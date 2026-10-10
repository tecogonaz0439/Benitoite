# アーカイブ

過去の文書を保管する場所である。過去の文書や、処理系の作成・改造の経緯を調べるときだけ読む。ここにある文書は更新せず、現在の作業の根拠にしない。現在の設計書は [`docs/design/`](../design/README.md) にある。

| ディレクトリ | 内容 | 保管した日 |
|---|---|---|
| [`2026-09-27-design-initial/`](2026-09-27-design-initial/README.md) | 最小実行版の設計書の写し。最小実行版の実装が拠った時点の版で、正式版の設計書は `docs/design/` でこの版から書き進める | 2026-09-27 |
| [`2026-09-27-implement-initial/`](2026-09-27-implement-initial/README.md) | 最小実行版の実装プランと、実装の結果の記録（作業の状態、実装の途中で改めたこと、完了の後の作業） | 2026-09-27 |
| [`2026-10-09-design-first-release/`](2026-10-09-design-first-release/README.md) | 初回リリース版の設計書の写し。初回リリース版の実装を終え、`0.0.1` として公開した時点の版で、以後の設計書は `docs/design/` でこの版から書き進める | 2026-10-09 |
| [`2026-10-09-implement-first-release/`](2026-10-09-implement-first-release/README.md) | 初回リリース版の実装プランと、実装の結果の記録（作業の状態、実装の途中で改めたこと、完了の後の作業）、設計の検討資料（`studies/`）、形式検証の段階 A・B のレビューの記録（`formal-reviews/`） | 2026-10-09 |
| [`2026-10-09-TODO-171-check-script-review/`](2026-10-09-TODO-171-check-script-review/README.md) | TODO-171 の一部の改造（`scripts/check.sh` の見直し）。改造の内容、測定、判断、実装プラン | 2026-10-10 |
| [`2026-10-09-TODO-162-desugar-formalization/`](2026-10-09-TODO-162-desugar-formalization/README.md) | TODO-162 のフェーズ 1 の改造（脱糖の形式化の段階 C1〜C3。性質 1 の証明と、Lean と処理系の脱糖の差分テスト）。調査、判断、実装プラン（フェーズ 2・3 の計画を含む）、差分テストの結果、レビューの記録（`reviews/`） | 2026-10-10 |
| [`2026-10-10-TODO-162-desugar-formalization-phase2/`](2026-10-10-TODO-162-desugar-formalization-phase2/README.md) | TODO-162 のフェーズ 2 の改造（脱糖の形式化の段階 C4〜C7。制御の構成・型クラス・脱糖だけで表す拡張・パターンの拡張。C7 でコア計算の `match` を広げた）。調査、判断、実装プラン、ADR 0312 の制限を外した版の試み、差分テストの結果、レビューの記録（`reviews/`） | 2026-10-10 |
| [`2026-10-10-TODO-162-desugar-formalization-phase3/`](2026-10-10-TODO-162-desugar-formalization-phase3/README.md) | TODO-162 のフェーズ 3 の改造（段階 E1 網羅性の判定の手順の形式化と健全性、段階 E2 型検査の出力を表層の型付けで検査する関数と健全性）。調査、判断、実装プラン、網羅性の差分テストと型検査の出力の検査の結果、レビューの記録（`reviews/`） | 2026-10-10 |

形式検証の定義と言明のレビューの記録（もとは `formal/reviews/`）は、2026-10-10 に、段階ごとの改造のディレクトリの `reviews/` と、段階 A・B の分を `2026-10-09-implement-first-release/formal-reviews/` へ移した。移した記録の中の相対リンクは移した後の場所に合わせて書き換えたが、移す前から切れていたリンク（当時の設計書の置き場所を指すものなど）はそのまま残した。

保管したときに、文書の中の相対リンクとリポジトリの根からのパスを、保管した後の場所に合わせて書き換えた。実装プランから設計書へのリンクは、同じ時点の写し（`2026-09-27-design-initial/`）を指す。初回リリース版の実装プランから設計書へのリンクは、同じ時点の写し（`2026-10-09-design-first-release/`）を指す。処理系のソースコードのパスは、保管した時点の配置（`crates/benitoite/` など）のままであり、その後の変更は反映しない。初回リリース版の検討資料のうち相談の記録（`2026-10-09-implement-first-release/studies/u2-runtime/consult/`）にある、設計者の機械の上の絶対パスによるリンクは、相談の記録のまま残した。

設計判断の記録（ADR、`ADR nnnn`）と未決事項の一覧（`OPEN-nnn`）は、初回リリース版の設計書の写しの `2026-10-09-design-first-release/decisions/` と `2026-10-09-design-first-release/open-issues.md` にだけある。今の設計書はこれらを持たない。測定の記録（`tools/bench/results/` など）、形式検証のレビューの記録（`formal/reviews/`）、`docs/todo/` の項目、このディレクトリの文書に残る ADR と OPEN の番号は、この写しを指す。
