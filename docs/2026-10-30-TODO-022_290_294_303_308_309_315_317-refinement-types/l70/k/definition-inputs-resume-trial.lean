import Benitoite.Release.Refinement.RangeFunctionExamples
import Benitoite.Release.Refinement.Context.WF
import Benitoite.Release.Refinement.ComputationInputs

/-! 範囲パラメータを持つ型付きの定義と、未具体化の旧入力の結論の不両立。 -/
namespace Benitoite.Release.Refinement.DefinitionInputsResumeTrial
noncomputable section
open RangeFunctionExamples

/-- 固定された入口の前提と結論を、全プログラム・全定義について量化する。 -/
def OldInputsStatement : Prop :=
  ∀ (P : Program) (B : Builtins) (d : Def), Def.WellTyped P B d →
    Ctx.Regular P d.tparams (d.tel.context []) ∧
    d.body.Inputs P B StoreTy.empty (QTel d.tel) d.tparams
      (d.tel.context []) (liftMany d.tel.arity [])
      (some d.tel.result) d.tel.result d.tel.effect []

/-- 引数の範囲変数0は、範囲深さ0で整形式にならない。 -/
theorem not_reader_regular :
    ¬ Ctx.Regular program readerDef.tparams (readerDef.tel.context []) := by
  intro h
  have bad := h.wf 0 (pathTy (.rvar 0)) (by rfl)
  simp [Ty.WF, pathTy, RangeIx.WF] at bad

/-- 本番の定義の型付けを満たす入力と、旧結論の否定を同時に示す。 -/
theorem reader_obstruction :
    readerDef.WellTyped program builtins ∧
    ¬ (Ctx.Regular program readerDef.tparams (readerDef.tel.context []) ∧
      readerDef.body.Inputs program builtins StoreTy.empty (QTel readerDef.tel) readerDef.tparams
        (readerDef.tel.context []) (liftMany readerDef.tel.arity [])
        (some readerDef.tel.result) readerDef.tel.result readerDef.tel.effect []) :=
  ⟨reader_wellTyped, fun h => not_reader_regular h.1⟩

theorem old_inputs_statement_false : ¬ OldInputsStatement := by
  intro h
  exact reader_obstruction.2 (h program builtins readerDef reader_obstruction.1)

/-- 適格な具体化の存在を、全三種類の範囲文脈について供給する。 -/
theorem range_context_inhabited (ks : List Scope.Domain.Kind) :
    ∃ rs, RangesFit rs ks := ⟨_, RangesFit.top ks⟩

/-- 具体化した通常のパスを渡す呼出しにも、本番の判断で型が付く。 -/
theorem concrete_call :
    HasTypeCQ program builtins StoreTy.empty Qempty [] [] [] none
      (.app (.fnRef "reader" [] [] [.fixed .top]) [.checked (.path [])])
      readResult (readEff (.fixed .top)) [] := reader_root_call

end
end Benitoite.Release.Refinement.DefinitionInputsResumeTrial
