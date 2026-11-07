import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.Surface.CheckDeclarations

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

/-! ## 行多相の関数・部分適用・ラムダ・合流 -/

private def failString : Eff := .mk (fun _ => false) [strTy]
private def failInt : Eff := .mk (fun _ => false) [intTy]
private def emptyEff : Eff := .mk (fun _ => false) []
private def row0 : Eff := .mk (fun a => a == .rho 0) []
private def rows : Eff := .mk (fun a => a == .rho 0 || a == .rho 1) []

private def funDecl (neffs : Nat) (names : List String) (params : List Ty) (eff : Eff) : FunDecl where
  tparams := []
  neffs := neffs
  names := names
  params := params
  ret := intTy
  eff := eff

/-- 二つの無制約の行・一つの行・固定の Fail と併記した行・高階の行を持つ関数の宣言。 -/
private def rowDeclarations : Declarations where
  funs := fun n =>
    if n = "Other.twoRows" then some (funDecl 2 [] [] rows)
    else if n = "Other.oneRow" then some (funDecl 1 ["value"] [intTy] row0)
    else if n = "Other.fixed" then some (funDecl 1 [] [] (.mk (fun a => a == .rho 0) [strTy]))
    else if n = "Other.apply" then some (funDecl 1 ["body"] [.fn [] [] intTy row0] row0)
    else none
  cons := fun _ => none

private def rowInput : Check.Input where
  D := rowDeclarations
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [.name "IO" (.fixed .top), .rho 0, .rho 1], ctors := fun _ => [] }
  satDec := fun _ _ _ => true
  proofSteps := 10

/-- 行多相の宣言の表で検査が成功するか。 -/
private def accepts (e : Expr) : Bool :=
  match Check.checkExpr rowInput [] [] [] none .other [] e with
  | .ok _ => true
  | .error _ => false

/-- 検査の成功の効果の失敗の型の列（行多相の宣言の表）。 -/
private def rowFailsOf (e : Expr) : Option (List Ty) :=
  match Check.checkExpr rowInput [] [] [] none .other [] e with
  | .ok (_, ε) => some ε.fails
  | .error _ => none

private def call0 (f : Expr) : Expr := .call f [] [] .nil

/-- 同じ型を raise し直しても、節の Fail を捕捉済みとして除かない。予約した0番は値として持ち出せない。 -/
theorem reraise_kept :
    failsOf (.handleFail strTy intTy (.last raised) (.last (raiseAt intTy strTy (.local 1)))) = some [strTy] ∧
    failsOf (.handleFail strTy intTy (.last raised) (.last (.local 0))) = none := by
  constructor <;> cbv

/-- 通常の節の列は Fail を受け入れず、普通の節との混在も型付けできない。 -/
theorem ordinary_clauses_rejected :
    failsOf (.handleE (.last raised)
      (.cons .fail 1 1 (.last value) (.cons (.user "other") 0 0 (.last value) .nil))) = none := by
  cbv

/-- 異なる Fail を二つの無制約の行へ渡す具体化は、呼出しの前でも拒否する。同じ型の Fail の重複と Fail を持たない行多相は
受理する。 -/
theorem two_rows :
    accepts (.funName "Other.twoRows" [] [failString, failInt]) = false ∧
    accepts (call0 (.funName "Other.twoRows" [] [failString, failInt])) = false ∧
    accepts (.funName "Other.twoRows" [] [failString, failString]) = true ∧
    accepts (.funName "Other.twoRows" [] [row0, .mk (fun a => a == .rho 1) []]) = true := by
  refine ⟨?_, ?_, ?_, ?_⟩ <;> cbv

/-- 固定の Fail と併記した行へ Fail を渡せない（NoFail の文脈は署名に由来する）。 -/
theorem fixed_row :
    accepts (.funName "Other.fixed" [] [failInt]) = false ∧ accepts (.funName "Other.fixed" [] [emptyEff]) = true := by
  constructor <;> cbv

/-- 部分適用と、持ち出したラムダでも潜在効果を失わない。合流の一方の Fail だけを残す結果は拒否する。 -/
theorem latent_failures :
    accepts (.partialCall (.funName "Other.oneRow" [] [failString]) ["value"]
      (.hole (some "value") 0 intTy .nil) intTy failString) = true ∧
    accepts (.lam [] [] intTy failString (.last (.returnE intTy raised))) = true ∧
    accepts (.ite (.literal (.boolean true)) (.last raised) (.last (raiseAt intTy intTy value))) = false := by
  refine ⟨?_, ?_, ?_⟩ <;> cbv

private def failingLambda : Expr := .lam [] [] intTy failString (.last (.returnE intTy raised))
private def higherCall : Expr := .call (.funName "Other.apply" [] [failString]) [none] [0] (.cons failingLambda .nil)

/-- 高階の行は呼出しで Fail を保持し、外側の捕捉でだけ除く。 -/
theorem higher_order :
    rowFailsOf higherCall = some [strTy] ∧
    rowFailsOf (.handleFail strTy intTy (.last higherCall) (.last value)) = some [] := by
  constructor <;> cbv

/-- 関数型の結びでも潜在効果の Fail を比べる。 -/
theorem join_latent :
    accepts (.ite (.literal (.boolean true)) (.last (.funName "Other.oneRow" [] [failString]))
      (.last (.funName "Other.oneRow" [] [failInt]))) = false := by
  cbv

/-! ## 本体の NoFail・型の束縛の漏れ・通常の効果・制約のないエラー値 -/

private def arbitraryDecl : FunDecl where
  tparams := [TypeCtx.valueParam]
  neffs := 0
  names := []
  params := []
  ret := .tvar 0
  eff := emptyEff

private def moreInput : Check.Input :=
  { rowInput with D := { rowDeclarations with
      funs := fun n => if n = "Other.arbitrary" then some arbitraryDecl else rowDeclarations.funs n } }

private def acceptsIn (Γ : Ctx) (e : Expr) : Bool :=
  match Check.checkExpr moreInput [] Γ [] none .other [] e with
  | .ok _ => true
  | .error _ => false

/-- 本体だけが NoFail を要る署名（Fail を持たない行の宣言）で、固定の Fail を持つ関数を呼ぶ定義は拒否し、宣言の効果に
同じ Fail を持たせれば受理する。 -/
private def callsFixed (eff : Eff) : Def where
  tparams := []
  neffs := 1
  names := []
  params := []
  ret := intTy
  eff := eff
  body := .last (.returnE intTy (call0 (.funName "Other.fixed" [] [row0])))

theorem body_noFail :
    (CheckDeclarations.checkDef moreInput [] (callsFixed row0)).toBool = false ∧
    (CheckDeclarations.checkDef moreInput [] (callsFixed (.mk (fun a => a == .rho 0) [strTy]))).toBool = true := by
  constructor <;> cbv

/-- 型の束縛 T を Fail のエラー型にして節の外へ漏らす handle は拒否する。 -/
theorem rigid_leak_rejected :
    acceptsIn [] (.handleFail strTy intTy (.last raised)
      (.last (raiseAt intTy (.tvar 0) (call0 (.funName "Other.arbitrary" [.tvar 0] []))))) = false := by
  cbv

/-- 通常の効果は捕捉の後にも残る。 -/
theorem ordinary_effect_kept :
    (match Check.checkExpr moreInput [] [] [] none .other []
        (.handleFail strTy intTy
          (.last (call0 (.funName "Other.twoRows" [] [failString, .mk (fun a => a == .name "IO" (.fixed .top)) []])))
          (.last value)) with
      | .ok (_, ε) => some (ε.fails, ε.test (.name "IO" (.fixed .top)))
      | .error _ => none) = some ([], true) := by
  cbv

private def escapedTy : Ty := .fn [] [] strTy emptyEff

/-- Show や等値の制約を持たないエラー値も捕捉でき、節から持ち出すラムダはエラー値を捕え、利用不能な継続に触れない。
コレクションの中の関数型の潜在効果も単一の Fail を検査する。 -/
theorem unconstrained_errors :
    acceptsIn [some (.opaque "Secret" .top)]
      (.handleFail (.opaque "Secret" .top) intTy (.last (raiseAt intTy (.opaque "Secret" .top) (.local 0)))
        (.last value)) = true ∧
    acceptsIn [] (.handleFail strTy escapedTy (.last (raiseAt escapedTy strTy (.literal (.string "bad"))))
      (.last (.lam [] [] strTy emptyEff (.last (.returnE strTy (.local 1)))))) = true ∧
    acceptsIn [some (.list (.fn [] [] intTy (.mk (fun _ => false) [strTy, intTy])))] (.local 0) = false := by
  refine ⟨?_, ?_, ?_⟩ <;> cbv

end Benitoite.Release.Refinement.Surface.FailureExamples
