import Benitoite.Exchange.CanonicalNames
import Benitoite.Release.Refinement.StandardHeadTailContracts

/-! # 篩の述語の名前の写しの例

処理系が内部名で書き出した `List.tail` の結果型の篩の述語は、同じ入力の宣言から決まる名前の対応で写すと、
標準表の `List.tail` の署名の述語と一致する（設計書 07-04「篩を含む形式化の範囲」）。欄の参照の所属の data の名前も写し、
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

/-! ## JSON の写しに通した署名の一致

名前の写しの全体（`CanonicalNames.json`）と JSON の変換は部分関数なので、等式を定理にできない。小さな交換の値を
既定ビルドの中で評価して確かめる（`#guard`。一致しなければビルドが失敗する）。 -/

/-- 組込みの表の行の形（名前・引数の型・結果型）に置いた署名。名前の写しは表全体と同じ文脈で働く。 -/
def tailRow (params : List Benitoite.Exchange.Ty) (ret : Benitoite.Exchange.Ty) : Lean.Json :=
  Lean.Json.mkObj [("prims", Lean.Json.arr #[Lean.Json.mkObj
    [("name", Lean.toJson "List.tail"), ("params", Lean.toJson params), ("ret", Lean.toJson ret)]])]

/-- 内部名で書き出した `List.tail` の引数の型。 -/
def tailParams : List Benitoite.Exchange.Ty := [.list (.tvar 0)]

/-- 内部名で書き出した `List.tail` の結果型（篩付きの `Option`）。 -/
def internalTailRet : Benitoite.Exchange.Ty :=
  .refined (.data "data:199" [.list (.tvar 0)]) (internalTailPredicate (.var 0) (.var 1))

/-- 標準表の `List.tail` の結果型（`StandardHeadTail.tailSignature` の結果型）を交換の型で書いたもの。 -/
def standardTailRet : Benitoite.Exchange.Ty :=
  .refined (.data "Option" [.list (.tvar 0)]) (StandardHeadTail.tailPredicate (.var 0) (.var 1))

-- 内部名の署名を JSON の写しに通すと、標準の署名の JSON と一致する。
#guard tailNames.json (tailRow tailParams internalTailRet) == tailRow tailParams standardTailRet

-- JSON の写しでも、値としての文字列 `"data:199"` は写さず、同じ述語の欄の参照は写す。
#guard tailNames.json (tailRow [] (.refined (.base "Integer")
    (.eq (.string "data:199") (.field internalSomeField (.var 0))))) ==
  tailRow [] (.refined (.base "Integer") (.eq (.string "data:199") (.field StandardHeadTail.someField (.var 0))))

-- 写す前の内部名の署名は標準の署名と一致しない（上の一致が写しによることの対照）。
#guard !(tailRow tailParams internalTailRet == tailRow tailParams standardTailRet)

end Benitoite.Exchange.CanonicalNamesExamples
