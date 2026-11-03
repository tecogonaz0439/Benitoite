import Benitoite.Release.Refinement.StandardByteCharacter
import Benitoite.Release.Refinement.ScalarLogic

/-! # Float 二幅の実ビット列、分類と比較の応答 -/
namespace Benitoite.Release.Refinement.StandardScalar

def floatClasses : List FloatClass :=
  [.finite,.nan,.positiveInfinity,.negativeInfinity,.positiveZero,.negativeZero]
def comparisons : List Comparison := [.eq,.ne,.lt,.le,.gt,.ge]

/-- Float32 の分類を、保持するビット列のまま読む。公開 API を追加しない。 -/
def float32ClassReply (c : FloatClass) (bits : UInt32) : Outcome :=
  .val (.const (.boolean (ieeeClass 23 8 bits.toNat c)))

def float32CompareReply (op : Comparison) (a b : UInt32) : Outcome :=
  .val (.const (.boolean (ieeeCompare 23 8 a.toNat b.toNat op)))

def float32CompareName : Comparison → PrimName
  | .eq => "%eq" | .ne => "%ne" | .lt => "%Float32.less" | .le => "%Float32.lessOrEqual"
  | .gt => "%Float32.greater" | .ge => "%Float32.greaterOrEqual"

/-- 実ライブラリの isNaN/isInfinite と比較だけを受ける部分表。 -/
private def float32DeltaAt (name : PrimName) (ws : List Val) : Option Outcome :=
  match name,ws with
  | "Float32.isNaN", [.const (.float32 bits)] => some (float32ClassReply .nan bits)
  | "Float32.isInfinite", [.const (.float32 bits)] => some (.val (.const (.boolean
      (ieeeClass 23 8 bits.toNat .positiveInfinity || ieeeClass 23 8 bits.toNat .negativeInfinity))))
  | "%eq", [.const (.float32 a),.const (.float32 b)] => some (float32CompareReply .eq a b)
  | "%ne", [.const (.float32 a),.const (.float32 b)] => some (float32CompareReply .ne a b)
  | "%Float32.less", [.const (.float32 a),.const (.float32 b)] => some (float32CompareReply .lt a b)
  | "%Float32.lessOrEqual", [.const (.float32 a),.const (.float32 b)] => some (float32CompareReply .le a b)
  | "%Float32.greater", [.const (.float32 a),.const (.float32 b)] => some (float32CompareReply .gt a b)
  | "%Float32.greaterOrEqual", [.const (.float32 a),.const (.float32 b)] => some (float32CompareReply .ge a b)
  | _,_ => none

/-- 共通の型・行・範囲引数の検査を使う部分表。 -/
def float32Delta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome := scalarDelta .float32 float32DeltaAt name ts es rs ws

/-- 六分類の同じ Boolean を、型付き応答と有限述語へ渡す。 -/
theorem float32_class_reply (P : Program) (B : Builtins) (Ψ : StoreTy)
    (η : ObservationEnvModel) (bits : UInt32) (c : FloatClass) :
    ∃ value, float32ClassReply c bits = .val (.const (.boolean value)) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.floatClass .binary32 c (.float32 bits)).interpret η = value :=
  ⟨_,rfl,.V_Const trivial,(NumericContracts.float_class_exact η (.float32 bits) c).1 bits rfl⟩

/-- 同じ実名の比較応答は、NaN と符号付き零を含む有限述語と一致する。 -/
theorem float32_compare_reply (P : Program) (B : Builtins) (Ψ : StoreTy)
    (η : ObservationEnvModel) (a b : UInt32) (op : Comparison) :
    ∃ value, float32Delta (float32CompareName op) (comparisonTypes .float32 op) [] [] [.const (.float32 a),.const (.float32 b)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .float32 op (.float32 a) (.float32 b)).interpret η = value := by
  refine ⟨ieeeCompare 23 8 a.toNat b.toNat op,?_,.V_Const trivial,?_⟩
  · cases op <;> rfl
  · exact NumericContracts.compare_exact η (t := .float32 a) (u := .float32 b) rfl rfl rfl rfl op

example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) (bits : UInt32) (c : FloatClass) :
    ∃ value, float32ClassReply c bits = .val (.const (.boolean value)) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.floatClass .binary32 c (.float32 bits)).interpret η = value := float32_class_reply P B Ψ η bits c
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) (a b : UInt32) (op : Comparison) :
    ∃ value, float32Delta (float32CompareName op) (comparisonTypes .float32 op) [] [] [.const (.float32 a),.const (.float32 b)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .float32 op (.float32 a) (.float32 b)).interpret η = value := float32_compare_reply P B Ψ η a b op

/-- finite は零も含む。分類の六行を排他的な六分割とは扱わない。 -/
example : ([1065353216,2143289344,2139095040,4286578688,0,2147483648] : List UInt32).map
    (fun bits => floatClasses.map (ieeeClass 23 8 bits.toNat)) =
    [[true,false,false,false,false,false],[false,true,false,false,false,false],
     [false,false,true,false,false,false],[false,false,false,true,false,false],
     [true,false,false,false,true,false],[true,false,false,false,false,true]] := by decide

/-- 数の等号では ±0 は等しいが、ビットを保持する構文の等号では異なる。 -/
example : ieeeCompare 23 8 0 2147483648 .eq = true ∧
    (Term.float32 0) ≠ Term.float32 2147483648 := by
  refine ⟨by decide,?_⟩
  intro h
  exact (by decide : (0 : UInt32) ≠ 2147483648) (Term.float32.inj h)
/-- 同じ NaN の構文は自分自身と等しく、数の等号では偽になる。 -/
example : (Term.float32 2143289344) = Term.float32 2143289344 ∧
    ieeeCompare 23 8 2143289344 2143289344 .eq = false := ⟨rfl,by decide⟩

example : comparisons.map (ieeeCompare 23 8 2143289344 1065353216) = [false,true,false,false,false,false] ∧
    comparisons.map (ieeeCompare 23 8 0 2147483648) = [true,false,false,true,false,true] ∧
    comparisons.map (ieeeCompare 23 8 4286578688 2139095040) = [false,true,true,true,false,false] := by decide

/-- Float の分類を、保持するビット列のまま読む。公開 API を追加しない。 -/
def float64ClassReply (c : FloatClass) (bits : UInt64) : Outcome :=
  .val (.const (.boolean (ieeeClass 52 11 bits.toNat c)))

def float64CompareReply (op : Comparison) (a b : UInt64) : Outcome :=
  .val (.const (.boolean (ieeeCompare 52 11 a.toNat b.toNat op)))

def float64CompareName : Comparison → PrimName
  | .eq => "%eq" | .ne => "%ne" | .lt => "%Float.less" | .le => "%Float.lessOrEqual"
  | .gt => "%Float.greater" | .ge => "%Float.greaterOrEqual"

/-- 実ライブラリの isNaN と比較だけを受ける部分表。 -/
private def float64DeltaAt (name : PrimName) (ws : List Val) : Option Outcome :=
  match name,ws with
  | "Float.isNaN", [.const (.float64 bits)] => some (float64ClassReply .nan bits)
  | "%eq", [.const (.float64 a),.const (.float64 b)] => some (float64CompareReply .eq a b)
  | "%ne", [.const (.float64 a),.const (.float64 b)] => some (float64CompareReply .ne a b)
  | "%Float.less", [.const (.float64 a),.const (.float64 b)] => some (float64CompareReply .lt a b)
  | "%Float.lessOrEqual", [.const (.float64 a),.const (.float64 b)] => some (float64CompareReply .le a b)
  | "%Float.greater", [.const (.float64 a),.const (.float64 b)] => some (float64CompareReply .gt a b)
  | "%Float.greaterOrEqual", [.const (.float64 a),.const (.float64 b)] => some (float64CompareReply .ge a b)
  | _,_ => none

/-- 共通の型・行・範囲引数の検査を使う部分表。 -/
def float64Delta (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr)
    (ws : List Val) : Option Outcome := scalarDelta .float float64DeltaAt name ts es rs ws

/-- 六分類の同じ Boolean を、型付き応答と有限述語へ渡す。 -/
theorem float64_class_reply (P : Program) (B : Builtins) (Ψ : StoreTy)
    (η : ObservationEnvModel) (bits : UInt64) (c : FloatClass) :
    ∃ value, float64ClassReply c bits = .val (.const (.boolean value)) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.floatClass .binary64 c (.float64 bits)).interpret η = value :=
  ⟨_,rfl,.V_Const trivial,(NumericContracts.float_class_exact η (.float64 bits) c).2 bits rfl⟩

/-- 同じ実名の比較応答は、NaN と符号付き零を含む有限述語と一致する。 -/
theorem float64_compare_reply (P : Program) (B : Builtins) (Ψ : StoreTy)
    (η : ObservationEnvModel) (a b : UInt64) (op : Comparison) :
    ∃ value, float64Delta (float64CompareName op) (comparisonTypes .float op) [] [] [.const (.float64 a),.const (.float64 b)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .float64 op (.float64 a) (.float64 b)).interpret η = value := by
  refine ⟨ieeeCompare 52 11 a.toNat b.toNat op,?_,.V_Const trivial,?_⟩
  · cases op <;> rfl
  · exact NumericContracts.compare_exact η (t := .float64 a) (u := .float64 b) rfl rfl rfl rfl op

example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) (bits : UInt64) (c : FloatClass) :
    ∃ value, float64ClassReply c bits = .val (.const (.boolean value)) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.floatClass .binary64 c (.float64 bits)).interpret η = value := float64_class_reply P B Ψ η bits c
example (P : Program) (B : Builtins) (Ψ : StoreTy) (η : ObservationEnvModel) (a b : UInt64) (op : Comparison) :
    ∃ value, float64Delta (float64CompareName op) (comparisonTypes .float op) [] [] [.const (.float64 a),.const (.float64 b)] =
        some (.val (.const (.boolean value))) ∧
      HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean value)) (.base .boolean) ∧
      (Pred.compare .float64 op (.float64 a) (.float64 b)).interpret η = value := float64_compare_reply P B Ψ η a b op

/-- finite は零も含む。分類の六行を排他的な六分割とは扱わない。 -/
example : ([4607182418800017408,9221120237041090560,9218868437227405312,18442240474082181120,0,9223372036854775808] : List UInt64).map
    (fun bits => floatClasses.map (ieeeClass 52 11 bits.toNat)) =
    [[true,false,false,false,false,false],[false,true,false,false,false,false],
     [false,false,true,false,false,false],[false,false,false,true,false,false],
     [true,false,false,false,true,false],[true,false,false,false,false,true]] := by decide

/-- 数の等号では ±0 は等しいが、ビットを保持する構文の等号では異なる。 -/
example : ieeeCompare 52 11 0 9223372036854775808 .eq = true ∧
    (Term.float64 0) ≠ Term.float64 9223372036854775808 := by
  refine ⟨by decide,?_⟩
  intro h
  exact (by decide : (0 : UInt64) ≠ 9223372036854775808) (Term.float64.inj h)
/-- 同じ NaN の構文は自分自身と等しく、数の等号では偽になる。 -/
example : (Term.float64 9221120237041090560) = Term.float64 9221120237041090560 ∧
    ieeeCompare 52 11 9221120237041090560 9221120237041090560 .eq = false := ⟨rfl,by decide⟩

example : comparisons.map (ieeeCompare 52 11 9221120237041090560 4607182418800017408) = [false,true,false,false,false,false] ∧
    comparisons.map (ieeeCompare 52 11 0 9223372036854775808) = [true,false,false,true,false,true] ∧
    comparisons.map (ieeeCompare 52 11 18442240474082181120 9218868437227405312) = [false,true,true,true,false,false] := by decide


example : float32Delta "Float32.isInfinite" [] [] [] [.const (.float32 0xff800000)] =
    some (.val (.const (.boolean true))) ∧
    float32Delta "Float32.isInfinite" [] [] [] [.const (.float32 0x7fc00000)] =
      some (.val (.const (.boolean false))) ∧
    float64Delta "Float.isNaN" [] [] [] [.const (.float64 0x7ff8000000000000)] =
      some (.val (.const (.boolean true))) := ⟨rfl,rfl,rfl⟩

end Benitoite.Release.Refinement.StandardScalar
