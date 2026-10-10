# F03 構文解析 2: import・`public`・レコード・型の別名・定数・属性・ドキュメントコメント

- 依存する作業: [F02](F02-parser-core.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行）
- ブランチ: impl/F03-parser-modules-records

## 目的

F02 が置いたフックのうち、`parser/items.rs` と `parser/records.rs` の中身を書き、モジュールと import の宣言、`public`、レコードの宣言・構築・一部を変えた値・パターン、型の別名、定数の宣言、属性、ドキュメントコメントを読めるようにする。あわせて、これらの構文の文脈の制限（import の順序、属性、`public`、レコードのフィールドの数、ドキュメントコメントの位置）と、他の言語の書き方への診断を出す（02-03「文脈の制限」「他の言語の書き方への診断」）。F04 と並行して進める。

本作業の後、標準ライブラリのソース（10-14）のうち、F04 の構文（型クラス、実装、エフェクトの宣言など）を含まない部分が読めるようになる。モジュールの読み込み（F05）と、最小実行版のテストの書き直し（C03。import の宣言を使う）は本作業を待つ。

## 読む設計書の節

- [構文](../../2026-10-09-design-first-release/01-spec/01-02-syntax.md): 「モジュールと import（初回リリース版）」「レコード（初回リリース版）」「属性（初回リリース版）」「定数（初回リリース版）」「型の別名（初回リリース版）」「ドキュメントコメント（初回リリース版）」「初回リリース版の文法の全体」
- [字句解析器と構文解析器](../../2026-10-09-design-first-release/02-impl/02-03-frontend.md): 「コメントとドキュメントコメント」「構文解析の方式」（`QualUpper` の直後の `(` の読み分け、`type` の読み分け）「文脈の制限」「他の言語の書き方への診断」「標準ライブラリのソースの構文」
- [字句構造](../../2026-10-09-design-first-release/01-spec/01-01-lexical.md): 「コメント」「シェバンの行（初回リリース版）」
- [代数的データ型とパターンマッチ](../../2026-10-09-design-first-release/01-spec/01-05-data-types.md): 「レコード（初回リリース版）」
- ADR: [0053](../../2026-10-09-design-first-release/decisions/0053-private-by-default-with-pub.md)、[0057](../../2026-10-09-design-first-release/decisions/0057-record-declaration-construction-update.md)、[0119](../../2026-10-09-design-first-release/decisions/0119-attributes-test-and-deprecated.md)、[0123](../../2026-10-09-design-first-release/decisions/0123-top-level-constants.md)、[0124](../../2026-10-09-design-first-release/decisions/0124-type-aliases.md)、[0125](../../2026-10-09-design-first-release/decisions/0125-doc-comments.md)、[0126](../../2026-10-09-design-first-release/decisions/0126-import-by-module-name.md)、[0157](../../2026-10-09-design-first-release/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)
- インターフェース: [字句と構文木](../10-interfaces/10-03-syntax.md)の「AST」（`Module`・`ImportDecl`・`TopDecl`・`Attribute`・`RecordDecl`・`FieldDecl`・`AliasDecl`・`ConstDecl`・`RecordExpr`・`FieldArg`・`RecordPat`・`FieldPat`・`DocComment`）、[診断](../10-interfaces/10-02-diagnostics.md)の「E02 構文」「E08 属性」の表で出す作業が F03 のコード
- F02 の作業の文書と、F02 が `src/syntax/parser/mod.rs` の先頭の `//!` に書いたフックの表と共通の関数の一覧

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `src/syntax/parser/items.rs`: F02 が置いたフック（`DocStore`・`parse_import`・`parse_attributes`・`parse_public`・`body_rule`・`check_decl_header`・`report_missing_body`・`reject_public`・`parse_record_decl`・`parse_alias_decl`・`parse_const_decl`・`try_foreign_decl_start`）の中身。
- `src/syntax/parser/records.rs`: `parse_record_expr`・`parse_record_pattern` の中身。
- 両ファイルの中の非公開の補助の関数と `#[cfg(test)] mod tests` のテスト（F02 の `parser::test_support` を使う）。
- `src/diag/codes.rs` の、本作業が出すコード（E0204 の鍵 `record`、E0219〜E0221、E0224・E0225、E0228・E0229、E0237、E0244、E0247〜E0249、E0801〜E0805、E0807・E0808）の型板の直し（10-02「型板の直し方」の範囲）。
- `testdata-next/syntax/` のゴールデンテスト（後述）。

F02 のファイル（`parser/mod.rs`・`decls.rs`・`exprs.rs`・`patterns.rs`・`types.rs`・`foreign.rs`・`text.rs`・`snippet.rs`・`test_support.rs`）と F04 のファイル（`traits.rs`・`effects.rs`・`interp.rs`・`spread.rs`・`patterns_ext.rs`）は変えない。フックのシグネチャを変える必要や、F02 の共通の関数と `text.rs` の呼び名が足りないことが分かったら、作業を止めて報告する（[作業の進め方](../00-common/00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。

## 手順の要点

### import の宣言（`parse_import`）

- `import` UpperIdent { `.` UpperIdent } [`as` UpperIdent] を読み、`ImportDecl` を作る。`as` は小文字の識別子 `as` として読む（キーワードでない。02-03「字句」）。
- ほかのトップレベルの宣言を読んだ後の import の宣言は E0219 とし、補助の位置（鍵 `first`）に最初の宣言を示す（F02 が最初の宣言の span を渡す）。宣言としては読み、AST の `imports` に加える。
- パスの文字列や `from` で取り込む形（`import "./text.bnt"`、`import Text from "./lib/text.bnt"`）は E0244 とし、行の終わりまで読み飛ばす。本プランの決定: `{module}` には、文字列のパスから先頭の `./` と拡張子 `.bnt` を除き、`/` で区切った各段の先頭の文字を大文字にして `.` でつないだ名前（`./lib/text.bnt` なら `Lib.Text`）を入れる。文字列がないときは `from` の前の名前を入れる。

### `public` と宣言の頭の検査（`parse_public`・`check_decl_header`・`reject_public`）

- `public` を読み、span を返す。`implement` の前の `public` は E0221（`what` は `parser` の `text` の宣言の呼び名。鍵 `remove` の置き換えで `public ` を消し、鍵 `implement` の注記を添える）。`implement` の中の関数の前の `public` は、F04 が `reject_public` を呼び、同じく E0221 にする。
- 属性の組の検査は後述の「属性」で行う。

### 属性（`parse_attributes`・`body_rule`・`check_decl_header`）

- `@` 名前 [`(` 文字列リテラルのコンマの並び `)`] を、宣言の前に一つ以上読む。属性の後の NEWLINE は読み飛ばす（`AttrDecl`）。
- 引数が文字列リテラル（`StringLit`）でないか、補間を含む（`StrStart`）ときは E0220（鍵 `plain`）とし、その引数を読み飛ばす。
- 名前が大文字で始まるもの（`@Test`）は E0247（鍵 `test` の置き換えは名前を小文字にしたもの。`Test` 以外は鍵 `other` の注記）。`@doc` は E0249。ほかの知らない名前は E0801（`name`、鍵 `allowed`）。`builtin` は、`SourceKind::Prelude` では受け付け、利用者のソースでは E0807（鍵 `remove`）とする。
- 本プランの決定（誤りの報告の順と回復）: 属性ごとに、名前の誤り（E0247・E0249・E0801・E0807）を先に調べ、名前が正しい属性についてだけ引数の数と内容を調べる。`@test` の引数が二つ以上なら E0805、`@deprecated` の引数が一つでないか、空の文字列なら E0804（鍵 `message`）、`@builtin` の引数が文字列一つでなければ E0201 とする。一つの宣言に同じ名前の属性が二度あれば、二つ目を E0803（補助の位置 `first`、鍵 `remove` の置き換え）とする。
- 付けられる宣言（`check_decl_header`）: `@test` と `@builtin` は関数、`@deprecated` は関数・定数・`data`・型の別名・レコード・型クラス・エフェクト（01-02「属性（初回リリース版）」の表）。ほかの宣言に付けたら E0802（`name`、`what` は `text` の宣言の呼び名）。
- `body_rule`: `@builtin` を付けた関数の宣言は本体のない宣言として読む。利用者のソースの `@builtin` も、E0807 を報告したうえで本体のない形で読む（02-03「標準ライブラリのソースの構文」）。
- `report_missing_body`: 本体の要る関数の宣言に本体と `end function` がないとき、E0808（`name`、鍵 `body`）を報告し、本体のない宣言として受け付ける。

### 型の別名と定数（`parse_alias_decl`・`parse_const_decl`）

- 型の別名: `type` UpperIdent [型パラメータ] `=` 型（`AliasDecl`）。型パラメータは F02 の `TypeParams` の並びを読む関数で読む。
- 右辺の型の後の `|`（`BadSymbol`）は E0237（鍵 `data`）とし、行の終わりまで読み飛ばす。この `|` の報告は E0105 に代えて行う（F02 の共通の関数に、コードを指定して `BadSymbol` を報告済みにする関数がある）。
- `type alias X = T` は E0248（`name` は `X`）とし、`alias` を読み飛ばして型の別名として読む。トップレベルの `typealias X = T` は `try_foreign_decl_start` で E0248 とし、同じく読む。
- 定数: `const` LowerIdent `:` 型 `=` 式（`ConstDecl`）。型の注釈のない `const x = 1` は E0201 とする。右辺が定数式であるかは名前解決と型検査が判定する（02-03「文脈の制限」の最後の段落）。

### レコード（`parse_record_decl`・`records.rs`）

- 宣言: `record` UpperIdent [型パラメータ] フィールドの並び `end record`。フィールドは `name: Type` で、一行に一つ。フィールドの前で説明を受け取る（`DocStore::take_for`）。`end` の検査は F02 の共通の関数で行う。
- 構築と一部を変えた値（`parse_record_expr`）: F02 が、修飾した大文字の名前の直後の `(` の次が「小文字の名前 `:`」か `..` のときに呼ぶ。`[`..` 式 `,`] フィールドの引数の並び [`,`]` を読む。`..` の式の後にフィールドがない形（`Person(..p)`）は E0224（`value` は式の断片、鍵 `use_value` の置き換えはレコードの式全体を式の断片にする）とする。フィールドの値が `_` だけのときは E0204（鍵 `record`）とする。
- パターン（`parse_record_pattern`）: `name: pattern` の並び、最後に [`,` `..`]。フィールドがない形（`Person(..)`）は E0225（鍵 `wildcard` の置き換えはパターン全体を `_` にする）とする。`..` が最後でないときは E0201。
- フィールドの引数とフィールドのパターンは、F02 の深さの数え上げで並びの要素（`i + 1`）として数える。フィールドの名前の重なりと、宣言にないフィールドは型検査（F07）が判定する。

### ドキュメントコメント（`DocStore`）

- `DocStore::new` は `parse` の始めに、コメントの一覧（すべての種類。結果の `comments` には元のまま残す）を受け取る。
- `module_doc`: ファイルの先頭（シェバンの行があればその直後）から続く `//!` の行を一つの説明にする。`Module::doc` に入れる。
- `take_for`: `///` を付けられる宣言（トップレベルの宣言、構成子、フィールド、メソッド、操作、実装の中の関数）を読み始めるときに、F02・F04 がその宣言の最初の字句（属性があれば最初の `@`）の位置を渡して呼ぶ。その直前の行から上に続く `///` の行を集めて一つの説明（`DocComment`。`text` は各行の本文を改行でつないだもの、span は最初の行の先頭から最後の行の終わりまで）にする。空の行か普通のコメントの行があれば、そこで集めるのをやめる。結び付けたコメントを使用済みにする。
- `finish`: `parse` の終わりに、使用済みでない `///` を E0228（鍵 `plain` の置き換えは `///` を `//` にする）、ファイルの先頭の外の `//!` を E0229（同じく `//!` を `//` にする）として報告する。ファイルが `//!` の説明だけからなるときは、誤りとせず、宣言のない空のモジュールとする。
- 他の言語の書き方（`try_foreign_decl_start`）: トップレベルの宣言の位置の `/` `*` `*`（`/**`）、`{`（`BadSymbol`）・`-`・`|`（`{-|`）、`(` `*` `*`（`(**`）は E0249（鍵 `doc`）とし、対応する閉じ（`*/`・`-}`・`*)`）か次の宣言まで読み飛ばす。`#` `[`（`#[test]`）と `[` `<`（`[<Test>]`）は E0247 とし、`]` まで読み飛ばす。これらの記号の `BadSymbol` は、E0105・E0212 に代えてこの診断で報告済みにする。

宣言と説明の間、説明の行どうしの間の「空の行」は、`parse` の `text`（10-03）で判定する。隣り合う二つの `///` の行の間、最後の `///` の行と宣言の最初の字句の間のソースの改行の数を数え、二つ以上なら空の行がある（間に普通のコメントの字句があれば、空の行がなくてもそこで集めるのをやめる）。

## 受け入れテスト

F02 の `parser::test_support` でソースを字句解析・改行の判定・構文解析に通し、AST の形と診断のコード・主な位置（置き換えがあれば範囲と文字列）で確かめる。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| import | `import Lib.Text`、`import Benitoite.IO.Console as C` | `ImportDecl` の `path` が二段・三段、`alias` が `C` |
| import の順序 | 関数の宣言の後の `import Lib.A` | E0219（補助の位置が関数の宣言）。`imports` に入る |
| パスの import | `import "./lib/text.bnt"`、`import Text from "./text.bnt"` | E0244 が一つずつ。`{module}` が `Lib.Text`・`Text` |
| `public` | `public function f() -> Unit …`、`public implement Show[T] …`（F04 の前は実装の本体の読み方に関係なく頭だけを確かめる） | `TopDecl::public` が `Some`。後者は E0221（置き換えで `public ` を消す） |
| 属性 | `@test\nfunction t() -> Unit …`、`@test("adds") function t() …`、`@deprecated("use g") function f() …` | `attrs` の名前と引数 |
| 属性の誤り | `@Test`、`@doc`、`@inline`、`@test("a", "b")`、`@deprecated`、`@deprecated("")`、`@deprecated("a", "b")`、`@test @test`、`@test` を付けた `data`、`@deprecated("x")` を付けた `implement`、`@deprecated(x)`、`@deprecated("a${x}")` | E0247（置き換え `test`）、E0249、E0801、E0805、E0804、E0804、E0804、E0803、E0802、E0802、E0220、E0220 |
| `@builtin` | `SourceKind::Prelude` の `@builtin("Integer.add")\nfunction add(a: Integer, b: Integer) -> Integer` の後に別の宣言、利用者のソースの同じもの | 前者は `body` が `None` で誤りなし。後者は E0807 だけで、本体のない宣言として読む |
| 本体のない関数 | 利用者のソースの `function f() -> Unit` の直後に `function g() -> Unit … end function` | E0808 一つ。`g` は読める |
| 型の別名 | `type UserId = Integer`、`type Validator[T] = function(T) -> Result[T, String]` | `AliasDecl` |
| 別名の誤り | `type T = A | B`、`type alias X = Integer`、`typealias X = Integer` | E0237、E0248、E0248。いずれも後の宣言は読める |
| 定数 | 01-02「定数（初回リリース版）」の五つの例、`const x = 1` | 前者は `ConstDecl`。後者は E0201 |
| レコード | 01-02「レコード（初回リリース版）」の例 | `RecordDecl` のフィールド二つ、`RecordExpr` の `base` と `fields`、`RecordPat` の `rest` |
| レコードの誤り | `Person(..p)`、`case Person(..) ->`、`Person(name: _)`、`Person(.., name: n)` | E0224（置き換えで `p`）、E0225（置き換えで `_`）、E0204（鍵 `record`）、E0201 |
| 構成子との読み分け | `Shape.Circle(1.0)`、`Pair(a, b)`、`Geo.Point(x: 1, y: 2)` | 前の二つは呼び出し（パターンでは構成子のパターン）、三つ目はレコードの構築 |
| ドキュメントコメント | 01-02「ドキュメントコメント（初回リリース版）」の例、属性を付けた宣言の前の `///`、構成子・フィールドの `///` | `Module::doc`、`TopDecl::doc`、`FieldDecl::doc` に本文。属性の前の説明も結び付く |
| ドキュメントコメントの誤り | 関数の本体の中の `///`、ファイルの最後の `///`、説明と宣言の間の空の行、import の後の `//!`、`/** doc */`、`#[test]`、`[<Test>]` | E0228、E0228、E0228、E0229、E0249、E0247、E0247 |
| `//!` だけのファイル | `//! Only docs.` | 誤りなし、宣言のないモジュール |
| 標準ライブラリのソース | 10-14 のソースのうち、F04 の構文を含まないモジュール（`Benitoite.Integer`・`Option`・`List` など）を `SourceKind::Prelude` で読む | 構文の誤りなし |

ゴールデンテスト: 誤りのない次の例を、`testdata-next/syntax/` に `f03_<名前>.bnt`・`.mode`（`check`）・`.exit`（`0`）の組で置く（先頭に `// spec: 01-02 …` の行）。初回リリース版の検査を誤りなく通る完全なプログラムにする。F18 と C10 が揃うまで実行されず、C05 が確かめる。

- 01-02「レコード（初回リリース版）」の `Person` の例（`main` を加える）
- 定数と型の別名（`Map.fromList` を使う例を含む）
- `import Benitoite.Unofficial.IO.Console` と `uses Console.Write` を使う `main`（`Benitoite.IO.Console` は非公式のモジュールなので取り込みの名前で書く。[ADR 0286](../../2026-10-09-design-first-release/decisions/0286-unofficial-modules-imported-under-unofficial.md)）
- ドキュメントコメントと `@test`・`@deprecated` の属性（`@deprecated` の宣言は参照しない。参照すると警告 W0301 が出るため）

## 完了条件

- `scripts/check.sh` が通る（[実装の規約](../00-common/00-02-conventions.md)の「完了条件の共通の検査」）。
- 受け入れテストのすべての場合を確かめるテストがある。
- F02 と F04 のファイルを変えていない。
- 完了の報告の「判断したこと」に、`codes.rs` で直した型板を挙げる。

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「字句と構文（F01〜F04）」の行に加えて、次を読む。

- 属性の誤りが、一つの属性について一つの診断に収まっているか（名前の誤りのある属性の引数を重ねて報告していないか）。
- レコードの構築とパターンの読み分けが、02-03「構文解析の方式」の二字句の先読みだけで決まっているか。
- ドキュメントコメントを、宣言のノードの欄に入れたうえで、結果のコメントの一覧にも残しているか（フォーマッタのため。02-03「コメントとドキュメントコメント」）。
- 他の言語の書き方の診断で、同じ `BadSymbol` を E0105・E0212 と重ねて報告していないか。

## 難易度の理由

構文の一つ一つは短いが、属性の検査の組み合わせと、ドキュメントコメントを宣言に結び付ける規則（空の行、普通のコメント、属性の前の説明、ファイルの先頭の `//!`）の境界の場合が多い。F02 が置いたフックの中だけで書くので、共通の関数の使い方を F02 の表から正しく読み取る必要がある。
