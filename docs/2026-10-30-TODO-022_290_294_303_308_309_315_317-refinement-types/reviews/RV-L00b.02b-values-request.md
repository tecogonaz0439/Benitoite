# RV-L00b.02b-values：群末のレビュー依頼

2026-10-31。案Aを採った再開の実装と群末の検査を終えた。独立レビューを依頼する。前の停止点だけを対象にした依頼を、本依頼へ置き換える。担当の自己点検を独立レビュー済みとは扱わない。

## 基準と読む順序

B_WORKは `fb9afed8a9dc800ea558c07ccdc7c589b40118f8`、指定ブランチは `m014/l00b.02b-values`、前の群の取り込みは依頼の `08f9ac72` である。担当はgitの照合・操作を行っていない。

1. [plan](../plan.md)の2026-10-31の取りまとめの判断（案Aの採用、RV-.02a、補助の契約の委任）。
2. [signatures](../l00b.02/signatures.md)の第12節のこの起動単位、第19節以降、**第22節・第23節**。第21節の停止は過去の記録。
3. [results](../l00b.02/results.md)の「案Aでの再開と群末」、[停止点への追記](../l00b.02/02b-values-contract.md)、[公開の宣言の追加](../l00b.02/02b-values-r2-public-api.md)。
4. READMEの設計者の決定・decisions・l00a.06a/contracts・l00a.16a/lemmasと、本番Lean。

処理系・現行設計書・plan.mdは変更していない。作業末のworkは依頼どおり取りまとめへ残した。次の外部の起動単位には進んでいない。

## 対象と完了の主張

- V_Fun/Prim/Op/Raise/Con/LocRef/LocLazy/Map/Set/Bytes/Dict/Superの12、C_BuilderLet/BuilderOp/If/Lazy/Escape/Use/Methの7、許容とストアの移送を接続した。
- 移動・値の相互置換・narrowingは各V18/C12/Vs2/Each2=34。TypedFactsの予定の2入口は36場合、補助入口は80場合。値・値列・計算のDeclaredとnarrowingへの供給を閉じた。
- Capture1/Closure1、Val19/Comp13、Frame7/Cell6/LocTy4/State4、Event2、旧Step68/Steps2とstep、旧構文・宣言・状態の埋め込みを置いた。旧68遷移の名前・順序も一致した。
- 案Aの四条件はLeanの公理ではなくCoreAssumptionsの証拠であり、CoreAssumptions.valuesから補助定理へ渡す。三モデルの充足はL50等へ明記した。全CoreAssumptionsの既存の応答条件・型付き状態・全保存・step_soundを今回完成したとは主張しない。

## 重点的に確かめてほしい点

1. **案AとD28**。sat/admitsの四条件の量化、Annotationと型付きの像の範囲、単調な改名、主な定理からの供給の経路を確認してほしい。独自公理や、葉ごとの移送に閉じた形への受理条件の置換にしていないか。三モデルのcarrierの骨格による充足を未証明のまま完了と数えていないか。
2. **RV-L00b.02a中1**。V_Lam/List等のDeclared、Ctx.Declaredを前提にしたV/Vs/CQの正則性、Ctx.Narrows.of_valueを確認してほしい。未宣言の名前は表層で拒まれることを根拠に、利用者の書ける形を狭めないか。C_Let/BuilderLetの外側の結果の明示的なDeclaredも含む。
3. **宣言のkindと名目型**。宣言のTel、primitiveの元のadmitsと範囲具体化、型クラスのargumentKind、Conのdata/欄/arity、Constructor kindの型引数を落としていないか。Program.WellTypedとの接続は`.03`の残る義務と区別する。
4. **局所参照・ストア・None**。LocalCtx.extendがkind内の値参照もshiftすること、LocalSubstOkがρの種類を照合すること、値の任意ρを保持する根拠、PreservesNormals/Extendsの使い分けとhideを確認してほしい。CQ/NoneのR0拘束の切替は予定どおりhandlersに残している。
5. **依存するメソッド引数**。Tel.argumentsは先行する実引数で次の引数型と結果・効果を具体化する。C_MethのVsの型列とarguments_subst/map/shiftの交換、部分観測のNone、型・行引数にある外側の値依存を確認してほしい。
6. **閉包と68遷移**。Closure.viewで一歩に必要な値だけを閉じること、let/guard/handler/thunkのCapture保持、引数を一度だけ追加すること、固定σ、解放・error・exit・dropの順序を確認してほしい。旧lamのlambdaShapeの終端unit/emptyは結果型・効果の証拠に使わず、後のClosureTyがbodyを照合するという契約にも注意してほしい。
7. **検査の境界**。重複Map、依存鍵型の反例の表の除外、場所の削除、捕捉値の確認を、本番の型付け・遷移を使う補助入力で確認した。自己点検・核の型検査・後段の状態保存の証明を混同していないか。

## 検査と再現

[結果](../l00b.02/02b-values-r2-validation.json)、[コマンド](../l00b.02/02b-values-r2-commands.json)、[393入力のSHA-256](../l00b.02/02b-values-r2-inputs-final.json)、[変更した28ファイルとSHA-256](../l00b.02/02b-values-r2-source-changes.json)、[補助入力のSHA-256](../l00b.02/02b-values-r2-artifact-inputs.json)を保存した。検査の前後の本番入力は一致した。

| 検査 | 結果 |
|---|---|
| 既定 `cd formal && lake build` | 終了0、636 jobs。最終入口はキャッシュ利用0.155秒 |
| 案A・Map・場所・Captureの境界 | 終了0、30宣言、0.648秒 |
| 以前のr4の参照等の境界 | 入力を変えず終了0、0.648秒 |
| 以前のr5のkindの境界 | 入力を変えず終了0、21宣言の公理依存、0.385秒 |
| 新規/変更宣言の公理依存 | 全63モジュール・7,448宣言、終了0、5.978秒。許可したpropext/Quot.sound/Classical.choiceだけ |
| sorry等の抜け道 | 本番Refinementの語の検出なし。公理依存にもsorryAxなし |
| Leanの上限 | 既定・単独とも-M 12288、Lean4.34.1、設定と固定版の変更なし |
| work / RSS | work未実行（取りまとめへ引継ぎ）、RSS未取得（計画上の非採取） |

再現の入口は [r2の台本](../l00b.02/02b-values-r2-validate.py)。一時領域のbaselineはソースの差分と入力ハッシュを取るためにだけ使い、本番や境界・公理依存の入力は改造に保存している。大きな差分206,185バイトと公理依存762,611バイトの生の記録は改造へ置かず、[large-records](../l00b.02/large-records.md)に大きさとSHA-256を記した。以前の停止時点の入力・出力は履歴であり、現在の構成子数の検査として再利用しない。

## 新規ファイルの全一覧

### 本番Lean17ファイル

- [Admissible.lean](../../../formal/Benitoite/Release/Refinement/Admissible.lean)
- [AdmissibleMap.lean](../../../formal/Benitoite/Release/Refinement/AdmissibleMap.lean)
- [BuilderExec.lean](../../../formal/Benitoite/Release/Refinement/BuilderExec.lean)
- [Capture.lean](../../../formal/Benitoite/Release/Refinement/Capture.lean)
- [ConstraintAssumptions.lean](../../../formal/Benitoite/Release/Refinement/ConstraintAssumptions.lean)
- [Embedding.lean](../../../formal/Benitoite/Release/Refinement/Embedding.lean)
- [KindValues.lean](../../../formal/Benitoite/Release/Refinement/KindValues.lean)
- [LocalTransport.lean](../../../formal/Benitoite/Release/Refinement/LocalTransport.lean)
- [MethodArguments.lean](../../../formal/Benitoite/Release/Refinement/MethodArguments.lean)
- [RuntimeMatch.lean](../../../formal/Benitoite/Release/Refinement/RuntimeMatch.lean)
- [RuntimeSyntax.lean](../../../formal/Benitoite/Release/Refinement/RuntimeSyntax.lean)
- [Semantics.lean](../../../formal/Benitoite/Release/Refinement/Semantics.lean)
- [Step.lean](../../../formal/Benitoite/Release/Refinement/Step.lean)
- [StoreTransport.lean](../../../formal/Benitoite/Release/Refinement/StoreTransport.lean)
- [TelArguments.lean](../../../formal/Benitoite/Release/Refinement/TelArguments.lean)
- [TypingDeclared.lean](../../../formal/Benitoite/Release/Refinement/TypingDeclared.lean)
- [ValueInstantiation.lean](../../../formal/Benitoite/Release/Refinement/ValueInstantiation.lean)

### 改造の補助入力・台本・記録

停止時点の記録も今回の起動単位の新規ファイルとして列挙する。r2が最終の検査であり、旧の記録を上書きしていない。

- [02b-values-artifact-inputs.json](../l00b.02/02b-values-artifact-inputs.json)
- [02b-values-axioms-summary.json](../l00b.02/02b-values-axioms-summary.json)
- [02b-values-axioms.lean](../l00b.02/02b-values-axioms.lean)
- [02b-values-build.log](../l00b.02/02b-values-build.log)
- [02b-values-commands.json](../l00b.02/02b-values-commands.json)
- [02b-values-constraint-boundary.lean](../l00b.02/02b-values-constraint-boundary.lean)
- [02b-values-constraint-boundary.log](../l00b.02/02b-values-constraint-boundary.log)
- [02b-values-contract.md](../l00b.02/02b-values-contract.md)
- [02b-values-delivery.json](../l00b.02/02b-values-delivery.json)
- [02b-values-inputs-final.json](../l00b.02/02b-values-inputs-final.json)
- [02b-values-kind-boundary.log](../l00b.02/02b-values-kind-boundary.log)
- [02b-values-lean-version.log](../l00b.02/02b-values-lean-version.log)
- [02b-values-previous-boundary.log](../l00b.02/02b-values-previous-boundary.log)
- [02b-values-production.patch](../l00b.02/02b-values-production.patch)
- [02b-values-r2-artifact-inputs.json](../l00b.02/02b-values-r2-artifact-inputs.json)
- [02b-values-r2-axioms-summary.json](../l00b.02/02b-values-r2-axioms-summary.json)
- [02b-values-r2-axioms.lean](../l00b.02/02b-values-r2-axioms.lean)
- [02b-values-r2-build.log](../l00b.02/02b-values-r2-build.log)
- [02b-values-r2-commands.json](../l00b.02/02b-values-r2-commands.json)
- [02b-values-r2-constraint-boundary.lean](../l00b.02/02b-values-r2-constraint-boundary.lean)
- [02b-values-r2-constraint-boundary.log](../l00b.02/02b-values-r2-constraint-boundary.log)
- [02b-values-r2-delivery.json](../l00b.02/02b-values-r2-delivery.json)
- [02b-values-r2-inputs-final.json](../l00b.02/02b-values-r2-inputs-final.json)
- [02b-values-r2-kind-boundary.log](../l00b.02/02b-values-r2-kind-boundary.log)
- [02b-values-r2-lean-version.log](../l00b.02/02b-values-r2-lean-version.log)
- [02b-values-r2-previous-boundary.log](../l00b.02/02b-values-r2-previous-boundary.log)
- [02b-values-r2-public-api.md](../l00b.02/02b-values-r2-public-api.md)
- [02b-values-r2-source-changes.json](../l00b.02/02b-values-r2-source-changes.json)
- [02b-values-r2-step-coverage.json](../l00b.02/02b-values-r2-step-coverage.json)
- [02b-values-r2-validate.py](../l00b.02/02b-values-r2-validate.py)
- [02b-values-r2-validation.json](../l00b.02/02b-values-r2-validation.json)
- [02b-values-source-changes.json](../l00b.02/02b-values-source-changes.json)
- [02b-values-validate.py](../l00b.02/02b-values-validate.py)
- [02b-values-validation.json](../l00b.02/02b-values-validation.json)
- [本レビュー依頼 RV-L00b.02b-values-request.md](RV-L00b.02b-values-request.md)

## 変更した既存ファイル

- [formal/Benitoite/Release/Refinement/Narrowing.lean](../../../formal/Benitoite/Release/Refinement/Narrowing.lean)
- [formal/Benitoite/Release/Refinement/NarrowingObstruction.lean](../../../formal/Benitoite/Release/Refinement/NarrowingObstruction.lean)
- [formal/Benitoite/Release/Refinement/Subst.lean](../../../formal/Benitoite/Release/Refinement/Subst.lean)
- [formal/Benitoite/Release/Refinement/SubstTyping.lean](../../../formal/Benitoite/Release/Refinement/SubstTyping.lean)
- [formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean](../../../formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean)
- [formal/Benitoite/Release/Refinement/Syntax.lean](../../../formal/Benitoite/Release/Refinement/Syntax.lean)
- [formal/Benitoite/Release/Refinement/TypedFacts.lean](../../../formal/Benitoite/Release/Refinement/TypedFacts.lean)
- [formal/Benitoite/Release/Refinement/Typing.lean](../../../formal/Benitoite/Release/Refinement/Typing.lean)
- [formal/Benitoite/Release/Refinement/TypingShift.lean](../../../formal/Benitoite/Release/Refinement/TypingShift.lean)
- [formal/Benitoite/Release/Refinement/ValueBinding.lean](../../../formal/Benitoite/Release/Refinement/ValueBinding.lean)
- [formal/Benitoite.lean](../../../formal/Benitoite.lean)
- [l00b.02/signatures.md](../l00b.02/signatures.md)
- [l00b.02/results.md](../l00b.02/results.md)
- [l00b.02/large-records.md](../l00b.02/large-records.md)

## 残る義務と受け渡し

今回受け持つ値・計算の追加と34場合の未完了はない。モデルの案Aの充足はL50（三モデル）・L60/L70（接続）・.15（信頼条件の比較）へ記録した。外部の群はVal19/Comp13/Step68を起点に5導出を追加し、今回のTel.argumentsの交換を使ってもTelArgsの相互補題を省かない。At・handlers・closures・.03・.11・.13等の既定の残る義務はresults/signaturesに記した。

独立レビューと作業末のworkは取りまとめ、受け入れは設計者の担当である。担当は外部の群を起動していない。
