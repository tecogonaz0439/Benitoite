import Benitoite.Release.Refinement.StateTyping
namespace Benitoite.Release.Refinement
noncomputable section

theorem closeR_normal {cap : Capture} {R : Option Ty} {r : Ty}
    (h : cap.closeR R = some r) : r.Normal := by
  cases R with
  | none => cases h
  | some a =>
    have he : cap.closeTy a = r := Option.some.inj h
    rw [←he]; exact substTyValues_normal _ _

theorem ContTy.empty_ret {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hk : k = []) : R = Re := by
  induction h with
  | K_Empty => rfl
  | K_Sub _ _ ih => exact ih hk
  | _ => cases hk

private theorem tail {f : Frame} {k : Cont} (he : EndsWithHandle (f :: k))
    (hf : ∀ cap h, f ≠ .handleF cap h) : EndsWithHandle k := by
  obtain ⟨k1, cap, h, hk⟩ := he
  cases k1 with
  | nil => exact absurd (List.cons.inj hk).1 (hf cap h)
  | cons g k1 => exact ⟨k1, cap, h, (List.cons.inj hk).2⟩

private theorem tail' {f : Frame} {k : Cont} (he : EndsWithHandle (f :: k)) (hk : k ≠ []) :
    EndsWithHandle k := by
  obtain ⟨k1, cap, h, hh⟩ := he
  cases k1 with
  | nil => exact absurd (List.cons.inj hh).2 hk
  | cons g k1 => exact ⟨k1, cap, h, (List.cons.inj hh).2⟩

/-- ハンドラで終わる格納の継続の末尾の R は正規形である。 -/
theorem ContTy.end_normal {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (he : EndsWithHandle k) :
    ∀ r, Re = some r → r.Normal := by
  induction h with
  | K_Empty => obtain ⟨k1,_,_,hk⟩ := he; simp at hk
  | K_Sub _ _ ih => exact ih he
  | @K_Handle R ε ec eb cap h' k t b Eb Re Γ Φ Rs ts ecs ebs ht _ _ _ _ hR _ _ _ _ _ _ _ ih =>
    by_cases hk : k = []
    · intro r hr
      have := ContTy.empty_ret ht hk
      subst this
      exact closeR_normal (hR.trans hr)
    · exact ih (tail' he hk)
  | @K_Handle_Fail R ε ec rest E cap h' k t b Eb Re Γ Φ Rs ts ecs Es ht _ _ _ _ hR _ _ _ _ _ _ _ ih =>
    by_cases hk : k = []
    · intro r hr
      have := ContTy.empty_ret ht hk
      subst this
      exact closeR_normal (hR.trans hr)
    · exact ih (tail' he hk)
  | K_Let _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Mark _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Update _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Release _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Drop _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))
  | K_Guard _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ ih => exact ih (tail he (by intro _ _ h; cases h))

/-- StoreOk の下では、継続の場所の格納 R は再開の規則が読む正規化の等号から生の等号へ戻せる（現在の R が正規形のとき）。 -/
theorem resume_raw_return {P B σ Ψ μ l b t e r R k}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.cont b t e r)) (hμ : μ l = some (.cont k))
    (he : r.map Ty.norm = R.map Ty.norm) (hR : ∀ x, R = some x → x.Normal) : r = R := by
  have hc := hs.2.2.2.2 l _ hμ
  obtain ⟨b',t',e',r',hl',hend,_,_,hk⟩ := hc
  rw [hl] at hl'
  cases Option.some.inj hl'
  have hn := ContTy.end_normal hk hend
  cases r with
  | none => cases R <;> simp_all
  | some x =>
    cases R with
    | none => simp at he
    | some y =>
      have h1 : x.norm = x := hn x rfl
      have h2 : y.norm = y := hR y rfl
      have h3 : x.norm = y.norm := Option.some.inj he
      rw [h1, h2] at h3
      rw [h3]

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.resume_raw_return
