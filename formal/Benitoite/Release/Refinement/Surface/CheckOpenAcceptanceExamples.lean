import Benitoite.Release.Refinement.Surface.CheckOpenExamples

/-! # 開いた関数の実入口の成功から得る型付け -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenAcceptanceExamples
open Check CheckOpenExamples RangeFunctionExamples

private theorem signature_support (k : Scope.Domain.Kind) :
    CheckArguments.SignatureSupport [] (inspectDecl k).coreParams (inspectDecl k).ret
      (inspectDecl k).eff (inspectDecl k).tel ∧
    CheckArguments.SignatureSupport [] (inspectSig k).params (inspectSig k).ret
      (inspectSig k).eff (inspectSig k).tel := by
  simp [CheckArguments.SignatureSupport, inspectDecl, inspectSig, ScopeSignatures.pureIn,
    FunDecl.coreParams, FunDecl.coreNames, internalNames, FunDecl.dictTys, FunDecl.tel, PrimSig.tel, signatureTel,
    targetTy, Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty]

private theorem input_sound (k : Scope.Domain.Kind) : (input k).Sound := by
  refine ⟨⟨?_, ?_⟩, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro c cd h; cases h
  · intro c cd h; cases h
  · intro i d h; cases h
  · intro f d h
    change (if f = "inspect" then some (inspectDecl k) else none) = some d at h
    split at h
    · cases h; exact (signature_support k).1
    · cases h
  · intro b s h
    change (if b = "Example.inspect" then some (inspectSig k) else none) = some s at h
    split at h
    · cases h; exact (signature_support k).2
    · cases h
  · intro o d h; cases h
  · intro c cd m ms h; cases h
  · intro f d h; cases h
  · intro C a p h; trivial
  · intro b s C ts hlookup hcheck
    change (if b = "Example.inspect" then some (inspectSig k) else none) = some s at hlookup
    split at hlookup
    · cases hlookup
      change ts = []
      have hnil : decide (ts = []) = true := by simpa only [input] using hcheck
      exact of_decide_eq_true hnil
    · cases hlookup
  · intro b rs h; trivial
  · intro o t b ts h; cases h

private theorem forward_support (k : Scope.Domain.Kind) :
    CheckDeclarations.DefSupport (input k) (forwardDef k) := by
  refine ⟨(signature_support k).1.2.2.2, ?_⟩
  change CheckArguments.HeadInputsSupport (input k).formation (input k).B
    (.funName "inspect" [] [] [.rvar 0]) ∧ True ∧ True
  exact ⟨⟨trivial, by simp, fun rs h => by cases h⟩, trivial, trivial⟩

private def closedFunction : FunDecl where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty

private def closedInput : Check.Input :=
  { input .path with
    D := { funs := fun f => if f = "Example.unit" then some closedFunction else none
           cons := fun _ => none } }

/-- 空の範囲列では、元の関数の支持と注釈の検査から実入口の受理を得る。 -/
theorem closed_function_and_annotation :
    Check.ExprSupport closedInput (.funName "Example.unit" [] [] []) ∧
    (Check.checkExpr closedInput [] [] [] none .other []
      (.call (.funName "Example.unit" [] [] []) [] [] .nil)).toBool = true ∧
    CheckOpenFormation.annotation closedInput.formation [] closedInput.D.core [] [] [] (.base .unit) = true := by
  refine ⟨CheckArguments.function_empty_support trivial (by simp), ?_, ?_⟩
  · cbv
  · rw [CheckOpenFormation.annotation_nil]
    rfl

/-- 開いた範囲を別の関数へ渡す定義の受理から、同じ表の型付けを得る。 -/
theorem function_forward_wellTyped :
    (forwardDef .path).WellTyped (input .path).D (input .path).B (input .path).opPrim := by
  apply CheckDeclarations.checkDef_sound (input_sound .path) (forward_support .path) ?_ function_forward
  intro _ c cd h
  cases h

end Benitoite.Release.Refinement.Surface.CheckOpenAcceptanceExamples
