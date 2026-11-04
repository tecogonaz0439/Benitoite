import Benitoite.Release.Refinement.StandardOperatorArguments
import Benitoite.Release.Refinement.StandardDecimal

/-! # Decimalの係数・scale・丸めと算術の応答 -/
namespace Benitoite.Release.Refinement.StandardDecimalOperatorResponse
noncomputable section
open StandardScalar

inductive API where
  | add | subtract | multiply | divide | negate
  deriving DecidableEq
def API.suffix : API → String
  | .add => ".add" | .subtract => ".subtract" | .multiply => ".multiply"
  | .divide => ".divide" | .negate => ".negate"
def name (api : API) : String := "%Decimal" ++ api.suffix
def signature (api : API) : PrimSig :=
  StandardOperatorArguments.signature .decimal .decimal (api=.negate)

abbrev DecimalValue := {p : Int × Nat // decimalRepresentable p.1 p.2}
def limit : Nat := 79228162514264337593543950335

/-- crates/benitoite/src/base/decimal.rs のWideの256 bitの検査。
    正確な一時計算をNatで行い、Rustと同じ箇所で上限を検査する。 -/
def wide (n : Nat) : Option Nat := if n < 2^256 then some n else none

/-- 同ファイルのmake。符号付き128 bitの保存と96 bit/scaleの不変条件を検査する。 -/
def make (magnitude scale : Nat) (negative : Bool) : Option DecimalValue := do
  if magnitude > limit then none else
    let c ← CoefficientModel.save CoefficientModel.storageBits
      (if negative then -(magnitude : Int) else magnitude)
    if h : decimalRepresentable c scale then some ⟨(c,scale),h⟩ else none

/-- 同ファイルのround_magnitudeのHalfToEven。余りとdivisor−余りを比較する。 -/
def roundMagnitude (q r d : Nat) : Option Nat :=
  if r=0 then some q else
    if r>d then none else
      if r>d-r ∨ (r=d-r ∧ q%2≠0) then wide (q+1) else some q

private def fitAt (magnitude original : Nat) (negative : Bool) : List Nat → Option DecimalValue
  | [] => none
  | scale::rest => do
    let divisor ← wide (10^(original-scale))
    if divisor=0 then none else
      let rounded ← roundMagnitude (magnitude/divisor) (magnitude%divisor) divisor
      if rounded ≤ limit then make rounded scale negative else fitAt magnitude original negative rest

/-- 同ファイルのfit。scaleを降順にし、候補ごとに元の係数から丸め直す。 -/
def fit (magnitude original : Nat) (negative : Bool) : Option DecimalValue :=
  fitAt magnitude original negative ((List.range (min original 28+1)).reverse)

/-- 同ファイルのchecked_divの0..=28のループ。打切り時に最後の候補を返し、
    桁を追加する計算のoverflowは、その候補へ戻さず失敗にする。 -/
def divDigits : Nat → Nat → Nat → Nat → Nat → Nat → Bool → Option DecimalValue → Option DecimalValue
  | 0,_,_,_,_,_,_,rounded => rounded
  | fuel+1,scale,q,r,d,minimum,negative,rounded =>
    if q>limit then rounded else
      if r=0 ∧ scale≥minimum then make q scale negative else do
        let candidate ← roundMagnitude q r d
        let next ← if candidate≤limit then (make candidate scale negative).map some else some rounded
        let expanded ← wide (r*10)
        if d=0 then none else
          let times ← wide (q*10)
          let quotient ← wide (times+expanded/d)
          divDigits fuel (scale+1) quotient (expanded%d) d minimum negative next

/-- 同ファイルのchecked_div。符号・桁合わせ・最小scaleを同じ入力から計算する。 -/
def divide (a : Int) (s : Nat) (b : Int) (t : Nat) : Option DecimalValue := do
  let numerator ← wide (a.natAbs * 10^(t-s))
  let denominator ← wide (b.natAbs * 10^(s-t))
  if denominator=0 then none else
    divDigits 29 0 (numerator/denominator) (numerator%denominator) denominator
      (s-t) (decide (a<0) != decide (b<0)) none

/-- 同ファイルのadd_signed/checked_mul/negate。
    加減の桁合わせと一時積はCoefficientModelの正確な積を使い、保存幅から分ける。 -/
def calculate (api : API) (a : Int) (s : Nat) (b : Int) (t : Nat) : Option DecimalValue :=
  match api with
  | .negate => make a.natAbs s (decide (0<a))
  | .divide => divide a s b t
  | .multiply => do
    let magnitude ← wide (CoefficientModel.temporaryProduct a b).natAbs
    fit magnitude (s+t) (decide (a<0) != decide (b<0))
  | .add | .subtract => do
    let scale := max s t
    let left ← wide (a.natAbs * 10^(scale-s))
    let right ← wide (b.natAbs * 10^(scale-t))
    let negativeLeft := decide (a<0)
    let negativeRight := decide (b<0) != (api=.subtract)
    if negativeLeft=negativeRight then
      let magnitude ← wide (left+right)
      fit magnitude scale negativeLeft
    else if left≥right then fit (left-right) scale negativeLeft
    else fit (right-left) scale negativeRight

def outcome : Option DecimalValue → Outcome
  | none => .err "DecimalOverflow"
  | some p => .val (.const (.decimal p.val.1 p.val.2))

/-- crates/benitoite/src/builtins/funcs/operators.rs のdecimal_*とdecimal_error。
    0除算を先に区別し、それ以外の算法の失敗をDecimalOverflowへ写す。 -/
def reply (api : API) (a : Int) (s : Nat) (b : Int) (t : Nat) : Outcome :=
  if api=.divide ∧ b=0 then .err "DivisionByZero" else outcome (calculate api a s b t)

def delta (api : API) (b : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b=name api ∧ ts=[] ∧ es=[] ∧ rs=[] then
    match api,ws with
    | .negate,[.const (.decimal a s)] => some (reply api a s 0 0)
    | .negate,_ => none
    | _,[.const (.decimal a s),.const (.decimal b t)] => some (reply api a s b t)
    | _,_ => none
  else none

private theorem shape {P B Ψ v}
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.base .decimal)) :
    ∃ c s, v=.const (.decimal c s) ∧ decimalRepresentable c s := by
  obtain ⟨c,rfl,hc,tag⟩ := typed.canonical_scalar rfl
  cases c <;> cases tag
  exact ⟨_,_,rfl,hc⟩

private theorem outcome_safe {P B Ψ} (value : Option DecimalValue) (ws : List Val) :
    Outcome.Typed P B Ψ (outcome value) (.base .decimal) ∧
      AdequateResult ws (outcome value) ∧ (∀ i, outcome value≠.exit i) := by
  cases value with
  | none => exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp [outcome]⟩
  | some p => exact ⟨⟨.V_Const p.property,trivial⟩,by intro σ _ _; trivial,by intro i; simp [outcome]⟩

private theorem reply_safe {P B Ψ} (api : API) (a : Int) (s : Nat) (b : Int) (t : Nat) (ws : List Val) :
    Outcome.Typed P B Ψ (reply api a s b t) (.base .decimal) ∧
      AdequateResult ws (reply api a s b t) ∧ (∀ i, reply api a s b t≠.exit i) := by
  unfold reply
  split
  · exact ⟨trivial,by intro σ _ _; trivial,by intro i; simp⟩
  · exact outcome_safe _ ws

theorem response {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ (name api) (signature api) ts es rs ws a e) :
    ∃ out, delta api (name api) ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ :=
    StandardOperatorArguments.arguments .decimal .decimal (api=.negate) args
  by_cases unary : api=.negate
  · simp only [unary] at values
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,s,rfl,_⟩ := shape typed
      exact ⟨reply api c s 0 0,by simp [delta,unary],reply_safe api c s 0 0 _⟩
  · simp only [unary] at values
    cases values with | cons left rest => cases rest with | cons right rest =>
      cases rest
      obtain ⟨c,s,rfl,_⟩ := shape left
      obtain ⟨d,t,rfl,_⟩ := shape right
      refine ⟨reply api c s d t,?_,reply_safe api c s d t _⟩
      cases api <;> simp_all [delta]

end
end Benitoite.Release.Refinement.StandardDecimalOperatorResponse
