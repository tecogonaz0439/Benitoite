import Benitoite.Release.Refinement.ValueBinding

namespace Benitoite.Release.Refinement
open Order

noncomputable def SubstEnv.normRows (θ : SubstEnv) : SubstEnv :=
  { θ with rows := θ.rows.map Eff.norm }

@[simp] theorem SubstEnv.normRows_types (θ : SubstEnv) : θ.normRows.types = θ.types := rfl
@[simp] theorem SubstEnv.normRows_rows (θ : SubstEnv) : θ.normRows.rows = θ.rows.map Eff.norm := rfl
@[simp] theorem SubstEnv.normRows_ranges (θ : SubstEnv) : θ.normRows.ranges = θ.ranges := rfl
@[simp] theorem SubstEnv.normRows_values (θ : SubstEnv) : θ.normRows.values = θ.values := rfl

theorem SubstEnv.normRows_up (θ : SubstEnv) : θ.up.normRows = θ.normRows.up := by
  cases θ
  simp only [SubstEnv.normRows, SubstEnv.up, List.map_map]
  congr 2
  funext e
  exact Eff.norm_shiftV e 1 0

theorem substAtoms_normRows (es : List Eff) (atoms : Atom → Bool) :
    substAtoms (es.map Eff.norm) atoms = substAtoms es atoms := by
  funext x
  simp only [substAtoms, List.length_map, List.getElem?_map]
  congr 1
  apply congrArg (fun f => (List.range es.length).any f)
  funext i
  cases es[i]? with
  | none => rfl
  | some e => cases e; rfl

theorem Eff.fails_norm (e : Eff) : e.norm.fails = sortUnique tyCompare (Ty.normTys e.fails) := by
  cases e; rfl

theorem rowFails_normRows (es : List Eff) (atoms : Atom → Bool) :
    sortUnique tyCompare (Ty.normTys (rowFails (es.map Eff.norm) atoms)) =
      sortUnique tyCompare (Ty.normTys (rowFails es atoms)) := by
  apply sortUnique_eq_iff_mem.mpr
  intro t
  simp only [Ty.normTys_eq_map, List.mem_map, Eff.mem_rowFails,
    List.getElem?_map, Option.map_eq_some_iff]
  constructor
  · rintro ⟨x, ⟨i, f, ⟨g, hg, rfl⟩, ha, hx⟩, he⟩
    rw [Eff.fails_norm] at hx
    rw [Ty.normTys_eq_map] at hx
    obtain ⟨y, hy, rfl⟩ := List.mem_map.mp (Order.mem_sortUnique.mp hx)
    exact ⟨y, ⟨i, g, hg, ha, hy⟩, (Ty.norm_idem y).symm.trans he⟩
  · rintro ⟨x, ⟨i, f, hf, ha, hx⟩, he⟩
    have hx' : x.norm ∈ f.norm.fails := by
      rw [Eff.fails_norm]
      rw [Ty.normTys_eq_map]
      exact Order.mem_sortUnique.mpr (List.mem_map.mpr ⟨x, hx, rfl⟩)
    exact ⟨x.norm, ⟨i, f.norm, ⟨f, hf, rfl⟩, ha, hx'⟩, (Ty.norm_idem x).trans he⟩

mutual
  theorem Ty.bind_normRows (a : Ty) (θ : SubstEnv) :
      (a.rawBind θ.normRows).norm = (a.rawBind θ).norm := by
    cases a <;> simp only [Ty.rawBind, Ty.norm, SubstEnv.normRows_types, SubstEnv.normRows_values,
      SubstEnv.normRows_ranges, Ty.bind_normRows, normBindTys_normRows, Eff.bind_normRows, Tel.bind_normRows]
    case tapp i as =>
      rw [← rawApply_norm, normBindTys_normRows, rawApply_norm]
  theorem Tel.bind_normRows (t : Tel) (θ : SubstEnv) :
      Tel.norm (Tel.rawBind θ.normRows t) = Tel.norm (Tel.rawBind θ t) := by
    cases t with
    | done r e => simp only [Tel.rawBind, Tel.norm, Ty.bind_normRows, Eff.bind_normRows]
    | param n a t => simp only [Tel.rawBind, Tel.norm, Ty.bind_normRows,
        ← SubstEnv.normRows_up, Tel.bind_normRows]
  theorem normBindTys_normRows (as : List Ty) (θ : SubstEnv) :
      Ty.normTys (rawBindTys θ.normRows as) = Ty.normTys (rawBindTys θ as) := by
    cases as <;> simp only [rawBindTys, Ty.normTys, Ty.bind_normRows, normBindTys_normRows]
  theorem Eff.bind_normRows (e : Eff) (θ : SubstEnv) :
      Eff.norm (Eff.rawBind θ.normRows e) = Eff.norm (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, Eff.norm, SubstEnv.normRows_rows, SubstEnv.normRows_ranges, substAtoms_normRows, Ty.normTys_append]
      congr 1
      apply sortUnique_append_congr
      · exact congrArg _ (normBindTys_normRows fs θ)
      · exact rowFails_normRows θ.rows a
end

theorem Ty.subst_norm_typeImages (a : Ty) (ts : List Ty) (es : List Eff) :
    a.subst (ts.map Ty.norm) es = a.subst ts es := by
  apply Ty.bind_sameTypes
  refine ⟨?_, rfl, rfl, rfl⟩
  intro i
  simp only [typeEnvAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
    List.length_map, List.getElem?_map]
  split
  · cases ht : ts[i]? with
    | none => rfl
    | some a => simp only [Option.map_some, Option.getD_some, shiftTypes_zero, Ty.norm_idem]
  · rfl

theorem Ty.subst_norm_rowImages (a : Ty) (ts : List Ty) (es : List Eff) :
    a.subst ts (es.map Eff.norm) = a.subst ts es := by
  have he : typeEnvAt 0 ts (es.map Eff.norm) = (typeEnvAt 0 ts es).normRows := by
    have hz : shiftRowsTypes 0 0 = id := funext (fun e => shiftRowsTypes_zero e 0)
    simp only [typeEnvAt, SubstEnv.normRows, hz, List.map_id]
  change (a.rawBind _).norm = (a.rawBind _).norm
  rw [he]
  exact a.bind_normRows _

theorem Ty.subst_norm_images_all (a : Ty) (ts : List Ty) (es : List Eff) :
    a.subst (ts.map Ty.norm) (es.map Eff.norm) = a.subst ts es := by
  rw [Ty.subst_norm_typeImages, Ty.subst_norm_rowImages]

theorem Ty.substV_subst_closed_rows {nt a} (hw : Ty.WF 0 nt 0 a)
    (ts : List Ty) (es : List Eff) (ν : ObservationEnv) :
    (a.subst ts es).substV ν = a.subst (ts.map (Ty.substV ν)) (es.map (Eff.substV ν)) := by
  have hs := Ty.substAt_substV a 0 ts es ν
  rw [Ty.substV_of_wf_zero hw] at hs
  change (a.subst ts es).substV ν = a.subst _ _ at hs
  rw [hs]
  have he : Ty.substV ν = (fun t => (t.rawSubstV ν).norm) := by
    funext t; simp only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind]
  have hf : Eff.substV ν = (fun e => (Eff.rawSubstV ν e).norm) := by
    funext e; simp only [Eff.substV, Eff.bind, SubstEnv.valuesOnly, ← Eff.rawSubstV_eq_rawBind]
  rw [he, hf]
  simpa only [List.map_map, Function.comp_def] using
    (Ty.subst_norm_images_all a (ts.map (Ty.rawSubstV ν)) (es.map (Eff.rawSubstV ν))).symm

theorem Ty.subst_shiftV_closed_rows {nt a} (hw : Ty.WF 0 nt 0 a)
    (ts : List Ty) (es : List Eff) (k c : Nat) :
    (a.subst ts es).shiftV k c = a.subst (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) := by
  have hs := Ty.substAt_substV a 0 ts es (fun i => some (.var (shiftIndex k c i)))
  rw [Ty.substV_of_wf_zero hw] at hs
  have he : Ty.rawSubstV (fun i => some (.var (shiftIndex k c i))) = Ty.shiftV k c := by
    funext t; rw [← renameTy_eq_rawSubstV, ← Ty.shiftV_eq_renameTy]
  have hf : Eff.rawSubstV (fun i => some (.var (shiftIndex k c i))) = Eff.shiftV k c := by
    funext e; rw [← renameEff_eq_rawSubstV, ← Eff.shiftV_eq_renameEff]
  change (a.subst ts es).substV (fun i => some (.var (shiftIndex k c i))) = a.subst _ _ at hs
  have hn : ((a.subst ts es).shiftV k c).norm = (a.subst ts es).shiftV k c := by
    rw [Ty.norm_shiftV]; exact congrArg (Ty.shiftV k c) (Ty.norm_idem _)
  simpa only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind, he, hf, hn] using hs

end Benitoite.Release.Refinement
