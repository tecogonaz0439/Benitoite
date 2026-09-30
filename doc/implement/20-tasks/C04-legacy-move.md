# C04 最小実行版の実装を `crate::legacy` へ移す

- 依存する作業: [C00](C00-foundation.md)
- 難易度: 1（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（書く行は少ないが、移すファイルとパスを書き換える箇所が多い）
- ブランチ: impl/C04-legacy-move

## 目的

最小実行版のモジュールを `crate::legacy` の下（`src/legacy/`）へ移し、初回リリース版のモジュールを置く最終的なパス（`src/syntax/`・`src/vm/` など）を空ける（[README](../README.md) の「決めたこと」の 11）。最小実行版の CLI とテストは、移した後も `legacy` の実装で動き続ける。この作業は振る舞いを変えない。以後の作業（C01・C02）は、空いたパスにインターフェースを置く。

## 読む設計書の節

- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): 「処理系のクレートのモジュール」「移行の間の配置」（手順の正はこの節）
- [作業の進め方](../00-common/00-03-workflow.md): 「最小実行版の実装からの移行」
- [実装の規約](../00-common/00-02-conventions.md): 「`#[allow]` を書いてよい箇所」「大域の状態」
- [基本の型とクレートの骨組み](../10-interfaces/10-01-base.md): 「置く作業と既存のファイル」（C04 の後の `lib.rs` と `main.rs` の形）
- [処理系のテスト戦略](../../design/07-quality/07-03-compiler-testing.md): 「実装の規約と静的な検査」の `unsafe_code` の行（最小実行版の実装は `unsafe` を使わない）

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。`fuzz/` と `AGENTS.md` はリポジトリの根からの相対パスである。

| ファイル | 変更 |
|---|---|
| `src/legacy/` | `src/` の下の次のものを `git mv` で移す: `builtins/`・`bytecode/`・`cli/`・`diag/`・`ir/`・`prelude/`・`refinterp/`・`resolve/`・`runtime/`・`syntax/`・`typeck/`・`types/`・`vm/`・`pipeline.rs` |
| `src/legacy/mod.rs` | 加える（下記） |
| 移したファイルの全体 | `crate::<移したモジュール>` を `crate::legacy::<移したモジュール>` に書き換える |
| `src/lib.rs` | `base` と `legacy` だけを宣言する形にする |
| `src/main.rs` | `benitoite::legacy::cli::main()` を呼ぶ形にする |
| `tests/*.rs`・`examples/*.rs` | `benitoite::<移したモジュール>` を `benitoite::legacy::<移したモジュール>` に書き換える |
| `fuzz/fuzz_targets/*.rs` | 同じ |
| `AGENTS.md` | 「実装の規約」の `#[allow]` の表と「大域の状態」に、`src/legacy/` の下の同じファイルを加える |

`src/base/`・`testdata/`・`tools/`・`scripts/` は変えない。

## 手順の要点

00-01「移行の間の配置」の手順 1〜6 を、この順で行う。

1. `git mv` で移す。移したディレクトリの中の構成（`runtime/heap.rs`・`runtime/panic.rs`・`prelude/*.bnt` など）は変えない。`prelude/mod.rs` の `include_str!` は同じディレクトリからの相対パスなので、書き換えなくてよい。
2. `src/legacy/mod.rs` を加える。中身は次のとおりとする。
   - 先頭の `//!` に、最小実行版の実装を移行の間だけ置くモジュールであること、初回リリース版のモジュールはこのモジュールを参照しないこと、移行の締め（C18）が消すことを書き、00-01「移行の間の配置」を示す。
   - `#![forbid(unsafe_code)]` を置き、その理由（07-03「実装の規約と静的な検査」の `unsafe_code` の行: 作り直しの前の最小実行版の実装は `forbid` のまま `unsafe` を使わない。ワークスペースの水準は C00 が `deny` に下げた）をコメントで書く。
   - 移した 14 のモジュールを `pub mod` で宣言する（`pub mod pipeline;` を含む）。
3. 移したファイルの中のパスを書き換える。
   - `crate::diag::…` のような単独のパスは `crate::legacy::diag::…` にする。`crate::base::…` は変えない（`base` は移さない）。
   - `use crate::{…}` の形でまとめて取り込んでいる箇所は、中の各項目が移したモジュールか `base` かを見分けて書き換える。
   - ドキュメントのコメントの中のリンク（`[`crate::vm::Vm`]` など）も書き換える。rustdoc のリンク切れは警告になり、警告は誤りになる。
   - `super::` と `self::` のパスは、移したモジュールの中で閉じているので変えない。
4. `src/lib.rs` を次の形にする。C01 が 10-01 の `lib.rs` で置き換える。

   ```text
   //! Benitoite の処理系。移行の間の形（実装プラン 00-01「移行の間の配置」）。
   //! 最小実行版の実装は `legacy` にある。初回リリース版のモジュールは C01・C02 が加える。

   pub mod base;
   pub mod legacy;
   ```

   `src/main.rs` は、`benitoite::cli::main()` の呼び出しを `benitoite::legacy::cli::main()` に改めるだけにする（先頭の `//!` は残す）。
5. `tests/`・`examples/`・`fuzz/fuzz_targets/` の `benitoite::<移したモジュール>` を `benitoite::legacy::<移したモジュール>` に書き換える。`benitoite::base` は変えない。`testdata/` は変えない。`tests/spec_examples.rs` と `tests/language_reference.rs` が読む文書のパス（`../../doc/...`）は変えない。
6. AGENTS.md の「実装の規約」を改める（C00 が 00-02 の規約を写した後の節）。
   - `#[allow]` の表に、`src/legacy/` の下で最小実行版が許した箇所（`src/legacy/cli/mod.rs` と `src/legacy/runtime/real_io.rs` の `BENITOITE_DEV_PANIC` の処理、`src/legacy/bytecode/program.rs` の `assert_shareable`、テストのモジュール）があることを確かめ、なければ 00-02 の表のとおりに加える。
   - 「大域の状態」の panic hook の記録と `alloc-stats` の計数器の箇条に、最小実行版の実装のファイル（`src/legacy/runtime/panic.rs`、`src/legacy/runtime/heap.rs`）を、C18 が消すまでの間の場所として加える。
   - ほかの節は変えない。
7. `scripts/check.sh` を実行する。`fuzz/` はワークスペースの外なので、`cargo +nightly fuzz build` で三つの対象がビルドできることを別に確かめる（nightly と cargo-fuzz がある場合。ない場合は、完了の報告にそう書く）。

コードの中身（関数の本体、型、テスト）は変えない。書き換えるのは、パスと、上に挙げた宣言だけである。書き換えの後に、`rustfmt` が `use` の並びを並べ替えることがある。`cargo fmt --all` の結果はそのまま受け入れる。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `scripts/check.sh` | すべて通る。最小実行版のゴールデンテスト（197 件）、CLI のプロセスのテスト、言語仕様の例のテスト、言語リファレンスのテストが、移す前と同じく通る |
| テストの数 | `cargo test --workspace` が実行したテストの数が、移す前と同じである（移す前と後の数を完了の報告に書く） |
| CLI | `cargo run -- run crates/benitoite/testdata/acceptance/hello.bnt` の出力と終了状態が、移す前と同じである |
| 移した後のパス | `src/` の直下に、`base/`・`legacy/`・`lib.rs`・`main.rs` のほかのものがない |
| 参照の漏れ | `src/base/` が `crate::legacy` を参照しない（`base` は初回リリース版のモジュールと共有する）。`src/legacy/` の中に、`legacy` を通らない `crate::<移したモジュール>` の参照がない（`grep` で確かめ、コマンドを完了の報告に書く） |
| fuzz | nightly と cargo-fuzz があれば、`cargo +nightly fuzz build` が通る |

振る舞いを変えない作業なので、新しいテストは書かない。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書いている
- 移したファイルの差分が、パスの書き換えと `rustfmt` の並べ替えだけである（`git diff -M --stat` と、書き換えの種類を完了の報告に書く）

## 難易度の理由

手順が 00-01 に決めてあり、判断はほとんど要らない。量は多いので、まとめて取り込む `use crate::{…}` とドキュメントのコメントの中のリンクの書き換えの漏れに注意する。
