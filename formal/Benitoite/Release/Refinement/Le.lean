import Benitoite.Release.Refinement.NormalizationLogic

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

mutual
/-- 有限の論理の文脈を持つ部分型判断。 -/
inductive Ty.LeQ : Ctx → List Pred → Ty → Ty → Prop where
  | refl {Γ Φ} {a} : Ty.LeQ Γ Φ a a
  | convert {Γ Φ a b} : a.norm = b.norm → Ty.LeQ Γ Φ a b
  | trans {Γ Φ} {a b c} : Ty.LeQ Γ Φ a b → Ty.LeQ Γ Φ b c → Ty.LeQ Γ Φ a c
  | fn_effect {Γ Φ} {ns ps r ε ε'} : Eff.Covers Γ Φ ε' ε →
      Ty.LeQ Γ Φ (.fn ns ps r ε) (.fn ns ps r ε')
  | list {Γ Φ} {a b} : Ty.LeQ Γ Φ a b → Ty.LeQ Γ Φ (.list a) (.list b)
  | lazy {Γ Φ} {a b} : Ty.LeQ Γ Φ a b → Ty.LeQ Γ Φ (.lazy a) (.lazy b)
  | map_value {Γ Φ} {k k' a b} : k = k' → Ty.LeQ Γ Φ a b → Ty.LeQ Γ Φ (.map k a) (.map k' b)
  | forget {Γ Φ} {a p} : Ty.LeQ Γ Φ (.refined a p) a
  | introduce {Γ Φ} {a p} : p.Sorted Γ (some a) → Entails (assumptions Γ Φ a) p →
      Ty.LeQ Γ Φ a (.refined a p)
  | refine {Γ Φ} {a b p q} : Ty.LeQ Γ Φ a b → p.Sorted Γ (some a) → q.Sorted Γ (some b) →
      Entails (p :: assumptions Γ Φ a) q → Ty.LeQ Γ Φ (.refined a p) (.refined b q)

  | dependentFn {Γ Φ t u} : TelClosure Γ Φ t u → Ty.LeQ Γ Φ (.dependentFn t) (.dependentFn u)
  | scoped {Γ Φ o k inner outer} : RangeIx.Covers outer inner →
      Ty.LeQ Γ Φ (.scoped o k inner) (.scoped o k outer)
  | scoped_forget {Γ Φ o k ix} : Ty.LeQ Γ Φ (.scoped o k ix) (.opaque o ix)

inductive TelLe : Ctx → List Pred → Tel → Tel → Prop where
  | done {Γ Φ r s e f} : Ty.LeQ Γ Φ r s → Eff.Covers Γ Φ f e →
      TelLe Γ Φ (.done r e) (.done s f)
  | param {Γ Φ n a b t u} : Ty.LeQ Γ Φ b a →
      TelLe (Γ.extend b) (Φ.map Pred.lift) t u →
      TelLe Γ Φ (.param n a t) (.param n b u)

inductive TelClosure : Ctx → List Pred → Tel → Tel → Prop where
  | refl {Γ Φ t} : TelClosure Γ Φ t t
  | tail {Γ Φ t u v} : TelClosure Γ Φ t u → TelLe Γ Φ u v → TelClosure Γ Φ t v
end

/-- 正規化の前後の型を、検査した構造等号でつなぐ。 -/
theorem Ty.LeQ.norm {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) : Ty.LeQ Γ Φ a.norm b.norm :=
  .trans (.convert (Ty.norm_idem a)) (.trans h (.convert (Ty.norm_idem b).symm))

theorem Ty.LeQ.notContCore {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) : a.NotContCore ↔ b.NotContCore := by
  match h with
  | .refl => rfl
  | .convert he => rw [← Ty.notContCore_norm a, he, Ty.notContCore_norm]
  | .trans h₁ h₂ => exact h₁.notContCore.trans h₂.notContCore
  | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget => simp [Ty.NotContCore, Ty.core]
  | .forget | .introduce _ _ => rfl
  | .refine hv _ _ _ => exact hv.notContCore

/-- 部分型の導出で、行き先の各最外の事実を元の事実から導く。 -/
theorem Ty.LeQ.assume {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) :
    ∀ q ∈ b.assume, Entails (a.assume ++ (Γ.facts ++ Φ).map Pred.lift) q := by
  match h with
  | .refl => intro q hq; exact .hyp (List.mem_append_left _ hq)
  | .convert he =>
    exact Ty.assume_of_norm_eq he _ (fun q hq => .hyp (List.mem_append_left _ hq))
  | .trans h₁ h₂ =>
    have ih₁ := Ty.LeQ.assume h₁
    have ih₂ := Ty.LeQ.assume h₂
    intro q hq
    apply (ih₂ q hq).cut
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact ih₁ r hr
    · exact .hyp (List.mem_append_right _ hr)
  | .fn_effect _ | .dependentFn _ | .scoped _ | .scoped_forget => intro q hq; cases hq
  | .list _ => intro q hq; cases hq
  | .lazy _ => intro q hq; cases hq
  | .map_value _ _ => intro q hq; cases hq
  | .forget =>
    intro q hq
    rw [Ty.assume_refined (Ty.assume_ordinary hq)]
    exact .hyp (List.mem_append_left _ (List.mem_append_left _ hq))
  | .introduce (a := a) _ hp =>
    intro q hq
    have ho := Ty.assume_ordinary hq
    rw [Ty.assume_refined (a := a) ho] at hq
    rcases List.mem_append.mp hq with hq | hq
    · exact .hyp (List.mem_append_left _ hq)
    · exact Entails.conjuncts hp q hq
  | .refine (a := a) (b := b) (p := p) (q := q) hv _ _ hp =>
    by_cases ho : a.Ordinary
    · have hob : b.Ordinary := hv.notContCore.mp ho
      have ih := Ty.LeQ.assume hv
      have hsa := Ty.assume_refined ho p
      have hsb := Ty.assume_refined hob q
      have liftOld : ∀ r ∈ assumptions Γ Φ a,
          Entails (assumptions Γ Φ (.refined a p)) r := by
        intro r hr
        simp only [assumptions, hsa] at *
        rcases List.mem_append.mp hr with hr | hr
        · exact .hyp (List.mem_append_left _ (List.mem_append_left _ hr))
        · exact .hyp (List.mem_append_right _ hr)
      have hp' : Entails (assumptions Γ Φ (.refined a p)) _ := hp.cut (by
        intro r hr
        simp only [assumptions, hsa] at *
        rcases List.mem_cons.mp hr with rfl | hr
        · exact Entails.of_conjuncts (fun q hq =>
            .hyp (List.mem_append_left _ (List.mem_append_right _ hq)))
        · exact liftOld r hr)
      intro q hq
      rw [hsb] at hq
      rcases List.mem_append.mp hq with hq | hq
      · exact (ih q hq).cut liftOld
      · exact Entails.conjuncts hp' q hq
    · have hnb : ¬ b.Ordinary := fun hb => ho (hv.notContCore.mpr hb)
      intro r hr
      rw [Ty.assume_eq_nil (a := .refined b q) hnb] at hr
      cases hr

/-- 旧被覆を任意の開いた Γ/Φ の下へ写す。 -/
theorem embedCovers {outer inner : Benitoite.Release.Eff} {Γ Φ}
    (h : Benitoite.Release.Eff.Covers outer inner) :
    Eff.Covers Γ Φ (embedEff outer) (embedEff inner) := by
  refine ⟨?_, ?_⟩
  · intro a ha
    have ha' : embedAtoms inner.atoms a = true := by cases inner; exact ha
    obtain ⟨oa, hoa, rfl⟩ := (embedAtoms_true _ _).mp ha'
    obtain ⟨ob, hob, hba⟩ := h.1 oa hoa
    exact ⟨embedAtom ob, by cases outer; simpa only [embedEff, Eff.mem, Eff.test, Eff.atoms, embedAtoms_embed, Benitoite.Release.Eff.mem, Benitoite.Release.Eff.test, Benitoite.Release.Eff.atoms] using hob,
      embedAtom_covers hba⟩
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
