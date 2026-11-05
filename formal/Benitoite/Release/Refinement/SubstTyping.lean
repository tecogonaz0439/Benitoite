import Benitoite.Release.Refinement.TypingStore
import Benitoite.Release.Refinement.TypeShiftTyping
import Benitoite.Release.Refinement.TypeShiftSyntax
import Benitoite.Release.Refinement.TypingShift
import Benitoite.Release.Refinement.ValueRenameAlgebra
import Benitoite.Release.Refinement.PatternTransport

/-!
# 型付きの値の相互置換

値の像から整数観測と有限の事実を先に導き、部分型の葉へ cut する。
-/
namespace Benitoite.Release.Refinement
set_option maxHeartbeats 1600000

def ClosedTy (P : Program) (B : Builtins) (store : StoreTy) (v : Val) (a : Ty) : Prop :=
  ∀ Q C Γ Φ, HasTypeVQ P B store Q C Γ Φ v a

private def TypedImages (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx) (C : TypeCtx)
    (Γ Δ : Ctx) (Ξ : List Pred) (σ : Nat → Val) : Prop :=
  ∀ i a, Γ[i]? = some (some a) → a.Ordinary →
    HasTypeVQ P B store Q C Δ Ξ (σ i) (substTyValues σ a)

private theorem SubstOk.images {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ) : TypedImages P B store Q C Γ Δ Ξ σ := by
  intro i a hi ho
  cases h i a hi with
  | ordinary _ hv => exact hv
  | hidden hn _ => exact False.elim (hn ho)
  | contLoc he _ _ _ _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))
  | contVar he _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))

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
      (Ty.assume_bind a (valEnv σ) (by intro i; simp [valEnv, Ordinary, Ty.core]) q hq)
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

private theorem TypedImages.telAnnotation {P B store Q C Γ Δ Ξ σ t}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ha : Ty.Annotation P C Γ (.dependentFn t)) :
    Ty.Annotation P C Δ (.dependentFn (Tel.bind (valEnv σ) t)) := by
  have htr := h.transport (Φ := []) (by simp)
  refine ⟨?_, ?_, ?_⟩
  · simpa only [Ty.WF, valEnv_valuesOnly] using
      Tel.wf_bind_values (t := t) ha.wf ha.sorted.references (valEnv σ).values htr.imageWF
  · simpa only [Ty.Sorted, valEnv_valuesOnly] using
      Tel.sorted_bind_values (t := t) ha.sorted (valEnv σ).values htr.values htr.references
  · simpa only [Ty.Declared, valEnv_valuesOnly] using
      Tel.Declared.bind_values (t := t) ha.declared h.declaration

@[simp] theorem substTyValues_norm_source (a : Ty) (ν : Nat → Val) :
    substTyValues ν a.norm = substTyValues ν a := Ty.norm_rawBind _ a

@[simp] theorem substEffValues_norm_source (e : Eff) (ν : Nat → Val) :
    substEffValues ν e.norm = substEffValues ν e := by
  exact Eff.norm_rawBind (valEnv ν) e

@[simp] theorem substTyValues_normal (a : Ty) (ν : Nat → Val) :
    (substTyValues ν a).norm = substTyValues ν a := Ty.norm_idem _

private theorem substReturn_norm (R : Option Ty) (σ : Nat → Val) :
    (R.map Ty.norm).map (substTyValues σ) = (R.map (substTyValues σ)).map Ty.norm := by
  cases R <;> simp only [Option.map_none, Option.map_some, substTyValues_norm_source, substTyValues_normal]

private theorem substReturn_closed {R : Option Ty} (σ : Nat → Val)
    (hw : ∀ a, R = some a → a.WF 0 0 0) :
    (R.map (substTyValues σ)).map Ty.norm = R.map Ty.norm := by
  cases he : R with
  | none => rfl
  | some a => simp only [Option.map_some, Ty.subst_values_of_wf_zero (hw a he), Ty.norm_idem]

private theorem TypedImages.closedDeclared {P B store Q C Γ Δ Ξ σ a}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hc : a.WF 0 0 0)
    (ha : Ty.Declared P C Γ a) : Ty.Declared P C Δ a := by
  have hh := ha.rawSubstV h.declaration
  rwa [Ty.rawSubstV_of_wf_zero hc] at hh

private theorem TypedImages.closedAnnotation {P B store Q C Γ Δ Ξ σ a}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hc : a.WF 0 0 0)
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Δ a := by
  refine ⟨hc.weaken (by omega) (by omega), ?_, h.closedDeclared hc ha.declared⟩
  have hh := Ty.sorted_rawSubstV ha.sorted (valEnv σ).values h.values h.references
  rwa [Ty.rawSubstV_of_wf_zero hc] at hh

private theorem TypedImages.signature {P B store Q C Γ Δ Ξ σ t ks ts es}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ht : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Δ t ks (ts.map (substTyValues σ)) (es.map (substEffValues σ)) := by
  refine ⟨ht.source, h.typeAnnotations ht.types, ht.kinds.subst σ, h.rowAnnotations ht.rows, ?_, ?_⟩
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    have hk : Ty.HasKind P (TypeCtx.kinds C) (.fn [] [] (.base .unit) f) .value :=
      ⟨by simp [NamesWF], trivial, trivial, ht.rowKinds f hf⟩
    exact (hk.bind_values σ).2.2.2
  · rw [← instantiatedTel_subst_eq ht.source]
    exact h.telAnnotation ht.result

private theorem TypedImages.sat_normal {P B store Q C Γ Δ Ξ σ a p}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B)
    (ha : Ty.Annotation P C Γ a) (hs : B.sat (TypeCtx.constraints C) a.norm p) :
    B.sat (TypeCtx.constraints C) (substTyValues σ a).norm p := by
  have hh := hA.sat_values store Q C Γ Δ Ξ σ a.norm p h ha.norm hs
  simpa only [substTyValues, Ty.bind, Ty.norm_rawBind, Ty.norm_idem] using hh

private theorem TypedImages.admits_normal {P B store Q C Γ Δ Ξ σ b sg ts}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B)
    (hl : B.sig b = some sg) (ha : TypeAnnotations P C Γ ts)
    (hs : sg.admits (TypeCtx.constraints C) (Ty.normTys ts)) : sg.admits (TypeCtx.constraints C) (Ty.normTys (ts.map (substTyValues σ))) := by
  have he : (Ty.normTys ts).map (substTyValues σ) = Ty.normTys (ts.map (substTyValues σ)) := by
    simp only [Ty.normTys_eq_map, List.map_map, Function.comp_def]
    apply List.map_congr_left
    intro a ha
    simp only [substTyValues, Ty.bind, Ty.norm_rawBind, Ty.norm_idem]
  simpa only [he] using hA.admits_values b sg store Q C Γ Δ Ξ σ (Ty.normTys ts) hl h ha.norm hs

private theorem TypedImages.admissible {P B store Q C Γ Δ Ξ σ tps ne Qs Qt ts es e}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (hA : Builtins.ValueAssumptions P B)
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : Admissible B C Γ.length tps ne Qs Qt ts es e) :
    Admissible B C Δ.length tps ne Qs Qt (ts.map (substTyValues σ)) (es.map (substEffValues σ)) e := by
  apply ha.map (substTyValues σ) (substEffValues σ)
  · exact ha.types.map _ (fun a hm p hp => h.sat_normal hA (ht a hm) hp)
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
  · exact h.admits_normal hA hb ht ha.admits
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

theorem substEffValues_singleFail (a : Ty) (ν : Nat → Val) :
    substEffValues ν (Eff.singleFail a)=Eff.singleFail (substTyValues ν a) := Eff.bind_singleFail a ν

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

/-- 値のない位置も一つの番号として残す。 -/
def Ctx.extendOption (Γ : Ctx) : Option Ty → Ctx
  | none => Γ.extendNone
  | some a => Γ.extend a

@[simp] theorem Ctx.extendOption_length (Γ : Ctx) (x : Option Ty) :
    (Γ.extendOption x).length = Γ.length + 1 := by
  cases x <;> simp [Ctx.extendOption, Ctx.extend, Ctx.extendNone]

theorem ShiftMap.outerOption (Γ : Ctx) (x : Option Ty) :
    ShiftMap 1 0 Γ (Γ.extendOption x) := by
  cases x with
  | none => exact .outerNone Γ
  | some a => simpa [Ctx.extendOption, bindParams, Ctx.extend] using ShiftMap.outer Γ [a]

theorem SubstOk.hide {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) {Ψ'}
    (hp : Ψ.PreservesNormals Ψ') (R1 : Option Ty) :
    SubstOk P B Ψ' Q C (hideConts Γ) Φ (hideConts Δ) Ξ R1 ν := by
  intro i a hi
  obtain ⟨hi,ho⟩ := hideConts_lookup.mp hi
  cases h i a hi with
  | ordinary _ hv => exact .ordinary ho (hv.hide_context hA hw Ψ' hp)
  | hidden hn _ => exact False.elim (hn ho)
  | contLoc he _ _ _ _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))
  | contVar he _ _ => exact False.elim (ho _ _ _ (by rw [he]; rfl))

/-- 一つ束縛を増やす前後で、古い像の番号と依存する型を同時に移す。 -/
theorem ImageOk.lift {P B Ψ Q C Δ Ξ R0 ν i a}
    (h : ImageOk P B Ψ Q C Δ Ξ R0 ν i a)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (x : Option Ty) :
    ImageOk P B Ψ Q C (Δ.extendOption x) (Ξ.map Pred.lift)
      (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν) (i+1) (a.shiftV 1 0) := by
  have hn : ¬ i+1 < 1 := by omega
  have he := Ty.bind_shiftV_values a 1 ν
  match h with
  | .ordinary ho hv =>
    refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
    rw [he]
    have hh := hv.shift_values (store' := Ψ) hA hw (.refl _) (ShiftMap.outerOption Δ x)
      (Ξ := Ξ.map Pred.lift) (fun p hp => .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))
    simpa only [upSubst, hn, ↓reduceIte, Nat.add_sub_cancel, shiftIndex_add] using hh
  | .hidden hno hnc =>
    exact .hidden (fun hn => hno ((Ty.ordinary_shiftV _ _ _).mp hn))
      (by cases a <;> simp_all [Ty.shiftV])
  | .contLoc (b := b) (t := t) (e := e) (b' := b') (t' := t') (e' := e')
      ha hb hclosed hl hs hr =>
    have hc : (substTyValues ν a).shiftV 1 0 = substTyValues ν a := Ty.shiftV_of_wf_zero hclosed _ _
    have hR : R0.map (Ty.shiftV 1 0) = R0 := by
      cases ho : R0 with
      | none => rfl
      | some r => simp only [Option.map_some]; exact congrArg some (Ty.shiftV_of_wf_zero (hr r ho) _ _)
    rw [hR]
    refine .contLoc (b := b.shiftV 1 0) (t := t.shiftV 1 0) (e := Eff.shiftV 1 0 e) ?_ ?_ ?_ ?_ hs hr
    · simp only [ha, Ty.shiftV]
    · rw [he, hc]; exact hb
    · rw [he, hc]; exact hclosed
    · simp only [upSubst, hn, ↓reduceIte, Nat.add_sub_cancel, hl, Val.rename]
  | .contVar (b := b) (t := t) (e := e) (j := j) ha hv hl =>
    refine .contVar (j := j+1) (b := b.shiftV 1 0) (t := t.shiftV 1 0) (e := Eff.shiftV 1 0 e) ?_ ?_ ?_
    · simp only [ha, Ty.shiftV]
    · simp only [upSubst, hn, ↓reduceIte, Nat.add_sub_cancel, hv, Val.rename]
    · obtain ⟨b', t', e', hi, heq⟩ := hl
      refine ⟨b'.shiftV 1 0, t'.shiftV 1 0, Eff.shiftV 1 0 e', ?_, ?_⟩
      · cases x <;> simp [Ctx.extendOption, Ctx.extend, Ctx.extendNone, List.getElem?_map, hi, Ty.shiftV]
      · rw [he]
        exact (Ty.norm_shiftV (.cont b' t' e') 1 0).trans (congrArg (Ty.shiftV 1 0) heq)

theorem SubstOk.extendNone {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    SubstOk P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) Δ.extendNone (Ξ.map Pred.lift)
      (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν) := by
  intro i a hi
  cases i with
  | zero => simp [Ctx.extendNone] at hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨x,hx,he⟩ := Option.map_eq_some_iff.mp hi
    cases x with
    | none => cases he
    | some b =>
      cases he
      exact (h i b hx).lift hA hw none

theorem SubstOk.wf {P B Ψ Q C Γ Φ Δ Ξ R0 ν a}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hw : a.WF 0 C.length Γ.length)
    (hs : a.Sorted Γ) : (substTyValues ν a).WF 0 C.length Δ.length := by
  have h0 : SubstOk P B Ψ Q C Γ [] Δ Ξ R0 ν := h
  have ht := h0.transport (by simp)
  exact Ty.wf_bind_values hw hs.references (valEnv ν).values ht.imageWF

private theorem SubstOk.extendNorm {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hstore : Ψ.WF) (x y : Ty)
    (hy : y.norm = substTyValues ν x)
    (hc : ∀ b t e, x = .cont b t e → ∃ b' t' e', y = .cont b' t' e') :
    SubstOk P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift) (Δ.extend y) (Ξ.map Pred.lift)
      (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν) := by
  classical
  intro i a hi
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
    cases hi
    have he := Ty.bind_shiftV_values x 1 ν
    by_cases ho : x.Ordinary
    · have hyo : y.Ordinary := (Ty.ordinary_norm y).mp
        (hy.symm ▸ (Ty.ordinary_bind_values x ν).mpr ho)
      refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
      rw [he, ←hy]
      have hh : HasTypeVQ P B Ψ Q C (Δ.extend y) (Ξ.map Pred.lift) (.var 0) (y.shiftV 1 0) :=
        .V_Var rfl ((Ty.ordinary_shiftV _ _ _).mpr hyo)
      simpa only [Ty.norm_shiftV, upSubst, show 0 < 1 from by omega, if_true] using hh.V_Normal
    · by_cases hn : ∀ b t e, x ≠ .cont b t e
      · exact .hidden (fun h => ho ((Ty.ordinary_shiftV _ _ _).mp h))
          (by cases x <;> simp_all [Ty.shiftV])
      · have hex : ∃ b t e, x = .cont b t e := by
          apply Classical.byContradiction
          intro hh
          exact hn (fun b t e hx => hh ⟨b,t,e,hx⟩)
        obtain ⟨b,t,e,hx⟩ := hex
        obtain ⟨b',t',e',hyc⟩ := hc b t e hx
        refine .contVar (j := 0) (b := b.shiftV 1 0) (t := t.shiftV 1 0)
          (e := Eff.shiftV 1 0 e) (by rw [hx]; rfl) rfl ?_
        refine ⟨b'.shiftV 1 0, t'.shiftV 1 0, Eff.shiftV 1 0 e', ?_, ?_⟩
        · simp only [Ctx.extend, List.getElem?_cons_zero, hyc, Ty.shiftV]
        · rw [he]
          exact (Ty.norm_shiftV (.cont b' t' e') 1 0).trans
            (congrArg (Ty.shiftV 1 0) (by simpa only [hyc] using hy))
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨v,hv,he⟩ := Option.map_eq_some_iff.mp hi
    cases v with
    | none => cases he
    | some b => cases he; exact (h i b hv).lift hA hstore (some y)

theorem SubstOk.upValue {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hstore : Ψ.WF) (x : Ty) :
    SubstOk P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift)
      (Δ.extend (substTyValues ν x)) (Ξ.map Pred.lift)
      (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν) :=
  h.extendNorm hA hstore x _ (substTyValues_normal _ _) (by
    intro b t e he; subst x
    exact ⟨substTyValues ν b, substTyValues ν t, substEffValues ν e, rfl⟩)

theorem SubstOk.up {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hstore : Ψ.WF)
    (_hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p))
    (x : Ty) (_hw : x.WF 0 C.length Γ.length) (_hs : x.Sorted Γ) :
    SubstOk P B Ψ Q C (Γ.extend x) (Φ.map Pred.lift)
      (Δ.extend (substTyValues ν x)) (Ξ.map Pred.lift)
      (R0.map (Ty.shiftV 1 0)) (upSubst 1 ν) := h.upValue hA hstore x

theorem SubstOk.upN {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hstore : Ψ.WF)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p))
    (ps : List Ty) (hw : BinderTypes.WF C.length Γ ps) (hs : BinderTypes.Sorted Γ ps) :
    SubstOk P B Ψ Q C (Γ.extendMany ps) (liftMany ps.length Φ)
      (Δ.extendMany (binderImages ν ps)) (liftMany ps.length Ξ)
      (R0.map (Ty.shiftV ps.length 0)) (upSubst ps.length ν) := by
  induction ps generalizing Γ Δ Φ Ξ R0 ν with
  | nil =>
    have he : R0.map (Ty.shiftV 0 0) = R0 := by
      cases R0 <;> simp [Ty.shiftV_zero]
    change SubstOk P B Ψ Q C Γ Φ Δ Ξ (R0.map (Ty.shiftV 0 0)) (upSubst 0 ν)
    rw [he, upSubst_zero]
    exact h
  | cons a as ih =>
    have hf1 : ∀ p ∈ Φ.map Pred.lift,
        Entails ((Δ.extend (substTyValues ν a)).facts ++ Ξ.map Pred.lift)
          (predBind (valEnv (upSubst 1 ν)).values p) := by
      intro p hp
      simpa only [valEnv_upSubst_one, ← substTyValues_eq_bind] using
        ((h.transport hf).up a).facts p (List.mem_append_right _ hp)
    have hh := ih (h.up hA hstore hf a hw.1 hs.1) hf1 hw.2 hs.2
    rw [show Φ.map Pred.lift = liftMany 1 Φ from rfl,
      show Ξ.map Pred.lift = liftMany 1 Ξ from rfl] at hh
    simpa only [Ctx.extendMany, binderImages, List.length_cons, liftMany_add,
      upSubst_add, Option.map_map, Function.comp_def, Ty.shiftV_add, Nat.add_comm 1] using hh


theorem SubstOk.upNValue {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.ValueAssumptions P B)
    (hstore : Ψ.WF) (ps : List Ty) :
    SubstOk P B Ψ Q C (Γ.extendMany ps) (liftMany ps.length Φ)
      (Δ.extendMany (binderImages ν ps)) (liftMany ps.length Ξ)
      (R0.map (Ty.shiftV ps.length 0)) (upSubst ps.length ν) := by
  induction ps generalizing Γ Δ Φ Ξ R0 ν with
  | nil =>
    have he : R0.map (Ty.shiftV 0 0)=R0 := by cases R0 <;> simp [Ty.shiftV_zero]
    change SubstOk P B Ψ Q C Γ Φ Δ Ξ (R0.map (Ty.shiftV 0 0)) (upSubst 0 ν)
    rw [he,upSubst_zero]; exact h
  | cons a as ih =>
    have hh := ih (h.upValue hA hstore a)
    rw [show Φ.map Pred.lift=liftMany 1 Φ from rfl,show Ξ.map Pred.lift=liftMany 1 Ξ from rfl] at hh
    simpa only [Ctx.extendMany,binderImages,List.length_cons,liftMany_add,upSubst_add,
      Option.map_map,Function.comp_def,Ty.shiftV_add,Nat.add_comm 1] using hh

theorem SubstOk.store {P B Ψ Ψ' Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.ValueAssumptions P B)
    (hw : Ψ.WF) (hp : Ψ.PreservesNormals Ψ') : SubstOk P B Ψ' Q C Γ Φ Δ Ξ R0 ν := by
  intro i a hi
  match h i a hi with
  | .ordinary ho hv =>
    refine .ordinary ho ?_
    have hm : ShiftMap 0 0 Δ Δ := ⟨by omega,fun i a hi _ => by simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
    have hh := hv.shift_values hA hw hp hm (Ξ := Ξ)
      (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
    simpa only [shiftIndex_zero,Val.rename_identity,Ty.shiftV_zero] using hh
  | .hidden hn hc => exact .hidden hn hc
  | .contLoc he ht hw hv hl hr => exact .contLoc he ht hw hv (hp _ _ hl trivial) hr
  | .contVar he hv hi => exact .contVar he hv hi

theorem Transport.many_values {Γ Φ Δ Ξ ν} (h : Transport (valEnv ν) Γ Φ Δ Ξ) (ps : List Ty) :
    Transport (valEnv (upSubst ps.length ν)) (Γ.extendMany ps) (liftMany ps.length Φ)
      (Δ.extendMany (binderImages ν ps)) (liftMany ps.length Ξ) := by
  induction ps generalizing Γ Φ Δ Ξ ν with
  | nil => simpa only [List.length_nil,Ctx.extendMany,binderImages,upSubst_zero,liftMany_eq,show Pred.shiftV 0 0=_root_.id from funext (fun (p : Pred) => p.shiftV_zero 0),List.map_id] using h
  | cons a as ih =>
    have hu : Transport (valEnv (upSubst 1 ν)) (Γ.extend a) (Φ.map Pred.lift)
        (Δ.extend (substTyValues ν a)) (Ξ.map Pred.lift) := by
      simpa only [valEnv_upSubst_one,substTyValues] using h.up a
    have hh := ih hu
    simpa only [Ctx.extendMany,binderImages,List.length_cons,←liftMany_one,liftMany_add,upSubst_add,Nat.add_comm 1] using hh

private theorem TypedImages.hide_substOk {P B Ψ Q C Γ Δ Ξ ν Φ}
    (h : TypedImages P B Ψ Q C Γ Δ Ξ ν) (hA : Builtins.ValueAssumptions P B)
    (hw : Ψ.WF) (Ψ' : StoreTy) (hp : Ψ.PreservesNormals Ψ') (R0 : Option Ty) :
    SubstOk P B Ψ' Q C (hideConts Γ) Φ (hideConts Δ) Ξ R0 ν := by
  intro i a hi
  have ho := (hideConts_lookup.mp hi).2
  exact .ordinary ho ((h.hide hA hw Ψ' hp) i a hi ho)

theorem ImageOk.liftParams {P B Ψ Q C Δ Ξ R0 ν i a}
    (h : ImageOk P B Ψ Q C Δ Ξ R0 ν i a)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (ps : List Ty) :
    ImageOk P B Ψ Q C (bindParams Δ ps) (liftMany ps.length Ξ)
      (R0.map (Ty.shiftV ps.length 0)) (upSubst ps.length ν) (i+ps.length) (a.shiftV ps.length 0) := by
  have hn : ¬ i+ps.length < ps.length := by omega
  have he := Ty.bind_shiftV_values a ps.length ν
  match h with
  | .ordinary ho hv =>
    refine .ordinary ((Ty.ordinary_shiftV _ _ _).mpr ho) ?_
    rw [he]
    have hh := hv.shift_values (store' := Ψ) hA hw (.refl _) (ShiftMap.outer Δ ps)
      (Ξ := liftMany ps.length Ξ) (fun p hp => .hyp (List.mem_append_right _ (by
        rw [liftMany_eq]; exact List.mem_map.mpr ⟨p,hp,rfl⟩)))
    simpa only [upSubst, hn, ↓reduceIte, Nat.add_sub_cancel, shiftIndex_add] using hh
  | .hidden hno hnc =>
    exact .hidden (fun hn => hno ((Ty.ordinary_shiftV _ _ _).mp hn))
      (by cases a <;> simp_all [Ty.shiftV])
  | .contLoc (b := b) (t := t) (e := e) (b' := b') (t' := t') (e' := e') ha hb hc hv hl hr =>
    have hec : (substTyValues ν a).shiftV ps.length 0 = substTyValues ν a := Ty.shiftV_of_wf_zero hc _ _
    have hR : R0.map (Ty.shiftV ps.length 0) = R0 := by
      cases ho : R0 with
      | none => rfl
      | some r => simp only [Option.map_some]; exact congrArg some (Ty.shiftV_of_wf_zero (hr r ho) _ _)
    rw [hR]
    refine .contLoc (b := b.shiftV ps.length 0) (t := t.shiftV ps.length 0) (e := Eff.shiftV ps.length 0 e)
      (by simp only [ha, Ty.shiftV]) ?_ ?_ ?_ hl hr
    · rw [he, hec]; exact hb
    · rw [he, hec]; exact hc
    · simp only [upSubst, hn, ↓reduceIte, Nat.add_sub_cancel, hv, Val.rename]
  | .contVar (b := b) (t := t) (e := e) (j := j) ha hv hl =>
    refine .contVar (j := j+ps.length) (b := b.shiftV ps.length 0) (t := t.shiftV ps.length 0)
      (e := Eff.shiftV ps.length 0 e) (by simp only [ha, Ty.shiftV]) ?_ ?_
    · simp only [upSubst, hn, ↓reduceIte, Nat.add_sub_cancel, hv, Val.rename]
    · obtain ⟨b', t', e', hi, heq⟩ := hl
      refine ⟨b'.shiftV ps.length 0, t'.shiftV ps.length 0, Eff.shiftV ps.length 0 e', ?_, ?_⟩
      · rw [bindParams, List.getElem?_append_right (by simp only [List.length_map, List.length_reverse]; omega)]
        simp only [List.length_map, List.length_reverse, Nat.add_sub_cancel_right,
          List.getElem?_map, hi, Option.map_some, Ty.shiftV]
      · rw [he]
        exact (Ty.norm_shiftV (.cont b' t' e') ps.length 0).trans (congrArg (Ty.shiftV ps.length 0) heq)

theorem SubstOk.params {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (ps : List Ty) :
    SubstOk P B Ψ Q C (bindParams Γ ps) (liftMany ps.length Φ)
      (bindParams Δ (ps.map (substTyValues ν))) (liftMany ps.length Ξ)
      (R0.map (Ty.shiftV ps.length 0)) (upSubst ps.length ν) := by
  intro i a hi
  by_cases ho : a.Ordinary
  · exact .ordinary ho (h.images.params hA hw ps i a hi ho)
  · by_cases hil : i < ps.length
    · rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi
      simp only [List.getElem?_map] at hi
      cases hu : ps.reverse[i]? with
      | none => simp [hu] at hi
      | some u =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        cases u <;> simp only [Ty.shiftV, Ty.Ordinary, Ordinary, Ty.core] at ho
        all_goals try (solve | apply False.elim; apply ho; intros; simp)
        case refined a p =>
          exact .hidden ho (by intros; simp [Ty.shiftV])
        case cont b t e =>
          refine .contVar (j := i) rfl (by simp [upSubst, hil]) ?_
          rw [Ty.bind_shiftV_values]
          rw [bindParams, List.getElem?_append_left (by simpa using hil)]
          refine ⟨(substTyValues ν b).shiftV ps.length 0, (substTyValues ν t).shiftV ps.length 0,
            Eff.shiftV ps.length 0 (substEffValues ν e), ?_, ?_⟩
          · simp only [← List.map_reverse, List.getElem?_map, List.length_map, hu, Option.map_some,
              substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Ty.shiftV, substEffValues, Eff.bind]
          · exact (Ty.norm_shiftV (substTyValues ν (.cont b t e)) ps.length 0).trans
              (congrArg (Ty.shiftV ps.length 0) (substTyValues_normal _ _))
    · rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi
      simp only [List.length_map, List.length_reverse, List.getElem?_map] at hi
      cases hu : Γ[i-ps.length]? with
      | none => simp [hu] at hi
      | some u => cases u with
        | none => simp [hu] at hi
        | some u =>
          simp only [hu, Option.map_some, Option.some.injEq] at hi
          cases hi
          have hh := (h (i-ps.length) u hu).liftParams hA hw (ps.map (substTyValues ν))
          simpa only [List.length_map, Nat.sub_add_cancel (Nat.le_of_not_gt hil)] using hh

theorem ImageOk.shiftEAt {P B Ψ Q C Δ Ξ R0 ν i a C' k c}
    (h : ImageOk P B Ψ Q C Δ Ξ R0 ν i a) (hA : Builtins.TypeAssumptions P B)
    (hstore : Ψ.WF) (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) :
    ImageOk P B Ψ Q C' (Δ.shiftEAt k c) Ξ (R0.map (shiftTypes k c))
      (fun i => (ν i).shiftEAt k c) i (shiftTypes k c a) := by
  match h with
  | .ordinary ho hv =>
    refine .ordinary ((Ty.ordinary_shiftTypes _ _ _).mpr ho) ?_
    rw [substTyValues_shiftEAt]
    exact hv.shift_types hA hstore hC hn (TypeCtxMap.shiftEAt Δ k c)
  | .hidden hno hnc =>
    exact .hidden (fun hn => hno ((Ty.ordinary_shiftTypes _ _ _).mp hn))
      (by cases a <;> simp_all [shiftTypes])
  | .contLoc (b' := b') (t' := t') (e' := e') (l := l) he ht hw hv hl hr =>
    have hc := Ty.shiftTypes_of_wf_zero hw k c
    have hR : R0.map (shiftTypes k c)=R0 := by
      cases he : R0 with
      | none => rfl
      | some r => exact congrArg some (Ty.shiftTypes_of_wf_zero (hr r he) k c)
    subst he
    refine .contLoc (b' := b') (t' := t') (e' := e') (l := l) rfl ?_ ?_ ?_ ?_ ?_
    · rw [substTyValues_shiftEAt,hc]; exact ht
    · rw [substTyValues_shiftEAt,hc]; exact hw
    · simp only [hv,Val.shiftEAt]
    · simpa only [hR] using hl
    · simpa only [hR] using hr
  | .contVar (j := j) he hv hi =>
    subst he
    refine .contVar (j := j) rfl (by simp only [hv,Val.shiftEAt]) ?_
    obtain ⟨b', t', e', hi, heq⟩ := hi
    refine ⟨shiftTypes k c b', shiftTypes k c t', shiftRowsTypes k c e', ?_, ?_⟩
    · exact (TypeCtxMap.shiftEAt Δ k c).lookup _ _ hi
    · rw [substTyValues_shiftEAt]
      exact (Ty.norm_shiftTypes (.cont b' t' e') k c).trans (congrArg (shiftTypes k c) heq)

theorem SubstOk.shiftEAt {P B Ψ Q C Γ Φ Δ Ξ R0 ν C' k c}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.TypeAssumptions P B)
    (hstore : Ψ.WF) (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) :
    SubstOk P B Ψ Q C' (Γ.shiftEAt k c) Φ (Δ.shiftEAt k c) Ξ (R0.map (shiftTypes k c))
      (fun i => (ν i).shiftEAt k c) := by
  intro i a hi
  simp only [Ctx.shiftEAt,List.getElem?_map] at hi
  cases hg : Γ[i]? with
  | none => simp [hg] at hi
  | some u => cases u with
    | none => simp [hg] at hi
    | some b =>
      simp only [hg,Option.map_some,Option.some.injEq] at hi
      cases hi
      exact (h _ _ hg).shiftEAt hA hstore hC hn

theorem SubstOk.shiftE {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.TypeAssumptions P B)
    (hstore : Ψ.WF) (_hΓ : Ctx.WF 0 C.length Γ) (_hΔ : Ctx.WF 0 C.length Δ) (extra : TypeCtx) :
    SubstOk P B Ψ Q (extra++C) (Γ.shiftE extra.length) Φ (Δ.shiftE extra.length) Ξ
      (R0.map (shiftTypes extra.length 0)) (fun i => (ν i).shiftE extra.length) := by
  apply h.shiftEAt hA hstore
  · simpa only [List.nil_append,List.length_nil] using TypeParamRenaming.insert [] extra C
  · simp [Nat.add_comm]

theorem SubstOk.clause {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.ValueAssumptions P B) (hstore : Ψ.WF)
    (hf : ∀ p∈Φ, Entails (Δ.facts++Ξ) (predBind (valEnv ν).values p))
    (ps : List Ty) (hw : BinderTypes.WF C.length Γ ps) (hs : BinderTypes.Sorted Γ ps)
    (cont : Option Ty)
    (_hk : ∀ a, cont=some a → a.WF 0 C.length (Γ.length+ps.length) ∧ a.Sorted (Γ.extendMany ps)) :
    SubstOk P B Ψ Q C ((Γ.extendMany ps).extendOption cont) (liftMany (ps.length+1) Φ)
      ((Δ.extendMany (binderImages ν ps)).extendOption (cont.map (substTyValues (upSubst ps.length ν))))
      (liftMany (ps.length+1) Ξ) (R0.map (Ty.shiftV (ps.length+1) 0)) (upSubst (ps.length+1) ν) := by
  have hh := h.upN hA hstore hf ps hw hs
  cases cont with
  | none =>
    have hx := hh.extendNone hA hstore
    simpa only [Ctx.extendOption,Option.map_none,←liftMany_one,liftMany_add,upSubst_add,Option.map_map,Function.comp_def,
      Ty.shiftV_add,Nat.add_comm 1] using hx
  | some a =>
    have hx := hh.upValue hA hstore a
    simpa only [Ctx.extendOption,Option.map_some,←liftMany_one,liftMany_add,upSubst_add,Option.map_map,Function.comp_def,
      Ty.shiftV_add,Nat.add_comm 1] using hx

theorem SubstOk.clauseValue {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (ps : List Ty) (cont : Option Ty) :
    SubstOk P B Ψ Q C ((Γ.extendMany ps).extendOption cont) (liftMany (ps.length+1) Φ)
      ((Δ.extendMany (binderImages ν ps)).extendOption (cont.map (substTyValues (upSubst ps.length ν))))
      (liftMany (ps.length+1) Ξ) (R0.map (Ty.shiftV (ps.length+1) 0)) (upSubst (ps.length+1) ν) := by
  have hh := h.upNValue hA hw ps
  cases cont with
  | none =>
    have hx := hh.extendNone hA hw
    simpa only [Ctx.extendOption,Option.map_none,←liftMany_one,liftMany_add,upSubst_add,Option.map_map,Function.comp_def,
      Ty.shiftV_add,Nat.add_comm 1] using hx
  | some a =>
    have hx := hh.upValue hA hw a
    simpa only [Ctx.extendOption,Option.map_some,←liftMany_one,liftMany_add,upSubst_add,Option.map_map,Function.comp_def,
      Ty.shiftV_add,Nat.add_comm 1] using hx

theorem Transport.clause_values {Γ Φ Δ Ξ ν} (h : Transport (valEnv ν) Γ Φ Δ Ξ)
    (ps : List Ty) (cont : Option Ty) :
    Transport (valEnv (upSubst (ps.length+1) ν)) ((Γ.extendMany ps).extendOption cont)
      (liftMany (ps.length+1) Φ)
      ((Δ.extendMany (binderImages ν ps)).extendOption (cont.map (substTyValues (upSubst ps.length ν))))
      (liftMany (ps.length+1) Ξ) := by
  have hh := h.many_values ps
  cases cont with
  | none =>
    have hx := hh.extendNone
    simpa only [Ctx.extendOption,Option.map_none,←liftMany_one,liftMany_add,upSubst_add,
      ←valEnv_upSubst_one,Nat.add_comm 1] using hx
  | some a =>
    have hx := hh.up a
    simpa only [Ctx.extendOption,Option.map_some,←liftMany_one,liftMany_add,upSubst_add,
      ←valEnv_upSubst_one,substTyValues,Nat.add_comm 1] using hx

theorem SubstOk.poly {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (extra : TypeCtx) :
    SubstOk P B (hideBuilders Ψ) Q (extra++C) (Γ.shiftE extra.length) Φ
      (Δ.shiftE extra.length) Ξ (R0.map (shiftTypes extra.length 0))
      (fun i => (ν i).shiftEAt extra.length 0) := by
  have hh := h.store hA.toValueAssumptions hw (StoreTy.preserves_hide _)
  apply hh.shiftEAt hA.toTypeAssumptions hw.hide
  · simpa only [List.nil_append,List.length_nil] using TypeParamRenaming.insert [] extra C
  · simp [Nat.add_comm]

theorem shifted_values_facts {Δ : Ctx} {Ξ Φ : List Pred} {ν : Nat → Val} (k : Nat)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv ν).values p)) :
    ∀ p∈Φ,Entails ((Δ.shiftE k).facts++Ξ)
      (predBind (valEnv (fun i => (ν i).shiftEAt k 0)).values p) := by
  intro p hp
  have hh := (TypeCtxMap.shiftEAt Δ k 0).entails (hf p hp)
  simpa only [Ctx.shiftE, valEnv,Val.toTerm_shiftEAt] using hh

private theorem SubstOk.fixedParameters {P B Ψ Q C Γ Φ Δ Ξ R0 ν nt n ps}
    (hw : BinderTypes.LocalWF nt n ps)
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 (upSubst n ν))
    (hA : Builtins.ValueAssumptions P B) (hs : Ψ.WF) :
    SubstOk P B Ψ Q C (Γ.extendMany ps) (liftMany ps.length Φ)
      (Δ.extendMany ps) (liftMany ps.length Ξ) (R0.map (Ty.shiftV ps.length 0))
      (upSubst ps.length (upSubst n ν)) := by
  induction ps generalizing Γ Δ Φ Ξ R0 n with
  | nil => simpa only [Ctx.extendMany, List.length_nil, liftMany_eq, List.map_id, show Pred.shiftV 0 0 = _root_.id from funext (fun p : Pred => p.shiftV_zero 0), upSubst_zero, Ty.shiftV_zero, Option.map_id, id_eq, show Ty.shiftV 0 0 = id from funext (fun a => a.shiftV_zero 0)] using h
  | cons x xs ih =>
    have hx := h.extendNorm hA hs x x (Ty.subst_up_fixed hw.1 ν).symm
      (by intro b t e he; exact ⟨b,t,e,he⟩)
    have he : upSubst 1 (upSubst n ν) = upSubst (n+1) ν := by rw [upSubst_add]
    rw [he] at hx
    have hh := ih hw.2 hx
    simpa only [Ctx.extendMany, List.length_cons, ←liftMany_one, liftMany_add,
      upSubst_add, Option.map_map, Function.comp_def, Ty.shiftV_add, Nat.add_assoc, Nat.add_comm 1] using hh

private theorem Transport.up_norm {θ Γ Φ Δ Ξ} (h : Transport θ Γ Φ Δ Ξ)
    (x y : Ty) (hy : y.norm = x.bind θ) :
    Transport θ.up (Γ.extend x) (Φ.map Pred.lift) (Δ.extend y) (Ξ.map Pred.lift) := by
  apply h.extend x y
  · intro sort hs
    apply (Ty.hasSort_norm _ _).mp
    rw [hy]; exact Ty.hasSort_bind hs θ
  · intro ho
    apply (Ty.ordinary_norm _).mp
    rw [hy]; exact Ty.ordinary_bind ho θ h.typeImages
  · intro p hp
    have hh := Ty.assume_bind x θ h.typeImages p hp
    rwa [←hy, Ty.assume_norm] at hh

private theorem Transport.fixedParameters {Γ Φ Δ Ξ ν nt n ps}
    (hw : BinderTypes.LocalWF nt n ps)
    (h : Transport (valEnv (upSubst n ν)) Γ Φ Δ Ξ) :
    Transport (valEnv (upSubst ps.length (upSubst n ν)))
      (Γ.extendMany ps) (liftMany ps.length Φ) (Δ.extendMany ps) (liftMany ps.length Ξ) := by
  induction ps generalizing Γ Δ Φ Ξ n with
  | nil => simpa only [Ctx.extendMany, List.length_nil, liftMany_eq, List.map_id, show Pred.shiftV 0 0 = _root_.id from funext (fun p : Pred => p.shiftV_zero 0), upSubst_zero, id_eq, show (fun p => Pred.shiftV 0 0 p) = _root_.id from funext (fun p : Pred => p.shiftV_zero 0)] using h
  | cons x xs ih =>
    have hx := h.up_norm x x (Ty.subst_up_fixed hw.1 ν).symm
    rw [←valEnv_upSubst_one, upSubst_add] at hx
    have hh := ih hw.2 hx
    simpa only [Ctx.extendMany, List.length_cons, ←liftMany_one, liftMany_add, upSubst_add,
      Nat.add_assoc, Nat.add_comm 1] using hh

theorem SubstOk.handler_clause {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (sg : OpSig) (hs : sg.WF) (t : Ty) (e : Eff) :
    SubstOk P B (hideBuilders Ψ) Q (sg.tparams++C) (sg.context Γ t e)
      (liftMany (sg.params.length+1) Φ) (sg.context Δ (substTyValues ν t) (substEffValues ν e))
      (liftMany (sg.params.length+1) Ξ)
      (R0.map (fun r => (shiftTypes sg.tparams.length 0 r).shiftV (sg.params.length+1) 0))
      (upSubst (sg.params.length+1) (fun i => (ν i).shiftEAt sg.tparams.length 0)) := by
  let μ := fun i => (ν i).shiftEAt sg.tparams.length 0
  have hp := SubstOk.fixedParameters (ν := μ) hs.1 (by
    simpa only [upSubst_zero] using h.poly hA hw sg.tparams) hA.toValueAssumptions hw.hide
  simp only [upSubst_zero] at hp
  have hh := hp.extendNorm hA.toValueAssumptions hw.hide (sg.continuation t e)
    (sg.continuation (substTyValues ν t) (substEffValues ν e))
    (OpSig.continuation_subst_values hs t e ν).symm
    (by intro b u f he; exact ⟨sg.ret,_,_,rfl⟩)
  simpa only [OpSig.context, ←liftMany_one, liftMany_add, upSubst_add,
    Option.map_map, Function.comp_def, Ty.shiftV_add, Nat.add_comm 1] using hh

theorem SubstOk.handler_conditions {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (sg : OpSig) (hs : sg.WF) (t : Ty) (e : Eff)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv ν).values p)) :
    ∀ p∈liftMany (sg.params.length+1) Φ,
      Entails ((sg.context Δ (substTyValues ν t) (substEffValues ν e)).facts++liftMany (sg.params.length+1) Ξ)
        (predBind (valEnv (upSubst (sg.params.length+1) (fun i => (ν i).shiftEAt sg.tparams.length 0))).values p) := by
  let μ := fun i => (ν i).shiftEAt sg.tparams.length 0
  have hp := Transport.fixedParameters (ν := μ) hs.1 (by
    simpa only [upSubst_zero] using
      (h.poly hA hw sg.tparams).transport (shifted_values_facts sg.tparams.length hf))
  simp only [upSubst_zero] at hp
  have hh := hp.up_norm (sg.continuation t e)
    (sg.continuation (substTyValues ν t) (substEffValues ν e))
    (OpSig.continuation_subst_values hs t e ν).symm
  intro p hm
  have hx := hh.facts p (List.mem_append_right _ hm)
  simpa only [OpSig.context, ←liftMany_one, liftMany_add, ←valEnv_upSubst_one, upSubst_add,
    Nat.add_comm 1] using hx

theorem SubstOk.handler_failure {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (E : Ty) :
    SubstOk P B (hideBuilders Ψ) Q (TypeCtx.valueParam::C) (failureContext Γ E) (liftMany 2 Φ)
      (failureContext Δ (substTyValues ν E)) (liftMany 2 Ξ)
      (R0.map (fun r => (shiftTypes 1 0 r).shiftV 2 0))
      (upSubst 2 (fun i => (ν i).shiftEAt 1 0)) := by
  have hh := (h.poly hA hw [TypeCtx.valueParam]).clauseValue hA.toValueAssumptions hw.hide [shiftTypes 1 0 E] none
  simpa only [failureContext,Ctx.extendOption,binderImages,Ctx.extendMany,List.singleton_append,Nat.reduceAdd,List.length_cons,List.length_nil,
    Nat.zero_add,Option.map_none,Option.map_map,Function.comp_def,substTyValues_shiftEAt] using hh

theorem SubstOk.failure_conditions {P B Ψ Q C Γ Φ Δ Ξ R0 ν}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν) (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (E : Ty)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv ν).values p)) :
    ∀ p∈liftMany 2 Φ,Entails ((failureContext Δ (substTyValues ν E)).facts++liftMany 2 Ξ)
      (predBind (valEnv (upSubst 2 (fun i => (ν i).shiftEAt 1 0))).values p) := by
  have hh := ((h.poly hA hw [TypeCtx.valueParam]).transport (shifted_values_facts 1 hf)).clause_values [shiftTypes 1 0 E] none
  intro p hp
  have hx := hh.facts p (List.mem_append_right _ hp)
  simpa only [failureContext,Ctx.extendOption,binderImages,Ctx.extendMany,List.singleton_append,Nat.reduceAdd,List.length_cons,List.length_nil,
    Nat.zero_add,Option.map_none,substTyValues_shiftEAt] using hx

theorem LocalSubstOk.localExtend {Ψ L L' ν ρ} (h : LocalSubstOk Ψ L ν ρ L')
    (hw : Ψ.WF) (n : Nat) :
    LocalSubstOk Ψ (localExtend n L) (upSubst n ν) (upLocalSubst n ρ) (localExtend n L') := by
  induction n with
  | zero =>
    simpa only [Refinement.localExtend, upSubst_zero, upLocalSubst_zero] using h
  | succ n ih =>
    simpa only [Refinement.localExtend, Option.map_none, upSubst_add, upLocalSubst_add] using ih.extend hw none

/-- 同じ像が二つの異なるreturn契約で型付けば、継続場所の枝は使われていない。 -/
private theorem ImageOk.changeReturn {P B Ψ Q C Δ Ξ ν i a}
    (h : ImageOk P B Ψ Q C Δ Ξ none ν i a)
    (h1 : ImageOk P B Ψ Q C Δ Ξ (some (.base .unit)) ν i a) (R : Option Ty) :
    ImageOk P B Ψ Q C Δ Ξ R ν i a := by
  cases h with
  | ordinary ho hv => exact .ordinary ho hv
  | hidden hn hc => exact .hidden hn hc
  | contVar ha hv ht => exact .contVar ha hv ht
  | contLoc ha hb hc hl hs hr =>
    cases h1 with
    | ordinary ho hv => subst a; exact False.elim (ho _ _ _ rfl)
    | hidden hn hc => exact False.elim (hc _ _ _ ha)
    | contVar ha1 hv1 ht1 => rw [hl] at hv1; cases hv1
    | contLoc ha1 hb1 hc1 hl1 hs1 hr1 =>
      rw [hl] at hl1
      cases hl1
      rw [hs] at hs1
      cases hs1

private def ReturnFreeImages (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (C : TypeCtx) (Γ Δ : Ctx) (Ξ : List Pred) (ν : Nat → Val) : Prop :=
  ∀ R, SubstOk P B Ψ Q C Γ [] Δ Ξ R ν

private theorem ReturnFreeImages.up {P B Ψ Q C Γ Δ Ξ ν}
    (h : ReturnFreeImages P B Ψ Q C Γ Δ Ξ ν) (hA : Builtins.ValueAssumptions P B)
    (hw : Ψ.WF) (a : Ty) :
    ReturnFreeImages P B Ψ Q C (Γ.extend a) (Δ.extend (substTyValues ν a))
      (Ξ.map Pred.lift) (upSubst 1 ν) := by
  intro R i b hi
  have h0 := (h none).upValue hA hw a i b hi
  have h1 := (h (some (.base .unit))).upValue hA hw a i b hi
  exact ImageOk.changeReturn h0 (by simpa only [Option.map_some, Ty.shiftV] using h1) R


theorem SubstOk.add_conditions {P B store Q C Γ Φ Δ Ξ R ν} (added : List Pred)
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R ν)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) :
    SubstOk P B store Q C Γ Φ Δ (added ++ Ξ) R ν := by
  intro i a hi
  exact (h i a hi).weaken_conditions hA hw
    (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_append_right _ hp)))

private theorem TypedImages.raw_bool_annotation {P B store Q C Γ Δ Ξ ν p}
    (h : TypedImages P B store Q C Γ Δ Ξ ν)
    (ha : Ty.Annotation P C Γ (.refined (.base .boolean) p)) :
    Ty.Annotation P C Δ (.refined (.base .boolean) (predBind (upValues (valEnv ν).values) p)) := by
  have hs := Pred.sorted_bind ha.sorted.2 (valEnv ν).values (fun _ h => h) (fun h => h) h.values h.references
  exact ⟨⟨trivial,Pred.wf_of_sorted hs,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,hs⟩,
    ⟨trivial,ha.declared.2.bind_values h.declaration⟩⟩

theorem SubstOk.raw_bool_annotation {P B store Q C Γ Φ Δ Ξ R ν p}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R ν)
    (ha : Ty.Annotation P C Γ (.refined (.base .boolean) p)) :
    Ty.Annotation P C Δ (.refined (.base .boolean) (predBind (upValues (valEnv ν).values) p)) :=
  h.images.raw_bool_annotation ha

mutual
  private theorem subst_value {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) := by
    match h with
    | .V_Var hi ho => exact ht _ _ hi ho
    | .V_Const hc => rw [substTyValues, Const.type_bind_values]; exact .V_Const hc
    | .V_Lam (ps := ps) (r := r) hn hw hs hb hd =>
      apply HasTypeVQ.subst_lam hw hs (ht.transport hf) hd ht.declaration
      have hb' := subst_comp (L' := []) hb hA hT hstore.hide (upLocalSubst ps.length ρ)
        (by
          have hh := (ht.hide_substOk (Φ := Φ) hA hstore (hideBuilders store)
            (StoreTy.preserves_hide _) (some (substTyValues σ r))).params hA hstore.hide ps
          simpa only [Option.map_some, Ty.bind_shiftV_values] using hh) (.empty _ _ _ _)
        ((ht.hide hA hstore (hideBuilders store) (StoreTy.preserves_hide _)).conditions_params
          (fun p hp => (hf p hp).hideConts) ps)
      simpa only [Option.map_some, Ty.bind_shiftV_values, Eff.bind_shiftV_values, Option.map_none, localExtend] using hb'
    | .V_DependentLam (t := t) ha hb =>
      have hhide := ht.hide hA hstore (hideBuilders store) (StoreTy.preserves_hide _)
      have hh := subst_telBody hb hA hT hstore.hide ρ
        (show ReturnFreeImages P B (hideBuilders store) Q C (hideConts Γ) (hideConts Δ) Ξ σ from
          fun R => ht.hide_substOk hA hstore _ (StoreTy.preserves_hide _) R)
        (fun p hp => (hf p hp).hideConts)
      simpa only [Val.subst, substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Tel.bind, Ty.norm_foldFn, Tel.norm_idem, Ty.norm_idem] using
        (HasTypeVQ.V_DependentLam (ht.telAnnotation ha) hh).V_Normal
    | .V_Closure (runtime := runtime) (t := t) ha hw hb =>
      have hc : (Ty.dependentFn t).WF 0 0 0 := hw.contract_wf
      have he := Ty.subst_values_of_wf_zero hc σ
      simpa only [Val.subst, he] using
        (HasTypeVQ.V_Closure (Ψ := store) (Q := Q) (Φ := Ξ)
          (ht.closedAnnotation hc ha) hw hb).V_Normal
    | .V_List he hw hs hd =>
      exact .V_List (subst_each he hA hT hstore ρ ht hf) (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .V_Fun hd hn ha hi =>
      have hh := HasTypeVQ.V_Fun (Ψ := store) (Φ := Ξ) hd hn (ht.admissible hA hi.types hi.rows ha) (ht.signature hi)
      simpa only [Val.subst, instantiatedTel_subst hi.source] using hh.V_Normal
    | .V_Prim hb hr hn ha hi =>
      have hh := HasTypeVQ.V_Prim (Ψ := store) (Φ := Ξ) hb hr hn (ht.primitive hA hb hi.types hi.rows ha) (ht.signature hi)
      simpa only [Val.subst, instantiatedTel_subst hi.source] using hh.V_Normal
    | .V_Op ho hn ha hi =>
      have hs := ha.map (substTyValues σ) (fun a hm p hp => ht.sat_normal hA (hi.types a hm) hp)
      have hh := HasTypeVQ.V_Op (Q := Q) (Ψ := store) (Φ := Ξ) ho hn hs (ht.signature hi)
      simpa only [Val.subst, List.map_nil, instantiatedTel_subst hi.source] using hh.V_Normal
    | .V_ExternalRef hd hw ha hi =>
      have hh := HasTypeVQ.V_ExternalRef (Q := Q) (Ψ := store) (Φ := Ξ) hd hw
        (ha.map hw (substTyValues σ)) (ht.signature hi)
      simpa only [Val.subst, List.map_nil, instantiatedTel_subst hi.source] using hh.V_Normal
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
      exact .V_Map (subst_each hk hA hT hstore ρ ht hf) (subst_each hv hA hT hstore ρ ht hf)
        (by simpa using hn) (ht.sat_normal hA ha hs) (ht.annotation ha) (ht.annotation hb)
    | .V_Set hv hs ha =>
      exact .V_Set (subst_each hv hA hT hstore ρ ht hf) (ht.sat_normal hA ha hs) (ht.annotation ha)
    | .V_Dict (id := id) (ts := ts) hi hs hts hk hw htarget hv ha =>
      have hv' := subst_values hv hA hT hstore ρ ht hf
      have he : (id.dictTys.map (Ty.subst ts [])).map (substTyValues σ) =
          id.dictTys.map (Ty.subst (ts.map (substTyValues σ)) []) := by
        rw [List.map_map]; exact List.map_congr_left (fun a ha => Ty.substV_subst_closed (hw a ha) ts (valEnv σ).values)
      rw [he] at hv'
      have hs' := hs.map (substTyValues σ) (fun a hm p hp => ht.sat_normal hA (hts a hm) hp)
      have ha' := ht.annotation ha
      simp only [Ty.bind_dict, Ty.subst_values_closed htarget] at ha' ⊢
      simpa only [Val.subst] using HasTypeVQ.V_Dict hi hs' (ht.typeAnnotations hts) (hk.subst σ) hw htarget hv' ha'
    | .V_Raise (t := t) (e := e) ha hot hoe hkind =>
      have hh := ht.annotation ha
      simp only [Val.subst, substTyValues, Ty.bind_fn, Eff.bind_singleFail] at hh ⊢
      exact .V_Raise hh ((Ty.ordinary_bind_values _ _).mpr hot) ((Ty.ordinary_bind_values _ _).mpr hoe) (hkind.bind_values σ)
    | .V_LocRef (a := a) hl hd =>
      have hc : (Ty.reference a).WF 0 0 0 := hstore _ _ hl
      have he := Ty.subst_values_of_wf_zero hc σ
      simpa only [Val.subst, he] using
        (HasTypeVQ.V_LocRef hl (ht.closedDeclared hc hd)).V_Normal
    | .V_LocLazy (a := a) hl hd =>
      have hc : (Ty.lazy a).WF 0 0 0 := hstore _ _ hl
      have he := Ty.subst_values_of_wf_zero hc σ
      simpa only [Val.subst, he] using
        (HasTypeVQ.V_LocLazy hl (ht.closedDeclared hc hd)).V_Normal
    | .V_Bytes hb => exact .V_Bytes hb
    | .V_Con (cd := cd) (ts := ts) hc hn hk hw hv ha =>
      have hh := subst_values hv hA hT hstore ρ ht hf
      have he : (cd.args.map (Ty.subst ts [])).map (substTyValues σ) =
          cd.args.map (Ty.subst (ts.map (substTyValues σ)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.substV_subst_closed (hw a ha) ts (valEnv σ).values)
      rw [he] at hh
      simp only [Val.subst, substTyValues, Ty.bind_data]
      exact .V_Con hc (by simpa only [List.length_map] using hn) (hk.subst σ) hw hh (by simpa only [substTyValues_eq_bind, substTyValues, Ty.bind_data] using ht.annotation ha)
    | .V_Super hv hc hmemb hd =>
      exact .V_Super (subst_value hv hA hT hstore ρ ht hf) hc hmemb (hd.bind_values ht.declaration)
    | .V_Normal hv =>
      simpa only [substTyValues_norm_source, substTyValues_normal] using
        (subst_value hv hA hT hstore ρ ht hf).V_Normal
    | .V_Sub hv hl hw hs hd =>
      exact .V_Sub (subst_value hv hA hT hstore ρ ht hf) (hl.bind (valEnv σ) (ht.transport hf))
        (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .V_Refine (a := a) (t := t) (p := p) hv hi hterm hs hw he hda hdp =>
      obtain ⟨u, hu, hus⟩ := hv.observation hi
      have hut : u = t := Option.some.inj (hu.symm.trans hterm)
      subst u
      have hs' := Pred.sorted_bind hs (valEnv σ).values (fun _ h => Ty.hasSort_bind h (valEnv σ))
        (fun h => Ty.ordinary_bind h (valEnv σ) (ht.transport hf).typeImages)
        (ht.transport hf).values (ht.transport hf).references
      rw [show substTyValues σ (.refined a p) =
        (Ty.refined (substTyValues σ a) (predBind (upValues (valEnv σ).values) p)).norm from by
          simp only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Ty.norm_idem]]
      apply HasTypeVQ.V_Normal
      refine .V_Refine (subst_value hv hA hT hstore ρ ht hf) (Ty.hasSort_bind hi (valEnv σ))
        (ht.observation hterm hus ρ) hs' (Pred.wf_of_sorted hs') ?_
        (hda.bind_values ht.declaration) (hdp.bind_values ht.declaration)
      obtain ⟨u, hu, _⟩ := Term.hasSort_bind hus _ ht.values ht.references
      have hsuccess : termBind? (valEnv σ).values t = some (termBind (valEnv σ).values t) := by
        simp only [termBind, hu, Option.getD_some]
      rw [← predBind_open_of_some _ p t _ hsuccess]
      exact (ht.transport hf).entails he
  private theorem subst_values {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeVsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (as.map (substTyValues σ)) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (subst_value hv hA hT hstore ρ ht hf) (subst_values hs hA hT hstore ρ ht hf)
  private theorem subst_each {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeEachQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (substTyValues σ a) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (subst_value hv hA hT hstore ρ ht hf) (subst_each hs hA hT hstore ρ ht hf)
  private theorem subst_comp {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ L'} (ρ : Nat → LocalRef)
      (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
      (hL : LocalSubstOk store L σ ρ L')
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
        (substTyValues σ a) (substEffValues σ e) L' := by
    match h with
    | .C_BuilderLet (kind := kind) ha hk hb hd =>
      simp only [Comp.subst]
      refine .C_BuilderLet (by simpa only [BuilderKind.contents_subst] using ht.images.annotation ha)
        (by simpa only [BuilderKind.contents_subst, List.map_cons, List.map_nil] using hk.subst σ) ?_ (hd.bind_values ht.declaration)
      have hh := subst_comp (Ξ := Ξ.map Pred.lift) hb hA hT hstore (upLocalSubst 1 ρ)
        (by
          have hh := ht.extendNone hA hstore
          simpa only [Option.map_map, Function.comp_def, Ty.bind_shiftV_values] using hh) (hL.extend hstore (some kind)) (fun p hp => by
          have hh := (ht.transport hf).extendNone.facts p (List.mem_append_right _ hp)
          simpa only [valEnv_upSubst_one] using hh)
      simpa only [Option.map_map, Option.map_some, Function.comp_def, Ty.bind_shiftV_values, Eff.bind_shiftV_values] using hh
    | .C_BuilderOp ha hk hr hv =>
      simp only [Comp.subst]
      rw [← BuilderOp.resultType_subst, substEffValues_empty]
      exact .C_BuilderOp (by simpa only [BuilderKind.contents_subst] using ht.images.annotation ha)
        (by simpa only [BuilderKind.contents_subst, List.map_cons, List.map_nil] using hk.subst σ)
        (hr.subst hstore hL)
        (by simpa only [BuilderOp.parameters_subst] using subst_values hv hA hT hstore ρ ht.images hf)
    | .C_Return hv => rw [substEffValues_empty]; exact .C_Return (subst_value hv hA hT hstore ρ ht.images hf)
    | .C_DependentApp (t := t) hv ha =>
      apply HasTypeCQ.C_DependentAppNorm (t := Tel.bind (valEnv σ) t)
      · simpa only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, Tel.bind, Tel.norm_idem] using
          subst_value hv hA hT hstore ρ ht.images hf
      · exact subst_telArgs ha hA hT hstore ρ ht.images hf
    | .C_Normal hb =>
      simpa only [substTyValues_norm_source] using subst_comp hb hA hT hstore ρ ht hL hf
    | .C_App hv hs =>
      have hv' := subst_value hv hA hT hstore ρ ht.images hf
      rw [substTyValues, Ty.bind_fn] at hv'
      exact .C_App hv' (subst_values hs hA hT hstore ρ ht.images hf)
    | .C_If (t := t) hv hobs hm hn =>
      refine .C_If (subst_value hv hA hT hstore ρ ht.images hf)
        (ht.observation hv rfl hobs ρ) ?_ ?_
      · exact subst_comp hm hA hT hstore ρ
          (fun i a hi => (ht i a hi).weaken_conditions hA hstore (by
            intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp)))) hL
          (by
            intro p hp
            rcases List.mem_cons.mp hp with rfl | hp
            · exact .hyp (List.mem_append_right _ List.mem_cons_self)
            · exact (hf p hp).weaken (by
                intro q hq
                rcases List.mem_append.mp hq with hq | hq
                · exact List.mem_append_left _ hq
                · exact List.mem_append_right _ (List.mem_cons_of_mem _ hq)))
      · exact subst_comp hn hA hT hstore ρ
          (fun i a hi => (ht i a hi).weaken_conditions hA hstore (by
            intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp)))) hL
          (by
            intro p hp
            rcases List.mem_cons.mp hp with rfl | hp
            · exact .hyp (List.mem_append_right _ List.mem_cons_self)
            · exact (hf p hp).weaken (by
                intro q hq
                rcases List.mem_append.mp hq with hq | hq
                · exact List.mem_append_left _ hq
                · exact List.mem_append_right _ (List.mem_cons_of_mem _ hq)))
    | .C_Match (obs := obs) hv ho ha hx =>
      refine .C_Match (subst_value hv hA hT hstore ρ ht.images hf) ?_
        (subst_arms ha hA hT hstore ρ ht hL hf)
        (by rw [unguardedPats_subst]; exact hx.subst_values σ)
      intro t hobs
      cases obs with
      | none => cases hobs
      | some u =>
        obtain ⟨hu,s,hs⟩ := ho u rfl
        obtain ⟨w,hw,hws⟩ := Term.hasSort_bind hs _ ht.images.values ht.images.references
        simp only [Option.bind_some,hw,Option.some.injEq] at hobs
        subst t
        exact ⟨by simpa only [termBind,hw,Option.getD_some] using ht.images.observation hu hs ρ,s,hws⟩
    | .C_Lazy hb ha =>
      rw [substEffValues_empty]
      refine .C_Lazy ?_ (ht.images.annotation ha)
      have hh := subst_comp (L' := []) hb hA hT hstore.hide ρ
        (ht.hide hA hstore (StoreTy.preserves_hide _) none) (.empty _ _ _ _) (fun p hp => (hf p hp).hideConts)
      simpa only [substEffValues_empty, Option.map_none, substTyValues, Ty.bind] using hh
    | .C_Escape hv ha => exact .C_Escape (subst_value hv hA hT hstore ρ ht.images hf) (ht.images.annotation ha)
    | .C_Use hv hr hb he =>
      refine .C_Use (subst_value hv hA hT hstore ρ ht.images hf) hr (subst_comp hb hA hT hstore ρ ht hL hf) ?_
      cases e
      simpa only [substEffValues, Eff.bind, Eff.norm, Eff.rawBind, valEnv,
        instAtoms_nil, substAtoms_nil, Eff.test, Eff.atoms] using he
    | .C_Handle hb hc hh =>
      exact .C_Handle (subst_comp hb hA hT hstore ρ ht hL hf)
        (by simpa only [←substEffValues_eq_bind,substEffValues_union,handled_subst,handled_subst_values] using hc.bind (valEnv σ))
        (subst_clauses hh hA hT hstore ρ ht hL hf)
    | .C_Handle_Fail hb hc hn hh =>
      rw [substEffValues_union]
      exact .C_Handle_Fail (subst_comp hb hA hT hstore ρ ht hL hf)
        (by simpa only [←substEffValues_eq_bind,substEffValues_union,substEffValues_singleFail] using hc.bind (valEnv σ))
        (hn.subst_values σ) (subst_failure hh hA hT hstore ρ ht hL hf)
    | .C_Resume (i := i) (v := v) (b := b) (t := t) (ε := ε) hi hv hd =>
      have hv' : HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ b) := by
        simpa only [substTyValues_norm_source] using subst_value hv hA hT hstore ρ ht.images hf
      have hd' := hd.bind_values ht.declaration
      change HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ))
        (.resume (σ i) (v.subst σ ρ)) (substTyValues σ t) (substEffValues σ ε) L'
      cases ht i (.cont b t ε) hi with
      | ordinary ho _ => exact False.elim (ho b t ε rfl)
      | hidden _ hc => exact False.elim (hc b t ε rfl)
      | contLoc _ hty _ himg hloc _ =>
        have heq : Ty.cont (substTyValues σ b) (substTyValues σ t) (substEffValues σ ε) = _ := hty
        obtain ⟨hb,hr,he⟩ := Ty.cont.inj heq
        cases hb; cases hr; cases he
        rw [himg]
        exact .C_ResumeL hloc hv' hd'
      | contVar _ himg hlookup =>
        obtain ⟨b',t',e',hl,heq⟩ := hlookup
        change Ty.cont b'.norm t'.norm (Eff.norm e') = Ty.cont (substTyValues σ b)
          (substTyValues σ t) (substEffValues σ ε) at heq
        obtain ⟨hb,hr,he⟩ := Ty.cont.inj heq
        rw [himg, ←hr, ←he]
        exact .C_ResumeNorm hl (by rw [hb]; exact hv') (by rw [hr]; exact hd')
    | .C_ResumeNorm (i := i) (v := v) (b := b) (t := t) (ε := ε) hi hv hd =>
      have hv' : HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ b) := by
        simpa only [substTyValues_norm_source] using subst_value hv hA hT hstore ρ ht.images hf
      have hd' : Ty.Declared P C Δ (substTyValues σ t) := by
        simpa only [substTyValues, Ty.bind, Ty.norm_rawBind, valEnv_valuesOnly] using hd.bind_values ht.declaration
      simp only [substTyValues_norm_source, substEffValues_norm_source]
      change HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ))
        (.resume (σ i) (v.subst σ ρ)) (substTyValues σ t) (substEffValues σ ε) L'
      cases ht i (.cont b t ε) hi with
      | ordinary ho _ => exact False.elim (ho b t ε rfl)
      | hidden _ hc => exact False.elim (hc b t ε rfl)
      | contLoc _ hty _ himg hloc _ =>
        have heq : Ty.cont (substTyValues σ b) (substTyValues σ t) (substEffValues σ ε) = _ := hty
        obtain ⟨hb,hr,he⟩ := Ty.cont.inj heq
        cases hb; cases hr; cases he
        rw [himg]
        exact .C_ResumeL hloc hv' hd'
      | contVar _ himg hlookup =>
        obtain ⟨b',t',e',hl,heq⟩ := hlookup
        change Ty.cont b'.norm t'.norm (Eff.norm e') = Ty.cont (substTyValues σ b)
          (substTyValues σ t) (substEffValues σ ε) at heq
        obtain ⟨hb,hr,he⟩ := Ty.cont.inj heq
        rw [himg, ←hr, ←he]
        exact .C_ResumeNorm hl (by rw [hb]; exact hv') (by rw [hr]; exact hd')
    | .C_ResumeL (b := b) (t := t) (ε := ε) (R := r) hl hv hd =>
      have hw := hstore _ _ hl
      have hb := Ty.subst_values_of_wf_zero hw.1 σ
      have hr := Ty.subst_values_of_wf_zero hw.2.1 σ
      have he := Eff.subst_values_of_wf_zero hw.2.2.1 hw.2.2.2.1 σ
      have hv' := subst_value hv hA hT hstore ρ ht.images hf
      have hd' := hd.bind_values ht.declaration
      simp only [←substTyValues_eq_bind, hr, valEnv_valuesOnly] at hd'
      simp only [Comp.subst, Val.subst, hb, hr, he] at hv' ⊢
      have hh := HasTypeCQ.C_ResumeLNorm (Δ := L') hl (substReturn_closed σ hw.2.2.2.2).symm hv' hd'
      simpa only [show Eff.norm ε = ε from hw.2.2.2.1] using hh
    | .C_ResumeLNorm (b := b) (t := t) (ε := ε) (R := r) (R' := r') hl hR hv hd =>
      have hw := hstore _ _ hl
      have hb := Ty.subst_values_of_wf_zero hw.1 σ
      have hr := Ty.subst_values_of_wf_zero hw.2.1 σ
      have he := Eff.subst_values_of_wf_zero hw.2.2.1 hw.2.2.2.1 σ
      have hv' := subst_value hv hA hT hstore ρ ht.images hf
      have hd' := hd.bind_values ht.declaration
      simp only [substTyValues, Ty.bind, Ty.norm_rawBind] at hd'
      change Ty.Declared P C Δ (substTyValues σ t) at hd'
      rw [hr] at hd'
      have hR' := congrArg (Option.map (substTyValues σ)) hR
      rw [substReturn_norm, substReturn_norm, substReturn_closed σ hw.2.2.2.2] at hR'
      simp only [Comp.subst, Val.subst, substTyValues_norm_source, substEffValues_norm_source, hb, hr, he] at hv' ⊢
      have hh := HasTypeCQ.C_ResumeLNorm (Δ := L') hl hR' hv' hd'
      simpa only [show Eff.norm ε = ε from hw.2.2.2.1] using hh
    | .C_Meth (ms := ms) (ss := ss) (τ := τ) (es := es) (ws := ws) hv hc hmeth hn hs hi hr hargs hvs ha =>
      have hs' := hs.map (substTyValues σ) (fun a hm' p hp =>
        ht.images.sat_normal hA (hi.types a (List.mem_append_left _ hm')) hp)
      have hargs' := Tel.arguments_subst (instantiatedTel ms.tel (ss ++ [τ]) es) ws σ ρ
      rw [instantiatedTel_subst_eq hi.source, hargs, Option.map_some] at hargs'
      simp only [List.map_append, List.map_cons, List.map_nil] at hargs'
      exact .C_Meth (subst_value hv hA hT hstore ρ ht.images hf) hc hmeth hn hs'
        (by simpa only [List.map_append, List.map_cons, List.map_nil, substTyValues, Ty.bind] using ht.images.signature hi)
        (ht.images.methodRows hi.rows hr) hargs' (subst_values hvs hA hT hstore ρ ht.images hf) (ht.images.annotation ha)
    | .C_External (ts := ts) hd hw ha hargs =>
      have hh := subst_telArgs hargs hA hT hstore ρ ht.images hf
      have he := instantiatedTel_subst_eq hw.annotation.wf ts [] σ
      simp only [List.map_nil] at he
      change Tel.bind (valEnv σ) (Tel.bind (typeEnv ts) _) = _ at he
      rw [he] at hh
      exact .C_External hd hw (ha.map hw _) hh
    | .C_IssuePathBases b sg hb hk ho hp hr he =>
      rw [Eff.subst_values_single]
      exact .C_IssuePathBases b sg hb hk ho hp hr he
    | .C_CheckAt (bases := bases) hc =>
      have hh := subst_at_call hc hA hT hstore ρ ht.images hf
      rw [Eff.subst_values_empty]
      cases bases <;> simpa [Comp.subst, substTyValues, Ty.bind, Ty.rawBind, rawBindTys,
        Ty.norm, Ty.normTys, valEnv, RangeIx.inst_nil] using
        (HasTypeCQ.C_CheckAt (R := R.map (substTyValues σ)) (Δ := L') hh)
    | .C_Sub hm hl hc hw hs hd =>
      exact .C_Sub (subst_comp hm hA hT hstore ρ ht hL hf) (hl.bind (valEnv σ) (ht.transport hf))
        (hc.bind (valEnv σ)) (ht.wf hw hs) (ht.images.sorted hs) (hd.bind_values ht.declaration)
    | .C_Eff hm hc => exact .C_Eff (subst_comp hm hA hT hstore ρ ht hL hf) (hc.bind (valEnv σ))
    | .C_Let (a := x) hm hb hd =>
      refine .C_Let (subst_comp hm hA hT hstore ρ ht hL hf) ?_ (hd.bind_values ht.declaration)
      have hb' := subst_comp hb hA hT hstore (upLocalSubst 1 ρ) (by
        have hh := ht.upValue hA hstore x
        simpa only [Option.map_map, Function.comp_def, Ty.bind_shiftV_values,
          List.map_cons, List.map_nil, bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil,
          List.nil_append, List.cons_append, List.length_cons, List.length_nil, Nat.zero_add, liftMany_one] using hh) (hL.extend hstore none) (ht.images.conditions_params hf [x])
      simpa only [List.length_cons, List.length_nil, Nat.zero_add, List.map_cons, List.map_nil,
        bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.nil_append,
        List.cons_append, liftMany_one, Option.map_map, Function.comp_def,
        Ty.bind_shiftV_values, Eff.bind_shiftV_values, Option.map_none, localExtend] using hb'
  private theorem subst_arms {P B store Q C Γ Φ R obs arms a b e L}
      (h : HasTypeArmsQ P B store Q C Γ Φ R obs arms a b e L)
      (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : StoreTy.WF store) {Δ Ξ σ L'} (ρ : Nat → LocalRef)
      (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
      (hL : LocalSubstOk store L σ ρ L')
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeArmsQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (obs.bind (termBind? (valEnv σ).values)) (Arm.substList σ arms ρ)
        (substTyValues σ a) (substTyValues σ b) (substEffValues σ e) L' := by
    match h with
    | .nil ha => exact .nil (ht.images.annotation ha)
    | .plain (δ := δ) (alts := alts) (links := links) hp hvf hfw hw hb hs =>
      have hw' := hw.bind_paths ht.images.values ht.images.references ht.images.declaration
      have heq := fieldFacts_bind hvf hw ht.images.values ht.images.references
      have heq' : (fieldFacts δ.length obs links).map (predBind (valEnv (upSubst δ.length σ)).values) =
          fieldFacts δ.length (obs.bind (termBind? (valEnv σ).values)) links := by
        rw [valEnv_upSubst]
        exact heq
      rw [pathFacts_append] at hw
      have hmf := Entails.extend_conditions hf (pathFacts_bind hw.left ht.images.values ht.images.references)
      have hef := Entails.extend_conditions hf (pathFacts_bind hw.right ht.images.values ht.images.references)
      have htm := ht.add_conditions (pathFacts (obs.bind (termBind? (valEnv σ).values)) (matchedTests alts)) hA hstore
      have hte := ht.add_conditions (pathFacts (obs.bind (termBind? (valEnv σ).values)) (excludedTests alts)) hA hstore
      have hparams := htm.params hA hstore δ
      have hfw' : FactsWF P C (bindParams Δ (δ.map (substTyValues σ)))
          (fieldFacts δ.length (obs.bind (termBind? (valEnv σ).values)) links) := by
        rw [←heq']
        intro p hp
        obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
        exact (hfw q hq).map hparams.images.values hparams.images.references hparams.images.declaration
      have hparamsF := hparams.add_conditions (fieldFacts δ.length (obs.bind (termBind? (valEnv σ).values)) links) hA hstore
      have hconds := Entails.extend_conditions (htm.images.conditions_params hmf δ) heq'
      refine .plain (hp.subst_values σ) (by simpa only [List.length_map] using hvf)
        (by simpa only [List.length_map] using hfw') hw' ?_ (subst_arms hs hA hT hstore ρ hte hL hef)
      have hh := subst_comp hb hA hT hstore (upLocalSubst δ.length ρ)
        (by simpa only [SubstOk,Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using hparamsF)
        (hL.localExtend hstore δ.length) hconds
      simpa only [List.length_map,Option.map_map,Function.comp_def,
        Ty.bind_shiftV_values,Eff.bind_shiftV_values,hp.2.1,List.cons_append,List.nil_append] using hh
    | .guarded (δ := δ) (alts := alts) (p := p) (links := links) hp hvf hfw hw hgp hg hb hs =>
      have hw' := hw.bind_paths ht.images.values ht.images.references ht.images.declaration
      have heq := fieldFacts_bind hvf hw ht.images.values ht.images.references
      have heq' : (fieldFacts δ.length obs links).map (predBind (valEnv (upSubst δ.length σ)).values) =
          fieldFacts δ.length (obs.bind (termBind? (valEnv σ).values)) links := by
        rw [valEnv_upSubst]
        exact heq
      rw [pathFacts_append] at hw
      have hmf := Entails.extend_conditions hf (pathFacts_bind hw.left ht.images.values ht.images.references)
      have htm := ht.add_conditions (pathFacts (obs.bind (termBind? (valEnv σ).values)) (matchedTests alts)) hA hstore
      have hparams := htm.params hA hstore δ
      have hfw' : FactsWF P C (bindParams Δ (δ.map (substTyValues σ)))
          (fieldFacts δ.length (obs.bind (termBind? (valEnv σ).values)) links) := by
        rw [←heq']
        intro p hp
        obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
        exact (hfw q hq).map hparams.images.values hparams.images.references hparams.images.declaration
      have hparamsF := hparams.add_conditions (fieldFacts δ.length (obs.bind (termBind? (valEnv σ).values)) links) hA hstore
      have hguard := hparamsF.hide hA hstore (.refl _) none
      have hgAnn := hguard.images.raw_bool_annotation hgp
      have hconds := Entails.extend_conditions (htm.images.conditions_params hmf δ) heq'
      refine .guarded (hp.subst_values σ) (by simpa only [List.length_map] using hvf)
        (by simpa only [List.length_map] using hfw') hw' hgAnn ?_ ?_ (subst_arms hs hA hT hstore ρ ht hL hf)
      · have hh := subst_comp hg hA hT hstore (upLocalSubst δ.length ρ) hguard
          (hL.localExtend hstore δ.length) (fun p hp => (hconds p hp).hideConts)
        have he : substTyValues (upSubst δ.length σ) (.refined (.base .boolean) p) =
            (Ty.refined (.base .boolean) (predBind (upValues (valEnv (upSubst δ.length σ)).values) p)).norm := by
          simp only [substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Ty.norm_idem]
        rw [he,substEffValues_empty] at hh
        have hh' := HasTypeCQ.C_Sub hh (.convert (Ty.norm_idem _)) (Eff.Covers.refl _ _ _)
          hgAnn.wf hgAnn.sorted hgAnn.declared
        simpa only [List.length_map,Option.map_none,substEffValues_empty,hp.2.1] using hh'
      · have hconds' := Entails.extend_conditions hconds
          (added := [p.open (.boolean true)])
          (added' := [(predBind (upValues (valEnv (upSubst δ.length σ)).values) p).open (.boolean true)])
          (by
            simp only [List.map_cons,List.map_nil,List.cons.injEq,and_true]
            exact predBind_open_of_some _ p (.boolean true) (.boolean true) rfl)
        have hh := subst_comp hb hA hT hstore (upLocalSubst δ.length ρ)
          (by simpa only [SubstOk,Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using
            hparamsF.add_conditions [(predBind (upValues (valEnv (upSubst δ.length σ)).values) p).open (.boolean true)] hA hstore)
          (hL.localExtend hstore δ.length) hconds'
        simpa only [List.length_map,Option.map_map,Function.comp_def,
          Ty.bind_shiftV_values,Eff.bind_shiftV_values,hp.2.1,List.cons_append,List.nil_append] using hh
  private theorem subst_clauses {P B store Q C Γ Φ R eb cs t e L}
      (h : HasTypeClausesQ P B store Q C Γ Φ R eb cs t e L)
      (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : store.WF)
      {Δ Ξ σ L'} (ρ : Nat → LocalRef)
      (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
      (hL : LocalSubstOk store L σ ρ L')
      (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p)) :
      HasTypeClausesQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (substEffValues σ eb)
        (Clause.substList σ cs ρ) (substTyValues σ t) (substEffValues σ e) L' := by
    match h with
    | .nil => exact .nil
    | .cons (sg := sg) hc hn hN hK hw hb hs =>
      refine .cons (hc.subst_values σ) hn hN hK hw ?_ (subst_clauses hs hA hT hstore ρ ht hL hf)
      have hx := subst_comp (L' := []) hb hA hT hstore.hide (upLocalSubst (sg.params.length+1) ρ)
        (by simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values,substTyValues_shiftEAt] using
          ht.handler_clause ⟨hA,hT⟩ hstore sg hw t e)
        (.empty _ _ _ _) (ht.handler_conditions ⟨hA,hT⟩ hstore sg hw t e hf)
      simpa only [Clause.substList,Comp.subst,hN,hK,Ty.bind_shiftV_values,Eff.bind_shiftV_values,
        substTyValues_shiftEAt,substEffValues_shiftEAt,Option.map_map,Function.comp_def] using hx
  private theorem subst_failure {P B store Q C Γ Φ E R cs t e L}
      (h : HasFailureClause P B store Q C Γ Φ E R cs t e L)
      (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : store.WF)
      {Δ Ξ σ L'} (ρ : Nat → LocalRef)
      (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
      (_hL : LocalSubstOk store L σ ρ L')
      (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p)) :
      HasFailureClause P B store Q C Δ Ξ (substTyValues σ E) (R.map (substTyValues σ))
        (Clause.substList σ cs ρ) (substTyValues σ t) (substEffValues σ e) L' := by
    match h with
    | .one ha hb he hm =>
      refine .one (ht.images.annotation ha) (ht.images.annotation hb)
        (by simpa only [List.map_cons,List.map_nil] using ht.images.rowAnnotations he) ?_
      have hx := subst_comp (L' := []) hm hA hT hstore.hide (upLocalSubst 2 ρ)
        (by simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values,substTyValues_shiftEAt] using
          ht.handler_failure ⟨hA,hT⟩ hstore E)
        (.empty _ _ _ _) (ht.failure_conditions ⟨hA,hT⟩ hstore E hf)
      simpa only [Clause.substList,Comp.subst,Ty.bind_shiftV_values,Eff.bind_shiftV_values,
        substTyValues_shiftEAt,substEffValues_shiftEAt,Option.map_map,Function.comp_def] using hx
  private theorem subst_telArgs {P B store Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
      (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : store.WF) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeTelArgsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (Tel.bind (valEnv σ) t)
        (substTyValues σ a) (substEffValues σ e) := by
    match h with
    | .done ha => exact .done (ht.telAnnotation ha)
    | .param (rest := rest) (v := v) (vs := vs) ha hv hs =>
      apply HasTypeTelArgsQ.param (ht.annotation ha) (subst_value hv hA hT hstore ρ ht hf)
      change HasTypeTelArgsQ P B store Q C Δ Ξ (Val.substList σ vs ρ)
        (Tel.bind (Tel.argumentsEnv (v.subst σ ρ)) (Tel.bind (valEnv σ).up rest)) _ _
      rw [← valEnv_upSubst_one, Tel.open_subst]
      exact subst_telArgs hs hA hT hstore ρ ht hf

  private theorem subst_telBody {P B store Q C Γ Φ t body}
      (h : TelBodyTy P B store Q C Γ Φ t body)
      (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hw : store.WF) (ρ : Nat → LocalRef)
      {Δ Ξ σ} (ht : ReturnFreeImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      TelBodyTy P B store Q C Δ Ξ (Tel.bind (valEnv σ) t)
        (body.subst (upSubst (telBinders t) σ) (upLocalSubst (telBinders t) ρ)) := by
    match h with
    | .done (a := a) hb =>
      have hx : SubstOk P B store Q C Γ Φ Δ Ξ (some (substTyValues σ a)) σ := ht _
      have hh := subst_comp (L' := []) hb hA hT hw ρ hx (.empty _ _ _ _) hf
      simpa only [←substTyValues_eq_bind, ←substEffValues_eq_bind,Tel.bind_done,telBinders,upSubst_zero,upLocalSubst_zero] using TelBodyTy.done hh
    | .param (a := a) (rest := rest) hb =>
      have hh := subst_telBody hb hA hT hw (upLocalSubst 1 ρ) (ht.up hA hw a) (by
        have hx := ((ht none).transport (Φ := Φ) hf).up a
        intro p hp
        simpa only [←valEnv_upSubst_one, ←substTyValues_eq_bind] using hx.facts p (List.mem_append_right _ hp))
      rw [Tel.bind_param]
      apply TelBodyTy.param
      simpa only [←substTyValues_eq_bind, valEnv_upSubst_one, telBinders, upSubst_add, upLocalSubst_add,
        Nat.add_comm 1] using hh

  private theorem subst_at_call {P B store Q C Γ Φ kind name shape bases pattern input index}
      (h : AtCallAdmissible P B store Q C Γ Φ kind name shape bases pattern input index)
      (hA : Builtins.ValueAssumptions P B) (hT : Builtins.TypeAssumptions P B) (hstore : store.WF) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      AtCallAdmissible P B store Q C Δ Ξ kind name
        {shape with errorType := substTyValues σ shape.errorType}
        (match bases with | none => none | some b => some (b.subst σ ρ))
        (pattern.subst σ ρ) (input.subst σ ρ) index := by
    match h with
    | .mk (inputTy := inputTy) hs hk hb hp hty hv hw hi =>
      have hb' := fun b (he : bases = some b) => subst_value (hb b he) hA hT hstore ρ ht hf
      have he : {shape with errorType := substTyValues σ shape.errorType} = shape := by
        have hx : substTyValues σ shape.errorType = shape.errorType := by
          rw [hs.errorType_eq]; rfl
        simp only [hx]
      rw [he]
      refine AtCallAdmissible.mk (inputTy := inputTy) hs hk ?_ (subst_value hp hA hT hstore ρ ht hf) hty ?_ hw hi
      · intro v he
        cases bases with
        | none => cases he
        | some b => cases he; exact hb' b rfl
      · have hv' := subst_value hv hA hT hstore ρ ht hf
        rcases hty with ⟨rfl, hy⟩ | hy
        · exact hv'
        · simpa only [substTyValues_norm_source, Ty.subst_values_of_wf_zero hy.2.1] using hv'
    | .text (inputTy := inputTy) hs hk hb hp hty hv hw hi =>
      have hb' := fun b (he : bases = some b) => subst_value (hb b he) hA hT hstore ρ ht hf
      have he : {shape with errorType := substTyValues σ shape.errorType} = shape := by
        have hx : substTyValues σ shape.errorType = shape.errorType := by
          rw [hs.errorType_eq]; rfl
        simp only [hx]
      rw [he]
      refine AtCallAdmissible.text (inputTy := inputTy) hs hk ?_ (subst_value hp hA hT hstore ρ ht hf) hty ?_ hw hi
      · intro v he
        cases bases with
        | none => cases he
        | some b => cases he; exact hb' b rfl
      · have hv' := subst_value hv hA hT hstore ρ ht hf
        rcases hty with ⟨rfl, hy⟩ | hy
        · exact hv'
        · simpa only [substTyValues_norm_source, Ty.subst_values_of_wf_zero hy.2.1] using hv'


end

theorem HasTypeVQ.subst {P B store Q C Γ Φ v a Δ Ξ R σ}
    (h : HasTypeVQ P B store Q C Γ Φ v a)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) :=
  subst_value h hA.toValueAssumptions hA.toTypeAssumptions hstore ρ ht.images hf

theorem HasTypeVsQ.subst {P B store Q C Γ Φ vs as Δ Ξ R σ}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (as.map (substTyValues σ)) :=
  subst_values h hA.toValueAssumptions hA.toTypeAssumptions hstore ρ ht.images hf

theorem HasTypeEachQ.subst {P B store Q C Γ Φ vs a Δ Ξ R σ}
    (h : HasTypeEachQ P B store Q C Γ Φ vs a)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeEachQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (substTyValues σ a) :=
  subst_each h hA.toValueAssumptions hA.toTypeAssumptions hstore ρ ht.images hf

theorem HasTypeCQ.subst {P B store Q C Γ Φ R m a e L L' Δ Ξ σ}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L σ ρ L') :
    HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
      (substTyValues σ a) (substEffValues σ e) L' := subst_comp h hA.toValueAssumptions hA.toTypeAssumptions hstore ρ ht hL hf

theorem HasTypeTelArgsQ.subst {P B store Q C Γ Φ vs t a e Δ Ξ R0 σ}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeTelArgsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (Tel.bind (valEnv σ) t)
      (substTyValues σ a) (substEffValues σ e) :=
  subst_telArgs h hA.toValueAssumptions hA.toTypeAssumptions hstore ρ ht.images hf

theorem HasTypeArmsQ.subst {P B store Q C Γ Φ R obs arms a b e L L' Δ Ξ σ}
    (h : HasTypeArmsQ P B store Q C Γ Φ R obs arms a b e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L σ ρ L') :
    HasTypeArmsQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (obs.bind (termBind? (valEnv σ).values)) (Arm.substList σ arms ρ)
      (substTyValues σ a) (substTyValues σ b) (substEffValues σ e) L' :=
  subst_arms h hA.toValueAssumptions hA.toTypeAssumptions hstore ρ ht hL hf

/-- 本体のreturn契約はTelの終端で決まる。像は継続場所に依存しない。 -/
theorem TelBodyTy.subst {P B Ψ Q C Γ Φ t body Δ Ξ ν}
    (h : TelBodyTy P B Ψ Q C Γ Φ t body) (hA : Builtins.SubstitutionAssumptions P B)
    (hw : Ψ.WF) (ht : ∀ R0, SubstOk P B Ψ Q C Γ Φ Δ Ξ R0 ν)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv ν).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    TelBodyTy P B Ψ Q C Δ Ξ (Tel.bind (valEnv ν) t)
      (body.subst (upSubst (telBinders t) ν) (upLocalSubst (telBinders t) ρ)) :=
  subst_telBody h hA.toValueAssumptions hA.toTypeAssumptions hw ρ ht hf

/-- None の束縛では新しい像や事実を仮定せず、親の移送を extendNone する。 -/
theorem HasTypeClausesQ.subst {P B store Q C Γ Φ R eb cs t e L L' Δ Ξ σ}
    (h : HasTypeClausesQ P B store Q C Γ Φ R eb cs t e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L σ ρ L') :
    HasTypeClausesQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (substEffValues σ eb)
      (Clause.substList σ cs ρ) (substTyValues σ t) (substEffValues σ e) L' :=
  subst_clauses h hA.toValueAssumptions hA.toTypeAssumptions hw ρ ht hL hf

theorem HasFailureClause.subst {P B store Q C Γ Φ E R cs t e L L' Δ Ξ σ}
    (h : HasFailureClause P B store Q C Γ Φ E R cs t e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L σ ρ L') :
    HasFailureClause P B store Q C Δ Ξ (substTyValues σ E) (R.map (substTyValues σ))
      (Clause.substList σ cs ρ) (substTyValues σ t) (substEffValues σ e) L' :=
  subst_failure h hA.toValueAssumptions hA.toTypeAssumptions hw ρ ht hL hf

theorem SubstOk.transport_extendNone {P B store Q C Γ Φ Δ Ξ R σ}
    (h : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
    Transport (valEnv (upSubst 1 σ)) Γ.extendNone (Φ.map Pred.lift)
      Δ.extendNone (Ξ.map Pred.lift) := by
  rw [valEnv_upSubst_one]
  exact (h.transport hf).extendNone

theorem HasTypeVQ.subst_under_none {P B store Q C Γ Φ v a Δ Ξ R σ}
    (h : HasTypeVQ P B store Q C Γ.extendNone (Φ.map Pred.lift) v a)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (v.subst (upSubst 1 σ) (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) :=
  subst_value h hA.toValueAssumptions hA.toTypeAssumptions hstore _ (ht.images.none hA.toValueAssumptions hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeVsQ.subst_under_none {P B store Q C Γ Φ vs as Δ Ξ R σ}
    (h : HasTypeVsQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs as)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVsQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (as.map (substTyValues (upSubst 1 σ))) :=
  subst_values h hA.toValueAssumptions hA.toTypeAssumptions hstore _ (ht.images.none hA.toValueAssumptions hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeEachQ.subst_under_none {P B store Q C Γ Φ vs a Δ Ξ R σ}
    (h : HasTypeEachQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs a)
    (hA : Builtins.SubstitutionAssumptions P B)
    (hstore : StoreTy.WF store)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeEachQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) :=
  subst_each h hA.toValueAssumptions hA.toTypeAssumptions hstore _ (ht.images.none hA.toValueAssumptions hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeCQ.subst_under_none {P B store Q C Γ Φ m a e L L' Δ Ξ σ} {R : Option Ty}
    (h : HasTypeCQ P B store Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) m a e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L (upSubst 1 σ) (upLocalSubst 1 ρ) L') :
    HasTypeCQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      ((R.map (substTyValues σ)).map (Ty.shiftV 1 0))
      (m.subst (upSubst 1 σ) (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) a) (substEffValues (upSubst 1 σ) e) L' := by
  have hh := subst_comp h hA.toValueAssumptions hA.toTypeAssumptions hstore _ (by
    have hx := ht.extendNone hA.toValueAssumptions hstore
    simpa only [Option.map_map, Function.comp_def, Ty.bind_shiftV_values] using hx) hL (fun p hp =>
      Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))
  simpa only [Option.map_map, Function.comp_def, Ty.bind_shiftV_values] using hh

theorem HasTypeTelArgsQ.subst_under_none {P B store Q C Γ Φ vs t a e Δ Ξ R0 σ}
    (h : HasTypeTelArgsQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs t a e)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeTelArgsQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (Tel.bind (valEnv (upSubst 1 σ)) t)
      (substTyValues (upSubst 1 σ) a) (substEffValues (upSubst 1 σ) e) :=
  subst_telArgs h hA.toValueAssumptions hA.toTypeAssumptions hstore _ (ht.images.none hA.toValueAssumptions hstore) (fun p hp =>
    Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp))

theorem HasTypeArmsQ.subst_under_none {P B store Q C Γ Φ obs cs a t e L L' Δ Ξ σ} {R : Option Ty}
    (h : HasTypeArmsQ P B store Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) obs cs a t e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L (upSubst 1 σ) (upLocalSubst 1 ρ) L') :
    HasTypeArmsQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      ((R.map (substTyValues σ)).map (Ty.shiftV 1 0))
      (obs.bind (termBind? (valEnv (upSubst 1 σ)).values)) (Arm.substList (upSubst 1 σ) cs (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) a) (substTyValues (upSubst 1 σ) t) (substEffValues (upSubst 1 σ) e) L' := by
  have hh := h.subst hA hw (by
    simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using ht.extendNone hA.toValueAssumptions hw)
    (fun p hp => Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp)) _ hL
  simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using hh

theorem HasTypeClausesQ.subst_under_none {P B store Q C Γ Φ cs eb t e L L' Δ Ξ σ} {R : Option Ty}
    (h : HasTypeClausesQ P B store Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0)) eb cs t e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L (upSubst 1 σ) (upLocalSubst 1 ρ) L') :
    HasTypeClausesQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      ((R.map (substTyValues σ)).map (Ty.shiftV 1 0)) (substEffValues (upSubst 1 σ) eb)
      (Clause.substList (upSubst 1 σ) cs (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) t) (substEffValues (upSubst 1 σ) e) L' := by
  have hh := h.subst hA hw (by
    simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using ht.extendNone hA.toValueAssumptions hw)
    (fun p hp => Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp)) _ hL
  simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using hh

theorem HasFailureClause.subst_under_none {P B store Q C Γ Φ E cs t e L L' Δ Ξ σ} {R : Option Ty}
    (h : HasFailureClause P B store Q C Γ.extendNone (Φ.map Pred.lift) E (R.map (Ty.shiftV 1 0)) cs t e L)
    (hA : Builtins.SubstitutionAssumptions P B) (hw : store.WF)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ (R.map (substTyValues σ)) σ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef) (hL : LocalSubstOk store L (upSubst 1 σ) (upLocalSubst 1 ρ) L') :
    HasFailureClause P B store Q C Δ.extendNone (Ξ.map Pred.lift) (substTyValues (upSubst 1 σ) E)
      ((R.map (substTyValues σ)).map (Ty.shiftV 1 0)) (Clause.substList (upSubst 1 σ) cs (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) t) (substEffValues (upSubst 1 σ) e) L' := by
  have hh := h.subst hA hw (by
    simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using ht.extendNone hA.toValueAssumptions hw)
    (fun p hp => Transport.facts (ht.transport_extendNone hf) p (List.mem_append_right _ hp)) _ hL
  simpa only [Option.map_map,Function.comp_def,Ty.bind_shiftV_values] using hh

theorem SubstOk.signature {P B Ψ Q C Γ Φ Δ Ξ R ν t ks ts es}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R ν)
    (hi : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Δ t ks (ts.map (substTyValues ν)) (es.map (substEffValues ν)) := h.images.signature hi

theorem SubstOk.methodRows {P B Ψ Q C Γ Φ Δ Ξ R ν ms es}
    (h : SubstOk P B Ψ Q C Γ Φ Δ Ξ R ν)
    (hr : RowAnnotations P C Γ es) (ha : MethodRowsAdmissible C Γ.length Q ms es) :
    MethodRowsAdmissible C Δ.length Q ms (es.map (substEffValues ν)) := h.images.methodRows hr ha

end Benitoite.Release.Refinement
