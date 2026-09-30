# 外部Goライブラリ

- 状態: 未着手
- 関連ADR: [0077](../decisions/0077-abolish-go-layer.md)
- 未決事項: [OPEN-035](../open-issues.md#open-035)
- 移行元: [設計メモ](../sources/fp-language-design.md) 17, 0.2

## 目的と範囲

オペークハンドル、橋渡し型、公式サポートの範囲。

設計メモの go.* の層とラッパー自動生成器は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。本章は go.* の層を前提にしているので、v1 のライブラリの提供方法を決めるとき（[OPEN-035](../open-issues.md#open-035)）に、章の構成ごと見直す。

## 前提

## 仕様

### 非目標

- 【方針】外部 Go ライブラリのネイティブラッパーを公式には提供しない。

## 未決事項

- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
