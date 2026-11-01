import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.VarianceTransport

/-!
# 型付きの値から得る整数観測と篩の事実

置換の定理を使わずに、元の型付けの導出から事実を取り出す。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}

theorem Ty.LeQ.integerCarrier {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
    a.IntegerCarrier ↔ b.IntegerCarrier := by
  match h with
  | .refl => rfl
  | .convert he =>
    change a.HasSort .integer ↔ b.HasSort .integer
    rw [←Ty.hasSort_norm a, ←Ty.hasSort_norm b, he]
  | .trans h₁ h₂ => exact h₁.integerCarrier.trans h₂.integerCarrier
  | .data _ | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ => rfl
  | .forget | .introduce _ _ => rfl
  | .refine hv _ _ _ => exact hv.integerCarrier
  | .dependentFn _ | .scoped _ => rfl
  | .scoped_forget => simp [Ty.IntegerCarrier, Ty.HasSort, Ty.sort?]

theorem HasTypeVsQ.length {P B store Q C Γ Φ vs as}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as) : vs.length = as.length := by
  match h with
  | .nil => rfl
  | .cons _ hs => exact congrArg Nat.succ hs.length

theorem HasTypeVQ.data_observation {P B store Q C Γ Φ v a d ts}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hd : a.norm.core = .data d ts)
    {t : Term} (ht : v.toTerm? = some t) : Term.HasData P Γ t d ts := by
  match h with
  | .V_Var hi ho => cases ht; exact .var hi hd
  | .V_Const (c := c) _ => cases c <;> cases hd
  | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ | .V_List _ _ _ _ => first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd
  | .V_Con hc hn _ _ hv _ =>
    simp only [Ty.norm, Ty.core, Ty.data.injEq] at hd
    obtain ⟨rfl, rfl⟩ := hd
    cases ht
    exact .value hc rfl (by simpa only [Ty.normTys_eq_map, List.length_map] using hn.symm)
      (by simpa only [Val.toTermSlots_length, List.length_map] using hv.length)
  | .V_Super _ _ _ _ => first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd
  | .V_Raise .. | .V_LocRef _ _ | .V_LocLazy _ _ | .V_Bytes _ => first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ => first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd
  | .V_Map _ _ _ _ _ _ | .V_Set _ _ _ | .V_Dict _ _ _ _ _ _ _ _ => first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd
  | .V_PathBases _ | .V_ScopePattern _ _ _ | .V_Checked _ _ _ |
      .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ => first | exact False.elim (Ty.notDataCore_dependentFn hd) | cases hd
  | .V_AtError hs =>
    rw [hs.errorType_eq] at hd
    simp only [atErrorType, Ty.norm, Ty.core, Ty.normTys] at hd
    cases hd
    cases ht
    exact hs.error_data
  | .V_Normal hv => exact hv.data_observation (by simpa only [Ty.norm_idem] using hd) ht
  | .V_Sub hv hl _ _ _ =>
    obtain ⟨us, hu, hs⟩ := hl.dataCore_source hd
    exact .widen (hv.data_observation hu ht) (DataObservationLe.of_args hs)
  | .V_Refine hv _ _ _ _ _ _ _ => exact hv.data_observation (by simpa only [Ty.refined_norm_core] using hd) ht

mutual
  theorem HasTypeVQ.observation_declared {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) {t : Term} (ht : v.toTerm? = some t) :
      Term.Declared P C Γ t := by
    match h with
    | .V_Var hi ho => cases ht; exact ⟨_, hi, ho⟩
    | .V_Const (c := c) _ => cases c <;> cases ht <;> trivial
    | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ => cases ht
    | .V_List hv _ _ _ => cases ht; exact HasTypeEachQ.observation_declared hv
    | .V_Con hc _ _ _ hv _ =>
      cases ht
      exact ⟨HasTypeVsQ.observation_declared hv, _, hc,
        by simpa only [Val.toTermSlots_length, List.length_map] using hv.length⟩
    | .V_Super _ _ _ _ => cases ht
    | .V_Raise .. | .V_LocRef _ _ | .V_LocLazy _ _ => cases ht
    | .V_Bytes _ => cases ht; trivial
    | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Dict _ _ _ _ _ _ _ _ | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ => cases ht
    | .V_Map hk hv _ _ _ _ => cases ht; exact ⟨HasTypeEachQ.observation_declared hk, HasTypeEachQ.observation_declared hv⟩
    | .V_Set hv _ _ => cases ht; exact HasTypeEachQ.observation_declared hv
    | .V_PathBases _ | .V_ScopePattern _ _ _ => cases ht
    | .V_Checked _ _ _ | .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ => cases ht; trivial
    | .V_AtError hs => cases ht; exact hs.error_observation_declared
    | .V_Normal hv => exact hv.observation_declared ht
    | .V_Sub hv _ _ _ _ => exact hv.observation_declared ht
    | .V_Refine hv _ _ _ _ _ _ _ => exact hv.observation_declared ht
  theorem HasTypeVsQ.observation_declared {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) : declaredSlots P C Γ (Val.toTermSlots vs) := by
    match h with
    | .nil => trivial
    | .cons hv hs =>
      refine ⟨?_, HasTypeVsQ.observation_declared hs⟩
      cases he : Val.toTerm? _ with
      | none => trivial
      | some t => exact hv.observation_declared he
  theorem HasTypeEachQ.observation_declared {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) :
      declaredSlots P C Γ (Val.toTermSlots vs) := by
    match h with
    | .nil => trivial
    | .cons hv hs =>
      refine ⟨?_, HasTypeEachQ.observation_declared hs⟩
      cases he : Val.toTerm? _ with
      | none => trivial
      | some t => exact hv.observation_declared he
end


mutual
  theorem HasTypeVQ.observation_references {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) {t : Term} (ht : v.toTerm? = some t) :
      t.References Γ := by
    match h with
    | .V_Var hg ho => cases ht; exact ⟨_, hg, ho⟩
    | .V_Const (c := c) _ => cases c <;> cases ht <;> trivial
    | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ => cases ht
    | .V_List hv _ _ _ => cases ht; exact HasTypeEachQ.observation_references hv
    | .V_Con _ _ _ _ hv _ => cases ht; exact HasTypeVsQ.observation_references hv
    | .V_Super _ _ _ _ => cases ht
    | .V_Raise .. | .V_LocRef _ _ | .V_LocLazy _ _ => cases ht
    | .V_Bytes _ => cases ht; trivial
    | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Dict _ _ _ _ _ _ _ _ | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ => cases ht
    | .V_Map hk hv _ _ _ _ => cases ht; exact ⟨HasTypeEachQ.observation_references hk, HasTypeEachQ.observation_references hv⟩
    | .V_Set hv _ _ => cases ht; exact HasTypeEachQ.observation_references hv
    | .V_PathBases _ | .V_ScopePattern _ _ _ => cases ht
    | .V_Checked _ _ _ | .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ => cases ht; trivial
    | .V_AtError _ => cases ht; simp [Term.References, Term.VarsIn, varsInSlots, varsInSlot, AtError.textFields, List.map]
    | .V_Normal hv => exact hv.observation_references ht
    | .V_Sub hv _ _ _ _ => exact hv.observation_references ht
    | .V_Refine hv _ _ _ _ _ _ _ => exact hv.observation_references ht
  theorem HasTypeVsQ.observation_references {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) : varsInSlots Γ.Readable (Val.toTermSlots vs) := by
    match h with
    | .nil => trivial
    | .cons hv hs =>
      refine ⟨?_, HasTypeVsQ.observation_references hs⟩
      cases he : Val.toTerm? _ with
      | none => trivial
      | some t => exact hv.observation_references he
  theorem HasTypeEachQ.observation_references {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) :
      varsInSlots Γ.Readable (Val.toTermSlots vs) := by
    match h with
    | .nil => trivial
    | .cons hv hs =>
      refine ⟨?_, HasTypeEachQ.observation_references hs⟩
      cases he : Val.toTerm? _ with
      | none => trivial
      | some t => exact hv.observation_references he
end

private theorem const_observation {B c sort} (h : ConstOK B c) (hi : (Const.type c).HasSort sort) :
    ∃ t, (Val.const c).toTerm? = some t ∧ t.HasSort Γ sort := by
  cases c <;> simp_all [Const.type, Ty.HasSort, Ty.sort?, Val.toTerm?,
    Term.HasSort, Term.Shape, Term.References, Term.VarsIn]

theorem HasTypeVQ.observation {P B store Q C Γ Φ v a sort}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.HasSort sort) :
    ∃ t, v.toTerm? = some t ∧ t.HasSort Γ sort := by
  match h with
  | .V_Var hg ho => exact ⟨_, rfl, ⟨a, hg, ho⟩, a, hg, hi⟩
  | .V_Const hc => exact const_observation hc hi
  | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ => cases hi
  | .V_List hv _ _ _ =>
    have hs : sort = .list := (Option.some.inj hi).symm
    exact ⟨_, rfl, HasTypeEachQ.observation_references hv, hs⟩
  | .V_Con _ _ _ _ hv _ => exact ⟨_, rfl, HasTypeVsQ.observation_references hv, (Option.some.inj hi).symm⟩
  | .V_Super _ _ _ _ => cases hi
  | .V_Raise .. | .V_LocRef _ _ | .V_LocLazy _ _ => cases hi
  | .V_Bytes _ => exact ⟨_, rfl, trivial, (Option.some.inj hi).symm⟩
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Dict _ _ _ _ _ _ _ _ | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ => cases hi
  | .V_Map hk hv _ _ _ _ => exact ⟨_, rfl, ⟨HasTypeEachQ.observation_references hk, HasTypeEachQ.observation_references hv⟩, (Option.some.inj hi).symm⟩
  | .V_Set hv _ _ => exact ⟨_, rfl, HasTypeEachQ.observation_references hv, (Option.some.inj hi).symm⟩
  | .V_PathBases _ | .V_ScopePattern _ _ _ => cases hi
  | .V_Checked _ _ hm =>
    exact ⟨_, rfl, trivial, by simpa [Term.Shape, hm.1] using (Option.some.inj hi).symm⟩
  | .V_CheckedRequest _ _ _ _ _ hm =>
    exact ⟨_, rfl, trivial, by simpa [Term.Shape, hm.1] using (Option.some.inj hi).symm⟩
  | .V_CheckedAt (target := target) (k := k) (snapshot := snapshot) (range := range) hw =>
    have hk : target.kind = k := by
      cases hw with
      | plain _ _ ht _ => exact ht
      | request _ _ _ _ _ hm => cases snapshot <;> cases range <;> simp_all [SnapshotMem, RangeExpr.Mem, Scope.Domain.Range.MemK]
    exact ⟨_, rfl, trivial, by simpa [Term.Shape, hk] using (Option.some.inj hi).symm⟩
  | .V_AtError hs =>
    rw [hs.errorType_eq] at hi
    exact ⟨_, rfl, by simp [Term.References, Term.VarsIn, varsInSlots, varsInSlot, AtError.textFields, List.map], (Option.some.inj hi).symm⟩
  | .V_Normal hv => exact hv.observation ((Ty.hasSort_norm _ _).mp hi)
  | .V_Sub hv hl _ _ _ => exact hv.observation (hl.hasSort_source hi)
  | .V_Refine hv _ _ _ _ _ _ _ => exact hv.observation hi

theorem HasTypeVQ.integer_observation {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.IntegerCarrier) :
    ∃ t, v.toTerm? = some t ∧ termSorted Γ t := h.observation hi

theorem HasTypeVQ.toTerm_of_integerCarrier {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.IntegerCarrier) :
    ∃ t, v.toTerm? = some t := by
  obtain ⟨t, ht, _⟩ := h.observation hi
  exact ⟨t, ht⟩

@[simp] theorem Pred.open_lift (p : Pred) (t : Term) : p.lift.open t = p := by
  simp only [Pred.open, Pred.lift, predBind_comp]
  exact predBind_id p

theorem HasTypeVQ.assume {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) :
    ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.open (v.toTerm?.getD (.integer 0))) := by
  match h with
  | .V_Var hg _ =>
    intro p hp
    exact .hyp (List.mem_append_left _ (Ctx.mem_facts.mpr ⟨_, _, p, hg, hp, rfl⟩))
  | .V_Const (c := c) _ =>
    cases c <;> simp [Const.type, Ty.assume, Ty.refinementPredicates]
  | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ | .V_List _ _ _ _ => intro p hp; cases hp
  | .V_Con _ _ _ _ _ _ | .V_Super _ _ _ _ | .V_Raise .. | .V_LocRef _ _ | .V_LocLazy _ _ | .V_Bytes _ => intro p hp; cases hp
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Dict _ _ _ _ _ _ _ _
  | .V_Map _ _ _ _ _ _ | .V_Set _ _ _
  | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ => intro p hp; cases hp
  | .V_PathBases _ | .V_ScopePattern _ _ _ | .V_Checked _ _ _ |
      .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ => intro p hp; cases hp
  | .V_AtError hs => rw [hs.errorType_eq]; intro p hp; cases hp
  | .V_Normal hv =>
    simpa only [Ty.assume_norm] using hv.assume
  | .V_Sub hv hl _ _ _ =>
    intro p hp
    apply ((hl.assume p hp).bind (fun i => match i with
      | 0 => some (v.toTerm?.getD (.integer 0)) | j+1 => some (.var j))).cut
    intro q hq
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
    rcases List.mem_append.mp hr with hr | hr
    · exact hv.assume r hr
    · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hr
      change Entails _ (s.lift.open _)
      rw [Pred.open_lift]
      exact .hyp hs
  | .V_Refine hv hsort ht _ _ he hda hdp =>
    intro p hp
    rw [Ty.assume_refined hsort.ordinary] at hp
    rcases List.mem_append.mp hp with hp | hp
    · exact hv.assume p hp
    · simp only [ht, Option.getD_some]
      apply Entails.conjuncts he
      rw [Pred.open, Pred.conjuncts_bind]
      exact List.mem_map.mpr ⟨p, hp, rfl⟩

theorem HasTypeVQ.assume_optional {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) :
    ∀ p ∈ a.assume, Entails (Γ.facts ++ Φ) (p.openOptional v.toTerm?) := by
  match h with
  | .V_Var hg _ =>
    intro p hp
    exact .hyp (List.mem_append_left _ (Ctx.mem_facts.mpr ⟨_, _, p, hg, hp, rfl⟩))
  | .V_Const (c := c) _ =>
    cases c <;> simp [Const.type, Ty.assume, Ty.refinementPredicates]
  | .V_DependentLam .. | .V_Closure .. | .V_Lam _ _ _ _ _ | .V_List _ _ _ _ => intro p hp; cases hp
  | .V_Con _ _ _ _ _ _ | .V_Super _ _ _ _ | .V_Raise .. | .V_LocRef _ _ | .V_LocLazy _ _ | .V_Bytes _ => intro p hp; cases hp
  | .V_Fun _ _ _ _ | .V_Prim _ _ _ _ _ | .V_Op _ _ _ _ | .V_Dict _ _ _ _ _ _ _ _
  | .V_Map _ _ _ _ _ _ | .V_Set _ _ _
  | .V_ExternalRef _ _ _ _ | .V_ExternalHandle _ _ _ _ _ _ _ => intro p hp; cases hp
  | .V_PathBases _ | .V_ScopePattern _ _ _ | .V_Checked _ _ _ |
      .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ => intro p hp; cases hp
  | .V_AtError hs => rw [hs.errorType_eq]; intro p hp; cases hp
  | .V_Normal hv =>
    simpa only [Ty.assume_norm] using hv.assume_optional
  | .V_Sub hv hl _ _ _ =>
    intro p hp
    apply ((hl.assume p hp).bind (fun i => match i with
      | 0 => v.toTerm? | j+1 => some (.var j))).cut
    intro q hq
    obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
    rcases List.mem_append.mp hr with hr | hr
    · exact hv.assume_optional r hr
    · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp hr
      change Entails _ (s.lift.openOptional _)
      simp only [Pred.openOptional, Pred.lift, predBind_comp] 
      change Entails _ (predBind (fun i => some (.var i)) s)
      rw [predBind_id]
      exact .hyp hs
  | .V_Refine hv hsort ht _ _ he hda hdp =>
    intro p hp
    rw [Ty.assume_refined hsort.ordinary] at hp
    rcases List.mem_append.mp hp with hp | hp
    · exact hv.assume_optional p hp
    · simp only [ht, Pred.openOptional_some]
      apply Entails.conjuncts he
      rw [Pred.open, Pred.conjuncts_bind]
      exact List.mem_map.mpr ⟨p, hp, rfl⟩

end Benitoite.Release.Refinement
