import Benitoite.Release.Refinement.Surface.PredicateSimulationPureProviders

/-! # 標準表の公開判定を、その固定APIへ対応させる -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

def public_row : PredicateResponse.API → StandardModel.Primitive
  | .path => .p378
  | .host => .p379
  | .characters => .p380
  | .floating .binary64 .finite => .p381
  | .floating .binary64 .infinite => .p382
  | .floating .binary64 .positiveInfinity => .p383
  | .floating .binary64 .negativeInfinity => .p384
  | .floating .binary64 .positiveZero => .p385
  | .floating .binary64 .negativeZero => .p386
  | .floating .binary32 .finite => .p387
  | .floating .binary32 .infinite => .p177
  | .floating .binary32 .positiveInfinity => .p388
  | .floating .binary32 .negativeInfinity => .p389
  | .floating .binary32 .positiveZero => .p390
  | .floating .binary32 .negativeZero => .p391

theorem public_row_name (api : PredicateResponse.API) : (public_row api).name = api.name := by
  cases api <;> try (rename_i width test; cases width <;> cases test)
  all_goals rfl

theorem public_row_signature (api : PredicateResponse.API) (sat) :
    (public_row api).signatureWith sat = api.signature := by
  cases api <;> try (rename_i width test; cases width <;> cases test)
  all_goals rfl

/-- 標準表の実lookupは、公開APIのBoolean署名をそのまま持つ。 -/
theorem public_signature {B} [StandardModel.RowLookup B] (api : PredicateResponse.API) :
    B.sig api.name = some api.signature := by
  simpa only [public_row_name,public_row_signature] using StandardModel.RowLookup.sig (B := B) (public_row api)

private theorem public_row_no_keys (api : PredicateResponse.API) : (public_row api).readsKeys = false := by
  cases api <;> try (rename_i width test; cases width <;> cases test)
  all_goals rfl

/-- 対応先の各引数の型付けから、元の標準表の公開δを固定APIのδへ対応させる。 -/
theorem public_delta_values {P Bsource Btarget Ψ values} [StandardModel.RowLookup Bsource]
    (api : PredicateResponse.API)
    (valuesTyped : HasTypeVsQ P Btarget Ψ Qempty [] [] [] values api.inputs) :
    Bsource.delta api.name [] [] [] values = api.delta api.name [] [] [] values := by
  have fixed := StandardModel.RowLookup.delta (B := Bsource) (public_row api) (public_row_no_keys api)
  rw [public_row_name] at fixed
  rw [fixed]
  cases api with
  | path | host | characters => rfl
  | floating width test =>
    cases width <;> cases test <;> try rfl
    cases valuesTyped with | cons value rest =>
      cases rest
      obtain ⟨c,rfl,_,tag⟩ := value.canonical_scalar rfl
      cases c <;> cases tag
      rename_i bits constOk
      have bytePrefix : "Float32.isInfinite".startsWith "Byte." = false := by decide +kernel
      have characterPrefix : "Float32.isInfinite".startsWith "Character." = false := by decide +kernel
      have floatPrefix : "Float32.isInfinite".startsWith "Float32." = true := by decide +kernel
      change (StandardScalarResponse.table StandardModel.signatureBase).delta "Float32.isInfinite" [] [] []
        [.const (.float32 bits)] = StandardScalar.float32Delta "Float32.isInfinite" [] [] [] [.const (.float32 bits)]
      simp only [StandardScalarResponse.table,bytePrefix,characterPrefix,floatPrefix,Bool.false_eq_true,ite_false,ite_true]

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
