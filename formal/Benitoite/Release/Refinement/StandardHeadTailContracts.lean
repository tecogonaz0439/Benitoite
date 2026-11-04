import Benitoite.Release.Refinement.StandardListRemainingResponse
import Benitoite.Release.Refinement.StandardSafeBodies

/-! # head・tail・append の依存する長さの契約 -/
namespace Benitoite.Release.Refinement.StandardHeadTail
noncomputable section
set_option maxRecDepth 5000
set_option maxHeartbeats 2000000
set_option linter.unusedSimpArgs false

def length (t : Term) : Term := .measure .listLength t
def someField : FieldRef := ⟨"Option","Option.Some",0,.list⟩
def headPredicate (result xs : Term) : Pred :=
  .or (.not (.constructorIs result "Option.None")) (.eq (length xs) (.integer 0))
def tailPredicate (result xs : Term) : Pred := .and (headPredicate result xs)
  (.or (.not (.constructorIs result "Option.Some"))
    (.eq (length (.field someField result)) (.add (length xs) (.integer (-1)))))
def appendPredicate (result xs : Term) : Pred :=
  .eq (length result) (.add (length xs) (.integer 1))

/-- Noneから空列を導くため、headの応答に同じ入力列の長さを記す。 -/
def headSignature : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["xs"],[.list (.tvar 0)],
    .refined (.data "Option" [.tvar 0]) (headPredicate (.var 0) (.var 1)),
    Eff.empty,(fun _ ts => ts.length=1),.pure,none,[],.untargeted⟩
/-- 残りの列の一歩と累積の不変条件を結ぶため、Some欄の長さを記す。 -/
def tailSignature : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["xs"],[.list (.tvar 0)],
    .refined (.data "Option" [.list (.tvar 0)]) (tailPredicate (.var 0) (.var 1)),
    Eff.empty,(fun _ ts => ts.length=1),.pure,none,[],.untargeted⟩
/-- 累積に一要素を足す歩みで長さの不変条件を保つため、増分を記す。 -/
def appendSignature : PrimSig :=
  ⟨[TypeCtx.valueParam],0,["xs","x"],[.list (.tvar 0),.tvar 0],
    .refined (.list (.tvar 0)) (appendPredicate (.var 0) (.var 2)),
    Eff.empty,(fun _ ts => ts.length=1),.pure,none,[],.untargeted⟩

private theorem observeSlots_length (η : ObservationEnvModel) (xs : List (Option Term)) :
    (observeSlots η xs).length = xs.length := by
  induction xs with
  | nil => rfl
  | cons x xs ih => cases x <;> simp [observeSlots,ih]

/-- 任意の有限入力に対する実head応答。要素の観測可能性を仮定しない。 -/
theorem head_reply (a : Ty) (xs : List Val) :
    ∃ t, (StandardCollections.optionValue a xs.head?).toTerm? = some t ∧
      (headPredicate t (.listValue (Val.toTermSlots xs))).evalWith (fun _ => none) = some true := by
  cases xs with
  | nil =>
    refine ⟨_,rfl,?_⟩
    simp [headPredicate,length,Pred.evalWith,Pred.atomReady,Pred.atomValue,
      termReady,Term.observe,Term.interpret,integerAs,observeAs,Observation.sort,
      Observation.measure,Observation.integerD,observeSlots]
  | cons x xs =>
    refine ⟨_,rfl,?_⟩
    simp [headPredicate,length,Pred.evalWith,Pred.atomReady,Pred.atomValue,
      termReady,Term.observe,Term.interpret,integerAs,observeAs,Observation.sort,
      Observation.measure,Observation.integerD,observeSlots]

/-- 実tailのNone/Someの全有限入力。列の大きさを具体化しない。 -/
theorem tail_reply (a : Ty) (xs : List Val) :
    ∃ t, (StandardCollections.optionValue (.list a) (StandardListRemainingResponse.tail? xs)).toTerm? = some t ∧
      (tailPredicate t (.listValue (Val.toTermSlots xs))).evalWith (fun _ => none) = some true := by
  cases xs with
  | nil =>
    refine ⟨_,rfl,?_⟩
    simp [tailPredicate,headPredicate,length,someField,Pred.evalWith,Pred.atomReady,
      termReady,Term.observe,Observation.measure,Observation.sort,Pred.atomValue,
      integerAs,observeAs,Term.interpret,observeSlots]
  | cons x xs =>
    refine ⟨_,rfl,?_⟩
    simp [tailPredicate,headPredicate,length,someField,Pred.evalWith,Pred.atomReady,
      termReady,Term.observe,Observation.measure,Observation.sort,Pred.atomValue,
      integerAs,observeAs,Term.interpret,Val.toTerm?,Val.toTermSlots,observeSlots,
      observeSlots_length,Val.toTermSlots_eq_map,Observation.integerD,Int.natCast_add,Int.add_assoc]

/-- 実appendが返す同じ列の全有限入力。停止応答に長さを要求しない。 -/
theorem append_reply (xs : List Val) (x : Val) :
    (appendPredicate (.listValue (Val.toTermSlots (xs++[x]))) (.listValue (Val.toTermSlots xs))).evalWith (fun _ => none) = some true := by
  simp [appendPredicate,length,Pred.evalWith,Pred.atomReady,Pred.atomValue,termReady,
    Term.observe,Term.interpret,integerAs,observeAs,Observation.sort,Observation.measure,
    observeSlots_length,Val.toTermSlots_eq_map,Observation.integerD,Int.natCast_add]

/-- 三つの応答の字面を、通常の実δへの呼出しと照合する。 -/
theorem real_head (a : Ty) (xs : List Val) :
    StandardListRemainingResponse.delta .head "List.head" [a] [] [] [.list xs] =
      some (.val (StandardCollections.optionValue a xs.head?)) := by rfl

theorem real_tail (a : Ty) (xs : List Val) :
    StandardListRemainingResponse.delta .tail "List.tail" [a] [] [] [.list xs] =
      some (.val (StandardCollections.optionValue (.list a) (StandardListRemainingResponse.tail? xs))) := by rfl

theorem real_append (a : Ty) (xs : List Val) (x : Val) :
    StandardCollections.insertDelta "List.append" [a] [] [] [.list xs,x] = some (.val (.list (xs++[x]))) := by rfl

end
end Benitoite.Release.Refinement.StandardHeadTail
