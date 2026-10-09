//! 型検査の公開の出力と診断で、型クラスの言語規則と脱糖への契約を確かめる（実装プラン F08）。
// 作成時の関門: 辞書の選択・番号・型引数と制約の拒否が観察可能な契約である。
// 選択の優先順位や型の形の検査を誤る退行は F07 のテストでは捕まらない。
// 実際の読み込み・名前解決・型検査をつなぎ、本番の差し込み口を加えない（設計書 07-03）。
// テストの失敗と期待値の直接の比較にだけ panic と添字を使う。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use crate::base::{BindingId, NodeId};
use crate::diag::{DiagCode as C, Diagnostic};
use crate::modules::LoadOutput;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::*;
use crate::typeck::{TypeckOutput, test_support::check_files};
use crate::types::builtin::BuiltinTypeId as B;
use crate::types::*;

fn check(s: &str) -> (LoadOutput, ResolveOutput, TypeckOutput, Vec<Diagnostic>) {
    check_files(&[("main.bnt", s)], false)
}
fn clean(s: &str) -> (LoadOutput, ResolveOutput, TypeckOutput) {
    let (l, r, t, d) = check(s);
    assert!(d.is_empty(), "{d:#?}");
    (l, r, t)
}
fn id(r: &ResolveOutput, name: &str) -> BindingId {
    r.bindings
        .iter()
        .find(|(_, b)| b.name == name && b.module.0 == 0)
        .unwrap()
        .0
}
#[test]
fn standard_library_sources_and_dictionary_contracts() {
    let (l, r, t) = clean("import Benitoite.Trait\n");
    assert_eq!(t.traits.iter().count(), 9);
    let module = l
        .modules
        .modules
        .iter()
        .find(|m| m.name.dotted() == "Benitoite.Trait")
        .unwrap();
    let ast = &l.asts[module.id.0 as usize];
    let impls: Vec<_> = ast
        .decls
        .iter()
        .filter_map(|top| {
            if let Item::Impl(i) = &top.item {
                Some(i)
            } else {
                None
            }
        })
        .collect();
    assert_eq!(impls.len(), 44);
    assert_eq!(t.impls.iter().count(), impls.len());
    for source in impls {
        let imp = t.impls.get(source.id).unwrap();
        let class = t.traits.get(imp.class).unwrap();
        assert_eq!(imp.methods.len(), class.methods.len());
        assert_eq!(imp.supers.len(), class.supers.len());
        for (method, function) in class.methods.iter().zip(&imp.methods) {
            assert!(
                source.fns.iter().any(|f| r.refs.get(f.id) == Some(method)
                    && r.decls.get(f.decl.id) == Some(function))
            );
        }
    }
}

fn visit_block(b: &Block, f: &mut impl FnMut(NodeId, crate::base::Span)) {
    f(b.id, b.span);
    for s in &b.stmts {
        match s {
            Stmt::Expr(e) => visit_expr(e, f),
            Stmt::Bind(b) => {
                f(b.id, b.span);
                visit_pattern(&b.pattern, f);
                visit_expr(&b.value, f);
            }
            Stmt::Error(e) => f(e.id, e.span),
        }
    }
}
fn visit_pattern(p: &Pattern, f: &mut impl FnMut(NodeId, crate::base::Span)) {
    f(p.id(), p.span());
    match p {
        Pattern::Ctor(p) => {
            for p in &p.args {
                visit_pattern(p, f);
            }
        }
        Pattern::Record(p) => {
            for p in &p.fields {
                visit_pattern(&p.pattern, f);
            }
        }
        Pattern::Wildcard(_)
        | Pattern::Var(_)
        | Pattern::Lit(_)
        | Pattern::Unit(_)
        | Pattern::Range(_)
        | Pattern::List(_)
        | Pattern::Error(_) => {}
    }
}
fn visit_expr(e: &Expr, f: &mut impl FnMut(NodeId, crate::base::Span)) {
    f(e.id(), e.span());
    match e {
        Expr::Paren(p) => visit_expr(&p.inner, f),
        Expr::Interp(i) => {
            for s in &i.segments {
                visit_expr(&s.expr, f);
            }
        }
        Expr::List(l) => {
            for e in &l.elems {
                match e {
                    ListElem::Expr(e) => visit_expr(e, f),
                    ListElem::Spread(s) => {
                        f(s.id, s.span);
                        visit_expr(&s.expr, f);
                    }
                }
            }
        }
        Expr::Call(c) => {
            visit_expr(&c.callee, f);
            for a in &c.args {
                match a {
                    Arg::Expr(e) => visit_expr(e, f),
                    Arg::Placeholder(p) => f(p.id, p.span),
                }
            }
        }
        Expr::Record(r) => {
            if let Some(b) = &r.base {
                visit_expr(b, f);
            }
            for field in &r.fields {
                visit_expr(&field.value, f);
            }
        }
        Expr::Binary(b) => {
            visit_expr(&b.lhs, f);
            visit_expr(&b.rhs, f);
        }
        Expr::Unary(u) => visit_expr(&u.operand, f),
        Expr::Pipe(p) => {
            visit_expr(&p.lhs, f);
            visit_expr(&p.rhs, f);
        }
        Expr::Return(r) => visit_expr(&r.value, f),
        Expr::If(i) => {
            visit_expr(&i.cond, f);
            visit_block(&i.then_block, f);
            if let Some(b) = &i.else_branch {
                match b {
                    ElseBranch::Block(b) => visit_block(b, f),
                    ElseBranch::If(i) => visit_expr(&Expr::If(i.as_ref().clone()), f),
                }
            }
        }
        Expr::Match(m) => {
            visit_expr(&m.scrutinee, f);
            for a in &m.arms {
                for p in &a.patterns {
                    visit_pattern(p, f);
                }
                if let Some(g) = &a.guard {
                    visit_expr(g, f);
                }
                visit_block(&a.body, f);
            }
        }
        Expr::Lambda(l) => {
            for p in &l.params {
                f(p.id, p.span);
            }
            visit_block(&l.body, f);
        }
        Expr::Lit(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::Try(_)
        | Expr::Lazy(_)
        | Expr::With(_)
        | Expr::Handle(_)
        | Expr::Resume(_)
        | Expr::Error(_) => {}
    }
}
fn node_at(l: &LoadOutput, start: usize, end: usize) -> NodeId {
    let mut found = None;
    let mut visit = |n: NodeId, span: crate::base::Span| {
        if span.start.0 as usize == start && span.end.0 as usize == end {
            found = Some(n);
        }
    };
    for top in &l.asts[0].decls {
        match &top.item {
            Item::Fn(f) => {
                if let Some(b) = &f.body {
                    visit_block(b, &mut visit);
                }
            }
            Item::Impl(i) => {
                for f in &i.fns {
                    if let Some(b) = &f.decl.body {
                        visit_block(b, &mut visit);
                    }
                }
            }
            Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Error(_) => {}
        }
    }
    found.expect("missing expression in AST")
}
fn dict<'a>(
    l: &LoadOutput,
    t: &'a TypeckOutput,
    source: &str,
    name: &str,
    occurrence: usize,
) -> &'a Vec<DictExpr> {
    let start = source.match_indices(name).nth(occurrence).unwrap().0;
    t.dicts
        .get(node_at(l, start, start + name.len()))
        .expect("missing dictionary")
}
fn impl_for(t: &TypeckOutput, class: BindingId, con: TyCon) -> NodeId {
    t.impls
        .iter()
        .find(|(_, i)| i.class == class && i.target_con == con)
        .unwrap_or_else(|| {
            panic!(
                "missing implementation for {class:?}, {con:?}: {:?}",
                t.impls
            )
        })
        .0
}
fn concrete(impl_decl: NodeId) -> DictExpr {
    DictExpr::Impl {
        impl_decl,
        type_args: vec![],
        args: vec![],
    }
}
#[test]
fn show_example_records_nested_dictionaries_and_method_values() {
    let s = include_str!("../../../testdata/traits/show.bnt");
    let (l, r, t) = clean(s);
    let show = id(&r, "Show");
    let person = id(&r, "Person");
    let p = impl_for(&t, show, TyCon::Adt(person));
    let option = impl_for(
        &t,
        show,
        TyCon::Adt(r.stdlib("Benitoite.Option.Option").unwrap()),
    );
    let param = DictExpr::Param {
        constraint: 0,
        supers: vec![],
    };
    assert_eq!(
        dict(&l, &t, s, "Show.show", 0),
        std::slice::from_ref(&param)
    );
    assert_eq!(dict(&l, &t, s, "Show.show", 1), &[param]);
    assert_eq!(dict(&l, &t, s, "describeAll", 1), &[concrete(p)]);
    assert_eq!(
        dict(&l, &t, s, "describeAll", 2),
        &[DictExpr::Impl {
            impl_decl: option,
            type_args: vec![TypeArg::Ty(Ty::Con(TyCon::Adt(person), vec![]))],
            args: vec![concrete(p)],
        }]
    );
}
#[test]
fn supertraits_and_result_annotations_select_dictionaries() {
    let s = include_str!("../../../testdata/traits/combine-all.bnt");
    let (l, r, t) = clean(s);
    let semigroup = r.stdlib("Benitoite.Trait.Semigroup").unwrap();
    let monoid = r.stdlib("Benitoite.Trait.Monoid").unwrap();
    assert_eq!(
        dict(&l, &t, s, "Trait.Semigroup.combine", 0),
        &[DictExpr::Param {
            constraint: 0,
            supers: vec![semigroup]
        }]
    );
    let mono_string = impl_for(&t, monoid, TyCon::Builtin(B::STRING));
    assert_eq!(
        dict(&l, &t, s, "Trait.Monoid.empty", 1),
        &[concrete(mono_string)]
    );
    assert_eq!(
        t.impls.get(mono_string).unwrap().supers,
        [concrete(impl_for(&t, semigroup, TyCon::Builtin(B::STRING)))]
    );
    let mono_list = impl_for(&t, monoid, TyCon::Builtin(B::LIST));
    let semi_list = impl_for(&t, semigroup, TyCon::Builtin(B::LIST));
    assert_eq!(
        t.impls.get(mono_list).unwrap().supers,
        [DictExpr::Impl {
            impl_decl: semi_list,
            type_args: vec![TypeArg::Ty(Ty::Param(0))],
            args: vec![],
        }]
    );
}
#[test]
fn higher_kinded_methods_select_heads_and_keep_method_arguments() {
    let s = include_str!("../../../testdata/traits/functor.bnt");
    let (l, r, t) = clean(s);
    let functor = r.stdlib("Benitoite.Trait.Functor").unwrap();
    for (n, con) in [
        (0, TyCon::Adt(r.stdlib("Benitoite.Option.Option").unwrap())),
        (1, TyCon::Builtin(B::LIST)),
    ] {
        assert_eq!(
            dict(&l, &t, s, "Trait.Functor.map", n),
            &[concrete(impl_for(&t, functor, con))]
        );
        let start = s.match_indices("Trait.Functor.map").nth(n).unwrap().0;
        assert_eq!(
            t.type_args
                .get(node_at(&l, start, start + "Trait.Functor.map".len()))
                .unwrap()
                .tys,
            [
                TypeArg::Head(TyHead::Con(con)),
                TypeArg::Ty(Ty::Con(TyCon::Builtin(B::INTEGER), vec![])),
                TypeArg::Ty(Ty::Con(TyCon::Builtin(B::STRING), vec![])),
            ]
        );
    }
}
#[test]
fn builtin_constraints_and_standard_trait_examples() {
    for s in [
        include_str!("../../../testdata/traits/single.bnt"),
        include_str!("../../../testdata/traits/standard-traits.bnt"),
    ] {
        let (_, _, _, d) = check_files(&[("main.bnt", s)], true);
        assert!(d.is_empty(), "{d:#?}");
    }
    clean(
        "function same[T: equality](a: T, b: T) -> Boolean\n return a = b\nend function\nfunction f[T: key](a: T) -> Boolean\n return same(a, a)\nend function\n",
    );
    clean("function f() -> Unit\n bind _ <- List.sort([1, 2])\nend function\n");
}
fn expect(s: &str, expected: &[(C, &str, usize)]) -> Vec<Diagnostic> {
    let (l, _, _, d) = check(s);
    assert_eq!(d.len(), expected.len(), "{s}\n{d:#?}");
    for (diag, (code, marker, nth)) in d.iter().zip(expected) {
        assert_eq!(diag.code, Some(*code), "{s}\n{d:#?}");
        let span = diag.primary.as_ref().unwrap().span;
        assert_eq!(l.sources.get(span.file).unwrap().name(), "main.bnt");
        assert_eq!(
            span.start.0 as usize,
            s.match_indices(marker).nth(*nth).unwrap().0,
            "{s}\n{d:#?}"
        );
        assert!(
            !diag.message.contains('{'),
            "unfilled diagnostic: {diag:#?}"
        );
    }
    d
}
const SHOW: &str = "trait Show[T]\n function show(x: T) -> String\nend trait\n";
#[test]
fn declaration_and_implementation_rules_report_codes_and_positions() {
    for (suffix, code, marker) in [
        (
            "implement Show[Option[Integer]]\n function show(x: Option[Integer]) -> String return \"\" end function\nend implement\n",
            C::E0712,
            "Option[Integer]",
        ),
        (
            "implement Show[function() -> Unit]\n function show(x: function() -> Unit) -> String return \"\" end function\nend implement\n",
            C::E0712,
            "function() -> Unit",
        ),
        (
            "implement[T, U] Show[Option[T]]\n function show(x: Option[T]) -> String return \"\" end function\nend implement\n",
            C::E0713,
            "U]",
        ),
        (
            "implement[T] Show[Pair[T, T]]\n function show(x: Pair[T, T]) -> String return \"\" end function\nend implement\n",
            C::E0712,
            "Pair[T, T]",
        ),
    ] {
        expect(&format!("{SHOW}{suffix}"), &[(code, marker, 0)]);
    }
    expect("trait Empty[T]\nend trait\n", &[(C::E0710, "Empty", 0)]);
    expect(
        "trait Bad[T]\n function f() -> Integer\nend trait\n",
        &[(C::E0709, "f()", 0)],
    );
    for (s, marker) in [
        ("data Box[T: equality]\n Box(T)\nend data\n", "equality"),
        ("data Box[T: Show]\n Box(T)\nend data\n", "Show"),
        (
            "function f[F[_]: equality](x: F[Integer]) -> Unit\nend function\n",
            "equality",
        ),
        ("record Box[T: key]\n value: T\nend record\n", "key"),
        ("type Box[T: key] = Option[T]\n", "key"),
    ] {
        expect(s, &[(C::E0425, marker, 0)]);
    }
    expect(
        "trait Container[F[_]]\n function f[A](x: F[A]) -> F[A]\nend trait\nfunction bad[T: Container](x: T) -> Unit\nend function\n",
        &[(C::E0714, "Container]", 0)],
    );
    expect(
        "trait Container[F[_]]\n function f[A](x: F[A]) -> F[A]\nend trait\nfunction bad[F[_,_]: Container](x: F[Integer, String]) -> Unit\nend function\n",
        &[(C::E0427, "Container]", 0)],
    );
    expect(
        "trait A[T]\n function f(x: T) -> T\nend trait\ntrait B[F[_]: A]\n function f[T](x: F[T]) -> F[T]\nend trait\n",
        &[(C::E0714, "A]", 0)],
    );
    let functor = "trait Functor[F[_]]\n function map[A, B](x: F[A], f: function(A) -> B) -> F[B]\nend trait\n";
    for (target, code) in [("Integer", C::E0714), ("Result", C::E0427)] {
        let s = format!(
            "{functor}implement Functor[{target}]\n function map[A, B](x: Option[A], f: function(A) -> B) -> Option[B] return Option.map(x, f) end function\nend implement\n"
        );
        expect(&s, &[(code, target, 0)]);
    }
}
#[test]
fn missing_or_unknown_dictionary_and_parameter_fixes() {
    let s = format!(
        "{SHOW}function f() -> String\n return Show.show(lambda() () end lambda)\nend function\n"
    );
    expect(&s, &[(C::E0705, "Show.show", 0)]);
    let s = format!("{SHOW}function f[T](x: T) -> String\n return Show.show(x)\nend function\n");
    let d = expect(&s, &[(C::E0706, "Show.show", 0)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, ": Show");
    assert_eq!(
        d[0].helps[0].edits[0].span.start.0 as usize,
        s.find("T](").unwrap() + 1
    );
    let s = "import Benitoite.Trait\nfunction f() -> Unit\n bind _ <- Trait.Monoid.empty()\nend function\n";
    let d = expect(s, &[(C::E0407, "Trait.Monoid.empty", 0)]);
    assert!(!d[0].helps.is_empty());
    expect(
        "import Benitoite.Trait\nfunction f() -> Unit\n bind _ <- Trait.Applicative.pure(1)\nend function\n",
        &[(C::E0407, "Trait.Applicative.pure", 0)],
    );
}
#[test]
fn coherence_and_method_contracts() {
    let first = "implement Show[Integer]\n function show(x: Integer) -> String return \"\" end function\nend implement\n";
    let s = format!("{SHOW}{first}{first}");
    let d = expect(&s, &[(C::E0702, "implement Show[", 1)]);
    assert_eq!(
        d[0].secondary[0].span.start.0 as usize,
        s.find("implement").unwrap()
    );
    let s = "import Benitoite.Trait\nimplement Trait.Show[Integer]\n function show(x: Integer) -> String return \"\" end function\nend implement\n";
    let (l, _, _, d) = check(s);
    assert_eq!(
        d.iter().map(|d| d.code).collect::<Vec<_>>(),
        [Some(C::E0701), Some(C::E0702)]
    );
    assert_eq!(
        d[0].primary.as_ref().unwrap().span.start.0 as usize,
        s.find("implement").unwrap()
    );
    let overlap = d[1].primary.as_ref().unwrap().span;
    assert_eq!(
        l.sources.get(overlap.file).unwrap().name(),
        "<benitoite>/Trait.bnt"
    );
    assert_eq!(d[1].secondary[0].span, d[0].primary.as_ref().unwrap().span);
    let (l, _, _, d) = check_files(
        &[
            (
                "main.bnt",
                "import Classes\nimport Types\nimplement Classes.Show[Types.X]\n function show(x: Types.X) -> String return \"\" end function\nend implement\n",
            ),
            (
                "Classes.bnt",
                "public trait Show[T]\n function show(x: T) -> String\nend trait\n",
            ),
            ("Types.bnt", "public data X\n X\nend data\n"),
        ],
        false,
    );
    assert_eq!(d.len(), 1, "{d:#?}");
    assert_eq!(d[0].code, Some(C::E0701));
    let span = d[0].primary.as_ref().unwrap().span;
    assert_eq!(
        l.sources.get(span.file).unwrap().line_col(span.start).line,
        3
    );
    let s = "trait Semigroup[T]\n function combine(x: T, y: T) -> T\nend trait\ntrait Monoid[T: Semigroup]\n function empty() -> T\nend trait\ndata X\n X\nend data\nimplement Monoid[X]\n function empty() -> X return X.X end function\nend implement\n";
    expect(s, &[(C::E0704, "implement", 0)]);
    let s = format!(
        "{SHOW}implement Show[Integer]\n function show(x: Integer) -> Integer return x end function\nend implement\nfunction f() -> Unit\n bind _ <- Show.show(1)\n bind _ <- Show.show(2)\nend function\n"
    );
    expect(&s, &[(C::E0711, "show(x: Integer)", 0)]);
    clean(
        "import Benitoite.Unofficial.IO.Console\ntrait Act[T]\n function act(x: T) -> T uses Console.Write\nend trait\nimplement Act[Integer]\n function act(x: Integer) -> Integer return x end function\nend implement\n",
    );
}
#[test]
fn builtin_parameter_bounds_and_strength() {
    let s = "function same[T](a: T, b: T) -> Boolean\n return a = b\nend function\n";
    let d = expect(s, &[(C::E0406, "a = b", 0)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, ": equality");
    let s = "function same[T: equality](a: T, b: T) -> Boolean return a = b end function\nfunction f[T](a: T) -> Boolean\n return same(a, a)\nend function\n";
    expect(s, &[(C::E0424, "same(a,", 0)]);
    let s = "function key[T: key](x: T) -> T return x end function\nfunction f[T: equality](x: T) -> T\n return key(x)\nend function\n";
    let d = expect(s, &[(C::E0424, "key(x)", 0)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, " & key");
    expect(
        "function f() -> Unit\n bind _ <- List.sort([true])\nend function\n",
        &[(C::E0405, "List.sort", 0)],
    );
    let s = include_str!("../../../testdata/traits/single.bnt").replace("K: key", "K");
    let d = expect(&s, &[(C::E0424, "Map.fromList", 0)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, ": key");
    expect(
        "function f[T](a: T, b: T) -> Boolean\n return a < b\nend function\n",
        &[(C::E0405, "a < b", 0)],
    );
}

#[test]
fn implementation_and_method_constraints_keep_separate_indices() {
    let s = "trait Show[T]\n function show(x: T) -> String\n function render[U: Show](x: T, y: U) -> String\nend trait\nimplement[T: Show] Show[List[T]]\n function render[U: Show](x: List[T], y: U) -> String\n  bind _ <- List.map(x, Show.show)\n  return Show.show(y)\n end function\n function show(x: List[T]) -> String\n  return String.join(List.map(x, Show.show), \",\")\n end function\nend implement\n";
    let (l, r, t) = clean(s);
    assert_eq!(
        dict(&l, &t, s, "Show.show", 0),
        &[DictExpr::Param {
            constraint: 0,
            supers: vec![]
        }]
    );
    assert_eq!(
        dict(&l, &t, s, "Show.show", 1),
        &[DictExpr::Param {
            constraint: 1,
            supers: vec![]
        }]
    );
    assert_eq!(
        dict(&l, &t, s, "Show.show", 2),
        &[DictExpr::Param {
            constraint: 0,
            supers: vec![]
        }]
    );
    let show = id(&r, "Show");
    let imp = t
        .impls
        .get(impl_for(&t, show, TyCon::Builtin(B::LIST)))
        .unwrap();
    let names: Vec<_> = imp
        .methods
        .iter()
        .map(|id| r.bindings.get(*id).unwrap().name.as_str())
        .collect();
    assert_eq!(names, ["show", "render"]);
    let render = t.decl_types.get(imp.methods[1]).unwrap();
    assert_eq!(
        render.class_constraints,
        [
            ClassConstraint {
                param: 0,
                class: show
            },
            ClassConstraint {
                param: 1,
                class: show
            }
        ]
    );
}

#[test]
fn parameter_dictionary_selection_prefers_exact_shortest_then_first() {
    let declarations = "trait Base[T]\n function get(x: T) -> T\nend trait\ntrait Near[T: Base]\n function near(x: T) -> T\nend trait\ntrait Far[T: Near]\n function far(x: T) -> T\nend trait\ntrait Other[T: Base]\n function other(x: T) -> T\nend trait\n";
    for (bounds, index) in [
        ("Far & Near & Other & Base", 3),
        ("Far & Near & Other", 1),
        ("Other & Near", 0),
    ] {
        let s = format!(
            "{declarations}function f[T: {bounds}](x: T) -> T\n return Base.get(x)\nend function\n"
        );
        let (l, r, t) = clean(&s);
        let supers = if index == 3 {
            vec![]
        } else {
            vec![id(&r, "Base")]
        };
        assert_eq!(
            dict(&l, &t, &s, "Base.get", 0),
            &[DictExpr::Param {
                constraint: index,
                supers
            }]
        );
    }
}

#[test]
fn constructor_parameter_constraint_fixes_preserve_the_kind_and_qualification() {
    let s = "import Benitoite.Trait\nfunction f[F[_], A](xs: F[A]) -> F[A]\n return Trait.Functor.map(xs, lambda(x) return x end lambda)\nend function\n";
    let d = expect(s, &[(C::E0706, "Trait.Functor.map", 0)]);
    let edit = &d[0].helps[0].edits[0];
    assert_eq!(edit.replacement, ": Trait.Functor");
    assert_eq!(
        edit.span.start.0 as usize,
        s.find("F[_]").unwrap() + "F[_]".len()
    );
    let mut fixed = s.to_owned();
    fixed.replace_range(
        edit.span.start.0 as usize..edit.span.end.0 as usize,
        &edit.replacement,
    );
    clean(&fixed);
}

#[test]
fn selected_implementations_require_their_builtin_bounds() {
    // 辞書の解決でも実装の組み込みの制約を満たす必要がある。普通の関数の具体化だけを
    // 確かめるテストでは、辞書を通じて equality を満たさない型が入る退行を捕まえられない。
    let declarations = format!(
        "{SHOW}implement[T: equality] Show[Option[T]]\n function show(x: Option[T]) -> String return \"\" end function\nend implement\n"
    );
    clean(&format!(
        "{declarations}function f[T: key](x: T) -> String\n return Show.show(Option.Some(x))\nend function\n"
    ));
    let s = format!(
        "{declarations}function f[T](x: T) -> String\n return Show.show(Option.Some(x))\nend function\n"
    );
    let d = expect(&s, &[(C::E0424, "Show.show", 0)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, ": equality");
    let s = format!(
        "{declarations}function f() -> String\n return Show.show(Option.Some(lambda() () end lambda))\nend function\n"
    );
    expect(&s, &[(C::E0406, "Show.show", 0)]);
    let s = format!(
        "{declarations}function f() -> String\n return Show.show(Option.None)\nend function\n"
    );
    expect(&s, &[(C::E0407, "Show.show", 0)]);
    let declarations = declarations.replace("T: equality", "T: key");
    let s = format!(
        "{declarations}function f() -> String\n return Show.show(Option.Some(1.0))\nend function\n"
    );
    expect(&s, &[(C::E0423, "Show.show", 0)]);
    let declarations = "trait Base[T]\n function get(x: T) -> T\nend trait\ntrait Derived[T: Base]\n function derived(x: T) -> T\nend trait\nimplement[T: key] Base[Option[T]]\n function get(x: Option[T]) -> Option[T] return x end function\nend implement\n";
    let suffix = "implement[T: key] Derived[Option[T]]\n function derived(x: Option[T]) -> Option[T] return x end function\nend implement\n";
    clean(&format!("{declarations}{suffix}"));
    expect(
        &format!("{declarations}{}", suffix.replace("T: key", "T: equality")),
        &[(C::E0704, "implement[T:", 1)],
    );
}

#[test]
fn invalid_declarations_do_not_produce_secondary_errors() {
    let s = format!(
        "{SHOW}implement Show[Unit]\n function show(x: Unit) -> String return \"\" end function\nend implement\nimplement Show[function() -> Unit]\n function show(x: function() -> Unit) -> String return \"\" end function\nend implement\n"
    );
    expect(&s, &[(C::E0712, "function() -> Unit", 0)]);
    let s = "trait Base[T]\n function get(x: T) -> T\nend trait\ntrait Empty[T: Base]\nend trait\nimplement Empty[Integer]\nend implement\n";
    expect(s, &[(C::E0710, "Empty", 0)]);
    expect(
        "trait Invalid[T]\n function get() -> Option\nend trait\n",
        &[(C::E0426, "Option", 0)],
    );
}

#[test]
fn permuted_implementation_arguments_and_method_dictionaries_keep_their_order() {
    let s = format!(
        "{SHOW}trait Render[T]\n function render[U: Show](x: T, y: U) -> String\nend trait\nimplement[A: Show, B: Show] Render[Pair[B, A]]\n function render[U: Show](x: Pair[B, A], y: U) -> String return Show.show(y) end function\nend implement\nimplement Show[Integer]\n function show(x: Integer) -> String return \"integer\" end function\nend implement\nimplement Show[String]\n function show(x: String) -> String return x end function\nend implement\nfunction f() -> String\n return Render.render(Pair(1, \"a\"), 2)\nend function\n"
    );
    let (l, r, t) = clean(&s);
    let show = id(&r, "Show");
    let integer = concrete(impl_for(&t, show, TyCon::Builtin(B::INTEGER)));
    let string = concrete(impl_for(&t, show, TyCon::Builtin(B::STRING)));
    let pair = t
        .adts
        .adts
        .iter()
        .find(|(_, a)| a.name == "Pair")
        .unwrap()
        .0;
    let render = impl_for(&t, id(&r, "Render"), TyCon::Adt(pair));
    assert_eq!(
        dict(&l, &t, &s, "Render.render", 0),
        &[
            DictExpr::Impl {
                impl_decl: render,
                type_args: vec![
                    TypeArg::Ty(Ty::Con(TyCon::Builtin(B::STRING), vec![])),
                    TypeArg::Ty(Ty::Con(TyCon::Builtin(B::INTEGER), vec![])),
                ],
                args: vec![string, integer.clone()],
            },
            integer,
        ]
    );
}
