import Benitoite.Surface.Theorems
open Benitoite.Release Benitoite.Surface

def kTy : Ty := .cont (.base .unit) (.base .unit) Eff.empty

def mkSig : PrimSig :=
  { tparams := [], neffs := 0, params := [], ret := kTy, eff := Eff.empty, admits := fun _ _ => True, kind := .pure, opEff := none }
def useSig : PrimSig :=
  { tparams := [], neffs := 0, params := [kTy], ret := .base .unit, eff := Eff.empty, admits := fun _ _ => True, kind := .pure, opEff := none }

def sigs (b : PrimName) : Option PrimSig :=
  if b = "mk" then some mkSig else if b = "use" then some useSig else none

def B0 : Builtins :=
  { sig := sigs, delta := fun _ _ _ _ => none, ioResponse := fun _ _ _ _ _ => False,
    releaseResponse := fun _ _ => False, isResource := fun _ => false, effects := fun _ => none,
    sat := fun _ _ _ => True, refGet := "g", refSet := "s" }

def op0 : OpPrim := fun _ _ => none

def body : Block := .last (.call (.primName "use" [] []) (.cons (.call (.primName "mk" [] []) .nil) .nil))

def d0 : Benitoite.Surface.Def := { tparams := [], neffs := 0, params := [], ret := .base .unit, eff := Eff.empty, body := body }

def P0 : Benitoite.Surface.Program := { defs := fun f => if f = "f" then some d0 else none, cons := fun _ => none }

example : desugarBlock op0 .tail body =
  .letIn (.app (.prim "mk" [] []) []) (.app (.prim "use" [] []) [.var 0]) := rfl

-- 表層では型が付く
theorem sr (ε : Eff) : Eff.substRho [] ε = ε := by
  funext a; cases a <;> simp [Eff.substRho]
theorem hU : fnTy useSig.params useSig.ret useSig.eff [] [] = .fn [kTy] (.base .unit) Eff.empty := by
  simp [fnTy, useSig, kTy, Ty.subst, Ty.substAt, sr]
theorem hM : fnTy mkSig.params mkSig.ret mkSig.eff [] [] = .fn [] kTy Eff.empty := by
  simp [fnTy, mkSig, kTy, Ty.subst, Ty.substAt, sr]

def D0 := P0.declarations
theorem tyMk : HasType D0 B0 op0 [] [] (some (.base .unit)) .other (.call (.primName "mk" [] []) .nil) kTy
    (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) :=
  HasType.E_Call (HasType.E_Sub (HasType.E_Prim (s := mkSig) rfl rfl rfl trivial) (Or.inl hM) (fun _ h => h)) HasTypes.nil
theorem tyBody : HasBlock D0 B0 op0 [] [] (some (.base .unit)) .tail body (.base .unit)
    (Eff.union Eff.empty (Eff.union (Eff.union (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) Eff.empty) Eff.empty)) :=
  HasBlock.B_Last (HasType.E_Call (HasType.E_Sub (HasType.E_Prim (s := useSig) rfl rfl rfl trivial) (Or.inl hU) (fun _ h => h))
    (HasTypes.cons tyMk HasTypes.nil))

-- 脱糖の結果の var 0 は継続の型なので V_Var で型が付かない（V_Var の前提 a ≠ cont）。
