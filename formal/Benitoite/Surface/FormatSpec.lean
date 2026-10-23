import Benitoite.Release.Syntax

/-! 解析済みの補間書式と、書式化の内部頭の契約。
設計書 01-12「文字列補間」の独立した定義であり、文字列の解析と書式化の算法は含まない。
-/
namespace Benitoite.Surface
open Benitoite.Release

/-- 種類の省略は、型ごとの既存の表記を使う。 -/
inductive FormatKind where
  | default | d | b | o | x | upperX | f | s | c
  deriving DecidableEq, Repr

/-- 寄せの省略は、数なら右、それ以外なら左と解釈する。 -/
inductive FormatAlign where
  | default | left | right | center
  deriving DecidableEq, Repr

/-- 明示できる符号指定は + だけである。 -/
inductive FormatSign where
  | default | plus
  deriving DecidableEq, Repr

/-- 元の字面と位置は持たず、幅・精度の省略と明示を区別する。 -/
structure FormatSpec where
  kind : FormatKind := .default
  align : FormatAlign := .default
  sign : FormatSign := .default
  alternate : Bool := false
  zero : Bool := false
  width : Option Nat := none
  precision : Option Nat := none
  deriving DecidableEq, Repr

namespace FormatSpec

/-- 型とは独立した、空指定・範囲・併用の条件。字句の検査はこの定義の前に行う。 -/
def SyntaxValid (s : FormatSpec) : Prop :=
  s ≠ {} ∧
  (match s.width with | none => True | some w => 1 ≤ w ∧ w ≤ 65535) ∧
  (match s.precision with | none => True | some p => p ≤ 28 ∧ s.kind = .f) ∧
  (s.align ≠ .default → s.width.isSome = true) ∧
  (s.zero = true → s.width.isSome = true ∧ s.align = .default) ∧
  (s.alternate = true → s.kind = .b ∨ s.kind = .o ∨ s.kind = .x ∨ s.kind = .upperX)

instance (s : FormatSpec) : Decidable s.SyntaxValid := by
  unfold SyntaxValid
  cases s.width <;> cases s.precision <;> infer_instance

/-- Byte を含む八つの整数型。別名の正規化は入力側で行う。 -/
def IntegerType : Ty → Prop
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .byte | .base .unsignedInteger16 | .base .unsignedInteger32
  | .base .unsignedInteger64 => True
  | _ => False

/-- f が使える三型。整数からの暗黙の変換は行わない。 -/
def FractionalType : Ty → Prop
  | .base .float | .base .float32 | .base .decimal => True
  | _ => False

/-- 書式付き補間に許す閉じた14型。 -/
def SupportedType : Ty → Prop
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .byte | .base .unsignedInteger16 | .base .unsignedInteger32
  | .base .unsignedInteger64 | .base .float | .base .float32 | .base .decimal
  | .base .string | .base .character | .base .boolean => True
  | _ => False

instance (t : Ty) : Decidable (IntegerType t) := by
  cases t <;> simp only [IntegerType] <;> try infer_instance
  rename_i b; cases b <;> infer_instance
instance (t : Ty) : Decidable (FractionalType t) := by
  cases t <;> simp only [FractionalType] <;> try infer_instance
  rename_i b; cases b <;> infer_instance
instance (t : Ty) : Decidable (SupportedType t) := by
  cases t <;> simp only [SupportedType] <;> try infer_instance
  rename_i b; cases b <;> infer_instance

/-- 種類による型の制限と、符号・ゼロ埋めを数に限る条件。 -/
def Compatible (t : Ty) (s : FormatSpec) : Prop :=
  SupportedType t ∧
  (match s.kind with
   | .default => True
   | .d | .b | .o | .x | .upperX => IntegerType t
   | .f => FractionalType t
   | .s => match t with | .base .string => True | _ => False
   | .c => match t with | .base .character => True | _ => False) ∧
  ((s.sign = .plus ∨ s.zero = true) → IntegerType t ∨ FractionalType t)

instance (t : Ty) (s : FormatSpec) : Decidable (Compatible t s) := by
  unfold Compatible
  cases s.kind <;> cases t <;> simp only <;> try infer_instance
  all_goals rename_i b; cases b <;> infer_instance

/-- 表層の型付けと検査が共通に使う書式の条件。 -/
def Valid (t : Ty) (s : FormatSpec) : Prop := s.SyntaxValid ∧ s.Compatible t

/-- 定数引数の符号化。種類の省略を0として残す。 -/
def kindCode : FormatKind → Integer64Value
  | .default => ⟨0, by decide⟩
  | .d => ⟨1, by decide⟩
  | .b => ⟨2, by decide⟩
  | .o => ⟨3, by decide⟩
  | .x => ⟨4, by decide⟩
  | .upperX => ⟨5, by decide⟩
  | .f => ⟨6, by decide⟩
  | .s => ⟨7, by decide⟩
  | .c => ⟨8, by decide⟩

/-- 寄せは省略0・左1・右2・中央3で表す。 -/
def alignCode : FormatAlign → Integer64Value
  | .default => ⟨0, by decide⟩
  | .left => ⟨1, by decide⟩
  | .right => ⟨2, by decide⟩
  | .center => ⟨3, by decide⟩

/-- 符号は省略0・+を1で表す。 -/
def signCode : FormatSign → Integer64Value
  | .default => ⟨0, by decide⟩
  | .plus => ⟨1, by decide⟩

/-- 妥当性からIntegerの範囲を導き、幅の省略は0で表す。 -/
def widthCode (s : FormatSpec) (h : s.SyntaxValid) : Integer64Value :=
  ⟨Int.ofNat (s.width.getD 0), by
    have hw := h.2.1
    cases he : s.width with
    | none => simp [min64, max64]
    | some w => simp only [he] at hw; simp [min64, max64]; omega⟩

/-- 精度の省略は-1で表し、型別の既定値へ置き換えない。 -/
def precisionCode (s : FormatSpec) (h : s.SyntaxValid) : Integer64Value :=
  ⟨match s.precision with | none => -1 | some p => Int.ofNat p, by
    have hp := h.2.2.1
    cases he : s.precision with
    | none => simp [min64, max64]
    | some p => simp only [he] at hp; simp [min64, max64]; omega⟩

/-- valueの後へ渡す七定数。型の検査とは別に、構文の妥当性の証拠を要する。 -/
def constants (s : FormatSpec) (h : s.SyntaxValid) : List Const :=
  [.integer (kindCode s.kind), .integer (alignCode s.align), .integer (signCode s.sign),
   .boolean s.alternate, .boolean s.zero, .integer (s.widthCode h), .integer (s.precisionCode h)]

/-- 定数列の型と引数名は、全入力型で同じである。 -/
def constantTypes : List Ty :=
  [.base .integer, .base .integer, .base .integer, .base .boolean, .base .boolean,
   .base .integer, .base .integer]

/-- valueと七定数の契約名。型ごとの公開toStringの引数名とは区別する。 -/
def parameterNames : List String :=
  ["value", "kind", "align", "sign", "alternate", "zero", "width", "precision"]

/-- 書式化の内部頭に求める純粋な固定シグネチャ。直接の頭であることは利用側で検査する。 -/
def converterType (t : Ty) : Ty :=
  .fn parameterNames (t :: constantTypes) (.base .string) Eff.empty

theorem constants_types (s : FormatSpec) (h : s.SyntaxValid) :
    (s.constants h).map Const.type = constantTypes := rfl

theorem parameterNames_wf (t : Ty) : NamesWF parameterNames (t :: constantTypes) := by
  simp [NamesWF, parameterNames, constantTypes]

/-- 未対応型には内部頭を割り当てず、Stringにも専用の書式化の内部頭を持つ。 -/
def headName : Ty → Option PrimName
  | .base .integer => some "%Format.Integer"
  | .base .integer8 => some "%Format.Integer8"
  | .base .integer16 => some "%Format.Integer16"
  | .base .integer32 => some "%Format.Integer32"
  | .base .byte => some "%Format.Byte"
  | .base .unsignedInteger16 => some "%Format.UnsignedInteger16"
  | .base .unsignedInteger32 => some "%Format.UnsignedInteger32"
  | .base .unsignedInteger64 => some "%Format.UnsignedInteger64"
  | .base .float => some "%Format.Float"
  | .base .float32 => some "%Format.Float32"
  | .base .decimal => some "%Format.Decimal"
  | .base .string => some "%Format.String"
  | .base .character => some "%Format.Character"
  | .base .boolean => some "%Format.Boolean"
  | _ => none

theorem headName_supported (t : Ty) : (headName t).isSome = true ↔ SupportedType t := by
  cases t <;> simp only [headName, SupportedType, Option.isSome_none, Bool.false_eq_true,
    iff_self]
  rename_i b; cases b <;> decide

/-- fの精度省略はFloat系で6、Decimalでは入力値のscaleを使う。
符号化はこの解釈と分け、交換と脱糖には省略を残す。 -/
def fixedPrecision (s : FormatSpec) (t : Ty) (decimalScale : Nat) : Option Nat :=
  match s.kind, t with
  | .f, .base .float | .f, .base .float32 => some (s.precision.getD 6)
  | .f, .base .decimal => some (s.precision.getD decimalScale)
  | _, _ => none

end FormatSpec
end Benitoite.Surface
