import Benitoite.Release.Refinement.Surface.Desugar

/-!
# 構築器の脱糖の番号

専用の束縛を宣言した本体で、通常引数の束縛と結果を捨てる文が増やす共有の番号を、独立に書いた期待の核の項で
照合する（設計書 01-12「構築器の専用操作と脱糖」）。
-/
namespace Benitoite.Release.Refinement.Surface.BuilderExamples

private def appendAt (i : Nat) (s : String) : Expr :=
  .builderOp .append i (.cons (.literal (.string s)) .nil) .string
private def copyAt (i : Nat) : Expr := .builderOp .copy i .nil .string

/-- `builder b: String; b.append("x"); b.copy()`。通常引数 `"x"` の束縛の下では専用位置は番号 1 を指し、
結果を捨てる文の束縛の下でも番号 1 を指す。 -/
theorem dedicated_lowering :
    desugarBlock (fun _ _ => none) .other
      (.builderBind .string (.seq (appendAt 0 "x") (.last (copyAt 0)))) =
    .builderLet .string
      (.letIn (.letIn (.ret (.const (.string "x")))
        (.builderOp .string .append (.bound 1) [.var 0]))
        (.builderOp .string .copy (.bound 1) [])) := by
  rfl

end Benitoite.Release.Refinement.Surface.BuilderExamples
