import Benitoite.Release.Refinement.Ground

/-! # 表層から作る構文と実行時だけの構文の区別 -/
namespace Benitoite.Release.Refinement
mutual
  def Val.Source : Val → Prop
    | .pathBases _ | .checkedAt _ _ _ _ | .atError _ | .externalHandle _ _ |
        .closure _ _ | .checked _ | .checkedRequest _ _ | .loc _ => False
    | .lam _ _ body | .dependentLam _ body => body.Source
    | .con _ _ vs | .dict _ _ vs | .list vs | .setV vs => sourceVals vs
    | .mapV ks vs => sourceVals ks ∧ sourceVals vs
    | .super v _ => v.Source
    | _ => True
  def sourceVals : List Val → Prop
    | [] => True
    | v :: vs => v.Source ∧ sourceVals vs
  def Comp.Source : Comp → Prop
    | .issuePathBases _ => False
    | .builderLet _ m | .lazyC m => m.Source
    | .builderOp _ _ _ vs | .externalCall _ _ vs => sourceVals vs
    | .ret v | .escape v => v.Source
    | .letIn m n => m.Source ∧ n.Source
    | .app v vs | .meth v _ _ _ vs => v.Source ∧ sourceVals vs
    | .ite v m n => v.Source ∧ m.Source ∧ n.Source
    | .match v arms => v.Source ∧ sourceArms arms
    | .use v m => v.Source ∧ m.Source
    | .handle m cs => m.Source ∧ sourceClauses cs
    | .resume k v => k.Source ∧ v.Source
    | .checkAt _ _ _ bs p v _ => (match bs with | none => True | some b => b.Source) ∧ p.Source ∧ v.Source
  def sourceArms : List Arm → Prop
    | [] => True
    | .mk _ guard body :: arms =>
        (match guard with | none => True | some g => g.Source) ∧ body.Source ∧ sourceArms arms
  def sourceClauses : List Clause → Prop
    | [] => True
    | .mk _ _ _ body :: cs | .fail _ body :: cs => body.Source ∧ sourceClauses cs
end
end Benitoite.Release.Refinement
