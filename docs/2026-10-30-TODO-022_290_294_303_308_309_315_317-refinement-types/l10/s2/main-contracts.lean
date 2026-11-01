import Lean
import Benitoite
namespace Benitoite.Release.Refinement
-- HasTypeVQ.shift_values
theorem mainContract0 : ∀ {P B store Q C Γ Φ v a}
      (_h : HasTypeVQ P B store Q C Γ Φ v a) {k c Δ Ξ store'}
      (_hA : Builtins.ValueAssumptions P B)
      (_hstore : StoreTy.WF store)
      (_hpres : StoreTy.PreservesNormals store store')
      (_hm : ShiftMap k c Γ Δ)
      (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)), HasTypeVQ P B store' Q C Δ Ξ (v.rename (shiftIndex k c)) (a.shiftV k c) := @HasTypeVQ.shift_values
#print axioms mainContract0

-- HasTypeCQ.shift_values
theorem mainContract1 : ∀ {P B store Q C Γ Φ R m a e L}
      (_h : HasTypeCQ P B store Q C Γ Φ R m a e L) {k c Δ Ξ store' L'}
      (_hA : Builtins.ValueAssumptions P B)
      (_hstore : StoreTy.WF store)
      (_hext : StoreTy.Extends store store')
      (_hm : FullShiftMap k c Γ Δ)
      (_hL : LocalCtx.Shift k c L L')
      (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)), HasTypeCQ P B store' Q C Δ Ξ (R.map (Ty.shiftV k c)) (m.rename (shiftIndex k c))
        (a.shiftV k c) (Eff.shiftV k c e) L' := @HasTypeCQ.shift_values
#print axioms mainContract1

-- HasTypeVQ.shift_types
theorem mainContract2 : ∀ {P B store Q C Γ Φ v a}
      (_h : HasTypeVQ P B store Q C Γ Φ v a) {C' Δ k c}
      (_hA : Builtins.TypeAssumptions P B) (_hstore : store.WF)
      (_hC : TypeParamRenaming C C' (shiftIndex k c)) (_hn : C'.length=C.length+k)
      (_hm : TypeCtxMap k c Γ Δ), HasTypeVQ P B store Q C' Δ Φ (v.shiftEAt k c) (shiftTypes k c a) := @HasTypeVQ.shift_types
#print axioms mainContract2

-- HasTypeCQ.shift_types
theorem mainContract3 : ∀ {P B store Q C Γ Φ R m a e L}
      (_h : HasTypeCQ P B store Q C Γ Φ R m a e L) {C' Δ k c}
      (_hA : Builtins.TypeAssumptions P B) (_hstore : store.WF)
      (_hC : TypeParamRenaming C C' (shiftIndex k c)) (_hn : C'.length=C.length+k) (_hm : TypeCtxMap k c Γ Δ), HasTypeCQ P B store Q C' Δ Φ (R.map (shiftTypes k c)) (m.shiftEAt k c)
        (shiftTypes k c a) (shiftRowsTypes k c e) (L.shiftEAt k c) := @HasTypeCQ.shift_types
#print axioms mainContract3

-- HasTypeVQ.subst
theorem mainContract4 : ∀ {P B store Q C Γ Φ v a Δ Ξ R σ}
    (_h : HasTypeVQ P B store Q C Γ Φ v a)
    (_hA : Builtins.SubstitutionAssumptions P B)
    (_hstore : StoreTy.WF store)
    (_ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound), HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) := @HasTypeVQ.subst
#print axioms mainContract4

-- HasTypeVQ.subst_under_none
theorem mainContract5 : ∀ {P B store Q C Γ Φ v a Δ Ξ R σ}
    (_h : HasTypeVQ P B store Q C Γ.extendNone (Φ.map Pred.lift) v a)
    (_hA : Builtins.SubstitutionAssumptions P B)
    (_hstore : StoreTy.WF store)
    (_ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound), HasTypeVQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (v.subst (upSubst 1 σ) (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) := @HasTypeVQ.subst_under_none
#print axioms mainContract5

-- HasTypeCQ.subst
theorem mainContract6 : ∀ {P B store Q C Γ Φ R m a e L L' Δ Ξ σ}
    (_h : HasTypeCQ P B store Q C Γ Φ R m a e L)
    (_hA : Builtins.SubstitutionAssumptions P B)
    (_hstore : StoreTy.WF store)
    (_ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (_hL : LocalSubstOk store L σ ρ L'), HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
      (substTyValues σ a) (substEffValues σ e) L' := @HasTypeCQ.subst
#print axioms mainContract6

-- HasTypeCQ.subst_under_none
theorem mainContract7 : ∀ {P B store Q C Γ Φ m a e L L' Δ Ξ σ} {R : Option Ty}
    (_h : HasTypeCQ P B store Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) m a e L)
    (_hA : Builtins.SubstitutionAssumptions P B) (_hstore : store.WF)
    (_ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (_hL : LocalSubstOk store L (upSubst 1 σ) (upLocalSubst 1 ρ) L'), HasTypeCQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      ((R.map (substTyValues σ)).map (Ty.shiftV 1 0))
      (m.subst (upSubst 1 σ) (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) a) (substEffValues (upSubst 1 σ) e) L' := @HasTypeCQ.subst_under_none
#print axioms mainContract7

-- HasTypeVQ.narrow
theorem mainContract8 : ∀ {P B store Q C Γ Φ v a Δ Ξ}
    (_h : HasTypeVQ P B store Q C Γ Φ v a) (_hA : Builtins.ValueAssumptions P B) (_hstore : store.WF) (_hn : Ctx.Narrows P C Γ Φ Δ Ξ), HasTypeVQ P B store Q C Δ Ξ v a := @HasTypeVQ.narrow
#print axioms mainContract8

-- HasTypeCQ.narrow
theorem mainContract9 : ∀ {P B store Q C Γ Φ R m a e L Δ Ξ}
    (_h : HasTypeCQ P B store Q C Γ Φ R m a e L) (_hA : Builtins.ValueAssumptions P B) (_hstore : store.WF) (_hn : Ctx.Narrows P C Γ Φ Δ Ξ), HasTypeCQ P B store Q C Δ Ξ R m a e L := @HasTypeCQ.narrow
#print axioms mainContract9

end Benitoite.Release.Refinement
