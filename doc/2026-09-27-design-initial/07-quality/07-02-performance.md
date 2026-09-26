# 性能

- 状態: 草稿
- 関連ADR: [0015](../decisions/0015-shared-program-per-execution-state.md), [0026](../decisions/0026-match-to-decision-trees.md), [0027](../decisions/0027-register-bytecode.md), [0028](../decisions/0028-tagged-struct-values.md), [0029](../decisions/0029-two-io-execution-modes.md), [0030](../decisions/0030-call-stack-size-limit.md), [0040](../decisions/0040-single-repository.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md), [0078](../decisions/0078-reference-counting-in-minimal.md), [0079](../decisions/0079-rust-readings-of-go-based-decisions.md)
- 未決事項: [OPEN-009](../open-issues.md#open-009)
- 移行元: [設計メモ](../sources/fp-language-design.md) 9, 3.6

## 目的と範囲

性能の見込み、ベンチマーク集合、判断基準。

現在の版は、最小実行版の完了後に行う測定（[ロードマップ](../00-overview/00-03-roadmap.md)）の範囲だけを定める。v1 の完了時の測定は、v1 の範囲を設計するときに加える。

## 前提

処理系は Rust で実装し、測定の後に実装言語を見直す段階は設けない（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。最小実行版の完了後に性能を測り、その結果を最適化の要否を決める材料にする。実行性能の実測は [OPEN-009](../open-issues.md#open-009) で扱う。

## 仕様

### 性能の見込み

【方針】設計メモは、JIT のない本言語の VM の実行性能を、ボックス化した値の素朴なインタプリタ（CPython、Ruby MRI の JIT なし）の層の付近と見込んでいる。設計メモのこの見込みは Go で実装する前提のものであり、Rust で実装する処理系の見込みは確かめていない【要検証】（[OPEN-009](../open-issues.md#open-009)）。値の表現は、Rust の列挙型で表し、数値などの値はヒープを確保しない（[ADR 0028](../decisions/0028-tagged-struct-values.md)、[ADR 0079](../decisions/0079-rust-readings-of-go-based-decisions.md)）。言語の値は参照カウントで管理するので、参照の数の増減と解放の費用が評価の繰り返しに加わる（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）。性能の数値目標は置かない。

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

【方針】比較対象は、CPython、Ruby（MRI）、Lua（C で書かれた公式の処理系）、同じ処理を Rust で書いてビルドしたバイナリとする（[OPEN-009](../open-issues.md#open-009)）。Lua は、レジスタ型のバイトコード VM（[ADR 0027](../decisions/0027-register-bytecode.md)）の先行事例として比べる。設計メモが挙げていた gopher-lua は、Go で書いたインタプリタの不利を見るための比較対象だったので、外した。CPython と Ruby は、JIT を持つ版では JIT を無効にしたものと有効にしたものの両方を測り、区別して記録する。各処理系の版を記録する。

### 測る項目

【方針】次の項目を測る。

| 項目 | 測り方 |
|---|---|
| 実行時間 | 各ベンチマークを 10 回実行した実時間の中央値。本言語では、検査とコード生成の時間を含む場合と含まない場合を分けて記録する |
| 起動から終了までの時間 | 何もしないスクリプト（`main` が `()` を返すだけ）を 10 回実行した実時間の中央値 |
| 検査にかかる時間 | 大きなスクリプト（関数を多数並べて生成した、1 万行程度のもの）の `check` の実時間 |
| メモリ | 各ベンチマークの最大の常駐メモリ |
| 確保と解放 | 本言語の各ベンチマークでの、確保の回数・確保した量・解放の回数。処理系の確保の処理（[ADR 0078](../decisions/0078-reference-counting-in-minimal.md)）で数える |
| 実行時間の内訳 | 本言語の各ベンチマークの CPU プロファイル（取る道具は実装プランで選ぶ）。命令の振り分け、値の操作、参照の数の増減と解放、組み込みの関数に分けて集計する |

【方針】処理系の実装の選択の影響として、次のものも記録する。

- IO の二つの方式（[ADR 0029](../decisions/0029-two-io-execution-modes.md)）: println と lines を、両方の方式で測る。
- 命令の長さ（[ADR 0027](../decisions/0027-register-bytecode.md)、[OPEN-009](../open-issues.md#open-009)）: 各ベンチマークのバイトコードの大きさを記録し、実行時間の内訳から命令の読み込みにかかる費用を見る。
- 値の表現（[ADR 0028](../decisions/0028-tagged-struct-values.md)）: fib と loop で、数値の演算がヒープを確保していないことを確かめる。
- 呼び出しの情報の上限（[ADR 0030](../decisions/0030-call-stack-size-limit.md)）: fib を末尾でない再帰で深くしたときに、上限に達する段数を記録し、既定の 1 GiB を見直す材料にする。

### 測定の環境と記録

【方針】測定の結果は、測定した計算機の CPU・メモリ・OS、Rust のツールチェーンの版、処理系の版（コミット）、比較対象の各処理系の版とともに、設計書と別の測定記録として、本リポジトリに残す（[ADR 0040](../decisions/0040-single-repository.md)）。リポジトリの中の置き場所は、最初の実装プランを作るときに決める。

### 測定の結果の使い方

【決定】測定の結果は、最適化の要否を決める材料にし、実装言語を見直す判断には使わない（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）。

【方針】性能の数値の基準は置かない。測定の後に、次の三つの観点で結果を並べた記録を作り、最適化に取り組むかと、その対象を決める。

1. 比較対象に対する、ベンチマークごとの相対の位置
2. 遅い部分の原因の内訳と、それを処理系の設計（値の表現、命令の長さ、IO の方式、値の管理など）で直せるか
3. 言語処理系を学ぶという実質的な目的への影響（[目的と設計原則](../00-overview/00-01-goals.md)）

## 未決事項

- [OPEN-009](../open-issues.md#open-009): 実行性能
