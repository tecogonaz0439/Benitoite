import Benitoite.Release.Refinement.EffectCover
import Benitoite.Release.Refinement.ContextFacts

/-!
# 有限の仮定と整数観測の移送

部分型の置換に必要な条件を構文の導出で表す。
型付きの値の像からこの条件を導く仕事とは区別する。
-/
namespace Benitoite.Release.Refinement

theorem Ty.sort?_refineNorm (a : Ty) (p : Pred) : (Ty.refineNorm a p).sort? = a.sort? := by
  rw [←Ty.sort?_core, Ty.core_refineNorm, Ty.sort?_core]

theorem Ty.sort?_foldFn (t : Tel) : (Ty.foldFn t).sort? = none := by
  unfold Ty.foldFn
  split <;> rfl

@[simp] theorem Ty.hasSort_norm (a : Ty) (s : «Sort») : a.norm.HasSort s ↔ a.HasSort s := by
  cases a <;> simp only [Ty.norm, Ty.HasSort, Ty.sort?]
  case refined a p =>
    rw [Ty.sort?_refineNorm]
    exact Ty.hasSort_norm a s
  case dependentFn t => rw [Ty.sort?_foldFn]

theorem Ty.hasSort_rawBind {a : Ty} {s : «Sort»} (h : a.HasSort s) (θ : SubstEnv) :
    (a.rawBind θ).HasSort s := by
  cases a <;> simp only [Ty.HasSort, Ty.sort?] at h ⊢
  all_goals first | contradiction | exact h | skip
  case refined a p => exact Ty.hasSort_rawBind h θ

theorem Ty.hasSort_bind {a : Ty} {s : «Sort»} (h : a.HasSort s) (θ : SubstEnv) :
    (a.bind θ).HasSort s := (Ty.hasSort_norm _ _).mpr (Ty.hasSort_rawBind h θ)

@[simp] theorem Ty.integerCarrier_norm (a : Ty) : a.norm.IntegerCarrier ↔ a.IntegerCarrier :=
  Ty.hasSort_norm a .integer
theorem Ty.IntegerCarrier.bind {a : Ty} (h : a.IntegerCarrier) (θ : SubstEnv) :
    (a.bind θ).IntegerCarrier := Ty.hasSort_bind h θ

@[simp] theorem Ty.ordinary_norm (a : Ty) : Ordinary a.norm ↔ Ordinary a := by
  exact Ty.notContCore_norm a

private theorem rawApply_ordinary {a : Ty} (h : Ordinary a) (as : List Ty) : Ordinary (rawApply a as) := by
  cases a <;> simp_all [rawApply, Ordinary, Ty.core]
  case ctor c => cases c <;> simp [rawApply, Ty.core]
  case refined a p => exact rawApply_ordinary (a := a) h as

theorem Ty.ordinary_rawBind {a : Ty} (h : Ordinary a) (θ : SubstEnv)
    (ht : ∀ i, Ordinary (θ.types i)) : Ordinary (a.rawBind θ) := by
  cases a <;> simp_all [Ty.rawBind, Ordinary, Ty.core]
  case refined a p => exact Ty.ordinary_rawBind h θ ht
  case tapp i as => exact rawApply_ordinary (ht i) _

theorem Ty.ordinary_bind {a : Ty} (h : Ordinary a) (θ : SubstEnv)
    (ht : ∀ i, Ordinary (θ.types i)) : Ordinary (a.bind θ) :=
  (Ty.ordinary_norm _).mpr (Ty.ordinary_rawBind h θ ht)

/-- 型像が新しい篩を含んでも、元の最外の事実を失わない。 -/
theorem Ty.predicates_rawBind (a : Ty) (θ : SubstEnv) :
    ∀ p ∈ a.refinementPredicates,
      predBind (upValues θ.values) p ∈ (a.rawBind θ).refinementPredicates := by
  cases a with
  | refined a p =>
    intro q hq
    change q ∈ a.refinementPredicates ++ p.conjuncts at hq
    change predBind _ q ∈ (a.rawBind θ).refinementPredicates ++ (predBind (upValues θ.values) p).conjuncts
    rcases List.mem_append.mp hq with hq | hq
    · exact List.mem_append_left _ (Ty.predicates_rawBind a θ q hq)
    · rw [Pred.conjuncts_bind]
      exact List.mem_append_right _ (List.mem_map.mpr ⟨q, hq, rfl⟩)
  | _ => intro p hp; cases hp

theorem Ty.assume_bind (a : Ty) (θ : SubstEnv) (ht : ∀ i, Ordinary (θ.types i)) :
    ∀ p ∈ a.assume, predBind (upValues θ.values) p ∈ (a.bind θ).assume := by
  intro q hq
  have ho := Ty.assume_ordinary hq
  rw [Ty.assume_eq_predicates ho] at hq
  rw [Ty.assume_eq_predicates (Ty.ordinary_bind ho θ ht)]
  simpa only [Ty.bind, Ty.predicates_norm] using Ty.predicates_rawBind a θ q hq

/-- 元の整数の観測を、行き先で型のある整数項へ写す構文の条件。 -/
structure Transport (θ : SubstEnv) (Γ : Ctx) (Φ : List Pred) (Δ : Ctx) (Ψ : List Pred) : Prop where
  values : Term.ImagesSorted Γ Δ θ.values
  references : Term.ImageReferences Γ Δ θ.values
  typeImages : ∀ i, Ordinary (θ.types i)
  facts : ∀ p ∈ Γ.facts ++ Φ, Entails (Δ.facts ++ Ψ) (predBind θ.values p)

theorem Transport.integer_values {θ Γ Φ Δ Ψ} (h : Transport θ Γ Φ Δ Ψ) :
    ∀ i a, Γ[i]? = some (some a) → a.IntegerCarrier →
      ∃ t, θ.values i = some t ∧ termSorted Δ t := fun i a hi ha => h.values i a .integer hi ha

theorem Transport.imageWF {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) :
    Term.ImageWF Γ Δ θ.values := by
  intro i a hi ho t ht'
  exact Term.references_wf (ht.references i a hi ho t ht')

/-- 元の型の事実と Γ/Φ の像を、新しい型の事実と Δ/Ψ から導く。 -/
theorem Transport.assumptions {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a : Ty) :
    ∀ p ∈ assumptions Γ Φ a,
      Entails (assumptions Δ Ψ (a.bind θ)) (predBind (upValues θ.values) p) := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · exact .hyp (List.mem_append_left _ (Ty.assume_bind a θ ht.typeImages p hp))
  · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
    rw [predBind_lift]
    exact ((ht.facts q hq).bind (fun i => some (.var (i+1)))).weaken
      (fun _ h => List.mem_append_right _ h)

/-- 型像で増えた事実を含め、値の束縛の下で移送条件を保つ。 -/
theorem Transport.extend {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a b : Ty)
    (hb : ∀ s, a.HasSort s → b.HasSort s)
    (ho : Ordinary a → Ordinary b)
    (hf : ∀ p ∈ a.assume, predBind (upValues θ.values) p ∈ b.assume) :
    Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
      (Δ.extend b) (Ψ.map Pred.lift) := by
  constructor
  · intro i t s hi htSort
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      have hs := (Ty.hasSort_shiftV b 1 0 s).mpr (hb s ((Ty.hasSort_shiftV a 1 0 s).mp htSort))
      exact ⟨.var 0, rfl, ⟨b.shiftV 1 0, rfl, hs.ordinary⟩, b.shiftV 1 0, rfl, hs⟩
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some u =>
        cases u with
        | none => simp [hg] at hi
        | some u =>
          simp only [hg, Option.map_some, Option.some.injEq] at hi
          cases hi
          obtain ⟨v, hv, hs⟩ := ht.values i u s hg ((Ty.hasSort_shiftV _ _ _ _).mp htSort)
          exact ⟨_, by simp only [SubstEnv.up_values, upValues, hv, Option.map_some],
            Term.hasSort_lift (Term.hasSort_map_shiftV hs 1 0) _⟩
  · intro i t hi htOrd v hv
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      cases hv
      exact ⟨b.shiftV 1 0, rfl, (Ty.ordinary_shiftV _ _ _).mpr (ho ((Ty.ordinary_shiftV _ _ _).mp htOrd))⟩
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some u =>
        cases u with
        | none => simp [hg] at hi
        | some u =>
          simp only [hg, Option.map_some, Option.some.injEq] at hi
          cases hi
          simp only [SubstEnv.up_values, upValues, Option.map_eq_some_iff] at hv
          obtain ⟨w, hw, rfl⟩ := hv
          exact Term.references_lift (Term.references_map_shiftV
            (ht.references i u hg ((Ty.ordinary_shiftV _ _ _).mp htOrd) w hw) 1 0) _
  · intro i
    exact (Ty.ordinary_shiftV _ _ _).mpr (ht.typeImages i)
  · have hl : ∀ {p}, Entails (Δ.facts ++ Ψ) p →
        Entails ((Δ.extend b).facts ++ Ψ.map Pred.lift) p.lift := by
      intro p he
      apply (he.bind (fun i => some (.var (i+1)))).weaken
      intro q hq
      obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
      rcases List.mem_append.mp hr with hr | hr
      · exact List.mem_append_left _ (Ctx.mem_facts_extend.mpr (Or.inr ⟨r, hr, rfl⟩))
      · exact List.mem_append_right _ (List.mem_map.mpr ⟨r, hr, rfl⟩)
    intro p hp
    change Entails _ (predBind (upValues θ.values) p)
    rcases List.mem_append.mp hp with hp | hp
    · rcases Ctx.mem_facts_extend.mp hp with hp | ⟨q, hq, rfl⟩
      · exact .hyp (List.mem_append_left _ (Ctx.mem_facts_extend.mpr
          (Or.inl (hf p hp))))
      · rw [predBind_lift]
        exact hl (ht.facts q (List.mem_append_left _ hq))
    · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      rw [predBind_lift]
      exact hl (ht.facts q (List.mem_append_right _ hq))

theorem Transport.up {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a : Ty) :
    Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
      (Δ.extend (a.bind θ)) (Ψ.map Pred.lift) :=
  ht.extend a (a.bind θ) (fun _ h => Ty.hasSort_bind h θ)
    (fun h => Ty.ordinary_bind h θ ht.typeImages) (Ty.assume_bind a θ ht.typeImages)

/-- 生の型注釈を使う項の置換にも同じ束縛の証明を渡す。 -/
theorem Transport.up_raw {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a : Ty) :
    Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
      (Δ.extend (a.rawBind θ)) (Ψ.map Pred.lift) := by
  apply ht.extend a (a.rawBind θ)
  · intro s h; exact Ty.hasSort_rawBind h θ
  · intro h; exact Ty.ordinary_rawBind h θ ht.typeImages
  · intro p hp
    simpa only [Ty.bind, Ty.assume_norm] using Ty.assume_bind a θ ht.typeImages p hp

/-- None の束縛も番号を残し、外側の移送条件を up で保つ。 -/
theorem Transport.extendNone {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) :
    Transport θ.up Γ.extendNone (Φ.map Pred.lift) Δ.extendNone (Ψ.map Pred.lift) := by
  constructor
  · intro i t s hi htSort
    cases i with
    | zero => simp [Ctx.extendNone] at hi
    | succ i =>
      simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some u =>
        cases u with
        | none => simp [hg] at hi
        | some u =>
          simp only [hg, Option.map_some, Option.some.injEq] at hi
          cases hi
          obtain ⟨v, hv, hs⟩ := ht.values i u s hg ((Ty.hasSort_shiftV _ _ _ _).mp htSort)
          exact ⟨_, by simp only [SubstEnv.up_values, upValues, hv, Option.map_some],
            Term.hasSort_lift (Term.hasSort_map_shiftV hs 1 0) none⟩
  · intro i t hi htOrd v hv
    cases i with
    | zero => simp [Ctx.extendNone] at hi
    | succ i =>
      simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some u =>
        cases u with
        | none => simp [hg] at hi
        | some u =>
          simp only [hg, Option.map_some, Option.some.injEq] at hi
          cases hi
          simp only [SubstEnv.up_values, upValues, Option.map_eq_some_iff] at hv
          obtain ⟨w, hw, rfl⟩ := hv
          exact Term.references_lift (Term.references_map_shiftV
            (ht.references i u hg ((Ty.ordinary_shiftV _ _ _).mp htOrd) w hw) 1 0) none
  · intro i
    exact (Ty.ordinary_shiftV _ _ _).mpr (ht.typeImages i)
  · have hl : ∀ {p}, Entails (Δ.facts ++ Ψ) p →
        Entails (Δ.extendNone.facts ++ Ψ.map Pred.lift) p.lift := by
      intro p he
      apply (he.bind (fun i => some (.var (i+1)))).weaken
      intro q hq
      obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
      rcases List.mem_append.mp hr with hr | hr
      · exact List.mem_append_left _ (Ctx.mem_facts_extendNone.mpr ⟨r, hr, rfl⟩)
      · exact List.mem_append_right _ (List.mem_map.mpr ⟨r, hr, rfl⟩)
    intro p hp
    change Entails _ (predBind (upValues θ.values) p)
    rcases List.mem_append.mp hp with hp | hp
    · obtain ⟨q, hq, rfl⟩ := Ctx.mem_facts_extendNone.mp hp
      rw [predBind_lift]
      exact hl (ht.facts q (List.mem_append_left _ hq))
    · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
      rw [predBind_lift]
      exact hl (ht.facts q (List.mem_append_right _ hq))

mutual
/-- 新判断の全構成子に対し、置換後の構文の導出を返す。 -/
theorem Ty.LeQ.rawBind {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (θ : SubstEnv) {Δ Ψ}
    (ht : Transport θ Γ Φ Δ Ψ) : Ty.LeQ Δ Ψ (a.rawBind θ) (b.rawBind θ) := by
  match h with
  | .refl => exact .refl
  | .convert he => exact .convert (Ty.rawBind_norm_congr θ he)
  | .trans h₁ h₂ => exact .trans (Ty.LeQ.rawBind h₁ θ ht) (Ty.LeQ.rawBind h₂ θ ht)
  | .fn_effect hc => exact .fn_effect (Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (hc.bind θ)))
  | .list hv => exact .list (Ty.LeQ.rawBind hv θ ht)
  | .lazy hv => exact .lazy (Ty.LeQ.rawBind hv θ ht)
  | .map_value hk hv => exact .map_value (congrArg (Ty.rawBind θ) hk) (Ty.LeQ.rawBind hv θ ht)
  | .forget => exact .forget
  | .introduce hs he =>
    apply Ty.LeQ.introduce
    · exact Pred.sorted_bind hs θ.values (fun _ h => Ty.hasSort_rawBind h θ) (fun h => Ty.ordinary_rawBind h θ ht.typeImages) ht.values ht.references
    · exact (he.bind (upValues θ.values)).cut (by
        intro p hp
        obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        simpa only [assumptions, Ty.bind, Ty.assume_norm] using ht.assumptions _ q hq)
  | .refine hv hp hq he =>
    apply Ty.LeQ.refine (Ty.LeQ.rawBind hv θ ht)
    · exact Pred.sorted_bind hp θ.values (fun _ h => Ty.hasSort_rawBind h θ) (fun h => Ty.ordinary_rawBind h θ ht.typeImages) ht.values ht.references
    · exact Pred.sorted_bind hq θ.values (fun _ h => Ty.hasSort_rawBind h θ) (fun h => Ty.ordinary_rawBind h θ ht.typeImages) ht.values ht.references
    · apply (he.bind (upValues θ.values)).cut
      intro p hp
      rcases List.mem_cons.mp hp with rfl | hp
      · exact .hyp List.mem_cons_self
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        simpa only [assumptions, Ty.bind, Ty.assume_norm] using
          (ht.assumptions _ q hq).weaken (fun _ => List.mem_cons_of_mem _)

  | .dependentFn hs => exact .dependentFn (TelClosure.rawBind hs θ ht)
  | .scoped hc => exact .scoped (hc.inst θ.ranges)
  | .scoped_forget => exact .scoped_forget

  theorem TelLe.rawBind {Γ Φ t u} (h : TelLe Γ Φ t u) (θ : SubstEnv) {Δ Ψ}
      (ht : Transport θ Γ Φ Δ Ψ) : TelLe Δ Ψ (Tel.rawBind θ t) (Tel.rawBind θ u) := by
    match h with
    | .done hr he => exact .done (Ty.LeQ.rawBind hr θ ht) (Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (he.bind θ)))
    | .param ha hs => exact .param (Ty.LeQ.rawBind ha θ ht) (TelLe.rawBind hs θ.up (ht.up_raw _))

  theorem TelClosure.rawBind {Γ Φ t u} (h : TelClosure Γ Φ t u) (θ : SubstEnv) {Δ Ψ}
      (ht : Transport θ Γ Φ Δ Ψ) : TelClosure Δ Ψ (Tel.rawBind θ t) (Tel.rawBind θ u) := by
    match h with
    | .refl => exact .refl
    | .tail hpre hs => exact .tail (TelClosure.rawBind hpre θ ht) (TelLe.rawBind hs θ ht)
end

mutual
/-- 新判断の全構成子に対し、置換後の構文の導出を返す。 -/
theorem Ty.LeQ.bind {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (θ : SubstEnv) {Δ Ψ}
    (ht : Transport θ Γ Φ Δ Ψ) : Ty.LeQ Δ Ψ (a.bind θ) (b.bind θ) := by
  exact (h.rawBind θ ht).norm

  theorem TelLe.bind {Γ Φ t u} (h : TelLe Γ Φ t u) (θ : SubstEnv) {Δ Ψ}
      (ht : Transport θ Γ Φ Δ Ψ) : TelLe Δ Ψ (Tel.bind θ t) (Tel.bind θ u) := by
    match h with
    | .done hr he => exact .done (Ty.LeQ.bind hr θ ht) (he.bind θ)
    | .param ha hs => exact .param (Ty.LeQ.bind ha θ ht) (TelLe.bind hs θ.up (ht.up _))

  theorem TelClosure.bind {Γ Φ t u} (h : TelClosure Γ Φ t u) (θ : SubstEnv) {Δ Ψ}
      (ht : Transport θ Γ Φ Δ Ψ) : TelClosure Δ Ψ (Tel.bind θ t) (Tel.bind θ u) := by
    match h with
    | .refl => exact .refl
    | .tail hpre hs => exact .tail (TelClosure.bind hpre θ ht) (TelLe.bind hs θ ht)
end


theorem Transport.id (Γ : Ctx) (Φ : List Pred) : Transport (renEnv id) Γ Φ Γ Φ := by
  constructor
  · intro i a s hi ha; exact ⟨.var i, rfl, ⟨a, hi, ha.ordinary⟩, a, hi, ha⟩
  · intro i a hi ho t ht; cases ht; exact ⟨a, hi, ho⟩
  · intro i; simp [renEnv, Ordinary, Ty.core]
  · intro p hp
    simpa only [renEnv, id_eq, predBind_id] using (Entails.hyp hp)


end Benitoite.Release.Refinement
