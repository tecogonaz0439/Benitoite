import Benitoite.Scope.Domain
import Benitoite.Interval.BindingScope
import Benitoite.Interval.Identity

/-!
# Scope の成功の局所解析の評価関係と抽象値（採用定義）

0.0.13 の L00 の比較の後、設計者が採用した局所解析の骨格である（L00.08 の一括の問い、問 14・15）。
L00.05 の形を、具体の値の表現によらない形で置く。具体の値の型 `V` と、事実と値の対応 `FactModels V` は
利用側が与える（モデルは `Scope.InferenceExamples`、本番の接続は L40）。

- 評価関係: 解決済みの標準の束縛が選ぶ規則の表（`ScopeTable`）と、その表を引いて規則を適用する一つの関係
  （`EvalScope`。構成子は `apply` だけ）。規則は表の項目（`ScopeRule`）であり、項目ごとの健全性（`RuleSound`）から
  適用全体の健全性（`apply_sound`）を導く。規則を加えても評価関係の構成子は増えない。
- 抽象値: 対象の種類（`Kind`）と、既知の範囲または未知（`Bound`）を持つ由来（`Origin`）と、その由来を持つ
  Result・同じ成功値・射影した条件の事実（`ScopeFact`）。未知は Top の添字になる（判断 9）。
- 局所位置: 既存の `Interval.BindingScope`（束縛番号）と `Interval.OperationKey`（呼び出しの同定）を共有し、
  別の番号付けを作らない。Scope の事実は Range の事実と別の成分に置き（`LocalState`）、必須の判定
  （`ScopeState.requiredIndex`）は Range の成分を読まない（判断 9 の「警告の解析の結果を型の受理条件へ
  流用しない」）。

本モジュールは区間解析の評価関係（`Interval.Eval`）と警告の解析を import しない。予算の計上点・忘却の費用・
上限の値（DET-08）は L40 と R20 で置く（問 24）。
-/

namespace Benitoite.Scope.Inference

open Benitoite.Scope.Domain

/-- 呼び出しの同定は既存の `OperationKey` を共有する。 -/
abbrev Key := Interval.OperationKey

/-! ## 抽象値 -/

/-- 既知の閉じた範囲か、未知か。 -/
inductive Bound where
  | known (r : Range)
  | unknown
  deriving DecidableEq, Repr

/-- 型の添字。未知は Top（判断 9）。 -/
def Bound.index : Bound → Range
  | .known r => r
  | .unknown => .top

/-- 検査の由来。呼び出しの同定、対象の種類、既知の範囲または未知。 -/
structure Origin where
  key : Key
  kind : Kind
  bound : Bound
  deriving DecidableEq, Repr

/-- 局所位置に置く Scope の事実。
`pattern r` は解析すると r になるパターンの文字列、`result o` は一度保存した検査の Result、
`checked o id` は同じ Result の `Ok` の成功値で、束縛番号 id にだけ有効である。 -/
inductive ScopeFact where
  | pattern (r : Range)
  | result (origin : Origin)
  | checked (origin : Origin) (successId : Nat)
  deriving DecidableEq, Repr

/-- 規則に渡す抽象の引数。リテラル、束縛番号と事実を持つ局所の読み取り、直接の射影の値、未知。 -/
inductive AbsArg where
  | lit (s : String)
  | loc (id : Nat) (fact : Option ScopeFact)
  | value (fact : ScopeFact)
  | unknown
  deriving DecidableEq, Repr

/-! ## 事実と具体の値の対応 -/

/-- 抽象と具体の値の対応の与え方。`lit s v` は値 v がリテラル s であること、`fact f id v` は束縛番号 id の位置の
値 v が事実 f に対応すること（成功値の事実はその番号にだけ有効にする）。 -/
structure FactModels (V : Type) where
  lit : String → V → Prop
  fact : ScopeFact → Nat → V → Prop

variable {V : Type}

def AbsArg.Models (M : FactModels V) : AbsArg → V → Prop
  | .lit s, v => M.lit s v
  | .loc id (some f), v => M.fact f id v
  | .loc _ none, _ => True
  | .value f, v => ∀ id, M.fact f id v
  | .unknown, _ => True

inductive ArgsModel (M : FactModels V) : List AbsArg → List V → Prop
  | nil : ArgsModel M [] []
  | cons {a as v vs} : a.Models M v → ArgsModel M as vs → ArgsModel M (a :: as) (v :: vs)

/-! ## 規則の表と一つの評価関係 -/

/-- 表の項目（標準の宣言の規則）。`index` は型検査器が抽象の引数から選ぶ範囲の具体化、`run` は具体化した
範囲を受け取る実行時の評価（コアの δ に当たる）、`transfer` は抽象の適用。 -/
structure ScopeRule (V : Type) where
  index : List AbsArg → List Range
  run : List Range → List V → Option V
  transfer : Key → List AbsArg → Option ScopeFact

/-- 項目の健全性。どの具体化の範囲で実行しても、抽象の結果が値に対応する。結果の事実は束縛番号に
よらない（成功値の事実は表の規則から作らず、`Ok` の腕だけが作る）。 -/
def RuleSound (M : FactModels V) (rule : ScopeRule V) : Prop :=
  ∀ key aargs rs vs v f, ArgsModel M aargs vs → rule.run rs vs = some v →
    rule.transfer key aargs = some f → ∀ id, M.fact f id v

/-- 解決済みの標準の束縛の表。`apiAt` は出現の同定（解決済みの宣言）、`rules` は宣言の規則。
同じ綴りの利用者の関数は `apiAt` に現れない。 -/
structure ScopeTable (V : Type) where
  apiAt : Key → Option String
  rules : String → Option (ScopeRule V)

def ScopeTable.ruleAt (T : ScopeTable V) (key : Key) : Option (ScopeRule V) := do
  let declaration ← T.apiAt key
  T.rules declaration

def TableSound (M : FactModels V) (T : ScopeTable V) : Prop :=
  ∀ d rule, T.rules d = some rule → RuleSound M rule

/-- 評価関係。表が選ぶ規則を適用する一つの構成子だけを持つ。 -/
inductive EvalScope (T : ScopeTable V) (key : Key) (rs : List Range) (vs : List V) : V → Prop where
  | apply (rule : ScopeRule V) (v : V) (identified : T.ruleAt key = some rule)
      (run : rule.run rs vs = some v) : EvalScope T key rs vs v

/-- 抽象の適用。表にない出現は未知（`none`）。 -/
def absApply (T : ScopeTable V) (key : Key) (aargs : List AbsArg) : Option ScopeFact :=
  match T.ruleAt key with
  | some rule => rule.transfer key aargs
  | none => none

/-- 同定されない出現へ標準の規則を適用する導出はない。 -/
theorem evalScope_unidentified {T : ScopeTable V} {key : Key} {rs : List Range} {vs : List V} {v : V}
    (missing : T.ruleAt key = none) : ¬ EvalScope T key rs vs v := by
  intro h
  cases h with
  | apply rule _ identified _ => simp [missing] at identified

/-- 適用の健全性は表の健全性から従う。規則の追加は表の項目とその健全性の補題の追加で済む。 -/
theorem apply_sound {M : FactModels V} {T : ScopeTable V} (hT : TableSound M T) {key : Key}
    {rs : List Range} {vs : List V} {v : V} {aargs : List AbsArg} {f : ScopeFact}
    (hargs : ArgsModel M aargs vs) (hev : EvalScope T key rs vs v) (hf : absApply T key aargs = some f) :
    ∀ id, M.fact f id v := by
  cases hev with
  | apply rule _ identified run =>
    have hrule : RuleSound M rule := by
      unfold ScopeTable.ruleAt at identified
      cases hd : T.apiAt key with
      | none => simp [hd] at identified
      | some d =>
        simp only [hd, Option.bind_eq_bind, Option.bind_some] at identified
        exact hT d rule identified
    simp only [absApply, identified] at hf
    exact hrule key aargs rs vs v f hargs run hf

/-! ## 局所の状態 -/

/-- Scope の局所の事実。束縛番号は既存の `BindingScope` を共有する。 -/
structure ScopeState where
  scope : Interval.BindingScope
  facts : List (Option ScopeFact)

def ScopeState.Models (M : FactModels V) (st : ScopeState) (env : List (Option V)) : Prop :=
  ∀ index fact, st.facts[index]? = some (some fact) →
    ∃ id value, st.scope.idAt index = some id ∧ env[index]? = some (some value) ∧ M.fact fact id value

/-- ラムダ、handle の保護本体と節、Task の入口。位置と番号を残し、由来を仮定しない（判断 9）。 -/
def ScopeState.empty (scope : Interval.BindingScope) : ScopeState :=
  ⟨scope, List.replicate scope.positions.length none⟩

def ScopeState.extend (st : ScopeState) (fact : Option ScopeFact) : ScopeState :=
  ⟨st.scope.fresh, fact :: st.facts⟩

/-- 合流・本体の境界・予算の超過。位置を保ち、全ての由来を忘れる。 -/
def ScopeState.forgetAll (st : ScopeState) : ScopeState :=
  ⟨st.scope, st.facts.map (fun _ => none)⟩

/-- 局所の位置の読み取り。束縛番号と、その位置の事実。 -/
def ScopeState.readLocal (st : ScopeState) (index : Nat) : AbsArg :=
  match st.scope.idAt index with
  | some id => .loc id (st.facts[index]?.join)
  | none => .unknown

theorem ScopeState.empty_models (M : FactModels V) (scope : Interval.BindingScope) (env : List (Option V)) :
    (ScopeState.empty scope).Models M env := by
  intro index fact found
  simp only [ScopeState.empty, List.getElem?_replicate] at found
  split at found <;> simp_all

theorem ScopeState.forgetAll_models (M : FactModels V) (st : ScopeState) (env : List (Option V)) :
    st.forgetAll.Models M env := by
  intro index fact found
  simp [ScopeState.forgetAll] at found

theorem ScopeState.readLocal_models {M : FactModels V} {st : ScopeState} {env : List (Option V)}
    (hm : st.Models M env) {i : Nat} {v : V} (found : env[i]? = some (some v)) :
    (st.readLocal i).Models M v := by
  unfold ScopeState.readLocal
  cases hid : st.scope.idAt i with
  | none => exact trivial
  | some id =>
    cases hf : st.facts[i]? with
    | none => exact trivial
    | some fo =>
      cases fo with
      | none => exact trivial
      | some f =>
        obtain ⟨id', value, hid', hval, hmod⟩ := hm i f hf
        rw [hid] at hid'; cases hid'
        rw [found] at hval; cases hval
        exact hmod

theorem ScopeState.extend_models {M : FactModels V} {st : ScopeState} {env : List (Option V)}
    (hm : st.Models M env) {fact : Option ScopeFact} {v : Option V}
    (head : ∀ f, fact = some f → ∃ w, v = some w ∧ M.fact f st.scope.nextId w) :
    (st.extend fact).Models M (v :: env) := by
  intro index f found
  cases index with
  | zero =>
    simp only [ScopeState.extend, List.getElem?_cons_zero, Option.some.injEq] at found
    obtain ⟨w, rfl, hw⟩ := head f found
    exact ⟨st.scope.nextId, w, rfl, rfl, hw⟩
  | succ index =>
    obtain ⟨id, old, atId, atValue, modeled⟩ := hm index f found
    exact ⟨id, old, atId, atValue, modeled⟩

/-! ## 必須の判定 -/

/-- 局所の位置 index の値に必須の判定が付ける型の添字。同じ成功値の事実で、読んだ位置の束縛番号と
成功値番号が一致するときだけ既知の範囲、それ以外は Top。 -/
def ScopeState.requiredIndex (st : ScopeState) (index : Nat) : Range :=
  match st.facts[index]? with
  | some (some (.checked o sid)) =>
      match st.scope.idAt index with
      | some id => if sid = id then o.bound.index else .top
      | none => .top
  | _ => .top

/-- 必須の判定が Top でない添字を付けた位置の値は、同じ番号の成功値の事実に対応し、添字はその由来の添字である。
所属は利用側の対応 `M.fact` から得る。 -/
theorem ScopeState.requiredIndex_fact {M : FactModels V} {st : ScopeState} {env : List (Option V)}
    (hm : st.Models M env) {index : Nat} {v : V} (found : env[index]? = some (some v))
    (hne : st.requiredIndex index ≠ .top) :
    ∃ o id, st.requiredIndex index = o.bound.index ∧ M.fact (.checked o id) id v := by
  unfold ScopeState.requiredIndex at hne ⊢
  cases hf : st.facts[index]? with
  | none => simp [hf] at hne
  | some fo =>
    cases fo with
    | none => simp [hf] at hne
    | some fact =>
      cases fact with
      | checked o sid =>
        cases hid : st.scope.idAt index with
        | none => simp [hf, hid] at hne
        | some id =>
          simp only [hf, hid] at hne ⊢
          by_cases hsid : sid = id
          · rw [ite_eq_left hsid]
            obtain ⟨id', value, hid', hval, hmod⟩ := hm index _ hf
            rw [hid] at hid'; cases hid'
            rw [found] at hval; cases hval
            subst hsid
            exact ⟨o, sid, rfl, hmod⟩
          · rw [ite_eq_right hsid] at hne
            exact absurd rfl hne
      | pattern r => simp [hf] at hne
      | result o => simp [hf] at hne

/-- Range の事実と Scope の事実を同じ束縛番号の上の別の成分に置く局所の状態。Range の事実の型 `RF` は
区間解析が与える（本番は `Interval.RangeLocalFact`）。 -/
structure LocalState (RF : Type) where
  scope : Interval.BindingScope
  range : List (Option RF)
  scopeFacts : List (Option ScopeFact)

def LocalState.toScope {RF : Type} (s : LocalState RF) : ScopeState := ⟨s.scope, s.scopeFacts⟩

/-- 必須の判定は Range の成分（警告の解析が使う由来）を読まない。 -/
theorem LocalState.requiredIndex_range_independent {RF : Type} (s : LocalState RF) (r : List (Option RF))
    (index : Nat) :
    ({ s with range := r }).toScope.requiredIndex index = s.toScope.requiredIndex index := rfl

/-- Scope の成分は状態の束縛番号を読む（別の番号付けを作らない）。 -/
theorem LocalState.toScope_scope {RF : Type} (s : LocalState RF) : s.toScope.scope = s.scope := rfl

end Benitoite.Scope.Inference
