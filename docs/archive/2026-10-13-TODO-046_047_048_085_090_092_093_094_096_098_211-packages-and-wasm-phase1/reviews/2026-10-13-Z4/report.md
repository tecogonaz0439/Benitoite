# Z4（689b5333）のレビュー

対象: `Fix the findings of the W5, Z2 and Z3 reviews (Z4)`。worktree（`scratchpad/pkg/rev-Z4`、detached 689b5333）で debug ビルドを作り、`adv/` の入力と追加の入力を実行した。追加の入力は `scratchpad/pkg/z4rev/` に置いた。WAT から WASM への変換には、同じ target ディレクトリでビルドした小さな道具（`z4rev/wat2wasm`、`wat =1.261.0`）を使った。

## 再実行の結果（すべて期待どおり）

| 入力 | 結果 |
|---|---|
| `adv/badutf8`・`badchar`・`badopt`・`oob` | R0601、終了状態 1（以前は 3）。文言は Wasmtime の原因（`invalid utf-8 ...`、`discriminant 5 out of range`、`string pointer/length out of bounds of memory` など） |
| `adv/starttrap` | R0601、終了状態 1 |
| `adv/bigtable` | R0902、終了状態 1（20000 要素、上限 10000） |
| `adv/alias`（同じバッファを指す二つのリスト） | R0905（上限 268435456）、終了状態 1。hostcall fuel の文言の照合を実際に通る |
| `adv/bigarg`（16 MiB の `Bytes` の引数） | R0905（上限 268435456）、終了状態 1。変換前の検査で止まる |
| `adv/manymem`（10 インスタンス × 60 MiB）・`adv/initmem` | R0905（上限 67108864）、終了状態 1 |
| `adv/echo` の 3,000,000・4 MiB（4194304）・6,000,000 バイトの往復 | 成功（debug ビルドの最大 RSS は 4 MiB で約 383 MiB、6 MB で約 531 MiB） |
| 同じく 6,800,000 バイト | R0905（256 MiB の予算を超える。6.8M × 40 > 256 MiB） |
| `adv/looptest` を `benitoite test` で動かし、0.8 秒・1.5 秒後に SIGINT | 終了状態 130、`test result: FAILED. 0 passed; 0 failed; interrupted`（中断しなければ約 3 秒で R0904） |
| `adv/loop` を `run` で動かし SIGINT | 130 |

worktree で `cargo test -p benitoite --lib -- external modules`（66 件）、外部の関数のゴールデン、`--test external_signals` が通った。テストの後の `git status` は空だった。`check.sh` の `check_licenses` の Python 部分を取り出して今の `deny.toml`・`about.toml` に当てると通った。

## 所見

### M1. 一時ディレクトリをクレートのディレクトリの直下に作り、`.gitignore` にない

- 場所: `crates/benitoite/src/modules/test_support.rs:16`
- 問題: `Temporary::new` は `crates/benitoite/.module-test-<pid>-<n>` を作る。panic の巻き戻しでは `Drop` が消すので、通常の失敗では残らない。しかし、`cargo test` の Ctrl-C、`SIGKILL`、時間切れ、`panic = "abort"` では `Drop` が走らず、リポジトリの中に追跡されないディレクトリが残る。`.gitignore` に該当する行はない。このため `git status` に現れ、`scripts/check.sh` が `git ls-files --others --exclude-standard`（`check.sh:267`）で拾って検査の選択に混ざる。読み取り専用のソースの木（配布物を展開した木など）ではテストが失敗する。ほかのテスト（`cli/tools/skill/tests.rs:28`、`cli/tools/formatter/tests.rs:429`、`builtins/funcs/runtime_test_support.rs:59`、`tests/test_command.rs:32` など）はすべて `std::env::temp_dir()` を使っており、置き場所が揃っていない。Codex は「作業ディレクトリの外のファイルを変えない」という指示を優先したと報告したが、これは Codex のサンドボックスの都合であり、リポジトリの規約ではない。
- 再現: `cargo test -p benitoite --lib modules::hash` を実行中に `kill -9` すると、`crates/benitoite/.module-test-*` が残る（原理上。今回は実行していない）。
- 修正案: Z3 のレビューの修正案どおり `std::env::temp_dir()` に戻す（ほかのテストと揃う。macOS の `/var` → `/private/var` には、今と同じく `canonicalize` で対応する）。どうしてもリポジトリの中に置くなら、少なくとも `.gitignore` に `/crates/benitoite/.module-test-*` を加える。

### M2. R0905 の文言が、256 MiB の受け渡しの予算を「memory limit」と表示する

- 場所: `crates/benitoite/src/diag/codes.rs:1117`、`crates/benitoite/src/external/runtime.rs:181` 付近（`limit: TRANSFER`）、`convert.rs` の `check_arguments`
- 問題: 受け渡しの予算を超えると `the external function `f` needed more than the memory limit of 268435456 bytes` と出る。線形メモリの上限を超えたときも同じ文言で `67108864` と出る。設計書と CHANGELOG は「メモリの上限は 64 MiB」と書くので、読み手（第一の読み手は LLM）は 256 MiB の「メモリの上限」をどこにも見つけられない。直し方も違う（メモリはゲストを直す、予算は受け渡す値を小さくする）。設計原則 4（診断の明確さ）に反する。
- 再現: `adv/bigarg` と `adv/manymem` を実行し、二つの文言を比べる。
- 修正案: `ResourceError` に受け渡しの予算の種類（例: `ExternalTransfer { function, component, limit, direction }`）を加え、R0905 に注記（`transfer`: "values passed to or from an external function are limited to {limit} bytes in their host representation"）を足すか、別の文言に分ける。設計書 02-09・02-10・03-10 と Skill の生成物を合わせる。

### M3. 上限超えの分類がそろっていない（数の上限は R0601 の「trapped」、表の要素数は R0902 の「value too large」）

- 場所: `crates/benitoite/src/external/runtime.rs:153`（`instances`・`memories`・`tables` が 16）、`:204`（その他の誤りを R0601 に）、`:149`（表の要素数を R0902 に）、`codes.rs:1108`
- 問題:
  1. コアのインスタンス・メモリ・表の数の上限（16）を超えると、Wasmtime の `resource limit exceeded: instance count too high at 17` が R0601 `the external function `f` trapped: ...` になる。R20 は上限を超えたら資源の不足とすると決めており、同じ「数の上限」の表の要素数は資源の不足（R0902）、メモリの合計は R0905 になる。分類が上限の種類でばらつく。02-09 は「インスタンス化の失敗は R0601」と書いているので文書とは合うが、R20 の趣旨と合わない。
  2. 表の要素数の超過は R0902 の `` `f` would create a value that is too large `` と `the result would have 20000 elements` で示される。言語の値も戻り値も作っていないので、文言が事実と違う。
- 再現: `z4rev/inst`（同じモジュールのコアのインスタンスを 17 個）→ R0601 `resource limit exceeded: instance count too high at 17`。`z4rev/tbls`（表を 17 個）→ R0601 `table count too high at 17`。`adv/bigtable` → R0902 `the result would have 20000 elements`。
- 修正案: `instances`・`memories`・`tables` の超過は Wasmtime が独自の誤りを作るので、制限器の側で数を数え、`memory_growing`・`table_growing` と同じく専用の型で返すことはできない。代わりに、インスタンス化の前にコンポーネントの型情報からコアのインスタンス・メモリ・表の数を数えて検査するか（検査の段で E 系の診断にすることもできる）、少なくとも文言の「trapped」を避ける。表の要素数は R0905 と同じ種類の外部の資源の誤り（例: `ExternalTable { limit }`）にし、「value」「result」の語を使わない。

### L1. hostcall fuel の枯渇を `Display` の完全一致で見分ける

- 場所: `crates/benitoite/src/external/runtime.rs:181`、`crates/benitoite/src/external/text.rs` の `HOSTCALL_FUEL_EXHAUSTED`
- 調べた結果: Wasmtime 49.0.2 では、`HostcallFuelExhausted` は `runtime/component/func/options.rs:533` の非公開の型で、`LiftContext::consume_fuel` だけが作る。fuel は `LiftContext::new` が `store.hostcall_fuel()` を写して減らすので、呼び出しの後に `Store::hostcall_fuel()` を読んでも残量は分からない（設定した値が返る）。公開の誤りの型も、`Trap` の変種もない。したがって、型や残量で見分ける方法は 49.0.2 にはなく、文言の照合は避けられない。
- 危険の程度: `wasmtime` は `=49.0.2` に固定している（`crates/benitoite/Cargo.toml:41`）。文言が変わっても誤りは R0601 になり、終了状態 3 にはならない。`bytes_transfer_budget_and_empty_values` と `aliased-result` のゴールデンが本物の枯渇で分類を確かめるので、版を上げたときに検出される。今の形で受け入れてよい。
- 修正案（任意）: 完全一致でなく、文言の後半（`fuel allocated for hostcalls has been exhausted`）を含むかで見る。前半の言い回しが変わっても分類が保たれる。

### L2. 線形メモリの合計の数え方: 自身の `maximum` を超える `memory.grow` も資源の誤りになる

- 場所: `crates/benitoite/src/external/runtime.rs:131`〜`:137`
- 調べた結果: 数え方は正しい。Wasmtime は初期のメモリの作成でも `memory_growing(0, minimum, maximum)` を呼ぶので、初期のメモリと `memory.grow` の両方が合計に入る。Wasm にはメモリを縮める命令がないので、`desired < current` は起きない（起きても `checked_sub` で `u64::MAX` になり拒否される）。ストアは呼び出しごとに作るので、合計は呼び出しごとに 0 から数える。表の要素は合計に入れないが、16 個 × 10,000 要素なので小さい。
- 問題: 合計の検査（`:131`）を、自身の `maximum` を超える要求の検査（`:135`）より先に行う。コメントは「Wasm 自身の maximum を超える要求は確保されないので、合計へ加えない」と書くが、`maximum` を超え、かつ合計も超える要求は、`memory.grow` が -1 を返す（Wasm の仕様の振る舞い）代わりに R0905 で止まる。
- 再現: `z4rev/grow`（`(memory 1 2)` で `memory.grow 100000`）→ R0905 `memory limit of 67108864 bytes`。Wasm の意味では -1 が返り、処理が続く。
- 修正案: `maximum` の検査を合計の検査より前に移す。予算を超える `memory.grow` を -1 にするか停止にするかは、今の決定（停止）のままでよい。あわせて、`Ok(true)` を返した後に確保が失敗した場合（`memory_grow_failed`）は合計を戻さないので、合計が多めになることをコメントに書いておくとよい（64 MiB の範囲では起きにくい）。

### L3. 受け渡しの予算の数え方は Wasmtime と一致するが、一呼び出しのホストのピークは約 2 倍になる

- 場所: `crates/benitoite/src/external/convert.rs` の `check_arguments`、`docs/design/02-impl/02-09-runtime.md`
- 調べた結果: Wasmtime 49.0.2 の動的な持ち上げ（`values.rs`）は、リストで `len × size_of::<Val>()`（`load_list`）、タプルとレコードで `fields × size_of::<Val>()`、`Option`・`Result`・variant の存在するペイロードで `size_of::<Val>()`、文字列で `n - ptr`（UTF-8 ではバイト数。`typed.rs:1530`）を数える。`check_arguments` の数え方（`Bytes` は各バイトを `Val` 一つ、リスト・タプル・存在するペイロードは要素ごとに `Val`、文字列は UTF-8 のバイト数）はこれと一致する。リストの長さを先に数えてから要素を辿るので、長いリストを予算を超えてまで辿ることもない。違いは、ゲストが `string-encoding=utf16` を使ったときに Wasmtime が 2 倍のバイト数を数えることだけで、引数の側では問題にならない。
- 問題: 予算は方向ごとなので、エコーのような関数では引数の `Vec<Val>`（`func.call` の間生きている）と戻り値の `Vec<Val>` が同時に存在する。4 MiB の `Bytes` の往復で、debug ビルドの最大 RSS は約 383 MiB、6 MB では約 531 MiB だった。設計書 02-09 は「プロセス全体のメモリ使用量の上限ではない」と書いているので食い違いはないが、「一回の呼び出しで最大でおよそ 2 × 256 MiB と 64 MiB」と書いておくと、読み手が見積もれる。
- 修正案: 02-09 の該当の段落に一文を加える。必須ではない。

### L4. ABI 違反を R0601 にしたことで、処理系自身の値の型の不一致も R0601 に紛れる

- 場所: `crates/benitoite/src/external/runtime.rs:204`、`:283`
- 問題: `func.call` が返す、`Trap` でも専用の型でもない誤りは、すべて R0601 になる。この中には、処理系が作った引数の `Val` の型がコンポーネントの型と合わないときの Wasmtime の型検査の誤りも入る。これは 02-09 が「処理系の不具合」とする種類だが、今はコンポーネントの失敗として表示される。検査の段が型を照合しているので、起きるのは処理系の不具合のときだけである。
- 修正案: 必須ではない。直すなら、呼ぶ前に `func.params()` の型と `params` を照合する補助を置いて不一致を `internal` にするか、02-09 に「Wasmtime の型検査の誤りも R0601 に含まれる」と書く。

### L5. `check_licenses` の照合は、`deny.toml` に `[[licenses.exceptions]]` を足すと止まる

- 場所: `scripts/check.sh:72`〜`:97`
- 調べた結果: 今の二つの一覧では通る。項目の欠落と順の変更を拒否することは Codex が確かめた。分類（`scripts/release/about.toml|about.hbs` → licenses、`deny.toml` → rust と licenses）も意図どおり。
- 問題: 正規表現で節を切るので、`[[licenses.exceptions]]`（中に `allow = [...]` を持つ）は `[licenses]` の節の中に残る。cargo-deny の正当な設定を足すと `expected exactly one allow list` で止まる。リストの中の `#` のコメントも `ast.literal_eval` で失敗する。誤りの文言ははっきりしているので、黙って誤った結果を出すことはない。
- 修正案: Python 3.11 以降の `tomllib` で読む（`tomllib.load(f)["licenses"]["allow"]`）。`python3` の版が 3.11 未満の環境を支えるなら、今のままで、止まったときに直す。

## 文書

- 02-09・03-10・02-10・01-09 の分類と上限の記述は、実装と一致する（M2・M3 の文言の問題を除く）。02-09 の出典（`values.rs`、`store.rs`、`limits.rs`、`options.rs`）は、49.0.2 の取り込んだソースで内容を確かめた。
- 03-01 の「検査と実行ごとに `Engine` を作る」「`benitoite test` はテストの関数ごとに作り直す」と、`signals.rs` の行番号の直しは妥当（行番号はローカルの 49.0.2 のソースで個別には確かめていない）。
- 02-04 の E0921 の説明の直しと、06-09 の「入口の依存だけを辿り、E0922 を重ねない」は、`load.rs:185` 以降の実装と一致する。
- CHANGELOG の Unreleased は、64 MiB の合計、方向ごとの 256 MiB、R0601・R0904・R0905・R0902 の分類を書いており実装と一致する。表の数の上限 16 は書いていないが、CHANGELOG の粒度では省いてよい。
- AGENTS.md と 02-09 の見張りのスレッドの記述は、実装（最初の外部の呼び出しから実行の終わりまで）に合わせて揃っている。

## まとめ

依頼の点（ABI 違反 → R0601、4 MiB の `Bytes` の往復、予算超えの引数と戻り値 → 資源の誤り、複数メモリの合計超え → 資源の誤り、`benitoite test` の SIGINT → 130）は、すべてビルドした処理系で確かめた。H はない。M は 3 件（一時ディレクトリの置き場所と後片付け、R0905 の文言が二つの上限を区別しない、数の上限と表の要素数の分類と文言）、L は 5 件。
