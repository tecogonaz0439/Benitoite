//! 単一化、流れ込む制約、エフェクトの最小解（設計書 02-05「制約の解決」）。
use super::context::{Body, fixed};
use super::infer::*;
use super::limits::{TypeBudget, TypeLimit};
use crate::base::{NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Edit};
use crate::resolve::ResolveOutput;
use crate::syntax::ast::{BinOp, UnOp};
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
type EffectConstraint = (IEffect, IEffect, Reason, Option<(ITy, ITy)>);

/// 一つの本体でだけ有効な型変数とエフェクト変数の状態。
#[derive(Default)]
pub(super) struct Solver {
    vars: Vec<Var>,
    clauses: Vec<NodeId>,
    heads: BTreeMap<u32, TyHead>,
    effs: Vec<EffectState>,
    effects: Vec<EffectConstraint>,
    required: Vec<(ITy, Reason)>,
    // 宣言の型への流れ込む制約（`return` など）が先に結び付けた型変数と、その理由。呼び出しの
    // 戻り値の型の食い違いを、宣言の側の理由で報告するために使う（設計書 02-05「誤りの報告と検査の継続」）。
    declared: BTreeMap<u32, Reason>,
    // call_return が後へ回した失敗の報告。どちらの段で積んだものも、solve の終わりで報告する。
    late: Vec<(DiagCode, ITy, ITy, Reason)>,
}
impl Solver {
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
    /// 型注釈の型を参照の共有先に置き、誤りの印も局所の使い先へ伝える（ADR 0024）。
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
                    // 予算を消費する。子を作る前に拒否する意味は変えない（ADR 0353）。
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
    pub fn finalize(&self, t: &ITy, r: &ResolveOutput) -> Ty {
        match self.zonk(t) {
            ITy::Var(_) | ITy::Error => super::decls::unit(),
            ITy::Con(c, a) => Ty::Con(c, a.iter().map(|t| self.finalize(t, r)).collect()),
            ITy::Fn(f) => Ty::Fn(Box::new(FnTy {
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
                ITy::Rigid { clause, .. } if !clauses.contains(&clause) => {
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
        self.equal_with_outer(a, b, reason, a, b)
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
            params: x.params.clone(),
            ret: y.ret.clone(),
            effect: x.effect.clone(),
        }));
        if let Err(code) = self.equal(&shape, found, reason) {
            self.failure(ctx, code, expected, found, reason);
            return true;
        }
        if let Err(code) = self.equal(&x.ret, &y.ret, &r) {
            self.late.push((code, x.ret.clone(), y.ret.clone(), r));
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
        let names: Vec<_> = ctx
            .scheme
            .type_params
            .iter()
            .map(|p| p.name.clone())
            .collect();
        self.diagnostic_type(t).show(&TyNames {
            adts: &ctx.decls.out.adts,
            effects: &ctx.decls.out.effects,
            type_params: &names,
            effect_params: &ctx.scheme.effect_params,
        })
    }
    // 出力用の finalize の既定値を診断へ持ち込まない。未確定の変数には
    // 名前の表にない番号を用い、Ty::show の `_` の表示を使う（設計書 02-05「誤りの報告と検査の継続」）。
    fn diagnostic_type(&self, t: &ITy) -> Ty {
        match self.zonk(t) {
            ITy::Var(_) | ITy::Error => Ty::Param(u32::MAX),
            ITy::Con(c, a) => Ty::Con(c, a.iter().map(|t| self.diagnostic_type(t)).collect()),
            ITy::Fn(f) => Ty::Fn(Box::new(FnTy {
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
        }
        let mut exp = self.show(ctx, expected);
        let shown = self.show(ctx, expected);
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
        let mut f = self.show(ctx, found);
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
        if code == DiagCode::E0402
            && let Some(span) = r.related
        {
            d = d.secondary(span, "declared");
        }
        if code == DiagCode::E0401 {
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
        }
        if code == DiagCode::E0416 {
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
        for c in constraints {
            match c {
                Constraint::EffSub { sub, sup, reason } => {
                    self.effects.push((sub, sup, reason, None))
                }
                Constraint::Flow { ref reason, .. } if reason.priority == Priority::Declared => {
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
        loop {
            let mut remaining = vec![];
            let n = deferred.len();
            for c in deferred {
                self.solve_pair(ctx, c, &mut remaining);
            }
            if remaining.len() == n {
                for c in remaining {
                    if let Constraint::Flow { from, to, reason } = c
                        && let Err(code) = self.equal(&to, &from, &reason)
                    {
                        self.failure(ctx, code, &to, &from, &reason);
                    }
                }
                break;
            }
            deferred = remaining;
        }
        bounds = self.bounds(ctx, bounds, false);
        // F09 の試行とリソースの検査がこの状態に制約を足せるように移して戻す（F07 フック E5）。
        ctx.solver = std::mem::take(self);
        super::effects::solve_special(ctx);
        *self = std::mem::take(&mut ctx.solver);
        let mut deferred = vec![];
        for c in std::mem::take(&mut ctx.constraints) {
            match c {
                Constraint::EffSub { sub, sup, reason } => {
                    self.effects.push((sub, sup, reason, None))
                }
                Constraint::Equal { .. } | Constraint::Flow { .. } => {
                    self.solve_pair(ctx, c, &mut deferred)
                }
                Constraint::OneOf { .. } | Constraint::Equality { .. } | Constraint::Key { .. } => {
                    bounds.push(c)
                }
                Constraint::Class { .. } | Constraint::Try { .. } | Constraint::Resource { .. } => {
                    ctx.add(c)
                }
            }
        }
        for c in deferred {
            if let Constraint::Flow { from, to, reason } = c
                && let Err(code) = self.equal(&to, &from, &reason)
            {
                self.failure(ctx, code, &to, &from, &reason);
            }
        }
        for (code, expected, found, reason) in std::mem::take(&mut self.late) {
            self.failure(ctx, code, &expected, &found, &reason);
        }
        self.bounds(ctx, bounds, true);
        self.solve_effects(ctx);
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
                if self.call_return(ctx, &expected, &found, &reason) {
                    return;
                }
                if let Err(code) = self.equal(&expected, &found, &reason) {
                    self.failure(ctx, code, &expected, &found, &reason);
                }
            }
            Constraint::Flow { from, to, reason } => match self.flow(&from, &to, &reason) {
                Ok(false) => deferred.push(Constraint::Flow { from, to, reason }),
                Err(code) => self.failure(ctx, code, &to, &from, &reason),
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
                Constraint::OneOf { ty, reason, set } => (ty, reason, 0, Some(set)),
                Constraint::Equality { ty, reason } => (ty, reason, 1, None),
                Constraint::Key { ty, reason } => (ty, reason, 2, None),
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
                    if mode == 0 {
                        valid =
                            matches!(con,TyCon::Builtin(b) if set.is_some_and(|s|s.contains(b)));
                    } else {
                        match con {
                            TyCon::Builtin(b) => {
                                valid = b.def().is_some_and(|d| {
                                    !matches!(
                                        d.class,
                                        BuiltinTypeClass::Opaque | BuiltinTypeClass::Resource
                                    )
                                }) && (mode != 2 || b != B::FLOAT);
                                if b.def()
                                    .is_some_and(|d| d.class == BuiltinTypeClass::Collection)
                                {
                                    indices.extend(0..args.len());
                                }
                            }
                            TyCon::Adt(id) => {
                                if let Some(a) = ctx.decls.out.adts.get(id) {
                                    valid = !a.eq_summary.always
                                        && (mode != 2 || !a.key_summary.always);
                                    indices.extend(
                                        a.eq_summary
                                            .depends_on
                                            .iter()
                                            .filter_map(|i| usize::try_from(*i).ok()),
                                    );
                                    if mode == 2 {
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
                                let constraint = if mode == 2 {
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
                                let outer = (mode == 1)
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
                ITy::Con(TyCon::Builtin(B::FLOAT), _) => return true,
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
        mode: u8,
        set: Option<TySet>,
    ) {
        let code = if mode == 2 {
            DiagCode::E0423
        } else if mode == 1 {
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
            let allowed = set
                .0
                .iter()
                .filter_map(|b| b.def())
                .map(|d| format!("`{}`", d.name))
                .collect::<Vec<_>>()
                .join(", ");
            d = d.arg("allowed", allowed).note("allowed");
        }
        if code == DiagCode::E0405
            && matches!(
                r.kind,
                ReasonKind::Operator {
                    op: OpName::Bin(BinOp::Div)
                }
            )
            && self.zonk(ty) == ITy::Con(TyCon::Builtin(B::INTEGER), vec![])
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

    fn interpolation_help(
        &self,
        ctx: &Body<'_, '_>,
        ty: &ITy,
        span: Span,
        d: DiagBuilder,
    ) -> DiagBuilder {
        // 同じモジュールの import から別名を引く。ほかのモジュールが取り込んだ
        // Trait はこの位置から参照できない（設計書 01-03「モジュールと import」）。
        let alias = ctx
            .decls
            .asts
            .iter()
            .find(|m| m.file == span.file)
            .and_then(|m| {
                m.imports.iter().find(|i| {
                    i.path
                        .iter()
                        .map(|n| n.text.as_str())
                        .eq(["Benitoite", "Trait"])
                })
            })
            .and_then(|i| i.alias.as_ref().or_else(|| i.path.last()));
        let Some(alias) = alias else {
            return d.help("import_show");
        };
        let Some(class) = ctx.decls.resolved.stdlib("Benitoite.Trait.Show") else {
            return d.help("convert");
        };
        if !super::traits::implements(ctx, self, class, ty) {
            return d.help("convert");
        }
        let function = format!("{}.Show.show", alias.text);
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
                        self.failure(ctx, DiagCode::E0401, b, a, &r);
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
            match op {
                OpName::Un(UnOp::Neg) => "-",
                OpName::Un(UnOp::Not) => "not",
                OpName::Bin(b) => match b {
                    BinOp::Add => "+",
                    BinOp::Sub => "-",
                    BinOp::Mul => "*",
                    BinOp::Div => "/",
                    BinOp::IntDiv => "div",
                    BinOp::Mod => "mod",
                    BinOp::Eq => "=",
                    BinOp::Ne => "<>",
                    BinOp::Lt => "<",
                    BinOp::Le => "<=",
                    BinOp::Gt => ">",
                    BinOp::Ge => ">=",
                    BinOp::And => "and",
                    BinOp::Or => "or",
                },
            }
            .into()
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
        | ReasonKind::ConstValue => "=".into(),
    }
}
struct ExprStmtInfo {
    name: String,
    value: String,
}
fn reassign(ctx: &Body<'_, '_>, span: Span) -> Option<ExprStmtInfo> {
    use crate::syntax::ast::Expr;
    let e = ctx.expr_stmts.iter().find(|(_, e)| e.span() == span)?.1;
    let Expr::Binary(b) = e else {
        return None;
    };
    if b.op != BinOp::Eq {
        return None;
    }
    let Expr::Name(n) = b.lhs.as_ref() else {
        return None;
    };
    let name = source(ctx.decls.sources, n.span)?.to_owned();
    let value = source(ctx.decls.sources, b.rhs.span())?.to_owned();
    Some(ExprStmtInfo { name, value })
}
