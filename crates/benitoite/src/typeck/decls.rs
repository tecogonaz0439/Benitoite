//! 宣言の検査（設計書 02-05「宣言の検査」）。
//!
//! 型の宣言から代数的データ型の表を作り、等値の型の要約を求め（01-06「等値の型」、ADR 0082）、
//! 関数と構成子の宣言の型（`Scheme`）を決め、`main` の形を確かめる（01-07「プログラムの入口」）。
//! 型を書いた箇所（`TypeExpr`）から `Ty` への変換も受け持ち、本体の型注釈の変換（`generate.rs`）にも使う。
//!
//! 型の宣言と関数のシグネチャで誤りを報告した宣言は「壊れた宣言」として記録する。壊れた宣言を
//! 使う箇所の型は誤りの型にし、壊れた関数の本体は検査しない。宣言の誤りから派生した誤りを
//! 本体で報告しないためである（ADR 0024 の趣旨を宣言に広げる。作業 T15 で決めた）。

use std::collections::{BTreeMap, BTreeSet, HashSet};

use super::MainInfo;
use crate::base::{BindingId, BindingMap, NodeId, Span};
use crate::diag::{DiagBuilder, DiagCode, Diagnostic};
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::{FnDecl, FnType, Item, NamedType, Program, TypeDecl, TypeExpr, UsesList};
use crate::types::{
    AdtDef, AdtTable, CtorDef, EffVar, EffectSet, EqSummary, ParamConstraint, Scheme, Ty, TyCon,
    TypeParamInfo,
};

/// 呼び出しの診断の補助の位置に使う、宣言の位置（02-05「制約の種類」の「関連する位置」）。
#[derive(Clone, Debug)]
pub(super) struct Site {
    /// 関数の名前、または構成子の名前の位置
    pub name: Span,
    /// 引数の型を書いた位置（構成子では引数の型の位置）
    pub params: Vec<Span>,
}

/// 宣言の検査の結果。本体の検査はこれを読むだけで、書き換えない。
#[derive(Debug, Default)]
pub(super) struct Decls {
    pub decl_types: BindingMap<Scheme>,
    pub adts: AdtTable,
    /// 壊れた宣言（関数、型、構成子）の束縛の番号
    pub broken: HashSet<BindingId>,
    pub sites: BindingMap<Site>,
    /// 利用者の型の宣言の型パラメータの数（E0410 の検査に使う）
    pub adt_arity: BTreeMap<BindingId, usize>,
    pub main: Option<MainInfo>,
}

/// 型を書いた箇所を `Ty` に変える文脈。名前は名前解決の参照の表で引く（作業 T15「宣言の検査」）。
#[derive(Clone, Copy)]
pub(super) struct TypeCx<'a> {
    pub resolved: &'a ResolveOutput,
    pub adt_arity: &'a BTreeMap<BindingId, usize>,
}

impl TypeCx<'_> {
    fn kind_of(&self, node: NodeId) -> Option<BindingKind> {
        let b = self.resolved.refs.get(node)?;
        self.resolved.bindings.get(*b).map(|b| b.kind)
    }

    /// 型を変換する。誤りを報告したら `None` を返す。一つの誤りで止めず、型の全体を辿って
    /// 独立した誤りをすべて報告する（ADR 0024）。型の入れ子は構文解析器の上限（1000）まで深くなりうる
    /// ので、再帰の経路の関数（`convert`・`named`・`convert_all`）は、診断を作る処理などを別の関数に分け、
    /// 一段の枠を小さく保つ（実装プラン 00-02「再帰の深さ」）。
    pub fn convert(&self, t: &TypeExpr, diags: &mut Vec<Diagnostic>) -> Option<Ty> {
        match t {
            TypeExpr::Named(n) => self.named(n, diags),
            TypeExpr::Fn(f) => self.fn_type(f, diags),
            TypeExpr::Paren(p) => self.convert(&p.inner, diags),
            // 構文の誤りのある AST は型検査に来ない（ADR 0019）。
            TypeExpr::Error(_) => None,
        }
    }

    /// 型の並びを変換する。どれかが誤りなら `None`（残りも辿って誤りを報告する）。
    fn convert_all(&self, ts: &[TypeExpr], diags: &mut Vec<Diagnostic>) -> Option<Vec<Ty>> {
        let mut out = Some(Vec::with_capacity(ts.len()));
        for t in ts {
            match (self.convert(t, diags), out.as_mut()) {
                (Some(ty), Some(v)) => v.push(ty),
                _ => out = None,
            }
        }
        out
    }

    fn fn_type(&self, f: &FnType, diags: &mut Vec<Diagnostic>) -> Option<Ty> {
        let params = self.convert_all(&f.params, diags);
        let ret = self.convert(&f.ret, diags);
        let effects = self.convert_uses(f.uses.as_ref(), diags);
        Some(Ty::func(params?, ret?, effects?))
    }

    fn named(&self, n: &NamedType, diags: &mut Vec<Diagnostic>) -> Option<Ty> {
        let args = self.convert_all(&n.args, diags);
        match self.named_head(n, diags)? {
            Ok(c) => Some(Ty::Con(c, args?)),
            Err(index) => Some(Ty::Param(index)),
        }
    }

    /// 名前の型の型構成子（型パラメータなら `Err(index)`）を決め、型引数の個数を検査する
    /// （01-05「型の宣言」）。型パラメータは型引数をとらない。
    fn named_head(&self, n: &NamedType, diags: &mut Vec<Diagnostic>) -> Option<Result<TyCon, u32>> {
        let (expected, head) = match self.kind_of(n.id)? {
            BindingKind::Type(c) => {
                let arity = match (c.builtin_arity(), c) {
                    (Some(a), _) => a,
                    (None, TyCon::Adt(b)) => *self.adt_arity.get(&b)?,
                    (None, _) => return None,
                };
                (arity, Ok(c))
            }
            BindingKind::TypeParam { index } => (0, Err(index)),
            // 種類の合わない名前は名前解決が報告する（02-04）。
            BindingKind::TopFn
            | BindingKind::PreludeFn { .. }
            | BindingKind::Builtin(_)
            | BindingKind::Ctor { .. }
            | BindingKind::Param
            | BindingKind::Let
            | BindingKind::LambdaParam
            | BindingKind::PatternVar
            | BindingKind::EffectVar { .. }
            | BindingKind::Effect
            | BindingKind::Module(_) => return None,
        };
        if n.args.len() != expected {
            diags.push(
                DiagBuilder::new(DiagCode::E0410)
                    .arg("name", n.name.text.clone())
                    .arg("expected", expected.to_string())
                    .arg("found", n.args.len().to_string())
                    .primary(n.span)
                    .build(),
            );
            return None;
        }
        Some(head)
    }

    /// `uses` の並びをエフェクトの集合にする。エフェクト変数の規則のうち、並びの中で決まる
    /// E0417（変数が二つ以上）と E0419（同じ名前が二度）を検査する（01-06「関数の型とエフェクト」）。
    pub fn convert_uses(
        &self,
        uses: Option<&UsesList>,
        diags: &mut Vec<Diagnostic>,
    ) -> Option<EffectSet> {
        let mut set = EffectSet::empty();
        let Some(uses) = uses else {
            return Some(set);
        };
        let mut ok = true;
        let mut seen: Vec<BindingId> = Vec::new();
        let mut var_count: usize = 0;
        for r in &uses.effects {
            let Some(b) = self.resolved.refs.get(r.id).copied() else {
                ok = false;
                continue;
            };
            if seen.contains(&b) {
                diags.push(
                    DiagBuilder::new(DiagCode::E0419)
                        .arg("name", r.name.text.clone())
                        .primary(r.span)
                        .build(),
                );
                ok = false;
                continue;
            }
            seen.push(b);
            match self.resolved.bindings.get(b).map(|b| b.kind) {
                Some(BindingKind::Effect) => set.io = true,
                Some(BindingKind::EffectVar { index }) => {
                    var_count = var_count.saturating_add(1);
                    set.insert_var(EffVar(index));
                }
                Some(
                    BindingKind::TopFn
                    | BindingKind::PreludeFn { .. }
                    | BindingKind::Builtin(_)
                    | BindingKind::Ctor { .. }
                    | BindingKind::Param
                    | BindingKind::Let
                    | BindingKind::LambdaParam
                    | BindingKind::PatternVar
                    | BindingKind::Type(_)
                    | BindingKind::TypeParam { .. }
                    | BindingKind::Module(_),
                )
                | None => ok = false,
            }
        }
        if var_count > 1 {
            diags.push(DiagBuilder::new(DiagCode::E0417).primary(uses.span).build());
            ok = false;
        }
        ok.then_some(set)
    }
}

/// 宣言の検査を行う（02-05「宣言の検査」）。順序は作業 T15「宣言の検査」に従う。
pub(super) fn check_decls(
    prelude: &[Program],
    user: &Program,
    resolved: &ResolveOutput,
    diags: &mut Vec<Diagnostic>,
) -> Decls {
    let mut d = Decls::default();
    add_prelude_adts(&mut d, resolved);

    // 型は宣言の順序によらず互いを参照できる（01-05「型の宣言」）ので、型引数の個数の検査のために、
    // 先にすべての型の宣言の型パラメータの数を集める。
    for item in &user.items {
        if let Item::Type(td) = item
            && let Some(b) = resolved.decls.get(td.id)
        {
            let arity = td.type_params.iter().filter(|p| !p.is_effect).count();
            d.adt_arity.insert(*b, arity);
        }
    }

    for item in &user.items {
        if let Item::Type(td) = item {
            check_type_decl(&mut d, resolved, td, diags);
        }
    }
    compute_eq_summaries(&mut d.adts);
    add_ctor_schemes(&mut d);

    for program in prelude {
        for item in &program.items {
            if let Item::Fn(f) = item {
                check_fn_sig(&mut d, resolved, f, diags);
            }
        }
    }
    for item in &user.items {
        if let Item::Fn(f) = item {
            check_fn_sig(&mut d, resolved, f, diags);
        }
    }
    d.main = check_main(&d, user, resolved, diags);
    d
}

/// `Option` と `Result` の代数的データ型（01-05「prelude が定める型」）。タグは 02-07 の定め。
/// 構成子の束縛の番号は名前解決の `PreludeBindings` から取る。
fn add_prelude_adts(d: &mut Decls, resolved: &ResolveOutput) {
    let p = &resolved.prelude;
    let ctor = |name: &str, binding: Option<BindingId>, tag: u32, fields: Vec<Ty>| {
        binding.map(|binding| CtorDef {
            name: name.to_string(),
            binding,
            tag,
            fields,
        })
    };
    let option_ctors = [
        ctor("Some", p.some, 0, vec![Ty::Param(0)]),
        ctor("None", p.none, 1, Vec::new()),
    ];
    let result_ctors = [
        ctor("Ok", p.ok, 0, vec![Ty::Param(0)]),
        ctor("Err", p.err, 1, vec![Ty::Param(1)]),
    ];
    d.adts.adts.push(AdtDef {
        con: TyCon::Option,
        name: "Option".to_string(),
        type_params: vec!["T".to_string()],
        ctors: option_ctors.into_iter().flatten().collect(),
        eq_summary: EqSummary::default(),
    });
    d.adts.adts.push(AdtDef {
        con: TyCon::Result,
        name: "Result".to_string(),
        type_params: vec!["T".to_string(), "E".to_string()],
        ctors: result_ctors.into_iter().flatten().collect(),
        eq_summary: EqSummary::default(),
    });
}

/// 利用者の型の宣言を一つ検査し、代数的データ型の表に加える。
fn check_type_decl(
    d: &mut Decls,
    resolved: &ResolveOutput,
    td: &TypeDecl,
    diags: &mut Vec<Diagnostic>,
) {
    let Some(b) = resolved.decls.get(td.id).copied() else {
        return;
    };
    let mut broken = false;
    if td.variants.is_empty() {
        diags.push(
            DiagBuilder::new(DiagCode::E0411)
                .arg("name", td.name.text.clone())
                .primary(td.name.span)
                .help("add")
                .build(),
        );
        broken = true;
    }
    let tcx = TypeCx {
        resolved,
        adt_arity: &d.adt_arity,
    };
    let mut ctors = Vec::with_capacity(td.variants.len());
    let mut sites = Vec::with_capacity(td.variants.len());
    for (tag, v) in td.variants.iter().enumerate() {
        let mut fields = Vec::with_capacity(v.fields.len());
        for f in &v.fields {
            match tcx.convert(f, diags) {
                Some(ty) => fields.push(ty),
                None => {
                    // 壊れた型の宣言の構成子は使われないので、欄の型は仮の型にしておく。
                    broken = true;
                    fields.push(Ty::unit());
                }
            }
        }
        let Some(cb) = resolved.decls.get(v.id).copied() else {
            broken = true;
            continue;
        };
        sites.push((
            cb,
            Site {
                name: v.name.span,
                params: v.fields.iter().map(TypeExpr::span).collect(),
            },
        ));
        ctors.push(CtorDef {
            name: v.name.text.clone(),
            binding: cb,
            tag: u32::try_from(tag).unwrap_or(u32::MAX),
            fields,
        });
    }
    for (cb, site) in sites {
        d.sites.insert(cb, site);
        if broken {
            d.broken.insert(cb);
        }
    }
    if broken {
        d.broken.insert(b);
    }
    d.adts.adts.push(AdtDef {
        con: TyCon::Adt(b),
        name: td.name.text.clone(),
        type_params: td
            .type_params
            .iter()
            .filter(|p| !p.is_effect)
            .map(|p| p.name.text.clone())
            .collect(),
        ctors,
        eq_summary: EqSummary::default(),
    });
}

/// 型が関数の型か中身を見せない prelude の型を含む条件（01-06「等値の型」の手順 2）。
enum Cond {
    /// 型引数によらず含む
    Always,
    /// 集合の型パラメータのどれかに与えた型引数が含むときに含む
    On(BTreeSet<u32>),
}

impl Cond {
    fn never() -> Cond {
        Cond::On(BTreeSet::new())
    }

    fn join(self, other: Cond) -> Cond {
        match (self, other) {
            (Cond::Always, _) | (_, Cond::Always) => Cond::Always,
            (Cond::On(mut a), Cond::On(b)) => {
                a.extend(b);
                Cond::On(a)
            }
        }
    }
}

/// 構成子の引数の型 τ が含む条件を、現在の要約で求める（01-06「等値の型」の手順 2）。
fn cond_of(ty: &Ty, adts: &AdtTable) -> Cond {
    match ty {
        Ty::Fn(_) => Cond::Always,
        Ty::Param(i) => Cond::On(BTreeSet::from([*i])),
        Ty::Con(c, args) => match c {
            TyCon::Int | TyCon::Float | TyCon::String | TyCon::Char | TyCon::Bool | TyCon::Unit => {
                Cond::never()
            }
            TyCon::IoError => Cond::Always,
            TyCon::List => args
                .iter()
                .fold(Cond::never(), |acc, a| acc.join(cond_of(a, adts))),
            TyCon::Option | TyCon::Result | TyCon::Adt(_) => {
                let Some(def) = adts.get(*c) else {
                    return Cond::never();
                };
                if def.eq_summary.always {
                    return Cond::Always;
                }
                let mut acc = Cond::never();
                for j in &def.eq_summary.depends_on {
                    let arg = usize::try_from(*j).ok().and_then(|j| args.get(j));
                    if let Some(arg) = arg {
                        acc = acc.join(cond_of(arg, adts));
                    }
                }
                acc
            }
        },
    }
}

/// すべての型の宣言の等値の型の要約を、同時に、変わらなくなるまで求める（01-06「等値の型」、ADR 0082）。
/// 要約は偽から真へ、集合は大きくなる方向にだけ変わるので、繰り返しは必ず終わる。
fn compute_eq_summaries(adts: &mut AdtTable) {
    loop {
        let mut changed = false;
        for i in 0..adts.adts.len() {
            let Some(def) = adts.adts.get(i) else {
                continue;
            };
            let mut acc = Cond::never();
            for ctor in &def.ctors {
                for f in &ctor.fields {
                    acc = acc.join(cond_of(f, adts));
                }
            }
            let summary = match acc {
                Cond::Always => EqSummary {
                    always: true,
                    depends_on: Vec::new(),
                },
                Cond::On(set) => EqSummary {
                    always: false,
                    depends_on: set.into_iter().collect(),
                },
            };
            if let Some(def) = adts.adts.get_mut(i)
                && def.eq_summary != summary
            {
                def.eq_summary = summary;
                changed = true;
            }
        }
        if !changed {
            break;
        }
    }
}

/// 構成子の宣言の型（10-05「型検査の出力」の最後の段落）。型の宣言の型パラメータを型パラメータとし、
/// 引数の型を引数、`D[T̄]` を戻り値の型、空集合をエフェクトとする。
fn add_ctor_schemes(d: &mut Decls) {
    for def in &d.adts.adts {
        let n = u32::try_from(def.type_params.len()).unwrap_or(u32::MAX);
        let ret = Ty::Con(def.con, (0..n).map(Ty::Param).collect());
        for ctor in &def.ctors {
            if d.broken.contains(&ctor.binding) {
                continue;
            }
            d.decl_types.insert(
                ctor.binding,
                Scheme {
                    type_params: def
                        .type_params
                        .iter()
                        .map(|name| TypeParamInfo {
                            name: name.clone(),
                            constraint: ParamConstraint::None,
                        })
                        .collect(),
                    effect_params: Vec::new(),
                    params: ctor.fields.clone(),
                    ret: ret.clone(),
                    effects: EffectSet::empty(),
                },
            );
        }
    }
}

/// 型を書いた箇所の中の、`uses` の並びに書いた名前の束縛を集める（E0418 の検査）。
fn collect_effect_refs(t: &TypeExpr, resolved: &ResolveOutput, out: &mut HashSet<BindingId>) {
    match t {
        TypeExpr::Named(n) => {
            for a in &n.args {
                collect_effect_refs(a, resolved, out);
            }
        }
        TypeExpr::Fn(f) => {
            for p in &f.params {
                collect_effect_refs(p, resolved, out);
            }
            collect_effect_refs(&f.ret, resolved, out);
            if let Some(uses) = &f.uses {
                out.extend(uses.effects.iter().filter_map(|r| resolved.refs.get(r.id)));
            }
        }
        TypeExpr::Paren(p) => collect_effect_refs(&p.inner, resolved, out),
        TypeExpr::Error(_) => {}
    }
}

/// 関数のシグネチャを検査し、宣言の型を決める（02-05「宣言の検査」）。
fn check_fn_sig(d: &mut Decls, resolved: &ResolveOutput, f: &FnDecl, diags: &mut Vec<Diagnostic>) {
    let Some(b) = resolved.decls.get(f.id).copied() else {
        return;
    };
    let tcx = TypeCx {
        resolved,
        adt_arity: &d.adt_arity,
    };
    let mut ok = true;
    let mut params = Vec::with_capacity(f.params.len());
    for p in &f.params {
        match p.ty.as_ref().and_then(|t| tcx.convert(t, diags)) {
            Some(ty) => params.push(ty),
            None => ok = false,
        }
    }
    let ret = tcx.convert(&f.ret, diags);
    let effects = tcx.convert_uses(f.uses.as_ref(), diags);

    // 宣言したエフェクト変数は、引数の型のどこかに現れなければならない（01-06「関数の型とエフェクト」）。
    let mut in_params = HashSet::new();
    for p in &f.params {
        if let Some(t) = &p.ty {
            collect_effect_refs(t, resolved, &mut in_params);
        }
    }
    for tp in f.type_params.iter().filter(|tp| tp.is_effect) {
        let declared = resolved.decls.get(tp.id);
        if declared.is_some_and(|eb| !in_params.contains(eb)) {
            diags.push(
                DiagBuilder::new(DiagCode::E0418)
                    .arg("name", tp.name.text.clone())
                    .primary(tp.name.span)
                    .build(),
            );
            ok = false;
        }
    }

    d.sites.insert(
        b,
        Site {
            name: f.name.span,
            params: f
                .params
                .iter()
                .map(|p| p.ty.as_ref().map_or(p.span, TypeExpr::span))
                .collect(),
        },
    );
    let (true, Some(ret), Some(effects)) = (ok, ret, effects) else {
        d.broken.insert(b);
        return;
    };
    d.decl_types.insert(
        b,
        Scheme {
            type_params: f
                .type_params
                .iter()
                .filter(|tp| !tp.is_effect)
                .map(|tp| TypeParamInfo {
                    name: tp.name.text.clone(),
                    constraint: ParamConstraint::None,
                })
                .collect(),
            effect_params: f
                .type_params
                .iter()
                .filter(|tp| tp.is_effect)
                .map(|tp| tp.name.text.clone())
                .collect(),
            params,
            ret,
            effects,
        },
    );
}

/// `main` の名前（01-07「プログラムの入口」）。
const MAIN: &str = "main";

/// `main` を検査する（01-07「プログラムの入口」）。満たさない条件ごとに注記を一つの診断に並べる。
fn check_main(
    d: &Decls,
    user: &Program,
    resolved: &ResolveOutput,
    diags: &mut Vec<Diagnostic>,
) -> Option<MainInfo> {
    let found = user.items.iter().find_map(|item| match item {
        Item::Fn(f) if f.name.text == MAIN => Some(f),
        Item::Fn(_) | Item::Type(_) | Item::Error(_) => None,
    });
    let Some(f) = found else {
        diags.push(DiagBuilder::new(DiagCode::E0414).help("define").build());
        return None;
    };
    let b = resolved.decls.get(f.id).copied()?;
    let mut notes: Vec<&'static str> = Vec::new();
    if !f.params.is_empty() {
        notes.push("params");
    }
    if !f.type_params.is_empty() {
        notes.push("type_params");
    }
    // シグネチャが壊れていれば、その誤りを既に報告したので、戻り値の型とエフェクトは調べない。
    let scheme = d.decl_types.get(b);
    let returns_result = scheme.is_some_and(|s| s.ret == Ty::result(Ty::unit(), Ty::string()));
    if let Some(s) = scheme {
        if s.ret != Ty::unit() && !returns_result {
            notes.push("ret");
        }
        if !s.effects.vars.is_empty() {
            notes.push("effects");
        }
    }
    if !notes.is_empty() {
        let mut builder = DiagBuilder::new(DiagCode::E0415).primary(f.name.span);
        for n in notes {
            builder = builder.note(n);
        }
        diags.push(builder.build());
        return None;
    }
    scheme?;
    Some(MainInfo {
        binding: b,
        returns_result,
    })
}
