# C18 移行の締め（`legacy` を消す）

- 依存する作業: [C05](C05-test-switchover.md), [C13](C13-spec-examples.md)（fuzzing の対象を移す [C15](C15-fuzz.md) も済んでいることが望ましい。済んでいなければ、本作業が `fuzz/` の `legacy` の参照を移す）
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（消すのが大半。移す箇所は開発用の例と測定の道具）
- ブランチ: impl/C18-legacy-removal

## 目的

最小実行版の実装（`src/legacy/`）を消し、移行を終える（[README](../README.md) の「決めたこと」の 11、[リポジトリとクレートの配置](../00-common/00-01-repository-layout.md)の「移行の間の配置」の C18 の行）。テスト・開発用の例・fuzzing・測定の道具に残る `legacy` の参照を、初回リリース版のモジュールに移す。`lib.rs` の `legacy` の宣言と、作業の途中のための `dead_code` の許可を外す。最小実行版の文書だけを確かめるテスト（`tests/language_reference.rs`）を消す。

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
| `src/lib.rs` | `pub mod legacy;` とその `///` のコメント、`#![allow(dead_code)]` とその理由のコメントを消す |
| `src/vm/mod.rs` | `pub mod stage1;` の宣言とその `///` のコメントを消す（10-09「第 1 段の実行の関数」。R26 が関数を消した後に残る、`//!` だけのモジュールの宣言） |
| `src/vm/stage1.rs` | 消す |
| `tests/language_reference.rs` | 消す |
| `tests/` の残り | `legacy` の参照が残っていれば、初回リリース版のモジュールに移す |
| `examples/disasm.rs`・`examples/bytecode_stats.rs` | 初回リリース版のパイプライン（10-13）と `bytecode::disasm`（10-07）を使う形に移す |
| `fuzz/fuzz_targets/` | C15 の後なら変えない。C15 の前なら、C15 の手順で三つの対象を移す（新しい対象は加えない） |
| `tools/bench/run.py`・`tools/bench/README.md` | `--bytecode-stats` を使えるように戻す（C05 が止めた） |
| `AGENTS.md` | 「実装の規約」の `#[allow]` の表から `src/lib.rs` の `dead_code` の行と `src/legacy/` の行を、「大域の状態」から `src/legacy/` の場所を消す。「ディレクトリ構成」の表に `src/legacy/` と `testdata-next/` への言及が残っていれば消す |

`src/lib.rs` は C01 が置いた凍結したファイルだが、README の「インターフェースの読み方」と 10-01 が、この二つの指定を C18 が外すとしている。ほかの行は変えない。`src/vm/mod.rs` も C01 が置いた凍結したファイルだが、10-09 の「作業の割り当て」が `pub mod stage1;` の宣言を C18 が消すとしている。

## 手順の要点

1. `git grep -n 'legacy'` で、リポジトリの中の `legacy` の参照を一覧にする（`docs/` は除く）。一覧を完了の報告に貼る。
2. `src/legacy/` を `git rm -r` で消し、`lib.rs` の二つの指定を外す。`src/vm/stage1.rs` を `git rm` で消し、`src/vm/mod.rs` の `pub mod stage1;` の宣言を消す。消す前に `src/vm/stage1.rs` が `//!` のコメントだけであることを確かめ、関数が残っていれば（R26 が済んでいない）報告して止まる。`tests/language_reference.rs` を消す（最小実行版の言語リファレンス `docs/reference/benitoite-minimal.md` は消さない。文書の扱いは U4 の同梱の文書の作業が決める）。
3. 開発用の例を移す。`disasm` は、スクリプトを `pipeline::check_path`・`desugar_checked`・`compile` で処理し、`bytecode::disasm` の出力を示す。`--all` の選択肢（標準ライブラリの原型も示す）の意味を保つ。`bytecode_stats` は、ベンチマークのバイトコードの大きさ（命令の数）を `tools/bench/run.py` が読む形で出す。出力の形が最小実行版から変わるなら、`run.py` の読み方を合わせる。
4. `dead_code` の許可を外すと、使われていない項目が警告（誤り）になることがある。
   - 非公開の補助の関数や欄のうち、どこからも使われず、後の作業（U3・U4）が使う予定も 10-interfaces にないものは、書いた作業のファイルの中で消してよい。消したものを完了の報告に挙げる。
   - 10-interfaces が定めた項目（`file=` のコードと `sig=` のシグネチャ）が警告になるとき、または U3・U4 が使う予定の項目が警告になるときは、消さずに、一覧を報告して止まる。オーケストレータが、許可を残すか、項目を直すかを決める。
5. `todo!()` の仮置きの残りを調べる。`git grep -n 'todo!()' crates/benitoite/src` と `git grep -n 'allow(clippy::todo, unused_variables)' crates/benitoite/src` を実行する。U1・U2 の完了の時点では、どちらも空でなければならない（[00-02](../00-common/00-02-conventions.md)「`todo!()` の仮置き」）。残っていれば、自分で本体を書かずに、残っているファイルと関数、それを受け持つ未了の作業（10-interfaces の各章の「作業の割り当て」で引く）を完了の報告に挙げる。
6. `scripts/check.sh`・`scripts/check-heap.sh`・`scripts/fuzz-short.sh`（nightly と cargo-fuzz がある場合）を実行する。
7. 最後に、もう一度 `git grep -n 'legacy'` を実行し、`docs/` の外に最小実行版の実装を指す参照が残っていないことを確かめる（`legacy` という語を別の意味で使う箇所があれば、その箇所を報告に書く）。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `scripts/check.sh` | すべて通る |
| `scripts/check-heap.sh` | すべて通る |
| `legacy` の参照 | `docs/` の外に最小実行版の実装を指す参照がない |
| 開発用の例 | `cargo run --example disasm -- <新しい構文のスクリプト>` が原型を示し、`tools/bench/run.py --verify --bytecode-stats target/release/examples/bytecode_stats` が命令の数を記録する |
| `lib.rs` | `dead_code` の許可がなく、`legacy` の宣言がない |
| `vm::stage1` | `src/vm/stage1.rs` がなく、`src/vm/mod.rs` に `stage1` の宣言がない |
| `todo!()` の仮置き | `crates/benitoite/src` に `todo!()` と仮置きの許可（`#![allow(clippy::todo, unused_variables)]`）が残っていない。残っていれば、そのファイルと受け持つ未了の作業を完了の報告に挙げている |

## 完了条件

- `scripts/check.sh` と `scripts/check-heap.sh` が通る
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書く
- `dead_code` の警告に対して消したものと、報告したものを、完了の報告で分けて示す
- 完了の報告に、`todo!()` の仮置きの残りの調べの結果（残りがなければその旨）を書く

## 難易度の理由

大半は消すだけである。判断が要るのは、`dead_code` の許可を外したときに現れる警告を、消してよい項目と報告すべき項目に分けることである。
