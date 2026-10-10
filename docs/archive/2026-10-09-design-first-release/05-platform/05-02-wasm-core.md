# WASMコア化（条件付き代替案）

- 状態: 未着手
- 関連ADR: なし
- 未決事項: [OPEN-007](../open-issues.md#open-007)
- 移行元: [設計メモ](../sources/fp-language-design.md) 21

## 目的と範囲

構成案、wasip1 の制約、採否の判断条件と判断のための試作。基準案ではないため、全構成の詳細設計は採用が決まるまで行わない。WASM プラグイン（[プラグイン基盤](../04-extensions/04-02-plugins-wasm.md)）とは別の判断として扱う。

採否は、初回リリース版で外部コマンドの起動（`Process.run`）とシェルによる実行（`Process.shell`）を実装した後に判断する。採用すると判断しても、WASM 化は初回リリース版に含めない（[ロードマップ](../00-overview/00-03-roadmap.md)）。

## 前提

## 仕様

## 未決事項

- [OPEN-007](../open-issues.md#open-007): WASMコア化の採否
