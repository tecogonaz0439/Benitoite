//! 脱糖（設計書 02-06「脱糖」、01-12「表層からの脱糖」）。
//!
//! 型検査を通ったプログラムの AST を、コア計算と同じ形のコア IR に移す。01-12「表層からの脱糖」の
//! 表の各行を、構文ごとに一つの関数として書く（各関数の `///` のコメントに、実装する行を示す）。
//! 各ノードには、02-06「コア IR」の表に従って型とエフェクトを、02-02「合成ノードの由来位置」に従って
//! 由来位置を付ける。
//!
//! 値が必要な箇所では、式を脱糖した計算を新しい変数に束縛する（`let x ⇐ ⟦e⟧ in …`）。束縛は
//! `Lets`（束縛の並び）に積み、最後に `wrap` で `let` の入れ子に組む。この形にすると、各規則の関数を
//! 01-12 の表の右辺と同じ順に書ける。脱糖は最適化をせず（02-06「最適化」）、`let` の右側が入れ子に
//! なった形もそのまま残す（02-06「脱糖」）。
//!
//! 再帰の深さとスタック: AST を再帰で辿る（00-02「再帰の深さ」）。構文解析器が AST の深さを 1000 に
//! 抑える（02-03「入れ子の深さ」）ので、再帰の深さはその定数倍に収まる。ただし、各段の単体テストは
//! 既定のスタック（2 MiB）で通す（ADR 0087 の決定 3）ので、1 段あたりのスタックを小さく保つ。
//! 最適化しないビルドでは、関数の枠が、その関数の中のすべての一時の値の領域を持つ。そこで、
//! - 再帰の経路にある関数（子の式を辿る関数）は計算を `Box<Comp>` で受け渡し、枠には参照、`Vec`、
//!   `Box` だけを置く。
//! - 子を辿った後に大きな値（`Comp`・`CoreVal`）を組み立てる処理は、`*_rest` などの別の関数に分ける。
//!   その関数は再帰しないので、枠は再帰の間スタックに残らない。

use std::collections::HashMap;

use super::InternalError;
use super::core_ir::{
    Arm, Comp, CompKind, Const, CoreDef, CorePat, CoreProgram, CoreVal, DefOrigin, Lambda,
    LambdaId, Program, Val, ValKind, Var, VarId,
};
use crate::base::{BindingId, NodeId, Span};
use crate::builtins::BuiltinId;
use crate::builtins::table;
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast;
use crate::syntax::ast::{
    Arg, BinOp, BinaryExpr, Block, CallExpr, CtorPat, ElseBranch, Expr, FnDecl, IfExpr, Item,
    LambdaExpr, LetName, LetStmt, ListExpr, Literal, MatchExpr, NameExpr, Pattern, PipeExpr, Stmt,
    UnOp, UnaryExpr,
};
use crate::typeck::{TypeArgs, TypeckOutput};
use crate::types::{EffectSet, Ty, TyCon};

/// 型検査を通ったプログラムをコア IR に移す（02-06「脱糖」、01-12「表層からの脱糖」）。
pub fn desugar(
    prelude: &[ast::Program],
    user: &ast::Program,
    resolved: &ResolveOutput,
    types: &TypeckOutput,
) -> Result<CoreProgram, InternalError> {
    // 型検査を通ったプログラムには必ず `main` がある（01-07「プログラムの入口」）。
    let Some(main) = types.main else {
        return Err(*internal("the type checker output has no main".to_string()));
    };
    let mut d = Desugarer {
        resolved,
        types,
        next_var: 0,
        next_lambda: 0,
        locals: HashMap::new(),
    };
    // 定義の並びは、prelude のソースの定義（ファイルの名前の順、ファイルの中の順）の後に、
    // 利用者の定義（ソースの順）を置く（10-06 の `Program`）。
    let mut defs = Vec::new();
    for program in prelude.iter().chain(std::iter::once(user)) {
        for item in &program.items {
            match item {
                Item::Fn(f) => defs.push(d.def(f).map_err(|e| *e)?),
                // 型の宣言は定義を作らない。型の表は `types.adts` をそのまま写す。
                Item::Type(_) => {}
                Item::Error(e) => return Err(*error_node("item", e.id)),
            }
        }
    }
    Ok(Program {
        defs,
        adts: types.adts.clone(),
        main: main.binding,
        main_returns_result: main.returns_result,
        lambda_count: d.next_lambda,
    })
}

/// 段の中の結果の型。誤りを `Box` に入れ、再帰の経路で受け渡す値と一時の値を小さく保つ。
type R<T> = Result<T, Box<InternalError>>;

fn internal(message: String) -> Box<InternalError> {
    Box::new(InternalError {
        stage: "desugar",
        message,
    })
}

/// 構文エラーから回復したノード。型検査を通ったプログラムには現れない。
fn error_node(what: &str, id: NodeId) -> Box<InternalError> {
    internal(format!("error {what} at node {}", id.0))
}

/// 束縛を待つ計算。`wrap` が `let var ⇐ bound in …` に組む。
struct Pending {
    var: Var,
    bound: Box<Comp>,
    /// `let` の計算の由来位置（その束縛を生んだ構文の span。02-02）
    origin: Span,
}

/// 束縛の並び。先頭が最も外側の `let` になる。
type Lets = Vec<Pending>;

/// 呼び出しの引数。パイプの `t` とプレースホルダの引数は、すでに値（変数）になっている。
enum CallArg<'e> {
    Expr(&'e Expr),
    Ready(Box<CoreVal>),
}

/// 呼び出しの直接の引数（プレースホルダを含まない呼び出しのもの）。
fn plain_args(args: &[Arg]) -> Vec<CallArg<'_>> {
    let mut out = Vec::with_capacity(args.len());
    for a in args {
        if let Arg::Expr(e) = a {
            out.push(CallArg::Expr(e));
        }
    }
    out
}

fn has_placeholder(c: &CallExpr) -> bool {
    c.args.iter().any(|a| matches!(a, Arg::Placeholder(_)))
}

/// 脱糖の状態。大域の状態にせず、この構造体を `&mut` で渡す（ADR 0015）。
struct Desugarer<'a> {
    resolved: &'a ResolveOutput,
    types: &'a TypeckOutput,
    /// 定義ごとに 0 から振る変数の番号（02-06「コア IR」）
    next_var: u32,
    /// プログラム全体で一つの数え上げから振るラムダの番号
    next_lambda: u32,
    /// 局所の束縛の番号 → 変数の番号と型
    locals: HashMap<BindingId, (VarId, Ty)>,
}

// ---------------- 小さな組み立て ----------------

/// `return V`。型は V の型、エフェクトは空集合（02-06 の表）。
fn ret(val: CoreVal, origin: Span) -> Box<Comp> {
    Box::new(Comp {
        ty: val.ty.clone(),
        kind: CompKind::Return(val),
        eff: EffectSet::empty(),
        origin,
    })
}

fn const_val(c: Const, ty: Ty, origin: Span) -> CoreVal {
    Val {
        kind: ValKind::Const(c),
        ty,
        origin,
    }
}

/// `return ()`。
fn unit_comp(origin: Span) -> Box<Comp> {
    ret(const_val(Const::Unit, Ty::unit(), origin), origin)
}

/// `return true`・`return false`。
fn bool_comp(b: bool, origin: Span) -> Box<Comp> {
    ret(const_val(Const::Bool(b), Ty::bool(), origin), origin)
}

fn var_val(var: &Var, origin: Span) -> CoreVal {
    Val {
        kind: ValKind::Var(var.id),
        ty: var.ty.clone(),
        origin,
    }
}

/// 束縛の並びを、後ろから `let` の入れ子に組む。`let x ⇐ M in N` の型は N の型、エフェクトは
/// M と N の和集合（02-06 の表）。繰り返しで組むので、並びの長さに比例して再帰しない。
fn wrap(lets: Lets, body: Box<Comp>) -> Box<Comp> {
    let mut acc = body;
    for p in lets.into_iter().rev() {
        let ty = acc.ty.clone();
        let eff = p.bound.eff.union(&acc.eff);
        acc = Box::new(Comp {
            kind: CompKind::Let {
                var: p.var,
                bound: p.bound,
                body: acc,
            },
            ty,
            eff,
            origin: p.origin,
        });
    }
    acc
}

/// `if V then M else N`。型は元の表層の式の型、エフェクトは分岐の和集合（02-06 の表）。
fn if_comp(
    cond: CoreVal,
    then_branch: Box<Comp>,
    else_branch: Box<Comp>,
    ty: Ty,
    origin: Span,
) -> Box<Comp> {
    Box::new(Comp {
        eff: then_branch.eff.union(&else_branch.eff),
        kind: CompKind::If {
            cond,
            then_branch,
            else_branch,
        },
        ty,
        origin,
    })
}

/// 適用 `V(W̄)`。型は V の型（関数の型）の戻り値の型、エフェクトはその関数の型のエフェクト
/// （02-06 の表）。V が `b[T̄; Ē]` なら、置き換えた型のエフェクトである。
fn app(func: CoreVal, args: Vec<CoreVal>, origin: Span) -> R<Box<Comp>> {
    let Ty::Fn(f) = &func.ty else {
        return Err(internal(format!(
            "applying a value of a non-function type at bytes {}..{}",
            origin.start.0, origin.end.0
        )));
    };
    let (ty, eff) = (f.ret.clone(), f.effects.clone());
    Ok(Box::new(Comp {
        kind: CompKind::App { func, args },
        ty,
        eff,
        origin,
    }))
}

/// 関数の値 `λ(x̄:Ā). M`。型は `(Ā) → B ! ε`（B は M の型、ε は型検査の「ラムダのエフェクト」の値。
/// 02-06 の表）。本体の型が型検査の表の型と違っても本体の型を使う。差があればコア IR の検査器が
/// 不具合として見つける（作業 T17「型とエフェクトの付け方」）。
fn lambda_val(id: LambdaId, params: Vec<Var>, body: Comp, eff: EffectSet, span: Span) -> CoreVal {
    let ty = Ty::func(
        params.iter().map(|p| p.ty.clone()).collect(),
        body.ty.clone(),
        eff,
    );
    Val {
        kind: ValKind::Lambda(Box::new(Lambda {
            id,
            params,
            body,
            span,
        })),
        ty,
        origin: span,
    }
}

/// 整数リテラルの値。数字列を `u64` で読んでから符号を付けるので、`-9223372036854775808` も
/// 溢れずに `i64::MIN` になる（01-04「Int」）。範囲は型検査で確かめてある。
fn int_value(radix: u32, digits: &str, negative: bool) -> Option<i64> {
    let magnitude = u64::from_str_radix(digits, radix).ok()?;
    if negative {
        0i64.checked_sub_unsigned(magnitude)
    } else {
        i64::try_from(magnitude).ok()
    }
}

/// リテラルの値。`negative` は整数リテラルの前置の `-`（式の `-n` とパターンの `-n`）。
fn literal_const(id: NodeId, lit: &Literal, negative: bool) -> R<Const> {
    match lit {
        Literal::Int { radix, digits } => int_value(*radix, digits, negative)
            .map(Const::Int)
            .ok_or_else(|| internal(format!("integer literal out of range at node {}", id.0))),
        // Rust の `f64` の `FromStr` は最近接偶数丸めで読む。01-04「Float」の規則と一致する。
        Literal::Float(text) if !negative => text
            .parse::<f64>()
            .map(Const::Float)
            .map_err(|_| internal(format!("unreadable float literal at node {}", id.0))),
        Literal::Str(s) if !negative => Ok(Const::Str(s.clone())),
        Literal::Char(c) if !negative => Ok(Const::Char(*c)),
        Literal::Bool(b) if !negative => Ok(Const::Bool(*b)),
        Literal::Float(_) | Literal::Str(_) | Literal::Char(_) | Literal::Bool(_) => Err(internal(
            format!("negative non-integer literal at node {}", id.0),
        )),
    }
}

/// 二項演算子とオペランドの型の組から選ぶ組み込みの関数（10-10「演算子」）。`==`・`!=` は別に扱う。
const BINARY_OPS: [(BinOp, TyCon, BuiltinId); 26] = [
    (BinOp::Add, TyCon::Int, BuiltinId::AddInt),
    (BinOp::Sub, TyCon::Int, BuiltinId::SubInt),
    (BinOp::Mul, TyCon::Int, BuiltinId::MulInt),
    (BinOp::Div, TyCon::Int, BuiltinId::DivInt),
    (BinOp::Rem, TyCon::Int, BuiltinId::RemInt),
    (BinOp::Add, TyCon::Float, BuiltinId::AddFloat),
    (BinOp::Sub, TyCon::Float, BuiltinId::SubFloat),
    (BinOp::Mul, TyCon::Float, BuiltinId::MulFloat),
    (BinOp::Div, TyCon::Float, BuiltinId::DivFloat),
    (BinOp::Add, TyCon::String, BuiltinId::ConcatString),
    (BinOp::Lt, TyCon::Int, BuiltinId::LtInt),
    (BinOp::Le, TyCon::Int, BuiltinId::LeInt),
    (BinOp::Gt, TyCon::Int, BuiltinId::GtInt),
    (BinOp::Ge, TyCon::Int, BuiltinId::GeInt),
    (BinOp::Lt, TyCon::Float, BuiltinId::LtFloat),
    (BinOp::Le, TyCon::Float, BuiltinId::LeFloat),
    (BinOp::Gt, TyCon::Float, BuiltinId::GtFloat),
    (BinOp::Ge, TyCon::Float, BuiltinId::GeFloat),
    (BinOp::Lt, TyCon::String, BuiltinId::LtString),
    (BinOp::Le, TyCon::String, BuiltinId::LeString),
    (BinOp::Gt, TyCon::String, BuiltinId::GtString),
    (BinOp::Ge, TyCon::String, BuiltinId::GeString),
    (BinOp::Lt, TyCon::Char, BuiltinId::LtChar),
    (BinOp::Le, TyCon::Char, BuiltinId::LeChar),
    (BinOp::Gt, TyCon::Char, BuiltinId::GtChar),
    (BinOp::Ge, TyCon::Char, BuiltinId::GeChar),
];

/// 単項の `-` とオペランドの型の組から選ぶ組み込みの関数。
const NEG_OPS: [(TyCon, BuiltinId); 2] = [
    (TyCon::Int, BuiltinId::NegInt),
    (TyCon::Float, BuiltinId::NegFloat),
];

/// 演算子の `⊕_T`（02-06「コア IR」）。`==` と `!=` は型パラメータを一つ持つ `Eq`・`Ne` にし、
/// オペランドの型を型の引数にする。T は等値の型ならどの型でもよいので、型ごとの項目を作らない。
/// そのほかは演算子と型の組ごとの項目を指す。
fn binary_builtin(op: BinOp, operand: &Ty) -> Option<(BuiltinId, Vec<Ty>)> {
    if op == BinOp::Eq {
        return Some((BuiltinId::Eq, vec![operand.clone()]));
    }
    if op == BinOp::Ne {
        return Some((BuiltinId::Ne, vec![operand.clone()]));
    }
    let Ty::Con(con, args) = operand else {
        return None;
    };
    if !args.is_empty() {
        return None;
    }
    BINARY_OPS
        .iter()
        .find(|(o, c, _)| *o == op && c == con)
        .map(|(_, _, id)| (*id, Vec::new()))
}

fn neg_builtin(operand: &Ty) -> Option<BuiltinId> {
    let Ty::Con(con, args) = operand else {
        return None;
    };
    if !args.is_empty() {
        return None;
    }
    NEG_OPS.iter().find(|(c, _)| c == con).map(|(_, id)| *id)
}

/// 組み込みの関数の値 `b[T̄; ]`。型は組み込みの表の型を置き換えたもの（02-06 の表）。
fn builtin_val(id: BuiltinId, tys: Vec<Ty>, origin: Span) -> CoreVal {
    let ty = table::scheme(id).fn_ty().subst(&tys, &[]);
    Val {
        kind: ValKind::Builtin {
            id,
            tys,
            effs: Vec::new(),
        },
        ty,
        origin,
    }
}

impl<'a> Desugarer<'a> {
    // ---------------- 表を引く ----------------

    fn expr_type(&self, node: NodeId) -> R<Ty> {
        match self.types.expr_types.get(node) {
            Some(t) => Ok(t.clone()),
            None => Err(internal(format!("no expr_types entry for node {}", node.0))),
        }
    }

    fn lambda_effect(&self, node: NodeId) -> R<EffectSet> {
        match self.types.lambda_effects.get(node) {
            Some(e) => Ok(e.clone()),
            None => Err(internal(format!(
                "no lambda_effects entry for node {}",
                node.0
            ))),
        }
    }

    fn operand_type(&self, node: NodeId) -> R<&'a Ty> {
        self.types
            .operand_types
            .get(node)
            .ok_or_else(|| internal(format!("no operand_types entry for node {}", node.0)))
    }

    /// 多相な名前の置き換え `[T̄; Ē]`。表になければ多相でない名前なので空とする。
    fn type_args(&self, node: NodeId) -> TypeArgs {
        self.types.type_args.get(node).cloned().unwrap_or_default()
    }

    /// 名前を使う箇所の束縛の番号と種類。
    fn binding_of(&self, node: NodeId) -> R<(BindingId, BindingKind)> {
        let Some(b) = self.resolved.refs.get(node).copied() else {
            return Err(internal(format!("no refs entry for node {}", node.0)));
        };
        let Some(binding) = self.resolved.bindings.get(b) else {
            return Err(internal(format!("no binding {}", b.0)));
        };
        Ok((b, binding.kind))
    }

    /// 宣言したノードの束縛の番号。
    fn decl_of(&self, node: NodeId) -> R<BindingId> {
        self.resolved
            .decls
            .get(node)
            .copied()
            .ok_or_else(|| internal(format!("no decls entry for node {}", node.0)))
    }

    // ---------------- 番号を振る ----------------

    /// 新しい変数。脱糖で作る変数も、ソースの名前から移した変数も、定義ごとの同じ数え上げから振る
    /// （02-06「コア IR」）。
    fn fresh_var(&mut self, name: Option<String>, ty: Ty) -> R<Var> {
        let id = VarId(self.next_var);
        self.next_var = self
            .next_var
            .checked_add(1)
            .ok_or_else(|| internal("too many variables".to_string()))?;
        Ok(Var { id, name, ty })
    }

    /// ソースの名前の変数を作り、局所の束縛（引数、`let`、ラムダの引数、パターンの変数）の番号に
    /// 対応させる。変数の型は、宣言したノードの型である。
    fn local_var(&mut self, decl: NodeId, name: &str, ty: Ty) -> R<Var> {
        let binding = self.decl_of(decl)?;
        let var = self.fresh_var(Some(name.to_string()), ty)?;
        self.locals.insert(binding, (var.id, var.ty.clone()));
        Ok(var)
    }

    fn fresh_lambda(&mut self) -> R<LambdaId> {
        let id = LambdaId(self.next_lambda);
        self.next_lambda = self
            .next_lambda
            .checked_add(1)
            .ok_or_else(|| internal("too many lambdas".to_string()))?;
        Ok(id)
    }

    /// 計算を新しい変数に束縛し、その変数を値として返す（規則の `let x ⇐ ⟦e⟧ in …` の `x`）。
    /// 変数の型は計算の型とする。
    fn bind(&mut self, lets: &mut Lets, bound: Box<Comp>, origin: Span) -> R<CoreVal> {
        let var = self.fresh_var(None, bound.ty.clone())?;
        let val = var_val(&var, bound.origin);
        lets.push(Pending { var, bound, origin });
        Ok(val)
    }

    /// `bind` の値を `vals` に加える。
    fn bind_into(
        &mut self,
        lets: &mut Lets,
        vals: &mut Vec<CoreVal>,
        bound: Box<Comp>,
        origin: Span,
    ) -> R<()> {
        let val = self.bind(lets, bound, origin)?;
        vals.push(val);
        Ok(())
    }

    /// 結果を使わない計算を新しい変数 `z` に束縛する（`let _ = e` 以外の、最後でない式文）。
    fn bind_discard(&mut self, lets: &mut Lets, bound: Box<Comp>, origin: Span) -> R<()> {
        self.bind(lets, bound, origin).map(drop)
    }

    // ---------------- 定義 ----------------

    /// トップレベルの関数 `fn f[ᾱ, effect ρ̄](x̄: Ā) -> B uses ε B0` を、定義
    /// `fn f[ᾱ; ρ̄](x̄:Ā) : B ! ε = ⟦B0⟧` に移す（01-12「トップレベルの関数」）。
    fn def(&mut self, f: &FnDecl) -> R<CoreDef> {
        self.next_var = 0;
        self.locals.clear();
        let binding = self.decl_of(f.id)?;
        let Some(b) = self.resolved.bindings.get(binding) else {
            return Err(internal(format!("no binding {}", binding.0)));
        };
        let (origin, name) = match b.kind {
            BindingKind::TopFn => (DefOrigin::User, f.name.text.clone()),
            BindingKind::PreludeFn { module: Some(m) } => (
                DefOrigin::PreludePublic { module: m },
                format!("{}.{}", m.name(), f.name.text),
            ),
            BindingKind::PreludeFn { module: None } => {
                (DefOrigin::PreludeHelper, f.name.text.clone())
            }
            BindingKind::Builtin(_)
            | BindingKind::Ctor { .. }
            | BindingKind::Param
            | BindingKind::Let
            | BindingKind::LambdaParam
            | BindingKind::PatternVar
            | BindingKind::Type(_)
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Effect
            | BindingKind::Module(_) => {
                return Err(internal(format!(
                    "function declaration {} is not bound to a function",
                    f.id.0
                )));
            }
        };
        let Some(scheme) = self.types.decl_types.get(binding) else {
            return Err(internal(format!(
                "no decl_types entry for binding {}",
                binding.0
            )));
        };
        if scheme.params.len() != f.params.len() {
            return Err(internal(format!(
                "parameter count mismatch in function {}",
                f.id.0
            )));
        }
        // 引数の番号を先に振る（作業 T17「全体の流れ」の 4）。型は宣言の型の引数の型。
        let mut params = Vec::with_capacity(f.params.len());
        for (p, ty) in f.params.iter().zip(&scheme.params) {
            params.push(self.local_var(p.id, &p.name.text, ty.clone())?);
        }
        let body = self.block(&f.body)?;
        Ok(CoreDef {
            binding,
            name,
            origin,
            type_params: scheme.type_params.iter().map(|t| t.name.clone()).collect(),
            effect_params: scheme.effect_params.clone(),
            params,
            ret: scheme.ret.clone(),
            eff: scheme.effects.clone(),
            body: *body,
            span: f.span,
            var_count: self.next_var,
        })
    }

    // ---------------- 式 ----------------

    /// 表層の式 e を計算 `⟦e⟧` に移す（01-12「表層からの脱糖」）。構文ごとの関数に振り分けるだけにし、
    /// この関数の枠を小さく保つ。次の二行はここで移す（01-12「名前とリテラル」）。
    /// - `()`: `return ()`
    /// - `(e)`: `⟦e⟧`
    fn expr(&mut self, e: &Expr) -> R<Box<Comp>> {
        match e {
            Expr::Lit(l) => self.lit_expr(l.id, &l.lit, l.span),
            Expr::Name(n) => self.name_expr(n),
            // `()`: `return ()`（01-12「名前とリテラル」）。
            Expr::Unit(u) => Ok(unit_comp(u.span)),
            // `(e)`: `⟦e⟧`（01-12「名前とリテラル」）。
            Expr::Paren(p) => self.expr(&p.inner),
            Expr::List(l) => self.list_expr(l),
            Expr::Call(c) if has_placeholder(c) => self.placeholder_call(c),
            Expr::Call(c) => self.call_parts(&c.callee, plain_args(&c.args), c.span),
            Expr::Binary(b) if matches!(b.op, BinOp::And | BinOp::Or) => self.logic_expr(b),
            Expr::Binary(b) => self.binary_expr(b),
            Expr::Unary(u) => self.unary_expr(u),
            Expr::Pipe(p) => self.pipe_expr(p),
            Expr::Block(b) => self.block(b),
            Expr::If(i) => self.if_expr(i),
            Expr::Match(m) => self.match_expr(m),
            Expr::Lambda(l) => self.lambda_expr(l),
            Expr::Error(e) => Err(error_node("expression", e.id)),
        }
    }

    /// リテラル: `return c`（c はリテラルが表す値。01-12「名前とリテラル」）。
    fn lit_expr(&self, id: NodeId, lit: &Literal, span: Span) -> R<Box<Comp>> {
        let c = literal_const(id, lit, false)?;
        let ty = self.expr_type(id)?;
        Ok(ret(const_val(c, ty, span), span))
    }

    /// 名前の式（01-12「名前とリテラル」の名前の行。値は `name_val` が作る）。
    fn name_expr(&mut self, n: &NameExpr) -> R<Box<Comp>> {
        let val = self.name_val(n)?;
        Ok(ret(val, n.span))
    }

    /// 名前が表す値（01-12「名前とリテラル」）。
    /// - 局所の束縛の名前 `x`: `return x`
    /// - トップレベルの関数の名前 `f`: `return f[T̄; Ē]`
    /// - prelude の関数 `M.g`: Σ に定義があるもの（prelude のソースの関数）は `return M.g[T̄; Ē]`、
    ///   組み込みの関数は `return b[T̄; Ē]`
    /// - 構成子: `ctor_value` に任せる
    fn name_val(&mut self, n: &NameExpr) -> R<CoreVal> {
        let (b, kind) = self.binding_of(n.id)?;
        match kind {
            BindingKind::Param
            | BindingKind::Let
            | BindingKind::LambdaParam
            | BindingKind::PatternVar => {
                let Some((id, ty)) = self.locals.get(&b) else {
                    return Err(internal(format!(
                        "unbound local {} at node {}",
                        b.0, n.id.0
                    )));
                };
                Ok(Val {
                    kind: ValKind::Var(*id),
                    ty: ty.clone(),
                    origin: n.span,
                })
            }
            // prelude のソースの関数は Σ に定義があるので、組み込みの関数ではなく TopFn にする。
            BindingKind::TopFn | BindingKind::PreludeFn { .. } => {
                let Some(scheme) = self.types.decl_types.get(b) else {
                    return Err(internal(format!("no decl_types entry for binding {}", b.0)));
                };
                let args = self.type_args(n.id);
                let ty = scheme.fn_ty().subst(&args.tys, &args.effects);
                Ok(Val {
                    kind: ValKind::TopFn {
                        def: b,
                        tys: args.tys,
                        effs: args.effects,
                    },
                    ty,
                    origin: n.span,
                })
            }
            BindingKind::Builtin(id) => {
                // 値として使う組み込みの関数もこの形でよい。値として使うときの原型はコード生成が作る
                // （作業 T17「名前とリテラル」）。
                let args = self.type_args(n.id);
                let ty = table::scheme(id).fn_ty().subst(&args.tys, &args.effects);
                Ok(Val {
                    kind: ValKind::Builtin {
                        id,
                        tys: args.tys,
                        effs: args.effects,
                    },
                    ty,
                    origin: n.span,
                })
            }
            BindingKind::Ctor { con, tag } => self.ctor_value(n, con, tag),
            BindingKind::Type(_)
            | BindingKind::TypeParam { .. }
            | BindingKind::EffectVar { .. }
            | BindingKind::Effect
            | BindingKind::Module(_) => Err(internal(format!(
                "name at node {} does not denote a value",
                n.id.0
            ))),
        }
    }

    /// 構成子の名前を呼び出さずに使う（01-12「名前とリテラル」）。
    /// - 引数のない構成子 `T.C`、`None`: `return C[T̄]()`
    /// - 引数を持つ構成子 `T.C`、`Some` などを、呼び出さずに値として使う:
    ///   `return λ(y1:A1, …, yn:An). return C[T̄](y1, …, yn)`（`Ā` は構成子の引数の型）
    fn ctor_value(&mut self, n: &NameExpr, con: TyCon, tag: u32) -> R<CoreVal> {
        let tys = self.type_args(n.id).tys;
        let Some(fields) = self.types.adts.field_types(con, tag, &tys) else {
            return Err(internal(format!("unknown constructor at node {}", n.id.0)));
        };
        let ty = Ty::Con(con, tys.clone());
        if fields.is_empty() {
            return Ok(Val {
                kind: ValKind::Ctor {
                    con,
                    tag,
                    tys,
                    args: Vec::new(),
                },
                ty,
                origin: n.span,
            });
        }
        let id = self.fresh_lambda()?;
        let mut params = Vec::with_capacity(fields.len());
        for f in fields {
            params.push(self.fresh_var(None, f)?);
        }
        let args = params.iter().map(|p| var_val(p, n.span)).collect();
        let value = Val {
            kind: ValKind::Ctor {
                con,
                tag,
                tys,
                args,
            },
            ty,
            origin: n.span,
        };
        let body = ret(value, n.span);
        Ok(lambda_val(id, params, *body, EffectSet::empty(), n.span))
    }

    /// 呼ばれる式と引数の並びから呼び出しを作る（01-12「呼び出し」）。通常の呼び出しとパイプの展開の
    /// 両方から呼ぶ。
    /// - 構成子の呼び出し `T.C(e1, …, en)`、`Some(e1)`、`Ok(e1)`、`Err(e1)`（ADR 0007）:
    ///   `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return C[T̄](x1, …, xn)`
    /// - そのほかの呼び出し `e0(e1, …, en)`: `let y ⇐ ⟦e0⟧ in let x1 ⇐ ⟦e1⟧ in … y(x1, …, xn)`
    ///
    /// 引数は左から順に評価する（01-08「評価順序」）。`origin` は、作る計算の由来位置（呼び出しの式。
    /// パイプの展開ではパイプの式全体。02-02）。
    fn call_parts(&mut self, callee: &Expr, args: Vec<CallArg<'_>>, origin: Span) -> R<Box<Comp>> {
        let ctor = self.ctor_callee(callee)?;
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(args.len().saturating_add(1));
        if ctor.is_none() {
            let f = self.expr(callee)?;
            self.bind_into(&mut lets, &mut vals, f, origin)?;
        }
        for a in args {
            if let CallArg::Expr(e) = a {
                let c = self.expr(e)?;
                self.bind_into(&mut lets, &mut vals, c, origin)?;
            } else {
                push_ready(&mut vals, a);
            }
        }
        self.call_rest(ctor, lets, vals, origin)
    }

    /// 呼ばれる式が構成子を指す名前なら、その名前のノードと構成子。
    fn ctor_callee(&self, callee: &Expr) -> R<Option<(NodeId, TyCon, u32)>> {
        let Expr::Name(n) = callee else {
            return Ok(None);
        };
        if let (_, BindingKind::Ctor { con, tag }) = self.binding_of(n.id)? {
            Ok(Some((n.id, con, tag)))
        } else {
            Ok(None)
        }
    }

    fn call_rest(
        &self,
        ctor: Option<(NodeId, TyCon, u32)>,
        lets: Lets,
        mut vals: Vec<CoreVal>,
        origin: Span,
    ) -> R<Box<Comp>> {
        let comp = match ctor {
            Some((name, con, tag)) => {
                let tys = self.type_args(name).tys;
                let value = Val {
                    ty: Ty::Con(con, tys.clone()),
                    kind: ValKind::Ctor {
                        con,
                        tag,
                        tys,
                        args: vals,
                    },
                    origin,
                };
                ret(value, origin)
            }
            None => {
                if vals.is_empty() {
                    return Err(internal("a call without a callee".to_string()));
                }
                let func = vals.remove(0);
                app(func, vals, origin)?
            }
        };
        Ok(wrap(lets, comp))
    }

    /// プレースホルダを含む呼び出し。`f(a1, _, a3)` を `fn(p1) { f(a1, p1, a3) }` に展開してから、
    /// 01-12「呼び出し」の規則で移す（01-02「部分適用のプレースホルダ」）。呼ぶ関数とプレースホルダで
    /// ない引数は、ラムダの本体の中で評価する（01-08「評価順序」）。ラムダとその本体の呼び出しの
    /// 由来位置は、プレースホルダを含む呼び出しの式全体（02-02）。
    fn placeholder_call(&mut self, c: &CallExpr) -> R<Box<Comp>> {
        let id = self.fresh_lambda()?;
        let mut params = Vec::new();
        let mut args = Vec::with_capacity(c.args.len());
        for a in &c.args {
            match a {
                Arg::Expr(e) => args.push(CallArg::Expr(e)),
                Arg::Placeholder(p) => {
                    let v = self.placeholder_param(p.id, p.span, &mut params)?;
                    args.push(CallArg::Ready(v));
                }
            }
        }
        let body = self.call_parts(&c.callee, args, c.span)?;
        self.placeholder_rest(c, id, params, body)
    }

    /// プレースホルダを置き換える新しい引数。型はプレースホルダの型（作業 T17）。
    fn placeholder_param(
        &mut self,
        id: NodeId,
        span: Span,
        params: &mut Vec<Var>,
    ) -> R<Box<CoreVal>> {
        let ty = self.expr_type(id)?;
        let var = self.fresh_var(None, ty)?;
        let v = Box::new(var_val(&var, span));
        params.push(var);
        Ok(v)
    }

    fn placeholder_rest(
        &self,
        c: &CallExpr,
        id: LambdaId,
        params: Vec<Var>,
        body: Box<Comp>,
    ) -> R<Box<Comp>> {
        let eff = self.lambda_effect(c.id)?;
        Ok(ret(lambda_val(id, params, *body, eff, c.span), c.span))
    }

    /// パイプ `e1 |> e2`: `let t ⇐ ⟦e1⟧ in ⟦e'⟧`（01-12「呼び出し」、01-02「パイプ」、ADR 0050）。
    /// e' は次の規則で作る。
    /// 1. e2 が呼び出しで、直接の引数にプレースホルダがなければ、最も外側の呼び出しの引数の先頭に t を
    ///    加えた呼び出し。直接の引数だけを見るので、`f(g(_))` は `f(t, g(_))` になる。
    /// 2. それ以外（括弧の式、名前、ラムダ、直接の引数にプレースホルダを含む呼び出しなど）は `e2(t)`。
    ///
    /// 展開で作った呼び出しの由来位置は、パイプの式全体の span（02-02）。
    fn pipe_expr(&mut self, p: &PipeExpr) -> R<Box<Comp>> {
        let lhs = self.expr(&p.lhs)?;
        let mut lets = Lets::new();
        let t = self.pipe_bind(p, lhs, &mut lets)?;
        // 規則 1。`g(a)(b)` の形では、e2 そのものが最も外側の呼び出し `(b)` である。
        // 括弧の式は `Expr::Paren` なのでここに当たらず、中身によらず規則 2 になる。
        let body = if let Expr::Call(c) = p.rhs.as_ref()
            && !has_placeholder(c)
        {
            let mut args = plain_args(&c.args);
            args.insert(0, CallArg::Ready(t));
            self.call_parts(&c.callee, args, p.span)?
        } else {
            // 規則 2。直接の引数にプレースホルダを含む呼び出しは、`⟦e2⟧` がラムダに展開してから適用する。
            self.call_parts(&p.rhs, vec![CallArg::Ready(t)], p.span)?
        };
        Ok(wrap(lets, body))
    }

    /// パイプの左辺を `t` に束縛する。`t` の型は e1 の式の型（作業 T17「パイプ」）。
    fn pipe_bind(&mut self, p: &PipeExpr, lhs: Box<Comp>, lets: &mut Lets) -> R<Box<CoreVal>> {
        let ty = self.expr_type(p.lhs.id())?;
        let var = self.fresh_var(None, ty)?;
        let t = Box::new(var_val(&var, lhs.origin));
        lets.push(Pending {
            var,
            bound: lhs,
            origin: p.span,
        });
        Ok(t)
    }

    /// 二項演算子 `e1 ⊕ e2`（⊕ は `+ - * / % == != < <= > >=`）:
    /// `let x ⇐ ⟦e1⟧ in let y ⇐ ⟦e2⟧ in ⊕_T(x, y)`（01-12「演算子」）。
    /// 演算子を適用する計算の由来位置は、演算子の式全体（02-02 の `a / b` の例）。
    fn binary_expr(&mut self, b: &BinaryExpr) -> R<Box<Comp>> {
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(2);
        let l = self.expr(&b.lhs)?;
        self.bind_into(&mut lets, &mut vals, l, b.span)?;
        let r = self.expr(&b.rhs)?;
        self.bind_into(&mut lets, &mut vals, r, b.span)?;
        self.binary_rest(b, lets, vals)
    }

    fn binary_rest(&self, b: &BinaryExpr, lets: Lets, vals: Vec<CoreVal>) -> R<Box<Comp>> {
        let operand = self.operand_type(b.id)?;
        let Some((id, tys)) = binary_builtin(b.op, operand) else {
            return Err(internal(format!(
                "no builtin for operator {:?} on the operand type at node {}",
                b.op, b.id.0
            )));
        };
        let comp = app(builtin_val(id, tys, b.op_span), vals, b.span)?;
        Ok(wrap(lets, comp))
    }

    /// 論理演算（01-12「演算子」）。
    /// - `e1 && e2`: `let x ⇐ ⟦e1⟧ in if x then ⟦e2⟧ else return false`
    /// - `e1 || e2`: `let x ⇐ ⟦e1⟧ in if x then return true else ⟦e2⟧`
    ///
    /// e2 を `let` の左側に移さないので、e2 の中の末尾呼び出しは末尾位置のまま残る（01-08「末尾呼び出し」）。
    fn logic_expr(&mut self, b: &BinaryExpr) -> R<Box<Comp>> {
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(1);
        let l = self.expr(&b.lhs)?;
        self.bind_into(&mut lets, &mut vals, l, b.span)?;
        let r = self.expr(&b.rhs)?;
        self.logic_rest(b, lets, vals, r)
    }

    fn logic_rest(
        &self,
        b: &BinaryExpr,
        lets: Lets,
        mut vals: Vec<CoreVal>,
        r: Box<Comp>,
    ) -> R<Box<Comp>> {
        let ty = self.expr_type(b.id)?;
        let Some(x) = vals.pop() else {
            return Err(internal("missing operand".to_string()));
        };
        let comp = if b.op == BinOp::And {
            if_comp(x, r, bool_comp(false, b.span), ty, b.span)
        } else {
            if_comp(x, bool_comp(true, b.span), r, ty, b.span)
        };
        Ok(wrap(lets, comp))
    }

    /// 単項の演算子（01-12「名前とリテラル」「演算子」）。
    /// - 単項の `-` を整数リテラルに直接適用した式 `-n`: `return c`（c は −n）
    /// - `-e`（上の `-n` を除く）: `let x ⇐ ⟦e⟧ in neg_T(x)`
    /// - `!e`: `let x ⇐ ⟦e⟧ in if x then return false else return true`
    fn unary_expr(&mut self, u: &UnaryExpr) -> R<Box<Comp>> {
        // 括弧を挟んだ `-(5)` は、オペランドが `Expr::Paren` なので、この規則に当たらない。
        if u.op == UnOp::Neg
            && let Expr::Lit(l) = u.operand.as_ref()
            && let Literal::Int { .. } = &l.lit
        {
            let c = literal_const(l.id, &l.lit, true)?;
            return Ok(ret(const_val(c, Ty::int(), u.span), u.span));
        }
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(1);
        let e = self.expr(&u.operand)?;
        self.bind_into(&mut lets, &mut vals, e, u.span)?;
        self.unary_rest(u, lets, vals)
    }

    fn unary_rest(&self, u: &UnaryExpr, lets: Lets, mut vals: Vec<CoreVal>) -> R<Box<Comp>> {
        let comp = match u.op {
            UnOp::Neg => {
                let operand = self.operand_type(u.id)?;
                let Some(id) = neg_builtin(operand) else {
                    return Err(internal(format!(
                        "no builtin for negation on the operand type at node {}",
                        u.id.0
                    )));
                };
                app(builtin_val(id, Vec::new(), u.op_span), vals, u.span)?
            }
            UnOp::Not => {
                let ty = self.expr_type(u.id)?;
                let Some(x) = vals.pop() else {
                    return Err(internal("missing operand".to_string()));
                };
                if_comp(
                    x,
                    bool_comp(false, u.span),
                    bool_comp(true, u.span),
                    ty,
                    u.span,
                )
            }
        };
        Ok(wrap(lets, comp))
    }

    /// リスト `[e1, …, en]`: `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return [x1, …, xn]`
    /// （01-12「リスト、ラムダ、条件分岐、match」）。値の型は元の式の型（02-06 の表）。
    fn list_expr(&mut self, l: &ListExpr) -> R<Box<Comp>> {
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(l.elems.len());
        for e in &l.elems {
            let c = self.expr(e)?;
            self.bind_into(&mut lets, &mut vals, c, l.span)?;
        }
        self.list_rest(l, lets, vals)
    }

    fn list_rest(&self, l: &ListExpr, lets: Lets, vals: Vec<CoreVal>) -> R<Box<Comp>> {
        let value = Val {
            kind: ValKind::List(vals),
            ty: self.expr_type(l.id)?,
            origin: l.span,
        };
        Ok(wrap(lets, ret(value, l.span)))
    }

    /// ラムダ `fn(x1, …, xn) { … }`: `return λ(x1:A1, …, xn:An). ⟦{ … }⟧`（`Ā` は型検査が決めた引数の型。
    /// 01-12「リスト、ラムダ、条件分岐、match」）。戻り値の型注釈と `uses` は型検査で使い終えているので
    /// 残さない。
    fn lambda_expr(&mut self, l: &LambdaExpr) -> R<Box<Comp>> {
        let id = self.fresh_lambda()?;
        let params = self.lambda_params(l)?;
        let body = self.block(&l.body)?;
        self.lambda_rest(l, id, params, body)
    }

    fn lambda_params(&mut self, l: &LambdaExpr) -> R<Vec<Var>> {
        let mut params = Vec::with_capacity(l.params.len());
        for p in &l.params {
            let ty = self.expr_type(p.id)?;
            params.push(self.local_var(p.id, &p.name.text, ty)?);
        }
        Ok(params)
    }

    fn lambda_rest(
        &self,
        l: &LambdaExpr,
        id: LambdaId,
        params: Vec<Var>,
        body: Box<Comp>,
    ) -> R<Box<Comp>> {
        let eff = self.lambda_effect(l.id)?;
        Ok(ret(lambda_val(id, params, *body, eff, l.span), l.span))
    }

    /// 条件分岐（01-12「リスト、ラムダ、条件分岐、match」）。
    /// - `if e B1 else B2`: `let x ⇐ ⟦e⟧ in if x then ⟦B1⟧ else ⟦B2⟧`
    /// - `if e B1 else if …`: `else` の後の `if` を B2 として上の規則で移す
    /// - `if e B1`（`else` なし）: `let x ⇐ ⟦e⟧ in if x then ⟦B1⟧ else return ()`
    fn if_expr(&mut self, i: &IfExpr) -> R<Box<Comp>> {
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(1);
        let c = self.expr(&i.cond)?;
        self.bind_into(&mut lets, &mut vals, c, i.span)?;
        let then_branch = self.block(&i.then_block)?;
        let else_branch = match &i.else_branch {
            None => unit_comp(i.span),
            Some(ElseBranch::Block(b)) => self.block(b)?,
            Some(ElseBranch::If(inner)) => self.if_expr(inner)?,
        };
        self.if_rest(i, lets, vals, then_branch, else_branch)
    }

    fn if_rest(
        &self,
        i: &IfExpr,
        lets: Lets,
        mut vals: Vec<CoreVal>,
        then_branch: Box<Comp>,
        else_branch: Box<Comp>,
    ) -> R<Box<Comp>> {
        let ty = self.expr_type(i.id)?;
        let Some(x) = vals.pop() else {
            return Err(internal("missing condition".to_string()));
        };
        Ok(wrap(lets, if_comp(x, then_branch, else_branch, ty, i.span)))
    }

    /// `match e { p1 => e1 … pn => en }`: `let x ⇐ ⟦e⟧ in match x { p1' ⇒ ⟦e1⟧ | … | pn' ⇒ ⟦en⟧ }`
    /// （01-12「リスト、ラムダ、条件分岐、match」）。型は元の式の型、エフェクトは各分岐の本体の
    /// エフェクトの和集合（02-06 の表）。
    fn match_expr(&mut self, m: &MatchExpr) -> R<Box<Comp>> {
        let mut lets = Lets::new();
        let mut vals = Vec::with_capacity(1);
        let s = self.expr(&m.scrutinee)?;
        self.bind_into(&mut lets, &mut vals, s, m.span)?;
        let mut arms = Vec::with_capacity(m.arms.len());
        for arm in &m.arms {
            // パターンの変数に番号を振ってから本体を辿る（本体がその変数を使う）。
            let pattern = self.pattern(&arm.pattern)?;
            let body = self.expr(&arm.body)?;
            push_arm(&mut arms, pattern, body);
        }
        self.match_rest(m, lets, vals, arms)
    }

    fn match_rest(
        &self,
        m: &MatchExpr,
        lets: Lets,
        mut vals: Vec<CoreVal>,
        arms: Vec<Arm>,
    ) -> R<Box<Comp>> {
        let Some(scrutinee) = vals.pop() else {
            return Err(internal("missing scrutinee".to_string()));
        };
        let mut eff = EffectSet::empty();
        for arm in &arms {
            eff = eff.union(&arm.body.eff);
        }
        let comp = Box::new(Comp {
            kind: CompKind::Match { scrutinee, arms },
            ty: self.expr_type(m.id)?,
            eff,
            origin: m.span,
        });
        Ok(wrap(lets, comp))
    }

    /// パターン `p'`: 表層のパターン `p` から構成子の型名の修飾を除き、`-n` の形の整数リテラルを
    /// 負の定数にしたもの（01-12「リスト、ラムダ、条件分岐、match」）。構成子のパターンだけが再帰する。
    fn pattern(&mut self, p: &Pattern) -> R<CorePat> {
        let Pattern::Ctor(c) = p else {
            return self.simple_pattern(p);
        };
        let (con, tag) = self.ctor_of_pattern(c)?;
        let mut args = Vec::with_capacity(c.args.len());
        for a in &c.args {
            let q = self.pattern(a)?;
            args.push(q);
        }
        Ok(CorePat::Ctor { con, tag, args })
    }

    fn ctor_of_pattern(&self, c: &CtorPat) -> R<(TyCon, u32)> {
        if let (_, BindingKind::Ctor { con, tag }) = self.binding_of(c.id)? {
            Ok((con, tag))
        } else {
            Err(internal(format!(
                "constructor pattern at node {} is not bound to a constructor",
                c.id.0
            )))
        }
    }

    /// 構成子でないパターン。変数のパターンには新しい変数を振る。
    fn simple_pattern(&mut self, p: &Pattern) -> R<CorePat> {
        match p {
            Pattern::Wildcard(_) => Ok(CorePat::Wild),
            Pattern::Var(v) => {
                let ty = self.expr_type(v.id)?;
                Ok(CorePat::Var(self.local_var(v.id, &v.name.text, ty)?))
            }
            Pattern::Lit(l) => Ok(CorePat::Const(literal_const(l.id, &l.lit, l.negative)?)),
            Pattern::Unit(_) => Ok(CorePat::Const(Const::Unit)),
            Pattern::Ctor(c) => Err(internal(format!(
                "constructor pattern at node {} in simple_pattern",
                c.id.0
            ))),
            Pattern::Error(e) => Err(error_node("pattern", e.id)),
        }
    }

    // ---------------- ブロック ----------------

    /// ブロックを、文の並びの先頭から順に移す（01-12「ブロック」）。
    /// - `{ }`: `return ()`
    /// - `{ e }`（最後の文が式）: `⟦e⟧`
    /// - `{ let x = e }`（最後の文が `let`）: `let x ⇐ ⟦e⟧ in return ()`
    /// - `{ let x = e; s̄ }`（型注釈 `let x: T = e` も同じ）: `let x ⇐ ⟦e⟧ in ⟦{ s̄ }⟧`
    /// - `{ let _ = e; s̄ }`: `let z ⇐ ⟦e⟧ in ⟦{ s̄ }⟧`
    /// - `{ e; s̄ }`（式文）: `let z ⇐ ⟦e⟧ in ⟦{ s̄ }⟧`
    ///
    /// 残りの文の並び `s̄` を再帰で辿らず、束縛を積んでから `wrap` で組む。
    fn block(&mut self, b: &Block) -> R<Box<Comp>> {
        let mut lets = Lets::new();
        let mut result = None;
        let last = b.stmts.len().saturating_sub(1);
        for (i, s) in b.stmts.iter().enumerate() {
            match s {
                Stmt::Let(l) => {
                    let c = self.expr(&l.value)?;
                    self.let_stmt(l, c, &mut lets)?;
                    if i == last {
                        result = Some(unit_comp(l.span));
                    }
                }
                Stmt::Expr(e) if i == last => result = Some(self.expr(e)?),
                Stmt::Expr(e) => {
                    let c = self.expr(e)?;
                    self.bind_discard(&mut lets, c, e.span())?;
                }
                Stmt::Error(e) => return Err(error_node("statement", e.id)),
            }
        }
        let body = result.unwrap_or_else(|| unit_comp(b.span));
        Ok(wrap(lets, body))
    }

    /// `let x = e` と `let _ = e` の束縛。`let x` の変数の型は `let` 文の型（型注釈があればその型）、
    /// `let _` の変数の型は計算の型。
    fn let_stmt(&mut self, l: &LetStmt, bound: Box<Comp>, lets: &mut Lets) -> R<()> {
        let var = match &l.name {
            LetName::Var(name) => {
                let ty = self.expr_type(l.id)?;
                self.local_var(l.id, &name.text, ty)?
            }
            LetName::Wildcard(_) => self.fresh_var(None, bound.ty.clone())?,
        };
        lets.push(Pending {
            var,
            bound,
            origin: l.span,
        });
        Ok(())
    }
}

/// 値になっている引数を並びに加える。`CoreVal` を再帰の経路の関数の枠に置かないために分けてある。
fn push_ready(vals: &mut Vec<CoreVal>, a: CallArg<'_>) {
    if let CallArg::Ready(v) = a {
        vals.push(*v);
    }
}

/// 分岐を並びに加える。`Comp` を再帰の経路の関数の枠に置かないために分けてある。
fn push_arm(arms: &mut Vec<Arm>, pattern: CorePat, body: Box<Comp>) {
    arms.push(Arm {
        pattern,
        body: *body,
    });
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)] // テストの失敗は panic で表す（07-03）
mod tests {
    //! 脱糖のテスト（作業 T17「受け入れテスト」）。ソースを本物の字句解析・構文解析・名前解決・型検査に
    //! 通してから `desugar` を呼び、結果のコア IR の形を確かめる。

    use super::*;
    use crate::base::{FileId, IdGen, SourceKind};
    use crate::builtins::PreludeModule;
    use crate::ir::check::check_program;
    use crate::resolve::resolve;
    use crate::syntax::lexer::lex;
    use crate::syntax::newline::resolve_newlines;
    use crate::syntax::parser::parse;
    use crate::typeck::typecheck;

    fn parse_one(
        file: FileId,
        kind: SourceKind,
        src: &str,
        ids: &mut IdGen,
    ) -> Option<ast::Program> {
        let lexed = lex(file, src.as_bytes());
        let out = parse(
            file,
            kind,
            resolve_newlines(lexed.tokens),
            lexed.comments,
            ids,
        );
        (lexed.diagnostics.is_empty() && out.diagnostics.is_empty()).then_some(out.program)
    }

    /// 型検査までを誤りなく通したプログラム。
    struct Front {
        prelude: Vec<ast::Program>,
        user: ast::Program,
        resolved: ResolveOutput,
        types: TypeckOutput,
    }

    fn front(src: &str) -> Front {
        let mut ids = IdGen::new();
        let prelude: Vec<ast::Program> = crate::prelude::SOURCES
            .iter()
            .enumerate()
            .map(|(i, (_, text))| {
                parse_one(FileId(i as u32), SourceKind::Prelude, text, &mut ids).unwrap()
            })
            .collect();
        let file = FileId(prelude.len() as u32);
        let user = parse_one(file, SourceKind::User, src, &mut ids).expect("syntax error");
        let resolved = resolve(&prelude, &user, &mut ids);
        assert!(
            resolved.diagnostics.is_empty(),
            "{:?}",
            resolved.diagnostics
        );
        let (types, diags) = typecheck(&prelude, &user, &resolved);
        assert!(diags.is_empty(), "{diags:#?}");
        Front {
            prelude,
            user,
            resolved,
            types,
        }
    }

    struct Lowered {
        src: String,
        program: CoreProgram,
    }

    const MAIN: &str = "\nfn main() -> Unit { () }\n";

    /// ソースを脱糖する。`main` がなければ加える。
    fn lower(src: &str) -> Lowered {
        let src = if src.contains("fn main(") {
            src.to_string()
        } else {
            format!("{src}{MAIN}")
        };
        let f = front(&src);
        let program = desugar(&f.prelude, &f.user, &f.resolved, &f.types).unwrap();
        Lowered { src, program }
    }

    impl Lowered {
        fn text(&self, span: Span) -> &str {
            &self.src[span.start.0 as usize..span.end.0 as usize]
        }

        fn def(&self, name: &str) -> &CoreDef {
            self.program
                .defs
                .iter()
                .find(|d| d.origin == DefOrigin::User && d.name == name)
                .unwrap_or_else(|| panic!("no user def {name}"))
        }

        /// 利用者の定義の本体。
        fn body(&self, name: &str) -> &Comp {
            &self.def(name).body
        }

        fn binding(&self, name: &str) -> BindingId {
            self.program
                .defs
                .iter()
                .find(|d| d.name == name)
                .unwrap_or_else(|| panic!("no def {name}"))
                .binding
        }

        fn param(&self, def: &str, i: usize) -> VarId {
            self.def(def).params[i].id
        }
    }

    // ---- 形を取り出す補助 ----

    fn as_let(c: &Comp) -> (&Var, &Comp, &Comp) {
        let CompKind::Let { var, bound, body } = &c.kind else {
            panic!("expected let, got {:?}", c.kind)
        };
        (var, bound, body)
    }

    fn as_return(c: &Comp) -> &CoreVal {
        let CompKind::Return(v) = &c.kind else {
            panic!("expected return, got {:?}", c.kind)
        };
        v
    }

    fn as_app(c: &Comp) -> (&CoreVal, &[CoreVal]) {
        let CompKind::App { func, args } = &c.kind else {
            panic!("expected application, got {:?}", c.kind)
        };
        (func, args)
    }

    fn as_if(c: &Comp) -> (&CoreVal, &Comp, &Comp) {
        let CompKind::If {
            cond,
            then_branch,
            else_branch,
        } = &c.kind
        else {
            panic!("expected if, got {:?}", c.kind)
        };
        (cond, then_branch, else_branch)
    }

    fn as_lambda(v: &CoreVal) -> &Lambda<Comp> {
        let ValKind::Lambda(l) = &v.kind else {
            panic!("expected lambda, got {:?}", v.kind)
        };
        l
    }

    /// `let` の並びを辿り、(束縛の並び, 最後の計算) に分ける。
    fn lets_of(c: &Comp) -> (Vec<(&Var, &Comp)>, &Comp) {
        let mut out = Vec::new();
        let mut cur = c;
        while let CompKind::Let { var, bound, body } = &cur.kind {
            out.push((var, &**bound));
            cur = body;
        }
        (out, cur)
    }

    fn var_of(v: &CoreVal) -> VarId {
        let ValKind::Var(id) = &v.kind else {
            panic!("expected a variable, got {:?}", v.kind)
        };
        *id
    }

    fn builtin_of(v: &CoreVal) -> (BuiltinId, &[Ty]) {
        let ValKind::Builtin { id, tys, .. } = &v.kind else {
            panic!("expected a builtin, got {:?}", v.kind)
        };
        (*id, tys)
    }

    /// 構成子を適用した値の (型, タグ, 型の引数, 引数)。
    fn ctor_of(v: &CoreVal) -> (TyCon, u32, &[Ty], &[CoreVal]) {
        let ValKind::Ctor {
            con,
            tag,
            tys,
            args,
        } = &v.kind
        else {
            panic!("expected a constructor value, got {:?}", v.kind)
        };
        (*con, *tag, tys, args)
    }

    fn int_of(v: &CoreVal) -> i64 {
        let ValKind::Const(Const::Int(n)) = &v.kind else {
            panic!("expected an Int constant, got {:?}", v.kind)
        };
        *n
    }

    // ---- 受け入れテスト ----

    #[test]
    fn division_binds_both_operands_then_applies_div_int() {
        let l = lower("fn f(a: Int, b: Int) -> Int { a / b }");
        let (x, bx, rest) = as_let(l.body("f"));
        assert_eq!(var_of(as_return(bx)), l.param("f", 0));
        let (y, by, app) = as_let(rest);
        assert_eq!(var_of(as_return(by)), l.param("f", 1));
        assert_ne!(x.id, y.id);
        let (func, args) = as_app(app);
        assert_eq!(builtin_of(func), (BuiltinId::DivInt, &[][..]));
        assert_eq!(
            args.iter().map(var_of).collect::<Vec<_>>(),
            vec![x.id, y.id]
        );
        assert_eq!(l.text(app.origin), "a / b");
        assert_eq!(app.ty, Ty::int());
        assert!(app.eff.is_empty());
    }

    #[test]
    fn operator_is_chosen_by_the_operand_type() {
        let cases: [(&str, &str, BuiltinId, Vec<Ty>); 6] = [
            ("1.0 + 2.0", "Float", BuiltinId::AddFloat, vec![]),
            ("\"a\" + \"b\"", "String", BuiltinId::ConcatString, vec![]),
            ("'a' > 'b'", "Bool", BuiltinId::GtChar, vec![]),
            (
                "[1] == [2]",
                "Bool",
                BuiltinId::Eq,
                vec![Ty::list(Ty::int())],
            ),
            ("\"a\" != \"b\"", "Bool", BuiltinId::Ne, vec![Ty::string()]),
            ("7 % 2", "Int", BuiltinId::RemInt, vec![]),
        ];
        for (expr, ret_ty, id, tys) in cases {
            let l = lower(&format!("fn f() -> {ret_ty} {{ {expr} }}"));
            let (bindings, app) = lets_of(l.body("f"));
            assert_eq!(bindings.len(), 2, "{expr}");
            let (func, _) = as_app(app);
            assert_eq!(builtin_of(func), (id, &tys[..]), "{expr}");
        }
    }

    #[test]
    fn negative_integer_literal_is_a_constant_but_parenthesized_is_negation() {
        let l = lower(
            "fn f() -> Int { -9223372036854775808 }\nfn g() -> Int { -(5) }\nfn h() -> Int { -0x10 }",
        );
        assert_eq!(int_of(as_return(l.body("f"))), i64::MIN);
        assert_eq!(int_of(as_return(l.body("h"))), -16);
        let (x, five, app) = as_let(l.body("g"));
        assert_eq!(int_of(as_return(five)), 5);
        let (func, args) = as_app(app);
        assert_eq!(builtin_of(func).0, BuiltinId::NegInt);
        assert_eq!(var_of(&args[0]), x.id);
    }

    #[test]
    fn logical_and_keeps_the_right_operand_in_the_branch() {
        let l = lower(
            "fn g(b: Bool) -> Bool { b }\nfn f(a: Bool, b: Bool) -> Bool { a && g(b) }\nfn h(a: Bool, b: Bool) -> Bool { a || b }",
        );
        let (x, bx, cond) = as_let(l.body("f"));
        assert_eq!(var_of(as_return(bx)), l.param("f", 0));
        let (c, then_branch, else_branch) = as_if(cond);
        assert_eq!(var_of(c), x.id);
        // `g(b)` の呼び出しは then の分岐の中にあり、その末尾は `let` の左側でない適用である。
        let (bindings, call) = lets_of(then_branch);
        let (func, _) = as_app(call);
        assert_eq!(var_of(func), bindings[0].0.id);
        assert!(matches!(
            as_return(bindings[0].1).kind,
            ValKind::TopFn { def, .. } if def == l.binding("g")
        ));
        assert!(matches!(
            as_return(else_branch).kind,
            ValKind::Const(Const::Bool(false))
        ));
        // `||` は then が `return true`、else が右のオペランド。
        let (_, _, cond) = as_let(l.body("h"));
        let (_, then_branch, else_branch) = as_if(cond);
        assert!(matches!(
            as_return(then_branch).kind,
            ValKind::Const(Const::Bool(true))
        ));
        assert_eq!(var_of(as_return(else_branch)), l.param("h", 1));
    }

    #[test]
    fn pipe_rule_1_puts_the_left_value_first() {
        let l = lower(
            "fn g(n: Int) -> Int { n }\nfn f(xs: List[Int]) -> List[Int] { xs |> List.map(g) }",
        );
        let body = l.body("f");
        let (t, bt, rest) = as_let(body);
        assert_eq!(var_of(as_return(bt)), l.param("f", 0));
        let (bindings, app) = lets_of(rest);
        let (y, by) = bindings[0];
        assert!(matches!(
            as_return(by).kind,
            ValKind::TopFn { def, .. } if def == l.binding("List.map")
        ));
        let (func, args) = as_app(app);
        assert_eq!(var_of(func), y.id);
        assert_eq!(var_of(&args[0]), t.id);
        let (x1, bg) = bindings[1];
        assert!(matches!(
            as_return(bg).kind,
            ValKind::TopFn { def, .. } if def == l.binding("g")
        ));
        assert_eq!(var_of(&args[1]), x1.id);
        assert_eq!(l.text(app.origin), "xs |> List.map(g)");

        // `x |> g(a)(b)` は最も外側の呼び出し `(b)` に加え、`g(a)(x, b)` になる（01-02「パイプ」）。
        let l = lower(
            "fn g(a: Int) -> fn(Int, Int) -> Int { fn(p, q) { p - q + a } }\nfn f(x: Int) -> Int { x |> g(1)(2) }",
        );
        let (t, bt, rest) = as_let(l.body("f"));
        assert_eq!(var_of(as_return(bt)), l.param("f", 0));
        let (bindings, app) = lets_of(rest);
        // 呼ばれる値は `g(1)` の結果。その計算は `g` に 1 だけを渡す適用である。
        let (y, by) = bindings[0];
        let (gb, g_app) = lets_of(by);
        assert!(matches!(
            as_return(gb[0].1).kind,
            ValKind::TopFn { def, .. } if def == l.binding("g")
        ));
        assert_eq!(int_of(as_return(gb[1].1)), 1);
        assert_eq!(as_app(g_app).1.len(), 1);
        let (x2, b2) = bindings[1];
        assert_eq!(int_of(as_return(b2)), 2);
        let (func, args) = as_app(app);
        assert_eq!(var_of(func), y.id);
        assert_eq!(
            args.iter().map(var_of).collect::<Vec<_>>(),
            vec![t.id, x2.id]
        );
        assert_eq!(l.text(app.origin), "x |> g(1)(2)");
    }

    #[test]
    fn pipe_into_parenthesized_call_applies_its_result() {
        let l = lower(
            "fn h(n: Int) -> fn(Int) -> Int { fn(m) { n + m } }\nfn f(x: Int) -> Int { x |> (h(1)) }",
        );
        let (t, _, rest) = as_let(l.body("f"));
        let (y, by, app) = as_let(rest);
        // y は `h(1)` の結果。その計算は `h` に 1 を渡す適用である。
        let (hb, h_app) = lets_of(by);
        assert!(matches!(
            as_return(hb[0].1).kind,
            ValKind::TopFn { def, .. } if def == l.binding("h")
        ));
        assert_eq!(int_of(as_return(hb[1].1)), 1);
        assert_eq!(as_app(h_app).1.len(), 1);
        let (func, args) = as_app(app);
        assert_eq!(var_of(func), y.id);
        assert_eq!(args.iter().map(var_of).collect::<Vec<_>>(), vec![t.id]);
    }

    #[test]
    fn pipe_rule_2_and_direct_placeholders() {
        // 名前への規則 2、直接の引数のプレースホルダ（規則 2）、入れ子のプレースホルダ（規則 1）。
        let l = lower(
            "fn g(a: Int, b: Int) -> Int { a - b }\nfn k(n: Int) -> Int { n }\nfn ap(n: Int, f: fn(Int) -> Int) -> Int { f(n) }\n\
             fn f1(x: Int) -> Int { x |> k }\nfn f2(x: Int) -> Int { x |> g(1, _) }\nfn f3(x: Int) -> Int { x |> ap(g(_, 2)) }",
        );
        // f1: let t ⇐ x in let y ⇐ return k in y(t)
        let (t, _, rest) = as_let(l.body("f1"));
        let (_, by, app) = as_let(rest);
        assert!(matches!(as_return(by).kind, ValKind::TopFn { def, .. } if def == l.binding("k")));
        assert_eq!(var_of(&as_app(app).1[0]), t.id);
        // f2: let t ⇐ x in let y ⇐ return λ(p). (g(1, p)) in y(t)
        let (t, _, rest) = as_let(l.body("f2"));
        let (_, by, app) = as_let(rest);
        let lam = as_lambda(as_return(by));
        assert_eq!(lam.params.len(), 1);
        let (_, inner) = lets_of(&lam.body);
        assert_eq!(var_of(&as_app(inner).1[1]), lam.params[0].id);
        assert_eq!(var_of(&as_app(app).1[0]), t.id);
        // f3: ap(t, g(_, 2))。t は最初の引数で、2 つ目はラムダ。
        let (t, _, rest) = as_let(l.body("f3"));
        let (bindings, app) = lets_of(rest);
        let (_, args) = as_app(app);
        assert_eq!(var_of(&args[0]), t.id);
        assert!(matches!(as_return(bindings[1].1).kind, ValKind::Lambda(_)));
    }

    #[test]
    fn placeholder_call_becomes_a_lambda_evaluating_other_arguments_inside() {
        let l = lower(
            "fn clamp(lo: Int, x: Int, hi: Int) -> Int { x }\nfn f() -> fn(Int) -> Int { clamp(0, _, 100) }",
        );
        let body = l.body("f");
        let lam = as_lambda(as_return(body));
        assert_eq!(l.text(lam.span), "clamp(0, _, 100)");
        assert_eq!(lam.params.len(), 1);
        assert_eq!(lam.params[0].ty, Ty::int());
        let (bindings, app) = lets_of(&lam.body);
        assert!(matches!(
            as_return(bindings[0].1).kind,
            ValKind::TopFn { def, .. } if def == l.binding("clamp")
        ));
        assert_eq!(int_of(as_return(bindings[1].1)), 0);
        assert_eq!(int_of(as_return(bindings[2].1)), 100);
        let (_, args) = as_app(app);
        assert_eq!(var_of(&args[1]), lam.params[0].id);
        assert_eq!(l.text(app.origin), "clamp(0, _, 100)");
        assert_eq!(
            as_return(body).ty,
            Ty::func(vec![Ty::int()], Ty::int(), EffectSet::empty())
        );
    }

    #[test]
    fn constructors_called_nullary_and_used_as_values() {
        let l = lower(
            "type Shape {\n  Circle(Float)\n  Square(Float)\n}\ntype Tree {\n  Leaf\n  Node(Tree, Tree)\n}\n\
             fn c() -> Shape { Shape.Circle(1.0) }\nfn t() -> Tree { Tree.Leaf }\n\
             fn m(rs: List[Float]) -> List[Shape] { List.map(rs, Shape.Circle) }\nfn s() -> Option[Int] { Some(1) }",
        );
        let shape = l
            .program
            .adts
            .adts
            .iter()
            .find(|a| a.name == "Shape")
            .unwrap()
            .con;
        let tree = l
            .program
            .adts
            .adts
            .iter()
            .find(|a| a.name == "Tree")
            .unwrap()
            .con;
        // Shape.Circle(1.0): let x ⇐ return 1.0 in return Circle(x)
        let (x, one, r) = as_let(l.body("c"));
        assert!(matches!(as_return(one).kind, ValKind::Const(Const::Float(f)) if f == 1.0));
        let (con, tag, _, args) = ctor_of(as_return(r));
        assert_eq!((con, tag), (shape, 0));
        assert_eq!(args.iter().map(var_of).collect::<Vec<_>>(), vec![x.id]);
        assert_eq!(as_return(r).ty, Ty::con(shape));
        // Tree.Leaf: return Leaf()
        let (con, tag, _, args) = ctor_of(as_return(l.body("t")));
        assert_eq!((con, tag, args.len()), (tree, 0, 0));
        // Shape.Circle を値として使う: λ(y:Float). return Circle(y)
        let (bindings, _) = lets_of(l.body("m"));
        let circle = as_return(bindings[2].1);
        let lam = as_lambda(circle);
        assert_eq!(lam.params.len(), 1);
        assert_eq!(lam.params[0].ty, Ty::float());
        let (con, _, _, args) = ctor_of(as_return(&lam.body));
        assert_eq!(con, shape);
        assert_eq!(var_of(&args[0]), lam.params[0].id);
        assert_eq!(
            circle.ty,
            Ty::func(vec![Ty::float()], Ty::con(shape), EffectSet::empty())
        );
        // Some(1) は構成子の呼び出しで、型の引数を持つ。
        let (_, _, r) = as_let(l.body("s"));
        let (con, _, tys, _) = ctor_of(as_return(r));
        assert_eq!((con, tys), (TyCon::Option, &[Ty::int()][..]));
    }

    #[test]
    fn builtin_used_as_a_value() {
        let l = lower("fn f(xs: List[Int]) -> List[String] { List.map(xs, Int.toString) }");
        let (bindings, _) = lets_of(l.body("f"));
        let v = as_return(bindings[2].1);
        assert_eq!(builtin_of(v).0, BuiltinId::IntToString);
        assert_eq!(
            v.ty,
            Ty::func(vec![Ty::int()], Ty::string(), EffectSet::empty())
        );
    }

    #[test]
    fn block_binds_discarded_values_to_distinct_variables() {
        let l = lower(
            "fn f() -> Unit { () }\nfn g() -> Unit { () }\nfn b() -> Int {\n  let _ = f()\n  g()\n  1\n}\n\
             fn e() -> Unit { }\nfn last() -> Unit {\n  let x = 1\n}",
        );
        let (z1, bf, rest) = as_let(l.body("b"));
        let (z2, bg, one) = as_let(rest);
        assert_ne!(z1.id, z2.id);
        assert!(
            matches!(as_return(as_let(bf).1).kind, ValKind::TopFn { def, .. } if def == l.binding("f"))
        );
        assert!(
            matches!(as_return(as_let(bg).1).kind, ValKind::TopFn { def, .. } if def == l.binding("g"))
        );
        assert_eq!(int_of(as_return(one)), 1);
        assert!(matches!(
            as_return(l.body("e")).kind,
            ValKind::Const(Const::Unit)
        ));
        // 最後の文が let なら `let x ⇐ ⟦e⟧ in return ()`
        let (x, _, unit) = as_let(l.body("last"));
        assert_eq!(x.name.as_deref(), Some("x"));
        assert!(matches!(as_return(unit).kind, ValKind::Const(Const::Unit)));
    }

    #[test]
    fn if_without_else_returns_unit_and_else_if_nests() {
        let l = lower(
            "fn f(c: Bool) -> Unit uses IO { if c { Console.println(\"a\") } }\n\
             fn g(a: Bool, b: Bool) -> Int { if a { 1 } else if b { 2 } else { 3 } }",
        );
        let body = l.body("f");
        let (_, _, cond) = as_let(body);
        let (_, then_branch, else_branch) = as_if(cond);
        assert!(matches!(
            as_return(else_branch).kind,
            ValKind::Const(Const::Unit)
        ));
        assert!(then_branch.eff.io);
        assert_eq!(body.eff, EffectSet::io());
        let (_, _, cond) = as_let(l.body("g"));
        let (_, _, else_branch) = as_if(cond);
        let (_, _, inner) = as_let(else_branch);
        let (_, two, three) = as_if(inner);
        assert_eq!(int_of(as_return(two)), 2);
        assert_eq!(int_of(as_return(three)), 3);
    }

    #[test]
    fn match_binds_the_scrutinee_and_strips_qualifiers() {
        let l = lower(
            "fn f(o: Option[Int]) -> Int {\n  match o {\n    Some(x) => x\n    None => 0\n  }\n}\n\
             fn g(n: Int) -> Int {\n  match n {\n    -1 => 0\n    _ => n\n  }\n}",
        );
        let option = l.program.adts.get(TyCon::Option).unwrap();
        let tag_of = |name: &str| option.ctors.iter().find(|c| c.name == name).unwrap().tag;
        let (s, bs, m) = as_let(l.body("f"));
        assert_eq!(var_of(as_return(bs)), l.param("f", 0));
        let CompKind::Match { scrutinee, arms } = &m.kind else {
            panic!("{m:?}")
        };
        assert_eq!(var_of(scrutinee), s.id);
        let CorePat::Ctor { con, tag, args } = &arms[0].pattern else {
            panic!("{:?}", arms[0].pattern)
        };
        assert_eq!((*con, *tag), (TyCon::Option, tag_of("Some")));
        let [CorePat::Var(x)] = &args[..] else {
            panic!("{args:?}")
        };
        assert_eq!(x.ty, Ty::int());
        assert_eq!(var_of(as_return(&arms[0].body)), x.id);
        assert_eq!(
            arms[1].pattern,
            CorePat::Ctor {
                con: TyCon::Option,
                tag: tag_of("None"),
                args: vec![]
            }
        );
        assert_eq!(int_of(as_return(&arms[1].body)), 0);
        assert_eq!(m.ty, Ty::int());
        // 前置の `-` を付けたリテラルのパターンは負の定数になる。
        let (_, _, m) = as_let(l.body("g"));
        let CompKind::Match { arms, .. } = &m.kind else {
            panic!("{m:?}")
        };
        assert_eq!(arms[0].pattern, CorePat::Const(Const::Int(-1)));
        assert_eq!(arms[1].pattern, CorePat::Wild);
    }

    /// 定義の中で振った変数の番号（引数、`let`、パターン、ラムダの引数）をすべて集める。
    fn collect_vars(c: &Comp, out: &mut Vec<VarId>) {
        match &c.kind {
            CompKind::Return(v) => collect_val_vars(v, out),
            CompKind::Let { var, bound, body } => {
                out.push(var.id);
                collect_vars(bound, out);
                collect_vars(body, out);
            }
            CompKind::App { func, args } => {
                collect_val_vars(func, out);
                args.iter().for_each(|a| collect_val_vars(a, out));
            }
            CompKind::If {
                then_branch,
                else_branch,
                ..
            } => {
                collect_vars(then_branch, out);
                collect_vars(else_branch, out);
            }
            CompKind::Match { arms, .. } => {
                for arm in arms {
                    collect_pat_vars(&arm.pattern, out);
                    collect_vars(&arm.body, out);
                }
            }
        }
    }

    fn collect_val_vars(v: &CoreVal, out: &mut Vec<VarId>) {
        match &v.kind {
            ValKind::Lambda(l) => {
                out.extend(l.params.iter().map(|p| p.id));
                collect_vars(&l.body, out);
            }
            ValKind::Ctor { args, .. } | ValKind::List(args) => {
                args.iter().for_each(|a| collect_val_vars(a, out));
            }
            ValKind::Var(_)
            | ValKind::Const(_)
            | ValKind::TopFn { .. }
            | ValKind::Builtin { .. } => {}
        }
    }

    fn collect_pat_vars(p: &CorePat, out: &mut Vec<VarId>) {
        match p {
            CorePat::Var(v) => out.push(v.id),
            CorePat::Ctor { args, .. } => args.iter().for_each(|a| collect_pat_vars(a, out)),
            CorePat::Wild | CorePat::Const(_) => {}
        }
    }

    #[test]
    fn variables_get_distinct_numbers_per_definition() {
        let l = lower(
            "fn f(a: Int) -> Int {\n  let x = a\n  let x = x + 1\n  let x = x * 2\n  match Some(x) {\n    Some(y) => (fn(z) { z + y })(x)\n    None => x\n  }\n}",
        );
        let def = l.def("f");
        let mut vars: Vec<VarId> = def.params.iter().map(|p| p.id).collect();
        collect_vars(&def.body, &mut vars);
        let count = vars.len();
        vars.sort();
        vars.dedup();
        assert_eq!(vars.len(), count, "a variable number was reused");
        assert_eq!(def.var_count as usize, count);
        assert_eq!(vars.last().map(|v| v.0 + 1), Some(def.var_count));
        // 三つの `x` は別の変数で、二つ目の `x + 1` は一つ目の `x` を読む。
        let (x1, _, rest) = as_let(&def.body);
        let (x2, b2, rest) = as_let(rest);
        let (x3, _, _) = as_let(rest);
        assert!(x1.id != x2.id && x2.id != x3.id && x1.id != x3.id);
        assert_eq!(var_of(as_return(as_let(b2).1)), x1.id);
    }

    #[test]
    fn body_effects_are_computed_bottom_up() {
        let l = lower(
            "fn main() -> Unit uses IO { Console.println(\"a\") }\nfn p(n: Int) -> Int { n + 1 }",
        );
        assert_eq!(l.def("main").body.eff, EffectSet::io());
        assert!(l.def("p").body.eff.is_empty());
    }

    #[test]
    fn prelude_definitions_come_first_with_qualified_names() {
        let l = lower("fn mapInto(n: Int) -> Int { n }");
        let defs = &l.program.defs;
        let first_user = defs
            .iter()
            .position(|d| d.origin == DefOrigin::User)
            .unwrap();
        assert!(
            defs[first_user..]
                .iter()
                .all(|d| d.origin == DefOrigin::User)
        );
        let map = defs.iter().find(|d| d.name == "List.map").unwrap();
        assert_eq!(
            map.origin,
            DefOrigin::PreludePublic {
                module: PreludeModule::List
            }
        );
        let helpers: Vec<DefOrigin> = defs
            .iter()
            .filter(|d| d.name == "mapInto")
            .map(|d| d.origin)
            .collect();
        assert_eq!(helpers, vec![DefOrigin::PreludeHelper, DefOrigin::User]);
        assert_eq!(l.program.main, l.binding("main"));
        assert!(!l.program.main_returns_result);
    }

    /// 脱糖の結果に 01-12 の型付け規則で型が付く（01-12「確かめる性質」の 1。02-06「コア IR の検査器」）。
    /// 利用者の `main` だけのプログラムでは、prelude のソースのすべての定義を脱糖して確かめる。
    #[test]
    fn desugared_programs_are_well_typed() {
        let sources = [
            "fn main() -> Unit { () }",
            "fn show(a: Int, b: Int) -> String { Int.toString(a) + \",\" + Int.toString(b) }\n\
             fn twice[T, effect E](f: fn(T) -> T uses E, x: T) -> T uses E { f(f(x)) }\n\
             fn main() -> Result[Unit, String] uses IO {\n\
               Console.println(1 |> show(2))\n\
               Console.println(2 |> show(1, _))\n\
               let xs = [3, 1, 2] |> List.map(fn(n) { n * 2 }) |> List.filter(fn(n) { n > 2 })\n\
               let _ = twice(fn(s) { Console.println(s)\n s }, \"hi\")\n\
               let ok = !(1 < 2) || 'a' <= 'b' && -1.5 < 2.0\n\
               if ok && List.length(xs) == 2 { Ok(()) } else { Err(\"bad\") }\n\
             }",
            "type Tree[T] {\n  Leaf\n  Node(Tree[T], T, Tree[T])\n}\n\
             fn size[T](t: Tree[T]) -> Int {\n  match t {\n    Tree.Leaf => 0\n    Tree.Node(l, _, r) => size(l) + 1 + size(r)\n  }\n}\n\
             fn build(n: Int) -> Tree[Int] { if n == 0 { Tree.Leaf } else { Tree.Node(build(n - 1), n, Tree.Leaf) } }\n\
             fn main() -> Unit uses IO { Console.println(Int.toString(size(build(3)))) }",
        ];
        for src in sources {
            let l = lower(src);
            let errors = check_program(&l.program);
            assert!(errors.is_empty(), "{src}\n{errors:#?}");
        }
    }

    // ---- 深い入れ子 ----

    fn user_parses(src: &str) -> bool {
        let mut ids = IdGen::new();
        parse_one(FileId(0), SourceKind::User, src, &mut ids).is_some()
    }

    /// 構文解析器が受け付ける最も深い入れ子（02-03「入れ子の深さ」）を、テストのスレッドの既定の
    /// スタックで脱糖できることを確かめる（00-02「再帰の深さ」、ADR 0087 の決定 3）。前段は順に走り、
    /// 脱糖と同時にスタックに載らない。
    #[test]
    fn nesting_up_to_the_parser_limit() {
        type Make = fn(usize) -> String;
        let body = |e: String| {
            format!("fn f(x: Int, a: Bool) -> Int {{\n  {e}\n}}\nfn main() -> Unit {{ () }}\n")
        };
        let cases: Vec<(&str, Make)> = vec![
            ("parens", |n| format!("{}x{}", "(".repeat(n), ")".repeat(n))),
            ("blocks", |n| {
                format!("{}x{}", "{ ".repeat(n), " }".repeat(n))
            }),
            ("calls", |n| {
                format!("{}x{}", "f(".repeat(n), ", a)".repeat(n))
            }),
            ("operators", |n| format!("x{}", " + x".repeat(n))),
            ("negation", |n| format!("{}x", "-".repeat(n))),
            ("not", |n| {
                format!("if {}a {{ x }} else {{ x }}", "!".repeat(n))
            }),
            ("and", |n| {
                format!("if a{} {{ x }} else {{ x }}", " && a".repeat(n))
            }),
            ("pipes", |n| format!("x{}", " |> f(a)".repeat(n))),
            ("placeholders", |n| {
                format!("{}x{}", "f(_, a)(".repeat(n), ")".repeat(n))
            }),
            ("if", |n| {
                format!("{}x{}", "if a { ".repeat(n), " } else { x }".repeat(n))
            }),
            ("else if", |n| {
                format!("if a {{ x }}{} else {{ x }}", " else if a { x }".repeat(n))
            }),
            ("match", |n| {
                format!("{}x{}", "match x { y => ".repeat(n), " }".repeat(n))
            }),
            ("lambda", |n| {
                format!("let g = {}x{}\n  x", "fn(y) { ".repeat(n), " }".repeat(n))
            }),
            ("let", |n| {
                format!("{}x{}", "{ let y = ".repeat(n), "\n y }".repeat(n))
            }),
            ("lists", |n| {
                format!("let l = {}x{}\n  x", "[".repeat(n), "]".repeat(n))
            }),
            ("list elements", |n| {
                format!("let l = [{}]\n  x", vec!["x"; n].join(", "))
            }),
            ("statements", |n| {
                format!("{}x", "let y = x + 1\n  ".repeat(n))
            }),
            ("match arms", |n| {
                let arms: String = (0..n).map(|i| format!("    {i} => x\n")).collect();
                format!("match x {{\n{arms}    _ => x\n  }}")
            }),
        ];
        for (name, make) in cases {
            let (mut lo, mut hi) = (1usize, 1100usize);
            assert!(user_parses(&body(make(lo))), "{name}");
            assert!(!user_parses(&body(make(hi))), "{name}");
            while hi - lo > 1 {
                let mid = (lo + hi) / 2;
                if user_parses(&body(make(mid))) {
                    lo = mid;
                } else {
                    hi = mid;
                }
            }
            let f = front(&body(make(lo)));
            let program = desugar(&f.prelude, &f.user, &f.resolved, &f.types);
            assert!(program.is_ok(), "{name}: {:?}", program.err());
        }
        // 深いパターン
        let deep_match = |n: usize| {
            format!(
                "fn f(x: {}Int{}) -> Int {{\n  match x {{ {}y{} => y\n _ => 0 }}\n}}\nfn main() -> Unit {{ () }}\n",
                "Option[".repeat(n),
                "]".repeat(n),
                "Some(".repeat(n),
                ")".repeat(n)
            )
        };
        let (mut lo, mut hi) = (1usize, 1100usize);
        assert!(!user_parses(&deep_match(hi)));
        while hi - lo > 1 {
            let mid = (lo + hi) / 2;
            if user_parses(&deep_match(mid)) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        let f = front(&deep_match(lo));
        let program = desugar(&f.prelude, &f.user, &f.resolved, &f.types);
        assert!(program.is_ok(), "{:?}", program.err());
    }
}
