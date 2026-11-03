# 群 H・I の完全署名

名前空間は特記しない限り `Benitoite.Release.Refinement`。本番ソースから台本で抽出した新規・変更の署名である。型付けの構成子、Entails.bind、主要十移送は不変である。

## Ty.assumeWithCarrier_norm

配置: `formal/Benitoite/Release/Refinement/CarrierFacts.lean`。

```lean
@[simp] theorem Ty.assumeWithCarrier_norm (a : Ty) :
    a.norm.assumeWithCarrier = a.assumeWithCarrier
```

## Ty.assumeWithCarrier_refined

配置: `formal/Benitoite/Release/Refinement/CarrierFacts.lean`。

```lean
theorem Ty.assumeWithCarrier_refined {a : Ty} (ho : a.Ordinary) (p : Pred) :
    (Ty.refined a p).assumeWithCarrier = a.assumeWithCarrier ++ p.conjuncts
```

## Ty.assumeWithCarrier_of_wf

配置: `formal/Benitoite/Release/Refinement/CarrierFacts.lean`。

```lean
theorem Ty.assumeWithCarrier_of_wf {nr nt nv : Nat} {a : Ty} (hw : a.WF nr nt nv) :
    a.assumeWithCarrier = a.carrierFacts ++ a.refinementPredicates
```

## Ty.carrierFacts_subset_assumeWithCarrier

配置: `formal/Benitoite/Release/Refinement/CarrierFacts.lean`。

```lean
theorem Ty.carrierFacts_subset_assumeWithCarrier (a : Ty) :
    ∀ p ∈ a.carrierFacts, p ∈ a.assumeWithCarrier
```

## Ty.carrierFacts_hasSort

配置: `formal/Benitoite/Release/Refinement/CarrierFacts.lean`。

```lean
theorem Ty.carrierFacts_hasSort {a : Ty} {p : Pred} (hp : p ∈ a.carrierFacts) :
    ∃ s, a.HasSort s
```

## widthCtx

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
def widthCtx : Ctx
```

## upper

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
def upper : Pred
```

## width_upper

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem width_upper : Entails widthCtx.factsWithCarrier upper
```

## explicitFacts

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
def explicitFacts (Γ : Ctx) : List Pred
```

## explicit_width_upper_unprovable

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem explicit_width_upper_unprovable : ¬ Entails (explicitFacts widthCtx) upper
```

## width_128_unprovable

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem width_128_unprovable : ¬ Entails widthCtx.factsWithCarrier (.le (.integer 128) (.var 0))
```

## upperType

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
def upperType : Ty
```

## integer8_upper_sub

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem integer8_upper_sub (P : Program) (Γ : Ctx) (Φ : List Pred) :
    Ty.LeQ P Γ Φ (.base .integer8) upperType
```

## upper_annotation

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
private theorem upper_annotation (P : Program) (Γ : Ctx) : Ty.Annotation P [] Γ upperType
```

## typed_integer8_upper

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem typed_integer8_upper (P : Program) (B : Builtins) :
    HasTypeVQ P B StoreTy.empty Qempty [] widthCtx [] (.var 0) upperType
```

## P

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
private def P : Program
```

## B

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
private def B : Builtins
```

## closed_integer8_upper

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem closed_integer8_upper :
    HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.const (.integer8 127)) upperType
```

## closed_integer8_carrier

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem closed_integer8_carrier (η : ObservationEnvModel) :
    ∀ p ∈ upperType.carrierFacts,
      p.interpret (selfModel η (.const (.integer8 127))) = true
```

## raw_1000_not_meaning

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem raw_1000_not_meaning (P : Program) (η : ObservationEnvModel) :
    ¬ ValueMeaning P η (.base .integer8) (.const (.integer8 1000))
```

## captured_decimal

配置: `formal/Benitoite/Release/Refinement/CarrierFactsExamples.lean`。

```lean
theorem captured_decimal : CaptureOk P B StoreTy.empty none
    (Ctx.extend [] (.base .decimal)) [] (Capture.empty.extend (.const (.decimal 1 0)))
```

## integerBounds

配置: `formal/Benitoite/Release/Refinement/Context.lean`。

```lean
def integerBounds (lo hi : Int) : List Pred
```

## Ty.carrierFacts

配置: `formal/Benitoite/Release/Refinement/Context.lean`。

```lean
def Ty.carrierFacts (a : Ty) : List Pred
```

## Ty.carrierFacts_norm

配置: `formal/Benitoite/Release/Refinement/Context.lean`。

```lean
@[simp] theorem Ty.carrierFacts_norm (a : Ty) : a.norm.carrierFacts = a.carrierFacts
```

## Ty.assumeWithCarrier

配置: `formal/Benitoite/Release/Refinement/Context.lean`。

```lean
abbrev Ty.assumeWithCarrier
```

## Ty.assume_eq_carrier_append

配置: `formal/Benitoite/Release/Refinement/Context.lean`。

```lean
theorem Ty.assume_eq_carrier_append {a : Ty} (ho : a.Ordinary) : a.assume = a.carrierFacts ++ a.refinementPredicates
```

## Ctx.factsWithCarrier

配置: `formal/Benitoite/Release/Refinement/Context.lean`。

```lean
abbrev Ctx.factsWithCarrier
```

## Ty.carrierFacts_shiftV

配置: `formal/Benitoite/Release/Refinement/ContextFacts.lean`。

```lean
theorem Ty.carrierFacts_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).carrierFacts = a.carrierFacts.map (Pred.shiftV k (c+1))
```

## Ty.assumeWithCarrier_shiftV

配置: `formal/Benitoite/Release/Refinement/ContextFacts.lean`。

```lean
theorem Ty.assumeWithCarrier_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).assumeWithCarrier = a.assumeWithCarrier.map (Pred.shiftV k (c+1))
```

## Ctx.mem_factsWithCarrier_extend

配置: `formal/Benitoite/Release/Refinement/ContextFacts.lean`。

```lean
theorem Ctx.mem_factsWithCarrier_extend {Γ : Ctx} {a : Ty} {q : Pred} :
    q ∈ (Γ.extend a).factsWithCarrier ↔ q ∈ a.assumeWithCarrier ∨ ∃ p ∈ Γ.factsWithCarrier, p.lift = q
```

## Ctx.mem_factsWithCarrier

配置: `formal/Benitoite/Release/Refinement/ContextFacts.lean`。

```lean
theorem Ctx.mem_factsWithCarrier {Γ : Ctx} {q : Pred} : q ∈ Γ.factsWithCarrier ↔
    ∃ (i : Nat) (a : Ty) (p : Pred), Γ[i]? = some (some a) ∧ p ∈ a.assumeWithCarrier ∧ q = p.open (.var i)
```

## Ctx.mem_factsWithCarrier_extendNone

配置: `formal/Benitoite/Release/Refinement/ContextFacts.lean`。

```lean
theorem Ctx.mem_factsWithCarrier_extendNone {Γ : Ctx} {q : Pred} :
    q ∈ Γ.extendNone.factsWithCarrier ↔ ∃ p ∈ Γ.factsWithCarrier, p.lift = q
```

## Ctx.factsWithCarrier_map_norm

配置: `formal/Benitoite/Release/Refinement/ContextNormEq.lean`。

```lean
theorem Ctx.factsWithCarrier_map_norm (Γ : Ctx) : Ctx.factsWithCarrier (Γ.map (Option.map Ty.norm)) = Γ.factsWithCarrier
```

## Ctx.NormEq.factsWithCarrier

配置: `formal/Benitoite/Release/Refinement/ContextNormEq.lean`。

```lean
theorem Ctx.NormEq.factsWithCarrier {Γ Δ : Ctx} (h : Γ.NormEq Δ) : Γ.factsWithCarrier = Δ.factsWithCarrier
```

## assumptionsWithCarrier

配置: `formal/Benitoite/Release/Refinement/Le.lean`。

```lean
abbrev assumptionsWithCarrier
```

## Ty.LeQ.assumeWithCarrier

配置: `formal/Benitoite/Release/Refinement/Le.lean`。

```lean
theorem Ty.LeQ.assumeWithCarrier {P : Program} {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    ∀ q ∈ b.assume, Entails (a.assume ++ (Γ.facts ++ Φ).map Pred.lift) q
```

## Ty.assume_of_wf

配置: `formal/Benitoite/Release/Refinement/NormalWellFormed.lean`。

```lean
theorem Ty.assume_of_wf {nr nt nv : Nat} {a : Ty} (hw : a.WF nr nt nv) :
    a.assume = a.carrierFacts ++ a.refinementPredicates
```

## Ty.entails_assumeWithCarrier_iff

配置: `formal/Benitoite/Release/Refinement/NormalizationLogic.lean`。

```lean
theorem Ty.entails_assumeWithCarrier_iff (Ξ : List Pred) (a : Ty) (ho : a.Ordinary) :
    (∀ p ∈ a.assumeWithCarrier, Entails Ξ p) ↔
      (∀ p ∈ a.carrierFacts, Entails Ξ p) ∧
      (∀ p ∈ a.refinementPredicates, Entails Ξ p)
```

## Ty.assumeWithCarrier_of_norm_eq

配置: `formal/Benitoite/Release/Refinement/NormalizationLogic.lean`。

```lean
theorem Ty.assumeWithCarrier_of_norm_eq {a b : Ty} (he : a.norm = b.norm) (Ξ : List Pred)
    (ha : ∀ p ∈ a.assumeWithCarrier, Entails Ξ p) :
    ∀ p ∈ b.assumeWithCarrier, Entails Ξ p
```

## Const.NumericRepresented

配置: `formal/Benitoite/Release/Refinement/NumericRepresented.lean`。

```lean
def Const.NumericRepresented : Const → Prop
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -79228162514264337593543950335 ≤ n ∧
      n ≤ 79228162514264337593543950335 ∧ scale ≤ 28
  | _ => True
```

## ConstOK.represented

配置: `formal/Benitoite/Release/Refinement/NumericRepresented.lean`。

```lean
theorem ConstOK.represented {B c} (h : ConstOK B c) : c.NumericRepresented
```

## context_facts

配置: `formal/Benitoite/Release/Refinement/OpenSubstitution.lean`。

```lean
theorem context_facts :
    Γ.facts = integerBounds (-9223372036854775808) 9223372036854775807 ++ [path] ∧
    Δ.facts = integerBounds (-9223372036854775808) 9223372036854775807 ++
      [predBind σ path, .le (.integer (-9223372036854775808)) (.var 2),
        .le (.var 2) (.integer 9223372036854775807)]
```

## target_carrier_from_path

配置: `formal/Benitoite/Release/Refinement/OpenSubstitution.lean`。

```lean
private theorem target_carrier_from_path :
    ∀ p ∈ integerBounds (-9223372036854775808) 9223372036854775807,
      Entails Δ.facts (predBind σ p)
```

## Ty.assumeWithCarrier_rawMapRanges

配置: `formal/Benitoite/Release/Refinement/RangeSubst.lean`。

```lean
theorem Ty.assumeWithCarrier_rawMapRanges (a : Ty) (ρ : Nat → RangeIx) :
    (a.rawMapRanges ρ).assumeWithCarrier = a.assumeWithCarrier
```

## context_facts

配置: `formal/Benitoite/Release/Refinement/SubstTypingObstruction.lean`。

```lean
theorem context_facts :
    Γ.facts = integerBounds (-9223372036854775808) 9223372036854775807 ++
      [path, .le (.integer (-9223372036854775808)) (.var 1),
        .le (.var 1) (.integer 9223372036854775807), .eq (.var 1) (.integer 7)] ∧
    Δ.facts = integerBounds (-9223372036854775808) 9223372036854775807 ++ [path]
```

## Ty.carrierFacts_rawBind

配置: `formal/Benitoite/Release/Refinement/Transport.lean`。

```lean
theorem Ty.carrierFacts_rawBind (a : Ty) (θ : SubstEnv) :
    ∀ p ∈ a.carrierFacts, predBind (upValues θ.values) p ∈ (a.rawBind θ).carrierFacts
```

## Ty.carrierFacts_bind

配置: `formal/Benitoite/Release/Refinement/Transport.lean`。

```lean
theorem Ty.carrierFacts_bind (a : Ty) (θ : SubstEnv) :
    ∀ p ∈ a.carrierFacts, predBind (upValues θ.values) p ∈ (a.bind θ).carrierFacts
```

## Ty.assumeWithCarrier_bind

配置: `formal/Benitoite/Release/Refinement/Transport.lean`。

```lean
theorem Ty.assumeWithCarrier_bind (a : Ty) (θ : SubstEnv)
    (ht : ∀ i, Ordinary (θ.types i)) :
    ∀ p ∈ a.assumeWithCarrier,
      predBind (upValues θ.values) p ∈ (a.bind θ).assumeWithCarrier
```

## Ty.assume_bind

配置: `formal/Benitoite/Release/Refinement/Transport.lean`。

```lean
theorem Ty.assume_bind (a : Ty) (θ : SubstEnv)
    (ht : ∀ i, Ordinary (θ.types i)) :
    ∀ p ∈ a.assume,
      predBind (upValues θ.values) p ∈ (a.bind θ).assume
```

## assumptionsWithCarrier_bind

配置: `formal/Benitoite/Release/Refinement/Transport.lean`。

```lean
theorem assumptionsWithCarrier_bind {θ : SubstEnv} {Γ Δ : Ctx} {Φ Ψ : List Pred}
    (ht : ∀ i, Ordinary (θ.types i))
    (hf : ∀ p ∈ Γ.factsWithCarrier ++ Φ,
      Entails (Δ.factsWithCarrier ++ Ψ) (predBind θ.values p)) (a : Ty) :
    ∀ p ∈ assumptionsWithCarrier Γ Φ a,
      Entails (assumptionsWithCarrier Δ Ψ (a.bind θ)) (predBind (upValues θ.values) p)
```

## Ty.assumeWithCarrier_shiftTypes

配置: `formal/Benitoite/Release/Refinement/TypeShiftContracts.lean`。

```lean
theorem Ty.assumeWithCarrier_shiftTypes (a : Ty) (k c : Nat) :
    (shiftTypes k c a).assumeWithCarrier=a.assumeWithCarrier
```

## Const.NumericRepresented.assume

配置: `formal/Benitoite/Release/Refinement/TypedFacts.lean`。

```lean
theorem Const.NumericRepresented.assume {c : Const} (hc : c.NumericRepresented)
    (Ξ : List Pred) : ∀ p ∈ c.type.assumeWithCarrier,
    Entails Ξ (p.openOptional (Val.const c).toTerm?)
```

## HasTypeVQ.carrierFacts

配置: `formal/Benitoite/Release/Refinement/TypedFacts.lean`。

```lean
theorem HasTypeVQ.carrierFacts {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) :
    ∀ p ∈ a.carrierFacts,
      Entails (Γ.facts ++ Φ) (p.open (v.toTerm?.getD (.integer 0)))
```

## const_meaning

配置: `formal/Benitoite/Release/Refinement/TypedMeaning.lean`。

```lean
theorem const_meaning (P η) (c : Const) (hc : c.NumericRepresented) : ValueMeaning P η (Const.type c) (.const c)
```

## carrierFacts_meaning_closed

配置: `formal/Benitoite/Release/Refinement/TypedMeaning.lean`。

```lean
theorem carrierFacts_meaning_closed {P B Ψ Q C v a}
    (h : HasTypeVQ P B Ψ Q C [] [] v a) (η : ObservationEnvModel) :
    ∀ p ∈ a.carrierFacts, p.interpret (selfModel η v) = true
```

## ValueMeaning.assume

配置: `formal/Benitoite/Release/Refinement/ValueMeaning.lean`。

```lean
theorem ValueMeaning.assume {P η a v} (h : ValueMeaning P η a v) :
    ∀ p ∈ a.assume, p.interpret (selfModel η v) = true
```

## 判断と意味の構成

`Ty.assumeWithCarrier` と `Ctx.factsWithCarrier` は、本来の入口の略記である。`refinementPredicates` は明示した篩の列を保つ。ValueShapeMeaning の23構成子は変わらない。

```lean
| mk {a v} : ValueShapeMeaning P η a.norm.core v →
    (∀ p ∈ a.norm.refinementPredicates, p.interpret (selfModel η v) = true) →
    (∀ p ∈ a.carrierFacts, p.interpret (selfModel η v) = true) → ValueMeaning P η a v
```

## 置換した旧署名

- `Ty.assumeWithCarrier`（`formal/Benitoite/Release/Refinement/CarrierFacts.lean`）。定義を `Context.lean` へ移した。assumeWithCarrier/factsWithCarrierは本来の入口の略記である。
- `Ty.carrierFacts`（`formal/Benitoite/Release/Refinement/CarrierFacts.lean`）。定義を `Context.lean` へ移した。assumeWithCarrier/factsWithCarrierは本来の入口の略記である。
- `integerBounds`（`formal/Benitoite/Release/Refinement/CarrierFacts.lean`）。定義を `Context.lean` へ移した。assumeWithCarrier/factsWithCarrierは本来の入口の略記である。
- `Ctx.factsWithCarrier`（`formal/Benitoite/Release/Refinement/CarrierFacts.lean`）。定義を `Context.lean` へ移した。assumeWithCarrier/factsWithCarrierは本来の入口の略記である。
- `Ty.assume_eq_predicates`（`formal/Benitoite/Release/Refinement/Context.lean`）。後継は `Ty.assume_eq_carrier_append`。
- `Const.NumericRepresented`（`formal/Benitoite/Release/Refinement/ExternalObservation.lean`）。同じ完全名と内容で `NumericRepresented.lean` へ移動した。
- `ConstOK.represented`（`formal/Benitoite/Release/Refinement/ExternalObservation.lean`）。同じ完全名と内容で `NumericRepresented.lean` へ移動した。
- `Ty.entails_assume_iff_predicates`（`formal/Benitoite/Release/Refinement/NormalizationLogic.lean`）。後継は `Ty.entails_assumeWithCarrier_iff`。
