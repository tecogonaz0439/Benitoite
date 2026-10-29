import Benitoite.Release.TargetTable
import Benitoite.Release.Lemmas.MembershipBase

/-!
# L40.3c の第一段の試行: 要求をレコードの閉じた値で持つ規則と Scope の系の前提

試行の差分（`trial-7.diff`。`Val.checkedRequest t (req : Val)` と、保持する要求が同じストアの型付け・空の NoFail の
文脈・空の型と値の文脈で `valContent` の型を持つ前提の規則 V-CheckedRequest）を当ててビルドしたモジュールを
読み込み、次を確かめる。

1. `Http.ClientRequest` のレコードの閉じた値が、構成子を宣言したプログラムで `TargetTable.clientRequestTy` を持ち、
   それを保持する検査済みの要求の値が `Http.RequestIn[api.example.com:443]` を持つ。
2. 構成子を宣言しないプログラムでは、同じ値はどの型も持たない。従って `scope_local_typed_of_typed` の、別の
   プログラム `Pr'` の型付けから任意のプログラム `Pr` の型付けを得る形は、新しい規則では成り立たない。
3. 同じプログラムと同じストアの型付け（またはストアの型付けの包含）なら、`scope_local_typed` の前提 `hc` を
   引数の値の型付けから得られる（NoFail の文脈・型の文脈・値の文脈は任意のまま）。
4. 保持したレコードの欄（`url`）は、射影の後に同じ値として読める（逆転で保持する値と型を取り出す）。

本ファイルは試行の記録であり、既定のビルドの対象ではない。
-/

namespace L403cProbe

open Benitoite
open Benitoite.Release
open Scope.Domain (Range Target)

/-- 表のデータだけを持つ小さな表（モデル）。`valKind`・`valContent` は `TargetTable` のもの。 -/
def B : Builtins where
  sig := fun _ => none
  delta := fun _ _ _ _ _ => none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => True
  refGet := "Reference.get"
  refSet := "Reference.set"
  valKind := TargetTable.valKind
  valContent := TargetTable.valContent

def pairTy : Ty := .data "Pair" [.base .string, .base .string]

/-- `Http.ClientRequest` の五つの欄（Rust の `Http.bnt` の宣言の順）。 -/
def clientRequestDecl : ConDecl :=
  ⟨"Http.ClientRequest", 0, [.base .string, .base .string, .list pairTy, .bytes, .base .integer]⟩
def pairDecl : ConDecl := ⟨"Pair", 2, [.tvar 0, .tvar 1]⟩

def prog : Program :=
  ⟨fun _ => none,
   fun c => if c = "Http.ClientRequest" then some clientRequestDecl else if c = "Pair" then some pairDecl else none,
   fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩

def emptyProg : Program :=
  ⟨fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none⟩

def timeout : Integer64Value := ⟨30000, by decide⟩
def header : Val := .con "Pair" [.base .string, .base .string] [.const (.string "Accept"), .const (.string "text/plain")]
def record : Val :=
  .con "Http.ClientRequest" []
    [.const (.string "GET"), .const (.string "https://api.example.com/"), .list [header], .bytesV [],
      .const (.integer timeout)]

def apiRange : Range := .endpoint ⟨.name (.exact ["api", "example", "com"]), ⟨443, 443⟩⟩
def apiT : Target := .endpoint ⟨.name ["api", "example", "com"], 443⟩
def wrapped : Val := .checkedRequest apiT record

theorem header_typed {Ψ} : HasTypeV prog B Ψ [] [] header pairTy :=
  .V_Con (cd := pairDecl) (by simp [prog]) rfl
    (.cons (by simp only [Ty.subst, Ty.substAt]; exact .V_Const)
      (.cons (by simp only [Ty.subst, Ty.substAt]; exact .V_Const) .nil))

/-- 1. レコードの閉じた値は要求の型を持つ。 -/
theorem record_typed {Ψ} : HasTypeV prog B Ψ [] [] record TargetTable.clientRequestTy := by
  refine .V_Con (cd := clientRequestDecl) (by simp [prog]) rfl ?_
  simp only [clientRequestDecl, List.map, Ty.subst, Ty.substAt]
  refine .cons .V_Const (.cons .V_Const (.cons ?_ (.cons .V_Bytes (.cons .V_Const .nil))))
  refine .V_List (.cons ?_ .nil) ?_
  · simpa [pairTy, Ty.subst, Ty.substAt] using header_typed
  · simp [pairTy, Ty.substAt, Ty.substTysAt, Ty.WF, Ty.WFList]

/-- 1. 保持した値は `Http.RequestIn[api.example.com:443]` を持つ。 -/
theorem wrapped_typed {Ψ Q C Γ} : HasTypeVQ prog B Ψ Q C Γ wrapped (.opaque "Http.RequestIn" (.fixed apiRange)) :=
  .V_CheckedRequest (T := TargetTable.clientRequestTy) rfl (by decide) rfl record_typed

/-- 構成子を宣言しないプログラムでは、レコードの値はどの型も持たない。 -/
theorem record_not_typed_empty {Ψ Q C Γ T} : ¬ HasTypeVQ emptyProg B Ψ Q C Γ record T := by
  intro h
  obtain ⟨cd, hc, -⟩ := h.inv_con rfl
  simp [emptyProg] at hc

/-- 2. 構成子を宣言しないプログラムでは、保持した値もどの型も持たない。 -/
theorem wrapped_not_typed_empty {Ψ Q C Γ T} : ¬ HasTypeVQ emptyProg B Ψ Q C Γ wrapped T := by
  intro h
  obtain ⟨o, R, A, hT, hk, hm, hA, hr⟩ := h.inv_checkedRequest rfl
  exact record_not_typed_empty hr

/-- 2. `scope_local_typed_of_typed` の、プログラムを取り替える結論の形（`Pr'` での型付けから任意の `Pr` での型付け）は
新しい規則では成り立たない。 -/
theorem arbitrary_program_transfer_fails :
    ¬ ∀ (Pr Pr' : Program) (Ψ Ψ' : StoreTy) (Q Q' : NoFailCtx) (C C' : List TParam) (Γ Γ' : List (Option Ty))
        (ix : Scope.Signature.Ix) (S : Range),
        HasTypeVQ Pr' B Ψ' Q' C' Γ' wrapped (.opaque "Http.RequestIn" ix) →
        HasTypeVQ Pr B Ψ Q C Γ wrapped (.opaque "Http.RequestIn" (.fixed S)) := by
  intro h
  exact wrapped_not_typed_empty
    (h emptyProg prog (fun _ => none) (fun _ => none) Qempty Qempty [] [] [] [] (.fixed apiRange) apiRange wrapped_typed)

/-- 3. 同じプログラムと同じストアの型付けなら、`scope_local_typed` の前提 `hc` の新しい形を、引数の値の型付けから
得られる。NoFail の文脈・型の文脈・値の文脈は両側で任意である。 -/
theorem hc_of_typed_same {Pr : Program} {B : Builtins} {Ψ : StoreTy} {Q' : NoFailCtx} {C' : List TParam}
    {Γ' : List (Option Ty)} {v : Val} {name : OpaqueName} {ix : Scope.Signature.Ix}
    (hv : HasTypeVQ Pr B Ψ Q' C' Γ' v (.opaque name ix)) :
    ∀ t c, v = .checkedRequest t c → ∃ A, B.valContent name = some A ∧ HasTypeVQ Pr B Ψ Qempty [] [] c A := by
  intro t c hvc
  obtain ⟨o, R, A, hT, -, -, hA, hc⟩ := hv.inv_checkedRequest hvc
  cases hT
  exact ⟨A, hA, hc⟩

/-- 3. ストアの型付けを広げる方向（`Ψ'` ⊆ `Ψ`）でも得られる（`HasTypeVQ.store`）。 -/
theorem hc_of_typed_sub {Pr : Program} {B : Builtins} {Ψ Ψ' : StoreTy} {Q' : NoFailCtx} {C' : List TParam}
    {Γ' : List (Option Ty)} {v : Val} {name : OpaqueName} {ix : Scope.Signature.Ix}
    (hv : HasTypeVQ Pr B Ψ' Q' C' Γ' v (.opaque name ix)) (hΨ : StoreTy.Sub Ψ' Ψ) :
    ∀ t c, v = .checkedRequest t c → ∃ A, B.valContent name = some A ∧ HasTypeVQ Pr B Ψ Qempty [] [] c A := by
  intro t c hvc
  obtain ⟨A, hA, hc⟩ := hc_of_typed_same hv t c hvc
  exact ⟨A, hA, hc.store hΨ⟩

/-- 4. 型を持つ検査済みの要求の値から、保持するレコードとその型を取り出せる。射影の δ がこの値を返せば、欄の参照
（構成子の照合）は保持した欄の値を読む。ここでは保持した値の第1欄（`url`）が元の文字列であることを確かめる。 -/
theorem stored_record_typed {Ψ Q C Γ c R}
    (h : HasTypeVQ prog B Ψ Q C Γ (.checkedRequest apiT c) (.opaque "Http.RequestIn" (.fixed R))) :
    HasTypeVQ prog B Ψ Qempty [] [] c TargetTable.clientRequestTy := by
  obtain ⟨o, R', A, hT, -, -, hA, hc⟩ := h.inv_checkedRequest rfl
  simp only [Ty.opaque.injEq] at hT
  obtain ⟨rfl, -⟩ := hT
  simp only [B, TargetTable.valContent, Option.some.injEq] at hA
  subst hA
  exact hc

def urlOf : Val → Option Val
  | .con "Http.ClientRequest" _ [_, u, _, _, _] => some u
  | _ => none

theorem wrapped_url : (match wrapped with | .checkedRequest _ r => urlOf r | _ => none) =
    some (.const (.string "https://api.example.com/")) := rfl

end L403cProbe

#print axioms L403cProbe.record_typed
#print axioms L403cProbe.wrapped_typed
#print axioms L403cProbe.wrapped_not_typed_empty
#print axioms L403cProbe.arbitrary_program_transfer_fails
#print axioms L403cProbe.hc_of_typed_same
#print axioms L403cProbe.hc_of_typed_sub
#print axioms L403cProbe.stored_record_typed
#print axioms L403cProbe.wrapped_url
