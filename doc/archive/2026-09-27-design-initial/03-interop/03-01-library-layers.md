# 3層ライブラリ構造

- 状態: 未着手
- 関連ADR: [0077](../decisions/0077-abolish-go-layer.md)
- 未決事項: [OPEN-035](../open-issues.md#open-035)
- 移行元: [設計メモ](../sources/fp-language-design.md) 10

## 目的と範囲

core / std / go.* の責務と昇格基準。言語自身で書く定義、Go で実装する組み込み関数、コンパイラが特別扱いする型・演算（Result/Option、IO など）の境界と、標準ライブラリを読み込む前にコンパイラが必要とする情報も扱う。

設計メモの go.* の層とラッパー自動生成器は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。本章は go.* の層を前提にしているので、v1 のライブラリの提供方法を決めるとき（[OPEN-035](../open-issues.md#open-035)）に、章の構成ごと見直す。

## 前提

## 仕様

## 未決事項

- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
