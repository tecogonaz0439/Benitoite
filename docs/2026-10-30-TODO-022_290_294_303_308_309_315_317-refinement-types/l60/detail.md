# L60 外部呼出しの葉の起動単位（下書き）

2026-11-05。計画担当による下書きである。[共通依頼文](../implementation-request.md)、[plan](../plan.md)、[decisions](../decisions.md)と、受け入れ済みの L20〜L50 の結果を読んで作成した。独立レビュー[RV-L60-plan](../reviews/RV-L60-plan.md)の所見を再開1で反映した。実装の開始、修正版の独立レビュー済み、段末の受け入れを意味しない。今回の作成・短い試行の記録は [results](results.md) に置く。

## 1. 基準と起動条件

| 項目 | 固定値と状態 |
|---|---|
| ブランチ | `m014/l60-plan`。依頼で指定された値。切替・作成・コミットも、状態を調べる git コマンドも実行していない |
| B_WORK | `4998e26854eec6be3d5cb9efd4acde54a2603d44`。今回の文書の基準。実装の各群には、取りまとめが直前の取り込みの完全 ID を改めて渡す |
| 段の枠 | 所要時間（能動時間）17〜41時間、中心29時間。主定理の3〜7時間は L70 に移動済みで、本段へ戻さない |
| 前段の受け入れ | L20・L30 は2026-11-03、L40 は2026-11-04、L50 は2026-11-05に設計者が受け入れた。README「設計者の決定」と plan の最新追記を正とし、古い資料冒頭の「受け入れ待ち」へ戻さない |
| L50 の最後の検査 | stage-results 末尾と l/results の最終 work は終了0、478.36秒、最大常駐量2,938,339,328バイト。これは L50 の記録であり、本下書きのビルド成功の証拠ではない |
| 勧告 | 2026-10-30 の二lock・四ツールの照合と「組み込まない」を継承。新しい更新を相乗りしない。計画の詳細化だけなので再照合しない |
| 起動前に残ること | 取りまとめによる plan の L60 行への反映と修正版の再レビュー。J60-1=B・J60-2=F06・J60-3=(a)は再開1の指示で決定済み。群Aはこの判断の下で実署名と台帳を固定する |
| U02/U05 | U02の公開 PathBases・At・ScopeError・安全な入口の名前と字面は未決のまま保つ。L70前の別作業で写す。U05の交換版・readerの切替はL70/R50/R60。L60の内部名を公開形へ先取りしない |

L60は外部の宣言・応答・通常資源・実表の**葉と充足**を閉じる。進行・保存・step_sound・effect_soundness/noLamNames、対象の一段・到達・表層、性質1、全表層checker・交換の切替はL70の所有である。R段はL70の既定ビルド・A-L・独立合成レビュー・F-REGの後に始める。L60の成功をRust/Lean全比較やABI全体の証明と呼ばない。

### 1.1 既済み分として差し引く18項目

以下のパスの先頭は `formal/Benitoite/Release/Refinement/`、Lean名の先頭は `Benitoite.Release.Refinement.` である。元定義と証明を読み、必要な入口の一部は短いLean入力でも型を確認した。既済みの言明の再証明を作業単位にしない。別のP/Bへ移す接続は、既済み分に含めない。

| 控除 | ファイルと実定義・実補題 | L60に残ること |
|---|---|---|
| C01 | ScopeSyntax/Types/Syntax：`ExternalId`、`ComponentId`、`ExternalFunctionId`、`Ty.external`、`ExternalKey`、`ExternalDecl`、`ExternalTypeDecl`、`ExternalHandle` | 専用IDと有限表の全読者を同じ宣言へ接続。構成子を作り直さない |
| C02 | Syntax/External：`Program.externalType`、`Program.externalFunction`、`Program.ExternalWF`、`type_lookup`、`function_lookup` | 未知・重複・鍵と宣言の不一致の境界と、同一ID/異なるIDの対照 |
| C03 | External：`ExternalValueType`、`ExternalOccurrence`、`ExternalUseAt`、`ExternalTelWF`、`ExternalSignature.WF`、`ExternalCallAdmissible.types_nil/map` | borrow/own/Stateと同一component/resourceを実宣言から供給。有限の同名入れ子を排除しない |
| C04 | Typing：`V_ExternalRef`、`V_ExternalHandle`、`C_External`、`C_Use`。Source/SourceScopeのexternal各枝 | 新しい型規則を追加しない。実表と表層の葉への入力を構成 |
| C05 | Subst/ValueShiftSyntax/TypeShiftSyntax/TypeSubstTyping/ValueBinding/RangeSubstのexternal枝、ValueBindingの`Ty.bind_external`、`type_subst_all`ほかL20の14判断の移送 | IDを保持する既存の変換を使い、名目性の系と読者を接続。相互置換を再実装しない |
| C06 | CanonicalValues：`inv_externalRef`、`inv_externalHandle`、`canonical_external`（同じハンドルから宣言を取り出す無名例もある） | 芯とfactsの実署名を維持。元型全体のLeQを返す撤回済みの形に戻さない |
| C07 | ExternalCheck：`ExternalCarrier`三族、`ExternalPredicates`三族、`accepted`、`checked_typed`、`adequate` | 受信検査の全入れ子と正常/拒否の実例。carrierを篩の真の信頼へ変えない |
| C08 | ExternalResponse：`ExternalArgs`、`ExternalAssumptions`三欄、`checked_typed`、`externalReceive` | 三モデルの同じ応答関係で三欄を実証 |
| C09 | ExternalConnection：`receive`、`external_adequate`、`received_value`、`receive_no_exit`、`Step.external_accept/external_reject` | 全有効σの適格性をこの導出から読む。第四の信頼条件を足さない |
| C10 | Semantics/Step：`E_ExternalApply/E_External/E_ExternalErr`と実行関数のexternal三枝 | 応答の選択と計算→関係の局所入口。Stepの新構成子を足さない |
| C11 | ExternalStateLeaves：`ClosureTy.external_view_typed/external_view_inputs`、`StateTyE.external_apply_all/external_value_all/external_error_all` | 元StateTyEからExternalArgsと存在を供給。全保存への合成はL70 |
| C12 | LeafInputs/TelApplication：`StateTyE.externalRef_contract_inputs`、`TelClosure.apply` | 元列AnnotationとCtx.WFを供給。除去済みの四前提を復活させない |
| C13 | HandlerGeneral/ContinuationGeneral/StepLeafSelection：`error_release`、release/dropの全葉、`ContTy.release_response_exists`、`selected_release`、`step_release_selected` | 通常資源の実際の関係と存在。既存のerror/exit/escape経路を再作成しない |
| C14 | ScopeResponse/ScopedIOResponse/ScopeValueDelta/RequestValueDelta：純粋6行とIO7行の全入力の応答、型、非exit、適格性、存在 | 同じδ/IOを全実表へ組み込む。関数・節の全到達はL70 |
| C15 | Model/ModelTargets/ModelHttpConditions/ScopeModels：`scopeConditions`、`ScopeModels.conditions`の25×3=75欄 | 新しい外部/解放関係を持つ同じ表への移送と12欄。75欄は実質69・空疎6（Model） |
| C16 | TargetModelConditions：`ModelScopeConditions.core`。ConstraintAssumptionsの既存全28欄、別構造体`TargetAgreement`1欄 | 28+1欄の出力を構成。主定理への新しい仮定にしない |
| C17 | L40の各`response`、`StandardOperatorResponse.response`34行、`StandardStructuralEqualityResponse.response`2行、`StandardCollectionRefinedBodies.program_typed/response_assumptions` | 任意P/Bの入口から一つの表へ合成。具体の小表専用の`table_response`は流用しない |
| C18 | CurrentSignatureRows/ScopeSignatures、L50の8制約保存則、`TargetTable.content_rows`、`AtPrepared.request`、`Val.reqTarget_kind`、`checkAt.absolute` | 残りの標準表のsourceTelRows/operationKinds/kindと同じ有限Pを確認。三つのAt補題と非対象13sortは再実装しない |

C16の数は、Substitution8＋External3＋Response4＋独自13＝Core28、TargetAgreement1を別に足して29である。L50の25欄はCoreの24欄＋TargetAgreement1であり、Core単独で25欄ではない。

## 2. 規則・構成子・葉の一覧と場合の数

場合の数は構成子・入力・表の行・義務の母集団ごとに数える。有限列の長さ・NatのID・引数数は記号と帰納で扱い、大きな具体値を評価しない。

### 2.1 外部の宣言と受信

| 母集団 | 全場合と数 | 補題・受け持つ単位 |
|---|---|---|
| 宣言の鍵と値 | ExternalKey 2種×ExternalDecl 2種=4対。正しいtype/type・function/functionの2、種違いの拒否2 | C02、F02、.06 |
| 専用ID | ExternalId/ExternalFunctionId/ComponentIdの3種。別名の同ID、別宣言の異ID、未知、重複、差替え、不正型引数の6境界。表示名を等号に使わない | F02、.06〜.07 |
| 受渡し型 | `ExternalValueType`9規則：scalar/unit/bytes/handle/list/map/flags/data/refined。scalarは13基本型。Bool添字はUnitを許す位置（結果でtrue）を表す。unit規則はtrueにだけあるため、9規則×2添字の18を場合の数にしない | C03/C07、F03、.07〜.09 |
| 名目型の全構文位置 | `Ty`の21構成子を構造帰納：external本体1、篩・List・Map・Set・Fn・dependentFn・data・Reference・Lazy・dict・tapp・cont等の再帰位置、残る葉を全列挙。F02の全変換でIDを保つ。型/行/範囲/値の置換のexternal枝も照合し、既存の定義の枝と`Ty.bind_external`を控除する | C05、F02、.07。全21の名前は直後に列挙する |
| 外部型の出現 | `ExternalOccurrence`6規則：root/element/key/value/field/refined。path stepはelement/key/value/fieldの4種。keyの1枝は構文の母集団に数えるが、適格な外部Mapの鍵ではExternalMapKeyが外部型を許さないため到達しない | F03、.08 |
| 使用位置と所有 | `ExternalUseAt`3規則：argument/next/result。argumentはborrow、resultはown。modeは2種、positionも2種で4対、許す組はargument/borrowとresult/ownの2対。uses_exactとuses_uniqueを両方読む | F03、.08 |
| 署名 | `ExternalTelWF`2規則：done/param。`ExternalSignature.WF`8欄。uses=[]ならempty、uses≠[]ならStateの2枝。monomorphic・kinds=[]・sourceTelRowsを維持 | F03、.08〜.09 |
| 値/計算の直接規則 | V_ExternalRef/V_ExternalHandle/C_Externalの3規則。包むV_Sub/V_Normal/V_RefineとC_Sub/C_Normal/C_Effの6規則は既存帰納で処理済み | C04〜C06、F02/F08、.07/.16〜.18 |
| carrier | ExternalCarrier8＋Each2＋Fields2=12構成子。scalar/bytes/handle/list/map/set/data/refinedと二つのnil/cons | C07、F04、.10〜.11 |
| 篩の受信条件 | ExternalPredicates8＋Each2＋Fields2=12構成子。carrierとは別の12。全入れ子のmap鍵/data欄を含む | C07、.10〜.11。定義と一般健全性は控除 |
| 生の応答 | valの検査成功、valの検査失敗、err、exitの4葉。exitはexternal_typedの非exitから排除。instantiate=noneは適格なExternalArgsから排除 | F04/F05、.10〜.15 |
| 外部遷移 | E_ExternalApply/E_External/E_ExternalErrの3葉。実行関数のlookup none・receive none/exitは型付き開始から排除する枝 | C10/C11、F05、.14〜.15 |
| 外部IO対象 | `obs=[]`を全応答で結論する1条件。Stateの追跡とは別。外部が実体や副通信を持たないという意味にしない | F04、.10/.12〜.15 |

Types.leanで読んだTyの全21構成子は、base/opaque/data/list/fn/tvar/reference/lazy/cont/map/set/bytes/dict/tapp/ctor/refined/dependentFn/external/scoped/pathBases/scopePatternである。新しい帰納を要求する場合の本確定の母集団は次の76枝である。既存の相互置換の作り直しを計上したものではない。

### 2.2 表を差し替える際にだけ要る移送

外部応答欄を足したBは、sig等が等しくても元Bと定義上同じ値ではない。型付き入力を旧Bで受け、結論だけ新Bと書く誤りを避ける。F01の七射影の一致による型付けの移送を使う。これは型・文脈の置換の相互帰納を変更せず、一度だけ別の補題として置く。

| 判断 | 構成子数 | 全構成子 | 単位 |
|---|---:|---|---|
| HasTypeVQ | 29 | V_Var/Const/Lam/DependentLam/Closure/Fun/Prim/Op/ExternalRef/ExternalHandle/PathBases/ScopePattern/Checked/CheckedRequest/CheckedAt/AtError/Map/Set/Dict/Raise/LocRef/LocLazy/Bytes/Con/Super/List/Sub/Normal/Refine | .02で骨格、.05で全枝 |
| HasTypeVsQ | 2 | nil/cons | .05 |
| HasTypeEachQ | 2 | nil/cons | .05 |
| HasTypeCQ | 24 | C_BuilderLet/BuilderOp/Return/Let/App/DependentApp/If/Match/Lazy/Escape/Use/Handle/Handle_Fail/Resume/ResumeL/ResumeNorm/ResumeLNorm/Normal/Meth/External/IssuePathBases/CheckAt/Sub/Eff | .05 |
| HasTypeTelArgsQ | 2 | done/param | .05 |
| TelBodyTy | 2 | done/param | .05 |
| CaptureOk | 1 | mk | .05 |
| DependentClosureTy | 1 | mk | .05 |
| CheckedWitness | 2 | plain/request | .05 |
| AtCallAdmissible | 1 | mk | .05 |
| HasTypeArmsQ | 3 | nil/plain/guarded | .05 |
| HasTypeClausesQ | 2 | nil/cons | .05 |
| HasFailureClause | 1 | one | .05 |
| ImageOk | 4 | ordinary/hidden/contLoc/contVar | .05 |
| 合計 | 76 | 14判断。新しい規則の追加0、既存の移送の変更0を既定とする | F01 |

carrierの12枝、BuiltinArgsの9欄、ExternalArgsの6欄、ModelScopeConditionsの25欄の移送をこの76へ混ぜない。ModelScopeConditions移送は七射影に加えδ/IO/refGet/refSet/effKindの一致を使う。外部応答・releaseだけを変える構成なら全てrflで供給できる。同じ補題を任意の標準表の和へ無条件に適用しない。

### 2.3 通常資源と表層の葉

| 母集団 | 一覧と数 | 単位・完了の判定 |
|---|---|---|
| 通常資源の分類 | Rust `runtime::ResourceKind`のFileReader/FileWriter/HttpListener/HttpExchange/TaskGroupの5種。ModelTargetsのFile.Handleは一つの模型の名前であり、この5種の実署名の代わりにしない | .03/.19/.21。抽象解放は有限な名前表とopaque値で表し、外部ハンドルを混ぜない |
| 解放の遷移 | E_Release/E_RelErr、E_EscRel/E_EscRelErr、E_ErrRel/E_ErrRelErr、E_ExitRel/E_ExitRelErrの8葉 | C13を使う.20。成功・失敗の2結果×通常/escape/error/exitの4開始 |
| 解放枠への入口 | E_Useの1葉。継続破棄のreleases/dropは既存HandlerGeneral/ContinuationGeneralを継承 | .20。8葉と合わせて9だが外部3葉とは別の母集団 |
| 表層・脱糖の外部固有部分 | 型のID参照、外部名の参照、直接の飽和呼出し、名前付き引数の呼出し、穴を持つ部分適用の5接続 | F08、.16〜.18。子の評価・並べ替え・穴の一般則はL70、外部表/同じ結果・Stateへの葉はL60 |
| 偽造を断る境界 | externalHandleのソース直接構築、表現パターン、JSONからの型/値偽造の3分類 | .09/.18/.33。SourceのFalseと現行表層/変換器の拒否は別。実CLIはR50/V10 |

既存SurfaceはReleaseのTy/Programを読み、外部ID/外部呼出しの構成子を持たない（Surface/Syntax・CheckTables）。従って「旧の表層checkerが既にexternalを扱う」とはしない。F08の外部固有の五つの接点をL60で固定し、その葉を読む新しい全表層・全交換への組込みはL70で行う。名前付き引数を一度だけ評価すること、部分適用の非穴式を生成ラムダの呼出しごとに評価することは共通依頼文の契約を保つ。

### 2.4 三モデルの12欄

J60-1=Bにより、F04の外部応答を付けた表を別名で定義し、F01で同じ七射影を持つ25欄を移す。ここでの「Modelの4欄」はその対応する拡張表の欄であり、空の旧`Model.builtins.externalResponse`についてexternal_existsを主張するものではない。対応する旧表・新表の完全名を群Aで固定し、実表と証拠の取り違えを防ぐ（J60-1）。

欄の分類は、同じP/Bでの前提と結論を調べて次の順で判定する。

| 分類 | 定義と判定の方法 |
|---|---|
| 不成立 | 適格な入力で前提が成り立ち、結論が成り立たない反例がある。証明未完だけではこの分類にしない |
| 空疎 | 全称欄の前提からFalseを導ける。その導出を保存する |
| 自明 | 充足可能な前提に依存せず、定数の証人等で結論が閉じる。定数errの存在証明や、どのvでも`⟨none, rfl⟩`で閉じる関係を含む |
| 実質 | 前記に当たらず、前提の充足可能な入力があり、入力の型・形又は応答の証拠を使って結論を示す |

Falseの導出が見つからないだけでは実質としない。前提の否定、結論の自明さ、到達する入力の証拠を欄ごとに照合する。未確認は分類を確定せず残す。.11の正常応答・篩拒否の証拠は関係がerrだけに退化していないことを示す別の証拠であり、存在欄の分類を実質へ変えない。

| 番号 | モデル | 欄 | 現在の状態 | L60の出力・単位 |
|---|---|---|---|---|
| M01 | Model | external_typed | 空関係なので空疎 | 同じ拡張表のcarrier/非exit、.12 |
| M02 | Model | external_exists | 適格な外部呼出しを持つPでは不成立 | 自明：Pを狭めず定数errの証人を全入力へ、.12 |
| M03 | Model | external_no_targets | 空関係なので空疎 | 正常/errを含む同じ関係のobs=[]、.12 |
| M04 | Model | release_exists | isResource=falseなので空疎 | 空疎と明記して継承。実質の解放の証拠に数えない、.19/.22 |
| M05 | ModelTargets | external_typed | 空関係なので空疎 | 同じ拡張表のcarrier/非exit、.13 |
| M06 | ModelTargets | external_exists | 適格な外部呼出しを持つPでは不成立 | 自明：全入力に定数errの証人、.13 |
| M07 | ModelTargets | external_no_targets | 空関係なので空疎 | 正常/errを含む同じ関係のobs=[]、.13 |
| M08 | ModelTargets | release_exists | r=noneで結論自明。前提は充足可能 | .19で通常資源の関係を入れ、その関係で存在を示す。全てのvへのnoneで代用しない |
| M09 | ModelHttp | external_typed | 空関係なので空疎 | 同じ拡張表のcarrier/非exit、.13 |
| M10 | ModelHttp | external_exists | 適格な外部呼出しを持つPでは不成立 | 自明：全入力に定数errの証人、.13 |
| M11 | ModelHttp | external_no_targets | 空関係なので空疎 | 正常/errを含む同じ関係のobs=[]、.13 |
| M12 | ModelHttp | release_exists | isResource=falseなので空疎 | 空疎と明記して継承、.19/.22 |

入口は空疎8・自明1・不成立3の12欄である。目標は**実質7・自明3・空疎2**とする。外部のtyped/no_targetsの6欄とTargetsの解放1欄が実質、external_existsの3欄が自明、Model/Httpのrelease_existsの2欄が空疎である。Targetsの解放は型付き値からcanonicalで資源値の形を得る必要があり、全値にnoneを許す旧関係とは判定が異なる。

L50の75欄は実質69・空疎6を継承する。3×29=87欄の参考内訳は**実質76・自明3・空疎8**である。Modelのpure/io/exit不在の6欄を実質へ変えず、実装時に上の判定法で全欄を照合する。

### 2.5 証拠を合成する行と仮定の側に残す登録

[登録の表・Lean側から固定する既存証拠・照合条件](tables.md)へ分けた。L60.04は同書のE01〜E15（出典別の延べ552行）と三モデル75欄を閉じた入力として台帳を作り、Rust名・Lean名・証拠の完全名を記録する。L60.29は全既存証拠から合成行への対応と、仮定側の証拠名0件を、台帳とlookupの双方向の照合とは別に確認する。

## 3. 先に固定する定義と完全署名の形

本節の新名は案である。名前の先頭は`Benitoite.Release.Refinement`。`ErrKind`・`OpaqueName`・`Qempty`はReleaseの定義を読む。既存の型の署名は変えない。新しい補助の名前・配置だけを群Aで固定し、定理として実装する前に型の全引数をLeanへ読ませる。省略した証明をsorryで埋めて型検査成功と数えない。

### F01: 表の実行用の欄を変える移送

新規`BuiltinTypingTransport.lean`へ次の形を置く。両向きの一致なので、外部応答・解放だけを変える表に適用できる。

```lean
structure Builtins.TypingFieldsEq (B B' : Builtins) : Prop where
  sig : B.sig = B'.sig
  sat : B.sat = B'.sat
  ranges : B.admitsR = B'.admitsR
  resources : B.isResource = B'.isResource
  kinds : B.valKind = B'.valKind
  content : B.valContent = B'.valContent
  effects : B.effects = B'.effects

theorem HasTypeVQ.of_fields {P B B' Ψ Q C Γ Φ v a}
    (fields : Builtins.TypingFieldsEq B B')
    (typed : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    HasTypeVQ P B' Ψ Q C Γ Φ v a

theorem HasTypeCQ.of_fields {P B B' Ψ Q C Γ Φ R m a ε Δ}
    (fields : Builtins.TypingFieldsEq B B')
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) :
    HasTypeCQ P B' Ψ Q C Γ Φ R m a ε Δ
```

同じ定理を第2.2節の全14判断で相互に証明する。各判断の添字は元の判断から一つも落とさず、BだけをB'にする。結果は`typing_transport_all`として14成分の連言、又は各射影が同じ相互証明を読む14定理にする。Bに関する新条件を判断の定義へ加えない。76枝の全名を一覧にし、どの七射影を読むかを各枝へ書く。C_Handleの`handled`はHandlerContractsの`effOps`を通じてB.effectsを読むため、effectsの一致を含める。C_UseはisResource、ConstOKはvalKind/valContentを読む。外部応答・releaseだけを変える`{base with …}`では七欄ともrflで供給できる。

`ExternalArgs.of_fields`、`BuiltinArgs.of_fields`、`ExternalCarrier.of_fields`三族、`Outcome.Typed.of_fields`と`Outcome.Carrier.of_fields`は、同じfieldsと元の証拠からB'の証拠を返す。`ModelScopeConditions.of_responses`は、fieldsに加えて`B.delta=B'.delta`・`B.ioResponse=B'.ioResponse`・`B.refGet=B'.refGet`・`B.refSet=B'.refSet`・`B.effKind=B'.effKind`を受け、25欄をB'へ移す。release/externalの関係の等号は要求しない。これは**同じP**での移送であり、標準の小さいPを大きいPへ移す定理ではない。

### F02: 名目IDの保持

新規`ExternalNominal.lean`。IDに関する結論の共通形は次である。

```lean
def ExternalNominal.Preserves (transform : Ty → Ty) : Prop :=
  ∀ (id : ExternalId) (args : List Ty),
    ∃ resultArgs, (transform (.external id args)).core = .external id resultArgs
```

対象はexternalの枝を持つ全変換とする。直接の枝はNormalizeの`Ty.norm`、Finiteの`Ty.normWith`、ValueShiftSyntaxの`Ty.shiftV`、RangeSubstの`Ty.rawMapRanges`、TypeRenamingの`Ty.rawRenameTypes`、Contextの`Ty.rawBind`、Substの`shiftTypes`、ValueExchangeの`Ty.rawSubstV`、ValueRenamingSyntaxの`Ty.renameValues`、Carrierの`Ty.carrier`である。各枝は同じIDと変換後の引数列を返す。これらを包む`Ty.bind/renameTypes/mapRanges/substRAt/instR/shiftR`、型/行代入`Ty.subst/shift`も定義から追う。ObservationTypeの`Ty.observationType`は引数を空にする観測専用の変換としてID保持だけを照合する。

`Ty.bind_external`は既存の証明を使い、残りのPreservesも定義の枝で閉じる見込みである。新しい全21枝の帰納証明は作らず、入れ子の読者へつなぐ箇所を.07に残す。さらに`inv_externalHandle`の実結論から`td.component=h.component`・`td.resource=h.resource`・arityの一致を取り出す。異なるIDの二つの`.external`が正規形等号で一致しないことと、未知IDでは`Ty.Declared`/V_ExternalHandleの前提を供給できないことを別々に記す。外部型をopaque/Unit/Topへ忘却する規則を足さない。

### F03: 署名のusesとState

新規`ExternalSignatureLeaves.lean`。先に次の全称の形を固定する。

```lean
theorem ExternalUseAt.mode {P n tel use}
    (h : ExternalUseAt P n tel use) :
    (∀ i, use.position = .argument i → use.mode = .borrow) ∧
    (use.position = .result → use.mode = .own)
```

Stateの言明は既存`ExternalSignature.WF.shape`の射影を直接使い、同じ命題の別名の補題は作らない。これを使う名前付きの実宣言の読者を.08で作る。usesに重複がない、出現の過不足がない、引数borrow/結果own、型と行のパラメータが空、同じcomponent/resourceという入力の供給を一行ずつ照合する。StateはIOの操作でなく、外部ハンドルは通常資源でない。

### F04: 生の外部応答とモデルの拡張

新規`ExternalModelResponse.lean`。Pを制限せず、既存のcarrierの条件を満たす正常応答とerrを許す抽象関係である（J60-1=B）。受信前の篩の真を要求しない。精密な外部状態・ABI・ゲスト所有のヒープは加えない。

```lean
def ExternalModel.response (P : Program) (base : Builtins)
    (f : ExternalFunctionId) (ts : List Ty) (vs : List Val)
    (out : Outcome) (obs : List Benitoite.Scope.Domain.Target) : Prop :=
  obs = [] ∧ ∀ Ψ d a e,
    P.externalFunction f = some d → ExternalArgs P base Ψ d ts vs a e →
    Outcome.Carrier P base Ψ out a ∧ (∀ n : Int, out ≠ .exit n)

def ExternalModel.builtins (P : Program) (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) : Builtins :=
  { base with externalResponse := ExternalModel.response P base,
              releaseResponse := release }
```

`response_err P base f ts vs r`は任意のerrについて関係を満たす。`response_exists P base f ts vs`はその証人から導く（全入力での存在）。`external_assumptions (P) (base) (release)`は、F01でExternalArgsを元baseへ戻し、Outcome.Carrierを拡張表へ移して、**拡張表の**ExternalAssumptionsを返す。全称のcarrier条件を定義に書けることと、正常応答が実際に許されることは別に検査する。Unit・整数の篩の合格/不合格・入れ子List/data/map鍵・handleの正常応答を、適格な有限宣言と同じ拡張表の下で示す。

この関係は採択した抽象モデルであり、実ゲストが宣言のcarrierへ正しく変換されることを証明するものではない。群Aで上の全称形と接続の完全署名を固定し、新公理・未検査の意味の欄は作らない。全称形のerr存在・射影不変は短い試行で確認したが、F01を通じた全三条件・全正常形・75欄の移送は未確認である。

モデルの三条件の共通の出力と選択の署名は次である。

```lean
theorem ExternalModel.external_assumptions (P : Program) (base : Builtins)
    (release : Val → Option Benitoite.Release.ErrKind → Prop) :
    Builtins.ExternalAssumptions P (ExternalModel.builtins P base release)

noncomputable def Builtins.selectExternal (B : Builtins) : ExternalOracle

theorem Builtins.selectExternal_response {B f ts ws}
    (h : ∃ out obs, B.externalResponse f ts ws out obs) :
    B.externalResponse f ts ws (B.selectExternal f ts ws).1
      (B.selectExternal f ts ws).2
```

三表は`ExternalModels.model P`、`ExternalModels.targets P`、`ExternalModels.http P`とする案で、baseにそれぞれ現行のModel/Targets/Http.builtinsを渡す。HasFile/HasHttpは既存と同じ宣言条件であり、外部宣言を持たないという制限を足さない。旧`builtins`と`scopeConditions`は残し、意味を変えず、拡張表の型に旧の証拠を直接当てない。

### F05: 型付き開始から応答・選択へ

新規`ExternalLeafSelection.lean`。存在を使う局所の接続は次の形で、主定理の閉鎖ではない。

```lean
theorem StateTyE.external_response_step {P B σ Eb q f ts ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B)
    (hB : Builtins.CoreAssumptions P B)
    (state : StateTyE P B σ Eb (.run q k μ))
    (view : q.view = .externalCall f ts ws) :
    ∃ out obs dest,
      B.externalResponse f ts ws out obs ∧ obs = [] ∧
      Step P B σ (.run q k μ) none dest ∧ StateTyE P B σ Eb dest
```

元StateTyEの同じΨから`ClosureTy.external_view_inputs`と形成・Groundを使ってExternalArgsを得る。hB.external_existsから生応答を選び、`receive/receive_no_exit/received_value`とC11へ進む。正常応答を選べるという前提を足さない。

F04の`selectExternal`は証人があればClassical.chooseし、なければerrと空観測を返す。`selectExternal_response`は証人がある場合だけ同じ関係への所属を結論する。`step_external_selected`はhP/hPB/hB/state/viewと同じ選択を受け、`step P B σ oracle B.selectExternal rel fresh`の結果と同じ`Step`・`StateTyE`を結論する。既存のstepの入力と量化を変えない。逆方向の完全性は証明しない。

### F06: 通常資源の解放

新規`ResourceReleaseModel.lean`。短い試行で型を確認し、J60-2で採択した関係は次である。

```lean
def ResourceRelease.response (isResource : Benitoite.Release.OpaqueName → Bool)
    (v : Val) (_r : Option Benitoite.Release.ErrKind) : Prop :=
  ∃ o i, v = .const (.opaque o i) ∧ isResource o = true
```

これは資源値ごとに成功と失敗の両方を許す抽象関係であり、全値にnoneを返す関係より対象を限定する。OS資源の開閉状態や失敗理由を計算するモデルではない。精密な開閉状態が必要なら停止条件へ戻す。型付き資源のcanonicalを`B.isResource o=true → B.valKind o=none`という**実表から証明する分類**と既存の逆転から得る。分類をCoreの新前提にしない。任意Ψ/v/oを量化したrelease_existsを返し、Ground/Adequateの前提を加えない。外部ハンドルとPathIn/RequestInをこのopaque資源値へ変換しない。

Model/HttpのisResource=falseによる2欄は空疎と記録する。TargetsではFile.Handleの型付きopaque値を構成し、r=noneとr=some reasonの双方が同じ新関係に属すること、その値以外（整数・externalHandle等）は関係に属さないことを確認する。合成表では既存証拠を持つFile.Handle等の署名・名前から同じ分類を供給する。Rustの5種との名前の対応は台帳に残し、証拠のない資源の新しい状態・解放モデルは作らない。

### F07: 全実表の合成の出力

新規`StandardModelDeclarations.lean`・`StandardModelSignatures.lean`・`StandardModelResponse.lean`・`StandardModelCore.lean`へ分ける。既存の標準の本体・δの算法は移動しない。出力の形は次である。

```lean
-- 固定表は.04の台帳のうち、既存Lean証拠を持つ行から作る。
def StandardModel.program (externals : List (ExternalKey × ExternalDecl)) : Program
def StandardModel.builtins (P : Program) : Builtins

theorem StandardModel.core (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    Builtins.CoreAssumptions (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))

theorem StandardModel.targets (externals : List (ExternalKey × ExternalDecl)) :
    Builtins.TargetAgreement (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))
```

定義の形を示す宣言で、証明を省略したLean入力として実行するものではない。programは合成対象の固定有限宣言とcore本体を同じ表へ収集し、外部宣言だけを引数にする。coreが受けるhwは既存Program.ExternalWFであり、新しい意味上の仮定ではない。外部関数を含む非空externalsの具体Pについてhwと全表の証拠を構成する。

群Aで、P/B固定の本体は**合成表の上で証明し直す**方針を固定する。F01は同じP・七射影の等号に限り、部分表から合成表への一般の拡張補題は使わない。型付けは表の拡張で単調でない。handledは効果の全操作に節を要求し、ConstOKはvalKind/valContent、C_UseはisResourceを読むためである。.27はcore84公開行と共有helperの重なりを除き、元の証明の構成を再利用しつつ、全lookupと型付けを合成先のP/Bで閉じ直す。

証明先の完全署名は次とする（定義形であり、証明抜きで型検査成功と数えない）。

```lean
theorem StandardModel.definition_typed
    (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF)
    (f : Benitoite.Release.FunName) (d : Def)
    (lookup : (StandardModel.program externals).defs f = some d) :
    Def.WellTyped (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals)) d

theorem StandardModel.program_typed
    (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    (StandardModel.program externals).WellTyped
      (StandardModel.builtins (StandardModel.program externals))

theorem StandardModel.program_wellFormed
    (externals : List (ExternalKey × ExternalDecl))
    (hw : (StandardModel.program externals).ExternalWF) :
    (StandardModel.program externals).WellFormed
```

群Aは本体が読む名前・data/constructor/arity/kind・sigと、全handled/effOps・ConstOK・isResourceの値を合成表に対して固定する。これらは本体の各枝で証明する副条件であり、旧表との一般の包含や新しい信頼条件として受け取らない。外部宣言の鍵はProgramの専用表にあり、標準のdefs等と混ぜない。合成先の副条件が閉じなければ元の証明を型ごと流用せず、該当枝と不足を報告する。.27の80〜140分にこの再証明を含める。

sig_scoped、sat/admitsの8保存、operationKinds、sourceTelRows、StoreShape、Reference四種のkind=[value]、force、PathBases、合成側の全pure/IO/exit・対象条件を同じ表で構成する。任意P/Bの既存responseには新しい表のBuiltinArgsを渡す。仮定側の名前は台帳としてR50へ渡し、このモデルのCoreを全Rust登録の意味の証明と呼ばない。利用者Pへの収集と全プログラムの切替はL70に残す。

### F08: 外部の宣言表を読む表層・脱糖の葉

新規`ExternalSurfaceLeaves.lean`へ、現行のV_ExternalRef/C_Externalを読む表層の本番の読者を置く。以下は入力供給の契約であり、構成子の単純な別名二本を新規実装件数として加算しない。型の正は次の二つである。

```lean
theorem ExternalSurface.ref_typed {P B Ψ Q C Γ Φ f d ts}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts []) :
    HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts)
      (.dependentFn (instantiatedTel d.parameters ts []))

theorem ExternalSurface.call_typed {P B Ψ Q C Γ Φ R Δ f d ts ws a e}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
      (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ
```

この二つの形は短いLean入力で、V_ExternalRef/C_Externalをそのまま適用して証明した。callの引数は`Tel.bind (typeEnv ts) d.parameters`であり、refの`instantiatedTel`と混同しない。出力Δを含む全添字は現行規則と一致する。型ID参照の葉は`Program.externalType`と`Ty.Declared`、引数名の葉は`d.parameters.names`、穴の葉は`SignatureInstance`/`TelClosure`をそのまま渡す。新しい表層ASTをL60で独立に作らない。五つの接続すべてについて、L70が読む完全な型・結果の篩・State・引数順・評価位置と、一般の脱糖のどの入口へ組み込むかを保存する。外部関数の内部externalRef表現を利用者が第一級の関数値として渡せるという新しい提供範囲に読み替えない（Rust emit/refinterpはその値としての利用を拒否する）。

F08の二つの型自体は確認済みだが、名前付き引数・穴の一般の読者への組込みと、引数の捕捉からの供給は未確認である。必要な変更が内部補助の型の修正だけなら、群Aで修正と根拠を記録する。型付け規則そのもの、書ける形、公開契約の変更なら停止する。

## 4. 作業単位とレビュー・取り込みの群

37単位を9群にまとめる。時間は所要時間（能動時間）で、ビルド・レビュー・回答待ちを除く。群内はまとめて起動し群末に独立レビュー・取り込みを置く。別起動なら各作業末にworkを一度行い、結果を引用して重複を避ける。

ファイルは`formal/Benitoite/Release/Refinement/`からの相対名である。新モジュールは`formal/Benitoite.lean`へimportし、01-12/07-04を同じ変更で写す。実装記録は`l60/<群の英小文字>/`、レビューは改造の`reviews/`へ置く。これは将来の実装の指定であり、本下書きの編集許可ではない。

検査符号はL=局所Lean、S=実署名、N=非空性/受理拒否、D=型と値の定数依存、W=群末work、A=段末A-L。コマンドは第9節へ集める。

| 単位/群 | 目的 | 触るファイル | 完全署名又は定義の形 | 手順と完了条件 | 依存 | 見込み（分） | 検査 |
|---|---|---|---|---|---|---:|---|
| L60.01/A | 前段と全母集団を固定 | 群Aの記録 | C01〜18、第2節、O行の全表 | B_WORKと受け入れを読む。21Ty/14判断76枝/12欄/61部分523参照を再照合。既済みと未照合を混ぜない | L20〜L50受け入れ | 25〜40 | S、静的集計 |
| L60.02/A | 表の差替えと表層の方式を確かめる | BuiltinTypingTransport、ExternalSurfaceLeaves、StandardModelの署名 | F01/F07/F08 | 七射影と14判断を固定。V_Prim/CheckedRequest/C_External/C_Use/C_Handle/CaptureOkを先に実装し、handled/ConstOKも照合。F08二葉の元入力を確認。F07は合成表上の再証明を選び、副条件と完全署名を固定 | .01 | 55〜85 | L/S/N |
| L60.03/A | 通常資源の関係と外部境界を確かめる | ResourceReleaseModel、ExternalModelResponse | F04/F06 | 決定済みのF04/F06の定義、err存在、release成功/失敗を固定。File.Handleのcanonicalと資源分類を確認。精密状態を加えない | .01 | 30〜50 | L/S/N |
| L60.04/A | 証拠と仮定側の名前の台帳を作る | StandardModelDeclarations/Signaturesの定義形、群Aの名前台帳 | F07、第2.5節 | J60-3=(a)に従い[tablesのE01〜E15](tables.md#lean側から固定する既存証拠)の552出典行・三モデル75欄とRust523参照を独立に展開。Rust名・Lean名・証拠の完全名を持つ台帳へ全件対応させ、出典別件数と合成/仮定・理由を固定。重なりと衝突を残して最初の16件を確認。証拠のある名を仮定側へ分類しない | .01/.02 | 35〜60 | S/N/D |
| L60.05/A | 骨格と全型付け移送を閉じる | BuiltinTypingTransport、ExternalModelResponse、StandardModelの署名、既定import、写し | F01/F04/F07の固定署名一式 | 七射影で14判断76枝＋carrier12枝＋Argsを閉じる。F07のdefinition_typed/program_typedの証明先と副条件を固定。本体証拠を任意P/B・lookup等の副条件付き・固定P/Bの三種に分け、出典行の重なりを除いた件数を.27の80〜140分の根拠として記録する。F01〜F08の署名を型検査し、群Aの独立レビュー後にB以降を起動 | .02〜.04、決定済みJ60-1〜3 | 70〜110 | L/S/D、W-A |
| L60.06/B | 宣言の鍵と有限表の拒否 | ExternalNominal | F02、ExternalWF.type_lookup/function_lookup | 4対を照合し、未知・重複・鍵不一致/差替えの失敗と正しい宣言を対応。別名同ID/別宣言異IDを表示名と分離 | A | 30〜45 | L/N |
| L60.07/B | 入れ子と置換の名目性 | ExternalNominal | F02の全変換、Ty.bind_external、inv_externalHandle | externalの枝と既存bind_externalを控除。Map/Data/Fn等の入れ子の読者でID・component/resourceを照合。定義展開の系のみ接続し、相互置換も全21枝の帰納も作り直さない | .06 | 20〜35 | L/N/D |
| L60.08/B | borrow/ownとStateの実署名 | ExternalSignatureLeaves | F03、ExternalUseAt.mode、WF.shape | Occurrence6/UseAt3/TelWF2/WF8欄を実宣言へ接続。uses_exact/uniqueとsourceTelRows、単相/空kind、Stateの二枝を全て読む | .06/.07 | 35〜60 | L/S/N |
| L60.09/B | 外部の拒否境界と写し | ExternalSignatureLeaves、Source読者、写し | C04/F02/F03、SourceのFalse | 外部handle構築・表現パターン・JSONの3境界を分類。純粋外部/State外部・同一/異種component/resourceの受理拒否を対にする。通常資源へ追加しない | .08 | 30〜50 | N/D、W-B |
| L60.10/C | 生応答の全三条件の共通証明 | ExternalModelResponse | F04.external_assumptions | 新BのExternalArgsを元Bへ戻してcarrierを新Bへ移す。val成功/拒否/err/exitの4葉を接続。新しい意味上の仮定を入力にしない | A/B | 35〜60 | L/S |
| L60.11/C | 正常応答と篩拒否の非空性 | ExternalModelExamples | F04の具体有限PとExternalArgs/response/receive | Unit、整数、List、data、map鍵、handleの6正常形と、それぞれの篩拒否がある形を示す。任意深さは帰納。空のP・errだけでは完了にしない | .10/.08 | 40〜75 | L/N/D |
| L60.12/C | Modelの外部3欄 | ExternalModels | F04.model、M01〜M03 | Pは任意、外部宣言なしの制限0。旧scopeConditionsをF01で同じ拡張表へ移す。3欄を束ねる。Modelのpure/IO6欄の空疎を維持 | .10/.11 | 30〜50 | L/S/N |
| L60.13/C | Targets/Httpの外部6欄 | ExternalModels | F04.targets/http、M05〜M07/M09〜M11 | 既存HasFile/HasHttpと同じPで25欄を移送し、外部6欄を構成。13範囲APIのBと混ぜない。Core合成はEへ残す | .12 | 40〜70 | L/S/N/D、W-C |
| L60.14/D | 型付き開始から応答存在を得る | ExternalLeafSelection | F05.external_response_step | 元StateTyEから同じΨ・ExternalArgsを供給し、三条件からchecked応答と既存保存葉へ。Ground/Canonical/Annotationは開始から導く | .10/.13 | 35〜60 | L/S/N |
| L60.15/D | 外部の応答選択とstepを結ぶ | ExternalLeafSelection | F05.selectExternal/response/step_external_selected | 選択した対の関係所属、receive none/exit排除、Step三葉へ。step→Stepだけ。σ/Eb/μを保持 | .14 | 30〜50 | L/N/D |
| L60.16/D | 型IDと外部名の表層の葉 | ExternalSurfaceLeaves | F08.ref_typed、F02のDeclared入口 | 既存の型/名前のlookupから新判断へ。refの型引数・結果の篩・Stateを残す。externalRefを第一級関数の新機能にしない | B、.14 | 30〜50 | L/S/N |
| L60.17/D | 飽和呼出しと名前付き引数 | ExternalSurfaceLeaves、L70への署名表 | F08.call_typed、Tel.bind/typeEnv | 宣言順の引数とソース順の評価を区別し、一般の並べ替えの読者へ全引数を渡す。L70が作る全脱糖とは別に、外部固有の引数順/結果型/Stateの葉を閉じる | .16 | 35〜65 | L/S/N/D |
| L60.18/D | 部分適用・偽造拒否と五葉の収集 | ExternalSurfaceLeaves、写し、L70への署名表 | F08、SignatureInstance/TelClosureの既存署名 | 非穴式の評価位置を既存の意味へ揃え、L70が読む葉の型・量化・供給元を全5接続で固定。欠けを単にL70へ送らない | .17/.09 | 30〜50 | L/S/D、W-D |
| L60.19/E | 資源値と通常の解放関係 | ResourceReleaseModel | F06.response、任意Ψ/v/oのrelease_exists | Targetsの型付きopaque資源をcanonicalから取得。新関係で成功・失敗を示す。Model/Httpの二空疎欄を分ける。全値noneの関係は使わない | A/C | 40〜75 | L/N |
| L60.20/E | 全8解放葉と選択への接続 | ResourceReleaseLeaves | C13の8定理、ContTy.selected_release等 | ret/escape/error/exit×成功/失敗を全件照合し、同じ新関係の存在を選択へ渡す。use/drop/releaseの既存枠の順を維持 | .19 | 35〜60 | L/N/D |
| L60.21/E | 通常資源の台帳とReferenceの形 | StandardModelSignatures、ResourceReleaseLeaves、群Eの対応表 | F06/F07、StoreShape/ref_get/ref_set | Rustの5資源種と外部型を区別し、Lean証拠がある資源だけを合成。残りは名前と仮定側に入る理由を台帳へ。Reference四種kind=[value]・force・sourceTelRows/operationKindsは合成対象を全照合 | .19/.04 | 25〜40 | S/N/D |
| L60.22/E | 三モデルのCoreと対象条件 | ExternalModels/ScopeModelsの新読者、写し | F04/F06、ModelScopeConditions.core | 同じ拡張Bで25+3+1を構成。12欄の実質7/自明3/空疎2と既存75の69/0/6を別列にし、87欄を出力。前提の否定・結論の自明さ・充足可能な入力を欄ごとに照合 | .13/.20/.21 | 30〜50 | L/S/N/D、W-E |
| L60.23/F1 | 合成対象の有限宣言と最初の16接続 | StandardModelDeclarations/Signatures/Response | F07、StandardOperatorResponse.response | 台帳の合成対象だけを一つのP/Bへ配置。最初の16件を本番へ接続。共有のOption/Result/Pair/Request/Errorとkind/arityを供給。仮定側の名にlookupを作らない | A/E | 40〜65 | L/S/N/D |
| L60.24/F1 | 標準の数値の全pure行 | StandardModelResponse | F07、各Scalar/Integer/Conversion/NumericRemaining.response | L40の数値群の既存全証拠を同じBへ接続。別名のcoreとδの重複を除く。parsedは同じbitsから作る。証拠のない公開名の意味は追加しない | .23 | 40〜70 | L/N/D |
| L60.25/F1 | 全107演算子と構造等号 | StandardModelResponse | F07、OperatorResponse.response、StructuralEqualityResponse.response | 先行16を再計上せず残りを合成。%eq/%neの重複を全型の一署名へ。malformed StopのR50申し送りを保持。部分表のtable_responseを使わない | .24 | 40〜70 | L/N/D、W-F1 |
| L60.26/F2 | String/Bytes/List/Map/Setのpure応答 | StandardModelResponse | F07、既存各response、KeyShapeの実供給 | 既存証拠の全純粋行のlength/値域/鍵/構造の契約を同じP/Bへ。篩付き入力と全σのAdequateResultを維持。仮定側の名をこの表へ足さない | .24/.25 | 40〜70 | L/N/D |
| L60.27/F2 | core84行とhelperを合成表で再証明 | StandardModelDeclarations/Response | F07.definition_typed/program_typed、Def.WellTyped | 精密tel7・%Map.replaceValues・getter19・alias51の重なりを除く。元証明の構成を使い、全本体を合成P/Bで閉じ直す。handled/effOps・ConstOK・isResourceと全lookupの副条件を供給。一般の表拡張の単調性は使わない | .26、群Aで固定したF07 | 80〜140 | L/S/N/D |
| L60.28/F2 | 証拠のあるIO/ストア/範囲を合成 | StandardModelSignatures/Response | F07、ScopedIOResponse.response、ScopeResponse.response | 合成対象の9kindを閉じる。純粋6/IO7/発行/Reference/forceと証拠のある通常資源を同じP/Bで読む。新しいIO/資源の意味を定義せず、io_existsとexternal_existsを区別 | .25〜.27、.21 | 35〜60 | L/S/N/D |
| L60.29/F2 | 全実表の28+1欄を閉じる | StandardModelCore、既定import、写し | F07.core/targets/program_typed/program_wellFormed | [tablesの四照合](tables.md#l6004とl6029で行う照合)を実行。全既存証拠→合成行の出典別件数一致・漏れ0、仮定側の証拠名0を独立に確認。台帳↔全lookup、Rust登録→台帳も照合。sat/admitsの8保存・sourceTelRows/operationKinds/StoreShapeを含む28+1欄とWellTyped/WellFormedを同じ表で構成。仮定側の全名前・理由を記録 | .28 | 35〜60 | L/S/N/D、W-F2 |
| L60.30/G | 義務27行を段別に照合 | 群Gのobligations/記録 | 第6節の全行 | 完了証拠と残る所有を分離。O144の誤移管0。定義があるだけの行を完了にしない | B〜F | 30〜50 | S/D |
| L60.31/G | 申し送りの全受け口と読者を照合 | 群Gのhandoffs/依存記録 | 第5節の59行 | 証拠→読者の型と値の定数依存を行ごとに照合。未使用はそのまま書き、受け口が将来なら未使用とする | .30 | 30〜50 | D、静的集計 |
| L60.32/G | 四分類と全場合を照合 | 群Gのcases/conditions/記録 | 12欄、75欄、全表28+1欄 | 第2.4節の順で、前提の否定・結論の自明さ・充足可能な入力を全欄で照合。定数errの存在3欄は自明。正常/拒否の証拠は別記。12欄7/3/2、87欄76/3/8と合成/仮定台帳を照合 | .31 | 30〜50 | L/N/D |
| L60.33/G | 外部除外の境界と後段の契約 | 群Gの署名表、写し | O086/O157/O168、F02/F05/F07/F08 | externalType/external function両理由のreader/台本/元定義/別本体/独立入力を名指し。L60の支持葉とR50の実0件を別欄にし、既に0件と書かない | .32/.18 | 35〜60 | S/D、W-G |
| L60.34/H | 段末の全署名・写しと一覧 | stage-results/記録、写し | C/F全名と第2節の全場合 | 全新定義・言明・仮定・旧主定理/新葉の一覧を作る。既定importを外さず、未完を後段の成功に代えない | G | 30〜50 | S/D |
| L60.35/H | 段末の公理依存と最終読者 | 段のaxioms.lean、記録 | A-L、全名監査 | Leanのprivateの宣言と生成宣言と使用定義を含むimport閉包を監査。許可三公理以外0、sorryAx0。証拠の型ハッシュと読者の依存を機械照合 | .34 | 30〜50 | A/S/D |
| L60.36/H | 独立レビューへの応答 | 指摘が当たる本番/写し/記録のみ | 全所見のhandling | 取りまとめが起動した独立レビューの所見を一件ずつ処置。範囲外の改名・文章置換をしない。新しい意味の変更は止める | .35＋独立レビュー | 30〜50 | 古くなったL/S/N/D/Aだけ更新 |
| L60.37/H | 段末のworkと受け渡し | stage-results/記録、L70/Rへの署名一覧 | 全O/H行の判定と残る所有 | 同じ最終状態でworkを一度、取りまとめの正式RSSを同じ実行へ付ける。受け入れは設計者。実CLI/全比較は本段に追加しない | .36 | 25〜45 | W-H、正式RSS |

### 群ごとの完了条件

| 群 | 単位 | 群末で閉じるもの | 起動順と取り込みの条件 |
|---|---|---|---|
| A 方式と骨格 | .01〜.05 | 七射影の移送の全14判断76枝、外部/解放の関係の型、合成/仮定の台帳、F01〜F08の完全署名、合成表上の本体再証明の方針と副条件。決定済みJ60-1〜3を具体化 | 最初。未確定の方式をB以降へ渡さない。独立レビュー後に取りまとめが取り込む |
| B 宣言と名目性 | .06〜.09 | 鍵4対・全Ty21の位置・F02の全変換・uses/Stateの全規則、偽造の3境界 | Aの実署名を使う |
| C 外部応答とモデル | .10〜.13 | 三モデルの外部9欄、6正常形と篩拒否、25欄を同じ拡張Bへ移す証拠 | Bの実宣言を使う。通常資源の最終存在はE |
| D 実行と表層の葉 | .14〜.18 | 外部3Step、選択と計算→関係、表層の外部固有5接続 | Cの全入力の存在から使う。主定理は閉じない |
| E 通常資源と三モデルの合成 | .19〜.22 | 8解放葉、既存証拠のある通常資源と5種の名前台帳、87欄の実質76/自明3/空疎8 | Cの後に起動でき、Dの成果を待つ依存はない。外部ハンドルの解放を通常資源へ混ぜない |
| F1 証拠のある宣言・数値・演算子 | .23〜.25 | 同じ有限P/B、最初の16接続、数値・全演算子・構造等号。後の行を黙って上書きしない | J60-3=(a)の合成対象と群Aの台帳を正とし、独立レビュー・取り込みを一度置く |
| F2 証拠のある構造値・本体・IOと合成 | .26〜.29 | [tablesの閉じた入力](tables.md#lean側から固定する既存証拠)の全証拠→合成行、仮定側の証拠名0、台帳↔lookupを件数付きで照合。合成表上のcore再証明、28Core+1対象、WellTyped/WellFormed、仮定側の名前と理由 | F1を継承。既存証拠の合成が未完なら相談。仮定側へ移して済ませない |
| G 義務と申し送り | .30〜.33 | 27義務・59受け口・全場合・依存の証拠、除外0件を判定する後段の入口 | C〜Fの証拠を使用。将来の読者は将来と記録 |
| H 段末 | .34〜.37 | 写し、既定import、A-L、独立レビューの処置、最終work/正式RSS、受け入れ資料 | 最後。設計者の受け入れをもって段末完了 |

方式の関門を担当が自分で独立レビュー済みにしない。群Aの未成立が、主定理の前提・結論、新公理、精密な外部状態、書ける形、提供範囲に触れると分かったら、他群の実装を先行せず、定義・反例/未証明の言明・代案・所要時間（能動時間）・待ち時間と実用への影響を報告する。

## 5. 申し送りの一件ずつの受け口

L50段末の31行を全て残す。先にL60へ来た事項をL50が引き継いでいる場合は同じ技術作業を重ねず、以下のH行と、過去の原所見を読むS行を結ぶ。Sはこの文書内の照合番号であり、新しいADR/TODOや本番のコメントの名前ではない。

分類は「L60受持」（本段で接続・供給する）、「既済み継承」（本段で再実装しない）、「他段受持」（送り先を保持する）である。証拠の定義があるだけで読者ありとはしない。各受け口で、使う証拠の完全名・型の全引数・読者の型と値の依存を記録する。

| L50行 | 要点・既存の入口 | 分類 | L60の単位・完了の判定又は正しい送り先 |
|---|---|---|---|
| H01 | 芯の対応/facts、形成付きapp_tel。撤回した元型全体のLeQに戻さない | 他段受持 | L70の全開始の合成。C06/C12を継承し新しい逆転を作らない |
| H02 | TelClosure.applyのCtx.WFと元列Annotation、除去済み四前提 | L60受持 | .14/.17：実開始から同じ実署名へ供給。L70は全合成 |
| H03 | ScopeResponse/ModelHttp/Targets.normal_facts | L60受持 | .24〜.29：同じδ、正常値、toTerm?の等号からfacts。L70へ全実行 |
| H04 | 要求の二保持形、同じ内容型/reqTarget/endpoint/σ | L60受持 | .28/.29：同じ値を全表へ。全位置の到達はL70、実装はR30/R50 |
| H05 | 篩付きPair五欄要求、parseUrlTargetの射影形拒否 | 他段受持 | R30/R50の同じ要求の比較。L50の処置を未修正扱いへ戻さない |
| H06 | sourceTelRows/SourceScoped/TargetTable.content_rows | L60受持 | .21/.23/.29：残る全表で供給。ソース生成はL70/R10b |
| H07 | ScopeModels.conditionsの75出力、任意Ψ/非Top | L60受持 | .12/.13/.22：新Bへ移し12欄と合成。sat=Trueの例で代用しない |
| H08 | Ready/InitialPrepared、未束縛の準備拒否と動的Error | 他段受持 | L70の初期表層・全到達。Readyを新しい全状態不変条件にしない |
| H09 | ModelConstraintsの値四保存、Fail列の骨格 | L60受持 | .22/.29：同じsat/admitsへ再利用。順序/長さ/重複を読む条件を足さない |
| H10 | TypeParamRenamingと型/行像の四保存 | L60受持 | .22/.29：束縛下の途中挿入も維持。独立のsat_localなし |
| H11 | PathBasesShape八欄とProcess.Environmentのmembership | 他段受持 | L70の全効果、R30の実発行。全表への収集はH13/.28と同じ入力を使う |
| H12 | ShapeOk.singleのopaque(rvar 0)とscoped_forget | L60受持 | .28/.29：同じ署名・同じ値。scopedの署名へ変えない |
| H13 | 有限PのResult/Pairのarity2、Request/Errorと全lookup | L60受持 | .23/.27/.29：同じ全表の形成を供給。旧Scopedを新Scoped Pへ直接流用しない |
| H14 | 全有効σの適格性と外部三条件の区別 | L60受持 | .10/.11/.14：external_adequate/received_valueを実際に使う。δ/IO証拠で代用しない |
| H15 | 非Top→Top→opaque、要求なしRequestの拒否 | 他段受持 | R30/R50の同じ保持値の受理・拒否。一般逆転はC18で控除 |
| H16 | TargetTable.valKindのPathIn/path、RequestIn/endpoint、valContent | L60受持 | .21/.28/.29：同じ実表で分類。R30は実装側 |
| H17 | AtPrepared.request/reqTarget_kind/checkAt.absolute | 既済み継承 | C18。追加の未完0、再証明しない |
| H18 | data_observationとDetail.match_pattern_typed | 既済み継承 | C18とL50の受け入れ。公開形はU02後の別作業、再実装なし |
| H19 | 対象3sortと同じ値の観測・所属・具体化 | L60受持 | .28/.29：同じδへ供給。R50へ二つのlength観測を渡す。非対象13sortは再実装しない |
| H20 | 九欄の内部保存、20等号、未解析の元入力 | 他段受持 | U02後の公開写し/L70/R30/R60。保存値と表示上限を分ける |
| H21 | 同じP.cons/Term/RuntimeMatch/Exhaustiveの公開写し | 他段受持 | U02確定後・L70前の別作業。生Valを読む形なら適格性を再点検 |
| H22 | 型/行像・範囲具体化・値bindの正規化 | 他段受持 | L70の全主定理。同じ一般交換はL20で済み |
| H23 | Sourceの直接構築拒否、同じσの発行→At | 他段受持 | R30/R50のrecord/JSON/外部からのPathBases偽造拒否。L60の外部不透明性はH31へ |
| H24 | O022/O034/O062/O065/O144の局所証拠と全体を区別 | L60受持 | .29/.30：全実表への合成。O144は第6節で他段へ分類。演算子/decoderのL40の証明を再移管しない |
| H25 | 同じ有限宣言・summary/satB/KeyObservation | L60受持 | .23/.26/.27/.29：全表収集。ソース合成と全比較はL70/R10b/R50 |
| H26 | CaptureReadBoundaryで読まれない捕捉の場所番号をδが観測できる | 他段受持 | R50のRustとの比較と設計者の登録判断。新しい不変条件/精密状態なし |
| H27 | 外部三欄と通常資源release_existsを各モデルへ | L60受持 | .10〜.13/.19〜.22：第2.4節の12行を同じP/Bで閉じる |
| H28 | 任意Ψ・全適格σ・新F3受理、全入力 | 他段受持 | L70/R50の全開始・全応答。L60も入力をTop/空Ψ/旧入力へ限定しない |
| H29 | File6本/sendとexternalResponseを分離 | L60受持 | .10/.19/.28：borrow/own/Stateと通常資源を区別。実IOの固定σはR30 |
| H30 | 局所Lean/raw再生とRust/Lean全比較の区別 | 他段受持 | L70/F-REG、R50/F-CONN。有限交換と上層証明を同じ候補で照合 |
| H31 | 外部ref/handle等のAdequateResultは外部応答三条件の代用にならない | L60受持 | .10/.11/.14：carrierから全有効σのadequateを実際に導く。公開元入力の再点検はU02後 |

L50の31行の分類はL60受持17・既済み継承2・他段受持12である。元のL50の「技術24・継承5・他段2」は**L50時点の所有の分類**であり、この表のL60時点の分類と一致させる必要はない。

### 原所見・前段からの追加の28受け口

| 番号 | 原所見・出どころ | 分類 | 受け持つ単位と完了の判定 |
|---|---|---|---|
| S01 | L20 stage-results J20-2：型/行像・tapp・sourceTelRows | L60受持 | .21/.29。H06へ合流。実表の全件供給で閉じる |
| S02 | L20段末「実表・三モデル・対象/範囲」：小さいsat=True例の限界 | L60受持 | .22/.29。H07/H25へ。旧Assumptionsの成功を証拠にしない |
| S03 | L30 A5 葉の受渡し：PreparedLeaf四欄と型付き本番値 | L60受持 | .24〜.29。H19へ。実応答からの構成を使い、PreparedLeafの再定義なし |
| S04 | L30段末O022/O034、J/K実モデル：machine_exact/stable/represented | L60受持 | .29/.30。H03/H19へ。型付けだけから算法一致を推測しない |
| S05 | L00b.15 theorems：旧20欄と追加の外部/値/型の条件、release_exists | L60受持 | .19/.22/.29。未移行だったsig_scopedはL20で済み。28+1の新表を構成 |
| S06 | L00b.15 theorems/RV-.14c：Reference四種kind=[value] | L60受持 | .21/.29。処理系の実四署名も照合し、表の旧存在条件だけで終えない |
| S07 | L00b.15 mapping：01-12の各葉と抽象/具体/全体の区別 | L60受持 | .34。既存の写しを根拠に主定理済みとしない。外部/解放の新しい接続だけ写す |
| S08 | RV-L00b.02b-external中1：carrierまで信頼、篩は受信検査 | L60受持 | .10/.11。一般検査C07〜C09は控除。三モデルで正常/違反を受信へ通す |
| S09 | 同 軽1：ExternalValueTypeの補助判断はRust受理より広い | 他段受持 | L70/R50はRust受理→ExternalSignature.WFの一方向。Option[Unit]等の逆方向完全性を要求しない |
| S10 | 同 軽2：ExternalCallAdmissible.typesは空Γ | 既済み継承 | 現行単相ではtypes_nil。多相外部を追加しない。将来の案をL60の規則にしない |
| S11 | 同 軽3：C_DependentApp/TelArgsからE_ExternalApply | 既済み継承 | ExternalStateLeaves.external_apply_allとLeafInputsで既済み（C11/C12）。.14は存在の供給だけ |
| S12 | 同 軽4：usesと実引数を持つState外部の正例 | L60受持 | .08/.11。borrowの実ハンドル引数、ownの結果、uses_exact逆向きを実入力へ |
| S13 | RV-L00b.04軽2：受理側・再帰するdataの深い位置の拒否 | L60受持 | .11。ExternalCarrier.accepted/Predicatesと強いKleeneを継承し、任意深さの帰納と小さい正負の対照を三モデルへ。単にchecked_typedだけでは閉じない |
| S14 | RV-L00b.05：受信拒否したownハンドルの解放 | 他段受持 | R50/L70の既定所有。L60は通常資源releaseへ外部ownのcleanupを加えず、carrier/受信の葉だけを渡す |
| S15 | RV-L00b.11：正規形のsat/admits/δ/IO | L60受持 | .21/.29。BuiltinArgs.normalizedを継承。Canonicalを外して入力の量化を変えない |
| S16 | RV-L20.a3a中1、plan 2026-11-02：operationKinds | L60受持 | .21/.29。全opEff付き署名のkindをvalueへ。LegacyPrimSignatureは旧適格埋め込みの入力のまま |
| S17 | RV-L20.a3b r2：sourceTelRows・外部の行支持・現在署名の本番化 | L60受持 | .21/.29。CurrentSignatureRowsの既済みを控除して全標準残りを本番へ。ExternalSignature.WFの既存欄を変えない |
| S18 | RV-L20.bc：新ScopedはPの宣言のarity/kindを読む | L60受持 | .23/.27/.29。同じPのResult/Pair等を供給。旧Scopedの証拠で代用しない |
| S19 | RV-L40.c情報1：生lambda/closure二表現と応答の差 | L60受持 | .04/.25/.26/.33。現行の実δが区別する行を照合し、差をR50へ。Coreの独立条件は足さない |
| S20 | RV-L40.d情報R1：Decimal.fromFloatのparsedとbits | L60受持 | .24。StandardNumericRemainingResponseの同じbitsの入口を使う。自由なparsedを実表に入れない |
| S21 | RV-L40.e軽2：任意P/Bのresponseと小表のtable_response | L60受持 | .23〜.29。全モジュールでresponseを使う。固定Pの証拠の無条件移植0 |
| S22 | RV-L40.g軽1/軽2と追記：34演算子/構造等号の実署名、表の合成 | L60受持 | .25/.29/.30。任意P/Bの二responseから同じ表へ。L40で閉じたdecoderを再証明しない |
| S23 | RV-L50.h情報5、群Hの取りまとめ追記 | L60受持 | .12/.19/.22。Modelのrelease空疎とexternal_exists不成立を別に処置 |
| S24 | RV-L50.i情報7、群Iの取りまとめ追記 | L60受持 | .13/.19/.22。Targetsのnone自明と通常資源の関係を区別 |
| S25 | RV-L50.j情報9、群Jの取りまとめ追記・j/handoffs | L60受持 | .13/.22。75欄と12欄、同じP/B、三表の具体入口を全件照合 |
| S26 | RV-L50.k中1と再レビュー：読者が依存として成立しない行 | L60受持 | .31。型/値の依存の閉包で全組を照合。一部の証拠だけを使う読者は証拠ごとに明記 |
| S27 | RV-L50.l中2：75欄中Modelの6欄は空疎 | L60受持 | .32。69/0/6と新12欄の7/3/2を別集計。Falseが出ないだけで実質にしない |
| S28 | RV-L50.l軽6：Targetsのrelease_existsは既にnoneで書ける | L60受持 | .19/.32。残件が証明不能でなく、通常資源の関係の接続であると示す |

追加28行はL60受持24・既済み継承2・他段受持2、両表59行の合計はL60受持41・既済み継承4・他段受持14である。HとSが同じ技術義務へ合流する場合は証明の件数も所要も一度だけ数える。l50/kの33義務・31申し送りの読者記録、l50/lの空疎の判定、l50/l/review-pointsの受け入れ済みの差を全て引き継ぐ。

## 6. 義務の分類と前段の段別判定

planの担当欄にL60を明記する行は**14行**である。全Lにかかる共通4行を含めると18行となる。前段の「残る段」にL60を持つ行は、L20段末5、L30段末2、L40の最終のg/obligations11、L50段末19である。L40のstage-resultsには、再開前の独立未完の記述も残るため、最終のg/obligationsと再開2・3の追記を併読した。古い未完を再登録しない。

和集合は26行、planの18行との差集合はO013/O015/O022/O034/O035/O048/O049/O065の8行である。H24が挙げるO144を誤移管の点検の1行として加え、下表は27行とする。出どころPは明示L60、共は全L、20/30/40/50は各前段の残る段を表す。古い状態欄の「L60未実施」は本詳細の完了を示さず、既に受け入れたL20〜L50の担当分を未完へ戻す意味でもない。

| 義務 | 出どころ | 分類 | 前段で済んだもの／L60の受け持ち・単位 | L60の完了の判定 | L60後に残る段 |
|---|---|---|---|---|---|
| O013 | 50 | 技術 | L50のShapeOk/75欄を継承。 .22/.29で全Coreへ | 12欄と同じP/Bの対象条件 | L70/R50/V10の全体照合 |
| O015 | 50 | 技術 | L30/L50のsort・所属を継承。.28/.29 | 対象3sortの同じ実応答を全表へ。新論理規則なし | R50の実装比較 |
| O016 | 共/50 | 共通 | 前段のA-Lは受け入れ済み。.35/.36 | 既定import閉包・旧主定理/新葉の全名、公理・独立レビュー | L70と各段レビュー |
| O022 | 30/40/50 | 技術 | L30/L40の三条件と実応答、L50の全σ。.24〜.29 | 同じout/toTerm?からのfactsと全表への接続 | R50/V10の実装・領域照合 |
| O027 | 共 | 共通 | 前段の正式RSSは各段に保持。.37 | 最終workの本体/計測器の終了・原単位・機械を分ける | L70/R20/R70の限定採取 |
| O034 | 30/40/50 | 技術 | L30の観測三条件とL40の各幅、L50の対象。.29 | 同じ値の表現・観測・所属を実表へ | R50の同じ値の比較 |
| O035 | 40/50 | 技術 | L50のRequestDeltaと保持二経路。.28/.29 | 同じreq/endpoint/groundVal/valContentのまま全表へ | L70全到達、R30/R50 |
| O038 | P/20/40/50 | 技術 | L20全ストア/継続とL40/L50の葉を継承。.14/.20/.22/.29 | 外部応答・通常解放の同じ状態からの葉と実表 | L70全保存 |
| O048 | 50 | 技術 | L50のwidenRequestIn/範囲拡大。.28/.29 | 同じ値と対象を全表へ。旧eq_of_not_fnへ戻さない | L70/R30/R50 |
| O049 | 20/50 | 技術 | L00b/L20/L50の保持要求の葉。.28/.29 | 同じreqTarget/内容型を全表で供給 | R30/R50。既存葉の再証明なし |
| O057 | P/40/50 | 技術 | canonicalと前段の応答葉は済み。.14/.19/.22/.29 | 任意の新型付き入力からexternal/releaseの応答存在 | L70 progress |
| O058 | P/20/40/50 | 技術 | L20の置換/格納とL40/L50保存葉。.14/.20/.29 | σ/Eb/μを保持した外部・解放の保存葉と全表 | L70 preservation |
| O059 | P/40/50 | 技術 | L20/L50の実行選択を継承。.15/.20 | 選んだ外部/解放応答からstep→Stepの局所証拠 | L70 step_sound |
| O060 | P/40/50 | 技術 | 前段の事象被覆と末尾の移送を継承。.08/.22/.29 | Stateの追跡、外部obs=[]と合成表の全effects。IOへ変換しない | L70 effect_soundness/noLamNames |
| O061 | P/50 | 技術 | L50のio_target/obs_allowed。.10/.14/.29 | external_no_targetsを同じP/Bへ。CoreとTargetAgreement別 | L70一段/到達/表層 |
| O062 | P/40/50 | 技術 | L40全pure/演算子/構造値とL50純粋6行。.10/.24〜.29 | 合成対象の同じδの全BuiltinArgsで存在/型/適格性/非exit。仮定側は名前と理由、外部carrierは別 | 本段の合成分は完了。R50の算法比較と最終全体照合 |
| O063 | P/50 | 技術 | L50全7IOとモデルio_exists。.13/.28/.29 | 新受理を含む全入力、外部三条件とIOを区別 | R50の実応答比較。正常応答存在は要求しない |
| O064 | P/40 | 技術 | L40は担当なし、L50のTargetsはnone自明。.19〜.22 | 三モデルと証拠のある合成資源の全型付き値で新関係の存在。証拠のない資源は名前と理由を記録。外部を資源へ追加しない | 通常解放の本段分は完了。R30/R50の実装比較 |
| O065 | 20/40/50 | 技術 | L20のScoped/移送とL50の八保存。.21/.23/.29 | 合成対象の全sourceTelRows/operationKinds/arity/StoreShapeと仮定側の台帳 | L70の新判断への切替 |
| O084 | 共/50 | 共通 | 前段の原因分離と独立未完0の判定を継承。.01〜.05/.36 | 篩/σ/external差を別記し、全関門と停止条件を守る | L70/R/K/Vの合成・比較 |
| O086 | P | 技術 | 旧Release/Surfaceの除外を確認。.16〜.18/.33 | 両除外を外せる外部葉と型の受け口。実0件は未実施と明示 | L70全reader、R50両理由0件/F-CONN、K10 |
| O087 | P/20 | 技術 | L00b/L10のID/ExternalWF、L20の供給済み葉。.06〜.09 | 全入れ子・全置換・未知/重複/差替え/偽造の境界 | L70表層収集、R50名目ID交換 |
| O088 | P | 技術 | 前段の外部規則/受信/保存葉。.08/.10〜.22 | borrow/own/State、三条件9欄と通常資源の区別、表層5接続 | L70主定理/全脱糖、R50 |
| O118 | 共 | 共通 | 前段のコメントの扱いを継承。.34/.36 | 変更した本番/写しに作業IDを残さず、現行の章節/意味の名前を使う | L70/R50/R60/D10/V10 |
| O144 | H24 | 他段 | H24の参照。L40/L50の局所証拠は受け入れ済み | L60はその証拠を合成に使用。新しい理論・CLIの所有を追加しない | R20/R10b/R40/R50/V10。理由は下記 |
| O157 | P | 記録 | 現行07-04には旧除外の説明が残る。.09/.18/.29/.33/.34 | 新しい外部/解放葉と01-12を同じ変更で写し、未実施の全比較を成功にしない | L70境界改訂、R50除外0、D10/V10最終候補 |
| O168 | P/50 | 技術 | L50のパス/偽造の内側は済み。.07/.09/.18/.33 | externalの名目性・不透明性の内側の葉を受理/拒否の対で示す | R30/R50/R60/R70/D10/V10のDET-R全実CLI |

分類は**技術21・記録1・共通4・他段1＝27行**である。O086の本段分は支持葉の準備であり、除外0件そのものを本段で閉鎖しない。O144はplanの担当にもL50段末の残る段にもL60がなく、H24の「全表へ合成」を理論/領域/CLIの新作業の移管と読まないための対照行である。理由: 定義・有限規則・局所証拠はL10〜L50で受け入れ済みで、後段で残るのはRustの検査・比較・候補CLIである。実表への組込みはO022/O034/O062/O065で受け持つ。

各複数段のO行に対するL60の完了条件は本表の第五列である。実装時の証拠は、該当群のresults/conditions/全名の署名/依存記録、最終のstage-resultsへ集める。全体の義務を「閉じた」と判定するのは、右列の残る所有も終わった後である。

## 7. 方式の確認の状態と分岐する判断

### 7.1 短いLean入力で確認したこと

試行は`<tmp>`の入力だけで行い、`formal/`の本番ソース・既定importを変えていない。`lake env lean -M 12288`、既定Benitoiteのimport済み環境で、最後の入力は終了0・外側約0.754秒だった。入力全文・修正・終了と公理依存の記録をresultsに保存する。

| 形 | 確認した範囲 | まだ確かめていないこと |
|---|---|---|
| F04の関係 | `response`の全称形を定義でき、errの関係所属と全入力の応答存在を証明できた。sig/sat/δを変えない拡張表の三射影はrfl | 三射影が等しいだけで型付けが自動で移るわけではない。F01の全76枝、三モデルの9欄、正常応答の具体の証人、25欄の移送 |
| F06の関係 | 正しいopaque資源値について成功と失敗の双方を許す関係を書け、二つの証人を作れた | 任意の型付き資源値のcanonical、証拠のある資源の分類と新表のrelease_exists。5種の名前と仮定側の理由 |
| 現行の解放の3欄 | Model/HttpのisResource=falseの矛盾、Targetsの`⟨none,rfl⟩`をそのまま証明できた | これは新しい実質の解放関係を構成した証拠ではない |
| F08の二葉 | ref_typedとcall_typedを全添字つきで、既存のV_ExternalRef/C_Externalから証明できた。callはTel.bind(typeEnv ts) | 名前付き引数/穴を含む一般の表層の読者、同じソースの生成と全checker |
| 既存の入口 | ModelScopeConditions.core、received_value、外部保存3葉、externalRef_contract_inputs、任意P/Bの演算子・構造等号responseの実型を印字 | 全実表への適用、主定理・表層・全比較 |
| 全表の母集団 | 現在Rustの登録61部分・523参照と、L40の23モジュール328公開APIを別に静的集計 | 全523の名前、合成/仮定側の分類と理由、重複名、証拠のある行の合成は未照合。新しい意味の定義は対象外 |

試行した補助定理の成功時の公理依存は、propext/Quot.sound/Classical.choiceの部分集合だけである。段末A-Lを実施した意味ではない。最初の失敗入力は名前空間の指定不足による型の不一致であり、独自公理やsorryを成功の根拠にしていない。

### 7.2 分岐する判断の決定と理由

再開1の取りまとめの指示により、次の三件を決定済みとして扱う。plan末尾の2026-11-05の追記とも一致する。群Aは判断待ちでなく、この方針の定義・署名・台帳を固定する。

| 番号 | 決定 | 理由と退けた案 | 群A以後の扱い |
|---|---|---|---|
| J60-1 | **B**。Pを制限せず、F04の応答を定義した拡張表へ既存75欄を移す | 外部宣言/呼出しなしへPを制限するAは書ける形を狭める。空関係のままでは適格な外部呼出しの存在欄が不成立。拡張表なら既存表と読者を保って同じ七射影で移せる | .02/.03/.05で実署名、Cで外部9欄、Eで全87欄を構成。主定理の前提・公理は変えない |
| J60-2 | **F06**。通常資源の分類に対応して成功・失敗を許す抽象関係 | 全値にnoneを許す旧関係は通常資源の分類を読まない。F06は型付き値のcanonicalから同じ資源値の関係へ接続できる | .03/.19〜.22。精密な開閉状態が必要になれば停止条件へ戻す。外部ownを通常資源に加えない |
| J60-3 | **(a)**。Leanの実δ・本体・応答の証拠がある行だけを同じP/Bへ合成し、証拠のない登録は名前と07-04の仮定の範囲に入る理由を一行ずつ台帳に記す | planのL60行と「形式化の内外」は全Rust登録の合成を求めない。(b)の新しいδ/IOの意味の定義は所要不明で精密状態の停止条件に当たりうる。(c)の合成の除外はL40の328 APIをL60へ渡す受け口を失う | .04で台帳、F1/F2で既存証拠を合成。新しい意味・無条件err・semantic providerで埋めない。提供範囲と書ける形を変えずR50へ台帳を渡す |

主な定理の前提・結論の追加変更、新公理、未検査の信頼条件、精密な外部状態を新しく提案する項目は、上の決定には**ない**。必要になったらplanの停止条件を直ちに使う。U02の公開名/構文、U05の交換版、own受信拒否後の実解放、CaptureReadBoundaryの登録判断は既存の他段の判断として残す。Pの制限・篩付き外部宣言の拒否・正常応答しか扱わない条件・空ストア/Topだけへの限定を、補助の都合で導入しない。

### 7.3 前段の定義・署名を変える場合の波及

| 対象 | 既定の扱い | 変更が必要になったときの波及と停止 |
|---|---|---|
| Ty/Tel/ExternalWF/ExternalSignature.WF/型付け14判断 | 変更0。Bの七射影の移送は別の補題として追加 | 型規則の変更なら既存76枝×型/行/範囲/値等の移送へ波及する。正確な影響枝を一覧にして止める。76を全て変更するとの断定もしない |
| 外部の受信検査とOutcome.Carrier | 定義と受信後検査を継承。carrierをTy.carrierの型付けと混同しない | carrier/Predicates各12枝、receive/received_value、外部3Step、StateTyEの葉と全σのadequateへ波及。篩の真をゲストの信頼へ移す改訂は不可 |
| Model/Targets/Httpの既存builtinsとscopeConditions | 既存の25×3欄はそのまま残す。拡張表に別名で出力 | 旧表を直接変更するなら75欄の型と全読者を再照合する。外部3＋release1だけ変えれば他の25欄が自動で同じになるとはしない |
| CoreAssumptions/TargetAgreement | 欄数/型/意味を変えない。28と1を分けて出力 | 新欄や量化の変更は主定理の前提の変更なので停止。実表の不足をCoreの新欄として仮定しない |
| Step/StateTyE/step | 構成子と意味の変更0。3外部葉と8解放葉の接続だけ追加 | 旧76Stepの相互作用、型/状態の全葉と主定理へ波及。受け入れ済みのE_Lam/E_AtErrorの変更を今回再設計しない |
| 標準の小さいP/Bと精密tel | 既存の証明を残す。合成表は別のP/Bとして構成 | P/B固定の証明の移送は新しい接続。失敗を無条件のerrや任意のprop欄で消さない。L40のS14/S15等の意味を弱めない |
| Surface/全交換の切替 | 外部固有の葉だけL60で用意。全切替はL70 | 旧SurfaceのRelease型へexternalをopaqueとして押し込む方式は採らない。全readerを新判断へ写す順はL70の担当 |

## 8. 本番追随とL70・R段への署名

### 8.1 最初の同種16件

旧Releaseには専用external型/呼出しの規則がなく、L60の外部部分で「旧Ty.Leの外部補題を新判断へ移す」本番移植は0件である。L20の一般置換とL50の75欄を移植済みとして二重に数えない。

本段で新しく必要な追随は、既存の新判断で証明された部分表を、一つのP/Bの実表へ合成することである。最初の同種16件をL60.23〜.25の本番として残す。`StandardOperatorResponse.entries`の順で、Integer8/16/32/64/UnsignedInteger16/32/64の各div/modの14件と、floating falseのadd/subtractの2件を使う。参照するのは任意P/Bの`StandardOperatorResponse.response`であり、`table_response`ではない。全表の新しいlookupとBuiltinArgsから同じ実δの結果へ結ぶ16個の読者を作る。

16件のうち一部が既に全表の同じP/Bで閉じていると分かったら控除し、測る目的で作り直さない。同種の残りは追加34中18件、演算子全107中の他の既済み73件は異なる供給元として区別する。構造等号2名、core84、全IO、523台帳の未照合行へ16件の平均を掛けない。

通常のresultsの外側時間E、分離できる待ちW、完了数n=16からのみA=E−W、c=A/nを得る。分離不能ならcは未取得、旧見込みを保ち、外側時間を情報として添える。更新するのは同種の未処理Nに対するN×cだけである。測定専用の作業・別実装・元へ戻す試行は置かない。形が合えば通常の続きへ進み、形が合わないと分かったら定義と反例/未証明言明を示す。

### 8.2 後段へ渡す完全名と型の契約

新名の接頭辞は`Benitoite.Release.Refinement.`。新名の型はF節を正とし、群AとHで全暗黙引数を印字して、実開始からの前提の供給を照合する。

| 受け手 | 完全名（接頭辞を付ける） | 型と受け口・残る作業 |
|---|---|---|
| L70 | F02の全変換のID保持の系、ExternalUseAt.mode、ExternalSignature.WF.shape | F02/F03。有限外部表と名目性/borrow/own/Stateをソース収集から供給。受理→WFの向きだけ |
| L70 | ExternalSurface.ref_typed/call_typedと五接続の対応表 | F08。全表層/脱糖/checkerの子の結果から同じ篩付きa/eへ。一般のnamed/穴/評価順と全表層の健全性を合成 |
| L70 | StateTyE.external_response_step、Builtins.selectExternal、Builtins.selectExternal_response、step_external_selected | F05。任意の型付き外部開始、同じP/B/σ/Eb/μ、存在と計算→関係。全progress/preservation/step_soundへ |
| L70 | StateTyE.external_apply_all/external_value_all/external_error_all、Builtins.ExternalAssumptions.received_value | C09/C11の実署名をそのまま渡す。受信値のaでの型/Ground/全σのadequate。主定理の前提を増やさない |
| L70 | ResourceRelease.response、ExternalModels.model/targets/http、各core/targetAgreementの出力 | F04/F06。三モデルの既存25欄＋外部3欄＋解放1欄。実質76/自明3/空疎8の根拠と正常/拒否の入力を添える |
| L70 | StandardModel.program/builtins/core/targets/program_typed/program_wellFormed | F07。合成対象と同じP/Bの28+1欄、definition_typed、仮定側の名前と理由の台帳。利用者Pへの収集、全主定理/互換readerの切替はL70で一度だけ行う |
| R10b/R50 | F02/F03/F08の定義・葉、合成側のsourceTelRows/operationKinds、通常資源の5種の名前と合成/仮定の分類 | 実external型ID・入れ子・宣言表・型/Effect引数拒否・borrow/own/Stateとの照合。入力の型をopaque/Topへ消さない |
| R30/R50 | ResourceRelease.responseと8解放葉の表、ScopeResponse/ScopedIOResponseの同じ値の契約 | 実資源の解放/中断/失敗と抽象関係の向きを照合。外部ownの解放は別の既存義務。実体/副通信/OSの保証を足さない |
| R50 | 全登録台帳、元定義/別本体/独立入力、外部受信4葉、externalType/external function両理由の支持葉 | F-CONNで両除外0件。閉じた外部評価不能は評価比較だけ理由付きで分ける。型/解析/脱糖/checker/網羅性から落とさない。ABI/WIT/GC所有の全証明と、台帳の仮定側の実算法・状態は外側 |
| R50 | CaptureReadBoundary、ModelTargets.readObs、Decimal/Float/構造等号の前段の差 | 新しい実表でも元の申し送りを保持。応答が生lambdaとclosureを区別するか、同じbitsからのparsed、関門外URL、相対/home形の対象観測を比較 |
| D10/V10/K10 | O086/O157/O168の段別証拠と残る所有 | 新葉/写しと、R50の実0件と実候補を混同しない。全CLIの拒否/受理、07-04の最終境界、関係状態の再確認 |

## 9. 検査の割り当て

以下は**将来の実装の割り当て**である。今回の計画作成は文書の静的点検と短い補助入力だけであり、既定build、work、段末A-L、Rustテスト、全比較は実行していない。新しいテストを作る担当はtest-auditの作成時の関門を通す。定義の形だけの補助試行を、退行の所有境界を持つ新しい処理系テストへ水増ししない。

| 検査 | 中身・コマンド | 割り当てと保存・待ちの見込み |
|---|---|---|
| L 局所Lean | `formal/`で `lake env lean -M 12288 Benitoite/Release/Refinement/<対象>.lean`。新しい補題と実際の前提の供給を局所で確認 | 各単位の途中。型の試行の今回の約0.75秒は全帰納の見込みではない。群resultsへコマンド/Lean本体の終了/外側時間を保存 |
| S 実署名 | 群Aで全F、B〜F2で各実署名、Hで全宣言を既定環境から印字して型と前提を照合 | .05/.22/.29/.34/.35。型のハッシュと完全名。実在だけで言明の十分さを済ませない |
| N 非空性と受理/拒否 | 型付き外部入力、正常/篩拒否/err、資源の成功/失敗、同一/異種ID/component/resource、全σ/任意Ψを含む証拠 | 各群の条件表。空疎な行は理由とFalseの導出を記す。非空性の全称化を具体例だけで代用しない |
| D 依存と全件対応 | Leanの名前付き宣言の型と値に現れる定数の閉包を辿り、証拠ごとの読者と経路を保存 | .05から順次、.31全件、.35最終。future readerは未来と書く。未使用に見える名前を消して主定理の入力を失わない |
| W 選択確認 | 根で `scripts/check.sh --level work --base B_WORK --dry-run` | 群A/B/C/D/E/F1/F2/G/Hの各最終状態。B_WORKは各起動で渡す完全ID。onlyなしを既定とし、誤指定2/分類不能3は共通依頼文の扱い |
| W 作業末 | 根で `scripts/check.sh --level work --base B_WORK`。既定全Leanとsorry拒否、変更した01-12/07-04の読者。text例を変えればspec_examples、構文も変えれば生成Skill/skill_docs/spec_tallyを同じ入口へ | 各群末に一度。LeanだけにRust全libを追加せず、局所buildと同じ一式を重ねない。直近478.36秒×9=約71分45秒は参考待ち。増分/cleanと関係する変更で更新 |
| A-L 公理依存 | 段の`axioms.lean`に既定Benitoiteをimportし、旧主定理・新葉・使用定義の全名について`#print axioms`。`formal/`で `lake env lean -M 12288 <監査入力の相対パス>` | .35、所見の修正後は古くなった範囲だけ再確認。Leanのprivateの宣言と生成宣言を含むimport閉包を対象とし、全名/出力のbytesとSHA-256・実署名・道具/構成を保存。直近L50約53秒、計画1〜5分案を待ちに保つ |
| 公理の判定 | propext/Quot.sound/Classical.choiceの部分集合だけを許す。sorryAx・独自公理・未承認の信頼条件0 | .35/.36。既定importや既存主定理を外して成功にしない |
| 正式RSS | .37の同じ最終workへ取りまとめがsandbox外でmacOSのtime -l又はLinuxのtime -vを付ける | 段末だけ。他は未取得（計画上の非採取）。本体/計測器の終了・機械/OS/原単位を分け、追加buildを作らない |
| 独立レビュー | 群Aは関係/完全署名/全表の方式、各群は全場合/存在/非空性/同じP/B、段末は27義務/59受け口/87欄/全実表・写し | 取りまとめが群末ごとに依頼。.36で処置。待ちは不明。担当の自己点検を独立レビューに代えない |
| 全比較と実CLI | L70末F-REG、R50のF-LOCAL/F-CONN、K10の関係再確認、V10の実CLI | 本段へ前倒ししない。旧約40分/最大約14GiBは別の実行。R50の両除外0件をL60の局所成功から推測しない |

結果には基準完全ID、入力/生成物/設定/道具/構成、対象HEAD/差分と未追跡入力のハッシュ、コマンド、件数、実行器/本体の終了、外側時間、RSSの採否と理由、後の変更、引用する場合の関係状態一致の根拠・判断者/日付を残す。大きな生出力はbytes/SHA-256と再現入力を改造内へ残し、消える`work/`・`reference/`や手元の絶対パスを根拠にしない。

## 10. 所要時間（能動時間）と残りの手順

37単位・9群の積上げは**21時間55分〜37時間10分、中心29時間32分30秒**である。再開前の22時間05分〜38時間30分から下端10分・上端1時間20分減った。planの枠17〜41時間・中心29は変更しない。J60-3は決定済みで、全Rust登録の未知の意味の定義を含む条件付き見込みは取り下げた。以下は既存証拠の合成と合成表上の本体再証明の参考見込みである。未知の旧除外不一致の修正は別相談のままとする。

| 群 | 単位数 | 所要時間（能動時間）の積上げ |
|---|---:|---|
| A 方式と骨格 | 5 | 3時間35分〜5時間45分 |
| B 宣言と名目性 | 4 | 1時間55分〜3時間10分 |
| C 外部応答とモデル | 4 | 2時間25分〜4時間15分 |
| D 実行と表層の葉 | 5 | 2時間40分〜4時間35分 |
| E 通常資源と三モデルの合成 | 4 | 2時間10分〜3時間45分 |
| F1 証拠のある宣言・数値・演算子 | 3 | 2時間00分〜3時間25分 |
| F2 証拠のある構造値・本体・IOと合成 | 4 | 3時間10分〜5時間30分 |
| G 義務と申し送り | 4 | 2時間05分〜3時間30分 |
| H 段末 | 4 | 1時間55分〜3時間15分 |
| 合計 | 37 | 21時間55分〜37時間10分 |

増減は.02/.05の七射影・C_Handle・F07の署名/副条件固定（計+20/+20分）、.07の既存変換の控除（−20/−35分）、.21の資源の台帳化（−5/−10分）、F1の既存証拠への範囲の確定（−15/−35分）、F2の範囲の確定と.27の再証明の加算を合わせた差（+10/−20分）である。F1/F2の合計は旧5時間15分〜9時間50分から**5時間10分〜8時間55分**となる。.27自体は50〜100分から80〜140分へ増やし、表の拡張の未計上を隠さない。

### 前段の実績の使い方

[effort-ledger](../effort-ledger.md)のL20は外側約20時間（見込み97時間45分〜219時間45分）、L30は下書き込み約7時間30分（47時間05分〜91時間55分）、L50のH/I/Jは約29/22/22分、Kは約26分＋再開約18分だった。L50段末の7時間03分32秒も数値のある区間だけの和で、全能動時間ではない。読み取り・待ち・取りまとめ・レビューを分離できないため、一律の比をL60へ掛けない。

L50の再開の教訓は完了条件へ反映する。Eの約25分の再開から型付けと同じ実δ/応答の証拠を分け、Kの約18分の再開から証拠→読者の型/値依存を機械照合する。Lの再開から四分類と処置対象の限定を守り、AのNamesWF不足から群Aで完全署名と前提の供給元を固定する。

planの2026-10-31の設計者の了承では、同じ群を同じセッションで進め、群末でレビューする。時間だけの相談の基準は段の上端でなく改造全体の上端とする追記を優先する。ただし各作業の上端の2倍・新公理・主な定理の未承認変更・精密な外部状態・旧除外の未知の食い違いの停止条件は保つ。最初の1時間から見直し、見込みを越えたら原因と能動時間/待ちを分けて報告する。2倍に達した場合はビルドと関係検査が通る区切りで止め、新しい作業を増やさない。意味の停止条件は区切りを待たない。

### 検査・レビュー・受け入れまでの残り

| 手順 | 担当・完了の判定 | 見込み |
|---|---|---|
| 修正版の確認と起動条件の確定 | 取りまとめ。決定済みJ60-1〜3、七射影・F07の再証明・四分類と台帳・義務/申し送りを確認しplanへ反映 | 待ちは不明。実装の時間へ加算しない |
| 群Aの方式・骨格の実装と検査 | 担当。F01全76枝と全署名、合成/仮定台帳、F07の再証明の副条件を固定。群末workと独立レビュー | 能動3時間35分〜5時間45分。既定buildは直近約8分を初期値に更新、レビュー/回答待ちは不明 |
| 群B〜F2の実装と局所検査・群末レビュー | 担当。外部9欄/通常資源/全実表と葉、群末work。取りまとめのレビューと取り込み | 能動14時間20分〜24時間40分。work待ちは6群で直近換算約48分、レビュー待ちは不明 |
| 群G〜Hの全件照合・段末監査・所見の処置 | 担当。27義務/59受け口/全場合と依存、既定import/A-L/写し/最終work | 能動4時間00分〜6時間45分。G/Hのworkは直近換算約16分、A-Lは1〜5分案。独立レビュー待ちは不明 |
| 段末の正式RSSと受け入れ | 取りまとめが同じ最終workへ計測を付け、設計者が受け入れる | 追加buildなし。受け入れ待ちは不明 |
| L70の全合成・表層・切替・F-REG、その後R50/F-CONNと候補 | 既存planの担当。主定理の移動済み3〜7時間もL70の内数 | L70はplanの24〜62時間。全比較の時間/機械は短い試行で更新し、長い実行の了承を得てから始める |

表のworkの単純換算は待ちの参考であり、9回×478秒が下限又は上限だとはしない。今回の短い試行を全体系のビルド時間の見込みに使わない。将来の長い列・大きい整数幅・深い型の検査は、大きい具体値の評価でなく記号・有限規則の全称・帰納で進める。
