import Benitoite.Release.Refinement.Surface.PredicateSimulationActiveProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationABI

/-! # IO事象に記録する型付き実引数の同一性 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

local macro "scopedInputsImpl" : term =>
  pure (Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.ScopedIOResponse
    `Benitoite.Release.Refinement.ScopedIOResponse.inputs))

/-- 保持対象の型付きの値は、保持した要求もground検査を通るため対応元と同じ値である。 -/
theorem held_input_equal {P B Ψ Q source rows x y a name kind range}
    (typed : HasTypeVQ P B Ψ Q [] [] [] y a) (held : a.Holds name kind range)
    (related : Value source rows x y) : x = y := by
  rcases typed.canonical_held held with ⟨owner,payload,rfl⟩ | ⟨target,rfl⟩ |
    ⟨target,request,rfl⟩ | ⟨r,snapshot,target,request,rfl⟩
  · exact related.constant_right
  · cases related; rfl
  · obtain ⟨_,_,_,_,_,_,_,ground,_,_,_,_⟩ := typed.inv_checkedRequest rfl
    cases related with
    | checkedRequest child => rw [child.eq_of_ground_right ground]
  · obtain ⟨_,_,_,witness,_,_⟩ := typed.inv_checkedAt rfl
    cases witness with
    | plain _ _ _ _ => cases related with
      | checkedAt request => cases request; rfl
    | request _ _ _ ground _ _ => cases related with
      | checkedAt request => cases request with
        | some child => rw [child.eq_of_ground_right ground]

private theorem scoped_values_equal {P B Ψ source rows xs ys range}
    (operation : ScopedIOResponse.Operation)
    (typed : HasTypeVsQ P B Ψ Qempty [] [] [] ys (operation.params range))
    (related : Values source rows xs ys) : xs = ys := by
  cases operation <;> cases typed with
  | cons first rest =>
    cases related with
    | cons head tail =>
      have same := held_input_equal (kind := .path) first (Or.inr rfl) head
      rw [same]
      first
      | cases rest; cases tail; rfl
      | cases rest with
        | cons second rest =>
          cases rest
          cases tail with
          | cons element tail =>
            cases tail
            first
            | rw [constant_input_equal (.base .string) second element]
            | rw [constant_input_equal .bytes second element]

/-- 範囲付き標準IOの対応先の実署名は、生の実引数列の等号を与える。 -/
theorem scoped_io_inputs_equal {P B Ψ source rows xs ys ts es rs a e}
    (operation : ScopedIOResponse.Operation)
    (typed : BuiltinArgs P B Ψ operation.name operation.signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  obtain ⟨_,_,range,_,values,_⟩ := scopedInputsImpl operation typed
  exact scoped_values_equal operation values related

private theorem legacy_io_inputs_equal {P B Ψ source rows name signature xs ys ts es rs a e}
    (legacy : (name = "print" ∧ signature = ModelTargets.printSig) ∨
      (name = "exit" ∧ signature = ModelTargets.exitSig) ∨
      (name = "File.readText" ∧ signature = ModelTargets.readTextSig))
    (typed : BuiltinArgs P B Ψ name signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  have form : signature = ModelTargets.printSig ∨ signature = ModelTargets.exitSig ∨ signature = ModelTargets.readTextSig := by
    rcases legacy with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩
    · exact Or.inl rfl
    · exact Or.inr (Or.inl rfl)
    · exact Or.inr (Or.inr rfl)
  have typeCount : signature.tparams = [] := by rcases form with rfl | rfl | rfl <;> rfl
  have effectCount : signature.neffs = 0 := by rcases form with rfl | rfl | rfl <;> rfl
  have rangeCount : signature.rkinds = [] := by rcases form with rfl | rfl | rfl <;> rfl
  have types : ts = [] := List.length_eq_zero_iff.mp (typed.admissible.typeCount.trans (by rw [typeCount]; rfl))
  have effects : es = [] := List.length_eq_zero_iff.mp (typed.admissible.rowCount.trans effectCount)
  have ranges : rs = [] := List.length_eq_zero_iff.mp (typed.ranges.1.trans (by rw [rangeCount]; rfl))
  subst ts; subst es; subst rs
  have instantiated : instantiatedTel (Tel.instR [] signature.tel) [] [] =
      Ty.toTel signature.names signature.params signature.ret signature.eff := by
    rcases form with rfl | rfl | rfl
    all_goals simp [ModelTargets.printSig,ModelTargets.exitSig,ModelTargets.readTextSig,ScopeSignatures.unscopedIO,
      PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
      Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.single,typeEnvAt,SubstEnv.up,
      substAtoms_nil,instAtoms_nil,rowFails,RangeIx.inst]
  have names : NamesWF signature.names signature.params := by
    rcases form with rfl | rfl | rfl <;>
      simp [ModelTargets.printSig,ModelTargets.exitSig,ModelTargets.readTextSig,ScopeSignatures.unscopedIO,NamesWF]
  have normal : Ty.normTys signature.params = signature.params := by rcases form with rfl | rfl | rfl <;> rfl
  have shapes : ∀ input ∈ signature.params, ConstantInputType input := by
    rcases form with rfl | rfl | rfl <;>
      simp [ModelTargets.printSig,ModelTargets.exitSig,ModelTargets.readTextSig,ScopeSignatures.unscopedIO,ConstantInputType.base]
  have arguments := typed.arguments
  rw [instantiated] at arguments
  exact constant_values_equal (normal ▸ (arguments.toTelValues names).1) shapes related

/-- 固定台帳のIO又はexitの署名は、対応先だけの型付けから同じ実引数列を与える。 -/
theorem fixed_io_inputs_equal {P B Ψ source rows xs ys ts es rs a e}
    (row : StandardModel.Primitive)
    (kind : (row.signatureWith B.sat).kind = .io ∨ (row.signatureWith B.sat).kind = .exit)
    (typed : BuiltinArgs P B Ψ row.name (row.signatureWith B.sat) ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  cases row
  case p157 => exact scoped_io_inputs_equal .appendBytes typed related
  case p158 => exact scoped_io_inputs_equal .appendText typed related
  case p159 => exact scoped_io_inputs_equal .readBytes typed related
  case p160 => exact legacy_io_inputs_equal (Or.inr (Or.inr ⟨rfl,rfl⟩)) typed related
  case p161 => exact scoped_io_inputs_equal .readText typed related
  case p162 => exact scoped_io_inputs_equal .writeBytes typed related
  case p163 => exact scoped_io_inputs_equal .writeText typed related
  case p187 => exact scoped_io_inputs_equal .send typed related
  case p372 => exact legacy_io_inputs_equal (Or.inr (Or.inl ⟨rfl,rfl⟩)) typed related
  case p373 => exact legacy_io_inputs_equal (Or.inl ⟨rfl,rfl⟩) typed related
  all_goals rcases kind with kind | kind <;> cases kind

/-- 有効な構成元のIO事象へ記録される実引数は、対応先の型付けだけで同じ値列となる。 -/
theorem active_io_inputs_equal {P Ψ source rows xs ys ts es rs a e name signature}
    {config : Check.BuiltinSource} (active : CheckPreparation.enabled config = true)
    (found : config.builtins.sig name = some signature) (kind : signature.kind = .io ∨ signature.kind = .exit)
    (typed : BuiltinArgs P config.builtins Ψ name signature ts es rs ys a e)
    (related : Values source rows xs ys) : xs = ys := by
  rcases active_signature_cases active found with ⟨row,rfl,rfl⟩ | ⟨row,rfl,_delta⟩
  · exact fixed_io_inputs_equal row kind typed related
  · cases row <;> rcases kind with kind | kind <;> cases kind

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
