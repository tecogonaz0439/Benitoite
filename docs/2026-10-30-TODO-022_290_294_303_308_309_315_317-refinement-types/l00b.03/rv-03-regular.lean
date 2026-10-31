import Benitoite.Release.Refinement.Context.Capture
namespace Benitoite.Release.Refinement.RV03
noncomputable section

theorem hideMap (Γ : Ctx) : ShiftMap 0 0 Γ (hideConts Γ) := by
  refine ⟨by simp [hideConts], ?_⟩
  intro i a hi ho
  simpa [shiftIndex_zero, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi, ho⟩

theorem outerMap (Γ : Ctx) (i : Nat) : ShiftMap 0 0 (Γ.outer i) ((hideConts Γ).outer i) := by
  refine ⟨by simp [hideConts], ?_⟩
  intro j a hj ho
  obtain ⟨h1, h2⟩ := Ctx.lookup_outer.mp hj
  simpa [shiftIndex_zero, Ty.shiftV_zero] using
    Ctx.lookup_outer.mpr ⟨h1, hideConts_lookup.mpr ⟨h2, ho⟩⟩

/-- 継続を隠した文脈も Regular。 -/
theorem regular_hide {P C Γ} (h : Ctx.Regular P C Γ) : Ctx.Regular P C (hideConts Γ) := by
  have hm := hideMap Γ
  have ann : ∀ (i : Nat) (a : Ty), (hideConts Γ)[i]? = some (some a) → Ty.Annotation P C (hideConts Γ) a := by
    intro i a hx
    have hl := (hideConts_lookup.mp hx).1
    simpa [Ty.shiftV_zero] using
      hm.annotation (a := a) ⟨h.wf i a hl, h.sorted i a hl, h.declared i a hl⟩
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro i a hx; simpa [hideConts] using (ann i a hx).wf
  · intro i a hx; exact (ann i a hx).sorted
  · intro i a hx; exact (ann i a hx).declared
  · intro i a hx
    have hl := (hideConts_lookup.mp hx).1
    have hr := (outerMap Γ i).references
    have hh := (h.ordered i a hl).rawSubstV hr
    rw [Ty.rawSubstV_eq_rawBind] at hh
    change Ty.References _ (renameTy (shiftIndex 0 0) a) at hh
    simpa only [← Ty.shiftV_eq_renameTy, Ty.shiftV_zero] using hh

/-- 非依存の引数列の文脈も Regular。 -/
theorem regular_bindParams {P C} (n : Nat) : ∀ {ps : List Ty} {Γ : Ctx}, ps.length = n →
    Ctx.Regular P C Γ → TypeAnnotations P C Γ ps → Ctx.Regular P C (bindParams Γ ps) := by
  induction n with
  | zero =>
    intro ps Γ hn h _
    cases ps with
    | nil =>
      have he : (fun x : Option Ty => Option.map (Ty.shiftV 0 0) x) = id := by
        funext x; cases x <;> simp [Ty.shiftV_zero]
      have : List.map (Option.map (Ty.shiftV 0 0)) Γ = Γ := by
        simpa only [List.map_id] using congrArg (fun f => List.map f Γ) he
      simpa [bindParams, this] using h
    | cons _ _ => cases hn
  | succ n ih =>
    intro ps Γ hn h ha
    cases ps with
    | nil => cases hn
    | cons a ps =>
      rw [← bindParams_cons]
      apply ih (by simpa using hn) (h.extend (ha a List.mem_cons_self))
      intro b hb
      obtain ⟨c, hc, rfl⟩ := List.mem_map.mp hb
      exact (ShiftMap.outerValue Γ (some (a.shiftV 1 0))).annotation (ha c (List.mem_cons_of_mem _ hc))
#print axioms regular_hide
#print axioms regular_bindParams
end
end Benitoite.Release.Refinement.RV03
