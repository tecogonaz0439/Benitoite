# 段末の実署名（続き）

## Benitoite.Release.Refinement.MatchFacts.excluded_evalClosed_true_of_typing

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 688。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {test : Benitoite.Release.Refinement.PathTest}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v a →
      Benitoite.Release.Refinement.firstAlt v alts = Option.none →
        test ∈ Benitoite.Release.Refinement.excludedTests alts →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.WF 0 (test.predicate t) →
              Benitoite.Release.Refinement.Pred.Sorted [] Option.none (test.predicate t) →
                (test.predicate t).evalClosed = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.excluded_list_cases

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 586。

```lean
∀ {before : List Benitoite.Release.Pat} {rest : Option Benitoite.Release.ListRest} {after : List Benitoite.Release.Pat}
  {test : Benitoite.Release.Refinement.PathTest},
  Benitoite.Release.Refinement.excludedTest? (Benitoite.Release.Pat.list before rest after) = Option.some test →
    test = Benitoite.Release.Refinement.PathTest.nonempty ∧ before = [] ∧ rest = Option.none ∧ after = []
```

## Benitoite.Release.Refinement.MatchFacts.excluded_paths_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 669。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
      Benitoite.Release.Refinement.firstAlt v alts = Option.none →
        (∀ (p : Benitoite.Release.Refinement.Pred),
            p ∈ Benitoite.Release.Refinement.pathFacts v.toTerm? (Benitoite.Release.Refinement.excludedTests alts) →
              Benitoite.Release.Refinement.Pred.WF 0 p ∧ Benitoite.Release.Refinement.Pred.Sorted [] Option.none p) →
          Benitoite.Release.Refinement.PathsEvaluated v (Benitoite.Release.Refinement.excludedTests alts)
```

## Benitoite.Release.Refinement.MatchFacts.excluded_paths_true_of_typing

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 695。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v a →
      Benitoite.Release.Refinement.firstAlt v alts = Option.none →
        (∀ (p : Benitoite.Release.Refinement.Pred),
            p ∈ Benitoite.Release.Refinement.pathFacts v.toTerm? (Benitoite.Release.Refinement.excludedTests alts) →
              Benitoite.Release.Refinement.Pred.WF 0 p ∧ Benitoite.Release.Refinement.Pred.Sorted [] Option.none p) →
          Benitoite.Release.Refinement.PathsEvaluated v (Benitoite.Release.Refinement.excludedTests alts)
```

## Benitoite.Release.Refinement.MatchFacts.excluded_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 640。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {test : Benitoite.Release.Refinement.PathTest} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
      Benitoite.Release.Refinement.firstAlt v alts = Option.none →
        test ∈ Benitoite.Release.Refinement.excludedTests alts →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.excluded_true_of_typing

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 681。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty}
  {v : Benitoite.Release.Refinement.Val} {test : Benitoite.Release.Refinement.PathTest}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v a →
      Benitoite.Release.Refinement.firstAlt v alts = Option.none →
        test ∈ Benitoite.Release.Refinement.excludedTests alts →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.field_equality_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 922。

```lean
∀ {v w : Benitoite.Release.Refinement.Val} {route : List Benitoite.Release.Refinement.FieldRef}
  {t tw : Benitoite.Release.Refinement.Term} {m : Option Benitoite.Release.Refinement.Measure},
  Benitoite.Release.Refinement.MatchFacts.readPath v route = Option.some w →
    Benitoite.Release.Refinement.Term.observe (fun x => Option.none) t =
        v.toTerm?.bind (Benitoite.Release.Refinement.Term.observe fun x => Option.none) →
      w.toTerm? = Option.some tw →
        m = Option.none ∨ m = Option.some Benitoite.Release.Refinement.Measure.listLength →
          Benitoite.Release.Refinement.Term.Shape [] (Benitoite.Release.Refinement.viewTerm m tw)
              Benitoite.Release.Refinement.Sort.integer →
            Benitoite.Release.Refinement.Term.Shape []
                (Benitoite.Release.Refinement.viewTerm m (Benitoite.Release.Refinement.routeTerm t route))
                Benitoite.Release.Refinement.Sort.integer →
              Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
                  (Benitoite.Release.Refinement.Pred.eq (Benitoite.Release.Refinement.viewTerm m tw)
                    (Benitoite.Release.Refinement.viewTerm m (Benitoite.Release.Refinement.routeTerm t route))) =
                Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.firstAlt_none_all

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 93。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {alts : List Benitoite.Release.Alt} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.AltsTy P alts a δ →
    Benitoite.Release.Refinement.firstAlt v alts = Option.none →
      ∀ (alt : Benitoite.Release.Alt), alt ∈ alts → Benitoite.Release.Refinement.matchVal alt.pat v = Option.none
```

## Benitoite.Release.Refinement.MatchFacts.firstAlt_some_mem

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 116。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {alts : List Benitoite.Release.Alt},
  Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
    ∃ alt, alt ∈ alts ∧ ∃ us, Benitoite.Release.Refinement.matchVal alt.pat v = Option.some us
```

## Benitoite.Release.Refinement.MatchFacts.irrefutable_fields_match

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 519。

```lean
∀ {ps : List Benitoite.Release.Pat} {vs : List Benitoite.Release.Refinement.Val},
  ps.all Benitoite.Release.Refinement.irrefutableField = Bool.true →
    ps.length = vs.length → ∃ ws, Benitoite.Release.Refinement.matchList ps vs = Option.some ws
```

## Benitoite.Release.Refinement.MatchFacts.list_root

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 142。

```lean
∀ {b : List Benitoite.Release.Pat} {r : Option Benitoite.Release.ListRest} {a : List Benitoite.Release.Pat}
  {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  (!Decidable.decide ((b.isEmpty && a.isEmpty) = Bool.true)) = Bool.true →
    Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.list b r a) v = Option.some ws →
      ∃ slots, v.toTerm? = Option.some (Benitoite.Release.Refinement.Term.listValue slots) ∧ 0 < slots.length
```

## Benitoite.Release.Refinement.MatchFacts.list_test_cases

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 239。

```lean
∀ {before : List Benitoite.Release.Pat} {rest : Option Benitoite.Release.ListRest} {after : List Benitoite.Release.Pat}
  {test : Benitoite.Release.Refinement.PathTest},
  Benitoite.Release.Refinement.patternTest? (Benitoite.Release.Pat.list before rest after) = Option.some test →
    test = Benitoite.Release.Refinement.PathTest.nonempty ∧
        Benitoite.Release.Refinement.nonemptyPattern (Benitoite.Release.Pat.list before rest after) = Bool.true ∨
      test = Benitoite.Release.Refinement.PathTest.empty ∧ before = [] ∧ rest = Option.none ∧ after = []
```

## Benitoite.Release.Refinement.MatchFacts.literal_test_false

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 429。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {c : Benitoite.Release.Const} {v : Benitoite.Release.Refinement.Val}
  {lit : Benitoite.Release.Refinement.PathLiteral} {t : Benitoite.Release.Refinement.Term},
  c.patternAllowed = Bool.true →
    Benitoite.Release.Refinement.MatchFacts.RootShape P (Benitoite.Release.Refinement.embedConst c).type v →
      Benitoite.Release.Refinement.pathLiteral? c = Option.some lit →
        Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.const c) v = Option.none →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
                ((Benitoite.Release.Refinement.PathTest.literal lit).predicate t) =
              Option.some Bool.false
```

## Benitoite.Release.Refinement.MatchFacts.literal_test_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 192。

```lean
∀ {c : Benitoite.Release.Const} {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {lit : Benitoite.Release.Refinement.PathLiteral} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.pathLiteral? c = Option.some lit →
    Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.const c) v = Option.some ws →
      v.toTerm? = Option.some t →
        Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none)
            ((Benitoite.Release.Refinement.PathTest.literal lit).predicate t) =
          Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.matchList_binders

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 61。

```lean
∀ {ps : List Benitoite.Release.Pat} {vs ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.matchList ps vs = Option.some ws → ws.length = Benitoite.Release.Pat.bindersList ps
```

## Benitoite.Release.Refinement.MatchFacts.matchList_selected

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 714。

```lean
∀ {ps : List Benitoite.Release.Pat} {vs ws : List Benitoite.Release.Refinement.Val} {j : Nat}
  {p : Benitoite.Release.Pat},
  Benitoite.Release.Refinement.matchList ps vs = Option.some ws →
    ps[j]? = Option.some p →
      ∃ v zs,
        vs[j]? = Option.some v ∧
          Benitoite.Release.Refinement.matchVal p v = Option.some zs ∧
            ∀ (i : Nat) (w : Benitoite.Release.Refinement.Val),
              zs[i]? = Option.some w → ws[Benitoite.Release.Pat.bindersList (List.take j ps) + i]? = Option.some w
```

## Benitoite.Release.Refinement.MatchFacts.matchVal_binders

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 29。

```lean
∀ {p : Benitoite.Release.Pat} {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.matchVal p v = Option.some ws → ws.length = p.binders
```

## Benitoite.Release.Refinement.MatchFacts.matched_evalClosed_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 336。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {alts : List Benitoite.Release.Alt} {test : Benitoite.Release.Refinement.PathTest}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
    test ∈ Benitoite.Release.Refinement.matchedTests alts →
      v.toTerm? = Option.some t →
        Benitoite.Release.Refinement.Pred.WF 0 (test.predicate t) →
          Benitoite.Release.Refinement.Pred.Sorted [] Option.none (test.predicate t) →
            (test.predicate t).evalClosed = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.matched_paths_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 657。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {alts : List Benitoite.Release.Alt}
  {ws : List Benitoite.Release.Refinement.Val},
  Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
    (∀ (p : Benitoite.Release.Refinement.Pred),
        p ∈ Benitoite.Release.Refinement.pathFacts v.toTerm? (Benitoite.Release.Refinement.matchedTests alts) →
          Benitoite.Release.Refinement.Pred.WF 0 p ∧ Benitoite.Release.Refinement.Pred.Sorted [] Option.none p) →
      Benitoite.Release.Refinement.PathsEvaluated v (Benitoite.Release.Refinement.matchedTests alts)
```

## Benitoite.Release.Refinement.MatchFacts.matched_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 309。

```lean
∀ {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {alts : List Benitoite.Release.Alt} {test : Benitoite.Release.Refinement.PathTest}
  {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.firstAlt v alts = Option.some ws →
    test ∈ Benitoite.Release.Refinement.matchedTests alts →
      v.toTerm? = Option.some t →
        Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.observeSlots_length

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 163。

```lean
∀ (η : Benitoite.Release.Refinement.ObservationEnvModel) (slots : List (Option Benitoite.Release.Refinement.Term)),
  (Benitoite.Release.Refinement.observeSlots η slots).length = slots.length
```

## Benitoite.Release.Refinement.MatchFacts.pattern_excluded_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 597。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {pat : Benitoite.Release.Pat} {a : Benitoite.Release.Refinement.Ty}
  {δ : List Benitoite.Release.Refinement.Ty} {v : Benitoite.Release.Refinement.Val}
  {test : Benitoite.Release.Refinement.PathTest} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.PatTy P pat a δ →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
      Benitoite.Release.Refinement.excludedTest? pat = Option.some test →
        Benitoite.Release.Refinement.matchVal pat v = Option.none →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.pattern_test_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 256。

```lean
∀ {pat : Benitoite.Release.Pat} {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {test : Benitoite.Release.Refinement.PathTest} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.patternTest? pat = Option.some test →
    Benitoite.Release.Refinement.matchVal pat v = Option.some ws →
      v.toTerm? = Option.some t →
        Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.range_test_false

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 508。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {lo hi : Benitoite.Release.Const} {v : Benitoite.Release.Refinement.Val}
  {test : Benitoite.Release.Refinement.PathTest} {t : Benitoite.Release.Refinement.Term}
  {a : Benitoite.Release.Refinement.Ty} {δ : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.PatTy P (Benitoite.Release.Pat.range lo hi) a δ →
    Benitoite.Release.Refinement.MatchFacts.RootShape P a v →
      Benitoite.Release.Refinement.patternTest? (Benitoite.Release.Pat.range lo hi) = Option.some test →
        Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.range lo hi) v = Option.none →
          v.toTerm? = Option.some t →
            Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) =
              Option.some Bool.false
```

## Benitoite.Release.Refinement.MatchFacts.range_test_true

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 207。

```lean
∀ {lo hi : Benitoite.Release.Const} {v : Benitoite.Release.Refinement.Val} {ws : List Benitoite.Release.Refinement.Val}
  {test : Benitoite.Release.Refinement.PathTest} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.patternTest? (Benitoite.Release.Pat.range lo hi) = Option.some test →
    Benitoite.Release.Refinement.matchVal (Benitoite.Release.Pat.range lo hi) v = Option.some ws →
      v.toTerm? = Option.some t →
        Benitoite.Release.Refinement.Pred.evalWith (fun x => Option.none) (test.predicate t) = Option.some Bool.true
```

## Benitoite.Release.Refinement.MatchFacts.readPath

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 708。

```lean
Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.FieldRef → Option Benitoite.Release.Refinement.Val
```

## Benitoite.Release.Refinement.MatchFacts.rootShape_of_typing

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 408。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Φ : List Benitoite.Release.Refinement.Pred}
  {v : Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVQ P B Ψ Q C [] Φ v a → Benitoite.Release.Refinement.MatchFacts.RootShape P a v
```

## Benitoite.Release.Refinement.MatchFacts.selectSlots_total

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 83。

```lean
∀ {α : Type} {xs : List α} {slots : List Nat},
  (∀ (i : Nat), i ∈ slots → i < xs.length) → ∃ ys, Benitoite.Release.Refinement.selectSlots xs slots = Option.some ys
```

## Benitoite.Release.Refinement.MatchFacts.tacticMatch_eval_simp

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 175。

```lean
Lean.ParserDescr
```

## Benitoite.Release.Refinement.MatchFacts.typed_values_length

所在: `formal/Benitoite/Release/Refinement/MatchFacts.lean`、行: 382。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins}
  {Ψ : Benitoite.Release.Refinement.StoreTy} {Q : Benitoite.Release.NoFailCtx}
  {C : Benitoite.Release.Refinement.TypeCtx} {Γ : Benitoite.Release.Refinement.Ctx}
  {Φ : List Benitoite.Release.Refinement.Pred} {vs : List Benitoite.Release.Refinement.Val}
  {as : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.HasTypeVsQ P B Ψ Q C Γ Φ vs as → vs.length = as.length
```

## Benitoite.Release.Refinement.MatchPrefix

所在: `formal/Benitoite/Release/Refinement/Semantics.lean`、行: 56。

```lean
Benitoite.Release.Refinement.Val → List Benitoite.Release.Refinement.Arm → Nat → Prop
```

## Benitoite.Release.Refinement.Measure

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 206。

```lean
Type
```

## Benitoite.Release.Refinement.Measure.bytesLength

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.bytesLength.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 3 → motive Benitoite.Release.Refinement.Measure.bytesLength → motive t
```

## Benitoite.Release.Refinement.Measure.characterCode

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 208。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.characterCode.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 208。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 6 → motive Benitoite.Release.Refinement.Measure.characterCode → motive t
```

## Benitoite.Release.Refinement.Measure.ctorElim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 206。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (ctorIdx : Nat) →
    (t : Benitoite.Release.Refinement.Measure) →
      ctorIdx = t.ctorIdx → Benitoite.Release.Refinement.Measure.ctorElimType ctorIdx → motive t
```

## Benitoite.Release.Refinement.Measure.input

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 211。

```lean
Benitoite.Release.Refinement.Measure → Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Measure.listLength

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.listLength.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 2 → motive Benitoite.Release.Refinement.Measure.listLength → motive t
```

## Benitoite.Release.Refinement.Measure.mapSize

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.mapSize.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 4 → motive Benitoite.Release.Refinement.Measure.mapSize → motive t
```

## Benitoite.Release.Refinement.Measure.noConfusion

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 206。

```lean
{P : Sort v✝} →
  {x y : Benitoite.Release.Refinement.Measure} → x = y → Benitoite.Release.Refinement.Measure.noConfusionType P x y
```

## Benitoite.Release.Refinement.Measure.output

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 219。

```lean
Benitoite.Release.Refinement.Measure → Benitoite.Release.Refinement.Sort
```

## Benitoite.Release.Refinement.Measure.setSize

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.setSize.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 5 → motive Benitoite.Release.Refinement.Measure.setSize → motive t
```

## Benitoite.Release.Refinement.Measure.stringBytes

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.stringBytes.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 0 → motive Benitoite.Release.Refinement.Measure.stringBytes → motive t
```

## Benitoite.Release.Refinement.Measure.stringCharacters

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
Benitoite.Release.Refinement.Measure
```

## Benitoite.Release.Refinement.Measure.stringCharacters.elim

所在: `formal/Benitoite/Release/Refinement/ScopeSyntax.lean`、行: 207。

```lean
{motive : Benitoite.Release.Refinement.Measure → Sort u} →
  (t : Benitoite.Release.Refinement.Measure) →
    t.ctorIdx = 1 → motive Benitoite.Release.Refinement.Measure.stringCharacters → motive t
```

## Benitoite.Release.Refinement.MethSig

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 289。

```lean
Type
```

## Benitoite.Release.Refinement.MethSig.eff

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 298。

```lean
Benitoite.Release.Refinement.MethSig → Benitoite.Release.Refinement.Eff
```

## Benitoite.Release.Refinement.MethSig.mk

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 292。

```lean
List Benitoite.Release.Refinement.TParamDecl →
  Nat →
    List String →
      List Benitoite.Release.Refinement.Ty →
        Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Eff → Benitoite.Release.Refinement.MethSig
```

## Benitoite.Release.Refinement.MethSig.mk.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 292。

```lean
{P : Sort u} →
  {tparams : List Benitoite.Release.Refinement.TParamDecl} →
    {neffs : Nat} →
      {names : List String} →
        {params : List Benitoite.Release.Refinement.Ty} →
          {ret : Benitoite.Release.Refinement.Ty} →
            {eff : Benitoite.Release.Refinement.Eff} →
              {tparams' : List Benitoite.Release.Refinement.TParamDecl} →
                {neffs' : Nat} →
                  {names' : List String} →
                    {params' : List Benitoite.Release.Refinement.Ty} →
                      {ret' : Benitoite.Release.Refinement.Ty} →
                        {eff' : Benitoite.Release.Refinement.Eff} →
                          { tparams := tparams, neffs := neffs, names := names, params := params, ret := ret,
                                eff := eff } =
                              { tparams := tparams', neffs := neffs', names := names', params := params', ret := ret',
                                eff := eff' } →
                            (tparams = tparams' →
                                neffs = neffs' → names = names' → params = params' → ret = ret' → eff = eff' → P) →
                              P
```

## Benitoite.Release.Refinement.MethSig.names

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 295。

```lean
Benitoite.Release.Refinement.MethSig → List String
```

## Benitoite.Release.Refinement.MethSig.neffs

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 294。

```lean
Benitoite.Release.Refinement.MethSig → Nat
```

## Benitoite.Release.Refinement.MethSig.noConfusion

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 289。

```lean
{P : Sort u} →
  {t t' : Benitoite.Release.Refinement.MethSig} → t = t' → Benitoite.Release.Refinement.MethSig.noConfusionType P t t'
```

## Benitoite.Release.Refinement.MethSig.params

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 296。

```lean
Benitoite.Release.Refinement.MethSig → List Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.MethSig.ret

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 297。

```lean
Benitoite.Release.Refinement.MethSig → Benitoite.Release.Refinement.Ty
```

## Benitoite.Release.Refinement.MethSig.tel

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 464。

```lean
Benitoite.Release.Refinement.MethSig → Benitoite.Release.Refinement.Tel
```

## Benitoite.Release.Refinement.MethSig.tparams

所在: `formal/Benitoite/Release/Refinement/Syntax.lean`、行: 293。

```lean
Benitoite.Release.Refinement.MethSig → List Benitoite.Release.Refinement.TParamDecl
```

## Benitoite.Release.Refinement.Model.admits_sat

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 80。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : Benitoite.Release.Refinement.TypeCtx}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.Model.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

## Benitoite.Release.Refinement.Model.builtins

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 18。

```lean
Benitoite.Release.Refinement.Builtins
```

## Benitoite.Release.Refinement.Model.delta_typed

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 142。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
      Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        ∃ out,
          Benitoite.Release.Refinement.Model.builtins.delta b ts es rs ws = Option.some out ∧
            (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
              Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.Model.builtins Ψ out a ∧
                Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.Model.effect_ops

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 108。

```lean
∀ {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  Benitoite.Release.Refinement.Model.builtins.effects l = Option.some bs →
    b ∈ bs →
      ∃ s,
        Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s ∧
          (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            s.opEff = Option.some l
```

## Benitoite.Release.Refinement.Model.effects

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 14。

```lean
Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

## Benitoite.Release.Refinement.Model.entries

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 10。

```lean
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

## Benitoite.Release.Refinement.Model.io_exists

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 163。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        ∃ out obs, Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.Model.io_kind

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 156。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some sg →
    Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
      Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
        (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
            ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∨
          sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∧
            ∀ (v : Benitoite.Release.Refinement.Val), out ≠ Benitoite.Release.Refinement.Outcome.val v
```

## Benitoite.Release.Refinement.Model.io_op

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 98。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.Model.builtins.ShapeOk b s
```

## Benitoite.Release.Refinement.Model.io_typed

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 150。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.Model.builtins Ψ b sg ts es rs ws a e →
        Benitoite.Release.Refinement.Model.builtins.ioResponse b ts es ws out obs →
          Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.Model.builtins Ψ out a ∧
            Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.Model.opEff_io

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 101。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s →
    s.opEff = Option.some l →
      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ s.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

## Benitoite.Release.Refinement.Model.pathBases_shape

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 85。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s →
    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      s.PathBasesShape Benitoite.Release.Refinement.Model.builtins b
```

## Benitoite.Release.Refinement.Model.ref_get

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 125。

```lean
∃ s,
  Benitoite.Release.Refinement.Model.builtins.sig Benitoite.Release.Refinement.Model.builtins.refGet = Option.some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

## Benitoite.Release.Refinement.Model.ref_set

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 128。

```lean
∃ s,
  Benitoite.Release.Refinement.Model.builtins.sig Benitoite.Release.Refinement.Model.builtins.refSet = Option.some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

## Benitoite.Release.Refinement.Model.responseAssumptions

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 169。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.ResponseAssumptions P Benitoite.Release.Refinement.Model.builtins
```

## Benitoite.Release.Refinement.Model.sat_unconstrained

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 77。

```lean
∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.Model.builtins.sat [] t.norm { }
```

## Benitoite.Release.Refinement.Model.scopeConditions

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 181。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.Model.builtins
```

## Benitoite.Release.Refinement.Model.sig_cases

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 25。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s →
    b = "Reference.get" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refGet ∨
      b = "Reference.set" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refSet ∨
        b = Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∧
          s = Benitoite.Release.Refinement.ScopeSignatures.pathBases
```

## Benitoite.Release.Refinement.Model.sig_scoped

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 62。

```lean
∀ (P : Benitoite.Release.Refinement.Program) {b : Benitoite.Release.PrimName}
  {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s → Benitoite.Release.Refinement.PrimSig.Scoped P s
```

## Benitoite.Release.Refinement.Model.state_effect

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 123。

```lean
Benitoite.Release.Refinement.Model.builtins.effects Benitoite.Release.stateEff = Option.some []
```

## Benitoite.Release.Refinement.Model.store_admits

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 138。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s → ts.length = s.tparams.length → s.admits C ts
```

## Benitoite.Release.Refinement.Model.store_shape

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 131。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.Model.builtins.sig b = Option.some s →
    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape
```

## Benitoite.Release.Refinement.Model.substitutionAssumptions

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 37。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P Benitoite.Release.Refinement.Model.builtins
```

## Benitoite.Release.Refinement.Model.targetAgreement

所在: `formal/Benitoite/Release/Refinement/Model.lean`、行: 175。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P Benitoite.Release.Refinement.Model.builtins
```

## Benitoite.Release.Refinement.ModelConstraints.admits

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 13。

```lean
Benitoite.Release.SummaryTable →
  List Benitoite.Release.TParam → List Benitoite.Release.TParam → List Benitoite.Release.Refinement.Ty → Prop
```

## Benitoite.Release.Refinement.ModelConstraints.admits_bind_values

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 32。

```lean
∀ (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
  (as : List Benitoite.Release.Refinement.Ty) (θ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), θ.types i = Benitoite.Release.Refinement.Ty.tvar i) →
    (Benitoite.Release.Refinement.ModelConstraints.admits S ps C
        (List.map (fun a => Benitoite.Release.Refinement.Ty.bind θ a) as) ↔
      Benitoite.Release.Refinement.ModelConstraints.admits S ps C as)
```

## Benitoite.Release.Refinement.ModelConstraints.admits_map

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 69。

```lean
∀ {S : Benitoite.Release.SummaryTable} {ps C D : List Benitoite.Release.TParam}
  {as : List Benitoite.Release.Refinement.Ty} {f : Benitoite.Release.Refinement.Ty → Benitoite.Release.Refinement.Ty},
  (∀ (a : Benitoite.Release.Refinement.Ty) (p : Benitoite.Release.TParam),
      Benitoite.Release.Refinement.ModelConstraints.sat S C a p →
        Benitoite.Release.Refinement.ModelConstraints.sat S D (f a) p) →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C as →
      Benitoite.Release.Refinement.ModelConstraints.admits S ps D (List.map f as)
```

## Benitoite.Release.Refinement.ModelConstraints.admits_rename

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 79。

```lean
∀ (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
  (as : List Benitoite.Release.Refinement.Ty) (ξ : Nat → Nat),
  Benitoite.Release.Refinement.ModelConstraints.admits S ps C as →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C (List.map (Benitoite.Release.Refinement.renameTy ξ) as)
```

## Benitoite.Release.Refinement.ModelConstraints.admits_renameTypes

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 232。

```lean
∀ {S : Benitoite.Release.SummaryTable} {ps : List Benitoite.Release.TParam} {C D : Benitoite.Release.Refinement.TypeCtx}
  {ρ : Nat → Nat} {as : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.TypeParamRenaming C D ρ →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C.constraints as →
      Benitoite.Release.Refinement.ModelConstraints.admits S ps D.constraints (List.map (fun a => a.renameTypes ρ) as)
```

## Benitoite.Release.Refinement.ModelConstraints.admits_subst

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 279。

```lean
∀ {S : Benitoite.Release.SummaryTable} {ps : List Benitoite.Release.TParam}
  {C0 C1 : Benitoite.Release.Refinement.TypeCtx} {as ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ModelConstraints.admits S ps (C1 ++ C0).constraints as →
    (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
      (ts.length = C0.constraints.length ∧
          ∀ (i : Nat) (t : Benitoite.Release.Refinement.Ty) (q : Benitoite.Release.TParam),
            ts[i]? = Option.some t →
              C0.constraints[i]? = Option.some q →
                Benitoite.Release.Refinement.ModelConstraints.sat S C1.constraints t.norm q) →
        ts.length = List.length C0 →
          Benitoite.Release.Refinement.ModelConstraints.admits S ps C1.constraints
            (List.map (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es) as)
```

## Benitoite.Release.Refinement.ModelConstraints.admits_values

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 84。

```lean
∀ (S : Benitoite.Release.SummaryTable) (ps C : List Benitoite.Release.TParam)
  (as : List Benitoite.Release.Refinement.Ty) (ν : Nat → Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.ModelConstraints.admits S ps C as →
    Benitoite.Release.Refinement.ModelConstraints.admits S ps C
      (List.map (Benitoite.Release.Refinement.substTyValues ν) as)
```

## Benitoite.Release.Refinement.ModelConstraints.sat

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 10。

```lean
Benitoite.Release.SummaryTable →
  List Benitoite.Release.TParam → Benitoite.Release.Refinement.Ty → Benitoite.Release.TParam → Prop
```

## Benitoite.Release.Refinement.ModelConstraints.sat_bind_values

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 26。

```lean
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam) (θ : Benitoite.Release.Refinement.SubstEnv),
  (∀ (i : Nat), θ.types i = Benitoite.Release.Refinement.Ty.tvar i) →
    (Benitoite.Release.Refinement.ModelConstraints.sat S C (Benitoite.Release.Refinement.Ty.bind θ a) p ↔
      Benitoite.Release.Refinement.ModelConstraints.sat S C a p)
```

## Benitoite.Release.Refinement.ModelConstraints.sat_norm

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 237。

```lean
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam),
  Benitoite.Release.Refinement.ModelConstraints.sat S C a.norm p ↔
    Benitoite.Release.Refinement.ModelConstraints.sat S C a p
```

## Benitoite.Release.Refinement.ModelConstraints.sat_rename

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 57。

```lean
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam) (ξ : Nat → Nat),
  Benitoite.Release.Refinement.ModelConstraints.sat S C (Benitoite.Release.Refinement.renameTy ξ a) p ↔
    Benitoite.Release.Refinement.ModelConstraints.sat S C a p
```

## Benitoite.Release.Refinement.ModelConstraints.sat_renameTypes

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 211。

```lean
∀ {S : Benitoite.Release.SummaryTable} {C D : Benitoite.Release.Refinement.TypeCtx} {ρ : Nat → Nat}
  {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.TParam},
  Benitoite.Release.Refinement.TypeParamRenaming C D ρ →
    Benitoite.Release.Refinement.ModelConstraints.sat S C.constraints a p →
      Benitoite.Release.Refinement.ModelConstraints.sat S D.constraints (a.renameTypes ρ) p
```

## Benitoite.Release.Refinement.ModelConstraints.sat_subst

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 241。

```lean
∀ {S : Benitoite.Release.SummaryTable} {C0 C1 : Benitoite.Release.Refinement.TypeCtx}
  {a : Benitoite.Release.Refinement.Ty} {p : Benitoite.Release.TParam} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ModelConstraints.sat S (C1 ++ C0).constraints a p →
    (∀ (t : Benitoite.Release.Refinement.Ty), t ∈ ts → Benitoite.Release.Refinement.Ty.WF 0 0 0 t) →
      (ts.length = C0.constraints.length ∧
          ∀ (i : Nat) (t : Benitoite.Release.Refinement.Ty) (q : Benitoite.Release.TParam),
            ts[i]? = Option.some t →
              C0.constraints[i]? = Option.some q →
                Benitoite.Release.Refinement.ModelConstraints.sat S C1.constraints t.norm q) →
        ts.length = List.length C0 →
          Benitoite.Release.Refinement.ModelConstraints.sat S C1.constraints
            (Benitoite.Release.Refinement.Ty.substAt (List.length C1) ts es a) p
```

## Benitoite.Release.Refinement.ModelConstraints.sat_unconstrained

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 289。

```lean
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty),
  Benitoite.Release.Refinement.ModelConstraints.sat S C a { }
```

## Benitoite.Release.Refinement.ModelConstraints.sat_values

所在: `formal/Benitoite/Release/Refinement/ModelConstraints.lean`、行: 63。

```lean
∀ (S : Benitoite.Release.SummaryTable) (C : List Benitoite.Release.TParam) (a : Benitoite.Release.Refinement.Ty)
  (p : Benitoite.Release.TParam) (ν : Nat → Benitoite.Release.Refinement.Val),
  Benitoite.Release.Refinement.ModelConstraints.sat S C (Benitoite.Release.Refinement.substTyValues ν a) p ↔
    Benitoite.Release.Refinement.ModelConstraints.sat S C a p
```

## Benitoite.Release.Refinement.ModelHttp.admits_sat

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 88。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig} {C : Benitoite.Release.Refinement.TypeCtx}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some s →
    s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
      Benitoite.Release.Refinement.SatAll Benitoite.Release.Refinement.ModelHttp.builtins C ts
        (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

## Benitoite.Release.Refinement.ModelHttp.builtins

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 27。

```lean
Benitoite.Release.Refinement.Builtins
```

## Benitoite.Release.Refinement.ModelHttp.delta_typed

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 161。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          ∃ out,
            Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.ModelHttp.effect_ops

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 112。

```lean
∀ {l : Benitoite.Release.EffName} {bs : List Benitoite.Release.PrimName} {b : Benitoite.Release.PrimName},
  Benitoite.Release.Refinement.ModelHttp.builtins.effects l = Option.some bs →
    b ∈ bs →
      ∃ sg,
        Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg ∧
          (sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
              sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
            sg.opEff = Option.some l
```

## Benitoite.Release.Refinement.ModelHttp.effects

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 16。

```lean
Benitoite.Release.EffName → Option (List Benitoite.Release.PrimName)
```

## Benitoite.Release.Refinement.ModelHttp.entries

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 10。

```lean
List (Benitoite.Release.PrimName × Benitoite.Release.Refinement.PrimSig)
```

## Benitoite.Release.Refinement.ModelHttp.ioResponse

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 22。

```lean
Benitoite.Release.PrimName →
  List Benitoite.Release.Refinement.Ty →
    List Benitoite.Release.Refinement.Eff →
      List Benitoite.Release.Refinement.Val →
        Benitoite.Release.Refinement.Outcome → List Benitoite.Scope.Domain.Target → Prop
```

## Benitoite.Release.Refinement.ModelHttp.io_exists

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 236。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          ∃ out obs, Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.ModelHttp.io_kind

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 224。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {ws : List Benitoite.Release.Refinement.Val} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∧
        ∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n
```

## Benitoite.Release.Refinement.ModelHttp.io_op

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 99。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
      Benitoite.Release.Refinement.ModelHttp.builtins.ShapeOk b sg
```

## Benitoite.Release.Refinement.ModelHttp.io_typed

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 215。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out
```

## Benitoite.Release.Refinement.ModelHttp.normal_facts

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 181。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {v : Benitoite.Release.Refinement.Val} {t : Benitoite.Release.Refinement.Term},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws =
              Option.some (Benitoite.Release.Refinement.Outcome.val v) →
            v.toTerm? = Option.some t →
              ∀ (r : Benitoite.Release.Refinement.Pred),
                r ∈ a.assume → Benitoite.Release.Refinement.Entails [] (r.open t)
```

## Benitoite.Release.Refinement.ModelHttp.obs_allowed

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 256。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome}
  {obs : List Benitoite.Scope.Domain.Target} {σ : Benitoite.Release.Refinement.PathEnv},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.exit →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          (∀ (w : Benitoite.Release.Refinement.Val), w ∈ ws → Benitoite.Release.Refinement.Val.Adequate σ w) →
            Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
              ∃ l,
                sg.opEff = Option.some l ∧
                  ∀ (t : Benitoite.Scope.Domain.Target),
                    t ∈ obs →
                      Benitoite.Release.Refinement.Eff.Allows σ Benitoite.Release.Refinement.ModelHttp.builtins.effKind
                        e l t
```

## Benitoite.Release.Refinement.ModelHttp.opEff_io

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 107。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig} {l : Benitoite.Release.EffName},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    sg.opEff = Option.some l →
      sg.kind = Benitoite.Release.Refinement.PrimKind.io ∨
        sg.kind = Benitoite.Release.Refinement.PrimKind.exit ∨ sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases
```

## Benitoite.Release.Refinement.ModelHttp.pathBases_no_io

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 266。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      ∀ (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
        (ws : List Benitoite.Release.Refinement.Val) (out : Benitoite.Release.Refinement.Outcome)
        (obs : List Benitoite.Scope.Domain.Target),
        ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs
```

## Benitoite.Release.Refinement.ModelHttp.pathBases_shape

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 93。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    sg.kind = Benitoite.Release.Refinement.PrimKind.pathBases →
      sg.PathBasesShape Benitoite.Release.Refinement.ModelHttp.builtins b
```

## Benitoite.Release.Refinement.ModelHttp.pure_outcome

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 170。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff} {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = Option.some out →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  ∀ (v : Benitoite.Release.Refinement.Val), out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ModelHttp.pure_response

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 145。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy} {b : Benitoite.Release.PrimName}
  {sg : Benitoite.Release.Refinement.PrimSig} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {rs : List Benitoite.Release.Refinement.RangeExpr}
  {ws : List Benitoite.Release.Refinement.Val} {a : Benitoite.Release.Refinement.Ty}
  {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
      sg.kind = Benitoite.Release.Refinement.PrimKind.pure →
        Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ b sg ts es rs ws a
            e →
          ∃ out,
            Benitoite.Release.Refinement.ModelHttp.builtins.delta b ts es rs ws = Option.some out ∧
              (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
                  Benitoite.Release.Refinement.AdequateResult ws out ∧
                    ∀ (v : Benitoite.Release.Refinement.Val),
                      out = Benitoite.Release.Refinement.Outcome.val v → v.Ground
```

## Benitoite.Release.Refinement.ModelHttp.ref_get

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 123。

```lean
∃ s,
  Benitoite.Release.Refinement.ModelHttp.builtins.sig Benitoite.Release.Refinement.ModelHttp.builtins.refGet =
      Option.some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refGet
```

## Benitoite.Release.Refinement.ModelHttp.ref_set

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 126。

```lean
∃ s,
  Benitoite.Release.Refinement.ModelHttp.builtins.sig Benitoite.Release.Refinement.ModelHttp.builtins.refSet =
      Option.some s ∧
    s.kind = Benitoite.Release.Refinement.PrimKind.refSet
```

## Benitoite.Release.Refinement.ModelHttp.responseAssumptions

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 320。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P Benitoite.Release.Refinement.ModelHttp.builtins
```

## Benitoite.Release.Refinement.ModelHttp.sat_unconstrained

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 85。

```lean
∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.ModelHttp.builtins.sat [] t.norm { }
```

## Benitoite.Release.Refinement.ModelHttp.scopeConditions

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 327。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    Benitoite.Release.Refinement.ModelScopeConditions P Benitoite.Release.Refinement.ModelHttp.builtins
```

## Benitoite.Release.Refinement.ModelHttp.send_held

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 274。

```lean
∀ {req : Benitoite.Release.Refinement.Val} {t : Benitoite.Scope.Domain.Target}
  {out : Benitoite.Release.Refinement.Outcome},
  Benitoite.Release.Refinement.groundVal req = Bool.true →
    req.reqTarget = Option.some t →
      Benitoite.Release.Refinement.ScopedIOResponse.Reply Benitoite.Release.Refinement.ScopedIOResponse.ResultKind.http
          out →
        ∀ (r : Benitoite.Release.Refinement.RangeExpr) (snap : Option Benitoite.Release.Refinement.PathEnv),
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" [] []
              [Benitoite.Release.Refinement.Val.checkedRequest t req] out [t] ∧
            Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" [] []
              [Benitoite.Release.Refinement.Val.checkedAt r snap t (Option.some req)] out [t]
```

## Benitoite.Release.Refinement.ModelHttp.send_mismatch

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 300。

```lean
∀ {req : Benitoite.Release.Refinement.Val} {t other : Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.groundVal req = Bool.true →
    req.reqTarget = Option.some t →
      t ≠ other →
        ∀ (r : Benitoite.Release.Refinement.RangeExpr) (snap : Option Benitoite.Release.Refinement.PathEnv)
          (ts : List Benitoite.Release.Refinement.Ty) (es : List Benitoite.Release.Refinement.Eff)
          (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
          ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
                [Benitoite.Release.Refinement.Val.checkedRequest other req] out obs ∧
            ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
                [Benitoite.Release.Refinement.Val.checkedAt r snap other (Option.some req)] out obs
```

## Benitoite.Release.Refinement.ModelHttp.send_response

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 204。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {Ψ : Benitoite.Release.Refinement.StoreTy}
  {ts : List Benitoite.Release.Refinement.Ty} {es : List Benitoite.Release.Refinement.Eff}
  {rs : List Benitoite.Release.Refinement.RangeExpr} {ws : List Benitoite.Release.Refinement.Val}
  {a : Benitoite.Release.Refinement.Ty} {e : Benitoite.Release.Refinement.Eff},
  Benitoite.Release.Refinement.ScopeDeclarations.HasFile P →
    Benitoite.Release.Refinement.BuiltinArgs P Benitoite.Release.Refinement.ModelHttp.builtins Ψ "Http.sendIn"
        Benitoite.Release.Refinement.ScopeSignatures.sendIn ts es rs ws a e →
      (∀ (out : Benitoite.Release.Refinement.Outcome) (obs : List Benitoite.Scope.Domain.Target),
          Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es ws out obs →
            Benitoite.Release.Refinement.Outcome.Typed P Benitoite.Release.Refinement.ModelHttp.builtins Ψ out a ∧
              Benitoite.Release.Refinement.AdequateResult ws out ∧
                (∀ (n : Int), out ≠ Benitoite.Release.Refinement.Outcome.exit n) ∧
                  Benitoite.Scope.Signature.ShapeTargets Benitoite.Release.Refinement.Val.target?
                    (Benitoite.Release.Refinement.ScopeSignatures.sendIn.shapeAt ws) ws obs) ∧
        ∃ out obs, Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es ws out obs
```

## Benitoite.Release.Refinement.ModelHttp.send_without_request

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 285。

```lean
∀ (t : Benitoite.Scope.Domain.Target) (r : Benitoite.Release.Refinement.RangeExpr)
  (snap : Option Benitoite.Release.Refinement.PathEnv) (ts : List Benitoite.Release.Refinement.Ty)
  (es : List Benitoite.Release.Refinement.Eff) (out : Benitoite.Release.Refinement.Outcome)
  (obs : List Benitoite.Scope.Domain.Target),
  ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
        [Benitoite.Release.Refinement.Val.checked t] out obs ∧
    ¬Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse "Http.sendIn" ts es
        [Benitoite.Release.Refinement.Val.checkedAt r snap t Option.none] out obs
```

## Benitoite.Release.Refinement.ModelHttp.sent_request

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 243。

```lean
∀ {b : Benitoite.Release.PrimName} {ts : List Benitoite.Release.Refinement.Ty}
  {es : List Benitoite.Release.Refinement.Eff} {ws : List Benitoite.Release.Refinement.Val}
  {out : Benitoite.Release.Refinement.Outcome} {obs : List Benitoite.Scope.Domain.Target},
  Benitoite.Release.Refinement.ModelHttp.builtins.ioResponse b ts es ws out obs →
    b = "Http.sendIn" ∧
      ∃ w req t,
        ws = [w] ∧
          Benitoite.Release.Refinement.ModelHttp.valueRun [w] = Benitoite.Release.Refinement.Outcome.val req ∧
            Benitoite.Release.Refinement.groundVal req = Bool.true ∧
              req.reqTarget = Option.some t ∧ w.target? = Option.some t ∧ obs = [t]
```

## Benitoite.Release.Refinement.ModelHttp.sig_cases

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 34。

```lean
∀ {b : Benitoite.Release.PrimName} {s : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some s →
    b = "Reference.get" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refGet ∨
      b = "Reference.set" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.refSet ∨
        b = "Http.checkRequestIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.checkRequestIn ∨
          b = "Http.requestInValue" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.requestInValue ∨
            b = "Http.sendIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.sendIn ∨
              b = "Http.widenRequestIn" ∧ s = Benitoite.Release.Refinement.ScopeSignatures.widenRequestIn ∨
                b = Benitoite.Release.Refinement.ScopeSignatures.pathBasesName ∧
                  s = Benitoite.Release.Refinement.ScopeSignatures.pathBases
```

## Benitoite.Release.Refinement.ModelHttp.sig_scoped

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 75。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
        Benitoite.Release.Refinement.PrimSig.Scoped P sg
```

## Benitoite.Release.Refinement.ModelHttp.sourceTelRows

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 80。

```lean
∀ {P : Benitoite.Release.Refinement.Program},
  Benitoite.Release.Refinement.ScopeDeclarations.HasHttp P →
    ∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
      Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
        Benitoite.Release.Refinement.Tel.RowsIn (fun x => x < sg.neffs) sg.tel
```

## Benitoite.Release.Refinement.ModelHttp.state_effect

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 121。

```lean
Benitoite.Release.Refinement.ModelHttp.builtins.effects Benitoite.Release.stateEff = Option.some []
```

## Benitoite.Release.Refinement.ModelHttp.store_admits

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 137。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig} {C : List Benitoite.Release.TParam}
  {ts : List Benitoite.Release.Refinement.Ty},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    ts.length = sg.tparams.length → sg.admits C ts
```

## Benitoite.Release.Refinement.ModelHttp.store_shape

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 129。

```lean
∀ {b : Benitoite.Release.PrimName} {sg : Benitoite.Release.Refinement.PrimSig},
  Benitoite.Release.Refinement.ModelHttp.builtins.sig b = Option.some sg →
    sg.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → sg.StoreShape
```

## Benitoite.Release.Refinement.ModelHttp.substitutionAssumptions

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 49。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P Benitoite.Release.Refinement.ModelHttp.builtins
```

## Benitoite.Release.Refinement.ModelHttp.targetAgreement

所在: `formal/Benitoite/Release/Refinement/ModelHttpConditions.lean`、行: 250。

```lean
∀ (P : Benitoite.Release.Refinement.Program),
  Benitoite.Release.Refinement.Builtins.TargetAgreement P Benitoite.Release.Refinement.ModelHttp.builtins
```

## Benitoite.Release.Refinement.ModelHttp.valueRun

所在: `formal/Benitoite/Release/Refinement/ModelHttp.lean`、行: 14。

```lean
List Benitoite.Release.Refinement.Val → Benitoite.Release.Refinement.Outcome
```

## Benitoite.Release.Refinement.ModelScopeConditions

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 5。

```lean
Benitoite.Release.Refinement.Program → Benitoite.Release.Refinement.Builtins → Prop
```

## Benitoite.Release.Refinement.ModelScopeConditions.admits_sat

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 11。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
      (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
      B.sig b = Option.some s →
        s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
          Benitoite.Release.Refinement.SatAll B C ts
            (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)
```

## Benitoite.Release.Refinement.ModelScopeConditions.core

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 30。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    Benitoite.Release.Refinement.Builtins.ExternalAssumptions P B →
      (∀ (Ψ : Benitoite.Release.Refinement.StoreTy) (v : Benitoite.Release.Refinement.Val)
          (o : Benitoite.Release.OpaqueName),
          Benitoite.Release.Refinement.HasTypeV P B Ψ [] [] [] v
              (Benitoite.Release.Refinement.Ty.opaque o
                (Benitoite.Release.Refinement.RangeIx.fixed Benitoite.Release.Refinement.RangeExpr.top)) →
            B.isResource o = Bool.true → ∃ r, B.releaseResponse v r) →
        Benitoite.Release.Refinement.Builtins.CoreAssumptions P B
```

## Benitoite.Release.Refinement.ModelScopeConditions.effect_ops

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 20。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName) (b : Benitoite.Release.PrimName),
      B.effects l = Option.some bs →
        b ∈ bs →
          ∃ s,
            B.sig b = Option.some s ∧
              (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                  s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                s.opEff = Option.some l
```

## Benitoite.Release.Refinement.ModelScopeConditions.io_op

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 16。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.ModelScopeConditions P B →
    ∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
      B.sig b = Option.some s →
        s.kind = Benitoite.Release.Refinement.PrimKind.io ∨ s.kind = Benitoite.Release.Refinement.PrimKind.exit →
          B.ShapeOk b s
```

## Benitoite.Release.Refinement.ModelScopeConditions.mk

所在: `formal/Benitoite/Release/Refinement/TargetModelConditions.lean`、行: 5。

```lean
∀ {P : Benitoite.Release.Refinement.Program} {B : Benitoite.Release.Refinement.Builtins},
  Benitoite.Release.Refinement.Builtins.SubstitutionAssumptions P B →
    Benitoite.Release.Refinement.Builtins.ResponseAssumptions P B →
      Benitoite.Release.Refinement.Builtins.TargetAgreement P B →
        (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
            B.sig b = Option.some s → Benitoite.Release.Refinement.PrimSig.Scoped P s) →
          (∀ (t : Benitoite.Release.Refinement.Ty), Benitoite.Release.Refinement.Ty.WF 0 0 0 t → B.sat [] t.norm { }) →
            (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
                (C : Benitoite.Release.Refinement.TypeCtx) (ts : List Benitoite.Release.Refinement.Ty),
                B.sig b = Option.some s →
                  s.admits C.constraints (Benitoite.Release.Refinement.Ty.normTys ts) →
                    Benitoite.Release.Refinement.SatAll B C ts
                      (List.map Benitoite.Release.Refinement.TParamDecl.constraints s.tparams)) →
              (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
                  B.sig b = Option.some s →
                    s.kind = Benitoite.Release.Refinement.PrimKind.pathBases → s.PathBasesShape B b) →
                (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
                    B.sig b = Option.some s →
                      s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                          s.kind = Benitoite.Release.Refinement.PrimKind.exit →
                        B.ShapeOk b s) →
                  (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
                      (l : Benitoite.Release.EffName),
                      B.sig b = Option.some s →
                        s.opEff = Option.some l →
                          s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                            s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                              s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) →
                    (∀ (l : Benitoite.Release.EffName) (bs : List Benitoite.Release.PrimName)
                        (b : Benitoite.Release.PrimName),
                        B.effects l = Option.some bs →
                          b ∈ bs →
                            ∃ s,
                              B.sig b = Option.some s ∧
                                (s.kind = Benitoite.Release.Refinement.PrimKind.io ∨
                                    s.kind = Benitoite.Release.Refinement.PrimKind.exit ∨
                                      s.kind = Benitoite.Release.Refinement.PrimKind.pathBases) ∧
                                  s.opEff = Option.some l) →
                      B.effects Benitoite.Release.stateEff = Option.some [] →
                        (∃ s, B.sig B.refGet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refGet) →
                          (∃ s,
                              B.sig B.refSet = Option.some s ∧ s.kind = Benitoite.Release.Refinement.PrimKind.refSet) →
                            (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig),
                                B.sig b = Option.some s →
                                  s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases → s.StoreShape) →
                              (∀ (b : Benitoite.Release.PrimName) (s : Benitoite.Release.Refinement.PrimSig)
                                  (C : List Benitoite.Release.TParam) (ts : List Benitoite.Release.Refinement.Ty),
                                  B.sig b = Option.some s →
                                    s.kind ≠ Benitoite.Release.Refinement.PrimKind.pure →
                                      s.kind ≠ Benitoite.Release.Refinement.PrimKind.io →
                                        s.kind ≠ Benitoite.Release.Refinement.PrimKind.exit →
                                          s.kind ≠ Benitoite.Release.Refinement.PrimKind.pathBases →
                                            ts.length = s.tparams.length → s.admits C ts) →
                                Benitoite.Release.Refinement.ModelScopeConditions P B
```

