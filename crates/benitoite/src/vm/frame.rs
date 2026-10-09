//! 区画と枠（設計書 02-08「枠の積み重ね」「枠の種類」、ADR 0262）。

use crate::bytecode::program::ProtoIdx;
use crate::runtime::heap::{Discard, Discarder, ResourceId, Slot, Trace, Tracer};

use super::InstrRef;

/// 呼び出しの枠（02-08「枠の種類」）。
#[derive(Debug)]
pub struct CallFrame {
    /// 実行中の関数の値。メソッドの呼び出しでは辞書（`GETDICT` が読む）
    pub func: Slot,
    pub proto: ProtoIdx,
    /// 次に実行する命令の位置。振り分けのループが局所に持つ間は古い
    pub pc: u32,
    /// レジスタの窓の先頭（区画の `regs` の中の位置）
    pub base: u32,
    /// 窓の大きさ（原型のレジスタの数）
    pub size: u32,
    /// 結果を入れる呼び出し元のレジスタ（区画の `regs` の中の位置）。区画の最初の枠では `None`
    pub ret: Option<u32>,
    /// 呼び出した命令。`main` の枠とタスクの最初の枠では `None`
    pub call_site: Option<InstrRef>,
    /// 関数の境界の印（02-07「関数の境界」。`ESCAPE` はここで止まる）。枠を積むときに、呼んだ原型の
    /// `Proto::boundary`（10-07）を写す
    pub boundary: bool,
    /// 引き継いだハンドラの末尾で再開する節を直接呼んだ枠では、見つけたハンドラより外側の連鎖の始まり
    /// （タスクの引き継いだハンドラの連鎖の中の位置）。ハンドラを探す処理はここで連鎖を移る（02-08「ハンドラと継続」）
    pub chain_resume: Option<u32>,
}

/// セルの更新の枠が持つもの（02-08「可変のセル」）。
#[derive(Debug)]
pub struct CellUpdate {
    pub cell: Slot,
    /// 読んだときの版の番号
    pub version: u64,
    /// 適用する関数
    pub func: Slot,
}

/// `handle` の枠が持つもの（02-08「ハンドラの記録とハンドラの連鎖」）。
#[derive(Debug)]
pub struct HandleFrame {
    /// ハンドラの記録（`Host` の対象。10-09「ハンドラの記録、継続、`Lazy`」）
    pub record: Slot,
    /// 値を返したときの戻り先。この区画のすぐ下の区画の `regs` の中の位置。
    /// 初めは `HANDLE` の結果のレジスタ、`RESUME` で区画を戻すたびに `RESUME` の結果のレジスタに付け替える
    pub ret: u32,
    /// この枠を積んだ `HANDLE` の命令（行き詰まりの記録に使う）
    pub at: InstrRef,
}

/// 呼び出しの枠でない枠の種類。
#[derive(Debug)]
pub enum OtherKind {
    /// 解放の枠（`USE` が積む。積んだ呼び出しの枠に属する）
    Release {
        resource: ResourceId,
        at: InstrRef,
    },
    /// `update` の枠。評価の途中の `Lazy` の対象を持つ
    Update {
        lazy: Slot,
        at: InstrRef,
    },
    CellUpdate(CellUpdate),
    Handle(HandleFrame),
    /// `drop` の枠。継続の値を持つ
    Drop {
        cont: Slot,
    },
}

/// 呼び出しの枠でない枠。
#[derive(Debug)]
pub struct OtherFrame {
    /// 積んだ時点で、その下にあった同じ区画の呼び出しの枠の数
    pub depth: u32,
    pub kind: OtherKind,
}

/// 枠の種類（枠を降ろす処理の表の行。10-09「枠を降ろす原因と処理」）。
#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
pub enum FrameKind {
    Call,
    Release,
    Update,
    CellUpdate,
    Handle,
    Drop,
}

impl OtherKind {
    pub fn frame_kind(&self) -> FrameKind {
        match self {
            OtherKind::Release { .. } => FrameKind::Release,
            OtherKind::Update { .. } => FrameKind::Update,
            OtherKind::CellUpdate(_) => FrameKind::CellUpdate,
            OtherKind::Handle(_) => FrameKind::Handle,
            OtherKind::Drop { .. } => FrameKind::Drop,
        }
    }

    /// 一つの呼び出しを包む枠か（解放の枠のほかはすべて包む枠）。
    pub fn is_wrapping(&self) -> bool {
        !matches!(self, OtherKind::Release { .. })
    }
}

/// 区画の中の枠の位置。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FrameAt {
    Call(usize),
    Other(usize),
}

/// 区画（ADR 0262 の決定 1）。
#[derive(Debug, Default)]
pub struct Segment {
    pub calls: Vec<CallFrame>,
    pub others: Vec<OtherFrame>,
    pub regs: Vec<Slot>,
}

impl Segment {
    /// 最も上の枠。二つの `Vec` の最後の要素から、上の規則で決める。
    pub fn top_frame(&self) -> Option<FrameAt> {
        let calls = self.calls.len();
        if let Some(other) = self.others.last() {
            let above_all_calls = usize::try_from(other.depth).is_ok_and(|d| d >= calls);
            if above_all_calls {
                return Some(FrameAt::Other(self.others.len().saturating_sub(1)));
            }
        }
        calls.checked_sub(1).map(FrameAt::Call)
    }

    /// 枠の数（二つの `Vec` の両方。02-08「呼び出しの入れ子の上限」）。
    pub fn frame_count(&self) -> u64 {
        let n = self.calls.len().saturating_add(self.others.len());
        u64::try_from(n).unwrap_or(u64::MAX)
    }

    pub fn reg_count(&self) -> u64 {
        u64::try_from(self.regs.len()).unwrap_or(u64::MAX)
    }

    pub fn is_empty(&self) -> bool {
        self.calls.is_empty() && self.others.is_empty()
    }
}

/// タスクの枠の積み重ね。最後の区画が最も上にある。
#[derive(Debug, Default)]
pub struct TaskStack {
    pub segments: Vec<Segment>,
}

impl Trace for CallFrame {
    fn trace(&self, t: &mut Tracer<'_>) {
        t.slot(&self.func);
    }
}

impl Trace for OtherFrame {
    fn trace(&self, t: &mut Tracer<'_>) {
        match &self.kind {
            OtherKind::Release { .. } => {}
            OtherKind::Update { lazy, .. } => t.slot(lazy),
            OtherKind::CellUpdate(c) => {
                t.slot(&c.cell);
                t.slot(&c.func);
            }
            OtherKind::Handle(h) => t.slot(&h.record),
            OtherKind::Drop { cont } => t.slot(cont),
        }
    }
}

impl Trace for Segment {
    fn trace(&self, t: &mut Tracer<'_>) {
        self.calls.trace(t);
        self.others.trace(t);
        t.slots(&self.regs);
    }
}

impl Trace for TaskStack {
    fn trace(&self, t: &mut Tracer<'_>) {
        self.segments.trace(t);
    }
}

// 枠と区画を捨てるときは、所有する `Slot` を値で手放す（10-08 の不変条件 H11）。`Trace` と同じ `Slot` を訪れる。

impl Discard for CallFrame {
    fn discard(self, d: &mut Discarder<'_>) {
        d.slot(self.func);
    }
}

impl Discard for OtherFrame {
    fn discard(self, d: &mut Discarder<'_>) {
        match self.kind {
            OtherKind::Release { .. } => {}
            OtherKind::Update { lazy, .. } => d.slot(lazy),
            OtherKind::CellUpdate(c) => {
                d.slot(c.cell);
                d.slot(c.func);
            }
            OtherKind::Handle(h) => d.slot(h.record),
            OtherKind::Drop { cont } => d.slot(cont),
        }
    }
}

impl Discard for Segment {
    fn discard(self, d: &mut Discarder<'_>) {
        self.calls.discard(d);
        self.others.discard(d);
        self.regs.discard(d);
    }
}

impl Discard for TaskStack {
    fn discard(self, d: &mut Discarder<'_>) {
        self.segments.discard(d);
    }
}
