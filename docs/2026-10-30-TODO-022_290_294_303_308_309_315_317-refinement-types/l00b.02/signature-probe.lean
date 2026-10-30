import Lean

/- 署名の表現だけを検査する。本番の規則・意味・保存の証明ではない。 -/
namespace SignatureProbe
inductive Term where
  | var (i : Nat)
  | integer (n : Int)
  | listValue (xs : List (Option Term))
  | mapValue (keys values : List (Option Term))
  | field (position : Nat) (receiver : Term)
  | add (left right : Term)
  deriving BEq


-- 構造の等号。言語の Map/Set の鍵の等値には使わない。
mutual
  def bindOptional (ν : Nat → Option Term) : Term → Option Term
    | .var i => ν i
    | .integer n => some (.integer n)
    | .listValue xs => some (.listValue (bindSlots ν xs))
    | .mapValue ks vs => some (.mapValue (bindSlots ν ks) (bindSlots ν vs))
    | .field i t => some (.field i ((bindOptional ν t).getD (.integer 0)))
    | .add l r => some (.add ((bindOptional ν l).getD (.integer 0))
        ((bindOptional ν r).getD (.integer 0)))
  def bindSlots (ν : Nat → Option Term) : List (Option Term) → List (Option Term)
    | [] => []
    | none :: xs => none :: bindSlots ν xs
    | some t :: xs => bindOptional ν t :: bindSlots ν xs
end

inductive Pred where
  | eq (l r : Term)
  | and (p q : Pred)
  deriving BEq
def predBind (ν : Nat → Option Term) : Pred → Pred
  | .eq l r => .eq ((bindOptional ν l).getD (.integer 0))
      ((bindOptional ν r).getD (.integer 0))
  | .and p q => .and (predBind ν p) (predBind ν q)

example : bindOptional (fun _ => none) (.listValue [some (.var 0)]) =
    some (.listValue [none]) := rfl

mutual
  inductive Typed : Nat → Prop where
    | capture : Captured → Typed 0
  inductive Captured : Prop where
    | mk : (∀ i : Nat, ImageOk i) → Captured
  inductive ImageOk : Nat → Prop where
    | ordinary (i : Nat) : Typed i → ImageOk i
    | contLoc (i l : Nat) : i = l → ImageOk i
    | contVar (i j : Nat) : i = j → ImageOk i
end
def SubstOk : Prop := ∀ i : Nat, ImageOk i

#check Term.rec
#check predBind
#check Captured.mk
#check SubstOk
#print axioms bindOptional
#print axioms predBind
end SignatureProbe

/- 全域の二値解釈と、観測不能で none を返す評価器の境界。
   本番 Pred の反例を実行したものではなく、完全性の言明の必要条件を検査する。 -/
namespace ClosedEvaluationBoundary
inductive ClosedPred where
  | unobservable
  | not (p : ClosedPred)
def interpret (b : Bool) : ClosedPred → Bool
  | .unobservable => b
  | .not p => !(interpret b p)
def evalClosed : ClosedPred → Option Bool
  | .unobservable => none
  | .not p => (evalClosed p).map Bool.not
theorem unconditional_complete_impossible (b : Bool) :
    ¬ (∀ p, interpret b p = true → evalClosed p = some true) := by
  cases b with
  | false =>
    intro h
    have he := h (.not .unobservable) rfl
    cases he
  | true =>
    intro h
    have he := h .unobservable rfl
    cases he
#print axioms unconditional_complete_impossible
end ClosedEvaluationBoundary
