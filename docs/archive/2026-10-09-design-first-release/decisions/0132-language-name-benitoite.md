# 0132. 言語の名前を Benitoite に確定する

- 状態: 採択
- 日付: 2026-09-28
- 関連章: [README](../README.md), [目的と設計原則](../00-overview/00-01-goals.md), [CLI](../06-tooling/06-01-cli.md), [標準ライブラリ](../03-interop/03-06-stdlib.md)
- 関連する未決事項: [OPEN-011](../open-issues.md#open-011)

## 背景

言語の名前は仮称の `Benitoite` として扱ってきた（[OPEN-011](../open-issues.md#open-011)）。標準ライブラリの名前空間の根を `Benitoite` とした（[ADR 0128](0128-prelude-and-benitoite-namespace.md)）ので、言語の名前を変えると、すべてのスクリプトの import と完全な名前が変わる。

## 決定

言語の名前を `Benitoite`（ベニトアイト）に確定する。標準ライブラリの名前空間の根も `Benitoite` とする。

## 検討した代替案

- **仮称のまま進める**: 名前を変える余地が残る。しかし、名前空間の根に使う以上、初回リリース版より後に変えると、利用者のスクリプトをすべて書き換えることになる。

## 帰結

- [OPEN-011](../open-issues.md#open-011) のうち、言語の名前を決着させる。CLI のコマンドの名前（`benitoite`）とスクリプトのファイルの拡張子（`.bnt`）は、仮の決定のまま OPEN-011 に残す。
- 設計書の「仮称」の記述を改める。
