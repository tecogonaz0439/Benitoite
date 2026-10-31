import Benitoite
namespace Benitoite.Release.Refinement
noncomputable section
/-- 代案の核: 局所参照を場所へ置換せず、値の束縛だけを外しても元の HasTypeCQ で型付く。
kind は局所文脈が束縛に追随して動かすので、Ψ（閉じた実行時のストア）は変わらない。 -/
theorem builderBody_keepsBound {P B Ψ Q C Γ Φ R body a e L k}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) (hΓ : Ctx.WF 0 C.length Γ)
    (hb : HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) body
      (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L))
    (hR : (R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst) = R)
    (ha : substTyValues builderValueSubst (a.shiftV 1 0) = a)
    (he : substEffValues builderValueSubst (e.shiftV 1 0) = e)
    (hk : substKind builderValueSubst (renameKind (shiftIndex 1 0) k) = k)
    (hL : ∀ (i : Nat) (b : BuilderKind), L[i]? = some (some b) →
      substKind builderValueSubst (renameKind (shiftIndex 1 0) b) = b) :
    HasTypeCQ P B Ψ Q C Γ Φ R (body.subst builderValueSubst LocalRef.bound) a e (some k :: L) := by
  have hs : SubstOk P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) Γ Φ
      ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst)) builderValueSubst := by
    intro i b hi
    cases i with
    | zero => simp [Ctx.extendNone] at hi
    | succ i =>
      simp only [Ctx.extendNone,List.getElem?_cons_succ,List.getElem?_map] at hi
      obtain ⟨x,hx,hh⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hh
      | some t =>
        cases hh
        have hn : substTyValues builderValueSubst (t.shiftV 1 0) = t := by
          have := Ty.openValue_shift t (.const .unit)
          rw [Ty.canonical_of_wf (hΓ _ _ hx)] at this
          have he : openValue (.const .unit) = builderValueSubst := by funext j; cases j <;> rfl
          rwa [he] at this
        by_cases ho : t.Ordinary
        · refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
          rw [hn]; exact .V_Var hx ho
        · cases t <;> simp [Ty.Ordinary] at ho
          case cont b t e => exact .contVar rfl rfl (by rw [hn]; exact hx)
  have hf : ∀ p ∈ Φ.map Pred.lift, Entails (Γ.facts ++ Φ)
      (predBind (valEnv builderValueSubst).values p) := by
    intro p hp
    obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    have he : openValue (.const .unit) = builderValueSubst := by funext j; cases j <;> rfl
    rw [←he, Pred.openValue_lift]
    exact .hyp (List.mem_append_right _ hq)
  have hl : LocalSubstOk Ψ (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)
      builderValueSubst LocalRef.bound (some k :: L) := by
    intro i b hi
    cases i with
    | zero =>
      simp only [LocalCtx.extend,List.getElem?_cons_zero,Option.some.injEq] at hi
      cases hi; rw [hk]; exact .bound rfl
    | succ i =>
      simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
      obtain ⟨x,hx,hh⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hh
      | some c => cases hh; rw [hL i c hx]; exact .bound (by simpa using hx)
  have h := hb.subst hA hw hs hf LocalRef.bound hl
  rw [hR,ha,he] at h
  exact h
#print axioms builderBody_keepsBound
end
end Benitoite.Release.Refinement
