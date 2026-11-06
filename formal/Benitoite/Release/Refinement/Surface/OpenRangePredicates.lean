import Benitoite.Release.Refinement.Surface.OpenSurfaceFormation

/-! # 範囲の具体化と、表層の述語の宣言の形成

述語の観測は範囲の注釈を読まない。宣言の照合と観測型を保った文脈へ、元の有限な宣言の根拠を移す。
-/
namespace Benitoite.Release.Refinement.Surface.OpenSurface
noncomputable section

mutual
  private theorem obs_ranges (a : Ty) (ρ : Nat → RangeIx) :
      (a.rawMapRanges ρ).observationType = a.observationType := by
    cases a <;> simp only [Ty.rawMapRanges, Ty.observationType]
    all_goals first | rfl | exact obs_ranges _ ρ | rw [obs_ranges_tys]
  private theorem obs_ranges_tys (as : List Ty) (ρ : Nat → RangeIx) :
      observationTypes (mapRangesTys ρ as) = observationTypes as := by
    cases as <;> simp only [mapRangesTys, observationTypes, obs_ranges, obs_ranges_tys]
end

private theorem data_core_ranges {a : Ty} {d ts} (h : a.norm.core = .data d ts)
    (ρ : Nat → RangeIx) :
    (a.rawMapRanges ρ).norm.core = .data d (Ty.normTys (mapRangesTys ρ ts)) := by
  have hh := congrArg (fun t => (t.rawMapRanges ρ).norm) h
  simp only [Ty.core_norm, Ty.norm_rawMapRanges] at hh
  rw [Ty.core_norm, Ty.core_rawMapRanges, hh]
  rfl

private theorem data_ranges {P Γ t d ts} (h : Term.HasData P Γ t d ts)
    (ρ : Nat → RangeIx) : Term.HasData P (Γ.rawMapRanges ρ) t d ts := by
  match h with
  | .widen hr hs => exact .widen (data_ranges hr ρ) hs
  | .var (i := i) (a := a) hi hd =>
    have hl : (Γ.rawMapRanges ρ)[i]? = some (some (a.rawMapRanges ρ)) := by
      simp only [Ctx.rawMapRanges, List.getElem?_map, hi, Option.map_some]
    refine .widen (.var hl (data_core_ranges hd ρ)) ?_
    change TypeArgsLe P [] [] _ _ _
    rw [observationTypes_norm, obs_ranges_tys]
    simpa only [DataObservationLe, Ty.normTys_eq_map, mapRangesTys_eq_map, List.length_map] using
      DataObservationLe.refl P d ts
  | .value hc hd hn hl => exact .value hc hd hn hl
  | .field hr hc hd hn ha hw hs hv => exact .field (data_ranges hr ρ) hc hd hn ha hw hs hv

private theorem field_ranges {P C Γ t ref} (h : FieldRef.Declared P C Γ t ref)
    (ρ : Nat → RangeIx) : FieldRef.Declared P C (Γ.rawMapRanges ρ) t ref := by
  obtain ⟨ts,cd,a,ht,hc,hd,hn,ha,hw,hs⟩ := h
  exact ⟨ts,cd,a,data_ranges ht ρ,hc,hd,hn,ha,hw,hs⟩

mutual
  theorem term_ranges {P C Γ t} (h : Term.Declared P C Γ t)
      (ρ : Nat → RangeIx) : Term.Declared P C (Γ.rawMapRanges ρ) t := by
    cases t <;> simp only [Term.Declared] at h ⊢
    all_goals first
      | trivial
      | exact term_ranges h ρ
      | exact ⟨term_ranges h.1 ρ, term_ranges h.2 ρ⟩
      | skip
    case var i =>
      obtain ⟨a,hi,ho⟩ := h
      exact ⟨a.rawMapRanges ρ, by simp [Ctx.rawMapRanges, List.getElem?_map, hi],
        (Ty.ordinary_rawMapRanges a ρ).mpr ho⟩
    case field ref t => exact ⟨term_ranges h.1 ρ, field_ranges h.2 ρ⟩
    case listValue xs => exact slots_ranges h ρ
    case setValue xs => exact slots_ranges h ρ
    case mapValue ks vs => exact ⟨slots_ranges h.1 ρ, slots_ranges h.2 ρ⟩
    case dataValue c xs => exact ⟨slots_ranges h.1 ρ,h.2⟩
  private theorem slots_ranges {P C Γ xs} (h : declaredSlots P C Γ xs)
      (ρ : Nat → RangeIx) : declaredSlots P C (Γ.rawMapRanges ρ) xs := by
    cases xs with
    | nil => trivial
    | cons x xs =>
      refine ⟨?_,slots_ranges h.2 ρ⟩
      cases x with
      | none => trivial
      | some t => exact term_ranges h.1 ρ
end

theorem pred_ranges {P C Γ self p} (h : Pred.Declared P C Γ self p)
    (ρ : Nat → RangeIx) :
    Pred.Declared P C (Γ.rawMapRanges ρ) (self.map (Ty.rawMapRanges ρ)) p := by
  have ctx : (Γ.rawMapRanges ρ).declarationSelf (self.map (Ty.rawMapRanges ρ)) =
      (Γ.declarationSelf self).rawMapRanges ρ := by
    cases self <;> simp only [Ctx.declarationSelf, Option.map, Ctx.rawMapRanges_extend]
  induction p <;> simp only [Pred.Declared, ctx] at h ⊢
  all_goals first
    | trivial
    | exact term_ranges h ρ
    | exact ⟨term_ranges h.1 ρ,term_ranges h.2 ρ⟩
    | exact ⟨by assumption,by assumption⟩
    | assumption
    | skip
  case constructorIs t c =>
    obtain ⟨ht,d,ts,cd,hd,hc,hn⟩ := h
    exact ⟨term_ranges ht ρ,d,ts,cd,data_ranges hd ρ,hc,hn⟩
  case and p q ih jh => exact ⟨ih h.1,jh h.2⟩
  case or p q ih jh => exact ⟨ih h.1,jh h.2⟩
  case not p ih => exact ih h


end
end Benitoite.Release.Refinement.Surface.OpenSurface
