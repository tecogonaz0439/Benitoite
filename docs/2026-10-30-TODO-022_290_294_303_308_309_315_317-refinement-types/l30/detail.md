# L30: 論理と証明書の起動単位（下書き）

2026-11-03、r1。実装、独立レビュー、設計者の受け入れを表さない。[共通依頼文](../implementation-request.md)、[plan](../plan.md)、[decisions](../decisions.md)、[README](../README.md)を引き継ぐ。取りまとめが本書の条件付きの署名を確認し、独立レビューと必要な判断を得て plan へ転記してから起動する。

指定ブランチは `m014/l30-plan`、B_WORK は `5122e4085e269a113903842571a96f3a07c484f7` である。依頼で受領した値である。`R/`は`formal/Benitoite/Release/Refinement/`、旧`Release/`は`formal/Benitoite/Release/`を指す。Lean宣言は特記しない限り `Benitoite.Release.Refinement` の名前空間にある。

**79単位・14群**の案である。所要時間（能動時間）は第11節の個別積上げによる。30〜60分を基本とし、帰納・切替・捕捉の再照合は別の幅を置く。J30-2はplanの2026-11-03の判断によりD02・D21の範囲として採択済みである。主定理の前提に入る判断の定義を変える内容を含む。A群で方式と署名を確認してから依存群を起動する。U03の回答を待つのは群Lだけである。

## 1. 入口の点検と既済み分の控除

### 前提の状態

| 前提 | 読んで確かめた状態 | L30 の扱い |
|---|---|---|
| L10 の全 sort・measure・宣言・正規形 | [sort 対応16行](../l10/f/sort-correspondence.md)、`R/ScopeSyntax.lean` の Sort/Measure、`R/Context.lean` の HasSort/Sorted、`R/Declared.lean` の FieldRef.Declared | 定義を引き継ぐ。WF、sort、宣言照合、Source、観測の成功を別に検査する |
| L20 の必要補題 | [段末](../l20/stage-results.md)と各群の結果。四関門、型置換14成分76場合、型付き意味33場合、全46旧規則の埋め込みを担当分完了としている | 最後の段末 work は終了0。段末資料冒頭の古い「転記・再レビュー未実施」より、末尾の取りまとめによる転記と再レビュー可の記録を優先する。設計者の受け入れは依頼どおり並行中であり、完了したとは記さない |
| 共有定義の固定 | StoreOk の Sorted、kind を持つ C、rowKinds、SourceScoped、保持値の像の変更が取り込み済みの基準として渡された | L20 と共有定義を同時編集しない。再開があれば新基準を受ける。L40 は L20 と L30 の両方を待つ |
| D06 の規則レビュー | 方式 C は採択済み。`l00b.05/signatures.md`「L30へ固定する全規則の義務」は残件である | 本書第3節がレビュー用の案。方式の採択と各追加規則の健全性の証明を区別する |
| U03 | 幅・詳細な計上規則・版・計算量の制約は未決 | 第4節の比較を設計者へ示す。i128 を採用済みにしない |
| U08/U01/U09 | decisions 末尾と README の2026-10-30の回答で A/A/A・E に確定 | Nat/WFを維持。独立の深さ・枝数・入力長・証明書量の上限を追加しない。設定の選択の実装は R70 |
| L30 と R20 | Lean の検査・正規化・有限規則は内側。探索の完全性と CPU/OS 時間の上限は外側 | R20 の遅延 DNF/FM/探索順序の実装を L30 で作らない。steps の定義と有限比較の入力は渡す |

### 控除する既済みの12項目

控除は同じ証明の再実装を予定しない意味である。項目別の配賦がないので控除時間は作らず、追随と本番読者への適用だけを計上する。

| 番号 | 既済みの本番ファイルと宣言 | 控除する内容／残り |
|---|---|---|
| C01 | `R/Logic.lean`: Entails の18構成子、weaken/cut | or_elim/not_intro/not_elim/not_not_elim を追加し直さない。開いた Boolean の相異と算術への接続は残る |
| C02 | `R/LogicSound.lean`: Entails.sound、`R/Basic.lean`: Entails.bind/shiftV | 既存18場合の健全性と置換は済み。新しい checked の1場合だけを同じ四つの帰納へ足す案とする |
| C03 | `R/ClosedEvaluation.lean`: evalWith/evalClosed と健全性、`R/ExternalCheck.lean`: Pred.closedTrue_entails | 強い Kleene の三値、閉性・sort・some true の検査は済み。NNF の二値モデルの論理と混同しない |
| C04 | `R/RefinementNormalForm.lean` と `R/Normalize.lean`: predicates_norm、norm_refined_truth、norm_idem、型・行・依存列の正規化 | D07 の平坦化と true 消去、構造等号は済み。L30 の論理の否定標準形と線形式の正規化だけを作る |
| C05 | `R/NormalizationLogic.lean`: conjuncts/of_conjuncts/assume_of_norm_eq、`R/ContextNormEq.lean`: NormEq と facts/sortMap/annotation/comp | 正規形の等しい文脈の橋は済み。暗黙の事実を足す場合の等号の維持だけを点検する |
| C06 | `R/Certificate.lean`: EqProof の4構成子、check/sound/checkSorted_sound | 構文等号の4場合は済み。意味上の整数等号と限定合同、途中の sort の検査は残る |
| C07 | 同上: Certificate の6構成子、check/sound/checkSorted_sound | use/leaf/substitute/consume/cases/discard の現行の健全性は済み。枝内の導出列・NNF・丸め・整数分枝は未実装 |
| C08 | 同上: Observation.measure_nonnegative、PreparedLeaf.entails/machine_exact/stable | 全7 measure の正常結果の非負と閉じた葉の代表は済み。開いた葉、実際の正常結果、置換後の対応は残る |
| C09 | `R/ExternalObservation.lean`: HasTypeVQ.closed_observation/represented、ConstOK.represented | 閉じた型付き値の toTerm? と数値の既存値域の証拠は済み。Map/Set の鍵の言語上の等値の一般の一致は未証明 |
| C10 | `R/CloseTyping.lean`、`R/TypeValueExchange.lean`、`R/TypedMeaning.lean` の close_value_typed、型/行/値の交換、typed_value_meaning_closed | 全置換・closeVal の相互証明を作り直さない。新しい葉へ実際に適用し、必要な追随だけを行う |
| C11 | `R/PatternBindings.lean` の pattern_length_relation、`R/CoverageRefinement.lean` の length_refinement_coverage/nonempty_from_entails、`R/TypedCoverage.lean` の捕捉の入口 | パターン束縛と閉じた非空の葉は済み。len(l)=n と n>0 からの開いた含意の証明書は L30、ソースからの静的な合成は L70/R10b |
| C12 | `R/HandlerGeneral.lean` 等と `R/StepLeafSelection.lean` 等の状態の葉、`formal/Benitoite/Interval/Eval.lean` の IntKind.checkedAdd/checkedSub/checkedMul/checkedNeg と `Interval/Arithmetic.lean` の checkedAdd_normal_iff/overflow_iff・checkedNeg_normal_iff 等 | L20 の handler/resume/used/解放/ストア/継続の葉、七整数の既存の正常算術を再証明しない。論理の入力・出力の契約と、Stop を成功へ写さない接続だけを扱う |

状態の76行はL20段末表を正とし、再証明の件数に加えない。旧側へ篩の新規則を遡って適用しない。

### 入口で判明した不足

1. `Ty.assume` は通常型について `refinementPredicates` だけである。`Ctx.facts [some (.base .integer8)] = []` なので、127以下という入力型の事実を現在の Entails から取り出せない。補助 Lean で、同じ文脈の `Entails … (x ≤ 127)` の否定を、x=1000 のモデルと Entails.sound から証明した。型付けの誤りや設計者の決定の変更を意味せず、暗黙の型域を論理へ写す接続が未実装という意味である。
2. `EqProof.sound` の結論は `t = u` であり、`checkSorted` は substitute の内部で呼ばれない（RV-L00b.05 軽2）。意味上の整数等号から任意の snapshot の位置へ置き換える規則は不健全になりうる。観測のない変数と整数0は integerAs では等しいが、Set の snapshot の鍵にすると大きさが0と1になる例を補助 Lean で確かめた。許される置換位置を列挙する必要がある。
3. Term/Pred の DecidableEq は Classical.propDecidable である。構成的な構造比較を新しい検査器に使い、その一致を証明する。旧 instance の一括置換と、外部検査器の全域の実行可能化は行わない。
4. `ValueMeaning` は現在、数値の不適格な生定数を形の近似として含める（ValueShapeMeaning.const、TypedMeaning.const_meaning）。型域の事実を assume へ加えるなら、値の意味からその事実を供給する箇所も直す必要がある。J30-2 の独立した項目とし、単に assume の定義だけを変えない。

## 2. 定義と完全署名を固定する順序

以下は新規宣言の**形の案**である。短いLeanで確認した命題はresultsに限る。A群で完全署名・import・bindを確かめ、公開署名の変更が要れば取りまとめへ返す。

### S01: 型と論理を結ぶ有限の事実

採択したS01は `refinementPredicates` を明示した篩の正規化用の列として保ち、別の `carrierFacts` を assume へ加える。型の構造等号を論理同値へ変えない。contの除外を保つ。

```lean
-- 配置案: R/Context.lean 又はその直前の新モジュール。J30-2 は採択済み。
def Ty.carrierFacts : Ty → List Pred
-- a.core の整数七幅と Byte: lower ≤ self, self ≤ upper の2項。
-- Decimal: decimalRepresented self の1項。
-- その他: []。長さの非負は型域でなく普遍的な measure の規則で導く。
-- refined は芯の facts、型変数は空。関数/Reference/資源を観測しない。
def Ty.assume (a : Ty) : List Pred :=
  match a.core with
  | .cont _ _ _ => []
  | _ => a.carrierFacts ++ a.refinementPredicates

theorem Ty.carrierFacts_norm (a : Ty) : a.norm.carrierFacts = a.carrierFacts
theorem Ty.carrierFacts_bind (a : Ty) (θ : SubstEnv) :
  ∀ p ∈ a.carrierFacts, predBind (upValues θ.values) p ∈ (a.bind θ).carrierFacts
-- 旧 assume_eq_predicates / assume_of_wf の等号はこの形へ改める。
theorem Ty.assume_eq_carrier_append {a : Ty} (h : a.Ordinary) :
  a.assume = a.carrierFacts ++ a.refinementPredicates
```

ValueMeaning.mk は、現在の二条件に「`∀ p ∈ a.carrierFacts, p.interpret (selfModel η v) = true`」を加える形を候補とする。ValueShapeMeaning の23構成子は増やさない。`TypedMeaning.const_meaning` は `Const.NumericRepresented c` を入力とし、実際の V_Const では既存 `ConstOK.represented` から供給する。Const.NumericRepresented の定義の配置だけを Syntax の後へ下げ、TypedFacts への逆向きの import を作らない。この変更はCtx.factsを通じてTy.LeQ.introduce/refine（V_Sub・C_Subの前提）とCaptureOk.mkの事実の欄へ入る。主定理が量化する型付けの判断と状態の不変条件の定義を変える。typed_value_meaning_closed、valueMeaning_sub、close_value_typed、主要十移送と主定理の言明の形（量化の形と結論）は保つ。型域の事実のためだけに CoreAssumptions に欄を追加しない。

並置名は `Ty.assumeWithCarrier : Ty → List Pred` と `Ctx.factsWithCarrier : Ctx → List Pred` とする。前者は上のmatch、後者は現行Ctx.factsと同じzipIdx/flatMapで前者を読む。L30.43〜.50では旧Ty.assume/Ctx.factsを保ち、新名の補題と意味の供給を準備する。ValueMeaningの変更案と全読者の修正箇所もここで確定するが、定義の切替はしない。**L30.51が切替の単位（180〜300分）**である。Ty.assume/Ctx.facts、ValueMeaning.mk/const_meaningと影響する全読者をまとめて変更し、既定ビルドを通して渡す。並置名は互換な略記へ寄せ、二つの判断を提供し続けない。.52〜.54は切替後の意味・捕捉・全読者の照合である。A.02でこの名前・切替単位・群末のビルド成功を確認できなければ、H/Iを起動せず再詳細化する。L20で閉じたCaptureOkの構成を開き直す分は第11節に含める。

### S02: 論理の下に置く算術と証明書

型付けと Entails を import しない層に、線形式・NNF・検査の構文と意味を置く。既存 Pred に arithmetic という構成子を加える案は採らず、既存の add/scale/le/And/Or/Not で表す。これにより Pred の14場合を読む全ファイルの帰納を増やさずに済む。

```lean
structure Linear where
  coefficients : List Int
  bound : Int
def Linear.eval (l : Linear) (ρ : Nat → Int) : Int
def Linear.Holds (l : Linear) (ρ : Nat → Int) : Prop := l.eval ρ ≤ l.bound
def Linear.toPred (keys : List Term) (l : Linear) : Pred
-- Σ coefficient[i] * keys[i] ≤ bound。長さ不一致は検査が拒否。

inductive NNF where
  | truth | falsity
  | linear (constraint : Linear)
  | literal (atom : Pred) (negative : Bool)
  | and (left right : NNF)
  | or (left right : NNF)
def NNF.toPred (keys : List Term) : NNF → Pred
def normalize (keys : List Term) (p : Pred) (negative : Bool) : Option NNF
-- 外から NNF/normalizationTrace を信用しない。keys の正しさも再計算する。
theorem normalize_sound {keys p negative q} (h : normalize keys p negative = some q) :
  ∀ η : ObservationEnvModel,
    (q.toPred keys).interpret η = (if negative then !(p.interpret η) else p.interpret η)

inductive LinearStep where
  | combine (terms : List (Nat × Int)) (expected : Linear)
  | round (source : Nat) (divisor : Int) (expected : Linear)
inductive Refutation where
  | consume (next : Refutation)
  | cases (left right : Refutation)
  | derive (step : LinearStep) (next : Refutation)
  | closeLinear (index : Nat)
  | closeAtom (positive negative : Nat)
  | split (key : Nat) (cut : Int) (left right : Refutation)
  | discardTodo (next : Refutation)
  | discardFact (index : Nat) (next : Refutation)
  | builtin (leaf : PreparedLeaf) (next : Refutation)
-- branch は todo、既に取り込んだ線形/符号付き原子の列、固定した keys を持つ。
-- 子は現在の列だけを受け、枝の結果の列を兄弟へ渡さない。
def refute (keys : List Term) (todo : List NNF) (facts : List NNF) : Refutation → Bool
theorem refute_sound {keys todo facts c} (h : refute keys todo facts c = true) :
  ∀ η : ObservationEnvModel,
    (∀ q ∈ todo ++ facts, (q.toPred keys).interpret η = true) → False
def check (premise goal : Pred) (c : Certificate) : Bool
-- Certificateの純粋な検査をpremise.conjunctsから呼ぶ。
-- refuteの入口はpremise ∧ not goalを内部でnormalizeし、初期factsを空にする。
theorem check_sound {premise goal c} (h : check premise goal c = true) :
  ∀ η : ObservationEnvModel,
    (.and premise (.not goal)).interpret η ≠ true
theorem implication_sound {premise goal c} (h : check premise goal c = true) :
  ∀ η : ObservationEnvModel, premise.interpret η = true → goal.interpret η = true
-- A.03の案(i)だけで採用する署名。案(ii)では置換像上の健全性へ置き換える。
theorem check_bind {premise goal c} (h : check premise goal c = true) (ν : ObservationEnv) :
  ∃ c', check (predBind ν premise) (predBind ν goal) c' = true
```

このブロックの PreparedLeaf/Certificate/EqProof は、現行 Certificate.lean から純粋な有限データの定義だけを下層へ移したものを指す。PreparedLeaf の定義の形は S05、Certificate の7構成子は第3節の表を正とする。宣言順は Linear/NNF→EqProof→BuiltinLemma/PreparedLeaf→Refutation→Certificate とし、証明済みの Entails や型付けを下層へ import しない。`Certificate.check` は生の Φ を受ける現行の名前を保ち、上の `check` は一つの premise へまとめる接続用の入口である。型/宣言の検査は上層の checkIn に置く。下層でも成立する有限の恒等式以外を、上層のsort検査が通るという理由だけで受理しない。

keysは有限の項列で、型付き入口だけがSource/HasSort/Declaredを要求する。符号化Linear.toPredのbind等号は補助Leanで確認したが、再線形化の鍵の照合・係数の位置まで保存する証拠ではない。A.03では次の二案を比較する。どちらもEntails.bindの公開署名を変えない。

| 案 | 固定し、代表で証明するもの | 通過の判定と後続への条件 |
|---|---|---|
| (i) ∃c'を再構成 | 鍵を先に照合するか構造を先に分解するか、像の衝突/新しい一致の処理、splitの対象を線形式へ一般化する形 | 二鍵の同じ像、非鍵の像との一致、var 0→add(var 1,var 2)を含む代表についてcheck_bindを証明。単なるkeys.mapでは通過しない |
| (ii) νを持つcheckedAt | 下のimplication_sound_atを各検査規則の帰納で直接証明し、bindはpredBind_compで合成 | 整数add/scale、snapshot、原子の正負、閉じたB01の代表を置換像上で証明。(i)のcheck_bindを要求しない。採用時はA末にD/Gの.19/.21〜.24/.37〜.40の署名・手順・見込みを改め、取りまとめが確認してから起動 |

```lean
-- 案(ii)の下層の署名の形。元の健全性からの意味の置換だけでは導かない。
theorem implication_sound_at {p q c} (h : check p q c = true) :
  ∀ (ν : ObservationEnv) (η : ObservationEnvModel),
    (predBind ν p).interpret η = true → (predBind ν q).interpret η = true
-- Logic.leanに追加する一構成子の代案
| checkedAt {Ξ p q c} (ν : ObservationEnv) :
    check p q c = true → Entails Ξ (predBind ν p) → Entails Ξ (predBind ν q)
```

案(ii)の整数射影の核とpredBind_compの適用は[独立レビュー](../reviews/RV-L30-plan.md)の補助Leanで確認されている。全有限規則の成立は未確認である。snapshotのslotのobserveと整数位置のinterpretは一般に交換しないので、置換前の健全性から任意の置換後の健全性を推論しない。案(i)のsplitの形も未確定であり、下のkey:NatはA.03前の候補に留める。

### S03: 構文による含意への接続

追加するEntailsの構成子を一つにまとめる。以下はA.03の案(i)であり、案(ii)ならcheckedAtと恒等置換からのchecked導出に替える。下層の健全性とbindを先に証明し、Entailsの帰納は一度だけ直す。以下の `check` は S02 の有限な検査関数だけを指す。

```lean
-- Logic.lean の追加構成子の形。任意の Prop/意味上の含意は欄にしない。
| checked {Ξ premise goal c} :
    check premise goal c = true → Entails Ξ premise → Entails Ξ goal

-- 下層で各有限規則とその bind を証明した後に、既存の署名を保つ。
theorem Entails.bind {Ξ p} (h : Entails Ξ p) (ν : ObservationEnv) :
  Entails (Ξ.map (predBind ν)) (predBind ν p)
theorem Certificate.refutation_entails {Φ goal c}
    (h : check (Pred.ofConjuncts Φ) goal c = true) : Entails Φ goal
```

weaken/cutは子へ帰納仮定を当てる。(i)のsound/bindはimplication_sound/check_bind、(ii)はimplication_sound_at/predBind_compを使う。直接の四帰納へ各1場合を足す。証明書の正しさをAssumptionsへ追加せず、意味上の全包含からEntailsを得る完全性も仮定しない。

### S04: EqProof と途中の適格性

構文等号の入口を残し、意味上の整数等号を別の mode で読む。**数の等号から field/measure/snapshot の任意の位置へ合同を適用しない。**

```lean
inductive EqualityMode where
  | structural
  | integer
-- EqProof は第3節の10構成子。hyp は現在の枝の整数 eq だけを参照。
def EqProof.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (s : «Sort») (mode : EqualityMode)
    (t u : Term) (c : EqProof) : Bool
-- structural は検証した別名の展開後の構造一致。
-- integer は integerAs の等値。field/measure は structural の子だけを受ける。
def RewritePosition (p : Pred) (mode : EqualityMode) : Prop
-- integer は eq/le/lt の add/neg/scale の下の位置のみ。
-- structural は同じ有限の構文の再構成。snapshot内のNoneを値で埋めない。
theorem EqProof.integer_sound {P C Γ Φ t u c}
    (h : EqProof.checkIn P C Γ Φ .integer .integer t u c = true) :
  ∀ η : ObservationEnvModel, (∀ p ∈ Φ, p.interpret η = true) → integerAs η t = integerAs η u
```

同じ番号や文字列を「同じ対象」と信用しない。別名の証拠は、有限の置換の列を順に展開した同じ項であることを検査する。ソースの `let y=x` をこの有限の像へ写す仕事は L70/R10b、捕捉後の一致の葉は L30 の担当とする。dataの意味上の等値だけから全欄の合同を導かない。FieldRef.Declared、同じ P の VarianceValid、型引数/欄番号/名目型を入口で照合する。

### S05: PreparedLeaf と L40 への受渡し

```lean
-- raw の葉は有限データだけを持つ。証明済み Prop や任意の論理含意を欄にしない。
structure PreparedLeaf where
  predicate : Pred
  lemma : BuiltinLemma
  arguments : List Term
  references : List Nat
-- BuiltinLemma の12種類は第3節。型域の上下限はΓのfactsから読む。
def PreparedLeaf.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (l : PreparedLeaf) : Bool
theorem PreparedLeaf.entailsIn {P C Γ Φ l}
    (h : l.checkIn P C Γ Φ = true) : Entails (Γ.facts ++ Φ) l.predicate
theorem PreparedLeaf.bind_entails {P C Γ Φ l}
    (h : l.checkIn P C Γ Φ = true) (ν : ObservationEnv) :
    Entails ((Γ.facts ++ Φ).map (predBind ν)) (predBind ν l.predicate)

theorem checked_refinement {P Γ Φ a b p q c}
    (hab : Ty.LeQ P Γ Φ a b)
    (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
    (hc : check (Pred.ofConjuncts (p :: assumptions Γ Φ a)) q c = true) :
    Ty.LeQ P Γ Φ (.refined a p) (.refined b q)
```

stable の一般化は「置換後も導出と観測が対応する」であり、開いた `predBind ν p = p` という等号ではない。型・行・範囲の像を含む本番の適用は、上の Entails.bind と既存 Ty.LeQ.bind/Transport を合成する。葉の検査を通すために Transport の事実を独立に仮定するのでなく、SubstOk/CaptureOk から既存の入口で供給する。

machine_exact は、`Observation.measure m o = some (.integer n)`、`Observation.compare`、`Interval.IntKind.checkedAdd/Sub/Mul` 等の**本番の定義**を分解して導く。正常結果のときだけ同じ値と toTerm? の成功を返す。任意の抽象 B の delta の算術を、型の保存条件だけから同定することはできない。L40 へは、上の本番演算の補題と、具体の署名/実引数/正常応答をそれへ結ぶ入口を渡す。B.delta と演算定義の一致の証拠を主定理の新しい信頼条件へ加えない。標準本体の呼出しとの合成は L40、σ/対象は L50、三モデル全欄は L60、Rust との有限比較は R50 に残す。

represented は既存 HasTypeVQ.represented と ConstOK.represented を実際に呼ぶ。Map/Set は、sat の真だけから keyCode? の成功を仮定しない。有限の閉じた鍵の構造と、実際の鍵の制約の表から成功を構成する。未観測の鍵を持つ既存の型付き Map（L20 群Iの unknown の例）は残し、正常な measure の葉を持つ入力と、観測できず葉を構成できない入力を区別する。全型付き Map が必ず観測可能という結論にしない。

### S06: 本番の観測の接続の署名

measure_machine_exact/measure_stableと既存HasTypeVQ.representedの完全署名・前提の供給元は[resultsのS06](results.md#r1-s06-本番の観測の接続の署名)に置く。.55/.56で実装し.62が使う。補助Leanの確認済みの範囲を保ち、Keyは.59/.60で具体化する。

## 3. D06 の規則レビューと場合の対応

ここでの数は構成子又は検査の分岐の数であり、無限に多い整数・文字列・利用者宣言の実例の個数ではない。提案の構成子数と現行数を区別する。表の `sound` は第2節の帰納に接続する補題で、単位表で作る場所を指定する。

### 否定標準形28場合と線形化20場合

| Pred の場合 | 正/負の数学上の意味と検査の規則 | 場合数 | 補題／単位 |
|---|---|---:|---|
| truth/falsity | true/false とその否定を交換 | 4 | normalize_sound の定数枝／.13 |
| eq | a=b は a-b≤0 と b-a≤0。否定は a-b≤-1 又は b-a≤-1 | 2 | normalize_integer_eq／.14 |
| le | a≤b は a-b≤0。否定は b-a≤-1 | 2 | normalize_integer_le／.14 |
| lt | a<b は a-b≤-1。否定は b-a≤0 | 2 | normalize_integer_lt／.14 |
| compare/floatClass/decimalRepresented/charactersIn/member/constructorIs | 各原子とその符号を保持する。Float の not lt を ge に書き換えず、未解決の対象所属も false に変えない | 12 | normalize_literal、6原子×2／.15〜.16 |
| and/or | 同じ極性の再帰と De Morgan。DNF 全列の事前生成はしない | 4 | normalize_boolean／.17 |
| not | 極性だけ反転して子へ再帰 | 2 | normalize_not／.17 |
| 合計 | Pred14構成子×2極性 | **28** | .18 で全件合成、.19 で bind |

線形化は Term20構成子を漏らさず検査する。整数定数・add・neg・scale の4場合は線形式へ写す。型付き入口ではvar・field・measureの3場合をinteger sort/Declaredと照合し、残るcharacter/float64/float32/decimal/boolean/unitValue/string/listValue/bytesValue/mapValue/setValue/dataValue/targetValueの13場合を整数式として拒否する。下層では検査したkeysのintegerAs射影を原子にできる。任意の置換でvarがBooleanやsnapshotへ写る場合は、A.03の案(i)の再構成又は案(ii)の置換像上の帰納で扱う。型付き入口の受理は広げない。下層でも13形を一律に拒否すると、無条件のEntails.bindを保てるとは限らないので、A.03で先に確認する。内部の閉じた値を measure の受け手にすることは別の入口で許し、Source の measure 入れ子禁止を内部 snapshot の禁止と取り違えない。`linearize_sound` の20場合を .09〜.12、鍵の照合の規則を .07〜.08 が受け持つ。

### 証明書と線形の導出

| 構成子・規則 | 数学上の意味／実際に検査するもの | 現行との差・補題 | 単位 |
|---|---|---|---|
| Certificate.use | 現在の仮定の index が goal と一致 | 現行1場合を引継ぎ。lookup_sound | .38 |
| Certificate.leaf | 有限の登録表と同じ結論で、各補題の検査に成功 | 現行の閉じた形から PreparedLeaf.entailsIn へ | .38/.61〜.66 |
| Certificate.substitute | EqProof と許された置換位置、両項と途中述語の sort/Declared を全部検査 | 現行は構文等号だけ。substitute_sound | .25〜.30 |
| Certificate.consume | 先頭の And を二つに分け、同じ枝へ渡す | 現行済み。新層への接続 | .38 |
| Certificate.cases | Or の両枝で同じ結論が導ける | 現行済み。片枝の成功だけでは受理しない | .38 |
| Certificate.discard | 一つの仮定を使わずに証明する | 現行済み。weaken による健全性 | .38 |
| Certificate.refute（追加） | 検査器が作った premise ∧ not goal の反証 | Refutation の健全性→S03。Certificate は6→7構成子 | .39〜.42 |
| Refutation.consume | truth を捨てる／falsity なら閉じる／linear 又は符号付き原子を facts の末尾へ移す／And をtodoへ分解 | NNF6形を分け、Or はこの規則で読まない。consume_sound | .21 |
| Refutation.cases | todo先頭のOrの左右を別々の枝で反証 | 元のfactsを共有し、枝固有の追記を兄弟へ出さない。cases_sound | .21 |
| Refutation.derive | 既知の事実から新しい線形不等式を導く | LinearStepの2場合。derive_sound | .22〜.23 |
| Refutation.closeLinear | 全係数0かつ bound<0 の先行する事実を検査 | 0≤負数の矛盾。close_linear_sound | .24 |
| Refutation.closeAtom | 同じ原子の正負が現在のfactsにある | 論理的矛盾。部分評価のnoneを否定しない。close_atom_sound | .24 |
| Refutation.split | 整数の鍵xについて x≤cut 又は cut+1≤x の全被覆 | 二つの証明書を両方検査。split_sound | .23 |
| Refutation.discardTodo | 未処理の条件を落とした、より弱い前提でも矛盾する | discard_todo_sound。無関係な≠を展開せず捨てる | .24 |
| Refutation.discardFact | 一つの既知事実を使わずに続ける | discard_fact_sound。削除後の index の規則を固定 | .24 |
| Refutation.builtin | B01〜B12の有限な論理補題を検査して枝へ追記する | builtin_sound。型域を無条件の補題として追記しない | .31〜.36/.39 |
| LinearStep.combine | Σ kᵢ·事実ᵢ、全 kᵢ≥0。係数と定数の和が expected と一致 | 空和/一項/複数項、負の乗数の拒否。combination_sound | .20/.22 |
| LinearStep.round | d>0、元の各係数=d×出力係数、出力bound=floor(元bound/d) | 係数を勝手に丸めない。負のboundも下方丸め。round_sound | .23 |

現行の Certificate6、提案の Certificate7、Refutation9、LinearStep2 を別に数える。Refutation の9構成子の帰納は一回で、todo/facts/keys を一般化する。derive の2場合と consume 内の NNF6形はその補助の場合であり、重ねて合計しない。

R20のroundは言語の整数除算（零への切捨て）と別である。正のdで負の剰余が残れば商を1減らし、−3/2→−2を照合する。

参照は枝内の先行する列に対する Nat とする。外部の番号→内部 index の変換は R20 で検査付きとする。兄弟・将来・循環・範囲外・sort違いの5種類と、期待式改竄・未知key・宣言不一致・負の乗数・非正除数・不正な丸め・片枝欠落の7種類、計12種類の拒否を .39/.30/.66/.71 で担当する。discardFact は削除後の列を子へ渡し、その列についてだけ参照を解決する。旧 index を黙って生き残らせない。

### EqProof10構成子と限定合同

| 規則 | modeと条件 | 意味の根拠 | 単位 |
|---|---|---|---|
| refl/symm/trans/add | 既存4。integer の add は整数射影、structural は構造の合同 | 既存 EqProof.sound を残し、mode別の補題で一般化 | .25/.28 |
| neg/scale | integer。係数は数学Intで、Rustでは固定幅へ収まることを検査 | 等式に負号又は同じ定数倍を適用 | .26 |
| hyp | 現在の枝の整数eqだけ | Φの事実から整数射影の等値を得る | .26 |
| alias | 有限の束縛の展開が同じ構文へ到達することを確認。先行参照のみ | sourceの名前の一致だけでは受理しない。捕捉の同じ像への一致 | .27 |
| field | structural の子、同じ宣言・constructor・型引数・欄番号・result sort | FieldRef.Declaredと既存観測の射影。同じPのVarianceValidを使う | .27/.29 |
| measure | structural の子、同じmeasure。7種全部 | 同じ受け手の同じ部分観測。成功とnoneの両方を保つ | .28/.29 |

integer の書換え位置は eq/le/lt の両辺と、その add/neg/scale の下に限る。structural の一致は全20項形の再構成へ使えるが、alias の同定を任意の意味上の等値から作らない。Boolean の相異は次の B04 で導く。Float の数としての等値をビットの同一性へ読み替えず、NaNへの反射則や、±0の分類を壊す置換を足さない。

### 登録済みの論理補題12種類と本番の事実の出どころ

| ID・BuiltinLemma の種類 | 数学上の意味・有限検査の分岐 | 出どころ／受け持つ単位 |
|---|---|---|
| B01 closed | 現行同様、閉性・sort・evalClosed=some true | 下層はPred.evalClosed_sound、上層はPred.closedTrue_entails／.31 |
| B02 lengthNonnegative | 旧の閉じたList長の代表を保つ。B03への接続を付ける | 現行の検査成功の保存／.31 |
| B03 measureNonnegative | 正常なmeasure結果は非負。モデルの失敗時の整数0も非負。7measure | Observation.measure_nonnegative を使い、単にsome trueを仮定しない／.32 |
| B04 booleanApart | 同じBoolean項がtrueとfalseの両方に等しいことはない。向き2場合 | Observation.compare/fromEqLt の実定義／.33 |
| B05 compareComplement | eq/neは7scalar sortの両向き14場合。順序の反転はCharacter/Decimalのlt/le/gt/geの8場合だけ | 計22場合。Floatの順序はNaNで全順序にならないので同じ規則へ入れない／.34 |
| B06 charactersSubset | lo'≤loかつhi≤hi'なら charactersIn(s,lo,hi)→charactersIn(s,lo',hi') | 同じStringの全ての文字の条件。一般正規表現を足さない／.35 |
| B07 constructorApart | 異なるconstructorを同じdata観測が同時に持たない | constructorIs の同じ受け手と異なる名を検査／.35 |
| B08 sameObservation | 検査したstructuralの同じ像を使う原子の一致。sort対応16行 | 論理を強める無条件のUF規則にしない。field/measureを含むS04との接続／.29/.36 |
| B09 scalarOrder | Character/Decimal/Float32/64の4sort×eq対称/eq推移/lt推移/le推移/lt-le/le-ltの6則=24。Boolean/String/Unitの3sort×eq対称/推移=6。計30分岐 | Floatは成功する比較を前提とする含意だけで、NaNへの反射則は足さない。異なる端点との関係を閉じた比較と合成／.33〜.34 |
| B10 characterCodeRange | 0≤code≤0x10ffff、code<0xd800又は0xdfff<code。1分岐 | 本番Charの範囲をObservation.measureから導く。一般のビット列理論ではない／.35 |
| B11 characterCompare | Characterの6比較とcharacterCodeの整数比較の対応。6分岐 | 同じ文字の符号の射影で比較を整数の含意へ接続／.35 |
| B12 floatCompareClass | 2幅×6分類の12分岐。NaNは他項との順序比較/eqを否定、±Infinityは有限の他項より外、±0は数の等号とfinite、finiteはNaN/±Infinityを除外 | 各分類について同じ幅の比較との有限の節を作り、分類の排他/全被覆も本番bitsから導く。有限端点の間ならfiniteという含意を構成し、非線形算術を足さない／.34/.36 |

原案のB01〜B08の展開51分岐にB09〜B12の49分岐を加え、**12種類・100分岐**（1+1+7+2+22+1+1+16+30+1+6+12）とする。B09〜B12は異なる端点の値域を比較・分類へ結ぶために必要であり、原子の符号を保持するだけで全値域の接続が済むとはしない。文字端点等の実例数は数えていない。B05以外の一般の scalar 比較は原子の構文で保持しB09/B12の有限の節で関係を補う。閉じた値の検査と本番の比較結果の対応は全 **30**（Character/Decimal/Float64/Float32各6、Boolean/String/Unit各2）を .34 で示す。Float分類は2幅×6分類=12場合である。

Jの本番接続では、整数七幅の加減算/乗算21組と符号付き四幅の負号4組の正常/あふれを区別する（定数倍は既存乗算の特殊化）。Byteは値域と明示変換の対象であり、七整数の算術へ暗黙変換しない。鍵の観測はObservation14構成子のうち成功しうる11形と対象外3形を区分し、再帰するlist/map/set/dataとDecimalの正規化を .59〜.60 に割り当てる。一般のビット列理論や非線形の自動判定をこの場合表へ加えない。

次の事実は普遍的な論理補題と区別する。登録番号を発行しただけで真にしない。

| 事実の群 | 出どころと完成の条件 | L30 と後段の境界 |
|---|---|---|
| 七整数/Byteの上下限 | carrierFacts の8型×2端点=16項。ConstOK/Integer64Value/ConstOK.representedから型付きの実値で満たすことを証明 | .43〜.48/.57。任意Intへ機械幅を仮定しない。実δの正常結果の型付けはL40 |
| Decimalの表現可能性 | 係数96bitsの範囲とscale≤28。carrierFactsの1項、ConstOKの本番の条件 | .45/.58。Decimalの四則算と丸めを線形整数の無制限な演算にしない |
| String二長/Bytes長/List長 | 本番Observation.measureの7種のうち該当4種。文字数とバイト数を別々に同定 | .55/.57。map/reverse/append/filterの標準本体の関係はL40 |
| Map/Setの大きさと鍵 | mapKeys/keySetCodes、Key.normalizeMap_length/normalizeSet_length、型付き閉じた鍵の有限の構造 | .59〜.60。後の値を保つMap、数としてのDecimalの鍵の等値を照合。実標準表の契約はL40/R40/R50 |
| 不変欄と別名 | FieldRef.Declared、constructor_field_inputs/con_field_by_type、close_value_typed、観測と置換の既存交換 | .27/.29/.62。セル現内容・Reference・関数・資源を読む規則を足さない |
| 対象所属 | member/SnapshotMemをそのまま原子として読み、同じ対象/同じsnapshotの一致だけを使う | .16/.62。異なる起点の被覆・具体化と全有効σの意味はL50、実行の一致はR30/R50 |
| 正常算術とStop | 既存のcheckedAdd/Sub/Mul、負号・比較の実定義、正常結果の表現可能性 | .57/.64、L40 H03/H04へ。中間Stopを後の演算で取り消さない。非線形の自動判定は追加しない |

Fの比較/分類はfraction/exponentの共通補題を一度証明して二幅へ使い、同じ帰納を二度書かない。Jの鍵も11成功形の構造の帰納をMap/Setで共有する。

### 健全性と探索の不完全性

証明の順は、線形化とNNFの意味の保存→combine/round/split/discard→refute_sound→check_sound→implication_sound→Entails.checked の sound/bind→PreparedLeaf→checked_refinement である。machine_exact/stable/represented の三条件は S05/S06 と本番の観測/型付き値の補題から各事実を構成し、PreparedLeaf の raw データに未検査の条件として保持しない。

refute_sound は「与えた有限証明書の検査がtrue」を前提とする。check_sound/implication_sound/checked_refinement も検査成功だけを前提にし、「探索が必ず証明書を返す」「全整数モデルを列挙した」「長さが機械整数幅で有界」を前提にしない。候補の整数割当だけで長さやMapの実値を作れるとは主張しない。反証候補の出力はR20/R60で元の値に実現できた場合だけ反例と呼び、未実現の候補は未証明のままとする。

## 4. U03: 係数幅、steps、入力検査の案

### 係数幅の判断 J30-1

保存する線形式の係数・定数の幅と、一時の積・閉じた値の比較の計算域を分ける。以下はこの分離を前提とした三案である。数学の規則はLean.Intのまま置く。Rustの32bit構成でも同じ結果にする。

| 案 | 固定幅を使う計算と数学上の意味 | R20への影響 | 利用者の受理への影響 |
|---|---|---|---|
| A: 符号付き64bit | 保存係数/定数は−2^63〜2^63−1。係数積の一時値は別の正確な計算域 | 一積は128bit相当で計算しても保存時に64bit検査が要る。32bit構成も含む | u64最大値すら保存できず、単純な値域の契約でも表現外unknownが増える |
| B: 符号付き128bit（推奨、未決） | 保存係数/定数は−2^127〜2^127−1。u64端点/96bit Decimal係数の単体は入る。u64大の二係数の積は約2^128で、保存域には入らない場合がある | 一積は256bit相当等で正確に計算し、合成/正規化後の保存時に表現を検査。min/−1、読取り、加算/負号/除算も照合。32bit構成で同じ意味を保つ | 大きい端点を使えるが、一回のFM消去でも表現外になりうる。幅を広げても完全性は保証しない |
| C: 固定256bit | 保存係数/定数は−2^255〜2^255−1。一積は別の512bit相当等で扱う | 固定語列の算術・比較・除算の実装/証明が増える。32bit構成を保つ | Bより広いが表現外は残る。同じstepsの探索到達範囲も変わる |

**閉じた比較は三案とも係数幅に入れない**。`R/Observation.lean`のObservation.compareのDecimal枝はc×10^tとd×10^sを比べる。最大近傍の96bit係数とscale 28の桁合わせは約2^189であり、128bitでは足りない。B01/B09等はこの比較を別の正確な計算で行う。Floatのビット比較も線形係数へ丸めず、現行の正確な意味を保つ。一時のu64の積も保存幅と同じ幅では計算しない。ただし正確に計算した結果を線形係数へ保存できなければunknownである。u64の本番演算のあふれは従来どおりStopであり、この一時域で成功へ変えない。

推奨Bの条件は、この計算域の分離をL30.72のR20契約へ明記することである。別の正確な計算の実装と計上はR20で照合し、無料の算術にはしない。幅を引数にした数学の対応は回答前に進められる。設計者はD44/R70の実スクリプトの測定を見て決めてもよい。公開幅と群Lは回答を待つ。

```lean
def CoefficientRepresented (bits : Nat) (n : Int) : Prop :=
  0 < bits ∧ -(2^(bits-1) : Int) ≤ n ∧ n < (2^(bits-1) : Int)
-- 保存域と一時の計算域は別の引数。checked成功の像=数学Intの結果を示す。
```

### 詳細計上と版 J30-3・計算量の契約 J30-4

D43の全実作業を一回ずつ数える方式と、U08の独立上限を加えない決定を引き継ぐ。規則適用だけを数える案、処理段階ごとに独立上限を置く案は選択肢に戻さない。設計者へ問う詳細は次の三点に絞る。

| 問う点 | 比較と推奨 | R20への影響 | 実用への影響（受理の差） |
|---|---|---|---|
| 基本操作の粒度 | **byte読取り/比較は一byte、構造は一節点/辺/要素、固定幅算術は一演算**を推す。一節点に可変長の文字列比較等を隠す粒度とは比較を分ける | 入力/clone/正規化/探索/証明書生成/独立検査/後始末の各ループに計上を対応させる。幅の異なる一時算術も明記 | 同じ100,000で到達する証明が変わり、unknownになるプログラムが変わる。型・エフェクトの規則は変わらない |
| 版の字面 | 有限規則と計上の双方を識別する**`proof-steps-v1`**を候補として推す。字面と既存設定との対応は設計者が確定する。公開の契約として字面を固定するのは、U05 の版番号と同じく R/K の接続の前である | 出力/設定/証明書の版をL30.72で一致させる。無版の意味変更をしない | 字面だけなら受理差なし。同じ値を旧P2と同じ計上と解釈しない移行案内が要る |
| 後始末の予約 | **生存要素を作る時に必要な解放の操作を内部予約し、実際の破棄時に一度だけusedへ移す**方式を推す。個別予約と、所有単位ごとの上界をまとめる方式を比較し、対応が小さい個別予約を第一候補にする | used+reserved≤limitを維持。予約と実消費を二重計上せず、rollback/共有handle/所有本体に対応。利用者の別上限は作らない | 予約の上界によって同じ上限でも早くunknownになる場合がある。まとめた過大予約は受理をさらに減らしうる |

J30-4はこの粒度・予約に沿った実作業との対応を確定する項目であり、別の計算量保証を選ぶ問いを増やさない。入力I/証明書Cの走査も同じstepsに含め、展開後の仕事Pを隠さずO(I+C+P)の実作業を対応させる。証明書byte数だけのO(I+C)、CPU/OS/allocatorの時間上限は保証しない。prefix共有と明示スタックで枝全体の暗黙cloneを避ける。

入力走査、可変長の名前比較、係数merge、DNF/FMの候補生成、反例候補の実現確認、証明書の書込み、最終検査と破棄まで計上する。malformed/coefficientRepresentation/stepsExhaustedを区別し、入力検査の途中で尽きた入力をprovedにしない。独立の深さ/枝数/証明書量のunknown、無検査usize cast、将来/兄弟/循環参照は加えない。群Lだけが上の回答に依存する。

## 5. 最初の群 A と、変更が波及する箇所

A 群は方式を先に確認する6単位である。いずれも確認用に捨てる実装を作るのでなく、採用した定義・補題・反例を本番の読者が使う形に置く。採択済みのJ30-2と未決のU03を区別する。独立レビューの指摘を取り込んだ案であり、A 群の成功を前提に後の群を同時起動しない。

| 関門 | 最初に確かめるもの | 通過の判定 | 下書き時点の状態 |
|---|---|---|---|
| A1・型域と意味（A.02） | 採択済みS01とCaptureOkの全構成。並置名Ty.assumeWithCarrier/Ctx.factsWithCarrier、切替L30.51 | 型付き値から事実を構成し、全読者を切替時に直して既定ビルドを通す道筋を固定。主定理の言明（量化の形と結論）を変える必要があれば停止。前提の判断の定義の変更はJ30-2の内容 | 欠けは補助Leanで確定。新しい全構成と切替の成立は未確認 |
| A2・帰納とbind（A.03） | S02の(i)∃c'と(ii)checkedAtを比較 | (i)鍵照合/splitの形と三代表を証明、又は(ii)ν上の各規則の健全性の帰納を固定し代表を証明。Entails.bindの公開署名を保つ。(ii)ならA末にD/G表を改訂 | 符号化bindとレビューの整数射影の核のみ確認。両案の全体は未確認 |
| A3・整数 | 除数正・全係数の整除・負の床・二分の被覆 | 2*x=1、bound=−3/d=2、cutの左右、片枝欠落を同じ規則で説明 | 床除算の一般の含意、−3/2=−2、整数分枝、2*x≠1を補助Leanで確認 |
| A4・合同 | mode、RewritePosition、別名の有限展開、FieldRef.DeclaredとVarianceValid | 型付きの不変欄/measureと捕捉で同じ像を得る。数の等号をSetの鍵へ書換える反例を拒否 | 反例の各観測値は補助Leanで確認。別名と全16sortの橋は未確認 |
| A5・葉の受渡し | S05。開いたlen(l)=n、n>0とL40のrefine | 証明書からEntails→同じTy.LeQ→既存bindへ接続。PreparedLeafの欄に未検査の意味の仮定を持たせない | 既存のL20の閉じた葉は確認。開いた証明書の合成は未確認 |

短い試行は [results](results.md) に入力全文と結果を保存した。補助入力だけの成功を既定ビルド、全規則の実装、A 群の通過として扱わない。

### 既存定義の変更と波及の件数

| 変更案 | 理由 | 確認した波及の範囲と担当 |
|---|---|---|
| Entails.checked の追加、純粋な検査器の定義をLogicより下へ移す | 既存18規則だけでは開いた線形/Booleanの新しい含意を導けない | 構成子18→19。直接の帰納4か所に各1場合。HasType相互14判断76場合に新構成子を足す変更ではない。.37〜.42。(i)/(ii)のどちらでも既存の四読者を閉じられなければ、前提を強めず停止 |
| Ty.carrierFacts/Ty.assume/Ctx.facts、Ty.LeQ.introduce/refine、CaptureOk.mk | D02/D21の値域を判断へ接続する採択済み変更 | assume検索29ファイル141行、CaptureOk検索50ファイル220行、明示の定義展開16ファイル25行。下表とresultsに全在庫。前提の判断の定義が変わる。.43〜.54で追随 |
| ValueMeaning.mk のcarrierFactsの条件とconst_meaningの入力 | assumeの追加だけでは、現在の広い形の近似から型域を供給できない | ValueMeaningの構成子数1、ValueShapeMeaning23、値/値列/同型列の相互33場合は維持。TypedMeaningのV_Constとmkの再構成、MeaningTransport/CoverageRefinement/PatternNormalForm/TypedCoverage/各具体例を追随。.49〜.54。公開valueMeaning_sub等の言明を変える必要があれば停止 |
| Certificate のデータの下層への移動、refute追加 | Logicに逆向きのimportを作らず有限検査を埋め込む | 6→7構成子。R/Certificate.lean外の本番読者は**0ファイル**、既定formal/Benitoite.leanのimportだけ。旧6場合の成功保存と既定importの維持は.38/.77へ統合し、独立の.73を削除する。 |
| EqProof、PreparedLeaf、checkIn | 開いた合同と中間sortの検査、閉じたstableの一般化が必要 | EqProof4→10、BuiltinLemma2→12。旧check/soundの構文等号の入口は保つ。新checkInとentailsInを別に固定し、既存の閉じたstableを偽の等号に変更しない。.25〜.36/.61〜.66 |
| 構造比較 | ClassicalなDecidableEqのままでは核内のdecideで検査を再生できない | Term20/Pred14の明示的なbool比較と一致の証明。既存instanceの全面変更0。typedな宣言準備とrawな論理核の実行範囲を区分し、Ty/Effの関数を含む全表が計算可能になったとは言わない。.08/.30/.74 |

J30-2はplanの2026-11-03の判断で採択済みである。Ty.LeQを通じて受理する導出が増え、CaptureOkの事実の欄を強める。主定理の言明の形を保ち、Integer8→Integer8{self≤127}等を可能にする。以下をL30.01の在庫に含め、.51で追随し、.54で各構成の事実の欄を照合する。

| 読者の種類 | ファイルと宣言（R/を省略） | 完了の照合 |
|---|---|---|
| 捕捉を直接構成する12宣言 | Typing: CaptureOk.empty、Context/Capture: extend/extendHidden/extendCont、ContextTransport: CaptureOk.q_fixed、TypeSubstTyping: case_Capture_mk、CaptureTransport: CaptureOk.normConts、CapturedFacts: CaptureOk.addEntailed、ClosureApply: CaptureOk.mapReturn、DependentBeta: CaptureOk.hideConts_any、HandlerGeneral: capture_normal、TypingShift: CaptureOk.store | 明示CaptureOk.mkだけでなく匿名.mkも含む。新Γ.factsをHasTypeVQ.assume/移送/既存証拠のどれから作るか記録 |
| 間接に構成する読者 | Context/Capture: extendTel、CaptureApplicationAlgebra: bindParams、CapturedFacts: addEvaluated、MatchPaths: addEvaluatedFacts/paths_evaluate、MatchStateLeaves: match_extend/matched_facts/excluded_facts、CaptureTransport: hideBuilders_hideConts、SuperClosure: closed_arguments、TypeSubstTyping: deriveCapture、CaptureReadBoundary: unread_capture_ok、ReferenceStore: reference_write_snapshot、ほかに capture_tel・primitive_reads_hidden_capture・HasTypeArmsQ.capture_plain・capture_plain_success（所在は results の在庫） | paths_evaluateは事実の証明を供給し、addEvaluatedFactsが捕捉を構成する。この鎖と状態葉の呼出しを照合 |
| 定義を開く証明 | Context/Facts: Ty.assume_wellFormed、Context: assume_eq_predicates/assume_ordinary/assume_eq_nil、ContextFacts: assume_shiftV/mem_facts/mem_facts_extendNone、ContextNormEq: facts_map_norm、RangeSubst: assume_rawMapRanges/facts_mapRanges/facts_rawMapRanges、TypeShiftContracts: assume_shiftTypes、TypedFacts: HasTypeVQ.assume/assume_optional、ほかresultsの16ファイル表 | simp/simpa/unfold/dsimpでTy.assume/Ctx.factsを開く行を全件処分。空文脈で不変の証明も理由付きで保持 |

検索はR/以下の全*.lean、コメント/例/属性を除外せず一致した物理行を一度数える。`assume`、`\bCaptureOk\b`、`\b(simp|simpa|unfold|dsimp)\b[^\n]*(Ctx\.facts\b|Ty\.assume\b)`を別集計する。未修飾/複数行の展開の見落としを避けるため`facts|assume`全48ファイル485行も候補にし、宣言全体を確認する。50ファイルのCaptureOk出現宣言、定義展開の行番号、検索の再現条件は[resultsのr1在庫](results.md#r1-読者の在庫)に置く。ファイル/一致行の数を変更補題の数としない。

### 最初の同種16件の本番追随

既存Ty.assumeのnorm/refined/shiftV/bindと、Ctx.mem_facts/extend/extendNone、Transport.assumptions、正規形/文脈の橋、Ty.LeQ.assume等の**16読者**を最初に選ぶ。[全宣言名と記録方法](results.md#r1-最初の同種16件)を引く。.44〜.48で新名の補助を準備し、.51で本番を切り替える。通常resultsの所要から同種の残りだけを更新し、変更不要な読者を移植の実績に含めない。測定だけの単位は置かない。

## 6. 起動単位と群

未作成のファイルは配置案であり、名前を既存の宣言として引用しない。各単位の署名欄の S01〜S06 は第2節の定義又は完全署名を指す。ほかの補題は、その欄に入力と結論の形を明記した。非公開の補助の追加は自由である。公開の形を変える必要があれば起動条件へ戻す。

共通の完了条件は固有条件・既定import・sorryなし・既存読者の維持・新公理/信頼条件なし・署名/残件の記録である。所要時間（能動時間）は各行に個別に置き、中心は上下端の中点とする。30〜60分が基本であり、重い帰納・切替は幅を広げた。表の「検査」Lは関係するLeanを `lake env lean -M 12288` で検査、Wは群を終えて取りまとめへ渡すときの既定Lean/写しを含むworkを意味する。途中の単位だけで手番を終える場合も、その受渡しの末にWを一度行う。同じセッションで続ける群では、途中はL、最後にWを一度行い、同じ検査を重ねない。正確なコマンドは第9節から引くresultsの検査表だけに集める。


| 群 | 内容 | 単位 | 群固有の完了条件（共通条件・独立レビューと所見処置を含む） | 所要時間（能動時間） |
|---|---|---|---|---:|
| A | 方式と署名の確認 | L30.01〜06 | S01〜S06と五関門を確認。J30-2は採択済み、U03非依存。A.03の選択とD/G改訂を取りまとめが確認。 | 3時間40分〜7時間15分 |
| B | 線形の項と鍵 | L30.07〜12 | Term20場合と有限keysの位置、線形式の符号化が本番で一致する。 | 2時間50分〜5時間40分 |
| C | 否定標準形 | L30.13〜18 | Pred14×2の全28場合、停止と意味の保存。traceは入力にしない。 | 3時間5分〜6時間10分 |
| D | 整数の導出と枝 | L30.19〜24 | combine/round/split/close/discardと枝内の列の意味が固定する。 | 3時間30分〜7時間 |
| E | EqProofと限定合同 | L30.25〜30 | 10構成子、全16sortの適格性、途中のsortと危険な書換えの拒否。 | 3時間15分〜6時間30分 |
| F | 有限の論理補題 | L30.31〜36 | 12schema100分岐のsound/bind、30比較と12分類を本番定義に対応させる。 | 3時間35分〜7時間10分 |
| G | 検査器とEntails | L30.37〜42 | Refutation9・Certificate7の全健全性とbind、Entails19場合の四読者を閉じる。 | 4時間15分〜8時間30分 |
| H | 型域と最初の本番追随 | L30.43〜48 | 新名のfactsと最初の16補助を残し、旧assumeのまま既定ビルド成功。Aの後に開始できる。 | 3時間30分〜6時間40分 |
| I | 型付き値と意味の追随 | L30.49〜54 | .51で全判断/意味/読者を切替え、.54でCaptureOk全構成と全在庫を照合。主定理の言明の形を維持。 | 7時間15分〜13時間30分 |
| J | 本番の観測と正常結果 | L30.55〜60 | measure、正常算術、鍵の等値/大きさから三条件を導く。実δと実標準本体の残りを明示する。 | 3時間40分〜7時間15分 |
| K | PreparedLeafとL40 | L30.61〜66 | 開いたList長、Boolean、欄、全sortを本番のTy.LeQとbindへ接続する。 | 3時間40分〜7時間 |
| L | 固定幅とstepsの契約 | L30.67〜72 | U03回答後だけ起動。保存幅/一時積/閉じた比較、粒度/版/予約をR20へ渡す。 | 3時間〜6時間 |
| M | 旧読者と義務の照合 | L30.74〜76 | 再生/証明、申し送り、全O行を照合。.73は.38/.77に統合。 | 1時間35分〜2時間55分 |
| N | 段末監査と受け入れ | L30.77〜80 | 全有限規則・既定ビルド・A-L・写し・独立レビューの所見処置をそろえ、受入資料を提出する。 | 2時間5分〜3時間55分 |

群の見込みには担当によるレビュー所見の処置を含め、独立レビューの実行・待ちは含めない。各群の見込みは第11節の表による。同じ群では同じセッションを再開して使う。群末に取りまとめが一回レビューし、所見の重大さと変更の有無で再レビューを決める。

| 単位/群 | 目的 | 触るファイル（新は配置案） | 完全署名又は定義/補題の形 | 手順→固有の完了条件 | 依存 | 所要時間（能動時間）/検査 |
|---|---|---|---|---|---|---|
| L30.01/A | 入口と変更範囲を固定 | 既存Context/Logic/Certificate/MeaningTransport、群内署名 | S01〜S06、assume/CaptureOk/定義展開の全読者表 | 第5節とresultsの検索を再実行し、12直接構成・間接供給と全出現宣言を確認→各事実の供給元、変更/保持/切替の在庫が固定 | L10/L20 | 40〜75分/L |
| L30.02/A | 採択済み型域と切替の方式 | Context/ValueMeaning/TypedMeaning（J30-2対象） | S01、assumeWithCarrier/factsWithCarrier、ValueMeaning.mkの3条件 | Integer8/DecimalとCaptureOkを確認→並置名と切替.51（180〜300分）、全読者同時追随を固定。主定理の言明（量化の形と結論）を変える必要があれば停止。前提の判断の定義の変更はJ30-2 | 01、J30-2は採択済み | 45〜90分/L |
| L30.03/A | 検査器の帰納とbindを確認 | LinearSyntax/CertificateSyntax/CertificateKernelBind（新） | S02の(i)check_bindの∃c'又は(ii)implication_sound_at/checkedAt | (i)鍵照合/splitと像衝突・新一致・加算像の代表を証明、(ii)ν上の健全性とpredBind_compの代表を比較→Entails.bind不変。採用を記録し(ii)ならD/G表をA末に改訂 | 01 | 45〜90分/L |
| L30.04/A | 丸めと整数分枝の方式を確認 | LinearSound（新）、Interval/Arithmeticは読取り | d>0 ∧ d*x≤b → x≤b/d、x≤k ∨ k+1≤x | 負の床・係数整除・2*x=1を同じ形で扱う→切捨て/片枝で受理しない一般補題の形が固定 | 03 | 30〜60分/L |
| L30.05/A | 限定合同と別名の方式を確認 | EqCertificate（新）、Declared/ObservationSubstitution | S04、integer/structuralの2mode | Set鍵の反例を残し、field/measureの同じ像と実捕捉の入力を照合→16sortと置換位置の供給表が固定 | 01/03 | 30〜60分/L |
| L30.06/A | PreparedLeafとL40の署名を固定 | PreparedLeaf（新）、既存Certificate/Le | S05、checked_refinement | len(l)=n,n>0と型域・正常結果/Stopの3経路を接続する形を確認→B以降の完全署名、D06表、J30の扱いを取りまとめへ返す | 02〜05。U03の回答不要、幅/stepsは引数 | 30〜60分/L・W |
| L30.07/B | 線形式と符号化を置く | LinearSyntax（新） | Linear/Linear.eval/Holds/toPred、S02 | 係数列・bound・keysの長さを定義しencode_bindを証明→数学Intと型幅を混同しない | A | 20〜40分/L |
| L30.08/B | 鍵と枝内参照の定義 | CertificateSyntax/TermStructuralEq（新） | KeyTable=List Term、lookupのsome→所属、termEq=true↔t=u | 相異性を要求しない鍵列、枝prefix、構造比較を置く。A.03(i)の照合/変換、又は(ii)の像の評価に対応→不正indexを拒否 | 07 | 30〜60分/L |
| L30.09/B | 整数定数と変数の線形化 | Linearization（新） | linearize keys t=some l → integerAs η t=l.eval(keyEnv η) | integer/varの2場合とlength検査→定数項・一単位係数が一致 | 07/08 | 30〜60分/L |
| L30.10/B | 加算の線形化 | Linearization（新） | linearize_add、dot(addCoeffs a b)=dot a+dot b | 左右の係数を同じkeysへmergeし定数を合成→加算の意味と係数位置が一致 | 09 | 30〜60分/L |
| L30.11/B | 負号と定数倍の線形化 | Linearization（新） | linearize_neg/scale、dot(scale k a)=k*dot a | 負係数と0/1の係数も含める→非線形の項を入れない | 10 | 30〜60分/L |
| L30.12/B | field/measureと拒否13形 | Linearization（新）、Context/Declared | linearize_soundのTerm20場合、整数sortの鍵3形 | 可視不変欄/7measureを鍵へ写し、型付き入口は13形を拒否。raw核はintegerAs原子のbindを保つ→20場合を合成 | 08〜11/05 | 30〜60分/L・W |
| L30.13/C | NNFの定数 | LogicNormalization（新） | normalize_sound、truth/falsity×2 | 検査器内で極性を反転し、外からtraceを受け取らない→定数4場合 | B | 20〜40分/L |
| L30.14/C | 整数の比較のNNF | LogicNormalization（新） | eq/le/lt×2のnormalize_sound | 厳密不等号の−1と等号の両向き、≠のOrを導く→整数6場合 | 12/13 | 30〜60分/L |
| L30.15/C | scalar比較とFloat分類のNNF | LogicNormalization（新） | compare/floatClass×2をliteralへ写す | not ltをgeにせず符号付き原子で保持→NaN/±0の境界を変えない | 13 | 30〜60分/L |
| L30.16/C | 残る原子と対象所属のNNF | LogicNormalization（新） | decimalRepresented/charactersIn/member/constructorIs×2 | 正常観測とunknownを混同せず原子の同一性を保つ→残る8場合 | 13/15 | 30〜60分/L |
| L30.17/C | And/Or/NotのNNF | LogicNormalization（新） | and/or×2、not×2の構造再帰 | De Morganと極性反転を一帰納で証明→DNFの全枝列を事前に作らない | 14〜16 | 30〜60分/L |
| L30.18/C | 正規化の停止と全意味の合成 | LogicNormalization（新） | S02 normalize_soundの全28場合 | 入力Predの構造/極性の停止を確かめ、既に作った枝補題を合成→28場合の意味を閉じる。新しい28証明をここで作り直さない | 17 | 45〜90分/L・W |
| L30.19/D | 符号化と正規化の置換 | LinearizationBind（新） | (i)NNF/keys/線形化の変換、又は(ii)NNF.toPredの置換像の意味 | (i)像の衝突・新一致・加算像を扱う。(ii)では整数射影add/scaleと原子の同じ像を帰納へ供給→A末に採用案の完全署名へ改訂 | B/C、A.03の選択後 | 45〜90分/L |
| L30.20/D | 係数の和・非負結合 | LinearSound（新） | combination_sound、Σk_i*l_i.Holds、k_i≥0 | 空和/一項/複数項、係数0と負乗数の拒否→数学上の和の一致 | 07/19 | 30〜60分/L |
| L30.21/D | consumeとcasesの枝 | RefutationSound（新） | S02 refuteのNNF6形、todo/facts保存 | truth/falsity/linear/literal/And/Orの受理分岐を区別→両枝の事実を交差させない | 18/20 | 30〜60分/L |
| L30.22/D | deriveのcombine | RefutationSound（新） | derive_soundのcombine、期待する全係数/定数の一致 | 先行factのlookupと非負結合を合成→改竄/範囲外を拒否 | 20/21 | 30〜60分/L |
| L30.23/D | roundとsplit | RefutationSound（新） | round_sound、split_sound。splitの対象はA.03で固定 | 正除数・係数整除・負床を検査。(i)線形式の二分又は(ii)鍵の置換像の二分を使う→同じfactsの左右両枝で全整数を被覆 | 04/22 | 45〜90分/L |
| L30.24/D | 矛盾と捨てる規則 | RefutationSound（新） | close_linear/atom、discard_todo/fact_sound | 0≤負数と原子の正負だけで閉じ、削除後のindexを再解決→無関係なOrを捨てられる | 21〜23 | 30〜60分/L・W |
| L30.25/E | EqProofの旧4場合 | EqCertificate（新）、Certificate | S04 refl/symm/trans/addのmode別のsound | 旧の構文等号入口を保存し、整数射影の等式を分離→過去の正負例を維持 | 05/B/D | 30〜60分/L |
| L30.26/E | 整数のhyp/neg/scale | EqCertificate（新） | integer_soundの新3場合、先行Φのeqだけを参照 | 負係数・中間項を含める→sort違い、兄弟/将来参照を拒否 | 25 | 30〜60分/L |
| L30.27/E | 別名の有限展開 | EqCertificate（新）、ObservationSubstitution | aliasの展開列、展開後Termの構造一致 | 同じソース名だけでなく実像を照合→循環/将来展開を拒否しcaptureの同一性へ渡す | 08/25 | 30〜60分/L |
| L30.28/E | field/measureの合同 | EqCertificate（新）、Declared | field/measureのstructural子、Measure7場合 | 同じ名目型・欄番号・型引数・同じmeasureを照合→一般UFを認めない | 27/12 | 30〜60分/L |
| L30.29/E | 途中のsortと宣言を接続 | EqCertificate（新）、ClosedDecidable/Declared | S04 checkIn、HasSort/Pred.Declaredを途中にも保持 | structural16sortとintegerだけの書換え位置を分ける→substituteの中間不適格を拒否 | 26〜28 | 30〜60分/L |
| L30.30/E | substituteの健全性と比較 | CertificateKernelBind（新）、TermStructuralEq（新） | RewritePositionのspec、p.open前後の含意、PredEq=true↔等号 | snapshot反例とFloatの危険な置換を拒否し、構造比較をTerm20/Pred14へ合成→意味と実行可能な比較が一致 | 19/29 | 45〜90分/L・W |
| L30.31/F | 閉じた二つのbuiltin | BuiltinLogic（新）、既存ClosedEvaluation | B01/B02のrawcheck→意味、bind | 純粋なclosedTrueの定義とmeasure_nonnegativeを下層へ移す。rawはevalClosed_sound、上層は既存entailsを使う→循環importなし、旧成功保存 | C/E | 30〜60分/L |
| L30.32/F | 全measureの開いた非負 | BuiltinLogic（新）、Observation/Certificate | B03の7場合、0≤integerAs η (.measure m t) | measure_nonnegativeと失敗時0を分解→開いたtにも使える。stableはbindの対応で示す | 31/12 | 30〜60分/L |
| L30.33/F | Booleanの相異 | BuiltinLogic（新）、ClosedEvaluation | B04の2向き、eq(c,true)∧eq(c,false)→false | 既定射影を含む全モデルで証明→let cのapartを新しい仮定なしで導く | 31 | 20〜40分/L |
| L30.34/F | scalar比較と分類 | BuiltinLogic（新）、ClosedEvaluation | B05の22補則/B09の30順序則/B12の12分類、比較30の対応 | 実際のieeeCompare/ieeeClass、Decimal比較、Char順序を読む→NaNを全順序扱いしない | 31/15 | 60〜120分/L |
| L30.35/F | 文字範囲と構成子相異 | BuiltinLogic（新）、Observation/ClosedEvaluation | B06の包含/B07の相異、B10の符号範囲/B11の6比較 | 文字のallとtag、Charの符号範囲と比較を証明→一般正規表現/非対応sortを足さない | 31/16 | 30〜60分/L |
| L30.36/F | 同じ観測と全builtinのbind | BuiltinLogic（新）、EqCertificate | B08の16sort、12schema100分岐のraw_sound/raw_bind | 同じ像の一致を各原子へ運び、全12種類の検査と変換を閉じる→任意Propや型域の無条件登録なし | 28〜35 | 45〜90分/L・W |
| L30.37/G | 下層の全反証の健全性 | CertificateKernel（新） | (i)refute_sound、又は(ii)ν上のrefute_sound_at。Refutation9 | todo/facts/keysを一般化して一度帰納。A末に選んだ意味でbuiltin/round/splitを合成→全規則と兄弟の独立を閉じる | D/E/F | 60〜120分/L |
| L30.38/G | Certificateの全7場合 | CertificateKernel（新）、CertificateSyntax（新） | Certificate.checkの意味、check_sound/implication_sound | 既存6場合とrefuteを合成しNNFを再計算→全モデルの含意。旧6成功の保存もここで照合し、独立の.73は置かない | 37 | 30〜60分/L |
| L30.39/G | 検査器と置換の接続を合成 | CertificateKernelBind（新） | (i)check_bind、又は(ii)implication_sound_atとνの合成 | (i)7+9+10場合の変換からc'を構成。(ii)ν上で全規則を閉じ、恒等像/合成を証明→Entails.bindを元の署名で供給。A末にG表を改訂 | 19/30/36/38、A.03の選択後 | 60〜120分/L |
| L30.40/G | Entailsへ一度接続 | Logic/Basic/LogicSound、純粋kernelのimport | S03 checked又はcheckedAtの一構成子、weaken/cut/sound/bind | Aで選んだ下層証明を使い四帰納へ各1場合→18→19、公開署名を維持 | 38/39 | 45〜90分/L |
| L30.41/G | 型付けと葉の既存読者 | Le/Transport/TypedFacts/ReferenceStore/TypedMeaning | Entails.shiftV/under_none/hideContsと既存読者の形 | 新しいEntailsで全既存importを確認→型付け相互76場合へ新しい前提なし | 40 | 30〜60分/L |
| L30.42/G | 実行する論理核の入口 | Certificate（上層接続）、CertificateKernelExamples（新） | Certificate.refutation_entailsとrawcheckのdecide | 開いた線形/Booleanの正例、不正証明書の負例を本番から再生→guard実行と核内証明を分けて保存 | 41 | 30〜60分/L・W |
| L30.43/H | 並置の補助: 型域の定義 | Context、CarrierFacts（新） | Ty.carrierFacts/assumeWithCarrier/Ctx.factsWithCarrier、S01 | 8整数型の16端点とDecimal1項を並置→旧assume/factsの読者は切り替えない | A。G/U03の回答に依存しない | 30〜60分/L |
| L30.44/H | 並置の補助: normとWF | Context/NormalWellFormed/NormalizationLogic | 新名版の16読者1/2/9/13/14、S01 | carrier/refinementの二列を新名で証明→旧等号は.51まで維持し、後継の使用箇所を準備 | 43 | 40〜75分/L |
| L30.45/H | 並置の補助: shiftと文脈 | ContextFacts/ContextMap/ContextNormEq | 新名版の16読者3〜6/10/11/15/16 | None/self/後続変数の番号を保つ新factsの補題→旧Ctx.factsは切り替えず対応を記録 | 44 | 40〜75分/L |
| L30.46/H | 並置の補助: 四置換 | Transport/TypeSubst/RangeSubst | 新名版の16読者7/8、carrierFacts_bind | 型変数の像で増える事実を包含で扱う→新名の型/行/範囲/値の移送を準備 | 44/45 | 40〜75分/L |
| L30.47/H | 並置の補助: 部分型の事実 | Le/MeaningOrder | 新名版の16読者12、Ty.LeQ.assumeの後継の形 | 四族22場合の供給元を分ける→現行導出に対する補助を作り、変更後のintroduce/refineの追随箇所も固定 | 46 | 40〜75分/L |
| L30.48/H | 並置の補助: 最初の16件 | Hの変更読者、群の通常results | 16読者の新名版の変更/保持/未切替表 | 本番に残る新補題を照合し通常resultsへ記録→補助の完成を呼び手切替済みと数えない | 44〜47 | 20〜40分/L・W |
| L30.49/I | 並置の補助: 型付き事実 | TypedFacts/ValueFacts/ExternalObservation、Captureの各供給元 | HasTypeVQ.carrierFacts、assumeWithCarrier_optional/factsWithCarrierの補助の形 | ConstOK.representedとV29の供給元を準備し、CaptureOkの新事実の欄に必要な一般補題を作る→L20の構成の再追随を.51へ渡す | H | 45〜90分/L |
| L30.50/I | 並置の補助: 意味の供給 | ValueMeaning/CoverageRefinement | carrierFactsの意味、ValueMeaning.mk/const_meaningの切替用完全署名 | 現在の型付き値から型域の意味を示す。ValueMeaning自体の変更は.51→mk再構成と33場合の修正箇所、constの入力供給がそろう | 43/49 | 45〜90分/L |
| L30.51/I | 切替: 判断と意味と全読者 | Context/Le/Typing/ValueMeaning/TypedMeaningと第5節の全在庫 | S01、CaptureOk.mkの新facts、const_meaningの新入力。主定理の言明の形は不変 | 並置補助を使いassume/factsと意味を切替え、全直接/間接Capture構成・16読者・定義展開を同時追随→33場合/十移送/旧読者を含む既定ビルド成功 | G/H/49/50。G を待つのは、.41 と同じ Le・TypedFacts を編集し、新しい Entails の構成子（.40）の後に切り替えるためである。U03の回答不要 | 180〜300分/L |
| L30.52/I | 切替後の読者: 意味の移送 | MeaningTransport/MeaningOrder | assumptions_meaning、valueMeaning_subの旧公開署名 | 新carrierFactsと明示述語を別々に供給する証明を整理→assumptions_meaning/valueMeaning_subの旧公開署名と辞書式帰納を維持 | 51 | 45〜90分/L |
| L30.53/I | 切替後の読者: 網羅性と捕捉 | CoverageRefinement/TypedCoverage/PatternNormalForm/CloseTyping | 既存Inhabits/norm/close/captureの入口 | Month/空篩/観測不能List/unknownを確認し、bindParams/match_extend/paths_evaluate等の供給鎖を整理→捕捉した値の型域を実導出から得る | 51/52 | 30〜60分/L |
| L30.54/I | 切替後の読者: 捕捉と全在庫 | 第5節とresultsの全在庫、HeldValues/RangeFormation等 | CaptureOkの12直接構成、全間接構成/供給、factsの定義展開の処分表 | 各CaptureOkの新しいΓ.factsの証拠を照合し変更/保持/後継を宣言名で閉じる→L20で閉じた構成を含め漏れ0、相互の仮定なし | 49〜53 | 90〜180分/L・W |
| L30.55/J | 本番measureの正常結果 | Observation/ExternalObservation、MeasureContracts（新） | S06 measure_machine_exact | String二長/List/Bytes/Map/Set/characterCodeの7場合を分解→数学の非負と機械幅の表現可能性を分ける | F/I | 40〜75分/L |
| L30.56/J | 不変欄・snapshotのstable | MeasureContracts（新）、TypeValueExchange/CloseTyping/Declared | S06 measure_stable、closeValの既存観測交換 | 全16sort、可視な欄連鎖とNoneスロットで既存交換を使う→開いたpの不変等号を要求しない | 55/29/51 | 30〜60分/L |
| L30.57/J | 整数の正常結果と表現可能性 | NumericContracts（新）、Interval/Evalの定義とInterval/Arithmeticの補題 | checkedAdd/Sub/Mul等の正常結果→数の一致とrepresented | 七幅の加算/減算/定数倍と符号付き四幅の負号、Byteの表現/変換を照合→中間Stopを成功へしない | 55/49 | 30〜60分/L |
| L30.58/J | Decimal/Float/Characterの本番対応 | NumericContracts（新）、ClosedEvaluation/ExternalObservation | Decimalのrepresented、30比較と12分類の正常結果 | 既存bits/Char/係数scaleと同じ結果を導く→丸めやFloat算術を数学Intの線形へ拡大しない | 34/51/57 | 45〜90分/L |
| L30.59/J | Mapの鍵と大きさ | KeyContracts（新）、ClosedKeys/Observation/BuiltinTable（旧は読取り） | 閉じたKeyShape→keyCode?成功、衝突→言語上の鍵の等値 | 元の鍵/後の値/重複縮約、Decimalの数の等値を構造から証明→satだけを根拠にしない | 55/56 | 45〜90分/L |
| L30.60/J | Setと標準契約の境界 | KeyContracts（新）、ClosedKeys/MeasureContracts（新） | Setの重複縮約の一致、L40のδ接続用の署名 | mapSizeは値の観測不要、Map自体の鍵化は値も検査。鍵の成功/noneを区別しL20 unknown例を維持→実標準表の未証明部分をL40へ明示 | 58/59 | 30〜60分/L・W |
| L30.61/K | PreparedLeafの生データと検査 | PreparedLeaf（新）、Certificate | S05、BuiltinLemma12の有限な検査 | predicate/arguments/referencesからrawcheckとsort/宣言の入口を構成→Entails/任意Propを欄にしない | G/J | 40〜75分/L |
| L30.62/K | machine_exact/stable/representedの読者 | PreparedLeaf（新）、MeasureContracts/NumericContracts/KeyContracts | S05 entailsIn/bind_entails、本番の三条件を適用 | 閉じた旧代表と開いた全sortを分けて三条件を構成→作っただけの補題にしない | 61 | 40〜75分/L |
| L30.63/K | 非空Listへの開いた証明書 | PreparedLeafExamples（新）、既存CoverageRefinement/TypedCoverage | len(l)=n ∧ 0<n → 0<len(l)、任意のΓ/Φ | actual CertificateからEntailsを作りnonempty_from_entailsへ適用→ソース合成済みとはしない | 62/42 | 30〜60分/L |
| L30.64/K | L40への部分型の接続 | PreparedLeaf（新）、Le/Transport | S05 checked_refinement、同じLeQのbind/cut | 型/行/範囲/値の像と依存結果を含める→P4の試作の型を残さず本番のTy.LeQで閉じる | 62/63 | 40〜75分/L |
| L30.65/K | Boolean・短絡と欄の実読者 | PreparedLeafExamples（新）、PathConditions/MatchPathsの既存葉 | apartの仮定をB04から導く、真偽の条件の含意 | let cの偽側/And/Or/Not、欄の別名からの同じmeasureを適用→偽guardの事実を後続へ足さない | 33/56/64 | 30〜60分/L |
| L30.66/K | 全sortと有限補題の受渡し | PreparedLeafExamples（新）、16sort表の読者 | O015の16行、12schema100分岐の証拠/拒否対応 | characters/member/constructor/Booleanを含め全行へ供給元を記す→L50のσとL40の標準本体を区分 | 63〜65 | 40〜75分/L・W |
| L30.67/L | 固定幅と数学Intの対応 | CoefficientModel（新）、本書のU03欄 | CoefficientRepresented bitsと一時域の別引数、checked成功→数学結果 | 回答の保存幅と一積の計算域を区別し、Decimalの閉じた比較を別の正確な計算へ分ける→32bit構成と表現外を照合 | A/D、J30-1/3/4の回答後 | 30〜60分/L |
| L30.68/L | 一回ずつのstepsの定義 | StepAccounting（新）、本書U03欄 | Operationの有限タグ、used/reserved/remainingの状態遷移 | 入力/clone/正規化/探索/証明書/最終検査/後始末を定義→重みや別上限なし | 67、J30-3の粒度/版/予約の回答後 | 30〜60分/L |
| L30.69/L | 各処理と計上の対応 | StepAccounting（新）、R20向け読者表 | operation列の長さ=使用数、使用数+予約≤上限 | lookup/係数merge/名前比較/枝rollbackの具体化を対応→未計上ループ/暗黙cloneを残さない | 68 | 30〜60分/L |
| L30.70/L | 検査器の計算量の境界 | StepAccounting（新）、CertificateKernelの読者 | I/C/Pと仕事列の対応、不正参照の入力検査 | 共有prefix/明示スタック/型付きIDを点検→CPUや証明書byte線形の未証明主張をしない | 69/G、J30-4の実作業との対応の回答後 | 30〜60分/L |
| L30.71/L | 三種類の停止と拒否 | CoefficientModel/StepAccounting（新）、CertificateKernelExamples | malformed/representation/stepsExhaustedの別の結果形 | stepsが残る表現外、steps超過、不正証明書の入力を区別→unknownをproved/反例へしない | 67〜70 | 30〜60分/L |
| L30.72/L | R20の契約を引き渡す | Lの本番宣言、本書のR20表 | 規則の版/係数幅の回答/入力と理由/計上の全読者 | 保存幅/一時積/閉じた比較、版、byte/節点の粒度、予約を引渡す→Rust探索順/u64既定値/設定元と健全性を分けて全処理の実装レビューへ | 71 | 30〜60分/L・W |
| L30.74/M | 再生と核内証明の照合 | CertificateKernelExamples/TermStructuralEq（新） | rawcheckの実行値、by decideで同じ等式を証明 | 同じ証明書のguard実行とカーネル証明を別に記録→実行時間を能動時間へ混ぜない | K。U03非依存、契約値は引数 | 20〜40分/L |
| L30.75/M | レビュー申し送りの処分 | 本書第8節、対応する本番読者 | 論理の証拠とhandler/Reference/Lazy/Atの担当を分離 | 既済み/今回/L40/L50/L70/R段を理由付きで一件ずつ処分→Rustの未実装比較を実施済みにしない | 74 | 30〜60分/L |
| L30.76/M | 義務と署名の全照合 | 本書第7節、L40/R20への実署名 | 27行+L20段末15行+O143+共通4行の段別判定 | 本番の定義名・証拠・残る段を対応し全署名を保存→義務全体の閉鎖とL30分の完了を区別 | 75。契約は引数、回答前はL未完を明記 | 45〜75分/L・W |
| L30.77/N | 全ケースの完了を点検 | 全新規/変更Lean、既定Benitoite import | 28/20/7/9/2/10/12/100/16の各別の一覧 | 全有限規則・正常/拒否の読者と既定Certificate importを照合→未証明/無効化例0、旧6成功保存は.38の証拠を引用 | L/M | 45〜75分/L |
| L30.78/N | 公理依存と最終work | 新旧主定理/新規葉、01-12/07-04の写し | A-L全定数一覧とprint axioms、同じ最後のwork | 許可三公理だけ、既定全対象とsorry拒否。正式RSSは取りまとめが同じworkへ付ける→生終了と入力を保存 | 77 | 30〜60分/L |
| L30.79/N | 段末の独立レビューへ応答 | 当該変更と群/段末results | 定義/言明/仮定、J30、全O行の証拠の応答 | 取りまとめの独立所見を処置し影響した検査だけ更新→担当の自己点検と独立レビューを分ける | 78、レビュー実行は待ち | 30〜60分/L |
| L30.80/N | 受け入れ資料と次段を固定 | 段末results、本書、L40/R20実署名 | 段別完了/全体残り、所要と待ち、未決の判断表 | 取りまとめへ転記を渡し設計者の受入を待つ→未受入を完了と書かない | 79 | 20〜40分/L・W |

Aの後はB→C→D→E→F→G→H→I→J→K→L→M→Nを基本とする。DはFのbuiltinを参照する構文だけを先に置き、全Refutationの帰納はFの後のGで一度閉じる。既定ビルドを保つため途中の下層は未実装の枝をfalseで拒否してよいが、その枝の完成とは数えない。対応する群で規則の本体・sound・bind・既定の具体読者を同時に足し、Nの全場合表で拒否のまま残った規則がないことを確かめる。

### U03の回答と群の依存

| 群 | 依存 | U03の回答 |
|---|---|---|
| A | L10/必要なL20、採択済みJ30-2 | 不要。幅/stepsを引数にする |
| B/C/D/E/F/G | Aと各行の前群。D/GはA.03で選んだ署名を確認 | 不要 |
| H、I | HはAだけ、Gを待たずに並置可。Iの切替.51はG/H/.49/.50 | 不要 |
| J/K/M | 各行のI/F/G/K等。Mの義務表はLの欄を未確定として先に作れる | 不要 |
| L | A/DとJ30-1/3/4の回答 | **必要。全6単位を回答後に置く** |
| N | 全群の成果とレビュー。Lの未回答があればL30段末は未完 | 段末の合流で必要 |

.43〜.50は「並置の補助」、.51は「切替」、.52〜.54は「切替後の読者」である。切替の所要時間（能動時間）だけを分けると180〜300分。前後の補助・照合とは二重に足さない。長い単位も関係Lean/既定ビルドが通る途中の区切りを設け、上端の2倍へ達したら見直す。

## 7. 義務の一行ずつの対応

以下は**計画上の割当**であり、実施済みの判定ではない。各群の証拠は `l30/<群の小文字>/results.md`、段末の本番宣言と検査の一覧は `l30/results.md` に保存する予定である。全体を閉鎖済みとする義務は0行である。

### plan の L30 担当27行

| 義務 | L30の分類 | 単位（L30.を省略） | L30分の完了の判定 | L30の後に残る担当/判定 |
|---|---|---|---|---|
| O015 | 証明 | 12/16/29/56/66 | 16sortとmember/constructor/Booleanの有限規則、観測の成功との接続 | L50の対象所属/具体化、L40の標準葉 |
| O017 | 契約 | 67〜72 | 全処理の無重み計上、版、実作業との対応を固定 | R20の実装レビュー/使用数、R50/R60の報告 |
| O019 | 証明 | 07〜08/25〜42/61 | Certificate7/Refutation9/EqProof10、12種の不正証拠の拒否と全sound/bind | R20の独立検査器、R50の有限比較 |
| O020 | 証明 | 21〜24/37/71 | discardTodo/discardFactとOr展開前の既知矛盾の反証を構成 | R20探索順、R70の不要な≠を含む本番測定 |
| O021 | 計画 | 06/48/72/80 | 全79単位と48時間55分〜95時間30分の積上げ、正常算術/Stop/写しの担当を名指し | L40、R20と合わせた見込み更新。元の中心112を本番実績なしに80へ変更しない |
| O022 | 証明 | 25〜36/43〜66 | 有限表と型域/鍵/欄を列挙し、本番から三条件を用いて葉を構成 | L40の標準本体/実δ、L50の対象/σ、L60のモデル |
| O023 | 証明・記録 | 42/74 | 同じ証明書でrawcheckの実行とby decideの等式証明を別に保存 | R50の交換再生と対応する時間の記録 |
| O026 | 契約 | 60/71/72 | 純化された数値割当を候補とし、負のlengthを実反例と呼ばない境界 | R20の実現確認、R60の診断/JSON |
| O034 | 証明 | 55〜64 | 実measure/正常算術/型付き値/閉じた鍵から三条件を構成し実読者を置く | L40の全契約、L50/L60の実表、R50 |
| O043 | 証明 | 61〜66 | 本番Ty.LeQのchecked_refinementと四種の像を含むbind。試作P4の型を使わない | L40の全部分型/正常δ、L70の合成 |
| O050 | 証明 | 25〜30/39/56 | L20の観測交換を継承し、整数等号の危険な書換えと関数/Reference/資源のeqを拒否 | L40の標準葉。L20の全相互置換は再実装しない |
| O054 | 証明 | 33/36〜42/65 | 既存or_elim/not_introを引継ぎ、開いたBooleanの相異・限定合同からapartを導く | L30分は単独で閉じる。標準比較宣言はL40、ソース合成はL70/R10b |
| O071 | 証明 | 13〜24/37〜42/71 | 遅延の論理枝/FMの有限規則、負床/2*x=1/全分枝、成功証明書だけを前提とする健全性 | R20探索実装/unknown、D10の不完全性の説明 |
| O072 | 証明 | 08/25〜30/56/64 | var/可視不変欄/有限別名展開/同じmeasureのPath鍵。一般UF/入れ子measureを追加しない | R10bのソース別名の像、R20のinterningと探索 |
| O127 | 証明 | 16/35/49/58/66 | charactersInの有限区間包含と型付き入力の対応。一般regexなし | L40の導入/標準葉→R10b/R40/R50→V10 |
| O130 | 証明 | 32/55/62 | stringBytesとstringCharactersの別々の正常観測、開いた非負と葉 | L40の標準契約→R10b/R40/R50→V10 |
| O131 | 証明 | 32/55/63 | listLengthの一般規則とlen(l)=n,n>0の証明書。既存pattern_length_relationを使う | map/reverse/append/filterの本体の契約はL40へ明確に分担→R10b/R40/R50→V10 |
| O132 | 証明 | 32/55/62 | bytesLengthの非負、正常観測とByte≤255を区別 | L40標準契約→R10b/R40/R50→V10 |
| O133 | 証明 | 55/59/62 | Mapの重複縮約の大きさ、鍵コードと同じ型の鍵の等値 | Mapの鍵の不変/値の変性・実標準本体はL40→R10b/R40/R50→V10 |
| O134 | 証明 | 55/60/62 | Setの重複縮約、同じ型の鍵と正常measure/noneの区別 | Setの不変/実標準本体はL40→R10b/R40/R50→V10 |
| O135 | 証明 | 27〜29/56/65 | 不変欄連鎖・有限別名の合同と同じPのVarianceValidの供給 | data変性/decode/record全体条件の標準契約はL40/R40→R50/V10 |
| O136 | 証明 | 19/39/63〜64 | 依存する端点/結果の含意を構文の証明書と同じLeQ.bindへ接続 | L40契約/L70→R10b/R20/R50→V10 |
| O137 | 証明 | 51/57〜58/64 | 七幅の本番正常算術とByte/Decimal等の表現可能性、Stopの区別を葉へ渡す | L40の全実δ/標準契約・H04→R20/R10b/R40/R50→V10 |
| O144 | 証明 | 09〜42/55〜66 | 量化子なし線形/論理/組込みmeasureの全規則、空篩/true/構造等号を継承 | L40の型/標準葉、L50対象→R20/R10b/R40/R50→V10。UF/SMT/量化/非線形/入れ子measureなし |
| O158 | 契約 | 67〜72 | 回答済みU08=Aとの照合。stepsと係数表現外以外の独立unknownを足さない | R20/R70の実装と設定、V10でmalformedとの区別 |
| O161 | 証明 | 67/71/72 | 数学Intと幅多相の部分演算の対応、表現外とstepsの別結果 | R20で回答後の幅、R60のJSON/診断、V10の別入力 |
| O167 | 証明 | 12/25〜36/60/66/71 | L30が持つ非観測/限定合同/UF・非線形・入れ子measure/unknownの境界を受理と拒否の対照で示す | L40/L70→各R段/V10。比較連鎖/区間略記はL70/R60 |

分類は証明23行（O023は再生の記録も含む）、契約3行（O017/O026/O158）、計画1行（O021）、計27行である。共同の行はL30分だけを判定する。O131の標準本体、O135のdata/decode、O137の全δ、O015/O144のσ等は、論理の規則を作る担当と本体/対象の意味を証明する担当が異なるため、右欄へ分けた。行全体を他段へ丸投げした件は0行である。

### L20段末で L30 を残る段に持つ15行

| L20の行 | 本書の単位 | L20から引継ぐものとL30分の完了の判定 | 後段 |
|---|---|---|---|
| O015 | 12/16/29/66 | 全sortの既存形成を継承し有限規則への接続 | L50の所属と具体化 |
| O046 | 31〜42/55/63/65 | L20の捕捉したif/guard/matchの葉を再証明せず有限規則を供給 | L40の算術/length/δ、L70の全合成 |
| O050 | 25〜30/39/56 | 既存観測交換に安全な論理規則を接続 | L40の標準葉 |
| O079 | 63/64 | len(l)=nとn>0から非空の証明書を構成 | L70/R10bの静的scrutinee強化、R50比較 |
| O127 | 35/58/66 | charactersInの有限規則の入力と葉 | L40→R10b/R40/R50→V10 |
| O130 | 32/55/62 | 二つのString長と置換後の葉 | L40→R10b/R40/R50→V10 |
| O131 | 32/55/63 | List長の一般規則と開いた含意 | 標準本体map/reverse/append/filterはL40→R段/V10 |
| O132 | 32/55/62 | Bytesの正常観測と非負 | L40→R10b/R40/R50→V10 |
| O133 | 59/62 | Map鍵の等値と大きさの対応 | L40の変性/実標準契約→R段/V10 |
| O134 | 60/62 | Set鍵の等値と大きさの対応 | L40の不変/実標準契約→R段/V10 |
| O135 | 27〜29/56/65 | 検証済み変性を使う欄合同とstable | data変性/decodeはL40/R40→R50/V10 |
| O136 | 19/39/64 | 値依存端点・結果の含意とbind | L40契約/L70→R10b/R20/R50→V10 |
| O138 | 33/42/63/65 | 有限証明書、Booleanの真偽と非空の論理 | L40標準facts、L70/R10b静的合成→R50/V10 |
| O144 | 12〜42/55〜66 | 既存空篩と除外境界を保ち案Iを接続 | L40/L50→R段/V10 |
| O167 | 30/60/66/71 | 論理の拒否を対応する受理と対照にする | L40/L70→各R段/V10。構文はL70/R60 |

15行のうち12行は上の27行と同じで、O046/O079/O138の3行が追加である。群Iの results のO143にも「Φから正の長さを合成する規則はL30/L70」という申し送りがあるため、次の1行を加える。

| 追加の出どころ | 本書の単位 | L30分の完了の判定 | 後段 |
|---|---|---|---|
| O143・L20群I/J | .63〜.64 | 同じlengthを使う開いた証明書を作り、既存pattern_length_relationへ接続する。任意の同長の別Listの実API契約を完成済みとしない | L40の標準契約、L70/R10b/R40/R50/V10 |

従って、plan27行と段末15行と群Iの1行の和集合は **31義務** である。L20段末の転記済みという事実を、L30の証明済みの根拠に使わない。

**取りまとめへの転記**: O046・O079・O138・O143の4行は、本書の割当だけではplanの担当欄にL30がない。取りまとめが各行の「受け持つ段・作業」へL30を加える。本担当はplanを編集しない。

| 照合した追加の行 | L30の扱い | 理由と後段 |
|---|---|---|
| O056（l00b.15/theorems.mdではO138と併記してL30） | **L30の新しい残件なし**。31義務には追加しない | planの2026-11-01でLeanのpaths規則をL00b.14b-pathsへ前倒しし、L20段末O056はdependent_result_close/pattern_length_relationと捕捉・match/guardの一般葉を完了、残りL70。新しい有限論理規則はO054/O138で受けるため、二重計上しない |

### 全 L 段の共通4行

| 義務 | 単位 | 段別の完了の判定と証拠 | 残り |
|---|---|---|---|
| O016 | .77〜.79 | 新旧の主定理・新しい葉・private/生成宣言を含むA-L、許可三公理のみ、定義/言明/仮定の独立レビュー | L70の全合成とRust開始条件 |
| O084 | .75〜.80 | 内外、J30、段別の証明と実装/比較の未完を分け、全O行へ本番の根拠を付ける | 全L/R/K/Vの受入 |
| O027 | .78/.80 | -M実値、最後の同じworkへの限定RSS、本体/計測器の終了と未取得を保存 | 他段の正式採取 |
| O118 | .38/.77 | 変更した本番コメントを現行設計へそろえ、工程ID/絶対パスを新たに残さない。既存の残件を別記 | L70/R50/R60/D10/V10の全体照合 |

共通4行を含めた管理対象は **35義務** である。重複を除いた31行のうち、証明27・契約3・計画1であり、共通の記録/監査4を別に数える。実装を始めていないので完了判定は全て未実施である。

## 8. レビュー申し送りと他段への分担

[resultsの申し送り表](results.md#レビュー申し送りの照合)を正とする。Reference/Lazy/AtのRust/全合成はL70/R段、handler等の既済みの葉はL20、実標準本体はL40/実表はL60と分ける。L30は有限論理と入力/出力の証拠を担当し、未実施の実装比較を済みとしない。R20へ渡す幅・版・全計上・拒否理由は.72に集める。

## 9. 検査・レビュー・受け入れの割当

各単位途中の関係Lean、受渡し末の既定全Lean/sorry拒否と写しを含むwork、.78の全定数の公理依存と同じ最後のworkへの正式RSS、.74の実行と核内証明、14群末/段末の独立レビュー、.80の設計者の受け入れを割り当てる。コマンド・基準・保存先・見込みの全表は[resultsの検査の割当](results.md#r1-実装時の検査の割当)を正とする。下書きの本作業では実施済みとしない。

## 10. 分岐する判断と停止条件

| 項目 | 判断の状態・推奨 | 影響と止める位置 |
|---|---|---|
| J30-1・係数幅 | **設計者・未決**。128bitを推奨。第4節の計算域の分離が条件 | 保存係数の表現外で受理が変わる。閉じたDecimal比較とu64の一時積は同じ固定幅で計算しない。群L/公開契約は回答後 |
| J30-2・判断と意味の型域 | **採択済み**。planの2026-11-03の取りまとめの判断。D02・D21の範囲としてS01を採る | Ty.assume→Ctx.facts→Ty.LeQ.introduce/refine（V_Sub・C_Sub）とCaptureOk.mkの事実の欄に入る。主定理が量化する型付け判断と状態不変条件の定義を変える。言明の形（量化の形と結論）は維持。受理する導出が増え、書ける形は狭めない。L20のCapture構成の再追随も計上 |
| J30-3・粒度/版/予約 | **設計者・未決**。byteと節点の実操作、proof-steps-v1、生成時の個別予約を推奨 | 第4節の三点だけを問う。粒度/予約は同じstepsでの受理を変えうる。版の字面だけなら差なし。群Lは回答後 |
| J30-4・実作業と計算量の対応 | **設計者・U03の契約の確認**。J30-3の粒度/予約と実作業の対応、枝共有を推す | 新しい選択肢を増やさず三点へ集約。独立上限/重み/未計上cloneを追加せず、証明書byte数だけの線形時間やCPU/OS上限を保証しない |
| J30-5・検査器/合同/葉 | **取りまとめと独立レビュー**。A.03の二案比較とA.05/.06の署名を確認 | Entails.bindを変えず、選んだ案をD/Gへ反映。A.02では主定理の言明（量化の形と結論）を変える必要があれば停止する。J30-2で採った前提の判断の定義の変更とは区別 |

新公理、主定理の結論の弱化、新しい提供範囲の削減、書ける形の独立の制限、精密な外部状態の新設は提案しない。これらが必要と分かったら、反例/未証明の言明・差・代案・所要時間（能動時間）と待ち・実用への影響を示して止める。

**取りまとめへの確認点**: planのREADMEと同じ範囲の上端は既に1,338.3時間で、旧相談基準1,188.8時間を149.5時間超える。2026-10-31の了承は相談の対象を「改造全体の見込みの上端」へ変えた。この了承と1,188.8時間の基準の関係、今回のL30上端95時間30分への更新後に相談が要るかを取りまとめが整理する。段の上端だけで自動停止とはしないが、超過を未発生とも書かない。

各単位の上端の2倍へ達したら原因と残りを報告し、既定ビルドが通る区切りで止め、新単位へ入らない。全単位一律120分とはしない。新公理等の停止条件はその時刻を待たない。

## 11. 見込みの根拠と取りまとめへの転記

**79単位、所要時間（能動時間）48時間55分〜95時間30分、中心72時間12分30秒（約72時間13分）**。第6節の各行を加算した値で、単位数に一律45分を掛けていない。元枠36〜84時間（中心60）に対し、下端+12時間55分、上端+11時間30分、中心約+12時間13分となる。独立レビューの実行・ビルド/監査・回答/受け入れの待ちは別である。

帰納を合成する.18/.37/.39、分岐の多い.34/.36、全在庫の.54を個別に広げた。.51の切替は180〜300分を別掲する。L20で閉じたCaptureOkの構成を開き直す分は、.49の15〜30分、.51の60〜120分、.53の15〜30分、.54の60〜120分、計**2時間30分〜5時間**を各単位の内数として含めた。切替とその後の照合を二重に加算しない。守る既存読者0の.73は.38/.77に統合し、IDを詰めない。

[effort-ledger](../effort-ledger.md)の選択は、単位名が`L20 群 `で始まり担当Codexの全行（A1〜S、入口/停止/再開を含む）44行で約21時間54分。`RV-L20.`で始まる独立レビュー23行は約3時間20分。`L20-plan`の計画4行は約2時間59分、`RV-L20-plan`の計画レビュー4行は約29分として分離した。取りまとめのworkは足さない。[resultsの選択行表](results.md#r1-台帳の選択行)に全行名と元の行番号を載せる。待ちが分離されていない外側の時間を能動時間の確定値にはしない。

L20の実装は詳細化の見込みを大きく下回ったが、新しい検査器/丸め/合同/型域の変更へ比を一律に掛けない。最初の16読者の新名版と本番切替の結果を区別し、通常resultsで分離できた同種の残りだけを更新する。Aで選ぶ帰納の形、Jの鍵の意味、回答待ちにはその単価を掛けない。

| 残る手順 | 検査・レビュー・受け入れを含む内容 | 見込み |
|---|---|---:|
| r1の確認と転記 | 所見14件、79単位、35義務、担当追記4行、O056の処分、上端と相談条件を取りまとめが確認 | 不明 |
| Aの方式の確認 | 6単位、関係/既定Lean、定義/言明/仮定の群末レビューと処置、D/Gの署名確定 | 所要時間（能動時間）3時間40分〜7時間15分、待ちは別 |
| B〜Mの本番作業 | 69単位。LだけU03回答後。有限規則・本番読者・各群末の既定Leanとレビュー処置 | 所要時間（能動時間）43時間10分〜84時間20分、待ちは別 |
| Nの監査と受入資料 | 4単位、全場合/義務/署名、A-L、最後のwork/RSS、段末レビュー応答 | 所要時間（能動時間）2時間5分〜3時間55分、待ちは別 |
| ビルド・監査・正式RSS | 同じ検査を引用。L20最後のwork147.71秒は参考だけ | 群末増分buildは約2.5分から更新、A-L旧案1〜5分。新規分/再実行は不明 |
| 独立レビュー・U03回答・受け入れ | 群末/段末と設計者。L20の並行受け入れを区別 | 不明 |

取りまとめは群/見込み/担当追記/J30/次段の実署名をplanへ転記する。主定理・実表・標準本体・Rust接続・最終比較の全体の完了とは区別する。
