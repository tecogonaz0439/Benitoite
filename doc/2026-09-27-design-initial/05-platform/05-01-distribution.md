# 配布形態

- 状態: 未着手
- 関連ADR: [0003](../decisions/0003-license.md), [0076](../decisions/0076-initial-implementation-in-rust.md), [0077](../decisions/0077-abolish-go-layer.md)
- 未決事項: [OPEN-021](../open-issues.md#open-021)
- 移行元: [設計メモ](../sources/fp-language-design.md) 20

## 目的と範囲

対応環境（OS・CPU・Go のバージョン）の対応表、必要なツールと生成物、単一バイナリ、Agent Skills 実行環境への導入経路、生成ラッパーの更新と検証、リリース時の試験範囲、配布物のライセンスと第三者の OSS の著作権表示。この言語のソース・標準ライブラリ・保存したバイトコードの互換性方針も扱う（Go のバージョンへの追従は[Goバージョン追従](../03-interop/03-05-go-version-tracking.md)）。モバイルや WASM コアを初期の対象とするかは、この章の対応表で示す。

範囲の記述のうち Go を前提にした部分（Go のバージョン、生成ラッパー、Go のバージョンへの追従）は、処理系を Rust で実装し（[ADR 0076](../decisions/0076-initial-implementation-in-rust.md)）、go.* の層を廃止した（[ADR 0077](../decisions/0077-abolish-go-layer.md)）ことに合わせて、本章を書くときに見直す。

## 前提

## 仕様

## 未決事項

- [OPEN-021](../open-issues.md#open-021): 処理系・標準ライブラリ・文書・設計書のライセンス
