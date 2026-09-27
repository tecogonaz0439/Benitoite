//! 型検査のテスト（作業 T15「受け入れテスト」）。持ち主の境界 `typecheck` を、本物の字句解析・
//! 構文解析・名前解決に通したソースで確かめる。
#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    clippy::panic,
    clippy::indexing_slicing,
    clippy::arithmetic_side_effects
)] // テストの失敗は panic で表す（07-03）

use super::*;
use crate::base::{FileId, IdGen, NodeId, SourceKind, Span};
use crate::diag::DiagCode;
use crate::resolve::resolve;
use crate::syntax::ast::{Arg, Block, ElseBranch, Expr, IfExpr, Item, Pattern, Stmt};
use crate::syntax::lexer::lex;
use crate::syntax::newline::resolve_newlines;
use crate::syntax::parser::parse;
use crate::types::TyCon;

fn parse_one(file: FileId, kind: SourceKind, src: &str, ids: &mut IdGen) -> Option<Program> {
    let lexed = lex(file, src.as_bytes());
    let out = parse(
        file,
        kind,
        resolve_newlines(lexed.tokens),
        lexed.comments,
        ids,
    );
    (lexed.diagnostics.is_empty() && out.diagnostics.is_empty()).then_some(out.program)
}

struct Checked {
    src: String,
    prelude: Vec<Program>,
    user: Program,
    out: TypeckOutput,
    diags: Vec<Diagnostic>,
}

impl Checked {
    fn codes(&self) -> Vec<DiagCode> {
        self.diags.iter().filter_map(|d| d.code).collect()
    }

    fn text(&self, span: Span) -> &str {
        assert_eq!(span.file, self.user.file, "span outside the user source");
        &self.src[span.start.0 as usize..span.end.0 as usize]
    }

    /// 診断ごとの (コード, 主な位置の字面)。主な位置のない診断は空の字面。
    fn summary(&self) -> Vec<(DiagCode, String)> {
        self.diags
            .iter()
            .map(|d| {
                let at = d
                    .primary
                    .as_ref()
                    .map_or(String::new(), |l| self.text(l.span).to_string());
                (d.code.unwrap(), at)
            })
            .collect()
    }

    fn only(&self, code: DiagCode) -> &Diagnostic {
        assert_eq!(self.codes(), vec![code], "{:#?}", self.diags);
        &self.diags[0]
    }
}

/// prelude のソースと利用者のソースを、字句解析・構文解析・名前解決に通してから型検査する。
/// 構文と名前の誤りのないソースだけを使う。
fn check(src: &str) -> Checked {
    let mut ids = IdGen::new();
    let prelude: Vec<Program> = crate::prelude::SOURCES
        .iter()
        .enumerate()
        .map(|(i, (_, text))| {
            parse_one(FileId(i as u32), SourceKind::Prelude, text, &mut ids).unwrap()
        })
        .collect();
    let file = FileId(prelude.len() as u32);
    let user = parse_one(file, SourceKind::User, src, &mut ids).expect("syntax error");
    let resolved = resolve(&prelude, &user, &mut ids);
    assert!(
        resolved.diagnostics.is_empty(),
        "{:?}",
        resolved.diagnostics
    );
    let (out, diags) = typecheck(&prelude, &user, &resolved);
    Checked {
        src: src.to_string(),
        prelude,
        user,
        out,
        diags,
    }
}

// ---------------- AST から確かめるノードを集める ----------------

/// 表に型がなければならないノード（作業 T15「解いた後の検査と記録」の最後の段落）と、
/// 修飾した名前ごとの NameExpr、プレースホルダ、呼び出しのノード。
#[derive(Default)]
struct Nodes {
    typed: Vec<(NodeId, Span)>,
    names: Vec<(String, NodeId)>,
    placeholders: Vec<NodeId>,
    calls: Vec<(NodeId, Span)>,
    lets: Vec<NodeId>,
}

impl Nodes {
    fn of(p: &Program) -> Nodes {
        let mut n = Nodes::default();
        for item in &p.items {
            if let Item::Fn(f) = item {
                for param in &f.params {
                    n.typed.push((param.id, param.span));
                }
                n.block(&f.body);
            }
        }
        n
    }

    fn block(&mut self, b: &Block) {
        for s in &b.stmts {
            match s {
                Stmt::Let(l) => {
                    self.typed.push((l.id, l.span));
                    self.lets.push(l.id);
                    self.expr(&l.value);
                }
                Stmt::Expr(e) => self.expr(e),
                Stmt::Error(_) => panic!("error node"),
            }
        }
    }

    fn if_expr(&mut self, i: &IfExpr) {
        self.expr(&i.cond);
        self.block(&i.then_block);
        match &i.else_branch {
            Some(ElseBranch::Block(b)) => self.block(b),
            Some(ElseBranch::If(inner)) => self.if_expr(inner),
            None => {}
        }
    }

    fn expr(&mut self, e: &Expr) {
        self.typed.push((e.id(), e.span()));
        match e {
            Expr::Lit(_) | Expr::Unit(_) | Expr::Error(_) => {}
            Expr::Name(n) => {
                let q = n
                    .qualifier
                    .as_ref()
                    .map_or(String::new(), |q| format!("{}.", q.text));
                self.names.push((format!("{q}{}", n.name.text), n.id));
            }
            Expr::Paren(p) => self.expr(&p.inner),
            Expr::List(l) => l.elems.iter().for_each(|x| self.expr(x)),
            Expr::Call(c) => {
                self.calls.push((c.id, c.span));
                self.expr(&c.callee);
                for a in &c.args {
                    match a {
                        Arg::Expr(x) => self.expr(x),
                        Arg::Placeholder(p) => {
                            self.typed.push((p.id, p.span));
                            self.placeholders.push(p.id);
                        }
                    }
                }
            }
            Expr::Binary(b) => {
                self.expr(&b.lhs);
                self.expr(&b.rhs);
            }
            Expr::Unary(u) => self.expr(&u.operand),
            Expr::Pipe(p) => {
                self.expr(&p.lhs);
                self.expr(&p.rhs);
            }
            Expr::Block(b) => self.block(b),
            Expr::If(i) => self.if_expr(i),
            Expr::Match(m) => {
                self.expr(&m.scrutinee);
                for arm in &m.arms {
                    self.pattern(&arm.pattern);
                    self.expr(&arm.body);
                }
            }
            Expr::Lambda(l) => {
                for p in &l.params {
                    self.typed.push((p.id, p.span));
                }
                self.block(&l.body);
            }
        }
    }

    fn pattern(&mut self, p: &Pattern) {
        self.typed.push((p.id(), p.span()));
        if let Pattern::Ctor(c) = p {
            c.args.iter().for_each(|a| self.pattern(a));
        }
    }

    fn name(&self, qualified: &str) -> NodeId {
        self.names
            .iter()
            .find(|(n, _)| n == qualified)
            .unwrap_or_else(|| panic!("no name {qualified}"))
            .1
    }
}

/// 表の網羅: すべての式・パターン・`let` 文・引数・プレースホルダが `expr_types` にある。
/// prelude のソースの本体も脱糖するので、prelude の AST も調べる。
fn assert_tables_cover(c: &Checked) {
    for program in &c.prelude {
        for (id, span) in &Nodes::of(program).typed {
            assert!(
                c.out.expr_types.get(*id).is_some(),
                "no type for the prelude node at {span:?}"
            );
        }
    }
    let nodes = Nodes::of(&c.user);
    for (id, span) in &nodes.typed {
        assert!(
            c.out.expr_types.get(*id).is_some(),
            "no type for `{}`",
            c.text(*span)
        );
    }
}

fn ty_of(c: &Checked, id: NodeId) -> Ty {
    c.out.expr_types.get(id).cloned().unwrap()
}

fn fn_ty(params: Vec<Ty>, ret: Ty) -> Ty {
    Ty::func(params, ret, EffectSet::empty())
}

// ---------------- 診断のないプログラム ----------------

const SHAPES: &str = "type Shape {
  Circle(Float)
  Rect(Float, Float)
}

fn area(s: Shape) -> Float {
  match s {
    Shape.Circle(r) => 3.14159 * r * r
    Shape.Rect(w, h) => w * h
  }
}

fn totalArea(shapes: List[Shape]) -> Float {
  shapes
    |> List.map(area)
    |> List.fold(0.0, fn(acc, a) { acc + a })
}

fn main() -> Unit uses IO {
  let shapes = [Shape.Circle(1.0), Shape.Rect(2.0, 3.0)]
  Console.println(Float.toString(totalArea(shapes)))
}
";

const CHOOSE: &str = "fn choose[effect E](unused: fn() -> Unit uses IO, E, act: fn() -> Unit uses E) -> Unit uses E {
  act()
}

fn main() -> Unit {
  choose(fn() { Console.println(\"not called\") }, fn() { () })
}
";

const PIPES: &str = "fn clamp(lo: Int, x: Int, hi: Int) -> Int {
  if x < lo { lo } else if x > hi { hi } else { x }
}

fn make(n: Int) -> fn(Int) -> Int {
  fn(x) { x + n }
}

fn main() -> Unit {
  let xs = [1, 2] |> List.map(fn(x) { x + 1 })
  let x = 5
  let y = x |> clamp(0, _, 100)
  let z = x |> (make(1))
  let f = clamp(0, _, 100)
  let w = f(5)
  ()
}
";

#[test]
fn programs_without_errors() {
    let cases = [
        // prelude のソースに誤りがないこと（完了条件）
        "fn main() -> Unit { () }",
        SHAPES,
        // 型が使い方で決まる（01-06「演算子の型付け」の g）
        "fn g() -> Int {
  let add = fn(a, b) { a + b }
  add(1, 2)
}
fn main() -> Unit { () }",
        CHOOSE,
        PIPES,
        // main は Result[Unit, String] も返せる（01-07「プログラムの入口」）
        "fn main() -> Result[Unit, String] uses IO {
  match File.readText(\"input.txt\") {
    Ok(text) => {
      Console.println(Int.toString(List.length(String.lines(text))))
      Ok(())
    }
    Err(e) => Err(IoError.message(e))
  }
}",
        // 相互再帰の型、引数のない構成子を値として使う、構成子の部分適用、等値の型の比較
        "type Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
}
type Forest[T] {
  Nil
  Cons(Tree[T], Forest[T])
}
fn size[T](t: Tree[T]) -> Int {
  match t {
    Tree.Leaf => 0
    Tree.Node(l, _, r) => size(l) + 1 + size(r)
  }
}
fn main() -> Unit {
  let t = Tree.Node(Tree.Leaf, 3, Tree.Leaf)
  let f = Forest.Cons(t, Forest.Nil)
  let same = f == Forest.Nil && t != Tree.Leaf
  let leaves = List.map([1, 2], Tree.Node(Tree.Leaf, _, Tree.Leaf))
  let big = -9223372036854775808 < 9223372036854775807
  let s = -(1.5) * -2.0
  ()
}",
    ];
    for src in cases {
        let c = check(src);
        assert!(c.diags.is_empty(), "{src}\n{:#?}", c.diags);
        assert_tables_cover(&c);
    }
}

#[test]
fn polymorphic_uses_record_type_args() {
    let c = check(SHAPES);
    let nodes = Nodes::of(&c.user);
    let Ty::Fn(area) = ty_of(&c, nodes.name("area")) else {
        panic!()
    };
    let shape = area.params[0].clone();
    assert!(matches!(shape, Ty::Con(TyCon::Adt(_), _)));
    // List.map の置き換えは [Shape, Float] と空のエフェクト（受け入れテスト「01-02 の例」）
    let args = c.out.type_args.get(nodes.name("List.map")).unwrap();
    assert_eq!(args.tys, vec![shape.clone(), Ty::float()]);
    assert_eq!(args.effects, vec![EffectSet::empty()]);
    // 構成子を値として使う箇所の型は、構成子の宣言の型の関数の型（01-05「値の構築」）
    assert_eq!(
        ty_of(&c, nodes.name("Shape.Circle")),
        fn_ty(vec![Ty::float()], shape)
    );
    let main = c.out.main.unwrap();
    assert!(!main.returns_result);
    assert!(c.out.decl_types.get(main.binding).is_some());
}

#[test]
fn pipes_and_placeholders_expand_to_calls() {
    let c = check(PIPES);
    let nodes = Nodes::of(&c.user);
    // main の let 文の型（clamp と make の本体には let 文がない）
    let lets: Vec<Ty> = nodes.lets.iter().map(|id| ty_of(&c, *id)).collect();
    let int_to_int = fn_ty(vec![Ty::int()], Ty::int());
    assert_eq!(
        lets,
        vec![
            Ty::list(Ty::int()),
            Ty::int(),
            Ty::int(),
            Ty::int(),
            int_to_int.clone(),
            Ty::int(),
        ]
    );
    // プレースホルダの型は展開したラムダの引数の型、エフェクトは空集合
    assert_eq!(nodes.placeholders.len(), 2);
    for p in &nodes.placeholders {
        assert_eq!(ty_of(&c, *p), Ty::int());
    }
    let placeholder_calls: Vec<NodeId> = nodes
        .calls
        .iter()
        .filter(|(_, span)| c.text(*span) == "clamp(0, _, 100)")
        .map(|(id, _)| *id)
        .collect();
    assert_eq!(placeholder_calls.len(), 2);
    for id in placeholder_calls {
        assert_eq!(ty_of(&c, id), int_to_int);
        assert_eq!(c.out.lambda_effects.get(id), Some(&EffectSet::empty()));
    }
}

// ---------------- 診断 ----------------

/// 期待する診断: (コード, 主な位置の字面)。主な位置のない診断は空の字面。
type Expect = &'static [(DiagCode, &'static str)];

#[test]
fn diagnostics_by_code_and_position() {
    use DiagCode::*;
    let main = "\nfn main() -> Unit { () }";
    let cases: Vec<(String, Expect)> = vec![
        // 局所の束縛は多相にしない（01-06「多相」）
        (
            format!(
                "fn example() -> Unit {{
  let id = fn(x) {{ x }}
  let a = id(1)
  let b = id(\"one\")
}}{main}"
            ),
            &[(E0401, "\"one\"")],
        ),
        // 型が決まらない（01-06「演算子の型付け」の f）
        (
            format!("fn f() -> Unit {{\n  let add = fn(a, b) {{ a + b }}\n}}{main}"),
            &[(E0407, "a + b")],
        ),
        // エフェクト変数の違反（02-05 の choose の第 2 引数を IO を行うラムダに変えたもの）。
        // 主な位置は IO を生じた呼び出し（01-06「式のエフェクト」）
        (
            CHOOSE.replace("fn() { () }", "fn() { Console.println(\"x\") }"),
            &[(E0501, "Console.println(\"x\")")],
        ),
        // 純粋な関数から IO（01-06「式のエフェクト」の greet）
        (
            format!(
                "fn greet(name: String) -> Unit {{\n  Console.println(\"Hello, \" + name)\n}}{main}"
            ),
            &[(E0501, "Console.println(\"Hello, \" + name)")],
        ),
        // main がない
        ("fn f() -> Unit { () }".to_string(), &[(E0414, "")]),
        // 型引数の個数（シグネチャ、型パラメータ、本体の型注釈）
        (
            format!("fn f(x: List) -> Unit {{ () }}{main}"),
            &[(E0410, "List")],
        ),
        (
            format!("fn f[T](x: T[Int]) -> Unit {{ () }}{main}"),
            &[(E0410, "T[Int]")],
        ),
        (
            format!("fn f() -> Unit {{\n  let x: Option[Int, Int] = None\n}}{main}"),
            &[(E0410, "Option[Int, Int]")],
        ),
        // 構成子のない型
        (format!("type T {{}}{main}"), &[(E0411, "T")]),
        // エフェクト変数の規則
        (
            format!(
                "fn f[effect E, effect F](a: fn() -> Unit uses E, b: fn() -> Unit uses F) -> Unit uses E, F {{ () }}{main}"
            ),
            &[(E0417, "uses E, F")],
        ),
        (
            format!("fn f() -> Unit uses IO, IO {{ () }}{main}"),
            &[(E0419, "IO")],
        ),
        (
            format!("fn f[effect E]() -> Unit uses E {{ () }}{main}"),
            &[(E0418, "E")],
        ),
        // 本体の型注釈の uses にも同じ規則
        (
            format!("fn f() -> Unit {{\n  let g = fn() -> Unit uses IO, IO {{ () }}\n}}{main}"),
            &[(E0419, "IO")],
        ),
        // 引数のない構成子に括弧（式とパターン）。派生の誤りなし
        (
            format!(
                "type Tree {{\n  Leaf\n  Node(Tree, Tree)\n}}
fn f(t: Tree) -> Int {{
  let u = Tree.Leaf()
  let v = None()
  match t {{
    Tree.Leaf() => 0
    Tree.Node(_, _) => 1
  }}
}}{main}"
            ),
            &[
                (E0413, "Tree.Leaf()"),
                (E0413, "None()"),
                (E0413, "Tree.Leaf()"),
            ],
        ),
        // パターンの引数の個数
        (
            format!(
                "type Shape {{\n  Circle(Float)\n  Rect(Float, Float)\n}}
fn f(s: Shape) -> Float {{
  match s {{
    Shape.Rect(w) => w
    Shape.Circle(r) => r
  }}
}}{main}"
            ),
            &[(E0412, "Shape.Rect(w)")],
        ),
        // パイプで展開した呼び出しの制約の主な位置は、パイプの式全体（作業 T15「本体の制約の生成」）。
        // 規則 1（引数の型の誤り）と規則 2（呼ばれる式の引数の型の誤り）
        (
            format!(
                "fn f(a: Int, h: fn(Int) -> Int) -> Int {{ h(a) }}
fn g() -> Unit {{
  let p = \"s\" |> f(Int.abs(_))
  let q = \"s\" |> Int.abs
}}{main}"
            ),
            &[
                (E0401, "\"s\" |> f(Int.abs(_))"),
                (E0401, "\"s\" |> Int.abs"),
            ],
        ),
        // 整数リテラルの範囲。直接の `-` の下では 2^63 まで許す
        (
            format!(
                "fn f() -> Unit {{
  let a = 9223372036854775807
  let b = 9223372036854775808
  let c = -9223372036854775808
  let d = -(9223372036854775808)
  let e = 0x7FFF_FFFF_FFFF_FFFF
  let g = 0x1_0000_0000_0000_0000_0000_0000_0000_0000
}}{main}"
            ),
            &[
                (E0408, "9223372036854775808"),
                (E0408, "9223372036854775808"),
                (E0408, "0x1_0000_0000_0000_0000_0000_0000_0000_0000"),
            ],
        ),
        // パターンの整数リテラルの範囲。範囲の外を含む match は網羅性を検査しない
        (
            format!(
                "fn f(n: Int) -> Int {{
  match n {{
    -9223372036854775808 => 1
    9223372036854775808 => 2
  }}
}}{main}"
            ),
            &[(E0408, "9223372036854775808")],
        ),
        // 浮動小数リテラルの範囲
        (
            format!("fn f() -> Unit {{\n  let a = 1e308\n  let b = 1e309\n}}{main}"),
            &[(E0409, "1e309")],
        ),
        // 式文
        (
            format!("fn f() -> Unit {{\n  1 + 2\n  ()\n}}{main}"),
            &[(E0416, "1 + 2")],
        ),
        // 等値の型
        (
            format!("fn f() -> Bool {{\n  fn() {{ () }} == fn() {{ () }}\n}}{main}"),
            &[(E0406, "fn() { () } == fn() { () }")],
        ),
        (
            "fn main() -> Unit uses IO {\n  let same = File.readText(\"a\") == File.readText(\"b\")\n}"
                .to_string(),
            &[(E0406, "File.readText(\"a\") == File.readText(\"b\")")],
        ),
        // List.sort の制約
        (
            format!("fn f() -> List[Bool] {{\n  List.sort([true])\n}}{main}"),
            &[(E0405, "List.sort")],
        ),
        // 網羅性
        (
            format!(
                "type Tree[T] {{\n  Leaf\n  Node(Tree[T], T, Tree[T])\n}}
fn f(t: Tree[Int]) -> Int {{
  match t {{
    Tree.Leaf => 0
  }}
}}{main}"
            ),
            &[(E0601, "t")],
        ),
        // 選ばれない分岐（01-05「選ばれない分岐の検査」）
        (
            format!(
                "fn f(n: Int) -> String {{
  match n {{
    _ => \"other\"
    0 => \"zero\"
  }}
}}{main}"
            ),
            &[(E0602, "0")],
        ),
        // 一つの関数の独立した三つの誤り（ADR 0024）
        (
            format!(
                "fn f(x: Int) -> Unit {{
  let a: String = x
  let b = if x {{ 1 }} else {{ 2 }}
  let c = x + \"s\"
}}{main}"
            ),
            &[(E0401, "x"), (E0401, "x"), (E0401, "\"s\"")],
        ),
        // 誤りの型の変数を後で三回使っても、派生した誤りを出さない
        (
            format!(
                "fn f() -> Unit {{
  let x = Option.unwrapOr(1, 2)
  let a = x + 1
  let b = List.length(x)
  let c = x == \"s\"
}}{main}"
            ),
            &[(E0401, "1")],
        ),
        // パターンの型が合わない match は、網羅性を検査しない（派生した誤りを出さない）
        (
            format!(
                "fn f(n: Int) -> Int {{\n  match n {{\n    \"a\" => 1\n  }}\n}}{main}"
            ),
            &[(E0401, "\"a\"")],
        ),
        // 宣言の誤りから派生した誤りを本体で出さない（壊れた宣言）
        (
            format!(
                "type T {{\n  A(List)\n}}
fn g(x: List) -> Int {{ 1 }}
fn f() -> Int {{
  let t = T.A([1])
  g(\"s\") + g(1)
}}{main}"
            ),
            &[(E0410, "List"), (E0410, "List")],
        ),
    ];
    for (src, expected) in &cases {
        let c = check(src);
        let want: Vec<(DiagCode, String)> =
            expected.iter().map(|(d, s)| (*d, s.to_string())).collect();
        assert_eq!(c.summary(), want, "{src}\n{:#?}", c.diags);
    }
}

#[test]
fn pipe_rule_one_looks_only_at_direct_arguments_and_the_outermost_call() {
    // `x |> f(g(_))` は f(x, g(_))、`x |> g(a)(b)` は g(a)(x, b) に展開する（01-02「パイプ」）。
    // 取り違えると型が合わなくなるか、別の型になる。
    let c = check(
        "fn f(a: Int, h: fn(Int) -> Int) -> Int { h(a) }
fn g(a: String) -> fn(Int, Int) -> String {
  fn(x, b) { a }
}
fn main() -> Unit {
  let p = 1 |> f(Int.abs(_))
  let q = 2 |> g(\"s\")(3)
  ()
}",
    );
    assert!(c.diags.is_empty(), "{:#?}", c.diags);
    assert_tables_cover(&c);
    let lets: Vec<Ty> = Nodes::of(&c.user)
        .lets
        .iter()
        .map(|id| ty_of(&c, *id))
        .collect();
    assert_eq!(lets, vec![Ty::int(), Ty::string()]);
}

#[test]
fn constructor_pattern_arity_names_the_counts() {
    let c = check(
        "type Shape {
  Circle(Float)
  Rect(Float, Float)
}
fn f(s: Shape) -> Float {
  match s {
    Shape.Rect(w) => w
    Shape.Circle(r) => r
  }
}
fn main() -> Unit { () }",
    );
    let d = c.only(DiagCode::E0412);
    assert_eq!(
        d.message,
        "the constructor `Shape.Rect` has 2 field(s) but the pattern has 1"
    );
}

#[test]
fn lambda_uses_reports_the_call_and_the_uses_list() {
    let c = check(
        "fn f[effect E](a: fn() -> Unit uses E) -> Unit uses E {
  let g = fn() -> Unit uses E { Console.println(\"x\") }
}
fn main() -> Unit { () }",
    );
    let d = c.only(DiagCode::E0502);
    assert_eq!(
        c.text(d.primary.as_ref().unwrap().span),
        "Console.println(\"x\")"
    );
    assert_eq!(d.secondary.len(), 1);
    assert_eq!(c.text(d.secondary[0].span), "uses E");
}

fn extra(code: DiagCode, key: &str) -> String {
    code.info()
        .extras
        .iter()
        .find(|(k, _)| *k == key)
        .unwrap()
        .1
        .to_string()
}

#[test]
fn main_signature_notes() {
    let c = check("fn main(x: Int) -> Int { x }");
    let d = c.only(DiagCode::E0415);
    assert_eq!(c.text(d.primary.as_ref().unwrap().span), "main");
    let note = |key| extra(DiagCode::E0415, key);
    assert_eq!(d.notes, vec![note("params"), note("ret")]);

    let c = check("fn main[effect E](f: fn() -> Unit uses E) -> Unit uses E { f() }");
    let d = c.only(DiagCode::E0415);
    assert_eq!(
        d.notes,
        vec![note("params"), note("type_params"), note("effects")]
    );
}

#[test]
fn mismatch_notes_and_fixes() {
    let main = "\nfn main() -> Unit { () }";
    // `else` のない `if`
    let c = check(&format!(
        "fn f(c: Bool) -> Unit {{\n  if c {{ 1 }}\n}}{main}"
    ));
    let d = c.only(DiagCode::E0401);
    assert_eq!(d.notes, vec![extra(DiagCode::E0401, "because_if_no_else")]);
    // Float の位置の整数リテラル
    let c = check(&format!("fn f(x: Float) -> Float {{\n  x * 2\n}}{main}"));
    let d = c.only(DiagCode::E0401);
    assert!(d.helps.iter().any(|h| h.contains("`2.0`")), "{d:#?}");
    // 文字列の `+`
    let c = check(&format!("fn f() -> String {{\n  \"a\" + 1\n}}{main}"));
    assert_eq!(c.diags.len(), 1, "{:#?}", c.diags);
    let d = &c.diags[0];
    assert!(matches!(d.code, Some(DiagCode::E0401 | DiagCode::E0405)));
    assert!(d.helps.iter().any(|h| h.contains("Int.toString")), "{d:#?}");
    // 呼び出しの引数は、宣言の引数の型を補助の位置に示す
    let c = check(&format!(
        "fn g(n: Int) -> Int {{ n }}\nfn f() -> Int {{\n  g(\"s\")\n}}{main}"
    ));
    let d = c.only(DiagCode::E0401);
    assert_eq!(c.text(d.primary.as_ref().unwrap().span), "\"s\"");
    assert_eq!(c.text(d.secondary[0].span), "Int");
}

#[test]
fn unreachable_arm_points_at_the_covering_arm() {
    let c = check(
        "fn f(n: Int) -> String {
  match n {
    _ => \"other\"
    0 => \"zero\"
  }
}
fn main() -> Unit { () }",
    );
    let d = c.only(DiagCode::E0602);
    assert_eq!(d.secondary.len(), 1);
    assert_eq!(c.text(d.secondary[0].span), "_");
}

#[test]
fn non_exhaustive_match_shows_a_witness() {
    let c = check(
        "type Tree[T] {
  Leaf
  Node(Tree[T], T, Tree[T])
}
fn f(t: Tree[Int]) -> Int {
  match t {
    Tree.Leaf => 0
  }
}
fn main() -> Unit { () }",
    );
    let d = c.only(DiagCode::E0601);
    assert!(
        d.primary
            .as_ref()
            .unwrap()
            .text
            .contains("Tree.Node(_, _, _)"),
        "{d:#?}"
    );
}

#[test]
fn equality_summary_of_declarations() {
    // 等値の型の要約（01-06「等値の型」、ADR 0082）。Box[T] は T に依存し、Nest は再帰の先で
    // 型引数が変わっても展開せずに判定する。Holder は関数の型を含む。
    let main = "\nfn main() -> Unit { () }";
    let decls = "type Box[T] {\n  Box(T)\n}
type Nest[T] {\n  Leaf(T)\n  Deeper(Nest[List[T]])\n}
type Holder {\n  Holder(fn() -> Unit)\n}\n";
    let ok = check(&format!(
        "{decls}fn f(a: Box[Int], b: Nest[String]) -> Bool {{\n  a == a && b == b\n}}{main}"
    ));
    assert!(ok.diags.is_empty(), "{:#?}", ok.diags);
    for (params, body) in [
        ("a: Box[fn() -> Unit]", "a == a"),
        ("a: Nest[IoError]", "a == a"),
        ("a: Holder", "a == a"),
        ("a: Option[Box[Holder]]", "a != a"),
    ] {
        let c = check(&format!(
            "{decls}fn f({params}) -> Bool {{\n  {body}\n}}{main}"
        ));
        c.only(DiagCode::E0406);
    }
}

// ---------------- 深い入れ子と長い並び ----------------

fn user_parses(src: &str) -> bool {
    let mut ids = IdGen::new();
    parse_one(FileId(0), SourceKind::User, src, &mut ids).is_some()
}

#[test]
fn nesting_up_to_the_parser_limit() {
    // 構文解析器が受け付ける最も深い入れ子（02-03「入れ子の深さ」）を、テストのスレッドの既定の
    // スタックで型検査できることを確かめる（00-02「再帰の深さ」）。受け付ける最大の段数を二分探索で求める。
    type Make = fn(usize) -> String;
    let body = |e: String| {
        format!("fn f(x: Int, a: Bool) -> Int {{\n  {e}\n}}\nfn main() -> Unit {{ () }}\n")
    };
    let cases: Vec<(&str, Make)> = vec![
        ("parens", |n| format!("{}x{}", "(".repeat(n), ")".repeat(n))),
        ("blocks", |n| {
            format!("{}x{}", "{ ".repeat(n), " }".repeat(n))
        }),
        ("calls", |n| {
            format!("{}x{}", "f(".repeat(n), ", a)".repeat(n))
        }),
        ("operators", |n| format!("x{}", " + x".repeat(n))),
        ("negation", |n| format!("{}x", "-".repeat(n))),
        ("pipes", |n| format!("x{}", " |> f(a)".repeat(n))),
        ("placeholders", |n| {
            format!("{}x{}", "f(_, a)(".repeat(n), ")".repeat(n))
        }),
        ("if", |n| {
            format!("{}x{}", "if a { ".repeat(n), " } else { x }".repeat(n))
        }),
        ("else if", |n| {
            format!("if a {{ x }}{} else {{ x }}", " else if a { x }".repeat(n))
        }),
        ("match", |n| {
            format!("{}x{}", "match x { y => ".repeat(n), " }".repeat(n))
        }),
        ("lambda", |n| {
            format!("let g = {}x{}\n  x", "fn(y) { ".repeat(n), " }".repeat(n))
        }),
        ("let", |n| {
            format!("{}x{}", "{ let y = ".repeat(n), "\n y }".repeat(n))
        }),
        ("lists", |n| {
            format!("let l = {}x{}\n  x", "[".repeat(n), "]".repeat(n))
        }),
        ("list elements", |n| {
            format!("let l = [{}]\n  x", vec!["x"; n].join(", "))
        }),
        ("statements", |n| {
            format!("{}x", "let y = x + 1\n  ".repeat(n))
        }),
        ("match arms", |n| {
            let arms: String = (0..n).map(|i| format!("    {i} => x\n")).collect();
            format!("match x {{\n{arms}    _ => x\n  }}")
        }),
        ("types", |n| {
            format!("let l: {}Int{} = []\n  x", "List[".repeat(n), "]".repeat(n))
        }),
    ];
    for (name, make) in cases {
        let (mut lo, mut hi) = (1usize, 1100usize);
        assert!(user_parses(&body(make(lo))), "{name}");
        assert!(!user_parses(&body(make(hi))), "{name}");
        while hi - lo > 1 {
            let mid = (lo + hi) / 2;
            if user_parses(&body(make(mid))) {
                lo = mid;
            } else {
                hi = mid;
            }
        }
        let c = check(&body(make(lo)));
        assert!(c.diags.is_empty(), "{name}: {:#?}", c.diags);
        assert_tables_cover(&c);
    }
    // 深いパターンと、それに合う深い型の対象（パターンの検査も深い型の上で行う）
    let deep_match = |n: usize| {
        format!(
            "fn f(x: {}Int{}) -> Int {{\n  match x {{ {}y{} => y\n _ => 0 }}\n}}\nfn main() -> Unit {{ () }}\n",
            "Option[".repeat(n),
            "]".repeat(n),
            "Some(".repeat(n),
            ")".repeat(n)
        )
    };
    let (mut lo, mut hi) = (1usize, 1100usize);
    assert!(!user_parses(&deep_match(hi)));
    while hi - lo > 1 {
        let mid = (lo + hi) / 2;
        if user_parses(&deep_match(mid)) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    let c = check(&deep_match(lo));
    assert!(c.diags.is_empty(), "{:#?}", c.diags);
    assert_tables_cover(&c);
}
