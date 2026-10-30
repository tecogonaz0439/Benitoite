import Benitoite.Release.Refinement.ValueRegularity

/-!
# 項の束縛と型注釈の値置換

実際の値の像と整数項の像を接続し、自己束縛を越えて像を移す。
-/
namespace Benitoite.Release.Refinement

mutual
  theorem Val.toTerm_rename (v : Val) (ξ : Nat → Nat) :
      (v.rename ξ).toTerm? = v.toTerm?.map (termBind (fun i => some (.var (ξ i)))) := by
    cases v <;> try rfl
    case const c => cases c <;> rfl
    all_goals simp only [Val.rename, Val.toTerm?, Val.toTermSlots_rename,
      termBind_listValue, termBind_mapValue, termBind_setValue, termBind_dataValue,
      Option.map_some]
  theorem Val.toTermSlots_rename (vs : List Val) (ξ : Nat → Nat) :
      Val.toTermSlots (Val.renameList ξ vs) =
        bindSlots (fun i => some (.var (ξ i))) (Val.toTermSlots vs) := by
    cases vs with
    | nil => rfl
    | cons v vs =>
      simp only [Val.renameList, Val.toTermSlots, Val.toTerm_rename,
        Val.toTermSlots_rename, bindSlots]
      congr 1
      cases v.toTerm? <;> simp only [slotBind, Option.map_none, Option.map_some, termBind?_renaming]
end

mutual
  theorem Val.toTerm_subst_optional (v : Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
      (v.subst ν ρ).toTerm? = v.toTerm?.bind (termBind? (valEnv ν).values) := by
    cases v <;> try rfl
    case const c => cases c <;> rfl
    all_goals simp only [Val.subst, Val.toTerm?, Val.toTermSlots_subst,
      termBind?, Option.bind_some]
  theorem Val.toTermSlots_subst (vs : List Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
      Val.toTermSlots (Val.substList ν vs ρ) = bindSlots (valEnv ν).values (Val.toTermSlots vs) := by
    cases vs with
    | nil => rfl
    | cons v vs =>
      simp only [Val.substList, Val.toTermSlots, Val.toTerm_subst_optional,
        Val.toTermSlots_subst, bindSlots]
      congr 1
      cases v.toTerm? <;> rfl
end

theorem Val.toTerm_subst_slots (vs : List Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
    (Val.substList ν vs ρ).map Val.toTerm? =
      (vs.map Val.toTerm?).map (slotBind (valEnv ν).values) := by
  rw [← Val.toTermSlots_eq_map, Val.toTermSlots_subst, ← Val.toTermSlots_eq_map]
  induction Val.toTermSlots vs <;> simp_all [bindSlots]

theorem Val.observe_rename (v : Val) (ξ : Nat → Nat) :
    (v.rename ξ).toTerm?.getD (.integer 0) =
      termBind (fun i => some (.var (ξ i))) (v.toTerm?.getD (.integer 0)) := by
  rw [Val.toTerm_rename]
  cases v.toTerm? <;> rfl

def SubstEnv.upN (k : Nat) (θ : SubstEnv) : SubstEnv :=
  Nat.rec θ (fun _ t => t.up) k

theorem renameTy_id (a : Ty) : renameTy id a = a := by
  exact Ty.rawBind_id a

theorem renameEff_id (e : Eff) : renameEff id e = e := by
  exact Eff.rawBind_id e

@[simp] theorem renameTy_identity : renameTy id = id := funext renameTy_id
@[simp] theorem renameEff_identity : renameEff id = id := funext renameEff_id

private theorem renameKind_id (k : BuilderKind) : renameKind id k = k := by
  cases k <;> simp [renameKind, renameTy_id]

private theorem localRename_id (r : LocalRef) : LocalRef.rename id r = r := by
  cases r <;> rfl

theorem upRen_identity (k : Nat) : upRen k id = id := by
  funext i
  unfold upRen
  split <;> simp_all <;> omega

mutual
  theorem Val.rename_identity (v : Val) : v.rename id = v := by
    cases v <;> simp [Val.rename, upRen_identity,
      Val.renameList_identity, Comp.rename_identity, Val.rename_identity, Tel.rawBind_id]
  theorem Val.renameList_identity (vs : List Val) : Val.renameList id vs = vs := by
    cases vs <;> simp [Val.renameList, Val.rename_identity, Val.renameList_identity]
  theorem Comp.rename_identity (m : Comp) : m.rename id = m := by
    cases m <;> simp [Comp.rename, renameKind_id, localRename_id, upRen_identity,
      Val.rename_identity, Val.renameList_identity, Comp.rename_identity,
      Arm.renameList_identity, Clause.renameList_identity]
  theorem Arm.renameList_identity (as : List Arm) : Arm.renameList id as = as := by
    cases as with
    | nil => rfl
    | cons a as => cases a with
      | mk alts guard body => cases guard <;>
          simp [Arm.renameList, upRen_identity, Comp.rename_identity, Arm.renameList_identity]
  theorem Clause.renameList_identity (cs : List Clause) : Clause.renameList id cs = cs := by
    cases cs with
    | nil => rfl
    | cons c cs => cases c <;>
        simp [Clause.renameList, renameTy_id, upRen_identity, Comp.rename_identity, Clause.renameList_identity]
end

theorem upSubst_zero (σ : Nat → Val) : upSubst 0 σ = σ := by
  funext i
  simp only [upSubst, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero]
  exact Val.rename_identity _

theorem valEnv_upSubst_one (σ : Nat → Val) : valEnv (upSubst 1 σ) = (valEnv σ).up := by
  change SubstEnv.mk Ty.tvar [] [] _ = SubstEnv.mk Ty.tvar [] [] _
  congr 1
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [upSubst, Nat.succ_lt_succ_iff, Nat.not_lt_zero,
      ↓reduceIte, Nat.add_one_sub_one, Val.toTerm_rename, upValues, valEnv]

theorem valEnv_upSubst (k : Nat) (σ : Nat → Val) :
    valEnv (upSubst k σ) = SubstEnv.valuesOnly (upTerms k (valEnv σ).values) := by
  change SubstEnv.mk Ty.tvar [] [] _ = SubstEnv.mk Ty.tvar [] [] _
  congr 1
  funext i
  simp only [upSubst, upTerms]
  split
  · rfl
  · exact Val.toTerm_rename _ _

theorem upTerms_succ (k : Nat) (σ : ObservationEnv) : upTerms (k+1) σ = upValues (upTerms k σ) := by
  funext i
  cases i with
  | zero => simp [upTerms, upValues]
  | succ i =>
    simp only [upValues, upTerms, Nat.succ_lt_succ_iff, Nat.add_sub_add_right]
    split
    · simp
    · cases he : σ (i-k) with
      | none => rfl
      | some t =>
        simp only [Option.map_some, termBind_comp]
        congr 1

theorem valEnv_upN (k : Nat) (σ : Nat → Val) :
    valEnv (upSubst k σ) = (valEnv σ).upN k := by
  rw [valEnv_upSubst]
  induction k with
  | zero => simp only [upTerms_zero, SubstEnv.upN]; rfl
  | succ k ih =>
    change SubstEnv.valuesOnly (upTerms (k+1) (valEnv σ).values) = ((valEnv σ).upN k).up
    rw [← ih, upTerms_succ]
    rfl

mutual
  theorem Ty.rawSubstV_comp (a : Ty) (σ τ : ObservationEnv) :
      (a.rawSubstV σ).rawSubstV τ = a.rawSubstV (fun i => (σ i).bind (termBind? τ)) := by
    cases a <;> simp only [Ty.rawSubstV, Ty.rawSubstV_comp, substVTys_comp, Eff.rawSubstV_comp, Tel.rawSubstV_comp]
    case refined a p => rw [predBind_comp, upValues_comp]
  theorem Tel.rawSubstV_comp (t : Tel) (σ τ : ObservationEnv) :
      Tel.rawSubstV τ (Tel.rawSubstV σ t) = Tel.rawSubstV (fun i => (σ i).bind (termBind? τ)) t := by
    cases t <;> simp only [Tel.rawSubstV, Ty.rawSubstV_comp, Eff.rawSubstV_comp, Tel.rawSubstV_comp, upValues_comp]
  theorem substVTys_comp (as : List Ty) (σ τ : ObservationEnv) :
      substVTys τ (substVTys σ as) = substVTys (fun i => (σ i).bind (termBind? τ)) as := by
    cases as <;> simp only [substVTys, Ty.rawSubstV_comp, substVTys_comp]
  theorem Eff.rawSubstV_comp (e : Eff) (σ τ : ObservationEnv) :
      Eff.rawSubstV τ (Eff.rawSubstV σ e) = Eff.rawSubstV (fun i => (σ i).bind (termBind? τ)) e := by
    cases e; simp only [Eff.rawSubstV, substVTys_comp]
end

theorem renameTy_eq_rawSubstV (ξ : Nat → Nat) (a : Ty) :
    renameTy ξ a = a.rawSubstV (fun i => some (.var (ξ i))) := (Ty.rawSubstV_eq_rawBind _ _).symm

theorem renameEff_eq_rawSubstV (ξ : Nat → Nat) (e : Eff) :
    renameEff ξ e = Eff.rawSubstV (fun i => some (.var (ξ i))) e := (Eff.rawSubstV_eq_rawBind _ _).symm

theorem Ty.bind_shiftV_values (a : Ty) (k : Nat) (σ : Nat → Val) :
    substTyValues (upSubst k σ) (a.shiftV k 0) = (substTyValues σ a).shiftV k 0 := by
  unfold substTyValues Ty.bind
  rw [valEnv_upSubst]
  simp only [valEnv]
  change ((a.shiftV k 0).rawBind ⟨Ty.tvar, [], [], _⟩).norm = _
  rw [← Ty.rawSubstV_eq_rawBind, Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV,
    Ty.rawSubstV_comp, ← Ty.norm_shiftV, Ty.shiftV_eq_renameTy,
    renameTy_eq_rawSubstV, ← Ty.rawSubstV_eq_rawBind, Ty.rawSubstV_comp]
  congr 2
  funext i
  have hi : ¬ i+k < k := by omega
  simp [termBind?, map_rename_eq_bind, shiftIndex, upTerms, hi]

theorem Eff.bind_shiftV_values (e : Eff) (k : Nat) (σ : Nat → Val) :
    substEffValues (upSubst k σ) (Eff.shiftV k 0 e) = Eff.shiftV k 0 (substEffValues σ e) := by
  unfold substEffValues Eff.bind
  rw [valEnv_upSubst]
  simp only [valEnv]
  change (Eff.rawBind ⟨Ty.tvar, [], [], _⟩ (Eff.shiftV k 0 e)).norm = _
  rw [← Eff.rawSubstV_eq_rawBind, Eff.shiftV_eq_renameEff, renameEff_eq_rawSubstV,
    Eff.rawSubstV_comp, ← Eff.norm_shiftV, Eff.shiftV_eq_renameEff,
    renameEff_eq_rawSubstV, ← Eff.rawSubstV_eq_rawBind, Eff.rawSubstV_comp]
  congr 2
  funext i
  have hi : ¬ i+k < k := by omega
  simp [termBind?, map_rename_eq_bind, shiftIndex, upTerms, hi]

theorem Ty.bind_fn (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (θ : SubstEnv) :
    (Ty.fn ns ps r e).bind θ = .fn ns (ps.map (Ty.bind θ)) (r.bind θ) (Eff.bind θ e) := by
  simp only [Ty.bind, Ty.rawBind, Ty.norm, Eff.bind, rawBindTys_eq_map,
    Ty.normTys_eq_map, List.map_map]
  rfl

@[simp] theorem valEnv_valuesOnly (σ : Nat → Val) :
    SubstEnv.valuesOnly (valEnv σ).values = valEnv σ := rfl

theorem substTyValues_eq_bind (σ : Nat → Val) : substTyValues σ = Ty.bind (valEnv σ) := rfl
theorem substEffValues_eq_bind (σ : Nat → Val) : substEffValues σ = Eff.bind (valEnv σ) := rfl

theorem Pred.shiftV_lift (p : Pred) (k c : Nat) :
    p.lift.shiftV k (c+1) = (p.shiftV k c).lift := by
  simp only [Pred.shiftV, ← upValues_shiftIndex, predBind_lift]

theorem upRen_shiftIndex (n k c : Nat) :
    upRen n (shiftIndex k c) = shiftIndex k (c+n) := by
  funext i
  unfold upRen shiftIndex
  by_cases h : i<n
  · simp only [h, ↓reduceIte, show i<c+n by omega]
  · simp only [h, ↓reduceIte]
    by_cases h' : i<c+n <;> simp only [h', ↓reduceIte]
    · simp only [show i-n<c by omega, ↓reduceIte]; omega
    · simp only [show ¬ i-n<c by omega, ↓reduceIte]; omega

theorem Ty.bind_data (d : DataName) (ts : List Ty) (θ : SubstEnv) :
    (Ty.data d ts).bind θ = .data d (ts.map (Ty.bind θ)) := by
  simp only [Ty.bind, Ty.rawBind, Ty.norm, rawBindTys_eq_map, Ty.normTys_eq_map, List.map_map]
  rfl

theorem Ty.subst_shiftV_closed {nt a} (hw : Ty.WF 0 nt 0 a) (ts : List Ty) (k c : Nat) :
    (a.subst ts []).shiftV k c = a.subst (ts.map (Ty.shiftV k c)) [] := by
  have hs := Ty.substV_subst_closed hw ts (fun i => some (.var (shiftIndex k c i)))
  rw [bindDataArgs_eq_norm, Ty.subst_norm_images] at hs
  have hi : (a.subst ts []).norm = a.subst ts [] := Ty.norm_idem _
  have hn : ((a.subst ts []).shiftV k c).norm = (a.subst ts []).shiftV k c := by
    rw [Ty.norm_shiftV, hi]
  have he : Ty.rawSubstV (fun i => some (.var (shiftIndex k c i))) = Ty.shiftV k c := by
    funext t
    rw [← renameTy_eq_rawSubstV, ← Ty.shiftV_eq_renameTy]
  simpa only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind,
    he, hn, substVTys_eq_map] using hs

@[simp] theorem Val.toTermSlots_length (vs : List Val) : (Val.toTermSlots vs).length = vs.length := by
  simp only [Val.toTermSlots_eq_map, List.length_map]

/-- V_Lam の注釈と帰納仮定の結論を、同じ bind の型へそろえる入口。 -/
theorem HasTypeVQ.subst_lam {P B store Q C Γ Φ Δ Ξ ns ps body r e σ ρ}
    (hw : Ty.WF 0 C.length Γ.length (.fn ns ps r e))
    (hs : Ty.Sorted Γ (.fn ns ps r e))
    (ht : Transport (valEnv σ) Γ Φ Δ Ξ)
    (hd : Ty.Declared P C Γ (.fn ns ps r e))
    (hdi : DeclarationImages P C Γ Δ (valEnv σ).values)
    (hb : HasTypeCQ P B (hideBuilders store) Q C
      (bindParams (hideConts Δ) (ps.map (substTyValues σ)))
      (liftMany ps.length Ξ) (some ((substTyValues σ r).shiftV ps.length 0))
      (body.subst (upSubst ps.length σ) (upLocalSubst ps.length ρ))
      ((substTyValues σ r).shiftV ps.length 0)
      (Eff.shiftV ps.length 0 (substEffValues σ e)) []) :
    HasTypeVQ P B store Q C Δ Ξ ((Val.lam ns ps body).subst σ ρ)
      ((Ty.fn ns ps r e).bind (valEnv σ)) := by
  rw [Ty.bind_fn]
  refine .V_Lam ?_ ?_ ?_ ?_ ?_
  · simpa only [NamesWF, List.length_map] using hw.1
  · simpa only [valEnv_valuesOnly, Ty.bind_fn, substTyValues_eq_bind] using
      Ty.wf_bind_values hw hs.references (valEnv σ).values ht.imageWF
  · simpa only [valEnv_valuesOnly, Ty.bind_fn, substTyValues_eq_bind] using
      Ty.sorted_bind_values hs (valEnv σ).values ht.values ht.references
  · simpa only [List.length_map, substTyValues, substEffValues] using hb
  · simpa only [valEnv_valuesOnly, Ty.bind_fn, substTyValues_eq_bind] using hd.bind_values hdi

mutual
  theorem Ty.rawSubstV_embed (a : Benitoite.Release.Ty) (σ : ObservationEnv) :
      (embedTy a).rawSubstV σ = embedTy a := by
    cases a <;> simp only [embedTy, Ty.rawSubstV, Ty.rawSubstV_embed,
      substVTys_embed, Eff.rawSubstV_embed]
  theorem substVTys_embed (as : List Benitoite.Release.Ty) (σ : ObservationEnv) :
      substVTys σ (embedTys as) = embedTys as := by
    cases as <;> simp only [embedTys, substVTys, Ty.rawSubstV_embed, substVTys_embed]
  theorem Eff.rawSubstV_embed (e : Benitoite.Release.Eff) (σ : ObservationEnv) :
      Eff.rawSubstV σ (embedEff e) = embedEff e := by
    cases e; simp only [embedEff, Eff.rawSubstV, substVTys_embed]
end

theorem substTyValues_embed (σ : Nat → Val) (a : Benitoite.Release.Ty) :
    substTyValues σ (embedTy a) = embedTy a.norm := by
  unfold substTyValues Ty.bind valEnv
  rw [← Ty.rawSubstV_eq_rawBind, Ty.rawSubstV_embed, ← embedTy_norm]

theorem substEffValues_embed (σ : Nat → Val) (e : Benitoite.Release.Eff) :
    substEffValues σ (embedEff e) = embedEff e.norm := by
  unfold substEffValues Eff.bind valEnv
  rw [← Eff.rawSubstV_eq_rawBind, Eff.rawSubstV_embed, ← embedEff_norm]

theorem Ty.subst_values_of_wf_zero {nr nt a} (h : Ty.WF nr nt 0 a) (σ : Nat → Val) :
    substTyValues σ a = a := by
  unfold substTyValues Ty.bind valEnv
  rw [← Ty.rawSubstV_eq_rawBind, Ty.rawSubstV_of_wf_zero h]
  exact Ty.canonical_of_wf h

theorem Eff.subst_values_of_wf_zero {nr nt e} (h : Eff.WF nr nt 0 e)
    (hc : e.Canonical) (σ : Nat → Val) : substEffValues σ e = e := by
  unfold substEffValues Eff.bind valEnv
  rw [← Eff.rawSubstV_eq_rawBind, Eff.rawSubstV_of_wf_zero h]
  exact hc

end Benitoite.Release.Refinement
