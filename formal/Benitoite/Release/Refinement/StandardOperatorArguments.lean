import Benitoite.Release.Refinement.StandardFloatMathResponse
import Benitoite.Release.Refinement.StandardIntegerFailure
import Benitoite.Release.Refinement.CoefficientModel

/-! # 単相の演算子の原署名と全引数 -/
namespace Benitoite.Release.Refinement.StandardOperatorArguments

/-- 単項の value、二項の left/right を持つ演算子の原署名。 -/
def signature (input output : BaseTy) (unary : Bool) : PrimSig :=
  ⟨[],0,if unary then ["value"] else ["left","right"],
    if unary then [.base input] else [.base input,.base input],.base output,Eff.empty,
    (fun _ ts => ts=[]),.pure,none,[],.untargeted⟩

private theorem instantiated (input output : BaseTy) (unary : Bool) :
    instantiatedTel (Tel.instR [] (signature input output unary).tel) [] [] =
      Ty.toTel (if unary then ["value"] else ["left","right"])
        (if unary then [.base input] else [.base input,.base input]) (.base output) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases unary <;> simp [signature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    emptyRange,Ty.toTel,Ty.shiftV,Eff.shiftV]

/-- 型・行・範囲引数を増やさず、元の全BuiltinArgsから実値の導出を取り出す。 -/
theorem arguments {P B Ψ name ts es rs ws a e} (input output : BaseTy) (unary : Bool)
    (args : BuiltinArgs P B Ψ name (signature input output unary) ts es rs ws a e) :
    ts=[] ∧ es=[] ∧ rs=[] ∧ a=.base output ∧ e=Eff.empty ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws
        (if unary then [.base input] else [.base input,.base input]) := by
  have ts0 : ts=[] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es=[] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs=[] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have h := args.arguments
  rw [instantiated] at h
  obtain ⟨values,ar,ee⟩ := h.toTelValues (by cases unary <;> simp [NamesWF])
  refine ⟨rfl,rfl,rfl,args.result.2.symm.trans ar,args.effect.2.symm.trans ee,?_⟩
  cases unary <;> exact values

end Benitoite.Release.Refinement.StandardOperatorArguments
