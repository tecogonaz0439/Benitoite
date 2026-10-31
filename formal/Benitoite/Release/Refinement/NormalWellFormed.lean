import Benitoite.Release.Refinement.ShiftOrder

namespace Benitoite.Release.Refinement

/-- 適格な型では継続の芯に付いた不適格な篩を除く枝は使われない。 -/
theorem Ty.assume_of_wf {nr nt nv : Nat} {a : Ty} (hw : a.WF nr nt nv) :
    a.assume = a.refinementPredicates := by
  cases a <;> try rfl
  case refined a p => exact Ty.assume_eq_predicates hw.2.2


mutual
  theorem Term.varsIn_rename_iff (t : Term) (P : Nat → Prop) (ξ : Nat → Nat) :
      (termBind (fun i => some (.var (ξ i))) t).VarsIn P ↔ t.VarsIn (fun i => P (ξ i)) := by
    cases t <;> simp only [termBind_var, termBind_integer, termBind_character, termBind_float64, termBind_float32, termBind_decimal, termBind_boolean, termBind_unitValue, termBind_string, termBind_listValue, termBind_bytesValue, termBind_mapValue, termBind_setValue, termBind_dataValue, termBind_targetValue, termBind_field, termBind_measure, termBind_add, termBind_neg, termBind_scale, Option.getD_some, Term.VarsIn, Term.varsIn_rename_iff, slots_rename_iff]
  private theorem slot_rename_iff (t : Option Term) (P : Nat → Prop) (ξ : Nat → Nat) :
      varsInSlot P (slotBind (fun i => some (.var (ξ i))) t) ↔ varsInSlot (fun i => P (ξ i)) t := by
    cases t <;> simp only [slotBind, varsInSlot, termBind?_renaming, Term.varsIn_rename_iff]
  private theorem slots_rename_iff (ts : List (Option Term)) (P : Nat → Prop) (ξ : Nat → Nat) :
      varsInSlots P (bindSlots (fun i => some (.var (ξ i))) ts) ↔ varsInSlots (fun i => P (ξ i)) ts := by
    cases ts <;> simp only [bindSlots, varsInSlots, slot_rename_iff, slots_rename_iff]
end

theorem Pred.varsIn_rename_iff (p : Pred) (P : Nat → Prop) (ξ : Nat → Nat) :
    (predBind (fun i => some (.var (ξ i))) p).VarsIn P ↔ p.VarsIn (fun i => P (ξ i)) := by
  cases p <;> simp only [predBind, Pred.VarsIn, Term.varsIn_rename_iff, Pred.varsIn_rename_iff]

theorem Pred.wf_shiftV_rev {p : Pred} {nv k c : Nat} (hc : c ≤ nv)
    (h : (p.shiftV k c).WF (nv+k)) : p.WF nv := by
  have hh := (Pred.varsIn_rename_iff p (fun i => i < nv+k) (shiftIndex k c)).mp h
  apply Pred.varsIn_mono hh
  intro i hi
  unfold shiftIndex at hi
  split at hi <;> omega

theorem Eff.canonical_shiftV_rev {e : Eff} {k c : Nat} (h : (Eff.shiftV k c e).Canonical) :
    e.Canonical := by
  apply Eff.shiftV_injective k c
  simpa only [Eff.Canonical, Eff.norm_shiftV] using h

mutual
  theorem Ty.wf_shiftV_rev {a : Ty} {nr nt nv k c : Nat} (hc : c ≤ nv)
      (h : (a.shiftV k c).WF nr nt (nv+k)) : a.WF nr nt nv := by
    cases a <;> simp only [Ty.shiftV, Ty.WF] at h ⊢
    all_goals first | exact h | exact Ty.wf_shiftV_rev hc h | exact wfList_shiftV_rev hc h |
      exact Tel.wf_shiftV_rev hc h | skip
    case fn ns ps r e =>
      exact ⟨⟨by simpa only [shiftVTys_eq_map, List.length_map] using h.1.1, h.1.2⟩,
        wfList_shiftV_rev hc h.2.1, Ty.wf_shiftV_rev hc h.2.2.1,
        Eff.wf_shiftV_rev hc h.2.2.2.1, Eff.canonical_shiftV_rev h.2.2.2.2⟩
    case cont b t e => exact ⟨Ty.wf_shiftV_rev hc h.1, Ty.wf_shiftV_rev hc h.2.1,
      Eff.wf_shiftV_rev hc h.2.2.1, Eff.canonical_shiftV_rev h.2.2.2⟩
    case map a b => exact ⟨Ty.wf_shiftV_rev hc h.1, Ty.wf_shiftV_rev hc h.2⟩
    case tapp i as => exact ⟨h.1, wfList_shiftV_rev hc h.2⟩
    case refined a p => exact ⟨Ty.wf_shiftV_rev hc h.1,
      Pred.wf_shiftV_rev (p := p) (nv := nv+1) (k := k) (c := c+1) (by omega) (by simpa only [Pred.shiftV, shiftIndex, Nat.add_right_comm] using h.2.1),
      (Ty.notContCore_shiftV _ _ _).mp h.2.2⟩
  theorem Tel.wf_shiftV_rev {t : Tel} {nr nt nv k c : Nat} (hc : c ≤ nv)
      (h : (Tel.shiftV k c t).WF nr nt (nv+k)) : t.WF nr nt nv := by
    cases t with
    | done r e => exact ⟨Ty.wf_shiftV_rev hc h.1, Eff.wf_shiftV_rev hc h.2.1,
        Eff.canonical_shiftV_rev h.2.2⟩
    | param n a t => exact ⟨Ty.wf_shiftV_rev hc h.1,
        Tel.wf_shiftV_rev (nv := nv+1) (k := k) (c := c+1) (by omega) (by simpa only [Nat.add_right_comm] using h.2)⟩
  theorem wfList_shiftV_rev {as : List Ty} {nr nt nv k c : Nat} (hc : c ≤ nv)
      (h : Ty.WFList nr nt (nv+k) (shiftVTys k c as)) : Ty.WFList nr nt nv as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_shiftV_rev hc h.1, wfList_shiftV_rev hc h.2⟩
  theorem Eff.wf_shiftV_rev {e : Eff} {nr nt nv k c : Nat} (hc : c ≤ nv)
      (h : (Eff.shiftV k c e).WF nr nt (nv+k)) : e.WF nr nt nv := by
    cases e; exact wfList_shiftV_rev hc h
end

theorem Ty.wf_of_toTel {ns ps r e nr nt nv} (hn : NamesWF ns ps)
    (h : Tel.WF nr nt nv (Ty.toTel ns ps r e)) : (Ty.fn ns ps r e).WF nr nt nv := by
  induction ns generalizing ps r e nv with
  | nil =>
    cases ps with
    | nil => exact ⟨hn, trivial, h.1, h.2.1, h.2.2⟩
    | cons => simp [NamesWF] at hn
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      have ht := ih hn' h.2
      exact ⟨hn, ⟨h.1, wfList_shiftV_rev (Nat.zero_le nv) ht.2.1⟩,
        Ty.wf_shiftV_rev (Nat.zero_le nv) ht.2.2.1,
        Eff.wf_shiftV_rev (Nat.zero_le nv) ht.2.2.2.1,
        Eff.canonical_shiftV_rev ht.2.2.2.2⟩

theorem Ty.wf_foldFn {t : Tel} {nr nt nv} (h : t.WF nr nt nv) :
    (Ty.foldFn t).WF nr nt nv := by
  classical
  by_cases he : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := he
    rw [Ty.foldFn_toTel]
    exact Ty.wf_of_toTel f.names_wf h
  · rw [Ty.foldFn_no_view he]
    exact h

theorem Pred.wf_conjuncts {p : Pred} {nv} (h : p.WF nv) : ∀ q ∈ p.conjuncts, q.WF nv := by
  cases p with
  | truth => intro q hq; cases hq
  | and p q =>
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact Pred.wf_conjuncts h.1 r hr
    · exact Pred.wf_conjuncts h.2 r hr
  | _ => intro q hq; cases List.mem_singleton.mp hq; exact h

theorem Pred.wf_ofConjuncts {ps : List Pred} {nv} (h : ∀ p ∈ ps, p.WF nv) :
    (Pred.ofConjuncts ps).WF nv := by
  induction ps with
  | nil => trivial
  | cons p ps ih =>
    cases ps with
    | nil => exact h p List.mem_cons_self
    | cons q qs => exact ⟨h p List.mem_cons_self, ih (fun r hr => h r (List.mem_cons_of_mem p hr))⟩

theorem Ty.WF.core {a : Ty} {nr nt nv} (h : a.WF nr nt nv) : a.core.WF nr nt nv := by
  cases a with
  | refined a _ => exact Ty.WF.core (a := a) h.1
  | _ => exact h

theorem Ty.WF.predicates {a : Ty} {nr nt nv} (h : a.WF nr nt nv) :
    ∀ p ∈ a.refinementPredicates, p.WF (nv+1) := by
  cases a with
  | refined a p =>
    intro q hq
    rcases List.mem_append.mp hq with hq | hq
    · exact Ty.WF.predicates h.1 q hq
    · exact Pred.wf_conjuncts h.2.1 q hq
  | _ => intro p hp; cases hp

theorem Ty.wf_refineNorm {a : Ty} {p : Pred} {nr nt nv} (ha : a.WF nr nt nv)
    (hp : p.WF (nv+1)) (hc : a.NotContCore) : (Ty.refineNorm a p).WF nr nt nv := by
  unfold Ty.refineNorm
  cases hs : a.refinementPredicates ++ p.conjuncts with
  | nil => exact ha.core
  | cons q qs =>
    refine ⟨ha.core, Pred.wf_ofConjuncts ?_, ?_⟩
    · intro r hr
      rw [←hs] at hr
      rcases List.mem_append.mp hr with hr | hr
      · exact ha.predicates r hr
      · exact Pred.wf_conjuncts hp r hr
    · simpa only [Ty.NotContCore, Ty.core_idem] using hc

theorem Ty.wfList_iff {nr nt nv : Nat} {as : List Ty} :
    Ty.WFList nr nt nv as ↔ ∀ a ∈ as, a.WF nr nt nv := by
  induction as with
  | nil => simp [Ty.WFList]
  | cons a as ih => simp only [Ty.WFList, ih, List.mem_cons, forall_eq_or_imp]


mutual
  theorem Ty.wf_norm {a : Ty} {nr nt nv} (h : a.WF nr nt nv) : a.norm.WF nr nt nv := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.norm, Ty.WF]
    all_goals first | exact h | exact Ty.wf_norm h | exact wfList_norm h | skip
    case fn ns ps r e => exact ⟨⟨by simpa only [Ty.normTys_eq_map, List.length_map] using h.1.1, h.1.2⟩,
      wfList_norm h.2.1, Ty.wf_norm h.2.2.1, Eff.wf_norm h.2.2.2.1, Eff.norm_idem _⟩
    case cont b t e => exact ⟨Ty.wf_norm h.1, Ty.wf_norm h.2.1, Eff.wf_norm h.2.2.1, Eff.norm_idem _⟩
    case map a b => exact ⟨Ty.wf_norm h.1, Ty.wf_norm h.2⟩
    case tapp i as => exact ⟨h.1, wfList_norm h.2⟩
    case refined a p => exact Ty.wf_refineNorm (Ty.wf_norm h.1) h.2.1 ((Ty.notContCore_norm _).mpr h.2.2)
    case dependentFn t => exact Ty.wf_foldFn (Tel.wf_norm h)
  theorem Tel.wf_norm {t : Tel} {nr nt nv} (h : t.WF nr nt nv) : (Tel.norm t).WF nr nt nv := by
    cases t with
    | done r e => exact ⟨Ty.wf_norm h.1, Eff.wf_norm h.2.1, Eff.norm_idem _⟩
    | param n a t => exact ⟨Ty.wf_norm h.1, Tel.wf_norm h.2⟩
  theorem wfList_norm {as : List Ty} {nr nt nv} (h : Ty.WFList nr nt nv as) :
      Ty.WFList nr nt nv (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_norm h.1, wfList_norm h.2⟩
  theorem Eff.wf_norm {e : Eff} {nr nt nv} (h : e.WF nr nt nv) : e.norm.WF nr nt nv := by
    cases e with
    | mk a fs =>
      apply Ty.wfList_iff.mpr
      intro x hx
      exact Ty.wfList_iff.mp (wfList_norm h) x (Order.mem_sortUnique.mp hx)

end

theorem Ty.WF.ordinary_of_not_cont {nr nt nv a} (h : a.WF nr nt nv)
    (hn : ∀ b t e, a ≠ .cont b t e) : Ordinary a := by
  cases a with
  | refined a p => exact h.2.2
  | _ => exact hn

mutual
  theorem Ty.WF.weaken {nr nt nv nt' nv' a} (h : Ty.WF nr nt nv a)
      (ht : nt ≤ nt') (hv : nv ≤ nv') : Ty.WF nr nt' nv' a := by
    cases a <;> simp only [Ty.WF] at h ⊢
    all_goals first | exact h | omega | exact Ty.WF.weaken h ht hv | exact Ty.WFList.weaken h ht hv | skip
    case fn ns ps r e => exact ⟨h.1, Ty.WFList.weaken h.2.1 ht hv,
      Ty.WF.weaken h.2.2.1 ht hv, Eff.WF.weaken h.2.2.2.1 ht hv, h.2.2.2.2⟩
    case cont b t e => exact ⟨Ty.WF.weaken h.1 ht hv, Ty.WF.weaken h.2.1 ht hv,
      Eff.WF.weaken h.2.2.1 ht hv, h.2.2.2⟩
    case map a b => exact ⟨Ty.WF.weaken h.1 ht hv, Ty.WF.weaken h.2 ht hv⟩
    case tapp i as => exact ⟨by omega, Ty.WFList.weaken h.2 ht hv⟩
    case refined a p => exact ⟨Ty.WF.weaken h.1 ht hv,
      Pred.varsIn_mono h.2.1 (fun _ hi => by omega), h.2.2⟩
    case dependentFn t => exact Tel.WF.weaken h ht hv
  theorem Tel.WF.weaken {nr nt nv nt' nv' t} (h : Tel.WF nr nt nv t)
      (ht : nt ≤ nt') (hv : nv ≤ nv') : Tel.WF nr nt' nv' t := by
    cases t with
    | done r e => exact ⟨Ty.WF.weaken h.1 ht hv, Eff.WF.weaken h.2.1 ht hv, h.2.2⟩
    | param n a t => exact ⟨Ty.WF.weaken h.1 ht hv, Tel.WF.weaken h.2 ht (by omega)⟩
  theorem Ty.WFList.weaken {nr nt nv nt' nv' as} (h : Ty.WFList nr nt nv as)
      (ht : nt ≤ nt') (hv : nv ≤ nv') : Ty.WFList nr nt' nv' as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.WF.weaken h.1 ht hv, Ty.WFList.weaken h.2 ht hv⟩
  theorem Eff.WF.weaken {nr nt nv nt' nv' e} (h : Eff.WF nr nt nv e)
      (ht : nt ≤ nt') (hv : nv ≤ nv') : Eff.WF nr nt' nv' e := by
    cases e; exact Ty.WFList.weaken h ht hv
end

end Benitoite.Release.Refinement
