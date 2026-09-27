//! 名前解決の状態と、トップレベルの名前の表を作る処理（設計書 02-04「prelude」「解決の手順」の手順 1・2）。

use std::collections::BTreeMap;

use super::{Binding, BindingKind, DeclSite, ResolveOutput};
use crate::base::{BindingId, IdGen, NodeId, Span};
use crate::builtins::table::spec;
use crate::builtins::{BuiltinId, PreludeModule};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{Item, Name, Program};
use crate::types::TyCon;

/// 解決しているソースの種類。prelude のソースと利用者のソースでは名前の引き方が違う（02-04「prelude」）。
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub(super) enum Src {
    Prelude,
    User,
}

/// 修飾せずに書く prelude の構成子の名前（01-03「修飾しない名前の解決」）。
pub(super) const PRELUDE_CTORS: [&str; 4] = ["Some", "None", "Ok", "Err"];

/// トップレベルの大文字の名前が指すもの（01-03「トップレベルの名前空間」）。
#[derive(Clone, Copy, Debug)]
pub(super) enum Upper {
    /// 利用者の型。`Resolver::user_types` の添字
    UserType(usize),
    /// prelude の型。モジュールを兼ねるものは `Some`（`Bool` と `Unit` は中身のあるモジュールを持たない）
    PreludeType(BindingId, Option<PreludeModule>),
    /// 型を持たないモジュール
    Module(BindingId, PreludeModule),
    /// エフェクトの名前
    Effect(BindingId),
}

/// 利用者の型の宣言。モジュールとしての中身は構成子だけである。
#[derive(Debug)]
pub(super) struct UserType {
    pub(super) name: String,
    pub(super) binding: BindingId,
    pub(super) ctors: Vec<(String, BindingId)>,
}

/// 名前解決の状態。検査ごとに作り、大域に置かない（ADR 0015）。
pub(super) struct Resolver<'a> {
    pub(super) ids: &'a mut IdGen,
    pub(super) out: ResolveOutput,
    /// prelude の型・モジュール・エフェクトの名前
    pub(super) prelude_upper: Vec<(&'static str, Upper)>,
    /// prelude のソースの修飾した関数
    pub(super) prelude_fns: Vec<(PreludeModule, String, BindingId)>,
    /// prelude のソースの補助の関数。prelude のソースの中からだけ引く
    pub(super) helpers: BTreeMap<String, BindingId>,
    /// 利用者の型（誤りのあるものも含め、宣言の順）
    pub(super) user_types: Vec<UserType>,
    /// 名前で引ける利用者の型（重複や prelude との衝突のあったものは入れない）
    pub(super) user_type_names: BTreeMap<String, usize>,
    /// 利用者のトップレベルの関数
    pub(super) user_fns: BTreeMap<String, BindingId>,
}

/// prelude の型の名前と型構成子と、兼ねるモジュール（束縛を振る順）。
const PRELUDE_TYPES: [(&str, TyCon, Option<PreludeModule>); 10] = [
    ("Int", TyCon::Int, Some(PreludeModule::Int)),
    ("Float", TyCon::Float, Some(PreludeModule::Float)),
    ("String", TyCon::String, Some(PreludeModule::String)),
    ("Char", TyCon::Char, Some(PreludeModule::Char)),
    ("Bool", TyCon::Bool, None),
    ("Unit", TyCon::Unit, None),
    ("List", TyCon::List, Some(PreludeModule::List)),
    ("Option", TyCon::Option, Some(PreludeModule::Option)),
    ("Result", TyCon::Result, Some(PreludeModule::Result)),
    ("IoError", TyCon::IoError, Some(PreludeModule::IoError)),
];

/// 型を持たないモジュール（束縛を振る順）。
const PLAIN_MODULES: [PreludeModule; 3] = [
    PreludeModule::Console,
    PreludeModule::File,
    PreludeModule::Process,
];

/// エフェクトの名前。
const IO_EFFECT: &str = "IO";

impl<'a> Resolver<'a> {
    pub(super) fn new(ids: &'a mut IdGen) -> Resolver<'a> {
        Resolver {
            ids,
            out: ResolveOutput::default(),
            prelude_upper: Vec::new(),
            prelude_fns: Vec::new(),
            helpers: BTreeMap::new(),
            user_types: Vec::new(),
            user_type_names: BTreeMap::new(),
            user_fns: BTreeMap::new(),
        }
    }

    // ---------------- 束縛を作る補助 ----------------

    /// 組み込みの表の項目の束縛を作る（`DeclSite::Prelude`、span なし）。
    fn bind_table(&mut self, kind: BindingKind, name: &str) -> BindingId {
        let id = self.ids.binding();
        self.out.bindings.insert(
            id,
            Binding {
                kind,
                name: name.to_owned(),
                decl: DeclSite::Prelude,
                span: None,
            },
        );
        id
    }

    /// AST のノードで宣言した束縛を作り、宣言の表にも加える。
    pub(super) fn bind_node(&mut self, kind: BindingKind, name: &Name, node: NodeId) -> BindingId {
        let id = self.ids.binding();
        self.out.bindings.insert(
            id,
            Binding {
                kind,
                name: name.text.clone(),
                decl: DeclSite::Node(node),
                span: Some(name.span),
            },
        );
        self.out.decls.insert(node, id);
        id
    }

    pub(super) fn report(&mut self, builder: DiagBuilder) {
        self.out.diagnostics.push(builder.build());
    }

    /// 重複の誤り（2 個目を主な位置、1 個目を補助の位置）を報告する。
    pub(super) fn report_duplicate(&mut self, code: DiagCode, name: &Name, first: Span) {
        self.report(
            DiagBuilder::new(code)
                .arg("name", name.text.clone())
                .primary(name.span)
                .secondary(first, "first"),
        );
    }

    // ---------------- 手順 1: 組み込みの表 ----------------

    /// 組み込みの表の名前に束縛を振る（作業の文書の順序の 1〜5）。
    pub(super) fn bind_builtin_table(&mut self) {
        for (name, con, module) in PRELUDE_TYPES {
            let id = self.bind_table(BindingKind::Type(con), name);
            self.prelude_upper
                .push((name, Upper::PreludeType(id, module)));
        }
        for module in PLAIN_MODULES {
            let id = self.bind_table(BindingKind::Module(module), module.name());
            self.prelude_upper
                .push((module.name(), Upper::Module(id, module)));
        }
        let io = self.bind_table(BindingKind::Effect, IO_EFFECT);
        self.prelude_upper.push((IO_EFFECT, Upper::Effect(io)));

        let ctor = |con, tag| BindingKind::Ctor { con, tag };
        self.out.prelude.some = Some(self.bind_table(ctor(TyCon::Option, 0), "Some"));
        self.out.prelude.none = Some(self.bind_table(ctor(TyCon::Option, 1), "None"));
        self.out.prelude.ok = Some(self.bind_table(ctor(TyCon::Result, 0), "Ok"));
        self.out.prelude.err = Some(self.bind_table(ctor(TyCon::Result, 1), "Err"));

        // 演算子は名前で引かれないので束縛を持たない。
        for id in BuiltinId::ALL {
            if id.is_operator() {
                continue;
            }
            let b = self.bind_table(BindingKind::Builtin(id), spec(id).name);
            self.out.prelude.builtins.push((id, b));
        }
    }

    // ---------------- 手順 1: prelude のソースの関数 ----------------

    /// prelude のソースの関数を、修飾した関数と補助の関数に分けて集める（02-04「prelude」）。
    /// ここでの誤りは処理系の不具合であり、prelude のソースだけを解決するテストで見つける。
    pub(super) fn collect_prelude(&mut self, prelude: &[Program]) {
        // 重複の報告の補助の位置のために、名前を初めて宣言した位置を覚える。
        let mut first_qualified: Vec<(PreludeModule, String, Span)> = Vec::new();
        let mut first_helper: BTreeMap<String, Span> = BTreeMap::new();
        for program in prelude {
            for item in &program.items {
                let Item::Fn(decl) = item else { continue };
                let name = &decl.name;
                match &decl.module {
                    Some(qualifier) => {
                        let module = PreludeModule::ALL
                            .into_iter()
                            .find(|m| m.name() == qualifier.text);
                        let Some(module) = module else {
                            self.report(
                                DiagBuilder::new(DiagCode::E0302)
                                    .arg("name", qualifier.text.clone())
                                    .primary(qualifier.span),
                            );
                            let kind = BindingKind::PreludeFn { module: None };
                            self.bind_node(kind, name, decl.id);
                            continue;
                        };
                        let kind = BindingKind::PreludeFn {
                            module: Some(module),
                        };
                        let id = self.bind_node(kind, name, decl.id);
                        let earlier = first_qualified
                            .iter()
                            .find(|(m, n, _)| *m == module && *n == name.text)
                            .map(|(_, _, s)| *s);
                        if let Some(first) = earlier {
                            self.report_duplicate(DiagCode::E0306, name, first);
                        } else if crate::builtins::table::lookup(module, &name.text).is_some() {
                            // 組み込みの関数は宣言の位置を持たないので、補助の位置は示さない。
                            self.report(
                                DiagBuilder::new(DiagCode::E0306)
                                    .arg("name", name.text.clone())
                                    .primary(name.span),
                            );
                        } else {
                            first_qualified.push((module, name.text.clone(), name.span));
                            self.prelude_fns.push((module, name.text.clone(), id));
                        }
                    }
                    None => {
                        let kind = BindingKind::PreludeFn { module: None };
                        let id = self.bind_node(kind, name, decl.id);
                        if let Some(first) = first_helper.get(&name.text).copied() {
                            self.report_duplicate(DiagCode::E0306, name, first);
                        } else {
                            first_helper.insert(name.text.clone(), name.span);
                            self.helpers.insert(name.text.clone(), id);
                        }
                    }
                }
            }
        }
    }

    // ---------------- 手順 2: 利用者のトップレベルの宣言 ----------------

    /// 利用者の型・構成子・関数をソースの順に集め、トップレベルの名前の誤りを報告する
    /// （01-03「トップレベルの名前空間」、01-05「型の宣言」）。
    pub(super) fn collect_user(&mut self, user: &Program) {
        let mut first_type: BTreeMap<String, Span> = BTreeMap::new();
        let mut first_fn: BTreeMap<String, Span> = BTreeMap::new();
        for item in &user.items {
            match item {
                Item::Type(decl) => {
                    let name = &decl.name;
                    let id = self.ids.binding();
                    self.out.bindings.insert(
                        id,
                        Binding {
                            kind: BindingKind::Type(TyCon::Adt(id)),
                            name: name.text.clone(),
                            decl: DeclSite::Node(decl.id),
                            span: Some(name.span),
                        },
                    );
                    self.out.decls.insert(decl.id, id);

                    // 型の宣言の束縛の直後に、その構成子の束縛を振る。
                    let mut ctors: Vec<(String, BindingId)> = Vec::new();
                    let mut first_ctor: BTreeMap<String, Span> = BTreeMap::new();
                    for (tag, variant) in decl.variants.iter().enumerate() {
                        let tag = u32::try_from(tag).unwrap_or(u32::MAX);
                        let kind = BindingKind::Ctor {
                            con: TyCon::Adt(id),
                            tag,
                        };
                        let cid = self.bind_node(kind, &variant.name, variant.id);
                        if let Some(first) = first_ctor.get(&variant.name.text).copied() {
                            self.report(
                                DiagBuilder::new(DiagCode::E0309)
                                    .arg("name", variant.name.text.clone())
                                    .arg("ty", name.text.clone())
                                    .primary(variant.name.span)
                                    .secondary(first, "first"),
                            );
                        } else {
                            first_ctor.insert(variant.name.text.clone(), variant.name.span);
                            ctors.push((variant.name.text.clone(), cid));
                        }
                    }
                    let index = self.user_types.len();
                    self.user_types.push(UserType {
                        name: name.text.clone(),
                        binding: id,
                        ctors,
                    });

                    if PRELUDE_CTORS.contains(&name.text.as_str()) {
                        self.report(
                            DiagBuilder::new(DiagCode::E0308)
                                .arg("name", name.text.clone())
                                .primary(name.span)
                                .note("prelude_ctor"),
                        );
                    } else if self.prelude_upper.iter().any(|(n, _)| *n == name.text) {
                        self.report(
                            DiagBuilder::new(DiagCode::E0307)
                                .arg("name", name.text.clone())
                                .primary(name.span),
                        );
                    } else if let Some(first) = first_type.get(&name.text).copied() {
                        self.report_duplicate(DiagCode::E0305, name, first);
                    } else {
                        first_type.insert(name.text.clone(), name.span);
                        self.user_type_names.insert(name.text.clone(), index);
                    }
                }
                Item::Fn(decl) => {
                    let name = &decl.name;
                    let id = self.bind_node(BindingKind::TopFn, name, decl.id);
                    if let Some(first) = first_fn.get(&name.text).copied() {
                        self.report_duplicate(DiagCode::E0306, name, first);
                    } else {
                        first_fn.insert(name.text.clone(), name.span);
                        self.user_fns.insert(name.text.clone(), id);
                    }
                }
                Item::Error(_) => {}
            }
        }
    }
}
