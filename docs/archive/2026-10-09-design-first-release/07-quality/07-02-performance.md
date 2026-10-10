# 性能

- 状態: 確定
- 関連ADR: [0015](../decisions/0015-shared-program-per-execution-state.md), [0026](../decisions/0026-match-to-decision-trees.md), [0027](../decisions/0027-register-bytecode.md), [0028](../decisions/0028-tagged-struct-values.md), [0029](../decisions/0029-two-io-execution-modes.md), [0030](../decisions/0030-call-stack-size-limit.md), [0040](../decisions/0040-single-repository.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0079](../decisions/0079-rust-readings-of-go-based-decisions.md), [0089](../decisions/0089-ocaml-as-benchmark-comparator.md), [0088](../decisions/0088-keep-both-io-execution-modes.md), [0104](../decisions/0104-list-as-persistent-vector.md), [0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md), [0103](../decisions/0103-map-and-set-ordered-by-key.md), [0158](../decisions/0158-type-classes-by-dictionary-passing.md), [0160](../decisions/0160-one-shot-continuations-as-stack-segments.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md), [0163](../decisions/0163-interrupt-releases-resources.md), [0176](../decisions/0176-first-release-targets-and-static-linux-build.md), [0240](../decisions/0240-runtime-redesign-in-first-release-plan.md), [0259](../decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md), [0263](../decisions/0263-dispatch-loop-locals-and-verifier.md), [0268](../decisions/0268-staged-runtime-rebuild.md), [0269](../decisions/0269-correct-adr-0240-performance-assessment.md), [0313](../decisions/0313-vm-performance-recovery-before-stage-2.md), [0332](../decisions/0332-http-latency-measured-by-bench-client.md), [0355](../decisions/0355-mark-sweep-k1-for-first-release.md), [0356](../decisions/0356-call-budget-2500.md), [0357](../decisions/0357-no-ir-optimization-in-first-release.md)
- 未決事項: [OPEN-009](../open-issues.md#open-009)
- 移行元: [設計メモ](../sources/fp-language-design.md) 9, 3.6

## 目的と範囲

性能の見込み、ベンチマーク集合、判断基準。

現在の版は、最小実行版の完了後に行った測定（[ロードマップ](../00-overview/00-03-roadmap.md)）の方法と結果に加えて、初回リリース版の完了時に行う測定を定める。初回リリース版の完了時の測定は、最小実行版の測定の方法（ベンチマーク集合、比較対象、測る項目、記録、結果の使い方）を引き継ぎ、初回リリース版で加わる機能の分だけ広げる。

## 前提

処理系は Rust で実装し、測定の後に実装言語を見直す段階は設けない（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。最小実行版の完了後に性能を測り、その結果を最適化の要否を決める材料にする。実行性能の実測は [OPEN-009](../open-issues.md#open-009) で扱う。

## 仕様

### 性能の見込み

【方針】設計メモは、JIT のない本言語の VM の実行性能を、ボックス化した値の素朴なインタプリタ（CPython、Ruby MRI の JIT なし）の層の付近と見込んでいる。設計メモのこの見込みは Go で実装する前提のものであった。Rust で実装した最小実行版の測定では、関数の呼び出しと整数の演算ではこの層に入り、リストと文字列の操作ではこの層より遅かった（後述の「最小実行版の測定の結果」）。値の表現は、Rust の列挙型で表し、数値などの値はヒープを確保しない（[ADR 0028](../decisions/0028-tagged-struct-values.md)、[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。言語の値は参照カウントで管理するので、参照の数の増減と解放の費用が評価の繰り返しに加わる（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。性能の数値目標は置かない。

### ベンチマーク集合

【方針】最小実行版の完了後の測定では、次のベンチマークを使う。各ベンチマークは、本言語のスクリプトと、比較対象の言語で同じ処理を書いたものからなる。入力の大きさは、本言語での実行時間が 1 秒から 10 秒程度になるように決める。

| ベンチマーク | 処理 | 主に負荷をかける部分 |
|---|---|---|
| fib | 末尾でない再帰で Fibonacci 数を求める | 関数の呼び出しと戻り、整数の演算 |
| loop | 末尾再帰で整数を数え上げる | 末尾呼び出し、命令の振り分け |
| list | 大きなリストに map・filter・畳み込みを続けて適用する | prelude の関数を引数にとる関数、関数の値の呼び出し、リストの確保 |
| tree | 二分木を作って辿る（代数的データ型） | 構成子の値の確保と解放、パターンマッチ |
| eval | 式を代数的データ型で表した小さなインタプリタで、式を評価する | 分岐の多いパターンマッチ（判定の木。[ADR 0026](../decisions/0026-match-to-decision-trees.md)） |
| string | 文字列を連結し、分割し、数える | 文字列の操作 |
| println | 多数の行を標準出力に書く | IO の命令（[ADR 0029](../decisions/0029-two-io-execution-modes.md)） |
| lines | 大きなファイルを読んで行数を数える | ファイルの読み込み、文字列の分割 |

設計メモの go.* の層は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）ので、Go の関数を呼ぶ費用を測るベンチマークは設けない。

### 比較対象

【方針】比較対象は、CPython、Ruby（MRI）、Lua（C で書かれた公式の処理系）、OCaml（バイトコードとネイティブの二つの形）、同じ処理を Rust で書いてビルドしたバイナリとする（[OPEN-009](../open-issues.md#open-009)、[ADR 0089](../decisions/0089-ocaml-as-benchmark-comparator.md)）。OCaml のバイトコードは、正格評価で静的に型を付ける関数型の言語をバイトコードの VM で実行する処理系の先行事例として比べる。Lua は、レジスタ型のバイトコード VM（[ADR 0027](../decisions/0027-register-bytecode.md)）の先行事例として比べる。設計メモが挙げていた gopher-lua は、Go で書いたインタプリタの不利を見るための比較対象だったので、外した。CPython と Ruby は、JIT を持つ版では JIT を無効にしたものと有効にしたものの両方を測り、区別して記録する。各処理系の版を記録する。

### 測る項目

【方針】次の項目を測る。

| 項目 | 測り方 |
|---|---|
| 実行時間 | 各ベンチマークを 10 回実行した実時間の中央値。本言語では、検査とコード生成の時間を含む場合と含まない場合を分けて記録する |
| 起動から終了までの時間 | 何もしないスクリプト（`main` が `()` を返すだけ）を 10 回実行した実時間の中央値 |
| 検査にかかる時間 | 大きなスクリプト（関数を多数並べて生成した、1 万行程度のもの）の `check` の実時間 |
| メモリ | 各ベンチマークの最大の常駐メモリ |
| 確保と解放 | 本言語の各ベンチマークでの、確保の回数・確保した量・解放の回数。処理系の確保の処理（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）で数える |
| 実行時間の内訳 | 本言語の各ベンチマークの CPU プロファイル（samply で取る。手順はプロジェクトのスキル `benchmark` に定める）。命令の振り分け、値の操作、参照の数の増減と解放、組み込みの関数に分けて集計する |

【方針】処理系の実装の選択の影響として、次のものも記録する。

- IO の二つの方式（[ADR 0029](../decisions/0029-two-io-execution-modes.md)）: println と lines を、両方の方式で測る。
- 命令の長さ（[ADR 0027](../decisions/0027-register-bytecode.md)、[OPEN-009](../open-issues.md#open-009)）: 各ベンチマークのバイトコードの大きさを記録し、実行時間の内訳から命令の読み込みにかかる費用を見る。
- 値の表現（[ADR 0028](../decisions/0028-tagged-struct-values.md)）: fib と loop で、数値の演算がヒープを確保していないことを確かめる。
- 呼び出しの情報の上限（[ADR 0030](../decisions/0030-call-stack-size-limit.md)）: fib を末尾でない再帰で深くしたときに、上限に達する段数を記録し、既定の 1 GiB を見直す材料にする。
- リストの表現（初回リリース版。[ADR 0104](../decisions/0104-list-as-persistent-vector.md)、[ADR 0211](../decisions/0211-list-invariants-by-model-comparison-and-debug-assertions.md)）: 長さを変えた大きなリストで、添字で要素を引く操作（`List.get`）の時間を測る。長さに対する時間の増え方から、木の高さが要素の数に対して O(log n) に収まっているかを見る（[標準ライブラリ](../03-interop/03-06-stdlib.md)の「List の内部の表現」）。

### 測定の環境と記録

【方針】測定の結果は、測定した計算機の CPU・メモリ・OS、Rust のツールチェーンの版、処理系の版（コミット）、比較対象の各処理系の版とともに、設計書と別の測定記録として、本リポジトリに残す（[ADR 0040](../decisions/0040-single-repository.md)）。リポジトリの中の置き場所は `tools/bench/results/` とし、測定記録（Markdown）と、そこから作るグラフ付きの HTML を置く。測定の手順はスキル `benchmark`（`.claude/skills/benchmark/SKILL.md`）にまとめる。

### 測定の結果の使い方

【決定】測定の結果は、最適化の要否を決める材料にし、実装言語を見直す判断には使わない（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。

【方針】性能の数値の基準は置かない。測定の後に、次の三つの観点で結果を並べた記録を作り、最適化に取り組むかと、その対象を決める。

1. 比較対象に対する、ベンチマークごとの相対の位置
2. 遅い部分の原因の内訳と、それを処理系の設計（値の表現、命令の長さ、IO の方式、値の管理など）で直せるか
3. 言語処理系を学ぶという実質的な目的への影響（[目的と設計原則](../00-overview/00-01-goals.md)）

【決定】例外として、初回リリース版のランタイムの作り直しの間は、最小実行版の VM を下限とする関門を置く（[ADR 0313](../decisions/0313-vm-performance-recovery-before-stage-2.md) の決定 5）。U2 第 2 段を始める前に、fib と loop の実行の段の時間の中央値が、同じ計算機・同じ機会に測り直した最小実行版の VM 以下でなければならない。関門を通った後は、その時点の fib と loop の時間を基準とし、VM・ランタイムのヒープ・コード生成・生存の情報を変える変更で、どちらかが基準より 5% を超えて遅くなったら、理由を記録し、設計者の合意を得る。基準と比べる本測定は、U2 第 2 段の途中（作業用のスレッドとイベントループの本物を入れる R40 の後）と、VM とランタイムを変える作業をすべて終えた後に行い、作業ごとには短い測定と振り分けのループの機械語の数で確かめる（ADR 0313 の帰結）。普通の呼び出しと戻りで Rust の動的確保が起きないことを、テストで確かめる。第 2 段の開始の関門は、loop が最小実行版の VM の 1.07 倍の値のまま、設計者の合意を得て通した（2026-10-06）。その後、R20 で fib と loop の両方が最小実行版の VM を下回った（ADR 0313 の帰結）。

### 初回リリース版の完了時の測定

【方針】初回リリース版の完了時には、前述のベンチマーク集合に次のものを加えて測る。入力の大きさの決め方は、前述の「ベンチマーク集合」と同じである。

| ベンチマーク | 処理 | 主に負荷をかける部分 |
|---|---|---|
| trait | 型クラスの制約を持つ多相の関数から、メソッドを繰り返し呼ぶ | 辞書を引数で渡すメソッドの呼び出し（[ADR 0158](../decisions/0158-type-classes-by-dictionary-passing.md)） |
| handler | 利用者が定義したエフェクトの操作を繰り返し呼ぶ。末尾で再開する節と、継続を保存してから再開する節の二つの形で測る | ハンドラの探索、継続の区画の保存と再開（[ADR 0160](../decisions/0160-one-shot-continuations-as-stack-segments.md)） |
| tasks | 多数のタスクを起動し、それぞれに計算させて、すべての終わりを待つ | タスクの切り替え、呼び出しの回数の予算（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)） |
| map | 大きな `Map` と `Set` に、挿入・検索・削除を続けて行う | 平衡二分木の更新と探索（[ADR 0103](../decisions/0103-map-and-set-ordered-by-key.md)） |
| cycle | 可変のセルで循環する値を作っては捨てる | 循環する値の回収（[ADR 0355](../decisions/0355-mark-sweep-k1-for-first-release.md)） |
| http | スクリプトで書いた HTTP サーバに、ループバックで多数の要求を送る。計算を続けるタスクを同時に動かす場合と、動かさない場合を測る | イベントループ、待つタスクの切り替え、要求の解析と応答の生成（[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)） |

http は、ロードマップが並行処理の水準とした「スクリプトで簡易な HTTP サーバ（HTML を返す、REST API を提供する）を動かせる」ことと、「一つのタスクが接続を待ち受けたり計算を続けたりしている間も、ほかのタスクを止めない」ことを、数で確かめるためのものである（[ロードマップ](../00-overview/00-03-roadmap.md)の「初回リリース版」）。要求を送る側の道具は、測定の手順を定めるときに選ぶ。【方針】初回リリース版の完了時の測定では、Benitoite のスクリプトはサーバだけを動かし、ベンチマークの道具（`tools/bench/run.py`）がクライアントとして要求を送り、要求ごとの応答までの時間を処理系の外で測る。言語の時計はミリ秒までしか測れず、ループバックの応答までの時間を測るには粗いからである（[ADR 0332](../decisions/0332-http-latency-measured-by-bench-client.md)）。

【方針】比較対象は、前述の「比較対象」と同じとする。比較対象の言語で同じ処理を素直に書けないベンチマーク（handler、tasks、cycle、http）は、Benitoite だけで測り、処理系を変えた前後の比較に使う。http は、結果を読むのに要るときだけ、ほかの言語で書いた簡単な HTTP サーバと比べる。

【方針】前述の「測る項目」に、次のものを加える。

| 項目 | 測り方 |
|---|---|
| 要求の処理の量と待ち時間 | http で、一秒あたりに処理した要求の数と、要求ごとの応答までの時間の中央値と最大。計算を続けるタスクがある場合とない場合を分けて記録する |
| 並行処理でのメモリ | tasks で、同時に存在するタスクの数を変えたときの最大の常駐メモリ。一つのタスクあたりのメモリを見積もる（[ADR 0015](../decisions/0015-shared-program-per-execution-state.md) の帰結） |
| 回収の費用 | cycle と、値を多く作るベンチマーク（list、tree、eval）で、回収か解放にかかる時間の合計と、実行が止まる時間の p50・p95・p99・最大、最大の常駐メモリ。値の表現とランタイムの作り直しで採った方式（止めて行う非移動のマーク・スイープ。[ADR 0355](../decisions/0355-mark-sweep-k1-for-first-release.md)）について測る。作り直しの第 1 段で二つの方式を比べるときの項目は [ADR 0259](../decisions/0259-compare-mark-sweep-and-rc-in-stage-1.md) で定める |
| 起動と検査にかかる時間の内訳 | 前述の「測る項目」の、起動から終了までの時間と検査にかかる時間を、標準ライブラリのソースの読み込みと型検査にかかる時間と、それ以外に分けて記録する。検査のたびに、読む標準ライブラリのモジュールも名前解決から型検査までの段を通すためである（[名前解決とモジュール読込](../02-impl/02-04-resolver.md)の「標準ライブラリのソースの持ち方」） |

【方針】処理系の実装の選択の影響として、次のものも記録する。

- 呼び出しの回数の予算（[仮想機械](../02-impl/02-08-vm.md)の「タスクの切り替え」）: 予算の初めの値は実装プランで定め、性能の測定で調整する。tasks と http を、初めの値を変えて測り、実行時間と応答までの時間の釣り合いから値を選ぶ。初回リリース版の完了時の測定で、初めの値を 2,500 回にした（[ADR 0356](../decisions/0356-call-budget-2500.md)）。
- 切り替えの位置の処理（[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)、[ADR 0163](../decisions/0163-interrupt-releases-resources.md)、[ADR 0263](../decisions/0263-dispatch-loop-locals-and-verifier.md)）: 関数の呼び出しのたびに中断の印と予算を調べ、取り消しと回収の要求は予算を 0 にして知らせる。fib と loop の CPU プロファイルで、この処理が実行時間に占める割合を見る。
- 中間表現の最適化（[中間表現と脱糖](../02-impl/02-06-ir-and-lowering.md)の「最適化」）: 初回リリース版では、中間表現の最適化を行わない（[ADR 0357](../decisions/0357-no-ir-optimization-in-first-release.md)）。初回リリース版の後に、候補の変換（辞書が決まっているメソッドの呼び出しを直接の呼び出しにすること、`let` の入れ子を平らにすることなど）ごとに、変換の有無で各ベンチマークを測り、採るかを決める。辞書の変換は trait で効果を見る。
- 配布する実行ファイルのメモリの確保（[ADR 0176](../decisions/0176-first-release-targets-and-static-linux-build.md)、[OPEN-009](../open-issues.md#open-009)）: Linux 向けの musl で静的にリンクしたビルドと、glibc のビルドを、同じ Linux の計算機で比べる。

【方針】測定の結果は、前述の「測定の結果の使い方」の三つの観点で並べ、性能の数値の基準は置かない。最小実行版の測定の結果と同じ計算機で測れるときは、前述のベンチマークについて、最小実行版からの変化も並べる。

### 最小実行版の測定の結果

最小実行版の完了後の測定を 2026-09-27 に行った（Apple M4、メモリ 32 GB、macOS 27.0、Rust 1.98.1）。記録は `tools/bench/results/2026-09-27-1ff816b0b156.md` と、同じ名前のグラフ付きの HTML にある。測定の前に、最初の測定のプロファイルで見つけた二つの費用（解放のたびの確保、VM の呼び出しのたびの確保とレジスタの並びの伸び縮み）を、設計書の決定を変えずに直した。比較対象の版は、CPython 3.9.6（JIT なし）、Ruby 4.0.7（YJIT の有無）、Lua 5.5.1、OCaml 5.5.1（バイトコードとネイティブ。[ADR 0089](../decisions/0089-ocaml-as-benchmark-comparator.md)）、Rust 1.98.1 である。

実行時間（10 回の中央値。倍率は「Benitoite の時間 ÷ 比較対象の時間」で、1 より大きいほど Benitoite が遅い）は次のとおりである。

| ベンチマーク | Benitoite | CPython に対して | OCaml バイトコードに対して | Lua に対して |
|---|---:|---:|---:|---:|
| fib | 2.12 秒 | 1.7 倍 | 13 倍 | 8.4 倍 |
| loop | 1.03 秒 | 0.95 倍 | 14 倍 | 19 倍 |
| list | 1.43 秒 | 9.6 倍 | 13 倍 | 18 倍 |
| tree | 1.89 秒 | 1.6 倍 | 8.6 倍 | 2.4 倍 |
| eval | 1.75 秒 | 0.87 倍 | 20 倍 | 5.9 倍 |
| string | 0.40 秒 | 9.2 倍 | 0.40 倍 | 2.0 倍 |
| println | 1.55 秒 | 0.98 倍 | （条件が揃っていない） | （条件が揃っていない） |
| lines | 1.08 秒 | 2.7 倍 | 0.45 倍 | 0.80 倍 |

測定の結果を、「測定の結果の使い方」の三つの観点で並べると次のとおりである。原因は、プロファイルと実装から見立てたものであり、直して測り直して確かめたものではない。

1. **相対の位置**: 関数の呼び出しと整数の演算（fib、loop、eval）では、CPython（JIT なし）の 0.9〜1.7 倍の時間で、設計メモの見込みの層に入った。リストと文字列の操作（list、string、lines）では CPython の 2.7〜9.6 倍の時間で、見込みより遅い。JIT を持たない OCaml のバイトコードと Lua は、関数の呼び出しと代数的データ型の処理で Benitoite より 2.4〜20 倍速い。起動から終了までは 3.1 ミリ秒、約 1 万行のスクリプトの検査は 17 ミリ秒である。最大常駐メモリは、値を多く作るベンチマーク（list、tree、string、lines）で比較対象より大きい（tree で 747 MB、OCaml は 104 MB）。
2. **原因と、設計で直せるか**: 最適化の後は、命令を取り出して振り分ける費用（原型と枠の引き直しを含む）が実行時間の 34〜61% を占め、値の複製と解放（参照の数の増減）が 5〜20%、リストのセルと文字列の確保と解放が値を多く作るベンチマークで 10〜45% を占める。前の二つは VM とコード生成の局所的な直し（振り分けのループの組み立て、コード生成が出す余分な MOVE を減らすこと）で減らせる見込みがあり、命令の形（[ADR 0027](../decisions/0027-register-bytecode.md)）と値の表現は変えずに済む。関数の呼び出しが中心のプログラム（fib、loop）で OCaml のバイトコードとの差を生んでいるのは、ヒープをほとんど確保しないことから、値の表現ではなく、振り分けのループの組み立て（命令ごとに原型と枠を引き直し、レジスタの読み書きごとに範囲を確かめる）と呼び出しの手順だと見られる。値の表現とメモリの管理が主な差になるのは、値を多く作り捨てるプログラム（list、tree）と、値を多く写すプログラム（eval）である（[ADR 0269](../decisions/0269-correct-adr-0240-performance-assessment.md)）。どちらを直すにも、値の表現とランタイムの作り直しが要る。IO の二つの方式の差は小さく（println で約 11%、lines で約 2%）、二つとも残すと決めた（[ADR 0088](../decisions/0088-keep-both-io-execution-modes.md)）。
3. **学ぶ目的への影響**: JIT を持たないインタプリタでも 1 桁速くできる余地があり、その原因が値の表現と命令の振り分けにあることは、VM の設計を学ぶ題材になる。JIT は初回リリース版の非目標のまま扱い（[ロードマップ](../00-overview/00-03-roadmap.md)）、インタプリタの範囲での改良を先に行う。

【方針】初回リリース版に進む前の最適化は、命令の形と値の表現を変えずに行える局所的な直し（振り分けのループ、コード生成の余分な MOVE）に限る。値の表現の見直しは、初回リリース版の実装プランを作るときに、値の表現とランタイムの作り直しとして行う（[ADR 0240](../decisions/0240-runtime-redesign-in-first-release-plan.md)）。

【決定】作り直しは段に分けて行い、第 1 段の終わりに fib・loop・list・tree・eval・string と、循環や大きな生きているグラフなどの負荷を測る。振り分けのループの改善の効果は、メモリの管理の方式の比較と混ざらないよう別に測る（[ADR 0268](../decisions/0268-staged-runtime-rebuild.md)）。

比較の読み方には次の注意がある。println では、Lua・Rust・OCaml の版が一行ごとに出力を送り出していると見られ、比較の条件が揃っていない。string と lines では、分割と検索を Benitoite では Rust で書いた組み込みの関数が行い、OCaml のバイトコードでは OCaml で書いた標準ライブラリを VM が 1 文字ずつ実行するので、VM の速さの比較としては読まない。string の入力は List の要素数の上限（16,777,216）で抑えられ、実行時間が 1 秒に届かない。

## 未決事項

- [OPEN-009](../open-issues.md#open-009): 実行性能
