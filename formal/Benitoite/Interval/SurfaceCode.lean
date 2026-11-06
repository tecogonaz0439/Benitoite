import Benitoite.Interval.SurfaceSyntax
import Benitoite.Release.Refinement.Surface.Desugar

/-! # 独立評価の構文と新しい脱糖の対応 -/
namespace Benitoite.Interval.SurfaceCode
open Benitoite.Release.Refinement
open SurfaceSyntax
noncomputable section

/-- 独立評価の式を、新しい表層の脱糖へ渡す。 -/
def expr (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position)
    (source : Benitoite.Surface.Expr) : Comp :=
  Surface.desugarExpr (liftOp op) (liftPosition position) (liftExpr source)

/-- 独立評価の文列を、新しい表層の脱糖へ渡す。 -/
def block (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position)
    (source : Benitoite.Surface.Block) : Comp :=
  Surface.desugarBlock (liftOp op) (liftPosition position) (liftBlock source)

/-- 独立評価の腕の列を、新しい表層の脱糖へ渡す。 -/
def arms (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position)
    (source : Benitoite.Surface.Arms) : List Arm :=
  Surface.desugarArms (liftOp op) (liftPosition position) (liftArms source)

/-- 腕の外側の変数の前に、照合した値の一スロットを挿入したガード。 -/
def armExpr (op : Benitoite.Surface.OpPrim) (binders : Nat)
    (source : Benitoite.Surface.Expr) : Comp :=
  Surface.desugarExpr (liftOp op) .other
    (Surface.SourceRename.expr (Benitoite.Release.upRen binders (·+1)) (liftExpr source))

/-- パターンで束縛した値を保護し、照合対象のスロットを挿入した本体。 -/
def armBlock (op : Benitoite.Surface.OpPrim) (position : Benitoite.Surface.Position) (binders : Nat)
    (source : Benitoite.Surface.Block) : Comp :=
  Surface.desugarBlock (liftOp op) (liftPosition position)
    (Surface.SourceRename.block (Benitoite.Release.upRen binders (·+1)) (liftBlock source))


end
end Benitoite.Interval.SurfaceCode
