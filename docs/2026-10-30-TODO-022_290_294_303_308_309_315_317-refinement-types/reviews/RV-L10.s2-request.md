# RV-L10.s2 再レビューの処置記録と依頼

2026-11-01。L10.44〜L10.51の初回レビュー（重1・軽1〜4）への処置について、定義・言明・仮定の再レビューを依頼する。実装と担当検査は完了した。再レビュー・work・受け入れ・取り込みは取りまとめと設計者が行う。L10.52は開始していない。

指定ブランチは `m014/l10.s2`、B_WORKは `42a09116fd2442fca93b38a7e18b8138356a8dcc`。gitの操作・照合はしていない。型付け規則のOrdinaryの条件の追加は、planの先頭の2026-11-01の判断と今回の依頼で承認された範囲に限る。

## 読む順序

1. [レビュー原本と取りまとめの追記](RV-L10.s2.md)、plan先頭の承認、今回の依頼を確認する。レビュー原本とrv-s2-t1〜t4は変更していない。
2. [完全署名・補助契約5・規則の新旧](../l10/s2/signatures.md)、[結果と各所見の処置](../l10/s2/results.md#再開での所見の処置)を読む。旧読者closedArgs_of・ClosedArgs.singleの補完、弱めた言明の一覧も同所にある。
3. TypeArgsKinded・TypeArgsKindedAt・V_Raise、SignatureInstanceのOrdinaryの供給、TypeArgumentRegularityと群VのsourceOrdの導出を照合する。
4. [boundary.lean](../l10/s2/boundary.lean)の操作の負例、通常の型引数を持つ操作・辞書・メソッドの正例、WF・LeQ・本体の置換、継続のresume、範囲変数とTopAtomsの正負例を読む。
5. [完全署名の型の照合](../l10/s2/signatures.lean)、[十定理の完全な宣言の照合](../l10/s2/main-contracts.json)、[全差分の監査](../l10/s2/axioms.lean)、[最終検証](../l10/s2/verification.json)と01-12・07-04の写しを確認する。

## 所見の処置と確認を依頼する点

| 所見 | 処置 | 確認してほしい契約 |
|---|---|---|
| 重1 | TypeArgsKinded/Atへ `HasKind ∧ (k = .value → Ordinary a)` を追加。SignatureInstanceの利用規則と構成子・辞書・builderで供給する。V_RaiseにはOrdinary t/eを追加。C_Methのss++[τ]はSignatureInstanceから導出 | Annotation/HasKind.valueだけからOrdinaryを誤って得ていないか。constructor kindと継続のresumeを妨げないか |
| 重1・本体の入力 | 操作のts、メソッドのss++ts、raiseの単一の結果型のWF/OrdinaryからWFとLeQの型置換を閉じる。操作・メソッドの返す本体の代表も閉じる | G03へ渡すOrdinaryが新しい規則の欄に由来するか。全状態の保存と代表を混同していないか |
| 重1・群V/Legacy | 三補題のsourceOrdを元のV_Conから導出。LegacyTypesInputは各型のNotContだけの下で追加前の入力と同値。閉性は要求しない。raiseは旧VarsInから、builderは内容型の形から供給 | 適格な旧導出の入力の範囲を狭めていないか。一般のLegacyTypeInputや継続の文脈を制限していないか |
| 軽1 | 範囲変数の拒否、κがあるTopの許可、TopAtomsの正負例、secretsとsnapshotの例を追加 | 行変数と範囲変数を区別しているか |
| 軽2 | 弱めた言明の一覧を結果へ転記。foundationの115件は存在の確認、完全署名158件は型の照合と区別 | foundationの分類16＋43＋31＋68と旧読者二件の補完が十分か |
| 軽3 | 07-04の未定義の語の否定を除き、SourceScopedとの一致は証明と記述 | 設計書に工程の予告やIDを入れていないか |
| 軽4 | Tel.bind_wf/Tel.substAt_wf、Ty/Eff/Tel.substAt_nil_of_wfを追加 | 結果のnormと未使用の像の扱いが正しいか |

主な十定理の前提・結論は完全な宣言で一致する。既定引数内の `:=` と本体の開始を区別して抽出し、群Vの保存ソースの必要部分をmain-contracts-reference.jsonへ写した。十四判断76構成子、値移動・型移動・値置換・narrowingの四本の移送に追随し、Noneの下の置換も保った。新しい公理、提供範囲、利用者の型の文法、精密な外部状態の追加はない。

HandlerCallsの反転と入力は `.op o ts` へ一般化した。HandlerOperation.operation_oneの全状態の代表は単相のままであり、任意の本体の型置換、tappのSorted/Declared、E_Op/E_OpFail/E_Methの全状態への接続はG03の担当範囲として残す。

## 検査と差分

既定 `cd formal && lake build` は終了0、772ジョブ、sorryなし。lakefileと直接のLeanは `-M 12288`。完全署名158件、foundationの対応先115件の存在、境界151宣言、十定理の型、群Vの境界55宣言、補助入力t2〜t4が成功した。初回レビューの反例t1は変更前の型付けを構成する入力のため、同じファイルの再成功を要求せず、新境界でその型付けの否定と通常の型引数の正例を検査した。

全差分32モジュールの全2,551宣言＋既存18件、ほかの入力の公理印字を合わせ2,946件（重複を含む）を確認した。許可外の公理とsorryAxは0件、使用する公理はpropext・Quot.sound・Classical.choiceだけである。既定buildの141警告は既存のlintとリンクの警告であり、最終の局所検査は警告0である。buildは増分である。

01-12・07-04・用語集を同じ変更で更新した。textブロックは変更していないためspec_examplesは実行していない。work・Rustの検査・Rust/Leanの全比較・ベンチマークは実行していない。RSSは計画上の非採取で未取得。再開からの外側の時間と終了時刻はverification.jsonを正とする。

再開時の1,913入力との比較と、plan/detail・レビュー原本・rv-*の107入力の保護照合をverify.pyで行う。変更した既存Leanソースは以下の26ファイルである。これらを含む全差分はaudit-modules.jsonの一覧と一致する。既存文書は01-12・07-04・用語集、群Vのsignatures/results/boundary、本群の証拠と本依頼を更新した。用語集の継続の型付けの説明もOrdinaryの条件へ合わせた。識別はreview-changes.jsonとverification.jsonに保存する。

- `formal/Benitoite.lean`
- `formal/Benitoite/Release/Refinement/Admissible.lean`
- `formal/Benitoite/Release/Refinement/AdmissibleMap.lean`
- `formal/Benitoite/Release/Refinement/ClosedCapture.lean`
- `formal/Benitoite/Release/Refinement/Context/Declarations.lean`
- `formal/Benitoite/Release/Refinement/HandlerAlgebra.lean`
- `formal/Benitoite/Release/Refinement/HandlerCalls.lean`
- `formal/Benitoite/Release/Refinement/HandlerOperation.lean`
- `formal/Benitoite/Release/Refinement/KindValues.lean`
- `formal/Benitoite/Release/Refinement/LazyPreservation.lean`
- `formal/Benitoite/Release/Refinement/LegacyDeclarations.lean`
- `formal/Benitoite/Release/Refinement/LegacyInput.lean`
- `formal/Benitoite/Release/Refinement/LegacyValues.lean`
- `formal/Benitoite/Release/Refinement/Narrowing.lean`
- `formal/Benitoite/Release/Refinement/NarrowingObstruction.lean`
- `formal/Benitoite/Release/Refinement/ReferencePreservation.lean`
- `formal/Benitoite/Release/Refinement/SubstTyping.lean`
- `formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean`
- `formal/Benitoite/Release/Refinement/TypeBounds.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftKinds.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftTyping.lean`
- `formal/Benitoite/Release/Refinement/TypedFacts.lean`
- `formal/Benitoite/Release/Refinement/Typing.lean`
- `formal/Benitoite/Release/Refinement/TypingDeclared.lean`
- `formal/Benitoite/Release/Refinement/TypingShift.lean`
- `formal/Benitoite/Release/Refinement/ValueFacts.lean`

## 再レビューの所見の最終処置

取りまとめの2026-11-01の追記に従い、再中1・再軽1・再軽2を処置した。raise_subst_wf/leは実際のE_OpFailの結果型Tによる[T]の置換へ訂正した。Legacyの同値は各型のNotContだけを要求するiff_of_notContへ替え、旧VarsInとVarsInListからの供給を添えた。Ordinaryと旧NotContは最上位だけの条件であり、入れ子の継続を拒まないことを決定の記録へ追記した。全状態で害がないことの確認はG03の入力とする。

既定buildは772ジョブで成功し、sorryなし。完全署名160件、境界154宣言、補助入力t5が成功した。全差分32モジュールの全2,553宣言＋既存18件の公理依存は、propext・Quot.sound・Classical.choiceだけである。最終検査の印字は合計2,955件（重複を含む）。直接のLeanは-M 12288、既定buildも同じメモリ設定である。plan/detail・レビュー原本・rv-*の現在の108入力と、取りまとめが追記した工数台帳一件を保護し、検査の台本とハッシュを更新した。初回からの既定importと主な十定理の宣言は保つ。

[今回の結果](../l10/s2/results.md#再レビューの所見の処置)と[verification.json](../l10/s2/verification.json)を最終の入力と検査の正とする。レビュー原本とrv-s2-t5は変更していない。取りまとめの「再レビューはこれで閉じる」に従う。work・受け入れ・取り込みは取りまとめと設計者に残す。

## 新規ファイルの全一覧

初回の実装から今回の最終処置までに作成した本番・文書・検査入力・成功と失敗の記録を全件列挙する。new-files.jsonにも同じ一覧を保存する。取りまとめのrv-s2-t1〜t5は変更禁止の入力として保護し、作成したファイルには含めない。100,000 bytesを超える生の記録は一時領域に置き、large-records.mdに大きさとSHA-256を記録する。

- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/audit-modules.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/axioms.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/boundary.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/check-main-contracts.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/check.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/foundation-map.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/foundation.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/initial-record.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/large-records.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/main-contracts-reference.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/main-contracts.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/main-contracts.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/new-files.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/prepare-evidence.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/rereview-start.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/results.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/review-changes.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/review-initial-record.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/review-inputs-before-rereview.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/review-inputs.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-001-regularity.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-001-regularity.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-002-regularity.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-002-regularity.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-003-bounds-bind.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-003-bounds-bind.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-004-bounds-bind.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-004-bounds-bind.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-005-bounds-bind.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-005-bounds-bind.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-006-bounds-bind.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-006-bounds-bind.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-007-bounds-subst.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-007-bounds-subst.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-008-bounds-subst.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-008-bounds-subst.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-009-rows.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-009-rows.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-010-variables.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-010-variables.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-011-variables.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-011-variables.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-012-bounds-deps.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-012-bounds-deps.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-013-variables.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-013-variables.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-014-shift-algebra.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-014-shift-algebra.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-015-shift-order.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-015-shift-order.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-016-effects.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-016-effects.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-017-effects.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-017-effects.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-018-effects.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-018-effects.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-019-effects.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-019-effects.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-020-new-modules.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-020-new-modules.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-021-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-021-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-022-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-022-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-023-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-023-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-024-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-024-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-025-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-025-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-026-build.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-026-build.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-027-signatures.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-027-signatures.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-028-signatures.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-028-signatures.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-029-foundation.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-029-foundation.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-030-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-030-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-031-axioms.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-031-axioms.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-032-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-032-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-033-review-kinds.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-033-review-kinds.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-034-review-typing.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-034-review-typing.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-035-review-transports.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-035-review-transports.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-036-review-follow.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-036-review-follow.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-037-review-handler.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-037-review-handler.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-038-review-regularity.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-038-review-regularity.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-039-review-regularity.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-039-review-regularity.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-040-review-regularity.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-040-review-regularity.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-041-review-legacy.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-041-review-legacy.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-042-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-042-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-043-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-043-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-044-build.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-044-build.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-045-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-045-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-046-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-046-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-047-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-047-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-048-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-048-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-049-signatures.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-049-signatures.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-050-build.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-050-build.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-051-build.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-051-build.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-052-main-contracts.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-052-main-contracts.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-053-review-t3.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-053-review-t3.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-054-review-t4.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-054-review-t4.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-055-foundation.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-055-foundation.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-055-review-t2.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-055-review-t2.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-057-v-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-057-v-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-058-signatures.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-058-signatures.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-059-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-059-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-060-axioms.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-061-main-contracts.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-061-main-contracts.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-062-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-062-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-063-signatures.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-063-signatures.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-064-rereview-regularity.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-064-rereview-regularity.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-065-build.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-065-build.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-066-review-t5.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-066-review-t5.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-067-signatures.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-067-signatures.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-068-boundary.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-068-boundary.txt`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/run-069-axioms.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/signatures.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/signatures.md`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/verification.json`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/verify.py`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/reviews/RV-L10.s2-request.md`
- `formal/Benitoite/Release/Refinement/EffectFacts.lean`
- `formal/Benitoite/Release/Refinement/TypeArgumentRegularity.lean`
- `formal/Benitoite/Release/Refinement/TypeBounds.lean`
- `formal/Benitoite/Release/Refinement/TypeRegularity.lean`
- `formal/Benitoite/Release/Refinement/TypeRows.lean`
- `formal/Benitoite/Release/Refinement/TypeShiftFacts.lean`
- `formal/Benitoite/Release/Refinement/TypeVariables.lean`
- `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l10/s2/coordinator-inputs.json`
