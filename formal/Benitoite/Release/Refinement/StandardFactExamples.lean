import Benitoite.Release.Refinement.StandardDecimal
import Benitoite.Release.Refinement.PreparedLeafExamples
import Benitoite.Release.Refinement.MatchStateLeaves
import Benitoite.Release.Refinement.Step

/-! # 有限の事実を読む部分型、if と guard の本体 -/
namespace Benitoite.Release.Refinement.StandardFactExamples
noncomputable section

private def lengthContext : Ctx := [some (.base .integer)]
private def lengthEq : Pred := .eq (.measure .listLength (.var 0)) (.var 1)
private def positiveN : Pred := .lt (.integer 0) (.var 0)
private def lengthSource : Ty := .refined (.list (.base .unit)) lengthEq
private def lengthTarget : Ty := nonemptyType (.base .unit)

/-- 先頭の長さの等式と、型域の二前提の後にある n>0 を読む。 -/
private def lengthCertificate : Certificate :=
  .substitute (.lt (.integer 0) (.var 0)) (.var 1) (.measure .listLength (.var 0))
    (.symm (.hyp 0)) (.use 3) .integer

/-- len=n と n>0 の両方を使う実証明書から、構文の LeQ へ進む。 -/
theorem length_le (P : Program) :
    Ty.LeQ P lengthContext [positiveN] lengthSource lengthTarget := by
  apply checked_refinement (c := lengthCertificate) .refl
  · simp [lengthEq,lengthContext,Pred.Sorted,Term.HasSort,Term.References,Term.Shape,
      Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Measure.input,Measure.output]
  · simp [nonemptyPredicate,Pred.Sorted,Term.HasSort,Term.References,
      Term.Shape,Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Measure.input,Measure.output]
  · decide

/-- 同じ元の篩から、正数の経路条件を除くと部分型にはできない。 -/
theorem length_without_positive_rejected (P : Program) :
    ¬ Ty.LeQ P lengthContext [] lengthSource lengthTarget := by
  intro h
  have he := h.assume nonemptyPredicate (by
    simp [lengthTarget,nonemptyType,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,nonemptyPredicate])
  let η : ObservationEnvModel := fun i => if i = 0 then some (.listValue []) else some (.integer 0)
  have facts : ∀ p ∈ lengthSource.assume ++ (lengthContext.facts ++ []).map Pred.lift,
      p.interpret η = true := by
    intro p hp
    simp [lengthSource,lengthEq,lengthContext,Ty.assume,Ty.carrierFacts,Ty.core,
      Ty.refinementPredicates,Pred.conjuncts,Ctx.facts,integerBounds,
      Pred.open,predBind,Pred.lift,termBind,termBind?] at hp
    rcases hp with rfl | rfl | rfl <;> decide
  have bad := he.sound η facts
  have no : nonemptyPredicate.interpret η = false := by decide
  rw [no] at bad; cases bad

example (P : Program) : Ty.LeQ P lengthContext [positiveN] lengthSource lengthTarget := length_le P
example (P : Program) : ¬ Ty.LeQ P lengthContext [] lengthSource lengthTarget := length_without_positive_rejected P

private def booleanContext : Ctx := [some (.base .boolean)]
private def notTrue : Pred := .not (boolCond (.var 0) true)
private def falseType : Ty := .refined (.base .boolean) notTrue
private def falseBody : Comp := .ret (.var 0)
private def falseIf : Comp := .ite (.var 0) (.ret (.const (.boolean false))) falseBody

private theorem false_annotation (P : Program) (Γ : Ctx) : Ty.Annotation P [] Γ falseType := by
  refine ⟨?_,?_,?_⟩
  all_goals simp [falseType,notTrue,boolCond,Ty.WF,Ty.Sorted,Ty.Declared,Ty.NotContCore,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,
    Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Comparison.Allowed,Ctx.declarationSelf,Ctx.extend,Ty.shiftV]

private theorem return_with_not (P : Program) (B : Builtins) (Ψ : StoreTy) (Φ : List Pred)
    (he : Entails (booleanContext.facts ++ Φ) (.not (boolCond (.var 0) true))) :
    HasTypeCQ P B Ψ Qempty [] booleanContext Φ none falseBody falseType Eff.empty [] := by
  apply HasTypeCQ.C_Return
  refine HasTypeVQ.V_Refine (a := .base .boolean) (.V_Var rfl (by intro b t e h; cases h)) rfl rfl
    (false_annotation P booleanContext).sorted.2 (false_annotation P booleanContext).wf.2.1 ?_
    trivial (false_annotation P booleanContext).declared.2
  simpa [notTrue,Pred.open,predBind,boolCond,termBind,termBind?] using he

/-- Boolean の偽側の有限な葉から得た Not を、返却値の篩に使う。 -/
theorem false_fact_typing (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] booleanContext [boolCond (.var 0) false]
      none falseBody falseType Eff.empty [] := by
  apply return_with_not
  simpa [booleanContext,Ctx.facts,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates]
    using Entails.and_right PreparedLeafExamples.false_side

private theorem false_constant (P : Program) (B : Builtins) (Ψ : StoreTy) (Φ : List Pred) :
    HasTypeCQ P B Ψ Qempty [] booleanContext Φ none (.ret (.const (.boolean false))) falseType Eff.empty [] := by
  apply HasTypeCQ.C_Return
  refine HasTypeVQ.V_Refine (a := .base .boolean) (.V_Const trivial) rfl rfl
    (false_annotation P booleanContext).sorted.2 (false_annotation P booleanContext).wf.2.1 ?_
    trivial (false_annotation P booleanContext).declared.2
  have h : (notTrue.open (.boolean false)).evalClosed = some true := by decide
  exact (CaptureOk.evaluated_fact h).weaken (by simp)

/-- 条件が未知のまま両枝を検査し、偽側の本体では Not を読む。 -/
theorem false_if_typing (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] booleanContext [] none falseIf falseType Eff.empty [] :=
  .C_If (.V_Var rfl (by intro b t e h; cases h)) rfl (false_constant P B Ψ _) (false_fact_typing P B Ψ)

/-- Not を供給する前提がない同じ本体は、同じ篩の結果型にはできない。 -/
theorem false_body_rejected (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ¬ HasTypeCQ P B Ψ Qempty [] booleanContext [] none falseBody falseType Eff.empty [] := by
  intro h
  have he := (h.ret_value rfl).facts (t := .var 0) rfl notTrue (by
    simp [falseType,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates,Pred.conjuncts,notTrue])
  have bad := he.sound (fun _ => some (.boolean true)) (by
    intro p hp
    simp [booleanContext,Ctx.facts,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates] at hp)
  have no : (notTrue.open (.var 0)).interpret (fun _ => some (.boolean true)) = false := by decide
  rw [no] at bad; cases bad

/-- 元の CaptureOk を保持して if 全体を閉じる。 -/
theorem false_if_closed {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap) :
    ClosureTy P B Ψ [] none (.mk cap falseIf) (cap.closeTy falseType) (cap.closeEff Eff.empty) :=
  ClosureTy.capture hc (false_if_typing P B Ψ) ((false_annotation P _).done_empty) rfl (by intro r h; cases h)

/-- 実際に観測した条件だけを選び、同じ捕捉で両方の枝を閉じる。 -/
theorem false_if_selected {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap)
    (b : Bool) (selected : closeVal cap (.var 0) = .const (.boolean b)) :
    ClosureTy P B Ψ [] none
      (.mk cap (if b then .ret (.const (.boolean false)) else falseBody))
      (cap.closeTy falseType) (cap.closeEff Eff.empty) := by
  apply (false_if_closed hc).ite_selected b
  simp [falseIf,Closure.view,Closure.code,Closure.capture,selected,falseBody]

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] booleanContext [boolCond (.var 0) false]
      none falseBody falseType Eff.empty [] := false_fact_typing P B Ψ
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ¬ HasTypeCQ P B Ψ Qempty [] booleanContext [] none falseBody falseType Eff.empty [] := false_body_rejected P B Ψ
example {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap)
    (selected : closeVal cap (.var 0) = .const (.boolean false)) :
    ClosureTy P B Ψ [] none (.mk cap falseBody) (cap.closeTy falseType) (cap.closeEff Eff.empty) := by
  simpa using false_if_selected hc false selected


private def guardPredicate : Pred := .or (boolCond (.var 0) false) (.not (boolCond (.var 1) true))
private def guardType : Ty := .refined (.base .boolean) guardPredicate
private def guardCode : Comp := .ite (.var 0) (.ret (.const (.boolean false))) (.ret (.const (.boolean true)))

private theorem guard_annotation (P : Program) : Ty.Annotation P [] booleanContext guardType := by
  refine ⟨?_,?_,?_⟩
  all_goals simp [guardType,guardPredicate,booleanContext,boolCond,Ty.WF,Ty.Sorted,Ty.Declared,Ty.NotContCore,
    Pred.WF,Pred.VarsIn,Pred.Sorted,Pred.Declared,Term.Declared,Term.HasSort,Term.Shape,Term.References,
    Term.VarsIn,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Ty.core,Comparison.Allowed,
    Ctx.declarationSelf,Ctx.extend,Ty.shiftV]

private theorem guard_return (P : Program) (B : Builtins) (Ψ : StoreTy) (Φ : List Pred) (b : Bool)
    (h : Entails (booleanContext.facts ++ Φ) (guardPredicate.open (.boolean b))) :
    HasTypeCQ P B Ψ Qempty [] booleanContext Φ none (.ret (.const (.boolean b))) guardType Eff.empty [] :=
  .C_Return (.V_Refine (.V_Const trivial) rfl rfl (guard_annotation P).sorted.2
    (guard_annotation P).wf.2.1 h trivial (guard_annotation P).declared.2)

/-- 真になることも偽になることもある guard を、未知の捕捉値のまま検査する。 -/
theorem guard_typing (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] booleanContext [] none guardCode guardType Eff.empty [] := by
  refine .C_If (.V_Var rfl (by intro b t e h; cases h)) rfl (guard_return P B Ψ _ false ?_) (guard_return P B Ψ _ true ?_)
  · change Entails _ (.or (boolCond (.boolean false) false) (.not (boolCond (.var 0) true)))
    exact .or_left ((CaptureOk.evaluated_fact (p := boolCond (.boolean false) false) (by decide)).weaken (by simp))
  · change Entails _ (.or (boolCond (.boolean true) false) (.not (boolCond (.var 0) true)))
    apply Entails.or_right
    simpa [booleanContext,Ctx.facts,Ty.assume,Ty.core,Ty.carrierFacts,Ty.refinementPredicates]
      using Entails.and_right PreparedLeafExamples.false_side

/-- guard の実結果 true で開いた契約から、body が必要とする Not を得る。 -/
theorem guard_body_typing (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] booleanContext [guardPredicate.open (.boolean true)]
      none falseBody falseType Eff.empty [] := by
  apply return_with_not
  change Entails _ (.not (boolCond (.var 0) true))
  have hor : Entails (booleanContext.facts ++ [guardPredicate.open (.boolean true)])
      (.or (boolCond (.boolean true) false) (.not (boolCond (.var 0) true))) :=
    .hyp (by simp [guardPredicate,Pred.open,predBind,boolCond,termBind,termBind?])
  apply Entails.or_elim hor
  · apply Entails.false_elim
    exact .not_elim (.hyp List.mem_cons_self)
      ((CaptureOk.evaluated_fact (p := .not (boolCond (.boolean true) false)) (by decide)).weaken (by simp))
  · exact .hyp List.mem_cons_self

private def wildAlts : List Alt := [⟨.wild,[]⟩]
private def guardArms : List Arm :=
  [.mk wildAlts (some guardCode) falseBody, .mk wildAlts none (.ret (.const (.boolean false)))]
private def guardMatch : Comp := .match (.const (.boolean true)) guardArms

private theorem wild_alts (P : Program) : AltsTy P wildAlts (.base .boolean) [] := by
  refine ⟨by decide,rfl,?_,?_⟩
  · intro alt h; cases Option.some.inj h; rfl
  · intro alt h; cases List.mem_singleton.mp h
    exact ⟨[],.P_Wild,List.Perm.nil,rfl⟩

/-- obs=None も除かず、guard と通常の後続腕を実際の腕の判断に渡す。 -/
theorem guard_arms_typing (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeArmsQ P B Ψ Qempty [] booleanContext [] none none guardArms
      (.base .boolean) falseType Eff.empty [] := by
  refine .guardedEmpty (p := guardPredicate) (wild_alts P) ?_ ?_ ?_ ?_ ?_
  · intro p hp; cases hp
  · simpa [guardType,bindParams,booleanContext,hideConts,Ty.shiftV_zero,Ty.core] using guard_annotation P
  · simpa [guardType,bindParams,booleanContext,hideConts,liftMany_eq,pathFacts,localExtend,Ty.shiftV_zero,Ty.core] using guard_typing P B Ψ
  · simpa [bindParams,booleanContext,liftMany_eq,pathFacts,localExtend,Ty.shiftV_zero,Eff.shiftV_zero] using guard_body_typing P B Ψ
  · refine .plainEmpty (wild_alts P) ?_ ?_ ?_
    · intro p hp; cases hp
    · simpa [bindParams,booleanContext,liftMany_eq,pathFacts,localExtend,Ty.shiftV_zero,Eff.shiftV_zero] using false_constant P B Ψ []
    · exact .nil (false_annotation P _)

/-- wildcard の後続腕を保持した match 本体も同じ結果型で検査する。 -/
theorem guard_match_typing (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeCQ P B Ψ Qempty [] booleanContext [] none guardMatch falseType Eff.empty [] := by
  refine .C_Match (.V_Const trivial) (obs := none) (by intro t ht; cases ht) (guard_arms_typing P B Ψ) trivial ?_
  intro v _
  exact ⟨.wild,by simp [guardArms,unguardedPats,wildAlts],by simp [matchVal]⟩

/-- 同じ CaptureOk で guard・body・後続腕を含む実本体を閉じる。 -/
theorem guard_match_closed {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap) :
    ClosureTy P B Ψ [] none (.mk cap guardMatch) (cap.closeTy falseType) (cap.closeEff Eff.empty) :=
  ClosureTy.capture hc (guard_match_typing P B Ψ) ((false_annotation P _).done_empty) rfl (by intro r h; cases h)

/-- guard の各選択枝も元の捕捉で閉じる。 -/
theorem guard_selected {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap)
    (b : Bool) (selected : closeVal cap (.var 0) = .const (.boolean b)) :
    ClosureTy P B Ψ [] none (.mk cap (if b then .ret (.const (.boolean false)) else .ret (.const (.boolean true))))
      (cap.closeTy guardType) (cap.closeEff Eff.empty) := by
  have h := ClosureTy.capture hc (guard_typing P B Ψ) ((guard_annotation P).done_empty) rfl (by intro r h; cases h)
  apply h.ite_selected b
  simp [guardCode,Closure.view,Closure.code,Closure.capture,selected]

example {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap) :
    ClosureTy P B Ψ [] none (.mk cap guardMatch) (cap.closeTy falseType) (cap.closeEff Eff.empty) := guard_match_closed hc
example {P B Ψ cap} (hc : CaptureOk P B Ψ none booleanContext [] cap)
    (selected : closeVal cap (.var 0) = .const (.boolean false)) :
    ClosureTy P B Ψ [] none (.mk cap (.ret (.const (.boolean true))))
      (cap.closeTy guardType) (cap.closeEff Eff.empty) := by simpa using guard_selected hc false selected

/-- 観測の欠けを true に変えず、到達しない右辺は unknown のままでよい。 -/
example : (boolCond (.var 0) true).evalWith (fun _ => none) = none ∧
    (Pred.and (.compare .boolean .eq (.boolean false) (.boolean true))
      (boolCond (.var 1) true)).evalWith (fun _ => none) = some false ∧
    (Pred.or (.compare .boolean .eq (.boolean true) (.boolean true))
      (boolCond (.var 1) true)).evalWith (fun _ => none) = some true := by decide

/-- 左が偽だったという事実は、到達しない右辺を真にしない。 -/
theorem unreachable_right_rejected :
    ¬ Entails [boolCond (.var 0) false] (boolCond (.var 1) true) := by
  intro h
  have bad := h.sound (fun _ => some (.boolean false)) (by
    intro p hp; cases List.mem_singleton.mp hp; decide)
  have no : (boolCond (.var 1) true).interpret (fun _ => some (.boolean false)) = false := by decide
  rw [no] at bad; cases bad

example : Entails [boolCond (.var 0) false]
    (.or (.not (boolCond (.var 0) true)) (boolCond (.var 1) true)) :=
  .or_left (.and_right PreparedLeafExamples.false_side)
example : ¬ Entails [boolCond (.var 0) false] (boolCond (.var 1) true) := unreachable_right_rejected


private def booleanCapture (b : Bool) : Capture := Capture.empty.extend (.const (.boolean b))
private theorem boolean_capture (P : Program) (B : Builtins) (Ψ : StoreTy) (b : Bool) :
    CaptureOk P B Ψ none booleanContext [] (booleanCapture b) := by
  have h := (CaptureOk.empty P B Ψ none).extend (a := .base .boolean)
    (v := .const (.boolean b)) ⟨trivial,trivial,trivial⟩ (.V_Const trivial) trivial
  simpa [booleanCapture,booleanContext,Ctx.extend,Ty.shiftV] using h

/-- 型付きの真偽の値を持つ同じ捕捉で、if と guard の両側を実際に選択する。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (b : Bool) :
    ClosureTy P B Ψ [] none
      (.mk (booleanCapture b) (if b then .ret (.const (.boolean false)) else falseBody))
      ((booleanCapture b).closeTy falseType) ((booleanCapture b).closeEff Eff.empty) ∧
    ClosureTy P B Ψ [] none
      (.mk (booleanCapture b) (if b then .ret (.const (.boolean false)) else .ret (.const (.boolean true))))
      ((booleanCapture b).closeTy guardType) ((booleanCapture b).closeEff Eff.empty) ∧
    ClosureTy P B Ψ [] none (.mk (booleanCapture b) guardMatch)
      ((booleanCapture b).closeTy falseType) ((booleanCapture b).closeEff Eff.empty) :=
  ⟨false_if_selected (boolean_capture P B Ψ b) b rfl,
    guard_selected (boolean_capture P B Ψ b) b rfl,guard_match_closed (boolean_capture P B Ψ b)⟩

/-- 標準整数比較の同じ正常応答を捕捉し、Boolean の枝の実本体へ渡す。 -/
theorem integer_comparison_branch (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : Benitoite.Interval.IntKind) (a b : Benitoite.Interval.IntegerValue k) :
    ∃ value, StandardScalar.integerDelta ("%" ++ StandardScalar.integerModule k ++ ".lessOrEqual") [] [] []
      [.const (embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
       .const (embedConst (Benitoite.Interval.IntegerValue.toConst k b))] =
        some (.val (.const (.boolean value))) ∧
      ClosureTy P B Ψ [] none
        (.mk (booleanCapture value) (if value then .ret (.const (.boolean false)) else falseBody))
        ((booleanCapture value).closeTy falseType) ((booleanCapture value).closeEff Eff.empty) := by
  let value := Comparison.le.fromEqLt (a.toInt == b.toInt) (decide (a.toInt < b.toInt)) (decide (b.toInt < a.toInt))
  refine ⟨value,?_,false_if_selected (boolean_capture P B Ψ value) value rfl⟩
  exact StandardScalar.integerDelta_order k .le a b (Or.inr (Or.inl rfl))

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ value, StandardScalar.integerDelta "%Integer8.lessOrEqual" [] [] []
      [.const (.integer8 2),.const (.integer8 3)] = some (.val (.const (.boolean value))) ∧
      ClosureTy P B Ψ [] none
        (.mk (booleanCapture value) (if value then .ret (.const (.boolean false)) else falseBody))
        ((booleanCapture value).closeTy falseType) ((booleanCapture value).closeEff Eff.empty) :=
  integer_comparison_branch P B Ψ .integer8 ⟨2,by decide⟩ ⟨3,by decide⟩


/-- 同じ捕捉で型付けた if は、選択した同じ本体へ実際に一歩進む。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (σ : PathEnv) (μ : Store) (b : Bool) :
    ClosureTy P B Ψ [] none (.mk (booleanCapture b) falseIf)
      ((booleanCapture b).closeTy falseType) ((booleanCapture b).closeEff Eff.empty) ∧
    Step P B σ (.run (.mk (booleanCapture b) falseIf) [] μ) none
      (.run (.mk (booleanCapture b) (if b then .ret (.const (.boolean false)) else falseBody)) [] μ) := by
  refine ⟨false_if_closed (boolean_capture P B Ψ b),?_⟩
  cases b
  · exact .E_IfF rfl
  · exact .E_IfT rfl

/-- guard が true を返した同じ捕捉へ契約を足し、Not を読む本体を閉じる。 -/
private theorem guard_true_body_closed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ClosureTy P B Ψ [] none (.mk (booleanCapture false) falseBody)
      ((booleanCapture false).closeTy falseType) ((booleanCapture false).closeEff Eff.empty) := by
  exact ClosureTy.capture ((boolean_capture P B Ψ false).addEvaluated
    ((guard_annotation P).open_boolean true) (by decide))
    (guard_body_typing P B Ψ) ((false_annotation P _).done_empty) rfl (by intro r h; cases h)

/-- 偽の捕捉値に対する guard の二歩と、同じ body の型付けを同時に保持する。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) (σ : PathEnv) (μ : Store) :
    ∃ mid, Step P B σ
      (.run (.mk (booleanCapture false) guardCode)
        [.guardF (.const (.boolean true)) (booleanCapture false) guardArms 1 (.mk (booleanCapture false) falseBody)] μ)
      none mid ∧
      Step P B σ mid none (.run (.mk (booleanCapture false) falseBody) [] μ) ∧
      ClosureTy P B Ψ [] none (.mk (booleanCapture false) falseBody)
        ((booleanCapture false).closeTy falseType) ((booleanCapture false).closeEff Eff.empty) :=
  ⟨_,.E_IfF rfl,.E_GuardT rfl,guard_true_body_closed P B Ψ⟩

/-- 真の捕捉値では guard は false を返し、後続腕へ進む。 -/
example (P : Program) (B : Builtins) (σ : PathEnv) (μ : Store) :
    ∃ mid, Step P B σ
      (.run (.mk (booleanCapture true) guardCode)
        [.guardF (.const (.boolean true)) (booleanCapture true) guardArms 1 (.mk (booleanCapture true) falseBody)] μ)
      none mid ∧
      Step P B σ mid none (.matchRun (.const (.boolean true)) (booleanCapture true) guardArms 1 [] μ) :=
  ⟨_,.E_IfT rfl,.E_GuardF rfl⟩


private theorem constant_reply {P B Ψ c} (ws : List Val) (ok : ConstOK B c) :
    Outcome.Typed P B Ψ (.val (.const c)) c.type ∧ AdequateResult ws (.val (.const c)) ∧
      ∀ n, (Outcome.val (.const c)) ≠ .exit n :=
  ⟨⟨.V_Const ok,trivial⟩,(by intro σ hσ inputs; trivial),(by intro n h; cases h)⟩

/-- 同じ実算術の応答に、型・Ground・AdequateResult・exit の排除をそろえる。 -/
theorem arithmetic_reply_contract (P : Program) (B : Builtins) (Ψ : StoreTy)
    (k : Benitoite.Interval.IntKind) (op : Benitoite.Interval.WidthBinary)
    (a b v : Benitoite.Interval.IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) :
    ∃ out, StandardScalar.integerBinaryDelta k op a b = out ∧
      Outcome.Typed P B Ψ out (embedConst (Benitoite.Interval.IntegerValue.toConst k v)).type ∧
      AdequateResult [.const (embedConst (Benitoite.Interval.IntegerValue.toConst k a)),
        .const (embedConst (Benitoite.Interval.IntegerValue.toConst k b))] out ∧
      ∀ n, out ≠ .exit n := by
  have ht := StandardScalar.integer_result_typed P B Ψ Qempty [] [] [] k v
  exact ⟨_,(StandardScalar.integerBinary_reply k op a b v supported normal).1,
    constant_reply _ (ht.inv_const rfl).1⟩

/-- 実際の丸め応答にも同じ三条件を供給する。 -/
theorem decimal_reply_contract (P : Program) (B : Builtins) (Ψ : StoreTy)
    (c d : Int) (s t : Nat) (places : Benitoite.Release.Integer64Value)
    (mode : StandardScalar.DecimalRounding)
    (normal : StandardScalar.decimalRound c s places.toInt mode = .normal d t) :
    ∃ out, StandardScalar.decimalRoundReply c s places.toInt mode = out ∧
      Outcome.Typed P B Ψ out (.base .decimal) ∧
      AdequateResult [.const (.decimal c s),.const (.integer places)] out ∧
      ∀ n, out ≠ .exit n := by
  have represented := StandardScalar.decimalRound_represented c s places.toInt mode d t normal
  exact ⟨_,by rw [StandardScalar.decimalRoundReply,normal],constant_reply (c := .decimal d t) _ represented⟩

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ out, StandardScalar.integerBinaryDelta .integer8 .add ⟨2,by decide⟩ ⟨3,by decide⟩ = out ∧
      Outcome.Typed P B Ψ out (.base .integer8) ∧
      AdequateResult [.const (.integer8 2),.const (.integer8 3)] out ∧ ∀ n, out ≠ .exit n :=
  arithmetic_reply_contract P B Ψ .integer8 .add ⟨2,by decide⟩ ⟨3,by decide⟩ ⟨5,by decide⟩ (Or.inl rfl) rfl
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ out, StandardScalar.decimalRoundReply 25 1 0 .halfToEven = out ∧
      Outcome.Typed P B Ψ out (.base .decimal) ∧
      AdequateResult [.const (.decimal 25 1),.const (.integer ⟨0,by decide⟩)] out ∧ ∀ n, out ≠ .exit n :=
  decimal_reply_contract P B Ψ 25 2 1 0 ⟨0,by decide⟩ .halfToEven rfl

end
open StandardScalar

/-- 数値の部分表を合成し、同じ呼出しに応答した行をすべて残す。 -/
private def scalarReplies (name : PrimName) (ts : List Ty) (es : List Eff)
    (rs : List RangeExpr) (ws : List Val) : List Outcome :=
  ([integerDelta,byteDelta,characterDelta,float32Delta,float64Delta,decimalDelta] :
      List (PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome)).filterMap
    (fun delta => delta name ts es rs ws)

/-- 空・重複・異なる基本型、余分な行・範囲の引数を全ての表で拒否する。 -/
private def equalityCalls (name : PrimName) (t : Ty) (wrong : Ty) (ws : List Val) : List (List Outcome) :=
  [scalarReplies name [t] [] [] ws,
   scalarReplies name [.refined t (.le (.integer 0) (.integer 0))] [] [] ws,
   scalarReplies name [] [] [] ws,
   scalarReplies name [t,t] [] [] ws,
   scalarReplies name [wrong] [] [] ws,
   scalarReplies name [t] [Eff.empty] [] ws,
   scalarReplies name [t] [] [.top] ws]

example : equalityCalls "%eq" (.base .integer8) (.base .float) [.const (.integer8 7),.const (.integer8 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .integer8) (.base .float) [.const (.integer8 7),.const (.integer8 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .integer16) (.base .float) [.const (.integer16 7),.const (.integer16 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .integer16) (.base .float) [.const (.integer16 7),.const (.integer16 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .integer32) (.base .float) [.const (.integer32 7),.const (.integer32 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .integer32) (.base .float) [.const (.integer32 7),.const (.integer32 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .integer) (.base .float) [.const (.integer ⟨7,by decide⟩),.const (.integer ⟨7,by decide⟩)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .integer) (.base .float) [.const (.integer ⟨7,by decide⟩),.const (.integer ⟨7,by decide⟩)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .unsignedInteger16) (.base .float) [.const (.unsignedInteger16 7),.const (.unsignedInteger16 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .unsignedInteger16) (.base .float) [.const (.unsignedInteger16 7),.const (.unsignedInteger16 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .unsignedInteger32) (.base .float) [.const (.unsignedInteger32 7),.const (.unsignedInteger32 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .unsignedInteger32) (.base .float) [.const (.unsignedInteger32 7),.const (.unsignedInteger32 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .unsignedInteger64) (.base .float) [.const (.unsignedInteger64 7),.const (.unsignedInteger64 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .unsignedInteger64) (.base .float) [.const (.unsignedInteger64 7),.const (.unsignedInteger64 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .byte) (.base .float) [.const (.byte 7),.const (.byte 7)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .byte) (.base .float) [.const (.byte 7),.const (.byte 7)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .character) (.base .float) [.const (.character 'a'),.const (.character 'a')] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .character) (.base .float) [.const (.character 'a'),.const (.character 'a')] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .float32) (.base .float) [.const (.float32 0x3f800000),.const (.float32 0x3f800000)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .float32) (.base .float) [.const (.float32 0x3f800000),.const (.float32 0x3f800000)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .float) (.base .character) [.const (.float64 0x3ff0000000000000),.const (.float64 0x3ff0000000000000)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .float) (.base .character) [.const (.float64 0x3ff0000000000000),.const (.float64 0x3ff0000000000000)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl
example : equalityCalls "%eq" (.base .decimal) (.base .float) [.const (.decimal 1 0),.const (.decimal 1 0)] =
    [[.val (.const (.boolean true))],[.val (.const (.boolean true))],[],[],[],[],[]] := by rfl
example : equalityCalls "%ne" (.base .decimal) (.base .float) [.const (.decimal 1 0),.const (.decimal 1 0)] =
    [[.val (.const (.boolean false))],[.val (.const (.boolean false))],[],[],[],[],[]] := by rfl

/-- Option の実宣言と同じ二構成子だけを持つ適用例のプログラム。 -/
private def optionProgram : Program where
  defs := fun _ => none
  cons := fun c => if c = "Option.Some" then some ⟨"Option",1,[.tvar 0]⟩
    else if c = "Option.None" then some ⟨"Option",1,[]⟩ else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private theorem optionArity : optionProgram.DataArity "Option" 1 := by
  refine ⟨⟨"Option.Some",⟨"Option",1,[.tvar 0]⟩,rfl,rfl⟩,?_⟩
  intro c cd hc _
  dsimp only [optionProgram] at hc
  split at hc
  · cases hc; rfl
  · split at hc
    · cases hc; rfl
    · cases hc

example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .integer8 ⟨0,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .integer8 ⟨128,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .integer16 ⟨0,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .integer16 ⟨32768,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .integer32 ⟨0,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .integer32 ⟨2147483648,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .unsignedInteger16 ⟨0,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .unsignedInteger16 ⟨-1,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .unsignedInteger32 ⟨0,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .unsignedInteger32 ⟨-1,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .unsignedInteger64 ⟨0,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  integerDelta_fromInteger_typed optionProgram B Ψ .unsignedInteger64 ⟨-1,by decide⟩ (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  byte_fromInteger_typed optionProgram B Ψ ⟨0,by decide⟩ rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  byte_fromInteger_typed optionProgram B Ψ ⟨256,by decide⟩ rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  character_fromInteger_typed optionProgram B Ψ ⟨0,by decide⟩ rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  character_fromInteger_typed optionProgram B Ψ ⟨55296,by decide⟩ rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalFromFloat_typed optionProgram B Ψ 0 (some (15,1)) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalFromFloat_typed optionProgram B Ψ 0 (none) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalFromFloat_typed optionProgram B Ψ 0 (some (79228162514264337593543950336,0)) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalTruncate_typed optionProgram B Ψ 15 1 (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalTruncate_typed optionProgram B Ψ 9223372036854775808 0 (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalToUnsigned64_typed optionProgram B Ψ 10 1 (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :=
  decimalToUnsigned64_typed optionProgram B Ψ 15 1 (by decide) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :
    ∃ v, integerDelta "UnsignedInteger64.toInteger" [] [] [] [.const (.unsignedInteger64 7)] = some (.val v) ∧
      HasTypeVQ optionProgram B Ψ Qempty [] [] [] v (.data "Option" [.base .integer]) := by
  refine ⟨integerOption .integer64 (integerConvert .integer64 7),?_,
    integerOption_typed optionProgram B Ψ .integer64 _ rfl rfl optionArity⟩
  exact integerDelta_toInteger .unsignedInteger64 ⟨7,by decide⟩ (by decide)
example (B : Builtins) (Ψ : StoreTy) :
    ∃ v, integerDelta "UnsignedInteger64.toInteger" [] [] [] [.const (.unsignedInteger64 18446744073709551615)] = some (.val v) ∧
      HasTypeVQ optionProgram B Ψ Qempty [] [] [] v (.data "Option" [.base .integer]) := by
  refine ⟨integerOption .integer64 (integerConvert .integer64 18446744073709551615),?_,
    integerOption_typed optionProgram B Ψ .integer64 _ rfl rfl optionArity⟩
  exact integerDelta_toInteger .unsignedInteger64 ⟨18446744073709551615,by decide⟩ (by decide)

example (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ optionProgram B Ψ Qempty [] [] []
      (.con "Option.Some" [.base .integer8] [.const (.integer8 7)]) (.data "Option" [.base .integer8]) :=
  integerOption_typed optionProgram B Ψ .integer8 (some ⟨7,by decide⟩) rfl rfl optionArity
example (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ optionProgram B Ψ Qempty [] [] []
      (.con "Option.None" [.base .integer8] []) (.data "Option" [.base .integer8]) :=
  integerOption_typed optionProgram B Ψ .integer8 none rfl rfl optionArity

end Benitoite.Release.Refinement.StandardFactExamples
