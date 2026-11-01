# RV-L10.k: レビュー修正の確認依頼

2026-11-01。群K/I/E、L10.24〜L10.30のRV-L10.kの中1・軽2〜5を処置した。指定ブランチは `m014/l10.k`、B_WORK は `99ff1579586c5b62db54c00b1fbb673b96d02dc4`。git操作は行っていない。初回の独立レビューは条件付き可であり、本書は修正後の確認に渡す依頼である。

## 所見ごとの修正と確認点

| 所見 | 修正先と確認してほしいこと |
|---|---|
| 中1 | LegacyClausesInput の通常節の元の署名を操作自身の型文脈で検査する。外側Cで範囲外の型変数を補わない。LegacyValues の五補題がTopのopSigから同じ長さの範囲SのopSigAtへ埋め込み型のWFを渡す。境界L10KClauseSourceの旧判断・新入力の二拒否とsignature_at_range、ClauseSource変異を確認してほしい |
| 軽2 | LegacyPrimSignature.admits、LegacyTables.sat/rangesを旧受理→新受理へ変更した。L10KOneWayで新側だけの受理が実際に成立する。逆向きの同値は要求しない |
| 軽3 | resultsのL20・局所文脈の行とsignaturesに旧extend n []と新localExtendの相違、LocalCtx.Shift.emptyによるk=0の移送を記した。一般のshift_valuesの前提を無条件に得たとせず、専用補助を閉じる義務を残す。埋め込みへ新しい独立前提を加えない |
| 軽4 | handoff.leanとsignaturesに関数本体・メソッド本体・上位辞書の三つのLegacyOutputInputの親判断を完全な引数で記し、L10.55へ渡す。旧WellTypedとQ/C/Γ/R/効果/κを照合した。LegacyDeclarationsInputだけで代用しない |
| 軽5 | rv-k-t2/t3を境界のL10KApplied/L10KFieldsHeldへ写した。.tappの元の署名・旧V_Funの全入力、実宣言の入力、欄のあるconstructorの表/Scoped/VarianceValid、保持nodeの正負が通る。HeldContent変異も追加した |

RV-L10.k.md、取りまとめの追記、rv-k-t1〜t3は変更していない。review-immutable-inputs.jsonでplan/detail・effort-ledgerも保護した。detailのuseのnv+1は誤りで実装が正しいことをresultsの「補助の契約と計画からのずれ」に明記した。01-12・07-04・用語集を現行の規則にそろえた。

## 証拠と判定の範囲

[結果](../l10/k/results.md)、[完全署名](../l10/k/signatures.md)、[義務の自己照合](../l10/k/obligations.md)、[受渡しの型](../l10/k/handoff.lean)、[検証結果](../l10/k/verification.json)、[変異の詳細](../l10/k/mutations-result.json)を添える。

既定lake buildは760ジョブで終了0、sorryなし。本番七モジュール等351宣言、境界208宣言、受渡し3宣言の計562件はpropext・Quot.sound・Classical.choiceだけに依存する。境界は88定理（拒否14）、本番の補題は58本。対照と五変異を実行し、各変異の該当する負例内の行で検出した。検査入口の記録と変異詳細の保存名を分け、各入力ハッシュ・診断・終了を残した。Leanには全て-M 12288を指定した。

主な十言明、旧46局所規則の列挙、公理、提供範囲、利用者の書ける形、精密な外部状態は変更していない。担当の点検を独立レビューの代用にしない。work/dry-run、全比較、RSS採取、L10.31への着手はしていない。全型付け・宣言・状態の埋め込みと局所文脈の橋渡しは、明記したL10.55/L20へ残す。

## ファイルの完全な一覧

初回からの新規ファイル、今回も含む変更した既存ファイル、今回追加された変更禁止のレビュー補助入力を末尾に分けて列挙する。

基準からの実装担当の新規ファイル（41件）:

- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/axioms-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/axioms-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/boundary-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/boundary-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/build-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/build-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/case-matrix.tsv`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/check.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/files.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/handoff-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/handoff-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/handoff.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/initial-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/main-contracts.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/mutation-boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/mutation-run-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/mutation-run-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/mutations-output.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/mutations-result.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/mutations.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/obligations.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/review-immutable-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/review-started.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/rule-counts.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/self-check.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/started.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/theorems.tsv`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/verification.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L10.k-request.md`
- `formal/Benitoite/Release/Refinement/LegacyDeclarations.lean`
- `formal/Benitoite/Release/Refinement/LegacyInput.lean`
- `formal/Benitoite/Release/Refinement/LegacyKinds.lean`
- `formal/Benitoite/Release/Refinement/LegacyRegularity.lean`
- `formal/Benitoite/Release/Refinement/LegacyTableFacts.lean`
- `formal/Benitoite/Release/Refinement/LegacyTables.lean`
- `formal/Benitoite/Release/Refinement/LegacyValues.lean`

実装担当が変更した既存ファイル（4件）:

- `formal/Benitoite.lean`
- `docs/design/01-spec/01-12-core-calculus.md`
- `docs/design/07-quality/07-04-formal-semantics.md`
- `docs/design/00-overview/00-04-glossary.md`

今回のレビューで渡された変更禁止の補助入力（3件）:

- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/rv-k-t1.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/rv-k-t2.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/k/rv-k-t3.lean`
