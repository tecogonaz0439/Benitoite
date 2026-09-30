# T13 名前解決

- 依存する作業: [T12](T12-parser-exprs.md), [T10](T10-builtin-table.md)
- 難易度: 3（1〜5。README の「難易度の目安」）
- 規模の見込み: 大（1500 行超）
- ブランチ: impl/T13-resolver

## 目的

prelude のソースと利用者のソースの AST の名前を解決し、束縛の表・参照の表・宣言の表を作る。prelude の名前の表は、組み込みの表（T10）と prelude のソースから作る。名前の誤りを報告し、綴りの近い名前や、単位を持たない `String.length` などに修正案を示す。

## 読む設計書の節

- [名前解決とモジュール読込](../../2026-09-27-design-initial/02-impl/02-04-resolver.md)の「prelude」「束縛」「解決の手順」「誤りと修正案」
- [名前・スコープ・モジュール](../../2026-09-27-design-initial/01-spec/01-03-names-modules.md)の「名前の種類」から「シャドーイング」まで（「（v1）」の節を除く）
- [代数的データ型とパターンマッチ](../../2026-09-27-design-initial/01-spec/01-05-data-types.md)の「型の宣言」「値の構築」「prelude が定める型」
- [型システム](../../2026-09-27-design-initial/01-spec/01-06-type-system.md)の「関数の型とエフェクト」（エフェクト変数を書ける位置）
- [基本型の意味論](../../2026-09-27-design-initial/01-spec/01-04-types-basic.md)の「String」（単位を持たない名前の修正案）
- [ADR 0010](../../2026-09-27-design-initial/decisions/0010-shared-namespace-and-shadowing.md)、[ADR 0043](../../2026-09-27-design-initial/decisions/0043-option-result-rust-names-no-unwrap.md)、[ADR 0047](../../2026-09-27-design-initial/decisions/0047-parenthesized-types-and-uses-binding.md)
- インターフェース: [名前解決](../10-interfaces/10-04-resolve.md)、[組み込みの関数](../10-interfaces/10-10-builtins.md)の「組み込みの表の型」「組み込みの表の関数」、[診断](../10-interfaces/10-02-diagnostics.md)の E03nn、[字句と構文木](../10-interfaces/10-03-syntax.md)の「AST」

## 作るもの

- `src/resolve/mod.rs`: 10-04 の `sig=src/resolve/mod.rs` の `resolve`。
- `src/resolve/` の下の非公開のファイル（分け方は任意。例: `prelude.rs` に prelude の名前の表、`scope.rs` に有効範囲の積み重ね、`suggest.rs` に綴りの近い名前と修正案）。宣言は `resolve/mod.rs` に `mod prelude;` などとして加える。10-04 の `file=` の部分は変えない。
- 上のファイルの中のテスト。

## 手順の要点

### 束縛の番号を振る順序

束縛の番号は `ids.binding()` で、次の順に振る。番号の値をテストで確かめることはしないが、同じ入力で同じ番号になるように順序を固定する。

1. prelude の型（`TyCon::Int`・`Float`・`String`・`Char`・`Bool`・`Unit`・`List`・`Option`・`Result`・`IoError` の順。`BindingKind::Type`）
2. 型を持たないモジュール `Console`・`File`・`Process`（`BindingKind::Module`）
3. エフェクトの名前 `IO`（`BindingKind::Effect`）
4. 構成子 `Some`（`Option` のタグ 0）・`None`（1）・`Ok`（`Result` のタグ 0）・`Err`（1）。`PreludeBindings` の `some`・`none`・`ok`・`err` に入れる
5. 組み込みの関数。`BuiltinId::ALL` の順に、演算子（`is_operator()` が真のもの）を除いて一つずつ振り、`PreludeBindings.builtins` に入れる。演算子は名前で引かれないので束縛を持たない
6. prelude のソースの関数（ファイルの順、ファイルの中の順）
7. 利用者の型、その構成子、利用者の関数（ソースの順。型の宣言の束縛を振った直後に、その構成子の束縛を振る）
8. 各宣言の型パラメータ、引数、局所の束縛（解決の手順 3・4 で出会った順）

1〜5 の束縛の `decl` は `DeclSite::Prelude`、`span` は `None` である。6 以降は `DeclSite::Node(宣言したノード)` と名前の span を持ち、`decls` に「宣言したノード → 束縛の番号」を加える。宣言したノードは 02-04「束縛」の対応（関数の宣言、データ構成子の宣言、型の宣言、型パラメータの宣言、引数、`let` 文、変数のパターン）による。`let _ = e` と、`_` のパターンは束縛を作らない。

型の宣言の束縛の種類は `Type(TyCon::Adt(その束縛の番号))`、構成子は `Ctor { con: TyCon::Adt(型の束縛の番号), tag }` である。タグは型の宣言の中の構成子の順に 0 から振る。

型パラメータの `index` は、その宣言の型パラメータの並びのうち `effect` を付けないものだけを数えた位置、エフェクト変数の `index` は `effect` を付けたものだけを数えた位置である。

### prelude の名前の表

- prelude のモジュールの中身は、組み込みの関数（`spec(id).module` がそのモジュールのもの）と、prelude のソースの修飾した関数である。モジュールの中の名前を引くときは、`table::lookup(module, name)` と、prelude のソースの修飾した関数の表を引く。
- `spec(id).prelude_only` が真の組み込みの関数は、prelude のソースの中から引くときだけ見つかる。利用者のソースから引いたときは見つからないものとし、E0303 にする。
- prelude のソースの修飾した関数のモジュールの名前が `PreludeModule` のどれでもなければ、E0302 を報告する。prelude のソースの誤りは処理系の不具合であり、prelude のソースだけを解決するテストで見つける（02-04「prelude」）。修飾した関数の名前が、同じモジュールの組み込みの関数か別の修飾した関数と重なったときも、E0306 を報告する（同じ理由）。
- prelude のソースの補助の関数（修飾しない名前）は、prelude のソースの中からだけ引ける。利用者のトップレベルの関数と同じ名前でも衝突しない。

### 名前を引く順序

- 利用者のソースの修飾しない小文字の名前は、有効範囲の積み重ねの内側から外側へ局所の束縛を引き、なければ利用者のトップレベルの関数を引く（01-03「修飾しない名前の解決」）。prelude のソースの中では、局所の束縛、補助の関数の順に引き、利用者のトップレベルの関数は引かない（02-04「prelude」）。
- 修飾しない大文字の名前（式と構成子のパターン）は、`Some`・`None`・`Ok`・`Err` なら prelude の構成子に解決する。それ以外は誤りである（次節の E0304・E0301）。
- 修飾された名前 `A.b`・`A.B` は、`A` をトップレベルの大文字の名前（利用者の型、prelude の型とモジュール）として引き、そのモジュールの中でドットの右の名前を引く。利用者の型のモジュールには構成子だけが入る。prelude の型のモジュールには構成子が入らない（`Option.Some` は E0317）。参照の表には、ドットの右の名前が指す束縛を載せる。
- 型を書く位置の大文字の名前は、その関数の型パラメータ（型の宣言の中ではその宣言の型パラメータ）、トップレベルの型の名前の順に引く。関数の本体の中の型注釈（`let` の型注釈、ラムダの引数と戻り値の型）でも、その関数の型パラメータが見える。
- `uses` の並びの名前は、その関数のエフェクト変数、`IO` の順に引く。ラムダの `uses` と関数の型の `uses` でも、外側の関数のエフェクト変数が見える。

### 有効範囲

- 02-04「解決の手順」の手順 2 で、利用者のトップレベルの宣言をすべて集めてから、手順 3・4 を宣言ごとに行う。ある宣言の誤りは、ほかの宣言の解決を止めない。
- 積み重ねは、関数の本体、ブロック、ラムダ、`match` の分岐に入るときに一段積み、出るときに降ろす。
- `let` は右辺を解決した後で、束縛した名前を現在の段に加える。同じ段に同じ名前を加えたら置き換える（ADR 0010）。
- パイプとプレースホルダは書かれたままの形で辿る。プレースホルダは名前でないので解決しない。

### 誤りと修正案

| 誤り | コード | 型板の値と extras の鍵 |
|---|---|---|
| 見つからない修飾しない名前（小文字、および型を書く位置の大文字） | E0301 | `name`。候補があれば `candidates` と `help("similar")` |
| 見つからないモジュール（`A.b` の `A`） | E0302 | `name`。候補（トップレベルの大文字の名前）があれば `help("similar")` |
| モジュールの中に見つからない名前 | E0303 | `module`・`name`。下の特別な修正案がなければ、候補があれば `help("similar")` |
| 種類の合わない名前 | E0304 | `name`・`found_kind`・`expected_kind`（後述） |
| 型の名前の重複 | E0305 | `name`。2 個目を主な位置に、1 個目を `secondary(.., "first")` |
| 関数の名前の重複 | E0306 | 同上 |
| 型の名前が prelude の型・モジュール・エフェクトと同じ | E0307 | `name` |
| 型の名前が `Some`・`None`・`Ok`・`Err` | E0308 | `name`、`note("prelude_ctor")` |
| 構成子の名前の重複 | E0309 | `name`・`ty`、`secondary(.., "first")` |
| 引数の名前の重複（関数とラムダ） | E0310 | `name`、`secondary(.., "first")` |
| 一つのパターンの中の変数の重複 | E0311 | `name`、`secondary(.., "first")` |
| 型パラメータの名前の重複（エフェクト変数を含む並び） | E0312 | `name`、`secondary(.., "first")` |
| 型パラメータがトップレベルの大文字の名前と同じ | E0313 | `name` |
| 型を書く位置のエフェクト変数と `IO` | E0314 | `name`、`help("uses_only")` |
| `uses` の並びの最初のエフェクトでない名前 | E0315 | `name` |
| `uses` の並びの 2 番目以降のエフェクトでない名前 | E0316 | `name`、`help("paren")`（ADR 0047） |
| `Option.Some` など修飾した prelude の構成子 | E0317 | `name`・`module`、`help("unqualified")` |

- 候補は、その位置で見える同じ種類の名前のうち、レーベンシュタイン距離が 2 以下のものを、距離の小さい順、同じ距離なら名前の辞書式の順に最大 3 つとる（02-04「誤りと修正案」）。`candidates` の値は `` `a`, `b` `` の形につなげる。修飾しない小文字の名前の候補は、その位置で有効な局所の束縛と、見えるトップレベルの関数である。修飾された名前の候補は、同じモジュールの名前（利用者のソースからは prelude 専用の組み込みの関数を除く）である。
- E0303 の特別な修正案は次のとおりとし、これを示すときは `help("similar")` を示さない。`String` の `length`・`len`・`size` には `help("length")`、`slice`・`substring` には `help("slice")`、`indexOf` には `help("index_of")`、`Option` と `Result` の `unwrap`・`expect` には `help("unwrap")`（`module` と `name` の値を使う）。
- E0304 の `found_kind` と `expected_kind` の語は、冠詞を含めて `a type`・`a module`・`an effect`・`a constructor`・`a value`・`a type parameter`・`an effect variable` から選ぶ（型板は冠詞を持たない）。これらの語は、`resolve` の非公開の子のモジュール `text`（`resolve/text.rs`、`resolve/mod.rs` で `mod text;` と宣言する）に定数として置く（00-02「文言」）。式の中に書いた修飾しない大文字の名前が、利用者の型か prelude の型・モジュールの名前なら、`found_kind` にその種類、`expected_kind` に `value` を入れる。どのトップレベルの名前でもなく、利用者のどれかの型がその名前の構成子を持つなら、`found_kind` に `constructor`、`expected_kind` に `value` を入れ、`help("qualify")` に `suggestion`（`Shape.Circle` の形。複数の型にあれば宣言の順の最初）を示す。構成子のパターンでも同じ規則で報告する。どちらでもなければ E0301 にする。
- 型を書く位置の型を持たないモジュール（`Console`）は E0304（`found_kind` に `module`、`expected_kind` に `type`）とする。
- 解決できなかった名前は参照の表に載せない。

## 受け入れテスト

テストは T12 までの構文解析で AST を作り、`resolve` を呼んで、診断のコード・主な位置・修正案の文と、表の中身を確かめる。prelude のソースは `crate::prelude::SOURCES` を解析して渡す。

| 場合 | 入力（要点） | 期待 |
|---|---|---|
| prelude のソースだけ | 利用者のソースを空のプログラムにする | 診断なし。`PreludeBindings` の 4 構成子と、演算子以外の組み込みの関数の数だけの `builtins` がある |
| 局所の束縛とシャドーイング | 01-03「局所の束縛の有効範囲」「シャドーイング」の例 | 右辺の `x` は引数の束縛、後の `x` は `let` の束縛を指す |
| 宣言の順によらない参照 | `main` が後で宣言した関数と型を使う | 診断なし |
| 構成子 | `Shape.Circle(1.0)`、パターン `Shape.Rect(w, h)`、`Some(x)` | 参照の表が `Ctor` の束縛を指す |
| 見つからない名前 | `lenght` と書き、局所の束縛 `length` がある | E0301、`help` に `` `length` `` |
| 単位を持たない名前 | `String.length(s)` | E0303、`help("length")` の文、`similar` なし |
| unwrap | `Option.unwrap(o)` | E0303、`help("unwrap")` の文 |
| prelude 専用の関数 | 利用者のソースの `List.dropFirst(xs)` | E0303 |
| 修飾した prelude の構成子 | `Option.Some(1)` | E0317 |
| 修飾しない利用者の構成子 | `Circle(1.0)`（`Shape` に `Circle` がある） | E0304、`help` に `Shape.Circle` |
| 型の名前を式に書く | `Shape` を式に書く | E0304 |
| 重複 | 型・関数・構成子・引数・パターンの変数・型パラメータの重複 | E0305・E0306・E0309・E0310・E0311・E0312、補助の位置が 1 個目 |
| prelude の名前との衝突 | `type List { A }`、`type Some { A }` | E0307、E0308 |
| 型パラメータとトップレベルの名前 | `fn f[Int](x: Int) -> Int` | E0313 |
| 型の位置のエフェクト | `fn f(x: IO) -> Unit`、`fn f[effect E](x: E) -> Unit` | E0314 |
| `uses` の中の型 | `fn f() -> Unit uses Int`、`fn g(h: fn(fn() -> Unit uses IO, Int) -> Unit) -> Unit` | E0315、E0316（`help` あり） |
| 補助の関数は見えない | 利用者のソースから `mapInto(...)` | E0301 |
| 補助の関数と同名の利用者の関数 | 利用者の `fn mapInto(...)` | 診断なし。束縛の番号が prelude の `mapInto` と違う |
| 誤りの後の継続 | 一つの宣言に見つからない名前が 2 個、別の宣言に 1 個 | 3 個すべて報告 |
| 型パラメータの位置 | `fn f[A, effect E, B](...)` | `A` の `index` は 0、`B` は 1、`E` のエフェクト変数の `index` は 0 |

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある
- prelude のソースだけを解決して診断がないことを確かめるテストがある

## 難易度の理由

一つ一つの規則は単純だが、prelude のソースと利用者のソースで引き方が違うこと、修飾の有無と名前の大小で規則が分かれること、誤りの種類ごとに修正案の選び方が決まっていることを、漏れなく組み合わせる必要がある。束縛の種類・宣言の表・型パラメータの位置は後の型検査と脱糖が前提にするので、ここでの取り違えが後の作業で見つかりにくい誤りになる。アルゴリズム自体に難しいところは少ない。
