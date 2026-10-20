import Benitoite.Surface.Lemmas.PatternSupport
import Benitoite.Surface.Lemmas.BuilderLower

/-! 式の型保存から文の列の型保存を組み立てる（設計書 01-12「ブロック」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {Q : NoFailCtx}

variable {view : CoverageView}

variable {p : Program} {B : Builtins} {op : OpPrim}

/-- 式の帰納法の結論を受け、全ての文の形と束縛の作用先を保つ。 -/
theorem HasBlockQ.desugar_of_expr {Δb : BuilderCtx} {C Γ}
    (hAlign : BuilderCtx.Aligned Γ Δb) (hΔ : BuilderCtx.Clean C.length Δb)
    (preserve : ∀ {Δb C Γ R pos e a ε pe},
      BuilderCtx.Aligned Γ Δb → BuilderCtx.Clean C.length Δb →
      HasTypeQ (p.declarationsFor view) B op Q Δb C Γ R pos e a ε →
      e.Scoped C.length pe Γ.length → EnvClean C.length Γ →
      (∀ r, R = some r → TyOK C.length r) →
      HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarExpr op pos e) a ε Δb.toLocal)
    (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {R pos body a ε pe}
    (h : HasBlockQ (p.declarationsFor view) B op Q Δb C Γ R pos body a ε)
    (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    HasTypeCQ (desugarProgram op p) B StoreTy.empty Q C Γ R (desugarBlock op pos body) a ε Δb.toLocal := by
  have resultWF := Ty.VarsIn.wf _ (HasBlockQ.clean hΔ hwf hsig h sc hΓ hR)
  match h with
  | .B_LastPat _ _ hp hex he =>
      have ha := HasTypeQ.clean hΔ hwf hsig he sc.2 hΓ hR
      apply HasTypeCQ.C_Let (preserve hAlign hΔ he sc.2 hΓ hR)
      apply HasTypeCQ.C_Match (.V_Var rfl (clean_notCont ha))
      · exact HasTypeArmsQ.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
          (HasTypeCQ.weakenEff (.C_Return .V_Const) (Eff.empty_sub _)) (.nil trivial)
      · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
          Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex.exhaustive
  | .B_BindPat (δ := δ) (rest := rest) _ _ hp hex he hb =>
      have ha := scoped_clean sc.1
      have hδ := PatTy.clean hwf.2.2.1 hp ha
      have scb : Block.Scoped C.length pe (binds δ ++ Γ).length rest :=
        by simpa [binds_length, hp.length_eq, Pattern.binders] using sc.2.2
      have hb' := HasBlockQ.desugar_of_expr (BuilderCtx.aligned_binds hAlign _) (BuilderCtx.all_values hΔ _) preserve hwf hsig hb scb (hΓ.binds hδ) hR
      simp only [BuilderCtx.toLocal_values] at hb'
      have hc := HasBlockQ.clean (BuilderCtx.all_values hΔ _) hwf hsig hb scb (hΓ.binds hδ) hR
      apply typedLet (preserve hAlign hΔ he sc.2.1 hΓ hR)
      apply HasTypeCQ.C_Match (.V_Var rfl (clean_notCont ha))
      · exact HasTypeArmsQ.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
          (HasTypeCQ.shiftPattern (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp) hb') (.nil (Ty.VarsIn.wf _ hc))
      · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
          Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex.exhaustive
  | .B_BuilderBind hc _ hb =>
      have ih := HasBlockQ.desugar_of_expr (BuilderCtx.aligned_builder hAlign _) (BuilderCtx.clean_builder hΔ hc)
        preserve hwf hsig hb sc.2
        (by intro i t hi; cases i with
            | zero => simp at hi
            | succ i => exact hΓ i t hi) hR
      exact builderBlock_desugar_typed hc ih
  | .B_Empty =>
      exact .C_Return .V_Const
  | .B_Last h =>
      exact preserve hAlign hΔ h sc hΓ hR
  | .B_LastBind h =>
      exact .C_Let (preserve hAlign hΔ h sc.2 hΓ hR)
        (HasTypeCQ.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
  | .B_LastDiscard h =>
      exact .C_Let (preserve hAlign hΔ h sc hΓ hR)
        (HasTypeCQ.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
  | .B_Bind h hb =>
      exact typedLet (preserve hAlign hΔ h sc.2.1 hΓ hR)
        (by simpa only [BuilderCtx.toLocal_value] using
          HasBlockQ.desugar_of_expr (BuilderCtx.aligned_value hAlign _) (BuilderCtx.clean_value hΔ) preserve hwf hsig hb sc.2.2 (hΓ.cons (scoped_clean sc.1)) hR)
  | .B_Discard h hb =>
      exact typedLet (preserve hAlign hΔ h sc.1 hΓ hR)
        (HasTypeCQ.shiftOne (HasBlockQ.desugar_of_expr hAlign hΔ preserve hwf hsig hb sc.2 hΓ hR))
  | .B_Seq h _ hb =>
      exact typedLet (preserve hAlign hΔ h sc.1 hΓ hR)
        (HasTypeCQ.shiftOne (HasBlockQ.desugar_of_expr hAlign hΔ preserve hwf hsig hb sc.2 hΓ hR))
  | .B_Sub h hl hs hw =>
      exact .C_Sub (HasBlockQ.desugar_of_expr hAlign hΔ preserve hwf hsig h sc hΓ hR) hl hs resultWF

end Benitoite.Surface
