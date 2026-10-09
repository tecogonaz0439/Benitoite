# C16 ベンチマークの更新

- 依存する作業: [R12](R12-stage1-measurement.md), [R23](R23-reference-cells.md), [R29](R29-runtime-builtins.md), [R34](R34-type-class-instructions.md), [R36](R36-persistent-vector.md)（理由は「依存を見直した理由」）
- 難易度: 2（1〜5。[README](../README.md) の「作業一覧」の目安）
- 規模の見込み: 中（ベンチマークのプログラムと、測定の道具の追加）
- ブランチ: impl/C16-bench

## 目的

初回リリース版の完了時の測定（[性能](../../design/07-quality/07-02-performance.md)の「初回リリース版の完了時の測定」）のために、追加のベンチマークのプログラムと、追加の測る項目を取る手段を `tools/bench/` に用意する。測定そのもの（静かな計算機での本測定と所見）は、最小実行版と同じく、すべての作業を終えた後にスキル `benchmark` の手順で行う（[完了後の作業](../90-after-completion.md)）。本作業では、道具が動き、出力が比較対象と一致することを確かめる。R33 の前に行う 2 回目の本測定は、`tools/bench/gate.py` による fib・loop の測定であり、本作業の道具は使わない。

U1・U2 の範囲で書けないベンチマーク（`map` の挿入・検索・削除は U3 の `Map` の関数を、`http` は U3 の HTTP を要する）は、U3 の作業が加える。本作業では扱わない。

## 依存を見直した理由

骨子の段階では C16 の依存を R12 としていた。しかし、追加するベンチマークは、ハンドラとタスク（R20〜R29。R29 の依存の連なりに入る）、`Reference` のセル（R23）、型クラスの命令（R34）、永続ベクタのリスト（R36。`List.get` の時間の増え方を見る）を VM で実行できなければ動かない。そこで依存を R12・R23・R29・R34・R36 とした。あわせて、メモリの管理の確定のための測り直し（[R33](R33-memory-management-remeasure.md)）は、本作業が作るベンチマークのプログラム（handler・tasks・cycle）を使うので、C16 に依存する。

## 読む設計書の節

- [性能](../../design/07-quality/07-02-performance.md): 「ベンチマーク集合」「比較対象」「測る項目」「測定の環境と記録」「初回リリース版の完了時の測定」
- [ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md): 決定 3（比べる項目）
- [ADR 0158](../../design/decisions/0158-type-classes-by-dictionary-passing.md)、[ADR 0160](../../design/decisions/0160-one-shot-continuations-as-stack-segments.md)、[ADR 0161](../../design/decisions/0161-single-threaded-task-scheduler.md)、[ADR 0104](../../design/decisions/0104-list-as-persistent-vector.md)、[ADR 0239](../../design/decisions/0239-cycle-collection-for-reference-cells.md)
- [仮想機械](../../design/02-impl/02-08-vm.md): 「タスクの切り替え」（呼び出しの回数の予算）
- インターフェース: [10-13](../10-interfaces/10-13-pipeline-and-cli.md) の `RunEnv`・`RunEnd`・`text::ALLOC_STATS`、[10-08](../10-interfaces/10-08-values-and-heap.md) の `HeapConfig`・`HeapStats`、[10-09](../10-interfaces/10-09-vm.md) の `VmConfig`
- スキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）と `tools/bench/README.md`
- R12 の作業の文書（第 1 段の測定で使った、回収の停止の時間を取る手段）

## 作るもの

パスはリポジトリの根からの相対パスである。

| ファイル | 内容 |
|---|---|
| `tools/bench/programs/trait.bnt` と比較対象の版（`python/`・`ruby/`・`lua/`・`ocaml/`・`rust/`） | 型クラスの制約を持つ多相の関数から、メソッドを繰り返し呼ぶ。比較対象では、それぞれの言語の普通の多相（Python のダックタイピング、OCaml のモジュールかレコードの関数、Rust のトレイトの動的な呼び出し）で書き、違いを README に書く |
| `tools/bench/programs/handler.bnt` | 利用者が定義したエフェクトの操作を繰り返し呼ぶ。引数で、末尾で再開する節と、継続を保存してから再開する節を切り替える（07-02 の二つの形）。後者は、`resume` の後に計算が続く節（末尾でない再開。VM は継続の区画を保存する）の意味であり、継続を値として持ち出して後で再開する形ではない（`resume` は節の中でだけ直接呼べ、継続は値にならない。01-07）。Benitoite だけ |
| `tools/bench/programs/tasks.bnt` | 引数の数のタスクを `TaskGroup` の中で起動し、それぞれに計算させ、すべての終わりを待つ。Benitoite だけ |
| `tools/bench/programs/cycle.bnt` | `Reference` のセルで循環する値を作っては捨てる。Benitoite だけ |
| `tools/bench/programs/listget.bnt` と比較対象の版 | 長さを引数で与えた大きなリストに、`List.get` を無作為の位置（決まった種の擬似乱数）で繰り返す。擬似乱数は、スクリプトの中の整数の演算（線形合同法など）で作る（`Random` は U3 で入るので使わない）。整数の溢れは実行時エラーになるので、各段で剰余をとって値を小さく保つ。比較対象の版も同じ式で同じ位置の並びを作る |
| 各ベンチマークの `.args.small` | 差分テスト（C10 の `BENCH_DIRS`）で数十ミリ秒で終わる入力。`listget` は長さ・回数とも 1,000 程度に抑える（参照インタプリタは組み込みの呼び出しごとにリスト全体を写すので、大きな長さでは差分テストが遅くなる）。`tasks` は、参照インタプリタが `TaskGroup.spawn` を `Unsupported` にし、差分テストの比較が `Excluded` になるので外れる。`tests/golden.rs` は変えない |
| `crates/benitoite/examples/bench_run.rs` | 開発用の例（下記）。新しく作る。`examples/stage1_bench.rs`・`examples/stage1_support/`・`tools/bench/gate.py` は変えない（`stage1_bench` は第 2 段の命令を拒み、`gate.py` の本測定に使っているため）。`stage1_support` を `#[path]` で読んで使うのはよい |
| `tools/bench/run.py` | 追加のベンチマークと追加の項目（下記） |
| `tools/bench/results/TEMPLATE.md`・`tools/bench/report_html.py` | 追加の項目の表とグラフ |
| `tools/bench/README.md` | 追加のベンチマーク、項目、測り方、近似であるものの説明 |

処理系の `src/` は変えない。CLI にない値（回収の停止の時間、呼び出しの回数の予算）は、開発用の例で取る。

## 手順の要点

### 開発用の例 `bench_run`

CLI は `alloc-stats` の一行（確保の回数と量、最大のヒープの量、回収の回数）しか出さない（10-13 の `text::ALLOC_STATS`）。07-02 の追加の項目のうち、回収の停止の時間（p50・p95・p99・最大）、呼び出しの回数の予算を変えた実行、検査と実行の時間の内訳は、CLI では取れない。そこで、パイプラインの公開の関数を呼ぶ開発用の例を置く。

- 引数は、スクリプトのパスとスクリプトの引数、選択肢 `--call-budget=<数>`・`--trigger-factor=<百分率>`・`--io-mode=direct|request`・`--repeat-check=<回数>` とする。
- `pipeline::check_path`・`desugar_checked`・`compile`・`runtime::run::run_program` を順に呼び、段ごとの実時間を測る。`RunEnv` の `vm.call_budget` と `heap.trigger_factor_percent` に選択肢の値を入れる。
- 終わった後に、段ごとの時間と `RunEnd::heap`（`HeapStats`）の項目（停止の時間の並びから計算した p50・p95・p99・最大と合計、回収の回数、最大のヒープの量）を、標準エラー出力に `bench-run: key=value …` の一行で書く。スクリプトの標準出力は `OutputTarget::Stdout` のまま流す。
- 標準ライブラリの読み込みと型検査にかかる時間（07-02 の「起動と検査にかかる時間の内訳」）は、`main` が `()` を返すだけのスクリプトの検査の時間を標準ライブラリの分の近似とし、大きなスクリプトの検査の時間との差をそれ以外の分とする。近似であることを README と記録に書く。
- 例のコードも処理系の規約（lint、文言をまとめる規約は開発用の例なので対象外とし、その旨を先頭の `//!` に書く）に従う。

### `run.py` に加える項目

| 項目 | 測り方 |
|---|---|
| 追加のベンチマークの実行時間 | 最小実行版と同じく 10 回の中央値。`handler` は二つの形を別の行にする |
| 回収の費用 | `cycle`・`list`・`tree`・`eval` を `bench_run` で実行し、停止の時間の p50・p95・p99・最大、回収の時間の合計、最大の常駐メモリを記録する |
| 並行処理でのメモリ | `tasks` を、同時に存在するタスクの数を変えて（例: 1,000・10,000・100,000）実行し、最大の常駐メモリからタスク一つあたりのメモリを見積もる |
| 呼び出しの回数の予算 | `tasks` を、予算の値を変えて（既定の値の 1/4・1/2・1・2・4 倍）`bench_run` で実行し、実行時間を記録する（`http` の応答までの時間との釣り合いは U3 の後） |
| リストの添字の時間 | `listget` を長さ 10^3・10^4・10^5・10^6・10^7 で実行し、一回あたりの時間を記録する |
| 起動と検査の内訳 | 上の `bench_run` の近似 |

- 追加の項目は、選択肢（`--first-release`）を与えたときだけ測る。最小実行版の項目だけの測定（R12 の比べ方）を変えないためである。
- 入力の大きさは、Benitoite での実行時間が 1〜10 秒になるように `BENCH_INPUTS` に仮の値を置く。本測定の前に調整する（90-after-completion）。

### 比べ方の注意

- 比較対象の言語で同じ処理を素直に書けないベンチマーク（handler、tasks、cycle）は、Benitoite だけで測る（07-02）。記録の表では比較対象の欄を空にし、処理系を変えた前後の比較に使うことを書く。
- 中間表現の最適化の有無の比較と、musl と glibc のビルドの比較は、本作業の範囲ではない（最適化はまだなく、musl のビルドは配布の作業が作る）。90-after-completion に残す。

## 受け入れテスト

| 場合 | 期待 |
|---|---|
| 検査と小さな入力 | 追加したすべての `.bnt` が `benitoite check` を通り、`.args.small` の入力で `benitoite run` が終了状態 0 で終わる |
| 出力の一致 | `run.py --verify` で、`trait` と `listget` の出力が比較対象の各言語の版と一致する |
| 差分テスト | C10 の差分テストが、追加したベンチマーク（`tasks` を除く）で通る |
| `bench_run` | 小さな入力の `cycle` で、`bench-run:` の行に停止の時間の項目が出る。二つの IO の方式で実行できる |
| 記録 | `run.py --first-release` を小さな入力の設定（`--quick` などの試し用の選択肢を加えてよい）で実行し、記録と HTML ができる。試しの記録は `tools/bench/results/` に残さない |

## 完了条件

- `scripts/check.sh` が通る（00-02「完了条件の共通の検査」）
- 受け入れテストのすべての場合を確かめ、完了の報告に結果を書く

## 難易度の理由

プログラムは小さく、アルゴリズムの難しさはない。判断が要るのは、CLI で取れない値を開発用の例で取る範囲を決めることと、近似で測る項目を記録の上で近似と分かるように書くことである。
