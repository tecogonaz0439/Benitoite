import Benitoite.Release.Refinement.ValueRegularity

/-!
# 項の束縛と型注釈の値置換

実際の値の像と整数項の像を接続し、自己束縛を越えて像を移す。
-/
namespace Benitoite.Release.Refinement

theorem Val.toTerm_rename (v : Val) (ξ : Nat → Nat) :
    (v.rename ξ).toTerm? = v.toTerm?.map (termBind (fun i => .var (ξ i))) := by
  cases v <;> try rfl
  case const c => cases c <;> rfl

theorem Val.observe_rename (v : Val) (ξ : Nat → Nat) :
    (v.rename ξ).toTerm?.getD (.integer 0) =
      termBind (fun i => .var (ξ i)) (v.toTerm?.getD (.integer 0)) := by
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
      Val.renameList_identity, Comp.rename_identity, Val.rename_identity]
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
      ↓reduceIte, Nat.add_one_sub_one, Val.observe_rename, upValues, valEnv]

theorem valEnv_upSubst (k : Nat) (σ : Nat → Val) :
    valEnv (upSubst k σ) = SubstEnv.valuesOnly (upTerms k (valEnv σ).values) := by
  change SubstEnv.mk Ty.tvar [] [] _ = SubstEnv.mk Ty.tvar [] [] _
  congr 1
  funext i
  simp only [upSubst, upTerms]
  split
  · rfl
  · exact Val.observe_rename _ _

theorem upTerms_succ (k : Nat) (σ : Nat → Term) : upTerms (k+1) σ = upValues (upTerms k σ) := by
  funext i
  cases i with
  | zero => simp [upTerms, upValues]
  | succ i =>
    simp only [upValues, upTerms, Nat.succ_lt_succ_iff, Nat.add_sub_add_right]
    split
    · simp only [termBind]
    · rw [termBind_comp]
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
  theorem Ty.rawSubstV_comp (a : Ty) (σ τ : Nat → Term) :
      (a.rawSubstV σ).rawSubstV τ = a.rawSubstV (fun i => termBind τ (σ i)) := by
    cases a <;> simp only [Ty.rawSubstV, Ty.rawSubstV_comp, substVTys_comp, Eff.rawSubstV_comp]
    case refined a p => rw [predBind_comp, upValues_comp]
  theorem substVTys_comp (as : List Ty) (σ τ : Nat → Term) :
      substVTys τ (substVTys σ as) = substVTys (fun i => termBind τ (σ i)) as := by
    cases as <;> simp only [substVTys, Ty.rawSubstV_comp, substVTys_comp]
  theorem Eff.rawSubstV_comp (e : Eff) (σ τ : Nat → Term) :
      Eff.rawSubstV τ (Eff.rawSubstV σ e) = Eff.rawSubstV (fun i => termBind τ (σ i)) e := by
    cases e; simp only [Eff.rawSubstV, substVTys_comp]
end

theorem renameTy_eq_rawSubstV (ξ : Nat → Nat) (a : Ty) :
    renameTy ξ a = a.rawSubstV (fun i => .var (ξ i)) := (Ty.rawSubstV_eq_rawBind _ _).symm

theorem renameEff_eq_rawSubstV (ξ : Nat → Nat) (e : Eff) :
    renameEff ξ e = Eff.rawSubstV (fun i => .var (ξ i)) e := (Eff.rawSubstV_eq_rawBind _ _).symm

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
  simp [termBind, shiftIndex, upTerms, hi]

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
  simp [termBind, shiftIndex, upTerms, hi]

theorem Ty.bind_fn (ns : List String) (ps : List Ty) (r : Ty) (e : Eff) (θ : SubstEnv) :
    (Ty.fn ns ps r e).bind θ = .fn ns (ps.map (Ty.bind θ)) (r.bind θ) (Eff.bind θ e) := by
  simp only [Ty.bind, Ty.rawBind, Ty.norm, Eff.bind, rawBindTys_eq_map,
    Ty.normTys_eq_map, List.map_map]
  rfl

@[simp] theorem valEnv_valuesOnly (σ : Nat → Val) :
    SubstEnv.valuesOnly (valEnv σ).values = valEnv σ := rfl

theorem substTyValues_eq_bind (σ : Nat → Val) : substTyValues σ = Ty.bind (valEnv σ) := rfl
theorem substEffValues_eq_bind (σ : Nat → Val) : substEffValues σ = Eff.bind (valEnv σ) := rfl

theorem Ty.shiftV_comm (a : Ty) (n k c : Nat) :
    (a.shiftV n 0).shiftV k (c+n) = (a.shiftV k c).shiftV n 0 := by
  simp only [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV, Ty.rawSubstV_comp]
  congr 1
  funext i
  simp only [termBind, shiftIndex, Nat.not_lt_zero, ↓reduceIte]
  by_cases h : i < c <;> simp [h, show (i+n < c+n) ↔ i<c by omega]
  all_goals omega

theorem Eff.shiftV_comm (e : Eff) (n k c : Nat) :
    Eff.shiftV k (c+n) (Eff.shiftV n 0 e) = Eff.shiftV n 0 (Eff.shiftV k c e) := by
  simp only [Eff.shiftV_eq_renameEff, renameEff_eq_rawSubstV, Eff.rawSubstV_comp]
  congr 1
  funext i
  simp only [termBind, shiftIndex, Nat.not_lt_zero, ↓reduceIte]
  by_cases h : i < c <;> simp [h, show (i+n < c+n) ↔ i<c by omega]
  all_goals omega

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

/-- V_Lam の注釈と帰納仮定の結論を、同じ bind の型へそろえる入口。 -/
theorem HasTypeVQ.subst_lam {P B store Q C Γ Φ Δ Ξ ns ps body r e σ ρ}
    (hw : Ty.WF 0 C.length Γ.length (.fn ns ps r e))
    (hs : Ty.Sorted Γ (.fn ns ps r e))
    (ht : Transport (valEnv σ) Γ Φ Δ Ξ)
    (hb : HasTypeCQ P B (hideBuilders store) Q C
      (bindParams (hideConts Δ) (ps.map (substTyValues σ)))
      (liftMany ps.length Ξ) (some ((substTyValues σ r).shiftV ps.length 0))
      (body.subst (upSubst ps.length σ) (upLocalSubst ps.length ρ))
      ((substTyValues σ r).shiftV ps.length 0)
      (Eff.shiftV ps.length 0 (substEffValues σ e)) []) :
    HasTypeVQ P B store Q C Δ Ξ ((Val.lam ns ps body).subst σ ρ)
      ((Ty.fn ns ps r e).bind (valEnv σ)) := by
  rw [Ty.bind_fn]
  refine .V_Lam ?_ ?_ ?_ ?_
  · simpa only [NamesWF, List.length_map] using hw.1
  · simpa only [valEnv_valuesOnly, Ty.bind_fn, substTyValues_eq_bind] using
      Ty.wf_bind_values hw hs (valEnv σ).values ht.values
  · simpa only [valEnv_valuesOnly, Ty.bind_fn, substTyValues_eq_bind] using
      Ty.sorted_bind_values hs (valEnv σ).values ht.values
  · simpa only [List.length_map, substTyValues, substEffValues] using hb

mutual
  theorem Ty.rawSubstV_embed (a : Benitoite.Release.Ty) (σ : Nat → Term) :
      (embedTy a).rawSubstV σ = embedTy a := by
    cases a <;> simp only [embedTy, Ty.rawSubstV, Ty.rawSubstV_embed,
      substVTys_embed, Eff.rawSubstV_embed]
  theorem substVTys_embed (as : List Benitoite.Release.Ty) (σ : Nat → Term) :
      substVTys σ (embedTys as) = embedTys as := by
    cases as <;> simp only [embedTys, substVTys, Ty.rawSubstV_embed, substVTys_embed]
  theorem Eff.rawSubstV_embed (e : Benitoite.Release.Eff) (σ : Nat → Term) :
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

private theorem termBind_fixed {nv t} (h : termWF nv t) (σ : Nat → Term)
    (hf : ∀ i, i<nv → σ i = .var i) : termBind σ t = t := by
  induction t with
  | var i => exact hf i h
  | integer _ => rfl
  | add a b ia ib => simp only [termBind, ia h.1, ib h.2]

private theorem predBind_fixed {nv p} (h : Pred.WF nv p) (σ : Nat → Term)
    (hf : ∀ i, i<nv → σ i = .var i) : predBind σ p = p := by
  induction p with
  | truth | falsity => rfl
  | eq a b | le a b | lt a b => simp only [predBind, termBind_fixed h.1 σ hf, termBind_fixed h.2 σ hf]
  | and p q ip iq | or p q ip iq => simp only [predBind, ip h.1, iq h.2]
  | not p ip => exact congrArg Pred.not (ip h)

mutual
  /-- self 以外の値変数を参照しない WF 注釈では、生の値置換が恒等である。 -/
  theorem Ty.rawSubstV_of_wf_zero {nr nt a} (h : Ty.WF nr nt 0 a) (σ : Nat → Term) :
      a.rawSubstV σ = a := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.rawSubstV]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.rawSubstV_of_wf_zero h σ)
      | exact congrArg _ (substVTys_of_wf_zero h σ)
      | skip
    case fn ns ps r e => rw [substVTys_of_wf_zero h.2.1 σ,
      Ty.rawSubstV_of_wf_zero h.2.2.1 σ, Eff.rawSubstV_of_wf_zero h.2.2.2.1 σ]
    case cont b t e => rw [Ty.rawSubstV_of_wf_zero h.1 σ,
      Ty.rawSubstV_of_wf_zero h.2.1 σ, Eff.rawSubstV_of_wf_zero h.2.2.1 σ]
    case map a b => rw [Ty.rawSubstV_of_wf_zero h.1 σ, Ty.rawSubstV_of_wf_zero h.2 σ]
    case tapp i as => rw [substVTys_of_wf_zero h.2 σ]
    case refined a p =>
      rw [Ty.rawSubstV_of_wf_zero h.1 σ, predBind_fixed h.2.1 (upValues σ) (by
        intro i hi
        have he : i=0 := by omega
        subst i; rfl)]
  theorem substVTys_of_wf_zero {nr nt as} (h : Ty.WFList nr nt 0 as) (σ : Nat → Term) :
      substVTys σ as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [substVTys, Ty.rawSubstV_of_wf_zero h.1 σ, substVTys_of_wf_zero h.2 σ]
  theorem Eff.rawSubstV_of_wf_zero {nr nt e} (h : Eff.WF nr nt 0 e) (σ : Nat → Term) :
      Eff.rawSubstV σ e = e := by
    cases e; simp only [Eff.rawSubstV, substVTys_of_wf_zero h σ]
end

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
