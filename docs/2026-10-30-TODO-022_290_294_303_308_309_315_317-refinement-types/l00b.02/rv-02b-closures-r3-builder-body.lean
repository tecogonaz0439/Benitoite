import Benitoite.Release.Refinement.StateTyping
import Benitoite.Release.Refinement.ClosureTyping

/-! builderBody_keepsBound の前提の検討。C_BuilderLet の結果・行・R と L の未使用の位置は正準形とは限らない。 -/
namespace Benitoite.Release.Refinement
noncomputable section

def imageKind (b : BuilderKind) : BuilderKind := substKind builderValueSubst (renameKind (shiftIndex 1 0) b)
def imageLocal (L : LocalCtx) : LocalCtx := L.map (Option.map imageKind)

theorem builderValueSubst_eq : openValue (.const .unit) = builderValueSubst := by funext j; cases j <;> rfl

/-- 前提 hR・ha・he・hk・hL を外し、結論を像で述べた形。 -/
theorem HasTypeCQ.builderBody_image {P B Ψ Q C Γ Φ} {R : Option Ty} {body : Comp} {a : Ty} {e : Eff} {L k}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF) (hΓ : Ctx.WF 0 C.length Γ)
    (hb : HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) body
      (a.shiftV 1 0) (e.shiftV 1 0) (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)) :
    HasTypeCQ P B Ψ Q C Γ Φ ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst))
      (body.subst builderValueSubst LocalRef.bound)
      (substTyValues builderValueSubst (a.shiftV 1 0)) (substEffValues builderValueSubst (e.shiftV 1 0))
      (some (substKind builderValueSubst (renameKind (shiftIndex 1 0) k)) :: imageLocal L) := by
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
          rw [Ty.canonical_of_wf (hΓ _ _ hx),builderValueSubst_eq] at this
          exact this
        by_cases ho : t.Ordinary
        · refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
          rw [hn]; exact .V_Var hx ho
        · cases t <;> simp [Ty.Ordinary] at ho
          case cont b t e => exact .contVar rfl rfl (by rw [hn]; exact hx)
  have hf : ∀ p ∈ Φ.map Pred.lift, Entails (Γ.facts ++ Φ)
      (predBind (valEnv builderValueSubst).values p) := by
    intro p hp
    obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
    rw [←builderValueSubst_eq, Pred.openValue_lift]
    exact .hyp (List.mem_append_right _ hq)
  have hl : LocalSubstOk Ψ (LocalCtx.extend (some (renameKind (shiftIndex 1 0) k)) L)
      builderValueSubst LocalRef.bound
      (some (substKind builderValueSubst (renameKind (shiftIndex 1 0) k)) :: imageLocal L) := by
    intro i b hi
    cases i with
    | zero =>
      simp only [LocalCtx.extend,List.getElem?_cons_zero,Option.some.injEq] at hi
      cases hi; exact .bound rfl
    | succ i =>
      simp only [LocalCtx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi
      obtain ⟨x,hx,hh⟩ := Option.map_eq_some_iff.mp hi
      cases x with
      | none => cases hh
      | some c =>
        cases hh
        exact .bound (by simp [imageLocal,hx,imageKind])
  exact hb.subst hA hw hs hf LocalRef.bound hl

/-- 閉じる像は正規化を区別しない: 像の L で CaptureLocals を作り直せる。 -/
theorem substKind_image (ν : Nat → Val) (b : BuilderKind) : substKind ν (imageKind b) = substKind ν b := by
  cases b with
  | string | bytes => rfl
  | list a =>
    have h := Ty.openValue_shift a (.const .unit)
    rw [builderValueSubst_eq] at h
    simp only [imageKind,substKind,renameKind_shift,h]
    exact congrArg BuilderKind.list (Ty.rawBind_norm_congr _ (Ty.norm_idem a))

/-- keepsBound の he を満たさない行の例: Fail の重複。 -/
def dupEff : Eff := .mk (fun _ => false) [.base .unit, .base .unit]

theorem dup_not_canonical : ¬ dupEff.Canonical := by
  intro h
  have hf := congrArg Eff.fails h
  simp only [dupEff,Eff.norm,Ty.normTys_eq_map] at hf
  have hp := Order.pairwise_sortUnique (cmp := tyCompare) ([Ty.base .unit,Ty.base .unit].map Ty.norm)
  have hf' : Order.sortUnique tyCompare (List.map Ty.norm [Ty.base BaseTy.unit, Ty.base BaseTy.unit]) = [Ty.base .unit,Ty.base .unit] := hf
  rw [hf'] at hp
  have h1 := (List.pairwise_cons.mp hp).1 (.base .unit) (by simp)
  have h2 : tyCompare (.base .unit) (.base .unit) = .eq := (tyCompare_eq_iff _ _).mpr rfl
  rw [h2] at h1; cases h1

theorem keepsBound_he_fails : substEffValues builderValueSubst (dupEff.shiftV 1 0) ≠ dupEff := by
  intro h
  apply dup_not_canonical
  have hn : (substEffValues builderValueSubst (dupEff.shiftV 1 0)).norm = substEffValues builderValueSubst (dupEff.shiftV 1 0) := Eff.norm_idem _
  rw [h] at hn; exact hn

/-- その行のまま builderLet が型付く: C_BuilderLet は ε に何も要求しない。 -/
theorem builderLet_at_dup (P : Program) (B : Builtins) (Ψ : StoreTy) (Γ : Ctx) :
    HasTypeC P B Ψ [] Γ [] none (.builderLet .string (.ret (.const .unit))) (.base .unit) dupEff := by
  refine .C_BuilderLet ⟨trivial,trivial,trivial⟩ ⟨rfl,[],rfl,?_⟩ (.C_Eff (.C_Return (.V_Const trivial)) ?_) trivial
  · intro i x k hx hk
    cases i with
    | zero => cases hx; cases hk; exact trivial
    | succ i => simp at hx
  · exact ⟨(by intro a ha; cases ha),(by intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx)⟩
#print axioms HasTypeCQ.builderBody_image
#print axioms keepsBound_he_fails
#print axioms builderLet_at_dup
end
end Benitoite.Release.Refinement
