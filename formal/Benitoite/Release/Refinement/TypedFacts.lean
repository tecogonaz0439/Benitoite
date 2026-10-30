import Benitoite.Release.Refinement.ValueBinding

/-!
# 型付きの値から得る整数観測と篩の事実

置換の定理を使わずに、元の型付けの導出から事実を取り出す。
-/
namespace Benitoite.Release.Refinement

theorem Ty.LeQ.integerCarrier {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) :
    a.IntegerCarrier ↔ b.IntegerCarrier := by
  induction h with
  | refl => rfl
  | trans _ _ ih₁ ih₂ => exact ih₁.trans ih₂
  | fn_effect _ | list _ _ | lazy _ _ | map_value _ _ _ => rfl
  | forget | introduce _ _ => rfl
  | refine _ _ _ _ ih => exact ih

private theorem const_integer {B c} (h : ConstOK B c) (hi : (Const.type c).IntegerCarrier) :
    ∃ t, (Val.const c).toTerm? = some t ∧ termSorted Γ t := by
  cases c <;> simp_all [Const.type, Benitoite.Release.Const.type, embedTy,
    Ty.IntegerCarrier, Val.toTerm?, termSorted]

theorem HasTypeVQ.integer_observation {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.IntegerCarrier) :
    ∃ t, v.toTerm? = some t ∧ termSorted Γ t := by
  match h with
  | .V_Var hg _ => exact ⟨_, rfl, _, hg, hi⟩
  | .V_Const hc => exact const_integer hc hi
  | .V_Lam _ _ _ _ | .V_List _ _ _ => contradiction
  | .V_Sub hv hl _ _ => exact hv.integer_observation (hl.integerCarrier.mpr hi)
  | .V_Refine hv _ _ _ _ _ => exact hv.integer_observation hi

theorem HasTypeVQ.toTerm_of_integerCarrier {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.IntegerCarrier) :
    ∃ t, v.toTerm? = some t := by
  obtain ⟨t, ht, _⟩ := h.integer_observation hi
  exact ⟨t, ht⟩

@[simp] theorem Pred.open_lift (p : Pred) (t : Term) : p.lift.open t = p := by
  simp only [Pred.open, Pred.lift, predBind_comp]
  exact predBind_id p

theorem HasTypeVQ.assume {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) :
    ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.open (v.toTerm?.getD (.integer 0))) := by
  match h with
  | .V_Var hg _ =>
    intro p hp
    exact .hyp (List.mem_append_left _ (Ctx.mem_facts.mpr ⟨_, _, p, hg, hp, rfl⟩))
  | .V_Const (c := c) _ =>
    cases c <;> simp [Const.type, Benitoite.Release.Const.type, embedTy, Ty.assume]
  | .V_Lam _ _ _ _ | .V_List _ _ _ => intro p hp; cases hp
  | .V_Sub hv hl _ _ =>
    intro p hp
    apply ((hl.assume p hp).bind (fun i => match i with
      | 0 => v.toTerm?.getD (.integer 0) | j+1 => .var j)).cut
    intro q hq
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
    rcases List.mem_append.mp hr with hr | hr
    · exact hv.assume r hr
    · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hr
      change Entails _ (s.lift.open _)
      rw [Pred.open_lift]
      exact .hyp hs
  | .V_Refine hv _ ht _ _ he =>
    intro p hp
    rcases List.mem_cons.mp hp with rfl | hp
    · simpa only [ht, Option.getD_some] using he
    · exact hv.assume p hp

theorem termSorted_bind_congr {Γ t} (ht : termSorted Γ t) {σ τ : Nat → Term}
    (he : ∀ i a, Γ[i]? = some (some a) → a.IntegerCarrier → σ i = τ i) :
    termBind σ t = termBind τ t := by
  induction t with
  | var i => obtain ⟨a, ha, hi⟩ := ht; exact he i a ha hi
  | integer _ => rfl
  | add a b ia ib => simp only [termBind, ia ht.1, ib ht.2]

/-- Sorted が読まない位置の getD の既定値は、述語の像に影響しない。 -/
theorem Pred.bind_congr_sorted {Γ p} (hp : p.Sorted Γ none) {σ τ : Nat → Term}
    (he : ∀ i a, Γ[i]? = some (some a) → a.IntegerCarrier → σ i = τ i) :
    predBind σ p = predBind τ p := by
  induction p with
  | truth | falsity => rfl
  | eq a b | le a b | lt a b =>
    simp only [predBind, termSorted_bind_congr hp.1 he, termSorted_bind_congr hp.2 he]
  | and p q ip iq | or p q ip iq => simp only [predBind, ip hp.1, iq hp.2]
  | not p ip => exact congrArg Pred.not (ip hp)

end Benitoite.Release.Refinement
