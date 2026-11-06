import Benitoite.Release.Refinement.Surface.CheckOpenExamples

/-! # 標準の組込みへの開いた範囲の転送の検査 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpenStandardExamples
open Check RangeFunctionExamples

private noncomputable def input : Check.Input :=
  { CheckOpenExamples.input .endpoint with
    builtinSource := .standard (declarations .endpoint).core
    satDec := fun _ _ _ => false
    admitsDec := fun b _ ts => decide (b = "Http.widenRequestIn" ∧ ts = [])
    admitsRDec := fun _ _ => false }

attribute [local cbv_opaque] StandardModel.builtins
attribute [local cbv_eval] endpoint_lookup

/-- 標準表の endpoint の拡張へ、同じ開いた範囲を両位置で渡す。 -/
theorem endpoint_forward : CheckDeclarations.checkDef input [] endpointDef = .ok () := by
  cbv

end Benitoite.Release.Refinement.Surface.CheckOpenStandardExamples
