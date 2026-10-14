# W4・W5 の事前点検

対象: `san_benito`（85eff190 の時点。`crates/` は 02b52fd7 から W1 の作業中の変更だけ）。行番号は `san_benito` のもの。パスは `crates/benitoite/` を省く。リポジトリのファイルは変えていない。

確かめに使ったもの:

- 試しのクレート `scratchpad/pkg/w4w5probe/`（新しく作った。wasmtime 49.0.2 を `runtime`・`component-model`・`std`・`cranelift` だけで使い、`wat` 1.261.0 でコンポーネントのテキストを変換する）。下の「確かめた事実」はこれで動かした結果である。
- 調査 B の試しのホスト（`scratchpad/pkg/wasmtest/host/`）と、取得済みの wasmtime 49.0.2 のソース（`~/.cargo/registry/src/index.crates.io-1949cf8c6b5b557f/wasmtime-49.0.2/`）。
- `cargo tree`・`cargo deny` を試しのホストに当てた結果（リポジトリの `deny.toml` を写して使った）。

（共通の補足）

### P1. 確かめた事実（wasmtime 49.0.2、Rust 1.98.1、Apple M4）

| 項目 | 結果 |
|---|---|
| `Config::signals_based_traps(false)` | 存在する（`src/config.rs:3227`）。Cranelift と組み合わせて動いた。**この設定にすると、Cranelift の `enable_heap_access_spectre_mitigation`・`enable_table_access_spectre_mitigation` が自動で切られる**（`config.rs:3024-3040`。両方を真にすると `Engine::new` が誤りを返す）。プロセス全体のシグナルの処理器の登録（`init_traps`）は呼ばれない（`engine.rs:130-140`） |
| シグナルを切っても残るスレッドごとの作用 | Wasm に初めて入るスレッドで `lazy_per_thread_init` が走り、既存の sigaltstack が 256 KiB より小さければ、256 KiB の sigaltstack を付け替える（`runtime/vm/traphandlers.rs:1165-1177`、`runtime/vm/sys/unix/signals.rs:459-580`）。コンパイル時の `cfg(has_native_signals)` で決まり、`Config` では切れない。Rust の標準ライブラリのスタックあふれの検出は sigaltstack の大きさに依らないので、検出そのものは壊れない（見込み。試していない） |
| C のコード | **機能 `runtime` は `cc` を build 依存に持ち、Unix では `src/runtime/vm/helpers.c`（50 行。弱いシンボル `__unw_add_dynamic_fde` の有無を返す関数）を C コンパイラでビルドする**（`build.rs` の `build_c_helpers`、`Cargo.toml` の `[build-dependencies.cc]`）。`cargo tree -i cc` は `aarch64-apple-darwin`・`x86_64-unknown-linux-musl`・`aarch64-unknown-linux-musl` のどれでも `cc v1.8.0 ← wasmtime` を示した。`cmake` は使わない。機能では外せない |
| 依存の数とライセンス | `cranelift` の構成で 97 個（調査 B 3.4 と同じ）。今の `deny.toml`（`allow = MIT, Apache-2.0, ISC, BSD-3-Clause`）を当てると 29 件が拒まれた。内訳は `Apache-2.0 WITH LLVM-exception` だけのクレートが 27、`Zlib`（`foldhash`）が 1、`(MIT OR Apache-2.0) AND Unicode-3.0`（`unicode-ident`）が 1 |
| コンポーネントのテキスト | `wat` 1.261.0（既定の機能 `component-model`）で `(component …)` を変換でき、`Component::from_binary` で読めた（532 バイト）。49 の構文では `(memory (core memory $i "memory")) (realloc (core func $i "cabi_realloc"))` と書く（古い `(memory $i "memory")` は誤り） |
| コアのモジュール | `Component::from_binary` は「failed to parse WebAssembly module」とだけ返す。見分けるには先頭の 8 バイトを見る（コンポーネントは `00 61 73 6d 0d 00 01 00`、コアのモジュールは `00 61 73 6d 01 00 00 00`） |
| 型の列挙 | `component_type().imports(&engine)` が 0 件、`exports` で `add: (a: S64, b: S64) -> [S64]`、`len: (s: String) -> [S64]`、`spin: () -> []`、`async_()` は偽 |
| 罠 | `unreachable` → `downcast_ref::<Trap>() == Some(UnreachableCodeReached)` |
| 燃料 | `br` だけの無限ループに燃料 10^9 で `Some(OutOfFuel)`、約 0.46 秒（release） |
| メモリの上限 | 自前の `ResourceLimiter` の `memory_growing` から `Err(wasmtime::Error::new(MemoryLimit(..)))` を返すと、`downcast_ref::<MemoryLimit>()` で取り出せた。関数の中の `memory.grow` でも、文字列の引数を下ろすときの `cabi_realloc` の中でも同じ |
| 中断 | `epoch_interruption(true)` と `Store::set_epoch_deadline(1)` で、別のスレッドが「中断の印が立ったら `Engine::increment_epoch()`」を 10 ms ごとに行う形で、無限ループが 212 ms で `Some(Interrupt)` になった（印は 200 ms で立てた）。呼び戻し（`epoch_deadline_callback`）は要らない。`increment_epoch` は「signal-safe」（`engine.rs:867-873`） |
| 呼び出しの費用 | 小さな関数で「`Store` の作成 + `instantiate` + `call`」を 1000 回: release 5.8 ms（1 回 約 6 µs）、debug 19.5 ms |
| コンパイルの時間 | 例の Fuzzy（25,141 B）: release 23〜53 ms、**debug 370〜406 ms**。小さな WAT のもの: release 0.9 ms、debug 12.8 ms |
| `Val` の大きさ | `size_of::<Val>() == 40`。`list<u8>` を `Val` で受け渡すと 1 バイトが 40 バイトになる |

### P2. 凍結した型の変更で、了承の表に**ない**もの（設計者に尋ねる。下の「設計者に尋ねること」）

外部の関数の照合の結果（正規化したパス、読んだバイト列、型の変換表）を、検査の段から `CompiledProgram` まで運ぶ経路が、了承した変更だけではつながらない。

- `desugar(modules, asts, resolved, types)`（10-06）と `codegen(LowerProgram, sources)`（10-07）と `pipeline::compile(core, sources)`（10-13）のシグネチャは凍結している。
- `BindingKind` は `Copy`（`src/resolve/mod.rs:12`）なので、列挙子に照合の結果（バイト列）を持たせられない。
- したがって、脱糖が読む四つの入力のどれかに欄が要る。最も小さいのは **`ResolveOutput`（10-04、`src/resolve/mod.rs:118`）に欄を一つ足す**ことである（推す案。`builtin_ops` と同じく名前解決が作る表で、照合の段が中身を埋める）。

ほかに、R9 の失敗の種類に `RuntimeError`・`ResourceError`（10-08、`src/runtime/mod.rs:50,88`）の列挙子が要り、中断を外部の関数の実行中に効かせるのに `InterruptSource`（10-10、`src/runtime/io/services.rs:22`）か呼び出しごとのスレッドが要る（W5 の節）。

`LoadOutput`（10-04）と `CheckedProgram`（10-13）には欄を足さずに済む（W4 の「根のパス」の節）。W2・W3 の事前点検 C6-6 の申し送りへの答えである。

### P3. 診断コードの割り当て

| 区分 | 作業 | 内容 |
|---|---|---|
| `E0809`〜`E0814` | W4 | `@external` の書き方（構文の段。E08 の続き。今の最大は E0808、`src/diag/codes.rs:887`） |
| `E10nn`（新設） | W4 | 外部の関数の照合（検査の段の最後。02-10「診断コード」の表に「`E10nn` 検査の誤り／外部の関数（コンポーネントの読み込みと型の照合）」の行を足す） |
| `R0601`（新設の区分 `R06nn`） | W5 | 外部の関数のトラップ（実行時エラー。R06 は空き。02-10 の表と JSON の `"runtime"` の行に `R06nn` を足す） |
| `R0904`・`R0905` | W5 | 外部の関数の燃料・メモリの上限（資源の不足。`"resource"` の区分は `R09nn` だけなので R09 に置く） |
| 既存 `R0902` | W5 | 外部の関数の戻り値から作る値が大きすぎる（`{function}` に外部の関数の修飾した名前を入れる） |
| `L0113` | W5 | 外部の関数の表が大きすぎる（`L0106` と同じ形。`src/bytecode/codegen/tables.rs:302`） |

### P4. 置き場所（新しいモジュール）

`src/external/`（新設。`lib.rs` に `pub mod external;`）に、外部の関数に関わるものを集める。R6 の「一か所の入口」はこのモジュールの `call` とする。

| ファイル | 作業 | 中身 |
|---|---|---|
| `mod.rs` | W4 | 型（`ExternalDecl`・`ExternalSpec`・`ComponentSource`・`WitPlan`）、`engine_config()`、モジュールの説明 |
| `check.rs` | W4 | 照合の段 `check_externals` |
| `path.rs` | W4 | コンポーネントのパスの解決 |
| `types.rs` | W4 | 宣言の型から `WitPlan` を作る関数、WIT の型との照合、WIT の型の表示 |
| `text.rs` | W4 | 型板に埋める語（`"the root directory"` など） |
| `convert.rs` | W5 | 値の変換（両方向） |
| `runtime.rs` | W5 | 実行ごとの状態 `ExternalRuntime`、`call`（一か所の入口）、見張りのスレッド |

### P5. どの作業でも守ること（W4・W5 に共通）

- `unsafe` を書かない。`Component::deserialize*` は使わない（Q1）。テキストを読む `Component::new` も使わず、本番の経路は `Component::from_binary` だけを使う（テストのビルドで `wat` の機能が付いても、本番と同じ振る舞いにするため）。
- 大域の可変状態を加えない。`Engine` は実行ごと（と検査ごと）に作る。wasmtime が内部に持つ大域の状態は 03-01 に書く（W4。P1 と W4-1）。
- `Config` は一つの関数 `external::engine_config()` で作り、検査と実行で同じものを使う（燃料の数え上げはコンパイルの時点で入るので、検査と実行で設定が違うと照合の結果がずれる）。中身: `consume_fuel(true)`、`epoch_interruption(true)`、`signals_based_traps(false)`、`max_wasm_stack(512 * 1024)`（既定の値を明示）、`wasm_backtrace(false)`（報告に Wasm の履歴を使わず、捕まえる費用を省く）。
- `CompiledProgram` に wasmtime の型を入れない。`CompiledProgram` には平らなデータ（パス・名前・バイト列・変換表）だけを置き、`Engine`・`Component`・`Store` は実行ごとの状態（W5）に置く。`assert_shareable`（`src/bytecode/program.rs:376-379`）はそのまま通る。

## W4 への補足

### W4-1. 依存の追加

`crates/benitoite/Cargo.toml` の `[dependencies]` に一行を足す（ほかの行と同じく `=` で固定）:

```toml
wasmtime = { version = "=49.0.2", default-features = false, features = ["runtime", "component-model", "std", "cranelift"] }
```

- `anyhow` の機能は付けない（`wasmtime::Error` は自前の型で、`Error::new`・`downcast_ref` を持つ。`wasmtime-internal-core-49.0.2/src/error/error.rs:588,1052`）。`async`・`wat`・`cache`・`parallel-compilation`・`pooling-allocator` も付けない。
- MSRV は 1.96（調査 B 1.1）で、`rust-toolchain.toml` の 1.98.1 で通る。既存の `rustix =1.1.5` は wasmtime の要求（`^1.1.4`）を満たす。
- ネットワークが使えないときは `cargo build --offline` で `Cargo.lock` を作れる（必要なクレートは `~/.cargo/registry` に取得済み）。
- テストだけの依存（`[dev-dependencies]`）として `wat = "=1.261.0"` を足すかは設計者に尋ねる（W4-7）。

測る（Q1。報告と docs/todo の TODO-176 の記録の材料。TODO-176 への書き足しは W8）:

```sh
# 足す前（依存を足す前のコミット）と足した後に、同じ三つを測る
cargo build --release -p benitoite && ls -l target/release/benitoite
strip -o /tmp/benitoite-stripped target/release/benitoite && ls -l /tmp/benitoite-stripped
/usr/bin/time -l target/release/benitoite run tools/bench/programs/fib.bnt 25 2>&1 | grep 'maximum resident'
# 外部の関数を使わないプログラムの最大 RSS が変わらないことを確かめる
```

`strip` の出力はリポジトリの外（`/tmp` か作業用のディレクトリ）に置く。

#### ライセンスと C のコード

- `deny.toml` の `allow` と `scripts/release/about.toml` の `accepted`（同じものを同じ並びで書く決まり。`about.toml` の先頭のコメント）に、`"Apache-2.0 WITH LLVM-exception"` と `"Zlib"` を足す。`"Unicode-3.0"` は今の `cargo deny check licenses` が通っている（今も `unicode-ident` を含むのに通る）ので、足した後に `cargo deny check licenses` が要求したときだけ足す。
- 03-01「依存のライセンス」の許可の一覧（`03-01-library-structure.md:79`）は今 `Apache-2.0 WITH LLVM-exception` を含まない。R7 は「03-01 の方針の範囲で」と書くが、一覧そのものに加える必要がある。許容型であること（LLVM の例外は Apache-2.0 の条件を緩める例外で、コピーレフトでない）を理由に書いて一覧に加える。00-03「利用する既存の OSS のライセンス」は 03-01 を参照するだけなので直さなくてよい。
- **03-01 の「初回リリース版の依存のクレートは、どれも C のコードを含まず、ビルドに Rust のツールチェーンだけを要する」（`03-01-library-structure.md:75`）は、wasmtime を入れると偽になる**（P1）。同じ節は `ring`・`aws-lc-rs` を C コンパイラを要するという理由で採らなかったと書いている（`:73`）。扱いは設計者に尋ねる（「設計者に尋ねること」の 1）。答えが「受け入れる」なら、W4 は次を直す。
  - 03-01「使う Rust のクレート」に用途「WASM のコンポーネントの実行（外部の関数）」の行（`wasmtime`、https://github.com/bytecodealliance/wasmtime 、`Apache-2.0 WITH LLVM-exception`）と、C のコードの文を「wasmtime の機能 `runtime` は Unix で小さな C のファイル（`helpers.c`）を C コンパイラでビルドする（出典: wasmtime 49.0.2 の `build.rs`）。ほかの依存は C のコードを含まない」に改める。`ring` を採らなかった理由の文は残す。
  - 03-01 に wasmtime の内部の大域の状態を書く（AGENTS.md「大域の状態」の決まり。jiff の段落と同じ形）: コードの登録表（`src/runtime/module/registry.rs:402` の `GLOBAL_CODE`。トラップの位置から模様を引く）、スレッドごとの活性化の記録（`src/runtime/vm/sys/std_tls.rs:3` の `TLS`）、ページの大きさの記録（`src/runtime/vm.rs:434`）、`Store` の番号（`src/runtime/store/data.rs:162`）、Wasm に入ったスレッドの sigaltstack（P1）。`signals_based_traps(false)` にしたのでシグナルの処理器は登録しないこと、その代わりに範囲の確かめが明示になり、Spectre の緩和の二つが切れること（P1）も書く。
  - 05-01「ソースからのビルド」に、ビルドに C コンパイラ（macOS は Xcode のコマンドラインツール、Linux は `cc`）が要ることを書く。musl 向けのビルドに musl の C コンパイラが要ることは、実行ファイルを配る形（docs/todo の TODO-073）の項目に書き足す（W8 で docs/todo に）。
- 05-01「ライセンスの表示」は直さなくてよい（生成の方法は変わらない）。足した後に `scripts/release/licenses.sh aarch64-apple-darwin /tmp/tpl.txt` を一度走らせ、`Apache-2.0 WITH LLVM-exception` のクレートが載ることを確かめて報告する（cargo-about 0.9.2 は手元にある）。

### W4-2. 構文（`src/syntax/parser/items.rs`。W1 は `decls.rs` を直しているので、W1 の取り込みの後の行で直す）

- 名前の検査 `attribute_name_error`（`items.rs:431-471`）: `"test" | "deprecated" | "builtin" => None` に `"external"` を足す（どのソースでも受け付ける）。
- 本体の規則 `body_rule`（`items.rs:160-166`）: `builtin` か `external` を付けたら `BodyRule::Omitted`。
- 本体を書いてしまった場合: 今の `parse_function`（`decls.rs:263-300`）は `Omitted` なら改行だけを読むので、次の行の本体がトップレベルの字句として読まれ、関係のない誤りが続く。`external` を付けた宣言で、改行の後の字句が宣言の始まり（`is_decl_start`）でもファイルの終わりでもなければ、`Required` と同じく本体を `end function` まで読み、`E0814` を報告して `body` を `None` にする。`@builtin`（標準ライブラリだけ）はこの扱いにしなくてよい。
- 引数の検査 `attribute_args_error`（`items.rs:472-486`）に `"external"` の腕: 引数がちょうど 3 個でなければ `E0809`。1 個目が `"wasm"` でなければ `E0810`（主な位置は 1 個目の引数の span）。
- 付けられる宣言の検査 `check_decl_header`（`items.rs:167-209`）: `"test" | "builtin" => function` に `"external"` を加える（関数以外は今の `E0802`）。関数の宣言なら続けて次を確かめる（`Item::Fn(f)` を見る）。
  - `f.type_params` が空でなければ `E0811`（型パラメータ・エフェクト変数・制約のどれも）。主な位置は最初の型パラメータの span から最後のものの span まで。
  - `f.uses` が `Some` なら `E0812`（R6）。修正案は `uses …` を消す編集（`help_edits`）。
  - 同じ宣言に `@test` か `@builtin` もあれば `E0813`（主な位置は後に書いた方の属性）。`@deprecated` とは併用してよい。
- トップレベルだけ: 属性はトップレベルの宣言でだけ読む（`parse_attributes` を呼ぶのは `decls.rs:35` だけ）ので、新しい規則は要らない。実装の中の関数（`implement`）は今の `E0802` になる。
- `public` は付けてよい（何もしない）。

診断の表（`src/diag/codes.rs` の E08 の節の末尾、`:889` の後）。既存の三つも直す。

| コード | message / label / 注記 |
|---|---|
| E0801（直す） | 注記 `allowed` を "the attributes are `@test`, `@test(\"...\")`, `@deprecated(\"...\")`, and `@external(\"wasm\", \"...\", \"...\")`" に。説明の文はそのまま |
| E0802（直す） | 説明に "`@external` is written on top-level functions." を足す |
| E0808（直す） | 説明を "A function needs a body, unless it is an external function declared with `@external` or a built-in function of the standard library." に。注記 `external: "to call a function of a WebAssembly component, write `@external(\"wasm\", \"path\", \"name\")` before the function"` を足し、`report_missing_body`（`items.rs:252-260`）で付ける |
| E0809 | "`@external` takes three strings: the kind, the component path, and the function name" / "" / `form: "write `@external(\"wasm\", \"wasm/fuzzy.wasm\", \"distance\")`"` |
| E0810 | "unknown kind of external function `{kind}`" / "unknown kind" / `wasm: "this version supports only `\"wasm\"`"` |
| E0811 | "an external function cannot have type parameters" / "type parameters" / `fixed: "write concrete types for the parameters and the result; the types are checked against the component"` |
| E0812 | "an external function cannot have `uses` in this version" / "remove this" / `pure: "this version calls only components that import nothing, so external functions are pure"`。修正案 `remove`（`uses` を消す） |
| E0813 | "`@external` cannot be combined with `@{other}`" / "" / [] |
| E0814 | "an external function has no body" / "remove this body" / `remove: "the component provides the body; end the declaration after the result type"` |

- 説明（`explanation`）は短い英語の 1 文。`gen_skill` で Skill の診断の文書を作り直す。
- 構文の段の誤りなので、ファイルの種類に依らない（W1〜W3 の点検 C3 と同じ考え）。

### W4-3. 名前解決（`ResolveOutput` の欄。設計者の了承が要る。P2）

- `BindingKind` は変えない。`@external` を付けた関数の束縛は今のとおり `BindingKind::Fn`（`src/resolve/collect.rs:328-339` の `kind = BindingKind::Fn` のまま）。plan の表の「`BindingKind` に列挙子を足す」は使わない。理由: 型検査・名前解決・脱糖の `BindingKind::Fn` の扱い（本体のない関数は本体の検査を飛ばす。`typeck/generate.rs:87-90`）がそのまま当てはまり、`BuiltinFn` を見る 12 か所（`resolve/lookup.rs:63,94,126`、`resolve/checks.rs:189`、`ir/desugar/effects.rs:138`、`ir/desugar/exprs.rs:115,150,268,893`、`typeck/context.rs:433`、`typeck/generate.rs:194`、`typeck/decls.rs:441`）を触らずに済むため。
- `ResolveOutput`（`src/resolve/mod.rs:118`）に欄を足す（了承が要る）:

```rust
/// `@external` を付けた関数の束縛 → 宣言の属性と照合の結果（設計書 03-10）。
/// 名前解決が属性の文字列を入れ、外部の関数の照合の段（`external::check_externals`）が `spec` を埋める
pub externals: BindingMap<crate::external::ExternalDecl>,
```

```rust
// src/external/mod.rs
pub struct ExternalDecl {
    pub module: ModuleId,
    /// 関数の宣言のノード番号
    pub decl: NodeId,
    pub kind: StrArg,   // "wasm"（構文の段で確かめ済み）
    pub path: StrArg,
    pub export: StrArg,
    /// 照合の段が埋める。照合の前と、照合が誤りを出した宣言では None
    pub spec: Option<Arc<ExternalSpec>>,
}
```

- `collect.rs` の関数の腕（`:328-339`）で、`@external` の属性があれば `externals` に入れる（構文の段の誤り `E0809`〜`E0814` があるファイルは名前解決まで進まないので、ここでは 3 個の引数を前提にしてよい。足りなければ `self.internal`）。

### W4-4. 照合の段（パイプライン）

- 置き場所: `pipeline.rs` の `check_stages`（`:249-300`）で、型検査の後、誤りがないとき（`:277` の `if` の中、`CheckedProgram` を作る前）に呼ぶ。照合の誤りがあれば `program` を作らない（`append_stage` の後にもう一度誤りの有無を見る）。

```rust
let diagnostics = crate::external::check_externals(
    entry, fs, &loaded.modules, &loaded.asts, &result.sources, &mut resolved, &types,
);
append_stage(&mut result, diagnostics);
```

  `resolved.externals` が空なら何もせず、`Engine` も作らない（外部の関数を使わないプログラムの検査の費用を変えない）。`run`・`check`・`test` はどれも `pipeline::check` を通るので、三つとも照合する（`test` は入口ごと）。`fmt` は照合しない。
- 02-01「段と段の間のデータ」「検査と実行の経路」に段を一つ書き足す（10-13 の了承の範囲）。

#### 根のパス（`LoadOutput`・`CheckedProgram` を変えない）

宣言を書いたモジュールの根は、照合の段が自分で求める。

- 種類が `Entry`・`User` のモジュール: `fs.canonicalize(&entry.root)`（`EntrySpec` は `check_stages` の引数にある）。
- 種類が `Package`（W2）のモジュール: 名前の先頭の段が依存の別名（W2 の点検「`ModuleKind` と `ModulePath`」）。別名からパッケージの正規化した根を引く。W2 が読み込みの中で作る依存の表（別名・正規化した根）を作る関数を、W4 で `pub(crate)` にして、照合の段から `entry`・`modules`・`asts`・`fs` だけで呼べる形に直す（入口の AST と根の `package.bnt`（`ModuleKind::Config`）の AST の `header` の `dependency` から作り直す）。W2 の実装を読んで名前を合わせる。同じ規則を二か所に書かない。
- `MemoryFs::canonicalize` はパスをそのまま返す（`pipeline.rs:335-337`）ので、単体テストでも同じ手順で動く。

#### パスの規則（`external/path.rs`）

R5・Q10 と、W3 のハッシュの範囲（`wasm/` の下の `*.wasm`、名前が `.` で始まる項目を辿らない）に揃える。

1. 文字列は `/` で区切った相対パス。空、`/` で始まる、`\` を含む、空の段・`.`・`..` の段を含むものは誤り（E1002。注記で理由を示す）。
2. 最後の段が `.wasm` で終わらなければ誤り（E1002）。**推す追加**（R5 にない）: パッケージのハッシュは `*.wasm` だけを含む（R10）ので、ほかの拡張子のファイルを読めるとハッシュで確かめない中身を実行できる。根のモジュールも同じ規則にして一つにする。オーケストレータが了承してから渡す。
3. パッケージのモジュールでは、最初の段が `wasm` でなければ誤り（E1003、注記 `package`）。名前が `.` で始まる段も誤り（E1002）。
4. 段ごとに `fs.list_dir` で大文字小文字まで一致する項目を探す（`src/modules/find.rs:51-92` の import の照合と同じ考え。途中の段は `is_dir`、最後の段は `!is_dir`）。見つからなければ E1001（`reason` に "no such file"）。理由: 大文字小文字を区別しないファイルシステムでも、宣言とハッシュの記録とが同じ名前を指す。
5. `fs.canonicalize` した結果が、正規化した根（パッケージなら `根/wasm`）の下になければ E1003（シンボリックリンクで外へ出る場合）。
6. `fs.read_file`。`RealFs` は普通のファイルだけを 256 MiB（`MAX_SOURCE_BYTES`）+ 1 バイトまで読む（`src/base/file_read.rs:17-32`）。長さが `MAX_SOURCE_BYTES` を超えたら E1001（`reason` に大きさ）。
7. 同じ正規化したパスは一度だけ読み、一度だけコンパイルする（`BTreeMap<PathBuf, 読んだ結果>`）。

#### コンポーネントの確かめ（`external/check.rs`）

1. 先頭の 8 バイト: `\0asm` でなければ E1004 注記 `not_wasm`、バージョンの 4 バイトが `01 00 00 00` ならコアのモジュール（E1004 注記 `core`）、`0d 00 01 00` 以外も E1004 注記 `invalid`。
2. `Component::from_binary(&engine, &bytes)`。`Err` なら E1004 注記 `invalid`（`{reason}` に wasmtime の誤りの文。外の文字列を引数に入れる形は E0916 の `reason` と同じ）。
3. `component_type().imports(&engine)` が空でなければ E1005（名前を最初の 5 個まで、`wasi:` で始まるものがあれば注記 `target`）。
4. `get_export(&engine, 名前)`: `None` なら E1006（注記に、`exports` のうち `ComponentItem::ComponentFunc` の名前の一覧）。`ComponentFunc` でない（`ComponentInstance` など。world の直下でない関数）も E1006。`f.async_()` が真なら E1011。
5. 引数の数（`f.params().len()` と宣言の引数の数）が違えば E1007。位置ごとに型を照合し（名前は照合しない。R5）、違えば E1008。戻り値: 宣言が `Unit` なら `results()` が 0 個、そうでなければ 1 個で型が一致。違えば E1009。
6. 一つの宣言の照合を通ったら `ExternalSpec` を作って `resolved.externals[b].spec` に入れる。

#### 型の対応と変換表（`external/types.rs`。W5 が使う）

宣言の型は `types.decl_types.get(binding)`（`Scheme`。`src/types/mod.rs:167`。`params`・`ret`）から読む。型の別名は展開された形で入っている（想定。単体テストで別名を使った宣言を一つ確かめる）。

```rust
/// Benitoite の型と WIT の型の対応の一つ（設計書 03-10「型の対応」）。W5 の値の変換はこの木を辿る。
#[derive(Clone, PartialEq, Eq, Debug)]
pub enum WitPlan {
    S64,            // Integer
    F64,            // Float
    Bool,           // Boolean
    Char,           // Character
    String,         // String
    U8,             // Byte
    Bytes,          // Bytes ↔ list<u8>
    List(Box<WitPlan>),     // List[T] ↔ list<T>（List[Byte] も list<u8>。宣言の型で決まる）
    Option(Box<WitPlan>),   // Option[T] ↔ option<T>
    /// Result[T, E] ↔ result<T, E>。Unit の側は WIT で省く（Result[Unit, E] ↔ result<_, E>）
    Result { ok: Option<Box<WitPlan>>, err: Option<Box<WitPlan>> },
    Tuple(Vec<WitPlan>),    // Pair[A, B] ↔ tuple<A, B>、Triple ↔ tuple<A, B, C>
}
```

- 型の見分け: `Ty::Con(TyCon::Builtin(BuiltinTypeId::INTEGER), [])` など（`src/types/builtin.rs:33-46`）。`Option`・`Result`・`Pair`・`Triple` は `TyCon::Adt(id)` で、`resolved.stdlib("Benitoite.Option.Option")`・`"Benitoite.Result.Result"`・`"Benitoite.Pair.Pair"`・`"Benitoite.Triple.Triple"` と比べる（`typeck/decls.rs:972`、`typeck/consts.rs:833` と同じ方法。`Triple` の完全な名前は `stdlib_names` で確かめる）。
- `Unit` は戻り値と `Result` の片側だけ。引数・`List`・`Option`・`Tuple` の中の `Unit` は対応なし。
- 対応のない型（`Decimal`・`Map`・`Set`・利用者の `data`・レコード・関数の型・リソースの型・`Task` など）は E1010（主な位置はその引数か戻り値の型の式。`FnDecl.params[i].ty`・`ret` の span）。R8 の「フェーズ 2 以降」の型も同じ。宣言の型が E1010 なら、その宣言のコンポーネントの照合（E1007〜E1009）は行わない。
- `WitPlan::matches(&self, &wasmtime::component::Type) -> bool` で照合する。`Type::List(l)` は `l.ty()`、`Type::Option(o)` は `o.ty()`、`Type::Result(r)` は `r.ok()`・`r.err()`（`Option<Type>`）、`Type::Tuple(t)` は `t.types()`。`Bytes` は `Type::List` の要素が `Type::U8`。
- 診断に出す WIT の型の表示は自前の関数で作る（`Type` の `Debug` は `S64` などで WIT の綴りでない）: `s64`・`list<u8>`・`option<string>`・`result<_, string>`・`tuple<s64, string>`、名前のある型は `record`・`variant`・`enum`・`flags`・`resource`・`map<…>` などの種類の名前。
- 再帰は型の深さで抑えられる（構文の入れ子の上限の内側）。AST を辿る処理と同じく再帰で書いてよい（AGENTS.md「再帰の深さ」の 1 項目め）。

```rust
pub struct ExternalSpec {
    /// プログラムの中の通し番号（照合の段が振る）。比べるときはこれだけを比べる
    pub id: u32,
    /// 診断に使う修飾した名前（`Fuzzy.Distance.distance`。脱糖の名前と同じ作り方。`ir/desugar/decls.rs:109-127`）
    pub function: String,
    pub component: Arc<ComponentSource>,
    pub export: String,
    pub params: Vec<WitPlan>,
    /// None は戻り値なし（Unit）
    pub result: Option<WitPlan>,
}
pub struct ComponentSource {
    /// 診断と報告に使うパス（モジュールの表示名のディレクトリ部分 + 宣言の文字列。`find.rs:124-133` と同じ作り方）
    pub display: String,
    pub bytes: Arc<[u8]>,
}
```

`PartialEq`・`Debug` は手で書く（`id` だけを比べ、`Debug` はバイト列の長さだけを示す。W5 の `ValKind` が `PartialEq`・`Debug` を要する）。どちらも `Send + Sync`。

#### E10 の診断（`src/diag/codes.rs` に `// ---- E10: 外部の関数 ----` の節）

| コード | message / label / 注記 |
|---|---|
| E1001 | "cannot read the component `{path}`" / "" / `reason: "{reason}"` |
| E1002 | "malformed component path `{path}`" / "" / `form: "write a relative path separated by `/` that ends with `.wasm`, without `.` or `..`"`、`hidden: "a name that starts with `.` is not part of a package"` |
| E1003 | "the component `{path}` is outside the {base}" / "" / `root: "a component of a module under the root directory must be under the root directory"`、`package: "a component of the package `{package}` must be under its `wasm` directory"` |
| E1004 | "`{path}` is not a WebAssembly component" / "" / `not_wasm: "the file does not start with the WebAssembly magic bytes"`、`core: "it is a core WebAssembly module; wrap it with `wasm-tools component new`"`、`invalid: "{reason}"` |
| E1005 | "the component `{path}` imports {count}, so it cannot be called as a pure function" / "" / `imports: "imports: {names}"`、`target: "build it for `wasm32-unknown-unknown` and wrap it with `wasm-tools component new`; `wasm32-wasip2` adds WASI imports"` |
| E1006 | "the component `{path}` has no function `{name}` at the top level of its world" / "" / `exports: "the functions it exports are {names}"` |
| E1007 | "the function `{name}` of the component takes {found}, but `{function}` declares {expected}" / "" / [] |
| E1008 | "argument {index} of `{function}` does not match the component" / "declared as `{declared}`" / `component: "the component expects `{wit}`"`、`maps: "`{declared}` is passed as `{expected}`"` |
| E1009 | "the result of `{function}` does not match the component" / 同上の形 |
| E1010 | "`{ty}` cannot be passed to or from an external function in this version" / "" / `types: "the types that can be passed are Integer, Float, Boolean, Character, String, Byte, Bytes, List, Option, Result, Pair, and Triple, and Unit as a result"` |
| E1011 | "the function `{name}` of the component `{path}` is asynchronous" / "" / [] |

- 主な位置: パスの誤り（E1001〜E1006、E1011）は 2 個目の引数の文字列、E1006 は 3 個目、E1007 は関数の名前、E1008・E1009・E1010 は型の式。
- `{count}` などの単数・複数は既存の型板の書き方に合わせる（"1 item"・"3 items"）。

### W4-5. 脱糖での扱い（W4 の範囲）

W4 では `run` を支えない。今の `ir/desugar/decls.rs:32-45` は本体のない `Fn` を飛ばすので、参照が `TopFn` になり、コード生成が「unknown top-level function」の処理系の不具合になる。W4 の間は、脱糖で `resolved.externals` にある関数を見つけたら `InternalError { stage: "desugar", message: "external functions are not supported yet" }` を返し、W4 のテストは `check` だけにする。W5 がこれを置き換える。

### W4-6. 設計書（W4）

| 章 | 節 | 内容 |
|---|---|---|
| 01-02 | 属性（初回リリース版） | 冒頭の「属性は、宣言の型付けと評価の意味を変えず」を、R5 のとおり「評価の意味を変える属性は `@builtin` と `@external` だけで、どちらも本体のない関数の宣言に付ける」に改める。利用者が書ける属性の表に `@external("wasm", "パス", "名前")` の行（付けられる宣言: トップレベルの関数。型パラメータと `uses` を書けない）。新しい見出しを足すなら「外部の関数の宣言」（既存の見出しは変えない） |
| 01-02 | 初回リリース版の文法の全体 | `ExternalFnDecl = "function" LowerIdent "(" CommaList(Param) ")" "->" Type .` を足し、`@external` を付けた宣言は `FnDecl` の代わりにこれで書くと本文で述べる（`gen_skill` の文法に載る） |
| 01-07 | 新しい節「外部の関数のエフェクト」（「外部のライブラリのエフェクトと権限の表示（初回リリース版の後）」の前） | 取り込みのないコンポーネントの関数だけを純粋な関数として型付けする。`uses` を書けない。理由（R6） |
| 01-07 | 外部のライブラリのエフェクトと権限の表示（初回リリース版の後） | 見出しは変えず、本文の「初回リリース版は…持たない」を今の範囲（外部の関数は純粋なものだけ）に合わせて直す |
| 03-10（新） | `# 外部の関数` / 目的と範囲 / 前提 / 仕様 | 仕様の節: 宣言の形、コンポーネントのパスの基準（W4-4 の規則）、照合（取り込みが空、world の直下の関数、位置での照合）、型の対応（R8 の表と `Result` の片側の省略、`List[Byte]` と `Bytes`）、作り方の例（`wasm32-unknown-unknown` と `wasm-tools component new`）。W5 が実行の節を足す |
| 03-01 | 使う Rust のクレート、依存のライセンス | W4-1 |
| 05-01 | ソースからのビルド | W4-1（C コンパイラ） |
| 02-01 | 段と段の間のデータ、検査と実行の経路 | 外部の関数の照合の段 |
| 02-04 | 束縛と表 | `ResolveOutput` の外部の関数の表（了承が得られたら） |
| 02-10 | 診断コード | `E10nn` の行、E08 の範囲の説明 |
| 00-03 | 自作する部分と既存の OSS を使う部分 | R7 の一文（WASM の実行系は既存の OSS、型の対応と境界の変換は自作）。W7 に回してもよいが、W4 で入れる方が R7 に近い |
| `docs/design/README.md` | 目次 | 03-10 の行 |

`spec_examples` は 01-spec の ```text のブロックを `check_files` で検査する（`tests/spec_examples.rs:455-483`）。01-02 に `@external` の例を置くと、コンポーネントがないので E1001 になるが、E10 は「読み込みの誤り」に数えないのでテストは失敗しない（名前解決と型検査は済む）。例は 03-10 に置いてもよい（02 以降の部は `spec_examples` が読まない）。

### W4-7. 試験用のコンポーネント（R14）

- テキスト形式は使える（P1）。ただし、テキストを変換するには `wat` のクレートが要る。wasmtime の機能 `wat` は本番の構成から外したので、テストのビルドだけの依存（`[dev-dependencies] wat = "=1.261.0"`）を足すことになる。plan の「依存のクレートを加えるのは W4 の Wasmtime（とそれが引く依存）だけ」の外なので、設計者に尋ねる（「設計者に尋ねること」の 5）。`wat` のライセンスは `Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT`、依存は `wast`・`wasm-encoder`・`bumpalo`・`leb128fmt`・`memchr`・`unicode-width`（どれも許容型）。`cargo deny` は開発用の依存も見る。
- 推す形（`wat` を足す場合）:
  - 単体テスト（`src/external/` の `#[cfg(test)]`、`pipeline` のテスト）: `wat::parse_str` で作ったバイト列を `pipeline::check_files(&[("main.bnt", src), ("wasm/x.wasm", &bytes)], …)` に渡す。`MemoryFs` が `.wasm` も読む。E1002〜E1011 と型の対応の表の各行はここで一度ずつ確かめる。
  - ゴールデン（CLI から見える形）: `testdata/external/` を新しい区分として作り、各ケースのディレクトリに `wasm/<名前>.wat` と、そこから作った `wasm/<名前>.wasm` を置く。テスト `testdata_components_match_their_text`（`tests/golden.rs` の隣か `src/external` のテスト）が、`testdata/**/*.wat` をすべて変換して隣の `.wasm` と一致することを確かめ、`BENITOITE_BLESS=1` で作り直す（`gen_skill` と同じ考え）。バイナリを手で作らず、テキストと食い違わない。
  - `wat` を足さない場合: `.wat` を正とし、`.wasm` を `wasm-tools parse`（作業用のディレクトリの `scratchpad/pkg/wasmtest/tools/bin/wasm-tools`、1.261.0）で作って置き、作り方を README に書く。一致のテストは書けない。
- 例の Fuzzy（形 2）。W2 の点検 C4 の置き場所に合わせ、根の外の共有のパッケージとして置く:

| 写す元（`scratchpad/pkg/wasmtest/fuzzy/`） | 写す先（`testdata/packages/libraries.files/fuzzy/`） |
|---|---|
| `fuzzy-unknown.component.wasm`（25,141 B） | `wasm/fuzzy.wasm` |
| `src/lib.rs` | `rust/src/lib.rs` |
| `Cargo.toml`（`wit-bindgen = "0.62.0"`、`opt-level = "s"`、`panic = "abort"`） | `rust/Cargo.toml` |
| `Cargo.lock` | `rust/Cargo.lock` |
| `wit/fuzzy.wit` | `wit/fuzzy.wit` |
| （新しく書く） | `package.bnt`（`package Fuzzy` + `license "MIT"` + `end package`、`language "0.0.3"`）、`Distance.bnt`（`study/package-samples/proposed/packages/fuzzy/Distance.bnt` を写し、コメントを短くする）、`README.md`（作り方: Rust 1.98.1、`rustup target add wasm32-unknown-unknown`、`cargo build --release --target wasm32-unknown-unknown`、`wasm-tools component new target/wasm32-unknown-unknown/release/fuzzy.wasm -o ../wasm/fuzzy.wasm`（wasm-tools 1.261.0）、`wasm-tools component wit` の出力。`lib.rs` の `path` は試しで `"wit"` に変えたので、写した配置（`rust/` から見た `../wit`）に戻す） |

  - `rust/Cargo.toml` はワークスペースの外（`Cargo.toml` の `members` は `crates/benitoite` だけ）なので、処理系のビルドは読まない。`rust/`・`wit/` はハッシュに入らない（Q10）。
  - Fuzzy のコンパイルは debug で約 0.4 秒かかる（P1）。ゴールデン 1 件で、検査・整形の前後の検査（2 回）・実行・参照インタプリタと 5 回ほどコンパイルするので、Fuzzy を使うゴールデンは 1〜2 件にし、ほかは小さな WAT のコンポーネントで作る。
- ゴールデンの整形の性質の確かめ（`tests/golden/formatting.rs:303-371`）は、`script_files`（`:124-149`）が `.bnt` だけを `MemoryFs` に入れるので、`.wasm` がなく、整形の前後とも E1001 になる。比べる性質は壊れないが、意味のある比較にするため、`script_files` が `.wasm` も集めるようにする（テストだけの変更）。

### W4-8. W4 のテスト

- 単体: 構文（`src/syntax/parser/` の `#[cfg(test)]`。E0809〜E0814、E0801・E0802 の `external`、`@deprecated` との併用が通ること、`public` が通ること）、パスの規則（`external::path`。`MemoryFs` で）、型の対応の各行と E1010、照合（E1004 の三つの注記、E1005〜E1009、E1011）。
- ゴールデン（`testdata/external/` と `testdata/packages/`）: 形 3 の `check` が通るケース（印 `// spec: 01-02 属性（初回リリース版）`、03-10 は 01-spec でないので印を付けない）、形 2（Fuzzy）の `check`、代表の誤り（E1001・E1005・E1008 など、CLI での表示を見るもの）。
- 整形: `testdata/fmt/` に `@external` の宣言を含むケース（本体のない関数の整形。`roles/walk.rs:477-486` は本体がなければ `end` を求めない）。

### W4-9. 完了の条件（共通のものに加えて）

```sh
cargo test -p benitoite --lib syntax::parser
cargo test -p benitoite --lib external
cargo test -p benitoite --lib pipeline
cargo test -p benitoite --lib resolve
cargo test -p benitoite --test fmt_command
BENITOITE_GOLDEN_FILTER=testdata/external/ cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=testdata/fmt/ cargo test -p benitoite --test golden
cargo deny check licenses
scripts/release/licenses.sh aarch64-apple-darwin /tmp/benitoite-tpl.txt   # LLVM-exception のクレートが載ること
cargo build --release -p benitoite   # 大きさの測定（W4-1）
python3 tools/spec-coverage/spec_coverage.py
# Miri の下でビルドが通ることだけを一度確かめる（テストは走らせない。下の「危険」の 3）:
cargo +nightly miri test -p benitoite --no-default-features --features gc-mark-sweep,heap-verify --lib --no-run
```

## W5 への補足

### W5-1. 経路（調査 A 3.3 の案 A を、合成した関数の形で）

外部の関数を「本体が外部の関数の呼び出し一つだけの、合成したトップレベルの関数」として脱糖する。値として使う場合（`List.map(xs, distance)`）も、直接呼ぶ場合も、今の `TopFn` の経路がそのまま使える。`ValKind::External` は合成した本体の呼び出しの頭にだけ現れる。R6 の一か所の入口もここで一つになる。

- 代わりの形（`@builtin` と同じく、直接の呼び出しを命令にし、値として使うときだけ包みの原型を作る。`bytecode/codegen/emit.rs:219-248`・`:1121`）は、主な位置が呼んだ側の式になる利点があるが、扱う箇所が増える。合成した関数の形でも、報告の呼び出しの履歴に呼んだ側の位置が出る。推すのは合成した関数の形。費用は CALL 一回（外部の呼び出しの数 µs に比べて小さい）。

#### コア IR（10-06。了承済み）

`src/ir/core_ir.rs:122-155` の `ValKind<C>` に足す:

```rust
/// 外部の関数 `@external`（設計書 03-10）。合成したトップレベルの関数の本体の呼び出しの頭にだけ現れる。
/// 型は `def` の宣言の型（`Program::schemes`）
External { def: BindingId, spec: Arc<crate::external::ExternalSpec> },
```

扱う箇所（`wildcard_enum_match_arm` を禁じているので、漏れはコンパイルの誤りで分かる）:

| 箇所 | 扱い |
|---|---|
| `ir/desugar/decls.rs:32-45` | `ast::Item::Fn(f) if f.body.is_none()` で `resolved.externals` にあれば、`getters`（`:211-295`）と同じ形で合成した `Def`（`DefKind::Fn`、`name` は `definition` と同じ作り方、本体は引数の変数をそのまま渡す `App`（頭は `ValKind::External`）の末尾の呼び出し、`eff` は空）を作る。`spec` が `None` なら `InternalError`。W4-5 の仮の誤りを消す |
| `ir/decision.rs:193`（コア IR → 下位 IR の写し） | `External { def, spec }` をそのまま写す |
| `ir/decision.rs:1946,1974,2894`、`bytecode/codegen/analysis.rs:93`、`refinterp/index.rs:52,148,286` | `ValKind::Builtin { .. }` と同じ並びに足す |
| `ir/check.rs:360` | 型は `program.schemes[def]` から作った関数の型。`ir/check.rs:1508,1646` は `Builtin` だけを扱うので触らない |
| `bytecode/codegen/emit.rs:219`（`app`） | 頭が `External` なら `EXT` を出す（下） |
| `bytecode/codegen/emit.rs:1121`（値の位置） | 現れないはずなので `internal("external function used as a value")` |
| `refinterp/eval.rs:239`（値）と呼び出し | 値の位置は上と同じく処理系の不具合。`App` の頭が `External` なら、引数を `refinterp/convert.rs` の変換でヒープの値にし、`external::call` を呼び、戻りを変換する（組み込みの関数の `refinterp/convert.rs:75-100` と同じ形） |
| `tests/desugar_export.rs`（Lean との差分テストの書き出し） | 外部の関数を含むプログラムは書き出しの対象にしない（R11 の「対象外」）。表 `tests/desugar_export/builtins.rs` には足さない |

#### バイトコード（10-07。了承済み）

- `src/bytecode/instr.rs:6-80` の `Opcode` に `Ext = 15`（14 と 16 の間の空き）。`from_u8`（`:90` の並び）、名前 `"EXT"`（`:166` の並び）。形は `abc`: A = 結果のレジスタ、B = 外部の関数の表の番号、C = 引数の先頭のレジスタ。引数の数は表から引く。
- `CompiledProgram`（`src/bytecode/program.rs:256-273`）に欄を足す:

```rust
/// 外部の関数の表（`EXT` の B が指す）。中身は平らなデータだけで、wasmtime の型を持たない（設計書 02-01「コンパイル済みプログラムと実行ごとの状態」）
pub externals: ExternalTable,
pub struct ExternalTable { pub functions: Vec<ExternalRef>, pub components: Vec<Arc<ComponentSource>> }
pub struct ExternalRef { pub spec: Arc<ExternalSpec>, pub component: u32, pub arity: u16 }
```

  `CompiledProgram { … }` を直接書いている箇所が 31 ある（`src/` と `tests/` の 23 ファイル。`grep -rn 'CompiledProgram {'`）。すべてに `externals: ExternalTable::default()` を足す。
- コード生成: `codegen/tables.rs` に `external(spec) -> u32`（`builtin`（`:285-310`）と同じく、`spec.id` で一つにまとめ、コンポーネントは `Arc::ptr_eq` かパスでまとめる）と、上限の `L0113`（`check_table`、`:302` と同じ形。上限は B が `u16` なので 65,535）。
- `program.rs:336-349` の `builtin_call_operands` の隣に `external_call_operands`。
- 生存の解析 `bytecode/liveness.rs:137`: `Prim | Io` と同じく、C から arity 個を読み、A に書く。`:306` の `waits` と `:368-380` の `writes`（呼び出しの書き込み）には入れない（待たず、切り替えない）。
- 検証器 `bytecode/verify.rs:239`（範囲）・`:374`（並び）・`:650-` のテスト「68 命令」を 69 に（テストの固定のプログラムに外部の関数の表の項目を一つ置く）。
- 逆アセンブラ `bytecode/disasm.rs:120-135`: 外部の関数の表を、修飾した名前・コンポーネントの表示のパス・関数の名前・引数の数で示す。

#### VM（10-09。了承済み）

- `src/vm/dispatch.rs:564` の `Opcode::Prim | Opcode::Io` の隣に `Opcode::Ext => return external_call(…)`。`external_call` は `#[inline(never)]` の補助の関数にする（振り分けのループを太らせない。07-02「性能の関門」）。
  1. 中断の印を読み（`cursor.interrupt`、`:1159` と同じ）、立っていれば `interrupt_call(state, Some(locals))`（`:296-304`）。
  2. 引数を `read_range`、`external::call(runtime, program, idx, ctx, &args)`。
  3. 結果を `write` し、`finish_builtin(state, ctx, locals, BuiltinEnd::Value)` と同じ後始末（確保による回収の要求を拾う）。
  4. `Err(ExternalFailure::Interrupted)` なら 1 と同じく `interrupt_call`（命令を済ませない。`CALL` の中断と同じ）。`Err(ExternalFailure::Stop(stop))` はそのまま返す（`fail_instruction` が位置を記録する）。
- `RunState`（`src/vm/state.rs:18-46`）に `pub(crate) externals: Option<Box<crate::external::ExternalRuntime>>`。最初の `EXT` で作る（下）。`Trace` は辿らない（言語の値を持たない）。

### W5-2. 実行ごとの状態と、コンパイルの時期

```rust
pub struct ExternalRuntime {
    engine: wasmtime::Engine,                          // engine_config() で作る
    components: Vec<Option<wasmtime::component::Component>>, // 表の components と同じ添字。最初の呼び出しでコンパイル
    linker: wasmtime::component::Linker<CallLimits>,   // 何も登録しない
    watcher: Option<Watcher>,                          // 中断を見張るスレッド（下）
}
```

- **コンパイルは、そのコンポーネントの関数を最初に呼んだときに一度**（推す案）。理由: `benitoite test` はテストの関数ごとに実行を作るので（`runtime/run.rs:1028` の `run_test` → `run_entry`）、実行の始めにコンパイルすると、外部の関数を呼ばないテストでも毎回コンパイルする（Fuzzy で release 約 25 ms、debug 約 0.4 秒）。検査で同じバイト列と同じ `Config` のコンパイルを通っているので、ここでの失敗は処理系の不具合（`Stop::Internal`）とする。
- `Engine` も最初の `EXT` で作る（外部の関数を使わないプログラムの実行は何も変わらない）。
- インスタンスは呼び出しごと（R9）: `Store::new(&engine, CallLimits::new())`、`store.limiter(|s| s)`、`store.set_fuel(FUEL)`、`store.set_epoch_deadline(1)`、`linker.instantiate`、`get_func(&mut store, &spec.export)`、`func.call`。`post_return` は要らない（調査 B 2）。
- 参照インタプリタは自分の `ExternalRuntime` を持つ（中断なし、見張りなし）。`refinterp::run(program, io)`（`refinterp/mod.rs:41`）の中で、最初の外部の呼び出しのときに作る。燃料は決定的なので VM と同じ結果になる。

### W5-3. 中断（epoch）

- 仕組み（P1 で確かめた形）: すべての `Store` で `set_epoch_deadline(1)`。見張りのスレッドが中断の印を 10 ms ごとに読み、立っていたら `engine.increment_epoch()` を呼ぶ。実行中の Wasm は `Trap::Interrupt` で止まり、`external::call` は `ExternalFailure::Interrupted` を返す。epoch は中断のときだけ進めるので、結果は時刻に左右されない（決定性を保つ）。`epoch_deadline_callback` は使わない。
- スレッドの寿命: `ExternalRuntime` を作るときに、印があれば起こす。`Drop` で止める（止める印を立て、`unpark`、`join`）。外部の関数を使わない実行と、印を持たない読み口（`NoInterrupt`。テストと参照インタプリタ）では起こさない。`park_timeout(10 ms)` で待つ。
- **見張りのスレッドに印を渡す口がない**: VM は振り分けの間、読み口を `IoRuntime` から借りており（`dispatch.rs:164` の `swap`）、`InterruptSource::flag()`（`runtime/io/services.rs:32-37`）は `&AtomicBool` しか返さない。実行ごとの状態に置く `'static` のスレッドに渡すには `Arc<AtomicBool>` が要る。案（設計者に尋ねる。「設計者に尋ねること」の 3）:
  - (a) 推す案: `InterruptSource` に既定の本体つきの関数 `fn shared_flag(&self) -> Option<Arc<AtomicBool>> { None }` を足し、`ProcessInterrupt`（`runtime/run/interrupt.rs:9-27`）は `Some(Arc::clone(&self.flag))` を返す（10-10 の変更。既存の関数は変えない）。`run.rs` のテストの読み口（`runtime/run.rs:718` 付近の `interrupt: Option<Arc<AtomicBool>>`）も同じ印を返せるので、中断のテストを今の形で書ける。
  - (b) 凍結の型を変えない案: `EXT` のたびに `std::thread::scope` で見張りのスレッドを起こし、`&AtomicBool` を借りて渡す。スレッドの起動と合流が呼び出しごとに加わる（費用は測っていない。数十 µs と見込む）。
- 02-09「中断の要求」の「読むのは、…だけである」と AGENTS.md「大域の状態」の中断の印の項目の、読む場所の一覧に「外部の関数の実行中に印を見張るスレッド」を加える。02-09 の同じ節の「VM は、タスクを切り替える位置と、外部に作用する操作を待つ位置で中断の印を調べる」に「外部の関数を呼ぶ前」を加える。
- `Task.withTimeout` の取り消しは外部の関数の実行中には効かないこと（Q2）を 03-10 と 01-11 の取り消しの節に書く。

### W5-4. 上限（燃料とメモリ）

- 燃料: 呼び出しごとに `set_fuel(FUEL)`。候補 `FUEL = 10_000_000_000`（10^10）。P1 の分岐だけのループで約 4.6 秒、Fuzzy の 3000×3000 の編集距離（約 5.5×10^8。調査 B 3.3）の約 18 倍。W5 で release のビルドの Fuzzy と分岐だけのループの燃料あたりの時間を測り、値と測った時間を 03-10 に書く（R9）。
- メモリ: `ResourceLimiter` を自前で実装する（`CallLimits`）。`memory_growing` は `desired > MEMORY` なら `Err(wasmtime::Error::new(MemoryLimitExceeded))` を返す（P1 で `downcast_ref` で取り出せることを確かめた。`trap_on_grow_failure` の文字列で見分ける必要がない）。`table_growing` は `desired <= 10_000`、`instances`・`tables`・`memories` は既定の値（`ResourceLimiter` の既定の本体）。
- `MEMORY` の既定値は設計者に確かめる（「設計者に尋ねること」の 7）。推す値は 64 MiB。理由: wasmtime は戻り値の `list<T>` を `Vec<Val>`（1 要素 40 バイト。P1）に持ち上げてから処理系に渡すので、ゲストが `MEMORY` いっぱいの `list<u8>` を返すと、ホストは約 40 倍を一度に確保する（64 MiB なら約 2.5 GiB、256 MiB なら約 10 GiB）。持ち上げの途中では処理系は大きさを確かめられない。
- 引数の側（Benitoite → `Val`）も 40 倍になるので、変換の前に「文字列のバイト数 + リストの要素の数（`Bytes` はバイト数）」の合計を数え、`MEMORY` を超えれば変換せずに `ResourceError::ExternalMemory` にする（どのみちゲストのメモリに入らない）。

### W5-5. 値の変換（`external/convert.rs`）

- Benitoite → `Val`: `Integer` → `Val::S64`、`Float` → `F64`、`Boolean` → `Bool`、`Character` → `Char`、`Byte` → `U8`、`String` → `Val::String(ctx.str(v)?.to_owned())`、`Bytes` → `Val::List(バイトごとの Val::U8)`、`List` → `runtime::list::to_vec`（`src/runtime/list.rs:189`）で要素を取り出し `Val::List`、`Option` → `fields_header` で `tags::OPTION_SOME`/`Value::Tag(CtorTag(tags::OPTION_NONE))` を見分ける（`builtins/table.rs:92-104`、`builtins/funcs/mod.rs:11-16`）、`Result` → `RESULT_OK`/`RESULT_ERROR`、`Pair`・`Triple` → `field(v, i)` で `Val::Tuple`。
- `Val` → Benitoite: 逆向き。文字列は `ctx.alloc_str_utf8(s.as_bytes(), …)`（R8。`runtime/heap/ctx.rs:466-476`。wasmtime が既に UTF-8 を確かめているが、規約どおり確かめる API を通す。`Ok(None)` は処理系の不具合）、`Bytes` は `CheckedLen::bytes` で確かめてから `alloc_bytes_with`、リストは `list::from_values`、構成子は `alloc_fields(FieldsKind::Ctor, tag, …)`、`Option.None` は `Value::Tag(CtorTag(tags::OPTION_NONE))`、`Unit` の側の `Result` は `Value::Unit` を中身にする。
- 大きさ（02-09「一つの操作で作る値の大きさの上限」）: 作る前に、文字列・`Bytes` のバイト数を 2^30、リストの長さを 2^24 と比べる。今の `ValueTooLarge { function: &'static str }`（`runtime/mod.rs:92-97`）には外部の関数の名前（実行時に決まる）を入れられないので、自前で比べて `ResourceError::ExternalValueTooLarge`（W5-6）を返し、R0902 で報告する。
- 辿り方: 実行時の値を辿る処理なので、リストの要素は反復で辿る（AGENTS.md「再帰の深さ」の 3 項目め）。入れ子の深さは宣言の型の深さで決まり、型の深さに対する再帰は構文の入れ子の上限で抑えられるが、規約に合わせ、変換表と値の組を積む明示の積み重ね（`Vec`）で書く。

### W5-6. 失敗の報告（10-08。了承の表にない。設計者に尋ねる。「設計者に尋ねること」の 2）

`external::call` の誤りの分け方（P1 の確かめに基づく）:

| wasmtime の誤り | 分類 | 報告 |
|---|---|---|
| `downcast_ref::<Trap>() == Some(Trap::Interrupt)` | 中断 | 報告なし、終了状態 130（W5-1 の 4） |
| `Some(Trap::OutOfFuel)` | 資源の不足 | `R0904` "the external function `{function}` used up its fuel limit of {limit}" |
| `downcast_ref::<MemoryLimitExceeded>()` が `Some` | 資源の不足 | `R0905` "the external function `{function}` needed more than the memory limit of {limit} bytes" |
| そのほかの `Trap`（`UnreachableCodeReached`・`StackOverflow`・`MemoryOutOfBounds` など。`Trap` は `#[non_exhaustive]`） | 実行時エラー | `R0601` "the external function `{function}` trapped: {trap}"（`{trap}` は `Trap` の `Display`）。注記 `component: "component `{component}`, function `{export}`"`。説明に「panic と Rust のメモリ不足も `unreachable` のトラップになる」 |
| `Trap` でも上の型でもない誤り | 処理系の不具合 | `Stop::Internal`（文はそのまま） |

足す列挙子（案）:

```rust
// RuntimeError
ExternalTrap { function: String, component: String, export: String, trap: String },
// ResourceError
ExternalFuel { function: String, component: String, limit: u64 },
ExternalMemory { function: String, component: String, limit: u64 },
ExternalValueTooLarge { function: String, size: u64, unit: SizeUnit, limit: u64 },
```

- 報告の対応は `runtime/report.rs:76-130` の `match` に足す。主な位置は `EXT` の命令（合成した関数の宣言の位置）で、呼び出しの履歴に呼んだ側が出る。
- 01-08「実行時エラーによる停止」の表に「外部の関数のトラップ」、「資源の不足」の表に「外部の関数の計算量」「外部の関数のメモリ」の行を足す。02-10 の `R06nn` の行と JSON の区分の表（`02-10-diagnostics.md:234`）。01-09「外部のライブラリの誤りとの対応」（`01-09-errors.md:135-137`）の「初回リリース版は…持たない」を、外部の関数のトラップは実行時エラーになると改める（見出しは変えない）。

### W5-7. スタック

- `max_wasm_stack` は 512 KiB。wasmtime はこれを呼んだ側のスレッドの残りから使い、残りが足りないとプロセスが abort する（調査 B 7.1）。VM は言語の呼び出しで Rust の関数を入れ子に呼ばない（AGENTS.md「再帰の深さ」）ので、`EXT` を実行するときの VM のスレッドのスタックは浅い。CLI の `run` は主スレッド（macOS・Linux とも 8 MiB）、テストの実行器とゴールデンのスレッドは 2 MiB 以上で、足りる。参照インタプリタは評価を再帰で書いていないかを確かめ（`refinterp/eval.rs`）、深い入れ子のテストの中で外部の関数を呼ぶ場合に足りるかを、深い再帰の後に外部の関数を呼ぶテストを一つ置いて確かめる。
- 段のスレッド（64 MiB）と 16 MiB で測る段のテスト（`pipeline.rs:382-389`）は、照合の段が入れ子の深さに依らないので影響しない。
- Wasm の中の深い再帰は `Trap::StackOverflow` になること（abort しないこと）を、WAT の再帰の関数で一度確かめる（`signals_based_traps(false)` でも明示のスタックの上限の確かめで捕まる、と見込む。確かめていない）。

### W5-8. 設計書（W5）

| 章 | 節 | 内容 |
|---|---|---|
| 02-09 | 新しい節「外部の関数の実行」（「中断の要求」の後。R12 で 02-13 にしない） | 実行ごとの状態（`Engine`、コンパイルしたコンポーネント、見張りのスレッド）、最初の呼び出しでのコンパイル、呼び出しごとのインスタンス、燃料とメモリの上限の値と測った根拠、中断（epoch）、失敗の分類、`Task.withTimeout` が効かないこと、シグナルの処理器を登録しないことと sigaltstack |
| 02-09 | 実行ごとの状態（表） | 「外部の関数の実行系」の行 |
| 02-09 | 中断の要求 | W5-3 |
| 02-08 | 実行ごとの状態のうち VM が使うもの、新しい節「外部の関数の呼び出し」（「組み込みの関数の呼び出し」の後） | `EXT` の手順、中断の印を読むこと、切り替えないこと |
| 02-07 | 命令の表 | `EXT`（15） |
| 02-06 | コア IR | `ValKind::External` と合成した関数 |
| 02-01 | コンパイル済みプログラムと実行ごとの状態 | 外部の関数の表（平らなデータ）と、wasmtime の型を実行ごとの状態にだけ置くこと |
| 03-10 | 新しい節「実行」（W4 の章に足す） | 利用者から見える振る舞い（上限、失敗、中断、`Task.withTimeout`） |
| 01-08・01-09・02-10 | W5-6 | |
| AGENTS.md | 実装の規約の「大域の状態」 | 中断の印を読む場所 |

### W5-9. テスト

- ゴールデン: 例の Fuzzy（形 2、`run`。`closest` で候補から選ぶ）、形 3（`testdata/external/` の WAT のコンポーネントを入口から呼ぶ `run`）。R8 の各型の往復（WAT で `list<T>`・`option`・`result`・`tuple`・`string`・`char` をそのまま返す関数を作る）は単体テストかゴールデン 1 件にまとめる。トラップ（R0601）・燃料（R0904。燃料を使い切る無限ループ。燃料を 10^10 にするとテストが数秒かかるので、上限の値を引数で受け取る内部の関数を用意し、テストでは小さな値を渡す）・メモリ（R0905）・戻り値が大きすぎる（R0902。リストの長さの上限は WAT のループで作れる）。参照インタプリタとの差分（`tests/golden/differential.rs`）は `run` のゴールデンで自動で通る。
- 中断: `tests/interrupt_process.rs` に、無限に回る WAT の関数を呼ぶスクリプトを CLI で起動し、`SIGINT` を送って終了状態 130 と報告の形を確かめるケースを足す。燃料の上限より先に中断が来るよう、送るまでの時間は 200 ms 程度にする。
- 値の変換の境界（大きさの上限ちょうどと 1 超え）は単体テストで、小さな上限を渡せる内部の関数で確かめる。

### W5-10. 呼び出しの費用の短い測定

本測定（`run.py`）は行わない（メモリの「本測定の運用」）。計算機を静かにしてから（スキル `benchmark` の「始める前に確かめること」の 1）、次を release のビルドで各 5 回測り、中央値を報告に書く（記録のファイルは作らなくてよい）:

```sh
cargo build --release -p benitoite
# a) 外部の add（WAT の s64 の足し算）を 10^5 回呼ぶ。b) 同じ足し算の Benitoite の関数を 10^5 回呼ぶ。c) 外部の関数を一度だけ呼ぶ（コンパイルの費用）
/usr/bin/time -l target/release/benitoite run <a>.bnt   # 実時間と最大 RSS
```

（a − b）/ 10^5 を一回の外部の呼び出しの費用とする。P1 の素の wasmtime で約 6 µs なので、それより大きく外れたら原因を書く。c から b を引いてコンパイルの費用を見る。

### W5-11. 完了の条件（共通のものに加えて）

```sh
cargo test -p benitoite --lib external
cargo test -p benitoite --lib bytecode
cargo test -p benitoite --lib vm
cargo test -p benitoite --lib refinterp
cargo test -p benitoite --lib ir
cargo test -p benitoite --lib runtime::report
cargo test -p benitoite --test verify --test interrupt_process --test test_command
cargo test -p benitoite --test desugar_export
BENITOITE_GOLDEN_FILTER=testdata/external/ cargo test -p benitoite --test golden
BENITOITE_GOLDEN_FILTER=testdata/packages/ cargo test -p benitoite --test golden
python3 tools/spec-coverage/spec_coverage.py
cargo build --release -p benitoite   # W5-10 の測定
```

`scripts/check-formal.sh`（R11 の差分テスト）は W8 で行う。

## 作業の間の依存

- W4 は W2・W3 の後に行う（plan のとおり）。W4 は W2 が作る `ModuleKind::Package` と依存の表（別名 → 正規化した根）と、W3 のハッシュの範囲（`wasm/` の下の `*.wasm`、名前が `.` で始まる項目を辿らない）に合わせる。W2 の依存の表を作る関数を `pub(crate)` にするのは W4 の作業に含める。
- W4 が作り W5 が使うもの: `src/external/` のモジュール、`ExternalDecl`・`ExternalSpec`・`ComponentSource`・`WitPlan`、`engine_config()`、`ResolveOutput::externals`（了承が得られたら）、照合の段、試験用の WAT のコンポーネントと一致のテスト、Fuzzy の `testdata`。
- W4 と W5 の間の状態: W4 の取り込みの後、`@external` を使うプログラムの `run` は「external functions are not supported yet」の処理系の不具合（終了状態 3）になる（W4-5）。W5 が直す。
- W6 は W4 の照合の関数を使う（R13 のエフェクトの表示で、`@external` が指すコンポーネントの一覧と取り込みが空であることを示す）。W4 は、パスの解決とコンポーネントの確かめを、照合の段の外からも呼べる関数（`pub(crate)`）に分けておく。
- W7 は 00-04 用語集（外部の関数、コンポーネント、燃料など）と 07-01 の保証（R15）、07-04 の対象外の行（R11）を書く。W4・W5 の章の語をそこで揃える。
- W8 は `scripts/check.sh` で、依存を足したことで選ばれる `licenses` と全体のビルドを走らせる。wasmtime と Cranelift のビルドが加わるので、何もない状態からの検査は前回（約 45〜50 分）より長くなる見込み。`scripts/check-heap.sh` の Miri と `scripts/fuzz-short.sh` も wasmtime を含めてビルドする（下の「危険」）。

### 危険と食い違い

1. **C コンパイラが要る**（P1）。03-01 の性質の文と食い違う。Linux で `cargo install --path` する利用者にも C コンパイラが要る。設計者に尋ねる。
2. **Spectre の緩和が切れる**（P1）。R7 の `signals_based_traps(false)` の帰結である。取り込みのない純粋なコンポーネントでも、同じプロセスのメモリを投機実行の副作用で読む攻撃の余地は残る。07-01 の脅威モデル（W7）に書く必要がある。シグナルを使う既定の構成に戻すと、wasmtime がプロセス全体のシグナルの処理器を登録する（調査 B 7.1）。設計者に確かめる。
3. **Miri**: `check-heap.sh` は `cargo +nightly miri test … --lib` でクレート全体を Miri の下でビルドする（`scripts/check-heap.sh:54-57`）。wasmtime と Cranelift も Miri の下でビルドされる。wasmtime は `cfg(miri)` で Pulley を既定にするなど Miri を考えた作りだが（`build.rs` の `default_target_pulley`）、ビルドが通るかは確かめていない。W4 で Miri のビルドだけを一度確かめる（W4-9 の最後の行）。通らなければ止めて報告する。
4. **debug のビルドの遅さ**: Cranelift の debug のビルドはコンパイルが約 15 倍遅い（P1）。テストでコンパイルする回数を抑える（W4-7）。それでも遅ければ、ワークスペースの `Cargo.toml` に `[profile.dev.package.cranelift-codegen] opt-level = 1` などを足す案があるが、ほかの依存のビルドの時間にも関わるので、測ってから設計者に相談する。
5. **ホストのメモリの膨らみ**（W5-4）。`Val` の 40 倍。
6. **`CompiledProgram` の作成箇所が 31**（W5-1）。機械的な変更だが量がある。
7. plan の凍結の表の `BindingKind`（W4）は使わずに済む（W4-3）。表に載っているが使わない、と報告に書く。

## 設計者に尋ねること

1. **C コンパイラを要する依存を受け入れるか**（W4 の前）。wasmtime の機能 `runtime` は、Unix で `helpers.c`（50 行）を `cc` でビルドし、機能では外せない。03-01 は「依存のクレートは C のコードを含まず、Rust のツールチェーンだけでビルドできる」と書き、TLS では同じ理由で `ring` を採らなかった。受け入れるなら 03-01・05-01 の文を W4-1 のとおりに改める。受け入れないなら、Q1（Cranelift を常に含める）を含めて実行系の選び方を見直すことになる（wasmtime 以外にコンポーネントを動かせる実行系は調査 B 1.2 で見つかっていない）。
2. **`RuntimeError`・`ResourceError`（10-08）に列挙子を足してよいか**（W5 の前）。R9 のトラップ・燃料・メモリと、戻り値が大きすぎる場合の報告に、実行時に決まる外部の関数の名前を持たせるため（W5-6 の 4 つ）。今の `ValueTooLarge` などは名前を `&'static str` で持つので流用できない。
3. **中断の印を見張るスレッドへの渡し方**（W5 の前）。(a) `InterruptSource`（10-10）に既定の本体つきの関数 `shared_flag()` を一つ足す（推す）／(b) 凍結の型を変えず、外部の関数を呼ぶたびにスレッドを起こす（呼び出しごとに数十 µs と見込む）。
4. **`ResolveOutput`（10-04）に欄 `externals` を足してよいか**（W4 の前）。照合の結果を脱糖と `CompiledProgram` まで運ぶ経路が、了承した変更（`BindingKind`・`ValKind`・`CompiledProgram`・パイプラインの段）だけではつながらない（P2）。代わりに `BindingKind` の列挙子は使わない。
5. **テストだけの依存 `wat`（1.261.0）を足してよいか**（W4 の前）。R14 のテキスト形式のコンポーネントを、テストの中でバイナリに変える。本番の実行ファイルには入らない。足さないなら、`.wat` から `wasm-tools` で作った `.wasm` を置き、作り方を README に書く（一致のテストは書けない）。
6. **Spectre の緩和が切れることを受け入れるか**（W4 の前、確かめだけ）。`signals_based_traps(false)`（R7）にすると、wasmtime は線形メモリと表の参照の Spectre の緩和を有効にできない。07-01 に書く。
7. **外部の関数のメモリの上限の既定値**（W5 の前、確かめだけ）。推す値は 64 MiB（W5-4。戻り値の `list<u8>` がホストで 40 倍になるため）。渡せる文字列もおよそこの大きさまでになる。燃料は 10^10 を候補に W5 で測って決める。
8. （小さな点。オーケストレータが決めてよい）コンポーネントのパスを `.wasm` で終わるものに限り、`.`・`..` と名前が `.` で始まる段を誤りにする（W4-4 のパスの規則の 1〜3）。W3 のハッシュの範囲と揃えるため。
