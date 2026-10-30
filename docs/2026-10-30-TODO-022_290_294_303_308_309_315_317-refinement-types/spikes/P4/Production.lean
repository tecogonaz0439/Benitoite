import Context
import M6
import Benitoite.Release.ModelHttp

/- 本番への接続に使った定義:
   Release/Syntax.lean:234-269（Val）、Typing.lean:523-591（型付け）、
   ModelHttp.lean:56-57,85-96（名目の ClientRequest と URL 射影）、
   Lemmas/Basic.lean:87-92（旧部分型の非関数の逆転）。 -/
namespace P4.Production
open Benitoite.Release
open Benitoite.Scope.Domain (Target Range)
set_option maxHeartbeats 400000

-- 型付きの本番値から不変な観測値だけを取り出す。閉包の本体・Reference の中身は読まない。
mutual
  def observe (P : Program) : Val → Value
    | .const (.integer n) => .int n.toInt
    | .const (.integer8 n) | .const (.integer16 n) | .const (.integer32 n) => .int n
    | .const (.unsignedInteger16 n) | .const (.unsignedInteger32 n) | .const (.unsignedInteger64 n) => .int n
    | .const (.byte n) => .int n
    | .const (.string s) => .string s
    | .list xs => .list (observeList P xs)
    | .con c _ xs => .con ((P.cons c).map ConDecl.data |>.getD "<undeclared>") c (observeList P xs)
    | .loc l => .reference l
    | v@(.lam _ _ _) | v@(.fnRef _ _ _) | v@(.prim _ _ _ _) | v@(.op _ _) => .closure v
    | .checkedRequest t req => .request t (observe P req)
    | v => .unobserved v
  def observeList (P : Program) : List Val → List Value
    | [] => []
    | v :: vs => observe P v :: observeList P vs
end

-- 0.0.13 の V_CheckedRequest にはこの条件がない。0.0.14 で加える候補を明示する。
def RequestOK (parse : String → Option Target) (a : Ty) (w : Val) : Prop :=
  ∀ R, a = .opaque "Http.RequestIn" (.fixed R) →
    ∃ t req, w = .checkedRequest t req ∧ t.kind = .endpoint ∧ R.Mem t ∧
      ModelHttp.groundVal req = true ∧ ModelHttp.urlTarget parse req = some t

-- 本番の構文の型付けの証拠と、不変な要求についての追加条件だけを持つ。
-- 関数の呼出しの意味や Reference の内容の意味を定義していない。
def Native (P : Program) (B : Builtins) (Ψ : StoreTy) (parse : String → Option Target)
    (v : Value) (a : Ty) : Prop :=
  ∃ w, HasTypeVQ P B Ψ Qempty [] [] w a ∧ observe P w = v ∧ RequestOK parse a w

theorem native_of_typed {P B Ψ parse w a}
    (ht : HasTypeVQ P B Ψ Qempty [] [] w a) (hr : RequestOK parse a w) :
    Native P B Ψ parse (observe P w) a := ⟨w, ht, rfl, hr⟩

-- V_Sub があっても、最外の篩と通常の型の由来をそれぞれ取り出せる。
theorem Typed.native_origin {N : Value → Ty → Prop} {Γ Φ t a} (h : Typed N Γ Φ t a)
    {v : Value} (he : t = .lit v) : ∃ a₀, N v a₀ ∧ Ty.Le a₀ a.carrier := by
  induction h with
  | var => cases he
  | literal hv => cases he; exact ⟨_, hv, Ty.Le.refl _⟩
  | refine _ _ ih => exact ih he
  | V_Sub _ hl ih =>
      obtain ⟨a₀, hv, hc⟩ := ih he
      exact ⟨a₀, hv, Ty.Le.trans hc hl.carrier⟩

-- 任意の篩 p と V_Sub の任意の列を対象とする RequestIn の canonical forms。
theorem request_canonical {P B Ψ parse R p v}
    (h : Typed (Native P B Ψ parse) [] [] (.lit v) ⟨.opaque "Http.RequestIn" (.fixed R), p⟩)
    (ρ : Nat → Value) :
    p.Holds parse (extend ρ v) ∧
      ∃ w t req, HasTypeVQ P B Ψ Qempty [] [] w (.opaque "Http.RequestIn" (.fixed R)) ∧
        w = .checkedRequest t req ∧ observe P w = v ∧ t.kind = .endpoint ∧ R.Mem t ∧
        ModelHttp.urlTarget parse req = some t ∧ ModelHttp.valueRun [w] = .val req := by
  refine ⟨h.canonical parse ρ, ?_⟩
  obtain ⟨a₀, ⟨w, hw, ho, hr⟩, hle⟩ := Typed.native_origin h rfl
  have he : a₀ = .opaque "Http.RequestIn" (.fixed R) := Ty.Le.eq_of_not_fn hle (by intros; simp)
  subst a₀
  obtain ⟨t, req, heq, hkind, hmem, hground, ht⟩ := hr R rfl
  exact ⟨w, t, req, hw, heq, ho, hkind, hmem, ht, by simp [heq, ModelHttp.valueRun, hground]⟩

variable (P : Program) (B : Builtins) (Ψ : StoreTy) (parse : String → Option Target)

def withinTen : Pred := .le (.var 0) (.lit (.int 10))
def n7 : Integer64Value := ⟨7, by decide⟩

theorem int_refined : Typed (Native P B Ψ parse) [] [] (.lit (.int 7))
    ⟨.base .integer, withinTen⟩ := by
  apply Typed.refine (a := ⟨.base .integer, .truth⟩)
  · apply Typed.literal
    exact ⟨.const (.integer n7), .V_Const, rfl, by intro R he; cases he⟩
  · exact .integer (by decide)

include P B Ψ in
theorem int_canonical (ρ : Nat → Value) : withinTen.Holds parse (extend ρ (.int 7)) :=
  (int_refined P B Ψ parse).canonical parse ρ

-- 空でない List と長さの条件。内部に Reference があっても長さの条件は変わらない。
def singletonLength : Pred := .eq (.length (.var 0)) (.lit (.int 1))

theorem list_refined (l : Nat) (hl : Ψ l = some (.ref (.base .integer))) :
    Typed (Native P B Ψ parse) [] [] (.lit (.list [.reference l]))
      ⟨.list (.reference (.base .integer)), singletonLength⟩ := by
  apply Typed.refine (a := ⟨.list (.reference (.base .integer)), .truth⟩)
  · apply Typed.literal
    refine ⟨.list [.loc l], .V_List (.cons (.V_LocRef hl) .nil) ?_, rfl, ?_⟩
    · trivial
    · intro R he; cases he
  · exact .length_eq [.reference l]

include P B in
theorem list_canonical (l : Nat) (hl : Ψ l = some (.ref (.base .integer))) (ρ : Nat → Value) :
    singletonLength.Holds parse (extend ρ (.list [.reference l])) :=
  (list_refined P B Ψ parse l hl).canonical parse ρ

-- record は名目の data Point、その唯一の構成子 MkPoint の欄 0 として表す。
def pointDecl : ConDecl := ⟨"Point", 0, [.base .integer]⟩
def pointField : Pred := .eq (.field "Point" "MkPoint" 0 (.var 0)) (.lit (.int 7))

theorem record_refined (hp : P.cons "MkPoint" = some pointDecl) :
    Typed (Native P B Ψ parse) [] [] (.lit (.con "Point" "MkPoint" [.int 7]))
      ⟨.data "Point" [], pointField⟩ := by
  apply Typed.refine (a := ⟨.data "Point" [], .truth⟩)
  · apply Typed.literal
    refine ⟨.con "MkPoint" [] [.const (.integer n7)], ?_, ?_, ?_⟩
    · exact .V_Con hp rfl (.cons .V_Const .nil)
    · simp [observe, observeList, hp, pointDecl, n7, Integer64Value.toInt]
    · intro R he; cases he
  · exact .field_eq "Point" "MkPoint" [.int 7] 0 (.int 7) rfl

-- Reference は同一の参照値だけを観測する。Ψ のセルの値は一切量化しない。
def sameReference (l : Nat) : Pred := .eq (.var 0) (.lit (.reference l))

theorem reference_refined (l : Nat) (hl : Ψ l = some (.ref (.base .integer))) :
    Typed (Native P B Ψ parse) [] [] (.lit (.reference l))
      ⟨.reference (.base .integer), sameReference l⟩ := by
  apply Typed.refine (a := ⟨.reference (.base .integer), .truth⟩)
  · apply Typed.literal
    exact ⟨.loc l, .V_LocRef hl, rfl, by intro R he; cases he⟩
  · exact .literal_eq (.reference l)

-- ModelHttp の本番値をそのまま用いる閉じた RequestIn の例。
def keptRequest (P : Program) (req : Val) : Pred :=
  .eq (.requestValue (.var 0)) (.lit (observe P req))

theorem request_refined {t : Target} {req : Val} {R : Range}
    (hk : B.valKind "Http.RequestIn" = some t.kind) (hm : R.Mem t)
    (hc : B.valContent "Http.RequestIn" = some TargetTable.clientRequestTy)
    (hr : HasTypeVQ P B Ψ Qempty [] [] req TargetTable.clientRequestTy)
    (he : ModelHttp.urlTarget parse req = some t) (hkind : t.kind = .endpoint)
    (hground : ModelHttp.groundVal req = true) :
    Typed (Native P B Ψ parse) [] [] (.lit (observe P (.checkedRequest t req)))
      ⟨.opaque "Http.RequestIn" (.fixed R), keptRequest P req⟩ := by
  apply Typed.refine (a := ⟨.opaque "Http.RequestIn" (.fixed R), .truth⟩)
  · apply Typed.literal
    refine ⟨.checkedRequest t req, .V_CheckedRequest hk hm hc hr, rfl, ?_⟩
    intro S hs
    cases hs
    exact ⟨t, req, rfl, hkind, hm, hground, he⟩
  · exact .request_value t (observe P req)

-- 本番の List[Reference[Integer]] → 構文の葉 → P2 → V_Sub → canonical forms。
-- ここで V_Sub に渡す含意と Derivation.TyLe.bind の葉は adapter_le で接続している。
def listShape : Pred := .isList (.var 0)
def checkedLength : Pred := .arithmetic [.length (.var 0)] M6.relaxedLength

theorem length_adapter_le (Φ : List Pred) (a : Ty) :
    Le Φ ⟨.list a, listShape⟩ ⟨.list a, checkedLength⟩ := by
  apply Le.refine (a := ⟨.list a, listShape⟩) (b := ⟨.list a, checkedLength⟩) (Ty.Le.refl _)
  exact .checked (cert := M6.lengthCert) (by decide) (.length_nonnegative (.hyp (by simp [listShape])))

theorem checked_list_refined (l : Nat) (hl : Ψ l = some (.ref (.base .integer))) :
    Typed (Native P B Ψ parse) [] [] (.lit (.list [.reference l]))
      ⟨.list (.reference (.base .integer)), checkedLength⟩ := by
  apply Typed.V_Sub (a := ⟨.list (.reference (.base .integer)), listShape⟩)
  · apply Typed.refine (a := ⟨.list (.reference (.base .integer)), .truth⟩)
    · apply Typed.literal
      refine ⟨.list [.loc l], .V_List (.cons (.V_LocRef hl) .nil) ?_, rfl, ?_⟩
      · trivial
      · intro R he; cases he
    · exact .list_shape _
  · exact length_adapter_le _ _

include P B in
theorem checked_list_canonical (l : Nat) (hl : Ψ l = some (.ref (.base .integer))) (ρ : Nat → Value) :
    checkedLength.Holds parse (extend ρ (.list [.reference l])) :=
  (checked_list_refined P B Ψ parse l hl).canonical parse ρ

-- 本番 Http の具体例でも、追加条件と型付けの両方を実際に構成できる。
theorem concrete_request {Ψ : StoreTy} :
    let P := ModelHttp.Examples.httpProg
    let B := ModelHttp.Examples.B
    let parse := ModelHttp.Examples.parseUrl
    let req := ModelHttp.Examples.req
    Typed (Native P B Ψ parse) [] [] (.lit (observe P ModelHttp.Examples.checkedReq))
      ⟨.opaque "Http.RequestIn" (.fixed ModelHttp.Examples.apiRange), keptRequest P req⟩ := by
  apply request_refined
  · rfl
  · decide
  · rfl
  · exact ModelHttp.Examples.mkReq_typed _
  · exact ModelHttp.Examples.reqTarget_req
  · rfl
  · exact ModelHttp.Examples.req_closed

example (ρ : Nat → Value) (l : Nat) :
    Term.eval ρ (.length (.lit (.reference l))) = none := rfl
example (ρ : Nat → Value) (l : Nat) :
    Term.eval ρ (.field "Point" "MkPoint" 0 (.lit (.reference l))) = none := rfl

-- 旧い型付けだけでは endpoint の一致が出ないことを、本番値の反例で固定する。
theorem old_request_mismatch :
    ModelHttp.urlTarget ModelHttp.Examples.parseUrl ModelHttp.defaultRequest ≠ some ModelHttp.Examples.apiT := by
  simp [ModelHttp.urlTarget, ModelHttp.requestUrl, ModelHttp.defaultRequest,
    ModelHttp.Examples.parseUrl, ModelHttp.Examples.apiUrl]

theorem old_bare_request_typed {Ψ : StoreTy} :
    HasTypeVQ ModelHttp.Examples.httpProg ModelHttp.Examples.B Ψ Qempty [] []
      (.checked ModelHttp.Examples.apiT) (.opaque "Http.RequestIn" (.fixed .top)) :=
  .V_Checked rfl trivial

theorem new_bare_request_rejected (parse : String → Option Target) (t : Target) :
    ¬ RequestOK parse (.opaque "Http.RequestIn" (.fixed .top)) (.checked t) := by
  intro h
  obtain ⟨t', req, he, _⟩ := h .top rfl
  cases he

#print axioms old_bare_request_typed
#print axioms new_bare_request_rejected
#print axioms checked_list_canonical
#print axioms concrete_request
#print axioms Typed.native_origin
#print axioms request_canonical
#print axioms int_refined
#print axioms list_refined
#print axioms record_refined
#print axioms reference_refined
#print axioms request_refined
#print axioms old_request_mismatch
end P4.Production
