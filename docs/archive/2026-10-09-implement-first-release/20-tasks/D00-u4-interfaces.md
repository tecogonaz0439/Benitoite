# D00 U4 のインターフェースを置く

- 依存する作業: [F18](F18-pipeline-cli.md)
- 難易度: 1（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（500〜1500 行。ただし大部分は書くのではなく取り出して置く）
- ブランチ: impl/D00-u4-interfaces

## 目的

U4 のインターフェースの章（[10-17](../10-interfaces/10-17-formatter.md)・[10-18](../10-interfaces/10-18-test-runner.md)・[10-19](../10-interfaces/10-19-skill-and-distribution.md)）を処理系のクレートに置く。あわせて、prelude のモジュール `Benitoite.Assert` のソースと、その操作の組み込みの関数の表の部分を加える。`Assert` は prelude のモジュールなのでどの検査でも読まれ、表に操作がないと名前解決が処理系の不具合を報告する（10-18「組み込みの関数の表の部分」）。ソースと表の部分を同じ作業で加えるのはそのためである。

D00 の後、フォーマッタ（D01〜D04）、テストの実行器（D10〜D12）、Skill（D20 以降）、ライセンスの表示（D30）の作業が始められる。U3 の L00 とは互いに依存しないので、どちらを先に取り込んでもよい。

## 読む設計書の節

- [実装プランの README](../README.md): 「インターフェースの章」「インターフェースの読み方」「U3・U4 で決めたこと」
- [作業の進め方](../00-common/00-03-workflow.md): 「インターフェースの凍結」「型やシグネチャを変える必要が生じたとき」
- 取り出しの道具 [tools/extract_interfaces.py](../tools/extract_interfaces.py) の先頭のコメント（`append=` の扱い）
- インターフェース: 10-17・10-18・10-19 の全体。[10-12](../10-interfaces/10-12-builtin-table.md) の「表の組み立て」「名前の付け方」「まだ書かない項目の仮の本体」、[10-11](../10-interfaces/10-11-builtin-interface.md) の「宣言のマクロ」、[10-14](../10-interfaces/10-14-prelude-and-stdlib-sources.md) の「置き方」

## 作るもの

パスは処理系のクレート `crates/benitoite/` からの相対パスである。

- `python3 docs/archive/2026-10-09-implement-first-release/tools/extract_interfaces.py list --task D00` が挙げるファイル。新しく置くのは `src/cli/tools/` の下（`args.rs`、`formatter/`、`test_runner/`、`skill/`、`licenses.rs`）、`src/runtime/assert.rs`、`src/prelude/stdlib/Assert.bnt` である。既存のファイル（`src/cli/tools.rs`、`src/runtime/mod.rs`・`run.rs`、`src/vm/mod.rs`、`src/diag/render.rs`、`src/prelude/mod.rs`）には、道具が `append=` のコードと `sig=` の `todo!()` の仮置きを足す。
- `src/builtins/funcs/assert.rs`: 10-18「組み込みの関数の表の部分」の四つの項目を `builtin!` の `io` の権限で書く。本体は `Err(Stop::Internal(String::from("Assert operation reached the handler table")))` を返し、引数は使わない（`let _ = (ctx, …);`）。引数の Rust の型は `Value<'e>` とする。これは最終の形であり、後の作業は書き換えない。ファイルの先頭の `//!` に、テストの実行器が VM の中で処理するので表の関数としては呼ばれないことと、10-18 の節を書く。
- `src/builtins/funcs/mod.rs`: `pub mod assert;` を加え、`PARTS` の末尾に `assert::DECLS` を加える（00-03「インターフェースの凍結」の `funcs/mod.rs` の例外）。

- `src/builtins/table.rs`: F06 の照合のテスト `table_names_parts_capabilities_and_schemes_are_consistent` が部分ごとの項目の数と合計を値で書いているので、`assert::DECLS` の分を加える（`lengths` の末尾に 4、`names.len()` を 168、権限ごとの数を `[137, 12, 19]`。L00 が先に取り込まれていれば、その値に 4 項目を足す）。このテストの値のほかは変えない。

- `src/modules/tests.rs`: `prelude_order_kinds_and_clock_dependency` の prelude のモジュールの一覧の末尾（`"IO"` の後）に `"Assert"` を加える。

置いたファイルは手で直さない（上の四つを除く）。

## 手順の要点

1. リポジトリの根で、置くものを確かめる。

   ```sh
   python3 docs/archive/2026-10-09-implement-first-release/tools/extract_interfaces.py list --task D00
   python3 docs/archive/2026-10-09-implement-first-release/tools/extract_interfaces.py place crates/benitoite --task D00 --dry-run
   ```

   `refuse` が出たら、本プランの誤りである。報告して止まる。`overwrite` は出ない（本作業の章に `replace` はない）。
2. 同じコマンドを `--dry-run` なしで実行する。
3. `src/builtins/funcs/assert.rs` を書き、`funcs/mod.rs` に宣言と部分を加える。
4. `scripts/check.sh` を実行する。10-12 の照合のテスト（F06）が、`Assert` のソースと表の部分を含めて通ることを確かめる。U3 の L00 が先に取り込まれていれば、U3 の部分の後に `assert::DECLS` が並ぶ。番号の値はどのコードにも書かないので、順は問わない（10-12「番号の振り方」）。
5. `todo!()` の仮置きは、`todo!()` を含むファイルにだけ置かれる（道具の先頭のコメント）。仮置きの許可の残りの検査が失敗したら、道具の不具合として報告する。
6. `list --task D00` の出力を完了の報告に貼る。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| `scripts/check.sh` | すべて通る。F18 の CLI のテスト（`test`・`fmt`・`skill`・`--licenses` が `TOOL_UNAVAILABLE` で終了状態 2）も、そのまま通る |
| 照合のテスト（F06） | `Benitoite.Assert.equal` など四つの操作が表にあり、引数の数と権限がソースの宣言と合う |
| 型検査 | `uses Assert.Check` を持つ `@test` の関数と、`Assert.equal(1, 1)` を呼ぶ関数を含むプログラムが、`check_text`（`require_main` は偽）で誤りなく通る。単体テストを `src/builtins/funcs/assert.rs` のテストのモジュールに一つ置く |
| 取り出しの再実行 | `place --task D00` をもう一度実行すると、すべてのファイルが `unchanged` になる |
| 道具の再実行 | `extract_interfaces.py place crates/benitoite --task D00` をもう一度実行すると、すべてのファイルが unchanged になる（`check --task D00` は D00 と関係のない既知の理由で失敗する。C02 の重ね直しで `funcs/mod.rs` の rustfmt が失敗し、`--base` なしでは `base::source` の import で失敗する。実行しなくてよい） |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書いている
- 取り出したコードを手で直していない。C01・C02 が置いた `file=` のコードを、道具の `append=` と `sig=` のほかに変えていない

## 難易度の理由

道具を実行し、表の部分を 10-18 の表のとおりに書くだけの作業である。判断が要るのは、照合のテストが通らないときに原因がソースか表の部分かを見分けることだけである。
