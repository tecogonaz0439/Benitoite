import Lean
import Benitoite.Release.Refinement.MatchFacts
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement.PathConditionsBoundary
noncomputable section

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
def σ : PathEnv := ⟨[],[],[],none,none,none⟩
abbrev BoolTy : Ty := .base .boolean
def Γ : Ctx := Ctx.extend [] BoolTy
def p : Pred := boolCond (.var 0) true
def result : Ty := .refined BoolTy p
def code : Comp := .ite (.var 0) (.ret (.var 0)) (.ret (.const (.boolean true)))
def cap (b : Bool) : Capture := Capture.empty.extend (.const (.boolean b))
def source (b : Bool) : State := .run (.mk (cap b) code) [] Store.empty

theorem result_ann : Ty.Annotation P [] Γ (.dependentFn (.done result Eff.empty)) := by
  refine ⟨?_,?_,?_⟩ <;>
    simp [result,p,boolCond,Γ,Ctx.extend,Ty.WF,Ty.WFList,Ty.shiftV,Ty.NotContCore,Ty.core,
      Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Eff.WF,Eff.Canonical,Eff.empty,
      Tel.Sorted,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
      Ty.HasSort,Ty.sort?,Ordinary,Tel.Declared,Ty.Declared,declaredEff,Pred.Declared,
      Term.Declared,Ctx.declarationSelf,Ctx.Readable,Comparison.Allowed,sortedEff,sortedTys,
      declaredTys,Eff.norm,Ty.normTys]

theorem true_branch : HasTypeC P B StoreTy.empty [] Γ [p] none
    (.ret (.var 0)) result Eff.empty := by
  apply HasTypeCQ.C_Return
  exact .V_Refine (.V_Var rfl (by trivial)) rfl rfl result_ann.sorted.1.2
    result_ann.wf.1.2.1 (.hyp (List.mem_append_right _ List.mem_cons_self))
    trivial result_ann.declared.1.2

theorem true_branch_requires_condition :
    ¬ HasTypeC P B StoreTy.empty [] Γ [] none (.ret (.var 0)) result Eff.empty := by
  intro h
  have hf := (h.ret_value rfl).facts rfl p (by change p ∈ [p]; simp)
  have hh := hf.sound (fun _ => some (.boolean false)) (by
    intro q hq
    change q ∈ [] at hq
    cases hq)
  change false = true at hh
  cases hh

theorem false_branch : HasTypeC P B StoreTy.empty [] Γ [boolCond (.var 0) false] none
    (.ret (.const (.boolean true))) result Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Const trivial) rfl rfl result_ann.sorted.1.2
    result_ann.wf.1.2.1 ?_ trivial result_ann.declared.1.2
  exact (CaptureOk.evaluated_fact (p := boolCond (.boolean true) true) (by decide)).weaken (by simp)

theorem code_typed : HasTypeC P B StoreTy.empty [] Γ [] none code result Eff.empty :=
  .C_If (.V_Var rfl (by trivial)) rfl true_branch false_branch

theorem code_with_conversions : HasTypeC P B StoreTy.empty [] Γ [] none code result Eff.empty := by
  have hn : result.norm = result := rfl
  exact .C_Sub (hn ▸ (.C_Normal (.C_Eff code_typed (Eff.Covers.refl _ _ _))))
    .refl (Eff.Covers.refl _ _ _) result_ann.wf.1 result_ann.sorted.1 result_ann.declared.1

theorem captured (b : Bool) : CaptureOk P B StoreTy.empty none Γ [] (cap b) :=
  (CaptureOk.empty P B _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial

theorem source_typed (b : Bool) : StateTy P B σ (source b) := by
  have hc := captured b
  have hq := ClosureTy.capture hc code_with_conversions result_ann rfl (by intro r hr; cases hr)
  have hAnn := hc.substOk.telAnnotation result_ann
  have ha : Ty.Annotation P [] [] ((cap b).closeTy result) :=
    ⟨hAnn.wf.1,hAnn.sorted.1,hAnn.declared.1⟩
  have he : (cap b).closeEff Eff.empty = Eff.empty := substEffValues_empty _
  rw [he] at hq
  refine ⟨by decide,Eff.empty,?_,StoreTy.empty,none,_,_,Eff.empty,Eff.empty,
    StoreOk.empty _ _ _,hq,⟨fun _ h => h,fun _ h => h⟩,ContTy.K_Empty (⟨fun _ h => h,fun _ h => h⟩) ha,?_,?_,?_,?_⟩
  · exact ⟨rfl,by intro a hm; cases hm⟩
  · exact ⟨⟨trivial,trivial⟩,trivial,trivial,trivial⟩
  · simp [Closure.ClosedAt,cap,Capture.extend,Capture.empty,Capture.Closed,
      captureSlotsClosed,Val.ClosedAt,Capture.values,code,Comp.ClosedAt]
  · intro f hf; cases hf
  · intro l c hl; cases hl

theorem if_true_execution :
    Step P B σ (source true) none (.run (.mk (cap true) (.ret (.var 0))) [] Store.empty) :=
  .E_IfT rfl

theorem if_false_execution :
    Step P B σ (source false) none (.run (.mk (cap false) (.ret (.const (.boolean true)))) [] Store.empty) :=
  .E_IfF rfl

theorem if_true_target :
    StateTy P B σ (.run (.mk (cap true) (.ret (.var 0))) [] Store.empty) := by
  obtain ⟨hσ,Eb,hEb,h⟩ := source_typed true
  exact ⟨hσ,Eb,hEb,h.if_true rfl⟩

theorem if_false_target :
    StateTy P B σ (.run (.mk (cap false) (.ret (.const (.boolean true)))) [] Store.empty) := by
  obtain ⟨hσ,Eb,hEb,h⟩ := source_typed false
  exact ⟨hσ,Eb,hEb,h.if_false rfl⟩

/-- 観測なしの腕は同じ入力型の値に使え、旧導出の入口を保つ。 -/
theorem arms_do_not_identify_scrutinee {P B Ψ Q C Γ Φ R arms a r e L v w}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hw : HasTypeVQ P B Ψ Q C Γ Φ w a)
    (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R none arms a r e L)
    (hx : Exhaustive P a (unguardedPats arms)) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) r e L ∧
    HasTypeCQ P B Ψ Q C Γ Φ R (.match w arms) r e L :=
  ⟨.match_legacy hv ha hx,.match_legacy hw ha hx⟩

/-- 別の被検査値から得た構成子の事実は、外側の値の事実へ無条件に流用できない。 -/
theorem wrong_constructor_fact :
    ¬ Entails [] (.constructorIs (.dataValue "Other" []) "Selected") := by
  intro h
  have hh := h.sound (fun _ => none) (by simp)
  change false = true at hh
  cases hh

/-- 比較組込みの結果型の宣言から得る選言を、if c の真の事実に接続する。
    apart は現行の Entails では導けない（レビューの apart_not_derivable）。
    この補題は L30 で規則を足した後の接続の形であり、現時点で適用できる導出ではない。 -/
theorem let_comparison_connect {Ξ : List Pred} {c x : Term}
    (comparison_result : Entails Ξ
      (.or (.and (boolCond c true) (.lt x (.integer 8)))
        (.and (boolCond c false) (.not (.lt x (.integer 8))))))
    (condition : Entails Ξ (boolCond c true))
    (apart : ∀ Ψ t, Entails Ψ (boolCond t true) → Entails Ψ (boolCond t false) → Entails Ψ .falsity) :
    Entails Ξ (.lt x (.integer 8)) := by
  apply Entails.or_elim comparison_result
  · exact .and_right (.hyp List.mem_cons_self)
  · apply Entails.false_elim
    exact apart _ c (condition.weaken (fun _ h => List.mem_cons_of_mem _ h))
      (.and_left (.hyp List.mem_cons_self))


namespace Match

def cd : ConDecl := ⟨"Choice",0,[]⟩
def Pm : Program := { P with cons := fun c => if c = "Selected" ∨ c = "Other" then some cd else none }
abbrev Input : Ty := .data "Choice" []
def Γm : Ctx := Ctx.extend [] Input
def fact : Pred := .constructorIs (.var 0) "Selected"
def Out : Ty := .refined Input fact
def alts : List Alt := [⟨.con "Selected" [],[]⟩]
def arms : List Arm := [.mk alts none (.ret (.var 0)), .mk [⟨.wild,[]⟩] none (.ret (.con "Selected" [] []))]
def cm : Comp := .match (.var 0) arms
def cp : Capture := Capture.empty.extend (.con "Selected" [] [])

theorem input_ann {Γ : Ctx} : Ty.Annotation Pm [] Γ Input := by
  refine ⟨trivial,trivial,⟨⟨0,?_,rfl⟩,trivial⟩⟩
  refine ⟨⟨"Selected",cd,rfl,rfl⟩,?_⟩
  intro c d hd _
  change (if c = "Selected" ∨ c = "Other" then some cd else none) = some d at hd
  split at hd
  · cases Option.some.inj hd; rfl
  · cases hd

theorem con_typed {Γ : Ctx} {Φ : List Pred} : HasTypeV Pm B StoreTy.empty [] Γ Φ (.con "Selected" [] []) Input :=
  .V_Con (cd := cd) rfl rfl (by simp [TypeArgsKinded,cd]) (by intro t ht; cases ht) .nil input_ann

theorem out_ann : Ty.Annotation Pm [] Γm (.dependentFn (.done Out Eff.empty)) := by
  have hp : Pred.WellFormed Pm [] Γm fact := by
    refine ⟨?_,?_,?_⟩
    · simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn,Γm,Ctx.extend]
    · exact ⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩
    · exact ⟨⟨Input,rfl,by trivial⟩,"Choice",[],cd,.var rfl rfl,rfl,rfl⟩
  have ha : Ty.Annotation Pm [] Γm Out :=
    ⟨⟨input_ann.wf,by simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn],by simp [Input,Ty.NotContCore,Ty.core]⟩,
      ⟨input_ann.sorted,⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩⟩,
      ⟨input_ann.declared,⟨⟨Input,rfl,by trivial⟩,"Choice",[],cd,.var rfl rfl,rfl,rfl⟩⟩⟩
  exact ⟨⟨ha.wf,trivial,rfl⟩,⟨ha.sorted,trivial⟩,⟨ha.declared,trivial⟩⟩

theorem matched_wf : FactsWF Pm [] Γm
    (pathFacts (some (.var 0)) (matchedTests alts ++ excludedTests alts)) := by
  have hw : Pred.WellFormed Pm [] Γm fact := by
    refine ⟨?_,?_,?_⟩
    · simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn,Γm,Ctx.extend]
    · exact ⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩
    · exact ⟨⟨Input,rfl,by trivial⟩,"Choice",[],cd,.var rfl rfl,rfl,rfl⟩
  intro p hp
  change p ∈ [fact,.not fact] at hp
  simp only [List.mem_cons,List.not_mem_nil,or_false] at hp
  rcases hp with rfl | rfl
  · exact hw
  · exact ⟨hw.wf,hw.sorted,hw.declared⟩

theorem selected_body : HasTypeC Pm B StoreTy.empty [] Γm [fact] none
    (.ret (.var 0)) Out Eff.empty := by
  exact .C_Return (.V_Refine (.V_Var rfl (by trivial)) rfl rfl out_ann.sorted.1.2
    out_ann.wf.1.2.1 (.hyp (by change fact ∈ [fact]; simp))
    input_ann.declared out_ann.declared.1.2)

theorem selected_body_requires_fact : ¬ HasTypeC Pm B StoreTy.empty [] Γm [] none
    (.ret (.var 0)) Out Eff.empty := by
  intro h
  have hf := (h.ret_value rfl).facts rfl fact (by change fact ∈ [fact]; simp)
  have hh := hf.sound (fun _ => some (.dataValue "Other" [])) (by
    intro q hq; change q ∈ [] at hq; cases hq)
  change false = true at hh
  cases hh

theorem fallback {Φ : List Pred} : HasTypeC Pm B StoreTy.empty [] Γm Φ none
    (.ret (.con "Selected" [] [])) Out Eff.empty := by
  exact .C_Return (.V_Refine con_typed rfl rfl out_ann.sorted.1.2 out_ann.wf.1.2.1
    ((CaptureOk.evaluated_fact (p := .constructorIs (.dataValue "Selected" []) "Selected")
      (by decide)).weaken (by simp)) input_ann.declared out_ann.declared.1.2)

theorem alts_typed : AltsTy Pm alts Input [] := by
  refine ⟨by decide,rfl,?_,?_⟩
  · intro a h; cases Option.some.inj h; rfl
  · intro a h; rcases List.mem_cons.mp h with rfl | h
    · exact ⟨[],.P_Con (cd := cd) (ts := []) rfl rfl (by intro t ht; cases ht) .nil,.refl _,rfl⟩
    · cases h

theorem arms_typed : HasTypeArmsQ Pm B StoreTy.empty Qempty [] Γm [] none (some (.var 0)) arms Input Out Eff.empty := by
  refine .plain alts_typed matched_wf ?_ ?_
  · simpa [alts,matchedTests,patternTest?,alternativesTest,rootConstructor,pathFacts,PathTest.predicate,bindParams,liftMany_eq,
      fact,localExtend,Ty.shiftV_zero,Pred.shiftV_zero,Eff.shiftV_zero,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using selected_body
  · refine .plain (δ := []) ?_ (by intro p hp; cases hp) ?_ (.nil ⟨out_ann.wf.1,out_ann.sorted.1,out_ann.declared.1⟩)
    · exact ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),
        (by intro a h; rcases List.mem_cons.mp h with rfl | h; exact ⟨[],.P_Wild,.refl _,rfl⟩; cases h)⟩
    · simpa [matchedTests,patternTest?,alternativesTest,rootConstructor,nonemptyPattern,pathFacts,bindParams,liftMany_eq,localExtend,
        alts,excludedTests,excludedTest?,irrefutableField,PathTest.predicate,fact,Ty.shiftV_zero,Pred.shiftV_zero,Eff.shiftV_zero,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using (fallback (Φ := [.not fact]))

theorem exhaustive : Exhaustive Pm Input (unguardedPats arms) := by
  intro v hv
  exact ⟨.wild,by simp [arms,unguardedPats],by simp [matchVal]⟩

theorem code_typed : HasTypeC Pm B StoreTy.empty [] Γm [] none cm Out Eff.empty :=
  .C_Match (.V_Var rfl (by trivial)) (by intro t h; cases h; exact ⟨rfl,.data,⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩) arms_typed exhaustive

theorem capture_ok : CaptureOk Pm B StoreTy.empty none Γm [] cp :=
  (CaptureOk.empty Pm B _ _).extend input_ann con_typed (by change (Val.con "Selected" [] []).ClosedAt 0 0; exact ⟨(by intro a h; cases h),trivial⟩)

theorem source : StateTyE Pm B σ Eff.empty (.run (.mk cp cm) [] Store.empty) := by
  have hq := ClosureTy.capture capture_ok code_typed out_ann rfl (by intro r hr; cases hr)
  have hAnn := capture_ok.substOk.telAnnotation out_ann
  have hempty : cp.closeEff Eff.empty = Eff.empty := substEffValues_empty _
  rw [hempty] at hq
  refine ⟨StoreTy.empty,none,cp.closeTy Out,cp.closeTy Out,Eff.empty,Eff.empty,StoreOk.empty _ _ _,hq,?_,?_,?_,?_,?_,?_⟩
  · exact ⟨fun _ h => h,fun _ h => h⟩
  · exact .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨hAnn.wf.1,hAnn.sorted.1,hAnn.declared.1⟩
  · trivial
  · simp [Closure.ClosedAt,cp,Capture.extend,Capture.empty,Capture.Closed,captureSlotsClosed,Val.ClosedAt,
      Val.ClosedList,Capture.values,cm,Comp.ClosedAt,arms,Arm.ClosedList,alts,Arm.bindersOf,Pat.binders,Pat.bindersList]
  · intro f hf; cases hf
  · intro l c hl; cases hl

theorem start_step : Step Pm B σ (.run (.mk cp cm) [] Store.empty) none
    (.matchRun (.con "Selected" [] []) cp arms 0 [] Store.empty) := .E_Match rfl

theorem start : StateTyE Pm B σ Eff.empty
    (.matchRun (.con "Selected" [] []) cp arms 0 [] Store.empty) := source.match_start rfl

theorem body_step : Step Pm B σ (.matchRun (.con "Selected" [] []) cp arms 0 [] Store.empty) none
    (.run (.mk cp (.ret (.var 0))) [] Store.empty) := by
  simpa only [Capture.extendMany,List.foldl_nil] using (Step.E_MatchBody (P := Pm) (B := B) (σ := σ) (ws := []) (arms := arms) (next := 0) (k := []) (μ := Store.empty) (cap := cp) (v := .con "Selected" [] []) (alts := alts) (body := .ret (.var 0)) rfl rfl)

theorem body_target : StateTyE Pm B σ Eff.empty (.run (.mk cp (.ret (.var 0))) [] Store.empty) := by
  apply start.match_body_zero (alts := alts) rfl rfl rfl
  constructor
  · intro i as g m hi hn; omega
  · intro as g m hi
    cases Option.some.inj hi
    intro p hp
    change p ∈ [.constructorIs (.dataValue "Selected" []) "Selected"] at hp
    simp only [List.mem_cons,List.not_mem_nil,or_false] at hp
    subst p
    decide


namespace Excluded
-- Other の腕を飛ばした事実は、後続の wildcard の本体で読む。
def absent : Pred := .not (.constructorIs (.var 0) "Other")
def predicate : Pred := .or (.not (.constructorIs (.var 1) "Other")) (boolCond (.var 0) true)
def Out : Ty := .refined BoolTy predicate
def alts : List Alt := [⟨.con "Other" [],[]⟩]
def arms : List Arm := [.mk alts none (.ret (.const (.boolean true))),
  .mk [⟨.wild,[]⟩] none (.ret (.const (.boolean false)))]

theorem annotation : Ty.Annotation Pm [] Γm (.dependentFn (.done Out Eff.empty)) := by
  refine ⟨?_,?_,?_⟩
  · simp [Out,predicate,boolCond,Γm,Ctx.extend,Ty.WF,Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,
      Eff.WF,Eff.empty,Eff.Canonical,Ty.NotContCore,Ty.core,Ty.WFList,Eff.norm,Ty.normTys]
  · exact ⟨⟨trivial,⟨⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩,trivial,
      ⟨⟨BoolTy,rfl,by trivial⟩,BoolTy,rfl,rfl⟩,by trivial⟩⟩,trivial⟩
  · refine ⟨⟨trivial,?_,?_⟩,trivial⟩
    · exact ⟨⟨Input,rfl,by trivial⟩,"Choice",[],cd,.var rfl rfl,rfl,rfl⟩
    · exact ⟨⟨BoolTy,rfl,by trivial⟩,trivial⟩

theorem later_body : HasTypeC Pm B StoreTy.empty [] Γm [absent] none
    (.ret (.const (.boolean false))) Out Eff.empty := by
  exact .C_Return (.V_Refine (.V_Const trivial) rfl rfl annotation.sorted.1.2
    annotation.wf.1.2.1 (.or_left (.hyp (List.mem_append_right _ List.mem_cons_self)))
    trivial annotation.declared.1.2)

theorem later_requires_excluded : ¬ HasTypeC Pm B StoreTy.empty [] Γm [] none
    (.ret (.const (.boolean false))) Out Eff.empty := by
  intro h
  have hf := (h.ret_value rfl).facts rfl predicate (by change predicate ∈ [predicate]; simp)
  have hh := hf.sound (fun _ => some (.dataValue "Other" [])) (by
    intro q hq; change q ∈ [] at hq; cases hq)
  change false = true at hh
  cases hh

theorem first_body {Φ : List Pred} : HasTypeC Pm B StoreTy.empty [] Γm Φ none
    (.ret (.const (.boolean true))) Out Eff.empty := by
  exact .C_Return (.V_Refine (.V_Const trivial) rfl rfl annotation.sorted.1.2 annotation.wf.1.2.1
    (.or_right ((CaptureOk.evaluated_fact (p := boolCond (.boolean true) true) (by decide)).weaken (by simp)))
    trivial annotation.declared.1.2)

theorem alts_typed : AltsTy Pm alts Input [] := by
  exact ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),
    (by intro a h; rcases List.mem_cons.mp h with rfl | h
        ; exact ⟨[],.P_Con (cd := cd) (ts := []) rfl rfl (by intro t ht; cases ht) .nil,.refl _,rfl⟩
        ; cases h)⟩

theorem facts_wf : FactsWF Pm [] Γm (pathFacts (some (.var 0)) (matchedTests alts ++ excludedTests alts)) := by
  have hw : Pred.WellFormed Pm [] Γm (.constructorIs (.var 0) "Other") := by
    refine ⟨?_,?_,?_⟩
    · simp [Pred.WF,Pred.VarsIn,Term.VarsIn,Γm,Ctx.extend]
    · exact ⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩
    · exact ⟨⟨Input,rfl,by trivial⟩,"Choice",[],cd,.var rfl rfl,rfl,rfl⟩
  intro p hp
  change p ∈ [.constructorIs (.var 0) "Other",.not (.constructorIs (.var 0) "Other")] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · exact hw
  · rcases List.mem_cons.mp hp with rfl | hp
    · exact ⟨hw.wf,hw.sorted,hw.declared⟩
    · cases hp

theorem arms_typed : HasTypeArmsQ Pm B StoreTy.empty Qempty [] Γm [] none (some (.var 0)) arms Input Out Eff.empty := by
  refine .plain alts_typed facts_wf ?_ ?_
  · simpa [bindParams,liftMany_eq,localExtend,Ty.shiftV_zero,Eff.shiftV_zero,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0)] using
      (first_body (Φ := pathFacts (some (.var 0)) (matchedTests alts)))
  · refine .plain (δ := []) ?_ (by intro p hp; cases hp) ?_
      (.nil ⟨annotation.wf.1,annotation.sorted.1,annotation.declared.1⟩)
    · exact ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),
        (by intro a h; rcases List.mem_cons.mp h with rfl | h; exact ⟨[],.P_Wild,.refl _,rfl⟩; cases h)⟩
    · simpa [bindParams,liftMany_eq,localExtend,Ty.shiftV_zero,Eff.shiftV_zero,Pred.shiftV_zero,
        show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),matchedTests,patternTest?,alternativesTest,nonemptyPattern,
        rootConstructor,pathFacts,alts,excludedTests,excludedTest?,irrefutableField,PathTest.predicate,absent] using later_body

theorem exclusion_is_closed : PathsEvaluated (.con "Selected" [] []) (excludedTests alts) := by
  intro p hp
  change p ∈ [.not (.constructorIs (.dataValue "Selected" []) "Other")] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · decide
  · cases hp


theorem source : StateTyE Pm B σ Eff.empty
    (.run (.mk cp (.match (.var 0) arms)) [] Store.empty) := by
  have hb : HasTypeC Pm B StoreTy.empty [] Γm [] none (.match (.var 0) arms) Out Eff.empty :=
    .C_Match (.V_Var rfl (by trivial)) (obs := some (.var 0))
      (by intro t ht; cases ht; exact ⟨rfl,.data,⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩) arms_typed
      (by intro v hv; exact ⟨.wild,by simp [arms,unguardedPats],by simp [matchVal]⟩)
  have hq := ClosureTy.capture capture_ok hb annotation rfl (by intro r hr; cases hr)
  have hann := capture_ok.substOk.telAnnotation annotation
  have he : cp.closeEff Eff.empty = Eff.empty := substEffValues_empty _
  rw [he] at hq
  refine ⟨StoreTy.empty,none,_,_,Eff.empty,Eff.empty,StoreOk.empty _ _ _,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩
      ⟨hann.wf.1,hann.sorted.1,hann.declared.1⟩,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,cp,Capture.empty,Capture.extend,Capture.Closed,Capture.values,
      captureSlotsClosed,Val.ClosedAt,Val.ClosedList,Comp.ClosedAt,Arm.ClosedList,arms,alts,
      Arm.bindersOf,Pat.binders,Pat.bindersList]
  · intro f hf; cases hf
  · intro l c hl; cases hl

theorem skipped : StateTyE Pm B σ Eff.empty
    (.matchRun (.con "Selected" [] []) cp arms 1 [] Store.empty) :=
  (source.match_start rfl).match_skip rfl rfl

theorem skip_step : Step Pm B σ
    (.matchRun (.con "Selected" [] []) cp arms 0 [] Store.empty) none
    (.matchRun (.con "Selected" [] []) cp arms 1 [] Store.empty) := .E_MatchSkip rfl rfl

theorem later_step : Step Pm B σ
    (.matchRun (.con "Selected" [] []) cp arms 1 [] Store.empty) none
    (.run (.mk cp (.ret (.const (.boolean false)))) [] Store.empty) := by
  simpa only [Capture.extendMany,List.foldl_nil] using
    (Step.E_MatchBody (P := Pm) (B := B) (σ := σ) (v := .con "Selected" [] [])
      (cap := cp) (arms := arms) (next := 1) (alts := [⟨.wild,[]⟩]) (body := .ret (.const (.boolean false)))
      (ws := []) (k := []) (μ := Store.empty) rfl rfl)

theorem later_target : StateTyE Pm B σ Eff.empty
    (.run (.mk cp (.ret (.const (.boolean false)))) [] Store.empty) := by
  apply skipped.match_body_zero (alts := [⟨.wild,[]⟩]) rfl rfl rfl
  constructor
  · intro i as g m hi hn hg
    have hi0 : i = 0 := by omega
    subst i
    cases Option.some.inj hi
    exact exclusion_is_closed
  · intro as g m hi
    cases Option.some.inj hi
    intro p hp; cases hp

end Excluded

end Match


namespace Guard
abbrev IntTy : Ty := .base .integer
def test : Pred := .lt (.var 0) (.integer 8)
def Out : Ty := .refined IntTy test
-- 宣言の self は var 0、比較する x は var 1 である。
def relation : Pred := .or
  (.and (boolCond (.var 0) true) (.lt (.var 1) (.integer 8)))
  (.and (boolCond (.var 0) false) (.not (.lt (.var 1) (.integer 8))))
def Result : Ty := .refined BoolTy relation
def signature : PrimSig :=
  { tparams := [], neffs := 0, names := ["x"], params := [IntTy],
    ret := Result, eff := Eff.empty, admits := fun _ _ => True, kind := .pure, opEff := none }
def Bg : Builtins := { B with
  sig := fun c => if c = "lt8" then some signature else none,
  delta := fun c _ _ _ ws => match c, ws with
    | "lt8", [.const (.integer n)] => some (.val (.const (.boolean (decide (n.val < 8)))))
    | _, _ => none }
def tel : Tel := .param "x" IntTy (.done Result Eff.empty)
def ctx : Ctx := Ctx.extend [] IntTy
def guard : Comp := .app (.prim "lt8" [] [] []) [.var 0]
def alts : List Alt := [⟨.var,[0]⟩]
def arms : List Arm := [.mk alts (some guard) (.ret (.var 0)),
  .mk [⟨.wild,[]⟩] none (.ret (.const (.integer ⟨3,by decide⟩)))]
def num (n : Int) (hn : -9223372036854775808 ≤ n ∧ n ≤ 9223372036854775807) : Val := .const (.integer ⟨n,hn⟩)
def cp (n : Int) (hn : -9223372036854775808 ≤ n ∧ n ≤ 9223372036854775807) : Capture := Capture.empty.extend (num n hn)

macro "guard_annotation" : tactic => `(tactic|
  (refine ⟨?_,?_,?_⟩ <;>
    simp [tel,signature,Result,relation,boolCond,Out,test,ctx,Ctx.extend,IntTy,BoolTy,
      Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Ty.shiftV,Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,
      Eff.WF,Eff.Canonical,Eff.empty,Tel.Sorted,Ty.Sorted,Pred.Sorted,Term.HasSort,
      Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Tel.Declared,Ty.Declared,
      declaredEff,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,
      Comparison.Allowed,sortedEff,sortedTys,declaredTys,Eff.norm,Ty.normTys]))

theorem result_ann : Ty.Annotation P [] ctx Result := by guard_annotation
theorem out_ann : Ty.Annotation P [] [] (.dependentFn (.done Out Eff.empty)) := by guard_annotation
theorem tel_ann {Γ : Ctx} : Ty.Annotation P [] Γ (.dependentFn tel) := by guard_annotation

theorem source_tel : Tel.instR [] signature.tel = tel := by
  simp [Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,PrimSig.tel,signature,signatureTel,
    tel,Result,IntTy,BoolTy,Tel.norm,Ty.rawMapRanges,Ty.norm,Ty.refineNorm,Ty.packRefinements,
    Ty.refinementPredicates,relation,Pred.conjuncts,Pred.ofConjuncts,Eff.rawMapRanges,Eff.norm,
    Eff.empty,Ty.normTys,Order.sortUnique]
  funext x
  simp [mapRangeAtoms]

theorem instance_tel : instantiatedTel (Tel.instR [] signature.tel) [] [] = tel := by
  rw [source_tel]
  simp [instantiatedTel,Tel.bind,Tel.rawBind,Tel.norm,Ty.rawBind,Ty.norm,tel,Result,IntTy,BoolTy,
    Eff.rawBind,Eff.norm,Eff.empty,typeEnvAt,rowFails,rawBindTys,instAtoms_nil,substAtoms_nil,
    Ty.normTys,Order.sortUnique,Ty.refineNorm,Ty.packRefinements,Ty.refinementPredicates,
    relation,Pred.conjuncts,Pred.ofConjuncts,SubstEnv.up,upValues,predBind,termBind,termBind?,boolCond]

theorem primitive {Γ : Ctx} {Φ : List Pred} : HasTypeV P Bg StoreTy.empty [] Γ Φ
    (.prim "lt8" [] [] []) (.dependentFn tel) := by
  have hh := HasTypeVQ.V_Prim (P := P) (B := Bg) (Ψ := StoreTy.empty) (Q := Qempty)
    (C := []) (Γ := Γ) (Φ := Φ) (b := "lt8") (s := signature) (ts := []) (es := []) (rs := []) rfl ?_ ?_ ?_ ?_
  · rwa [instance_tel] at hh
  · exact ⟨rfl,(by intro i r k hi; cases hi),(by intro r hr; cases hr),Or.inl (by intro r hr; cases hr)⟩
  · exact ⟨rfl,by simp [signature]⟩
  · refine ⟨rfl,trivial,(by intro t ht; cases ht),rfl,(by intro e he; cases he),?_,?_,?_⟩
    · exact ⟨(by intro i hi; cases hi),trivial⟩
    · intro i hi; exfalso; simpa [Qsig,QTys,QTy,QEff,signature,IntTy,Result,BoolTy,Eff.empty,Qempty] using hi
    · intro i hi; exfalso; simpa [Qsig,QTys,QTy,QEff,signature,IntTy,Result,BoolTy,Eff.empty,Qempty] using hi
  · refine ⟨?_,(by intro t ht; cases ht),(by simp [TypeArgsKinded,signature]),(by intro e he; cases he),?_⟩
    · rw [source_tel]; exact (tel_ann (Γ := [])).wf
    · rw [instance_tel]; exact tel_ann

theorem guard_typed (L : LocalCtx) : HasTypeCQ P Bg StoreTy.empty Qempty [] ctx [] none guard Result Eff.empty L := by
  have hargs := HasTypeTelArgsQ.one (B := Bg) (Ψ := StoreTy.empty) (Q := Qempty) (Φ := [])
    (Γ := ctx) (name := "x") (v := .var 0) (tel_ann (Γ := ctx)) (by
      intro i a hi; cases i with
      | zero => cases Option.some.inj hi; trivial
      | succ i => cases hi) (HasTypeVQ.V_Var rfl (by trivial))
  have hh := HasTypeCQ.C_DependentApp (R := none) (Δ := L) primitive hargs
  simpa [substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Result,BoolTy,Ty.refineNorm,Ty.packRefinements,
    Ty.refinementPredicates,relation,Pred.conjuncts,Pred.ofConjuncts,valEnv,openValue,SubstEnv.valuesOnly,
    upValues,predBind,termBind,termBind?,Val.toTerm?,Pred.shiftV,boolCond,
    substEffValues_empty,guard] using hh

theorem guard_true_fact : Entails (ctx.facts ++ [relation.open (.boolean true)]) (.lt (.var 0) (.integer 8)) := by
  have hh : Entails (ctx.facts ++ [relation.open (.boolean true)]) (relation.open (.boolean true)) :=
    .hyp (List.mem_append_right _ List.mem_cons_self)
  apply Entails.or_elim hh
  · exact .and_right (.hyp List.mem_cons_self)
  · apply Entails.false_elim
    exact .not_elim (.and_left (.hyp List.mem_cons_self))
      ((CaptureOk.evaluated_fact (p := .not (boolCond (.boolean true) false)) (by decide)).weaken (by simp))

theorem body_typed (L : LocalCtx) : HasTypeCQ P Bg StoreTy.empty Qempty [] ctx [relation.open (.boolean true)] none
    (.ret (.var 0)) Out Eff.empty L := by
  have ha : Ty.Annotation P [] ctx Out := by guard_annotation
  exact .C_Return (.V_Refine (.V_Var rfl (by trivial)) rfl rfl ha.sorted.2 ha.wf.2.1
    guard_true_fact ha.declared.1 ha.declared.2)

theorem body_requires_condition : ¬ HasTypeC P Bg StoreTy.empty [] ctx [] none (.ret (.var 0)) Out Eff.empty := by
  intro h
  have hf := (h.ret_value rfl).facts rfl test (by change test ∈ [test]; simp)
  have hh := hf.sound (fun _ => some (.integer 9)) (by intro p hp; change p ∈ [] at hp; cases hp)
  change false = true at hh
  cases hh

theorem alts_typed : AltsTy P alts IntTy [IntTy] := by
  exact ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),
    (by intro a h; rcases List.mem_cons.mp h with rfl | h; exact ⟨[IntTy],.P_Var,.refl _,rfl⟩; cases h)⟩

theorem arms_typed : HasTypeArmsQ P Bg StoreTy.empty Qempty [] [] [] none none arms IntTy Out Eff.empty := by
  refine .guarded (p := relation) alts_typed (by intro p hp; cases hp) ?_ ?_ ?_ ?_
  · exact result_ann
  · simpa [bindParams,liftMany_eq,pathFacts,localExtend,LocalCtx.extend,ctx,Ctx.extend,Result,hideConts,Ty.shiftV] using (guard_typed (localExtend 1 []))
  · simpa [bindParams,liftMany_eq,pathFacts,localExtend,ctx,Out,test,IntTy,Ty.shiftV,Pred.shiftV,Eff.shiftV,
      predBind,termBind,termBind?,Ctx.extend,LocalCtx.extend,Eff.empty,shiftVTys] using (body_typed (localExtend 1 []))
  · refine .plain (δ := []) ?_ (by intro p hp; cases hp) ?_ (.nil ⟨out_ann.wf.1,out_ann.sorted.1,out_ann.declared.1⟩)
    · exact ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),
        (by intro a h; rcases List.mem_cons.mp h with rfl | h; exact ⟨[],.P_Wild,.refl _,rfl⟩; cases h)⟩
    · apply HasTypeCQ.C_Return
      have ha : Ty.Annotation P [] [] Out := ⟨out_ann.wf.1,out_ann.sorted.1,out_ann.declared.1⟩
      exact .V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1
        (CaptureOk.evaluated_fact (by decide)) ha.declared.1 ha.declared.2


theorem sig_admits {b sg} (hs : Bg.sig b = some sg) (C : List TParam) (ts : List Ty) : sg.admits C ts := by
  change (if b = "lt8" then some signature else none) = some sg at hs
  split at hs
  · cases Option.some.inj hs; trivial
  · cases hs

theorem substitution_assumptions : Builtins.SubstitutionAssumptions P Bg where
  sat_rename := by intros; trivial
  admits_rename := by intro b sg C Γ Δ ts ξ hs _ _ _ _; exact sig_admits hs _ _
  sat_values := by intros; trivial
  admits_values := by intro b sg Ψ Q C Γ Δ Ξ ν ts hs _ _ _; exact sig_admits hs _ _
  sat_renameTypes := by intros; trivial
  admits_renameTypes := by intro b sg C C' Γ Δ ts ρ hs _ _ _ _; exact sig_admits hs _ _
  sat_subst := by intros; trivial
  admits_subst := by intro b sg C0 C1 ts ts' es' hs _ _ _ _; exact sig_admits hs _ _

theorem close_out (cap : Capture) : cap.closeTy Out = Out :=
  (Ty.subst_values_of_wf_zero out_ann.wf.1 cap.env).trans rfl

theorem captured (n : Int) (hn) : CaptureOk P Bg StoreTy.empty none ctx [] (cp n hn) :=
  (CaptureOk.empty P Bg _ _).extend ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial

theorem locals (n : Int) (hn) : CaptureLocals StoreTy.empty (cp n hn).env (localExtend 1 []) LocalRef.bound := by
  intro i kind hi
  cases i with
  | zero => cases hi
  | succ i => cases hi

theorem pending (n : Int) (hn) : GuardBodyTy P Bg StoreTy.empty none (.mk (cp n hn) (.ret (.var 0)))
    ((cp n hn).closeTy Result) Out Eff.empty := by
  have hh := GuardBodyTy.mk (cap := cp n hn) (a := Out) (e := Eff.empty) (p := relation)
    (L := localExtend 1 []) (ρ := LocalRef.bound) (Rs := none)
    (captured n hn) result_ann (body_typed _) (locals n hn) rfl
    (by rw [close_out,show (cp n hn).closeEff Eff.empty = Eff.empty from substEffValues_empty _]; exact out_ann)
    rfl (by intro r hr; cases hr)
  rw [Comp.resolveLocals_id] at hh
  change GuardBodyTy P Bg StoreTy.empty none (.mk (cp n hn) (.ret (.var 0)))
    ((cp n hn).closeTy Result) ((cp n hn).closeTy Out) ((cp n hn).closeEff Eff.empty) at hh
  rwa [close_out,show (cp n hn).closeEff Eff.empty = Eff.empty from substEffValues_empty _] at hh

theorem exhaustive : Exhaustive P IntTy (unguardedPats arms) := by
  intro v hv
  exact ⟨.wild,by simp [arms,unguardedPats],by simp [matchVal]⟩

def frame (n : Int) (hn : -9223372036854775808 ≤ n ∧ n ≤ 9223372036854775807) : Frame := .guardF (num n hn) Capture.empty arms 1 (.mk (cp n hn) (.ret (.var 0)))

theorem continuation (n : Int) (hn) : ContTy P Bg σ StoreTy.empty none Eff.empty [frame n hn]
    ((cp n hn).closeTy Result) Out Eff.empty none := by
  apply ContTy.K_Guard (R := none) (ε := Eff.empty) (a := Out) (Γ := []) (Φ := []) (Rs := none) (vs := num n hn) (t := IntTy)
    (as := Out) (es := Eff.empty) (arms0 := arms) (L := []) (ρ := LocalRef.bound) (obs := none)
    (e1 := Eff.empty)
  · exact CaptureOk.empty _ _ _ _
  · exact .V_Const trivial
  · intro t ht; cases ht
  · exact arms_typed
  · exact CaptureLocals.empty _ _ _
  · exact (Arm.resolveLocalsList_id arms).symm
  · intro r hr; cases hr
  · exact exhaustive
  · rfl
  · rfl
  · exact close_out _
  · exact substEffValues_empty _
  · exact pending n hn
  · exact ⟨fun _ h => h,fun _ h => h⟩
  · intro arm hm hg
    rcases List.mem_cons.mp hm with rfl | hm
    · cases hg
    · cases hm
  · exact .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨out_ann.wf.1,out_ann.sorted.1,out_ann.declared.1⟩
  · trivial

theorem frame_closed (n : Int) (hn) : (frame n hn).Closed := by
  simp [frame,Frame.Closed,Val.Ground,num,cp,Capture.empty,Capture.extend,Capture.Closed,Capture.values,
    captureSlotsClosed,Val.ClosedAt,Val.ClosedList,Closure.ClosedAt,Comp.ClosedAt,Arm.ClosedList,
    arms,alts,guard,Arm.bindersOf,Pat.binders,Pat.bindersList]

theorem source (n : Int) (hn) : StateTyE P Bg σ Eff.empty
    (.run (Closure.pure (.match (num n hn) arms)) [] Store.empty) := by
  have hb := HasTypeCQ.C_Match (R := none) (Δ := []) (HasTypeVQ.V_Const (P := P) (B := Bg) (Ψ := StoreTy.empty)
    (Q := Qempty) (C := []) (Γ := []) (Φ := []) (c := .integer ⟨n,hn⟩) trivial)
    (obs := none) (by intro t ht; cases ht) arms_typed exhaustive
  have hq := ClosureTy.pure hb out_ann (by intro r hr; cases hr) (by rfl) (by intro r hr; cases hr)
  refine ⟨StoreTy.empty,none,Out,Out,Eff.empty,Eff.empty,StoreOk.empty _ _ _,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩
      ⟨out_ann.wf.1,out_ann.sorted.1,out_ann.declared.1⟩,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.pure,Closure.ClosedAt,Capture.empty,Capture.Closed,captureSlotsClosed,
      Capture.values,Comp.ClosedAt,Arm.ClosedList,arms,alts,guard,num,Val.ClosedAt,
      Val.ClosedList,Arm.bindersOf,Pat.binders,Pat.bindersList]
  · intro f hf; cases hf
  · intro l c hl; cases hl

theorem match_start (n : Int) (hn) : StateTyE P Bg σ Eff.empty
    (.matchRun (num n hn) Capture.empty arms 0 [] Store.empty) := (source n hn).match_start rfl

theorem match_guard_step (n : Int) (hn) : Step P Bg σ
    (.matchRun (num n hn) Capture.empty arms 0 [] Store.empty) none
    (.run (.mk (cp n hn) guard) [frame n hn] Store.empty) := by
  simpa only [Capture.extendMany,List.foldl_cons,List.foldl_nil,cp,frame] using
    (Step.E_MatchGuard (P := P) (B := Bg) (σ := σ) (v := num n hn) (cap := Capture.empty)
      (arms := arms) (next := 0) (alts := alts) (guard := guard) (body := .ret (.var 0))
      (ws := [num n hn]) (k := []) (μ := Store.empty) rfl rfl)

theorem before_guard (n : Int) (hn) : StateTyE P Bg σ Eff.empty
    (.run (.mk (cp n hn) guard) [frame n hn] Store.empty) := by
  have ha : Ty.Annotation P [] ctx (.dependentFn (.done Result Eff.empty)) :=
    ⟨⟨result_ann.wf,trivial,rfl⟩,⟨result_ann.sorted,trivial⟩,⟨result_ann.declared,trivial⟩⟩
  have hq := ClosureTy.capture_resolved (captured n hn) (guard_typed _) (locals n hn) ha rfl (by intro r hr; cases hr)
  rw [Comp.resolveLocals_id] at hq
  have hempty : (cp n hn).closeEff Eff.empty = Eff.empty := substEffValues_empty _
  rw [hempty] at hq
  refine ⟨StoreTy.empty,none,_,Out,Eff.empty,Eff.empty,StoreOk.empty _ _ _,hq,
    ⟨fun _ h => h,fun _ h => h⟩,continuation n hn,?_,?_,?_,?_⟩
  · trivial
  · simp [Closure.ClosedAt,cp,Capture.empty,Capture.extend,Capture.Closed,Capture.values,
      captureSlotsClosed,Comp.ClosedAt,guard,num,Val.ClosedAt,Val.ClosedList]
  · intro f hf; rcases List.mem_cons.mp hf with rfl | hf; exact frame_closed n hn; cases hf
  · intro l c hl; cases hl

def bound_relation (n : Int) (hn : -9223372036854775808 ≤ n ∧ n ≤ 9223372036854775807) : Pred := predBind (upValues (valEnv (cp n hn).env).values) relation

theorem before_result (n : Int) (hn) (b : Bool)
    (heval : ((bound_relation n hn).open (.boolean b)).evalClosed = some true) :
    StateTyE P Bg σ Eff.empty (.run (Closure.pure (.ret (.const (.boolean b)))) [frame n hn] Store.empty) := by
  have ha := (captured n hn).substOk.raw_bool_annotation result_ann
  have hv : HasTypeV P Bg StoreTy.empty [] [] [] (.const (.boolean b))
      (.refined BoolTy (bound_relation n hn)) :=
    .V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1 (CaptureOk.evaluated_fact heval)
      ha.declared.1 ha.declared.2
  have hv' : HasTypeV P Bg StoreTy.empty [] [] [] (.const (.boolean b)) ((cp n hn).closeTy Result) := hv.V_Normal
  have ha' := (captured n hn).substOk.telAnnotation
    (show Ty.Annotation P [] ctx (.dependentFn (.done Result Eff.empty)) from
      ⟨⟨result_ann.wf,trivial,rfl⟩,⟨result_ann.sorted,trivial⟩,⟨result_ann.declared,trivial⟩⟩)
  have ha'' : Ty.Annotation P [] [] (.dependentFn (.done ((cp n hn).closeTy Result) Eff.empty)) := by
    change Ty.Annotation P [] [] (.dependentFn (.done ((cp n hn).closeTy Result) ((cp n hn).closeEff Eff.empty))) at ha'
    rwa [show (cp n hn).closeEff Eff.empty = Eff.empty from substEffValues_empty _] at ha'
  have hret : HasTypeC P Bg StoreTy.empty [] [] [] none (.ret (.const (.boolean b))) ((cp n hn).closeTy Result) Eff.empty := .C_Return hv'
  have hnormal : ((cp n hn).closeTy Result).norm = (cp n hn).closeTy Result := substTyValues_normal _ _
  have hnorm := HasTypeCQ.C_Normal (.C_Eff hret (Eff.Covers.refl _ _ _))
  rw [hnormal] at hnorm
  have hret' : HasTypeC P Bg StoreTy.empty [] [] [] none (.ret (.const (.boolean b))) ((cp n hn).closeTy Result) Eff.empty :=
    .C_Sub hnorm .refl (Eff.Covers.refl _ _ _) ha''.wf.1 ha''.sorted.1 ha''.declared.1
  have hq := ClosureTy.pure (R := none) hret' ha''  (by intro r hr; cases hr)
    (substTyValues_normal _ _) (by intro r hr; cases hr)
  refine ⟨StoreTy.empty,none,_,Out,Eff.empty,Eff.empty,StoreOk.empty _ _ _,hq,
    ⟨fun _ h => h,fun _ h => h⟩,continuation n hn,?_,?_,?_,?_⟩
  · trivial
  · exact ⟨trivial,trivial⟩
  · intro f hf; rcases List.mem_cons.mp hf with rfl | hf; exact frame_closed n hn; cases hf
  · intro l c hl; cases hl

theorem compare_three_step : Step P Bg σ
    (.run (.mk (cp 3 (by decide)) guard) [frame 3 (by decide)] Store.empty) none
    (.run (Closure.pure (.ret (.const (.boolean true)))) [frame 3 (by decide)] Store.empty) :=
  .E_Prim rfl rfl rfl rfl

theorem compare_nine_step : Step P Bg σ
    (.run (.mk (cp 9 (by decide)) guard) [frame 9 (by decide)] Store.empty) none
    (.run (Closure.pure (.ret (.const (.boolean false)))) [frame 9 (by decide)] Store.empty) :=
  .E_Prim rfl rfl rfl rfl

theorem true_intermediate : StateTyE P Bg σ Eff.empty
    (.run (Closure.pure (.ret (.const (.boolean true)))) [frame 3 (by decide)] Store.empty) :=
  before_result 3 (by decide) true (by decide)

theorem false_intermediate : StateTyE P Bg σ Eff.empty
    (.run (Closure.pure (.ret (.const (.boolean false)))) [frame 9 (by decide)] Store.empty) :=
  before_result 9 (by decide) false (by decide)

theorem true_step : Step P Bg σ
    (.run (Closure.pure (.ret (.const (.boolean true)))) [frame 3 (by decide)] Store.empty) none
    (.run (.mk (cp 3 (by decide)) (.ret (.var 0))) [] Store.empty) := .E_GuardT rfl

theorem false_step : Step P Bg σ
    (.run (Closure.pure (.ret (.const (.boolean false)))) [frame 9 (by decide)] Store.empty) none
    (.matchRun (num 9 (by decide)) Capture.empty arms 1 [] Store.empty) := .E_GuardF rfl

theorem true_target : StateTyE P Bg σ Eff.empty
    (.run (.mk (cp 3 (by decide)) (.ret (.var 0))) [] Store.empty) :=
  true_intermediate.guard_true substitution_assumptions rfl

theorem false_target : StateTyE P Bg σ Eff.empty
    (.matchRun (num 9 (by decide)) Capture.empty arms 1 [] Store.empty) :=
  false_intermediate.guard_false rfl


theorem nine_body_not_closed : ¬ ClosureTy P Bg StoreTy.empty [] none
    (.mk (cp 9 (by decide)) (.ret (.var 0))) Out Eff.empty := by
  intro h
  have hv := h.ret_const substitution_assumptions (StoreOk.empty P Bg σ).wf rfl
  have hf := hv.facts rfl test (by change test ∈ [test]; simp)
  have hh := hf.sound (fun _ => none) (by intro p hp; cases hp)
  change false = true at hh
  cases hh


/-- apart は現行では導けない。L30 の規則を足した後に let の結果型を真の枝へ接続する形である。
    self=false の宣言を真の枝で読む場合と、変数の条件の偽の側には O054 が要る。 -/
theorem let_if_connect
    (apart : ∀ Ξ t, Entails Ξ (boolCond t true) → Entails Ξ (boolCond t false) → Entails Ξ .falsity) :
    HasTypeC P Bg StoreTy.empty [] ctx [] none
      (.letIn guard (.ite (.var 0) (.ret (.var 1)) (.ret (.const (.integer ⟨3,by decide⟩))))) Out Eff.empty := by
  let Δ := ctx.extend Result
  have ha : Ty.Annotation P [] Δ Out := by guard_annotation
  have hb : Ty.Annotation P [] Δ BoolTy := ⟨trivial,trivial,trivial⟩
  have hc : HasTypeV P Bg StoreTy.empty [] Δ [] (.var 0) BoolTy :=
    .V_Sub (.V_Var rfl (by simp [Result,Ty.Ordinary,Ordinary,Ty.shiftV,Ty.core])) .forget
      hb.wf hb.sorted hb.declared
  have ht : HasTypeCQ P Bg StoreTy.empty Qempty [] Δ [boolCond (.var 0) true] none
      (.ret (.var 1)) Out Eff.empty (localExtend 1 []) := by
    have hvc : HasTypeV P Bg StoreTy.empty [] Δ [boolCond (.var 0) true] (.var 0)
        (.refined BoolTy (relation.shiftV 1 1)) :=
      .V_Var rfl (by simp [Result,Ty.Ordinary,Ordinary,Ty.shiftV,Ty.core])
    have hf := hvc.facts rfl (relation.shiftV 1 1) (by
      rw [Ty.assume_refined (by simp [BoolTy,Ty.Ordinary,Ordinary,Ty.core])]
      change _ ∈ [relation.shiftV 1 1]
      exact List.mem_cons_self)
    have hf' : Entails (Δ.facts ++ [boolCond (.var 0) true])
        (.or (.and (boolCond (.var 0) true) (.lt (.var 1) (.integer 8)))
          (.and (boolCond (.var 0) false) (.not (.lt (.var 1) (.integer 8))))) := by
      simpa [relation,Pred.shiftV,Pred.open,predBind,termBind,termBind?,upValues,boolCond,openingEnv,shiftIndex] using hf
    have hx := let_comparison_connect hf' (.hyp (List.mem_append_right _ List.mem_cons_self)) apart
    exact .C_Return (.V_Refine (.V_Var rfl (by trivial)) rfl rfl ha.sorted.2 ha.wf.2.1 hx
      ha.declared.1 ha.declared.2)
  have hf : HasTypeCQ P Bg StoreTy.empty Qempty [] Δ [boolCond (.var 0) false] none
      (.ret (.const (.integer ⟨3,by decide⟩))) Out Eff.empty (localExtend 1 []) :=
    .C_Return (.V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1
      ((CaptureOk.evaluated_fact (p := .lt (.integer 3) (.integer 8)) (by decide)).weaken (by simp))
      ha.declared.1 ha.declared.2)
  refine .C_Let (guard_typed []) ?_ (by exact (show Ty.Annotation P [] ctx Out from by guard_annotation).declared)
  simpa [liftMany_eq,Out,test,IntTy,Ty.shiftV,Pred.shiftV,predBind,termBind,termBind?,Eff.shiftV,Eff.empty,shiftVTys] using
    (HasTypeCQ.C_If hc rfl ht hf)

end Guard


namespace Nonempty
abbrev Input : Ty := .list (.base .unit)
def ctx : Ctx := Ctx.extend [] Input
def fact : Pred := .lt (.integer 0) (.measure .listLength (.var 0))
def Out : Ty := .refined Input fact
def alts : List Alt := [⟨.list [.wild] none [],[]⟩]

theorem annotation : Ty.Annotation P [] ctx Out := by
  refine ⟨?_,?_,?_⟩ <;>
    simp [Out,fact,ctx,Ctx.extend,Input,Ty.WF,Ty.WFList,Ty.Sorted,sortedTys,Pred.WF,Pred.VarsIn,
      Term.VarsIn,Ty.NotContCore,Ty.core,Ty.shiftV,Pred.Sorted,Term.HasSort,Term.References,
      Term.Shape,Measure.input,Measure.output,Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Ctx.declarationSelf,
      Term.Declared,Ctx.Readable,declaredTys]

theorem body : HasTypeC P B StoreTy.empty [] ctx [fact] none (.ret (.var 0)) Out Eff.empty :=
  .C_Return (.V_Refine (.V_Var rfl (by trivial)) rfl rfl annotation.sorted.2 annotation.wf.2.1
    (.hyp (List.mem_append_right _ List.mem_cons_self)) annotation.declared.1 annotation.declared.2)

theorem paths_wf : FactsWF P [] ctx (pathFacts (some (.var 0)) (matchedTests alts ++ excludedTests alts)) := by
  intro p hp
  change p ∈ [fact] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · refine ⟨?_,?_,?_⟩ <;>
      simp [fact,ctx,Ctx.extend,Input,Pred.WF,Pred.VarsIn,Term.VarsIn,Pred.Sorted,Term.HasSort,
        Term.References,Term.Shape,Measure.input,Measure.output,Ty.HasSort,Ty.sort?,Ty.shiftV,Ordinary,Ty.core,
        Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable]
  · cases hp

theorem arm : HasTypeArmsQ P B StoreTy.empty Qempty [] ctx [] none (some (.var 0))
    [.mk alts none (.ret (.var 0))] Input Out Eff.empty := by
  refine .plain (δ := []) ?_ paths_wf ?_ (.nil annotation)
  · exact ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),
      (by intro a h; rcases List.mem_cons.mp h with rfl | h
          ; exact ⟨[],.P_List (.cons .P_Wild .nil) .nil (by intro h; rfl),.refl _,rfl⟩
          ; cases h)⟩
  · simpa [bindParams,liftMany_eq,localExtend,Ty.shiftV_zero,Eff.shiftV_zero,Pred.shiftV_zero,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      alts,pathFacts,matchedTests,patternTest?,alternativesTest,rootConstructor,nonemptyPattern,PathTest.predicate,fact] using body

theorem matching : firstAlt (.list [.const .unit]) alts = some [] := rfl

theorem evaluates : PathsEvaluated (.list [.const .unit]) (matchedTests alts) := by
  intro p hp
  change p ∈ [.lt (.integer 0) (.measure .listLength (.listValue [some .unitValue]))] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · decide
  · cases hp
end Nonempty

/-- 空の観測像を整数0の既定値へ置き換えて事実を作らない。 -/
theorem lost_observation_drops_facts (tests : List PathTest) :
    pathFacts ((some (.var 0)).bind (termBind? (fun _ => none))) tests = [] := rfl

theorem state_empty_effect {P B s} (h : StateTyE P B σ Eff.empty s) : StateTy P B σ s :=
  ⟨by decide,Eff.empty,⟨rfl,(by intro a ha; cases ha)⟩,h⟩

theorem match_state_target : StateTy Match.Pm B σ
    (.run (.mk Match.cp (.ret (.var 0))) [] Store.empty) := state_empty_effect Match.body_target

theorem excluded_state_target : StateTy Match.Pm B σ
    (.run (.mk Match.cp (.ret (.const (.boolean false)))) [] Store.empty) :=
  state_empty_effect Match.Excluded.later_target

theorem guard_true_state_target : StateTy P Guard.Bg σ
    (.run (.mk (Guard.cp 3 (by decide)) (.ret (.var 0))) [] Store.empty) := state_empty_effect Guard.true_target

theorem guard_false_state_target : StateTy P Guard.Bg σ
    (.matchRun (Guard.num 9 (by decide)) Capture.empty Guard.arms 1 [] Store.empty) :=
  state_empty_effect Guard.false_target

namespace ShortCircuit

def P : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
abbrev BoolTy : Ty := .base .boolean
def tt (t : Term) := boolCond t true
/-- Γ = [b, a]（var 0 = b, var 1 = a）の下の self の述語。self は var 0、b は var 1、a は var 2。 -/
def q : Pred := .or (.and (tt (.var 0)) (.and (tt (.var 2)) (tt (.var 1)))) (.not (tt (.var 0)))
def Inner : Ty := .refined BoolTy q
def Γ2 : Ctx := Ctx.extend (Ctx.extend [] BoolTy) BoolTy
def Out : Ty := .refined BoolTy (tt (.var 0))

macro "ann" : tactic => `(tactic|
  (refine ⟨?_,?_,?_⟩ <;>
    simp [Out,Inner,q,tt,boolCond,Γ2,Ctx.extend,BoolTy,Ty.WF,Ty.WFList,Ty.NotContCore,Ty.core,Ty.shiftV,
      Tel.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Eff.WF,Eff.Canonical,Eff.empty,Tel.Sorted,Ty.Sorted,
      Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Tel.Declared,
      Ty.Declared,declaredEff,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,
      Comparison.Allowed,sortedEff,sortedTys,declaredTys,Eff.norm,Ty.normTys]))

theorem inner_ann : Ty.Annotation P [] Γ2 Inner := by ann

/-- 排中律と `not_not_elim` で、b の真偽に分ける。 -/
theorem em (Ξ : List Pred) (p : Pred) : Entails Ξ (.or p (.not p)) := by
  apply Entails.not_not_elim
  apply Entails.not_intro
  have hh : Entails (Pred.not (.or p (.not p)) :: Ξ) (.not p) := by
    apply Entails.not_intro
    exact .not_elim (.or_left (.hyp List.mem_cons_self)) (.hyp (List.mem_cons_of_mem _ List.mem_cons_self))
  exact .not_elim (.or_right hh) (.hyp List.mem_cons_self)



theorem bool_var {Γ : Ctx} {Φ} {i} (hi : Γ[i]? = some (some BoolTy)) :
    HasTypeV P B StoreTy.empty [] Γ Φ (.var i) BoolTy := .V_Var hi (by simp [BoolTy,Ty.Ordinary,Ordinary,Ty.core])

theorem bool_var' {Γ : Ctx} {Φ} {i} {a : Ty} (hi : Γ[i]? = some (some a)) (hb : a = BoolTy) :
    HasTypeV P B StoreTy.empty [] Γ Φ (.var i) BoolTy := by subst hb; exact bool_var hi

theorem then_branch : HasTypeC P B StoreTy.empty [] Γ2 [tt (.var 1)] none (.ret (.var 0)) Inner Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (bool_var rfl) rfl rfl inner_ann.sorted.2 inner_ann.wf.2.1 ?_ inner_ann.declared.1 inner_ann.declared.2
  have hg : Entails (Γ2.facts ++ [tt (.var 1)]) (tt (.var 1)) := .hyp (by simp)
  have goal : Entails (Γ2.facts ++ [tt (.var 1)])
      (.or (.and (tt (.var 0)) (.and (tt (.var 1)) (tt (.var 0)))) (.not (tt (.var 0)))) := by
    apply Entails.or_elim (em _ (tt (.var 0)))
    · exact .or_left (.and_intro (.hyp List.mem_cons_self)
        (.and_intro (hg.weaken (fun _ h => List.mem_cons_of_mem _ h)) (.hyp List.mem_cons_self)))
    · exact .or_right (.hyp List.mem_cons_self)
  simpa [q,tt,boolCond,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex] using goal

theorem else_branch : HasTypeC P B StoreTy.empty [] Γ2 [boolCond (.var 1) false] none
    (.ret (.const (.boolean false))) Inner Eff.empty := by
  apply HasTypeCQ.C_Return
  refine .V_Refine (.V_Const trivial) rfl rfl inner_ann.sorted.2 inner_ann.wf.2.1 ?_ inner_ann.declared.1 inner_ann.declared.2
  have goal : Entails (Γ2.facts ++ [boolCond (.var 1) false])
      (.not (tt (.boolean false))) := (CaptureOk.evaluated_fact (by decide)).weaken (by simp)
  have g2 := Entails.or_right (p := .and (tt (.boolean false)) (.and (tt (.var 1)) (tt (.var 0)))) goal
  simpa [q,tt,boolCond,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex] using g2

def condition : Comp := .ite (.var 1) (.ret (.var 0)) (.ret (.const (.boolean false)))
def whole : Comp := .letIn condition (.ite (.var 0) (.ret (.var 2)) (.ret (.const (.boolean true))))

theorem condition_typed : HasTypeCQ P B StoreTy.empty Qempty [] Γ2 [] none condition Inner Eff.empty [] :=
  HasTypeCQ.C_If (bool_var (Γ := Γ2) (Φ := []) (i := 1) rfl) rfl then_branch else_branch

/-- 実際の脱糖の形で、`if a && b` の真の枝が a の真を読む。apart を仮定しない。 -/
theorem short_circuit_reads_left : HasTypeC P B StoreTy.empty [] Γ2 [] none whole Out Eff.empty := by
  let Δ := Γ2.extend Inner
  have ha : Ty.Annotation P [] Δ Out := by
    refine ⟨?_,?_,?_⟩ <;> simp [Δ,Out,Inner,q,tt,boolCond,Γ2,Ctx.extend,BoolTy,Ty.WF,Ty.NotContCore,Ty.core,Ty.shiftV,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Comparison.Allowed]
  have hb : Ty.Annotation P [] Δ BoolTy := ⟨trivial,trivial,trivial⟩
  have hc : HasTypeV P B StoreTy.empty [] Δ [] (.var 0) BoolTy :=
    .V_Sub (.V_Var rfl (by simp [Inner,Ty.Ordinary,Ordinary,Ty.shiftV,Ty.core])) .forget hb.wf hb.sorted hb.declared
  have ht : HasTypeCQ P B StoreTy.empty Qempty [] Δ [boolCond (.var 0) true] none
      (.ret (.var 2)) Out Eff.empty (localExtend 1 []) := by
    have hvc : HasTypeV P B StoreTy.empty [] Δ [boolCond (.var 0) true] (.var 0)
        (.refined BoolTy (q.shiftV 1 1)) :=
      .V_Var rfl (by simp [Inner,Ty.Ordinary,Ordinary,Ty.shiftV,Ty.core])
    have hf := hvc.facts rfl (q.shiftV 1 1) (by
      rw [Ty.assume_refined (by simp [BoolTy,Ty.Ordinary,Ordinary,Ty.core])]
      change _ ∈ [q.shiftV 1 1]
      exact List.mem_cons_self)
    have hf' : Entails (Δ.facts ++ [boolCond (.var 0) true])
        (.or (.and (tt (.var 0)) (.and (tt (.var 2)) (tt (.var 1)))) (.not (tt (.var 0)))) := by
      simpa [q,tt,Pred.shiftV,Pred.open,predBind,termBind,termBind?,upValues,boolCond,openingEnv,shiftIndex] using hf
    have hcond : Entails (Δ.facts ++ [boolCond (.var 0) true]) (tt (.var 0)) := .hyp (by simp [tt])
    have hx : Entails (Δ.facts ++ [boolCond (.var 0) true]) (tt (.var 2)) := by
      apply Entails.or_elim hf'
      · exact .and_left (.and_right (.hyp List.mem_cons_self))
      · exact .false_elim (.not_elim (hcond.weaken (fun _ h => List.mem_cons_of_mem _ h)) (.hyp List.mem_cons_self))
    exact .C_Return (.V_Refine (bool_var' (a := BoolTy) (by rfl) rfl) rfl rfl ha.sorted.2 ha.wf.2.1
      (by simpa [tt,boolCond,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex] using hx) ha.declared.1 ha.declared.2)
  have hff : HasTypeCQ P B StoreTy.empty Qempty [] Δ [boolCond (.var 0) false] none
      (.ret (.const (.boolean true))) Out Eff.empty (localExtend 1 []) :=
    .C_Return (.V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1
      ((CaptureOk.evaluated_fact (p := tt (.boolean true)) (by decide)).weaken (by simp))
      ha.declared.1 ha.declared.2)
  refine .C_Let condition_typed ?_ (by
    simp [Out,tt,boolCond,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,BoolTy]
    exact ⟨_,rfl,by simp [Ty.shiftV,Ty.core]⟩)
  simpa [liftMany_eq,Out,tt,boolCond,BoolTy,Ty.shiftV,Pred.shiftV,predBind,termBind,termBind?,Eff.shiftV,Eff.empty,shiftVTys] using
    (HasTypeCQ.C_If hc rfl ht hff)
end ShortCircuit

namespace BoundObservation

def B : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => True,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => True,
    refGet := "get", refSet := "set" }
abbrev IntTy : Ty := .base .integer
def cd : ConDecl := ⟨"T",0,[IntTy]⟩
def P0 : Program :=
  { defs := fun _ => none, cons := fun _ => none, ops := fun _ => none,
    effects := fun _ => none, classes := fun _ => none, impls := fun _ => none }
def Pm : Program := { P0 with cons := fun c => if c = "Box" then some cd else none }
abbrev Input : Ty := .data "T" []
def Γm : Ctx := Ctx.extend [] Input
def fact : Pred := .constructorIs (.var 0) "Box"
def Out : Ty := .refined Input fact
def alts : List Alt := [⟨.con "Box" [.var],[0]⟩]

theorem input_ann {Γ : Ctx} : Ty.Annotation Pm [] Γ Input := by
  refine ⟨trivial,trivial,⟨⟨0,?_,rfl⟩,trivial⟩⟩
  refine ⟨⟨"Box",cd,rfl,rfl⟩,?_⟩
  intro c d hd _
  change (if c = "Box" then some cd else none) = some d at hd
  split at hd
  · cases Option.some.inj hd; rfl
  · cases hd

theorem box_cons : Pm.cons "Box" = some cd := rfl

theorem fact_wf : Pred.WellFormed Pm [] Γm fact := by
  refine ⟨?_,?_,?_⟩
  · simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn,Γm,Ctx.extend]
  · exact ⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩
  · exact ⟨⟨Input,rfl,by trivial⟩,"T",[],cd,.var rfl rfl,rfl,rfl⟩

theorem paths_wf : FactsWF Pm [] Γm (pathFacts (some (.var 0)) (matchedTests alts ++ excludedTests alts)) := by
  intro p hp
  change p ∈ [fact,.not fact] at hp
  rcases List.mem_cons.mp hp with rfl | hp
  · exact fact_wf
  · rcases List.mem_cons.mp hp with rfl | hp
    · exact ⟨fact_wf.wf,fact_wf.sorted,fact_wf.declared⟩
    · cases hp

theorem alts_typed : AltsTy Pm alts Input [IntTy] := by
  refine ⟨by decide,rfl,(by intro a h; cases Option.some.inj h; rfl),?_⟩
  intro a h
  rcases List.mem_cons.mp h with rfl | h
  · refine ⟨[IntTy],.P_Con (cd := cd) (ts := []) rfl rfl (by intro t ht; simp [cd] at ht; subst ht; trivial) ?_,.refl _,rfl⟩
    exact .cons .P_Var .nil
  · cases h

def Γb : Ctx := bindParams Γm [IntTy]
def Outs : Ty := Out.shiftV 1 0

theorem out_ann : Ty.Annotation Pm [] Γm Out := by
  exact ⟨⟨input_ann.wf,by simp [fact,Pred.WF,Pred.VarsIn,Term.VarsIn],by simp [Input,Ty.NotContCore,Ty.core]⟩,
      ⟨input_ann.sorted,⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩⟩,
      ⟨input_ann.declared,⟨⟨Input,rfl,by trivial⟩,"T",[],cd,.var rfl rfl,rfl,rfl⟩⟩⟩

theorem out_shift_ann : Ty.Annotation Pm [] Γb Outs := (ShiftMap.outer Γm [IntTy]).annotation out_ann

theorem body : HasTypeCQ Pm B StoreTy.empty Qempty [] Γb
    (liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts)))
    none (.ret (.var 1)) Outs (Eff.shiftV 1 0 Eff.empty) (localExtend 1 []) := by
  have ha := out_shift_ann
  apply HasTypeCQ.C_Return
  have hx : Entails (Γb.facts ++ liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts)))
      (.constructorIs (.var 1) "Box") := .hyp (by
        apply List.mem_append_right
        change _ ∈ [Pred.lift fact]
        simp [fact,Pred.lift,predBind,termBind,termBind?])
  refine .V_Refine (.V_Var rfl (by trivial)) rfl rfl ha.sorted.2 ha.wf.2.1 ?_ ha.declared.1 ha.declared.2
  simpa [Outs,Out,fact,Ty.shiftV,Pred.shiftV,Pred.open,predBind,termBind,termBind?,openingEnv,upValues,shiftIndex,Input] using hx

theorem arms_typed : HasTypeArmsQ Pm B StoreTy.empty Qempty [] Γm [] none (some (.var 0))
    [.mk alts none (.ret (.var 1))] Input Out Eff.empty := by
  refine .plain alts_typed paths_wf ?_ (.nil out_ann)
  rw [List.append_nil]
  exact body

-- M が guard と、束縛した本体の両方へ入る組。
def guardPred : Pred := .constructorIs (.var 2) "Box"
def guardResult : Ty := .refined (.base .boolean) guardPred

theorem guard_annotation : Ty.Annotation Pm [] (hideConts Γb) guardResult := by
  refine ⟨⟨trivial,?_,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,?_⟩,⟨trivial,?_⟩⟩
  · simp [guardPred,Γb,bindParams,Γm,Ctx.extend,hideConts,Pred.WF,Pred.VarsIn,Term.VarsIn]
  · exact ⟨⟨Input,rfl,by trivial⟩,Input,rfl,rfl⟩
  · exact ⟨⟨Input,rfl,by trivial⟩,"T",[],cd,.var rfl rfl,rfl,rfl⟩

theorem guard_reads_match : HasTypeCQ Pm B StoreTy.empty Qempty [] (hideConts Γb)
    (liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts))) none
    (.ret (.const (.boolean true))) guardResult Eff.empty (localExtend 1 []) := by
  have ha := guard_annotation
  refine .C_Return (.V_Refine (.V_Const trivial) rfl rfl ha.sorted.2 ha.wf.2.1 ?_ ha.declared.1 ha.declared.2)
  apply Entails.hyp
  apply List.mem_append_right
  change _ ∈ [Pred.lift fact]
  simp [guardPred,fact,Pred.lift,Pred.open,predBind,termBind,termBind?,openingEnv,shiftIndex]

theorem guard_requires_match : ¬ HasTypeCQ Pm B StoreTy.empty Qempty [] (hideConts Γb) [] none
    (.ret (.const (.boolean true))) guardResult Eff.empty (localExtend 1 []) := by
  intro h
  have hf := (h.ret_value rfl).facts rfl guardPred (by change guardPred ∈ [guardPred]; simp)
  have hh := hf.sound (fun _ => some (.dataValue "Other" [])) (by
    intro q hq; change q ∈ [] at hq; cases hq)
  change false = true at hh
  cases hh

theorem guarded_body : HasTypeCQ Pm B StoreTy.empty Qempty [] Γb
    (guardPred.open (.boolean true) :: liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts)))
    none (.ret (.var 1)) Outs (Eff.shiftV 1 0 Eff.empty) (localExtend 1 []) := by
  have ha := out_shift_ann
  apply HasTypeCQ.C_Return
  have hx : Entails (Γb.facts ++ (guardPred.open (.boolean true) ::
      liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts))))
      (.constructorIs (.var 1) "Box") := by
    have hh : Entails (Γb.facts ++ (guardPred.open (.boolean true) ::
        liftMany 1 (pathFacts (some (.var 0)) (matchedTests alts)))) (guardPred.open (.boolean true)) :=
      Entails.hyp (List.mem_append_right Γb.facts
      (List.mem_cons_self (a := guardPred.open (.boolean true))))
    simpa [guardPred,Pred.open,predBind,termBind,termBind?,openingEnv] using hh
  refine .V_Refine (.V_Var rfl (by trivial)) rfl rfl ha.sorted.2 ha.wf.2.1 ?_ ha.declared.1 ha.declared.2
  simpa [Outs,Out,fact,Ty.shiftV,Pred.shiftV,Pred.open,predBind,termBind,termBind?,openingEnv,upValues,shiftIndex,Input] using hx

theorem observed_guarded_arm : HasTypeArmsQ Pm B StoreTy.empty Qempty [] Γm [] none (some (.var 0))
    [.mk alts (some (.ret (.const (.boolean true)))) (.ret (.var 1))] Input Out Eff.empty := by
  refine .guarded (p := guardPred) alts_typed paths_wf guard_annotation ?_ ?_ (.nil out_ann)
  · simpa only [Γb,guardResult,List.append_nil,List.length_cons,List.length_nil] using guard_reads_match
  · simpa only [Γb,Outs,List.append_nil,List.length_cons,List.length_nil,Option.map_none] using guarded_body

end BoundObservation


end
end Benitoite.Release.Refinement.PathConditionsBoundary

open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if name.toString.startsWith "Benitoite.Release.Refinement.PathConditionsBoundary."
      then some name else none).mergeSort (fun a b => a.toString < b.toString)
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
  logInfo m!"BOUNDARY_DECLARATIONS {names.length}"
