import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.Le

/-!
# 値の移動と論理の置換

self を残す up と、外側の値の Nat/cutoff を区別する。
構文の含意の導出を移し、意味上の包含を仮定しない。
-/
namespace Benitoite.Release.Refinement

/-- 改名の像は必ず存在するので、selfの開きと無条件に交換する。 -/
theorem predBind_open_renaming (ξ : Nat → Nat) (p : Pred) (t : Term) :
    predBind (fun i => some (.var (ξ i))) (p.open t) =
      (predBind (upValues (fun i => some (.var (ξ i)))) p).open
        (termBind (fun i => some (.var (ξ i))) t) :=
  predBind_open_of_some _ p t _ (termBind?_renaming ξ t)

/-- 有限の含意の全規則に対する、論理項の同時置換。 -/
theorem Entails.bind {Ξ p} (h : Entails Ξ p) (σ : ObservationEnv) :
    Entails (Ξ.map (predBind σ)) (predBind σ p) := by
  induction h with
  | hyp h => exact .hyp (List.mem_map.mpr ⟨_, h, rfl⟩)
  | truth => exact .truth
  | false_elim _ ih => exact .false_elim ih
  | and_intro _ _ ih₁ ih₂ => exact .and_intro ih₁ ih₂
  | and_left _ ih => exact .and_left ih
  | and_right _ ih => exact .and_right ih
  | or_left _ ih => exact .or_left ih
  | or_right _ ih => exact .or_right ih
  | or_elim _ _ _ ih₀ ih₁ ih₂ => exact .or_elim ih₀ ih₁ ih₂
  | not_intro _ ih => exact .not_intro ih
  | not_elim _ _ ih₁ ih₂ => exact .not_elim ih₁ ih₂
  | not_not_elim _ ih => exact .not_not_elim ih
  | eq_refl => exact .eq_refl
  | le_refl => exact .le_refl
  | integer_eq h => exact .integer_eq h
  | integer_le h => exact .integer_le h
  | integer_lt h => exact .integer_lt h
  | closed hw hs he =>
    rw [Pred.bind_closed hw σ]
    exact .closed hw hs he
  | checkedAt ν hc _ ih =>
    simp only [predBind_comp] at ih ⊢
    exact .checkedAt (fun i => (ν i).bind (termBind? σ)) hc ih



theorem upValues_shiftIndex (k c : Nat) :
    upValues (fun i => some (.var (shiftIndex k c i))) =
      (fun i => some (.var (shiftIndex k (c+1) i))) := by
  funext i
  cases i with
  | zero => simp [upValues, shiftIndex]
  | succ i =>
    simp only [upValues, Option.map_some, termBind, termBind?, Option.getD_some, shiftIndex]
    split <;> split <;> simp_all <;> omega

theorem Entails.shiftV {Ξ p} (h : Entails Ξ p) (k c : Nat) :
    Entails (Ξ.map (Pred.shiftV k c)) (p.shiftV k c) := h.bind _

theorem Pred.wf_shiftV {nv : Nat} {p : Pred} (h : p.WF nv) (k c : Nat) :
    (p.shiftV k c).WF (nv+k) := by
  apply Pred.wf_bind h
  intro i hi u hu
  cases hu
  simp only [termWF, Term.VarsIn, shiftIndex]
  split <;> omega

def Term.ImageReferences (Γ Δ : Ctx) (ν : ObservationEnv) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → Ordinary a →
    ∀ t, ν i = some t → t.References Δ
def Term.ImageWF (Γ Δ : Ctx) (ν : ObservationEnv) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → Ordinary a →
    ∀ t, ν i = some t → termWF Δ.length t
def Term.ImagesSorted (Γ Δ : Ctx) (ν : ObservationEnv) : Prop :=
  ∀ i a s, Γ[i]? = some (some a) → a.HasSort s →
    ∃ t, ν i = some t ∧ t.HasSort Δ s

theorem Term.imageWF_up {Γ Δ : Ctx} {ν : ObservationEnv} (h : Term.ImageWF Γ Δ ν)
    (a b : Ty) : Term.ImageWF (some a :: Γ) (some b :: Δ) (upValues ν) := by
  intro i t ht ho u hu
  cases i with
  | zero => cases hu; exact Nat.zero_lt_succ _
  | succ i =>
    simp only [upValues, Option.map_eq_some_iff] at hu
    obtain ⟨v, hv, rfl⟩ := hu
    apply termWF_bind (h i t ht ho v hv)
    intro j hj w hw
    cases hw
    exact Nat.succ_lt_succ hj

theorem Pred.wf_bind_references {Γ Δ : Ctx} {a b : Ty} {p : Pred}
    (h : p.References Γ (some a)) (ν : ObservationEnv) (hi : Term.ImageWF Γ Δ ν) :
    (predBind (upValues ν) p).WF (Δ.length+1) :=
  Pred.varsIn_bind h _ (fun _ ⟨t, ht, ho⟩ => Term.imageWF_up hi a b _ t ht ho)

theorem Term.references_bind {Γ Δ : Ctx} {t : Term} (h : t.References Γ)
    (ν : ObservationEnv) (hi : Term.ImageReferences Γ Δ ν) {u : Term}
    (he : termBind? ν t = some u) : u.References Δ :=
  Term.varsIn_bind h ν (fun i ⟨a, ha, ho⟩ => hi i a ha ho) he

theorem Term.references_termBind {Γ Δ : Ctx} {t : Term} (h : t.References Γ)
    (ν : ObservationEnv) (hi : Term.ImageReferences Γ Δ ν) :
    (termBind ν t).References Δ :=
  Term.varsIn_termBind h ν (fun i ⟨a, ha, ho⟩ => hi i a ha ho)

private theorem Term.shape_bind {Γ Δ : Ctx} {t : Term} {s : «Sort»}
    (h : t.Shape Γ s) (ν : ObservationEnv) (hi : Term.ImagesSorted Γ Δ ν) :
    ∃ u, termBind? ν t = some u ∧ u.Shape Δ s := by
  cases t with
  | var i =>
    obtain ⟨a, ha, hs⟩ := h
    obtain ⟨u, hu, hs⟩ := hi i a s ha hs
    exact ⟨u, hu, hs.2⟩
  | field r a | measure r a | neg a | scale r a =>
    obtain ⟨u, hu, hs⟩ := Term.shape_bind h.1 ν hi
    exact ⟨_, rfl, by simpa only [Term.Shape, termBind, hu, Option.getD_some] using And.intro hs h.2⟩
  | add a b =>
    obtain ⟨u, hu, hs⟩ := Term.shape_bind h.1 ν hi
    obtain ⟨v, hv, ht⟩ := Term.shape_bind h.2.1 ν hi
    exact ⟨_, rfl, by simpa only [Term.Shape, termBind, hu, hv, Option.getD_some] using And.intro hs (And.intro ht h.2.2)⟩
  | integer _ | character _ | float64 _ | float32 _ | decimal _ _ | boolean _
  | unitValue | string _ | listValue _ | bytesValue _ | mapValue _ _ | setValue _
  | dataValue _ _ | targetValue _ _ => exact ⟨_, rfl, h⟩

theorem Term.hasSort_bind {Γ Δ : Ctx} {t : Term} {s : «Sort»}
    (h : t.HasSort Γ s) (ν : ObservationEnv) (hs : Term.ImagesSorted Γ Δ ν)
    (hr : Term.ImageReferences Γ Δ ν) :
    ∃ u, termBind? ν t = some u ∧ u.HasSort Δ s := by
  obtain ⟨u, hu, ht⟩ := Term.shape_bind h.2 ν hs
  exact ⟨u, hu, Term.references_bind h.1 ν hr hu, ht⟩

theorem Term.hasSort_termBind {Γ Δ : Ctx} {t : Term} {s : «Sort»}
    (h : t.HasSort Γ s) (ν : ObservationEnv) (hs : Term.ImagesSorted Γ Δ ν)
    (hr : Term.ImageReferences Γ Δ ν) : (termBind ν t).HasSort Δ s := by
  obtain ⟨u, hu, ht⟩ := Term.hasSort_bind h ν hs hr
  simpa only [termBind, hu, Option.getD_some] using ht

theorem Term.hasSort_context {Γ Δ : Ctx} {t : Term} {s : «Sort»} (h : t.HasSort Γ s)
    (hs : ∀ (i : Nat) (a : Ty) (s : «Sort»), Γ[i]? = some (some a) → a.HasSort s →
      ∃ b : Ty, Δ[i]? = some (some b) ∧ b.HasSort s)
    (hr : ∀ i, Γ.Readable i → Δ.Readable i) : t.HasSort Δ s := by
  have hsi : Term.ImagesSorted Γ Δ (fun i => some (.var i)) := by
    intro i a s hi ha
    obtain ⟨b, hb, hs⟩ := hs i a s hi ha
    exact ⟨.var i, rfl, hr i ⟨a, hi, ha.ordinary⟩, b, hb, hs⟩
  have hri : Term.ImageReferences Γ Δ (fun i => some (.var i)) := by
    intro i a hi ho u hu
    cases hu
    exact hr i ⟨a, hi, ho⟩
  simpa only [termBind_id] using Term.hasSort_termBind h _ hsi hri

theorem Term.references_lift {Γ : Ctx} {t : Term} (h : t.References Γ) (a : Option Ty) :
    (termBind (fun i => some (.var (i+1))) t).References (a :: Γ) := by
  apply Term.references_termBind h
  intro i b hb ho u hu
  cases hu
  exact ⟨b, hb, ho⟩

theorem Term.hasSort_lift {Γ : Ctx} {t : Term} {s : «Sort»} (h : t.HasSort Γ s)
    (a : Option Ty) : (termBind (fun i => some (.var (i+1))) t).HasSort (a :: Γ) s := by
  refine ⟨Term.references_lift h.1 a, ?_⟩
  obtain ⟨u, hu, ht⟩ := Term.shape_bind (Δ := a :: Γ) h.2 (fun i => some (.var (i+1))) (by
    intro i b s hb hs
    exact ⟨.var (i+1), rfl, ⟨b, hb, hs.ordinary⟩, b, hb, hs⟩)
  simpa only [termBind, hu, Option.getD_some] using ht

theorem Term.imageReferences_up {Γ Δ : Ctx} {ν : ObservationEnv}
    (hr : Term.ImageReferences Γ Δ ν) (a b : Ty) (ho : Ordinary a → Ordinary b) :
    Term.ImageReferences (some a :: Γ) (some b :: Δ) (upValues ν) := by
  intro i t ht htOrd u hu
  cases i with
  | zero =>
    simp only [List.getElem?_cons_zero, Option.some.injEq] at ht
    cases ht
    cases hu
    exact ⟨b, rfl, ho htOrd⟩
  | succ i =>
    simp only [upValues, Option.map_eq_some_iff] at hu
    obtain ⟨v, hv, rfl⟩ := hu
    exact Term.references_lift (hr i t ht htOrd v hv) (some b)

theorem Pred.references_bind {Γ Δ : Ctx} {a b : Ty} {p : Pred}
    (h : p.References Γ (some a)) (ν : ObservationEnv)
    (ho : Ordinary a → Ordinary b) (hr : Term.ImageReferences Γ Δ ν) :
    (predBind (upValues ν) p).References Δ (some b) :=
  Pred.varsIn_bind h _ (fun _ ⟨t, ht, htOrd⟩ => Term.imageReferences_up hr a b ho _ t ht htOrd)

theorem Pred.sorted_bind {Γ Δ : Ctx} {a b : Ty} {p : Pred}
    (h : p.Sorted Γ (some a)) (ν : ObservationEnv)
    (ha : ∀ s, a.HasSort s → b.HasSort s) (ho : Ordinary a → Ordinary b)
    (hs : Term.ImagesSorted Γ Δ ν) (hr : Term.ImageReferences Γ Δ ν) :
    (predBind (upValues ν) p).Sorted Δ (some b) := by
  have hsu : Term.ImagesSorted (some a :: Γ) (some b :: Δ) (upValues ν) := by
    intro i t s ht hs'
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at ht
      cases ht
      exact ⟨.var 0, rfl, ⟨b, rfl, (ha s hs').ordinary⟩, b, rfl, ha s hs'⟩
    | succ i =>
      obtain ⟨u, hu, hsort⟩ := hs i t s ht hs'
      exact ⟨_, by simp only [upValues, hu, Option.map_some], Term.hasSort_lift hsort (some b)⟩
  have hru : Term.ImageReferences (some a :: Γ) (some b :: Δ) (upValues ν) := by
    intro i t ht ht' u hu
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at ht
      cases ht
      cases hu
      exact ⟨b, rfl, ho ht'⟩
    | succ i =>
      simp only [upValues, Option.map_eq_some_iff] at hu
      obtain ⟨v, hv, rfl⟩ := hu
      exact Term.references_lift (hr i t ht ht' v hv) (some b)
  cases p <;> simp only [Pred.Sorted] at h <;> simp only [predBind, Pred.Sorted]
  all_goals first
    | trivial
    | exact ⟨Term.hasSort_termBind h.1 _ hsu hru, Term.hasSort_termBind h.2 _ hsu hru⟩
    | exact ⟨h.1, Term.hasSort_termBind h.2.1 _ hsu hru, Term.hasSort_termBind h.2.2 _ hsu hru⟩
    | exact Term.hasSort_termBind h _ hsu hru
    | exact h.elim (fun ht => Or.inl (Term.hasSort_termBind ht _ hsu hru))
        (fun ht => Or.inr ⟨ht.1, Term.hasSort_termBind ht.2 _ hsu hru⟩)
    | exact ⟨Pred.sorted_bind h.1 ν ha ho hs hr, Pred.sorted_bind h.2 ν ha ho hs hr⟩
    | exact Pred.sorted_bind h ν ha ho hs hr

theorem instAtoms_nil (a : Atom → Bool) : instAtoms [] a = a := by
  funext x
  rcases x with ⟨l, r | i⟩ | i <;> simp [instAtoms]

theorem substAtoms_nil (a : Atom → Bool) : substAtoms [] a = a := by
  funext x
  cases x <;> simp [substAtoms]

theorem renEnv_up_shiftIndex (k c : Nat) :
    (renEnv (shiftIndex k c)).up = renEnv (shiftIndex k (c+1)) := by
  rw [renEnv_up]
  congr 1
  funext i
  cases i <;> simp [upRen, shiftIndex]
  all_goals split <;> omega

@[simp] theorem renEnv_up_id : (renEnv id).up = renEnv id := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  funext i
  cases i <;> rfl

mutual
  /-- Context の移動と、項の型注釈に使う改名の実装は一致する。 -/
  theorem Ty.shiftV_eq_renameTy (a : Ty) (k c : Nat) :
      a.shiftV k c = renameTy (shiftIndex k c) a := by
    cases a <;> simp only [Ty.shiftV, renameTy, Ty.rawBind, renEnv,
      RangeIx.inst_nil, rawApply, Ty.shiftVTys_eq_rename, Eff.shiftV_eq_renameEff,
      Ty.shiftV_eq_renameTy, renameTy, renameEff, Tel.shiftV_eq_rawBind]
    case refined a p =>
      congr 1
      exact congrArg (fun σ => predBind σ p) (upValues_shiftIndex k c).symm
  theorem Tel.shiftV_eq_rawBind (t : Tel) (k c : Nat) :
      Tel.shiftV k c t = Tel.rawBind (renEnv (shiftIndex k c)) t := by
    cases t <;> simp only [Tel.shiftV, Tel.rawBind, Ty.shiftV_eq_renameTy,
      Eff.shiftV_eq_renameEff, renameTy, renameEff, renEnv_up_shiftIndex, Tel.shiftV_eq_rawBind]
  theorem Ty.shiftVTys_eq_rename (as : List Ty) (k c : Nat) :
      shiftVTys k c as = rawBindTys (renEnv (shiftIndex k c)) as := by
    cases as with
    | nil => rfl
    | cons a as =>
      simp only [shiftVTys, rawBindTys, Ty.shiftV_eq_renameTy, renameTy, Ty.shiftVTys_eq_rename]
  theorem Eff.shiftV_eq_renameEff (e : Eff) (k c : Nat) :
      Eff.shiftV k c e = renameEff (shiftIndex k c) e := by
    cases e with
    | mk a fs =>
      simp only [Eff.shiftV, renameEff, Eff.rawBind, renEnv, instAtoms_nil,
        substAtoms_nil, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil, Ty.shiftVTys_eq_rename]
end

@[simp] theorem renEnv_types (ξ : Nat → Nat) : (renEnv ξ).types = Ty.tvar := rfl
@[simp] theorem renEnv_rows (ξ : Nat → Nat) : (renEnv ξ).rows = [] := rfl
@[simp] theorem renEnv_ranges (ξ : Nat → Nat) : (renEnv ξ).ranges = [] := rfl
@[simp] theorem renEnv_values (ξ : Nat → Nat) : (renEnv ξ).values = fun i => some (.var (ξ i)) := rfl

end Benitoite.Release.Refinement
