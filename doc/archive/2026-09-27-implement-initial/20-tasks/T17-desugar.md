# T17 脱糖

- 依存する作業: [T15](T15-typeck-generate.md)
- 難易度: 4（1〜5。README の「難易度の目安」）
- 規模の見込み: 大（1500 行超）（テストを含む Rust の行数の目安）
- ブランチ: impl/T17-desugar

## 目的

型検査を通ったプログラムの AST を、コア計算と同じ形のコア IR に移す。01-12「表層からの脱糖」の規則を、構文ごとに一つの Rust の関数として実装する（02-06「脱糖」）。各ノードに型・エフェクト・由来位置を付け、後の段（判定の木への変換、参照インタプリタ、コア IR の検査器）がそのまま使える形にする。

## 読む設計書の節

- [コア計算と脱糖](../../2026-09-27-design-initial/01-spec/01-12-core-calculus.md): 「構文」「表層からの脱糖」（全項）「置き換えてよい等式」
- [中間表現と脱糖](../../2026-09-27-design-initial/02-impl/02-06-ir-and-lowering.md): 「工程」「コア IR」（型とエフェクトの付け方の表を含む）「脱糖」
- [ソース管理と位置情報](../../2026-09-27-design-initial/02-impl/02-02-source-and-spans.md): 「合成ノードの由来位置」
- [構文](../../2026-09-27-design-initial/01-spec/01-02-syntax.md): 「パイプ」「部分適用のプレースホルダ」
- [型検査器](../../2026-09-27-design-initial/02-impl/02-05-typechecker.md): 「出力」
- [名前解決とモジュール読込](../../2026-09-27-design-initial/02-impl/02-04-resolver.md): 「束縛」「prelude」
- [中間表現](../10-interfaces/10-06-ir.md): 全体（特に `core_ir.rs` と `desugar` のシグネチャ）
- [型と型検査](../10-interfaces/10-05-types.md): 「型の表現」「型検査の出力」
- [名前解決](../10-interfaces/10-04-resolve.md)、[組み込みの関数](../10-interfaces/10-10-builtins.md)の「演算子」

## 作るもの

- `src/ir/desugar.rs`: `desugar` の中身（10-06 の `sig=src/ir/desugar.rs`）と、非公開の補助の関数。
- `src/ir/desugar.rs` の中のテスト（`#[cfg(test)] mod tests`）。

これ以外のファイルは変えない。

## 手順の要点

### 全体の流れ

1. `types.main` が `None` なら `InternalError` を返す（型検査を通ったプログラムでは起きない）。
2. prelude のソースの `Program`（ファイルの名前の順）、利用者の `Program` の順に、`Item::Fn` を定義に移す。定義の並びは 10-06 の `Program` のコメントのとおり、prelude の定義の後に利用者の定義を置く。`Item::Type` は定義を作らない（型の宣言は `types.adts` をそのまま `Program::adts` に写す）。`Item::Error` が現れたら `InternalError`。
3. `LambdaId` はプログラム全体で一つの数え上げから振り、最後の値を `lambda_count` に入れる。
4. `VarId` は定義ごとに 0 から振る。引数から先に振り、本体で作る変数は現れた順に振る。定義の最後の値を `var_count` に入れる。

脱糖の状態（`VarId` と `LambdaId` の数え上げ、局所の束縛の番号から `VarId` への表、引いている表への参照）は、構造体一つにまとめて各関数に `&mut` で渡す。大域の状態にしない（ADR 0015）。

### 定義

- 束縛の番号は `resolved.decls.get(fn_decl.id)` で引く。その束縛の種類が `TopFn` なら `DefOrigin::User`、`PreludeFn { module: Some(m) }` なら `DefOrigin::PreludePublic { module: m }`、`PreludeFn { module: None }` なら `DefOrigin::PreludeHelper`。
- `name` は、利用者の関数と補助の関数は宣言の名前、prelude の公開の関数は `List.map` の形（`PreludeModule::name()` と `.` と名前）とする。
- 型パラメータ・エフェクト変数・引数の型・戻り値の型・エフェクトは、`types.decl_types.get(binding)` の `Scheme` から写す。
- 引数ごとに `Var` を作る。`name` はソースの名前、`ty` は `Scheme::params` の型。引数の宣言したノード（`Param::id`）の束縛の番号を `VarId` に対応させる。
- 本体は `⟦B0⟧`（後述のブロックの規則）。`span` は関数の宣言の span。

### 式の規則（01-12「表層からの脱糖」の表の各行を一つの関数にする）

関数の形は次を目安にする: `fn desugar_expr(&mut self, e: &ast::Expr) -> Result<Comp, InternalError>`。値が必要な箇所は、式を脱糖した計算を `let x ⇐ ⟦e⟧ in …` で新しい変数に束縛する。補助の関数 `bind(comp, ty, |x| rest)` のような「計算を新しい変数に束縛して続きを作る」関数を一つ作り、各規則で使うと表と一対一の形に書ける。

型の引き方は次のとおりである。

| 知りたいもの | 引き方 |
|---|---|
| 表層の式の型 | `types.expr_types.get(expr.id())` |
| 名前を使う箇所の束縛 | `resolved.refs.get(name_expr.id)` の束縛の番号で `resolved.bindings` を引く |
| 多相な名前の置き換え `[T̄; Ē]` | `types.type_args.get(name_expr.id)`。表になければ空の `TypeArgs`（多相でない名前） |
| 演算子のオペランドの型 | `types.operand_types.get(binary.id)` |
| ラムダの型のエフェクト | `types.lambda_effects.get(lambda.id)`（プレースホルダを含む呼び出しは、その `CallExpr` の id） |
| ラムダの引数・プレースホルダの型 | `types.expr_types.get(param.id)`・`types.expr_types.get(placeholder.id)` |
| 局所の束縛の型 | 宣言したノード（引数、`let` 文、変数のパターン）の `expr_types` |

表を引いて結果がないときは `InternalError { stage: "desugar", message }` を返す。message には引けなかった表とノード番号を書く。

名前とリテラル:

- 局所の束縛（`Param`・`Let`・`LambdaParam`・`PatternVar`）: `return x`。`x` は束縛の番号に対応させた `VarId`。
- `TopFn`・`PreludeFn`: `return f[T̄; Ē]`（`ValKind::TopFn { def: 束縛の番号, .. }`）。prelude のソースの関数は Σ に定義があるので、組み込みの関数ではなく `TopFn` にする（01-12「名前とリテラル」の表の 3 行目）。
- `Builtin(id)`: `return b[T̄; Ē]`（`ValKind::Builtin`）。値として使う場合もこれでよい。値として使う組み込みの関数の原型は、コード生成（T21）が作る。
- `Ctor { con, tag }`: 構成子の引数の個数を `types.adts` で調べる。引数がなければ `return C[T̄]()`。引数があり、呼び出しの呼ばれる式として使われていない（値として使う）なら、`return λ(y1:A1, …, yn:An). return C[T̄](y1, …, yn)` を作る。`Ā` は `AdtTable::field_types(con, tag, &T̄)`。このラムダの `span` は名前の式の span、`LambdaId` は新しく振る。
- リテラル: `Literal::Int` は基数と数字列から `i64` にする（範囲は型検査で確かめてある。変換に失敗したら `InternalError`）。`Literal::Float` は `str::parse::<f64>` で読む（Rust の `f64` の `FromStr` は最近接偶数丸めで読む。01-04「Float」の規則と一致する）。`Literal::Str`・`Char`・`Bool` はそのまま。
- 単項の `-` を整数リテラルに直接適用した式（`UnaryExpr { op: Neg, operand: Expr::Lit(Int) }`）は、符号を含めた定数にする。`-9223372036854775808` は `i64::MIN` になる。数字列を `u64` で読んでから符号を付けるなど、溢れない方法で求める。括弧を挟んだ `-(5)` はこの規則に当たらない（一般の `neg_T` になる）。
- `()` は `return ()`、`(e)` は `⟦e⟧`。

呼び出し:

- 呼ばれる式が構成子を指す名前（`Expr::Name` で束縛が `Ctor`）で、引数がすべてプレースホルダでない式なら、構成子の呼び出しの規則: `let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return C[T̄](x1, …, xn)`。
- そのほかの呼び出しは `let y ⇐ ⟦e0⟧ in let x1 ⇐ ⟦e1⟧ in … y(x1, …, xn)`。
- 引数にプレースホルダを含む呼び出しは、先にラムダへ展開する（01-02「部分適用のプレースホルダ」）。ラムダの引数はプレースホルダの左から順に新しい変数（型は `expr_types` のプレースホルダの型）、本体は「プレースホルダを引数の変数に置き換えた呼び出し」を上の規則で脱糖したもの。ラムダの `span` と、ラムダとその本体の呼び出しの由来位置は、プレースホルダを含む呼び出しの式全体の span（02-02）。エフェクトは `lambda_effects.get(call.id)`。呼び出す関数とプレースホルダでない引数は、ラムダの本体の中で評価する（01-08「評価順序」）。

パイプ `e1 |> e2`: `let t ⇐ ⟦e1⟧ in ⟦e'⟧`。`e'` は次の規則で作る（01-02「パイプ」、ADR 0050）。

1. `e2` が `Expr::Paren` なら、中身によらず規則 2（`(e2)(t)`）。
2. `e2` が `Expr::Call` で、直接の引数にプレースホルダがなければ、最も外側の呼び出しの引数の先頭に `t` を加えた呼び出し（規則 1）。`g(a)(b)` の形なら最も外側（`(b)`）に加える。直接の引数だけを見るので、`f(g(_))` は規則 1 で `f(t, g(_))` になる。
3. それ以外（名前、ラムダ、直接の引数にプレースホルダを含む呼び出しなど）は `e2(t)`（規則 2）。直接の引数にプレースホルダを含む呼び出しは、先にラムダに展開してから適用する。

AST を書き換えて新しい `CallExpr` を作るのではなく、「呼ばれる式」「引数の並び（先頭の `t` を含む）」を受け取る脱糖の関数を用意し、パイプと通常の呼び出しの両方から呼ぶ。展開で作った呼び出しの由来位置は、パイプの式全体の span（02-02）。`t` の型は `expr_types.get(e1.id())`。

演算子:

- `⊕` が `+ - * / % == != < <= > >=` のとき `let x ⇐ ⟦e1⟧ in let y ⇐ ⟦e2⟧ in ⊕_T(x, y)`。`⊕_T` は `ValKind::Builtin` で、演算子とオペランドの型 `T`（`operand_types`）の組から 10-10 の表の識別子を選ぶ。例: `+` と `Int` は `AddInt`、`+` と `String` は `ConcatString`、`>` と `Char` は `GtChar`。`==` と `!=` は `Eq`・`Ne` にし、`tys` に `[T]` を入れる（02-06「コア IR」）。表にない組は `InternalError`。
- 単項の `-`（整数リテラルの直接の適用を除く）は `let x ⇐ ⟦e⟧ in neg_T(x)`（`NegInt`・`NegFloat`）。
- `!e` は `let x ⇐ ⟦e⟧ in if x then return false else return true`。
- `e1 && e2` は `let x ⇐ ⟦e1⟧ in if x then ⟦e2⟧ else return false`、`e1 || e2` は `let x ⇐ ⟦e1⟧ in if x then return true else ⟦e2⟧`。`e2` を `let` の左側に移さないので、`e2` の中の末尾呼び出しは末尾位置のまま残る（01-08「末尾呼び出し」）。
- 演算子を適用する計算の由来位置は、演算子の式全体の span（02-02 の `a / b` の例）。

リスト、ラムダ、条件分岐、`match`、ブロック: 01-12 の表どおりに移す。

- ラムダの引数の型は `expr_types.get(param.id)`、エフェクトは `lambda_effects.get(lambda.id)`。ラムダの戻り値の型注釈と `uses` は、型検査で使い終えているので IR には残さない。
- `if e B1`（`else` なし）の `else` の側は `return ()`。`else if` は `else` の後の `if` を B2 として移す。
- `match e { … }` は `let x ⇐ ⟦e⟧ in match x { p1' ⇒ ⟦e1⟧ | … }`。パターンは `CorePat` に移す: ワイルドカードは `Wild`、変数のパターンは `Var`（束縛の番号に新しい `VarId` を対応させる）、リテラルは `Const`（前置の `-` は負の定数）、`()` は `Const(Unit)`、構成子のパターンは型名の修飾を除いて `Ctor { con, tag, args }`（`con`・`tag` は `resolved.refs` の束縛の種類から）。
- ブロックは文の並びの先頭から順に、01-12「ブロック」の 6 行で移す。`{ }` は `return ()`、最後の文が `let` なら `let x ⇐ ⟦e⟧ in return ()`。`let _ = e` と、最後でない式文は、新しい変数 `z` に束縛する。

### 型とエフェクトの付け方

02-06 の表に従う。計算のエフェクトは子の計算から下から求める。

- `return V`: 型は V の型、エフェクトは空集合。
- `let x ⇐ M in N`: 型は N の型、エフェクトは M と N の和集合。
- `V(W̄)`: 型は V の型（関数の型）の戻り値の型、エフェクトはその関数の型のエフェクト。`V` が `f[T̄; Ē]` か `b[T̄; Ē]` なら、宣言の型を `Ty::subst(&T̄, &Ē)` で置き換えた型を使う。組み込みの関数の宣言の型は `builtins::table::scheme`。
- `if`・`match`: 型は元の表層の式の型（`expr_types`）、エフェクトは分岐の和集合。
- 値 `[V̄]` の型は元の式の型、`C[T̄](V̄)` の型は `Ty::Con(con, T̄)`、ラムダは `Ty::func(引数の型, 本体の型, lambda_effects の値)`。

ラムダの型は、本体の型を求めてから作る。ラムダの本体の型が型検査の表の型と違っても、そのまま本体の型を使う（差があれば T18 の検査器が不具合として見つける）。

### 変えないこと

- 脱糖は `let` の右側が入れ子になった形（`let x ⇐ (let y ⇐ M in N) in P`）をそのまま残す（02-06「脱糖」の最後の段落）。平らにしない。
- 最適化をしない（02-06「最適化」）。

## 受け入れテスト

テストは、ソースの文字列を実際の前段（`pipeline::check_text` が未完成なら、T13・T15 の公開の関数を直接つなぐ）に通して `CheckedProgram` 相当を作り、`desugar` の結果の形を確かめる。利用者の定義の本体だけを取り出して比べる補助の関数を一つ用意する。

| 場合 | 入力（`main` の本体など） | 期待する結果 |
|---|---|---|
| 除算 | `fn f(a: Int, b: Int) -> Int { a / b }` | 本体が `let x ⇐ return a in let y ⇐ return b in DivInt(x, y)` の形。適用の計算の由来位置は `a / b` の span |
| 演算子の選択 | `1.0 + 2.0`、`"a" + "b"`、`'a' > 'b'`、`[1] == [2]` | それぞれ `AddFloat`、`ConcatString`、`GtChar`、`Eq` で `tys = [List[Int]]` |
| 負の整数リテラル | `-9223372036854775808` と `-(5)` | 前者は `return c`（`c` は `i64::MIN`）、後者は `NegInt` の適用 |
| 論理演算 | `a && f(b)` | `let x ⇐ return a in if x then (f の呼び出しの脱糖) else return false`。`f(b)` の呼び出しは `if` の分岐の中にあり、`let` の左側にない |
| パイプ規則 1 | `xs \|> List.map(g)` | `let t ⇐ … in` の後、`List.map` を指す `TopFn` に `t, g` の順で引数を渡す適用。適用の由来位置はパイプの式全体 |
| パイプ規則 2 と括弧 | `x \|> (h(1))` | `h(1)` の結果を呼び出し、`t` を引数とする適用 |
| プレースホルダ | `clamp(0, _, 100)` | 引数一つのラムダ。ラムダの `span` と本体の適用の由来位置は呼び出しの式全体。`0` と `100` の評価はラムダの本体の中 |
| 構成子 | `Shape.Circle(1.0)`、`Tree.Leaf`、`List.map(rs, Shape.Circle)` | 1 つ目は `Ctor` の値を返す `let` の並び、2 つ目は引数のない `Ctor`、3 つ目の `Shape.Circle` は `Ctor` を返すラムダ |
| 組み込みの関数を値として使う | `List.map(xs, Int.toString)` | `Int.toString` は `ValKind::Builtin { id: IntToString, .. }` |
| ブロック | `{ let _ = f(); g(); 1 }` | `let z1 ⇐ f() in let z2 ⇐ g() in return 1`（`z1`・`z2` は別の `VarId`） |
| `else` なしの `if` | `if c { Console.println("a") }` | `else` の側が `return ()` |
| `match` | `match o { Some(x) => x  None => 0 }` | `let s ⇐ return o in match s { Ctor(Option, 0, [Var x]) ⇒ return x \| Ctor(Option, 1, []) ⇒ return 0 }` |
| 変数の番号 | 同じ名前の `let` を三度重ねる関数 | 三つの `Var` の `VarId` がすべて異なり、`var_count` がその定義で振った数と一致する |
| エフェクト | `fn main() -> Unit uses IO { Console.println("a") }` | 本体の計算のエフェクトが `{IO}`。純粋な関数の本体は空集合 |
| 定義の並びと名前 | prelude と利用者の関数を含むプログラム | 定義の並びは prelude の定義が先。`List.map` の定義の `name` が `"List.map"`、`origin` が `PreludePublic { module: List }`、`mapInto` は `PreludeHelper` |
| prelude のソース全体 | 利用者の `main` だけのプログラム | `desugar` が `Ok` を返す（prelude のソースのすべての定義を脱糖できる） |

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- 01-12「表層からの脱糖」の表の各行に、それを実装する関数があり、関数の `///` のコメントがその行を示している
- コア IR の検査器（T18）による確かめは T25 で行う。本作業のテストは T18 に依存しない

## 難易度の理由

規則の数が多く（01-12 の表の約 25 行）、型検査の五つの表と名前解決の表を正しく組み合わせて引く必要がある。パイプとプレースホルダの展開は、規則 1・2・括弧の規則・直接の引数だけを見る判定が重なり、取り違えても型の付くコード（引数の順の違い）になりうるので誤りが見えにくい。型とエフェクトを各ノードに付ける規則も、後の段（T18〜T21）の前提になる。
