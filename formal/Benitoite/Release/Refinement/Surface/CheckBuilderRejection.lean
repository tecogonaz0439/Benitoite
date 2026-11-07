import Benitoite.Release.Refinement.Surface.CheckSound

/-!
# 宣言のない専用操作の拒否と組込みの名前の脱糖

設計書 01-12「構築器の分類と環境の対応」「脱糖」に対応する。検査器は、専用の位置を宣言していない中間状態（空の分類表）の
専用操作を、どの検査の案内のもとでも受理しない（`builderOp_empty_rejected`）。組込みの名前の脱糖は範囲の列を
そのまま写す（`desugar_primName`）。
-/
namespace Benitoite.Release.Refinement.Surface

namespace Check

/-- 宣言のない中間状態では、任意の専用操作を空の分類表で拒否する。 -/
theorem builderOp_empty_rejected (q : Input) (rows : List Bool) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (R : Option Ty) (p : Position) (path : List Nat) (op : BuilderOp) (i : Nat) (args : Exprs)
    (kind : BuilderKind) (a : Ty) (ε : Eff) (g : Guide) :
    checkExprAt q rows [] C Γ Φ R p path (.builderOp op i args kind) a ε g = false := by
  match g with
  | .unknown => simp [checkExprAt]
  | .failure _ => simp [checkExprAt]
  | .node rule h children =>
    unfold checkExprAt
    cases rule <;> simp only [Bool.and_eq_false_iff] <;> right <;> (repeat' split) <;>
      first
      | rfl
      | simp_all [Expr.valueOf?]
      | (rename_i ge
         simp only [allChecks, builderOp_empty_rejected q rows C Γ Φ R p _ op i args kind _ _ ge, Bool.false_and])
termination_by g
decreasing_by
  all_goals simp_wf
  all_goals (subst_vars; simp; omega)

end Check

/-- 脱糖は組込みの名前の範囲の列をそのまま写す。 -/
theorem desugar_primName (op : OpPrim) (p : Position) (b : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeIx) : desugarExpr op p (.primName b ts es rs) = .ret (.prim b ts es rs) := by
  simp [desugarExpr]

end Benitoite.Release.Refinement.Surface
