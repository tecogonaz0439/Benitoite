//! エフェクトの規則・診断と後続の段に渡す表を型検査の入口で確かめる（実装プラン F09）。
// テストの失敗は panic で表し、AST と期待した診断の位置を直接参照する。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use crate::base::BindingId;
use crate::diag::{DiagCode as C, Diagnostic};
use crate::modules::LoadOutput;
use crate::resolve::{BindingKind, ResolveOutput};
use crate::syntax::ast::*;
use crate::typeck::{TryKind, TypeckOutput, test_support::check_files, typecheck};
use crate::types::builtin::{BuiltinTypeId as B, find_builtin_effect};
use crate::types::{EffectName, Ty, TyCon};

const LOG: &str = include_str!("../../../testdata/handlers/first-release-log.bnt");
const PARSE: &str = include_str!("../../../testdata/handlers/first-release-parse-all.bnt");
const PORT: &str = include_str!("../../../testdata/handlers/first-release-port.bnt");
const CELLS: &str = include_str!("../../../testdata/effects/first-release-cells.bnt");
const WITH: &str = include_str!("../../../testdata/effects/first-release-with.bnt");
const TRY: &str = include_str!("../../../testdata/effects/first-release-try.bnt");

fn check(s: &str) -> (LoadOutput, ResolveOutput, TypeckOutput, Vec<Diagnostic>) {
    check_files(&[("main.bnt", s)], false)
}
fn clean(s: &str) -> (LoadOutput, ResolveOutput, TypeckOutput) {
    let (l, r, t, d) = check(s);
    assert!(d.is_empty(), "{s}\n{d:#?}");
    (l, r, t)
}
fn basic(b: B) -> Ty {
    Ty::Con(TyCon::Builtin(b), vec![])
}
fn binding(r: &ResolveOutput, name: &str) -> BindingId {
    r.bindings
        .iter()
        .find(|(_, b)| b.module.0 == 0 && b.name == name)
        .unwrap()
        .0
}
fn function<'a>(l: &'a LoadOutput, name: &str) -> &'a FnDecl {
    l.asts[0]
        .decls
        .iter()
        .find_map(|d| match &d.item {
            Item::Fn(f) if f.name.text == name => Some(f.as_ref()),
            Item::Fn(_)
            | Item::Const(_)
            | Item::Data(_)
            | Item::Alias(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Effect(_)
            | Item::Impl(_)
            | Item::Error(_) => None,
        })
        .unwrap()
}
fn handle<'a>(l: &'a LoadOutput, name: &str) -> &'a HandleExpr {
    function(l, name)
        .body
        .as_ref()
        .unwrap()
        .stmts
        .iter()
        .find_map(|s| {
            let e = match s {
                Stmt::Bind(b) => &b.value,
                Stmt::Expr(e) => e,
                _ => return None,
            };
            let e = if let Expr::Return(r) = e {
                r.value.as_ref()
            } else {
                e
            };
            match e {
                Expr::Handle(h) => Some(h),
                Expr::Lit(_)
                | Expr::Interp(_)
                | Expr::Name(_)
                | Expr::Unit(_)
                | Expr::Paren(_)
                | Expr::List(_)
                | Expr::Call(_)
                | Expr::Record(_)
                | Expr::Binary(_)
                | Expr::Unary(_)
                | Expr::Pipe(_)
                | Expr::If(_)
                | Expr::Match(_)
                | Expr::Lambda(_)
                | Expr::Return(_)
                | Expr::Try(_)
                | Expr::Lazy(_)
                | Expr::With(_)
                | Expr::Resume(_)
                | Expr::Error(_) => None,
            }
        })
        .unwrap()
}
fn expect(s: &str, expected: &[(C, &str, usize)]) -> Vec<Diagnostic> {
    let (l, _, _, d) = check(s);
    assert_eq!(d.len(), expected.len(), "{s}\n{d:#?}");
    for (d, (code, text, occurrence)) in d.iter().zip(expected) {
        assert_eq!(d.code, Some(*code), "{s}\n{d:#?}");
        let span = d.primary.as_ref().unwrap().span;
        assert_eq!(span.file, l.asts[0].span.file);
        assert_eq!(
            span.start.0 as usize,
            s.match_indices(text).nth(*occurrence).unwrap().0,
            "{s}\n{d:#?}"
        );
    }
    d
}

#[test]
fn specification_examples_and_output_tables() {
    for s in [LOG, PARSE, PORT, CELLS, WITH, TRY] {
        let (_, _, _, d) = check_files(&[("main.bnt", s)], true);
        assert!(d.is_empty(), "{s}\n{d:#?}");
    }
    let (l, r, t) = clean(LOG);
    let h = handle(&l, "main");
    let info = t.handlers.get(h.id).unwrap();
    assert_eq!(info.clauses[0].op, binding(&r, "write"));
    assert!(info.clauses[0].tail_resumptive);
    assert_eq!(info.handled.names, [EffectName::User(binding(&r, "Log"))]);
    assert_eq!(
        t.expr_types.get(h.clauses[0].params[0].id),
        Some(&basic(B::STRING))
    );
    let (l, r, t) = clean(PARSE);
    assert!(!t.handlers.get(handle(&l, "parseAll").id).unwrap().clauses[0].tail_resumptive);
    assert!(
        t.decl_types
            .get(binding(&r, "parseAll"))
            .unwrap()
            .effects
            .names
            .is_empty()
    );
    let (l, _, t) = clean(PORT);
    assert!(
        t.handlers
            .get(handle(&l, "portIsRead").id)
            .unwrap()
            .handled
            .names
            .is_empty()
    );
    let (l, r, t) = clean(TRY);
    // 標準ライブラリ内の try が増えても、仕様例の三つの出力を確かめる（実装プラン L00）。
    let tries: Vec<_> = ["parseConfig", "loadConfig"]
        .into_iter()
        .flat_map(|name| &function(&l, name).body.as_ref().unwrap().stmts)
        .filter_map(|stmt| {
            if let Stmt::Bind(bind) = stmt
                && let Expr::Try(expr) = &bind.value
            {
                Some(t.try_kinds.get(expr.id).unwrap())
            } else {
                None
            }
        })
        .collect();
    assert_eq!(tries.len(), 3);
    let ret = &t.decl_types.get(binding(&r, "loadConfig")).unwrap().ret;
    assert!(tries.iter().all(|info| info.ret == *ret));
    assert!(tries.iter().all(|info| info.kind == TryKind::Result));
    let (l, _, t) = clean(WITH);
    let Stmt::Expr(Expr::With(w)) = &function(&l, "firstLine").body.as_ref().unwrap().stmts[0]
    else {
        panic!()
    };
    assert_eq!(
        t.expr_types.get(w.binds[0].id),
        Some(&Ty::Con(
            TyCon::Builtin(
                crate::types::builtin::find_builtin_type(&["IO", "File"], "Reader").unwrap()
            ),
            vec![]
        ))
    );
}

#[test]
fn all_standard_library_sources_are_checked_without_diagnostics() {
    let mut source = crate::prelude::STDLIB
        .iter()
        .filter(|m| !m.prelude)
        .map(|m| {
            format!(
                "import Benitoite.{}{}\n",
                if m.unofficial { "Unofficial." } else { "" },
                m.path.join(".")
            )
        })
        .collect::<String>();
    source.push_str("function main() -> Unit\n ()\nend function\n");
    let (_, _, _, d) = check_files(&[("main.bnt", &source)], true);
    assert!(d.is_empty(), "{d:#?}");
}

#[test]
fn clause_parameters_include_wildcards_and_rigid_types() {
    let logging = "public effect Log\n function write(message: String) -> Unit\nend effect\n";
    for param in ["message", "_"] {
        let source = format!(
            "import Logging\nfunction f() -> Unit\n handle Logging.write(\"a\") with case Logging.write({param}) -> resume(()) end handle\nend function\n"
        );
        let (l, r, t, d) = check_files(&[("main.bnt", &source), ("Logging.bnt", logging)], false);
        assert!(d.is_empty(), "{d:#?}");
        let h = handle(&l, "f");
        assert_eq!(
            t.expr_types.get(h.clauses[0].params[0].id),
            Some(&basic(B::STRING))
        );
        assert_eq!(
            t.handlers.get(h.id).unwrap().clauses[0].op,
            *r.refs.get(h.clauses[0].op.id).unwrap()
        );
    }
    let source = "effect Identity\n function identity[T](value: T) -> T\nend effect\nfunction f() -> Integer\n return handle identity(1) with case identity(value) -> resume(value) end handle\nend function\n";
    let (l, _, t) = clean(source);
    let h = handle(&l, "f");
    assert_eq!(
        t.expr_types.get(h.clauses[0].params[0].id),
        Some(&Ty::Rigid {
            clause: h.clauses[0].id,
            index: 0
        })
    );
    let source = "effect Abort\n function fail[T](message: String) -> T\nend effect\nfunction f() -> Integer\n return handle fail(\"bad\") with case fail(message) -> resume(message) end handle\nend function\n";
    expect(source, &[(C::E0401, "message)", 1)]);
}

#[test]
fn declared_operation_bounds_are_available_in_clauses() {
    let same = "effect Compare\n function same[T: equality](a: T, b: T) -> Boolean\nend effect\nfunction f() -> Boolean\n return handle same(1, 2) with case same(a, b) -> resume(a = b) end handle\nend function\n";
    clean(same);
    let d = expect(&same.replace("T: equality", "T"), &[(C::E0406, "a = b", 0)]);
    assert!(d[0].message.contains("T"));
    clean(
        "import Benitoite.Map\neffect Keys\n function keyOf[T: key](value: T) -> T\nend effect\nfunction f() -> Integer\n return handle keyOf(1) with case keyOf(value) ->\n bind m <- Map.fromList([Pair(value, ())])\n bind _ <- Map.toList(m)\n resume(value)\n end handle\nend function\n",
    );
}

#[test]
fn invalid_clauses_and_effects_have_precise_diagnostics() {
    let source = "function ordinary() -> Unit\n ()\nend function\nfunction f() -> Unit\n handle () with case ordinary() -> () end handle\nend function\n";
    expect(source, &[(C::E0507, "ordinary()", 1)]);
    let source = "function f() -> Unit\n handle () with case Reference.set(r, v) -> () end handle\nend function\n";
    let d = expect(source, &[(C::E0507, "Reference.set", 0)]);
    assert!(d[0].notes.iter().any(|n| n.contains("State")));
    let source = "effect Ping\n function ping() -> Unit\nend effect\nfunction f() -> Unit\n handle ping() with\n case ping() -> resume(())\n case ping() -> resume(())\n end handle\nend function\n";
    let d = expect(source, &[(C::E0508, "ping()", 3)]);
    assert_eq!(
        d[0].secondary[0].span.start.0 as usize,
        source.match_indices("ping()").nth(2).unwrap().0
    );
    expect(
        &source.replace(
            "case ping() -> resume(())\n case ping()",
            "case ping(x) -> resume(())\n case ping()",
        ),
        &[(C::E0402, "ping(x)", 0), (C::E0508, "ping()", 2)],
    );
    expect(
        &PORT.replace(
            "function portIsRead() -> Boolean uses File.Read",
            "function portIsRead() -> Boolean",
        ),
        &[(C::E0501, "readPort(\"app.conf\")", 0)],
    );
    expect(
        &LOG.replace(
            "function main() -> Unit uses Console.Write",
            "function main() -> Unit",
        ),
        &[(C::E0501, "Console.writeLine(message)", 0)],
    );
    expect(
        &LOG.replace("-> Integer uses Log", "-> Integer"),
        &[(C::E0501, "write(\"item:", 0)],
    );
    // 宣言したエフェクト変数は、すべての Log の節を揃えても除かれない（01-06）。
    clean(
        "effect Log\n function write() -> Unit\nend effect\nfunction f[effect E](act: function() -> Unit uses E) -> Unit uses E\n handle act() with case write() -> resume(()) end handle\nend function\n",
    );
}

#[test]
fn lazy_resources_and_taskgroup_placement() {
    let (l, _, t) =
        clean("function f() -> Lazy[Integer]\n return lazy 1 + 2 end lazy\nend function\n");
    let Stmt::Expr(Expr::Return(e)) = &function(&l, "f").body.as_ref().unwrap().stmts[0] else {
        panic!()
    };
    assert_eq!(
        t.expr_types.get(e.value.id()),
        Some(&Ty::Con(TyCon::Builtin(B::LAZY), vec![basic(B::INTEGER)]))
    );
    let source = "import Benitoite.Unofficial.IO.Console\nfunction f() -> Lazy[Unit]\n return lazy Console.writeLine(\"a\") end lazy\nend function\n";
    let d = expect(source, &[(C::E0503, "Console.writeLine", 0)]);
    assert!(d[0].helps[0].message.contains("lambda"));
    expect(
        &WITH.replace("File.Read, State", "File.Read"),
        &[(C::E0501, "with reader", 0)],
    );
    expect(
        "function f() -> Unit uses State\n with x = 1 do () end with\nend function\n",
        &[(C::E0443, "1 do", 0)],
    );
    clean(
        "function f() -> Unit uses State\n with g = TaskGroup.open() do\n bind t <- TaskGroup.spawn(g, lambda() return 1 end lambda)\n bind _ <- Task.await(t)\n end with\nend function\n",
    );
    for expr in ["TaskGroup.open()", "TaskGroup.open", "(TaskGroup.open())"] {
        let source = format!("function f() -> Unit uses State\n bind _ <- {expr}\nend function\n");
        let d = expect(&source, &[(C::E0505, "TaskGroup.open", 0)]);
        assert!(d[0].helps[0].message.contains("with"));
    }
    expect(
        "function f() -> Unit uses State\n bind _ <- List.map([()], TaskGroup.open)\nend function\n",
        &[
            (C::E0505, "TaskGroup.open", 0),
            (C::E0402, "TaskGroup.open", 0),
        ],
    );
    // with の許可は、束縛の式の中にある別の参照には及ばない。
    expect(
        "function f() -> Unit uses State\n with g = TaskGroup.open(TaskGroup.open) do () end with\nend function\n",
        &[
            (C::E0505, "TaskGroup.open", 1),
            (C::E0402, "TaskGroup.open(Task", 0),
        ],
    );
    expect(
        &CELLS.replace("uses State", ""),
        &[(C::E0501, "Reference.new", 0)],
    );
}

#[test]
fn try_infers_return_types_and_reports_incompatible_types() {
    let option = "function f(s: String) -> Option[Integer]\n bind n <- try Integer.parse(s)\n return Option.Some(n)\nend function\n";
    let (_, r, t) = clean(option);
    let info = t.try_kinds.iter().next().unwrap().1;
    assert_eq!(info.kind, TryKind::Option);
    assert_eq!(info.ret, t.decl_types.get(binding(&r, "f")).unwrap().ret);
    let source = "function f() -> Unit\n bind action <- lambda(x: Result[Integer, String])\n bind n <- try x\n return Result.Ok(n)\n end lambda\n bind _ <- action(Result.Ok(1))\nend function\n";
    let (_, r, t) = clean(source);
    let info = t.try_kinds.iter().next().unwrap().1;
    assert_eq!(info.kind, TryKind::Result);
    assert_eq!(
        info.ret,
        Ty::Con(
            TyCon::Adt(r.stdlib("Benitoite.Result.Result").unwrap()),
            vec![basic(B::INTEGER), basic(B::STRING)]
        )
    );
    for (source, code, help) in [
        (
            "function f() -> Integer\n return try 1\nend function\n",
            C::E0440,
            "Result",
        ),
        (
            "function f(x: Result[Integer, String]) -> Integer\n return try x\nend function\n",
            C::E0441,
            "Option.okOr",
        ),
        (
            "function f(x: Result[Integer, Integer]) -> Result[Integer, String]\n return Result.Ok(try x)\nend function\n",
            C::E0442,
            "Result.mapError",
        ),
        (
            "function f(x: Option[Integer]) -> Result[Integer, String]\n return Result.Ok(try x)\nend function\n",
            C::E0441,
            "Option.okOr",
        ),
    ] {
        let d = expect(source, &[(code, "try", 0)]);
        assert!(d[0].helps[0].message.contains(help));
    }
    expect(
        "function f() -> Unit\n bind _ <- lambda(x) try x end lambda\nend function\n",
        &[(C::E0407, "try", 0)],
    );
    // 後に解ける内側の try が外側の対象の型を決める。
    let (_, _, t) = clean(
        "function f(x: Option[Option[Integer]]) -> Option[Integer]\n return Option.Some(try (try x))\nend function\n",
    );
    assert_eq!(t.try_kinds.iter().count(), 2);
}

#[test]
fn entry_effects_and_uses_duplicates() {
    for (name, attr) in [("main", ""), ("sample", "@test\n")] {
        let source = format!(
            "effect Log\n function write() -> Unit\nend effect\n{attr}function {name}() -> Unit uses Log\n ()\nend function\n"
        );
        expect(&source, &[(C::E0506, "Log\n", 1)]);
    }
    // 未提供の Assert と Network のソースの代わりに、公開の名前解決の表に
    // 組み込みの番号を置き、型検査の入口に渡す（実装プラン F09「受け入れテスト」）。
    for (module, effect, is_test, expected) in [
        (vec!["Assert"], "Check", false, Some(C::E0415)),
        (vec!["Assert"], "Check", true, None),
        (vec!["Network", "Http"], "Connect", false, None),
        (vec!["Network", "Http"], "Listen", false, None),
    ] {
        let source = format!(
            "{}function main() -> Unit uses State\n ()\nend function\n",
            if is_test { "@test\n" } else { "" }
        );
        let (l, mut r, _, d) = check(&source);
        assert!(d.is_empty());
        if is_test {
            r.main = None;
        }
        let state = r
            .bindings
            .iter()
            .find(|(_, b)| {
                matches!(
                    b.kind,
                    BindingKind::BuiltinEffect(crate::types::builtin::BuiltinEffectId::STATE)
                )
            })
            .unwrap()
            .0;
        let mut b = r.bindings.get(state).unwrap().clone();
        b.kind = BindingKind::BuiltinEffect(find_builtin_effect(&module, effect).unwrap());
        r.bindings.insert(state, b);
        let (_, d) = typecheck(&l.modules, &l.asts, &l.sources, &r, false);
        assert_eq!(
            d.iter().map(|d| d.code.unwrap()).collect::<Vec<_>>(),
            expected.into_iter().collect::<Vec<_>>()
        );
        if !d.is_empty() {
            assert_eq!(
                d[0].primary.as_ref().unwrap().span.start.0 as usize,
                source.find("State").unwrap()
            );
            assert!(d[0].notes.iter().any(|n| n.contains("Assert.Check")));
        }
    }
    let source = "import Benitoite.Unofficial.IO.Console as C\nfunction f() -> Unit uses C.Write, C.Write\n ()\nend function\n";
    let d = expect(source, &[(C::E0419, "C.Write", 1)]);
    let edit = &d[0].helps[0].edits[0];
    assert!(edit.replacement.is_empty());
    assert_eq!(
        &source[edit.span.start.0 as usize..edit.span.end.0 as usize],
        ", C.Write"
    );
    clean(
        "import Benitoite.Unofficial.IO.Console\nfunction f(action: function() -> Unit uses IO.All) -> Unit uses IO.All, Console.Write\n action()\nend function\n",
    );
    expect(
        "function f[effect E](act: function() -> Unit uses E) -> Unit uses E, E\n act()\nend function\n",
        &[(C::E0419, "E\n", 0), (C::E0417, "uses E, E", 0)],
    );
}

#[test]
fn io_all_warning_edits_and_full_effect_body() {
    let source = "import Benitoite.Unofficial.IO.Console\nfunction f() -> Unit uses IO.All\n Console.writeLine(\"a\")\nend function\n";
    let d = expect(source, &[(C::W0501, "IO.All", 0)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, "Console.Write");
    let source = "function f() -> Unit uses IO.All\n ()\nend function\n";
    let d = expect(source, &[(C::W0501, "IO.All", 0)]);
    let edit = &d[0].helps[0].edits[0];
    assert_eq!(
        &source[edit.span.start.0 as usize..edit.span.end.0 as usize],
        "uses IO.All"
    );
    assert!(edit.replacement.is_empty());
    clean(
        "function f(action: function() -> Unit uses IO.All) -> Unit uses IO.All\n action()\nend function\n",
    );
    let source = "function f[effect E](act: function() -> Unit uses E) -> Unit uses IO.All\n act()\nend function\n";
    let d = expect(source, &[(C::E0501, "act()", 0), (C::W0501, "IO.All", 0)]);
    assert_eq!(d[1].helps[0].edits[0].replacement, "E");
    let source = source.replace("uses IO.All\n", "uses IO.All, E\n");
    let d = expect(&source, &[(C::W0501, "IO.All", 0)]);
    assert!(d[0].helps[0].edits[0].replacement.is_empty());
    let source = "import Benitoite.Trait\nimport Benitoite.Unofficial.IO.Console\nrecord Box\n value: Integer\nend record\ntrait Display[T]\n function show(value: T) -> String uses IO.All\nend trait\nimplement Display[Box]\n function show(value: Box) -> String uses IO.All\n Console.writeLine(\"box\")\n return \"box\"\n end function\nend implement\n";
    // 本体のない宣言には警告を出さず、実装のメソッドの本体を検査する。
    let (_, _, _, d) = check(source);
    assert_eq!(
        d.iter().map(|d| d.code.unwrap()).collect::<Vec<_>>(),
        [C::W0501],
        "{d:#?}"
    );
}

#[test]
fn tail_resumption_checks_every_path_and_excludes_inner_lambda_escapes() {
    for (body, expected, ret, uses) in [
        ("resume(())", true, "Unit", ""),
        ("(resume(()))", true, "Unit", ""),
        (
            "if true then resume(()) else resume(()) end if",
            true,
            "Unit",
            "",
        ),
        ("if true then resume(()) else () end if", false, "Unit", ""),
        (
            "match true with case true -> resume(())\n case false -> resume(()) end match",
            true,
            "Unit",
            "",
        ),
        ("bind _ <- resume(())\n ()", false, "Unit", ""),
        (
            "with g = TaskGroup.open() do resume(()) end with",
            false,
            "Unit",
            " uses State",
        ),
        (
            "if true then return () end if\n resume(())",
            false,
            "Unit",
            "",
        ),
        (
            "bind _ <- try Option.Some(())\n resume(())",
            false,
            "Option[Unit]",
            "",
        ),
        (
            "bind _ <- lambda() return () end lambda\n resume(())",
            true,
            "Unit",
            "",
        ),
        (
            "bind _ <- lambda() return Option.Some(try Option.Some(())) end lambda\n resume(())",
            true,
            "Unit",
            "",
        ),
    ] {
        let value = if ret == "Unit" {
            "()"
        } else {
            "Option.Some(())"
        };
        let source = format!(
            "effect Ping\n function ping() -> Unit\nend effect\nfunction f() -> {ret}{uses}\n return handle\n ping()\n {value}\n with case ping() ->\n {body}\n end handle\nend function\n"
        );
        let (l, _, t) = clean(&source);
        assert_eq!(
            t.handlers.get(handle(&l, "f").id).unwrap().clauses[0].tail_resumptive,
            expected,
            "{source}"
        );
    }
}
