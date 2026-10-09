# F02 構文解析 1: 構文の全体の書き直しと他の言語の書き方への診断

- 依存する作業: [F01](F01-lexer.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/F02-parser-core

## 目的

構文解析器を、初回リリース版の構文（キーワードで始めて `end` と構文の名前で閉じるブロック、`function`・`lambda`・`if … then`、`->` の戻り値の型、`bind`・`shadow`、`data`、`match … with case`、演算子 `=`・`<>`・`and`・`or`・`not`・`div`・`mod`）で書き直す。あわせて、他の言語の書き方と最小実行版の書き方（波括弧のブロック、`fn`、`let`、`==`・`&&` など）への診断を出す。

本作業は、構文解析器の基盤（字句の読み進め、報告の抑制、誤りからの回復、入れ子の深さの数え上げ、解析の文脈の印）と、F03・F04 が並行して中身を書く子のモジュールの境目を置く（10-03「置く作業と既存のファイル」）。F03・F04 が受け持つ構文は、本作業では仮の本体を持つ関数（フック）として置く。本作業の後、C03 が最小実行版のテストを新しい構文で書き直すので、最小実行版の言語の範囲の構文は、本作業だけで読めなければならない。

## 読む設計書の節

- [字句解析器と構文解析器](../../design/02-impl/02-03-frontend.md): 全体（特に「構文解析の方式」「文脈の制限」「構文の規則に伴う診断」「他の言語の書き方への診断」「型の解析」「AST」「誤りからの回復」「入れ子の深さ」「構文解析の結果」「標準ライブラリのソースの構文」）
- [構文](../../design/01-spec/01-02-syntax.md): 「EBNF の表記」「プログラムと宣言」「ブロックと文」「`return`」「条件分岐」「パターンマッチ」「ラムダ」「演算子の優先順位と結合性」「ドット記法」「パイプ」「部分適用のプレースホルダ」「初回リリース版の文法の全体」「例」
- [字句構造](../../design/01-spec/01-01-lexical.md): 「キーワード」「演算子と区切り記号」「改行による区切り」
- [代数的データ型とパターンマッチ](../../design/01-spec/01-05-data-types.md): 「型の宣言」「パターン」
- [名前・スコープ・モジュール](../../design/01-spec/01-03-names-modules.md): 「シャドーイング」（`bind` と `shadow` の書き分けは名前解決が検査する。本作業は書いた方を記録するだけ）
- [ソース管理と位置情報](../../design/02-impl/02-02-source-and-spans.md): 「span」
- [診断エンジン](../../design/02-impl/02-10-diagnostics.md): 「修正案」（構文の行）
- ADR: [0020](../../design/decisions/0020-recursive-descent-with-pratt.md)、[0047](../../design/decisions/0047-parenthesized-types-and-uses-binding.md)、[0050](../../design/decisions/0050-pipe-with-parenthesized-rhs.md)、[0086](../../design/decisions/0086-pattern-nodes-count-toward-nesting-limit.md)、[0108](../../design/decisions/0108-keyword-blocks-closed-by-end.md)〜[0113](../../design/decisions/0113-div-and-mod-operators.md)、[0254](../../design/decisions/0254-return-type-after-arrow.md)〜[0257](../../design/decisions/0257-match-with-case-arms.md)
- インターフェース: [字句と構文木](../10-interfaces/10-03-syntax.md)の全体、[診断](../10-interfaces/10-02-diagnostics.md)の「E02 構文」の表と `codes.rs` の E0105・E0106・E0201〜E0216・E0230〜E0234・E0238〜E0240・E0243 の項目、[基本の型](../10-interfaces/10-01-base.md)の `IdGen`・`Span`・`SourceKind`

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

| ファイル | 中身 | 本作業の後に中身を書く作業 |
|---|---|---|
| `src/syntax/parser/mod.rs` | 10-03 の `sig=`（`MAX_DEPTH`・`ParseOutput`・`parse`）、解析器の状態 `Parser`、基盤の関数、フックの表（モジュールの先頭の `//!`） | —（F02 だけ） |
| `src/syntax/parser/decls.rs` | トップレベルの宣言の並び、関数の宣言、`data` の宣言、ほかの宣言の振り分け | — |
| `src/syntax/parser/exprs.rs` | Pratt 法の式、ブロックと文、束縛の文、`if`・`match`・ラムダ・`return`、呼び出し、パイプ、プレースホルダ、リストリテラル | — |
| `src/syntax/parser/patterns.rs` | 基本のパターン（ワイルドカード、変数、リテラル、`()`、構成子） | — |
| `src/syntax/parser/types.rs` | 型、`uses` の並び、型パラメータの並び（制約の構文を含む） | — |
| `src/syntax/parser/foreign.rs` | 他の言語と最小実行版の書き方への診断、`BadSymbol` の報告 | — |
| `src/syntax/parser/text.rs` | E0201 の `{expected}`・`{found}` に埋める字句と構文の呼び名（[実装の規約](../00-common/00-02-conventions.md)の「文言」） | — |
| `src/syntax/parser/snippet.rs` | span の範囲のソースの文字列を返す関数（後述の「型板に埋めるソースの断片」） | — |
| `src/syntax/parser/test_support.rs` | `#[cfg(test)] pub(crate)` のテストの補助（後述） | — |
| `src/syntax/parser/items.rs` | F03 のフック（仮の本体） | F03 |
| `src/syntax/parser/records.rs` | F03 のフック（仮の本体） | F03 |
| `src/syntax/parser/traits.rs` | F04 のフック（仮の本体） | F04 |
| `src/syntax/parser/effects.rs` | F04 のフック（仮の本体） | F04 |
| `src/syntax/parser/interp.rs` | F04 のフック（仮の本体） | F04 |
| `src/syntax/parser/spread.rs` | F04 のフック（仮の本体） | F04 |
| `src/syntax/parser/patterns_ext.rs` | F04 のフック（仮の本体） | F04 |

- 子のモジュールはすべて `parser/mod.rs` で非公開（`mod x;`、テストの補助は `#[cfg(test)] pub(crate) mod test_support;`）で宣言する。外に見せるのは 10-03 の `sig=` の項目だけである。
- 各ファイルの `#[cfg(test)] mod tests` のテスト。
- `src/diag/codes.rs` の、本作業が出すコードの型板の直し（10-02「型板の直し方」の範囲）。
- `testdata-next/syntax/` のゴールデンテスト（後述の「受け入れテスト」）。

`token.rs`・`ast.rs`・`lexer.rs`・`newline.rs`（F01）と `src/legacy/` は変えない。最小実行版の構文解析器（`src/legacy/syntax/parser/`）の基盤（`Parser` の読み進め、報告の抑制、`comma_list`・`line_list`、回復、深さの数え方、スタックを小さく保つ書き方）は写してよい。規則ごとの関数は、字句と AST が違うので書き直す。

## 手順の要点

### 基盤（`mod.rs`）

- `Parser` は、ソースのバイト列（`parse` の `text`）、字句の列と読む位置、ファイル ID、`SourceKind`、`IdGen`（`parse` の間だけ預かり、終わったら呼び出し側へ戻す。最小実行版のとおり）、診断の一覧、報告の抑制の印、打ち切りの印、入れ子の深さ、開いているブロックの積み重ね（構文の種類と開いた位置。E0213・E0214 に使う）、報告済みの `BadSymbol` の字句の位置の集合、解析の文脈（後述）、ドキュメントコメントの置き場（`items::DocStore`。F03 が中身を書く）を持つ。
- 報告の抑制と回復は 02-03「誤りからの回復」のとおりとし、最小実行版の形を写す。`BadSymbol` の報告は抑制の対象にしない。回復で読み飛ばす字句に `BadSymbol` があれば、読み飛ばすときにも一度だけ報告する（後述の「字句に使えない記号」）。
- 読み飛ばす先は 02-03 の表のとおりである。トップレベルの宣言の読み飛ばす先は、括弧の外の、行の先頭の `import`・`public`・`@`・`function`・`const`・`data`・`type`・`record`・`trait`・`implement`・`effect` である。
- `Error` の字句（字句の段が報告済み）は、その位置で期待していた構文の誤りのノードにし、新しい構文エラーを出さない。
- 入れ子の深さは 02-03「入れ子の深さ」の数え方（文と並びの要素の `i + 1`、パターンの節の通し番号を含む）で数え、上限 `MAX_DEPTH` を超えたら E0208（`limit` に 1000）を一つ報告し、打ち切りの印を立ててそのファイルの解析をやめる。深さを数える関数は、F03・F04 のフックも使えるように `pub(super)` で置く（後述のフックの表の「共通の関数」）。
- スタックの使い方: 深さ 1000 の入れ子（`((((…))))`、`if` の入れ子、ラムダの入れ子、パターンの入れ子）を、テストのスレッドの既定のスタックの大きさで解析できなければならない。最小実行版の `parser/mod.rs` の先頭のコメントの書き方（並びの要素を並びに直接加える、大きなノードの組み立てを別の関数に分ける）を引き継ぐ。スタックの大きさを変えてテストを通すことはしない（[実装の規約](../00-common/00-02-conventions.md)の「再帰の深さ」）。

### 解析の文脈の印

02-03「文脈の制限」の印を、`Parser` の欄 `ctx` に持つ。

| 印 | 値 | 立てる作業 |
|---|---|---|
| `stdlib` | `kind` が `SourceKind::Prelude` か | F02（`parse` の始め） |
| `clause` | `None`（節の外）・`Direct`（`handle` の節の中に直接）・`Blocked`（節の中のラムダか `lazy` の本体の中） | F04 が節の本体と `lazy` の本体で立てる。F02 はラムダの本体に入るときに `Direct` を `Blocked` にする |
| `escape` | `Allowed`・`InLazy`・`InGuard` | F04 が `lazy` の本体とガードで立てる。F02 はラムダの本体に入るときに `Allowed` に戻す |
| `in_arm_head` | `match` の分岐の頭を読んでいるか | F02 |

印は、構文に入るときに保存して立て、出るときに戻す（関数の引数でなく欄で持つのは、F03・F04 のフックが同じ印を読むためである）。

### フックの表

F03 と F04 が受け持つ構文は、次のフックを通して読む。本作業は、各フックを表の「仮の本体」の振る舞いで置き、`parser/mod.rs` の先頭の `//!` にこの表（関数の名前、受け取るもの、返すもの、仮の本体の振る舞い、中身を書く作業）を書く。シグネチャ（`fn` の引数と戻り値の型）は本作業が決めてよいが、表の役割を満たすようにする。F03・F04 は自分のファイルの中身だけを書き、フックのシグネチャと、F02 のファイルを変えない。フックが足りないと分かったら、F03・F04 は作業を止めて報告する。

仮の本体が構文を読めないときは、E0201（`expected` はその構文の呼び名、`found` はその字句）を報告し、その構文の終わり（対応する `end`、閉じ括弧、トップレベルの次の宣言など、02-03「誤りからの回復」の読み飛ばす先）まで読み飛ばして誤りのノードを返す。

| ファイル | フック | 呼ぶ位置 | 役割 | 仮の本体 |
|---|---|---|---|---|
| `items.rs`（F03） | `DocStore`（`new`・`take_for`・`module_doc`・`finish`） | `parse` の始めと終わり、ドキュメントコメントを付けられるノードを作るとき | ドキュメントコメントを宣言に結び付ける。E0228・E0229 | 結び付けず（`None`）、報告しない |
| 〃 | `parse_import` | トップレベルの `import` | import の宣言。E0219（最初の宣言の位置を受け取る）・E0244 | E0201 と読み飛ばし |
| 〃 | `parse_attributes` | トップレベルの宣言の始めの `@`・`#`・`[` | 属性の並び。E0220・E0247・E0801・E0805 など | `@` から属性の終わりまでを E0201 で読み飛ばし、空の並び |
| 〃 | `parse_public` | 属性の後 | `public` を読む | `public` があれば読み、その span を返す |
| 〃 | `body_rule` | 関数の宣言を読む前 | 本体のない関数の宣言か（`@builtin`） | 本体が要る |
| 〃 | `check_decl_header` | トップレベルの宣言を読んだ後 | 属性と `public` と宣言の種類の組の検査。E0221・E0802〜E0804・E0807 | 何もしない |
| 〃 | `report_missing_body` | 本体が要る関数の宣言で、シグネチャの後に本体と `end function` がない（次の字句がトップレベルの宣言の始めかファイルの終わり）とき | E0808 | E0201 |
| 〃 | `reject_public` | `implement` の中の関数の前の `public`（F04 が呼ぶ） | E0221 | 何もしない |
| 〃 | `parse_record_decl`・`parse_alias_decl`・`parse_const_decl` | トップレベルの `record`・`type`（名前と型パラメータの後に `=` があるか、`type` の直後が `alias`）・`const` | それぞれの宣言。E0237・E0248 | E0201 と読み飛ばし |
| 〃 | `try_foreign_decl_start` | トップレベルの宣言の位置で、宣言の始めでない字句に出会ったとき（F02 の診断より先） | `/**`・`{-|`・`(**`・`typealias`・`#[test]`・`[<Test>]` の診断（E0247・E0248・E0249）。扱ったら `Some` に解析の結果（`typealias` は型の別名の `Item`、ほかは誤りのノードの `Item`）を入れて返す。引数は `p` と深さ | `None` |
| `records.rs`（F03） | `parse_record_expr`・`parse_record_pattern` | 式とパターンの `QualUpper (` の次が「小文字の名前 `:`」か `..` のとき（02-03「構文解析の方式」） | レコードの構築・一部を変えた値・レコードのパターン。E0224・E0225・E0204（鍵 `record`） | E0201 と閉じ括弧までの読み飛ばし |
| `traits.rs`（F04） | `parse_trait_decl`・`parse_impl_decl` | トップレベルの `trait`・`implement` | 型クラスと実装の宣言。E0223・E0245 | E0201 と読み飛ばし |
| 〃 | `builtin_constraint` | 型パラメータの制約の位置の小文字の名前 | 組み込みの制約（`equality`・`key`、標準ライブラリのソースの `ordered`）。E0222 | `equality`・`key`・`ordered` をそのまま受け付け、ほかは E0201 |
| `effects.rs`（F04） | `parse_effect_decl` | トップレベルの `effect` | エフェクトの宣言。E0510 | E0201 と読み飛ばし |
| 〃 | `parse_handle`・`parse_resume`・`parse_with`・`parse_lazy`・`parse_try` | 式の始めの `handle`・`resume`・`with`・`lazy`・`try` | それぞれの式。E0509・E0235・E0246 | E0201 と構文の終わりまでの読み飛ばし（`try` は後の式を読んで捨てる） |
| 〃 | `check_escape` | `return` を読んだとき（F02）と `try` を読んだとき（F04） | `lazy` の本体とガードの中の `return`・`try`。E0218 | 何もしない |
| `interp.rs`（F04） | `parse_interp` | 式の始めの `StrStart` | 文字列補間の式 | E0201 と対応する `StrEnd` までの読み飛ばし |
| `spread.rs`（F04） | `parse_spread_elem` | リストリテラルの要素の始めの `..` と `*` | 展開の要素。E0227 | E0201 と要素の終わりまでの読み飛ばし |
| 〃 | `check_list_spreads` | リストリテラルを読んだ後 | 二つ目の展開。E0226 | 何もしない |
| `patterns_ext.rs`（F04） | `parse_arm_head_rest` | `match` の分岐の最初のパターンを読んだ直後 | 選択肢、ガード。E0236・E0241 | 何も読まずに、最初のパターンだけの選択肢とガードなしを返す |
| 〃 | `parse_range_rest` | パターンの整数・文字のリテラルの直後の `..` | 範囲のパターン。E0242 | E0201 と読み飛ばし |
| 〃 | `parse_list_pattern` | パターンの始めの `[` | リストのパターン。E0250 | E0201 と `]` までの読み飛ばし |
| 〃 | `report_tuple` | 丸括弧で囲んだ式・型・パターンの中に括弧の外側のコンマがあったとき（要素の数と span を渡す） | E0217 | E0201（`expected` は `)`） |

F02 が F03・F04 に `pub(super)` で使わせる共通の関数（字句の読み進め、`expect`、名前を読む関数（キーワードの E0216 を含む）、修飾した名前を読む関数、ノード番号、深さの数え上げ、回復、`BadSymbol` の報告（文脈で決めたコードを指定して報告済みにする関数を含む。F03・F04 が E0105・E0212 に代えて E0236・E0237・E0247・E0249・E0235 などを出すときに使う）、分岐の頭の `when` を E0232 として扱う関数（F04 の `handle` の節も使う）、式・パターン・型・ブロック・関数の宣言とシグネチャ・型パラメータの並びを読む関数、`end` の検査、ソースの断片）も、`//!` の表に一覧として書く。

### 宣言（`decls.rs`）

- プログラム: 先頭の NEWLINE、`import` の並び（フック）、宣言の並びを読む（01-02「初回リリース版の文法の全体」の `Program`）。宣言の前に `items::DocStore::take_for` で説明を受け取り、`parse_attributes`・`parse_public` を呼び、宣言の語で振り分ける。
- 関数の宣言: `function` 名前 [型パラメータ] `(` 引数 `)` `->` 型 [`uses` の並び] 本体 `end function`。本体は `body_rule` が本体なしを返したときだけ読まない（シグネチャの後の NEWLINE で宣言を終え、`FnDecl::body` を `None` にする。02-03「標準ライブラリのソースの構文」）。
- シグネチャを読む関数（名前、型パラメータ、引数、`->`、戻り値の型、`uses`）を F04（メソッドと操作の宣言）と共有する。
- `data` の宣言: `data` 名前 [型パラメータ（大文字の名前の並び）] 構成子の並び `end data`。構成子の前で説明を受け取る。宣言の中の空の括弧（`Leaf()`）は E0206（`name`、鍵 `remove` の置き換え）。
- 振り分け: `record`・`const` と、`=` のある `type`・`type alias` は F03、`trait`・`implement` と `effect` は F04 のフック。名前と型パラメータの後に `=` のない `type` は E0233（後述）。
- 関数の名前を修飾して宣言した形（`function List.map(`）は E0207（`module` に修飾の部分、鍵 `remove` の置き換え）。

### 型（`types.rs`）

- 02-03「型の解析」のとおりである。括弧の型、関数の型と `uses`（最も内側の関数の型に付き、並びを最長に読む）、2 番目以降の要素の直後の `[` の E0209 は、最小実行版の規則を初回リリース版の字句（`function` の型、修飾した `QualUpper`）で写す。
- 型パラメータの並びを読む関数は、宣言の種類で書けるものを変える。関数・実装・メソッド・操作の並び（`FnTypeParams`）は `effect E`、`F[_]`（`_` の数を `TypeParamKind::Ctor { arity }` に入れる）、`:` の後の `&` でつないだ制約（大文字の修飾した名前は `ConstraintRef::Class`、小文字の名前は `traits::builtin_constraint`）を読む。型・レコード・型の別名の並び（`TypeParams`）は大文字の名前だけを読む。末尾のコンマを許す。

### 式・ブロック・文（`exprs.rs`）

- 演算子は 02-03「構文解析の方式」の表の強さで Pratt 法で読む。比較演算子は結合しない。比較の右のオペランドの直後にまた比較演算子があれば E0202 とし、鍵 `and` の置き換え（二つ目の演算子の前に ` and ` と真ん中のオペランドの断片を挿入する）を付ける。回復では二つ目の比較を読み捨て、一つ目の比較のノードを返す。
- `return` は式の始めで調べ、右の式全体（パイプを含む）を読む。読む前に `effects::check_escape` を呼ぶ。`try` は `effects::parse_try` に渡す。
- 式の始め（Primary）: リテラル（`Decimal` を含む）、名前（`{ UpperIdent "." } (LowerIdent | UpperIdent)`）、`()`、括弧の式、リストリテラル、`if`、`match`、ラムダは本作業で読む。`StrStart`・`lazy`・`with`・`handle`・`resume` はフックに渡す。修飾した大文字の名前の直後の `(` の次が「小文字の名前 `:`」か `..` なら `records::parse_record_expr` に渡す。
- 括弧の式の中に括弧の外側のコンマがあれば、要素を読んでから `patterns_ext::report_tuple` を呼ぶ（型とパターンも同じ）。
- 呼び出しの引数: 直接の引数の `_` は `Arg::Placeholder`。それ以外の位置の `_` は E0204。
- 値に続けたドット（小文字の名前・呼び出し・リテラル・括弧の式・リストの後の `.`）は E0203。鍵 `pipe` の修正案を示し、ドットの右が小文字の名前なら鍵 `field` の修正案も示す。`.` と名前と、続く呼び出しの引数を読み飛ばす。
- リストリテラル: 要素の始めが `..` か `*` なら `spread::parse_spread_elem` に渡し、読み終えた後に `spread::check_list_spreads` を呼ぶ。
- `if`: `if` 条件 `then` 本体 { `else if` … } [`else` 本体] `end if`。`else` の直後の `if` は続きの分岐として読み、`ElseBranch::If` にする。
- `match`: 対象の式を Pratt 法で読み、次が `with` でなければ構文エラーとする。対象の後に NEWLINE があり次の行の頭が `with` なら E0215（鍵 `same_line` の置き換えは、対象の終わりから `with` の前までを空白一つにする）とし、`with` を読んで続ける。分岐は `case` で始め、最初のパターンを読んでから `patterns_ext::parse_arm_head_rest` を呼び、`->` を読んで本体を読む。本体は、NEWLINE の次の字句が `case` か `end` なら終える（02-03「構文解析の方式」）。分岐の頭を読む間は `in_arm_head` を立てる。
- ラムダ: `lambda` `(` 引数（`_` は E0210。鍵 `name` の置き換えは `_unused`） `)` [`->` 型 [`uses`]] 本体 `end lambda`。本体に入るときに文脈の印を改める（前述）。
- ブロック: 文を改行で区切って読む。読む関数は、終わりの字句の種類（`end`、`else`、`case`、`handle` の本体を終える「`with` の次が `case`」）を引数で受け取り、F04 と共有する。
- 束縛の文: `bind`・`shadow` の後にパターン、[`:` 型]、`<-`、式。`BindStmt::mode` と `keyword_span` を入れる。
- `end` の検査: `end` の直後の語が開いているブロックの構文と一致しなければ E0213（`found`・`expected`、補助の位置 `opened`、鍵 `replace` の置き換え）とし、そのブロックを閉じたものとする。ただし、直後の語が外側の開いているブロックの構文と一致するときは、内側の閉じていないブロックについて E0214（`construct`、補助の位置 `opened`）を一つ報告し、外側まで閉じる。ファイルの終わりで閉じていないブロックも E0214 である。

### パターン（`patterns.rs`）

- ワイルドカード、変数、リテラル（前置の `-` は整数リテラルだけに付けられる。`LitPat::negative`）、文字列と文字のリテラル、`true`・`false`、`()`、構成子（修飾した名前、括弧を書いたか、引数）を読む。浮動小数と `Decimal` のリテラルは E0201 とする。
- 整数・文字のリテラルの直後の `..` は `patterns_ext::parse_range_rest`、`[` は `patterns_ext::parse_list_pattern`、構成子の名前の直後の `(` の次が「小文字の名前 `:`」か `..` なら `records::parse_record_pattern` に渡す。
- パターンの節は、02-03「入れ子の深さ」の通し番号で深さを数える（ADR 0086）。

### 字句に使えない記号（`foreign.rs`）

`BadSymbol` の字句は、どの位置で読んでも一度だけ報告する。まず文脈で決まる診断を調べ、当たらなければ文脈によらない診断を出す。

| 記号 | 文脈 | 診断と回復 |
|---|---|---|
| `==`・`!=`・`&&`・`||`・`%` | 二項演算子を読む位置 | E0211（鍵 `equal`・`not_equal`・`and`・`or`・`remainder` の置き換えで `=`・`<>`・`and`・`or`・`mod` にする）。その演算子として読み続ける |
| `!` | 前置の演算子を読む位置 | E0211（鍵 `not`、`not ` への置き換え）。`not` として読み続ける |
| `=>` | `match` の分岐の頭の `->` の位置 | E0211（鍵 `fat_arrow`）。`->` として読み続ける |
| `?` | 値の直後 | E0211（鍵 `question`。置き換えなし）。読み飛ばす |
| `;` | どこでも | E0106。鍵 `newline` の置き換えは、`;` の後が行の終わりなら `;` の削除、そうでなければ `;` を改行に置き換えるもの。文の区切りとして扱う |
| `{`・`}` | どこでも | E0212。`{` は鍵 `open`、`}` は鍵 `end`（`construct` に最も内側の開いているブロックの構文の名前）の修正案を示す。`{` は読み飛ばす。`}` は、いま読んでいるブロックの終わりとして扱い、その構文の `end …` を期待する位置では `end …` の代わりとして受け付ける（`} else {` では `else` の分岐へ続ける）。最小実行版の関数・`if`・`match` の波括弧の書き方で、派生の診断を出さない |
| `|` | `match` の分岐の頭、型の別名の右辺 | F04（E0236）、F03（E0237）のフックが扱う |
| `#` | トップレベルの宣言の位置の `#[` | F03 のフック（E0247）が扱う |
| そのほか（`#`・単独の `|`・`~`・`^`・`` ` ``・`$`、文脈に合わない上の記号） | — | E0105（`symbol`）。上の表の記号が文脈に合わないとき（`a ; b` でない位置の `{` など、E0106・E0211・E0212 の文脈がないとき）は、01-01「演算子と区切り記号」の記号ごとの修正案のコード（E0106・E0211・E0212）を、置き換えなしで出す |

### 他の言語と最小実行版の書き方（`foreign.rs`）

02-03「他の言語の書き方への診断」の表のうち、本作業が受け持つ行を次の位置で見つける。修正案の型板の値は後述の「型板に埋めるソースの断片」で作る。

| 書き方 | 見つける位置 | コード | 回復 |
|---|---|---|---|
| `let x = e` | 文の先頭の名前 `let` の後にパターンと `=` | E0230（`name`・`value`、鍵 `bind` と `shadow` の修正案） | `bind x <- e` として読む |
| `case 対象 of` | 分岐の並びの外の、式の位置の `case` と、式の後の名前 `of` | E0231（`value`、鍵 `match_with`） | 同じブロックの中の `end case` か、なければ文の終わりまで読み飛ばす |
| `when p:`・`when 操作(引数):` | `match` と `handle` の分岐を読む位置の名前 `when` | E0232（`pattern`、鍵 `case`） | `:` を `->` として分岐を読む。`handle` の節を読む F04 も、この判定の関数を呼ぶ |
| 構成子を並べた `type` | `type` の名前と型パラメータの後に `=` がない | E0233（`name`、鍵 `data` の置き換えは `type` を `data` に、対応する `end type` があればそれを `end data` にする） | `data` の宣言として読み、`end type` を受け付ける |
| `function f(x: Integer): Integer`、`lambda(x): T` | 関数・ラムダ（F04 のメソッドと操作はシグネチャを読む関数を通して同じ）の引数の並びの `)` の直後の `:` | E0234（鍵 `arrow` の置き換え） | `->` として読む |
| `パターン -> 式`、`パターン => 式` | `match` の分岐を読む位置の `case` のないパターン | E0238（`pattern`、鍵 `case`） | 分岐として読む |
| `switch e`、`default:` | 文の先頭の名前 `switch` の直後に式、分岐を読む位置の名前 `default` と `:` | E0239（`word`、鍵 `switch`・`default`） | `switch` は文の終わりまで（波括弧を含む）読み飛ばす。`default:` は `case _ ->` として読む |
| `break` | 分岐の本体の、名前 `break` だけの文 | E0240（鍵 `remove`） | 文を捨てる |
| `lambda x: e` | `lambda` の直後の小文字の名前 | E0243（`params`・`body`、鍵 `lambda`） | 名前の並びと `:` の後の式を読み、その式を返すラムダとする |
| 名前の位置のキーワード | 名前を読む関数が `Kw*` の字句に出会ったとき | E0216（`word`、鍵 `rename`） | その語を名前として読み続ける |
| 最小実行版の `fn` | 宣言と式の始めの名前 `fn` の後に名前か `(` | E0201（`expected` に `function` の宣言か `lambda`） | 本プランの決定: 専用のコードがないので E0201 で示す。宣言の位置では次の宣言まで、式の位置では対応する `}` まで読み飛ばす |

### 型板に埋めるソースの断片（`snippet.rs`）

`parse` は `text` でソースのバイト列を受け取る（10-03）。E0202 の置き換えや E0230・E0231・E0243 の `{value}` など、ソースの一部を型板に埋める診断は、span の範囲のソースの写しで作る。`snippet` は、span とソースのバイト列から、その範囲の文字列を返す（字句の span は文字の境界にあるので、範囲の切り出しは `get` で行い、`None` や UTF-8 として読めない場合は `String::from_utf8_lossy` の結果を使う。panic しない）。F03・F04 も同じ関数を使う。

### 字句と構文の呼び名（`text.rs`）

E0201 の `{expected}` と `{found}` に埋める呼び名を、`TokenKind` のすべての字句と、01-02「初回リリース版の文法の全体」のすべての構文（F03・F04 が読む構文を含む。`import` の宣言、属性、レコードのフィールド、型クラスのメソッド、エフェクトの操作、`handle` の節など）について、ここにまとめる。F03・F04 はこのファイルを変えないので、足りない呼び名があれば作業を止めて報告する。

### テストの補助（`test_support.rs`）

`#[cfg(test)] pub(crate)` で、ソースの文字列を `lex`（`FileId(0)`）・`resolve_newlines`・`parse`（新しい `IdGen`。`text` には `lex` に渡したのと同じバイト列）に通して、構文解析の結果と字句の診断を返す関数、診断のコードの並びを返す関数、ソースの中の文字列の位置を返す関数を置く。`SourceKind` を引数で選べるようにする。F03・F04 のテストもこれを使う。

## 受け入れテスト

診断はコードと主な位置で確かめ、置き換えを持つものは置き換えの範囲と文字列も確かめる。AST は形（ノードの種類と主な欄）で確かめ、ノード番号の値そのものは比べない。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 01-02 の例 | 「例」の `Shape`・`area`・`totalArea`・`main`（`uses IO` のまま。構文としては読める） | 構文エラーなし。`match` の分岐が二つ、パイプが二段 |
| 本章の各節の例 | 01-02 の「プログラムと宣言」〜「部分適用のプレースホルダ」の例と、01-01「改行による区切り」の例 | 構文エラーなし |
| 演算子の優先順位 | `a or b and c = d + e * f`、`not a and b`、`-x * y`、`x |> f |> g`、`a div b mod c` | 02-03 の表の結合で木ができる |
| 比較を連ねる | `a < b < c` | E0202 一つ。置き換えを当てると `a < b and b < c` になる |
| `return` と `try` の範囲 | `return x |> f` | `return` の値がパイプの式 |
| `else if` | `if a then 1 else if b then 2 else 3 end if` | 外側の `IfExpr` の `else_branch` が `ElseBranch::If`、`end if` は一つ |
| 束縛の文 | `bind x: Integer <- 1`、`shadow x <- 2`、`bind _ <- f()`、`bind Pair(a, b) <- p` | `BindStmt` の `mode`・`keyword_span`・`pattern`・`ty` |
| プレースホルダ | `f(_, 1)`、`_ + 1`、`f(g(_))` | 1 と 3 は `Arg::Placeholder`。2 は E0204 |
| ドット | `xs.map(f)`、`p.name`、`List.map`、`Shape.Circle(1.0)`、`A.B.c` | 1 は E0203（鍵 `pipe`）、2 は E0203（`pipe` と `field`）。残りは名前 |
| 型と `uses` | `function(function() -> Unit uses Console.Write, E) -> Unit`、`function() -> function() -> Integer uses Console.Write`、`function(function() -> Unit uses A, List[Integer]) -> Unit` | `uses` は最も内側に付き、並びを最長に読む。3 は E0209 |
| 型パラメータ | `function f[T: Show & equality, F[_], effect E](x: T) -> Unit` | 制約が `Class` と `Builtin(Equality)`、`F` が `Ctor { arity: 1 }`、`E` が `Effect` |
| `data` | `data Tree[T]\n Leaf\n Node(Tree[T], T, Tree[T])\nend data`、構成子 `Leaf()` | 構成子が二つ。`Leaf()` は E0206（置き換えで `()` を消す） |
| ブロックの閉じ方 | `if c then 1 end match`、閉じない `lambda` がファイルの終わりまで、外側の `end function` に達した `if` | E0213（補助の位置が `if`）、E0214、E0214 が一つだけ |
| 最小実行版の書き方 | `fn f(x: Int) -> Int { x + 1 }`、`let x = 1`、`if x == 1 && y != 2 { … } else { … }`、`match x { Some(v) => v, None => 0 }`、`a; b`、`!ok`、`n % 2` | それぞれ本文の表のコード。一つの記号に一つの診断で、派生した E0201・E0213・E0214 を出さない |
| 他の言語の書き方 | `case x of`、`when Some(v):`、`type Shape\n Circle(Float)\nend type`、`function f(): Integer`、`lambda(x): Integer …`、`Some(v) -> v` の分岐、`switch x`、`default:`、分岐の中の `break`、`lambda x: x + 1`、`x?`、`p => e` | E0231・E0232・E0233（置き換えで `data` と `end data`）・E0234（置き換え）・E0234・E0238・E0239・E0239・E0240・E0243・E0211（`question`）・E0211（`fat_arrow`） |
| `match` の後の改行 | `match x\nwith\n case _ -> 1\nend match` | E0215 一つ。置き換えを当てると `match x with` になる |
| キーワードを名前に | `bind match <- 1`、`function with() -> Unit`、引数 `data: Integer` | E0216（`word`）が一つずつ。派生の誤りなし |
| 標準ライブラリのソース | `SourceKind::Prelude` で、本体のない関数の宣言 | 本作業の時点では `body_rule` の仮の本体が本体を要求するので構文エラーになる（F03 の後に通る）。本作業は `body_rule` が本体なしを返したときに `body` が `None` になることを、仮の本体を通さない単体テストで確かめる |
| フックの仮の本体 | `record R\n x: Integer\nend record` の後に関数の宣言、式の中の `"a${x}"`・`lazy 1 end lazy`・`[..xs]`、`case 1, 2 ->` | どれも E0201 一つで回復し、後の関数の宣言は正しく読める |
| 深さの上限 | 深さ 999 と 1001 の括弧の入れ子、1001 段の `if` の入れ子、1001 個の文を持つブロック、要素 1001 個のリスト、節の数の多い `match` のパターン | 上限の内は通り、外は E0208 一つで打ち切る。どれも既定のスタックの大きさのテストのスレッドで終わる |
| 回復 | 一つの関数に独立した構文の誤りを三つ、誤りの後の宣言 | 三つの診断。後の宣言が AST にある |
| `Error` の字句 | 閉じていない文字列を含む式 | 字句の誤りだけで、構文エラーを重ねない |
| ノード | 上の構文エラーのない入力 | すべてのノードの span が最初の字句から最後の字句までを覆い、ノード番号が重ならない |

ゴールデンテスト: 誤りのない次の例を、`testdata-next/syntax/` に `f02_<名前>.bnt`・`.mode`（`check`）・`.exit`（`0`）の組で置く（07-03「ゴールデンテスト」の形式。先頭に `// spec: 01-02 …` の行を書く）。初回リリース版の検査を誤りなく通る完全なプログラムにする（`main` は `function main() -> Unit` とし、IO を使わない）。F18 と C10 が揃うまで実行されず、C05 が確かめる。C03 のテスト（`tests/next_syntax.rs`）が取り込まれていれば、構文の誤りがないことをそれで確かめる。

- キーワードのブロック（`function`・`if … then … else if … end if`・`lambda`・`match … with case`）
- `data` と構成子のパターン
- 演算子（`=`・`<>`・`and`・`or`・`not`・`div`・`mod`）と改行の継続
- パイプとプレースホルダ
- `bind` と `shadow`

## 完了条件

- `scripts/check.sh` が通る（[実装の規約](../00-common/00-02-conventions.md)の「完了条件の共通の検査」）。
- 受け入れテストのすべての場合を確かめるテストがある。
- `parser/mod.rs` の先頭の `//!` に、フックの表と共通の関数の一覧がある。
- 診断の文言を処理の中に直接書いていない（`DiagBuilder`、10-02 の鍵、`text.rs` の呼び名だけを使う）。
- 完了の報告の「判断したこと」に、`codes.rs` で直した型板と、フックのシグネチャを挙げる。

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「字句と構文（F01〜F04）」の行に加えて、次を読む。

- フックの表のすべてのフックが置かれ、仮の本体が表の振る舞い（E0201 と回復）をしているか。F03・F04 が、F02 のファイルを変えずに中身を書けるだけの引数を渡しているか。
- `BadSymbol` を、回復で読み飛ばす場合も含めて、ちょうど一度報告しているか。
- 最小実行版の波括弧の書き方（C03 が書き直す前のテストの形）に対して、記号一つにつき一つの診断に収まっているか。
- 深さの数え方が 02-03「入れ子の深さ」の各項目（文と並びの要素の `i + 1`、パターンの節の通し番号）と一致しているか。
- 01-02「初回リリース版の文法の全体」のうち、本作業が受け持つ規則がすべて読めるか（C03 が最小実行版の機能を新しい構文で書くのに足りるか）。

## 難易度の理由

構文の全体を書き直す作業であり、基盤と規則ごとの関数の数が多い。難しいのは、誤りからの回復と報告の抑制を、他の言語の書き方への多数の診断と組み合わせて、一つの誤りに一つの診断を保つことと、F03・F04 が並行して中身を書けるフックの境目を、先に正しく置くことである。
