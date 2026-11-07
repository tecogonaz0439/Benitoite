import Benitoite.Release.Refinement.Surface.Rules
import Benitoite.Release.Refinement.Surface.OpenSurface

/-! # 欄の判定に残す元の取り出しの型付け

内部の判定の型付けが、検査用に保持した元の式の型付けも持つことを示す。
型や効果の拡大を重ねても、元の式の検査を省くことはできない。
-/
namespace Benitoite.Release.Refinement.Surface

set_option maxHeartbeats 400000 in
private theorem project_source_of_eq {D B op Q Δ C Γ Φ R p e a η}
    (h : HasTypeQ D B op Q Δ C Γ Φ R p e a η) {name ts es xs root source b ε}
    (he : e = .partialCall (.primName name ts es xs) []
      (.expr none 0 root (.expr none 1 source .nil)) b ε) :
    ∃ input, HasTypeQ D B op Q Δ C Γ Φ R .other source input Eff.empty := by
  match h with
  | .E_BuilderOp .. => cases he
  | .E_Local .. => cases he
  | .E_Const .. => cases he
  | .E_Fun .. => cases he
  | .E_FunDicts .. => cases he
  | .E_MethName .. => cases he
  | .E_Prim .. => cases he
  | .E_Raise .. => cases he
  | .E_HandleFail .. => cases he
  | .E_Op .. => cases he
  | .E_OpDicts .. => cases he
  | .E_ExternalName .. => cases he
  | .E_NullCon .. => cases he
  | .E_ConValue .. => cases he
  | .E_Refine _ hv _ _ _ _ _ _ _ => cases he; cases hv
  | .E_Literal .. => cases he
  | .E_NegInt .. => cases he
  | .E_NegFloat .. => cases he
  | .E_NegDecimal .. => cases he
  | .E_NegInteger8 .. => cases he
  | .E_NegInteger16 .. => cases he
  | .E_NegInteger32 .. => cases he
  | .E_NegFloat32 .. => cases he
  | .E_Unit .. => cases he
  | .E_Block .. => cases he
  | .E_Paren .. => cases he
  | .E_Record .. => cases he
  | .E_RecordUpdate .. => cases he
  | .E_RecordRefined .. => cases he
  | .E_RecordUpdateRefined .. => cases he
  | .E_ConCall .. => cases he
  | .E_CallDirect .. => cases he
  | .E_PredicateCall .. => cases he
  | .E_PredicateProject _ _ hs _ _ _ _ => cases he; exact ⟨_, hs⟩
  | .E_CallExternal .. => cases he
  | .E_Call .. => cases he
  | .E_PipeConCall .. => cases he
  | .E_PipeConValue .. => cases he
  | .E_PipeCallDirect .. => cases he
  | .E_PipeCall .. => cases he
  | .E_PipeApplyDirect .. => cases he
  | .E_PipeApply .. => cases he
  | .E_PartialCallDirect hn _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCall _ hn _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCallDirectDep hn _ _ _ _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCallDep _ hn _ _ _ _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCon .. => cases he
  | .E_Binary .. => cases he
  | .E_Neg .. => cases he
  | .E_Not .. => cases he
  | .E_And .. => cases he
  | .E_Or .. => cases he
  | .E_List .. => cases he
  | .E_ListRefined .. => cases he
  | .E_ListSpread .. => cases he
  | .E_Interpolation .. => cases he
  | .E_Lam .. => cases he
  | .E_If .. => cases he
  | .E_ElseIf .. => cases he
  | .E_IfOnly .. => cases he
  | .E_Match .. => cases he
  | .E_ReturnTail .. => cases he
  | .E_ReturnOther .. => cases he
  | .E_TryResult .. => cases he
  | .E_TryOption .. => cases he
  | .E_TryResultDie .. => cases he
  | .E_TryResultDieMessage .. => cases he
  | .E_TryOptionDie .. => cases he
  | .E_TryOptionDieMessage .. => cases he
  | .E_With .. => cases he
  | .E_Lazy .. => cases he
  | .E_Handle .. => cases he
  | .E_Resume .. => cases he
  | .E_Sub child _ _ _ => exact project_source_of_eq child he
termination_by structural h

/-- 欄の判定を受け入れた導出から、同じ文脈の元の取り出しの純粋な型付けを得る。 -/
theorem HasTypeQ.predicateProject_source {D B op Q Δ C Γ Φ R p name ts es xs root source b ε a η}
    (h : HasTypeQ D B op Q Δ C Γ Φ R p
      (.partialCall (.primName name ts es xs) [] (.expr none 0 root (.expr none 1 source .nil)) b ε) a η) :
    ∃ input, HasTypeQ D B op Q Δ C Γ Φ R .other source input Eff.empty :=
  project_source_of_eq h rfl

namespace OpenSurface

set_option maxHeartbeats 400000 in
private theorem open_project_source_of_eq {D B ks op Q Δ C Γ Φ R p e a η}
    (h : HasTypeQ D B ks op Q Δ C Γ Φ R p e a η) {name ts es xs root source b ε}
    (he : e = .partialCall (.primName name ts es xs) []
      (.expr none 0 root (.expr none 1 source .nil)) b ε) :
    ∃ input, HasTypeQ D B ks op Q Δ C Γ Φ R .other source input Eff.empty := by
  match h with
  | .E_BuilderOp .. => cases he
  | .E_Local .. => cases he
  | .E_Const .. => cases he
  | .E_Fun .. => cases he
  | .E_FunDicts .. => cases he
  | .E_MethName .. => cases he
  | .E_Prim .. => cases he
  | .E_Raise .. => cases he
  | .E_HandleFail .. => cases he
  | .E_Op .. => cases he
  | .E_OpDicts .. => cases he
  | .E_ExternalName .. => cases he
  | .E_NullCon .. => cases he
  | .E_ConValue .. => cases he
  | .E_Refine _ hv _ _ _ _ _ _ _ => cases he; cases hv
  | .E_Literal .. => cases he
  | .E_NegInt .. => cases he
  | .E_NegFloat .. => cases he
  | .E_NegDecimal .. => cases he
  | .E_NegInteger8 .. => cases he
  | .E_NegInteger16 .. => cases he
  | .E_NegInteger32 .. => cases he
  | .E_NegFloat32 .. => cases he
  | .E_Unit .. => cases he
  | .E_Block .. => cases he
  | .E_Paren .. => cases he
  | .E_Record .. => cases he
  | .E_RecordUpdate .. => cases he
  | .E_RecordRefined .. => cases he
  | .E_RecordUpdateRefined .. => cases he
  | .E_ConCall .. => cases he
  | .E_CallDirect .. => cases he
  | .E_PredicateCall .. => cases he
  | .E_PredicateProject _ _ hs _ _ _ _ => cases he; exact ⟨_, hs⟩
  | .E_CallExternal .. => cases he
  | .E_Call .. => cases he
  | .E_PipeConCall .. => cases he
  | .E_PipeConValue .. => cases he
  | .E_PipeCallDirect .. => cases he
  | .E_PipeCall .. => cases he
  | .E_PipeApplyDirect .. => cases he
  | .E_PipeApply .. => cases he
  | .E_PartialCallDirect hn _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCall _ hn _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCallDirectDep hn _ _ _ _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCallDep _ hn _ _ _ _ _ _ _ _ _ _ _ => cases he; exact False.elim (hn rfl)
  | .E_PartialCon .. => cases he
  | .E_Binary .. => cases he
  | .E_Neg .. => cases he
  | .E_Not .. => cases he
  | .E_And .. => cases he
  | .E_Or .. => cases he
  | .E_List .. => cases he
  | .E_ListRefined .. => cases he
  | .E_ListSpread .. => cases he
  | .E_Interpolation .. => cases he
  | .E_Lam .. => cases he
  | .E_If .. => cases he
  | .E_ElseIf .. => cases he
  | .E_IfOnly .. => cases he
  | .E_Match .. => cases he
  | .E_ReturnTail .. => cases he
  | .E_ReturnOther .. => cases he
  | .E_TryResult .. => cases he
  | .E_TryOption .. => cases he
  | .E_TryResultDie .. => cases he
  | .E_TryResultDieMessage .. => cases he
  | .E_TryOptionDie .. => cases he
  | .E_TryOptionDieMessage .. => cases he
  | .E_With .. => cases he
  | .E_Lazy .. => cases he
  | .E_Handle .. => cases he
  | .E_Resume .. => cases he
  | .E_Sub child _ _ _ => exact open_project_source_of_eq child he
termination_by structural h

/-- 開いた範囲文脈でも、元の取り出しの型付けを同じ文脈で保持する。 -/
theorem HasTypeQ.predicateProject_source {D B ks op Q Δ C Γ Φ R p name ts es xs root source b ε a η}
    (h : HasTypeQ D B ks op Q Δ C Γ Φ R p
      (.partialCall (.primName name ts es xs) [] (.expr none 0 root (.expr none 1 source .nil)) b ε) a η) :
    ∃ input, HasTypeQ D B ks op Q Δ C Γ Φ R .other source input Eff.empty :=
  open_project_source_of_eq h rfl

end OpenSurface
end Benitoite.Release.Refinement.Surface
