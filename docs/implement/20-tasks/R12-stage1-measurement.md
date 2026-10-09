# R12 第 1 段の測定

- 依存する作業: [R11](R11-heap-verification.md)、[C05](C05-test-switchover.md)
- 難易度: 3（1〜5。README の「作業一覧」）
- 規模の見込み: 中（500〜1500 行。測定の道具とワークロードと記録）
- ブランチ: impl/R12-stage1-measurement

## 目的

作り直しの第 1 段の二つのメモリの管理（マーク・スイープと改良した参照カウント）を、同じ値の配置・確保器・VM の上で比べて測り、暫定に採る方式と回収の閾値の係数 k を設計者が判断するための記録を作る（[ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 3・4、[ADR 0268](../../design/decisions/0268-staged-runtime-rebuild.md) の決定 3〜5）。記録は `tools/bench/results/` に置き、比べた構成（コミット、ビルドの設定、方式の切り替え）、入力、結果、暫定に採る方式の案、k の判断の案を書く。

本作業は測って記録し、案を示すところまでを行う。方式と k を決めるのは設計者であり、オーケストレータが記録を設計者に示して確かめてから、R14 を起動する（[作業の進め方](../00-common/00-03-workflow.md)の「第 1 段の後の確認」）。

測定は、C05 が新しい構文へ移したベンチマークのプログラム（`tools/bench/programs/` の `.bnt`）と、本作業が加えるワークロードで行う。第 1 段の完了の条件の「最小実行版のすべてのテストが、両方式と回収の強制の下で通る」は、C05 が満たしている（[ADR 0278](../../design/decisions/0278-stage-1-completes-on-new-syntax-tests.md) の決定 1）。

測定はスキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）の手順に従う。計算機を静かにすることと、測定の間にほかの作業を動かさないことは、スキルのとおり設計者の了承を得てから行う。

## 読む設計書の節

- [性能](../../design/07-quality/07-02-performance.md)の全体（とくに「ベンチマーク集合」「測る項目」「測定の環境と記録」「測定の結果の使い方」「初回リリース版の完了時の測定」の回収の費用の行）
- [ランタイム](../../design/02-impl/02-09-runtime.md)の「メモリの管理」
- [ADR 0239](../../design/decisions/0239-cycle-collection-for-reference-cells.md)（決定 3・6）、[ADR 0258](../../design/decisions/0258-sixteen-byte-value-enum.md)（決定 6）、[ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md)、[ADR 0263](../../design/decisions/0263-dispatch-loop-locals-and-verifier.md)（決定 5）、[ADR 0268](../../design/decisions/0268-staged-runtime-rebuild.md)、[ADR 0269](../../design/decisions/0269-correct-adr-0240-performance-assessment.md)、[ADR 0277](../../design/decisions/0277-refcount-defers-freeing-to-safepoints.md)（帰結の最後の箇条）、[ADR 0280](../../design/decisions/0280-reuse-by-dedicated-construct-instruction.md)（決定 4）
- 未決事項: [OPEN-036](../../design/open-issues.md#open-036)、[OPEN-065](../../design/open-issues.md#open-065)、[OPEN-009](../../design/open-issues.md#open-009)
- インターフェース: [値とヒープ](../10-interfaces/10-08-values-and-heap.md)の「設定と測定の記録」、[パイプラインと CLI](../10-interfaces/10-13-pipeline-and-cli.md)の「パイプライン」「実行の流れ」
- 道具: `tools/bench/README.md`、`tools/bench/results/TEMPLATE.md`、最小実行版の測定の記録（`tools/bench/results/2026-09-27-1ff816b0b156.md`）
- 経緯: [相談の第 1 回](../studies/u2-runtime/consult/01-memory-and-values.md)の「要点」の 1・3・7（比較で確保器・値の大きさ・VM の改善を GC の成果と取り違えないこと、逆転しうる負荷、閾値の比べ方）

## 作るもの

- 測定の道具（置き場所は例）:
  - `examples/stage1_bench.rs`: 初回リリース版のパイプライン（`pipeline::check_path` → `desugar_checked` → `compile`）と `runtime::run::run_program` を、`RunEnv::heap` の k を指定して実行し、`RunEnd::heap`（`HeapStats`）を機械で読める形（1 行の `key=value` の並びなど）で標準エラー出力に書く例のプログラム。CLI は k を指定する口を持たない（10-13「CLI」）ので、k を変える測定と、`HeapStats` のすべての項目を読む測定にはこの例を使う。CLI と同じ関数を通るので、測る処理は CLI と同じである。
  - `examples/stage1_heap_bench.rs`: ヒープの単位の測定（循環など。後述）を行う例のプログラム。`runtime::heap` の公開の層だけを使う。
  - `tools/bench/stage1.py`: 構成ごとのビルド、ワークロードの実行、`HeapStats` と最大常駐メモリの収集、記録の Markdown の作成を行うスクリプト。`tools/bench/run.py` の関数を使ってよいが、`run.py` の既存の振る舞いは変えない（ベンチマークの道具の更新は C16 が行う）。
- 追加のワークロード（新しい構文の `.bnt`）: `tools/bench/programs/stage1/` の下に置く（後述）。
- 測定の記録: `tools/bench/results/<日付>-stage1-<コミット>.md` と、スキルの手順で作るグラフ付きの `.html`。CPU プロファイルの所見を含める。
- 測定のためだけのリビジョン（後述の「整数の値の範囲と対象の大きさの記録」と、参照カウントの循環の回収の記録を読む口）。本番の枝には取り込まず、オーケストレータが名前を付けて残し、記録にコミットを書く。

`examples/` の新しいファイルは、`scripts/check.sh` の書式と lint の検査（両方式の `clippy --all-targets`。workspace の lint は examples にも効き、`#[allow]` の表に examples はない。百分位などの計算は checked の演算で書く）を通す。`tools/bench/` の Python は `check.sh` が検査しない。

### 実装担当とオーケストレータの分担

- コミット: 実装担当は 00-03 のとおりコミットしない。本番の枝に取り込むもの（道具、ワークロード、記録）と測定のためだけの変更を同じ作業ツリーに作り、完了の報告で、本番に取り込むファイルと測定だけのファイル（と、その変更を戻す方法）を分けて挙げる。オーケストレータが測定だけの変更を `measure/R12-*` の枝にコミットし、本番の枝には挙げられたファイルだけを取り込む。記録のコミットとファイル名は仮の字句（`<COMMIT>`）にしておき、オーケストレータが埋めて改名する。測定のためだけの変更では、凍結したファイル（VM の振り分け、ヒープの内部の層の確保、`refcount.rs` の `cycle_stats` の `cfg(test)` など）と型を変えてよい。
- 時間の本測定: 計算機を静かにすることが要る（スキル `benchmark` の「始める前に確かめること」の 1）ので、オーケストレータがほかの作業を止めてから行う。実装担当は、出力の照合、`HeapStats` のうち決まった値になる項目（`allocations`・`allocated_bytes`・`live_bytes`・`peak_heap_bytes`・`collections`・`roots_traced`・`rc_*`・`reuses`）、最大常駐メモリ（`/usr/bin/time -l`）、各構成を短い回数で動かす確認を行って記録に書く。実行時間・`pause_nanos` の分布・CPU プロファイルの欄は空けておき、それらを埋めるコマンド（`stage1.py` の本測定の指定、samply の使い方）を記録に書く。オーケストレータがそのコマンドで埋める。

## 手順の要点

### 比べる構成

| 構成 | ビルド | 設定 |
|---|---|---|
| MS-k0.5・MS-k1・MS-k2 | `--no-default-features --features gc-mark-sweep`、release | `HeapConfig::trigger_factor_percent` を 50・100・200 |
| RC | `--no-default-features --features gc-refcount`、release | 既定。遅らせた解放の要求の条件と循環の回収の閾値は R04 の値 |
| RC-noreuse | RC と同じビルド | `HeapConfig::reuse` を偽にする（[ADR 0280](../../design/decisions/0280-reuse-by-dedicated-construct-instruction.md) の決定 4。命令の並びは RC と同じ）。`examples/stage1_bench.rs` の `RunEnv::heap` で設定する。ADR 0259 の決定 3 の「その場での再利用を無効にした場合も並べて測る」 |

- すべての構成の時間を `examples/stage1_bench.rs` で測る（CLI と同じ関数を通り、構成どうしの条件が揃う）。検査とコード生成を含む時間と含まない時間は、`stage1_bench` の中で段ごとに `Instant` で測る。
- 実行時間は `heap-verify`・`alloc-stats`・`gc-stress` を有効にしないビルドで測る。確保の回数などは `HeapStats` から読む（`HeapStats` は既定のビルドでも数える項目である）。`alloc-stats` の計数が要るときは、スキルのとおり別のビルドで数える。
- その場での再利用は `CONR` で必ず実装される（R09）ので、RC-noreuse はつねに測り、RC と並べて再利用の有無の差を記録する。
- 比較対象の言語（CPython など）は、スキルの本測定の手順で、既存の 8 本について一度だけ測れば足りる。第 1 段の判断は、Benitoite の構成どうしの比較で行う。

### ワークロード

[ADR 0268](../../design/decisions/0268-staged-runtime-rebuild.md) の決定 3 のとおり、次のものを測る。

| ワークロード | 内容 | 置き場所 |
|---|---|---|
| fib・loop・list・tree・eval・string | C05 が新しい構文に移した既存のベンチマーク | `tools/bench/programs/` |
| 共有の多いグラフ | 部分木を共有する木（同じ部分木を何度も含む大きな構造）を作って辿り、捨てる | `programs/stage1/` |
| 大きな生きているグラフと短命な値の混在 | 大きな木を保ったまま、短命なリストと文字列を多く作って捨てる | 同上 |
| 根の大量の削除 | 大きな構造を多くの枠のレジスタに分けて持ち、まとめて手放す（深い再帰の中で作り、戻るときに手放す形） | 同上 |
| 続けて戻る処理 | 深い末尾でない再帰の底で値を作り、呼び出しを挟まずに続けて戻る | 同上 |
| 大きさの違う対象の混在 | 小さな構成子の値、中くらいの文字列、長いリストを混ぜて作る | 同上 |
| 循環 | `Reference` のセルで循環する値を作っては捨てる。第 1 段の VM は `Reference` の操作を実行しないので、ヒープの単位で測る（下記） | `examples/stage1_heap_bench.rs` |

- `.bnt` のワークロードは、最小実行版の言語の機能（C03 の書き直しの範囲）だけで書く。F15 がこれを段が 1 の命令だけに移すことを、新しいパイプラインの `bytecode::disasm::disassemble` か、`Proto::code` の各命令の `opcode()?.in_stage1()`（`codegen/tests.rs` と同じ方法）で確かめる（`stage1_bench` の選択肢などで行う）。既存の `examples/disasm.rs`・`bytecode_stats.rs` は `legacy` のパイプラインを使い、新しい構文を読めない。
- 入力の大きさは、07-02「ベンチマーク集合」のとおり、実行時間が 1 秒から 10 秒になるように決める。本測定の入力は `stage1.py` の辞書に、小さな入力は `<名前>.args.small` に、出力を照合する期待値は `<名前>.stdout.small` などに置く。

### ヒープの単位の測定（循環）

第 1 段の循環の測定は、VM の測定と記録の上で分け、ヒープの単位の測定として扱う（[ADR 0268](../../design/decisions/0268-staged-runtime-rebuild.md) の決定 2 の最後の箇条）。この測定から、言語の `Reference` の操作との統合まで確かめたとは扱わない。

- `examples/stage1_heap_bench.rs` は、`Heap::epoch` の中で `alloc_cell`・`cell_set`・`alloc_fields` で循環（自己参照のセル、二つのセルの相互参照、セルと値の並びの長い輪、大きなリストをセルに入れた循環）を作り、根（`RootStack`）から外してから安全点に当たる位置で `Heap::collect` を呼ぶ、を繰り返す。
- 両方の方式で、回収の時間の合計、一回の停止の時間の分布、最大常駐メモリ、残った対象の数を測る。参照カウントでは、循環の回収の回数と時間を、遅らせた解放と分けて記録する（R04 の内部の記録 `HeapCore::cycle_stats` を読む。この口は `#[cfg(test)]` なので、測定のためだけのリビジョンで `cfg(test)` を外し、`Heap` に公開の口を足して読む。本番の example は `HeapStats` だけを出す）。参照カウントの `Heap::collect` は循環の回収の条件（新しいセルの数、確保の量の閾値。`trigger_factor_percent`・`trigger_min_bytes` にもよる）を満たさないと循環を回収しないので、毎回回収させる測定では `HeapConfig::stress` を真にし、そのことを記録に書く。ADR 0239 の帰結の「大きなデータ構造を入れたセルがあると一回の回収の時間が延びる」を、大きなリストをセルに入れた場合で確かめる。

### 記録する項目

[ADR 0259](../../design/decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) の決定 3 の項目を、構成 × ワークロードごとに記録する。

| 項目 | 取り方 |
|---|---|
| 実行時間 | スキルの手順（複数回の中央値）。検査とコード生成の時間を含む場合と含まない場合を分ける |
| 確保の量、生きている量 | `HeapStats::allocated_bytes`・`live_bytes`（最後の回収のもの）・`peak_heap_bytes` |
| 最大常駐メモリ | OS の計測（`/usr/bin/time -l` など。スキルと `run.py` の方法に合わせる） |
| 回収か解放で止まる時間 | `HeapStats::pause_nanos` から p50・p95・p99・最大 |
| 参照の数の増減の回数と省けた回数 | `rc_increments`・`rc_decrements`・`rc_elided` |
| 再利用の率 | `reuses` ÷（`reuses` + `allocations`）。再利用しなければ確保していた対象のうち、再利用で確保を省いた割合として読む。R04 が `reuses` をどう数えたか（R04 の完了の報告）を記録に書く |
| 辿った根の数 | `roots_traced` |
| 回収の回数 | `collections` |

- リソースの解放の順序が両方式で一致すること（ADR 0259 の決定 3 の最後の文）は、第 1 段の VM がリソースを扱わない（解放の枠は第 2 段の R24）ので、第 1 段では確かめられない。記録にそう書き、R33 の測り直しに回す。
- 整数の値の範囲とヒープの対象の大きさ（[ADR 0258](../../design/decisions/0258-sixteen-byte-value-enum.md) の決定 6、[OPEN-065](../../design/open-issues.md#open-065)）: 測定のためだけのリビジョンで、VM の算術の結果の整数と定数の整数の大きさの分布（例: 31 ビット・47 ビット・63 ビットに収まる割合）と、確保した対象の大きさの分布を数え、記録する。数える処理は本番の枝に取り込まない。
- 振り分けのループの改善の効果（[ADR 0268](../../design/decisions/0268-staged-runtime-rebuild.md) の決定 4、[ADR 0269](../../design/decisions/0269-correct-adr-0240-performance-assessment.md) の決定 4）は、メモリの管理の比較と分けて記録する。最小実行版の測定の記録（2026-09-27）と同じ計算機で、C05 の前のコミット（最小実行版の CLI が動くもの）を古い構文のベンチマークで測り直し（`git worktree add` はサンドボックスから使えないので、`git archive <コミット> | tar -x -C <作業ツリーの下の一時ディレクトリ>` で展開してビルドする。時間の本測定はオーケストレータが行う）、fib・loop の変化を、新しい VM の MS-k1 と並べる。CPU プロファイルで、命令の振り分け・値の操作・回収・組み込みの関数の割合を見て、ADR 0269 の決定 1・2 の見立てに合うかを所見に書く。
- 呼び出しの回数の予算（`DEFAULT_CALL_BUDGET`）は第 1 段では切り替えに使わない（タスクがない）ので、測らない。

### 記録の形と案

- 記録は `tools/bench/results/TEMPLATE.md` の冒頭（環境・処理系・入力）だけを流用し、残りは記録する項目を見出しにした自由な書式にする。グラフ付きの `.html` は `stage1.py` が自分で書く（`report_html.py` と `run.py` は変えない）。比較対象の言語を一度だけ測るときは、`run.py` に `--bytecode-stats` を渡さない（C05 の後は止まる）。冒頭には、比べた構成（各構成のコミット、ビルドのコマンド、機能、`HeapConfig` の値、R04 の要求の条件と循環の回収の閾値）、計算機と Rust の版、入力を書く（ADR 0268 の決定 3 の最後の箇条）。
- 結果の後に、次の案を書く。案であって決定ではないことを明記する。
  - 暫定に採る方式の案と理由。ADR 0259 の帰結のとおり、ワークロードごとの勝ち負けと、停止の時間・最大常駐メモリの許せる範囲（HTTP のサーバを想定した観点）を分けて書く。
  - k の案（マーク・スイープを採る場合）と理由。
  - 参照カウントを採る場合の、遅らせた解放の条件と循環の回収の閾値の見直しの要否。
  - 8 バイトの値を試す価値の見立て（OPEN-065）。
- 記録の後に、オーケストレータに渡す短い要約（採る方式の案、k の案、判断に効いた数値）を完了の報告の「判断したこと」に書く。

## 受け入れテスト

測定の作業なので、振る舞いを確かめる Rust のテストは例のプログラムの引数の解釈など最小限にとどめる（`test-audit` の作成時の関門で判断する）。代わりに、次のことを確かめる。

- 出力の照合: すべてのワークロードで、すべての構成の出力が期待値と一致する（スキルの `--verify` と同じ考え方）。構成によって出力が違えば、測定に進まず原因を報告する。
- 記録の完全さ: 記録に、構成 × ワークロードのすべての組の項目がある（測れなかった組は理由を書く）。
- 再現: 記録のコマンドだけで、別の人が同じ構成をビルドして同じワークロードを走らせられる（記録のコマンドを一度写して走らせて確かめる）。

## 完了条件

- `scripts/check.sh` が通る
- 測定の記録（`.md` と `.html`）が `tools/bench/results/` にあり、上の「記録する項目」と「記録の形と案」の内容を含む
- 測定のためだけのリビジョンのコミットを書く欄が記録にあり（オーケストレータが埋める）、本番の枝に取り込むファイルに測定だけの変更が含まれていない
- 完了の報告に、設計者に確かめてもらう事項（採る方式の案、k の案、判断に効いた数値、測れなかった項目）を挙げている

## 確認の観点

[実装の確認の観点](../00-common/00-04-review-checklist.md)の「すべての作業で読む観点」に加えて、次の点を読む。

- 構成の違いが、方式の切り替えと k だけになっているか（ビルドの設定、入力、計算機の状態が揃っているか）。確保器・値の大きさ・VM の改善の効果を、方式の差として書いていないか。
- 循環の測定を、VM の測定と分けて記録しているか。ヒープの単位の結果から、言語の機能との統合まで確かめたと書いていないか。
- 案の理由が、記録した数値で支えられているか。

## 難易度の理由

測る処理そのものは道具で行うが、比べる構成を公平に揃えること、追加のワークロードを負荷の性質どおりに書くこと、測定のためだけのリビジョンを本番と混ぜずに残すことに注意が要る。結果は設計者の判断の材料になるので、案と事実を分けて書く必要がある。
