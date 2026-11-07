import Benitoite.Release.Refinement.Surface.Desugar
import Benitoite.Release.Refinement.TypeShiftExchange
import Benitoite.Release.Refinement.Capture

/-! # 元の値の解析が返す構文の形 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 元のvalueOf?が直接返す値は、局所参照・定数・空の構成子である。 -/
inductive SimpleValue : Val → Prop
  | var (index) : SimpleValue (.var index)
  | constant (value) : SimpleValue (.const value)
  | con (name types) : SimpleValue (.con name types [])

/-- 元の値の解析から、閉包本体を含まない構文の証拠を得る。 -/
theorem SimpleValue.of_valueOf {expression : Expr} {value} (found : expression.valueOf? = some value) : SimpleValue value := by
  cases expression <;> cases found <;> first | exact .var _ | exact .constant _ | exact .con _ _

/-- 改名は、この元の値の構文の形を保つ。 -/
theorem SimpleValue.rename {value} (simple : SimpleValue value) (rename : Nat → Nat) : SimpleValue (value.rename rename) := by
  cases simple <;> first | exact .var _ | exact .constant _ | exact .con _ _

/-- 型具体化は、この元の値の構文の形を保つ。 -/
theorem SimpleValue.substTy {value} (simple : SimpleValue value) (index : Nat) (types : List Ty) (effects : List Eff) :
    SimpleValue (value.substTyAt index types effects) := by
  cases simple <;> first | exact .var _ | exact .constant _ | exact .con _ _

/-- 範囲具体化は、この元の値の構文の形を保つ。 -/
theorem SimpleValue.mapRanges {value} (simple : SimpleValue value) (ranges : Nat → RangeIx) :
    SimpleValue (value.mapRangesN ranges) := by
  cases simple <;> first | exact .var _ | exact .constant _ | exact .con _ _

/-- 型変数の追加は、この元の値の構文の形を保つ。 -/
theorem SimpleValue.shiftE {value} (simple : SimpleValue value) (count cutoff : Nat) :
    SimpleValue (value.shiftEAt count cutoff) := by
  cases simple <;> first | exact .var _ | exact .constant _ | exact .con _ _

/-- 同じ形の値の置換像を使うと、元の値の構文の形を保つ。 -/
theorem SimpleValue.subst {value} (simple : SimpleValue value) (images : Nat → Val) (locals : Nat → LocalRef)
    (closed : ∀ index, SimpleValue (images index)) : SimpleValue (value.subst images locals) := by
  cases simple with
  | var index => exact closed index
  | constant value => exact .constant _
  | con name types => exact .con _ _

/-- 束縛を越えた置換像も、局所参照と同じ形の値である。 -/
theorem simple_upSubst {images : Nat → Val} (simple : ∀ index, SimpleValue (images index)) (count index : Nat) :
    SimpleValue (upSubst count images index) := by
  unfold upSubst
  split
  · exact .var _
  · exact (simple _).rename _

/-- builderの実規則が使う置換像は、Unit又は局所参照である。 -/
theorem simple_builder_substitution (index : Nat) : SimpleValue (builderValueSubst index) := by
  cases index <;> first | exact .constant _ | exact .var _

/-- ソース順の全引数が、元の値の解析で得られる形である。 -/
def SimpleValues (values : List Val) : Prop := ∀ value ∈ values, SimpleValue value

private theorem simple_cons {value values} : SimpleValues (value :: values) ↔ SimpleValue value ∧ SimpleValues values := by
  simp only [SimpleValues, List.mem_cons, forall_eq_or_imp]

/-- 全引数の改名は、元の値の構文の形を保つ。 -/
theorem SimpleValues.rename {values} (simple : SimpleValues values) (rename : Nat → Nat) :
    SimpleValues (Val.renameList rename values) := by
  induction values with
  | nil => exact simple
  | cons value values ih =>
    obtain ⟨head, tail⟩ := simple_cons.mp simple
    exact simple_cons.mpr ⟨head.rename rename, ih tail⟩

/-- 全引数の型具体化は、元の値の構文の形を保つ。 -/
theorem SimpleValues.substTy {values} (simple : SimpleValues values) (index : Nat) (types : List Ty) (effects : List Eff) :
    SimpleValues (Val.substTyAtList index types effects values) := by
  induction values with
  | nil => exact simple
  | cons value values ih =>
    obtain ⟨head, tail⟩ := simple_cons.mp simple
    exact simple_cons.mpr ⟨head.substTy index types effects, ih tail⟩

/-- 全引数の範囲具体化は、元の値の構文の形を保つ。 -/
theorem SimpleValues.mapRanges {values} (simple : SimpleValues values) (ranges : Nat → RangeIx) :
    SimpleValues (Val.mapRangesListN ranges values) := by
  induction values with
  | nil => exact simple
  | cons value values ih =>
    obtain ⟨head, tail⟩ := simple_cons.mp simple
    exact simple_cons.mpr ⟨head.mapRanges ranges, ih tail⟩

/-- 全引数への型変数の追加は、元の値の構文の形を保つ。 -/
theorem SimpleValues.shiftE {values} (simple : SimpleValues values) (count cutoff : Nat) :
    SimpleValues (Val.shiftEListAt count cutoff values) := by
  induction values with
  | nil => exact simple
  | cons value values ih =>
    obtain ⟨head, tail⟩ := simple_cons.mp simple
    exact simple_cons.mpr ⟨head.shiftE count cutoff, ih tail⟩

/-- 全引数の値置換は、同じ形の置換像を使うと元の構文の形を保つ。 -/
theorem SimpleValues.subst {values} (simple : SimpleValues values) (images : Nat → Val) (locals : Nat → LocalRef)
    (closed : ∀ index, SimpleValue (images index)) : SimpleValues (Val.substList images values locals) := by
  induction values with
  | nil => exact simple
  | cons value values ih =>
    obtain ⟨head, tail⟩ := simple_cons.mp simple
    exact simple_cons.mpr ⟨head.subst images locals closed, ih tail⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
