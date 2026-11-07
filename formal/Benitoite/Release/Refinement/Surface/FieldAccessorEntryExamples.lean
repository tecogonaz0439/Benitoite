import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckMaterialsSound

/-! # 証明書なしの取り出しの関数の呼出しの実入口

欄の関係で篩った結果型を持つ取り出しの関数を、期待型のない位置と条件の位置で呼ぶ。
入力は交換の証明書を持たない。結果型の篩が束縛した実引数を指すとき、外側の型はその篩を除く。
-/
namespace Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples
open CheckTables
noncomputable section

private def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => False,
    refGet := "get", refSet := "set" }

private inductive Payload where
  | integer | string | float | decimal | data

private def payloadType : Payload → Ty
  | .integer => .base .integer | .string => .base .string | .float => .base .float
  | .decimal => .base .decimal
  | .data => .data "Color" []

/-- 取り出しの関数の呼出し。受け手は関数の引数である。 -/
private def getter : Expr := .call (.funName "Box.value" [] []) [some "value"] [0] (.cons (.local 0) .nil)

/-- 取り出した値を期待型のない位置で評価して捨てる。 -/
private def discarded : Def where
  tparams := []
  neffs := 0
  names := ["record"]
  params := [.data "Box" []]
  ret := .base .unit
  eff := .empty
  body := .lastDiscard getter

/-- 取り出した値を条件の判定の実引数に渡す。 -/
private def tested : Def where
  tparams := []
  neffs := 0
  names := ["record"]
  params := [.data "Box" []]
  ret := .base .unit
  eff := .empty
  body := .last (.ite (.call (.funName "accepts" [] []) [some "value"] [0] (.cons getter .nil)) .empty .empty)

private def accepts (a : Ty) : Def where
  tparams := []
  neffs := 0
  names := ["value"]
  params := [a]
  ret := .base .boolean
  eff := .empty
  body := .last (.literal (.boolean true))

private def colors : List (ConName × ConDecl) :=
  [("Color.Red", ⟨"Color", 0, []⟩), ("Color.Blue", ⟨"Color", 0, []⟩)]

private def materials (x : Payload) : Materials where
  defs := [("discarded", discarded), ("tested", tested), ("accepts", accepts (payloadType x))]
  cons := ("Box", ⟨"Box", 0, [payloadType x]⟩) :: (match x with | .data => colors | _ => [])
  conFields := [("Box", ["value"])]
  accessors := [("Box.value", ("Box", 0))]

private def baseInput : Check.Input where
  D := { funs := fun _ => none, cons := fun _ => none }
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  proofSteps := 100

private def acceptInput : CheckAccept.AcceptInput :=
  { ok := "Ok", rules := fun _ => none, limits := ⟨⟨100,100⟩,⟨100,100⟩⟩, methodKey := fun i m => i ++ "." ++ m }

private def Checked (x : Payload) : Prop :=
  checkProgram ((materials x).input baseInput) (materials x).program = .ok () ∧
  CheckAccept.checkProgramAccepted ((materials x).input baseInput) acceptInput (materials x).program = .ok ()

/-- 整数の欄の取り出しを、証明書なしで二つの位置に書ける。 -/
theorem integer_accessor_checked : Checked .integer := by cbv

/-- String の欄の取り出しを、証明書なしで二つの位置に書ける。 -/
theorem string_accessor_checked : Checked .string := by cbv

/-- Float の欄の取り出しを、証明書なしで二つの位置に書ける。 -/
theorem float_accessor_checked : Checked .float := by cbv

/-- Decimal の欄の取り出しを、証明書なしで二つの位置に書ける。 -/
theorem decimal_accessor_checked : Checked .decimal := by cbv

/-- 構成子の関係で篩う data の欄の取り出しを、証明書なしで二つの位置に書ける。 -/
theorem data_accessor_checked : Checked .data := by cbv

/-- 欄について何も知らない値の取り出しは、文字集合の契約を証明書なしに満たさない。 -/
private def promised : Def where
  tparams := []
  neffs := 0
  names := ["record"]
  params := [.data "Box" []]
  ret := .refined (.base .string) (.charactersIn (.var 0) 'a' 'z')
  eff := .empty
  body := .last getter

private def promisedMaterials : Materials where
  defs := [("promised", promised)]
  cons := [("Box", ⟨"Box", 0, [.base .string]⟩)]
  conFields := [("Box", ["value"])]
  accessors := [("Box.value", ("Box", 0))]

/-- 外側の型で除いた篩は、元の篩の結論を超える契約の根拠にならない。 -/
theorem unproved_contract_rejected :
    (checkProgram (promisedMaterials.input baseInput) promisedMaterials.program).toBool = false := by cbv

/-- 条件の実引数の位置で、文字集合の事実を要求する引数型へ取り出しの結果を渡す。 -/
private def demandingMaterials : Materials :=
  { materials .string with
    defs := [("tested", tested), ("accepts", accepts (.refined (.base .string) (.charactersIn (.var 0) 'a' 'z')))] }

/-- 外側の型で除いた篩は、条件の実引数の位置でも、元の篩の結論を超える引数の契約の根拠にならない。 -/
theorem unproved_argument_rejected :
    (checkProgram (demandingMaterials.input baseInput) demandingMaterials.program).toBool = false := by cbv

end
end Benitoite.Release.Refinement.Surface.FieldAccessorEntryExamples
