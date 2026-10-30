import Benitoite.Release.Refinement.Capture
import Benitoite.Release.Refinement.BuilderExec

namespace Benitoite.Release.Refinement

inductive Frame where
  | letF (body : Closure)
  | mark
  | update (location : Nat)
  | release (resource : Val)
  | handleF (capture : Capture) (clauses : List Clause)
  | drop (continuation : Nat)
  | guardF (value : Val) (capture : Capture) (arms : List Arm) (next : Nat) (body : Closure)

abbrev Cont := List Frame

inductive Cell where
  | builder (contents : BuilderContents)
  | val (value : Val)
  | thunk (body : Closure)
  | done (value : Val)
  | cont (continuation : Cont)
  | used

abbrev Store := Nat → Option Cell

def Store.empty : Store := fun _ => none
def Store.set (μ : Store) (l : Nat) (c : Cell) : Store := fun l' => if l' = l then some c else μ l'

inductive State where
  | run (computation : Closure) (continuation : Cont) (store : Store)
  | matchRun (value : Val) (capture : Capture) (arms : List Arm) (next : Nat) (continuation : Cont) (store : Store)
  | error (errors : List ErrKind) (continuation : Cont) (store : Store)
  | exit (code : Int) (errors : List ErrKind) (continuation : Cont) (store : Store)

inductive Event where
  | io (name : PrimName) (arguments : List Val) (outcome : Outcome) (observed : List Scope.Domain.Target)
  | release (value : Val) (error : Option ErrKind)

end Benitoite.Release.Refinement
