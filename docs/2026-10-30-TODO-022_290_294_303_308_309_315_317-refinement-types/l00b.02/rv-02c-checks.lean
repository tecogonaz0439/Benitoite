import Benitoite
import Lean
open Benitoite

namespace RV

/-- 中1の反例: 旧解析の mayFail が偽のままで .failed が評価できる（腕の尽きた整数 match）。 -/
def env0 : Interval.ConcreteEnv := ⟨[], [], fun _ => none⟩
def absEnv : Interval.AbstractEnv := Interval.AbstractEnv.ofLocals []
def one : Surface.Expr := .literal (.integer ⟨1, by decide⟩)

theorem failed_without_mayFail (key : Interval.OperationKey) :
    let input : Interval.EvalInput := ⟨.matchE (.base .unit) one .nil, .base .unit, key⟩
    Interval.Models absEnv env0 ∧
    Interval.EvalPartial env0 input (.failed .unknown) [] ∧
    (Interval.analyzeBase absEnv input 3).mayFail = false := by
  refine ⟨⟨.nil, rfl, rfl⟩, ?_, ?_⟩
  · exact Interval.EvalPartial.matchInteger env0 key one .nil (.base .unit) _ _ [] []
      (Interval.EvalPartial.integer env0 _ _) (Interval.EvalArms.nil _ _ _ _)
  · rfl

/-- 正常域の写しの逆向き（型が一致する値では所属と同値。Bool の写しが空虚でないことも含む）。 -/
theorem normalToShared_iff {type range} {value : Interval.ConcreteValue}
    (typed : value.type = type) :
    (Interval.normalToShared type range).Mem value.toApprox ↔ Interval.NormalMem type range value := by
  refine ⟨?_, Interval.normalToShared_mem⟩
  intro h
  subst typed
  refine ⟨rfl, ?_⟩
  cases value with
  | integer n => exact h.2
  | boolean b => cases b <;> exact h
  | integer8 n => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | integer16 n => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | integer32 n => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | unsignedInteger16 n => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | unsignedInteger32 n => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | unsignedInteger64 n => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | unit => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | rangeError o n e => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | con o ts n a => change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem]
  | other t nI nB nU =>
    cases t with
    | base b =>
      cases b <;> first
        | exact absurd rfl nB
        | exact absurd rfl nU
        | (simp [Interval.IntKind.ofType] at nI; done)
        | (change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem])
    | _ => all_goals (change _ = true; revert h; simp only [Interval.ConcreteValue.type, Interval.normalToShared]; cases (range : Bool) <;> simp [Shared.ValueApprox.Mem])

/-- 空虚でないこと: Bool の true/false の場合を具体に。 -/
example : (Interval.normalToShared (.base .unit) (true : Bool)).Mem (Interval.ConcreteValue.unit).toApprox := trivial
example : ¬ (Interval.normalToShared (.base .unit) (false : Bool)).Mem (Interval.ConcreteValue.unit).toApprox := id
example : Interval.NormalMem (.base .unit) (true : Bool) .unit := ⟨rfl, rfl⟩
example : Interval.NormalMem (.base .integer8) (true : Bool) (.integer8 ⟨7, by decide⟩) := ⟨rfl, rfl⟩
example : (Interval.normalToShared (.base .integer8) (true : Bool)).Mem
    (Interval.ConcreteValue.integer8 ⟨7, by decide⟩).toApprox := trivial

/-- other は整数・Boolean の近似に含まれない。 -/
example (k : Interval.IntKind) (i : Interval.Interval k) :
    ¬ (Shared.ValueApprox.integer k i).Mem .other := id
example (a b : Bool) : ¬ (Shared.ValueApprox.boolean a b).Mem .other := id
example : (Shared.ValueApprox.unknown).Mem .other := trivial

/-- 型付き定数と範囲: 型付けが範囲を要求しないので、範囲外の定数は .integer の全域に属さない。 -/
example : (Release.Refinement.Val.const (.integer8 999)).toApprox = .other := by
  exact Shared.ApproxValue.ofInt_outside (kind := .integer8) (value := 999) (by decide)
example : ¬ (Shared.ValueApprox.integer .integer8 (Interval.top .integer8)).Mem
    (Release.Refinement.Val.const (.integer8 999)).toApprox := by
  have : (Release.Refinement.Val.const (.integer8 999)).toApprox = .other := by
    exact Shared.ApproxValue.ofInt_outside (kind := .integer8) (value := 999) (by decide)
  rw [this]; exact id

/-- 空の表現が複数ある（Mem は等しいが構文は別）。 -/
example : ∀ v, ¬ (Shared.ValueApprox.boolean false false).Mem v := by
  intro v h; cases v <;> simp_all [Shared.ValueApprox.Mem]
example : (Shared.ValueApprox.boolean false false) ≠ .bottom := by intro h; cases h

/-- 新型の整数認定: 篩は認定しない。 Byte も。 -/
example : Interval.IntKind.ofRefinementType (.base .byte) = none := rfl
example : Interval.IntKind.ofType (.base .boolean) = none := rfl

end RV

open Lean Elab Command in
elab "#ctorcount " n:ident : command => do
  let env ← getEnv
  let some (.inductInfo i) := env.find? n.getId | throwError "no"
  logInfo m!"{n.getId}: {i.ctors.length}"

#ctorcount Benitoite.Shared.ValueApprox
#ctorcount Benitoite.Shared.ApproxValue
#ctorcount Benitoite.Shared.FlowApprox
#ctorcount Benitoite.Shared.EvalResult
#ctorcount Benitoite.Release.Refinement.HasTypeVQ
#ctorcount Benitoite.Release.Refinement.HasTypeCQ
#ctorcount Benitoite.Release.Refinement.HasTypeVsQ
#ctorcount Benitoite.Release.Refinement.HasTypeEachQ
#ctorcount Benitoite.Release.Refinement.HasTypeTelArgsQ
#ctorcount Benitoite.Release.Refinement.HasTypeArmsQ
#ctorcount Benitoite.Release.Refinement.HasTypeClausesQ

#check @Benitoite.Release.Refinement.Val
#print axioms RV.failed_without_mayFail
#print axioms Benitoite.Interval.normalToShared_mem
#print axioms Benitoite.Release.Refinement.embedVal_toApprox
#print Benitoite.Release.min64
#print Benitoite.Release.Integer64Value

#print axioms RV.normalToShared_iff
