import Benitoite.Surface.Lemmas.PatternSupport

/-! 式の型保存から文の列の型保存を組み立てる（設計書 01-12「ブロック」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {op : OpPrim}

/-- 式の帰納法の結論を受け、全ての文の形と束縛の作用先を保つ。 -/
theorem HasBlock.desugar_of_expr
    (preserve : ∀ {C Γ R pos e a ε pe},
      HasType p.declarations B op C Γ R pos e a ε →
      e.Scoped C.length pe Γ.length → EnvClean C.length Γ →
      (∀ r, R = some r → TyOK C.length r) →
      HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R (desugarExpr op pos e) a ε)
    (hwf : p.WellFormed)
    (hsig : ∀ b s, B.sig b = some s → s.Scoped) {C Γ R pos body a ε pe}
    (h : HasBlock p.declarations B op C Γ R pos body a ε)
    (sc : body.Scoped C.length pe Γ.length) (hΓ : EnvClean C.length Γ)
    (hR : ∀ r, R = some r → TyOK C.length r) :
    HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R (desugarBlock op pos body) a ε := by
  match h with
  | .B_LastPat _ _ hp hex he =>
      have ha := HasType.clean hwf hsig he sc.2 hΓ hR
      apply HasTypeC.C_Let (preserve he sc.2 hΓ hR)
      apply HasTypeC.C_Match (.V_Var rfl (clean_notCont ha))
      · exact HasTypeArms.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
          (HasTypeC.weakenEff (.C_Return .V_Const) (Eff.empty_sub _)) (.nil trivial)
      · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
          Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex
  | .B_BindPat (δ := δ) (rest := rest) _ _ hp hex he hb =>
      have ha := scoped_clean sc.1
      have hδ := PatTy.clean hwf.2.2.1 hp ha
      have scb : Block.Scoped C.length pe (binds δ ++ Γ).length rest :=
        by simpa [binds_length, hp.length_eq, Pattern.binders] using sc.2.2
      have hb' := HasBlock.desugar_of_expr preserve hwf hsig hb scb (hΓ.binds hδ) hR
      have hc := HasBlock.clean hwf hsig hb scb (hΓ.binds hδ) hR
      apply typedLet (preserve he sc.2.1 hΓ hR)
      apply HasTypeC.C_Match (.V_Var rfl (clean_notCont ha))
      · exact HasTypeArms.mkArm_cons (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp)
          (HasTypeC.shiftPattern (PatTy.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hp) hb') (.nil (Ty.VarsIn.wf _ hc))
      · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
          Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex
  | .B_Empty =>
      exact .C_Return .V_Const
  | .B_Last h =>
      exact preserve h sc hΓ hR
  | .B_LastBind h =>
      exact .C_Let (preserve h sc.2 hΓ hR)
        (HasTypeC.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
  | .B_LastDiscard h =>
      exact .C_Let (preserve h sc hΓ hR)
        (HasTypeC.weakenEff (.C_Return .V_Const) (Eff.empty_sub _))
  | .B_Bind h hb =>
      exact typedLet (preserve h sc.2.1 hΓ hR)
        (HasBlock.desugar_of_expr preserve hwf hsig hb sc.2.2 (hΓ.cons (scoped_clean sc.1)) hR)
  | .B_Discard h hb =>
      exact typedLet (preserve h sc.1 hΓ hR)
        (HasTypeC.shiftOne (HasBlock.desugar_of_expr preserve hwf hsig hb sc.2 hΓ hR))
  | .B_Seq h _ hb =>
      exact typedLet (preserve h sc.1 hΓ hR)
        (HasTypeC.shiftOne (HasBlock.desugar_of_expr preserve hwf hsig hb sc.2 hΓ hR))
  | .B_Sub h hl hs =>
      exact .C_Sub (HasBlock.desugar_of_expr preserve hwf hsig h sc hΓ hR) hl hs

end Benitoite.Surface
