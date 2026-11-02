# 群D・Eの完全署名

群Aの固定署名を引き継いだ。数学の係数はIntのままである。以下は本番の宣言から抽出した完全署名であり、本体の証明を省く。名前空間は`Benitoite.Release.Refinement`である。

`EqProof`はCertificateから移し、4構成子から9構成子へ拡張した。`check/sound`は名前と型を保つ。`BuiltinLemma/PreparedLeaf`はPreparedLeafSyntaxへ移し、固定済みの12種類・引数列・参照列を置いた。`Certificate`は6構成子と構造一致のsubstituteを保つ。全7構成子への接続は群Gの担当である。

既存の補助の変更は、Linearizationの`linearDot_zero`をprivateから公開へ移した一点である。型と本体は変えていない。非負結合がこの補助を使うため、同じ帰納を増やさない。群Aの固定署名からの変更は0。型の拡張と配置の変更は上記の固定済みの内容である。

## LinearCombination

```lean
inductive LinearStep where
  | combine (terms : List (Nat × Int)) (expected : Linear)
  | round (source : Nat) (divisor : Int) (expected : Linear)

def NNF.linear? : NNF → Option Linear

def linearCombination (n : Nat) (facts : List NNF) : List (Nat × Int) → Option Linear

theorem linearCombination_sound {n facts terms l}
    (h : linearCombination n facts terms = some l) (ρ : Nat → Int)
    (hf : ∀ q ∈ facts, ∀ a, q = .linear a → a.Holds ρ) : l.Holds ρ

def LinearStep.result : LinearStep → Linear

def LinearStep.check (n : Nat) (facts : List NNF) : LinearStep → Bool

theorem LinearStep.sound {n : Nat} {facts : List NNF} {step : LinearStep} (h : step.check n facts = true) (ρ : Nat → Int)
    (hf : ∀ q ∈ facts, ∀ a, q = .linear a → a.Holds ρ) : step.result.Holds ρ

```

## PreparedLeafSyntax

```lean
inductive BuiltinLemma where
  | closed | lengthNonnegative | measureNonnegative | booleanApart
  | compareComplement | charactersSubset | constructorApart | sameObservation
  | scalarOrder | characterCodeRange | characterCompare | floatCompareClass
  deriving DecidableEq

structure PreparedLeaf where
  predicate : Pred
  lemma : BuiltinLemma
  arguments : List Term
  references : List Nat

```

## RefutationSyntax

```lean
inductive Refutation where
  | consume (next : Refutation)
  | cases (left right : Refutation)
  | derive (step : LinearStep) (next : Refutation)
  | closeLinear (index : Nat)
  | closeAtom (positive negative : Nat)
  | split (key : Nat) (cut : Int) (left right : Refutation)
  | discardTodo (next : Refutation)
  | discardFact (index : Nat) (next : Refutation)
  | builtin (leaf : PreparedLeaf) (next : Refutation)

namespace CertificateKernel

def consume (next : List NNF → List NNF → Bool) (todo facts : List NNF) : Bool

def cases (left right : List NNF → List NNF → Bool) (todo facts : List NNF) : Bool

def splitLeft (n key : Nat) (cut : Int) : NNF

def splitRight (n key : Nat) (cut : Int) : NNF

def split (keys : KeyTable) (todo facts : List NNF) (key : Nat) (cut : Int)
    (left right : List NNF → List NNF → Bool) : Bool

def closeLinear (facts : List NNF) (i : Nat) : Bool

def closeAtom (facts : List NNF) (positive negative : Nat) : Bool

def discardTodo (next : List NNF → List NNF → Bool) (todo facts : List NNF) : Bool

def discardFact (next : List NNF → List NNF → Bool) (todo facts : List NNF) (i : Nat) : Bool

def refute (keys : KeyTable) (todo facts : List NNF) : Refutation → Bool

end CertificateKernel

```

## RefutationSound

```lean
def NNF.HoldsAt (keys : KeyTable) (ν : ObservationEnv) (η : ObservationEnvModel) (q : NNF) : Prop

theorem normalize_holds_at {keys p negative q} (h : normalize keys p negative = some q)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    q.HoldsAt keys ν η ↔
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) = true

theorem normalize_linear_at {keys p negative l} (h : normalize keys p negative = some (.linear l))
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    l.Holds (keyEnv η (keys.map (termBind ν))) ↔
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) = true

def BranchHoldsAt (keys : KeyTable) (todo facts : List NNF)
    (ν : ObservationEnv) (η : ObservationEnvModel) : Prop

def BranchRefutedAt (keys : KeyTable) (todo facts : List NNF)
    (ν : ObservationEnv) (η : ObservationEnvModel) : Prop

namespace CertificateKernel

theorem consume_sound_at {keys todo facts next}
    (h : consume next todo facts = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η

theorem cases_sound_at {keys todo facts left right}
    (h : cases left right todo facts = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (hl : ∀ ts fs, left ts fs = true → BranchRefutedAt keys ts fs ν η)
    (hr : ∀ ts fs, right ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η

theorem derive_sound_at {keys : KeyTable} {todo facts : List NNF} {step : LinearStep}
    {next : List NNF → List NNF → Bool}
    (h : (step.check keys.length facts && next todo (facts ++ [.linear step.result])) = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η

theorem split_sound_at {keys todo facts key cut left right}
    (h : split keys todo facts key cut left right = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (hl : ∀ ts fs, left ts fs = true → BranchRefutedAt keys ts fs ν η)
    (hr : ∀ ts fs, right ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η

theorem close_linear_sound_at {keys todo facts i} (h : closeLinear facts i = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) : BranchRefutedAt keys todo facts ν η

theorem close_atom_sound_at {keys todo facts p n} (h : closeAtom facts p n = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) : BranchRefutedAt keys todo facts ν η

theorem discard_todo_sound_at {keys todo facts next} (h : discardTodo next todo facts = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η

theorem discard_fact_sound_at {keys todo facts next i} (h : discardFact next todo facts i = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η

end CertificateKernel

```

## EqProofSyntax

```lean
inductive EqProof where
  | refl
  | symm (proof : EqProof)
  | trans (middle : Term) (left right : EqProof)
  | add (left right : EqProof)
  | neg (proof : EqProof)
  | scale (coefficient : Int) (proof : EqProof)
  | hyp (index : Nat)
  | field (proof : EqProof)
  | measure (proof : EqProof)

def EqProof.checkRaw (Φ : List Pred) (mode : EqualityMode) (t u : Term) : EqProof → Bool

theorem EqProof.structural_sound {Φ : List Pred} {t u : Term} {c : EqProof}
    (h : EqProof.checkRaw Φ .structural t u c = true) : t = u

theorem EqProof.integer_sound_at {Φ : List Pred} {t u : Term} {c : EqProof}
    (h : EqProof.checkRaw Φ .integer t u c = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
    integerAs η (termBind ν t) = integerAs η (termBind ν u)

def EqProof.check (t u : Term) (c : EqProof) : Bool

theorem EqProof.sound {t u : Term} {c : EqProof} (h : EqProof.check t u c = true) : t = u

```

## EqCertificate

```lean
def Term.IntegerRewritePosition : Term → Prop

def RewritePosition (p : Pred) (mode : EqualityMode) : Prop

theorem Term.IntegerRewritePosition.sound {t : Term} (h : t.IntegerRewritePosition)
    (σ τ : ObservationEnv) (η : ObservationEnvModel)
    (zero : integerAs η ((σ 0).getD (.integer 0)) = integerAs η ((τ 0).getD (.integer 0)))
    (rest : ∀ i, i ≠ 0 → σ i = τ i) : integerAs η (termBind σ t) = integerAs η (termBind τ t)

theorem RewritePosition.integer_sound {p : Pred} (h : RewritePosition p .integer)
    (σ τ : ObservationEnv) (η : ObservationEnvModel)
    (zero : integerAs η ((σ 0).getD (.integer 0)) = integerAs η ((τ 0).getD (.integer 0)))
    (rest : ∀ i, i ≠ 0 → σ i = τ i) :
    (predBind σ p).interpret η = (predBind τ p).interpret η

theorem RewritePosition.structural_sound (p : Pred) {t u : Term} (h : t = u) :
    p.open t = p.open u

instance Term.integerRewritePositionDecidable (t : Term) : Decidable t.IntegerRewritePosition

instance rewritePositionDecidable (p : Pred) (mode : EqualityMode) : Decidable (RewritePosition p mode)

def rewritePosition (p : Pred) (mode : EqualityMode) : Bool

theorem rewritePosition_spec (p : Pred) (mode : EqualityMode) :
    rewritePosition p mode = true ↔ RewritePosition p mode

theorem EqProof.substitute_sound_at {Φ : List Pred} {mode : EqualityMode} {t u : Term} {c : EqProof}
    (h : c.checkRaw Φ mode t u = true) {p : Pred} (hp : rewritePosition p mode = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ q ∈ Φ, (predBind ν q).interpret η = true) :
    (predBind ν (p.open t)).interpret η = (predBind ν (p.open u)).interpret η

```

## EqCertificateTyping

```lean
def Term.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx) (s : «Sort») (t : Term) : Prop

noncomputable def KeyTable.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx) (keys : KeyTable) : Bool

theorem KeyTable.checkIn_sound {P C Γ keys} (h : KeyTable.checkIn P C Γ keys = true) :
    P.VarianceValid ∧ ∀ t ∈ keys, t.HasSort Γ .integer ∧ t.Declared P C Γ

def EqProof.AdmissibleIn (P : Program) (C : TypeCtx) (Γ : Ctx)
    (s : «Sort») (mode : EqualityMode) (t u : Term) (c : EqProof) : Prop

noncomputable def EqProof.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (s : «Sort») (mode : EqualityMode) (t u : Term) (c : EqProof) : Bool

theorem EqProof.checkIn_sound {P C Γ Φ s mode t u c}
    (h : EqProof.checkIn P C Γ Φ s mode t u c = true) :
    EqProof.checkRaw Φ mode t u c = true ∧ EqProof.AdmissibleIn P C Γ s mode t u c ∧
      P.VarianceValid ∧ ∀ p ∈ Φ, p.Sorted Γ none ∧ p.Declared P C Γ none

theorem EqProof.integer_sound {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t u : Term} {c : EqProof}
    (h : EqProof.checkIn P C Γ Φ .integer .integer t u c = true) :
    ∀ η : ObservationEnvModel, (∀ p ∈ Φ, p.interpret η = true) → integerAs η t = integerAs η u

noncomputable def EqProof.substituteIn (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (s : «Sort») (mode : EqualityMode) (p : Pred) (t u : Term) (c : EqProof) : Bool

theorem EqProof.substituteIn_sound_at {P C Γ Φ s mode p t u c}
    (h : EqProof.substituteIn P C Γ Φ s mode p t u c = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ q ∈ Φ, (predBind ν q).interpret η = true) :
    ((p.open t).Sorted Γ none ∧ (p.open t).Declared P C Γ none ∧
      (p.open u).Sorted Γ none ∧ (p.open u).Declared P C Γ none) ∧
      (predBind ν (p.open t)).interpret η = (predBind ν (p.open u)).interpret η

```

## 共有補助の公開

```lean
theorem linearDot_zero (n : Nat) (ρ : Nat → Int) :
    linearDot (List.replicate n 0) ρ = 0
```
