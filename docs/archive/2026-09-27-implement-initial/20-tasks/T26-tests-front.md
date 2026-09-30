# T26 テストの作成: 字句・構文・名前

- 依存する作業: [T25](T25-golden-runner.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（ゴールデンテストのスクリプトが 50〜70 本）
- ブランチ: impl/T26-tests-front

## 目的

字句構造・構文・名前の規則について、ゴールデンテストを `testdata/lexical/`・`testdata/syntax/`・`testdata/names/` に置く。E01・E02・E03 の診断コードのうち、ゴールデンテストで起こせるものをすべて一度以上起こし、修正案を示す診断（02-10「修正案」の表）がその修正案を示すことを確かめる。処理系を実装した LLM と別の LLM がこの作業を担当すれば、実装が仕様を読み違えた箇所を見つけやすい。

## 読む設計書の節

- [字句構造](../../2026-09-27-design-initial/01-spec/01-01-lexical.md): 全節
- [構文](../../2026-09-27-design-initial/01-spec/01-02-syntax.md): 「文法」から「部分適用のプレースホルダ」まで、「最小実行版に含めない構文」「例」
- [名前・スコープ・モジュール](../../2026-09-27-design-initial/01-spec/01-03-names-modules.md): 「名前の種類」から「シャドーイング」まで
- [字句解析器と構文解析器](../../2026-09-27-design-initial/02-impl/02-03-frontend.md): 「字句」「構文解析の方式」「型の解析」「誤りからの回復」「入れ子の深さ」
- [名前解決とモジュール読込](../../2026-09-27-design-initial/02-impl/02-04-resolver.md): 「誤りと修正案」
- [診断エンジン](../../2026-09-27-design-initial/02-impl/02-10-diagnostics.md): 「修正案」
- [処理系のテスト戦略](../../2026-09-27-design-initial/07-quality/07-03-compiler-testing.md): 「テストの設計の原則」「ゴールデンテスト」
- [診断](../10-interfaces/10-02-diagnostics.md): 「診断コードの初めの一覧」（各コードの型板と `extras` の鍵）
- [T25 ゴールデンテストの実行器](T25-golden-runner.md): 期待値のファイルの組と書き直しの指定

## 作るもの

- `crates/benitoite/testdata/lexical/*.bnt` と期待値のファイル
- `crates/benitoite/testdata/syntax/*.bnt` と期待値のファイル
- `crates/benitoite/testdata/names/*.bnt` と期待値のファイル

処理系のソースは変えない。テストが仕様と食い違う処理系の振る舞いを見つけたら、期待値を処理系に合わせずに、そのテストを失敗させたまま報告する（後述）。

## 手順の要点

- 各スクリプトの先頭に、確かめる仕様の項目を `// spec: <章の番号> <節の見出し>` の形で書く（07-03「ゴールデンテスト」）。見出しは章の見出しをそのまま写す（T25 の `spec_coverage.py` が照合する）。
- 誤りのテストは、原則として一つのスクリプトで一つの誤りを起こす。例外は、誤りからの回復（複数の誤りをすべて報告し、派生した誤りを出さないこと）を確かめるテストである。
- 誤りのテストのモードは `check` とする。誤りのないテストのうち、構文が正しく読めることを確かめるものは、`main` を持つ `run` のテストにし、読めた構造が値に表れるようにする（例: 演算子の優先順位のテストは、計算の結果を出力する）。AST の形そのものは T11・T12 の単体テストが確かめる。
- 期待値のファイルは、`BENITOITE_BLESS=1` で作ってから、すべて読んで仕様と照らす（ADR 0039「帰結」）。`.diag.json` の各行について、コード・主な位置の範囲・ラベル・修正案が、仕様と 10-02 の型板に合っているかを確かめる。合っていなければ、処理系の不具合として完了の報告に書き、期待値は仕様どおりの内容に手で直す（そのテストは失敗する）。
- 文章の形式の体裁（02-10「文章の形式」）を確かめる `.text.stderr` は、本作業では 3 本に置く: 主な位置だけの診断、補助の位置が別の行にある診断（E0305 の `first defined here`）、タブを含む行の抜粋。書き直しの指定は、`.text.stderr` があるときだけそれを書き直すので、先に空の `.text.stderr` を置いてから書き直しの指定で実行し、出力を読んで確かめる（T25）。
- ソースに正しくない UTF-8 や制御文字を含めるテストは、バイト列でファイルを作る（エディタで書けないので、作り方を完了の報告に書く）。
- E0101（ファイルを読めない）はゴールデンテストでは起こせない（`check_text` はファイルを読まない）。T25 の `cli_process.rs` が確かめるので、本作業では扱わない。

### 置くテスト

次の表のテストを置く。名前は例であり、変えてよい。「コード」は、そのテストが起こす診断である。

| 区分 | 名前 | 確かめること | コード |
|---|---|---|---|
| lexical | `invalid_utf8` | 正しくない UTF-8 のバイト | E0102 |
| lexical | `bom_at_start` | ファイルの先頭の BOM は無視し、1 行目の列に数えない（誤りのある 1 行目の列で確かめる） | E0201 など |
| lexical | `fullwidth_space` | 全角空白（U+3000）を文字列の外に書く | E0103 |
| lexical | `nbsp_outside` | U+00A0 を文字列の外に書く | E0103 |
| lexical | `bidi_in_string` | 文字列リテラルの中の U+202E。`\u{...}` の修正案 | E0104 |
| lexical | `bidi_in_comment` | コメントの中の U+2066 | E0104 |
| lexical | `bom_in_middle` | 先頭以外の U+FEFF | E0104 |
| lexical | `unknown_symbol` | `@`・`#`・`?`（最小実行版では記号でない） | E0105 |
| lexical | `semicolon` | `;` と改行で区切る修正案。`let x = 1; let y = 2` の形で、診断が E0106 の一件だけであること（`;` は改行の印になり、構文の誤りが派生しない。T02） | E0106 |
| lexical | `lone_cr` | LF を伴わない CR | E0107 |
| lexical | `crlf_ok` | CR LF の改行で書いたスクリプトが実行できる | なし |
| lexical | `unterminated_string` | 行の終わりで閉じたものとして続け、後の誤りも報告する | E0108 |
| lexical | `unterminated_char` | 閉じていない文字リテラル | E0109 |
| lexical | `bad_escape` | `\q`、`\u{110000}`、`\u{D800}`、文字列の中の `\'` | E0110 |
| lexical | `interpolation_reserved` | `"a${x}"` と `\$` の修正案。`"$a"` は誤りでない | E0111 |
| lexical | `empty_char` | `''` | E0112 |
| lexical | `multi_char` | 結合文字を含む文字リテラルと、文字列リテラルの修正案 | E0113 |
| lexical | `control_in_literal` | 文字列リテラルの中の U+0007 | E0114 |
| lexical | `int_literals_ok` | 10 進・16 進・8 進・2 進と `_` の値（出力で確かめる） | なし |
| lexical | `int_malformed` | `007`、`1__0`、`0x`、`0XFF`、`12abc`、`0xfg`、`1_` | E0115 |
| lexical | `float_malformed` | `1.`、`00.5`、`01e5`、`1e`、`1.5.2`、`1.5x` | E0116 |
| lexical | `reserved_loop` | `for`・`while`・`loop` と、再帰や `List.map` の修正案 | E0117 |
| lexical | `reserved_return` | `return` と、最後の式の値が戻り値である修正案 | E0117 |
| lexical | `reserved_other` | `class` を名前に使う | E0117 |
| lexical | `permissions_is_ident` | `permissions`・`with`・`record`・`from` は最小実行版では識別子に使える | なし |
| lexical | `comment_kept_out` | `//` のコメントと、文字列の中の `//` がコメントでないこと | なし |
| syntax | `newline_continuation` | 01-01「改行による区切り」の例（`* quantity` の継続、`|>` の行頭、`} else {`） | なし |
| syntax | `newline_minus` | 行頭の `-` は新しい文になる（最後でない式文として E0416 が出るのは T27 の範囲なので、本テストは最後の文で値になる場合を確かめる） | なし |
| syntax | `brace_next_line` | `{` を次の行に書く。前の行の末尾に書く修正案 | E0205 |
| syntax | `unexpected_token` | 式の位置に `)` | E0201 |
| syntax | `recovery_many` | 三つの関数にそれぞれ一つの構文エラー。三つとも報告し、派生した誤りがない | E0201 |
| syntax | `chained_comparison` | `a < b < c` と `a < b && b < c` の修正案 | E0202 |
| syntax | `dot_after_value` | `xs.map(f)` と `|>` の修正案 | E0203 |
| syntax | `placeholder_misplaced` | `_ + 1` | E0204 |
| syntax | `ctor_decl_parens` | 型の宣言の `Leaf()` | E0206 |
| syntax | `qualified_fn_decl` | 利用者のソースの `fn List.map(...)` | E0207 |
| syntax | `too_deep` | 1001 段の括弧の入れ子（スクリプトを生成して置く） | E0208 |
| syntax | `uses_then_bracket` | `fn(fn() -> Unit uses IO, List[Int]) -> Unit` | E0209 |
| syntax | `lambda_underscore_param` | `fn(_, x) { x }` と `_unused` の修正案 | E0210 |
| syntax | `precedence` | 01-02 の優先順位の表の各段（`1 + 2 * 3`、`-2 * 3`、`!a && b`、`a || b && c`） | なし |
| syntax | `pipe_rules` | 01-02「パイプ」の例のすべて（規則 1・2、括弧の右辺、呼び出しを重ねた形） | なし |
| syntax | `placeholder_rules` | 01-02「部分適用のプレースホルダ」の例（`clamp(0, _, 100)`、`between(_, lo, _)`、`f(g(_))`） | なし |
| syntax | `uses_longest_match` | `fn((fn() -> Unit uses IO), Int) -> Unit` と、戻り値の型に付く `uses` の例 | なし |
| syntax | `else_if_chain` | `else if` の連なり | なし |
| syntax | `trailing_commas` | 引数・型引数・リストの末尾のコンマ | なし |
| syntax | `example_shapes` | 01-02「例」のプログラムを実行して出力を確かめる | なし |
| names | `unknown_name` | 綴りの近い名前の修正案（距離 2 以下、最大 3 つ、距離の順） | E0301 |
| names | `unknown_module` | `Lst.map` と `List` の修正案 | E0302 |
| names | `unknown_member` | `List.mapp` と修正案 | E0303 |
| names | `string_length` | `String.length` と、単位を持つ関数の修正案。`String.substring`・`String.indexOf` も | E0303 |
| names | `option_unwrap` | `Option.unwrap` と `Result.expect` の修正案 | E0303 |
| names | `prelude_only_hidden` | `List.dropFirst` は利用者から見えない | E0303 |
| names | `wrong_kind` | 式の中の型の名前（`Shape`）、修飾しない構成子（`Circle`）と修飾の修正案 | E0304 |
| names | `duplicate_type` | 同じ型の名前を二度。補助の位置 `first defined here` | E0305 |
| names | `duplicate_fn` | 同じ関数の名前を二度 | E0306 |
| names | `type_named_prelude` | `type List { ... }`、`type Console { ... }`、`type IO { ... }` | E0307 |
| names | `type_named_some` | `type Some { ... }` | E0308 |
| names | `duplicate_ctor` | 一つの型の宣言の中の同じ構成子 | E0309 |
| names | `duplicate_param` | 関数とラムダの引数の重複 | E0310 |
| names | `duplicate_pattern_var` | `Shape.Rect(x, x)` | E0311 |
| names | `duplicate_type_param` | `fn f[T, T]` | E0312 |
| names | `type_param_toplevel` | `fn f[List]`、`fn g[Shape]` | E0313 |
| names | `effect_as_type` | `fn f[effect E](x: E)`、`x: IO` | E0314 |
| names | `uses_not_effect_first` | `uses Int` | E0315 |
| names | `uses_not_effect_later` | `uses IO, Int` と括弧で囲む修正案 | E0316 |
| names | `qualified_some` | `Option.Some(1)` と修飾しない修正案 | E0317 |
| names | `shadowing` | 01-03「シャドーイング」の例と、同じブロックでの再束縛、`let x = x + 1` の右辺が外側を指すこと | なし |
| names | `decl_order` | 宣言より前の位置からの参照、相互再帰、相互再帰型 | なし |
| names | `helper_name_clash` | 利用者の関数 `mapInto` と prelude の補助の関数が衝突しない（`List.map` も正しく動く） | なし |

表の後で `spec_coverage.py` を実行し、01-01・01-02・01-03 の最小実行版の範囲の節のうち、テストのない節が残っていれば、テストを足すか、足さない理由を完了の報告に書く。

## 受け入れテスト

- 上の表のテストがすべて置かれている。
- E0102〜E0117、E0201〜E0210、E0301〜E0317 の各コードを起こすテストが一本以上ある（`grep -l '"code":"E0xxx"' testdata/*/*.diag.json` で確かめ、完了の報告に一覧を書く）。
- 02-10「修正案」の表のうち、字句・構文・名前の行（予約語、`;`、`${`、複数のスカラー値の文字、`{` の位置、比較演算子の連ね、値に続けたドット、見つからない名前、`uses` の並び）の修正案が、期待値の `helps` に現れる。
- `.text.stderr` を持つテストが 3 本ある。
- 各スクリプトの先頭に `// spec:` の行がある。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）。ただし、仕様と処理系が食い違うと報告したテストの失敗は除く
- 受け入れテストのすべての場合を確かめるテストがある
- 完了の報告に、仕様と食い違った処理系の振る舞いの一覧（テストの名前、仕様の節、実際の出力）を書く

## 難易度の理由

仕様の規則をスクリプトと期待値に写す作業であり、アルゴリズムを書く必要はない。規則の数は多いが、どれも 01-01〜01-03 と 02-10 に具体的な例と修正案が書いてある。手間がかかるのは、書き直しの指定で作った期待値を一行ずつ仕様と照らす確認である。
