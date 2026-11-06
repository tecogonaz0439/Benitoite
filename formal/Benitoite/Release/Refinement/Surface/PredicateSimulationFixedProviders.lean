import Benitoite.Release.Refinement.Surface.PredicateSimulationFixedResponses
import Benitoite.Release.Refinement.Surface.PredicateSimulationListArguments
import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationPureProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationNumericProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationOperatorProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationDecimalProviders
import Benitoite.Release.Refinement.Surface.PredicateSimulationBytesProviders

/-! # 標準台帳の純粋応答と禁止名不在 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 固定台帳の実行先だけが型付くとき、対応する実引数から応答の対応と元の禁止名不在を得る。 -/
theorem fixed_pure_response {P B Ψ source rows keys ts es rs xs ys a e}
    [environment : StandardModel.RowEnv P B] (core : B.CoreAssumptions P)
    (row : StandardModel.Primitive) (pure : (row.signatureWith B.sat).kind = .pure)
    (typed : BuiltinArgs P B Ψ row.name (row.signatureWith B.sat) ts es rs ys a e)
    (related : Values source rows xs ys) (avoid : ValuesAvoid keys xs) :
    let constructors := (environment.keys.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst
    OptionalOutcomeRel source rows (row.deltaWith constructors row.name ts es rs xs)
      (row.deltaWith constructors row.name ts es rs ys) ∧
      OptionalOutcomeAvoid keys (row.deltaWith constructors row.name ts es rs xs) := by
  have resultTyped : ∀ out, row.deltaWith ((environment.keys.declarations.flatMap StandardKeyTyping.DataDecl.entries).map Prod.fst)
      row.name ts es rs ys = some out → Outcome.Typed P B Ψ out a := by
    obtain ⟨out,response,_noExit,typedResult,_adequate⟩ :=
      core.delta_typed Ψ row.name (row.signatureWith B.sat) ts es rs ys a e (StandardModel.RowLookup.sig row) pure typed
    rw [StandardModel.RowEnv.keyDelta (P := P) row] at response
    intro result found
    cases Option.some.inj (found.symm.trans response)
    exact typedResult
  cases row with
  | p001 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .byte .gt typed related)
      (fun out response => order_fixed_reply_noMint .byte .gt environment.options environment.valid typed (resultTyped out response))
  | p002 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .byte .ge typed related)
      (fun out response => order_fixed_reply_noMint .byte .ge environment.options environment.valid typed (resultTyped out response))
  | p003 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .byte .lt typed related)
      (fun out response => order_fixed_reply_noMint .byte .lt environment.options environment.valid typed (resultTyped out response))
  | p004 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .byte .le typed related)
      (fun out response => order_fixed_reply_noMint .byte .le environment.options environment.valid typed (resultTyped out response))
  | p005 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .character .gt typed related)
      (fun out response => order_fixed_reply_noMint .character .gt environment.options environment.valid typed (resultTyped out response))
  | p006 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .character .ge typed related)
      (fun out response => order_fixed_reply_noMint .character .ge environment.options environment.valid typed (resultTyped out response))
  | p007 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .character .lt typed related)
      (fun out response => order_fixed_reply_noMint .character .lt environment.options environment.valid typed (resultTyped out response))
  | p008 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .character .le typed related)
      (fun out response => order_fixed_reply_noMint .character .le environment.options environment.valid typed (resultTyped out response))
  | p009 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.decimal .add) typed related)
      (fun out response => operator_reply_noMint (.decimal .add) typed (resultTyped out response))
  | p010 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.decimal .divide) typed related)
      (fun out response => operator_reply_noMint (.decimal .divide) typed (resultTyped out response))
  | p011 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .decimal .gt typed related)
      (fun out response => order_fixed_reply_noMint .decimal .gt environment.options environment.valid typed (resultTyped out response))
  | p012 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .decimal .ge typed related)
      (fun out response => order_fixed_reply_noMint .decimal .ge environment.options environment.valid typed (resultTyped out response))
  | p013 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .decimal .lt typed related)
      (fun out response => order_fixed_reply_noMint .decimal .lt environment.options environment.valid typed (resultTyped out response))
  | p014 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .decimal .le typed related)
      (fun out response => order_fixed_reply_noMint .decimal .le environment.options environment.valid typed (resultTyped out response))
  | p015 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.decimal .multiply) typed related)
      (fun out response => operator_reply_noMint (.decimal .multiply) typed (resultTyped out response))
  | p016 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.decimal .negate) typed related)
      (fun out response => operator_reply_noMint (.decimal .negate) typed (resultTyped out response))
  | p017 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.decimal .subtract) typed related)
      (fun out response => operator_reply_noMint (.decimal .subtract) typed (resultTyped out response))
  | p018 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating false .add) typed related)
      (fun out response => operator_reply_noMint (.floating false .add) typed (resultTyped out response))
  | p019 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating false .divide) typed related)
      (fun out response => operator_reply_noMint (.floating false .divide) typed (resultTyped out response))
  | p020 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float64 .gt typed related)
      (fun out response => order_fixed_reply_noMint .float64 .gt environment.options environment.valid typed (resultTyped out response))
  | p021 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float64 .ge typed related)
      (fun out response => order_fixed_reply_noMint .float64 .ge environment.options environment.valid typed (resultTyped out response))
  | p022 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float64 .lt typed related)
      (fun out response => order_fixed_reply_noMint .float64 .lt environment.options environment.valid typed (resultTyped out response))
  | p023 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float64 .le typed related)
      (fun out response => order_fixed_reply_noMint .float64 .le environment.options environment.valid typed (resultTyped out response))
  | p024 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating false .multiply) typed related)
      (fun out response => operator_reply_noMint (.floating false .multiply) typed (resultTyped out response))
  | p025 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating false .negate) typed related)
      (fun out response => operator_reply_noMint (.floating false .negate) typed (resultTyped out response))
  | p026 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating false .subtract) typed related)
      (fun out response => operator_reply_noMint (.floating false .subtract) typed (resultTyped out response))
  | p027 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating true .add) typed related)
      (fun out response => operator_reply_noMint (.floating true .add) typed (resultTyped out response))
  | p028 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating true .divide) typed related)
      (fun out response => operator_reply_noMint (.floating true .divide) typed (resultTyped out response))
  | p029 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float32 .gt typed related)
      (fun out response => order_fixed_reply_noMint .float32 .gt environment.options environment.valid typed (resultTyped out response))
  | p030 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float32 .ge typed related)
      (fun out response => order_fixed_reply_noMint .float32 .ge environment.options environment.valid typed (resultTyped out response))
  | p031 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float32 .lt typed related)
      (fun out response => order_fixed_reply_noMint .float32 .lt environment.options environment.valid typed (resultTyped out response))
  | p032 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .float32 .le typed related)
      (fun out response => order_fixed_reply_noMint .float32 .le environment.options environment.valid typed (resultTyped out response))
  | p033 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating true .multiply) typed related)
      (fun out response => operator_reply_noMint (.floating true .multiply) typed (resultTyped out response))
  | p034 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating true .negate) typed related)
      (fun out response => operator_reply_noMint (.floating true .negate) typed (resultTyped out response))
  | p035 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.floating true .subtract) typed related)
      (fun out response => operator_reply_noMint (.floating true .subtract) typed (resultTyped out response))
  | p036 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer64 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer64 .add environment.options environment.valid typed (resultTyped out response))
  | p037 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer64 false) typed related)
      (fun out response => operator_reply_noMint (.integer .integer64 false) typed (resultTyped out response))
  | p038 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer64 .gt typed related)
      (fun out response => order_fixed_reply_noMint .integer64 .gt environment.options environment.valid typed (resultTyped out response))
  | p039 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer64 .ge typed related)
      (fun out response => order_fixed_reply_noMint .integer64 .ge environment.options environment.valid typed (resultTyped out response))
  | p040 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer64 .lt typed related)
      (fun out response => order_fixed_reply_noMint .integer64 .lt environment.options environment.valid typed (resultTyped out response))
  | p041 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer64 .le typed related)
      (fun out response => order_fixed_reply_noMint .integer64 .le environment.options environment.valid typed (resultTyped out response))
  | p042 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer64 true) typed related)
      (fun out response => operator_reply_noMint (.integer .integer64 true) typed (resultTyped out response))
  | p043 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer64 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer64 .multiply environment.options environment.valid typed (resultTyped out response))
  | p044 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer64 .negate typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer64 .negate environment.options environment.valid typed (resultTyped out response))
  | p045 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer64 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer64 .subtract environment.options environment.valid typed (resultTyped out response))
  | p046 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer16 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer16 .add environment.options environment.valid typed (resultTyped out response))
  | p047 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer16 false) typed related)
      (fun out response => operator_reply_noMint (.integer .integer16 false) typed (resultTyped out response))
  | p048 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer16 .gt typed related)
      (fun out response => order_fixed_reply_noMint .integer16 .gt environment.options environment.valid typed (resultTyped out response))
  | p049 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer16 .ge typed related)
      (fun out response => order_fixed_reply_noMint .integer16 .ge environment.options environment.valid typed (resultTyped out response))
  | p050 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer16 .lt typed related)
      (fun out response => order_fixed_reply_noMint .integer16 .lt environment.options environment.valid typed (resultTyped out response))
  | p051 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer16 .le typed related)
      (fun out response => order_fixed_reply_noMint .integer16 .le environment.options environment.valid typed (resultTyped out response))
  | p052 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer16 true) typed related)
      (fun out response => operator_reply_noMint (.integer .integer16 true) typed (resultTyped out response))
  | p053 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer16 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer16 .multiply environment.options environment.valid typed (resultTyped out response))
  | p054 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer16 .negate typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer16 .negate environment.options environment.valid typed (resultTyped out response))
  | p055 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer16 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer16 .subtract environment.options environment.valid typed (resultTyped out response))
  | p056 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer32 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer32 .add environment.options environment.valid typed (resultTyped out response))
  | p057 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer32 false) typed related)
      (fun out response => operator_reply_noMint (.integer .integer32 false) typed (resultTyped out response))
  | p058 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer32 .gt typed related)
      (fun out response => order_fixed_reply_noMint .integer32 .gt environment.options environment.valid typed (resultTyped out response))
  | p059 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer32 .ge typed related)
      (fun out response => order_fixed_reply_noMint .integer32 .ge environment.options environment.valid typed (resultTyped out response))
  | p060 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer32 .lt typed related)
      (fun out response => order_fixed_reply_noMint .integer32 .lt environment.options environment.valid typed (resultTyped out response))
  | p061 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer32 .le typed related)
      (fun out response => order_fixed_reply_noMint .integer32 .le environment.options environment.valid typed (resultTyped out response))
  | p062 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer32 true) typed related)
      (fun out response => operator_reply_noMint (.integer .integer32 true) typed (resultTyped out response))
  | p063 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer32 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer32 .multiply environment.options environment.valid typed (resultTyped out response))
  | p064 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer32 .negate typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer32 .negate environment.options environment.valid typed (resultTyped out response))
  | p065 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer32 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer32 .subtract environment.options environment.valid typed (resultTyped out response))
  | p066 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer8 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer8 .add environment.options environment.valid typed (resultTyped out response))
  | p067 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer8 false) typed related)
      (fun out response => operator_reply_noMint (.integer .integer8 false) typed (resultTyped out response))
  | p068 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer8 .gt typed related)
      (fun out response => order_fixed_reply_noMint .integer8 .gt environment.options environment.valid typed (resultTyped out response))
  | p069 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer8 .ge typed related)
      (fun out response => order_fixed_reply_noMint .integer8 .ge environment.options environment.valid typed (resultTyped out response))
  | p070 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer8 .lt typed related)
      (fun out response => order_fixed_reply_noMint .integer8 .lt environment.options environment.valid typed (resultTyped out response))
  | p071 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .integer8 .le typed related)
      (fun out response => order_fixed_reply_noMint .integer8 .le environment.options environment.valid typed (resultTyped out response))
  | p072 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .integer8 true) typed related)
      (fun out response => operator_reply_noMint (.integer .integer8 true) typed (resultTyped out response))
  | p073 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer8 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer8 .multiply environment.options environment.valid typed (resultTyped out response))
  | p074 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer8 .negate typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer8 .negate environment.options environment.valid typed (resultTyped out response))
  | p075 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .integer8 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .integer8 .subtract environment.options environment.valid typed (resultTyped out response))
  | p076 =>
    exact ⟨precision_delta related _ _ _ _ _,precision_delta_noMint avoid _ _ _ _ _⟩
  | p077 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.string .add) typed related)
      (fun out response => operator_reply_noMint (.string .add) typed (resultTyped out response))
  | p078 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.string .greater) typed related)
      (fun out response => operator_reply_noMint (.string .greater) typed (resultTyped out response))
  | p079 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.string .greaterOrEqual) typed related)
      (fun out response => operator_reply_noMint (.string .greaterOrEqual) typed (resultTyped out response))
  | p080 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.string .less) typed related)
      (fun out response => operator_reply_noMint (.string .less) typed (resultTyped out response))
  | p081 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.string .lessOrEqual) typed related)
      (fun out response => operator_reply_noMint (.string .lessOrEqual) typed (resultTyped out response))
  | p082 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger16 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger16 .add environment.options environment.valid typed (resultTyped out response))
  | p083 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .unsignedInteger16 false) typed related)
      (fun out response => operator_reply_noMint (.integer .unsignedInteger16 false) typed (resultTyped out response))
  | p084 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger16 .gt typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger16 .gt environment.options environment.valid typed (resultTyped out response))
  | p085 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger16 .ge typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger16 .ge environment.options environment.valid typed (resultTyped out response))
  | p086 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger16 .lt typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger16 .lt environment.options environment.valid typed (resultTyped out response))
  | p087 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger16 .le typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger16 .le environment.options environment.valid typed (resultTyped out response))
  | p088 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .unsignedInteger16 true) typed related)
      (fun out response => operator_reply_noMint (.integer .unsignedInteger16 true) typed (resultTyped out response))
  | p089 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger16 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger16 .multiply environment.options environment.valid typed (resultTyped out response))
  | p090 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger16 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger16 .subtract environment.options environment.valid typed (resultTyped out response))
  | p091 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger32 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger32 .add environment.options environment.valid typed (resultTyped out response))
  | p092 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .unsignedInteger32 false) typed related)
      (fun out response => operator_reply_noMint (.integer .unsignedInteger32 false) typed (resultTyped out response))
  | p093 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger32 .gt typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger32 .gt environment.options environment.valid typed (resultTyped out response))
  | p094 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger32 .ge typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger32 .ge environment.options environment.valid typed (resultTyped out response))
  | p095 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger32 .lt typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger32 .lt environment.options environment.valid typed (resultTyped out response))
  | p096 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger32 .le typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger32 .le environment.options environment.valid typed (resultTyped out response))
  | p097 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .unsignedInteger32 true) typed related)
      (fun out response => operator_reply_noMint (.integer .unsignedInteger32 true) typed (resultTyped out response))
  | p098 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger32 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger32 .multiply environment.options environment.valid typed (resultTyped out response))
  | p099 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger32 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger32 .subtract environment.options environment.valid typed (resultTyped out response))
  | p100 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger64 .add typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger64 .add environment.options environment.valid typed (resultTyped out response))
  | p101 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .unsignedInteger64 false) typed related)
      (fun out response => operator_reply_noMint (.integer .unsignedInteger64 false) typed (resultTyped out response))
  | p102 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger64 .gt typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger64 .gt environment.options environment.valid typed (resultTyped out response))
  | p103 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger64 .ge typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger64 .ge environment.options environment.valid typed (resultTyped out response))
  | p104 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger64 .lt typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger64 .lt environment.options environment.valid typed (resultTyped out response))
  | p105 =>
    exact fixed_inputs_response _ (order_fixed_inputs_equal .unsignedInteger64 .le typed related)
      (fun out response => order_fixed_reply_noMint .unsignedInteger64 .le environment.options environment.valid typed (resultTyped out response))
  | p106 =>
    exact fixed_inputs_response _ (operator_inputs_equal (.integer .unsignedInteger64 true) typed related)
      (fun out response => operator_reply_noMint (.integer .unsignedInteger64 true) typed (resultTyped out response))
  | p107 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger64 .multiply typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger64 .multiply environment.options environment.valid typed (resultTyped out response))
  | p108 =>
    exact fixed_inputs_response _ (arithmetic_fixed_inputs_equal .unsignedInteger64 .subtract typed related)
      (fun out response => arithmetic_fixed_reply_noMint .unsignedInteger64 .subtract environment.options environment.valid typed (resultTyped out response))
  | p109 =>
    exact ⟨equality_delta related _ _ _ _,equality_delta_noMint⟩
  | p110 =>
    exact ⟨equality_delta related _ _ _ _,equality_delta_noMint⟩
  | p111 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteAnd typed related)
      (fun out response => scalar_reply_noMint .byteAnd environment.options environment.valid typed (resultTyped out response))
  | p112 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteXor typed related)
      (fun out response => scalar_reply_noMint .byteXor environment.options environment.valid typed (resultTyped out response))
  | p113 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteNot typed related)
      (fun out response => scalar_reply_noMint .byteNot environment.options environment.valid typed (resultTyped out response))
  | p114 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteOr typed related)
      (fun out response => scalar_reply_noMint .byteOr environment.options environment.valid typed (resultTyped out response))
  | p115 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteFrom typed related)
      (fun out response => scalar_reply_noMint .byteFrom environment.options environment.valid typed (resultTyped out response))
  | p116 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteLeft typed related)
      (fun out response => scalar_reply_noMint .byteLeft environment.options environment.valid typed (resultTyped out response))
  | p117 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteRight typed related)
      (fun out response => scalar_reply_noMint .byteRight environment.options environment.valid typed (resultTyped out response))
  | p118 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .byteTo typed related)
      (fun out response => scalar_reply_noMint .byteTo environment.options environment.valid typed (resultTyped out response))
  | p119 =>
    exact fixed_inputs_response _ (byte_string_inputs_equal typed related)
      (fun out response => byte_string_reply_noMint typed (resultTyped out response))
  | p120 =>
    exact ⟨bytes_ordinary_provider_delta .concatenate typed related,bytes_table_noMint⟩
  | p121 =>
    exact ⟨bytes_ordinary_provider_delta .empty typed related,bytes_table_noMint⟩
  | p122 =>
    exact ⟨bytes_ordinary_provider_delta .fromBinary typed related,bytes_table_noMint⟩
  | p123 =>
    exact ⟨bytes_ordinary_provider_delta .fromHex typed related,bytes_table_noMint⟩
  | p124 =>
    exact ⟨bytes_ordinary_provider_delta .fromIntegers typed related,bytes_table_noMint⟩
  | p125 =>
    exact fixed_inputs_response _ (bytes_inputs_equal .bytesFromList typed related)
      (fun out response => bytes_reply_noMint .bytesFromList typed (resultTyped out response))
  | p126 =>
    exact ⟨bytes_ordinary_provider_delta .fromSigned typed related,bytes_table_noMint⟩
  | p127 =>
    exact ⟨bytes_ordinary_provider_delta .fromUnsigned typed related,bytes_table_noMint⟩
  | p128 =>
    exact ⟨bytes_ordinary_provider_delta .get typed related,bytes_table_noMint⟩
  | p129 =>
    exact fixed_inputs_response _ (bytes_inputs_equal .bytesLength typed related)
      (fun out response => bytes_reply_noMint .bytesLength typed (resultTyped out response))
  | p130 =>
    exact ⟨bytes_ordinary_provider_delta .readSigned typed related,bytes_table_noMint⟩
  | p131 =>
    exact ⟨bytes_ordinary_provider_delta .readUnsigned typed related,bytes_table_noMint⟩
  | p132 =>
    exact ⟨bytes_ordinary_provider_delta .slice typed related,bytes_table_noMint⟩
  | p133 =>
    exact ⟨bytes_ordinary_provider_delta .toBinary typed related,bytes_table_noMint⟩
  | p134 =>
    exact ⟨bytes_ordinary_provider_delta .toHex typed related,bytes_table_noMint⟩
  | p135 =>
    exact fixed_inputs_response _ (bytes_inputs_equal .bytesToList typed related)
      (fun out response => bytes_reply_noMint .bytesToList typed (resultTyped out response))
  | p136 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .characterFrom typed related)
      (fun out response => scalar_reply_noMint .characterFrom environment.options environment.valid typed (resultTyped out response))
  | p137 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isASCIIDigit typed related)
      (fun out response => character_fixed_reply_noMint .isASCIIDigit environment.options environment.valid typed (resultTyped out response))
  | p138 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isASCIIWhitespace typed related)
      (fun out response => character_fixed_reply_noMint .isASCIIWhitespace environment.options environment.valid typed (resultTyped out response))
  | p139 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isAlphabetic typed related)
      (fun out response => character_fixed_reply_noMint .isAlphabetic environment.options environment.valid typed (resultTyped out response))
  | p140 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isLowercase typed related)
      (fun out response => character_fixed_reply_noMint .isLowercase environment.options environment.valid typed (resultTyped out response))
  | p141 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isNumeric typed related)
      (fun out response => character_fixed_reply_noMint .isNumeric environment.options environment.valid typed (resultTyped out response))
  | p142 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isUppercase typed related)
      (fun out response => character_fixed_reply_noMint .isUppercase environment.options environment.valid typed (resultTyped out response))
  | p143 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .isWhitespace typed related)
      (fun out response => character_fixed_reply_noMint .isWhitespace environment.options environment.valid typed (resultTyped out response))
  | p144 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .characterTo typed related)
      (fun out response => scalar_reply_noMint .characterTo environment.options environment.valid typed (resultTyped out response))
  | p145 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .toLowercase typed related)
      (fun out response => character_fixed_reply_noMint .toLowercase environment.options environment.valid typed (resultTyped out response))
  | p146 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .toString typed related)
      (fun out response => character_fixed_reply_noMint .toString environment.options environment.valid typed (resultTyped out response))
  | p147 =>
    exact fixed_inputs_response _ (character_fixed_inputs_equal .toUppercase typed related)
      (fun out response => character_fixed_reply_noMint .toUppercase environment.options environment.valid typed (resultTyped out response))
  | p148 =>
    exact fixed_inputs_response _ (decimal_inputs_equal environment.rounding .absolute typed related)
      (fun out response => decimal_reply_noMint .absolute environment.options environment.valid typed (resultTyped out response))
  | p149 =>
    exact ⟨numeric_provider_delta .Decimal_fromFloat typed related,numeric_table_noMint⟩
  | p150 =>
    exact fixed_inputs_response _ (decimal_inputs_equal environment.rounding .fromInteger typed related)
      (fun out response => decimal_reply_noMint .fromInteger environment.options environment.valid typed (resultTyped out response))
  | p151 =>
    exact ⟨numeric_provider_delta .Decimal_parse typed related,numeric_table_noMint⟩
  | p152 =>
    exact fixed_inputs_response _ (decimal_inputs_equal environment.rounding .round typed related)
      (fun out response => decimal_reply_noMint .round environment.options environment.valid typed (resultTyped out response))
  | p153 =>
    exact ⟨numeric_provider_delta .Decimal_toFloat typed related,numeric_table_noMint⟩
  | p154 =>
    exact ⟨numeric_provider_delta .Decimal_toString typed related,numeric_table_noMint⟩
  | p155 =>
    exact fixed_inputs_response _ (decimal_inputs_equal environment.rounding .truncate typed related)
      (fun out response => decimal_reply_noMint .truncate environment.options environment.valid typed (resultTyped out response))
  | p156 =>
    cases pure
  | p157 =>
    cases pure
  | p158 =>
    cases pure
  | p159 =>
    cases pure
  | p160 =>
    cases pure
  | p161 =>
    cases pure
  | p162 =>
    cases pure
  | p163 =>
    cases pure
  | p164 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal false .absolute typed related)
      (fun out response => float_math_fixed_reply_noMint false .absolute environment.options environment.valid typed (resultTyped out response))
  | p165 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal false .ceiling typed related)
      (fun out response => float_math_fixed_reply_noMint false .ceiling environment.options environment.valid typed (resultTyped out response))
  | p166 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal false .floor typed related)
      (fun out response => float_math_fixed_reply_noMint false .floor environment.options environment.valid typed (resultTyped out response))
  | p167 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .floatNaN typed related)
      (fun out response => scalar_reply_noMint .floatNaN environment.options environment.valid typed (resultTyped out response))
  | p168 =>
    exact ⟨numeric_provider_delta .Float_parse typed related,numeric_table_noMint⟩
  | p169 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal false .round typed related)
      (fun out response => float_math_fixed_reply_noMint false .round environment.options environment.valid typed (resultTyped out response))
  | p170 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal false .squareRoot typed related)
      (fun out response => float_math_fixed_reply_noMint false .squareRoot environment.options environment.valid typed (resultTyped out response))
  | p171 =>
    exact ⟨numeric_provider_delta .Float_toString typed related,numeric_table_noMint⟩
  | p172 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal false .truncate typed related)
      (fun out response => float_math_fixed_reply_noMint false .truncate environment.options environment.valid typed (resultTyped out response))
  | p173 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal true .absolute typed related)
      (fun out response => float_math_fixed_reply_noMint true .absolute environment.options environment.valid typed (resultTyped out response))
  | p174 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal true .ceiling typed related)
      (fun out response => float_math_fixed_reply_noMint true .ceiling environment.options environment.valid typed (resultTyped out response))
  | p175 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal true .floor typed related)
      (fun out response => float_math_fixed_reply_noMint true .floor environment.options environment.valid typed (resultTyped out response))
  | p176 =>
    exact ⟨numeric_provider_delta .Float32_fromFloat typed related,numeric_table_noMint⟩
  | p177 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .float32Infinite typed related)
      (fun out response => scalar_reply_noMint .float32Infinite environment.options environment.valid typed (resultTyped out response))
  | p178 =>
    exact fixed_inputs_response _ (scalar_inputs_equal .float32NaN typed related)
      (fun out response => scalar_reply_noMint .float32NaN environment.options environment.valid typed (resultTyped out response))
  | p179 =>
    exact ⟨numeric_provider_delta .Float32_parse typed related,numeric_table_noMint⟩
  | p180 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal true .round typed related)
      (fun out response => float_math_fixed_reply_noMint true .round environment.options environment.valid typed (resultTyped out response))
  | p181 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal true .squareRoot typed related)
      (fun out response => float_math_fixed_reply_noMint true .squareRoot environment.options environment.valid typed (resultTyped out response))
  | p182 =>
    exact ⟨numeric_provider_delta .Float32_toFloat typed related,numeric_table_noMint⟩
  | p183 =>
    exact ⟨numeric_provider_delta .Float32_toString typed related,numeric_table_noMint⟩
  | p184 =>
    exact fixed_inputs_response _ (float_math_fixed_inputs_equal true .truncate typed related)
      (fun out response => float_math_fixed_reply_noMint true .truncate environment.options environment.valid typed (resultTyped out response))
  | p185 =>
    exact ⟨scope_response_delta related "Http.checkRequestIn" ts es rs,scope_response_noMint (name := "Http.checkRequestIn") (ts := ts) (es := es) (rs := rs) avoid⟩
  | p186 =>
    exact ⟨scope_response_delta related "Http.requestInValue" ts es rs,scope_response_noMint (name := "Http.requestInValue") (ts := ts) (es := es) (rs := rs) avoid⟩
  | p187 =>
    cases pure
  | p188 =>
    exact ⟨scope_response_delta related "Http.widenRequestIn" ts es rs,scope_response_noMint (name := "Http.widenRequestIn") (ts := ts) (es := es) (rs := rs) avoid⟩
  | p189 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .absolute environment.options environment.valid typed (resultTyped out response))
  | p190 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p191 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p192 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p193 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p194 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p195 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p196 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer64 true typed related)
      (fun out response => minmax_fixed_reply_noMint .integer64 true environment.options environment.valid typed (resultTyped out response))
  | p197 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer64 false typed related)
      (fun out response => minmax_fixed_reply_noMint .integer64 false environment.options environment.valid typed (resultTyped out response))
  | p198 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer64 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer64 .parse environment.options environment.valid typed (resultTyped out response))
  | p199 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p200 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p201 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer64 .shiftRightUnsigned typed related)
      (fun out response => integer_fixed_reply_noMint .integer64 .shiftRightUnsigned environment.options environment.valid typed (resultTyped out response))
  | p202 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer64 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer64 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p203 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer64 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer64 .toString environment.options environment.valid typed (resultTyped out response))
  | p204 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .absolute environment.options environment.valid typed (resultTyped out response))
  | p205 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p206 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p207 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p208 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p209 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p210 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p211 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .integer16 true typed related)
      (fun out response => conversion_fixed_reply_noMint .integer16 true environment.options environment.valid typed (resultTyped out response))
  | p212 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer16 true typed related)
      (fun out response => minmax_fixed_reply_noMint .integer16 true environment.options environment.valid typed (resultTyped out response))
  | p213 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer16 false typed related)
      (fun out response => minmax_fixed_reply_noMint .integer16 false environment.options environment.valid typed (resultTyped out response))
  | p214 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer16 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer16 .parse environment.options environment.valid typed (resultTyped out response))
  | p215 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p216 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p217 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer16 .shiftRightUnsigned typed related)
      (fun out response => integer_fixed_reply_noMint .integer16 .shiftRightUnsigned environment.options environment.valid typed (resultTyped out response))
  | p218 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer16 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer16 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p219 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .integer16 false typed related)
      (fun out response => conversion_fixed_reply_noMint .integer16 false environment.options environment.valid typed (resultTyped out response))
  | p220 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer16 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer16 .toString environment.options environment.valid typed (resultTyped out response))
  | p221 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .absolute environment.options environment.valid typed (resultTyped out response))
  | p222 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p223 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p224 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p225 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p226 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p227 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p228 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .integer32 true typed related)
      (fun out response => conversion_fixed_reply_noMint .integer32 true environment.options environment.valid typed (resultTyped out response))
  | p229 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer32 true typed related)
      (fun out response => minmax_fixed_reply_noMint .integer32 true environment.options environment.valid typed (resultTyped out response))
  | p230 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer32 false typed related)
      (fun out response => minmax_fixed_reply_noMint .integer32 false environment.options environment.valid typed (resultTyped out response))
  | p231 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer32 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer32 .parse environment.options environment.valid typed (resultTyped out response))
  | p232 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p233 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p234 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer32 .shiftRightUnsigned typed related)
      (fun out response => integer_fixed_reply_noMint .integer32 .shiftRightUnsigned environment.options environment.valid typed (resultTyped out response))
  | p235 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer32 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer32 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p236 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .integer32 false typed related)
      (fun out response => conversion_fixed_reply_noMint .integer32 false environment.options environment.valid typed (resultTyped out response))
  | p237 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer32 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer32 .toString environment.options environment.valid typed (resultTyped out response))
  | p238 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .absolute environment.options environment.valid typed (resultTyped out response))
  | p239 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p240 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p241 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p242 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p243 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p244 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p245 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .integer8 true typed related)
      (fun out response => conversion_fixed_reply_noMint .integer8 true environment.options environment.valid typed (resultTyped out response))
  | p246 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer8 true typed related)
      (fun out response => minmax_fixed_reply_noMint .integer8 true environment.options environment.valid typed (resultTyped out response))
  | p247 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .integer8 false typed related)
      (fun out response => minmax_fixed_reply_noMint .integer8 false environment.options environment.valid typed (resultTyped out response))
  | p248 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer8 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer8 .parse environment.options environment.valid typed (resultTyped out response))
  | p249 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p250 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p251 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .integer8 .shiftRightUnsigned typed related)
      (fun out response => integer_fixed_reply_noMint .integer8 .shiftRightUnsigned environment.options environment.valid typed (resultTyped out response))
  | p252 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer8 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer8 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p253 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .integer8 false typed related)
      (fun out response => conversion_fixed_reply_noMint .integer8 false environment.options environment.valid typed (resultTyped out response))
  | p254 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .integer8 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .integer8 .toString environment.options environment.valid typed (resultTyped out response))
  | p255 =>
    exact refined_append_response typed related avoid
  | p256 =>
    exact ordinary_list_response .concatenate typed related avoid
  | p257 =>
    exact remaining_list_response .contains typed related avoid
  | p258 =>
    exact remaining_list_response .drop typed related avoid
  | p259 =>
    exact remaining_list_response .get typed related avoid
  | p260 =>
    exact head_tail_response false typed related avoid
  | p261 =>
    exact ordinary_list_response .isEmpty typed related avoid
  | p262 =>
    exact ordinary_list_response .length typed related avoid
  | p263 =>
    exact ordinary_list_response .prepend typed related avoid
  | p264 =>
    exact ⟨list_range_delta typed related,list_range_noMint⟩
  | p265 =>
    exact ordinary_list_response .reverse typed related avoid
  | p266 =>
    exact remaining_list_response .sort typed related avoid
  | p267 =>
    exact head_tail_response true typed related avoid
  | p268 =>
    exact remaining_list_response .take typed related avoid
  | p269 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p270 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p271 =>
    exact ⟨precision_delta related _ _ _ _ _,precision_delta_noMint avoid _ _ _ _ _⟩
  | p272 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p273 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p274 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p275 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p276 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p277 =>
    exact ⟨precision_delta related _ _ _ _ _,precision_delta_noMint avoid _ _ _ _ _⟩
  | p278 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p279 =>
    cases pure
  | p280 =>
    cases pure
  | p281 =>
    exact ⟨scope_response_delta related "Scope.checkPathIn" ts es rs,scope_response_noMint (name := "Scope.checkPathIn") (ts := ts) (es := es) (rs := rs) avoid⟩
  | p282 =>
    exact ⟨scope_response_delta related "Scope.pathInValue" ts es rs,scope_response_noMint (name := "Scope.pathInValue") (ts := ts) (es := es) (rs := rs) avoid⟩
  | p283 =>
    exact ⟨scope_response_delta related "Scope.widenPathIn" ts es rs,scope_response_noMint (name := "Scope.widenPathIn") (ts := ts) (es := es) (rs := rs) avoid⟩
  | p284 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p285 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p286 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p287 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p288 =>
    exact ⟨precision_delta related _ _ _ _ _,precision_delta_noMint avoid _ _ _ _ _⟩
  | p289 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p290 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p291 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p292 =>
    exact ⟨precision_delta related _ _ _ _ _,precision_delta_noMint avoid _ _ _ _ _⟩
  | p293 =>
    exact ⟨collection_delta related _ _ _ _ _,collection_delta_noMint avoid _ _ _ _ _⟩
  | p294 =>
    exact ⟨string_provider_delta .byteIndexOf typed related,string_table_noMint⟩
  | p295 =>
    exact fixed_inputs_response _ (bytes_inputs_equal .stringBytes typed related)
      (fun out response => bytes_reply_noMint .stringBytes typed (resultTyped out response))
  | p296 =>
    exact ⟨string_provider_delta .byteSlice typed related,string_table_noMint⟩
  | p297 =>
    exact ⟨string_provider_delta .characterAt typed related,string_table_noMint⟩
  | p298 =>
    exact fixed_inputs_response _ (bytes_inputs_equal .stringCharacters typed related)
      (fun out response => bytes_reply_noMint .stringCharacters typed (resultTyped out response))
  | p299 =>
    exact ⟨string_provider_delta .characterSlice typed related,string_table_noMint⟩
  | p300 =>
    exact ⟨string_provider_delta .characters typed related,string_table_noMint⟩
  | p301 =>
    exact ⟨string_provider_delta .contains typed related,string_table_noMint⟩
  | p302 =>
    exact ⟨string_provider_delta .displayWidth typed related,string_table_noMint⟩
  | p303 =>
    exact ⟨string_provider_delta .displayWidthCJK typed related,string_table_noMint⟩
  | p304 =>
    exact ⟨string_provider_delta .displayWidthPadEnd typed related,string_table_noMint⟩
  | p305 =>
    exact ⟨string_provider_delta .displayWidthPadEndCJK typed related,string_table_noMint⟩
  | p306 =>
    exact ⟨string_provider_delta .displayWidthPadStart typed related,string_table_noMint⟩
  | p307 =>
    exact ⟨string_provider_delta .displayWidthPadStartCJK typed related,string_table_noMint⟩
  | p308 =>
    exact ⟨string_provider_delta .endsWith typed related,string_table_noMint⟩
  | p309 =>
    exact ⟨string_provider_delta .fromCharacters typed related,string_table_noMint⟩
  | p310 =>
    exact ⟨string_provider_delta .fromUTF8 typed related,string_table_noMint⟩
  | p311 =>
    exact ⟨string_provider_delta .isEmpty typed related,string_table_noMint⟩
  | p312 =>
    exact ⟨string_provider_delta .join typed related,string_table_noMint⟩
  | p313 =>
    exact ⟨string_provider_delta .lines typed related,string_table_noMint⟩
  | p314 =>
    exact ⟨string_provider_delta .repeat typed related,string_table_noMint⟩
  | p315 =>
    exact ⟨string_provider_delta .replace typed related,string_table_noMint⟩
  | p316 =>
    exact ⟨string_provider_delta .split typed related,string_table_noMint⟩
  | p317 =>
    exact ⟨string_provider_delta .startsWith typed related,string_table_noMint⟩
  | p318 =>
    exact ⟨string_provider_delta .toLowercase typed related,string_table_noMint⟩
  | p319 =>
    exact ⟨string_provider_delta .toUTF8 typed related,string_table_noMint⟩
  | p320 =>
    exact ⟨string_provider_delta .toUppercase typed related,string_table_noMint⟩
  | p321 =>
    exact ⟨string_provider_delta .trim typed related,string_table_noMint⟩
  | p322 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .absolute environment.options environment.valid typed (resultTyped out response))
  | p323 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p324 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p325 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p326 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p327 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p328 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p329 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .unsignedInteger16 true typed related)
      (fun out response => conversion_fixed_reply_noMint .unsignedInteger16 true environment.options environment.valid typed (resultTyped out response))
  | p330 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .unsignedInteger16 true typed related)
      (fun out response => minmax_fixed_reply_noMint .unsignedInteger16 true environment.options environment.valid typed (resultTyped out response))
  | p331 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .unsignedInteger16 false typed related)
      (fun out response => minmax_fixed_reply_noMint .unsignedInteger16 false environment.options environment.valid typed (resultTyped out response))
  | p332 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger16 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger16 .parse environment.options environment.valid typed (resultTyped out response))
  | p333 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p334 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger16 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger16 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p335 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger16 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger16 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p336 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .unsignedInteger16 false typed related)
      (fun out response => conversion_fixed_reply_noMint .unsignedInteger16 false environment.options environment.valid typed (resultTyped out response))
  | p337 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger16 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger16 .toString environment.options environment.valid typed (resultTyped out response))
  | p338 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .absolute environment.options environment.valid typed (resultTyped out response))
  | p339 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p340 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p341 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p342 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p343 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p344 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p345 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .unsignedInteger32 true typed related)
      (fun out response => conversion_fixed_reply_noMint .unsignedInteger32 true environment.options environment.valid typed (resultTyped out response))
  | p346 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .unsignedInteger32 true typed related)
      (fun out response => minmax_fixed_reply_noMint .unsignedInteger32 true environment.options environment.valid typed (resultTyped out response))
  | p347 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .unsignedInteger32 false typed related)
      (fun out response => minmax_fixed_reply_noMint .unsignedInteger32 false environment.options environment.valid typed (resultTyped out response))
  | p348 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger32 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger32 .parse environment.options environment.valid typed (resultTyped out response))
  | p349 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p350 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger32 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger32 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p351 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger32 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger32 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p352 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .unsignedInteger32 false typed related)
      (fun out response => conversion_fixed_reply_noMint .unsignedInteger32 false environment.options environment.valid typed (resultTyped out response))
  | p353 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger32 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger32 .toString environment.options environment.valid typed (resultTyped out response))
  | p354 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .absolute typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .absolute environment.options environment.valid typed (resultTyped out response))
  | p355 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .bitwiseAnd typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .bitwiseAnd environment.options environment.valid typed (resultTyped out response))
  | p356 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .bitwiseExclusiveOr typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .bitwiseExclusiveOr environment.options environment.valid typed (resultTyped out response))
  | p357 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .bitwiseNot typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .bitwiseNot environment.options environment.valid typed (resultTyped out response))
  | p358 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .bitwiseOr typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .bitwiseOr environment.options environment.valid typed (resultTyped out response))
  | p359 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .floorDivide typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .floorDivide environment.options environment.valid typed (resultTyped out response))
  | p360 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .floorModulo typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .floorModulo environment.options environment.valid typed (resultTyped out response))
  | p361 =>
    exact fixed_inputs_response _ (decimal_inputs_equal environment.rounding .fromDecimal typed related)
      (fun out response => decimal_reply_noMint .fromDecimal environment.options environment.valid typed (resultTyped out response))
  | p362 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .unsignedInteger64 true typed related)
      (fun out response => conversion_fixed_reply_noMint .unsignedInteger64 true environment.options environment.valid typed (resultTyped out response))
  | p363 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .unsignedInteger64 true typed related)
      (fun out response => minmax_fixed_reply_noMint .unsignedInteger64 true environment.options environment.valid typed (resultTyped out response))
  | p364 =>
    exact fixed_inputs_response _ (minmax_fixed_inputs_equal .unsignedInteger64 false typed related)
      (fun out response => minmax_fixed_reply_noMint .unsignedInteger64 false environment.options environment.valid typed (resultTyped out response))
  | p365 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger64 .parse typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger64 .parse environment.options environment.valid typed (resultTyped out response))
  | p366 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .shiftLeft typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .shiftLeft environment.options environment.valid typed (resultTyped out response))
  | p367 =>
    exact fixed_inputs_response _ (integer_fixed_inputs_equal .unsignedInteger64 .shiftRight typed related)
      (fun out response => integer_fixed_reply_noMint .unsignedInteger64 .shiftRight environment.options environment.valid typed (resultTyped out response))
  | p368 =>
    exact fixed_inputs_response _ (decimal_inputs_equal environment.rounding .toDecimal typed related)
      (fun out response => decimal_reply_noMint .toDecimal environment.options environment.valid typed (resultTyped out response))
  | p369 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger64 .toFloat typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger64 .toFloat environment.options environment.valid typed (resultTyped out response))
  | p370 =>
    exact fixed_inputs_response _ (conversion_fixed_inputs_equal .unsignedInteger64 false typed related)
      (fun out response => conversion_fixed_reply_noMint .unsignedInteger64 false environment.options environment.valid typed (resultTyped out response))
  | p371 =>
    exact fixed_inputs_response _ (integer_text_fixed_inputs_equal .unsignedInteger64 .toString typed related)
      (fun out response => integer_text_fixed_reply_noMint .unsignedInteger64 .toString environment.options environment.valid typed (resultTyped out response))
  | p372 =>
    cases pure
  | p373 =>
    cases pure
  | p374 =>
    cases pure
  | p375 =>
    cases pure
  | p376 =>
    cases pure
  | p377 =>
    exact safe_front_response typed related avoid
  | p378 =>
    exact ⟨public_predicate_provider_delta (.path) typed related,public_predicate_noMint (.path)⟩
  | p379 =>
    exact ⟨public_predicate_provider_delta (.host) typed related,public_predicate_noMint (.host)⟩
  | p380 =>
    exact ⟨public_predicate_provider_delta (.characters) typed related,public_predicate_noMint (.characters)⟩
  | p381 =>
    exact ⟨public_predicate_provider_delta (.floating .binary64 .finite) typed related,public_predicate_noMint (.floating .binary64 .finite)⟩
  | p382 =>
    exact ⟨public_predicate_provider_delta (.floating .binary64 .infinite) typed related,public_predicate_noMint (.floating .binary64 .infinite)⟩
  | p383 =>
    exact ⟨public_predicate_provider_delta (.floating .binary64 .positiveInfinity) typed related,public_predicate_noMint (.floating .binary64 .positiveInfinity)⟩
  | p384 =>
    exact ⟨public_predicate_provider_delta (.floating .binary64 .negativeInfinity) typed related,public_predicate_noMint (.floating .binary64 .negativeInfinity)⟩
  | p385 =>
    exact ⟨public_predicate_provider_delta (.floating .binary64 .positiveZero) typed related,public_predicate_noMint (.floating .binary64 .positiveZero)⟩
  | p386 =>
    exact ⟨public_predicate_provider_delta (.floating .binary64 .negativeZero) typed related,public_predicate_noMint (.floating .binary64 .negativeZero)⟩
  | p387 =>
    exact ⟨public_predicate_provider_delta (.floating .binary32 .finite) typed related,public_predicate_noMint (.floating .binary32 .finite)⟩
  | p388 =>
    exact ⟨public_predicate_provider_delta (.floating .binary32 .positiveInfinity) typed related,public_predicate_noMint (.floating .binary32 .positiveInfinity)⟩
  | p389 =>
    exact ⟨public_predicate_provider_delta (.floating .binary32 .negativeInfinity) typed related,public_predicate_noMint (.floating .binary32 .negativeInfinity)⟩
  | p390 =>
    exact ⟨public_predicate_provider_delta (.floating .binary32 .positiveZero) typed related,public_predicate_noMint (.floating .binary32 .positiveZero)⟩
  | p391 =>
    exact ⟨public_predicate_provider_delta (.floating .binary32 .negativeZero) typed related,public_predicate_noMint (.floating .binary32 .negativeZero)⟩
  | p392 =>
    exact ⟨check_delta related _ _ _ _ _,check_delta_noMint avoid _ _ _ _ _⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
