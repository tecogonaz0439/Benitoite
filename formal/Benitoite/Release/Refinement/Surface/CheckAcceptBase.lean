import Benitoite.Release.Refinement.Surface.CheckInput
import Benitoite.Release.Refinement.Surface.ScopeAccept
import Benitoite.Release.Refinement.Surface.OpenScopeAccept

/-! 全定義・全実装メソッドの必須の判定の受理。 -/
namespace Benitoite.Release.Refinement.Surface.CheckAccept
open Benitoite.Scope.Inference ScopeState ScopeLower ScopeAccept

structure AcceptInput where
  ok : ConName
  rules : String → Option (ScopeRule Refinement.Val)
  limits : Limits
  methodKey : ImplName → MethName → String
  /-- 型が保持する開いた範囲を選ぶ規則。閉じた由来の規則とは別の構成データである。 -/
  openRules : List OpenScopeAccept.Rule :=
    [.pathWiden, .requestWiden, .pathValue, .requestValue, .readText, .readBytes, .send,
      .writeText, .appendText, .writeBytes, .appendBytes]

def bodyKey (name : String) : Key := ⟨name, 0⟩

def entryScope (n : Nat) : Benitoite.Interval.BindingScope := ⟨List.range n, n⟩

def primResolve (key : Key) (body : Block) : Key → Option Resolved := fun k =>
  match (occurrences key body).find? (fun p => decide (p.1 = k)) with
  | some (_, .call (.primName b _ _ _) _ _ _) => some ⟨.standard, b⟩
  | _ => none

def tableFor (A : AcceptInput) (key : Key) (body : Block) : ScopeTable Refinement.Val :=
  standardTable (primResolve key body) A.rules

def acceptFn (A : AcceptInput) (name : String) (nlocals : Nat) (body : Block) : Except (Key × CoverFailure) Unit :=
  acceptBody A.ok (tableFor A (bodyKey name) body) A.limits (bodyKey name) (entryScope nlocals) body

def acceptDef (A : AcceptInput) (name : FunName) (d : Def) : Except (Key × CoverFailure) Unit :=
  OpenScopeAccept.acceptBody A.openRules d.rangeParams d.coreParams A.ok
    (tableFor A (bodyKey name) d.body) A.limits (bodyKey name) (entryScope d.coreParams.length) d.body

/-- 範囲パラメータのない定義は、閉じた由来の必須の判定を使う。 -/
theorem acceptDef_no_ranges (A : AcceptInput) (name : FunName) (d : Def) (h : d.rangeParams = [])
    (noneSelected : OpenScopeAccept.selections A.openRules d.coreParams (bodyKey name) d.body = []) :
    acceptDef A name d = acceptFn A name d.coreParams.length d.body := by
  unfold acceptDef
  rw [h]
  exact OpenScopeAccept.acceptBody_no_ranges _ _ _ _ _ _ _ _ noneSelected |>.trans (by rfl)

def acceptMethod (A : AcceptInput) (q : Check.Input) (i : ImplName) (m : MethName)
    (id : ImplDecl) (body : Block) : Except (Key × CoverFailure) Unit :=
  acceptFn A (A.methodKey i m) (id.dictTys.length + (q.methodParamNames i m).length) body

/-- 名前の一覧に現れる全本体を検査する。健全性では、一覧が実際の全 lookup を含むことを別に照合する。 -/
def acceptProgram (A : AcceptInput) (q : Check.Input) (p : Program) : Except (Key × CoverFailure) Unit := do
  allOk q.defs fun n => match p.defs n with
    | none => .ok ()
    | some d => acceptDef A n d
  allOk q.impls fun i => match p.impls i with
    | none => .ok ()
    | some id => allOk q.methods fun m => match id.methods m with
      | none => .ok ()
      | some body => acceptMethod A q i m id body

/-- 本体を持つ全ての定義と全ての実装メソッドで必須の判定が成功する。 -/
def Accepted (A : AcceptInput) (q : Check.Input) (p : Program) : Prop :=
  (∀ n d, p.defs n = some d → acceptDef A n d = .ok ()) ∧
  ∀ i id, p.impls i = some id → ∀ m body, id.methods m = some body → acceptMethod A q i m id body = .ok ()

def NamesComplete (q : Check.Input) (p : Program) : Prop :=
  (∀ n d, p.defs n = some d → n ∈ q.defs) ∧
  (∀ i id, p.impls i = some id → i ∈ q.impls) ∧
  (∀ i id, p.impls i = some id → ∀ m body, id.methods m = some body → m ∈ q.methods)

private theorem bind_unit_ok {ε : Type} {r s : Except ε Unit} (h : (r >>= fun _ => s) = .ok ()) :
    r = .ok () ∧ s = .ok () := by
  cases r with
  | error e => cases h
  | ok u => cases u; exact ⟨rfl, h⟩

theorem acceptProgram_sound {A q p} (hn : NamesComplete q p)
    (h : acceptProgram A q p = .ok ()) : Accepted A q p := by
  obtain ⟨hd, hi⟩ := bind_unit_ok h
  refine ⟨fun n d hget => ?_, fun i id hget m body hb => ?_⟩
  · have hh := allOk_ok hd n (hn.1 n d hget)
    simpa only [hget] using hh
  · have hh := allOk_ok hi i (hn.2.1 i id hget)
    simp only [hget] at hh
    have hm := allOk_ok hh m (hn.2.2 i id hget m body hb)
    simpa only [hb] using hm

theorem Accepted.def_body {A q p} (h : Accepted A q p) {n d} (hd : p.defs n = some d) :
    OpenScopeAccept.acceptBody A.openRules d.rangeParams d.coreParams A.ok
      (tableFor A (bodyKey n) d.body) A.limits (bodyKey n)
      (entryScope d.coreParams.length) d.body = .ok () := h.1 n d hd

/-- 空の範囲文脈では、受理した定義の閉じた由来の局所解析の成功を得る。 -/
theorem Accepted.def_body_no_ranges {A q p} (h : Accepted A q p) {n d}
    (hd : p.defs n = some d) (hr : d.rangeParams = [])
    (noneSelected : OpenScopeAccept.selections A.openRules d.coreParams (bodyKey n) d.body = []) :
    ScopeAccept.acceptBody A.ok (tableFor A (bodyKey n) d.body) A.limits (bodyKey n)
      (entryScope d.coreParams.length) d.body = .ok () := by
  have hb := h.1 n d hd
  rw [acceptDef_no_ranges A n d hr noneSelected] at hb
  exact hb

theorem Accepted.method_body {A q p} (h : Accepted A q p) {i id m body}
    (hi : p.impls i = some id) (hm : id.methods m = some body) :
    acceptBody A.ok (tableFor A (bodyKey (A.methodKey i m)) body) A.limits (bodyKey (A.methodKey i m))
      (entryScope (id.dictTys.length + (q.methodParamNames i m).length)) body = .ok () := h.2 i id hi m body hm

end Benitoite.Release.Refinement.Surface.CheckAccept
