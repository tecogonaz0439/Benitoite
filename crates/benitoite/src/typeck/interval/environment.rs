//! 局所束縛の区間と、枝で共有する環境の接尾辞
//! （設計書 02-05「区間解析の局所環境」）。

use super::budget::{Budget, Item, Lifetime, Operation, StopReason};
use super::domain::{IntKind, Interval};
use super::origins::Provenance;
use crate::base::BindingId;
use std::rc::Rc;

/// 専用構築器を通常の整数の位置と混同しない。
#[derive(Clone, Debug, PartialEq, Eq)]
pub(in crate::typeck) enum Slot {
    Integer(Interval, Provenance),
    IntegerKind(IntKind, Interval, Provenance),
    Unknown,
    Builder,
    Unavailable,
}

impl Slot {
    /// Lean の integerKindSlot と同じく、Integer64 は既存の位置を使う。
    pub(super) fn integer_kind(kind: IntKind, range: Interval, provenance: Provenance) -> Self {
        match kind {
            IntKind::Integer64 => Self::Integer(range, provenance),
            IntKind::Integer8
            | IntKind::Integer16
            | IntKind::Integer32
            | IntKind::UnsignedInteger16
            | IntKind::UnsignedInteger32
            | IntKind::UnsignedInteger64 => Self::IntegerKind(kind, range, provenance),
        }
    }

    /// 本体入口では型域だけを残す。構造由来の未知は通常の整数位置に変えない。
    pub(super) fn top(ty: &crate::types::Ty) -> Self {
        IntKind::of_type(ty).map_or(Self::Unknown, |kind| {
            Self::integer_kind(kind, Interval::top_kind(kind), Provenance::default())
        })
    }
}

#[derive(Clone, Debug)]
struct Entry {
    binding: Option<BindingId>,
    slot: Slot,
    tail: Option<usize>,
    range_id: u64,
    range_fact: Option<usize>,
}

/// 環境は先頭の番号だけで分岐する。共有する接尾辞を再計上しない。
#[derive(Default)]
pub(in crate::typeck) struct Environment {
    entries: Vec<Entry>,
    seed: SavedEnvironment,
    head: Option<usize>,
    ranges: RangeScope,
    range_facts: Vec<super::flow::range::Fact>,
    checkpoints: Vec<RangeCheckpoint>,
}

/// 位置の数と次番号を保持する。事実の参照先は局所列、記録の本体は一時領域に置く。
/// 通常の環境を忘れても番号を再利用しない（設計書 01-12「区間解析の同じ成功値の直接射影」）。
#[derive(Clone, Copy, Debug, Default)]
struct RangeScope {
    positions: u64,
    next_id: u64,
}

/// 局所列と Range の位置を一緒に分岐・復元する。
#[derive(Clone, Copy)]
pub(super) struct Snapshot {
    head: Option<usize>,
    ranges: RangeScope,
}

/// 発見列と解析入口で共有する忘却済みの位置。保存項目を二重に数えない。
#[derive(Clone, Debug, Default)]
pub(super) struct SavedEnvironment(Option<Rc<Vec<Entry>>>);

impl SavedEnvironment {
    fn len(&self) -> usize {
        self.0.as_ref().map_or(0, |entries| entries.len())
    }
}

/// 元の長さと先頭、および必要な場合だけ Range の復元情報の添字を持つ。
/// 空の状態では確保せず、Range の状態を足しても元の三語の枠を大きくしない
/// （設計書 02-01「関数の呼び出しと処理系のスタック」）。
#[derive(Clone, Copy)]
pub(super) struct Checkpoint {
    length: usize,
    head: usize,
    ranges: usize,
}

#[derive(Clone, Copy)]
struct RangeCheckpoint {
    ranges: RangeScope,
    range_facts: usize,
}

#[derive(Clone, Copy)]
struct CheckpointState {
    length: usize,
    head: Option<usize>,
    ranges: RangeScope,
    range_facts: usize,
}

impl Environment {
    /// 保存された入口環境を借り、一時領域だけを新しく作る。
    pub(super) fn from_saved(seed: SavedEnvironment) -> Self {
        Self {
            head: seed.len().checked_sub(1),
            seed,
            entries: Vec::new(),
            ranges: RangeScope::default(),
            range_facts: Vec::new(),
            checkpoints: Vec::new(),
        }
    }

    /// forget が新しく作った連続した列だけを保存へ移し、元の環境へ戻る。
    pub(super) fn save_since(
        &mut self,
        checkpoint: Checkpoint,
        budget: &mut Budget,
    ) -> SavedEnvironment {
        let Some(checkpoint) = self.take_checkpoint(checkpoint) else {
            return SavedEnvironment::default();
        };
        let offset = self.seed.len().saturating_add(checkpoint.length);
        let mut entries = self.entries.split_off(checkpoint.length);
        for entry in &mut entries {
            entry.tail = entry.tail.and_then(|index| index.checked_sub(offset));
        }
        self.head = checkpoint.head;
        self.ranges = checkpoint.ranges;
        let facts = self
            .range_facts
            .len()
            .saturating_sub(checkpoint.range_facts);
        self.range_facts.truncate(checkpoint.range_facts);
        budget.release(
            Lifetime::Temporary,
            u64::try_from(facts).unwrap_or(u64::MAX),
        );
        budget.save_temporary(u64::try_from(entries.len()).unwrap_or(u64::MAX));
        SavedEnvironment((!entries.is_empty()).then(|| Rc::new(entries)))
    }

    /// 復元する一時領域。番号はホストの添字であり、言語の整数値には使わない。
    pub(super) fn checkpoint(&mut self) -> Checkpoint {
        let ranges = if self.ranges.next_id == 0
            && self.range_facts.is_empty()
            && self.checkpoints.is_empty()
        {
            // next_id が0なら位置・事実も空。大量の定数展開では作業領域を確保しない。
            usize::MAX
        } else {
            let index = self.checkpoints.len();
            self.checkpoints.push(RangeCheckpoint {
                ranges: self.ranges,
                range_facts: self.range_facts.len(),
            });
            index
        };
        Checkpoint {
            length: self.entries.len(),
            // 実在する Entry の添字は usize::MAX より小さい。
            head: self.head.unwrap_or(usize::MAX),
            ranges,
        }
    }

    fn take_checkpoint(&mut self, checkpoint: Checkpoint) -> Option<CheckpointState> {
        // 番号はこの環境だけが作り、内側で停止して残った復元情報も一緒に捨てる。
        let (ranges, range_facts) = if checkpoint.ranges == usize::MAX {
            self.checkpoints.clear();
            (RangeScope::default(), 0)
        } else {
            debug_assert!(checkpoint.ranges < self.checkpoints.len());
            let state = self.checkpoints.get(checkpoint.ranges).copied()?;
            self.checkpoints.truncate(checkpoint.ranges);
            (state.ranges, state.range_facts)
        };
        Some(CheckpointState {
            length: checkpoint.length,
            head: (checkpoint.head != usize::MAX).then_some(checkpoint.head),
            ranges,
            range_facts,
        })
    }

    /// 枝の環境を複製せずに保存する。
    pub(super) fn snapshot(&self) -> Snapshot {
        Snapshot {
            head: self.head,
            ranges: self.ranges,
        }
    }

    /// 同じ一時領域に保持した枝へ切り替える。
    pub(super) fn select(&mut self, snapshot: Snapshot) {
        self.head = snapshot.head;
        self.ranges = snapshot.ranges;
    }

    /// clearLocals は次番号を保つ。入口の resetRanges は from_saved が行う。
    pub(super) fn clear_locals(&mut self) {
        self.head = None;
        self.forget_ranges();
    }

    fn forget_ranges(&mut self) {
        self.ranges.positions = 0;
    }

    fn extend_ranges(&mut self) {
        // fresh は計上済みの環境書き込みの後だけであり、次番号は本体操作数以下である。
        self.ranges.positions = self.ranges.positions.saturating_add(1);
        self.ranges.next_id = self.ranges.next_id.saturating_add(1);
    }

    /// 空の末尾を含む rangeEntry の各枠と読み取りを、局所位置まで数える。
    /// 由来がない場合も位置を飛ばさず、局所列全体を事前に数えない。
    pub(super) fn read_range(
        &self,
        binding: BindingId,
        budget: &mut Budget,
    ) -> Result<Option<super::flow::range::Fact>, StopReason> {
        self.read_range_position(binding, budget)
            .map(|entry| entry.and_then(|(_, fact)| fact))
    }

    /// rangeChecked は位置番号と事実の二列を、それぞれ同じ局所位置まで読む。
    pub(super) fn read_checked_range(
        &self,
        binding: BindingId,
        budget: &mut Budget,
    ) -> Result<Option<super::flow::range::Fact>, StopReason> {
        let Some((id, _)) = self.read_range_position(binding, budget)? else {
            return Ok(None);
        };
        Ok(self
            .read_range_position(binding, budget)?
            .and_then(|(_, fact)| fact)
            .filter(|fact| fact.success_id == Some(id)))
    }

    fn read_range_position(
        &self,
        binding: BindingId,
        budget: &mut Budget,
    ) -> Result<Option<(u64, Option<super::flow::range::Fact>)>, StopReason> {
        let mut head = self.head;
        let mut remaining = self.ranges.positions;
        let mut held = 0_u64;
        let result = (|| loop {
            Self::frame(budget)?;
            held = held.saturating_add(1);
            budget.charge(Operation::EnvironmentRead)?;
            if remaining == 0 {
                return Ok(None);
            }
            let Some(entry) = self.entry(head) else {
                return Ok(None);
            };
            if entry.binding == Some(binding) {
                return Ok(Some((
                    entry.range_id,
                    entry
                        .range_fact
                        .and_then(|index| self.range_facts.get(index))
                        .copied(),
                )));
            }
            head = entry.tail;
            remaining = remaining.saturating_sub(1);
        })();
        budget.release(Lifetime::Temporary, held);
        result
    }

    /// 保存の直前に auxiliary 一項だけを確保する。認定の走査以外の操作は足さない。
    pub(super) fn save_range(
        &mut self,
        origin: super::flow::range::Origin,
        checked: bool,
        budget: &mut Budget,
    ) -> Result<(), super::identity::IdentityStop> {
        use super::identity::IdentityStop;
        let index = self
            .head
            .and_then(|index| index.checked_sub(self.seed.len()))
            .ok_or(IdentityStop::NumberOverflow)?;
        let entry = self
            .entries
            .get_mut(index)
            .ok_or(IdentityStop::NumberOverflow)?;
        budget
            .reserve(Item::Auxiliary, Lifetime::Temporary)
            .map_err(IdentityStop::AnalysisBudget)?;
        entry.range_fact = Some(self.range_facts.len());
        self.range_facts.push(super::flow::range::Fact {
            origin,
            success_id: checked.then_some(entry.range_id),
        });
        Ok(())
    }

    fn entry(&self, head: Option<usize>) -> Option<&Entry> {
        head.and_then(|index| {
            if index < self.seed.len() {
                self.seed.0.as_ref().and_then(|entries| entries.get(index))
            } else {
                self.entries.get(index.saturating_sub(self.seed.len()))
            }
        })
    }

    fn frame(budget: &mut Budget) -> Result<(), StopReason> {
        budget.reserve(Item::StackFrame, Lifetime::Temporary)
    }

    fn cons(&mut self, entry: Entry, budget: &mut Budget) -> Result<Option<usize>, StopReason> {
        budget.charge(Operation::EnvironmentWrite)?;
        budget.reserve(Item::Environment, Lifetime::Temporary)?;
        let head = self.seed.len().saturating_add(self.entries.len());
        self.entries.push(entry);
        Ok(Some(head))
    }

    /// BudgetScan.readSlots と同じ順序で、位置ごとに枠と読み取りを計上する。
    pub(super) fn read(
        &self,
        binding: BindingId,
        budget: &mut Budget,
    ) -> Result<Option<Slot>, StopReason> {
        let mut head = self.head;
        let mut held = 0_u64;
        let result = (|| loop {
            Self::frame(budget)?;
            held = held.saturating_add(1);
            budget.charge(Operation::EnvironmentRead)?;
            match self.entry(head) {
                Some(entry) if entry.binding == Some(binding) => {
                    return Ok(Some(entry.slot.clone()));
                }
                Some(entry) => head = entry.tail,
                None => return Ok(None),
            }
        })();
        budget.release(Lifetime::Temporary, held);
        result
    }

    /// 新しい束縛は既存の環境を接尾辞として共有する。別名の関係は追加しない。
    pub(super) fn write(
        &mut self,
        binding: BindingId,
        slot: Slot,
        budget: &mut Budget,
    ) -> Result<(), StopReason> {
        self.head = self.cons(
            Entry {
                binding: Some(binding),
                slot,
                tail: self.head,
                range_id: self.ranges.next_id,
                range_fact: None,
            },
            budget,
        )?;
        self.extend_ranges();
        Ok(())
    }

    /// 辞書・破棄した引数・継続も位置を持つが、通常の名前から参照させない。
    pub(super) fn anonymous(&mut self, slot: Slot, budget: &mut Budget) -> Result<(), StopReason> {
        self.head = self.cons(
            Entry {
                binding: None,
                slot,
                tail: self.head,
                range_id: self.ranges.next_id,
                range_fact: None,
            },
            budget,
        )?;
        self.extend_ranges();
        Ok(())
    }

    /// 比較の更新では BudgetScan.narrow と同じく接頭辞だけを内側から作り直す。
    pub(super) fn narrow(
        &mut self,
        binding: BindingId,
        slot: Slot,
        budget: &mut Budget,
    ) -> Result<(), StopReason> {
        let mut head = self.head;
        let mut prefix = Vec::new();
        let mut held = 0_u64;
        let result = (|| {
            let mut tail = loop {
                Self::frame(budget)?;
                held = held.saturating_add(1);
                budget.charge(Operation::EnvironmentRead)?;
                match self.entry(head) {
                    Some(entry) if entry.binding == Some(binding) => {
                        break self.cons(
                            Entry {
                                // narrow は整数位置だけを更新する。構造由来の未知を
                                // 比較によって整数位置へ変えない。
                                slot: if matches!((&entry.slot, &slot),
                                    (Slot::Integer(..), Slot::Integer(..)))
                                    || matches!((&entry.slot, &slot),
                                        (Slot::IntegerKind(stored, ..), Slot::IntegerKind(kind, ..)) if stored == kind) {
                                    slot
                                } else {
                                    entry.slot.clone()
                                },
                                ..entry.clone()
                            },
                            budget,
                        )?;
                    }
                    Some(entry) => {
                        prefix.push(entry.clone());
                        head = entry.tail;
                    }
                    None => break None,
                }
            };
            budget.release(Lifetime::Temporary, 1);
            held = held.saturating_sub(1);
            while let Some(entry) = prefix.pop() {
                tail = self.cons(Entry { tail, ..entry }, budget)?;
                budget.release(Lifetime::Temporary, 1);
                held = held.saturating_sub(1);
            }
            self.head = tail;
            Ok(())
        })();
        budget.release(Lifetime::Temporary, held);
        result
    }

    fn integer_head(
        &self,
        head: Option<usize>,
        kind: IntKind,
        budget: &mut Budget,
    ) -> Result<(Interval, Provenance), StopReason> {
        Self::frame(budget)?;
        let result = budget.charge(Operation::EnvironmentRead).map(|()| {
            match self.entry(head).map(|e| &e.slot) {
                Some(Slot::Integer(range, origin)) if kind == IntKind::Integer64 => {
                    (*range, origin.clone())
                }
                Some(Slot::IntegerKind(stored, range, origin)) if *stored == kind => {
                    (*range, origin.clone())
                }
                _ => (Interval::top_kind(kind), Provenance::default()),
            }
        });
        budget.release(Lifetime::Temporary, 1);
        result
    }

    /// BudgetScan.hull の項目・左右の参照・再帰・保存の順序で凸に合流する。
    pub(super) fn join(
        &mut self,
        base: Snapshot,
        left: Snapshot,
        right: Snapshot,
        budget: &mut Budget,
    ) -> Result<(), StopReason> {
        let (mut base_head, mut left_head, mut right_head) = (base.head, left.head, right.head);
        let mut pending = Vec::new();
        let mut held = 0_u64;
        let result = (|| {
            loop {
                Self::frame(budget)?;
                held = held.saturating_add(1);
                let Some(mut entry) = self.entry(base_head).cloned() else {
                    break;
                };
                budget.charge(Operation::JoinItem)?;
                let integer = match &entry.slot {
                    Slot::Integer(_, origin) => Some((IntKind::Integer64, origin)),
                    Slot::IntegerKind(kind, _, origin) => Some((*kind, origin)),
                    Slot::Unknown | Slot::Builder | Slot::Unavailable => None,
                };
                if let Some((kind, base_origin)) = integer {
                    let (l, left_origin) = self.integer_head(left_head, kind, budget)?;
                    let (r, _) = self.integer_head(right_head, kind, budget)?;
                    // hull 自身は由来の操作・保存を持たないため、新しい由来を作らない。
                    // 同一区間は既存の根拠、異なる区間は両枝に共通する入口の根拠を保つ。
                    let origin = if l == r {
                        left_origin
                    } else {
                        base_origin.clone()
                    };
                    entry.slot = Slot::integer_kind(kind, l.join(r), origin);
                }
                base_head = entry.tail;
                pending.push(entry);
                left_head = self.entry(left_head).and_then(|e| e.tail);
                right_head = self.entry(right_head).and_then(|e| e.tail);
            }
            budget.release(Lifetime::Temporary, 1);
            held = held.saturating_sub(1);
            let mut tail = None;
            while let Some(entry) = pending.pop() {
                tail = self.cons(Entry { tail, ..entry }, budget)?;
                budget.release(Lifetime::Temporary, 1);
                held = held.saturating_sub(1);
            }
            self.head = tail;
            self.ranges = base.ranges;
            self.forget_ranges();
            Ok(())
        })();
        budget.release(Lifetime::Temporary, held);
        result
    }

    /// forgetSlots と同じく先頭から読み、末尾から Top の位置を作る。
    /// 診断用の由来も捨てる。途中停止で作った接頭辞は呼び出し元の領域で返す。
    pub(super) fn forget(&mut self, budget: &mut Budget) -> Result<(), StopReason> {
        let mut head = self.head;
        let mut pending = Vec::new();
        let mut held = 0_u64;
        let result = (|| {
            loop {
                Self::frame(budget)?;
                held = held.saturating_add(1);
                let Some(mut entry) = self.entry(head).cloned() else {
                    break;
                };
                budget.charge(Operation::EnvironmentRead)?;
                entry.slot = match entry.slot {
                    Slot::Integer(..) => Slot::Integer(Interval::top(), Provenance::default()),
                    Slot::IntegerKind(kind, ..) => {
                        Slot::IntegerKind(kind, Interval::top_kind(kind), Provenance::default())
                    }
                    slot @ (Slot::Unknown | Slot::Builder | Slot::Unavailable) => slot,
                };
                entry.range_fact = None;
                head = entry.tail;
                pending.push(entry);
            }
            budget.release(Lifetime::Temporary, 1);
            held = held.saturating_sub(1);
            let mut tail = None;
            while let Some(entry) = pending.pop() {
                tail = self.cons(Entry { tail, ..entry }, budget)?;
                budget.release(Lifetime::Temporary, 1);
                held = held.saturating_sub(1);
            }
            self.head = tail;
            self.forget_ranges();
            Ok(())
        })();
        budget.release(Lifetime::Temporary, held);
        result
    }

    /// 成功・停止とも、入口後に作った接頭辞だけを返す。
    pub(super) fn rollback(&mut self, checkpoint: Checkpoint, budget: &mut Budget) {
        let Some(checkpoint) = self.take_checkpoint(checkpoint) else {
            return;
        };
        let count = self.entries.len().saturating_sub(checkpoint.length);
        let facts = self
            .range_facts
            .len()
            .saturating_sub(checkpoint.range_facts);
        self.entries.truncate(checkpoint.length);
        self.range_facts.truncate(checkpoint.range_facts);
        self.head = checkpoint.head;
        self.ranges = checkpoint.ranges;
        budget.release(
            Lifetime::Temporary,
            u64::try_from(count.saturating_add(facts)).unwrap_or(u64::MAX),
        );
    }
}
