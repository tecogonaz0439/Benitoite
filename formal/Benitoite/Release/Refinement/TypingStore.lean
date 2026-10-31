import Benitoite.Release.Refinement.TypingShift

namespace Benitoite.Release.Refinement

theorem shiftIndex_zero (c : Nat) : shiftIndex 0 c = id := by
  funext i; simp [shiftIndex]

theorem shiftIndex_add (k : Nat) : shiftIndex k 0 = (fun i => i+k) := by
  funext i; simp [shiftIndex]

theorem Ty.shiftV_zero (a : Ty) (c : Nat) : a.shiftV 0 c = a := by
  rw [Ty.shiftV_eq_renameTy, shiftIndex_zero, renameTy_id]

theorem Eff.shiftV_zero (e : Eff) (c : Nat) : Eff.shiftV 0 c e = e := by
  rw [Eff.shiftV_eq_renameEff, shiftIndex_zero, renameEff_id]

theorem Pred.shiftV_zero (p : Pred) (c : Nat) : p.shiftV 0 c = p := by
  simp only [Pred.shiftV, shiftIndex_zero]
  exact predBind_id p

theorem Tel.shiftV_zero (t : Tel) (c : Nat) : Tel.shiftV 0 c t = t := by
  rw [Tel.shiftV_eq_rawBind, shiftIndex_zero]
  exact Tel.rawBind_id t

theorem HasTypeVQ.hide_context {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store)
    (store' : StoreTy) (hpres : store.PreservesNormals store') :
    HasTypeVQ P B store' Q C (hideConts Γ) Φ v a := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    constructor
    · simp [hideConts]
    · intro i a hi ho
      simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi,ho⟩
  have ht := h.shift_values (store' := store') hA hstore hpres hm (Ξ := Φ) (fun p hp => by
    rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using ht

theorem HasTypeTelArgsQ.hide_context {P B store Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
    (store' : StoreTy) (hpres : store.PreservesNormals store') :
    HasTypeTelArgsQ P B store' Q C (hideConts Γ) Φ vs t a e := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    constructor
    · simp [hideConts]
    · intro i a hi ho
      simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi,ho⟩
  have hh := h.shift_values hA hstore hpres hm (Ξ := Φ) (fun p hp => by
    rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.renameList_identity, Ty.shiftV_zero, Eff.shiftV_zero, Tel.shiftV_zero] using hh

theorem HasTypeVQ.weaken_empty {P B Q C Γ Φ v a store}
    (h : HasTypeVQ P B StoreTy.empty Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) : HasTypeVQ P B store Q C Γ Φ v a := by
  have hm : ShiftMap 0 0 Γ Γ := ⟨by omega, by
    intro i a hi _; simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hi⟩
  have hh := h.shift_values hA StoreTy.WF.empty (StoreTy.Extends.empty store).preservesNormals hm
    (Ξ := Φ) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using hh

theorem HasTypeCQ.weaken_empty {P B Q C Γ Φ R m a e L store}
    (h : HasTypeCQ P B StoreTy.empty Q C Γ Φ R m a e L) (hA : Builtins.ValueAssumptions P B) : HasTypeCQ P B store Q C Γ Φ R m a e L := by
  have hm : FullShiftMap 0 0 Γ Γ := ⟨by omega, by
    intro i a hi; simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hi⟩
  have hh := h.shift_values (L' := L) hA StoreTy.WF.empty (StoreTy.Extends.empty store) hm (.refl _)
    (Ξ := Φ) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Comp.rename_identity, Ty.shiftV_zero, Eff.shiftV_zero,
    Option.map_id, id_eq, show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hh


end Benitoite.Release.Refinement
