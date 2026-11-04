# L50 範囲付き値と σ の葉の起動単位（下書き）

2026-11-04。計画担当による下書きである。[共通依頼文](../implementation-request.md)、[plan](../plan.md)、[decisions](../decisions.md)、[README の設計者の決定](../README.md#設計者の決定)を引き継ぐ。実装の開始を指示する文書ではない。取りまとめが段別の義務と完全署名を plan へ転記し、独立レビューの所見を処置してから起動する。L40 の段末は2026-11-04に設計者が受け入れた。

指定ブランチは `m014/l50-plan`、B_WORK は `09b0ea34fe8b68d65a4933c58a6c16b80c7de1f3`。Git の操作は行っていない。以下の短い Lean モジュール名は `formal/Benitoite/Release/Refinement/<名前>.lean`、旧という指定は `formal/Benitoite/Release/` を指す。新設候補には「新」を付ける。署名中は `Benitoite.Release.Refinement` を開き、旧の `Qempty`・名前の型だけを共用する。

## 1. 入口の点検と既済み分の控除

| 前提 | 読んだ証拠と状態 | 起動への扱い |
|---|---|---|
| L20 | [段末](../l20/stage-results.md)。148単位、全置換・状態の葉・適格な旧46規則と状態の埋め込み。README 2026-11-03 で設計者が受け入れた | 完了分を引き継ぐ。捕捉の読まれる位置の限定、行支持、kind、正規化した入力を戻さない |
| L30 | [段末](../l30/stage-results.md)。79単位、35義務、688モジュール・67,907宣言の監査、work 159.00秒・終了0。README 同日で受け入れ済み | J30-2 の型域を含む `Ty.assume`・`ValueMeaning` と、U03 の規範を使う。旧の二条件の値の意味を復活させない |
| L40 | [段末](../l40/stage-results.md)、[義務](../l40/g/obligations.md)、[申し送り](../l40/g/handoffs.md)。40単位と群G再開3（L40.39）まで取り込み済み。独立未完0、全体閉鎖0。末尾の取りまとめの記録と RV-L40.g の再レビューを、冒頭の古い未実施表示より優先する | README 2026-11-04で設計者が段末を受け入れ済み。見直しの対象を含め技術的な受渡しを引き継ぐ |
| L40 の検査 | effort-ledger の正式な段末 work は456.52秒・終了0、最大常駐量2,931,425,280バイト。段末監査は999モジュール・79,156宣言、新公理・sorryAx 0 | 引用元の結果であり、今回再実行した結果ではない |
| 判断 | D08/D09/D20/D22/D24〜D29/D53〜D61/D67/D71、U01/U08/U09 の回答、U03、plan の変更記録を新しい順に確認 | U1・同じ要求・固定σは再選択しない。公開API/ScopeError の U02 は未確定として扱う |
| 段の順序 | L50 は葉、L60 は外部応答・通常資源・三モデルの最終構築、L70 は主定理・表層・全交換 | R10a 以降は L70 の完了後。Rust を先に直して Lean の規則を追認しない |

### 差し引く21項目

これは作業項目の数であり、定理の総数ではない。既済み分の所要時間は分離されていないので、架空の時間を控除しない。新規作業の積上げだけを第10節に示す。

| 控除 | 本番ファイルと確認した定義・補題 | 差し引く内容／L50 に残る接続 |
|---|---|---|
| C01 | ScopeSyntax：PathBase/PathEnv/RangeExpr/RangeIx/TargetInput/AtFailure/AtError | 既存の範囲構文を継承。全σの意味、内部保存の補完とU02後の公開写しは残る |
| C02 | PathResolution：PathEnv.Valid/lookup、RangeExpr.resolve/Mem、SnapshotMem、checkAt | 解決と判定の本体はある。被覆から全σでの所属保存、必要束縛から解決成功への証明が残る |
| C03 | Atoms：RangeExpr.Covers、RangeIx.Covers.inst、Atom.Covers.trans | 静的被覆の定義・反射・推移・具体化を再作成しない。意味上の健全性を足す |
| C04 | Adequate：SnapshotAdequate、Val/Comp/Closure/Store.Adequate、AdequateResult、SnapshotMem.current | 固定σへの適格性の相互定義と現在の所属への橋は済み。全型付き対象への逆転、具体δの充足が残る |
| C05 | HeldValues：Ty.Holds、Ty.LeQ.holds、inv_checked/inv_checkedRequest/inv_checkedAt | 芯と被覆を返す逆転は済み。旧の型全体の等号を返す署名へ戻さない |
| C06 | HeldValues：checkedRequest_content/request_mismatch、CheckedWitness.request_content、checkedAt_without_request | groundVal・同じreqTarget・内容の型と不正要求排除は済み。関数/節・実δ/IOへの利用が残る |
| C07 | HeldValues：checked_widen/checkedRequest_widen | 同じ値の scoped 共変は済み。opaque の互換API、全σ、Topを含む実入力へ接続する |
| C08 | AtPrepare/AtInput/AtTyping/AtSound：AtPrepared.request、Val.reqTarget_kind、CheckedWitness.of_prepared_request、checkAt.sound/absolute | RV-L00b.13 中2の三接続は既済み。新しく作った数へ入れない。篩付きPairの要求と実表への接続は残る |
| C09 | AtStateInputs：ClosureTy.at_inputs、AtCallAdmissible.closed_input/result_image | 捕捉から閉じた要求と同じ結果型を得る。元の型付けを新しい仮定として再掲しない |
| C10 | AtStateLeaves：StateTyE.at_ok_all/at_error_all/at_prepare_error_all | At三遷移の保存はある。成功/失敗の場合分けと hcurrent の供給、内部保存への整合とU02後の公開写しが残る |
| C11 | PathBasesLeaves：path_bases_apply_all/issue_path_bases_all | 発行二遷移の型保存はある。実署名・Process.Environment表・発行値とAtの同じσを結ぶ |
| C12 | Preparation/SourcePreparation：Required/Ready/InitialPrepared、InitialPrepared.source_state | 準備の定義と条件付きの開始接続はある。必要な束縛の供給、SourceからのAdequate、動的未束縛のErrorを閉じる |
| C13 | Source/SourceScope：Val.Source/SourceScoped、Comp.Source/SourceScoped | ソースからpathBases/checkedAt等を直接作れない定義はある。一般の型付きValが偽造不能とは述べない |
| C14 | TelApplication：TelClosure.apply；ApplicationInputs：primitive_contract_inputs、LeafInputs：externalRef_contract_inputs | F02はCtx.WFと元列Annotationを使い、P.WellFormed等の四前提を除いた実署名。F01〜F03の開始逆転を再作成しない |
| C15 | BuiltinResponse/ConstraintAssumptions：BuiltinArgs.normalized、ResponseAssumptions、TargetAgreement、CoreAssumptions、ShapeOk/PathBasesShape | 条件の移行は済み。条件を具体の表で証明する。欄名の一致を充足の証拠にしない |
| C16 | TargetTable：valContent/request_content/path_content/content_rows；ModelHttp：valueRun_checkedAt_request/valueRun_request | 同じ要求の射影と行支持はある。新しいvalKind・全署名・チェック/送信の応答表が残る |
| C17 | StandardKeyTyping：carrier/Table；StandardKeySummary：carrier_core/carrier_norm；StandardKeySoundの鍵の意味 | 骨格と有限宣言の鍵の証拠を利用する。開いた型の全sat/admits保存を既済みとはしない |
| C18 | L30のPreparedLeaf/TypedMeaning/NormalResultLeaves、L40のnormal_reply_facts・各Standard*Response、76実行葉 | 論理帰納、通常328API・演算子34行・decoder接続を再開しない。対象所属3sortと13範囲APIの応答を接続する |
| C19 | EffectFacts：Eff.Allows、Eff.allows_norm | 同じσの許容の定義と正規化の同値は既済み。F02はこの定義を使い、T07は継承する |
| C20 | CanonicalValues：HasTypeVQ.canonical_held、Ty.Holds.unique_name（HeldValues） | 包む3規則を含む29規則からopaque定数と保持3形への限定は既済み。F03は定数をConstOKで除き、三逆転とF01で所属を得る |
| C21 | BuiltinEffects：Builtins.ShapeOk.operation、CoreAssumptions.io_event_covered/io_transition_covered/pathBases_event_covered/pathBases_transition_covered | IO・発行の宣言効果による事象の被覆は既済み。L50は実表のShapeOk/PathBasesShapeと同じσの許容F02/F05を供給する |

`formal/Benitoite/Checked/Scope.lean` の makeHost/makePath/makeEndpoint と成功・失敗・消去、`Scope/RangeCover.lean` の Range.Covers.sound/sound_memK は継承する。旧の covers_iff を記号付き範囲の全σの完全性へ拡張しない。

## 2. 規則・構成子・葉の母集団

場合の数は異なる母集団を区別する。同じ葉を複数の義務が使っても証明の件数を増やさない。以下の各行を群K/Lの照合で一行ずつ判定する。

| 族・出どころ | 全場合と数 | 補題・単位 |
|---|---|---|
| RangeExprの二項被覆 | absolute/based/secretsの直積9場合。Topによる拡大を先に分け、absolute同士は旧Rangeの4×4＝16場合を継承 | F01、.06〜.08。起点を跨ぐ拒否は.52 |
| basedのPathPattern | exact/exact、exact/tree、tree/exact、tree/treeの4場合。baseはroot/cwd/home/work/tmpの5構成子、等号と不等号を分ける | append_cover、.06/.07。25起点組を巨大な具体値で評価せず等号の場合分けで扱う |
| RangeIxとAtom | fixed/rvarの直積4、name-fixed/name-rvar/rhoの直積9。成功する対はそれぞれ2・3。短い具体化列はrvarを残しTopにしない | F01/F02、.08/.09。構文側のinstはC03を継承 |
| 解決 | lookupは5場合（必須3、任意2）。RangeExpr.resolveは3場合、TargetInput.resolveはabsolute/relativePath/homePathの3場合 | F06、.16/.18。work/tmpのnoneとsecretsの未指定/空/非空を分離 |
| Checked小モデル | makeHost 4葉、makePath 4葉、makeEndpoint 7葉、計15葉（各成功1と順序付き失敗3/3/6） | 既済み。旧純粋チェックとAtを.19/.24/.25で区別 |
| 値の型付け | Typingの29規則。保持導入3（V_Checked/Request/At）、包む規則3（V_Sub/Normal/Refine）、その他23。CheckedWitnessはplain/requestの2構成子 | C20で四形へ限定済み。F03を.02で証明し、.11/.12で読者へ接続 |
| 値構文 | Valの25構成子を一度ずつ照合。target?を持つ3構文と、checkedAtのrequest none/someを区別 | .11/.12/.14。checkedAtのsnapshot none/someはC04の二場合へ帰着。全25構文の照合はC20を利用 |
| U1 | scopedの共変、scoped_forgetの2規則。保持plain/request×checked/checkedAtの4導入経路。Request側のcheckedはcheckedRequestを指す | .13/.15/.26/.27。opaque全体の新しい共変規則は足さない |
| U1の位置 | 直接、明示拡大、関数値、callback、ADT/List格納、Reference/Lazy、節/resumeの7行。名前/個数・同じreq/endpoint/σを保持 | F03/F04/F08、.15/.51。既存の置換/格納/保存葉を利用 |
| Atの判定 | checkAtは解決失敗3、invalidTarget、invalidPattern、dynamicCondition、staticIndex、okの8葉 | F06、.18/.20。typed indexの準備時staticIndex排除と、実際のbound不所属によるstaticIndexは別 |
| AtFailure | outsideScope/unbound/secretsUnbound/invalidPattern/invalidTarget/dynamicCondition/staticIndexの7構成子。unboundの引数を5baseへ展開すると11形 | .20/.53。outsideScopeを消さず、動的条件と静的添字の失敗を別に保存 |
| At/PathBasesの実行 | E_PathBasesApply、E_IssuePathBases、E_AtOk、E_AtError、E_AtPrepareErrorの5葉 | C10/C11を控除。.17/.18/.54は開始入力とhcurrent、発行・型・事象の接続を補う |
| IOShape | untargeted/topTargeted/singleの3形。singleの型付き入力でtarget?=noneになる枝は排除 | F04/F05、.14/.23/.35/.50。全Valの無条件shape一致を要求しない |
| IOのOutcome | val/err/exitの3枝。範囲IO7行ではvalとerrが許され、exitはio_kindで排除。Result.Ok/Errorはvalの中の2構成子 | .31〜.35。応答存在を正常応答存在へ強めない |
| 実行の応答読者 | E_Prim/E_Err、E_IO/E_IOErr/E_Exit、E_OpPrimの6葉 | .28/.35/.54。L20の状態保存・oracle選択を利用し、全76葉の主定理はL70 |
| 標準表 | 範囲位置を持つ13API＝IO7＋純粋6。Reference.get/setの2行とPathBases発行1行を足した共通表は16行 | .21〜.35。Atは専用Compであり純粋6行へ重複計上しない |
| 三モデル | 新Model 3行、新ModelTargets 15行、新ModelHttp 7行、延べ25署名行（共有行を含む）。第4節の25条件×3モデル＝75充足欄 | .36〜.50。新しい表の案であり、旧の署名件数2/7/5とは区別。L60の外部3＋release1を各モデルへ残す |

### 被覆9対、値29規則、At8葉の内訳

次の表は第2節の母集団の内訳であり、場合数へ再加算しない。

| outer / inner | absolute | based | secrets |
|---|---|---|---|
| absolute | 旧Range.Covers.sound。Topを含む／.07 | Topだけ可／.07 | Topだけ可／.07 |
| based | 不成立／.07 | 同じbaseで4PathPattern対の被覆／.06/.07 | 不成立／.07 |
| secrets | 不成立／.07 | 不成立／.07 | 同じ一覧の自己被覆／.07 |

| HasTypeVQの規則（全29、括弧内は個数） | F03の処理 | 単位 |
|---|---|---|
| V_Checked（1） | inv_checkedとF01から任意σの所属 | .02/.11 |
| V_CheckedRequest（1） | inv_checkedRequestとF01。同じreq/endpointも保持 | .02/.12 |
| V_CheckedAt（1） | inv_checkedAt、SnapshotMem.currentとF01 | .02/.11/.12 |
| V_Sub（1） | C20のcanonical_heldが包む規則を処理済み | .02で利用、.11で照合 |
| V_Normal（1） | C20で処理済み | .11で照合 |
| V_Refine（1） | C20で処理済み。factsの既存読者を維持 | .11で照合 |
| V_Var（1） | C20の空Γで排除済み | .11で照合 |
| V_Const（1） | C20で残るopaque定数をunique_name・ConstOKとvalKindの矛盾で排除 | .02 |
| V_Lam/V_DependentLam/V_Closure/V_Fun/V_Prim/V_Op/V_ExternalRef/V_Raise（8） | C20で排除済み | .11で照合 |
| V_ExternalHandle（1） | C20で排除済み | .11で照合 |
| V_PathBases/V_ScopePattern（2） | C20で排除済み | .11で照合 |
| V_AtError/V_Con（2） | C20で排除済み。AtErrorの内部保存の読者は.53 | .11/.53 |
| V_Map/V_Set/V_Bytes/V_List（4） | C20で排除済み | .11で照合 |
| V_Dict/V_Super（2） | C20で排除済み | .11で照合 |
| V_LocRef/V_LocLazy（2） | C20で排除済み。資源存在はL60 | .11で照合 |

Valの25構文の一覧は `var,const,fnRef,prim,lam,dependentLam,closure,con,list,op,raise,loc,mapV,setV,bytesV,dict,super,externalRef,externalHandle,pathBases,scopePattern,checkedAt,atError,checked,checkedRequest` である。各々を上表の直接規則へ対応させる。locだけは二直接規則、残り24構文は各一直接規則で、直接26＋包む規則3＝29となる。checked/checkedRequest/checkedAtの3構文はtarget?成功、その他22構文は上表の排除へ対応する。C20を利用するF03を.02で証明し、.11で全構文の対応と実読者を照合する。

| checkAtの葉 | 条件と返却 | 補題/単位 |
|---|---|---|
| A01 | patternのresolveSnapshot=none → missingRange pattern | 解決成功/失敗の分解、.16/.18 |
| A02 | targetのresolveTargetSnapshot=none → unbound targetBase | .18。現行TargetInputの入力では到達可否を別に確認し、定義の枝を消さない |
| A03 | boundのresolveSnapshot=none → missingRange bound | .16/.18 |
| A04 | targetのWF又はkind不適合 → invalidTarget | .18/.20 |
| A05 | pattern/boundのWF又はFitsKind不適合 → invalidPattern | .18/.20 |
| A06 | 動的patternへの不所属 → dynamicCondition | .18/.20 |
| A07 | 静的boundへの不所属 → staticIndex | .18/.20。型付きindexのWFによる準備時の排除と混同しない |
| A08 | 両方に所属 → ok t | 既存checkAt.sound/absolute→CheckedWitness→at_ok_all、.18 |

AtPrepareの内訳も固定する。indexはrvar/fixedの2場合。fixedではpattern parseのnone/some、contentのnone/some、要求のgroundVal/reqTarget、basesのnone/someと閉じたpathBases/その他、snapshot.Valid、finishPreparationのvalKindとbound形成、snapshotなしのbased/secrets/relative/homeを順に分ける。全てを平坦な直積へ展開せず、実装の判定順を保つ。これらの失敗はE_AtPrepareError、成功は上の8葉からE_AtOk又はE_AtErrorへ対応し、.17/.18/.20が受け持つ。構造の追加なしに場合の表を閉じられることを群Dの条件とする。

局所的な判定の葉も次の23個へ対応させる。これは中間の成功とErrorの伝播を含む局所の一覧であり、checkAtとの直積の母集団にはしない。共通のfinishPreparationを分岐元ごとに二重計上せず、各局所関数の葉として数える。

| 局所の判定 | 葉の一覧 | 数 | 単位 |
|---|---|---:|---|
| AtPrepare | rvarのError、fixedでprepareCoreのError、fixedでprepareCoreの成功 | 3 | .18 |
| pattern parse | noneのinvalidPattern、someの次の判定 | 2 | .18/.20 |
| 入力のparse/ground | contentなしでparse none/someの2、contentありでground不成立/reqTarget none/reqTarget someの3 | 5 | .18/.25 |
| bases | noneでsnapshotなし、someで閉じたpathBasesかつValid、pathBasesかつ非Valid、その他の値 | 4 | .17/.18 |
| finishPreparation | valKind不適合、bound形成不適合、snapshotなしでpattern based/secrets・target home/relative・bound based/secretsの6、残りの成功 | 9 | .18/.20 |
| 計 | 中間判定と伝播を含む局所の一覧 | 23 | .18で照合 |

準備と検査の接続は、局所23葉とは別に次の母集団で照合する。出どころは`AtPrepare.lean`の`AtPrepare`・`prepareCore`・`finishPreparation`、`PathResolution.lean`の`checkAt`である。以下は定義の判定順を読んだ集計であり、全経路の証明済み件数ではない。

| 接続の母集団 | 内訳 | 数と行き先 |
|---|---|---|
| 準備の失敗の終端 | rvar 1、pattern parse失敗1、入力のparse失敗/非ground/reqTargetなし3、basesの非Valid/別の値2、finishPreparationのvalKind/bound形成/起点等の拒否8 | 1＋1＋3＋2＋8＝15葉。各々E_AtPrepareErrorへ。prepareCoreのError伝播を別の終端に数えない |
| 準備の成功 | contentなしでparseAtInput成功、contentありでgroundかつreqTarget成功の2経路 × basesなし、有効なpathBasesありの2経路。pattern parseとfinishPreparationの成功を共通条件とする | 2×2＝4経路。各経路からcheckAtのA01〜A08を経てE_AtOk/E_AtErrorへ |
| 接続の上限 | 失敗15葉＋成功4経路×検査8葉 | 15＋4×8＝47。実際の到達可能な数と排除の根拠は.18で確定 |

snapshotなしの準備成功では、pattern/boundのbased・secretsとtargetのhomePath/relativePathがfinishPreparationで拒まれるため、checkAtの未解決の枝へ進めない。有効snapshotありでもtargetの解決は成功する。これらは4経路のそれぞれで到達可否と排除の実定理を記し、checkAtそのものの8葉を削除しない。型付きindexでは準備時rvarのstaticIndexを`AtPrepare.no_staticIndex`で除く。成功時には同じsnapshotと実行σの一致（snapshotなしは自明）を.17から供給し、三At遷移へ接続する。

### 13 API の実名と原署名

`PathIn i = opaque "Scope.PathIn" (rvar i)`、`RequestIn i = opaque "Http.RequestIn" (rvar i)`。いずれも同じ範囲変数を効果へ使い、IOShape.singleの位置は0である。結果のopaqueは資源等の従来の名前であり、対象のPathIn/RequestInの裸opaqueとは区別する。

| API | 引数名と型（宣言順） | 結果／効果／範囲の種類 | 単位 |
|---|---|---|---|
| File.readTextIn | path:PathIn 0 | Result[String,IOError] / File.Read[R0] / path | .31 |
| File.readBytesIn | path:PathIn 0 | Result[Bytes,IOError] / File.Read[R0] / path | .31 |
| File.writeTextIn | path:PathIn 0,text:String | Result[Unit,IOError] / File.Write[R0] / path | .32 |
| File.writeBytesIn | path:PathIn 0,content:Bytes | 同上 | .32 |
| File.appendTextIn | path:PathIn 0,text:String | 同上 | .33 |
| File.appendBytesIn | path:PathIn 0,content:Bytes | 同上 | .33 |
| Http.sendIn | request:RequestIn 0 | Result[Http.Response,NetworkError] / Http.Connect[R0] / endpoint | .34 |
| Scope.checkPathIn | pattern:String,path:String | Result[PathIn 0,Scope.ScopeError] / empty / path | .24 |
| Http.checkRequestIn | hostPattern:String,minimumPort:Integer,maximumPort:Integer,request:Http.ClientRequest | Result[RequestIn 0,Http.RequestCheckError] / empty / endpoint | .25 |
| Scope.pathInValue | path:PathIn 0 | String / empty / path | .26 |
| Http.requestInValue | request:RequestIn 0 | Http.ClientRequest / empty / endpoint | .27 |
| Scope.widenPathIn | path:PathIn 0 | PathIn 1 / empty / path,path、R1.Covers R0 | .26 |
| Http.widenRequestIn | request:RequestIn 0 | RequestIn 1 / empty / endpoint,endpoint、R1.Covers R0 | .27 |

この13行は旧TargetTable.entriesの範囲部分である。ScopeErrorの内部宣言とPathBasesの内部名は.04/.05/.20、公開名と公開写しはU02後・L70前に固定する。

## 3. 先に固定する署名と証明の順序

F01〜F10は新しい葉の契約の案である。全変数を量化し、量化の範囲をTop・空ストア・旧導出だけへ限定しない。`HasTypeV`の空C/Γ/Φは実行時の閉じた入力という既存契約であり、開いたソースの受理範囲を狭める条件ではない。開いた関数は既存CaptureOk/TelClosure.applyから閉じてこの入口へ渡す。

### F01: 全σの被覆と所属

```lean
theorem PathPattern.covers_atBase (w : Scope.Domain.Word)
    {p q : Scope.Domain.PathPattern} (h : p.Covers q) :
    (PathPattern.atBase w p).Covers (PathPattern.atBase w q)

theorem RangeExpr.Covers.mem {outer inner : RangeExpr}
    (h : outer.Covers inner) (σ : PathEnv) {k : Scope.Domain.Kind}
    {t : Scope.Domain.Target} (hm : inner.Mem σ k t) : outer.Mem σ k t

theorem SnapshotMem.mono {snapshot k r s t}
    (h : SnapshotMem snapshot k r t) (hc : s.Covers r) :
    SnapshotMem snapshot k s t
```

RangeExpr.Covers.memとSnapshotMem.monoはσ.Validを仮定しない強い形を採る。RV-L50-planの再現入力で両式の証明を確認でき、全有効σも含む。none snapshotでrがabsoluteの場合、sがbasedになる被覆はなく、TopもabsoluteなのでSnapshotMemの条件を保てる。逆向きの完全性を足さない。

### F02: 効果の許す対象

既存`EffectFacts`の定義を使う。`EffectTargets`（新）へ置くのはEff.Covers等の意味の読者だけである。静的判断にσを足さない。

```lean
-- 既存の定義（再宣言しない）
def Eff.Allows (σ : PathEnv) (κ : EffName → Option Scope.Domain.Kind)
    (e : Eff) (l : EffName) (t : Scope.Domain.Target) : Prop :=
  ∃ k r, κ l = some k ∧ e.mem (.name l (.fixed r)) ∧ r.Mem σ k t

theorem Eff.Covers.allows {Γ Φ e f σ κ l t}
    (h : Eff.Covers Γ Φ e f) (ha : Eff.Allows σ κ f l t) :
    Eff.Allows σ κ e l t
```

C19のEff.allows_normを継承し、union/empty/型・行・値のbind/範囲instの読者を置く。Failの型は対象を許す原子として数えない。型/行像に値依存がある場合も、置換の後にbindで正規化する。openなΓ/Φの事実を外部の意味仮定へ置き換えない。

### F03: 型付き保持値から同じ対象と要求

```lean
theorem HasTypeVQ.target_member {P B Ψ Q v T o k r σ}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (ha : v.Adequate σ) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t
```

C20のcanonical_heldで四形に絞る。opaque定数の枝はinv_constのConstOK、Ty.Holds.unique_name、hkの矛盾で除く。残る保持三形はinv_checked三本を使い、絶対所属又はSnapshotMem.currentからF01へ進む。F01の必要な補助を.02で先に証明してF03を閉じる。.06〜.08では同じ証明を作り直さず全場合と読者を接続する。target.WFはこの署名に足さない。V_Checkedの前提はMemKであり、常にWFまで返すとは確認できていないためである。要求の二経路は既存`checkedRequest_content`と`ModelHttp.valueRun_checkedAt_request`の実署名を使い、同じreqの型・groundVal・reqTargetを結論する。旧eq_of_not_fnや全型の等号に依存しない。

opaqueの互換拡大は、F03の証人から元のscopedの導出を再構成し、`.scoped`と`.scoped_forget`で同じvを目的型へ渡す形を先に確認する。一般の`Ty.LeQ (opaque o r) (opaque o s)`を新設しない。

### F04: 全型付きsingle呼出しのshape

```lean
theorem Builtins.ShapeOk.single_target {P B Ψ b sg ts es rs ws a e k p σ}
    (sh : B.ShapeOk b sg) (single : sg.shape = .single k p)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ) :
    ∃ r t, rs = [r] ∧ (ws[p]?).bind Val.target? = some t ∧
      r.Mem σ k t ∧ sg.shapeAt ws = .single k p
```

署名の対象引数はopaque。実値はscoped_forgetから受ける。p=0だけへ一般補題を限定せず、同じ依存列の途中の引数もlookupで取り出す。F3で変更した関数の入力はTelClosure.applyから元列へ戻す。F04が偽なら、主定理やShapeOkへ新条件を加える前に.02で止めて反例を示す。

### F05: 同じ応答の観測と許容対象

```lean
theorem Builtins.TargetAgreement.obs_allowed {P B Ψ b sg ts es rs ws a e out obs σ}
    (hsh : B.ShapeOk b sg) (ht : B.TargetAgreement P)
    (hs : B.sig b = some sg) (hkind : sg.kind = .io ∨ sg.kind = .exit)
    (ha : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : B.ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ B.effKind e l t
```

untargetedは空、topTargetedは同じkind、singleはF04から同じ保持対象一つ。必要な前提はShapeOkとTargetAgreementに分け、未構成のCoreAssumptionsを要求しない。.35/.45は実表のShapeOkから適用できる。これは一回の呼出しの葉であり、継続の末尾Ebへの伝播・一段/到達/表層の主定理はL70に残す。

### F06: 準備とAtの全分岐

```lean
theorem PathEnv.Ready.resolve_required {P B σ s r}
    (ready : σ.Ready P B s)
    (reach : PreparationNode.Reachable P B (.state s) (.range r)) :
    ∃ rs, r.resolve σ = some rs

theorem AtPrepared.current {P B σ Ψ R Γ Φ cap kind name shape bs p v ix snap pat t bound}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (had : cap.Adequate σ)
    (hb : ∀ b, bs = some b → b.Adequate σ)
    (hp : AtPrepared B cap kind name bs p v ix snap pat t bound) :
    ∀ ρ, snap = some ρ → ρ = σ
```

currentのbsの適格性は`StateTyE`の`Closure.Adequate`から供給する。hbとhcのうち証明に不要な前提は.02/.05の固定前に除く。供給元のないReadyを全StateTyEへ足さない。既知契約の準備成功と、動的入力のErrorの存在を別に証明し、checkAtの結果を全分岐する補題からC10の三遷移へ渡す。発行二遷移と合わせても主定理の閉鎖を行わない。

### F07: 具体δとIOの応答

externalRef・externalHandle・scopePattern・atErrorを返す場合も、全有効σの`AdequateResult`を示す。受け口はScopeResponse.adequate_externalRef/adequate_externalHandle/adequate_scopePattern（.28）とAtTargets.adequate_atError（.53）とする。各署名は構成子vの全引数と任意wsを量化し、`AdequateResult ws (.val v)`を返す。外部呼出しの応答三条件はL60へ残す。

各純粋行は`ResponseAssumptions.delta_typed`の当該bの完全な量化（Ψ/sg/ts/es/rs/ws/a/e）を持つ定理を置く。結論は同じ`B.delta b ts es rs ws = some out`、全nで非exit、`Outcome.Typed P B Ψ out a`、`AdequateResult ws out`。groundな返却値は別の補題で供給する。

各IO行は同じ`BuiltinArgs`から、実際に定義した`ioResponse`の全out/obsに対して`Outcome.Typed`・`AdequateResult`、io_kind、`ShapeTargets`を証明し、同じ関係の応答を少なくとも一つ構成する。Result.Errorも応答である。全応答を型付き関係そのものとして定義して証明を循環させず、Ok/Errorの具体の構築と事象の観測を先に定義する。旧モデルのような小さい非決定的応答関係は許すが、実IOの成功や完全な外部状態を模型へ追加しない。

### F08: U1の受渡し

各APIの入力の型は第2節の原署名を使う。D09の直接/明示拡大/関数値/無制約Top/比較不能の5行を区別する。L50は具体化後の実依存列、同じws、原署名と一度決めたrsの関係を証明する。入力の推論手続きの選択はR10b/R30で独立期待と比較する。結果型又は許容効果からrsを逆算する補題は置かない。

### F09: モデルの構築

新しい`ModelScopeConditions`（新、定義の形は第4節）は、既存の条件の命題をまとめた**証明の出力**とする。新しい主定理の入力や公理にしない。各モデルの同じP/Bについて、SubstitutionAssumptions、ResponseAssumptions、TargetAgreementとCoreAssumptionsのうちrelease_exists以外の13欄中12欄を構成する。L60はこの証拠とexternalの3欄・release_existsを組み合わせて全CoreAssumptionsを作る。通常資源とexternalの区別はL60で閉じる。

F09の出力の定義の形は次である。既存Coreの欄の型を変えずに写した案であり、新しい条件を仮定する構造体ではない。これを実装する担当は各欄の証明を具体の表から構成する。

```lean
structure ModelScopeConditions (P : Program) (B : Builtins) : Prop extends
    Builtins.SubstitutionAssumptions P B,
    Builtins.ResponseAssumptions P B,
    Builtins.TargetAgreement P B where
  sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s
  sat_unconstrained : ∀ t : Ty, t.WF 0 0 0 → B.sat [] t.norm ({} : TParam)
  admits_sat : ∀ b s C ts, B.sig b = some s →
    s.admits (TypeCtx.constraints C) (Ty.normTys ts) →
    SatAll B C ts (s.tparams.map TParamDecl.constraints)
  pathBases_shape : ∀ b s, B.sig b = some s → s.kind = .pathBases →
    s.PathBasesShape B b
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    B.ShapeOk b s
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
      s.opEff = some l
  state_effect : B.effects stateEff = some []
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
  store_shape : ∀ b s, B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts
```

この出力からCoreへ進むために残る入力は、**同じP/Bの既存ExternalAssumptionsとrelease_existsだけ**である。新しい無検査の前提を加えない。モデルの入口は `Model.scopeConditions (P)`、`ModelTargets.scopeConditions (P) (hP : ScopeDeclarations.HasFile P)`、`ModelHttp.scopeConditions (P) (hP : ScopeDeclarations.HasHttp P)` を案とする。HasFile/HasHttpは第4節の有限な宣言一覧の各lookup・arityと一致する命題として定義し、その成立する具体のPも.22/.42/.47で構成する。未検査の「型付き結果がある」という欄は含めない。Pを読む必要のない欄へHasFile/HasHttpを増やさず、.05で実型を固定する。

### F10: D61の内部保存と公開形の境界

L50は元の生入力と解析済み入力を区別し、解決後の複数原子・対象・両起点・失敗種別を切り詰めず内部に持つ。解析失敗は解析済み欄のnoneで表し、元入力を.topや空パスで代用しない。reprStrを保存値にしない。内部の形と保存の等号を.04で固定し、.20で実装、.53で全失敗と読者を照合する。

公開PathBases・At・ScopeErrorの名前・完全署名・観測形への写しは、U02確定後・L70前に取りまとめが割り当てる。L50はその回答に依存する部分を実装しない。既存の七String観測は暫定の内部読者として追随させるだけで、公開写しの完了証拠にしない。表示の引用/エスケープ/4096バイト上限と保存値の非切詰めはD61のまま保つ。二案の材料は[u02-options.md](u02-options.md)に置く。

## 4. 表とモデルの境界

新TargetTableは既存valContentを拡張し、旧valKindと同じ2名の分類を置く。共通16行の署名・RangeAdmissible・effect表・純粋δと7IOの応答を一つのlookupへ接続する。Resultのarity2、Http.ClientRequestのarity0、Pairのarity2、ScopeErrorとRequestCheckError、Ok/Error等の引数位置を同じPが持つことを、有限宣言の等号とlookupから証明する。`sig_scoped`をPの条件なしで全Pへ述べない。

モデルの署名集合の案は、ModelがReference.get/setと発行、ModelTargetsが旧7行にFileの残り5行・pathInValue・widenPathIn・発行を足した15行、ModelHttpが旧5行にwidenRequestIn・発行を足した7行である。共通表の全行の照合と、三モデルの一部のlookupの照合を混同しない。モデルのPへ通常標準328APIを一括収集する作業はL60/L70の元の担当に残す。

| 充足する既存条件 | 一モデルの欄数 | 作業 | L60へ残すもの |
|---|---:|---|---|
| ValueAssumptions：sat_rename/admits_rename/sat_values/admits_values | 4 | .29/.36/.41/.46。篩の述語と値番号を読まない骨格で実証 | 各モデルの証拠を再利用 |
| TypeAssumptions：sat_renameTypes/admits_renameTypes/sat_subst/admits_subst | 4 | .29/.30/.36/.41/.46。TypeParamRenaming、型像の篩、行の正規化を含む | 同上 |
| ResponseAssumptions：delta_typed/io_typed/io_kind/io_exists | 4 | .28/.31〜.35、モデルの.37〜.49 | externalの応答をここへ混ぜない |
| Coreの表の条件：sig_scoped/sat_unconstrained/admits_sat/pathBases_shape/io_op/opEff_io/effect_ops/state_effect/ref_get/ref_set/store_shape/store_admits | 12 | .21〜.23/.30、.37〜.49。全署名と同じeffectsのmembershipを確認 | release_existsの1欄 |
| TargetAgreement.io_target | 1 | .35/.40/.45/.50。型付き入力全域とshapeAt | external_no_targetsと区別 |
| 計 | 25×3＝75 | .50で一欄ずつ実定理を記録 | external_typed/exists/no_targetsの3欄×3＋release_exists×3＝12欄 |

satの候補は`StandardKeyTyping.carrier`と同じ有限宣言からの`Release.satB`を使う。Failの順序・重複・長さや自由値番号を読まない。既存のcarrierは関数等を拒否する関数型の骨格へ写すので、その定義を読んだだけでは開いた型への全保存を結論しない。.03で非空制約のtvar、二つの像の衝突、値依存を持つ型/行像、Failの重複が正規化で消える例を確かめ、.29で一般化する。sat=Trueの小例だけで75欄を閉じたと記録しない。sat/admitsの意味を主な判断側で変える必要が出れば停止条件へ戻る。

旧モデルの自由なreqTarget引数は、新ModelHttpへそのまま残さず本番`Val.reqTarget`に固定する。成功時はcheckedRequest又はcheckedAtが持つ同じreqを射影し、IOもそのendpointを使う。F3・篩による新受理を旧のgroundTy/旧Ty.Leで制限しない。

## 5. 起動単位とレビューの群

表のLは途中の局所Lean、Wは群末の作業末検査、RVは取りまとめによる群末レビューを示す。コマンドの正は第11節だけに置く。対象に「新」がない短名は既存である。モデル名の「新」は旧Releaseのモデルと別名前空間へ置く意味である。各単位の署名はF番号と第2/4節の有限表で定まる。完全な型の印字を.05で保存し、型/欄/引数を後から変えるときは取りまとめへ返す。

| 単位/群 | 目的 | 触るファイル | 完全署名又は定義の形 | 手順と完了条件 | 依存 | 所要時間（能動時間） | 検査 |
|---|---|---|---|---|---|---:|---|
| L50.01/A | 入口と母集団を固定 | 本書・段末表（文書） | C01〜21、義務33行、H表 | 前段の受け入れとC19〜C21の既存名を照合。重複定義/証明を除き、全場合の受け口を確定 | L40の結果 | 30〜45分 | L |
| L50.02/A | 保持所属とshapeを証明 | ScopeCoverage/MembershipTargets/ShapeTargets（新） | F01の所属補助、F03/F04、F06.currentの型 | F01の必要補助→C20で四形へ→ConstOKで定数排除→三逆転とF01でF03を証明。同じtelの任意pをlookupし、scoped_forgetとF03から任意Ψ/非TopのF04を証明。一般の型/値代入の処理もここで閉じ、.14では再証明しない。供給不能なら停止 | 01/C19/C20 | 60〜105分 | L |
| L50.03/A | 骨格と三モデルの方式 | ModelConstraints/TargetModelConditions（新） | F09、carrierとsatB、25欄の出力 | 非空制約・型/行像・Fail縮約で八保存則の形を確かめる。Trueだけの模型へ戻さず、実表のarity条件を固定 | 01 | 60〜120分 | L |
| L50.04/A | 内部保存の方式とU02材料 | ScopeSyntax/AtPrepare/AtContracts（内部の候補変更） | F10、元入力/解析済み入力/解決結果 | 仮入力/reprStrと全読者を棚卸し→内部保存の形と等号を固定。公開二案の材料だけを用意し、U02依存部分は実装しない | 01 | 30〜60分 | L |
| L50.05/A | 完全署名と配置を確定 | 群Aの署名・読者表、既定import | F01〜F10の型、モデル25欄 | F01〜F10の完全署名/定義形を型検査し供給元を固定。F03/F04は証明を要求。公開写しをL70前の別作業に明記し群を閉じる | 02〜04 | 35〜60分 | L・W・RV |
| L50.06/B | 起点付加の被覆 | ScopeCoverage（新） | F01.covers_atBase、4場合 | 02のF01補助を再利用し、記号のWordとappendの結合則で4場合と実読者を閉じる。base/末尾を大きな具体列に展開しない | A | 30〜55分 | L |
| L50.07/B | RangeExprの全σ被覆 | ScopeCoverage（新） | F01.RangeExpr.Covers.mem、9場合 | 02の所属補助へ全9対を対応させる。Top→absoluteの旧sound→同base→secretsの読者を接続。異なる起点を解決先で同一視しない | 06 | 40〜75分 | L |
| L50.08/B | snapshotと範囲具体化 | ScopeCoverage/MembershipTargets（新） | F01.SnapshotMem.mono、RangeIx二種 | 02のmonoをnone/some双方の読者へ適用→同じsnapshotで所属を拡大。Pred.memberの3sortと範囲instへ渡し、短い列を拒否/未具体化のまま保つ | 07 | 35〜60分 | L |
| L50.09/B | 既存Eff.Allowsの読者 | EffectTargets（新）・EffectFactsは利用 | F02、union/empty/bind/inst | C19を再宣言せずAtom9対→一原子の被覆→同じσのAllowsへ。normは既存証拠を利用し、Failとbindの正規化を保持 | 07/08/C19 | 35〜65分 | L |
| L50.10/B | 最初の本番13移植を照合 | ScopeCoverage/EffectTargets・移植表 | T01〜T14の14目的、T07は継承 | 新移植13目的とT07の継承1を区別し、供給側で満たす行も実名で記録。通常結果から残件/時間を更新 | 06〜09 | 25〜45分 | L・W・RV |
| L50.11/C | 保持対象の全場合と読者 | MembershipTargets（新）・CanonicalValues/HeldValuesは利用 | 証明済みF03、29規則/25構文 | C20と.02のF03を全規則/構文へ対応させ、任意Ψ/Topを含む対象3sortの読者へ接続。導出の帰納と23規則の排除を作り直さない | B/02 | 20〜35分 | L |
| L50.12/C | 同じ要求とendpoint | MembershipTargets/ModelHttp（既存利用） | F03のRequest二経路 | checkedRequestとcheckedAt(some req)を同じreqの型/groundVal/reqTargetへ。Pairの篩/trueを含む受理対照と不一致拒否を置く | 11 | 35〜60分 | L |
| L50.13/C | opaque互換拡大 | MembershipWiden（新） | F03、同じvの目的scoped/opaque型 | 既存のscoped導出を逆転から再構成→F01→scoped_forget。widen APIと節の添字への列移送を閉じる。新しいopaque共変規則は作らない | 11/12 | 45〜90分 | L |
| L50.14/C | 依存引数列とsingle対象 | ShapeTargets（新） | F04、任意の位置p | 02の証明済みF04を、型/値代入後の実読者へ適用し、同じws・opaqueの位置・要求/endpointの受渡しを照合。任意pのlookupとF03による一般証明を複製しない | 02/11/13 | 20〜40分 | L |
| L50.15/C | F3とU1の位置の受渡し | ScopedCallContracts（新） | F08、位置7行・D09の5行 | TelClosure.applyの実署名で同じwsを原列へ戻す。入力の具体化を一回に固定し、結果/許容効果からの逆算を入れず群Cを閉じる | 12〜14/C14 | 35〜60分 | L・W・RV |
| L50.16/D | 必要束縛と初期準備 | PreparationTargets（新）・Preparationは利用 | F06.resolve_required、Required二構成子 | Reachableからbase/secretsを取り出す。work/tmpと未指定/空一覧を区別→SourceからAdequateを供給しInitialPrepared.source_stateへ | B/C12/C13 | 35〜60分 | L |
| L50.17/D | 発行と同じσのAt | PreparationTargets/PathBasesTargets（新） | F06.current、C11の二遷移 | typed basesをclose→Val.Adequateからsnapshot=σ→AtPrepared.currentへ。発行はProcess.Environmentの同じmembership。既存二保存葉を再証明しない | 16/14 | 45〜90分 | L |
| L50.18/D | At全分岐から既存の葉 | AtTargets（新）・AtStateLeavesは利用 | checkAt8葉、At/発行5遷移 | 同じ準備結果をok/errorへ分け、型付きindexで準備時staticIndexを排除。準備失敗の終端15葉をE_AtPrepareErrorへ、成功4経路を各checkAt8葉からE_AtOk/E_AtErrorへ対応させる（15＋4×8を上限）。到達不能の根拠と実際の数を記し、三At保存葉へhcurrentを供給。動的未束縛はErrorを構成 | 16/17 | 40〜80分 | L |
| L50.19/D | 旧純粋APIとAtの分離 | ScopeLegacyContracts（新） | F06/F07、絶対noneとAt some σ | 旧checkPath/checkPathInの相対形を拒否又は明示Errorにする。Atはcwd/home、パターンはroot。同じ絶対射影と純粋効果を照合 | 18 | 35〜60分 | L |
| L50.20/D | D61の内部保存を実装 | ScopeSyntax/AtPrepare/AtContracts/内部読者 | F10、失敗7構成子/11形 | 04の内部形を実装。全準備失敗で元入力を保存し解析欄noneを区別。解決結果/両起点/複数原子を保持し、既存読者だけ追随。公開写しはU02後 | 04/18/19 | 40〜75分 | L・W・RV |
| L50.21/E | 共通16署名とvalKind | TargetTable拡張・ScopeSignatures（新） | 第2節13API＋ref2＋発行1 | 原署名/実名/効果/対象位置/valContent/valKindを一行ずつ定義。PathBases名は05の内部名を使う。範囲APIを分類だけで終えない | A/D | 35〜60分 | L |
| L50.22/E | 同じ宣言の形成 | ScopeDeclarations（新） | P.DataArity、PrimSig.Scoped全16行 | Result/Pair/Request/両Errorの有限宣言を作り同じPのlookupからkinds/declared/sourceTelRowsを供給。Pの形成を仮定だけで済ませない | 21 | 60〜120分 | L |
| L50.23/E | 効果表とShapeOkの全行 | ScopeSignatures（新） | ShapeOk3形、PathBasesShape8欄 | 各IO名を同じeffectsリストへ登録。target引数はopaque、rkinds/retの位置も照合。発行をioResponseへ混ぜない | 21/22 | 40〜60分 | L |
| L50.24/E | 旧checkPathInの具体δ | ScopeDelta（新） | F07、絶対入力と静的range | 既存Checked.ScopeとparseAtInputを使い成功/形式失敗/動的不所属/静的不所属を同じResultへ。basedの静的添字を旧純粋APIへ黙って通さない | 19/20/22 | 45〜90分 | L |
| L50.25/E | checkRequestInの具体δ | RequestDelta（新） | F07、固定Val.reqTargetとgroundVal | host/portの既存順序と同じreqを保持。失敗のpayloadも型付け→全BuiltinArgsでOutcome.Typed/Ground/Adequate/非exit。parse引数を任意関数にしない | 12/20/22/24 | 60〜120分 | L・W・RV |
| L50.26/F | パス射影と拡大δ | ScopeDelta（新） | F07 pathInValue/widenPathIn | checked/checkedAtの保持絶対対象を同じStringへ写す。widenは同じ値を返しF01/13で型を広げ、再解決しない | 13/21/24 | 45〜90分 | L |
| L50.27/F | 要求射影と拡大δ | RequestDelta/ModelHttp | F07 requestInValue/widenRequestIn | 既存valueRunの型付けを利用→同じreq/endpointを保持する全経路。widenの結果も同じ値とし、要求をdefaultへ置き換える枝をtypedで排除 | 12/13/25 | 45〜90分 | L |
| L50.28/F | 純粋6行の応答と観測 | ScopeResponse（新） | F07、delta_typedの量化 | 24〜27の6行を同じlookup/deltaへ集約。別枠の結果葉externalRef/externalHandle/scopePatternの全σ適格性も証明し、正常値のfactsをF04(旧L40)へ接続。Outcome.errも残し、分類だけの未完0にする | 24〜27 | 45〜90分 | L |
| L50.29/F | 骨格の四つの値保存 | ModelConstraints（新） | ValueAssumptionsの完全4署名 | carrierのrename/値bind/norm不変→sat/admitsの四条件。型/行像が値依存を持つ場合を含み、Failの列を長さで観測しない | 03/B | 75〜150分 | L |
| L50.30/F | 型改名・型代入と許容 | ModelConstraints（新） | TypeAssumptions4署名、admits_sat | TypeParamRenamingとSatAllから構造の保存を帰納。source arity/kindを22から供給。八保存と無制約の供給を閉じる | 29/22 | 35〜60分 | L・W・RV |
| L50.31/G | Fileの二読取り | ScopedIOResponse（新） | F07 readTextIn/readBytesIn | 同じtarget?をobs=[t]にし、String/BytesのOkとIOErrorのErrorを具体構築。全入力で型/適格性/存在/非exit | 14/23/28 | 40〜60分 | L |
| L50.32/G | Fileの二書込み | ScopedIOResponse（新） | F07 writeTextIn/writeBytesIn | 同じ保持パス＋text/contentの二入力を逆転。UnitのOk/Errorと同じobs、全ts/es/rs/ws/Ψを照合 | 31 | 40〜60分 | L |
| L50.33/G | Fileの二追記 | ScopedIOResponse（新） | F07 appendTextIn/appendBytesIn | 書込みと独立した二実名を表へ接続。共有応答補題を使い、追記を登録漏れにしない。対象/型/存在を各行で確認 | 32 | 40〜60分 | L |
| L50.34/G | Http.sendInの同一要求 | ScopedIOResponse（新） | F07 sendIn、reqTarget一致 | 同じ要求全体を射影→同じendpointだけobsへ。Response/NetworkErrorのResultとerrを型付け。正常応答存在・副通信隔離を要求しない | 12/27/31 | 45〜90分 | L |
| L50.35/G | 7行の存在と対象一致 | ShapeTargets/ScopedIOResponse（新） | F05、io_typed/kind/exists/target | 7実名のlookupと具体関係を全行照合→実表のShapeOkとF04からF05（Core不要）。非TopとTop双方、全適格σ/任意Ψで実証する | 31〜34/09 | 35〜60分 | L・W・RV |
| L50.36/H | Modelの八保存則 | Model（新）・ModelConstraints利用 | F09、3署名行のsat/admits | ref2/発行の同じ表を定義し29/30から八条件を構成。型パラメータの制約を含むsatをTrueへ置換しない | F/23 | 45〜90分 | L |
| L50.37/H | Modelの宣言・形 | Model（新） | F09のCore12欄 | ref_get/set・StoreShape・state_effect・発行・sig_scopedを全3行で証明。同じPとBから供給し空のsig表へしない | 36/22 | 35〜60分 | L |
| L50.38/H | Modelの応答4条件 | Model（新） | ResponseAssumptionsの4署名 | pure/ioの不在はlookupで排除。発行は専用Stepへ。δの未定義を新pureの応答存在の証拠にしない | 37 | 30〜55分 | L |
| L50.39/H | Modelの発行読者 | ModelTargetsExamples（新） | C11＋F06、Process.Environment | 空引数の発行からAtへ渡す同じσを構成。Readyの必要束縛とEnvironment事象を照合、通常資源releaseはL60へ | 17/38 | 35〜60分 | L |
| L50.40/H | Modelの担当25条件 | Model/TargetModelConditions（新） | F09、25欄の具体の証拠 | target条件はIO不在から証明。25欄を実定理へ対応し、新Core全体の充足とは区別して群Hを閉じる | 36〜39 | 30〜55分 | L・W・RV |
| L50.41/I | ModelTargetsの表と移送 | ModelTargets（新） | F09、15署名行と八保存 | 旧7＋追加8を実名で構成。scopeの3pure/6IO/旧readText/print/exitを落とさず共通八保存を適用 | H/F | 45〜90分 | L |
| L50.42/I | ModelTargetsの宣言と形 | ModelTargets（新） | Core12欄、IOShape三形 | Result/ScopeErrorの同じP、3形のShapeOk、発行、sourceTelRowsを全15行で証明。resource分類は旧File.Handleを残す | 41/22/23 | 35〜60分 | L |
| L50.43/I | ModelTargetsの純粋δ | ModelTargets（新） | F07 checkPath/value/widenの3行 | 24/26/28を同じ表へ適用。絶対形/相対形/非Top/Top、実結果の篩とGround/Adequateを供給 | 42/28 | 45〜90分 | L |
| L50.44/I | ModelTargetsのIOと存在 | ModelTargets（新） | F07の6IO＋readText/print/exit | untargeted/topTargetedを含め全IOを型付けしexistsを構成。exitはvalを返さず、旧readTextをsingleへ狭めない | 43/35 | 40〜75分 | L |
| L50.45/I | ModelTargetsの対象条件 | ModelTargets（新） | F05/F09、担当25欄 | 実表のShapeOkからF05を適用し同じσ下の上限へ全応答を接続。PathBasesを加えた表のmembershipを確認し25欄を閉じる | 41〜44 | 30〜55分 | L・W・RV |
| L50.46/J | ModelHttpの表と移送 | ModelHttp（既存へ並置拡張） | F09、7署名行と八保存 | ref2/check/value/send/widen/発行を同じ表へ。固定reqTarget、同じ内容型、骨格を保ち八保存を適用 | H/F | 45〜90分 | L |
| L50.47/J | ModelHttpの宣言と形 | ModelHttp/ScopeDeclarations（新） | Core12欄、Http/Pair/Resultの宣言 | 5欄ClientRequestとPairのarity、RequestCheckErrorの構成子を同じPで検査。篩付きPairのgroundTy修正を継承 | 46/22 | 35〜60分 | L |
| L50.48/J | ModelHttpの純粋δ | ModelHttp（既存へ並置拡張） | F07 checkRequest/value/widen | 25/27の同じreqを実δへ結ぶ。旧の任意parseやdefaultRequest成功へ戻さず全BuiltinArgsを扱う | 47/28 | 40〜75分 | L |
| L50.49/J | ModelHttpの送信と存在 | ModelHttp（既存へ並置拡張） | F07 sendInと発行 | sendIn全応答の結果型/適格性/存在と同じendpoint、発行の表を証明。要求なし/端点不一致の否定を同じ表で照合 | 48/34 | 40〜75分 | L |
| L50.50/J | 三モデル75欄を集約 | TargetModelConditions/ModelHttp/Model/ModelTargets | F09、25×3の実定理 | 三モデルの担当欄を一行ずつ照合し独立未完0を確認。external3＋release1の各12欄はL60へ具体の入口を渡す | 40/45/46〜49 | 35〜60分 | L・W・RV |
| L50.51/K | U1全位置とIO添字 | ScopedCallContracts/ScopedTargetExamples（新） | F08の7位置と5具体化行 | 関数/節/格納を同じ要求・対象・σへ接続。旧型の同値を使わず、scope上限と逆算禁止をR10b/R30へ渡す | C/J | 40〜75分 | L |
| L50.52/K | 全σと否定の境界 | ScopedTargetExamples（新） | 起点差/分割被覆/secretsの対照 | root=cwdでも非Topの被覆を拒否。未指定と空一覧・任意の有限非空一覧、Top拡大と同じ絶対射影を証明する | 07/16/35 | 30〜55分 | L |
| L50.53/K | 内部エラーの保存を照合 | AtTargets/AtPatterns/TypedFacts/内部観測の読者 | F10、内部全欄・全失敗形 | 20の保存等号と全失敗を照合し、暫定の内部観測の読者を追随。atErrorの全有効σでの適格性も証明。公開宣言/観測/網羅性の写しはU02後・L70前へ渡す | 20/47 | 30〜55分 | L |
| L50.54/K | 実行の読者へ接続 | ScopedTargetInputs（新）・既存State葉を利用 | 第2節の応答6葉＋At/発行5葉 | StateTyE.inputs→primitive_contract_inputs→BuiltinArgs.normalized→実応答→既存保存葉を連結。同じEb/σ/μを保持し、外部と主定理をL60/L70へ | 35/50/51/53 | 40〜75分 | L |
| L50.55/K | 義務・申し送りの事前照合 | 群Kの結果・一行表 | 第6節33義務、第7節31申し送り | 技術/継承/他段/共通を一行ずつ実定理と読者へ照合。見つけたL50独立未完はL50で閉じ、後段へ付け替えない | 51〜54 | 30〜55分 | L・W・RV |
| L50.56/L | 写しと既定importを照合 | 01-12/07-04・既定import・群L結果 | 実定義とF01〜10の対応 | 実装済み規則だけを写し、全新モジュールを既定へ含める。Sourceの偽造排除とσの静的/実行時の境界を明記 | K | 30〜55分 | L |
| L50.57/L | 段末の公理依存 | 段末監査入力・出力（将来の保存先） | 旧主定理＋新葉＋使用定義 | 全環境のLeanのprivate宣言と自動生成の宣言も監査し許可三公理だけを確認。新型に置換した実署名を保存し、sorry拒否と別に照合する | 56 | 30〜55分 | A-L |
| L50.58/L | 全場合と後段の受渡し | 段末の全場合/義務/署名表 | F01〜10、75欄、13API | 全母集団を実定理/実δ/読み手へ照合し、充足と応答存在を別判定。L60/L70/R30/R50の受け口と残件を固定 | 57 | 30〜55分 | L |
| L50.59/L | 独立レビューへの応答 | 指摘が当たる本番/写し・群L結果 | 群/段末の全所見 | 取りまとめの独立レビュー後に処置。新前提・提供範囲変更は停止。修正で古くなった検査と監査だけ更新する | 58/独立レビュー | 45〜90分 | L |
| L50.60/L | 段末の受け入れ資料 | l50の結果・実署名・取りまとめへの転記 | 33義務の段別判定、後段の完全署名 | 全L50独立未完0を照合→最終work/RSSを同じ実装状態で一度→取りまとめと設計者へ渡す。全体閉鎖や受け入れ済みと自己判定しない | 59 | 25〜45分 | L・W・RV |

### 群の一覧と完了条件

群を同じセッションで実装し、群末に一回レビュー・取り込みする。入力から具体δと利用先までを閉じる。

| 群 | 単位 | 群の完了条件 | 所要時間（能動時間） |
|---|---|---|---:|
| A 方式と完全署名 | .01〜.05 | F01・F02・F03・F04・F05・F06・F07・F08・F09・F10すべての完全署名/定義形を型検査し供給元を固定。F03/F04は証明する。公開写しはU02後・L70前へ明示。 | 3時間35分〜6時間30分 |
| B 全σの被覆 | .06〜.10 | 9対の被覆と全σでの所属、snapshot、効果の意味が接続し、最初の13移植と継承T07の1目的を区別して残件が数えられる。 | 2時間45分〜5時間00分 |
| C U1とsingleの型付き入力 | .11〜.15 | 任意Ψの保持対象と同じ要求を返し、型付きsingleがTop fallbackを使わない。F3と7位置への入口が同じwsを保つ。 | 2時間35分〜4時間45分 |
| D 必要束縛・発行・At | .16〜.20 | 準備失敗の終端15葉すべてにE_AtPrepareErrorへの実定理を対応。成功4経路のそれぞれはcheckAtの8葉からE_AtOk/E_AtErrorへ接続し、到達不能なら排除の実定理を示す。15＋4×8＝47を上限に実数を記録し、同じσ・発行・D61の内部保存を閉じる。 | 3時間15分〜6時間05分 |
| E 共通表とチェックδ | .21〜.25 | 共通16署名とPの有限宣言が同じで、checkPathIn/checkRequestInの実δと結果型が全BuiltinArgsで成立。 | 4時間00分〜7時間30分 |
| F 純粋応答と八保存則 | .26〜.30 | 純粋6行の全応答、非exit、Ground、AdequateResultと非空制約を含む八保存則が本番にある。 | 4時間05分〜8時間00分 |
| G File6本とHttp.sendIn | .31〜.35 | IO7実名すべてで型/存在/同じ観測対象が成立。正常成功の存在や実外部状態の精密化を新前提にしない。 | 3時間20分〜5時間30分 |
| H Modelの担当条件 | .36〜.40 | 新Modelの実3行から担当25条件が構成され、発行の実読者があり、release/externalを別に残す。 | 2時間55分〜5時間20分 |
| I ModelTargetsの担当条件 | .41〜.45 | 新ModelTargetsの15実名と3つのIOShape全体に担当25条件が成立。旧readTextのTopの契約を維持する。 | 3時間15分〜6時間10分 |
| J ModelHttpと75条件 | .46〜.50 | 新ModelHttpの7実名と同じreq/endpointが成立し、三モデル75欄に各々証拠がある。 | 3時間15分〜6時間00分 |
| K 全位置と全読者 | .51〜.55 | 7位置・5具体化行・11実行読者・33義務/31申し送りの各行に、照合結果と実在する定理又はδの完全名を記す。後段の所有分にも根拠となる実定理名と未実装の受け口を併記する。 | 2時間50分〜5時間15分 |
| L 段末の監査・レビュー・受け入れ資料 | .56〜.60 | 全場合・実署名・公理依存・既定build・写しを独立レビューし、L60/L70へ渡せる。設計者の受け入れは別判定。 | 2時間40分〜5時間00分 |

全60単位の積上げは **38時間30分〜71時間05分、中心54時間47分30秒**。群末の所見の処置を各群の内数とし、.59は段末の横断所見への応答だけを計上した。ビルド・独立レビュー・設計者の回答の待ちは別である。


## 6. 義務の一行ずつの対応

Pはplanの**担当欄**、20/30/40は各段末の**残る段の欄**にL50があることを表す。本文に現れただけのL50を数えない。前段での「完了」は担当分であり全体の閉鎖ではない。L20/L30/L40は設計者が段末を受け入れ済みという第1節の判定を各行へ適用する。

| 母集団 | 件数 | 差と扱い |
|---|---:|---|
| plan担当 | 26 | O013,O015,O035,O036,O038,O044,O048,O049,O057,O058,O059,O060,O061,O062,O063,O074,O082,O092,O096,O097,O141,O144,O156,O165,O166,O168 |
| L20段末の残る段 | 9 | O013,O015,O035,O038,O044,O049,O058,O065,O144 |
| L30段末の残る段 | 4 | O015,O022,O034,O144 |
| L40段末の残る段 | 13 | O015,O022,O034,O035,O038,O048,O057,O058,O059,O060,O062,O141,O144 |
| 和集合 | 29 | Pとの差はO022/O034/O065の3行。すべて下表へ残す |
| 全L共通 | 4 | O016/O027/O084/O118。上記29行と重複なし |
| 計 | 33 | 技術26・記録2・他段1・共通4。全行の受け口があり、現在の実装完了/全体閉鎖は0 |

| 義務/入力 | 分類 | 受け持つ単位 | L50の完了の判定 | L50後に残る段/理由 |
|---|---|---|---|---|
| O013・P/20 | 技術 | 11/14/35/40/45/50 | 型付き対象の裸opaque排除からshapeAt/TargetAgreement/io_existsへ。三モデルの対象に関わる25条件を実証 | L60が全Coreを組立。対象の葉の未完を移管しない |
| O015・P/20/30/40 | 技術 | 07/08/11/28/35 | target path/host/endpointの所属と具体化を全σで接続。L30の16sortの論理帰納は継承 | L60の実表合成、R50 |
| O016・全L | 共通 | 05/57/59 | 定義・言明・仮定と全環境の公理依存を独立レビュー。新主定理の閉鎖済みとはしない | L60/L70レビューとRust開始条件 |
| O022・30/40 | 技術 | 08/28/35/50 | L30三条件のうち対象の観測と実δを同じ値で照合。L40の正常算術・有限鍵は済み | L60の外部/全実モデル、R50 |
| O027・全L | 共通 | 60 | -M12288、同じ最終workで取りまとめが正式RSSを限定採取。本体/計測器の終了を分ける | 各後段の限定採取 |
| O034・30/40 | 技術 | 08/28/35/50 | 対象所属のmachine_exact/stable/representedの既存条件と具体表を接続。意味上の対象なしTopへ戻さない | L60、R50 |
| O035・P/20/40 | 技術 | 12/13/25/27/34/51 | 全δ・拡大・関数/節で同じreq/endpointと適格σ。Requestの二導入経路とIO存在を確認 | L60全モデル、L70合成、R30/R50 |
| O036・P | 技術 | 14/23/35 | 全single型付き入力にtarget?がありshapeAt=shape。旧対象なしTop枝を使わず全Valの一致にはしない | L70の実行/表層への合成 |
| O038・P/20/40 | 技術 | 17/18/28/35/54 | 既存StoreOk/ContTy/StateTyEの葉へ実応答を供給し同じσ/Eb/μを保持。全76遷移の保存を作り直さない | L60外部/解放、L70全保存 |
| O044・P/20 | 記録 | 20/56/60 | D20/D22と旧Syntax/07-04の対照、対象保持とgroundValの変更を結果へ明記。旧主定理の欠陥とは説明しない | D10公開文書、L70の規範切替 |
| O048・P/40 | 技術 | 07/12/13/27/34 | 既存の所属単調性を全σの被覆と同じ要求/endpointを使う実δ/IOへ接続。eq_of_not_fnへ戻さない | L60表の組立、L70/R30/R50合成 |
| O049・P/20 | 技術 | 12/25/27/34 | groundVal/固定reqTarget/valContentを本番のチェック→射影→送信へ通す。既存逆転を再証明しない | L60全Core、R30/R50 |
| O057・P/40 | 技術 | 17/18/35/54 | 全適格σのAtの三枝、発行、実IOの応答存在を実開始から供給。正常応答存在を前提にしない | L60外部/解放、L70 progress |
| O058・P/20/40 | 技術 | 13/15/28/35/54 | 同じ実引数の依存結果/効果と適格な応答を既存保存葉へ。捕捉/継続の新仮定なし | L60、L70 preservation |
| O059・P/40 | 技術 | 18/35/54 | 実応答の存在とoracleの選択、At全分岐を既存step読者へ供給。逆方向の完全性を足さない | L60、L70 step_sound |
| O060・P/40 | 技術 | 09/17/23/54 | C21のIO/PathBasesの事象被覆を継承し、実表のShapeOk/PathBasesShapeと同じσの許容F02/F05を供給。Fail不変/NamesWFを保つ。全到達の効果健全性は未閉鎖 | L60、L70 effect_soundness/noLamNames |
| O061・P | 技術 | 07/09/14/35/54 | ShapeOkとTargetAgreementから同じσ/対象の一回の観測を許すF05まで（Core不要）。副通信/実体/IFCは含めない | L60 external_no_targets、L70一段/到達/表層 |
| O062・P/40 | 技術 | 24〜28/50 | 純粋6範囲APIの全BuiltinArgsから同じδのOutcome.Typed/AdequateResult/非exit。L40の328/34行を再開しない | L60外部/全実表 |
| O063・P | 技術 | 31〜35/40/45/50 | IO7本と各モデルの全IOにtyped/kind/existsを構成。F3の新入力を旧Ty.Leで制限しない | L60の外部条件との区別・全Core |
| O065・20 | 技術 | 22/29/30/50 | sig_scoped/sourceTelRows/八保存則/同じPのarityを範囲表で充足。L20の移送と片方向埋め込みは継承 | L60の実表全欄、L70切替。全面的な旧仮定同値は要求しない |
| O074・P | 他段 | 15/51/60 | L50はD09の具体化後の原署名/同じrsと5入力形の受渡しだけを証拠化。入力推論の選択はR10b/R30が所有するため、その実装をL50で作らない | R10b/R30の直接/明示拡大/関数値/Top/比較不能の実受理と一度の具体化 |
| O082・P | 技術 | 16/18/19/52 | パターンrootと動的cwdを別の解決関数で扱う。root=cwdでも静的被覆を足さず同じ絶対対象を射影 | R30/R70/D10のscripts下/別cwd/run .と起動形 |
| O084・全L | 共通 | 05/55/59/60 | 篩/σ/externalの変更を分離。L50独立未完0と他段の未完を区別し個別レビュー | L60/L70/R/K/Vの合成/受け入れ |
| O092・P | 技術 | 16/18/52 | secrets未指定/空/有限非空の意味と一覧の自己被覆。任意一覧を静的型へ埋め込まず、所属成功を許可/分類解除に使わない | R30/R70のCLI単独名/接尾辞/混在拒否と起動側管理 |
| O096・P | 技術 | 16〜19/23/31〜35/54 | Sourceの偽造排除、必要束縛、発行、At成功から同じ保持絶対対象をFile6本/Httpへ。存在/型/対象を分けて閉じる | R30の供給・heap/stress・work/tmpの実在と管理 |
| O097・P | 技術 | 04/20/53 | D61の元の生入力/解析済み入力/解決結果/両起点/失敗種別/原子列を内部に保存。reprStr保存と仮入力置換を除く | U02確定後・L70前の公開宣言/観測/照合の写し、R30/R60の構成/文言/Show |
| O118・全L | 共通 | 56/58/60 | コメント/写しを現行仕様の根拠へ合わせ工程ID/手元の絶対パスを本番へ足さない | L70/R50/R60/D10/V10の全読者 |
| O141・P/40 | 技術 | 15/35/51/54 | U1の7位置と同じ対象/req/σ、拡大前に一度決めたIO添字の葉を実署名に接続 | L70、R10b/R30/R50/R60/V10 |
| O144・P/20/30/40 | 技術 | 07〜09/28/35 | 案Iの対象所属と全σ、既存論理/true/空篩を具体応答に接続。一般UF/量化等を追加しない | R20/R10b/R40/R50/V10 |
| O156・P | 記録 | 56/60 | σを引数とする静的上限とcheck/runの限界、IFC未実装をD10へ渡す。L50で00-01/AGENTSの公開要約を先行改訂しない | D10の二文書、V10の実CLI。利用者向け文書の所有による分離 |
| O165・P | 技術 | 06〜09/52 | 同一起点の被覆→任意σの所属保存。異なる起点が同じ解決先でも被覆を認めない対照 | R10b/R30/R50/V10 |
| O166・P | 技術 | 19/24/52 | 旧純粋APIは絶対形だけ、Atはbases明示の相対形。範囲添字も未束縛を代用しない | R30/R40/D10/V10 |
| O168・P | 技術 | 16/19/20/52/53 | DET-R01〜26を解析済みの内側と字句/CLI/外部へ分類し、起点差/分割被覆/未束縛/偽造のLean境界を証明 | L60のexternal名目性、R30/R50/R60/R70/D10/V10の否定例 |

他段への分離は、O074の**推論手続き**、O156の**公開要約の編集**、O013/O049/O063/O065等の**external/releaseを含む全Coreの構築**に限る。L50自身の対象所属・実δ・IO応答・75条件をこれらへ送って完了にしない。O064の通常資源のrelease_existsは、l00b.15の一般的なL50/L60表記より、planとL40段末のL60担当を具体的な所有とする。H27でも理由と受け口を残す。


## 7. 申し送りの一件ずつの受け口

出どころが重なる場合も照合行は保つ。下表の31行は受け渡された事項の照合であり、独立した実装課題が31件あるという意味ではない。L40の33申し送り全体を再度L50へ移管せず、そのH31と段末のL50行等を受ける。古いレビューの未完表示には、planの処置と後段の結果を合わせて判定した。

集計は **31行＝技術24・継承5・他段2**。全行に単位/完了判定/残る段があり、実装前なので今回閉じた行は0である。

| 受け口 | 出どころと内容 | 分類 | 単位 | 完了の判定 | 後に残すもの |
|---|---|---|---|---|---|
| H01 | L40段末F01/F03、RV-L40.aとbの取りまとめ追記 | 継承 | 02/05/11 | 芯の対応＋facts、appは直接二枝と形成付きapp_telを使う。元型全体のLeQを返す撤回署名を再採用しない | L70全開始の合成 |
| H02 | L40段末F02、l40/b/results、planの四前提除去 | 継承 | 05/15 | TelClosure.applyのCtx.WF＋元列Annotationを実開始から供給。除去した四前提を再追加しない | L60/L70が同じ実署名を使用 |
| H03 | L40段末F04、normal_reply_facts/at | 継承 | 28 | 同じ実δ・同じ正常値・toTerm?の等号からfactsを得る。型保存だけからδとの算術一致を推測しない | L60の応答、L70合成 |
| H04 | L40段末L50行、CのHeldValues受渡し、S32 | 技術 | 11〜15/26/27/34 | 同じ保持対象/req/endpointを拡大・関数/節・全IOへ接続し、全σの所属を実証 | L60/L70/R30/R50 |
| H05 | L40 H31、L30処分表RV-L00b.13：篩付きPairのRequest/At | 技術 | 12/18/25/47 | groundTy修正を継承しPair[String{true},String]等の型付き要求をAt→射影→sendへ。実Rustとの一致は別 | R30/R50の同じ入力を比較 |
| H06 | L20段末J20-2：sourceTelRows/AtのinputTy.RowsIn | 技術 | 22/30/47 | 全16共通署名と三モデルの実表にSourceScoped/RowsInを供給。閉じた内容型の行支持をTargetTable.content_rowsから使う | L60残りの実表、L70/R10bソース生成 |
| H07 | L20段末「実表・三モデル・対象/範囲」、RV-L20.j取りまとめ追記 | 技術 | 21〜50 | sat=Trueの小例を実表の証拠にせず、同じP/Bの25×3条件と非Top/任意Ψを構成 | L60全Coreと通常資源 |
| H08 | L00b.15 theorems：σ/Ready/InitialPreparedの段落 | 技術 | 16〜19/54 | Readyを新たな全状態不変条件にせず、必要束縛と初期準備、動的未束縛Errorを分離 | L70初期表層と全到達 |
| H09 | L00b.15 値の移送、RV-L00b.02b-values軽3 | 技術 | 03/29/36/41/46 | 四保存則を骨格から証明。Fail列の順序/重複/長さを読まず、型/行像の値依存を除かない | L60で証拠を再利用 |
| H10 | L00b.15 型の改名、RV-L00b.02b-handlersの一般ρ | 技術 | 03/30/36/41/46 | TypeParamRenamingで制約を保持し束縛下の途中挿入も扱う。sat_localを新しい独立仮定へしない | L60の全Core |
| H11 | L00b.15 PathBases署名、RV-L00b.02b-atのio_op追記 | 技術 | 17/21/23/39 | PathBasesShapeの8欄と同じB.effectsリストのmembership、Process.Environment事象を実表で満たす | L70のeffect_soundness、R30発行 |
| H12 | L00b.15受渡し、RV-L00b.15軽6とRV-L10 O013 | 技術 | 14/21/23 | ShapeOk.singleの署名引数はopaque o (rvar 0)。値のscopedはscoped_forgetで渡す。scoped署名へ変えない | L60実表合成 |
| H13 | RV-L20.bc中の新ScopedとPのarity条件 | 技術 | 22/42/47 | Result等の宣言とkindを同じPの有限宣言から供給。旧s.Scopedの証拠を新PrimSig.Scoped Pへそのまま使わない | L60の標準全表 |
| H14 | RV-L00b.02-sig中5、l00b.15のAdequateResult | 技術 | 24〜35/50 | δ/ioの全応答に全有効σのAdequateResult。外部応答の三条件からのadequate導出とは別に閉じる | L60のexternalCheckedOutcome |
| H15 | RV-L00b.13軽4：通常checkedのTop拡大の対照 | 技術 | 11/13/52 | PathInの保持値を非Top→Top→opaqueへ渡して逆転。要求なしのRequestIn拒否と対にする | R30/R50の入力表 |
| H16 | RV-L00b.13軽6：valKindの未並置 | 技術 | 21/23 | 旧TargetTable.valKindのPathIn/pathとRequestIn/endpointを新表へ並置しvalContentと整合 | L60/R30の実表 |
| H17 | RV-L00b.13中2、planの2026-11-01の処置 | 継承 | 01/18 | AtPrepared.request/Val.reqTarget_kind/checkAt.absoluteは既済み。At成功値の新補題数へ重複計上せず利用する | 追加の未完なし |
| H18 | RV-L00b.13軽2・3・7、L40 H11/H12/H13の処分 | 継承 | 01/12/53 | 全幅facts・List要素facts・atError専用逆転の処置を継承。L50は要求の内容/エラー形の読者だけ確認 | 公開形の対応以外の再実装なし |
| H19 | L30段末O015/O022/O034とA5葉の受渡し | 技術 | 08/28/35 | 対象3sortの観測→所属/具体化→実δを結ぶ。B08の同一項q→qを強めず、二つのlength観測を同じ値で使う | L60/R50。非対象13sortは既済み |
| H20 | RV-L00b.02b-at中のtextFields/内部reprStr | 技術 | 04/20/53 | 未解析の元入力を内部保存しShowと分離。U02の二案を[u02-options.md](u02-options.md)に用意するが公開写しは実装しない | R30/R60/L70の公開shape/reader |
| H21 | RV-L00b.02b-handlersのStandardErrorComplete、l00b.15 mapping | 技術 | 20/22/53 | 内部保存変更後も既存P.cons/Term/RuntimeMatch/Exhaustiveの読者を保つ。At/OutsideScopeの確定公開表への一致はU02後へ明記 | U02確定後・L70前の公開写し、R60の全表層 |
| H22 | plan末尾のL00a.12：値置換にbindの正規化 | 技術 | 09/13/15/30 | 範囲具体化・型/行像・継続Rの契約を同じbindへ。L20の一般交換を使い生のrawBindで後段を組まない | L70主定理の閉鎖 |
| H23 | L00b.15の発行・準備、L20 SourcePreparation | 技術 | 16/17/19 | Sourceから直接pathBasesを作れず、発行した同じσをAtへ渡す。一般ValのV_PathBasesを偽造の反例と誤読しない | R30/R50のrecord/JSON/外部からの偽造拒否 |
| H24 | RV-L40.g軽1・中2、取りまとめ追記と段末64義務 | 技術 | 55/58/60 | L40の局所証拠を全体閉鎖へ繰り上げず、O022/O034/O062/O065/O144の残る対象/実表を受ける。演算子34行/decoderをL50へ再移管しない | L60/L70/R50の既存所有 |
| H25 | L40 F05/F06、同じ有限宣言とsatB、L30 J/Kの読者 | 技術 | 03/22/29/30/50 | 同じPとsummaryの骨格を使う。KeyObservationを未検査欄にせず、全標準表の収集は別とする | L60/L70/R10b/R50の全表収集 |
| H26 | L20群L/MのCaptureReadBoundaryとL40 H08 | 技術 | 03/28/54 | δが読まれない捕捉の場所番号を観測できる既存契約を維持。L50で応答の適格性以外の不変条件や精密外部状態を足さない | Rustが閉包内部を観測しない差の比較はR50 |
| H27 | L00b.15のrelease_exists追加3欄とL40段末L60行 | 他段 | 50/60 | release_existsの通常資源の全値とexternalはL60。L50は第4節の25条件（sat_unconstrained/admits_satの2欄を含む）を実証する | L60。通常資源は範囲IOの新葉ではないため |
| H28 | L40段末L50行：Top/空ストアへ量化を縮めない | 技術 | 11/14/35/50/54 | 任意Ψ・全適格σ・新F3受理を全署名に保つ。代表の成功と全入力の定理を分け、Topでも同じ保持対象を返す | L70/R50の全接続 |
| H29 | L40/detail第9節と各群の範囲/外部応答の境界 | 技術 | 31〜35/54/60 | File6本とHttp.sendInをexternalResponseと分離し、δ/IO/Atのそれぞれの表と応答存在を閉じる | L60のborrow/own/State、R30の固定σ実装 |
| H30 | L30処分表の非計算的checkIn、L40 H33 | 他段 | 58/60 | 有限交換表と上層の証明の照合はR50。L50の局所Leanやraw再生で全表の一致と呼ばない | R50/F-CONN、L70/F-REGの既存コーパス |
| H31 | L40 g/casesの「全有効σはL50」9行：範囲添字、externalRef、externalHandle、pathBases/scopePattern、保持3形、atError、externalCall/issuePathBases/checkAt、対象3sort、応答 | 技術 | 02/08/11/17/18/20/28/35/53/54 | F01/F03/F07で9行を対応。externalRef・externalHandle・scopePattern・atErrorも全有効σのAdequateResultを.28/.53/.54で証明し、外部応答の充足とは区別 | L60の外部応答全条件、L70主定理/公開写し |


出どころの所在は[前段の対照](../l00b.15/theorems.md)・[写しの対応](../l00b.15/mapping.md)、[L20段末](../l20/stage-results.md)、[L30段末](../l30/stage-results.md)・[63件の処分](../l30/l/review-handoffs.md)、[L40段末](../l40/stage-results.md)・[33件の処分](../l40/g/handoffs.md)・[全場合の表](../l40/g/cases.md)の上記9行、reviewsのRV-L00b.02-sig/.02b-values/.02b-at/.02b-handlers/.13/.15、RV-L10、RV-L20.bc/.j、RV-L40.a/.b/.c/.gと各末尾の取りまとめ追記である。単独の古い所見を最新の未完として復活させない。


## 8. 本番追随の最初の13移植・継承1と残り

測るための別実装・標本・元へ戻す試行を置かない。群Bの最初の14目的を次表に固定し、新移植13とC19の継承1に分ける。新しい形を作るRangeExprの被覆はその前提であり、この14目的の一件当たりの時間へ混ぜない。旧の所要が記録されていない目的を、値の逆転やL30の証明書の比で補わない。

| 移植 | 旧EffectCoverの名前 | 新しい入口の形／単位 |
|---|---|---|
| T01 | Eff.allows_of_mem | 同じσで固定範囲への所属を許容へ／.09 |
| T02 | Eff.Allows.kind | 許される対象とeffKindが同じ／.09 |
| T03 | Eff.not_allows_of_kind_none | 種類のない名前から対象許可を得ない／.09 |
| T04 | Eff.allows_of_nameTop | 同じkindのTop／.09 |
| T05 | Eff.allows_single_iff | 同じ名前・固定Top原子の許容／.09 |
| T06 | Eff.Allows.mono | 原子の包含による許容の単調性／.09 |
| T07 | Eff.allows_norm | C19のEffectFactsの既存証拠を継承／.10で照合。新移植に数えない |
| T08 | Eff.allows_union | 原子和の許容の分解／.09 |
| T09 | Eff.not_allows_empty | 空効果は対象を許さない／.09 |
| T10 | Eff.not_allows_row | 未具体化の行原子だけでは対象を許さない／.09 |
| T11 | Eff.allows_bind | 型/行/範囲/値の像をもつbindの意味の読者／.09 |
| T12 | Eff.allows_bind_of_rows_nil | 行像なしのbindで同じ名前の固定原子を返す／.09 |
| T13 | Eff.Covers.sound | 一原子の被覆から同じσの許容へ／.09 |
| T14 | Eff.allows_of_mem_covers | 一つの原子と被覆の直接の利用／.09 |

署名をそのままコピーするという意味ではない。新しいEff.CoversにはΓ/Φ、範囲にはRangeExprがあり、旧型との等号は要求しない。σを意味の読者へ足しても静的Coversへ足さない。.10で各目的を「新移植」「既済みの証拠を継承」「供給側が別の入口で同じ目的を満たす」に一行ずつ分ける。既済みの目的を新移植の実績へ足さない。継承T07を除く13件に不足があるなら残件を維持する。

| 残りの移植の族 | 旧の目的（13） | 受け持つ先 |
|---|---|---|
| 効果の置換3 | allows_substAt_nil、allows_substRho、allows_bind_comp | .09/.30。T11/T12から供給できれば残件から控除 |
| ShapeOk5 | common、eff_eq、inst_eff_mem、single、single_inst | .14/.23。原署名のopaqueと任意pを保持 |
| Membership4 | canonical_opaque、widen_opaque、widen_instTarget_covers、HasTypeVsQ.widen_covers | .11/.13。対象名の枝は新しい強い入口へ。通常資源の存在はL60の既存担当 |
| 観測の許容1 | Builtins.TargetAgreement.obs_allowed | .35。F05で全新入力と同じσを扱う |

合計27目的（新規候補26＋継承T07の1）は、今回読む旧モジュールで具体的に名指した移植の一覧である。過去の419/807/819全体の移植件数ではない。L00b〜L40で同じ目的が済んでいれば控除し、同名の補題を二本作らない。主定理側のTargetStep/TargetPropagationは、L70へF02/F05の署名を渡す読者として在庫に残し、この27へ追加しない。

通常の結果の区間から能動時間と待ちを分離できた場合だけ、実移植件数n、所要時間（能動時間）A、残件Nから `c=A/n` と `N×c` を使う。分離不能ならcは未取得で、段の枠36.5〜84時間を保つ。骨格作成・Atエラーの変更・モデルの条件をこの係数で一律に減らさない。更新の区切りだけを理由に止めず、形が合わず移植が成り立たない場合は反例・現在の前提・代案を返す。

## 9. 既存定義への変更、方式の確認、判断の分岐

### 確認済みと未確定

この下書き中の短い試行は、補助入力の `lake env lean -M 12288` だけである。4命題と実署名の確認を行い、入力の全文・終了・時間・公理依存を[結果](results.md)へ保存した。大きな具体列や範囲の評価はしていない。

| 対象 | 今回確認した範囲 | 最初の群で残る確認 |
|---|---|---|
| basedの被覆 | 任意Wordを付加する4場合を証明。具体列の長さに依存しない | F01の所属補助は.02で先行証明し、9対/secretsの読者と全効果への接続を.06〜.09で行う |
| snapshot | SnapshotMemとSnapshotAdequateから同じσのMemを返す既存currentを利用 | 下書きのF03/F04は型検査のみ。.02ではC20とF01でF03を証明し、F04も証明する。currentの供給は.17へ接続 |
| shapeAt | 対象位置のtarget?=some tならsingleのままであることを証明 | F04を.02で証明し、任意pの具体の依存列への適用を.14で閉じる |
| 起点差 | a≠bならbased a pがbased b qを覆わないことを証明 | 解決先が同じσでの対照と全IOの読者は.52 |
| F01〜F03/ModelHttp | inv_checked三本、TelClosure.apply、primitive/externalRef_contract_inputs、valueRun_checkedAt_requestを実環境で型として確認 | 呼出し全域の新しい証明を済みとしない |
| 八保存則 | carrier/既存SubstitutionAssumptionsの定義と利用先を読んだ | F09の25条件の出力の定義形は型検査済み。非空制約と開いた型の全保存は未試行。.03で方式、.29/.30で証明 |
| 公開エラー | reprStr、準備失敗時の仮入力、七String観測と構成子表を読んだ | 内部保存だけをL50で補完。公開二案はU02の回答後・L70前まで実装しない |

### 定義を変える必要と波及

| 対象 | 必要な変更の案と理由 | 波及の場合の数・先に固定する境界 |
|---|---|---|
| Ty/LeQ/HasType/StateTyE/Step/Ready | 原則として変更しない。既存の構成子とF01〜F09の補助定理で接続する | 既存の29値規則、25Val/16Comp、76Step、七判断の相互帰納を作り直す単位を置かない。必要と分かったら停止 |
| TargetTable | valKind、13範囲APIとref2/発行1、同じPのdeclared/sourceTelRows、効果表・応答表を新判断へ並置 | 共通16署名、三モデル延べ25署名行。旧Releaseの表/主定理はL70まで残す |
| ModelHttp | 既存のvalueRunの証拠を保ち、固定reqTargetでcheck/send/widen/発行を同じ表へ組む | RequestのcheckedRequest/checkedAtの2経路と純粋3行・IO1行。旧自由parse関数へ一般化しない |
| sat/admitsのモデル実装 | 同じ有限宣言の骨格とsatBから八保存則を証明。主判断の任意satの契約は保つ | 4値＋4型の8欄を共通補題で一度証明し3モデルへ適用。tvar/値像/行像/Fail縮約を含む |
| AtError/AtPrepare | 未解析の元入力を保存し、公開観測をreprStrから分離する必要がある。現在のAtError.originalPatternはRangeExpr、originalTargetはTargetInputなので、解析失敗の任意の元文字列を表せない | 04で検索字句と読者を記録し実際の追随を棚卸しする。L50は内部保存と既存読者の追随。U02後は公開写しとV_AtError/At三遷移/AtPatterns/TypedFacts/MatchFacts等の対応を再点検 |
| ScopeErrorの公開形 | 既存のOutsideScopeを保ち、U02確定後・L70前に選んだ形とP.consの一覧を合わせる | AtFailure7構成子（base展開11）、AtErrorの元入力/解析済み入力を含む保存欄、ResultのOk/Error2行、宣言/観測/照合/網羅性の4読者。StdErrorCompleteを存在条件だけで代用しない |

新しい相互帰納の判断やσ引数付きの型付けを先に加える案は採らない。定義と署名をAで固定し、B/Cの一般補題、Dの準備、E〜Gの具体表、H〜Jの三モデル、Kの実読者の順に進める。前の段の一般補題を変える必要が出たら、字句一致だけで所要を決めず、実際の構成子/証明の分岐と再検査を列挙して止める。

### 設計者の判断が要る項目

| 項目 | 現在の状態・案 | 判断の時期と実用への影響 |
|---|---|---|
| J50-1：内部保存とU02の公開形 | **取りまとめの判断を反映**。L50はD61の内部保存と既存読者だけを整える。公開二案の欄/照合例/既存6構成子との関係/写しの見込みを[u02-options.md](u02-options.md)に提示 | U02の期限は元のL70前を維持。回答に依存する公開名・完全署名・観測形への写しを.04/.20/.53に含めない |
| J50-2：新しい主定理前提/公理/精密外部状態を必要とする場合 | **現時点で追加案なし**。F03/F04/八保存/準備の接続が現行規則で閉じない場合だけ、定義と反例又は未証明箇所を示す。scope conditionsの出力を新しい未検査仮定として主定理に追加する案は不可 | Aの最初の1時間から点検。sourceのみ/Topのみ/空Ψのみへ保証を狭めること、Readyを全状態へ独立に課すことも判断なしに行わない |

J50-1の時期は今回の指示で確定し、公開形はU02の材料に残す。J50-2は未実証が反例へ変わったときの停止条件である。モデルの内部配置は担当が選べるが、主定理・新公理・提供範囲・書ける形・精密な外部状態の変更を実装の裁量に含めない。

### U02に提示する公開エラーの二案

比較材料を[u02-options.md](u02-options.md)へ分けた。案Aは七Stringと公開JSON規則、案Bは9欄recordと型付きdataを使う。既存ScopeErrorの6構成子との対応、失敗分類の重複と設計原則5、案Bの入れ子を含む新規19型、L70/R30/R60/D10の影響を同書に示す。公開形の確定はU02、写しはその後・L70前であり、L50はD61の内部保存までを行う。見込みはL50へ加算しない。

## 10. 所要時間（能動時間）と実績の読み方

段の枠は指定どおり **36.5〜84時間、中心60.25時間**を保つ。60単位の参考積上げは **38時間30分〜71時間05分、中心54時間47分30秒**である。枠との差は下端2時間00分、上端12時間55分、中心5時間27分30秒である。この差を未実施の追加機能へ配ったり、planの枠を勝手に短縮したりしない。重いものは任意pの依存列lookup、Pの形成、要求の全δ、八保存、エラーの内部保存に個別の幅を置いた。一律に単位数へ30〜60分を掛けた値ではない。

| 台帳の実績 | 分かること | L50への反映 |
|---|---|---|
| L20群O/P：旧値19規則の外側30分30秒、V_Fun/V_Primが約72%。群全体約1時間15分＋レビュー/処置等 | 共通の補助を作る枝に所要が寄る。能動時間と待ちは未分離 | .29/.30へ共通保存を一度置き三モデルで使う。全単位へ平均を掛けない |
| L30段末：下書きを含む担当の外側約7時間30分、レビュー計約2時間。見込み47時間5分〜91時間55分 | 見込みより短いが、能動時間は確定していない | 検査器の実績をσ/実表の未知の証明の係数にしない |
| L40 A/F1とB：外側約2時間・約1時間15分、積上げ6時間10分〜12時間5分を下回る | 既存補題の再利用と署名の修正を含む。c_V/c_Cは未取得 | 最初に控除し、型の形をAで確認する。比は一律に掛けない |
| L40 E：初回約2時間3分、再開1約4時間37分、再開2約1時間42分、停止/調査/再開6約2時間40分等 | モデル混雑・待ちを含む。通常179行の未接続、型の篩と標準本体、getterの規則が照合で追加された | APIを全行名指しし、分類・型付け・実δ・同じ入力・存在・対象を別列で閉じる。担当自身のδの未完を後段へ移さない |
| L40 G：初回約37分、再開1約7分、再開2約32分、再開3約11分。正式work456.52秒 | 演算子34行と構造Equality/decoder接続の独立未完が段末で発見された | .55/.58に実読者と応答存在までの照合を置く。75条件も型が書けたことだけで閉じない |

実績の出どころは[effort-ledger](../effort-ledger.md)。外側の時間を能動時間に変換していない。積上げには各群の所見の処置を含み、独立レビュー・ビルド・回答待ちは含まない。段の見込み更新は通常のresultsの記録で行い、27目的の残件へ二種類の比を重ねない。

planの2026-10-31の変更記録に従い、改造全体の上端で相談する。各作業の上端の2倍、公理/未承認の前提変更等の停止条件も継承する。2倍に達した時点で原因・済んだ範囲・残り・能動時間/待ち・再見込みを報告し、超過時は検査が通る区切りで止める。長い作業は群Aと通常の結果から見直し、大きな具体値を評価しない。

## 11. 検査、後段の完全署名、残りの手順

### 実装時の検査の割当

本表は将来の実装の検査であり、この文書作成中に実行済みの記録ではない。初回の基準は冒頭のB_WORK、以後は取りまとめが起動ごとに渡す直前の取り込みの完全IDとする。

| 検査 | 内容とコマンド | 割当・待ちの見込み・保存先 |
|---|---|---|
| L：局所Lean | formal/から `lake env lean -M 12288 Benitoite/Release/Refinement/<対象>.lean`。型だけでなく前提を実際に供給する読者を含む | 各単位の途中。短い型試行は今回約0.25秒、一般の帰納は不明。群resultsへ本体終了/外側時間を保存 |
| W：選択確認 | 根から `scripts/check.sh --level work --base B_WORK --dry-run`。Leanと実際に変更する01-12/07-04の読者を確認。分類不能3/誤指定2は共通依頼文に従う | 各群の最終状態。onlyを既定で足さない |
| W：作業末 | 根から `scripts/check.sh --level work --base B_WORK`。既定全Lean・sorry拒否。text例変更ならspec_examples等、構文変更なら生成Skill/集計も同じ入口へ | 各群の最後に一度。最初は直近の456.52秒を目安とし、12群なら約91分の参考値。clean/増分と後の変更で更新する。局所buildと重なる一式を追加しない |
| A-L：公理依存 | 全既定importの旧主定理・新葉・使用定義の完全名へ `#print axioms`。formal/から `lake env lean -M 12288 <監査入力の相対パス>`。Leanのprivate宣言と自動生成の宣言も全環境の対象へ含める | .57とレビュー修正後の影響分。直近約76秒、計画1〜5分案を別待ちとして保つ。生出力bytes/SHA-256、対象一覧、実署名を保存 |
| RSS | .60の同じ最後のworkに取りまとめがsandbox外でmacOSのtime -l又はLinuxのtime -vを付け、計測器と本体終了を区別 | 段末だけ。ほかは未取得（計画上の非採取）。追加buildで採らない |
| 独立レビュー | 群Aは定義/完全署名/仮定の供給、各群は全場合/応答、段末は75条件・33義務・31申し送り・後段の実署名 | 各群末に取りまとめが依頼。待ちは不明。自己点検を独立レビュー済みとしない |
| 表/リンク/写し | 全行の連続性、母集団、sum、実定義と本文の対応、手元の絶対パス/一時領域を根拠にしないことを確認 | .55/.56/.58/.60。テストを追加/変更する実装担当はtest-auditの関門を通す |
| 全比較/Rust/CLI | L50では実行しない。L70 F-REG、R50 F-CONN、V10候補CLIがそれぞれ所有する | 既存の約40分/最大約14GiBをL50の局所検査へ足さない。Leanの成功をRust/Lean一致と呼ばない |

監査で許す公理はpropext/Quot.sound/Classical.choiceだけである。sorryAx・独自公理・未承認の信頼条件を見つけたら停止する。新しいモデル条件の出力を主定理の未検査の前提へ移さない。

### L60/L70/R段へ渡す完全名と条件

次は新設予定の完全名と結論の形である。型の正は第3節F01〜F10であり、単なる名前の予約を証明済みとしない。.05で型を固定し、.58/.60で実環境から暗黙引数も含む型を印字して渡す。

| 受け手 | 完全名（先頭はBenitoite.Release.Refinement.） | 結論と必要な入力 |
|---|---|---|
| L60 | Model.scopeConditions、ModelTargets.scopeConditions、ModelHttp.scopeConditions | F09の同じP/Bに対するModelScopeConditions。SubstitutionAssumptions、ResponseAssumptions、TargetAgreementと表の12欄の証拠。有限宣言の供給元を添える。external3/release1はL60が証明してCoreへ組み込む |
| L60 | ScopedIOResponse.readTextIn/readBytesIn/writeTextIn/writeBytesIn/appendTextIn/appendBytesIn/sendIn、ScopeResponse.delta_typed | F07の全BuiltinArgs、同じ具体δ/IO関係、Outcome.Typed/AdequateResult/存在/非exit。σはAdequateResultの全称の中で扱い、ioResponseの引数へ追加しない |
| L60/L70 | HasTypeVQ.target_member、Builtins.ShapeOk.single_target | F03/F04。任意Ψの型付き閉じた入力、同じσのAdequate、同じreq/endpoint。Top fallbackの不使用。資源値のcanonical formsとは区別 |
| L70 | RangeExpr.Covers.mem、SnapshotMem.mono、Eff.Covers.allows、Builtins.TargetAgreement.obs_allowed | F01/F02/F05。全σの所属保存と同じ名前の効果の許容。一段/到達/表層の健全性はこれを使ってL70で閉じる |
| L70 | PathEnv.Ready.resolve_required、AtPrepared.current、既存StateTyE.at_*_all/path_bases_apply_all/issue_path_bases_all | F06/C10/C11。準備・固定σ・同じEbを保つ5葉と供給元。Readyを全状態へ独立に追加しない |
| L70 | ScopedTargetInputs.response_inputs（.54でF07と既存入力から構成） | 全6応答読者について元StateTyEから実args/同じout/同じ固定Ebへ進む形。既存のprimitive_contract_inputsの実署名から前提を増やさない |
| R10b/R30/R50 | 13API表、ScopedCallContracts、全σの起点差/Top/5具体化行/7位置 | ソース推論と実表に独立期待を置く。基準のRustのFile/Httpの保持経路と照合し、σ供給/PathBases/Atの新実装と分ける |
| R30/R60/L70 | AtErrorの内部保存の実署名、U02後に行う公開変換/宣言/観測/照合の申し送り | F10。全保存値・表示制限・元/解析済み/解決後の入力と両起点。公開写しはU02確定後・L70前に完了させ、旧OutsideScopeを保つ |
| D10/V10 | σを引数とする静的上限、check観測/run固定値の限界、IFC未実装 | O044/O156。00-01/AGENTSとCLIの実候補で照合し、今回の形式化の葉から実行時隔離へ保証を広げない |

.54の受渡しは、全6読者について元の入力から結論までの実定理を一行ずつ示す。上の予約名を持つ定義を置いただけでは完了しない。新しい相互判断の構成子を追加する必要が出たら、完全署名の変更として取りまとめへ返す。

Rustの読み取りでは、file.rsのretained_pathと6入口が同じ保持Stringを渡すこと、http_client.rsのsend_in/start_sendとchecked_requestの保持要求/endpointの照合を確認した。PathBases/path_bases/checkPathAt/checkPathInAt/checkRequestInAtの名前はsrc全体の検索で見つからなかった（終了1、0一致）。**σの発行・照合の新実装を確認済みとは扱わない**。R30/R70が作る対象である。実際のRust実行・IO・外部応答の比較は今回行っていない。

### 検査・レビュー・受け入れまでの手順

| 残る手順 | 内容 | 見込み |
|---|---|---|
| 取りまとめによる下書きの照合とplanへの転記 | 義務の段別判定、L40受け入れ済み、完全署名、内部保存とU02後の公開写しの分担を固定 | 不明 |
| 詳細の独立レビューと所見の処置 | 取りまとめが依頼。自己点検を代行にしない | 不明 |
| 群Aの方式の確認と署名の確定 | 最初の1時間から形を点検。F03/F04を証明し公開写しをL70前へ分離 | 3時間35分〜6時間30分（能動時間） |
| 群B〜Kの実装・局所検査・群末レビューへの応答 | 第5節の各群。群の実績で残件を更新 | 32時間15分〜59時間35分（能動時間）。build/独立レビュー待ちは別 |
| 群Lの写し・全場合/義務/申し送り・監査・段末応答 | 第5/6/7節の全件、全環境A-L、同じ最終workと限定RSS | 2時間40分〜5時間00分（能動時間）。work約8分/A-L1〜5分は初期目安、レビュー待ちは不明 |
| L50段末の取り込みと設計者の受け入れ | 実署名・33義務の担当分・後段の残り・時間/待ちを確認 | 不明 |
| L60→L70の検査と合成、R段への接続 | external/release、主定理・表層・F-REG、その後R50 F-CONNとV10 | 当該planの枠を正とする。L50へ二重計上しない。待ちは不明 |

