import Benitoite.Surface.Check

/-! TODO-178: 穴で展開するラムダの R と継続の境界を独立した項で検査する。
引数の個数と宣言を満たし、拒否の経路と理由まで固定する。 -/
namespace Benitoite.Surface.Check.Counterexamples
open Benitoite.Release Benitoite.Surface.CheckTools
private def intTy : Ty := .base .integer
private def strTy : Ty := .base .string
private def optionTy : Ty := .data "Option" [intTy]
private def decls : Declarations :=
  { funs := fun n => if n == "add" then some {
      tparams := [], neffs := 0, params := [intTy,intTy], ret := intTy, eff := emptyEff } else none,
    cons := fun c => match c with
      | "Option.Some" => some ⟨"Option",1,[.tvar 0]⟩
      | "Option.None" => some ⟨"Option",1,[]⟩
      | _ => none,
    ops := fun o => if o == "Pick.value" then some {
      eff := "Pick", tparams := [], params := [], ret := intTy } else none }
private def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => False,
    refGet := "get", refSet := "set" }
private def input : Input :=
  { D := decls, B := builtins, satDec := fun _ _ _ => true, admitsDec := fun _ _ _ => false,
    opPrim := fun _ _ => none,
    ctors := fun n => if n == "Option" then ["Option.Some","Option.None"] else [], atoms := [.name "Pick"] }
private def partialAdd (e : Expr) : Expr :=
  .partialCall (.funName "add" [] []) (.expr e (.hole intTy .nil)) intTy emptyEff
private def make : Def :=
  { tparams := [], neffs := 0, params := [], ret := strTy, eff := emptyEff,
    body := .bind .bind (.fn [intTy] intTy emptyEff)
      (partialAdd (.returnE intTy (.literal (.string "escaped"))))
      (.last (.returnE strTy (.literal (.string "ok")))) }
private def probe : Def :=
  { tparams := [], neffs := 0, params := [], ret := optionTy, eff := emptyEff,
    body := .bind .bind (.fn [intTy] intTy emptyEff)
      (partialAdd (.tryOption [intTy] "Option.Some" "Option.None" (.nullCon "Option.None" [intTy])))
      (.last (.returnE optionTy (.nullCon "Option.None" [intTy]))) }

private def errorOf {α : Type} : Result α → Option Error
  | .ok _ => none
  | .error e => some e
example : errorOf (checkDef input [] make) =
    some ⟨[0,0,1,0,0],"type is not included in the expected type"⟩ := by decide
example : errorOf (checkDef input [] probe) =
    some ⟨[0,0,1,0],"Option return type mismatch"⟩ := by decide
private def handled : Def :=
  { tparams := [], neffs := 0, params := [], ret := intTy, eff := emptyEff,
    body := .last (.returnE intTy (.handleE (.last (.literal (.integer 1)))
      (.cons (.user "Pick.value") 0 0
        (.bind .bind (.fn [intTy] intTy emptyEff)
          (partialAdd (.resume 0 (.literal (.integer 10))))
          (.last (.resume 1 (.literal (.integer 10))))) .nil))) }
-- 本物のハンドラの節で継続を束縛し、非穴の引数に到達してから拒否する。
example : errorOf (checkDef input [] handled) =
    some ⟨[0,0,0,1,0,0,1,0],"continuation is missing or hidden"⟩ := by decide

-- 対照: 同じ引数位置の Integer は受理され、宣言や個数による拒否ではない。
example : (checkExpr input .strict [] [] (some strTy) .other []
    (partialAdd (.literal (.integer 10)))).isOk = true := by decide
end Benitoite.Surface.Check.Counterexamples
