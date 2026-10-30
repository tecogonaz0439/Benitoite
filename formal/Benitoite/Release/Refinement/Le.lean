import Benitoite.Release.Refinement.Logic

/-!
# 有限の論理を使う部分型と被覆

構文の導出を旧判断と並置し、Fail の比較には正規形の等号を使う。
-/

namespace Benitoite.Release.Refinement

/-- 構造上の包含。内側の行を先に置く。 -/
def Eff.Sub (inner outer : Eff) : Prop :=
  (∀ a, inner.mem a → outer.mem a) ∧ (∀ t, inner.memFail t → outer.memFail t)

/-- 一つの内側の原子に対し、一つの外側の原子を選ぶ被覆。Fail は不変である。 -/
def Eff.Covers (_Γ : Ctx) (_Φ : List Pred) (outer inner : Eff) : Prop :=
  (∀ a, inner.mem a → ∃ b, outer.mem b ∧ b.Covers a) ∧
  (∀ t, inner.memFail t → outer.memFail t)

def assumptions (Γ : Ctx) (Φ : List Pred) (a : Ty) : List Pred :=
  a.assume ++ (Γ.facts ++ Φ).map Pred.lift

/-- 有限の論理の文脈を持つ部分型判断。 -/
inductive Ty.LeQ (Γ : Ctx) (Φ : List Pred) : Ty → Ty → Prop where
  | refl {a} : LeQ Γ Φ a a
  | trans {a b c} : LeQ Γ Φ a b → LeQ Γ Φ b c → LeQ Γ Φ a c
  | fn_effect {ns ps r ε ε'} : Eff.Covers Γ Φ ε' ε →
      LeQ Γ Φ (.fn ns ps r ε) (.fn ns ps r ε')
  | list {a b} : LeQ Γ Φ a b → LeQ Γ Φ (.list a) (.list b)
  | lazy {a b} : LeQ Γ Φ a b → LeQ Γ Φ (.lazy a) (.lazy b)
  | map_value {k k' a b} : k = k' → LeQ Γ Φ a b → LeQ Γ Φ (.map k a) (.map k' b)
  | forget {a p} : LeQ Γ Φ (.refined a p) a
  | introduce {a p} : p.Sorted Γ (some a) → Entails (assumptions Γ Φ a) p →
      LeQ Γ Φ a (.refined a p)
  | refine {a b p q} : LeQ Γ Φ a b → p.Sorted Γ (some a) → q.Sorted Γ (some b) →
      Entails (p :: assumptions Γ Φ a) q → LeQ Γ Φ (.refined a p) (.refined b q)

/-- 部分型の導出で、行き先の各最外の事実を元の事実から導く。 -/
theorem Ty.LeQ.assume {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) :
    ∀ q ∈ b.assume, Entails (a.assume ++ (Γ.facts ++ Φ).map Pred.lift) q := by
  induction h with
  | refl => intro q hq; exact .hyp (List.mem_append_left _ hq)
  | trans _ _ ih₁ ih₂ =>
    intro q hq
    apply (ih₂ q hq).cut
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact ih₁ r hr
    · exact .hyp (List.mem_append_right _ hr)
  | fn_effect _ => intro q hq; cases hq
  | list _ _ => intro q hq; cases hq
  | lazy _ _ => intro q hq; cases hq
  | map_value _ _ _ => intro q hq; cases hq
  | forget =>
    intro q hq
    exact .hyp (List.mem_append_left _ (List.mem_cons_of_mem _ hq))
  | introduce _ hp =>
    intro q hq
    rcases List.mem_cons.mp hq with rfl | hq
    · exact hp
    · exact .hyp (List.mem_append_left _ hq)
  | refine _ _ _ hp ih =>
    intro q hq
    rcases List.mem_cons.mp hq with rfl | hq
    · exact hp
    · exact (ih q hq).weaken (fun _ h => List.mem_cons_of_mem _ h)

/-- 旧被覆を任意の開いた Γ/Φ の下へ写す。 -/
theorem embedCovers {outer inner : Benitoite.Release.Eff} {Γ Φ}
    (h : Benitoite.Release.Eff.Covers outer inner) :
    Eff.Covers Γ Φ (embedEff outer) (embedEff inner) := by
  refine ⟨?_, ?_⟩
  · intro a ha
    obtain ⟨b, hb, hba⟩ := h.1 a (by cases inner; exact ha)
    exact ⟨b, (by cases outer; exact hb), hba⟩
  · intro t ht
    cases inner with
    | mk ia fs =>
      obtain ⟨u, hu, he⟩ := ht
      have hum : u ∈ fs.map embedTy := by simpa only [embedEff, Eff.fails, embedTys_eq_map] using hu
      obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hum
      have hi : Benitoite.Release.Eff.memFail (.mk ia fs) x := ⟨x, hx, rfl⟩
      obtain ⟨y, hy, heq⟩ := h.2 x hi
      cases outer with
      | mk oa gs =>
        refine ⟨embedTy y, ?_, ?_⟩
        · simpa only [embedEff, Eff.fails, embedTys_eq_map, List.mem_map] using
            (show ∃ z ∈ gs, embedTy z = embedTy y from ⟨y, hy, rfl⟩)
        · rw [← embedTy_norm, heq, embedTy_norm]
          exact he

/-- 旧 Le の等号と最外関数の二枝を、新判断の規則で再構成する。 -/
theorem embedLe {a b : Benitoite.Release.Ty} {Γ Φ} (h : Benitoite.Release.Ty.Le a b) :
    Ty.LeQ Γ Φ (embedTy a) (embedTy b) := by
  rcases h with rfl | ⟨ns, ps, r, ε, ε', rfl, rfl, hc⟩
  · exact .refl
  · exact .fn_effect (embedCovers hc)

end Benitoite.Release.Refinement
