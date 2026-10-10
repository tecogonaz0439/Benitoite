# U2 値の表現とランタイムの作り直しの検討資料

- 状態: 設計を採択済み（2026-09-30。ADR 0258〜0271 と、[仮想機械](../../../2026-10-09-design-first-release/02-impl/02-08-vm.md)・[ランタイム](../../../2026-10-09-design-first-release/02-impl/02-09-runtime.md)の章。以後は設計書の側が正であり、本資料は経緯の記録として残す）
- 関連ADR: [0240](../../../2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md), [0239](../../../2026-10-09-design-first-release/decisions/0239-cycle-collection-for-reference-cells.md), [0253](../../../2026-10-09-design-first-release/decisions/0253-first-release-plan-location-and-units.md)
- 未決事項: [OPEN-036](../../../2026-10-09-design-first-release/open-issues.md#open-036), [OPEN-039](../../../2026-10-09-design-first-release/open-issues.md#open-039), [OPEN-062](../../../2026-10-09-design-first-release/open-issues.md#open-062)

## 目的

初回リリース版の実装プランの単位 U2（[ADR 0253](../../../2026-10-09-design-first-release/decisions/0253-first-release-plan-location-and-units.md)）で、値の表現とランタイムを作り直す（[ADR 0240](../../../2026-10-09-design-first-release/decisions/0240-runtime-redesign-in-first-release-plan.md)）。この資料は、作り直しの方式を決める前の検討の材料である。設計書の章でも実装プランでもなく、ここに書いた推奨は、設計者の判断と外部の検証者（Codex と GPT-6-Astra）への相談を経て、ADR と設計書の章に移すまでは決定ではない。

作り直しは、設計者が言語処理系を学ぶ題材の中心でもある（[目的と設計原則](../../../2026-10-09-design-first-release/00-overview/00-01-goals.md)）。そのため、各資料は結論だけでなく、選択肢の間の損得と、その理由を書く。

## ファイル

| ファイル | 内容 |
|---|---|
| [01-current-state.md](01-current-state.md) | 最小実行版のランタイムの実装の現状。値の型、ヒープと参照カウント、VM の枠、組み込みの関数と IO の呼び方、測定の結果。実装済みのものと、設計書にだけあるものを分ける |
| [02-requirements.md](02-requirements.md) | 作り直したランタイムが満たすべき要求。意味論、安全性、性能、並行の形、メモリ、埋め込み、将来の版、OPEN-062 の反例。それぞれに根拠の章・ADR・OPEN を付ける |
| [03-options.md](03-options.md) | 設計の問いごとの選択肢、先行事例、処理系のほかの部分への影響、LLM による実装の難しさ、学ぶ価値、暫定の推奨、専門家に聞きたいこと |
| [04-consult-plan.md](04-consult-plan.md) | Codex と GPT-6-Astra への相談の計画（問いの絞り込み、回数、添える資料、期待する回答）と、最初の相談の依頼文の草稿 |

相談の記録（送った問いと回答）は、相談のたびに `consult/` の下に残す（[04-consult-plan.md](04-consult-plan.md) の「記録の残し方」）。

## 凡例

- 【要検証】: 一次資料（処理系のソース、論文、公式の文書）で確かめていない事実。設計書に移す前に確かめる。
- 暫定の推奨: 本資料の筆者の現時点の推奨であり、決定ではない。
