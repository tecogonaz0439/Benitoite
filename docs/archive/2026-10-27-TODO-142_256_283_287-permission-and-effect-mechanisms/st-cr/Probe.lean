import Benitoite.Surface.ScopeSound

/-! ST-CR の単一ファイルの試行。本番の定義は変更しない。 -/
namespace STCR
open Benitoite
open Benitoite.Release

def requestDecl : ConDecl :=
  ⟨"Http.ClientRequest", 0,
    [.base .string, .base .string, .list (.data "Pair" [.base .string, .base .string]), .bytes, .base .integer]⟩

def request : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"), .const (.string "https://example.com/"), .list [], .bytesV [],
    .const (.integer ⟨30000, by decide⟩)]

theorem record_typed {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {C : List TParam} {Γ : List (Option Ty)}
    (hc : P.cons "Http.ClientRequest" = some requestDecl) :
    HasTypeVQ P B Ψ Q C Γ request (.data "Http.ClientRequest" []) := by
  apply HasTypeVQ.V_Con (cd := requestDecl) hc rfl
  change HasTypeVsQ P B Ψ Q C Γ _
    [.base .string, .base .string, .list (.data "Pair" [.base .string, .base .string]), .bytes, .base .integer]
  exact .cons .V_Const (.cons .V_Const
    (.cons (.V_List .nil (by simp [Ty.WF, Ty.WFList])) (.cons .V_Bytes (.cons .V_Const .nil))))

theorem record_not_opaque {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : List TParam} :
    ¬ HasTypeVQ P B Ψ Q C [] request (.opaqueTop "Http.ClientRequest") := by
  intro h
  rcases h.canonical_opaque with ⟨_, he, _⟩ | ⟨_, _, he, _⟩ | ⟨_, _, _, _, he, _⟩ <;>
    simp [request] at he

theorem record_needs_declaration {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx}
    {C : List TParam} {Γ : List (Option Ty)} {T : Ty} :
    ¬ HasTypeVQ Model.emptyProgram B Ψ Q C Γ request T := by
  intro h
  obtain ⟨cd, hc, _⟩ := h.inv_con rfl
  simp [Model.emptyProgram] at hc

theorem record_endpoint_ignored (f : Const → Option Scope.Domain.Target) :
    Surface.ScopeSound.reqEndpoint f request = none := rfl

/-! 同梱のビルド済みモジュールには requestOk がないため、現在のソースの定義をこの場で写す。
現在の ScopeState 全体を再検査したことにはしない。 -/
def copiedRequestOk : List Val → Scope.Domain.Target → Val
  | [_, _, _, .const req], t => .checkedRequest t req
  | _, t => .checked t

theorem record_requestOk_falls_back (t : Scope.Domain.Target) :
    copiedRequestOk [.const (.string "example.com"), .const (.integer ⟨443, by decide⟩),
      .const (.integer ⟨443, by decide⟩), request] t = .checked t := rfl

theorem check_signature_opaque (r : Scope.Domain.Range) :
    (TargetTable.checkRequestIn.inst [r]).params.map (Ty.subst [] []) =
      [.base .string, .base .integer, .base .integer, .opaqueTop "Http.ClientRequest"] :=
  ModelHttp.checkRequestIn_params r

/-! 型を表に置くだけでは、型代入で表の内容が変わらないとはいえない。 -/
theorem open_type_changes :
    Ty.subst [.base .string] [] (.tvar 0) ≠ (.tvar 0) := by
  simp [Ty.subst, Ty.substAt, Ty.shift]

/-! 独立した閉じたデータの形なら、本番の Val の相互再帰に新しい枝を加えずに中身を表せる。
ここでは一つのレコードと対・リスト・定数・バイト列だけを試す。型付けの完全な接続は試していない。 -/
inductive DataValue where
  | string (s : String)
  | integer (n : Integer64Value)
  | bytes (bs : List Nat)
  | pair (name : ConName) (a b : String)
  | con (name : ConName) (args : List DataValue)
  | list (args : List DataValue)

mutual
  def DataValue.toVal : DataValue → Val
    | .string s => .const (.string s)
    | .integer n => .const (.integer n)
    | .bytes bs => .bytesV bs
    | .pair n a b => .con n [.base .string, .base .string] [.const (.string a), .const (.string b)]
    | .con n args => .con n [] (toVals args)
    | .list args => .list (toVals args)
  def toVals : List DataValue → List Val
    | [] => []
    | v :: vs => v.toVal :: toVals vs
end

mutual
  theorem DataValue.rename_toVal (ξ : Nat → Nat) : (v : DataValue) →
      Val.rename ξ v.toVal = v.toVal
    | .string _ => rfl
    | .integer _ => rfl
    | .bytes _ => rfl
    | .pair _ _ _ => rfl
    | .con _ args => by simp [DataValue.toVal, Val.rename, rename_toVals ξ args]
    | .list args => by simp [DataValue.toVal, Val.rename, rename_toVals ξ args]
  theorem rename_toVals (ξ : Nat → Nat) : (vs : List DataValue) →
      Val.renameList ξ (toVals vs) = toVals vs
    | [] => rfl
    | v :: vs => by simp [toVals, Val.renameList, DataValue.rename_toVal ξ v, rename_toVals ξ vs]
end

mutual
  theorem DataValue.subst_toVal (σ : Nat → Val) (ρ : Nat → LocalRef) : (v : DataValue) →
      Val.subst σ v.toVal ρ = v.toVal
    | .string _ => rfl
    | .integer _ => rfl
    | .bytes _ => rfl
    | .pair _ _ _ => rfl
    | .con _ args => by simp [DataValue.toVal, Val.subst, subst_toVals σ ρ args]
    | .list args => by simp [DataValue.toVal, Val.subst, subst_toVals σ ρ args]
  theorem subst_toVals (σ : Nat → Val) (ρ : Nat → LocalRef) : (vs : List DataValue) →
      Val.substList σ (toVals vs) ρ = toVals vs
    | [] => rfl
    | v :: vs => by simp [toVals, Val.substList, DataValue.subst_toVal σ ρ v, subst_toVals σ ρ vs]
end

mutual
  theorem DataValue.substTy_toVal (c : Nat) (ts : List Ty) (es : List Eff) : (v : DataValue) →
      Val.substTyAt c ts es v.toVal = v.toVal
    | .string _ => rfl
    | .integer _ => rfl
    | .bytes _ => rfl
    | .pair _ _ _ => rfl
    | .con _ args => by simp [DataValue.toVal, Val.substTyAt, substTy_toVals c ts es args]
    | .list args => by simp [DataValue.toVal, Val.substTyAt, substTy_toVals c ts es args]
  theorem substTy_toVals (c : Nat) (ts : List Ty) (es : List Eff) : (vs : List DataValue) →
      Val.substTyAtList c ts es (toVals vs) = toVals vs
    | [] => rfl
    | v :: vs => by simp [toVals, Val.substTyAtList, DataValue.substTy_toVal c ts es v, substTy_toVals c ts es vs]
end

#print axioms record_typed
#print axioms record_not_opaque
#print axioms record_needs_declaration
#print axioms record_endpoint_ignored
#print axioms record_requestOk_falls_back
#print axioms check_signature_opaque
#print axioms open_type_changes
#print axioms DataValue.rename_toVal
#print axioms rename_toVals
#print axioms DataValue.subst_toVal
#print axioms subst_toVals
#print axioms DataValue.substTy_toVal
#print axioms substTy_toVals
#check Val.checkedRequest
#check HasTypeVQ.V_CheckedRequest
#print Surface.ScopeSound.reqEndpoint
#print TargetTable.clientRequestTy
end STCR
