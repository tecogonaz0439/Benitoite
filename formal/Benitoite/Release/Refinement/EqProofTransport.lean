import Benitoite.Release.Refinement.EqCertificate

/-! # 整数等号の先行参照を仮定の包含へ移す -/
namespace Benitoite.Release.Refinement

theorem EqProof.recontextualize {Φ Δ : List Pred} {mode : EqualityMode} {t u : Term} {c : EqProof}
    (h : c.checkRaw Φ mode t u = true)
    (hm : ∀ a b, Pred.eq a b ∈ Φ → Pred.eq a b ∈ Δ) :
    ∃ d : EqProof, d.checkRaw Δ mode t u = true := by
  induction c generalizing mode t u with
  | refl => exact ⟨.refl, h⟩
  | symm c ih =>
    obtain ⟨d,hd⟩ := ih h
    exact ⟨.symm d, hd⟩
  | trans m l r ihl ihr =>
    simp only [checkRaw, Bool.and_eq_true] at h
    obtain ⟨dl,hl⟩ := ihl h.1
    obtain ⟨dr,hr⟩ := ihr h.2
    exact ⟨.trans m dl dr, by simp only [checkRaw, Bool.and_eq_true]; exact ⟨hl,hr⟩⟩
  | add l r ihl ihr =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    simp only [Bool.and_eq_true] at h
    obtain ⟨dl,hl⟩ := ihl h.1
    obtain ⟨dr,hr⟩ := ihr h.2
    exact ⟨.add dl dr, by simp only [checkRaw, Bool.and_eq_true]; exact ⟨hl,hr⟩⟩
  | neg c ih =>
    cases mode <;> cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    obtain ⟨d,hd⟩ := ih h
    exact ⟨.neg d,hd⟩
  | scale k c ih =>
    cases mode <;> cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    simp only [Bool.and_eq_true] at h
    obtain ⟨d,hd⟩ := ih h.2
    exact ⟨.scale k d, by simp only [checkRaw, Bool.and_eq_true]; exact ⟨h.1,hd⟩⟩
  | hyp i =>
    unfold checkRaw at h
    split at h
    · rename_i a b hi
      obtain ⟨j,hj⟩ := List.mem_iff_getElem?.mp (hm a b (List.mem_of_getElem? hi))
      exact ⟨.hyp j, by simpa only [checkRaw, hj] using h⟩
    · cases h
  | field c ih =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    simp only [Bool.and_eq_true] at h
    obtain ⟨d,hd⟩ := ih h.2
    exact ⟨.field d, by simp only [checkRaw, Bool.and_eq_true]; exact ⟨h.1,hd⟩⟩
  | measure c ih =>
    cases t <;> cases u <;> simp only [checkRaw, Bool.false_eq_true] at h
    simp only [Bool.and_eq_true] at h
    obtain ⟨d,hd⟩ := ih h.2
    exact ⟨.measure d, by simp only [checkRaw, Bool.and_eq_true]; exact ⟨h.1,hd⟩⟩

theorem EqProof.structural_check_context (Φ Δ : List Pred) (t u : Term) (c : EqProof) :
    c.checkRaw Φ .structural t u = c.checkRaw Δ .structural t u := by
  induction c generalizing t u with
  | refl => rfl
  | symm c ih => exact ih _ _
  | trans m l r ihl ihr => simp only [checkRaw, ihl, ihr]
  | neg c ih | scale k c ih | hyp i => rfl
  | add l r ihl ihr =>
    simp only [checkRaw]
    split <;> simp_all
  | field c ih | measure c ih =>
    simp only [checkRaw]
    split <;> simp_all

end Benitoite.Release.Refinement
