import Benitoite.Release.Refinement.Surface.PredicateProjectionSpec

/-! # 判定する欄の部分観測と実値の一致 -/
namespace Benitoite.Release.Refinement.Surface.PredicateProjection
open PredicateRows PredicateResponse MatchFacts Scope.Domain
noncomputable section

/-- 中間の欄は data、末尾の欄は判定の scalar の sort である。 -/
def RouteSorted : List FieldRef → «Sort» → Prop
  | [], _ => True
  | [ref], sort => ref.result = sort
  | ref :: next :: rest, sort => ref.result = .data ∧ RouteSorted (next :: rest) sort

theorem route_closed {t : Term} (closed : t.Closed) (route : List FieldRef) :
    (routeTerm t route).Closed := by
  induction route generalizing t with
  | nil => exact closed
  | cons ref rest ih => exact ih closed

theorem route_shape {t : Term} {route : List FieldRef} {sort : «Sort»}
    (nonempty : route ≠ []) (sorted : RouteSorted route sort) (root : t.Shape [] .data) :
    (routeTerm t route).Shape [] sort := by
  induction route generalizing t with
  | nil => contradiction
  | cons ref rest ih =>
    cases rest with
    | nil => exact ⟨root, sorted.symm⟩
    | cons next rest => exact ih (by simp) sorted.2 ⟨root, sorted.1.symm⟩

private theorem fields_term {v : Val} {constructor : ConName} {values : List Val}
    (fields : conFields? v = some (constructor, values)) :
    v.toTerm? = some (.dataValue constructor (Val.toTermSlots values)) := by
  cases v <;> simp only [conFields?, Option.some.injEq, Prod.mk.injEq] at fields
  all_goals first | (cases fields; done) | skip
  case con c ts vs => obtain ⟨rfl, rfl⟩ := fields; rfl
  case atError detail =>
    obtain ⟨rfl, rfl⟩ := fields
    exact Detail.values_toTerm detail

private theorem slots_at {values : List Val} {i : Nat} {value : Val}
    (selected : values[i]? = some value) (η : ObservationEnvModel) :
    (observeSlots η (Val.toTermSlots values))[i]? = some (value.toTerm?.bind (Term.observe η)) := by
  induction values generalizing i with
  | nil => cases selected
  | cons v rest ih =>
    cases i with
    | zero =>
      cases Option.some.inj selected
      cases h : value.toTerm? <;> simp [Val.toTermSlots, observeSlots, h]
    | succ i =>
      cases h : v.toTerm? <;> simpa [Val.toTermSlots, observeSlots, h] using ih selected

theorem read_data {v w : Val} {route : List FieldRef}
    (nonempty : route ≠ []) (read : readPath v route = some w) :
    ∃ c fields, v.toTerm? = some (.dataValue c fields) := by
  cases route with
  | nil => contradiction
  | cons ref rest =>
    cases fields : conFields? v with
    | none => simp [readPath, fields] at read
    | some pair => exact ⟨pair.1, Val.toTermSlots pair.2, fields_term fields⟩

/-- 同じ欄の値の観測が存在すれば、経路の項の部分観測も同じ値になる。 -/
theorem read_observation {v w : Val} {route : List FieldRef} {t : Term} {sort : «Sort»}
    {η : ObservationEnvModel} {observed : Observation}
    (read : readPath v route = some w)
    (root : t.observe η = v.toTerm?.bind (Term.observe η))
    (sorted : RouteSorted route sort)
    (leaf : w.toTerm?.bind (Term.observe η) = some observed) (leafSort : observed.sort = sort) :
    (routeTerm t route).observe η = some observed := by
  induction route generalizing v t with
  | nil => cases Option.some.inj read; exact root.trans leaf
  | cons ref rest ih =>
    obtain ⟨constructor, values, hfields, hc, middle, hm, hr⟩ :
        ∃ constructor values, conFields? v = some (constructor, values) ∧
          constructor = ref.constructor ∧ ∃ middle,
            values[ref.position]? = some middle ∧ readPath middle rest = some w := by
      cases hf : conFields? v with
      | none => simp [readPath, hf] at read
      | some pair =>
        rcases pair with ⟨constructor, values⟩
        simp only [readPath, hf, Bind.bind, Option.bind] at read
        split at read
        · rename_i hc
          cases hm : values[ref.position]? with
          | none => simp [hm] at read
          | some middle => exact ⟨_, _, rfl, hc, middle, hm, by simpa [hm] using read⟩
        · cases read
    obtain ⟨middleObservation, hmiddle, hsort⟩ :
        ∃ o, middle.toTerm?.bind (Term.observe η) = some o ∧ o.sort = ref.result := by
      cases rest with
      | nil =>
        cases Option.some.inj hr
        exact ⟨observed, leaf, leafSort.trans sorted.symm⟩
      | cons next tail =>
        obtain ⟨c, fields, h⟩ := read_data (by simp) hr
        exact ⟨.dataValue c (observeSlots η fields), by rw [h]; rfl, sorted.1.symm⟩
    have hroot : t.observe η = some (.dataValue constructor (observeSlots η (Val.toTermSlots values))) := by
      rw [root, fields_term hfields]
      rfl
    have hfield : (Term.field ref t).observe η = middle.toTerm?.bind (Term.observe η) := by
      simp only [Term.observe, hroot, hc, Bind.bind, Option.bind,
        bne_self_eq_false, Bool.false_eq_true, ite_false]
      rw [slots_at hm η]
      simp only [Option.bind]
      cases ht : middle.toTerm? with
      | none => simp [ht] at hmiddle
      | some u =>
        have hu : u.observe η = some middleObservation := by simpa [ht] using hmiddle
        simp [hu, hsort]
    cases rest with
    | nil => cases Option.some.inj hr; exact hfield.trans leaf
    | cons next tail => exact ih hr hfield sorted.2

/-- 部分観測した同じ scalar に対し、通常の判定と閉じた述語は一致する。 -/
theorem predicate_observed (entry : Entry) (valid : entry.Valid) {c : Const} {t : Term}
    (tag : c.type.norm.core = .base entry.input) (closed : t.Closed)
    (shape : t.Shape [] entry.sort)
    (observed : t.observe (fun _ => none) = (Val.const c).toTerm?.bind (Term.observe (fun _ => none))) :
    (entry.predicate t).evalClosed = some (entry.run [.const c]) := by
  have hw : t.VarsIn (fun _ => False) := by simpa [Term.Closed, termWF] using closed
  have href : t.References [] := Term.varsIn_mono hw (fun _ h => h.elim)
  cases entry <;> try (rename_i w test; cases w using FloatWidth.casesOn <;> cases test)
  all_goals cases c <;> cases tag
  all_goals simp only [Val.toTerm?, Option.bind_some, Term.observe] at observed
  all_goals have interpreted := Term.observe_sound observed
  all_goals simp only [Entry.sort, Entry.Valid] at shape valid
  all_goals simp +decide [Entry.predicate, Entry.run,
    FloatTest.predicate, FloatTest.test, API.run,
    Pred.evalClosed, Pred.WF, Pred.VarsIn, Pred.Sorted, Term.HasSort,
    href, hw, shape, Pred.evalWith, Pred.atomReady, termReady,
    observed, Pred.atomValue, observeAs, interpreted, memberReady,
    RangeExpr.WF, Range.WF, RangeExpr.FitsKind, Range.FitsKind, Range.kind?,
    resolveSnapshot, valid, Observation.sort]
  all_goals rename_i bits
  all_goals first
    | (cases ieeeClass 23 8 bits.toNat .positiveInfinity <;>
        cases ieeeClass 23 8 bits.toNat .negativeInfinity <;> rfl)
    | (cases ieeeClass 52 11 bits.toNat .positiveInfinity <;>
        cases ieeeClass 52 11 bits.toNat .negativeInfinity <;> rfl)

end
end Benitoite.Release.Refinement.Surface.PredicateProjection
