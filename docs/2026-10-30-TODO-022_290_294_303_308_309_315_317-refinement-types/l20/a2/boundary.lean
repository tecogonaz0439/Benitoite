import Benitoite.Release.Refinement.CaptureRegularity
import Benitoite.Release.Refinement.DependentBeta

namespace L20A2
open Benitoite.Release.Refinement
noncomputable section

private theorem regular_empty (P : Program) : CaptureContextRegular P [] [] := by
  constructor
  · intro i a hi; cases hi
  · intro i a hi; cases hi

private theorem empty_wf : StoreTy.empty.WF := by intro l a hl; cases hl
private theorem empty_sorted : StoreTy.empty.Sorted := by intro l a hl; cases hl
private theorem empty_declared (P : Program) : StoreTy.Declared P StoreTy.empty := by
  intro l a hl; cases hl

def impossible : List Pred := [.compare .boolean .eq (.boolean true) (.boolean false)]

/-- 偽の Φ の下で、実際の let の二導出に開いた motive を適用する。 -/
theorem false_path_let (P : Program) (B : Builtins)
:
    Ty.Annotation P [] [] (.base .unit) := by
  have hm : HasTypeCQ P B StoreTy.empty Benitoite.Release.Qempty [] [] impossible none
      (.letIn (.ret (.const .unit)) (.ret (.var 0))) (.base .unit) Eff.empty [] :=
    .C_Let (.C_Return (.V_Const trivial))
      (.C_Return (.V_Var rfl (by simp [Ordinary, Ty.shiftV, Ty.core]))) trivial
  exact open_comp_annotation empty_wf empty_sorted (empty_declared P) (regular_empty P) hm

/-- 継続のソースの潜在行は Capture 三条件に足さず、resume の結果を形成する。 -/
theorem weak_context_resume (P : Program) (B : Builtins)
:
    let Γ : Ctx := [some (.cont (.base .unit) (.base .unit) (Eff.singleFail (.tvar 0)))]
    CaptureContextRegular P [] Γ ∧ Ty.Annotation P [] Γ (.base .unit) := by
  dsimp
  have hr : CaptureContextRegular P []
      [some (.cont (.base .unit) (.base .unit) (Eff.singleFail (.tvar 0)))] := by
    constructor
    · intro i a hi
      cases i with
      | zero => cases hi; exact ⟨trivial, trivial⟩
      | succ i => cases hi
    · intro i a hi
      cases i with
      | zero => cases hi; exact ⟨⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩
      | succ i => cases hi
  refine ⟨hr, ?_⟩
  apply open_comp_annotation (B := B) empty_wf empty_sorted (empty_declared P) hr
    (m := .resume (.var 0) (.const .unit)) (e := Eff.singleFail (.tvar 0)) (R := none) (L := [])
    (Φ := impossible) (Q := Benitoite.Release.Qempty)
  exact .C_Resume rfl (.V_Const trivial) trivial

/-- Each.nil の型は任意であり、非空条件なしの形成は偽である。 -/
theorem empty_each_unformed (P : Program) (B : Builtins) :
    HasTypeEachQ P B StoreTy.empty Benitoite.Release.Qempty [] [] impossible [] (.tvar 0) ∧
      ¬ Ty.Annotation P [] [] (.tvar 0) := by
  refine ⟨.nil, ?_⟩
  intro ha
  exact Nat.not_lt_zero 0 ha.wf

/-- escape の任意効果から全効果の形成を結論しない。結果型は形成済みである。 -/
theorem arbitrary_escape_effect (P : Program) (B : Builtins) :
    HasTypeCQ P B StoreTy.empty Benitoite.Release.Qempty [] [] [] (some (.base .unit))
      (.escape (.const .unit)) (.base .unit) (Eff.singleFail (.tvar 0)) [] ∧
    ¬ Ty.Annotation P [] [] (.dependentFn (.done (.base .unit) (Eff.singleFail (.tvar 0)))) := by
  refine ⟨.C_Escape (.V_Const trivial) ⟨trivial, trivial, trivial⟩, ?_⟩
  intro ha
  exact Nat.not_lt_zero 0 ha.wf.2.1.1

/-- 同じ未形成効果を handle の空節で隠すことはできない。 -/
theorem unformed_handle_bound_rejected (P : Program) (B : Builtins) :
    ¬ Eff.Sub (Eff.singleFail (.tvar 0)) (Eff.union Eff.empty (handled P B [])) := by
  intro hs
  have hh := hs.2 (.tvar 0) ⟨.tvar 0, by simp [Eff.singleFail, Eff.fails, Ty.norm], rfl⟩
  have hh := (Eff.norm_memFail _ _).mp hh
  obtain ⟨t, ht, _⟩ := hh
  cases ht

/-- 開いた生の eb が非正規でも、capture後の eb の全注釈を上限から供給する。 -/
theorem handle_nonnormal_inner (P : Program) (B : Builtins) :
    Ty.Annotation P [] [] (.dependentFn (.done (Capture.empty.closeTy (.base .unit))
      (Capture.empty.closeEff (EffR.mk (fun _ => false) [.base .unit, .base .unit])))) := by
  apply capture_handle_body_annotation (B := B) (h := [])
    (ec := Eff.singleFail (.base .unit))
  · exact ⟨⟨trivial, ⟨trivial, trivial⟩, rfl⟩, ⟨trivial, trivial, trivial⟩,
      ⟨trivial, trivial, trivial⟩⟩
  · constructor
    · intro a ha; cases ha
    · intro t ht
      obtain ⟨u, hu, he⟩ := ht
      rcases List.mem_cons.mp hu with rfl | hu
      · exact (Eff.norm_memFail _ _).mpr ⟨.base .unit, by simp [Eff.singleFail, handled, Eff.fails, Ty.norm], he⟩
      · cases List.mem_singleton.mp hu
        exact (Eff.norm_memFail _ _).mpr ⟨.base .unit, by simp [Eff.singleFail, handled, Eff.fails, Ty.norm], he⟩

/-- 失敗の rest は非Topの原子を保持してよく、形成に名前の全域条件は要らない。 -/
theorem failure_non_top_rest (P : Program) :
    Ty.Annotation P [] [] (.dependentFn (.done (.base .unit)
      (Eff.union (Eff.singleFail (.base .string))
        (.mk (fun a => decide (a = .name "localEffect" (.fixed (.absolute (.path (.tree ["data"])))))) [])))) := by
  refine failure_effect_upper_annotation (Q := Benitoite.Release.Qempty)
    (t := .base .unit) (E := .base .string) ⟨trivial, trivial, trivial⟩
    ⟨trivial, trivial, trivial⟩ ⟨rfl, ?_⟩
  intro i hi
  simp [Eff.test, Eff.atoms] at hi

/-- 実際の hide の下: 閉包の捕捉から thunk の本体へ適用する。 -/
theorem rv_thunk_body {P B Ψ R Γ Φ cap m a e L}
    (hA : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hm : HasTypeCQ P B (hideBuilders Ψ) Benitoite.Release.Qempty [] (hideConts Γ) Φ none m a e L) :
    Ty.Annotation P [] [] (cap.closeTy a) :=
  capture_comp_annotation hw.hide hs.hide hd.hide
    ((hc.store hA.values hw (StoreTy.preserves_hide Ψ)).hideConts_any (R' := none)) hm

/-- 実際の閉包: 通常の値と Fail を持つ継続の場所を捕捉した環境。 -/
def rvE : Eff := Eff.singleFail (.base .string)
def rvK : Ty := .cont (.base .unit) (.base .boolean) rvE
def rvΨ : StoreTy := fun l => if l = 0 then some (.cont (.base .unit) (.base .boolean) rvE none) else none

theorem rvE_canon : rvE.Canonical := by
  simp [rvE, Eff.Canonical, Eff.singleFail, Eff.norm, Ty.normTys, Ty.norm_idem]

theorem rvE_wf : Eff.WF 0 0 0 rvE := ⟨trivial, trivial⟩

theorem rvK_wf : rvK.WF 0 0 0 := ⟨trivial, trivial, rvE_wf, rvE_canon⟩

theorem rvK_close (cap : Capture) : cap.closeTy rvK = rvK := by
  have h := Ty.substV_of_wf_zero rvK_wf (valEnv cap.env).values
  have hn : rvK.norm = rvK := by
    have hc : rvE.norm = rvE := rvE_canon
    simp [rvK, Ty.norm, hc]
  exact h.trans hn

theorem rv_store : rvΨ.WF ∧ rvΨ.Sorted ∧ ∀ P, StoreTy.Declared P rvΨ := by
  refine ⟨?_, ?_, ?_⟩
  · intro l x hl
    simp only [rvΨ] at hl
    split at hl
    · cases hl; exact ⟨trivial, trivial, rvE_wf, rvE_canon, by simp⟩
    · cases hl
  · intro l x hl
    simp only [rvΨ] at hl
    split at hl
    · cases hl; exact ⟨trivial, trivial, trivial, trivial⟩
    · cases hl
  · intro P l x hl
    simp only [rvΨ] at hl
    split at hl
    · cases hl; exact ⟨trivial, trivial, ⟨trivial, trivial⟩, by simp⟩
    · cases hl

theorem rv_real_closure (P : Program) (B : Builtins)
    :
    ∃ Γ cap, Γ ≠ [] ∧ CaptureOk P B rvΨ none Γ [] cap ∧
      Ty.Annotation P [] [] (cap.closeTy (.base .boolean)) ∧
      Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy (.base .boolean)) (cap.closeEff (Eff.shiftV 1 0 rvE)))) := by
  obtain ⟨hw, hs, hd⟩ := rv_store
  have hc0 := CaptureOk.empty P B rvΨ none
  have hv : HasTypeVQ P B rvΨ Benitoite.Release.Qempty [] [] [] (.const .unit)
      (Capture.empty.closeTy (.base .unit)) := .V_Const trivial
  have hc1 := hc0.extend (a := .base .unit) ⟨trivial, trivial, trivial⟩ hv trivial
  have hc2 := hc1.extendCont (b := .base .unit) (t := .base .boolean) (e := rvE)
    (b' := .base .unit) (t' := .base .boolean) (e' := rvE) (l := 0)
    ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ (rvK_close _)
    (by rw [show Capture.closeTy _ (Ty.cont _ _ _) = rvK from rvK_close _]; exact rvK_wf)
    (by simp [rvΨ]) (by intro r hr; cases hr)
  have hb : HasTypeCQ P B rvΨ Benitoite.Release.Qempty [] (Ctx.extend (Ctx.extend [] (.base .unit)) rvK) [] none
      (.resume (.var 0) (.const .unit)) (.base .boolean) (Eff.shiftV 1 0 rvE) [] :=
    .C_Resume (b := .base .unit) (by rfl) (.V_Const trivial) trivial
  exact ⟨_, _, by simp [Ctx.extend], hc2, capture_comp_annotation hw hs (hd P) hc2 hb,
    hc2.continuation_result_effect hw hs (hd P) (i := 0) (b := .base .unit) rfl⟩

end
end L20A2
