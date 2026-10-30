import Benitoite.Release.Syntax
import Benitoite.Scope.Signature

/- 現行ソースから必要な枝を独立に縮小した写し。
   Release/Syntax.lean の Val.checkedRequest（req:Val）、
   Typing.lean:581-591、ModelHttp.lean:56-57,83-96,188-190。
   既存oleanのVal.checkedRequest/valContentが旧形だったため、本番Val/Builtinsを使わない。
   型・Const・Target・Rangeの既存のデータ型だけを再利用する。
   型引数のないClientRequestの例に必要な構築・List・Bytesの枝を残す。
   本番の全HasTypeVやCoreAssumptionsの再構成ではない。 -/
namespace P3bRequest
open Benitoite.Release
open Benitoite.Scope.Domain (Target Range Kind)
set_option maxHeartbeats 200000

inductive Value where
  | const (c : Const)
  | con (name : String) (args : List Value)
  | list (args : List Value)
  | bytes (args : List Nat)
  | checked (t : Target)
  | checkedRequest (t : Target) (req : Value)

structure BuiltinFields where
  valKind : String → Option Kind
  valContent : String → Option Ty

mutual
  inductive Typed (B : BuiltinFields) : Value → Ty → Prop where
    | constant {c} : Typed B (.const c) c.type
    | request {method url headers body timeout} :
        Typed B method (.base .string) → Typed B url (.base .string) →
        Typed B headers (.list (.data "Pair" [.base .string, .base .string])) →
        Typed B body .bytes → Typed B timeout (.base .integer) →
        Typed B (.con "Http.ClientRequest" [method,url,headers,body,timeout]) (.data "Http.ClientRequest" [])
    | list {vs a} : AllTyped B vs a → Typed B (.list vs) (.list a)
    | bytes {bs} : Typed B (.bytes bs) .bytes
    | checked {o R t} : B.valKind o = some t.kind → R.Mem t →
        Typed B (.checked t) (.opaque o (.fixed R))
    | checkedRequest {o R t req T} :
        B.valKind o = some t.kind → R.Mem t → B.valContent o = some T →
        Typed B req T → Typed B (.checkedRequest t req) (.opaque o (.fixed R))
  inductive AllTyped (B : BuiltinFields) : List Value → Ty → Prop where
    | nil {a} : AllTyped B [] a
    | cons {v vs a} : Typed B v a → AllTyped B vs a → AllTyped B (v::vs) a
end

def target? : Value → Option Target
  | .checked t | .checkedRequest t _ => some t
  | _ => none

def fields : BuiltinFields where
  valKind o := if o = "Http.RequestIn" then some .endpoint else none
  valContent o := if o = "Http.RequestIn" then some (.data "Http.ClientRequest" []) else none

def api : Target := .endpoint ⟨.name ["api", "example", "com"], 443⟩
def defaultTimeout : Integer64Value := ⟨30000, by decide⟩
def defaultRequest : Value := .con "Http.ClientRequest"
  [.const (.string ""), .const (.string ""), .list [], .bytes [], .const (.integer defaultTimeout)]

def requestUrl : Value → Option String
  | .con "Http.ClientRequest" [_, .const (.string u), _, _, _] => some u
  | _ => none
def reqTarget (v : Value) : Option Target := (requestUrl v).bind
  (fun u => if u = "https://api.example.com/" then some api else none)

-- groundVal/型引数の検査はこの閉じた具体例ではtrue。要求を持たない枝だけを読む。
def projection : List Value → Value
  | [.checkedRequest _ req] => req
  | _ => defaultRequest

theorem default_typed : Typed fields defaultRequest (.data "Http.ClientRequest" []) :=
  .request .constant .constant (.list .nil) .bytes .constant

theorem typed_without_request : Typed fields (.checked api) (.opaque "Http.RequestIn" (.fixed .top)) := by
  apply Typed.checked
  · rfl
  · trivial

theorem typed_mismatched_request :
    Typed fields (.checkedRequest api defaultRequest) (.opaque "Http.RequestIn" (.fixed .top)) ∧
    reqTarget defaultRequest = none ∧ target? (.checkedRequest api defaultRequest) = some api := by
  refine ⟨Typed.checkedRequest rfl trivial rfl default_typed, ?_, rfl⟩
  simp [reqTarget, requestUrl, defaultRequest]

theorem old_fallback : projection [.checked api] = defaultRequest := rfl

def shapeAt (s : Benitoite.Scope.Signature.IOShape) (ws : List Value) :
    Benitoite.Scope.Signature.IOShape := match s with
  | .single k p => if ((ws[p]?).bind target?).isSome then .single k p else .topTargeted k
  | sh => sh

theorem checkedRequest_keeps_single_shape :
    shapeAt (.single .endpoint 0) [.checkedRequest api defaultRequest] = .single .endpoint 0 := rfl

-- targetMemberが表すのは保持対象の所属までで、要求のURLとの一致は別である。
def TargetMember (R : Range) (v : Value) := ∃ t, target? v = some t ∧ R.Mem t
theorem targetMember_widen {R S : Range} {v : Value} (h : TargetMember R v) (hs : R.Sub S) :
    TargetMember S v := by
  obtain ⟨t, ht, hm⟩ := h
  exact ⟨t, ht, hs t hm⟩

theorem targetMember_not_enough : TargetMember .top (.checkedRequest api defaultRequest) ∧
    reqTarget defaultRequest ≠ some api := by
  refine ⟨⟨api, rfl, trivial⟩, ?_⟩
  rw [typed_mismatched_request.2.1]
  intro h; cases h

#print axioms typed_mismatched_request
#print axioms targetMember_not_enough
#print axioms checkedRequest_keeps_single_shape
#print axioms targetMember_widen
end P3bRequest
