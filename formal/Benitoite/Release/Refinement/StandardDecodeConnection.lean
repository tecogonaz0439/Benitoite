import Benitoite.Release.Refinement.StandardDecodeBodies
import Benitoite.Release.Refinement.FirstReturn

/-! # 通常decoderの実行と同じResultの追加検査 -/
namespace Benitoite.Release.Refinement.StandardDecode
noncomputable section

def decoderInputType : Ty := .data "Result" [.data "Raw" [],.data "ConversionError" []]
def decoderOutputType : Ty := .data "Result" [wholeType,.data "ConversionError" []]

/-- 通常decoderを一度実行し、その実Resultだけを既存の後処理本体へ渡す。
    後処理のDefの登録に依存しないcoreの接続である。 -/
def decodeThen (decoder : Comp) : Comp := .letIn decoder postprocessBody

theorem decodeThen_typed {Ψ decoder}
    (typed : HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] [] [] (some decoderOutputType)
      decoder decoderInputType Eff.empty []) :
    HasTypeCQ recordProgram recordBuiltins Ψ Qempty [] [] [] (some decoderOutputType)
      (decodeThen decoder) decoderOutputType Eff.empty [] := decode_let_typed typed

private theorem steps_trans {P B σ s t u es fs}
    (first : Steps P B σ s es t) (next : Steps P B σ t fs u) :
    Steps P B σ s (es++fs) u := by
  induction first with
  | nil => exact next
  | cons step rest ih => simpa [List.append_assoc] using Steps.cons step (ih next)

/-- 任意の通常decoderの同じ実Stepsとretを、同じlet枠のE_Returnへ接続する。
    事象列・更新後のストアを保持し、返却値を別のResultへ置き換えない。 -/
theorem decodeThen_normal {σ Ψ decoder events q μ μ' decoded} (k : Cont)
    (child : Steps recordProgram recordBuiltins σ
      (.run (.mk Capture.empty decoder) (.letF (.mk Capture.empty postprocessBody)::k) μ) events
      (.run q (.letF (.mk Capture.empty postprocessBody)::k) μ'))
    (normal : q.view=.ret decoded)
    (typed : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] decoded decoderInputType) :
    ∃ result last, Steps recordProgram recordBuiltins σ
      (.run (.mk Capture.empty (decodeThen decoder)) k μ) events (.run last k μ') ∧
      last.view=.ret result ∧ DecodeResult decoded result ∧
      HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] result decoderOutputType := by
  obtain ⟨result,last,tail,view,related,typed⟩ := postprocess_all typed k μ'
  refine ⟨result,last,?_,view,related,typed⟩
  apply Steps.cons (Step.E_Let rfl)
  simpa only [Closure.capture,Option.toList_none,List.nil_append,List.append_nil] using steps_trans child (Steps.cons (Step.E_Return normal) tail)

/-- 最初の返却という既存の構文上の境界からも、同じResultの接続を得る。 -/
theorem decodeThen_firstReturn {σ Ψ decoder events q μ μ' decoded} (k : Cont)
    (child : FirstReturn recordProgram recordBuiltins σ (.letF (.mk Capture.empty postprocessBody)::k)
      (.run (.mk Capture.empty decoder) (.letF (.mk Capture.empty postprocessBody)::k) μ)
      events q μ' decoded)
    (typed : HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] decoded decoderInputType) :
    ∃ result last, Steps recordProgram recordBuiltins σ
      (.run (.mk Capture.empty (decodeThen decoder)) k μ) events (.run last k μ') ∧
      last.view=.ret result ∧ DecodeResult decoded result ∧
      HasTypeVQ recordProgram recordBuiltins Ψ Qempty [] [] [] result decoderOutputType :=
  decodeThen_normal k child.steps.1 child.steps.2 typed

/-- 通常decoder自身がStopになった場合、追加検査を行わず同じ理由列を外へ返す。 -/
theorem decodeThen_failed {σ decoder events errors μ μ'} (k : Cont)
    (child : Steps recordProgram recordBuiltins σ
      (.run (.mk Capture.empty decoder) (.letF (.mk Capture.empty postprocessBody)::k) μ) events
      (.error errors (.letF (.mk Capture.empty postprocessBody)::k) μ')) :
    Steps recordProgram recordBuiltins σ (.run (.mk Capture.empty (decodeThen decoder)) k μ)
      events (.error errors k μ') := by
  apply Steps.cons (Step.E_Let rfl)
  simpa only [Closure.capture,Option.toList_none,List.nil_append,List.append_nil] using steps_trans child (Steps.cons Step.E_ErrPopLet Steps.nil)

end
end Benitoite.Release.Refinement.StandardDecode
