import SurfaceCheck.Batch

/-! 分類の除外条件と末尾の補正、戻り値の境界を独立した入力で確かめる。
設計書 07-04「証明する性質」の対象外を型の不一致と区別する。 -/
namespace SurfaceCheck.Validation
open Benitoite.Release.Refinement Benitoite.Release.Refinement.Surface Benitoite.Release.Refinement.Surface.Check
open SurfaceCheck.Batch

private def table : Builtins := {
  sig := fun _ => none, delta := fun _ _ _ _ _ => none, ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False, isResource := fun _ => false, effects := fun _ => none
  sat := fun _ _ _ => False, refGet := "get", refSet := "set" }

private def q : Input := {
  D := { funs := fun _ => none, cons := fun _ => none }
  builtinSource := .custom table
  opPrim := fun _ _ => none
  formation := { atoms := [.name "A" .top], ctors := fun _ => [] }
  proofSteps := 1 }

-- 継続が隠された誤りも、プレースホルダ引数の誤りも、不一致として扱う。
#guard category q {} [] (.error ⟨[0,1,0,2],"continuation is missing or hidden",.rejected⟩) == "mismatched"
#guard category q { prims := ["unsupported"] } ["unsupported"] (.ok ()) == "outOfScope"
#guard category q { prims := ["supported"] } ["unsupported"] (.ok ()) == "matched"

private def intTy : Ty := .base .integer
private def fn : Expr := .lam [] [] intTy Eff.empty (.last (.returnE intTy (.literal (.integer ⟨1, by decide⟩))))
private def lazyWalk : WalkState := {
  nodes := #[⟨[0],.lazyE (.last fn),some (.lazy (.fn [] [] intTy (Eff.single "A")))⟩] }
#guard category q lazyWalk [] (.error ⟨[0],"type is not included in the expected type",.rejected⟩) == "lazyRestriction"
#guard category q lazyWalk [] (.error ⟨[0],"effect exceeds the allowed effect",.rejected⟩) == "mismatched"
#guard category q lazyWalk [] (.error ⟨[0,0,0,0],"type is not included in the expected type",.rejected⟩) == "mismatched"

private def tailMatch : Expr := .matchE (.base .unit) (.literal (.boolean true))
  (.cons [⟨.wild, []⟩] none (.last (.returnE (.base .unit) (.literal (.integer ⟨1, by decide⟩)))) .nil)
private def changes (e : Expr) (p : Position) : Nat :=
  ((walkExpr q (some (.base .string)) p [] none e).run {}).2.changes.size
#guard changes tailMatch .tail == 1
#guard changes tailMatch .other == 0
#guard changes (.lam [] [] intTy Eff.empty (.last tailMatch)) .other == 1
#guard changes (.lazyE (.last tailMatch)) .tail == 0
#guard changes (.withE "File" .unit (.last tailMatch)) .tail == 0
#guard changes (.ite .unit (.last tailMatch) (.last tailMatch)) .tail == 2
#guard changes (.matchE (.base .unit) .unit (.cons [⟨.wild, []⟩] none (.last .unit) .nil)) .tail == 0
-- 個数だけでなく、ラムダ自身の R に置き換わることを検査する。
#guard match ((walkExpr q (some (.base .string)) .other [] none
    (.lam [] [] intTy Eff.empty (.last tailMatch))).run {}).1 with
  | .lam _ _ _ _ (.last (.matchE t _ _)) => tyEq q t intTy
  | _ => false
end SurfaceCheck.Validation

namespace SurfaceCheck.Validation
open Benitoite.Release.Refinement Benitoite.Release.Refinement.Surface Benitoite.Release.Refinement.Surface.Check
open Benitoite.Release.Refinement.Surface.CheckTables Benitoite.Exchange.CheckInput SurfaceCheck.Batch
private def pickSig : MethSig :=
  { tparams := [], neffs := 0, names := [], params := [], ret := .tvar 0, eff := Eff.empty }
private def pickBody : Block := .last (.matchE (.base .unit) .unit
  (.cons [⟨.wild, []⟩] none (.last (.returnE (.base .unit) (.literal (.string "x")))) .nil))
private def implSig : ImplSig := { tparams := [], dictParams := [], cls := "K", target := .base .string }
private def material : Materials :=
  { classes := [("K", { methods := [("pick", pickSig)] })]
    impls := [("I", { signature := implSig, methods := [("pick", { names := [], body := pickBody })] })] }
private def prepared : Prepared :=
  ⟨material, material.input q, true, true, true, [],
    q.formation.atoms.map Benitoite.Exchange.fromAtom, (Benitoite.Exchange.filterMap_toRelease_fromAtom _).symm,
    Benitoite.Exchange.ScopeAcceptanceEntry.acceptInput none, [], [], fun _ => none, fun _ => none, [], [],
    ⟨[], []⟩, [], []⟩
-- 実装のメソッドの末尾の照合は、型クラスの宣言の結果型を実装の対象で具体化した型へ補正する。
#guard match ((lookup (normalize prepared).1.impls "I").bind
    (fun i => lookup i.methods "pick")) with
  | some { body := .last (.matchE t _ _), .. } => tyEq q t (.base .string)
  | _ => false
end SurfaceCheck.Validation
