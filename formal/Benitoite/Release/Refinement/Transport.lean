import Benitoite.Release.Refinement.EffectCover

/-!
# 有限の仮定と整数観測の移送

部分型の置換に必要な条件を構文の導出で表す。
型付きの値の像からこの条件を導く仕事とは区別する。
-/
namespace Benitoite.Release.Refinement

@[simp] theorem Ty.integerCarrier_norm (a : Ty) : a.norm.IntegerCarrier ↔ a.IntegerCarrier := by
  cases a <;> simp only [Ty.norm, Ty.IntegerCarrier, Ty.integerCarrier_norm]

/-- 整数 carrier の骨格は四名前空間の置換で保たれる。 -/
theorem Ty.IntegerCarrier.bind {a : Ty} (h : a.IntegerCarrier) (θ : SubstEnv) :
    (a.bind θ).IntegerCarrier := by
  unfold Ty.bind
  rw [Ty.integerCarrier_norm]
  cases a <;> try (simp only [Ty.IntegerCarrier] at h)
  case base b => exact h
  case refined a p =>
    change (a.rawBind θ).IntegerCarrier
    have hi := Ty.IntegerCarrier.bind h θ
    simpa only [Ty.bind, Ty.integerCarrier_norm] using hi

@[simp] theorem Ty.assume_norm (a : Ty) : a.norm.assume = a.assume := by
  cases a <;> simp only [Ty.norm, Ty.assume, Ty.assume_norm]

/-- 型像が新しい篩を含んでも、元の最外の事実を失わない。 -/
theorem Ty.assume_bind (a : Ty) (θ : SubstEnv) :
    ∀ p ∈ a.assume, predBind (upValues θ.values) p ∈ (a.bind θ).assume := by
  unfold Ty.bind
  rw [Ty.assume_norm]
  cases a <;> simp only [Ty.assume]
  all_goals first | exact fun _ h => False.elim (List.not_mem_nil h) | skip
  case refined a p =>
    intro q hq
    rcases List.mem_cons.mp hq with rfl | hq
    · exact List.mem_cons_self
    · exact List.mem_cons_of_mem _ (by simpa only [Ty.bind, Ty.assume_norm] using Ty.assume_bind a θ q hq)

/-- 元の整数の観測を、行き先で型のある整数項へ写す構文の条件。 -/
structure Transport (θ : SubstEnv) (Γ : Ctx) (Φ : List Pred) (Δ : Ctx) (Ψ : List Pred) : Prop where
  values : ∀ i a, Γ[i]? = some (some a) → a.IntegerCarrier → termSorted Δ (θ.values i)
  facts : ∀ p ∈ Γ.facts ++ Φ, Entails (Δ.facts ++ Ψ) (predBind θ.values p)

/-- 文脈を一つ増やすと、外側の整数観測の番号が一つ上がる。 -/
theorem termSorted_lift {Γ : Ctx} {t : Term} (h : termSorted Γ t) (a : Option Ty) :
    termSorted (a :: Γ) (termBind (fun i => .var (i+1)) t) := by
  apply termSorted_bind h
  intro i b hb hi
  exact ⟨b, by simpa only [List.getElem?_cons_succ] using hb, hi⟩

theorem Pred.sorted_bind {Γ Δ : Ctx} {a b : Ty} {p : Pred} (h : p.Sorted Γ (some a))
    (σ : Nat → Term) (ha : a.IntegerCarrier → b.IntegerCarrier)
    (hs : ∀ i t, Γ[i]? = some (some t) → t.IntegerCarrier → termSorted Δ (σ i)) :
    (predBind (upValues σ) p).Sorted Δ (some b) := by
  have hu : ∀ i t, (some a :: Γ)[i]? = some (some t) → t.IntegerCarrier →
      termSorted (some b :: Δ) (upValues σ i) := by
    intro i t ht hi
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at ht
      cases ht
      exact ⟨b, rfl, ha hi⟩
    | succ i =>
      exact termSorted_lift (hs i t ht hi) (some b)
  induction p with
  | truth | falsity => trivial
  | eq x y | le x y | lt x y => exact ⟨termSorted_bind h.1 _ hu, termSorted_bind h.2 _ hu⟩
  | and p q ip iq | or p q ip iq => exact ⟨ip h.1, iq h.2⟩
  | not p ip => exact ip h

/-- 元の型の事実と Γ/Φ の像を、新しい型の事実と Δ/Ψ から導く。 -/
theorem Transport.assumptions {θ Γ Φ Δ Ψ} (ht : Transport θ Γ Φ Δ Ψ) (a : Ty) :
    ∀ p ∈ assumptions Γ Φ a,
      Entails (assumptions Δ Ψ (a.bind θ)) (predBind (upValues θ.values) p) := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · exact .hyp (List.mem_append_left _ (Ty.assume_bind a θ p hp))
  · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
    rw [predBind_lift]
    exact ((ht.facts q hq).bind (fun i => .var (i+1))).weaken
      (fun _ h => List.mem_append_right _ h)

/-- 新判断の全構成子に対し、置換後の構文の導出を返す。 -/
theorem Ty.LeQ.bind {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (θ : SubstEnv) {Δ Ψ}
    (ht : Transport θ Γ Φ Δ Ψ) : Ty.LeQ Δ Ψ (a.bind θ) (b.bind θ) := by
  induction h with
  | refl => exact .refl
  | trans _ _ ih₁ ih₂ => exact .trans ih₁ ih₂
  | fn_effect hc => exact .fn_effect (hc.bind θ)
  | list _ ih => exact .list ih
  | lazy _ ih => exact .lazy ih
  | map_value hk _ ih => exact .map_value (congrArg (Ty.bind θ) hk) ih
  | forget => exact .forget
  | introduce hs he =>
    apply Ty.LeQ.introduce
    · exact Pred.sorted_bind hs θ.values (fun h => h.bind θ) ht.values
    · exact (he.bind (upValues θ.values)).cut (by
        intro p hp
        obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        exact ht.assumptions _ q hq)
  | refine _ hp hq he ih =>
    apply Ty.LeQ.refine ih
    · exact Pred.sorted_bind hp θ.values (fun h => h.bind θ) ht.values
    · exact Pred.sorted_bind hq θ.values (fun h => h.bind θ) ht.values
    · apply (he.bind (upValues θ.values)).cut
      intro p hp
      rcases List.mem_cons.mp hp with rfl | hp
      · exact .hyp List.mem_cons_self
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        exact (ht.assumptions _ q hq).weaken (fun _ => List.mem_cons_of_mem _)

/-- 新判断の全構成子に対し、置換後の構文の導出を返す。 -/
theorem Ty.LeQ.rawBind {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (θ : SubstEnv) {Δ Ψ}
    (ht : Transport θ Γ Φ Δ Ψ) : Ty.LeQ Δ Ψ (a.rawBind θ) (b.rawBind θ) := by
  induction h with
  | refl => exact .refl
  | trans _ _ ih₁ ih₂ => exact .trans ih₁ ih₂
  | fn_effect hc => exact .fn_effect (Eff.covers_norm_right.mp (Eff.covers_norm_left.mp (hc.bind θ)))
  | list _ ih => exact .list ih
  | lazy _ ih => exact .lazy ih
  | map_value hk _ ih => exact .map_value (congrArg (Ty.rawBind θ) hk) ih
  | forget => exact .forget
  | introduce hs he =>
    apply Ty.LeQ.introduce
    · exact Pred.sorted_bind hs θ.values (fun h => by simpa only [Ty.bind, Ty.integerCarrier_norm] using h.bind θ) ht.values
    · exact (he.bind (upValues θ.values)).cut (by
        intro p hp
        obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        simpa only [assumptions, Ty.bind, Ty.assume_norm] using ht.assumptions _ q hq)
  | refine _ hp hq he ih =>
    apply Ty.LeQ.refine ih
    · exact Pred.sorted_bind hp θ.values (fun h => by simpa only [Ty.bind, Ty.integerCarrier_norm] using h.bind θ) ht.values
    · exact Pred.sorted_bind hq θ.values (fun h => by simpa only [Ty.bind, Ty.integerCarrier_norm] using h.bind θ) ht.values
    · apply (he.bind (upValues θ.values)).cut
      intro p hp
      rcases List.mem_cons.mp hp with rfl | hp
      · exact .hyp List.mem_cons_self
      · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
        simpa only [assumptions, Ty.bind, Ty.assume_norm] using
          (ht.assumptions _ q hq).weaken (fun _ => List.mem_cons_of_mem _)

theorem Transport.id (Γ : Ctx) (Φ : List Pred) : Transport (renEnv id) Γ Φ Γ Φ := by
  constructor
  · intro i a hi ha; exact ⟨a, hi, ha⟩
  · intro p hp
    simpa only [renEnv, id_eq, predBind_id] using (Entails.hyp hp)

/-- 子と Fail の正規化を、構文の導出として保存する。 -/
theorem Ty.LeQ.norm {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) : Ty.LeQ Γ Φ a.norm b.norm := by
  simpa only [Ty.bind, Ty.rawBind_id] using h.bind (renEnv id) (Transport.id Γ Φ)

end Benitoite.Release.Refinement
