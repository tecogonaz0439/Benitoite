import Benitoite.Release.Refinement.Surface.Basic
import Benitoite.Release.Refinement.Surface.Typing

/-!
# 篩の中の名前から述語・項への写し

篩の中に書いた判定の関数の呼出しと record の欄の参照を、核の述語 `Pred` と項 `Term` へ写す（設計書
01-12「型の情報を付けた表層の構文と型付け」）。写しの定義域の外の呼出しは篩に書けない（写しが `none` を返し、型検査が拒む）。篩の
束縛名は同じ宣言の引数名と同名にできない。
-/

namespace Benitoite.Release.Refinement.Surface

/-- 篩の束縛名の整形式。束縛名は同じ宣言の引数名のどれとも異なる。 -/
def RefinementBinderOk (binder : String) (names : List String) : Prop := binder ∉ names

instance (binder : String) (names : List String) : Decidable (RefinementBinderOk binder names) :=
  inferInstanceAs (Decidable (binder ∉ names))

/-- Float と Float32 の分類の判定の名前。`isInfinite` は二つの類の和である。 -/
def floatClassesOf : String → Option (List FloatClass)
  | "isNaN" => some [.nan]
  | "isFinite" => some [.finite]
  | "isInfinite" => some [.positiveInfinity, .negativeInfinity]
  | "isPositiveInfinity" => some [.positiveInfinity]
  | "isNegativeInfinity" => some [.negativeInfinity]
  | "isPositiveZero" => some [.positiveZero]
  | "isNegativeZero" => some [.negativeZero]
  | _ => none

def floatWidthOf : String → Option FloatWidth
  | "Float" => some .binary64
  | "Float32" => some .binary32
  | _ => none

/-- 類の列の和。空の列は偽である。 -/
def floatClassAny (w : FloatWidth) (t : Term) : List FloatClass → Pred
  | [] => .falsity
  | [k] => .floatClass w k t
  | k :: ks => .or (.floatClass w k t) (floatClassAny w t ks)

/-- 篩の中の関数の呼出し `module.name(args)` の述語への写し。Float の分類、端がリテラルの
`String.charactersIn`、生成した構成子の判定の関数だけを写す。 -/
def predicateOfCall (D : Declarations) (module name : String) : List Term → Option Pred
  | [t] =>
      match floatWidthOf module, floatClassesOf name with
      | some w, some ks => some (floatClassAny w t ks)
      | _, _ => (D.testers name).map (Pred.constructorIs t)
  | [t, .character lo, .character hi] =>
      if module = "String" ∧ name = "charactersIn" then some (.charactersIn t lo hi) else none
  | _ => none

/-- 篩の中の record の欄の参照 `t.f` の項への写し。公開の射影を欄の観測 `Term.field` として読む。欄の型は
sort を持つ。 -/
def fieldTermOf (D : Declarations) (c : ConName) (f : String) (t : Term) : Option Term :=
  match D.cons c, D.conFields c with
  | some cd, some names =>
      match names.idxOf? f with
      | none => none
      | some k => match cd.args[k]? with
        | none => none
        | some a => a.sort?.map fun s => .field ⟨cd.data, c, k, s⟩ t
  | _, _ => none

/-! ## 例 -/

private def shapeDecls : Declarations where
  funs := fun _ => none
  cons := fun c => if c = "Point" then some ⟨"Pt", 0, [.base .integer, .base .integer]⟩ else
    if c = "Circle" then some ⟨"Shape", 0, [.base .float]⟩ else none
  conFields := fun c => if c = "Point" then some ["x", "y"] else none
  testers := fun f => if f = "isCircle" then some "Circle" else none

example : RefinementBinderOk "r" ["value"] := by decide
example : ¬ RefinementBinderOk "value" ["value"] := by decide
example : predicateOfCall shapeDecls "Float" "isNaN" [.var 0] = some (.floatClass .binary64 .nan (.var 0)) := rfl
example : predicateOfCall shapeDecls "Float32" "isInfinite" [.var 0] =
    some (.or (.floatClass .binary32 .positiveInfinity (.var 0)) (.floatClass .binary32 .negativeInfinity (.var 0))) :=
  rfl
example : predicateOfCall shapeDecls "Shape" "isCircle" [.var 1] = some (.constructorIs (.var 1) "Circle") := rfl
example : predicateOfCall shapeDecls "String" "charactersIn" [.var 0, .character 'a', .character 'z'] =
    some (.charactersIn (.var 0) 'a' 'z') := rfl
example : predicateOfCall shapeDecls "String" "charactersIn" [.var 0, .var 1, .character 'z'] = none := rfl
example : fieldTermOf shapeDecls "Point" "y" (.var 0) = some (.field ⟨"Pt", "Point", 1, .integer⟩ (.var 0)) := rfl

/-- 欄 `high` の篩 `low <= high` は、record 全体の値（番号 0）の二つの欄の観測の関係へ写る。 -/
example : spanRecord.refinement "Span" =
    .and (.le (.field ⟨"Span", "Span", 0, .integer⟩ (.var 0)) (.field ⟨"Span", "Span", 1, .integer⟩ (.var 0)))
      .truth := rfl
example : spanRecord.conDecl = ⟨"Span", 0, [.base .integer, .base .integer]⟩ := rfl
/-- 欄 `high` を取り出す関数の結果は、引数の欄の観測に等しい篩を持つ。全体の篩の事実がこの等号で射影の結果へ流れる。 -/
example : accessorRet "Span" spanRecord.conDecl 1 =
    .refined (.base .integer) (.eq (.var 0) (.field ⟨"Span", "Span", 1, .integer⟩ (.var 1))) := rfl

/-- 欄 `xs: List[Integer]{ys | List.length(ys) = n}` を持つ record。 -/
private def sizedRecord : RecordDecl where
  data := "Sized"
  ntys := 0
  fields := [("n", .base .integer),
    ("xs", .refined (.list (.base .integer)) (.eq (.measure .listLength (.var 0)) (.var 1)))]

/-- List の欄の依存は、record 全体の篩では欄の観測の長さの関係へ写り、取り出しの関数の結果は引数の欄の長さに等しい
長さの篩を持つ。 -/
example : sizedRecord.refinement "Sized" =
    .and (.eq (.measure .listLength (.field ⟨"Sized", "Sized", 1, .list⟩ (.var 0)))
      (.field ⟨"Sized", "Sized", 0, .integer⟩ (.var 0))) .truth := rfl
example : accessorRet "Sized" sizedRecord.conDecl 1 =
    .refined (.list (.base .integer)) (.eq (.measure .listLength (.var 0))
      (.measure .listLength (.field ⟨"Sized", "Sized", 1, .list⟩ (.var 1)))) := rfl

end Benitoite.Release.Refinement.Surface
