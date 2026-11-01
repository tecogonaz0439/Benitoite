import Benitoite.Release.Refinement.TypeSubst

namespace Benitoite.Release.Refinement

variable {P : Program}

/-- 番号を保ち、観測・参照・最外の事実を保存する型の対応。 -/
structure Ctx.TypeMap (Γ Δ : Ctx) : Prop where
  lookup : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ∃ b : Ty, Δ[i]? = some (some b) ∧
    (∀ s, a.HasSort s → b.HasSort s) ∧ (Ordinary a → Ordinary b) ∧
    (∀ p ∈ a.assume, p ∈ b.assume)

theorem Ctx.TypeMap.id (Γ : Ctx) : Ctx.TypeMap Γ Γ :=
  ⟨fun _ a ha => ⟨a, ha, fun _ h => h, fun h => h, fun _ h => h⟩⟩

theorem Ctx.TypeMap.of_map (Γ : Ctx) (f : Ty → Ty)
    (hs : ∀ a s, a.HasSort s → (f a).HasSort s)
    (ho : ∀ a, Ordinary a → Ordinary (f a))
    (hf : ∀ a p, p ∈ a.assume → p ∈ (f a).assume) :
    Ctx.TypeMap Γ (Γ.map (Option.map f)) := by
  constructor
  intro i a hi
  exact ⟨f a, by simp [List.getElem?_map, hi], hs a, ho a, hf a⟩

theorem Ctx.TypeMap.norm (Γ : Ctx) : Ctx.TypeMap Γ (Γ.map (Option.map Ty.norm)) :=
  Ctx.TypeMap.of_map Γ Ty.norm (fun a s h => (Ty.hasSort_norm a s).mpr h)
    (fun a h => (Ty.ordinary_norm a).mpr h) (fun a p h => by simpa only [Ty.assume_norm] using h)

theorem Ctx.TypeMap.values {Γ Δ} (h : Ctx.TypeMap Γ Δ) :
    Term.ImagesSorted Γ Δ (renEnv _root_.id).values := by
  intro i a s hi ha
  obtain ⟨b, hb, hs, ho, _⟩ := h.lookup i a hi
  exact ⟨.var i, rfl, ⟨b, hb, ho ha.ordinary⟩, b, hb, hs s ha⟩

theorem Ctx.TypeMap.references {Γ Δ} (h : Ctx.TypeMap Γ Δ) :
    Term.ImageReferences Γ Δ (renEnv _root_.id).values := by
  intro i a hi ho u hu
  cases hu
  obtain ⟨b, hb, _, ho', _⟩ := h.lookup i a hi
  exact ⟨b, hb, ho' ho⟩

theorem Ctx.TypeMap.facts {Γ Δ} (h : Ctx.TypeMap Γ Δ) {p : Pred} (hp : p ∈ Γ.facts) : p ∈ Δ.facts := by
  obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
  obtain ⟨b, hb, _, _, hf⟩ := h.lookup i a hi
  exact Ctx.mem_facts.mpr ⟨i, b, q, hb, hf q hq, rfl⟩

theorem Ctx.TypeMap.transport {Γ Δ} (h : Ctx.TypeMap Γ Δ) (Φ : List Pred) :
    Transport (renEnv _root_.id) Γ Φ Δ Φ := by
  refine ⟨h.values, h.references, (by intro i; simp [renEnv]), ?_⟩
  intro p hp
  simp only [renEnv_values, id_eq, predBind_id]
  apply Entails.hyp
  rcases List.mem_append.mp hp with hp | hp
  · exact List.mem_append_left _ (h.facts hp)
  · exact List.mem_append_right _ hp

theorem Ctx.TypeMap.extend {Γ Δ} (h : Ctx.TypeMap Γ Δ) (a b : Ty)
    (hs : ∀ s, a.HasSort s → b.HasSort s) (ho : Ordinary a → Ordinary b)
    (hf : ∀ p ∈ a.assume, p ∈ b.assume) : Ctx.TypeMap (Γ.extend a) (Δ.extend b) := by
  constructor
  intro i t hi
  have shifted : ∀ a b : Ty, (∀ s, a.HasSort s → b.HasSort s) → (Ordinary a → Ordinary b) →
      (∀ p ∈ a.assume, p ∈ b.assume) →
      (∀ s, (a.shiftV 1 0).HasSort s → (b.shiftV 1 0).HasSort s) ∧
      (Ordinary (a.shiftV 1 0) → Ordinary (b.shiftV 1 0)) ∧
      (∀ p ∈ (a.shiftV 1 0).assume, p ∈ (b.shiftV 1 0).assume) := by
    intro a b hs ho hf
    refine ⟨fun s hi => (Ty.hasSort_shiftV _ _ _ _).mpr (hs s ((Ty.hasSort_shiftV _ _ _ _).mp hi)),
      fun hi => (Ty.ordinary_shiftV _ _ _).mpr (ho ((Ty.ordinary_shiftV _ _ _).mp hi)), ?_⟩
    intro p hp
    rw [Ty.assume_shiftV] at hp ⊢
    obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
    exact List.mem_map.mpr ⟨q, hf q hq, rfl⟩
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    exact ⟨b.shiftV 1 0, rfl, (shifted a b hs ho hf).1,
      (shifted a b hs ho hf).2.1, (shifted a b hs ho hf).2.2⟩
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u => cases u with
      | none => simp [hg] at hi
      | some u =>
        simp only [hg, Option.map_some, Option.some.injEq] at hi
        cases hi
        obtain ⟨v, hv, hs, ho, hf⟩ := h.lookup i u hg
        exact ⟨v.shiftV 1 0, by simp [Ctx.extend, List.getElem?_map, hv],
          (shifted u v hs ho hf).1, (shifted u v hs ho hf).2.1, (shifted u v hs ho hf).2.2⟩

theorem Ty.LeQ.context {Γ Δ Φ a b} (h : Ty.LeQ P Γ Φ a b) (hm : Ctx.TypeMap Γ Δ) : Ty.LeQ P Δ Φ a b := by
  simpa only [Ty.rawBind_id] using h.rawBind (renEnv _root_.id) (hm.transport Φ)
theorem TelLe.context {Γ Δ Φ t u} (h : TelLe P Γ Φ t u) (hm : Ctx.TypeMap Γ Δ) : TelLe P Δ Φ t u := by
  simpa only [Tel.rawBind_id] using h.rawBind (renEnv _root_.id) (hm.transport Φ)
theorem TelClosure.context {Γ Δ Φ t u} (h : TelClosure P Γ Φ t u) (hm : Ctx.TypeMap Γ Δ) : TelClosure P Δ Φ t u := by
  simpa only [Tel.rawBind_id] using h.rawBind (renEnv _root_.id) (hm.transport Φ)

theorem TelLe.norm {Γ Φ t u} (h : TelLe P Γ Φ t u) : TelLe P Γ Φ (Tel.norm t) (Tel.norm u) := by
  simpa only [Tel.bind, Tel.rawBind_id] using h.bind (renEnv _root_.id) (Transport.id Γ Φ)
theorem TelClosure.norm {Γ Φ t u} (h : TelClosure P Γ Φ t u) : TelClosure P Γ Φ (Tel.norm t) (Tel.norm u) := by
  simpa only [Tel.bind, Tel.rawBind_id] using h.bind (renEnv _root_.id) (Transport.id Γ Φ)

mutual
  theorem Ty.Sorted.context {Γ Δ : Ctx} {a : Ty} (h : a.Sorted Γ) (hm : Ctx.TypeMap Γ Δ) : a.Sorted Δ := by
    cases a <;> simp only [Ty.Sorted] at h ⊢
    all_goals first
      | trivial
      | exact Ty.Sorted.context h hm
      | exact sortedTys_context h hm
      | exact Tel.Sorted.context h hm
      | skip
    case fn _ _ _ _ => exact ⟨sortedTys_context h.1 hm, Ty.Sorted.context h.2.1 hm, sortedEff_context h.2.2 hm⟩
    case cont _ _ _ => exact ⟨Ty.Sorted.context h.1 hm, Ty.Sorted.context h.2.1 hm, sortedEff_context h.2.2 hm⟩
    case map _ _ => exact ⟨Ty.Sorted.context h.1 hm, Ty.Sorted.context h.2 hm⟩
    case refined _ _ =>
      refine ⟨Ty.Sorted.context h.1 hm, ?_⟩
      simpa only [renEnv_values, id_eq, upValues_id, predBind_id] using
        Pred.sorted_bind h.2 (renEnv _root_.id).values (fun _ h => h) (fun h => h) hm.values hm.references
  theorem Tel.Sorted.context {Γ Δ : Ctx} {t : Tel} (h : Tel.Sorted Γ t) (hm : Ctx.TypeMap Γ Δ) : Tel.Sorted Δ t := by
    cases t with
    | done r e => exact ⟨Ty.Sorted.context h.1 hm, sortedEff_context h.2 hm⟩
    | param n a t => exact ⟨Ty.Sorted.context h.1 hm,
        Tel.Sorted.context h.2 (hm.extend a a (fun _ h => h) (fun h => h) (fun _ h => h))⟩
  theorem sortedTys_context {Γ Δ : Ctx} {as : List Ty} (h : sortedTys Γ as) (hm : Ctx.TypeMap Γ Δ) : sortedTys Δ as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Sorted.context h.1 hm, sortedTys_context h.2 hm⟩
  theorem sortedEff_context {Γ Δ : Ctx} {e : Eff} (h : sortedEff Γ e) (hm : Ctx.TypeMap Γ Δ) : sortedEff Δ e := by
    cases e; exact sortedTys_context h hm
end

end Benitoite.Release.Refinement
