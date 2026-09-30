# F04 構文解析 3: 型クラス・エフェクトとハンドラ・`with`・`lazy`・`try`・文字列補間・パターンの拡張・リストの展開

- 依存する作業: [F02](F02-parser-core.md)
- 難易度: 4（1〜5。README の「作業一覧」）
- 規模の見込み: 大（1500 行超。テストを含む）
- ブランチ: impl/F04-parser-traits-effects

## 目的

F02 が置いたフックのうち、`parser/traits.rs`・`effects.rs`・`interp.rs`・`spread.rs`・`patterns_ext.rs` の中身を書き、型クラスと実装の宣言、組み込みの制約、エフェクトの宣言、`handle`・`resume`・`with`・`lazy`・`try`、文字列補間、`match` の分岐の選択肢とガード、範囲とリストのパターン、組の診断、リストリテラルの展開を読めるようにする。あわせて、これらの構文の文脈の制限（`resume`・`return`・`try` の位置、操作の宣言、制約の小文字の名前）と、他の言語の書き方への診断を出す（02-03「文脈の制限」「他の言語の書き方への診断」）。F03 と並行して進める。

本作業の後、標準ライブラリのソース（10-14）の全体（`Benitoite.Trait` の型クラスと実装、`Benitoite.IO.Clock` などのエフェクトの宣言）が構文として読めるようになる。

## 読む設計書の節

- [構文](../../design/01-spec/01-02-syntax.md): 「組と `bind`・`shadow` のパターン（初回リリース版）」「文字列補間（初回リリース版）」「型クラス（初回リリース版）」「`Result.Error` と `Option.None` を呼び出し元へ返す構文（初回リリース版）」「明示遅延（初回リリース版）」「リソーススコープ（初回リリース版）」「パターンの拡張（初回リリース版）」「リストの展開（初回リリース版）」「エフェクトの宣言とハンドラ（初回リリース版）」「初回リリース版の文法の全体」
- [字句解析器と構文解析器](../../design/02-impl/02-03-frontend.md): 「構文解析の方式」（`match` と `handle` の分岐の並び）「文脈の制限」「構文の規則に伴う診断」（組）「他の言語の書き方への診断」「型の解析」（制約の並び）「AST」「入れ子の深さ」「標準ライブラリのソースの構文」（`ordered`）
- [代数的データ型とパターンマッチ](../../design/01-spec/01-05-data-types.md): 「パターンの拡張（初回リリース版）」
- [リソース管理](../../design/01-spec/01-10-resources.md): 「`with` の構文」
- [エラー処理](../../design/01-spec/01-09-errors.md): 「`Result.Error` と `Option.None` を呼び出し元へ返す構文 `try`」「例外」
- [ソース管理と位置情報](../../design/02-impl/02-02-source-and-spans.md): 「合成ノードの由来位置」（文字列補間の `${` から `}` までの span）
- ADR: [0058](../../design/decisions/0058-string-interpolation-of-base-types.md)、[0060](../../design/decisions/0060-trait-and-impl-syntax.md)、[0066](../../design/decisions/0066-explicit-laziness-pure-body.md)、[0067](../../design/decisions/0067-with-resource-scope.md)、[0097](../../design/decisions/0097-prefix-try.md)、[0098](../../design/decisions/0098-constraints-joined-by-ampersand.md)、[0102](../../design/decisions/0102-pair-and-triple.md)、[0118](../../design/decisions/0118-effect-handlers.md)、[0121](../../design/decisions/0121-pattern-extensions.md)、[0133](../../design/decisions/0133-builtin-equality-and-key-constraints.md)、[0155](../../design/decisions/0155-resume-not-in-lazy.md)、[0157](../../design/decisions/0157-stdlib-sources-as-modules-with-builtin-attribute.md)、[0257](../../design/decisions/0257-match-with-case-arms.md)、[0272](../../design/decisions/0272-list-spread-in-list-literals.md)、[0279](../../design/decisions/0279-no-duplicate-method-names-in-trait.md)
- インターフェース: [字句と構文木](../10-interfaces/10-03-syntax.md)の「AST」（`TraitDecl`・`MethodSig`・`ImplDecl`・`ImplFn`・`EffectDecl`・`OpSig`・`ConstraintRef`・`InterpExpr`・`ListElem`・`SpreadElem`・`TryExpr`・`LazyExpr`・`WithExpr`・`WithBind`・`HandleExpr`・`HandleClause`・`OpRef`・`ClauseParam`・`ResumeExpr`・`MatchArm`・`RangePat`・`RangeEnd`・`ListPat`・`ListRest`）、[診断](../10-interfaces/10-02-diagnostics.md)の「E02 構文」「E05 エフェクト、ハンドラ」の表で出す作業が F04 のコード
- F02 の作業の文書と、F02 が `src/syntax/parser/mod.rs` の先頭の `//!` に書いたフックの表と共通の関数の一覧

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `src/syntax/parser/traits.rs`: `parse_trait_decl`・`parse_impl_decl`・`builtin_constraint` の中身。
- `src/syntax/parser/effects.rs`: `parse_effect_decl`・`parse_handle`・`parse_resume`・`parse_with`・`parse_lazy`・`parse_try`・`check_escape` の中身。
- `src/syntax/parser/interp.rs`: `parse_interp` の中身。
- `src/syntax/parser/spread.rs`: `parse_spread_elem`・`check_list_spreads` の中身。
- `src/syntax/parser/patterns_ext.rs`: `parse_arm_head_rest`・`parse_range_rest`・`parse_list_pattern`・`report_tuple` の中身。
- 上のファイルの中の非公開の補助の関数と `#[cfg(test)] mod tests` のテスト（F02 の `parser::test_support` を使う）。
- `src/diag/codes.rs` の、本作業が出すコード（E0217・E0218・E0222・E0223・E0226・E0227・E0235・E0236・E0241・E0242・E0245・E0246・E0250・E0509・E0510）の型板の直し（10-02「型板の直し方」の範囲）。
- `testdata-next/` のゴールデンテスト（後述）。

F02 のファイルと F03 のファイル（`items.rs`・`records.rs`）は変えない。F03 の関数（`DocStore::take_for`・`parse_public`・`reject_public`）と F02 の共通の関数は呼んでよい。フックのシグネチャを変える必要や、共通の関数と `text.rs` の呼び名が足りないことが分かったら、作業を止めて報告する（[作業の進め方](../00-common/00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。

## 手順の要点

深さは、F02 の深さの数え上げの関数で数える。並びの要素（文字列補間の式、`with` の束縛、`handle` の節）は `i + 1`、分岐の選択肢とリストのパターンの要素はパターンの節の通し番号で数える（02-03「入れ子の深さ」）。

### 型クラスと実装（`traits.rs`）

- 型クラス: `trait` UpperIdent `[` 型パラメータの宣言 [`:` 上位の型クラスの並び] `]` メソッドの並び `end trait`。型パラメータの宣言は `T` か `F[_]`（`_` の数）。上位の型クラスは `&` でつないだ修飾した大文字の名前で、`TraitDecl::param.constraints` に `ConstraintRef::Class` として入れる。上位の型クラスの位置の小文字の名前は E0223（`name`、鍵 `remove` の置き換え）とし、並びから除く。
- メソッド: `function` 名前 [型パラメータ] `(` 引数 `)` `->` 型 [`uses`]（本体なし）。F02 のシグネチャを読む関数で読み、前で `DocStore::take_for` を呼ぶ。同じ名前のメソッドの重なり（ADR 0279）は名前解決が E0328 で報告するので、本作業では判定しない。
- 実装: `implement` [型パラメータの並び] 修飾した型クラスの名前 `[` 型 `]` 関数の宣言の並び `end implement`。型クラスの名前の後に `[` がない形（`implement Person … end implement`）は E0245（`name`、鍵 `functions`）とし、`end implement` まで読み飛ばす。中の関数は、`DocStore::take_for` で説明を受け取り、前に `public` があれば `items::parse_public` で読んで `items::reject_public` に渡し、F02 の関数の宣言を読む関数で読む。`ImplFn::id` はメソッドの名前を使う箇所のノードとして、`decl.id` と別に振る（10-03「AST」）。
- `builtin_constraint`: 制約の位置の小文字の名前が `equality`・`key` なら `ConstraintRef::Builtin`。`ordered` は `SourceKind::Prelude` のときだけ受け付け、利用者のソースでは E0222（鍵 `ordered`）。ほかの名前は E0222（鍵 `builtin`）とし、並びから除く。

### エフェクトの宣言（`parse_effect_decl`）

- `effect` UpperIdent 操作の並び `end effect`。操作は F02 のシグネチャを読む関数で読み、前で `DocStore::take_for` を呼ぶ。
- 操作に `uses` を書いたら E0510（鍵 `uses`）とし、`uses` の並びを捨てる。型パラメータにエフェクト変数を宣言したら E0510（鍵 `effect_var`）とし、その型パラメータを捨てる（02-03「文脈の制限」）。`OpSig` は `uses` の欄を持たない（10-03）。

### `handle` と `resume`（`parse_handle`・`parse_resume`）

- `handle` 本体 `with` 節の並び `end handle`。本体は F02 のブロックを読む関数で、「文の先頭の `with` の次が `case`」で終える。節は `case` 操作の名前 `(` 名前か `_` の並び `)` `->` 本体で、本体は NEWLINE の次が `case` か `end` で終える（02-03「構文解析の方式」）。操作の名前は `{ UpperIdent "." } LowerIdent`（`OpRef`）。`_` の引数は `ClauseParam::name` を `None` にする。分岐を読む位置の `when` は、F02 の関数で E0232 として扱う。
- 節の本体を読む間は、文脈の印 `clause` を `Direct` にする。本プランの決定: `handle` の本体を読むときは `clause` を変えない。外側の節の中に書いた `handle` の本体の中の `resume` は、外側の節の `resume` として受け付ける（10-07「コード生成」の補足が、`handle` の本体と節の原型が囲む節の継続を捕捉しうるとしている）。節の外の `handle` の本体の中の `resume` は、`clause` が `None` なので E0509 になる。
- `resume(e)`: `clause` が `Direct` なら `ResumeExpr`。`None` なら E0509、`Blocked` なら E0509 に鍵 `lambda` の注記を添える。どちらも式は読んでノードを作る（派生の誤りを出さない）。

### `with`・`lazy`・`try`（`parse_with`・`parse_lazy`・`parse_try`・`check_escape`）

- `with`: 次が「小文字の名前 `=`」なら、`with` 束縛 { `,` 束縛 } `do` 本体 `end with`（`WithExpr`）。束縛の式は F02 の式を読む関数で読む（`with a = try f() |> g(_, x), b = …` のコンマは式の後の区切り）。次がそれ以外（`with handler …`）なら E0246（鍵 `handle`）とし、`end with` か文の終わりまで読み飛ばす。
- `lazy` 本体 `end lazy`: 本体を読む間は、`escape` を `InLazy` にし、`clause` が `Direct` なら `Blocked` にする。
- `try e`: 前置の `try` の後の式全体（パイプを含む）を読む（02-03「構文解析の方式」）。読む前に `check_escape` を呼ぶ。`try` の直後が `{`（`BadSymbol`）なら E0235（鍵 `result`）とし、E0212 に代えて報告済みにし、対応する `}` と、続く `catch` の節（名前 `catch` と、その後の括弧と波括弧）まで読み飛ばす。
- `check_escape`: `escape` が `InLazy` か `InGuard` なら E0218（`keyword` は `return` か `try`、`context` は `text` の呼び名、鍵 `lazy_body` か `guard`、鍵 `lambda` の注記）。

### 文字列補間（`parse_interp`）

- `StrStart` 式 { `StrMid` 式 } `StrEnd` を読み、`InterpExpr` を作る。`head` は `StrStart` の値、各 `InterpSegment` の `tail` は続く `StrMid` か `StrEnd` の値である。
- `InterpSegment::span` は `${` から `}` まで（02-02「合成ノードの由来位置」）であり、前の字句の終わりの 2 バイト（`${`）の始めから、次の字句の最初の 1 バイト（`}`）の終わりまでとする。
- 式の後に `StrMid`・`StrEnd` がなければ E0201 とし、対応する `StrEnd` まで読み飛ばす。

### リストの展開（`spread.rs`）

- `..` 式は `ListElem::Spread`（`SpreadElem` の span は `..` から式の終わりまで）。`..` の直後が要素の終わり（`,`・`]`）なら E0201（パターンと違い、式が要る）。
- `...xs`（`..` と `.` の span が隣り合う）は E0227（`written` は `...`、`name` は式の断片、鍵 `spread` の置き換えで `...` を `..` にする）、`*xs` は E0227（`*` を `..` にする）とし、展開として読む。
- `check_list_spreads`: 二つ目以降の展開ごとに E0226（補助の位置 `first`、鍵 `concat`）。

### 分岐の頭とパターンの拡張（`patterns_ext.rs`）

- `parse_arm_head_rest`: 最初のパターンの後に、括弧の外側の `,` があれば選択肢を続けて読む。`if` があればガードとして式を読む（`escape` を `InGuard` にし、`in_arm_head` の間の `if` を `if` の式として読まない。ガードの中の `if` の式は括弧で囲んだものだけ）。`|`（`BadSymbol`）は E0236（`first`・`second` は前後のパターンの断片、鍵 `comma` の置き換えで `|` を `,` にする）とし、選択肢の区切りとして読む。名前 `when`・`where` は E0241（`pattern`・`condition`、鍵 `if` の置き換えでその語を `if` にする）とし、ガードとして読む。
- `parse_range_rest`: 整数（前置の `-` を含む）か文字のリテラルの後の `..` に、もう一方の端を読む（`RangePat`）。`..` の直後に空白なしで `=`・`<`・`.` が続く形（`1..=5`・`1..<5`・`1...5`）は E0242（`low`・`high`、鍵 `range`）とし、範囲として読む。本プランの決定: 置き換えは、`..=` と `...` では余分な字句を消すもの、`..<` では上端を一つ小さい値（整数は 1 を引いた値、文字は一つ前のスカラー値）にしたものとする。一つ小さい値が作れないとき（上端が最小の値）は置き換えを付けない。端の種類の違いと下端が上端より大きいことは型検査（F10）が判定する。
- `parse_list_pattern`: `[` 要素 { `,` 要素 } [`,`] `]`。要素は、パターンか、`..` [小文字の名前]（`ListRest`）。`..` の前の要素を `before`、後の要素を `after` に入れる。二つ目の `..` は E0250（補助の位置 `first`）とし、要素として捨てる。
- `report_tuple`: 丸括弧の中の括弧の外側のコンマを F02 が見つけたときに、要素の数と span を受け取り、E0217 を報告する。修正案は、要素が 2 個なら鍵 `pair`、3 個なら `triple`、4 個以上なら `record`。

## 受け入れテスト

F02 の `parser::test_support` でソースを字句解析・改行の判定・構文解析に通し、AST の形と診断のコード・主な位置（置き換えがあれば範囲と文字列）で確かめる。

| 場合 | 入力の要点 | 期待する結果 |
|---|---|---|
| 型クラス | `trait Monoid[T: Semigroup]\n function empty() -> T\nend trait`、`trait Functor[F[_]] …`、`trait Traversable[F[_]: Functor & Foldable] …` | `param` の `kind` と上位の型クラスの並び、メソッドのシグネチャ |
| 型クラスの誤り | `trait Eq[T: equality] …`、`implement Person\n function f() -> Unit … end function\nend implement` | E0223（置き換え）、E0245 |
| 実装 | `implement[T: Show] Show[List[T]]\n function show(xs: List[T]) -> String … end function\nend implement`、中の関数の前の `public` | `ImplDecl` の型パラメータ・型クラス・対象・関数。`public` は E0221（F03 の後に確かめる。F03 の前は `reject_public` の仮の本体で何も出ない） |
| 制約 | `[T: equality & key]`、利用者のソースの `[T: ordered]`、`SourceKind::Prelude` の `[T: ordered]`、`[T: eq]` | `Builtin` が二つ、E0222（鍵 `ordered`）、誤りなし、E0222（鍵 `builtin`） |
| エフェクト | 01-02「エフェクトの宣言とハンドラ（初回リリース版）」の `Log`・`sumPrices`・`total` | `EffectDecl`・`HandleExpr`（節一つ、引数一つ）・`ResumeExpr` |
| 操作の誤り | `function write(m: String) -> Unit uses Console.Write`、`function f[effect E]() -> Unit` を操作に | E0510（鍵 `uses`）、E0510（鍵 `effect_var`） |
| `resume` の位置 | 節の中の `resume(())`、節の中に書いた内側の `handle` の本体の中の `resume`、節の中のラムダの中、節の中の `lazy` の中、関数の本体 | 1・2 は誤りなし、3・4 は E0509（鍵 `lambda`）、5 は E0509 |
| 節の形 | `case Log.write(_) -> resume(())`、`when write(m): resume(())` | `ClauseParam::name` が `None`。後者は E0232 |
| `with` | 01-10 の `copyHeader`（束縛二つ、`try` とパイプを含む式）、`with handler do … end with` | `WithExpr` の束縛二つ。後者は E0246 |
| `lazy` | `lazy\n compute()\nend lazy`、`lazy return 1 end lazy`、`lazy lambda() return 1 end lambda end lazy` | 誤りなし、E0218（鍵 `lazy_body`）、誤りなし |
| `try` | `try parse(s) |> Result.mapError(_, f)`、`try { f() } catch (e) { g() }` | `TryExpr` の値がパイプ。後者は E0235 一つで、`{`・`}` について E0212 を出さない |
| ガード | `case n if n > 0 -> 1`、`case n if (if a then true else false end if) -> 1`、ガードの中の `return 1`、`case n when n > 0 -> 1`、`case n where n > 0 -> 1` | `MatchArm::guard`。3 は E0218（鍵 `guard`）、4・5 は E0241（置き換えで `if`） |
| 選択肢 | `case 1, 2 -> a`、`case Option.Some(1), Option.None -> b`、`case 1 | 2 -> c` | `patterns` が二つ。構成子の引数の中のコンマは区切りにならない。3 は E0236（置き換えで `,`） |
| 範囲 | `case 1..9 ->`、`case -5..-1 ->`、`case 'a'..'z' ->`、`1..=9`、`1..<10`、`1...9` | `RangePat`。後の三つは E0242。置き換えを当てると `1..9` になる |
| リストのパターン | `[]`、`[x, 0]`、`[first, ..rest]`、`[first, .., last]`、`[..]`、`[a, ..b, ..c]` | `before`・`rest`・`after`。最後は E0250 |
| 組 | `(1, "one")`、`bind (a, b) <- p`、型の `(Integer, String, Boolean)`、`(1, 2, 3, 4)` | E0217（鍵 `pair`・`pair`・`triple`・`record`） |
| 文字列補間 | `"a${x}b${f(y)}c"`、入れ子の `"a${g("b${x}")}"` | `InterpExpr` の `head`・`segments`。各 `InterpSegment::span` が `${` から `}` まで |
| 展開 | `[a, ..xs, b]`、`[..xs, ..ys]`、`[...xs]`、`[*xs]`、`[x, ..]` | `ListElem::Spread`。E0226（補助の位置が一つ目）、E0227（置き換え）、E0227、E0201 |
| 深さ | `with` の束縛 1001 個、`handle` の節 1001 個、選択肢の多い分岐 | E0208 で打ち切る（F02 の数え方） |
| 標準ライブラリのソース | 10-14 のすべてのソースを `SourceKind::Prelude` で読む（F03 の取り込みの後） | 構文の誤りなし |

ゴールデンテスト: 誤りのない次の例を、`testdata-next/<区分>/` に `f04_<名前>.bnt`・`.mode`（`check`）・`.exit`（`0`）の組で置く（先頭に `// spec: …` の行）。初回リリース版の検査を誤りなく通る完全なプログラムにする。F18 と C10 が揃うまで実行されず、C05 が確かめる。

- `traits/`: 型クラスと実装、上位の型クラス（`import Benitoite.Trait` を使う例と、利用者の型クラスの例）
- `handlers/`: 01-02 の `Log` の例（`main` を加える）
- `syntax/`: 文字列補間、`lazy`、`try`、リストの展開（01-02 の `insertByCount` の例）
- `patterns/`: 01-05「パターンの拡張（初回リリース版）」の二つの例
- `effects/`: `with` と `File` のリソース（`import Benitoite.Unofficial.IO.File`。非公式のモジュール。[ADR 0286](../../design/decisions/0286-unofficial-modules-imported-under-unofficial.md)）

## 完了条件

- `scripts/check.sh` が通る（[実装の規約](../00-common/00-02-conventions.md)の「完了条件の共通の検査」）。
- 受け入れテストのすべての場合を確かめるテストがある（F03 の関数に頼る場合は、F03 が取り込まれていればその結果で、取り込まれていなければ仮の本体の振る舞いで確かめ、完了の報告に書く）。
- F02 と F03 のファイルを変えていない。
- 完了の報告の「判断したこと」に、`codes.rs` で直した型板を挙げる。

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「字句と構文（F01〜F04）」の行に加えて、次を読む。

- 文脈の印を、構文に入るときに保存して立て、出るときに必ず戻しているか（誤りから回復して抜ける経路を含む）。
- `handle` の本体の終わりを「文の先頭の `with` の次が `case`」だけで決め、本体の中のリソーススコープの `with` と取り違えていないか。
- ガードの `if` を `if` の式として読んでいないか。改行の判定（F01）の分岐の頭の規則と、読み方が一致しているか。
- E0235・E0236・E0242 など、`BadSymbol` や隣り合う字句から判定する診断で、E0105・E0211・E0212 と重ねて報告していないか。

## 難易度の理由

構文の種類が多く、文脈の印（`resume`・`return`・`try` の位置）を構文の入れ子と正しく組み合わせる必要がある。`handle` の本体の終わり、ガードの `if`、選択肢のコンマなど、先読みと改行の判定（F01）の規則に頼る読み分けが多い。F02 のフックの中だけで書くので、共通の関数の使い方を F02 の表から正しく読み取る必要もある。
