import Benitoite.Release.Refinement.TypingStore

/-!
# 構文の文脈の narrowing

部分型は置き換える束縛の外側で検査し、後続の値・None・経路条件の位置を保つ。
-/
namespace Benitoite.Release.Refinement

variable {P : Program}

set_option maxRecDepth 4096
set_option maxHeartbeats 2000000


/-- 継続の型の位置は、通常値の部分型による置換と区別して同じ型を保つ。 -/
def Ctx.ContMap (Γ Δ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ¬ a.Ordinary → Δ[i]? = some (some a)

theorem Ctx.ContMap.params {Γ Δ} (h : Ctx.ContMap Γ Δ) (ps : List Ty) :
    Ctx.ContMap (bindParams Γ ps) (bindParams Δ ps) := by
  intro i a hi ho
  by_cases hil : i < ps.length
  · rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi ⊢
    exact hi
  · rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi ⊢
    simp only [List.length_map, List.length_reverse, List.getElem?_map] at hi ⊢
    cases hu : Γ[i-ps.length]? with
    | none => simp [hu] at hi
    | some u => cases u with
      | none => simp [hu] at hi
      | some b =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        rw [h _ _ hu (fun hb => ho ((Ty.ordinary_shiftV _ _ _).mpr hb))]
        rfl

theorem Ctx.ContMap.none {Γ Δ} (h : Ctx.ContMap Γ Δ) : Ctx.ContMap Γ.extendNone Δ.extendNone := by
  intro i a hi ho
  cases i with
  | zero => simp [Ctx.extendNone] at hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi ⊢
    cases hu : Γ[i]? with
    | none => simp [hu] at hi
    | some u => cases u with
      | none => simp [hu] at hi
      | some b =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        rw [h _ _ hu (fun hb => ho ((Ty.ordinary_shiftV _ _ _).mpr hb))]
        rfl

private def contView : Ty → Option (Ty × Ty × Eff)
  | .cont b t e => some (b,t,e)
  | .refined a _ => contView a
  | _ => none

private theorem contView_none (a : Ty) : contView a = none ↔ a.NotContCore := by
  cases a <;> simp [contView, Ty.NotContCore, Ty.core]
  case refined a p => exact contView_none a

private theorem contView_core (a : Ty) : contView a.core = contView a := by
  cases a <;> simp only [Ty.core, contView]
  case refined a p => exact contView_core a

private theorem contView_norm_refined (a : Ty) (p : Pred) :
    contView (Ty.refined a p).norm = contView a.norm := by
  rw [←contView_core, Ty.core_norm, Ty.core, ←Ty.core_norm, contView_core]

private theorem contView_foldFn (t : Tel) : contView (Ty.foldFn t) = none := by
  unfold Ty.foldFn
  split <;> rfl

private theorem contView_le {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) : contView a.norm = contView b.norm := by
  match h with
  | .refl => rfl
  | .trans h₁ h₂ => exact (contView_le h₁).trans (contView_le h₂)
  | .refine h _ _ _ => simpa only [contView_norm_refined] using contView_le h
  | .forget | .introduce .. => simp only [contView_norm_refined]
  | .convert he => exact congrArg contView he
  | .dependentFn .. => simp only [Ty.norm, contView_foldFn]
  | .data .. | .fn_effect .. | .list .. | .lazy .. | .map_value ..
  | .scoped .. | .scoped_forget => rfl

private theorem contView_wf {nr nt nv a b t e} (hw : a.WF nr nt nv)
    (h : contView a = some (b,t,e)) : a = .cont b t e := by
  cases a <;> simp only [contView] at h <;> try cases h
  case cont => rfl
  case refined a p =>
    have hn := (contView_none a).mpr hw.2.2
    rw [hn] at h
    cases h
/-- 同じ生の束縛、または正規形の等号と元の型へ戻す注釈を持つ束縛。 -/
private def ContImages (P : Program) (C : List TParam) (Γ Δ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ¬a.Ordinary →
    ∃ a', Δ[i]? = some (some a') ∧ a'.norm = a.norm ∧
      (a' = a ∨ ∃ b t e, a' = .cont b t e ∧ Ty.Annotation P C Δ a)

private theorem ContImages.params {P C Γ Δ} (h : ContImages P C Γ Δ) (ps : List Ty) :
    ContImages P C (bindParams Γ ps) (bindParams Δ ps) := by
  intro i a hi ho
  by_cases hil : i < ps.length
  · exact ⟨a, by rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi ⊢; exact hi,
      rfl, Or.inl rfl⟩
  · rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi ⊢
    simp only [List.length_map, List.length_reverse, List.getElem?_map] at hi
    obtain ⟨u,hu,he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some b =>
      cases he
      obtain ⟨b',hb,hn,hann⟩ := h _ _ hu (fun hh => ho ((Ty.ordinary_shiftV _ _ _).mpr hh))
      refine ⟨b'.shiftV ps.length 0, by simp only [List.length_map, List.length_reverse, List.getElem?_map, hb, Option.map_some], ?_, ?_⟩
      · simpa only [Ty.norm_shiftV] using congrArg (Ty.shiftV ps.length 0) hn
      · rcases hann with he | ha
        · exact Or.inl (congrArg (Ty.shiftV ps.length 0) he)
        · obtain ⟨b,t,e,he,ha⟩ := ha
          exact Or.inr ⟨b.shiftV ps.length 0,t.shiftV ps.length 0,Eff.shiftV ps.length 0 e,
            by rw [he]; rfl,(ShiftMap.outer Δ ps).annotation ha⟩

private theorem ContImages.none {P C Γ Δ} (h : ContImages P C Γ Δ) :
    ContImages P C Γ.extendNone Δ.extendNone := by
  intro i a hi ho
  cases i with
  | zero => simp [Ctx.extendNone] at hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi ⊢
    obtain ⟨u,hu,he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some b =>
      cases he
      obtain ⟨b',hb,hn,hann⟩ := h _ _ hu (fun hh => ho ((Ty.ordinary_shiftV _ _ _).mpr hh))
      refine ⟨b'.shiftV 1 0, by simp only [hb, Option.map_some], ?_, ?_⟩
      · simpa only [Ty.norm_shiftV] using congrArg (Ty.shiftV 1 0) hn
      · rcases hann with he | ha
        · exact Or.inl (congrArg (Ty.shiftV 1 0) he)
        · obtain ⟨b,t,e,he,ha⟩ := ha
          exact Or.inr ⟨b.shiftV 1 0,t.shiftV 1 0,Eff.shiftV 1 0 e,
            by rw [he]; rfl,(ShiftMap.outerNone Δ).annotation ha⟩

private structure ContextMap (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx)
    (C : List TParam) (Γ Δ : Ctx) (Ξ : List Pred) : Prop where
  length : Δ.length = Γ.length
  continuations : ContImages P C Γ Δ
  lookup : ∀ i a, Γ[i]? = some (some a) → a.Ordinary →
    HasTypeVQ P B store Q C Δ Ξ (.var i) a

private theorem ContextMap.add_conditions {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (added : List Pred)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) :
    ContextMap P B store Q C Γ Δ (added ++ Ξ) :=
  ⟨h.length,h.continuations,fun i a hi ho => (h.lookup i a hi ho).weaken_conditions hA hw
    (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_append_right _ hp)))⟩

private theorem ContextMap.values {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) :
    Term.ImagesSorted Γ Δ (fun i => some (.var i)) := by
  intro i a sort hi ha
  obtain ⟨t, ht, hs⟩ := (h.lookup i a hi ha.ordinary).observation ha
  cases ht
  exact ⟨.var i, rfl, hs⟩

private theorem ContextMap.references {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) :
    Term.ImageReferences Γ Δ (fun i => some (.var i)) := by
  intro i a hi ho t ht
  cases ht
  exact (h.lookup i a hi ho).observation_references rfl

private theorem ContextMap.declaration {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) : DeclarationImages P C Γ Δ (fun i => some (.var i)) := by
  constructor
  · intro i a hi ho t ht
    cases ht
    exact (h.lookup i a hi ho).observation_declared rfl
  · intro i a d ts hi hd
    rw [bindDataArgs_id, Ty.dataCore_args_norm hd]
    exact (h.lookup i a hi (Ty.ordinary_of_dataCore hd)).data_observation hd rfl

private theorem ContextMap.facts {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) {p} (hp : p ∈ Γ.facts) :
    Entails (Δ.facts ++ Ξ) p := by
  obtain ⟨i,a,q,hi,hq,rfl⟩ := Ctx.mem_facts.mp hp
  exact (h.lookup i a hi (Ty.assume_ordinary hq)).assume q hq

private theorem ContextMap.transport {P B store Q C Γ Δ Ξ Φ}
    (h : ContextMap P B store Q C Γ Δ Ξ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
    Transport (SubstEnv.valuesOnly (fun i => some (.var i))) Γ Φ Δ Ξ := by
  constructor
  · exact h.values
  · exact h.references
  · intro i; simp [SubstEnv.valuesOnly]
  · intro p hp
    simp only [SubstEnv.valuesOnly, predBind_id]
    rcases List.mem_append.mp hp with hp | hp
    · exact h.facts hp
    · exact hf p hp

private theorem ContextMap.sorted {P B store Q C Γ Δ Ξ a}
    (h : ContextMap P B store Q C Γ Δ Ξ) (ha : Ty.Sorted Γ a) : a.Sorted Δ := by
  have hs := Ty.sorted_rawSubstV ha (fun i => some (.var i)) h.values h.references
  rw [Ty.rawSubstV_eq_rawBind] at hs
  change Ty.Sorted Δ (renameTy id a) at hs
  rwa [renameTy_id] at hs

private theorem ContextMap.hide {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) :
    ContextMap P B (hideBuilders store) Q C (hideConts Γ) (hideConts Δ) Ξ := by
  constructor
  · simpa only [hideConts, List.length_map] using h.length
  · intro i a hi ho
    exact False.elim (ho (hideConts_lookup.mp hi).2)
  · intro i a hi ho
    exact (h.lookup i a (hideConts_lookup.mp hi).1 ho).hide_context hA hstore (hideBuilders store) (StoreTy.preserves_hide _)

private theorem ContextMap.hideConts {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hw : store.WF) :
    ContextMap P B store Q C (hideConts Γ) (hideConts Δ) Ξ := by
  constructor
  · simpa only [Refinement.hideConts,List.length_map] using h.length
  · intro i a hi ho
    exact False.elim (ho (hideConts_lookup.mp hi).2)
  · intro i a hi ho
    exact (h.lookup i a (hideConts_lookup.mp hi).1 ho).hide_context hA hw store (.refl _)

private theorem ContextMap.params {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (ps : List Ty) :
    ContextMap P B store Q C (bindParams Γ ps) (bindParams Δ ps) (liftMany ps.length Ξ) := by
  constructor
  · simp only [bindParams, List.length_append, List.length_map, List.length_reverse, h.length]
  · exact h.continuations.params ps
  · intro i a hi ho
    by_cases hil : i < ps.length
    · apply HasTypeVQ.V_Var _ ho
      rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi ⊢
      exact hi
    · rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi
      simp only [List.length_map, List.length_reverse, List.getElem?_map] at hi
      cases hu : Γ[i-ps.length]? with
      | none => simp [hu] at hi
      | some u => cases u with
        | none => simp [hu] at hi
        | some u =>
          simp only [hu, Option.map_some, Option.some.injEq] at hi
          cases hi
          have ht := (h.lookup _ u hu ((Ty.ordinary_shiftV _ _ _).mp ho)).shift_values
            (store' := store) hA hstore (.refl _) (ShiftMap.outer Δ ps) (Ξ := liftMany ps.length Ξ)
            (fun p hp => .hyp (List.mem_append_right _ (by rw [liftMany_eq]; exact List.mem_map.mpr ⟨p,hp,rfl⟩)))
          simpa only [Val.rename, shiftIndex_add, Nat.sub_add_cancel (Nat.le_of_not_gt hil)] using ht

private theorem ContextMap.none {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) :
    ContextMap P B store Q C Γ.extendNone Δ.extendNone (Ξ.map Pred.lift) := by
  constructor
  · simp only [Ctx.extendNone, List.length_cons, List.length_map, h.length]
  · exact h.continuations.none
  · intro i a hi ho
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
          have ht := (h.lookup i u hu ((Ty.ordinary_shiftV _ _ _).mp ho)).shift_values
            (store' := store) hA hstore (.refl _) (ShiftMap.outerNone Δ) (Ξ := Ξ.map Pred.lift) (fun p hp => by
              change Entails _ p.lift
              exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩)))
          simpa only [Val.rename, shiftIndex_add] using ht

private theorem ContextMap.conditions_params {P B store Q C Γ Δ Ξ Φ}
    (_h : ContextMap P B store Q C Γ Δ Ξ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) (ps : List Ty) :
    ∀ p ∈ liftMany ps.length Φ, Entails ((bindParams Δ ps).facts ++ liftMany ps.length Ξ) p := by
  intro p hp
  rw [liftMany_eq] at hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  exact (hf q hq).under_params ps

private theorem ContextMap.annotation {P B store Q C Γ Δ Ξ a}
    (h : ContextMap P B store Q C Γ Δ Ξ) (ha : Ty.Annotation P C Γ a) :
    Ty.Annotation P C Δ a :=
  ⟨by simpa only [h.length] using ha.wf, h.sorted ha.sorted, ha.declared.context h.declaration⟩

private theorem ContextMap.resume {P B store Q C Γ Δ Ξ i b t e R v L}
    (hm : ContextMap P B store Q C Γ Δ Ξ) (hi : Γ[i]? = some (some (.cont b t e)))
    (hv : HasTypeVQ P B store Q C Δ Ξ v b) (hd : Ty.Declared P C Δ t) :
    HasTypeCQ P B store Q C Δ Ξ R (.resume (.var i) v) t e L := by
  obtain ⟨a',hi',hn,ha⟩ := hm.continuations _ _ hi (by simp [Ty.Ordinary, Ty.core])
  rcases ha with he | ⟨b',t',e',he,ha⟩
  · rw [he] at hi'; exact .C_Resume hi' hv hd
  · rw [he] at hi' hn
    obtain ⟨hb,ht,heff⟩ := Ty.cont.inj hn
    have hv' : HasTypeVQ P B store Q C Δ Ξ v b'.norm := hb.symm ▸ hv.V_Normal
    have hd' : Ty.Declared P C Δ t'.norm := ht.symm ▸ hd.norm
    have hh := HasTypeCQ.C_ResumeNorm (Δ := L) (R := R) hi' hv' hd'
    rw [ht,heff] at hh
    have htAnn : Ty.Annotation P C Δ t := ⟨ha.wf.2.1, ha.sorted.2.1, ha.declared.2.1⟩
    exact .C_Sub hh (.convert (Ty.norm_idem t))
      (Eff.covers_norm_right.mpr (.refl _ _ _)) htAnn.wf htAnn.sorted htAnn.declared

private theorem ContextMap.resumeNorm {P B store Q C Γ Δ Ξ i b t e R v L}
    (hm : ContextMap P B store Q C Γ Δ Ξ) (hi : Γ[i]? = some (some (.cont b t e)))
    (hv : HasTypeVQ P B store Q C Δ Ξ v b.norm) (hd : Ty.Declared P C Δ t.norm) :
    HasTypeCQ P B store Q C Δ Ξ R (.resume (.var i) v) t.norm (Eff.norm e) L := by
  obtain ⟨a',hi',hn,ha⟩ := hm.continuations _ _ hi (by simp [Ty.Ordinary, Ty.core])
  rcases ha with he | ⟨b',t',e',he,ha⟩
  · rw [he] at hi'; exact .C_ResumeNorm hi' hv hd
  · rw [he] at hi' hn
    obtain ⟨hb,ht,heff⟩ := Ty.cont.inj hn
    have hh := HasTypeCQ.C_ResumeNorm (Δ := L) (R := R) hi' (hb.symm ▸ hv) (ht.symm ▸ hd)
    simpa only [ht,heff] using hh

private theorem ContextMap.signature {P B store Q C Γ Δ Ξ t ks ts es}
    (h : ContextMap P B store Q C Γ Δ Ξ) (ht : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Δ t ks ts es :=
  ⟨ht.source, fun a ha => h.annotation (ht.types a ha), ht.kinds,
    fun e he => h.annotation (ht.rows e he), h.annotation ht.result⟩

private theorem ContextMap.shiftE {P B store Q C Γ Δ Ξ store'}
    (h : ContextMap P B store Q C Γ Δ Ξ) (extra : List TParam) :
    ContextMap P B store' Q (extra++C) (Γ.shiftE extra.length) (Δ.shiftE extra.length) Ξ := by
  constructor
  · simpa only [Ctx.shiftE,Ctx.shiftEAt,List.length_map] using h.length
  · intro i a hi ho
    simp only [Ctx.shiftE,Ctx.shiftEAt,List.getElem?_map] at hi ⊢
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u => cases u with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg,Option.map_some,Option.some.injEq] at hi
        cases hi
        obtain ⟨b',hb,he,ha⟩ := h.continuations i b hg (fun hb => ho ((Ty.ordinary_shiftTypes _ _ _).mpr hb))
        refine ⟨shiftTypes extra.length 0 b', by simp only [hb, Option.map_some], ?_, ?_⟩
        · simpa only [Ty.norm_shiftTypes] using congrArg (shiftTypes extra.length 0) he
        · rcases ha with he | ha
          · exact Or.inl (congrArg (shiftTypes extra.length 0) he)
          · obtain ⟨bin,bout,e,he,ha⟩ := ha
            exact Or.inr ⟨shiftTypes extra.length 0 bin,shiftTypes extra.length 0 bout,shiftRowsTypes extra.length 0 e,
              by rw [he]; rfl,(TypeCtxMap.shiftEAt Δ extra.length 0).annotation (by simp [Nat.add_comm]) ha⟩
  · intro i a hi ho
    simp only [Ctx.shiftE,Ctx.shiftEAt,List.getElem?_map] at hi
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u => cases u with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg,Option.map_some,Option.some.injEq] at hi
        cases hi
        exact (h.lookup i b hg ((Ty.ordinary_shiftTypes _ _ _).mp ho)).shift_types_var
          (by simp [Nat.add_comm]) (TypeCtxMap.shiftEAt Δ extra.length 0)

private theorem ContextMap.many {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (ps : List Ty) :
    ContextMap P B store Q C (Γ.extendMany ps) (Δ.extendMany ps) (liftMany ps.length Ξ) := by
  induction ps generalizing Γ Δ Ξ with
  | nil => exact h
  | cons a as ih =>
    have hh := ih (by simpa only [bindParams_single,liftMany_one,List.length_cons,List.length_nil,Nat.zero_add] using h.params hA hw [a])
    simpa only [Ctx.extendMany,List.length_cons,←liftMany_one,liftMany_add,Nat.add_comm 1] using hh

private theorem ContextMap.conditions_many {P B store Q C Γ Δ Ξ Φ}
    (h : ContextMap P B store Q C Γ Δ Ξ)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) p) (ps : List Ty) :
    ∀ p∈liftMany ps.length Φ,Entails ((Δ.extendMany ps).facts++liftMany ps.length Ξ) p := by
  induction ps generalizing Γ Δ Φ Ξ with
  | nil => exact hf
  | cons a as ih =>
    have hm : ContextMap P B store Q C (Γ.extend a) (Δ.extend a) (Ξ.map Pred.lift) := by
      simpa only [bindParams_single,liftMany_one,List.length_cons,List.length_nil,Nat.zero_add] using h.params hA hw [a]
    have hf1 : ∀ p∈Φ.map Pred.lift,Entails ((Δ.extend a).facts++Ξ.map Pred.lift) p := by
      simpa only [bindParams_single,liftMany_one,List.length_cons,List.length_nil,Nat.zero_add] using h.conditions_params hf [a]
    have hh := ih hm hf1
    simpa only [Ctx.extendMany,List.length_cons,←liftMany_one,liftMany_add,Nat.add_comm 1] using hh

private theorem ContextMap.clause {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (sg : OpSig) (t : Ty) (e : Eff) :
    ContextMap P B (hideBuilders store) Q (sg.tparams++C) (sg.context Γ t e) (sg.context Δ t e)
      (liftMany (sg.params.length+1) Ξ) := by
  have hm := (h.shiftE (store' := hideBuilders store) sg.tparams).many hA hw.hide sg.params
  have hh := hm.params hA hw.hide [sg.continuation t e]
  simpa only [OpSig.context,bindParams_single,List.length_cons,List.length_nil,Nat.zero_add,
    ←liftMany_one,liftMany_add] using hh

private theorem ContextMap.conditions_clause {P B store Q C Γ Δ Ξ Φ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) p) (sg : OpSig) (t : Ty) (e : Eff) :
    ∀ p∈liftMany (sg.params.length+1) Φ,Entails ((sg.context Δ t e).facts++liftMany (sg.params.length+1) Ξ) p := by
  have hm := h.shiftE (store' := hideBuilders store) sg.tparams
  have hf0 : ∀ p∈Φ,Entails ((Δ.shiftE sg.tparams.length).facts++Ξ) p :=
    fun p hp => (TypeCtxMap.shiftEAt Δ sg.tparams.length 0).entails (hf p hp)
  have hf1 := hm.conditions_many hA hw.hide hf0 sg.params
  have hm1 := hm.many hA hw.hide sg.params
  have hh := hm1.conditions_params hf1 [sg.continuation t e]
  simpa only [OpSig.context,bindParams_single,List.length_cons,List.length_nil,Nat.zero_add,
    ←liftMany_one,liftMany_add] using hh

private theorem ContextMap.failure {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (E : Ty) :
    ContextMap P B (hideBuilders store) Q (({} : TParam)::C) (failureContext Γ E) (failureContext Δ E) (liftMany 2 Ξ) := by
  have hm := (h.shiftE (store' := hideBuilders store) [{}]).params hA hw.hide [shiftTypes 1 0 E]
  have hh := (hm.none hA hw.hide)
  simpa only [failureContext,bindParams_single,List.length_cons,List.length_nil,Nat.zero_add,liftMany_one,
    List.singleton_append,show liftMany 2 Ξ=(Ξ.map Pred.lift).map Pred.lift from rfl] using hh

private theorem ContextMap.conditions_failure {P B store Q C Γ Δ Ξ Φ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (_hA : Builtins.ValueAssumptions P B) (_hw : store.WF)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) p) (E : Ty) :
    ∀ p∈liftMany 2 Φ,Entails ((failureContext Δ E).facts++liftMany 2 Ξ) p := by
  have hm := h.shiftE (store' := hideBuilders store) [{}]
  have hf0 : ∀ p∈Φ,Entails ((Δ.shiftE 1).facts++Ξ) p :=
    fun p hp => (TypeCtxMap.shiftEAt Δ 1 0).entails (hf p hp)
  have hh := hm.conditions_params hf0 [shiftTypes 1 0 E]
  simp only [bindParams_single,liftMany_one,List.length_cons,List.length_nil,Nat.zero_add] at hh
  intro p hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  exact (hh q hq).under_none

mutual
  private theorem context_value {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeVQ P B store Q C Δ Ξ v a := by
    match h with
    | .V_Var hi ho => exact hm.lookup _ _ hi ho
    | .V_Const hc => exact .V_Const hc
    | .V_Lam (ps := ps) hn hw hs hb hd =>
      refine .V_Lam hn (by simpa only [hm.length] using hw) (hm.sorted hs) ?_ (hd.context hm.declaration)
      exact context_comp hb hA hstore.hide ((hm.hide hA hstore).params hA hstore.hide ps)
        ((hm.hide hA hstore).conditions_params (fun p hp => (hf p hp).hideConts) ps)
    | .V_DependentLam ha hb =>
      exact .V_DependentLam (hm.annotation ha) (context_telBody hb hA hstore.hide
        (hm.hide hA hstore) (fun p hp => (hf p hp).hideConts))
    | .V_Closure ha hw hb => exact .V_Closure (hm.annotation ha) hw hb
    | .V_List he hw hs hd =>
      exact .V_List (context_each he hA hstore hm hf) (by simpa only [hm.length] using hw) (hm.sorted hs) (hd.context hm.declaration)
    | .V_Fun hd hn ha hi => exact .V_Fun hd hn (by simpa only [hm.length] using ha) (hm.signature hi)
    | .V_Prim hb hr hn ha hi => exact .V_Prim hb hr hn (by simpa only [hm.length] using ha) (hm.signature hi)
    | .V_Op ho hn ha hi => exact .V_Op ho hn ha (hm.signature hi)
    | .V_ExternalRef hd hw ha hi => exact .V_ExternalRef hd hw ha (hm.signature hi)
    | .V_ExternalHandle h td hd hc hr hn ha => exact .V_ExternalHandle h td hd hc hr hn (hm.annotation ha)
    | .V_PathBases hs => exact .V_PathBases hs
    | .V_ScopePattern hw hc hk => exact .V_ScopePattern hw hc hk
    | .V_Checked hk hc hm => exact .V_Checked hk hc hm
    | .V_CheckedRequest hk hc hv hg ht hm => exact .V_CheckedRequest hk hc hv hg ht hm
    | .V_CheckedAt hw => exact .V_CheckedAt hw
    | .V_AtError hs => exact .V_AtError hs
    | .V_Map hk hv hn hs ha hb =>
      exact .V_Map (context_each hk hA hstore hm hf)
        (context_each hv hA hstore hm hf) hn hs (hm.annotation ha) (hm.annotation hb)
    | .V_Set hv hs ha => exact .V_Set (context_each hv hA hstore hm hf) hs (hm.annotation ha)
    | .V_Dict hi hs ht hk hw htarget hv ha =>
      exact .V_Dict hi hs (fun a hm' => hm.annotation (ht a hm'))
        hk hw htarget (context_values hv hA hstore hm hf) (hm.annotation ha)
    | .V_Raise ha => exact .V_Raise ⟨by simpa only [hm.length] using ha.wf,
        hm.sorted ha.sorted, ha.declared.context hm.declaration⟩
    | .V_LocRef hl hd => exact .V_LocRef hl (hd.context hm.declaration)
    | .V_LocLazy hl hd => exact .V_LocLazy hl (hd.context hm.declaration)
    | .V_Bytes hb => exact .V_Bytes hb
    | .V_Con hc hn hk hw hv ha =>
      exact .V_Con hc hn hk hw (context_values hv hA hstore hm hf)
        ⟨by simpa only [hm.length] using ha.wf, hm.sorted ha.sorted, ha.declared.context hm.declaration⟩
    | .V_Super hv hc hmemb hd => exact .V_Super (context_value hv hA hstore hm hf) hc hmemb (hd.context hm.declaration)
    | .V_Normal hv => exact .V_Normal (context_value hv hA hstore hm hf)
    | .V_Sub hv hl hw hs hd =>
      have hl' := hl.rawBind (SubstEnv.valuesOnly (fun i => some (.var i))) (hm.transport hf)
      change Ty.LeQ P Δ Ξ (renameTy id _) (renameTy id _) at hl'
      simp only [renameTy_id] at hl'
      exact .V_Sub (context_value hv hA hstore hm hf) hl' (by simpa only [hm.length] using hw) (hm.sorted hs) (hd.context hm.declaration)
    | .V_Refine hv hi ht hs hw he hda hdp =>
      refine .V_Refine (context_value hv hA hstore hm hf) hi ht ?_ (by simpa only [hm.length] using hw) ?_ (hda.context hm.declaration) ?_
      · simpa only [upValues_id, predBind_id] using Pred.sorted_bind hs (fun i => some (.var i)) (fun _ h => h) id hm.values hm.references
      · simpa only [SubstEnv.valuesOnly, predBind_id] using (hm.transport hf).entails he
      · simpa only [Option.map_some, Ty.rawSubstV_id, upValues_id, predBind_id] using hdp.bind hm.declaration
  private theorem context_values {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeVsQ P B store Q C Δ Ξ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (context_value hv hA hstore hm hf) (context_values hs hA hstore hm hf)
  private theorem context_each {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeEachQ P B store Q C Δ Ξ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (context_value hv hA hstore hm hf) (context_each hs hA hstore hm hf)
  private theorem context_comp {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeCQ P B store Q C Δ Ξ R m a e L := by
    match h with
    | .C_BuilderLet ha hk hb hd =>
      exact .C_BuilderLet (hm.annotation ha) hk
        (context_comp hb hA hstore (hm.none hA hstore) (fun p hp => by
          obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
          exact (hf q hq).under_none)) (hd.context hm.declaration)
    | .C_BuilderOp ha hk hr hv => exact .C_BuilderOp (hm.annotation ha) hk hr (context_values hv hA hstore hm hf)
    | .C_Return hv => exact .C_Return (context_value hv hA hstore hm hf)
    | .C_DependentApp hv ht =>
      exact .C_DependentApp (context_value hv hA hstore hm hf) (context_telArgs ht hA hstore hm hf)
    | .C_App hv hs => exact .C_App (context_value hv hA hstore hm hf) (context_values hs hA hstore hm hf)
    | .C_If hv ht hm' hn =>
      refine .C_If (context_value hv hA hstore hm hf) ht ?_ ?_
      · exact context_comp hm' hA hstore
          ⟨hm.length,hm.continuations,fun i a hi ho => (hm.lookup i a hi ho).weaken_conditions hA hstore
            (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp)))⟩
          (Entails.conditions_cons hf (.hyp (List.mem_append_right _ List.mem_cons_self)))
      · exact context_comp hn hA hstore
          ⟨hm.length,hm.continuations,fun i a hi ho => (hm.lookup i a hi ho).weaken_conditions hA hstore
            (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp)))⟩
          (Entails.conditions_cons hf (.hyp (List.mem_append_right _ List.mem_cons_self)))
    | .C_Match hv ho ha hx =>
      refine .C_Match (context_value hv hA hstore hm hf) ?_ (context_arms ha hA hstore hm hf) hx
      intro t ht
      obtain ⟨hv,s,hs⟩ := ho t ht
      exact ⟨hv,s,by simpa only [termBind_id] using Term.hasSort_termBind hs _ hm.values hm.references⟩
    | .C_Lazy hb ha =>
      exact .C_Lazy (context_comp hb hA hstore.hide (hm.hide hA hstore) (fun p hp => (hf p hp).hideConts))
        ⟨by simpa only [hm.length] using ha.wf, hm.sorted ha.sorted, ha.declared.context hm.declaration⟩
    | .C_Escape hv ha =>
      exact .C_Escape (context_value hv hA hstore hm hf)
        ⟨by simpa only [hm.length] using ha.wf, hm.sorted ha.sorted, ha.declared.context hm.declaration⟩
    | .C_Use hv hr hb he => exact .C_Use (context_value hv hA hstore hm hf) hr (context_comp hb hA hstore hm hf) he
    | .C_Handle hb hc hh => exact .C_Handle (context_comp hb hA hstore hm hf) hc (context_clauses hh hA hstore hm hf)
    | .C_Handle_Fail hb hc hn hh => exact .C_Handle_Fail (context_comp hb hA hstore hm hf) hc hn (context_failure hh hA hstore hm hf)
    | .C_Resume hi hv hd =>
      exact hm.resume hi (context_value hv hA hstore hm hf) (hd.context hm.declaration)
    | .C_ResumeNorm hi hv hd =>
      exact hm.resumeNorm hi (context_value hv hA hstore hm hf) (hd.context hm.declaration)
    | .C_ResumeLNorm hl hr hv hd =>
      exact .C_ResumeLNorm hl hr (context_value hv hA hstore hm hf) (hd.context hm.declaration)
    | .C_ResumeL hl hv hd =>
      exact .C_ResumeL hl (context_value hv hA hstore hm hf) (hd.context hm.declaration)
    | .C_Meth hv hc hmeth hn hs hi hr hargs hvs ha =>
      exact .C_Meth (context_value hv hA hstore hm hf) hc hmeth hn hs (hm.signature hi)
        (by simpa only [hm.length] using hr) hargs (context_values hvs hA hstore hm hf) (hm.annotation ha)
    | .C_External hd hw ha hargs => exact .C_External hd hw ha (context_telArgs hargs hA hstore hm hf)
    | .C_IssuePathBases b sg hb hk ho hp hr he => exact .C_IssuePathBases b sg hb hk ho hp hr he
    | .C_CheckAt hc => exact .C_CheckAt (context_at_call hc hA hstore hm hf)
    | .C_Normal hb => exact .C_Normal (context_comp hb hA hstore hm hf)
    | .C_Sub ht hl hc hw hs hd =>
      have hl' := hl.rawBind (SubstEnv.valuesOnly (fun i => some (.var i))) (hm.transport hf)
      change Ty.LeQ P Δ Ξ (renameTy id _) (renameTy id _) at hl'
      simp only [renameTy_id] at hl'
      exact .C_Sub (context_comp ht hA hstore hm hf) hl' hc (by simpa only [hm.length] using hw) (hm.sorted hs) (hd.context hm.declaration)
    | .C_Eff ht hc => exact .C_Eff (context_comp ht hA hstore hm hf) hc
    | .C_Let (a := x) ht hb hd =>
      refine .C_Let (context_comp ht hA hstore hm hf) ?_ (hd.context hm.declaration)
      have hb' := context_comp hb hA hstore (hm.params hA hstore [x]) (hm.conditions_params hf [x])
      simpa only [List.length_cons, List.length_nil, Nat.zero_add, liftMany_one,
        bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.map_cons, List.map_nil,
        List.nil_append, List.cons_append] using hb'
  private theorem context_arms {P B store Q C Γ Φ R obs arms a b e L}
      (h : HasTypeArmsQ P B store Q C Γ Φ R obs arms a b e L)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeArmsQ P B store Q C Δ Ξ R obs arms a b e L := by
    match h with
    | .nil ha => exact .nil (hm.annotation ha)
    | .plain (δ := δ) (alts := alts) hp hw hb hs =>
      have hw' : FactsWF P C Δ (pathFacts obs (matchedTests alts ++ excludedTests alts)) := by
        intro p hp
        simpa only [predBind_id] using (hw p hp).map hm.values hm.references hm.declaration
      have hmf := Entails.extend_conditions hf (added := pathFacts obs (matchedTests alts)) (added' := pathFacts obs (matchedTests alts)) (by simp)
      have hef := Entails.extend_conditions hf (added := pathFacts obs (excludedTests alts)) (added' := pathFacts obs (excludedTests alts)) (by simp)
      have hmm := hm.add_conditions (pathFacts obs (matchedTests alts)) hA hstore
      have hme := hm.add_conditions (pathFacts obs (excludedTests alts)) hA hstore
      exact .plain hp hw' (context_comp hb hA hstore (hmm.params hA hstore δ)
        (hmm.conditions_params hmf δ)) (context_arms hs hA hstore hme hef)
    | .guarded (δ := δ) (alts := alts) (p := p) hp hw hgp hg hb hs =>
      have hw' : FactsWF P C Δ (pathFacts obs (matchedTests alts ++ excludedTests alts)) := by
        intro p hp
        simpa only [predBind_id] using (hw p hp).map hm.values hm.references hm.declaration
      have hmf := Entails.extend_conditions hf (added := pathFacts obs (matchedTests alts)) (added' := pathFacts obs (matchedTests alts)) (by simp)
      have hmm := hm.add_conditions (pathFacts obs (matchedTests alts)) hA hstore
      have hparams := hmm.params hA hstore δ
      have hguard := hparams.hideConts hA hstore
      have hconds := hmm.conditions_params hmf δ
      refine .guarded hp hw' (hguard.annotation hgp)
        (context_comp hg hA hstore hguard (fun p hp => (hconds p hp).hideConts)) ?_
        (context_arms hs hA hstore hm hf)
      exact context_comp hb hA hstore
        (hparams.add_conditions [p.open (.boolean true)] hA hstore)
        (Entails.conditions_cons hconds (.hyp (List.mem_append_right _ List.mem_cons_self)))
  private theorem context_clauses {P B store Q C Γ Φ R eb cs t e L}
      (h : HasTypeClausesQ P B store Q C Γ Φ R eb cs t e L)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ) (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) p) :
      HasTypeClausesQ P B store Q C Δ Ξ R eb cs t e L := by
    match h with
    | .nil => exact .nil
    | .cons (sg := sg) hc hn hN hK hw hb hs =>
      exact .cons hc hn hN hK hw (context_comp hb hA hstore.hide (hm.clause hA hstore sg t e)
        (hm.conditions_clause hA hstore hf sg t e)) (context_clauses hs hA hstore hm hf)
  private theorem context_failure {P B store Q C Γ Φ E R cs t e L}
      (h : HasFailureClause P B store Q C Γ Φ E R cs t e L)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ) (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) p) :
      HasFailureClause P B store Q C Δ Ξ E R cs t e L := by
    match h with
    | .one ha ht he hb =>
      exact .one (hm.annotation ha) (hm.annotation ht) (fun f hf => hm.annotation (he f hf))
        (context_comp hb hA hstore.hide (hm.failure hA hstore E) (hm.conditions_failure hA hstore hf E))
  private theorem context_telArgs {P B store Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeTelArgsQ P B store Q C Δ Ξ vs t a e := by
    match h with
    | .done ha => exact .done (hm.annotation ha)
    | .param ha hv ht =>
      exact .param (hm.annotation ha) (context_value hv hA hstore hm hf)
        (context_telArgs ht hA hstore hm hf)

  private theorem context_telBody {P B store Q C Γ Φ t body}
      (h : TelBodyTy P B store Q C Γ Φ t body)
      (hA : Builtins.ValueAssumptions P B) (hw : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      TelBodyTy P B store Q C Δ Ξ t body := by
    match h with
    | .done hb => exact .done (context_comp hb hA hw hm hf)
    | .param (a := a) hb =>
      exact .param (context_telBody hb hA hw (by simpa only [bindParams_single,List.length_cons,List.length_nil,Nat.zero_add,liftMany_one] using hm.params hA hw [a])
        (by simpa only [bindParams_single,List.length_cons,List.length_nil,Nat.zero_add,liftMany_one] using hm.conditions_params hf [a]))

  private theorem context_at_call {P B store Q C Γ Φ kind name shape bases pattern input index}
      (h : AtCallAdmissible P B store Q C Γ Φ kind name shape bases pattern input index)
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      AtCallAdmissible P B store Q C Δ Ξ kind name shape bases pattern input index := by
    match h with
    | .mk hs hk hb hp ht hv hw hi =>
      exact .mk hs hk (fun v he => context_value (hb v he) hA hstore hm hf)
        (context_value hp hA hstore hm hf) ht (context_value hv hA hstore hm hf) hw hi

end

/-- 外側で検査した部分型による一位置の置換と、後続の束縛の列。 -/
inductive Ctx.Narrows (P : Program) (C : List TParam) : Ctx → List Pred → Ctx → List Pred → Prop where
  | here {Γ Φ a b} : Ty.LeQ P Γ Φ a b → a.WF 0 C.length Γ.length → b.WF 0 C.length Γ.length → b.Sorted Γ → Ty.Declared P C Γ b →
      Narrows P C (Γ.extend b) (Φ.map Pred.lift) (Γ.extend a) (Φ.map Pred.lift)
  | under {Γ Φ Δ Ξ} : Narrows P C Γ Φ Δ Ξ → (a : Ty) →
      Narrows P C (Γ.extend a) (Φ.map Pred.lift) (Δ.extend a) (Ξ.map Pred.lift)
  | underNone {Γ Φ Δ Ξ} : Narrows P C Γ Φ Δ Ξ →
      Narrows P C Γ.extendNone (Φ.map Pred.lift) Δ.extendNone (Ξ.map Pred.lift)

theorem Ctx.Narrows.conditions {P C Γ Φ Δ Ξ} (h : Ctx.Narrows P C Γ Φ Δ Ξ) : Φ = Ξ := by
  induction h with
  | here _ _ _ _ _ => rfl
  | under _ _ ih | underNone _ ih => exact congrArg (List.map Pred.lift) ih

private theorem Ctx.Narrows.contextMap {P B store Q C Γ Φ Δ Ξ}
    (h : Ctx.Narrows P C Γ Φ Δ Ξ) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) : ContextMap P B store Q C Γ Δ Ξ := by
  induction h with
  | @here Γ Φ a b hl haw hw hs hd =>
    constructor
    · simp [Ctx.extend]
    · intro i t hi ho
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        have hb : ¬ b.Ordinary := fun hh => ho ((Ty.ordinary_shiftV _ _ _).mpr hh)
        cases b <;> simp at hb
        case cont bin bout eff =>
          have heq := contView_le hl
          have hav : contView a ≠ none := by
            intro hn
            have haOrd : a.NotContCore := (contView_none a).mp hn
            have hbOrd := hl.notContCore.mp haOrd
            exact hbOrd bin bout eff rfl
          obtain ⟨bin',bout',eff',hac⟩ : ∃ bin' bout' eff', a = .cont bin' bout' eff' := by
            cases hc : contView a with
            | none => exact False.elim (hav hc)
            | some triple =>
              obtain ⟨bin',bout',eff'⟩ := triple
              exact ⟨bin',bout',eff',contView_wf haw hc⟩
          rw [hac] at heq
          have heq' : (Ty.cont bin' bout' eff').norm = (Ty.cont bin bout eff).norm := by
            exact congrArg (fun x : Ty × Ty × Eff => Ty.cont x.1 x.2.1 x.2.2) (Option.some.inj heq)
          refine ⟨a.shiftV 1 0, rfl, ?_, Or.inr ⟨bin'.shiftV 1 0,bout'.shiftV 1 0,Eff.shiftV 1 0 eff', by rw [hac]; rfl, ?_⟩⟩
          · simpa only [Ty.norm_shiftV, hac] using congrArg (Ty.shiftV 1 0) heq'
          · exact (ShiftMap.outer Γ [a]).annotation ⟨hw,hs,hd⟩
        case refined core pred =>
          obtain ⟨bin,bout,eff,he⟩ := hb
          exact False.elim (hw.2.2 bin bout eff he)
      | succ i => exact ⟨_,hi,rfl,Or.inl rfl⟩
    · intro i t hi ho
      cases i with
      | zero =>
        simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
        cases hi
        have hoa : a.Ordinary :=
          (hl.notContCore.mpr (Ty.notContCore_of_wf_ordinary hw ((Ty.ordinary_shiftV _ _ _).mp ho))).ordinary
        have hv : HasTypeVQ P B store Q C (Γ.extend a) (Φ.map Pred.lift) (.var 0) (a.shiftV 1 0) :=
          .V_Var rfl ((Ty.ordinary_shiftV _ _ _).mpr hoa)
        have hm := ShiftMap.outer Γ [a]
        have hl' := hl.rawBind (renEnv (shiftIndex 1 0)) (hm.transport (Ξ := Φ.map Pred.lift) (fun p hp => by
          change Entails _ p.lift
          exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p,hp,rfl⟩))))
        change Ty.LeQ P (Γ.extend a) (Φ.map Pred.lift) (renameTy (shiftIndex 1 0) a) (renameTy (shiftIndex 1 0) b) at hl'
        rw [renameTy_shiftIndex] at hl'
        exact .V_Sub hv hl' (hm.wf hw) (hm.sorted hs) (hm.declared hd)
      | succ i =>
        exact .V_Var (by simpa only [Ctx.extend, List.getElem?_cons_succ] using hi) ho
  | under h a ih =>
    have hm := ih.params hA hstore [a]
    simpa only [List.length_cons, List.length_nil, Nat.zero_add, liftMany_one,
      bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.map_cons, List.map_nil,
      List.nil_append, List.cons_append] using hm
  | underNone h ih => exact ih.none hA hstore

theorem HasTypeVQ.narrow {P B store Q C Γ Φ v a Δ Ξ}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeVQ P B store Q C Δ Ξ v a :=
  context_value h hA hstore (hn.contextMap hA hstore) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeVsQ.narrow {P B store Q C Γ Φ vs as Δ Ξ}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeVsQ P B store Q C Δ Ξ vs as :=
  context_values h hA hstore (hn.contextMap hA hstore) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeEachQ.narrow {P B store Q C Γ Φ vs a Δ Ξ}
    (h : HasTypeEachQ P B store Q C Γ Φ vs a) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeEachQ P B store Q C Δ Ξ vs a :=
  context_each h hA hstore (hn.contextMap hA hstore) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeCQ.narrow {P B store Q C Γ Φ R m a e L Δ Ξ}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L) (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeCQ P B store Q C Δ Ξ R m a e L :=
  context_comp h hA hstore (hn.contextMap hA hstore) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem TelBodyTy.narrow {P B store Q C Γ Φ t body Δ Ξ}
    (h : TelBodyTy P B store Q C Γ Φ t body)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    TelBodyTy P B store Q C Δ Ξ t body :=
  context_telBody h hA hw (hn.contextMap hA hw) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeTelArgsQ.narrow {P B store Q C Γ Φ vs t a e Δ Ξ}
    (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e)
    (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeTelArgsQ P B store Q C Δ Ξ vs t a e :=
  context_telArgs h hA hstore (hn.contextMap hA hstore)
    (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeArmsQ.narrow {P B store Q C Γ Φ R obs arms a b e L Δ Ξ}
    (h : HasTypeArmsQ P B store Q C Γ Φ R obs arms a b e L)
    (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
    (hn : Ctx.Narrows P C Γ Φ Δ Ξ) : HasTypeArmsQ P B store Q C Δ Ξ R obs arms a b e L :=
  context_arms h hA hstore (hn.contextMap hA hstore)
    (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeClausesQ.narrow {P B store Q C Γ Φ R eb cs t e L Δ Ξ}
    (h : HasTypeClausesQ P B store Q C Γ Φ R eb cs t e L) (hA : Builtins.ValueAssumptions P B)
    (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) : HasTypeClausesQ P B store Q C Δ Ξ R eb cs t e L :=
  context_clauses h hA hstore (hn.contextMap hA hstore) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasFailureClause.narrow {P B store Q C Γ Φ E R cs t e L Δ Ξ}
    (h : HasFailureClause P B store Q C Γ Φ E R cs t e L) (hA : Builtins.ValueAssumptions P B)
    (hstore : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) : HasFailureClause P B store Q C Δ Ξ E R cs t e L :=
  context_failure h hA hstore (hn.contextMap hA hstore) (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem ImageOk.narrow {P B store Q C Γ Φ Δ Ξ R0 ν i a}
    (h : ImageOk P B store Q C Γ Φ R0 ν i a)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    ImageOk P B store Q C Δ Ξ R0 ν i a := by
  match h with
  | .ordinary ho hv => exact .ordinary ho (hv.narrow hA hw hn)
  | .contLoc he ht ha hv hl hr => exact .contLoc he ht ha hv hl hr
  | .hidden ho hc => exact .hidden ho hc
  | .contVar he hv hi =>
    obtain ⟨b,t,e,hi,heq⟩ := hi
    obtain ⟨a',hi',hn,hann⟩ := (hn.contextMap (Q := Q) hA hw).continuations _ _ hi
      (by simp [Ty.Ordinary,Ty.core])
    rcases hann with hsame | ⟨b',t',e',hshape,ha⟩
    · rw [hsame] at hi'
      exact .contVar he hv ⟨b,t,e,hi',heq⟩
    · rw [hshape] at hi' hn
      exact .contVar he hv ⟨b',t',e',hi',hn.trans heq⟩

end Benitoite.Release.Refinement
