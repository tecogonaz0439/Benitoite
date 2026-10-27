import Benitoite.Interval.CallReachIndependent
import Benitoite.Interval.BudgetWhole

/-!
# 検査全体に保存された本体と独立入力の call の認定

全体上限・入口作成・発見・待ち行列の停止後にも、実際に保存した出力の保証を保つ。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetWhole
open Benitoite.Surface Benitoite.Release Budget BudgetAnalysis

def BodyOutput.CallsRecognized (body : BodyOutput) : Prop :=
  (∀ warning ∈ body.output.approx.warnings,
    (CallReach.expr body.seed.initial (bodyRoot body.seed.body)).allows
      (bodyRootKey body.definition) warning) ∧
  ∀ entry ∈ body.output.context.independentRev, entry.CallsRecognized

theorem runBody_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) :
    (runBody limits state fuel definition seed).CallsRecognized :=
  ⟨analyzeBody_warning_call_reach limits state fuel definition seed,
    analyzeBody_independent_call_reach limits state fuel definition seed⟩

theorem runEntries_call_reach (limits : Limits) (fuel : Nat) (entries : List BudgetDiscovery.Entry)
    (state : Budget.State) (outputsRev : List BodyOutput)
    (before : ∀ body ∈ outputsRev, body.CallsRecognized) :
    ∀ body ∈ (runEntries limits fuel entries state outputsRev).bodiesRev, body.CallsRecognized := by
  induction entries generalizing state outputsRev with
  | nil => exact before
  | cons entry rest ih =>
    rw [runEntries.eq_def]
    dsimp only
    split
    · exact before
    · split
      · exact before
      · split
        · exact before
        · apply ih
          intro body member
          rcases List.mem_cons.mp member with same | old
          · subst body; exact runBody_call_reach _ _ _ _ _
          · exact before body old

def DefinitionOutput.CallsRecognized (output : DefinitionOutput) : Prop :=
  (∀ body ∈ output.root.toList, body.CallsRecognized) ∧
  ∀ body ∈ output.embedded.bodiesRev, body.CallsRecognized

theorem runDefinition_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat) (input : Definition) :
    (runDefinition limits state fuel input).CallsRecognized := by
  unfold runDefinition
  cases prepared : prepareRoot input limits { budget := state, next := bodyRootKey input.name } with
  | mk result ready =>
    cases result with
    | error reason => simp [DefinitionOutput.CallsRecognized]
    | ok seed =>
      dsimp only
      split
      · exact ⟨by simpa using runBody_call_reach limits ready.budget fuel input.name seed, by simp⟩
      · split
        · exact ⟨by simpa using runBody_call_reach limits ready.budget fuel input.name seed, by simp⟩
        · split
          split
          · exact ⟨by simpa using runBody_call_reach limits ready.budget fuel input.name seed, by simp⟩
          · refine ⟨by simpa using runBody_call_reach limits ready.budget fuel input.name seed, ?_⟩
            exact runEntries_call_reach _ _ _ _ _ (by simp)

theorem definitions_call_reach (limits : Limits) (fuel : Nat) (inputs : List Definition) (report : Report)
    (before : ∀ output ∈ report.definitionsRev, output.CallsRecognized) :
    ∀ output ∈ (definitions limits fuel inputs report).definitionsRev, output.CallsRecognized := by
  induction inputs generalizing report with
  | nil => exact before
  | cons input rest ih =>
    rw [definitions.eq_def]
    dsimp only
    split
    · exact before
    · split
      · exact before
      · apply ih
        intro output member
        rcases List.mem_cons.mp member with same | old
        · subst output; exact runDefinition_call_reach _ _ _ _
        · exact before output old

theorem modules_call_reach (limits : Limits) (fuel : Nat) (inputs : List Module) (report : Report)
    (before : ∀ output ∈ report.definitionsRev, output.CallsRecognized) :
    ∀ output ∈ (modules limits fuel inputs report).definitionsRev, output.CallsRecognized := by
  induction inputs generalizing report with
  | nil => exact before
  | cons input rest ih =>
    rw [modules.eq_def]
    dsimp only
    split
    · exact before
    · split
      · exact before
      · rename_i value ready equation
        have saved := definitions_call_reach limits fuel input.definitions
          { report with after := finishBody ready } before
        split
        · exact saved
        · exact ih _ saved

/-- 全体入口が返した全本体について、親の警告と保存した独立入力の両方を保証する。 -/
theorem analyze_warning_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (inputs : List Module) :
    ∀ body ∈ bodyOutputs (analyze limits state fuel inputs), body.CallsRecognized := by
  intro body member
  obtain ⟨output, saved, member⟩ := List.mem_flatMap.mp member
  have good := modules_call_reach limits fuel inputs { after := state } (by simp)
    output (List.mem_reverse.mp saved)
  rcases List.mem_append.mp member with root | embedded
  · exact good.1 body root
  · exact good.2 body (List.mem_reverse.mp embedded)

end Benitoite.Interval.BudgetWhole
