# L60-plan 作成結果

2026-11-05。B_WORKは`4998e26854eec6be3d5cb9efd4acde54a2603d44`、指定ブランチは`m014/l60-plan`である。ブランチの検査・切替・作成・コミットを含め、gitコマンドは実行していない。今回の変更は[detail.md](detail.md)と本書だけであり、実装はしていない。

初回作成の記録は以下に保存する。現在の決定・集計と所見の処置は末尾の「再開1」を正とする。

## 作成した下書き

[detail.md](detail.md)に、入口、18項目の控除、規則・葉の母集団、三モデルの12欄、全標準表の合成、完全署名/定義の形F01〜F08、37起動単位、9群、義務・申し送り、方式の確認、分岐する判断、検査と見込みを記した。取りまとめによるplanへの反映と独立レビューは未実施である。L60本体の義務を完了にした行は0である。

| 集計 | 結果 |
|---|---|
| 起動単位・群 | L60.01〜.37の37単位、A/B/C/D/E/F1/F2/G/Hの9群 |
| 所要時間（能動時間）の積上げ | 1,325〜2,310分＝22時間05分〜38時間30分、中心30時間17分30秒。planの17〜41時間・中心29は変更しない |
| 入口で控除 | C01〜C18の18項目。宣言/型規則/置換/受信検査/外部保存葉、解放の既存葉、L50の75欄、合成器、L40の実応答、既存の署名形成・Atの三補題など |
| 義務 | planの明示L60は14行、共通4を含む18行。L20/L30/L40/L50の残るL60は5/2/11/19行。和集合26行、差集合8行。H24のO144を他段とする点検1行を加えた27行 |
| 義務の分類 | 技術21・記録1・共通4・他段1。O144の理論/実CLIの所有は移さず、合成の使用はO022/O034/O062/O065で受ける |
| 申し送り | L50の全31行＋原所見/前段の28行＝59行。L60受持41・既済み継承4・他段受持14。重なる証拠・作業の所要は再計上しない |
| 三モデルの入口の12欄 | 空疎8・自明1・適格な外部呼出しを持つPでは不成立3 |
| 三モデルの目標の12欄 | 外部9＋Targetsの解放1の実質10、資源を持たない二表の空疎2。既存75は実質69/空疎6を保つ。合成後の87欄の参考は79/8 |
| 規則の母集団 | Ty21、型付け14判断76枝、ExternalValueType9（scalar13）、Occurrence6、UseAt3、TelWF2、ExternalSignature.WF8欄、鍵と宣言4対、carrier12とPredicates12、応答4葉、外部Step3、通常解放8＋Use1、通常資源5種、表層の外部固有5接続、偽造拒否3分類 |
| 全標準表 | 現在Rustの登録61部分・523参照を静的集計。L40の23モジュール328公開API（pure244/core84）、107演算子、範囲13APIとは重なる別母集団。合成表の固有名数/全証拠の対応は未照合 |
| 本番の先行追随 | .23〜.25で既存の任意P/Bのresponseから合成する最初の16件を固定。旧Releaseから外部補題を移す作業は0件。測定だけの作業は追加していない |

## 読み取りの範囲

共通依頼文を最初に読み、planの指定された節・L60/全Lの義務・検査・見込み・変更の追記、decisionsのD25〜31/D38/D66〜71等とU02/U05/U06、READMEの設計者の決定を確認した。前段の受け入れはREADMEとplanの最新追記を正とした。L50段末の冒頭等の古い「受け入れ待ち」を現在の状態に戻していない。

L50のstage-results、j/handoffs・conditions、k/obligations・handoffs・l60-fields、l/review-points、detail、H/I/Jの取りまとめ追記、L20/L30/L40段末のL60を残す行とL40/gの最終義務表、L00b.15/theorems・mappingを読んだ。reviews内のL60を含む行を全件検索し、受信/署名/行支持/実表/正常応答/通常資源/表の合成/空疎/依存に関する原所見と取りまとめ追記を照合した。L30のreview-handoffsとL40/gの申し送りも、重複を確認した。

LeanではRefinementのScopeSyntax/Types/Syntax/External/Typing/ExternalCheck/ExternalResponse/ExternalConnection/ExternalStateLeaves、Substと移動/置換の該当枝、Source/SourceScope、LeafInputs/TelClosureの供給、Semantics/Step/HandlerGeneral/ContinuationGeneral/StepLeafSelection、ConstraintAssumptions/TargetModelConditions、三モデルとModelHttpConditions/ScopeModels、標準の任意P/BのresponseとP/B固定の本体の定理を区別して読んだ。旧ReleaseとSurfaceの型・表はexternal固有の構成子を持たず、交換の外部除外が残ることを確認した。

Rustはexternalの宣言/受渡し型・同一component/resource・borrow/own・Stateの検査、外部関数の値としての利用の拒否、通常資源の5種と解放の関係、全表の入口PARTSに限って形を調べた。全523個の算法を調査したわけではなく、実行で外部の受理/拒否を比較してもいない。

## 短いLean試行

入力は`<tmp>/L60PlanProbe.lean`、実行場所は`formal/`、コマンドは `lake env lean -M 12288 <tmp>/L60PlanProbe.lean` とした。大きい具体値の評価、全build、既定importの変更はしていない。最終入力は下に全文を保存する。消える入力へのリンクを証拠にしない。

| 試行 | Lean本体の終了・外側時間 | 判定 |
|---|---|---|
| 最初の呼出し | 非同期の実行結果の終了を回収できず未取得 | 成功に数えない。同じ短い入力を回収可能な呼出しで再検査した |
| 入力の再取得 | 補助のPythonが一時ディレクトリの所在を誤り終了1。Leanは起動していない | 入力はOSの実際の一時ディレクトリから取得し直した |
| 最初の回収できたLean | 終了1、0.7617秒 | Release.ErrKind/OpaqueNameの名前空間の指定不足。未宣言の型パラメータとして推論されて型が不一致。エラーのある入力の生成sorryAxを成功の根拠にしない |
| 名前空間を明示した入力 | 終了0、0.7099秒 | 応答関係/err存在/射影3つ、解放の2結果、現行解放3欄、既存入口の実型を確認。未使用変数の警告あり |
| F08二署名を加えた最終入力 | 終了0、0.7538秒 | V_ExternalRef/C_Externalから全添字の二葉を証明。carrier/受信/既存保存葉の実型も印字 |

シェルの補助実行器の終了と、出力へ明記したLean本体の終了を分けた。Lean終了1の試行でも、その終了を表示して正常に戻るPython実行器の終了は0だった。これをLean成功とは扱っていない。最大常駐量は未取得（計画上の非採取）である。

最終の五つの補助定理の#print axiomsは、response_err/response_exists/ref_typed/call_typedがpropext・Classical.choice・Quot.sound、release_bothが公理なしだった。成功入力にsorryAx/独自公理はない。これは五つの試行の公理依存であり、全既定環境の段末A-Lではない。

F04の関係を定義できること、errの証人を作れること、正常応答を許す関係を全モデルへ接続できることは別である。F01の全76枝、全三条件と75欄の移送、型付き通常資源からの一般のcanonical、全523登録の証拠の対応は本下書きでは未確認と記した。

最終入力は3773バイト、SHA-256は`ced5152199094d987fc4d7528376028fca4ef3cbc80f84b77408e09285c35e43`である。

```lean
import Benitoite
namespace L60PlanProbe
open Benitoite.Release.Refinement
abbrev ErrKind := Benitoite.Release.ErrKind
abbrev OpaqueName := Benitoite.Release.OpaqueName
noncomputable section
def response (P : Program) (base : Builtins) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) (out : Outcome)
    (obs : List Benitoite.Scope.Domain.Target) : Prop :=
  obs = [] ∧ ∀ Ψ d a e, P.externalFunction f = some d →
    ExternalArgs P base Ψ d ts vs a e →
    Outcome.Carrier P base Ψ out a ∧ (∀ n : Int, out ≠ .exit n)
theorem response_err (P : Program) (base : Builtins) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) (r : ErrKind) :
    response P base f ts vs (.err r) [] := by
  refine ⟨rfl, ?_⟩
  intro Ψ d a e hd ha
  exact ⟨trivial, by intro n; simp⟩
theorem response_exists (P : Program) (base : Builtins) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) : ∃ out obs, response P base f ts vs out obs :=
  ⟨.err "ExternalFailure", [], response_err P base f ts vs _⟩
def augmented (P : Program) (base : Builtins) : Builtins :=
  {base with externalResponse := response P base}
example (P : Program) (base : Builtins) : (augmented P base).sig = base.sig := rfl
example (P : Program) (base : Builtins) : (augmented P base).sat = base.sat := rfl
example (P : Program) (base : Builtins) : (augmented P base).delta = base.delta := rfl
def release (isResource : OpaqueName → Bool) (v : Val) (_r : Option ErrKind) : Prop :=
  ∃ o i, v = .const (.opaque o i) ∧ isResource o = true
theorem release_both {isResource : OpaqueName → Bool} {o i}
    (h : isResource o = true) (r : ErrKind) :
    release isResource (.const (.opaque o i)) none ∧
    release isResource (.const (.opaque o i)) (some r) :=
  ⟨⟨o,i,rfl,h⟩,⟨o,i,rfl,h⟩⟩
example (P : Program) (Ψ : StoreTy) (v : Val) (o : OpaqueName)
    (h : HasTypeV P Model.builtins Ψ [] [] [] v (.opaque o (.fixed .top)))
    (resource : Model.builtins.isResource o = true) : False := by cases resource
example (P : Program) (Ψ : StoreTy) (v : Val) (o : OpaqueName)
    (h : HasTypeV P ModelHttp.builtins Ψ [] [] [] v (.opaque o (.fixed .top)))
    (resource : ModelHttp.builtins.isResource o = true) : False := by cases resource
example (P : Program) (Ψ : StoreTy) (v : Val) (o : OpaqueName)
    (h : HasTypeV P ModelTargets.builtins Ψ [] [] [] v (.opaque o (.fixed .top)))
    (resource : ModelTargets.builtins.isResource o = true) :
    ∃ r, ModelTargets.builtins.releaseResponse v r := ⟨none,rfl⟩
#check ModelScopeConditions.core
#check Builtins.ExternalAssumptions.received_value
#check StateTyE.external_apply_all
#check StateTyE.external_value_all
#check StateTyE.external_error_all
#check StateTyE.externalRef_contract_inputs
#check StandardOperatorResponse.response
#check StandardStructuralEqualityResponse.response
#print axioms response_err
#print axioms response_exists
#print axioms release_both

theorem ref_typed {P B Ψ Q C Γ Φ f d ts}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (inst : SignatureInstance P C Γ d.parameters d.kinds ts []) :
    HasTypeVQ P B Ψ Q C Γ Φ (.externalRef f ts)
      (.dependentFn (instantiatedTel d.parameters ts [])) :=
  .V_ExternalRef lookup wf admissible inst

theorem call_typed {P B Ψ Q C Γ Φ R Δ f d ts ws a e}
    (lookup : P.externalFunction f = some d) (wf : d.WF P)
    (admissible : ExternalCallAdmissible P B C d ts)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws
      (Tel.bind (typeEnv ts) d.parameters) a e) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.externalCall f ts ws) a e Δ :=
  .C_External lookup wf admissible args
#print axioms ref_typed
#print axioms call_typed
end
end L60PlanProbe
```

## 分岐する判断と未完の範囲

| 番号 | 取りまとめへ渡す判断 |
|---|---|
| J60-1 | 三モデルへ外部応答を定義して既存75欄を対応する拡張表へ移す案を推す。Pを外部宣言なし/呼出しなしへ制限する案は、書ける形/適用範囲を狭めるため設計者の判断に分けた。関係の選択は未採択 |
| J60-2 | 全値にnoneを許す関係から、通常資源の分類と成功/失敗を許す抽象関係へ接続する案を推す。精密な開閉状態・失敗理由の計算が必要なら停止条件へ戻す |
| J60-3 | 全表523参照のうち、既存の署名/δ/本体の証拠へ対応しない行を群Aで全件確定する。328だけへ狭めず、新しい信頼条件や常にerrの代用も足さず、同じ提供範囲の方式・順序・所要を確認する |

U02/U05、受信拒否したownの解放、CaptureReadBoundaryの登録判断とR50の既知の比較点は、それぞれ既存の担当へ残した。新しい主定理の前提・結論・公理・精密外部状態の追加案は置いていない。独立レビュー、取りまとめによるplanへの反映、L60本体の実装、正式検査・受け入れは未実施である。

## 文書の点検

件数・集合・見込みの合計・群ごとの内訳、Markdown表の列数、相対リンク、手元の絶対パスがないことを、読み取りのPythonで点検した。記録する最終結果は次の点検の欄に追記する。git diff/status、work/dry-run、Rustテスト、既定lake build、全比較は実行していない。今回の文書だけの作業へRust全libを追加していない。


最終の静的点検は終了0だった。対象は保存したdetail/resultsの二文書である。

| 検査 | 結果 |
|---|---|
| 起動単位 | 01〜37の連続性、重複0、全37行に8欄あり |
| 時間 | 1,325〜2,310分、群別の9行の和と一致。中間のB〜F2は6群、890〜1,580分 |
| 義務 | planの明示14・共通4、前段5/2/11/19、和26＋O144の27と出どころを機械照合。不足0 |
| 申し送り | H01〜31/S01〜28の59行、分類41/4/14と一致 |
| 規則 | Types.leanのTy21、Typing.leanの14判断76構成子、外部の9/6/3/2規則と実ソースを照合。Mapのkey枝は構文と適格入力の到達性を区別 |
| 登録部分 | PARTSの61部分、PURE_DECLSの別名を展開した523参照。全配列の項が::DECLの形であることを確認。固有名数や全原署名の検査とは区別 |
| 文書 | Markdown表の列数、コードブロック、相対リンクは全て正常。手元の絶対パス・docs/todoへのリンク・指定を避ける語の混入0 |
| 大きさ | detailは98,952バイトで100,000未満。分割ファイルは追加していない |

点検したdetailのSHA-256は`362c2523a80ce8c9fb59e17d58e9b3fa5c55969a62d5cd16fadee464206f734b`である。

作成開始は2026-11-05 06:58:07（+0900）、この最終点検の記録時刻は2026-11-05 07:27:36（+0900）である。外側の時間は約29分で、読み取り・執筆・短いLean待ち・点検を含む。厳密な能動時間は分離していない。依頼の4時間の停止条件には達していない。


## 再開1: RV-L60-plan の所見の処置

2026-11-05。開始は07:45:54（+0900）。対象は[detail.md](detail.md)と本書だけである。引継ぎのB_WORKと指定ブランチは冒頭のとおりで、gitコマンドは実行していない。[独立レビュー](../reviews/RV-L60-plan.md)の重1・中3・軽4・情報7を、再開1の取りまとめの判断に従って処置した。レビュー・plan・formal・処理系は編集していない。本節は計画の修正であり、L60本体の実装・義務の閉鎖・修正版の独立レビュー済みを表さない。

### 所見ごとの処置

| 所見 | 処置とdetailの反映先 |
|---|---|
| 重1 | J60-3=(a)を決定済みとした。第2.5節/F07/.04/.21/.23〜.29/群F1・F2/義務O062・O064・O065/第8・10節をそろえた。既存の実δ・本体・応答の証拠がある全行を同じP/Bへ合成する。証拠のない公開名・資源名は07-04の仮定側へ残し、一名一行で名前と理由を記録する。新しい意味や無条件err、semantic providerで埋めない。合成漏れ0と仮定側の全名の記録を完了条件として分けた |
| 中1 | 第2.2節/F01/.02/.05/群A/第7.3節を七射影へ変更。effectsを追加し、HasTypeCQ.of_fieldsの完全署名とC_Handle→handled→effOpsの依存を書いた。C_Use・ConstOKも最初の枝の点検へ含めた。of_responsesの追加一致からeffectsを除き、応答/releaseだけの更新なら七欄ともrflであると明記した |
| 中2 | 第2.4節に不成立・空疎・自明・実質の定義と判定順を置いた。M02/M06/M10の定数errによる存在を自明とし、正常/拒否の非空性は.11の別証拠へ分離。目標12欄=実質7/自明3/空疎2、87欄=76/3/8へ変更。.22/.32/群E/第5・8節も更新した |
| 中3 | F07で合成表上の再証明を選択した。一般の表拡張の補題を暗黙に使う文を除き、definition_typed/program_typed/program_wellFormedの完全署名を記した。群Aで証明先とlookup・handled/effOps・ConstOK・isResource等の副条件を固定し、.27で本体の全枝を合成P/Bで閉じ直す。署名固定は.02/.05、再証明は.27の見込みへ入れた |
| 軽1 | .35と第9節を「Leanのprivateの宣言と生成宣言」とし、ディレクトリとの誤読を避けた |
| 軽2 | 第2.1節でBool添字がUnitを許す位置を表し、unit規則はtrueだけにあるため9×2=18を場合の数にしないと明記した |
| 軽3 | C05へValueBindingのTy.bind_externalを追加。F02でexternalの枝を持つ全変換とそのラッパーを列挙し、定義展開と既存補題を控除した。.07は入れ子の読者でID/component/resourceを照合する20〜35分へ変更した |
| 軽4 | 群EはCの後に起動でき、Dの成果を待つ依存はないと記した。.19〜.22の依存は保った |
| 情報1 | 構成子数・宣言数等の既存集計は維持。Rustの5資源種・61部分523参照は台帳の入力、Leanの証拠の合成対象とは別であると明記した |
| 情報2 | 義務27行の集合と技術21/記録1/共通4/他段1を維持。J60-3に関わる完了条件だけを具体化し、担当は移していない |
| 情報3 | 申し送り59行と41/4/14の分類、全ての受け口を維持。S27の集計を四分類へそろえた |
| 情報4 | C01〜C18の控除とF05の既存前提の供給を維持。軽3の既存補題をC05の内数へ加え、控除項目の数は増やしていない |
| 情報5 | J60-1=B、J60-2=F06を決定済みとし、書ける形・主定理の前提・公理・精密状態を変えない理由を第7.2節へ反映した |
| 情報6 | 入口12欄の空疎8/自明1/不成立3、目標のModel/Httpのrelease_existsの空疎2は維持した |
| 情報7 | 件数・時間・文書規約・サイズを修正版で再点検する。初回のハッシュとサイズは初回の記録として残した |

### 決定済みの範囲と完了判定

J60-1はB、J60-2はF06、J60-3は(a)である。群Aの.04は判断待ちの調査ではなく、この方針で台帳を作る単位に改めた。台帳には「元の登録部分・名前・合成/仮定・既存Lean証拠と担当、又は07-04の仮定の範囲に入る理由」を一行ずつ置く。モジュールの名前だけで仮定側の全公開名を記録したことにはしない。重複参照の出どころも残す。

群F1・F2はL40の328 API・107演算子、L50の範囲13行等、既存証拠のある行を同じP/Bに合成する。仮定側のRegex・Time・Path・Csv・Task・Encoding・TaskGroup・Json・Hash等の公開名とHttpListener・HttpExchange・TaskGroup等の資源に新しいδ/IO/精密状態を作らない。提供範囲は変えず、R50へ台帳と既存の比較の申し送りを渡す。既存証拠の合成に失敗した行を仮定側へ移して完了にしない。

分類は、前提が成り立つ反例で結論が偽なら不成立、前提からFalseを導けば空疎、充足可能な前提を使わず定数の証人等で結論が閉じれば自明、残りで充足可能な入力と型/形/応答の証拠を用いるものを実質とする。定数errの存在や全vに対するnoneは自明である。前提の否定・結論の自明さ・充足可能な入力を各欄で点検し、未確認は実質に数えない。正常応答を許す関係であることの証拠は、存在欄の分類とは別に保存する。

### 単位と所要時間（能動時間）の差

37単位・9群は変えず、1,325〜2,310分から**1,315〜2,230分（21時間55分〜37時間10分）**へ改めた。下端10分・上端80分の減少、中心は30時間17分30秒から29時間32分30秒へ45分減った。planの枠17〜41時間・中心29は編集していない。

| 群 | 単位数 | 再開前 | 再開1 |
|---|---:|---|---|
| A | 5 | 3時間15分〜5時間25分 | 3時間35分〜5時間45分 |
| B | 4 | 2時間15分〜3時間45分 | 1時間55分〜3時間10分 |
| C | 4 | 2時間25分〜4時間15分 | 同じ |
| D | 5 | 2時間40分〜4時間35分 | 同じ |
| E | 4 | 2時間15分〜3時間55分 | 2時間10分〜3時間45分 |
| F1 | 3 | 2時間15分〜4時間00分 | 2時間00分〜3時間25分 |
| F2 | 4 | 3時間00分〜5時間50分 | 3時間10分〜5時間30分 |
| G | 4 | 2時間05分〜3時間30分 | 同じ |
| H | 4 | 1時間55分〜3時間15分 | 同じ |

.02/.05は下端・上端を各10分加算（七射影・C_Handle・F07の署名/副条件固定）。.07は20〜35分減算、.21は5〜10分減算、F1は計15〜35分減算した。F2は範囲の確定による減算と.27の30〜40分の加算を合わせて下端10分増・上端20分減である。F1/F2合計は5時間15分〜9時間50分から5時間10分〜8時間55分へ変わる。検査・レビューの待ちは能動時間の積上げに加えていない。

### 照合と検査の範囲

レビューの所見と根拠を読み、07-04「形式化で仮定するもの」、plan末尾の2026-11-05の判断、既存のTy.bind_externalと各変換のexternal枝、ProgramTypingのDef.WellTyped/Program.WellTyped、ProgramWellFormedを読み取りで照合した。新しい外部事実を追加する作業ではないため、外部検索はしていない。

この再開ではLeanの新しい試行・既定ビルド・Rustテスト・check.sh・全比較・正式RSSは実行していない。レビューが既に示した反例を再実行せず、七射影の全76枝の証明と合成表の本体再証明は将来の実装の完了条件へ割り当てた。新しい署名は計画の定義形であり、型検査済みとは記さない。最大常駐量は未取得（計画上の非採取）である。

修正した二文書を、読み取りのPythonで静的点検する。コマンドは`python3 - <<'PY' … PY`（rtk proxy経由）。点検は単位/群の件数と時間、四分類の合計、義務と申し送りの行、旧記述の残存、表・コードブロック・相対リンク、禁止されたパスと100,000バイト未満の大きさを対象にする。実行結果と終了時刻は末尾へ記録する。

取りまとめへ新しい分岐判断を求める点はない。決定済みJ60-1〜3と本見込みをplanのL60行へ反映し、修正版の独立レビューを行うのは取りまとめの担当である。U02/U05等の既存の判断の所有は変えない。


再開1の静的点検は終了0だった。37単位・9群、1,315〜2,230分と群別の和、B〜F2の860〜1,480分、F1/F2の310〜535分、義務27行の21/1/4/1、申し送り59行の41/4/14、C01〜18・M01〜12の連続性を確認した。12欄7/3/2と87欄76/3/8、七射影の構造体、旧分類・未採択・D待ちの記述がdetailに残らないことも確認した。Markdown表の列数・コードブロック・相対リンクは正常で、手元の絶対パスとdocs/todoへのリンクはない。

最終のdetailは99,691バイト、SHA-256は`418c1f69096eeca296851ddd743396deef4a6cecccb41ce0ba19103e7ec908dd`である。両文書とも100,000バイト未満で、分割ファイルは追加していない。新しいLean署名を検査した成功記録は追加していない。

再開1の終了は2026-11-05 07:54:38（+0900）。開始からの外側の時間は8分44秒であり、読み取り・修正・点検を含む。能動時間と待ちは分離していない。依頼の4時間の停止条件には達していない。


## 再開2: 既存証拠の母集団を閉じる

2026-11-05。開始は07:58:56（+0900）。指定ブランチは`m014/l60-plan`、B_WORKは`4998e26854eec6be3d5cb9efd4acde54a2603d44`を継承した。gitコマンドは実行していない。今回書くのはl60内のdetail・tables・本書だけであり、formal・処理系・設計書・plan・レビュー記録は編集していない。[再開1の再レビュー](../reviews/RV-L60-plan.md#再開1の再レビュー)の再1中1・再1軽1と、計画へ影響する情報1を処置した。情報2は修正不要との判定を継承した。

### 所見の処置

| 所見 | 処置 |
|---|---|
| 再1中1 | 第2.5節を分けた[tables](tables.md)で、Lean側の入力をE01〜E15として閉じた。出典の行/有限リストと件数、証拠名、受け口を列挙した。L40/g/apis.jsonの328は23モジュールの集計であり、328個の名前と証拠は同ファイルのsource_recordが指すl40/e/sources-r4-u28.jsonのrowsから取ると明記した。同記録の全証拠組を件数付きで列挙した |
| 同・台帳 | .04に、Rust523参照からの展開とは独立にLeanの全入力を展開する条件を加えた。台帳にRust名・Lean名・証拠の完全名の列を設け、出典行・引数/射影・担当も保持する。内部名はRust名を該当なしとし、登録の側にない名前の欠落を防ぐ。複数の署名の証拠は子行で保持する |
| 同・完了条件 | .29と群F2に「全既存証拠→合成行」「仮定側の証拠名0」を追加した。出典別件数・全証拠ごとの対応を機械照合する。仮定側の証拠列が空であることに加え、元の閉じた入力にも対応する証拠がないことを名前・別名/署名から独立に確認する。台帳↔lookup、Rust登録→台帳の従来の方向も保つ |
| 再1軽1 | detailの第2.5節をtables.mdへ移し、detailには相対リンクと入力・照合の要点を残した。61部分523参照と23モジュール328行の二つの既存表は値を変えず移した |
| 再1情報1 | .05に、本体証拠を任意P/B・lookup等の副条件付き・固定P/Bの三種へ分け、出典行の重なりを除く件数を.27の80〜140分の見込みの根拠として記録する一行を加えた。実装時の分類の条件であり、今回全本体を三種に分類し終えたとは記さない |
| 再1情報2 | external_no_targetsが関係の前提を使う場合の「実質」という判定と矛盾しないとの情報を継承した。第2.4節は変更していない |

### 固定した既存証拠の入力と件数

| 入力 | 件数 | 出どころ |
|---|---:|---|
| E01 公開API | 328（pure244/core84） | l40/g/apis.jsonのsource_recordとl40/e/sources-r4-u28.jsonの全rows。証拠の組別の内訳もtablesへ保存 |
| E02 既接続演算子 | 73（算術25/順序48） | l40/e/operators-r1-u28.jsonのpure-leaf行とStandardArithmeticResponse/StandardOrderResponse |
| E03 再開2の演算子 | 34（14/10/5/5） | l40/g/resume2-operators.json、StandardOperatorResponse.entriesとentries_count/entries_unique |
| E04 全構造等号 | 2 | StandardStructuralEqualityResponseの%eq/%ne。旧不足はL40再開2で接続済み |
| E05 範囲付きpure | 6 | ScopeSignatures.entriesのpure行、ScopeResponse.response |
| E06 範囲付きIO | 7 | 同entriesのIO行、ScopedIOResponse.response |
| E07/E08/E09 三モデルの登録 | 3/15/7（延べ25） | Model.entries、ModelTargets.entries、ModelHttp.entries（所在はModelHttpConditions） |
| E10 通常資源の分類 | 1 | ModelTargets.builtinsのFile.Handleと同ファイルの型付きopaque値の無名例 |
| E11 安全な内部本体 | 7 | StandardSafe.bodyRows、registered_bodies |
| E12 精密getter | 9 | StandardSafe.PreciseGetter.all、precise_rows_typed |
| E13 精密collection本体 | 11（公開精密7は内数） | StandardCollectionRefinedBodies.coreRows、core_rows_typed/program_typed |
| E14 内部pure | 1 | %Map.replaceValues、StandardMapReplaceValues.response/delta_aligned |
| E15 通常coreとhelper | 48（10＋10＋24＋4） | StandardOrdinaryCoreProgram.allDefinitions、all_lookup_typed |
| 三モデルの既存条件（別表） | 75（25×3） | ScopeModels.conditions、l50/j/conditions.md |

E01〜E15は延べ552出典行である。重なりを除いた登録名数、定理の宣言数、pureのAPI件数とは区別する。三モデル75欄は別表で照合し、552へ加算しない。名前・署名が重なる既存証拠を捨てず、全出典行から合成/移送の行へ対応させる。出典別件数の一致と、対応なし0・仮定行への対応0を完了条件とした。

この一覧は既存のcore/helper/精密な署名を明示したものであり、J60-3の範囲を広げない。新しいδ・IO応答・資源の状態は定義していない。File.Handleの既存分類を、新しい解放関係の存在の証拠に数えない。三モデルの空疎欄と未完12欄は従来どおり分ける。

### 見込みと取りまとめへの申し送り

37単位・9群、所要時間（能動時間）1,315〜2,230分（21時間55分〜37時間10分）、中心29時間32分30秒は再開1から変更していない。.04の35〜60分、.05の70〜110分、.27の80〜140分、.29の35〜60分も維持する。既存の全件台帳・照合の対象と向きを固定する処置であり、新しい実装単位や証明を追加する見積りではない。planの17〜41時間・中心29時間も変更していない。

取りまとめへ新たな分岐判断を求める点はない。J60-1=B・J60-2=F06・J60-3=(a)の扱いを維持し、J60-3が設計者の見直しの対象である点も維持する。planへの反映・修正版の独立レビュー・実装の起動・受け入れの判断は取りまとめと設計者に残る。今回の一覧を、L60.04の行別台帳やL60.29の合成が実装済みである記録にはしない。

### 検査の範囲

今回の静的点検は、読み取りのPythonをrtk proxy経由で一度実行する。37単位・9群と時間、義務27行と申し送り59行、移した表と既存証拠の出典別件数、相対リンク（追加した見出しへのリンクを含む）、Markdown表の列数、コードブロック、l60内の各ファイルの100,000バイト以下を確かめる。Leanの新試行・既定ビルド・Rustテスト・check.sh・全比較・公理監査・正式RSSは実行しない。最大常駐量は未取得（計画上の非採取）である。実行結果と終了時刻を末尾に記録する。


再開2の全項目の静的点検は一度通しで完了し、終了0・失敗0だった。起動時の点検用Pythonは二度、文書を変更せずに停止した。初回は表の区切り行の判定が全データ行にも一致したため、次は群の合計行を9群の一行として数えたためであり、いずれも点検台本だけを直した。三回目の実行で全項目を最後まで確認した。文書の数値を点検へ合わせる変更は行っていない。

| 点検 | 最終結果 |
|---|---|
| 単位・群・時間 | 01〜37の連続性、全単位8欄、9群、1,315〜2,230分。群別の和と第10節の時間表が一致 |
| 義務 | 27行、技術21・記録1・共通4・他段1 |
| 申し送り | H01〜31/S01〜28の59行、L60受持41・既済み継承4・他段受持14 |
| 移した既存表 | Rust61部分523参照、L40の23モジュール328行 |
| APIと証拠 | 328の固有名、pure244/core84、集計のsource_recordの大きさ・SHA-256と行別記録の一致。全36証拠組の名前と件数、和328を照合 |
| 演算子 | 旧107行の全名前集合が既接続73＋再開2の34と一致し、両群の重複0。73の内訳25/48も一致 |
| Leanの有限リスト | 三モデルの3/15/7、純粋6/IO7、内部本体7・精密getter9・精密collection11・通常core/helper48の構成をソースから静的に確認。大きな値を評価していない |
| 閉じた入力 | E01〜E15の連続性、15集合の件数と延べ552出典行が一致。75条件は別表 |
| 文書 | 三文書の相対リンクと見出し39件、表の列数・コードブロック・禁止パスが正常。全ファイル100,000バイト以下 |

点検時のdetailは94,077バイト、SHA-256は`4907098c1ac83d0e34de9cf5efe9cfd523f8e28ef7f1b2440422f05f971dc6f8`である。tablesは22,148バイト、SHA-256は`7ed23d5afc82bdf35b7a581c8948d3d1be110cc81ce31ece966a270b5e11fdda`である。resultsはこの点検結果を追記する直前で30,846バイトであり、以下の終了記録も含めて100,000バイト以内に収まる。

再開2の終了は2026-11-05 08:07:49（+0900）。開始からの外側の時間は8分53秒で、読み取り・執筆・点検を含む。能動時間と待ちは分離していない。4時間の停止条件には達していない。Leanの新しい成功記録や修正版の独立レビュー済みという記録は追加していない。
