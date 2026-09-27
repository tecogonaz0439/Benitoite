# プラグイン基盤

- 状態: 未着手
- 関連ADR: [0076](../decisions/0076-initial-implementation-in-rust.md)
- 未決事項: [OPEN-035](../open-issues.md#open-035)
- 移行元: [設計メモ](../sources/fp-language-design.md) 18, 19

## 目的と範囲

プラグイン境界、wazero、ABI、メモリ管理の責任分界。

処理系を Rust で実装することにした（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）ので、プラグインの実行に使う WASM の実行環境（設計メモでは wazero）は、本章を書くときに選び直す。プラグインで外部の機能を加える方法は、v1 のライブラリの提供方法（[OPEN-035](../open-issues.md#open-035)）とあわせて決める。

## 前提

## 仕様

## 未決事項

- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
