import Benitoite.Release.Refinement.StepLeafSelection
import Benitoite.Release.Refinement.NormalReplyExamples

/-! # escape と通常の pop のソース入力と読者 -/
namespace Benitoite.Release.Refinement

/-- 行先の型付けを含まない、制御の七遷移の入力。 -/
inductive ControlLeafInputs (P : Program) (B : Builtins) (σ : PathEnv) :
    State → Option Event → State → Prop where
  | E_EscLet {v n k μ} {q : Closure} :
      q.view = (.escape v) →
      ControlLeafInputs P B σ (.run q (.letF n :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscHandle {v h k μ} {q : Closure} {hcap : Capture} :
      q.view = (.escape v) →
      ControlLeafInputs P B σ (.run q (.handleF hcap h :: k) μ) none (.run (Closure.pure (.escape v)) k μ)
  | E_EscMark {v k μ} {q : Closure} :
      q.view = (.escape v) →
      ControlLeafInputs P B σ (.run q (.mark :: k) μ) none (.run (Closure.pure (.ret v)) k μ)
  
  | E_ErrPopLet {rs n k μ} : ControlLeafInputs P B σ (.error rs (.letF n :: k) μ) none (.error rs k μ)
  | E_ErrPopMark {rs k μ} : ControlLeafInputs P B σ (.error rs (.mark :: k) μ) none (.error rs k μ)
  | E_ExitPopLet {n rs m k μ} : ControlLeafInputs P B σ (.exit n rs (.letF m :: k) μ) none (.exit n rs k μ)
  | E_ExitPopMark {n rs k μ} : ControlLeafInputs P B σ (.exit n rs (.mark :: k) μ) none (.exit n rs k μ)

noncomputable section

theorem StateTyE.control_leaf {P B σ Eb s event dest}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb s) (hi : ControlLeafInputs P B σ s event dest) :
    Step P B σ s event dest ∧ StateTyE P B σ Eb dest ∧ LocalStateInvariant P B σ dest := by
  have result : Step P B σ s event dest ∧ StateTyE P B σ Eb dest := by
    cases hi with
    | E_EscLet hv => exact h.escape_let hP hPB hB hv
    | E_EscHandle hv => exact h.escape_handler hP hPB hB hv
    | E_EscMark hv => exact h.escape_mark hP hPB hB hv
    | E_ErrPopLet => exact h.error_let
    | E_ErrPopMark => exact h.error_mark
    | E_ExitPopLet => exact h.exit_let
    | E_ExitPopMark => exact h.exit_mark
  exact ⟨result.1,result.2,result.2.local_invariant⟩

private theorem control_for_model {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) none
        (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hq := ClosureTy.pure (B := B) (Ψ := StoreTy.empty)
    (.C_Escape (ε := Eff.empty) (.V_Const (c := .unit) (by trivial)) ha) ha.done_empty
    (by intro r hr; cases hr; exact ⟨trivial,trivial⟩) rfl (by intro r hr; cases hr; rfl)
  have hk := ContTy.K_Mark (ContTy.K_Empty (R := none) (P := P) (B := B) (σ := σ)
    (Ψ := StoreTy.empty) (show Eff.Sub Eff.empty Eff.empty from ⟨fun _ h => h,fun _ h => h⟩) ha) ha
  have hs : StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) :=
    ⟨StoreTy.empty,some (.base .unit),.base .unit,.base .unit,Eff.empty,Eff.empty,
      StoreOk.empty _ _ σ,hq,⟨fun _ h => h,fun _ h => h⟩,hk,by trivial,by trivial,
      (by intro f hf; cases List.mem_singleton.mp hf; trivial),(by intro l c h; cases h)⟩
  obtain ⟨ht,hd,_⟩ := hs.control_leaf hP hPB hB (.E_EscMark rfl)
  exact ⟨ht,hd⟩

private theorem other_control_for_model {P B σ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) :
    (Step P B σ (.error [rResume] [.mark] Store.empty) none (.error [rResume] [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.error [rResume] [] Store.empty)) ∧
    (Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.handleF Capture.empty [],.mark] Store.empty) none
        (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty)) := by
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hq := ClosureTy.pure (B := B) (Ψ := StoreTy.empty)
    (.C_Escape (ε := Eff.empty) (.V_Const (c := .unit) (by trivial)) ha) ha.done_empty
    (by intro r hr; cases hr; exact ⟨trivial,trivial⟩) rfl (by intro r hr; cases hr; rfl)
  have hk := ContTy.K_Mark (ContTy.K_Empty (R := none) (P := P) (B := B) (σ := σ)
    (Ψ := StoreTy.empty) (show Eff.Sub Eff.empty Eff.empty from ⟨fun _ h => h,fun _ h => h⟩) ha) ha
  have he : StateTyE P B σ Eff.empty (.error [rResume] [.mark] Store.empty) :=
    ⟨StoreTy.empty,some (.base .unit),.base .unit,.base .unit,Eff.empty,StoreOk.empty _ _ σ,hk,
      (by intro f hf; cases List.mem_singleton.mp hf; trivial),(by intro l c h; cases h)⟩
  have hh : ContTy P B σ StoreTy.empty (some (.base .unit)) Eff.empty
      [.handleF Capture.empty [],.mark] (.base .unit) (.base .unit) Eff.empty none :=
    .K_Handle (Γ := []) (Φ := []) (Rs := some (.base .unit)) (ts := .base .unit)
      (ecs := Eff.empty) (ebs := Eff.empty) hk (Eff.Covers.refl [] [] Eff.empty)
      ⟨(by intro a ha; cases ha),(by intro a ha; obtain ⟨x,hx,_⟩ := ha; cases hx)⟩
      (CaptureOk.empty _ _ _ (some (.base .unit))) .nil rfl rfl
      (by simp only [Capture.closeEff,substEffValues_empty])
      (by simp only [Capture.closeEff,substEffValues_empty]) ha.done_empty ha
      (by intro a hh; cases hh; trivial) (by trivial)
  have hs : StateTyE P B σ Eff.empty
      (.run (Closure.pure (.escape (.const .unit))) [.handleF Capture.empty [],.mark] Store.empty) :=
    ⟨StoreTy.empty,some (.base .unit),.base .unit,.base .unit,Eff.empty,Eff.empty,
      StoreOk.empty _ _ σ,hq,⟨fun _ h => h,fun _ h => h⟩,hh,by trivial,by trivial,
      (by intro f hf; simp only [List.mem_cons,List.not_mem_nil,or_false] at hf
          rcases hf with rfl | rfl <;> trivial),(by intro l c h; cases h)⟩
  obtain ⟨te,de,_⟩ := he.control_leaf hP hPB hB .E_ErrPopMark
  obtain ⟨ts,ds,_⟩ := hs.control_leaf hP hPB hB (.E_EscHandle rfl)
  exact ⟨⟨te,de⟩,ts,ds⟩

/-- 同じ適格な表で、error の pop と空の handler を飛ばす escape に適用する。 -/
theorem concrete_other_control_leaves :
    ∃ P B σ, P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      (Step P B σ (.error [rResume] [.mark] Store.empty) none (.error [rResume] [] Store.empty) ∧
        StateTyE P B σ Eff.empty (.error [rResume] [] Store.empty)) ∧
      (Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.handleF Capture.empty [],.mark] Store.empty) none
          (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) ∧
        StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty)) := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  exact ⟨_,_,σ,hP,hPB,hB,hσ,other_control_for_model hP hPB hB⟩

/-- 同じ具体の表の証拠と、escape から mark への葉を同時に持つ。 -/
theorem concrete_control_leaf :
    ∃ P B σ, P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      Step P B σ (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) none
        (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  exact ⟨_,_,σ,hP,hPB,hB,hσ,control_for_model hP hPB hB⟩

end
end Benitoite.Release.Refinement
