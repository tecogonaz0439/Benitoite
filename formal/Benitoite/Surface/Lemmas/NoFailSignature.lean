import Benitoite.Surface.Syntax
import Benitoite.Release.NoFail

/-! 辞書引数を加えたコアの署名も、表層の宣言と同じ NoFail 条件を持つ。 -/
namespace Benitoite.Surface
open Benitoite.Release

@[simp] theorem QTys.append_iff (as bs : List Ty) (i : Nat) :
    QTys (as ++ bs) i ↔ QTys as i ∨ QTys bs i := by
  induction as with
  | nil => simp [QTys, Qempty]
  | cons a as ih => simp only [List.cons_append, QTys, ih, or_assoc]

/-- 制約の辞書は型変数だけを含むため、署名の NoFail 条件を増やさない。 -/
theorem FunDecl.dictTys_noQ (d : FunDecl) (i : Nat) : ¬ QTys d.dictTys i := by
  unfold FunDecl.dictTys
  induction d.dictParams with
  | nil => exact id
  | cons p ps ih =>
      simpa only [List.map_cons, QTys, QTy, Qempty, false_or] using ih

@[simp] theorem FunDecl.Qsig_core (d : FunDecl) :
    Qsig (d.dictTys ++ d.params) d.ret d.eff = Qsig d.params d.ret d.eff := by
  funext i
  apply propext
  simp only [Qsig, QTys.append_iff, d.dictTys_noQ, false_or]

end Benitoite.Surface
