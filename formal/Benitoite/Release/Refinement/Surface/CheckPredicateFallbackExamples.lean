import Benitoite.Release.Refinement.Surface.CheckEntrypoints
import Benitoite.Release.Refinement.Surface.PredicateCalls

/-! # 動的な判定の条件を持つ呼出しの結果型 -/
namespace Benitoite.Release.Refinement.Surface.CheckPredicateFallbackExamples
open PredicateResponse
noncomputable section

private def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none

private def builtins (api : API) : Builtins where
  sig := fun b => if b = api.name then some api.signature else none
  delta := api.delta
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "Reference.get"
  refSet := "Reference.set"

private def input (api : API) : Check.Input where
  D := declarations
  builtinSource := .custom (builtins api)
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  admitsDec := fun _ _ ts => decide (ts = [])
  proofSteps := 200

private def stringCall (api : API) : Expr :=
  PredicateCalls.resolveCall [("%Predicate.unused", .path (.tree ["data"]))]
    api.name (api.names.map some) [0, 1] (.cons (.local 1) (.cons (.local 0) .nil))

/-- パスのpatternが変数なら内部行を選ばず、公開のBooleanの結果型で受け付ける。 -/
theorem dynamic_path_boolean :
    Check.checkExpr (input .path) [] [some (.base .string), some (.base .string)] []
      none .other [] (stringCall .path) = .ok (.base .boolean, Eff.empty) := by
  cbv <;> simp [Eff.atoms]

/-- ホストのpatternが変数の場合も、Booleanの結果だけを検査する。 -/
theorem dynamic_host_boolean :
    Check.checkExpr (input .host) [] [some (.base .string), some (.base .string)] []
      none .other [] (stringCall .host) = .ok (.base .boolean, Eff.empty) := by
  cbv <;> simp [Eff.atoms]

private def charactersCall : Expr :=
  PredicateCalls.resolveCall [("%Predicate.unused", .characters 'a' 'z')]
    "String.charactersIn" [some "text", some "minimum", some "maximum"] [0, 1, 2]
    (.cons (.local 2) (.cons (.local 1) (.cons (.local 0) .nil)))

/-- 両端を変数で渡す文字集合の判定は、篩を付けずBooleanとして受け付ける。 -/
theorem dynamic_characters_boolean :
    Check.checkExpr (input .characters) []
      [some (.base .character), some (.base .character), some (.base .string)] []
      none .other [] charactersCall = .ok (.base .boolean, Eff.empty) := by
  cbv <;> simp [Eff.atoms]

end
end Benitoite.Release.Refinement.Surface.CheckPredicateFallbackExamples
