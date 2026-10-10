# C18 移行の締め（`legacy` を消す）

- 依存する作業: [C05](C05-test-switchover.md), [C13](C13-spec-examples.md)（fuzzing の対象を移す [C15](C15-fuzz.md) も済んでいることが望ましい。済んでいなければ、本作業が `fuzz/` の `legacy` の参照を移す）
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（消すのが大半。移す箇所は開発用の例と測定の道具）
- ブランチ: impl/C18-legacy-removal

## 目的

最小実行版の実装（`src/legacy/`）を消し、移行を終える（[README](../README.md) の「決めたこと」の 11、[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」の C18 の行）。テスト・開発用の例・fuzzing・測定の道具に残る `legacy` の参照を、初回リリース版のモジュールに移す。`lib.rs` の `legacy` の宣言を外す。最小実行版の文書だけを確かめるテスト（`tests/language_reference.rs`）を消す。

次の三つは、U1・U2 の作業が残っている間は行えないので、本作業の範囲に入れない。U1・U2 をすべて終えた後に、オーケストレータが行う（[すべての作業を終えた後に行うこと](../90-after-completion.md)の「移行の締めの残り」）。

- `lib.rs` の `dead_code` の許可を外すこと（後の作業が使う 10-interfaces の項目が警告になる）
- `src/vm/stage1.rs` と `vm/mod.rs` の `pub mod stage1;` の宣言を消すこと（R26 が関数を消した後に行う）
- `todo!()` の仮置きの残りの調べ

文書（AGENTS.md と実装プランの 00-01・00-02・00-03・10-01）の `legacy` の記述は、本作業の取り込みの後にオーケストレータが改める。本作業は文書を変えない。

## 読む設計書の節

- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): 「処理系のクレートのモジュール」「移行の間の配置」
- [実装の規約](../00-common/00-02-conventions.md): 「`#[allow]` を書いてよい箇所」「大域の状態」
- [作業の進め方](../00-common/00-03-workflow.md): 「最小実行版の実装からの移行」
- [基本の型とクレートの骨組み](../10-interfaces/10-01-base.md): 「クレートの骨組み」（`lib.rs` のコメントが C18 で外すとした指定）
- [10-07](../10-interfaces/10-07-bytecode.md) の `bytecode::disasm`（開発用の例が使う）

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。`fuzz/`・`tools/`・`AGENTS.md` はリポジトリの根からの相対パスである。

| ファイル | 変更 |
|---|---|
| `src/legacy/` | 消す |
| `src/lib.rs` | `pub mod legacy;` とその `///` のコメントを消す（`#![allow(dead_code)]` は残す） |
| `tests/language_reference.rs` | 消す |
| `tests/` の残り | `legacy` の参照が残っていれば、初回リリース版のモジュールに移す |
| `examples/disasm.rs`・`examples/bytecode_stats.rs` | 初回リリース版のパイプライン（10-13）と `bytecode::disasm`（10-07）を使う形に移す |
| `fuzz/fuzz_targets/` | C15 の後なら変えない。C15 の前なら、C15 の手順で三つの対象を移す（新しい対象は加えない） |
| `tools/bench/run.py`・`tools/bench/README.md` | `--bytecode-stats` を使えるように戻す（C05 が止めた） |
| `scripts/check-heap.sh` | `--skip legacy::` と、その説明のコメントを消す |
| `src/` のテストとコメント | 最小実行版の実装を指すコメント（例 `ir/decision.rs`・`resolve/tests.rs`・`runtime/report.rs`・`syntax/parser/mod.rs`・`runtime/panic.rs` の該当行）を、今の実装に合う文に直すか、経緯の記述として残す。どちらにしたかを報告に書く |

`legacy` という語を別の意味で使う箇所（例 `syntax/parser/exprs.rs`・`syntax/parser/effects.rs` の古い構文の節、`tests/golden.rs` の `.opts`、`bytecode/codegen/tests.rs` の変数の名前）は変えない。`tools/bench/gate.py`・`tools/bench/stage1.py` の `--legacy` と `tools/bench/results/` の記録は、コミット `d4668a9^` から別にビルドした最小実行版の VM と比べるためのもので、`src/legacy/` に依存しないので変えない（[ADR 0313](../../2026-10-09-design-first-release/decisions/0313-vm-performance-recovery-before-stage-2.md) の帰結）。

`src/lib.rs` は C01 が置いた凍結したファイルだが、README の「インターフェースの読み方」と 10-01 が、`legacy` の宣言を C18 が外すとしている。ほかの行は変えない。

## 手順の要点

1. `git grep -n 'legacy'` で、リポジトリの中の `legacy` の参照を一覧にする（`docs/` は除く）。一覧を完了の報告に貼る。
2. `src/legacy/` を `git rm -r` で消し、`lib.rs` の `legacy` の宣言を外す。`tests/language_reference.rs` を消す（最小実行版の言語リファレンス `docs/reference/benitoite-minimal.md` は消さない。文書の扱いは U4 の同梱の文書の作業が決める）。
3. 開発用の例を移す。`disasm` は、スクリプトを `pipeline::check_path`・`desugar_checked`・`compile` で処理し、`bytecode::disasm` の出力を示す。`--all` の選択肢（標準ライブラリの原型も示す）の意味を保つ。`bytecode_stats` は、ベンチマークのバイトコードの大きさ（命令の数）を `tools/bench/run.py` が読む形で出す。出力の形が最小実行版から変わるなら、`run.py` の読み方を合わせる。利用者のコードの命令の数には、`ProtoOrigin` の `User` で始まる区分（`UserMethod`・`UserHandleBody`・`UserHandleClause`・`UserLazy` など）を数え、標準ライブラリと組み込みの関数の値の原型は全体の数にだけ含める。
4. `scripts/check.sh`・`scripts/check-heap.sh`・`scripts/fuzz-short.sh`（nightly と cargo-fuzz がある場合）を実行する。
5. 最後に、もう一度 `git grep -n 'legacy'` を実行し、`docs/` と `AGENTS.md` の外に最小実行版の実装を指す参照が残っていないことを確かめる（`legacy` という語を別の意味で使う箇所があれば、その箇所を報告に書く）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `scripts/check.sh` | すべて通る |
| `scripts/check-heap.sh` | すべて通る |
| `legacy` の参照 | `docs/` と `AGENTS.md` の外に最小実行版の実装を指す参照がない |
| 開発用の例 | `cargo run --example disasm -- <新しい構文のスクリプト>` が原型を示し、`tools/bench/run.py` の `--bytecode-stats target/release/examples/bytecode_stats` が命令の数を記録する（`--verify` は比較の対象の言語の処理系が要る。ない環境では `--benitoite` だけを指定して確かめ、その旨を報告に書く） |
| `lib.rs` | `legacy` の宣言がない（`dead_code` の許可は残る） |

## 完了条件

- `scripts/check.sh` と `scripts/check-heap.sh` が通る
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書く

## 難易度の理由

大半は消すだけである。判断が要るのは、開発用の例を新しいパイプラインに移すときの出力の形と、`legacy` の語が最小実行版の実装を指すかどうかの見分けである。
