//! 言語の規則・後続の段への出力・診断の位置を、実際の読み込みから検査する（設計書 02-05「出力」）。
// テストの失敗を panic で表し、期待値の位置と公開の表を直接確かめる。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)]
use super::{TypeckOutput, test_support::check_files};
use crate::base::{BindingId, NodeId};
use crate::diag::{DiagCode as C, Diagnostic};
use crate::modules::LoadOutput;
use crate::resolve::ResolveOutput;
use crate::syntax::ast::*;
use crate::types::builtin::{BuiltinEffectId, BuiltinTypeId as B};
use crate::types::{ConstValue as V, EffectName, Ty, TyCon, TypeArg};

fn check(s: &str) -> (LoadOutput, ResolveOutput, TypeckOutput, Vec<Diagnostic>) {
    check_files(&[("main.bnt", s)], false)
}

#[test]
fn prelude_type_shadowing_in_nested_types_and_type_arity() {
    // 公開の型検査で、入れ子の型と型引数の数にも注記が付くことを確かめる。
    // 診断の描画のテストでは、利用者と標準の同名の型の判定には届かない。
    for (source, code, name) in [
        (
            "record Result\n value: Integer\nend record\nfunction f() -> List[Result]\n return [Benitoite.Result.Ok(1)]\nend function",
            C::E0401,
            "Result",
        ),
        (
            "record String\n value: Integer\nend record\nfunction f(x: String) -> Benitoite.String\n return x\nend function",
            C::E0401,
            "String",
        ),
        (
            "record Integer64\n value: Integer\nend record\nfunction f(x: Integer64) -> Benitoite.Integer64\n return x\nend function",
            C::E0401,
            "Integer64",
        ),
        (
            "record Float64\n value: Integer\nend record\nfunction f(x: Float64) -> Benitoite.Float64\n return x\nend function",
            C::E0401,
            "Float64",
        ),
        (
            "record UnsignedInteger8\n value: Integer\nend record\nfunction f(x: UnsignedInteger8) -> Benitoite.UnsignedInteger8\n return x\nend function",
            C::E0401,
            "UnsignedInteger8",
        ),
        (
            "record UnsignedInteger\n value: Integer\nend record\nfunction f(x: UnsignedInteger) -> Benitoite.UnsignedInteger\n return x\nend function",
            C::E0401,
            "UnsignedInteger",
        ),
        (
            "record Result\n value: Integer\nend record\nfunction f(x: List[Result]) -> Integer\n return x\nend function",
            C::E0401,
            "",
        ),
        (
            "record Unit\n value: Integer\nend record\nfunction f(x: function(Unit) -> Integer) -> Integer\n return x\nend function",
            C::E0401,
            "",
        ),
        (
            "record Unit\n value: Integer\nend record\nfunction f(x: function(Unit) -> Integer) -> function(Benitoite.Unit) -> Integer\n return x\nend function",
            C::E0401,
            "Unit",
        ),
        (
            "record State\n value: Integer\nend record\nfunction f(x: function() -> State) -> Integer\n return x\nend function",
            C::E0401,
            "",
        ),
        (
            "record Result\n value: Integer\nend record\nfunction f(x: Result[Integer, String]) -> Unit\nend function",
            C::E0410,
            "Result",
        ),
        (
            "record Local\n value: Integer\nend record\nfunction f(x: Local[Integer]) -> Unit\nend function",
            C::E0410,
            "",
        ),
    ] {
        let (_, _, _, diagnostics) = check(source);
        let diag = diagnostics.iter().find(|d| d.code == Some(code)).unwrap();
        if name.is_empty() {
            assert!(
                !diag.notes.iter().any(|n| n.contains("hides the prelude")),
                "{diag:?}"
            );
            assert!(diag.helps.is_empty());
        } else {
            assert!(
                diag.notes.iter().any(|n| n.contains("hides the prelude")),
                "{diag:?}"
            );
            assert_eq!(
                diag.helps.last().unwrap().message,
                format!("write `Benitoite.{name}` for the prelude type")
            );
            assert!(diag.helps.last().unwrap().edits.is_empty());
        }
    }
    for (main, code) in [
        (
            "import M\nfunction f(x: M.Result[Integer, String]) -> Unit\nend function",
            C::E0410,
        ),
        (
            "import M\nfunction f(x: M.Result) -> Benitoite.Result[Integer, String]\n return x\nend function",
            C::E0401,
        ),
    ] {
        let (_, _, _, diagnostics) = check_files(
            &[
                ("main.bnt", main),
                ("M.bnt", "public record Result\n value: Integer\nend record"),
            ],
            false,
        );
        let diag = diagnostics.iter().find(|d| d.code == Some(code)).unwrap();
        assert!(
            !diag.notes.iter().any(|n| n.contains("hides the prelude")),
            "{diag:?}"
        );
        assert!(diag.helps.is_empty(), "{diag:?}");
    }
    clean(
        "record Task\n title: String\nend record\nfunction f(x: Task) -> Task\n return x\nend function",
    );
}

fn clean(s: &str) -> (LoadOutput, ResolveOutput, TypeckOutput) {
    let (l, r, t, d) = check(s);
    assert!(d.is_empty(), "{d:#?}");
    assert_output_nodes(&l, &t);
    (l, r, t)
}
fn assert_output_nodes(load: &LoadOutput, out: &TypeckOutput) {
    // 型検査の表をキーの列挙で確かめず、検査したソースの AST から必要なノードを求める。
    for top in &load.asts[0].decls {
        let mut check = |n: NodeId, _| assert!(out.expr_types.get(n).is_some(), "missing {n:?}");
        match &top.item {
            Item::Fn(f) => {
                for p in &f.params {
                    check(p.id, p.span);
                }
                if let Some(b) = &f.body {
                    visit_block(b, &mut check);
                }
            }
            Item::Const(c) => visit_expr(&c.value, &mut check),
            Item::Data(_)
            | Item::Alias(_)
            | Item::Record(_)
            | Item::Trait(_)
            | Item::Impl(_)
            | Item::Effect(_)
            | Item::ExternalType(_)
            | Item::Error(_) => {}
        }
    }
}
fn expect(s: &str, expected: &[(C, usize, usize)]) -> Vec<Diagnostic> {
    let (load, _, _, d) = check(s);
    let positions = d
        .iter()
        .map(|d| {
            let span = d.primary.as_ref().map(|p| p.span);
            let pos = span.map(|span| load.sources.get(span.file).unwrap().line_col(span.start));
            (
                d.code.unwrap(),
                pos.map_or(0, |p| p.line as usize),
                pos.map_or(0, |p| p.column as usize),
            )
        })
        .collect::<Vec<_>>();
    assert_eq!(positions, expected, "{d:#?}");
    d
}
fn id(r: &ResolveOutput, name: &str) -> BindingId {
    r.bindings
        .iter()
        .find(|(_, b)| b.name == name && b.module.0 == 0)
        .unwrap()
        .0
}
fn constant<'a>(r: &ResolveOutput, t: &'a TypeckOutput, name: &str) -> &'a V {
    t.consts.get(id(r, name)).unwrap()
}
fn node_at(load: &LoadOutput, start: usize) -> NodeId {
    // ノードの検索は AST から行う。出力の表のキーを使って期待値を作らない。
    let mut found = None;
    for top in &load.asts[0].decls {
        if let Item::Fn(f) = &top.item
            && let Some(b) = &f.body
        {
            visit_block(b, &mut |n, span| {
                if span.start.0 as usize == start {
                    found = Some(n);
                }
            });
        }
    }
    found.unwrap()
}
#[test]
fn standard_library_and_entry_contracts() {
    let (_, r, t, d) = check_files(
        &[("main.bnt", "function main() -> Unit\nend function\n")],
        true,
    );
    assert!(d.is_empty(), "{d:#?}");
    for name in [
        "Benitoite.Option.Some",
        "Benitoite.Result.Ok",
        "Benitoite.Pair.Pair",
        "Benitoite.List.map",
    ] {
        assert!(
            t.decl_types.get(r.stdlib(name).unwrap()).is_some(),
            "{name}"
        );
    }
    for (binding, definition) in r.bindings.iter() {
        if matches!(
            definition.kind,
            crate::resolve::BindingKind::Fn
                | crate::resolve::BindingKind::BuiltinFn(_)
                | crate::resolve::BindingKind::Const
                | crate::resolve::BindingKind::Ctor { .. }
                | crate::resolve::BindingKind::Record
                | crate::resolve::BindingKind::Field { .. }
                | crate::resolve::BindingKind::Op { .. }
        ) {
            assert!(t.decl_types.get(binding).is_some(), "{}", definition.name);
        }
    }
    assert!(t.main.is_some());
    let (_, _, t, d) = check_files(
        &[(
            "main.bnt",
            "function main() -> Result[Unit, String]\n return Result.Ok(())\nend function\n",
        )],
        true,
    );
    assert!(d.is_empty(), "{d:#?}");
    assert!(t.main.unwrap().returns_result);

    let (_, _, _, d) = check_files(
        &[("main.bnt", "function f() -> Unit\nend function\n")],
        true,
    );
    assert_eq!(
        d.iter().map(|d| d.code).collect::<Vec<_>>(),
        [Some(C::E0414)]
    );
    let d = expect(
        "function main(x: Integer) -> Integer\n return x\nend function\n",
        &[(C::E0415, 1, 10)],
    );
    assert_eq!(d[0].notes.len(), 2);
    expect(
        "@test\nfunction f(x: Integer) -> Unit\nend function\n",
        &[(C::E0806, 2, 10)],
    );
}
#[test]
fn records_aliases_constants_and_output_tables() {
    let s = r#"import Benitoite.Map
data Color
 Red
 Green
 Blue
end data
record Person
 name: String
 age: Integer
end record
record Box[T]
 value: T
end record
type UserId = Integer
type Validator[T] = function(T) -> Result[T, String]
const maxRetries: Integer = 3
const defaultPort: Integer = 8000 + 80
const greeting: String = "hello, ${defaultPort}"
const primaryColors: List[Color] = [Color.Red, Color.Green, Color.Blue]
const statusNames: Map[Integer, String] = Map.fromList([Pair(404, "Not Found"), Pair(200, "OK")])
function validate(v: Validator[Integer], x: UserId) -> Result[Integer, String]
 return v(x)
end function
function main() -> Unit
 bind p <- Person(name: "Ada", age: 36)
 bind q <- Person(..p, age: 37)
 bind personName <- Person.name(p)
 bind Person(name: n, ..) <- q
 bind age <- match p with
  case Person(age: a, ..) -> a
 end match
 bind b <- Box(value: 4)
 bind x <- Box.value(b)
 bind pair <- Pair(age, n)
 bind Pair(k, label) <- pair
 bind f <- Integer.toString(_)
 bind xs <- [1, ..[2, 3]]
 bind text <- label |> Pair(f(k))
end function
"#;
    let (l, r, t) = clean(s);
    assert!(matches!(constant(&r, &t, "maxRetries"), V::Integer(3)));
    assert!(matches!(constant(&r, &t, "primaryColors"), V::List(colors)
        if matches!(colors.as_slice(), [V::Ctor { tag: 0, .. }, V::Ctor { tag: 1, .. }, V::Ctor { tag: 2, .. }])));
    assert!(matches!(constant(&r, &t, "defaultPort"), V::Integer(8080)));
    assert!(matches!(constant(&r,&t,"greeting"),V::String(s) if s=="hello, 8080"));
    let V::Map(m) = constant(&r, &t, "statusNames") else {
        panic!()
    };
    assert!(matches!(m[0].0, V::Integer(200)));
    assert!(matches!(m[1].0, V::Integer(404)));
    let start = s.find("Box(value:").unwrap();
    let n = node_at(&l, start);
    assert_eq!(
        t.type_args.get(n).unwrap().tys,
        vec![TypeArg::Ty(Ty::Con(TyCon::Builtin(B::INTEGER), vec![]))]
    );
    let start = s.find("Box.value(b)").unwrap();
    let n = node_at(&l, start);
    assert_eq!(t.type_args.get(n).unwrap().tys.len(), 1);
}
#[test]
fn record_errors_and_alias_spelling() {
    expect(
        "record Person\n name: String\n age: Integer\nend record\nfunction f() -> Unit\n bind _ <- Person(name: \"Ada\")\n bind _ <- Person(name: \"Ada\", age: 4, typo: 5)\n bind _ <- Person(name: \"Ada\", age: 4, age: 5)\nend function\n",
        &[(C::E0428, 6, 12), (C::E0429, 7, 40), (C::E0430, 8, 40)],
    );
    expect(
        "record Box[T]\n value: T\nend record\nfunction f(b: Box[Integer]) -> Unit\n bind _ <- Box(..b, value: \"x\")\nend function\n",
        &[(C::E0401, 5, 28)],
    );
    expect(
        "type Unused[T] = Integer\ntype Validator[T] = function(T) -> T\nfunction f(x: Validator[Integer, String], y: Validator) -> Unit\nend function\n",
        &[(C::E0432, 1, 6), (C::E0410, 3, 15), (C::E0410, 3, 46)],
    );
    let d = expect(
        "type UserId = Integer\nfunction f() -> Unit\n bind x: UserId <- \"a\"\nend function\n",
        &[(C::E0401, 3, 20)],
    );
    assert!(d[0].primary.as_ref().unwrap().text.contains("UserId"));
    assert!(d[0].notes.iter().any(|n| n.contains("Integer")));
}
#[test]
fn decimal_and_integer_literals_and_interpolation() {
    let (_, r, t) = clean(
        r#"const a: Decimal = 1.50m
const b: Decimal = -79228162514264337593543950335m
const s: String = "${1.0e21} ${0.001} ${-0.0} ${1.5m} ${true}"
const n: Integer = -9223372036854775808
const modMin: Integer = -9223372036854775808 mod -1
"#,
    );
    assert!(matches!(constant(&r,&t,"a"),V::Decimal(d) if d.mantissa()==150&&d.scale()==2));
    assert!(
        matches!(constant(&r,&t,"b"),V::Decimal(d) if d.mantissa()== -crate::base::decimal::MAX_MANTISSA)
    );
    assert!(matches!(constant(&r,&t,"s"),V::String(s) if s=="1.0e+21 0.001 -0.0 1.5 true"));
    assert!(matches!(constant(&r, &t, "n"), V::Integer(i64::MIN)));
    assert!(matches!(constant(&r, &t, "modMin"), V::Integer(0)));
    expect(
        "const a: Decimal = 0.12345678901234567890123456789m\nconst b: Decimal = 79228162514264337593543950336m\n",
        &[(C::E0420, 1, 20), (C::E0421, 2, 20)],
    );
    expect(
        "const a: Integer = 9223372036854775808\nconst b: Float = 1e999\n",
        &[(C::E0408, 1, 20), (C::E0409, 2, 18)],
    );
    expect(
        "function f() -> Unit\n bind _ <- \"${[1]}\"\nend function\n",
        &[(C::E0422, 2, 15)],
    );
}
#[test]
fn constant_failures_dependencies_and_duplicate_keys() {
    expect(
        "function f() -> Integer\n return 1\nend function\nconst a: Integer = f()\nconst b: Integer = 9223372036854775807 + 1\nconst c: Integer = b + 1\nconst d: Integer = 1 div 0\n",
        &[(C::E0433, 4, 20), (C::E0435, 5, 20), (C::E0435, 7, 20)],
    );
    expect(
        "const f: function(Integer) -> Option[Integer] = Option.Some\n",
        &[(C::E0433, 1, 49)],
    );
    expect(
        "import Benitoite.Map\nconst a: Map[Integer, String] = Map.fromList([Pair(1, \"a\"), Pair(1, \"b\")])\n",
        &[(C::E0436, 2, 66)],
    );
    expect(
        "import Benitoite.Set\nconst a: Set[Decimal] = Set.fromList([1.0m, 1.00m])\n",
        &[(C::E0436, 2, 45)],
    );
    expect(
        "import Benitoite.Set\nconst prefix: List[Integer] = [2, 1]\nconst a: Set[Integer] = Set.fromList([..prefix, 1])\n",
        &[(C::E0436, 3, 49)],
    );
    expect(
        "import Benitoite.Set\nconst a: Set[Option[Integer]] = Set.fromList([Option.Some(1), Option.Some(1)])\n",
        &[(C::E0436, 2, 63)],
    );
    let s = "const maxRetries: Integer = 3\nfunction f() -> Unit\n bind _ <- maxRetries()\nend function\n";
    let d = expect(s, &[(C::E0403, 3, 12)]);
    let edit = &d[0].helps[0].edits[0];
    assert_eq!(edit.replacement, "");
    assert_eq!(
        &s[edit.span.start.0 as usize..edit.span.end.0 as usize],
        "()"
    );
}
#[test]
fn operators_warnings_and_fixes() {
    expect(
        "import Benitoite.Map\nfunction f(x: Integer) -> Unit\n bind _ <- x div 0\n bind _ <- 9223372036854775807 + 1\n bind _ <- Integer.absolute(-9223372036854775808)\n bind _ <- Map.fromList([Pair(1, \"a\"), Pair(1, \"b\")])\nend function\n",
        &[
            (C::W0401, 3, 18),
            (C::W0402, 4, 12),
            (C::W0402, 5, 12),
            (C::W0403, 6, 45),
        ],
    );
    clean(
        "import Benitoite.Map\nfunction makePair(x: Integer) -> Pair[Integer, String]\n return Pair(x, \"a\")\nend function\nfunction f() -> Unit\n bind _ <- Map.fromList([makePair(1), makePair(1)])\nend function\n",
    );
    clean("function f(a: Byte, b: Byte) -> Boolean\n return a < b or a = b\nend function\n");
    expect(
        "function f(b: Byte) -> Unit\n bind _ <- b + b\nend function\n",
        &[(C::E0405, 2, 12)],
    );
    let s = "function f() -> Unit\n bind _ <- 1 / 2\nend function\n";
    let d = expect(s, &[(C::E0405, 2, 12)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, "div");
    assert_eq!(
        &s[d[0].helps[0].edits[0].span.start.0 as usize
            ..d[0].helps[0].edits[0].span.end.0 as usize],
        "/"
    );
    clean("const a: Decimal = 1.5m + 2m\n");
    expect(
        "function f() -> Float\n return 1 div 2\nend function\n",
        &[(C::E0401, 2, 9)],
    );
    expect(
        "function f() -> Float\n return 1 mod 2\nend function\n",
        &[(C::E0401, 2, 9)],
    );
    clean(
        "function f() -> Unit\n bind divide <- lambda(a, b) return a div b end lambda\n bind modulo <- lambda(a, b) return a mod b end lambda\n bind _ <- divide(5, 2) + modulo(5, 2)\nend function\n",
    );
    expect(
        "function f() -> Unit\n bind _ <- 1.5m div 2m\nend function\n",
        &[(C::E0401, 2, 17)],
    );
    let s = "function f(x: Integer) -> Unit\n 1 + 2\n x = 5\n ()\nend function\n";
    let d = expect(s, &[(C::E0416, 2, 2), (C::E0416, 3, 2)]);
    assert_eq!(d[0].helps[0].edits[0].replacement, "bind _ <- ");
    assert_eq!(
        d[0].helps[0].edits[0].span.start,
        d[0].helps[0].edits[0].span.end
    );
    assert_eq!(d[1].helps[1].edits[0].replacement, "shadow x <- 5");
}
#[test]
fn returns_monomorphism_unknown_types_and_error_recovery() {
    clean(
        "function sign(n: Integer) -> Integer\n if n < 0 then\n  return -1\n else\n  return 1\n end if\nend function\n",
    );
    expect(
        "function bad(n: Integer) -> Integer\n if n < 0 then\n  return -1\n end if\nend function\n",
        &[(C::E0438, 2, 2)],
    );
    expect(
        "function f() -> Unit\n return ()\n bind x <- 1\nend function\n",
        &[(C::E0439, 3, 2)],
    );
    expect(
        "function f() -> Unit\n bind g <- lambda(x) return x end lambda\n bind _ <- g(1)\n bind _ <- g(\"x\")\nend function\n",
        &[(C::E0401, 4, 14)],
    );
    expect(
        "function f() -> Unit\n bind g <- lambda(x) return x + x end lambda\nend function\n",
        &[(C::E0407, 2, 29)],
    );
    expect(
        "function f() -> Unit\n bind x: Integer <- \"wrong\"\n bind _ <- x + 1\n bind _ <- x + 2\n bind _ <- x + 3\nend function\n",
        &[(C::E0401, 2, 21)],
    );
}

#[test]
fn final_expression_reports_once_at_the_expression() {
    // 本体の最後の式と、戻り値の型が違う再代入の形を区別する。
    // ブロックの先頭への挿入や、同じ原因の二重の診断を検出する（設計書 02-05）。
    for (source, line, column, helps) in [
        (
            "function f(x: Integer) -> Integer\n bind y <- x + 1\n y * 2\nend function\n",
            3,
            2,
            vec![("return ", true)],
        ),
        (
            "function f(x: Integer) -> Unit\n x = 5\nend function\n",
            2,
            2,
            vec![("bind _ <- ", true), ("shadow x <- 5", true)],
        ),
        (
            "function f(x: Integer) -> Integer\n x = 5\nend function\n",
            2,
            2,
            vec![("", false), ("shadow x <- 5", true)],
        ),
        (
            "function f() -> Unit\n bind g <- lambda() -> Integer\n  1\n end lambda\nend function\n",
            3,
            3,
            vec![("return ", true)],
        ),
        (
            "function f() -> Unit\n bind g <- lambda()\n  1\n end lambda\nend function\n",
            3,
            3,
            vec![("return ", true), ("bind _ <- ", true)],
        ),
        (
            "function accept(cb: function() -> Unit) -> Unit\nend function\nfunction f() -> Unit\n accept(lambda()\n  1\n end lambda)\nend function\n",
            5,
            3,
            vec![("bind _ <- ", true)],
        ),
    ] {
        let diagnostics = expect(source, &[(C::E0416, line, column)]);
        let diag = &diagnostics[0];
        assert_eq!(diag.helps.len(), helps.len(), "{diag:?}");
        for (help, (replacement, has_edit)) in diag.helps.iter().zip(helps) {
            assert_eq!(!help.edits.is_empty(), has_edit, "{help:?}");
            if has_edit {
                assert_eq!(help.edits[0].replacement, replacement);
            } else {
                assert!(help.message.contains("write `return`"), "{help:?}");
            }
        }
    }
}

#[test]
fn returned_binding_mismatch_uses_the_declared_return_reason() {
    let mut cases = vec![];
    for (annotation, ret) in [("", "Unit"), (": String", "Unit"), ("", "Integer")] {
        let source = format!(
            "function f() -> {ret}\n bind s{annotation} <- Integer.toString(1)\n return s\nend function\n"
        );
        cases.push((source, ret, "String", 3, 9));
    }
    // 分岐の変数も、宣言の戻り値とパターンの値の食い違いを return の位置で示す。
    cases.push((
        "function f(n: Integer) -> String\n match n with\n case s -> return s\n end match\nend function\n".into(),
        "String",
        "Integer",
        3,
        19,
    ));
    for (source, ret, found, line, column) in cases {
        let diagnostics = expect(&source, &[(C::E0401, line, column)]);
        let diag = &diagnostics[0];
        assert_eq!(
            diag.primary.as_ref().unwrap().text,
            format!("expected `{ret}`, found `{found}`")
        );
        assert!(
            diag.notes
                .iter()
                .any(|n| n.contains("declared return type")),
            "{diag:?}"
        );
    }
}
#[test]
fn binding_mismatch_suppresses_spurious_variable_use_failures() {
    // 束縛の値には合う呼び出しが、宣言で仮に決まった型との比較で誤りにならないことを守る。
    // 既存の宣言のテストは食い違う変数を別の呼び出しに渡さず、診断の取り違えに届かない。
    // 使う側をラムダの本体と分岐の中に置く行は、記録が使う側の制約より先に起きる前提を守る。
    // 型検査の入口で件数・位置・型の向きを確かめ、差し込み口は加えない。
    let callee = "function h(x: Integer) -> Integer\n  return x\nend function\n\n";
    let mut mismatches = vec![];
    for (body, line, column) in [
        (
            "function f(n: Integer) -> String\n  bind s <- n\n  bind _ <- h(s)\n  return s\nend function\n",
            8,
            10,
        ),
        (
            "function f(n: Integer) -> Unit\n  bind s <- n\n  bind t: String <- s\n  bind _ <- h(s)\nend function\n",
            7,
            21,
        ),
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind t: String <- s\n  bind _ <- h(s)\n  return s\nend function\n",
            7,
            21,
        ),
        (
            "function f(n: Integer) -> String\n  bind s <- n\n  bind k <- lambda() -> Integer\n    return h(s)\n  end lambda\n  return s\nend function\n",
            10,
            10,
        ),
        (
            "function f(n: Integer) -> String\n  match n with\n  case s ->\n    bind _ <- h(s)\n    return s\n  end match\nend function\n",
            9,
            12,
        ),
    ] {
        let source = format!("{callee}{body}");
        let (loaded, _, _, diagnostics) = check(&source);
        let actual: Vec<_> = diagnostics
            .iter()
            .map(|d| {
                let p = d.primary.as_ref().unwrap();
                let loc = loaded
                    .sources
                    .get(p.span.file)
                    .unwrap()
                    .line_col(p.span.start);
                (
                    d.code,
                    loc.line as usize,
                    loc.column as usize,
                    p.text.as_str(),
                )
            })
            .collect();
        if actual
            != [(
                Some(C::E0401),
                line,
                column,
                "expected `String`, found `Integer`",
            )]
        {
            mismatches.push(format!("{body}: {diagnostics:#?}"));
        }
    }
    assert!(mismatches.is_empty(), "{}", mismatches.join("\n"));
}
#[test]
fn declaration_flow_keeps_variable_use_failures_at_the_argument() {
    // 関門: 宣言で型が決まった変数を使う側の診断を、引数の位置と型の向きで守る。
    // 既存の部分式のテストには変数の引数がなく、宣言への誤った移し替えを捕まえられない。
    // 型検査の入口で確かめ、テスト用の差し込み口は加えない。
    // 束縛と宣言が一致するときは、最初の引数の誤りから後続の報告を抑える。
    // 一回だけ変数を使う既存の例では、報告の増加や別の誤りへの入れ替わりを捕まえられない。
    let callee = "function g(x: String) -> Integer\n  return 1\nend function\n\n";
    for (body, line, column) in [
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind _ <- g(s)\n  return s\nend function\n",
            7,
            15,
        ),
        (
            "function f(c: Boolean, n: Integer) -> Integer\n  bind s <- n\n  if c then\n    return s\n  end if\n  return g(s)\nend function\n",
            10,
            12,
        ),
        (
            "function f(c: Boolean, n: Integer) -> Integer\n  bind s <- n\n  if c then\n    return g(s)\n  end if\n  return s\nend function\n",
            8,
            14,
        ),
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind _ <- g(s)\n  bind z <- [s, \"x\"]\n  return s\nend function\n",
            7,
            15,
        ),
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind _ <- g(s)\n  bind z <- s + \"x\"\n  return s\nend function\n",
            7,
            15,
        ),
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind _ <- g(s)\n  bind z <- s < \"x\"\n  return s\nend function\n",
            7,
            15,
        ),
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind _ <- g(s)\n  bind _ <- s(1)\n  return s\nend function\n",
            7,
            15,
        ),
    ] {
        let source = format!("{callee}{body}");
        let diagnostics = expect(&source, &[(C::E0401, line, column)]);
        let diag = &diagnostics[0];
        assert_eq!(
            diag.primary.as_ref().unwrap().text,
            "expected `String`, found `Integer`"
        );
        assert!(
            !diag
                .notes
                .iter()
                .any(|n| n.contains("declared return type")),
            "{diag:?}"
        );
    }
}

#[test]
fn conflicting_declaration_flows_report_the_annotation_once() {
    // 関門: 宣言どうしが食い違うとき、値を定める束縛の誤りを先に示し、派生した報告を抑える。
    // 既存の戻り値のテストには二つの宣言の流れ込みがなく、注釈の理由の取り違えに届かない。
    // 型検査の入口で、戻り値の型と宣言の順序を変えて確かめる。差し込み口は不要。
    for (source, line) in [
        (
            "function f(n: Integer) -> Integer\n  bind s <- n\n  bind t: String <- s\n  return s\nend function\n",
            3,
        ),
        (
            "function f(n: Integer) -> Unit\n  bind s <- n\n  bind t: String <- s\n  return s\nend function\n",
            3,
        ),
        (
            "function f(c: Boolean, n: Integer) -> Integer\n  bind s <- n\n  if c then\n    return s\n  end if\n  bind t: String <- s\n  return s\nend function\n",
            6,
        ),
    ] {
        let diagnostics = expect(source, &[(C::E0401, line, 21)]);
        let diag = &diagnostics[0];
        assert_eq!(
            diag.primary.as_ref().unwrap().text,
            "expected `String`, found `Integer`"
        );
        assert!(
            diag.notes.iter().any(|n| n.contains("type annotation")),
            "{diag:?}"
        );
        assert!(
            !diag
                .notes
                .iter()
                .any(|n| n.contains("declared return type")),
            "{diag:?}"
        );
    }
}

#[test]
fn declaration_flow_preserves_inner_failure_positions_and_repairs() {
    // 宣言の型への流れ込みの内側では、部分式の位置と整数リテラルの修正案を保つ。
    for source in [
        "function f(value: Float) -> Float\n return value * 2\nend function\n",
        "function f(value: Float) -> Unit\n bind x: Float <- value * 2\nend function\n",
        "function f(value: Float, c: Boolean) -> Float\n return if c then value else 2 end if\nend function\n",
        "function f(value: Float, c: Boolean) -> Float\n return match c with\n case true -> value\n case false -> value * 2\n end match\nend function\n",
    ] {
        let (_, _, _, diagnostics) = check(source);
        assert_eq!(diagnostics.len(), 1, "{diagnostics:#?}");
        let diag = &diagnostics[0];
        assert_eq!(diag.code, Some(C::E0401));
        let span = diag.primary.as_ref().unwrap().span;
        assert_eq!(&source[span.start.0 as usize..span.end.0 as usize], "2");
        assert_eq!(diag.helps[0].edits[0].replacement, "2.0");
        assert_eq!(diag.helps[0].edits[0].span, span);
        assert!(
            !diag
                .notes
                .iter()
                .any(|n| n.contains("declared return type") || n.contains("type annotation"))
        );
    }
}

#[test]
fn unreachable_statements_are_reported_once_per_block_in_effect_children() {
    // spec: 01-06 必ず抜ける文
    // 関門: 型検査の診断数と最初の後続文の位置を守る。既存の一文だけの例では、
    // 重複とエフェクトの子の見落としを捕まえられない。CLI の診断全体はゴールデンで守る。
    let effect = "effect Ask\n function ask() -> Integer\nend effect\n";
    for (source, line) in [
        (
            "function f() -> Integer\n return handle\n  return 1\n  bind y <- 5\n  1\n with\n case ask() -> resume(1)\n end handle\nend function\n",
            7,
        ),
        (
            "function f() -> Integer\n return handle ask() with\n case ask() ->\n  return 2\n  bind z <- 6\n  2\n end handle\nend function\n",
            8,
        ),
        (
            "function f() -> Integer\n return handle ask() with\n case ask() -> resume(if true then\n  return 2\n  bind z <- 6\n  2\n else\n  1\n end if)\n end handle\nend function\n",
            8,
        ),
    ] {
        expect(&format!("{effect}{source}"), &[(C::E0439, line, 3)]);
    }
    expect(
        "function f() -> Option[Integer]\n bind n <- try (match true with\n case true ->\n  return Option.None\n  bind w <- 1\n  Option.Some(1)\n case false -> Option.Some(2)\n end match)\n return Option.Some(n)\nend function\n",
        &[(C::E0439, 5, 3)],
    );
}
#[test]
fn unreachable_statements_are_reported_once_per_block() {
    // spec: 01-06 必ず抜ける文
    // 関門: 後続文の数によらず一度だけ報告し、入れ子とラムダの独立した検査を守る。
    expect(
        "function f() -> Unit\n return ()\n bind x <- 1\n return ()\n bind y <- 2\nend function\n",
        &[(C::E0439, 3, 2)],
    );
    // 外側が到達しなくても内側のブロックを検査し、それぞれ最初の文だけを報告する。
    expect(
        "function f() -> Unit\n return ()\n if true then\n  return ()\n  bind x <- 1\n  bind y <- 2\n end if\n ()\nend function\n",
        &[(C::E0439, 3, 2), (C::E0439, 5, 3)],
    );
    // ラムダは固有の戻り値の検査で辿るため、外側の走査で二重に報告しない。
    expect(
        "function f() -> Unit\n bind g <- lambda()\n  return ()\n  bind x <- 1\n end lambda\nend function\n",
        &[(C::E0439, 4, 3)],
    );
}
#[test]
fn effect_inference_names_and_stubs() {
    let choose = "import Benitoite.Unofficial.IO.Console\nfunction choose[effect E](unused: function() -> Unit uses Console.Write, E, act: function() -> Unit uses E) -> Unit uses E\n act()\nend function\nfunction main() -> Unit\n choose(lambda() Console.writeLine(\"unused\") end lambda, lambda() () end lambda)\nend function\n";
    clean(choose);
    let effectful = choose.replace(
        "lambda() () end lambda",
        "lambda() Console.writeLine(\"called\") end lambda",
    );
    expect(&effectful, &[(C::E0501, 6, 67)]);
    let (l, r, t, d) = check(
        "import Benitoite.Unofficial.IO.Console\nfunction f() -> Unit uses IO.All\n Console.writeLine(\"hi\")\nend function\n",
    );
    assert_eq!(
        d.iter().map(|d| d.code.unwrap()).collect::<Vec<_>>(),
        [C::W0501]
    );
    assert_output_nodes(&l, &t);
    let s = t.decl_types.get(id(&r, "f")).unwrap();
    assert!(s.wrote_io_all);
    assert!(s.effects.names.contains(&EffectName::Builtin(
        crate::types::builtin::find_builtin_effect(&["IO", "Console"], "Write").unwrap()
    )));
    assert!(
        !s.effects
            .names
            .contains(&EffectName::Builtin(BuiltinEffectId::IO_ALL))
    );
    let (_, r, t) = clean(
        "effect Write\n function write(s: String) -> Unit\nend effect\nfunction f() -> Unit uses Write\n write(\"hello\")\nend function\n",
    );
    assert_eq!(
        t.effects.get(id(&r, "Write")).unwrap().name,
        EffectName::User(id(&r, "Write"))
    );
    let d = expect(
        "effect Write\n function write(s: String) -> Unit\nend effect\nfunction f() -> Unit\n write(\"hi\")\nend function\n",
        &[(C::E0501, 5, 2)],
    );
    assert!(d[0].message.contains("Write"));
    expect(
        "function f[effect E, effect F](a: function() -> Unit uses E, b: function() -> Unit uses F) -> Unit uses E, F\nend function\n",
        &[(C::E0417, 1, 100)],
    );
    expect(
        "function f[effect E]() -> Unit uses E\nend function\n",
        &[(C::E0418, 1, 19)],
    );
    expect(
        "function f[F[_]](x: F) -> Unit\nend function\n",
        &[(C::E0426, 1, 21)],
    );
    clean(
        "trait Show[T]\n function show(x: T) -> String\nend trait\neffect Log\n function write(s: String) -> Unit\nend effect\nfunction f[T: Show](x: T) -> Unit\n bind _ <- lazy 1 end lazy\n bind _ <- handle write(\"hi\") with\n  case write(s) -> ()\n end handle\nend function\n",
    );
}
#[test]
fn data_without_constructors_is_reported_by_the_type_checker() {
    // 構文解析器は空の宣言を読み、型検査だけが E0411 を報告する（01-05）。
    expect("data Empty\nend data\n", &[(C::E0411, 1, 6)]);
}
#[test]
fn zero_field_constructors_and_signed_literal_outputs() {
    let s = "data Tree\n Leaf\nend data\nfunction f(t: Tree) -> Unit\n bind _ <- Tree.Leaf()\n bind _ <- match t with\n  case Tree.Leaf() -> ()\n end match\nend function\n";
    let d = expect(s, &[(C::E0413, 5, 12), (C::E0413, 7, 8)]);
    for d in d {
        assert_eq!(d.helps[0].edits[0].replacement, "");
        assert_eq!(
            &s[d.helps[0].edits[0].span.start.0 as usize..d.helps[0].edits[0].span.end.0 as usize],
            "()"
        );
    }
    expect(
        "data Box[T]\n Box(T)\nend data\nfunction f(b: Box[Integer]) -> Unit\n bind _ <- match b with\n  case Box.Box(x, y) -> x + y\n end match\nend function\n",
        &[(C::E0412, 6, 8)],
    );
    let s =
        "function f() -> Unit\n bind _ <- -9223372036854775808\n bind _ <- -1.00m\nend function\n";
    let (l, _, t) = clean(s);
    let n = node_at(&l, s.find("-922").unwrap());
    assert!(matches!(t.lit_values.get(n), Some(V::Integer(i64::MIN))));
    let n = node_at(&l, s.find("-1.00").unwrap());
    assert!(matches!(t.lit_values.get(n),Some(V::Decimal(d)) if d.mantissa()== -100&&d.scale()==2));
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

#[test]
fn higher_kinded_instantiation_and_equatable_declaration_summaries() {
    let s = "function transform[F[_], A](x: F[A], f: function(F[A]) -> F[A]) -> F[A]\n return f(x)\nend function\nfunction main() -> Unit\n bind n <- transform(Option.Some(1), lambda(x) return x end lambda)\nend function\n";
    let (l, r, t) = clean(s);
    let call = s.rfind("transform(").unwrap();
    let node = node_at(&l, call);
    assert_eq!(
        t.type_args.get(node).unwrap().tys,
        [
            TypeArg::Head(crate::types::TyHead::Con(TyCon::Adt(
                r.stdlib("Benitoite.Option.Option").unwrap()
            ))),
            TypeArg::Ty(Ty::Con(TyCon::Builtin(B::INTEGER), vec![]))
        ]
    );
    clean(
        "data A[T]\n End\n Next(B[T])\nend data\ndata B[T]\n B(T, A[T])\nend data\nfunction equalTrees(a: A[Integer], b: A[Integer]) -> Boolean\n return a = b\nend function\n",
    );
    expect(
        "data Box[T]\n Box(T)\nend data\nfunction f(x: Box[function() -> Unit]) -> Unit\n bind _ <- x = x\nend function\n",
        &[(C::E0406, 5, 12)],
    );
    expect(
        "import Benitoite.Set\nfunction f() -> Unit\n bind _ <- Set.fromList([1.0])\nend function\n",
        &[(C::E0423, 3, 12)],
    );
    expect(
        "function transform[F[_], A](x: F[A]) -> F[A]\n return x\nend function\nfunction f() -> Unit\n bind _ <- transform(Result.Ok(1))\nend function\n",
        &[(C::E0401, 5, 22)],
    );
}

#[test]
fn constant_collections_numeric_semantics_and_golden_examples() {
    for s in [
        include_str!("../../testdata/types/first-release-records.bnt"),
        include_str!("../../testdata/types/first-release-constants.bnt"),
        include_str!("../../testdata/types/first-release-aliases.bnt"),
        include_str!("../../testdata/types/first-release-decimal.bnt"),
    ] {
        let (l, _, t, d) = check_files(&[("main.bnt", s)], true);
        assert!(d.is_empty(), "{d:#?}");
        assert_output_nodes(&l, &t);
    }
    let (_, r, t) = clean(
        r#"import Benitoite.Map
import Benitoite.Set
const nested: Set[List[Integer]] = Set.fromList([[1, 2], [1], [0]])
const tagged: Set[Option[Integer]] = Set.fromList([Option.None, Option.Some(3), Option.Some(1)])
const sets: Set[Set[Integer]] = Set.fromList([Set.fromList([2]), Set.empty()])
const maps: Set[Map[Integer, Integer]] = Set.fromList([Map.fromList([Pair(2, 5)]), Map.empty()])
const emptyMap: Map[Integer, String] = Map.empty()
const forward: Integer = later + 1
const later: Integer = 3
const ieee: String = "${0.0 / 0.0} ${1.0 / 0.0} ${-1.0 / 0.0}"
const unordered: Boolean = [0.0 / 0.0] = [0.0 / 0.0]
const zeroSigns: Boolean = -0.0 = 0.0
const shortCircuit: Boolean = false and (1 div 0 = 0)
const literal: Character = 'あ'
const pair: Pair[Integer, String] = Pair(1, "a")
"#,
    );
    assert!(matches!(constant(&r, &t, "forward"), V::Integer(4)));
    assert!(matches!(constant(&r,&t,"ieee"),V::String(s) if s=="NaN Infinity -Infinity"));
    assert!(matches!(constant(&r, &t, "unordered"), V::Boolean(false)));
    assert!(matches!(constant(&r, &t, "zeroSigns"), V::Boolean(true)));
    assert!(matches!(
        constant(&r, &t, "shortCircuit"),
        V::Boolean(false)
    ));
    let V::Set(v) = constant(&r, &t, "nested") else {
        panic!()
    };
    assert!(matches!(&v[0],V::List(v) if matches!(v.as_slice(),[V::Integer(0)])));
    assert!(matches!(&v[1],V::List(v) if matches!(v.as_slice(),[V::Integer(1)])));
    let V::Set(v) = constant(&r, &t, "tagged") else {
        panic!()
    };
    assert!(matches!(&v[0],V::Ctor { tag:0,args,.. } if matches!(args.as_slice(),[V::Integer(1)])));
    assert!(matches!(&v[2], V::Ctor { tag: 1, .. }));
    let V::Set(v) = constant(&r, &t, "sets") else {
        panic!()
    };
    assert!(matches!(&v[0],V::Set(s) if s.is_empty()));
    let V::Set(v) = constant(&r, &t, "maps") else {
        panic!()
    };
    assert!(matches!(&v[0],V::Map(s) if s.is_empty()));
    expect(
        "const a: Integer = -9223372036854775808 div -1\n",
        &[(C::E0435, 1, 20)],
    );
    expect("const a: Decimal = 1m / 0m\n", &[(C::E0435, 1, 20)]);
    expect(
        "const a: Decimal = 79228162514264337593543950335m + 1m\n",
        &[(C::E0435, 1, 20)],
    );
}

#[test]
fn source_diagnostics_and_constant_type_parameters() {
    // 通常のソースでは自由な T を名前解決が拒む。出力の表の境界に型パラメータが
    // 渡された場合も E0434 にする契約を、同じ読み込みと名前解決から作った表で確かめる。
    let (l, mut r, _) = clean("type Identity[T] = T\nconst a: Integer = 1\n");
    let Item::Const(c) = &l.asts[0].decls[1].item else {
        panic!()
    };
    let parameter = r
        .bindings
        .iter()
        .find(|(_, b)| matches!(b.kind, crate::resolve::BindingKind::TypeParam { .. }))
        .unwrap()
        .0;
    r.refs.insert(c.ty.id(), parameter);
    let (_, d) = super::typecheck(&l.modules, &l.asts, &l.sources, &r, false);
    assert_eq!(d.len(), 1);
    assert_eq!(d[0].code, Some(C::E0434));
    let span = d[0].primary.as_ref().unwrap().span;
    let p = l.sources.get(span.file).unwrap().line_col(span.start);
    assert_eq!((p.line, p.column), (2, 10));
    let (_, _, _, d) = check("function f() -> Unit\n bind _ <- (\nend function\n");
    assert!(d.iter().any(Diagnostic::is_error));
}

#[test]
fn effect_flow_direction_call_errors_and_float_fix() {
    expect(
        "import Benitoite.Unofficial.IO.Console\nfunction f() -> Unit\n bind x <- lambda() -> Unit uses State Console.writeLine(\"hi\") end lambda\nend function\n",
        &[(C::E0502, 3, 40)],
    );
    let s = "function f(x: Float) -> Unit\nend function\nfunction g() -> Unit\n f(0x10)\nend function\n";
    let d = expect(s, &[(C::E0401, 4, 4)]);
    let edit = &d[0].helps[0].edits[0];
    assert_eq!(edit.replacement, "16.0");
    assert_eq!(
        &s[edit.span.start.0 as usize..edit.span.end.0 as usize],
        "0x10"
    );
    let d = expect(
        "function f(x: Integer) -> Unit\nend function\nfunction g() -> Unit\n f()\nend function\n",
        &[(C::E0402, 4, 2)],
    );
    assert!(d[0].message.contains("takes 1"), "{d:#?}");
    assert!(d[0].message.contains("0 were supplied"));
    expect(
        "function f() -> Unit\n bind g <- lambda(x) return x(x) end lambda\nend function\n",
        &[(C::E0404, 2, 31)],
    );
    clean(
        "function f() -> Unit\n bind g <- lambda() () end lambda\n bind _ <- g()\nend function\n",
    );
    clean(
        "function f() -> Boolean\n return match Byte.fromInteger(1) with\n  case Option.Some(b) -> b < b or b = b\n  case Option.None -> false\n end match\nend function\n",
    );
}
// spec: 01-02 部分適用のプレースホルダ
// 関門: callee 内の return も生成する関数を抜ける。引数側の CLI テストでは届かない境界であり、
// 外側の String と照合する退行を型検査の公開入口で捕まえる。差し込み口は不要。
#[test]
fn placeholder_callee_return_uses_generated_function_boundary() {
    clean(
        "function add(a: Integer, b: Integer) -> Integer\n return a + b\nend function\nfunction make() -> String\n bind f <- (if true then return 5 else add end if)(_, 1)\n return Integer.toString(f(2))\nend function\n",
    );
}

// return の値が呼び出しのとき、戻り値の型の食い違いを、関数でない値の呼び出し（E0403）ではなく
// return の理由の型の食い違い（E0401）として報告する（設計書 02-05「誤りの報告と検査の継続」、FE403）。
#[test]
fn return_call_mismatch_reports_return_reason() {
    for (s, line, col, expected, found) in [
        (
            "function main() -> Unit\n return Integer.toString(1)\nend function\n",
            2,
            9,
            "Unit",
            "String",
        ),
        (
            "function main() -> Unit\n return List.reverse([1])\nend function\n",
            2,
            9,
            "Unit",
            "List[Integer]",
        ),
        (
            "function rev[T](xs: List[T]) -> List[T]\n return xs\nend function\nfunction f() -> String\n return rev([1])\nend function\n",
            5,
            9,
            "String",
            "List[Integer]",
        ),
    ] {
        let d = expect(s, &[(C::E0401, line, col)]);
        let text = d[0].primary.as_ref().unwrap().text.clone();
        assert!(text.contains(expected) && text.contains(found), "{text}");
        assert!(
            d[0].notes
                .iter()
                .any(|n| n.contains("declared return type")),
            "{:?}",
            d[0].notes
        );
    }
    expect(
        "function f() -> Unit\n bind x <- 1\n return x()\nend function\n",
        &[(C::E0403, 3, 9)],
    );
}
// 宣言の戻り値の型で決まる総称の呼び出しは、戻り値の型をその場で比べ、引数の位置の誤りと
// 修正案を保つ（設計書 02-05「制約の解決」の手順 1、FE403 の退行の防止）。
#[test]
fn return_call_keeps_argument_position_diagnostics() {
    let id = "function id[T](x: T) -> T\n return x\nend function\n";
    let d = expect(
        &format!("{id}function d() -> Float\n return id(1)\nend function\n"),
        &[(C::E0401, 5, 12)],
    );
    assert!(!d[0].helps.is_empty(), "{:?}", d[0]);
    let d = expect(
        "function e() -> Option[Float]\n return Option.Some(1)\nend function\n",
        &[(C::E0401, 2, 21)],
    );
    assert!(!d[0].helps.is_empty(), "{:?}", d[0]);
    expect(
        "function j(xs: List[Integer]) -> List[String]\n return List.map(xs, lambda(n) return n + 1 end lambda)\nend function\n",
        &[(C::E0401, 2, 39)],
    );
    expect(
        "function g() -> Unit\n bind o: Option[String] <- Option.Some(1)\nend function\n",
        &[(C::E0401, 2, 40)],
    );
}

#[test]
fn width_literals_keep_their_exact_types_and_values() {
    let (_, resolved, typed) = clean(
        "const integer: Integer64 = -9223372036854775808s64\nconst float: Float64 = -1.5f64\nconst byte: UnsignedInteger8 = 0xffu8\n",
    );
    assert!(matches!(
        constant(&resolved, &typed, "integer"),
        V::Integer(i64::MIN)
    ));
    assert!(matches!(constant(&resolved, &typed, "float"), V::Float(n) if *n == -1.5));
    assert!(matches!(constant(&resolved, &typed, "byte"), V::Byte(255)));
    // 新しい型を旧値に置き換えると、リテラルの型と値の表が食い違う。
    for (literal, name, builtin) in [
        ("-128s8", "Integer8", B::INTEGER8),
        ("32767s16", "Integer16", B::INTEGER16),
        ("42s32", "Integer32", B::INTEGER32),
        ("42u16", "UnsignedInteger16", B::UNSIGNED_INTEGER16),
        ("42u32", "UnsignedInteger32", B::UNSIGNED_INTEGER32),
        (
            "18446744073709551615u64",
            "UnsignedInteger64",
            B::UNSIGNED_INTEGER64,
        ),
        ("1e-3f32", "Float32", B::FLOAT32),
    ] {
        let source = format!("function f() -> {name}\n return {literal}\nend function\n");
        let (loaded, _, typed, diagnostics) = check(&source);
        assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
        let node = node_at(&loaded, source.find(literal).unwrap());
        assert_eq!(
            typed.expr_types.get(node),
            Some(&Ty::Con(TyCon::Builtin(builtin), vec![]))
        );
        assert!(typed.lit_values.get(node).is_some());
    }
    for (literal, name, code) in [
        ("256u8", "Byte", C::E0446),
        ("-0u8", "Byte", C::E0405),
        ("-1u8", "Byte", C::E0405),
        ("9223372036854775808s64", "Integer", C::E0408),
        ("-(9223372036854775808s64)", "Integer", C::E0408),
        ("1e999f64", "Float", C::E0409),
    ] {
        let source = format!("function f() -> {name}\n return {literal}\nend function\n");
        let (_, _, _, diagnostics) = check(&source);
        assert_eq!(diagnostics.len(), 1, "{source}: {diagnostics:?}");
        assert_eq!(diagnostics[0].code, Some(code));
    }
}

// 型の検査結果を境界にし、字句の受理だけでは見つからない幅の取り違えと丸めを確かめる。
fn assert_width_value(actual: &V, expected: &V) {
    match (actual, expected) {
        (V::Integer8(a), V::Integer8(b)) => assert_eq!(a, b),
        (V::Integer16(a), V::Integer16(b)) => assert_eq!(a, b),
        (V::Integer32(a), V::Integer32(b)) => assert_eq!(a, b),
        (V::UnsignedInteger16(a), V::UnsignedInteger16(b)) => assert_eq!(a, b),
        (V::UnsignedInteger32(a), V::UnsignedInteger32(b)) => assert_eq!(a, b),
        (V::UnsignedInteger64(a), V::UnsignedInteger64(b)) => assert_eq!(a, b),
        (V::Float32(a), V::Float32(b)) => assert_eq!(a.to_bits(), b.to_bits()),
        _ => panic!("different numeric types: {actual:?}, {expected:?}"),
    }
}

#[test]
fn width_integer_literals_check_both_boundaries_and_record_exact_values() {
    for (suffix, name, builtin, low, minimum, high, maximum, below, above) in [
        (
            "s8",
            "Integer8",
            B::INTEGER8,
            "-128",
            V::Integer8(-128),
            "127",
            V::Integer8(127),
            "-129",
            "128",
        ),
        (
            "s16",
            "Integer16",
            B::INTEGER16,
            "-32768",
            V::Integer16(-32768),
            "32767",
            V::Integer16(32767),
            "-32769",
            "32768",
        ),
        (
            "s32",
            "Integer32",
            B::INTEGER32,
            "-2147483648",
            V::Integer32(-2147483648),
            "2147483647",
            V::Integer32(2147483647),
            "-2147483649",
            "2147483648",
        ),
        (
            "u16",
            "UnsignedInteger16",
            B::UNSIGNED_INTEGER16,
            "0",
            V::UnsignedInteger16(0),
            "65535",
            V::UnsignedInteger16(65535),
            "-1",
            "65536",
        ),
        (
            "u32",
            "UnsignedInteger32",
            B::UNSIGNED_INTEGER32,
            "0",
            V::UnsignedInteger32(0),
            "4294967295",
            V::UnsignedInteger32(4294967295),
            "-1",
            "4294967296",
        ),
        (
            "u64",
            "UnsignedInteger64",
            B::UNSIGNED_INTEGER64,
            "0",
            V::UnsignedInteger64(0),
            "18446744073709551615",
            V::UnsignedInteger64(18446744073709551615),
            "-1",
            "18446744073709551616",
        ),
    ] {
        for (digits, expected) in [(low, &minimum), (high, &maximum)] {
            let literal = format!("{digits}{suffix}");
            let source = format!("function f() -> {name}\n return {literal}\nend function\n");
            let (loaded, _, typed, diagnostics) = check(&source);
            assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
            let node = node_at(&loaded, source.find(&literal).unwrap());
            assert_eq!(
                typed.expr_types.get(node),
                Some(&Ty::Con(TyCon::Builtin(builtin), vec![]))
            );
            assert_width_value(typed.lit_values.get(node).unwrap(), expected);
        }
        for digits in [below, above] {
            let literal = format!("{digits}{suffix}");
            let source = format!("function f() -> {name}\n return {literal}\nend function\n");
            let (loaded, _, typed, diagnostics) = check(&source);
            let node = node_at(&loaded, source.find(&literal).unwrap());
            assert!(typed.lit_values.get(node).is_none(), "{source}");
            let range = diagnostics.iter().find(|d| d.code == Some(C::E0447));
            if suffix.starts_with('s') || digits == above {
                let range = range.unwrap_or_else(|| panic!("{source}: {diagnostics:?}"));
                assert!(range.notes[0].contains(&format!("from {low} to {high}")));
            } else {
                assert!(range.is_none());
                assert_eq!(diagnostics.len(), 1, "{diagnostics:?}");
                assert_eq!(diagnostics[0].code, Some(C::E0405));
            }
        }
    }
    // u64 の上半分の値を各基数で読み、i64 へ縮めずに保存する。
    for literal in [
        "9223372036854775808u64",
        "0x8000000000000000u64",
        "0o1000000000000000000000u64",
        "0b1000000000000000000000000000000000000000000000000000000000000000u64",
    ] {
        let source =
            format!("function f() -> UnsignedInteger64\n return {literal}\nend function\n");
        let (loaded, _, typed, diagnostics) = check(&source);
        assert!(diagnostics.is_empty(), "{diagnostics:?}");
        assert_width_value(
            typed
                .lit_values
                .get(node_at(&loaded, source.find(literal).unwrap()))
                .unwrap(),
            &V::UnsignedInteger64(9223372036854775808),
        );
    }
}

#[test]
fn width_float_literals_round_directly_to_binary32() {
    for (literal, bits) in [
        ("3.4028234663852886e38f32", 0x7f7fffff),
        ("-3.4028234663852886e38f32", 0xff7fffff),
        ("1.401298464324817e-45f32", 1),
        ("1e-100f32", 0),
        ("-1e-100f32", 0x80000000),
        ("-0.0f32", 0x80000000),
        // f64 で先に丸めると、ちょうど中点となって 1.0 に丸められてしまう。
        ("1.0000000596046448f32", 0x3f800001),
    ] {
        let source = format!("function f() -> Float32\n return {literal}\nend function\n");
        let (loaded, _, typed, diagnostics) = check(&source);
        assert!(diagnostics.is_empty(), "{diagnostics:?}");
        assert_width_value(
            typed
                .lit_values
                .get(node_at(&loaded, source.find(literal).unwrap()))
                .unwrap(),
            &V::Float32(f32::from_bits(bits)),
        );
    }
    for literal in ["3.4028236e38f32", "-3.4028236e38f32", "1e999f32"] {
        let source = format!("function f() -> Float32\n return {literal}\nend function\n");
        let (loaded, _, typed, diagnostics) = check(&source);
        assert!(
            diagnostics.iter().any(|d| d.code == Some(C::E0448)),
            "{diagnostics:?}"
        );
        assert!(
            typed
                .lit_values
                .get(node_at(&loaded, source.find(literal).unwrap()))
                .is_none()
        );
    }
}

#[test]
fn width_integer_division_waits_for_operands_and_defaults_unconstrained_lambdas() {
    for op in ["div", "mod"] {
        for suffix in ["s8", "s16", "s32", "u16", "u32", "u64", ""] {
            let source = format!(
                "function f() -> Unit\n bind calculate <- lambda(a, b) return a {op} b end lambda\n bind _ <- calculate(5{suffix}, 2{suffix})\nend function\n"
            );
            clean(&source);
        }
        let source = format!(
            "function f() -> Unit\n bind calculate <- lambda(a, b) return a {op} b end lambda\nend function\n"
        );
        let (loaded, _, typed) = clean(&source);
        let operand = node_at(&loaded, source.find(&format!("a {op} b")).unwrap());
        assert_eq!(
            typed.expr_types.get(operand),
            Some(&Ty::Con(TyCon::Builtin(B::INTEGER), vec![]))
        );
    }
}

#[test]
fn width_operators_accept_matching_types_and_reject_invalid_uses() {
    for name in [
        "Integer8",
        "Integer16",
        "Integer32",
        "UnsignedInteger16",
        "UnsignedInteger32",
        "UnsignedInteger64",
        "Float32",
    ] {
        let ops = if name == "Float32" {
            vec!["+", "-", "*", "/", "=", "<>", "<", "<=", ">", ">="]
        } else {
            vec!["+", "-", "*", "div", "mod", "=", "<>", "<", "<=", ">", ">="]
        };
        for op in ops {
            let comparison = matches!(op, "=" | "<>" | "<" | "<=" | ">" | ">=");
            let result = if comparison { "Boolean" } else { name };
            let source = format!(
                "function f(a: {name}, b: {name}) -> {result}\n return a {op} b\nend function\n"
            );
            let (_, _, _, diagnostics) = check(&source);
            assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
        }
        let source = format!("function f(a: {name}) -> {name}\n return -a\nend function\n");
        let (_, _, _, diagnostics) = check(&source);
        if name.starts_with("Integer") || name == "Float32" {
            assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
            continue;
        }
        assert_eq!(diagnostics.len(), 1, "{source}: {diagnostics:?}");
        assert_eq!(diagnostics[0].code, Some(C::E0405));
    }
    for (name, expr) in [
        ("Byte", "a + a"),
        ("Byte", "a - a"),
        ("Byte", "a * a"),
        ("Byte", "-a"),
        ("Float32", "a div a"),
        ("Integer32", "a / a"),
    ] {
        let source = format!("function f(a: {name}) -> {name}\n return {expr}\nend function\n");
        let (_, _, _, diagnostics) = check(&source);
        assert!(
            diagnostics
                .iter()
                .any(|d| d.code == Some(C::E0405) || d.code == Some(C::E0401)),
            "{source}: {diagnostics:?}"
        );
        assert!(
            diagnostics
                .iter()
                .all(|d| matches!(d.code, Some(C::E0405 | C::E0401))),
            "{diagnostics:?}"
        );
    }
    for (literal, name) in [
        ("-(128s8)", "Integer8"),
        ("-(32768s16)", "Integer16"),
        ("-(2147483648s32)", "Integer32"),
    ] {
        let source = format!("function f() -> {name}\n return {literal}\nend function\n");
        let (_, _, _, diagnostics) = check(&source);
        assert!(
            diagnostics.iter().any(|d| d.code == Some(C::E0447)),
            "{diagnostics:?}"
        );
    }
    for (name, suffix) in [
        ("UnsignedInteger16", "u16"),
        ("UnsignedInteger32", "u32"),
        ("UnsignedInteger64", "u64"),
    ] {
        let source = format!("function f() -> {name}\n return -0{suffix}\nend function\n");
        let (_, _, _, diagnostics) = check(&source);
        assert_eq!(diagnostics.len(), 1, "{diagnostics:?}");
        assert_eq!(diagnostics[0].code, Some(C::E0405));
    }
    for source in [
        "function f() -> Integer32\n return 1\nend function\n",
        "function f() -> Integer\n return 1s32\nend function\n",
        "function f(a: Integer32, b: Integer) -> Integer32\n return a + b\nend function\n",
        "function f(a: Integer32, b: Integer16) -> Boolean\n return a = b\nend function\n",
        "function f(a: Float32, b: Float) -> Boolean\n return a < b\nend function\n",
    ] {
        let (_, _, _, diagnostics) = check(source);
        let mismatch = diagnostics
            .iter()
            .find(|d| d.code == Some(C::E0401))
            .unwrap_or_else(|| panic!("{source}: {diagnostics:?}"));
        assert!(
            mismatch
                .helps
                .iter()
                .any(|h| h.message.contains("suffix") && h.message.contains("explicitly convert")),
            "{mismatch:?}"
        );
    }
}

#[test]
fn width_keys_reject_float32_and_accept_integers_and_interpolation() {
    for (decls, name, code) in [
        ("", "Float32", Some(C::E0423)),
        (
            "record Key\n value: Float32\nend record\n",
            "Key",
            Some(C::E0423),
        ),
        ("data Key\n Key(Float32)\nend data\n", "Key", Some(C::E0423)),
        (
            "data Key[T]\n Key(T)\nend data\n",
            "Key[Float32]",
            Some(C::E0423),
        ),
        ("", "Integer8", None),
        ("", "UnsignedInteger64", None),
        ("", "List[Integer16]", None),
        ("record Key\n value: Integer32\nend record\n", "Key", None),
        (
            "data Key\n End\n Next(UnsignedInteger16, Key)\nend data\n",
            "Key",
            None,
        ),
        (
            "data Key[T]\n Key(T)\nend data\n",
            "Key[UnsignedInteger32]",
            None,
        ),
    ] {
        let source = format!(
            "import Benitoite.Set\n{decls}function f() -> Set[{name}]\n return Set.empty()\nend function\n"
        );
        let (_, _, _, diagnostics) = check(&source);
        if let Some(code) = code {
            assert_eq!(diagnostics.len(), 1, "{source}: {diagnostics:?}");
            assert_eq!(diagnostics[0].code, Some(code));
            assert!(!diagnostics[0].helps.is_empty());
        } else {
            assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
        }
    }
    clean(
        "import Benitoite.Set\ndata Phantom[T]\n Phantom\nend data\nfunction f() -> Set[Phantom[Integer8]]\n return Set.empty()\nend function\n",
    );
    for name in [
        "Integer8",
        "Integer16",
        "Integer32",
        "UnsignedInteger16",
        "UnsignedInteger32",
        "UnsignedInteger64",
        "Float32",
    ] {
        let source = format!("function f(a: {name}) -> String\n return \"${{a}}\"\nend function\n");
        let (_, _, _, diagnostics) = check(&source);
        assert!(diagnostics.is_empty(), "{source}: {diagnostics:?}");
    }
}
