import Benitoite.Release.Refinement.Surface.CheckDeclarations
import Benitoite.Release.Refinement.Surface.CheckEffects

/-! 全プログラムの有限検査。定義とメソッドの予算と view は本体ごとに選ぶ。 -/
namespace Benitoite.Release.Refinement.Surface.CheckTables

/-- 変性と効果の所属を検査し、一覧にある全ての定義と実装の本体を検査する。 -/
def checkProgram (q : Check.Input) (p : Program) : Check.Result Unit := do
  Check.require [] "invalid data variance"
    (CheckVariance.check q.formation q.D.core q.dataNames q.ctorNames)
  Check.require [] "invalid effect declarations" (effectsCheck q)
  checkNamed p.defs (fun path n d =>
    CheckDeclarations.checkDef {q with D := q.D.withView (p.functionViews n), proofSteps := q.functionSteps n} path d) [0] q.defs 0
  checkNamed p.impls (fun path n id =>
    CheckDeclarations.checkImpl q n path id (p.methodViews n)) [1] q.impls 0

end Benitoite.Release.Refinement.Surface.CheckTables
