# RV-L00b.02b-closures：群末の独立レビュー依頼

2026-10-31。B_WORKは `1170a4a6d81d49a6d098d2f222ed33c8f22c9230`、指定ブランチは `m014/l00b.02b-closures` である。担当はgitの照合・操作・切替・コミットを行っていない。本書は独立レビューの依頼であり、レビュー済み・受け入れ済みを表さない。

## 対象と読む順

1. [共通依頼文](../implementation-request.md)、plan「計画の変更と取りまとめへの確認点」の2026-10-31の全行、[signatures](../l00b.02/signatures.md)の第12.2節・第24節・第29節と今回の第30節。
2. [resultsの今回の節](../l00b.02/results.md)、[公開宣言](../l00b.02/02b-closures-public-api.md)、[本番の変更一覧とハッシュ](../l00b.02/02b-closures-source-changes.json)。開始時と最終の入力はstart/inputs-finalで固定した。
3. [READMEの設計者の決定](../README.md#設計者の決定)、[decisions](../decisions.md)、[L00aの契約](../l00a.06a/contracts.md)、[中心の補題と申し送り](../l00a.16a/lemmas.md)。前群のRV-values中2・軽4、RV-external軽3、RV-handlers重1・軽1の扱いも確認する。
4. 新しいClosureTyping/StateTypingと、変更したTyping/TypingShift/SubstTyping/Narrowing/TypeShiftTyping/TypedFacts/TypingDeclared等。実行側のCapture/Semantics/Step、旧Releaseの型付けと状態も照合する。
5. [境界入力](../l00b.02/02b-closures-boundary.lean)、[A-L](../l00b.02/02b-closures-axioms.lean)、[検査全体](../l00b.02/02b-closures-validation.json)。最終の件数・時刻はこれらの機械記録を正とする。

## 新規ファイルの全一覧

新しい本番ファイルは次の2件である。

- `formal/Benitoite/Release/Refinement/ClosureTyping.lean`
- `formal/Benitoite/Release/Refinement/StateTyping.lean`

改造内の新規ファイルは次のとおりである。大きいA-Lの生出力はこの一覧に含めず、`<tmp>`の大きさとSHA-256を既存のlarge-recordsへ追記した。

- `l00b.02/02b-closures-public-api.md`
- `l00b.02/02b-closures-boundary.lean`
- `l00b.02/02b-closures-axioms.lean`
- `l00b.02/02b-closures-validate.py`
- `l00b.02/02b-closures-start.json`
- `l00b.02/02b-closures-inputs-final.json`
- `l00b.02/02b-closures-source-changes.json`
- `l00b.02/02b-closures-artifact-inputs.json`
- `l00b.02/02b-closures-commands.json`
- `l00b.02/02b-closures-case-inventory.json`
- `l00b.02/02b-closures-axioms-summary.json`
- `l00b.02/02b-closures-validation.json`
- `l00b.02/02b-closures-build.log`
- `l00b.02/02b-closures-boundary.log`
- `l00b.02/02b-closures-lean-version.log`
- `l00b.02/02b-closures-delivery.json`
- `reviews/RV-L00b.02b-closures-request.md`（本書）

既存の改造文書の変更は `l00b.02/signatures.md`・`results.md`・`large-records.md` の3件である。本番の既存の変更16件と新規2件はsource-changesの全18行を確認する。Ctx.WFは定義を変えずTypeShiftContextからAdmissibleへ、既存のゼロ移動の6補題はTypingStoreからTypingShiftへ移した。共有層、処理系、設計書、plan、旧Release、Semantics/Stepの遷移は変更していない。

## 特に確認してほしい点

| 観点 | 担当の処置と確認先 |
|---|---|
| 8導出と71場合 | V28/C21、TelBody2/CaptureOk1/ClosureTy1/DependentClosureTy1を含む累計71。三族の実際の根と閉じた捕捉の証拠の再利用はresultsへ分けて記した。AtCallの1、ContTy10、CellOk6、StateTyE4を混ぜていないか |
| 旧lamの実行用署名 | SameInputs/RuntimeShapeは名前と各入力型を照合し、結果・効果はDependentClosureTyの本体で検査する。lambdaShapeのUnit/emptyを契約として信用しない。toTel_iffとlegacy_closureのBoolean例が旧lamの閉じ方へ使えるか |
| Γ/Φの捕捉 | CaptureOkが元のΓ/Φ、全someのImageOk、閉じたΓ.facts/Φを構文で保持する。通常値・contLoc・contVarを同じ相互帰納で扱う。Noneの位置を詰めず、そこに残る値は型付き像・事実として読まない。利用可能なsome位置に実値があることは要求する。Failの実際のE_OpFailはNoneスロットに継続場所を保持するため、初案のOption.isSome全列の等号は撤回した。masked_captureの正例も確認する |
| TelBodyと自分のR | paramの逐次のΓ/Φの延長、doneのR=some結果、upRen/upSubstの総束縛数。内部のReturnFreeImages/changeReturnが新しい信頼条件でなく、hideと値束縛から作れているか。通常CQのR0拘束を緩めていないか |
| 実際の依存β | Capture.openTel/instantiateが、Telの逐次bindと実行のCapture.extendManyを同じ終端の型・行へ対応させる。closeValsとVal.substListの観測の一致も証明した。境界のE_Lam/captured_beta/beta_environmentがその接続を検査しているか |
| 逆向きのTelArgs | of_argumentsはTel全体のAnnotationとΓのWF、Tel.argumentsの結果、Vsを受ける。各段のAnnotationをopenValueの型付き像から導く。RV-external軽3の後続のE_ExternalApplyへ渡せるか |
| StoreOkと契約のDeclared | LocTy.Declaredはref/lazyの内容、contの入力・結果・行・Rを閉じた文脈で検査し、StoreOkがWFと別に保持する。ClosureTyのソース/出力R、DependentClosureTyのソース/出力Tel、K_Handle/K_Guard等の捕捉したソース契約も保持する。場所のDeclaredを任意のC/Γへ供給する3補題を確認する。境界のundeclared_prior_conditionsはDeclared以外のStoreOkの条件を満たし、否定が別の失敗で通ることを防いでいる |
| K_Guard | 元のΨのHasTypeArmsQを保持し、guard_contextはhideConts・R=none・empty・全Φ・localExtend δ.length Δを使う。guard_with_builder/guard_frameは外側の構築器の場所を読むguardを実際に型付けする。成功/失敗後は元のR/効果に戻る |
| 状態の範囲 | ContTyはσ/Ebを固定。CellOkは6形、StateTyEはrun/matchRun/error/exitの4形。StateTyはValidだけを要求しReadyを追加しない。matchRunの実行値はGround、腕にもAdequateを要求する。全保存・進行・step_soundを完成と数えていないか |
| 公理と提供範囲 | CoreAssumptions・利用者の書ける形・提供範囲・精密な外部状態は変更していない。新しい公理はない。最終A-Lは全98モジュールと指定旧7宣言を対象にし、自動生成と非公開の証明も含む。許可外依存・sorryAxがないか |
| 後続への配分 | `.03`の参照順序/None/extend、`.11`のfnの正規化、`.14a`の固定Eb、`.14b`のgroundからのΦ、L20/L70の全状態の保存・進行・D29を残している。同じ構文の交換や今回の三族を未完として戻して二重計上しないことも確認する |

## 検査と受け入れの区分

担当は既定の`cd formal && lake build`、境界入力、公理依存の全件照合を実行した。単独のLeanと既定lakefileはともに`-M 12288`である。境界の新しい正例と、Declared以外を満たすストアの反例を追加した後の最終のコマンド・終了・所要・件数はcommands/validation/resultsへ記録する。100 KB超の生出力は改造内へ置いていない。workは起動依頼どおり取りまとめへ残し、RSSは計画上の非採取で未取得である。

この依頼は`.02b-closures`の群末だけを対象とする。`.02c`、全状態の保存、独立レビューと受け入れの完了を担当の自己点検と混同しない。
