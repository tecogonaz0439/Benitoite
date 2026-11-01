# L10-plan: 再レビュー所見の処置結果

2026-11-01。[RV-L10-plan](../reviews/RV-L10-plan.md)の「再レビュー」と末尾の「取りまとめの追記（再レビューの処置）」、planの最新の先頭行を読み、[detail.md](detail.md)を更新した。前回の重1・重2は解消との判定を引き継ぎ、今回の再中1〜5・軽6〜9の九件を処置した。実装・本番の証明・起動・受入の完了記録ではない。

指定ブランチは `m014/l10-plan`、B_WORKは `b63a091da90626d13f4d079580728d8d8d3cde49` である。gitの操作は行わず、リポジトリで書いたのはdetail.mdと本ファイルだけである。formalの本番ソース・処理系・設計書・plan・レビュー原本・rv-l10の入力は編集していない。Qの補題の形だけを許可された一時のLean入力で確認した。

## 集計と担当

| 項目 | 今回の結果 |
|---|---|
| 起動単位 | **L10.01〜L10.59の59単位**。各所要時間（能動時間）0.5〜1時間、基本枠は **29.5〜59時間** |
| 本体 | TODO-294の一単位を除く58単位、**29〜58時間**。修正の余裕0〜3を含む見込みの提案は **29〜61時間** |
| 相乗り | TODO-294はL10.57の0.5〜1時間を相乗り6〜12時間から一度計上。残5.5〜11時間。本体へ重ねない |
| 単位の増減 | 旧.05/.13/.14をそれぞれ三単位へ、旧.27を二単位へ分割。WellFormed一単位、中間判断の入力二単位を追加。49+2+2+2+1+1+2=59 |
| 規則 | Variance/Polarityを三値にし、非出現引数は不変。既存17+data1+TypeArgsLe4=**22規則**。型付け相互14判断76規則の四本304枝の照合は変わらない |
| 網羅性 | Inhabits三族28規則、PatTy二族10規則。B/Γ/Φを増やさず、Exhaustiveはa.normを入口にする。意味の不変量を別に定義 |
| foundation | **158=既済16+不要43+L10残99**。不要のうち12件の読者の代替をL20/L70へ名指し。別に旧Legacyの二読者も記録 |
| 最初の同種群 | g=19、最初17=.33の3+.34の5+.35の6+.36の3。A_17は四単位の通常resultsから読み、c_g=A_17/17、残N_g=2。.37の残二件の所要を混ぜない |
| 義務の判定 | 元29+前回追加4+今回の代表/引渡し4=**37行、A12/B16/C6/D1/E2**。O037/O066/O138は本体が他段である契約の確認。L10単独で義務全体を閉じる行は0 |
| 転記表 | detail末尾の「取りまとめへの転記表」に、段/G/H/Oの変更、所要の算入先、旧番号との対応を集約 |

変性を読む箇所は再レビューの再計測と一致する33ファイル175行・211出現、TelLe36行、TelClosure45行、和集合34ファイル249行である。Inhabitsは4ファイル46行、Exhaustiveは7ファイル14行。今回も本番ソースを変えていないので、この読者の候補数は変わらない。新しい意味の判断や旧の入力の局所規則は追加する予定の定義であり、この現行の出現数へ加えない。

## 所見ごとの処置

| 所見 | 処置 | 担当・完了の判定 |
|---|---|---|
| 再中1 unused | Variance.unused/unused_consを外す。非出現の型引数にcovariantを空に許すことも避け、ParamOccursInFieldsが偽ならinvariantとする検証を追加。三値/22規則へ修正 | V、.02〜.09。Tokenの権限の印の意味を広げない。planの確定判断であり新たな問いにしない |
| 再中2 WellFormedと内外 | Program.WellFormedの定義を.23へ追加。全宣言のscope/arityと格納metadataの適格性を定義。requirements/publicBoundaryの完全な収集はLeanに表せる情報からは得られないと明記 | W1、.23/.56。提供列が空ならその全称は空に成り立つが、元ソースが空とは証明しない。D14の全照合はL70/R10b、O005/O033 |
| 再中3 意味の不変量 | InhabitsをIHにせず、正規形の値の形・全子値・全事実の二値の真を持つValueMeaningを使う。V_Sub/refineでEntails.soundへpとΓ/Φの真を供給し、qのfalseと矛盾させる | X1、旧.13→.15〜.17、旧.14→.18〜.20。評価の単調性・正規化・全移送、refine/捕捉の接続を名指し。G09の全証明は4〜8時間へ再見積もり |
| 再中4 値依存の長さ | 任意の閉じたnと長さnのList、0<nからV_Refineと網羅性へ進む代表の署名/手順を追加。開いたΓ/Φからの静的合成の義務を明記 | .20、L70/R10bのO037/O066/O079/O138。開いた算術の有限の証明書は既存L30が担当。閉じた代表でその生成を完了としない |
| 再中5 中間型のkind | 結論だけのLegacyOutputInputを廃止し、旧七判断の全中間判断をデータで記録するLegacyJudgment、46局所規則、全nodeの形成/kindを検査する帰納述語へ変更 | I/E、.28/.29/.55。letの中間型と拡張Γ、Appの結果、空腕/resume/節を覆う。LegacyTablesに全constructor欄のAnnotation/HasKindとarity一致を追加。全埋め込みはL20 |
| 軽6 17件と残二件 | 旧.27を新.36（反映三件、最初17件の完了）と.37（残二件）へ分離 | 通常の単位別resultsでA_17と残二件を分離。.36でN_g=2、.37で0へ更新 |
| 軽7 Qの一致 | QTel_signatureTel、Def.QTel_eq_Qsig、MethSig.QTel_eq_QsigをNamesWF付きで追加する計画にした | .21/.22。一時入力で三補題の形と証明を確認。Admissibleへ別のNoFail前提を追加しない |
| 軽8 不要の旧読者 | 12件のFND行と専用表に旧読者/説明の参照、L20 G04/G08又はL70、直接使う新しい形成/正規化/Scopedの入口を記載 | .55で引渡し。旧のWF→Canonicalや旧RangeWFとの同値を復活させず、読者の追随の既存枠で代替する |
| 軽9 枠と余裕 | 旧.05/.13を各三単位へ分け、旧.14の代表も三つへ分割。一時間で閉じる実績がないことを明記。余裕を0〜3時間とし根拠を示す | 単位の上端2倍と全Lの停止条件を保つ。工程移動と見積もり不足の増分を別欄にした転記案を提示 |

旧導出の入力は、Propの導出hを分解してPropを返すdefではない。TypeであるLegacyJudgmentのデータ、旧規則の局所の関係、全nodeを検査する帰納述語を定義し、その強い入力の証明に帰納して新しい型付けを示す。旧HasTypeと根のkindだけから無条件に全中間型のkindを導く正則性は主張していない。これは適格な旧導出の片方向の橋の前提の明確化であり、新しい型付けの結論を入力へ入れる方法ではない。

## 主な定理の前提・定義の変更

| 対象 | 今回の変更・条件の範囲 |
|---|---|
| P.WellTyped.variance | 三値の変性、constructor欄の形成/kindと、非出現引数の不変を検査。提供されたmetadataの正負を検査するが、元ソースの辞書制約/公開境界の完全な収集は含意しない |
| P.WellFormed | L10.23で全宣言と格納metadataのscope/arityを定義。これを原ソースとの収集の一致という前提にしない。preservation等が渡す位置は同じ |
| progressと網羅性 | 新しい意味の不変量を証明のIHに使い、最後にInhabitsを導く。ValueMeaningを主定理の独立仮定やBuiltinsの信頼欄にしない |
| Exhaustive/inhabits_of_typed | 正規形a.normへの所属を入口/結論とする。D07の篩の平坦化/true消去/関数畳込みに合わせる変更で、carrierへの消去ではない。rawなInhabitsへ戻す系ではWFを明示し、型付け一般だけから無条件に仮定しない |
| 捕捉のあるmatchRun | 型付き像で閉じた型付け→ValueMeaning→閉じた型への所属→値置換の反映→元の開いた型の正規形への所属→Exhaustiveの順とする。開いたvそのもののInhabitsを仮定しない |
| 旧導出の橋 | 根だけでなく全中間判断のLegacyOutputInputと、constructor欄のAnnotation/HasKind/arityを前提にする。全導出はL20で証明する |
| QTel/Qsig | NamesWFの下の一致を補題として供給し、呼出し側に新しいNoFail条件を追加しない |
| CoreAssumptions/TargetAgreement/σ | 今回新しい信頼欄・公理・精密な外部状態を追加しない。未移行のsig_scopedはG08の既存残件として区別 |

正規形を入口にするExhaustiveと、生の所属へ戻すWF付きの系の分離は、今回の証明方針を具体化するための定義上の選択として明示した。取りまとめはこの変更節も確認する。適格なWF型についてはInhabits.norm_iffを実装して一致を示すことが完了条件であり、今回その全証明が既に閉じたとは記録しない。

J01/J02/Byteと七幅の比較/既存の工程の移動は前回の判断を継承する。unusedの除外はplanの最新の確定判断に従う。今回の新しい見込みとL70からのWF定義の移動は、末尾の表で取りまとめへ提示する。残る意味上の分岐はJ04（failedの所属の入力条件と接続）で、L20/L40に残す。新公理・主定理の結論の弱化・精密な外部状態・利用者の書ける形の新しい制限を提案していない。

## 見込みと転記先

所要時間（能動時間）の転記案である。工程の移動は合計を保ち、見積もり不足の訂正だけを増分として示す。

| 段 | 前回の配分 | 今回の工程の移動 | 見積もり不足の訂正 | 今回の提案 |
|---|---:|---:|---:|---:|
| L00b | 36〜77 | 0 | 0 | **36〜77時間** |
| L10 | 21〜49 | L70から+0.5〜1 | +7.5〜11 | **29〜61時間** |
| L20 | 31〜75 | 0 | G09 +3〜5 | **34〜80時間** |
| L40 | 15〜35 | 0 | 0 | **15〜35時間** |
| L70 | 24.5〜63 | L10へ−0.5〜1 | 0 | **24〜62時間** |
| 五段の小計 | **127.5〜299** | **0** | **+10.5〜16** | **138〜315時間** |

L10の下端は今回の積上げ29を直接使う。前回の積上げ下端24と配分下端21の差を残したまま縮めない。上端は基本58と余裕3の61である。余裕の内訳は単調性/形成1.5時間、観測/正規化0.75時間、旧入力/読者0.75時間を上限の目安とした。いずれも実測ではない。L00bの代表や今回のQの短い証明の比を掛けず、中心の補題の通常resultsで更新する。

detail末尾の「取りまとめへの転記表」には、この表に加えG/Hの担当、O005/O033/O079の担当欄の変更とO037/O066/O138/O065/O159/O160/O167/O016/O084の完了条件の追記を一節に集めた。O037/O066/O138は担当欄を据え置く契約の確認である。L70/R10bの辞書制約/公開境界とscrutineeの静的合成は、核の代表だけで完了としない。

## 今回の検証と限界

| 確認 | 結果・外側の時間 |
|---|---|
| 再レビューとplanの最新判断、現在のLean | 読取り。ConDeclの欄、Programに公開境界がないこと、Logic/LogicSound/ClosedEvaluation、Qの定義、旧七判断46規則、旧WellFormedを照合 |
| 不要43件の旧読者 | 字面で検索し、再レビューの12件の参照と代替を表へ保存。別にTy.norm_legacy/Eff.norm_legacyの旧TypeSubstLemmasの二件を確認。説明内の参照と証明の呼出しを区別 |
| 文書の静的照合 | 59単位の連番/依存順、37義務と分類12/16/6/1/2、元のL10担当29行の包含、foundation158=16+43+99、表の列数、コード枠、リンク、禁止する記述、時間の算術を確認。参照の区間表記二箇所を整理した最終一括検査は問題0、Python内約0.0048秒。保存した二つのLean入力のバイト数/SHA-256も一致 |
| 一時入力Q.leanの初回 | `lake env lean -M 12288 <tmp>/Q.lean`。終了1、約0.662秒。Qemptyの名前空間を明示する必要があった |
| Q.leanの修正後 | 同じ入口で終了0、約0.671秒。QTelとQsigの一致及びDef/MethSigの系を、補助入力にsorry/axiomを追加せず確認 |
| 保護対象 | 開始時のplan・レビュー原本・rv-l10八入力の計10件をSHA-256で識別し、最終照合で不変を確認 |
| 本番ビルド/実装検査 | 未実行。計画文書の作業で、gitを使うcheck.shも実行しない。実装担当の局所検査/work/公理依存/群・段末レビューはdetailへ割り当てた |
| 最大常駐量 | 未取得。今回の文書作業は採取対象ではない |

Qの補助入力の全文を以下に保存する。入力は1117バイト、SHA-256は `e45c78ac97042f5584735caf3b022619984aec9a42c1bdc4e99a7abf18c17172` である。一時ファイルの存続に証拠を依存させない。これは本番への実装ではなく、予定した補題の形の確認である。

```lean
import Benitoite
open Benitoite Benitoite.Release.Refinement
namespace L10PlanR2
theorem QTel_signatureTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) :
    QTel (signatureTel ns ps r e) = Qsig ps r e := by
  induction ns generalizing ps with
  | nil =>
    have hp : ps = [] := List.length_eq_zero_iff.mp (by simpa using hn.1.symm)
    subst ps
    funext i
    apply propext
    simp [signatureTel, QTel, Qsig, QTys, Benitoite.Release.Qempty]
  | cons name ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns ps := ⟨Nat.succ.inj hn.1, hn.2.of_cons⟩
      simp only [signatureTel, QTel]
      rw [ih ps hn']
      funext i
      apply propext
      simp [Qsig, QTys, or_assoc]
theorem Def_Q (d : Def) (hn : NamesWF d.names d.params) :
    QTel d.tel = Qsig d.params d.ret d.eff :=
  QTel_signatureTel d.names d.params d.ret d.eff hn
theorem MethSig_Q (ms : MethSig) (hn : NamesWF ms.names ms.params) :
    QTel ms.tel = Qsig ms.params ms.ret ms.eff :=
  QTel_signatureTel ms.names ms.params ms.ret ms.eff hn
end L10PlanR2
```

今回、ValueMeaning・評価の単調性・正規化の全補題・LegacyRule/LegacyOutputInput・Program.WellFormedは実装も型検査もしていない。detailの完全署名又は定義の形は計画である。Qの成功をこれらの証明の完了へ外挿しない。再レビューの「意味の不変量が別に必要」という所見を、前回の三値の評価例が通ったことで閉じたとは扱わない。

### 前回から継承する補助入力

前回、構文からPropへの再帰、falsity/Byte13/空Listの評価の境界を検査した入力を保持する。今回は再実行していない。これはRefinementPossibleの評価例の証拠であり、型付けからValueMeaningを導く証拠ではない。前回の入力は2498バイト、SHA-256は `93869fe1cfb838b80b9d397a3c4066d1a0a0d945f258136263926f7c36653a15` である。

```lean
import Benitoite
open Benitoite
open Benitoite.Release.Refinement
namespace L10PlanShapes
noncomputable def selfObservation (v : Val) : Option Observation :=
  v.toTerm?.bind (Term.observe (fun _ => none))
noncomputable def RefinementPossible (p : Pred) (v : Val) : Prop :=
  p.evalWith (fun | 0 => selfObservation v | _+1 => none) ≠ some false
example (v : Val) : ¬ RefinementPossible .falsity v := by
  simp [RefinementPossible, Pred.evalWith, Pred.atomReady, Pred.atomValue]
example : ¬ RefinementPossible (.le (.var 0) (.integer 12))
    (.const (.byte 13)) := by
  simp [RefinementPossible, selfObservation, Val.toTerm?, Term.observe,
    Pred.evalWith, Pred.atomReady, termReady, Observation.sort,
    Pred.atomValue, integerAs, observeAs, Term.interpret]
example : ¬ RefinementPossible (.lt (.integer 0) (.measure .listLength (.var 0)))
    (.list []) := by
  simp [RefinementPossible, selfObservation, Val.toTerm?, Val.toTermSlots,
    Term.observe, observeSlots, Pred.evalWith, Pred.atomReady, termReady, Observation.sort,
    Observation.measure, Pred.atomValue, integerAs, observeAs, Term.interpret]
-- 導出は引数に取らず、Typeである旧構文をPropへ再帰する形。
mutual
  def valueInput : Release.Val → Prop
    | .lam _ _ body => compInput body
    | .con _ _ vs | .list vs | .setV vs | .dict _ _ vs => valuesInput vs
    | .mapV ks vs => valuesInput ks ∧ valuesInput vs
    | .super v _ | .checkedRequest _ v => valueInput v
    | _ => True
  def valuesInput : List Release.Val → Prop
    | [] => True
    | v::vs => valueInput v ∧ valuesInput vs
  def compInput : Release.Comp → Prop
    | .builderLet _ m | .lazyC m => compInput m
    | .builderOp _ _ _ vs => valuesInput vs
    | .ret v | .escape v => valueInput v
    | .letIn m n => compInput m ∧ compInput n
    | .app f vs | .meth f _ _ _ vs => valueInput f ∧ valuesInput vs
    | .ite v m n => valueInput v ∧ compInput m ∧ compInput n
    | .match v arms => valueInput v ∧ armsInput arms
    | .use v m => valueInput v ∧ compInput m
    | .handle m cs => compInput m ∧ clausesInput cs
    | .resume k v => valueInput k ∧ valueInput v
  def armsInput : List Release.Arm → Prop
    | [] => True
    | .mk _ g m::xs => (match g with | none => True | some q => compInput q) ∧
        compInput m ∧ armsInput xs
  def clausesInput : List Release.Clause → Prop
    | [] => True
    | .mk _ _ _ m::xs | .fail _ m::xs => compInput m ∧ clausesInput xs
end
end L10PlanShapes
```

### 保護対象の識別

| 改造からの相対パス | 今回の開始時のSHA-256（最終も一致） |
|---|---|
| plan.md | `e1f2b459c65fadab847bfa0b658aefdba977bdea08cb48afb4f6c8dae3c1dbb8` |
| reviews/RV-L10-plan.md | `9e26d80689971edb8b456d07add263dfdc8eb5b6ea71740b544fe41e454ac22a` |
| l10/rv-l10-count.lean | `6c9b01bf3b4b5b7eb784c797e6efb0638b2489fced0db92a4aa281bc2a1dd50d` |
| l10/rv-l10-names.lean | `d3824e1a8b3f77dc520bbf78829fe4012ff560def4efa969b1939e5200ff86a1` |
| l10/rv-l10-prop.lean | `3cb1c4fb76cf18d0c4b8ba206b82e935921a5b149a4c56d8d0b7421e4dbab4d2` |
| l10/rv-l10-sig1.lean | `30f93813e372041cb2875df1fd44c053ac251fb32a00bc0423cd02051c6f1f45` |
| l10/rv-l10-sig2.lean | `a3e5872a26d7a9db3801882e54fc00857ab80140871c557c1d8ed18fbc4bfe1c` |
| l10/rv-l10-sig3.lean | `ffad0bb5ae524fbc443703b613d9eb14a3c5678a96de040dfa721e40c37a8969` |
| l10/rv-l10-t1.lean | `0d4aa12b050668fe62cfc410378184a5d0b27055ea800131d9ce9c2472c85ab7` |
| l10/rv-l10-t2.lean | `b4ab71ef12a33b09e6239a8d00b3fecbaf1f7c669e274c32fdf8931638ad8364` |

## 残る工程

| 手順 | 担当・検査/受入 | 見込み |
|---|---|---|
| 変更節の確認と転記 | 取りまとめ。再レビューの指示どおり、変更した定義・前提・見込み・O行を確認し、末尾の表をplanへ写す。全体の再レビューは置かない | 不明 |
| 起動とL10本体 | detailの58単位。局所検査、整合した区切りの既定全Leanのwork、必要な仕様例を検査 | 所要時間（能動時間）29〜58時間、修正の余裕0〜3。検査待ちは不明 |
| TODO-294 | L10.57。意味を保った改名と全読者を確認 | 相乗り枠の所要時間（能動時間）0.5〜1時間 |
| 公理依存と実装の群/段末レビュー | A-L、定義/言明/仮定の独立レビュー、同じ最後のworkにRSS採取 | A-Lは1〜5分案、その他の待ちは不明 |
| 受入と後段の起動 | 設計者/取りまとめ。37行の段別判定、内外、意味の接続、旧読者の代替を確認 | 不明 |

計画担当の九所見への処置と自己点検を記録した。取りまとめの変更節の確認・planの転記・実装の起動は未実施である。
