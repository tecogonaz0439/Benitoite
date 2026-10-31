import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.MatchFacts

/-! # 可変セルと不変な捕捉のストア移送 -/
namespace Benitoite.Release.Refinement
noncomputable section

def StoreTy.put (Ψ : StoreTy) (l : Nat) (x : LocTy) : StoreTy :=
  fun i => if i = l then some x else Ψ i

theorem StoreTy.extends_put {Ψ : StoreTy} {l : Nat} {x : LocTy} (h : Ψ l = none) : Ψ.Extends (Ψ.put l x) := by
  intro i t hi
  have hn : i ≠ l := by intro he; subst i; rw [h] at hi; cases hi
  simp only [StoreTy.put, hn, ↓reduceIte, hi]

theorem HasTypeVQ.store_extend {P B Ψ Q C Γ Φ v a Ψ'}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasTypeVQ P B Ψ' Q C Γ Φ v a := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw he.preservesNormals
    ⟨rfl,by intro i a hi _; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
    (Ξ := Φ) (by intro p hp; rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero,Val.rename_identity,Ty.shiftV_zero] using hh

private theorem arms_store {P B Ψ Q C Γ Φ R obs arms a b e L Ψ'}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasTypeArmsQ P B Ψ' Q C Γ Φ R obs arms a b e L := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw he
    ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
    (LocalCtx.Shift.refl _) (Ξ := Φ)
    (by intro p hp; rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero,Arm.renameList_identity,Ty.shiftV_zero,Eff.shiftV_zero,
    id_eq,termBind_identity,Option.map_id,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hh

private theorem clauses_store {P B Ψ Q C Γ Φ R eb cs t e L Ψ'}
    (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasTypeClausesQ P B Ψ' Q C Γ Φ R eb cs t e L := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw he
    ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
    (LocalCtx.Shift.refl _) (Ξ := Φ)
    (by intro p hp; rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero,Clause.renameList_identity,Ty.shiftV_zero,Eff.shiftV_zero,
    id_eq,Option.map_id,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hh

private theorem failure_store {P B Ψ Q C Γ Φ E R cs t e L Ψ'}
    (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    HasFailureClause P B Ψ' Q C Γ Φ E R cs t e L := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw he
    ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
    (LocalCtx.Shift.refl _) (Ξ := Φ)
    (by intro p hp; rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
  simpa only [shiftIndex_zero,Clause.renameList_identity,Ty.shiftV_zero,Eff.shiftV_zero,
    id_eq,Option.map_id,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hh

theorem GuardBodyTy.store {P B Ψ R q input a e Ψ'}
    (h : GuardBodyTy P B Ψ R q input a e)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    GuardBodyTy P B Ψ' R q input a e := by
  cases h with
  | mk hc hg hb hl hcode ha hR hr =>
    exact .mk (hc.store hA hw he.preservesNormals) hg (hb.store_extend hA hw he)
      (fun i kind hi => by obtain ⟨l,hr,ht⟩ := hl i kind hi; exact ⟨l,hr,he l _ ht⟩)
      hcode ha hR hr

theorem ContTy.store {P B σ Ψ R ε k a b Eb Re Ψ'}
    (h : ContTy P B σ Ψ R ε k a b Eb Re)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    ContTy P B σ Ψ' R ε k a b Eb Re := by
  induction h with
  | K_Empty h ha => exact .K_Empty h ha
  | K_Sub _ hl ih => exact .K_Sub ih hl
  | K_Let hq had ha hs _ ih => exact .K_Let (hq.store hA hw he) had ha hs ih
  | K_Mark _ ha ih => exact .K_Mark ih ha
  | K_Update hl _ ih => exact .K_Update (he _ _ hl) ih
  | K_Release hv had hr hs _ ih => exact .K_Release (hv.store_extend hA hw he) had hr hs ih
  | K_Drop hl hs _ ih => exact .K_Drop (he _ _ hl) hs ih
  | K_Handle _ hc hs hcap hcs hR ht hec heb ha has hr had ih =>
    exact .K_Handle ih hc hs (hcap.store hA hw.hide he.preservesNormals.hide.preservesNormals)
      (clauses_store hcs hA hw.hide he.preservesNormals.hide) hR ht hec heb ha has hr had
  | K_Handle_Fail _ hc hn hcap hcs hR ht hec hE hr hcov ha had ih =>
    exact .K_Handle_Fail ih hc hn (hcap.store hA hw.hide he.preservesNormals.hide.preservesNormals)
      (failure_store hcs hA hw.hide he.preservesNormals.hide) hR ht hec hE hr hcov ha had
  | K_Guard hcap hv ho hs hl harms hr hx hval hR ha heq hbody hsub hprefix _ had ih =>
    exact .K_Guard (hcap.store hA hw he.preservesNormals) (hv.store_extend hA hw he) ho
      (arms_store hs hA hw he)
      (fun i kind hi => by obtain ⟨l,hr,ht⟩ := hl i kind hi; exact ⟨l,hr,he l _ ht⟩)
      harms hr hx hval hR ha heq (hbody.store hA hw he) hsub hprefix ih had

theorem CellOk.store {P B σ Ψ l c Ψ'}
    (h : CellOk P B σ Ψ l c)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (he : Ψ.Extends Ψ') :
    CellOk P B σ Ψ' l c := by
  cases c with
  | val v | done v =>
    obtain ⟨a,hl,hv,had⟩ := h
    exact ⟨a,he _ _ hl,hv.store_extend hA hw he,had⟩
  | thunk q =>
    obtain ⟨a,hl,hq,had⟩ := h
    exact ⟨a,he _ _ hl,hq.store hA hw.hide he.preservesNormals.hide,had⟩
  | used => obtain ⟨b,t,e,r,hl⟩ := h; exact ⟨b,t,e,r,he _ _ hl⟩
  | cont k =>
    obtain ⟨b,t,e,r,hl,hend,R,ε,hk⟩ := h
    exact ⟨b,t,e,r,he _ _ hl,hend,R,ε,hk.store hA hw he⟩
  | builder c =>
    obtain ⟨kind,hl,hc,had⟩ := h
    refine ⟨kind,he _ _ hl,⟨hc.1,?_⟩,had⟩
    cases kind <;> cases c <;> try exact hc.2
    rename_i a vs
    refine ⟨hc.2.1,?_⟩
    have hh := hc.2.2.shift_values (k := 0) (c := 0) hA hw he.preservesNormals
      ⟨rfl,by intro i a hi _; cases hi⟩ (Ξ := []) (by simp)
    simpa only [shiftIndex_zero,Val.renameList_identity,Ty.shiftV_zero] using hh

private theorem store_set_finite {μ : Store} (h : ∃ n, ∀ l, n ≤ l → μ l = none)
    (l : Nat) (c : Cell) : ∃ n, ∀ i, n ≤ i → (μ.set l c) i = none := by
  obtain ⟨n,hn⟩ := h
  refine ⟨max n (l+1),?_⟩
  intro i hi
  have hil : i ≠ l := by omega
  simp only [Store.set,hil,↓reduceIte]
  exact hn i (by omega)

theorem StoreOk.write_reference {P B σ Ψ μ l a b v}
    (h : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.ref b))
    (he : b.norm = a.norm) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ Ψ (μ.set l (.val v)) := by
  refine ⟨store_set_finite h.1 l _,h.wf,h.declared,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simpa only [Store.set,hi,↓reduceIte] using h.2.2.2.1 i x hx
  · intro i c hc
    by_cases hi : i = l
    · subst i
      simp only [Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      exact CellOk.val_write hl he hn hv ha
    · simp only [Store.set,hi,↓reduceIte] at hc
      exact h.2.2.2.2 i c hc

theorem StoreOk.allocate_reference {P B σ Ψ μ l a v}
    (h : StoreOk P B σ Ψ μ) (hA : Builtins.ValueAssumptions P B)
    (hl : μ l = none) (ht : Ty.Annotation P [] [] a) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ (Ψ.put l (.ref a)) (μ.set l (.val v)) := by
  have hnone : Ψ l = none := by
    cases he : Ψ l with
    | none => rfl
    | some t => exact False.elim (h.2.2.2.1 l t he hl)
  have hext := StoreTy.extends_put (x := LocTy.ref a) hnone
  refine ⟨store_set_finite h.1 l _,?_,?_,?_,?_⟩
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact ht.wf
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.wf i x hx
  · intro i x hx
    by_cases hi : i = l
    · subst i; simp only [StoreTy.put,↓reduceIte,Option.some.injEq] at hx
      subst x; exact ht.declared
    · simp only [StoreTy.put,hi,↓reduceIte] at hx; exact h.declared i x hx
  · intro i x hx
    by_cases hi : i = l
    · simp [Store.set,hi]
    · simp only [StoreTy.put,hi,↓reduceIte] at hx
      simpa only [Store.set,hi,↓reduceIte] using h.2.2.2.1 i x hx
  · intro i c hc
    by_cases hi : i = l
    · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hc
      subst c
      exact CellOk.val_write (by simp [StoreTy.put]) rfl hn (hv.store_extend hA h.wf hext) ha
    · simp only [Store.set,hi,↓reduceIte] at hc
      exact (h.2.2.2.2 i c hc).store hA h.wf hext

theorem reference_no_sort (a : Ty) : (Ty.reference a).sort? = none := rfl
theorem reference_no_observation (l : Nat) : (Val.loc l).toTerm? = none := rfl
theorem reference_no_observed_fact (l : Nat) (tests : List PathTest) :
    pathFacts (Val.loc l).toTerm? tests = [] := rfl

theorem CaptureOk.reference_write_snapshot {P B σ Ψ μ R Γ Φ cap l a b v p}
    (hA : Builtins.ValueAssumptions P B) (hs : StoreOk P B σ Ψ μ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hp : Entails (Γ.facts ++ Φ) p)
    (hl : Ψ l = some (.ref b)) (he : b.norm = a.norm) (hn : a.Normal)
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ) :
    StoreOk P B σ Ψ (μ.set l (.val v)) ∧ CaptureOk P B Ψ R Γ Φ cap ∧
      Entails [] (predBind (valEnv cap.env).values p) :=
  ⟨hs.write_reference hl he hn hv ha,
    hc.store hA hs.wf (StoreTy.PreservesNormals.refl _),hc.close_entails hp⟩

end
end Benitoite.Release.Refinement
