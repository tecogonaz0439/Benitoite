//! 宣言・束縛・型の部分の依存を、単一化の結果と分けて保持する
//! （設計書 02-05「誤りの報告と検査の継続」）。成功する型付けの順序は変えない。
use super::*;

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
        if reason.priority != Priority::Declared
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
            if a == b || has_error(&a) || has_error(&b) {
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
