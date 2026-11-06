import Benitoite.Release.Refinement.BuiltinFacts
import Benitoite.Release.Refinement.ScalarLogic
import Benitoite.Release.Refinement.FieldAtomSound

/-! # 登録済みの有限な論理補題の節 -/
namespace Benitoite.Release.Refinement

namespace BuiltinSchema

def implies (p q : Pred) : Pred := .or (.not p) q

def scalarOrder (s : «Sort») (r : ScalarRule) (a b c : Term) : Pred :=
  match r with
  | .eqSymm => implies (.compare s .eq a b) (.compare s .eq b a)
  | .eqTrans => implies (.and (.compare s .eq a b) (.compare s .eq b c)) (.compare s .eq a c)
  | .ltTrans => implies (.and (.compare s .lt a b) (.compare s .lt b c)) (.compare s .lt a c)
  | .leTrans => implies (.and (.compare s .le a b) (.compare s .le b c)) (.compare s .le a c)
  | .ltLe => implies (.and (.compare s .lt a b) (.compare s .le b c)) (.compare s .lt a c)
  | .leLt => implies (.and (.compare s .le a b) (.compare s .lt b c)) (.compare s .lt a c)

def scalarRules : List ScalarRule := [.eqSymm, .eqTrans, .ltTrans, .leTrans, .ltLe, .leLt]
def equalityRules : List ScalarRule := [.eqSymm, .eqTrans]
def measures : List Measure := [.stringBytes, .stringCharacters, .listLength,
  .bytesLength, .mapSize, .setSize, .characterCode]
def sorts : List «Sort» := [.integer, .character, .float64, .float32, .decimal,
  .boolean, .unit, .string, .list, .bytes, .map, .set, .data,
  .target .path, .target .host, .target .endpoint]
def classes : List FloatClass := [.finite, .nan, .positiveInfinity,
  .negativeInfinity, .positiveZero, .negativeZero]
def comparisons : List Comparison := [.eq, .ne, .lt, .le, .gt, .ge]

def observationAtom (s : «Sort») (t : Term) : Pred := match s with
  | .integer => .eq t (.integer 0)
  | .character => .compare .character .eq t (.character '\x00')
  | .float64 => .compare .float64 .eq t (.float64 0)
  | .float32 => .compare .float32 .eq t (.float32 0)
  | .decimal => .compare .decimal .eq t (.decimal 0 0)
  | .boolean => .compare .boolean .eq t (.boolean false)
  | .unit => .compare .unit .eq t .unitValue
  | .string => .compare .string .eq t (.string "")
  | .list => .le (.integer 0) (.measure .listLength t)
  | .bytes => .le (.integer 0) (.measure .bytesLength t)
  | .map => .le (.integer 0) (.measure .mapSize t)
  | .set => .le (.integer 0) (.measure .setSize t)
  | .data => .constructorIs t ""
  | .target k => .member k t .top

def comparisonInteger (o : Comparison) (a b : Term) : Pred := match o with
  | .eq => .eq a b | .ne => .not (.eq a b)
  | .lt => .lt a b | .le => .le a b | .gt => .lt b a | .ge => .le b a

def characterCompare (o : Comparison) (a b : Term) : Pred :=
  let p := .compare .character o a b
  let q := comparisonInteger o (.measure .characterCode a) (.measure .characterCode b)
  .and (implies p q) (implies q p)

def floatSort : FloatWidth → «Sort»
  | .binary32 => .float32 | .binary64 => .float64

/-- negativeは、この定数の符号である。floatClassのゼロの節は、
正のゼロを負のゼロと、負のゼロを正のゼロと比較し、数としての等号を示す。 -/
def floatZero (w : FloatWidth) (negative : Bool) : Term := match w with
  | .binary32 => .float32 (if negative then 2147483648 else 0)
  | .binary64 => .float64 (if negative then 9223372036854775808 else 0)

def floatPartition (w : FloatWidth) (a : Term) : Pred :=
  let fin := .floatClass w .finite a
  let nan := .floatClass w .nan a
  let pos := .floatClass w .positiveInfinity a
  let neg := .floatClass w .negativeInfinity a
  .and (.or (.or (.or fin nan) pos) neg)
    (.and (.not (.and fin (.or (.or nan pos) neg)))
      (.and (.not (.and nan (.or pos neg))) (.not (.and pos neg))))

def floatClass (w : FloatWidth) (c : FloatClass) (a b : Term) : Pred :=
  .and (floatPartition w a) (match c with
  | .finite => implies (.floatClass w .finite a)
      (.and (.not (.floatClass w .nan a))
        (.and (.not (.floatClass w .positiveInfinity a)) (.not (.floatClass w .negativeInfinity a))))
  | .nan => implies (.floatClass w .nan a)
      (.and (.not (.compare (floatSort w) .eq a b))
        (.and (.not (.compare (floatSort w) .lt a b))
          (.and (.not (.compare (floatSort w) .le a b))
            (.and (.not (.compare (floatSort w) .gt a b)) (.not (.compare (floatSort w) .ge a b))))))
  | .positiveInfinity => implies (.and (.floatClass w .positiveInfinity a) (.floatClass w .finite b))
      (.and (.compare (floatSort w) .gt a b) (.not (.compare (floatSort w) .le a b)))
  | .negativeInfinity => implies (.and (.floatClass w .negativeInfinity a) (.floatClass w .finite b))
      (.and (.compare (floatSort w) .lt a b) (.not (.compare (floatSort w) .ge a b)))
  | .positiveZero => implies (.floatClass w .positiveZero a)
      (.and (.and (.floatClass w .finite a) (.compare (floatSort w) .eq a (floatZero w true)))
        (.not (.floatClass w .negativeZero a)))
  | .negativeZero => implies (.floatClass w .negativeZero a)
      (.and (.and (.floatClass w .finite a) (.compare (floatSort w) .eq a (floatZero w false)))
        (.not (.floatClass w .positiveZero a))))

/-- 関係の下で二つの原子を双方向へ移す有限の節。 -/
def fieldTransfer (s : «Sort») (cs : List ConName) (a b : Term) (p q : Pred) : List Pred :=
  [implies (.and (fieldRelation s cs none a b) p) q,
   implies (.and (fieldRelation s cs none a b) q) p]

/-- 比較の相手、文字の端点、構成子名は実際の項として渡す。 -/
def fieldCandidates (s : «Sort») (cs : List ConName) (arguments : List Term) : List Pred :=
  match arguments with
  | [a,b,t] =>
      (if s ∈ [«Sort».character, .decimal, .float64, .float32, .boolean, .string, .unit] then
        comparisons.flatMap fun o =>
          fieldTransfer s cs a b (.compare s o a t) (.compare s o b t) ++
          fieldTransfer s cs a b (.compare s o t a) (.compare s o t b)
       else []) ++
      (match s,t with
       | .data, .string c => if c ∈ cs then
           fieldTransfer .data cs a b (.constructorIs a c) (.constructorIs b c) else []
       | _, _ => [])
  | [a,b,.character lo,.character hi] =>
      if s = .string then fieldTransfer .string cs a b (.charactersIn a lo hi) (.charactersIn b lo hi)
      else []
  | [a,b] =>
      (match s with | .float32 => [FloatWidth.binary32] | .float64 => [.binary64] | _ => []).flatMap fun w =>
        classes.flatMap fun c =>
          fieldTransfer (floatSort w) cs a b (.floatClass w c a) (.floatClass w c b)
  | _ => []

mutual
  private def observationEq : Observation → Observation → Bool
    | .integer a, .integer b => decide (a = b)
    | .character a, .character b => decide (a = b)
    | .float64 a, .float64 b => decide (a = b)
    | .float32 a, .float32 b => decide (a = b)
    | .decimal a s, .decimal b t => decide (a = b ∧ s = t)
    | .boolean a, .boolean b => decide (a = b)
    | .unitValue, .unitValue => true
    | .string a, .string b => decide (a = b)
    | .listValue xs, .listValue ys | .setValue xs, .setValue ys => observationSlotsEq xs ys
    | .bytesValue xs, .bytesValue ys => decide (xs = ys)
    | .mapValue ks vs, .mapValue ls ws => observationSlotsEq ks ls && observationSlotsEq vs ws
    | .dataValue c xs, .dataValue d ys => decide (c = d) && observationSlotsEq xs ys
    | .targetValue a t, .targetValue b u => decide (a = b ∧ t = u)
    | _, _ => false
  private def observationSlotEq : Option Observation → Option Observation → Bool
    | none, none => true
    | some a, some b => observationEq a b
    | _, _ => false
  private def observationSlotsEq : List (Option Observation) → List (Option Observation) → Bool
    | [], [] => true
    | a :: as, b :: bs => observationSlotEq a b && observationSlotsEq as bs
    | _, _ => false
end

mutual
  private theorem observationEq_spec (a b : Observation) : observationEq a b = true ↔ a = b := by
    cases a <;> cases b <;>
      simp [observationEq, observationSlotsEq_spec, Bool.and_eq_true]
  private theorem observationSlotEq_spec (a b : Option Observation) : observationSlotEq a b = true ↔ a = b := by
    cases a <;> cases b <;> simp [observationSlotEq, observationEq_spec]
  private theorem observationSlotsEq_spec (as bs : List (Option Observation)) :
      observationSlotsEq as bs = true ↔ as = bs := by
    cases as <;> cases bs <;> simp [observationSlotsEq, observationSlotEq_spec, observationSlotsEq_spec, Bool.and_eq_true]
end

/-- 閉じた両項の成功した観測を、欠けたスロットも含めて構造で照合する。 -/
def sameClosedObservation (a b : Term) : Bool :=
  decide (a.Closed ∧ b.Closed) &&
    match a.observe (fun _ => none), b.observe (fun _ => none) with
    | some x, some y => observationEq x y
    | _, _ => false

/-- 同じ成功した観測を持つ閉じた二項だけを受ける。 -/
theorem sameClosedObservation_sound {a b : Term} (h : sameClosedObservation a b = true) :
    a.Closed ∧ b.Closed ∧ ∃ o, a.observe (fun _ => none) = some o ∧ b.observe (fun _ => none) = some o := by
  simp only [sameClosedObservation, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨closed, h⟩ := h
  split at h
  · rename_i x y hx hy
    have he := (observationEq_spec x y).mp h
    exact ⟨closed.1, closed.2, x, hx, he ▸ hy⟩
  · cases h

/-- 測度の部分評価が不能でも、同じ閉じた観測の全七測度を結ぶ。 -/
def measuredCandidates (a b : Term) : List Pred :=
  if sameClosedObservation a b then
    measures.map fun m => .eq (.measure m a) (.measure m b)
  else []

/-- 引数は実際の項だけを持ち、規則番号を項として符号化しない。 -/
def candidates (lemma : BuiltinLemma) (arguments : List Term) : List Pred :=
  match lemma, arguments with
  | .measureNonnegative, [t] => measures.map fun m => .le (.integer 0) (.measure m t)
  | .booleanApart, [t] => [false,true].map fun b =>
      .not (.and (.compare .boolean .eq t (.boolean b)) (.compare .boolean .eq t (.boolean (!b))))
  | .compareComplement, [a,b] =>
      (scalarSorts.flatMap fun s =>
        [implies (.not (.compare s .eq a b)) (.compare s .ne a b),
         implies (.compare s .ne a b) (.not (.compare s .eq a b))]) ++
      ([«Sort».character, .decimal].flatMap fun s =>
        [implies (.not (.compare s .lt a b)) (.compare s .ge a b),
         implies (.compare s .ge a b) (.not (.compare s .lt a b)),
         implies (.not (.compare s .le a b)) (.compare s .gt a b),
         implies (.compare s .gt a b) (.not (.compare s .le a b))])
  | .charactersSubset, [a,.character lo,.character hi,.character lo',.character hi'] =>
      if lo'.toNat ≤ lo.toNat ∧ hi.toNat ≤ hi'.toNat then
        [implies (.charactersIn a lo hi) (.charactersIn a lo' hi')] else []
  | .constructorApart, [a,.string c,.string d] =>
      if c ≠ d then [.not (.and (.constructorIs a c) (.constructorIs a d))] else []
  | .sameObservation, [a,b] => if termEq a b then
      sorts.map (fun s => implies (observationAtom s a) (observationAtom s b)) else []
  | .scalarOrder, [a,b,c] =>
      (orderedScalarSorts.flatMap fun s => scalarRules.map (fun r => scalarOrder s r a b c)) ++
      (equalityScalarSorts.flatMap fun s => equalityRules.map (fun r => scalarOrder s r a b c))
  | .characterCodeRange, [t] =>
      let code := .measure .characterCode t
      [.and (.le (.integer 0) code) (.and (.le code (.integer 1114111))
        (.or (.lt code (.integer 55296)) (.lt (.integer 57343) code)))]
  | .characterCompare, [a,b] => comparisons.map (fun o => characterCompare o a b)
  | .floatCompareClass, [a,b] =>
      [FloatWidth.binary32, .binary64].flatMap (fun w => classes.map (fun c => floatClass w c a b))
  | .fieldAtom s cs, args => fieldCandidates s cs args
  | .measured, [a,b] => measuredCandidates a b
  | _, _ => []

end BuiltinSchema
end Benitoite.Release.Refinement
