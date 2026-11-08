import Benitoite.Exchange.CanonicalNames
import Benitoite.Release.Refinement.StandardHeadTailContracts

/-! # 篩の述語の名前の写しの例

処理系が内部名で書き出した `List.tail` の結果型の篩の述語は、同じ入力の宣言から決まる名前の対応で写すと、
標準表の `List.tail` の署名の述語と一致する（設計書 07-04「証明する性質」）。欄の参照の所属の data の名前も写し、
値としての文字列は写さない。 -/
namespace Benitoite.Exchange.CanonicalNamesExamples
open Benitoite.Release.Refinement

/-- `Option` を内部名 `data:199`、構成子を `ctor:Some`・`ctor:None` で書き出した入力から決まる対応。 -/
def tailNames : CanonicalNames :=
  { dataNames := [("data:199", "Option")]
    constructorNames := [("ctor:None", "Option.None"), ("ctor:Some", "Option.Some")] }

/-- 内部名で書いた `Some` の欄の参照。 -/
def internalSomeField : FieldRef := ⟨"data:199", "ctor:Some", 0, .list⟩

/-- 内部名で書いた `List.tail` の結果型の篩の述語（標準表の `StandardHeadTail.tailPredicate` と同じ形）。 -/
def internalTailPredicate (result xs : Term) : Pred :=
  .and (.or (.not (.constructorIs result "ctor:None")) (.eq (.measure .listLength xs) (.integer 0)))
    (.or (.not (.constructorIs result "ctor:Some"))
      (.eq (.measure .listLength (.field internalSomeField result))
        (.add (.measure .listLength xs) (.integer (-1)))))

/-- 欄の参照は、所属の data と構成子の両方を標準の名前へ写す。 -/
theorem internalSomeField_renamed : tailNames.fieldRef internalSomeField = StandardHeadTail.someField := rfl

/-- 内部名の `List.tail` の篩の述語は、写すと標準表の `List.tail` の署名の述語に一致する。 -/
theorem tail_predicate_renamed :
    tailNames.pred (internalTailPredicate (.var 0) (.var 1)) = StandardHeadTail.tailPredicate (.var 0) (.var 1) :=
  rfl

/-- 値としての文字列は、data の内部名と同じ綴りでも写さない。 -/
theorem string_value_kept :
    tailNames.pred (.eq (.string "data:199") (.field internalSomeField (.var 0))) =
      .eq (.string "data:199") (.field StandardHeadTail.someField (.var 0)) :=
  rfl

end Benitoite.Exchange.CanonicalNamesExamples
