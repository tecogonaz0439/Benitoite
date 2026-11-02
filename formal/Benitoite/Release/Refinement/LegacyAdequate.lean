import Benitoite.Release.Refinement.LegacyStateInputs

namespace Benitoite.Release.Refinement
noncomputable section

mutual
  theorem legacy_value_adequate (v : Benitoite.Release.Val) (σ : PathEnv) : (embedVal v).Adequate σ := by
    cases v <;> simp only [embedVal,Val.Adequate]
    all_goals first
      | trivial
      | exact legacy_comp_adequate _ σ
      | exact legacy_values_adequate _ σ
      | exact legacy_value_adequate _ σ
      | exact ⟨legacy_values_adequate _ σ,legacy_values_adequate _ σ⟩
  theorem legacy_values_adequate (vs : List Benitoite.Release.Val) (σ : PathEnv) :
      adequateVals σ (embedVals vs) := by
    cases vs with
    | nil => trivial
    | cons v vs => exact ⟨legacy_value_adequate v σ,legacy_values_adequate vs σ⟩
  theorem legacy_comp_adequate (m : Benitoite.Release.Comp) (σ : PathEnv) : (embedComp m).Adequate σ := by
    cases m <;> simp only [embedComp,Comp.Adequate]
    all_goals first
      | exact legacy_comp_adequate _ σ
      | exact legacy_values_adequate _ σ
      | exact legacy_value_adequate _ σ
      | exact ⟨legacy_comp_adequate _ σ,legacy_comp_adequate _ σ⟩
      | exact ⟨legacy_value_adequate _ σ,legacy_values_adequate _ σ⟩
      | exact ⟨legacy_value_adequate _ σ,legacy_comp_adequate _ σ,legacy_comp_adequate _ σ⟩
      | exact ⟨legacy_value_adequate _ σ,legacy_arms_adequate _ σ⟩
      | exact ⟨legacy_value_adequate _ σ,legacy_comp_adequate _ σ⟩
      | exact ⟨legacy_comp_adequate _ σ,legacy_clauses_adequate _ σ⟩
      | exact ⟨legacy_value_adequate _ σ,legacy_value_adequate _ σ⟩
  theorem legacy_arms_adequate (xs : List Benitoite.Release.Arm) (σ : PathEnv) :
      adequateArms σ (embedArms xs) := by
    cases xs with
    | nil => trivial
    | cons x xs => cases x with
      | mk alts guard body => cases guard <;>
          simp only [embedArms,embedArm,adequateArms] <;>
          exact ⟨by first | trivial | exact legacy_comp_adequate _ σ,
            legacy_comp_adequate body σ,legacy_arms_adequate xs σ⟩
  theorem legacy_clauses_adequate (cs : List Benitoite.Release.Clause) (σ : PathEnv) :
      adequateClauses σ (embedClauses cs) := by
    cases cs with
    | nil => trivial
    | cons c cs => cases c <;> exact ⟨legacy_comp_adequate _ σ,legacy_clauses_adequate cs σ⟩
end

theorem legacy_held_value_adequate (v : Benitoite.Release.Val) (σ : PathEnv) : (embedHeldVal v).Adequate σ :=
  closeVal_adequate (by trivial) (legacy_value_adequate v σ)

theorem legacy_frame_adequate (f : Benitoite.Release.Frame) (σ : PathEnv) : (embedFrame f).Adequate σ := by
  cases f <;> simp only [embedFrame,Frame.Adequate,Closure.Adequate,Closure.pure,Capture.Adequate,
    Capture.empty,adequateCaptureSlots]
  all_goals first
    | trivial
    | exact ⟨trivial,legacy_comp_adequate _ σ⟩
    | exact legacy_value_adequate _ σ
    | exact ⟨trivial,legacy_clauses_adequate _ σ⟩
    | exact ⟨legacy_held_value_adequate _ σ,trivial,legacy_arms_adequate _ σ,trivial,legacy_comp_adequate _ σ⟩

theorem legacy_cont_adequate (k : Benitoite.Release.Cont) (σ : PathEnv) : (embedCont k).Adequate σ := by
  intro f hf
  obtain ⟨old,_,rfl⟩ := List.mem_map.mp hf
  exact legacy_frame_adequate old σ

theorem legacy_cell_adequate (c : Benitoite.Release.Cell) (σ : PathEnv) : (embedCell c).Adequate σ := by
  cases c <;> simp only [embedCell,Cell.Adequate]
  all_goals first
    | trivial
    | exact legacy_value_adequate _ σ
    | exact ⟨trivial,legacy_comp_adequate _ σ⟩
    | exact legacy_cont_adequate _ σ
    | (rename_i c; cases c <;> first | trivial | exact legacy_values_adequate _ σ)

theorem legacy_store_adequate (μ : Benitoite.Release.Store) (σ : PathEnv) : (embedStore μ).Adequate σ := by
  intro l c hc
  obtain ⟨old,_,rfl⟩ := Option.map_eq_some_iff.mp hc
  exact legacy_cell_adequate old σ

end
end Benitoite.Release.Refinement
