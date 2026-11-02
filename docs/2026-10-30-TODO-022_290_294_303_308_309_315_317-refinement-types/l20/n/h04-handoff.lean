import Benitoite

open Benitoite.Release.Refinement
open Benitoite.Release.Refinement.IntervalConnection

-- L40 H04 が証明する候補の完全な型。宣言・公理・定理の仮置きではない。
-- 同じ入力・同じ独立評価・同じ trace の拒否理由から mayFail を導く。
#check (∀ (abstract : Benitoite.Interval.AbstractEnv) (concrete : Benitoite.Interval.ConcreteEnv)
    (input : Benitoite.Interval.EvalInput) (parameters : Benitoite.Interval.BudgetAnalysis.Parameters)
    (reason : Benitoite.Interval.Failure) (trace : Benitoite.Interval.EvalTrace),
    Benitoite.Interval.Models abstract concrete →
    Benitoite.Interval.EvalPartial concrete input (.failed reason) trace →
    TrackedFailure reason trace →
    (Benitoite.Interval.BudgetAnalysis.analyze abstract input parameters).mayFail = true : Prop)

namespace Benitoite.Release.Refinement.IntervalConnection.H04

/-- 選んだ同じ実行経路について、まだ error に入っていないことを示す。 -/
def BeforeError : State → Prop
  | .error .. => False
  | _ => True

inductive BeforeErrorSteps (P : Program) (B : Builtins) (σ : PathEnv) :
    State → List Event → State → Prop where
  | nil {s} : BeforeError s → BeforeErrorSteps P B σ s [] s
  | cons {s t u event events} : BeforeError s → Step P B σ s event t →
      BeforeErrorSteps P B σ t events u →
      BeforeErrorSteps P B σ s (event.toList ++ events) u

/-- 最初の失敗の位置と、その位置で実際に拒否した pure の δ だけを観測する。 -/
def FirstFailureHandoff : Prop :=
  ∀ (P : Program) (B : Builtins) (σ : PathEnv) (q : Closure) (k : Cont) (μ : Store)
    (events : List Event) (errors : List ErrKind) (lastK : Cont) (lastStore : Store),
    Steps P B σ (.run q k μ) events (.error errors lastK lastStore) →
    ∃ (preEvents : List Event) (before : State) (event : Option Event)
      (firstErrors : List ErrKind) (firstK : Cont) (firstStore : Store) (suffix : List Event),
      BeforeErrorSteps P B σ (.run q k μ) preEvents before ∧
      Step P B σ before event (.error firstErrors firstK firstStore) ∧
      Steps P B σ (.error firstErrors firstK firstStore) suffix (.error errors lastK lastStore) ∧
      events = preEvents ++ event.toList ++ suffix ∧
      ∀ (focus : Closure) (atK : Cont) (atStore : Store) (b : PrimName)
        (ts : List Ty) (es : List Eff) (ranges : List RangeExpr) (ws : List Val) (sg : PrimSig),
        before = .run focus atK atStore → focus.view = .app (.prim b ts es ranges) ws →
        B.sig b = some sg → sg.kind = .pure →
        event = none ∧ ∃ r, firstErrors = [r] ∧ B.delta b (Ty.normTys ts) (es.map Eff.norm) ranges ws = some (.err r)

end Benitoite.Release.Refinement.IntervalConnection.H04

-- 第二候補は同じ有限な実行の最初の失敗の位置を特定する。
#check (H04.FirstFailureHandoff : Prop)

#print H04.FirstFailureHandoff
