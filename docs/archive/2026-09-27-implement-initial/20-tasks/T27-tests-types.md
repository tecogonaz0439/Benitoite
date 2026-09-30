# T27 テストの作成: 型・エフェクト・パターン

- 依存する作業: [T25](T25-golden-runner.md)
- 難易度: 3（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（ゴールデンテストのスクリプトが 50〜70 本）
- ブランチ: impl/T27-tests-types

## 目的

型システム・エフェクト・パターンマッチの規則について、ゴールデンテストを `testdata/types/`・`testdata/effects/`・`testdata/patterns/` に置く。E04・E05・E06 の診断コードをすべて一度以上起こし、型の誤りの後も検査を続けて互いに独立した誤りをすべて報告すること、一つの誤りから派生した診断を出さないことを確かめる（ADR 0024）。エフェクト多相とエフェクトの包含は、正しいプログラムが検査を通ることも確かめる。

## 読む設計書の節

- [型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md): 「型」から「prelude の関数の型」まで
- [エフェクト](../../2026-09-27-design-initial/01-spec/01-07-effects.md): 「IO エフェクトが表す操作」「IO の失敗」「プログラムの入口」「IO を行う組み込み関数」
- [代数的データ型とパターンマッチ](../../2026-09-27-design-initial/01-spec/01-05-data-types.md): 「型の宣言」から「選ばれない分岐の検査」まで
- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md): 「Int」「Float」のリテラルの範囲、「String」の `+`
- [型検査器](../../2026-09-27-design-initial/02-impl/02-05-typechecker.md): 全節（特に「制約の解決」の例、「本体の後の検査」、「誤りの報告と検査の継続」）
- [処理系のテスト戦略](../../2026-09-27-design-initial/07-quality/07-03-compiler-testing.md): 「ゴールデンテスト」「派生した診断が出ないことのテスト」
- [診断](../10-interfaces/10-02-diagnostics.md): E04〜E06 の型板と `extras` の鍵
- [T25 ゴールデンテストの実行器](T25-golden-runner.md)

## 作るもの

- `crates/benitoite/testdata/types/*.bnt` と期待値のファイル
- `crates/benitoite/testdata/effects/*.bnt` と期待値のファイル
- `crates/benitoite/testdata/patterns/*.bnt` と期待値のファイル

処理系のソースは変えない。

## 手順の要点

- 書き方の決まり（`// spec:` の行、書き直しの指定で作った期待値を一行ずつ仕様と照らすこと、処理系が仕様と食い違うときの扱い）は [T26](T26-tests-front.md) の「手順の要点」と同じである。
- 正しいプログラムが検査を通ることを確かめるテストは `run` にし、推論した型が値の振る舞いに表れるようにする（多相な関数を二つの型で使って両方の結果を出力する、など）。
- 型の誤りの期待値では、`expected` と `found` の型の表示（10-05 の `Ty::show`）、理由の注記（`because_*`）、補助の位置（`declared`）が 02-05「誤りの報告と検査の継続」のとおりかを確かめる。まだ決まらない型の表示は、T14・T15 の文書が定める形（型変数を `_` で示すなど）に従う。
- 同じ誤りが制約の解く順で別の位置に報告されうる場合は、02-05「制約の解決」の手順 1（宣言と型注釈から生じた制約を先に解く）のとおり、宣言に合わない使い方の側が報告されることを確かめる。

### 置くテスト

| 区分 | 名前 | 確かめること | コード |
|---|---|---|---|
| types | `mismatch_let_annotation` | 02-10 の例（`let n: Int = "a"`） | E0401 |
| types | `mismatch_call_arg` | 引数の型の誤りと、引数の型を宣言した箇所の補助の位置 | E0401 |
| types | `mismatch_if_branches` | `if` の二つの分岐の型が違う | E0401 |
| types | `if_without_else_not_unit` | `else` のない `if` の分岐が `Int` | E0401 |
| types | `condition_not_bool` | `if 1 { ... }` | E0401 |
| types | `float_literal_help` | `x * 2`（`x` は `Float`）と `2.0` の修正案 | E0401 |
| types | `string_plus_int` | `"n = " + n` と `Int.toString` の修正案。`Float`・`Char` も | E0401 または E0405 |
| types | `arity` | 引数の個数の誤り。構成子の呼び出しの個数の誤りも | E0402 |
| types | `not_a_function` | `let x = 1` の後の `x(2)` | E0403 |
| types | `infinite_type` | `fn(f) { f(f) }` | E0404 |
| types | `operator_set` | `true + false`、`'a' * 'b'`、`[1] < [2]` | E0405 |
| types | `rem_operands` | `2 % 1.5`（`%` のオペランドは `Int` と等しくする。T15） | E0401（注記 `because_int_operands`） |
| types | `operator_on_type_param` | 型パラメータ `T` の値に `<` を使う | E0405 |
| types | `equality_function` | 関数の値を `==` で比べる | E0406 |
| types | `equality_ioerror` | `Result[String, IoError]` を `==` で比べる（ADR 0048） | E0406 |
| types | `equality_summary` | `type Nest[T] { Leaf(T) Deep(Nest[List[T]]) }` の `Nest[Int]` は比べられ、`Nest[fn() -> Unit]` は比べられない（ADR 0082） | E0406 |
| types | `equality_adt_ok` | 代数的データ型とリストの `==` と、`Some(0.0 / 0.0) == Some(0.0 / 0.0)` が `false`（出力で確かめる） | なし |
| types | `undetermined` | 01-06「演算子の型付け」の `let add = fn(a, b) { a + b }`（型注釈の修正案）と、`add(1, 2)` で決まる場合 | E0407 |
| types | `int_literal_range` | `9223372036854775808` は誤り、`-9223372036854775808` は正しい。リテラルのパターンでも同じ | E0408 |
| types | `float_literal_range` | `1e309` は誤り、`1e308` は正しい | E0409 |
| types | `type_arg_count` | `List` を型引数なしで、`Option[Int, Int]` を書く | E0410 |
| types | `type_no_ctors` | `type Empty { }` | E0411 |
| types | `pattern_arity` | `Shape.Rect(w)` | E0412 |
| types | `nullary_ctor_parens` | 式の `Tree.Leaf()` と `None()`、パターンの `Tree.Leaf()` | E0413 |
| types | `missing_main` | `main` がない | E0414 |
| types | `main_signature` | 引数を持つ、型パラメータを持つ、`Int` を返す、`Result[Int, String]` を返す、エフェクト変数を持つ。一つのスクリプトに一つずつ（5 本） | E0415 |
| types | `main_result_ok` | `Result[Unit, String]` を返す `main` は検査を通る | なし |
| types | `discarded_value` | 最後でない式文が `Int`。`let _ =` の修正案 | E0416 |
| types | `too_many_effect_vars` | `uses E, F` | E0417 |
| types | `effect_var_unused` | 引数の型に現れないエフェクト変数 | E0418 |
| types | `duplicate_in_uses` | `uses IO, IO` | E0419 |
| types | `no_let_polymorphism` | 01-06「多相」の `id` の例 | E0401 |
| types | `generic_functions` | 型パラメータを持つ関数（`getOr` など）を二つの型で使う | なし |
| types | `independent_errors` | 【派生した診断が出ないことのテスト 1】一つの関数に互いに独立した型の誤りが三つある。三つとも報告される | E0401 ほか |
| types | `no_cascade` | 【派生した診断が出ないことのテスト 2】誤った型の変数を後で何度も使う。最初の誤りだけが報告される | E0401 |
| types | `errors_across_functions` | 二つの関数にそれぞれ誤り。両方が報告される | E0401 |
| effects | `pure_calls_io` | 01-06「式のエフェクト」の `greet` の例。宣言に含まれないエフェクトと呼び出しの位置 | E0501 |
| effects | `lambda_uses_violation` | `fn() -> Unit uses E { Console.println("x") }` のように、ラムダの `uses` に含まれない IO | E0502 |
| effects | `lambda_effect_inferred` | `uses` を書かないラムダの本体の IO は、ラムダの型のエフェクトになり、ラムダを作るだけの関数は純粋のまま検査を通る | なし |
| effects | `map_with_io` | 01-06「エフェクト変数の具体化」の例（純粋なラムダの `map` は純粋、IO のラムダの `map` は IO） | なし／E0501 |
| effects | `choose_example` | 02-05「制約の解決」の `choose` の例は検査を通り、第 2 引数を IO のラムダに変えると `main` の本体の誤りになる | なし／E0501 |
| effects | `run_all_subsumption` | 01-06「エフェクトの包含」の `runAll` と `let f: fn() -> Unit uses IO = fn() { () }` | なし |
| effects | `list_element_order` | 02-05 の `[fn() { () }, fn() { Console.println("a") }]` と要素を入れ替えたもの。どちらも同じ型になる | なし |
| effects | `outermost_only` | `List[fn() -> Unit]` の変数を `List[fn() -> Unit uses IO]` の引数に渡すと誤り | E0401 |
| effects | `effect_var_rigid` | エフェクト変数 `E` の位置に `uses IO` の関数を渡す関数の本体は誤り | E0401 または E0501 |
| effects | `widen_result` | 01-12 の `make`・`widen` の例が検査を通り、実行できる | なし |
| patterns | `nonexhaustive_adt` | `Tree` の `match` で `Tree.Node(Tree.Leaf, _, _)` が漏れる。反例の形を示す | E0601 |
| patterns | `nonexhaustive_option` | `Some(1)` と `None` だけの `Option[Int]` | E0601 |
| patterns | `nonexhaustive_literals` | `Int`・`String`・`Char` はリテラルを並べても網羅しない | E0601 |
| patterns | `exhaustive_bool_unit` | `Bool` の `true`・`false`、`Unit` の `()` は網羅する | なし |
| patterns | `unreachable_after_wild` | 01-05 の `_ => "other"` の後の `0 => "zero"` | E0602 |
| patterns | `unreachable_covering_many` | 一つの分岐が、前の二つの分岐の組み合わせで覆われる。覆っている分岐がすべて補助の位置に示される（02-05「本体の後の検査」） | E0602 |
| patterns | `uninhabited_not_unreachable` | 01-05 の `type L { Mk(L) }` の `L.Mk(_)` の分岐は選ばれない分岐にならない | なし |
| patterns | `float_and_list_wild` | `Float` と `List` の `match` はワイルドカードか変数のパターンで網羅する | なし |
| patterns | `match_on_error_type` | 対象の型が誤りの型の `match` は、パターンの検査の誤りを出さない（型の誤りだけが出る） | E0401 |
| patterns | `nested_patterns_run` | 入れ子の構成子のパターンと、リテラル・変数の組み合わせが、最初に照合する分岐を選ぶ（出力で確かめる） | なし |

表の後で `spec_coverage.py` を実行し、01-05・01-06・01-07 の最小実行版の範囲の節のうち、テストのない節が残っていれば、テストを足すか、足さない理由を完了の報告に書く。

## 受け入れテスト

- 上の表のテストがすべて置かれている。
- E0401〜E0419、E0501〜E0502、E0601〜E0602 の各コードを起こすテストが一本以上ある（`.diag.json` を grep して確かめ、完了の報告に一覧を書く）。
- 派生した診断が出ないことのテスト（`independent_errors` と `no_cascade`）の `.diag.json` が、期待する診断だけを持つ（07-03「派生した診断が出ないことのテスト」）。
- 02-10「修正案」の表のうち、型の行（`Float` の位置の整数リテラル、`String` と他の型の `+`、型が決まらない、引数のない構成子の括弧）の修正案が、期待値の `helps` に現れる。
- 各スクリプトの先頭に `// spec:` の行がある。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）。ただし、仕様と処理系が食い違うと報告したテストの失敗は除く
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、仕様と食い違った処理系の振る舞いの一覧を書く

## 難易度の理由

テストの作成であり、処理系のコードは書かない。ただし、期待値の診断が正しいかを判断するには、制約を解く順序、エフェクトの最小の解、等値の型の要約、有用性による網羅性の判定（02-05）を追って、どの位置にどの型の組が報告されるはずかを自分で導く必要がある。字句と構文のテスト（T26）より、仕様から期待値を導く推論が長い。
