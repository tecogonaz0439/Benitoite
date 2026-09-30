# 実装の規約

本章は、初回リリース版の処理系のソースコードを書くときの規約を定める。最小実行版の規約（最小実行版の実装プランの 00-02 と、AGENTS.md の「実装の規約」）を引き継ぎ、作り直しの ADR（[ADR 0258](../../design/decisions/0258-sixteen-byte-value-enum.md)〜[ADR 0272](../../design/decisions/0272-list-spread-in-list-literals.md)）で変わる点を加える。規約はできるだけ型の定義・コンパイラと lint・テストで守らせ（[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「実装の規約と静的な検査」）、道具で確かめにくい規約を本章の「文章で守る規約」に書く。C00 は、本章の「道具で確かめる規約」の設定をリポジトリに置き、「文章で守る規約」を AGENTS.md の「実装の規約」の節に写す。

## Rust の版と設定

- Rust の版は 1.98.1 のままとする（`rust-toolchain.toml`）。上げる必要が生じたら、作業を止めて報告する。
- edition は 2024、警告を誤りとする指定（`.cargo/config.toml` の `warnings = "deny"`）、リリースのビルドでの整数の溢れの検査と巻き戻しの panic は、最小実行版のとおりとする。
- Miri は nightly の Rust で動かす。Rust 1.98.1 には Miri の部品がない（2026-09-30 に確かめた）。nightly の版は `scripts/check-heap.sh` の中で固定せず、オーケストレータが導入した nightly を使う。

C00 は、ワークスペースの `Cargo.toml` の lint の表を次のように改める。最小実行版からの変更は、`unsafe_code` を `forbid` から `deny` にしたこと（[ADR 0260](../../design/decisions/0260-heap-and-unsafe-boundary.md) の決定 9）と、`unsafe` のブロックの書き方を確かめる二つの clippy の lint を加えたこと（同 決定 8）である。二つの lint が Rust 1.98.1 の clippy にあることは、2026-09-30 に `cargo clippy --explain` で確かめた。

```toml
[workspace.lints.rust]
unsafe_code = "deny"

[workspace.lints.clippy]
wildcard_enum_match_arm = "deny"
unwrap_used = "deny"
expect_used = "deny"
panic = "deny"
todo = "deny"
unimplemented = "deny"
dbg_macro = "deny"
indexing_slicing = "deny"
arithmetic_side_effects = "deny"
let_underscore_must_use = "deny"
clone_on_ref_ptr = "deny"
undocumented_unsafe_blocks = "deny"
multiple_unsafe_ops_per_block = "deny"
```

- `undocumented_unsafe_blocks`: `unsafe` のブロックの直前に `// SAFETY:` のコメントがないものを誤りにする。
- `multiple_unsafe_ops_per_block`: 一つの `unsafe` のブロックに二つ以上の `unsafe` の操作を入れたものを誤りにする。操作ごとに、守る不変条件を別々のコメントで書かせるためである。

処理系のクレートの機能（feature）は、[リポジトリとクレートの配置](00-01-repository-layout.md)の「機能（feature）」で定める。

## 完了条件の共通の検査

各作業の完了条件には、次の検査がすべて通ることを含める。C00 が `scripts/check.sh` をこの表の形に改める。最小実行版の `check.sh` は `--all-features` で lint とテストを行ったが、二つのメモリの管理の機能は同時に有効にできないので、機能の組み合わせを名指しして二度ずつ行う。

| 検査 | コマンド |
|---|---|
| 書式 | `cargo fmt --all --check` |
| lint（マーク・スイープ） | `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` |
| lint（参照カウント。第 1 段の間） | `cargo clippy --workspace --all-targets --no-default-features --features gc-refcount,heap-verify,alloc-stats` |
| テスト（マーク・スイープ） | `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify` |
| テスト（参照カウント。第 1 段の間） | `cargo test --workspace --no-default-features --features gc-refcount,heap-verify` |
| 回収の強制（両方式。第 1 段の間） | 上の二つのテストの機能に `gc-stress` を加え、ゴールデンテストと差分テストを実行する |
| 言語仕様の例 | `python3 tools/grammar-check/grammar_check.py` と、付録の例を読む `python3 tools/grammar-check/grammar_check.py doc/design/08-appendix/08-04-fp-syntax-comparison.md`。C13 が、言語仕様（`01-spec/`）と付録（08-04）の両方の例を処理系で検査する形に置き換える（07-03「言語仕様の例の検査」）。置き換えるまで道具を消さない |
| 仮置きの許可の残り | `todo!()` を一つも含まないのに、`todo!()` の仮置きのための許可（後述の「`todo!()` の仮置き」）が残っている `src/` のファイルがあれば失敗にする（`grep` で確かめる） |
| 仕様の網羅の道具の自己テスト | `python3 tools/spec-coverage/spec_coverage.py --self-test` |
| 依存のライセンス | `cargo deny check licenses` |

参照カウントの行は、第 1 段の締め（R14）で採らなかった方式の機能を消すときに、採った方式だけを残す形に改める。回収の強制の実行が遅く、`check.sh` の時間が作業の妨げになるときは、ゴールデンテストの一部だけを `check.sh` で走らせ、残りを `scripts/check-heap.sh` に移す（07-03 は、時間のかかる検査を別のスクリプトで行ってよいとした）。どの検査をどちらに置くかは C00 が決め、`check.sh` の冒頭のコメントに書く。

`scripts/check-heap.sh` は、nightly の Rust が要る検査と時間のかかる検査を行う。`runtime::heap` を変える作業（R01〜R04、R06、R11、第 2 段でヒープに触れる作業）の完了条件には、このスクリプトが通ることも含める。

| 検査 | 内容 |
|---|---|
| Miri | `runtime::heap` の単体テストと、小さな VM のプログラムのテストを、nightly の Miri で実行する。`mio` やスレッドを含む部分を Miri で動かせるかは【要検証】であり、動かなければ IO 実行器を外して実行する（ADR 0260 の決定 7） |
| 対象ごとの確保 | 機能 `heap-per-object` を有効にして、ヒープの単体テストを Miri で実行する |
| 到達可能性の比較の長い実行 | 確保・参照の書き換え・根の追加と削除を無作為に組み合わせるテストを、`check.sh` より多い回数で実行する |

## 依存するクレート

- 言語の中核と処理系の主要部は自作する。メモリの管理も自作し、GC のクレートは依存に加えない（[ADR 0271](../../design/decisions/0271-self-made-gc-as-exception.md)）。
- 依存に加えてよいのは、設計書が名指ししたクレートだけである。U1・U2 の範囲では、`mio`（IO のイベントループ。[ADR 0162](../../design/decisions/0162-event-loop-and-worker-threads-for-io.md)）と、中断の要求のシグナルの登録に使う `signal-hook` 0.4.4 と `signal-hook-mio` 0.3.0（[ADR 0163](../../design/decisions/0163-interrupt-releases-resources.md)、[02-09](../../design/02-impl/02-09-runtime.md)「中断の要求」。[README](../README.md) の「決めたこと」の 14）が当たる。二つのシグナルのクレートは、ライセンスが `MIT OR Apache-2.0`、`rust-version` が 1.66 であり、R28 が加える。対応環境は macOS と Linux だけ（[ADR 0176](../../design/decisions/0176-first-release-targets-and-static-linux-build.md)）なので、Unix 系の OS でだけ使えればよい。`Decimal` の算術はクレートを使わずに自作する（[ADR 0275](../../design/decisions/0275-self-made-decimal-arithmetic.md)、[README](../README.md) の「決めたこと」の 10）。標準ライブラリのクレート（[ADR 0138](../../design/decisions/0138-crates-and-licenses-for-stdlib.md)、[ADR 0143](../../design/decisions/0143-http-and-tls-crates.md)）は U3 の作業が加える。
- `mio` は R26 が加える。2026-09-30 に `cargo info` と crates.io の配布物の `Cargo.toml`・`src/lib.rs` で確かめた最新の版は 1.2.3 であり、ライセンスは `MIT`、`rust-version` は 1.71 である。機能は、既定の `log` を外し（`default-features = false`）、`Poll`・`Registry`・`Waker` に要る `os-poll` と、標準入出力などの記述子を登録する `mio::unix::SourceFd` に要る `os-ext` を有効にする（`os-ext` は `os-poll` を含む。ソケットの `net` は U3 の HTTP の作業が加える）。Unix 系の OS で `mio` が使う依存は `libc` 0.2（ライセンスは `MIT OR Apache-2.0`）だけである。`signal-hook-mio` 0.3.0 の機能 `support-v1_0` は `mio` 1.x を機能 `net` と `os-ext` 付きで要求するので、R28 がこのクレートを加えた後は、機能の統合により `mio` の `net` も有効になる。R26 の時点で 1.2.3 より新しい 1.x の版があれば、その版の文書で機能の名前が変わっていないことを確かめて使い、版を完了の報告に書く。
- クレートを加える作業は、作業の文書にクレートの名前と版を書く。加えるときは `cargo deny check licenses` で確かめ、ADR 0138 の決定 3 の許可の一覧のうち実際に要るものだけを `deny.toml` に加える。
- テストのための依存（`[dev-dependencies]`）も加えない。コンパイルの失敗のテストは、rustdoc の `compile_fail` の例で書く（後述の「コンパイルの失敗のテスト」）。
- 外部のコードを写さない。写す必要が生じたときは、作業を止めて報告する（[ADR 0003](../../design/decisions/0003-license.md)）。

## 文章で守る規約

### 型とシグネチャを変えない

`10-interfaces/` の `file=` のコードと `sig=` のシグネチャは、変えずに中身を書く。欄や引数を加える・変える・消す必要が生じたら、実装を進めずに報告する（[作業の進め方](00-03-workflow.md)の「型やシグネチャを変える必要が生じたとき」）。非公開の補助の関数と型は、自由に加えてよい。

### `todo!()` の仮置き

C01・C02 は、`tools/extract_interfaces.py place` でインターフェースを置く。道具は、`sig=` の関数の宣言を、本体が `todo!()` の関数（`todo!()` の仮置き）として書き、仮置きを置いたファイルの先頭（`//!` の行の後）に次の許可とコメントを置く。置いた直後のクレートがコンパイルでき、`scripts/check.sh` を通るようにするためである（C01・C02 の後も、どの取り込みの後もクレートがコンパイルできる。[作業の進め方](00-03-workflow.md)の「最小実行版の実装からの移行」）。10-12 の組み込みの関数の「仮の本体」（名前・権限・引数の数だけが正しく、呼ばれたら処理系の不具合を返す関数）とは別のものである。

```rust
// 仮置きのための許可: 道具が置いた `todo!()` の仮置きのために、lint の clippy::todo と、仮置きが
// 使わない引数への unused_variables を許す。このファイルの `todo!()` をすべて本体に書き換えた
// 作業が、このコメントと次の属性を消す（実装プラン 00-02「`#[allow]` を書いてよい箇所」）。
#![allow(clippy::todo, unused_variables)]
```

- 作業は、受け持つ関数の `todo!()` を本体に書き換える。完了のときに、受け持つ関数に `todo!()` を残さない。
- 作業を終えるときにファイルに `todo!()` が一つも残っていなければ、その作業が許可とコメントを消す。一つのファイルの関数を複数の作業が受け持つとき（10-08 の `runtime/heap/ctx.rs` など）は、最後に `todo!()` を書き換えた作業が消す。`todo!()` のないファイルに許可が残っていると、`scripts/check.sh` が失敗する（「完了条件の共通の検査」の「仮置きの許可の残り」）。
- 仮置きの許可を、道具が置いたファイル以外に書き足さない。作業が新しく書くコードで `todo!()` を使わない。
- U1・U2 の作業をすべて終えた時点で、`src/` に `todo!()` と仮置きの許可は残らない（[すべての作業を終えた後に行うこと](../90-after-completion.md)）。移行の締め（C18）は、その時点で残っている仮置きのファイルと、それを受け持つ未了の作業を完了の報告に挙げる。

### 失敗を panic で表さない

- 言語の規則で定めた失敗（除算の 0、IO の失敗など）は、`Stop` か `Err` の値として返す（[ランタイム](../../design/02-impl/02-09-runtime.md)の「panic 境界」）。
- 型検査を通ったプログラムでは起きないはずの状態（表を引いて結果がない、値の種類が違う）は、脱糖とコード生成では `InternalError`、実行中は `Stop::Internal` として返す。
- 読み込みのときの検証器を通したうえで振り分けのループの範囲の確かめを省くかは、[OPEN-064](../../design/open-issues.md#open-064) で決める（R32）。省くことにした場合に限り、省いた確かめについては「`Stop::Internal` で返す」を「検証器がプログラムを拒む」に読み替える規則を、本節と AGENTS.md に加える。それまでは、すべての確かめを実行中に行う。
- `unwrap`・`expect`・添字（`v[i]`）は lint で禁じている。`get` と `?`、`let ... else` で書く。

### `unsafe` の書き方

- `unsafe` を書いてよいのは、`runtime::heap` の内部の層だけである（[リポジトリとクレートの配置](00-01-repository-layout.md)の「`unsafe` を書いてよいモジュール」）。
- `unsafe` のブロックは、操作を一つだけ含め、直前に `// SAFETY:` のコメントで、その操作が前提とする不変条件と、それがなぜ成り立つかを書く（lint が形だけを確かめ、中身は確認の観点で読む）。
- 内部の層の各ファイルの先頭の `//!` のコメントに、そのファイルが守る不変条件の一覧を書く。`// SAFETY:` のコメントは、その一覧の項目を名指しして引く。
- `unsafe fn` を公開の層に出さない。内部の層の `unsafe fn` には、呼び出し側が守る条件を `/// # Safety` の節で書く。

### 回収しない区間と値の扱い

言語の値は `Value<'epoch>` の形で扱う（[ADR 0260](../../design/decisions/0260-heap-and-unsafe-boundary.md) の決定 3・4）。`'epoch` は回収しない区間の寿命であり、区間の中の処理は `NoGcCtx<'epoch>` を受け取る。

- `Value<'epoch>` を、区間より長く生きる場所（構造体の欄、`static`、作業用のスレッドへ渡す値）に置かない。型の上でも置けないように作ってあり、置こうとするとコンパイルの誤りになる。
- 安全点を越えて使う値は、安全点へ戻る前に VM の保存領域（レジスタ、枠、根の保存領域）に置く。保存領域から読み直した値は、新しい区間の `Value<'epoch>` になる。
- `NoGcCtx<'epoch>` は回収の機能を持たない。回収を行えるのは、VM が安全点で呼ぶ関数だけである。
- 別の実行のヒープの値を混ぜない。混ぜられないように型の印か検査付きの参照で作ってある（ADR 0260 の決定 5）。
- 書き込みの障壁を差し込む位置（セルの書き込み、`Lazy` の結果の書き込み、タスクの結果の書き込み、継続の状態の変更）は、公開の層の決まった関数だけで書く（[ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 7）。対象の中身を直接書き換える関数を、公開の層に加えない。

### 言語の値を作る経路

言語の値のヒープの対象は、`runtime::heap` の公開の層の関数（`NoGcCtx` が持つ関数）だけで作る。対象を指す値は、`runtime::heap` の外から作れないようにしてある。最小実行版の「`runtime::heap::Heap` の関数だけで作る」（[ADR 0078](../../design/decisions/0078-reference-counting-in-minimal.md)）を、この形に改める。

### 組み込みの関数の書き方

組み込みの関数は、型付きの形で書く（[ADR 0261](../../design/decisions/0261-typed-builtin-interface.md)）。詳細は 10-11 で凍結する。

- 実装者は、名前と型の付いた引数を受け取る関数と、その宣言だけを書く。引数の読み出しと登録の表は、`macro_rules!` による宣言のマクロが宣言から作る。内部の共通の形（`Ctx` と引数を受け取り、応答か停止を返す関数）を直接書かない。
- 関数は、権限に合った文脈を受け取る。純粋な関数は、時計・乱数・リソースに触れず、待つ・タスクの起動・終了を返せない文脈を受け取る。
- 値を作る関数は、確保の前に大きさを確かめる（[ADR 0049](../../design/decisions/0049-size-limit-for-built-values.md)）。確かめた長さを受け取る確保の関数か、上限付きの構築器を使う。外部のバイト列から文字列の値を作るときは、UTF-8 を確かめる文字列の値の API を通す。
- 作業用のスレッドに渡す仕事と結果は `Send + 'static` の型にし、言語の値を含めない。完了を言語の値に変える処理は、環境を捕えない `fn` ポインタで書く。待つ間に要る言語の値は、閉包に捕えず、枠のレジスタに残す。
- 完了の保存、起動する関数の登録、取り消しとの競合、リソースの返却は、共通の部分が行う。個々の組み込みの関数に書かない（[ADR 0266](../../design/decisions/0266-task-and-resource-state-machines.md)）。

### 大域の状態

処理系のどの段も、`static mut`・`thread_local!`・`OnceLock` などの大域の可変状態を持たない（[ADR 0015](../../design/decisions/0015-shared-program-per-execution-state.md)）。例外は、AGENTS.md の「大域の状態」の三つ（panic hook の記録、機能 `alloc-stats` の計数器、中断の印）と、ヒープの番号を割り当てる計数器（プロセスで一つの `AtomicU32`。`Heap::new` だけが増やす。[ADR 0281](../../design/decisions/0281-heap-number-in-slot-and-contract-safety.md)、10-08「根の保存領域」）だけである。ヒープは実行ごとに持ち、大域の確保器の状態を作らない。回収の要求と予算は実行ごとの状態に置く。

### 再帰の深さ

最小実行版の規約のとおりとする。

- AST と、AST から作る中間表現を辿る処理は、再帰で書いてよい。
- 実行時の値を辿る処理（構造の `==`、マーク、参照カウントの解放の連鎖、到達可能性の計算、リストの走査）は、明示の積み重ね（`Vec`）で書く。
- 言語の関数の呼び出しで Rust の関数を入れ子に呼ばない（[ADR 0016](../../design/decisions/0016-calls-off-go-stack.md)）。VM と参照インタプリタの両方に適用する。
- 処理系のテストは、深い入れ子と長いリストの場合を含める。スレッドのスタックの大きさを変えてテストを通すことはしない。

### 数値の変換

`as` による数値の変換は、値が収まることが明らかな箇所（命令の符号化など）に限る。そのほかは `u32::try_from` などを使い、失敗を処理系の不具合として扱う。

### `#[allow]` を書いてよい箇所

lint を個別に許す `#[allow(...)]` は、次の箇所だけに書き、許す理由をコメントで書く。最小実行版の表からの変更は、`runtime::heap` の内部の層の行と `todo!()` の仮置きの行を加え、`src/lib.rs` の行を作業の途中の間だけに限ったことである。

| 箇所 | 許す lint | 理由 |
|---|---|---|
| `src/runtime/heap/` の内部の層のファイル（10-08 がファイルを指定する） | `unsafe_code` | 確保器と生のポインタを扱う（ADR 0260）。公開の層のファイルには書かない |
| `src/lib.rs` | `dead_code` | 作業の途中では、後の作業が使う欄が読まれない。C01 で置き、移行の締め（C18）で外す |
| `tools/extract_interfaces.py place` が `todo!()` の仮置きを置いたファイルの先頭（道具が置く。前述の「`todo!()` の仮置き」） | `clippy::todo`・`unused_variables` | 後の作業が本体を書くまで、置いた直後のクレートをコンパイルでき lint を通るようにする。そのファイルの `todo!()` をすべて書き換えた作業が消す |
| テストのモジュール（`#[cfg(test)] mod tests`）と `tests/` の各ファイル | `clippy::unwrap_used`・`clippy::expect_used`・`clippy::panic`・`clippy::indexing_slicing`・`clippy::arithmetic_side_effects` | テストの失敗は panic で表す |
| `src/cli/` と IO 実行器の `BENITOITE_DEV_PANIC` の処理 | `clippy::panic` | 処理系の不具合の報告をテストするために、意図して panic を起こす |
| `src/bytecode/program.rs` の `assert_shareable` | `dead_code` | 呼ばれない関数で、型の性質をコンパイルの時点で確かめる |
| `src/legacy/` の下の、最小実行版が許した箇所（C04 が移した `cli/mod.rs`・`runtime/real_io.rs` の `BENITOITE_DEV_PANIC` の処理、`bytecode/program.rs` の `assert_shareable`、テストのモジュール） | 最小実行版の表のとおり | 最小実行版の実装を移行の間だけ残す（[リポジトリとクレートの配置](00-01-repository-layout.md)の「移行の間の配置」）。C18 が `legacy` とともに消す |

振り分けのループの `unsafe`（OPEN-064）を許すことにした場合は、その箇所を R32 がこの表と AGENTS.md に加える。これ以外の箇所で許す必要が生じたら、作業を止めて報告する。

### 文言

診断・報告の文言は英語で書き、`diag::codes` の表と `cli::text` にまとめる（[ADR 0033](../../design/decisions/0033-english-diagnostic-messages.md)）。処理を書く関数の中に英語の文を直接書かない。型板に埋める値やほかの報告の文は、それぞれのモジュールの `text` という子のモジュールに定数としてまとめる（最小実行版の規約のとおり）。`Stop::Internal` と `InternalError` の説明の文字列は、処理系の不具合を調べるためのもので、診断の表にも `text` にも載せない。

### コメントと名前

- 識別子は英語で書く。コメントは日本語で書く。コメントは「何をするか」より「なぜそうするか」を書き、根拠になる設計書の章と節を `（設計書 02-08「実行の手順」）` の形で示す。
- 各モジュールの先頭に `//!` のコメントを置き、そのモジュールの役割と、対応する設計書の章を書く。
- 公開の関数と型には `///` のコメントを書く。10-interfaces のコメントはそのまま残す。

## テストの規約

- テストを書く・変える・見直すときは、スキル `test-audit` に従う（[処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「テストの設計の原則」）。
- VM と `runtime` のテストは、両方のメモリの管理の機能で通るように書く（第 1 段の間）。一方の方式だけに意味のあるテスト（参照カウントの循環の回収など）は、`#[cfg(feature = ...)]` でその方式に限る。
- コンパイルの失敗のテスト（区間の外への値の持ち出し、別のヒープとの混用、作業用のスレッドへの値の持ち出し、組み込みの関数の権限の誤り）は、公開の型の `///` のコメントに rustdoc の `compile_fail` の例として書く。例ごとに、どの規則を破る例かをコメントで書く。この形がワークスペースの lint と警告の設定の下で期待どおりに働くか（誤りの理由を取り違えて通らないか）は【要検証】であり、C01 で確かめる。働かなければ、作業を止めて報告する。
- 実行のスケジュールに依存するテストは、テスト用に切り替えの順序を与えるスケジューラと、仮想の時間で書く。実時間の待ちや、スレッドの実行の順序の偶然に頼らない。この仕組みは [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md)の「順序を与えるスケジューラと仮想の時間（初回リリース版）」（ADR 0274）が定め、R25 が作る。
