//! 宣言・束縛・型の部分の依存を、単一化の結果と分けて保持する
//! （設計書 02-05「誤りの報告と検査の継続」）。成功する型付けの順序は変えない。
use super::*;

// 転記先、元の部分の経路、転記先の部分の経路。合成と射影を同じ辺で表す。
type ValueDependent = (u32, Vec<usize>, Vec<usize>);

#[derive(Clone)]
enum ValueShape {
    Recorded(usize),
    Known(ITy),
}

#[derive(Clone)]
struct ValueRecord {
    target: ITy,
    value: ITy,
    shape: Option<ValueShape>,
}

#[derive(Default)]
pub(super) struct Provenance {
    // 辺の番号を両端から共有する。使用ごとに宣言までの履歴を複製しない。
    edges: Vec<(u32, u32, Reason)>,
    incident: BTreeMap<u32, Vec<usize>>,
    // zonk が消す List 要素・構成子の欄・関数の各部分への経路を残す。
    shapes: BTreeMap<u32, (ITy, Reason)>,
    recovered: BTreeMap<u32, ITy>,
    components: BTreeMap<u32, OriginComponent>,
    uses: Vec<(ITy, ITy, Reason)>,
    // 成功時には組だけを積み、経路と依存表は診断が必要になってから作る。
    values: Vec<ValueRecord>,
    value_bindings: Vec<Option<usize>>,
    processed_values: usize,
    values_dirty: bool,
    known_parts: RefCell<BTreeMap<(u32, Vec<usize>), bool>>,
    pending_dependents: BTreeSet<u32>,
    pending_dirty: bool,
    deferred_results: BTreeSet<u32>,
    // 値から束縛への向きだけを記録する。利用側の要求は元の値の根拠にしない。
    bindings: BTreeMap<u32, ITy>,
    binding_dependents: BTreeMap<u32, Vec<ValueDependent>>,
    value_sources: BTreeMap<u32, Vec<ITy>>,
    pub(super) diagnosed_roots: BTreeMap<u32, Span>,
    binding_contracts: BTreeMap<u32, ITy>,
    // 元の型変数と、その型の部分への経路から診断済み原因の位置を引く。
    // 空の経路は値全体であり、zonk の根や宣言由来の連結成分とは共有しない。
    diagnosed: BTreeMap<u32, BTreeMap<Vec<usize>, Span>>,
    pending_results: BTreeSet<u32>,
}

// 型の単一化とは別の連結成分。成功する制約では根の要約だけを参照する。
#[derive(Clone)]
struct OriginComponent {
    parent: u32,
    size: usize,
    confirmed: bool,
    declaration: Option<Reason>,
}
impl Provenance {
    fn root(&self, mut v: u32) -> u32 {
        while let Some(node) = self.components.get(&v) {
            if node.parent == v {
                break;
            }
            v = node.parent;
        }
        v
    }
    fn component(&mut self, v: u32) -> &mut OriginComponent {
        let root = self.root(v);
        self.components.entry(root).or_insert(OriginComponent {
            parent: root,
            size: 1,
            confirmed: false,
            declaration: None,
        })
    }
    pub(super) fn connect(&mut self, a: u32, b: u32) {
        let (mut a, mut b) = (self.root(a), self.root(b));
        if a == b {
            return;
        }
        if self.component(a).size < self.component(b).size {
            std::mem::swap(&mut a, &mut b);
        }
        let right = self.component(b).clone();
        self.component(b).parent = a;
        let left = self.component(a);
        left.size = left.size.saturating_add(right.size);
        left.confirmed |= right.confirmed;
        if left.declaration.is_none() {
            left.declaration = right.declaration;
        }
    }
    pub(super) fn declare(&mut self, v: u32, reason: &Reason) {
        self.component(v).declaration = Some(reason.clone());
    }
}

impl Solver {
    /// 束縛自身の注釈と、注釈のない束縛の右辺を単一化より前に残す。
    pub(in crate::typeck) fn record_binding(
        &mut self,
        pattern: &ITy,
        value: &ITy,
        contract: Option<&ITy>,
    ) {
        let ITy::Var(v) = pattern else {
            if contract.is_none() {
                self.record_value(pattern, value);
            }
            return;
        };
        if let Some(contract) = contract {
            self.provenance
                .binding_contracts
                .insert(v.0, contract.clone());
            return;
        }
        self.record_value(pattern, value);
    }

    /// 値を作る向きの依存だけを残す。使用側の注釈・引数の要求はここへ加えない。
    pub(in crate::typeck) fn record_value(&mut self, target: &ITy, value: &ITy) {
        if target == value {
            return;
        }
        if let ITy::Var(v) = target {
            if self.provenance.binding_contracts.contains_key(&v.0) {
                return;
            }
            if let Ok(i) = usize::try_from(v.0) {
                self.provenance.value_bindings.resize(
                    self.provenance
                        .value_bindings
                        .len()
                        .max(i.saturating_add(1)),
                    None,
                );
                if let Some(slot) = self.provenance.value_bindings.get_mut(i) {
                    slot.get_or_insert(self.provenance.values.len());
                }
            }
        }
        // 後の単一化で変わる値側の外形は、記録済みの値の索引で固定する。
        // 元がknownの変数の場合だけ、その時点の外形を保存する。
        let shape = if !matches!(target, ITy::Var(_)) && matches!(value, ITy::Var(_)) {
            let (recorded, shape) = self.value_origin(value);
            Some(recorded.map_or_else(|| ValueShape::Known(shape.clone()), ValueShape::Recorded))
        } else {
            None
        };
        self.provenance.values.push(ValueRecord {
            target: target.clone(),
            value: value.clone(),
            shape,
        });
        self.provenance.values_dirty = true;
        self.provenance.pending_dirty = true;
    }

    fn build_value(&mut self, target: &ITy, value: &ITy, shape: &ITy) {
        let ITy::Var(v) = target else {
            // パターンや高階引数の部分を取り出す向きも保存する。
            // 元の値の外側が遅延中なら、原因が確定してから経路を射影する。
            if let ITy::Var(source) = value {
                let mut pending = vec![(target, Vec::new())];
                while let Some((part, path)) = pending.pop() {
                    match part {
                        ITy::Var(target) => self
                            .provenance
                            .binding_dependents
                            .entry(source.0)
                            .or_default()
                            .push((target.0, path, Vec::new())),
                        ITy::Con(_, args) | ITy::App(_, args) => {
                            for (i, part) in args.iter().enumerate() {
                                let mut child = path.clone();
                                child.push(i);
                                pending.push((part, child));
                            }
                        }
                        ITy::Fn(f) => {
                            for (i, part) in f
                                .params
                                .iter()
                                .chain(std::iter::once(&f.ret))
                                .chain(&f.effect.failures)
                                .enumerate()
                                .skip(f.params.len())
                            {
                                let mut child = path.clone();
                                child.push(i);
                                pending.push((part, child));
                            }
                        }
                        ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
                    }
                }
            }
            match (target, shape) {
                (ITy::Con(c, a), ITy::Con(d, b)) if c == d => {
                    for (a, b) in a.iter().zip(b) {
                        self.build_value(a, b, b);
                    }
                }
                (ITy::Fn(a), ITy::Fn(b)) => {
                    // 引数の注釈は利用側の要求であり、元の値の確定情報にしない。
                    for (a, b) in a.params.iter().zip(&b.params) {
                        self.build_value(b, a, a);
                    }
                    self.build_value(&a.ret, &b.ret, &b.ret);
                    for (a, b) in a.effect.failures.iter().zip(&b.effect.failures) {
                        self.build_value(a, b, b);
                    }
                }
                _ => {}
            }
            return;
        };
        if self.provenance.binding_contracts.contains_key(&v.0) {
            return;
        }
        self.provenance
            .bindings
            .entry(v.0)
            .or_insert_with(|| value.clone());
        self.provenance
            .value_sources
            .entry(v.0)
            .or_default()
            .push(value.clone());
        let mut pending = vec![(value, Vec::new())];
        while let Some((ty, path)) = pending.pop() {
            match ty {
                ITy::Var(source) => self
                    .provenance
                    .binding_dependents
                    .entry(source.0)
                    .or_default()
                    .push((v.0, Vec::new(), path)),
                ITy::Con(_, args) | ITy::App(_, args) => {
                    for (i, ty) in args.iter().enumerate() {
                        let mut child = path.clone();
                        child.push(i);
                        pending.push((ty, child));
                    }
                }
                ITy::Fn(f) => {
                    for (i, ty) in f
                        .params
                        .iter()
                        .chain(std::iter::once(&f.ret))
                        .chain(&f.effect.failures)
                        .enumerate()
                    {
                        let mut child = path.clone();
                        child.push(i);
                        pending.push((ty, child));
                    }
                }
                ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
    }

    /// 同じ部分に正常な値もある場合、その値の型は回復の仮情報ではない。
    /// 単一化後のbindingは使用側の要求も含むため、値の元の形だけを調べる。
    pub(super) fn known_value_part(&self, v: u32, path: &[usize]) -> bool {
        let key = (v, path.to_vec());
        if let Some(known) = self.provenance.known_parts.borrow().get(&key) {
            return *known;
        }
        let mut pending = vec![(ITy::Var(TyVar(v)), path.to_vec())];
        let mut seen = BTreeSet::new();
        while let Some((ty, path)) = pending.pop() {
            match ty {
                ITy::Var(v) => {
                    if !seen.insert((v.0, path.clone()))
                        || self.provenance.diagnosed_roots.contains_key(&v.0)
                    {
                        continue;
                    }
                    let known = self
                        .provenance
                        .known_parts
                        .borrow()
                        .get(&(v.0, path.clone()))
                        .copied();
                    if let Some(known) = known {
                        if known {
                            self.provenance.known_parts.borrow_mut().insert(key, true);
                            return true;
                        }
                        continue;
                    }
                    if let Some(contract) = self.provenance.binding_contracts.get(&v.0) {
                        pending.push((contract.clone(), path));
                    } else if let Some(sources) = self.provenance.value_sources.get(&v.0) {
                        pending.extend(sources.iter().cloned().map(|t| (t, path.clone())));
                    }
                }
                ITy::Error => {}
                ty @ (ITy::Con(..)
                | ITy::Fn(_)
                | ITy::Param(_)
                | ITy::App(..)
                | ITy::Rigid { .. }) => {
                    if path.is_empty() {
                        self.provenance.known_parts.borrow_mut().insert(key, true);
                        return true;
                    }
                    let children = match ty {
                        ITy::Con(_, args) | ITy::App(_, args) => args,
                        ITy::Fn(f) => f
                            .params
                            .into_iter()
                            .chain(std::iter::once(f.ret))
                            .chain(f.effect.failures)
                            .collect(),
                        ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => vec![],
                    };
                    if let Some(child) = path.first().and_then(|i| children.get(*i)) {
                        pending.push((child.clone(), path.iter().skip(1).copied().collect()));
                    }
                }
            }
        }
        self.provenance
            .known_parts
            .borrow_mut()
            .extend(seen.into_iter().map(|key| (key, false)));
        false
    }

    pub(super) fn build_values(&mut self) {
        if self.provenance.processed_values != self.provenance.values.len() {
            self.provenance.known_parts.get_mut().clear();
        }
        while let Some(record) = self
            .provenance
            .values
            .get(self.provenance.processed_values)
            .cloned()
        {
            self.provenance.processed_values = self.provenance.processed_values.saturating_add(1);
            let shape = match record.shape {
                Some(ValueShape::Known(shape)) => shape,
                Some(ValueShape::Recorded(i)) => self
                    .provenance
                    .values
                    .get(i)
                    .map(|record| record.value.clone())
                    .unwrap_or_else(|| record.value.clone()),
                None => record.value.clone(),
            };
            self.build_value(&record.target, &record.value, &shape);
        }
    }

    pub(in crate::typeck) fn refresh_diagnosed(&mut self) {
        if self.provenance.diagnosed_roots.is_empty() || !self.provenance.values_dirty {
            return;
        }
        self.build_values();
        self.provenance.values_dirty = false;
        self.provenance.known_parts.get_mut().clear();
        self.provenance.diagnosed.clear();
        let mut pending: Vec<_> = self
            .provenance
            .diagnosed_roots
            .iter()
            .map(|(v, cause)| (*v, Vec::new(), *cause))
            .collect();
        let mut budget = TypeBudget::default();
        while let Some((v, path, cause)) = pending.pop() {
            // 追跡を打ち切った部分は抑制しない。根の診断と通常の型の予算は残す。
            if budget.enter(path.len().saturating_add(1)).is_err() {
                break;
            }
            if self.provenance.binding_contracts.contains_key(&v)
                || self.known_value_part(v, &path)
                || self
                    .provenance
                    .diagnosed
                    .get(&v)
                    .is_some_and(|parts| parts.contains_key(&path))
            {
                continue;
            }
            self.provenance
                .diagnosed
                .entry(v)
                .or_default()
                .insert(path.clone(), cause);
            for (target, source_path, prefix) in self
                .provenance
                .binding_dependents
                .get(&v)
                .into_iter()
                .flatten()
            {
                let remainder = if path.is_empty() {
                    &path[..]
                } else {
                    let Some(remainder) = path.strip_prefix(source_path.as_slice()) else {
                        continue;
                    };
                    remainder
                };
                let mut target_path = prefix.clone();
                target_path.extend(remainder);
                // 型の予算の外で循環した経路を無制限に伸ばさない。
                if target_path.len() <= super::super::limits::MAX_TYPE_DEPTH {
                    pending.push((*target, target_path, cause));
                }
            }
        }
    }

    /// 既に報告した式の未確定な結果に原因を付ける。通常の型や交換には出さない。
    pub(in crate::typeck) fn diagnose_result(&mut self, ty: &ITy, cause: Span) {
        let ITy::Var(v) = ty else { return };
        self.provenance.diagnosed_roots.insert(v.0, cause);
        self.provenance.values_dirty = true;
    }

    /// 部分の原因がある変数は、使用側が具体化した形より元の値の形を使う。
    pub(super) fn provenance_shape(&self, v: TyVar, tracking: bool) -> Option<&ITy> {
        if !tracking {
            return None;
        }
        self.provenance.diagnosed.get(&v.0)?;
        self.provenance.bindings.get(&v.0)
    }

    pub(super) fn diagnosed_whole(&self, v: TyVar) -> bool {
        self.diagnosed_cause(&ITy::Var(v)).is_some()
    }

    /// 原因IDは元の診断の一次位置（ファイルとUTF-8バイト範囲）で識別する。
    pub(in crate::typeck) fn diagnosed_cause(&self, ty: &ITy) -> Option<Span> {
        let ITy::Var(v) = ty else { return None };
        self.provenance
            .diagnosed_roots
            .get(&v.0)
            .copied()
            .or_else(|| {
                self.provenance
                    .diagnosed
                    .get(&v.0)?
                    .get(&Vec::new())
                    .copied()
            })
    }

    /// 後で解く呼び出しだけは、原因の診断が決まるまで依存する不一致を保留する。
    pub(in crate::typeck) fn pending_result(&mut self, ty: &ITy) {
        if let ITy::Var(v) = ty {
            self.provenance.pending_results.insert(v.0);
            self.provenance.deferred_results.insert(v.0);
            self.provenance.pending_dirty = true;
        }
    }

    pub(in crate::typeck) fn resolved_result(&mut self, ty: &ITy) {
        if let ITy::Var(v) = ty {
            self.provenance.pending_results.remove(&v.0);
            self.provenance.pending_dirty = true;
        }
    }

    fn pending_closure(&self, roots: &BTreeSet<u32>) -> BTreeSet<u32> {
        let mut marked = BTreeSet::new();
        let mut pending: Vec<_> = roots.iter().copied().collect();
        while let Some(v) = pending.pop() {
            if self.provenance.binding_contracts.contains_key(&v) || !marked.insert(v) {
                continue;
            }
            pending.extend(
                self.provenance
                    .binding_dependents
                    .get(&v)
                    .into_iter()
                    .flatten()
                    .map(|(target, _, _)| *target),
            );
        }
        marked
    }

    fn uses_marked(ty: &ITy, marked: &BTreeSet<u32>) -> bool {
        let mut pending = vec![ty];
        while let Some(ty) = pending.pop() {
            match ty {
                ITy::Var(v) => {
                    if marked.contains(&v.0) {
                        return true;
                    }
                }
                ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
                ITy::Fn(f) => {
                    pending.extend(&f.params);
                    pending.push(&f.ret);
                    pending.extend(&f.effect.failures);
                }
                ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
        false
    }

    pub(super) fn depends_on_pending_result(&mut self, ty: &ITy) -> bool {
        if self.provenance.pending_results.is_empty() {
            return false;
        }
        self.build_values();
        if self.provenance.pending_dirty {
            self.provenance.pending_dirty = false;
            self.provenance.pending_dependents =
                self.pending_closure(&self.provenance.pending_results);
        }
        Self::uses_marked(ty, &self.provenance.pending_dependents)
    }

    /// 誤りの葉を未知としても残る、既知の構造どうしの不一致だけを調べる。
    pub(super) fn known_mismatch(&self, a: &ITy, b: &ITy) -> bool {
        let mut pending = vec![(self.zonk(a), self.zonk(b))];
        while let Some((a, b)) = pending.pop() {
            match (a, b) {
                (ITy::Error | ITy::Var(_), _) | (_, ITy::Error | ITy::Var(_)) => {}
                (ITy::App(h, _), _) | (_, ITy::App(h, _)) if self.head(h).is_none() => {}
                (ITy::Con(c, a), ITy::Con(d, b)) if c == d && a.len() == b.len() => {
                    pending.extend(a.into_iter().zip(b))
                }
                (ITy::App(c, a), ITy::App(d, b)) if c == d && a.len() == b.len() => {
                    pending.extend(a.into_iter().zip(b))
                }
                (ITy::Fn(a), ITy::Fn(b)) => {
                    if a.params.len() != b.params.len() {
                        return true;
                    }
                    pending.extend(a.params.into_iter().zip(b.params));
                    pending.push((a.ret, b.ret));
                    pending.extend(a.effect.failures.into_iter().zip(b.effect.failures));
                }
                (a, b) if a == b => {}
                _ => return true,
            }
        }
        false
    }

    fn value_origin<'a>(&'a self, ty: &'a ITy) -> (Option<usize>, &'a ITy) {
        let mut current = ty;
        let mut recorded = None;
        let mut seen = BTreeSet::new();
        while let ITy::Var(v) = current {
            if !seen.insert(v.0) {
                break;
            }
            let index = usize::try_from(v.0)
                .ok()
                .and_then(|i| self.provenance.value_bindings.get(i))
                .and_then(|i| *i);
            if let Some((index, record)) =
                index.and_then(|i| self.provenance.values.get(i).map(|r| (i, r)))
            {
                recorded = Some(index);
                current = &record.value;
            } else if let Some(next) = self.node(*v).and_then(|n| n.binding.as_ref()) {
                recorded = None;
                current = next;
            } else {
                break;
            }
        }
        (recorded, current)
    }

    /// 制約を解く前の呼び出す値の形を保存するため、値側の束縛だけを辿る。
    pub(in crate::typeck) fn value_shape(&self, ty: &ITy) -> ITy {
        self.value_origin(ty).1.clone()
    }

    pub(super) fn record_redirected(&mut self, imposed: &ITy, value: &ITy) {
        if let ITy::Var(v) = imposed {
            self.provenance.recovered.insert(v.0, value.clone());
            self.redirected.insert(self.root(*v).0);
        }
    }
    pub(super) fn origin_neighbors(&self, v: u32) -> impl Iterator<Item = u32> + '_ {
        self.provenance
            .incident
            .get(&v)
            .into_iter()
            .flatten()
            .filter_map(move |i| {
                self.provenance
                    .edges
                    .get(*i)
                    .map(|(a, b, _)| if *a == v { *b } else { *a })
            })
            .chain((self.root(TyVar(v)).0 != v).then(|| self.root(TyVar(v)).0))
    }

    fn origin_shape(&self, ty: &ITy) -> ITy {
        let mut ty = ty.clone();
        let mut seen = BTreeSet::new();
        while let ITy::Var(v) = ty {
            if !seen.insert(v.0) {
                break;
            }
            let next = self
                .provenance
                .shapes
                .get(&v.0)
                .map(|(t, _)| t.clone())
                .or_else(|| self.node(v).and_then(|n| n.binding.clone()));
            let Some(next) = next else { break };
            ty = next;
        }
        ty
    }

    pub(super) fn record_use(&mut self, a: &ITy, b: &ITy, reason: &Reason) {
        if (reason.priority != Priority::Declared || !self.provenance.pending_results.is_empty())
            && !matches!(
                reason.kind,
                ReasonKind::Pattern | ReasonKind::Try | ReasonKind::FnBody
            )
        {
            self.provenance
                .uses
                .push((a.clone(), b.clone(), reason.clone()));
        }
    }

    pub(super) fn record_provenance(&mut self, a: &ITy, b: &ITy, reason: &Reason) {
        let mut pending = vec![(a.clone(), b.clone())];
        while let Some((a, b)) = pending.pop() {
            if reason.kind == ReasonKind::Pattern
                && self.intrinsic_type(&a)
                && let ITy::Var(v) = &b
            {
                self.provenance.component(v.0).confirmed = true;
            }
            if let (ITy::Var(a), ITy::Var(b)) = (&a, &b) {
                if a != b {
                    self.provenance.connect(a.0, b.0);
                    let index = self.provenance.edges.len();
                    self.provenance.edges.push((a.0, b.0, reason.clone()));
                    self.provenance.incident.entry(a.0).or_default().push(index);
                    self.provenance.incident.entry(b.0).or_default().push(index);
                }
            } else {
                for (v, t) in [(&a, &b), (&b, &a)] {
                    if let ITy::Var(v) = v
                        && !matches!(t, ITy::Var(_) | ITy::Error)
                    {
                        self.provenance
                            .shapes
                            .entry(v.0)
                            .or_insert_with(|| (t.clone(), reason.clone()));
                    }
                }
            }
            match (self.origin_shape(&a), self.origin_shape(&b)) {
                (ITy::Con(c, a), ITy::Con(d, b)) if c == d => pending.extend(a.into_iter().zip(b)),
                (ITy::App(c, a), ITy::App(d, b)) if c == d => pending.extend(a.into_iter().zip(b)),
                (ITy::Fn(a), ITy::Fn(b)) => {
                    pending.extend(a.params.into_iter().zip(b.params));
                    pending.push((a.ret, b.ret));
                    pending.extend(a.effect.failures.into_iter().zip(b.effect.failures));
                }
                _ => {}
            }
        }
    }

    fn origin_confirmed(&self, v: u32) -> bool {
        self.provenance
            .components
            .get(&self.provenance.root(v))
            .is_some_and(|c| c.confirmed)
    }

    fn intrinsic_type(&self, ty: &ITy) -> bool {
        match ty {
            ITy::Var(v) => self.origin_confirmed(v.0),
            ITy::Con(_, args) | ITy::App(_, args) => args.iter().all(|t| self.intrinsic_type(t)),
            ITy::Fn(f) => {
                f.params.iter().all(|t| self.intrinsic_type(t)) && self.intrinsic_type(&f.ret)
            }
            ITy::Param(_) | ITy::Rigid { .. } => true,
            ITy::Error => false,
        }
    }

    fn origin_declaration(&self, ty: &ITy) -> Option<Reason> {
        let ITy::Var(v) = ty else { return None };
        self.provenance
            .components
            .get(&self.provenance.root(v.0))
            .and_then(|c| c.declaration.clone())
    }

    fn origin_recovery(&self, v: u32) -> Option<ITy> {
        if self.provenance.recovered.is_empty() {
            return None;
        }
        let mut pending = vec![v];
        let mut seen = BTreeSet::new();
        while let Some(v) = pending.pop() {
            if !seen.insert(v) {
                continue;
            }
            if let Some(t) = self.provenance.recovered.get(&v) {
                return Some(t.clone());
            }
            pending.extend(self.origin_neighbors(v));
        }
        None
    }

    pub(super) fn recovered_type(&self, ty: &ITy) -> ITy {
        if let ITy::Var(v) = ty
            && let Some(t) = self.origin_recovery(v.0)
        {
            return self.zonk(&t);
        }
        match self.origin_shape(ty) {
            ITy::Con(c, args) => ITy::Con(c, args.iter().map(|t| self.recovered_type(t)).collect()),
            ITy::App(h, args) => ITy::App(h, args.iter().map(|t| self.recovered_type(t)).collect()),
            ITy::Fn(mut f) => {
                f.params = f.params.iter().map(|t| self.recovered_type(t)).collect();
                f.ret = self.recovered_type(&f.ret);
                f.effect.failures = f
                    .effect
                    .failures
                    .iter()
                    .map(|t| self.recovered_type(t))
                    .collect();
                ITy::Fn(f)
            }
            ty @ (ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error) => self.zonk(&ty),
        }
    }

    pub(super) fn has_recovery(&self, ty: &ITy) -> bool {
        if self.provenance.recovered.is_empty() {
            return false;
        }
        let mut pending = vec![ty.clone()];
        while let Some(t) = pending.pop() {
            if let ITy::Var(v) = &t
                && self.origin_recovery(v.0).is_some()
            {
                return true;
            }
            match self.origin_shape(&t) {
                ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
                ITy::Fn(f) => {
                    pending.extend(f.params);
                    pending.push(f.ret);
                    pending.extend(f.effect.failures);
                }
                ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
        false
    }

    pub(super) fn provisional_dependency(&self, ty: &ITy, reason: &Reason) -> bool {
        let mut pending = vec![ty.clone()];
        while let Some(t) = pending.pop() {
            if let ITy::Var(v) = &t
                && self.origin_confirmed(v.0)
            {
                continue;
            }
            if let Some(r) = self.origin_declaration(&t)
                && !(reason.span.file == r.span.file
                    && reason.span.start >= r.span.start
                    && reason.span.end <= r.span.end)
            {
                return true;
            }
            match self.origin_shape(&t) {
                ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
                ITy::Fn(f) => {
                    pending.extend(f.params);
                    pending.push(f.ret);
                    pending.extend(f.effect.failures);
                }
                ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
        false
    }

    pub(super) fn provenance_failure(
        &mut self,
        ctx: &mut Body<'_, '_>,
        expected: &ITy,
        found: &ITy,
        reason: &Reason,
    ) -> bool {
        // 値を定める制約は、食い違った部分だけを宣言への要求に移す。
        // Try の成功型は result が期待側にあるので Pattern と向きが逆になる。
        let pair = if reason.kind == ReasonKind::Pattern {
            Some((expected, found))
        } else if reason.kind == ReasonKind::Try {
            Some((found, expected))
        } else {
            None
        };
        if let Some((value, imposed)) = pair {
            let mut pending = vec![(value.clone(), imposed.clone())];
            let mut moved = false;
            while let Some((value, imposed)) = pending.pop() {
                if self.zonk(&value) == self.zonk(&imposed) {
                    continue;
                }
                if let Some(r) = self.origin_declaration(&imposed) {
                    if reason.span.file == r.span.file
                        && reason.span.start >= r.span.start
                        && reason.span.end <= r.span.end
                    {
                        continue;
                    }
                    let exp = self.zonk(&imposed);
                    self.record_redirected(&imposed, &value);
                    // 型・向き・理由を保存し、根の無効化は報告の採否と分けて最後に行う。
                    self.late
                        .push((DiagCode::E0401, exp, value, r, self.escaped.take()));
                    moved = true;
                    continue;
                }
                match (self.origin_shape(&value), self.origin_shape(&imposed)) {
                    (ITy::Con(c, a), ITy::Con(d, b)) if c == d => {
                        pending.extend(a.into_iter().zip(b))
                    }
                    (ITy::Fn(a), ITy::Fn(b)) if a.params.len() == b.params.len() => {
                        pending.extend(a.params.into_iter().zip(b.params));
                        pending.push((a.ret, b.ret));
                    }
                    _ => {}
                }
            }
            if moved {
                return true;
            }
        }
        if self.has_recovery(expected) || self.has_recovery(found) {
            let a = self.recovered_type(expected);
            let b = self.recovered_type(found);
            if a == b || ((has_error(&a) || has_error(&b)) && !self.known_mismatch(&a, &b)) {
                // 宣言の仮の型との比較だけで失敗した使用を保留する。
                self.dependent_late.push((
                    DiagCode::E0401,
                    expected.clone(),
                    found.clone(),
                    reason.clone(),
                    self.escaped.take(),
                ));
            } else {
                // 同じ根を使っていても、値の型でも失敗する要求は独立した誤りである。
                self.failure(ctx, DiagCode::E0401, &a, &b, reason);
                self.poison(&[expected.clone(), found.clone()]);
            }
            return true;
        }
        if reason.priority != Priority::Declared
            && !matches!(
                reason.kind,
                ReasonKind::Pattern | ReasonKind::Try | ReasonKind::FnBody
            )
            && (self.provisional_dependency(expected, reason)
                || self.provisional_dependency(found, reason))
        {
            self.dependent_late.push((
                DiagCode::E0401,
                expected.clone(),
                found.clone(),
                reason.clone(),
                self.escaped.take(),
            ));
            return true;
        }
        false
    }

    /// 遅延した原因の確定前に成功した要求も、既知の構造だけを再確認する。
    pub(super) fn diagnosed_uses(&mut self) -> Vec<(ITy, ITy, Reason)> {
        self.refresh_diagnosed();
        if self.provenance.diagnosed.is_empty() {
            return vec![];
        }
        let marked = self.pending_closure(&self.provenance.deferred_results);
        self.provenance
            .uses
            .iter()
            .filter(|(a, b, _)| {
                (Self::uses_marked(a, &marked) || Self::uses_marked(b, &marked))
                    && self.known_mismatch(a, b)
            })
            .cloned()
            .collect()
    }

    pub(super) fn recovered_uses(&mut self) -> Vec<(ITy, ITy, Reason)> {
        let uses = std::mem::take(&mut self.provenance.uses);
        if self.provenance.recovered.is_empty() {
            return vec![];
        }
        uses.into_iter()
            .filter_map(|(a, b, reason)| {
                // 元の型でも失敗した使用の内側だけを再確認する。宣言の型では
                // 正しい使用に、回復だけを理由とする新しい誤りを加えない。
                let originally_failed = self.dependent_late.iter().any(|(_, _, _, failed, _)| {
                    failed.priority != Priority::Declared
                        && failed.span.file == reason.span.file
                        && failed.span.start <= reason.span.start
                        && failed.span.end >= reason.span.end
                });
                if !originally_failed || (!self.has_recovery(&a) && !self.has_recovery(&b)) {
                    return None;
                }
                let (a, b) = (self.recovered_type(&a), self.recovered_type(&b));
                // 推論用の行変数・契約の番号の違いを型の不一致にしない。
                let mut probe = Solver::default();
                (!has_error(&a) && !has_error(&b) && probe.equal(&a, &b, &reason).is_err())
                    .then_some((a, b, reason))
            })
            .collect()
    }

    pub(super) fn poison_redirected(&mut self) {
        let mut pending = self
            .provenance
            .recovered
            .keys()
            .copied()
            .collect::<Vec<_>>();
        let mut seen = BTreeSet::new();
        while let Some(v) = pending.pop() {
            if !seen.insert(v) {
                continue;
            }
            pending.extend(self.origin_neighbors(v));
            self.poison(&[ITy::Var(TyVar(v))]);
        }
    }
}
