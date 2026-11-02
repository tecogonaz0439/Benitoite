# L30-plan の結果

2026-11-03。初稿とr1の記録である。現在の下書きは[detail.md](detail.md)、r1の処置は本書末尾にある。実装と設計者の受け入れは未実施。独立レビューRV-L30-planの14件へ対応したが、r1の再レビューは未実施である。

指定ブランチは `m014/l30-plan`、B_WORK は `5122e4085e269a113903842571a96f3a07c484f7` である。これらは依頼で受領した値で、GitによるHEAD/ブランチの照合はしていない。Gitの読取り/変更のコマンド、ブランチ切替・作成・コミットは実行していない。

## 初稿で作成した下書き

- 80単位（L30.01〜.80）、14群（A〜N）。所要時間（能動時間）40〜80時間、中心60時間。元の枠36〜84時間、中心60に対して中心を維持した。
- 完成済みの12項目を引き継ぎ、同じ証明を再実装する作業を控除した。粗い元枠に項目別の時間がないため、架空の控除時間は作っていない。
- 規則表はNNF28場合、Term20形、現行Certificate6→提案7、Refutation9、LinearStep2、EqProof4→10、BuiltinLemma2→12の100分岐、sort16行。scalar比較30とFloat分類12、本番整数演算25組と正常/あふれの別、鍵の11成功形/3対象外も区分した。
- 義務はplanの27行、L20段末でL30を残す15行（12重複+3追加）、群IのO143の追加1行を一行ずつ対応した。和集合31義務と共通4義務で35。plan27の分類は証明23・契約3・計画1、31の分類は証明27・契約3・計画1である。閉鎖済みは0行。
- D06はconsume/cases、検査器内のNNF再計算、traceなしを保ち、整数のderive/round/split/discard、限定合同、有限補題を列挙した。check_sound/implication_soundを探索の完全性に依存させない。
- U03は64/128/256bitを比較し128bitを推奨として示した。未決のままである。全実作業を一回ずつ数えるstepsと、枝共有・不正証明書/表現外/steps超過の分離を推奨した。U08=Aは決定済みとして継承した。

## 初稿: 読取りと短い試行で判明した点

1. 現在のCtx.factsはInteger8の型域を論理へ暗黙に加えない。幅の事実をΓ/selfへ写す接続が残る。補助Leanで、現在のΓのfactsからx≤127を導けないことを証明した。
2. ValueMeaningは不適格な生の整数定数も形の近似として持てる。型域をassumeへ足すときは値の意味とconst_meaningの供給も直す必要がある。J30-2に独立して記録した。
3. **意味上の整数等号からsnapshot内へ自由に書き換える規則を仮に加えると**、観測が欠けた変数と整数0をSetの鍵として区別できる。現行EqProofは構文の等号だけを証明するため、この例は現行の不健全性を示さない。integer/structuralのmodeと書換え位置を分ける案を置いた。
4. Entails.bindは任意のObservationEnvを受け取る。型付き入口のSource/sortの拒否をraw核へそのまま移すと、置換の公開署名を保てるとは限らない。raw核はintegerAsの射影を使い、checkerのbindの全体はA群の未確認の関門とした。
5. 現行のTerm/Predの等号はClassicalである。構造比較をrawな論理核へ用意し、型/行の関数を含む宣言準備まで一括して実行可能になったとはしない。

measureの正常結果とInfoLEに沿う置換後の同じ整数観測の二署名も補助Leanで確認した。NNF/全checkerのbind、別名の全sort、PreparedLeafの開いた一般化、S01の全追随とH/Iの切替粒度は**未確認**である。A群で先に確認し、署名とビルドを保つ順序を固定してから依存群を起動する。短い試行から全本番の完成を推定しない。

## 初稿: 実行した検査

本作業は文書の下書きである。formalのソース、処理系、現行設計、plan、レビュー記録を編集していない。書込みは許可されたdetail/resultsと、許可された補助Lean入力だけである。既定lake build、scripts/check.sh、Rustテスト、性能測定、全比較、新しい勧告照合は実行していない。文書の静的照合と、次の短いLeanの形の試行を実行した。

補助入力は`<tmp>/Shape.lean`と表す。実際に許可された一時ディレクトリへ置き、formalから `lake env lean -M 12288 <tmp>/Shape.lean` を実行した。下の全文が再実行できる入力であり、消える一時ディレクトリを根拠へのリンクにはしない。

| 試行 | 終了 | 外側の時間 | 結果と修正 |
|---|---:|---:|---|
| 1 | 1 | 0.572秒 | Observationの等号にDecidableがない箇所のdecideと、符号化の帰納のmotiveが失敗。失敗した宣言のprintにはsorryAxが現れたため成功証拠に使っていない |
| 2 | 1 | 0.552秒 | 符号化をtermの補助へ分けてbindの証明は通った。観測の等号のrflは失敗 |
| 3 | 0 | 0.553秒 | 観測の等号は定義を開くsimpへ修正。幅の不足、snapshotの二観測、床/分枝、符号化bindが通過。unused simpの警告1件 |
| 4 | 0 | 0.557秒 | 不適格なInteger8を持つ現在のValueMeaningの具体例を追加し、unused simpを除去。エラー/警告0、印字した三定理は許可三公理の範囲 |
| 5 | 1 | 0.555秒 | measureの正常結果の署名は通過。stableの依存する場合分けが失敗し、失敗宣言にsorryAx。成功証拠へ使わない |
| 6・最終 | 0 | 0.558秒 | 任意のOption観測についての補助に場合分けを移してstableも通過。エラー/警告0、印字五定理は許可三公理だけ |

RSSは未取得（計画上の非採取）。短いLeanの実行時間は担当の能動時間とは別の検査時間である。初回の失敗を終了0へ書き換えていない。

### 再実行できる補助入力

```lean
import Benitoite
namespace L30PlanProbe
open Benitoite.Release.Refinement
set_option maxRecDepth 4096

def widthCtx : Ctx := [some (.base .integer8)]
example : widthCtx.facts = [] := by rfl

theorem width_not_implicit : ¬ Entails widthCtx.facts (.le (.var 0) (.integer 127)) := by
  intro h
  have hh := h.sound (fun _ => some (.integer 1000)) (by simp [widthCtx, Ctx.facts, Ty.assume, Ty.refinementPredicates])
  have hx : Pred.interpret (fun _ => some (.integer 1000)) (.le (.var 0) (.integer 127)) = false := by decide
  rw [hx] at hh
  cases hh

example (P : Program) (η : ObservationEnvModel) :
    ValueMeaning P η (.base .integer8) (.const (.integer8 1000)) :=
  TypedMeaning.const_meaning P η (.integer8 1000)

-- 比較の整数射影が等しくても、snapshot の鍵の観測は同じにならない。
def missing : ObservationEnvModel := fun _ => none
example : Pred.interpret missing (.eq (.var 0) (.integer 0)) = true := by decide
example : (Term.measure .setSize (.setValue [some (.var 0)])).interpret missing = some (.integer 0) := by simp [Term.interpret, Term.observe, Observation.measure, observeSlots, missing, keySetCodes]
example : (Term.measure .setSize (.setValue [some (.integer 0)])).interpret missing = some (.integer 1) := by simp [Term.interpret, Term.observe, Observation.measure, observeSlots, keySetCodes, Observation.keyCode?]

theorem round_form (x b d : Int) (hd : 0 < d) (h : d*x ≤ b) : x ≤ b / d := by
  exact (Int.le_ediv_iff_mul_le hd).mpr (by simpa [Int.mul_comm] using h)
example : (-3 : Int) / 2 = -2 := by decide
example (x cut : Int) : x ≤ cut ∨ cut+1 ≤ x := by omega
example (x : Int) : ¬ (2*x = 1) := by omega

def linearTerm (ks : List Term) (cs : List Int) : Term := match ks,cs with
  | k::ks,c::cs => .add (.scale c k) (linearTerm ks cs)
  | _,_ => .integer 0

theorem linearTerm_bind (ν : ObservationEnv) (ks : List Term) (cs : List Int) :
    termBind ν (linearTerm ks cs) = linearTerm (ks.map (termBind ν)) cs := by
  induction ks generalizing cs with
  | nil => cases cs <;> rfl
  | cons k ks ih =>
    cases cs with
    | nil => rfl
    | cons c cs =>
      simp only [linearTerm, termBind_add, termBind_scale, List.map_cons]
      exact congrArg (Term.add (.scale c (termBind ν k))) (ih cs)

def enc (ks : List Term) (cs : List Int) (b : Int) : Pred := .le (linearTerm ks cs) (.integer b)
theorem enc_bind (ν : ObservationEnv) (ks : List Term) (cs : List Int) (b : Int) :
    predBind ν (enc ks cs b) = enc (ks.map (termBind ν)) cs b := by
  simp only [enc, predBind, linearTerm_bind, termBind_integer]
theorem measure_exact {m : Measure} {o : Observation} {n : Int}
    (h : Observation.measure m o = some (.integer n))
    (η : ObservationEnvModel) (t : Term) (ht : t.observe η = some o) :
    (Term.measure m t).observe η = some (.integer n) ∧
    (Term.measure m t).interpret η = some (.integer n) ∧ 0 ≤ n := by
  have hh : (Term.measure m t).observe η = some (.integer n) := by
    simp [Term.observe, ht, h]
  exact ⟨hh, Term.observe_sound hh, Observation.measure_nonnegative h⟩

theorem measure_stable {m : Measure} {t : Term} {n : Int}
    (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (h : (Term.measure m t).observe η = some (.integer n)) :
    (Term.measure m (termBind ν t)).observe ξ = some (.integer n) := by
  change (termBind ν (Term.measure m t)).observe ξ = some (.integer n)
  have hh := ((Term.measure m t).bind_observe_info ν η ξ hi).2
  rw [h] at hh
  have exact_integer {x : Option Observation}
      (hx : Observation.OptionInfoLE (some (.integer n)) x) :
      x = some (.integer n) := by
    cases hx with
    | some ho => cases ho; rfl
  exact exact_integer hh

#print axioms width_not_implicit
#print axioms round_form
#print axioms enc_bind
#print axioms measure_exact
#print axioms measure_stable
end L30PlanProbe
```

最終出力は次のとおりである。

```text
'L30PlanProbe.width_not_implicit' depends on axioms: [propext, Classical.choice, Quot.sound]
'L30PlanProbe.round_form' depends on axioms: [propext]
'L30PlanProbe.enc_bind' depends on axioms: [propext]
'L30PlanProbe.measure_exact' depends on axioms: [propext, Classical.choice, Quot.sound]
'L30PlanProbe.measure_stable' depends on axioms: [propext, Classical.choice, Quot.sound]
```

これは五定理の依存の確認であり、本番全体のA-Lを代行したものではない。

## 初稿: 入力の識別

以下は読取りを照合したソースのSHA-256である。指定B_WORKと作業ツリーの同一性をGitで確認した証拠ではない。既存L20の成功記録も、今回の試行の入力と同一とは扱っていない。

| 入力（リポジトリの根から） | SHA-256 |
|---|---|
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/implementation-request.md` | `c192998a08649ee22b155d53806636d3571d83fd25f4b084dec9e3bc0458a1ca` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/plan.md` | `a99e84323787627ff56f3b648d19f0695109b39f8781e94e715514b932c25e06` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/decisions.md` | `a5f4647af8cb8586ba17d31c56e7d449d3d7fbb7ec2411eb219c199df4fd24c2` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/README.md` | `0307bd8706f5962dc4693877652bc1fe6ff723ed35baa42e7100eb2efd464ae6` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/stage-results.md` | `28b7ce0ad51e2af0bcf90b0366b90c87c8322043abbb53cc69a73c5d9216fdd7` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/l20/detail.md` | `9ca3a779f92b02b8dae432f0172cbd18ba3d77493861074ffe57bb68f422e777` |
| `docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types/effort-ledger.md` | `077466ec017e4e4d0af28664e5e2b6f730f0f4a59125daced73dde387cf74ff7` |
| `formal/lean-toolchain` | `d5edba4e4b8faad9c1baeadb265716d20d03be4d1a2647dc5e35b0c0325bea7b` |
| `formal/lakefile.toml` | `10f2661bff8fce95a9253d976427d0ca44038ec12350c955badbc1cf1efa6e3a` |
| `formal/Benitoite/Release/Refinement/Logic.lean` | `7bb70e239a1ec3a43b00a3799bbf83750ac4e0db5d165d90af7951c772a668b5` |
| `formal/Benitoite/Release/Refinement/LogicSound.lean` | `c62882eb5dc9ff650bd3323479d3cf2f3d823748dad62a185d5dcbff0bbe9645` |
| `formal/Benitoite/Release/Refinement/Basic.lean` | `6567b7ed789781d0bd1be19aec710c27ca0f42aa39b01fe36f948e28bc794a53` |
| `formal/Benitoite/Release/Refinement/Certificate.lean` | `8ba1c54daafde961f1ce48078f64ddf7490ada218c24591b0031408341eb1661` |
| `formal/Benitoite/Release/Refinement/NormalizationLogic.lean` | `7728b1cf93d3946137ee69674cafa295301283f0f120e69c663fddaaaf2851cd` |
| `formal/Benitoite/Release/Refinement/ExternalCheck.lean` | `c64635f0fef824b3cd6ef8e6a7a0c888d3d8b3bbd26f941b40b2afb36ad229c7` |
| `formal/Benitoite/Release/Refinement/Context.lean` | `a1c8f28980e7e2baebec746a902183745399f7cf6b63a2a7de6c4cdf38759529` |
| `formal/Benitoite/Release/Refinement/ContextNormEq.lean` | `15d5867730db531f1bb7d2e27df4e010be12ee093b4604fa72d96621baaf6c77` |
| `formal/Benitoite/Release/Refinement/TypedFacts.lean` | `88be9c3770f90b91a8bd35640b89a5afc1693e61e694b7f63067ca5b394fbd06` |
| `formal/Benitoite/Release/Refinement/ValueMeaning.lean` | `8203600d43dc13f650b288da1338318855abadfa9b63d41d430e4ec19643e889` |
| `formal/Benitoite/Release/Refinement/TypedMeaning.lean` | `da56c70d3ac0d2c2ba3b57fd8a8913a339b7190efcffa9ce5a5eccec4455bca8` |
| `formal/Benitoite/Release/Refinement/Observation.lean` | `7be3f6971d21e910fb07d724d3d84620c6df3497c0bbf454e79a21427f07ec17` |
| `formal/Benitoite/Release/Refinement/ClosedEvaluation.lean` | `dd84323f9df260b4f1cd42bdf8d081623989ca2e5d04dfe9b92a7ae1912959aa` |
| `formal/Benitoite/Release/Refinement/ClosedKeys.lean` | `70351266627121a2934911c8b484c0baa1882fc49c870c67728db2b94db18121` |
| `formal/Benitoite/Release/Refinement/ExternalObservation.lean` | `5c1bb2c56c05b9fe2b158c26589ae9451408dd2d257d2687c46440b08b2782cb` |
| 補助入力の上記全文 | `d57c75f05301d3c2f8b020b38e0c7a8cefb442d5e98dd232d87fdda70842be56` |

## レビュー申し送りの照合

| 出どころ | L30で受け持つもの | 既済み・後段へ分けるものと理由 |
|---|---|---|
| RV-L00b.05 軽2 | .25〜.30/.61。substitute内部の両項・途中述語のsort/Declaredと許される位置を検査する | 現行の構文等号の健全性は継承。現在のcheckSortedだけで意味上の等号が検査済みとはしない |
| 同 軽3、l00b.15 theorems の比較の行 | .08/.30/.74。rawな論理核の構造比較と核内のdecideによる再生 | 型/行の関数を含む全宣言表の計算可能性を一括で保証しない。R50は交換した有限の表と高い入口の証拠を照合 |
| 同 軽4 | .55〜.62。represented/measure_nonnegative/machine_exact/stableの実読者を置く。使わない補助は削除又は理由を記録 | external_adequate/received_valueの本番接続は既存。外部三条件の全モデルの充足はL60 |
| 同 軽6 | .32/.62。開いた非負とstableの含意の形を作る | 閉じたpの不変を開いたpへ拡張しない。旧stableの閉じた署名は保存する |
| RV-L00b.04 の鍵の等値 | .59〜.60。Key.equalのコード一致と同じ型の言語上の等値/大きさを結ぶ | 型クラスの任意のsatだけから観測可能性を主張しない。Rustの実表/鍵比較はL40/R40/R50へ |
| RV-L00b.14b と RV-L00b.14b-paths のapart | .33/.65。開いたBooleanの相異を有限規則から導き、仮定apartを実際に供給する | 比較結果の契約はL40。古いapartの前提だけを持つ例を接続完成と数えない |
| RV-L00b.14c のReference.updateの引数名 | .75で読者と入力を受渡しに残す | **L70/R10b/R50**へ。Fnの名前の一致とRustのlambdaの受理の比較であり、線形証明書の規則ではない。実行前の疑いのまま事実にしない |
| RV-L00b.14d のforceの共変性/格納と観測 | .56/.75。閉じた不変の値・snapshotの観測の論理を接続する | 保存とcloseValの一般葉はL20完了。実標準表の結果型の共変はL40、VMの評価途中・別タスク待機/取消の対応は**L70/R30/R50**。R20の探索の担当へ混ぜない |
| RV-L00b.14e、RV-L00b.15 軽6の節入力/結果/split/resume/used/解放 | .65/.75。入出力の論理と型域が保存される接点だけを受け持つ | L20群J/Lの一般葉を継承。実表の入力/応答/効果の意味はL40/L60、Rustの操作と解放はR30/R50。状態葉を再実装しない |
| RV-L00b.13 の篩付きPairを持つRequestのAt | .75で、修正済みgroundTyと未比較の入力を記録 | **L50/R30/R50**へ。型付き要求・Atの実行の一致であり論理の算術規則ではない。旧の不一致の疑いを未再現のまま残す |
| RV-L00b.15 軽5の短絡 | .65で真偽の有限な含意を構成する | **L70/R10b**が脱糖と同じ型/効果を接続。Refinement.Compに短絡の独立構文があるとは記さない |
| RV-L10.v/RV-L10 のsort反映 | .29/.56。Declaredだけに頼らず同じPのVarianceValidを使う | ソースからのmetadataの完全な収集はL70/R10b/R50 |
| RV-L20-plan/planのL20との並行 | L20の共有変更を取り込んだ基準を使う。今回のL30内でもS01を先に固定 | L20の未受入を隠して並行変更しない。別機で能動時間の合計が減るとはしない |
| L20群I/J/NのO046/O079/O138/O143 | .63〜.65で開いた長さとBooleanの証明書を供給 | 捕捉/パターン/guard/返値の一般葉は既済み。ソースの静的合成と実APIの契約はL40/L70/R10b/R50 |

太字の送り先は、以前L30と書かれた申し送りを内容に従って分ける提案である。取りまとめが元の担当表へ転記するまで、この下書きだけで担当が変更済みとは扱わない。比較の入力を消さず、その段の起動依頼へ写す。

R20向けには、正常化した式だけを検査の入力として信用しないこと、全参照の検査、固定幅と数学Intの一致、全処理の計上、候補モデルの実現確認、拒否理由の分離、版を渡す。現行Rustでは `typeck/interval/` は警告の解析であり、その上限と新しい含意判定のproof-stepsは別である。既存の `ResultBounds::Signed(i128)` 等を新しい係数幅の決定としない。runtime/map/keys.rs の同じ型の鍵比較と、Leanの正準コードの対応はR50の有限比較へ残す。


## 初稿: 分岐する判断と受渡し

J30-1（係数幅）、J30-3（詳細steps/版/後始末）、J30-4（計算量の契約）は設計者のU03の判断とする。J30-2（型域の事実と値の意味）、J30-5（下層とEntailsの接続・限定合同・宣言の実行範囲）は取りまとめの署名/方式の確認と独立レビューへ分け、既決の境界を越える変更なら設計者へ戻す。新公理・主定理の結論の弱化・提供範囲の削減・独立の利用者制限・精密な外部状態は提案していない。

この下書きの独立レビュー、planへの転記、必要な設計者の判断、実装起動は取りまとめへ残る。L40へはchecked_refinement、PreparedLeaf.entailsIn/bind_entailsと本番の観測/正常結果の署名、R20へは有限規則・固定幅/steps/拒否理由・版を渡す。現在、これらの本番実装の完了は主張しない。

## 初稿: 最後の静的照合

2026-11-03 05:29頃（+0900）にPythonの読取りによる照合を行い、全assertが成功した。単位IDの連続性と重複なし、群A〜L各6単位/M・N各4単位、見込み40/60/80時間、元planのL30担当27行との順序を含む一致、L20段末の15行との一致、O143を含む和集合31と共通4を確かめた。

両文書についてMarkdown表の列数、閉じたcode fence、全相対リンクの宛先、手元の絶対パスとdocs/todoへのリンクがないことを確認した。入力24ファイルの記録したhashを再照合し、本文の補助Lean入力（UTF-8/LF、末尾改行1個）も記録したhashと一致した。補助入力にsorry/独自axiom/native_decide/unsafeはない。規則数の算式は28/100/30/12/25で一致する。

大きくなったレビュー申し送りの照合をresults側へ分け、detailを100KB目安内に収めた。N群末と段末の独立レビューは同じ証拠を一回のレビューへまとめる計画である。この静的照合は担当の自己点検であり、独立レビューではない。

作業開始の時計は2026-11-03 04:38:37（+0900）、最後の機械的照合は05:29:44で、そこまでの外側の時間は約51分である。途中の読取り・推敲と待ちは分離しておらず、能動時間の確定値としていない。正式なRSSは未取得である。

## r1: RV-L30-planの所見への対応

2026-11-03。[planの2026-11-03の取りまとめの判断](../plan.md#計画の変更と取りまとめへの確認点)を最初に読み、[独立レビュー](../reviews/RV-L30-plan.md)、元の依頼、該当するLean/義務/台帳を照合した。以下が現在の下書きの値であり、上の「初稿」の80単位/40〜80時間は履歴として残す。

**79単位・14群、所要時間（能動時間）48時間55分〜95時間30分、中心72時間12分30秒（約72時間13分）**。各行の上下端は2,935分/5,730分で、中点は4,332.5分。.73を.38/.77へ統合し、残りのIDを保った。元枠の上端84時間を11時間30分超える。主な増分は帰納/置換、切替180〜300分、CaptureOkの再追随2時間30分〜5時間（各行の内数）である。

| 所見 | 処置 | 確認と残る条件 |
|---|---|---|
| 重1 | S01/第5/第10節とA.02/.51/.54を改訂。Ty.LeQとCaptureOkを通じて前提の判断の定義を変える採択済みJ30-2と明記 | Le.leanのassumptions/introduce/refine、Typing.leanのCaptureOk.mk、ValueMeaningを読んだ。主定理の言明の形は維持。全追随の成立はA.02/実装時に確認 |
| 中1 | A.03で∃c'再構成とνを持つcheckedAt/置換像上の健全性を比較。両案でEntails.bind不変 | keys衝突/新一致/加算像とsplitの形を通過条件へ。(ii)ならA末にD/Gの単位表を改訂。レビューの短い核の証明は全checkerの完成ではない |
| 中2 | 並置名Ty.assumeWithCarrier/Ctx.factsWithCarrier、切替.51を固定。.43〜.50は並置の補助、.52〜.54は切替後の読者 | 切替180〜300分を別掲。A.02で既定ビルドを保つ全追随の道筋を確認できなければH/Iを再詳細化 |
| 中3 | 重い単位の幅を広げ、全79行から加算。L20台帳は計画/実装/独立レビューを分離し全選択行を下表へ | 一律80×45分を廃止。同種の残りだけ通常resultsで更新し、L20との比を一律に掛けない |
| 中4 | 幅の表に計算域を追加。保存係数、u64の一時積、閉じたDecimalの桁合わせ/Float比較を区別 | 128bit推奨は正確な別の計算域が条件。64/128/256のすべてで32bit構成を記載。実装幅は未決 |
| 中5 | O046/O079/O138/O143は取りまとめがplanの担当欄へL30を追記する、と第7節に明記 | O056はL00b.14b-pathsとL20段末でLeanの担当分完了、L30の新残件なし。有限論理はO054/O138、全表層はL70で二重計上しない |
| 軽1 | S01のTy.assumeを現行と同じmatch形へ | Context.leanのOrdinary/assume/assume_eq_predicatesを照合。新しいDecidable instanceを仮定しない |
| 軽2 | checked算術の定義をInterval/Eval.lean、補題をInterval/Arithmetic.leanと分け「旧」を除去 | IntKind.checkedAdd/Sub/Mul/Negとnormal_iff/overflow_iffの所在を再確認 |
| 軽3 | 語/対象/除外/数え方を明記し在庫を再作成。CaptureOkの匿名.mkと全供給鎖も対象 | assume29ファイル141行、CaptureOk50ファイル220行。定義展開と広い候補の数は下表。行数を証明数と数えない |
| 軽4 | Certificateの既存読者0を第5節へ明記。.73を.38/.77へ統合 | formal全*.leanのimport/Certificate使用を検索。Certificate自身以外はformal/Benitoite.leanのimportのみ。定理の既定importを保つ |
| 軽5 | 現上端1,338.3時間が旧基準1,188.8時間を149.5時間超えることと、2026-10-31了承との関係を確認点へ | 段だけで自動停止とはしない。今回のL30上端更新を含め、取りまとめが相談条件を整理する |
| 軽6 | 既決で除外された案を外し、問いを基本操作の粒度/版の字面/後始末の予約の三点へ限定 | 各点に推奨と受理差を記載。群Lだけ回答後、他群は幅/計上契約を引数にして進める |
| 軽7 | .43のG依存を外しAの後へ。切替.51だけGを待つ | carrierFacts/並置factsは検査器を読まない。依存表でU03の非依存と段末の合流を区別 |
| 軽8 | 初稿「判明した点」3に、仮に意味上の等号でsnapshotを書き換える規則を加えた場合と明記 | 現行EqProof.soundの結論は構文等号t=u。現行の不健全性という主張をしない |

### r1 群と見込み

| 群 | 内容 | 単位数 | 所要時間（能動時間） |
|---|---|---:|---:|
| A | 方式と署名 | 6 | 3時間40分〜7時間15分 |
| B | 線形の項と鍵 | 6 | 2時間50分〜5時間40分 |
| C | 否定標準形 | 6 | 3時間5分〜6時間10分 |
| D | 整数導出と枝 | 6 | 3時間30分〜7時間 |
| E | EqProofと限定合同 | 6 | 3時間15分〜6時間30分 |
| F | 有限論理補題 | 6 | 3時間35分〜7時間10分 |
| G | 検査器とEntails | 6 | 4時間15分〜8時間30分 |
| H | 型域の並置と最初の補助 | 6 | 3時間30分〜6時間40分 |
| I | 判断/意味の切替と捕捉の追随 | 6 | 7時間15分〜13時間30分 |
| J | 本番観測と正常結果 | 6 | 3時間40分〜7時間15分 |
| K | PreparedLeafとL40 | 6 | 3時間40分〜7時間 |
| L | U03回答後の幅/steps契約 | 6 | 3時間〜6時間 |
| M | 再生/申し送り/義務 | 3 | 1時間35分〜2時間55分 |
| N | 段末監査と受入資料 | 4 | 2時間5分〜3時間55分 |

### r1 読者の在庫

対象は`formal/Benitoite/Release/Refinement/`以下のすべての`*.lean`。コメント・例・属性は除外しない。一致した物理行を一検索につき一度数え、複数の検索の和をユニーク行数としない。以下のrgの正規表現と同じ条件で全ファイルを再集計した。

```text
assume
\bCaptureOk\b
\b(simp|simpa|unfold|dsimp)\b[^\n]*(Ctx\.facts\b|Ty\.assume\b)
facts|assume
```

四検索は順に29ファイル141行、50ファイル220行、16ファイル25行、48ファイル485行。最後は未修飾の名前・複数行のsimp・factsを使う移送の候補も拾う広い在庫であり、定義を直接開く証明数ではない。全ファイルの和集合は82。初稿29/134は置き換える。レビューの31/46と同じ数になる検索条件は確認していないため、その数は転記せず、再現できた条件を採った。レビューで例示されたBind/PatternBindingSupport/PatternMatchAnnotations/PatternSemantics/TypeShiftOrderにもfacts/assumeの文字列を検索したが一致はなかった。これらの型付けの移送を除外する根拠にはせず、.51の既定ビルドと.54の全読者照合に含める。

次の表は語の一致の上位の宣言をファイルごとに示す。名前はそのファイルに書かれた宣言名であり、名前空間の補完前の表記を含む。CaptureOkの結論/入力/構成子の分解を区別せず列挙し、宣言本体を読んで、第5節の12直接構成と間接構成/事実供給へ分けた。匿名`.mk`も調べ、明示`CaptureOk.mk`の検索だけには依存しない。全141出現宣言は新たな証明141件を意味しない。以下の「展開」は上の第三検索の行番号である。

| R/からのファイル | assume一致行 | CaptureOk一致行 | facts/assume広い候補行 | CaptureOkの出現宣言／明示の定義展開 |
|---|---:|---:|---:|---|
| AtStateInputs.lean | 0 | 3 | 0 | `at_source`, `ClosureTy.at_inputs`, `AtCallAdmissible.closed_input` |
| BuilderStateLeaves.lean | 0 | 1 | 0 | `close_builder_operation` |
| CaptureApplicationAlgebra.lean | 0 | 6 | 1 | `CaptureOk.closed`, `CaptureOk.bindParams` |
| CaptureReadBoundary.lean | 0 | 5 | 0 | `unread_capture_ok`, `argument_typed`, `primitive_reads_hidden_capture` |
| CaptureRegularity.lean | 0 | 14 | 0 | `CaptureOk.contextRegular`, `capture_value_annotation`, `capture_comp_annotation`, `capture_failure_body_annotation`, `CaptureOk.continuation_annotation`, `CaptureOk.continuation_result_effect`, `capture_let_effect_annotations`, `capture_tel_annotation`, `capture_function_result_effect`, `HasFailureClause.capture_result_effect`, `e_handle_supply`, `split_fail_annotated` |
| CaptureTransport.lean | 0 | 9 | 4 | `CaptureOk.normConts`, `capture_normConts_value_annotation`, `capture_normConts_comp_annotation`, `CaptureOk.hideBuilders_hideConts`, `capture_value_annotation_via_normConts`, `capture_comp_annotation_via_normConts` |
| CapturedFacts.lean | 0 | 15 | 1 | `CaptureOk.evaluated_fact`, `CaptureOk.addEntailed`, `CaptureOk.addEvaluated`, `CaptureOk.close_entails`, `HasTypeTelArgsQ.captured_one`, `StateTyE.captured_beta_one`, `StateTy.captured_beta_one` |
| CloseApplication.lean | 0 | 3 | 0 | `HasTypeTelArgsQ.close_typed`, `HasTypeCQ.close_app_aux`, `HasTypeCQ.close_method_aux` |
| CloseTyping.lean | 0 | 10 | 0 | `close_dependent_lambda`, `close_lambda`, `CaptureOk.close_sat`, `close_value_aux`, `close_values_aux`, `close_each_aux`, `close_value_typed`, `close_values_typed`, `close_each_typed` |
| ClosedCapture.lean | 0 | 5 | 0 | `CaptureOk.close_annotations`, `HasTypeVQ.close_ground`, `HasTypeVsQ.close_ground`, `HasTypeEachQ.close_ground` |
| ClosureApply.lean | 0 | 5 | 0 | `TelBodyTy.capture_all`, `CaptureOk.mapReturn`, `ClosureTy.apply_all` |
| ClosureCallInputs.lean | 0 | 1 | 0 | `HasTypeCQ.fun_apply_all` |
| ClosureTyping.lean | 0 | 11 | 2 | `CaptureOk.substOk`, `CaptureOk.conditions`, `CaptureOk.transport`, `CaptureOk.wf`, `CaptureOk.declared`, `CaptureOk.wf_ordinary`, `CaptureOk.continuation_image_wf`, `ClosureTy.pure`, `ClosureTy.capture_resolved`, `ClosureTy.capture` |
| ClosureViewTyping.lean | 0 | 1 | 0 | `ClosureViewTy` |
| Context.lean | 14 | 0 | 15 | 展開 157,162,171 |
| Context/Capture.lean | 0 | 12 | 4 | `CaptureOk.extend`, `CaptureOk.extendHidden`, `CaptureOk.extendCont`, `CaptureOk.extendTel` |
| Context/Facts.lean | 14 | 1 | 30 | `CaptureOk.facts_extend`；展開 68 |
| ContextFacts.lean | 11 | 0 | 24 | 展開 19,26,115,118 |
| ContextMap.lean | 7 | 0 | 11 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| ContextNormEq.lean | 1 | 0 | 7 | 展開 92 |
| ContextTransport.lean | 0 | 3 | 0 | `CaptureOk.q_fixed` |
| ControlLeafSelection.lean | 0 | 1 | 0 | `other_control_for_model` |
| CoverageRefinement.lean | 2 | 2 | 8 | `CaptureOk.variable_coverage`；展開 249 |
| DependentBeta.lean | 1 | 6 | 4 | `ClosureTy.dependent_one`, `CaptureOk.hideConts_any`, `ClosureTy.closure_one` |
| ExternalStateLeaves.lean | 0 | 1 | 0 | `close_external` |
| FunctionViewGeneral.lean | 0 | 3 | 0 | `CaptureOk.termBind_success`, `HasTypeVQ.captured_observation` |
| HandlerCalls.lean | 0 | 0 | 1 | 展開 267 |
| HandlerContinuation.lean | 0 | 1 | 0 | `HandlerFrameTy` |
| HandlerFailure.lean | 0 | 1 | 0 | `ContTy.fail_input` |
| HandlerGeneral.lean | 0 | 6 | 3 | `capture_normal`, `operation_capture`, `close_resume_aux`, `close_escape_all` |
| HandlerStoreExamples.lean | 0 | 1 | 0 | `saved_typed` |
| HandlerTelescope.lean | 0 | 2 | 0 | `capture_tel` |
| HeldValues.lean | 2 | 0 | 3 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| HiddenCaptureBoundary.lean | 0 | 2 | 0 | `hidden_state_typed` |
| IntervalConnectionExamples.lean | 0 | 1 | 0 | `view_observation_model` |
| LazyPreservation.lean | 0 | 0 | 1 | 展開 236 |
| Le.lean | 13 | 0 | 13 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| LegacyHeldTyping.lean | 0 | 1 | 0 | `held_lambda` |
| LegacyStateTyping.lean | 0 | 7 | 0 | `legacy_pure_let`, `embedContTy`, `legacy_cont_closed`, `embedStateTyE` |
| LocalInvariant.lean | 0 | 3 | 0 | `Closure.LocalRefs`, `Frame.LocalRefs` |
| MatchPaths.lean | 1 | 10 | 3 | `ClosureTy.capture_resolved_closed`, `ClosureTy.open_zero`, `CaptureOk.addEvaluatedFacts`, `CaptureOk.paths_evaluate`, `HasTypeArmsQ.capture_plain`, `ClosureTy.match_source` |
| MatchStateExamples.lean | 0 | 0 | 1 | 展開 180 |
| MatchStateLeaves.lean | 0 | 15 | 6 | `CaptureOk.match_extend`, `CaptureOk.paths_wellFormed`, `CaptureOk.matched_facts`, `CaptureOk.excluded_facts`, `HasTypeArmsQ.capture_plain_success`, `HasTypeArmsQ.capture_guard_success` |
| MeaningTransport.lean | 2 | 0 | 38 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| MeaningTransportObstruction.lean | 0 | 0 | 2 | 展開 111 |
| MethodClosure.lean | 0 | 2 | 0 | `HasTypeCQ.method_apply_all` |
| Narrowing.lean | 1 | 0 | 28 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| NarrowingObstruction.lean | 0 | 0 | 3 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| NestedContinuation.lean | 0 | 2 | 0 | `CaptureOk.list_cont_empty` |
| NormalWellFormed.lean | 3 | 0 | 3 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| NormalizationLogic.lean | 8 | 0 | 8 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| OpenSubstitution.lean | 1 | 0 | 12 | 展開 80 |
| PathBasesLeaves.lean | 0 | 1 | 0 | `issue_source` |
| PathConditions.lean | 0 | 4 | 1 | `CaptureOk.boolCond_evaluates`, `ClosureTy.branch`, `Comp.isIte_resolve` |
| PathFacts.lean | 0 | 0 | 2 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| PatternBindingExamples.lean | 0 | 2 | 0 | `month_variable_coverage` |
| PatternMatchAnnotations.lean | 0 | 4 | 0 | `annotations_aux`, `annotations_list_aux`, `PatTy.bindings_annotation`, `AltsTy.bindings_annotation` |
| RangeFormation.lean | 1 | 0 | 1 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| RangeSubst.lean | 4 | 0 | 10 | 展開 163,185,193 |
| ReadLocalRefs.lean | 0 | 3 | 0 | `Val.LocalRefs`, `DependentClosureTy.localRefs`, `CaptureOk.localRefs` |
| ReferenceCalls.lean | 1 | 0 | 6 | 展開 354 |
| ReferencePreservation.lean | 0 | 2 | 0 | `ClosureTy.pure_return`, `pure_replace` |
| ReferenceStore.lean | 0 | 3 | 1 | `CaptureOk.reference_write_snapshot` |
| Shift.lean | 1 | 0 | 7 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| StateTyping.lean | 0 | 4 | 0 | `GuardBodyTy`, `ContTy` |
| SubstTyping.lean | 5 | 0 | 64 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| SubstTypingObstruction.lean | 1 | 0 | 11 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| SuperClosure.lean | 0 | 4 | 0 | `CaptureOk.closed_arguments`, `HasTypeVQ.super_dictionary` |
| Transport.lean | 11 | 0 | 26 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| TypeShiftContracts.lean | 4 | 0 | 9 | 展開 208 |
| TypeSubst.lean | 1 | 0 | 6 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| TypeSubstContracts.lean | 0 | 1 | 0 | `S02_Capture` |
| TypeSubstTyping.lean | 0 | 7 | 3 | `case_Capture_mk`, `case_Closure_mk`, `deriveCapture` |
| TypedCoverage.lean | 0 | 3 | 0 | `CaptureOk.typed_variable_coverage` |
| TypedFacts.lean | 16 | 0 | 18 | 展開 216,257 |
| TypedMeaning.lean | 0 | 0 | 2 | 展開 134,141 |
| TypedMeaningExamples.lean | 0 | 0 | 1 | 展開 25 |
| Typing.lean | 0 | 6 | 6 | `CaptureOk`, `DependentClosureTy`, `ClosureTy`, `CaptureOk.empty` |
| TypingShift.lean | 3 | 4 | 49 | `CaptureOk.store`, `DependentClosureTy.store`, `ClosureTy.store` |
| ValueFacts.lean | 10 | 0 | 24 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| ValueReferences.lean | 1 | 0 | 1 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |
| ValueRegularity.lean | 1 | 0 | 1 | assume/factsの供給・移送の候補（宣言はL30.01で分類） |

直接構成12宣言と間接構成/供給の全名はdetail第5節の表を正とする。`.mk`を明示する6一致行はContext/Capture.leanの3、ContextTransport.leanの1、TypeSubstTyping.leanの2（後者の一つはパターンの分解）である。TypeSubstTypingだけに6構成があるとは数えない。実際の直接構成12件は匿名構成を含めて分類した。CaptureOk.localRefs（ReadLocalRefs.lean）の`.mk`はCapture.LocalRefsを作り、CaptureOkを新しく作る箇所には数えない。

明示して定義を開く16ファイル25行の宣言名は次のとおりである。空文脈のfactsを開く箇所も変更不要を確認する対象として残す。

| R/からのファイル | 宣言名: 行番号 |
|---|---|
| Context/Facts.lean | `Ty.assume_wellFormed`: 68 |
| Context.lean | `Ty.assume_eq_predicates`: 157、`Ty.assume_ordinary`: 162、`Ty.assume_eq_nil`: 171 |
| ContextFacts.lean | `Ty.assume_shiftV`: 19、`Ctx.mem_facts`: 26、`Ctx.mem_facts_extendNone`: 115、`Ctx.mem_facts_extendNone`: 118 |
| ContextNormEq.lean | `Ctx.facts_map_norm`: 92 |
| CoverageRefinement.lean | `CaptureOk.variable_coverage`: 249 |
| HandlerCalls.lean | `ClosureTy.pure_operation`: 267 |
| LazyPreservation.lean | `pure_ret`: 236 |
| MatchStateExamples.lean | `reject_false_fact_to_tail`: 180 |
| MeaningTransportObstruction.lean | `ordinary_supply_counterexample`: 111 |
| OpenSubstitution.lean | `transport`: 80 |
| RangeSubst.lean | `Ty.assume_rawMapRanges`: 163、`Ctx.facts_mapRanges`: 185、`Ctx.facts_rawMapRanges`: 193 |
| ReferenceCalls.lean | `ClosureTy.pure_primitive`: 354 |
| TypeShiftContracts.lean | `Ty.assume_shiftTypes`: 208 |
| TypedFacts.lean | `HasTypeVQ.assume`: 216、`HasTypeVQ.assume_optional`: 257 |
| TypedMeaning.lean | `typed_meaning_aux`: 134、`typed_meaning_aux`: 141 |
| TypedMeaningExamples.lean | `typed_entries`: 25 |

### r1 台帳の選択行

元のeffort-ledger.mdの行番号と単位名を固定して示す。各「約」の外側の時間をそのまま分/秒に読み、計画・実装・独立レビュー・取りまとめの検査を混ぜない。累計トークンは時間の和に使わない。

| 分類 | 選択行数 | 外側の時間の和 | 単位名の選択条件 |
|---|---:|---:|---|
| 計画 | 4 | 約2時間59分 | L20-planで始まり担当Codex |
| 計画の独立レビュー | 4 | 約29分 | RV-L20-planで始まる |
| 実装とその再開/所見対応 | 44 | 約21時間54分 | L20 群 で始まり担当Codex、A1〜S。入口/停止/再開を含む |
| 実装の独立レビュー | 23 | 約3時間20分 | RV-L20.で始まる。初回/再レビューを含む |

取りまとめの群末/段末work、L20を説明欄でだけ挙げるL00b/L10の行は選ばない。レビューの40/26と母集団を同じと推定せず、以下の全行名によって再現可能にする。

| 分類 | 元の行番号: 単位名（外側の時間） |
|---|---|
| 計画 | 122: L20-plan（40分）、124: L20-plan 再開1（所見の対応）（46分）、126: L20-plan 再開2（kind の処置）（53分）、128: L20-plan 再開3（Declared の処置）（40分） |
| 計画レビュー | 123: RV-L20-plan（15分）、125: RV-L20-plan r1 の再レビュー（7分）、127: RV-L20-plan r2 の再確認（4分）、129: RV-L20-plan r3 の確認（3分） |
| 実装 | 130: L20 群 A1（.01〜.03）（13分）、132: L20 群 A1 再開1（所見の対応）（6分）、133: L20 群 A2（.04〜.07）（19分）、135: L20 群 A2 再開1（所見の対応）（7分）、136: L20 群 A3a（.08〜.13）（18分）、137: L20 群 A3a 再開1（承認後の完了）（16分）、139: L20 群 A3a 再開2（所見の対応）（14分）、140: L20 群 A3b（.14〜.19）（23分） |
| 実装 | 142: L20 群 A3b 再開1（所見の対応）（25分）、143: L20 群 A3b 再開2（sourceTelRows）（19分）、145: L20 群 A3c 入口（19分）、146: L20 群 A3c 再開1（本体）（40分）、148: L20 群 A3c 再開2（所見の対応）（18分）、149: L20 群 A4 初回（10分）、150: L20 群 A4 再開1（案A）（12分）、152: L20 群 A4 再開2（所見の対応）（14分） |
| 実装 | 153: L20 群 B・C（.28〜.38）（41分）、155: L20 群 B・C 再開1（所見の対応）（14分）、156: L20 群 D 初回（33分）、157: L20 群 D 再開1（55分）、159: L20 群 D 再開2（所見の対応）（9分）、160: L20 群 E（.61〜.70）（37分）、162: L20 群 E 再開1（所見の対応）（14分）、163: L20 群 F・G（.71〜.84）（90分） |
| 実装 | 165: L20 群 F・G 再開1（所見の対応）（11分）、166: L20 群 I（.89〜.96）（20分）、168: L20 群 I 再開1（所見の対応）（9分）、169: L20 群 J・K（.97〜.105）（140分）、171: L20 群 J・K 再開1（所見の対応）（20分）、173: L20 群 L・M（.106〜.114）（55分）、174: L20 群 L・M 再開1（案1の点検）（20分）、175: L20 群 L・M 再開2（範囲の確定と続き）（75分） |
| 実装 | 177: L20 群 L・M 再開3（軽い所見）（30分）、178: L20 群 N（.115〜.122）（60分）、180: L20 群 N 再開1（所見の対応）（13分）、181: L20 群 N 再開2（内部署名の変更と続き）（45分）、183: L20 群 N 再開3（再レビューの所見）（30分）、184: L20 群 O・P（.123〜.134）（75分）、186: L20 群 O・P 再開1（RV の軽1〜4）（8分）、189: L20 群 Q・R（.135〜.144）（39分） |
| 実装 | 191: L20 群 Q・R 再開1（RV の軽1〜3）（9分）、194: L20 群 S（.145〜.148）（17分）、195: L20 群 S 再開1（保持値の像と続き、段末資料）（48分）、197: L20 群 S 再開2（RV の軽1〜7）（24分） |
| 実装レビュー | 131: RV-L20.a1（5分）、134: RV-L20.a2（16分）、138: RV-L20.a3a（11分）、141: RV-L20.a3b（12分）、144: RV-L20.a3b r2 の再レビュー（4分）、147: RV-L20.a3c（18分）、151: RV-L20.a4（9分）、154: RV-L20.bc（11分） |
| 実装レビュー | 158: RV-L20.d（9分）、161: RV-L20.e（9分）、164: RV-L20.f（9分）、167: RV-L20.i（9分）、170: RV-L20.j（11分）、172: RV-L20.j 再レビュー（4分）、176: RV-L20.l（9分）、179: RV-L20.n（13分） |
| 実装レビュー | 182: RV-L20.n 再レビュー（4分）、185: RV-L20.o（10分）、187: RV-L20.o 再レビュー（1分30秒）、190: RV-L20.q（8分）、192: RV-L20.q 再レビュー（1分）、196: RV-L20.s（群 S と段末）（13分）、198: RV-L20.s 再レビュー（再開2）（3分30秒） |

### r1 最初の同種16件

旧Ty.Leから新判断への46規則の移植はL20で済んだ。L30に同じ移植を増やさない。採択済みS01の新しいfactsへの追随を同種群とし、次の16読者の新名版を.44〜.48で準備し、.51で本番の呼び手を切り替える。

1. Ty.assume_norm
2. Ty.assume_refined
3. Ty.assume_shiftV
4. Ctx.mem_facts
5. Ctx.mem_facts_extend
6. Ctx.mem_facts_extendNone
7. Ty.assume_bind
8. Transport.assumptions
9. Ty.assume_of_norm_eq
10. Ctx.facts_map_norm
11. Ctx.NormEq.facts
12. Ty.LeQ.assume
13. NormalWellFormed の Ty.assume_of_wf の後継
14. NormalizationLogic の Ty.entails_assume_iff_predicates の後継
15. ContextMap の Ctx.TypeMap.norm
16. ContextMap の Ctx.TypeMap.facts

ContextMap.TypeMap.norm/factsは、定義を変更せず証明がそのまま通る可能性もある。その場合は変更不要の根拠を通常の結果へ記録し、移植の実績の件数へ入れない。16を合わせるためだけの包装を作らない。これらは論理のfactsの移送という同じ仕事であり、Semanticな33場合や、検査器の帰納の単価にはしない。

.48では新名の補助の完了件数と未切替を区別する。.51の通常の結果で本番へ切り替えた件数・外側の時間・待ちを記録し、分離できる場合だけ `一件当たり能動時間 = 能動時間 / 実際の完了件数` を残りの同種読者へ適用する。分離できなければ能動時間は未取得として旧見込みを保つ。残るTypedFacts/ValueFacts/MeaningTransport等と、変更が不要な読者とCaptureOk全構成の照合を.49〜.54/.74〜.76に残す。測定専用の実装・元へ戻す移植・専用の計測単位を置かない。

### r1 S06 本番の観測の接続の署名

.55/.56の新補題の完全署名の案を示す。最後は.62が実際に使う既存の署名であり、同じ入口の包装を新設しない。

```lean
theorem measure_machine_exact {m : Measure} {o : Observation} {n : Int}
    (h : Observation.measure m o = some (.integer n))
    (η : ObservationEnvModel) (t : Term) (ht : t.observe η = some o) :
    (Term.measure m t).observe η = some (.integer n) ∧
    (Term.measure m t).interpret η = some (.integer n) ∧ 0 ≤ n

theorem measure_stable {m : Measure} {t : Term} {n : Int}
    (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (h : (Term.measure m t).observe η = some (.integer n)) :
    (Term.measure m (termBind ν t)).observe ξ = some (.integer n)

-- 既存 ExternalObservation.lean。
theorem HasTypeVQ.represented {P B Ψ Q C Φ v a s}
    (h : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.carrier.HasSort s) :
    ∃ t, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed
```

measure_stableのhiは既存の型付き観測の交換から供給し、主定理の新しい信頼条件にはしない。上のmeasure二署名は補助Leanで証明を確認した。本番への実装は未実施である。Keyの接続は閉じたKeyShapeと同じ型の二値を前提とする。.59/.60で成功11形/対象外3形の署名を具体化し、抽象satだけでこの入力を作らない。

### r1 実装時の検査の割当

以下は**実装時の計画**である。今回の下書きで既定ビルドやworkを実行したという意味ではない。全実装単位は、必要な `formal/Benitoite.lean` の既定importと、`docs/design/01-spec/01-12-core-calculus.md` の規則の写し、`docs/design/07-quality/07-04-formal-semantics.md` の内外の対応も同じ変更でそろえる。実装前の内容を現行設計へ先に書かない。

| 検査/担当と時期 | 実際の中身・コマンド | 基準/保存と見込み |
|---|---|---|
| L・各単位の途中 | formalから `lake env lean -M 12288 <関係ファイル>`。型域/NNF/証明書/鍵/本番葉の当該部分だけ | 入力の完全署名、終了、外側の時間を群resultsへ。単一ファイルの成功を既定全体の代わりにしない |
| W・各受渡し末、群内は最後に一度 | 根から `scripts/check.sh --level work --base <当該B_WORK> --dry-run` で選択を確認し、同じ引数のdry-runなしを一度実行。既定全Lean・sorry拒否、変更した仕様のtext例の読者を含める | 最初は指定の `5122e4085e269a113903842571a96f3a07c484f7`、次の群から直前の取り込みの完全ID。LeanだけへRust全libを追加しない。群resultsへ |
| A-L・N.78 | 既定モジュールをimportする当該段のaxioms入力で `#print axioms`。formalから `lake env lean -M 12288 <段内の監査入力への相対パス>` | 新旧主定理、変更した意味の定義、全新葉、private/生成定数。完全名の一覧/生成手順/生出力/件数を保存。許可はpropext/Quot.sound/Classical.choiceのみ。1〜5分は旧案で、今回の実測は未取得 |
| 再生と証明・M.74 | 同じ有限証明書をrawcheckで評価し、同じ等式を `by decide` 等でカーネルが検査する | 評価値/終了と、定理の公理依存を分ける。native_decide/unsafe等を証明の代用にしない。実行時間は待ちとして記録 |
| 群末の独立レビュー・取りまとめ | A〜Nの各群について定義・言明・仮定・供給元・全場合と残りを確認。修正の影響範囲だけ再確認 | 14群。Nは段末レビューと合同。待ちは不明。所見処置の担当の能動時間は各単位の内数。レビュー記録を担当が作った自己点検で代用しない |
| 最後のWと正式RSS・取りまとめ | .78の同じ最後のworkへsandbox外でRSS採取を付ける。レビュー後に本番を直した場合は最後の変更後へ差替え | 本体/計測器の終了、機械/OS/方法/原単位を別に保存。非採取の単位は「未取得（計画上の非採取）」。計測だけの追加ビルドなし |
| 段末の独立レビュー・.79 | 35義務、全有限規則、S01/S03、L40/R20実署名、U03回答、主定理/実表/交換の残りを照合 | 不明。所見への応答と影響検査を保存し、取りまとめがplanへ転記 |
| 受け入れ・設計者 | .80の段別判定と未完の担当、U03とJ30の決定を確認 | 不明。L20段末の並行受け入れも別に扱う |

Rust検査・性能測定・全比較をL30へ前倒ししない。F-REGはL70、F-CONNはR50。R20は明示スタック、pipelineの実測スタックのテスト、stack_probe、最適化した深い再帰（release_stack）10件を詳細化する。

結果は共通依頼文の全欄で記録し、引用には関係状態の一致の根拠を付ける。本番テストを加える担当はtest-auditの作成時の関門を適用する。

### r1 設計者へ問う点と確認の範囲

係数幅は128bitを推すが未決である。閉じたDecimalの桁合わせとu64の一時積を保存係数と同じ固定幅では計算しないことを条件とし、保存できない結果のunknownは残す。基本操作はbyte/節点/辺/要素/固定幅演算を実際に一回ずつ、版の字面はproof-steps-v1、後始末は生成時の個別予約を推す。粒度/予約/保存幅は受理に影響し、版の字面だけなら受理差はない。J30-4はこの三点と実作業との対応へ集約し、既決と違う別の上限を問わない。群Lだけ回答後に置く。

義務の集合は初稿と同じ、27行+段末15行（12重複）+O143で31、共通4を含め35。31の分類は証明27・契約3・計画1。O046/O079/O138/O143の4行は取りまとめによる担当追記が必要。O056は照合の対象として一行を増やしたが、L30の新残件0として35へ追加しない。控除12項目と規則数28/20/7/9/2/10/12schema100分岐/16sortは変更しない。

r1では本番を実装せず、Lean/Rust/既定ビルド/work/性能測定を新たに実行していない。レビューの補助Leanのコード・主張を読んだことと、こちらでの再実行を区別する。A.03の両案の全体、S01全追随、切替の成立とPreparedLeafの開いた合成は未確認のままである。下の文書検査は起動時のLean検査の代わりにはしない。

### r1 文書の検査

単位表79行のID/7列/所要/検査欄、14群の上下端の和、.43〜.54の分類、planの27行とL20段末の15行の集合、和集合31+共通4、所見14件、相対リンク/見出し、コード囲み、制御文字、現行本文に初稿の80単位/134行等が残らないことを照合した。これら313判定は全て成功。別にMarkdownの全34表（detail 23/results 11）の列の数を照合して不整合0だった。後述の検算の入力と識別表を追記した後も再確認し、成功した。

主要な数の検算は、リポジトリの根から次のPythonで再現できる。実装/Leanの健全性の検査ではない。

```python
from pathlib import Path
import re
root = Path("docs/2026-10-30-TODO-022_290_294_303_308_309_315_317-refinement-types")
text = (root / "l30/detail.md").read_text()
rows = {}
for line in text.splitlines():
    m = re.match(r"\| L30\.(\d+)/([A-N]) \|", line)
    if m:
        cells = [c.strip() for c in line.strip("|").split("|")]
        assert len(cells) == 7
        n = int(m[1])
        assert n not in rows
        lo, hi = map(int, re.match(r"(\d+)〜(\d+)分", cells[-1]).groups())
        rows[n] = (m[2], lo, hi)
assert set(rows) == set(range(1, 81)) - {73}
assert set(g for g, _, _ in rows.values()) == set("ABCDEFGHIJKLMN")
assert sum(lo for _, lo, _ in rows.values()) == 2935
assert sum(hi for _, _, hi in rows.values()) == 5730
for g in "ABCDEFGHIJKLMN":
    same = [(lo, hi) for grp, lo, hi in rows.values() if grp == g]
    print(g, len(same), sum(x for x, _ in same), sum(y for _, y in same))
```

r1で照合した主な入力のSHA-256を以下に残す。初稿の入力の識別表とは時点を分ける。パスは改造からの相対であり、手元の絶対パスを根拠にしない。

| 入力 | SHA-256 |
|---|---|
| plan.md | `bd4cc6c780a2476518054a2bd77ffc5facad913c6bae424d424683d806302edf` |
| reviews/RV-L30-plan.md | `dc37f0f1fa0bc2fa34b0e1c0c0a14895515d8f6a3cb8ba578611b3bd0951db76` |
| effort-ledger.md | `143aee86fa08b194626f4052ac7a2779ddbe03b8523243caf9e3ef014b1eba71` |
| l20/stage-results.md | `28b7ce0ad51e2af0bcf90b0366b90c87c8322043abbb53cc69a73c5d9216fdd7` |
| l30/detail.md | `19d06bc95dff26d6e0d88552296d8895e64dfafd4f650fe86e657f934ad9f318` |

編集はl30/detail.mdとl30/results.mdに限った。Git操作、本番ソース/処理系/設計/plan/レビュー記録の変更は行っていない。r1の独立再レビュー、U03の設計者の回答、取りまとめの転記と見込みの整理は未実施である。
