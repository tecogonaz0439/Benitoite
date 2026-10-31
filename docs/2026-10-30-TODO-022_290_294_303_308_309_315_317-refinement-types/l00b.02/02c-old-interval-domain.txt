import Benitoite.Release.Syntax

/-!
# 七種の整数の閉区間の領域

正常値の集合だけを表し、失敗可能性とは分ける。有限の端点とその値域の証拠を
保持し、型や部分型を増やさない（設計書 01-12「整数の閉区間の領域」）。
-/
namespace Benitoite.Interval

open Benitoite.Release (min64 max64)

/-- 算術を持つ整数の七種。Integer は integer64 の別名であり、Byte は含まない。 -/
inductive IntKind where
  | integer8 | integer16 | integer32 | integer64
  | unsignedInteger16 | unsignedInteger32 | unsignedInteger64
  deriving DecidableEq, Repr

/-- 型ごとの有限の下限。ホストの整数幅を使わない。 -/
abbrev IntKind.min : IntKind → Int
  | .integer8 => -128
  | .integer16 => -32768
  | .integer32 => -2147483648
  | .integer64 => min64
  | .unsignedInteger16 | .unsignedInteger32 | .unsignedInteger64 => 0

/-- 型ごとの有限の上限。最大u64も数学上のIntで表す。 -/
abbrev IntKind.max : IntKind → Int
  | .integer8 => 127
  | .integer16 => 32767
  | .integer32 => 2147483647
  | .integer64 => max64
  | .unsignedInteger16 => 65535
  | .unsignedInteger32 => 4294967295
  | .unsignedInteger64 => 18446744073709551615

/-- 七種すべての値域は非空である。 -/
theorem IntKind.bounds (kind : IntKind) : kind.min ≤ kind.max := by
  cases kind <;> decide

/-- 整数の別名は解決済みの型で同じinteger64に対応する。 -/
def IntKind.type : IntKind → Benitoite.Release.Ty
  | .integer8 => .base .integer8
  | .integer16 => .base .integer16
  | .integer32 => .base .integer32
  | .integer64 => .base .integer
  | .unsignedInteger16 => .base .unsignedInteger16
  | .unsignedInteger32 => .base .unsignedInteger32
  | .unsignedInteger64 => .base .unsignedInteger64

/-- 七種だけを認定し、Byteと整数以外の型を除外する。 -/
def IntKind.ofType : Benitoite.Release.Ty → Option IntKind
  | .base .integer8 => some .integer8
  | .base .integer16 => some .integer16
  | .base .integer32 => some .integer32
  | .base .integer => some .integer64
  | .base .unsignedInteger16 => some .unsignedInteger16
  | .base .unsignedInteger32 => some .unsignedInteger32
  | .base .unsignedInteger64 => some .unsignedInteger64
  | _ => none

@[simp] theorem IntKind.ofType_type (kind : IntKind) : ofType kind.type = some kind := by
  cases kind <;> rfl

/-- 対象構文の評価関係の整数は、型の値域内の値とその証拠を持つ。 -/
abbrev IntegerValue (kind : IntKind) := { n : Int // kind.min ≤ n ∧ n ≤ kind.max }

/-- 区間の計算には数学上のIntへの射影を使う。 -/
def IntegerValue.toInt {kind : IntKind} (value : IntegerValue kind) : Int := value.val

/-- 各幅の整数の射影は、その幅の値域内にある。 -/
theorem IntegerValue.toInt_bounds {kind : IntKind} (value : IntegerValue kind) :
    kind.min ≤ value.toInt ∧ value.toInt ≤ kind.max := value.property

/-- 空集合、または指定した整数型の値域内の非空の閉区間。 -/
inductive Interval (kind : IntKind := .integer64) where
  | bottom
  | closed (lo hi : Int) (valid : kind.min ≤ lo ∧ lo ≤ hi ∧ hi ≤ kind.max)
  deriving DecidableEq, Repr

variable {kind : IntKind}

/-- 閉区間への所属。Bottom には値が属さない。 -/
def Mem (value : Int) : Interval kind → Prop
  | .bottom => False
  | .closed lo hi _ => lo ≤ value ∧ value ≤ hi

instance (value : Int) (i : Interval kind) : Decidable (Mem value i) := by
  cases i <;> unfold Mem <;> infer_instance

/-- 値域との交差を取り、空なら Bottom に正規化する。 -/
def normalize (lo hi : Int) (kind : IntKind := .integer64) : Interval kind :=
  let lower := max kind.min lo
  let upper := min kind.max hi
  if h : lower ≤ upper then
    .closed lower upper ⟨Int.le_max_left _ _, h, Int.min_le_left _ _⟩
  else .bottom

/-- 未知の正常値を表す指定した整数型の全値域。 -/
def top (kind : IntKind := .integer64) : Interval kind :=
  .closed kind.min kind.max ⟨Int.le_refl _, kind.bounds, Int.le_refl _⟩

/-- 包含は空集合の特例と二つの端点の比較で判定する。 -/
def Subset : Interval kind → Interval kind → Prop
  | .bottom, _ => True
  | .closed _ _ _, .bottom => False
  | .closed lo hi _, .closed lo' hi' _ => lo' ≤ lo ∧ hi ≤ hi'

instance (a b : Interval kind) : Decidable (Subset a b) := by
  cases a <;> cases b <;> unfold Subset <;> infer_instance

/-- 二つの正常値集合の交差。 -/
def meet : Interval kind → Interval kind → Interval kind
  | .bottom, _ | _, .bottom => .bottom
  | .closed lo hi _, .closed lo' hi' _ => normalize (max lo lo') (min hi hi') kind

/-- 両方の正常値集合を含む最小の閉区間。区間の間の穴は失う。 -/
def join : Interval kind → Interval kind → Interval kind
  | .bottom, b => b
  | a, .bottom => a
  | .closed lo hi _, .closed lo' hi' _ => normalize (min lo lo') (max hi hi') kind

/-- 正規化は入力区間と指定した整数型の値域との交差を正確に表す。 -/
theorem mem_normalize (value lo hi : Int) (kind : IntKind := .integer64) :
    Mem value (normalize lo hi kind) ↔
      kind.min ≤ value ∧ value ≤ kind.max ∧ lo ≤ value ∧ value ≤ hi := by
  unfold normalize
  dsimp only
  split
  · simp only [Mem, Int.max_le, Int.le_min]
    constructor <;> intro h <;> omega
  · simp only [Mem, false_iff]
    intro h
    rename_i empty
    apply empty
    simp only [Int.le_min, Int.max_le]
    omega

/-- どの区間に所属する値も指定した整数型で表現できる。 -/
theorem mem_bounds {value : Int} {i : Interval kind} (h : Mem value i) :
    kind.min ≤ value ∧ value ≤ kind.max := by
  cases i with
  | bottom => exact False.elim h
  | closed lo hi valid => simp only [Mem] at h; omega

/-- すでに値域内にある非空区間の正規化は端点を変えない。 -/
theorem normalize_closed (lo hi : Int) (valid : kind.min ≤ lo ∧ lo ≤ hi ∧ hi ≤ kind.max) :
    normalize lo hi kind = .closed lo hi valid := by
  simp only [normalize, Int.max_eq_right valid.1, Int.min_eq_right valid.2.2,
    dite_eq_left valid.2.1]

/-- Top への所属は指定した整数型の表現可能性と同値である。 -/
theorem mem_top (value : Int) (kind : IntKind := .integer64) :
    Mem value (top kind) ↔ kind.min ≤ value ∧ value ≤ kind.max := Iff.rfl

/-- 包含の端点判定と、値集合としての包含は一致する。 -/
theorem subset_iff (a b : Interval kind) :
    Subset a b ↔ ∀ value, Mem value a → Mem value b := by
  cases a with
  | bottom => simp [Subset, Mem]
  | closed lo hi valid =>
    cases b with
    | bottom =>
      simp only [Subset, Mem]
      constructor
      · intro h; contradiction
      · intro h
        have := h lo ⟨Int.le_refl _, valid.2.1⟩
        contradiction
    | closed lo' hi' valid' =>
      simp only [Subset, Mem]
      constructor
      · intro h value hv; omega
      · intro h
        have hl := h lo ⟨Int.le_refl _, valid.2.1⟩
        have hh := h hi ⟨valid.2.1, Int.le_refl _⟩
        omega

/-- 交差への所属は両方の区間への所属と同値である。 -/
theorem mem_meet (value : Int) (a b : Interval kind) :
    Mem value (meet a b) ↔ Mem value a ∧ Mem value b := by
  cases a with
  | bottom => simp [meet, Mem]
  | closed lo hi valid =>
    cases b with
    | bottom => simp [meet, Mem]
    | closed lo' hi' valid' =>
      rw [meet, mem_normalize _ _ _ kind]
      simp only [Mem, Int.max_le, Int.le_min]
      omega

/-- 合流はどちらかの区間に所属する値を失わない。 -/
theorem mem_join {value : Int} {a b : Interval kind}
    (h : Mem value a ∨ Mem value b) : Mem value (join a b) := by
  cases a with
  | bottom => simpa [join, Mem] using h
  | closed lo hi valid =>
    cases b with
    | bottom => simpa [join, Mem] using h
    | closed lo' hi' valid' =>
      rw [join, mem_normalize _ _ _ kind]
      simp only [Mem] at h
      omega

/-- 合流は両方を包含する閉区間のうち最小である。 -/
theorem join_least {a b c : Interval kind} (ha : Subset a c) (hb : Subset b c) :
    Subset (join a b) c := by
  cases a with
  | bottom => simpa [join] using hb
  | closed lo hi valid =>
    cases b with
    | bottom => simpa [join] using ha
    | closed lo' hi' valid' =>
      cases c with
      | bottom => exact False.elim ha
      | closed lc hc vc =>
        simp only [Subset] at ha hb
        apply (subset_iff _ _).mpr
        intro value hv
        rw [join, mem_normalize _ _ _ kind] at hv
        simp only [Mem]
        omega

/-- 交差は値域を保つ。 -/
theorem meet_bounds {value : Int} {a b : Interval kind} (h : Mem value (meet a b)) :
    kind.min ≤ value ∧ value ≤ kind.max := mem_bounds h

/-- 合流は値域を保つ。 -/
theorem join_bounds {value : Int} {a b : Interval kind} (h : Mem value (join a b)) :
    kind.min ≤ value ∧ value ≤ kind.max := mem_bounds h

-- 独立した十進の端点で、七種のTopが過大にも過小にもならないことを確かめる。
-- Byteは型の認定の対象外とし、Integerの別名に別の種類を作らない。
example :
    ([ (IntKind.integer8, -128, 127), (.integer16, -32768, 32767),
       (.integer32, -2147483648, 2147483647),
       (.integer64, -9223372036854775808, 9223372036854775807),
       (.unsignedInteger16, 0, 65535), (.unsignedInteger32, 0, 4294967295),
       (.unsignedInteger64, 0, 18446744073709551615) ] : List (IntKind × Int × Int)).all
      (fun (kind, lo, hi) => decide (
        Mem lo (top kind) ∧ Mem hi (top kind) ∧
        ¬ Mem (lo - 1) (top kind) ∧ ¬ Mem (hi + 1) (top kind) ∧
        normalize (lo - 1) (hi + 1) kind = top kind ∧
        normalize (lo - 2) (lo - 1) kind = .bottom ∧
        normalize (hi + 1) (hi + 2) kind = .bottom)) = true ∧
    IntKind.ofType (.base .byte) = none ∧
    IntKind.ofType (.base .integer) = some .integer64 := by decide +kernel

-- 独立期待値で、空・一点・両端・凸な合流による穴の消失を確かめる。
example : normalize 2 1 = .bottom ∧ meet (normalize (-2) (-1)) (normalize 1 2) =
    .bottom := by decide

example : Mem 7 (normalize 7 7) ∧ ¬ Mem 6 (normalize 7 7) ∧
    ¬ Mem 8 (normalize 7 7) := by decide

example : meet (normalize (-2) 0) (normalize 0 3) = normalize 0 0 ∧
    Subset (normalize 0 0) (normalize (-2) 3) ∧
    ¬ Subset (normalize (-2) 3) (normalize 0 0) ∧ Subset .bottom top := by decide

example : Mem min64 top ∧ Mem max64 top ∧
    normalize (min64 - 1) (max64 + 1) = top ∧
    normalize (max64 + 1) (max64 + 2) = .bottom ∧
    normalize (min64 - 2) (min64 - 1) = .bottom := by decide

example : join (normalize (-2) (-1)) (normalize 1 2) = normalize (-2) 2 ∧
    Mem 0 (join (normalize (-2) (-1)) (normalize 1 2)) ∧
    ¬ Mem 0 (normalize (-2) (-1)) ∧ ¬ Mem 0 (normalize 1 2) := by decide

end Benitoite.Interval
