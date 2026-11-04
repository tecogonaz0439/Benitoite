import Benitoite.Release.Refinement.FiniteStepPreservation

/-! # 指定した継続で最初に返却するまでの有限な実行 -/
namespace Benitoite.Release.Refinement

/-- 返却値の意味や型を含めず、実状態の構文だけで境界を定める。 -/
def ReturnAt (k : Cont) (state : State) : Prop :=
  ∃ q μ v, state = .run q k μ ∧ q.view = .ret v

/-- 途中の実状態は返却境界に当たらず、終点で初めて ret となる。 -/
inductive FirstReturn (P : Program) (B : Builtins) (σ : PathEnv) (k : Cont) :
    State → List Event → Closure → Store → Val → Prop where
  | done {q μ v} : q.view = .ret v →
      FirstReturn P B σ k (.run q k μ) [] q μ v
  | step {source next event events q μ v} :
      ¬ ReturnAt k source → Step P B σ source event next →
      FirstReturn P B σ k next events q μ v →
      FirstReturn P B σ k source (event.toList ++ events) q μ v

/-- この有限関係の全遷移は、同じ Steps と同じ正常な終点を持つ。 -/
theorem FirstReturn.steps {P B σ k source events q μ v}
    (h : FirstReturn P B σ k source events q μ v) :
    Steps P B σ source events (.run q k μ) ∧ q.view = .ret v := by
  induction h with
  | done normal => exact ⟨.nil,normal⟩
  | step _ move _ ih => exact ⟨.cons move ih.1,ih.2⟩

/-- 最初の返却の導出にも、同じ有限保存をそのまま適用できる。 -/
theorem FirstReturn.typed {P B σ Eb k source events q μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (initial : StateTyE P B σ Eb source)
    (h : FirstReturn P B σ k source events q μ v) :
    StateTyE P B σ Eb (.run q k μ) :=
  initial.steps_preserved hP hPB hdecl hB hσ h.steps.1

/-- 一つ多い let の枠の下での返却は、外側の返却境界ではない。 -/
theorem ReturnAt.not_let (k : Cont) (n q : Closure) (μ : Store) :
    ¬ ReturnAt k (.run q (.letF n :: k) μ) := by
  rintro ⟨r,store,v,eq,_⟩
  have lengths := congrArg List.length (State.run.inj eq).2.1
  simp at lengths

/-- 同じ継続にいるとき、ret以外のviewは返却境界ではない。 -/
theorem ReturnAt.not_view {k q μ} (h : ∀ v, q.view ≠ .ret v) :
    ¬ ReturnAt k (.run q k μ) := by
  rintro ⟨r,store,v,eq,normal⟩
  have eqs := State.run.inj eq
  cases eqs.1
  exact h v normal

/-- matchの探索状態そのものはretではない。 -/
theorem ReturnAt.not_match (k : Cont) (v : Val) (cap : Capture) (arms : List Arm)
    (next : Nat) (μ : Store) : ¬ ReturnAt k (.matchRun v cap arms next k μ) := by
  rintro ⟨q,store,x,eq,_⟩
  cases eq

/-- 継続の長さが違えば、指定した継続での返却ではない。 -/
theorem ReturnAt.not_length {k frames q μ} (different : frames.length ≠ k.length) :
    ¬ ReturnAt k (.run q frames μ) := by
  rintro ⟨r,store,v,eq,_⟩
  exact different (congrArg List.length (State.run.inj eq).2.1)

end Benitoite.Release.Refinement
