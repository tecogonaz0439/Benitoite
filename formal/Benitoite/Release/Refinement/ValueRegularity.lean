import Benitoite.Release.Refinement.OpenSubstitution
import Benitoite.Release.Refinement.Typing

/-!
# 正規化した値置換の整形式と sort

生の改名の WF 保存は順序を保つ移動に限る。一般の値置換では
型注釈と潜在効果を bind で正規化する。
-/
namespace Benitoite.Release.Refinement

mutual
  theorem Ty.canonical_of_wf {nr nt nv a} (h : Ty.WF nr nt nv a) : a.Canonical := by
    cases a <;> simp only [Ty.WF] at h <;> unfold Ty.Canonical <;> simp only [Ty.norm]
    all_goals first | rfl | exact congrArg _ (Ty.canonical_of_wf h) | skip
    case data d as => exact congrArg (Ty.data d) (Ty.normTys_of_wf h)
    case fn ns ps r e =>
      rw [Ty.normTys_of_wf h.2.1, Ty.canonical_of_wf h.2.2.1, h.2.2.2.2]
    case cont b t e => rw [Ty.canonical_of_wf h.1, Ty.canonical_of_wf h.2.1, h.2.2.2]
    case map a b => rw [Ty.canonical_of_wf h.1, Ty.canonical_of_wf h.2]
    case tapp i as => exact congrArg (Ty.tapp i) (Ty.normTys_of_wf h.2)
    case refined a p => exact congrArg (fun t => Ty.refined t p) (Ty.canonical_of_wf h.1)
  theorem Ty.normTys_of_wf {nr nt nv as} (h : Ty.WFList nr nt nv as) : Ty.normTys as = as := by
    cases as with
    | nil => rfl
    | cons a as =>
      change a.norm :: Ty.normTys as = a :: as
      rw [show a.norm = a from Ty.canonical_of_wf h.1, Ty.normTys_of_wf h.2]
end

/-- 最上位の行の WF は整列を要求しないが、Fail の各型は正規形である。 -/
theorem Eff.normTys_of_wf {nr nt nv e} (h : Eff.WF nr nt nv e) :
    Ty.normTys e.fails = e.fails := by
  cases e; exact Ty.normTys_of_wf h

theorem termWF_of_sorted {Γ t} (h : termSorted Γ t) : termWF Γ.length t := by
  induction t with
  | var i => obtain ⟨a, hi, _⟩ := h; exact (List.getElem?_eq_some_iff.mp hi).1
  | integer _ => trivial
  | add a b ia ib => exact ⟨ia h.1, ib h.2⟩

theorem Pred.wf_of_sorted {Γ a p} (h : Pred.Sorted Γ (some a) p) : p.WF (Γ.length+1) := by
  induction p with
  | truth | falsity => trivial
  | eq a b | le a b | lt a b =>
    exact ⟨termWF_of_sorted h.1, termWF_of_sorted h.2⟩
  | and p q ip iq | or p q ip iq => exact ⟨ip h.1, iq h.2⟩
  | not p ip => exact ip h

@[simp] theorem Ty.notContCore_rawSubstV (a : Ty) (σ : Nat → Term) :
    (a.rawSubstV σ).NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.rawSubstV, Ty.NotContCore, Ty.core]
  case refined a p => exact Ty.notContCore_rawSubstV a σ

mutual
  @[simp] theorem Ty.integerCarrier_rawSubstV (a : Ty) (σ : Nat → Term) :
      (a.rawSubstV σ).IntegerCarrier ↔ a.IntegerCarrier := by
    cases a <;> simp only [Ty.rawSubstV, Ty.IntegerCarrier, Ty.integerCarrier_rawSubstV]
  theorem Ty.sorted_rawSubstV {Γ Δ a} (h : Ty.Sorted Γ a) (σ : Nat → Term)
      (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
      (a.rawSubstV σ).Sorted Δ := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.rawSubstV, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_rawSubstV h σ hs | exact sortedTys_rawSubstV h σ hs | skip
    case fn ns ps r e => exact ⟨sortedTys_rawSubstV h.1 σ hs,
      Ty.sorted_rawSubstV h.2.1 σ hs, sortedEff_rawSubstV h.2.2 σ hs⟩
    case cont b t e => exact ⟨Ty.sorted_rawSubstV h.1 σ hs,
      Ty.sorted_rawSubstV h.2.1 σ hs, sortedEff_rawSubstV h.2.2 σ hs⟩
    case map a b => exact ⟨Ty.sorted_rawSubstV h.1 σ hs, Ty.sorted_rawSubstV h.2 σ hs⟩
    case refined a p => exact ⟨Ty.sorted_rawSubstV h.1 σ hs,
      Pred.sorted_bind h.2 σ (fun hi => (Ty.integerCarrier_rawSubstV _ _).mpr hi) hs⟩
  theorem sortedTys_rawSubstV {Γ Δ as} (h : sortedTys Γ as) (σ : Nat → Term)
      (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
      sortedTys Δ (substVTys σ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_rawSubstV h.1 σ hs, sortedTys_rawSubstV h.2 σ hs⟩
  theorem sortedEff_rawSubstV {Γ Δ e} (h : sortedEff Γ e) (σ : Nat → Term)
      (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
      sortedEff Δ (Eff.rawSubstV σ e) := by
    cases e; exact sortedTys_rawSubstV h σ hs
end

private theorem sortedTys_iff {Γ as} : sortedTys Γ as ↔ ∀ a ∈ as, a.Sorted Γ := by
  induction as with
  | nil => simp [sortedTys]
  | cons a as ih => simp only [sortedTys, ih, List.mem_cons, forall_eq_or_imp]

mutual
  theorem Ty.sorted_norm {Γ a} (h : Ty.Sorted Γ a) : a.norm.Sorted Γ := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.norm, Ty.Sorted]
    all_goals first | trivial | exact Ty.sorted_norm h | exact sortedTys_norm h | skip
    case fn ns ps r e => exact ⟨sortedTys_norm h.1, Ty.sorted_norm h.2.1, sortedEff_norm h.2.2⟩
    case cont b t e => exact ⟨Ty.sorted_norm h.1, Ty.sorted_norm h.2.1, sortedEff_norm h.2.2⟩
    case map a b => exact ⟨Ty.sorted_norm h.1, Ty.sorted_norm h.2⟩
    case refined a p =>
      refine ⟨Ty.sorted_norm h.1, ?_⟩
      simpa only [upValues_id, predBind_id] using
        Pred.sorted_bind h.2 Term.var (fun hi => (Ty.integerCarrier_norm _).mpr hi)
          (fun i t ht hi => ⟨t, ht, hi⟩)
  theorem sortedTys_norm {Γ as} (h : sortedTys Γ as) : sortedTys Γ (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.sorted_norm h.1, sortedTys_norm h.2⟩
  theorem sortedEff_norm {Γ e} (h : sortedEff Γ e) : sortedEff Γ e.norm := by
    cases e with
    | mk a fs =>
      exact sortedTys_iff.mpr (fun t ht => sortedTys_iff.mp (sortedTys_norm h) t
        (Order.mem_sortUnique.mp ht))
end

mutual
  /-- 参照の上限と篩の芯を検査する。潜在効果の整列は正規化で回復する。 -/
  private def Bounds (nr nt nv : Nat) : Ty → Prop
    | .base _ | .bytes | .ctor _ => True
    | .opaque _ ix => ix.WF nr
    | .data _ as => BoundsList nr nt nv as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => Bounds nr nt nv a
    | .fn ns ps r e => NamesWF ns ps ∧ BoundsList nr nt nv ps ∧ Bounds nr nt nv r ∧ BoundsEff nr nt nv e
    | .tvar i => i < nt
    | .cont b t e => Bounds nr nt nv b ∧ Bounds nr nt nv t ∧ BoundsEff nr nt nv e
    | .map a b => Bounds nr nt nv a ∧ Bounds nr nt nv b
    | .tapp i as => i < nt ∧ BoundsList nr nt nv as
    | .refined a p => Bounds nr nt nv a ∧ p.WF (nv+1) ∧ a.NotContCore
  private def BoundsList (nr nt nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => Bounds nr nt nv a ∧ BoundsList nr nt nv as
  private def BoundsEff (nr nt nv : Nat) : Eff → Prop
    | .mk _ fs => BoundsList nr nt nv fs
end

mutual
  private theorem bounds_of_wf {nr nt nv a} (h : Ty.WF nr nt nv a) : Bounds nr nt nv a := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Bounds]
    all_goals first | exact h | exact bounds_of_wf h | exact boundsList_of_wf h | skip
    case fn ns ps r e => exact ⟨h.1, boundsList_of_wf h.2.1, bounds_of_wf h.2.2.1, boundsEff_of_wf h.2.2.2.1⟩
    case cont b t e => exact ⟨bounds_of_wf h.1, bounds_of_wf h.2.1, boundsEff_of_wf h.2.2.1⟩
    case map a b => exact ⟨bounds_of_wf h.1, bounds_of_wf h.2⟩
    case tapp i as => exact ⟨h.1, boundsList_of_wf h.2⟩
    case refined a p => exact ⟨bounds_of_wf h.1, h.2⟩
  private theorem boundsList_of_wf {nr nt nv as} (h : Ty.WFList nr nt nv as) : BoundsList nr nt nv as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨bounds_of_wf h.1, boundsList_of_wf h.2⟩
  private theorem boundsEff_of_wf {nr nt nv e} (h : Eff.WF nr nt nv e) : BoundsEff nr nt nv e := by
    cases e; exact boundsList_of_wf h
end

private theorem boundsList_iff {nr nt nv as} :
    BoundsList nr nt nv as ↔ ∀ a ∈ as, Bounds nr nt nv a := by
  induction as with
  | nil => simp [BoundsList]
  | cons a as ih => simp only [BoundsList, ih, List.mem_cons, forall_eq_or_imp]

mutual
  private theorem wf_norm_of_bounds {nr nt nv a} (h : Bounds nr nt nv a) : a.norm.WF nr nt nv := by
    cases a <;> simp only [Bounds] at h <;> simp only [Ty.norm, Ty.WF]
    all_goals first | exact h | exact wf_norm_of_bounds h | exact wfList_norm_of_bounds h | skip
    case fn ns ps r e => exact ⟨by simpa [NamesWF] using h.1,
      wfList_norm_of_bounds h.2.1, wf_norm_of_bounds h.2.2.1, wfEff_norm_of_bounds h.2.2.2, Eff.norm_idem _⟩
    case cont b t e => exact ⟨wf_norm_of_bounds h.1, wf_norm_of_bounds h.2.1, wfEff_norm_of_bounds h.2.2, Eff.norm_idem _⟩
    case map a b => exact ⟨wf_norm_of_bounds h.1, wf_norm_of_bounds h.2⟩
    case tapp i as => exact ⟨h.1, wfList_norm_of_bounds h.2⟩
    case refined a p => exact ⟨wf_norm_of_bounds h.1, h.2.1, (Ty.notContCore_norm _).mpr h.2.2⟩
  private theorem wfList_norm_of_bounds {nr nt nv as} (h : BoundsList nr nt nv as) :
      Ty.WFList nr nt nv (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨wf_norm_of_bounds h.1, wfList_norm_of_bounds h.2⟩
  private theorem wfEff_norm_of_bounds {nr nt nv e} (h : BoundsEff nr nt nv e) : e.norm.WF nr nt nv := by
    cases e with
    | mk a fs => exact Ty.wfList_iff.mpr (fun t ht => Ty.wfList_iff.mp
        (wfList_norm_of_bounds h) t (Order.mem_sortUnique.mp ht))
end

mutual
  private theorem bounds_subst {nr nt Γ Δ a} (h : Bounds nr nt Γ.length a) (ha : a.Sorted Γ)
      (σ : Nat → Term)
      (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
      Bounds nr nt Δ.length (a.rawSubstV σ) := by
    cases a <;> simp only [Bounds] at h <;> simp only [Ty.Sorted] at ha <;> simp only [Ty.rawSubstV, Bounds]
    all_goals first | exact h | exact bounds_subst h ha σ hs | exact boundsList_subst h ha σ hs | skip
    case fn ns ps r e => exact ⟨by simpa [NamesWF] using h.1,
      boundsList_subst h.2.1 ha.1 σ hs, bounds_subst h.2.2.1 ha.2.1 σ hs,
      boundsEff_subst h.2.2.2 ha.2.2 σ hs⟩
    case cont b t e => exact ⟨bounds_subst h.1 ha.1 σ hs, bounds_subst h.2.1 ha.2.1 σ hs,
      boundsEff_subst h.2.2 ha.2.2 σ hs⟩
    case map a b => exact ⟨bounds_subst h.1 ha.1 σ hs, bounds_subst h.2 ha.2 σ hs⟩
    case tapp i as => exact ⟨h.1, boundsList_subst h.2 ha σ hs⟩
    case refined a p => exact ⟨bounds_subst h.1 ha.1 σ hs,
      Pred.wf_of_sorted (Pred.sorted_bind ha.2 σ
        (fun hi => (Ty.integerCarrier_rawSubstV a σ).mpr hi) hs),
      (Ty.notContCore_rawSubstV _ _).mpr h.2.2⟩
  private theorem boundsList_subst {nr nt Γ Δ as} (h : BoundsList nr nt Γ.length as) (ha : sortedTys Γ as)
      (σ : Nat → Term)
      (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
      BoundsList nr nt Δ.length (substVTys σ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨bounds_subst h.1 ha.1 σ hs, boundsList_subst h.2 ha.2 σ hs⟩
  private theorem boundsEff_subst {nr nt Γ Δ e} (h : BoundsEff nr nt Γ.length e) (ha : sortedEff Γ e)
      (σ : Nat → Term)
      (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
      BoundsEff nr nt Δ.length (Eff.rawSubstV σ e) := by
    cases e; exact boundsList_subst h ha σ hs
end

theorem Ty.wf_bind_values {nr nt Γ Δ a} (h : Ty.WF nr nt Γ.length a) (ha : a.Sorted Γ)
    (σ : Nat → Term)
    (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
    (a.bind (SubstEnv.valuesOnly σ)).WF nr nt Δ.length := by
  change (a.rawBind _).norm.WF nr nt Δ.length
  unfold SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind]
  exact wf_norm_of_bounds (bounds_subst (bounds_of_wf h) ha σ hs)

theorem Ty.sorted_bind_values {Γ Δ : Ctx} {a : Ty} (ha : a.Sorted Γ) (σ : Nat → Term)
    (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
    (a.bind (SubstEnv.valuesOnly σ)).Sorted Δ := by
  change (a.rawBind _).norm.Sorted Δ
  unfold SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind]
  exact Ty.sorted_norm (Ty.sorted_rawSubstV ha σ hs)

theorem Eff.wf_bind_values {nr nt Γ Δ e} (h : Eff.WF nr nt Γ.length e) (ha : sortedEff Γ e)
    (σ : Nat → Term)
    (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
    (Eff.bind (SubstEnv.valuesOnly σ) e).WF nr nt Δ.length := by
  change (Eff.rawBind _ e).norm.WF nr nt Δ.length
  unfold SubstEnv.valuesOnly
  rw [← Eff.rawSubstV_eq_rawBind]
  exact wfEff_norm_of_bounds (boundsEff_subst (boundsEff_of_wf h) ha σ hs)

theorem Eff.sorted_bind_values {Γ Δ e} (ha : sortedEff Γ e) (σ : Nat → Term)
    (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
    sortedEff Δ (Eff.bind (SubstEnv.valuesOnly σ) e) := by
  change sortedEff Δ (Eff.rawBind _ e).norm
  unfold SubstEnv.valuesOnly
  rw [← Eff.rawSubstV_eq_rawBind]
  exact sortedEff_norm (sortedEff_rawSubstV ha σ hs)

end Benitoite.Release.Refinement
