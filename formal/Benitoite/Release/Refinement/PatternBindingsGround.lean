import Benitoite.Release.Refinement.PatternBindings

/-! # 照合結果の閉性（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement

private theorem ground_list_iff (vs : List Val) :
    Val.ClosedList 0 0 vs ↔ ∀ v ∈ vs, v.Ground := by
  induction vs <;> simp_all [Val.ClosedList,Val.Ground]

mutual
  theorem pattern_bindings_ground {p v ws} (hg : v.Ground)
      (hm : matchVal p v = some ws) : ∀ w ∈ ws, w.Ground := by
    cases p with
    | wild => cases Option.some.inj hm; intro w hw; cases hw
    | var => cases Option.some.inj hm; intro w hw; cases List.mem_singleton.mp hw; exact hg
    | const c | range c d =>
      cases v <;> simp only [matchVal] at hm
      all_goals first | cases hm | (split at hm <;> first | (cases Option.some.inj hm; intro w hw; cases hw) | cases hm)
    | con c ps =>
      cases v <;> simp only [matchVal] at hm
      all_goals try cases hm
      case con d ts vs =>
        split at hm
        · exact patterns_bindings_ground ((ground_list_iff _).mp hg.2) hm
        · cases hm
      case atError detail =>
        split at hm
        · apply patterns_bindings_ground (vs := detail.values) _ hm
          intro w hw
          simp only [Detail.values, List.mem_singleton] at hw
          subst hw
          exact groundVal_ground detail.publicTree.toVal_ground
        · cases hm
    | list before rest after =>
      cases v <;> simp only [matchVal] at hm
      all_goals try cases hm
      rename_i elems
      have hall := (ground_list_iff elems).mp hg
      by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length else before.length + after.length = elems.length)
      · rw [ite_eq_left hlen] at hm
        cases hl : matchList before (elems.take before.length) with
        | none => simp [hl] at hm
        | some left =>
          cases hr : matchList after (elems.drop (elems.length-after.length)) with
          | none => simp [hl,hr] at hm
          | some right =>
            have hleft := patterns_bindings_ground (fun v h => hall v (List.mem_of_mem_take h)) hl
            have hright := patterns_bindings_ground (fun v h => hall v (List.mem_of_mem_drop h)) hr
            have hmiddle : (Val.list ((elems.drop before.length).take
                (elems.length-(before.length+after.length)))).Ground :=
              (ground_list_iff _).mpr (fun v h => hall v (List.mem_of_mem_drop (List.mem_of_mem_take h)))
            simp only [hl,hr] at hm
            cases Option.some.inj hm
            intro w hw
            rcases List.mem_append.mp hw with hw | hw
            · rcases List.mem_append.mp hw with hw | hw
              · exact hleft w hw
              · cases rest with
                | none => cases hw
                | some rest => cases rest with
                  | skip => cases hw
                  | bind => cases List.mem_singleton.mp hw; exact hmiddle
            · exact hright w hw
      · rw [ite_eq_right hlen] at hm; cases hm
  termination_by sizeOf p
  theorem patterns_bindings_ground {ps vs ws} (hg : ∀ v ∈ vs, v.Ground)
      (hm : matchList ps vs = some ws) : ∀ w ∈ ws, w.Ground := by
    cases ps with
    | nil => cases vs <;> cases hm; intro w hw; cases hw
    | cons p ps =>
      cases vs with
      | nil => cases hm
      | cons v vs =>
        simp only [matchList] at hm
        cases hl : matchVal p v with
        | none => simp [hl] at hm
        | some left =>
          cases hr : matchList ps vs with
          | none => simp [hl,hr] at hm
          | some right =>
            simp only [hl,hr] at hm
            cases Option.some.inj hm
            intro w hw
            rcases List.mem_append.mp hw with hw | hw
            · exact pattern_bindings_ground (hg v List.mem_cons_self) hl w hw
            · exact patterns_bindings_ground (fun x hx => hg x (List.mem_cons_of_mem _ hx)) hr w hw
  termination_by sizeOf ps
end

theorem alternatives_bindings_ground {alts v ws} (hg : v.Ground)
    (hm : firstAlt v alts = some ws) : ∀ w ∈ ws, w.Ground := by
  induction alts with
  | nil => cases hm
  | cons alt alts ih =>
    simp only [firstAlt] at hm
    cases hp : matchVal alt.pat v with
    | none => exact ih (by simpa only [hp] using hm)
    | some bindings =>
      have hs : selectSlots bindings alt.slots = some ws := by simpa only [hp] using hm
      intro w hw
      exact pattern_bindings_ground hg hp w (selectSlots_mem hs w hw)

end Benitoite.Release.Refinement
