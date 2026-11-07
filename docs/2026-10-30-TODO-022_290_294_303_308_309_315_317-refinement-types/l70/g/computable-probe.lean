import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.Desugar
import Lean
open Lean Elab Command
-- 入口が呼ぶ規範の検査と脱糖に実行コードがあるかを調べる。
run_cmd do
  let env ← getEnv
  let names := [``Benitoite.Release.Refinement.Surface.CheckAccept.checkProgramAccepted,
    ``Benitoite.Release.Refinement.Surface.CheckAccept.acceptDef,
    ``Benitoite.Release.Refinement.Surface.CheckAccept.acceptMethod,
    ``Benitoite.Release.Refinement.Surface.CheckDeclarations.checkDef,
    ``Benitoite.Release.Refinement.Surface.CheckDeclarations.checkImpl,
    ``Benitoite.Release.Refinement.Surface.CheckTables.checkProgram,
    ``Benitoite.Release.Refinement.Surface.Check.Input.B,
    ``Benitoite.Release.Refinement.Surface.Check.BuiltinSource.builtins,
    ``Benitoite.Release.Refinement.Surface.desugarDef,
    ``Benitoite.Release.Refinement.Surface.desugarImpl,
    ``Benitoite.Release.Refinement.Surface.desugarProgram,
    ``Benitoite.Release.Refinement.Surface.holeLam]
  for n in names do
    logInfo m!"{n}: noncomputable={isNoncomputable env n}"
