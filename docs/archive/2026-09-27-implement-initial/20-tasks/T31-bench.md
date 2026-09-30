# T31 ベンチマーク

- 依存する作業: [T24](T24-pipeline-cli.md), [T25](T25-golden-runner.md)
- 難易度: 2（1〜5。README の「難易度の目安」）
- 規模の見込み: 中（ベンチマークのスクリプトが 8 本 × 5 言語と、測定のスクリプト）
- ブランチ: impl/T31-bench

## 目的

最小実行版の完了後に行う性能の測定（07-02）のために、ベンチマークのスクリプトと、比較対象の言語で同じ処理を書いたもの、測定の手順を行うスクリプト、測定記録のひな形を用意する。測定そのものは本作業の範囲ではなく、最小実行版の完了後に行う（[完了後の作業](../90-after-completion.md)）。ベンチマークのうち最小実行版の範囲で書けるものが実行できることは、ロードマップの最小実行版の完了条件に含まれる。

## 読む設計書の節

- [性能](../../2026-09-27-design-initial/07-quality/07-02-performance.md): 全節
- [ロードマップ](../../2026-09-27-design-initial/00-overview/00-03-roadmap.md): 最小実行版の「完了条件」の最後の段落、「性能の測定」
- [処理系のテスト戦略](../../2026-09-27-design-initial/07-quality/07-03-compiler-testing.md): 「差分テスト」（ベンチマークの入力を小さくしたものを差分テストにかける）
- [CLI](../../2026-09-27-design-initial/06-tooling/06-01-cli.md): 「開発用の設定」（`BENITOITE_DEV_IO_MODE`）
- [標準ライブラリ](../../2026-09-27-design-initial/03-interop/03-06-stdlib.md): スクリプトで使う関数
- [リポジトリとクレートの配置](../00-common/00-01-repository-layout.md): `tools/bench/` の配置
- [実行時の値、VM、ランタイム](../10-interfaces/10-08-runtime.md): 「ヒープ」（`AllocStats` と `alloc-stats` の機能）
- [T25 ゴールデンテストの実行器](T25-golden-runner.md): 「差分テスト」の `.args.small` の決まり

## 作るもの

- `tools/bench/programs/<名前>.bnt` と `tools/bench/programs/<名前>.args.small`（`<名前>` は `fib`・`loop`・`list`・`tree`・`eval`・`string`・`println`・`lines`）
- `tools/bench/programs/python/<名前>.py`、`tools/bench/programs/ruby/<名前>.rb`、`tools/bench/programs/lua/<名前>.lua`、`tools/bench/programs/rust/`（ワークスペースの外の Cargo のプロジェクト。`src/bin/<名前>.rs` を 8 本）
- `tools/bench/programs/gen_lines.py`（`lines` の入力のファイルを作る）
- `tools/bench/run.py`（測定の手順を行う。Python 3 の標準ライブラリだけ）
- `tools/bench/results/TEMPLATE.md`（測定記録のひな形）
- `tools/bench/README.md`（道具の導入と、測定の手順）

## 手順の要点

### ベンチマークのスクリプト

- 07-02「ベンチマーク集合」の表の 8 本を、表の「処理」と「主に負荷をかける部分」のとおりに書く。`fib` は末尾でない再帰、`loop` は末尾再帰で数え上げる、`list` は `List.range` で作ったリストに `List.map`・`List.filter`・`List.fold` を続けて適用する、`tree` は二分木を代数的データ型で作って辿る、`eval` は式を代数的データ型で表した小さなインタプリタ、`string` は文字列の連結・`String.split`・数え上げ、`println` は多数の行を `Console.println` で書く、`lines` は大きなファイルを `File.readText` で読んで `String.lines` で行数を数える。
- 入力の大きさは、コマンドライン引数から `Int.parse` で読む（`lines` はファイルのパス）。引数が読めなければ `main` が `Err` を返す。
- どのスクリプトも、結果を一行以上、標準出力に書く（最適化で処理が消えないことと、言語の間で結果を突き合わせるため）。
- `.args.small` には、差分テスト（T25）で数十ミリ秒で終わる小さな入力を書く。`lines` の小さな入力のファイルは `.args.small` から読めるように、`tools/bench/programs/` の下に小さな入力のファイルを置く。【新しい決定】差分テストは `TestIo` を使うので、`lines` の差分テストではファイルを読めない（`Err` の分岐に入る）。差分テストでファイルを読ませる手段は設けず、`lines` は `Err` の分岐の差分テストだけになることを README に書く。
- 比較対象の言語のスクリプトは、同じアルゴリズムと同じ出力にする（07-02「ベンチマーク集合」の「同じ処理を書いたもの」）。Rust の版は、`Vec` などの標準ライブラリの普通の書き方でよい。同じ処理にするため、`list` は連結リストでなく各言語の標準のリスト（配列）を使ってよいが、その違いを README に書く。

### 測定のスクリプト

- 【新しい決定】測定には、Python 3 の標準ライブラリだけで書いた `tools/bench/run.py` を使う。hyperfine などの外部の道具を前提にしない。どの環境でも同じ手順で動かすためである。
- `tools/bench/run.py` は、07-02「測る項目」の各項目を次のように測る。

| 項目 | 測り方 |
|---|---|
| 実行時間 | 各ベンチマークを 10 回実行した実時間の中央値（`time.perf_counter`）。本言語では、`benitoite run` 全体の時間と、`benitoite check` の時間の中央値を別に記録し、差を「検査とコード生成を含まない時間」の近似として記録する（【新しい決定】CLI に段ごとの時間を出す手段を設けないため。近似であることを記録に書く） |
| 起動から終了までの時間 | `main` が `()` を返すだけのスクリプトを 10 回実行した中央値 |
| 検査にかかる時間 | 関数を多数並べて生成した 1 万行程度のスクリプト（`run.py` が生成する）の `check` の時間 |
| メモリ | 最大の常駐メモリ。macOS では `/usr/bin/time -l`、Linux では `/usr/bin/time -v` の出力から読む |
| 確保と解放 | 本言語の各ベンチマークの確保の回数・量・解放の回数（下記） |
| 実行時間の内訳 | CPU プロファイル（下記） |

- IO の二つの方式（07-02）: `println` と `lines` を、環境変数 `BENITOITE_DEV_IO_MODE=direct` と `request` で測る。
- 命令の長さ: 各ベンチマークのバイトコードの大きさ（命令の数）は、最小実行版の完了後の測定のときに、`bytecode::disasm::disassemble` の出力から数える（90-after-completion）。本作業の `run.py` は数えない。
- 確保と解放: 機能 `alloc-stats` を有効にしてビルドした処理系で数える。`alloc-stats` のビルドで環境変数 `BENITOITE_DEV_ALLOC_STATS=1` を与えると、CLI（T24）が実行の後に `alloc-stats allocations=<n> bytes=<n> freed=<n>` の一行を標準エラー出力に書く（10-09「開発用の設定」）。`run.py` はこの行を読んで記録する。
- CPU プロファイル: 【新しい決定】道具は samply とする（07-02 が「取る道具は実装プランで選ぶ」とした）。macOS と Linux の両方で動くとされる。【要検証】導入の方法（`cargo install samply --locked`）と、プロファイルの出力の形を、作業のときに確かめて README に書く。`run.py` は `--profile` を指定したときだけ samply を呼ぶ。内訳の集計（命令の振り分け、値の操作、参照の数の増減と解放、組み込みの関数）は、測定のときに人がプロファイルを読んで行う。
- 比較対象: CPython、Ruby（MRI）、Lua、Rust（`--release` でビルド）。CPython と Ruby は、JIT を持つ版では無効と有効の両方を測る（07-02「比較対象」）。【要検証】CPython の JIT を有効にする方法（ビルドの設定と環境変数）と Ruby の YJIT を有効にする方法（`--yjit`）は、測定のときに使う版の文書で確かめる。`run.py` は、見つからない処理系を飛ばし、飛ばしたことを記録する。
- 入力の大きさは、本言語での実行時間が 1 秒から 10 秒程度になるように、`run.py` の中の表で決める（07-02）。本作業では仮の値を置き、測定のときに調整する。
- 記録: `run.py` は、`tools/bench/results/<日付>-<コミットの短い名前>.md` に、`TEMPLATE.md` の形で結果を書く。記録には、CPU・メモリ・OS、`rustc --version`、処理系のコミット、比較対象の各処理系の版を含める（07-02「測定の環境と記録」）。

## 受け入れテスト

- `tools/bench/programs/` の 8 本の本言語のスクリプトが、`benitoite check` を通り、`.args.small` の入力で `benitoite run` が終了状態 0 で終わる（`lines` は小さな入力のファイルを与えて実行する）。
- 各スクリプトの出力が、同じ入力の Python の版の出力と一致する（`run.py --verify` で確かめる。`run.py` は、見つかった処理系ごとに、小さな入力で本言語の出力と比べる）。
- T25 の差分テスト（`tools/bench/programs/*.bnt` と `.args.small`）が通る。
- `run.py` を、比較対象の処理系が一つもない環境で実行しても、本言語だけの記録を作って終わる。

## 完了条件

- scripts/check.sh が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめるテストがある（`run.py --verify` の実行の結果を完了の報告に書く）

## 難易度の理由

同じ処理を五つの言語で書くので量は多いが、どの処理も小さく、アルゴリズムの難しさはない。判断が要るのは、各言語で同じ処理になっているかを揃えることと、07-02 の測る項目のうち処理系の側の仕組みが要るもの（確保の回数、命令の数）を本作業の範囲の外として切り分けることである。
