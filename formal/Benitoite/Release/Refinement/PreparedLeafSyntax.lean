import Benitoite.Release.Refinement.CertificateSyntax

/-! # 登録済みの論理補題を指定する有限データ -/
namespace Benitoite.Release.Refinement

inductive BuiltinLemma where
  | closed | lengthNonnegative | measureNonnegative | booleanApart
  | compareComplement | charactersSubset | constructorApart | sameObservation
  | scalarOrder | characterCodeRange | characterCompare | floatCompareClass
  | fieldAtom (sort : «Sort») (constructors : List ConName)
  | measured
  deriving DecidableEq

structure PreparedLeaf where
  predicate : Pred
  lemma : BuiltinLemma
  arguments : List Term
  references : List Nat

end Benitoite.Release.Refinement
