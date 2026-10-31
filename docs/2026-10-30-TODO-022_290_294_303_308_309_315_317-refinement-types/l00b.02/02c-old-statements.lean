import Benitoite

namespace Benitoite.Release

example (n : Integer64Value) :
    min64 ≤ n.toInt ∧ n.toInt ≤ max64 := by
  apply Integer64Value.toInt_bounds <;> assumption

end Benitoite.Release

namespace Benitoite.Interval

open Benitoite.Release (min64 max64)

variable {kind : IntKind}

example (kind : IntKind) : kind.min ≤ kind.max := by
  apply IntKind.bounds <;> assumption

example (kind : IntKind) : IntKind.ofType kind.type = some kind := by
  apply IntKind.ofType_type <;> assumption

example {kind : IntKind} (value : IntegerValue kind) :
    kind.min ≤ value.toInt ∧ value.toInt ≤ kind.max := by
  apply IntegerValue.toInt_bounds <;> assumption

example (value lo hi : Int) (kind : IntKind := .integer64) :
    Mem value (normalize lo hi kind) ↔
      kind.min ≤ value ∧ value ≤ kind.max ∧ lo ≤ value ∧ value ≤ hi := by
  apply mem_normalize <;> assumption

example {value : Int} {i : Interval kind} (h : Mem value i) :
    kind.min ≤ value ∧ value ≤ kind.max := by
  apply mem_bounds <;> assumption

example (lo hi : Int) (valid : kind.min ≤ lo ∧ lo ≤ hi ∧ hi ≤ kind.max) :
    normalize lo hi kind = .closed lo hi valid := by
  apply normalize_closed <;> assumption

example (value : Int) (kind : IntKind := .integer64) :
    Mem value (top kind) ↔ kind.min ≤ value ∧ value ≤ kind.max := by
  apply mem_top <;> assumption

example (a b : Interval kind) :
    Subset a b ↔ ∀ value, Mem value a → Mem value b := by
  apply subset_iff <;> assumption

example (value : Int) (a b : Interval kind) :
    Mem value (meet a b) ↔ Mem value a ∧ Mem value b := by
  apply mem_meet <;> assumption

example {value : Int} {a b : Interval kind}
    (h : Mem value a ∨ Mem value b) : Mem value (join a b) := by
  apply mem_join <;> assumption

example {a b c : Interval kind} (ha : Subset a c) (hb : Subset b c) :
    Subset (join a b) c := by
  apply join_least <;> assumption

example {value : Int} {a b : Interval kind} (h : Mem value (meet a b)) :
    kind.min ≤ value ∧ value ≤ kind.max := by
  apply meet_bounds <;> assumption

example {value : Int} {a b : Interval kind} (h : Mem value (join a b)) :
    kind.min ≤ value ∧ value ≤ kind.max := by
  apply join_bounds <;> assumption

end Benitoite.Interval
