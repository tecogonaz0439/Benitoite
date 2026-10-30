import Lean
namespace SignatureDecidableNegative
inductive Term where
  | var (i : Nat)
  | listValue (xs : List (Option Term))
  deriving DecidableEq
end SignatureDecidableNegative
