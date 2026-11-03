# L40 型規則と葉の起動単位への詳細化（下書き）

2026-11-03。計画担当による下書きである。[共通依頼文](../implementation-request.md)、[plan](../plan.md)、[decisions](../decisions.md)、[README の設計者の決定](../README.md#設計者の決定)を継承する。r1 は [RV-L40-plan](../reviews/RV-L40-plan.md) と plan 先頭の J40-3/J40-4 の判断を反映した。L20・L30 の段末は受け入れ済みであり、取りまとめによる plan への転記と詳細の再レビューを経て起動する。

指定ブランチは `m014/l40-plan`、B_WORK は `c52220daeca139f2aee61cf817828f91792c4d89`。担当は git の操作を行っていない。以下の本番ファイルのパスはリポジトリの根からの相対パスである。表中の短いモジュール名は、特記しない限り `formal/Benitoite/Release/Refinement/<名前>.lean` を指す。新設候補には「新」を付け、既存の宣言と区別する。

## 1. 入口の状態と差し引く作業

### 前段の受け入れと起動条件

| 前提 | 読んだ証拠と現在の状態 | L40 の起動前に確認すること |
|---|---|---|
| L20 | [段末の照合](../l20/stage-results.md)、README 2026-11-03。全148単位の担当分と RV-L20.s の処置を取り込み、設計者が受け入れた | 受け入れ済みの値・kind・行支持・StoreOk・保持値の像を基準とする。再度の方式選択はしない |
| L30 | [段末の照合](../l30/stage-results.md)の末尾「段末の work と取りまとめの転記」を、冒頭の古い未実施表示より優先する。全79単位、RV-L30.l 再レビュー可、work 終了0、159.00秒、正式 RSS 1,704,460,288 バイト、公理監査688モジュール・67,907宣言を記録済み。README 2026-11-03 で設計者が段末を受け入れた | L30 の受け入れという起動条件は満たした。詳細の再レビュー・転記は別に確認する |
| U03 | README 2026-11-03。保存係数128 bit、実際の基本操作の一回計上、`proof-steps-v1`、生成時の個別予約 | 規範は決定と StepAccounting の遷移。AccountingWork の例示を Rust の操作列へ固定しない。L40 は計上規則を改めない |
| J30-2 | plan の最新の変更記録、CarrierFacts・Context・ValueMeaning と H/I の追随 | 型域を含む現在の Ty.assume と三条件の ValueMeaning を使う。旧二条件を新しく作らない。README 2026-11-03 の L30 段末の受け入れに J30-2 と steps の規範の判断を含む |
| 勧告 | 共通依頼文が引き継ぐ2026-10-30の照合と「組み込まない」の判断 | 新しい改造の開始や依存更新ではない。今回の詳細化へ更新を相乗りしない |
| L/R の順序 | plan「作業の組み方と段のレビュー」 | L40 は型規則・開始の逆転・正常/Stop/return の葉。L50 は対象・全有効 σ、L60 は外部・三モデル、L70 は主定理・表層・交換。R 段の実装は L70 後 |

### 本番を読んで差し引いた20項目

次表は20の作業項目であり、定理の総数ではない。右欄にL40の利用側を示す。既済み分の所要は未分離なので仮の控除時間は付けない。

| 控除 | ファイルと定義・補題 | 差し引く内容／残る利用側 |
|---|---|---|
| C01 | Le：Ty.LeQ、TelLe、TelClosure、TypeArgsLe | 14・2・2・4構成子の新設は済み。F3 の適用時の反変移送と開始の逆転は残る |
| C02 | InversionCore：Ty.LeQ.listCore/listCore_right、fnCore/fnCore_right、names_eq、refCore/refCore_right | List/Fn/Reference の構文逆転そのものは済み。意味上の Subtype へ置き換えない |
| C03 | InversionCore：Ty.listCore_norm、fnCore_norm、refCore_norm、TelClosure.trans、TelLe.of_norm_eq | 篩・正規化・推移の処理を再証明しない |
| C04 | Canonical：HasTypeVQ.inv_list、inv_closure、canonical_ref；LazyInversion：canonical_lazy、Ty.LeQ.lazyCore_right | List/閉包の導出と参照・Lazy の場所は得られる。任意の元状態からセル・実引数へ進む接続は残る |
| C05 | ValueFacts：HasTypeVQ.inv_const、facts、subtype_facts、list_element_facts、field_facts_by_type、constructor_field_inputs | 最外の事実、List 要素と宣言側の data 欄への移送は済み。全幅の統一した読者と実標準応答は残る |
| C06 | HeldValues：Ty.LeQ.holds、HasTypeVQ.inv_checked、inv_checkedRequest、inv_checkedAt、checkedRequest_content | U1 の保持要求・同じ端点の逆転は済み。全 σ の被覆と IO の対象一致は L50 |
| C07 | ModelHttp：valueRun_typed、valueRun_request、valueRun_checkedAt_request、valueRun_embed | 保持した同じ要求の射影は済み。全 δ の充足を閉じたとは数えない |
| C08 | AtPrepare/AtTyping/AtSound：AtPrepared.request、CheckedWitness.of_prepared_request、checkAt.sound/absolute | 篩付き groundTy と At 成功値を作る局所補題は済み。実表・Rust 比較は L50/R30/R50 |
| C09 | VarianceSyntax/VarianceValidation：Ty.VarianceOK、Program.VarianceValid、ParamOccursInFields；VarianceTransport：variance_field_mono | 正負規則・未使用を不変にする検証の定義は L10 で済み。辞書制約/公開境界のソース収集は L70/R10b |
| C10 | MeaningOrder：MeaningTransport.variance_meaning、variance_meaning_args、field_order；MeaningTransport：valueMeaning_sub | Ordinary を取れない場合の意味の移送も L20 で済み。意味の fn/map 等の枝は構文の canonical forms の代用にならない |
| C11 | TypedMeaning：typed_value_meaning_closed、inhabits_of_typed；ValueMeaning：ValueMeaning.assume | 全値の意味・Inhabits への橋は済み。Kripke/step-indexed な所属を独立の仮定として加えない |
| C12 | TypeSubstMain/CloseTyping/StoreReplyLeaves：type_subst_all、close_value_typed、StateTyE.store_reply；Narrowing：HasTypeVQ.narrow 等 | 型/行/範囲/値の全移送、閉じ方、格納・継続の保存を再実装しない |
| C13 | PathConditions：HasTypeCQ.ite_branch、ClosureTy.ite_selected、StateTyE.if_true/if_false；MatchPaths/MatchStateLeaves | if/guard/match の規則と一般葉は済み。B04 の有限証明書を実型付けへ供給する読者は残る |
| C14 | StepLeafSelection/ControlLeafSelection：selectOracle_response、selectRelease_response、selectFresh_empty、StateTyE.control_leaf | 応答選択・fresh と制御7葉は済み。主定理全体を先に閉じない |
| C15 | [L20 の76葉表](../l20/n/leaves.md)と各表中の宣言 | 継承69＋追加7、Step を返す60＋到達型だけ16の一般葉は済み。開始の canonical forms と各応答の供給が残る |
| C16 | Context：Ty.carrierFacts；CarrierFacts/CarrierFactsMeaning：Const.NumericRepresented.carrierFacts；NumericRepresented | 七整数型・Byte・Decimal の型域を置く作業と捕捉全読者の追随は済み |
| C17 | PreparedSortExamples：typed_observation、observations_16；ExternalObservation：HasTypeVQ.represented | 全16 sort の外側の観測成功は済み。snapshot 内の None まで成功としない |
| C18 | MeasureContracts：measure_machine_exact、measure_stable、field_measure_stable；NumericContracts：binary_normal、neg_normal、decimal_result；NormalResultLeaves：binary_leaf、binary_entails_at | 7 measure、七幅×加減乗21組と符号付き負号4組の正常応答の部品は済み。実 B.delta・標準契約へ結ぶ証拠は残る |
| C19 | KeyContracts：Observation.KeyShape.code、Key.code_of_shape、equal_of_shapes、decimal_key_compare、map_measure、set_measure；ClosedKeys：Key.normalizeMap/normalizeSet | 11形の鍵コード・重複縮約は済み。型付き鍵から KeyShape/ClosedSlots を供給する橋は未完 |
| C20 | PreparedLeaf：checkIn、entailsIn、bind_entails、checked_refinement；IntervalConnection：ValueRel.toApprox_eq、normal_shared_iff、typed_returned_mark、connect_bind/connect_return | 有限証明書から構文の LeQ への入口と正常/return の局所接続は済み。前提を読む LeQ の読者、実演算、failed の解析は残る |

### L40 に残る範囲

H01 は全値・全計算の開始逆転と F3 に沿った引数の移送、H02 は検証済みの変性を使う標準 data/record と鍵の具体表への接続、H03 は実 δ・全 sort・標準契約・枝の事実、H04 は正常/return/failed の所属の葉である。[L00b.15 の旧配分](../l00b.15/theorems.md)の H01〜H04 の時間を本書の積上げへ再加算しない。H02 の定義は L10、全状態の保存は L20、合成した主定理は L70 へ移っている。

LeQ/TelLe/型付けの相互帰納への新構成子は予定しない。標準契約の本体を出力関係だけで済ませず、CoreAssumptionsへ未証明の欄を加えない。

## 2. 規則・構成子・葉の全場合

以下の数は異なる母集団である。型の構成子、導出の構成子、演算の組合せ、実行の遷移を足して「証明件数」にしない。既済みの導出全33場合や実行全76葉を、L40 の新規証明件数へ掛け直さない。

### 部分型、依存列、変性

| 母集団 | 場合の列挙 | 数 | 既存の証拠／L40 の単位と完了の判定 |
|---|---|---:|---|
| Ty.LeQ | refl、convert、trans、fn_effect、list、lazy、map_value、forget、introduce、refine、dependentFn、scoped、scoped_forget、data | 14 | Le の規則は継承。02/06〜11で各逆転が convert/trans/篩3枝を含むことを照合 |
| TelLe | done、param | 2 | done の結果/効果は共変、param の入力は反変。02/11で渡し先の Γ.extend b の下で後続を比較 |
| TelClosure | refl、tail | 2 | InversionCore の推移を継承。11で全列の実引数適用へ移す |
| TypeArgsLe | nil、covariant_cons、contravariant_cons、invariant_cons | 4 | 10/11。正規形等号の枝を部分型へ緩めない |
| Polarity.compose と位置 | positive/negative/both × covariant/contravariant/invariant | 9組 | VarianceSyntax/MeaningOrder を継承し10の標準宣言・高階の読者で全組を照合 |
| 変性の構造再帰 | base、opaque、data、list、fn、tvar、reference、lazy、cont、map、set、bytes、dict、tapp、ctor、refined、dependentFn、external、scoped、pathBases、scopePattern | Ty 全21形 | 定義と21形の意味移送は継承。10で欄の負出現・相互再帰・述語と不変位置の利用例。辞書/公開境界の収集は L70/R10b |
| 組込みの共変位置 | List要素、Option引数、Result成功、Result失敗、Pair左、Pair右、Lazy内容、Map値 | 8位置 | 10。Map鍵、Set要素、Reference内容、Dict、external引数、継続、Fail は不変。Fail と Result の失敗型を混同しない |
| 範囲添字 | scoped の共変、scoped→opaque の忘却 | 2規則 | HeldValues の同じ値/要求の逆転を継承。13で L50 へ渡す。opaque 同士に新たな共変規則を足さない |

F3 の全位置は、最外の関数、引数中の関数、結果中の関数、List/Option/Result/Pair/Lazy/Map値の中の関数、data の正負欄、不変位置の関数である。06〜11はこれを構造再帰で処理する。本体・呼出し・resume の被覆、handler/Fail 節・純粋要求・部分適用の構造上の包含、ファイル/main/test 上限を、関数値の一原子の被覆へ一括で置き換えない（D10〜D14）。

### 値、計算、状態の開始逆転

HasTypeVQ は29構成子、HasTypeVsQ/HasTypeEachQ は各2、合計33場合である。V_Sub/V_Normal/V_Refine の三枝は各逆転で共通に扱う。ソースの var は開いた Γ の逆転へ残し、閉じた Γ では lookup の矛盾から除く。値の閉性だけから型引数の形成や捕捉の型付けを推測しない。

| 値の構文（Syntax の Val 全25形） | 逆転の出力・構成子への対応 | 単位 |
|---|---|---|
| var | V_Var。元のΓの同じ位置・Ordinary・coreの対応。篩の事実はfacts、閉Γでは排除 | 06 |
| const | V_Const。ConstOK と core の等号は inv_const を継承。篩の事実は facts | 12/16 |
| fnRef | V_Fun。宣言、NamesWF、Admissible、SignatureInstance、元の依存列と到達列の TelClosure | 06 |
| prim | V_Prim。同じ b/型・行・範囲引数、RangeAdmissible、PrimitiveAdmissible、SignatureInstance、TelClosure | 06 |
| op | V_Op。同じ宣言・SatAll・SignatureInstance と TelClosure | 07 |
| lam / dependentLam | V_Lam/V_DependentLam。自身の契約で検査済みの本体、元の名前、形成、到達列との TelClosure | 07 |
| closure | V_Closure。runtime signature と元の t の RuntimeShape、DependentClosureTy、到達列との TelClosure。inv_closure を再使用 | 11/15 |
| raise | V_Raise。結果T/誤りE、Ordinary、kind、名前 error、Fail E の正規形不変と TelClosure | 07 |
| con | V_Con。構成子宣言、保持された型引数と値、到達 data 引数への TypeArgsLe。既存 inv_con/constructor_field_inputs | 10/12 |
| list | V_List。HasTypeEachQ と要素 LeQ。既存 inv_list/list_element_facts | 12/21 |
| loc | V_LocRef/V_LocLazy。reference は内容型の正規形等号、lazy は内容 LeQ。継続値は ImageOk/ContTy から得る | 14 |
| mapV | V_Map。元の鍵型・値型・二列の型付け・同長・sat keyC、到達鍵の不変/値の LeQ | 08/22 |
| setV | V_Set。元の要素型・型付け・sat keyC、到達要素の正規形等号 | 08/22 |
| bytesV | V_Bytes。各 byte≤255 と bytes の core。一律の長さ上限は足さない | 08/17 |
| dict / super | V_Dict/V_Super。実装・型引数・辞書引数・上位クラスの同じ宣言。dict の型引数は不変 | 09 |
| externalRef | V_ExternalRef。宣言表・WF・admissible・SignatureInstance・TelClosure。応答存在は L60 | 13 |
| externalHandle | V_ExternalHandle。同じ名目 ID/component/resource/型引数個数。資源 opaque と混同しない | 13 |
| pathBases / scopePattern | V_PathBases/V_ScopePattern。Valid snapshot、WF/Canonical/FitsKind の同じ range | 13 |
| checked / checkedRequest / checkedAt | V_Checked/V_CheckedRequest/V_CheckedAt。HeldValues の保持対象/groundVal/reqTarget/CheckedWitnessを継承 | 13 |
| atError | V_AtError。ResultShape.Declared と StandardError、7文字列欄。con の inv_con には通さない | 12/13 |

HasTypeCQ は24構成子である。計算の構文は16形（builderLet、builderOp、ret、letIn、app、ite、match、lazyC、escape、use、handle、resume、externalCall、issuePathBases、checkAt、meth）。同じ構文に複数規則がある app/handle/resume と、外側の C_Sub/C_Normal/C_Eff を別に扱う。

| 開始の16形 | 使用する葉・逆転 | 単位／後段 |
|---|---|---|
| app | C_App/C_DependentApp の2枝から共通の依存列へ移す。値の列の型付けを TelClosure.apply で元契約へ戻す | 09/11/15。進行の分配は L70 |
| ret / escape | ret_value は継承。escape は元の R と返却値、外側の結果型/効果の拡大を別に返す | 09/35 |
| letIn / meth | let の束縛下の Γ/Φ と同じ戻り先；meth の実辞書・同時の型/行具体化と実引数順 | 09/15 |
| ite | 既存 ite_branch、B04 の false_side を本当の HasTypeCQ/ClosureTy の読者へ通す | 20 |
| match | C_Match から照合対象の HasTypeVQ、obs が some t のときの toTerm?/HasSort、HasTypeArmsQ、Exhaustive P a (unguardedPats arms) を取り出す。obs=None も保つ | 12/15/20 |
| handle / use / resume | 既存 HandlerGeneral/ContTy の入力へ接続。resume は変数/場所×生/正規形の4規則 | 14/15。全効果健全性は L70 |
| builderLet / builderOp / lazyC | LocalRef.HasKind、BuilderCellOk、canonical_lazy と StoreOk のセル | 14/15 |
| externalCall / issuePathBases / checkAt | ExternalStateLeaves/PathBasesLeaves/AtStateLeaves の既存入力。新しい応答を仮定しない | 13/15。実表は L50/L60 |

状態は run/matchRun/error/exit の4形、Frame は letF/mark/update/release/handleF/drop/guardF の7形、Cell は builder/val/thunk/done/cont/used の6形である。14/15/35が各形の既存の形成と開始の取り出しを対応する葉へ渡す。全76遷移の受け手は第6節、ContTyの全10規則は[結果](results.md#継続の判断の全10規則)に列挙した。

### 全 sort と measure の本番からの導出

| sort（具体化後16） | 本番の供給元と意味の限定 | L40 の読者 |
|---|---|---|
| integer | ConstOK/型域、七整数型と Byte の toTerm?、正常演算。数学上の Int と幅付きの値を区別 | 16/17/29 |
| character | Char の有効な値、characterCode と compare_exact。UTF-16 code unit を値域へ足さない | 17 |
| float64 / float32（2） | UInt64/UInt32 bits、float_class_exact、ieeeClass、Comparison。NaN/±∞/±0 を区別 | 18 |
| decimal | coefficient/scale の NumericRepresented、decimal_result、decimal_key_compare。正規化した数の等値と構造等号を区別 | 19/22 |
| boolean | Bool、BooleanApart、false_side。三値評価の none は真にしない | 20 |
| unit | const .unit、TypedMeaning。構造値や other と同一視しない | 12/35 |
| string | String の実 UTF-8 byte 数/文字数、charactersIn の有限区間 | 17/21 |
| list | listValue/toTermSlots。内部 None があっても外側の長さは得る | 12/21/23 |
| bytes | V_Bytes の全要素≤255と bytesLength | 17/21 |
| map | mapValue。size は鍵の縮約、値の観測成功は不要。Map 自身の鍵化には値も必要 | 08/22/24 |
| set | setValue と鍵の重複縮約。要素型は不変 | 08/22/24 |
| data | 宣言した構成子と FieldRef.Declared、同じ P.VarianceValid。atError は別の入口 | 10/12/25 |
| target path/host/endpoint（3） | typed_observation と保持対象。symbolic range の所属・全 σ は L50 | 13/28 |

Measure は stringBytes/stringCharacters/listLength/bytesLength/mapSize/setSize/characterCode の7構成子である。measure_machine_exact の実 `Observation.measure` の正常応答から machine_exact を得て、measure_stable/field_measure_stable で置換後も同じ観測とし、HasTypeVQ.represented で型付き実値へ戻す。Map/Set の入力については22の KeyShape の証明を先に供給する。7種類を一つの「length」と呼ばない。

### 数値の正常結果と Stop

| 系列 | 場合と数 | 既済み／追加する葉と単位 |
|---|---|---|
| 幅 | Integer64（表層Integer）、Integer8/16/32、UnsignedInteger16/32/64 の7。Byte は別の8番目 | 型域は C16。16で各幅の定数/境界と標準 δ の関係を使う |
| 線形に使う算術 | 七幅×add/sub/mul=21、符号付き四幅×neg=4、計25組 | NumericContracts/NormalResultLeaves は既済み。16/29で同じ δ の実正常応答へ結ぶ。mul の自動推論は定数倍に限る |
| 除算・剰余 | 七幅×intDiv/mod=14組 | Interval.Arithmetic の divMod と実定義から正常値/zeroDivisor/overflow を29へ。線形理論へ一般除算を追加しない |
| 整数比較 | 七幅×eq/ne/lt/le/gt/ge=42組 | 比較原子の健全性は L30。16/20で標準比較が同じ Boolean を返すことを供給 |
| Byte | 導入0〜255/域外、射影、明示変換、bitwise/shift の表現可能性 | 17。byte_and_u16_represented は演算の変換の証明ではない。公開 API がない Byte→UInt16 を新設しない |
| Character | toInteger/fromInteger と scalar 値域、比較6種、文字範囲 | 17。文字分類の全 Unicode 表の証明は追加しない。閉じた有限観測と型付き結果の契約を扱う |
| Float | 2幅×6分類=12、2幅×6比較=12。±0 の数の比較と bits の等号を区別 | 18。Float32 の丸めの全ビット証明は plan の外側のまま。一般算術を実数線形へ写さない |
| Decimal | 表現可能性1、比較6、round の丸めモードごとの正常/表現外、絶対値・明示変換/再検査 | 19。5モード（RoundingMode.bnt・DecimalRounding で確認）。群 A では Lean の有限表へ写す |
| 応答 | Outcome.val/err/exit の3形 | pure は val/err の2形で exit の不可能性を保つ。正常結果の表現可能性を error へ要求しない。16/28/29 |
| 区間の失敗理由 | unknown、overflow、zeroDivisor、outsideDomain、invalidBounds、outOfRange の6構成子 | TrackedFailure は unknown を除く5形（後二つは payload を量化）。29〜34。ErrKind や proof-steps の停止と同じ型にしない |

数値系列の数は演算族の展開数であり、Rust の全命令や比較入力の総数ではない。丸め5モードと標準δの全署名の対応を05で固定してからD/E群を起動する。

## 3. 標準契約の表と定義の配置

### 契約を証明する三つの層

第一に、一般の B.CoreAssumptions.delta_typed から、同じ実引数で具体化した結果型の正常値・Ground・AdequateResult が得られる。これは既存の信頼条件の利用であり、具体の標準表の充足証明ではない。第二に、Interval の checked 演算、Observation.measure、Key.normalizeMap/Set などの本番の定義から、具体の正常値と関係式を導く。第三に、その定義を呼ぶ標準 δ 又は通常の core 本体が、同じ引数列・結果・停止を持つことを証明する。L40 の新規の仕事は主に第二から第三への接続である。

現在の Refinement には全標準関数を覆う具体の B がない。旧 Model は Reference の表、ModelHttp/ModelTargets は HTTP/対象の表であり、全数値・コレクションの表を備えたものではない（各 builtins/sig_cases）。したがって「三モデルの仮定から全標準本体が済んだ」とは書けない。05で、数値/コレクションの実定義を使う具体の表と通常 core 本体を新しい下層モジュールに置き、入力・実 δ の等号・結果の型付け・関係式を一緒に証明する形を固定する。モデル全体の CoreAssumptions の充足は L60、R40 の本体/実装との有限比較は R50 と分ける。

新モジュールは `StandardContracts`（契約の構文）、`StandardScalar`（実演算と δ）、`StandardCollections`（実有限列/縮約と δ）、`StandardBodies`（通常 core 本体）、`StandardKeyTyping`（具体制約表と型付き鍵）を候補とする。既存の Le/Typing/MeaningOrder の下層へこれらを import しない。原始葉→標準 δ→標準本体→本体の型付け/実行の順で依存させる。

### 関係を追加する契約の有限表

これは全標準ライブラリの関数の数ではない。D02/D33/D34 と L30 からの申し送りで追加する関係式の一覧である。この表の36行に、数値の族と7 measure の各展開を対応させる。既存23モジュール・328公開関数の名前と分類は[結果のAPI一覧](results.md#既存の公開apiと契約の分類)へ分けた。現行 API の名前は `crates/benitoite/src/prelude/stdlib/` の同名ファイルで確認した。新しい安全な入口は core 内部名で計画し、公開名/文法は U02/L70 の判断に残す。

| 契約行 | 対象と正常時の関係／失敗・条件 | 定義からの道筋 | 単位 |
|---|---|---|---|
| S01 | 七幅の加減乗/負号。正常値は同じ算術値、同じ幅に表現可能 | checkedAdd/Sub/Mul/Neg→NumericContracts→StandardScalar の δ 等号→受信値の facts | 16/29 |
| S02 | 七幅の intDiv/mod。正常と0除算/overflowを区別 | checked 演算と OperationResult の場合分け→局所の δ 応答 | 29 |
| S03 | 整数/Character/Float/Decimal の比較。正常応答の Boolean が原子と一致 | Observation.compare と本番比較の対応→B04/枝 | 16〜20 |
| S04 | Byte の導入/射影/明示変換と表現可能性。Option の None は正常な値 | Byte.bnt・実変換→ConstOK→同じ数の項。UInt16の表現可能性との区別 | 17 |
| S05 | Character の code と有効 scalar、String の文字範囲 | characterCode/charactersIn と実 `Char`/`String` 観測 | 17/21 |
| S06 | Float二幅の所属・分類・比較 | bits/ieeeClass/compare、有限分類の葉→型付き正常応答 | 18 |
| S07 | Decimal の仮数/scale、比較・round 正常結果と表現外 | NumericRepresented・ScalarLogic の比較→同じ丸め定義と再検査。外側の文字列パースを証明済みにしない | 19 |
| S08 | String.byteLength / characterCount の正確な二長 | Observation.measure の stringBytes/stringCharacters、実「é」の2対1 | 21 |
| S09 | Bytes.fromList/toList/length の byte の範囲と同長 | V_Bytes、bytesLength、有限列の長さ | 17/21 |
| S10 | List.length/isEmpty、構築 [] / cons の長さと非空 | listLength、inv_list、空/cons の2場合 | 21/23 |
| S11 | List.prepend/append は n+1 | xsの前/後へ一要素。現行 append は List 同士の連結ではない | 21/23 |
| S12 | List.concatenate は n+m | 実連結の列と二引数の順 | 23 |
| S13 | List.reverse は n | 有限列の reverse と要素の型付け | 23 |
| S14 | List.map は n、各正常 callback 結果は U、潜在効果 E | mapFrom の i/acc/残りの不変条件と実 core 本体。callback の正常応答の存在を要求しない | 23 |
| S15 | List.filter は 0≤m≤n、保持した要素の型は T | filterFrom の真/偽の2枝、順番・失敗/効果の伝播 | 23 |
| S16 | List.head/tail/get の旧 Option と安全な T の入口を区別 | 既存 Option API はそのまま。証明済み非空/0≤i<n から内部 safeHead/safeGet | 26 |
| S17 | Map.empty/fromList/size/toList、正規化後の大きさ | 元の鍵と後の値を保つ normalizeMap、KeyShape/ClosedSlots | 22/24 |
| S18 | Map.keys/values は size と同長 | normalizeMap の同じ entries の射影 | 24 |
| S19 | Map.set は n 又は n+1、remove は n 又は n−1 | 同じ鍵コードの一致/不一致の2枝。get/containsの旧Option/Booleanを保つ | 24 |
| S20 | Map.map は n、filter は m≤n、値共変/鍵不変 | 現行 Map.bnt の Map.toList→List.map/filter→Map.fromList、同じ鍵の保持 | 24 |
| S21 | Set.empty/fromList/toList/size の縮約後の大きさ | normalizeSet と鍵の不変位置 | 22/24 |
| S22 | Set.add/remove は一致/不一致の二枝、map/filter は m≤n | map は異なる元要素を同じ鍵へ写しうる。n と等しいとはしない | 24 |
| S23 | Set.union/intersection/difference の上下限 | 正規化済みコード集合の包含、0≤m、union≤n+k、intersection≤min、difference≤n | 24 |
| S24 | record の不変な欄・欄の連鎖・全体条件 | 同じ P の field_facts_by_type/FieldRef.Declared/VarianceValid。構築時に全体述語を証明 | 25 |
| S25 | decode は通常decode→各欄→全体条件の順、失敗は Error | 通常 core の検査列。検査成功の事実を値の型へ導入し、順と payload を保持。JSON の字句処理の一般証明はしない | 25 |
| S26 | Range.CheckedInteger の minimum/maximum/value と旧 RangeError | checkInteger の条件、invalidBounds/outOfRange、射影が同じ保持値 | 26/30 |
| S27 | Range.CheckedLength の上下限・checkedLength/lengthValues | 元 List を保持し、n=length values と lo≤n≤hi | 26 |
| S28 | Range.CheckedIndex の indexValue/indexValues/get | 元 List と保持 element の同一性。get が任意の別 List の要素を返すとはしない | 26 |
| S29 | 同長の別 List の safeGet | length xs=length ys=n と0≤i<nから ys の要素T。元の CheckedIndex の保持 element と区別 | 26 |
| S30 | NonEmptyList は nonemptyType T の別名、fromList/toList/head/tail/map | 現行の nominal record から移す core 契約。head:T、tail長n−1、map正常時非空。公開表示/名目性はR40/D10 | 26 |
| S31 | 関数/高階の入力反変、結果/潜在効果共変、名前/個数不変 | TelClosure.apply、型付き callback と依存結果/効果の同時代入 | 11/27 |
| S32 | 範囲付き値の標準契約への受渡し | HeldValues と ModelHttp.valueRun、同じ要求/対象。File 6本と Http.sendIn はL50へ | 13/28 |
| S33 | 正常/returned/failed の近似所属と Stop の区分 | ValueRel→toApprox_eq、EvalPartial/Block/Arms、実際の最初の失敗。proof-steps の unknown と混同しない | 29〜35 |
| S34 | 七整数型・Byte の明示変換、Decimal との変換。fromInteger/fromDecimal の Some は同じ数学値かつ対象幅内、None は通常値。toInteger は小幅で全域、u64 では Option | 実変換と対象幅の ConstOK/NumericRepresented→同じ値の項。Decimal.fromInteger/truncate/fromFloat は S07 と併用し整数性/切捨て/失敗を区別 | 16/17/19/28 |
| S35 | 七幅の floorDivide/floorModulo。床方向の商と剰余の関係、0除算、符号付き最小値÷−1の商の表現外 | 実 intDiv/mod と符号補正を同じ δ へ接続。floorModulo を商の overflow だけで拒否しない。名前付き18 API は別名を除き七幅×2演算の14組 | 16/29 |
| S36 | 七幅の absolute/minimum/maximum、各幅と Byte の bitwise/shift。正常値の表現可能性、符号付き最小値 absolute の Stop、shift count の域外 | 実 checked_abs/比較選択/幅内ビットと count 検査→型付き応答。正常 abs は非負、unsigned abs は同値。ビット演算を線形整数の一般推論へ加えない | 16/17/29 |

S08〜S23以外の既存 String/Bytes/List/Map/Set の API に、根拠のない長さの等式を追加しない。通常の宣言結果の型付けは同じ応答契約の全署名照合へ含める。05では各 API を「本表の新関係」「既存の通常結果だけ」「L50/L60」「外側の字句/ABI」に一行ずつ分類し、API を表から消して通常型まで未照合にしない。対象23モジュールは結果のAPI一覧で名指しし、Integer/Integer64、UnsignedInteger/UnsignedInteger64、Byte/UnsignedInteger8、Float/Float64 の型の別名は、API行328件と区別する。Codec/Property/derive の全生成物・Rust 本体は R40、表層ソースから本体を収集する接続は L70/R10b に残す。

## 4. 固定する署名と証明の順序

新設する入口の完全署名又は定義の形を示す。`P B Ψ Q C Γ Φ` は現行HasTypeVQと同じ。02〜05で確認し、取りまとめの署名の指定後に実装する。変更は共通依頼文の署名変更の手順に従う。

### F01: 構文の逆転の出力

fnRef/prim/op/lam/dependentLam/raise/externalRef は、元の規則の直接前提と、`T.fnCore = some u`、元の依存列 t から u への `TelClosure P Γ Φ t u` を返す。元の規則の前提は Typing の対応する構成子の矢印の左辺を一つずつ保持する。規則の直接前提を返し、型付け自体をrecordで持ち回さない。

prim/mapVの完全署名の例は [結果](results.md#f01の完全署名の例detail-第4節の別表)へ分けた。F01の上記の定義の形と、旧31行の行き先を使い完全署名を固定する。

上の新署名の証明は未実施である。値の意味の map/fn 枝が任意の v を許すため、ValueMeaning の逆転だけでこれらを証明する案は使えない（ValueMeaning の実定義）。

### F02: F3 の実引数への適用

```lean
theorem TelClosure.apply {P B Ψ Q C Γ Φ t u ws a e}
    (hP : P.WellFormed) (hB : B.CoreAssumptions P) (hw : Ψ.WF)
    (ht : Ty.Annotation P C Γ (.dependentFn t))
    (hu : Ty.Annotation P C Γ (.dependentFn u))
    (h : TelClosure P Γ Φ t u)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f
```

02は param の1引数、tail の2段の合成、依存する後続、正規化した fn↔dependentFn の代表を確かめる。11の本証明は TelClosure の帰納の中で TelLe の param/done を処理する。既存 narrowing、Tel.argumentsEnv、LeQ.bind/Transport を使い、相互の型付け33/76場合を増やさない。形成の ht/hu は新しい主定理の仮定ではなく、開始の元導出と型注釈から得る証拠である。これを供給できないときは独立の信頼条件へ置き換えず停止する。

### F03: 全 canonical forms と実行の入力

閉文脈の Boolean の入口は次である。

```lean
theorem HasTypeVQ.canonical_boolean {P B Ψ Q C Φ v T}
    (h : HasTypeVQ P B Ψ Q C [] Φ v T)
    (ht : T.norm.core = .base .boolean) :
    ∃ b, v = .const (.boolean b)
```

Scalar は `T.norm.core = .base tag` を入力に、同じ tag の Const と ConstOK を返す。List は既存 inv_list と閉文脈の構文排除から `∃vs, v=.list vs`、data は con 又は標準 atError、関数は fnRef/prim/op/raise/lam/dependentLam/closure/externalRef の8構文を返す。最後の8形のうち、実際の q.view で生の lam/dependentLam が closure へ変わる点は closeVal の定義を使って15で接続する。（注: 捕捉から読む生の lam は closeVal で closure に変わらない。15 では、広げた E_Lam の前提 `closeVal Capture.empty f = .closure …` で供給する。plan.md の 2026-11-03 の L40.15 の停止の項。）δ が closure の内部の場所番号を読める既存の境界を狭めない。

Map/Set/Bytes/Dict、scoped/opaque、external、PathBases/ScopePattern の canonical forms は第2節の各行の構文と元規則の前提を返す。tvar/tapp/ctor は閉じた値 kind の Annotation の下で排除し、cont は値の一般の HasTypeVQ ではなく ImageOk/ContTy の場所の証拠から読む。量化を閉じた規則に限るだけで、実行全状態を空ストアへ限らない。

セルの入口は次の定義の形で固定する。`StoreOk` の既存の二つの対応（Ψ→μの存在、μ→CellOk）を使う。

* `ref_cell`：`StoreOk … Ψ μ`、`Ψ l=some (.ref a)` から、`∃v, μ l=some (.val v) ∧ HasTypeV … v a.norm ∧ v.Adequate σ`。
* `lazy_cell`：同じ入力の `.lazy a` から、`μ l=some (.thunk q)` と既存 ClosureTy の証拠、又は `.done v` と HasTypeV/Adequate の証拠。
* `cont_cell`：`.cont b t e r` から `.cont k` と ContTy/EndsWithHandle、又は `.used`。
* `builder_cell`：`.builder kind` から対応する BuilderCellOk。型に現れない捕捉位置へ全位置の LocalRefs を要求しない。

### F04: 正常応答から facts への入口（短い試行で確認済み）

```lean
theorem normal_reply_facts {P B Ψ b sg ts es rs ws a e out v t}
    (hB : B.CoreAssumptions P)
    (hs : B.sig b = some sg) (hk : sg.kind = .pure)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e)
    (hd : B.delta b ts es rs ws = some out)
    (hv : out = .val v) (ht : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t)
```

CoreAssumptions.delta_typed の同じ応答との等号で分岐し、Outcome.Typed の値の型付けから facts を得る。値の型付けと Ground が連言で返るので、その第一成分を読む。この形は補助入力で証明と公理依存を確認した。`hd` は実 δ の呼出しの等号であり、「δ は算術に一致する」という新しい未検査条件ではない。具体表の hd と NumericContracts の normal の対応は16/19/23/24/29で証明する。

### F05: 具体の鍵の表

一般のB.sat keyCだけからKeyShapeは導けない。LegacyPatternExamples.builtins.satは全てTrueで関数も通すため、標準鍵表の代用にはしない。

`StandardKeyTyping` には次の証明の目標を置く。KeyObservationは全値の意味に関する独立の前提ではなく、具体表について証明する結論である。

```lean
def KeyObservation (P : Program) (B : Builtins) (a : Ty) : Prop :=
  ∀ {Ψ Q v}, HasTypeVQ P B Ψ Q [] [] [] v a →
    ∀ η : ObservationEnvModel, ∃ t o,
      v.toTerm? = some t ∧ t.Closed ∧ t.observe η = some o ∧ o.KeyShape
```

具体の鍵表の入力は、有限な構成子名/ConDeclの一覧がP.consと一致すること、同じ欄のcarrierをRelease/BuiltinTableのBuiltinDataDeclへ写すこと、S=dataSummaries dsとsummariesConverged ds S=true、B.satの鍵の判定がその計算結果と等しいことを保持する。名前だけが同じ別の表は渡さない。carrierの写しはdata/List/Map/Set/base/bytes/tvarを保存し、関数/参照/外部等を鍵不可の骨格へ写す。未使用の型引数を持つdataは、現行 satB と Rust の判定に合わせる。未使用の関数型引数を一律に拒む変更や受理の拡大は行わない。具体の表から等号を証明して構成する入力であり、「全欄の値は鍵になる」という意味上の結論を入力欄にしない。

証明はP.VarianceValid、同じ表のsat成功と閉じた値の導出からKeyObservationを結論する `key_table_sound` と、HasTypeVsQ/HasTypeEachQの列版を相互に証明するものとする。型の再帰dataの展開へ構文の大きさの減少を要求せず、有限な値の導出で帰納する。要約の成功を全欄へ移す補題はdataSummaries/summariesConvergedから証明し、未検査のrecord欄にしない。成功11形をKeyShapeの構成子へ写し、列版からKeySlots/KeyPairs/Key.ClosedSlotsを得る。Mapのsizeは値側の鍵化を要求しない。

03はList[Decimal]、Map[Integer8,List[Decimal]]、相互再帰data、関数欄の拒否、未使用の関数型引数を持つdataの5形を確認する。同じ宣言・型を旧 BuiltinTable.satB に与えた結果と、Rust の typeck/decls.rs の summary、typeck/solve.rs の鍵制約、ir/check.rs の satisfies の判定を群 A で照合する。未使用引数では等値と鍵の両要約の依存位置を確認し、入力と結果を記録して R50 の交換へ渡す。読取りからは依存位置だけを検査する実装に見えるが、代表の同一入力での一致は未実行である。食い違えば J40-1 へ戻す。具体表のデータと等号の構成を含む署名を取りまとめへ返す。宣言収集がなくds/Pの一致を供給できなければJ40-1へ戻す。L70/R10bへ残るのは同じ宣言からの表の収集であり、鍵の意味を新しい信頼条件として供給する義務ではない。

### F06: 標準本体の型付けと成功時の関係

`StandardContracts` の一行は、`name : String`、`tparams : List TParamDecl`、`neffs : Nat`、`tel : Tel`、`body : Option Comp`、実装の選択（pure δ/core 本体）、第3節の関係の種別を持つ有限データとする。関係の証明を record の未検査の欄にしない。新しい公開名や、任意の Prop を登録する仕組みを加えるものではない。

pure の行は既存の BuiltinArgs/Outcome.Typed/AdequateResult を全 ts/es/rs/ws/Ψ について証明する。core 本体の行は `Def.WellTyped P B d` と同じ量化で証明し、結果の関係は `Steps` の正常返却又は `IntervalConnection.Runs` の正常結果から導く。返却の存在/停止は結論しない。map/filter の callback は同じ型付き f と実際に観測した子の有限な実行を使い、callback を数学上の全域関数にして失敗を消さない。

23の mapFrom の不変条件は `i + remaining.length = xs.length`、`acc.length=i`、acc の各値がU型、残りが元列の suffix、順序を保持することである。filterFrom は `acc.length≤i` と同じ suffix/要素型を使う。i は数学上の添字であり、現行の幅付き Integer の加算の正常性は、次へ進む実入力の条件と合わせて示す。有限列の数学的長さ全域を Integer64 に収める新しい仮定は足さない。length の正常返却はその返却値が表現可能な場合であり、表現外の実応答は Stop の枝である（D21/D23）。

### F07: H04 の二候補と所属

解析の第一候補の署名は [L20 の受渡し](../l20/n/h04-handoff.lean)の先頭をそのまま使う。

```lean
theorem tracked_failure_sound
    (abstract : Benitoite.Interval.AbstractEnv)
    (concrete : Benitoite.Interval.ConcreteEnv)
    (input : Benitoite.Interval.EvalInput)
    (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace)
    (hm : Benitoite.Interval.Models abstract concrete)
    (he : Benitoite.Interval.EvalPartial concrete input (.failed reason) trace)
    (ht : IntervalConnection.TrackedFailure reason trace) :
    (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true
```

limits/state/fuel の成功を前提へ足さない。現在の NormalSoundness/WarningSoundness は正常値/警告の定理であり、failed の所属の証明にはならない（BudgetNormal.analyze_normal_sound、BudgetSound.analyze_warning_sound）。30〜32 は外部依存を04だけにし、群 F1 として A の直後、B〜E を待たずに起動する。内部は30→31→32の順で同じ帰納を完成させる。BudgetAnalyze.report の停止は baseUnknown に退き、未対応も unsupported から baseUnknown になる（Sound.baseUnknown.mayFail=true）。BudgetNormal.Success/SuccessAt は任意の事後条件 post を受けるので、既存定義を変えず失敗成分を追加できる見込みである。全109場合の証明は未実施であり、この見込みを完了とはしない。旧の正常値/警告の定理の量化と結論は保つ。

実行の第二候補は同じ受渡しの `H04.FirstFailureHandoff` の完全な定義を使用する。BeforeError/BeforeErrorSteps と first_error/pure_failure は [補助の反例・証明](../l20/n/h04-counterexample.lean)にあり、現在は既定 import の外である。34で本番へ移す場合も、最初の error の位置・同じ δ の実引数・その後の Steps という結論を保つ。`neg x + neg y` の後の独立評価の拒否を要求した OldH04 は復活させない。

正常/return の所属は `ValueRel c v` と同じ解析出力の各成分の所属から、`c.toApprox=v.toApprox` で移す。次の系は新しい仮定を足さない定義の形である。

```lean
theorem normal_mem_of_related {f : Shared.FlowApprox} {c v}
    (h : IntervalConnection.ValueRel c v) (hc : f.NormalMem c.toApprox) :
    f.NormalMem v.toApprox
theorem returned_mem_of_related {f : Shared.FlowApprox} {c v}
    (h : IntervalConnection.ValueRel c v) (hc : f.ReturnedMem c.toApprox) :
    f.ReturnedMem v.toApprox
```

この二つの系は ValueRel.toApprox_eq による書換え一回で閉じる。33の実質は、次の局所規則を実際の return/枝/腕/Block の構成へ適用することである。

`joinV : Shared.ValueApprox → Shared.ValueApprox → Shared.ValueApprox` は bottom を単位、同幅整数を区間包、Boolean を各フラグの論理和、異種を unknown とする形で定義し、左右の Mem を保つ。`normalF a=⟨a,bottom,false⟩`、`returnF f=⟨bottom,joinV f.normal f.returned,f.mayFail⟩`、`joinF f g=⟨joinV f.normal g.normal,joinV f.returned g.returned,f.mayFail || g.mayFail⟩`、`seqF h t=⟨t.normal,joinV h.returned t.returned,h.mayFail || t.mayFail⟩` を新設する定義の形とする。次の各規則は、同じ子の EvalPartial/EvalArms/EvalBlock の観測結果の ResultMem を入力に、親の結果の ResultMem を結論する。

| 局所規則 | 33で固定する前提と結論の形 |
|---|---|
| return | 子が normal c なら returnF f の ReturnedMem c.toApprox、returned c は同じ成分へ、failed は mayFail。normal成分はbottom |
| 順次 | head が normal のときだけ同じ値を束縛した tail の所属を使い seqF h t へ。head の returned/failed は tail を使わず伝播 |
| 枝・腕 | 実際に選択した同じ枝/腕の所属→joinF の対応成分。skip/guardFalse は残りへ、guard の returned/failed は伝播。Result の tag/payload の全体構成は含めない |
| Block | empty は unit の normalF、last は同じ子の flow、bind/discard/seq/pat は順次、return は returnF、各 abrupt は同じ returned/failed を伝播。EvalBlock14構成子に一対一で対応 |

joinV の左右所属、returnF/seqF/joinF の局所所属の証明と、その規則を使う本番読者を33の完了条件とする。任意に渡した returned 成分への所属だけでは閉じない。これを全実解析の returned の健全性とは呼ばず、35が同じ型付き mark/escape の読者を供給する。親実行の子への分解、other Result の tag/payload の構成、腕の束縛数、全表層の本体所有、全比較は L70/R10b/R50 に残す。

### 短い試行の状態

| 方式 | この下書き中の確認 | 未確認の範囲／最初の群 |
|---|---|---|
| 前提を読む長さの LeQ | `lengthPremise :: assumptions [Integer8] [] (List Unit)` を lengthCertificate が読み、lengthGoal を返す。checked_refinement への適用も成功 | 任意の文脈/型と全四置換の本番読者は20/27 |
| 正常応答の facts | F04 の一般署名と証明が成功 | 全具体の δ の一致/所属は05/16〜29 |
| Boolean→型付け | false_side の任意 t への bind と HasTypeCQ.weaken_conditions の合成が成功 | 実際の C_If/guard/捕捉で同じ body が事実を使用する読者は20 |
| 既存の逆転/変性 | fnCore_right、inv_closure、variance_meaning、canonical_lazy の実型を Lean で確認 | F02 の一般の反変適用と新逆転全体は02/06〜15 |
| 鍵の具体表 | 既存の定義を読んだ。satB と KeyShape の橋は未証明 | 03。一般 B.sat から導かない |
| H04 | 前段の候補・反例・補助証明を読んだ。第一候補は未証明 | 04。候補の型検査を証明と数えない |

補助入力での最終の3定理の公理依存は許可三公理だけだった。初回の射影の誤りと、Boolean の補助証明の構文の誤りを修正して再検査した。本番の既定ビルド・独立レビューは行っていない。試行の再現に必要な定義とコマンドの形は [結果](results.md)に記す。


## 5. 起動単位・群・依存

通常は30〜60分程度、重い単位には場合の数に応じた個別の幅を置く（下表）。全40単位・8群。IDを保ち、起動順はA→F1→B→C→D→E→F2→Gとする。F1は04だけを外部依存とし、B〜Eとは別に起動してよい。共有のIntervalFailureへの編集は群内で直列に行う。各行の「手順→完了の判定」は両方を含む。署名欄の F/S は第3・4節の定義に対応し、単位名だけを渡して実装担当に規則の選択を任せない。

L は関係するモジュールを単一 Lean で検査する途中の局所確認、W は作業末の work、RV は取りまとめが依頼する群の独立レビューである。群が一つの起動依頼・取り込みの単位となる場合は W を群末で一度実行する。単位を別に取り込むときは、その最後の状態について一度実行する。最初の群で固定した後続署名を変える必要があれば、依存群を止めて取りまとめへ戻す。

### 起動単位の一覧

| ID/群 | 目的 | 触るファイル | 完全署名又は定義の形 | 手順→完了の判定 | 依存 | 所要時間（能動時間） | 検査 |
|---|---|---|---|---|---|---:|---|
| L40.01/A | 入口の全表と控除を固定 | 本書・本番は読取り | C01〜20、Val25/Comp16/State4、56/60/64行、旧31逆転の行き先とN_g（結果の別表） | 旧31逆転の分類・全場合を照合→既済み/新規/後段、N_V=1/N_C=9と全行の受け口が一致 | L20/L30受入 | 25〜40分 | L |
| L40.02/A | F3適用の方式を確認 | TelApplication（新）・TelTyping/Narrowingは読取り | F02。param一段・tail二段・依存する後続の4代表 | 入力の形成→narrow→同じ実値のbind→結果/効果の推移の順を確認→新しい主定理前提なしで完全署名を固定 | 01 | 35〜75分 | L |
| L40.03/A | 具体の鍵の方式を確認 | StandardKeyTyping（新）・BuiltinTable/KeyContractsは読取り | F05、11 KeyShape形/列2形/対列2形 | 同じ5代表を具体表・旧satB・Rustの判定へ対応し結果を記録→F05の署名を返す。一致はR50へ渡し、差はJ40-1へ。橋の結論を前提にしない | 01 | 40〜85分 | L |
| L40.04/A | H04の解析の方式を確認 | IntervalFailure（新）・Interval/BudgetNormal/BudgetAnalyzeは読取り | F07 tracked_failure_sound、既存Success/SuccessAtの失敗成分 | 直接overflow、短絡、return後の番兵、上限停止、Range Errorの5経路を小さく確認→109場合の失敗成分の帰納の形を固定。候補が偽なら反例で停止 | 01 | 25〜50分 | L |
| L40.05/A | 標準契約と全署名を固定 | StandardContracts/StandardScalar/StandardBodies（新） | F04/F06、S01〜36、結果の23モジュール328API、丸め5モードのLean表、内部の安全な入口の引数/結果 | 具体δ/core本体を実定義へ対応→全署名を確定。どの証拠を受け何を返すかを末尾で確定し結果に書きU02へ渡す。公開名/字面は未決のまま、既存Option/Result APIは保つ。未確定ならD/Eを起動しない | 02/03/04 | 60〜110分 | L・W・RV |
| L40.30/F1 | 解析の失敗の基本枝と引数 | IntervalFailure（新）・BudgetNormal/Arithmetic利用 | F07、EvalStandard7・EvalPartial先頭〜算術枝と引数4＋4 | 既存の正常Containsを成功した子へ利用し、失敗はmayFailで保持→RangeのError値とfailedを区別。Parametersの無制限の量化を保つ。Success/SuccessAtは任意postなので定義を変えず失敗成分を足す見込み。 | 04（群内30→31→32） | 40〜80分 | L |
| L40.31/F1 | 解析の制御・腕・Blockの失敗 | IntervalFailure（新） | F07、Partialの制御枝、Arms6×3、Block14、全109場合の相互の言明 | 30の帰納へ条件/短絡/return/skip/guard/Result腕を同じ動機で組込む→既知の失敗が後続で消えない。別の相互帰納を重ねない | 04（群内30→31→32） | 60〜110分 | L |
| L40.32/F1 | 上限停止と第一候補を閉じる | IntervalFailure（新）・BudgetAnalyzeの実入口を利用 | F07 tracked_failure_sound、Coverage complete/unsupported/stopped | 実report/analyzeの全結果からmayFailへ→上限0/既消費/fuel0も入力を狭めず処理。unknownの除外はTrackedFailureだけ。Normal/WarningSoundnessを保持。停止/未対応はbaseUnknown.mayFail=trueへ。全109場合を終えてJ40-2を早期判定。 | 04（群内30→31→32） | 35〜70分 | L・W・RV |
| L40.06/B | 変数と宣言済み関数・primの逆転 | ValueInversion（新） | F01の規則の直接前提＋TelClosure、inv_var/inv_fnRef/inv_prim | 旧3補題を新LeQで移し、本番に残す→C_SubでなくV_Sub/Normal/Refineの鎖、同じ署名/引数/名前を返す | A | 25〜45分 | L |
| L40.07/B | op・lambda・raiseの逆転 | ValueInversion（新） | F01、inv_op/inv_lam_wf/inv_lam/inv_dependentLam/inv_raise | 旧3目的と追加のdependentLam/raiseの2目的を依存列へ→本体契約、Fail不変、source annotationを保持。旧に同名の新2補題はない | 06 | 30〜55分 | L |
| L40.08/B | Map・Set・Bytesの構文逆転 | CollectionInversion（新） | F01 inv_mapV、同形のinv_setV/inv_bytesV | LeQのmap/set/bytes射影を先に証明→元の型付き列・同長・sat・不変鍵を返す→core同士の意味上の包含で代用しない | 06 | 25〜50分 | L |
| L40.09/B | 辞書と呼出し・let・escapeの逆転 | ValueInversion/ComputationInversion（新） | F01/F03、inv_dict/inv_super/inv_app/inv_let/inv_escape | 旧5目的を移し、appの2規則を依存列で統一→実辞書と戻り先、束縛下のΦ、外側の結果/効果を分離。最初の16目的（旧14移植＋新2）を記録し、群B末に更新式へ渡す | 07/08 | 30〜55分 | L |
| L40.10/B | 変性の既存証明を標準宣言へ供給 | StandardVariance（新） | P.VarianceValid、TypeArgsLe、F3の8共変位置/9正負組 | Option/Result/Pairと負の関数欄・相互再帰・不変位置の実宣言を検証→既存field_order/valueMeaning_subを利用。ソース収集の完全性はL70 | 09 | 25〜50分 | L |
| L40.11/B | 依存列の実引数適用を閉じる | TelApplication（新） | F02 TelClosure.apply、TelLe.done/paramとTelClosure.refl/tail | 02の骨格へ一般の列・正規化・関数viewを実装→反変入力/依存結果/潜在効果の3結論が同じwsで得られる | 02/06〜10 | 50〜110分 | L・W・RV |
| L40.12/C | 全scalar/List/dataのcanonical forms | CanonicalValues（新）・既存Canonical/ValueFactsは利用 | F03、scalar各tag/list/con-or-atError | V29＋列2＋Each2の既存意味を使い、形は構文導出から得る→空篩はinhabitsから排除、atErrorをconだけの逆転へ流さない | B | 30〜55分 | L |
| L40.13/C | 保持値・外部・PathBasesの開始入力 | CanonicalValues/LeafInputs（新） | F03、既存HeldValues/ExternalRef/PathBasesの直接前提 | 全Val25形のうち8形を照合→同じ要求/endpoint/名目ID/snapshotと導入経路を返す。全σと外部応答はL50/L60へ固定 | 12 | 25〜45分 | L |
| L40.14/C | 場所・セル・継続の形を接続 | CanonicalCells（新）・StoreGeneral/ContinuationGeneralは利用 | F03 ref_cell/lazy_cell/cont_cell/builder_cellの定義の形 | StoreOkの存在とCellOkを逆転→ref/lazyの実セル、used/cont、builderを返し全6セル/7枠に対応。捕捉の全位置を強めない | 12 | 30〜65分 | L |
| L40.15/C | 全開始状態を76葉の入力へ供給 | LeafInputs（新）・ClosureViewTyping/StateLeavesは利用 | Comp16形・State4形、matchのHasTypeArmsQ/Exhaustive/obs、第6節76葉への入力 | q.view/元コード/捕捉から全開始入力を得る。C_Matchの照合値、obs=None/someのsort条件、腕、網羅性を保持→既存60 Step葉/16到達葉へ渡す。主定理は閉じない | 11/13/14 | 50〜100分 | L・W・RV |
| L40.16/D | 各幅の定数・算術・比較とδ | StandardScalar（新）・NumericContracts利用 | F04、S01/S03/S34〜36、算術25/比較42/明示変換20 API/床除算14組/abs7型 | 各幅の実変換のSome/Noneと同値・範囲、正常算術/比較/min/max/bitwise/shiftの実δを固定。床除算と最小値absoluteのStopは29へ。型域だけの仮定にしない | A/C | 55〜105分 | L |
| L40.17/D | Byte・CharacterとBytesの値域 | StandardScalar/StandardCollections（新） | S04/S05/S09/S34/S36、Byte=UnsignedInteger8の別名、ConstOK/V_Bytes/characterCode | 実導入/射影と正常結果を各篩へ結ぶ→0/255/域外とCharのscalar/字句外側を分離。暗黙変換や架空のByte→UInt16 APIを足さない | 16 | 30〜55分 | L |
| L40.18/D | Float二幅の分類・比較 | StandardScalar（新） | S06、2幅×6分類12、2幅×6比較12 | 実bitsから有限規則とBoolean結果へ供給→NaN/±∞/±0、数の等号と構造等号を対照。全ビットの丸めは外側 | 16 | 25〜50分 | L |
| L40.19/D | Decimalの正常値・丸め・比較 | StandardScalar（新） | S07、丸め5モードごとの正常/表現外/不正places | 同じ仮数/scale/丸め定義の応答からNumericRepresentedへ→表現外をStop/Option失敗と区別し比較6種を受信の葉へ供給 | 05/16 | 40〜85分 | L |
| L40.20/D | 有限事実を実際の枝とLeQへ通す | StandardFactExamples（新）・PathConditions利用 | F04、前提を読むlength_le、false_fact_typingの形 | len=n,n>0の同じ前提を読むLeQと、B04のNotを必要とするHasTypeCQの本体を構成→if真偽/guardを元CaptureOkで閉じ、unknownと到達しない右辺を除外しない | 11/16〜19 | 30〜55分 | L・W・RV |
| L40.21/E | 二つのString長とList/Bytesの長さ | StandardCollections（新） | S08〜S11、7measure中string二種/list/bytes | 実measure→正常δ→長さの篩へ→非負を有限幅の上限へ変えず、length表現外の停止を残す | D | 25〜50分 | L |
| L40.22/E | 型付き鍵から構造と縮約へ | StandardKeyTyping（新） | F05 key_shape/列版、KeyShape11＋KeySlots2＋KeyPairs2 | 03の方式で具体のsat/宣言から全有限値を帰納→Key.ClosedSlots/実鍵コードを供給。Decimalの数の同値、Map値NoneとMap自体の鍵化を区別 | 03/08/10/19 | 45〜95分 | L |
| L40.23/E | Listの標準δと通常map/filter本体 | StandardCollections/StandardBodies（新） | S11〜S16、F06 mapFrom/filterFromの不変条件 | prepend/append/concatenate/reverse→map/filter本体の型付けと正常時の関係→n+1/n+m/n/≤nを実行から得る。callback失敗・効果と一度の評価を保持 | 21/22/11 | 40〜80分 | L |
| L40.24/E | Map/Setの標準δと高階本体 | StandardCollections/StandardBodies（新） | S17〜S23、縮約済みentries/codesとF06 | size/射影/更新/削除/集合演算→Map/Setのmap/filterの通常本体（4本、List側の2本を利用）→Mapの同鍵保持とSet.mapの縮約を区別。全S行の成功/不一致/空の枝を閉じる | 22/23 | 60〜125分 | L |
| L40.25/E | 欄・record・decodeの契約 | StandardBodies/StandardFactExamples（新） | S24/S25、field_facts_by_type、同じP.VarianceValid | 不変な欄連鎖と構築の全体条件→通常decode後の欄順/全体条件をcoreの検査列で証明→Error payload/順番を保持。生成器の全実装はR40 | 10/20/24 | 35〜70分 | L |
| L40.26/E | Checked系・非空・同長の安全な入口 | StandardBodies（新） | S16/S26〜S30、元List/保持element/長さの関係 | Rangeの3種とNonEmptyList別名のcore署名・本体→同長の別ysへのsafeGet→旧Option/Result/RangeErrorを保持。公開名はU02で確定 | 23/25 | 35〜75分 | L |
| L40.27/E | 依存契約と高階の全位置を照合 | StandardFactExamples（新）・Transport利用 | S31、F02、L30の四種の像、同じ関数/名前/個数 | callback/結果/List内関数/正負data/Reference/Failの受理拒否対照→値引数の同時代入で結果/潜在効果を保つ。旧埋め込みを再証明しない | 11/20/26 | 30〜55分 | L |
| L40.28/E | 標準契約の全行と後段の応答を固定 | StandardContracts/StandardFactExamples（新）・受渡し表 | S01〜36、結果に名指す23モジュール328API、BuiltinArgs/Outcome3枝 | API各行の通常型/追加関係を実δ/core/対象/外部へ照合→明示変換S34・床除算S35・abs等S36の全幅を含め、L50/L60の供給元と未完を固定 | 16〜27 | 30〜55分 | L・W・RV |
| L40.29/F2 | 全幅の正常/Stopの局所意味 | IntervalFailure/StandardScalar（新） | S02/S33/S35/S36、加減乗21/負号4/intDiv-mod14/床除算14/abs7と失敗6形 | 実OperationResult/δから正常とStopへ。符号付き4幅の最小値absoluteのoverflow、floorDivideの最小値÷−1、floorModuloの正常剰余、0除算、shift の count が域外のときの Stop を分離。後続の演算を使わない | 04/16/28 | 40〜85分 | L |
| L40.33/F2 | 正常/returnedの二成分の局所所属 | IntervalFlowLeaves（新） | F07のjoinV/normalF/returnF/seqF/joinFと局所ResultMem規則（return/順次/枝/腕/Block14）、関連値の二系 | 定義の形を実装し左右Mem保存を証明→実return/選択枝/腕/Blockの構成からnormal/returnedを作る読者を閉じる。二系の書換えだけや任意returnedへの所属では不可。全表層はL70 | 31/32 | 40〜85分 | L |
| L40.34/F2 | 最初の失敗の補助証明を本番化 | FirstFailure（新）・IntervalConnection利用 | F07 BeforeError/BeforeErrorSteps/FirstFailureHandoffの完全な現行定義 | 前段のfirst_error/pure_failureを本番へ移し、同じneg反例の受理を保持→最初の位置だけのδ/理由列とsuffixを返す。解析との無条件一致を結論しない | 29/32 | 25〜45分 | L |
| L40.35/F2 | 型付きmarkと正常/return/Stopの受渡し | IntervalFlowLeaves/LeafInputs（新）・ControlLeafSelection利用 | S33、同じσ/Eb/Rのret/escape、FirstFailureHandoff | 33の同じ値の関係をtyped_returned_markと制御7葉へ供給→解析の第一候補/実行の第二候補/全体合成の残りを別々に記録 | 15/33/34 | 30〜55分 | L・W・RV |
| L40.36/G | 全場合・申し送り・義務を照合 | L40の段末資料・本書 | 第2節の全表、第7節64義務、第8節の全受け口 | 本番の定義名と未完の段を一行ずつ照合→56/37/21の抽出集合と差集合4、共通4に漏れ/二重計上なし | A/B/C/D/E/F1/F2 | 20〜35分 | L |
| L40.37/G | 写しと読者・importを照合 | 01-12/07-04、formal/Benitoite.lean、L40の読者一覧 | 現行定義・言明・仮定、既定8対象のimport閉包 | 実際に閉じた葉だけを写しへ反映→旧主定理/未知の失敗例を外さず、工程ID/絶対パス/新しい公理の混入を点検 | 36 | 25〜45分 | L |
| L40.38/G | 段末の検査と独立レビュー資料 | L40のaxioms入力/結果・段末results | 第9節A-L/W、旧主定理＋新葉＋使用定義の全名 | A-Lと最後のworkを一回ずつ実行し、同じworkに正式RSSを付ける→定義/言明/仮定のレビュー依頼資料を渡す。全比較は行わない | 37 | 25〜40分 | A-L・W・RV |
| L40.39/G | レビュー所見へ応答 | 当該本番と写し・results | 独立の所見のrequest/report/response/handlingに従う | 必要箇所だけ修正し古くなった検査を更新→取りまとめが独立再確認。自分の点検を独立可としない | 38/独立RV | 20〜45分 | 影響L/A-L/W |
| L40.40/G | 受け入れ資料と次段の署名を渡す | 段末results・L50/L60/L70受渡し | F01〜07の実署名、64行の段別判定と後段 | 全体閉鎖とL40分を区別し、時間/待ち/未取得と未決を集約→取りまとめのplan転記・設計者受入へ渡す | 39 | 15〜25分 | 文書照合 |

### レビューと取り込みの群

群Aだけは、形が未確定な部品の最初の関門である。B以降へ先回りして同時に書き換えない。各群の内部で短い単位に順に取り組み、共有の定義を別の起動で並行変更しない。

| 群 | 単位 | 完了条件 | 所要時間（能動時間、積上げの情報） |
|---|---|---|---:|
| A 方式と完全署名の確認 | .01〜.05 | F02/F05/F07、23モジュール328API、丸め5モードの写し、S01〜36、安全な入口の内部契約の引数/結果を確定。鍵5代表を現行satB/Rust判定と照合して差はJ40-1へ。公開名/字面はU02 | 3時間5分〜6時間 |
| F1 H04第一候補の早期確認 | .30〜.32 | 04のみを外部依存として109場合とEvalStandard7形からtracked_failure_soundを証明。停止/未対応のbaseUnknownを保ち、J40-2を判定。B〜Eの完了を待たない | 2時間15分〜4時間20分 |
| B 構文の逆転とF3の適用 | .06〜.11 | 16目的（旧14移植＋新2）を本番へ残し、旧31逆転の行き先/N_gを更新。群末の通常記録からplan更新式を適用。LeQ14と依存列4構成子、名前/個数/Fail不変を保持 | 3時間5分〜6時間5分 |
| C 全canonical formsと開始の入力 | .12〜.15 | Val25/Comp16/State4/Frame7/Cell6と既存76葉への供給先がそろう。C_Matchの値・obs=None/someのsort条件・HasTypeArmsQ・Exhaustiveを逆転。意味だけから構文を推測しない | 2時間15分〜4時間25分 |
| D scalarと有限事実の読者 | .16〜.20 | 七整数型/Byte/Character/Float二幅/Decimal、S34明示変換・S35/S36正常部と7measure担当分を実応答へ接続。前提を読むLeQとBoolean実型付けの読者あり | 3時間〜5時間50分 |
| E 全標準契約と具体の鍵/本体 | .21〜.28 | S01〜32/S34〜36の担当部を実δ/coreへ接続し328APIを全行分類。KeyShapeは具体sat/宣言から供給。L50/L60/R40へ残す部分を別記 | 5時間〜10時間5分 |
| F2 正常/return/Stopと実行への接続 | .29/.33〜.35 | 全幅のStop、F07の局所二成分規則/実読者、第二候補の最初の失敗を閉じる。第一候補はF1を引用し、主定理合成をL70へ残す | 2時間15分〜4時間30分 |
| G 照合・検査・レビュー応答・受渡し | .36〜.40 | 64義務/33申し送り/全場合/実署名/写しを照合しA-L/work/独立レビュー処置を完了。設計者の受け入れは設計者が行う | 1時間45分〜3時間10分 |

段の枠は **15〜35時間（中心25）を当面保つ**。個別幅の積上げは **1,360〜2,665分（22時間40分〜44時間25分）** の情報として添え、段の新見込みにはしない。検査実行・独立レビュー・設計者の回答待ちは別、39等の応答の能動時間は内数である。群B末にplanの更新式で改める。

### 最初の同種16件と残りの移植

B群06〜09の16目的は、inv_var/fnRef/prim、inv_op/lam_wf/lam/dependentLam/raise、inv_mapV/setV/bytesV、inv_dict/super/app/let/escapeである。旧から14件を移し、dependentLam と raise は旧に同名の補題がない新2目的として記録する。旧 `Release/Lemmas/Inversion.lean` の inv_を名前に持つ31定理を [結果の行き先の表](results.md#旧31逆転定理の行き先と同種の残件)へ一行ずつ分けた（ファイル内の全34定理から補助3を除く）。01で差を照合する。

同種の未処理件数 N_g は、群Bで移す旧14件の完了後は10件（loc、match、lazy、use、handle、resumeL、resumeVar、meth、builderLet、builderOp）の供給側の残件とする。inv_loc等の既済み部分を再証明せず、新判断から葉の入力を得る残りだけを数える。既済み7件はN_gへ入れない。10件を閉じたらN_g=0。新2目的、11の一般適用、canonical forms/セル接続、H04/標準本体にはこの移植単価を掛けない。元の31行の差と件数は通常の結果へ残す。

群Bの通常記録を値逆転Vと計算逆転Cに分ける。旧移植のn_V=11/n_C=3、残件N_V=1（loc）/N_C=9。外側E_gと待ちW_gを分離できる群だけA_g=E_g−W_g、c_g=A_g/n_g、残りΣ(N_g×c_g)へ使う。新2目的は除く。分離不能ならc_g未取得として旧見込みを保ち、測定専用の作業は置かない。`eq_of_not_fn` は旧 `formal/Benitoite/Core/Lemmas/Basic.lean` の補題であり、全子の等号へ戻す用途はF3のTelClosure/TypeArgsLeに置き換える。


## 6. 実行の全76葉と H04 の帰納の場合

実行の全76葉は、[結果の開始入力の表](results.md#既存76葉への開始入力の供給)に各 Step 名と単位を一行ずつ対応させた。継承69＋追加7、Step を返す60＋到達型だけ16という控除を保つ。開始の Comp16形と C_Match の腕/網羅性/obs の入力は12/15/20が供給する。

独立評価は [結果の109場合の表](results.md#h04-の109場合)に全構成子を列挙した。EvalPartial69（標準等23＋算術22＋制御24）、引数4＋4、腕6×3、Block14で109。別母集団のEvalStandard7は足さない。30/31で同じ相互の動機を共有し、32でanalyzeへ上げる。これらの外部依存は04のみ、具体δとStopの接続29は16/28の後に残す。

現行 BudgetAnalyze.Report.sharedFlow の returned は呼出し側の引数である。33/35が供給するのはF07の局所規則と読者であり、全表層・各本体の実解析出力から returned 成分を作る全接続はL70/R10b/R50へ残す。

## 7. 義務の一行ずつの対応

母集団は、planで担当にL40を含む56行（P）、L20段末の「残る段」欄にL40を含む37行（20）、L30段末の同欄にL40を含む21行（30）である。三集合の和は60行であり、planとの差集合は **O006/O015/O050/O054の4行**。共通の O016/O027/O084/O118 を加えた照合対象は64行となる。表の出どころ欄はこの抽出に厳密に対応し、本文の一般的なL40の言及だけを義務行へ数えない。

「技術」はL40の規則/葉/実読者を実装する行、「継承」は既済みの証拠を引用して差し引く行、「他段」は新規の証明が別段に属する行、「運用」は時間等の記録、「共通」は段ごとの監査/レビュー等である。ここに書く判定は今後の完了条件であり、今回閉じた義務を表さない。各群のresultsへ本番定義名・当該段の判定・残る段・確認日/レビュー担当を追記する。証拠の保存先は `l40/<群の小文字>/results.md` と段末 `l40/results.md` の計画であり、本下書きでこれらの実装記録を新設していない。

| 義務 | 出どころ | 分類 | L40単位 | L40担当分の完了条件と既済み証拠 | L40後に残る段・境界 |
|---|---|---|---|---|---|
| O001 | P | 継承 | 36 | C02の構文List/Fn/Reference逆転とnames_eqを引用。既存定理の新規証明なし | L40の新規担当なし。段別の引用確認後に取りまとめが全体判定 |
| O005 | P/20 | 技術 | 10/27 | 検証済み変性とfield_orderを標準欄へ利用。意味移送の再証明なし | L70/R10bの辞書・公開境界の全収集、R50/V10 |
| O006 | 20 | 継承 | 27/36 | 型/行/範囲/値の交換とclose_value_typedはL20で済み。利用だけ | L70の合成 |
| O007 | P/20 | 技術 | 14/15 | 参照内容とFailの正規形等号を実セル/開始逆転へ渡す | L70の全合成 |
| O008 | P/20 | 技術 | 15 | 元のClosureTy/CaptureOkから任意開始の入力を供給。環境を捨てる反例を保持 | L70の主定理 |
| O011 | P/20 | 技術 | 16/17/19/28 | 全幅/Byte/Decimalの値域を実正常δへ接続。既存決定の変更と記す | L40分の段末レビュー。定義のL10は継承 |
| O015 | 30 | 技術 | 13/16〜28 | L30からの全16sortの観測を標準葉へ供給。B08のq→qを強めない | L50の全σ/所属・具体化 |
| O021 | P/30 | 運用 | 05/09/40 | 段の枠15〜35時間と個別幅の積上げ、正常/Stop/写しと未経験群を名指し | 取りまとめの全体見込み更新。R20の実装の所要 |
| O022 | P/30 | 技術 | 16〜25/28 | 本番の三条件から全sort・型付き鍵・欄/標準葉を供給 | L50の全σ/対象、L60のモデル |
| O030 | P | 技術 | 12〜15/28 | 全構文/入れ子/δ結果を型付き導出から逆転しfactsへ。最外アダプタに限らない | L70の合成 |
| O032 | P/20 | 継承 | 36 | C03/C12の正規形と値代入の交換を引用。等号保存の新帰納なし | 新規担当なし。利用先は14/27 |
| O033 | P/20 | 技術 | 10/25 | 標準dataの全欄/正負/述語と既存VarianceValidの利用を照合 | L70/R10bの元の辞書/opaque公開境界の収集、R50 |
| O034 | P/30 | 技術 | 16〜25/28 | 7measure・全sort・実正常δ・有限鍵の三条件を本番から供給 | L50/L60の実表、R50 |
| O035 | P/20 | 技術 | 13/28 | 既存のgroundVal/reqTarget/valContentの逆転を関数/節の入力へ渡す | L50の全δ/拡大/対象/存在、L60のモデル |
| O038 | P/20 | 技術 | 14/15/28/35 | 全76葉へ開始の型・値/セルと応答入力を供給。既存保存葉は継承 | L50/L60の応答、L70の全保存 |
| O039 | P/20 | 継承 | 36 | C10/C11の意味・捕捉のfactsの構成を引用。全値の意味の独立仮定0 | L70の合成 |
| O043 | P/30 | 技術 | 20/27/28 | 既存checked_refinementへ前提を読む契約/全四像の本番読者を接続 | L70の合成 |
| O046 | P/20/30 | 技術 | 16〜21/28 | 実比較/算術/length/δの閉じた述語を一般の枝の型付けへ供給 | L70の全合成 |
| O047 | P | 継承 | 36 | C05のLeQ.assume/subtype_factsを引用。新しい意味Γなし | L40の新規担当なし。全canonicalの利用は12〜15 |
| O048 | P | 技術 | 13/28 | 同じ要求の所属単調性と射影を標準の受渡しへ利用 | L50の全被覆/endpoint/IO |
| O050 | 20/30 | 技術 | 22/25/27 | 既存の観測交換と限定合同を鍵/標準欄の葉へ使用 | L40分の段末レビュー。全相互置換の再実装なし |
| O051 | P/20 | 継承 | 36 | C12/C13の捕捉Φ/StoreOk/継続の一般保存を引用 | L70の合成。開始逆転は15の既存担当 |
| O054 | 30 | 技術 | 20 | L30単独の有限論理は継承。標準比較/B04から実型付けへ渡す追加の読者 | L70/R10bのソース構成。planの元のL30担当を改変しない |
| O057 | P | 技術 | 12〜15 | 空篩の排除、値/セル/実引数のcanonical formsを全開始へ供給 | L50/L60の存在、L70がprogress閉鎖 |
| O058 | P/20 | 技術 | 11/15/28/35 | 反変実引数・正常応答・同じR/σ/Ebの葉を供給 | L50/L60、L70がpreservation閉鎖 |
| O059 | P | 技術 | 15/28 | 既存selectOracle/selectRelease/selectFreshの入力をcanonicalから供給 | L50/L60の応答、L70がstep_sound閉鎖 |
| O060 | P | 技術 | 07/15/20 | Fail不変・注釈の名前/効果・空行guardの操作排除の局所葉 | L50/L60の対象、L70がeffect_soundness/noLamNames閉鎖 |
| O062 | P | 技術 | 16〜29 | 具体δと依存入力のret[ws]、正常結果の篩・Ground/Adequateを照合 | L50の範囲、L60の外部/三モデル |
| O064 | P | 他段 | 28/40 | 一般のrelease応答選択はC14。通常資源の実表の存在の充足はL60が正しい | L60。externalを01-10の資源に追加しない |
| O065 | P/20 | 技術 | 11/27/28 | C12のsig_scoped等を継承し標準の具体署名/型・行・範囲・値の形成に使用 | L60の実表全欄。全面的な旧仮定同値は要求しない |
| O069 | P | 技術 | 10/11/27 | F3の全位置と一原子被覆/構造包含/不変位置を受理拒否へ対応 | R10b/R60/D10の実装・表示 |
| O070 | P | 技術 | 10/13/27 | F3/組込み変性/data/U1/範囲を別の変更として照合 | R10b/D10/V10の独立期待・互換登録 |
| O080 | P | 技術 | 23〜26 | 標準本体・Checkedの元値/element・NonEmpty別名と旧Range Errorを保持 | R40/D10の実標準本体と公開文書 |
| O090 | P/20 | 運用 | 29〜35/40 | G07の既済みとH04の未完を分け二重加算なし。待ちと能動時間を区別 | L70/R10b/R50 |
| O091 | P | 技術 | 29〜35 | 全幅のnormal/returned局所所属、failed第一候補/最初の実失敗を区別 | L70の実出力/本体所有、R50/K10の親・独立・別本体/欠落拒否 |
| O114 | P | 技術 | 10/11/27 | 適格な旧導出は継承しF3/共変の新受理と名前/E/Fail不変の拒否を対照 | R10b/R50/V10 |
| O124 | P/20 | 技術 | 16/17/19/29 | S34の七整数型/Byte/Decimal明示変換のSome/None/同値・端点、S35床除算とS36最小値absの正常/Stopを同じδへ接続 | R10a/R10b/R40/R50/V10 |
| O125 | P/20 | 技術 | 17/21 | Byte0/255/域外、bytes要素と明示導入/演算の表現可能性 | R10b/R40/R50/V10 |
| O126 | P/20 | 技術 | 17 | Characterのscalar値域・code・比較の実葉 | R10b/R40/R50/V10 |
| O127 | P/20/30 | 技術 | 17/21 | charactersInの有限区間と型付きString/標準の導入を接続 | R10b/R40/R50/V10。一般regex/前方一致なし |
| O128 | P/20 | 技術 | 18 | 二幅の所属/特殊値・12分類/12比較。実数線形化なし | R10b/R40/R50/V10 |
| O129 | P/20 | 技術 | 19 | 仮数/scaleと実丸めの正常/表現外/再検査の葉 | R10b/R40/R50/V10 |
| O130 | P/20/30 | 技術 | 21 | byteLength/characterCountの異なる正常値・二長の受渡し | R10b/R40/R50/V10 |
| O131 | P/20/30 | 技術 | 21/23 | 構築/map/reverse/append/filterの正常時の長さと実本体 | R10b/R40/R50/V10 |
| O132 | P/20/30 | 技術 | 17/21 | Bytesの数学上の非負長とbyte範囲を別に接続 | R10b/R40/R50/V10 |
| O133 | P/20/30 | 技術 | 08/22/24 | 型付き鍵から構造、Map縮約後size・鍵不変/値共変・実本体 | R10b/R40/R50/V10 |
| O134 | P/20/30 | 技術 | 08/22/24 | 型付き鍵から構造、Set縮約後size・不変・実本体 | R10b/R40/R50/V10 |
| O135 | P/20/30 | 技術 | 10/25 | 同じPの宣言・不変欄連鎖・全体条件とdecodeの順 | R10b/R40/R50/V10 |
| O136 | P/20/30 | 技術 | 11/20/27 | 値依存端点・後続の渡し先文脈・結果/効果代入と線形関係 | L70、R10b/R20/R50/V10 |
| O137 | P/30 | 技術 | 16/29〜35 | 正常算術結果/表現可能性と中間Stopの所属を別に閉じる | R20/R10b/R40/R50/V10 |
| O138 | P/20/30 | 技術 | 12/20/23 | Boolean/非空/構成子の有限factsを実際の枝に供給 | L70/R10bのソース合成、R50/V10 |
| O139 | P/20 | 技術 | 06/07/11/27 | 名前付き/ラムダの自身の契約と依存引数/結果/効果の逆転 | L70、R10b/R50/V10 |
| O140 | P/20 | 技術 | 10/11/27 | callback/結果中/List内のF3、名前/個数と不変位置の対照 | L70、R10b/R40/R50/V10 |
| O141 | P | 技術 | 13/28 | U1の同じ保持対象/要求の値所属を供給。拡大前のIO添字を保持 | L50/L70、R10b/R30/R50/R60/V10 |
| O142 | P | 技術 | 26 | nonemptyType別名とsafeHeadの通常本体でTを得る | L70、R10b/R40/R50/V10 |
| O143 | P/20/30 | 技術 | 26 | 元List/elementを保ち、同長の別Listの安全な参照は別証明 | L70、R10b/R40/R50/V10 |
| O144 | P/20/30 | 技術 | 16〜28 | 案Iの全sort/measure/標準葉。平坦化/true/空篩を継承 | L50対象、R20/R10b/R40/R50/V10 |
| O160 | P/20 | 運用 | 06〜09/40 | 最初の16目的を本番へ残し通常記録で同種残件のみ更新 | 取りまとめの更新。比の一律適用/測定専用作業なし |
| O167 | P/20/30 | 技術 | 10/18/22/27/36 | 不変/非観測/unknown/非線形/measure境界を受理拒否の対照へ | L70/各R段/V10。構文の比較連鎖/区間略記はL70/R60 |
| O169 | P/20 | 技術 | 29〜35 | 独立評価と算術/δ/normal/returned、failed第一候補を証明し第二候補を本番化 | L70の親実行分解/表層/全合成、R10b/R50 |
| O016 | 全L共通 | 共通 | 38/39 | 旧主定理と新しい葉・使用定義/private・生成宣言までA-L。許可三公理のみ、独立レビューの処置を確認 | L70の全合成とRust開始条件 |
| O027 | 全L共通 | 共通 | 38/40 | -M12288、コマンド/本体終了/外側時間を記録し同じ段末workへ取りまとめが正式RSSを付ける | 各L/R段の限定採取。L20/L30の古い未採取表示を埋め直さない |
| O084 | 全L共通 | 共通 | 36〜40 | 篩/σ/external、証明/実装/比較/受け入れを区別し定義・言明・仮定の個別レビュー | 全L/R/K/Vの受け入れ。L70の合成レビュー |
| O118 | 全L共通 | 共通 | 37/39 | 現行仕様の根拠へコメント/写しを合わせ、工程ID・手元の絶対パスを追加しない | L70/R50/R60/D10/V10の全読者 |

集計は継承6行、技術50行、運用3行、他段1行、共通4行、計64行である。planの56行だけでは技術47・継承5・他段1・運用3。追加4行は技術3・継承1。全体の義務を今回閉鎖した行は0である。

O005/O033の宣言収集、O057〜O060の主定理、O064の実資源表の充足、O091/O169の全表層/交換をL40の完了へ繰り上げない。L20/L30が「担当分完了」とした証拠をそのまま全体の閉鎖へ書き換えない。提供範囲O124〜O144の各行は、L40のLeanの葉、各R段の型付け/本体、R50の交換、V10の実CLIの判定を保つ。

## 8. 申し送りの受け口

表の一行は出どころの照合単位である。同じ内容が別のレビューや段末に現れても出どころを消さず、実装は同じ単位を参照して一度だけ行う。[L30 の63行の処分表](../l30/l/review-handoffs.md)の「済」はL30の処置の完了であり、表中に残るL40の標準葉まで済んだとは読まない。L20/L30の段末の義務行は第7節へ一行ずつ対応済みである。

| 出どころ・項目 | 受け方 | 単位 | 完了の判定／後段 |
|---|---|---|---|
| L00b.15 H01：全canonical/開始逆転 | 今回 | 06〜15 | C02/C04を控除し、全Val25/Comp16と全76葉の開始入力がそろう |
| L00b.15 H02：data変性と初期領域 | 今回 | 10/12/25/27 | 定義/意味移送は継承。Month/空型/非空の利用葉、標準欄の同じPを確認。ソース収集はL70 |
| L00b.15 H03：実比較/δ/枝 | 今回 | 16〜28 | 実応答から有限事実・実型付けへ。L30の論理帰納は再実装しない |
| L00b.15 H04・L20 N：failed第一候補 | 今回 | 04/29〜32 | 同じParametersのままtracked_failure_soundを証明。候補を弱める必要なら停止 |
| L20 N H04：最初の失敗の第二候補 | 今回 | 34 | first_error/pure_failureを現行署名で本番へ移し、OldH04の反例を保持 |
| L20 N H04：normal/returnedの関係 | 今回 | 33/35 | 強いValueRelから同じ値の所属へ。関係を近似の等号へ戻さない |
| L20 N H04：other Result、親の分解、腕の束縛数 | 他段 | 40 | L70の実行→独立評価/表層の合成へ。型付き値の局所葉と分けて渡す |
| L20 L：捕捉の読まれる位置とδの場所番号 | 継承 | 15/28 | LocalStateInvariant/CaptureReadBoundaryの限定を保持。全位置の不変量や精密な外部状態を追加しない。Rustとの差はR段 |
| RV-L00b.11 中1/中2：BuiltinArgs正規化/CellOk | 継承 | 14/28 | planで既に処置済みのBuiltinArgs.normalized、正規化したδ入力、valセルのa.normを使う |
| RV-L00b.13 軽1：ret状態からの値 | 今回 | 15/35 | StateTyEと元ClosureTyからret_valueへ進み、別に仮定した値型の再掲で終えない |
| RV-L00b.13 軽2：全幅/Byteのfacts | 今回 | 16/17 | integer_factsだけに限らず各tagのinv_const/factsと実応答を利用 |
| RV-L00b.13 軽3：List要素のfacts | 継承 | 12/23 | 既存list_element_facts/field_facts_by_typeを使う。導入の新補題を二重作成しない |
| RV-L00b.13 軽7：atError | 今回 | 12/13/25 | ResultShapeと7欄を専用に扱いinv_conから漏らさない |
| RV-L00b.14d：Lazyのthunk/done | 今回 | 14 | canonical_lazyとStoreOkから二セルの形・内容型を返す |
| RV-L00b.15 軽6：空効果head guardの操作排除 | 今回 | 15/20 | 頭の実操作の必要効果を逆転し空行の被覆に矛盾。到達全体の効果健全性はL70 |
| RV-L10.a 軽1：整数値とtoIntの一致 | 今回 | 16/29/33 | const_integer_same_value/ValueRel.toApprox_eqを使い、constOK_toApproxを数値同一性の証明と読み替えない |
| RV-L10.v：sort反映とVarianceValid | 今回 | 10/12/25 | 同じP.VarianceValidを本番から供給。任意のmetadata表を信頼しない |
| L30処分表 RV-L00b.04：鍵の言語上の等値 | 今回 | 03/22/24 | 具体のsat/宣言からKeyShape/ClosedSlotsを供給し、既存Key.equalと結ぶ |
| 同 RV-L00b.14b/paths：apart | 今回 | 20 | B04→false_sideを実際のHasTypeCQ/ClosureTyの枝へ通す |
| 同 RV-L00b.14d：forceの共変/格納/観測 | 今回 | 11/14/27/28 | Lazyの結果共変を実標準契約で利用。別タスク待機/取消の比較はL70/R30/R50 |
| 同 RV-L00b.14e/15：節/resume/used/解放 | 今回 | 07/11/14/28 | 元の実引数/依存結果/効果と既存状態葉へ接続。実表全欄はL60、Rust解放はR30/R50 |
| 同 L20 I/J/N：O046/O079/O138/O143 | 今回 | 20/23/26 | 長さ/Booleanを標準facts/安全な実入口へ通す。O079の静的scrutinee強化はL70/R10b |
| L30 H情報1/2：開いた型域と算術の像 | 今回 | 20/27 | Ctx.factsの型域の真を既存capture/Transportから供給。独立の意味仮定を足さない |
| L30 H情報3：Character/Floatの芯の事実 | 今回 | 17/18 | 空のcarrierFactsを勝手に増やさずChar/bitsの有限規則から供給 |
| RV-L30.j 軽3（処分表J軽3） | 今回 | 03/22 | satB成功とKeyShapeの並置から、型付き実値の橋へ進む。L30分は転記と記す |
| RV-L30.j 軽4：ByteとUInt16 | 今回 | 17 | 同じ数の表現可能性と実変換の証明を区別。架空の変換APIなし |
| RV-L30.j 情報2：前提を読む長さLeQ | 今回 | 20/27 | p::assumptionsの順を実証明書が使用する。四種の像で同じLeQを移送 |
| RV-L30.j 情報3：Booleanから枝の型付け | 今回 | 20 | Entailsだけで終えず、Notを実際に使用するbodyの型付けへ供給 |
| L30 J/K：実δ/解決済み署名/標準本体 | 今回 | 05/16〜28 | S01〜36を実定義へ結ぶ。型保存だけからδの算術一致を推測しない |
| L30処分表 RV-L00b.14c：Reference.updateの名前 | 他段 | 40 | L70/R10b/R50のlambda受理/契約名の比較。未再現の不一致は断定しない |
| 同 RV-L00b.13：篩付きPairのRequest/At | 他段 | 40 | L50/R30/R50の型付き要求と実行一致。既存groundTy修正を継承 |
| 同 RV-L00b.15：短絡の脱糖 | 他段 | 40 | L70/R10b。同じ型/効果へ接続しCompに短絡構文を追加しない |
| 同 RV-L00b.05軽3/D情報2：非計算的checkInと交換 | 他段 | 40 | R50が有限交換表と上層の証明を照合。raw再生だけで全表比較済みにしない |

33行＝今回25・継承3・他段5である。同じ実装を参照する出どころの重複を課題数へ足さない。L30の11転記行のうちL40が現れる6行（鍵、Lazy、節、J軽3、J情報2、J情報3）は上表で全て受ける。L30処分表の「済」の行にL40を残すapart/L20群の標準葉も別に受けた。

## 9. 定義の固定・検査・後段への受渡し

### 既存定義を変える必要と波及

本案は既存のTy/LeQ/TelLe/Typing/CaptureOk/StoreOk/ValueMeaningの定義変更を要求しない。新しい逆転と本番の読者を上層へ追加する。現在のまま証明できないと分かった場合は、次の波及表と反例/未証明箇所を添えて止める。形成・局所の補題の前提を主定理の新しい信頼条件として追加しない。

| 変更候補 | 波及する母集団 | 採る順序 |
|---|---|---|
| LeQ/TelLeの構成子/引数 | LeQ14＋TelLe2＋TelClosure2＋TypeArgsLe4、全移送と既存逆転/意味移送 | 02の1引数/推移の方式を先に確認。相互帰納の定義を後から改める案は取りまとめへ戻す |
| 型付けの新しい引数/前提 | 値29＋列2＋Each2＋計算24と残る相互族、主要十移送の14判断76場合 | 本案の変更0。必要なら全L停止条件を適用し、定義を先に変更して後段へ負担を送らない |
| CaptureOk/ValueMeaningの条件 | 型付き意味の33場合、捕捉の全構成、L30 H/Iで照合した16主要読者 | J30-2のような切替を再度起こさない。必要なら全読者数を再採取し根拠と所要を提示 |
| 標準表の新しい具体δ/core本体 | S01〜36、全API分類、型付き入力/正常/err、L60実表/R40本体/R50交換 | 05で完全署名と具体の実定義を先に固定して独立レビュー。主定理の仮定への欄追加は別判断 |
| Intervalの解析の補助命題 | 独立評価7判断109場合＋EvalStandard7、既存Normal/WarningSoundness | 04で失敗の骨格を固定し30/31で同じ相互言明を一度閉じる。旧解析の上限を篩のproof-stepsへ統合しない |

### 検査の具体的な割当

次表は実装時の計画であり、この詳細化中に通した結果ではない。B_WORKは各起動依頼で取りまとめが渡す直前の取り込みの完全IDへ更新する。最初の群の基準は本書冒頭の値である。単独Leanは途中の確認であり既定全ビルドの代わりにはしない。

| 検査・担当 | 内容とコマンド | 時期・保存先・待ちの見込み |
|---|---|---|
| L：実装担当 | `formal/`から `lake env lean -M 12288 Benitoite/Release/Refinement/<対象>.lean`。型検査の対象だけでなく実際に新前提を使う読者を検査 | 各単位の途中。単位/群のresultsへ終了と外側時間。過去の短い単独検査は約1秒前後だが新帰納は未測定 |
| Wの選択確認：実装担当 | `scripts/check.sh --level work --base B_WORK --dry-run`。Leanと写しの読者を選ぶ。onlyは既定で足さない | 各群の最後の実装状態について確認。分類不能3/誤指定2は共通依頼文どおり |
| W：実装担当 | `scripts/check.sh --level work --base B_WORK`。既定全Lean/sorry拒否。01-12のtext例を変えれば仕様例/集計。構文を変えた場合は生成Skill等の読者も同じ入口へ | 群末に一度。L30の最後の正式workは159秒。8群なら約22分を初期の待ちの目安とし、別のclean一式を重ねない |
| A-L：実装担当、取りまとめがレビュー | 段のaxioms入力から全既定importの旧主定理・新葉・使用定義の完全名を `#print axioms`。private・生成宣言も一覧に含め、`lake env lean -M 12288 <監査入力>`。許可はpropext/Quot.sound/Classical.choiceだけ | 38の段末。L30の全監査は約38秒、計画の1〜5分案を待ちへ残す。生出力のbytes/SHA-256/対象名と一覧を保存 |
| RSS：取りまとめ | 38の同じ最後のworkへmacOS `/usr/bin/time -l` 又はLinux `/usr/bin/time -v` を付け、本体と計測器の終了・機械/OS/原単位を別記 | 段末だけ。他は「未取得（計画上の非採取）」。追加buildを作らない |
| 定義・言明・仮定の独立レビュー：取りまとめ | 群Aの方式・各群の契約/新前提/全場合、段末は全受渡しと公理依存。39で所見へ応答し影響した検査を更新 | 各群/段末。独立レビュー/設計者待ちは不明。自己点検を独立レビュー可にしない |
| 仕様例と禁止構文/リンク：実装担当 | 写しは現在の実定義だけを記す。新しい本番コメントの工程ID/絶対パス・sorry/独自公理を点検 | 37/39。テストを追加/変更する場合はtest-auditを読み、所有する境界・必要性を記録 |
| 全比較・Rust/CLI | L40では実行しない。L70のF-REG、R50のF-CONN、V10の実CLIに各担当の証拠を渡す | 既存約40分/最大約14GiBは全比較の旧目安であり、L40の単独Leanの待ちへ加えない |

### L50/L60/L70へ渡す署名

| 受け手 | L40が供給する実署名/証拠 | 受け手に残ること |
|---|---|---|
| L50 | F01/F02の構文逆転と実引数移送、F03の保持値/AtError/場所、F04の同じ正常値のfacts、既存HeldValues/ModelHttpの同じ要求 | 全有効σ、PathBases/At、FileのreadTextIn/readBytesIn/writeTextIn/writeBytesIn/appendTextIn/appendBytesInとHttp.sendIn、shapeAt/TargetAgreement/io_exists |
| L60 | F01のexternalRef/Handleと型/行/引数の証拠、F02、F04の正常応答、F05の実標準鍵表、F06の具体δ/core本体と署名分類 | external_typed/exists/no_targets、borrow/own/State、通常資源との区別、Model/ModelHttp/ModelTargets全欄。通常資源release_existsの具体充足 |
| L70 | F01〜03の全開始入力、全76葉の対応、F04〜06の全標準契約、F07のtracked_failure_sound/FirstFailureHandoff/二成分の局所所属 | PresMain/Progress/Theorems、主定理/効果/対象/表層/消去/全交換、実解析のreturned供給、親実行分解、other Result/束縛数、U02/U05の公開確定 |

署名は「L50向けだから既存の同名の旧Ty.Leへ戻す」形にしない。全て同じRefinementの型・行・値・固定σを使う。後段の量化を全Top/空Γ/空Storeへ縮めない。

## 10. 分岐する判断と停止条件

| 項目 | 現在の扱い・推す進め方 | 判断が必要になる条件・実用への影響 |
|---|---|---|
| J40-1：具体の鍵表/標準δ/core本体の供給 | 03/05で同じ宣言/本番の実定義から証明する。抽象BのCoreAssumptionsへ新欄を足さない。完全署名の固定は取りまとめと独立レビュー | 供給を証明できず、型付き鍵や標準関数の受理を狭める、対象dataを除く、意味の健全性を仮定する案が必要なら設計者へ。Map/Setや高階/再帰dataを使う通常スクリプトへ影響するので無断で選ばない |
| J40-2：H04の第一候補/実行との合成 | 第一候補は未証明のまま量化を固定。第二候補は現行の最初の失敗の位置だけを結論する。04で形を確かめ、F1の30〜32をB〜Eより先に閉じる | 第一候補に反例、又はδと算術の無条件一致が必要なら定義・反例・代案を示して停止。失敗の所属を正常の定理で代用しない。error/exitが消える保証は追加しない |
| J40-3：公開の安全な入口・NonEmptyList | 05末にどの証拠を受け何を返すかという内部契約の引数/結果を確定し結果へ記録。公開名と字面はU02、表示はL70/R40へ | 新しい公開APIの選択は設計者の判断。旧Option/Resultを削る、Checkedの元List/elementを捨てる案は採らない。NonEmptyの名目性/表示差は既承認の互換差として残す |
| J40-4：枠と積上げの区別 | plan先頭の判断に従い段の枠15〜35時間（中心25）を当面保つ。積上げは情報 | 群Bの16目的の通常記録と同種N_gをplan更新式へ入れて改める。能動/待ちを分離できなければ旧見込みを保つ。範囲を減らして数字を合わせない |

現時点で、新しいLean公理、主な定理の量化/結論の変更、提供範囲の削減、利用者の書ける形の縮小、精密な外部状態の新設を提案する項目はない。上のJ40-1/2は、そのいずれかが必要と分かったときの分岐であり、変更の事前承認ではない。J40-3は設計者の見直し対象であり、05の確定形を既存U02の判断時に示す。J40-4は当面の枠の維持が取りまとめにより決定済みで、群B後の更新と相談を残す。

各単位の最初の1時間で、骨格/供給元/未証明箇所と残りを見直す。単位の上端の2倍を超えたら原因を調べ、既定ビルドと関係検査が通る区切りで止め、済んだ範囲・残り・所要時間（能動時間）と待ちを返す。未承認の前提/結論変更、公理の追加、精密な外部状態、旧除外からの未知の不一致は区切りを待たず停止する。D71の篩/σ/externalの小さい組合せで原因を分け、公開範囲の自動延期へ変えない。

## 11. 見込みの根拠と取りまとめへの転記

### 所要時間（能動時間）と実績の使い方

段の所要時間（能動時間）は15〜35時間、中心25時間を当面保つ（plan先頭のJ40-4）。40単位の個別幅の積上げは1,360〜2,665分（22時間40分〜44時間25分、中心33.542時間）で、段の新見込みではない。r0の積上げは結果に旧情報として残す。

| 重い単位 | 個別の幅と根拠 |
|---|---|
| 05 | 60〜110分。36契約行・328 API分類、具体δ/coreの署名、安全な入口の内部契約。列挙は本書で済み、未確認の方式に幅を置く |
| 11 | 50〜110分。TelLe/TelClosure全4構成子と反変/依存結果/効果の3結論。02の型検査だけでは一般帰納を保証しない |
| 15 | 50〜100分。Comp16/State4と76葉の供給。matchのobs/腕/網羅性、捕捉の元コードとの関係を含む |
| 16 | 55〜105分。七幅の算術25/比較42、明示変換20 API、床除算・abs・bitwise/shiftの同族の正常部。個別δの証明を共有する |
| 24 | 60〜125分。S17〜23の7行、Map/Setのmap/filter4本。List側の2本を利用するが、縮約と同鍵保持の別証明を含む |
| 04と31 | 04は5経路の骨格確認25〜50分、31は制御24/腕18/Block14の同じ相互帰納60〜110分。代表確認と全帰納を分ける |

群Bの通常結果を更新の区切りにし、planの式「未処理の中心と同種の更新済み見込み＋Σ(N_g×c_g)＋まだ実績のない追随群の旧見込み＋その他の旧見込み/余裕」を使う。N_gの定義は第5節と結果の旧31表に置く。能動時間が分離不能ならc_g未取得とし段の旧見込みを保つ。更新だけで停止せず、形の不一致/未承認変更/時間超過は既定の停止条件へ従う。

| 実績 | 読んだ根拠 | 本案への使い方 |
|---|---|---|
| L20 | effort-ledgerの全群とplanの2026-11-03の記録。詳細化97時間45分〜219時間45分、担当の外側約20時間。旧値19規則は計30分30秒でV_Fun/V_Primの二枝が約72%。Q/Rの27規則は共通枠で個別加算不能 | 共通の形成/逆転の準備に時間が寄るので06〜11を同じ群に配置。外側約20時間は能動時間の上限の情報とし、H04/鍵/通常標準本体へ比を掛けない |
| L30 | effort-ledgerの計画/群A〜N/再開。詳細化の最終47時間5分〜91時間55分、担当の外側は計画を含め約7時間30分、レビュー計約2時間。段末表のA〜Kの担当約5時間4分 | finiteな部品の利用は差し引く。型域の切替・重い帰納・具体表の新設が同じ単価になる保証はない。能動時間と待ち未分離。外側約7時間30分は担当の能動時間の上限の情報であり、その値を能動時間へ代入しない |
| L40最初の16目的 | 06〜09の通常resultsで取得予定。専用測定なし | EとWを分離できる場合だけA=E−W、一件当たりA/nを同種の未移植分へ使う。N_V=1/N_C=9の同種未処理分だけを更新し、H04/標準本体/レビューの旧幅を保つ |

中心値は各単位の上下端の中点の和である。全109場合や76葉に一律の単価を掛け直さない。

### 転記・レビュー・受け入れまで

| 残る手順 | 検査・測定・レビュー・受け入れの内容 | 所要の見込み |
|---|---|---:|
| L20/L30段末の受け入れ | README 2026-11-03でJ30-2/steps規範を含め受け入れ済み | 完了 |
| この下書きの独立レビュー | 40単位/全署名/56義務＋段末差集合/申し送りと時間の妥当性を確認 | 不明 |
| 取りまとめのplanへの転記 | L40行/義務の段別条件/見込み/後段署名へ反映。段の枠15〜35時間の維持、群B後の更新式を反映 | 不明 |
| 群Aの起動・方式のレビュー | 署名/具体表/失敗成分の骨格を先に固定し、依存群を起動できるか判定 | 積上げ 3時間5分〜6時間＋検査/独立レビュー待ち |
| F1/B〜E/F2/Gの実装・検査・群レビュー応答 | 本書の全単位。workは既定Lean・仕様例等の読者、段末A-Lと同じworkのRSS。測定専用の作業なし | 積上げ 19時間35分〜38時間25分（段の枠は15〜35時間）。8群のwork待ち約22分、A-L1〜5分を初期目安。独立レビュー待ちは不明 |
| L40段末の設計者の受け入れ | L40担当分と残るL50/L60/L70/R段を確認 | 不明 |

planへの転記と起動の判断は取りまとめが行う。
