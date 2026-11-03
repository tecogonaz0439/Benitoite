# 群F・Gの完全署名

群A〜Eと案(ii)checkedAtの固定署名を維持する。数学の係数はInt、IEEEの共通補題の幅はNat引数である。以下は本番の宣言から抽出した完全署名で、本体の証明を省く。各節の冒頭に名前空間を付す。

Pred.closedTrueはClosedEvaluation、Pred.interpret_conjunctsはConjunctionMeaningへ同じ完全名・型で移した。Certificateは下層のCertificateDataへ移し、refute一構成子とsubstituteのmodeを加えた。旧6場合の保存はLegacy.success_preservedで示す。PreparedLeafの旧checkと全閉じた入口、EqProof9構成子、Entails.bindの公開の型は保つ。

## BuiltinFacts

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Pred.closedTrue_sound_at {p : Pred} (h : p.closedTrue = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem measure_nonnegative_at (m : Measure) (t : Term)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.le (.integer 0) (.measure m t))).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem observeAs_sort (η : ObservationEnvModel) (s : «Sort») (t : Term) :
    (observeAs η s t).sort = s
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem boolean_apart_at (t : Term) (b : Bool)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.not (.and (.compare .boolean .eq t (.boolean b))
      (.compare .boolean .eq t (.boolean (!b)))))).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem characterCode_projection (t : Term) (η : ObservationEnvModel) :
    integerAs η (.measure .characterCode t) =
      match observeAs η .character t with | .character c => (c.toNat : Int) | _ => 0
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem characters_subset_at (t : Term) (lo hi lo' hi' : Char)
    (hl : lo'.toNat ≤ lo.toNat) (hh : hi.toNat ≤ hi'.toNat)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.charactersIn t lo hi)).interpret η = true →
      (predBind ν (.charactersIn t lo' hi')).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem constructor_apart_at (t : Term) (c d : ConName) (hd : c ≠ d)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.not (.and (.constructorIs t c) (.constructorIs t d)))).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem character_code_range_at (t : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    let n
```

## ScalarLogic

名前空間: `Benitoite.Release.Refinement`

```lean
private theorem zero_mod_iff {x m : Nat} (hm : 0 < m) (hx : x < 2*m) :
    x % m = 0 ↔ x = 0 ∨ x = m
```

名前空間: `Benitoite.Release.Refinement`

```lean
def ieeeRank (fraction exponent x : Nat) : Int
```

名前空間: `Benitoite.Release.Refinement`

```lean
private theorem ieeeRank_compare {f e x y : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e))
    (hnx : ieeeNaN f e x = false) (hny : ieeeNaN f e y = false) (o : Comparison) :
    ieeeCompare f e x y o = o.fromEqLt
      (decide (ieeeRank f e x = ieeeRank f e y))
      (decide (ieeeRank f e x < ieeeRank f e y))
      (decide (ieeeRank f e y < ieeeRank f e x))
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieeeCompare_rank {f e x y : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (o : Comparison) :
    ieeeCompare f e x y o =
      if ieeeNaN f e x || ieeeNaN f e y then o == .ne else
        o.fromEqLt (decide (ieeeRank f e x = ieeeRank f e y))
          (decide (ieeeRank f e x < ieeeRank f e y))
          (decide (ieeeRank f e y < ieeeRank f e x))
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem cross_le_trans {x y z a b c : Int}
    (ha : 0 < a) (hb : 0 < b) (hc : 0 < c)
    (hxy : x*b ≤ y*a) (hyz : y*c ≤ z*b) : x*c ≤ z*a
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem cross_lt_le_trans {x y z a b c : Int}
    (ha : 0 < a) (hb : 0 < b) (hc : 0 < c)
    (hxy : x*b < y*a) (hyz : y*c ≤ z*b) : x*c < z*a
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem cross_le_lt_trans {x y z a b c : Int}
    (ha : 0 < a) (hb : 0 < b) (hc : 0 < c)
    (hxy : x*b ≤ y*a) (hyz : y*c < z*b) : x*c < z*a
```

名前空間: `Benitoite.Release.Refinement`

```lean
inductive ScalarRule where
  | eqSymm | eqTrans | ltTrans | leTrans | ltLe | leLt
  deriving DecidableEq
```

名前空間: `Benitoite.Release.Refinement`

```lean
def ScalarRule.test {α : Type} (cmp : Comparison → α → α → Bool)
    (a b c : α) : ScalarRule → Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
private theorem int_order_test (a b c : Int) (r : ScalarRule) :
    r.test (fun o x y => o.fromEqLt (decide (x=y)) (decide (x<y)) (decide (y<x)))
      a b c = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieee_order_test {f e x y z : Nat}
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (hz : z < 2 * 2^(f+e))
    (r : ScalarRule) : r.test (fun o a b => ieeeCompare f e a b o) x y z = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
private def decimalCompare (o : Comparison) (a b : Int × Nat) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem decimal_order_test (a b c : Int × Nat) (r : ScalarRule) :
    r.test decimalCompare a b c = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
def orderedScalarSorts : List «Sort»
```

名前空間: `Benitoite.Release.Refinement`

```lean
def equalityScalarSorts : List «Sort»
```

名前空間: `Benitoite.Release.Refinement`

```lean
def scalarSorts : List «Sort»
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem observation_order_test {s : «Sort»} (hs : s ∈ orderedScalarSorts)
    (a b c : Observation) (ha : a.sort = s) (hb : b.sort = s) (hc : c.sort = s)
    (r : ScalarRule) : r.test (fun o x y => x.compare o y) a b c = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem observation_equality_test {s : «Sort»} (hs : s ∈ equalityScalarSorts)
    (a b c : Observation) (ha : a.sort = s) (hb : b.sort = s) (hc : c.sort = s)
    (r : ScalarRule) (hr : r = .eqSymm ∨ r = .eqTrans) :
    r.test (fun o x y => x.compare o y) a b c = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem observation_eq_ne {s : «Sort»} (hs : s ∈ scalarSorts)
    (a b : Observation) (ha : a.sort = s) (hb : b.sort = s) :
    a.compare .ne b = !(a.compare .eq b)
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieee_finite_parts (f e x : Nat) :
    ieeeClass f e x .finite = decide (x % 2^(f+e) < (2^e-1)*2^f)
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieee_nan_parts (f e x : Nat) :
    ieeeNaN f e x = decide ((2^e-1)*2^f < x % 2^(f+e))
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieee_class_parts (f e x : Nat) (c : FloatClass) :
    ieeeClass f e x c = match c with
    | .finite => decide (x % 2^(f+e) < (2^e-1)*2^f)
    | .nan => decide ((2^e-1)*2^f < x % 2^(f+e))
    | .positiveInfinity => !(x / 2^(f+e) != 0) && decide (x % 2^(f+e) = (2^e-1)*2^f)
    | .negativeInfinity => (x / 2^(f+e) != 0) && decide (x % 2^(f+e) = (2^e-1)*2^f)
    | .positiveZero => !(x / 2^(f+e) != 0) && decide (x % 2^(f+e) = 0)
    | .negativeZero => (x / 2^(f+e) != 0) && decide (x % 2^(f+e) = 0)
```

名前空間: `Benitoite.Release.Refinement`

```lean
def ieeePartition (f e x : Nat) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
def ieeeClassTest (f e x y : Nat) (c : FloatClass) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieee_partition (f e x : Nat) : ieeePartition f e x = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem ieee_class_test {f e x y : Nat} (he : 0 < e)
    (hx : x < 2 * 2^(f+e)) (hy : y < 2 * 2^(f+e)) (c : FloatClass) :
    ieeeClassTest f e x y c = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem observation_order_complement {s : «Sort»} (hs : s = .character ∨ s = .decimal)
    (a b : Observation) (ha : a.sort = s) (hb : b.sort = s) :
    a.compare .ge b = !(a.compare .lt b) ∧ a.compare .gt b = !(a.compare .le b)
```

## BuiltinSchema

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def implies (p q : Pred) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def scalarOrder (s : «Sort») (r : ScalarRule) (a b c : Term) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def scalarRules : List ScalarRule
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def equalityRules : List ScalarRule
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def measures : List Measure
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def sorts : List «Sort»
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def classes : List FloatClass
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def comparisons : List Comparison
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def observationAtom (s : «Sort») (t : Term) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def comparisonInteger (o : Comparison) (a b : Term) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def characterCompare (o : Comparison) (a b : Term) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def floatSort : FloatWidth → «Sort»
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def floatZero (w : FloatWidth) (negative : Bool) : Term
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def floatPartition (w : FloatWidth) (a : Term) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def floatClass (w : FloatWidth) (c : FloatClass) (a b : Term) : Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
def candidates (lemma : BuiltinLemma) (arguments : List Term) : List Pred
```

## BuiltinLogic

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem scalarOrder_sound_at {s : «Sort»} (hs : s ∈ scalarSorts)
    (r : ScalarRule) (hr : s ∈ orderedScalarSorts ∨ r ∈ equalityRules)
    (a b c : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (scalarOrder s r a b c)).interpret η = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem characterCompare_sound_at (o : Comparison) (a b : Term)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (characterCompare o a b)).interpret η = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem floatClass_sound_at (w : FloatWidth) (c : FloatClass) (a b : Term)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (floatClass w c a b)).interpret η = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem implies_sound_at {p q : Pred} (ν : ObservationEnv) (η : ObservationEnvModel)
    (h : (predBind ν p).interpret η = true → (predBind ν q).interpret η = true) :
    (predBind ν (implies p q)).interpret η = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem eqComplement_sound_at {s : «Sort»} (hs : s ∈ scalarSorts)
    (a b : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.compare s .ne a b)).interpret η =
      (predBind ν (.not (.compare s .eq a b))).interpret η
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem orderComplement_sound_at {s : «Sort»} (hs : s = .character ∨ s = .decimal)
    (a b : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.compare s .ge a b)).interpret η =
      (predBind ν (.not (.compare s .lt a b))).interpret η ∧
    (predBind ν (.compare s .gt a b)).interpret η =
      (predBind ν (.not (.compare s .le a b))).interpret η
```

名前空間: `Benitoite.Release.Refinement.BuiltinSchema`

```lean
theorem candidates_sound_at {lemma args p} (hp : p ∈ candidates lemma args)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
def PreparedLeaf.checkRaw (Φ : List Pred) (l : PreparedLeaf) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem PreparedLeaf.raw_sound_at {Φ : List Pred} {l : PreparedLeaf}
    (h : PreparedLeaf.checkRaw Φ l = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
    (predBind ν l.predicate).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
def PreparedLeaf.check (l : PreparedLeaf) : Bool
```

## BuiltinLogicExamples

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
private def scalarEndpoints : List («Sort» × Term × Term)
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
def closedComparisons : List (Pred × Bool)
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
def closedComparisonBoundaries : List (Pred × Bool)
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
def closedClasses : List Pred
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
theorem comparisons_30 : closedComparisons.length = 30 ∧
    closedComparisons.all (fun (p,b) => p.evalClosed == some b) = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
theorem comparison_boundaries_48 : closedComparisonBoundaries.length = 48 ∧
    closedComparisonBoundaries.all (fun (p,b) => p.evalClosed == some b) = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
theorem classes_12 : closedClasses.length = 12 ∧
    closedClasses.all (fun p => p.evalClosed == some true) = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
def samples : List (List Pred × PreparedLeaf)
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
theorem registered_samples : samples.length = 12 ∧
    samples.all (fun (Φ,l) => l.checkRaw Φ) = true ∧
    samples.all (fun (Φ,l) => !(PreparedLeaf.checkRaw Φ {l with predicate
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
def alteredLeaves : List (List Pred × PreparedLeaf)
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
theorem altered_leaves_rejected : alteredLeaves.length = 6 ∧
    alteredLeaves.all (fun (Φ,l) => !(l.checkRaw Φ)) = true
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
def registry : List (List PreparedLeaf)
```

名前空間: `Benitoite.Release.Refinement.BuiltinLogicExamples`

```lean
theorem registry_100 : registry.map List.length = [1,1,7,2,22,1,1,16,30,1,6,12] ∧
    registry.flatten.length = 100 ∧ registry.flatten.all (PreparedLeaf.checkRaw []) = true
```

## CertificateData

名前空間: `Benitoite.Release.Refinement`

```lean
inductive Certificate where
  | use (index : Nat)
  | leaf (value : PreparedLeaf)
  | substitute (predicate : Pred) (left right : Term) (eq : EqProof)
      (proof : Certificate) (mode : EqualityMode)
  | consume (next : Certificate)
  | cases (left right : Certificate)
  | discard (next : Certificate)
  | refute (proof : Refutation)
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Term.linearKeys : Term → KeyTable
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Pred.linearKeys : Pred → KeyTable
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Refutation.keys : Refutation → KeyTable
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.extraKeys : Certificate → KeyTable
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.keys (premise goal : Pred) (c : Certificate) : KeyTable
```

## ConjunctionMeaning

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Pred.interpret_conjuncts (p : Pred) (η : ObservationEnvModel) :
    p.interpret η = true ↔ ∀ q ∈ p.conjuncts, q.interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Pred.interpret_conjuncts_at (p : Pred) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true ↔ ∀ q ∈ p.conjuncts, (predBind ν q).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Pred.interpret_ofConjuncts_at (ps : List Pred) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (Pred.ofConjuncts ps)).interpret η = true ↔
      ∀ p ∈ ps, (predBind ν p).interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Pred.conjuncts_ofConjuncts_flat (ps : List Pred) :
    (Pred.ofConjuncts ps).conjuncts = ps.flatMap Pred.conjuncts
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Pred.conjuncts_flat_idem (ps : List Pred) :
    (ps.flatMap Pred.conjuncts).flatMap Pred.conjuncts = ps.flatMap Pred.conjuncts
```

## CertificateKernel

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.check (Φ : List Pred) (goal : Pred) : Certificate → Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Certificate.sound_at {Φ : List Pred} {goal : Pred} {c : Certificate}
    (h : c.check Φ goal = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
    (predBind ν goal).interpret η = true
```

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
def check (premise goal : Pred) (c : Certificate) : Bool
```

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
theorem implication_sound_at {p q : Pred} {c : Certificate} (h : check p q c = true) :
    ∀ (ν : ObservationEnv) (η : ObservationEnvModel),
      (predBind ν p).interpret η = true → (predBind ν q).interpret η = true
```

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
theorem implication_sound {p q : Pred} {c : Certificate} (h : check p q c = true) :
    ∀ η : ObservationEnvModel, p.interpret η = true → q.interpret η = true
```

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
theorem check_sound {premise goal : Pred} {c : Certificate} (h : check premise goal c = true) :
    ∀ η : ObservationEnvModel, (Pred.and premise (.not goal)).interpret η ≠ true
```

## CertificateEntails

名前空間: `Benitoite.Release.Refinement`

```lean
private theorem premise_entails (Φ : List Pred) : Entails Φ (Pred.ofConjuncts Φ)
```

名前空間: `Benitoite.Release.Refinement`

```lean
private theorem substitute_atomic {Φ : List Pred} {p : Pred} {t u : Term} {eq : EqProof}
    {mode : EqualityMode} (ha : (p.open t).conjuncts = [p.open t])
    (he : eq.checkRaw Φ mode t u = true) (hr : rewritePosition p mode = true)
    (source : Entails Φ (p.open t)) : Entails Φ (p.open u)
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem EqProof.substitute_entails {Φ : List Pred} {p : Pred} {t u : Term} {eq : EqProof}
    {mode : EqualityMode} (he : eq.checkRaw Φ mode t u = true)
    (hr : rewritePosition p mode = true) (source : Entails Φ (p.open t)) :
    Entails Φ (p.open u)
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem PreparedLeaf.raw_entails {Φ : List Pred} {l : PreparedLeaf}
    (h : l.checkRaw Φ = true) : Entails Φ l.predicate
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Certificate.refutation_entails {Φ : List Pred} {goal : Pred} {c : Certificate}
    (h : CertificateKernel.check (Pred.ofConjuncts Φ) goal c = true) : Entails Φ goal
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Certificate.sound {Φ : List Pred} {goal : Pred} {c : Certificate}
    (h : c.check Φ goal = true) : Entails Φ goal
```

## CertificateLegacy

名前空間: `Benitoite.Release.Refinement`

```lean
inductive Certificate.Legacy where
  | use (index : Nat)
  | leaf (value : PreparedLeaf)
  | substitute (predicate : Pred) (left right : Term) (eq : EqProof) (proof : Certificate.Legacy)
  | consume (next : Certificate.Legacy)
  | cases (left right : Certificate.Legacy)
  | discard (next : Certificate.Legacy)
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.Legacy.check (Φ : List Pred) (goal : Pred) : Certificate.Legacy → Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.Legacy.embed : Certificate.Legacy → Certificate
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem PreparedLeaf.raw_of_check {l : PreparedLeaf} (h : l.check = true) (Φ : List Pred) :
    l.checkRaw Φ = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Certificate.Legacy.success_preserved {c : Certificate.Legacy} {Φ : List Pred} {goal : Pred}
    (h : c.check Φ goal = true) : c.embed.check Φ goal = true
```

## EqProofTransport

名前空間: `Benitoite.Release.Refinement`

```lean
theorem EqProof.recontextualize {Φ Δ : List Pred} {mode : EqualityMode} {t u : Term} {c : EqProof}
    (h : c.checkRaw Φ mode t u = true)
    (hm : ∀ a b, Pred.eq a b ∈ Φ → Pred.eq a b ∈ Δ) :
    ∃ d : EqProof, d.checkRaw Δ mode t u = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem EqProof.structural_check_context (Φ Δ : List Pred) (t u : Term) (c : EqProof) :
    c.checkRaw Φ .structural t u = c.checkRaw Δ .structural t u
```

## CertificateKernelExamples

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def premise : Pred
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def goal : Pred
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def twice : Certificate
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem twice_checked : CertificateKernel.check premise goal twice = true
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem twice_entails : Entails [premise] goal
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem twice_entails_at (ν : ObservationEnv) :
    Entails [predBind ν premise] (predBind ν goal)
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def images : List ObservationEnv
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def badTwice : Certificate
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem bad_twice_rejected : CertificateKernel.check premise goal badTwice = false
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def nonnegative : PreparedLeaf
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def negativeLength : Certificate
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem negative_length_checked : CertificateKernel.check
    (.lt (.measure .listLength (.var 0)) (.integer 0)) .falsity negativeLength = true
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def booleanApart : Pred
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def booleanLeaf : Certificate
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def source : Pred
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def target : Pred
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def replacing : Certificate
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
def legacySix : Certificate.Legacy
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
private def P : Program
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
private theorem valid : P.VarianceValid
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
private def Γ : Ctx
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem typed_twice : twice.checkIn P [] Γ [premise] goal = true
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
private theorem implication_elim {Φ : List Pred} {p q : Pred}
    (hi : Entails Φ (BuiltinSchema.implies p q)) (hp : Entails Φ p) : Entails Φ q
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
private theorem float_clause (w : FloatWidth) (c : FloatClass) (a b : Term) (Φ : List Pred) :
    Entails Φ (BuiltinSchema.floatClass w c a b)
```

名前空間: `Benitoite.Release.Refinement.CertificateKernelExamples`

```lean
theorem float_between (w : FloatWidth) (a lo hi : Term) :
    Entails [.floatClass w .finite lo, .floatClass w .finite hi,
      .compare (BuiltinSchema.floatSort w) .ge a lo,
      .compare (BuiltinSchema.floatSort w) .le a hi] (.floatClass w .finite a)
```

## Certificate

名前空間: `Benitoite.Release.Refinement`

```lean
theorem PreparedLeaf.entails {l : PreparedLeaf} (h : l.check = true) : Entails Φ l.predicate
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem PreparedLeaf.machine_exact {l : PreparedLeaf} (h : l.check = true) (η : ObservationEnvModel) :
    l.predicate.interpret η = true
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem PreparedLeaf.stable {l : PreparedLeaf} (h : l.check = true) (ν : ObservationEnv) :
    predBind ν l.predicate = l.predicate
```

名前空間: `Benitoite.Release.Refinement`

```lean
def EqProof.checkSorted (Γ : Ctx) (s : «Sort») (t u : Term) (c : EqProof) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem EqProof.checkSorted_sound {Γ s t u c} (h : EqProof.checkSorted Γ s t u c = true) :
    t.HasSort Γ s ∧ u.HasSort Γ s ∧ t = u
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.checkSorted (Γ : Ctx) (Φ : List Pred) (goal : Pred) (c : Certificate) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Certificate.checkSorted_sound {Γ Φ goal c} (h : Certificate.checkSorted Γ Φ goal c = true) :
    goal.Sorted Γ none ∧ (∀ p ∈ Φ, p.Sorted Γ none) ∧ Entails Φ goal
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Refutation.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx) : Refutation → Prop
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (goal : Pred) : Certificate → Prop
```

名前空間: `Benitoite.Release.Refinement`

```lean
def Certificate.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (goal : Pred) (c : Certificate) : Bool
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Certificate.checkIn_sound {P C Γ Φ goal c}
    (h : Certificate.checkIn P C Γ Φ goal c = true) :
    KeyTable.checkIn P C Γ (c.keys (Pred.ofConjuncts Φ) goal) = true ∧
      goal.Sorted Γ none ∧ goal.Declared P C Γ none ∧
      (∀ p ∈ Φ, p.Sorted Γ none ∧ p.Declared P C Γ none) ∧
      c.AdmissibleIn P C Γ Φ goal ∧ Entails Φ goal
```

## ClosedEvaluation

名前空間: `Benitoite.Release.Refinement`

```lean
def Pred.closedTrue (p : Pred) : Bool
```

## RefutationSyntax

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
def refute (keys : KeyTable) (todo facts : List NNF) : Refutation → Bool
```

## RefutationSound

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
theorem builtin_sound_at {keys todo facts} {l : PreparedLeaf}
    {next : List NNF → List NNF → Bool}
    (h : (l.checkRaw (facts.map (NNF.toPred keys)) &&
      match normalize keys l.predicate false with
      | some q => next (q::todo) facts | none => false) = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η
```

名前空間: `Benitoite.Release.Refinement.CertificateKernel`

```lean
theorem refute_sound_at {keys : KeyTable} {todo facts : List NNF} {c : Refutation}
    (h : refute keys todo facts c = true) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (∀ q ∈ todo ++ facts, (predBind ν (q.toPred keys)).interpret η = true) → False
```

## Logic

名前空間: `Benitoite.Release.Refinement`

```lean
inductive Entails : List Pred → Pred → Prop where
  | hyp {Ξ p} : p ∈ Ξ → Entails Ξ p
  | truth {Ξ} : Entails Ξ .truth
  | false_elim {Ξ p} : Entails Ξ .falsity → Entails Ξ p
  | and_intro {Ξ p q} : Entails Ξ p → Entails Ξ q → Entails Ξ (.and p q)
  | and_left {Ξ p q} : Entails Ξ (.and p q) → Entails Ξ p
  | and_right {Ξ p q} : Entails Ξ (.and p q) → Entails Ξ q
  | or_left {Ξ p q} : Entails Ξ p → Entails Ξ (.or p q)
  | or_right {Ξ p q} : Entails Ξ q → Entails Ξ (.or p q)
  | or_elim {Ξ p q r} : Entails Ξ (.or p q) → Entails (p::Ξ) r →
      Entails (q::Ξ) r → Entails Ξ r
  | not_intro {Ξ p} : Entails (p::Ξ) .falsity → Entails Ξ (.not p)
  | not_elim {Ξ p} : Entails Ξ p → Entails Ξ (.not p) → Entails Ξ .falsity
  | not_not_elim {Ξ p} : Entails Ξ (.not (.not p)) → Entails Ξ p
  | eq_refl {Ξ t} : Entails Ξ (.eq t t)
  | le_refl {Ξ t} : Entails Ξ (.le t t)
  | integer_eq {Ξ n m} : n = m → Entails Ξ (.eq (.integer n) (.integer m))
  | integer_le {Ξ n m} : n ≤ m → Entails Ξ (.le (.integer n) (.integer m))
  | integer_lt {Ξ n m} : n < m → Entails Ξ (.lt (.integer n) (.integer m))
  | closed {Ξ p} : p.WF 0 → p.Sorted [] none → p.evalClosed = some true → Entails Ξ p
  | checkedAt {Ξ p q c} (ν : ObservationEnv) :
      CertificateKernel.check p q c = true → Entails Ξ (predBind ν p) → Entails Ξ (predBind ν q)
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Entails.checked {Ξ p q c} (hc : CertificateKernel.check p q c = true)
    (hp : Entails Ξ p) : Entails Ξ q
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Entails.weaken {Ξ p} (h : Entails Ξ p) {Δ} (hm : ∀ q ∈ Ξ, q ∈ Δ) :
    Entails Δ p
```

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Entails.cut {Ξ p} (h : Entails Ξ p) {Δ} (hm : ∀ q ∈ Ξ, Entails Δ q) :
    Entails Δ p
```

## LogicSound

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Entails.sound {Φ : List Pred} {p : Pred} (h : Entails Φ p) :
    ∀ η : ObservationEnvModel, (∀ q ∈ Φ, q.interpret η = true) → p.interpret η = true
```

## Basic

名前空間: `Benitoite.Release.Refinement`

```lean
theorem Entails.bind {Ξ p} (h : Entails Ξ p) (σ : ObservationEnv) :
    Entails (Ξ.map (predBind σ)) (predBind σ p)
```
