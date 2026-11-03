import Benitoite.Release.Refinement.CarrierFactsMeaning
import Benitoite.Release.Refinement.MeaningTransport
import Benitoite.Release.Refinement.ValueFacts

/-! # 閉じた型付けから値の意味（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace TypedMeaning

/-- 宣言の欄の意味から構成子の意味を得る。 -/
theorem constructor_meaning {P η c cd ts tys vs}
    (lookup : P.cons c = some cd) (n : ts.length = cd.ntys)
    (wf : ∀ t ∈ cd.args, t.WF 0 cd.ntys 0)
    (fields : ValueMeanings P η (cd.args.map (Ty.subst ts [])) vs) :
    ValueMeaning P η (.data cd.data ts) (.con c tys vs) := by
  refine .mk ?_ (by intro p hp; cases hp) (by intro p hp; cases hp)
  refine .con lookup (by simp [Ty.normTys_eq_map, n]) wf ?_
  have he : Ty.subst (Ty.normTys ts) [] = Ty.subst ts [] := funext (fun a => Ty.subst_norm_images a ts)
  rw [he]; exact fields

/- 全域の代入の観測と解釈を同時に移す。 -/
mutual
  theorem bridge_term (u : Term) (ν : ObservationEnv) (ξ ζ : ObservationEnvModel)
      (h : ∀ i, ∃ s, ν i = some s ∧ s.observe ξ = ζ i ∧ s.interpret ξ = ζ i) :
      ∃ s, termBind? ν u = some s ∧ s.observe ξ = u.observe ζ ∧ s.interpret ξ = u.interpret ζ := by
    cases u with
    | var i => obtain ⟨s,a,b,c⟩ := h i; exact ⟨s,a,by simpa [Term.observe] using b,by simpa [Term.interpret] using c⟩
    | listValue xs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots xs ν ξ ζ h],by simp [Term.interpret,bridge_slots xs ν ξ ζ h]⟩
    | setValue xs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots xs ν ξ ζ h],by simp [Term.interpret,bridge_slots xs ν ξ ζ h]⟩
    | dataValue c xs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots xs ν ξ ζ h],by simp [Term.interpret,bridge_slots xs ν ξ ζ h]⟩
    | mapValue ks vs => exact ⟨_,rfl,by simp [Term.observe,bridge_slots ks ν ξ ζ h,bridge_slots vs ν ξ ζ h],by simp [Term.interpret,bridge_slots ks ν ξ ζ h,bridge_slots vs ν ξ ζ h]⟩
    | field r t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.field r s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | measure m t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.measure m s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | add x y =>
      obtain ⟨s,a,b,c⟩ := bridge_term x ν ξ ζ h
      obtain ⟨s',a',b',c'⟩ := bridge_term y ν ξ ζ h
      exact ⟨.add s s',by simp [termBind?,a,a'],by simp only [Term.observe,b,b'],by simp only [Term.interpret,c,c']⟩
    | neg t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.neg s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | scale k t =>
      obtain ⟨s,a,b,c⟩ := bridge_term t ν ξ ζ h
      exact ⟨.scale k s,by simp [termBind?,a],by simp only [Term.observe,b],by simp only [Term.interpret,c]⟩
    | _ => exact ⟨_,rfl,rfl,rfl⟩
  theorem bridge_slots (xs : List (Option Term)) (ν : ObservationEnv) (ξ ζ : ObservationEnvModel)
      (h : ∀ i, ∃ s, ν i = some s ∧ s.observe ξ = ζ i ∧ s.interpret ξ = ζ i) :
      observeSlots ξ (bindSlots ν xs) = observeSlots ζ xs := by
    cases xs with
    | nil => rfl
    | cons x xs =>
      cases x with
      | none => simp [bindSlots,slotBind,observeSlots,bridge_slots xs ν ξ ζ h]
      | some t =>
        obtain ⟨s,a,b,_⟩ := bridge_term t ν ξ ζ h
        simp [bindSlots,slotBind,a,observeSlots,b,bridge_slots xs ν ξ ζ h]
end

theorem bridge_bind (u : Term) (ν ξ ζ) (h : ∀ i, ∃ s, ν i = some s ∧ Term.observe ξ s = ζ i ∧ Term.interpret ξ s = ζ i) :
    (termBind ν u).interpret ξ = u.interpret ζ := by
  obtain ⟨s,a,_,c⟩ := bridge_term u ν ξ ζ h
  simp [termBind,a,c]
theorem bridge_pred (p : Pred) (ν ξ ζ) (h : ∀ i, ∃ s, ν i = some s ∧ Term.observe ξ s = ζ i ∧ Term.interpret ξ s = ζ i) :
    (predBind ν p).interpret ξ = p.interpret ζ := by
  have key := fun u => bridge_bind u ν ξ ζ h
  induction p with
  | and p q a b => simp only [predBind,Pred.interpret,a,b]
  | or p q a b => simp only [predBind,Pred.interpret,a,b]
  | not p a => simp only [predBind,Pred.interpret,a]
  | _ => simp only [predBind,Pred.interpret,Pred.atomValue,integerAs,observeAs,key] <;> (try rfl)

/-- 値の項の最上位は field 等の演算を含まない -/
theorem toTerm_interpret {v : Val} {t : Term} (ht : v.toTerm? = some t) (η) : t.interpret η = t.observe η := by
  unfold Val.toTerm? at ht
  split at ht <;> cases ht <;> rfl

theorem refine_bridge {v t η} {p : Pred} (ht : v.toTerm? = some t) (hc : t.Closed)
    (hp : (p.open t).interpret η = true) : p.interpret (selfModel η v) = true := by
  have := bridge_pred p (fun i => match i with | 0 => some t | j+1 => some (.var j)) η (selfModel η v) (by
    intro i; cases i with
    | zero =>
      refine ⟨t,rfl,?_,?_⟩
      · simp [selfModel,selfObservation,ht,Term.observe_closed hc η]
      · rw [toTerm_interpret ht]; simp [selfModel,selfObservation,ht,Term.observe_closed hc η]
    | succ j => exact ⟨.var j,rfl,rfl,rfl⟩)
  rw [← this]; exact hp


theorem const_norm (c : Const) : (Const.type c).norm = Const.type c := by cases c <;> rfl
theorem const_meaning (P η) (c : Const) (hc : c.NumericRepresented) : ValueMeaning P η (Const.type c) (.const c) := by
  refine .mk ?_ ?_ ?_
  · rw [const_norm]; cases c <;> exact .const
  · rw [const_norm]; cases c <;> (intro p hp; cases hp)
  · exact hc.carrierFacts η

theorem closed_of_refs {t : Term} (h : t.References []) : t.Closed :=
  Term.varsIn_mono h (fun i hi => by obtain ⟨a,ha,_⟩ := hi; simp at ha)

/-- 閉じた型付き値の観測から、自己モデルで型域を読む。 -/
theorem carrierFacts_meaning_closed {P B Ψ Q C v a}
    (h : HasTypeVQ P B Ψ Q C [] [] v a) (η : ObservationEnvModel) :
    ∀ p ∈ a.carrierFacts, p.interpret (selfModel η v) = true := by
  intro p hp
  obtain ⟨s,hs⟩ := Ty.carrierFacts_hasSort hp
  obtain ⟨t,ht,hr⟩ := h.observation hs
  have he := h.carrierFacts p hp
  simp only [ht, Option.getD_some] at he
  have hw := closed_of_refs hr.references
  exact refine_bridge ht hw (by
    apply he.sound η
    simp [Ctx.facts])

mutual
  theorem typed_meaning_aux {P : Program} {B Ψ Q C Γ Φ v a} (valid : P.VarianceValid)
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hΓ : Γ = []) (hΦ : Φ = []) :
      ValueMeaning P (fun _ => none) a v := by
    match h with
    | .V_Var hg _ => subst hΓ; simp at hg
    | .V_Const hc => exact const_meaning P _ _ hc.represented
    | .V_Lam .. => exact .mk .fn (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. =>
      exact MeaningTransport.dependentFn_meaning
    | .V_ExternalHandle .. => exact .mk .external (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_PathBases .. => exact .mk .pathBases (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_ScopePattern .. => exact .mk .scopePattern (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Checked .. => exact .of_scoped .checked
    | .V_CheckedRequest .. => exact .of_scoped .checkedRequest
    | .V_CheckedAt .. => exact .of_scoped .checkedAt
    | .V_AtError hs =>
      rw [hs.errorType_eq]
      exact .mk (.atError ⟨rfl,hs.standard.2⟩) (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Map .. => exact .mk .map (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Set .. => exact .mk .set (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Dict .. => exact .mk .dict (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Raise .. => exact .mk .fn (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_LocRef .. => exact .mk .reference (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_LocLazy .. => exact .mk .lazy (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Bytes .. => exact .mk .bytes (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Con lookup n _ wf hs _ =>
      exact constructor_meaning lookup n wf (typed_meaning_auxs valid hs hΓ hΦ)
    | .V_Super .. => exact .mk .dict (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_List hs .. =>
      exact .mk (.list (typed_each_norm valid hs hΓ hΦ)) (by intro p hp; cases hp) (by intro p hp; cases hp)
    | .V_Sub hv sub .. =>
      have m := typed_meaning_aux valid hv hΓ hΦ
      subst hΓ hΦ
      exact valueMeaning_sub valid sub (by simp [Ctx.facts]) m
    | .V_Normal hv => exact (ValueMeaning.norm_iff _ _ _ _).mpr (typed_meaning_aux valid hv hΓ hΦ)
    | .V_Refine hv _ ht _ _ he .. =>
      have m := typed_meaning_aux valid hv hΓ hΦ
      subst hΓ hΦ
      refine ValueMeaning.refined_iff.mpr ⟨m, ?_⟩
      have href := hv.observation_references ht
      exact refine_bridge ht (closed_of_refs href) (he.sound _ (by simp [Ctx.facts]))
  theorem typed_meaning_auxs {P : Program} {B Ψ Q C Γ Φ vs as} (valid : P.VarianceValid)
      (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (hΓ : Γ = []) (hΦ : Φ = []) :
      ValueMeanings P (fun _ => none) as vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (typed_meaning_aux valid hv hΓ hΦ) (typed_meaning_auxs valid hs hΓ hΦ)
  theorem typed_each_norm {P : Program} {B Ψ Q C Γ Φ vs a} (valid : P.VarianceValid)
      (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hΓ : Γ = []) (hΦ : Φ = []) :
      ValueMeaningEach P (fun _ => none) a.norm vs := by
    match h with
    | .nil => exact .nil
    | .cons hv hs =>
      exact .cons ((ValueMeaning.norm_iff _ _ _ _).mpr (typed_meaning_aux valid hv hΓ hΦ))
        (typed_each_norm valid hs hΓ hΦ)
end

end TypedMeaning

theorem typed_value_meaning_closed {P : Program} {B Ψ v a} (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v a) : ValueMeaning P (fun _ => none) a v :=
  TypedMeaning.typed_meaning_aux valid h rfl rfl

theorem inhabits_of_typed {P : Program} {B Ψ v a} (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v a) : Inhabits P a.norm v :=
  valueMeaning_inhabits_normal (typed_value_meaning_closed valid h)

theorem inhabits_of_typed_raw {P : Program} {B Ψ v a} (valid : P.VarianceValid)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v a) : Inhabits P a v :=
  (Inhabits.norm_all_iff _ _).mp (inhabits_of_typed valid h)

end
end Benitoite.Release.Refinement
