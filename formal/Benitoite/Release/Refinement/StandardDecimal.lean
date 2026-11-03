import Benitoite.Release.Refinement.StandardFloat
import Benitoite.Release.Refinement.KeyContracts

/-! # Decimal の再検査、五つの丸めと正常応答 -/
namespace Benitoite.Release.Refinement.StandardScalar
open Benitoite.Interval

/-- 保存する Decimal の仮数部は 96 bit の大きさ、scale は 28 以下である。 -/
def decimalRepresentable (c : Int) (s : Nat) : Prop :=
  -79228162514264337593543950335 ≤ c ∧ c ≤ 79228162514264337593543950335 ∧ s ≤ 28
instance (c : Int) (s : Nat) : Decidable (decimalRepresentable c s) := inferInstanceAs
  (Decidable (-79228162514264337593543950335 ≤ c ∧ c ≤ 79228162514264337593543950335 ∧ s ≤ 28))

def decimalChecked (c : Int) (s : Nat) : Option (Int × Nat) :=
  if decimalRepresentable c s then some (c,s) else none

theorem decimalChecked_some (c d : Int) (s t : Nat) :
    decimalChecked c s = some (d,t) ↔ c = d ∧ s = t ∧ decimalRepresentable c s := by
  unfold decimalChecked
  split <;> simp_all

def decimalOption : Option (Int × Nat) → Val
  | some (c,s) => .con "Option.Some" [.base .decimal] [.const (.decimal c s)]
  | none => .con "Option.None" [.base .decimal] []

/-- 表現外を Option.None として返す明示変換の出口。 -/
def decimalConversionReply (parsed : Option (Int × Nat)) : Outcome :=
  .val (decimalOption (parsed.bind (fun p => decimalChecked p.1 p.2)))

/-- 丸めの Stop と、変換の正常な None を同じ失敗としない。 -/
def decimalRoundReply (c : Int) (s : Nat) (places : Int) (mode : DecimalRounding) : Outcome :=
  match decimalRound c s places mode with
  | .normal d t => .val (.const (.decimal d t))
  | .invalidPlaces => .err "ArgumentOutOfDomain"
  | .overflow => .err "DecimalOverflow"

/-- 丸めの正常応答は、入力の表現可能性を仮定せず出力を再検査する。 -/
theorem decimalRound_represented (c : Int) (s : Nat) (places : Int) (mode : DecimalRounding)
    (d : Int) (t : Nat) (normal : decimalRound c s places mode = .normal d t) :
    decimalRepresentable d t := by
  let p := places.toNat
  let magnitude := c.natAbs
  let rounded := if s ≤ p then magnitude * 10^(p-s) else
    let divisor := 10^(s-p)
    let quotient := magnitude / divisor
    let remainder := magnitude % divisor
    quotient + if mode.increment (c < 0) quotient remainder divisor then 1 else 0
  change (if places < 0 ∨ 28 < places then DecimalRoundResult.invalidPlaces else
    if rounded ≤ 79228162514264337593543950335 then
      .normal (if c < 0 then -(rounded : Int) else rounded) p else .overflow) = .normal d t at normal
  split at normal
  · cases normal
  · rename_i placesOK
    split at normal
    · rename_i bound
      obtain ⟨hd,ht⟩ := DecimalRoundResult.normal.inj normal
      rw [←hd,←ht]
      unfold decimalRepresentable
      have hp : p ≤ 28 := by dsimp [p]; omega
      split <;> omega
    · cases normal

/-- 同じ正常応答を ConstOK・型付け・観測へ渡す。 -/
theorem decimalRound_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (c : Int) (s : Nat) (places : Int) (mode : DecimalRounding)
    (d : Int) (t : Nat) (normal : decimalRound c s places mode = .normal d t) :
    decimalRoundReply c s places mode = .val (.const (.decimal d t)) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal d t)) (.base .decimal) ∧
    (Val.const (.decimal d t)).toTerm? = some (.decimal d t) ∧
    (Const.decimal d t).NumericRepresented := by
  have represented := decimalRound_represented c s places mode d t normal
  exact ⟨by rw [decimalRoundReply,normal],.V_Const represented,rfl,represented⟩

/-- Decimal の仮数部は、証明書が保存する符号付き128 bit の係数にも収まる。
比較の桁合わせの一時積をこの型に制限しない。 -/
theorem decimal_coefficient128 {c : Int} {s : Nat} (h : decimalRepresentable c s) :
    -(2^127 : Int) ≤ c ∧ c < 2^127 := by
  obtain ⟨lo,hi,_⟩ := h
  change (-170141183460469231731687303715884105728 : Int) ≤ c ∧
    c < 170141183460469231731687303715884105728
  omega

/-- truncate は TowardZero の同じ丸めを行ってから Integer の Option を作る。 -/
def decimalTruncateReply (c : Int) (s : Nat) : Outcome :=
  match decimalRound c s 0 .towardZero with
  | .normal d _ => .val (integerOption .integer64 (integerConvert .integer64 d))
  | .invalidPlaces => .err "ArgumentOutOfDomain"
  | .overflow => .err "DecimalOverflow"

/-- fromDecimal は端数のない値だけを受け、切捨てで受理を増やさない。 -/
def decimalToUnsigned64 (c : Int) (s : Nat) : Option (IntegerValue .unsignedInteger64) :=
  if c.tmod (10^s) = 0 then integerConvert .unsignedInteger64 (c.tdiv (10^s)) else none

theorem decimalToUnsigned64_some (c : Int) (s : Nat) (v : IntegerValue .unsignedInteger64) :
    decimalToUnsigned64 c s = some v ↔ c.tmod (10^s) = 0 ∧ v.toInt = c.tdiv (10^s) := by
  unfold decimalToUnsigned64
  split <;> simp_all [integerConvert_some]

def decimalCompareReply (op : Comparison) (a : Int) (s : Nat) (b : Int) (t : Nat) : Outcome :=
  .val (.const (.boolean ((Observation.decimal a s).compare op (.decimal b t))))

def decimalCompareName : Comparison → PrimName
  | .eq => "%eq" | .ne => "%ne" | .lt => "%Decimal.less" | .le => "%Decimal.lessOrEqual"
  | .gt => "%Decimal.greater" | .ge => "%Decimal.greaterOrEqual"

private def roundingValue : DecimalRounding → Val
  | mode => .con ("RoundingMode." ++ mode.name) [] []
private def roundingRead : Val → Option DecimalRounding
  | .con "RoundingMode.HalfToEven" [] [] => some .halfToEven
  | .con "RoundingMode.HalfAwayFromZero" [] [] => some .halfAwayFromZero
  | .con "RoundingMode.TowardZero" [] [] => some .towardZero
  | .con "RoundingMode.TowardNegativeInfinity" [] [] => some .towardNegativeInfinity
  | .con "RoundingMode.TowardPositiveInfinity" [] [] => some .towardPositiveInfinity
  | _ => none

/-- Decimal の算術の出口を再検査し、実名の標準応答を作る部分表。 -/
private def decimalDeltaAt (name : PrimName) (ws : List Val) : Option Outcome :=
  match name,ws with
  | "Decimal.fromInteger", [.const (.integer n)] => some (.val (.const (.decimal n.toInt 0)))
  | "UnsignedInteger64.toDecimal", [.const (.unsignedInteger64 n)] =>
    if 0 ≤ n ∧ n ≤ 18446744073709551615 then some (.val (.const (.decimal n 0))) else none
  | "UnsignedInteger64.fromDecimal", [.const (.decimal c s)] =>
    if decimalRepresentable c s then some (.val (integerOption .unsignedInteger64 (decimalToUnsigned64 c s))) else none
  | "Decimal.absolute", [.const (.decimal c s)] =>
    if decimalRepresentable c s then some (.val (.const (.decimal c.natAbs s))) else none
  | "Decimal.truncate", [.const (.decimal c s)] =>
    if decimalRepresentable c s then some (decimalTruncateReply c s) else none
  | "Decimal.round", [.const (.decimal c s),.const (.integer places),mode] => do
    if decimalRepresentable c s then
      let m ← roundingRead mode
      return decimalRoundReply c s places.toInt m
    else none
  | "%eq", [.const (.decimal a s),.const (.decimal b t)] =>
    if decimalRepresentable a s ∧ decimalRepresentable b t then some (decimalCompareReply .eq a s b t) else none
  | "%ne", [.const (.decimal a s),.const (.decimal b t)] =>
    if decimalRepresentable a s ∧ decimalRepresentable b t then some (decimalCompareReply .ne a s b t) else none
  | "%Decimal.less", [.const (.decimal a s),.const (.decimal b t)] =>
    if decimalRepresentable a s ∧ decimalRepresentable b t then some (decimalCompareReply .lt a s b t) else none
  | "%Decimal.lessOrEqual", [.const (.decimal a s),.const (.decimal b t)] =>
    if decimalRepresentable a s ∧ decimalRepresentable b t then some (decimalCompareReply .le a s b t) else none
  | "%Decimal.greater", [.const (.decimal a s),.const (.decimal b t)] =>
    if decimalRepresentable a s ∧ decimalRepresentable b t then some (decimalCompareReply .gt a s b t) else none
  | "%Decimal.greaterOrEqual", [.const (.decimal a s),.const (.decimal b t)] =>
    if decimalRepresentable a s ∧ decimalRepresentable b t then some (decimalCompareReply .ge a s b t) else none
  | _,_ => none

/-- 共通の型・行・範囲引数の検査を使う部分表。 -/
def decimalDelta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome := scalarDelta .decimal decimalDeltaAt name ts es rs ws

/-- fromFloat の解析結果を受け、名前・Float 入力・引数列と表現可能性を再検査する。
Float のビット列から表記を作り解析する過程は、この部分表の入力より外にある。 -/
def decimalFromFloatDelta (parsed : Option (Int × Nat)) (name : PrimName)
    (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if scalarArguments .decimal name ts es rs then
    match name,ws with
    | "Decimal.fromFloat", [.const (.float64 _)] => some (decimalConversionReply parsed)
    | _,_ => none
  else none

/-- 同じ Decimal の六比較を実表から Boolean の型付けへ供給する。 -/
theorem decimal_compare_reply (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel)
    (a b : Int) (s t : Nat) (ha : decimalRepresentable a s) (hb : decimalRepresentable b t) (op : Comparison) :
    ∃ value, decimalDelta (decimalCompareName op) (comparisonTypes .decimal op) [] [] [.const (.decimal a s),.const (.decimal b t)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .decimal op (.decimal a s) (.decimal b t)).interpret η = value := by
  refine ⟨(Observation.decimal a s).compare op (.decimal b t),?_,.V_Const trivial,?_⟩
  · cases op <;> simp [decimalDelta,scalarDelta,scalarArguments,scalarTypeCore,comparisonTypes,decimalDeltaAt,decimalCompareName,ha,hb,decimalCompareReply]
  · exact NumericContracts.compare_exact η (t := .decimal a s) (u := .decimal b t) rfl rfl rfl rfl op

/-- 五つの実構成子の選択が、同じ丸めの定義へ届く。 -/
theorem decimalDelta_round (c : Int) (s : Nat) (h : decimalRepresentable c s)
    (places : Benitoite.Release.Integer64Value) (mode : DecimalRounding) :
    decimalDelta "Decimal.round" [] [] [] [.const (.decimal c s),.const (.integer places),roundingValue mode] =
      some (decimalRoundReply c s places.toInt mode) := by
  cases mode <;> simp [decimalDelta,scalarDelta,scalarArguments,decimalDeltaAt,roundingValue,roundingRead,DecimalRounding.name,h]

example (P : Program) (B : Builtins) (Ψ : StoreTy) (c d : Int) (s t : Nat) (places : Int)
    (mode : DecimalRounding) (normal : decimalRound c s places mode = .normal d t) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal d t)) (.base .decimal) :=
  (decimalRound_typed P B Ψ c s places mode d t normal).2.1
example {c : Int} {s : Nat} (h : decimalRepresentable c s) : -(2^127 : Int) ≤ c ∧ c < 2^127 := decimal_coefficient128 h
example (c d : Int) (s t : Nat) :
    decimalChecked c s = some (d,t) ↔ c = d ∧ s = t ∧ decimalRepresentable c s := decimalChecked_some c d s t
example (c : Int) (s : Nat) (v : IntegerValue .unsignedInteger64) :
    decimalToUnsigned64 c s = some v ↔ c.tmod (10^s) = 0 ∧ v.toInt = c.tdiv (10^s) := decimalToUnsigned64_some c s v
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) (a b : Int) (s t : Nat)
    (ha : decimalRepresentable a s) (hb : decimalRepresentable b t) (op : Comparison) :
    ∃ value, decimalDelta (decimalCompareName op) (comparisonTypes .decimal op) [] [] [.const (.decimal a s),.const (.decimal b t)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .decimal op (.decimal a s) (.decimal b t)).interpret η = value :=
  decimal_compare_reply P B Ψ η a b s t ha hb op
example (c : Int) (s : Nat) (h : decimalRepresentable c s) (places : Benitoite.Release.Integer64Value)
    (mode : DecimalRounding) :
    decimalDelta "Decimal.round" [] [] [] [.const (.decimal c s),.const (.integer places),roundingValue mode] =
      some (decimalRoundReply c s places.toInt mode) := decimalDelta_round c s h places mode

/-- 同率の偶数・奇数、余りなし、零の符号を五つのモードで確認する。 -/
example : DecimalRounding.all.map (decimalRound 35 1 0) =
    [.normal 4 0,.normal 4 0,.normal 3 0,.normal 3 0,.normal 4 0] ∧
    DecimalRounding.all.map (decimalRound 20 1 0) = List.replicate 5 (.normal 2 0) ∧
    DecimalRounding.all.map (decimalRound (-1) 1 0) =
      [.normal 0 0,.normal 0 0,.normal 0 0,.normal (-1) 0,.normal 0 0] := by decide

example : DecimalRounding.all.map (decimalRound 79228162514264337593543950335 0 1) =
    List.replicate 5 .overflow ∧
    DecimalRounding.all.map (decimalRound 1 0 (-1)) = List.replicate 5 .invalidPlaces ∧
    DecimalRounding.all.map (decimalRound 1 0 29) = List.replicate 5 .invalidPlaces := by decide

example : decimalRoundReply 79228162514264337593543950335 0 1 .halfToEven = .err "DecimalOverflow" ∧
    decimalConversionReply (some (79228162514264337593543950336,0)) =
      .val (.con "Option.None" [.base .decimal] []) := ⟨rfl,rfl⟩
example : decimalTruncateReply 92233720368547758080 1 =
    .val (.con "Option.None" [.base .integer] []) := by rfl
example : decimalDelta "UnsignedInteger64.fromDecimal" [] [] [] [.const (.decimal 10 1)] =
    some (.val (.con "Option.Some" [.base .unsignedInteger64] [.const (.unsignedInteger64 1)])) ∧
    decimalDelta "UnsignedInteger64.fromDecimal" [] [] [] [.const (.decimal 15 1)] =
    some (.val (.con "Option.None" [.base .unsignedInteger64] [])) := ⟨rfl,rfl⟩
example : comparisons.map ((Observation.decimal 10 1).compare · (.decimal 1 0)) =
    [true,false,false,true,false,true] ∧ (Term.decimal 10 1) ≠ Term.decimal 1 0 := by
  refine ⟨by decide,?_⟩
  intro h
  have := (Term.decimal.inj h).1
  omega


/-- 有効な仮数部の絶対値は同じ対称な型域へ入る。 -/
theorem decimalAbsolute_represented (c : Int) (s : Nat) (h : decimalRepresentable c s) :
    decimalRepresentable (c.natAbs : Int) s := by
  obtain ⟨lo,hi,hs⟩ := h
  cases c <;> simp_all [decimalRepresentable] <;> omega

/-- Integer と u64 の全域の明示変換は scale 0 の同じ数学値を返す。 -/
theorem decimal_integer_conversions (P : Program) (B : Builtins) (Ψ : StoreTy)
    (n : Benitoite.Release.Integer64Value) (u : IntegerValue .unsignedInteger64) :
    (decimalDelta "Decimal.fromInteger" [] [] [] [.const (.integer n)] = some (.val (.const (.decimal n.toInt 0))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal n.toInt 0)) (.base .decimal)) ∧
    (decimalDelta "UnsignedInteger64.toDecimal" [] [] [] [.const (.unsignedInteger64 u.toInt)] =
      some (.val (.const (.decimal u.toInt 0))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal u.toInt 0)) (.base .decimal)) := by
  have hn := n.toInt_bounds
  have hu := u.toInt_bounds
  refine ⟨⟨rfl,.V_Const ?_⟩,⟨?_,.V_Const ?_⟩⟩
  · change -79228162514264337593543950335 ≤ n.toInt ∧ n.toInt ≤ 79228162514264337593543950335 ∧ 0 ≤ 28
    simp only [Benitoite.Release.min64,Benitoite.Release.max64] at hn
    omega
  · simp [decimalDelta,scalarDelta,scalarArguments,decimalDeltaAt,hu]
  · change -79228162514264337593543950335 ≤ u.toInt ∧ u.toInt ≤ 79228162514264337593543950335 ∧ 0 ≤ 28
    change 0 ≤ u.toInt ∧ u.toInt ≤ 18446744073709551615 at hu
    omega

/-- fromDecimal の成功値は、scale を戻すと入力の同じ数になる。 -/
theorem decimalToUnsigned64_exact (c : Int) (s : Nat) (v : IntegerValue .unsignedInteger64)
    (h : decimalToUnsigned64 c s = some v) : c = v.toInt * 10^s := by
  obtain ⟨remainder,number⟩ := (decimalToUnsigned64_some c s v).mp h
  rw [number]
  exact (Int.tdiv_mul_cancel_of_tmod_eq_zero remainder).symm

/-- truncate の TowardZero は型域内で正常に丸め、Integer の変換の None と区別する。 -/
theorem decimalTruncate_round (c : Int) (s : Nat) (h : decimalRepresentable c s) :
    ∃ d, decimalRound c s 0 .towardZero = .normal d 0 ∧
      decimalTruncateReply c s = .val (integerOption .integer64 (integerConvert .integer64 d)) := by
  have bound : c.natAbs ≤ 79228162514264337593543950335 := by
    obtain ⟨lo,hi,_⟩ := h
    cases c <;> simp_all <;> omega
  by_cases hz : s = 0
  · subst s
    refine ⟨if c < 0 then -(c.natAbs : Int) else c.natAbs,?_,?_⟩
    · simp [decimalRound,bound]
    · simp [decimalTruncateReply,decimalRound,bound]
  · have divbound := Nat.le_trans (Nat.div_le_self c.natAbs (10^s)) bound
    refine ⟨if c < 0 then -((c.natAbs / 10^s : Nat) : Int) else (c.natAbs / 10^s : Nat),?_,?_⟩
    · simp [decimalRound,hz,DecimalRounding.increment,divbound]
    · simp [decimalTruncateReply,decimalRound,hz,DecimalRounding.increment,divbound]

example (c : Int) (s : Nat) (h : decimalRepresentable c s) :
    decimalRepresentable (c.natAbs : Int) s := decimalAbsolute_represented c s h
example (P : Program) (B : Builtins) (Ψ : StoreTy) (n : Benitoite.Release.Integer64Value)
    (u : IntegerValue .unsignedInteger64) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal u.toInt 0)) (.base .decimal) :=
  (decimal_integer_conversions P B Ψ n u).2.2
example (c : Int) (s : Nat) (v : IntegerValue .unsignedInteger64) (h : decimalToUnsigned64 c s = some v) :
    c = v.toInt * 10^s := decimalToUnsigned64_exact c s v h
example (c : Int) (s : Nat) (h : decimalRepresentable c s) :
    ∃ d, decimalRound c s 0 .towardZero = .normal d 0 ∧
      decimalTruncateReply c s = .val (integerOption .integer64 (integerConvert .integer64 d)) :=
  decimalTruncate_round c s h


theorem decimalToUnsigned64_none (c : Int) (s : Nat) :
    decimalToUnsigned64 c s = none ↔ c.tmod (10^s) ≠ 0 ∨
      c.tdiv (10^s) < 0 ∨ 18446744073709551615 < c.tdiv (10^s) := by
  unfold decimalToUnsigned64
  by_cases h : c.tmod (10^s) = 0
  · simp only [h,ite_true,ne_eq,not_true_eq_false,false_or]
    exact integerConvert_none _ _
  · simp [h]

/-- absolute は同じ scale と数学上の絶対値を保って正常に返す。 -/
theorem decimalAbsolute_reply (P : Program) (B : Builtins) (Ψ : StoreTy)
    (c : Int) (s : Nat) (h : decimalRepresentable c s) :
    decimalDelta "Decimal.absolute" [] [] [] [.const (.decimal c s)] = some (.val (.const (.decimal c.natAbs s))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal c.natAbs s)) (.base .decimal) :=
  ⟨by simp [decimalDelta,scalarDelta,scalarArguments,decimalDeltaAt,h],.V_Const (decimalAbsolute_represented c s h)⟩

example (c : Int) (s : Nat) :
    decimalToUnsigned64 c s = none ↔ c.tmod (10^s) ≠ 0 ∨
      c.tdiv (10^s) < 0 ∨ 18446744073709551615 < c.tdiv (10^s) := decimalToUnsigned64_none c s
example (P : Program) (B : Builtins) (Ψ : StoreTy) (c : Int) (s : Nat) (h : decimalRepresentable c s) :
    decimalDelta "Decimal.absolute" [] [] [] [.const (.decimal c s)] = some (.val (.const (.decimal c.natAbs s))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.decimal c.natAbs s)) (.base .decimal) := decimalAbsolute_reply P B Ψ c s h

/-- 型域を満たす Decimal の Some と、正常な None を型付ける。 -/
theorem decimalOption_typed (P : Program) (B : Builtins) (Ψ : StoreTy) (v : Option (Int × Nat))
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1)
    (represented : ∀ c s, v = some (c,s) → decimalRepresentable c s) :
    HasTypeVQ P B Ψ Qempty [] [] [] (decimalOption v) (.data "Option" [.base .decimal]) := by
  cases v with
  | none =>
    exact scalarOption_typed (α := Unit) P B Ψ .decimal (fun _ => .const (.decimal 0 0)) none
      someDecl noneDecl arity (fun _ => .V_Const (by change decimalRepresentable 0 0; decide))
  | some p =>
    exact scalarOption_typed (α := Unit) P B Ψ .decimal (fun _ => .const (.decimal p.1 p.2)) (some ())
      someDecl noneDecl arity (fun _ => .V_Const (represented p.1 p.2 rfl))

/-- 再検査した解析結果の Some/None は、同じ Option[Decimal] の正常応答である。 -/
theorem decimalConversionReply_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (parsed : Option (Int × Nat))
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, decimalConversionReply parsed = .val v ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [.base .decimal]) := by
  refine ⟨_,rfl,decimalOption_typed P B Ψ _ someDecl noneDecl arity ?_⟩
  intro c s h
  obtain ⟨p,_,hp⟩ := Option.bind_eq_some_iff.mp h
  obtain ⟨hc,hs,hr⟩ := (decimalChecked_some p.1 c p.2 s).mp hp
  exact hc ▸ hs ▸ hr

/-- 名前付きの fromFloat の行は、同じ解析結果の再検査と型付き正常応答へ届く。 -/
theorem decimalFromFloat_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (bits : UInt64) (parsed : Option (Int × Nat))
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, decimalFromFloatDelta parsed "Decimal.fromFloat" [] [] [] [.const (.float64 bits)] = some (.val v) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [.base .decimal]) := by
  obtain ⟨v,hv,ht⟩ := decimalConversionReply_typed P B Ψ parsed someDecl noneDecl arity
  exact ⟨v,congrArg some hv,ht⟩

/-- truncate の正常な丸めの後で、Some と None の両方を Integer の Option で型付ける。 -/
theorem decimalTruncate_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (c : Int) (s : Nat) (h : decimalRepresentable c s)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, decimalDelta "Decimal.truncate" [] [] [] [.const (.decimal c s)] = some (.val v) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [.base .integer]) := by
  obtain ⟨d,_,hd⟩ := decimalTruncate_round c s h
  refine ⟨integerOption .integer64 (integerConvert .integer64 d),?_,
    integerOption_typed P B Ψ .integer64 (integerConvert .integer64 d) someDecl noneDecl arity⟩
  simpa [decimalDelta,scalarDelta,scalarArguments,decimalDeltaAt,h] using congrArg some hd

/-- fromDecimal の整数性の検査の失敗も、型付きの正常な None である。 -/
theorem decimalToUnsigned64_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (c : Int) (s : Nat) (h : decimalRepresentable c s)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1) :
    ∃ v, decimalDelta "UnsignedInteger64.fromDecimal" [] [] [] [.const (.decimal c s)] = some (.val v) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] v (.data "Option" [.base .unsignedInteger64]) :=
  ⟨_,by simp [decimalDelta,scalarDelta,scalarArguments,decimalDeltaAt,h],
    integerOption_typed P B Ψ .unsignedInteger64 (decimalToUnsigned64 c s) someDecl noneDecl arity⟩

example : decimalFromFloatDelta (some (15,1)) "Decimal.fromFloat" [] [] [] [.const (.float64 0x3ff8000000000000)] =
    some (.val (.con "Option.Some" [.base .decimal] [.const (.decimal 15 1)])) ∧
    decimalFromFloatDelta none "Decimal.fromFloat" [] [] [] [.const (.float64 0x7ff8000000000000)] =
      some (.val (.con "Option.None" [.base .decimal] [])) ∧
    decimalFromFloatDelta (some (79228162514264337593543950336,0)) "Decimal.fromFloat" [] [] []
      [.const (.float64 0)] = some (.val (.con "Option.None" [.base .decimal] [])) := ⟨rfl,rfl,rfl⟩

end Benitoite.Release.Refinement.StandardScalar
