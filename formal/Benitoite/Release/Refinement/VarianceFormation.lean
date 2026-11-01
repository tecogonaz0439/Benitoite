import Benitoite.Release.Refinement.AdmissibleMap

namespace Benitoite.Release.Refinement

/-- sort と通常値の可読性だけを移す。事実の所属は要求しない。 -/
structure SortMap (Γ Δ : Ctx) : Prop where
  lookup : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ∃ b, Δ[i]? = some (some b) ∧
    (∀ s, a.HasSort s → b.HasSort s) ∧ (Ordinary a → Ordinary b)

theorem SortMap.values {Γ Δ} (h : SortMap Γ Δ) :
    Term.ImagesSorted Γ Δ (fun i => some (.var i)) := by
  intro i a s hi hs
  obtain ⟨b, hb, hsort, ho⟩ := h.lookup i a hi
  exact ⟨_, rfl, ⟨b, hb, ho hs.ordinary⟩, b, hb, hsort s hs⟩

theorem SortMap.references {Γ Δ} (h : SortMap Γ Δ) :
    Term.ImageReferences Γ Δ (fun i => some (.var i)) := by
  intro i a hi ho t ht
  cases ht
  obtain ⟨b, hb, _, hab⟩ := h.lookup i a hi
  exact ⟨b, hb, hab ho⟩

theorem Ty.Sorted.sortMap {Γ Δ : Ctx} {a : Ty} (h : a.Sorted Γ) (hm : SortMap Γ Δ) : a.Sorted Δ := by
  simpa only [Ty.rawSubstV_id] using Ty.sorted_rawSubstV h (fun i => some (.var i)) hm.values hm.references

theorem Tel.Sorted.sortMap {Γ Δ : Ctx} {t : Tel} (h : Tel.Sorted Γ t) (hm : SortMap Γ Δ) : Tel.Sorted Δ t := by
  simpa only [Tel.rawSubstV_id] using Tel.sorted_rawSubstV h (fun i => some (.var i)) hm.values hm.references

theorem SortMap.normSelf (Γ : Ctx) (a : Ty) : SortMap (Γ.extend a.norm) (Γ.extend a) := by
  constructor
  intro i b hi
  cases i with
  | zero =>
    cases Option.some.inj hi
    exact ⟨_, rfl, fun s hs => (Ty.hasSort_shiftV _ _ _ _).mpr
      ((Ty.hasSort_norm a s).mp ((Ty.hasSort_shiftV _ _ _ _).mp hs)),
      fun ho => (Ty.ordinary_shiftV _ _ _).mpr
        ((Ty.ordinary_norm a).mp ((Ty.ordinary_shiftV _ _ _).mp ho))⟩
  | succ i => exact ⟨b, hi, fun _ hs => hs, fun ho => ho⟩

theorem Pred.Sorted.sameSelf {Γ : Ctx} {a b : Ty} {p : Pred} (h : p.Sorted Γ (some a))
    (hs : ∀ s, a.HasSort s → b.HasSort s) (ho : Ordinary a → Ordinary b) :
    p.Sorted Γ (some b) := by
  simpa only [upValues_id, predBind_id] using
    Pred.sorted_bind h (fun i => some (.var i)) hs ho
      (Transport.id Γ []).values (Transport.id Γ []).references

theorem Pred.sorted_of_conjuncts {Γ : Ctx} {self : Option Ty} {p : Pred}
    (h : ∀ q ∈ p.conjuncts, q.Sorted Γ self) : p.Sorted Γ self := by
  cases p with
  | truth => trivial
  | and p q =>
    exact ⟨Pred.sorted_of_conjuncts (fun r hr => h r (List.mem_append_left _ hr)),
      Pred.sorted_of_conjuncts (fun r hr => h r (List.mem_append_right _ hr))⟩
  | _ => exact h _ List.mem_cons_self

theorem Ty.sorted_toTel {Γ ns ps r e} (h : (Ty.fn ns ps r e).Sorted Γ) :
    Tel.Sorted Γ (Ty.toTel ns ps r e) := by
  induction ns generalizing Γ ps r e with
  | nil => exact h.2
  | cons n ns ih =>
    cases ps with
    | nil => exact h.2
    | cons a ps =>
      refine ⟨h.1.1, ih ?_⟩
      have hm : SortMap (Γ.shiftV 1 0) (Γ.extend a) := by
        constructor
        intro i b hi
        cases i with
        | zero => simp [Ctx.shiftV] at hi
        | succ i => exact ⟨b, hi, fun _ hs => hs, fun ho => ho⟩
      have hh := Ty.Sorted.sortMap (Ty.sorted_shiftV (a := .fn ns ps r e) ⟨h.1.2, h.2⟩ 1 0) hm
      exact hh

theorem Ty.sorted_foldFn_rev {Γ t} (h : (Ty.foldFn t).Sorted Γ) : Tel.Sorted Γ t := by
  classical
  unfold Ty.foldFn at h
  split at h
  · rename_i f hf
    rw [← (Tel.fnView?_eq_some_iff _ _).mp hf]
    exact Ty.sorted_toTel h
  · exact h

theorem Ty.sorted_of_core_predicates {Γ : Ctx} (a : Ty) (hc : a.core.Sorted Γ)
    (hs : ∀ q ∈ a.refinementPredicates, q.Sorted Γ (some a.core)) : a.Sorted Γ := by
  cases a with
  | refined a p =>
    refine ⟨Ty.sorted_of_core_predicates a hc (fun q hq => hs q (List.mem_append_left _ hq)), ?_⟩
    exact (Pred.sorted_of_conjuncts (fun q hq => hs q (List.mem_append_right _ hq))).sameSelf
      (fun s h => (Ty.sort?_core a).symm.trans h)
      (fun h => by simpa only [Ty.Ordinary, Benitoite.Release.Refinement.Ordinary, Ty.core, Ty.core_idem] using h)
  | _ => exact hc

theorem Ty.sorted_refineNorm_rev {Γ : Ctx} {a : Ty} {p : Pred} (h : (a.refineNorm p).Sorted Γ) :
    a.Sorted Γ ∧ p.Sorted Γ (some a) := by
  have hc : a.core.Sorted Γ := by
    simpa only [Ty.core_refineNorm] using h.core
  have hp : ∀ q ∈ a.refinementPredicates ++ p.conjuncts, q.Sorted Γ (some a.core) := by
    intro q hq
    have hh := h.predicates q (by simpa only [Ty.predicates_refineNorm] using hq)
    simpa only [Ty.core_refineNorm] using hh
  refine ⟨Ty.sorted_of_core_predicates a hc (fun q hq => hp q (List.mem_append_left _ hq)), ?_⟩
  exact (Pred.sorted_of_conjuncts (fun q hq => hp q (List.mem_append_right _ hq))).sameSelf
    (fun s h => (Ty.sort?_core a).symm.trans h)
    (fun h => by simpa only [Ty.Ordinary, Benitoite.Release.Refinement.Ordinary, Ty.core, Ty.core_idem] using h)

private theorem sortedTys_all {Γ : Ctx} {as : List Ty} : sortedTys Γ as ↔ ∀ a ∈ as, a.Sorted Γ := by
  induction as <;> simp_all [sortedTys]

mutual
  theorem Ty.sorted_norm_rev {Γ : Ctx} {a : Ty} (h : a.norm.Sorted Γ) : a.Sorted Γ := by
    cases a <;> simp only [Ty.norm, Ty.Sorted] at h ⊢
    all_goals first | trivial | exact Ty.sorted_norm_rev h | exact sortedTys_norm_rev h | skip
    case fn ns ps r e => exact ⟨sortedTys_norm_rev h.1, Ty.sorted_norm_rev h.2.1, sortedEff_norm_rev h.2.2⟩
    case cont b t e => exact ⟨Ty.sorted_norm_rev h.1, Ty.sorted_norm_rev h.2.1, sortedEff_norm_rev h.2.2⟩
    case map a b => exact ⟨Ty.sorted_norm_rev h.1, Ty.sorted_norm_rev h.2⟩
    case refined a p =>
      obtain ⟨ha, hp⟩ := Ty.sorted_refineNorm_rev h
      exact ⟨Ty.sorted_norm_rev ha, hp.sameSelf (fun s hs => (Ty.hasSort_norm a s).mp hs)
        (fun ho => (Ty.ordinary_norm a).mp ho)⟩
    case dependentFn t => exact Tel.sorted_norm_rev (Ty.sorted_foldFn_rev h)
  theorem Tel.sorted_norm_rev {Γ t} (h : Tel.Sorted Γ (Tel.norm t)) : Tel.Sorted Γ t := by
    cases t with
    | done r e => exact ⟨Ty.sorted_norm_rev h.1, sortedEff_norm_rev h.2⟩
    | param n a t => exact ⟨Ty.sorted_norm_rev h.1,
        Tel.Sorted.sortMap (Tel.sorted_norm_rev h.2) (SortMap.normSelf Γ a)⟩
  theorem sortedTys_norm_rev {Γ : Ctx} {as : List Ty} (h : sortedTys Γ (Ty.normTys as)) : sortedTys Γ as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_norm_rev h.1, sortedTys_norm_rev h.2⟩
  theorem sortedEff_norm_rev {Γ e} (h : sortedEff Γ (Eff.norm e)) : sortedEff Γ e := by
    cases e with
    | mk ats fs =>
      apply sortedTys_norm_rev
      exact sortedTys_all.mpr (fun a ha => sortedTys_all.mp h a (Order.mem_sortUnique.mpr ha))
end

end Benitoite.Release.Refinement
