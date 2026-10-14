# V6・V7 の事前点検の補足

対象は plan.md の V6・V7 と、decisions.md の R4・R5・R7・R8・R10、reviews/preflight-V4V5.md の V5 への補足である。コードは `san_benito`（ba063822、V4 まで取り込み済み）で読んだ。試作のゲストは `scratchpad/pkg2/wasm/`（以下 `$W`）を読んだ。cargo は走らせていない。

共通の補足:

- 本補足でいう A は今の Unofficial の `@builtin`（`crates/benitoite/src/builtins/funcs/{hash,regex,json}.rs` と `src/prelude/stdlib/{Hash,Regex,Json}.bnt`）、B は Benitoite で書いた `Json`、C は WASM の版である。
- C の「同じ結果」は、A の Rust のコードをゲストに写して作るのが最も確かである。試作のゲストは serde_json と regex を素のまま使っているので、A と違う結果を返す箇所がある（「V6 への補足」の「ゲストの直し」）。A のコードは同じリポジトリの `MIT OR Apache-2.0` のコードなので、写してよい。写した箇所には、元のファイルと関数の名前をコメントで書く。
- ゲストの依存の版は、本体の `Cargo.lock` の版に揃える。`regex =1.13.1`（regex-automata 0.4.18、regex-syntax 0.8.11 は試作の lock と一致）、`serde_json =1.0.151` と機能 `float_roundtrip`、`serde_core =1.0.229`、zmij 1.0.23。試作の Json は serde_json 1.0.154 に解決しているので直す。理由: Regex の構文の誤りの文言と、Json の数の書式（serde_json 1.0.151 は zmij で書く）が版で変わりうる。
- **最も大きな危険は、debug のビルドでの Regex のコンパイルの時間である**（「オーケストレータへの報告」の 1）。plan.md の「約 0.5 秒」は release の測定（調査 B 6）である。フェーズ 1 の事前点検（`docs/archive/2026-10-13-…-phase1/reviews/preflight-W4W5.md` 423 行・550 行）は、Fuzzy で release 約 25 ms、debug 約 0.4 秒（約 15 倍）と記録した。同じ比なら Regex（926 KB）は debug で一回約 7 秒になる。ゴールデンの `run` のケース一件は、フォーマッタの性質の確かめで `check_files` を 2 回（`tests/golden/formatting.rs` 378〜379 行）、`Direct` と `Request` の二方式でそれぞれ検査と実行の 2 回、差分テストで 1 回以上コンパイルするので、Regex を使うケース一件で約 7 回、合計で約 50 秒になりうる（推測。測っていない）。V6a の最初に測る（「V6 への補足」の「ゴールデン」）。

## V6 への補足

### 作業の分け方

V6 は一つの作業として大きすぎる。次の三つに分けることを推す。

| 作業 | 内容 | 前提 |
|---|---|---|
| V6a | 三つのゲスト（Rust のソース・WIT・`.wasm`）、C のパッケージ三つ、A と C の同じ結果のゴールデン（Hash・Regex・Json の C） | V5 |
| V6b | B のパッケージ、A と B の同じ結果のゴールデン | V1 だけ（V5・V6a に依らない） |
| V6c | 測定のプログラム、入力の生成、`tools/bench/` の道具と README、A・B・C の三つを一度に比べるゴールデン（V6a・V6b の後でなければ書けないため） | V6a・V6b |

理由: V6b は WASM に触れない Benitoite のプログラムだけの作業で、合わせにくい点が多く（後述）、ほかと別に確かめたい。V6c は V6a・V6b の成果物の上に乗る。V6b を V5 より先に行ってもよい。

### ゲストの置き場所とパッケージの形

- 置き場所は Fuzzy と同じ `crates/benitoite/testdata/packages/libraries.files/` の下とする。`.files` で終わるディレクトリは、ゴールデンの実行器がケースとして探さない（`tests/golden.rs` 353 行）。ケースのディレクトリは `../libraries.files/<名前>` を `dependency` の `path` で指す（`fuzzy-run/main.bnt` の形）。`.files` の写しは行わないので、相対パスはソースの木のまま解決される。
- 推すディレクトリとパッケージの名前（A の `Json`・`Regex`・`Hash` と修飾の名前がぶつからないようにする）:

  | ディレクトリ | `package` の名前 | モジュール | 中身 |
  |---|---|---|---|
  | `wasm-hash/` | `WasmHash` | `Digest.bnt` | `sha256`（`Bytes`）、同じ WIT の関数を `List[Byte]` で宣言した版（動的な値の経路。測定で速い経路と比べる）、`sha256Hex` |
  | `wasm-regex/` | `WasmRegex` | `Pattern.bnt`（`public` の型と関数）、`Raw.bnt`（`public(package)` の `@external` の宣言） | resource の形と純粋な形 |
  | `wasm-json/` | `WasmJson` | `Codec.bnt`（`public` の関数）、`Nodes.bnt`（`public(package)` の `Node` と `@external` の宣言と組み直し） | 越え方 1・2・3 |
  | `pure-json/` | `PureJson` | `Parser.bnt`（`public` の `parse`・`stringify`・`stringifyPretty`）、`Scan.bnt` など（`public(package)` の補助） | B |

  名前は例であり、A・B・C を一つのプログラムで同時に `import` でき、修飾の名前が衝突しないことだけを求める。衝突するなら `import … as`（リファレンス 12 節）を使う。一つのパッケージに二つ以上のモジュールを置き、補助を `public(package)` にすると、V1 のパッケージの中の公開を、依存のパッケージの中のモジュールの間で確かめられる。
- 各パッケージは `package.bnt`（`language "0.0.3"`、`package` のブロック）を持ち、`.wasm` は根の直下の `wasm/` に置く（06-09 の 29 行、03-10「コンポーネントのパス」）。`rust/`・`wit/` は根の直下に置く。ハッシュはこれらを辿らない（06-09 の 78 行）。ゴールデンでは `hash` を書かない（Fuzzy と同じ）。理由: ゲストを作り直すたびにケースの記述を直すことになり、ハッシュの検査は既存のケースが確かめている。
- `package.bnt` の `license` は、ゲストのソースの使用許諾を書く。A のコードを写したゲストは `"MIT OR Apache-2.0"` とする（06-09 が `license` に許す書き方を確かめてから書く。書けなければ報告する）。
- パッケージの `.bnt` はゴールデンの実行器が整形の性質を確かめないので、`benitoite fmt --check` を手で通す。

### Rust のソース・ビルド・`.wasm`

- `rust/Cargo.toml` に空の `[workspace]` を書く（Fuzzy の形）。ルートのワークスペースは `members = ["crates/benitoite"]` だけなので、ゲストはメンバーにならず、`cargo build --workspace`・`cargo fmt --all`・`cargo clippy --workspace`・`cargo deny` の対象にならない。ルートの `Cargo.toml` の `exclude` は要らない。
- クレートの名前は依存と同じにしない（試作の `regex` は依存の `regex` と同名である）。例: `bnt-wasm-regex`。
- WIT は `wit/` に置き、`wit_bindgen::generate!` の `path` は `"../wit"` とする（Fuzzy の形）。
- ビルドは `CARGO_TARGET_DIR` をリポジトリの外（例: オーケストレータの作業場所）にして行う。ルートの `.gitignore` は `/target` だけを除くので、`rust/target/` を作ると未追跡のファイルが残る。終えたら `git status --porcelain` で生成物が残っていないことを確かめる。リポジトリの中で走らせると、ルートの `rust-toolchain.toml`（1.98.1）が使われる。1.98.1 の `wasm32-unknown-unknown` は入っている（確かめた）。
- `wasm-tools` は PATH にない。`/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/pkg/wasmtest/tools/bin/wasm-tools`（1.261.0。確かめた）を使う。
- **ホームディレクトリのパスを `.wasm` に埋め込まない。** 試作の `out/json.wasm` と `out/regex.wasm` は、panic の位置の文字列として `/Users/tecogonaz/.rustup/…`・`/Users/tecogonaz/.cargo/registry/…` を含む（`strings` で確かめた。`hash.wasm` と既存の `fuzzy.wasm` は `/rustc/<hash>/…` だけ）。公開のリポジトリに利用者の名前が入るので、`RUSTFLAGS` に `--remap-path-prefix=<CARGO_HOME>/registry/src=/cargo/registry/src`、`--remap-path-prefix=<RUSTUP_HOME>=/rustup`、`--remap-path-prefix=<ゲストのディレクトリ>=/build` を渡して作る。作った後に `strings <wasm> | grep -E '/Users|/home|/private'` が何も出さないことを確かめ、README の手順にもこの `RUSTFLAGS` を書く。
- 作り直して一致を確かめる仕組みは置かない。Fuzzy も置いていない（`testdata_components_match_their_text` は `.wat` の隣の `.wasm` だけを確かめる。`tests/golden.rs` 917 行〜）。テストからツールチェーンと wasm-tools を呼ぶことはできない。代わりに README に、Rust・wit-bindgen・wasm-tools の版、`RUSTFLAGS`、手順、`wasm-tools component wit` の出力（取り込みがないこと）、置いた `.wasm` の SHA-256 を書く。同じ機械で二度作って一致するかを確かめ、結果を README に書く（一致しなければその旨を書く。止める理由にはしない）。
- 大きさ: Regex は既定の機能・`opt-level = "s"`・LTO で約 926 KB になる（調査 B 5.1）。既定の機能のままにする（A と `\w` などの意味を揃える）。機能 `perf` を外すと意味は変えずに約 612 KB になるが、速さが変わり測定の意味が変わるので、debug のコンパイルの時間への対策（「オーケストレータへの報告」の 1）として設計者が選ぶ場合に限る。
- 使用許諾: ゲストの `Cargo.lock` は `cargo deny`（`scripts/check.sh` の `licenses`）の対象にならない（`classify` の `Cargo.lock` の行はルートの `Cargo.lock` だけに当たる。`crates/*` で `rust` の検査だけが選ばれる）。調べた範囲では、`.wasm` に入る依存の使用許諾は wit-bindgen（`Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT`）、sha2・regex・regex-syntax・serde_core・itoa（`MIT OR Apache-2.0`）、zmij（`MIT`）、memchr・aho-corasick（`Unlicense OR MIT`）で、どれも `deny.toml` の許す一覧の中にある。README に、`.wasm` に入る依存のクレートと使用許諾の一覧を書く（`cargo metadata --manifest-path rust/Cargo.toml --filter-platform wasm32-unknown-unknown` から作る）。MIT の著作権表示の扱い（`.wasm` を置くことが再配布に当たるか）は設計者に報告する（「オーケストレータへの報告」の 6）。

### ゲストの直し（試作の WIT と V2〜V5 の規則の食い違い）

共通:

- **`u32` を使えない。** 03-10「型の対応」の表に `u32` はない（R3 で幅の違う整数を入れなかった）。試作の Regex の `span { start: u32, end: u32 }`・`count -> u32`、Json の `parse-error { line: u32, column: u32 }`・`array(u32)`・`object(u32)`・`len -> option<u32>` を、すべて `s64` にする。
- インターフェースの名前は版を含めて完全一致なので、宣言の第 3 引数は `bnt:regex/re@0.1.0#[method]pattern.is-match` の形で、版まで書く。
- `_` を含む名前は使わない（R8）。WIT は `-` を使い、Benitoite の側は `-` を除いて大小を無視した名前にする（R3）。

Hash（`$W/guests/hash`）:

- WIT はそのままでよい（world の直下の `sha256: func(data: list<u8>) -> list<u8>` と `sha256-hex`）。`Bytes -> Bytes` と `Bytes -> String` は V4 の速い経路に当たる。world の直下を指す形は Fuzzy と同じで、インターフェースの形は Regex と Json が確かめる。
- 同じ `sha256` を `function sha256List(data: List[Byte]) -> List[Byte]` でも宣言すると、動的な値の経路で呼べる（03-10「型の対応」は `List[Byte]` と `Bytes` を区別し、`List[Byte]` は速い経路に入らない）。測定で二つの経路を比べるのに使う。新しいゲストの関数は要らない。
- sha2 の版は A（`=0.11.0`、`default-features = false`、`features = ["alloc"]`）に揃えてもよいが、結果は変わらない。

Regex（`$W/guests/regex`）:

- **`end` は Benitoite の予約語なので、欄の名前に使えない。** 試作の `record span { start, end }` に当たるレコードは Benitoite で書けない。`record found { text: string, byte-start: s64, byte-end: s64 }` にし、Benitoite の側は `record Found text: String byteStart: Integer byteEnd: Integer end record` とする（A の `matchText`・`matchByteStart`・`matchByteEnd` と比べられる）。型の名前を `Match` にすると A の `Regex.Match` と紛らわしいので避ける。
- R7 の範囲に合わせる。resource の形は `[static]pattern.compile: func(source: string) -> result<pattern, string>`、`[method]pattern.is-match`、`[method]pattern.find -> option<found>`、`[method]pattern.find-all -> list<found>`、`[method]pattern.replace-all(text, replacement) -> string`。純粋な形は `is-match-once(source, text) -> result<bool, string>` と `find-all-once(source, text) -> result<list<found>, string>`。試作の `count`・`count-once` は大きな入力の測定（結果のリストを返さない）に便利なので、残してよい（R7 の範囲の外の追加として README に書く）。
- `[static]` の `compile` が `result<own<pattern>, string>` を返す形は、V5 の補足（`DeclPlan::External` は `Result` の中に現れてよい）で受け付ける。Benitoite の宣言は `function compile(source: String) -> Result[Pattern, String] uses State`。
- **A と同じ結果にするための直し**（A は `src/builtins/funcs/regex.rs`）:
  - `RegexBuilder::new(source).build()` を既定の設定のまま使う。試作の `.size_limit(10 << 20)` を除く。
  - 構文の誤りの文言は、A の `compile_error`（4096 バイトを超えたら最後の行だけを残して切り詰める）を写す。
  - **`replace-all` の置換の文字列を展開しない。** 試作は `replace_all(&text, replacement.as_str())` で、`$1` などを展開する。A は `NoExpand` で文字どおりに置き換える（`regex.rs` 251 行）。`regex::NoExpand(&replacement)` を使う。
  - `find-all` は A の `findAll`（`Regex.bnt` の `findAllFrom` と `Regex.findAt` の `retry_start`。直前の一致の終わりと重なる空の一致を捨て、次の文字の境目から探す）と同じ手順で書く。`find_iter` でも同じ結果になると見込むが、確かめていないので、A の手順を写すほうを推す。`replace-all` も同じ手順で一致を数える。

Json（`$W/guests/json`）:

- `parse-error` は `record parse-error { line: s64, column: s64, message: string }` とし、Benitoite の宣言では標準ライブラリの `Json.ParseError` をそのまま使う（R8。欄の順も `line`・`column`・`message` で一致する）。`validate` は `result<_, parse-error>` で、`Result[Unit, Json.ParseError]` に照合する。
- 節点は `variant node { null, boolean(bool), integer(s64), float(f64), text(string), array(s64), object(s64), key(string) }`。`string` は WIT の予約語なので `text` のままにし、Benitoite の `public(package) data Node` の構成子は `Text(String)` とする。再帰せず、構成子の引数は 0 個か 1 個なので R3 に合う。
- 越え方 2 で A の三つの関数と比べられるよう、`stringify-pretty: func(nodes: list<node>) -> result<string, string>` を足す。
- 越え方 3 は `resource document { parse: static func(text: string) -> result<document, parse-error>; get: func(pointer: string) -> option<string>; len: func(pointer: string) -> option<s64>; }`。Benitoite の宣言はどれも `uses State`。
- **A と同じ結果にするための直し**（A は `src/builtins/funcs/json.rs`）: 試作は serde_json の `Value` と `IgnoredAny` を使うので、少なくとも次が A と違う。A の `parse`（`NumberLexemes`・`NumberState`・誤りの位置の付け替え・`character_column`・`JsonMaterial`）と `write_json`（`quoted`・数の書式・整形）をゲストに写し、三つの越え方のすべてがこの材料の木を通るようにする。
  - 誤りの文言に serde の ` at line X column Y` の接尾辞が残る。列が文字でなくバイトで数えられる。入力の終わり・数の範囲外の誤りの位置が A と違う。
  - `validate` が `IgnoredAny` を使うので、入れ子の深さの上限（serde の既定の 128）が効かない（調査 B 5.3 で 10 万段を正しいと答えた）。A は `recursion limit exceeded` を返す。
  - 数の分類（A は字面で分類し、`-0` は `Integer(0)`、`-0.0`・`-0e3` は `Float(-0.0)`、`i64` を超える整数は `Float`）が serde の `Value` と違いうる。
  - 鍵の重複は A と同じく後の値を残す（A は `BTreeMap::insert`）。
  - `stringify` の NaN と無限大を、試作は誤りにし、A は `null` と書く。
  - `document` の `get` は、材料の木を JSON Pointer（RFC 6901。`~0`・`~1`、配列の添字）で辿り、A の `write_json` と同じ書式で返す。serde_json の `Value::pointer` に頼らない。
- ゲストの中で深い入れ子を辿る処理は、試作の `flatten`・`rebuild` と同じく明示の積み重ねで書く（ゲストの Wasm のスタックの上限は 512 KiB）。

### Benitoite の側の宣言の形（例）

```text
// WasmRegex/Pattern.bnt
@external("wasm", "wasm/regex.wasm", "bnt:regex/re@0.1.0#pattern")
public type Pattern

@external("wasm", "wasm/regex.wasm", "bnt:regex/re@0.1.0#[static]pattern.compile")
public function compile(source: String) -> Result[Pattern, String] uses State

@external("wasm", "wasm/regex.wasm", "bnt:regex/re@0.1.0#[method]pattern.find-all")
public function findAll(pattern: Pattern, text: String) -> List[Found] uses State

@external("wasm", "wasm/regex.wasm", "bnt:regex/re@0.1.0#find-all-once")
public function findAllOnce(source: String, text: String) -> Result[List[Found], String]
```

外部の型の宣言の第 3 引数の書き方（`インターフェース#resource の名前`）は R4 のとおりである。V5 の実装で形が変わったら、それに従う。外部の型の値は等値の型でなく `Show` も持たないので、ゴールデンでは値そのものを出力しない。

### Json の B（V6b）

- B は `Benitoite.Unofficial.Json` の `Value` と `ParseError` を型として使い、`Result[Json.Value, Json.ParseError]` を返す。A と同じ型なので、`=` でそのまま比べられる。`get`・`at`・`as*` は書かない（調査 C 6.3）。
- 書ける見込み: 標準ライブラリに要るものは揃っている。入力は `String.toUTF8` で一度 `Bytes` にし、`Bytes.get` でバイトごとに読む（`String.characterAt` は文字の位置で引くので、長い入力で遅くなりうる。避ける）。文字列の中身は、エスケープがなければ `String.byteSlice` で一度に切り出し、あれば部分のリストを `String.join` する。`\uXXXX` は `Character.fromInteger` と `Character.toString`、サロゲートの対は自分で組む。数は字面を `String.byteSlice` で切り出し、A と同じく、`.`・`e`・`E` を含まなければ `Integer.parse`、失敗するか含めば `Float.parse`（`None` なら範囲外）とする。`Float.parse` は Rust の `f64` の解析（`decimal_float` で形を確かめた後）なので、A の `number_value` と同じ値になる。オブジェクトは `Map.set` で作る（後の重複が残る）。
- 再帰: 解析は再帰で書いてよい（入れ子は 128 段で止まる）。配列とオブジェクトの要素の並びは末尾呼び出しか `List.fold` で書く。`stringify` は利用者が作った深い値（A のテストは 1,000 段）を受け取るので、A の `write_json` と同じく作業のリストで書き、言語の呼び出しの深さの上限（R0901。`testdata/eval/call_stack_limit.bnt`）に当たらないようにする。
- 出力の文字列は部分のリストに積んで最後に `String.join` する。リストは 2^24 要素が上限なので、`Regex.bnt` の `appendPart`（4096 部分ごとに結合）と同じ形で積む。
- **合わせにくい点**（推す扱いを各項に書く）:
  1. 構文の誤りの位置。A は serde_json の誤りの位置（最後に読んだか覗いたバイトの行とバイトの列）を、`character_column` で文字の列に直し、数の誤りは字面の始まり、入力の終わりの誤りは最後の文字の直後に付け替える。`\r` は改行に数えない。推す扱い: serde_json 1.0.151 の `src/de.rs`・`src/read.rs`（`~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/serde_json-1.0.151/`。手元にある）の状態の遷移と位置の取り方（`peek_error` と `error` の区別）をそのまま写し、誤りのときだけバイトの位置から行と文字の列を数える補助の関数を通す。
  2. 誤りの文言。serde_json の `ErrorCode` の表示（同 `src/error.rs`。`expected value`・`expected ident`・`expected `,` or `]``・`expected `:``・`key must be a string`・`trailing comma`・`trailing characters`・`EOF while parsing a list` などの `EOF while parsing …`・`control character (\u0000-\u001F) found while parsing a string`・`invalid escape`・`invalid unicode code point`・`lone leading surrogate in hex escape`・`unexpected end of hex escape`・`invalid number`・`number out of range`・`recursion limit exceeded`）を `text` の定数として写す。
  3. 入れ子の深さの上限 128 と、その誤りの位置。A のテスト `parser_depth_boundary_and_iterative_writing_of_deep_values` の境界をゴールデンに含める。
  4. 浮動小数点数の書式。A は `serde_json::Number::from_f64(n).to_string()`（zmij）で書き、`1e+300`・`9.223372036854776e+18`・`5e-324`・`100.0`・`-0.0025` になる（`json.rs` のテスト）。Benitoite の `Float.toString` は指数が -5 以上 21 未満で十進の表記、それ以外は `1.0e+21` の形（`src/base/prim.rs` の `float_to_text`）で、A と違う。推す扱い: `Float.toString` から最短の数字の並びと指数を取り出し、zmij の切り替えの規則（zmij 1.0.23 のソースで確かめる）で組み直す。境界の値（`1e15`・`1e16`・`1e17`・`1e-5`・`1e-6`・`5e-324`・`1.7976931348623157e308`・`-0.0`）を A と比べるゴールデンの行に入れる。
  5. 文字列のエスケープの書き方。A の `quoted` に合わせる（`\b`・`\f`・`\n`・`\r`・`\t`、ほかの制御文字は小文字の `\u00XX`、`/` と U+007F はそのまま）。
  6. 速さ。B は 1 バイトごとに言語の関数を呼ぶので、A より大幅に遅い。10 MB は測定のプログラムでだけ使い、ゴールデンの入力は数 KB 以下にする。V6b の報告に、release のビルドで 100 KB の `parse` の時間を一度測って書き、10 MB の見込みを示す（線形なら約 100 倍）。差分テスト（参照インタプリタ）と gc-stress の構成でも、B のゴールデンが 10 秒の内に終わることを確かめる。
- 目標と報告: 正しい入力では、`Json.Value` の等しさと、`stringify`・`stringifyPretty` の出力のバイト列の一致を必ず満たす。誤りの入力では、`json.rs` の単体テストの表（`parse_errors_report_character_columns_and_separate_reasons` の 34 件と深さの境界）と、上の 2 の文言の種類ごとに一件以上を A と一致させる。一致させられない入力は、ゴールデンの出力に「known difference」として A と B の両方を示し、報告に挙げる（A が 03-08「Json」に合わない側なら、A を直さずに報告する。docs/todo の項目はオーケストレータが加える）。

### 同じ結果の確かめ（ゴールデン）

- 置き方: `testdata/packages/` の下のディレクトリのケース（`<名前>/main.bnt` と `<名前>.mode`・`.stdout`・`.exit`）。`.mode` は `run`。名前に作業の ID を付けない。推す四件:

  | ケース | 作業 | 中身 | コンパイルするコンポーネント |
  |---|---|---|---|
  | `wasm-hash-same` | V6a | A と C（`Bytes` の速い経路と `List[Byte]` の動的な値の経路、`sha256Hex` と `Bytes.toHex`）。空・短い・非 ASCII・1 MiB 程度の入力 | Hash（22 KB） |
  | `wasm-regex-same` | V6a | A と C の resource の形と純粋な形。`compile` の誤りの文言、`isMatch`、`find`（文字列と位置）、`findAll`（空の一致を含むパターン `a*`・`\b`・空のパターンと非 ASCII の入力）、`replaceAll`（`$1` を含む置換の文字列）。resource の形の一件で、同じ値を二度使う呼び出しも含める | Regex（926 KB）。**この一件だけにする** |
  | `json-pure-same` | V6b | A と B。l40-json の入力、`json.rs` の単体テストの表（正しい入力と誤りの入力）、深さの境界、浮動小数点数の境界 | なし |
  | `json-wasm-same` | V6c | A・B・C。越え方 1（`validate`・`pretty`・`minify` と A の `parse`・`stringifyPretty`・`stringify`）、越え方 2（`parse` の組み直しと `stringify`・`stringifyPretty`）、越え方 3（`document` の `get`・`len` と A の `Json.get`・`Json.at` で辿った値の `stringify`）。正しい入力と誤りの入力の代表 | Json（81 KB） |

  `json-wasm-same` で B も比べるので V6c に置く。V6a で C だけを確かめたいなら、V6a に `json-wasm-same` の A と C の部分を置き、V6c で B の列を足す。
- 出力の形: 入力ごとに一行、A の結果（`stringify` の出力か `ParseError` の三つの欄）と、B・C が A と同じかを書く（例: `ok  [1,2]` と、違えば `diff  A=…  C=…`）。期待値のファイルが A の結果の一覧を兼ねるので、比較の漏れを読み手が確かめられる。`-0.0` と `0.0` は `=` で等しくなりうるので、`=` と `stringify` の出力の両方で比べる。
- **時間を最初に測る。** V6a の最初に、`wasm-regex-same` の `isMatch` 一回だけの版を作り、`time BENITOITE_GOLDEN_FILTER=packages/wasm-regex-same cargo test -p benitoite --test golden` で debug の所要時間を測る。10 秒を超えたら、作業を止めて時間を報告する（対策の選択はオーケストレータと設計者が行う。「オーケストレータへの報告」の 1）。Json の C（約 81 KB）は debug で一回 1 秒前後と見込むが、`json-wasm-same` でも同じく測って報告に書く。
- 参照インタプリタ: resource を受け渡す呼び出しに当たると `Unsupported` で差分テストから外れる（V5 の補足）。`wasm-regex-same` と `json-wasm-same` は外れる見込みである。外れることは期待どおりなので、`EXPENSIVE_REFERENCE_CASES` などに加えない。
- gc-stress: `BENITOITE_GOLDEN_FILTER=packages/ cargo test -p benitoite --no-default-features --features gc-mark-sweep,gc-stress --test golden` でも結果が同じで、時間が上限の内であることを確かめる。
- 材料: `testdata/stdlib/l40-json.bnt` の入力、`src/builtins/funcs/json.rs` の単体テストの表（入力と期待する行・列・文言がそろっている）、`testdata/acceptance/json_summary.files/orders.json`。バックスラッシュと二重引用符の多い入力は、ケースの `.files` に置いて `File.readText` で読むと書きやすい（`uses File.Read` を足す）。

### 測定のプログラム（V6c）

- 置き場所: `tools/bench/wasm/`（Benitoite のプログラム）と、`tools/bench/wasm_bench.py`（入力の生成、結果の一致の確かめ、測定の実行を一つにまとめた道具）。理由: `run.py` は名前の表（`NAMES` など）に載せたプログラムだけを測る（`run.py` 32〜35 行）。ゴールデンの実行器は `tools/bench/programs/` の直下の `.bnt` のうち `.args.small` があるものを実行する（`tests/golden.rs` 34 行・191〜206 行）。`tools/bench/wasm/` に置けばどちらにも入らない。`scripts/check.sh` の `python` の検査は `tools/bench/*.py` の構文を確かめる（202 行）ので、Python の道具は `tools/bench/` の直下に置く（`tools/bench/wasm/` の下の `.py` は確かめられない）。
- プログラムは、パッケージを `dependency` の `path "../../../crates/benitoite/testdata/packages/libraries.files/wasm-json"` の形で指す（依存の根は根の外を指してよい。06-09 の 61 行）。
- 入力の生成: `wasm_bench.py gen-json --bytes N --seed S <出力>` の形で、決まった種から 1 KB・100 KB・10 MB の JSON を作り、リポジトリの外（一時ディレクトリ）に書く。中身は、レコードの並び（鍵が数個のオブジェクト、整数・小数・真偽値・`null`、エスケープと非 ASCII を含む文字列、入れ子の配列）にする。**数ばかりの入力にしない。** 越え方 2 の節点の表は、節点一つにつき `Val` 2 個分（80 バイト）と場合の名前と文字列のバイトを受け渡しの予算で数えるので、`[1,2,3,…]` のような 10 MB（約 500 万節点）は 256 MiB の予算を超える（推測）。調査 B の 10 MB の入力は約 219 万節点で予算に収まった。生成した入力の節点の数を道具が表示し、10 MB の C の越え方 2 が R0905 になったらそれも結果として記録する。
- 課題（TODO-212。調査 C 6.4）:
  - Json: 解析して全部作る（A `parse`、B `parse`、C 越え方 2 の `parse` と組み直し）、文字列に書く（A・B の `stringify`、C は Benitoite で節点の表に平らにしてから `stringify`）、解析して数か所を読む（A・B は `parse` と `get`・`at`、C は越え方 3 の `document`）、整形と検証（A・B は `stringifyPretty(parse)` と `parse` の成否、C は越え方 1）。入力は 1 KB・100 KB・10 MB。C は、初回（検査と最初の呼び出しのコンパイルを含む）と 2 回目以降を分ける。Benitoite の `Clock` は単調なミリ秒を返す（`IO/Clock.bnt`）ので、プログラムの中で k 回繰り返して最初の一回と残りを分けて出力し、プロセス全体の時間は道具が測る。
  - **越え方 3 の 10 MB を一つの実行の中で繰り返すと、状態を持つインスタンスの線形メモリ（寿命の合計で 64 MiB。R5）に当たりうる。** 前の `document` が回収されて片付けられる前に次を作るためである。10 MB の `document` は一実行に一つにするか、R0905 になったらその旨を記録する。
  - Hash: A と C（速い経路と `List[Byte]` の動的な値の経路）を 1 KB・1 MB・6 MB（動的な値の経路の予算 256 MiB ÷ 40 の手前）・32 MiB（速い経路だけ）で。**調査 C 6.4 の 100 MB は測れない。** ゲストの線形メモリの上限 64 MiB に、引数の写しだけで達するためである。
  - Regex: A、C の resource の形、C の純粋な形で、同じパターンを 1 回・1,000 回照合する。大きな入力（数 MB）の `count` も測る。
- 課題（TODO-232。調査 C 7）と測り方。Benitoite のプログラムからは燃料の消費量を読めず、合成したコンポーネントも作れないので、**Rust の例（`crates/benitoite/examples/wasm_cost.rs`）を一つ足す**ことを推す。例は `benitoite::external::engine_config()`（公開。`src/external/mod.rs` 182 行）と依存の `wasmtime`、開発用の依存の `wat`（`=1.261.0`）を使えるので、依存のクレートは増えない。`bench_run.rs`・`verify_bench.rs` が前例である。
  - 呼び出し一回の費用: 例で、空に近い関数（`func() -> s64` と `func(s64) -> s64`）を 10^4 回呼び、インスタンスの作成、型付きの呼び出し、`Val` の呼び出し、状態を持つインスタンスでの呼び出しを分けて測る。Benitoite の側の費用は、`tools/bench/wasm/` のプログラムで C の `sha256(Bytes.empty())` と A の `Hash.sha256(Bytes.empty())` を N 回呼んだ差で見る。
  - 燃料の単位あたりの時間と、10^10 を使い切る時間: 例で、`wat` で作った無限ループのコンポーネントを燃料 10^10 で `OutOfFuel` まで回した時間を測る。単位あたりの時間はこの時間 ÷ 10^10 とする。Fuzzy の距離（100〜3,000 文字）の燃料（`Store::get_fuel`）と時間の比も取る（02-09 の 351 行の測り方）。
  - コンポーネントの大きさごとのコンパイルの費用: 例で、`Component::from_binary` の時間を、Hash・Json・Regex・Fuzzy と、関数の数を増やして `wat` で合成したコンポーネント（1・4・16・64 MiB。256 MiB は時間とメモリが大きいので明示の指定のときだけ）について測る。データの区画だけが大きいものも一つ作り、コードの大きさと分ける。最大 RSS は、大きさごとに例を別のプロセスで起動し、道具が `tools/bench/rss.py` と同じ方法で取る。
  - 例は処理系のコードではないが、ワークスペースの lint（`unwrap_used` など）は例にも当たる（`#[allow]` の表に例はない）。`main` から `Result` を返す形で書く。
- `wasm_bench.py` は `--quick`（小さな入力と少ない回数で、道具が動くことと結果の一致だけを確かめる）を持つ。V6c では `--quick` だけを走らせ、本測定はしない（V8。スキル `benchmark` の「本測定を行わず道具を確かめる」に倣う）。測る前に、A・B・C が生成した入力に同じ結果を返すことを道具が確かめる（`stringify` の出力のハッシュを比べる）。
- `tools/bench/README.md` に「WASM の比較（docs/todo の TODO-212・TODO-232）」の節を足し、入力の生成、`--quick`、本測定の手順、例の使い方、測れない大きさ（Hash の 100 MB、越え方 2 の数ばかりの 10 MB）を書く。スキル `benchmark` には、その節を指す一行を足すかをオーケストレータが決める。

### 設計書

- plan.md のとおり、V6 で設計書を変える箇所はない見込みである。B が A と食い違う入力を見つけても、03-08 と A を直さずに報告する。

## V7 への補足

V5 が直すと決めた箇所（V5 の補足の「設計書」）の後に、次を通読して直す。V7 の時点の `san_benito` で、V1〜V6 の実装と照らし合わせる。

### 00-04 用語集

- 「外部の関数」（160 行）: 「純粋な関数として型が付く」を、外部の型を型に含む関数は `uses State` を持つことに合わせて直す。
- 「world」（163 行）: 「`@external` は world の直下に書き出した関数を指す」は V2 の後の実装と合わない（V2 の直し漏れ）。インターフェースの中の関数も `インターフェース#関数` で指せることに直す。
- 「公開」（186 行）: `public(package)` と三つの段階が書かれていない（V1 の直し漏れ）。段階と範囲（同じパッケージ、根の側全体を一つのパッケージとみなす）を書く。
- 「中身を見せない prelude の型」（206 行）と「リソース」（242 行）: 外部の型との関係を一文で示す（外部の型は中身を見せず等値の型でないが、prelude の型でも 01-10 のリソースの型でもない）。
- 加える項目（memory の「術語は初出で原語を添え、00-04 に定義を加える」）: 外部の型（external type。R10）、公開の段階・パッケージの中だけの公開（`public(package)`）、インターフェースの書き出し（exported interface）、状態を持つインスタンス、解放待ちの列、速い経路（typed fast path）、受け渡しの予算（value-transfer budget。V3・V4 で使い始めたが項目がない）。各項目の参照先は 03-10・01-03・02-09 の節にする。

### 07-01 と 00-03

- 07-01 の保証の表の「外部の関数」の行（53 行）: V5 で直す予定だが、次を確かめる。外部の型を型に含む関数は `State` を持つこと、保証しないことの欄に「外部の型を使う関数の結果は、ゲストが共有の状態を持つ場合、回収の時期に依存しうる」（R5）と「状態を持つインスタンスの線形メモリの上限は寿命の合計である」を加えること。
- 07-01 の 79 行（取り込みがないので IO 実行器を通らない経路にならない）は V5 の後も成り立つ。そのままでよい。
- 00-03 の 36 行「外部の関数は … 純粋な関数として型が付く」と 63 行（加えた機能の一覧）を、外部の型と `public(package)` に合わせて直す。00-03 を変えたら `spec_coverage` の検査が選ばれる（`check.sh` の `classify`）。

### 03-10 の通読

- 「目的と範囲」: 外部の関数だけを書いている。外部の型の宣言・照合・解放を加える。
- 「前提」: 純粋な関数の規則だけを挙げている。01-07「外部の関数のエフェクト」（`State`）を加える。
- 「宣言の形」: 「`uses` … は書けない」を、`uses State` だけを書けることに直す（V5）。外部の型の宣言（右辺のない `type`）の例を加える。
- 「照合」の 1〜4: resource の書き出しの照合と、`borrow`・`own` の照合を加える（V5）。E1012・E0816 を 02-10 の表と合わせる。
- 「型の対応」の表: 外部の型の行（引数は `borrow<R>`、戻り値は `own<R>`）を加える。「関数、`Decimal`・`Map`・`Set`・リソース・`Task` など、表にない型は誤り」の「リソース」は 01-10 のリソースの型を指すことが分かるようにする。
- 「作り方の例」: V6 で決めた `RUSTFLAGS` の `--remap-path-prefix` と `CARGO_TARGET_DIR` を加えるかを決める（加えるなら出典を添える）。「試験用の Fuzzy は …」の文に、検証のための Hash・Regex・Json のパッケージを加える。
- 「実行」の最初の【決定】:「コンポーネントの状態は呼び出しごとに作り直す」と理由「同じ引数の結果が以前の呼び出しの状態に依存せず」は、外部の型を型に含む関数では成り立たない。R5 の範囲に限る書き方に直す（V5 で直していれば確かめるだけ）。燃料と線形メモリの上限の文の「呼び出し全体の合計 64 MiB」も、状態を持つインスタンスでは寿命の合計であることと合わせる。
- 02-08「外部の関数の実行系」、02-09「外部の関数の実行」、01-07「外部の関数のエフェクト」、01-02 の宣言の構文、02-04 の束縛の種類の表、02-05 の型構成子の一覧、07-04 の対象外の表（148・150 行。外部の型も対象外に入るか）と、03-10 の用語と数値が一致することを確かめる。

### 言語リファレンス

- 12 節（549 行〜）: 「a newline before `(` is not accepted」は R9（`public` と `(package)` の間の改行を許す）と食い違う。Z1 が R9 を実装したなら直す（Z1 で直していれば確かめるだけ）。`public(package)` の後の改行は誤りのままであることを一文で書く（R9）。
- 21 節: 見出し「Pure external functions through WASM」（1021 行）を、外部の型を扱えるように「External functions through WASM」などに改め、外部の型の小節を加える。この見出しへのリンクは、調べた範囲では改造のディレクトリの調査 A の文だけにある。直す文: 「It cannot have … `uses`: only pure functions are accepted」、「Functions, `Decimal`, `Map`, `Set`, resources, and tasks cannot cross this boundary」（外部の型を除き、ここでの resources は 15 節のリソースであることを明確にする）、「External calls run synchronously, with fresh component instances on every call」、線形メモリの上限の説明。外部の型の例は今の 21 節と同じく `text` のブロックにする（1026 行のコメントの前例）。
- 254 行付近の等値の型の説明に、外部の型が等値の型でないことを加える（V5 の補足のとおり。V5 で直していれば確かめるだけ）。
- 例を変えたら `cargo test -p benitoite --test reference_examples` を走らせる。

### CHANGELOG の Unreleased

- V4 の項目（「Use typed Wasmtime calls …」）が、「Packages and external functions are experimental …」の段落より前、`### Added` の先頭に置かれている。実験的な機能の段落の下に移す。
- Unreleased はまだ公開していないので、フェーズ 1 の項目を最終の状態に合わせて書き直す。直す項目: 「Add `@external(…)` declarations for pure WebAssembly Component Model functions. Check … top-level exports …」（インターフェースの中の関数と外部の型を含めた状態にする）、「Execute external calls synchronously with fresh instances … a 64 MiB total linear-memory limit per call …」（状態を持つインスタンスでは寿命の合計であること）。V2〜V5 の項目と重なる文は一つにまとめる。
- V6 の検証のパッケージと測定の道具は利用者から見える変更ではないので、CHANGELOG に書かない。
- `docs/ja/` の訳はリリースのときに作り直す決まりなので、V7 では触れない。

## 作業の間の依存

- Z1 → V5 → V6a → V6c の順は動かせない。V6a の Regex の resource の形と Json の越え方 3 は、V5 の外部の型を要する。V6a のパッケージのモジュールは一つのファイルに resource の宣言と純粋な宣言を含むので、V5 の前には検査を通らない。
- V6b は V1（`public(package)`）だけに依る。Z1 の後ならいつ行ってもよい。V5 のレビューの間に V6b を進めると、直列のまま待ちを減らせる。
- V6c は V6a と V6b の成果物（パッケージと B）を使う。三つを比べる `json-wasm-same` は V6c に置く。
- V7 は V5 の後に行える。V6 の結果（B と A の食い違い、測れない大きさ）を 03-10 や用語集に書くことはない見込みなので、V6 と V7 の順は入れ替えてよい。ただし CHANGELOG と 21 節は V5 の変更を前提にする。
- V8 の測定（TODO-212・232）は V6c の道具を使う。測定の前に、`wasm_bench.py --quick` と結果の一致の確かめを release のビルドで一度通す。

## オーケストレータへの報告

1. **debug のビルドでの Regex のコンパイルの時間が、10 秒の上限を超えうる。** plan.md の「約 0.5 秒」は release の値で、フェーズ 1 の記録（Fuzzy で debug は release の約 15 倍）から、Regex（926 KB）は debug で一回約 7 秒と見込む。ゴールデンの `run` のケースは、整形の性質の確かめ（`check_files` 2 回）・二方式の検査と実行（4 回）・差分テストでコンパイルを繰り返すので、Regex のケース一件で約 50 秒になりうる（推測）。補足では、V6a の最初に一件だけで測り、10 秒を超えたら止めて報告するよう指示した。対策の候補: (a) ワークスペースの `Cargo.toml` に `[profile.dev.package.cranelift-codegen]` などの `opt-level` を足す（フェーズ 1 の事前点検も「測ってから設計者に相談する」とした。全体のビルドの時間に関わり、`check.sh` の `licenses`・`rust` が選ばれる）、(b) Regex の C のゴールデンを置かず、同じ結果の確かめを `wasm_bench.py` の確かめ（release）だけで行う（R7 の「ゴールデンテストで確かめる」から外れる）、(c) Regex のゲストから機能 `perf` を外す（意味は変わらないが約 34% 小さくなるだけで、足りない見込み。測定の意味も変わる）。設計者の判断が要る。
2. 試作の WIT は V2〜V5 の規則に合わない点がある。`u32`（型の対応にない）を `s64` に、Regex の欄の名前 `end`（Benitoite の予約語）を `byte-start`・`byte-end` に直し、Regex の関数を R7 の範囲（`find-all` と純粋な `find-all-once`）に合わせる。
3. 試作のゲストは A と違う結果を返す。Regex の `replace-all` が置換の文字列の `$1` を展開する（A は文字どおり）、`size_limit` を変えている、誤りの文言を切り詰めない。Json は誤りの位置と文言、入れ子の深さの上限（`IgnoredAny` で効かない）、数の分類、NaN の書き方が違う。補足では、A の Rust のコードをゲストに写し、依存の版を本体の `Cargo.lock`（serde_json 1.0.151 と `float_roundtrip`、regex 1.13.1）に揃えるよう指示した。
4. **試作の `json.wasm` と `regex.wasm` は `/Users/tecogonaz/…` のパスを含む。** 公開のリポジトリに置く前に、`--remap-path-prefix` で作り直し、`strings` で確かめるよう指示した。
5. 作業の分割を推す: V6a（ゲストと C のパッケージと A・C のゴールデン）、V6b（B と A・B のゴールデン。V1 だけに依る）、V6c（測定のプログラム・道具・Rust の例と、A・B・C のゴールデン）。
6. ゲストの `.wasm` には、MIT（zmij）、`Unlicense OR MIT`（memchr・aho-corasick）などのクレートのコードが入る。どれも `deny.toml` の許す一覧の中だが、`cargo deny` の対象にならず、リリースの第三者の使用許諾の一覧にも載らない。README に一覧を書くよう指示した。`.wasm` を置くことに対する著作権表示の扱いは設計者に確かめたい。
7. B は書ける見込みだが、A の誤りの位置と文言（serde_json の内部の位置の取り方を写す要がある）と、浮動小数点数の書式（A は zmij の書式で `1e+300` などと書き、Benitoite の `Float.toString` と違う）が合わせにくい。正しい入力は完全な一致を求め、誤りの入力は A の単体テストの表と文言の種類ごとの一致を目標にし、残りは「known difference」として報告させる。
8. 調査 C 6.4 の「Hash の 100 MB」は、ゲストの線形メモリの上限 64 MiB に当たるので測れない。32 MiB に改めた。数ばかりの 10 MB の JSON は越え方 2 の受け渡しの予算を超えうるので、入力の生成で避け、超えた場合は結果として記録させる。
9. TODO-232 の燃料と合成したコンポーネントのコンパイルは、Benitoite のプログラムからは測れない。`crates/benitoite/examples/wasm_cost.rs` を足す案を推した（依存は増えない）。例をクレートに足すことに異論があれば、`tools/bench/programs/rust/` と同じく別の Cargo のプロジェクトにする案もある。
10. V7 で、V1・V2 の直し漏れを見つけた。00-04 の「world」（`@external` は world の直下を指す）と「公開」（`public(package)` がない）、受け渡しの予算の項目がない。CHANGELOG では V4 の項目が実験的な機能の段落の前に置かれ、フェーズ 1 の項目（「pure」「top-level exports」「fresh instances」）が最終の状態と合わない。リファレンス 12 節の「a newline before `(` is not accepted」は R9 と食い違う（Z1 で直す対象か確かめたい）。
