import Benitoite
/-! 新しい操作の Scoped は辞書の先頭の一致を読む。旧の Scoped と旧入力はこの条件を読まない。 -/
namespace RVLTenF
open Benitoite.Release.Refinement

def oldOp : Benitoite.Release.OpDecl :=
  { eff := "E", tparams := [{}], names := ["x"], params := [.base .unit], ret := .base .unit,
    dictParams := [("C", 0)] }

/-- 添字は範囲内で、先頭の引数の型は辞書でなく Unit である。旧の OpDecl.Scoped は両方とも読まない。 -/
theorem old_index : ∀ p ∈ oldOp.dictParams, p.2 < oldOp.tparams.length := by
  simp [oldOp]

/-- 写した宣言は新しい OpDecl.Scoped を満たさない。 -/
theorem new_rejects (P : Program) : ¬ (embedOpDecl oldOp).Scoped P := by
  intro h
  have hp := h.2.2.1
  simp [embedOpDecl, oldOp, embedParameters, Ty.shiftV_zero, embedTy] at hp

end RVLTenF

#print axioms RVLTenF.new_rejects
