# プラグイン基盤

- 状態: 未着手
- 関連ADR: [0076](../decisions/0076-initial-implementation-in-rust.md), [0139](../decisions/0139-external-functions-via-wasm.md), [0161](../decisions/0161-single-threaded-task-scheduler.md), [0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)
- 未決事項: [OPEN-051](../open-issues.md#open-051)
- 移行元: [設計メモ](../sources/fp-language-design.md) 18, 19

## 目的と範囲

外部の関数（WASM のモジュールの関数）を実行する基盤を定める。対象は、WASM の実行環境、ホストの関数の呼び出しの規約（ABI）、値の受け渡しとメモリの管理の責任の分担、WASM の実行と処理系のランタイム（タスクの切り替え、IO 実行器、中断の要求）との関係である。

外部の関数は WASM のモジュールの関数とし、言語の表面は[外部の関数](04-01-external-functions.md)で定めた（[ADR 0139](../decisions/0139-external-functions-via-wasm.md)）。処理系を Rust で実装することにした（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）ので、WASM の実行環境（設計メモでは wazero）は選び直す。実行環境の選定、ホストの関数の呼び出しの規約、値の受け渡しとメモリの管理の責任の分担、ランタイム（[ランタイム](../02-impl/02-09-runtime.md)、[ADR 0161](../decisions/0161-single-threaded-task-scheduler.md)、[ADR 0162](../decisions/0162-event-loop-and-worker-threads-for-io.md)）との関係は、[OPEN-051](../open-issues.md#open-051) で決める。

## 前提

## 仕様

## 未決事項

- [OPEN-051](../open-issues.md#open-051): 外部の関数（WASM）の詳細
