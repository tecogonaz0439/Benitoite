import Benitoite.Surface.Theorems
import Benitoite.Release.CoverExamples

/-!
# 表層の効果の上限の被覆による包含と、表層の対象健全性が IO の事象に届く例（L40.6c・L50.4）

表層の `E_Sub`・`B_Sub` は、判断 5 の一原子の被覆（`Eff.Covers`）で効果を広げる。L20.7 の実例の表
`ModelTargets.Examples.B` の上で、構造上の包含では型付かず被覆だけで型付く表層のプログラムに、表層の対象健全性
（`surface_target_sound`）が当たることを確かめる。

- `f(path: PathIn["/data/a.txt"]) : Unit uses File.Write["/data/**"]` の本体は
  `File.writeTextIn["/data/a.txt"](path: path, text: "x")` であり、本体の効果 `{File.Write["/data/a.txt"]}` は上限に
  被覆でだけ含まれる（`Release.CoverExamples.not_sub_narrow`）。
- `g(path: PathIn["/data/a.txt"]) : Unit uses File.Write["/data/a.txt"]` は同じ本体を持ち、
  `h(path: PathIn["/data/a.txt"]) : Unit uses File.Write["/data/**"]` の本体は `g(path: path)` である（狭い効果を宣言した
  利用者の関数を広い上限の関数から呼ぶ）。
- `main() : Unit uses File.Write["/data/**"]` の本体は
  `match Scope.checkPathIn["/data/a.txt"](pattern: "/data/**", path: "/data/a.txt") { Ok(p) => f(path: p); Err(e) => () }`
  である（RV-L50 中1・RV-L40 軽8）。表層の構文は検査済みの対象の値を書けないので、`f` へ渡す値は検査の呼び出しの結果の
  照合から得る。脱糖したプログラムの開始状態 `main[;]()` から 18 回の事象のない遷移の後、`f` の本体の書き込みの事象
  （観測 `[/data/a.txt]`）に到達する（`main_reach`。遷移を計算する関数 `step` をカーネルで評価し、`step_sound` で遷移の
  関係へ移す）。到達した事象の観測を `surface_target_sound` に当て、`/data/a.txt` を上限が許し（`main_reach_allowed`）、
  どの到達した書き込みの事象の観測にも `/etc/passwd` が現れないこと（`main_never_passwd`）を導く。
-/

namespace Benitoite.Surface.CoverExamples

open Benitoite.Release
open Benitoite.Release.ModelTargets
open Benitoite.Release.ModelTargets.Examples
open Benitoite.Release.HandlerTargetExamples
open Benitoite.Release.CoverExamples
open Scope.Domain (Range Target)

private def opPrim : OpPrim := fun _ _ => none

/-- `PathIn["/data/a.txt"]`。 -/
abbrev pathTy : Ty := .opaque "Scope.PathIn" (.fixed exactR)

/-- `File.writeTextIn["/data/a.txt"](path: <局所変数 i>, text: "x")`。 -/
def writeE (i : Nat) : Expr :=
  .call (.primName "File.writeTextIn" [] [] [exactR]) [some "path", some "text"] [0, 1]
    (.cons (.local i) (.cons (.literal (.string "x")) .nil))

/-- `g(path: <局所変数 i>)`。 -/
def callGE (i : Nat) : Expr :=
  .call (.funName "g" [] []) [some "path"] [0] (.cons (.local i) .nil)

def unitDecl (eff : Eff) : FunDecl :=
  { tparams := [], neffs := 0, names := ["path"], params := [pathTy], ret := .base .unit, eff := eff }

def fDef : Def := { unitDecl bodyData with body := .lastDiscard (writeE 0) }
def gDef : Def := { unitDecl narrowEff with body := .lastDiscard (writeE 0) }
def hDef : Def := { unitDecl bodyData with body := .lastDiscard (callGE 0) }
/-- `Scope.checkPathIn["/data/a.txt"](pattern: "/data/**", path: "/data/a.txt")`。 -/
def checkE : Expr := .call (.primName "Scope.checkPathIn" [] [] [exactR]) [some "pattern", some "path"] [0, 1]
  (.cons (.literal (.string "/data/**")) (.cons (.literal (.string "/data/a.txt")) .nil))

/-- `f(path: <局所変数 i>)`。 -/
def callFE (i : Nat) : Expr :=
  .call (.funName "f" [] []) [some "path"] [0] (.cons (.local i) .nil)

def okAlt : List Alternative := [⟨.con none "Ok" [.var], [0]⟩]
def errAlt : List Alternative := [⟨.con none "Err" [.var], [0]⟩]

/-- `Ok(p) => f(path: p)`、`Err(e) => ()`。 -/
def mainArms : Arms := .cons okAlt none (.last (callFE 0)) (.cons errAlt none (.last .unit) .nil)

/-- 検査の結果の型 `Result[PathIn["/data/a.txt"], Scope.ScopeError]`。 -/
abbrev checkTy : Ty := .data "Result" [pathTy, TargetTable.scopeErrorTy]

def mainBody : Block := .last (.matchE (.base .unit) checkE mainArms)

def mainDef : Def :=
  { tparams := [], neffs := 0, names := [], params := [], ret := .base .unit, eff := bodyData, body := mainBody }

def defTable : FunName → Option Def := fun f =>
  if f = "f" then some fDef else if f = "g" then some gDef else if f = "h" then some hDef
  else if f = "main" then some mainDef else none

def program : Program := { defs := defTable, cons := resultCons }

/-! ## 本体の型付け -/

theorem write_names_wf : NamesWF (TargetTable.writeTextIn.inst [exactR]).names
    (TargetTable.writeTextIn.inst [exactR]).params := by
  simp [NamesWF, TargetTable.writeTextIn, TargetTable.ioIn, PrimSig.inst]

theorem write_fnTy :
    fnTy (TargetTable.writeTextIn.inst [exactR]).names (TargetTable.writeTextIn.inst [exactR]).params
      (TargetTable.writeTextIn.inst [exactR]).ret (TargetTable.writeTextIn.inst [exactR]).eff [] [] =
    .fn ["path", "text"] [pathTy, .base .string] writeRet narrowEff := by
  rw [fnTy_eq, write_params_at, writeTextIn_ret, write_eff_at]
  rfl

/-- 書き込みの呼び出しの型付け。効果は `{File.Write["/data/a.txt"]}` と空の効果の和である。 -/
theorem writeE_typed {D : Declarations} {Q : NoFailCtx} {Γ : List (Option Ty)} {R : Option Ty} {i : Nat}
    (hΓ : Γ[i]? = some (some pathTy)) :
    HasTypeQ D B opPrim Q [] [] Γ R .other (writeE i) writeRet
      (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) narrowEff)) := by
  have hp := HasTypeQ.E_Prim (D := D) (B := B) (opPrim := opPrim) (Q := Q) (Δ := []) (C := []) (Γ := Γ) (R := R)
    (p := .other) (b := "File.writeTextIn") (s := TargetTable.writeTextIn) (ts := []) (es := []) (rs := [exactR])
    sig_write write_admissible_exact write_names_wf rfl rfl rfl
    (PrimitiveAdmissible.of_noRows_inst write_scoped (by simp [TargetTable.writeTextIn, TargetTable.ioIn, PrimSig.nranges])
      rfl rfl rfl (by simp))
    (by rw [write_fnTy]; simp [SingleTy, SingleTys, SingleEff, SingleFail, writeTys, TargetTable.ioErrorTy,
      Eff.singleAt, Eff.ofAtoms, Eff.fails])
  rw [write_fnTy] at hp
  have hok : CallOk ["path", "text"] [pathTy, .base .string] false [some "path", some "text"] [0, 1] :=
    ⟨by simp [NamesWF], rfl, List.Perm.refl _, Or.inr (Or.inr ⟨rfl, by simp⟩)⟩
  have hargs : HasTypesQ D B opPrim Q [] [] Γ R (.cons (.local i) (.cons (.literal (.string "x")) .nil))
      (sourceTypes [pathTy, .base .string] [0, 1]) (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) :=
    .cons (.E_Local hΓ (by intro b t ε h; cases h)) (.cons .E_Literal .nil)
  exact HasTypeQ.E_Call hp hok hargs (by
    simp [SingleEff, SingleFail, SingleTys, Eff.union, Eff.norm, Eff.empty, Eff.singleAt, Eff.ofAtoms, Eff.fails])

/-- 空の効果と e の和は、e が覆う。 -/
theorem covers_write_union {e : Eff} (h : e.Covers narrowEff) :
    e.Covers (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) narrowEff)) :=
  (Eff.covers_empty _).union (((Eff.covers_empty _).union ((Eff.covers_empty _).union (Eff.covers_empty _))).union h)

theorem qsig_path (eff : Eff) (h : eff.fails = []) : Qsig [pathTy] (.base .unit) eff = Qempty := by
  funext i; apply propext
  cases eff with
  | mk a fs =>
    simp only [Eff.fails] at h
    subst h
    simp [Qsig, QTys, QTy, QEff, Qempty]

theorem decl_funs (f : FunName) (d : Def) (h : defTable f = some d) (view : CoverageView) :
    (program.declarationsFor view).funs f = some d.toFunDecl := by
  simp [Program.declarationsFor_funs, Program.declarations, Program.lookupFun, program, h]

theorem adm_path {Q : NoFailCtx} (ix : Scope.Signature.Ix) :
    Admissible B [] [] 0 (Qsig [pathTy] (.base .unit) (Eff.singleAt "File.Write" ix)) Q [] []
      (Eff.singleAt "File.Write" ix) := by
  rw [qsig_path _ rfl]
  exact
    { types := ⟨rfl, fun i _ _ h => by simp at h⟩
      typeScope := fun t h => by simp at h
      rowCount := rfl
      rowScope := fun f h => by simp at h
      sourceRows := by
        simp only [Eff.singleAt, Eff.ofAtoms, Eff.RowsIn, Ty.RowsInList]
        refine ⟨fun i h => ?_, trivial⟩
        simp at h
      sourceQ := fun i h => by simp [Qempty] at h
      noFailRows := fun i h => by simp [Qempty] at h }

/-- `g(path: path)` の型付け。効果は `g` の宣言の狭い効果 `{File.Write["/data/a.txt"]}` と空の効果の和である。 -/
theorem callGE_typed {view : CoverageView} {Q : NoFailCtx} {Γ : List (Option Ty)} {R : Option Ty} {i : Nat}
    (hΓ : Γ[i]? = some (some pathTy)) :
    HasTypeQ (program.declarationsFor view) B opPrim Q [] [] Γ R .other (callGE i) (.base .unit)
      (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty Eff.empty) narrowEff)) := by
  have hfn : fnTy gDef.toFunDecl.names gDef.toFunDecl.params gDef.toFunDecl.ret gDef.toFunDecl.eff [] [] =
      .fn ["path"] [pathTy] (.base .unit) narrowEff := by
    rw [fnTy_eq]
    simp [gDef, unitDecl, Ty.subst, Ty.substAt, substAt_singleAt]
  have hf := HasTypeQ.E_Fun (D := program.declarationsFor view) (B := B) (opPrim := opPrim) (Q := Q) (Δ := [])
    (C := []) (Γ := Γ) (R := R) (p := .other) (f := "g") (d := gDef.toFunDecl) (ts := []) (es := [])
    (decl_funs "g" gDef (by simp [defTable]) view) (by simp [NamesWF, gDef, unitDecl])
    (by simp [NamesWF, gDef, unitDecl, FunDecl.coreNames, FunDecl.dictTys, internalNames])
    ⟨rfl, by intro i t tp hi _; simp at hi⟩ rfl rfl
    (by simpa [gDef, unitDecl, FunDecl.dictTys] using adm_path (Q := Q) (.fixed exactR))
    (by rw [hfn]; simp [SingleTy, SingleTys, SingleEff, SingleFail, Eff.singleAt, Eff.ofAtoms, Eff.fails])
  rw [hfn] at hf
  have hok : CallOk ["path"] [pathTy] false [some "path"] [0] :=
    ⟨by simp [NamesWF], rfl, List.Perm.refl _, Or.inr (Or.inr ⟨rfl, by simp⟩)⟩
  exact HasTypeQ.E_Call hf hok (.cons (.E_Local hΓ (by intro b t ε h; cases h)) .nil) (by
    simp [SingleEff, SingleFail, SingleTys, Eff.union, Eff.norm, Eff.empty, Eff.singleAt, Eff.ofAtoms, Eff.fails])

/-- 上限 `{File.Write["/data/**"]}` での書き込みの型付け（`E_Sub` の被覆）。 -/
theorem writeE_bound {D : Declarations} {Q : NoFailCtx} {Γ : List (Option Ty)} {R : Option Ty} {i : Nat}
    (hΓ : Γ[i]? = some (some pathTy)) :
    HasTypeQ D B opPrim Q [] [] Γ R .other (writeE i) writeRet bodyData :=
  .E_Sub (writeE_typed hΓ) (Ty.Le.refl _) (covers_write_union bound_covers_narrow)
    (by simp [writeTys, TargetTable.ioErrorTy, Ty.VarsIn, Ty.VarsInList])

/-- 上限 `{File.Write["/data/a.txt"]}` での書き込みの型付け。 -/
theorem writeE_narrow {D : Declarations} {Q : NoFailCtx} {Γ : List (Option Ty)} {R : Option Ty} {i : Nat}
    (hΓ : Γ[i]? = some (some pathTy)) :
    HasTypeQ D B opPrim Q [] [] Γ R .other (writeE i) writeRet narrowEff :=
  .E_Sub (writeE_typed hΓ) (Ty.Le.refl _) (covers_write_union (Eff.Covers.refl _))
    (by simp [writeTys, TargetTable.ioErrorTy, Ty.VarsIn, Ty.VarsInList])

/-- 狭い効果の利用者の関数の呼び出しを、上限 `{File.Write["/data/**"]}` で型付ける（`E_Sub` の被覆）。 -/
theorem callGE_bound {view : CoverageView} {Q : NoFailCtx} {Γ : List (Option Ty)} {R : Option Ty} {i : Nat}
    (hΓ : Γ[i]? = some (some pathTy)) :
    HasTypeQ (program.declarationsFor view) B opPrim Q [] [] Γ R .other (callGE i) (.base .unit) bodyData :=
  .E_Sub (callGE_typed hΓ) (Ty.Le.refl _)
    ((Eff.covers_empty _).union (((Eff.covers_empty _).union (Eff.covers_empty _)).union bound_covers_narrow))
    (by simp [Ty.VarsIn])

/-! ## main の本体の型付け（検査の呼び出しの結果の照合） -/

theorem check_admissible_exact : B.RangeAdmissible "Scope.checkPathIn" TargetTable.checkPathIn [exactR] := by
  refine ⟨⟨?_, ?_, Or.inr ⟨Or.inr rfl, rfl⟩⟩, ?_⟩
  · exact ⟨by decide, Scope.Domain.Range.fitsKinds_nil⟩
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide
  · intro r hr; simp only [List.mem_singleton] at hr; subst hr; decide

theorem check_names_wf : NamesWF (TargetTable.checkPathIn.inst [exactR]).names
    (TargetTable.checkPathIn.inst [exactR]).params := by
  simp [NamesWF, TargetTable.checkPathIn, TargetTable.pureIn, PrimSig.inst]

/-- 空の効果の範囲の具体化は空の効果である。 -/
theorem instR_empty (rs : List Range) : Eff.instR rs Eff.empty = Eff.empty := by
  simp only [Eff.empty, Eff.instR, List.map_nil, EffR.mk.injEq, and_true]
  funext x
  cases x with
  | name l ix => cases ix <;> simp [Eff.instAtoms]
  | rho i => simp [Eff.instAtoms]

theorem check_eff_at : Eff.substAt 0 [] [] (TargetTable.checkPathIn.inst [exactR]).eff = Eff.empty := by
  rw [PrimSig.inst_eff]
  simp only [TargetTable.checkPathIn, TargetTable.pureIn]
  rw [instR_empty, Eff.substAt_empty]

theorem check_params_at :
    (TargetTable.checkPathIn.inst [exactR]).params.map (Ty.subst [] []) = [.base .string, .base .string] := by
  simp [TargetTable.checkPathIn, TargetTable.pureIn, Ty.instTarget, Ty.subst, Ty.substAt]

theorem check_fnTy :
    fnTy (TargetTable.checkPathIn.inst [exactR]).names (TargetTable.checkPathIn.inst [exactR]).params
      (TargetTable.checkPathIn.inst [exactR]).ret (TargetTable.checkPathIn.inst [exactR]).eff [] [] =
    .fn ["pattern", "path"] [.base .string, .base .string] checkTy Eff.empty := by
  rw [fnTy_eq, check_params_at, checkPathIn_ret, check_eff_at]
  rfl

/-- 検査の呼び出しの型付け。効果は空の効果の和である。 -/
theorem checkE_typed {D : Declarations} {Q : NoFailCtx} {Γ : List (Option Ty)} {R : Option Ty} :
    HasTypeQ D B opPrim Q [] [] Γ R .other checkE checkTy
      (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) Eff.empty)) := by
  have hp := HasTypeQ.E_Prim (D := D) (B := B) (opPrim := opPrim) (Q := Q) (Δ := []) (C := []) (Γ := Γ) (R := R)
    (p := .other) (b := "Scope.checkPathIn") (s := TargetTable.checkPathIn) (ts := []) (es := []) (rs := [exactR])
    sig_check check_admissible_exact check_names_wf rfl rfl rfl
    (PrimitiveAdmissible.of_noRows_inst check_scoped (by simp [TargetTable.checkPathIn, TargetTable.pureIn, PrimSig.nranges])
      rfl rfl rfl (by simp))
    (by rw [check_fnTy]; simp [SingleTy, SingleTys, SingleEff, SingleFail, TargetTable.scopeErrorTy,
      Eff.empty, Eff.fails])
  rw [check_fnTy] at hp
  have hok : CallOk ["pattern", "path"] [.base .string, .base .string] false [some "pattern", some "path"] [0, 1] :=
    ⟨by simp [NamesWF], rfl, List.Perm.refl _, Or.inr (Or.inr ⟨rfl, by simp⟩)⟩
  have hargs : HasTypesQ D B opPrim Q [] [] Γ R
      (.cons (.literal (.string "/data/**")) (.cons (.literal (.string "/data/a.txt")) .nil))
      (sourceTypes [.base .string, .base .string] [0, 1]) (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) :=
    .cons .E_Literal (.cons .E_Literal .nil)
  exact HasTypeQ.E_Call hp hok hargs (by
    simp [SingleEff, SingleFail, SingleTys, Eff.union, Eff.norm, Eff.empty, Eff.fails])

/-- `f(path: p)` の型付け。効果は `f` の宣言の上限 `{File.Write["/data/**"]}` と空の効果の和である。 -/
theorem callFE_typed {view : CoverageView} {Q : NoFailCtx} {Δ : BuilderCtx} {Γ : List (Option Ty)} {R : Option Ty} {p : Position}
    {i : Nat} (hΓ : Γ[i]? = some (some pathTy)) :
    HasTypeQ (program.declarationsFor view) B opPrim Q Δ [] Γ R p (callFE i) (.base .unit)
      (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty Eff.empty) bodyData)) := by
  have hfn : fnTy fDef.toFunDecl.names fDef.toFunDecl.params fDef.toFunDecl.ret fDef.toFunDecl.eff [] [] =
      .fn ["path"] [pathTy] (.base .unit) bodyData := by
    rw [fnTy_eq]
    simp [fDef, unitDecl, Ty.subst, Ty.substAt, substAt_singleAt]
  have hf := HasTypeQ.E_Fun (D := program.declarationsFor view) (B := B) (opPrim := opPrim) (Q := Q) (Δ := Δ)
    (C := []) (Γ := Γ) (R := R) (p := .other) (f := "f") (d := fDef.toFunDecl) (ts := []) (es := [])
    (decl_funs "f" fDef (by simp [defTable]) view) (by simp [NamesWF, fDef, unitDecl])
    (by simp [NamesWF, fDef, unitDecl, FunDecl.coreNames, FunDecl.dictTys, internalNames])
    ⟨rfl, by intro i t tp hi _; simp at hi⟩ rfl rfl
    (by simpa [fDef, unitDecl, FunDecl.dictTys] using adm_path (Q := Q) dataTree)
    (by rw [hfn]; simp [SingleTy, SingleTys, SingleEff, SingleFail, Eff.singleAt, Eff.ofAtoms, Eff.fails])
  rw [hfn] at hf
  have hok : CallOk ["path"] [pathTy] false [some "path"] [0] :=
    ⟨by simp [NamesWF], rfl, List.Perm.refl _, Or.inr (Or.inr ⟨rfl, by simp⟩)⟩
  exact HasTypeQ.E_Call hf hok (.cons (.E_Local hΓ (by intro b t ε h; cases h)) .nil) (by
    simp [SingleEff, SingleFail, SingleTys, Eff.union, Eff.norm, Eff.empty, Eff.singleAt, Eff.ofAtoms, Eff.fails])

theorem okAlt_ty (view : CoverageView) :
    AltsTy (program.declarationsFor view).patternProgram (Alternative.toCoreList okAlt) checkTy [pathTy] := by
  refine ⟨by simp [okAlt, Alternative.toCoreList], rfl, ?_, ?_⟩
  · intro alt h; simp [okAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h; rfl
  · intro alt h
    simp [okAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h
    refine ⟨[pathTy], ?_, List.Perm.refl _, rfl⟩
    exact .P_Con (cd := okDecl) (by simp [Program.declarations, program, resultCons, Declarations.patternProgram]) rfl
      (by simpa [okDecl, Ty.subst, Ty.substAt, Pattern.toCoreList, Pattern.toCore] using
        (PatTys.cons (P := (program.declarationsFor view).patternProgram) (PatTy.P_Var (a := pathTy)) .nil))

theorem errAlt_ty (view : CoverageView) :
    AltsTy (program.declarationsFor view).patternProgram (Alternative.toCoreList errAlt) checkTy
      [TargetTable.scopeErrorTy] := by
  refine ⟨by simp [errAlt, Alternative.toCoreList], rfl, ?_, ?_⟩
  · intro alt h; simp [errAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h; rfl
  · intro alt h
    simp [errAlt, Alternative.toCoreList, Alternative.toCore] at h; subst h
    refine ⟨[TargetTable.scopeErrorTy], ?_, List.Perm.refl _, rfl⟩
    exact .P_Con (cd := errDecl) (by simp [Program.declarations, program, resultCons, Declarations.patternProgram]) rfl
      (by simpa [errDecl, Ty.subst, Ty.substAt, Pattern.toCoreList, Pattern.toCore, TargetTable.scopeErrorTy,
          Ty.shift_opaque] using
        (PatTys.cons (P := (program.declarationsFor view).patternProgram)
          (PatTy.P_Var (a := TargetTable.scopeErrorTy)) .nil))

noncomputable abbrev armsEff : Eff :=
  Eff.union (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty Eff.empty) bodyData)) (Eff.union Eff.empty Eff.empty)

theorem mainArms_typed (view : CoverageView) {Q : NoFailCtx} {R : Option Ty} :
    HasArmsQ (program.declarationsFor view) B opPrim Q [] [] [] R .tail mainArms checkTy (.base .unit) armsEff :=
  .plain (by simp [Alternative.Valid, okAlt, Pattern.Valid, Pattern.ValidList]) (okAlt_ty view)
    (.B_Last (callFE_typed rfl))
    (.plain (by simp [Alternative.Valid, errAlt, Pattern.Valid, Pattern.ValidList]) (errAlt_ty view)
      (.B_Last .E_Unit) (.nil (by simp [Ty.WF])))

def resultCtors : DataName → List ConName
  | "Result" => ["Ok", "Err"]
  | _ => []

theorem resultCtors_complete (view : CoverageView) :
    CtorsComplete (program.declarationsFor view).patternProgram resultCtors := by
  intro c cd h
  have h' : resultCons c = some cd := h
  simp only [resultCons] at h'
  split at h'
  · cases h'; simp_all [resultCtors, okDecl]
  · split at h'
    · cases h'; simp_all [resultCtors, errDecl]
    · cases h'

/-- 二つの腕 `Ok(p)`・`Err(e)` は `Result[PathIn["/data/a.txt"], Scope.ScopeError]` を網羅する。 -/
theorem mainArms_exhaustive :
    ViewExhaustive (program.declarationsFor closedView) closedView checkTy mainArms.unguardedPatterns :=
  ⟨resultCtors, resultCtors_complete closedView, by decide⟩

theorem qsig_nil (eff : Eff) (h : eff.fails = []) : Qsig [] (.base .unit) eff = Qempty := by
  funext i; apply propext
  cases eff with
  | mk a fs =>
    simp only [Eff.fails] at h
    subst h
    simp [Qsig, QTys, QTy, QEff, Qempty]

/-- main の本体の型付け。検査の呼び出しは純粋で、`Ok` の腕の `f(path: p)` の効果は `f` の上限であり、本体の効果は上限
`{File.Write["/data/**"]}` に `B_Sub` の被覆で含まれる。 -/
theorem main_typed :
    HasBlockQ (program.declarationsFor closedView) B opPrim Qempty [] [] [] (some (.base .unit)) .tail mainBody
      (.base .unit) bodyData := by
  have ce := Eff.covers_empty bodyData
  exact .B_Sub (.B_Last (.E_Match (by simp [mainArms]) checkE_typed (mainArms_typed closedView) mainArms_exhaustive))
    (Ty.Le.refl _)
    ((ce.union (((ce.union (ce.union ce))).union ce)).union
      ((ce.union ((ce.union ce).union (Eff.Covers.refl _))).union (ce.union ce)))
    (by simp [Ty.VarsIn])

/-- 被覆だけで型付く: `f` の本体の効果は、上限に構造上の包含では含まれない。 -/
example : ¬ Eff.Sub (Eff.union Eff.empty (Eff.union (Eff.union Eff.empty (Eff.union Eff.empty Eff.empty)) narrowEff))
    bodyData := fun h => not_sub_narrow ⟨fun a ha => h.1 a ((Eff.mem_union _ _ _).mpr (.inr ha)),
      fun t ht => h.2 t ((Eff.memFail_union _ _ _).mpr (.inr ht))⟩

/-! ## プログラム -/

theorem defTable_cases {f d} (h : defTable f = some d) : d = fDef ∨ d = gDef ∨ d = hDef ∨ d = mainDef := by
  simp only [defTable] at h
  split at h
  · cases h; exact .inl rfl
  · split at h
    · cases h; exact .inr (.inl rfl)
    · split at h
      · cases h; exact .inr (.inr (.inl rfl))
      · split at h
        · cases h; exact .inr (.inr (.inr rfl))
        · cases h

theorem program_wellFormed : program.WellFormed := by
  refine ⟨(fun _ _ h => by cases h), ?_, ?_, (fun _ _ h => by cases h), (fun _ _ _ h => by cases h),
    (fun _ _ h => by cases h), (fun _ _ h => by cases h), (fun _ _ h => by cases h), ?_⟩
  · intro f d h
    rcases defTable_cases h with rfl | rfl | rfl | rfl <;>
      simp [Def.Scoped, fDef, gDef, hDef, mainDef, unitDecl, FunDecl.coreNames, internalNames, FunDecl.dictTys,
        NamesWF, Block.Scoped, Expr.Scoped, Exprs.Scoped, Arms.Scoped, writeE, callGE, checkE, callFE, mainBody,
        mainArms, okAlt, errAlt, Ty.VarsInList, Ty.VarsIn, Eff.VarsIn, Eff.VarsInList, bodyData, narrowEff, dataTree,
        Eff.singleAt, Eff.ofAtoms, Scope.Signature.Ix.WF, Arm.bindersOf, Alternative.toCoreList, Alternative.toCore,
        Pattern.toCore, Pattern.toCoreList, Pat.binders, Pat.bindersList]
  · intro c cd h
    simp only [program, resultCons] at h
    split at h
    · cases h; simp [ConDecl.Scoped, okDecl, Ty.VarsInList, Ty.VarsIn]
    · split at h
      · cases h; simp [ConDecl.Scoped, errDecl, Ty.VarsInList, Ty.VarsIn]
      · cases h
  · intro f c k h
    simp [program] at h

theorem body_typed (view : CoverageView) (d : Def) (hd : d = fDef ∨ d = gDef ∨ d = hDef) :
    HasBlockQ (program.declarationsFor view) B opPrim (Qsig (d.dictTys ++ d.params) d.ret d.eff) [] d.tparams
      (binds (d.dictTys ++ d.params)) (some d.ret) .tail d.body d.ret d.eff := by
  rcases hd with rfl | rfl | rfl
  · change HasBlockQ _ _ _ (Qsig [pathTy] (.base .unit) bodyData) [] [] [some pathTy] _ _ (.lastDiscard (writeE 0)) _ bodyData
    rw [qsig_path _ rfl]
    exact .B_LastDiscard (writeE_bound rfl)
  · change HasBlockQ _ _ _ (Qsig [pathTy] (.base .unit) narrowEff) [] [] [some pathTy] _ _ (.lastDiscard (writeE 0)) _ narrowEff
    rw [qsig_path _ rfl]
    exact .B_LastDiscard (writeE_narrow rfl)
  · change HasBlockQ _ _ _ (Qsig [pathTy] (.base .unit) bodyData) [] [] [some pathTy] _ _ (.lastDiscard (callGE 0)) _ bodyData
    rw [qsig_path _ rfl]
    exact .B_LastDiscard (callGE_bound rfl)

/-- 被覆だけで型付く定義（`f`・`h`）を含むプログラムは、表層の型付けを満たす。 -/
theorem program_wellTyped : program.WellTyped B opPrim := by
  refine ⟨?_, (fun _ _ h => by cases h), (fun _ _ h => by cases h)⟩
  intro f d h
  rcases defTable_cases h with rfl | rfl | rfl | rfl
  · exact ⟨by simp [fDef, unitDecl, NamesWF], Or.inr rfl, body_typed _ _ (.inl rfl)⟩
  · exact ⟨by simp [gDef, unitDecl, NamesWF], Or.inr rfl, body_typed _ _ (.inr (.inl rfl))⟩
  · exact ⟨by simp [hDef, unitDecl, NamesWF], Or.inr rfl, body_typed _ _ (.inr (.inr rfl))⟩
  · refine ⟨by simp [mainDef, NamesWF], Or.inr rfl, ?_⟩
    change HasBlockQ (program.declarationsFor closedView) _ _ (Qsig [] (.base .unit) bodyData) [] [] [] _ _ mainBody _
      bodyData
    rw [qsig_nil _ rfl]
    exact main_typed

theorem program_hasMain : program.HasMain bodyData :=
  ⟨mainDef, by simp [program, defTable], rfl, rfl, rfl, rfl, Or.inl rfl, Eff.Sub.refl _⟩

theorem desugared_hasResult : HasResult (desugarProgram opPrim program) := by
  simp [HasResult, desugarProgram, program, resultCons]

/-- 表層の対象健全性が、被覆だけで型付く定義を含むプログラムに当たる。脱糖したプログラムの `main` の開始状態から
到達したどの IO の事象の観測も、事象の操作の名前の `main` の上限の原子が許す。 -/
theorem program_target_sound {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps (desugarProgram opPrim program) B (.run (.app (.fnRef "main" [] []) []) [] Store.empty) s)
    (hst : Step (desugarProgram opPrim program) B s (some (.io b ws o obs)) s') :
    ∃ e l, B.sig b = some e ∧ e.opEff = some l ∧ ∀ t ∈ obs, B.Allows bodyData l t :=
  surface_target_sound program_wellFormed program_wellTyped
    (assumptions pat tgt (desugarProgram opPrim program) desugared_hasResult).core
    (assumptions pat tgt (desugarProgram opPrim program) desugared_hasResult).target
    program_hasMain hsteps hst

/-! ## main から書き込みの事象への到達（RV-L50 中1）

`program_target_sound` の前提（開始状態からの到達と IO の事象を伴う遷移）が満たせることを、遷移を計算する関数 `step`
（`Release.step`）で確かめる。応答の関数 `oracle` は表の応答の関係の一つを選び（書き込みは `Ok(())`、観測は最初の引数の
対象）、`fresh` は有限なストアの空いた場所を選ぶ。`step_sound` が `step` の遷移を遷移の関係の遷移へ移し、保存の定理が
状態の型付けを保つ。 -/

/-- 脱糖したプログラム。 -/
noncomputable abbrev coreProgram : Release.Program := desugarProgram opPrim program

/-- 開始状態 `main[;]()`。 -/
def start : State := .run (.app (.fnRef "main" [] []) []) [] Store.empty

/-- 表の応答の関係の一つを選ぶ応答の関数。 -/
def oracle : Oracle := fun b _ _ ws =>
  if b = "print" then (.val (.const .unit), [])
  else if b = "exit" then (.exit (exitCode ws), [])
  else if b = "File.readText" then (.val (.con "Ok" readTys [.const (.string "")]), readObs tgt ws)
  else (.val (.con "Ok" writeTys [.const .unit]), firstTarget ws)

/-- 解放の応答（この表の解放の応答は常に `none`）。 -/
def rel : Val → Option ErrKind := fun _ => none

open Classical in
/-- 有限なストアの空いた場所を選ぶ。 -/
noncomputable def fresh (σ : Store) : Nat :=
  if h : ∃ n, ∀ l, n ≤ l → σ l = none then Classical.choose h else 0

theorem oracle_ok : ∀ b ts es ws o obs, B.ioResponse b ts es ws o obs →
    B.ioResponse b ts es ws (oracle b ts es ws).1 (oracle b ts es ws).2 := by
  intro b ts es ws o obs h
  simp only [B, builtins] at h ⊢
  rcases h with ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩ | ⟨rfl, -, -⟩
  · exact .inl ⟨rfl, by simp [oracle], by simp [oracle]⟩
  · exact .inr (.inl ⟨rfl, by simp [oracle], by simp [oracle]⟩)
  · exact .inr (.inr (.inl ⟨rfl, .inl (by simp [oracle]), by simp [oracle]⟩))
  · exact .inr (.inr (.inr ⟨rfl, .inl (by simp [oracle]), by simp [oracle]⟩))

theorem rel_ok : ∀ v r, B.releaseResponse v r → B.releaseResponse v (rel v) := fun _ _ _ => rfl

theorem fresh_ok : ∀ σ : Store, (∃ n, ∀ l, n ≤ l → σ l = none) → σ (fresh σ) = none := by
  intro σ h
  unfold fresh
  simp only [h, dite_true]
  exact Classical.choose_spec h _ (Nat.le_refl _)

/-- `step` を、事象のない遷移だけ n 回まで続ける。 -/
noncomputable def silent : Nat → State → State
  | 0, s => s
  | n + 1, s =>
    match step coreProgram B oracle rel fresh s with
    | some (none, s') => silent n s'
    | _ => s

theorem core_typed : coreProgram.WellFormed ∧ coreProgram.WellTyped B ∧ coreProgram.EffectsOk B :=
  desugar_typed program_wellFormed program_wellTyped
    (assumptions pat tgt coreProgram desugared_hasResult).core.sig_scoped

theorem core_assumptions : B.CoreAssumptions coreProgram := (assumptions pat tgt coreProgram desugared_hasResult).core

/-- 型の付いた状態から `silent` が返す状態へは遷移の関係で到達し、その状態も型が付く。 -/
theorem silent_steps : ∀ n s, StateTy coreProgram B s →
    Steps coreProgram B s (silent n s) ∧ StateTy coreProgram B (silent n s)
  | 0, s, h => ⟨.refl, h⟩
  | n + 1, s, h => by
    simp only [silent]
    split
    · next s' heq =>
        have hst := step_sound core_assumptions oracle rel fresh oracle_ok rel_ok fresh_ok h heq
        obtain ⟨hs, ht⟩ := silent_steps n s' (preservation core_typed.1 core_typed.2.1 core_typed.2.2
          core_assumptions h hst)
        exact ⟨.step hst hs, ht⟩
    · exact ⟨.refl, h⟩

/-- 開始状態は型が付く（末尾は main の上限 `{File.Write["/data/**"]}`）。 -/
theorem start_stateTy : StateTy coreProgram B start := by
  obtain ⟨d, a, hd, -, hm⟩ := main_typed_eff (B := B) (op := opPrim) program_wellFormed program_hasMain
  have hd' : d = mainDef := by simpa [program, defTable] using hd.symm
  subst hd'
  have h := stateTyE_init_eff core_typed.1 core_assumptions hm
    (by simp [Comp.ClosedNoEffVars, Comp.VarsIn, Val.VarsIn, Ty.VarsInList, Eff.VarsInList, Val.VarsInList])
  rw [show mainDef.eff = bodyData from rfl, substAt_singleAt] at h
  exact stateTy_iff.mpr ⟨_, builtinOnly_write rfl dataTree, h⟩

/-- 18 回の事象のない遷移の後の `step` は、`File.writeTextIn` の事象を観測 `[/data/a.txt]` で返す（カーネルで評価する）。 -/
theorem write_after_silent :
    (match step coreProgram B oracle rel fresh (silent 18 start) with
      | some (some (.io b _ _ obs), _) => decide (b = "File.writeTextIn") && decide (obs = [target])
      | _ => false) = true := by
  decide

/-- 開始状態 `main[;]()` から到達した状態で、`File.writeTextIn` の事象（観測 `[/data/a.txt]`）を伴う遷移ができる。
`program_target_sound` の前提は満たせる。 -/
theorem main_reach : ∃ s ws o s', Steps coreProgram B start s ∧
    Step coreProgram B s (some (.io "File.writeTextIn" ws o [target])) s' := by
  obtain ⟨hs, ht⟩ := silent_steps 18 start start_stateTy
  have hc := write_after_silent
  split at hc
  · next b ws o obs s' heq =>
      simp only [Bool.and_eq_true, decide_eq_true_eq] at hc
      obtain ⟨rfl, rfl⟩ := hc
      exact ⟨_, ws, o, s', hs, step_sound core_assumptions oracle rel fresh oracle_ok rel_ok fresh_ok ht heq⟩
  · cases hc

/-- 到達した書き込みの事象の観測 `/data/a.txt` は、main の上限 `{File.Write["/data/**"]}` が許す（`surface_target_sound`
から導く）。 -/
theorem main_reach_allowed : ∀ t ∈ [target], B.Allows bodyData "File.Write" t := by
  obtain ⟨s, ws, o, s', hs, hst⟩ := main_reach
  obtain ⟨e, l, he, hl, h⟩ := program_target_sound hs hst
  rw [sig_write] at he
  cases he
  cases hl
  exact h

/-- `/etc/passwd`。 -/
def passwd : Target := .path ["etc", "passwd"]

/-- 上限 `{File.Write["/data/**"]}` は、どの操作の名前でも `/etc/passwd` を許さない。 -/
theorem passwd_not_allowed (l : EffName) : ¬ B.Allows bodyData l passwd := by
  rintro ⟨k, r, -, hm, hk⟩
  rw [Eff.mem_singleAt] at hm
  cases hm
  exact absurd hk.2 (by decide)

/-- 開始状態 `main[;]()` から到達したどの IO の事象の観測にも `/etc/passwd` は現れない（`surface_target_sound` から導く）。 -/
theorem main_never_passwd {s s' : State} {b : PrimName} {ws : List Val} {o : Outcome} {obs : List Target}
    (hsteps : Steps coreProgram B start s) (hst : Step coreProgram B s (some (.io b ws o obs)) s') : passwd ∉ obs := by
  obtain ⟨e, l, -, -, h⟩ := program_target_sound hsteps hst
  exact fun hm => passwd_not_allowed l (h passwd hm)

end Benitoite.Surface.CoverExamples
