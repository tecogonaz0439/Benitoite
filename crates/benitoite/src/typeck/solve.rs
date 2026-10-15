//! 単一化、流れ込む制約、エフェクトの最小解（設計書 02-05「制約の解決」）。
use super::context::{Body, fixed};
use super::infer::*;
use super::limits::{TypeBudget, TypeLimit};
use super::traits::Bound;
use crate::base::{NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::resolve::ResolveOutput;
use crate::syntax::ast::BinOp;
use crate::types::builtin::{BuiltinTypeClass, BuiltinTypeId as B};
use crate::types::*;
use std::collections::{BTreeMap, BTreeSet};

// 子を左から順に展開し、親の型は子をすべて作ってから組み立てる。
// 作業の枠はヒープに置き、型の深さに比例する Rust の再帰を使わない（02-03）。
enum ZonkHead<'a> {
    Con(TyCon),
    App(IHead),
    Fn(&'a IFnTy),
}
enum ZonkStep<'a> {
    Visit(&'a ITy, usize),
    Args {
        head: ZonkHead<'a>,
        remaining: std::slice::Iter<'a, ITy>,
        built: Vec<ITy>,
        depth: usize,
        has_child: bool,
    },
    Return(&'a IFnTy, Vec<ITy>),
}

#[derive(Default)]
struct Var {
    parent: u32,
    binding: Option<ITy>,
    // この変数の型に現れてよい剛な型の節。結合と複合型への代入で範囲を狭める
    // （設計書 01-12「型パラメータの組み込みの制約」の Δ）。
    clauses: Vec<NodeId>,
}
#[derive(Default)]
struct ContractState {
    parent: u32,
    binding: Option<IContract>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum Elem {
    Name(EffectName),
    Var(EffVar),
}
#[derive(Default)]
struct EffectState {
    set: EffectSet,
    origins: BTreeMap<Elem, Span>,
}
type Escape = (NodeId, u32);
type LateFailure = (DiagCode, ITy, ITy, Reason, Option<Escape>);
type EffectConstraint = (IEffect, IEffect, Reason, Option<(ITy, ITy)>);

/// 一つの本体でだけ有効な型変数とエフェクト変数の状態。
#[derive(Default)]
pub(super) struct Solver {
    vars: Vec<Var>,
    contracts: Vec<ContractState>,
    clauses: Vec<NodeId>,
    // 現在の単一化の失敗の出どころ。報告を保留するときは失敗とともに保存する。
    escaped: Option<Escape>,
    heads: BTreeMap<u32, TyHead>,
    effs: Vec<EffectState>,
    effects: Vec<EffectConstraint>,
    required: Vec<(ITy, Reason)>,
    // 宣言の型への流れ込む制約（`return` など）が先に結び付けた型変数と、その理由。
    // 呼び出しの戻り値の食い違い、パターンの失敗の移し替え、宣言どうしの食い違いの判定に使う
    // （設計書 02-05「誤りの報告と検査の継続」）。
    declared: BTreeMap<u32, Reason>,
    // 宣言の側の理由で後へ回した失敗の報告。どちらの段で積んだものも、solve の終わりで報告する。
    late: Vec<LateFailure>,
    // 束縛の失敗を宣言へ移した根だけを記録し、通常の使う側の誤りはすぐ報告する。
    // 記録のある根は型変数以外の型に結び付いているので、その後の変数どうしの結合で移らない
    // パターンの制約は `Equal` で遅らせず、変数を使う式の制約より先に生成されるので、使う側の制約を
    // 解く時点で記録は済んでいる（設計書 02-05「誤りの報告と検査の継続」）。
    redirected: BTreeSet<u32>,
    // 宣言どうしと変数を使う側の食い違いは、束縛との食い違いを先に示してから報告の要否を決める
    // （設計書 02-05「誤りの報告と検査の継続」）。
    dependent_late: Vec<LateFailure>,
}
impl Solver {
    pub fn fresh_contract(&mut self) -> IContract {
        let id = u32::try_from(self.contracts.len()).unwrap_or(u32::MAX);
        self.contracts.push(ContractState {
            parent: id,
            binding: None,
        });
        IContract::Var(ContractId(id))
    }
    fn contract_root(&self, id: ContractId) -> ContractId {
        let mut id = id;
        while let Some(state) = usize::try_from(id.0)
            .ok()
            .and_then(|i| self.contracts.get(i))
        {
            if state.parent == id.0 {
                break;
            }
            id = ContractId(state.parent);
        }
        id
    }
    pub(super) fn resolve_contract(&self, contract: &IContract) -> IContract {
        match contract {
            IContract::Var(id) => {
                let id = self.contract_root(*id);
                usize::try_from(id.0)
                    .ok()
                    .and_then(|i| self.contracts.get(i))
                    .and_then(|s| s.binding.clone())
                    .unwrap_or(IContract::Var(id))
            }
            IContract::Known(_) => contract.clone(),
        }
    }
    pub(super) fn contract_names(&self, contract: &IContract) -> Option<Vec<String>> {
        match self.resolve_contract(contract) {
            IContract::Known(names) => Some(names),
            IContract::Var(_) => None,
        }
    }
    fn equal_contracts(
        &mut self,
        a: &IContract,
        b: &IContract,
        arity: usize,
    ) -> Result<(), DiagCode> {
        let a = self.resolve_contract(a);
        let b = self.resolve_contract(b);
        for contract in [&a, &b] {
            if let IContract::Known(names) = contract
                && (names.len() != arity || names.iter().collect::<BTreeSet<_>>().len() != arity)
            {
                return Err(DiagCode::E0455);
            }
        }
        match (&a, &b) {
            (IContract::Var(a), IContract::Var(b)) => {
                if a != b
                    && let Some(s) = usize::try_from(a.0)
                        .ok()
                        .and_then(|i| self.contracts.get_mut(i))
                {
                    s.parent = b.0;
                }
                Ok(())
            }
            (IContract::Var(id), contract) | (contract, IContract::Var(id)) => {
                if let Some(s) = usize::try_from(id.0)
                    .ok()
                    .and_then(|i| self.contracts.get_mut(i))
                {
                    s.binding = Some(contract.clone());
                    Ok(())
                } else {
                    Err(DiagCode::E0455)
                }
            }
            (IContract::Known(a), IContract::Known(b)) if a != b => Err(DiagCode::E0454),
            _ => Ok(()),
        }
    }
    pub fn fresh_ty(&mut self) -> ITy {
        let n = u32::try_from(self.vars.len()).unwrap_or(u32::MAX);
        self.vars.push(Var {
            parent: n,
            binding: None,
            clauses: self.clauses.clone(),
        });
        ITy::Var(TyVar(n))
    }
    pub fn enter_clause(&mut self, clause: NodeId) {
        self.clauses.push(clause);
    }
    pub fn leave_clause(&mut self) {
        self.clauses.pop();
    }
    /// 制約の解決中に作る変数には、走査中の節でなく、元の変数の範囲を引き継ぐ。
    pub fn fresh_ty_like(&mut self, source: TyVar) -> ITy {
        let clauses = self
            .node(source)
            .map_or_else(Vec::new, |n| n.clauses.clone());
        let ty = self.fresh_ty();
        if let ITy::Var(v) = ty
            && let Some(n) = self.node_mut(v)
        {
            n.clauses = clauses;
        }
        ty
    }
    /// 型注釈の型を参照の共有先に置き、誤りの印も局所の使い先へ伝える（02-05「誤りの報告と検査の継続」）。
    pub fn known(&mut self, t: ITy) -> ITy {
        let variable = self.fresh_ty();
        if let ITy::Var(v) = variable
            && let Some(n) = self.node_mut(v)
        {
            n.binding = Some(t);
        }
        variable
    }
    pub fn fresh_head(&mut self) -> IHead {
        match self.fresh_ty() {
            ITy::Var(v) => IHead::Var(v),
            ITy::Con(..)
            | ITy::Fn(_)
            | ITy::Param(_)
            | ITy::App(..)
            | ITy::Rigid { .. }
            | ITy::Error => IHead::Param(0),
        }
    }
    pub fn fresh_effect(&mut self) -> IEffect {
        let n = u32::try_from(self.effs.len()).unwrap_or(u32::MAX);
        self.effs.push(EffectState::default());
        IEffect {
            fixed: EffectSet::empty(),
            var: Some(EffInfer(n)),
        }
    }
    /// 試行・リソースなどのフックが、決まらなければならない型を登録する。
    pub fn require_type(&mut self, ty: ITy, r: Reason) {
        self.required.push((ty, r));
    }
    fn root(&self, v: TyVar) -> TyVar {
        let mut v = v;
        while let Some(n) = usize::try_from(v.0).ok().and_then(|i| self.vars.get(i)) {
            if n.parent == v.0 {
                break;
            }
            v = TyVar(n.parent);
        }
        v
    }
    fn node(&self, v: TyVar) -> Option<&Var> {
        self.vars.get(usize::try_from(self.root(v).0).ok()?)
    }
    fn node_mut(&mut self, v: TyVar) -> Option<&mut Var> {
        let v = self.root(v);
        self.vars.get_mut(usize::try_from(v.0).ok()?)
    }
    pub fn zonk(&self, t: &ITy) -> ITy {
        self.zonk_checked(t).unwrap_or(ITy::Error)
    }
    pub fn zonk_checked(&self, t: &ITy) -> Result<ITy, TypeLimit> {
        let mut budget = TypeBudget::default();
        let mut pending = vec![ZonkStep::Visit(t, 1)];
        let mut result = ITy::Error;
        while let Some(step) = pending.pop() {
            match step {
                ZonkStep::Visit(mut t, depth) => {
                    // 共有する変数の連鎖自体はノードに数えず、展開した出現ごとに
                    // 予算を消費する。子を作る前に拒否する意味は変えない（02-03「入れ子の深さ」）。
                    while let ITy::Var(v) = t {
                        match self.node(*v).and_then(|n| n.binding.as_ref()) {
                            Some(bound) => t = bound,
                            None => break,
                        }
                    }
                    budget.enter(depth)?;
                    let children = match t {
                        ITy::Con(c, args) => Some((ZonkHead::Con(*c), args)),
                        ITy::App(h, args) => Some((ZonkHead::App(*h), args)),
                        ITy::Fn(f) => Some((ZonkHead::Fn(f), &f.params)),
                        ITy::Var(v) => {
                            result = ITy::Var(self.root(*v));
                            None
                        }
                        ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {
                            result = t.clone();
                            None
                        }
                    };
                    if let Some((head, args)) = children {
                        pending.push(ZonkStep::Args {
                            head,
                            remaining: args.iter(),
                            built: Vec::new(),
                            depth: depth.saturating_add(1),
                            has_child: false,
                        });
                    }
                }
                ZonkStep::Args {
                    head,
                    mut remaining,
                    mut built,
                    depth,
                    has_child,
                } => {
                    if has_child {
                        built.push(std::mem::replace(&mut result, ITy::Error));
                    }
                    if let Some(child) = remaining.next() {
                        pending.push(ZonkStep::Args {
                            head,
                            remaining,
                            built,
                            depth,
                            has_child: true,
                        });
                        pending.push(ZonkStep::Visit(child, depth));
                    } else {
                        match head {
                            ZonkHead::Con(c) => result = ITy::Con(c, built),
                            ZonkHead::App(h) => {
                                result = match self.head(h) {
                                    Some(TyHead::Con(c)) => ITy::Con(c, built),
                                    Some(TyHead::Param(i)) => ITy::App(IHead::Param(i), built),
                                    None => ITy::App(h, built),
                                };
                            }
                            ZonkHead::Fn(f) => {
                                pending.push(ZonkStep::Return(f, built));
                                pending.push(ZonkStep::Visit(&f.ret, depth));
                            }
                        }
                    }
                }
                ZonkStep::Return(f, params) => {
                    result = ITy::Fn(Box::new(IFnTy {
                        contract: self.resolve_contract(&f.contract),
                        params,
                        ret: result,
                        effect: f.effect.clone(),
                    }));
                }
            }
        }
        Ok(result)
    }
    fn head(&self, h: IHead) -> Option<TyHead> {
        match h {
            IHead::Param(i) => Some(TyHead::Param(i)),
            IHead::Var(v) => self.heads.get(&self.root(v).0).cloned(),
        }
    }
    pub fn finalize_head(&self, h: IHead, r: &ResolveOutput) -> TyHead {
        self.head(h).unwrap_or_else(|| {
            TyHead::Con(TyCon::Adt(
                r.stdlib("Benitoite.Option.Option")
                    .unwrap_or(crate::base::BindingId(u32::MAX)),
            ))
        })
    }
    pub(super) fn invalid_contract(&self, ty: &ITy) -> bool {
        let mut pending = vec![self.zonk(ty)];
        while let Some(ty) = pending.pop() {
            match ty {
                ITy::Fn(f) => {
                    if self.contract_names(&f.contract).is_none_or(|names| {
                        names.len() != f.params.len()
                            || names.iter().collect::<BTreeSet<_>>().len() != names.len()
                    }) {
                        return true;
                    }
                    pending.extend(f.params);
                    pending.push(f.ret);
                }
                ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
                ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
        false
    }
    pub fn finalize(&self, t: &ITy, r: &ResolveOutput) -> Ty {
        match self.zonk(t) {
            ITy::Var(_) | ITy::Error => super::decls::unit(),
            ITy::Con(c, a) => Ty::Con(c, a.iter().map(|t| self.finalize(t, r)).collect()),
            ITy::Fn(f)
                if self.contract_names(&f.contract).is_none_or(|names| {
                    names.len() != f.params.len()
                        || names.iter().collect::<BTreeSet<_>>().len() != names.len()
                }) =>
            {
                super::decls::unit()
            }
            ITy::Fn(f) => Ty::Fn(Box::new(FnTy {
                param_names: self.contract_names(&f.contract).unwrap_or_default(),
                params: f.params.iter().map(|t| self.finalize(t, r)).collect(),
                ret: self.finalize(&f.ret, r),
                effects: self.finalize_effect(&f.effect),
            })),
            ITy::Param(i) => Ty::Param(i),
            ITy::Rigid { clause, index } => Ty::Rigid { clause, index },
            ITy::App(h, a) => {
                let args = a.iter().map(|t| self.finalize(t, r)).collect();
                match self.finalize_head(h, r) {
                    TyHead::Con(c) => Ty::Con(c, args),
                    TyHead::Param(i) => Ty::App(i, args),
                }
            }
        }
    }
    pub fn finalize_effect(&self, e: &IEffect) -> EffectSet {
        e.var
            .and_then(|v| usize::try_from(v.0).ok().and_then(|i| self.effs.get(i)))
            .map_or_else(|| e.fixed.clone(), |s| e.fixed.union(&s.set))
    }
    pub fn contains_error(&self, t: &ITy) -> bool {
        has_error(&self.zonk(t))
    }
    fn occurs(&self, v: TyVar, t: &ITy) -> bool {
        let mut todo = vec![self.zonk(t)];
        while let Some(t) = todo.pop() {
            match t {
                ITy::Var(w) => {
                    if self.root(v) == self.root(w) {
                        return true;
                    }
                }
                ITy::Con(_, a) | ITy::App(_, a) => todo.extend(a),
                ITy::Fn(f) => {
                    todo.extend(f.params);
                    todo.push(f.ret);
                }
                ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
        false
    }
    fn bind(&mut self, v: TyVar, t: &ITy) -> Result<(), DiagCode> {
        if !matches!(t, ITy::Var(_)) && self.occurs(v, t) {
            return Err(DiagCode::E0404);
        }
        let clauses = self.node(v).map_or_else(Vec::new, |n| n.clauses.clone());
        self.restrict_clauses(t, &clauses)?;
        if let ITy::Var(w) = t {
            let (v, w) = (self.root(v), self.root(*w));
            if v != w
                && let Some(n) = self.node_mut(v)
            {
                n.parent = w.0;
            }
            return Ok(());
        }
        if let Some(n) = self.node_mut(v) {
            n.binding = Some(t.clone());
        }
        Ok(())
    }
    fn restrict_clauses(&mut self, t: &ITy, clauses: &[NodeId]) -> Result<(), DiagCode> {
        let mut pending = vec![self.zonk(t)];
        let mut vars = BTreeSet::new();
        while let Some(t) = pending.pop() {
            match t {
                ITy::Rigid { clause, index } if !clauses.contains(&clause) => {
                    self.escaped = Some((clause, index));
                    return Err(DiagCode::E0401);
                }
                ITy::Var(v) => {
                    vars.insert(v.0);
                }
                ITy::Con(_, args) | ITy::App(_, args) => pending.extend(args),
                ITy::Fn(f) => {
                    pending.extend(f.params);
                    pending.push(f.ret);
                }
                ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
        // 失敗した単一化で範囲を変えない。型がまだ未定の子の変数も狭め、後から剛な型が
        // 入る逃げを防ぐ。変数どうしの結合では両者の範囲の共通部分になる（01-12 の Δ）。
        for v in vars {
            if let Some(n) = self.node_mut(TyVar(v)) {
                n.clauses.retain(|clause| clauses.contains(clause));
            }
        }
        Ok(())
    }
    fn bind_head(&mut self, h: IHead, to: TyHead) -> Result<(), DiagCode> {
        match self.head(h) {
            Some(old) if old != to => Err(DiagCode::E0401),
            Some(_) => Ok(()),
            None => {
                if let IHead::Var(v) = h {
                    self.heads.insert(self.root(v).0, to);
                }
                Ok(())
            }
        }
    }
    pub fn equal(&mut self, a: &ITy, b: &ITy, reason: &Reason) -> Result<(), DiagCode> {
        self.clear_escape();
        self.equal_with_outer(a, b, reason, a, b)
    }
    /// 独自の診断で扱った単一化の脱出情報を、後の報告へ残さない。
    pub(super) fn clear_escape(&mut self) {
        self.escaped = None;
    }
    // 関数の入れ子のエフェクトが一致しない場合も、制約の外側の期待と実際を示す。
    // solve_effects は (実際, 期待) の対を受け取る（設計書 02-05「誤りの報告と検査の継続」）。
    fn equal_with_outer(
        &mut self,
        a: &ITy,
        b: &ITy,
        reason: &Reason,
        expected: &ITy,
        found: &ITy,
    ) -> Result<(), DiagCode> {
        let a = self.zonk_checked(a).map_err(|_| DiagCode::E0208)?;
        let b = self.zonk_checked(b).map_err(|_| DiagCode::E0208)?;
        if has_error(&a) || has_error(&b) {
            self.poison(&[a, b]);
            return Ok(());
        }
        match (&a, &b) {
            (ITy::Var(v), t) | (t, ITy::Var(v)) => self.bind(*v, t),
            (ITy::Con(c, x), ITy::Con(d, y)) if c == d && x.len() == y.len() => {
                for (a, b) in x.iter().zip(y) {
                    self.equal_with_outer(a, b, reason, expected, found)?;
                }
                Ok(())
            }
            (ITy::Param(i), ITy::Param(j)) if i == j => Ok(()),
            (
                ITy::Rigid {
                    clause: a,
                    index: i,
                },
                ITy::Rigid {
                    clause: b,
                    index: j,
                },
            ) if a == b && i == j => Ok(()),
            (ITy::Fn(x), ITy::Fn(y)) => {
                if x.params.len() != y.params.len() {
                    return Err(DiagCode::E0402);
                }
                self.equal_contracts(&x.contract, &y.contract, x.params.len())?;
                for (a, b) in x.params.iter().zip(&y.params) {
                    self.equal_with_outer(a, b, reason, expected, found)?;
                }
                self.equal_with_outer(&x.ret, &y.ret, reason, expected, found)?;
                self.effects.push((
                    x.effect.clone(),
                    y.effect.clone(),
                    reason.clone(),
                    Some((found.clone(), expected.clone())),
                ));
                self.effects.push((
                    y.effect.clone(),
                    x.effect.clone(),
                    reason.clone(),
                    Some((found.clone(), expected.clone())),
                ));
                Ok(())
            }
            (ITy::App(h, x), ITy::Con(c, y)) | (ITy::Con(c, y), ITy::App(h, x))
                if x.len() == y.len() =>
            {
                self.bind_head(*h, TyHead::Con(*c))?;
                for (a, b) in x.iter().zip(y) {
                    self.equal_with_outer(a, b, reason, expected, found)?;
                }
                Ok(())
            }
            (ITy::App(h, x), ITy::App(k, y)) if x.len() == y.len() => {
                match (self.head(*h), self.head(*k)) {
                    (Some(a), _) => self.bind_head(*k, a)?,
                    (_, Some(b)) => self.bind_head(*h, b)?,
                    _ => {
                        if let (IHead::Var(a), IHead::Var(b)) = (h, k) {
                            self.bind(*a, &ITy::Var(*b))?;
                        }
                    }
                }
                for (a, b) in x.iter().zip(y) {
                    self.equal_with_outer(a, b, reason, expected, found)?;
                }
                Ok(())
            }
            _ => Err(
                // E0403 は呼び出す値の型（外側の実際の型）が関数でないときだけ出す（設計書 02-05「誤りの報告と検査の継続」）。
                if matches!(reason.kind, ReasonKind::Call)
                    && !matches!(self.zonk(found), ITy::Fn(_))
                {
                    DiagCode::E0403
                } else {
                    DiagCode::E0401
                },
            ),
        }
    }
    fn flow(&mut self, a: &ITy, b: &ITy, r: &Reason) -> Result<bool, DiagCode> {
        self.clear_escape();
        let a = self.zonk_checked(a).map_err(|_| DiagCode::E0208)?;
        let b = self.zonk_checked(b).map_err(|_| DiagCode::E0208)?;
        if has_error(&a) || has_error(&b) {
            self.poison(&[a, b]);
            return Ok(true);
        }
        match (&a, &b) {
            (ITy::Var(_), ITy::Var(_)) => Ok(false),
            (ITy::Fn(x), ITy::Var(v)) | (ITy::Var(v), ITy::Fn(x)) => {
                let e = self.fresh_effect();
                let shape = ITy::Fn(Box::new(IFnTy {
                    contract: x.contract.clone(),
                    params: x.params.clone(),
                    ret: x.ret.clone(),
                    effect: e.clone(),
                }));
                self.bind(*v, &shape)?;
                let (sub, sup) = if matches!(a, ITy::Fn(_)) {
                    (x.effect.clone(), e)
                } else {
                    (e, x.effect.clone())
                };
                self.effects.push((sub, sup, r.clone(), Some((a, b))));
                Ok(true)
            }
            (ITy::Fn(x), ITy::Fn(y)) => {
                if x.params.len() != y.params.len() {
                    return Err(DiagCode::E0402);
                }
                self.equal_contracts(&x.contract, &y.contract, x.params.len())?;
                for (a, b) in x.params.iter().zip(&y.params) {
                    self.equal(a, b, r)?;
                }
                self.equal(&x.ret, &y.ret, r)?;
                self.effects
                    .push((x.effect.clone(), y.effect.clone(), r.clone(), Some((a, b))));
                Ok(true)
            }
            _ => {
                if r.priority == Priority::Declared
                    && let ITy::Var(v) = a
                {
                    self.declared.insert(self.root(v).0, r.clone());
                }
                self.equal(&b, &a, r)?;
                Ok(true)
            }
        }
    }
    // 呼び出しの戻り値の型の変数が宣言の側の制約で先に決まっていれば、戻り値の型どうしを
    // その理由で比べる。食い違いを関数でない値の呼び出しと誤って報告しないためである
    // （設計書 02-05「誤りの報告と検査の継続」）。比べる順序は「制約の解決」の手順 1 のまま
    // その場で比べ、失敗の報告だけを、引数の流れ込む制約を解いた後へ回す。実際の型の表示に、
    // 引数から決まる型を含めるためである。比べたときは true を返す。
    fn call_return(
        &mut self,
        ctx: &mut Body<'_, '_>,
        expected: &ITy,
        found: &ITy,
        reason: &Reason,
    ) -> bool {
        if reason.kind != ReasonKind::Call {
            return false;
        }
        let (ITy::Fn(x), ITy::Fn(y)) = (expected, self.zonk(found)) else {
            return false;
        };
        if x.params.len() != y.params.len() {
            return false;
        }
        let ITy::Var(v) = x.ret else {
            return false;
        };
        let Some(r) = self.declared.get(&self.root(v).0).cloned() else {
            return false;
        };
        let shape = ITy::Fn(Box::new(IFnTy {
            contract: x.contract.clone(),
            params: x.params.clone(),
            ret: y.ret.clone(),
            effect: x.effect.clone(),
        }));
        if let Err(code) = self.equal(&shape, found, reason) {
            self.failure(ctx, code, expected, found, reason);
            return true;
        }
        if let Err(code) = self.equal(&x.ret, &y.ret, &r) {
            self.late
                .push((code, x.ret.clone(), y.ret.clone(), r, self.escaped.take()));
        }
        true
    }
    fn poison(&mut self, types: &[ITy]) {
        let mut todo = types.to_vec();
        while let Some(t) = todo.pop() {
            match t {
                ITy::Var(v) => {
                    let bound = self.node(v).and_then(|n| n.binding.clone());
                    if let Some(t) = bound {
                        todo.push(t);
                    }
                    if let Some(n) = self.node_mut(v) {
                        n.binding = Some(ITy::Error);
                    }
                }
                ITy::Con(_, a) | ITy::App(_, a) => todo.extend(a),
                ITy::Fn(f) => {
                    todo.extend(f.params);
                    todo.push(f.ret);
                }
                ITy::Param(_) | ITy::Rigid { .. } | ITy::Error => {}
            }
        }
    }
    fn show(&self, ctx: &Body<'_, '_>, t: &ITy) -> String {
        ctx.show_type_with(self, t)
    }
    /// 出力用の finalize の既定値を診断へ持ち込まない。未確定の変数には
    /// 名前の表にない番号を用い、Ty::show の `_` の表示を使う（設計書 02-05「誤りの報告と検査の継続」）。
    pub(super) fn diagnostic_type(&self, t: &ITy) -> Ty {
        match self.zonk(t) {
            ITy::Var(_) | ITy::Error => Ty::Param(u32::MAX),
            ITy::Con(c, a) => Ty::Con(c, a.iter().map(|t| self.diagnostic_type(t)).collect()),
            ITy::Fn(f) => Ty::Fn(Box::new(FnTy {
                param_names: self.contract_names(&f.contract).unwrap_or_default(),
                params: f.params.iter().map(|t| self.diagnostic_type(t)).collect(),
                ret: self.diagnostic_type(&f.ret),
                effects: self.finalize_effect(&f.effect),
            })),
            ITy::Param(i) => Ty::Param(i),
            ITy::Rigid { clause, index } => Ty::Rigid { clause, index },
            ITy::App(h, a) => {
                let args = a.iter().map(|t| self.diagnostic_type(t)).collect();
                match self.head(h) {
                    Some(TyHead::Con(c)) => Ty::Con(c, args),
                    Some(TyHead::Param(i)) => Ty::App(i, args),
                    None => Ty::App(u32::MAX, args),
                }
            }
        }
    }
    pub fn failure(
        &mut self,
        ctx: &mut Body<'_, '_>,
        code: DiagCode,
        expected: &ITy,
        found: &ITy,
        r: &Reason,
    ) {
        let escaped = self.escaped.take();
        self.failure_with_escape(ctx, code, expected, found, r, escaped);
    }
    fn contract_difference(&self, expected: &ITy, found: &ITy) -> Option<(usize, String, String)> {
        let expected = self.zonk(expected);
        let found = self.zonk(found);
        let mut pending = vec![(&expected, &found)];
        while let Some((expected, found)) = pending.pop() {
            match (expected, found) {
                (ITy::Fn(e), ITy::Fn(f)) => {
                    let e_contract = self.resolve_contract(&e.contract);
                    let f_contract = self.resolve_contract(&f.contract);
                    if let (Some(es), Some(fs)) = (
                        self.contract_names(&e_contract),
                        self.contract_names(&f_contract),
                    ) && let Some((index, (e, f))) =
                        es.iter().zip(&fs).enumerate().find(|(_, (e, f))| e != f)
                    {
                        return Some((index.saturating_add(1), e.clone(), f.clone()));
                    }
                    pending.push((&e.ret, &f.ret));
                    pending.extend(e.params.iter().zip(&f.params).rev());
                }
                (ITy::Con(_, es), ITy::Con(_, fs)) | (ITy::App(_, es), ITy::App(_, fs)) => {
                    pending.extend(es.iter().zip(fs).rev())
                }
                _ => {}
            }
        }
        None
    }
    #[cold]
    #[inline(never)]
    fn failure_with_escape(
        &mut self,
        ctx: &mut Body<'_, '_>,
        code: DiagCode,
        expected: &ITy,
        found: &ITy,
        r: &Reason,
        escaped: Option<Escape>,
    ) {
        if r.kind == ReasonKind::LambdaReturn
            && ctx
                .lambda_body_ends
                .get(&r.span)
                .is_some_and(|end| ctx.reported_body_values.contains(end))
        {
            return;
        }
        if code == DiagCode::E0208 {
            let limit = self
                .zonk_checked(expected)
                .err()
                .or_else(|| self.zonk_checked(found).err());
            ctx.diagnostic(limit.map_or_else(
                || TypeLimit::diagnostic_limits(r.span),
                |limit| limit.diagnostic(r.span),
            ));
            self.poison(&[expected.clone(), found.clone()]);
            return;
        }
        if self.contains_error(expected) || self.contains_error(found) {
            return;
        }
        let mut code = code;
        if code == DiagCode::E0401 && matches!(r.kind, ReasonKind::ExprStmt | ReasonKind::FnBody) {
            code = DiagCode::E0416;
            if r.kind == ReasonKind::FnBody {
                ctx.reported_body_values.insert(r.span);
            }
        }
        let mut names = ctx.type_param_names();
        let mut indices = BTreeMap::new();
        let mut exp = ctx.show_type_named(self, expected, &mut names, &mut indices);
        let shown = exp.clone();
        if let Some(span) = r.related
            && ctx
                .decls
                .alias_spans
                .iter()
                .any(|s| s.file == span.file && s.start >= span.start && s.end <= span.end)
            && let Some(text) = source(ctx.decls.sources, span)
        {
            exp = text.into();
        }
        let mut f = ctx.show_type_named(self, found, &mut names, &mut indices);
        if code == DiagCode::E0402
            && let (ITy::Fn(e), ITy::Fn(actual)) = (self.zonk(expected), self.zonk(found))
        {
            let (expected, found) = if r.kind == ReasonKind::Call {
                (actual.params.len(), e.params.len())
            } else {
                (e.params.len(), actual.params.len())
            };
            exp = expected.to_string();
            f = found.to_string();
        }
        let op = op_text(&r.kind);
        let mut d = DiagBuilder::new(code)
            .arg("expected", &exp)
            .arg("found", &f)
            .arg("ty", &f)
            .arg("op", op)
            .primary(r.span);
        if code == DiagCode::E0454 {
            d = d.note("contracts");
            if let Some((index, expected_name, found_name)) =
                self.contract_difference(expected, found)
            {
                d = d
                    .arg("index", index.to_string())
                    .arg("expected_name", expected_name)
                    .arg("found_name", found_name)
                    .note("first_name");
            }
            if let Some(span) = r.related {
                d = d.secondary(span, "");
            }
        }
        if code == DiagCode::E0455 {
            d = d.help("annotation");
        }
        if code == DiagCode::E0402
            && let Some(span) = r.related
        {
            d = d.secondary(span, "declared");
        }
        if code == DiagCode::E0401 {
            if let Some((clause, index)) = escaped
                && let Some((op, span)) = ctx.clause_ops.get(clause)
            {
                // 期待・実際に表示した名前の表を注記でも使う。
                let mut ty = Ty::Rigid { clause, index };
                ctx.name_rigid_types(&mut ty, &mut names, &mut indices);
                let param = indices
                    .get(&(clause, index))
                    .and_then(|n| usize::try_from(*n).ok().and_then(|i| names.get(i)))
                    .map_or("_", String::as_str);
                d = d
                    .arg("param", param)
                    .arg("operation", op)
                    .note("escaped")
                    .secondary(*span, "clause");
            }
            if exp != shown {
                d = d.arg("expanded", shown).note("expanded");
            }
            if let Some(span) = r.related {
                d = d.secondary(span, "declared");
            }
            let note = match r.kind {
                ReasonKind::CallArg { index } => {
                    d = d.arg("index", index.to_string());
                    Some("because_call_arg")
                }
                ReasonKind::IfCondition | ReasonKind::MatchGuard => Some("because_condition"),
                ReasonKind::IfBranches => Some("because_if_branches"),
                ReasonKind::IfNoElse => Some("because_if_no_else"),
                ReasonKind::MatchArms => Some("because_match_arms"),
                ReasonKind::Pattern => Some("because_pattern"),
                ReasonKind::Alternatives => Some("because_alternatives"),
                ReasonKind::ListElement => Some("because_list"),
                ReasonKind::ListSpread => Some("because_spread"),
                ReasonKind::BindAnnotation => Some("because_bind_annotation"),
                ReasonKind::ConstValue => Some("because_const_annotation"),
                ReasonKind::Return => Some("because_return"),
                ReasonKind::LambdaReturn => Some("because_lambda_return"),
                ReasonKind::RecordBase => Some("because_update"),
                ReasonKind::RecordField { field } => {
                    d = d.arg(
                        "field",
                        ctx.decls
                            .resolved
                            .bindings
                            .get(field)
                            .map_or("_", |b| b.name.as_str()),
                    );
                    Some("because_field")
                }
                ReasonKind::Operands { .. } => Some("because_operands"),
                ReasonKind::Logic { .. } => Some("because_logic"),
                ReasonKind::Operator { .. } => Some("because_int_operands"),
                ReasonKind::Call
                | ReasonKind::LambdaUses
                | ReasonKind::FnBody
                | ReasonKind::FnUses
                | ReasonKind::ExprStmt
                | ReasonKind::Interp
                | ReasonKind::CallEffect
                | ReasonKind::BuiltinParam { .. }
                | ReasonKind::ParamBound { .. }
                | ReasonKind::ClassUse { .. }
                | ReasonKind::ImplSuper { .. }
                | ReasonKind::Try
                | ReasonKind::WithResource
                | ReasonKind::WithState
                | ReasonKind::LazyBody
                | ReasonKind::HandleBody
                | ReasonKind::HandleClause
                | ReasonKind::Resume => None,
            };
            if let Some(note) = note {
                d = d.note(note);
            }
            if let (ITy::Con(TyCon::Builtin(a), _), ITy::Con(TyCon::Builtin(b), _)) =
                (self.zonk(expected), self.zonk(found))
                && [a, b].iter().any(|ty| {
                    super::text::numeric_suffix(*ty).is_some()
                        && !matches!(*ty, B::INTEGER | B::FLOAT | B::BYTE)
                })
                && super::text::numeric_suffix(b).is_some()
                && let Some(suffix) = super::text::numeric_suffix(a)
            {
                d = d.arg("suffix", suffix).help("numeric_width");
            }
            if let Some(literal) = &r.int_literal
                && self.zonk(expected) == ITy::Con(TyCon::Builtin(B::FLOAT), vec![])
            {
                d = d.arg("literal", literal).help_edits(
                    "float_literal",
                    vec![Edit {
                        span: r.span,
                        replacement: format!("{literal}.0"),
                    }],
                );
            }
            if matches!(
                r.kind,
                ReasonKind::Operands {
                    op: OpName::Bin(BinOp::Add)
                }
            ) && (exp == "String" || f == "String")
            {
                let other = if exp == "String" { &f } else { &exp };
                let function = match other.as_str() {
                    "Integer" => Some(super::text::INTEGER_TO_STRING),
                    "Float" => Some(super::text::FLOAT_TO_STRING),
                    "Character" => Some(super::text::CHARACTER_TO_STRING),
                    _ => None,
                };
                d = if let Some(f) = function {
                    d.arg("function", f).help("to_string")
                } else {
                    d.help("to_string_any")
                };
            }
            let expected_type = self.diagnostic_type(expected);
            let found_type = self.diagnostic_type(found);
            if let Some(shadowed) = ctx
                .decls
                .prelude_type_in(&[&expected_type, &found_type], r.span)
            {
                d = d
                    .arg("shadowed", shadowed)
                    .note("shadowed")
                    .help("prelude_type");
            }
        }
        if code == DiagCode::E0416 {
            let body = ctx
                .body_returns
                .get(&r.span)
                .filter(|_| r.kind == ReasonKind::FnBody);
            let returns =
                body.is_some_and(|body| self.zonk(&body.ty) != super::generate::basic(B::UNIT));
            if returns && let Some(body) = body {
                let what = match body.owner {
                    super::context::ReturnOwner::Function => super::text::FUNCTION,
                    super::context::ReturnOwner::Lambda
                    | super::context::ReturnOwner::Placeholder(_) => super::text::LAMBDA,
                };
                d = d.arg("what", what);
                let returned = self.zonk(&body.ty);
                d = if matches!(returned, ITy::Var(_)) || returned == self.zonk(found) {
                    d.help_edits(
                        "return_value",
                        vec![Edit {
                            span: Span {
                                end: r.span.start,
                                ..r.span
                            },
                            replacement: "return ".into(),
                        }],
                    )
                } else {
                    d.help("return_value")
                };
            }
            if !returns || body.is_some_and(|body| !body.annotated) {
                d = d.help_edits(
                    "discard",
                    vec![Edit {
                        span: Span {
                            end: r.span.start,
                            ..r.span
                        },
                        replacement: "bind _ <- ".into(),
                    }],
                );
            }
            if let Some(ExprStmtInfo { name, value }) = reassign(ctx, r.span) {
                d = d.arg("name", &name).help_edits(
                    "reassign",
                    vec![Edit {
                        span: r.span,
                        replacement: format!("shadow {name} <- {value}"),
                    }],
                );
            }
        }
        ctx.diagnostic(d.build());
        self.poison(&[expected.clone(), found.clone()]);
    }
    pub fn solve(&mut self, ctx: &mut Body<'_, '_>, constraints: Vec<Constraint>) {
        let mut declared = vec![];
        let mut normal = vec![];
        let mut bounds = vec![];
        let mut call_statements = vec![];
        let call_results: BTreeSet<_> = ctx
            .named_calls
            .iter()
            .filter_map(super::calls::PendingCall::result_var)
            .map(|v| v.0)
            .collect();
        for c in constraints {
            match c {
                Constraint::EffSub { sub, sup, reason } => {
                    self.effects.push((sub, sup, reason, None))
                }
                Constraint::Equal {
                    ref found,
                    ref reason,
                    ..
                } if matches!(reason.kind, ReasonKind::ExprStmt | ReasonKind::FnBody)
                    && matches!(found, ITy::Var(v) if call_results.contains(&v.0)) =>
                {
                    call_statements.push(c)
                }
                Constraint::Equal { ref reason, .. } | Constraint::Flow { ref reason, .. }
                    if reason.priority == Priority::Declared =>
                {
                    declared.push(c)
                }
                Constraint::Equal { .. } | Constraint::Flow { .. } => normal.push(c),
                Constraint::Class { .. } | Constraint::Try { .. } | Constraint::Resource { .. } => {
                    ctx.add(c)
                }
                Constraint::OneOf { .. } | Constraint::Equality { .. } | Constraint::Key { .. } => {
                    normal.push(c)
                }
            }
        }
        let mut deferred = vec![];
        for c in declared.into_iter().chain(normal) {
            match c {
                Constraint::OneOf { .. } | Constraint::Equality { .. } | Constraint::Key { .. } => {
                    bounds.push(c)
                }
                Constraint::Equal { .. }
                | Constraint::Flow { .. }
                | Constraint::Class { .. }
                | Constraint::Try { .. }
                | Constraint::Resource { .. }
                | Constraint::EffSub { .. } => self.solve_pair(ctx, c, &mut deferred),
            }
            bounds = self.bounds(ctx, bounds, false);
        }
        let mut calls = std::mem::take(&mut ctx.named_calls);
        for call in &calls {
            if let Some(constraints) = super::calls::prepare(self, call) {
                for c in constraints {
                    self.solve_pair(ctx, c, &mut deferred);
                }
            }
        }
        // 呼び出しの Flow と試行がほかの呼び出しの契約を定める場合も再訪する。
        // 未確定の位置の等しさへの切り替えは、既知の情報を使い切ってから行う
        // （設計書 02-05「制約の解決」）。
        loop {
            let before = (calls.len(), deferred.len());
            let mut waiting = vec![];
            for call in calls {
                if super::calls::ready(self, &call) {
                    for c in super::calls::resolve(ctx, self, call) {
                        self.solve_pair(ctx, c, &mut deferred);
                    }
                } else {
                    waiting.push(call);
                }
            }
            calls = waiting;
            let mut remaining = vec![];
            for c in deferred {
                self.solve_pair(ctx, c, &mut remaining);
            }
            deferred = remaining;
            bounds = self.bounds(ctx, bounds, false);
            let special_before = ctx
                .constraints
                .iter()
                .filter(|c| matches!(c, Constraint::Try { .. } | Constraint::Resource { .. }))
                .count();
            ctx.solver = std::mem::take(self);
            super::effects::solve_ready(ctx);
            *self = std::mem::take(&mut ctx.solver);
            let mut special_after = 0usize;
            for c in std::mem::take(&mut ctx.constraints) {
                match c {
                    Constraint::EffSub { sub, sup, reason } => {
                        self.effects.push((sub, sup, reason, None));
                    }
                    Constraint::Equal { .. } | Constraint::Flow { .. } => {
                        self.solve_pair(ctx, c, &mut deferred);
                    }
                    Constraint::OneOf { .. }
                    | Constraint::Equality { .. }
                    | Constraint::Key { .. } => {
                        bounds.push(c);
                    }
                    Constraint::Try { .. } | Constraint::Resource { .. } => {
                        special_after = special_after.saturating_add(1);
                        ctx.add(c);
                    }
                    Constraint::Class { .. } => ctx.add(c),
                }
            }
            if before == (calls.len(), deferred.len()) && special_before == special_after {
                if deferred.is_empty() {
                    break;
                }
                for c in std::mem::take(&mut deferred) {
                    if let Constraint::Flow { from, to, reason } = c
                        && let Err(code) = self.equal(&to, &from, &reason)
                    {
                        self.pair_failure(ctx, code, &to, &from, &reason);
                    }
                }
            }
        }
        // 保留した呼び出しの結果が決まってから Unit との一致を調べる。
        // 捨てた値を関数型全体の不一致へ付け替えない（設計書 02-05「誤りの報告と検査の継続」）。
        for c in call_statements {
            self.solve_pair(ctx, c, &mut deferred);
        }
        ctx.solver = std::mem::take(self);
        super::effects::solve_special(ctx);
        *self = std::mem::take(&mut ctx.solver);
        for (code, expected, found, reason, escaped) in std::mem::take(&mut self.late) {
            self.failure_with_escape(ctx, code, &expected, &found, &reason, escaped);
        }
        for (code, expected, found, reason, escaped) in std::mem::take(&mut self.dependent_late) {
            // 移し替えた報告から伝わった誤りの型は、両辺を調べる failure_with_escape が抑える。
            self.failure_with_escape(ctx, code, &expected, &found, &reason, escaped);
        }
        bounds = self.bounds(ctx, bounds, false);
        self.solve_effects(ctx);
        // 型クラスの失敗による誤りの伝播も済ませてから、未確定の契約を報告する。
        // 辞書の解決は型を推測せず、確定した型を検査する（設計書 02-05「型クラスの制約の解決」）。
        ctx.solver = std::mem::take(self);
        super::traits::solve_ready_classes(ctx);
        *self = std::mem::take(&mut ctx.solver);
        for call in calls {
            super::calls::unresolved(ctx, self, call);
        }
        for (callee, span, call_span) in std::mem::take(&mut ctx.call_contracts) {
            if let ITy::Fn(f) = self.zonk(&callee)
                && !self.contains_error(&callee)
                && matches!(self.resolve_contract(&f.contract), IContract::Var(_))
            {
                if !super::calls::has_child_error(ctx, call_span) {
                    ctx.diagnostic(
                        DiagBuilder::new(DiagCode::E0455)
                            .primary(span)
                            .help("annotation")
                            .build(),
                    );
                }
                self.poison(std::slice::from_ref(&callee));
            }
        }
        // 未確定の契約から派生した型変数を誤りとして回復した後でだけ、
        // 型の曖昧さを報告する（設計書 02-05「誤りの報告と検査の継続」）。
        self.bounds(ctx, bounds, true);
        ctx.solver = std::mem::take(self);
        super::traits::solve_classes(ctx);
        *self = std::mem::take(&mut ctx.solver);
    }
    fn solve_pair(
        &mut self,
        ctx: &mut Body<'_, '_>,
        c: Constraint,
        deferred: &mut Vec<Constraint>,
    ) {
        match c {
            Constraint::Equal {
                expected,
                found,
                reason,
            } => {
                if reason.kind == ReasonKind::LambdaReturn
                    && ctx
                        .lambda_body_ends
                        .get(&reason.span)
                        .is_some_and(|end| ctx.reported_body_values.contains(end))
                {
                    return;
                }
                if self.call_return(ctx, &expected, &found, &reason) {
                    return;
                }
                if let Err(code) = self.equal(&expected, &found, &reason) {
                    self.pair_failure(ctx, code, &expected, &found, &reason);
                }
            }
            Constraint::Flow { from, to, reason } => match self.flow(&from, &to, &reason) {
                Ok(false) => deferred.push(Constraint::Flow { from, to, reason }),
                Err(code) => self.pair_failure(ctx, code, &to, &from, &reason),
                _ => {}
            },
            Constraint::OneOf { .. }
            | Constraint::Equality { .. }
            | Constraint::Key { .. }
            | Constraint::Class { .. }
            | Constraint::Try { .. }
            | Constraint::Resource { .. }
            | Constraint::EffSub { .. } => {}
        }
    }
    // 宣言が先に決めた変数を定めるパターンとの食い違いは、その宣言への流れ込む位置で示す。
    // 型の表示は、ほかの制約で引数の型が決まった後まで待つ（設計書 02-05「誤りの報告と検査の継続」）。
    #[cold]
    #[inline(never)]
    fn pair_failure(
        &mut self,
        ctx: &mut Body<'_, '_>,
        code: DiagCode,
        expected: &ITy,
        found: &ITy,
        reason: &Reason,
    ) {
        if code == DiagCode::E0401 && reason.kind == ReasonKind::FnBody {
            // ラムダを渡す引数の制約も解いてから、戻り値の編集が可能か判定する。
            // 既に報告対象となった本体では、既定の Unit との比較を重ねない。
            ctx.reported_body_values.insert(reason.span);
            self.late.push((
                code,
                expected.clone(),
                found.clone(),
                reason.clone(),
                self.escaped.take(),
            ));
            return;
        }
        if reason.priority == Priority::Declared
            && code == DiagCode::E0401
            && matches!(reason.kind, ReasonKind::Return | ReasonKind::BindAnnotation)
            && let ITy::Var(v) = found
            && self
                .declared
                .get(&self.root(*v).0)
                .is_some_and(|r| r != reason)
        {
            // ここで誤りの型にすると、手順 2 の束縛との食い違いを報告できなくなる。
            // 移し替えた報告が変数を誤りの型にした後で、宣言どうしの報告の要否を決める。
            self.dependent_late.push((
                code,
                expected.clone(),
                found.clone(),
                reason.clone(),
                self.escaped.take(),
            ));
            return;
        }
        if reason.priority != Priority::Declared
            && code == DiagCode::E0401
            && reason.kind == ReasonKind::Pattern
            // パターンの等しい型の制約は、expected が値の側、found がパターンの側である。
            && let ITy::Var(v) = found
            && let Some(r) = self.declared.get(&self.root(*v).0).cloned()
            && !(reason.span.file == r.span.file
                && reason.span.start >= r.span.start
                && reason.span.end <= r.span.end)
        {
            self.redirected.insert(self.root(*v).0);
            let escaped = self.escaped.take();
            self.late
                .push((code, found.clone(), expected.clone(), r, escaped));
            return;
        }
        if reason.priority != Priority::Declared
            && code == DiagCode::E0401
            && [expected, found]
                .iter()
                .any(|ty| matches!(ty, ITy::Var(v) if self.redirected.contains(&self.root(*v).0)))
        {
            // 宣言の型との比較だけで生じた使う側の誤りは、束縛の報告から誤りの型が伝わるまで待つ。
            // パターンの失敗と違い、理由と位置は変えない（設計書 02-05「誤りの報告と検査の継続」）。
            self.dependent_late.push((
                code,
                expected.clone(),
                found.clone(),
                reason.clone(),
                self.escaped.take(),
            ));
            return;
        }
        self.failure(ctx, code, expected, found, reason);
    }
    fn bounds(
        &mut self,
        ctx: &mut Body<'_, '_>,
        bounds: Vec<Constraint>,
        final_pass: bool,
    ) -> Vec<Constraint> {
        // 部分の比較可能性を検査しても、E0406 は元の式の外側の型を示す。
        // 診断用の型を別に保持し、誤りの伝播は従来どおり部分の型へ行う。
        let mut pending: Vec<_> = bounds.into_iter().rev().map(|c| (c, None)).collect();
        let mut unknown = BTreeMap::new();
        let mut waiting = vec![];
        while let Some((c, outer)) = pending.pop() {
            let original = c.clone();
            let (ty, r, mode, set) = match c {
                Constraint::OneOf { ty, reason, set } => (ty, reason, Bound::Set, Some(set)),
                Constraint::Equality { ty, reason } => (ty, reason, Bound::Equality, None),
                Constraint::Key { ty, reason } => (ty, reason, Bound::Key, None),
                Constraint::Equal { .. }
                | Constraint::Flow { .. }
                | Constraint::Class { .. }
                | Constraint::Try { .. }
                | Constraint::Resource { .. }
                | Constraint::EffSub { .. } => continue,
            };
            let t = self.zonk(&ty);
            if has_error(&t) {
                continue;
            }
            // 型変数は呼び出し側の制約を待ち、最後まで幅が決まらなければ Integer にする。
            // 既知の不適合な型への診断は保つ（設計書 02-05「制約の解決」）。
            if set == Some(TySet::INT_DIV)
                && (!matches!(&t, ITy::Var(_)) || final_pass)
                && !matches!(&t, ITy::Con(TyCon::Builtin(b), args)
                    if args.is_empty() && TySet::INT_DIV.contains(*b))
            {
                let integer = super::generate::basic(B::INTEGER);
                if let Err(code) = self.equal(&integer, &ty, &r) {
                    self.pair_failure(ctx, code, &integer, &ty, &r);
                }
                continue;
            }
            match t {
                ITy::Var(v) => {
                    unknown.entry(self.root(v).0).or_insert(r);
                    waiting.push(original);
                }
                ITy::Param(i) => {
                    ctx.solver = std::mem::take(self);
                    super::traits::check_bound(ctx, i, mode, set, &r);
                    *self = std::mem::take(&mut ctx.solver);
                }
                ITy::Rigid { clause, index } => {
                    ctx.solver = std::mem::take(self);
                    super::traits::check_rigid_bound(ctx, clause, index, mode, set, &r);
                    *self = std::mem::take(&mut ctx.solver);
                }
                ITy::Con(con, args) => {
                    let mut valid = true;
                    let mut indices = vec![];
                    if mode == Bound::Set {
                        valid =
                            matches!(con,TyCon::Builtin(b) if set.is_some_and(|s|s.contains(b)));
                    } else {
                        match con {
                            TyCon::External(_) => valid = false,
                            TyCon::Builtin(b) => {
                                valid = b.def().is_some_and(|d| {
                                    !matches!(
                                        d.class,
                                        BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource
                                    )
                                }) && (mode != Bound::Key
                                    || !matches!(b, B::FLOAT | B::FLOAT32));
                                if b.def()
                                    .is_some_and(|d| d.class == BuiltinTypeClass::Collection)
                                {
                                    indices.extend(0..args.len());
                                }
                            }
                            TyCon::Adt(id) => {
                                if let Some(a) = ctx.decls.out.adts.get(id) {
                                    valid = !a.eq_summary.always
                                        && (mode != Bound::Key || !a.key_summary.always);
                                    indices.extend(
                                        a.eq_summary
                                            .depends_on
                                            .iter()
                                            .filter_map(|i| usize::try_from(*i).ok()),
                                    );
                                    if mode == Bound::Key {
                                        indices.extend(
                                            a.key_summary
                                                .depends_on
                                                .iter()
                                                .filter_map(|i| usize::try_from(*i).ok()),
                                        );
                                    }
                                }
                            }
                        }
                    }
                    if valid {
                        indices.sort_unstable();
                        indices.dedup();
                        for i in indices.into_iter().rev() {
                            if let Some(t) = args.get(i) {
                                let constraint = if mode == Bound::Key {
                                    Constraint::Key {
                                        ty: t.clone(),
                                        reason: r.clone(),
                                    }
                                } else {
                                    Constraint::Equality {
                                        ty: t.clone(),
                                        reason: r.clone(),
                                    }
                                };
                                let outer = (mode == Bound::Equality)
                                    .then(|| outer.clone().unwrap_or_else(|| ty.clone()));
                                pending.push((constraint, outer));
                            }
                        }
                    } else {
                        self.bound_failure(ctx, &ty, outer.as_ref(), &r, mode, set);
                    }
                }
                ITy::Fn(_) | ITy::App(..) | ITy::Error => {
                    self.bound_failure(ctx, &ty, outer.as_ref(), &r, mode, set)
                }
            }
        }
        if final_pass {
            for (ty, r) in &self.required {
                if let ITy::Var(v) = self.zonk(ty) {
                    unknown.entry(self.root(v).0).or_insert(r.clone());
                }
            }
            for (_, r) in unknown {
                ctx.diagnostic(
                    DiagBuilder::new(DiagCode::E0407)
                        .primary(r.span)
                        .help("annotate")
                        .build(),
                );
            }
        }
        waiting
    }
    fn contains_float(&self, ctx: &Body<'_, '_>, ty: &ITy) -> bool {
        let mut pending = vec![self.zonk(ty)];
        while let Some(ty) = pending.pop() {
            match ty {
                ITy::Con(TyCon::Builtin(B::FLOAT | B::FLOAT32), _) => return true,
                ITy::Con(TyCon::Adt(id), args) => {
                    if let Some(adt) = ctx.decls.out.adts.get(id) {
                        if adt.key_summary.always {
                            return true;
                        }
                        for i in &adt.key_summary.depends_on {
                            if let Some(t) = usize::try_from(*i).ok().and_then(|i| args.get(i)) {
                                pending.push(t.clone());
                            }
                        }
                    }
                }
                ITy::Con(_, args) => pending.extend(args),
                ITy::Fn(_)
                | ITy::App(..)
                | ITy::Var(_)
                | ITy::Param(_)
                | ITy::Rigid { .. }
                | ITy::Error => {}
            }
        }
        false
    }
    fn bound_failure(
        &mut self,
        ctx: &mut Body<'_, '_>,
        ty: &ITy,
        outer: Option<&ITy>,
        r: &Reason,
        mode: Bound,
        set: Option<TySet>,
    ) {
        let code = if mode == Bound::Key {
            DiagCode::E0423
        } else if mode == Bound::Equality {
            DiagCode::E0406
        } else if r.kind == ReasonKind::Interp {
            DiagCode::E0422
        } else {
            DiagCode::E0405
        };
        let mut d = DiagBuilder::new(code)
            .primary(r.span)
            .arg("ty", self.show(ctx, outer.unwrap_or(ty)))
            .arg("op", op_text(&r.kind));
        if code == DiagCode::E0423 && self.contains_float(ctx, ty) {
            d = d.help("float");
        }
        if code == DiagCode::E0422 {
            d = self.interpolation_help(ctx, ty, r.span, d);
        }
        if code == DiagCode::E0406 {
            d = d.note("why");
        }
        if let Some(set) = set
            && code == DiagCode::E0405
        {
            let allowed =
                crate::diag::code_list(set.0.iter().filter_map(|b| b.def()).map(|d| d.name));
            d = d.arg("allowed", allowed).note("allowed");
        }
        if code == DiagCode::E0405
            && matches!(
                r.kind,
                ReasonKind::Operator {
                    op: OpName::Bin(BinOp::Div)
                }
            )
            && matches!(self.zonk(ty), ITy::Con(TyCon::Builtin(b), _) if TySet::INT_DIV.contains(b))
        {
            d = d.help_edits(
                "div",
                vec![Edit {
                    span: r.related.unwrap_or(r.span),
                    replacement: "div".into(),
                }],
            );
        }
        ctx.diagnostic(d.build());
        self.poison(std::slice::from_ref(ty));
    }

    /// `Show` の実装とこのモジュールの import に合う、文字列への変換の案内を作る。
    pub(super) fn interpolation_help(
        &self,
        ctx: &Body<'_, '_>,
        ty: &ITy,
        span: Span,
        d: DiagBuilder,
    ) -> DiagBuilder {
        let Some(alias) = super::traits::trait_import_alias(ctx, span) else {
            return d.help("import_show");
        };
        let Some(class) = ctx.decls.resolved.stdlib("Benitoite.Trait.Show") else {
            return d.help("convert");
        };
        if !super::traits::implements(ctx, self, class, ty) {
            return d.help("convert");
        }
        let function = format!("{alias}.Show.show");
        let edits = source(ctx.decls.sources, span)
            .map(|expr| Edit {
                span,
                replacement: format!("{function}({expr})"),
            })
            .into_iter()
            .collect();
        d.arg("function", function).help_edits("show", edits)
    }
    fn solve_effects(&mut self, ctx: &mut Body<'_, '_>) {
        loop {
            let mut changed = false;
            for (sub, sup, r, pair) in &self.effects {
                if pair
                    .as_ref()
                    .is_some_and(|(a, b)| self.contains_error(a) || self.contains_error(b))
                {
                    continue;
                }
                let Some(v) = sup.var else {
                    continue;
                };
                let current = self.finalize_effect(sub);
                let origins = sub
                    .var
                    .and_then(|v| usize::try_from(v.0).ok().and_then(|i| self.effs.get(i)))
                    .map(|s| s.origins.clone())
                    .unwrap_or_default();
                if let Some(state) = usize::try_from(v.0).ok().and_then(|i| self.effs.get_mut(i)) {
                    for elem in elements(&current) {
                        if !includes(&sup.fixed, elem) && !includes(&state.set, elem) {
                            insert(&mut state.set, elem);
                            state
                                .origins
                                .insert(elem, origins.get(&elem).copied().unwrap_or(r.span));
                            changed = true;
                        }
                    }
                }
            }
            if !changed {
                break;
            }
        }
        let mut reported = BTreeSet::new();
        let items = std::mem::take(&mut self.effects);
        for (sub, sup, r, pair) in items {
            if pair
                .as_ref()
                .is_some_and(|(a, b)| self.contains_error(a) || self.contains_error(b))
            {
                continue;
            }
            if sup.var.is_some() {
                continue;
            }
            for elem in elements(&self.finalize_effect(&sub)) {
                if includes(&sup.fixed, elem) {
                    continue;
                }
                if let Some((a, b)) = &pair {
                    if reported.insert((r.span.file.0, r.span.start.0, r.span.end.0)) {
                        self.failure_with_escape(ctx, DiagCode::E0401, b, a, &r, None);
                    }
                    break;
                }
                let origin = sub
                    .var
                    .and_then(|v| usize::try_from(v.0).ok().and_then(|i| self.effs.get(i)))
                    .and_then(|s| s.origins.get(&elem))
                    .copied()
                    .unwrap_or(r.span);
                let mut set = EffectSet::empty();
                insert(&mut set, elem);
                let shown = self.show(
                    ctx,
                    &ITy::Fn(Box::new(IFnTy {
                        contract: IContract::Known(Vec::new()),
                        params: vec![],
                        ret: super::context::lift(&super::decls::unit()),
                        effect: fixed(set),
                    })),
                );
                let name = shown.split_once(" uses ").map_or("_", |(_, s)| s);
                let d = match r.kind {
                    ReasonKind::LazyBody => super::effects::effect_failure(ctx, &r, name, origin),
                    ReasonKind::MatchGuard => {
                        super::pattern_ext::effect_failure(ctx, &r, name, origin)
                    }
                    ReasonKind::CallArg { .. }
                    | ReasonKind::Call
                    | ReasonKind::IfCondition
                    | ReasonKind::IfBranches
                    | ReasonKind::IfNoElse
                    | ReasonKind::MatchArms
                    | ReasonKind::Pattern
                    | ReasonKind::Alternatives
                    | ReasonKind::ListElement
                    | ReasonKind::ListSpread
                    | ReasonKind::BindAnnotation
                    | ReasonKind::LambdaReturn
                    | ReasonKind::LambdaUses
                    | ReasonKind::Return
                    | ReasonKind::FnBody
                    | ReasonKind::FnUses
                    | ReasonKind::ExprStmt
                    | ReasonKind::Operands { .. }
                    | ReasonKind::Logic { .. }
                    | ReasonKind::Operator { .. }
                    | ReasonKind::Interp
                    | ReasonKind::CallEffect
                    | ReasonKind::BuiltinParam { .. }
                    | ReasonKind::ParamBound { .. }
                    | ReasonKind::RecordField { .. }
                    | ReasonKind::RecordBase
                    | ReasonKind::ClassUse { .. }
                    | ReasonKind::ImplSuper { .. }
                    | ReasonKind::Try
                    | ReasonKind::WithResource
                    | ReasonKind::WithState
                    | ReasonKind::HandleBody
                    | ReasonKind::HandleClause
                    | ReasonKind::Resume
                    | ReasonKind::ConstValue => super::context::effect_diagnostic(
                        if r.kind == ReasonKind::LambdaUses {
                            DiagCode::E0502
                        } else {
                            DiagCode::E0501
                        },
                        &r,
                        name,
                        origin,
                    ),
                };
                ctx.diagnostic(d);
            }
        }
    }
}
pub(super) fn has_error(t: &ITy) -> bool {
    match t {
        ITy::Error => true,
        ITy::Con(_, a) | ITy::App(_, a) => a.iter().any(has_error),
        ITy::Fn(f) => f.params.iter().any(has_error) || has_error(&f.ret),
        ITy::Var(_) | ITy::Param(_) | ITy::Rigid { .. } => false,
    }
}
fn elements(set: &EffectSet) -> Vec<Elem> {
    set.names
        .iter()
        .map(|e| Elem::Name(*e))
        .chain(set.vars.iter().map(|v| Elem::Var(*v)))
        .collect()
}
fn includes(set: &EffectSet, e: Elem) -> bool {
    match e {
        Elem::Name(e) => set.names.contains(&e),
        Elem::Var(v) => set.vars.contains(&v),
    }
}
fn insert(set: &mut EffectSet, e: Elem) {
    match e {
        Elem::Name(e) => set.insert_name(e),
        Elem::Var(v) => set.insert_var(v),
    }
}
pub(super) fn source(sources: &crate::base::SourceTable, span: Span) -> Option<&str> {
    let text = sources.get(span.file)?.text();
    let start = usize::try_from(span.start.0).ok()?;
    let end = usize::try_from(span.end.0).ok()?;
    std::str::from_utf8(text.get(start..end)?).ok()
}
fn op_text(r: &ReasonKind) -> String {
    match r {
        ReasonKind::Operator { op } | ReasonKind::Operands { op } | ReasonKind::Logic { op } => {
            super::text::operator_spelling(*op).into()
        }
        ReasonKind::BuiltinParam { name } | ReasonKind::ParamBound { name } => name.clone(),
        ReasonKind::CallArg { .. }
        | ReasonKind::Call
        | ReasonKind::IfCondition
        | ReasonKind::IfBranches
        | ReasonKind::IfNoElse
        | ReasonKind::MatchArms
        | ReasonKind::MatchGuard
        | ReasonKind::Pattern
        | ReasonKind::Alternatives
        | ReasonKind::ListElement
        | ReasonKind::ListSpread
        | ReasonKind::BindAnnotation
        | ReasonKind::LambdaReturn
        | ReasonKind::LambdaUses
        | ReasonKind::Return
        | ReasonKind::FnBody
        | ReasonKind::FnUses
        | ReasonKind::ExprStmt
        | ReasonKind::Interp
        | ReasonKind::CallEffect
        | ReasonKind::RecordField { .. }
        | ReasonKind::RecordBase
        | ReasonKind::ClassUse { .. }
        | ReasonKind::ImplSuper { .. }
        | ReasonKind::Try
        | ReasonKind::WithResource
        | ReasonKind::WithState
        | ReasonKind::LazyBody
        | ReasonKind::HandleBody
        | ReasonKind::HandleClause
        | ReasonKind::Resume
        | ReasonKind::ConstValue => super::text::operator_spelling(OpName::Bin(BinOp::Eq)).into(),
    }
}
struct ExprStmtInfo {
    name: String,
    value: String,
}
fn reassign(ctx: &Body<'_, '_>, span: Span) -> Option<ExprStmtInfo> {
    let (lhs, rhs) = ctx.expr_stmts.get(&span)?;
    let name = source(ctx.decls.sources, *lhs)?.to_owned();
    let value = source(ctx.decls.sources, *rhs)?.to_owned();
    Some(ExprStmtInfo { name, value })
}
