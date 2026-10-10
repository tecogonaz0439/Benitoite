# C00 土台の更新（lint、機能、検査のスクリプト）

- 依存する作業: なし
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 小（500 行未満）
- ブランチ: impl/C00-foundation

## 目的

初回リリース版の作業が共通に使う設定と検査の手順を、最小実行版の土台の上に置く。具体的には、ワークスペースの lint の表を初回リリース版の表に改め（`unsafe_code` を `deny` にし、`unsafe` のブロックの書き方を確かめる二つの lint を加える）、メモリの管理を切り替える機能（feature）を処理系のクレートに置き、`scripts/check.sh` を機能の組み合わせごとに検査する形に改め、nightly の Rust が要る検査と時間のかかる検査を行う `scripts/check-heap.sh` を加える。あわせて、実装の規約を AGENTS.md に写す（[処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md)の「実装の規約と静的な検査」の最後の段落）。

この作業は処理系のソースを変えない。作業の後も、最小実行版の実装がそのまま検査を通る。

## 読む設計書の節

- [処理系のテスト戦略](../../2026-10-09-design-first-release/07-quality/07-03-compiler-testing.md): 「実装の規約と静的な検査」「ヒープとランタイムの確かめ方（初回リリース版）」「fuzzing」の nightly の段落
- [ADR 0259](../../2026-10-09-design-first-release/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md): 二つのメモリの管理を同じ枝に置くこと
- [ADR 0260](../../2026-10-09-design-first-release/decisions/0260-heap-and-unsafe-boundary.md): 決定 7〜9（Miri、`unsafe` のブロックの書き方、`unsafe_code` の水準）
- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): 「リポジトリの配置」、「`unsafe` を書いてよいモジュール」、「機能（feature）」
- [実装の規約](../00-common/00-02-conventions.md): 「Rust の版と設定」「完了条件の共通の検査」「文章で守る規約」
- [作業の進め方](../00-common/00-03-workflow.md): 「作業の手順」「担当と起動の方法」（nightly の Miri はオーケストレータが導入済み）

## 作るもの

この作業のファイルは、リポジトリの根からの相対パスで示す。

| ファイル | 変更 |
|---|---|
| `Cargo.toml` | `[workspace.lints.rust]` と `[workspace.lints.clippy]` を、00-02「Rust の版と設定」の `toml` のブロックと同じ内容にする。ほかの表（`[workspace]`・`[workspace.package]`・`[profile.release]`）は変えない |
| `crates/benitoite/Cargo.toml` | `[features]` を 00-01「機能（feature）」の表のとおりにする（下記） |
| `scripts/check.sh` | 00-02「完了条件の共通の検査」の表の形に改める（下記） |
| `scripts/check-heap.sh` | 加える（下記）。実行の権限を付ける |
| `AGENTS.md` | 「実装の規約」の節を置き換え、「ディレクトリ構成」の `scripts/` の行を改める（下記） |

## 手順の要点

### 機能

`crates/benitoite/Cargo.toml` の `[features]` を次の形にする。最小実行版の `alloc-stats = []` は残す。

```toml
[features]
default = ["gc-mark-sweep"]
gc-mark-sweep = []
gc-refcount = []
gc-stress = []
heap-verify = []
heap-per-object = []
alloc-stats = []
```

二つのメモリの管理のどちらか一方だけを有効にする `compile_error!` は、この作業では置かない。C01 が置く `src/runtime/heap/mod.rs`（[10-08](../10-interfaces/10-08-values-and-heap.md)）に入っている。C01 の後は `--all-features` のビルドが止まるので、`check.sh` とほかのスクリプトで `--all-features` を使わない。

### `scripts/check.sh`

最小実行版の `check.sh` の枠（`set -euo pipefail`、リポジトリの根に移る、`run_check` で `== <名前>` を出して最初の失敗で止まる、`cargo deny` がなければ導入の手順を示して終了状態 1）はそのまま使い、検査の並びを次の表にする。名前は `FAILED: <名前>` の表示に使う。

| 名前 | コマンド |
|---|---|
| `format` | `cargo fmt --all --check` |
| `lint (mark-sweep)` | `cargo clippy --workspace --all-targets --no-default-features --features gc-mark-sweep,heap-verify,alloc-stats` |
| `lint (refcount)` | `cargo clippy --workspace --all-targets --no-default-features --features gc-refcount,heap-verify,alloc-stats` |
| `test (mark-sweep)` | `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify` |
| `test (refcount)` | `cargo test --workspace --no-default-features --features gc-refcount,heap-verify` |
| `gc-stress (mark-sweep)` | `cargo test --workspace --no-default-features --features gc-mark-sweep,heap-verify,gc-stress --lib --tests` |
| `gc-stress (refcount)` | `cargo test --workspace --no-default-features --features gc-refcount,heap-verify,gc-stress --lib --tests` |
| `language examples` | `python3 tools/grammar-check/grammar_check.py` |
| `language examples (appendix)` | `python3 tools/grammar-check/grammar_check.py docs/archive/2026-10-09-design-first-release/08-appendix/08-04-fp-syntax-comparison.md` |
| `leftover placeholder allows` | `crates/benitoite/src/` の `.rs` のうち、`#![allow(clippy::todo, unused_variables)]` を含み `todo!(` を含まないファイルがあれば、そのファイルを示して失敗する（`grep` で書く。00-02「完了条件の共通の検査」の「仮置きの許可の残り」、「`todo!()` の仮置き」） |
| `spec coverage tool` | `python3 tools/spec-coverage/spec_coverage.py --self-test` |
| `licenses` | `cargo deny check licenses` |

- 回収の強制の行は、00-02 の「ゴールデンテストと差分テストを実行する」を、`--lib --tests`（ライブラリの単体テストとすべての統合テスト。ドキュメントのテストを除く）で満たす。ゴールデンテストの実行器は、C10 が加える初回リリース版の実行器も含めて `tests/` にあり、差分テストはその中で行う（C10）。統合テストの名前を並べないのは、C10・C05 が実行器のファイルを加えたり名前を改めたりしても、このスクリプトを変えずに済ませるためである。ドキュメントのテストを除くのは、そこに置くコンパイルの失敗のテストが回収の方式に依存しないからである。
- スクリプトの冒頭のコメントに、どの検査を `check.sh` に置き、どれを `check-heap.sh` に置いたかと、その理由を書く（00-02「完了条件の共通の検査」の最後の段落）。回収の強制は、いまは全体を `check.sh` に置く。後の作業で時間が作業の妨げになったら、その作業が報告し、オーケストレータが分け方を決める。
- `leftover placeholder allows` の行は、C01・C02 が置く `todo!()` の仮置きの許可が、本体を書き終えたファイルに残らないことを確かめる。C00 の時点では対象のファイルがないので通る。
- 参照カウントの三つの行（`lint (refcount)`・`test (refcount)`・`gc-stress (refcount)`）は、第 1 段の締め（R14）が、採った方式の行だけを残す形に改める。そのことを、行の前のコメントに書く。

### `scripts/check-heap.sh`

07-03「ヒープとランタイムの確かめ方（初回リリース版）」が「別のスクリプト」とした検査を行う（00-02「完了条件の共通の検査」の二つ目の表）。bash で書き、`check.sh` と同じ枠（`run_check`、最初の失敗で止まる、最後に `all heap checks passed`）にする。

1. nightly の Rust と Miri の有無を `cargo +nightly miri --version` で確かめる。なければ、`rustup toolchain install nightly` と `rustup component add --toolchain nightly miri` を示して終了状態 1 で終える。黙って飛ばさない。nightly の版はスクリプトの中で固定しない（00-02「Rust の版と設定」）。
2. Miri（両方式。第 1 段の間）: 機能 `gc-mark-sweep,heap-verify` と `gc-refcount,heap-verify` のそれぞれで、`cargo +nightly miri test -p benitoite --no-default-features --features <機能> --lib -- runtime::heap:: vm:: --skip legacy::` を実行する（絞り込みは部分一致なので、`legacy` の下の最小実行版のテストを `--skip` で除く。Miri の実行には `CARGO_BUILD_WARNINGS=warn` を与える。下記の【要検証】の段落を確かめた結果）。テストの名前の絞り込みは、ヒープの単体テスト（`runtime::heap` の下）と、小さな VM のプログラムのテスト（`vm` の下）を対象にするためである。
3. 対象ごとの確保: 機能に `heap-per-object` を加え、ヒープの単体テスト（`-- runtime::heap::`）だけを Miri で実行する（両方式）。
4. 到達可能性の比較の長い実行: 環境変数 `BENITOITE_HEAP_RANDOM_CASES=20000` を与えて、`cargo test -p benitoite --no-default-features --features <機能>,heap-verify --lib -- runtime::heap::` を両方式で実行する（Miri を使わない普通の実行）。
5. 各行の前に、どの作業がその検査の対象のテストを書くか（Miri と到達可能性の比較のテストは R01〜R04・R06・R11）をコメントで書く。

スクリプトは、後の作業との次の取り決めを冒頭のコメントに書く。

- Miri で動かせないテスト、Miri では遅すぎるテストには、`#[cfg_attr(miri, ignore)]` を付ける。付けた理由をコメントで書く。スクリプトの絞り込みは変えない。
- 無作為に組み合わせて到達可能性を比べるテストは、環境変数 `BENITOITE_HEAP_RANDOM_CASES` から組み合わせの数を読む。環境変数がないときの数は、`check.sh` の時間を妨げない小さな値にする（テストを書く作業が決める）。

nightly の `rustc` は、stable の 1.98.1 にない警告を出すことがある。リポジトリの `.cargo/config.toml` は警告を誤りにするので、Miri の実行が stable で出ない警告で止まるかもしれない【要検証】。止まったときは、Miri の実行にだけ環境変数 `CARGO_BUILD_WARNINGS=warn` を与えて警告を誤りにしない形にし、その理由をコメントに書く（警告は `check.sh` の stable の検査で誤りにしているので、ここで緩めても規約は守られる）。

C00 の時点では最小実行版のテストが `legacy` の下にまだないので、Miri の行を実行すると最小実行版の VM のテストも対象になり、終わらない。C00 では Miri のビルドが通ることだけを確かめ、Miri の行の実行は C04 の取り込みの後にオーケストレータが確かめる。それでも、Miri でクレート全体（`legacy` を含む）がビルドできることを、この作業で確かめる。

### AGENTS.md

- 「実装の規約」の節の本文を、00-02「文章で守る規約」の小節（型とシグネチャを変えない、失敗を panic で表さない、`unsafe` の書き方、回収しない区間と値の扱い、言語の値を作る経路、組み込みの関数の書き方、大域の状態、再帰の深さ、数値の変換、`#[allow]` を書いてよい箇所、文言、コメントと名前）を写したものに置き換える。節の冒頭の文を、「本節は初回リリース版の実装プランの `docs/archive/2026-10-09-implement-first-release/00-common/00-02-conventions.md`「文章で守る規約」を写したものであり、食い違ったときは 00-02 を正とする。lint の水準は `Cargo.toml` の `[workspace.lints]` が定める。」という趣旨の文にする。
- 00-02 の「大域の状態」は AGENTS.md の三つの例外を参照している。写すときは、AGENTS.md の現在の三つの例外（panic hook の記録、`alloc-stats` の計数器、中断の印）の箇条をそのまま残し、00-02 の本文を加える。panic hook の記録の場所は、初回リリース版の `runtime/panic.rs`（R09 が写す）とする。`src/legacy/` の同じファイルは C04 が加える。
- 写した文の中の相対リンク（`../../design/...` など）は、リポジトリの根からの相対パスに直すか、章の番号と節の名前だけの参照（`02-09「panic 境界」` の形）にする。AGENTS.md はリポジトリの根にあるので、00-02 の相対リンクはそのままでは切れる。
- 「ディレクトリ構成」の表の `scripts/` の行に、`check-heap.sh`（nightly の Rust が要る検査と時間のかかる検査。`runtime::heap` を変える作業で実行する）を加える。
- ほかの節は変えない。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 作業の後の `scripts/check.sh` | すべての検査が通り、`all checks passed` を出して終了状態 0 |
| 仮置きの許可の残り | `crates/benitoite/src/` に、一時的に `#![allow(clippy::todo, unused_variables)]` だけを書いた `.rs` のファイルを置くと、`leftover placeholder allows` で失敗して止まる。確かめたら元に戻す |
| `cargo clippy` の lint の表 | `crates/benitoite/src/lib.rs` に一時的に `pub fn f() { unsafe {} }` を加えると、`lint (mark-sweep)` で失敗して止まる（`unsafe_code` が `deny`）。確かめたら元に戻す |
| 機能の組み合わせ | `cargo build --no-default-features --features gc-refcount` が通る（C01 までは、機能がコードに影響しない） |
| `scripts/check-heap.sh` | nightly の Miri がある環境で、すべての検査が通る（対象のテストは 0 件） |
| Miri がない場合 | `PATH` から nightly を外すか `cargo +nightly` が失敗する状況を作ると、導入の手順を示して終了状態 1 で終わる（手で確かめ、完了の報告に書く） |
| AGENTS.md | 00-02「文章で守る規約」の小節がすべてあり、相対リンクが切れていない |

この作業は処理系の振る舞いを持たないので、Rust のテストは書かない。上の確認は手で行い、完了の報告に結果を書く。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- `scripts/check-heap.sh` が通る
- 受け入れテストのすべての場合を手で確かめ、完了の報告に結果を書いている
- 処理系のソース（`crates/benitoite/src/`・`tests/`）を変えていない

## 難易度の理由

設定の内容は 00-01・00-02 にほぼそのまま書いてある。判断が要るのは、回収の強制の検査の範囲、Miri のテストの絞り込みと後の作業との取り決め、AGENTS.md に写すときの参照の直し方である。
