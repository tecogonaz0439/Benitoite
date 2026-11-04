# 段末の実際の署名（続き）

## Benitoite.Release.Refinement.StandardDecode.postprocess_raw_steps

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} (lo hi : Benitoite.Release.Integer64Value)
  (k : Benitoite.Release.Refinement.Cont) (μ : Benitoite.Release.Refinement.Store),
  Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
    Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
    (Benitoite.Release.Refinement.State.run
      (Benitoite.Release.Refinement.Closure.mk
        (Benitoite.Release.Refinement.Capture.empty.extend
          (Benitoite.Release.Refinement.Val.con "Result.Ok"
            [Benitoite.Release.Refinement.StandardDecode.rawType✝,
              Benitoite.Release.Refinement.StandardDecode.errorType✝]
            [Benitoite.Release.Refinement.Val.con "Raw.Make" []
                [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer lo),
                  Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer hi)]]))
        Benitoite.Release.Refinement.StandardDecode.postprocessBody)
      k μ)
    []
    (Benitoite.Release.Refinement.State.run
      (Benitoite.Release.Refinement.Closure.mk (Benitoite.Release.Refinement.StandardDecode.rawCapture✝ lo hi)
        Benitoite.Release.Refinement.StandardDecode.checksBody)
      k μ)
```

## Benitoite.Release.Refinement.StandardDecode.postprocess_row_typed

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
Benitoite.Release.Refinement.StandardDecode.postprocessRow.BodyTyped
  Benitoite.Release.Refinement.StandardDecode.recordProgram Benitoite.Release.Refinement.StandardDecode.recordBuiltins
```

## Benitoite.Release.Refinement.StandardDecode.postprocess_wellTyped

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
Benitoite.Release.Refinement.Def.WellTyped Benitoite.Release.Refinement.StandardDecode.recordProgram
  Benitoite.Release.Refinement.StandardDecode.recordBuiltins
  Benitoite.Release.Refinement.StandardDecode.postprocessDefinition
```

## Benitoite.Release.Refinement.StandardFactExamples.false_fact_typing

所在: `formal/Benitoite/Release/Refinement/StandardFactExamples.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty []
    Benitoite.Release.Refinement.StandardFactExamples.booleanContext✝
    [Benitoite.Release.Refinement.boolCond (Benitoite.Release.Refinement.Term.var 0) false] none
    Benitoite.Release.Refinement.StandardFactExamples.falseBody✝
    Benitoite.Release.Refinement.StandardFactExamples.falseType✝ Benitoite.Release.Refinement.Eff.empty
```

## Benitoite.Release.Refinement.StandardFactExamples.false_if_typing

所在: `formal/Benitoite/Release/Refinement/StandardFactExamples.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty []
    Benitoite.Release.Refinement.StandardFactExamples.booleanContext✝ [] none
    Benitoite.Release.Refinement.StandardFactExamples.falseIf✝
    Benitoite.Release.Refinement.StandardFactExamples.falseType✝ Benitoite.Release.Refinement.Eff.empty
```

## Benitoite.Release.Refinement.StandardFactExamples.guard_body_typing

所在: `formal/Benitoite/Release/Refinement/StandardFactExamples.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.HasTypeCQ P B Ψ Benitoite.Release.Qempty []
    Benitoite.Release.Refinement.StandardFactExamples.booleanContext✝
    [Benitoite.Release.Refinement.StandardFactExamples.guardPredicate✝.open
        (Benitoite.Release.Refinement.Term.boolean true)]
    none Benitoite.Release.Refinement.StandardFactExamples.falseBody✝
    Benitoite.Release.Refinement.StandardFactExamples.falseType✝ Benitoite.Release.Refinement.Eff.empty
```

## Benitoite.Release.Refinement.StandardFactExamples.length_le

所在: `formal/Benitoite/Release/Refinement/StandardFactExamples.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Ty.LeQ P Benitoite.Release.Refinement.StandardFactExamples.lengthContext✝
    [Benitoite.Release.Refinement.StandardFactExamples.positiveN✝]
    Benitoite.Release.Refinement.StandardFactExamples.lengthSource✝
    Benitoite.Release.Refinement.StandardFactExamples.lengthTarget✝
```

## Benitoite.Release.Refinement.StandardScalar.float32_compare_reply

所在: `formal/Benitoite/Release/Refinement/StandardFloat.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (η : Benitoite.Release.Refinement.ObservationEnvModel) (a b : UInt32)
  (op : Benitoite.Release.Refinement.Comparison),
  ∃ value,
    Benitoite.Release.Refinement.StandardScalar.float32Delta
          (Benitoite.Release.Refinement.StandardScalar.float32CompareName op)
          (Benitoite.Release.Refinement.StandardScalar.comparisonTypes Benitoite.Release.BaseTy.float32 op) [] []
          [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.float32 a),
            Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.float32 b)] =
        some
          (Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean value))) ∧
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean value))
          (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean) ∧
        Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.Pred.compare Benitoite.Release.Refinement.Sort.float32 op
              (Benitoite.Release.Refinement.Term.float32 a) (Benitoite.Release.Refinement.Term.float32 b)) =
          value
```

## Benitoite.Release.Refinement.StandardScalar.float64_compare_reply

所在: `formal/Benitoite/Release/Refinement/StandardFloat.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy) (η : Benitoite.Release.Refinement.ObservationEnvModel) (a b : UInt64)
  (op : Benitoite.Release.Refinement.Comparison),
  ∃ value,
    Benitoite.Release.Refinement.StandardScalar.float64Delta
          (Benitoite.Release.Refinement.StandardScalar.float64CompareName op)
          (Benitoite.Release.Refinement.StandardScalar.comparisonTypes Benitoite.Release.BaseTy.float op) [] []
          [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.float64 a),
            Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.float64 b)] =
        some
          (Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean value))) ∧
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
          (Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean value))
          (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.boolean) ∧
        Benitoite.Release.Refinement.Pred.interpret η
            (Benitoite.Release.Refinement.Pred.compare Benitoite.Release.Refinement.Sort.float64 op
              (Benitoite.Release.Refinement.Term.float64 a) (Benitoite.Release.Refinement.Term.float64 b)) =
          value
```

## Benitoite.Release.Refinement.StandardFloatMathResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardFloatMathResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (single : Bool)
  (api : Benitoite.Release.Refinement.StandardFloatMathResponse.API),
  P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
    P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
      P.DataArity "Option" 1 →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ
            (Benitoite.Release.Refinement.StandardFloatMathResponse.name single api)
            (Benitoite.Release.Refinement.StandardFloatMathResponse.signature single api) ts es rs ws a e →
          ∃ out,
            Benitoite.Release.Refinement.StandardFloatMathResponse.delta single api
                  (Benitoite.Release.Refinement.StandardFloatMathResponse.name single api) ts es rs ws =
                some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardHeadTail.concrete_nonempty_public_typed

所在: `formal/Benitoite/Release/Refinement/StandardHeadTailBodies.lean`

```lean
Benitoite.Release.Refinement.StandardHeadTail.nonemptyPublicRow.BodyTyped
  Benitoite.Release.Refinement.StandardHeadTail.program Benitoite.Release.Refinement.StandardHeadTail.builtins
```

## Benitoite.Release.Refinement.StandardHeadTail.from_typed

所在: `formal/Benitoite/Release/Refinement/StandardHeadTailBodies.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.StandardHeadTail.Inputs P B →
    ∀ (filter : Bool), (Benitoite.Release.Refinement.StandardHeadTail.fromRow filter).BodyTyped P B
```

## Benitoite.Release.Refinement.StandardHigherPositions.callback_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.StandardHigherPositions.PositionChecked P B Ψ
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.I
      Benitoite.Release.Refinement.StandardHigherPositions.U)
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.R
      Benitoite.Release.Refinement.StandardHigherPositions.U)
```

## Benitoite.Release.Refinement.StandardHigherPositions.consumer_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.StandardHigherPositions.PositionChecked
    Benitoite.Release.Refinement.StandardHigherPositions.consumerProgram B Ψ
    (Benitoite.Release.Refinement.Ty.data "Consumer" [Benitoite.Release.Refinement.StandardHigherPositions.I])
    (Benitoite.Release.Refinement.Ty.data "Consumer" [Benitoite.Release.Refinement.StandardHigherPositions.R])
```

## Benitoite.Release.Refinement.StandardHigherPositions.dep_apply

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  ∃ r e,
    Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Benitoite.Release.Qempty [] [] []
        [Benitoite.Release.Refinement.StandardHigherPositions.v2,
          Benitoite.Release.Refinement.StandardHigherPositions.v5]
        (Benitoite.Release.Refinement.StandardHigherPositions.depTel false) r e ∧
      Benitoite.Release.Refinement.Ty.LeQ P [] [] r Benitoite.Release.Refinement.StandardHigherPositions.r25 ∧
        Benitoite.Release.Refinement.Eff.Covers [] []
          (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.r25) e
```

## Benitoite.Release.Refinement.StandardHigherPositions.effect_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.StandardHigherPositions.PositionChecked P B Ψ
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.U
      Benitoite.Release.Refinement.StandardHigherPositions.U)
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.U
      Benitoite.Release.Refinement.StandardHigherPositions.U
      (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.I))
```

## Benitoite.Release.Refinement.StandardHigherPositions.fail_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.Eff.Covers [] []
      (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.FunctionView)
      (Benitoite.Release.Refinement.Eff.singleFail
        (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.I
          Benitoite.Release.Refinement.StandardHigherPositions.U)) ∧
    ¬Benitoite.Release.Refinement.Eff.Covers [] []
          (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.I)
          (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.R) ∧
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
          [some
              (Benitoite.Release.Refinement.StandardHigherPositions.F
                Benitoite.Release.Refinement.StandardHigherPositions.U
                Benitoite.Release.Refinement.StandardHigherPositions.U
                (Benitoite.Release.Refinement.Eff.singleFail
                  (Benitoite.Release.Refinement.StandardHigherPositions.F
                    Benitoite.Release.Refinement.StandardHigherPositions.I
                    Benitoite.Release.Refinement.StandardHigherPositions.U)))]
          [] (Benitoite.Release.Refinement.Val.var 0)
          (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.U
            Benitoite.Release.Refinement.StandardHigherPositions.U
            (Benitoite.Release.Refinement.Eff.singleFail
              Benitoite.Release.Refinement.StandardHigherPositions.FunctionView)) ∧
        ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
            [some
                (Benitoite.Release.Refinement.StandardHigherPositions.F
                  Benitoite.Release.Refinement.StandardHigherPositions.U
                  Benitoite.Release.Refinement.StandardHigherPositions.U
                  (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.R))]
            [] (Benitoite.Release.Refinement.Val.var 0)
            (Benitoite.Release.Refinement.StandardHigherPositions.F
              Benitoite.Release.Refinement.StandardHigherPositions.U
              Benitoite.Release.Refinement.StandardHigherPositions.U
              (Benitoite.Release.Refinement.Eff.singleFail Benitoite.Release.Refinement.StandardHigherPositions.I))
```

## Benitoite.Release.Refinement.StandardHigherPositions.length_all_images

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Ty.LeQ P Benitoite.Release.Refinement.OpenSubstitution.Δ
    Benitoite.Release.Refinement.OpenSubstitution.Ψ
    (Benitoite.Release.Refinement.Ty.bind Benitoite.Release.Refinement.OpenSubstitution.θ
      Benitoite.Release.Refinement.StandardHigherPositions.nSource)
    (Benitoite.Release.Refinement.Ty.bind Benitoite.Release.Refinement.OpenSubstitution.θ
      (Benitoite.Release.Refinement.nonemptyType Benitoite.Release.Refinement.StandardHigherPositions.U))
```

## Benitoite.Release.Refinement.StandardHigherPositions.list_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.StandardHigherPositions.PositionChecked P B Ψ
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.I
        Benitoite.Release.Refinement.StandardHigherPositions.R).list
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.R
        Benitoite.Release.Refinement.StandardHigherPositions.I).list
```

## Benitoite.Release.Refinement.StandardHigherPositions.names_arity_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  (Benitoite.Release.Refinement.NamesWF ["value"] [Benitoite.Release.Refinement.StandardHigherPositions.I] ∧
      Benitoite.Release.Refinement.NamesWF ["other"] [Benitoite.Release.Refinement.StandardHigherPositions.I] ∧
        Benitoite.Release.Refinement.NamesWF ["value", "extra"]
          [Benitoite.Release.Refinement.StandardHigherPositions.I,
            Benitoite.Release.Refinement.StandardHigherPositions.U]) ∧
    Benitoite.Release.Refinement.Ty.Annotation P []
        [some
            (Benitoite.Release.Refinement.StandardHigherPositions.F
              Benitoite.Release.Refinement.StandardHigherPositions.I
              Benitoite.Release.Refinement.StandardHigherPositions.U)]
        (Benitoite.Release.Refinement.Ty.fn ["other"] [Benitoite.Release.Refinement.StandardHigherPositions.I]
          Benitoite.Release.Refinement.StandardHigherPositions.U Benitoite.Release.Refinement.Eff.empty) ∧
      Benitoite.Release.Refinement.Ty.Annotation P []
          [some
              (Benitoite.Release.Refinement.StandardHigherPositions.F
                Benitoite.Release.Refinement.StandardHigherPositions.I
                Benitoite.Release.Refinement.StandardHigherPositions.U)]
          (Benitoite.Release.Refinement.Ty.fn ["value", "extra"]
            [Benitoite.Release.Refinement.StandardHigherPositions.I,
              Benitoite.Release.Refinement.StandardHigherPositions.U]
            Benitoite.Release.Refinement.StandardHigherPositions.U Benitoite.Release.Refinement.Eff.empty) ∧
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
            [some
                (Benitoite.Release.Refinement.StandardHigherPositions.F
                  Benitoite.Release.Refinement.StandardHigherPositions.I
                  Benitoite.Release.Refinement.StandardHigherPositions.U)]
            [] (Benitoite.Release.Refinement.Val.var 0)
            Benitoite.Release.Refinement.StandardHigherPositions.FunctionView ∧
          ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
                [some
                    (Benitoite.Release.Refinement.StandardHigherPositions.F
                      Benitoite.Release.Refinement.StandardHigherPositions.I
                      Benitoite.Release.Refinement.StandardHigherPositions.U)]
                [] (Benitoite.Release.Refinement.Val.var 0)
                (Benitoite.Release.Refinement.Ty.fn ["other"] [Benitoite.Release.Refinement.StandardHigherPositions.I]
                  Benitoite.Release.Refinement.StandardHigherPositions.U Benitoite.Release.Refinement.Eff.empty) ∧
            ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
                [some
                    (Benitoite.Release.Refinement.StandardHigherPositions.F
                      Benitoite.Release.Refinement.StandardHigherPositions.I
                      Benitoite.Release.Refinement.StandardHigherPositions.U)]
                [] (Benitoite.Release.Refinement.Val.var 0)
                (Benitoite.Release.Refinement.Ty.fn ["value", "extra"]
                  [Benitoite.Release.Refinement.StandardHigherPositions.I,
                    Benitoite.Release.Refinement.StandardHigherPositions.U]
                  Benitoite.Release.Refinement.StandardHigherPositions.U Benitoite.Release.Refinement.Eff.empty)
```

## Benitoite.Release.Refinement.StandardHigherPositions.option_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.StandardHigherPositions.PositionChecked
    Benitoite.Release.Refinement.StandardVariance.program B Ψ
    (Benitoite.Release.Refinement.Ty.data "Option" [Benitoite.Release.Refinement.StandardHigherPositions.R])
    (Benitoite.Release.Refinement.Ty.data "Option" [Benitoite.Release.Refinement.StandardHigherPositions.I])
```

## Benitoite.Release.Refinement.StandardHigherPositions.reference_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  (Benitoite.Release.Refinement.Ty.Annotation P []
        [some
            (Benitoite.Release.Refinement.StandardHigherPositions.F
                Benitoite.Release.Refinement.StandardHigherPositions.I
                Benitoite.Release.Refinement.StandardHigherPositions.U).reference]
        (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.I
            Benitoite.Release.Refinement.StandardHigherPositions.U).reference ∧
      Benitoite.Release.Refinement.Ty.Annotation P []
        [some
            (Benitoite.Release.Refinement.StandardHigherPositions.F
                Benitoite.Release.Refinement.StandardHigherPositions.I
                Benitoite.Release.Refinement.StandardHigherPositions.U).reference]
        Benitoite.Release.Refinement.StandardHigherPositions.FunctionView.reference) ∧
    (Benitoite.Release.Refinement.Ty.Annotation P []
          [some Benitoite.Release.Refinement.StandardHigherPositions.R.reference]
          Benitoite.Release.Refinement.StandardHigherPositions.R.reference ∧
        Benitoite.Release.Refinement.Ty.Annotation P []
          [some Benitoite.Release.Refinement.StandardHigherPositions.R.reference]
          Benitoite.Release.Refinement.StandardHigherPositions.I.reference) ∧
      Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
          [some
              (Benitoite.Release.Refinement.StandardHigherPositions.F
                  Benitoite.Release.Refinement.StandardHigherPositions.I
                  Benitoite.Release.Refinement.StandardHigherPositions.U).reference]
          [] (Benitoite.Release.Refinement.Val.var 0)
          Benitoite.Release.Refinement.StandardHigherPositions.FunctionView.reference ∧
        ¬Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty []
            [some Benitoite.Release.Refinement.StandardHigherPositions.R.reference] []
            (Benitoite.Release.Refinement.Val.var 0) Benitoite.Release.Refinement.StandardHigherPositions.I.reference
```

## Benitoite.Release.Refinement.StandardHigherPositions.result_checked

所在: `formal/Benitoite/Release/Refinement/StandardHigherPositions.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins)
  (Ψ : Benitoite.Release.Refinement.StoreTy),
  Benitoite.Release.Refinement.StandardHigherPositions.PositionChecked P B Ψ
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.U
      Benitoite.Release.Refinement.StandardHigherPositions.R)
    (Benitoite.Release.Refinement.StandardHigherPositions.F Benitoite.Release.Refinement.StandardHigherPositions.U
      Benitoite.Release.Refinement.StandardHigherPositions.I)
```

## Benitoite.Release.Refinement.StandardScalar.integerDelta_absolute

所在: `formal/Benitoite/Release/Refinement/StandardInteger.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (a : Benitoite.Interval.IntegerValue k),
  Benitoite.Release.Refinement.StandardScalar.integerDelta
      (Benitoite.Release.Refinement.StandardScalar.integerModule k ++ ".absolute") [] [] []
      [Benitoite.Release.Refinement.Val.const
          (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k a))] =
    some (Benitoite.Release.Refinement.StandardScalar.integerAbsoluteDelta k a)
```

## Benitoite.Release.Refinement.StandardScalar.integerDelta_binary_facts

所在: `formal/Benitoite/Release/Refinement/StandardInteger.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  P.VarianceValid →
    ∀ (B : Benitoite.Release.Refinement.Builtins) (Ψ : Benitoite.Release.Refinement.StoreTy)
      (k : Benitoite.Interval.IntKind) (op : Benitoite.Interval.WidthBinary)
      (a b v : Benitoite.Interval.IntegerValue k),
      op = Benitoite.Interval.WidthBinary.add ∨
          op = Benitoite.Interval.WidthBinary.sub ∨ op = Benitoite.Interval.WidthBinary.mul →
        op.apply k a b = Benitoite.Interval.OperationResult.normal (Benitoite.Interval.ConcreteValue.ofInteger k v) →
          Benitoite.Release.Refinement.StandardScalar.integerDelta
                (Benitoite.Release.Refinement.StandardScalar.integerBinaryName✝ k op) [] [] []
                [Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
                  Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k b))] =
              some
                (Benitoite.Release.Refinement.Outcome.val
                  (Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))) ∧
            Benitoite.Release.Refinement.HasTypeVQ P B Ψ Benitoite.Release.Qempty [] [] []
                (Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))
                (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)).type ∧
              Benitoite.Release.Refinement.Entails []
                (Benitoite.Release.Refinement.NormalResultLeaves.leaf op a.toInt b.toInt v.toInt).predicate
```

## Benitoite.Release.Refinement.StandardScalar.integerDelta_bitwise

所在: `formal/Benitoite/Release/Refinement/StandardInteger.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (op : Benitoite.Release.Refinement.StandardScalar.IntegerBits)
  (a b : Benitoite.Interval.IntegerValue k),
  op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.bitwiseAnd ∨
      op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.bitwiseOr ∨
        op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.bitwiseExclusiveOr →
    Benitoite.Release.Refinement.StandardScalar.integerDelta
        (Benitoite.Release.Refinement.StandardScalar.integerBitsName✝ k op) [] [] []
        [Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
          Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k b))] =
      some (Benitoite.Release.Refinement.StandardScalar.integerBitsDelta k op a b 0)
```

## Benitoite.Release.Refinement.StandardScalar.integerDelta_floor

所在: `formal/Benitoite/Release/Refinement/StandardInteger.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (modulo : Bool) (a b : Benitoite.Interval.IntegerValue k),
  Benitoite.Release.Refinement.StandardScalar.integerDelta
      (Benitoite.Release.Refinement.StandardScalar.integerModule k ++
        if modulo = true then ".floorModulo" else ".floorDivide")
      [] [] []
      [Benitoite.Release.Refinement.Val.const
          (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
        Benitoite.Release.Refinement.Val.const
          (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k b))] =
    some (Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k modulo a b)
```

## Benitoite.Release.Refinement.StandardScalar.integerDelta_minMax

所在: `formal/Benitoite/Release/Refinement/StandardInteger.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (maximum : Bool) (a b : Benitoite.Interval.IntegerValue k),
  Benitoite.Release.Refinement.StandardScalar.integerDelta
      (Benitoite.Release.Refinement.StandardScalar.integerModule k ++ if maximum = true then ".maximum" else ".minimum")
      [] [] []
      [Benitoite.Release.Refinement.Val.const
          (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
        Benitoite.Release.Refinement.Val.const
          (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k b))] =
    some (Benitoite.Release.Refinement.StandardScalar.integerMinMaxDelta k maximum a b)
```

## Benitoite.Release.Refinement.StandardScalar.integerDelta_shift

所在: `formal/Benitoite/Release/Refinement/StandardInteger.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (op : Benitoite.Release.Refinement.StandardScalar.IntegerBits)
  (a : Benitoite.Interval.IntegerValue k) (count : Benitoite.Release.Integer64Value),
  op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftLeft ∨
      op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftRight ∨
        op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftRightUnsigned →
    (op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftRightUnsigned → k.min < 0) →
      Benitoite.Release.Refinement.StandardScalar.integerDelta
          (Benitoite.Release.Refinement.StandardScalar.integerBitsName✝ k op) [] [] []
          [Benitoite.Release.Refinement.Val.const
              (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
            Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer count)] =
        some (Benitoite.Release.Refinement.StandardScalar.integerBitsDelta k op a a count.toInt)
```

## Benitoite.Release.Refinement.StandardScalar.binary_delta_split

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (op : Benitoite.Interval.WidthBinary) (a b : Benitoite.Interval.IntegerValue k)
  (supported :
    op = Benitoite.Interval.WidthBinary.add ∨
      op = Benitoite.Interval.WidthBinary.sub ∨ op = Benitoite.Interval.WidthBinary.mul),
  (∃ v,
      Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k op a b =
          Benitoite.Release.Refinement.Outcome.val
            (Benitoite.Release.Refinement.Val.const
              (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v))) ∧
        Benitoite.Release.Refinement.IntervalConnection.ValueRel (Benitoite.Interval.ConcreteValue.ofInteger k v)
          (Benitoite.Release.Refinement.Val.const
            (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))) ∨
    Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k op a b =
        Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ∧
      ((match op, supported with
          | Benitoite.Interval.WidthBinary.add, supported => a.toInt + b.toInt
          | Benitoite.Interval.WidthBinary.sub, supported => a.toInt - b.toInt
          | x, supported => a.toInt * b.toInt) <
          k.min ∨
        k.max <
          match op, supported with
          | Benitoite.Interval.WidthBinary.add, supported => a.toInt + b.toInt
          | Benitoite.Interval.WidthBinary.sub, supported => a.toInt - b.toInt
          | x, supported => a.toInt * b.toInt)
```

## Benitoite.Release.Refinement.StandardScalar.divMod_delta_split

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (a b : Benitoite.Interval.IntegerValue k) (modulo : Bool),
  if modulo = true then
    Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.mod a b =
        Benitoite.Release.Refinement.Outcome.err "DivisionByZero" ∨
      ∃ v,
        v.toInt = a.toInt.tmod b.toInt ∧
          Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.mod a b =
              Benitoite.Release.Refinement.Outcome.val
                (Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v))) ∧
            Benitoite.Release.Refinement.IntervalConnection.ValueRel (Benitoite.Interval.ConcreteValue.ofInteger k v)
              (Benitoite.Release.Refinement.Val.const
                (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))
  else
    Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.intDiv a b =
        Benitoite.Release.Refinement.Outcome.err "DivisionByZero" ∨
      Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.intDiv a b =
            Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ∧
          (a.toInt.tdiv b.toInt < k.min ∨ k.max < a.toInt.tdiv b.toInt) ∨
        ∃ v,
          v.toInt = a.toInt.tdiv b.toInt ∧
            Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.intDiv a b =
                Benitoite.Release.Refinement.Outcome.val
                  (Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v))) ∧
              Benitoite.Release.Refinement.IntervalConnection.ValueRel (Benitoite.Interval.ConcreteValue.ofInteger k v)
                (Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))
```

## Benitoite.Release.Refinement.StandardScalar.division_overflow_iff

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (a b : Benitoite.Interval.IntegerValue k),
  b.toInt ≠ 0 →
    (Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.intDiv a b =
        Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ↔
      k.min < 0 ∧ a.toInt = k.min ∧ b.toInt = -1)
```

## Benitoite.Release.Refinement.StandardScalar.floorModulo_normal

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (a b : Benitoite.Interval.IntegerValue k),
  b.toInt ≠ 0 →
    ∃ v,
      v.toInt = Benitoite.Release.Refinement.StandardIntegerAPI.floorNumber true a.toInt b.toInt ∧
        Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k true a b =
            Benitoite.Release.Refinement.Outcome.val
              (Benitoite.Release.Refinement.Val.const
                (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v))) ∧
          Benitoite.Release.Refinement.IntervalConnection.ValueRel (Benitoite.Interval.ConcreteValue.ofInteger k v)
            (Benitoite.Release.Refinement.Val.const
              (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))
```

## Benitoite.Release.Refinement.StandardScalar.floor_delta_split

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (modulo : Bool) (a b : Benitoite.Interval.IntegerValue k),
  b.toInt = 0 ∧
      Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k modulo a b =
        Benitoite.Release.Refinement.Outcome.err "DivisionByZero" ∨
    b.toInt ≠ 0 ∧
      ((∃ v,
          v.toInt = Benitoite.Release.Refinement.StandardIntegerAPI.floorNumber modulo a.toInt b.toInt ∧
            Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k modulo a b =
                Benitoite.Release.Refinement.Outcome.val
                  (Benitoite.Release.Refinement.Val.const
                    (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v))) ∧
              Benitoite.Release.Refinement.IntervalConnection.ValueRel (Benitoite.Interval.ConcreteValue.ofInteger k v)
                (Benitoite.Release.Refinement.Val.const
                  (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))) ∨
        Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k modulo a b =
            Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ∧
          (Benitoite.Release.Refinement.StandardIntegerAPI.floorNumber modulo a.toInt b.toInt < k.min ∨
            k.max < Benitoite.Release.Refinement.StandardIntegerAPI.floorNumber modulo a.toInt b.toInt))
```

## Benitoite.Release.Refinement.StandardScalar.shift_outside

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind) (op : Benitoite.Release.Refinement.StandardScalar.IntegerBits)
  (a b : Benitoite.Interval.IntegerValue k) (count : Int),
  op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftLeft ∨
      op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftRight ∨
        op = Benitoite.Release.Refinement.StandardScalar.IntegerBits.shiftRightUnsigned →
    count < 0 ∨ ↑(Benitoite.Release.Refinement.StandardScalar.integerWidth k) ≤ count →
      Benitoite.Release.Refinement.StandardScalar.integerBitsDelta k op a b count =
        Benitoite.Release.Refinement.Outcome.err "ArgumentOutOfDomain"
```

## Benitoite.Release.Refinement.StandardScalar.signed_minimum_stops

所在: `formal/Benitoite/Release/Refinement/StandardIntegerFailure.lean`

```lean
∀ (k : Benitoite.Interval.IntKind),
  k.min < 0 →
    ∀ (a b : Benitoite.Interval.IntegerValue k),
      a.toInt = k.min →
        b.toInt = -1 →
          Benitoite.Release.Refinement.StandardScalar.integerAbsoluteDelta k a =
              Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ∧
            Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k false a b =
                Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ∧
              Benitoite.Release.Refinement.StandardScalar.integerBinaryDelta k Benitoite.Interval.WidthBinary.intDiv a
                    b =
                  Benitoite.Release.Refinement.Outcome.err "IntegerOverflow" ∧
                ∃ v,
                  v.toInt = 0 ∧
                    Benitoite.Release.Refinement.StandardScalar.integerFloorDelta k true a b =
                      Benitoite.Release.Refinement.Outcome.val
                        (Benitoite.Release.Refinement.Val.const
                          (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k v)))
```

## Benitoite.Release.Refinement.StandardIntegerResponse.minMax_response

所在: `formal/Benitoite/Release/Refinement/StandardIntegerResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (k : Benitoite.Interval.IntKind) (maximum : Bool),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ
      (Benitoite.Release.Refinement.StandardIntegerResponse.minMaxName k maximum)
      (Benitoite.Release.Refinement.StandardIntegerResponse.minMaxSig k) ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardScalar.integerDelta
            (Benitoite.Release.Refinement.StandardIntegerResponse.minMaxName k maximum) ts es rs ws =
          some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            (∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i) ∧
              ∃ left right,
                ws =
                    [Benitoite.Release.Refinement.Val.const
                        (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k left)),
                      Benitoite.Release.Refinement.Val.const
                        (Benitoite.Release.Refinement.embedConst (Benitoite.Interval.IntegerValue.toConst k right))] ∧
                  Benitoite.Release.Refinement.StandardScalar.integerMinMaxDelta k maximum left right = out ∧
                    ∃ value,
                      out =
                          Benitoite.Release.Refinement.Outcome.val
                            (Benitoite.Release.Refinement.Val.const
                              (Benitoite.Release.Refinement.embedConst
                                (Benitoite.Interval.IntegerValue.toConst k value))) ∧
                        value.toInt = if maximum = true then max left.toInt right.toInt else min left.toInt right.toInt
```

## Benitoite.Release.Refinement.StandardIntegerTextResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardIntegerTextResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (k : Benitoite.Interval.IntKind)
  (api : Benitoite.Release.Refinement.StandardIntegerTextResponse.API),
  P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
    P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
      P.DataArity "Option" 1 →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ
            (Benitoite.Release.Refinement.StandardIntegerTextResponse.name k api)
            (Benitoite.Release.Refinement.StandardIntegerTextResponse.signature k api) ts es rs ws a e →
          ∃ out,
            Benitoite.Release.Refinement.StandardIntegerTextResponse.delta k api
                  (Benitoite.Release.Refinement.StandardIntegerTextResponse.name k api) ts es rs ws =
                some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardKeyTyping.key_closed_slots

所在: `formal/Benitoite/Release/Refinement/StandardKeySound.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q [] [] [] vs a →
      B.sat [] a.norm Benitoite.Release.TParam.keyC →
        Benitoite.Release.Refinement.Key.ClosedSlots (Benitoite.Release.Refinement.Val.toTermSlots vs)
```

## Benitoite.Release.Refinement.StandardKeyTyping.key_each_sound

所在: `formal/Benitoite/Release/Refinement/StandardKeySound.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {vs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q [] [] [] vs a →
      B.sat [] a.norm Benitoite.Release.TParam.keyC →
        ∀ (η : Benitoite.Release.Refinement.ObservationEnvModel),
          Benitoite.Release.Refinement.Observation.KeySlots
            (List.map (fun t => t.bind (Benitoite.Release.Refinement.Term.observe η))
              (Benitoite.Release.Refinement.Val.toTermSlots vs))
```

## Benitoite.Release.Refinement.StandardKeyTyping.key_map_normal

所在: `formal/Benitoite/Release/Refinement/StandardKeySound.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {ks : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q [] [] [] ks a →
      B.sat [] a.norm Benitoite.Release.TParam.keyC →
        ∀ (vs : List Benitoite.Release.Refinement.Val),
          ks.length = vs.length →
            ∃ entries,
              Benitoite.Release.Refinement.Key.normalizeMap (Benitoite.Release.Refinement.Val.toTermSlots ks)
                  (Benitoite.Release.Refinement.Val.toTermSlots vs) =
                some entries
```

## Benitoite.Release.Refinement.StandardKeyTyping.key_set_normal

所在: `formal/Benitoite/Release/Refinement/StandardKeySound.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {xs : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeEachQ P B Ψ Q [] [] [] xs a →
      B.sat [] a.norm Benitoite.Release.TParam.keyC →
        ∃ entries,
          Benitoite.Release.Refinement.Key.normalizeSet (Benitoite.Release.Refinement.Val.toTermSlots xs) = some entries
```

## Benitoite.Release.Refinement.StandardKeyTyping.key_table_sound

所在: `formal/Benitoite/Release/Refinement/StandardKeySound.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    ∀ {a : Benitoite.Release.Refinement.Ty},
      B.sat [] a.norm Benitoite.Release.TParam.keyC →
        Benitoite.Release.Refinement.StandardKeyTyping.KeyObservation P B a
```

## Benitoite.Release.Refinement.StandardKeyTyping.key_values_sound

所在: `formal/Benitoite/Release/Refinement/StandardKeySound.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {vs : List Benitoite.Release.Refinement.Val} {as : List Benitoite.Release.Refinement.Ty}
  (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q [] [] [] vs as →
      (∀ (a : Benitoite.Release.Refinement.Ty), a ∈ as → B.sat [] a.norm Benitoite.Release.TParam.keyC) →
        ∀ (η : Benitoite.Release.Refinement.ObservationEnvModel),
          Benitoite.Release.Refinement.Observation.KeySlots
            (List.map (fun t => t.bind (Benitoite.Release.Refinement.Term.observe η))
              (Benitoite.Release.Refinement.Val.toTermSlots vs))
```

## Benitoite.Release.Refinement.StandardListRemainingResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardListRemainingResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {r : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardListRemainingResponse.API),
  P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
    P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
      P.DataArity "Option" 1 →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name
            (Benitoite.Release.Refinement.StandardListRemainingResponse.API.signature B.sat api) ts es rs ws r e →
          ∃ out,
            Benitoite.Release.Refinement.StandardListRemainingResponse.delta api api.name ts es rs ws = some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out r ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardListResponse.related_response

所在: `formal/Benitoite/Release/Refinement/StandardListResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardListResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e →
    ∃ out,
      api.delta api.name ts es rs ws = some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            (∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i) ∧
              Benitoite.Release.Refinement.StandardListResponse.Relation api ws out
```

## Benitoite.Release.Refinement.StandardMapReplaceValues.delta_aligned

所在: `formal/Benitoite/Release/Refinement/StandardMapReplaceValues.lean`

```lean
∀ {cs : List Benitoite.Release.ConName} {a b c : Benitoite.Release.Refinement.Ty}
  {ks vs ys : List Benitoite.Release.Refinement.Val}
  {entries : List Benitoite.Release.Refinement.StandardCollections.MapEntry},
  Benitoite.Release.Refinement.StandardCollections.normalizedMap cs ks vs = some entries →
    ys.length = entries.length →
      Benitoite.Release.Refinement.StandardMapReplaceValues.delta cs "%Map.replaceValues" [a, b, c] [] []
          [Benitoite.Release.Refinement.Val.mapV ks vs, Benitoite.Release.Refinement.Val.list ys] =
        Benitoite.Release.Refinement.StandardCollections.mapDelta cs "Map.fromList" [a, c] [] []
          [Benitoite.Release.Refinement.Val.list
              (List.zipWith (fun e v => Benitoite.Release.Refinement.Val.con "Pair.Pair" [a, c] [e.key, v]) entries ys)]
```

## Benitoite.Release.Refinement.StandardMapReplaceValues.response

所在: `formal/Benitoite/Release/Refinement/StandardMapReplaceValues.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {r : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (table : Benitoite.Release.Refinement.StandardKeyTyping.Table P B),
  P.VarianceValid →
    Benitoite.Release.Refinement.StandardCollections.MapSetDeclarations P →
      Benitoite.Release.Refinement.BuiltinArgs P B Ψ "%Map.replaceValues"
          (Benitoite.Release.Refinement.StandardMapReplaceValues.signature B.sat) ts es rs ws r e →
        ∃ out,
          Benitoite.Release.Refinement.StandardMapReplaceValues.delta
                (List.map Prod.fst
                  (List.flatMap Benitoite.Release.Refinement.StandardKeyTyping.DataDecl.entries table.declarations))
                "%Map.replaceValues" ts es rs ws =
              some out ∧
            Benitoite.Release.Refinement.Outcome.Typed P B Ψ out r ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.StandardNumericRemainingResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardNumericRemainingResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardNumericRemainingResponse.API),
  P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
    P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
      P.DataArity "Option" 1 →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e →
          ∃ out,
            api.delta api.name ts es rs ws = some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardDecode.record_chain

所在: `formal/Benitoite/Release/Refinement/StandardRecordFields.lean`

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {lo hi : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram B Ψ
      Benitoite.Release.Qempty [] Γ Φ
      (Benitoite.Release.Refinement.Val.con "Envelope.Make" []
        [Benitoite.Release.Refinement.Val.con "Checked.Make" [] [lo, hi]])
      (Benitoite.Release.Refinement.Ty.data "Envelope" []) →
    Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram B Ψ
        Benitoite.Release.Qempty [] Γ Φ lo Benitoite.Release.Refinement.StandardDecode.nonnegative ∧
      Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram B Ψ
        Benitoite.Release.Qempty [] Γ Φ hi Benitoite.Release.Refinement.StandardDecode.nonnegative
```

## Benitoite.Release.Refinement.StandardDecode.record_valid

所在: `formal/Benitoite/Release/Refinement/StandardRecordFields.lean`

```lean
Benitoite.Release.Refinement.StandardDecode.recordProgram.VarianceValid
```

## Benitoite.Release.Refinement.StandardDecode.whole_construct

所在: `formal/Benitoite/Release/Refinement/StandardRecordFields.lean`

```lean
∀ {B : Benitoite.Release.Refinement.Builtins} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {lo hi : Benitoite.Release.Refinement.Val} {tl th : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram B Ψ
      Benitoite.Release.Qempty [] Γ Φ lo (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer) →
    Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram B Ψ
        Benitoite.Release.Qempty [] Γ Φ hi (Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.integer) →
      lo.toTerm? = some tl →
        hi.toTerm? = some th →
          Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ)
              (Benitoite.Release.Refinement.Pred.le (Benitoite.Release.Refinement.Term.integer 0) tl) →
            Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ)
                (Benitoite.Release.Refinement.Pred.le (Benitoite.Release.Refinement.Term.integer 0) th) →
              Benitoite.Release.Refinement.Entails (Γ.facts ++ Φ)
                  (Benitoite.Release.Refinement.StandardDecode.constructedComparison tl th) →
                Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram B Ψ
                  Benitoite.Release.Qempty [] Γ Φ
                  (Benitoite.Release.Refinement.Val.con "Envelope.Make" []
                    [Benitoite.Release.Refinement.Val.con "Checked.Make" [] [lo, hi]])
                  Benitoite.Release.Refinement.StandardDecode.wholeType
```

## Benitoite.Release.Refinement.StandardSafe.head_row_typed

所在: `formal/Benitoite/Release/Refinement/StandardSafeBodies.lean`

```lean
∀ (P : Benitoite.Release.Refinement.Program) (B : Benitoite.Release.Refinement.Builtins),
  Benitoite.Release.Refinement.StandardSafe.headRow.BodyTyped P B
```

## Benitoite.Release.Refinement.StandardSafe.precise_rows_typed

所在: `formal/Benitoite/Release/Refinement/StandardSafeBodies.lean`

```lean
∀ (g : Benitoite.Release.Refinement.StandardSafe.PreciseGetter),
  g ∈ Benitoite.Release.Refinement.StandardSafe.PreciseGetter.all →
    g.row.BodyTyped Benitoite.Release.Refinement.StandardSafe.safeProgram
      Benitoite.Release.Refinement.StandardSafe.builtins
```

## Benitoite.Release.Refinement.StandardStringOrdinaryResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardStringOrdinaryResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardStringOrdinaryResponse.API),
  P.cons "Option.Some" = some { data := "Option", ntys := 1, args := [Benitoite.Release.Refinement.Ty.tvar 0] } →
    P.cons "Option.None" = some { data := "Option", ntys := 1, args := [] } →
      P.DataArity "Option" 1 →
        Benitoite.Release.Refinement.BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e →
          ∃ out,
            api.delta api.name ts es rs ws = some out ∧
              Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out ∧
                  ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardVariance.covariant_positions

所在: `formal/Benitoite/Release/Refinement/StandardVariance.lean`

```lean
∀ {Γ : Benitoite.Release.Refinement.Ctx} {Φ : List Benitoite.Release.Refinement.Pred}
  {a b : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ a b →
    Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ a.list b.list ∧
      Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ
          (Benitoite.Release.Refinement.Ty.data "Option" [a]) (Benitoite.Release.Refinement.Ty.data "Option" [b]) ∧
        Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ
            (Benitoite.Release.Refinement.Ty.data "Result"
              [a, Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit])
            (Benitoite.Release.Refinement.Ty.data "Result"
              [b, Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit]) ∧
          Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ
              (Benitoite.Release.Refinement.Ty.data "Result"
                [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit, a])
              (Benitoite.Release.Refinement.Ty.data "Result"
                [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit, b]) ∧
            Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ
                (Benitoite.Release.Refinement.Ty.data "Pair"
                  [a, Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit])
                (Benitoite.Release.Refinement.Ty.data "Pair"
                  [b, Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit]) ∧
              Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ
                  (Benitoite.Release.Refinement.Ty.data "Pair"
                    [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit, a])
                  (Benitoite.Release.Refinement.Ty.data "Pair"
                    [Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit, b]) ∧
                Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ a.lazy
                    b.lazy ∧
                  Benitoite.Release.Refinement.Ty.LeQ Benitoite.Release.Refinement.StandardVariance.program Γ Φ
                    ((Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit).map a)
                    ((Benitoite.Release.Refinement.Ty.base Benitoite.Release.BaseTy.unit).map b)
```

## Benitoite.Release.Refinement.StandardVariance.valid

所在: `formal/Benitoite/Release/Refinement/StandardVariance.lean`

```lean
Benitoite.Release.Refinement.StandardVariance.program.VarianceValid
```

## Benitoite.Release.Refinement.step_lambda

所在: `formal/Benitoite/Release/Refinement/Step.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {σ : Benitoite.Release.Refinement.PathEnv} {oracle : Benitoite.Release.Refinement.Oracle}
  {externalOracle : Benitoite.Release.Refinement.ExternalOracle}
  {rel : Benitoite.Release.Refinement.Val → Option Benitoite.Release.ErrKind}
  {fresh : Benitoite.Release.Refinement.Store → Nat} {q : Benitoite.Release.Refinement.Closure}
  {k : Benitoite.Release.Refinement.Cont} {μ : Benitoite.Release.Refinement.Store}
  {f : Benitoite.Release.Refinement.Val} {runtime : Benitoite.Release.Refinement.Tel}
  {body : Benitoite.Release.Refinement.Closure} {ws : List Benitoite.Release.Refinement.Val},
  q.view = Benitoite.Release.Refinement.Comp.app f ws →
    Benitoite.Release.Refinement.closeVal Benitoite.Release.Refinement.Capture.empty f =
        Benitoite.Release.Refinement.Val.closure runtime body →
      ws.length = runtime.arity →
        Benitoite.Release.Refinement.step P B σ oracle externalOracle rel fresh
              (Benitoite.Release.Refinement.State.run q k μ) =
            some
              (none,
                Benitoite.Release.Refinement.State.run (body.apply ws) (Benitoite.Release.Refinement.markPush k) μ) ∧
          Benitoite.Release.Refinement.Step P B σ (Benitoite.Release.Refinement.State.run q k μ) none
            (Benitoite.Release.Refinement.State.run (body.apply ws) (Benitoite.Release.Refinement.markPush k) μ)
```

## Benitoite.Release.Refinement.TelClosure.apply

所在: `formal/Benitoite/Release/Refinement/TelApplication.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {t u : Benitoite.Release.Refinement.Tel}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Ctx.WF 0 (List.length C) Γ →
    Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.dependentFn t) →
      Benitoite.Release.Refinement.TelClosure P Γ Φ t u →
        Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e →
          ∃ b f,
            Benitoite.Release.Refinement.HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
              Benitoite.Release.Refinement.Ty.LeQ P Γ Φ b a ∧ Benitoite.Release.Refinement.Eff.Covers Γ Φ e f
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_dependentLam

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {t : Benitoite.Release.Refinement.Tel} {body : Benitoite.Release.Refinement.Comp}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.dependentLam t body →
      ∃ u,
        Benitoite.Release.Refinement.Ty.Annotation P C Γ (Benitoite.Release.Refinement.Ty.dependentFn t) ∧
          Benitoite.Release.Refinement.TelBodyTy P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q C
              (Benitoite.Release.Refinement.hideConts Γ) Φ t body ∧
            T.fnCore = some u ∧ Benitoite.Release.Refinement.TelClosure P Γ Φ t u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_dict

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {i : Benitoite.Release.ImplName}
  {ts : List Benitoite.Release.Refinement.Ty} {vs : List Benitoite.Release.Refinement.Val}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.dict i ts vs →
      ∃ id,
        P.impls i = some id ∧
          Benitoite.Release.Refinement.SatAll B C ts id.tparams ∧
            Benitoite.Release.Refinement.TypeAnnotations P C Γ ts ∧
              Benitoite.Release.Refinement.TypeArgsKinded P C ts
                  (List.replicate id.tparams.length Benitoite.Release.Refinement.TyKind.value) ∧
                (∀ (a : Benitoite.Release.Refinement.Ty),
                    a ∈ id.dictTys → Benitoite.Release.Refinement.Ty.WF 0 id.tparams.length 0 a) ∧
                  Benitoite.Release.Refinement.Ty.WF 0 id.tparams.length 0 id.target ∧
                    Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs
                        (List.map (Benitoite.Release.Refinement.Ty.subst ts []) id.dictTys) ∧
                      Benitoite.Release.Refinement.Ty.Annotation P C Γ
                          (Benitoite.Release.Refinement.Ty.dict id.cls
                            (Benitoite.Release.Refinement.Ty.subst ts [] id.target)) ∧
                        T.norm.core =
                          (Benitoite.Release.Refinement.Ty.dict id.cls
                                (Benitoite.Release.Refinement.Ty.subst ts [] id.target)).norm.core
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_fnRef

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {f : Benitoite.Release.FunName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.fnRef f ts es →
      ∃ d u,
        P.defs f = some d ∧
          Benitoite.Release.Refinement.NamesWF d.names d.params ∧
            Benitoite.Release.Refinement.Admissible B C (List.length Γ)
                (Benitoite.Release.Refinement.TypeCtx.constraints d.tparams) d.neffs
                (Benitoite.Release.Refinement.Qsig d.params d.ret d.eff) Q ts es d.eff ∧
              Benitoite.Release.Refinement.SignatureInstance P C Γ d.tel
                  (Benitoite.Release.Refinement.TypeCtx.kinds d.tparams) ts es ∧
                T.fnCore = some u ∧
                  Benitoite.Release.Refinement.TelClosure P Γ Φ
                    (Benitoite.Release.Refinement.instantiatedTel d.tel ts es) u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_lam

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {ns : List String}
  {ps : List Benitoite.Release.Refinement.Ty} {body : Benitoite.Release.Refinement.Comp}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.lam ns ps body →
      ∃ r ε u,
        Benitoite.Release.Refinement.NamesWF ns ps ∧
          Benitoite.Release.Refinement.Ty.WF 0 (List.length C) (List.length Γ)
              (Benitoite.Release.Refinement.Ty.fn ns ps r ε) ∧
            Benitoite.Release.Refinement.Ty.Sorted Γ (Benitoite.Release.Refinement.Ty.fn ns ps r ε) ∧
              Benitoite.Release.Refinement.HasTypeCQ P B (Benitoite.Release.Refinement.hideBuilders Ψ) Q C
                  (Benitoite.Release.Refinement.bindParams (Benitoite.Release.Refinement.hideConts Γ) ps)
                  (Benitoite.Release.Refinement.liftMany ps.length Φ)
                  (some (Benitoite.Release.Refinement.Ty.shiftV ps.length 0 r)) body
                  (Benitoite.Release.Refinement.Ty.shiftV ps.length 0 r)
                  (Benitoite.Release.Refinement.Eff.shiftV ps.length 0 ε) ∧
                Benitoite.Release.Refinement.Ty.Declared P C Γ (Benitoite.Release.Refinement.Ty.fn ns ps r ε) ∧
                  T.fnCore = some u ∧
                    Benitoite.Release.Refinement.TelClosure P Γ Φ (Benitoite.Release.Refinement.Ty.toTel ns ps r ε) u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_op

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {o : Benitoite.Release.OpName}
  {ts : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.op o ts →
      ∃ od u,
        P.ops o = some od ∧
          Benitoite.Release.Refinement.NamesWF od.names od.params ∧
            Benitoite.Release.Refinement.SatAll B C ts od.tparams ∧
              Benitoite.Release.Refinement.SignatureInstance P C Γ od.tel
                  (List.replicate od.tparams.length Benitoite.Release.Refinement.TyKind.value) ts [] ∧
                T.fnCore = some u ∧
                  Benitoite.Release.Refinement.TelClosure P Γ Φ
                    (Benitoite.Release.Refinement.instantiatedTel od.tel ts []) u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_prim

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty} {b : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.prim b ts es rs →
      ∃ s u,
        B.sig b = some s ∧
          B.RangeAdmissible b s rs ∧
            Benitoite.Release.Refinement.NamesWF s.names s.params ∧
              Benitoite.Release.Refinement.PrimitiveAdmissible C (List.length Γ) s Q ts es ∧
                Benitoite.Release.Refinement.SignatureInstance P C Γ (Benitoite.Release.Refinement.Tel.instR rs s.tel)
                    (Benitoite.Release.Refinement.TypeCtx.kinds s.tparams) ts es ∧
                  T.fnCore = some u ∧
                    Benitoite.Release.Refinement.TelClosure P Γ Φ
                      (Benitoite.Release.Refinement.instantiatedTel (Benitoite.Release.Refinement.Tel.instR rs s.tel) ts
                        es)
                      u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_raise

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T t e : Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.raise t e →
      ∃ u,
        Benitoite.Release.Refinement.Ty.Annotation P C Γ
            (Benitoite.Release.Refinement.Ty.fn ["error"] [e] t (Benitoite.Release.Refinement.Eff.singleFail e)) ∧
          Benitoite.Release.Refinement.Ordinary t ∧
            Benitoite.Release.Refinement.Ordinary e ∧
              Benitoite.Release.Refinement.Ty.HasKind P C.kinds t Benitoite.Release.Refinement.TyKind.value ∧
                T.fnCore = some u ∧
                  Benitoite.Release.Refinement.TelClosure P Γ Φ
                    (Benitoite.Release.Refinement.Ty.toTel ["error"] [e] t
                      (Benitoite.Release.Refinement.Eff.singleFail e))
                    u
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_super

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {T : Benitoite.Release.Refinement.Ty}
  {inner : Benitoite.Release.Refinement.Val} {super : Benitoite.Release.ClassName}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = inner.super super →
      ∃ cl a cd,
        Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ inner (Benitoite.Release.Refinement.Ty.dict cl a) ∧
          P.classes cl = some cd ∧
            super ∈ cd.supers ∧
              Benitoite.Release.Refinement.Ty.Declared P C Γ a ∧
                T.norm.core = (Benitoite.Release.Refinement.Ty.dict super a).norm.core
```

## Benitoite.Release.Refinement.HasTypeVQ.inv_var

所在: `formal/Benitoite/Release/Refinement/ValueInversion.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {v : Benitoite.Release.Refinement.Val}
  {T : Benitoite.Release.Refinement.Ty} {i : Nat},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C Γ Φ v T →
    v = Benitoite.Release.Refinement.Val.var i →
      ∃ a b,
        Γ[i]? = some (some a) ∧ a.Ordinary ∧ T.norm.core = b ∧ Benitoite.Release.Refinement.Ty.LeQ P Γ Φ a.norm.core b
```

## Benitoite.Release.Refinement.StandardOperatorArguments.arguments

所在: `formal/Benitoite/Release/Refinement/StandardOperatorArguments.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {name : Benitoite.Release.PrimName}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff} (input output : Benitoite.Release.BaseTy)
  (unary : Bool),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ name
      (Benitoite.Release.Refinement.StandardOperatorArguments.signature input output unary) ts es rs ws a e →
    ts = [] ∧
      es = [] ∧
        rs = [] ∧
          a = Benitoite.Release.Refinement.Ty.base output ∧
            e = Benitoite.Release.Refinement.Eff.empty ∧
              Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Benitoite.Release.Qempty [] [] [] ws
                (if unary = true then [Benitoite.Release.Refinement.Ty.base input]
                else [Benitoite.Release.Refinement.Ty.base input, Benitoite.Release.Refinement.Ty.base input])
```

## Benitoite.Release.Refinement.StandardFloatOperatorResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardFloatOperatorResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (single : Bool)
  (api : Benitoite.Release.Refinement.StandardFloatOperatorResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ
      (Benitoite.Release.Refinement.StandardFloatOperatorResponse.name single api)
      (Benitoite.Release.Refinement.StandardFloatOperatorResponse.signature single api) ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardFloatOperatorResponse.delta single api
            (Benitoite.Release.Refinement.StandardFloatOperatorResponse.name single api) ts es rs ws =
          some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardDecimalOperatorResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardDecimalOperatorResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardDecimalOperatorResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ (Benitoite.Release.Refinement.StandardDecimalOperatorResponse.name api)
      (Benitoite.Release.Refinement.StandardDecimalOperatorResponse.signature api) ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardDecimalOperatorResponse.delta api
            (Benitoite.Release.Refinement.StandardDecimalOperatorResponse.name api) ts es rs ws =
          some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardStringOperatorResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardStringOperatorResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (api : Benitoite.Release.Refinement.StandardStringOperatorResponse.API),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ (Benitoite.Release.Refinement.StandardStringOperatorResponse.name api)
      (Benitoite.Release.Refinement.StandardStringOperatorResponse.signature api) ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardStringOperatorResponse.delta api
            (Benitoite.Release.Refinement.StandardStringOperatorResponse.name api) ts es rs ws =
          some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardIntegerOperatorResponse.response

所在: `formal/Benitoite/Release/Refinement/StandardIntegerOperatorResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (kind : Benitoite.Interval.IntKind) (modulo : Bool),
  Benitoite.Release.Refinement.BuiltinArgs P B Ψ
      (Benitoite.Release.Refinement.StandardIntegerOperatorResponse.name kind modulo)
      (Benitoite.Release.Refinement.StandardIntegerOperatorResponse.signature kind) ts es rs ws a e →
    ∃ out,
      Benitoite.Release.Refinement.StandardIntegerOperatorResponse.delta kind modulo
            (Benitoite.Release.Refinement.StandardIntegerOperatorResponse.name kind modulo) ts es rs ws =
          some out ∧
        Benitoite.Release.Refinement.Outcome.Typed P B Ψ out a ∧
          Benitoite.Release.Refinement.AdequateResult ws out ∧
            ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardOperatorResponse.table_response

所在: `formal/Benitoite/Release/Refinement/StandardOperatorResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {base : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (entry : Benitoite.Release.Refinement.StandardOperatorResponse.Entry),
  Benitoite.Release.Refinement.BuiltinArgs P (Benitoite.Release.Refinement.StandardOperatorResponse.table base) Ψ
      entry.name entry.signature ts es rs ws a e →
    (Benitoite.Release.Refinement.StandardOperatorResponse.table base).sig entry.name = some entry.signature ∧
      ∃ out,
        (Benitoite.Release.Refinement.StandardOperatorResponse.table base).delta entry.name ts es rs ws = some out ∧
          Benitoite.Release.Refinement.Outcome.Typed P
              (Benitoite.Release.Refinement.StandardOperatorResponse.table base) Ψ out a ∧
            Benitoite.Release.Refinement.AdequateResult ws out ∧
              ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table_response

所在: `formal/Benitoite/Release/Refinement/StandardStructuralEqualityResponse.lean`

```lean
∀ {P : Benitoite.Release.Refinement.Program} {base : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} (equal : Bool),
  Benitoite.Release.Refinement.BuiltinArgs P
      (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base) Ψ
      (if equal = true then "%eq" else "%ne")
      (Benitoite.Release.Refinement.StandardEqualityResponse.fullSignature
        (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base).sat)
      ts es rs ws a e →
    (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base).sig
          (if equal = true then "%eq" else "%ne") =
        some
          (Benitoite.Release.Refinement.StandardEqualityResponse.fullSignature
            (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base).sat) ∧
      ∃ T,
        ts = [T] ∧
          Benitoite.Release.Refinement.Ty.Annotation P [] [] T ∧
            Benitoite.Release.Refinement.Ordinary T ∧
              (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base).sat [] T.norm
                  { equality := true } ∧
                ∃ out,
                  (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base).delta
                        (if equal = true then "%eq" else "%ne") ts es rs ws =
                      some out ∧
                    Benitoite.Release.Refinement.Outcome.Typed P
                        (Benitoite.Release.Refinement.StandardStructuralEqualityResponse.table base) Ψ out a ∧
                      Benitoite.Release.Refinement.AdequateResult ws out ∧
                        ∀ (i : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit i
```

## Benitoite.Release.Refinement.StandardStructuralEqualityResponse.reply_normal

所在: `formal/Benitoite/Release/Refinement/StandardStructuralEqualityResponse.lean`

```lean
∀ (equal : Bool) (left right value : Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.StandardStructuralEqualityResponse.reply equal left right =
      Benitoite.Release.Refinement.Outcome.val value →
    ∃ b, value = Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.boolean b)
```

## Benitoite.Release.Refinement.StandardDecode.checkedRawResult

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
Benitoite.Release.Integer64Value → Benitoite.Release.Integer64Value → Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.StandardDecode.DecodeResult

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Val → Prop
```

