import Benitoite.Release.Refinement.SafeCheckObservations

/-! # 事象を出さない段を許した模倣からの観測保存 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation.Trace
noncomputable section
open SafeCheckErasure CheckErasure

/-- 一段に対応する有限実行。対応する実行が空のときは、元の順位が減る。 -/
def Forward (P : Program) (B : Builtins) (Q : Program) (D : Builtins)
    (σ : PathEnv) (R : State → State → Prop) (rank : State → Nat) : Prop :=
  ∀ {s t label s'}, R s t → Step P B σ s label s' →
    ∃ t', Steps Q D σ t label.toList t' ∧ R s' t' ∧
      (Descends Q D σ t' t ∨ (label = none ∧ t' = t ∧ rank s' < rank s))

/-- 一段の模倣を、同じ順序の全事象列を持つ有限実行へ延ばす。 -/
theorem finite {P B Q D σ R rank s t events z}
    (forward : Forward P B Q D σ R rank) (related : R s t)
    (steps : Steps P B σ s events z) :
    ∃ z', Steps Q D σ t events z' ∧ R z z' := by
  induction steps generalizing t with
  | nil => exact ⟨_,.nil,related⟩
  | cons step rest ih =>
    obtain ⟨next,first,rel,_⟩ := forward related step
    obtain ⟨last,remaining,lastRel⟩ := ih rel
    exact ⟨last,steps_append first remaining,lastRel⟩

/-- 対応先の全選択が有限なら、順位が減る省略の段を含む元の全選択も有限である。 -/
theorem accessible {P B Q D σ R rank s t}
    (forward : Forward P B Q D σ R rank) (related : R s t)
    (target : Acc (Transition Q D σ) t) : Acc (Transition P B σ) s := by
  have paths := descends_accessible target
  induction paths generalizing s with
  | intro t ht ih =>
    have inner : ∀ n s, rank s = n → R s t → Acc (Transition P B σ) s := by
      intro n
      induction n using Nat.strongRecOn with
      | ind n smaller =>
        intro s same related
        refine Acc.intro s ?_
        intro next nextStep
        obtain ⟨label,step⟩ := nextStep
        obtain ⟨nextTarget,_,nextRel,progress⟩ := forward related step
        rcases progress with targetSteps | ⟨_,rfl,less⟩
        · exact ih _ targetSteps nextRel (targetSteps.acc target)
        · exact smaller (rank next) (by simpa only [same] using less) next rfl nextRel
    exact inner (rank s) s rfl related

/-- 両方向の一段の模倣は、停止と非停止を保存する。 -/
theorem divergence {P B Q D σ R leftRank rightRank s t}
    (forward : Forward P B Q D σ R leftRank)
    (backward : Forward Q D P B σ (fun t s => R s t) rightRank)
    (related : R s t) : Diverges P B σ s ↔ Diverges Q D σ t := by
  exact not_congr ⟨accessible backward related,accessible forward related⟩

/-- 無限実行の存在を、段の数が異なる両側で保存する。 -/
theorem infinite {P B Q D σ R leftRank rightRank s t}
    (forward : Forward P B Q D σ R leftRank)
    (backward : Forward Q D P B σ (fun t s => R s t) rightRank)
    (related : R s t) :
    (∃ labels, InfiniteExecution P B σ s labels) ↔
      (∃ labels, InfiniteExecution Q D σ t labels) := by
  rw [← diverges_iff_infinite,← diverges_iff_infinite]
  exact divergence forward backward related

/-- 同じ有限の事象列の後に無限実行を選べることを保存する。 -/
theorem diverging_prefixes {P B Q D σ R leftRank rightRank s t}
    (forward : Forward P B Q D σ R leftRank)
    (backward : Forward Q D P B σ (fun t s => R s t) rightRank)
    (related : R s t) (events : List Event) :
    (∃ z, Steps P B σ s events z ∧ Diverges P B σ z) ↔
      (∃ z, Steps Q D σ t events z ∧ Diverges Q D σ z) := by
  constructor
  · rintro ⟨z,steps,nontermination⟩
    obtain ⟨z',steps',rel⟩ := finite forward related steps
    exact ⟨z',steps',(divergence forward backward rel).mp nontermination⟩
  · rintro ⟨z,steps,nontermination⟩
    obtain ⟨z',steps',rel⟩ := finite backward related steps
    exact ⟨z',steps',(divergence forward backward rel).mpr nontermination⟩

/-- 対応する状態の終端観測は、事象を出さない有限実行で対応する。 -/
def TerminalForward {Observation : Type} (Q : Program) (D : Builtins) (σ : PathEnv)
    (R : State → State → Prop) (left right : State → Observation → Prop) : Prop :=
  ∀ {s t observation}, R s t → left s observation →
    ∃ t', Steps Q D σ t [] t' ∧ right t' observation

/-- 全事象列と終端観測の同値は、一段の模倣と終端の対応から従う。 -/
theorem observations {Observation : Type} {P B Q D σ R leftRank rightRank s t}
    {left right : State → Observation → Prop}
    (forward : Forward P B Q D σ R leftRank)
    (backward : Forward Q D P B σ (fun t s => R s t) rightRank)
    (terminalForward : TerminalForward Q D σ R left right)
    (terminalBackward : TerminalForward P B σ (fun t s => R s t) right left)
    (related : R s t) (events : List Event) (observation : Observation) :
    (∃ z, Steps P B σ s events z ∧ left z observation) ↔
      (∃ z, Steps Q D σ t events z ∧ right z observation) := by
  constructor
  · rintro ⟨z,steps,terminal⟩
    obtain ⟨z',steps',rel⟩ := finite forward related steps
    obtain ⟨last,completion,observed⟩ := terminalForward rel terminal
    exact ⟨last,by simpa only [List.append_nil] using steps_append steps' completion,observed⟩
  · rintro ⟨z,steps,terminal⟩
    obtain ⟨z',steps',rel⟩ := finite backward related steps
    obtain ⟨last,completion,observed⟩ := terminalBackward rel terminal
    exact ⟨last,by simpa only [List.append_nil] using steps_append steps' completion,observed⟩

/-- 同じ事象列についての効果の被覆は、終端観測の同値と表の被覆の一致から従う。 -/
theorem effects {Observation : Type} {P B Q D σ R leftRank rightRank s t}
    {left right : State → Observation → Prop}
    (forward : Forward P B Q D σ R leftRank)
    (backward : Forward Q D P B σ (fun t s => R s t) rightRank)
    (terminalForward : TerminalForward Q D σ R left right)
    (terminalBackward : TerminalForward P B σ (fun t s => R s t) right left)
    (related : R s t) (Γ : Ctx) (Φ : List Pred) (ε : Eff)
    (covered : ∀ ev, Event.Covered B Γ Φ ε ev ↔ Event.Covered D Γ Φ ε ev)
    (events : List Event) (observation : Observation) :
    (∃ z, Steps P B σ s events z ∧ left z observation ∧
      ∀ ev ∈ events, Event.Covered B Γ Φ ε ev) ↔
      (∃ z, Steps Q D σ t events z ∧ right z observation ∧
        ∀ ev ∈ events, Event.Covered D Γ Φ ε ev) := by
  constructor
  · rintro ⟨z,steps,terminal,coverage⟩
    obtain ⟨z',steps',terminal'⟩ :=
      (observations forward backward terminalForward terminalBackward related events observation).mp
        ⟨z,steps,terminal⟩
    exact ⟨z',steps',terminal',fun ev mem => (covered ev).mp (coverage ev mem)⟩
  · rintro ⟨z,steps,terminal,coverage⟩
    obtain ⟨z',steps',terminal'⟩ :=
      (observations forward backward terminalForward terminalBackward related events observation).mpr
        ⟨z,steps,terminal⟩
    exact ⟨z',steps',terminal',fun ev mem => (covered ev).mpr (coverage ev mem)⟩

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation.Trace
