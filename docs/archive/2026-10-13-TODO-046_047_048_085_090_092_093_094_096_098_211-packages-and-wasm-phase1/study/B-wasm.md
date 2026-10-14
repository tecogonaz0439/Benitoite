# 調査 B: WASM のコンポーネントを Rust のホストから呼ぶ（フェーズ 1 の純粋な関数）

調査日: 2026-10-12〜13。対象: メモ `docs/todo/sources/2026-10-11-package-wasm/memo.md` の 2.5・4・5.1 と、例 `package-samples/proposed/packages/fuzzy/`。

外部の事実には URL を添えた。一次資料で確かめられなかったものは「未確認」と書いた。「試した」と書いたものは、次の作業用のディレクトリで実際にビルドと実行をした結果である。

- 作業用のディレクトリ: `/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/pkg/wasmtest/`
  - `fuzzy/`: 例の Fuzzy のクレート。`lib.rs` と `fuzzy.wit` は例のまま写した（`path` だけを `"wit"` に変えた）。
  - `host/`: 試しのホスト（`src/main.rs` と `src/bin/slice.rs`）。
  - `sizes.txt`: 大きさの記録。`build-*.log`: ビルドの記録。
- 環境: macOS（aarch64-apple-darwin）、Rust 1.98.1（`cargo +1.98.1`）。wasmtime 49.0.2、wit-bindgen 0.62.0、wasm-tools 1.261.0 を使った（wasm-tools は作業用のディレクトリの `tools/` に入れた）。
- 全体への影響: `rustup target add wasm32-unknown-unknown wasm32-wasip2` で、ツールチェーン 1.98.1 に二つの対象を加えた。リポジトリは変えていない。

## 要約

- **推す実行系は Wasmtime。** Rust のホストからコンポーネントを呼べる実行系のうち、一次資料で対応を確かめられたのは Wasmtime だけだった。wasmi はコンポーネントに未対応で、Wasmer は対応を確かめられなかった。最新版は 49.0.2 で、MSRV は 1.96 である。Rust 1.98.1 でビルドできることを試して確かめた。ライセンスは `Apache-2.0 WITH LLVM-exception` である。
- **型が実行時に決まる関数も呼べる。** `Component::component_type()` で取り込み（imports）と書き出し（exports）の型を列挙できる。これで「取り込みが空」と「`distance: func(string, string) -> s64`」の二つを確かめ、`Func::call(&mut store, &[Val], &mut [Val])` で呼べた（試した）。
- **大きさの増分は構成で大きく変わる。** strip した実行ファイルで比べた。最小の構成（`runtime` + `component-model`、コンパイラなし）は約 1.1 MB 増える。Cranelift を足すと約 9.8 MB 増え、既定の機能をすべて入れると約 13.7 MB 増える。いまの Benitoite の実行ファイルは 12.1 MB（strip していない）である。依存のライセンスはすべて許容型だった。
- **純粋性の判定には `wasm32-unknown-unknown` を使う。** `wasm32-unknown-unknown` + `wasm-tools component new` は adapter なしで包めて、取り込みは 0 個になった（試した）。`wasm32-wasip2` は、`panic = "abort"` でも `wasi:cli/*`・`wasi:io/*`・`wasi:clocks/*` の 14 個を取り込んだ（試した）。このため、メモ 2.5 の案（unknown-unknown を推す）は正しい。
- **実行の区切り方。** fuel か epoch を使い、`async` の機能で `call_async` の Future を手で poll すると、実行の途中で制御を VM に戻せた（試した）。区切りのたびに、VM はタスクを切り替えたり中断の印を読んだりできる。同期の `call` だけでは、上限に当たったときに止める（罠にする）ことしかできない。
- **罠の後はインスタンスを作り直す。** 罠（trap）の後に同じインスタンスを呼ぶと `cannot enter component instance` になった（試した）。メモリ不足は、Rust の側では `unreachable` の罠として現れ、panic と区別できなかった（試した）。区別したいときは、`StoreLimitsBuilder::trap_on_grow_failure(true)` で別の誤りにできる（試した）。

---

## 1. 実行系の候補

### 1.1 Wasmtime

- **最新版（2026-10-12 時点）**: 安定版の最新は 49.0.2（2026-10-02 公開）。50.0.0-rc.1 も 2026-10-05 に出ている。出典: https://crates.io/api/v1/crates/wasmtime （`max_stable_version` と `versions`）。
- **MSRV**:
  - crates.io に載る `rust-version` は、49.0.2 が 1.96.0、48.0.x が 1.95.0、50.0.0-rc.1 が 1.97.0 である（同上）。
  - 方針はワークスペースの `Cargo.toml` のコメントにある。「Wasmtime's current policy is that this number can be no larger than the current stable release of Rust minus 2.」 出典: https://github.com/bytecodealliance/wasmtime/blob/release-49.0.0/Cargo.toml
  - ドキュメントの platform support と tiers のページには、MSRV の記述が見当たらなかった。
  - Benitoite の `rust-version = "1.98"`（Rust 1.98.1）で 49.0.2 をビルドし、実行できた（試した）。上の方針では、Wasmtime の MSRV は安定版の Rust から 2 つ遅れて上がる。このため、Wasmtime の版を上げると、Benitoite の MSRV より上の Rust を求められることがある。版を上げるときに確かめる必要がある。
- **リリースの周期と LTS**: 毎月 5 日に `release-X.0.0` のブランチを切り、20 日ごろにメジャー版を出す。版の番号が 12 の倍数の版は LTS で、24 か月保守される。そのほかの版は 2 か月である。セキュリティの修正は、保守中のすべての版に戻される。出典: https://docs.wasmtime.dev/stability-release.html （元の文書は https://github.com/bytecodealliance/wasmtime/blob/main/docs/stability-release.md ）。
  - 48 が LTS に当たる。48.0.0 は 2026-08-20 公開で、MSRV は 1.95.0（https://crates.io/api/v1/crates/wasmtime/48.0.0 ）。
  - 各版の保守の終わりの日付は、ページの表が JavaScript で描かれるため読めなかった（未確認）。
- **ライセンス**: `Apache-2.0 WITH LLVM-exception`（crates.io の 49.0.2 の `license`。https://crates.io/crates/wasmtime/49.0.2 ）。
- **Tier**（出典: https://docs.wasmtime.dev/stability-tiers.html ）:
  - Tier 1: `component-model`、Cranelift、Winch、`x86_64-unknown-linux-gnu`、`x86_64-apple-darwin`。
  - Tier 2: `aarch64-apple-darwin`、`aarch64-unknown-linux-gnu`、Pulley。この三つに足りない条件は、前の二つが「Continuous fuzzing」、Pulley が「More time fuzzing/baking」である。
  - fuel と epoch は、この表に載っていない。

### 1.2 そのほかの候補

| 実行系 | 最新版 | コンポーネントの対応 | 出典 |
|---|---|---|---|
| wasmi | 2.0.0（2026-09-01、MSRV 1.86、MIT/Apache-2.0） | **対応しない**。README の対応表にコンポーネントモデルがなく、WASI は `wasip1` だけである。課題 #897「Implement the Wasm `component-model` proposal」は open のまま。2025-02 に保守者が「not planned nor unplanned」と書いた | https://crates.io/crates/wasmi 、https://github.com/wasmi-labs/wasmi 、https://github.com/wasmi-labs/wasmi/issues/897 |
| wasmi + `wasm_component_layer` | 0.1.18（最終更新 2024-08-02） | どの実行系の上でも動く、という触れ込みのコンポーネントの層。2 年以上更新がなく、いまの仕様にどこまで追従しているかは未確認 | https://crates.io/crates/wasm_component_layer |
| Wasmer | 7.5.0（2026-10-01、MSRV 1.96、MIT） | **未確認**。`lib/api/Cargo.toml`（main）と README に "component" の語がなかった。対応を示す一次資料は見つからなかった | https://crates.io/crates/wasmer 、https://github.com/wasmerio/wasmer/blob/main/lib/api/Cargo.toml |

WasmEdge、WAMR などの、Rust 以外で書かれた実行系は調べていない（未確認）。

### 1.3 推す選択

**Wasmtime** を推す。理由は三つある。

- コンポーネントモデルが Tier 1 で、Rust の API から動的な型の照合と呼び出しができる（2 で試した）。
- fuel・epoch・メモリの上限という、信頼しないコードを動かすための仕組みがそろっている。
- 依存がすべて許容型のライセンスである（3.4）。

版は、LTS の 48.x と最新の 49.x のどちらかを選ぶ。LTS は 24 か月保守され、毎月の版の上げの手間が減る。改造の時点の LTS（48.x）を `=` で固定する案がある（案）。

---

## 2. 実行時に型が決まる関数を呼ぶ API（wasmtime 49.0.2）

docs.rs の該当ページ: https://docs.rs/wasmtime/49.0.2/wasmtime/component/index.html 。crates.io から取得したクレートのソースも読んで確かめた。

| 目的 | API |
|---|---|
| 読み込みとコンパイル | `Component::from_file(&engine, path)` / `Component::new(&engine, bytes)` / `Component::from_binary`（機能 `cranelift` か `winch` が要る） |
| 型の取り出し | `Component::component_type() -> component::types::Component` |
| 取り込みの列挙 | `types::Component::imports(&engine) -> impl ExactSizeIterator<Item = (&str, ComponentExtern)>`。`get_import(&engine, name)` もある |
| 書き出しの列挙 | `types::Component::exports(&engine)` / `get_export(&engine, name)` |
| 書き出しの種類 | `ComponentExtern { ty: ComponentItem, implements, … }`。`ComponentItem::ComponentFunc(ComponentFunc)`・`CoreFunc`・`Module`・`Component`・`ComponentInstance`・`Type`・`Resource` |
| 関数の型 | `ComponentFunc::params() -> (&str, Type)` の並び、`results() -> Type` の並び、`async_()` |
| 値の型 | `component::Type`。`Bool`・`S8`〜`U64`・`Float32`・`Float64`・`Char`・`String`・`List`・`Map`・`Record`・`Tuple`・`Variant`・`Enum`・`Option`・`Result`・`Flags`・`Own`・`Borrow`・`Future`・`Stream`・`ErrorContext`・`FixedLengthList` |
| インスタンスの作成 | `Linker::<T>::new(&engine)` → `linker.instantiate(&mut store, &component)`。取り込みが空なら、何も登録しない `Linker` で作れる |
| 関数の取得 | `Instance::get_func(&mut store, "distance") -> Option<Func>` |
| 呼び出し | `Func::call(&self, store, params: &[Val], results: &mut [Val]) -> Result<()>`。`results` の長さは結果の数に合わせる |
| 値 | `component::Val`。`S64(i64)`・`String(String)`・`List(Vec<Val>)`・`Record(Vec<(String, Val)>)`・`Variant(String, Option<Box<Val>>)`・`Enum(String)`・`Option(..)`・`Result(..)`・`Flags(Vec<String>)`・`Resource(ResourceAny)` など |

補足:

- **`post_return` は要らない。** 49.0.2 では `Func::post_return` が `#[deprecated(note = "no longer needs to be called; this function has no effect")]` になっている。`call` の中で post-return を呼ぶ（ソース `src/runtime/component/func.rs`）。以前の版の例にある `post_return` の呼び出しは要らない。
- **`call` の誤り**: 引数の数や型が違うとき、罠が起きたとき、`Store` が非同期の呼び出しを要するときに `Err` を返す。メモリの確保に失敗したときは `OutOfMemory` の誤りを返す（docs.rs の `Func::call` の説明）。
- **試した結果**（`host/src/main.rs`）:
  - unknown-unknown で作ったコンポーネントでは、`imports (0): []` になった。書き出しは `export distance: func(a: String, b: String) -> [S64]` と出た。
  - 型の照合（すべての引数が `Type::String` で、結果が `[Type::S64]`）も通った。`call` は `kitten`/`sitting` に対して `S64(3)` を返した。
  - wasip2 で作ったコンポーネントでは、取り込みが 14 個と出た。空の `Linker` での `instantiate` は「component imports instance `wasi:io/poll@0.2.9`, but a matching implementation was not found in the linker」で失敗した。取り込みが空かどうかは、インスタンスを作る前に `component_type().imports()` で判定できる。
- **型の照合の手順（案）**: Benitoite の宣言から、期待する `Type` の形を作る。`ComponentFunc::params()`・`results()` を再帰的に辿って比べる。`Record` の欄（`fields()`）、`Variant` の場合（`cases()`）、`Enum` の名前（`names()`）も比べる。比べる操作は `Type` が持つ（ソース `src/runtime/component/types.rs`）。
- 静的に型が分かる場合は `Func::typed::<(String, String), (i64,)>()` も使える。ただし、Benitoite の宣言は実行時に読むので、`Val` の経路が合う。

---

## 3. Cargo の機能と、大きさ・ビルドの時間・依存

### 3.1 wasmtime 49.0.2 の機能

既定の機能は次のとおりである（クレートの `Cargo.toml`。docs.rs の機能の一覧: https://docs.rs/crate/wasmtime/49.0.2/features ）。

> anyhow, async, backtrace, cache, gc, gc-copying, gc-drc, gc-null, wat, profiling, parallel-compilation, cranelift, pooling-allocator, demangle, addr2line, coredump, debug-builtins, runtime, component-model, component-model-async, threads, stack-switching, std, debug, compile-time-builtins, wit-parser

既定を切って（`default-features = false`）、必要なものだけを足す。フェーズ 1 に要るのは次のとおりである。

- 必須: `runtime`、`component-model`、`std`。
- 読み込みのときにコンパイルするなら `cranelift`。
- 実行を区切るなら `async`（4 を見よ）。

外せるもの:

- `cache`: wasmtime-cache。ディスクへのキャッシュ。
- `wat`: テキスト形式の読み込み。
- `parallel-compilation`: rayon。
- `profiling`、`coredump`、`debug-builtins`、`demangle`、`addr2line`、`backtrace`。
- `gc*`: Wasm GC。
- `threads`、`stack-switching`、`component-model-async`、`pooling-allocator`、`wit-parser`、`compile-time-builtins`、`debug`。

`backtrace` を外したときの罠の報告の中身は、見ていない（未確認）。

**コンパイラの選び方**:

- **Cranelift**: 最適化するコンパイラ（Tier 1）。
- **Winch**: ベースラインのコンパイラ（Tier 1）。aarch64 の版は開発中である（https://docs.wasmtime.dev/stability-platform-support.html ）。`Config::epoch_interruption` の説明に「Enabling this option is not compatible with the Winch compiler.」とあるので、Benitoite には向かない。
- **Pulley**: 解釈実行器（Tier 2）。バイトコードは Cranelift のバックエンドが作る（同ページ）。
  - Cargo の機能 `pulley` は中身が空で、ホストのアーキテクチャにネイティブのコンパイラがあるときに Pulley を使えるようにする印である。`Config::target("pulley64")` と組み合わせる（`build.rs` と `engine.rs`）。
  - 機能 `pulley` なしで `target("pulley64")` を指定すると、「compilation settings are not compatible with the native host」で失敗した（試した）。
  - **Pulley でも、`.wasm` から作るには Cranelift が要る**。コンパイラなしの構成で動かすには、事前にコンパイルした成果物を `deserialize` で読む（試した。3.3）。

### 3.2 大きさとビルドの時間（試した）

条件:

- 対象: 試しのホスト（`host`）。コンポーネントを読み、型を確かめ、`Val` で呼ぶ。
- ビルド: release、`opt-level = 3`、LTO なし、`panic` は既定の unwind。
- 計測: 構成ごとに別の `target` ディレクトリを使い、何もない状態からビルドした。依存のソースは取得済みである。CPU の並列は 6 前後。
- 基準: 空のプログラム（`cargo new` の hello）は 433,776 B、strip すると 342,048 B。

| 構成（wasmtime の機能） | ビルドの時間 | 依存のクレートの数 | 大きさ | strip 後 | hello との差（strip 後） |
|---|---|---|---|---|---|
| `runtime, component-model, std`（コンパイラなし） | 18 秒 | 75 | 2,057,072 B | 1,465,664 B | 約 +1.1 MB |
| 上 + `pulley` | 19 秒 | 75 | 2,200,496 B | 1,552,880 B | 約 +1.2 MB |
| 上 + `cranelift` | 46 秒 | 97 | 14,117,808 B | 10,181,720 B | 約 +9.8 MB |
| 上 + `cranelift` + `pulley` | 47 秒 | 97 | 14,253,760 B | 10,268,928 B | 約 +9.9 MB |
| 既定の機能をすべて | 56 秒 | 144 | 19,404,848 B | 14,092,104 B | 約 +13.7 MB |
| 参考: `cranelift` + `async`（`slice`） | — | — | 14,145,072 B | — | — |

- 依存のクレートの数は、`cargo tree -e normal,build` の重複を除いた数である（ホストのクレートを除く）。
- いまの Benitoite の release の実行ファイルは 12,088,096 B（strip していない。`target/release/benitoite`）。Cranelift を入れると、実行ファイルはおよそ倍になる見込みである（見込み。Benitoite に組み込んで測ってはいない）。
- 解釈実行器の Pulley は、`runtime` の機能に既に含まれている（`runtime` が `pulley-interpreter/interp` を有効にする）。機能 `pulley` を足しても増えるのは約 90 KB だった。

### 3.3 Pulley の速さ（試した。短い測定）

- 3000 文字どうしの編集距離（結果は 301、fuel 換算で約 5.5 億命令）で比べた。Cranelift のネイティブのコードは 12.8 ms、Pulley は 377 ms で、約 30 倍遅い。
- 1 回だけの短い測定なので、目安である。

### 3.4 依存のライセンス（`cargo tree -f '{l}'`）

`cranelift` の構成（97 個）の内訳は次のとおりである。

| ライセンス | 個数 |
|---|---|
| MIT OR Apache-2.0 | 46 |
| Apache-2.0 WITH LLVM-exception | 27 |
| Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | 7 |
| Apache-2.0 OR MIT | 5 |
| MIT | 3 |
| Unlicense OR MIT | 2 |
| MIT/Apache-2.0 | 2 |
| Zlib（foldhash） | 1 |
| BSD-2-Clause OR MIT OR Apache-2.0（mach2） | 1 |
| Apache-2.0 / MIT | 1 |
| (MIT OR Apache-2.0) AND Unicode-3.0（unicode-ident） | 1 |
| (Apache-2.0 OR MIT) AND BSD-3-Clause（encoding_rs。`component-model` が入れる） | 1 |

- 既定の機能をすべて入れると、`BSD-3-Clause` が 2 個と `Apache-2.0` が 1 個増える。
- コピーレフト（GPL・LGPL・MPL など）はなかった。すべて許容型である。
- 配布物には、各ライセンスの表示（Apache-2.0 の NOTICE、BSD・Zlib・Unicode の著作権の表示など）を同梱する必要がある。どのファイルに何を載せるかは調べていない（未確認）。

---

## 4. 実行時間・メモリの上限と、実行の区切り方

出典: wasmtime 49.0.2 のソースの説明（`src/config.rs`、`src/runtime/store.rs`、`src/runtime/limits.rs`）。docs.rs の該当ページは https://docs.rs/wasmtime/49.0.2/wasmtime/struct.Config.html 、https://docs.rs/wasmtime/49.0.2/wasmtime/struct.Store.html 、https://docs.rs/wasmtime/49.0.2/wasmtime/enum.UpdateDeadline.html 、https://docs.rs/wasmtime/49.0.2/wasmtime/struct.StoreLimitsBuilder.html 。

### 4.1 fuel

- **仕組み**: `Config::consume_fuel(true)` を設定すると、生成コードに燃料の数え上げが入る。`Store::set_fuel(n)` で燃料を入れる。`Store` は燃料 0 で始まり、入れないとすぐに罠になる。
- **数え方**: ほとんどの命令が 1 を消費する。`nop`・`drop`・`block`・`loop` は 0 である。`Config::operator_cost` で命令ごとの重みを変えられる。
- **保証**: 決定的である。同じ状態から同じ呼び出しをすると、必ず同じ点で完了するか、`Trap::OutOfFuel` になる。
- **区切り**: `Store::fuel_async_yield_interval(Some(n))` を設定すると、燃料を n 消費するごとに、`*_async` で呼んだ実行を中断して呼び出し側に戻る（機能 `async` が要る）。
- **負担**: epoch より重い。説明には「in some measurements, up to 2-3x」とある。

### 4.2 epoch

- **仕組み**: `Config::epoch_interruption(true)` を設定し、`Store::set_epoch_deadline(ticks)` で期限を決める。期限を決めないと、すぐに罠になる。別のスレッドが `Engine::increment_epoch()` を呼んで、時を進める。
- **期限に来たときの動き**は三つから選ぶ。
  - 罠にする（`epoch_deadline_trap`。既定）。
  - コールバックを呼ぶ（`epoch_deadline_callback`）。コールバックは `UpdateDeadline` を返す。
    - `Interrupt`: 罠にする。
    - `Continue(n)`: 期限を延ばす。
    - `Yield(n)` / `YieldCustom(n, future)`: 戻ってから延ばす。async のときだけ使え、同期の呼び出しでは罠になる。
  - async の実行器に戻ってから延ばす（`epoch_deadline_async_yield_and_update`）。
- **保証**: 説明には「Epochs are designed to handle malicious WebAssembly guests -- the deadline check cannot be avoided by WebAssembly code.」とある。ただし、`memory.copy` などの一括の命令は、始まりで一度しか期限を確かめない。このため、一つの区切りの長さは、epoch の間隔と、最大の一括コピーの時間のうち長い方になる。厳密な時間の上限が要るなら、`ResourceLimiter` でメモリの大きさを抑えるよう勧めている。
- **決定性**: ない（時刻に依存する）。
- **負担**: fuel より軽い。
- **ホストの呼び出しで止まっている間**: fuel も epoch も効かない。フェーズ 1 は取り込みがないので、この問題は起きない。

### 4.3 async で区切る（試した）

- 機能 `async` を入れて `Func::call_async` を使うと、Wasm の実行が Future になる。
- 試しでは、Future を実行器なしで手で poll した。`Waker::noop()` を使い、`Poll::Pending` が返るたびに数えた（`host/src/bin/slice.rs`）。どちらの区切り方でも、正しい結果（301）が返った。
  - fuel（`fuel_async_yield_interval(Some(1_000_000))`）: 549 回 `Pending` が返った。約 18 ms。
  - epoch（1 ms ごとに `increment_epoch`、`epoch_deadline_async_yield_and_update(1)`）: 11 回 `Pending` が返った。約 15 ms。
- `Pending` が返ったところで、VM はタスクを切り替えたり、中断の印を読んで Future を捨てたりできる。
- Wasmtime の async は、Wasm を別の「ファイバ」のスタックで動かす。依存に wasmtime-fiber が加わる。スタックの大きさは `Config::async_stack_size` で決まり、既定は 2 MiB である。
- 49.0.2 では `Config::async_support` が「no longer has any effect」になっている。`call_async` を使うかどうかだけで決まる。
- `call_async` は `Store` のデータに `Send` を求める（`AsContextMut<Data: Send>`）。言語の値をデータに置かなければ問題にならない（見込み）。

### 4.4 どれが「区切って VM に戻り、タスクの切り替えと中断の印の確認をする」に合うか

- **同期の `call` + fuel、または同期の `call` + epoch のコールバック**: 上限を超えたら止める（罠）ことと、コールバックの中で中断の印を読んで `Interrupt` を返すことはできる。しかし、実行を途中で抜けて VM の他のタスクへ切り替えることはできない。
- **`call_async` + 区切り**: 4.3 のとおり、実行を途中で VM に戻せる。目的に合うのはこの形である。
  - fuel で区切ると、区切りの位置が決定的になる。テストで再現しやすく、VM の「呼び出しの回数の予算」とも考え方が揃う。
  - epoch で区切ると軽いが、時刻を進めるスレッドが要り、区切りが決定的でなくなる。
  - Benitoite の Regex の改造（TODO-201）で VM に作った区切り方と揃えるなら、fuel の方が近い（判断。そちらの区切り方の詳細は調べていない）。
  - 4.3 の短い測定では、fuel・epoch・どちらもなしの差は雑音（12〜20 ms のばらつき）に埋もれた。2〜3 倍という説明の数は、この試しでは確かめられなかった。

### 4.5 メモリの上限

- `Store::limiter(|data| &mut data.limits)` に `StoreLimits` を渡す。設定は `StoreLimitsBuilder::new().memory_size(bytes).table_elements(n).instances(n).memories(n).tables(n).trap_on_grow_failure(bool).build()` で作る。
- 自前の判断が要るときは、trait `ResourceLimiter`（async 用は `ResourceLimiterAsync`）を実装する。
- 上限に当たると、`memory.grow` が -1 を返す（Wasm の仕様どおり）。`trap_on_grow_failure(true)` なら、罠に近い誤りになる。
- 64 bit の環境では、線形メモリ一つに 4 GiB の仮想アドレス空間を予約するのが既定である（`Config::memory_reservation` の説明）。実際に確保する量ではない。

### 4.6 罠の種類と、メモリ不足の現れ方

**罠の種類**: `wasmtime::Trap` の主なものは次のとおりである（wasmtime-environ 49.0.2 の `trap_encoding.rs`。docs.rs: https://docs.rs/wasmtime/49.0.2/wasmtime/enum.Trap.html ）。

- `StackOverflow`、`MemoryOutOfBounds`、`TableOutOfBounds`、`IndirectCallToNull`、`BadSignature`
- `IntegerOverflow`、`IntegerDivisionByZero`、`BadConversionToInteger`、`UnreachableCodeReached`
- `Interrupt`（epoch）、`OutOfFuel`
- `CannotEnterComponent`、`InvalidChar`、`StringOutOfBounds`、`ListOutOfBounds`、`AllocationTooLarge` など

誤りの値は `wasmtime::Error` で、`e.downcast_ref::<wasmtime::Trap>()` で種類を取り出せる。

**試した結果**:

| 場面 | 結果 |
|---|---|
| 燃料切れ | `Some(OutOfFuel)` |
| 引数の文字列（20 MiB）が上限（16 MiB）を超える | 受け渡しの領域を確保する `cabi_realloc` の中で `Some(UnreachableCodeReached)` |
| 関数の中の確保（6 MiB の文字列から `Vec<char>` を作る）が上限を超える | Rust の `handle_alloc_error` → `rust_oom` を経て `Some(UnreachableCodeReached)` |
| 上と同じで、`trap_on_grow_failure(true)` | 「forcing trap when growing memory to 26542080 bytes」。`Trap` ではない誤り（`downcast_ref::<Trap>()` は `None`） |
| **罠の後に同じインスタンスを再び呼ぶ** | `wasm trap: cannot enter component instance` |

**Benitoite の `Result` との対応への示唆**:

- `panic = "abort"` の Rust のゲストでは、panic もメモリ不足も同じ `UnreachableCodeReached` になる。メモリ不足を区別したいなら、`trap_on_grow_failure(true)` を使う。あるいは、`ResourceLimiter` が拒否したことを自分で記録して見分ける（案）。
- 罠の後は同じインスタンスを使えない。呼び出しごとにインスタンスを作るか、罠の後に作り直す。インスタンスの作成は 30〜100 µs だった（試した）。
- ホストのメモリの確保の失敗は、`OutOfMemory` の誤りとして返す、と各 API の説明にある。

---

## 5. WIT の型

出典: Component Model の仕様（`design/mvp/WIT.md` と `design/mvp/Explainer.md`。main のコミット 6c48079b を 2026-10-12 に取得）。

- https://github.com/WebAssembly/component-model/blob/main/design/mvp/WIT.md
- https://github.com/WebAssembly/component-model/blob/main/design/mvp/Explainer.md

### 5.1 型の一覧

Explainer の `defvaltype` の文法は次のとおりである。

- 基本の型: `bool`、`s8`・`u8`・`s16`・`u16`・`s32`・`u32`・`s64`・`u64`、`f32`・`f64`、`char`、`string`
- 合成の型: `record`、`variant`、`list<T>`、`tuple<…>`、`flags`、`enum`、`option<T>`、`result<T, E>`（両方とも省略できる）
- ハンドル: `own<T>`、`borrow<T>`
  - WIT では、所有するハンドルは資源の名前をそのまま書き、借りるハンドルは `borrow<T>` と書く。
  - 資源は `resource` の項目で定義する。
- 追加の型（絵文字の印が付いたもの）:
  - `map<K, V>`（🗺️）: キーは整数・`char`・`bool`・`string` に限る。
  - `stream<T>`・`future<T>`（🔀）
  - `error-context`（📝）
  - 固定長のリスト `list<T, N>`（🔧）

印の扱いは次のとおりである（Explainer の冒頭）。

- 🔀（async・stream・future）、🗺️（map）、🏷️ は、0.2 の後の WASI の Developer Preview で出荷済みである。
- 🔧（固定長のリスト）、📝（error-context）、🐘（memory64）、📡（getter・setter）などは、既定で有効ではなく、互換性を壊す変更があり得る。

**Wasmtime 49.0.2 の扱い**:

- `component::Type` と `Val` は、上の型をすべて持つ（`Map`・`FixedLengthList`・`ErrorContext`・`Stream`・`Future` を含む）。
- `Config::wasm_component_model_map`・`wasm_component_model_fixed_length_lists`・`wasm_component_model_error_context` で有効にできる。固定長のリストについては、説明に「Wasmtime's support for this feature is _very_ incomplete.」とある。
- 各機能が既定で有効かどうかは確かめていない（未確認）。

**メモ 4 の表の見直し**:

- メモの「渡せない」側に、`map`、`list<T, N>`、`stream`・`future`・`error-context` を足す必要がある。
- 4 の表は、Benitoite の `Map` を「WIT になし」としている。WIT には `map<K, V>` がある。ただし、印 🗺️ の付いた追加の型である。渡すかどうかは改造で判断する。

### 5.2 再帰する型の禁止

WIT.md は「Types, however, cannot be recursive:」と書き、次の例を誤りとして示している。

```wit
type foo = foo;  // ERROR: cannot refer to itself
record bar1 { a: bar2, }
record bar2 { a: bar1, }   // ERROR: record cannot refer to itself
```

あわせて、`use` でつないだインターフェースも非循環でなければならない（「Interfaces linked with `use` must be acyclic.」）。

**結論**: 再帰する型は書けないことを、一次資料で確かめた。メモ 4 の「未確認」を外せる。

### 5.3 名前の規則（kebab-case）

**文法**: Explainer の `label` は次のとおりである。

```
label          ::= <first-fragment> ( '-' <fragment> )*
first-fragment ::= <first-word> | <first-acronym>
first-word     ::= [a-z] [0-9a-z]*
first-acronym  ::= [A-Z] [0-9A-Z]*
fragment       ::= <word> | <acronym>
word           ::= [0-9a-z]+
acronym        ::= [0-9A-Z]+
```

- 名前は、ハイフンで区切った「語」の並びである。各語は、すべて小文字か、すべて大文字（頭字語）にする。最初の語は英字で始める。
- 大文字と小文字を一つの語に混ぜることはできない（例: `parse-XML-document` はよく、`parseXml` は不可）。下線は使えない。
- 名前は、同じ有効範囲で大文字と小文字を区別せずに一意でなければならない（WIT.md「Each name must be case-insensitively unique in the scope in which it is declared.」）。
- WIT のキーワードと同じ名前は、`%` を前に付けて書く（例: `%variant`）。

**Benitoite への示唆**: レコードの欄の名前（Benitoite の側は lowerCamelCase の想定）は、語に分けてハイフンでつなぐ規則で変換できる。ただし、大文字と小文字の混ざった語（`HTTPServer` など）と数字の扱いは決める必要がある（判断）。

---

## 6. Rust で純粋なコンポーネントを作る

版: wit-bindgen 0.62.0（2026-09-10。https://crates.io/crates/wit-bindgen/0.62.0 ）、wasm-tools 1.261.0（https://crates.io/crates/wasm-tools/1.261.0 ）。

### 6.1 例のソースはそのまま通った（試した）

- 例の `lib.rs` は、`wit_bindgen::generate!({ world: "fuzzy", path: "../wit" })`、`struct Component; impl Guest for Component { fn distance(a: String, b: String) -> i64 }`、`export!(Component);` の形である。wit-bindgen 0.62.0 で、書き直さずにコンパイルできた。
- `path` はクレートの根（`Cargo.toml` のあるディレクトリ）からの相対パスである。例の配置（`fuzzy/rust/` から見た `../wit`）で合っている。試しでは配置を変えたので、`"wit"` にした。
- `Cargo.toml` の `wit-bindgen = "0.x"` は `"0.62.0"` に置き換えた（既定の機能のまま）。
- 例の `Cargo.toml` のコメントにある手順（`cargo build --release --target wasm32-unknown-unknown` → `wasm-tools component new … -o …` → `wasm-tools component wit …`）も、そのまま動いた。

### 6.2 (a) `wasm32-unknown-unknown` + `wasm-tools component new`（試した）

- コアのモジュール（25,094 B）の取り込みは 0 個だった（`wasm-tools print` で `(import` が 0）。
- `wasm-tools component new`（`--adapt` なし）でそのまま包めた。**adapter は要らない**。コンポーネントは 25,141 B になった。
  - adapter（`wasi_snapshot_preview1.*.wasm`）は、`wasi_snapshot_preview1` を取り込むモジュール（wasip1 の対象）を包むときのものである（wit-bindgen の README: https://github.com/bytecodealliance/wit-bindgen/blob/main/README.md ）。
- `wasm-tools component wit` の出力は次のとおりで、取り込みはない。

  ```
  package root:component;
  world root {
    export distance: func(a: string, b: string) -> s64;
  }
  ```

- world の名前は `root` と出た。`fuzzy` の名前はコンポーネントの型に残らない。照合には書き出しの名前と型だけを使うことになる。
- panic（`panic = "abort"`）とメモリ不足は、`unreachable` の罠になる（4.6）。
- ビルドの時間は、何もない状態から 16 秒（wit-bindgen のマクロのコンパイルを含む）。

### 6.3 (b) `wasm32-wasip2`（試した）

- `cargo build --release --target wasm32-wasip2` の出力は、そのままコンポーネントになる（74,938 B）。`panic = "abort"` を設定していても、次の 14 個を取り込んでいた。
  - `wasi:io/poll`、`wasi:io/error`、`wasi:io/streams`
  - `wasi:clocks/monotonic-clock`
  - `wasi:cli/stdout`・`stderr`・`stdin`・`environment`・`exit`・`terminal-input`・`terminal-output`・`terminal-stdin`・`terminal-stdout`・`terminal-stderr`
  - いずれも `@0.2.9`。
- 関数の本体は WASI を使わないが、標準ライブラリの部分（panic の表示、標準入出力、環境、終了など）が取り込みを残す。どの部分がどの取り込みを生むかは調べていない。
- 取り込みが空でないので、「取り込みが空なら純粋」という判定を通らない。空の `Linker` ではインスタンスも作れなかった（2）。
- **結論**: メモ 2.5 の懸念は当たっていた。フェーズ 1 は (a) にする。wasip2 で作ったコンポーネントを読み込みのときに誤りとして扱う規則も、取り込みの名前で示せる。

### 6.4 ツールの導入

- 対象: `rustup target add wasm32-unknown-unknown`（wasip2 も使うなら `wasm32-wasip2`）。
- wasm-tools: `cargo install --locked wasm-tools`。試しでは `--root` で作業用のディレクトリに入れた。ビルドに数分かかった。
- `cargo-component` は使っていない。

---

## 7. セキュリティと、読み込みのときのコンパイルの費用

### 7.1 信頼しないコンポーネントを動かすときの注意

出典: https://docs.wasmtime.dev/security.html と `Config` の説明。

- **Spectre**: Wasmtime が緩和しているのは、次の三つである。
  - 関数の表の範囲の確かめ（`call_indirect`）
  - `br_table`
  - 「dynamic」なメモリの範囲の確かめ

  既定の線形メモリは、ページの保護（guard）に頼り、明示の範囲の確かめを持たない。aarch64 の `csdb` 命令は、性能のために既定で無効である（`use_csdb` で有効にできる）。説明には「Mitigating Spectre continues to be a subject of ongoing research」とある。
- **Cranelift と Pulley**:
  - Cranelift は Tier 1 である。Pulley は Tier 2 で、Tier 1 に足りない条件は「More time fuzzing/baking」である（https://docs.wasmtime.dev/stability-tiers.html ）。
  - 開発者自身の Mac（`aarch64-apple-darwin`）も Tier 2 である。
  - Pulley は実行時に機械語を書き出さない。しかし、それが安全の上でどれだけ有利かを述べた一次資料は見つけていない（未確認）。
- **スタック**:
  - `Config::max_wasm_stack` の既定は 512 KiB である。Wasm が使うスタックが上限を超えると、`StackOverflow` の罠になる。
  - ただし、呼ぶ側のスレッドにそれだけの空きがあることは保証しない。スレッドのスタックを使い切ると、**プロセスが abort する**と説明にある。
  - Benitoite の VM のスレッドから同期の `call` で呼ぶなら、そのスレッドの残りのスタックが `max_wasm_stack` より十分に大きい必要がある。`async` で呼ぶなら、Wasm は `async_stack_size`（既定 2 MiB）のファイバの上で動く。
- **シグナル**:
  - 既定では、範囲外のアクセスなどを `SIGSEGV` などのシグナル（macOS では mach ports の設定もある）で捕まえるために、プロセス全体のシグナルの処理を登録する。
  - `Config::signals_based_traps(false)` で登録をやめられる。その代わり、明示の範囲の確かめが入って遅くなる。説明には「up to 2x slower」とある。
  - Benitoite の `SIGINT`・`SIGTERM` の処理（02-09「中断の要求」）とは別のシグナルである。しかし、併用で問題がないかは確かめていない（未確認）。
  - 依存のクレートが内部に大域の状態を持つときは、AGENTS.md の規約どおり、03-01 に書く必要がある。
- **メモリ**:
  - インスタンスが使ったメモリは、終わった後に 0 で埋める（security のページ）。
  - 線形メモリの前に 2 GB の guard 領域を置く（同）。

### 7.2 コンパイルの費用とキャッシュ（試した）

例の Fuzzy（25 KB）での計測は次のとおりである（短い測定）。

| 操作 | 時間 |
|---|---|
| `Component::from_file`（Cranelift、ネイティブ） | 27〜44 ms |
| `Component::from_file`（Cranelift、Pulley 向け） | 22〜40 ms |
| `Component::deserialize`（事前にコンパイルした成果物から） | 0.1〜0.5 ms |
| `instantiate` | 30〜100 µs |
| 呼び出し 1 回（短い文字列） | 18〜60 µs |

- 事前にコンパイルした成果物は、ネイティブ向けが 134,856 B、Pulley 向けが 151,120 B だった。
- `Engine::precompile_component` / `Component::serialize` で作り、`Component::deserialize` / `deserialize_file` で読む。コンパイラなしの構成（3.2 の 1.5 MB の版）でも、この経路で実行できた（試した）。
- 機能 `cache` は、コンパイルの結果をディスクにキャッシュする仕組みである（wasmtime-cache）。依存が増える。

**`deserialize` は `unsafe` である**。説明（`Module::deserialize`）には次のとおりある。

- 入力の検証は軽く、任意の入力を与えると、コンパイル済みのコードを別のコードに差し替えて任意のコードを実行させられる。
- このため、利用者の任意の入力に晒してはならない。
- `serialize` / `precompile_*` の出力をそのまま与える限りは安全とみなせる。
- 別の版の Wasmtime が作った出力は、安全に `Err` になる。

**Benitoite への示唆**:

- **規約との衝突**: AGENTS.md の規約は、`unsafe` を `runtime::heap` の内部の層だけに許している。キャッシュを読むために `deserialize` を使うなら、規約の例外を加える必要がある。
- **キャッシュの改ざん**: ディスクのキャッシュを改ざんされると、サンドボックスを越えたコードの実行につながる。キャッシュの置き場所の権限や、内容のハッシュの照合を決める必要がある。
- **毎回コンパイルする案**: 小さなコンポーネントなら、コンパイルは数十 ms である。フェーズ 1 は、毎回 `Component::new` でコンパイルし、`unsafe` もキャッシュも持たない案が単純である（案）。大きなコンポーネント（フェーズ 2 の Json・Regex など）のコンパイルの時間は測っていない（未確認）。

---

## 付記: 試しの再現の手順

```sh
W=/private/tmp/claude-501/-Users-tecogonaz-src-Benitoite/6253d5a4-70d2-428f-a9e7-3fd241935306/scratchpad/pkg/wasmtest
cd $W/fuzzy && cargo +1.98.1 build --release --target wasm32-unknown-unknown
$W/tools/bin/wasm-tools component new target/wasm32-unknown-unknown/release/fuzzy.wasm -o fuzzy-unknown.component.wasm
$W/tools/bin/wasm-tools component wit fuzzy-unknown.component.wasm
cd $W/fuzzy && cargo +1.98.1 build --release --target wasm32-wasip2
$W/tools/bin/wasm-tools component wit target/wasm32-wasip2/release/fuzzy.wasm
cd $W/host && cargo +1.98.1 build --release --features compiler        # 機能: compiler / pulley / async / full
./target/release/host ../fuzzy/fuzzy-unknown.component.wasm [native|pulley] [save]
OOM=inner TRAPGROW=1 ./target/release/host ../fuzzy/fuzzy-unknown.component.wasm native
cargo +1.98.1 build --release --features compiler,async --bin slice && ./target/release/slice ../fuzzy/fuzzy-unknown.component.wasm [fuel|epoch]
```

試しのホストは、構成ごとに `$W/t-<構成>/` へビルドした。`host-<構成>`（と `.stripped`）が、3.2 の表の大きさを測った実行ファイルである。後でホストに試しのコードを足したので、いまの `t-cranelift-pulley/` の中身は表の時点と少し違う。
