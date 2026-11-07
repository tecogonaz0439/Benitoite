import Benitoite.Release.Refinement.Surface.CheckOpenStandardExamples
import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckAcceptedRanges

/-! # 範囲変数を転送する関数の型付けと必須の判定の受理 -/
namespace Benitoite.Release.Refinement.Surface.OpenScopeExamples
open Check CheckAccept OpenScopeAccept RangeFunctionExamples Scope.Domain
noncomputable section

private inductive Forward where
  | pathWiden | requestWiden

private def Forward.rule : Forward → OpenScopeAccept.Rule
  | .pathWiden => .pathWiden
  | .requestWiden => .requestWiden

private def pathDef : Def where
  tparams := []
  neffs := 0
  names := ["path"]
  params := [.opaque "Scope.PathIn" (.rvar 0)]
  ret := .opaque "Scope.PathIn" (.rvar 0)
  eff := Eff.empty
  rangeParams := [.path]
  body := .last (.call (.primName "Scope.widenPathIn" [] [] [.rvar 0, .rvar 0])
    [none] [0] (.cons (.local 0) .nil))

private def functionName (rule : Forward) : String :=
  match rule with | .pathWiden => "path_forward" | .requestWiden => "endpoint_forward"

private def definition (rule : Forward) : Def :=
  match rule with | .pathWiden => pathDef | .requestWiden => endpointDef

private def program (rule : Forward) : Program where
  defs := fun name => if name = functionName rule then some (definition rule) else none
  cons := fun _ => none

private def input (rule : Forward) : Check.Input where
  D := (program rule).declarations
  builtinSource := .standard (program rule).declarations.core
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  satDec := fun _ _ _ => false
  admitsDec := fun b _ ts => decide (b = rule.rule.name ∧ ts = [])
  admitsRDec := fun _ _ => false
  proofSteps := 10
  defs := [functionName rule]

private def provenanceWidenRule : Benitoite.Scope.Inference.ScopeRule Refinement.Val where
  index := fun args => [match args with
    | [.loc _ (some (.checked origin _))] => origin.bound.index
    | [.value (.checked origin _)] => origin.bound.index
    | _ => .top]
  run := fun _ values => values.head?
  transfer := fun _ _ => none

private def required : CheckAccept.AcceptInput where
  ok := "Ok"
  rules := fun name => if name = "Scope.widenPathIn" ∨ name = "Http.widenRequestIn"
    then some provenanceWidenRule else none
  limits := ⟨⟨100, 100⟩, ⟨100, 100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

private theorem path_lookup (P : Refinement.Program) :
    (StandardModel.builtins P).sig "Scope.widenPathIn" = some ScopeSignatures.widenPathIn := by
  rfl

attribute [local cbv_opaque] StandardModel.builtins
attribute [local cbv_eval] endpoint_lookup path_lookup

/-- 登録した全規則は、標準表の位置0の入力型が保持する範囲をそのまま読む。 -/
theorem standard_registered_sources (P : Refinement.Program) (rule : OpenScopeAccept.Rule) :
    ∃ s a, (StandardModel.builtins P).sig rule.name = some s ∧ s.params[0]? = some a ∧
      sourceRange rule a = some (.rvar 0) := by
  cases rule <;> exact ⟨_, _, rfl, rfl, rfl⟩

/-- endpoint とpathの範囲変数の転送は、型付けと必須の判定を含む実入口で受理される。 -/
theorem source_entry_forward :
    checkProgramAccepted (input .requestWiden) required (program .requestWiden) = .ok () ∧
    checkProgramAccepted (input .pathWiden) required (program .pathWiden) = .ok () := by
  constructor <;> cbv

/-- 由来だけを読む入口では、開いた契約を既知の絶対範囲としては受理しない。 -/
theorem provenance_only_unknown :
    ScopeAccept.acceptBody required.ok
      (tableFor required (bodyKey "endpoint_forward") endpointDef.body) required.limits
      (bodyKey "endpoint_forward") (entryScope 1) endpointDef.body =
        .error (bodyKey "endpoint_forward", .unknownSource) ∧
    ScopeAccept.acceptBody required.ok
      (tableFor required (bodyKey "path_forward") pathDef.body) required.limits
      (bodyKey "path_forward") (entryScope 1) pathDef.body =
        .error (bodyKey "path_forward", .unknownSource) := by
  exact ⟨rfl, rfl⟩

private def differentDefinition (rule : Forward) : Def :=
  { definition rule with
    rangeParams := [rule.rule.kind, rule.rule.kind]
    body := .last (.call (.primName rule.rule.name [] [] [.rvar 1, .rvar 1])
      [none] [0] (.cons (.local 0) .nil)) }

/-- 宣言の入力型にある範囲と異なる変数を選ぶ転送は、定義の受理でも拒否する。 -/
theorem different_source_rejected :
    acceptDef required "endpoint_forward" (differentDefinition .requestWiden) =
      .error (bodyKey "endpoint_forward", .unknownSource) ∧
    acceptDef required "path_forward" (differentDefinition .pathWiden) =
      .error (bodyKey "path_forward", .unknownSource) := by
  exact ⟨rfl, rfl⟩

private def differentProgram (rule : Forward) : Program where
  defs := fun name => if name = functionName rule then some (differentDefinition rule) else none
  cons := fun _ => none

private def differentInput (rule : Forward) : Check.Input :=
  { input rule with D := (differentProgram rule).declarations }

/-- 同じ宣言の形で、入力型と呼出しに異なる範囲変数を渡すプログラムは実入口でも受理されない。 -/
theorem different_entry_rejected :
    (match checkProgramAccepted (differentInput .requestWiden) required (differentProgram .requestWiden) with
      | .error (.typing error) => error.kind = .rejected
      | _ => False) ∧
    (match checkProgramAccepted (differentInput .pathWiden) required (differentProgram .pathWiden) with
      | .error (.typing error) => error.kind = .rejected
      | _ => False) := by
  constructor <;> cbv

private theorem names_complete (rule : Forward) :
    CheckAccept.NamesComplete (input rule) (program rule) := by
  refine ⟨?_, ?_, ?_⟩
  · intro n d hd
    change (if n = functionName rule then some (definition rule) else none) = some d at hd
    split at hd
    · simp only [input, ‹n = functionName rule›, List.mem_singleton]
    · cases hd
  · intro i id hi
    cases hi
  · intro i id hi
    cases hi

/-- 全定義の受理から、選択した開いた規則の全具体化の契約を得る。 -/
theorem forward_ranges :
    DefinitionRanges required "endpoint_forward" endpointDef ∧
    DefinitionRanges required "path_forward" pathDef := by
  constructor
  · have ha := (checkProgramAccepted_ok source_entry_forward.1).2
    exact (acceptProgram_sound (names_complete .requestWiden) ha).def_ranges (by rfl)
  · have ha := (checkProgramAccepted_ok source_entry_forward.2).2
    exact (acceptProgram_sound (names_complete .pathWiden) ha).def_ranges (by rfl)

private theorem pair_fits (k : Kind) (r s : RangeExpr)
    (hr : r.FitsKind k ∧ r.WF ∧ r.Canonical)
    (hs : s.FitsKind k ∧ s.WF ∧ s.Canonical) : RangesFit [r, s] [k, k] := by
  refine ⟨rfl, ?_, ?_⟩
  · intro i t kind ht hk
    cases i with
    | zero => cases ht; cases hk; exact hr.1
    | succ i =>
      cases i with
      | zero => cases ht; cases hk; exact hs.1
      | succ i => simp at ht
  · intro t ht
    rcases List.mem_cons.mp ht with rfl | ht
    · exact hr.2
    · rcases List.mem_cons.mp ht with rfl | ht
      · exact hs.2
      · cases ht

/-- 異なる変数は、適格な具体化でも一方がTop、他方が狭い範囲になり、被覆を満たさない。 -/
theorem different_variables_counterexamples :
    (∃ rs, RangesFit rs [.path, .path] ∧ close rs (.rvar 0) = some .top ∧
      ∃ r, close rs (.rvar 1) = some r ∧ ¬ r.Covers .top) ∧
    (∃ rs, RangesFit rs [.endpoint, .endpoint] ∧ close rs (.rvar 0) = some .top ∧
      ∃ r, close rs (.rvar 1) = some r ∧ ¬ r.Covers .top) := by
  constructor
  · let r : RangeExpr := .path (.exact ["a"])
    exact ⟨[.top, r], pair_fits .path .top r (by decide) (by decide), rfl, r, rfl, by decide⟩
  · let r : RangeExpr := .endpoint ⟨.name (.exact ["a"]), ⟨443, 443⟩⟩
    exact ⟨[.top, r], pair_fits .endpoint .top r (by decide) (by decide), rfl, r, rfl, by decide⟩

/-- 選んだ範囲位置の契約がないときは、被覆の証人を失うため受理しない。 -/
theorem missing_contract_rejected :
    acceptSelection [.path] ⟨.rvar 0, []⟩ = .error .notCovered := rfl

end
end Benitoite.Release.Refinement.Surface.OpenScopeExamples
