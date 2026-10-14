# W5（81828fa6「Call external functions in WASM components」）のレビュー

対象: `git show 81828fa6`。別の worktree（81828fa6 に detach）で debug ビルドを作り、敵対的なコンポーネントを `wat` で作って実行した。再現に使った入力は `scratchpad/pkg/adv/{badutf8,badchar,badopt,oob,bigtable,alias,echo,bigarg,manymem,loop,looptest,initmem,starttrap,tasks}/` に残してある（`main.bnt` と `x.wat`・`x.wasm`）。

確かめて問題がなかった点:

- EXT の生存解析・検証器・逆アセンブラ: `reg_use` は C から表の arity 個を読み A に書く。検証器は範囲と表の整合を確かめる。L0113 も入っている。
- GC の安全: `external_call` は引数を読んでから結果を書くまで一つの `NoGcCtx` の区間の中にいる。Wasm の呼び出しの間も、`from_wasm` の確保の間も回収は起きない。確保による回収の要求は `finish_builtin` が拾う。言語の値は区間の外に持ち出していない。戻り値は `alloc_str_utf8`・`CheckedLen::bytes`＋`alloc_bytes_with`・`list::from_values`・`alloc_fields` を通り、作る前に大きさを確かめている。
- 変換は明示の作業列で行い、再帰していない。R8 の各型の往復、`Result` の Unit の側、空のリスト、入れ子は、ゴールデンと単体テストで確かめてある。
- 燃料切れ（R0904、終了状態 1）、`memory.grow` と初期メモリの上限超え（R0905）、start 関数でのトラップ（R0601）は正しく分類される。`benitoite run` で無限ループに SIGINT を送ると終了状態 130 で止まる（約 1 秒で送って確認）。debug ビルドで燃料 10^10 を使い切るまで約 4.5 秒かかる。
- TaskGroup の二つのタスクから外部の関数を 2,000 回ずつ呼んでも正しい（VM は単一スレッドで、EXT の間は切り替えない）。`Task.withTimeout(10, spin)` は文書どおり取り消されず、R0904 で止まる。
- 見張りのスレッド: 共有の印があり、かつ最初の EXT があったときだけ起こす。`Drop` で unpark してから join する。大域の状態は加えていない。
- 参照インタプリタは同じ `external::call` を通り、見張りのスレッドを持たない。
- 凍結した型の変更（`RuntimeError`・`ResourceError` の列挙子、`InterruptSource::shared_flag`、`CompiledProgram::externals`、`Opcode::Ext`、`ValKind::External`、`RunState` の欄）は、Q14 と plan の了承の表の範囲に収まっている。
- `cargo test --lib external`（24 件）、`--lib refinterp`、`--test external_signals --test interrupt_process` は worktree で通った。

---

## H1. ゲストの ABI 違反が処理系の不具合（終了状態 3）として報告される

- 場所: `crates/benitoite/src/external/runtime.rs:147`（`None => ExternalFailure::Stop(internal(e))`）。文書側は `docs/design/02-impl/02-09-runtime.md` の「外部の関数の実行」の「トラップでも専用の誤りでもない Wasmtime の失敗は、検査済みの契約との不一致として処理系の不具合にする」。preflight W5-6 の表も同じ誤りを含む。
- 問題: Wasmtime は、戻り値の持ち上げやインスタンス化の失敗の多くを `Trap` ではなく `bail!` の誤りで返す。どれもコンポーネントの側の誤りなのに、処理系の不具合の報告（"this is a bug in the implementation; please report it"）になり、終了状態は 3 になる。R9 は「トラップは実行時エラー」としており、利用者と LLM に誤った原因を示す。
- 再現（すべて `benitoite run main.bnt` で exit=3、`internal compiler error`）:
  - `adv/badutf8`: 戻り値の string が `\ff\fe` → "invalid utf-8 sequence of 1 bytes from index 0"
  - `adv/badchar`: char が 0xD800 → "converted integer out of range for `char`"
  - `adv/badopt`: option の判別子が 5 → "discriminant 5 out of range [0..2)"
  - `adv/oob`: string の長さが 0x7fffffff → "string pointer/length out of bounds of memory"
  - `adv/bigtable`: `(table 20000 funcref)` → "table minimum size of 20000 elements exceeds table limits"（`table_growing` が `Ok(false)` を返すため）
  - `adv/alias`・`adv/echo`: hostcall fuel の枯渇（H2）→ "too much data is being copied between the host and the guest"
- 修正案: `instantiate`・`get_func`・`func.call` から返った `Trap` 以外の誤りは、コンポーネントの失敗として実行時エラーにする（R0601 の `trap` に `e` の表示を入れるか、R06nn に「不正な値を返した」を新設する）。`Stop::Internal` は、処理系自身の変換表と値の不一致（`convert.rs` の `invalid()`）、`Component::from_binary` の失敗、`get_func` の欠落だけに限る。`table_growing` の上限超えは `MemoryLimitExceeded` と同様に専用の型で返し、R0905 か R06nn にする。02-09・03-10 の該当文を直し、上の各ケースをゴールデン（`testdata/external/`）に加える。

## H2. 戻り値の大きさの実際の上限は Wasmtime の hostcall fuel（128 MiB）で決まり、文書の 2^30 バイト／2^24 要素に届かない

- 場所: `crates/benitoite/src/external/runtime.rs:203-205`（`Store` を作るときに `set_hostcall_fuel` を設定していない）、`convert.rs:236,243,283`（`check_size` は持ち上げの後に走る）。文書側は `docs/design/03-interop/03-10-external-functions.md` の「実行」（「戻り値の文字列と `Bytes` は 2^30 バイト、リストは 2^24 要素の上限」）と、02-09 の「戻り値の持ち上げの途中には処理系の上限の検査を挟めず、このメモリ上限はホストのメモリ使用量の上限を保証しない」。
- 問題: Wasmtime 49.0.2 の `Store::set_hostcall_fuel` は既定で 128 MiB である（`wasmtime-49.0.2/src/runtime/component/store.rs:27` の `DEFAULT_HOSTCALL_FUEL = 128 << 20`）。動的な `Val` での持ち上げは、リストの要素ごとに `size_of::<Val>()`（40 バイト。worktree で確かめた）を、文字列ごとにバイト数をこの燃料から引く（`values.rs:232,1031`、`typed.rs:1530`）。そのため `list<u8>` と `list<s64>` の戻り値は約 335 万要素（128 MiB ÷ 40）を超えると失敗し、H1 のとおり処理系の不具合になる。一方、文書の「持ち上げの途中では上限を確かめられない」は事実と違う。Wasmtime はゲストからホストへのデータ量をこの燃料で制限しており、別名を使った増幅（`adv/alias`）もここで止まった（最大 RSS 166 MB）。
- 再現: `adv/echo`（`Bytes` をそのまま返すコンポーネント）に 4 MiB を渡すと exit=3（"fuel allocated for hostcalls has been exhausted"）、3,000,000 バイトなら成功する。
- 修正案: hostcall fuel を明示して設定し（ホストに割く上限として値を決める）、枯渇を利用者向けの資源の不足（R0902 か R0905）として報告する。誤りに型がないので、`func.call` の誤りの文言で見分けるのは脆い。少なくとも H1 の修正で実行時エラーにし、文書には実際に効く上限（`Val` の要素あたり 40 バイトで数えた hostcall fuel）を書く。03-10 の 2^30／2^24 は「処理系の確かめ」として残してよいが、それより先に hostcall fuel が効くことを明記する。4 MiB 程度の `Bytes` の戻り値のゴールデンか単体テストを加える。

## M1. `benitoite test` では Wasm の実行中の SIGINT が効かず、中断も失われる

- 場所: `crates/benitoite/src/cli/tools/test_runner/mod.rs:268-278`（`SharedInterrupt` が `shared_flag` を中の読み口へ渡していない。直上のコメントは `attach`・`flag` について同じ落とし穴を書いている）。
- 問題: 既定の本体が `None` を返すので、テストの実行では見張りのスレッドが起きない。02-09「中断の要求」と 03-10「実行」は、`run` と `test` で Wasm の実行中にも中断を受け付けると定めている。
- 再現: `adv/looptest`（`@test` の関数から無限ループの外部の関数を呼ぶ）を `benitoite test main.bnt` で動かし、1 秒後に SIGINT を送ると、燃料切れまで走り続ける。その後 `FAILED`（R0904）と表示して **exit=1** で終わり、130 にならない（中断の要求は捨てられる）。
- 修正案: `SharedInterrupt` に `fn shared_flag(&self) -> Option<Arc<AtomicBool>> { self.0.shared_flag() }` を足す。`tests/interrupt_process.rs` か `tests/test_command.rs` に、`test` の Wasm 実行中の SIGINT で 130 になるケースを加える。

## M2. 引数の側の大きさの上限が、ホストの確保（`Val` で 40 倍）を抑えていない

- 場所: `crates/benitoite/src/external/convert.rs:73-110`（`check_arguments` が文字列のバイト数と要素の数を数え、`MEMORY`＝64 Mi 単位と比べている）、`convert.rs:140-146`（`Bytes` を 1 バイトずつ `Val::U8` にする）。文書側は 02-09「外部の関数の実行」の理由（「Val は 1 要素 40 バイト…」）。
- 問題: 上限が 64 Mi 要素なので、`Bytes` の引数で最大約 2.5 GiB の `Vec<Val>` を確保できる。その後でゲストのメモリの上限（R0905）に当たる。hostcall fuel はホストからゲストへの向きを制限しない。理由の文（40 倍になるから先に数える）と上限の値が噛み合っていない。
- 再現: `adv/bigarg` で 16 MiB の `Bytes` を渡すと、最大 RSS は 795 MB（debug）。64 MiB に近づけると約 3 GB と見込む（実行はしていない）。
- 修正案: 要素ごとに `size_of::<Val>()`、文字列ごとにバイト数を足し、ホスト側の予算（例: 戻り値の hostcall fuel と同じ値）と比べる。文書の数え方と上限の説明を合わせて直す。

## M3. メモリの上限は線形メモリ一つごとで、呼び出し全体の合計を抑えていない

- 場所: `crates/benitoite/src/external/runtime.rs:102-123`（`memory_growing` が `desired` だけを見ており、`instances`・`memories` は既定の 10,000）。commit message は "64 MiB of memory per call"、Q15 は「メモリは 64 MiB」としている。02-09・03-10・CHANGELOG は「一つあたり」と書いている。
- 問題: コアのインスタンスを複数持つコンポーネントは、64 MiB × 個数のメモリを使える（理論上は 10,000 個）。
- 再現: `adv/manymem`（960 ページのメモリを持つモジュールを 10 回インスタンス化し、start 関数で 60 MiB を埋める）は成功し、最大 RSS は 668 MB。
- 修正案: `CallLimits` に合計の欄を持ち、`desired - current` を足して合計を 64 MiB と比べる。`instances()`・`memories()`・`tables()` を小さい値にする。設計者の意図が「一つごと」なら、Q15 との対応と、合計が抑えられないことを 02-09 に書く（docs/todo に項目を足す）。

## L1. 03-01 の「検査ごとに `Engine` を作る」が古い。`test` ではテストごとにエンジンを作り、コンパイルし直す

- 場所: `docs/design/03-interop/03-01-library-structure.md:78`。実行ごとの `ExternalRuntime`（`runtime.rs:46`）も `Engine` を作るようになった。
- `benitoite test` はテストの関数ごとに実行を作るので、外部の関数を呼ぶテストごとに Engine の作成、コンパイル（preflight の見積もりで Fuzzy は debug 約 0.4 秒）、見張りのスレッドの起動が起きる。仕様違反ではない。03-01 の文を「検査と実行ごと」に直す。`test` の一回の起動の中で Engine と `Component` を共有する案を docs/todo に残すとよい。

## L2. 見張りのスレッドは、最初の EXT の後、実行が終わるまで 10 ms ごとに起き続ける

- 場所: `runtime.rs:69-76`。AGENTS.md「大域の状態」と 02-09 は「外部の関数の実行中に印を見張るスレッド」と書いているが、実際には実行の最後まで読み続ける。害は小さい（毎秒 100 回起きるだけ）。文言を「最初の外部の呼び出しから実行の終わりまで」に直すか、呼び出しの間だけ unpark して動かす。

## L3. テストの穴

- H1 と H2 のケース（不正な UTF-8・char・判別子・範囲外のポインタ・表の上限・hostcall fuel の境界）、`test` での SIGINT（M1）、`Float` の NaN と無限大の往復、空の文字列と空の `Bytes` の戻り値が、どのテストにもない。
- `tests/external_signals.rs` は 200 ms 待ってから送る。シグナルが EXT より前に届いても、呼ぶ前の印の確かめで 130 になるので、このテストだけでは「Wasm の実行中に止まる」ことを保証しない。単体テスト `epoch_interrupts_running_wasm_and_watcher_joins` が補っているので、L とする。

## L4. 短い性能測定が未実施

- plan の W5-6 にある呼び出しの費用と燃料あたりの時間の短い測定は、Codex の報告どおり行っていない。03-10 の燃料の根拠は消費量だけで、時間（debug で約 4.5 秒／10^10。この review で測った値）は書いていない。W8 までに測るか、未測定として扱う。

---

### 推奨する対応の順

H1 と H2 は根が同じ（`Trap` 以外の誤りの分類と hostcall fuel）なので、一緒に直す。M1 は 1 行の修正とテスト一件で済む。M2 と M3 は上限の数え方を決める必要があり、M3 は設計者に「合計か一つごとか」を確かめる。
