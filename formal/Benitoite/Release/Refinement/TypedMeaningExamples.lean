import Benitoite.Release.Refinement.TypedCoverage

/-! # 意味と所属の入口の適用（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement.TypedMeaningExamples
noncomputable section

theorem month_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨5,by decide⟩)) monthType := by
  refine .V_Refine (.V_Const (by trivial)) rfl rfl ?_ ?_ ?_ trivial ?_
  · exact ⟨⟨⟨trivial,rfl⟩,⟨⟨_,rfl,by intro b t e h; cases h⟩,⟨_,rfl,rfl⟩⟩⟩,
      ⟨⟨⟨_,rfl,by intro b t e h; cases h⟩,⟨_,rfl,rfl⟩⟩,⟨trivial,rfl⟩⟩⟩
  · simp [monthPredicate,Pred.WF,Term.VarsIn,Pred.VarsIn]
  · change Entails [] (.and (.le (.integer 1) (.integer 5)) (.le (.integer 5) (.integer 12)))
    exact .and_intro (.integer_le (by decide)) (.integer_le (by decide))
  · exact ⟨⟨trivial,⟨_,rfl,by intro b t e h; cases h⟩⟩,
      ⟨⟨_,rfl,by intro b t e h; cases h⟩,trivial⟩⟩

/-- 三つの型付けの入口と部分型の意味の移送を同じ導出へ適用する。 -/
theorem typed_entries {P : Program} {B Ψ a v} (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v a) :
    ValueMeaning P (fun _ => none) a v ∧ Inhabits P a.norm v ∧ Inhabits P a v ∧
      ValueMeaning P (fun _ => none) a.norm v :=
  ⟨typed_value_meaning_closed valid typed, inhabits_of_typed valid typed,
    inhabits_of_typed_raw valid typed,
    valueMeaning_sub (Γ := []) (Φ := []) valid (.convert (Ty.norm_idem a).symm) (by simp [Ctx.facts])
      (typed_value_meaning_closed valid typed)⟩

theorem month_entries (P : Program) (B : Builtins) (Ψ : StoreTy) (valid : P.VarianceValid) :
    ValueMeaning P (fun _ => none) monthType (.const (.integer ⟨5,by decide⟩)) ∧
    Inhabits P monthType.norm (.const (.integer ⟨5,by decide⟩)) ∧
    Inhabits P monthType (.const (.integer ⟨5,by decide⟩)) ∧
    ∃ p ∈ [monthPattern], (matchVal p (.const (.integer ⟨5,by decide⟩))).isSome := by
  have h := typed_entries valid (month_typed P B Ψ)
  exact ⟨h.1,h.2.1,h.2.2.1,month_exhaustive P _ h.2.1⟩

theorem empty_entries {P : Program} {B Ψ a v} (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v (.refined a .falsity)) : False := by
  have h := typed_entries valid typed
  obtain ⟨p,hp,_⟩ := empty_refinement_exhaustive P a v h.2.1
  cases hp

theorem nonempty_entries (P : Program) (B : Builtins) (Ψ : StoreTy)
    (valid : P.VarianceValid) (k : Nat) (hk : 0 < k) :
    ValueMeaning P (fun _ => none) (nonemptyType unobservableFunctionType)
      (.list (List.replicate k unobservableFunction)) ∧
    Inhabits P (nonemptyType unobservableFunctionType).norm (.list (List.replicate k unobservableFunction)) ∧
    Inhabits P (nonemptyType unobservableFunctionType) (.list (List.replicate k unobservableFunction)) ∧
    ∃ p ∈ [headRestPattern], (matchVal p (.list (List.replicate k unobservableFunction))).isSome := by
  obtain ⟨typed,cover⟩ := unobservable_length_coverage P B Ψ k hk
  have h := typed_entries valid typed
  exact ⟨h.1,h.2.1,h.2.2.1,cover _ h.2.1⟩

def unknownTerm : Term := .measure .mapSize (.mapValue [none] [none])
def unknownPredicate : Pred := .eq unknownTerm unknownTerm
def unknownType : Ty := .refined (.base .integer) unknownPredicate

theorem unknown_eval (v : Val) :
    unknownPredicate.evalWith (selfModel (fun _ => none) v) = none := rfl

theorem unknown_typed (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer ⟨5,by decide⟩)) unknownType := by
  refine .V_Refine (.V_Const (by trivial)) rfl rfl ?_ ?_ ?_ trivial ?_
  · simp [unknownPredicate,unknownTerm,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,varsInSlot,varsInSlots,Term.Shape,Measure.input,Measure.output]
  · simp [unknownPredicate,unknownTerm,Pred.WF,Pred.VarsIn,Term.VarsIn,varsInSlot,varsInSlots]
  · exact Entails.eq_refl
  · simp [unknownPredicate,unknownTerm,Pred.Declared,Term.Declared,declaredSlot,declaredSlots]

theorem unknown_entries (P : Program) (B : Builtins) (Ψ : StoreTy) (valid : P.VarianceValid) :
    ValueMeaning P (fun _ => none) unknownType (.const (.integer ⟨5,by decide⟩)) ∧
    Inhabits P unknownType.norm (.const (.integer ⟨5,by decide⟩)) ∧
    Inhabits P unknownType (.const (.integer ⟨5,by decide⟩)) ∧
    unknownPredicate.evalWith (selfModel (fun _ => none) (.const (.integer ⟨5,by decide⟩))) = none := by
  have h := typed_entries valid (unknown_typed P B Ψ)
  exact ⟨h.1,h.2.1,h.2.2.1,unknown_eval _⟩

def five : Val := .const (.integer ⟨5,by decide⟩)
def thirteen : Val := .const (.integer ⟨13,by decide⟩)

theorem thirteen_rejected {P} (hi : Inhabits P monthType thirteen) : False := by
  obtain ⟨p,hp,hs⟩ := month_exhaustive P _ ((Inhabits.norm_all_iff _ _).mpr hi)
  have hn : matchVal monthPattern thirteen = none := by
    simp [monthPattern,thirteen,matchVal,patternRange,Integer64Value.toInt]
  rcases List.mem_singleton.mp hp with rfl
  simp [hn] at hs

theorem reject_top {P B Ψ} (valid : P.VarianceValid) :
    ¬ HasTypeVQ P B Ψ Qempty [] [] [] thirteen monthType :=
  fun h => thirteen_rejected (inhabits_of_typed_raw valid h)

theorem reject_list {P B Ψ} (valid : P.VarianceValid) :
    ¬ HasTypeVQ P B Ψ Qempty [] [] [] (.list [thirteen]) (.list monthType) := by
  intro h
  obtain ⟨xs,hxs,heach⟩ := (inhabits_of_typed_raw valid h).list_inv monthType rfl
  cases Val.list.inj hxs
  cases heach with
  | cons he _ => exact thirteen_rejected he

def mapT : Ty := .map unobservableFunctionType (.base .unit)
def selfUnknownTerm : Term := .measure .mapSize (.var 0)
def selfUnknownPred : Pred := .eq selfUnknownTerm selfUnknownTerm
def selfUnknownType : Ty := .refined mapT selfUnknownPred
def lamMap : Val := .mapV [unobservableFunction] [.const .unit]

theorem selfUnknown_eval : selfUnknownPred.evalWith (selfModel (fun _ => none) lamMap) = none := rfl

theorem selfUnknown_typed (P : Program) (B : Builtins) (Ψ : StoreTy)
    (hsat : B.sat [] unobservableFunctionType.norm TParam.keyC) :
    HasTypeVQ P B Ψ Qempty [] [] [] lamMap selfUnknownType := by
  have ha : Ty.Annotation P [] [] unobservableFunctionType := by
    refine ⟨?_,?_,?_⟩ <;> simp [unobservableFunctionType,Ty.WF,Ty.Sorted,Ty.Declared,Ty.WFList,sortedTys,
      declaredTys,NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,sortedEff,declaredEff]
  have hu : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hf : HasTypeVQ P B Ψ Qempty [] [] [] unobservableFunction unobservableFunctionType := by
    apply HasTypeVQ.V_Lam (by simp [NamesWF]) ha.wf ha.sorted _ ha.declared
    exact .C_Return (.V_Const (by trivial))
  have hk : HasTypeEachQ P B Ψ Qempty [] [] [] [unobservableFunction] unobservableFunctionType := .cons hf .nil
  have hc : HasTypeVQ P B Ψ Qempty [] [] [] (.const .unit) (.base .unit) := .V_Const (by trivial)
  have hw : HasTypeEachQ P B Ψ Qempty [] [] [] [.const .unit] (.base .unit) := .cons hc .nil
  have hl : HasTypeVQ P B Ψ Qempty [] [] [] lamMap mapT := .V_Map hk hw rfl hsat ha hu
  have self : (Term.var 0).HasSort [some mapT] .map :=
    ⟨⟨mapT,rfl,by intro b t e he; cases he⟩,⟨mapT,rfl,rfl⟩⟩
  have mself : selfUnknownTerm.HasSort [some mapT] .integer := ⟨self.1,⟨self.2,rfl⟩⟩
  exact .V_Refine hl rfl rfl ⟨mself,mself⟩ (by simp [selfUnknownPred,selfUnknownTerm,Pred.WF,Term.VarsIn,Pred.VarsIn]) Entails.eq_refl ⟨ha.declared,hu.declared⟩
    ⟨⟨_,rfl,by intro b t e he; cases he⟩,⟨_,rfl,by intro b t e he; cases he⟩⟩

theorem selfUnknown_entries (P : Program) (B : Builtins) (Ψ : StoreTy) (valid : P.VarianceValid)
    (hsat : B.sat [] unobservableFunctionType.norm TParam.keyC) :
    ValueMeaning P (fun _ => none) selfUnknownType lamMap ∧ Inhabits P selfUnknownType.norm lamMap ∧
    Inhabits P selfUnknownType lamMap := by
  have t := selfUnknown_typed P B Ψ hsat
  exact ⟨typed_value_meaning_closed valid t, inhabits_of_typed valid t, inhabits_of_typed_raw valid t⟩

-- unknown を除かない: unknown の値があるので空のパターン列は網羅でない
theorem unknown_not_excluded (P : Program) (B : Builtins) (Ψ : StoreTy) (valid : P.VarianceValid)
    (hsat : B.sat [] unobservableFunctionType.norm TParam.keyC) : ¬ Exhaustive P selfUnknownType [] := by
  intro h
  obtain ⟨p,hp,_⟩ := h _ (selfUnknown_entries P B Ψ valid hsat).2.1
  cases hp

def depPred : Pred := .eq (.var 0) (.var 1)
def depType : Ty := .refined (.base .integer) depPred
def cap5 : Capture := Capture.empty.extend five

theorem close_depType : cap5.closeTy depType = .refined (.base .integer) (.eq (.var 0) (.integer 5)) := by
  rfl

theorem dependent_capture_entries (P : Program) (B : Builtins) (Ψ : StoreTy)
    (valid : P.VarianceValid) :
    ValueMeaning P (fun _ => none) (cap5.closeTy depType) five ∧ Inhabits P depType five := by
  have ht : HasTypeVQ P B Ψ Qempty [] [] [] five (cap5.closeTy depType) := by
    rw [close_depType]
    refine .V_Refine (.V_Const (by trivial)) rfl rfl ?_ ?_ Entails.eq_refl trivial ?_
    · exact ⟨⟨⟨_,rfl,by intro b t e he; cases he⟩,⟨_,rfl,rfl⟩⟩,⟨trivial,rfl⟩⟩
    · simp [Pred.WF,Pred.VarsIn,Term.VarsIn]
    · exact ⟨⟨_,rfl,by intro b t e he; cases he⟩,trivial⟩
  exact Capture.typed_meaning (v := .var 0) (a := depType) valid ht

theorem cap_month (P : Program) (B : Builtins) (Ψ : StoreTy) (valid : P.VarianceValid) :
    (ValueMeaning P (fun _ => none) (cap5.closeTy monthType) five ∧ Inhabits P monthType five) ∧
    ∃ p ∈ [monthPattern], (matchVal p five).isSome := by
  have ht : HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap5 (.var 0)) (cap5.closeTy monthType) := month_typed P B Ψ
  exact ⟨Capture.typed_meaning (v := .var 0) (a := monthType) valid ht,
    Capture.typed_coverage valid ht (month_exhaustive P)⟩

theorem nonempty_capture_coverage (P : Program) (B : Builtins) (Ψ : StoreTy)
    (valid : P.VarianceValid) (k : Nat) (hk : 0 < k) :
    ∃ p ∈ [headRestPattern],
      (matchVal p (closeVal (Capture.empty.extend (.list (List.replicate k unobservableFunction))) (.var 0))).isSome := by
  obtain ⟨typed,cover⟩ := unobservable_length_coverage P B Ψ k hk
  refine Capture.typed_coverage (B := B) (Ψ := Ψ) (cap := Capture.empty.extend (.list (List.replicate k unobservableFunction)))
    (a := nonemptyType unobservableFunctionType) valid ?_ cover
  change HasTypeVQ P B Ψ Qempty [] [] [] (.list (List.replicate k unobservableFunction))
    (substTyValues _ (nonemptyType unobservableFunctionType))
  have hw : (nonemptyType unobservableFunctionType).WF 0 0 0 := by
    simp [nonemptyType,unobservableFunctionType,nonemptyPredicate,Ty.WF,Ty.WFList,NamesWF,
      Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore]
  rw [Ty.subst_values_of_wf_zero hw]
  exact typed.V_Normal

end
end Benitoite.Release.Refinement.TypedMeaningExamples
