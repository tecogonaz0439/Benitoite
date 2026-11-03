import Benitoite.Release.Refinement.RefutationSyntax
import Benitoite.Release.Refinement.EqProofSyntax

/-! # 有限な証明書と実際の式から再計算する鍵 -/
namespace Benitoite.Release.Refinement

inductive Certificate where
  | use (index : Nat)
  | leaf (value : PreparedLeaf)
  | substitute (predicate : Pred) (left right : Term) (eq : EqProof)
      (proof : Certificate) (mode : EqualityMode)
  | consume (next : Certificate)
  | cases (left right : Certificate)
  | discard (next : Certificate)
  | refute (proof : Refutation)

def Term.linearKeys : Term → KeyTable
  | .integer _ => []
  | .add a b => a.linearKeys ++ b.linearKeys
  | .neg a | .scale _ a => a.linearKeys
  | t => [t]

def Pred.linearKeys : Pred → KeyTable
  | .eq a b | .le a b | .lt a b => a.linearKeys ++ b.linearKeys
  | .and p q | .or p q => p.linearKeys ++ q.linearKeys
  | .not p => p.linearKeys
  | _ => []

def Refutation.keys : Refutation → KeyTable
  | .consume c | .derive _ c | .discardTodo c | .discardFact _ c => c.keys
  | .cases l r | .split _ _ l r => l.keys ++ r.keys
  | .builtin l c => l.predicate.linearKeys ++ c.keys
  | .closeLinear _ | .closeAtom _ _ => []

def Certificate.extraKeys : Certificate → KeyTable
  | .use _ => []
  | .leaf l => l.predicate.linearKeys
  | .substitute p t u _ c _ => (p.open t).linearKeys ++ (p.open u).linearKeys ++ c.extraKeys
  | .consume c | .discard c => c.extraKeys
  | .cases l r => l.extraKeys ++ r.extraKeys
  | .refute c => c.keys

def Certificate.keys (premise goal : Pred) (c : Certificate) : KeyTable :=
  premise.linearKeys ++ goal.linearKeys ++ c.extraKeys

end Benitoite.Release.Refinement
