import Benitoite.Release.Refinement.Surface.PredicateSimulationValues
import Benitoite.Release.Refinement.Surface.PredicateSimulationEffects

/-! # 閉包の本体の対応による正常値の観測

正常値は値の対応の同値閉包で比較する。失敗の全payloadと終了コードは等号で保持する。
既存の生の終端観測を変更せず、その正常値だけを商へ写す。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 値の対応から生成される、反射的・対称的・推移的な同値関係。 -/
inductive ValueEquivalent (source : Program) (rows : PredicateProjection.Table.Rows) : Val → Val → Prop
  | related {v w} : Value source rows v w → ValueEquivalent source rows v w
  | refl (v) : ValueEquivalent source rows v v
  | symm {v w} : ValueEquivalent source rows v w → ValueEquivalent source rows w v
  | trans {u v w} : ValueEquivalent source rows u v → ValueEquivalent source rows v w →
      ValueEquivalent source rows u w

def valueSetoid (source : Program) (rows : PredicateProjection.Table.Rows) : Setoid Val where
  r := ValueEquivalent source rows
  iseqv := ⟨ValueEquivalent.refl,ValueEquivalent.symm,ValueEquivalent.trans⟩

abbrev ObservedValue (source : Program) (rows : PredicateProjection.Table.Rows) :=
  Quotient (valueSetoid source rows)

def observeValue (source : Program) (rows : PredicateProjection.Table.Rows) (v : Val) :
    ObservedValue source rows := Quotient.mk _ v

/-- 対応する値は、同じ正常観測を持つ。 -/
theorem Value.observed {source rows v w} (related : Value source rows v w) :
    observeValue source rows v = observeValue source rows w :=
  Quotient.sound (.related related)

private def constantValue : Val → Option Const
  | .const c => some c
  | _ => none

private theorem Value.constantValue {source rows v w} (related : Value source rows v w) :
    constantValue v = constantValue w := by cases related <;> rfl

private theorem ValueEquivalent.constantValue {source rows v w}
    (related : ValueEquivalent source rows v w) : constantValue v = constantValue w := by
  induction related with
  | related h => exact h.constantValue
  | refl => rfl
  | symm h ih => exact ih.symm
  | trans h g ih jh => exact ih.trans jh

/-- 同値閉包を取っても、異なる定数を同じ正常観測にはしない。 -/
theorem observeValue_constants {source rows} (c d : Const) :
    observeValue source rows (.const c) = observeValue source rows (.const d) ↔ c = d := by
  constructor
  · intro same
    exact Option.some.inj (ValueEquivalent.constantValue (Quotient.exact same))
  · intro same
    cases same
    rfl

/-- 有限の項の観測も、正常値の同値類で一意に定まる。 -/
theorem ValueEquivalent.toTerm {source rows v w} (related : ValueEquivalent source rows v w) :
    v.toTerm? = w.toTerm? := by
  induction related with
  | related h => exact h.toTerm
  | refl => rfl
  | symm h ih => exact ih.symm
  | trans h g ih jh => exact ih.trans jh

def observeTerm (source : Program) (rows : PredicateProjection.Table.Rows) :
    ObservedValue source rows → Option Term :=
  Quotient.lift (fun v => v.toTerm?) (fun _ _ h => h.toTerm)

/-- 項への射影は、生の値から観測しても正常値の同値類から観測しても同じである。 -/
theorem observeTerm_value (source : Program) (rows : PredicateProjection.Table.Rows) (v : Val) :
    observeTerm source rows (observeValue source rows v) = v.toTerm? := rfl

inductive TerminalObservation (source : Program) (rows : PredicateProjection.Table.Rows) where
  | value (value : ObservedValue source rows)
  | error (payload : List ErrKind)
  | exit (code : Int) (payload : List ErrKind)

def observeTerminal (source : Program) (rows : PredicateProjection.Table.Rows) :
    SafeCheckErasure.TerminalObservation → TerminalObservation source rows
  | .value v => .value (observeValue source rows v)
  | .error payload => .error payload
  | .exit code payload => .exit code payload

def terminal (source : Program) (rows : PredicateProjection.Table.Rows) (state : State) :
    Option (TerminalObservation source rows) :=
  (SafeCheckErasure.terminal state).map (observeTerminal source rows)

/-- 正常なBooleanの両値を区別し、有限の項の観測もそのまま読む。 -/
example (source : Program) (rows : PredicateProjection.Table.Rows) :
    observeValue source rows (.const (.boolean true)) ≠ observeValue source rows (.const (.boolean false)) ∧
      observeTerm source rows (observeValue source rows (.const (.boolean true))) =
        (.const (.boolean true) : Val).toTerm? := by
  refine ⟨?_,observeTerm_value _ _ _⟩
  intro same
  have impossible := (observeValue_constants _ _).mp same
  cases impossible

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
