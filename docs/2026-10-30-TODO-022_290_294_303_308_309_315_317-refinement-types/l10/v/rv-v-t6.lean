import Lean
import Benitoite.Release.Refinement.ValueFacts

open Benitoite Benitoite.Release.Refinement
namespace RV

abbrev pureEff : Eff := .mk (fun _ => false) []
def fieldCo : Ty := .tvar 0
def fieldContra : Ty := .fn ["x"] [.tvar 0] (.base .unit) pureEff
def fieldInv : Ty := .reference (.tvar 0)
def cd (field : Ty) : ConDecl := ⟨"Box", 1, [field]⟩
def info (v : Variance) : DataVarianceDecl := ⟨1, [v], [], []⟩
def single (v : Variance) (field : Ty) : Program := {
  defs := fun _ => none
  cons := fun c => if c = "C" then some (cd field) else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none
  dataInfo := fun d => if d = "Box" then some (info v) else none
}

theorem single_valid (v : Variance) (field : Ty)
    (ha : Ty.Annotation (single v field) [{}] [] field)
    (hk : field.HasKind (single v field) [.value] .value)
    (hv : field.VarianceOK (single v field) [v] .positive)
    (occurs : v = .invariant ∨ field.ParamOccurs 0) :
    (single v field).VarianceValid := by
  constructor
  · intro d inf hi
    by_cases hd : d = "Box"
    · subst d
      simp only [single, ↓reduceIte, Option.some.injEq] at hi
      subst inf
      refine ⟨rfl, ?_, by simp [info], by simp [info]⟩
      intro i w hw hno
      cases i with
      | zero =>
        cases Option.some.inj hw
        rcases occurs with he | ho
        · exact he
        · exact False.elim (hno ⟨"C", cd field, field, by simp [single], rfl, List.mem_cons_self, ho⟩)
      | succ i => simp [info] at hw
    · simp [single, hd] at hi
  · intro c dec hc
    by_cases hC : c = "C"
    · subst c
      simp only [single, ↓reduceIte, Option.some.injEq] at hc
      subst dec
      constructor
      · intro inf hi
        simp only [single, cd, ↓reduceIte, Option.some.injEq] at hi
        subst inf
        rfl
      · intro a ha'
        have he : a = field := List.mem_singleton.mp ha'
        subst a
        refine ⟨ha, hk, ?_⟩
        simpa [single, cd, Program.varianceFor, info] using hv
    · simp [single, hC] at hc

-- 検査器が共変・反変・不変の宣言を受ける。
theorem co_valid : (single .covariant fieldCo).VarianceValid := by
  apply single_valid
  · exact ⟨by simp [fieldCo, Ty.WF], trivial, trivial⟩
  · trivial
  · exact ⟨.covariant, rfl, trivial⟩
  · exact Or.inr rfl

/-! 不変の位置の拒否（DET-L12）と入れ子。 -/
abbrev vc : List Variance := [.covariant]
abbrev Pc := single .covariant fieldCo
def e0 : Eff := .mk (fun _ => false) []
macro "rej" : tactic => `(tactic| (intro h; simp [Ty.VarianceOK, Tel.VarianceOK, Eff.VarianceOK, varianceTysOK, varianceArgsOK, Variance.accepts, Polarity.flip, Polarity.compose, Program.varianceFor, single, info] at h))
example : ¬ (Ty.reference (.tvar 0)).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.set (.tvar 0)).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.map (.tvar 0) (.base .unit)).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.dict "C" (.tvar 0)).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.cont (.tvar 0) (.base .unit) e0).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.cont (.base .unit) (.tvar 0) e0).VarianceOK Pc vc .positive := by rej
example (x : ExternalId) : ¬ (Ty.external x [.tvar 0]).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.tapp 0 []).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.fn [] [] (.base .unit) (.mk (fun _ => false) [.tvar 0])).VarianceOK Pc vc .positive := by rej
example : ¬ (Ty.dependentFn (.param "x" (.tvar 0) (.done (.base .unit) e0))).VarianceOK Pc vc .positive := by rej
-- 不変の data の引数へ渡す入れ子
example : ¬ (Ty.data "Other" [.tvar 0]).VarianceOK Pc vc .positive := by rej
-- 反変の data の引数へ渡すと負になる
example : ¬ (Ty.data "Box" [.tvar 0]).VarianceOK (single .contravariant fieldContra) vc .positive := by rej
-- 二重の反転は正
example : (Ty.fn ["x"] [.fn ["y"] [.tvar 0] (.base .unit) e0] (.base .unit) e0).VarianceOK Pc vc .positive := by
  simp [Ty.VarianceOK, Eff.VarianceOK, varianceTysOK, Variance.accepts, Polarity.flip, e0]
-- T{true} と T は不変の位置で同じ
example : Ty.LeQ (single .invariant fieldInv) [] [] (.data "Box" [.refined (.base .integer) .truth]) (.data "Box" [.base .integer]) := by
  apply Ty.LeQ.data
  have hv : (single .invariant fieldInv).varianceFor "Box" 1 = [.invariant] := by simp [single, Program.varianceFor, info]
  have hh : TypeArgsLe (single .invariant fieldInv) [] [] [.invariant] [.refined (.base .integer) .truth] [.base .integer] :=
    .invariant_cons (by simp [Ty.norm, Ty.refineNorm, Ty.packRefinements, Ty.core, Ty.refinementPredicates, Pred.conjuncts]) .nil
  simpa only [List.length_cons, List.length_nil, Nat.zero_add, hv] using hh
-- 不変の位置の篩の差は広げない
example : ¬ Ty.LeQ (single .invariant fieldInv) [] [] (.data "Box" [.refined (.base .integer) .falsity]) (.data "Box" [.base .integer]) := by
  intro h
  obtain ⟨bs, hb, hs⟩ := h.dataCore (d := "Box") (as := [Ty.norm (.refined (.base .integer) .falsity)]) rfl
  have he := (Ty.data.inj hb).2
  subst bs
  have hv : (single .invariant fieldInv).varianceFor "Box" 1 = [.invariant] := by simp [single, Program.varianceFor, info]
  simp only [List.length_cons, List.length_nil, Nat.zero_add, hv] at hs
  cases hs with
  | invariant_cons he _ =>
    simp [Ty.norm, Ty.refineNorm, Ty.packRefinements, Ty.core, Ty.refinementPredicates, Pred.conjuncts, Pred.ofConjuncts] at he
-- Token: 観測の型引数でも取り替えられない
def token : Program := { defs := fun _ => none, cons := fun c => if c = "Token" then some ⟨"Token", 1, []⟩ else none, ops := fun _ => none, effects := fun _ => none, classes := fun _ => none, impls := fun _ => none, dataInfo := fun d => if d = "Token" then some (info .invariant) else none }
example : ¬ DataObservationLe token "Token" [.opaque "Read" .top] [.opaque "Write" .top] := by
  intro h
  simp only [DataObservationLe, token, Program.varianceFor, info, observationTypes, Ty.observationType] at h
  simp at h
  cases h with
  | invariant_cons he _ => 
    have := (Ty.opaque.inj he).1
    exact (by decide : ("Read" : String) ≠ "Write") this
-- 列の子を消す観測では、不変の引数の中の List の要素は区別されない
example : DataObservationLe token "Token" [.list (.opaque "Read" .top)] [.list (.opaque "Write" .top)] := by
  simp only [DataObservationLe, token, Program.varianceFor, info, observationTypes, Ty.observationType]
  simp
  exact .invariant_cons rfl .nil
end RV
