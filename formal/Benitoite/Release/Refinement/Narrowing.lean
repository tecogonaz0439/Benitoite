import Benitoite.Release.Refinement.SubstTyping

/-!
# 構文の文脈の narrowing

部分型は置き換える束縛の外側で検査し、後続の値・None・経路条件の位置を保つ。
-/
namespace Benitoite.Release.Refinement

private structure ContextMap (P : Program) (B : Builtins) (store : StoreTy) (Q : NoFailCtx)
    (C : List TParam) (Γ Δ : Ctx) (Ξ : List Pred) : Prop where
  length : Δ.length = Γ.length
  lookup : ∀ i a, Γ[i]? = some (some a) → a.Ordinary →
    HasTypeVQ P B store Q C Δ Ξ (.var i) a

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
    (h : ContextMap P B store Q C Γ Δ Ξ) :
    ContextMap P B (hideBuilders store) Q C (hideConts Γ) (hideConts Δ) Ξ := by
  constructor
  · simpa only [hideConts, List.length_map] using h.length
  · intro i a hi ho
    exact (h.lookup i a (hideConts_lookup.mp hi).1 ho).hide_context (hideBuilders store)

private theorem ContextMap.params {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) (ps : List Ty) :
    ContextMap P B store Q C (bindParams Γ ps) (bindParams Δ ps) (liftMany ps.length Ξ) := by
  constructor
  · simp only [bindParams, List.length_append, List.length_map, List.length_reverse, h.length]
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
            (store' := store) (ShiftMap.outer Δ ps) (Ξ := liftMany ps.length Ξ)
            (fun p hp => .hyp (List.mem_append_right _ (by rw [liftMany_eq]; exact List.mem_map.mpr ⟨p,hp,rfl⟩)))
          simpa only [Val.rename, shiftIndex_add, Nat.sub_add_cancel (Nat.le_of_not_gt hil)] using ht

private theorem ContextMap.none {P B store Q C Γ Δ Ξ}
    (h : ContextMap P B store Q C Γ Δ Ξ) :
    ContextMap P B store Q C Γ.extendNone Δ.extendNone (Ξ.map Pred.lift) := by
  constructor
  · simp only [Ctx.extendNone, List.length_cons, List.length_map, h.length]
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
            (store' := store) (ShiftMap.outerNone Δ) (Ξ := Ξ.map Pred.lift) (fun p hp => by
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

mutual
  private theorem context_value {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeVQ P B store Q C Δ Ξ v a := by
    match h with
    | .V_Var hi ho => exact hm.lookup _ _ hi ho
    | .V_Const hc => exact .V_Const hc
    | .V_Lam (ps := ps) hn hw hs hb =>
      refine .V_Lam hn (by simpa only [hm.length] using hw) (hm.sorted hs) ?_
      exact context_comp hb (hm.hide.params ps)
        (hm.hide.conditions_params (fun p hp => (hf p hp).hideConts) ps)
    | .V_List he hw hs =>
      exact .V_List (context_each he hm hf) (by simpa only [hm.length] using hw) (hm.sorted hs)
    | .V_Sub hv hl hw hs hd =>
      have hl' := hl.rawBind (SubstEnv.valuesOnly (fun i => some (.var i))) (hm.transport hf)
      change Ty.LeQ Δ Ξ (renameTy id _) (renameTy id _) at hl'
      simp only [renameTy_id] at hl'
      exact .V_Sub (context_value hv hm hf) hl' (by simpa only [hm.length] using hw) (hm.sorted hs) (hd.context hm.declaration)
    | .V_Refine hv hi ht hs hw he hda hdp =>
      refine .V_Refine (context_value hv hm hf) hi ht ?_ (by simpa only [hm.length] using hw) ?_ (hda.context hm.declaration) ?_
      · simpa only [upValues_id, predBind_id] using Pred.sorted_bind hs (fun i => some (.var i)) (fun _ h => h) id hm.values hm.references
      · simpa only [SubstEnv.valuesOnly, predBind_id] using (hm.transport hf).entails he
      · simpa only [Option.map_some, Ty.rawSubstV_id, upValues_id, predBind_id] using hdp.bind hm.declaration
  private theorem context_values {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeVsQ P B store Q C Δ Ξ vs as := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (context_value hv hm hf) (context_values hs hm hf)
  private theorem context_each {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeEachQ P B store Q C Δ Ξ vs a := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (context_value hv hm hf) (context_each hs hm hf)
  private theorem context_comp {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) {Δ Ξ}
      (hm : ContextMap P B store Q C Γ Δ Ξ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) p) :
      HasTypeCQ P B store Q C Δ Ξ R m a e L := by
    match h with
    | .C_Return hv => exact .C_Return (context_value hv hm hf)
    | .C_App hv hs => exact .C_App (context_value hv hm hf) (context_values hs hm hf)
    | .C_Sub ht hl hc hw hs hd =>
      have hl' := hl.rawBind (SubstEnv.valuesOnly (fun i => some (.var i))) (hm.transport hf)
      change Ty.LeQ Δ Ξ (renameTy id _) (renameTy id _) at hl'
      simp only [renameTy_id] at hl'
      exact .C_Sub (context_comp ht hm hf) hl' hc (by simpa only [hm.length] using hw) (hm.sorted hs) (hd.context hm.declaration)
    | .C_Eff ht hc => exact .C_Eff (context_comp ht hm hf) hc
    | .C_Let (a := x) ht hb =>
      refine .C_Let (context_comp ht hm hf) ?_
      have hb' := context_comp hb (hm.params [x]) (hm.conditions_params hf [x])
      simpa only [List.length_cons, List.length_nil, Nat.zero_add, liftMany_one,
        bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.map_cons, List.map_nil,
        List.nil_append, List.cons_append] using hb'
end

/-- 外側で検査した部分型による一位置の置換と、後続の束縛の列。 -/
inductive Ctx.Narrows (P : Program) (C : List TParam) : Ctx → List Pred → Ctx → List Pred → Prop where
  | here {Γ Φ a b} : Ty.LeQ Γ Φ a b → b.WF 0 C.length Γ.length → b.Sorted Γ → Ty.Declared P C Γ b →
      Narrows P C (Γ.extend b) (Φ.map Pred.lift) (Γ.extend a) (Φ.map Pred.lift)
  | under {Γ Φ Δ Ξ} : Narrows P C Γ Φ Δ Ξ → (a : Ty) →
      Narrows P C (Γ.extend a) (Φ.map Pred.lift) (Δ.extend a) (Ξ.map Pred.lift)
  | underNone {Γ Φ Δ Ξ} : Narrows P C Γ Φ Δ Ξ →
      Narrows P C Γ.extendNone (Φ.map Pred.lift) Δ.extendNone (Ξ.map Pred.lift)

theorem Ctx.Narrows.conditions {P C Γ Φ Δ Ξ} (h : Ctx.Narrows P C Γ Φ Δ Ξ) : Φ = Ξ := by
  induction h with
  | here _ _ _ _ => rfl
  | under _ _ ih | underNone _ ih => exact congrArg (List.map Pred.lift) ih

private theorem Ctx.Narrows.contextMap {P B store Q C Γ Φ Δ Ξ}
    (h : Ctx.Narrows P C Γ Φ Δ Ξ) : ContextMap P B store Q C Γ Δ Ξ := by
  induction h with
  | @here Γ Φ a b hl hw hs hd =>
    constructor
    · simp [Ctx.extend]
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
        change Ty.LeQ (Γ.extend a) (Φ.map Pred.lift) (renameTy (shiftIndex 1 0) a) (renameTy (shiftIndex 1 0) b) at hl'
        rw [renameTy_shiftIndex] at hl'
        exact .V_Sub hv hl' (hm.wf hw) (hm.sorted hs) (hm.declared hd)
      | succ i =>
        exact .V_Var (by simpa only [Ctx.extend, List.getElem?_cons_succ] using hi) ho
  | under h a ih =>
    have hm := ih.params [a]
    simpa only [List.length_cons, List.length_nil, Nat.zero_add, liftMany_one,
      bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil, List.map_cons, List.map_nil,
      List.nil_append, List.cons_append] using hm
  | underNone h ih => exact ih.none

theorem HasTypeVQ.narrow {P B store Q C Γ Φ v a Δ Ξ}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeVQ P B store Q C Δ Ξ v a :=
  context_value h hn.contextMap (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeVsQ.narrow {P B store Q C Γ Φ vs as Δ Ξ}
    (h : HasTypeVsQ P B store Q C Γ Φ vs as) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeVsQ P B store Q C Δ Ξ vs as :=
  context_values h hn.contextMap (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeEachQ.narrow {P B store Q C Γ Φ vs a Δ Ξ}
    (h : HasTypeEachQ P B store Q C Γ Φ vs a) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeEachQ P B store Q C Δ Ξ vs a :=
  context_each h hn.contextMap (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

theorem HasTypeCQ.narrow {P B store Q C Γ Φ R m a e L Δ Ξ}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L) (hn : Ctx.Narrows P C Γ Φ Δ Ξ) :
    HasTypeCQ P B store Q C Δ Ξ R m a e L :=
  context_comp h hn.contextMap (fun _ hp => .hyp (List.mem_append_right _ (hn.conditions ▸ hp)))

end Benitoite.Release.Refinement
