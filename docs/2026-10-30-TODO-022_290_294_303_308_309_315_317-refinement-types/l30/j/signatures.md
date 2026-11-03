# 群 J・K の完全署名

名前空間は `Benitoite.Release.Refinement`。NumericContracts、NormalResultLeaves と適用例はファイル名と同名の下位名前空間である。群 A〜I の署名・構成子は不変である。公開の S05 四入口は固定した署名をそのまま実装した。再開1でbyte_representedをbyte_and_u16_representedへ改名し、AllKeysCheckedのrefuteの条件を実際の平坦化した仮定の鍵列に強めた。S05四入口の署名は不変である。以下は本番から抽出した署名である。有限構造の構成子は省略しない。

数学の整数は Int、七整数の幅は既存 IntKind、Float の二幅は既存の bits を読む。保存幅128やstepsの値を固定する新しい前提はない。

## MeasureContracts

```lean
theorem measure_machine_exact {m : Measure} {o : Observation} {n : Int}
    (h : Observation.measure m o = some (.integer n))
    (η : ObservationEnvModel) (t : Term) (ht : t.observe η = some o) :
    (Term.measure m t).observe η = some (.integer n) ∧
    (Term.measure m t).interpret η = some (.integer n) ∧ 0 ≤ n

theorem measure_stable {m : Measure} {t : Term} {n : Int}
    (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (h : (Term.measure m t).observe η = some (.integer n)) :
    (Term.measure m (termBind ν t)).observe ξ = some (.integer n)

theorem Observation.measure_exact :
    (∀ s : String, Observation.measure .stringBytes (.string s) =
      some (.integer s.utf8ByteSize)) ∧
    (∀ s : String, Observation.measure .stringCharacters (.string s) =
      some (.integer s.toList.length)) ∧
    (∀ xs, Observation.measure .listLength (.listValue xs) =
      some (.integer xs.length)) ∧
    (∀ xs : List Nat, xs.all (· ≤ 255) = true →
      Observation.measure .bytesLength (.bytesValue xs) = some (.integer xs.length)) ∧
    (∀ ks vs entries, mapKeys ks vs = some entries →
      Observation.measure .mapSize (.mapValue ks vs) = some (.integer entries.length)) ∧
    (∀ xs codes, keySetCodes xs [] = some codes →
      Observation.measure .setSize (.setValue xs) = some (.integer codes.length)) ∧
    (∀ c : Char, Observation.measure .characterCode (.character c) =
      some (.integer c.toNat))

theorem observeSlots_length (η : ObservationEnvModel) (xs : List (Option Term)) :
    (observeSlots η xs).length = xs.length

theorem field_measure_stable {r : FieldRef} {t : Term} {o : Observation}
    {m : Measure} {n : Int} (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ)))
    (field : (Term.field r t).observe η = some o)
    (normal : Observation.measure m o = some (.integer n)) :
    Observation.OptionInfoLE (some o) ((Term.field r (termBind ν t)).observe ξ) ∧
      (Term.measure m (Term.field r (termBind ν t))).observe ξ = some (.integer n)
```

## NumericContracts

```lean
theorem integer_result (k : IntKind) (v : IntegerValue k) :
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? =
      some (.integer v.toInt)

theorem binary_normal (k : IntKind) (op : WidthBinary)
    (a b v : IntegerValue k) (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) :
    (v.toInt = match op with
      | .add => a.toInt + b.toInt
      | .sub => a.toInt - b.toInt
      | _ => a.toInt * b.toInt) ∧
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? =
      some (.integer v.toInt)

theorem neg_normal (k : IntKind) (signed : k.min < 0) (a v : IntegerValue k)
    (normal : k.checkedNeg signed a = .normal (.ofInteger k v)) :
    v.toInt = -a.toInt ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? =
      some (.integer v.toInt)

theorem rejected_not_normal {r : OperationResult} {why : Failure}
    (rejected : r = .rejected why) (v : ConcreteValue) : r ≠ .normal v

theorem byte_and_u16_represented (n : Nat) (h : n ≤ 255) :
    (Const.byte n).NumericRepresented ∧
    (Val.const (.byte n)).toTerm? = some (.integer n) ∧
    (Const.unsignedInteger16 n).NumericRepresented

theorem compare_exact {s : «Sort»} {t u : Term} {a b : Observation}
    (η : ObservationEnvModel) (ht : t.observe η = some a) (hu : u.observe η = some b)
    (ha : a.sort = s) (hb : b.sort = s) (op : Comparison) :
    (Pred.compare s op t u).interpret η = a.compare op b

theorem float_class_exact (η : ObservationEnvModel) (t : Term) (c : FloatClass) :
    (∀ b : UInt32, t.observe η = some (.float32 b) →
      (Pred.floatClass .binary32 c t).interpret η = ieeeClass 23 8 b.toNat c) ∧
    (∀ b : UInt64, t.observe η = some (.float64 b) →
      (Pred.floatClass .binary64 c t).interpret η = ieeeClass 52 11 b.toNat c)

theorem decimal_result {B : Builtins} {c : Int} {scale : Nat}
    (ok : ConstOK B (.decimal c scale)) (η : ObservationEnvModel) :
    (Const.decimal c scale).NumericRepresented ∧
    (Val.const (.decimal c scale)).toTerm? = some (.decimal c scale) ∧
    (Term.decimal c scale).observe η = some (.decimal c scale) ∧
    ∀ p ∈ (Const.decimal c scale).type.carrierFacts,
      p.interpret (selfModel η (.const (.decimal c scale))) = true
```

## KeyContracts

```lean
inductive Observation.KeyShape : Observation → Prop where
    | integer (n) : KeyShape (.integer n)
    | character (c) : KeyShape (.character c)
    | decimal (c s) : KeyShape (.decimal c s)
    | boolean (b) : KeyShape (.boolean b)
    | unit : KeyShape .unitValue
    | string (s) : KeyShape (.string s)
    | bytes {xs} : xs.all (· ≤ 255) = true → KeyShape (.bytesValue xs)
    | list {xs} : Observation.KeySlots xs → KeyShape (.listValue xs)
    | map {ks vs} : Observation.KeyPairs ks vs → KeyShape (.mapValue ks vs)
    | set {xs} : Observation.KeySlots xs → KeyShape (.setValue xs)
    | data {c xs} : Observation.KeySlots xs → KeyShape (.dataValue c xs)

inductive Observation.KeySlots : List (Option Observation) → Prop where
    | nil : KeySlots []
    | cons {o xs} : o.KeyShape → KeySlots xs → KeySlots (some o :: xs)

inductive Observation.KeyPairs : List (Option Observation) → List (Option Observation) → Prop where
    | nil : KeyPairs [] []
    | cons {k v ks vs} : k.KeyShape → v.KeyShape → KeyPairs ks vs →
        KeyPairs (some k :: ks) (some v :: vs)


mutual

theorem Observation.KeyShape.code {o : Observation} (h : o.KeyShape) :
      ∃ c, o.keyCode? = some c

theorem Observation.KeySlots.codes {xs} (h : Observation.KeySlots xs) :
      ∃ cs, keySlotCodes xs = some cs

theorem Observation.KeySlots.setCodes {xs} (h : Observation.KeySlots xs) (acc : List (List Nat)) :
      ∃ cs, keySetCodes xs acc = some cs

theorem Observation.KeyPairs.mapCodes {ks vs} (h : Observation.KeyPairs ks vs)
      (acc : List (List Nat × List Nat)) : ∃ cs, keyMapCodes ks vs acc = some cs

theorem Observation.key_unsupported (x : UInt64) (y : UInt32)
    (bs : Option PathEnv) (t : Scope.Domain.Target) :
    (Observation.float64 x).keyCode? = none ∧
    (Observation.float32 y).keyCode? = none ∧
    (Observation.targetValue bs t).keyCode? = none

theorem Observation.KeySlots.mapKeys {ks} (h : Observation.KeySlots ks)
    (vs : List (Option Observation)) (lengths : ks.length = vs.length)
    (acc : List (List Nat × Option Observation)) :
    ∃ entries, mapKeys.go ks vs acc = some entries

theorem Key.code_of_shape {t : Term} {o : Observation} (closed : t.Closed)
    (η : ObservationEnvModel) (observed : t.observe η = some o) (shape : o.KeyShape) :
    ∃ c, Key.code? t = some c ∧ o.keyCode? = some c

theorem Key.equal_of_shapes {a b : Term} {x y : Observation}
    (ha : a.Closed) (hb : b.Closed) (η : ObservationEnvModel)
    (ax : a.observe η = some x) (by' : b.observe η = some y)
    (hx : x.KeyShape) (hy : y.KeyShape) :
    ∃ c d, x.keyCode? = some c ∧ y.keyCode? = some d ∧
      Key.equal a b = some (decide (c = d))

theorem decimalNormal_value (c : Int) (s : Nat) :
    let p := decimalNormal c s
    p.1 * (10 : Int)^s = c * (10 : Int)^p.2

private theorem decimalNormal_code_injective (c d : Int) (s t : Nat)
    (h : (Observation.decimal c s).keyCode? = (Observation.decimal d t).keyCode?) :
    decimalNormal c s = decimalNormal d t

theorem decimal_key_compare {c d : Int} {s t : Nat}
    (h : (Observation.decimal c s).keyCode? = (Observation.decimal d t).keyCode?) :
    (Observation.decimal c s).compare .eq (.decimal d t) = true

theorem Key.map_measure {ks vs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots ks) (normal : Key.normalizeMap ks vs = some entries) :
    Observation.measure .mapSize (.mapValue (observeSlots η ks) (observeSlots η vs)) =
      some (.integer entries.length)

theorem Key.set_measure {xs entries} (η : ObservationEnvModel)
    (closed : Key.ClosedSlots xs) (normal : Key.normalizeSet xs = some entries) :
    Observation.measure .setSize (.setValue (observeSlots η xs)) = some (.integer entries.length)
```

## PreparedLeaf

```lean
def PreparedLeaf.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (l : PreparedLeaf) : Bool

theorem PreparedLeaf.entailsIn {P : Program} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred} {l : PreparedLeaf} (h : l.checkIn P C Γ Φ = true) :
    Entails (Γ.facts ++ Φ) l.predicate

theorem PreparedLeaf.bind_entails {P : Program} {C : TypeCtx} {Γ : Ctx}
    {Φ : List Pred} {l : PreparedLeaf} (h : l.checkIn P C Γ Φ = true) (ν : ObservationEnv) :
    Entails ((Γ.facts ++ Φ).map (predBind ν)) (predBind ν l.predicate)

theorem checked_refinement {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {p q : Pred} {c : Certificate}
    (hab : Ty.LeQ P Γ Φ a b)
    (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
    (hc : CertificateKernel.check (Pred.ofConjuncts (p :: assumptions Γ Φ a)) q c = true) :
    Ty.LeQ P Γ Φ (.refined a p) (.refined b q)

theorem Val.toTerm_observed {v : Val} {t : Term} {s : «Sort»}
    (ht : v.toTerm? = some t) (hs : t.HasSort [] s) (η : ObservationEnvModel) :
    ∃ o, t.observe η = some o ∧ o.sort = s

theorem HasTypeVQ.observed_measure {P B Ψ Q C Φ v a m o n}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v a) (sort : a.carrier.HasSort m.input)
    (η : ObservationEnvModel)
    (observed : v.toTerm?.bind (Term.observe η) = some o)
    (normal : Observation.measure m o = some (.integer n)) :
    ∃ t, v.toTerm? = some t ∧ t.HasSort [] m.input ∧ t.Closed ∧
      (Term.measure m t).observe η = some (.integer n) ∧
      (Term.measure m t).interpret η = some (.integer n) ∧ 0 ≤ n ∧
      ∀ (ν : ObservationEnv) (ξ : ObservationEnvModel),
        (∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) →
        (Term.measure m (termBind ν t)).observe ξ = some (.integer n)
```

## CertificateKeys

```lean
private theorem ofConjuncts_keys (Φ : List Pred) :
    (Pred.ofConjuncts Φ).linearKeys = Φ.flatMap Pred.linearKeys

private theorem conjuncts_keys (p : Pred) :
    p.conjuncts.flatMap Pred.linearKeys = p.linearKeys

theorem Certificate.refute_keys_same (Φ : List Pred) (goal : Pred) (r : Refutation) :
    (Certificate.refute r).keys (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) goal =
      (Certificate.refute r).keys (Pred.ofConjuncts Φ) goal

def Certificate.AllKeysChecked (P : Program) (C : TypeCtx) (Γ : Ctx)
    (Φ : List Pred) (goal : Pred) (c : Certificate) : Prop

private theorem key_subset {P C Γ keys children}
    (h : KeyTable.checkIn P C Γ keys = true)
    (sub : ∀ t ∈ children, t ∈ keys) : KeyTable.checkIn P C Γ children = true

theorem Certificate.keys_checked_all {P C Γ Φ goal} {c : Certificate}
    (h : KeyTable.checkIn P C Γ (c.keys (Pred.ofConjuncts Φ) goal) = true) :
    c.AllKeysChecked P C Γ Φ goal

theorem Certificate.checkIn_all_keys {P C Γ Φ goal} {c : Certificate}
    (h : Certificate.checkIn P C Γ Φ goal c = true) :
    c.AllKeysChecked P C Γ Φ goal
```

## NormalResultLeaves

```lean
def expression (op : WidthBinary) (a b : Int) : Term

def leaf (op : WidthBinary) (a b n : Int) : PreparedLeaf

theorem binary_leaf {P : Program} (valid : P.VarianceValid) (k : IntKind) (op : WidthBinary)
    (a b v : IntegerValue k) (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) :
    (leaf op a.toInt b.toInt v.toInt).checkIn P [] [] [] = true ∧
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? = some (.integer v.toInt)

theorem binary_entails_at {P : Program} (valid : P.VarianceValid) (k : IntKind) (op : WidthBinary)
    (a b v : IntegerValue k) (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) (ν : ObservationEnv) :
    Entails [] (predBind ν (leaf op a.toInt b.toInt v.toInt).predicate)
```

## ObservationContractsExamples

```lean
private def measures : List (Measure × Observation × Int)

private theorem measure_observations : ∀ row ∈ measures,
    Observation.measure row.1 row.2.1 = some (.integer row.2.2)

theorem measures_machine_exact (η : ObservationEnvModel) (t : Term) :
    ∀ row ∈ measures, t.observe η = some row.2.1 →
      (Term.measure row.1 t).observe η = some (.integer row.2.2) ∧
      (Term.measure row.1 t).interpret η = some (.integer row.2.2) ∧ 0 ≤ row.2.2

private def small (k : IntKind) (n : Nat) (h : n ≤ 6) : IntegerValue k

theorem seven_integer_normal (k : IntKind) :
    (∃ v : IntegerValue k, k.checkedAdd (small k 2 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k v) ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented) ∧
    (∃ v : IntegerValue k, k.checkedSub (small k 5 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k v) ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented) ∧
    (∃ v : IntegerValue k, k.checkedMul (small k 2 (by decide)) (small k 3 (by decide)) =
      .normal (.ofInteger k v) ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented)
```

## PreparedLeafExamples

```lean
def lengthPremise : Pred := .and
  (.eq (.measure .listLength (.var 0)) (.var 1)) (.lt (.integer 0) (.var 1))

def lengthGoal : Pred := .lt (.integer 0) (.measure .listLength (.var 0))

def lengthCertificate : Certificate := .substitute (.lt (.integer 0) (.var 0))
  (.var 1) (.measure .listLength (.var 0)) (.symm (.hyp 0)) (.use 1) .integer

theorem length_checked : CertificateKernel.check lengthPremise lengthGoal lengthCertificate = true

theorem length_positive {Ξ : List Pred} (t n : Term)
    (eq : Entails Ξ (.eq (.measure .listLength t) n))
    (pos : Entails Ξ (.lt (.integer 0) n)) :
    Entails Ξ (.lt (.integer 0) (.measure .listLength t))

theorem nonempty_from_length {P B Ψ Q C Γ Φ T v t n}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v (.list T)) (ht : v.toTerm? = some t)
    (ha : Ty.Annotation P C Γ (.list T))
    (hp : nonemptyPredicate.Sorted Γ (some (.list T)))
    (hd : nonemptyPredicate.Declared P C Γ (some (.list T)))
    (eq : Entails (Γ.facts ++ Φ) (.eq (.measure .listLength t) n))
    (pos : Entails (Γ.facts ++ Φ) (.lt (.integer 0) n)) :
    HasTypeVQ P B Ψ Q C Γ Φ v (nonemptyType T) ∧
      Exhaustive P (nonemptyType T) [headRestPattern]

theorem unrelated_length_rejected : ¬ Entails
    [.eq (.measure .listLength (.var 0)) (.var 1), .lt (.integer 0) (.var 1)]
    (.lt (.integer 0) (.measure .listLength (.var 2)))

private def P : Program

private theorem valid : P.VarianceValid

private def B : Builtins := LegacyPatternExamples.builtins

theorem unit_list_nonempty :
    HasTypeVQ P B StoreTy.empty Qempty [] [] [] (.list [.const .unit])
      (nonemptyType (.base .unit)) ∧
    Exhaustive P (nonemptyType (.base .unit)) [headRestPattern]

def openList : Ty := .list (OpenSubstitution.source OpenSubstitution.inner)

def outerLength : Pred := .eq (.measure .listLength (.var 0)) (.var 1)

def nonnegativeLength : Pred := .le (.integer 0) (.measure .listLength (.var 0))

def lengthLeaf : PreparedLeaf := ⟨nonnegativeLength, .measureNonnegative, [.var 0], []⟩

theorem open_refinement : Ty.LeQ P OpenSubstitution.Γ [OpenSubstitution.path]
    (.refined openList outerLength) (.refined openList nonnegativeLength)

theorem open_refinement_bind : Ty.LeQ P OpenSubstitution.Δ OpenSubstitution.Ψ
    ((Ty.refined openList outerLength).bind OpenSubstitution.θ)
    ((Ty.refined openList nonnegativeLength).bind OpenSubstitution.θ)

theorem open_refinement_meaning {v : Val}
    (source : ValueMeaning P (fun _ => some (.integer 7)) (.refined openList outerLength) v) :
    ValueMeaning P (fun _ => some (.integer 7)) (.refined openList nonnegativeLength) v

def booleanContext : Ctx := [some (.base .boolean)]

def apart : Pred := .not (.and (boolCond (.var 0) true) (boolCond (.var 0) false))

def apartLeaf : PreparedLeaf := ⟨apart,.booleanApart,[.var 0],[]⟩

theorem apart_checked : apartLeaf.checkIn P [] booleanContext [] = true

theorem apart_entails : Entails [] apart

theorem false_side : Entails [boolCond (.var 0) false]
    (.and (boolCond (.var 0) false) (.not (boolCond (.var 0) true)))

theorem false_guard_rejects_true : ¬ Entails [boolCond (.var 0) false] (boolCond (.var 0) true)

private def badArguments : PreparedLeaf

theorem arguments_only_rejected :
    badArguments.predicate = (NormalResultLeaves.leaf .add 2 3 5).predicate ∧
    (Certificate.leaf badArguments).checkIn P [] [] [] badArguments.predicate = true ∧
    badArguments.checkIn P [] [] [] = false
```

## FieldObservationExamples

```lean
private def P : Program

private def inner : FieldRef := ⟨"Outer","Outer.Make",0,.data⟩

private def text : FieldRef := ⟨"Inner","Inner.Make",1,.string⟩

private def snapshot : Term

private def receiver : Term := .field inner snapshot

private def selected : Term := .field text receiver

private theorem innerArity : P.DataArity "Inner" 0

private theorem valid : P.VarianceValid

private theorem outerData : Term.HasData P [] snapshot "Outer" []

private theorem receiverData : Term.HasData P [] receiver "Inner" []

private theorem selectedDeclared : selected.Declared P [] []

theorem field_chain_admissible : selected.AdmissibleIn P [] [] .string ∧ P.VarianceValid

private def leaf : PreparedLeaf

theorem field_leaf_checked : leaf.checkIn P [] [] [] = true

theorem field_chain_stable (ν : ObservationEnv) (η ξ : ObservationEnvModel)
    (hi : ∀ i, Observation.OptionInfoLE (η i) ((ν i).bind (Term.observe ξ))) :
    Observation.OptionInfoLE (some (.string "é"))
      ((Term.field text (termBind ν receiver)).observe ξ) ∧
    (Term.measure .stringBytes (.field text (termBind ν receiver))).observe ξ = some (.integer 2)

private def receiverImage : ObservationEnv := fun | 0 => some receiver | _ => none

private def receiverModel : ObservationEnvModel := fun
  | 0 => some (.dataValue "Inner.Make" [none,some (.string "é")])
  | _ => none

theorem open_field_stable :
    (Term.field text (.var 0)).observe receiverModel = some (.string "é") ∧
    termBind receiverImage (.field text (.var 0)) = selected ∧
    (Term.measure .stringBytes (termBind receiverImage (.field text (.var 0)))).observe
      (fun _ => none) = some (.integer 2)
```

## PreparedSortExamples

```lean
private def rows : List («Sort» × Val)

theorem observations_16 (η : ObservationEnvModel) : rows.length = 16 ∧
    ∀ row ∈ rows, ∃ t o, row.2.toTerm? = some t ∧ t.HasSort [] row.1 ∧
      t.Closed ∧ t.observe η = some o ∧ o.sort = row.1

theorem typed_observation {P B Ψ Q C Φ v a s}
    (hv : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.carrier.HasSort s)
    (η : ObservationEnvModel) :
    ∃ t o, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed ∧
      t.observe η = some o ∧ o.sort = s ∧ t.interpret η = some o

theorem top_keys : ∃ P C Γ, Certificate.AllKeysChecked P C Γ
    [CertificateKernelExamples.premise] CertificateKernelExamples.goal CertificateKernelExamples.twice
```
