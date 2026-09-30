# Go型との対応規約

- 状態: 未着手
- 関連ADR: [0077](../decisions/0077-abolish-go-layer.md)
- 未決事項: [OPEN-035](../open-issues.md#open-035)
- 移行元: [設計メモ](../sources/fp-language-design.md) 11.3

## 目的と範囲

基本型との変換（符号なし整数・幅の狭い整数・`float32`・`string`・`rune`・`[]byte`）と、error・nil・ポインタ・コールバック・ジェネリクスの変換規則。変換を実行する仕組み（登録形式、呼び出し規約、ハンドルの管理）は[ランタイム](../02-impl/02-09-runtime.md)の定めを参照する。

設計メモの go.* の層とラッパー自動生成器は廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）。本章は go.* の層を前提にしているので、v1 のライブラリの提供方法を決めるとき（[OPEN-035](../open-issues.md#open-035)）に、章の構成ごと見直す。

## 前提

## 仕様

## 未決事項

- [OPEN-035](../open-issues.md#open-035): v1 のライブラリの提供方法
