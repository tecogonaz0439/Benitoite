import Benitoite.Release.Refinement.Shift

/-!
# 束縛の下の置換

自己変数を残し、型と行の像の外側の値を移す。
-/
namespace Benitoite.Release.Refinement

/-- 値の束縛を一つ越える。型と行の像も同じ値の束縛を越える。 -/
def SubstEnv.up (θ : SubstEnv) : SubstEnv :=
  ⟨fun i => (θ.types i).shiftV 1 0, θ.rows.map (Eff.shiftV 1 0), θ.ranges, upValues θ.values⟩

@[simp] theorem SubstEnv.up_types (θ : SubstEnv) (i : Nat) : θ.up.types i = (θ.types i).shiftV 1 0 := rfl
@[simp] theorem SubstEnv.up_rows (θ : SubstEnv) : θ.up.rows = θ.rows.map (Eff.shiftV 1 0) := rfl
@[simp] theorem SubstEnv.up_ranges (θ : SubstEnv) : θ.up.ranges = θ.ranges := rfl
@[simp] theorem SubstEnv.up_values (θ : SubstEnv) : θ.up.values = upValues θ.values := rfl

private theorem rawApply_shiftV (t : Ty) (as : List Ty) (k c : Nat) :
    (rawApply t as).shiftV k c = rawApply (t.shiftV k c) (shiftVTys k c as) := by
  cases t <;> simp only [rawApply, Ty.shiftV]
  case ctor t =>
    cases t <;> cases as <;> simp only [Ty.shiftV, shiftVTys,
      List.headD_nil, List.headD_cons, List.tail_nil, List.tail_cons]
    rename_i a as
    cases as <;> rfl

private theorem predBind_up_shift (σ : Nat → Term) (p : Pred) :
    predBind (upValues (upValues σ)) (p.shiftV 1 1) =
      (predBind (upValues σ) p).shiftV 1 1 := by
  simp only [Pred.shiftV, ← upValues_shiftIndex, predBind_comp]
  congr 1
  rw [upValues_comp, upValues_comp]
  congr 1

private theorem rowFails_shiftV (es : List Eff) (a : Atom → Bool) (k c : Nat) :
    shiftVTys k c (rowFails es a) = rowFails (es.map (Eff.shiftV k c)) a := by
  simp only [shiftVTys_eq_map, rowFails, List.length_map, List.map_flatMap, List.getElem?_map]
  congr 1
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; simp only [Option.map_some, Eff.shiftV, Eff.fails, shiftVTys_eq_map]

private theorem substAtoms_shiftV (es : List Eff) (a : Atom → Bool) (k c : Nat) :
    substAtoms (es.map (Eff.shiftV k c)) a = substAtoms es a := by
  funext x
  simp only [substAtoms, List.length_map, List.getElem?_map]
  congr 1
  apply congrArg (fun f => (List.range es.length).any f)
  funext i
  cases hi : es[i]? with
  | none => rfl
  | some e => cases e; rfl

mutual
  /-- 代入像を up してから束縛下へ入ると、置換後に移動した構文と一致する。 -/
  theorem Ty.rawBind_up (a : Ty) (θ : SubstEnv) :
      (a.shiftV 1 0).rawBind θ.up = (a.rawBind θ).shiftV 1 0 := by
    cases a <;> simp only [Ty.shiftV, Ty.rawBind, SubstEnv.up_types, SubstEnv.up_ranges, SubstEnv.up_values,
      Ty.rawBind_up, rawBindTys_up, Eff.rawBind_up]
    case tapp i as => exact (rawApply_shiftV _ _ _ _).symm
    case refined a p => exact congrArg (Ty.refined _) (predBind_up_shift θ.values p)
  theorem rawBindTys_up (as : List Ty) (θ : SubstEnv) :
      rawBindTys θ.up (shiftVTys 1 0 as) = shiftVTys 1 0 (rawBindTys θ as) := by
    cases as <;> simp only [shiftVTys, rawBindTys, Ty.rawBind_up, rawBindTys_up]
  theorem Eff.rawBind_up (e : Eff) (θ : SubstEnv) :
      Eff.rawBind θ.up (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.rawBind θ e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.shiftV, Eff.rawBind, SubstEnv.up_ranges, SubstEnv.up_rows, rawBindTys_up, substAtoms_shiftV]
      congr 1
      simp only [shiftVTys_eq_map, List.map_append]
      congr 1
      simpa only [shiftVTys_eq_map] using (rowFails_shiftV θ.rows a 1 0).symm
end

theorem Ty.bind_up (a : Ty) (θ : SubstEnv) :
    (a.shiftV 1 0).bind θ.up = (a.bind θ).shiftV 1 0 := by
  simp only [Ty.bind, Ty.rawBind_up, Ty.norm_shiftV]

theorem Eff.bind_up (e : Eff) (θ : SubstEnv) :
    Eff.bind θ.up (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.bind θ e) := by
  simp only [Eff.bind, Eff.rawBind_up, Eff.norm_shiftV]

private theorem termSorted_map_shiftV {Γ : Ctx} {t : Term} (h : termSorted Γ t) (k c : Nat) :
    termSorted (Γ.map (Option.map (Ty.shiftV k c))) t := by
  have hm : ∀ i a, Γ[i]? = some (some a) → a.IntegerCarrier →
      termSorted (Γ.map (Option.map (Ty.shiftV k c))) (.var i) := by
    intro i a hi ha
    exact ⟨a.shiftV k c, by simp [List.getElem?_map, hi], (Ty.integerCarrier_shiftV a k c).mpr ha⟩
  simpa only [termBind_id] using termSorted_bind h Term.var hm

/-- 型像で増えた事実を含め、値の束縛の下で移送条件を保つ。 -/
theorem Transport.extend {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a b : Ty)
    (hb : a.IntegerCarrier → b.IntegerCarrier)
    (hf : ∀ p ∈ a.assume, predBind (upValues θ.values) p ∈ b.assume) :
    Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
      (Δ.extend b) (Ψ.map Pred.lift) := by
  constructor
  · intro i t hi htInt
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      refine ⟨b.shiftV 1 0, rfl, ?_⟩
      exact (Ty.integerCarrier_shiftV _ 1 0).mpr
        (hb ((Ty.integerCarrier_shiftV a 1 0).mp htInt))
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
          have hs := ht.values i u hg ((Ty.integerCarrier_shiftV u 1 0).mp htInt)
          exact termSorted_lift (termSorted_map_shiftV hs 1 0) (some (b.shiftV 1 0))
  · have hl : ∀ {p}, Entails (Δ.facts ++ Ψ) p →
        Entails ((Δ.extend b).facts ++ Ψ.map Pred.lift) p.lift := by
      intro p he
      apply (he.bind (fun i => .var (i+1))).weaken
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
  ht.extend a (a.bind θ) (fun h => h.bind θ) (Ty.assume_bind a θ)

/-- 生の型注釈を使う項の置換にも同じ束縛の証明を渡す。 -/
theorem Transport.up_raw {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a : Ty) :
    Transport θ.up (Γ.extend a) (Φ.map Pred.lift)
      (Δ.extend (a.rawBind θ)) (Ψ.map Pred.lift) := by
  apply ht.extend a (a.rawBind θ)
  · intro h
    simpa only [Ty.bind, Ty.integerCarrier_norm] using h.bind θ
  · intro p hp
    simpa only [Ty.bind, Ty.assume_norm] using Ty.assume_bind a θ p hp

/-- 値を持たない束縛には新しい事実がなく、外側の事実だけを lift する。 -/
theorem Ctx.mem_facts_extendNone {Γ : Ctx} {q : Pred} :
    q ∈ Γ.extendNone.facts ↔ ∃ p ∈ Γ.facts, p.lift = q := by
  have he : Γ.extendNone.facts = (Γ.extend (.base .unit)).facts := by
    simp only [Ctx.extendNone, Ctx.extend, Ctx.facts, List.zipIdx_cons,
      List.flatMap_cons, Ty.shiftV, Ty.assume, List.map_nil, List.nil_append]
  rw [he, Ctx.mem_facts_extend]
  simp only [Ty.assume, List.not_mem_nil, false_or]

/-- None の束縛も番号を残し、外側の移送条件を up で保つ。 -/
theorem Transport.extendNone {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) :
    Transport θ.up Γ.extendNone (Φ.map Pred.lift) Δ.extendNone (Ψ.map Pred.lift) := by
  constructor
  · intro i t hi htInt
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
          simp only [hg, Option.map_some, Option.map_some, Option.some.injEq] at hi
          cases hi
          have hs := ht.values i u hg ((Ty.integerCarrier_shiftV u 1 0).mp htInt)
          exact termSorted_lift (termSorted_map_shiftV hs 1 0) none
  · have hl : ∀ {p}, Entails (Δ.facts ++ Ψ) p →
        Entails (Δ.extendNone.facts ++ Ψ.map Pred.lift) p.lift := by
      intro p he
      apply (he.bind (fun i => .var (i+1))).weaken
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

end Benitoite.Release.Refinement
