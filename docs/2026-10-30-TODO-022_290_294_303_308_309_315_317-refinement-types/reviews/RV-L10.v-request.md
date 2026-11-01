# RV-L10.v: 群 V のレビュー修正の再確認依頼

2026-11-01。L10.01〜L10.13 に対する [RV-L10.v.md](RV-L10.v.md) の中1〜3・軽1〜3と「取りまとめの追記」に従った修正の再確認を依頼する。実装担当の修正と指定の検証は完了した。修正後の独立レビュー済み又は受け入れ済みとは扱わない。

指定ブランチは `m014/l10.v`、B_WORK は `c668ff024b99287de702c5823c6280f8130a6aa5` である。git の操作・照合・コミット、work、L10.14 以降の作業は行っていない。初回からの全差分は [source-state.json](../l10/v/source-state.json)、今回の修正だけの差分は [review-fix-state.json](../l10/v/review-fix-state.json) を正とする。git の HEAD との一致を再確認したという意味ではない。

## 所見の処置と確認してほしい点

[review-handling.md](../l10/v/review-handling.md) に六所見の処置、[signatures.md](../l10/v/signatures.md) に現在の補助の契約、[results.md](../l10/v/results.md) に単位ごとの判定・提供表の不足・後段の担当をまとめた。初回の記録の L10.07・L10.08 の完了判定には形成の未実装の見落としがあり、本番の補題と実際の呼出しを加えて訂正した。

1. 中1: 新しい TypeFormation の `Annotation.subst_types_closed`・`VarianceValid.field_annotation` が、検証済みの総称の欄と型引数の Annotation・個数・Ordinary から欄の形成を導いているか。NoTapp は総称の欄の kind から導け、利用者に新しい構文の制限を課していないか。
2. 中1: `Declared` と `HasData.typesOnly` の型置換、特に HasData の field と widen の枝を確認すること。widen の対応は型像を射影して置換し、再度射影して保つ。消した List の子などを復元する仮定を加えていないか。
3. 中1: `inv_con` が元の V_Con の kind と data の Annotation を保持するか。`constructor_field_inputs` と境界の `supplied_sourceField_and_inputs`・`field_widened` が、欄ごとの Annotation を呼出し側へ残さず、実際の V_Con → V_Sub の値から sourceField と inputs を供給するか。
4. 中2: 単調性の相互証明を総称の Sorted・SortMap・OrdinaryTypeImages で閉じ、`variance_field_mono` から具体化後の注釈・valid・inputs を除いたか。`field_mono_trans` の中間列には Annotation と Ordinary の前提がないか。
5. 中3: 01-12 の P 付き部分型・K_Sub・data の型引数、07-04 の新規5モジュールと第六の TypeFormation の対応、用語集の variance・変性と公式の用例が現在の実装と合うか。
6. 軽1〜3: 実績と見込みの比較、初回に形成が未実装だった点、304枝の読み方、群 X・W へ比例で適用しない点が明記されたか。HasData/widen の docstring と VarianceValid の申し送り、未使用の Polarity.join の削除を確認すること。
7. 引き続き、四族22規則が同じ P を読み、未使用の型引数は不変であり、14判断76場合の四本の移送を保つか。主な10定理の前提・結論と、新しい公理・提供範囲・利用者の書ける形・精密な外部状態の境界を確認すること。

レビュー原本と t2〜t6 は変更していない。元の署名を使う補助入力は原本として保存し、現在の API の検査は boundary に置いた。開始時からの一致は [immutable-inputs.json](../l10/v/immutable-inputs.json) にある。レビュー原本・plan・detail・rv 入力・処理系は編集しない。設計書の上記三章の変更は今回の起動指示で承認済みである。

## 検証済みの範囲

- 既定の `cd formal && lake build`: 終了0、743ジョブ、外側51.378秒。各 Lean プロセスは `-M 12288`。
- 境界: 終了0、0.810秒、55定数。共変・反変・不変の正例、誤宣言・Token の拒否、P なしの旧判断、Byte と七幅の比較を維持し、形成・推移・widen の型置換の呼出しを追加した。
- 完全署名: 終了0、137宣言。現在の型は signatures-output.txt に保存した。
- 公理依存: 変更46モジュールと未変更の TypeShiftTyping/SubstTyping の48モジュール、5662定数＋旧主定理・三モデル8件＝5670回。許可した propext・Quot.sound・Classical.choice のみ。sorryAx・独自公理・対象漏れ0。
- 四族は14＋2＋2＋4＝22規則。型付け相互14判断は76規則、四本の既存の相互移送の照合は304枝。主な10定理の宣言は初回開始時の写しと一致した。
- 根の `cargo test --test spec_examples`: 終了0、7件成功、外側8.688秒。01-spec の text ブロック24個は変更前と一致する。

再現の台本は [check.py](../l10/v/check.py)、入力60ファイルのハッシュは [check-inputs.json](../l10/v/check-inputs.json) にある。小さい出力は相対リンクで保存し、作業領域のパスは `<repo>` とした。100,000 byteを超える生の出力は `<tmp>` に置き、[large-records.md](../l10/v/large-records.md) に大きさと SHA-256 を保存した。全差分の公理依存は [axioms-summary.md](../l10/v/axioms-summary.md)、主な定理の契約は [main-contracts.md](../l10/v/main-contracts.md) にある。

## 新規ファイルの全一覧

初回からの本番の新規ファイルは6件である。今回追加したものは TypeFormation.lean である。

- [ObservationType.lean](../../../formal/Benitoite/Release/Refinement/ObservationType.lean)
- [TypeFormation.lean](../../../formal/Benitoite/Release/Refinement/TypeFormation.lean)
- [VarianceFormation.lean](../../../formal/Benitoite/Release/Refinement/VarianceFormation.lean)
- [VarianceSyntax.lean](../../../formal/Benitoite/Release/Refinement/VarianceSyntax.lean)
- [VarianceTransport.lean](../../../formal/Benitoite/Release/Refinement/VarianceTransport.lean)
- [VarianceValidation.lean](../../../formal/Benitoite/Release/Refinement/VarianceValidation.lean)

改造内の新規ファイルは次のとおりである。検証入力・台本・小さい出力・ハッシュと判定の記録を含む。レビュー担当から渡された t2〜t6 は実装担当の新規ファイルに数えない。

- [axioms-result.json](../l10/v/axioms-result.json)
- [axioms-summary.md](../l10/v/axioms-summary.md)
- [axioms.lean](../l10/v/axioms.lean)
- [boundary-output.txt](../l10/v/boundary-output.txt)
- [boundary-result.json](../l10/v/boundary-result.json)
- [boundary.lean](../l10/v/boundary.lean)
- [build-output.txt](../l10/v/build-output.txt)
- [build-result.json](../l10/v/build-result.json)
- [case-matrix.tsv](../l10/v/case-matrix.tsv)
- [check-inputs.json](../l10/v/check-inputs.json)
- [check.py](../l10/v/check.py)
- [immutable-inputs.json](../l10/v/immutable-inputs.json)
- [large-records.md](../l10/v/large-records.md)
- [main-contracts-result.json](../l10/v/main-contracts-result.json)
- [main-contracts.md](../l10/v/main-contracts.md)
- [results.md](../l10/v/results.md)
- [review-fix-state.json](../l10/v/review-fix-state.json)
- [review-handling.md](../l10/v/review-handling.md)
- [signatures-output.txt](../l10/v/signatures-output.txt)
- [signatures-result.json](../l10/v/signatures-result.json)
- [signatures.lean](../l10/v/signatures.lean)
- [signatures.md](../l10/v/signatures.md)
- [source-state.json](../l10/v/source-state.json)
- [spec-examples-output.txt](../l10/v/spec-examples-output.txt)
- [spec-examples-result.json](../l10/v/spec-examples-result.json)
- [RV-L10.v-request.md](RV-L10.v-request.md)（本依頼）

## 既存ファイルの変更一覧

初回開始時の写しとの識別を用いた一覧であり、git 操作で得たものではない。今回の修正は、このうち Lean の Declared・ValueFacts・VarianceSyntax・VarianceTransport・Benitoite と、新規 TypeFormation、および設計書三章である。

- [Canonical.lean](../../../formal/Benitoite/Release/Refinement/Canonical.lean)
- [ContextMap.lean](../../../formal/Benitoite/Release/Refinement/ContextMap.lean)
- [Declared.lean](../../../formal/Benitoite/Release/Refinement/Declared.lean)
- [DeclaredTransport.lean](../../../formal/Benitoite/Release/Refinement/DeclaredTransport.lean)
- [DependentBeta.lean](../../../formal/Benitoite/Release/Refinement/DependentBeta.lean)
- [Embedding.lean](../../../formal/Benitoite/Release/Refinement/Embedding.lean)
- [ExternalCheck.lean](../../../formal/Benitoite/Release/Refinement/ExternalCheck.lean)
- [HandlerCalls.lean](../../../formal/Benitoite/Release/Refinement/HandlerCalls.lean)
- [HandlerContinuation.lean](../../../formal/Benitoite/Release/Refinement/HandlerContinuation.lean)
- [HandlerPreservation.lean](../../../formal/Benitoite/Release/Refinement/HandlerPreservation.lean)
- [HeldValues.lean](../../../formal/Benitoite/Release/Refinement/HeldValues.lean)
- [InversionCore.lean](../../../formal/Benitoite/Release/Refinement/InversionCore.lean)
- [LazyInversion.lean](../../../formal/Benitoite/Release/Refinement/LazyInversion.lean)
- [LazyPreservation.lean](../../../formal/Benitoite/Release/Refinement/LazyPreservation.lean)
- [LazyStore.lean](../../../formal/Benitoite/Release/Refinement/LazyStore.lean)
- [Le.lean](../../../formal/Benitoite/Release/Refinement/Le.lean)
- [MatchFacts.lean](../../../formal/Benitoite/Release/Refinement/MatchFacts.lean)
- [MatchPaths.lean](../../../formal/Benitoite/Release/Refinement/MatchPaths.lean)
- [Narrowing.lean](../../../formal/Benitoite/Release/Refinement/Narrowing.lean)
- [NarrowingObstruction.lean](../../../formal/Benitoite/Release/Refinement/NarrowingObstruction.lean)
- [OpenSubstitution.lean](../../../formal/Benitoite/Release/Refinement/OpenSubstitution.lean)
- [PathConditions.lean](../../../formal/Benitoite/Release/Refinement/PathConditions.lean)
- [RangeSubst.lean](../../../formal/Benitoite/Release/Refinement/RangeSubst.lean)
- [ReferenceCalls.lean](../../../formal/Benitoite/Release/Refinement/ReferenceCalls.lean)
- [Shift.lean](../../../formal/Benitoite/Release/Refinement/Shift.lean)
- [StateTyping.lean](../../../formal/Benitoite/Release/Refinement/StateTyping.lean)
- [SubstTypingObstruction.lean](../../../formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean)
- [Syntax.lean](../../../formal/Benitoite/Release/Refinement/Syntax.lean)
- [Telescope.lean](../../../formal/Benitoite/Release/Refinement/Telescope.lean)
- [Transport.lean](../../../formal/Benitoite/Release/Refinement/Transport.lean)
- [TypeShiftContext.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftContext.lean)
- [TypeShiftContracts.lean](../../../formal/Benitoite/Release/Refinement/TypeShiftContracts.lean)
- [TypeSubst.lean](../../../formal/Benitoite/Release/Refinement/TypeSubst.lean)
- [TypedFacts.lean](../../../formal/Benitoite/Release/Refinement/TypedFacts.lean)
- [Typing.lean](../../../formal/Benitoite/Release/Refinement/Typing.lean)
- [TypingDeclared.lean](../../../formal/Benitoite/Release/Refinement/TypingDeclared.lean)
- [TypingShift.lean](../../../formal/Benitoite/Release/Refinement/TypingShift.lean)
- [ValueFacts.lean](../../../formal/Benitoite/Release/Refinement/ValueFacts.lean)
- [ValueSubst.lean](../../../formal/Benitoite/Release/Refinement/ValueSubst.lean)
- [Benitoite.lean](../../../formal/Benitoite.lean)
- [01-12-core-calculus.md](../../../docs/design/01-spec/01-12-core-calculus.md)
- [07-04-formal-semantics.md](../../../docs/design/07-quality/07-04-formal-semantics.md)
- [00-04-glossary.md](../../../docs/design/00-overview/00-04-glossary.md)

## 残りと群 X への申し送り

| 担当 | 残る手順と引き継ぐ条件 | 見込み |
|---|---|---|
| 取りまとめ・レビュー担当 | 上の六所見と補助の契約を再確認し、所見の判定を閉じる | 不明 |
| 取りまとめ・設計者 | work、取り込み、次の B_WORK の固定、受け入れ | 不明 |
| 群 X | 新しい constructor_field_inputs/con_field_by_type を用いる。型引数の Ordinary と行き先の型引数の Annotation は補助へ渡し、欄ごとの形成を ValueMeaning や主な定理の前提に追加しない。HasData.widen の引数は観測用であり、実の引数との等号ではない。欄の sort の反映に VarianceValid を用いる | detail の既存枠。今回の実績から縮めない |
| 群 W・L30/L40・L70/R10b | WellTyped への VarianceValid の格納、観測の準備の sort の反映、metadata の原ソースからの収集の完全性をそれぞれ接続する | 各段の既存枠又は不明 |

今回指定された修正に未完はない。再レビュー・受け入れは取りまとめへ残し、L10.14 以降には進まない。
