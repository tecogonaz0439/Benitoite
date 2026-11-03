import Benitoite.Release.Refinement.LinearCombination
import Benitoite.Release.Refinement.BuiltinLogic

/-! # 枝内の先行参照を持つ有限の反証 -/
namespace Benitoite.Release.Refinement

inductive Refutation where
  | consume (next : Refutation)
  | cases (left right : Refutation)
  | derive (step : LinearStep) (next : Refutation)
  | closeLinear (index : Nat)
  | closeAtom (positive negative : Nat)
  | split (key : Nat) (cut : Int) (left right : Refutation)
  | discardTodo (next : Refutation)
  | discardFact (index : Nat) (next : Refutation)
  | builtin (leaf : PreparedLeaf) (next : Refutation)

namespace CertificateKernel

def consume (next : List NNF → List NNF → Bool) (todo facts : List NNF) : Bool :=
  match todo with
  | .truth :: rest => next rest facts
  | .falsity :: _ => true
  | .linear l :: rest => next rest (facts ++ [.linear l])
  | .literal p n :: rest => next rest (facts ++ [.literal p n])
  | .and p q :: rest => next (p::q::rest) facts
  | _ => false

def cases (left right : List NNF → List NNF → Bool) (todo facts : List NNF) : Bool :=
  match todo with
  | .or p q :: rest => left (p::rest) facts && right (q::rest) facts
  | _ => false

def splitLeft (n key : Nat) (cut : Int) : NNF :=
  .linear ⟨keyCoefficients n key, cut⟩
def splitRight (n key : Nat) (cut : Int) : NNF :=
  .linear ⟨(keyCoefficients n key).map ((-1) * ·), -(cut+1)⟩

def split (keys : KeyTable) (todo facts : List NNF) (key : Nat) (cut : Int)
    (left right : List NNF → List NNF → Bool) : Bool :=
  match keys[key]? with
  | none => false
  | some _ => left todo (facts ++ [splitLeft keys.length key cut]) &&
      right todo (facts ++ [splitRight keys.length key cut])

def closeLinear (facts : List NNF) (i : Nat) : Bool :=
  match facts[i]? with
  | some (.linear l) => decide (l.coefficients = List.replicate l.coefficients.length 0 ∧ l.bound < 0)
  | _ => false

def closeAtom (facts : List NNF) (positive negative : Nat) : Bool :=
  match facts[positive]?, facts[negative]? with
  | some (.literal p false), some (.literal q true) => predEq p q
  | _, _ => false

def discardTodo (next : List NNF → List NNF → Bool) (todo facts : List NNF) : Bool :=
  match todo with
  | _::rest => next rest facts
  | [] => false

def discardFact (next : List NNF → List NNF → Bool) (todo facts : List NNF) (i : Nat) : Bool :=
  if i < facts.length then next todo (facts.eraseIdx i) else false

/-- 組込みの葉を再検査し、再計算したNNFを同じ枝へ追加する。 -/
def refute (keys : KeyTable) (todo facts : List NNF) : Refutation → Bool
  | .consume c => consume (fun todo facts => refute keys todo facts c) todo facts
  | .cases l r => cases (fun todo facts => refute keys todo facts l)
      (fun todo facts => refute keys todo facts r) todo facts
  | .derive step c => step.check keys.length facts &&
      refute keys todo (facts ++ [.linear step.result]) c
  | .split key cut l r => split keys todo facts key cut
      (fun todo facts => refute keys todo facts l) (fun todo facts => refute keys todo facts r)
  | .closeLinear i => closeLinear facts i
  | .closeAtom p n => closeAtom facts p n
  | .discardTodo c => discardTodo (fun todo facts => refute keys todo facts c) todo facts
  | .discardFact i c => discardFact (fun todo facts => refute keys todo facts c) todo facts i
  | .builtin l c =>
      l.checkRaw (facts.map (NNF.toPred keys)) &&
        match normalize keys l.predicate false with
        | some q => refute keys (q::todo) facts c
        | none => false

end CertificateKernel
end Benitoite.Release.Refinement
