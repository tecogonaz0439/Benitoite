# 実装の規約

本章は、処理系のソースコードを書くときの規約を定める。設計書の[処理系のテスト戦略](../../2026-09-27-design-initial/07-quality/07-03-compiler-testing.md)の「実装の規約と静的な検査」が、規約はできるだけ型の定義・コンパイラと lint・テストで守らせると定めた。本章は、その設定の中身と、道具では確かめにくい規約を書く。作業 T00 は、本章の「道具で確かめる規約」の設定をリポジトリに置き、本章の「文章で守る規約」を AGENTS.md の実装の規約の節に写す。

## Rust の版と設定

- Rust の版は 1.98.1 に固定する（2026-09-27 に rustup で導入できた stable の版）。`rust-toolchain.toml` に `channel = "1.98.1"` と、`components = ["clippy", "rustfmt"]` を書く。
- edition は 2024 とする。
- 警告を誤りとして扱う指定は、`.cargo/config.toml` の `[build]` の `warnings = "deny"` で行う。この設定は Rust 1.98.1 の Cargo で働くことを確かめた（`cargo clippy` の警告が `warnings are denied by build.warnings configuration` の誤りになる）。07-03 が挙げた二つの方法（`cargo clippy -- -D warnings` と `CARGO_BUILD_WARNINGS=deny`）のうち後者を、設定ファイルに書く形にしたものである。コマンドの引数を変えて緩められないようにするためである。
- リリースのビルドでも整数の溢れの検査を有効にし、panic は巻き戻しにする（07-03、02-09「panic 境界」）。

T00 が置く `Cargo.toml`（ワークスペース）は次のとおりである。lint の表は 07-03 の表と一対一に対応する。

```toml
[workspace]
resolver = "3"
members = ["crates/benitoite"]
exclude = ["fuzz"]

[workspace.package]
edition = "2024"
license = "MIT OR Apache-2.0"
rust-version = "1.98"

[workspace.lints.rust]
unsafe_code = "forbid"

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

[profile.release]
overflow-checks = true
panic = "unwind"
```

処理系のクレートの `crates/benitoite/Cargo.toml` は、`[lints] workspace = true` を書き、ワークスペースの lint を使う。機能（feature）は `alloc-stats` だけを定める（後述の「大域の状態」）。

```toml
[package]
name = "benitoite"
version = "0.1.0"
edition.workspace = true
license.workspace = true
rust-version.workspace = true

[lints]
workspace = true

[features]
alloc-stats = []

[dependencies]
```

`.cargo/config.toml`:

```toml
[build]
warnings = "deny"
```

## 完了条件の共通の検査

各作業の完了条件には、次の検査がすべて通ることを含める（07-03 の表）。T00 が置く `scripts/check.sh` が、これらを順に行い、一つでも失敗すれば終了状態 1 で終わる。

| 検査 | コマンド |
|---|---|
| 書式 | `cargo fmt --all --check` |
| lint | `cargo clippy --workspace --all-targets --all-features` |
| テスト | `cargo test --workspace --all-features` |
| 言語仕様の例 | `python3 tools/grammar-check/grammar_check.py` |
| 仕様の網羅の道具の自己テスト（T25 の後） | `python3 tools/spec-coverage/spec_coverage.py --self-test` |
| 依存のライセンス | `cargo deny check licenses` |

cargo-deny は `cargo install cargo-deny --locked` で導入する。`deny.toml` の許可するライセンスの一覧は `MIT` と `Apache-2.0` とする。最小実行版の処理系のクレートは依存するクレートを持たない（次節）ので、この検査は処理系自身のライセンス（`MIT OR Apache-2.0`）だけを確かめる。

## 依存するクレート

処理系のクレートは、Rust の標準ライブラリだけを使い、依存するクレートを持たない。`[dependencies]` と `[dev-dependencies]` は空のままにする。

- 言語の中核と処理系の主要部は自作する（00-03 ロードマップ「自作する部分と既存の OSS を使う部分」）。
- JSON の書き出し（診断の JSON Lines）とゴールデンテストの JSON の読み取りも、標準ライブラリだけで書く。形が決まった小さな JSON なので、手で書いても量が少ない。
- 例外は fuzzing のクレート（`fuzz/`）の `libfuzzer-sys` だけである。ワークスペースの外に置き、処理系の配布物に含めない（T30）。ライセンスは `(MIT OR Apache-2.0) AND NCSA`（0.4.13）であり、NCSA はこのクレートに限って認める。

外部のコードを写さない。写す必要が生じたときは、作業を止めて報告する（ADR 0003）。

## 文章で守る規約

道具で確かめにくい規約は次のとおりである。AGENTS.md の実装の規約の節にも同じ内容を書く（07-03 の最後の段落）。

### 型とシグネチャを変えない

[10-interfaces](../10-interfaces/) の `file=` のコードと `sig=` のシグネチャは、変えずに中身を書く。欄や引数を加える・変える・消す必要が生じたら、実装を進めずに報告する（07-03「実装の規約と静的な検査」）。非公開の補助の関数と型は、自由に加えてよい。

### 失敗を panic で表さない

- 言語の規則で定めた失敗（除算の 0、IO の失敗など）は、`Stop` か `Err` の値として返す（02-09「panic 境界」）。
- 型検査を通ったプログラムでは起きないはずの状態（表を引いて結果がない、値の種類が違う）は、脱糖とコード生成では `InternalError`、実行中は `Stop::Internal` として返す。
- `unwrap`・`expect`・添字（`v[i]`）は lint で禁じている。`get` と `?`、`let ... else` で書く。

### 大域の状態

処理系のどの段も、`static mut`・`thread_local!`・`OnceLock` などの大域の可変状態を持たない（ADR 0015）。例外は次の二つだけである。

- panic hook の記録（02-09「panic 境界」がスレッドローカルな記憶域を指定した。`runtime/panic.rs`）。
- 解放の回数の計数（07-02「確保と解放」）。機能 `alloc-stats` を有効にしたビルドでだけ、`thread_local!` の計数器で数える。既定のビルドには含めない。

初期化の後に変更しない表（組み込みの表）は、`const` か関数で表す。

### 再帰の深さ

利用者のプログラムの大きさや深さに比例して、処理系の再帰を深くしない（07-03）。

- AST と、AST から作る中間表現を辿る処理は、再帰で書いてよい。構文解析器が AST の深さを 1000 に抑える（02-03「入れ子の深さ」）ので、再帰の深さはその定数倍に収まる。
- 実行時の値を辿る処理（構造の `==`、値の解放、リストの走査）は、明示の積み重ね（`Vec`）で書く（02-08、02-09）。
- 言語の関数の呼び出しで Rust の関数を入れ子に呼ばない（ADR 0016）。VM と参照インタプリタの両方に適用する。

手で組んだ AST・IR をテストの入力にするときも、入れ子の深さは構文解析器の上限（1000）程度までにする。実際のプログラムはこの上限を超えないので、それより深い入力で処理系の再帰の深さを確かめる意味はない。

処理系のテストは、深い入れ子と長いリストの場合を含める。スレッドのスタックの大きさを変えてテストを通すことはしない。

### 言語の値を作る経路

言語の値のヒープの対象は、`runtime::heap::Heap` の関数だけで作る（ADR 0078）。10-08 の専用の参照の型（`StrRef` など）は、ランタイムのモジュールの外から作れないようにしてある。

### 数値の変換

`as` による数値の変換は、値が収まることが明らかな箇所（10-07 の命令の符号化など）に限る。そのほかは `u32::try_from` などを使い、失敗を処理系の不具合として扱う。

### `#[allow]` を書いてよい箇所

lint を個別に許す `#[allow(...)]` は、次の箇所だけに書き、許す理由をコメントで書く。

| 箇所 | 許す lint | 理由 |
|---|---|---|
| `src/lib.rs` | `dead_code` | 作業の途中では、後の作業が使う欄が読まれない。T24 で外す |
| テストのモジュール（`#[cfg(test)] mod tests`）と `tests/` の各ファイル | `clippy::unwrap_used`・`clippy::expect_used`・`clippy::panic`・`clippy::indexing_slicing`・`clippy::arithmetic_side_effects` | テストの失敗は panic で表す（07-03 は、テストのコードでこれらを許してよいとした） |
| `src/cli/mod.rs` と `src/runtime/real_io.rs` の `BENITOITE_DEV_PANIC` の処理 | `clippy::panic` | 処理系の不具合の報告をテストするために、意図して panic を起こす（10-09） |
| `src/bytecode/program.rs` の `assert_shareable` | `dead_code` | 呼ばれない関数で、型の性質をコンパイルの時点で確かめる |

これ以外の箇所で許す必要が生じたら、作業を止めて報告する。

### 文言

診断・報告の文言は英語で書き、`diag::codes` の表と `cli::text` にまとめる（ADR 0033）。処理を書く関数の中に英語の文を直接書かない。次のものは診断の表の型板ではなく、型板に埋める値やほかの報告の文なので、それぞれのモジュールの `text` という子のモジュールに定数としてまとめる。

- 構文の誤り（E0201）の `{expected}` と `{found}` に埋める字句と構文の呼び名（`parser` の `text`。T11・T12）
- 種類の合わない名前（E0304）の `{found_kind}` と `{expected_kind}` に埋める種類の呼び名（`resolve` の `text`。T13）
- `IoError.message` の文（`builtins::io_error` の `text`。T10）
- 読み込みの誤り（E0101）の `reason` に埋める、ファイルが大きすぎることの文（`pipeline` の `text`。T24）

`Stop::Internal` と `InternalError` の説明の文字列は、処理系の不具合を調べるためのもので、診断の表にも `text` にも載せない。

### コメントと名前

- 識別子は英語で書く。コメントは日本語で書く。設計者は処理系を読んで学ぶ（00-01「目的と設計原則」）ので、コメントは「何をするか」より「なぜそうするか」を書き、根拠になる設計書の章と節を `（設計書 02-08「実行の手順」）` の形で示す。
- 各モジュールの先頭に `//!` のコメントを置き、そのモジュールの役割と、対応する設計書の章を書く。
- 公開の関数と型には `///` のコメントを書く。10-interfaces のコメントはそのまま残す。
