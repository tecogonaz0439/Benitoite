import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.ClosedKeys
import Benitoite.Release.Refinement.LogicSound
namespace Benitoite.Release.Refinement.RV04
noncomputable section
-- 反例: None か正の Some。短絡なしの評価が、篩を満たす値を拒む
def someField : FieldRef := ⟨"Opt","Some",0,.integer⟩
def cond : Pred := .or (.constructorIs (.var 0) "None") (.lt (.integer 0) (.field someField (.var 0)))
def noneV : Val := .con "None" [] []
def optT : Ty := .data "Opt" []
def noneDecl : ConDecl := ⟨"Opt",0,[]⟩
def someDecl : ConDecl := ⟨"Opt",0,[.base .integer]⟩
def prog : Program := ⟨fun _ => none, fun c => if c = "None" then some noneDecl else if c = "Some" then some someDecl else none,
  fun _ => none, fun _ => none, fun _ => none, fun _ => none, []⟩
theorem open_eq : (cond.open (.dataValue "None" [])) =
  .or (.constructorIs (.dataValue "None" []) "None") (.lt (.integer 0) (.field someField (.dataValue "None" []))) := rfl
theorem eval_none : (cond.open (.dataValue "None" [])).evalClosed = none := by decide
theorem left_true : (Pred.constructorIs (.dataValue "None" []) "None").evalClosed = some true := by decide
-- 導出は or_left で通る
theorem derivable : Entails [] (cond.open (.dataValue "None" [])) := by
  rw [open_eq]; exact .or_left (.ground (by decide) (by decide) left_true)
-- 受信の検査は拒否
theorem rejected : externalCheck prog noneV (.refined optT cond) = false := by
  simp only [externalCheck, Ty.sort?, optT, noneV, Val.toTerm?, Val.toTermSlots, prog, noneDecl, Pred.closedTrue, eval_none]
  simp [externalCheckFields, Ty.sort?]
  try decide
end
end Benitoite.Release.Refinement.RV04
#print axioms Benitoite.Release.Refinement.RV04.rejected
