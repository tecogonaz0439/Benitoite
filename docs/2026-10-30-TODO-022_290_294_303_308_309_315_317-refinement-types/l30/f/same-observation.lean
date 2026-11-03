import Benitoite.Release.Refinement.BuiltinLogic

open Benitoite.Release.Refinement
open BuiltinSchema

-- 本番の読者を持たない記録用の補助入力である。
theorem sameObservation_tautology {a b : Term} {p : Pred}
    (hp : p ∈ candidates .sameObservation [a, b]) : ∃ q, p = implies q q := by
  simp only [candidates] at hp
  split at hp
  · rename_i he
    have hab := (termEq_spec a b).mp he
    subst hab
    obtain ⟨s, _, rfl⟩ := List.mem_map.mp hp
    exact ⟨_, rfl⟩
  · simp at hp

-- 参照形は参照先そのものを返し、引数二項と原子の対応は要求しない。
example : PreparedLeaf.checkRaw [.le (.var 3) (.integer 1)]
    ⟨.le (.var 3) (.integer 1), .sameObservation, [.var 7, .var 7], [0]⟩ = true := by decide
