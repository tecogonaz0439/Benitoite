# 調査 C: 決めることの整理と先例

2026-10-13 に、フェーズ 2 で決める論点ごとに、選択肢、設計原則（00-01「設計原則」の番号。以下「原則 n」）に照らした利点と欠点、推す案と理由をまとめた。外部の事実は一次資料（仕様・公式の文書・依存のクレートのソース）で確かめたものに出典を添え、確かめられなかったものは「未確認」と書く。処理系の現状は調査 A（`A-codebase.md`）を引く。調査 B（Wasmtime の試作。`B-wasm.md`）は、本書の初稿の後に読み、試作の結果で推す案を直した。B の結果を引く箇所は「（B 1.3）」のように節を示す。

依存のクレートのソースは、手元の cargo のレジストリにある `wasmtime-49.0.2`・`wasmparser-0.258.3`（Wasmtime 49.0.2 が使う版）・`wit-parser-0.258.3`・`wit-parser-0.261.0` を読んだ。Component Model の仕様は、03-10 が引く版と同じ `6c48079b`（2026-10-13 の `main`）の `design/mvp/Explainer.md` と `WIT.md` を読んだ。

## 0. 前提として確かめた事実

| 事実 | 出典 |
|---|---|
| WIT の型は再帰できない（`type foo = foo` も、自分を含む record も誤り） | [WIT.md](https://github.com/WebAssembly/component-model/blob/6c48079b/design/mvp/WIT.md)（「Types, however, cannot be recursive」） |
| WIT の利用者の型は型パラメータを持たない。型パラメータを持つのは `list`・`option`・`result`・`tuple` などの組み込みだけである | 同上（型の文法） |
| variant は一つ以上の case を持たなければならない。record は一つ以上の欄を持たなければならない | 同上。record は `wasmparser-0.258.3/src/validator/component.rs` 4125〜4127（「record type must have at least one field」） |
| 名前（label）の字句は `first-fragment ('-' fragment)*`。断片は `[a-z][0-9a-z]*`（語）か `[A-Z][0-9A-Z]*`（頭字語）で、先頭の断片は英字で始まる。2 番目以降の断片は数字で始まってよい（`a1-2-3`） | [Explainer.md「Import and Export Definitions」](https://github.com/WebAssembly/component-model/blob/6c48079b/design/mvp/Explainer.md#import-and-export-definitions) |
| インターフェースの名前は `namespace:package/interface@semver` | 同上（`interfacename`）、WIT.md（「Package names look like `foo:bar@1.0.0`」） |
| resource の関数は、書き出しの名前で `[constructor]R`・`[method]R.name`・`[static]R.name` と表す。メソッドは最初の引数に `self` の handle を取る | Explainer.md（`plainname`）、WIT.md（resource の節） |
| record の欄の名前・variant の case の名前・enum の名前は、英字の大小を無視して一意でなければならない（ハイフンの位置は区別する） | `wasmparser-0.258.3/src/validator/component.rs` 4129〜4137・4184・4270、`validator/names.rs` 82〜92（`KebabStr` の比較は ASCII の小文字に揃えて行う） |
| `map<K, V>` は WASI 0.3 の後に加わった機能（🗺️）で、Wasmtime 49.0.2 では `Config::wasm_component_model_map` で有効にする。Wasmtime 49.0.2 が使う wasmparser 0.258.3 では既定で無効（`cm_map ... = false`）。0.259.0 で既定が有効になった | Explainer.md「Gated Features」、`wasmtime-49.0.2/src/config.rs` 1365、`wasmparser-0.258.3/src/features.rs` 342、`wasmparser-0.259.0/src/features.rs` 342 |
| Wasmtime の `Val` は `Record(Vec<(String, Val)>)`・`Variant(String, Option<Box<Val>>)`・`Enum(String)`・`Resource(ResourceAny)`・`Map(Vec<(Val, Val)>)` を持つ | `wasmtime-49.0.2/src/runtime/component/values.rs` 67〜97 |
| Wasmtime の型の API の `Record` は欄（名前と型）だけを返し、record の型そのものの名前を返さない | `wasmtime-49.0.2/src/runtime/component/types.rs` 427〜459 |
| インターフェースの中の関数は、`get_export_index(None, インターフェースの書き出しの名前)` で得た索引を親にして `get_export_index(Some(&親), 関数の名前)` で引く | `wasmtime-49.0.2/src/runtime/component/instance.rs` 120〜155・334、`component.rs` 794 |
| Wasmtime の書き出しの名前の表は、完全一致がなければ semver で互換な名前を探す。`@1.2.0` を書き出したコンポーネントは `@1.0.0` でも `@1.9.9` でも引ける | B 1.2・1.3、`wasmtime-environ-49.0.2/src/component/names.rs` の `NameMap::get` |
| `export api;`（パッケージ `bnt:demo@1.2.0` のインターフェース）の書き出しの名前は `bnt:demo/api@1.2.0`（版を含む）。world の中に書いたインターフェースは平らな名前（`inline`）になる | B 1.1 |
| 関数の呼び出しが誤り（罠、ホストの側の引数の形の誤り、捨てた resource の使用）を返すと、その `Store` のどのインスタンスにも入れなくなる | B 2.2 |
| `Val::Record` の欄は WIT の順に並べる必要がある | B 3.1 |
| `ResourceAny` は作った `Store` に結び付き、`resource_drop(store)` で解放する | `wasmtime-49.0.2/src/runtime/component/resources/any.rs` 49・165 |
| 受け渡しの予算（hostcall fuel）は、動的な値の持ち上げでは要素ごとに `size_of::<Val>()`、型付きの `Vec<T>`・`WasmList<T>` では `len × size_of::<T>()` を数える。既定値は 128 MiB | `values.rs` 232 など、`func/typed.rs` 1777、`store.rs` 27 |
| 型付きの `WasmList<u8>` などは `as_le_slice` でゲストの線形メモリを直接読める | `func/typed.rs` 1850〜1890 |

## 論点 1 パッケージの中だけの公開（TODO-234）

### 1.1 先例

| 言語・道具 | 書き方 | 単位 | 予約語 | 出典 |
|---|---|---|---|---|
| Rust | `pub(crate)`・`pub(super)`・`pub(in path)` | 宣言 | `crate` は既存のキーワード | [The Rust Reference「Visibility and privacy」](https://doc.rust-lang.org/reference/visibility-and-privacy.html) |
| Swift 5.9 | `package` の修飾子 | 宣言 | 文脈で意味を持つ語（既存の `package` という名前はそのまま使える）。`public` の関数の引数と戻り値に `package` の型を使えない | [SE-0386](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0386-package-access-modifier.md) |
| Kotlin | `internal` | 宣言（範囲は一緒にコンパイルする「module」） | 修飾子のキーワード（未確認: 識別子に使えるかは同じページに書かれていない） | [Visibility modifiers](https://kotlinlang.org/docs/visibility-modifiers.html) |
| F# | `internal` | 宣言（範囲はアセンブリ） | キーワード | [Access Control](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/access-control) |
| Scala | `private[pkg]` | 宣言 | なし（`private` の修飾） | [Scala 2.13 の仕様「Classes and Objects」の Modifiers](https://scala-lang.org/files/archive/spec/2.13/05-classes-and-objects.html) |
| Go | `internal` という名前のディレクトリの下のパッケージは、その親を根とする木の中からしか import できない | モジュール（ディレクトリ） | なし。言語ではなく `go` コマンドが強制する | [Go 1.4 Release Notes「Internal packages」](https://go.dev/doc/go1.4#internalpackages) |
| OCaml・dune | `.mli` でモジュールの中の公開を決め、dune の `private_modules` でライブラリの外から見えないモジュールを指定する | モジュール | なし | [dune「library」](https://dune.readthedocs.io/en/stable/reference/dune/library.html) |
| Java | `module-info.java` の `exports` に書いたパッケージだけを外に出す | パッケージ（設定に列挙） | 文脈で意味を持つ語 | [JLS 21 第 7 章](https://docs.oracle.com/javase/specs/jls/se21/html/jls-7.html) |
| Haskell（Cabal） | `exposed-modules` と `other-modules`（「used by the component but not exposed to users」） | モジュール（設定に列挙） | なし | [Cabal の package description](https://cabal.readthedocs.io/en/stable/cabal-package-description-file.html) |
| Gleam | 属性 `@internal`（v1.1.0。文書・補完・書き出したモジュールのインターフェースから隠す）と、`gleam.toml` の `internal_modules`（既定は `パッケージ名/internal` の下。取り込めはするが安定の保証がない） | 宣言とモジュール | なし | [Gleam v1.1 の変更履歴](https://github.com/gleam-lang/gleam/blob/main/changelog/v1.1.md)、[gleam.toml](https://gleam.run/documentation/gleam-toml-reference) |

Go 1.4 の告知は、導入の理由を「公開と非公開の二つしかなく、公開のリポジトリにあるがプログラムの外で使われることを意図しないコードにも利用者がつく」と書いており、TODO-234 の問題と同じである。Gleam の `@internal` が他のパッケージからの使用を誤りにするかは確かめていない（未確認）。

### 1.2 書き方の選択肢

| 案 | 例 | 利点 | 欠点 |
|---|---|---|---|
| (a) `public` の修飾 | `public(package) function helper(...)` | 予約語を増やさない（`package` は 01-01 で予約しない語）。三つの段階を「`public` の広さ」として一列に読める（原則 3）。Rust の `pub(crate)` が学習データに多い（00-01「構文の判断基準」の見込み） | 括弧が増え、プログラマでない人には「公開だが限定」が読みにくい。`TopDecl.public`（凍結の 10-03）の形が変わる（調査 A 4.3）。LLM が `public(crate)` と書く誤りを診断で案内する必要がある |
| (b) 新しい語 | `internal function helper(...)` | 一語で読める（原則 3）。Kotlin・F#・C# の先例 | キーワードにすると互換性を壊す（TODO-018、ADR 0236）。`as` のように文脈で意味を持つ語にすれば壊さないが、文脈語が増える。Kotlin の `internal` はモジュール、F# はアセンブリが範囲で、語の意味が言語ごとに違う |
| (c) Swift の `package` | `package function helper(...)` | 予約語を増やさない（文脈語）。範囲の名前と語が一致する | `package.bnt` の `package` のブロックと同じ語が別の意味を持つ（原則 5 の趣旨に反しはしないが、読み手が取り違えうる） |
| (d) 属性 | `@internal function helper(...)` | 構文木を変えない（調査 A 4.3）。R5 と同じく「属性で予約語を増やさない」理由に合う | 01-02「属性」は、評価の意味を変えない属性を「処理系や道具が宣言をどう扱うか」とする。名前解決の見え方を変える属性は新しい種類になる。`@internal public function` のような組み合わせの意味を別に定める必要がある |
| (e) ディレクトリの名前（Go） | `Calc/Internal/Helper.bnt` のモジュールは同じパッケージからしか取り込めない | 構文を変えない。取り込みの名前に `Internal` が現れるので、使う側のコードを読めば分かる（原則 3） | 粒度がモジュールになり、一つのモジュールの中で公開と内部用を分けられない。設計者の方向（`pub(crate)` に当たるもの）と粒度が違う |
| (f) 設定に列挙（Java・Cabal・dune） | `package.bnt` の `package` のブロックに `exposes Calc.Api` | パッケージの外への契約が `package.bnt` の差分に現れる（原則 2）。`benitoite package` のエフェクトの集計の範囲もここで決まる | 粒度がモジュール。宣言を読むだけでは外から見えるかが分からない（`public` と `package.bnt` の二か所を読む） |

推す案: **(a) `public(package)`**。理由: 予約語を増やさず（TODO-018 の判断を構文の見直しへ残せる）、設計者の方向（宣言の単位の `pub(crate)`）に合い、既存の `public` の契約の検査を「段階の大小」に一般化するだけで済む。見た目は構文の見直し（TODO-205）で変わる前提なので、今は意味（三段階と範囲）を固めることを優先する。(b)・(c) の一語の形が読みやすいことは認めるが、語を選ぶ判断は TODO-205 の可読性の基準（プログラマでない人の拒否反応）で行うべきで、今決めると二度決めることになる。

診断: `public(crate)`・`pub(crate)`・`internal`・`package function` と書いたときは、`public(package)` を修正案として示す（原則 4）。括弧の中に書けるのは `package` だけとし、ほかの語は書ける語を示して誤りとする。

### 1.3 範囲

- 依存のパッケージ: 同じパッケージの根の下のモジュール（同じ依存の別名を持つ `ModuleKind::Package` のモジュール。調査 A 4.2）。
- パッケージでない根: 根の側（入口と根の下のモジュール）をすべて一つのパッケージとみなす（調査 A 4.3 の (i)）。依存から根のモジュールは取り込めないので、根では `public(package)` と `public` の見え方は同じになる。誤りや警告にはしない。理由: 根の下で書いたモジュールを、書き換えずにパッケージへ移せる。自分の根でパッケージを開発するとき（`package.bnt` に `package` のブロックがあるとき）も、根の側が同じパッケージになるので、依存として読まれたときと判定が一致する（R19 と同じ考え方）。
- テスト: パッケージの根で `benitoite test` を走らせるテストのファイルは根の側なので、`public(package)` の関数を呼べる。Kotlin が `test` のソースから `main` の `internal` を見せるのと同じ結果になる。
- 入口のモジュールに書いた `public(package)` は、今の `public` と同じく意味を持たない（取り込めない）。誤りにしない。

### 1.4 公開の契約の検査を三段階に広げる

段階を `非公開 < public(package) < public` と順序づけ、Swift と同じ規則にする: 宣言の契約に現れる型・型クラス・エフェクトは、その宣言の段階以上でなければならない。今の 01-03「公開（初回リリース版）」の三つの段落（関数の引数と戻り値、構成子の引数、レコードの欄、型クラスのメソッドと制約と上位の型クラス、定数の注釈、型の別名の右辺、`uses`、エフェクトの操作）を、どれも「`public` を付けた宣言」から「段階 s の宣言」に読み替える。

- `public` の関数が `public(package)` の型を使う → 誤り。
- `public(package)` の関数が非公開の型を使う → 誤り。
- `public(package) data` は型とすべての構成子を同じ段階で公開する（構成子ごとに段階を分けない。01-03 の今の規則と同じ）。型は `public` で構成子だけ `public(package)` にする形（外からは作れない型）は今回入れない。TODO-072 の `#[non_exhaustive]` に当たる仕組みと合わせて考える。
- `implement` は今のとおり段階を持たない。
- 取り込んだ側が段階の足りない名前を引いたときの診断は、「見つからない」「公開されていない（E0330）」と区別し、「パッケージ X の中だけで公開されている」と示す（原則 4）。

### 1.5 `benitoite package` のエフェクトの集計（R24）

集計は `public` の宣言だけを数え、`public(package)` を数えない。理由: 集計の目的は「パッケージを使う側から見える契約」を示すことであり、`public(package)` は使う側から呼べない。06-09「`benitoite package`」の「公開の」の語に、`public(package)` を含めないと一文加える。

## 論点 2 インターフェースの関数の指し方（TODO-235）

### 2.1 先例

| ホスト・道具 | 指し方 | 出典 |
|---|---|---|
| Wasmtime（Rust の API） | インターフェースの書き出しの名前（`ns:pkg/iface@1.0.0` など、コンポーネントの書き出しの名前そのもの）で索引を引き、それを親にして関数の名前を引く | `wasmtime-49.0.2/src/runtime/component/instance.rs` 120〜155 |
| Wasmtime の CLI（`run --invoke`） | wit-parser の `ItemName` で読む。書式は `ns:pkg/iface.name@1.0.0`（版は最後に付く）。インターフェースを書かなければ、まず world の直下を探し、なければすべてのインターフェースから同じ名前の関数を探し、二つ以上あれば候補を示して誤りにする | [Wasmtime v49.0.2 の `src/commands/run.rs`](https://github.com/bytecodealliance/wasmtime/blob/v49.0.2/src/commands/run.rs) の `search_component_funcs`、`wit-parser-0.258.3/src/ast.rs` 2173〜2300 |
| jco（JS） | 書き出したインターフェースを、名前の最後の段（`iface`）の JS の書き出しと、`'my:pkg/interface@version'` の文字列の別名の二つで出す。関数は camelCase の名前のメソッドになる | [jco の transpiling の文書](https://github.com/bytecodealliance/jco/blob/main/docs/src/transpiling.md) |
| wit-component（ゲストの側のコアのモジュールの名前） | 古い命名（Legacy）では、インターフェースの関数のコアの書き出しを `インターフェースの名前#関数の名前` とする | `wit-parser-0.261.0/src/lib.rs` 1461 |
| componentize-py・wasmtime-py | componentize-py はゲスト（コンポーネントを作る側）の道具で、ホストの指し方の先例にならない。wasmtime-py のコンポーネントの API の指し方は確かめていない（未確認） | — |

Bytecode Alliance の解説は、関連する関数をインターフェースにまとめて world から書き出す形を推奨する構成として示している（[Running WebAssembly Components From the Command Line](https://bytecodealliance.org/articles/invoking-component-functions-in-wasmtime-cli)）。wit-bindgen は WIT に書いた world のとおりに作り、どちらが既定ということはない（B 1.5）。

### 2.2 第 3 引数の書き方の選択肢

| 案 | 例 | 利点 | 欠点 |
|---|---|---|---|
| (a) `#` で区切る | `"local:fuzzy/api#distance"`、`"local:fuzzy/api@1.0.0#distance"` | `#` は label にも interfacename にも現れないので、最後の `#` で一意に分けられる。前半がコンポーネントの書き出しの名前と一字一句同じなので、照合の規則が「書き出しの名前を探す」で済む（原則 4）。wit-component のコアの名前と同じ形 | `#` の形は仕様の名前の文法にない（wit-component の内部の命名に現れるだけ）。Wasmtime の API に `#` つきの名前を渡しても引けないので、処理系が分けて二段で引く（B 1.2） |
| (b) Wasmtime CLI の形 | `"local:fuzzy/api.distance@1.0.0"` | Wasmtime の CLI と同じ | 版が関数の名前の後に来て、書き出しの名前（`…/api@1.0.0`）と字面が一致しない。`[method]R.name` の `.` と紛れる |
| (c) 別の引数 | `@external("wasm", "wasm/fuzzy.wasm", "local:fuzzy/api", "distance")` | 区切りの規則が要らない | 引数の数で位置の意味が変わり、LLM が取り違えうる（原則 5）。属性の引数の数の検査が場合分けになる |
| (d) 関数の名前だけで探す（CLI の後段と同じ） | `"distance"` | 短い | 探索が暗黙で、コンポーネントに同じ名前の関数を持つインターフェースが加わると宣言が誤りに変わる。どれを呼ぶかが宣言から読めない（原則 2・3） |

推す案: **(a)**。最後の `#` より前をコンポーネントの書き出しの名前として、そのまま引く。`#` がなければ今のとおり world の直下の関数を引く（R5 と互換）。理由: 規則が一つで、診断で「書き出しの名前の一覧」を示せば LLM が写せる。

- 版: 書き出しの名前と完全に一致することを求める（semver の互換の照合はしない）。Wasmtime の `get_export_index` は semver で互換な名前も引き、宣言より古い版（`@1.9.9` の宣言に `@1.2.0` の書き出し）でも通してしまう（0 章）。そこで処理系は `component_type().exports()` で実際の書き出しの名前を列挙し、文字列として一致するものを探してから索引を引く（B 1.3 の判断と同じ）。理由: コンポーネントの版が変わったことを宣言の照合の誤りとして示し、契約の変更を見落とさせない（原則 2）。照合の誤りでは、コンポーネントの書き出しのうちインターフェースの名前の一覧（版つき）を示す。
- 版のないパッケージのインターフェースは `ns:pkg/api`、版のあるパッケージは `ns:pkg/api@1.2.0` と書く（パッケージの版がすべてのインターフェースに付く。B 1.1）。world の中に書いたインターフェース（`export inline: interface { ... }`）は平らな名前（`inline`）になるので、(a) の前半にはそれを書く。
- 仕様は版を縮めた canonical な名前（🔗）を定め、今の形を「temporarily permitted」とする（B 1.3）。ツールが canonical な名前に移った後の扱いは、その時に docs/todo の項目として扱う。
- resource の関数は `"ns:pkg/iface#[method]pattern.is-match"` のように、後半に Component Model の plainname をそのまま書く（論点 4）。

### 2.3 インターフェースの中の型

関数の型の中の record・variant は構造で照合するので（論点 3）、インターフェースの中で定義した型かどうかは照合に影響しない。TODO-047 の型の拡張と同時に入れても、規則を分ける必要はない。resource の型の宣言（論点 4）は、resource がどのインスタンス（インターフェース）の書き出しかを指す必要があるので、同じ `#` の書き方を使う。

### 2.4 WIT から `@external` の宣言を作る道具

推す案: **今回は入れない**。代わりに、照合の誤り（E1010 など）で、コンポーネントの関数の型を Benitoite の宣言の形にして示す（「期待する宣言: `function distance(a: String, b: String) -> Integer`」）。理由: `@external` の見た目は TODO-205 で変わり、作った道具をすぐ書き直すことになる。診断で示せば、LLM が一つずつ写せ、道具を覚える必要もない（原則 4・6）。関数が多いパッケージの手間は、構文の見直しの後に道具として扱う（docs/todo に項目を加える）。

## 論点 3 型の拡張の規則（TODO-047）

### 3.1 照合の単位: 構造だけか、名前も照合するか

Component Model の関数の型は構造で決まり、Wasmtime の型の API は record の型の名前を返さない（0 章）。インターフェースの中の型はインターフェースのインスタンスの書き出し（`ComponentItem::Type`）として引ける（B 1.2）が、関数の型の中の record からその書き出しの名前へ辿る API は確かめていない（未確認）。world の直下の関数が使う型が書き出しとして現れるかも確かめていない（未確認）。

推す案: **型の名前は照合せず、構造（欄の名前と型、case の名前と中身）で照合する**。欄と case の名前は照合する。理由: 名前を照合しない位置引数（R5）と違い、record の欄と variant の case は名前で値を受け渡すので、名前の対応は避けられない。型の名前は値の受け渡しに現れず、照合しても検出できる誤りが増えない。

### 3.2 欄と case の名前の対応

Benitoite の識別子は ASCII の英字・数字・`_` からなり、欄は小文字識別子、構成子は大文字識別子である（01-01「識別子」）。WIT の label は 0 章のとおりである。

選択肢:

- (i) WIT の名前から Benitoite の名前を作る（`byte-start` → `byteStart`、`not-found` → `NotFound`）。頭字語の扱い（`is-XML` → `isXml` か `isXML` か）を決める必要がある。2 番目以降の断片が数字で始まると（`a-1b` → `a1b`）、別の名前（`a1b`）と同じになる。
- (ii) Benitoite の名前から kebab-case を作り、WIT の名前と英字の大小を無視して比べる。変換は「小文字か数字の直後の大文字の前に `-` を入れる」。`byteStart` → `byte-start`、`isXML` → `is-xml`（WIT の `is-XML` と大小を無視して一致）、`line2Col` → `line2-col`、`NotFound` → `not-found`。
- (iii) 名前を変換せず、属性などで対応を書かせる。

推す案: **(ii)**。理由: wasmparser は欄・case・enum の名前を大小を無視して一意にするので（0 章）、大小を無視した比較で WIT の側の候補は高々一つに決まる。規則は「kebab-case の名前を camelCase に書く」の一文で説明でき、LLM が写しやすい（原則 4）。頭字語の綴りを利用者に選ばせても照合が変わらない。

変換できない名前と衝突:

- `_` を含む Benitoite の名前（`_x`、`x_y`）は対応する WIT の名前がないので、照合の誤りとし、kebab-case から作る名前を修正案として示す。
- WIT の名前のうち、(ii) の変換で作れないもの（2 番目以降の断片が数字で始まる `a-1b`、Benitoite のキーワードに当たる `type`・`match`・`end` など）は、Benitoite の側で書けないので、照合の誤りとし、その欄を持つ型を受け渡せない旨を示す。別名を付ける仕組みは今回入れない（TODO-205 で属性の書き方とあわせて考える）。
- 欄の順: Wasmtime は `Val::Record` の欄を WIT の順に並べることを求め、順が違うと呼び出しが誤りになって `Store` に印が立つ（B 2.2・3.1）。選択肢は、宣言の順と WIT の順の一致を照合で求めるか、変換で並べ替えるかである。推す案は「照合で一致を求める」。理由: 誤りを実行前に報告でき（原則 1）、宣言を読めば WIT の形がそのまま分かる。並べ替えは安く作れるが、宣言と WIT の字面の対応が崩れ、変換表の誤りが実行時の `Store` の印として現れる。

### 3.3 直和型と variant・enum

| Benitoite | WIT | 推す扱い |
|---|---|---|
| すべての構成子が引数を持たない `data` | `enum`、または中身のない case だけの `variant` | どちらにも照合する（WIT の側に合わせる）。enum と variant は ABI が違うので、変換表に区別を持つ |
| 引数が 0 個か 1 個の構成子からなる `data` | `variant`（中身なしか一つ） | 照合する |
| 引数が 2 個以上の構成子 | — | 誤りとする。修正案は、引数をレコードか `Pair`・`Triple` にまとめること |
| 型パラメータを持つ `data`・レコード | — | 誤りとする（具体化した `Box[Integer]` を record に照合する案は今回入れない） |
| 再帰する型（相互再帰、`List[自分]` などを通した再帰を含む） | — | 誤りとする。WIT が再帰を許さないので、照合に成功する WIT の型がない |
| 利用者のレコード | `record` | 3.1・3.2 のとおり |

引数が 2 個以上の構成子を `tuple` に写す案は、`C(Pair[A, B])` と `C(A, B)` の二つが同じ WIT の型に照合することになり、同じ役割の書き方を二つにする（原則 5）ので推さない。型パラメータを許さない理由は、照合の単位が宣言ごとになり、具体化ごとの変換表を作る必要がなくなるからである。`flags` は Benitoite に対応する型がないので、今のとおり誤りとする。

### 3.4 標準ライブラリの型との対応で決まっていない点

| 点 | 推す扱い | 理由 |
|---|---|---|
| `Map[K, V]` と `map<K, V>` | 今回入れない | Wasmtime 49.0.2 では機能を有効にする設定が要り、既定で無効である（0 章）。wit-bindgen 0.62.0 が `map` を出せるかも確かめていない（未確認）。TODO-212 の三つの対象は `Map` を境界に要しない（`Json.Value.Object` は再帰する型の中にあり、どのみち直接は渡せない） |
| 4 個以上の要素の `tuple` | 誤りのまま | Benitoite に対応する型がない（`Pair`・`Triple` だけ） |
| `Option[Unit]`・`List[Unit]` など入れ子の `Unit` | 誤りのまま | 03-10「型の対応」のとおり。利用者の型の構成子に引数を持たせない形で表せる |
| `Result` の片側に利用者の `data` | 照合する | variant を入れると自然に許される。`Result[T, MyError]` は WASM のライブラリの典型の形である |
| 標準ライブラリの型と同じ綴りの利用者の型（`Option` など） | 今の E1010 の注記を、レコード・variant の照合にも当てる | 03-10 の今の決まりの延長 |

## 論点 4 resource

### 4.1 前提の整理

- 今の `Regex.Pattern` と `Regex.Match` は、01-10 のリソースの型ではなく、中身を見せない型（回収で解放され、`with` も `State` も要らない）である（調査 A 2.3）。TODO-047 の「リソースの型と WIT の `resource`」という言い方は、この点で今の実装と食い違う。
- WIT の resource の handle は、作った `Store`（インスタンス）に結び付く（0 章）。今は呼び出しごとにインスタンスを作り直す（03-10「実行」）ので、このままでは handle を次の呼び出しへ持ち越せない。
- 01-07「可変のセル（初回リリース版）」は、純粋な関数について「同じ引数で二度呼んだとき、どちらも値を返したなら同じ値を返す」と保証している。03-10 は、呼び出しごとにインスタンスを作り直すことをこの性質の根拠にしている。
- resource を長く持つと、ゲストはメソッドの呼び出しの間で内部の状態を変えられる。処理系はゲストの中身を検査しないので、メソッドが状態を変えないことを保証できない。`regex` クレートは照合のたびに内部のキャッシュを更新するので、結果が同じでも燃料の消費量は履歴に依存しうる（調査 A 2.2 の推測）。

### 4.2 純粋の扱いの選択肢

| 案 | 内容 | 利点 | 欠点 |
|---|---|---|---|
| (A) `State` を付ける | resource を受け取る・返す外部の関数には `uses State` を書かせる（`uses` に書けるのは `State` だけ）。resource は `Reference` と同じく「中身の変わりうる値」として扱う | 01-07 の保証を弱めない。`Reference.new` が `State` を持つのと同じ考え方で、新しい規則が少ない（原則 1・2）。`State` は `IO.All` に含まれ、許可を要しない | `Regex` を WASM で書くと、照合のたびに `State` が型に現れ、今の `Regex` と同じ使い勝手（純粋）にならない。呼び出し元の関数にも `State` が広がる |
| (B) 純粋のまま | resource の関数も純粋として型付けする | 今の `Regex` と同じ使い勝手になる | 状態を変えるゲストで 01-07 の保証が破れる。宣言済みの保証を弱めることになる（00-01「目的が衝突したときの判断基準」に反する） |
| (C) 呼び出しごとに状態を戻す | コンストラクタの後のインスタンスの状態を写しとして持ち、メソッドを呼ぶたびにその写しから始める | 純粋のまま保証を保てる | Wasmtime 49.0.2 のコンポーネントの API でインスタンスの線形メモリを写し、戻す手段を確かめていない（未確認）。費用が線形メモリの大きさに比例する |
| (D) resource を使わない | `Regex` の検証は、照合のたびにパターンの文字列を渡してゲストで組み立てる純粋な関数で行う | 純粋のまま。今の仕組みで書ける | resource の対応（TODO-212 の `Regex` の検証の目的）を確かめられない。組み立ての費用が照合ごとにかかる |

B の試作では、短い入力の 1,000 回の照合が、resource を使い回す形で 0.65 ms、毎回パターンを渡す形（(D)）で 78 ms、毎回インスタンスも作る形で 110 ms だった（B 要約）。resource を持つ価値は大きい。

推す案: **(A) を入れ、(D) を比較の対照として測る**。理由: (A) は保証を弱めずに resource の受け渡しを確かめられ、(D) と比べれば「純粋な API を保つ費用」と「`State` を付ける使い勝手の損失」を両方とも TODO-097 の材料にできる。(C) は docs/todo に残す。(B) は採らない。これは設計の方向を変える選択なので、設計者に尋ねる（最後の Q1）。

### 4.3 インスタンスの寿命

| 案 | 内容 | 評価 |
|---|---|---|
| (a) 呼び出しごと（今） | — | handle を持ち越せないので resource を扱えない |
| (b) resource ごと | resource を作る呼び出しごとに専用の `Store` を作り、その resource のメソッドはその `Store` で呼ぶ（調査 A 2.2 の (b)） | 二つの resource を受け取る関数（WIT の例の `merge: static func(lhs: borrow<blob>, rhs: borrow<blob>)`）を呼べない。resource の数だけインスタンスとメモリを持つ |
| (c) コンポーネントごとに一つの「状態を持つインスタンス」 | resource を型に含む関数（コンストラクタ・メソッド・静的な関数と、引数か戻り値に resource を含む関数）は、実行ごと・コンポーネントごとに一つの長く生きる `Store` で呼ぶ。resource を型に含まない関数は今のとおり呼び出しごとに作り直す | 複数の resource を受け取る関数を呼べる。純粋な関数の再現性は変わらない。(A) の `State` と合わせれば、状態を共有することは型に現れる |

推す案: **(c)**（B 2.5 の C と同じ形）。置き場所は実行ごとの `ExternalRuntime`（調査 A 2.2）。一度の誤りで、そのコンポーネントの resource がすべて使えなくなる（0 章）が、今は外部の関数の誤りで実行全体を止めるので、同じ実行で再び入る場面はない。上限は次のとおりとする（どれも案）。

- 燃料・epoch の期限・受け渡しの予算は、呼び出しの前に設定し直し、呼び出しごとのままにする。
- 線形メモリの 64 MiB は、状態を持つインスタンスでは「寿命の合計」になる。resource を作り続けるループは、解放しなければこの上限（R0905）で止まる。上限の意味が呼び出しごとと寿命で違うことを 03-10 に書く。
- トラップした `Store` には二度と入れない（調査 A 1.5）。今はトラップで実行全体を止めるので、同じ実行で再び入る場面はない。

### 4.4 宣言の書き方

resource に当たる Benitoite の型を宣言する手段が今はない（調査 A 2.4）。

推す案: **中身を見せない型の宣言 `@external("wasm", "パス", "resource の書き出しの名前") type 名前`** を加える（`=` と右辺のない `type`）。関数は今の `@external` に plainname を書く。

```text
@external("wasm", "wasm/regex.wasm", "local:regex/api#pattern")
public type Pattern

@external("wasm", "wasm/regex.wasm", "local:regex/api#[static]pattern.compile")
public function compile(source: String) -> Result[Pattern, String] uses State

@external("wasm", "wasm/regex.wasm", "local:regex/api#[method]pattern.is-match")
public function isMatch(pattern: Pattern, text: String) -> Boolean uses State
```

- 理由: 予約語を増やさず（`type` を流用）、関数の側は新しい構文を要しない。plainname をそのまま書くので、Wasmtime の索引の引き方と一字一句対応する（原則 4）。
- 欠点: 構文木（凍結の 10-03）と型の構成子（10-05）に触れる見込みである（調査 A 2.4）。凍結した型の変更の了承が要る。
- 型は等値の型にしない（今の `Regex.Pattern` と同じ）。
- 照合: メソッドの最初の引数は宣言した型で、WIT の `borrow<R>` と照合する。ほかの位置の Benitoite の resource の型は、WIT の `own<R>` か `borrow<R>` と照合する。戻り値は `own<R>` だけを照合する（WIT が戻り値の `borrow` を許すかは確かめていない。未確認）。
- `own` の引数に渡した handle は、ゲストへ所有が移るので、Benitoite の側では解放済みとして扱い、後で使えば 01-10「解放したリソースの使用」と同じく実行時エラーにする。
- コンストラクタ（`[constructor]R`）は、失敗しうる形（`result<R, E>` を返す）を Wasmtime 49.0.2 と wit-bindgen 0.62.0 が扱えるかを確かめていない（未確認）。`Regex.compile` は静的な関数（`[static]pattern.compile`）で書けば足りる。

### 4.5 解放

01-10 のリソースの型にはせず、`Reference` と同じく回収で管理する中身を見せない値にする。理由: 取り込みのないゲストの destructor は外部に作用しないので、いつ解放しても（解放しなくても）結果を観測できない。01-10 が `with` と止めるときの解放を定めたのは、バッファの書き出しなど外部に見える後始末のためであり、ここには当たらない。`with` と解放の `State` を求めると、使い勝手だけが下がる。

- 回収された handle の `resource_drop`: 調査 A 2.3 のとおり、対象の `Drop` から `ExternalRuntime` に触れない。B の試作では、20,000 個のパターンを捨てずに作るとゲストの線形メモリが 1.4 MB から 100.7 MB に増え、捨てた後に作り直すと増えなかった（ゲストの確保器が使い回す。B 2.3）。実行の終わりまで解放しないと、パターンを作り続けるループが 64 MiB の上限（R0905）に早く当たる。推す案は、**回収された handle を解放待ちの列に入れ、次にその状態を持つインスタンスへ入る前に `resource_drop` で片付ける**形（調査 A 2.3 の候補）。列は言語の値を含まない番号だけを持つので、02-08「外部の関数の実行系」の約束（`ExternalRuntime` は言語の値を持たない）に合う。片付けの時期は回収の時期に依存する。取り込みのないゲストの destructor は外部に作用しないが、同じインスタンスの共有の状態（生きている resource の数など）を変えるゲストでは、`State` の付いたメソッドの結果が回収の時期で変わりうる。燃料とメモリの消費量も回収の時期で変わりうる。この非決定性を 03-10 に書くか、明示の解放だけにして回収では解放しない（上限に当たりやすくなる）かは、Q1 で (A) を採るときに合わせて決める。
- 明示の解放の関数（`close` に当たるもの）は今回入れない。列で片付けても上限に当たる使い方が測定で見つかれば、docs/todo の項目として扱う。
- 中断・止める手順: `ExternalRuntime` を捨てるだけでよい（ゲストの destructor を呼ばなくても外部への影響がない）。
- 参照インタプリタ: 中身を見せない値を写せない（調査 A 1.1）ので、resource を受け渡すプログラムを差分テストから除く。

### 4.6 今の `Regex` との対応

| 今の `Regex` | WASM の検証の版（推す案） |
|---|---|
| `Pattern`: 中身を見せない型、純粋 | `@external ... type Pattern`（resource）、関数は `uses State` |
| `Match`: 中身を見せない型 | WIT の `record`（`text`・`byte-start`・`byte-end`・`groups: list<option<string>>`）。resource にしない。名前付きの捕獲は、`Pattern` のメソッドで名前の一覧を返すか、`Match` の欄に `list<tuple<string, option<string>>>` を持たせる |
| `replaceAllWith`（関数を引数に取る） | 外部の関数は関数を受け取れないので、Benitoite の側で `find` を繰り返す形で書く（今の実装も Benitoite で書いている） |

## 論点 5 大きな値を速く渡す経路（TODO-230）

### 5.1 選択肢

| 案 | 内容 | 評価 |
|---|---|---|
| (a) 型付きの呼び出し（`TypedFunc`） | 決まった形の署名（例: `(list<u8>) -> list<u8>`、`(string) -> string`）ごとに Rust の型で呼ぶ。`Vec<u8>`・`&[u8]` で渡し、`Vec<u8>` か `WasmList<u8>::as_le_slice` で受け取る | Wasmtime の公開の API だけで書ける。予算は要素の大きさ（`u8` なら 1）で数えられる（0 章）。署名が動的なので、形ごとに単形化した呼び出しを用意し、表にない形は今の `Val` の経路に戻る |
| (b) 線形メモリへ直接写す | ゲストの `cabi_realloc` を呼んで線形メモリに書き、コアの関数を呼ぶ | コンポーネントのインスタンスのコアの関数とメモリを、Wasmtime のコンポーネントの API は公開していない（未確認だが、`Instance` の公開の関数に見当たらない）。正規 ABI を自作することになり、規約上 `unsafe` も書けない |
| (c) `Val` の経路の改良 | 変換の作業列やカーソルの改良 | `Val::List(Vec<Val>)` が 1 要素 40 バイトであることは変わらず、予算と時間の 40 倍は残る |
| (d) 動的な型に `Lower`・`Lift` を実装する | 署名の形によらず型付きの経路を使う | `ComponentType`・`Lower`・`Lift` は `unsafe` の trait で、規約（`unsafe` は `runtime::heap` の内部の層だけ）の例外になる。採らない |

B の試作（B 4.2・4.4）: 1 MiB の `list<u8>` の往復は `Val` の経路で 16.7 ms・確保 約 127 MB、型付きで 37〜46 µs・約 1 MB だった。型を {s64, f64, string, list<u8>} に限り、引数 0〜3 個と結果 1 個の全 340 通りを具体化しても、実行ファイルは約 0.8 MB 増えるだけだった。(b) の経路は公開の API にないことも B が確かめた。

推す案: **(a) を、型の集合と引数の数で決めた全組み合わせに使う**。初めの集合は B が測った {`Integer`/s64, `Float`/f64, `String`/string, `Bytes`/list<u8>}、引数 0〜3 個、結果 1 個（340 通り）とし、宣言の型がすべて集合に入る関数を型付きで、ほかを今の `Val` の経路で呼ぶ。理由: 形を TODO-212 の三つに絞るより、規則（「この四つの型だけからなる 3 引数までの関数」）が短く、利用者と LLM が速い経路に当たるかを判断できる（原則 3）。`Boolean`・`List[Integer]`・`List[Float]` を足すと組み合わせが大きく増える（6 型で 1,554 通り）ので、測定で効果を確かめてから足す。`ResourceAny` を含む形（Regex）は、resource の関数の数が少ないので、`Val` の経路のままでよい（費用の大半はゲストの照合）。

### 5.2 予算の数え方

今の規則は「Wasmtime が数えるのと同じ数え方」である（02-09「外部の関数の実行」）。型付きの経路でも Wasmtime の数え方（`len × size_of::<T>()`）に従えば、規則の文はそのままで、`Bytes` は 1 バイトにつき 1 を数える。渡せる `Bytes` は約 6.7 MB から、言語の値の上限（2^30 バイト）より先に 256 MiB に達するところまで広がる。

戻り値の予算は Wasmtime の hostcall fuel が数え、引数（ホストからゲスト）は Wasmtime が数えないので処理系が自分で数えている（B 4.3、02-09「外部の関数の実行」）。型付きの経路の引数は、Wasmtime の戻り値の数え方に合わせて `len × size_of::<T>()`（`Bytes` は 1 バイトにつき 1、文字列はバイト数）で数える。

欠点: 同じ大きさの `Bytes` でも、関数の型が速い経路の集合に入るかで、予算に達するかが変わる（`Bytes` と `Boolean` を取る関数は `Val` の経路になる）。

推す案: **規則の文は変えず、速い経路の条件（型の集合と引数の数）と、その経路での数え方を 03-10 に書く**。`Val` の経路で大きな値を渡して予算に達した誤り（R0905）の注記に、速い経路の条件を示す。予算をゲストのバイト数（正規 ABI の大きさ）で一律に数える案は、`Val` の経路のホストのメモリが 40 倍になる点を抑えられなくなるので採らない。この扱いでよいかを設計者に確かめる（最後の Q3）。

## 論点 6 TODO-212 の検証の進め方

### 6.1 置き場所

| 物 | 推す置き場所 | 理由 |
|---|---|---|
| `Hash`・`Regex`・`Json` のコンポーネント（`rust/`・`wit/`・`wasm/` と Benitoite の包みのモジュール） | `crates/benitoite/testdata/packages/libraries.files/` の下に、Fuzzy と同じ形のパッケージとして置く | ゴールデンテストで、wit-bindgen が実際に出す record・variant・resource の照合と、A（今の `@builtin`）との結果の一致を確かめられる。TODO-047 の型の拡張のテストを兼ねる |
| B（Benitoite で書いた Json の構文解析器） | 同じ場所に、形 1 のパッケージとして置く | A・C と同じ入力で同じ結果を返すことを、ゴールデンテストで確かめる |
| 測定のプログラム | `tools/bench/programs/` に置き、上のパッケージを `path` の依存で指す | スキル `benchmark` の手順と道具に乗せる |
| 測定の入力（1 KB・100 KB・10 MB の JSON） | `tools/bench/programs/gen_*.py` の形で生成し、生成物はリポジトリに置かない | 10 MB をリポジトリに置かない |
| 結果 | `tools/bench/results/`（スキル `benchmark` の形）。結論の要約は TODO-212 と TODO-097 に書く | 設計書には、実装した内容（速い経路、型の対応）とその理由に要る数字だけを書く |

B の試作の大きさは、Hash 22 KB、Json 81 KB、Regex 926 KB だった（`opt-level = "s"`、LTO。B 5.1）。testdata に置いてもリポジトリの負担は小さい。ただし Regex のコンパイルは約 0.47 秒かかる（B 6）ので、Regex を使うゴールデンテストは数を絞る（TODO-229 の共有がないため、テストごとにコンパイルする）。

Unofficial のモジュールは置き換えない。処理系の `@builtin` はそのまま残し、WASM の版は検証のための別のパッケージ（`import Regexw.Pattern` のような別名）として並べる。

### 6.2 Json の越え方

| 越え方 | 作るか | 理由 |
|---|---|---|
| 1. 文字列から文字列へ（検証・整形） | 作る | 型の拡張を要さず、境界で文字列を写す費用だけを測れる。速い経路 `(string) -> string` の効果も測れる |
| 2. 平らな節点の表で返し Benitoite で木に組み直す | 作る | A・B と同じ `Json.Value` を得る唯一の越え方で、課題「解析して全部作る」と「文字列に書く」の比較に要る。record・enum・`list<record>` を使うので、型の拡張の検証も兼ねる |
| 3. resource で文書を持ち、要る値だけを問い合わせる | 論点 4 で (A) を採るなら作る | 課題「数か所だけを読む」で最も速くなりうる。`Regex` と同じく `State` が付く |

節点の表の形は B の試作（B 5.3）の `variant node { null, boolean(bool), integer(s64), float(f64), text(string), array(u32), object(u32), key(string) }` を前順に並べた `list<node>` を基にする。ただし子の数の `u32` は Benitoite に対応する型がないので `s64` に改める（TODO-020 の範囲に触れない）。この形は、論点 3.3 の「引数 0 個か 1 個の構成子だけの `data`」にそのまま照合する。B の試作の serde_json は鍵を辞書順に並べ替えた（B 5.3）ので、A の `Json.Value.Object`（`Map`）の順と一致するかを、測る前の結果の照合で確かめる。

### 6.3 B の範囲

`parse`・`stringify`・`stringifyPretty` の三つを、A と同じ結果（`Json.ParseError` の行と列、数の扱い、`\u` のエスケープとサロゲートの対、整形の空白）で書く。`get`・`at`・`as*` は A の `Json` の Benitoite のソースをそのまま使えるので書かない。A と結果が食い違う入力が見つかったら、どちらが 03-08「Json」に合うかを記録する（A の不具合なら docs/todo に加える）。

### 6.4 測る課題と大きさ

todo-items.md の案（四つの課題 × 1 KB・100 KB・10 MB、C は初回と 2 回目以降を分ける、測る前に結果の一致を確かめる）のとおりとする。加えて次を測る。

- `Hash.sha256`: A と C（`Val` の経路と速い経路）を 1 KB・1 MB・6 MB（`Val` の経路の予算の限界の手前）・100 MB（速い経路だけ）で。
- `Regex`: A、C の (A) 案（resource）、C の (D) 案（照合ごとに組み立てる）で、同じパターンを 1 回・1,000 回照合する。燃料の消費量も記録する。
- WASM のコンポーネントの大きさと、Wasmtime を入れた後の実行ファイルの大きさ（フェーズ 1 の記録との差）。

## 論点 7 TODO-232 の測定の内容

設計者の答え（decisions.md の Q4）のとおり、実装の後に機械の状態を確かめてから測る。測る項目の案:

| 項目 | 測り方 | 決めること |
|---|---|---|
| 呼び出し一回の費用 | 空の関数（`func() -> s64`）を 10^4 回呼ぶ。インスタンスの作成、呼び出し、値の変換を分ける。状態を持つインスタンス（論点 4）の呼び出しも測る | 呼び出しごとのインスタンスを続けるか（TODO-229 の共有の効果の見積もり） |
| 燃料あたりの時間 | 決まった命令数を回すテキスト形式のコンポーネントと、Fuzzy の距離（100〜3,000 文字）で、燃料と実時間の比を取る | 燃料の既定値の換算 |
| 10^10 の燃料を使い切る時間 | 無限ループのコンポーネントを `OutOfFuel` まで回す | 既定値を変えるか、実時間の上限（TODO-047）が要るか。目安の時間は設計者に決めてもらう |
| コンポーネントの大きさごとのコンパイルの費用（TODO-228） | 関数の数を増やして作った 1・4・16・64・256 MiB 程度のコンポーネントで、`Component::from_binary` の時間と最大 RSS を測る。データの区画だけ大きいものはコンパイルの負荷にならないので分ける | 大きさの上限を 256 MiB から下げるか |
| 中断の遅れ | 長いループの最中に `SIGINT` を送り、終わるまでの時間を測る（見張りのスレッドの 10 ms の間隔の確認） | 間隔の見直しが要るか |

## 設計者に尋ねるべき問い

1. **resource の関数に `uses State` を付けるか（論点 4.2）**。推す案は (A)（`State` を付け、01-07 の保証を保つ）と、対照として (D)（resource を使わず照合ごとに組み立てる純粋な関数）を測ること。(A) では WASM の `Regex` が今の `Regex` と同じ純粋な使い勝手にならない。(B)（純粋のまま）は保証を弱めるので推さない。答えで、宣言の書き方・インスタンスの寿命・Json の越え方 3 の有無が変わる。
2. **パッケージの中だけの公開の書き方（論点 1.2）**。推す案は `public(package)`（予約語を増やさない）。一語の形（`internal`、Swift の `package`）を今選ぶか、モジュールの単位の仕組み（Go の `Internal` のディレクトリ、`package.bnt` に公開するモジュールを列挙）を選ぶかで、構文・名前解決・`benitoite package` の集計の作りが変わる。
3. **速い経路の範囲と予算の数え方（論点 5.1・5.2）**。推す案は、宣言の型が {`Integer`, `Float`, `String`, `Bytes`} だけからなる引数 3 個までの関数を型付きの経路で呼び、その経路では `Bytes` を 1 バイトにつき 1 と数えること（ほかは今のとおり 1 要素 40）。同じ大きさの `Bytes` でも関数の型で上限が変わることを受け入れるか。
4. **凍結した型の変更の了承（論点 1・4）**。`public(package)` は `TopDecl`（10-03）と `Binding`（10-04）に、resource の型の宣言（`@external ... type 名前`）は構文木（10-03）と型の構成子（10-05）に触れる見込みである（調査 A 2.4・4.3）。実装の前に了承の表を作ってよいか。

## 推す案どおりとしてよい点

- 論点 1.3: パッケージでない根は、根の側全体を一つのパッケージとみなす。根では `public(package)` と `public` の見え方が同じになるが、誤りにしない。
- 論点 1.4: 段階を `非公開 < public(package) < public` と順序づけ、契約に現れる名前は宣言の段階以上でなければならない（Swift と同じ）。構成子ごとの段階は分けない。
- 論点 1.5: `benitoite package` のエフェクトの集計は `public` だけを数える。
- 論点 2.2: 第 3 引数は最後の `#` で区切り、前半をコンポーネントの書き出しの名前とする。版は文字列の完全一致を求め（Wasmtime の semver の互換の引き方に頼らず、書き出しを列挙して照合する）、照合の誤りで書き出しの名前の一覧を示す。`#` がなければ今のとおり world の直下を引く。
- 論点 2.4: WIT から宣言を作る道具は今回入れず、照合の誤りで期待する宣言を示す。
- 論点 3.1・3.2: 型の名前は照合しない。欄と case の名前は、Benitoite の名前から作った kebab-case と WIT の名前を英字の大小を無視して比べる。`_` を含む名前、変換で作れない WIT の名前は誤りとし、別名の仕組みは入れない。欄の順も照合で一致を求める。
- 論点 3.3: 引数 0 個か 1 個の構成子だけの `data` を variant に、引数のない構成子だけの `data` を enum か variant に照合する。引数 2 個以上の構成子、型パラメータを持つ型、再帰する型は誤りとする。
- 論点 3.4: `Map` と `map<K, V>` は今回入れない。4 個以上の `tuple` と入れ子の `Unit` は誤りのまま。
- 論点 4.3（Q1 で (A) を採る場合）: resource を型に含む関数は、実行ごと・コンポーネントごとに一つの状態を持つインスタンスで呼ぶ。燃料・epoch・受け渡しの予算は呼び出しごとに設定し直し、線形メモリの上限はそのインスタンスの寿命の合計とする。
- 論点 4.4（同）: resource の型は `@external("wasm", "パス", "書き出しの名前#resource の名前") type 名前` で宣言し、関数は第 3 引数に `[static]`・`[method]` の plainname を書く。
- 論点 4.5: resource は 01-10 のリソースの型にせず、回収で管理する中身を見せない値にする。回収された handle は解放待ちの列に入れ、次にその状態を持つインスタンスへ入る前に解放する（回収の時期による非決定性の書き方は Q1 とあわせて決める）。明示の解放の関数は入れない。参照インタプリタとの差分テストから除く。
- 論点 4.6: `Regex.Match` に当たるものは resource にせず record にする。
- 論点 5.1: 速い経路は Wasmtime の型付きの呼び出しで作る。線形メモリへの直接の写しと、動的な型への `Lower` の実装は採らない（範囲は Q3）。
- 論点 6.1: 三つのコンポーネントと B を testdata に Fuzzy と同じ形で置き、測定のプログラムは `tools/bench/programs/` から `path` の依存で指す。Unofficial のモジュールは置き換えず、WASM の版を別のパッケージとして並べる。測定の入力は生成し、10 MB の入力をリポジトリに置かない。結果は `tools/bench/results/` に置き、要約を TODO-212 と TODO-097 に書く。
- 論点 6.2: Json の越え方 1 と 2 を作り、3 は Q1 の答えに従う。節点の表は B の試作の variant を基にし、子の数を `s64` にする。
- 論点 6.3: B は `parse`・`stringify`・`stringifyPretty` を A と同じ結果で書く。
- 論点 7: 測定の項目は表のとおり。10^10 を使い切る時間の目安は測定の後に設計者が決める。

## まだ確かめていない点

- 失敗しうるコンストラクタ（`constructor(...) -> result<R, E>`）と、戻り値の `borrow` を Wasmtime 49.0.2 と wit-bindgen 0.62.0 が扱えるか（B も試していない）。
- `map` を wit-bindgen 0.62.0 が出せるか。
- 関数の型の中の record から、型の書き出しの名前へ辿る API があるか（型の名前を照合しない推す案では要らない）。
- Gleam の `@internal` を他のパッケージから使ったときに誤りになるか。Kotlin の `internal` を識別子に使えるか。wasmtime-py のコンポーネントの API の関数の指し方。
