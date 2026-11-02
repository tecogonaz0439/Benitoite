# 群B以降へ渡す完全署名

2026-11-03。名前空間は特記しない限り `Benitoite.Release.Refinement`。本書は後続の実装の契約であり、全宣言の実装済みを表さない。本番に置いた宣言は [結果](results.md) の一覧を正とする。主な十言明・既存 `Entails.bind` の量化と結論を保つ。型付きの入口と、生の有限な検査器を分ける。

## 配置とimport

既定ビルドにある依存は `LinearSyntax` → `CertificateKernelBind` → `LinearSound` / `EqCertificate` である。矢印は左を先に置く意味である。`EqualityMode` はEqCertificate内にある。群Bの.08で定義を独立した `EqualityMode` モジュールへ移し、`CertificateSyntax` より前に置く。完全名と定義は保つ。

後続の順は `LinearSyntax` / `EqualityMode` → `CertificateSyntax` → `Linearization` / `LogicNormalization` / `EqCertificate` / `BuiltinLogic` → `CertificateKernel` → `Logic` → `Basic` / `LogicSound` → 型付けと上層 `Certificate` / `PreparedLeaf` である。下層のCertificateKernelBindは整数射影・置換合成の一般補題を供給し、CertificateKernelをimportしない。全検査器の健全性とその合成の系はCertificateKernel側へ置く。`CertificateSyntax` は有限データだけを持つ。`CertificateKernel` は `Entails`・`Ty.LeQ`・`HasTypeVQ`・`ValueMeaning` を import しない。既存の `ScopeSyntax` が旧 `Release.Typing` を読む依存は残る。この境界は新しい篩の型付け・意味・捕捉への逆向きの依存を禁止するものである。

`Observation.measure_nonnegative` は `MeasureNonnegative` へ移した。同じ完全名・同じ言明であり、旧 `Certificate` の import も残る。`CarrierFacts` は `Context` の後、`CarrierFactsMeaning` は `RefinementObservation` と `ExternalObservation` の後に置く。NumericRepresentedの定義を.51でSyntax直後へ移した後は、CarrierFactsMeaningのExternalObservationへの依存もその定義のモジュールへの依存へ替える。切替時にCarrierFactsの定義をContextへ移してよいが、完全名と意味は保つ。

## S01: 並置と切替（H/I）

```lean
def integerBounds (lo hi : Int) : List Pred :=
  [.le (.integer lo) (.var 0), .le (.var 0) (.integer hi)]
def Ty.carrierFacts (a : Ty) : List Pred
def Ty.assumeWithCarrier (a : Ty) : List Pred
def Ctx.factsWithCarrier (Γ : Ctx) : List Pred
theorem Ty.assumeWithCarrier_eq_carrier_append {a : Ty} (h : a.Ordinary) :
  a.assumeWithCarrier = a.carrierFacts ++ a.refinementPredicates
theorem Ty.carrierFacts_norm (a : Ty) : a.norm.carrierFacts = a.carrierFacts
theorem Ty.carrierFacts_bind (a : Ty) (θ : SubstEnv) :
  ∀ p ∈ a.carrierFacts, predBind (upValues θ.values) p ∈ (a.bind θ).carrierFacts
theorem Ty.assumeWithCarrier_refined {a : Ty} (h : a.Ordinary) (p : Pred) :
  (Ty.refined a p).assumeWithCarrier = a.assumeWithCarrier ++ p.conjuncts
theorem Ty.assumeWithCarrier_shiftV (a : Ty) (k c : Nat) :
  (a.shiftV k c).assumeWithCarrier = a.assumeWithCarrier.map (Pred.shiftV k (c+1))
theorem Ctx.mem_factsWithCarrier {Γ : Ctx} {p : Pred} :
  p ∈ Γ.factsWithCarrier ↔ ∃ i a q,
    Γ[i]? = some (some a) ∧ q ∈ a.assumeWithCarrier ∧ p = q.open (.var i)
theorem Const.NumericRepresented.carrierFacts {c : Const}
  (h : c.NumericRepresented) (η : ObservationEnvModel) :
  ∀ p ∈ c.type.carrierFacts, p.interpret (selfModel η (.const c)) = true
```

芯の Integer64/Integer8/Integer16/Integer32/UnsignedInteger16/UnsignedInteger32/UnsignedInteger64/Byte にそれぞれ2端点、Decimalに `decimalRepresented self`、他は空列である。`refined` は芯を読む。`tvar` に対する元の空列を、型置換の像の空列へ等号で移す規則は設けない。`carrierFacts_bind` は所属の片方向である。`refinementPredicates` は変えない。

切替は **L30.51**（180〜300分）である。.43〜.50では旧 `Ty.assume` / `Ctx.facts` を保つ。.51で次の三条件の `ValueMeaning.mk`、型付き事実、全直接・間接 `CaptureOk`、十移送と全読者を同時に直す。並置名を互換な略記へ寄せ、二つの判断を提供し続けない。.52〜.54は切替後の照合である。

```lean
-- L30.51におけるValueMeaningの唯一の構成子。
| mk {a : Ty} {v : Val} : ValueShapeMeaning P η a.norm.core v →
    (∀ p ∈ a.norm.refinementPredicates, p.interpret (selfModel η v) = true) →
    (∀ p ∈ a.carrierFacts, p.interpret (selfModel η v) = true) → ValueMeaning P η a v

-- NumericRepresentedの定義の内容を保ち、Syntax直後へ移す。
theorem TypedMeaning.const_meaning (P : Program) (η : ObservationEnvModel)
  (c : Const) (hc : c.NumericRepresented) : ValueMeaning P η c.type (.const c)

theorem HasTypeVQ.carrierFacts {P : Program} {B Ψ Q C Γ Φ v a}
  (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
  ∀ p ∈ a.carrierFacts,
    Entails (Γ.facts ++ Φ) (p.open (v.toTerm?.getD (.integer 0)))
```

`ConstOK.represented` は現行の署名を保つ。Integer64の型域は `Integer64Value.property` から供給する。捕捉の最後の欄は現行と同じ字面の
`∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p)` であり、`.51`で `Γ.facts` の定義を切り替える。`CoreAssumptions` に欄を加えない。`typed_value_meaning_closed`・`valueMeaning_sub`・`close_value_typed` の言明は変えない。

最初の16読者のうち、並置で新しく必要な補助の残りを次に固定する。型域を読む文脈の移送は旧 `Transport.facts` だけからは導けないため、その列の各像の導出を引数で受ける。これは型付けの仮定の追加ではなく、.49/.51で型付きの像から供給する内部の補題の入力である。

```lean
def assumptionsWithCarrier (Γ : Ctx) (Φ : List Pred) (a : Ty) : List Pred :=
  a.assumeWithCarrier ++ (Γ.factsWithCarrier ++ Φ).map Pred.lift
theorem Ty.assumeWithCarrier_norm (a : Ty) : a.norm.assumeWithCarrier = a.assumeWithCarrier
theorem Ty.assumeWithCarrier_bind (a : Ty) (θ : SubstEnv) (ht : ∀ i, Ordinary (θ.types i)) :
  ∀ p ∈ a.assumeWithCarrier, predBind (upValues θ.values) p ∈ (a.bind θ).assumeWithCarrier
theorem Ctx.mem_factsWithCarrier_extend {Γ : Ctx} {a : Ty} {q : Pred} :
  q ∈ (Γ.extend a).factsWithCarrier ↔ q ∈ a.assumeWithCarrier ∨ ∃ p ∈ Γ.factsWithCarrier, p.lift = q
theorem Ctx.mem_factsWithCarrier_extendNone {Γ : Ctx} {q : Pred} :
  q ∈ Γ.extendNone.factsWithCarrier ↔ ∃ p ∈ Γ.factsWithCarrier, p.lift = q
theorem assumptionsWithCarrier_bind {θ : SubstEnv} {Γ Δ : Ctx} {Φ Ψ : List Pred}
  (ht : ∀ i, Ordinary (θ.types i))
  (hf : ∀ p ∈ Γ.factsWithCarrier ++ Φ,
    Entails (Δ.factsWithCarrier ++ Ψ) (predBind θ.values p)) (a : Ty) :
  ∀ p ∈ assumptionsWithCarrier Γ Φ a,
    Entails (assumptionsWithCarrier Δ Ψ (a.bind θ)) (predBind (upValues θ.values) p)
theorem Ty.assumeWithCarrier_of_norm_eq {a b : Ty} (he : a.norm = b.norm) (Ξ : List Pred)
  (ha : ∀ p ∈ a.assumeWithCarrier, Entails Ξ p) : ∀ p ∈ b.assumeWithCarrier, Entails Ξ p
theorem Ctx.factsWithCarrier_map_norm (Γ : Ctx) :
  Ctx.factsWithCarrier (Γ.map (Option.map Ty.norm)) = Γ.factsWithCarrier
theorem Ctx.NormEq.factsWithCarrier {Γ Δ : Ctx} (h : Γ.NormEq Δ) :
  Γ.factsWithCarrier = Δ.factsWithCarrier
theorem Ty.LeQ.assumeWithCarrier {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty}
  (h : Ty.LeQ P Γ Φ a b) : ∀ q ∈ b.assumeWithCarrier, Entails (assumptionsWithCarrier Γ Φ a) q
theorem Ty.assumeWithCarrier_of_wf {nr nt nv : Nat} {a : Ty} (hw : a.WF nr nt nv) :
  a.assumeWithCarrier = a.carrierFacts ++ a.refinementPredicates
theorem Ty.entails_assumeWithCarrier_iff (Ξ : List Pred) (a : Ty) (ho : a.Ordinary) :
  (∀ p ∈ a.assumeWithCarrier, Entails Ξ p) ↔
    (∀ p ∈ a.carrierFacts, Entails Ξ p) ∧ (∀ p ∈ a.refinementPredicates, Entails Ξ p)
```

16読者の15/16である `Ctx.TypeMap.norm` / `Ctx.TypeMap.facts` は、.51で `Ctx.TypeMap.lookup` の事実の包含の定義を切り替えるときに、現行の公開署名を保って再照合する。並置期間に旧TypeMapから新factsの包含を結論する補題は作らない。.51で `Transport.assumptions` も現行の公開署名を保ち、その `Transport.facts` の定義を切り替える。新名の包装を16件に合わせて増やさない。

## S02: 線形式・否定標準形（B/C/D）

```lean
structure Linear where
  coefficients : List Int
  bound : Int
def linearDot : List Int → (Nat → Int) → Int
def Linear.eval (l : Linear) (ρ : Nat → Int) : Int
def Linear.Holds (l : Linear) (ρ : Nat → Int) : Prop := l.eval ρ ≤ l.bound
def linearTerm : List Term → List Int → Term
def Linear.toPred (keys : List Term) (l : Linear) : Pred
def keyEnv (η : ObservationEnvModel) (keys : List Term) : Nat → Int
theorem Linear.encode_bind (ν : ObservationEnv) (keys : List Term) (l : Linear) :
  predBind ν (l.toPred keys) = l.toPred (keys.map (termBind ν))
theorem Linear.toPred_sound_at (η : ObservationEnvModel) (ν : ObservationEnv)
  (keys : List Term) (l : Linear) (h : keys.length = l.coefficients.length) :
  (predBind ν (l.toPred keys)).interpret η = true ↔
    l.Holds (keyEnv η (keys.map (termBind ν)))

abbrev KeyTable := List Term
def termEq (t u : Term) : Bool
def predEq (p q : Pred) : Bool
theorem termEq_spec (t u : Term) : termEq t u = true ↔ t = u
theorem predEq_spec (p q : Pred) : predEq p q = true ↔ p = q
def keyIndex (keys : KeyTable) (t : Term) : Option Nat
theorem keyIndex_sound {keys : KeyTable} {t : Term} {i : Nat}
  (h : keyIndex keys t = some i) : keys[i]? = some t

-- 式は係数列と定数項、不等式はLinearのboundを使う。
def linearize (keys : KeyTable) (t : Term) : Option (List Int × Int)
theorem linearize_length {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
  (h : linearize keys t = some (cs,b)) : keys.length = cs.length
theorem linearize_sound_at {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
  (h : linearize keys t = some (cs,b)) (ν : ObservationEnv) (η : ObservationEnvModel) :
  integerAs η (termBind ν t) = linearDot cs (keyEnv η (keys.map (termBind ν))) + b

inductive NNF where
  | truth | falsity
  | linear (constraint : Linear)
  | literal (atom : Pred) (negative : Bool)
  | and (left right : NNF)
  | or (left right : NNF)
def NNF.toPred (keys : KeyTable) : NNF → Pred
def normalize (keys : KeyTable) (p : Pred) (negative : Bool) : Option NNF
theorem normalize_sound_at {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
  (h : normalize keys p negative = some q) (ν : ObservationEnv) (η : ObservationEnvModel) :
  (predBind ν (q.toPred keys)).interpret η =
    (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η)
theorem normalize_sound {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
  (h : normalize keys p negative = some q) : ∀ η : ObservationEnvModel,
  (q.toPred keys).interpret η = (if negative then !(p.interpret η) else p.interpret η)
```

`linearize` の結果を `Linear` 一個とする案を改めた。`Linear.eval` は係数の内積なので、空の係数列だけでは定数7を表せないためである。定数項を引いた値を不等式の `bound` へ移す。各再帰で列の長さを検査する。構造を先に分解し、整数定数・add・neg・scale以外の項は検査した鍵として扱う。rawな核での整数射影と、上層でSource/sort/Declaredを検査して拒否する13形を区別する。鍵列の相異性を仮定しない。

`normalize_sound_at` は原子を含めて `predBind ν (q.toPred keys)` を読む。`q.toPred (keys.map ...)` だけではliteralの原子が置換されないので代用しない。恒等置換から `normalize_sound` を導く。NNFは検査器が再計算し、外からtraceを受け取らない。

```lean
inductive LinearStep where
  | combine (terms : List (Nat × Int)) (expected : Linear)
  | round (source : Nat) (divisor : Int) (expected : Linear)

theorem integer_round {x b d : Int} (hd : 0 < d) (h : d*x ≤ b) : x ≤ b/d
theorem linearDot_scale (d : Int) (cs : List Int) (ρ : Nat → Int) :
  linearDot (cs.map (d * ·)) ρ = d * linearDot cs ρ
theorem Linear.round_sound {source result : Linear} (d : Int) (ρ : Nat → Int)
  (hd : 0 < d) (hc : source.coefficients = result.coefficients.map (d * ·))
  (hb : result.bound = source.bound / d) (h : source.Holds ρ) : result.Holds ρ
theorem integer_split (x cut : Int) : x ≤ cut ∨ cut+1 ≤ x
theorem integer_split_refute {x cut : Int}
  (left : x ≤ cut → False) (right : cut+1 ≤ x → False) : False
theorem integer_combination {x y b c k l : Int} (hk : 0 ≤ k) (hl : 0 ≤ l)
  (hx : x ≤ b) (hy : y ≤ c) : k*x+l*y ≤ k*b+l*c
theorem integerAs_round_at (η : ObservationEnvModel) (ν : ObservationEnv)
  (t : Term) {b d : Int} (hd : 0 < d)
  (h : integerAs η (termBind ν (.scale d t)) ≤ b) : integerAs η (termBind ν t) ≤ b/d
theorem integerAs_split_at (η : ObservationEnvModel) (ν : ObservationEnv) (t : Term) (cut : Int) :
  integerAs η (termBind ν t) ≤ cut ∨ cut+1 ≤ integerAs η (termBind ν t)
```

roundは正の除数・全係数の整除・床のboundの一致を全て検査する。combineは全参照・同じ列長・非負乗数・全係数とboundの一致を検査する。空和も数学の0として扱う。splitは案(ii)なので **鍵番号 `Nat` とcut `Int`** を保つ。νの像の整数射影に上の二分を適用する。

## S04: 等号と有限の別名（E）

```lean
inductive EqualityMode where
  | structural | integer
def Term.IntegerRewritePosition : Term → Prop
def RewritePosition (p : Pred) (mode : EqualityMode) : Prop
def rewritePosition (p : Pred) (mode : EqualityMode) : Bool
theorem rewritePosition_spec (p : Pred) (mode : EqualityMode) :
  rewritePosition p mode = true ↔ RewritePosition p mode

/-- 有限な等号の証拠。別名は展開済みの実際の像をreflで照合し、
ソース名や未検査の置換表を等号の根拠にしない。 -/
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

def EqProof.checkRaw (Φ : List Pred) (mode : EqualityMode) (t u : Term) (c : EqProof) : Bool
theorem EqProof.structural_sound {Φ : List Pred} {t u : Term} {c : EqProof}
  (h : EqProof.checkRaw Φ .structural t u c = true) : t = u
theorem EqProof.integer_sound_at {Φ : List Pred} {t u : Term} {c : EqProof}
  (h : EqProof.checkRaw Φ .integer t u c = true) (ν : ObservationEnv) (η : ObservationEnvModel)
  (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
  integerAs η (termBind ν t) = integerAs η (termBind ν u)

def EqProof.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
  (s : «Sort») (mode : EqualityMode) (t u : Term) (c : EqProof) : Bool
theorem EqProof.integer_sound {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {t u : Term} {c : EqProof}
  (h : EqProof.checkIn P C Γ Φ .integer .integer t u c = true) :
  ∀ η : ObservationEnvModel, (∀ p ∈ Φ, p.interpret η = true) → integerAs η t = integerAs η u

-- 旧の構造等号の二署名も残す。新しいinteger専用構成子は旧checkではfalse。
def EqProof.check (t u : Term) (c : EqProof) : Bool
theorem EqProof.sound {t u : Term} {c : EqProof}
  (h : EqProof.check t u c = true) : t = u
```

EqProofは9構成子とする。独立したalias構成子とexpandAliasesは設けない。初案のaliasは実際の端点t/uの構造一致を要求するため、reflで同じ結論を得られる。展開を共有して検査の手間を減らす実装はまだなく、独立した証拠の構文を保つ理由がない。ソースのletから有限な実像を作る仕事はL70/R10bに置き、捕捉・置換の後の端点をtermEq/reflで照合する。snapshot内のNoneは保つ。**同じ名前や任意の置換で同じ像へ写したという理由で、元の二変数を等しいとはしない。**

integerで自己を変えてよいのはeq/le/ltの両辺、そのadd/neg/scaleの下、論理結合子の下である。他の項・原子は自己を含まないときだけそのまま使う。structuralは全項位置で使える。field/measureの子はstructuralに固定する。上層のcheckInでは両端点とtransの中間、各子のsortとDeclared、fieldの同じ名目型・constructor・型引数・位置・結果sortを検査する。`FieldRef.Declared`だけでwiden前のsortを反映せず、上層の宣言供給には同じPの `VarianceValid` を使う。生の健全性へはこの未検査の仮定を足さない。

## S02/S05: 有限データと純粋な検査（D/F/G/K）

```lean
inductive BuiltinLemma where
  | closed | lengthNonnegative | measureNonnegative | booleanApart
  | compareComplement | charactersSubset | constructorApart | sameObservation
  | scalarOrder | characterCodeRange | characterCompare | floatCompareClass
structure PreparedLeaf where
  predicate : Pred
  lemma : BuiltinLemma
  arguments : List Term
  references : List Nat
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
inductive Certificate where
  | use (index : Nat)
  | leaf (value : PreparedLeaf)
  | substitute (predicate : Pred) (left right : Term) (eq : EqProof)
      (proof : Certificate) (mode : EqualityMode)
  | consume (next : Certificate)
  | cases (left right : Certificate)
  | discard (next : Certificate)
  | refute (proof : Refutation)

def PreparedLeaf.checkRaw (Φ : List Pred) (l : PreparedLeaf) : Bool
theorem PreparedLeaf.raw_sound_at {Φ : List Pred} {l : PreparedLeaf}
  (h : PreparedLeaf.checkRaw Φ l = true) (ν : ObservationEnv) (η : ObservationEnvModel)
  (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
  (predBind ν l.predicate).interpret η = true
def CertificateKernel.refute (keys : KeyTable) (todo facts : List NNF) (c : Refutation) : Bool
theorem CertificateKernel.refute_sound_at {keys : KeyTable} {todo facts : List NNF} {c : Refutation}
  (h : CertificateKernel.refute keys todo facts c = true) (ν : ObservationEnv) (η : ObservationEnvModel) :
  (∀ q ∈ todo ++ facts, (predBind ν (q.toPred keys)).interpret η = true) → False
def Certificate.keys (premise goal : Pred) (c : Certificate) : KeyTable
def Certificate.check (Φ : List Pred) (goal : Pred) (c : Certificate) : Bool
def CertificateKernel.check (premise goal : Pred) (c : Certificate) : Bool :=
  Certificate.check premise.conjuncts goal c
theorem CertificateKernel.implication_sound_at {p q : Pred} {c : Certificate}
  (h : CertificateKernel.check p q c = true) :
  ∀ (ν : ObservationEnv) (η : ObservationEnvModel),
    (predBind ν p).interpret η = true → (predBind ν q).interpret η = true
theorem CertificateKernel.implication_sound {p q : Pred} {c : Certificate}
  (h : CertificateKernel.check p q c = true) :
  ∀ η : ObservationEnvModel, p.interpret η = true → q.interpret η = true
theorem CertificateKernel.check_sound {premise goal : Pred} {c : Certificate}
  (h : CertificateKernel.check premise goal c = true) :
  ∀ η : ObservationEnvModel, (.and premise (.not goal)).interpret η ≠ true
```

宣言順はEqualityMode/Linear/NNF→EqProof→BuiltinLemma/PreparedLeaf→Refutation→Certificateである。`substitute`の末尾のmodeを明示する（旧6場合の移送はmodeをstructuralにする）。旧のraw検査の引数Φ/goalは保つ。checkedAtを採るので、**`check_bind : ∃ c' ...`を後続の完了条件にはしない**。raw_sound_atは12schemaの全有限規則で直接証明する。checkInのsortだけを根拠にrawで偽の規則を受けない。

鍵は外部の列を信用せず、premise・goalと証明書中の全項・述語・組込み引数・等号の中間項・展開済みの実像を走査して再計算する。組込みで初めて使うmeasure等もこの有限の入力に含める。外部のキー番号やハッシュの一致だけで同一視しない。`refute`のtodoは内部でnormalizeした `premise ∧ not goal` から作り、初期factsは空とする。builtinで増える述語も同じ鍵でnormalizeし、失敗は拒否する。

参照は現在の枝の列のNatである。todoのOrはcasesで両枝を検査する。deriveは現在のfactsだけを読む。discardFactは削除後の列を子へ渡す。兄弟・将来・循環・範囲外を受けない。B01〜B12の内容・100分岐、比較30と分類12、Refutation9とCertificate7の対応は [detail第3節](../detail.md#3-d06-の規則レビューと場合の対応) を保つ。型域を無条件builtinとして登録しない。

## S03: 構文による含意への一度の接続（G）

```lean
-- Entailsの追加構成子。cは有限データであり、意味の含意を欄にしない。
| checkedAt {Ξ : List Pred} {p q : Pred} {c : Certificate} (ν : ObservationEnv) :
    CertificateKernel.check p q c = true → Entails Ξ (predBind ν p) → Entails Ξ (predBind ν q)

theorem Entails.checked {Ξ : List Pred} {p q : Pred} {c : Certificate}
  (hc : CertificateKernel.check p q c = true) (hp : Entails Ξ p) : Entails Ξ q
theorem Entails.bind {Ξ : List Pred} {p : Pred} (h : Entails Ξ p) (ν : ObservationEnv) :
  Entails (Ξ.map (predBind ν)) (predBind ν p)
theorem Certificate.refutation_entails {Φ : List Pred} {goal : Pred} {c : Certificate}
  (h : CertificateKernel.check (Pred.ofConjuncts Φ) goal c = true) : Entails Φ goal
theorem Certificate.sound {Φ : List Pred} {goal : Pred} {c : Certificate}
  (h : Certificate.check Φ goal c = true) : Entails Φ goal
```

`checked`は恒等置換 `fun i => some (.var i)` から得る導出であり、第二の構成子ではない。weaken/cutは子の帰納仮定を使う。soundは `implication_sound_at` を使う。bindでは、構成子のνと外側のτを `fun i => (ν i).bind (termBind? τ)` へ合成し、`predBind_comp` を両辺へ適用する。既存の四つの帰納に各一場合を加える。型付け相互76場合には新構成子を加えない。

## S05/S06: 上層の葉とL40（J/K）

```lean
def PreparedLeaf.checkIn (P : Program) (C : TypeCtx) (Γ : Ctx)
  (Φ : List Pred) (l : PreparedLeaf) : Bool
theorem PreparedLeaf.entailsIn {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {l : PreparedLeaf}
  (h : l.checkIn P C Γ Φ = true) : Entails (Γ.facts ++ Φ) l.predicate
theorem PreparedLeaf.bind_entails {P : Program} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {l : PreparedLeaf}
  (h : l.checkIn P C Γ Φ = true) (ν : ObservationEnv) :
  Entails ((Γ.facts ++ Φ).map (predBind ν)) (predBind ν l.predicate)
theorem checked_refinement {P : Program} {Γ : Ctx} {Φ : List Pred} {a b : Ty} {p q : Pred} {c : Certificate}
  (hab : Ty.LeQ P Γ Φ a b)
  (hp : p.Sorted Γ (some a)) (hq : q.Sorted Γ (some b))
  (hc : CertificateKernel.check (Pred.ofConjuncts (p :: assumptions Γ Φ a)) q c = true) :
  Ty.LeQ P Γ Φ (.refined a p) (.refined b q)

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
-- 既存の入口をそのまま使い、新しい包装を置かない。
theorem HasTypeVQ.represented {P B Ψ Q C Φ v a s}
  (h : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.carrier.HasSort s) :
  ∃ t, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed
```

`checked_refinement` は `Certificate.refutation_entails hc` を既存の `Ty.LeQ.refine` へ渡す。`bind_entails` は `entailsIn` と元の `Entails.bind` の合成である。型・行・範囲・値の四つの像について新しいTransportを仮定しない。

L40へ渡す三経路は、(1)型付き定数の型域と `ConstOK.represented`、(2)実measureの正常結果と上の二補題、(3) `Interval.IntKind.checkedAdd/Sub/Mul/Neg` の正常応答とあふれの別である。`checkedAdd_normal_iff`・`checkedSub_normal_iff`・`checkedMul_normal_iff`・`checkedNeg_normal_iff` は既存の完全署名を保って引用する。任意の抽象B.deltaが算術と一致するとはしない。標準本体との合成はL40で行う。主定理の仮定へδとの一致を足さない。

Map/Setでは `Key.normalizeMap_length`・`Key.normalizeSet_length` の現行の `Key.ClosedSlots` をそのまま使う。これらは正常とnoneの双方を保つ。鍵コードの成功を導く新しい構造の関係と、同じ型の言語上の鍵の等値との対応は、detailと既存結果で指定されたとおり **.59/.60で具体化する**。Aで任意の `B.sat` から成功を得る署名は置かない。成功11形・対象外3形とDecimalの正準化を構造から処理し、L20のunknown例を保つ。

## U03の決定と引数で述べる数学の契約（L）

```lean
def CoefficientRepresented (bits : Nat) (n : Int) : Prop :=
  0 < bits ∧ -(2^(bits-1) : Int) ≤ n ∧ n < (2^(bits-1) : Int)
```

U03は2026-11-03の設計者の決定で閉じた。保存係数・定数は符号付き128ビット、byteの読取り/比較は一byte、構造は一節点/辺/要素、固定幅算術は一演算を一回ずつ数える。版はproof-steps-v1。要素を作る時に解放を個別に予約し、破棄時に一度だけusedへ移す。群L六単位は回答を待たず、各単位の依存順で起動できる。

数学の補題では保存幅と一時の計算域の幅を別のNat引数として扱い、公開の保存幅へ128を適用する。成功した部分演算が数学Intの結果と同じであることを証明し、保存時には保存幅を再検査する。閉じたDecimalの桁合わせとu64の一時積はこの保存幅で計算せず、Float比較も係数へ丸めない。stepsの実行可能なタグと遷移は上の決定に従って群Lで具体化する。B〜Kの数学の検査器へ独立の深さ・枝数・証明書量の上限を足さない。

## D/Gの確定した単位表

取りまとめの2026-11-03の判断でcheckedAtを採択し、再開1でdetailへ反映した。線形化のν上の証明はB、正規化のν上の証明はCへ割り当て、.19は合成だけとする。恒等置換の系は.38だけで扱う。

| 単位 | 固定する完全署名・手順 | 見込み（能動時間） |
|---|---|---|
| .19 | Bのlinearize_sound_atとCのnormalize_sound_atを同じ鍵列とνで合成する。再線形化や二つの帰納を繰り返さない | 15〜30分 |
| .21 | consume/casesの各枝について `predBind ν (q.toPred keys)` の真を保つ。Orの左右で同じ元のfactsを使う | 30〜60分を維持 |
| .22 | 現在のfactsの線形式へ `keyEnv η (keys.map (termBind ν))` を適用し、combineの全一致を検査する | 30〜60分を維持 |
| .23 | `Linear.round_sound` と `integerAs_split_at`。splitの対象はNatの鍵番号のまま、左右両枝を要求する | 45〜90分を維持 |
| .24 | 同じνの下でcloseLinear/closeAtom/discardを証明。削除後のindexを再解決する | 30〜60分を維持 |
| .37 | `CertificateKernel.refute_sound_at`。todo/facts/keys/ν/ηを一般化し、Refutation9場合の帰納を一回行う | 60〜120分を維持 |
| .38 | Certificate7場合のν上の健全性を合成し、恒等置換から従来のcheck_sound/implication_soundを得る。旧6場合の成功はstructuralのmodeで保存 | 30〜60分を維持 |
| .39 | .38のimplication_sound_atを使い、predBind_compでνを合成する。恒等置換の系を重ねて作らず、c'も再構成しない | 30〜60分 |
| .40 | 構成子はcheckedAt一個。checkedは導出。四帰納を一度直し、Entails.bindの公開署名を維持 | 45〜90分を維持 |

Fのraw_bindという表記も、証明書の再生成ではなく `PreparedLeaf.raw_sound_at` への接続と読む。主な定理の言明を変える必要が出た場合は本書を独断で改めず停止する。Aの代表だけを根拠に未経験の全帰納の見込みを下げない。
