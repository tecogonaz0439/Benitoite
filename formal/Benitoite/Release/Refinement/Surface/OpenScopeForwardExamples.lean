import Benitoite.Release.Refinement.Surface.OpenScopeExamples

/-! # パラメータの範囲を転送する文列の実入口の例 -/
namespace Benitoite.Release.Refinement.Surface.OpenScopeForwardExamples
open Check CheckAccept OpenScopeAccept Scope.Domain
noncomputable section

inductive Form where
  | direct | prefix | boundResult | blockEnd | write
  deriving DecidableEq

private def call (form : Form) (contract : RangeIx) (offset : Nat) : Expr :=
  if form = .write then
    .call (.primName "File.writeTextIn" [] [] [contract]) [some "text", some "path"] [1,0]
      (.cons (.local offset) (.cons (.local (offset+1)) .nil))
  else .call (.primName "Scope.widenPathIn" [] [] [contract,contract]) [none] [0]
    (.cons (.local offset) .nil)

private def body (form : Form) (contract : RangeIx) : Block :=
  match form with
  | .direct => .last (call form contract 0)
  | .prefix => .bind .bind (.base .unit) .unit (.last (call form contract 1))
  | .boundResult => .bind .bind (.opaque "Scope.PathIn" contract) (call form contract 0) (.last (.local 0))
  | .blockEnd => .last (.block (.last (call form contract 0)))
  | .write => .lastDiscard (call form contract 0)

private def definition (form : Form) (closed wrong : Bool) : Def :=
  let source : RangeIx := if closed then .fixed (.path (.exact ["a"])) else .rvar 0
  let target : RangeIx := if wrong then .rvar 1 else source
  { tparams := [], neffs := 0,
    names := if form = .write then ["path","text"] else ["path"],
    params := if form = .write then [.opaque "Scope.PathIn" source, .base .string]
      else [.opaque "Scope.PathIn" source],
    ret := if form = .write then .base .unit else .opaque "Scope.PathIn" source,
    eff := if form = .write then .mk (fun a => decide (a = .name "File.Write" source)) [] else Eff.empty,
    rangeParams := if closed then [] else [.path,.path],
    body := body form target }

private def program (form : Form) (closed wrong : Bool) : Program where
  defs := fun name => if name = "forward" then some (definition form closed wrong) else none
  cons := fun name => if name = "Ok" then some ⟨"Result", 2, [.tvar 1]⟩
    else if name = "Error" then some ⟨"Result", 2, [.tvar 0]⟩ else none

private def input (form : Form) (closed wrong : Bool) : Check.Input where
  D := (program form closed wrong).declarations
  builtinSource := .standard (program form closed wrong).declarations.core
  opPrim := fun _ _ => none
  formation := {
    atoms := [.name "File.Write" (.rvar 0), .name "File.Write" (.rvar 1),
      .name "File.Write" (.fixed (.path (.exact ["a"])))],
    ctors := fun name => if name = "Result" then ["Ok","Error"] else [] }
  admitsDec := fun name _ types =>
    decide ((name = "Scope.widenPathIn" ∨ name = "File.writeTextIn") ∧ types = [])
  admitsRDec := fun name ranges => decide (
    (name = "Scope.widenPathIn" ∧ ranges = [.path (.exact ["a"]), .path (.exact ["a"])]) ∨
    (name = "File.writeTextIn" ∧ ranges = [.path (.exact ["a"])]))
  proofSteps := 40
  defs := ["forward"]
  ctorNames := ["Ok","Error"]

private def sourceRule : Benitoite.Scope.Inference.ScopeRule Refinement.Val where
  index := fun args => [match args.head? with
    | some (.loc _ (some (.checked origin _))) => origin.bound.index
    | some (.value (.checked origin _)) => origin.bound.index
    | _ => .top]
  run := fun _ values => values.head?
  transfer := fun _ _ => none

private def required : AcceptInput where
  ok := "Ok"
  rules := fun name => if name = "Scope.widenPathIn" ∨ name = "File.writeTextIn" then some sourceRule else none
  limits := ⟨⟨100,100⟩,⟨100,100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

private theorem widen_lookup (P : Refinement.Program) :
    (StandardModel.builtins P).sig "Scope.widenPathIn" = some ScopeSignatures.widenPathIn := rfl
private theorem write_lookup (P : Refinement.Program) :
    (StandardModel.builtins P).sig "File.writeTextIn" = some ScopeSignatures.writeTextIn := rfl
attribute [local cbv_opaque] StandardModel.builtins
attribute [local cbv_eval] widen_lookup write_lookup

/-- 直接・前置きの束縛・結果の束縛・ブロックの末尾・書き込みは、同じ実入口で受理する。 -/
theorem open_entry (form : Form) :
    checkProgramAccepted (input form false false) required (program form false false) = .ok () := by
  cases form <;> cbv

/-- 閉じた例の許容判定は、合成表が実際に持つ範囲の規則を満たす。 -/
theorem range_decision_sound (form : Form) (closed wrong : Bool) :
    CheckArguments.RangeAdmitsSound (input form closed wrong).B (input form closed wrong).admitsRDec := by
  intro name ranges accepted
  have actual :
      (name = "Scope.widenPathIn" ∧ ranges = [.path (.exact ["a"]), .path (.exact ["a"])]) ∨
      (name = "File.writeTextIn" ∧ ranges = [.path (.exact ["a"])]) := of_decide_eq_true accepted
  rcases actual with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · change ScopeSignatures.admitsR "Scope.widenPathIn" _
    exact ⟨_, _, rfl, .refl _⟩
  · change ScopeSignatures.admitsR "File.writeTextIn" _
    exact ⟨by simp, rfl⟩

/-- 範囲パラメータのない同じ転送も、合成表の実際の署名と許容判定で受理する。 -/
theorem closed_entry (form : Form) :
    CheckArguments.RangeAdmitsSound (input form true false).B (input form true false).admitsRDec ∧
    checkProgramAccepted (input form true false) required (program form true false) = .ok () := by
  refine ⟨range_decision_sound form true false, ?_⟩
  cases form <;> cbv

/-- 形ごとの受理の段は、元のパラメータと異なる範囲変数を選ぶ契約を拒否する。 -/
theorem different_source (form : Form) :
    match acceptDef required "forward" (definition form false true) with
    | .error (_, .unknownSource) => True
    | _ => False := by
  cases form <;> cbv

/-- 実入口の異なる変数の対照は、型付けの段で拒否される。受理の段の拒否と区別する。 -/
theorem different_entry (form : Form) :
    match checkProgramAccepted (input form false true) required (program form false true) with
    | .error (.typing error) => error.kind = .rejected
    | _ => False := by
  cases form <;> cbv

end
end Benitoite.Release.Refinement.Surface.OpenScopeForwardExamples
