//! 名前を引く規則（設計書 01-03「修飾された名前の解決」「修飾しない名前の解決」、02-04「誤りと修正案」）。

use std::collections::BTreeMap;

use super::collect::{PRELUDE_CTORS, Resolver, Src, Upper};
use super::{BindingKind, suggest, text};
use crate::base::{BindingId, Span};
use crate::builtins::table::{lookup as table_lookup, spec};
use crate::builtins::{BuiltinId, PreludeModule};
use crate::diag::{DiagBuilder, DiagCode};
use crate::syntax::ast::{EffectRef, Name, NamedType, UsesList};

/// 一つのトップレベルの宣言を辿る間の文脈。
pub(super) struct Ctx {
    pub(super) src: Src,
    /// 型パラメータ（`effect` を付けないもの）
    pub(super) type_params: Vec<(String, BindingId)>,
    /// エフェクト変数
    pub(super) effect_vars: Vec<(String, BindingId)>,
    /// 局所の束縛の有効範囲の積み重ね。内側が末尾
    pub(super) scopes: Vec<BTreeMap<String, BindingId>>,
}

impl Ctx {
    pub(super) fn new(src: Src) -> Ctx {
        Ctx {
            src,
            type_params: Vec::new(),
            effect_vars: Vec::new(),
            scopes: Vec::new(),
        }
    }

    fn type_param(&self, name: &str) -> Option<BindingId> {
        find(&self.type_params, name)
    }

    fn effect_var(&self, name: &str) -> Option<BindingId> {
        find(&self.effect_vars, name)
    }

    fn local(&self, name: &str) -> Option<BindingId> {
        self.scopes
            .iter()
            .rev()
            .find_map(|scope| scope.get(name).copied())
    }
}

fn find(list: &[(String, BindingId)], name: &str) -> Option<BindingId> {
    list.iter().find(|(n, _)| n == name).map(|(_, b)| *b)
}

/// 修飾された名前の結果。
pub(super) enum Qualified {
    Found(BindingId),
    /// 誤りを報告した
    Failed,
}

impl Resolver<'_> {
    /// トップレベルの大文字の名前を引く。prelude のソースからは利用者の型を引かない（02-04「prelude」）。
    pub(super) fn lookup_upper(&self, src: Src, name: &str) -> Option<Upper> {
        if src == Src::User
            && let Some(index) = self.user_type_names.get(name)
        {
            return Some(Upper::UserType(*index));
        }
        self.prelude_upper
            .iter()
            .find(|(n, _)| *n == name)
            .map(|(_, u)| *u)
    }

    /// その位置で見えるトップレベルの大文字の名前（候補を作るため）。
    fn upper_names(&self, src: Src, only_types: bool) -> Vec<String> {
        let mut names: Vec<String> = Vec::new();
        if src == Src::User {
            names.extend(self.user_type_names.keys().cloned());
        }
        for (n, u) in &self.prelude_upper {
            if !only_types || matches!(u, Upper::PreludeType(..)) {
                names.push((*n).to_owned());
            }
        }
        names
    }

    fn upper_binding(&self, upper: Upper) -> Option<BindingId> {
        match upper {
            Upper::UserType(i) => self.user_types.get(i).map(|t| t.binding),
            Upper::PreludeType(b, _) | Upper::Module(b, _) | Upper::Effect(b) => Some(b),
        }
    }

    fn builtin_binding(&self, id: BuiltinId) -> Option<BindingId> {
        self.out
            .prelude
            .builtins
            .iter()
            .find(|(b, _)| *b == id)
            .map(|(_, binding)| *binding)
    }

    /// prelude のモジュールの中の名前を引く。prelude 専用の組み込みの関数は、prelude のソースからだけ見える。
    fn prelude_member(&self, src: Src, module: PreludeModule, name: &str) -> Option<BindingId> {
        if let Some(id) = table_lookup(module, name)
            && (src == Src::Prelude || !spec(id).prelude_only)
        {
            return self.builtin_binding(id);
        }
        self.prelude_fns
            .iter()
            .find(|(m, n, _)| *m == module && n == name)
            .map(|(_, _, b)| *b)
    }

    /// prelude のモジュールの中の見える名前（候補を作るため）。
    fn prelude_members(&self, src: Src, module: PreludeModule) -> Vec<String> {
        let mut names: Vec<String> = BuiltinId::ALL
            .into_iter()
            .map(spec)
            .filter(|s| s.module == Some(module) && (src == Src::Prelude || !s.prelude_only))
            .map(|s| s.name.to_owned())
            .collect();
        names.extend(
            self.prelude_fns
                .iter()
                .filter(|(m, _, _)| *m == module)
                .map(|(_, n, _)| n.clone()),
        );
        names
    }

    // ---------------- 修飾された名前 ----------------

    /// `A.b`・`A.B` を解決する（01-03「修飾された名前の解決」）。`whole` は修飾を含む名前全体の位置。
    pub(super) fn qualified(
        &mut self,
        src: Src,
        qualifier: &Name,
        name: &Name,
        whole: Span,
    ) -> Qualified {
        let Some(upper) = self.lookup_upper(src, &qualifier.text) else {
            let pool = self.upper_names(src, false);
            let mut d = DiagBuilder::new(DiagCode::E0302)
                .arg("name", qualifier.text.clone())
                .primary(qualifier.span);
            if let Some(c) = suggest::candidates(&qualifier.text, pool.iter().map(String::as_str)) {
                d = d.arg("candidates", c).help("similar");
            }
            self.report(d);
            return Qualified::Failed;
        };
        let module = match upper {
            Upper::Effect(_) => {
                self.report_kind(qualifier, text::EFFECT, text::MODULE);
                return Qualified::Failed;
            }
            Upper::UserType(i) => {
                // 利用者の型のモジュールには構成子だけが入る。
                let ctors = self.user_types.get(i).map(|t| &t.ctors);
                let found = ctors.and_then(|c| c.iter().find(|(n, _)| *n == name.text));
                if let Some((_, b)) = found {
                    return Qualified::Found(*b);
                }
                let pool: Vec<String> = ctors
                    .map(|c| c.iter().map(|(n, _)| n.clone()).collect())
                    .unwrap_or_default();
                self.report_no_member(qualifier, name, None, &pool);
                return Qualified::Failed;
            }
            Upper::PreludeType(_, m) => m,
            Upper::Module(_, m) => Some(m),
        };
        // prelude の型のモジュールに構成子は入らない（`Option.Some` は誤り。ADR 0007）。
        if PRELUDE_CTORS.contains(&name.text.as_str()) {
            self.report(
                DiagBuilder::new(DiagCode::E0317)
                    .arg("name", name.text.clone())
                    .arg("module", qualifier.text.clone())
                    .primary(whole)
                    .help("unqualified"),
            );
            return Qualified::Failed;
        }
        if let Some(m) = module
            && let Some(b) = self.prelude_member(src, m, &name.text)
        {
            return Qualified::Found(b);
        }
        let pool = module
            .map(|m| self.prelude_members(src, m))
            .unwrap_or_default();
        self.report_no_member(qualifier, name, module, &pool);
        Qualified::Failed
    }

    /// E0303 を報告する。単位を持たない名前などの特別な修正案があれば、綴りの近い名前は示さない
    /// （01-04「String」、ADR 0043）。
    fn report_no_member(
        &mut self,
        qualifier: &Name,
        name: &Name,
        module: Option<PreludeModule>,
        pool: &[String],
    ) {
        let special = match (module, name.text.as_str()) {
            (Some(PreludeModule::String), "length" | "len" | "size") => Some("length"),
            (Some(PreludeModule::String), "slice" | "substring") => Some("slice"),
            (Some(PreludeModule::String), "indexOf") => Some("index_of"),
            (Some(PreludeModule::Option | PreludeModule::Result), "unwrap" | "expect") => {
                Some("unwrap")
            }
            _ => None,
        };
        let mut d = DiagBuilder::new(DiagCode::E0303)
            .arg("module", qualifier.text.clone())
            .arg("name", name.text.clone())
            .primary(name.span);
        if let Some(key) = special {
            d = d.help(key);
        } else if let Some(c) = suggest::candidates(&name.text, pool.iter().map(String::as_str)) {
            d = d.arg("candidates", c).help("similar");
        }
        self.report(d);
    }

    /// E0304 を報告する。
    pub(super) fn report_kind(&mut self, name: &Name, found: &str, expected: &str) {
        self.report(
            DiagBuilder::new(DiagCode::E0304)
                .arg("name", name.text.clone())
                .arg("found_kind", found)
                .arg("expected_kind", expected)
                .primary(name.span),
        );
    }

    // ---------------- 修飾しない名前 ----------------

    /// 式とパターンの修飾しない大文字の名前を解決する（01-03「修飾しない名前の解決」）。
    pub(super) fn unqualified_upper(&mut self, cx: &Ctx, name: &Name) -> Option<BindingId> {
        let prelude = &self.out.prelude;
        let ctor = match name.text.as_str() {
            "Some" => prelude.some,
            "None" => prelude.none,
            "Ok" => prelude.ok,
            "Err" => prelude.err,
            _ => None,
        };
        if ctor.is_some() {
            return ctor;
        }
        if cx.type_param(&name.text).is_some() {
            self.report_kind(name, text::TYPE_PARAMETER, text::VALUE);
            return None;
        }
        if cx.effect_var(&name.text).is_some() {
            self.report_kind(name, text::EFFECT_VARIABLE, text::VALUE);
            return None;
        }
        if let Some(upper) = self.lookup_upper(cx.src, &name.text) {
            let found = match upper {
                Upper::UserType(_) | Upper::PreludeType(..) => text::TYPE,
                Upper::Module(..) => text::MODULE,
                Upper::Effect(_) => text::EFFECT,
            };
            self.report_kind(name, found, text::VALUE);
            return None;
        }
        // 利用者の型の構成子を修飾せずに書いた場合は、型名で修飾した形を示す。
        let owner = if cx.src == Src::User {
            self.user_types
                .iter()
                .find(|t| t.ctors.iter().any(|(n, _)| *n == name.text))
                .map(|t| t.name.clone())
        } else {
            None
        };
        if let Some(owner) = owner {
            self.report(
                DiagBuilder::new(DiagCode::E0304)
                    .arg("name", name.text.clone())
                    .arg("found_kind", text::CONSTRUCTOR)
                    .arg("expected_kind", text::VALUE)
                    .arg("suggestion", format!("{owner}.{}", name.text))
                    .primary(name.span)
                    .help("qualify"),
            );
            return None;
        }
        self.report_not_found(name, PRELUDE_CTORS.iter().copied());
        None
    }

    /// 式の修飾しない小文字の名前を解決する。局所の束縛、次にトップレベルの関数
    /// （prelude のソースでは補助の関数）の順に引く。
    pub(super) fn unqualified_lower(&mut self, cx: &Ctx, name: &Name) -> Option<BindingId> {
        let top = match cx.src {
            Src::User => &self.user_fns,
            Src::Prelude => &self.helpers,
        };
        if let Some(b) = cx
            .local(&name.text)
            .or_else(|| top.get(&name.text).copied())
        {
            return Some(b);
        }
        let mut pool: Vec<String> = cx.scopes.iter().flat_map(|s| s.keys().cloned()).collect();
        pool.extend(top.keys().cloned());
        self.report_not_found(name, pool.iter().map(String::as_str));
        None
    }

    /// E0301 を報告する。
    fn report_not_found<'n>(&mut self, name: &Name, pool: impl IntoIterator<Item = &'n str>) {
        let mut d = DiagBuilder::new(DiagCode::E0301)
            .arg("name", name.text.clone())
            .primary(name.span);
        if let Some(c) = suggest::candidates(&name.text, pool) {
            d = d.arg("candidates", c).help("similar");
        }
        self.report(d);
    }

    // ---------------- 型と uses ----------------

    /// 名前の型の名前を解決する。型パラメータ、次にトップレベルの型の名前の順に引く（01-03）。
    /// 型引数は呼び出し側が辿る。
    pub(super) fn named_type(&mut self, cx: &Ctx, t: &NamedType) {
        let name = &t.name;
        if let Some(b) = cx.type_param(&name.text) {
            self.out.refs.insert(t.id, b);
            return;
        }
        if cx.effect_var(&name.text).is_some() {
            self.report_effect_as_type(name);
            return;
        }
        match self.lookup_upper(cx.src, &name.text) {
            Some(Upper::Effect(_)) => self.report_effect_as_type(name),
            Some(Upper::Module(..)) => self.report_kind(name, text::MODULE, text::TYPE),
            Some(upper) => {
                if let Some(b) = self.upper_binding(upper) {
                    self.out.refs.insert(t.id, b);
                }
            }
            None => {
                let mut pool: Vec<String> = cx.type_params.iter().map(|(n, _)| n.clone()).collect();
                pool.extend(self.upper_names(cx.src, true));
                self.report_not_found(name, pool.iter().map(String::as_str));
            }
        }
    }

    /// E0314 を報告する（01-06「関数の型とエフェクト」）。
    fn report_effect_as_type(&mut self, name: &Name) {
        self.report(
            DiagBuilder::new(DiagCode::E0314)
                .arg("name", name.text.clone())
                .primary(name.span)
                .help("uses_only"),
        );
    }

    /// `uses` の並びの名前を解決する。エフェクト変数、次に `IO` の順に引く。
    pub(super) fn uses(&mut self, cx: &Ctx, uses: Option<&UsesList>) {
        let Some(uses) = uses else { return };
        for (i, effect) in uses.effects.iter().enumerate() {
            self.effect_ref(cx, effect, i == 0);
        }
    }

    fn effect_ref(&mut self, cx: &Ctx, effect: &EffectRef, first: bool) {
        let name = &effect.name;
        let found =
            cx.effect_var(&name.text)
                .or_else(|| match self.lookup_upper(cx.src, &name.text) {
                    Some(Upper::Effect(b)) => Some(b),
                    _ => None,
                });
        if let Some(b) = found {
            self.out.refs.insert(effect.id, b);
            return;
        }
        // 2 番目以降は、関数の型の後の `uses` が型の並びの次の要素を取り込んだ場合がある（ADR 0047）。
        let d = if first {
            DiagBuilder::new(DiagCode::E0315)
        } else {
            DiagBuilder::new(DiagCode::E0316).help("paren")
        };
        self.report(d.arg("name", name.text.clone()).primary(effect.span));
    }

    /// 束縛が構成子か（構成子のパターンの名前を確かめるため）。
    pub(super) fn is_ctor(&self, b: BindingId) -> bool {
        matches!(
            self.out.bindings.get(b).map(|x| x.kind),
            Some(BindingKind::Ctor { .. })
        )
    }
}
