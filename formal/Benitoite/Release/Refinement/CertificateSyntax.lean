import Benitoite.Release.Refinement.LinearSyntax
import Benitoite.Release.Refinement.TermStructuralEq

/-! # 論理の検査で使う有限の鍵と否定標準形 -/
namespace Benitoite.Release.Refinement

abbrev KeyTable := List Term

/-- 最初の構造一致の位置。相異性は要求せず、未登録の項は拒否する。 -/
def keyIndex : KeyTable → Term → Option Nat
  | [], _ => none
  | k::ks, t => if termEq k t then some 0 else (keyIndex ks t).map (·+1)

theorem keyIndex_sound {keys : KeyTable} {t : Term} {i : Nat}
    (h : keyIndex keys t = some i) : keys[i]? = some t := by
  induction keys generalizing i with
  | nil => simp [keyIndex] at h
  | cons k ks ih =>
    simp only [keyIndex] at h
    split at h
    · rename_i he
      have := (termEq_spec k t).mp he
      subst t
      cases h
      rfl
    · obtain ⟨j, hj, rfl⟩ := Option.map_eq_some_iff.mp h
      exact ih hj

inductive NNF where
  | truth | falsity
  | linear (constraint : Linear)
  | literal (atom : Pred) (negative : Bool)
  | and (left right : NNF)
  | or (left right : NNF)

def NNF.toPred (keys : KeyTable) : NNF → Pred
  | .truth => .truth
  | .falsity => .falsity
  | .linear l => l.toPred keys
  | .literal p negative => if negative then .not p else p
  | .and p q => .and (p.toPred keys) (q.toPred keys)
  | .or p q => .or (p.toPred keys) (q.toPred keys)

end Benitoite.Release.Refinement
