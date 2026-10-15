//! エフェクトの規則・診断と後続の段に渡す表を型検査の入口で確かめる（設計書 02-05「書く位置の検査」）。
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
use crate::resolve::ResolveOutput;
use crate::syntax::ast::*;
use crate::typeck::{TryKind, TypeckOutput, test_support::check_files};
use crate::types::builtin::BuiltinTypeId as B;
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
            | Item::ExternalType(_)
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
    // 標準ライブラリ内の try が増えても、仕様例の三つの出力を確かめる。
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
    let same = "effect Compare\n function same[T: equality](a: T, b: T) -> Boolean\nend effect\nfunction f() -> Boolean\n return handle same(a: 1, b: 2) with case same(a, b) -> resume(a = b) end handle\nend function\n";
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
    let source = "function bump(r: Reference[Integer]) -> Unit uses State\n Reference.set(reference: r, value: 1)\nend function\nfunction f() -> Unit\n handle () with case bump(r) -> () end handle\nend function\n";
    let d = expect(source, &[(C::E0507, "bump(r)", 0)]);
    assert!(d[0].notes.is_empty(), "{:?}", d[0]);
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
fn nested_clauses_distinguish_same_named_operation_parameters() {
    // 診断の期待と実際を同時に示す境界で、別の節の同名の型パラメータを区別する。
    // 数字を名前に直接付けると、操作が宣言した型パラメータ名と取り違える。
    let source = "effect Swap\n function store[T](x: T) -> T\nend effect\nfunction f[T](seed: T) -> Unit\n bind _ <- handle store(seed) with case store(x) ->\n  handle store(x) with case store(y) ->\n   if true then Option.Some(x) else Option.Some(y) end if\n  end handle\n end handle\nend function";
    let (_, _, _, diagnostics) = check(source);
    let diag = diagnostics
        .iter()
        .find(|d| {
            d.primary.as_ref().is_some_and(|p| {
                &source[p.span.start.0 as usize..p.span.end.0 as usize] == "Option.Some(y)"
            })
        })
        .unwrap();
    assert_eq!(diag.code, Some(C::E0401));
    assert_eq!(
        diag.primary.as_ref().unwrap().text,
        "expected `Option[store.T]`, found `Option[store.T#2]`"
    );
}

#[test]
fn type_escape_note_is_not_reused_for_other_failures() {
    // 剛な型の出どころを別の E0401 に持ち越さない。
    // 一件だけの脱出のゴールデンでは、記録を消し忘れる退行を捕まえられない。
    let sources = [
        "effect Swap\n function store[T](x: T) -> T\nend effect\nfunction f() -> Unit\n bind _ <- handle\n bind _ <- store(42)\n Option.None\n with case store(x) -> Option.Some(x)\n end handle\n bind _ <- String.characterCount(1)\nend function\n",
        "effect Swap\n function store[T](x: T) -> T\nend effect\nfunction f() -> Unit\n bind g <- lambda()\n  bind _ <- handle store(42) with case store(x) ->\n   bind s <- Option.Some(x)\n   return s\n  end handle\n  return Option.None\n end lambda\n bind _ <- 1 + \"bad\"\nend function\n",
    ];
    for source in sources {
        let (_, _, _, diagnostics) = check(source);
        assert_eq!(diagnostics.len(), 2, "{diagnostics:#?}");
        for d in diagnostics {
            assert_eq!(d.code, Some(C::E0401));
            let span = d.primary.as_ref().unwrap().span;
            let at = source
                .get(span.start.0 as usize..span.end.0 as usize)
                .unwrap();
            let escaped = d
                .notes
                .iter()
                .any(|n| n.contains("cannot leave the clause"));
            if at == "Option.Some(x)" || at == "s" {
                assert!(escaped, "{d:#?}");
            } else {
                assert!(at == "1" || at == "\"bad\"", "{at}");
                assert!(!escaped, "{d:#?}");
            }
        }
    }
}

#[test]
fn try_error_type_escape_does_not_annotate_a_deferred_return_mismatch() {
    // try が独自の E0442 を報告した脱出情報を、保留中の別の E0401 へ渡さない。
    let source = "effect Swap\n function store[T](x: T) -> T\nend effect\nfunction f() -> Unit\n bind g <- lambda()\n  bind _ <- handle store(42) with case store(x) ->\n   bind _ <- try Result.Error(x)\n   resume(x)\n  end handle\n  return Result.Ok(())\n end lambda\n bind s <- Integer.toString(1)\n return s\nend function\n";
    let (_, _, _, diagnostics) = check(source);
    assert_eq!(diagnostics.len(), 2, "{diagnostics:#?}");
    assert!(
        diagnostics.iter().any(|d| d.code == Some(C::E0442)),
        "{diagnostics:#?}"
    );
    let d = diagnostics
        .iter()
        .find(|d| d.code == Some(C::E0401))
        .unwrap();
    assert_eq!(
        d.primary.as_ref().unwrap().text,
        "expected `Unit`, found `String`"
    );
    assert!(
        !d.notes
            .iter()
            .any(|n| n.contains("cannot leave the clause")),
        "{d:#?}"
    );
    assert!(
        d.secondary
            .iter()
            .all(|label| !label.text.contains("clause")),
        "{d:#?}"
    );
}

#[test]
fn operation_type_parameters_are_qualified_when_outer_names_collide() {
    for (body, expected, escaped) in [
        (
            "-> Unit\n bind _ <- handle",
            "expected `Option[_]`, found `Option[store.T]`",
            true,
        ),
        (
            "-> Option[T]\n return handle",
            "expected `Option[T]`, found `Option[store.T]`",
            false,
        ),
    ] {
        let source = format!(
            "effect Swap\n function store[T](x: T) -> T\nend effect\nfunction run[T](a: T) {body}\n  bind _ <- store(a)\n  Option.None\n with case store(x) -> Option.Some(x)\n end handle\nend function\n"
        );
        let (_, _, _, diagnostics) = check(&source);
        assert_eq!(diagnostics.len(), 1, "{diagnostics:#?}");
        let d = &diagnostics[0];
        assert_eq!(d.code, Some(C::E0401));
        assert_eq!(d.primary.as_ref().unwrap().text, expected);
        assert_eq!(
            d.notes
                .iter()
                .any(|n| n.contains("`store.T`") && n.contains("cannot leave the clause")),
            escaped,
            "{d:#?}"
        );
    }
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
        "function f() -> Unit uses State\n with g = TaskGroup.open() do\n bind t <- TaskGroup.spawn(group: g, action: lambda() return 1 end lambda)\n bind _ <- Task.await(t)\n end with\nend function\n",
    );
    for expr in ["TaskGroup.open()", "TaskGroup.open", "(TaskGroup.open())"] {
        let source = format!("function f() -> Unit uses State\n bind _ <- {expr}\nend function\n");
        let d = expect(&source, &[(C::E0505, "TaskGroup.open", 0)]);
        assert!(d[0].helps[0].message.contains("with"));
    }
    expect(
        "function f() -> Unit uses State\n bind _ <- List.map(xs: [()], f: lambda(value) return TaskGroup.open(value) end lambda)\nend function\n",
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
        if code == C::E0441 {
            assert!(d[0].helps[0].message.contains("`Result.ok`"));
        }
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
fn try_notes_follow_lambda_and_placeholder_return_boundaries() {
    // プレースホルダ内のラムダと、ラムダ内のプレースホルダの両方で境界の復元を確かめる。
    for (source, code, note, call) in [
        (
            "function f(x: Result[Integer, String]) -> Unit\n bind _ <- lambda() -> Integer\n  return try x\n end lambda\nend function",
            C::E0441,
            "the lambda returns `Integer`",
            None,
        ),
        (
            "function f(x: Result[Integer, Integer]) -> Unit\n bind _ <- lambda() -> Result[Integer, String]\n  return Result.Ok(try x)\n end lambda\nend function",
            C::E0442,
            "the lambda returns `Result[Integer, String]`",
            None,
        ),
        (
            "function add(x: Integer, y: Integer) -> Integer\n return x + y\nend function\nfunction f() -> Unit\n bind _ <- add(x: try Option.None, y: _)\nend function",
            C::E0441,
            "the function made by `_` in this call returns `Integer`",
            Some("add(x: try Option.None, y: _)"),
        ),
        (
            "function add(x: Integer, y: Integer) -> Result[Integer, String]\n return Result.Ok(x + y)\nend function\nfunction f(x: Result[Integer, Integer]) -> Unit\n bind _ <- add(x: try x, y: _)\nend function",
            C::E0442,
            "the function made by `_` in this call returns `Result[Integer, String]`",
            Some("add(x: try x, y: _)"),
        ),
        (
            "function use(g: function() -> Integer, n: Integer) -> Unit\nend function\nfunction f(x: Option[Integer]) -> Unit\n bind _ <- use(g: lambda() -> Integer return try x end lambda, n: _)\nend function",
            C::E0441,
            "the lambda returns `Integer`",
            None,
        ),
        (
            "function add(x: Integer, y: Integer) -> Integer\n return x + y\nend function\nfunction f() -> Unit\n bind _ <- lambda()\n  bind _ <- add(x: try Option.None, y: _)\n  return ()\n end lambda\nend function",
            C::E0441,
            "the function made by `_` in this call returns `Integer`",
            Some("add(x: try Option.None, y: _)"),
        ),
    ] {
        let (load, _, _, diagnostics) = check(source);
        assert_eq!(diagnostics.len(), 1, "{diagnostics:?}");
        let diag = &diagnostics[0];
        assert_eq!(diag.code, Some(code), "{diag:?}");
        assert_eq!(diag.notes, [note]);
        if let Some(call) = call {
            let label = &diag.secondary[0];
            assert_eq!(label.text, "this call with `_` makes a function");
            let text = load.sources.get(label.span.file).unwrap().text();
            assert_eq!(
                &text[label.span.start.0 as usize..label.span.end.0 as usize],
                call.as_bytes()
            );
        } else {
            assert!(diag.secondary.is_empty(), "{diag:?}");
        }
    }
}

#[test]
fn entry_effects_and_uses_duplicates() {
    for (name, attr) in [("main", ""), ("sample", "@test\n")] {
        let source = format!(
            "effect Log\n function write() -> Unit\nend effect\n{attr}function {name}() -> Unit uses Log\n ()\nend function\n"
        );
        expect(&source, &[(C::E0506, "Log\n", 1)]);
    }
    let d = expect(
        "function main() -> Unit uses Assert.Check\n ()\nend function\n",
        &[(C::E0415, "Assert.Check", 0)],
    );
    assert!(d[0].notes.iter().any(|n| n.contains("Assert.Check")));
    // main 以外の関数は Assert のエフェクトを書いてよい。
    clean("function sample() -> Unit uses Assert.Check\n ()\nend function\n");
    for effect in ["Connect", "Listen"] {
        clean(&format!(
            "import Benitoite.Unofficial.Network.Http\nfunction main() -> Unit uses Http.{effect}\n ()\nend function\n"
        ));
    }
    let source = "import Benitoite.Unofficial.IO.Console\nfunction f() -> Unit uses Console.Write, Console.Write\n ()\nend function\n";
    let d = expect(source, &[(C::E0419, "Console.Write", 1)]);
    let edit = &d[0].helps[0].edits[0];
    assert!(edit.replacement.is_empty());
    assert_eq!(
        &source[edit.span.start.0 as usize..edit.span.end.0 as usize],
        ", Console.Write"
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

// 診断の型名と案内先を型検査の入口で確かめる。既存の脱出の検査では、試行・
// パターン・型クラスの別経路による外側の型名の混入を捕まえない（設計書 02-05「誤りの報告と検査の継続」）。
#[test]
fn rigid_types_keep_operation_names_in_body_diagnostics() {
    let mut mismatches = vec![];
    for outer in ["A", "T"] {
        let name = if outer == "T" { "store.T" } else { "T" };
        for (body, code, message, note) in [
            (
                "bind f <- lambda()\n bind v <- try Option.Some(x)\n return x\n end lambda",
                C::E0441,
                format!("`try` on `Option[{name}]` needs the function to return Option"),
                Some(format!("the lambda returns `{name}`")),
            ),
            (
                "bind f <- lambda()\n bind v <- try x\n return Option.Some(v)\n end lambda",
                C::E0440,
                format!("`try` cannot be applied to `{name}`"),
                None,
            ),
            (
                "bind f <- lambda()\n bind v <- try Result.Error(x)\n return Result.Error(\"s\")\n end lambda",
                C::E0442,
                format!(
                    "`try` cannot return an error of type `{name}` from a function that returns errors of type `String`"
                ),
                Some("the lambda returns `Result[_, String]`".into()),
            ),
            (
                "bind Option.Some(v) <- Option.Some(x)",
                C::E0607,
                format!("this pattern does not match every value of `Option[{name}]`"),
                None,
            ),
            (
                "bind s <- Trait.Show.show(Option.Some(x))",
                C::E0705,
                format!("`{name}` does not implement `Show`"),
                None,
            ),
        ] {
            let source = format!(
                "import Benitoite.Trait\neffect Swap\n function store[T](x: T) -> T\nend effect\nfunction run[{outer}](a: {outer}) -> {outer}\n return handle\n store(a)\n with case store(x) ->\n {body}\n resume(x)\n end handle\nend function\n"
            );
            let (_, _, _, diagnostics) = check(&source);
            assert_eq!(diagnostics.len(), 1, "{outer}: {diagnostics:#?}");
            let d = &diagnostics[0];
            assert_eq!(d.code, Some(code));
            if d.message != message
                || note
                    .as_ref()
                    .is_some_and(|note| !d.notes.iter().any(|n| n == note))
            {
                mismatches.push(format!(
                    "{outer}, {code:?}: expected {message:?}, note {note:?}; got {d:#?}"
                ));
            }
        }
    }
    assert!(mismatches.is_empty(), "{}", mismatches.join("\n"));
}

#[test]
fn rigid_constraint_help_targets_the_operation_declaration() {
    let mut mismatches = vec![];
    for (body, code, constraint) in [
        ("bind _ <- x = x", C::E0406, "equality"),
        ("bind _ <- Map.fromList([Pair(x, 1)])", C::E0424, "key"),
    ] {
        let source = format!(
            "effect Swap\n function store[T](x: T) -> T\nend effect\nfunction run[T](a: T) -> T\n return handle\n store(a)\n with case store(x) ->\n {body}\n resume(x)\n end handle\nend function\n"
        );
        let (_, _, _, diagnostics) = check(&source);
        assert_eq!(diagnostics.len(), 1, "{diagnostics:#?}");
        let d = &diagnostics[0];
        assert_eq!(d.code, Some(code));
        assert_eq!(d.helps.len(), 1);
        let expected = format!(
            "add the constraint `{constraint}` to the type parameter `T` in the declaration of the operation `store`"
        );
        if !d.message.contains("`store.T`") || d.helps[0].message != expected {
            mismatches.push(format!("{constraint}: {d:#?}"));
        }
        assert!(d.helps[0].edits.is_empty());
    }
    assert!(mismatches.is_empty(), "{}", mismatches.join("\n"));
}
