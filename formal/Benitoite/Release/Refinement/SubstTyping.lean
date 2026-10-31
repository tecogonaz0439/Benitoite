import Benitoite.Release.Refinement.TypingShift

/-!
# 型付きの値の相互置換

値の像から整数観測と有限の事実を先に導き、部分型の葉へ cut する。
-/
namespace Benitoite.Release.Refinement

def ClosedTy (P : Program) (B : Builtins) (store : StoreTy) (v : Val) (a : Ty) : Prop :=
  ∀ Q C Γ Φ, HasTypeVQ P B store Q C Γ Φ v a

/-- 通常値は置換後の型で検査し、継続場所の閉じた契約と R0 は保つ。 -/
def SubstOk (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx) (C : List TParam)
    (Γ : Ctx) (_Φ : List Pred) (Δ : Ctx) (Ξ : List Pred) (R0 : Option Ty) (σ : Nat → Val) : Prop :=
  ∀ i a, Γ[i]? = some (some a) →
    (a.Ordinary ∧ HasTypeVQ P B store Q C Δ Ξ (σ i) (substTyValues σ a)) ∨
    (∃ b t e l, a = .cont b t e ∧ a.WF 0 0 0 ∧ σ i = .loc l ∧
      store l = some (.cont b t e R0) ∧ ∀ r, R0 = some r → r.WF 0 0 0)

private def TypedImages (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx) (C : List TParam)
    (Γ Δ : Ctx) (Ξ : List Pred) (σ : Nat → Val) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → a.Ordinary →
    HasTypeVQ P B store Q C Δ Ξ (σ i) (substTyValues σ a)

private theorem SubstOk.images {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ) : TypedImages P B store Q C Γ Δ Ξ σ := by
  intro i a hi ho
  rcases h i a hi with h | ⟨b,t,e,l,he,_⟩
  · exact h.2
  · exact False.elim (ho b t e he)

private theorem TypedImages.values {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) :
    Term.ImagesSorted Γ Δ (valEnv σ).values := by
  intro i a sort hi ha
  exact (h i a hi ha.ordinary).observation (Ty.hasSort_bind ha (valEnv σ))

private theorem TypedImages.references {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) :
    Term.ImageReferences Γ Δ (valEnv σ).values := by
  intro i a hi ho t ht
  exact (h i a hi ho).observation_references ht

private theorem TypedImages.declaration {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) : DeclarationImages P C Γ Δ (valEnv σ).values := by
  constructor
  · intro i a hi ho t ht
    exact (h i a hi ho).observation_declared ht
  · intro i a d ts hi hd
    have hv := h i a hi (Ty.ordinary_of_dataCore hd)
    have hs := Ty.hasSort_bind (Ty.hasSort_of_dataCore hd) (valEnv σ)
    obtain ⟨t, ht, _⟩ := hv.observation hs
    have hh : (substTyValues σ a).norm.core = .data d (bindDataArgs (valEnv σ).values ts) := by
      simpa only [substTyValues, Ty.bind, valEnv, Ty.rawSubstV_eq_rawBind, Ty.norm_idem] using
        Ty.dataCore_substV hd (valEnv σ).values
    simpa only [termBind_var, valEnv, ht, Option.getD_some] using hv.data_observation hh ht

private theorem TypedImages.transport {P B store Q C Γ Δ Ξ σ Φ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
    Transport (valEnv σ) Γ Φ Δ Ξ := by
  refine ⟨h.values, h.references, (by intro i; simp [valEnv]), ?_⟩
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
    have ht := h i a hi (Ty.assume_ordinary hq)
    have he := ht.assume_optional (predBind (upValues (valEnv σ).values) q)
      (Ty.assume_bind a (valEnv σ) q hq)
    change Entails _ (predBind (valEnv σ).values (q.openOptional (some (.var i))))
    rw [predBind_open_optional]
    exact he
  · exact hf p hp

theorem SubstOk.observations {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ) :
    Term.ImagesSorted Γ Δ (valEnv σ).values := h.images.values

theorem SubstOk.references {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ) :
    Term.ImageReferences Γ Δ (valEnv σ).values := h.images.references

theorem SubstOk.declaration {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ) :
    DeclarationImages P C Γ Δ (valEnv σ).values := h.images.declaration

/-- Γ の事実は型付き像から導き、Φ の像の導出とは別に渡す。 -/
theorem SubstOk.transport {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
    Transport (valEnv σ) Γ Φ Δ Ξ := h.images.transport hf

theorem Ty.ordinary_bind_values (a : Ty) (σ : Nat → Val) :
    (substTyValues σ a).Ordinary ↔ a.Ordinary := by
  unfold substTyValues Ty.bind valEnv
  rw [← Ty.rawSubstV_eq_rawBind]
  cases a <;> simp [Ty.rawSubstV, Ty.norm, Ty.Ordinary]

theorem shiftIndex_zero (c : Nat) : shiftIndex 0 c = id := by
  funext i; simp [shiftIndex]

theorem shiftIndex_add (k : Nat) : shiftIndex k 0 = (fun i => i+k) := by
  funext i; simp [shiftIndex]

theorem Ty.shiftV_zero (a : Ty) (c : Nat) : a.shiftV 0 c = a := by
  rw [Ty.shiftV_eq_renameTy, shiftIndex_zero, renameTy_id]

theorem Eff.shiftV_zero (e : Eff) (c : Nat) : Eff.shiftV 0 c e = e := by
  rw [Eff.shiftV_eq_renameEff, shiftIndex_zero, renameEff_id]

theorem Pred.shiftV_zero (p : Pred) (c : Nat) : p.shiftV 0 c = p := by
  simp only [Pred.shiftV, shiftIndex_zero]
  exact predBind_id p

theorem Tel.shiftV_zero (t : Tel) (c : Nat) : Tel.shiftV 0 c t = t := by
  rw [Tel.shiftV_eq_rawBind, shiftIndex_zero]
  exact Tel.rawBind_id t

theorem HasTypeVQ.hide_context {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store)
    (store' : StoreTy) (hpres : store.PreservesNormals store') :
    HasTypeVQ P B store' Q C (hideConts Γ) Φ v a := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    constructor
    · simp [hideConts]
    · intro i a hi ho
      simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi,ho⟩
  have ht := h.shift_values (store' := store') hA hstore hpres hm (Ξ := Φ) (fun p hp => by
    rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using ht

theorem HasTypeTelArgsQ.hide_context {P B store Q C Γ Φ vs t a e}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
    (store' : StoreTy) (hpres : store.PreservesNormals store') :
    HasTypeTelArgsQ P B store' Q C (hideConts Γ) Φ vs t a e := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    constructor
    · simp [hideConts]
    · intro i a hi ho
      simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi,ho⟩
  have hh := h.shift_values hA hstore hpres hm (Ξ := Φ) (fun p hp => by
    rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.renameList_identity, Ty.shiftV_zero, Eff.shiftV_zero, Tel.shiftV_zero] using hh

theorem HasTypeVQ.weaken_empty {P B Q C Γ Φ v a store}
    (h : HasTypeVQ P B StoreTy.empty Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) : HasTypeVQ P B store Q C Γ Φ v a := by
  have hm : ShiftMap 0 0 Γ Γ := ⟨by omega, by
    intro i a hi _; simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hi⟩
  have hh := h.shift_values hA StoreTy.WF.empty (StoreTy.Extends.empty store).preservesNormals hm
    (Ξ := Φ) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using hh

theorem HasTypeCQ.weaken_empty {P B Q C Γ Φ R m a e L store}
    (h : HasTypeCQ P B StoreTy.empty Q C Γ Φ R m a e L) (hA : Builtins.ValueAssumptions P B) : HasTypeCQ P B store Q C Γ Φ R m a e L := by
  have hm : ShiftMap 0 0 Γ Γ := ⟨by omega, by
    intro i a hi _; simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hi⟩
  have hh := h.shift_values (L' := L) hA StoreTy.WF.empty (StoreTy.Extends.empty store) hm (.refl _)
    (Ξ := Φ) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Comp.rename_identity, Ty.shiftV_zero, Eff.shiftV_zero,
    Option.map_id, id_eq, show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hh

private theorem TypedImages.hide {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store)
    (store' : StoreTy) (hpres : store.PreservesNormals store') :
    TypedImages P B store' Q C (hideConts Γ) (hideConts Δ) Ξ σ := by
  intro i a hi ho
  exact (h i a (hideConts_lookup.mp hi).1 ho).hide_context hA hstore store' hpres

private theorem TypedImages.params {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store) (ps : List Ty) :
    TypedImages P B store Q C (bindParams Γ ps) (bindParams Δ (ps.map (substTyValues σ)))
      (liftMany ps.length Ξ) (upSubst ps.length σ) := by
  intro i a hi ho
  by_cases hil : i < ps.length
  · simp only [upSubst, hil, ↓reduceIte]
    rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi
    simp only [List.getElem?_map] at hi
    cases hu : ps.reverse[i]? with
    | none => simp [hu] at hi
    | some u =>
      simp only [hu, Option.map_some, Option.some.injEq] at hi
      cases hi
      rw [Ty.bind_shiftV_values]
      refine .V_Var ?_ ((Ty.ordinary_shiftV _ _ _).mpr
        ((Ty.ordinary_bind_values _ _).mpr ((Ty.ordinary_shiftV _ _ _).mp ho)))
      rw [bindParams, List.getElem?_append_left (by simpa using hil)]
      simp only [← List.map_reverse, List.getElem?_map, List.length_map, hu, Option.map_some]
  · rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi
    simp only [List.getElem?_map, List.length_map, List.length_reverse] at hi
    cases hu : Γ[i-ps.length]? with
    | none => simp [hu] at hi
    | some u => cases u with
      | none => simp [hu] at hi
      | some u =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        rw [Ty.bind_shiftV_values]
        have ht := (h _ u hu ((Ty.ordinary_shiftV _ _ _).mp ho)).shift_values
          (store' := store) hA hstore (.refl _) (ShiftMap.outer Δ (ps.map (substTyValues σ)))
          (Ξ := liftMany ps.length Ξ) (fun p hp => by
            simp only [List.length_map]
            exact .hyp (List.mem_append_right _ (by rw [liftMany_eq]; exact List.mem_map.mpr ⟨p,hp,rfl⟩)))
        simpa only [List.length_map, shiftIndex_add, upSubst, hil, ↓reduceIte] using ht

theorem predBind_upSubst_shift (p : Pred) (σ : Nat → Val) (k : Nat) :
    predBind (valEnv (upSubst k σ)).values (p.shiftV k 0) =
      (predBind (valEnv σ).values p).shiftV k 0 := by
  rw [valEnv_upSubst]
  simp only [SubstEnv.valuesOnly, Pred.shiftV, predBind_comp]
  congr 1
  funext i
  have hi : ¬ i+k < k := by omega
  simp [shiftIndex, termBind?, map_rename_eq_bind, upTerms, hi]

private theorem TypedImages.conditions_params {P B store Q C Γ Δ Ξ σ Φ}
    (_h : TypedImages P B store Q C Γ Δ Ξ σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) (ps : List Ty) :
    ∀ p ∈ liftMany ps.length Φ,
      Entails ((bindParams Δ (ps.map (substTyValues σ))).facts ++ liftMany ps.length Ξ)
        (predBind (valEnv (upSubst ps.length σ)).values p) := by
  intro p hp
  rw [liftMany_eq] at hp
  obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
  rw [predBind_upSubst_shift]
  simpa only [List.length_map] using (hf q hq).under_params (ps.map (substTyValues σ))

private theorem TypedImages.observation {P B store Q C Γ Δ Ξ σ} {v : Val} {t : Term} {sort : «Sort»}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ht : v.toTerm? = some t)
    (hs : t.HasSort Γ sort) (ρ : Nat → LocalRef) :
    (v.subst σ ρ).toTerm? = some (termBind (valEnv σ).values t) := by
  rw [Val.toTerm_subst_optional, ht, Option.bind_some]
  obtain ⟨u, hu, _⟩ := Term.hasSort_bind hs _ h.values h.references
  simp only [hu, termBind, Option.getD_some]

theorem SubstOk.observation {P B store Q C Γ Φ Δ Ξ R σ v a t sort}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hv : HasTypeVQ P B store Q C Γ Φ v a) (hi : a.HasSort sort)
    (ht : v.toTerm? = some t) (ρ : Nat → LocalRef) :
    (v.subst σ ρ).toTerm? = some (termBind (valEnv σ).values t) := by
  obtain ⟨u, hu, hs⟩ := hv.observation hi
  cases hu.symm.trans ht
  exact h.images.observation ht hs ρ

theorem Const.type_bind_values (con : Const) (σ : Nat → Val) :
    (Const.type con).bind (valEnv σ) = Const.type con := by
  cases con <;> rfl

@[simp] theorem substEffValues_empty (σ : Nat → Val) : substEffValues σ Eff.empty = Eff.empty := by
  simp only [substEffValues, Eff.bind, valEnv, Eff.empty, Eff.rawBind, instAtoms_nil,
    substAtoms_nil, rowFails, List.length_nil, List.range_zero, List.filter_nil,
    List.flatMap_nil, rawBindTys, List.append_nil, Eff.norm, Ty.normTys, Order.sortUnique]

private theorem TypedImages.wf {P B store Q C Γ Δ Ξ σ a}
    (h : TypedImages P B store Q C Γ Δ Ξ σ)
    (hw : Ty.WF 0 C.length Γ.length a) (hs : a.Sorted Γ) :
    (substTyValues σ a).WF 0 C.length Δ.length := by
  have ht := h.transport (Φ := []) (by simp)
  simpa only [substTyValues, valEnv_valuesOnly] using
    Ty.wf_bind_values hw hs.references (valEnv σ).values ht.imageWF

private theorem TypedImages.sorted {P B store Q C Γ Δ Ξ σ a}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hs : Ty.Sorted Γ a) :
    (substTyValues σ a).Sorted Δ := by
  have ht := h.transport (Φ := []) (by simp)
  simpa only [substTyValues, valEnv_valuesOnly] using
    Ty.sorted_bind_values hs (valEnv σ).values ht.values ht.references

private theorem TypedImages.annotation {P B store Q C Γ Δ Ξ σ a}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Δ (substTyValues σ a) :=
  ⟨h.wf ha.wf ha.sorted, h.sorted ha.sorted, ha.declared.bind_values h.declaration⟩

private theorem TypedImages.typeAnnotations {P B store Q C Γ Δ Ξ σ ts}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ht : TypeAnnotations P C Γ ts) :
    TypeAnnotations P C Δ (ts.map (substTyValues σ)) := by
  intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact h.annotation (ht x hx)

private theorem TypedImages.rowAnnotations {P B store Q C Γ Δ Ξ σ es}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ht : RowAnnotations P C Γ es) :
    RowAnnotations P C Δ (es.map (substEffValues σ)) := by
  intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha
  simpa only [substTyValues, Ty.bind_fn, List.map_nil, Ty.bind_base, substEffValues] using h.annotation (ht x hx)

private theorem TypedImages.signature {P B store Q C Γ Δ Ξ σ t ks ts es}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ht : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Δ t ks (ts.map (substTyValues σ)) (es.map (substEffValues σ)) := by
  refine ⟨ht.source, h.typeAnnotations ht.types, ht.kinds.subst σ, h.rowAnnotations ht.rows, ?_⟩
  have hh := h.annotation ht.result
  change Ty.Annotation P C Δ (((Ty.dependentFn t).subst ts es).substV (valEnv σ).values) at hh
  rw [Ty.substV_subst_closed_rows ht.source] at hh
  exact hh

private theorem TypedImages.admissible {P B store Q C Γ Δ Ξ σ tps ne Qs Qt ts es e}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B)
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : Admissible B C Γ.length tps ne Qs Qt ts es e) :
    Admissible B C Δ.length tps ne Qs Qt (ts.map (substTyValues σ)) (es.map (substEffValues σ)) e := by
  apply ha.map (substTyValues σ) (substEffValues σ)
  · exact ha.types.map _ (fun a hm p hp => hA.sat_values store Q C Γ Δ Ξ σ a p h (ht a hm) hp)
  · intro a hm; exact ⟨(h.annotation (ht a hm)).wf, (Ty.ordinary_bind_values _ _).mpr (ha.typeScope a hm).2⟩
  · intro e hm; exact ((h.rowAnnotations he) _ (List.mem_map.mpr ⟨e, hm, rfl⟩)).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hn => hn.subst_values σ) (fun i => by
      simp [substEffValues, Eff.row, Eff.bind, Eff.rawBind, rowFails, valEnv, rawBindTys,
        instAtoms_nil, substAtoms_nil, Eff.norm, Ty.normTys])

private theorem TypedImages.primitive {P B store Q C Γ Δ Ξ σ b sg ts es}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B)
    (hb : B.sig b = some sg) (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : PrimitiveAdmissible C Γ.length sg Q ts es) :
    PrimitiveAdmissible C Δ.length sg Q (ts.map (substTyValues σ)) (es.map (substEffValues σ)) := by
  apply ha.map (substTyValues σ) (substEffValues σ)
  · exact hA.admits_values b sg store Q C Γ Δ Ξ σ ts hb h ht ha.admits
  · intro a hm; exact ⟨(h.annotation (ht a hm)).wf, (Ty.ordinary_bind_values _ _).mpr (ha.typeScope a hm).2⟩
  · intro e hm; exact ((h.rowAnnotations he) _ (List.mem_map.mpr ⟨e, hm, rfl⟩)).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hn => hn.subst_values σ) (fun i => by
      simp [substEffValues, Eff.row, Eff.bind, Eff.rawBind, rowFails, valEnv, rawBindTys,
        instAtoms_nil, substAtoms_nil, Eff.norm, Ty.normTys])

@[simp] theorem Val.substList_length (vs : List Val) (ν : Nat → Val) (ρ : Nat → LocalRef) :
    (Val.substList ν vs ρ).length = vs.length := by
  induction vs <;> simp_all [Val.substList]

theorem Eff.bind_singleFail (a : Ty) (ν : Nat → Val) :
    Eff.bind (valEnv ν) (Eff.singleFail a) = Eff.singleFail (a.bind (valEnv ν)) := by
  simp [Eff.bind, Eff.singleFail, Eff.rawBind, rawBindTys, rowFails, valEnv,
    instAtoms_nil, substAtoms_nil, Ty.norm_rawBind, Ty.bind, Ty.norm_idem,
    Eff.norm, Ty.normTys]

private theorem TypedImages.methodRows {P B store Q C Γ Δ Ξ σ ms es}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (he : RowAnnotations P C Γ es)
    (ha : MethodRowsAdmissible C Γ.length Q ms es) :
    MethodRowsAdmissible C Δ.length Q ms (es.map (substEffValues σ)) :=
  ha.map _ (fun e hm => ((h.rowAnnotations he) _ (List.mem_map.mpr ⟨e, hm, rfl⟩)).wf.2.2.2.1)
    (ha.2.2.2.2.map _ (fun _ hn => hn.subst_values σ) (fun i => by
      simp [substEffValues, Eff.row, Eff.bind, Eff.rawBind, rowFails, valEnv, rawBindTys,
        instAtoms_nil, substAtoms_nil, Eff.norm, Ty.normTys]))

private theorem TypedImages.none {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store) :
    TypedImages P B store Q C Γ.extendNone Δ.extendNone (Ξ.map Pred.lift) (upSubst 1 σ) := by
  intro i a hi ho
  cases i with
  | zero => simp [Ctx.extendNone] at hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
    cases hu : Γ[i]? with
    | none => simp [hu] at hi
    | some u => cases u with
      | none => simp [hu] at hi
      | some u =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        rw [Ty.bind_shiftV_values]
        have ht := (h i u hu ((Ty.ordinary_shiftV _ _ _).mp ho)).shift_values
          (store' := store) hA hstore (.refl _) (ShiftMap.outerNone Δ) (Ξ := Ξ.map Pred.lift) (fun p hp => by
            change Entails _ p.lift
            exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))
        simpa only [upSubst, Nat.succ_lt_succ_iff, Nat.not_lt_zero, ↓reduceIte,
          Nat.add_one_sub_one, shiftIndex_add] using ht

theorem Eff.subst_values_empty (ν : Nat → Val) : substEffValues ν Eff.empty = Eff.empty := by
  simp [substEffValues, Eff.bind, Eff.rawBind, rowFails, valEnv, rawBindTys,
    Eff.norm, Eff.empty, Ty.normTys, substAtoms_nil, instAtoms_nil]

theorem Eff.subst_values_single (ν : Nat → Val) (l : EffName) :
    substEffValues ν (Eff.single l) = Eff.single l := by
  simp [substEffValues, Eff.bind, Eff.rawBind, rowFails, valEnv, rawBindTys,
    Eff.norm, Eff.single, Ty.normTys, substAtoms_nil, instAtoms_nil]

mutual
  private theorem subst_value {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) := by
    match h with
    | .V_Var hi ho => exact ht _ _ hi ho
    | .V_Const hc => rw [substTyValues, Const.type_bind_values]; exact .V_Const hc
    | .V_Lam (ps := ps) hn hw hs hb hd =>
      apply HasTypeVQ.subst_lam hw hs (ht.transport hf) hd ht.declaration
      have hb' := subst_comp (L' := []) hb hA hstore.hide (upLocalSubst ps.length ρ)
        ((ht.hide hA hstore (hideBuilders store) (StoreTy.preserves_hide _)).params hA hstore.hide ps) (.empty _ _ _ _)
        ((ht.hide hA hstore (hideBuilders store) (StoreTy.preserves_hide _)).conditions_params
          (fun p hp => (hf p hp).hideConts) ps)
      simpa only [Option.map_some, Ty.bind_shiftV_values, Eff.bind_shiftV_values, Option.map_none, localExtend] using hb'
    | .V_List he hw hs hd =>
      exact .V_List (subst_each he hA hstore ρ ht hf) (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .V_Fun hd hn ha hi =>
      have hh := HasTypeVQ.V_Fun (Ψ := store) (Φ := Ξ) hd hn (ht.admissible hA hi.types hi.rows ha) (ht.signature hi)
      simpa only [Val.subst, instantiatedTel_subst hi.source] using hh
    | .V_Prim hb hr hn ha hi =>
      have hh := HasTypeVQ.V_Prim (Ψ := store) (Φ := Ξ) hb hr hn (ht.primitive hA hb hi.types hi.rows ha) (ht.signature hi)
      simpa only [Val.subst, instantiatedTel_subst hi.source] using hh
    | .V_Op ho hn ha hi =>
      have hs := ha.map (substTyValues σ) (fun a hm p hp => hA.sat_values store Q C Γ Δ Ξ σ a p ht (hi.types a hm) hp)
      have hh := HasTypeVQ.V_Op (Q := Q) (Ψ := store) (Φ := Ξ) ho hn hs (ht.signature hi)
      simpa only [Val.subst, List.map_nil, instantiatedTel_subst hi.source] using hh
    | .V_ExternalRef hd hw ha hi =>
      have hh := HasTypeVQ.V_ExternalRef (Q := Q) (Ψ := store) (Φ := Ξ) hd hw
        (ha.map hw (substTyValues σ)) (ht.signature hi)
      simpa only [Val.subst, List.map_nil, instantiatedTel_subst hi.source] using hh
    | .V_ExternalHandle h td hd hc hr hn ha =>
      simpa only [Val.subst, substTyValues, Ty.bind_external, substTyValues_eq_bind] using
        HasTypeVQ.V_ExternalHandle (Ψ := store) (Φ := Ξ) h td hd hc hr
          (by simpa only [List.length_map] using hn)
          (by simpa only [substTyValues, Ty.bind_external, substTyValues_eq_bind] using ht.annotation ha)
    | .V_PathBases hs => exact .V_PathBases hs
    | .V_ScopePattern hw hc hk => exact .V_ScopePattern hw hc hk
    | .V_Checked hk hc hm => exact .V_Checked hk hc hm
    | .V_CheckedRequest hk hc hv hg ht hm => exact .V_CheckedRequest hk hc hv hg ht hm
    | .V_CheckedAt hw => exact .V_CheckedAt hw
    | .V_AtError hs =>
      simpa only [Val.subst, hs.errorType_eq, atErrorType, substTyValues, Ty.bind, Ty.rawBind, rawBindTys,
        Ty.norm, Ty.normTys] using
        (HasTypeVQ.V_AtError (Ψ := store) (Q := Q) (C := C) (Γ := Δ) (Φ := Ξ) hs)
    | .V_Map hk hv hn hs ha hb =>
      exact .V_Map (subst_each hk hA hstore ρ ht hf) (subst_each hv hA hstore ρ ht hf)
        (by simpa using hn) (hA.sat_values store Q C Γ Δ Ξ σ _ _ ht ha hs) (ht.annotation ha) (ht.annotation hb)
    | .V_Set hv hs ha =>
      exact .V_Set (subst_each hv hA hstore ρ ht hf) (hA.sat_values store Q C Γ Δ Ξ σ _ _ ht ha hs) (ht.annotation ha)
    | .V_Dict (id := id) (ts := ts) hi hs hts hk hw htarget hv ha =>
      have hv' := subst_values hv hA hstore ρ ht hf
      have he : (id.dictTys.map (Ty.subst ts [])).map (substTyValues σ) =
          id.dictTys.map (Ty.subst (ts.map (substTyValues σ)) []) := by
        rw [List.map_map]; exact List.map_congr_left (fun a ha => Ty.substV_subst_closed (hw a ha) ts (valEnv σ).values)
      rw [he] at hv'
      have hs' := hs.map (substTyValues σ) (fun a hm p hp => hA.sat_values store Q C Γ Δ Ξ σ a p ht (hts a hm) hp)
      have ha' := ht.annotation ha
      simp only [Ty.bind_dict, Ty.subst_values_closed htarget] at ha' ⊢
      simpa only [Val.subst] using HasTypeVQ.V_Dict hi hs' (ht.typeAnnotations hts) (hk.subst σ) hw htarget hv' ha'
    | .V_Raise (t := t) (e := e) ha =>
      have hh := ht.annotation ha
      simp only [Val.subst, substTyValues, Ty.bind_fn, Eff.bind_singleFail] at hh ⊢
      exact .V_Raise hh
    | .V_LocRef (a := a) hl hd =>
      have he := Ty.subst_values_of_wf_zero (hstore _ _ hl) σ
      change HasTypeVQ P B store Q C Δ Ξ (.loc _) (.reference (substTyValues σ a))
      rw [he]
      exact .V_LocRef hl (by simpa only [← substTyValues_eq_bind, he, valEnv_valuesOnly] using hd.bind_values ht.declaration)
    | .V_LocLazy (a := a) hl hd =>
      have he := Ty.subst_values_of_wf_zero (hstore _ _ hl) σ
      change HasTypeVQ P B store Q C Δ Ξ (.loc _) (.lazy (substTyValues σ a))
      rw [he]
      exact .V_LocLazy hl (by simpa only [← substTyValues_eq_bind, he, valEnv_valuesOnly] using hd.bind_values ht.declaration)
    | .V_Bytes hb => exact .V_Bytes hb
    | .V_Con (cd := cd) (ts := ts) hc hn hk hw hv ha =>
      have hh := subst_values hv hA hstore ρ ht hf
      have he : (cd.args.map (Ty.subst ts [])).map (substTyValues σ) =
          cd.args.map (Ty.subst (ts.map (substTyValues σ)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.substV_subst_closed (hw a ha) ts (valEnv σ).values)
      rw [he] at hh
      simp only [Val.subst, substTyValues, Ty.bind_data]
      exact .V_Con hc (by simpa only [List.length_map] using hn) (hk.subst σ) hw hh (by simpa only [substTyValues_eq_bind, substTyValues, Ty.bind_data] using ht.annotation ha)
    | .V_Super hv hc hmemb hd =>
      exact .V_Super (subst_value hv hA hstore ρ ht hf) hc hmemb (hd.bind_values ht.declaration)
    | .V_Sub hv hl hw hs hd =>
      exact .V_Sub (subst_value hv hA hstore ρ ht hf) (hl.bind (valEnv σ) (ht.transport hf))
        (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .V_Refine (a := a) (t := t) (p := p) hv hi hterm hs hw he hda hdp =>
      obtain ⟨u, hu, hus⟩ := hv.observation hi
      have hut : u = t := Option.some.inj (hu.symm.trans hterm)
      subst u
      have hs' := Pred.sorted_bind hs (valEnv σ).values (fun _ h => Ty.hasSort_bind h (valEnv σ))
        (fun h => Ty.ordinary_bind h (valEnv σ) (ht.transport hf).typeImages)
        (ht.transport hf).values (ht.transport hf).references
      refine .V_Refine (subst_value hv hA hstore ρ ht hf) (Ty.hasSort_bind hi (valEnv σ))
        (ht.observation hterm hus ρ) hs' (Pred.wf_of_sorted hs') ?_
        (hda.bind_values ht.declaration) (hdp.bind_values ht.declaration)
      obtain ⟨u, hu, _⟩ := Term.hasSort_bind hus _ ht.values ht.references
      have hsuccess : termBind? (valEnv σ).values t = some (termBind (valEnv σ).values t) := by
        simp only [termBind, hu, Option.getD_some]
      rw [← predBind_open_of_some _ p t _ hsuccess]
      exact (ht.transport hf).entails he
  private theorem subst_values {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeVsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (as.map (substTyValues σ)) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (subst_value hv hA hstore ρ ht hf) (subst_values hs hA hstore ρ ht hf)
  private theorem subst_each {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeEachQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (substTyValues σ a) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (subst_value hv hA hstore ρ ht hf) (subst_each hs hA hstore ρ ht hf)
  private theorem subst_comp {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ L'} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hL : LocalSubstOk store L σ ρ L')
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
        (substTyValues σ a) (substEffValues σ e) L' := by
    match h with
    | .C_BuilderLet (kind := kind) ha hk hb hd =>
      simp only [Comp.subst]
      refine .C_BuilderLet (by simpa only [BuilderKind.contents_subst] using ht.annotation ha)
        (by simpa only [BuilderKind.contents_subst, List.map_cons, List.map_nil] using hk.subst σ) ?_ (hd.bind_values ht.declaration)
      have hh := subst_comp (Ξ := Ξ.map Pred.lift) hb hA hstore (upLocalSubst 1 ρ)
        (ht.none hA hstore) (hL.extend hstore (some kind)) (fun p hp => by
          have hh := (ht.transport hf).extendNone.facts p (List.mem_append_right _ hp)
          simpa only [valEnv_upSubst_one] using hh)
      simpa only [Option.map_map, Option.map_some, Function.comp_def, Ty.bind_shiftV_values, Eff.bind_shiftV_values] using hh
    | .C_BuilderOp ha hk hr hv =>
      simp only [Comp.subst]
      rw [← BuilderOp.resultType_subst, substEffValues_empty]
      exact .C_BuilderOp (by simpa only [BuilderKind.contents_subst] using ht.annotation ha)
        (by simpa only [BuilderKind.contents_subst, List.map_cons, List.map_nil] using hk.subst σ)
        (hr.subst hstore hL)
        (by simpa only [BuilderOp.parameters_subst] using subst_values hv hA hstore ρ ht hf)
    | .C_Return hv => rw [substEffValues_empty]; exact .C_Return (subst_value hv hA hstore ρ ht hf)
    | .C_App hv hs =>
      have hv' := subst_value hv hA hstore ρ ht hf
      rw [substTyValues, Ty.bind_fn] at hv'
      exact .C_App hv' (subst_values hs hA hstore ρ ht hf)
    | .C_If hv hm hn =>
      exact .C_If (subst_value hv hA hstore ρ ht hf) (subst_comp hm hA hstore ρ ht hL hf) (subst_comp hn hA hstore ρ ht hL hf)
    | .C_Lazy hb ha =>
      rw [substEffValues_empty]
      refine .C_Lazy ?_ (ht.annotation ha)
      have hh := subst_comp (L' := []) hb hA hstore.hide ρ
        (ht.hide hA hstore (hideBuilders store) (StoreTy.preserves_hide _)) (.empty _ _ _ _) (fun p hp => (hf p hp).hideConts)
      simpa only [substEffValues_empty, Option.map_none, substTyValues, Ty.bind] using hh
    | .C_Escape hv ha => exact .C_Escape (subst_value hv hA hstore ρ ht hf) (ht.annotation ha)
    | .C_Use hv hr hb he =>
      refine .C_Use (subst_value hv hA hstore ρ ht hf) hr (subst_comp hb hA hstore ρ ht hL hf) ?_
      cases e
      simpa only [substEffValues, Eff.bind, Eff.norm, Eff.rawBind, valEnv,
        instAtoms_nil, substAtoms_nil, Eff.test, Eff.atoms] using he
    | .C_Meth (ms := ms) (ss := ss) (τ := τ) (es := es) (ws := ws) hv hc hmeth hn hs hi hr hargs hvs ha =>
      have hs' := hs.map (substTyValues σ) (fun a hm' p hp =>
        hA.sat_values store Q C Γ Δ Ξ σ a p ht (hi.types a (List.mem_append_left _ hm')) hp)
      have hargs' := Tel.arguments_subst (instantiatedTel ms.tel (ss ++ [τ]) es) ws σ ρ
      rw [instantiatedTel_subst_eq hi.source, hargs, Option.map_some] at hargs'
      simp only [List.map_append, List.map_cons, List.map_nil] at hargs'
      exact .C_Meth (subst_value hv hA hstore ρ ht hf) hc hmeth hn hs'
        (by simpa only [List.map_append, List.map_cons, List.map_nil, substTyValues, Ty.bind] using ht.signature hi)
        (ht.methodRows hi.rows hr) hargs' (subst_values hvs hA hstore ρ ht hf) (ht.annotation ha)
    | .C_External (ts := ts) hd hw ha hargs =>
      have hh := subst_telArgs hargs hA hstore ρ ht hf
      have he := instantiatedTel_subst_eq hw.annotation.wf ts [] σ
      simp only [List.map_nil] at he
      change Tel.bind (valEnv σ) (Tel.bind (typeEnv ts) _) = _ at he
      rw [he] at hh
      exact .C_External hd hw (ha.map hw _) hh
    | .C_IssuePathBases b sg hb hk ho hp hr he =>
      rw [Eff.subst_values_single]
      exact .C_IssuePathBases b sg hb hk ho hp hr he
    | .C_CheckAt (bases := bases) hc =>
      have hh := subst_at_call hc hA hstore ρ ht hf
      rw [Eff.subst_values_empty]
      cases bases <;> simpa [Comp.subst, substTyValues, Ty.bind, Ty.rawBind, rawBindTys,
        Ty.norm, Ty.normTys, valEnv, RangeIx.inst_nil] using
        (HasTypeCQ.C_CheckAt (R := R.map (substTyValues σ)) (Δ := L') hh)
    | .C_Sub hm hl hc hw hs hd =>
      exact .C_Sub (subst_comp hm hA hstore ρ ht hL hf) (hl.bind (valEnv σ) (ht.transport hf))
        (hc.bind (valEnv σ)) (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .C_Eff hm hc => exact .C_Eff (subst_comp hm hA hstore ρ ht hL hf) (hc.bind (valEnv σ))
    | .C_Let (a := x) hm hb hd =>
      refine .C_Let (subst_comp hm hA hstore ρ ht hL hf) ?_ (hd.bind_values ht.declaration)
      have hb' := subst_comp hb hA hstore (upLocalSubst 1 ρ) (ht.params hA hstore [x]) (hL.extend hstore none) (ht.conditions_params hf [x])
      simpa only [List.length_cons, List.length_nil, Nat.zero_add, List.map_cons, List.map_nil,
        bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.nil_append,
        List.cons_append, liftMany_one, Option.map_map, Function.comp_def,
        Ty.bind_shiftV_values, Eff.bind_shiftV_values, Option.map_none, localExtend] using hb'
  private theorem subst_telArgs {P B store Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeTelArgsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (Tel.bind (valEnv σ) t)
        (substTyValues σ a) (substEffValues σ e) := by
    match h with
    | .done ha => exact .done (ht.annotation ha)
    | .param (rest := rest) (v := v) (vs := vs) ha hv hs =>
      apply HasTypeTelArgsQ.param (ht.annotation ha) (subst_value hv hA hstore ρ ht hf)
      change HasTypeTelArgsQ P B store Q C Δ Ξ (Val.substList σ vs ρ)
        (Tel.bind (Tel.argumentsEnv (v.subst σ ρ)) (Tel.bind (valEnv σ).up rest)) _ _
      rw [← valEnv_upSubst_one, Tel.open_subst]
      exact subst_telArgs hs hA hstore ρ ht hf

  private theorem subst_at_call {P B store Q C Γ Φ kind name shape bases pattern input index}
      (h : AtCallAdmissible P B store Q C Γ Φ kind name shape bases pattern input index)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      AtCallAdmissible P B store Q C Δ Ξ kind name
        {shape with errorType := substTyValues σ shape.errorType}
        (match bases with | none => none | some b => some (b.subst σ ρ))
        (pattern.subst σ ρ) (input.subst σ ρ) index := by
    match h with
    | .mk hs hk hb hp hty hv hw hi =>
      have hb' := fun b (he : bases = some b) => subst_value (hb b he) hA hstore ρ ht hf
      have he : {shape with errorType := substTyValues σ shape.errorType} = shape := by
        have hx : substTyValues σ shape.errorType = shape.errorType := by
          rw [hs.errorType_eq]; rfl
        simp only [hx]
      rw [he]
      refine .mk hs hk ?_ (subst_value hp hA hstore ρ ht hf) ?_
        (subst_value hv hA hstore ρ ht hf) hw hi
      · intro v he
        cases bases with
        | none => cases he
        | some b => cases he; exact hb' b rfl
      · rcases hty with ⟨rfl, hy⟩ | hy
        · exact Or.inl ⟨rfl, hy⟩
        · exact Or.inr ⟨by rw [Ty.subst_values_of_wf_zero hy.2]; exact hy.1,
            by rw [Ty.subst_values_of_wf_zero hy.2]; exact hy.2⟩

end

theorem HasTypeVQ.subst {P B store Q C Γ Φ v a Δ Ξ R σ}
    (h : HasTypeVQ P B store Q C Γ Φ v a)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) :=
  subst_value h hA hstore ρ ht.images hf

theorem HasTypeVsQ.subst {P B store Q C Γ Φ vs as Δ Ξ R σ}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (as.map (substTyValues σ)) :=
  subst_values h hA hstore ρ ht.images hf

theorem HasTypeEachQ.subst {P B store Q C Γ Φ vs a Δ Ξ R σ}
    (h : HasTypeEachQ P B store Q C Γ Φ vs a)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeEachQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (substTyValues σ a) :=
  subst_each h hA hstore ρ ht.images hf

theorem HasTypeCQ.subst {P B store Q C Γ Φ R m a e L L' Δ Ξ R0 σ}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L σ ρ L') :
    HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
      (substTyValues σ a) (substEffValues σ e) L' := subst_comp h hA hstore ρ ht.images hL hf

theorem HasTypeTelArgsQ.subst {P B store Q C Γ Φ vs t a e Δ Ξ R0 σ}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeTelArgsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (Tel.bind (valEnv σ) t)
      (substTyValues σ a) (substEffValues σ e) :=
  subst_telArgs h hA hstore ρ ht.images hf

/-- None の束縛では新しい像や事実を仮定せず、親の移送を extendNone する。 -/
theorem SubstOk.transport_extendNone {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
    Transport (valEnv (upSubst 1 σ)) Γ.extendNone (Φ.map Pred.lift)
      Δ.extendNone (Ξ.map Pred.lift) := by
  rw [valEnv_upSubst_one]
  exact (h.transport hf).extendNone

theorem HasTypeVQ.subst_under_none {P B store Q C Γ Φ v a Δ Ξ R σ}
    (h : HasTypeVQ P B store Q C Γ.extendNone (Φ.map Pred.lift) v a)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (v.subst (upSubst 1 σ) (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) :=
  subst_value h hA hstore _ (ht.images.none hA hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeVsQ.subst_under_none {P B store Q C Γ Φ vs as Δ Ξ R σ}
    (h : HasTypeVsQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs as)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVsQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (as.map (substTyValues (upSubst 1 σ))) :=
  subst_values h hA hstore _ (ht.images.none hA hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeEachQ.subst_under_none {P B store Q C Γ Φ vs a Δ Ξ R σ}
    (h : HasTypeEachQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs a)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeEachQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) :=
  subst_each h hA hstore _ (ht.images.none hA hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeCQ.subst_under_none {P B store Q C Γ Φ R m a e L L' Δ Ξ R0 σ}
    (h : HasTypeCQ P B store Q C Γ.extendNone (Φ.map Pred.lift) R m a e L)
    (hA : Builtins.ValueAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L (upSubst 1 σ) (upLocalSubst 1 ρ) L') :
    HasTypeCQ P B store Q C Δ.extendNone (Ξ.map Pred.lift) (R.map (substTyValues (upSubst 1 σ)))
      (m.subst (upSubst 1 σ) (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) a) (substEffValues (upSubst 1 σ) e) L' :=
  subst_comp h hA hstore _ (ht.images.none hA hstore) hL (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeTelArgsQ.subst_under_none {P B store Q C Γ Φ vs t a e Δ Ξ R0 σ}
    (h : HasTypeTelArgsQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeTelArgsQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (Tel.bind (valEnv (upSubst 1 σ)) t)
      (substTyValues (upSubst 1 σ) a) (substEffValues (upSubst 1 σ) e) :=
  subst_telArgs h hA hstore _ (ht.images.none hA hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

end Benitoite.Release.Refinement
