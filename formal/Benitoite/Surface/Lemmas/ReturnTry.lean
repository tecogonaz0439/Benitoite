import Benitoite.Surface.Lemmas.PatternSupport

/-! return・try の作用先と型保存（設計書 01-12「`return`」「関数の境界と `escape`：途中の `return` と `try`」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {op : OpPrim}

/-- 末尾の return は最も内側の戻り値の型と計算をそのまま保つ。 -/
theorem returnTail_typed {C Γ r a e ε}
  (he : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ (some r)
    (desugarExpr op .tail e) r ε) :
  HasTypeC (desugarProgram op p) B StoreTy.empty C Γ (some r)
    (desugarExpr op .tail (.returnE a e)) r ε := he

/-- 非末尾の return は同じ R に escape し、外側の R を参照しない。 -/
theorem returnOther_typed {C Γ r a e ε} (hr : TyOK C.length r) (ha : Ty.WF C.length a)
  (he : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ (some r)
    (desugarExpr op .other e) r ε) :
  HasTypeC (desugarProgram op p) B StoreTy.empty C Γ (some r)
    (desugarExpr op .other (.returnE a e)) a ε :=
  .C_Let he (.C_Escape (.V_Var rfl (clean_notCont hr)) ha)

/-- Result の失敗側は同じエラー型を持つ最も内側の R に escape する。 -/
theorem tryResult_typed {C Γ R pos ok err cdo cde e t u et ε}
  (hco : p.cons ok = some cdo) (hce : p.cons err = some cde)
  (hno : cdo.ntys = 2) (hne : cde.ntys = 2)
  (hao : cdo.args = [.tvar 0]) (hae : cde.args = [.tvar 1])
  (hdata : cdo.data = cde.data) (hret : R = some (.data cdo.data [u, et]))
  (he : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
    (desugarExpr op .other e) (.data cdo.data [t, et]) ε)
  (hc : TyOK C.length (.data cdo.data [t, et]))
  (hex : Exhaustive p.declarations.patternProgram (.data cdo.data [t, et])
    [.con ok [.var], .con err [.var]]) :
  HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
    (desugarExpr op pos (.tryResult [u, et] ok err e)) t ε := by
  have ht : TyOK C.length t := hc.1
  have het : TyOK C.length et := hc.2.1
  have hw := Ty.VarsIn.wf _ ht
  have hpok : PatTy (desugarProgram op p) (.con ok [.var]) (.data cdo.data [t, et]) [t] := by
    apply PatTy.P_Con hco (by simp [hno])
    simpa [hao, Ty.subst, Ty.substAt, Ty.shift_zero] using
      (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := t)) PatTys.nil)
  have hperr : PatTy (desugarProgram op p) (.con err [.var]) (.data cdo.data [t, et]) [et] := by
    rw [hdata]
    apply PatTy.P_Con hce (by simp [hne])
    simpa [hae, Ty.subst, Ty.substAt, Ty.shift_zero] using
      (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := et)) PatTys.nil)
  apply HasTypeC.C_Let he
  apply HasTypeC.C_Match (.V_Var rfl (clean_notCont hc))
  · refine HasTypeArms.mkArm_cons hpok (HasTypeC.weakenEff (.C_Return (.V_Var rfl (clean_notCont ht)))
      (Eff.empty_sub _)) (HasTypeArms.mkArm_cons hperr ?_ (.nil hw))
    rw [hret, hdata]
    apply HasTypeC.C_Escape (a := t) (ε := ε) _ hw
    apply HasTypeV.V_Con hce (by simp [hne])
    simpa [hae, Ty.subst, Ty.substAt, Ty.shift_zero, binds] using
      (HasTypeVs.cons (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty)
        (C := C) (Γ := some et :: some (.data cde.data [t, et]) :: Γ)
        (.V_Var rfl (clean_notCont het)) HasTypeVs.nil)
  · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
      Exhaustive.consCongr (Q := desugarProgram op p)
      (P := p.declarations.patternProgram) rfl hex

/-- Option の失敗側は同じ最内の R に None を返し、成功値の型を保つ。 -/
theorem tryOption_typed {C Γ R pos cs cn cds cdn e t u ε}
  (hcs : p.cons cs = some cds) (hcn : p.cons cn = some cdn)
  (hns : cds.ntys = 1) (hnn : cdn.ntys = 1)
  (has : cds.args = [.tvar 0]) (han : cdn.args = [])
  (hdata : cds.data = cdn.data) (hret : R = some (.data cds.data [u]))
  (he : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
    (desugarExpr op .other e) (.data cds.data [t]) ε)
  (hc : TyOK C.length (.data cds.data [t]))
  (hex : Exhaustive p.declarations.patternProgram (.data cds.data [t])
    [.con cs [.var], .con cn []]) :
  HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
    (desugarExpr op pos (.tryOption [u] cs cn e)) t ε := by
  have ht : TyOK C.length t := hc.1
  have hw := Ty.VarsIn.wf _ ht
  have hps : PatTy (desugarProgram op p) (.con cs [.var]) (.data cds.data [t]) [t] := by
    apply PatTy.P_Con hcs (by simp [hns])
    simpa [has, Ty.subst, Ty.substAt, Ty.shift_zero] using
      (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := t)) PatTys.nil)
  have hpn : PatTy (desugarProgram op p) (.con cn []) (.data cds.data [t]) [] := by
    rw [hdata]
    apply PatTy.P_Con hcn (by simp [hnn])
    simpa [han] using (PatTys.nil (P := desugarProgram op p))
  apply HasTypeC.C_Let he
  apply HasTypeC.C_Match (.V_Var rfl (clean_notCont hc))
  · refine HasTypeArms.mkArm_cons hps (HasTypeC.weakenEff (.C_Return (.V_Var rfl (clean_notCont ht)))
      (Eff.empty_sub _)) (HasTypeArms.mkArm_cons hpn ?_ (.nil hw))
    rw [hret, hdata]
    apply HasTypeC.C_Escape (a := t) (ε := ε) _ hw
    apply HasTypeV.V_Con hcn (by simp [hnn])
    simpa [han, binds] using (HasTypeVs.nil (P := desugarProgram op p) (B := B)
      (Ψ := StoreTy.empty) (C := C) (Γ := some (.data cdn.data [t]) :: Γ))
  · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
      Exhaustive.consCongr (Q := desugarProgram op p)
      (P := p.declarations.patternProgram) rfl hex

end Benitoite.Surface
