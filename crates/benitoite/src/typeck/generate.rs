//! 本体ごとの制約の生成と、解いた後の検査と表への記録（設計書 02-05「制約の生成」「本体の後の検査」）。
//!
//! 一つの関数の本体を先頭から辿り、構文ごとに制約を作る。子を左から右に辿り終えた後に、その構文の
//! 制約を加える（02-05「制約の解決」の最後の段落）。辿り終えたら `Solver` で解き、決まらなかった型の
//! 誤り（E0407）とパターンの検査（E0601・E0602）を報告し、推論した型を表に書く。
//!
//! 再帰の深さ: AST を辿る関数は再帰で書く。深さは構文解析器が抑える AST の深さ（1000）の定数倍に
//! 収まる（実装プラン 00-02「再帰の深さ」）。最適化しないビルドでも既定のスタックに収まるように、
//! 再帰の経路にある関数（`expr` など）は構文ごとの処理を別の関数に分け、一段の枠を小さく保つ。

use super::TypeArgs;
use super::decls::{Decls, TypeCx};
use super::infer::{
    Constraint, EffInfer, IEffect, IFnTy, ITy, OpName, Priority, Reason, ReasonKind, TyVar,
};
use super::patterns::{MatchIssue, Pat, check_match};
use super::solve::{SolveEnv, Solver};
use crate::base::{BindingId, BindingMap, NodeId, NodeMap, Span};
use crate::builtins::table;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::{
    Arg, BinOp, BinaryExpr, Block, CallExpr, CtorPat, ElseBranch, Expr, FnDecl, IfExpr, LambdaExpr,
    LetName, LetStmt, LitPat, Literal, MatchArm, MatchExpr, NameExpr, Param, Pattern, PipeExpr,
    Stmt, UnOp, UnaryExpr,
};
use crate::types::{EffectSet, ParamConstraint, Scheme, Ty, TyCon, TySet};

/// 本体の検査が参照する、検査の全体で共通の情報。
pub(super) struct Global<'a> {
    pub resolved: &'a ResolveOutput,
    pub decls: &'a Decls,
}

/// 型検査の出力のうち、本体の検査が書く表（02-05「出力」）。
#[derive(Default)]
pub(super) struct Tables {
    pub expr_types: NodeMap<Ty>,
    pub type_args: NodeMap<TypeArgs>,
    pub operand_types: NodeMap<Ty>,
    pub lambda_effects: NodeMap<EffectSet>,
}

/// いま辿っている本体のエフェクト E の種類。呼び出しの含まれる制約の理由を選ぶ（作業 T15「本体の制約の生成」）。
#[derive(Clone, Copy)]
enum BodyEff {
    /// トップレベルの関数の本体。`related` は `uses` の並び（なければ関数の名前）の位置
    Fn { related: Span },
    /// `uses` を書いたラムダの本体。`related` はその `uses` の並びの位置
    Lambda { related: Span },
    /// `uses` を書かないラムダと、プレースホルダを含む呼び出しの本体（エフェクトは変数）
    Var,
}

/// 一つの `match` の、解いた後に行うパターンの検査のための記録。
struct MatchRec<'a> {
    m: &'a MatchExpr,
    scrutinee: ITy,
    /// パターンで E0408・E0412・E0413 を報告したか、壊れた構成子を使った
    skip: bool,
    /// パターンの型を求める等しい制約の両辺（期待した型、パターンの型）。どれかが解けなければ
    /// 検査しない（派生した誤りを出さないため。02-05「誤りの報告と検査の継続」）
    pairs: Vec<(ITy, ITy)>,
}

/// 一つの `match` のパターンを辿る間の記録。
#[derive(Default)]
struct PatAcc {
    bad: bool,
    pairs: Vec<(ITy, ITy)>,
}

/// 呼び出しの一つの引数の型と、理由に使う情報。
struct ArgTy {
    ty: ITy,
    span: Span,
    int_literal: Option<String>,
}

fn arg_ty(e: &Expr, ty: ITy) -> ArgTy {
    ArgTy {
        ty,
        span: e.span(),
        int_literal: int_literal_text(e),
    }
}

/// 一つの本体の制約の生成の状態。本体ごとに作って捨てる（02-05「検査の手順」、ADR 0015）。
struct Gen<'a> {
    g: &'a Global<'a>,
    solver: Solver,
    constraints: Vec<Constraint>,
    diags: Vec<Diagnostic>,
    /// 局所の束縛の型。多相にしない（ADR 0009）
    locals: BindingMap<ITy>,
    /// いま辿っている本体のエフェクト E とその種類
    effect: IEffect,
    effect_kind: BodyEff,
    rec_types: Vec<(NodeId, ITy)>,
    rec_args: Vec<(NodeId, Vec<ITy>, Vec<IEffect>)>,
    rec_operands: Vec<(NodeId, ITy)>,
    rec_lambdas: Vec<(NodeId, IEffect)>,
    matches: Vec<MatchRec<'a>>,
}

/// 関数の本体を一つ検査し、表に書き、診断を加える（02-05「検査の手順」の手順 2）。
/// 壊れた宣言の本体は検査しない（decls.rs の冒頭）。
pub(super) fn check_fn(
    g: &Global<'_>,
    f: &FnDecl,
    tables: &mut Tables,
    diags: &mut Vec<Diagnostic>,
) {
    let Some(b) = g.resolved.decls.get(f.id).copied() else {
        return;
    };
    if g.decls.broken.contains(&b) {
        return;
    }
    let Some(scheme) = g.decls.decl_types.get(b) else {
        return;
    };
    let related = f.uses.as_ref().map_or(f.name.span, |u| u.span);
    let effect = IEffect {
        fixed: scheme.effects.clone(),
        var: None,
    };
    let mut st = Gen::new(g, effect, BodyEff::Fn { related });
    for (p, ty) in f.params.iter().zip(&scheme.params) {
        st.bind_param(p, to_ity(ty, None));
    }
    let body = st.block(&f.body);
    // 関数の本体と宣言した戻り値の型は、宣言から生じた流れ込む制約として先に解く（02-05「制約の解決」の手順 1）。
    let mut reason = declared_reason(result_span(&f.body), ReasonKind::FnBody, f.ret.span());
    reason.int_literal = result_expr(&f.body).and_then(int_literal_text);
    st.constraints.push(Constraint::Flow {
        from: body,
        to: to_ity(&scheme.ret, None),
        reason,
    });
    let type_params: Vec<String> = scheme.type_params.iter().map(|t| t.name.clone()).collect();
    st.finish(&type_params, &scheme.effect_params, tables, diags);
}

// ---------------- 理由と型の補助 ----------------

fn reason(span: Span, kind: ReasonKind) -> Reason {
    Reason {
        span,
        kind,
        related: None,
        priority: Priority::Normal,
        int_literal: None,
    }
}

/// 宣言と型注釈から生じた流れ込む制約の理由。`related` は型注釈の位置（02-05「制約の解決」の手順 1）。
fn declared_reason(span: Span, kind: ReasonKind, annotation: Span) -> Reason {
    Reason {
        span,
        kind,
        related: Some(annotation),
        priority: Priority::Declared,
        int_literal: None,
    }
}

/// 型を求められた式が 10 進の整数リテラルなら、その字面（E0401 の修正案 `float_literal` に使う）。
/// 整数リテラルに直接付けた単項の `-` も、符号を含めたリテラルとして扱う。
fn int_literal_text(e: &Expr) -> Option<String> {
    if let Expr::Lit(l) = e
        && let Literal::Int { radix: 10, digits } = &l.lit
    {
        return Some(digits.clone());
    }
    if let Expr::Unary(u) = e
        && u.op == UnOp::Neg
        && let Expr::Lit(_) = u.operand.as_ref()
    {
        return int_literal_text(&u.operand).map(|d| format!("-{d}"));
    }
    None
}

/// ブロックの値になる最後の式。
fn result_expr(b: &Block) -> Option<&Expr> {
    match b.stmts.last() {
        Some(Stmt::Expr(e)) => Some(e),
        Some(Stmt::Let(_) | Stmt::Error(_)) | None => None,
    }
}

/// ブロックの値の位置。最後の文が式ならその式、そうでなければブロック全体。
fn result_span(b: &Block) -> Span {
    result_expr(b).map_or(b.span, Expr::span)
}

/// 型パラメータとエフェクト変数の置き換え。
type Subst<'s> = Option<(&'s [ITy], &'s [EffInfer])>;

/// 型検査を終えた型を推論の型にする。`sub` があれば、型パラメータとエフェクト変数を置き換える
/// （02-05「制約の生成」の「多相な名前」）。型の入れ子の深さは型注釈の入れ子の深さで決まり、
/// 構文解析器の上限（1000）に近づきうるので、一段の枠を小さく保つように、反復子の連鎖を使わずに書く。
fn to_ity(ty: &Ty, sub: Subst<'_>) -> ITy {
    match ty {
        Ty::Con(c, args) => {
            let mut out = Vec::with_capacity(args.len());
            for a in args {
                out.push(to_ity(a, sub));
            }
            ITy::Con(*c, out)
        }
        Ty::Fn(f) => to_ity_fn(f, sub),
        Ty::Param(i) => match sub {
            Some((tys, _)) => usize::try_from(*i)
                .ok()
                .and_then(|i| tys.get(i))
                .cloned()
                .unwrap_or(ITy::Error),
            None => ITy::Param(*i),
        },
    }
}

fn to_ity_fn(f: &crate::types::FnTy, sub: Subst<'_>) -> ITy {
    let mut params = Vec::with_capacity(f.params.len());
    for p in &f.params {
        params.push(to_ity(p, sub));
    }
    let ret = to_ity(&f.ret, sub);
    ITy::Fn(Box::new(IFnTy {
        params,
        ret,
        effect: to_ieffect(&f.effects, sub),
    }))
}

/// エフェクトの集合を推論のエフェクトにする。置き換えるエフェクト変数は、一つの集合に高々一つである
/// （一つの `uses` のエフェクト変数は一つまで。01-06「関数の型とエフェクト」）。
fn to_ieffect(e: &EffectSet, sub: Subst<'_>) -> IEffect {
    let Some((_, effs)) = sub else {
        return IEffect {
            fixed: e.clone(),
            var: None,
        };
    };
    let mut fixed = EffectSet {
        io: e.io,
        vars: Vec::new(),
    };
    let mut var = None;
    for v in &e.vars {
        match usize::try_from(v.0).ok().and_then(|i| effs.get(i)) {
            Some(r) if var.is_none() => var = Some(*r),
            // 宣言の検査（E0417）により起きない。起きても変数を増やさず、最初の変数だけを残す。
            Some(_) => {}
            None => fixed.insert_var(*v),
        }
    }
    IEffect { fixed, var }
}

/// 置き換えの組を作る。
fn subst<'s>(tys: &'s [ITy], effs: &'s [EffInfer]) -> Subst<'s> {
    Some((tys, effs))
}

/// 生成の時点で誤りの型と分かっている部分を含むか（02-05「誤りの報告と検査の継続」の 2 番目の項目）。
fn has_error(t: &ITy) -> bool {
    match t {
        ITy::Error => true,
        ITy::Con(_, args) => args.iter().any(has_error),
        ITy::Fn(f) => f.params.iter().any(has_error) || has_error(&f.ret),
        ITy::Var(_) | ITy::Param(_) => false,
    }
}

// ---------------- リテラルの範囲 ----------------

/// `Int` の最大値（01-04「Int」）。
const INT_MAX: u128 = 9_223_372_036_854_775_807;
/// 直接の単項の `-` の下で許す最大の絶対値（2^63）。
const INT_NEG_MAX: u128 = 9_223_372_036_854_775_808;

/// 基数と数字列から値を求める。`u128` に収まらなければ `None`（範囲の外）。
fn int_value(radix: u32, digits: &str) -> Option<u128> {
    let mut v: u128 = 0;
    for ch in digits.chars() {
        let d = ch.to_digit(radix)?;
        v = v
            .checked_mul(u128::from(radix))?
            .checked_add(u128::from(d))?;
    }
    Some(v)
}

/// 整数リテラルが範囲に収まるなら、その値（符号を含む）を返す。
fn int_in_range(radix: u32, digits: &str, negative: bool) -> Option<i64> {
    let v = int_value(radix, digits)?;
    let limit = if negative { INT_NEG_MAX } else { INT_MAX };
    if v > limit {
        return None;
    }
    let v = i128::try_from(v).ok()?;
    let v = if negative { v.checked_neg()? } else { v };
    i64::try_from(v).ok()
}

fn out_of_range(span: Span) -> Diagnostic {
    DiagBuilder::new(DiagCode::E0408)
        .primary(span)
        .note("range")
        .build()
}

/// 名前を書いたとおりに示す（`Shape.Rect`、`None`）。E0412・E0413 の `{name}` に使う。
fn written_name(qualifier: Option<&crate::syntax::ast::Name>, name: &str) -> String {
    match qualifier {
        Some(q) => format!("{}.{name}", q.text),
        None => name.to_string(),
    }
}

// ---------------- 生成 ----------------

impl<'a> Gen<'a> {
    fn new(g: &'a Global<'a>, effect: IEffect, effect_kind: BodyEff) -> Gen<'a> {
        Gen {
            g,
            solver: Solver::new(),
            constraints: Vec::new(),
            diags: Vec::new(),
            locals: BindingMap::new(),
            effect,
            effect_kind,
            rec_types: Vec::new(),
            rec_args: Vec::new(),
            rec_operands: Vec::new(),
            rec_lambdas: Vec::new(),
            matches: Vec::new(),
        }
    }

    fn record(&mut self, node: NodeId, t: &ITy) {
        self.rec_types.push((node, t.clone()));
    }

    fn equal(&mut self, expected: ITy, found: ITy, reason: Reason) {
        self.constraints.push(Constraint::Equal {
            expected,
            found,
            reason,
        });
    }

    fn flow(&mut self, from: ITy, to: ITy, reason: Reason) {
        self.constraints.push(Constraint::Flow { from, to, reason });
    }

    fn binding_of(&self, node: NodeId) -> Option<(BindingId, BindingKind)> {
        let b = self.g.resolved.refs.get(node).copied()?;
        let kind = self.g.resolved.bindings.get(b)?.kind;
        Some((b, kind))
    }

    /// 関数とラムダの引数を局所の束縛にし、表に記録する。
    fn bind_param(&mut self, p: &Param, t: ITy) {
        if let Some(b) = self.g.resolved.decls.get(p.id).copied() {
            self.locals.insert(b, t.clone());
        }
        self.rec_types.push((p.id, t));
    }

    /// 本体の型注釈を変換する。誤りを報告したら誤りの型にする。
    fn annotation(&mut self, t: &crate::syntax::ast::TypeExpr) -> ITy {
        let tcx = TypeCx {
            resolved: self.g.resolved,
            adt_arity: &self.g.decls.adt_arity,
        };
        match tcx.convert(t, &mut self.diags) {
            Some(ty) => to_ity(&ty, None),
            None => ITy::Error,
        }
    }

    // ---- 式 ----

    /// 式を辿って型を返し、表に記録する。構文ごとの処理を別の関数に分け、この関数の枠を小さく保つ。
    fn expr(&mut self, e: &'a Expr) -> ITy {
        let t = match e {
            Expr::Lit(l) => self.lit_expr(l.span, &l.lit),
            Expr::Name(n) => self.name_expr(n),
            Expr::Unit(_) => ITy::Con(TyCon::Unit, Vec::new()),
            Expr::Paren(p) => self.expr(&p.inner),
            Expr::List(l) => self.list_expr(&l.elems),
            Expr::Call(c) => self.call_expr(c),
            Expr::Binary(b) => self.binary_expr(b),
            Expr::Unary(u) => self.unary_expr(u),
            Expr::Pipe(p) => self.pipe_expr(p),
            Expr::Block(b) => self.block(b),
            Expr::If(i) => self.if_expr(i),
            Expr::Match(m) => self.match_expr(m),
            Expr::Lambda(l) => self.lambda_expr(l),
            Expr::Error(_) => ITy::Error,
        };
        self.record(e.id(), &t);
        t
    }

    fn lit_expr(&mut self, span: Span, lit: &Literal) -> ITy {
        let c = match lit {
            Literal::Int { radix, digits } => {
                if int_in_range(*radix, digits, false).is_none() {
                    self.diags.push(out_of_range(span));
                }
                TyCon::Int
            }
            Literal::Float(text) => {
                // Rust の `f64` への変換は最も近い値に丸める（最近接偶数）。これを 01-04「Float」の
                // 丸めの規則として使い、無限大になれば範囲の外とする（作業 T15「リテラルの範囲」）。
                if text.parse::<f64>().is_ok_and(f64::is_infinite) {
                    self.diags
                        .push(DiagBuilder::new(DiagCode::E0409).primary(span).build());
                }
                TyCon::Float
            }
            Literal::Str(_) => TyCon::String,
            Literal::Char(_) => TyCon::Char,
            Literal::Bool(_) => TyCon::Bool,
        };
        ITy::Con(c, Vec::new())
    }

    fn name_expr(&mut self, n: &NameExpr) -> ITy {
        let Some((b, kind)) = self.binding_of(n.id) else {
            return ITy::Error;
        };
        match kind {
            BindingKind::Param
            | BindingKind::Let
            | BindingKind::LambdaParam
            | BindingKind::PatternVar => self.locals.get(b).cloned().unwrap_or(ITy::Error),
            BindingKind::TopFn | BindingKind::PreludeFn { .. } => match self.declared_scheme(b) {
                Some(s) => self.instantiate_fn(n.id, s, None),
                None => ITy::Error,
            },
            BindingKind::Ctor { .. } => match self.declared_scheme(b) {
                // 引数を持たない構成子の名前の型は `D[T̄]`、引数を持つ構成子は関数の型である
                // （01-05「値の構築」）。
                Some(s) if s.params.is_empty() => {
                    let (tys, _) = self.instantiate(n.id, s, None);
                    to_ity(&s.ret, subst(&tys, &[]))
                }
                Some(s) => self.instantiate_fn(n.id, s, None),
                None => ITy::Error,
            },
            BindingKind::Builtin(id) => {
                let spec = table::spec(id);
                let scheme = table::scheme(id);
                // 型パラメータの制約が満たされないときの診断に、修飾した名前を示す（作業 T15）。
                let name = match spec.module {
                    Some(m) => format!("{}.{}", m.name(), spec.name),
                    None => spec.name.to_string(),
                };
                self.instantiate_fn(n.id, &scheme, Some((name, n.span)))
            }
            // 値でない名前は名前解決が報告する（02-04）。
            BindingKind::Type(_)
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Effect
            | BindingKind::Module(_) => ITy::Error,
        }
    }

    /// 宣言の型。壊れた宣言は `None`（使う箇所の型を誤りの型にする）。
    fn declared_scheme(&self, b: BindingId) -> Option<&'a Scheme> {
        if self.g.decls.broken.contains(&b) {
            return None;
        }
        self.g.decls.decl_types.get(b)
    }

    /// 多相な名前の型パラメータとエフェクト変数を新しい変数に置き換え、置き換えを記録する
    /// （02-05「制約の生成」の「多相な名前」）。組み込みの関数の型パラメータの制約は、置き換えた型変数に移す。
    fn instantiate(
        &mut self,
        node: NodeId,
        s: &Scheme,
        builtin: Option<(String, Span)>,
    ) -> (Vec<ITy>, Vec<EffInfer>) {
        let mut tys = Vec::with_capacity(s.type_params.len());
        for tp in &s.type_params {
            let v: TyVar = self.solver.fresh_ty_var();
            if let Some((name, span)) = &builtin {
                let r = reason(*span, ReasonKind::BuiltinParam { name: name.clone() });
                match tp.constraint {
                    ParamConstraint::None => {}
                    ParamConstraint::Equality => self.solver.constrain_equality(v, r),
                    ParamConstraint::OneOf(set) => self.solver.constrain_one_of(v, set, r),
                }
            }
            tys.push(ITy::Var(v));
        }
        let effs: Vec<EffInfer> = s
            .effect_params
            .iter()
            .map(|_| self.solver.fresh_eff_var())
            .collect();
        let ieffs = effs
            .iter()
            .map(|v| IEffect {
                fixed: EffectSet::empty(),
                var: Some(*v),
            })
            .collect();
        self.rec_args.push((node, tys.clone(), ieffs));
        (tys, effs)
    }

    fn instantiate_fn(&mut self, node: NodeId, s: &Scheme, builtin: Option<(String, Span)>) -> ITy {
        let (tys, effs) = self.instantiate(node, s, builtin);
        to_ity(&s.fn_ty(), subst(&tys, &effs))
    }

    // 再帰の経路にある関数（子の式を辿る関数）は、子を辿った結果を受け取って制約を作る処理を
    // `*_rest` などの別の関数に分ける。制約と理由の一時の値を、再帰の間ずっと残る枠に置かないためである
    // （本モジュールの冒頭）。

    fn list_expr(&mut self, elems: &'a [Expr]) -> ITy {
        let mut tys = Vec::with_capacity(elems.len());
        for e in elems {
            tys.push(self.expr(e));
        }
        self.list_rest(elems, tys)
    }

    fn list_rest(&mut self, elems: &[Expr], tys: Vec<ITy>) -> ITy {
        let alpha = self.solver.fresh_ty();
        for (e, t) in elems.iter().zip(tys) {
            let mut r = reason(e.span(), ReasonKind::ListElement);
            r.int_literal = int_literal_text(e);
            self.flow(t, alpha.clone(), r);
        }
        ITy::Con(TyCon::List, vec![alpha])
    }

    // ---- 呼び出し ----

    fn call_expr(&mut self, c: &'a CallExpr) -> ITy {
        if c.args.iter().any(|a| matches!(a, Arg::Placeholder(_))) {
            return self.placeholder_call(c);
        }
        if c.args.is_empty()
            && let Expr::Name(n) = c.callee.as_ref()
            && let Some(t) = self.nullary_ctor_call(n, c.span)
        {
            self.record(n.id, &t);
            return t;
        }
        let f_ty = self.expr(&c.callee);
        let mut args = Vec::with_capacity(c.args.len());
        self.push_args(&c.args, &mut args);
        self.call_constraints(&c.callee, f_ty, args, c.span, None)
    }

    /// 引数を持たない構成子に括弧を付けた呼び出し（`Tree.Leaf()`）なら、E0413 を報告して誤りの型を返す
    /// （02-05「制約の生成」の表の後の段落）。
    fn nullary_ctor_call(&mut self, n: &NameExpr, span: Span) -> Option<ITy> {
        let (b, BindingKind::Ctor { .. }) = self.binding_of(n.id)? else {
            return None;
        };
        if self.g.decls.broken.contains(&b) {
            return Some(ITy::Error);
        }
        let s = self.g.decls.decl_types.get(b)?;
        if !s.params.is_empty() {
            return None;
        }
        self.diags.push(
            DiagBuilder::new(DiagCode::E0413)
                .arg("name", written_name(n.qualifier.as_ref(), &n.name.text))
                .primary(span)
                .help("remove")
                .build(),
        );
        Some(ITy::Error)
    }

    /// 引数を辿り、型を `out` に加える。プレースホルダは新しい型変数 πk にして記録し、`params` に加える
    /// （展開したラムダの引数。01-02「部分適用のプレースホルダ」）。
    fn push_args(&mut self, args: &'a [Arg], out: &mut Vec<ArgTy>) -> Vec<ITy> {
        let mut params = Vec::new();
        for a in args {
            let arg = match a {
                Arg::Expr(e) => {
                    let ty = self.expr(e);
                    arg_ty(e, ty)
                }
                Arg::Placeholder(p) => {
                    let pi = self.solver.fresh_ty();
                    self.rec_types.push((p.id, pi.clone()));
                    params.push(pi.clone());
                    ArgTy {
                        ty: pi,
                        span: p.span,
                        int_literal: None,
                    }
                }
            };
            out.push(arg);
        }
        params
    }

    /// 呼び出しの制約（02-05「制約の生成」の「呼び出し」）。`pipe` はパイプの式全体の span で、
    /// 与えられたときは展開した呼び出しの制約の理由の span をすべてそれにする（作業 T15）。
    fn call_constraints(
        &mut self,
        callee: &Expr,
        f_ty: ITy,
        args: Vec<ArgTy>,
        span: Span,
        pipe: Option<Span>,
    ) -> ITy {
        let site = if let Expr::Name(n) = callee {
            self.call_site(n)
        } else {
            None
        };
        let betas: Vec<ITy> = args.iter().map(|_| self.solver.fresh_ty()).collect();
        let rho = self.solver.fresh_ty();
        let eps = self.solver.fresh_effect();
        let callee_has_error = has_error(&f_ty);
        let mut r = reason(pipe.unwrap_or(span), ReasonKind::Call);
        r.related = site.map(|s| s.name);
        self.equal(
            f_ty,
            ITy::Fn(Box::new(IFnTy {
                params: betas.clone(),
                ret: rho.clone(),
                effect: eps.clone(),
            })),
            r,
        );
        for (i, (a, beta)) in args.into_iter().zip(betas).enumerate() {
            let index = u32::try_from(i.saturating_add(1)).unwrap_or(u32::MAX);
            let mut r = reason(pipe.unwrap_or(a.span), ReasonKind::CallArg { index });
            r.related = site.and_then(|s| s.params.get(i).copied());
            r.int_literal = a.int_literal;
            self.flow(a.ty, beta, r);
        }
        // 呼ばれる式の型が誤りの型なら、エフェクトの要素を生じない（02-05「誤りの報告と検査の継続」）。
        if !callee_has_error {
            self.call_effect(eps, pipe.unwrap_or(span));
        }
        rho
    }

    /// 呼び出しのエフェクトが本体のエフェクトに含まれる制約。理由の種類は本体の種類で決まる（作業 T15）。
    fn call_effect(&mut self, eps: IEffect, span: Span) {
        let (kind, related) = match self.effect_kind {
            BodyEff::Fn { related } => (ReasonKind::FnUses, Some(related)),
            BodyEff::Lambda { related } => (ReasonKind::LambdaUses, Some(related)),
            BodyEff::Var => (ReasonKind::CallEffect, None),
        };
        let mut r = reason(span, kind);
        r.related = related;
        self.constraints.push(Constraint::EffSub {
            sub: eps,
            sup: self.effect.clone(),
            reason: r,
        });
    }

    /// 呼ばれる式がトップレベルの関数・prelude のソースの関数・引数を持つ構成子なら、その宣言の位置。
    fn call_site(&self, n: &NameExpr) -> Option<&'a super::decls::Site> {
        let (b, kind) = self.binding_of(n.id)?;
        match kind {
            BindingKind::TopFn | BindingKind::PreludeFn { .. } | BindingKind::Ctor { .. } => {
                let site = self.g.decls.sites.get(b)?;
                (!site.params.is_empty() || !matches!(kind, BindingKind::Ctor { .. }))
                    .then_some(site)
            }
            BindingKind::Builtin(_)
            | BindingKind::Param
            | BindingKind::Let
            | BindingKind::LambdaParam
            | BindingKind::PatternVar
            | BindingKind::Type(_)
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Effect
            | BindingKind::Module(_) => None,
        }
    }

    /// プレースホルダを含む呼び出し。01-02 の規則で展開したラムダとして扱う（02-05「制約の生成」）。
    /// 呼ばれる式とプレースホルダでない引数は、展開したラムダの本体（エフェクトは新しい変数 E'）の中で辿る。
    fn placeholder_call(&mut self, c: &'a CallExpr) -> ITy {
        let lambda_effect = self.solver.fresh_effect();
        let saved = self.enter_body(lambda_effect, BodyEff::Var);
        let f_ty = self.expr(&c.callee);
        let mut args = Vec::with_capacity(c.args.len());
        let params = self.push_args(&c.args, &mut args);
        self.placeholder_rest(c, f_ty, args, params, saved)
    }

    fn placeholder_rest(
        &mut self,
        c: &CallExpr,
        f_ty: ITy,
        args: Vec<ArgTy>,
        params: Vec<ITy>,
        saved: (IEffect, BodyEff),
    ) -> ITy {
        let ret = self.call_constraints(&c.callee, f_ty, args, c.span, None);
        let lambda_effect = self.leave_body(saved);
        self.rec_lambdas.push((c.id, lambda_effect.clone()));
        ITy::Fn(Box::new(IFnTy {
            params,
            ret,
            effect: lambda_effect,
        }))
    }

    /// ラムダの本体に入る。前の本体のエフェクトを返す。
    fn enter_body(&mut self, effect: IEffect, kind: BodyEff) -> (IEffect, BodyEff) {
        let old_effect = std::mem::replace(&mut self.effect, effect);
        let old_kind = std::mem::replace(&mut self.effect_kind, kind);
        (old_effect, old_kind)
    }

    /// ラムダの本体から出る。出た本体のエフェクトを返す。
    fn leave_body(&mut self, saved: (IEffect, BodyEff)) -> IEffect {
        self.effect_kind = saved.1;
        std::mem::replace(&mut self.effect, saved.0)
    }

    /// パイプ `x |> e`（01-02「パイプ」、ADR 0050）。展開した呼び出しの制約を作る。
    fn pipe_expr(&mut self, p: &'a PipeExpr) -> ITy {
        let x_ty = self.expr(&p.lhs);
        let mut args = vec![arg_ty(&p.lhs, x_ty)];
        // 規則 1: 直接の引数にプレースホルダを含まない呼び出しなら、x を第 1 引数に加える。
        // `g(a)(b)` の形でも、e そのものが最も外側の呼び出しである。
        if let Expr::Call(c) = p.rhs.as_ref()
            && !c.args.iter().any(|a| matches!(a, Arg::Placeholder(_)))
        {
            let f_ty = self.expr(&c.callee);
            self.push_args(&c.args, &mut args);
            return self.pipe_rule1_rest(p, c, f_ty, args);
        }
        // 規則 2（括弧の式、名前、ラムダ、プレースホルダを含む呼び出しなど）: e(x)。
        let f_ty = self.expr(&p.rhs);
        self.call_constraints(&p.rhs, f_ty, args, p.span, Some(p.span))
    }

    fn pipe_rule1_rest(&mut self, p: &PipeExpr, c: &CallExpr, f_ty: ITy, args: Vec<ArgTy>) -> ITy {
        let t = self.call_constraints(&c.callee, f_ty, args, c.span, Some(p.span));
        // 展開前の呼び出しのノードにも、展開した呼び出しの型を記録する（表の網羅）。
        self.record(c.id, &t);
        t
    }

    // ---- 演算子 ----

    fn binary_expr(&mut self, b: &'a BinaryExpr) -> ITy {
        let l = self.expr(&b.lhs);
        let r = self.expr(&b.rhs);
        self.binary_rest(b, l, r)
    }

    fn binary_rest(&mut self, b: &BinaryExpr, l: ITy, r: ITy) -> ITy {
        let op = OpName::Bin(b.op);
        let (operand, result) = match b.op {
            BinOp::Add | BinOp::Sub | BinOp::Mul | BinOp::Div => {
                let set = if b.op == BinOp::Add {
                    TySet::ADD
                } else {
                    TySet::ARITH
                };
                let alpha = self.operands(b, op, l, r);
                self.one_of(alpha.clone(), set, op, b.span);
                (alpha.clone(), alpha)
            }
            BinOp::Lt | BinOp::Le | BinOp::Gt | BinOp::Ge => {
                let alpha = self.operands(b, op, l, r);
                self.one_of(alpha.clone(), TySet::ORD, op, b.span);
                (alpha, ITy::Con(TyCon::Bool, Vec::new()))
            }
            BinOp::Eq | BinOp::Ne => {
                let alpha = self.operands(b, op, l, r);
                self.constraints.push(Constraint::Equality {
                    ty: alpha.clone(),
                    reason: reason(b.span, ReasonKind::Operator { op }),
                });
                (alpha, ITy::Con(TyCon::Bool, Vec::new()))
            }
            BinOp::Rem => {
                // `%` は `Int` だけ（01-06「演算子の型付け」）。理由 `Operator` の等しい制約は、
                // E0401 の注記 `because_int_operands` になる（T14）。
                let int = ITy::Con(TyCon::Int, Vec::new());
                self.fixed_operand(int.clone(), &b.lhs, l, ReasonKind::Operator { op });
                self.fixed_operand(int.clone(), &b.rhs, r, ReasonKind::Operator { op });
                (int.clone(), int)
            }
            BinOp::And | BinOp::Or => {
                let bool_ty = ITy::Con(TyCon::Bool, Vec::new());
                self.fixed_operand(bool_ty.clone(), &b.lhs, l, ReasonKind::Logic { op });
                self.fixed_operand(bool_ty.clone(), &b.rhs, r, ReasonKind::Logic { op });
                (bool_ty.clone(), bool_ty)
            }
        };
        self.rec_operands.push((b.id, operand));
        result
    }

    /// 二つのオペランドの型を新しい α と等しくする（理由 `Operands`）。T14 の `+` の修正案は
    /// `Equal(α, 左)`・`Equal(α, 右)` の形を前提にする。
    fn operands(&mut self, b: &BinaryExpr, op: OpName, l: ITy, r: ITy) -> ITy {
        let alpha = self.solver.fresh_ty();
        for (e, t) in [(&b.lhs, l), (&b.rhs, r)] {
            let mut rs = reason(e.span(), ReasonKind::Operands { op });
            rs.int_literal = int_literal_text(e);
            self.equal(alpha.clone(), t, rs);
        }
        alpha
    }

    fn fixed_operand(&mut self, expected: ITy, e: &Expr, t: ITy, kind: ReasonKind) {
        let mut rs = reason(e.span(), kind);
        rs.int_literal = int_literal_text(e);
        self.equal(expected, t, rs);
    }

    fn one_of(&mut self, ty: ITy, set: TySet, op: OpName, span: Span) {
        self.constraints.push(Constraint::OneOf {
            ty,
            set,
            reason: reason(span, ReasonKind::Operator { op }),
        });
    }

    fn unary_expr(&mut self, u: &'a UnaryExpr) -> ITy {
        // 整数リテラルに直接付けた `-` は、符号を含めた値で範囲を判定する（01-04「Int」）。
        // 括弧で囲んだ `-(n)` はこの扱いにしない。
        if u.op == UnOp::Neg
            && let Expr::Lit(l) = u.operand.as_ref()
            && let Literal::Int { radix, digits } = &l.lit
        {
            return self.negative_literal(u, l.id, *radix, digits);
        }
        let t = self.expr(&u.operand);
        self.unary_rest(u, t)
    }

    fn negative_literal(&mut self, u: &UnaryExpr, lit: NodeId, radix: u32, digits: &str) -> ITy {
        if int_in_range(radix, digits, true).is_none() {
            self.diags.push(out_of_range(u.span));
        }
        let int = ITy::Con(TyCon::Int, Vec::new());
        self.record(lit, &int);
        self.rec_operands.push((u.id, int.clone()));
        int
    }

    fn unary_rest(&mut self, u: &UnaryExpr, t: ITy) -> ITy {
        let op = OpName::Un(u.op);
        let operand = match u.op {
            UnOp::Neg => {
                let alpha = self.solver.fresh_ty();
                let mut rs = reason(u.operand.span(), ReasonKind::Operands { op });
                rs.int_literal = int_literal_text(&u.operand);
                self.equal(alpha.clone(), t, rs);
                self.one_of(alpha.clone(), TySet::ARITH, op, u.span);
                alpha
            }
            UnOp::Not => {
                let bool_ty = ITy::Con(TyCon::Bool, Vec::new());
                self.fixed_operand(bool_ty.clone(), &u.operand, t, ReasonKind::Logic { op });
                bool_ty
            }
        };
        self.rec_operands.push((u.id, operand.clone()));
        operand
    }

    // ---- ブロックと制御 ----

    fn block(&mut self, b: &'a Block) -> ITy {
        let mut result = ITy::Con(TyCon::Unit, Vec::new());
        let last = b.stmts.len().saturating_sub(1);
        for (i, s) in b.stmts.iter().enumerate() {
            result = match s {
                Stmt::Let(l) => {
                    self.let_stmt(l);
                    ITy::Con(TyCon::Unit, Vec::new())
                }
                Stmt::Expr(e) => {
                    let t = self.expr(e);
                    if i == last { t } else { self.expr_stmt(e, t) }
                }
                Stmt::Error(_) => ITy::Error,
            };
        }
        self.record(b.id, &result);
        result
    }

    /// 最後でない式文は `Unit` でなければならない（01-06「式と文の型」）。
    fn expr_stmt(&mut self, e: &Expr, t: ITy) -> ITy {
        let unit = ITy::Con(TyCon::Unit, Vec::new());
        self.equal(unit.clone(), t, reason(e.span(), ReasonKind::ExprStmt));
        unit
    }

    fn let_stmt(&mut self, l: &'a LetStmt) {
        let annotated = l.ty.as_ref().map(|t| self.annotation(t));
        let v = self.expr(&l.value);
        self.let_rest(l, annotated, v);
    }

    fn let_rest(&mut self, l: &LetStmt, annotated: Option<ITy>, v: ITy) {
        let bound = match (annotated, &l.ty) {
            (Some(ann), Some(t)) => {
                let mut r = declared_reason(l.value.span(), ReasonKind::LetAnnotation, t.span());
                r.int_literal = int_literal_text(&l.value);
                self.flow(v, ann.clone(), r);
                ann
            }
            _ => v,
        };
        if let LetName::Var(_) = &l.name
            && let Some(b) = self.g.resolved.decls.get(l.id).copied()
        {
            self.locals.insert(b, bound.clone());
        }
        self.rec_types.push((l.id, bound));
    }

    fn if_expr(&mut self, i: &'a IfExpr) -> ITy {
        let c = self.expr(&i.cond);
        let t1 = self.block(&i.then_block);
        let t2 = match &i.else_branch {
            None => None,
            Some(ElseBranch::Block(b)) => Some(self.block(b)),
            Some(ElseBranch::If(inner)) => Some(self.if_expr(inner)),
        };
        self.if_rest(i, c, t1, t2)
    }

    fn if_rest(&mut self, i: &IfExpr, c: ITy, t1: ITy, t2: Option<ITy>) -> ITy {
        self.equal(
            ITy::Con(TyCon::Bool, Vec::new()),
            c,
            reason(i.cond.span(), ReasonKind::IfCondition),
        );
        let then_lit = result_expr(&i.then_block).and_then(int_literal_text);
        let t = match (t2, &i.else_branch) {
            (Some(t2), Some(els)) => {
                let alpha = self.solver.fresh_ty();
                let mut r1 = reason(result_span(&i.then_block), ReasonKind::IfBranches);
                r1.int_literal = then_lit;
                self.flow(t1, alpha.clone(), r1);
                let r2 = match els {
                    ElseBranch::Block(b) => {
                        let mut r = reason(result_span(b), ReasonKind::IfBranches);
                        r.int_literal = result_expr(b).and_then(int_literal_text);
                        r
                    }
                    ElseBranch::If(inner) => reason(inner.span, ReasonKind::IfBranches),
                };
                self.flow(t2, alpha.clone(), r2);
                alpha
            }
            _ => {
                let mut r = reason(result_span(&i.then_block), ReasonKind::IfNoElse);
                r.int_literal = then_lit;
                self.equal(ITy::Con(TyCon::Unit, Vec::new()), t1, r);
                ITy::Con(TyCon::Unit, Vec::new())
            }
        };
        self.record(i.id, &t);
        t
    }

    fn match_expr(&mut self, m: &'a MatchExpr) -> ITy {
        let s = self.expr(&m.scrutinee);
        let alpha = self.solver.fresh_ty();
        let mut acc = PatAcc::default();
        for arm in &m.arms {
            self.match_arm(arm, &s, &alpha, &mut acc);
        }
        self.matches.push(MatchRec {
            m,
            scrutinee: s,
            skip: acc.bad,
            pairs: acc.pairs,
        });
        alpha
    }

    /// 分岐ごとに、パターンと本体を辿り終えた後に、その分岐の制約を加える（作業 T15 で決めた）。
    fn match_arm(&mut self, arm: &'a MatchArm, s: &ITy, alpha: &ITy, acc: &mut PatAcc) {
        let p = self.pattern(&arm.pattern, false, acc);
        let body = self.expr(&arm.body);
        self.arm_rest(arm, s, alpha, p, body, acc);
    }

    fn arm_rest(
        &mut self,
        arm: &MatchArm,
        s: &ITy,
        alpha: &ITy,
        p: ITy,
        body: ITy,
        acc: &mut PatAcc,
    ) {
        acc.pairs.push((s.clone(), p.clone()));
        self.equal(
            s.clone(),
            p,
            reason(arm.pattern.span(), ReasonKind::Pattern),
        );
        let mut r = reason(arm.body.span(), ReasonKind::MatchArms);
        r.int_literal = int_literal_text(&arm.body);
        self.flow(body, alpha.clone(), r);
    }

    fn lambda_expr(&mut self, l: &'a LambdaExpr) -> ITy {
        let (params, ret_ann, saved) = self.lambda_head(l);
        let body = self.block(&l.body);
        self.lambda_rest(l, params, ret_ann, body, saved)
    }

    /// ラムダの引数と戻り値の型注釈を変換し、本体に入る（02-05「制約の生成」の「ラムダ」）。
    fn lambda_head(&mut self, l: &LambdaExpr) -> (Vec<ITy>, Option<ITy>, (IEffect, BodyEff)) {
        let mut params = Vec::with_capacity(l.params.len());
        for p in &l.params {
            let t = match &p.ty {
                Some(t) => self.annotation(t),
                None => self.solver.fresh_ty(),
            };
            self.bind_param(p, t.clone());
            params.push(t);
        }
        let ret_ann = l.ret.as_ref().map(|t| self.annotation(t));
        // 本体のエフェクト E'。`uses` を書いていればその集合、書いていなければ新しい変数。
        let fixed = l.uses.as_ref().map(|u| {
            let tcx = TypeCx {
                resolved: self.g.resolved,
                adt_arity: &self.g.decls.adt_arity,
            };
            (tcx.convert_uses(Some(u), &mut self.diags), u.span)
        });
        let (effect, kind) = match fixed {
            Some((Some(fixed), related)) => {
                (IEffect { fixed, var: None }, BodyEff::Lambda { related })
            }
            // `uses` の誤りを報告したときは、本体のエフェクトの誤りを重ねて報告しない。
            Some((None, _)) | None => (self.solver.fresh_effect(), BodyEff::Var),
        };
        let saved = self.enter_body(effect, kind);
        (params, ret_ann, saved)
    }

    fn lambda_rest(
        &mut self,
        l: &LambdaExpr,
        params: Vec<ITy>,
        ret_ann: Option<ITy>,
        body: ITy,
        saved: (IEffect, BodyEff),
    ) -> ITy {
        let effect = self.leave_body(saved);
        let ret = match (ret_ann, &l.ret) {
            (Some(ann), Some(t)) => {
                let mut r =
                    declared_reason(result_span(&l.body), ReasonKind::LambdaReturn, t.span());
                r.int_literal = result_expr(&l.body).and_then(int_literal_text);
                self.flow(body, ann.clone(), r);
                ann
            }
            _ => body,
        };
        self.rec_lambdas.push((l.id, effect.clone()));
        ITy::Fn(Box::new(IFnTy {
            params,
            ret,
            effect,
        }))
    }

    // ---- パターン ----

    /// パターンを辿って型を返し、表に記録する。`poisoned` のときは、構成子の引数の個数の誤りの下にあり、
    /// 型をすべて誤りの型として辿る（02-05「制約の生成」の「構成子のパターン」）。
    fn pattern(&mut self, p: &'a Pattern, poisoned: bool, acc: &mut PatAcc) -> ITy {
        let t = match p {
            Pattern::Wildcard(_) => self.fresh_or_error(poisoned),
            Pattern::Var(v) => self.var_pattern(v.id, poisoned),
            Pattern::Lit(l) => self.lit_pattern(l, acc),
            Pattern::Unit(_) => ITy::Con(TyCon::Unit, Vec::new()),
            Pattern::Ctor(c) => self.ctor_pattern(c, acc),
            Pattern::Error(_) => {
                acc.bad = true;
                ITy::Error
            }
        };
        let t = if poisoned { ITy::Error } else { t };
        self.record(p.id(), &t);
        t
    }

    fn fresh_or_error(&mut self, poisoned: bool) -> ITy {
        if poisoned {
            ITy::Error
        } else {
            self.solver.fresh_ty()
        }
    }

    fn var_pattern(&mut self, node: NodeId, poisoned: bool) -> ITy {
        let t = self.fresh_or_error(poisoned);
        if let Some(b) = self.g.resolved.decls.get(node).copied() {
            self.locals.insert(b, t.clone());
        }
        t
    }

    fn lit_pattern(&mut self, l: &LitPat, acc: &mut PatAcc) -> ITy {
        let c = match &l.lit {
            Literal::Int { radix, digits } => {
                // `-n` の形は符号を含めた値で検査する。範囲の外の整数を含む `match` は、パターンの
                // 検査から外す（作業 T15「リテラルの範囲」）。
                if int_in_range(*radix, digits, l.negative).is_none() {
                    self.diags.push(out_of_range(l.span));
                    acc.bad = true;
                }
                TyCon::Int
            }
            Literal::Str(_) => TyCon::String,
            Literal::Char(_) => TyCon::Char,
            Literal::Bool(_) => TyCon::Bool,
            // 文法が浮動小数リテラルのパターンを許さない（10-03 `LitPat`）。
            Literal::Float(_) => {
                acc.bad = true;
                TyCon::Float
            }
        };
        ITy::Con(c, Vec::new())
    }

    fn ctor_pattern(&mut self, c: &'a CtorPat, acc: &mut PatAcc) -> ITy {
        let head = self.ctor_head(c, acc);
        let Some((ty, fields)) = head else {
            // 構成子の誤り（壊れた構成子、E0412・E0413）の下の引数は、誤りの型として辿る。
            for a in &c.args {
                self.pattern(a, true, acc);
            }
            return ITy::Error;
        };
        let mut arg_tys = Vec::with_capacity(c.args.len());
        for a in &c.args {
            arg_tys.push(self.pattern(a, false, acc));
        }
        self.ctor_rest(c, fields, arg_tys, acc);
        ty
    }

    /// 構成子のパターンの型を決める（02-05「制約の生成」の「構成子のパターン」）。引数の個数の誤りと、
    /// 引数を持たない構成子の括弧を報告したときは `None`。
    fn ctor_head(&mut self, c: &CtorPat, acc: &mut PatAcc) -> Option<(ITy, Vec<ITy>)> {
        let s = match self.binding_of(c.id) {
            Some((b, BindingKind::Ctor { .. })) => self.declared_scheme(b),
            Some(_) | None => None,
        };
        let Some(s) = s else {
            // 壊れた型の宣言の構成子。派生した誤りを出さないように、この `match` を検査しない。
            acc.bad = true;
            return None;
        };
        let (tys, _) = self.instantiate(c.id, s, None);
        let fields: Vec<ITy> = s
            .params
            .iter()
            .map(|f| to_ity(f, subst(&tys, &[])))
            .collect();
        let name = || written_name(c.qualifier.as_ref(), &c.name.text);
        let diag = if fields.is_empty() && c.has_parens {
            // 引数を持たない構成子に括弧を付けたパターン（01-05「パターン」）。
            DiagBuilder::new(DiagCode::E0413)
                .arg("name", name())
                .primary(c.span)
                .help("remove")
        } else if fields.len() != c.args.len() {
            DiagBuilder::new(DiagCode::E0412)
                .arg("name", name())
                .arg("expected", fields.len().to_string())
                .arg("found", c.args.len().to_string())
                .primary(c.span)
        } else {
            return Some((to_ity(&s.ret, subst(&tys, &[])), fields));
        };
        self.diags.push(diag.build());
        acc.bad = true;
        None
    }

    fn ctor_rest(&mut self, c: &CtorPat, fields: Vec<ITy>, arg_tys: Vec<ITy>, acc: &mut PatAcc) {
        for ((a, field), t) in c.args.iter().zip(fields).zip(arg_tys) {
            acc.pairs.push((field.clone(), t.clone()));
            self.equal(field, t, reason(a.span(), ReasonKind::Pattern));
        }
    }

    // ---- 解いた後 ----

    /// 制約を解き、本体の後の検査を行い、表に記録する（作業 T15「解いた後の検査と記録」）。
    fn finish(
        mut self,
        type_params: &[String],
        effect_params: &[String],
        tables: &mut Tables,
        diags: &mut Vec<Diagnostic>,
    ) {
        let env = SolveEnv {
            adts: &self.g.decls.adts,
            type_params,
            effect_params,
        };
        let constraints = std::mem::take(&mut self.constraints);
        let solved = self.solver.solve(constraints, &env);
        diags.append(&mut self.diags);
        diags.extend(solved);
        for r in self.solver.undetermined() {
            diags.push(
                DiagBuilder::new(DiagCode::E0407)
                    .primary(r.span)
                    .help("annotate")
                    .build(),
            );
        }
        for rec in std::mem::take(&mut self.matches) {
            self.check_patterns(&rec, diags);
        }
        let s = &self.solver;
        for (node, t) in &self.rec_types {
            tables.expr_types.insert(*node, s.finalize(t));
        }
        for (node, tys, effs) in &self.rec_args {
            tables.type_args.insert(
                *node,
                TypeArgs {
                    tys: tys.iter().map(|t| s.finalize(t)).collect(),
                    effects: effs.iter().map(|e| s.finalize_effect(e)).collect(),
                },
            );
        }
        for (node, t) in &self.rec_operands {
            tables.operand_types.insert(*node, s.finalize(t));
        }
        for (node, e) in &self.rec_lambdas {
            tables.lambda_effects.insert(*node, s.finalize_effect(e));
        }
    }

    /// 一つの `match` の網羅性と選ばれない分岐を検査する（02-05「本体の後の検査」）。
    fn check_patterns(&self, rec: &MatchRec<'_>, diags: &mut Vec<Diagnostic>) {
        if rec.skip || self.solver.contains_error(&rec.scrutinee) {
            return;
        }
        // パターンの型の制約が一つでも解けなかった `match` は、検査から外す。
        for (expected, found) in &rec.pairs {
            if self.solver.contains_error(expected)
                || self.solver.contains_error(found)
                || self.solver.finalize(expected) != self.solver.finalize(found)
            {
                return;
            }
        }
        let scrutinee = self.solver.finalize(&rec.scrutinee);
        if self.mentions_broken(&scrutinee) {
            return;
        }
        let mut pats = Vec::with_capacity(rec.m.arms.len());
        for arm in &rec.m.arms {
            let Some(p) = self.to_pat(&arm.pattern) else {
                return;
            };
            pats.push(p);
        }
        let arm_span = |i: usize| rec.m.arms.get(i).map(|a| a.pattern.span());
        for issue in check_match(&scrutinee, &pats, &self.g.decls.adts) {
            match issue {
                MatchIssue::Unreachable { arm, covered_by } => {
                    let Some(span) = arm_span(arm) else {
                        continue;
                    };
                    let mut b = DiagBuilder::new(DiagCode::E0602).primary(span);
                    for j in covered_by {
                        if let Some(s) = arm_span(j) {
                            b = b.secondary(s, "covering");
                        }
                    }
                    diags.push(b.build());
                }
                MatchIssue::NonExhaustive { witness } => diags.push(
                    DiagBuilder::new(DiagCode::E0601)
                        .arg("witness", witness)
                        .primary(rec.m.scrutinee.span())
                        .help("add_arm")
                        .build(),
                ),
            }
        }
    }

    /// 型が壊れた型の宣言を含むか。壊れた型の構成子の表は不完全なので、パターンを検査しない。
    fn mentions_broken(&self, t: &Ty) -> bool {
        match t {
            Ty::Con(TyCon::Adt(b), args) => {
                self.g.decls.broken.contains(b) || args.iter().any(|a| self.mentions_broken(a))
            }
            Ty::Con(_, args) => args.iter().any(|a| self.mentions_broken(a)),
            Ty::Fn(f) => {
                f.params.iter().any(|p| self.mentions_broken(p)) || self.mentions_broken(&f.ret)
            }
            Ty::Param(_) => false,
        }
    }

    /// AST のパターンを検査に使うパターンに移す。変数のパターンは `Wild`、`-n` は負の値、
    /// 構成子のパターンは参照の表の `Ctor { con, tag }`（作業 T15「解いた後の検査と記録」）。
    fn to_pat(&self, p: &Pattern) -> Option<Pat> {
        Some(match p {
            Pattern::Wildcard(_) | Pattern::Var(_) => Pat::Wild,
            Pattern::Unit(_) => Pat::Unit,
            Pattern::Lit(l) => match &l.lit {
                Literal::Int { radix, digits } => {
                    Pat::Int(int_in_range(*radix, digits, l.negative)?)
                }
                Literal::Str(s) => Pat::Str(s.clone()),
                Literal::Char(c) => Pat::Char(*c),
                Literal::Bool(b) => Pat::Bool(*b),
                Literal::Float(_) => return None,
            },
            Pattern::Ctor(c) => {
                let (_, BindingKind::Ctor { con, tag }) = self.binding_of(c.id)? else {
                    return None;
                };
                let mut args = Vec::with_capacity(c.args.len());
                for a in &c.args {
                    args.push(self.to_pat(a)?);
                }
                Pat::Ctor { con, tag, args }
            }
            Pattern::Error(_) => return None,
        })
    }
}
