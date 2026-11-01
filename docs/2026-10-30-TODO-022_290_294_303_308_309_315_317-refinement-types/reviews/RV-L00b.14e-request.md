# RV-L00b.14e: 所見対応後の再レビュー依頼

2026-11-01。実装担当から取りまとめへの依頼である。[レビュー本文](RV-L00b.14e.md) と末尾の取りまとめの追記、計画の先頭の承認を受け、中1・軽1〜軽5に対応した。本書は実装担当の処置と再確認の依頼であり、独立した再レビューの結果ではない。レビュー本文・rv-* は変更していない。

指定ブランチは `m014/l00b.14e`、B_WORK は `c64c0dc376b85185744303c4752d1f1bb34967af` である。git の照合・切替・作成・コミットはしていない。[results](../l00b.14e/results.md) の分類は **一部** を維持する。必須4種と追加5種の計9種の Step と保存の代表であり、全単相節・多相節・used/drop 全体・全状態の保存は L20 に残る。L00b.15 は実施していない。work は取りまとめが行う。

## 承認された前提の復帰と逆転

CoreAssumptions に旧の `state_effect : B.effects stateEff = some []` を戻した。旧 Release.Program/Builtins と Refinement.Program/Builtins は異なる型なので、承認された代案に従い、旧 EffectsOk の三連言をそのまま Refinement.Program.EffectsOk へ写した。名前空間と引数の型だけが異なる。verify.py でも定義本体を照合している。

四つの解放時の保存補題は `(hdecl : P.EffectsOk B)`・`(hA : Builtins.CoreAssumptions P B)` と開始の StateTyE を入力とする。NoStateHandled は二つから導き、独立した前提にしない。operation_one の hx/hy は開始の型付けから導いて削除した。ContTy/StateTyE、型付け・遷移の規則、新しい公理、提供範囲、利用者の書ける形、精密な外部状態は変えていない。

## 所見別の確認点

| 所見 | 処置 | 再確認を依頼する点 |
|---|---|---|
| 中1 | HandlerEffects に EffectsOk/NoStateHandled/noStateHandled/state_end/prepend_releases、HandlerPreservation に drop_rel_const と三つの伝播の保存を追加した | State が handled で消されない導出、全10構成子での State の到達と解放の前置、K_Drop の条件、used 化と捕捉・閉性の保持 |
| 軽1 | io_op（Builtins.ShapeOk）が現在の CoreAssumptions にない点と、E_OpPrim での要否・範囲の一致の再現と scoped の逆転の義務を L20 に明記した | 未再現の候補を確定した反例として書いていないか。承認外の条件を足していないか |
| 軽2 | split_fail/fail_input を HandlerFailure に移し、具体の失敗節から両方を使う境界を追加した | 格納の行 `.mk et.atoms ec.fails` の向き、入力の正規形の一致。E_OpFail 全体は型置換の補題の後であること |
| 軽3 | capture_tel/result_tel と必要な定義・補助を HandlerTelescope に移し、二つの実値 three の依存する入力/結果を境界に追加した | 任意の hcap と依存列の長さを保つこと。残件が操作全体の合成へ縮まっているか |
| 軽4 | hx を引数列の導出、hy を SignatureInstance.result から取り、operation_one の入力から削除した | pure_operation_signature の C_App/C_DependentApp・部分型・正規化の逆転。一般の hy/hxn/hyn/hbn と dictParams が L20 に残ること |
| 軽5 | signatures の guard の説明を先頭 guard の直前の対象の操作へ限定した | 内側の handler による操作の処理まで禁止したという説明がないか |

## 境界と代表の範囲

[boundary.lean](../l00b.14e/boundary.lean) の元の execution は、篩の入力を持つ操作の呼出し、節、resume、継続が事実を読む返却、handler、drop の5遷移と全到達の StateTyE を持つ。D19 の addEvaluated/addEntailed、閉じた評価、捕捉のストアの移送、二度目の再開、契約を外す負例を維持した。

追加した Release の四つの正例は、保存された継続 `[release resource, handleF empty []]` から非空の解放列を残し、セルを used にする。通常の返却は任意の捕捉から定数の view、escape は pure の定数の閉包、error/exit は任意の開始の状態に対する代表である。ReviewCounterTable は t1 の元の表が新しい state_effect を満たさないことと、B の予約だけを直すと P が EffectsOk に反することを分けて示す。

Failure の正例は具体の HasFailureClause と ContTy を構成して公開の二入口を使う。TwoArguments.captured は実際の二引数 [three,three] を型付け、第二引数と結果が第一引数を読むことを確認する。任意の捕捉を扱う一般の two_dependent_arguments もある。到達の結論の型付けを境界の入力には持たない。

operation_one は単相一引数・空の dictParams・pure・Normal・空のコード型置換の固定点という限定を持つ。capture_tel/result_tel の完成を、複数引数の操作の Step 全体の完成とは扱わない。L20 の残件は既存の型置換・閉包・ストア・継続の保存の内数であり、Lazy/Reference と重複加算しない。

## 本番の全ファイルと作業の全ファイル

B_WORK からの既存ファイルの変更は `formal/Benitoite.lean` の import と `formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean` の state_effect である。本番の新規は次の8本であり、この再開で新設したのは HandlerEffects/HandlerFailure/HandlerTelescope の3本である。初回の既存5本のうち HandlerCalls/HandlerOperation/HandlerPreservation はこの再開でも変更した。

- [formal/Benitoite/Release/Refinement/HandlerContinuation.lean](../../../formal/Benitoite/Release/Refinement/HandlerContinuation.lean)
- [formal/Benitoite/Release/Refinement/HandlerStore.lean](../../../formal/Benitoite/Release/Refinement/HandlerStore.lean)
- [formal/Benitoite/Release/Refinement/HandlerEffects.lean](../../../formal/Benitoite/Release/Refinement/HandlerEffects.lean)
- [formal/Benitoite/Release/Refinement/HandlerFailure.lean](../../../formal/Benitoite/Release/Refinement/HandlerFailure.lean)
- [formal/Benitoite/Release/Refinement/HandlerCalls.lean](../../../formal/Benitoite/Release/Refinement/HandlerCalls.lean)
- [formal/Benitoite/Release/Refinement/HandlerTelescope.lean](../../../formal/Benitoite/Release/Refinement/HandlerTelescope.lean)
- [formal/Benitoite/Release/Refinement/HandlerPreservation.lean](../../../formal/Benitoite/Release/Refinement/HandlerPreservation.lean)
- [formal/Benitoite/Release/Refinement/HandlerOperation.lean](../../../formal/Benitoite/Release/Refinement/HandlerOperation.lean)

作業の補助・文書・台本・記録の全ファイルは次のとおりである。初回の記録は initial/first として保持し、今回の最初の一括確認の失敗は resume-first、最終の成功は接尾辞なしに記録する。rv-* は提供された保護入力であり、下の新規ファイルの一覧には混ぜない。大きな生の出力は改造へ置かず、large-records の表で引く。

- [l00b.14e/axioms-summary-initial.json](../l00b.14e/axioms-summary-initial.json)
- [l00b.14e/axioms-summary.json](../l00b.14e/axioms-summary.json)
- [l00b.14e/axioms.lean](../l00b.14e/axioms.lean)
- [l00b.14e/boundary-first.log](../l00b.14e/boundary-first.log)
- [l00b.14e/boundary-initial.log](../l00b.14e/boundary-initial.log)
- [l00b.14e/boundary-inputs-initial.json](../l00b.14e/boundary-inputs-initial.json)
- [l00b.14e/boundary-inputs.json](../l00b.14e/boundary-inputs.json)
- [l00b.14e/boundary-resume-first.log](../l00b.14e/boundary-resume-first.log)
- [l00b.14e/boundary.lean](../l00b.14e/boundary.lean)
- [l00b.14e/boundary.log](../l00b.14e/boundary.log)
- [l00b.14e/build-initial.log](../l00b.14e/build-initial.log)
- [l00b.14e/build.log](../l00b.14e/build.log)
- [l00b.14e/large-records-initial.md](../l00b.14e/large-records-initial.md)
- [l00b.14e/large-records.md](../l00b.14e/large-records.md)
- [l00b.14e/protected-check.json](../l00b.14e/protected-check.json)
- [l00b.14e/protected-inputs.json](../l00b.14e/protected-inputs.json)
- [l00b.14e/public-api-initial.log](../l00b.14e/public-api-initial.log)
- [l00b.14e/public-api.lean](../l00b.14e/public-api.lean)
- [l00b.14e/public-api.log](../l00b.14e/public-api.log)
- [l00b.14e/public-names-initial.json](../l00b.14e/public-names-initial.json)
- [l00b.14e/public-names.json](../l00b.14e/public-names.json)
- [l00b.14e/results-initial.md](../l00b.14e/results-initial.md)
- [l00b.14e/results.md](../l00b.14e/results.md)
- [l00b.14e/resume-before.json](../l00b.14e/resume-before.json)
- [l00b.14e/signatures-initial.md](../l00b.14e/signatures-initial.md)
- [l00b.14e/signatures.md](../l00b.14e/signatures.md)
- [l00b.14e/source-delta-initial.json](../l00b.14e/source-delta-initial.json)
- [l00b.14e/source-delta.json](../l00b.14e/source-delta.json)
- [l00b.14e/source-inputs-initial.json](../l00b.14e/source-inputs-initial.json)
- [l00b.14e/source-inputs.json](../l00b.14e/source-inputs.json)
- [l00b.14e/verification-first.json](../l00b.14e/verification-first.json)
- [l00b.14e/verification-initial.json](../l00b.14e/verification-initial.json)
- [l00b.14e/verification-resume-first.json](../l00b.14e/verification-resume-first.json)
- [l00b.14e/verification.json](../l00b.14e/verification.json)
- [l00b.14e/verified-build.json](../l00b.14e/verified-build.json)
- [l00b.14e/verify.py](../l00b.14e/verify.py)

この依頼ファイルは `reviews/RV-L00b.14e-request.md` である。この再開で新設した文書・記録は *-initial、protected-inputs.json、protected-check.json、resume-before.json、boundary-resume-first.log、verification-resume-first.json であり、上の全一覧に含めた。保護した7入力のハッシュは protected-inputs/protected-check にある。レビュー本文、計画、設計書、処理系を変更していない。

## 検査と再現

既定の `cd formal && lake build` は736ジョブで成功し、Lean の各プロセスは lakefile と単独の引数で -M 12288 に制限した。境界155宣言、公開36宣言（定義5・補題31）と state_effect の射影、A-L の155モジュール・15,497宣言を確認した。依存公理は propext・Quot.sound・Classical.choice のみで、sorryAx はない。相互三族76・Step76・ContTy10・GuardBodyTy1・Cell6・値29・計算24の構成子数も一致した。

台本は EffectsOk の旧の定義との一致、全形式化ソースと設定の491入力、境界・公開署名・A-L・台本、保護した rv-* とレビュー本文のハッシュを記録する。今回の最初の一括確認では、境界の簡約リストの不要な未知の名前により終了1だった。境界を直し、その後ビルドのハッシュの対象を既定の全入口へ広げて、最後の一括確認を全て通した。本番ソースにはこの検査修正はない。元記録・外側の時間・入力のハッシュは results/verification にある。

再現はリポジトリの根で `python3 docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l00b.14e/verify.py` とする。Rust の検査・全比較・work の実施を主張しない。

| 残る手順 | 担当 | 見込み |
|---|---|---|
| 所見の処置、定義・言明・仮定と境界の独立した再レビュー | 取りまとめが起動するレビュー担当 | 不明 |
| 再レビューで必要になった修正と関係する検査 | 実装担当 | 不明（所見による） |
| 指定された作業末の work と取り込み | 取りまとめ | 不明 |
| L00b.15 以降の写し・分類・残件の整理と受け入れ | 取りまとめ・設計者 | 不明 |
