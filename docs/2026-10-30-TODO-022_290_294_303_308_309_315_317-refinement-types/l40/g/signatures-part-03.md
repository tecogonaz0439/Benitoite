# 段末の実際の署名（続き）

## Benitoite.Release.Refinement.StandardDecode.postprocess_all

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {decoded : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] [] decoded
      (Benitoite.Release.Refinement.Ty.data "Result"
        [Benitoite.Release.Refinement.Ty.data "Raw" [], Benitoite.Release.Refinement.Ty.data "ConversionError" []]) →
    ∀ (k : Benitoite.Release.Refinement.Cont) (μ : Benitoite.Release.Refinement.Store),
      ∃ result q,
        Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
            Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.mk (Benitoite.Release.Refinement.Capture.empty.extend decoded)
                Benitoite.Release.Refinement.StandardDecode.postprocessBody)
              k μ)
            [] (Benitoite.Release.Refinement.State.run q k μ) ∧
          q.view = Benitoite.Release.Refinement.Comp.ret result ∧
            Benitoite.Release.Refinement.StandardDecode.DecodeResult decoded result ∧
              Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram
                Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] [] result
                (Benitoite.Release.Refinement.Ty.data "Result"
                  [Benitoite.Release.Refinement.StandardDecode.wholeType,
                    Benitoite.Release.Refinement.Ty.data "ConversionError" []])
```

## Benitoite.Release.Refinement.StandardDecode.postprocess_raw_general_steps

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} (ts us : List Benitoite.Release.Refinement.Ty)
  (lo hi : Benitoite.Release.Integer64Value) (k : Benitoite.Release.Refinement.Cont)
  (μ : Benitoite.Release.Refinement.Store),
  ∃ q,
    Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
        Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
        (Benitoite.Release.Refinement.State.run
          (Benitoite.Release.Refinement.Closure.mk
            (Benitoite.Release.Refinement.Capture.empty.extend
              (Benitoite.Release.Refinement.Val.con "Result.Ok" ts
                [Benitoite.Release.Refinement.Val.con "Raw.Make" us
                    [Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer lo),
                      Benitoite.Release.Refinement.Val.const (Benitoite.Release.Refinement.Const.integer hi)]]))
            Benitoite.Release.Refinement.StandardDecode.postprocessBody)
          k μ)
        [] (Benitoite.Release.Refinement.State.run q k μ) ∧
      q.view =
        Benitoite.Release.Refinement.Comp.ret (Benitoite.Release.Refinement.StandardDecode.checkedRawResult lo hi)
```

## Benitoite.Release.Refinement.StandardDecode.decode_let_typed

所在: `formal/Benitoite/Release/Refinement/StandardDecodeBodies.lean`

```lean
∀ {Ψ : Benitoite.Release.Refinement.StoreTy} {decoder : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.HasTypeCQ Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] []
      (some Benitoite.Release.Refinement.StandardDecode.outputType✝) decoder
      Benitoite.Release.Refinement.StandardDecode.inputType✝ Benitoite.Release.Refinement.Eff.empty →
    Benitoite.Release.Refinement.HasTypeCQ Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] []
      (some Benitoite.Release.Refinement.StandardDecode.outputType✝)
      (decoder.letIn Benitoite.Release.Refinement.StandardDecode.postprocessBody)
      Benitoite.Release.Refinement.StandardDecode.outputType✝ Benitoite.Release.Refinement.Eff.empty
```

## Benitoite.Release.Refinement.StandardDecode.decodeThen_normal

所在: `formal/Benitoite/Release/Refinement/StandardDecodeConnection.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {decoder : Benitoite.Release.Refinement.Comp} {events : List Benitoite.Release.Refinement.Event}
  {q : Benitoite.Release.Refinement.Closure} {μ μ' : Benitoite.Release.Refinement.Store}
  {decoded : Benitoite.Release.Refinement.Val} (k : Benitoite.Release.Refinement.Cont),
  Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty decoder)
        (Benitoite.Release.Refinement.Frame.letF
            (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
              Benitoite.Release.Refinement.StandardDecode.postprocessBody) ::
          k)
        μ)
      events
      (Benitoite.Release.Refinement.State.run q
        (Benitoite.Release.Refinement.Frame.letF
            (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
              Benitoite.Release.Refinement.StandardDecode.postprocessBody) ::
          k)
        μ') →
    q.view = Benitoite.Release.Refinement.Comp.ret decoded →
      Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram
          Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] [] decoded
          Benitoite.Release.Refinement.StandardDecode.decoderInputType →
        ∃ result last,
          Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
              Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
              (Benitoite.Release.Refinement.State.run
                (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
                  (Benitoite.Release.Refinement.StandardDecode.decodeThen decoder))
                k μ)
              events (Benitoite.Release.Refinement.State.run last k μ') ∧
            last.view = Benitoite.Release.Refinement.Comp.ret result ∧
              Benitoite.Release.Refinement.StandardDecode.DecodeResult decoded result ∧
                Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram
                  Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] [] result
                  Benitoite.Release.Refinement.StandardDecode.decoderOutputType
```

## Benitoite.Release.Refinement.StandardDecode.decodeThen_firstReturn

所在: `formal/Benitoite/Release/Refinement/StandardDecodeConnection.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {decoder : Benitoite.Release.Refinement.Comp} {events : List Benitoite.Release.Refinement.Event}
  {q : Benitoite.Release.Refinement.Closure} {μ μ' : Benitoite.Release.Refinement.Store}
  {decoded : Benitoite.Release.Refinement.Val} (k : Benitoite.Release.Refinement.Cont),
  Benitoite.Release.Refinement.FirstReturn Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
      (Benitoite.Release.Refinement.Frame.letF
          (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
            Benitoite.Release.Refinement.StandardDecode.postprocessBody) ::
        k)
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty decoder)
        (Benitoite.Release.Refinement.Frame.letF
            (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
              Benitoite.Release.Refinement.StandardDecode.postprocessBody) ::
          k)
        μ)
      events q μ' decoded →
    Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram
        Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] [] decoded
        Benitoite.Release.Refinement.StandardDecode.decoderInputType →
      ∃ result last,
        Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
            Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
            (Benitoite.Release.Refinement.State.run
              (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
                (Benitoite.Release.Refinement.StandardDecode.decodeThen decoder))
              k μ)
            events (Benitoite.Release.Refinement.State.run last k μ') ∧
          last.view = Benitoite.Release.Refinement.Comp.ret result ∧
            Benitoite.Release.Refinement.StandardDecode.DecodeResult decoded result ∧
              Benitoite.Release.Refinement.HasTypeVQ Benitoite.Release.Refinement.StandardDecode.recordProgram
                Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] [] result
                Benitoite.Release.Refinement.StandardDecode.decoderOutputType
```

## Benitoite.Release.Refinement.StandardDecode.decodeThen_failed

所在: `formal/Benitoite/Release/Refinement/StandardDecodeConnection.lean`

```lean
∀ {σ : Benitoite.Release.Refinement.PathEnv} {decoder : Benitoite.Release.Refinement.Comp}
  {events : List Benitoite.Release.Refinement.Event} {errors : List Benitoite.Release.ErrKind}
  {μ μ' : Benitoite.Release.Refinement.Store} (k : Benitoite.Release.Refinement.Cont),
  Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty decoder)
        (Benitoite.Release.Refinement.Frame.letF
            (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
              Benitoite.Release.Refinement.StandardDecode.postprocessBody) ::
          k)
        μ)
      events
      (Benitoite.Release.Refinement.State.error errors
        (Benitoite.Release.Refinement.Frame.letF
            (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
              Benitoite.Release.Refinement.StandardDecode.postprocessBody) ::
          k)
        μ') →
    Benitoite.Release.Refinement.Steps Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins σ
      (Benitoite.Release.Refinement.State.run
        (Benitoite.Release.Refinement.Closure.mk Benitoite.Release.Refinement.Capture.empty
          (Benitoite.Release.Refinement.StandardDecode.decodeThen decoder))
        k μ)
      events (Benitoite.Release.Refinement.State.error errors k μ')
```

## Benitoite.Release.Refinement.StandardDecode.decodeThen_typed

所在: `formal/Benitoite/Release/Refinement/StandardDecodeConnection.lean`

```lean
∀ {Ψ : Benitoite.Release.Refinement.StoreTy} {decoder : Benitoite.Release.Refinement.Comp},
  Benitoite.Release.Refinement.HasTypeCQ Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] []
      (some Benitoite.Release.Refinement.StandardDecode.decoderOutputType) decoder
      Benitoite.Release.Refinement.StandardDecode.decoderInputType Benitoite.Release.Refinement.Eff.empty →
    Benitoite.Release.Refinement.HasTypeCQ Benitoite.Release.Refinement.StandardDecode.recordProgram
      Benitoite.Release.Refinement.StandardDecode.recordBuiltins Ψ Benitoite.Release.Qempty [] [] []
      (some Benitoite.Release.Refinement.StandardDecode.decoderOutputType)
      (Benitoite.Release.Refinement.StandardDecode.decodeThen decoder)
      Benitoite.Release.Refinement.StandardDecode.decoderOutputType Benitoite.Release.Refinement.Eff.empty
```

