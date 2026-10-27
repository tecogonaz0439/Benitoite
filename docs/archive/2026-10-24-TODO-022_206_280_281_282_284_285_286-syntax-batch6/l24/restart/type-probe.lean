import Benitoite.Interval.Eval
open Benitoite.Interval Benitoite.Release
example (positions : List Nat) (n : Nat) : Decidable (positions.Perm (List.range n)) := inferInstance
example (types : List Ty) (n : Nat) : Decidable ((match types[n]? with | some (.base .integer) => true | _ => false : Bool) = true) := inferInstance
