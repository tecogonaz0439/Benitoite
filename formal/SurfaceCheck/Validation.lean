import SurfaceCheck.Batch

/-! 分類の除外条件と末尾の補正、戻り値の境界を独立した入力で確かめる。
設計書 07-04「証明する性質」の対象外を型の不一致と区別する。 -/
namespace SurfaceCheck.Validation
open Benitoite.Release Benitoite.Surface Benitoite.Surface.Check Benitoite.Surface.CheckTools
open SurfaceCheck.Batch
private def q : Input := {
  D := { funs := fun _ => none, cons := fun _ => none }, B := { sig := fun _ => none, delta := fun _ _ _ _ => none, ioResponse := fun _ _ _ _ _ => False, releaseResponse := fun _ _ => False, isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => False, refGet := "get", refSet := "set" }, satDec := fun _ _ _ => false, admitsDec := fun _ _ _ => false, opPrim := fun _ _ => none, ctors := fun _ => [], atoms := [.name "A"] }
-- 継続が隠された誤りも、プレースホルダ引数の誤りも、不一致として扱う。
#guard category q {} [] (.error ⟨[0,1,0,2],"continuation is missing or hidden"⟩) == "mismatched"
#guard category q { prims := ["unsupported"] } ["unsupported"] (.ok ()) == "outOfScope"
#guard category q { prims := ["supported"] } ["unsupported"] (.ok ()) == "matched"

private def intTy : Ty := .base .integer
private def fn : Expr := .lam [] [] intTy emptyEff (.last (.returnE intTy (.literal (.integer 1))))
private def lazyWalk : WalkState := {
  nodes := #[⟨[0],.lazyE (.last fn),some (.lazy (.fn [] [] intTy (Eff.single "A")))⟩] }
#guard category q lazyWalk [] (.error ⟨[0],"type is not included in the expected type"⟩) == "lazyRestriction"
#guard category q lazyWalk [] (.error ⟨[0],"effect exceeds the allowed effect"⟩) == "mismatched"
#guard category q lazyWalk [] (.error ⟨[0,0,0,0],"type is not included in the expected type"⟩) == "mismatched"

private def tailMatch : Expr := .matchE (.base .unit) (.literal (.boolean true))
  (.single .wild (.last (.returnE (.base .unit) (.literal (.integer 1)))) .nil)
private def changes (e : Expr) (p : Position) : Nat :=
  ((walkExpr q (some (.base .string)) p [] none e).run {}).2.changes.size
#guard changes tailMatch .tail == 1
#guard changes tailMatch .other == 0
#guard changes (.lam [] [] intTy emptyEff (.last tailMatch)) .other == 1
#guard changes (.lazyE (.last tailMatch)) .tail == 0
#guard changes (.withE "File" .unit (.last tailMatch)) .tail == 0
#guard changes (.ite .unit (.last tailMatch) (.last tailMatch)) .tail == 2
#guard changes (.matchE (.base .unit) .unit (.single .wild (.last .unit) .nil)) .tail == 0
end SurfaceCheck.Validation

namespace SurfaceCheck.Validation
open Benitoite.Release Benitoite.Surface Benitoite.Surface.Check Benitoite.Surface.CheckTools
open Benitoite.Surface.CheckTables Benitoite.Exchange.CheckInput SurfaceCheck.Batch
-- 個数だけでなく、ラムダ自身の R に置き換わることを検査する。
#guard match ((walkExpr q (some (.base .string)) .other [] none
    (.lam [] [] intTy emptyEff (.last tailMatch))).run {}).1 with
  | .lam _ _ _ _ (.last (.matchE t _ _)) => tyEq q.atoms t intTy
  | _ => false
private def material : Materials := {
  defs := [], conFields := [], accessors := [], data := [], ops := [], effects := [], classes := [("K",⟨[],[("pick",{ tparams := [], neffs := 0, names := [], params := [], ret := .tvar 0, eff := emptyEff })]⟩)], impls := [("I",{ signature := { tparams := [], dictParams := [], cls := "K", target := .base .string }, supers := [], methods := [("pick",{ names := [], body := .last (.matchE (.base .unit) .unit
      (.single .wild (.last (.returnE (.base .unit) (.literal (.string "x")))) .nil)) })] })], trustedFuns := [], trustedImpls := [] }
private def prepared : Prepared :=
  ⟨material,{ q with D := material.declarations },true,true,true,[]⟩
#guard match ((lookup (normalize prepared).1.impls "I").bind
    (fun i => lookup i.methods "pick")) with
  | some { body := .last (.matchE t _ _), .. } => tyEq q.atoms t (.base .string)
  | _ => false
end SurfaceCheck.Validation
