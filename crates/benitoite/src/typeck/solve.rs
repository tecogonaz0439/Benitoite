//! 制約を解く部分（設計書 02-05「制約の解決」「誤りの報告と検査の継続」）。
//!
//! 型変数の union-find、単一化と出現検査、流れ込む制約の後回しと解き直し、集まりと等値の制約の判定、
//! エフェクトの含まれる制約の最小解と検査を行い、解けなかった制約を診断にする。
//! 状態は一つの本体の検査ごとに作って捨てる（02-05「検査の手順」、ADR 0015）。

use std::collections::HashSet;
use std::rc::Rc;

use crate::base::Span;
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::syntax::ast::BinOp;
use crate::types::{AdtTable, EffVar, EffectSet, Ty, TyCon, TyNames, TySet};

use super::infer::{
    Constraint, EffInfer, IEffect, IFnTy, ITy, OpName, Priority, Reason, ReasonKind, TyVar,
};

/// 診断の型板に埋める値のうち、型の表示でないもの（00-02「文言」）。
mod text {
    /// `+` の修正案 `to_string` に示す関数の名前（02-05「誤りの報告と検査の継続」）
    pub const INT_TO_STRING: &str = "Int.toString";
    pub const FLOAT_TO_STRING: &str = "Float.toString";
    pub const CHAR_TO_STRING: &str = "Char.toString";
    /// 集まりの型を並べるときの最後の区切り（「`Int`, `Float`, and `String`」）
    pub const AND: &str = "and";
}

/// 型変数（union-find の要素）の状態。
#[derive(Clone, Debug)]
struct VarNode {
    /// union-find の親。代表元は自分自身を指す
    parent: u32,
    /// 代表元のときの、組の要素の数（小さい組を大きい組に付けて、木を浅く保つ）
    size: u32,
    /// 決まった型。`Some(ITy::Error)` は誤りの型になった型変数の記録である。
    /// 型変数どうしは束ねるので、`ITy::Var` を入れない。
    /// `Rc` にするのは、単一化の途中で決まった型を取り出すときに、深い型を複製しないためである
    binding: Option<Rc<ITy>>,
    /// 集まりの制約とその理由
    one_of: Option<(TySet, Reason)>,
    /// 等値の制約の理由
    equality: Option<Reason>,
}

/// エフェクトの要素。`IO` か、検査している関数のエフェクト変数。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
enum Elem {
    Io,
    Var(EffVar),
}

impl Elem {
    fn is_in(self, set: &EffectSet) -> bool {
        match self {
            Elem::Io => set.io,
            Elem::Var(v) => set.vars.binary_search(&v).is_ok(),
        }
    }

    fn insert_into(self, set: &mut EffectSet) {
        match self {
            Elem::Io => set.io = true,
            Elem::Var(v) => set.insert_var(v),
        }
    }

    fn as_set(self) -> EffectSet {
        let mut set = EffectSet::empty();
        self.insert_into(&mut set);
        set
    }
}

/// 集合の要素を、`IO` を先に、エフェクト変数を昇順に並べる（`TyNames::show_effects` と同じ順）。
fn elems_of(set: &EffectSet) -> Vec<Elem> {
    let mut out = Vec::new();
    if set.io {
        out.push(Elem::Io);
    }
    out.extend(set.vars.iter().map(|v| Elem::Var(*v)));
    out
}

/// エフェクトの変数の状態。
#[derive(Clone, Debug, Default)]
struct EffState {
    /// 現在の集合（02-05 のエフェクトの手順の S(v)）
    set: EffectSet,
    /// 要素ごとの由来（その要素を生じた呼び出しの位置。01-06「式のエフェクト」）
    origins: Vec<(Elem, Span)>,
}

/// 含まれる制約の出どころ。
#[derive(Clone, Debug)]
enum EffOrigin {
    /// T15 が作った含まれる制約
    Given,
    /// 流れ込む制約と単一化が作った含まれる制約。満たされなければ、エフェクトの誤りではなく
    /// 元の制約の型の不一致（E0401）として報告するので、元の制約の番号と両辺の型を覚える
    Derived {
        group: usize,
        from: Rc<ITy>,
        to: Rc<ITy>,
    },
}

#[derive(Clone, Debug)]
struct EffSubItem {
    sub: IEffect,
    sup: IEffect,
    reason: Reason,
    origin: EffOrigin,
}

/// 制約が解けなかった事情。診断の種類は、制約の理由と合わせて `failure_diag` で決める。
#[derive(Clone, Debug)]
enum Failure {
    /// 形の違う型どうし（E0401・E0402・E0403・E0416）
    Mismatch,
    /// 出現検査の失敗（E0404）
    Occurs,
    /// 集まりの制約を満たさない（E0405）。`reason` は型変数に付いていた制約の理由、
    /// `var` はその制約を持っていた型変数（`+` の修正案で、同じ演算の相手のオペランドを引くために使う）
    OneOf {
        set: TySet,
        ty: ITy,
        reason: Reason,
        var: Option<TyVar>,
    },
    /// 等値の制約を満たさない（E0406）。`reason` は型変数に付いていた制約の理由
    Equality { ty: ITy, reason: Reason },
}

/// 単一化が含まれる制約を作るときに、元の制約から引き継ぐ情報。
struct Origin<'c> {
    reason: &'c Reason,
    group: usize,
    from: &'c Rc<ITy>,
    to: &'c Rc<ITy>,
}

/// 解けなかった制約の辺（診断に示し、誤りの型にする型変数を集める）。
enum Site<'c> {
    Pair { expected: &'c ITy, found: &'c ITy },
    Single(&'c ITy),
}

impl Site<'_> {
    fn types(&self) -> Vec<&ITy> {
        match self {
            Site::Pair { expected, found } => vec![*expected, *found],
            Site::Single(t) => vec![*t],
        }
    }
}

/// 後回しにした流れ込む制約。
struct Deferred {
    group: usize,
    from: Rc<ITy>,
    to: Rc<ITy>,
    reason: Reason,
}

/// 最も外側の型変数を置き換えた型（`Solver::shallow`）。決まった型は `Rc` を共有し、
/// 与えられた型はそのまま借りるので、深い型を複製しない。
enum Shallow<'a> {
    Given(&'a ITy),
    Bound(Rc<ITy>),
    /// 決まっていない型変数の代表元（`ITy::Var`）
    Unbound(ITy),
}

impl Shallow<'_> {
    fn get(&self) -> &ITy {
        match self {
            Shallow::Given(t) => t,
            Shallow::Bound(t) => t,
            Shallow::Unbound(t) => t,
        }
    }
}

// ---- 型を辿る処理のスタックの大きさについて ----
//
// 型の入れ子の深さは AST の深さの定数倍（構文解析器の上限 1000 程度）に収まるので、型を辿る処理は再帰で書く
// （00-02「再帰の深さ」）。ただし各段の単体テストは既定のスタック（2 MiB）で通す（ADR 0087）ので、
// 深さ 1000 の型を扱えるように、再帰の 1 段あたりの枠を小さく保つ。そのために次のようにする。
// - 再帰する関数は、反復子の連鎖（`map`・`collect`・`any`・`all`）ではなく明示のループで書く。
//   連鎖は段ごとに閉包と反復子の枠を重ねる。
// - 深い型を derive した `Clone` で複製しない（`Clone` も同じ深さの再帰になり、枠が大きい）。
//   決まった型は `Rc` で共有し、どうしても複製するときは `copy_ty` を使う。
// - 一段で使わない大きな一時の値（診断の組み立て、関数の型の形作り）は別の関数に分ける。

/// 型を複製する。derive した `Clone` より 1 段あたりの枠が小さい（上の注記）。
/// 形の違う型どうしの失敗。`Box::new` の引数の一時の値が呼び出し側の枠に載らないように、関数に分ける。
fn mismatch() -> Box<Failure> {
    Box::new(Failure::Mismatch)
}

fn copy_ty(ty: &ITy) -> ITy {
    match ty {
        ITy::Var(v) => ITy::Var(*v),
        ITy::Con(c, args) => ITy::Con(*c, copy_tys(args)),
        ITy::Fn(f) => copy_fn(f),
        ITy::Param(i) => ITy::Param(*i),
        ITy::Error => ITy::Error,
    }
}

fn copy_tys(tys: &[ITy]) -> Vec<ITy> {
    let mut out = Vec::with_capacity(tys.len());
    for t in tys {
        out.push(copy_ty(t));
    }
    out
}

/// 流れ込む制約で型変数を決める関数の型。引数と戻り値の型は `f` と同じで、エフェクトは `effect`。
fn shaped_fn(f: &IFnTy, effect: &IEffect) -> ITy {
    ITy::Fn(Box::new(IFnTy {
        params: copy_tys(&f.params),
        ret: copy_ty(&f.ret),
        effect: effect.clone(),
    }))
}

fn copy_fn(f: &IFnTy) -> ITy {
    ITy::Fn(Box::new(IFnTy {
        params: copy_tys(&f.params),
        ret: copy_ty(&f.ret),
        effect: f.effect.clone(),
    }))
}

/// 一回の `solve` の間だけ使う状態。
#[derive(Default)]
struct Run {
    diags: Vec<Diagnostic>,
    /// 解けなかった制約の番号。その制約から作った含まれる制約で、同じ誤りを二度報告しないために使う
    failed: HashSet<usize>,
    /// `+` のオペランドを等しくする制約（理由 `Operands { op: + }`）の (演算の型の型変数, オペランドの型) の組。
    /// T15 は `Equal(α, 左)`・`Equal(α, 右)` を作るので、α から同じ演算の二つのオペランドを引ける。
    /// E0405 の `+` の修正案で、集まりの制約を満たさなかった型の相手が `String` かを調べるために使う
    /// （02-05「誤りの報告と検査の継続」の 2 番目の項目）
    add_operands: Vec<(TyVar, ITy)>,
}

/// 一つの本体の検査で使う、型変数と制約を解く状態。本体ごとに作って捨てる（02-05「検査の手順」）。
#[derive(Debug, Default)]
pub struct Solver {
    vars: Vec<VarNode>,
    effs: Vec<EffState>,
    /// `solve` より前にその場で付けられなかった制約（既に決まった型変数への制約など）。
    /// `solve` の手順 2 の最初に解く
    pending: Vec<Constraint>,
    /// 単一化と流れ込む制約が作った含まれる制約。手順 3 で解く
    derived: Vec<EffSubItem>,
}

/// 解くときに参照する情報。
#[derive(Clone, Copy, Debug)]
pub struct SolveEnv<'a> {
    pub adts: &'a AdtTable,
    /// 検査している関数の型パラメータとエフェクト変数の名前（診断の型の表示に使う）
    pub type_params: &'a [String],
    pub effect_params: &'a [String],
}

impl SolveEnv<'_> {
    fn names(&self) -> TyNames<'_> {
        TyNames {
            adts: self.adts,
            type_params: self.type_params,
            effect_params: self.effect_params,
        }
    }
}

/// 番号を u32 にする。型変数とエフェクトの変数の数は、ソースの大きさの上限の定数倍に収まるので、
/// 溢れは起きない。万一溢れたときも panic せず、最後の番号に寄せる。
fn index_u32(len: usize) -> u32 {
    u32::try_from(len).unwrap_or(u32::MAX)
}

impl Solver {
    /// 空の状態。一つの本体の検査の始めに作る。
    pub fn new() -> Solver {
        Solver::default()
    }

    /// 新しい型変数。
    pub fn fresh_ty(&mut self) -> ITy {
        ITy::Var(self.fresh_ty_var())
    }

    /// 新しい型変数（union-find の要素）。決まっておらず、制約を持たない。
    pub fn fresh_ty_var(&mut self) -> TyVar {
        let id = index_u32(self.vars.len());
        self.vars.push(VarNode {
            parent: id,
            size: 1,
            binding: None,
            one_of: None,
            equality: None,
        });
        TyVar(id)
    }

    /// 新しいエフェクトの変数だけからなるエフェクト。
    pub fn fresh_effect(&mut self) -> IEffect {
        IEffect {
            fixed: EffectSet::empty(),
            var: Some(self.fresh_eff_var()),
        }
    }

    /// 新しいエフェクトの変数。集合は空から始め、`solve` の手順 3 で最小の集合を求める。
    pub fn fresh_eff_var(&mut self) -> EffInfer {
        let id = index_u32(self.effs.len());
        self.effs.push(EffState::default());
        EffInfer(id)
    }

    /// 型変数に集まりの制約を直接付ける（組み込みの関数の型パラメータの制約を移すときに使う）。
    pub fn constrain_one_of(&mut self, v: TyVar, set: TySet, reason: Reason) {
        let root = self.find(v);
        let attachable = match self.node(root) {
            Some(n) if n.binding.is_none() => match &n.one_of {
                Some((old, _)) => !old.intersect(set).0.is_empty(),
                None => true,
            },
            Some(_) | None => false,
        };
        if attachable {
            // 空でない共通部分になるので、その場で付けられる。
            self.attach_one_of(root, set, &reason);
        } else {
            // 既に決まった型変数や、共通部分が空になる場合は、診断を出すために solve で解く。
            self.pending.push(Constraint::OneOf {
                ty: ITy::Var(v),
                set,
                reason,
            });
        }
    }

    pub fn constrain_equality(&mut self, v: TyVar, reason: Reason) {
        let root = self.find(v);
        match self.node_mut(root) {
            Some(n) if n.binding.is_none() => {
                // 集まりの型はどれも等値の型なので、集まりの制約があれば付けなくてよい。
                if n.one_of.is_none() && n.equality.is_none() {
                    n.equality = Some(reason);
                }
            }
            Some(_) | None => self.pending.push(Constraint::Equality {
                ty: ITy::Var(v),
                reason,
            }),
        }
    }

    /// 制約をすべて解く。手順 1（Priority::Declared の流れ込む制約）、手順 2（残りの型の制約）、
    /// 手順 3（含まれる制約）の順。解けなかった制約の診断を返す。
    pub fn solve(&mut self, constraints: Vec<Constraint>, env: &SolveEnv<'_>) -> Vec<Diagnostic> {
        let mut run = Run::default();
        let pending = std::mem::take(&mut self.pending);
        // 制約に番号を振る。含まれる制約から元の制約を辿り、同じ誤りを二度報告しないために使う。
        let numbered = pending.into_iter().chain(constraints).enumerate();

        let mut declared = Vec::new();
        let mut normal = Vec::new();
        let mut given_effs = Vec::new();
        for (group, c) in numbered {
            if let Constraint::Equal {
                expected: ITy::Var(v),
                found,
                reason,
            } = &c
                && matches!(reason.kind, ReasonKind::Operands { op } if op == OpName::Bin(BinOp::Add))
            {
                run.add_operands.push((*v, copy_ty(found)));
            }
            match c {
                Constraint::EffSub { sub, sup, reason } => given_effs.push(EffSubItem {
                    sub,
                    sup,
                    reason,
                    origin: EffOrigin::Given,
                }),
                Constraint::Flow { ref reason, .. } if reason.priority == Priority::Declared => {
                    declared.push((group, c));
                }
                Constraint::Flow { .. }
                | Constraint::Equal { .. }
                | Constraint::OneOf { .. }
                | Constraint::Equality { .. } => normal.push((group, c)),
            }
        }

        // 手順 1 と 2（02-05「制約の解決」）。宣言と型注釈から生じた流れ込む制約を先に解き、
        // 宣言に合わない使い方の側を誤りとして報告する（ADR 0023）。同じ手順の中は受け取った順に解く。
        let mut deferred = Vec::new();
        for (group, c) in declared.into_iter().chain(normal) {
            self.solve_type_constraint(group, c, env, &mut run, &mut deferred);
        }
        self.retry_deferred(deferred, env, &mut run);

        // 手順 3。受け取った含まれる制約と、手順 1・2 が作った含まれる制約をすべて解く。
        let derived = std::mem::take(&mut self.derived);
        let items: Vec<EffSubItem> = given_effs.into_iter().chain(derived).collect();
        self.solve_effects(&items, env, &mut run);
        run.diags
    }

    /// 現在の単一化の状態で型変数を置き換えた型。
    pub fn zonk(&self, ty: &ITy) -> ITy {
        self.zonk_with(ty, false)
    }

    /// 型変数を置き換える。`shown` なら、診断に示すために、エフェクトの変数の現在の集合も確定した要素に移す。
    fn zonk_with(&self, ty: &ITy, shown: bool) -> ITy {
        match ty {
            ITy::Var(v) => {
                let root = self.find(*v);
                match self.binding(root) {
                    Some(b) => self.zonk_with(b, shown),
                    None => ITy::Var(root),
                }
            }
            ITy::Con(c, args) => ITy::Con(*c, self.zonk_tys(args, shown)),
            ITy::Fn(f) => self.zonk_fn(f, shown),
            ITy::Param(i) => ITy::Param(*i),
            ITy::Error => ITy::Error,
        }
    }

    fn zonk_tys(&self, tys: &[ITy], shown: bool) -> Vec<ITy> {
        let mut out = Vec::with_capacity(tys.len());
        for t in tys {
            out.push(self.zonk_with(t, shown));
        }
        out
    }

    fn zonk_fn(&self, f: &IFnTy, shown: bool) -> ITy {
        ITy::Fn(Box::new(IFnTy {
            params: self.zonk_tys(&f.params, shown),
            ret: self.zonk_with(&f.ret, shown),
            effect: self.zonk_effect(&f.effect, shown),
        }))
    }

    fn zonk_effect(&self, e: &IEffect, shown: bool) -> IEffect {
        if shown {
            IEffect {
                fixed: self.finalize_effect(e),
                var: None,
            }
        } else {
            e.clone()
        }
    }

    /// 型が誤りの型を含むか（置き換えた後で判定する）。
    pub fn contains_error(&self, ty: &ITy) -> bool {
        match ty {
            ITy::Var(v) => match self.binding(self.find(*v)) {
                Some(b) => self.contains_error(b),
                None => false,
            },
            ITy::Con(_, args) => self.any_error(args),
            ITy::Fn(f) => self.any_error(&f.params) || self.contains_error(&f.ret),
            ITy::Param(_) => false,
            ITy::Error => true,
        }
    }

    fn any_error(&self, tys: &[ITy]) -> bool {
        for t in tys {
            if self.contains_error(t) {
                return true;
            }
        }
        false
    }

    /// 表に書く型にする。制約を持たない決まっていない型変数は `Unit`、決まっていないエフェクトの変数は空集合。
    /// 誤りの型は `Unit` にする（誤りがあれば表は使われない）。
    pub fn finalize(&self, ty: &ITy) -> Ty {
        match ty {
            ITy::Var(v) => match self.binding(self.find(*v)) {
                Some(b) => self.finalize(b),
                None => Ty::unit(),
            },
            ITy::Con(c, args) => Ty::Con(*c, self.finalize_tys(args)),
            ITy::Fn(f) => self.finalize_fn(f),
            ITy::Param(i) => Ty::Param(*i),
            ITy::Error => Ty::unit(),
        }
    }

    fn finalize_tys(&self, tys: &[ITy]) -> Vec<Ty> {
        let mut out = Vec::with_capacity(tys.len());
        for t in tys {
            out.push(self.finalize(t));
        }
        out
    }

    fn finalize_fn(&self, f: &IFnTy) -> Ty {
        Ty::func(
            self.finalize_tys(&f.params),
            self.finalize(&f.ret),
            self.finalize_effect(&f.effect),
        )
    }

    /// 表に書くエフェクトにする。確定した要素と、変数の現在の集合の和集合（決まっていない変数は空集合）。
    pub fn finalize_effect(&self, e: &IEffect) -> EffectSet {
        match e.var.and_then(|v| self.eff(v)) {
            Some(state) => e.fixed.union(&state.set),
            None => e.fixed.clone(),
        }
    }

    /// 制約（集まり・等値）を持ち、決まらなかった型変数の制約の理由の位置（E0407 に使う。02-05「本体の後の検査」）。
    /// 誤りの型になった型変数は含めない。
    pub fn undetermined(&self) -> Vec<Reason> {
        let mut out = Vec::new();
        for (i, n) in self.vars.iter().enumerate() {
            let is_root = usize::try_from(n.parent).is_ok_and(|p| p == i);
            if !is_root || n.binding.is_some() {
                continue;
            }
            // 同じ型変数の理由は一つにする。集まりの制約を優先する。
            if let Some(r) = n.one_of.as_ref().map(|(_, r)| r).or(n.equality.as_ref()) {
                out.push(r.clone());
            }
        }
        out
    }

    // ---- union-find ----

    fn node(&self, v: TyVar) -> Option<&VarNode> {
        usize::try_from(v.0).ok().and_then(|i| self.vars.get(i))
    }

    fn node_mut(&mut self, v: TyVar) -> Option<&mut VarNode> {
        usize::try_from(v.0).ok().and_then(|i| self.vars.get_mut(i))
    }

    fn eff(&self, v: EffInfer) -> Option<&EffState> {
        usize::try_from(v.0).ok().and_then(|i| self.effs.get(i))
    }

    fn eff_mut(&mut self, v: EffInfer) -> Option<&mut EffState> {
        usize::try_from(v.0).ok().and_then(|i| self.effs.get_mut(i))
    }

    /// 代表元。組の大きさで束ねるので木の高さは要素の数の対数に収まり、経路の圧縮をしなくてよい
    /// （`zonk` などを `&self` のまま書ける）。
    fn find(&self, v: TyVar) -> TyVar {
        let mut cur = v;
        while let Some(n) = self.node(cur) {
            if n.parent == cur.0 {
                break;
            }
            cur = TyVar(n.parent);
        }
        cur
    }

    fn binding(&self, root: TyVar) -> Option<&ITy> {
        self.node(root).and_then(|n| n.binding.as_deref())
    }

    /// 最も外側の型変数を、決まった型で置き換える。決まっていなければ代表元の型変数を返す。
    fn shallow<'a>(&self, ty: &'a ITy) -> Shallow<'a> {
        let ITy::Var(v) = ty else {
            return Shallow::Given(ty);
        };
        let root = self.find(*v);
        match self.node(root).and_then(|n| n.binding.as_ref()) {
            // 決まった型は型変数でないので、一段だけ置き換えれば足りる。
            Some(b) => Shallow::Bound(Rc::clone(b)),
            None => Shallow::Unbound(ITy::Var(root)),
        }
    }

    /// 決まった型変数なら、その決まった型（`Rc` を共有する）。
    fn bound(&self, ty: &ITy) -> Option<Rc<ITy>> {
        let ITy::Var(v) = ty else {
            return None;
        };
        self.node(self.find(*v)).and_then(|n| n.binding.clone())
    }

    /// 型変数 `root` が型 `ty` の中に現れるか（出現検査）。
    fn occurs(&self, root: TyVar, ty: &ITy) -> bool {
        match ty {
            ITy::Var(v) => {
                let r = self.find(*v);
                if r == root {
                    return true;
                }
                match self.binding(r) {
                    Some(b) => self.occurs(root, b),
                    None => false,
                }
            }
            ITy::Con(_, args) => self.occurs_any(root, args),
            ITy::Fn(f) => self.occurs_any(root, &f.params) || self.occurs(root, &f.ret),
            ITy::Param(_) | ITy::Error => false,
        }
    }

    fn occurs_any(&self, root: TyVar, tys: &[ITy]) -> bool {
        for t in tys {
            if self.occurs(root, t) {
                return true;
            }
        }
        false
    }

    // ---- 単一化 ----

    /// 等しい(expected, found) を単一化する（02-05「制約の解決」の「等しい」）。
    /// 型の入れ子を辿る経路（名前の型どうし、関数の型どうし）だけをここに置き、
    /// そのほかの場合は `unify_leaf` に分けて、再帰の 1 段あたりの枠を小さく保つ。
    fn unify(
        &mut self,
        expected: &ITy,
        found: &ITy,
        origin: &Origin<'_>,
        env: &SolveEnv<'_>,
    ) -> Result<(), Box<Failure>> {
        // `Shallow` より小さい `Option<Rc<ITy>>` で決まった型を受け取り、枠を小さく保つ。
        let eb = self.bound(expected);
        let fb = self.bound(found);
        let e = eb.as_deref().unwrap_or(expected);
        let f = fb.as_deref().unwrap_or(found);
        match (e, f) {
            // 型引数の対ごとの単一化を、別の関数に分けずにここで回す（1 段を一つの枠にする）。
            (ITy::Con(c1, args1), ITy::Con(c2, args2)) if c1 == c2 => {
                if args1.len() != args2.len() {
                    return Err(mismatch());
                }
                let mut i = 0;
                while let (Some(x), Some(y)) = (args1.get(i), args2.get(i)) {
                    self.unify(x, y, origin, env)?;
                    i = i.saturating_add(1);
                }
                Ok(())
            }
            (ITy::Fn(f1), ITy::Fn(f2)) => self.unify_fns(f1, f2, origin, env),
            (x, y) => self.unify_leaf(x, y, env),
        }
    }

    /// 型の入れ子を辿らない単一化の場合（誤りの型、型変数、型パラメータ、形の違う型）。
    /// 型変数は決まっていないもの（代表元とは限らない）。
    fn unify_leaf(&mut self, e: &ITy, f: &ITy, env: &SolveEnv<'_>) -> Result<(), Box<Failure>> {
        match (e, f) {
            // 誤りの型はどの型とも等しい（ADR 0024）。相手の型変数も誤りの型にして、派生する誤りを抑える。
            (ITy::Error, other) | (other, ITy::Error) => {
                if let ITy::Var(v) = other {
                    self.set_error(*v);
                }
                Ok(())
            }
            (ITy::Var(a), ITy::Var(b)) => self.union_vars(self.find(*a), self.find(*b)),
            (ITy::Var(a), t) | (t, ITy::Var(a)) => self.bind_var(self.find(*a), t, env),
            // 型パラメータは同じ型パラメータとだけ等しい（01-06「型」）。
            (ITy::Param(i), ITy::Param(j)) if i == j => Ok(()),
            (
                ITy::Con(..) | ITy::Fn(_) | ITy::Param(_),
                ITy::Con(..) | ITy::Fn(_) | ITy::Param(_),
            ) => Err(mismatch()),
        }
    }

    /// 型の並びを対ごとに単一化する。個数が違えば失敗する。
    fn unify_tys(
        &mut self,
        expected: &[ITy],
        found: &[ITy],
        origin: &Origin<'_>,
        env: &SolveEnv<'_>,
    ) -> Result<(), Box<Failure>> {
        if expected.len() != found.len() {
            return Err(mismatch());
        }
        let mut i = 0;
        while let (Some(x), Some(y)) = (expected.get(i), found.get(i)) {
            self.unify(x, y, origin, env)?;
            i = i.saturating_add(1);
        }
        Ok(())
    }

    fn unify_fns(
        &mut self,
        f1: &IFnTy,
        f2: &IFnTy,
        origin: &Origin<'_>,
        env: &SolveEnv<'_>,
    ) -> Result<(), Box<Failure>> {
        self.unify_tys(&f1.params, &f2.params, origin, env)?;
        self.unify(&f1.ret, &f2.ret, origin, env)?;
        // 関数の型が等しいとき、エフェクトは両方向に含まれる（02-05「制約の解決」の「等しい」）。
        self.push_derived(&f2.effect, &f1.effect, origin);
        self.push_derived(&f1.effect, &f2.effect, origin);
        Ok(())
    }

    /// 決まっていない型変数 `root` を、型変数でない型 `ty` に決める。
    /// 制約を持つ型変数は、決める前に制約を判定し、満たさなければ決めずに失敗を返す
    /// （失敗した制約の型変数は `report` が誤りの型にする）。
    fn bind_var(&mut self, root: TyVar, ty: &ITy, env: &SolveEnv<'_>) -> Result<(), Box<Failure>> {
        if self.occurs(root, ty) {
            return Err(Box::new(Failure::Occurs));
        }
        let (one_of, equality) = match self.node(root) {
            Some(n) => (n.one_of.clone(), n.equality.clone()),
            None => (None, None),
        };
        if let Some((set, reason)) = one_of {
            self.check_one_of(ty, set, &reason, Some(root))?;
        }
        if let Some(reason) = equality {
            self.check_equality(ty, &reason, env)?;
        }
        let bound = Rc::new(copy_ty(ty));
        if let Some(n) = self.node_mut(root) {
            n.binding = Some(bound);
            n.one_of = None;
            n.equality = None;
        }
        Ok(())
    }

    /// 決まっていない二つの型変数を束ねる。制約は合わせる（01-06「演算子の型付け」）。
    fn union_vars(&mut self, a: TyVar, b: TyVar) -> Result<(), Box<Failure>> {
        if a == b {
            return Ok(());
        }
        let (Some(na), Some(nb)) = (self.node(a).cloned(), self.node(b).cloned()) else {
            return Ok(());
        };
        let one_of = match (na.one_of, nb.one_of) {
            (Some((sa, ra)), Some((sb, rb))) => {
                let inter = sa.intersect(sb);
                if inter.0.is_empty() {
                    return Err(Box::new(Failure::OneOf {
                        set: sa,
                        ty: ITy::Var(b),
                        reason: ra,
                        var: Some(a),
                    }));
                }
                // 共通部分と同じ集まりを持っていた側の理由を残す。
                Some(if inter == sa { (sa, ra) } else { (inter, rb) })
            }
            (x, y) => x.or(y),
        };
        let equality = na.equality.or(nb.equality);
        let (root, child) = if na.size >= nb.size { (a, b) } else { (b, a) };
        let size = na.size.saturating_add(nb.size);
        if let Some(n) = self.node_mut(child) {
            n.parent = root.0;
            n.one_of = None;
            n.equality = None;
        }
        if let Some(n) = self.node_mut(root) {
            n.size = size;
            n.one_of = one_of;
            n.equality = equality;
        }
        Ok(())
    }

    /// 型変数を誤りの型にする（02-05「誤りの報告と検査の継続」）。
    fn set_error(&mut self, v: TyVar) {
        let root = self.find(v);
        if let Some(n) = self.node_mut(root) {
            n.binding = Some(Rc::new(ITy::Error));
            n.one_of = None;
            n.equality = None;
        }
    }

    /// 解けなかった制約の辺に現れる型変数を、すべて誤りの型にする。既に決まった型変数も、決まった型の中の
    /// 型変数とともに誤りの型にする。そうしないと、同じ型変数を使う後の制約が同じ原因の誤りを繰り返す
    /// （`Equal(α, Int)`、`Equal(α, String)`、`Equal(α, Bool)` の三つ目）。
    fn mark_error(&mut self, ty: &ITy, seen: &mut HashSet<TyVar>) {
        match ty {
            ITy::Var(v) => {
                let root = self.find(*v);
                if !seen.insert(root) {
                    return;
                }
                if let Some(b) = self.node(root).and_then(|n| n.binding.clone()) {
                    self.mark_error(&b, seen);
                }
                self.set_error(root);
            }
            ITy::Con(_, args) => self.mark_error_all(args, seen),
            ITy::Fn(f) => {
                self.mark_error_all(&f.params, seen);
                self.mark_error(&f.ret, seen);
            }
            ITy::Param(_) | ITy::Error => {}
        }
    }

    fn mark_error_all(&mut self, tys: &[ITy], seen: &mut HashSet<TyVar>) {
        for t in tys {
            self.mark_error(t, seen);
        }
    }

    fn push_derived(&mut self, sub: &IEffect, sup: &IEffect, origin: &Origin<'_>) {
        self.derived.push(EffSubItem {
            sub: sub.clone(),
            sup: sup.clone(),
            reason: origin.reason.clone(),
            origin: EffOrigin::Derived {
                group: origin.group,
                from: Rc::clone(origin.from),
                to: Rc::clone(origin.to),
            },
        });
    }

    // ---- 流れ込む制約 ----

    /// 流れ込む(from, to) を解く（02-05「制約の解決」の「流れ込む(A, B)」）。
    /// 両辺とも型変数なら、後回しにするために `Ok(false)` を返す。
    fn flow(
        &mut self,
        from: &ITy,
        to: &ITy,
        origin: &Origin<'_>,
        env: &SolveEnv<'_>,
    ) -> Result<bool, Box<Failure>> {
        let a = self.shallow(from);
        let b = self.shallow(to);
        match (a.get(), b.get()) {
            (ITy::Error, _) | (_, ITy::Error) => {
                self.unify(b.get(), a.get(), origin, env)?;
                Ok(true)
            }
            (ITy::Fn(fa), ITy::Fn(fb)) => {
                self.unify_tys(&fb.params, &fa.params, origin, env)?;
                self.unify(&fb.ret, &fa.ret, origin, env)?;
                // エフェクトの包含は最も外側の関数の型にだけ働く（01-06「エフェクトの包含」）。
                self.push_derived(&fa.effect, &fb.effect, origin);
                Ok(true)
            }
            (ITy::Fn(fa), ITy::Var(vb)) => {
                let rho = self.fresh_effect();
                self.bind_var(*vb, &shaped_fn(fa, &rho), env)?;
                self.push_derived(&fa.effect, &rho, origin);
                Ok(true)
            }
            (ITy::Var(va), ITy::Fn(fb)) => {
                let rho = self.fresh_effect();
                self.bind_var(*va, &shaped_fn(fb, &rho), env)?;
                self.push_derived(&rho, &fb.effect, origin);
                Ok(true)
            }
            (ITy::Var(_), ITy::Var(_)) => Ok(false),
            (ITy::Con(..) | ITy::Param(_) | ITy::Var(_) | ITy::Fn(_), _) => {
                self.unify(b.get(), a.get(), origin, env)?;
                Ok(true)
            }
        }
    }

    // ---- 集まりと等値 ----

    /// 集まり(ty, set) を判定する（01-06「演算子の型付け」）。決まっていない型変数なら制約を付ける。
    /// `var` は、型変数を決めるときの判定なら、その型変数（制約を持っていた側）。
    fn check_one_of(
        &mut self,
        ty: &ITy,
        set: TySet,
        reason: &Reason,
        var: Option<TyVar>,
    ) -> Result<(), Box<Failure>> {
        if self.contains_error(ty) {
            return Ok(());
        }
        let mut var = var;
        let ok = match self.shallow(ty).get() {
            ITy::Var(root) => {
                var = var.or(Some(*root));
                self.attach_one_of(*root, set, reason)
            }
            ITy::Con(c, _) => set.contains(*c),
            // 関数の型と型パラメータは満たさない。利用者の関数の型パラメータに演算子を使えない。
            ITy::Fn(_) | ITy::Param(_) => false,
            ITy::Error => true,
        };
        if ok {
            Ok(())
        } else {
            // 集まり(ty) の ty が型変数の決まったものなら、その型変数が制約を持っていた側である。
            let var = var.or(match ty {
                ITy::Var(v) => Some(self.find(*v)),
                ITy::Con(..) | ITy::Fn(_) | ITy::Param(_) | ITy::Error => None,
            });
            Err(Box::new(Failure::OneOf {
                set,
                ty: copy_ty(ty),
                reason: reason.clone(),
                var,
            }))
        }
    }

    /// 決まっていない型変数に集まりの制約を付ける。既に持っていれば共通部分にし、空なら false を返す。
    fn attach_one_of(&mut self, root: TyVar, set: TySet, reason: &Reason) -> bool {
        let Some(n) = self.node_mut(root) else {
            return true;
        };
        match &n.one_of {
            Some((old, _)) => {
                let inter = old.intersect(set);
                if inter.0.is_empty() {
                    return false;
                }
                if inter != *old {
                    n.one_of = Some((inter, reason.clone()));
                }
            }
            None => n.one_of = Some((set, reason.clone())),
        }
        // 集まりの型はどれも等値の型なので、等値の制約は集まりの制約に含まれる。
        n.equality = None;
        true
    }

    /// 等値(ty) を判定する（01-06「等値の型」）。型変数には制約を移す。
    fn check_equality(
        &mut self,
        ty: &ITy,
        reason: &Reason,
        env: &SolveEnv<'_>,
    ) -> Result<(), Box<Failure>> {
        if self.contains_error(ty) || self.equality_walk(ty, reason, env) {
            Ok(())
        } else {
            Err(Box::new(Failure::Equality {
                ty: copy_ty(ty),
                reason: reason.clone(),
            }))
        }
    }

    /// 型を辿って等値の型かを判定し、途中の決まっていない型変数に等値の制約を付ける。
    fn equality_walk(&mut self, ty: &ITy, reason: &Reason, env: &SolveEnv<'_>) -> bool {
        let t = self.shallow(ty);
        match t.get() {
            ITy::Var(root) => {
                self.attach_equality(*root, reason);
                true
            }
            ITy::Error => true,
            ITy::Fn(_) | ITy::Param(_) => false,
            ITy::Con(c, args) => match c {
                // 中身を見せない prelude の型は等値の型でない（ADR 0048）。
                TyCon::IoError => false,
                TyCon::Int
                | TyCon::Float
                | TyCon::String
                | TyCon::Char
                | TyCon::Bool
                | TyCon::Unit => true,
                TyCon::List => self.equality_all(args, None, reason, env),
                TyCon::Option | TyCon::Result | TyCon::Adt(_) => match env.adts.get(*c) {
                    // 宣言の要約で判定し、依存する位置の型引数に制約を移す（ADR 0082）。
                    Some(def) => {
                        !def.eq_summary.always
                            && self.equality_all(
                                args,
                                Some(&def.eq_summary.depends_on),
                                reason,
                                env,
                            )
                    }
                    // 表にない型は、すべての型引数に依存するものとして扱う。
                    None => self.equality_all(args, None, reason, env),
                },
            },
        }
    }

    /// 決まっていない型変数に等値の制約を付ける。集まりの制約があれば付けなくてよい（集まりの型はどれも等値の型）。
    fn attach_equality(&mut self, root: TyVar, reason: &Reason) {
        if let Some(n) = self.node_mut(root)
            && n.one_of.is_none()
            && n.equality.is_none()
        {
            n.equality = Some(reason.clone());
        }
    }

    /// 型引数のうち `positions` の位置（`None` ならすべて）が等値の型かを判定する。
    fn equality_all(
        &mut self,
        args: &[ITy],
        positions: Option<&[u32]>,
        reason: &Reason,
        env: &SolveEnv<'_>,
    ) -> bool {
        let mut i: u32 = 0;
        for a in args {
            let depends = positions.is_none_or(|ps| ps.contains(&i));
            if depends && !self.equality_walk(a, reason, env) {
                return false;
            }
            i = i.saturating_add(1);
        }
        true
    }

    // ---- 型の制約を解く手順 ----

    fn solve_type_constraint(
        &mut self,
        group: usize,
        c: Constraint,
        env: &SolveEnv<'_>,
        run: &mut Run,
        deferred: &mut Vec<Deferred>,
    ) {
        match c {
            Constraint::Equal {
                expected,
                found,
                reason,
            } => {
                // 含まれる制約が元の制約の辺を覚えるので、辺を `Rc` にして複製せずに共有する。
                let (expected, found) = (Rc::new(expected), Rc::new(found));
                let origin = Origin {
                    reason: &reason,
                    group,
                    from: &found,
                    to: &expected,
                };
                if let Err(f) = self.unify(&expected, &found, &origin, env) {
                    let site = Site::Pair {
                        expected: &expected,
                        found: &found,
                    };
                    self.report(f, &site, &reason, group, env, run);
                }
            }
            Constraint::Flow { from, to, reason } => {
                let (from, to) = (Rc::new(from), Rc::new(to));
                let origin = Origin {
                    reason: &reason,
                    group,
                    from: &from,
                    to: &to,
                };
                match self.flow(&from, &to, &origin, env) {
                    Ok(true) => {}
                    Ok(false) => deferred.push(Deferred {
                        group,
                        from,
                        to,
                        reason,
                    }),
                    Err(f) => {
                        let site = Site::Pair {
                            expected: &to,
                            found: &from,
                        };
                        self.report(f, &site, &reason, group, env, run);
                    }
                }
            }
            Constraint::OneOf { ty, set, reason } => {
                if let Err(f) = self.check_one_of(&ty, set, &reason, None) {
                    self.report(f, &Site::Single(&ty), &reason, group, env, run);
                }
            }
            Constraint::Equality { ty, reason } => {
                if let Err(f) = self.check_equality(&ty, &reason, env) {
                    self.report(f, &Site::Single(&ty), &reason, group, env, run);
                }
            }
            // `solve` が含まれる制約を先に分けるので、ここには来ない。来ても手順 3 で解く。
            Constraint::EffSub { sub, sup, reason } => self.derived.push(EffSubItem {
                sub,
                sup,
                reason,
                origin: EffOrigin::Given,
            }),
        }
    }

    /// 後回しにした流れ込む制約を解き直す（02-05「制約の解決」）。一つでも片付けば残りを解き直し、
    /// 片付くものがなくなったら、残りを等しいとして単一化する。
    fn retry_deferred(&mut self, mut deferred: Vec<Deferred>, env: &SolveEnv<'_>, run: &mut Run) {
        while !deferred.is_empty() {
            let mut progressed = false;
            let mut remain = Vec::new();
            for d in deferred {
                let origin = Origin {
                    reason: &d.reason,
                    group: d.group,
                    from: &d.from,
                    to: &d.to,
                };
                match self.flow(&d.from, &d.to, &origin, env) {
                    Ok(true) => progressed = true,
                    Ok(false) => remain.push(d),
                    Err(f) => {
                        progressed = true;
                        let site = Site::Pair {
                            expected: &d.to,
                            found: &d.from,
                        };
                        self.report(f, &site, &d.reason, d.group, env, run);
                    }
                }
            }
            deferred = remain;
            if !progressed {
                break;
            }
        }
        for d in deferred {
            let origin = Origin {
                reason: &d.reason,
                group: d.group,
                from: &d.from,
                to: &d.to,
            };
            if let Err(f) = self.unify(&d.to, &d.from, &origin, env) {
                let site = Site::Pair {
                    expected: &d.to,
                    found: &d.from,
                };
                self.report(f, &site, &d.reason, d.group, env, run);
            }
        }
    }

    /// 解けなかった制約を報告し、辺の型変数を誤りの型にする（02-05「誤りの報告と検査の継続」）。
    /// 辺が誤りの型を含むときは、診断を出さない。
    fn report(
        &mut self,
        failure: Box<Failure>,
        site: &Site<'_>,
        reason: &Reason,
        group: usize,
        env: &SolveEnv<'_>,
        run: &mut Run,
    ) {
        run.failed.insert(group);
        let has_error = site.types().iter().any(|t| self.contains_error(t))
            || match failure.as_ref() {
                Failure::OneOf { ty, .. } | Failure::Equality { ty, .. } => self.contains_error(ty),
                Failure::Mismatch | Failure::Occurs => false,
            };
        if !has_error
            && let Some(d) = self.failure_diag(&failure, site, reason, env, &run.add_operands)
        {
            run.diags.push(d);
        }
        let mut seen = HashSet::new();
        for t in site.types() {
            self.mark_error(t, &mut seen);
        }
    }

    fn failure_diag(
        &self,
        failure: &Failure,
        site: &Site<'_>,
        reason: &Reason,
        env: &SolveEnv<'_>,
        add_operands: &[(TyVar, ITy)],
    ) -> Option<Diagnostic> {
        let names = env.names();
        match failure {
            Failure::Mismatch => match site {
                Site::Pair { expected, found } => Some(self.mismatch_diag(
                    &self.zonk_shown(expected),
                    &self.zonk_shown(found),
                    reason,
                    &names,
                )),
                Site::Single(_) => None,
            },
            Failure::Occurs => Some(
                DiagBuilder::new(DiagCode::E0404)
                    .primary(reason.span)
                    .build(),
            ),
            Failure::OneOf {
                set,
                ty,
                reason: var_reason,
                var,
            } => {
                let ty = self.zonk_shown(ty);
                let mut b = DiagBuilder::new(DiagCode::E0405)
                    .arg("op", op_text(var_reason))
                    .arg("ty", ty.show(&names))
                    .arg("allowed", allowed_text(*set, &names))
                    .primary(var_reason.span)
                    .note("allowed");
                if is_add(&var_reason.kind) {
                    // 「他方」は集まりの制約を満たさなかった型である。`String` の側は、解けなかった制約の辺か、
                    // 同じ `+` の演算のオペランド（制約を持っていた型変数 α との `Equal(α, オペランド)`）から探す。
                    let is_string = |t: &ITy| is_con(&self.zonk(t), TyCon::String);
                    let same_op = |v: &TyVar| var.is_some_and(|root| self.find(*v) == root);
                    let string_side = site.types().into_iter().any(is_string)
                        || add_operands.iter().any(|(e, f)| same_op(e) && is_string(f));
                    if string_side {
                        b = add_to_string_help(b, &ty);
                    }
                }
                Some(b.build())
            }
            Failure::Equality {
                ty,
                reason: var_reason,
            } => Some(
                DiagBuilder::new(DiagCode::E0406)
                    .arg("op", op_text(var_reason))
                    .arg("ty", self.zonk_shown(ty).show(&names))
                    .primary(var_reason.span)
                    .note("why")
                    .build(),
            ),
        }
    }

    /// 型の不一致の診断（E0401。呼び出しなら E0402・E0403、式文なら E0416）。
    /// `expected` と `found` は、診断に示すために置き換えを済ませた型。
    fn mismatch_diag(
        &self,
        expected: &ITy,
        found: &ITy,
        reason: &Reason,
        names: &TyNames<'_>,
    ) -> Diagnostic {
        if matches!(reason.kind, ReasonKind::ExprStmt) {
            return DiagBuilder::new(DiagCode::E0416)
                .arg("found", found.show(names))
                .primary(reason.span)
                .help("discard")
                .build();
        }
        if matches!(reason.kind, ReasonKind::Call) {
            match (expected, found) {
                (ITy::Fn(fe), ITy::Fn(ff)) if fe.params.len() != ff.params.len() => {
                    let mut b = DiagBuilder::new(DiagCode::E0402)
                        .arg("expected", fe.params.len().to_string())
                        .arg("found", ff.params.len().to_string())
                        .primary(reason.span);
                    if let Some(rel) = reason.related {
                        b = b.secondary(rel, "declared");
                    }
                    return b.build();
                }
                // 呼ばれる式の型が関数の型でも型変数でもない。
                (ITy::Con(..) | ITy::Param(_), _) => {
                    return DiagBuilder::new(DiagCode::E0403)
                        .arg("found", expected.show(names))
                        .primary(reason.span)
                        .build();
                }
                (ITy::Fn(_) | ITy::Var(_) | ITy::Error, _) => {}
            }
        }
        let mut b = DiagBuilder::new(DiagCode::E0401)
            .arg("expected", expected.show(names))
            .arg("found", found.show(names))
            .primary(reason.span);
        if let Some(rel) = reason.related {
            b = b.secondary(rel, "declared");
        }
        b = add_reason_note(b, &reason.kind);
        if let Some(digits) = &reason.int_literal
            && is_con(expected, TyCon::Float)
            && is_con(found, TyCon::Int)
        {
            b = b.arg("literal", digits.clone()).help("float_literal");
        }
        if let ReasonKind::Operands { op } = reason.kind
            && op == OpName::Bin(BinOp::Add)
        {
            // 一方が `String` で他方が `String` でないとき、他方を文字列に変換する修正案を示す。
            if is_con(expected, TyCon::String) {
                b = add_to_string_help(b, found);
            } else if is_con(found, TyCon::String) {
                b = add_to_string_help(b, expected);
            }
        }
        b.build()
    }

    /// 診断に示すための型。型変数を置き換え、エフェクトの変数の現在の集合を確定した要素に移す。
    fn zonk_shown(&self, ty: &ITy) -> ITy {
        self.zonk_with(ty, true)
    }

    // ---- エフェクトの制約 ----

    /// エフェクト `x` の現在の要素と、その由来の位置。確定した要素の由来は `span`（その制約の位置）、
    /// 変数から来た要素の由来は、変数に加えたときに記録した位置である。
    fn current_elems(&self, x: &IEffect, span: Span) -> Vec<(Elem, Span)> {
        let mut out: Vec<(Elem, Span)> =
            elems_of(&x.fixed).into_iter().map(|e| (e, span)).collect();
        if let Some(state) = x.var.and_then(|v| self.eff(v)) {
            for (e, origin) in &state.origins {
                if !e.is_in(&x.fixed) {
                    out.push((*e, *origin));
                }
            }
        }
        out
    }

    /// 含まれる制約を解く（02-05「制約の解決」のエフェクトの手順 1〜3）。
    fn solve_effects(&mut self, items: &[EffSubItem], env: &SolveEnv<'_>, run: &mut Run) {
        // 手順 2: 右辺が変数を持つ制約について、右辺の確定した要素で満たされない要素を変数に加える。
        // どの解でも含まれなければならない要素だけを加えるので、得られる集合は最小である。
        loop {
            let mut changed = false;
            for item in items {
                let Some(w) = item.sup.var else {
                    continue;
                };
                for (e, origin) in self.current_elems(&item.sub, item.reason.span) {
                    if e.is_in(&item.sup.fixed) {
                        continue;
                    }
                    if let Some(state) = self.eff_mut(w)
                        && !e.is_in(&state.set)
                    {
                        e.insert_into(&mut state.set);
                        state.origins.push((e, origin));
                        changed = true;
                    }
                }
            }
            if !changed {
                break;
            }
        }

        // 手順 3: 右辺が変数を持たない制約を検査する。
        let names = env.names();
        for item in items {
            if item.sup.var.is_some() {
                continue;
            }
            let leaked: Vec<(Elem, Span)> = self
                .current_elems(&item.sub, item.reason.span)
                .into_iter()
                .filter(|(e, _)| !e.is_in(&item.sup.fixed))
                .collect();
            if leaked.is_empty() {
                continue;
            }
            match &item.origin {
                EffOrigin::Derived { group, from, to } => {
                    // 流れ込む制約・単一化から作った制約は、元の制約の型の不一致として一度だけ報告する。
                    if !run.failed.insert(*group) {
                        continue;
                    }
                    if !self.contains_error(from) && !self.contains_error(to) {
                        let d = self.mismatch_diag(
                            &self.zonk_shown(to),
                            &self.zonk_shown(from),
                            &item.reason,
                            &names,
                        );
                        run.diags.push(d);
                    }
                    let mut seen = HashSet::new();
                    self.mark_error(from, &mut seen);
                    self.mark_error(to, &mut seen);
                }
                EffOrigin::Given => {
                    for (e, origin) in leaked {
                        run.diags.push(effect_diag(e, origin, &item.reason, &names));
                    }
                }
            }
        }
    }
}

/// 宣言に含まれないエフェクトの診断（E0501・E0502）。漏れた要素ごとに一つ出す。
fn effect_diag(e: Elem, origin: Span, reason: &Reason, names: &TyNames<'_>) -> Diagnostic {
    let effect = names.show_effects(&e.as_set());
    let lambda = matches!(reason.kind, ReasonKind::LambdaUses);
    // `FnUses` のほか、T15 が付けないはずの理由でも、診断を落とさないために E0501 とする。
    let code = if lambda {
        DiagCode::E0502
    } else {
        DiagCode::E0501
    };
    let mut b = DiagBuilder::new(code).arg("effect", effect).primary(origin);
    if let Some(rel) = reason.related {
        b = b.secondary(rel, "declared");
    }
    if !lambda {
        b = b.help("add_uses");
    }
    b.build()
}

/// 理由の種類から選ぶ E0401 の注記（T14 の作業の文書の表）。
fn add_reason_note(b: DiagBuilder, kind: &ReasonKind) -> DiagBuilder {
    match kind {
        ReasonKind::CallArg { index } => b.arg("index", index.to_string()).note("because_call_arg"),
        ReasonKind::Call => b.note("because_call"),
        ReasonKind::IfCondition => b.note("because_condition"),
        ReasonKind::IfBranches => b.note("because_if_branches"),
        ReasonKind::IfNoElse => b.note("because_if_no_else"),
        ReasonKind::MatchArms => b.note("because_match_arms"),
        ReasonKind::Pattern => b.note("because_pattern"),
        ReasonKind::ListElement => b.note("because_list"),
        ReasonKind::LetAnnotation => b.note("because_let_annotation"),
        ReasonKind::LambdaReturn => b.note("because_lambda_return"),
        ReasonKind::FnBody => b.note("because_fn_body"),
        ReasonKind::Operands { op } => b.arg("op", op.symbol()).note("because_operands"),
        ReasonKind::Logic { op } => b.arg("op", op.symbol()).note("because_logic"),
        // `%` のオペランドを `Int` と等しくする制約（T15）。
        ReasonKind::Operator { op } => b.arg("op", op.symbol()).note("because_int_operands"),
        ReasonKind::LambdaUses
        | ReasonKind::FnUses
        | ReasonKind::ExprStmt
        | ReasonKind::CallEffect
        | ReasonKind::BuiltinParam { .. } => b,
    }
}

fn is_add(kind: &ReasonKind) -> bool {
    matches!(kind, ReasonKind::Operator { op } if *op == OpName::Bin(BinOp::Add))
}

/// `+` の修正案。`other` は `String` でない側の型。誤りの型と `String` には付けない。
fn add_to_string_help(b: DiagBuilder, other: &ITy) -> DiagBuilder {
    let function = match other {
        ITy::Con(TyCon::Int, _) => Some(text::INT_TO_STRING),
        ITy::Con(TyCon::Float, _) => Some(text::FLOAT_TO_STRING),
        ITy::Con(TyCon::Char, _) => Some(text::CHAR_TO_STRING),
        ITy::Con(TyCon::String, _) | ITy::Error => return b,
        ITy::Con(..) | ITy::Fn(_) | ITy::Param(_) | ITy::Var(_) => None,
    };
    match function {
        Some(f) => b.arg("function", f).help("to_string"),
        None => b.help("to_string_any"),
    }
}

fn is_con(ty: &ITy, c: TyCon) -> bool {
    matches!(ty, ITy::Con(d, _) if *d == c)
}

/// E0405・E0406 の `{op}`。演算子の記号か、組み込みの関数の修飾した名前。
fn op_text(reason: &Reason) -> String {
    match &reason.kind {
        ReasonKind::Operator { op } | ReasonKind::Operands { op } | ReasonKind::Logic { op } => {
            op.symbol().to_string()
        }
        ReasonKind::BuiltinParam { name } => name.clone(),
        ReasonKind::CallArg { .. }
        | ReasonKind::Call
        | ReasonKind::IfCondition
        | ReasonKind::IfBranches
        | ReasonKind::IfNoElse
        | ReasonKind::MatchArms
        | ReasonKind::Pattern
        | ReasonKind::ListElement
        | ReasonKind::LetAnnotation
        | ReasonKind::LambdaReturn
        | ReasonKind::LambdaUses
        | ReasonKind::FnBody
        | ReasonKind::FnUses
        | ReasonKind::ExprStmt
        | ReasonKind::CallEffect => String::new(),
    }
}

/// 集まりの型を「`Int`, `Float`, and `String`」「`Int` and `Float`」の形に並べる。
fn allowed_text(set: TySet, names: &TyNames<'_>) -> String {
    let items: Vec<String> = set
        .0
        .iter()
        .map(|c| format!("`{}`", names.con_name(*c)))
        .collect();
    match items.as_slice() {
        [] => String::new(),
        [one] => one.clone(),
        [a, b] => format!("{a} {} {b}", text::AND),
        [init @ .., last] => format!("{}, {} {last}", init.join(", "), text::AND),
    }
}

// テストの失敗は panic で表す（07-03 は、テストのコードでこれらの lint を許してよいとした）。
#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
mod tests {
    use super::*;
    use crate::base::{BindingId, BytePos, FileId};
    use crate::types::{AdtDef, EqSummary};

    fn sp(n: u32) -> Span {
        Span {
            file: FileId(0),
            start: BytePos(n),
            end: BytePos(n + 1),
        }
    }

    fn reason_at(kind: ReasonKind, n: u32) -> Reason {
        Reason {
            span: sp(n),
            kind,
            related: None,
            priority: Priority::Normal,
            int_literal: None,
        }
    }

    fn reason(kind: ReasonKind) -> Reason {
        reason_at(kind, 0)
    }

    fn con(c: TyCon) -> ITy {
        ITy::Con(c, vec![])
    }

    fn int() -> ITy {
        con(TyCon::Int)
    }

    fn string() -> ITy {
        con(TyCon::String)
    }

    fn unit() -> ITy {
        con(TyCon::Unit)
    }

    fn list(t: ITy) -> ITy {
        ITy::Con(TyCon::List, vec![t])
    }

    fn func(params: Vec<ITy>, ret: ITy, effect: IEffect) -> ITy {
        ITy::Fn(Box::new(IFnTy {
            params,
            ret,
            effect,
        }))
    }

    fn pure() -> IEffect {
        IEffect::default()
    }

    fn fixed(set: EffectSet) -> IEffect {
        IEffect {
            fixed: set,
            var: None,
        }
    }

    fn io() -> IEffect {
        fixed(EffectSet::io())
    }

    fn equal(expected: ITy, found: ITy, kind: ReasonKind) -> Constraint {
        Constraint::Equal {
            expected,
            found,
            reason: reason(kind),
        }
    }

    fn flow(from: ITy, to: ITy, kind: ReasonKind) -> Constraint {
        Constraint::Flow {
            from,
            to,
            reason: reason(kind),
        }
    }

    fn one_of(ty: ITy, set: TySet, op: BinOp) -> Constraint {
        Constraint::OneOf {
            ty,
            set,
            reason: reason(ReasonKind::Operator {
                op: OpName::Bin(op),
            }),
        }
    }

    fn equality(ty: ITy) -> Constraint {
        Constraint::Equality {
            ty,
            reason: reason(ReasonKind::Operator {
                op: OpName::Bin(BinOp::Eq),
            }),
        }
    }

    fn eff_sub(sub: IEffect, sup: IEffect, r: Reason) -> Constraint {
        Constraint::EffSub {
            sub,
            sup,
            reason: r,
        }
    }

    const PLAIN: ReasonKind = ReasonKind::LetAnnotation;

    fn solve_with(
        s: &mut Solver,
        cs: Vec<Constraint>,
        adts: &AdtTable,
        eps: &[String],
    ) -> Vec<Diagnostic> {
        let env = SolveEnv {
            adts,
            type_params: &[],
            effect_params: eps,
        };
        s.solve(cs, &env)
    }

    fn solve(s: &mut Solver, cs: Vec<Constraint>) -> Vec<Diagnostic> {
        solve_with(s, cs, &AdtTable::default(), &[])
    }

    fn ids(ds: &[Diagnostic]) -> Vec<&'static str> {
        ds.iter().map(|d| d.code.unwrap().info().id).collect()
    }

    fn only(ds: &[Diagnostic], code: DiagCode) -> &Diagnostic {
        assert_eq!(ids(ds), vec![code.info().id], "{ds:#?}");
        &ds[0]
    }

    fn label(d: &Diagnostic) -> &str {
        &d.primary.as_ref().unwrap().text
    }

    /// 診断のコードだけを確かめる場合（02-05「制約の解決」、01-06 の型の等しさ・演算子・等値の型）。
    #[test]
    fn diagnostic_codes_of_constraint_sets() {
        type Build = fn(&mut Solver) -> Vec<Constraint>;
        let cases: &[(&str, Build, &[&str])] = &[
            (
                "occurs check",
                |s| {
                    let a = s.fresh_ty();
                    vec![equal(a.clone(), func(vec![a], int(), pure()), PLAIN)]
                },
                &["E0404"],
            ),
            (
                "type parameter is rigid",
                |_| vec![equal(ITy::Param(0), int(), PLAIN)],
                &["E0401"],
            ),
            (
                "error type absorbs",
                |s| {
                    let a = s.fresh_ty();
                    vec![
                        equal(ITy::Error, int(), PLAIN),
                        equal(a.clone(), ITy::Error, PLAIN),
                        one_of(a, TySet::ADD, BinOp::Add),
                    ]
                },
                &[],
            ),
            (
                "derived errors are suppressed",
                |s| {
                    let a = s.fresh_ty();
                    vec![
                        equal(a.clone(), int(), PLAIN),
                        equal(a.clone(), string(), PLAIN),
                        equal(a, con(TyCon::Bool), PLAIN),
                    ]
                },
                &["E0401"],
            ),
            (
                "operator on type parameter",
                |s| {
                    let a = s.fresh_ty();
                    vec![
                        one_of(a.clone(), TySet::ADD, BinOp::Add),
                        equal(a, ITy::Param(0), PLAIN),
                    ]
                },
                &["E0405"],
            ),
            (
                "equality of function type",
                |s| {
                    let a = s.fresh_ty();
                    vec![
                        equality(a.clone()),
                        equal(a, func(vec![], unit(), pure()), PLAIN),
                    ]
                },
                &["E0406"],
            ),
            (
                "equality of type containing IoError",
                |s| {
                    let a = s.fresh_ty();
                    let res = ITy::Con(TyCon::Result, vec![string(), con(TyCon::IoError)]);
                    vec![equality(a.clone()), equal(a, res, PLAIN)]
                },
                &["E0406"],
            ),
            (
                "equality moves to list element",
                |s| {
                    let a = s.fresh_ty();
                    vec![
                        equality(list(a.clone())),
                        equal(a, func(vec![], unit(), pure()), PLAIN),
                    ]
                },
                &["E0406"],
            ),
            (
                "pure function flows into IO position",
                |_| {
                    vec![flow(
                        func(vec![], unit(), pure()),
                        func(vec![], unit(), io()),
                        PLAIN,
                    )]
                },
                &[],
            ),
            (
                "undetermined variable is not an error here",
                |s| {
                    let a = s.fresh_ty();
                    vec![one_of(a, TySet::ADD, BinOp::Add)]
                },
                &[],
            ),
            (
                "nested effect mismatch in equal is one E0401",
                |_| {
                    vec![equal(
                        list(func(vec![], unit(), pure())),
                        list(func(vec![], unit(), io())),
                        PLAIN,
                    )]
                },
                &["E0401"],
            ),
        ];
        for (name, build, expected) in cases {
            let mut s = Solver::new();
            let cs = build(&mut s);
            let ds = solve(&mut s, cs);
            assert_eq!(&ids(&ds), expected, "{name}: {ds:#?}");
        }
    }

    #[test]
    fn unification_determines_types() {
        let mut s = Solver::new();
        let a = s.fresh_ty();
        let b = s.fresh_ty();
        let ds = solve(
            &mut s,
            vec![
                equal(a.clone(), int(), PLAIN),
                equal(list(a), b.clone(), PLAIN),
            ],
        );
        assert!(ds.is_empty(), "{ds:#?}");
        assert_eq!(s.finalize(&b), Ty::list(Ty::int()));
    }

    #[test]
    fn mismatch_shows_types_and_reason() {
        let mut s = Solver::new();
        let ds = solve(
            &mut s,
            vec![equal(int(), string(), ReasonKind::LetAnnotation)],
        );
        let d = only(&ds, DiagCode::E0401);
        assert_eq!(label(d), "expected `Int`, found `String`");
        assert_eq!(d.notes, vec!["the value must match the type annotation"]);
    }

    #[test]
    fn occurs_check_does_not_build_infinite_type() {
        let mut s = Solver::new();
        let a = s.fresh_ty();
        let ds = solve(
            &mut s,
            vec![equal(
                a.clone(),
                func(vec![a.clone()], int(), pure()),
                PLAIN,
            )],
        );
        only(&ds, DiagCode::E0404);
        // 型変数は誤りの型になり、置き換えが終わる。
        assert!(s.contains_error(&a));
        assert_eq!(s.finalize(&a), Ty::unit());
    }

    #[test]
    fn call_arity_and_non_function() {
        let mut s = Solver::new();
        let (b, c, r) = (s.fresh_ty(), s.fresh_ty(), s.fresh_ty());
        let callee = func(vec![int()], int(), pure());
        let ds = solve(
            &mut s,
            vec![equal(callee, func(vec![b, c], r, pure()), ReasonKind::Call)],
        );
        let d = only(&ds, DiagCode::E0402);
        assert_eq!(
            d.message,
            "this function takes 1 argument(s) but 2 were supplied"
        );

        let mut s = Solver::new();
        let r = s.fresh_ty();
        let ds = solve(
            &mut s,
            vec![equal(int(), func(vec![], r, pure()), ReasonKind::Call)],
        );
        let d = only(&ds, DiagCode::E0403);
        assert_eq!(d.message, "a value of type `Int` is not a function");
    }

    #[test]
    fn one_of_violation_lists_allowed_types() {
        let mut s = Solver::new();
        let a = s.fresh_ty();
        let ds = solve(
            &mut s,
            vec![
                one_of(a.clone(), TySet::ARITH, BinOp::Sub),
                equal(a, string(), PLAIN),
            ],
        );
        let d = only(&ds, DiagCode::E0405);
        assert_eq!(d.message, "`-` cannot be applied to `String`");
        assert_eq!(d.notes, vec!["`-` works on `Int` and `Float`"]);
    }

    #[test]
    fn one_of_sets_intersect_when_variables_meet() {
        let mut s = Solver::new();
        let (a, b) = (s.fresh_ty(), s.fresh_ty());
        let ds = solve(
            &mut s,
            vec![
                one_of(a.clone(), TySet::ADD, BinOp::Add),
                one_of(b.clone(), TySet::ORD, BinOp::Lt),
                equal(a, b.clone(), PLAIN),
                equal(b, con(TyCon::Char), PLAIN),
            ],
        );
        let d = only(&ds, DiagCode::E0405);
        assert_eq!(d.message, "`+` cannot be applied to `Char`");
        assert_eq!(d.notes, vec!["`+` works on `Int`, `Float`, and `String`"]);
    }

    #[test]
    fn fix_suggestions() {
        // `+` の二つのオペランドの型が違う。
        let mut s = Solver::new();
        let a = s.fresh_ty();
        let add = || ReasonKind::Operands {
            op: OpName::Bin(BinOp::Add),
        };
        let ds = solve(
            &mut s,
            vec![equal(a.clone(), string(), add()), equal(a, int(), add())],
        );
        let d = only(&ds, DiagCode::E0401);
        assert_eq!(
            d.helps,
            vec!["convert the value with `Int.toString` before joining it with `+`"]
        );

        // `Float` の位置の整数リテラル。
        let mut s = Solver::new();
        let mut r = reason(PLAIN);
        r.int_literal = Some("2".to_string());
        let c = Constraint::Equal {
            expected: con(TyCon::Float),
            found: int(),
            reason: r,
        };
        let ds = solve(&mut s, vec![c]);
        let d = only(&ds, DiagCode::E0401);
        assert_eq!(
            d.helps,
            vec!["write a floating-point literal such as `2.0`"]
        );
    }

    #[test]
    fn add_fix_suggestions_name_the_other_operand() {
        fn operands() -> ReasonKind {
            ReasonKind::Operands {
                op: OpName::Bin(BinOp::Add),
            }
        }
        // T15 の順（`Equal(α, 左)`・`Equal(α, 右)`・`OneOf(α, ADD)`）では、`String` と `String` でない型の
        // オペランドは二つ目の `Equal` で E0401 になる。α は誤りの型になり、`OneOf` は診断を出さない。
        let t15_order = |s: &mut Solver, other: ITy| {
            let a = s.fresh_ty();
            vec![
                equal(a.clone(), other, operands()),
                equal(a.clone(), string(), operands()),
                one_of(a, TySet::ADD, BinOp::Add),
            ]
        };
        // α が先に `+` の集まりの制約を持つ場合（入れ子の演算の結果の型など）は、集まりの制約を満たさない
        // オペランドで E0405 になる。相手のオペランドは同じ演算の `Equal(α, オペランド)` から引く。
        let constrained_first = |s: &mut Solver, other: ITy| {
            let a = s.fresh_ty();
            vec![
                one_of(a.clone(), TySet::ADD, BinOp::Add),
                equal(a.clone(), other, operands()),
                equal(a, string(), operands()),
            ]
        };
        type Build = fn(&mut Solver, ITy) -> Vec<Constraint>;
        let char_help = "convert the value with `Char.toString` before joining it with `+`";
        let any_help = "convert the other value to a `String` before joining it with `+`";
        let cases: &[(&str, Build, ITy, DiagCode, &str)] = &[
            (
                "t15 order, Char",
                t15_order,
                con(TyCon::Char),
                DiagCode::E0401,
                char_help,
            ),
            (
                "t15 order, Bool",
                t15_order,
                con(TyCon::Bool),
                DiagCode::E0401,
                any_help,
            ),
            (
                "constrained first, Char",
                constrained_first,
                con(TyCon::Char),
                DiagCode::E0405,
                char_help,
            ),
            (
                "constrained first, Bool",
                constrained_first,
                con(TyCon::Bool),
                DiagCode::E0405,
                any_help,
            ),
        ];
        for (name, build, other, code, help) in cases {
            let mut s = Solver::new();
            let cs = build(&mut s, other.clone());
            let ds = solve(&mut s, cs);
            assert_eq!(ids(&ds), vec![code.info().id], "{name}: {ds:#?}");
            assert_eq!(ds[0].helps, vec![*help], "{name}");
        }

        // 相手のオペランドも `String` でなければ、修正案を付けない（`true + true`）。
        let mut s = Solver::new();
        let a = s.fresh_ty();
        let bool_ty = con(TyCon::Bool);
        let ds = solve(
            &mut s,
            vec![
                equal(a.clone(), bool_ty.clone(), operands()),
                equal(a.clone(), bool_ty, operands()),
                one_of(a, TySet::ADD, BinOp::Add),
            ],
        );
        let d = only(&ds, DiagCode::E0405);
        assert!(d.helps.is_empty(), "{d:#?}");
    }

    #[test]
    fn builtin_param_constraints_attached_before_solve() {
        let sort = || {
            reason(ReasonKind::BuiltinParam {
                name: "List.sort".to_string(),
            })
        };
        let contains = || {
            reason(ReasonKind::BuiltinParam {
                name: "List.contains".to_string(),
            })
        };

        // 集まりの制約: 許される型に決まれば診断なし、許されない型なら E0405（`{op}` は関数の名前）。
        let mut s = Solver::new();
        let v = s.fresh_ty_var();
        s.constrain_one_of(v, TySet::ORD, sort());
        let ds = solve(&mut s, vec![equal(ITy::Var(v), string(), PLAIN)]);
        assert!(ds.is_empty(), "{ds:#?}");
        assert_eq!(s.finalize(&ITy::Var(v)), Ty::string());

        let mut s = Solver::new();
        let v = s.fresh_ty_var();
        s.constrain_one_of(v, TySet::ORD, sort());
        let ds = solve(&mut s, vec![equal(ITy::Var(v), con(TyCon::Bool), PLAIN)]);
        let d = only(&ds, DiagCode::E0405);
        assert_eq!(d.message, "`List.sort` cannot be applied to `Bool`");

        // 等値の制約: 基本型のリストは満たし、関数の型は E0406。
        let mut s = Solver::new();
        let v = s.fresh_ty_var();
        s.constrain_equality(v, contains());
        let ds = solve(&mut s, vec![equal(ITy::Var(v), list(int()), PLAIN)]);
        assert!(ds.is_empty(), "{ds:#?}");

        let mut s = Solver::new();
        let v = s.fresh_ty_var();
        s.constrain_equality(v, contains());
        let ds = solve(
            &mut s,
            vec![equal(ITy::Var(v), func(vec![], unit(), pure()), PLAIN)],
        );
        let d = only(&ds, DiagCode::E0406);
        assert_eq!(
            d.message,
            "values of type `fn() -> Unit` cannot be compared with `List.contains`"
        );

        // 既に決まった型変数に付けた制約も、次の solve で判定する。
        let mut s = Solver::new();
        let v = s.fresh_ty_var();
        let ds = solve(&mut s, vec![equal(ITy::Var(v), con(TyCon::Bool), PLAIN)]);
        assert!(ds.is_empty());
        s.constrain_one_of(v, TySet::ORD, sort());
        s.constrain_equality(v, contains());
        let ds = solve(&mut s, vec![]);
        only(&ds, DiagCode::E0405);
    }

    #[test]
    fn independent_errors_are_all_reported() {
        // 一つの本体の中でも、互いに独立した誤りをすべて報告する（ADR 0024）。
        let mut s = Solver::new();
        let b = s.fresh_ty();
        let ds = solve(
            &mut s,
            vec![
                equal(int(), string(), ReasonKind::LetAnnotation),
                equal(con(TyCon::Bool), unit(), ReasonKind::IfCondition),
                one_of(b.clone(), TySet::ARITH, BinOp::Mul),
                equal(b, string(), PLAIN),
                eff_sub(io(), pure(), reason(ReasonKind::FnUses)),
            ],
        );
        assert_eq!(
            ids(&ds),
            vec!["E0401", "E0401", "E0405", "E0501"],
            "{ds:#?}"
        );
        assert_eq!(label(&ds[0]), "expected `Int`, found `String`");
        assert_eq!(label(&ds[1]), "expected `Bool`, found `Unit`");
    }

    #[test]
    fn expression_statement_must_be_unit() {
        let mut s = Solver::new();
        let ds = solve(&mut s, vec![equal(unit(), int(), ReasonKind::ExprStmt)]);
        let d = only(&ds, DiagCode::E0416);
        assert_eq!(label(d), "this has type `Int`, not `Unit`");
    }

    #[test]
    fn equality_of_adt_follows_summary() {
        let boxed = TyCon::Adt(BindingId(7));
        let adts = AdtTable {
            adts: vec![AdtDef {
                con: boxed,
                name: "Box".to_string(),
                type_params: vec!["T".to_string()],
                ctors: vec![],
                eq_summary: EqSummary {
                    always: false,
                    depends_on: vec![0],
                },
            }],
        };
        let mut s = Solver::new();
        let with_fn = ITy::Con(boxed, vec![func(vec![], unit(), pure())]);
        let with_int = ITy::Con(boxed, vec![int()]);
        let ds = solve_with(
            &mut s,
            vec![equality(with_fn), equality(with_int)],
            &adts,
            &[],
        );
        let d = only(&ds, DiagCode::E0406);
        assert_eq!(
            d.message,
            "values of type `Box[fn() -> Unit]` cannot be compared with `==`"
        );
    }

    #[test]
    fn undetermined_reports_constrained_variables_once() {
        let mut s = Solver::new();
        let (a, b) = (s.fresh_ty(), s.fresh_ty());
        let ds = solve(
            &mut s,
            vec![
                one_of(a.clone(), TySet::ADD, BinOp::Add),
                equality(a.clone()),
                equal(a, b, PLAIN),
            ],
        );
        assert!(ds.is_empty(), "{ds:#?}");
        let rs = s.undetermined();
        assert_eq!(rs.len(), 1);
        assert_eq!(
            rs[0].kind,
            ReasonKind::Operator {
                op: OpName::Bin(BinOp::Add)
            }
        );
    }

    #[test]
    fn flow_effect_violation_is_type_mismatch() {
        let mut s = Solver::new();
        let ds = solve(
            &mut s,
            vec![flow(
                func(vec![], unit(), io()),
                func(vec![], unit(), pure()),
                ReasonKind::CallArg { index: 1 },
            )],
        );
        let d = only(&ds, DiagCode::E0401);
        assert_eq!(
            label(d),
            "expected `fn() -> Unit`, found `fn() -> Unit uses IO`"
        );
        assert_eq!(
            d.notes,
            vec!["argument 1 must match the parameter type of the called function"]
        );
    }

    #[test]
    fn flows_into_variable_do_not_depend_on_order() {
        // 02-05 の `[fn() { () }, fn() { Console.println("a") }]` と、要素の順を入れ替えたもの。
        for io_first in [false, true] {
            let mut s = Solver::new();
            let a = s.fresh_ty();
            let mut cs = vec![
                flow(
                    func(vec![], unit(), pure()),
                    a.clone(),
                    ReasonKind::ListElement,
                ),
                flow(
                    func(vec![], unit(), io()),
                    a.clone(),
                    ReasonKind::ListElement,
                ),
            ];
            if io_first {
                cs.reverse();
            }
            let ds = solve(&mut s, cs);
            assert!(ds.is_empty(), "io_first={io_first}: {ds:#?}");
            assert_eq!(
                s.finalize(&a),
                Ty::func(vec![], Ty::unit(), EffectSet::io()),
                "io_first={io_first}"
            );
        }
    }

    #[test]
    fn declared_flows_are_solved_first() {
        // 宣言から生じた流れ込む制約を先に解くので、後に並んだ宣言でなく使い方の側が誤りになる（ADR 0023）。
        let mut s = Solver::new();
        let a = s.fresh_ty();
        let mut declared = reason_at(ReasonKind::FnBody, 5);
        declared.priority = Priority::Declared;
        let ds = solve(
            &mut s,
            vec![
                equal(a.clone(), string(), ReasonKind::IfBranches),
                Constraint::Flow {
                    from: a,
                    to: int(),
                    reason: declared,
                },
            ],
        );
        let d = only(&ds, DiagCode::E0401);
        assert_eq!(label(d), "expected `Int`, found `String`");
        assert_eq!(
            d.notes,
            vec!["the branches of `if` must have compatible types"]
        );
    }

    #[test]
    fn deferred_flow_is_retried() {
        let mut s = Solver::new();
        let (a, b) = (s.fresh_ty(), s.fresh_ty());
        let ds = solve(
            &mut s,
            vec![
                flow(a.clone(), b.clone(), PLAIN),
                equal(a, func(vec![], unit(), pure()), PLAIN),
            ],
        );
        assert!(ds.is_empty(), "{ds:#?}");
        assert_eq!(
            s.finalize(&b),
            Ty::func(vec![], Ty::unit(), EffectSet::empty())
        );
    }

    /// 02-05 の `choose` の例。`second_io` なら第 2 引数が IO を行うラムダである。
    fn choose_constraints(s: &mut Solver, second_io: bool) -> (IEffect, Vec<Constraint>) {
        let eps = s.fresh_effect();
        let rho = s.fresh_effect();
        let sup = IEffect {
            fixed: EffectSet::io(),
            var: eps.var,
        };
        let second = if second_io { io() } else { pure() };
        let mut body = reason_at(ReasonKind::FnUses, 50);
        body.related = Some(sp(60));
        let cs = vec![
            eff_sub(rho.clone(), sup, reason_at(ReasonKind::CallEffect, 10)),
            eff_sub(second, eps.clone(), reason_at(ReasonKind::CallEffect, 20)),
            eff_sub(eps.clone(), pure(), body),
            eff_sub(io(), rho, reason_at(ReasonKind::CallEffect, 30)),
        ];
        (eps, cs)
    }

    #[test]
    fn effect_variables_take_minimal_sets() {
        let mut s = Solver::new();
        let (eps, cs) = choose_constraints(&mut s, false);
        let ds = solve(&mut s, cs);
        assert!(ds.is_empty(), "{ds:#?}");
        assert_eq!(s.finalize_effect(&eps), EffectSet::empty());
    }

    #[test]
    fn undeclared_effect_in_function_body() {
        let mut s = Solver::new();
        let (_, cs) = choose_constraints(&mut s, true);
        let ds = solve(&mut s, cs);
        let d = only(&ds, DiagCode::E0501);
        assert_eq!(
            d.message,
            "this function performs `IO` but does not declare it"
        );
        // 主な位置は IO を生じた呼び出し、補助の位置は宣言の `uses`。
        assert_eq!(d.primary.as_ref().unwrap().span, sp(20));
        assert_eq!(d.secondary.len(), 1);
        assert_eq!(d.secondary[0].span, sp(60));
        assert_eq!(d.helps.len(), 1);
    }

    #[test]
    fn undeclared_effect_in_lambda_and_effect_variable_names() {
        let mut s = Solver::new();
        let ds = solve(
            &mut s,
            vec![eff_sub(io(), pure(), reason(ReasonKind::LambdaUses))],
        );
        only(&ds, DiagCode::E0502);

        // 漏れた要素ごとに一つ出し、エフェクト変数は宣言の名前で示す。
        let mut s = Solver::new();
        let mut set = EffectSet::io();
        set.insert_var(EffVar(0));
        let ds = solve_with(
            &mut s,
            vec![eff_sub(fixed(set), pure(), reason(ReasonKind::FnUses))],
            &AdtTable::default(),
            &["E".to_string()],
        );
        assert_eq!(ids(&ds), vec!["E0501", "E0501"]);
        assert_eq!(label(&ds[0]), "`IO` happens here");
        assert_eq!(label(&ds[1]), "`E` happens here");
    }

    #[test]
    fn undetermined_effect_is_empty() {
        let mut s = Solver::new();
        let e = s.fresh_effect();
        let ds = solve(&mut s, vec![]);
        assert!(ds.is_empty());
        assert_eq!(s.finalize_effect(&e), EffectSet::empty());
    }

    /// `inner` を `wrap` で `depth` 段包んだ型。深い型を derive した Clone で複製しないように、毎回作る。
    fn nest(depth: usize, inner: ITy, wrap: fn(ITy) -> ITy) -> ITy {
        let mut t = inner;
        for _ in 0..depth {
            t = wrap(t);
        }
        t
    }

    fn option(t: ITy) -> ITy {
        ITy::Con(TyCon::Option, vec![t])
    }

    /// `fn() -> t`
    fn thunk(t: ITy) -> ITy {
        func(vec![], t, pure())
    }

    /// 入れ子の一段を外す。期待する形（`Option[_]`・`List[_]`・`fn() -> _`）の段なら中身を返す。
    type Step = fn(&Ty) -> Option<&Ty>;

    fn step_option(t: &Ty) -> Option<&Ty> {
        match t {
            Ty::Con(TyCon::Option, args) if args.len() == 1 => args.first(),
            Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) => None,
        }
    }

    fn step_list(t: &Ty) -> Option<&Ty> {
        match t {
            Ty::Con(TyCon::List, args) if args.len() == 1 => args.first(),
            Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) => None,
        }
    }

    fn step_thunk(t: &Ty) -> Option<&Ty> {
        match t {
            Ty::Fn(f) if f.params.is_empty() && f.effects.is_empty() => Some(&f.ret),
            Ty::Con(..) | Ty::Fn(_) | Ty::Param(_) => None,
        }
    }

    /// 期待する形の段を外せるだけ外し、外した段の数と最も内側の型を返す。
    /// 深い型に derive した PartialEq を使わないためである（再帰が深くなる）。
    fn peel(t: &Ty, step: Step) -> (usize, &Ty) {
        let mut t = t;
        let mut depth = 0;
        while let Some(inner) = step(t) {
            t = inner;
            depth += 1;
        }
        (depth, t)
    }

    /// `inner` を表示の前後の字面で `depth` 段包んだ文字列（期待する表示を組み立てる）。
    fn nested_text(depth: usize, prefix: &str, suffix: &str, inner: &str) -> String {
        format!("{}{inner}{}", prefix.repeat(depth), suffix.repeat(depth))
    }

    const DEEP: usize = 1000;

    /// 構文解析器の入れ子の上限（1000）程度の深さの型を、既定のテストのスタックで扱えること。
    /// 単一化の成功と、食い違ったときに E0401 を作って型を表示する経路まで通す。
    #[test]
    fn deep_types_unify_and_show() {
        type Wrap = fn(ITy) -> ITy;
        let shapes: [(&str, Wrap, Step, &str, &str); 3] = [
            ("option", option, step_option, "Option[", "]"),
            ("list", list, step_list, "List[", "]"),
            ("fn", thunk, step_thunk, "fn() -> ", ""),
        ];
        for (name, wrap, step, prefix, suffix) in shapes {
            let mut s = Solver::new();
            let a = s.fresh_ty();
            let ds = solve(
                &mut s,
                vec![
                    equal(nest(DEEP, a.clone(), wrap), nest(DEEP, int(), wrap), PLAIN),
                    flow(nest(DEEP, int(), wrap), nest(DEEP, a.clone(), wrap), PLAIN),
                ],
            );
            assert!(ds.is_empty(), "{name}: {ds:#?}");
            // 各段が期待する構成子で、最も内側が `Int` である。
            let t = s.finalize(&nest(DEEP, a.clone(), wrap));
            let (depth, inner) = peel(&t, step);
            assert_eq!(depth, DEEP, "{name}");
            assert_eq!(*inner, Ty::int(), "{name}");

            let expected = format!(
                "expected `{}`, found `{}`",
                nested_text(DEEP, prefix, suffix, "Int"),
                nested_text(DEEP, prefix, suffix, "String")
            );
            for as_flow in [false, true] {
                let mut s = Solver::new();
                let (to, from) = (nest(DEEP, int(), wrap), nest(DEEP, string(), wrap));
                let c = if as_flow {
                    flow(from, to, PLAIN)
                } else {
                    equal(to, from, PLAIN)
                };
                let ds = solve(&mut s, vec![c]);
                let d = only(&ds, DiagCode::E0401);
                // 表示の入れ子の形と、左右の最も内側の型を確かめる。
                assert!(label(d) == expected, "{name} as_flow={as_flow}");
            }
        }
    }

    #[test]
    fn long_variable_chains() {
        let mut s = Solver::new();
        let vars: Vec<ITy> = (0..10_000).map(|_| s.fresh_ty()).collect();
        let mut cs: Vec<Constraint> = vars
            .windows(2)
            .map(|w| equal(w[0].clone(), w[1].clone(), PLAIN))
            .collect();
        cs.push(equal(vars[0].clone(), int(), PLAIN));
        let ds = solve(&mut s, cs);
        assert!(ds.is_empty());
        assert_eq!(s.finalize(&vars[9_999]), Ty::int());
    }
}
