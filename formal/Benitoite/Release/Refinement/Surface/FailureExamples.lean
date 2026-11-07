import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound

/-!
# 型付きの失敗の検査器の受理と拒否

篩付きの表層の検査器で、型付きの失敗（`Fail.raise` と非再開の一節 `handleFail`）を確かめる。直接の raise は
失敗の型を効果に残し、同じ型の捕捉はそれを除き、節から別の型へ raise し直せばその型だけが残る。捕捉する型の
取り違えと、非再開の節の予約した継続の利用は拒否する（設計書 01-12「型付きの失敗の表層検査」）。
-/
namespace Benitoite.Release.Refinement.Surface.FailureExamples
open Check

private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string

private def builtins : Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "get"
  refSet := "set"

private def input : Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 10

private def raiseAt (T E : Ty) (e : Expr) : Expr := .call (.raise T E) [none] [0] (.cons e .nil)
private def value : Expr := .literal (.integer ⟨7, by decide⟩)
private def raised : Expr := raiseAt intTy strTy (.literal (.string "bad"))

/-- 検査の成功の効果の失敗の型の列。拒否なら `none`。 -/
private def failsOf (e : Expr) : Option (List Ty) :=
  match Check.checkExpr input [] [] [] none .other [] e with
  | .ok (_, ε) => some ε.fails
  | .error _ => none

/-- 直接の raise は失敗の型 String を効果に残す。 -/
theorem raised_checked : failsOf raised = some [strTy] := by
  cbv

/-- 同じ型の捕捉は失敗を除き、節から Integer へ raise し直すと Integer の失敗だけが残る。 -/
theorem caught_checked :
    failsOf (.handleFail strTy intTy (.last raised) (.last value)) = some [] ∧
    failsOf (.handleFail strTy intTy (.last raised) (.last (raiseAt intTy intTy value))) = some [intTy] := by
  constructor <;> cbv

/-- 捕捉する型を取り違えた節と、非再開の節での予約した継続の利用は拒否する。 -/
theorem failure_rejected :
    failsOf (.handleFail intTy intTy (.last raised) (.last value)) = none ∧
    failsOf (.handleFail strTy intTy (.last raised) (.last (.resume 0 value))) = none := by
  constructor <;> cbv

end Benitoite.Release.Refinement.Surface.FailureExamples
