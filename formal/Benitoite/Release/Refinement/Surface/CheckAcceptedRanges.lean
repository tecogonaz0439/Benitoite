import Benitoite.Release.Refinement.Surface.CheckAcceptBase

/-! 全本体の受理から、全ての呼び出しの範囲被覆と契約の位置の存在を得る。 -/
namespace Benitoite.Release.Refinement.Surface.CheckAccept
open Benitoite.Scope.Inference Scope.Domain
open ScopeState ScopeLower ScopeAccept

/-- 全出現で規則が選ぶ範囲を契約が覆い、選んだ全位置に契約がある。記録が無い出現は事実を持たない状態で判定する。 -/
def BodyRanges (A : AcceptInput) (key : Key) (scope : Interval.BindingScope) (body : Block) : Prop :=
  ScopeAccept.BodyRanges A.ok (tableFor A key body) A.limits key scope body

private theorem body_ranges_of_accepted {A key scope body}
    (h : acceptBody A.ok (tableFor A key body) A.limits key scope body = .ok ()) :
    BodyRanges A key scope body := by
  exact ScopeAccept.acceptBody_ranges_all h

/-- 空の種類列での閉じた由来の全出現の被覆、又は記号的な規則の選択に応じた被覆。 -/
def DefinitionRanges (A : AcceptInput) (name : FunName) (d : Def) : Prop :=
  OpenScopeAccept.BodyRanges A.openRules d.rangeParams d.coreParams A.ok
    (tableFor A (bodyKey name) d.body) A.limits (bodyKey name) (entryScope d.coreParams.length) d.body

/-- 空の範囲文脈で記号側の選択がないとき、全出現について閉じた由来の契約を得る。 -/
theorem Accepted.def_ranges_no_ranges {A q p} (h : Accepted A q p) {n d}
    (hd : p.defs n = some d) (hr : d.rangeParams = [])
    (noneSelected : OpenScopeAccept.selections A.openRules d.coreParams (bodyKey n) d.body = []) :
    BodyRanges A (bodyKey n) (entryScope d.coreParams.length) d.body :=
  body_ranges_of_accepted (h.def_body_no_ranges hd hr noneSelected)

/-- 閉じた由来の判定が成功した範囲パラメータのないプログラムは、記号側を含む受理と同じ閉じた全被覆をともに持つ。 -/
theorem accepted_no_ranges_of_closed {A : AcceptInput} {q : Check.Input} {p : Program}
    (hr : ∀ n d, p.defs n = some d → d.rangeParams = [])
    (hd : ∀ n d, p.defs n = some d → acceptFn A n d.coreParams.length d.body = .ok ())
    (hm : ∀ i id, p.impls i = some id → ∀ m body, id.methods m = some body →
      acceptMethod A q i m id body = .ok ()) :
    Accepted A q p ∧ ∀ n d, p.defs n = some d →
      BodyRanges A (bodyKey n) (entryScope d.coreParams.length) d.body :=
  ⟨Accepted.of_no_ranges hr hd hm, fun n d found => body_ranges_of_accepted (hd n d found)⟩

/-- 受理したプログラムの各関数について、選択した規則の範囲契約を得る。 -/
theorem Accepted.def_ranges {A q p} (h : Accepted A q p) {n d} (hd : p.defs n = some d) :
    DefinitionRanges A n d := by
  exact OpenScopeAccept.acceptBody_sound (h.def_body hd)

/-- 受理したプログラムの各実装メソッドにも、同じ全出現の範囲契約が成り立つ。 -/
theorem Accepted.method_ranges {A q p} (h : Accepted A q p) {i id m body}
    (hi : p.impls i = some id) (hm : id.methods m = some body) :
    BodyRanges A (bodyKey (A.methodKey i m))
      (entryScope (id.dictTys.length + (q.methodParamNames i m).length)) body :=
  body_ranges_of_accepted (h.method_body hi hm)

end Benitoite.Release.Refinement.Surface.CheckAccept
