import Benitoite.Release.Refinement.ValueMeaningInhabits
import Benitoite.Release.Refinement.ObservationInterpretation
import Benitoite.Release.Refinement.MatchFacts
import Benitoite.Release.Refinement.LogicSound

namespace Benitoite.Release.Refinement
noncomputable section

theorem ValueMeaning.refined_iff {P η a p v} :
    ValueMeaning P η (.refined a p) v ↔ ValueMeaning P η a v ∧ p.interpret (selfModel η v) = true := by
  constructor
  · intro h
    cases h with
    | mk hs hp hc =>
      have hh : ∀ q ∈ a.refinementPredicates ++ p.conjuncts, q.interpret (selfModel η v) = true := by
        simpa only [Ty.predicates_norm,Ty.refinementPredicates] using hp
      exact ⟨.mk (by simpa only [Ty.norm,Ty.core_refineNorm] using hs)
        (by intro q hq; exact hh q (List.mem_append_left _ (by simpa only [Ty.predicates_norm] using hq))) hc,
        (p.interpret_conjuncts _).mpr (fun q hq => hh q (List.mem_append_right _ hq))⟩
  · rintro ⟨h,hp⟩
    cases h with
    | mk hs ha hc =>
      refine .mk (by simpa only [Ty.norm,Ty.core_refineNorm] using hs) ?_ hc
      simp only [Ty.predicates_norm,Ty.refinementPredicates]
      intro q hq
      rcases List.mem_append.mp hq with hq | hq
      · exact ha q (by simpa only [Ty.predicates_norm] using hq)
      · exact (p.interpret_conjuncts _).mp hp q hq

/-- refine の帰納段。carrier の移送は基底の帰納仮定から受ける。 -/
theorem valueMeaning_refine {P : Program} {Γ : Ctx} {Φ : List Pred}
    {a b : Ty} {p q : Pred} {η : ObservationEnvModel} {v : Val}
    (source : ValueMeaning P η (.refined a p) v) (base : ValueMeaning P η b v)
    (facts : ∀ r ∈ Γ.facts ++ Φ, r.interpret η = true)
    (entails : Entails (p :: assumptions Γ Φ a) q) : ValueMeaning P η (.refined b q) v := by
  obtain ⟨ha,hp⟩ := ValueMeaning.refined_iff.mp source
  have hq := entails.sound (selfModel η v) (by
    intro r hr
    rcases List.mem_cons.mp hr with rfl | hr
    · exact hp
    · rcases List.mem_append.mp hr with hr | hr
      · exact ha.assume r hr
      · obtain ⟨s,hs,rfl⟩ := List.mem_map.mp hr
        rw [Pred.interpret_lift_self]
        exact facts s hs)
  exact ValueMeaning.refined_iff.mpr ⟨base,hq⟩

theorem HasTypeVQ.sub_refine_representative {P B Ψ Q C Γ Φ a b p q η v}
    (typed : HasTypeVQ P B Ψ Q C Γ Φ v (.refined a p))
    (sub : Ty.LeQ P Γ Φ a b) (ps : p.Sorted Γ (some a)) (qs : q.Sorted Γ (some b))
    (entails : Entails (p :: assumptions Γ Φ a) q)
    (annotation : Ty.Annotation P C Γ (.refined b q))
    (source : ValueMeaning P η (.refined a p) v) (base : ValueMeaning P η b v)
    (facts : ∀ r ∈ Γ.facts ++ Φ, r.interpret η = true) :
    HasTypeVQ P B Ψ Q C Γ Φ v (.refined b q) ∧ ValueMeaning P η (.refined b q) v :=
  ⟨.V_Sub typed (.refine sub ps qs entails) annotation.wf annotation.sorted annotation.declared,
    valueMeaning_refine source base facts entails⟩

def monthPredicate : Pred := .and (.le (.integer 1) (.var 0)) (.le (.var 0) (.integer 12))
def monthType : Ty := .refined (.base .integer) monthPredicate
def monthPattern : Pat := .range (.integer ⟨1,by decide⟩) (.integer ⟨12,by decide⟩)
def nonemptyPredicate : Pred := .lt (.integer 0) (.measure .listLength (.var 0))
def nonemptyType (a : Ty) : Ty := .refined (.list a) nonemptyPredicate
def headRestPattern : Pat := .list [.var] (some .bind) []

private theorem month_eval (n : Integer64Value) :
    monthPredicate.evalWith (selfModel (fun _ => none) (.const (.integer n))) =
      some (decide (1 ≤ n.val ∧ n.val ≤ 12)) := by
  by_cases h1 : 1 ≤ n.val <;> by_cases h2 : n.val ≤ 12 <;>
    simp [monthPredicate,Pred.evalWith,Pred.atomReady,Pred.atomValue,termReady,integerAs,
      observeAs,selfModel,selfObservation,Val.toTerm?,Term.observe,Term.interpret,Observation.sort,
      Integer64Value.toInt,h1,h2]

theorem month_exhaustive (P : Program) : Exhaustive P monthType [monthPattern] := by
  intro v hv
  obtain ⟨hc,hp⟩ := hv.refined_inv _ _ rfl
  obtain ⟨c,rfl,ht⟩ := hc.base_inv _ rfl
  cases c <;> simp only [Const.type,Ty.base.injEq,reduceCtorEq] at ht
  rename_i n
  have hn : 1 ≤ n.val ∧ n.val ≤ 12 := by
    change monthPredicate.evalWith _ ≠ some false at hp
    rw [month_eval] at hp
    simpa using hp
  refine ⟨monthPattern,by simp,?_⟩
  simp [monthPattern,matchVal,patternRange,Integer64Value.toInt,hn.1,hn.2]

theorem empty_refinement_exhaustive (P : Program) (a : Ty) :
    Exhaustive P (.refined a .falsity) [] := by
  intro v hv
  have hp := hv.predicates .falsity (by
    rw [Ty.predicates_norm]; exact List.mem_append_right _ (by simp [Pred.conjuncts]))
  exact (hp rfl).elim

private theorem self_list_length (xs : List Val) :
    nonemptyPredicate.evalWith (selfModel (fun _ => none) (.list xs)) = some (decide (0 < xs.length)) := by
  simp [nonemptyPredicate,Pred.evalWith,Pred.atomReady,Pred.atomValue,termReady,integerAs,observeAs,
    selfModel,selfObservation,Val.toTerm?,Term.observe,Term.interpret,Observation.sort,Observation.measure,
    MatchFacts.observeSlots_length,Val.toTermSlots_eq_map]

theorem nonempty_exhaustive (P : Program) (a : Ty) :
    Exhaustive P (nonemptyType a) [headRestPattern] := by
  intro v hv
  obtain ⟨hc,hp⟩ := hv.refined_inv _ _ rfl
  obtain ⟨xs,rfl,_⟩ := hc.list_inv _ rfl
  have hn : 0 < xs.length := by
    change nonemptyPredicate.evalWith _ ≠ some false at hp
    rw [self_list_length] at hp
    cases xs <;> simp_all
  cases xs with
  | nil => cases hn
  | cons x xs =>
    refine ⟨headRestPattern,by simp,?_⟩
    simp [headRestPattern,matchVal,matchList]

/-- 要素を観測できない List も、長さによる所属と実際の照合を持つ。 -/
theorem unobservable_list_nonempty (P : Program) :
    Inhabits P (nonemptyType (.fn [] [] (.base .unit) Eff.empty)) (.list [.fnRef "f" [] []]) ∧
      ∃ p ∈ [headRestPattern], (matchVal p (.list [.fnRef "f" [] []])).isSome := by
  have hp : RefinementPossible nonemptyPredicate (.list [.fnRef "f" [] []]) := by
    intro he; rw [self_list_length] at he; cases he
  have hi : Inhabits P (nonemptyType (.fn [] [] (.base .unit) Eff.empty)) (.list [.fnRef "f" [] []]) := Inhabits.refined (Inhabits.list (InhabitsEach.cons Inhabits.fn InhabitsEach.nil)) hp
  exact ⟨hi,nonempty_exhaustive P _ _ ((Inhabits.norm_all_iff _ _).mpr hi)⟩

private theorem closed_list_refine {P B Ψ T xs p}
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.list xs) (.list T))
    (ha : Ty.Annotation P [] [] (.list T))
    (hp : p.Sorted [] (some (.list T)))
    (hd : p.Declared P [] [] (some (.list T)))
    (hs : (p.open (.listValue (Val.toTermSlots xs))).Sorted [] none)
    (he : (p.open (.listValue (Val.toTermSlots xs))).evalWith (fun _ => none) = some true) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.list xs) (.refined (.list T) p) := by
  have hw0 : (p.open (.listValue (Val.toTermSlots xs))).WF 0 := hs.wf_none
  have hc : (p.open (.listValue (Val.toTermSlots xs))).evalClosed = some true := by
    unfold Pred.evalClosed
    rw [if_pos ⟨hw0,hs⟩]
    exact he
  exact .V_Refine hv rfl rfl hp (Pred.wf_of_sorted hp) (.closed hw0 hs hc) ha.declared hd

/-- 任意の閉じた n を用い、長さの等号と非空の篩の双方を核で導出する。 -/
theorem length_refinement_representative {P : Program} {B : Builtins} {Ψ : StoreTy} {T : Ty}
    (n : Int) (xs : List Val) (ha : Ty.Annotation P [] [] (.list T))
    (hs : HasTypeEachQ P B Ψ Qempty [] [] [] xs T)
    (hlen : (xs.length : Int) = n) (hn : 0 < n) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.list xs)
      (.refined (.list T) (.eq (.measure .listLength (.var 0)) (.integer n))) ∧
    HasTypeVQ P B Ψ Qempty [] [] [] (.list xs) (nonemptyType T) := by
  have hv : HasTypeVQ P B Ψ Qempty [] [] [] (.list xs) (.list T) :=
    .V_List hs ha.wf ha.sorted ha.declared
  have href := hv.observation_references (t := .listValue (Val.toTermSlots xs)) rfl
  have sl : (.listValue (Val.toTermSlots xs) : Term).HasSort [] .list := ⟨href,rfl⟩
  have self : (Term.var 0).HasSort [some (.list T)] .list :=
    ⟨⟨.list T,rfl,by intro b t e he; cases he⟩,⟨.list T,rfl,rfl⟩⟩
  have sint : ∀ k : Int, (Term.integer k).HasSort ([] : Ctx) .integer := fun _ => ⟨trivial,rfl⟩
  have sint' : ∀ k : Int, (Term.integer k).HasSort [some (.list T)] .integer := fun _ => ⟨trivial,rfl⟩
  have mself : (Term.measure .listLength (.var 0)).HasSort [some (.list T)] .integer :=
    ⟨self.1,⟨self.2,rfl⟩⟩
  have ml : (Term.measure .listLength (.listValue (Val.toTermSlots xs))).HasSort [] .integer :=
    ⟨sl.1,⟨sl.2,rfl⟩⟩
  constructor
  · apply closed_list_refine (p := .eq (.measure .listLength (.var 0)) (.integer n)) hv ha
      (show Pred.Sorted [] (some (.list T)) (.eq (.measure .listLength (.var 0)) (.integer n)) from ⟨mself,sint' n⟩)
      (show Pred.Declared P [] [] (some (.list T)) (.eq (.measure .listLength (.var 0)) (.integer n)) from
        ⟨⟨_,rfl,by intro b t e he; cases he⟩,trivial⟩)
      (show Pred.Sorted [] none _ from ⟨ml,sint n⟩)
    simp [Pred.open,openingEnv,predBind,termBind,termBind?,Pred.evalWith,Pred.atomReady,Pred.atomValue,
      termReady,integerAs,observeAs,Term.observe,Term.interpret,Observation.measure,Observation.sort,
      MatchFacts.observeSlots_length,Val.toTermSlots_eq_map,hlen]
  · apply closed_list_refine (p := nonemptyPredicate) hv ha
      (show Pred.Sorted [] (some (.list T)) nonemptyPredicate from ⟨sint' 0,mself⟩)
      (show Pred.Declared P [] [] (some (.list T)) nonemptyPredicate from
        ⟨trivial,⟨_,rfl,by intro b t e he; cases he⟩⟩)
      (show Pred.Sorted [] none _ from ⟨sint 0,ml⟩)
    simp [nonemptyPredicate,Pred.open,openingEnv,predBind,termBind,termBind?,Pred.evalWith,Pred.atomReady,Pred.atomValue,
      termReady,integerAs,observeAs,Term.observe,Term.interpret,Observation.measure,Observation.sort,
      MatchFacts.observeSlots_length,Val.toTermSlots_eq_map,hlen,hn]

/-- 長さの代表は型付けだけで終わらず、同じ非空型の網羅性を渡す。 -/
theorem length_refinement_coverage {P : Program} {B : Builtins} {Ψ : StoreTy} {T : Ty}
    (n : Int) (xs : List Val) (ha : Ty.Annotation P [] [] (.list T))
    (hs : HasTypeEachQ P B Ψ Qempty [] [] [] xs T)
    (hlen : (xs.length : Int) = n) (hn : 0 < n) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.list xs) (nonemptyType T) ∧
      Exhaustive P (nonemptyType T) [headRestPattern] :=
  ⟨(length_refinement_representative n xs ha hs hlen hn).2,nonempty_exhaustive P T⟩

def unobservableFunction : Val := .lam [] [] (.ret (.const .unit))
def unobservableFunctionType : Ty := .fn [] [] (.base .unit) Eff.empty

/-- 閉じた長さは任意であり、全要素が観測不能な場合も核の型付けから接続する。 -/
theorem unobservable_length_coverage (P : Program) (B : Builtins) (Ψ : StoreTy) (k : Nat) (hk : 0 < k) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.list (List.replicate k unobservableFunction))
      (nonemptyType unobservableFunctionType) ∧
    Exhaustive P (nonemptyType unobservableFunctionType) [headRestPattern] := by
  have ha : Ty.Annotation P [] [] (.list unobservableFunctionType) := by
    refine ⟨?_,?_,?_⟩ <;> simp [unobservableFunctionType,Ty.WF,Ty.Sorted,Ty.Declared,Ty.WFList,sortedTys,
      declaredTys,NamesWF,Eff.WF,Eff.Canonical,Eff.empty,Eff.norm,Eff.atoms,sortedEff,declaredEff,rowFails]
  have hv : HasTypeVQ P B Ψ Qempty [] [] [] unobservableFunction unobservableFunctionType := by
    apply HasTypeVQ.V_Lam (by simp [NamesWF]) ha.wf ha.sorted _ ha.declared
    exact .C_Return (.V_Const (by trivial))
  have hs : HasTypeEachQ P B Ψ Qempty [] [] [] (List.replicate k unobservableFunction) unobservableFunctionType := by
    clear hk
    induction k with
    | zero => exact .nil
    | succ k ih => exact .cons hv ih
  exact length_refinement_coverage (k : Int) _ ha hs (by simp) (by omega)

/-- 開いた算術の証明書を受け、静的に非空型へ強めてから網羅性へ進む入口。 -/
theorem HasTypeVQ.nonempty_from_entails {P B Ψ Q C Γ Φ T v t}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v (.list T)) (ht : v.toTerm? = some t)
    (ha : Ty.Annotation P C Γ (.list T))
    (hp : nonemptyPredicate.Sorted Γ (some (.list T)))
    (hd : nonemptyPredicate.Declared P C Γ (some (.list T)))
    (he : Entails (Γ.facts ++ Φ) (nonemptyPredicate.open t)) :
    HasTypeVQ P B Ψ Q C Γ Φ v (nonemptyType T) ∧ Exhaustive P (nonemptyType T) [headRestPattern] :=
  ⟨.V_Refine hv rfl ht hp (Pred.wf_of_sorted hp) he ha.declared hd,nonempty_exhaustive P T⟩

/-- 閉じた型の意味から、捕捉元の開いた型の正規形へ所属を反映する。 -/
theorem Capture.meaning_coverage {P : Program} {cap : Capture} {a : Ty} {w : Val} {ps : List Pat}
    (meaning : ValueMeaning P (fun _ => none) (cap.closeTy a) w)
    (coverage : Exhaustive P a ps) : ∃ p ∈ ps, (matchVal p w).isSome := by
  apply coverage w
  apply Inhabits.subst_values_reflect_normal cap.env
  exact (Inhabits.norm_all_iff _ _).mp (valueMeaning_inhabits_normal meaning)

/-- 型付き捕捉から閉じた変数の型付けと、意味を渡す網羅性の接続を得る。 -/
theorem CaptureOk.variable_coverage {P B Ψ R Γ Φ cap i a ps}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ (.var i) a)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : Ψ.WF)
    (coverage : Exhaustive P a ps) :
    HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap (.var i)) (cap.closeTy a) ∧
    (ValueMeaning P (fun _ => none) (cap.closeTy a) (closeVal cap (.var i)) →
      ∃ p ∈ ps, (matchVal p (closeVal cap (.var i))).isSome) := by
  have ht := hv.subst hA hstore hc.substOk (by
    intro p hp
    simpa [Ctx.facts] using
      hc.conditions p (List.mem_append_right _ hp))
  exact ⟨ht,fun hm => Capture.meaning_coverage hm coverage⟩

end
end Benitoite.Release.Refinement
