import Benitoite.Release.Refinement.LegacyValueCases
import Benitoite.Release.Refinement.LegacyPrimitiveCase
import Benitoite.Release.Refinement.LegacyOperationCase
import Benitoite.Release.Refinement.LegacyLambdaCase
import Benitoite.Release.Refinement.LegacyCollectionCases
import Benitoite.Release.Refinement.LegacyHeldCases
import Benitoite.Release.Refinement.LegacySubCases

namespace Benitoite.Release.Refinement
noncomputable section

theorem LegacyRule.embed_value {K P0 B0 B κ Ψ Q C Γ v a children}
    (rule : LegacyRule K P0 B0 (.value κ Ψ Q C Γ v a) children)
    (kinds : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a))
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a) := by
  cases rule with
  | V_Var lookup ordinary => exact LegacyValueCases.var_case lookup ordinary
  | V_Const => exact LegacyValueCases.const_case _ reg.2.1
  | V_Bytes => exact LegacyValueCases.bytes_case _ reg.2.1
  | V_Fun lookup names admissible => exact LegacyValueCases.fun_case kinds tables reg lookup names admissible
  | V_Prim lookup range names admissible => exact LegacyValueCases.prim_case tables reg lookup range names admissible
  | V_Op lookup names sat => exact LegacyValueCases.op_case tables reg lookup names sat
  | V_Lam names _ => exact LegacyValueCases.lam_case reg names (ih _ (by simp))
  | V_Con lookup arity => exact LegacyValueCases.con_case tables reg lookup arity (ih _ (by simp))
  | V_List _ => exact LegacyValueCases.list_case reg (ih _ (by simp))
  | V_Map count key _ _ => exact LegacyValueCases.map_case tables reg count key (ih _ (by simp)) (ih _ (by simp))
  | V_Set key _ => exact LegacyValueCases.set_case tables reg key (ih _ (by simp))
  | V_Dict lookup sat => exact LegacyValueCases.dict_case tables reg lookup sat (ih _ (by simp))
  | V_LocRef lookup => exact LegacyValueCases.locRef_case reg lookup
  | V_LocLazy lookup => exact LegacyValueCases.locLazy_case reg lookup
  | V_Checked _ _ => exact LegacyValueCases.checked_case reg
  | V_CheckedRequest _ _ content => exact LegacyValueCases.checkedRequest_case reg content (ih _ (by simp))
  | V_Raise _ _ => exact LegacyValueCases.raise_case reg
  | V_Super lookup member => exact LegacyValueCases.super_case reg lookup member (ih _ (by simp))
  | V_Sub sub _ => exact LegacyValueCases.sub_case reg sub (ih _ (by simp))

def LegacyJudgment.ConstantEmbedded (K : DeclarationKinds) (P0 : Benitoite.Release.Program) (B : Builtins) :
    LegacyJudgment → Prop
  | .value κ Ψ Q C Γ (.const c) a => LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ (.const c) a)
  | _ => True

theorem LegacyOutputInput.embed_constants {K P0 B0 B j}
    (input : LegacyOutputInput K P0 B0 B j) :
    j.ConstantEmbedded K P0 B := by
  apply input.induct_regular (M := fun j => j.ConstantEmbedded K P0 B)
  intro j children rule reg _ ih
  cases rule <;> try trivial
  case V_Const => exact LegacyValueCases.const_case _ reg.2.1
  case V_Sub κ Ψ Q C Γ v a b sub _ _ =>
    cases v <;> try trivial
    rename_i c inputs
    exact LegacyValueCases.sub_case reg sub (ih (.value κ Ψ Q C Γ (.const c) a) (List.mem_cons_self))

end
end Benitoite.Release.Refinement
