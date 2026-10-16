import Benitoite.Surface.Lemmas.PatternSupport
import Benitoite.Surface.Lemmas.CallHead

/-! return・try の作用先と型保存（設計書 01-12「`return`」「関数の境界と `escape`：途中の `return` と `try`」）。 -/
namespace Benitoite.Surface
open Benitoite.Release

variable {p : Program} {B : Builtins} {op : OpPrim}

mutual
  /-- 空のストアで R=None の計算は、外側の戻り先を変えても型を保つ。
  内側の lambda・lazy・ガードは既存の境界のままにする。 -/
  theorem HasTypeC.withReturn {P B Ψ C Γ R₀ m a ε}
      (h : HasTypeC P B Ψ C Γ R₀ m a ε) (hΨ : Ψ = StoreTy.empty) (hR : R₀ = none) (R : Option Ty) :
      HasTypeC P B Ψ C Γ R m a ε := by
    match h with
    | .C_Return hv => exact .C_Return hv
    | .C_Sub h hl hs => exact .C_Sub (HasTypeC.withReturn h hΨ hR R) hl hs
    | .C_Let hm hn => exact .C_Let (HasTypeC.withReturn hm hΨ hR R) (HasTypeC.withReturn hn hΨ hR R)
    | .C_App hf hs => exact .C_App hf hs
    | .C_If hv hy hn => exact .C_If hv (HasTypeC.withReturn hy hΨ hR R) (HasTypeC.withReturn hn hΨ hR R)
    | .C_Match hv hs he => exact .C_Match hv (HasTypeArms.withReturn hs hΨ hR R) he
    | .C_Lazy hm => exact .C_Lazy hm
    | .C_Escape _ _ => cases hR
    | .C_Use hv hr hm hs => exact .C_Use hv hr (HasTypeC.withReturn hm hΨ hR R) hs
    | .C_Handle hm he hs => exact .C_Handle (HasTypeC.withReturn hm hΨ hR R) he (HasTypeClauses.withReturn hs hΨ hR R)
    | .C_Resume hi hv => exact .C_Resume hi hv
    | .C_ResumeL hl _ => rw [hΨ] at hl; cases hl
    | .C_Meth hv hc hm hn ht he hs => exact .C_Meth hv hc hm hn ht he hs

  theorem HasTypeArms.withReturn {P B Ψ C Γ R₀ arms a b ε}
      (h : HasTypeArms P B Ψ C Γ R₀ arms a b ε) (hΨ : Ψ = StoreTy.empty) (hR : R₀ = none) (R : Option Ty) :
      HasTypeArms P B Ψ C Γ R arms a b ε := by
    match h with
    | .nil hw => exact .nil hw
    | .plain hp hb hs => exact .plain hp (HasTypeC.withReturn hb hΨ hR R) (HasTypeArms.withReturn hs hΨ hR R)
    | .guarded hp hg hb hs => exact .guarded hp hg (HasTypeC.withReturn hb hΨ hR R) (HasTypeArms.withReturn hs hΨ hR R)

  theorem HasTypeClauses.withReturn {P B Ψ C Γ R₀ cs t ε}
      (h : HasTypeClauses P B Ψ C Γ R₀ cs t ε) (hΨ : Ψ = StoreTy.empty) (hR : R₀ = none) (R : Option Ty) :
      HasTypeClauses P B Ψ C Γ R cs t ε := by
    match h with
    | .nil => exact .nil
    | .cons (k := k) ho hn hp hk hb hs =>
        exact .cons ho hn hp hk (HasTypeC.withReturn hb hΨ (by rw [hR]; rfl) (R.map (Ty.shift k 0)))
          (HasTypeClauses.withReturn hs hΨ hR R)
end

/-- 説明は元の非継続の束縛だけを参照し、分岐内への移動でもその番号を保つ。 -/
theorem dieMessage_typed {P B C Γ R m a ε} (xs : List (Option Ty))
    (h : HasTypeC P B StoreTy.empty C (hideConts Γ) none m a ε) :
    HasTypeC P B StoreTy.empty C (xs ++ Γ) R (m.rename (· + xs.length)) a ε := by
  apply HasTypeC.rename (HasTypeC.withReturn h rfl rfl R)
  intro i a hi
  rw [List.getElem?_append_right (by dsimp; omega)]
  simpa using (hideConts_get.mp hi).1

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

/-- 終了操作は任意の結果型 T に具体化し、既存の Process.Exit だけを行う。 -/
theorem DieExitOk.app_typed {P B C Γ R exit t} (h : DieExitOk B C exit t) :
    HasTypeC P B StoreTy.empty C Γ R
      (.app (.prim exit [t] []) [.const (.integer 1)]) t (Eff.single "Process.Exit") := by
  obtain ⟨s, hs, _, _, ht, he, hn, ha, hf⟩ := h
  have hv := HasTypeV.V_Prim (P := P) (Ψ := StoreTy.empty) (Γ := Γ) hs hn
    (by simpa using ht.symm : [t].length = s.ntys) (by simpa using he.symm : [].length = s.neffs) ha
  rw [hf] at hv
  exact .C_App hv (.cons .V_Const .nil)

/-- 純粋な説明と原因を挿入しても、失敗側の結果型と終了エフェクトを保つ。 -/
theorem dieFailure_typed {P B C Γ R t exit cause message}
    (xs : List (Option Ty)) (hx : DieExitOk B C exit t)
    (hc : HasTypeC P B StoreTy.empty C (xs ++ Γ) R cause (.base .string) Eff.empty)
    (hm : ∀ m, message = some m →
      HasTypeC P B StoreTy.empty C (hideConts Γ) none m (.base .string) Eff.empty) :
    HasTypeC P B StoreTy.empty C (xs ++ Γ) R
      (dieFailure t exit xs.length cause message) t (Eff.single "Process.Exit") := by
  cases message with
  | none => exact .C_Let (HasTypeC.weakenEff hc (Eff.empty_sub _)) (DieExitOk.app_typed hx)
  | some m =>
      exact .C_Let (HasTypeC.weakenEff (dieMessage_typed xs (hm m rfl)) (Eff.empty_sub _))
        (.C_Let (HasTypeC.weakenEff (HasTypeC.shiftOne hc) (Eff.empty_sub _)) (DieExitOk.app_typed hx))

theorem desugar_tryResultDie (pos : Position) (t : Ty) (ok err : ConName) (dict : DictEv)
    (showMethod : MethName) (exit : PrimName) (e : Expr) (message : Option Expr) :
    desugarExpr op pos (.tryResultDie t ok err dict showMethod exit e message) =
      .letIn (desugarExpr op .other e) (.match (.var 0)
        [mkArm (.con ok [.var]) (.ret (.var 0)), mkArm (.con err [.var])
          (dieFailure t exit 2 (.meth (dict.toVal.rename (· + 2)) showMethod [] [] [.var 0])
            (message.map (desugarExpr op .other)))]) := by
  cases message <;> rfl

theorem desugar_tryOptionDie (pos : Position) (t : Ty) (cs cn : ConName)
    (exit : PrimName) (e : Expr) (message : Option Expr) :
    desugarExpr op pos (.tryOptionDie t cs cn exit e message) =
      .letIn (desugarExpr op .other e) (.match (.var 0)
        [mkArm (.con cs [.var]) (.ret (.var 0)), mkArm (.con cn [])
          (dieFailure t exit 1 (.ret (.const (.string "expected a value, got Option.None")))
            (message.map (desugarExpr op .other)))]) := by
  cases message <;> rfl

/-- Result の die は囲む R を要求せず、辞書の表示・説明・終了を型付けする。 -/
theorem tryResultDie_typed {view C Γ R pos ok err cdo cde e t et ε dict showMethod exit message}
    (hco : p.cons ok = some cdo) (hce : p.cons err = some cde)
    (hno : cdo.ntys = 2) (hne : cde.ntys = 2)
    (hao : cdo.args = [.tvar 0]) (hae : cde.args = [.tvar 1]) (hdata : cdo.data = cde.data)
    (he : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
      (desugarExpr op .other e) (.data cdo.data [t, et]) ε)
    (hc : TyOK C.length (.data cdo.data [t, et]))
    (hex : Exhaustive p.declarations.patternProgram (.data cdo.data [t, et])
      [.con ok [.var], .con err [.var]])
    (hd : DieShowOk (p.declarationsFor view) B C Γ dict showMethod et)
    (hx : DieExitOk B C exit t)
    (hm : ∀ m, message = some m → HasTypeC (desugarProgram op p) B StoreTy.empty C (hideConts Γ) none
      (desugarExpr op .other m) (.base .string) Eff.empty) :
    HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
      (desugarExpr op pos (.tryResultDie t ok err dict showMethod exit e message))
      t (Eff.union ε (Eff.single "Process.Exit")) := by
  have ht := hc.1
  have het := hc.2.1
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
  obtain ⟨cl, cd, ms, hd, hcl, hms, htp, hneff, hn, hp, hr, hε⟩ := hd
  have hv := (DictEv.HasType.toVal op hd).rename
    (RenOk.shift [some et, some (.data cdo.data [t, et])] Γ)
  have hshow : HasTypeC (desugarProgram op p) B StoreTy.empty C
      (some et :: some (.data cdo.data [t, et]) :: Γ) R
      (.meth (dict.toVal.rename (· + 2)) showMethod [] [] [.var 0]) (.base .string) Eff.empty := by
    have hargs : HasTypeVs (desugarProgram op p) B StoreTy.empty C
        (some et :: some (.data cdo.data [t, et]) :: Γ) [.var 0]
        (ms.params.map (Ty.subst ([] ++ [et]) [])) := by
      simpa [hp, Ty.subst, Ty.substAt, Ty.shift_zero] using
        (HasTypeVs.cons (P := desugarProgram op p) (B := B) (Ψ := StoreTy.empty) (C := C)
          (Γ := some et :: some (.data cdo.data [t, et]) :: Γ)
          (.V_Var rfl (clean_notCont het)) HasTypeVs.nil)
    simpa [hr, hε, Ty.subst, Ty.substAt, Eff.substRho_empty] using
      (HasTypeC.C_Meth (R := R) hv (classDecl_desugared hcl) hms
        (by simp [hn, hp, NamesWF]) (by simp [SatAll, htp]) (by simp [hneff]) hargs)
  rw [desugar_tryResultDie]
  apply HasTypeC.C_Let (HasTypeC.weakenEff he (eff_left _ _))
  apply HasTypeC.C_Match (.V_Var rfl (clean_notCont hc))
  · refine HasTypeArms.mkArm_cons hpok
      (HasTypeC.weakenEff (HasTypeC.C_Return (.V_Var rfl (clean_notCont ht))) (Eff.empty_sub _))
      (HasTypeArms.mkArm_cons hperr ?_ (.nil hw))
    have hmsg : ∀ m, (message.map (desugarExpr op .other)) = some m →
        HasTypeC (desugarProgram op p) B StoreTy.empty C (hideConts Γ) none m (.base .string) Eff.empty := by
      intro m h
      obtain ⟨msg, hmsg, rfl⟩ := Option.map_eq_some_iff.mp h
      exact hm msg hmsg
    have hf := dieFailure_typed [some et, some (.data cdo.data [t, et])] hx hshow hmsg
    apply HasTypeC.weakenEff (δ := Eff.union ε (Eff.single "Process.Exit")) _ (eff_right _ _)
    cases message <;> exact hf
  · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
      Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex

/-- Option の die には辞書が不要であり、None の原因は純粋な固定文字列である。 -/
theorem tryOptionDie_typed {C Γ R pos cs cn cds cdn e t ε exit message}
    (hcs : p.cons cs = some cds) (hcn : p.cons cn = some cdn)
    (hns : cds.ntys = 1) (hnn : cdn.ntys = 1)
    (has : cds.args = [.tvar 0]) (han : cdn.args = []) (hdata : cds.data = cdn.data)
    (he : HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
      (desugarExpr op .other e) (.data cds.data [t]) ε)
    (hc : TyOK C.length (.data cds.data [t]))
    (hex : Exhaustive p.declarations.patternProgram (.data cds.data [t]) [.con cs [.var], .con cn []])
    (hx : DieExitOk B C exit t)
    (hm : ∀ m, message = some m → HasTypeC (desugarProgram op p) B StoreTy.empty C (hideConts Γ) none
      (desugarExpr op .other m) (.base .string) Eff.empty) :
    HasTypeC (desugarProgram op p) B StoreTy.empty C Γ R
      (desugarExpr op pos (.tryOptionDie t cs cn exit e message)) t (Eff.union ε (Eff.single "Process.Exit")) := by
  have ht := hc.1
  have hw := Ty.VarsIn.wf _ ht
  have hps : PatTy (desugarProgram op p) (.con cs [.var]) (.data cds.data [t]) [t] := by
    apply PatTy.P_Con hcs (by simp [hns])
    simpa [has, Ty.subst, Ty.substAt, Ty.shift_zero] using
      (PatTys.cons (P := desugarProgram op p) (PatTy.P_Var (a := t)) PatTys.nil)
  have hpn : PatTy (desugarProgram op p) (.con cn []) (.data cds.data [t]) [] := by
    rw [hdata]
    apply PatTy.P_Con hcn (by simp [hnn])
    simpa [han] using (PatTys.nil (P := desugarProgram op p))
  rw [desugar_tryOptionDie]
  apply HasTypeC.C_Let (HasTypeC.weakenEff he (eff_left _ _))
  apply HasTypeC.C_Match (.V_Var rfl (clean_notCont hc))
  · refine HasTypeArms.mkArm_cons hps
      (HasTypeC.weakenEff (HasTypeC.C_Return (.V_Var rfl (clean_notCont ht))) (Eff.empty_sub _))
      (HasTypeArms.mkArm_cons hpn ?_ (.nil hw))
    have hmsg : ∀ m, (message.map (desugarExpr op .other)) = some m →
        HasTypeC (desugarProgram op p) B StoreTy.empty C (hideConts Γ) none m (.base .string) Eff.empty := by
      intro m h
      obtain ⟨msg, hmsg, rfl⟩ := Option.map_eq_some_iff.mp h
      exact hm msg hmsg
    have hf := dieFailure_typed (R := R) [some (.data cds.data [t])] hx
      (HasTypeC.C_Return (HasTypeV.V_Const (c := .string "expected a value, got Option.None"))) hmsg
    apply HasTypeC.weakenEff (δ := Eff.union ε (Eff.single "Process.Exit")) _ (eff_right _ _)
    cases message <;> exact hf
  · simpa only [unguardedPats_mkArm_cons, unguardedPats] using
      Exhaustive.consCongr (Q := desugarProgram op p) (P := p.declarations.patternProgram) rfl hex

end Benitoite.Surface
