import Lean
import Benitoite.Release.Refinement.CapturedFacts
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.CapturedFactsBoundary
noncomputable section

abbrev I : Ty := .base .integer
def nonneg : Pred := .le (.integer 0) (.var 0)
def argument : Ty := .refined I nonneg
def phi : Pred := .lt (.var 0) (.integer 8)
def Γ : Ctx := Ctx.extend [] I
def result : Ty := .refined argument (.lt (.var 2) (.integer 8))
def tel : Tel := .param "x" argument (.done result Eff.empty)
def seven : Val := .const (.integer ⟨7,by decide⟩)
def three : Val := .const (.integer ⟨3,by decide⟩)
def zero : Val := .const (.integer ⟨0,by decide⟩)
def cap : Capture := Capture.empty.extend seven
def extended : Capture := cap.extend three
def closedResult : Ty := extended.closeTy result
def branch (c : Bool) : Comp := if c then .ret (.var 0) else .ret zero
def code (c : Bool) : Comp := .ite (.const (.boolean c)) (.ret (.var 0)) (.ret zero)

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
def σ : PathEnv := ⟨[],[],[],none,none,none⟩

macro "ann" : tactic => `(tactic| simp [Ty.Annotation,I,nonneg,argument,phi,Γ,result,tel,
  hideConts,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Pred.WF,Pred.VarsIn,Term.VarsIn,
  Ty.Sorted,sortedTys,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ctx.Readable,
  Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,declaredTys,declaredEff,Pred.Declared,
  Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Eff.empty,Eff.norm,Eff.WF,
  Eff.Canonical,sortedEff,Ty.norm,Ty.refineNorm,Ty.packRefinements,
  Ty.refinementPredicates,Pred.conjuncts,Pred.ofConjuncts,Ty.normTys,Order.sortUnique,
  Tel.WF,Tel.Sorted,Tel.Declared])

theorem argument_ann : Ty.Annotation P [] (hideConts Γ) argument := by
  refine ⟨?_,?_,?_⟩ <;> ann
theorem tel_ann : Ty.Annotation P [] (hideConts Γ) (.dependentFn tel) := by
  refine ⟨?_,?_,?_⟩ <;> ann
theorem result_ann : Ty.Annotation P [] ((hideConts Γ).extend argument)
    (.dependentFn (.done result Eff.empty)) := by
  refine ⟨?_,?_,?_⟩ <;> ann
theorem phi_wf : Pred.WellFormed P [] Γ phi := by
  refine ⟨?_,?_,?_⟩ <;> ann

theorem images_only : CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] cap :=
  (CaptureOk.empty P B _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial

/-- 結論の Entails や CaptureOk を仮定せず、D19 の計算成功を渡す。 -/
theorem phi_evaluates : (predBind (valEnv cap.env).values phi).evalClosed = some true := by
  decide
theorem captured : CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] cap :=
  images_only.addEvaluated phi_wf phi_evaluates

theorem argument_typed : HasTypeV P B StoreTy.empty [] [] [] three (cap.closeTy argument) := by
  change HasTypeV P B StoreTy.empty [] [] [] three argument
  refine .V_Refine (.V_Const trivial) (sort := .integer) rfl rfl ?_ ?_ ?_ trivial ?_
  · ann
  · trivial
  · exact .integer_le (by decide)
  · ann

/-- facts_extend が Γ の新しい篩の事実と、移動した Φ の両方を構成する。 -/
theorem extended_facts : ∀ p ∈ ((hideConts Γ).extend argument).facts ++ [phi].map Pred.lift,
    Entails [] (predBind (valEnv extended.env).values p) :=
  (captured.hideConts_any (R' := none)).facts_extend argument_typed

theorem argument_facts_nonempty :
    nonneg ∈ ((hideConts Γ).extend argument).facts := by
  apply Ctx.mem_facts_extend.mpr
  exact Or.inl (by change nonneg ∈ [nonneg]; simp)
theorem closed_argument_fact : Entails [] (.le (.integer 0) (.integer 3)) := by
  exact extended_facts nonneg (List.mem_append_left _ argument_facts_nonempty)
theorem closed_phi : Entails [] (.lt (.integer 7) (.integer 8)) := by
  exact extended_facts phi.lift (List.mem_append_right _ (by simp))

theorem extended_ok : CaptureOk P B (hideBuilders StoreTy.empty) (some closedResult)
    ((hideConts Γ).extend argument) [phi.lift] extended :=
  (captured.hideConts_any (R' := some closedResult)).extend argument_ann argument_typed trivial

theorem closed_body_fact : Entails []
    (predBind (valEnv extended.env).values (.lt (.var 1) (.integer 8))) := by
  apply extended_ok.close_entails
  exact .hyp (List.mem_append_right _ List.mem_cons_self)

/-- 篩の追加は捕捉 Φ の仮定を実際に使う。引数自身の事実だけでは出ない。 -/
theorem return_argument : HasTypeC P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [phi.lift] (some result) (.ret (.var 0)) result Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Var rfl (by trivial)) (sort := .integer) rfl rfl ?_ ?_ ?_ ?_ ?_
  · exact result_ann.sorted.1.2
  · exact result_ann.wf.1.2.1
  · exact .hyp (List.mem_append_right _ List.mem_cons_self)
  · exact argument_ann.declared
  · exact result_ann.declared.1.2

theorem return_zero : HasTypeC P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [phi.lift] (some result) (.ret zero) result Eff.empty := by
  apply HasTypeCQ.C_Return
  have hv : HasTypeV P B (hideBuilders StoreTy.empty) []
      ((hideConts Γ).extend argument) [phi.lift] zero argument := by
    refine .V_Refine (.V_Const trivial) (sort := .integer) rfl rfl ?_ ?_ ?_ trivial ?_
    · ann
    · trivial
    · exact .le_refl
    · ann
  refine .V_Refine hv (sort := .integer) rfl rfl ?_ ?_ ?_ ?_ ?_
  · exact result_ann.sorted.1.2
  · exact result_ann.wf.1.2.1
  · exact .hyp (List.mem_append_right _ List.mem_cons_self)
  · exact argument_ann.declared
  · exact result_ann.declared.1.2

theorem branch_typed (c : Bool) : HasTypeC P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [phi.lift] (some result) (branch c) result Eff.empty := by
  cases c
  · exact return_zero
  · exact return_argument

theorem body_typed (c : Bool) : TelBodyTy P B (hideBuilders StoreTy.empty) Qempty []
    (hideConts Γ) [phi] tel (code c) :=
  .param (.done (.C_If (.V_Const trivial) return_argument return_zero))

theorem value_assumptions : Builtins.ValueAssumptions P B := by
  constructor
  · intros; trivial
  · intro b sg C Γ Δ ts ξ hs; cases hs
  · intros; trivial
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hs; cases hs

theorem sub_refl (e : Eff) : Eff.Sub e e := ⟨fun _ h => h,fun _ h => h⟩

theorem closed_ann : Ty.Annotation P [] [] closedResult := by
  have ht := extended_ok.substOk.telAnnotation result_ann
  exact ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩

def start (c : Bool) : State := .run
  (Closure.pure (.app (.closure (cap.closeTel tel) (.mk cap (code c))) [three])) [] Store.empty
def applied (c : Bool) : State := .run (.mk extended (code c)) [.mark] Store.empty
def selected (c : Bool) : State := .run (.mk extended (branch c)) [.mark] Store.empty

theorem beta_states (c : Bool) : StateTy P B σ (start c) ∧
    Step P B σ (start c) none (applied c) ∧ StateTy P B σ (applied c) := by
  apply StateTy.captured_beta_one (Ψ := StoreTy.empty) value_assumptions captured
    (body_typed c) tel_ann argument_typed trivial rfl (StoreOk.empty P B σ)
    (by intros; contradiction)
    (.K_Empty (sub_refl Eff.empty) closed_ann)
    (by simpa only [Capture.closeEff,Eff.subst_values_empty] using sub_refl Eff.empty)
    (by trivial) (by trivial) (by trivial) (by trivial) (by change True ∧ 0 < 2 ∧ True; exact ⟨trivial,by decide,trivial⟩)
    (by intro f hf; cases hf) (by intro l d hd; cases hd)
    (by decide) ⟨rfl,by intro a ha; cases ha⟩

theorem branch_step (c : Bool) : Step P B σ (applied c) none (selected c) := by
  cases c
  · exact .E_IfF rfl
  · exact .E_IfT rfl

theorem selected_closure (c : Bool) : ClosureTy P B StoreTy.empty [] (some closedResult)
    (.mk extended (branch c)) closedResult Eff.empty := by
  have h := ClosureTy.capture extended_ok (branch_typed c) result_ann rfl
    (fun r hr => by cases hr; exact result_ann.declared.1)
  have he : Refinement.hideBuilders StoreTy.empty = StoreTy.empty := by funext l; rfl
  rw [he] at h
  simpa only [Capture.closeEff,Eff.subst_values_empty,closedResult] using h

theorem selected_stateE (c : Bool) : StateTyE P B σ Eff.empty (selected c) := by
  refine ⟨StoreTy.empty,some closedResult,closedResult,closedResult,Eff.empty,Eff.empty,
    StoreOk.empty P B σ,selected_closure c,sub_refl _,
    .K_Mark (.K_Empty (sub_refl _) closed_ann) closed_ann,?_,?_,?_,?_⟩
  · cases c <;> trivial
  · cases c
    · exact ⟨⟨trivial,trivial,trivial⟩,trivial⟩
    · exact ⟨⟨trivial,trivial,trivial⟩,by change 0 < 2; decide⟩
  · intro f hf; cases List.mem_singleton.mp hf; trivial
  · intro l d hd; cases hd

/-- 両分岐について、βとifの前後を実際のStateTy/Stepで構成する。 -/
theorem execution (c : Bool) : StateTy P B σ (start c) ∧
    Step P B σ (start c) none (applied c) ∧ StateTy P B σ (applied c) ∧
    Step P B σ (applied c) none (selected c) ∧ StateTy P B σ (selected c) := by
  obtain ⟨h0,hs,h1⟩ := beta_states c
  exact ⟨h0,hs,h1,branch_step c,⟨by decide,Eff.empty,⟨rfl,by intro a ha; cases ha⟩,selected_stateE c⟩⟩

def returned (c : Bool) : Val := if c then three else zero

theorem selected_view (c : Bool) : (Closure.mk extended (branch c)).view = .ret (returned c) := by
  cases c <;> rfl

theorem substitution_assumptions : Builtins.SubstitutionAssumptions P B := by
  constructor <;> constructor
  · intros; trivial
  · intro b sg C Γ Δ ts ξ hs; cases hs
  · intros; trivial
  · intro b sg Ψ Q C Γ Δ Ξ ν ts hs; cases hs
  · intros; trivial
  · intro b sg C C' Γ Δ ts ρ hs; cases hs
  · intros; trivial
  · intro b sg C0 C1 ts ts' es' hs; cases hs

/-- StateTyの逆転ではない。同じ本体の導出を閉じ、実際のviewの値を型付ける。 -/
theorem returned_typed (c : Bool) : HasTypeV P B StoreTy.empty [] [] [] (returned c) closedResult := by
  have hc : CaptureOk P B (hideBuilders StoreTy.empty) (some closedResult)
      ((hideConts Γ).extend argument) [phi.lift] extended := extended_ok
  have hb := (branch_typed c).subst substitution_assumptions StoreTy.WF.empty.hide
    hc.substOk (fun p hp => hc.conditions p (List.mem_append_right _ hp))
    LocalRef.bound (LocalSubstOk.empty _ _ _ [])
  have he : Refinement.hideBuilders StoreTy.empty = StoreTy.empty := by funext l; rfl
  rw [he] at hb
  have hret : (branch c).subst extended.env LocalRef.bound = .ret (returned c) := by
    cases c <;> rfl
  have hv := hb.ret_value hret
  exact hv

def closedPredicate : Pred := .and nonneg (.lt (.integer 7) (.integer 8))
theorem result_is_closed : closedResult = .refined I closedPredicate := rfl

theorem returned_facts (c : Bool) :
    Entails [] (.le (.integer 0) (if c then .integer 3 else .integer 0)) ∧
    Entails [] (.lt (.integer 7) (.integer 8)) := by
  have hv := returned_typed c
  rw [result_is_closed] at hv
  have ht : (returned c).toTerm? = some (if c then .integer 3 else .integer 0) := by
    cases c <;> rfl
  exact ⟨hv.facts ht nonneg (by change nonneg ∈ [nonneg, _]; simp),
    hv.facts ht (.lt (.integer 7) (.integer 8)) (by change _ ∈ [_, _]; simp)⟩

def wrongPhi : Pred := .lt (.var 0) (.integer 7)
def wrongResult : Ty := .refined argument (.lt (.integer 7) (.integer 7))
def eight : Val := .const (.integer ⟨8,by decide⟩)
def otherCap : Capture := Capture.empty.extend eight

theorem wrong_phi_wf : Pred.WellFormed P [] Γ wrongPhi := by
  refine ⟨?_,?_,?_⟩ <;> simp [wrongPhi] <;> ann
theorem wrong_result_ann : Ty.Annotation P [] [] wrongResult := by
  refine ⟨?_,?_,?_⟩ <;> simp [wrongResult] <;> ann
theorem wrong_phi_evaluates_false :
    (predBind (valEnv cap.env).values wrongPhi).evalClosed = some false := by decide

theorem no_wrong_closed_fact : ¬ Entails [] (.lt (.integer 7) (.integer 7)) := by
  intro h
  have hf := h.sound (fun _ => none) (by simp)
  change false = true at hf
  cases hf

theorem no_wrong_phi : ¬ CaptureOk P B (hideBuilders StoreTy.empty) none Γ [wrongPhi] cap := by
  intro h
  exact no_wrong_closed_fact (h.conditions wrongPhi (List.mem_append_right _ List.mem_cons_self))

theorem wrong_return_untyped (c : Bool) :
    ¬ HasTypeV P B StoreTy.empty [] [] [] (returned c) wrongResult := by
  intro h
  cases c
  · exact no_wrong_closed_fact (h.facts rfl (.lt (.integer 7) (.integer 7))
      (by change _ ∈ [_, _]; simp))
  · exact no_wrong_closed_fact (h.facts rfl (.lt (.integer 7) (.integer 7))
      (by change _ ∈ [_, _]; simp))

theorem body_requires_phi : ¬ HasTypeV P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [] (.var 0) result := by
  intro h
  have hf := h.facts rfl (.lt (.var 2) (.integer 8)) (by change _ ∈ [_, _]; simp)
  have hm := hf.sound (fun _ => some (.integer 8)) (by
    intro p hp
    change p ∈ [nonneg] at hp
    cases List.mem_singleton.mp hp
    rfl)
  change false = true at hm
  cases hm

/-- Γ と型付き像だけを残しても、捕捉した Φ は復元できない。 -/
theorem other_images_only : CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] otherCap :=
  (CaptureOk.empty P B _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial

theorem other_cannot_capture :
    ¬ CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] otherCap := by
  intro h
  have hf := (h.conditions phi (List.mem_append_right _ List.mem_cons_self)).sound
    (fun _ => none) (by simp)
  change false = true at hf
  cases hf

theorem environment_cannot_be_forgotten :
    ¬ (∀ q, CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] q →
      CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] q) := by
  intro h
  exact other_cannot_capture (h otherCap other_images_only)

theorem open_phi_is_not_closed_fact : ¬ Entails [] phi := by
  intro h
  have hf := h.sound (fun _ => some (.integer 8)) (by simp)
  change false = true at hf
  cases hf

theorem discarded_capture_changes_view :
    (Closure.mk cap (.ret (.var 0))).view = .ret seven ∧
    (Closure.mk Capture.empty (.ret (.var 0))).view = .ret (.const .unit) := ⟨rfl,rfl⟩

theorem discarded_capture_evaluation_fails :
    (predBind (valEnv Capture.empty.env).values phi).evalClosed = none := by decide

theorem environment_counterexample :
    CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] cap ∧
    CaptureOk P B (hideBuilders StoreTy.empty) none Γ [] otherCap ∧
    CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] cap ∧
    ¬ CaptureOk P B (hideBuilders StoreTy.empty) none Γ [phi] otherCap :=
  ⟨images_only,other_images_only,captured,other_cannot_capture⟩

/-! 追加: Φ が返り値自身の篩を与える例と、本体が引数の facts を読む例。 -/
def result2 : Ty := .refined I (.lt (.var 0) (.integer 8))

theorem result2_ann : Ty.Annotation P [] ((hideConts Γ).extend argument)
    (.dependentFn (.done result2 Eff.empty)) := by
  refine ⟨?_,?_,?_⟩ <;> simp only [result2] <;> ann

theorem return_capture : HasTypeC P B (hideBuilders StoreTy.empty) []
    ((hideConts Γ).extend argument) [phi.lift] (some result2) (.ret (.var 1)) result2 Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Var rfl (by trivial)) (sort := .integer) rfl rfl ?_ ?_ ?_ ?_ ?_
  · exact result2_ann.sorted.1.2
  · exact result2_ann.wf.1.2.1
  · exact .hyp (List.mem_append_right _ List.mem_cons_self)
  · simp [Ty.Declared]
  · exact result2_ann.declared.1.2

def closed2 : Ty := extended.closeTy result2
theorem closed2_eq : closed2 = result2 := rfl

theorem extended_ok2 : CaptureOk P B (hideBuilders StoreTy.empty) (some closed2)
    ((hideConts Γ).extend argument) [phi.lift] extended :=
  (captured.hideConts_any (R' := some closed2)).extend argument_ann argument_typed trivial

theorem returned_capture_typed : HasTypeV P B StoreTy.empty [] [] [] seven result2 := by
  have hc := extended_ok2
  have hb := return_capture.subst substitution_assumptions StoreTy.WF.empty.hide
    hc.substOk (fun p hp => hc.conditions p (List.mem_append_right _ hp))
    LocalRef.bound (LocalSubstOk.empty _ _ _ [])
  have he : Refinement.hideBuilders StoreTy.empty = StoreTy.empty := by funext l; rfl
  rw [he] at hb
  have hret : (Comp.ret (.var 1)).subst extended.env LocalRef.bound = .ret seven := rfl
  exact hb.ret_value hret

/-- 境界の値の型付けで 7 が実際に Φ の事実を受け取る。 -/
theorem returned_capture_fact : Entails [] (.lt (.integer 7) (.integer 8)) := by
  exact returned_capture_typed.facts rfl (Pred.lt (.var 0) (.integer 8))
    (by change _ ∈ [_]; simp)

/-- Γ.facts の側の hyp を close_entails へ通す。本体がこの事実を使う場合にも同じ入口となる。 -/
theorem closed_gamma_fact : Entails [] (.le (.integer 0) (.integer 3)) :=
  extended_ok.close_entails (p := nonneg) (.hyp (List.mem_append_left _ argument_facts_nonempty))


end
end Benitoite.Release.Refinement.CapturedFactsBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if (name.toString.splitOn "CapturedFactsBoundary").length > 1 then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
