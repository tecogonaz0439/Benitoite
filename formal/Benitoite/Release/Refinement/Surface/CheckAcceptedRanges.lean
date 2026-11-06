import Benitoite.Release.Refinement.Surface.CheckAcceptBase

/-! 全本体の受理から、全ての呼び出しの範囲被覆と契約の位置の存在を得る。 -/
namespace Benitoite.Release.Refinement.Surface.CheckAccept
open Benitoite.Scope.Inference Scope.Domain
open ScopeState ScopeLower ScopeAccept

/-- 全出現で規則が選ぶ範囲を契約が覆い、選んだ全位置に契約がある。記録が無い出現は事実を持たない状態で判定する。 -/
def BodyRanges (A : AcceptInput) (key : Key) (scope : Interval.BindingScope) (body : Block) : Prop :=
  let T := tableFor A key body
  let records := (analyzeBody A.ok T A.limits key scope body).2
  ∀ (k : Key) (b : PrimName) (ts : List Ty) (es : List Eff) (ix : List RangeIx)
      (labels : List (Option String)) (positions : List Nat) (args : Exprs) (xs : List Arg)
      (rule : ScopeRule Refinement.Val),
    (k, .call (.primName b ts es ix) labels positions args) ∈ occurrences key body →
    contractOrder positions (lowerArgs (argsKey k (.primName b ts es ix)) args) = some xs →
    T.ruleAt k = some rule →
    (∀ st, (k, st) ∈ records → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T st)))[i]? = some r →
      ∃ S, ix[i]? = some (.fixed (.absolute S)) ∧ S.Covers r) ∧
    ((∀ st, (k, st) ∉ records) → ∀ (i : Nat) (r : Range),
      (rule.index (xs.map (absArg T factFree)))[i]? = some r →
      ∃ S, ix[i]? = some (.fixed (.absolute S)) ∧ S.Covers r)

private theorem body_ranges_of_accepted {A key scope body}
    (h : acceptBody A.ok (tableFor A key body) A.limits key scope body = .ok ()) :
    BodyRanges A key scope body := by
  intro k b ts es ix labels positions args xs rule hocc hxs hrule
  exact acceptBody_ranges h hocc hxs hrule

/-- 受理したプログラムの各関数について、全出現・全記録と記録の無い場合の範囲契約を得る。 -/
theorem Accepted.def_ranges {A q p} (h : Accepted A q p) {n d} (hd : p.defs n = some d) :
    BodyRanges A (bodyKey n) (entryScope d.coreParams.length) d.body :=
  body_ranges_of_accepted (h.def_body hd)

/-- 受理したプログラムの各実装メソッドにも、同じ全出現の範囲契約が成り立つ。 -/
theorem Accepted.method_ranges {A q p} (h : Accepted A q p) {i id m body}
    (hi : p.impls i = some id) (hm : id.methods m = some body) :
    BodyRanges A (bodyKey (A.methodKey i m))
      (entryScope (id.dictTys.length + (q.methodParamNames i m).length)) body :=
  body_ranges_of_accepted (h.method_body hi hm)

end Benitoite.Release.Refinement.Surface.CheckAccept
