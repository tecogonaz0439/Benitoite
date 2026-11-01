import Benitoite.Release.Refinement.HandlerOperation
import Benitoite.Release.Refinement.LazyPreservation
import Benitoite.Release.Refinement.CapturedFacts

/-! StoreOk の Sorted と hide の境界。旧反例の型付けは残るが、新しいストアが拒む。 -/
namespace L20A1
open Benitoite.Release.Refinement
noncomputable section

def bad : Pred := .eq (.boolean true) (.boolean true)
def badT : Ty := .refined (.base .integer) bad

theorem bad_wf : badT.WF 0 0 0 := by
  simp [badT, bad, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, Ty.NotContCore, Ty.core]

theorem bad_declared (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx) :
    badT.Declared P C Γ := by
  simp [badT, bad, Ty.Declared, Pred.Declared, Term.Declared]

theorem bad_unsorted (Γ : Ctx) : ¬ badT.Sorted Γ := by
  simp [badT, bad, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape]

def one (x : LocTy) : StoreTy := fun l => if l = 0 then some x else none
def used : Store := fun l => if l = 0 then some .used else none

theorem rejected_used (P : Program) (B : Builtins) (σ : PathEnv) :
    ¬ StoreOk P B σ (one (.cont .bytes badT Eff.empty none)) used :=
  StoreOk.no_unsorted_cont_result (l := 0) rfl (bad_unsorted [])

/-- 旧反例の計算の型付け規則は変更していない。 -/
theorem counterexample_code_typed (P : Program) (B : Builtins) :
    HasTypeCQ P B (one (.cont .bytes badT Eff.empty none)) Benitoite.Release.Qempty
      [] [] [] none (.resume (.loc 0) (.bytesV [])) badT Eff.empty [] :=
  .C_ResumeL (l := 0) (b := .bytes) rfl (.V_Bytes (by simp)) (bad_declared P [] [])

/-- Sorted 以外の旧 StoreOk の全条件を満たすため、拒否理由を切り分けられる。 -/
theorem counterexample_other_fields (P : Program) (B : Builtins) (σ : PathEnv) :
    (∃ n, ∀ l, n ≤ l → used l = none) ∧
    (one (.cont .bytes badT Eff.empty none)).WF ∧
    StoreTy.Declared P (one (.cont .bytes badT Eff.empty none)) ∧
    (∀ l x, one (.cont .bytes badT Eff.empty none) l = some x → used l ≠ none) ∧
    (∀ l c, used l = some c → CellOk P B σ (one (.cont .bytes badT Eff.empty none)) l c) := by
  refine ⟨⟨1, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro l hl
    have : l ≠ 0 := by omega
    simp [used, this]
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [one] at hx; subst x
      exact ⟨trivial, bad_wf, by simp [Eff.WF, Eff.empty, Ty.WFList],
        by simp [Eff.Canonical, Eff.empty, Eff.norm], by simp⟩
    · simp [one, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [one] at hx; subst x
      exact ⟨trivial, bad_declared P [] [], by simp [declaredEff, Eff.empty, declaredTys], by simp⟩
    · simp [one, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [used]
    · simp [one, h] at hx
  · intro l c hc
    by_cases h : l = 0
    · subst l; simp [used] at hc; subst c
      exact ⟨.bytes, badT, Eff.empty, none, rfl⟩
    · simp [used, h] at hc

/-- r は WF と Declared だけを要求し、Sorted でない型も許す。 -/
theorem accepted_unsorted_return (P : Program) (B : Builtins) (σ : PathEnv) :
    StoreOk P B σ (one (.cont .bytes .bytes Eff.empty (some badT))) used := by
  refine ⟨⟨1, ?_⟩, ?_, ?_, ?_, ?_, ?_⟩
  · intro l hl
    have : l ≠ 0 := by omega
    simp [used, this]
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [one] at hx; subst x
      exact ⟨trivial, trivial, by simp [Eff.WF, Eff.empty, Ty.WFList],
        by simp [Eff.Canonical, Eff.empty, Eff.norm],
        by intro a ha; cases Option.some.inj ha; exact bad_wf⟩
    · simp [one, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [one] at hx; subst x
      exact ⟨trivial, trivial, by simp [sortedEff, sortedTys, Eff.empty]⟩
    · simp [one, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [one] at hx; subst x
      exact ⟨trivial, trivial, by simp [declaredEff, Eff.empty, declaredTys],
        by intro a ha; cases Option.some.inj ha; exact bad_declared P [] []⟩
    · simp [one, h] at hx
  · intro l x hx
    by_cases h : l = 0
    · subst l; simp [used]
    · simp [one, h] at hx
  · intro l c hc
    by_cases h : l = 0
    · subst l; simp [used] at hc; subst c
      exact ⟨.bytes, .bytes, Eff.empty, some badT, rfl⟩
    · simp [used, h] at hc

/-- 使用済みセルから両注釈を取り、結果は任意の文脈へ移せる。 -/
theorem used_annotations (P : Program) (B : Builtins) (σ : PathEnv)
    (C : List Benitoite.Release.TParam) (Γ : Ctx) :
    Ty.Annotation P C Γ Ty.bytes ∧
    Ty.Annotation P [] [] (.dependentFn (.done .bytes Eff.empty)) := by
  have hs := accepted_unsorted_return P B σ
  exact ⟨hs.cont_result_annotation (l := 0) rfl, hs.cont_annotation (l := 0) rfl⟩

theorem bytes_annotation (P : Program) : Ty.Annotation P [] [] Ty.bytes :=
  ⟨trivial, trivial, trivial⟩

theorem reference_allocate_write (P : Program) (B : Builtins) (σ : PathEnv)
    (hA : Builtins.ValueAssumptions P B) :
    let Ψ := StoreTy.empty.put 0 (.ref .bytes)
    let μ := Store.empty.set 0 (.val (.bytesV []))
    StoreOk P B σ Ψ μ ∧ StoreOk P B σ Ψ (μ.set 0 (.val (.bytesV []))) := by
  have hv : HasTypeV P B StoreTy.empty [] [] [] (.bytesV []) .bytes := .V_Bytes (by simp)
  have hs := (StoreOk.empty P B σ).allocate_reference hA (l := 0) rfl
    (bytes_annotation P) rfl hv trivial
  have hv' : HasTypeV P B (StoreTy.empty.put 0 (.ref .bytes)) [] [] [] (.bytesV []) .bytes :=
    .V_Bytes (by simp)
  exact ⟨hs, hs.write_reference (a := .bytes) (by simp [StoreTy.put]) rfl rfl hv' trivial⟩

theorem lazy_allocate_done (P : Program) (B : Builtins) (σ : PathEnv)
    (hA : Builtins.ValueAssumptions P B) :
    let q := Closure.pure (.ret (.bytesV []))
    let Ψ := StoreTy.empty.put 0 (.lazy .bytes)
    let μ := Store.empty.set 0 (.thunk q)
    StoreOk P B σ Ψ μ ∧ StoreOk P B σ Ψ (μ.set 0 (.done (.bytesV []))) := by
  have hq : ClosureTy P B (hideBuilders StoreTy.empty) [] none
      (Closure.pure (.ret (.bytesV []))) .bytes Eff.empty :=
    .pure (.C_Return (.V_Bytes (by simp)))
      ⟨⟨trivial, by simp [Eff.WF, Eff.empty, Ty.WFList],
          by simp [Eff.Canonical, Eff.empty, Eff.norm]⟩,
        ⟨trivial, by simp [sortedEff, sortedTys, Eff.empty]⟩,
        ⟨trivial, by simp [declaredEff, Eff.empty, declaredTys]⟩⟩
      (by simp) rfl (by simp)
  have hs := (StoreOk.empty P B σ).allocate_lazy hA (l := 0) rfl
    (bytes_annotation P) hq (by trivial)
  exact ⟨hs, hs.write_done (by simp [StoreTy.put]) (.V_Bytes (by simp)) trivial⟩

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

/-- handler で終わる継続を実際に割り当て、使用済みに更新した後も両注釈を得る。 -/
theorem continuation_allocate_use (P : Program) (B : Builtins) (σ : PathEnv)
    (hA : Builtins.ValueAssumptions P B) :
    let saved := [Frame.handleF Capture.empty []]
    let Ψ := StoreTy.empty.put 0 (.cont .bytes .bytes Eff.empty none)
    let μ := Store.empty.set 0 (.cont saved)
    StoreOk P B σ Ψ μ ∧ StoreOk P B σ Ψ (μ.set 0 .used) ∧
      Ty.Annotation P [] [] (.dependentFn (.done .bytes Eff.empty)) := by
  have ha := bytes_annotation P
  have han : Ty.Annotation P [] [] (.dependentFn (.done .bytes Eff.empty)) :=
    ⟨⟨ha.wf, by simp [Eff.WF, Eff.empty, Ty.WFList],
        by simp [Eff.Canonical, Eff.empty, Eff.norm]⟩,
      ⟨ha.sorted, by simp [sortedEff, sortedTys, Eff.empty]⟩,
      ⟨ha.declared, by simp [declaredEff, declaredTys, Eff.empty]⟩⟩
  have hk : ContTy P B σ StoreTy.empty none Eff.empty [Frame.handleF Capture.empty []]
      .bytes .bytes Eff.empty none :=
    .K_Handle (Γ := []) (Φ := []) (Rs := none) (ts := .bytes)
      (ecs := Eff.empty) (ebs := Eff.empty) (.K_Empty (empty_sub _) ha) (Eff.Covers.refl _ _ _) (empty_sub _)
      (CaptureOk.empty P B _ none) .nil rfl rfl (by simp [Capture.closeEff])
      (by simp [Capture.closeEff]) han ha (by simp) ⟨trivial, trivial⟩
  have hs := (StoreOk.empty P B σ).allocate_continuation hA (l := 0) rfl
    ⟨ha.wf, ha.wf, han.wf.2.1, han.wf.2.2, by simp⟩
    ha.sorted ha.sorted han.sorted.2
    ⟨ha.declared, ha.declared, han.declared.2, by simp⟩
    ⟨[], Capture.empty, [], rfl⟩ ⟨none, Eff.empty, hk⟩
  have hl : (StoreTy.empty.put 0 (.cont .bytes .bytes Eff.empty none)) 0 =
      some (.cont .bytes .bytes Eff.empty none) := by simp [StoreTy.put]
  have hu := hs.use_continuation hl
  exact ⟨hs, hu, hu.cont_annotation hl⟩

/-- Sorted 自体には WF は不要である。未束縛型変数でも文脈の移送ができる。 -/
theorem sorted_without_wf (Γ : Ctx) :
    ¬ (Ty.tvar 0).WF 0 0 0 ∧ (Ty.tvar 0).Sorted Γ := by
  exact ⟨by simp [Ty.WF], Ty.Sorted.closed_context (a := .tvar 0) trivial⟩

/-- 閉じた篩の述語も、空文脈から任意の値文脈へ移せる。 -/
theorem refined_sorted_context (Γ : Ctx) :
    (Ty.refined (.base .integer) (.eq (.integer 1) (.integer 1))).Sorted Γ := by
  apply Ty.Sorted.closed_context
  simp [Ty.Sorted, Pred.Sorted, Term.HasSort, Term.Shape, Term.References, Term.VarsIn]

/-- builder のセルを残した hide 後の StoreOk は要求できない。三条件だけを移す。 -/
theorem hide_builder_boundary (P : Program) (B : Builtins) (σ : PathEnv) :
    let Ψ := one (.builder .string)
    let μ : Store := fun l => if l = 0 then some (.builder (.string "")) else none
    StoreOk P B σ Ψ μ ∧ (hideBuilders Ψ).WF ∧ (hideBuilders Ψ).Sorted ∧
      StoreTy.Declared P (hideBuilders Ψ) ∧ ¬ StoreOk P B σ (hideBuilders Ψ) μ := by
  dsimp only
  have hs : StoreOk P B σ (one (.builder .string))
      (fun l => if l = 0 then some (.builder (.string "")) else none) := by
    refine ⟨⟨1, ?_⟩, ?_, ?_, ?_, ?_, ?_⟩
    · intro l hl
      have : l ≠ 0 := by omega
      simp [this]
    · intro l x hx
      by_cases h : l = 0
      · subst l; simp [one] at hx; subst x; trivial
      · simp [one, h] at hx
    · intro l x hx
      by_cases h : l = 0
      · subst l; simp [one] at hx; subst x; trivial
      · simp [one, h] at hx
    · intro l x hx
      by_cases h : l = 0
      · subst l; simp [one] at hx; subst x; trivial
      · simp [one, h] at hx
    · intro l x hx
      by_cases h : l = 0
      · subst l; simp
      · simp [one, h] at hx
    · intro l c hc
      by_cases h : l = 0
      · subst l; simp at hc; subst c
        exact ⟨.string, rfl, ⟨by decide, trivial⟩, trivial⟩
      · simp [h] at hc
  refine ⟨hs, hs.wf.hide, hs.sorted.hide, hs.declared.hide, ?_⟩
  intro h
  obtain ⟨kind, hk, _⟩ := h.cell 0 _ rfl
  simp [hideBuilders, one] at hk

/-- S00 の残りの型を読む全欄も、不適格な sort を拒む。 -/
theorem rejected_input {P B σ Ψ μ l t e r}
    (hl : Ψ l = some (.cont badT t e r)) : ¬ StoreOk P B σ Ψ μ := by
  intro h
  exact bad_unsorted []
    (StoreTy.cont_type_annotation (C := []) (Γ := []) h.wf h.sorted h.declared hl).sorted.1

theorem rejected_effect {P B σ Ψ μ l b t r}
    (hl : Ψ l = some (.cont b t (.mk (fun _ => false) [badT]) r)) : ¬ StoreOk P B σ Ψ μ := by
  intro h
  exact bad_unsorted [] (h.cont_annotation hl).sorted.2.1

theorem rejected_reference {P B σ Ψ μ l}
    (hl : Ψ l = some (.ref badT)) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted [] (h.reference_annotation (C := []) (Γ := []) hl).sorted

theorem rejected_lazy {P B σ Ψ μ l}
    (hl : Ψ l = some (.lazy badT)) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted [] (h.lazy_annotation (C := []) (Γ := []) hl).sorted

theorem rejected_builder_list {P B σ Ψ μ l}
    (hl : Ψ l = some (.builder (.list badT))) : ¬ StoreOk P B σ Ψ μ :=
  fun h => bad_unsorted []
    (StoreTy.builder_list_annotation (C := []) (Γ := []) h.wf h.sorted h.declared hl).sorted

/-- builder と通常の三種の場所を同じストア型に置く。 -/
def mixed (l : Nat) : Option LocTy :=
  if l = 0 then some (.builder (.list .bytes)) else
  if l = 1 then some (.ref .bytes) else
  if l = 2 then some (.lazy .bytes) else
  if l = 3 then some (.cont .bytes .bytes Eff.empty none) else none

private theorem mixed_conditions (P : Program) :
    StoreTy.WF mixed ∧ StoreTy.Sorted mixed ∧ StoreTy.Declared P mixed := by
  refine ⟨?_, ?_, ?_⟩
  all_goals
    intro l x hx
    unfold mixed at hx
    repeat' split at hx
    all_goals simp only [Option.some.injEq, reduceCtorEq] at hx
    all_goals subst x
    all_goals simp [LocTy.WF, LocTy.Sorted, LocTy.Declared, Ty.WF, Ty.Sorted,
      Ty.Declared, Eff.WF, Eff.Canonical, Eff.empty, Eff.norm, Ty.WFList,
      sortedEff, sortedTys, declaredEff, declaredTys]

/-- 隠したストアの StoreOk を要求せず、全ての三条件版を使う。 -/
theorem hidden_store_annotations (P : Program) (C : List Benitoite.Release.TParam) (Γ : Ctx) :
    mixed 0 = some (.builder (.list .bytes)) ∧ hideBuilders mixed 0 = none ∧
    Ty.Annotation P C Γ Ty.bytes ∧ Ty.Annotation P C Γ Ty.bytes ∧
    Ty.Annotation P C Γ Ty.bytes ∧
    Ty.Annotation P [] [] (.dependentFn (.done .bytes Eff.empty)) ∧
    Ty.Annotation P C Γ (.cont .bytes .bytes Eff.empty) ∧
    Ty.Annotation P C Γ Ty.bytes := by
  obtain ⟨hw, hs, hd⟩ := mixed_conditions P
  have hr : hideBuilders mixed 1 = some (.ref .bytes) := by simp [hideBuilders, mixed]
  have hl : hideBuilders mixed 2 = some (.lazy .bytes) := by simp [hideBuilders, mixed]
  have hc : hideBuilders mixed 3 = some (.cont .bytes .bytes Eff.empty none) := by
    simp [hideBuilders, mixed]
  exact ⟨rfl, rfl,
    StoreTy.reference_annotation hw.hide hs.hide hd.hide hr,
    StoreTy.lazy_annotation hw.hide hs.hide hd.hide hl,
    StoreTy.cont_result_annotation hw.hide hs.hide hd.hide hc,
    StoreTy.cont_annotation hw.hide hs.hide hd.hide hc,
    StoreTy.cont_type_annotation hw.hide hs.hide hd.hide hc,
    StoreTy.builder_list_annotation hw hs hd (l := 0) rfl⟩

end
end L20A1
