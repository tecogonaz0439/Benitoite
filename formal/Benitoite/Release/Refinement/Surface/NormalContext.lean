import Benitoite.Release.Refinement.ContextNormEq

/-! # 正規化した束縛型から元の文脈への型付けの移送

通常値の参照は正規化した型で読み、継続の参照は正規化した応答型と効果を保つ。
-/
namespace Benitoite.Release.Refinement.Surface.NormalContext
noncomputable section

private def ContImages (_P : Program) (_C : TypeCtx) (Γ Δ : Ctx) : Prop :=
  ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → ¬a.Ordinary →
    ∃ a', Δ[i]? = some (some a') ∧ a'.norm = a.norm ∧
      (a' = a ∨ ∃ b t e, a' = .cont b t e ∧ a.norm = a)

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
            by rw [he]; rfl,by simpa only [Ty.norm_shiftV] using congrArg (Ty.shiftV ps.length 0) ha⟩

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
            by rw [he]; rfl,by simpa only [Ty.norm_shiftV] using congrArg (Ty.shiftV 1 0) ha⟩

private structure ContextMap (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx)
    (C : TypeCtx) (Γ Δ : Ctx) (Ξ : List Pred) : Prop where
  length : Δ.length = Γ.length
  continuations : ContImages P C Γ Δ
  lookup : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.Ordinary →
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
    obtain ⟨_, htN, heN⟩ := Ty.cont.inj ha
    simpa only [htN, heN] using hh

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
    fun e he => h.annotation (ht.rows e he), ht.rowKinds, h.annotation ht.result⟩

private theorem ContextMap.shiftE {P B store Q C Γ Δ Ξ store'}
    (h : ContextMap P B store Q C Γ Δ Ξ) (extra : TypeCtx) :
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
              by rw [he]; rfl,by simpa only [Ty.norm_shiftTypes] using congrArg (shiftTypes extra.length 0) ha⟩
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
          (by simpa only [List.nil_append, List.length_nil] using TypeParamRenaming.insert [] extra C)

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
    ContextMap P B (hideBuilders store) Q (TypeCtx.valueParam::C) (failureContext Γ E) (failureContext Δ E) (liftMany 2 Ξ) := by
  have hm := (h.shiftE (store' := hideBuilders store) [TypeCtx.valueParam]).params hA hw.hide [shiftTypes 1 0 E]
  have hh := (hm.none hA hw.hide)
  simpa only [failureContext,bindParams_single,List.length_cons,List.length_nil,Nat.zero_add,liftMany_one,
    List.singleton_append,show liftMany 2 Ξ=(Ξ.map Pred.lift).map Pred.lift from rfl] using hh

private theorem ContextMap.conditions_failure {P B store Q C Γ Δ Ξ Φ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (_hA : Builtins.ValueAssumptions P B) (_hw : store.WF)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) p) (E : Ty) :
    ∀ p∈liftMany 2 Φ,Entails ((failureContext Δ E).facts++liftMany 2 Ξ) p := by
  have hm := h.shiftE (store' := hideBuilders store) [TypeCtx.valueParam]
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
    | .V_Fun hd hn hr ha hi => exact .V_Fun hd hn hr (by simpa only [hm.length] using ha) (hm.signature hi)
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
    | .V_Raise ha hot hoe hkind => exact .V_Raise ⟨by simpa only [hm.length] using ha.wf,
        hm.sorted ha.sorted, ha.declared.context hm.declaration⟩ hot hoe hkind
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
    | .C_Match hv ho ha hdecl hx =>
      refine .C_Match (context_value hv hA hstore hm hf) ?_ (context_arms ha hA hstore hm hf) (hdecl.context hm.declaration) hx
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
    | .plain (δ := δ) (alts := alts) (links := links) hp hvf hfw hw hb hs =>
      have hw' : FactsWF P C Δ (pathFacts obs (matchedTests alts ++ excludedTests alts)) := by
        intro p hp
        simpa only [predBind_id] using (hw p hp).map hm.values hm.references hm.declaration
      have hmf := Entails.extend_conditions hf (added := pathFacts obs (matchedTests alts)) (added' := pathFacts obs (matchedTests alts)) (by simp)
      have hef := Entails.extend_conditions hf (added := pathFacts obs (excludedTests alts)) (added' := pathFacts obs (excludedTests alts)) (by simp)
      have hmm := hm.add_conditions (pathFacts obs (matchedTests alts)) hA hstore
      have hme := hm.add_conditions (pathFacts obs (excludedTests alts)) hA hstore
      have hparams := hmm.params hA hstore δ
      have hfw' : FactsWF P C (bindParams Δ δ) (fieldFacts δ.length obs links) := by
        intro p hp
        simpa only [predBind_id] using (hfw p hp).map hparams.values hparams.references hparams.declaration
      have hparamsF := hparams.add_conditions (fieldFacts δ.length obs links) hA hstore
      have hconds := Entails.extend_conditions (hmm.conditions_params hmf δ) (added := fieldFacts δ.length obs links) (added' := fieldFacts δ.length obs links) (by simp)
      exact .plain hp hvf hfw' hw' (context_comp hb hA hstore hparamsF hconds) (context_arms hs hA hstore hme hef)
    | .guarded (δ := δ) (alts := alts) (p := p) (links := links) hp hvf hfw hw hgp hg hb hs =>
      have hw' : FactsWF P C Δ (pathFacts obs (matchedTests alts ++ excludedTests alts)) := by
        intro p hp
        simpa only [predBind_id] using (hw p hp).map hm.values hm.references hm.declaration
      have hmf := Entails.extend_conditions hf (added := pathFacts obs (matchedTests alts)) (added' := pathFacts obs (matchedTests alts)) (by simp)
      have hmm := hm.add_conditions (pathFacts obs (matchedTests alts)) hA hstore
      have hparams := hmm.params hA hstore δ
      have hfw' : FactsWF P C (bindParams Δ δ) (fieldFacts δ.length obs links) := by
        intro p hp
        simpa only [predBind_id] using (hfw p hp).map hparams.values hparams.references hparams.declaration
      have hparamsF := hparams.add_conditions (fieldFacts δ.length obs links) hA hstore
      have hguard := hparamsF.hideConts hA hstore
      have hconds := Entails.extend_conditions (hmm.conditions_params hmf δ) (added := fieldFacts δ.length obs links) (added' := fieldFacts δ.length obs links) (by simp)
      refine .guarded hp hvf hfw' hw' (hguard.annotation hgp)
        (context_comp hg hA hstore hguard (fun p hp => (hconds p hp).hideConts)) ?_
        (context_arms hs hA hstore hm hf)
      exact context_comp hb hA hstore
        (hparamsF.add_conditions [p.open (.boolean true)] hA hstore)
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
    | .text hs hk hb hp ht hv hw hi =>
      exact .text hs hk (fun v he => context_value (hb v he) hA hstore hm hf)
        (context_value hp hA hstore hm hf) ht (context_value hv hA hstore hm hf) hw hi

end


private def Shape (a : Ty) : Prop :=
  a.Ordinary ∨ (∃ b t e, a = .cont b t e) ∨ a.norm = a

private theorem Shape.of_wf {nr nt nv a} (hw : a.WF nr nt nv) : Shape a := by
  cases a with
  | cont b t e => exact Or.inr (Or.inl ⟨b, t, e, rfl⟩)
  | refined a p => exact Or.inl hw.2.2
  | _ => exact Or.inl (by intro b t e he; cases he)

private theorem Shape.shiftV {a : Ty} (h : Shape a) (k c : Nat) : Shape (a.shiftV k c) := by
  rcases h with ho | ⟨b,t,e,rfl⟩ | hn
  · exact Or.inl ((Ty.ordinary_shiftV _ _ _).mpr ho)
  · exact Or.inr (Or.inl ⟨_, _, _, rfl⟩)
  · exact Or.inr (Or.inr (by rw [Ty.norm_shiftV, hn]))

private def ContextShape (Γ : Ctx) : Prop := ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → Shape a

private theorem ContextShape.extend {Γ a} (h : ContextShape Γ) (ha : Shape a) :
    ContextShape (Γ.extend a) := by
  intro i b hb
  cases i with
  | zero =>
    simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hb
    subst b
    exact ha.shiftV 1 0
  | succ i =>
    simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hb
    obtain ⟨oa, ho, he⟩ := Option.map_eq_some_iff.mp hb
    cases oa with
    | none => cases he
    | some a => cases he; exact (h i a ho).shiftV 1 0

private theorem ContextShape.many {Γ nt n ps} (h : ContextShape Γ)
    (hw : BinderTypes.LocalWF nt n ps) : ContextShape (Γ.extendMany ps) := by
  induction ps generalizing Γ n with
  | nil => exact h
  | cons a as ih => exact ih (h.extend (Shape.of_wf hw.1)) hw.2

/-- 正規化した束縛型から同じ正規形の元の文脈へ、計算と結果を変えずに移す。 -/
theorem comp {P B store Q C Γ Δ Φ R m a e L}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (hn : Γ.NormEq Δ)
    (hΓ : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.norm = a)
    (hΔ : ∀ (i : Nat) (a : Ty), Δ[i]? = some (some a) →
      a.Ordinary ∨ (∃ b t e, a = .cont b t e) ∨ a.norm = a) :
    HasTypeCQ P B store Q C Δ Φ R m a e L := by
  have hm : ContextMap P B store Q C Γ Δ Φ := by
    constructor
    · exact hn.length.symm
    · intro i a hi ho
      obtain ⟨b, hb, he⟩ := hn.lookup hi
      have he' : b.norm = a := he.symm.trans (hΓ i a hi)
      refine ⟨b, hb, he.symm, ?_⟩
      rcases hΔ i b hb with hbOrd | hbCont | hbNorm
      · exact False.elim (ho ((Ty.ordinary_norm a).mp (he ▸ (Ty.ordinary_norm b).mpr hbOrd)))
      · obtain ⟨bin, bout, eff, rfl⟩ := hbCont
        exact Or.inr ⟨bin, bout, eff, rfl, hΓ i a hi⟩
      · exact Or.inl (hbNorm.symm.trans he')
    · intro i a hi ho
      obtain ⟨b, hb, he⟩ := hn.lookup hi
      have he' : b.norm = a := he.symm.trans (hΓ i a hi)
      rw [← he']
      exact .V_Normal (.V_Var hb ((Ty.ordinary_norm b).mp (he'.symm ▸ ho)))
  exact context_comp h hA hw hm (fun p hp => .hyp (List.mem_append_right _ hp))

/-- 操作の引数型の整形式だけから、元の節の文脈へ戻すための形を得る。 -/
theorem clause_shape {sg : OpSig} (hw : sg.WF) {Γ : Ctx}
    (hn : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → a.norm = a) (t : Ty) (e : Eff) :
    ∀ (i : Nat) (a : Ty), (sg.context Γ t e)[i]? = some (some a) →
      a.Ordinary ∨ (∃ b t e, a = .cont b t e) ∨ a.norm = a := by
  have hbase : ContextShape (Γ.shiftE sg.tparams.length) := by
    intro i a hi
    simp only [Ctx.shiftE, Ctx.shiftEAt, List.getElem?_map] at hi
    obtain ⟨oa, ho, he⟩ := Option.map_eq_some_iff.mp hi
    cases oa with
    | none => cases he
    | some a =>
      cases he
      exact Or.inr (Or.inr (by rw [Ty.norm_shiftTypes, hn i a ho]))
  exact (hbase.many hw.1).extend (Or.inr (Or.inl ⟨_, _, _, rfl⟩))

end
end Benitoite.Release.Refinement.Surface.NormalContext
