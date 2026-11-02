import Benitoite.Release.Refinement.ClosedEvaluation

/-! # 有限の線形式と述語への符号化 -/
namespace Benitoite.Release.Refinement

structure Linear where
  coefficients : List Int
  bound : Int
  deriving DecidableEq

def linearDot : List Int → (Nat → Int) → Int
  | [], _ => 0
  | c :: cs, ρ => c * ρ 0 + linearDot cs (fun i => ρ (i+1))

def Linear.eval (l : Linear) (ρ : Nat → Int) : Int := linearDot l.coefficients ρ
def Linear.Holds (l : Linear) (ρ : Nat → Int) : Prop := l.eval ρ ≤ l.bound

def linearTerm : List Term → List Int → Term
  | k::ks, c::cs => .add (.scale c k) (linearTerm ks cs)
  | _, _ => .integer 0

def Linear.toPred (keys : List Term) (l : Linear) : Pred :=
  .le (linearTerm keys l.coefficients) (.integer l.bound)

theorem linearTerm_bind (ν : ObservationEnv) (keys : List Term) (cs : List Int) :
    termBind ν (linearTerm keys cs) = linearTerm (keys.map (termBind ν)) cs := by
  induction keys generalizing cs with
  | nil => cases cs <;> rfl
  | cons k ks ih =>
    cases cs with
    | nil => rfl
    | cons c cs =>
      simp only [linearTerm, termBind_add, termBind_scale, List.map_cons]
      exact congrArg (Term.add (.scale c (termBind ν k))) (ih cs)

theorem Linear.encode_bind (ν : ObservationEnv) (keys : List Term) (l : Linear) :
    predBind ν (l.toPred keys) = l.toPred (keys.map (termBind ν)) := by
  simp only [Linear.toPred, predBind, linearTerm_bind, termBind_integer]

end Benitoite.Release.Refinement
