import Benitoite.Release.Model

/-!
# 通常の match と handle による Result の変換

成功と失敗の四つの有限遷移を示し、捕捉後には drop が used セルを残す。
専用の変換規則は使わない（設計書 01-12「実行の規則」）。
-/

namespace Benitoite.Release.FailureExamples

open Benitoite.Release

def okDecl : ConDecl := ⟨"L2Result", 2, [.tvar 0]⟩
def errorDecl : ConDecl := ⟨"L2Result", 2, [.tvar 1]⟩

def program : Program := { Model.emptyProgram with
  cons := fun c => if c = "L2Result.Ok" then some okDecl
    else if c = "L2Result.Error" then some errorDecl else none }

def resultTy (T E : Ty) : Ty := .data "L2Result" [T, E]
def okValue (T E : Ty) (v : Val) : Val := .con "L2Result.Ok" [T, E] [v]
def errorValue (T E : Ty) (v : Val) : Val := .con "L2Result.Error" [T, E] [v]

def fromResultBody (T E : Ty) (v : Val) : Comp :=
  .match v
    [.mk [.mk (.con "L2Result.Ok" [.var]) [0]] none (.ret (.var 0)),
     .mk [.mk (.con "L2Result.Error" [.var]) [0]] none
       (.app (.raise T E) [.var 0])]

noncomputable def toResultBody (T E : Ty) (body : Comp) : Comp :=
  .handle (.letIn body (.ret (okValue T E (.var 0))))
    [.fail E (.ret (errorValue (T.shift 1 0) (E.shift 1 0) (.var 1)))]

theorem fromResult_ok (P : Program) (B : Builtins) (T E : Ty) (v : Val) :
    Steps P B (.run (fromResultBody T E (okValue T E v)) [] Store.empty)
      (.run (.ret v) [] Store.empty) := by
  refine .step .E_Match (.step (.E_MatchBody (next := 0) (ws := [v]) rfl ?_) ?_)
  · rfl
  · exact .refl

theorem fromResult_error (P : Program) (B : Builtins) (T E : Ty) (v : Val) :
    Steps P B (.run (fromResultBody T E (errorValue T E v)) [] Store.empty)
      (.run (.app (.raise T E) [v]) [] Store.empty) := by
  refine .step .E_Match (.step (.E_MatchSkip (next := 0) rfl rfl)
    (.step (.E_MatchBody (next := 1) (ws := [v]) rfl ?_) ?_))
  · rfl
  · exact .refl

theorem toResult_return (P : Program) (B : Builtins) (T E : Ty) (v : Val) :
    Steps P B (.run (toResultBody T E (.ret v)) [] Store.empty)
      (.run (.ret (okValue T E v)) [] Store.empty) := by
  exact .step .E_Handle (.step .E_Let (.step .E_Return (.step .E_HRet .refl)))

theorem toResult_raise (P : Program) (B : Builtins) (T E : Ty) (v : Val)
    (hc : ClosedArgs [T, E]) :
    Steps P B (.run (toResultBody T E (.app (.raise T E) [v])) [] Store.empty)
      (.run (.ret (errorValue T E v)) [] (Store.empty.set 0 .used)) := by
  have ht := (hc T (by simp)).1
  have he := (hc E (by simp)).1
  unfold toResultBody
  rw [Ty.shift_of_wf (c := 0) 1 T ht, Ty.shift_of_wf (c := 0) 1 E he]
  refine .step .E_Handle (.step .E_Let (.step (.E_OpFail (κ := 0) (k1 := [.letF (.ret (okValue T E (.var 0)))])
    (E := E) (body := .ret (errorValue T E (.var 1))) (k2 := []) ?_ rfl) ?_))
  · exact ⟨rfl, rfl, by intro h hh; simp at hh⟩
  · have htθ := Ty.substAt_nil_of_wf (c := 0) [T] T ht
    have heθ := Ty.substAt_nil_of_wf (c := 0) [T] E he
    have hbody : ((Comp.ret (errorValue T E (.var 1))).substTy [T] []).instantiate [v, .loc 0] =
        .ret (errorValue T E v) := by
      simp [errorValue, Comp.substTy, Comp.substTyAt, Val.substTyAt, Val.substTyAtList, htθ, heθ,
        Comp.instantiate, Comp.subst, Val.subst, Val.substList, instSubst]
    rw [hbody]
    refine .step (.E_DropRel (k' := [.letF (.ret (okValue T E (.var 0))),
      .handleF [.fail E (.ret (errorValue T E (.var 1)))]]) rfl) ?_
    have heq : (Store.empty.set 0 (.cont
        [.letF (.ret (okValue T E (.var 0))), .handleF [.fail E (.ret (errorValue T E (.var 1)))]])).set 0 .used =
        Store.empty.set 0 .used := by
      funext l; by_cases hl : l = 0 <;> simp [Store.set, hl]
    simp only [List.cons_append, List.nil_append, releases]
    rw [heq]
    exact .refl

/-- Result の二構成子は同じ宣言を使い、成功値とエラー値を取り違えない。 -/
theorem result_values_typed {B Ψ C Γ T E v}
    (ht : Ty.WF 0 C.length T) (he : Ty.WF 0 C.length E) :
    (HasTypeV program B Ψ C Γ v T → HasTypeV program B Ψ C Γ (okValue T E v) (resultTy T E)) ∧
    (HasTypeV program B Ψ C Γ v E → HasTypeV program B Ψ C Γ (errorValue T E v) (resultTy T E)) := by
  constructor
  · intro hv
    apply HasTypeVQ.V_Con (cd := okDecl) (by simp [program]) rfl
    simpa [okDecl, Ty.subst, Ty.substAt, Ty.shift_zero 0 T (ht.canonical T)] using
      HasTypeVsQ.cons hv HasTypeVsQ.nil
  · intro hv
    apply HasTypeVQ.V_Con (cd := errorDecl) (by simp [program]) rfl
    simpa [errorDecl, Ty.subst, Ty.substAt, Ty.shift_zero 0 E (he.canonical E)] using
      HasTypeVsQ.cons hv HasTypeVsQ.nil

/-- 型付きの body の Fail を処理し、Result を返す通常の handle。 -/
theorem toResult_typed {B Ψ R T E body} (hc : ClosedArgs [T, E])
    (hb : HasTypeC program B Ψ [] [] R body T (Eff.singleFail E)) :
    HasTypeC program B Ψ [] [] R (toResultBody T E body) (resultTy T E) Eff.empty := by
  have ht := (hc T (by simp)).1
  have he := (hc E (by simp)).1
  have htc := (hc T (by simp)).2
  have hec := (hc E (by simp)).2
  have hout : Ty.WF 0 0 (resultTy T E) := ⟨ht, he, trivial⟩
  have hret : HasTypeC program B Ψ [] [some T] R (.ret (okValue T E (.var 0)))
      (resultTy T E) (Eff.singleFail E) :=
    .C_Eff (.C_Return ((result_values_typed (C := []) ht he).1 (.V_Var rfl htc))) (Eff.covers_empty _)
  have hbody := HasTypeCQ.C_Let hb hret
  have hcl : HasFailureClause program B Ψ Qempty [] [] E R
      [.fail E (.ret (errorValue (T.shift 1 0) (E.shift 1 0) (.var 1)))]
      (resultTy T E) Eff.empty := by
    refine .one he hout trivial ?_
    have htsh : T.shift 1 0 = T := Ty.shift_of_wf 1 T ht
    have hesh : E.shift 1 0 = E := Ty.shift_of_wf 1 E he
    have hv : HasTypeV program B Ψ [({} : TParam)] [none, some E]
        (.var 1) E := .V_Var rfl hec
    have hr := (result_values_typed (Ty.WF.mono (by simp) T ht) (Ty.WF.mono (by simp) E he)).2 hv
    simpa [shiftEnv, htsh, hesh, Ty.shift_of_wf 1 _ hout, Eff.shift, Eff.rawShift,
      Eff.empty, Eff.norm] using
      (HasTypeCQ.C_Return (R := R.map (Ty.shift 1 0)) (hideBuilders_strengthen_val hr))
  have hh := HasTypeCQ.C_Handle_Fail (Rest := Eff.empty) hbody
    (show Eff.Sub (Eff.singleFail E) (Eff.union (Eff.singleFail E) Eff.empty) from
      ⟨fun a ha => (Eff.mem_union _ _ _).mpr (Or.inl ha),
        fun t ht => (Eff.memFail_union _ _ _).mpr (Or.inl ht)⟩)
    (show NoFail Qempty Eff.empty from ⟨rfl, by intro i hi; cases hi⟩) hcl
  have heq : Eff.union Eff.empty Eff.empty = Eff.empty := rfl
  simpa only [toResultBody, heq] using hh

/-- 二構成子の宣言の両方を照合する fromResult の型付け。 -/
theorem fromResult_typed {B Ψ R T E v} (hc : ClosedArgs [T, E])
    (hv : HasTypeV program B Ψ [] [] v (resultTy T E)) :
    HasTypeC program B Ψ [] [] R (fromResultBody T E v) T (Eff.singleFail E) := by
  have ht := (hc T (by simp)).1
  have he := (hc E (by simp)).1
  have htc := (hc T (by simp)).2
  have hec := (hc E (by simp)).2
  have hpatOk : PatTy program (.con "L2Result.Ok" [.var]) (resultTy T E) [T] := by
    apply PatTy.P_Con (cd := okDecl) (by simp [program]) rfl
    simpa [okDecl, Ty.subst, Ty.substAt, Ty.shift_zero 0 T (ht.canonical T)] using
      PatTys.cons (PatTy.P_Var (a := T)) PatTys.nil
  have hpatError : PatTy program (.con "L2Result.Error" [.var]) (resultTy T E) [E] := by
    apply PatTy.P_Con (cd := errorDecl) (by simp [program]) rfl
    simpa [errorDecl, Ty.subst, Ty.substAt, Ty.shift_zero 0 E (he.canonical E)] using
      PatTys.cons (PatTy.P_Var (a := E)) PatTys.nil
  have alt {p x} (hp : PatTy program p (resultTy T E) [x]) (hn : p.binders = 1) :
      AltsTy program [⟨p, [0]⟩] (resultTy T E) [x] := by
    refine ⟨by simp, by simp [Arm.bindersOf, hn], ?_, ?_⟩
    · intro a ha; simp at ha; subst a; simp [hn]
    · intro a ha; simp at ha; subst a; exact ⟨[x], hp, .refl _, rfl⟩
  refine .C_Match hv
    (.plain (alt hpatOk rfl) (.C_Eff (.C_Return (.V_Var rfl htc)) (Eff.covers_empty _))
      (.plain (alt hpatError rfl) (.C_App (.V_Raise ht he) (.cons (.V_Var rfl hec) .nil))
        (.nil ht))) ?_
  intro w hw
  generalize hres : resultTy T E = a at hw
  cases hw <;> try { cases hres }
  case const c => cases c <;> cases hres
  case con c ts tys args cd hcon hlen hargs =>
      simp only [program] at hcon
      split at hcon
      · rename_i ho
        cases hcon
        cases hres
        cases hargs with
        | cons hx tail =>
            cases tail
            exact ⟨.con "L2Result.Ok" [.var], by simp [unguardedPats], by simp [Pat.matchVal, Pat.matchList, ho]⟩
      · split at hcon
        · rename_i he
          cases hcon
          cases hres
          cases hargs with
          | cons hx tail =>
              cases tail
              exact ⟨.con "L2Result.Error" [.var], by simp [unguardedPats], by simp [Pat.matchVal, Pat.matchList, he]⟩
        · cases hcon

end Benitoite.Release.FailureExamples
