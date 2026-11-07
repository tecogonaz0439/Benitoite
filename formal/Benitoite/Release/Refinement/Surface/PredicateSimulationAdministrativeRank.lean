import Benitoite.Release.Refinement.Surface.PredicateSimulationScalarControl
import Benitoite.Release.Refinement.Surface.PredicateSimulationProjectionInputs

/-! # 判定呼出しの管理用の段の下降順位

元のgetter宣言を参照して、let/returnとgetterの呼出し・照合・markを数える。
継続の残りも同じ順位へ含め、任意の外側の継続の下で下降を保つ。
-/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open PredicateRows PredicateResponse
noncomputable section

def administrativeCodeCost (source : Program) : Comp → Nat
  | .letIn first rest => 2 + administrativeCodeCost source first + administrativeCodeCost source rest
  | .app (.fnRef name _ _ _) _ => if (source.accessors name).isSome then 4 else 0
  | .match _ _ => 2
  | _ => 0

def administrativeFrameCost (source : Program) : Frame → Nat
  | .letF body => 1 + administrativeCodeCost source body.code
  | .mark => 1
  | _ => 0

def administrativeContCost (source : Program) : Cont → Nat
  | [] => 0
  | frame :: rest => administrativeFrameCost source frame + administrativeContCost source rest

def administrativeRank (source : Program) : State → Nat
  | .run body continuation _ => administrativeCodeCost source body.code + administrativeContCost source continuation
  | .matchRun _ _ _ _ continuation _ => 1 + administrativeContCost source continuation
  | .error _ continuation _ | .exit _ _ continuation _ => administrativeContCost source continuation

theorem administrativeCodeCost_scalarChain (source : Program) (api : API) (positions : List Nat)
    (values : List Val) (depth : Nat) (remaining : List Val) :
    administrativeCodeCost source (letChain depth (remaining.map Comp.ret) (scalarBody api positions values)) = 2 * remaining.length := by
  induction remaining generalizing depth with
  | nil => rfl
  | cons value remaining ih =>
    change 2 + 0 + administrativeCodeCost source (letChain (depth+1) (remaining.map Comp.ret) (scalarBody api positions values)) = _
    rw [ih]
    simp only [List.length_cons]
    omega

theorem ScalarPhase.administrativeRank {source api positions values cap continuation store state rank}
    (phase : ScalarPhase api positions values cap continuation store state rank) :
    administrativeRank source state = rank + administrativeContCost source continuation := by
  cases phase with
  | chain before remaining split =>
    change administrativeCodeCost source (letChain before.length (remaining.map Comp.ret) (scalarBody api positions values)) + _ = _
    rw [administrativeCodeCost_scalarChain]
  | argument before value remaining split =>
    change 0 + (1 + administrativeCodeCost source (letChain (before.length+1) (remaining.map Comp.ret) (scalarBody api positions values)) +
      administrativeContCost source continuation) = _
    rw [administrativeCodeCost_scalarChain]
    omega

theorem administrative_let_decreases (source : Program) (cap : Capture) (first rest : Comp) (k : Cont) (μ : Store) :
    administrativeRank source (.run (.mk cap first) (.letF (.mk cap rest) :: k) μ) <
      administrativeRank source (.run (.mk cap (.letIn first rest)) k μ) := by
  change administrativeCodeCost source first + (1 + administrativeCodeCost source rest + administrativeContCost source k) <
    2 + administrativeCodeCost source first + administrativeCodeCost source rest + administrativeContCost source k
  omega

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
