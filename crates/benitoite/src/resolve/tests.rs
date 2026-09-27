//! 名前解決のテスト（作業の文書 T13「受け入れテスト」）。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)] // テストの失敗は panic で表す（07-03）

use super::*;
use crate::base::{FileId, SourceKind};
use crate::diag::DiagCode;
use crate::syntax::ast::{Expr, FnDecl, Item, LetStmt, Stmt};
use crate::syntax::lexer::lex;
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::parse;

fn parse_one(file: FileId, kind: SourceKind, src: &str, ids: &mut IdGen) -> Program {
    let lexed = lex(file, src.as_bytes());
    let out = parse(
        file,
        kind,
        resolve_newlines(lexed.tokens),
        lexed.comments,
        ids,
    );
    assert!(
        lexed.diagnostics.is_empty() && out.diagnostics.is_empty(),
        "{:?}",
        out.diagnostics
    );
    out.program
}

/// prelude のソースを解析し、利用者のソース `src` とともに解決する。
fn run(src: &str) -> (Program, ResolveOutput) {
    let mut ids = IdGen::new();
    let prelude: Vec<Program> = crate::prelude::SOURCES
        .iter()
        .enumerate()
        .map(|(i, (_, text))| {
            parse_one(
                FileId(u32::try_from(i).unwrap()),
                SourceKind::Prelude,
                text,
                &mut ids,
            )
        })
        .collect();
    let user_file = FileId(u32::try_from(prelude.len()).unwrap());
    let user = parse_one(user_file, SourceKind::User, src, &mut ids);
    let out = resolve(&prelude, &user, &mut ids);
    (user, out)
}

fn codes(out: &ResolveOutput) -> Vec<DiagCode> {
    out.diagnostics.iter().filter_map(|d| d.code).collect()
}

fn text_at(src: &str, span: crate::base::Span) -> &str {
    &src[span.start.0 as usize..span.end.0 as usize]
}

fn fn_named<'p>(p: &'p Program, name: &str) -> &'p FnDecl {
    p.items
        .iter()
        .find_map(|i| match i {
            Item::Fn(f) if f.name.text == name => Some(&**f),
            Item::Fn(_) | Item::Type(_) | Item::Error(_) => None,
        })
        .unwrap()
}

/// 本体の `i` 番目の文。
fn stmt(f: &FnDecl, i: usize) -> &Stmt {
    &f.body.stmts[i]
}

fn let_stmt(f: &FnDecl, i: usize) -> &LetStmt {
    match stmt(f, i) {
        Stmt::Let(l) => l,
        s @ (Stmt::Expr(_) | Stmt::Error(_)) => panic!("not let: {s:?}"),
    }
}

fn kind_of(out: &ResolveOutput, b: BindingId) -> BindingKind {
    out.bindings.get(b).unwrap().kind
}

/// 利用者のソースの中の、綴り `name` を持つ名前の式を全部集める。
fn name_exprs<'p>(e: &'p Expr, name: &str, acc: &mut Vec<&'p crate::syntax::ast::NameExpr>) {
    match e {
        Expr::Name(n) if n.name.text == name => acc.push(n),
        Expr::Binary(b) => {
            name_exprs(&b.lhs, name, acc);
            name_exprs(&b.rhs, name, acc);
        }
        Expr::Call(c) => {
            name_exprs(&c.callee, name, acc);
            for a in &c.args {
                if let crate::syntax::ast::Arg::Expr(x) = a {
                    name_exprs(x, name, acc);
                }
            }
        }
        Expr::Paren(p) => name_exprs(&p.inner, name, acc),
        // 以下は確かめる入力に現れない形
        Expr::Lit(_)
        | Expr::Name(_)
        | Expr::Unit(_)
        | Expr::List(_)
        | Expr::Unary(_)
        | Expr::Pipe(_)
        | Expr::Block(_)
        | Expr::If(_)
        | Expr::Match(_)
        | Expr::Lambda(_)
        | Expr::Error(_) => {}
    }
}

#[test]
fn prelude_only_has_no_diagnostics() {
    let (_, out) = run("");
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
    let p = &out.prelude;
    for b in [p.some, p.none, p.ok, p.err] {
        assert!(matches!(
            kind_of(&out, b.unwrap()),
            BindingKind::Ctor { .. }
        ));
    }
    let expected = BuiltinId::ALL.iter().filter(|b| !b.is_operator()).count();
    assert_eq!(p.builtins.len(), expected);
    assert_eq!(
        kind_of(&out, p.none.unwrap()),
        BindingKind::Ctor {
            con: TyCon::Option,
            tag: 1
        }
    );
}

#[test]
fn local_binding_and_shadowing() {
    let src = "fn f(x: Int) -> Int {\n  let x = x + 1\n  x * 2\n}\n";
    let (user, out) = run(src);
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
    let f = fn_named(&user, "f");
    let param = *out.decls.get(f.params[0].id).unwrap();
    let let_b = *out.decls.get(let_stmt(f, 0).id).unwrap();
    assert_eq!(kind_of(&out, param), BindingKind::Param);
    assert_eq!(kind_of(&out, let_b), BindingKind::Let);
    let mut rhs = Vec::new();
    name_exprs(&let_stmt(f, 0).value, "x", &mut rhs);
    assert_eq!(out.refs.get(rhs[0].id), Some(&param));
    let Stmt::Expr(last) = stmt(f, 1) else {
        panic!()
    };
    let mut after = Vec::new();
    name_exprs(last, "x", &mut after);
    assert_eq!(out.refs.get(after[0].id), Some(&let_b));
}

#[test]
fn same_block_let_replaces_and_inner_scope_ends() {
    // 同じブロックの let の置き換えと、ブロックを出ると外側の束縛が再び見えること（01-03「シャドーイング」）。
    let src = "fn normalize(text: String) -> String {\n  let text = String.trim(text)\n  let r = { let text = 1\n text }\n  text\n}\n";
    let (user, out) = run(src);
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
    let f = fn_named(&user, "normalize");
    let first_let = *out.decls.get(let_stmt(f, 0).id).unwrap();
    let Stmt::Expr(last) = stmt(f, 2) else {
        panic!()
    };
    let mut xs = Vec::new();
    name_exprs(last, "text", &mut xs);
    assert_eq!(out.refs.get(xs[0].id), Some(&first_let));
}

#[test]
fn order_independent_and_constructors() {
    let src = "\
fn main() -> Unit {
  let s = Shape.Circle(1.0)
  let a = area(s)
  let o = Some(a)
  ()
}
fn area(s: Shape) -> Float {
  match s {
    Shape.Rect(w, h) => w * h
    Shape.Circle(r) => r
  }
}
type Shape {
  Circle(Float)
  Rect(Float, Float)
}
";
    let (user, out) = run(src);
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
    // 利用者の型の構成子を指す参照: Shape.Circle（式）と、パターンの Shape.Rect と Shape.Circle
    let adt_ctors = out
        .refs
        .iter()
        .filter(|(_, b)| {
            matches!(
                kind_of(&out, **b),
                BindingKind::Ctor {
                    con: TyCon::Adt(_),
                    ..
                }
            )
        })
        .count();
    assert_eq!(adt_ctors, 3);
    let main = fn_named(&user, "main");
    let mut some = Vec::new();
    name_exprs(&let_stmt(main, 2).value, "Some", &mut some);
    assert_eq!(out.refs.get(some[0].id).copied(), out.prelude.some);
    let ty_decl = match &user.items[2] {
        Item::Type(t) => t,
        Item::Fn(_) | Item::Error(_) => panic!(),
    };
    let ty_b = *out.decls.get(ty_decl.id).unwrap();
    assert_eq!(kind_of(&out, ty_b), BindingKind::Type(TyCon::Adt(ty_b)));
    let rect = *out.decls.get(ty_decl.variants[1].id).unwrap();
    assert_eq!(
        kind_of(&out, rect),
        BindingKind::Ctor {
            con: TyCon::Adt(ty_b),
            tag: 1
        }
    );
    // 各参照が、対応する構成子の宣言の束縛を指す。
    let circle = *out.decls.get(ty_decl.variants[0].id).unwrap();
    let mut circle_expr = Vec::new();
    name_exprs(&let_stmt(main, 0).value, "Circle", &mut circle_expr);
    assert_eq!(out.refs.get(circle_expr[0].id), Some(&circle));
    let area = fn_named(&user, "area");
    let Stmt::Expr(Expr::Match(m)) = stmt(area, 0) else {
        panic!()
    };
    let arm_ids: Vec<crate::base::NodeId> = m.arms.iter().map(|a| a.pattern.id()).collect();
    assert_eq!(out.refs.get(arm_ids[0]), Some(&rect));
    assert_eq!(out.refs.get(arm_ids[1]), Some(&circle));
}

/// 一つの誤りを出す入力について、コード・主な位置の綴り・help の文を確かめる。
#[test]
fn single_errors() {
    let shape = "type Shape {\n  Circle(Float)\n}\n";
    // (入力, コード, 主な位置の綴り, help に含む文（None なら help なし）)
    let cases: Vec<(String, DiagCode, &str, Option<&str>)> = vec![
        (
            "fn f(length: Int) -> Int {\n  lenght\n}\n".into(),
            DiagCode::E0301,
            "lenght",
            Some("`length`"),
        ),
        (
            "fn f(s: String) -> Int {\n  String.length(s)\n}\n".into(),
            DiagCode::E0303,
            "length",
            Some("String.byteLength"),
        ),
        (
            "fn f(o: Option[Int]) -> Int {\n  Option.unwrap(o)\n}\n".into(),
            DiagCode::E0303,
            "unwrap",
            Some("use `Option.unwrapOr`"),
        ),
        (
            "fn f(xs: List[Int]) -> List[Int] {\n  List.dropFirst(xs)\n}\n".into(),
            DiagCode::E0303,
            "dropFirst",
            None,
        ),
        (
            "fn f(xs: List[Int]) -> List[Int] {\n  List.mapp(xs)\n}\n".into(),
            DiagCode::E0303,
            "mapp",
            Some("`map`"),
        ),
        (
            "fn f() -> Unit {\n  Lst.map\n}\n".into(),
            DiagCode::E0302,
            "Lst",
            Some("`List`"),
        ),
        (
            "fn f() -> Option[Int] {\n  Option.Some(1)\n}\n".into(),
            DiagCode::E0317,
            "Option.Some",
            Some("write `Some` instead of `Option.Some`"),
        ),
        (
            format!("{shape}fn f() -> Shape {{\n  Circle(1.0)\n}}\n"),
            DiagCode::E0304,
            "Circle",
            Some("`Shape.Circle`"),
        ),
        (
            format!(
                "{shape}fn f(s: Shape) -> Int {{\n  match s {{\n    Circle(r) => 1\n  }}\n}}\n"
            ),
            DiagCode::E0304,
            "Circle",
            Some("`Shape.Circle`"),
        ),
        (
            format!("{shape}fn f() -> Unit {{\n  Shape\n}}\n"),
            DiagCode::E0304,
            "Shape",
            None,
        ),
        (
            "fn f() -> Unit {\n  mapInto([], 1, [])\n}\n".into(),
            DiagCode::E0301,
            "mapInto",
            None,
        ),
        (
            "fn f() -> Unit {\n  IO.x\n}\n".into(),
            DiagCode::E0304,
            "IO",
            None,
        ),
        (
            "fn f[T](x: T) -> Unit {\n  T\n}\n".into(),
            DiagCode::E0304,
            "T",
            None,
        ),
        (
            "fn f[effect E]() -> Unit uses E {\n  E\n}\n".into(),
            DiagCode::E0304,
            "E",
            None,
        ),
        // 候補が複数あり、同じ距離のものは辞書式の順に、最大 3 つ示す
        (
            "fn f(abd: Int, abc: Int, abx: Int, aby: Int) -> Int {\n  ab\n}\n".into(),
            DiagCode::E0301,
            "ab",
            Some("a similar name exists: `abc`, `abd`, `abx`"),
        ),
        (
            "fn f(ab: Int, abcd: Int, xyzw: Int) -> Int {\n  abc\n}\n".into(),
            DiagCode::E0301,
            "abc",
            Some("a similar name exists: `ab`, `abcd`"),
        ),
        (
            "fn f(c: Console) -> Unit {\n  ()\n}\n".into(),
            DiagCode::E0304,
            "Console",
            None,
        ),
        (
            "type List {\n  A\n}\n".into(),
            DiagCode::E0307,
            "List",
            None,
        ),
        (
            "type Some {\n  A\n}\n".into(),
            DiagCode::E0308,
            "Some",
            None,
        ),
        (
            "fn f[Int](x: Int) -> Int {\n  x\n}\n".into(),
            DiagCode::E0313,
            "Int",
            None,
        ),
        (
            "fn f(x: IO) -> Unit {\n  ()\n}\n".into(),
            DiagCode::E0314,
            "IO",
            Some("only appear after `uses`"),
        ),
        (
            "fn f[effect E](x: E) -> Unit {\n  ()\n}\n".into(),
            DiagCode::E0314,
            "E",
            Some("only appear after `uses`"),
        ),
        (
            "fn f() -> Unit uses Int {\n  ()\n}\n".into(),
            DiagCode::E0315,
            "Int",
            None,
        ),
        (
            "fn g(h: fn(fn() -> Unit uses IO, Int) -> Unit) -> Unit {\n  ()\n}\n".into(),
            DiagCode::E0316,
            "Int",
            Some("parenthesize"),
        ),
    ];
    for (src, code, at, help) in cases {
        let (_, out) = run(&src);
        assert_eq!(codes(&out), vec![code], "{src}");
        let d = &out.diagnostics[0];
        assert_eq!(text_at(&src, d.primary.as_ref().unwrap().span), at, "{src}");
        match help {
            Some(h) => {
                assert_eq!(d.helps.len(), 1, "{src}: {:?}", d.helps);
                assert!(d.helps[0].contains(h), "{src}: {:?}", d.helps);
            }
            None => assert!(d.helps.is_empty(), "{src}: {:?}", d.helps),
        }
    }
}

#[test]
fn kind_mismatch_messages_name_both_kinds() {
    let cases = [
        (
            "fn f() -> Unit {\n  IO.x\n}\n",
            "`IO` is an effect, not a module",
        ),
        (
            "fn f[T](x: T) -> Unit {\n  T\n}\n",
            "`T` is a type parameter, not a value",
        ),
        (
            "fn f[effect E]() -> Unit uses E {\n  E\n}\n",
            "`E` is an effect variable, not a value",
        ),
        (
            "fn f(c: Console) -> Unit {\n  ()\n}\n",
            "`Console` is a module, not a type",
        ),
    ];
    for (src, message) in cases {
        let (_, out) = run(src);
        assert_eq!(out.diagnostics[0].message, message, "{src}");
    }
}

#[test]
fn duplicates_point_to_first() {
    let cases: Vec<(&str, DiagCode, &str)> = vec![
        ("type A {\n  X\n}\ntype A {\n  Y\n}\n", DiagCode::E0305, "A"),
        (
            "fn f() -> Unit {\n  ()\n}\nfn f() -> Unit {\n  ()\n}\n",
            DiagCode::E0306,
            "f",
        ),
        ("type A {\n  X\n  X\n}\n", DiagCode::E0309, "X"),
        (
            "fn f(a: Int, a: Int) -> Unit {\n  ()\n}\n",
            DiagCode::E0310,
            "a",
        ),
        (
            "fn f() -> Unit {\n  let g = fn(a, a) { a }\n  ()\n}\n",
            DiagCode::E0310,
            "a",
        ),
        (
            "type P {\n  P2(Int, Int)\n}\nfn f(p: P) -> Int {\n  match p {\n    P.P2(a, a) => a\n  }\n}\n",
            DiagCode::E0311,
            "a",
        ),
        (
            "fn f[A, effect A]() -> Unit {\n  ()\n}\n",
            DiagCode::E0312,
            "A",
        ),
    ];
    for (src, code, name) in cases {
        let (_, out) = run(src);
        assert_eq!(codes(&out), vec![code], "{src}");
        let d = &out.diagnostics[0];
        let primary = d.primary.as_ref().unwrap().span;
        let first = d.secondary[0].span;
        assert_eq!(text_at(src, primary), name);
        assert_eq!(text_at(src, first), name);
        assert!(first.start < primary.start, "{src}");
    }
}

#[test]
fn user_function_named_like_prelude_helper() {
    let src = "fn mapInto(x: Int) -> Int {\n  mapInto(x)\n}\n";
    let (user, out) = run(src);
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
    let decl = fn_named(&user, "mapInto");
    let mine = *out.decls.get(decl.id).unwrap();
    assert_eq!(kind_of(&out, mine), BindingKind::TopFn);
    let prelude_helper = out
        .bindings
        .iter()
        .find(|(_, b)| b.name == "mapInto" && b.kind == BindingKind::PreludeFn { module: None })
        .map(|(id, _)| id)
        .unwrap();
    assert_ne!(mine, prelude_helper);
    let Stmt::Expr(e) = stmt(decl, 0) else {
        panic!()
    };
    let mut calls = Vec::new();
    name_exprs(e, "mapInto", &mut calls);
    assert_eq!(out.refs.get(calls[0].id), Some(&mine));
}

#[test]
fn errors_do_not_stop_other_declarations() {
    let src = "fn f() -> Int {\n  aa + bb\n}\nfn g() -> Int {\n  cc\n}\n";
    let (_, out) = run(src);
    assert_eq!(codes(&out), vec![DiagCode::E0301; 3]);
}

#[test]
fn type_parameter_indices() {
    let src = "fn f[A, effect E, B](a: A, b: B, g: fn() -> Unit uses E) -> A uses E {\n  a\n}\n";
    let (user, out) = run(src);
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
    let f = fn_named(&user, "f");
    let kinds: Vec<BindingKind> = f
        .type_params
        .iter()
        .map(|p| kind_of(&out, *out.decls.get(p.id).unwrap()))
        .collect();
    assert_eq!(
        kinds,
        vec![
            BindingKind::TypeParam { index: 0 },
            BindingKind::EffectVar { index: 0 },
            BindingKind::TypeParam { index: 1 },
        ]
    );
}

/// 字句と構文の診断がないか。
fn parses_cleanly(src: &str) -> bool {
    let mut ids = IdGen::new();
    let lexed = lex(FileId(0), src.as_bytes());
    let out = parse(
        FileId(0),
        SourceKind::User,
        resolve_newlines(lexed.tokens),
        lexed.comments,
        &mut ids,
    );
    lexed.diagnostics.is_empty() && out.diagnostics.is_empty()
}

#[test]
fn nesting_up_to_the_parser_limit() {
    // 構文解析器が受け付ける最も深い入れ子（02-03「入れ子の深さ」）を、テストのスレッドの既定のスタックで
    // 解決できることを確かめる（00-02「再帰の深さ」）。段ごとの深さの数え方は構文ごとに違うので、
    // 受け付ける最大の段数を二分探索で求め、その 1 段先が構文の誤りになることも確かめる。
    type Make = fn(usize) -> String;
    let body = |e: String| format!("fn f(x: Int, a: Bool) -> Int {{\n  {e}\n}}\n");
    let cases: Vec<(&str, Make)> = vec![
        ("parens", |n| format!("{}x{}", "(".repeat(n), ")".repeat(n))),
        ("blocks", |n| {
            format!("{}x{}", "{ ".repeat(n), " }".repeat(n))
        }),
        ("calls", |n| {
            format!("{}x{}", "f(".repeat(n), ", a)".repeat(n))
        }),
        ("operators", |n| format!("x{}", " + x".repeat(n))),
        ("if", |n| {
            format!("{}x{}", "if a { ".repeat(n), " }".repeat(n))
        }),
        ("match", |n| {
            format!("{}x{}", "match x { y => ".repeat(n), " }".repeat(n))
        }),
        ("lambda", |n| {
            format!("{}x{}", "fn(y) { ".repeat(n), " }".repeat(n))
        }),
        ("let", |n| {
            format!("{}x{}", "{ let y = ".repeat(n), "\n y }".repeat(n))
        }),
        ("patterns", |n| {
            format!("match x {{ {}y{} => 1 }}", "Some(".repeat(n), ")".repeat(n))
        }),
    ];
    for (name, make) in cases {
        let (mut lo, mut hi) = (1usize, 1000usize);
        assert!(parses_cleanly(&body(make(lo))), "{name}");
        assert!(!parses_cleanly(&body(make(hi))), "{name}");
        while hi - lo > 1 {
            let mid = (lo + hi) / 2;
            if parses_cleanly(&body(make(mid))) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        let (_, out) = run(&body(make(lo)));
        assert!(out.diagnostics.is_empty(), "{name}: {:?}", out.diagnostics);
    }
    // 型の入れ子
    let ty = |n: usize| {
        format!(
            "fn g(x: {}Int{}) -> Unit {{\n  ()\n}}\n",
            "List[".repeat(n),
            "]".repeat(n)
        )
    };
    let (mut lo, mut hi) = (1usize, 1000usize);
    assert!(!parses_cleanly(&ty(hi)));
    while hi - lo > 1 {
        let mid = (lo + hi) / 2;
        if parses_cleanly(&ty(mid)) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    let (_, out) = run(&ty(lo));
    assert!(out.diagnostics.is_empty(), "{:?}", out.diagnostics);
}
