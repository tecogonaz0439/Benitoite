import Benitoite.Release.Refinement.BindingShift

namespace Benitoite.Release.Refinement

@[simp] theorem Ty.hasSort_shiftV (a : Ty) (k c : Nat) (s : «Sort») :
    (a.shiftV k c).HasSort s ↔ a.HasSort s := by
  cases a <;> simp only [Ty.shiftV, Ty.HasSort, Ty.sort?]
  case refined a p => exact Ty.hasSort_shiftV a k c s

@[simp] theorem Ty.integerCarrier_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).IntegerCarrier ↔ a.IntegerCarrier := Ty.hasSort_shiftV a k c .integer

@[simp] theorem Ty.ordinary_shiftV (a : Ty) (k c : Nat) :
    Ordinary (a.shiftV k c) ↔ Ordinary a := by
  exact Ty.notContCore_shiftV a k c

theorem Ty.assume_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).assume = a.assume.map (Pred.shiftV k (c+1)) := by
  unfold Ty.assume
  rw [Ty.core_shiftV, Ty.predicates_shiftV]
  cases hc : a.core <;> rfl

/-- 文脈の事実の所属を、lookup と self の開きに分ける。 -/
theorem Ctx.mem_facts {Γ : Ctx} {q : Pred} : q ∈ Γ.facts ↔
    ∃ (i : Nat) (a : Ty) (p : Pred), Γ[i]? = some (some a) ∧ p ∈ a.assume ∧ p.open (.var i) = q := by
  simp only [Ctx.facts, List.mem_flatMap]
  constructor
  · rintro ⟨⟨a, i⟩, hi, hq⟩
    cases a with
    | none => cases hq
    | some a =>
      obtain ⟨p, hp, he⟩ := List.mem_map.mp hq
      exact ⟨i, a, p, List.mk_mem_zipIdx_iff_getElem?.mp hi, hp, he⟩
  · rintro ⟨i, a, p, hi, hp, rfl⟩
    exact ⟨(some a, i), List.mk_mem_zipIdx_iff_getElem?.mpr hi, List.mem_map.mpr ⟨p, hp, rfl⟩⟩


theorem Pred.open_shiftV_self (p : Pred) : (p.shiftV 1 1).open (.var 0) = p := by
  simp only [Pred.shiftV, Pred.open, predBind_comp]
  have hi : (fun i => (some (Term.var (shiftIndex 1 1 i))).bind
      (termBind? (fun j => match j with | 0 => some (Term.var 0) | j+1 => some (.var j)))) =
      (fun i => some (Term.var i)) := by
    funext i
    cases i <;> simp [termBind?, shiftIndex]
  exact (congrArg (fun σ => predBind σ p) hi).trans (predBind_id p)

theorem Pred.open_shiftV_outer (p : Pred) (i : Nat) :
    (p.shiftV 1 1).open (.var (i+1)) = (p.open (.var i)).lift := by
  change (predBind (fun i => some (.var (shiftIndex 1 1 i))) p).open _ = _
  rw [← upValues_shiftIndex]
  exact (predBind_open_renaming (shiftIndex 1 0) p (.var i)).symm

/-- 束縛した値の事実と、外側から移動した事実を区別する。 -/
theorem Ctx.mem_facts_extend {Γ : Ctx} {a : Ty} {q : Pred} :
    q ∈ (Γ.extend a).facts ↔ q ∈ a.assume ∨ ∃ p ∈ Γ.facts, p.lift = q := by
  constructor
  · intro hq
    obtain ⟨i, t, p, hi, hp, he⟩ := Ctx.mem_facts.mp hq
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      rw [Ty.assume_shiftV] at hp
      obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hp
      rw [Pred.open_shiftV_self] at he
      exact Or.inl (he ▸ hr)
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some u =>
        cases u with
        | none => simp [hg] at hi
        | some u =>
          simp only [hg, Option.map_some, Option.map_some, Option.some.injEq] at hi
          cases hi
          rw [Ty.assume_shiftV] at hp
          obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hp
          exact Or.inr ⟨r.open (.var i), Ctx.mem_facts.mpr ⟨i, u, r, hg, hr, rfl⟩,
            (Pred.open_shiftV_outer r i).symm.trans he⟩
  · rintro (hq | ⟨p, hp, rfl⟩)
    · exact Ctx.mem_facts.mpr ⟨0, a.shiftV 1 0, q.shiftV 1 1, rfl,
        by rw [Ty.assume_shiftV]; exact List.mem_map.mpr ⟨q, hq, rfl⟩, Pred.open_shiftV_self q⟩
    · obtain ⟨i, t, r, hi, hr, rfl⟩ := Ctx.mem_facts.mp hp
      exact Ctx.mem_facts.mpr ⟨i+1, t.shiftV 1 0, r.shiftV 1 1,
        by simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, hi, Option.map_some],
        by rw [Ty.assume_shiftV]; exact List.mem_map.mpr ⟨r, hr, rfl⟩,
        Pred.open_shiftV_outer r i⟩

theorem Term.references_map_shiftV {Γ : Ctx} {t : Term} (h : t.References Γ) (k c : Nat) :
    t.References (Γ.map (Option.map (Ty.shiftV k c))) := by
  apply Term.varsIn_mono h
  intro i ⟨a, ha, ho⟩
  exact ⟨a.shiftV k c, by simp [List.getElem?_map, ha], (Ty.ordinary_shiftV _ _ _).mpr ho⟩

theorem Term.hasSort_map_shiftV {Γ : Ctx} {t : Term} {s : «Sort»} (h : t.HasSort Γ s) (k c : Nat) :
    t.HasSort (Γ.map (Option.map (Ty.shiftV k c))) s := by
  have hs : Term.ImagesSorted Γ (Γ.map (Option.map (Ty.shiftV k c))) (fun i => some (.var i)) := by
    intro i a s hi ha
    have hi' : (Γ.map (Option.map (Ty.shiftV k c)))[i]? = some (some (a.shiftV k c)) := by
      simp [List.getElem?_map, hi]
    exact ⟨.var i, rfl, ⟨a.shiftV k c, hi', (Ty.ordinary_shiftV _ _ _).mpr ha.ordinary⟩,
      a.shiftV k c, hi', (Ty.hasSort_shiftV _ _ _ _).mpr ha⟩
  have hr : Term.ImageReferences Γ (Γ.map (Option.map (Ty.shiftV k c))) (fun i => some (.var i)) := by
    intro i a hi ho u hu
    cases hu
    exact ⟨a.shiftV k c, by simp [List.getElem?_map, hi], (Ty.ordinary_shiftV _ _ _).mpr ho⟩
  simpa only [termBind_id] using Term.hasSort_termBind h _ hs hr


/-- 値を持たない束縛には新しい事実がなく、外側の事実だけを lift する。 -/
theorem Ctx.mem_facts_extendNone {Γ : Ctx} {q : Pred} :
    q ∈ Γ.extendNone.facts ↔ ∃ p ∈ Γ.facts, p.lift = q := by
  have he : Γ.extendNone.facts = (Γ.extend (.base .unit)).facts := by
    simp only [Ctx.extendNone, Ctx.extend, Ctx.facts, List.zipIdx_cons,
      List.flatMap_cons, Ty.shiftV, Ty.assume, Ty.core, Ty.refinementPredicates, List.map_nil, List.nil_append]
  rw [he, Ctx.mem_facts_extend]
  simp only [Ty.assume, Ty.core, Ty.refinementPredicates, List.not_mem_nil, false_or]


end Benitoite.Release.Refinement
