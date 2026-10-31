import Benitoite.Release.Refinement.MatchFacts
namespace Benitoite.Release.Refinement.RV8
open MatchFacts
noncomputable section

/-- 確認1: 開始の状態が持つ MatchPrefix と実際の成功から、規則が足す事実の評価入力を組める。
    入力は各腕の AltsTy、実際の Inhabits、閉じた項の WF/Sorted だけである。 -/
theorem match_paths_evaluated {P a v arms n alts g body ws}
    (hty : ∀ (i : Nat) as g m, arms[i]? = some (Arm.mk as g m) → ∃ δ, AltsTy P as a δ)
    (hv : Inhabits P a v) (hp : MatchPrefix v arms n)
    (hi : arms[n]? = some (Arm.mk alts g body)) (hm : firstAlt v alts = some ws)
    (hw : ∀ (i : Nat) as g m, arms[i]? = some (Arm.mk as g m) →
      ∀ p ∈ pathFacts v.toTerm? (matchedTests as ++ excludedTests as), p.WF 0 ∧ p.Sorted [] none) :
    MatchPathsEvaluated v arms n := by
  constructor
  · intro i as g' m hi' hlt hg
    obtain ⟨δ,ha⟩ := hty i as g' m hi'
    have hmem : Arm.mk as g' m ∈ arms.take n := by
      obtain ⟨hlen,he⟩ := List.getElem?_eq_some_iff.mp hi'
      exact List.mem_take_iff_getElem.mpr ⟨i,by omega,he⟩
    have hf : firstAlt v as = none := hp _ hmem (by subst hg; rfl)
    exact excluded_paths_true ha hv hf (fun p hp' => hw i as g' m hi' p (by
      simp only [pathFacts_append,List.mem_append]; exact .inr hp'))
  · intro as g' m hi'
    rw [hi] at hi'
    cases Option.some.inj hi'
    exact matched_paths_true hm (fun p hp' => hw n _ _ _ hi p (by
      simp only [pathFacts_append,List.mem_append]; exact .inl hp'))

/-- 確認1の反例: 型付けできる閉じた値でも Inhabits を持たない形がある。 -/
theorem checkedAt_not_inhabits {P : Program} {o r range snap t req} :
    ¬ Inhabits P (.opaque o (.fixed r)) (.checkedAt range snap t req) := by
  intro h
  generalize ha : Ty.opaque o (.fixed r) = a at h
  generalize hv : Val.checkedAt range snap t req = w at h
  cases h <;> first | (cases ha; done) | (cases hv; done)

theorem checkedAt_typed_opaque {P B Ψ o k range snap t req ix}
    (hw : CheckedWitness P B Ψ o k range snap t req)
    (ha : Ty.Annotation P [] [] (.opaque o (.fixed range)))
    (hix : ix = RangeIx.fixed range) :
    HasTypeV P B Ψ [] [] [] (.checkedAt range snap t req) (.opaque o ix) := by
  subst hix
  exact .V_Sub (.V_CheckedAt hw) .scoped_forget ha.wf ha.sorted ha.declared

/-- その結果 List の要素に入ると、`[] => …; ys => …` の除外の入力が作れない。事実自体は真である。 -/
theorem list_checkedAt_not_inhabits {P : Program} {o r range snap t req} :
    ¬ Inhabits P (.list (.opaque o (.fixed r))) (.list [.checkedAt range snap t req]) := by
  intro h
  generalize ha : Ty.list (.opaque o (.fixed r)) = x at h
  generalize hv : Val.list [.checkedAt range snap t req] = w at h
  cases h with
  | list he =>
    cases ha; cases hv
    cases he with
    | cons hh _ => exact checkedAt_not_inhabits hh
  | _ => first | (cases ha; done) | (cases hv; done)

-- 確認2: 空の範囲。照合は失敗し、否定は真である。
def lo : Integer64Value := ⟨5,by decide⟩
def hi : Integer64Value := ⟨1,by decide⟩
example : matchVal (.range (.integer lo) (.integer hi)) (.const (.integer ⟨3,by decide⟩)) = none := by decide
example : excludedTest? (.range (.integer lo) (.integer hi)) = some (.negated (.integerRange 5 1)) := rfl
example : (Pred.not ((PathTest.integerRange 5 1).predicate (.integer 3))).evalClosed = some true := by decide
-- 両端を含む。
example : ((PathTest.integerRange 1 5).predicate (.integer 5)).evalClosed = some true := by decide
example : ((PathTest.integerRange 1 5).predicate (.integer 1)).evalClosed = some true := by decide
example : ((PathTest.characterRange 'a' 'c').predicate (.character 'c')).evalClosed = some true := by decide
example : ((PathTest.characterRange 'a' 'c').predicate (.character 'd')).evalClosed = some false := by decide
-- 空リストの長さ。
example : (PathTest.empty.predicate (.listValue [])).evalClosed = some true := by decide
example : (PathTest.empty.predicate (.listValue [none])).evalClosed = some false := by decide
-- 全 Unit・Boolean の等号。
example : ((PathTest.literal .unit).predicate .unitValue).evalClosed = some true := by decide
example : ((PathTest.literal (.boolean false)).predicate (.boolean false)).evalClosed = some true := by decide
example : ((PathTest.literal (.string "a")).predicate (.string "b")).evalClosed = some false := by decide
-- or: 事実のない選択肢が混ざれば Or を作らない。否定は作れた分だけ。
example : matchedTests [⟨.const (.boolean true),[]⟩,⟨.wild,[]⟩] = [] := rfl
example : matchedTests [⟨.wild,[]⟩,⟨.const (.boolean true),[]⟩] = [] := rfl
example : matchedTests [⟨.con "A" [],[]⟩,⟨.var,[]⟩,⟨.con "B" [],[]⟩] = [] := rfl
example : excludedTests [⟨.con "A" [.const (.boolean true)],[]⟩,⟨.con "B" [],[]⟩] = [.excluded "B"] := rfl
-- 欄を絞る腕は根を除かない。根の事実だけは成功時に出す。
example : excludedTests [⟨.con "A" [.con "C" []],[]⟩] = [] := rfl
example : matchedTests [⟨.con "A" [.con "C" []],[]⟩] = [.constructor "A"] := rfl
-- At
example : (PathTest.excluded "X").predicate (.dataValue "Scope.ScopeError.At" []) = .not (.constructorIs (.dataValue "Scope.ScopeError.At" []) "X") := rfl
end
end Benitoite.Release.Refinement.RV8
#print axioms Benitoite.Release.Refinement.RV8.match_paths_evaluated
#print axioms Benitoite.Release.Refinement.RV8.checkedAt_typed_opaque
