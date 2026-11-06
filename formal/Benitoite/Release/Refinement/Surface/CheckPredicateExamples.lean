import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.Surface.CheckDeclarationsSound
import Benitoite.Release.Refinement.Surface.PredicateRowsResponse
import Benitoite.Release.Refinement.Surface.PredicateCalls

/-! # 判定の結果型から得る条件分岐の事実の実入口の例 -/
namespace Benitoite.Release.Refinement.Surface.CheckPredicateExamples
open PredicateRows PredicateResponse Scope.Domain
noncomputable section

private def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none

private def builtins (entry : Entry) : Builtins where
  sig := fun b => if b = "%Predicate.0" then some entry.signature else none
  delta := fun b ts es rs ws => if b = "%Predicate.0" then entry.delta ts es rs ws else none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "Reference.get"
  refSet := "Reference.set"

private def input (entry : Entry) : Check.Input where
  D := declarations
  builtinSource := .custom (builtins entry)
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  admitsDec := fun _ _ ts => decide (ts = [])
  proofSteps := 200

private theorem signature_support (entry : Entry) :
    CheckArguments.SignatureSupport [] entry.signature.params entry.signature.ret
      entry.signature.eff entry.signature.tel := by
  cases entry <;> try (rename_i w test; cases w using FloatWidth.casesOn <;> cases test)
  all_goals simp [CheckArguments.SignatureSupport, Entry.signature, Entry.input, Entry.result,
    Entry.predicate, agreement, agreementAt, FloatTest.predicate, PrimSig.tel, signatureTel,
    Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty]

private theorem input_sound (entry : Entry) : (input entry).Sound := by
  refine ⟨⟨?_, ?_⟩, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro c cd h; cases h
  · intro c cd h; cases h
  · intro i d h; cases h
  · intro f d h; cases h
  · intro b s h
    change (if b = "%Predicate.0" then some entry.signature else none) = some s at h
    split at h
    · cases h; exact signature_support entry
    · cases h
  · intro o d h; cases h
  · intro c cd m ms h; cases h
  · intro f d h; cases h
  · intro C a p h; cases h
  · intro b s C ts hlookup hcheck
    change (if b = "%Predicate.0" then some entry.signature else none) = some s at hlookup
    split at hlookup
    · cases hlookup
      change ts = []
      exact of_decide_eq_true hcheck
    · cases hlookup
  · intro b rs h; cases h
  · intro o ty b ts h; cases h

/-- 利用者が条件に書く、書き換えていない公開の判定の呼出し。 -/
def publicCondition (entry : Entry) : Expr :=
  match entry with
  | .path _ => .call (.primName "Scope.pathMatches" [] [] [])
      [some "pattern", some "path"] [0, 1]
      (.cons (.literal (.string "/a")) (.cons (.local 0) .nil))
  | .host _ => .call (.primName "Scope.hostMatches" [] [] [])
      [some "pattern", some "host"] [0, 1]
      (.cons (.literal (.string "a")) (.cons (.local 0) .nil))
  | .characters lo hi => .call (.primName "String.charactersIn" [] [] [])
      [some "text", some "minimum", some "maximum"] [0, 1, 2]
      (.cons (.local 0) (.cons (.literal (.character lo)) (.cons (.literal (.character hi)) .nil)))
  | .floating width test => .call (.primName (API.floating width test).name [] [] [])
      [none] [0] (.cons (.local 0) .nil)

/-- 内部の規則の補題の例は、同じ公開呼出しを一行の表で解決して使う。 -/
private def condition (entry : Entry) : Expr :=
  PredicateCalls.resolveExpr [("%Predicate.0", entry)] (publicCondition entry)

private theorem parsed_path : parseAtPattern .path (.const (.string "/a")) =
    some (.path (.exact ["a"])) := by decide +kernel

private theorem parsed_host : parseAtPattern .host (.const (.string "a")) =
    some (.host (.name (.exact ["a"]))) := by
  have lower : "a".toLower = "a" := by decide +kernel
  have input : parseAtInput .host (.const (.string "a")) =
      some (.absolute (.host (.name ["a"]))) := by
    simp +decide [parseAtInput, parseTargetInput, parseHost, parseIPv4,
      splitText, splitChars, lower, NameWordWF, NameLabelWF, FourDigitLabels]
  have many : "a".startsWith "**." = false := by decide +kernel
  have one : "a".startsWith "*." = false := by decide +kernel
  have pieces : ("a".toList.splitOn '/').map String.ofList = ["a"] := by decide +kernel
  have pattern : parseHostPatternText "a" = some (.name (.exact ["a"])) := by
    simp only [parseHostPatternText, many, one, Bool.false_eq_true, ↓reduceIte, pieces, input]
    decide +kernel
  simp only [parseAtPattern, parsePatternText, pattern, Option.map_some, Option.bind_some]
  decide +kernel

attribute [local cbv_opaque] parseAtPattern
attribute [local cbv_eval] parsed_path parsed_host

private theorem path_condition : condition (.path (.exact ["a"])) =
    .partialCall (.primName "%Predicate.0" [] [] []) [] (.expr none 0 (.local 0) .nil)
      ((Entry.path (.exact ["a"])).result (.var 1)) Eff.empty := by cbv

private theorem host_condition : condition (.host (.name (.exact ["a"]))) =
    .partialCall (.primName "%Predicate.0" [] [] []) [] (.expr none 0 (.local 0) .nil)
      ((Entry.host (.name (.exact ["a"]))).result (.var 1)) Eff.empty := by cbv

private theorem characters_condition (lo hi : Char) : condition (.characters lo hi) =
    .partialCall (.primName "%Predicate.0" [] [] []) [] (.expr none 0 (.local 0) .nil)
      ((Entry.characters lo hi).result (.var 1)) Eff.empty := by cbv

private theorem floating_condition (width : FloatWidth) (test : FloatTest) : condition (.floating width test) =
    .partialCall (.primName "%Predicate.0" [] [] []) [] (.expr none 0 (.local 0) .nil)
      ((Entry.floating width test).result (.var 1)) Eff.empty := by
  cases width <;> cases test <;> cbv <;> simp [Eff.atoms]

attribute [local cbv_opaque] condition
attribute [local cbv_eval] path_condition host_condition characters_condition floating_condition

def branch (entry : Entry) (positive : Bool) : Block :=
  .lastBind .bind (.refined (.base entry.input)
    (if positive then entry.predicate (.var 0) else .not (entry.predicate (.var 0)))) (.local 0)

private def expression (entry : Entry) (facts : Bool) : Expr :=
  .ite (if facts then condition entry else .literal (.boolean true))
    (branch entry true) (branch entry false)

/-- 両枝がそれぞれ同じ対象の述語とその否定を必要とする、元の定義。 -/
def sourceDefinition (entry : Entry) (facts : Bool) : Def where
  tparams := []
  neffs := 0
  names := ["value"]
  params := [.base entry.input]
  ret := .base .unit
  eff := Eff.empty
  body := .last (.ite (if facts then publicCondition entry else .literal (.boolean true))
    (branch entry true) (branch entry false))

private def checked (entry : Entry) (facts : Bool) : Check.Result Check.Inferred :=
  Check.checkExpr (input entry) [] [some (.base entry.input)] [] none .other [] (expression entry facts)

private def accepted (entry : Entry) (facts : Bool) : Bool := (checked entry facts).toBool

/-- 固定した条件で選ぶ内部行は、公開の四種類の判定と同じ応答を返す。 -/
theorem public_delta (s : String) (width : FloatWidth) (test : FloatTest) (values : List Val) :
    (Entry.path (.exact ["a"])).delta [] [] [] [.const (.string s)] =
      API.path.delta API.path.name [] [] [] [.const (.string "/a"), .const (.string s)] ∧
    (Entry.host (.name (.exact ["a"]))).delta [] [] [] [.const (.string s)] =
      API.host.delta API.host.name [] [] [] [.const (.string "a"), .const (.string s)] ∧
    (Entry.characters 'a' 'z').delta [] [] [] [.const (.string s)] =
      API.characters.delta API.characters.name [] [] []
        [.const (.string s), .const (.character 'a'), .const (.character 'z')] ∧
    (Entry.floating width test).delta [] [] [] values =
      (API.floating width test).delta (API.floating width test).name [] [] [] values :=
  ⟨PredicateCalls.path_delta parsed_path s, PredicateCalls.host_delta parsed_host s,
    PredicateCalls.characters_delta 'a' 'z' s, PredicateCalls.floating_delta width test values⟩

/-- 公開名から選んだ同じ行のlookupと、対象だけを渡す脱糖をともに得る。 -/
theorem selected_call (op : OpPrim) (position : Position) :
    let entry := Entry.floating .binary64 .finite
    let output := condition entry
    [("%Predicate.0", entry)].lookup "%Predicate.0" = some entry ∧
      desugarExpr op position output = .app (.prim "%Predicate.0" [] [] []) [.var 0] := by
  dsimp only
  have chosen := PredicateCalls.resolveCall_selected
    (rows := [("%Predicate.0", Entry.floating .binary64 .finite)])
    (name := "Float.isFinite") (labels := [none]) (positions := [0])
    (args := .cons (.local 0) .nil) (api := .floating .binary64 .finite)
    (entry := Entry.floating .binary64 .finite) (target := .local 0)
    (key := "%Predicate.0") (output := condition (.floating .binary64 .finite))
    (by cbv) (by decide +kernel) (by cbv) (by cbv) (by cbv)
  have lowered := PredicateCalls.resolvedCall_desugar
    (name := "%Predicate.0") (entry := Entry.floating .binary64 .finite)
    (target := .local 0) (output := condition (.floating .binary64 .finite))
    (by cbv) op position
  obtain ⟨value, term, hv, _, _, hl, _⟩ := lowered
  cases hv
  exact ⟨chosen.2.1, hl⟩

/-- 真と偽の両枝はそれぞれ所属を要求する。同じ枝を素のBooleanの条件にすると拒否する。 -/
theorem path_branches :
    checked (.path (.exact ["a"])) true = .ok (.base .unit, Eff.empty) ∧
    accepted (.path (.exact ["a"])) false = false := by
  cbv <;> simp [Eff.atoms]

/-- ホストの事実も、通常の条件分岐の二枝へ渡る。 -/
theorem host_branches :
    checked (.host (.name (.exact ["a"]))) true = .ok (.base .unit, Eff.empty) ∧
    accepted (.host (.name (.exact ["a"]))) false = false := by
  cbv <;> simp [Eff.atoms]

/-- 文字集合の両端を固定した呼出しは、元の文字列について枝の篩を検査する。 -/
theorem characters_branches :
    checked (.characters 'a' 'z') true = .ok (.base .unit, Eff.empty) ∧
    accepted (.characters 'a' 'z') false = false := by
  cbv <;> simp [Eff.atoms]

/-- 六つのFloatの分類は、すべて真偽と同じ対象の分類を結ぶ。 -/
theorem float_branches (test : FloatTest) :
    checked (.floating .binary64 test) true = .ok (.base .unit, Eff.empty) ∧
    accepted (.floating .binary64 test) false = false := by
  cases test <;> cbv <;> simp [Eff.atoms]

/-- 新しい五つのFloat32の分類も同じ経路で検査する。 -/
theorem float32_branches (test : FloatTest) (h : test ≠ .infinite) :
    checked (.floating .binary32 test) true = .ok (.base .unit, Eff.empty) ∧
    accepted (.floating .binary32 test) false = false := by
  cases test <;> first | contradiction | (cbv <;> simp [Eff.atoms])

/-- Float32の無限大の分類も、真偽の両枝と素のBooleanの対照で確認する。 -/
theorem float32_infinite_branches :
    checked (.floating .binary32 .infinite) true = .ok (.base .unit, Eff.empty) ∧
    accepted (.floating .binary32 .infinite) false = false := by
  cbv <;> simp [Eff.atoms]

private def definition (entry : Entry) : Def where
  tparams := []
  neffs := 0
  names := ["value"]
  params := [.base entry.input]
  ret := .base .unit
  eff := Eff.empty
  rangeParams := [.path]
  body := .last (expression entry true)

/-- 範囲パラメータを持つ関数の本体でも、同じ文字列の呼出しと二枝の事実を受け付ける。 -/
theorem open_string_branches :
    CheckDeclarations.checkDef (input (.path (.exact ["a"]))) []
      (definition (.path (.exact ["a"]))) = .ok () ∧
    CheckDeclarations.checkDef (input (.host (.name (.exact ["a"])))) []
      (definition (.host (.name (.exact ["a"])))) = .ok () ∧
    CheckDeclarations.checkDef (input (.characters 'a' 'z')) []
      (definition (.characters 'a' 'z')) = .ok () := by
  cbv

/-- Floatの分類も、外側の範囲文脈を閉じずに検査する。 -/
theorem open_float_branches (width : FloatWidth) (test : FloatTest) :
    CheckDeclarations.checkDef (input (.floating width test)) []
      (definition (.floating width test)) = .ok () := by
  cases width <;> cases test <;> cbv <;> simp [Eff.atoms]

/-- 成功した実入口の同じ入力表から、二枝の事実を使う表層の型付けを得る。 -/
theorem path_wellTyped :
    HasTypeQ (input (.path (.exact ["a"]))).D (input (.path (.exact ["a"]))).B
      (input (.path (.exact ["a"]))).opPrim Qempty [] [] [some (.base .string)] [] none .other
      (expression (.path (.exact ["a"])) true) (.base .unit) Eff.empty := by
  apply (Check.checkExpr_sound (input_sound (.path (.exact ["a"]))) ?_ (by trivial) ?_
    (by trivial) (Check.empty_effect_support _) path_branches.1).1
  · intro i a hi
    cases i <;> simp at hi
    cases hi
    trivial
  · have hh := CheckArguments.primitive_empty_support
      (b := "%Predicate.0") (ts := []) (input_sound (.path (.exact ["a"]))).tables (by trivial)
    simp only [expression, ↓reduceIte, path_condition]
    simpa [Check.ExprSupport, CheckSource.ExprSupport, CheckSource.HolesSupport,
      CheckSource.BlockSupport, Entry.result, Ty.Support, Eff.Support, Eff.empty, branch] using ⟨hh, by trivial⟩

end
end Benitoite.Release.Refinement.Surface.CheckPredicateExamples
