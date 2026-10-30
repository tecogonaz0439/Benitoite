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

theorem Pred.shiftV_zero (p : Pred) (c : Nat) : p.shiftV 0 c = p := by
  simp only [Pred.shiftV, shiftIndex_zero]
  exact predBind_id p

theorem HasTypeVQ.hide_context {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (store' : StoreTy) :
    HasTypeVQ P B store' Q C (hideConts Γ) Φ v a := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    constructor
    · simp [hideConts]
    · intro i a hi ho
      simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi,ho⟩
  have ht := h.shift_values (store' := store') hm (Ξ := Φ) (fun p hp => by
    rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using ht

private theorem TypedImages.hide {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (store' : StoreTy) :
    TypedImages P B store' Q C (hideConts Γ) (hideConts Δ) Ξ σ := by
  intro i a hi ho
  exact (h i a (hideConts_lookup.mp hi).1 ho).hide_context store'

private theorem TypedImages.params {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) (ps : List Ty) :
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
          (store' := store) (ShiftMap.outer Δ (ps.map (substTyValues σ)))
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

mutual
  private theorem subst_value {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) := by
    match h with
    | .V_Var hi ho => exact ht _ _ hi ho
    | .V_Const hc => rw [substTyValues, Const.type_bind_values]; exact .V_Const hc
    | .V_Lam (ps := ps) hn hw hs hb =>
      apply HasTypeVQ.subst_lam hw hs (ht.transport hf)
      have hb' := subst_comp hb (upLocalSubst ps.length ρ)
        ((ht.hide (hideBuilders store)).params ps)
        ((ht.hide (hideBuilders store)).conditions_params
          (fun p hp => (hf p hp).hideConts) ps)
      simpa only [Option.map_some, Ty.bind_shiftV_values, Eff.bind_shiftV_values] using hb'
    | .V_List he hw hs =>
      exact .V_List (subst_each he ρ ht hf) (ht.wf hw hs) (ht.sorted hs)
    | .V_Sub hv hl hw hs hd =>
      exact .V_Sub (subst_value hv ρ ht hf) (hl.bind (valEnv σ) (ht.transport hf))
        (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .V_Refine (a := a) (t := t) (p := p) hv hi hterm hs hw he hda hdp =>
      obtain ⟨u, hu, hus⟩ := hv.observation hi
      have hut : u = t := Option.some.inj (hu.symm.trans hterm)
      subst u
      have hs' := Pred.sorted_bind hs (valEnv σ).values (fun _ h => Ty.hasSort_bind h (valEnv σ))
        (fun h => Ty.ordinary_bind h (valEnv σ) (ht.transport hf).typeImages)
        (ht.transport hf).values (ht.transport hf).references
      refine .V_Refine (subst_value hv ρ ht hf) (Ty.hasSort_bind hi (valEnv σ))
        (ht.observation hterm hus ρ) hs' (Pred.wf_of_sorted hs') ?_
        (hda.bind_values ht.declaration) (hdp.bind_values ht.declaration)
      obtain ⟨u, hu, _⟩ := Term.hasSort_bind hus _ ht.values ht.references
      have hsuccess : termBind? (valEnv σ).values t = some (termBind (valEnv σ).values t) := by
        simp only [termBind, hu, Option.getD_some]
      rw [← predBind_open_of_some _ p t _ hsuccess]
      exact (ht.transport hf).entails he
  private theorem subst_values {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeVsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (as.map (substTyValues σ)) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (subst_value hv ρ ht hf) (subst_values hs ρ ht hf)
  private theorem subst_each {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeEachQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (substTyValues σ a) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (subst_value hv ρ ht hf) (subst_each hs ρ ht hf)
  private theorem subst_comp {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) {Δ Ξ σ} (ρ : Nat → LocalRef)
      (ht : TypedImages P B store Q C Γ Δ Ξ σ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p)) :
      HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
        (substTyValues σ a) (substEffValues σ e) L := by
    match h with
    | .C_Return hv => rw [substEffValues_empty]; exact .C_Return (subst_value hv ρ ht hf)
    | .C_App hv hs =>
      have hv' := subst_value hv ρ ht hf
      rw [substTyValues, Ty.bind_fn] at hv'
      exact .C_App hv' (subst_values hs ρ ht hf)
    | .C_Sub hm hl hc hw hs hd =>
      exact .C_Sub (subst_comp hm ρ ht hf) (hl.bind (valEnv σ) (ht.transport hf))
        (hc.bind (valEnv σ)) (ht.wf hw hs) (ht.sorted hs) (hd.bind_values ht.declaration)
    | .C_Eff hm hc => exact .C_Eff (subst_comp hm ρ ht hf) (hc.bind (valEnv σ))
    | .C_Let (a := x) hm hb =>
      refine .C_Let (subst_comp hm ρ ht hf) ?_
      have hb' := subst_comp hb (upLocalSubst 1 ρ) (ht.params [x]) (ht.conditions_params hf [x])
      simpa only [List.length_cons, List.length_nil, Nat.zero_add, List.map_cons, List.map_nil,
        bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.nil_append,
        List.cons_append, liftMany_one, Option.map_map, Function.comp_def,
        Ty.bind_shiftV_values, Eff.bind_shiftV_values] using hb'
end

theorem HasTypeVQ.subst {P B store Q C Γ Φ v a Δ Ξ R σ}
    (h : HasTypeVQ P B store Q C Γ Φ v a)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVQ P B store Q C Δ Ξ (v.subst σ ρ) (substTyValues σ a) :=
  subst_value h ρ ht.images hf

theorem HasTypeVsQ.subst {P B store Q C Γ Φ vs as Δ Ξ R σ}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVsQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (as.map (substTyValues σ)) :=
  subst_values h ρ ht.images hf

theorem HasTypeEachQ.subst {P B store Q C Γ Φ vs a Δ Ξ R σ}
    (h : HasTypeEachQ P B store Q C Γ Φ vs a)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeEachQ P B store Q C Δ Ξ (Val.substList σ vs ρ) (substTyValues σ a) :=
  subst_each h ρ ht.images hf

theorem HasTypeCQ.subst {P B store Q C Γ Φ R m a e L Δ Ξ R0 σ}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeCQ P B store Q C Δ Ξ (R.map (substTyValues σ)) (m.subst σ ρ)
      (substTyValues σ a) (substEffValues σ e) L := subst_comp h ρ ht.images hf

private theorem TypedImages.none {P B store Q C Γ Δ Ξ σ}
    (h : TypedImages P B store Q C Γ Δ Ξ σ) :
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
          (store' := store) (ShiftMap.outerNone Δ) (Ξ := Ξ.map Pred.lift) (fun p hp => by
            change Entails _ p.lift
            exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))
        simpa only [upSubst, Nat.succ_lt_succ_iff, Nat.not_lt_zero, ↓reduceIte,
          Nat.add_one_sub_one, shiftIndex_add] using ht

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
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (v.subst (upSubst 1 σ) (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) :=
  subst_value h _ ht.images.none (fun p hp =>
    (ht.transport_extendNone hf).facts p (List.mem_append_right _ hp))

theorem HasTypeVsQ.subst_under_none {P B store Q C Γ Φ vs as Δ Ξ R σ}
    (h : HasTypeVsQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs as)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeVsQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (as.map (substTyValues (upSubst 1 σ))) :=
  subst_values h _ ht.images.none (fun p hp =>
    (ht.transport_extendNone hf).facts p (List.mem_append_right _ hp))

theorem HasTypeEachQ.subst_under_none {P B store Q C Γ Φ vs a Δ Ξ R σ}
    (h : HasTypeEachQ P B store Q C Γ.extendNone (Φ.map Pred.lift) vs a)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeEachQ P B store Q C Δ.extendNone (Ξ.map Pred.lift)
      (Val.substList (upSubst 1 σ) vs (upLocalSubst 1 ρ)) (substTyValues (upSubst 1 σ) a) :=
  subst_each h _ ht.images.none (fun p hp =>
    (ht.transport_extendNone hf).facts p (List.mem_append_right _ hp))

theorem HasTypeCQ.subst_under_none {P B store Q C Γ Φ R m a e L Δ Ξ R0 σ}
    (h : HasTypeCQ P B store Q C Γ.extendNone (Φ.map Pred.lift) R m a e L)
    (ht : SubstOk P B store Q C Γ Φ Δ Ξ R0 σ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (predBind (valEnv σ).values p))
    (ρ : Nat → LocalRef := LocalRef.bound) :
    HasTypeCQ P B store Q C Δ.extendNone (Ξ.map Pred.lift) (R.map (substTyValues (upSubst 1 σ)))
      (m.subst (upSubst 1 σ) (upLocalSubst 1 ρ))
      (substTyValues (upSubst 1 σ) a) (substEffValues (upSubst 1 σ) e) L :=
  subst_comp h _ ht.images.none (fun p hp =>
    (ht.transport_extendNone hf).facts p (List.mem_append_right _ hp))

end Benitoite.Release.Refinement
