//! 言語の規則・後続の段への出力・診断の位置を、実際の読み込みから検査する（実装プラン F07）。
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
    // 通常のソースでは自由な T を名前解決が拒む。凍結した表の境界に型パラメータが
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
// return の値が呼び出しのとき、戻り値の型の食い違いを、関数でない値の呼び出し（E0403）ではなく
// return の理由の型の食い違い（E0401）として報告する（設計書 02-05「診断」、FE403）。
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
