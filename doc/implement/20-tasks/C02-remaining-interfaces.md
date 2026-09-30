# C02 共有と U1 の残りのインターフェースを置く

- 依存する作業: [C01](C01-stage1-interfaces.md)
- 難易度: 1（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 大（1500 行超。ただし書くのではなく取り出して置く）
- ブランチ: impl/C02-remaining-interfaces

## 目的

C01 の後に残るインターフェースを、処理系のクレートに置く（[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」）。置くのは、共有と U1 の章（10-01 の `lib.rs` のほか、10-02〜10-06、10-12〜10-14）と、10-07〜10-11 のうち見出しに `task=C02` を付けたブロック（第 2 段の VM・スケジューラ・IO の型、コード生成と検証器のシグネチャなど）である。標準ライブラリのソース（`src/prelude/stdlib/` の `.bnt`）もここで置く。C02 の後、U1（F01 以降）と、R08 と、U2 第 2 段の作業が始められる。

## 読む設計書の節

- [実装プランの README](../README.md): 「インターフェースの章」「インターフェースの読み方」
- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): 「処理系のクレートのモジュール」「移行の間の配置」
- [作業の進め方](../00-common/00-03-workflow.md): 「インターフェースの凍結」「型やシグネチャを変える必要が生じたとき」
- 取り出しの道具 [tools/extract_interfaces.py](../tools/extract_interfaces.py) の先頭のコメント
- インターフェース: [10-01](../10-interfaces/10-01-base.md)〜[10-06](../10-interfaces/10-06-ir.md)、[10-12](../10-interfaces/10-12-builtin-table.md)〜[10-14](../10-interfaces/10-14-prelude-and-stdlib-sources.md) の全体と、10-07〜10-11 の `task=C02` のブロック（何が置かれるかを知るために目を通す）

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `python3 doc/implement/tools/extract_interfaces.py list --task C02` が挙げるファイル（2026-09-30 の時点で 75 ファイル）。10-10 の `src/runtime/sched/testing.rs`（中身のないモジュール）と、`src/runtime/io/` の `IoView`（`file=`）とその `IoServices` の実装の仮置きを含む。
- 置き換えるのは `src/base/mod.rs` だけである（見出しの属性 `replace`）。10-01「置く作業と既存のファイル」のとおり、型を加えるだけであり、`legacy` のコードは置き換えの後もそのままコンパイルできる。
- ほかは、C01 の時点で道具が作った中身のないモジュールを埋めるか、新しいファイルを作る。C01 が置いた `file=` のコードは変えない（00-03「インターフェースの凍結」）。`task=C02` の `sig=` のブロックが C01 の置いたファイルと同じパスを指すもの（`src/runtime/heap/ctx.rs`・`src/builtins/table.rs` など）は、道具が末尾に `todo!()` の仮置きを書き足し、中身を書く作業がその本体を書き換える。

`src/main.rs`・`src/legacy/` は変えない。

## `sig=` の項目の置き方

C01 と同じく、`place` は `sig=` の関数を `todo!()` の仮置きとして置き、仮置きを置いたファイルの先頭に仮置きの許可 `#![allow(clippy::todo, unused_variables)]` とその理由のコメントを置き、rustfmt で整える（[C01](C01-stage1-interfaces.md)「`sig=` の項目の置き方」、[00-02](../00-common/00-02-conventions.md)「`todo!()` の仮置き」）。`sig=` だけのパスに C01 の置いたファイルがあるとき（`src/runtime/heap/ctx.rs`・`src/builtins/table.rs` など）は、まだ置いていないブロックの仮置きをファイルの末尾に書き足す。関数の宣言がすべてファイルにあるブロックは置いたものとみなすので、再実行しても二重に置かない。

2026-09-30 に、C04 の後の形を写したクレートで `place --task C01 --overwrite` に続けて `place --task C02 --overwrite` を行い、Clippy（二つのメモリの管理の機能のそれぞれ）と `cargo test --no-run` が通ることを確かめた。

## 手順の要点

1. リポジトリの根で、置くものを確かめる。

   ```sh
   python3 doc/implement/tools/extract_interfaces.py list --task C02
   python3 doc/implement/tools/extract_interfaces.py place crates/benitoite --task C02 --overwrite --dry-run
   ```

   `--dry-run` の出力で、`overwrite` が `src/base/mod.rs` の一つだけであり、`refuse` がないことを確かめる。C01 の置いたファイルに `overwrite` や `refuse` が出たら、本プランの誤りである。報告して止まる。
2. 同じコマンドを `--dry-run` なしで実行する。`--overwrite` は、見出しに `replace` を付けた `src/base/mod.rs` を上書きするために要る。
3. `scripts/check.sh` を実行する。
4. 取り出したコードは手で直さない。通らなければ、誤りの内容と原因のブロックを報告して止まる（00-03「型やシグネチャを変える必要が生じたとき」）。書式の検査だけが通らない場合も、手で整形せずに報告する（道具が rustfmt で整えるので、通らなければ道具の不具合である）。
5. 標準ライブラリのソース（`text file=`）は、置いた後に読む処理がまだない（読み込みの段は F05 が書く）。ここでは、ファイルがブロックと同じ内容で置かれたことだけを確かめる。名前と型の誤りは F05〜F10 が見つける（10-14「置く作業と既存のファイル」）。
6. `list --task C02` の出力を完了の報告に貼る。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `scripts/check.sh` | すべて通る。最小実行版のテストは `legacy` で動き続ける |
| `cargo doc -p benitoite --no-deps` | 警告なしに通る |
| 仮置き | `sig=` の関数は本体が `todo!()` の仮置きであり、仮置きのあるファイルの先頭に仮置きの許可とコメントがある |
| 取り出しの再実行 | `place --task C01 --overwrite` と `place --task C02 --overwrite` を続けて実行すると、すべてのファイルが `unchanged` になる（C02 が末尾に書き足した C01 のファイルも、書く内容で始まるので `unchanged`） |
| `extract_interfaces.py check --base crates/benitoite` | すべての章を対象にして通る |
| 中身のないモジュール | 作業の後に、道具が作った中身のないモジュールのファイル（先頭のコメントだけのもの）のうち、どの章もブロックを置かないものの一覧を完了の報告に書く。一覧が空でないときは、その理由（後の作業が子のモジュールとして加えるもの、など）を添える |

この作業は型の定義と標準ライブラリのソースを置くだけで、振る舞いを持たないので、Rust のテストは書かない。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書いている
- 取り出したコードを手で直していない。C01 が置いた `file=` のコード、`src/main.rs`、`src/legacy/` を変えていない

## 難易度の理由

道具を実行して検査を通すだけの作業である。C01 より置くファイルが多いが、判断の量は変わらない。
