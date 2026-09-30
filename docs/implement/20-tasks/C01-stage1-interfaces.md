# C01 U2 第 1 段のインターフェースを置く

- 依存する作業: [C04](C04-legacy-move.md)
- 難易度: 1（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 大（1500 行超。ただし書くのではなく取り出して置く）
- ブランチ: impl/C01-stage1-interfaces

## 目的

U2 第 1 段（R01〜R14）が使うインターフェースを、処理系のクレートに置く（[README](../README.md) の「決めたこと」の 3、[作業の進め方](../00-common/00-03-workflow.md)の「インターフェースの凍結」）。置くのは、10-01 の `lib.rs`、共有の 10-07 の全体（命令の集合と符号化、コンパイル済みプログラムの形、生存の情報）、10-08・10-09・10-11 のうち第 1 段の分である。以後の作業は、ここで置いた型と、全モジュールの宣言の上に中身を書く。C01 の後、U2 第 1 段は U1 を待たずに始められる。

## 読む設計書の節

- [実装プランの README](../README.md): 「インターフェースの章」「インターフェースの読み方」
- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): 「処理系のクレートのモジュール」「移行の間の配置」「機能（feature）」
- [作業の進め方](../00-common/00-03-workflow.md): 「インターフェースの凍結」「型やシグネチャを変える必要が生じたとき」
- [実装の規約](../00-common/00-02-conventions.md): 「型とシグネチャを変えない」「`#[allow]` を書いてよい箇所」
- 取り出しの道具 [tools/extract_interfaces.py](../tools/extract_interfaces.py) の先頭のコメント
- インターフェース: [10-01](../10-interfaces/10-01-base.md) の「クレートの骨組み」、[10-07](../10-interfaces/10-07-bytecode.md)、[10-08](../10-interfaces/10-08-values-and-heap.md)、[10-09](../10-interfaces/10-09-vm.md)、[10-11](../10-interfaces/10-11-builtin-interface.md)（中身を理解する必要はない。何が置かれるかを知るために目を通す）

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `python3 docs/implement/tools/extract_interfaces.py list --task C01` が挙げるファイル（2026-09-30 の時点で 28 ファイル。数え直した）。主なものは `src/lib.rs`（置き換え）、`src/bytecode/`（`instr.rs`・`program.rs`・`liveness.rs`・`mod.rs`・`disasm.rs`）、`src/runtime/`（`mod.rs`・`panic.rs`・`heap/` の下、`list.rs`・`equal.rs`）、`src/vm/`（`mod.rs`・`state.rs`・`frame.rs`・`budget.rs`・`dispatch.rs`・`stage1.rs`）、`src/builtins/`（`iface.rs`・`mod.rs`・`table.rs`・`funcs/mod.rs`）である。
- `sig=` のブロックの関数の `todo!()` の仮置き（00-02「`todo!()` の仮置き」）。道具が置く。
- `lib.rs` と各 `mod.rs` が宣言したのにブロックのないモジュール（C02 が置く `syntax`・`typeck` などと、`runtime::report`・`runtime::sched` など）の、中身のないモジュールのファイル。道具が作る。

`src/main.rs`・`src/base/`・`src/legacy/` は変えない。

## `sig=` の項目の置き方

C01 の `file=` のコードは、`sig=` のブロックが定める項目（`src/runtime/heap/core.rs` の `HeapCore` など、`src/vm/state.rs` の `RunState`、`src/builtins/table.rs` の `builtin_decl`・`lookup_builtin`）を参照する。そこで `place` は、`sig=` の関数の宣言を、本体を `todo!()` にした関数（`todo!()` の仮置き）として置き、仮置きを置いたファイルの先頭（`//!` の行の後）に仮置きの許可 `#![allow(clippy::todo, unused_variables)]` とその理由のコメントを置く（[00-02](../00-common/00-02-conventions.md)「`todo!()` の仮置き」）。書く前に rustfmt（`--edition 2024`）で整えるので、置いたファイルの書式は章のコードと違うことがあるが、内容は同じである。仮置きは後の作業が本体に書き換え、ファイルに `todo!()` が残らなくなった作業が許可を消す。

2026-09-30 に、C04 の後の形を写したクレートで `place --task C01 --overwrite` を行い、Clippy（二つのメモリの管理の機能のそれぞれ）と `cargo test --no-run` が通ることを確かめた。

## 手順の要点

1. リポジトリの根で、置くものを確かめる。

   ```sh
   python3 docs/implement/tools/extract_interfaces.py list --task C01
   python3 docs/implement/tools/extract_interfaces.py place crates/benitoite --task C01 --overwrite --dry-run
   ```

   `--dry-run` の出力で、`overwrite` が `src/lib.rs` の一つだけであり（C04 が書いた移行の間の形を置き換える）、`refuse` がないことを確かめる。`refuse` があれば、C04 が空けたはずのパスにファイルが残っている。原因を報告して止まる。
2. 同じコマンドを `--dry-run` なしで実行する。`--overwrite` は、見出しに `replace` を付けた `src/lib.rs` を上書きするために要る。道具は `sig=` の関数を `todo!()` の仮置きとして置き、仮置きの許可を書き、rustfmt で整える（上の「`sig=` の項目の置き方」）。
3. `scripts/check.sh` を実行する。
4. 取り出したコードは手で直さない。コンパイル・lint・書式のどれかが通らなければ、誤りの内容と、どの章のどのブロックが原因かを報告して止まる（00-03「型やシグネチャを変える必要が生じたとき」）。本プランの側を直してから、取り出しをやり直す。`cargo fmt --check` だけが通らない場合も、手で整形せずに報告する（道具が rustfmt で整えるので、通らなければ道具の不具合である）。
5. `lib.rs` の `#![allow(dead_code)]` はそのまま残す（00-02「`#[allow]` を書いてよい箇所」。C18 が外す）。
6. `list --task C01` の出力を完了の報告に貼る。後の作業と確認の担当が、どのファイルが C01 のものかを確かめるためである。

C01 は、道具が作った中身のないモジュールのファイルを、`legacy` のものと取り違えないように注意する。道具は先頭のコメントだけのファイルを作り、C02 はそれを「ないもの」として埋める（[README](../README.md) の「インターフェースの読み方」）。中身のないファイルに手でコードを書かない。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `scripts/check.sh` | すべて通る。二つのメモリの管理の機能のそれぞれで lint とテストが通る。最小実行版のテストは `legacy` で動き続ける |
| 機能の排他 | `cargo check --no-default-features` と `cargo check --no-default-features --features gc-mark-sweep,gc-refcount` が、10-08 の `compile_error!` の文で止まる（手で確かめる） |
| `cargo doc -p benitoite --no-deps` | 警告なしに通る |
| 仮置き | `sig=` の関数は本体が `todo!()` の仮置きであり、仮置きのあるファイルの先頭に仮置きの許可とコメントがある |
| 取り出しの再実行 | 作業の後に同じ `place` を実行すると、すべてのファイルが `unchanged` になる（取り出したコードに手を加えていないことの確かめ） |
| `extract_interfaces.py check --task C01 --base crates/benitoite` | 通る（本プランの作成者が確かめた検査を、置いた後のクレートで繰り返す） |

この作業は型の定義だけを置き、振る舞いを持たないので、Rust のテストは書かない。

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書いている
- 取り出したコードを手で直していない。`src/main.rs`・`src/base/`・`src/legacy/` を変えていない

## 難易度の理由

道具を実行して検査を通すだけの作業である。通らない場合も、自分で直さずに報告すればよい。
