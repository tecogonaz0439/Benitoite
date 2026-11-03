import Benitoite.Release.Refinement.Context.WF

/-!
# 有限の経路条件と文脈の事実の再構成

事実は型付きの像から含意として作る。捕捉を延長する前に、延長後の
事実を仮定しない。未観測の値は openOptional により部分観測のまま扱う。
-/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Pred.WellFormed.shift {P C Γ Δ p k c} (hm : ShiftMap k c Γ Δ)
    (h : Pred.WellFormed P C Γ p) : Pred.WellFormed P C Δ (p.shiftV k c) :=
  h.map hm.values hm.references hm.declarationRenaming.images

private theorem wellFormed_context {P C Γ Δ p} (h : Pred.WellFormed P C Γ p)
    (hm : Ctx.TypeMap Γ Δ) (hd : DeclarationImages P C Γ Δ (fun i => some (.var i))) :
    Pred.WellFormed P C Δ p := by
  simpa only [renEnv_values, id_eq, predBind_id] using h.map hm.values hm.references hd

private theorem assume_subset (a : Ty) (p : Pred) :
    ∀ q ∈ a.assume, q ∈ (Ty.refined a p).assume := by
  intro q h
  rw [Ty.assume_refined (Ty.assume_ordinary h)]
  exact List.mem_append_left _ h

private theorem refined_map (Γ : Ctx) (a : Ty) (p : Pred) :
    Ctx.TypeMap (Γ.extend a) (Γ.extend (.refined a p)) :=
  (Ctx.TypeMap.id Γ).extend a (.refined a p) (fun _ h => h)
    (fun ho => ho) (assume_subset a p)

private theorem refined_declaration (P : Program) (C : TypeCtx) (Γ : Ctx) (a : Ty) (p : Pred) :
    DeclarationImages P C (Γ.extend a) (Γ.extend (.refined a p)) (fun i => some (.var i)) := by
  have h := (DeclarationImages.id P C Γ).extend a (.refined a p)
    (fun ho => ho) (by simp [Ty.norm, Ty.core])
  simpa only [upValues_id] using h

private theorem self_images (Γ : Ctx) (a : Ty) (p : Pred) :
    Term.ImagesSorted (some a :: Γ) (Γ.extend (.refined a p)) (fun i => some (.var i)) ∧
    Term.ImageReferences (some a :: Γ) (Γ.extend (.refined a p)) (fun i => some (.var i)) := by
  constructor
  · intro i b s hi hb
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      have hs : ((Ty.refined a p).shiftV 1 0).HasSort s := (Ty.hasSort_shiftV _ _ _ _).mpr hb
      exact ⟨.var 0, rfl, ⟨_, rfl, hs.ordinary⟩, _, rfl, hs⟩
    | succ i =>
      have hi' : (Γ.extend (.refined a p))[i+1]? = some (some (b.shiftV 1 0)) := by
        simp [Ctx.lookup_extend, show Γ[i]? = some (some b) from hi]
      have hs := (Ty.hasSort_shiftV b 1 0 s).mpr hb
      exact ⟨.var (i+1), rfl, ⟨_, hi', hs.ordinary⟩, _, hi', hs⟩
  · intro i b hi hb u hu
    cases hu
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      exact ⟨_, rfl, (Ty.ordinary_shiftV _ _ _).mpr hb⟩
    | succ i =>
      exact ⟨b.shiftV 1 0, by simp [Ctx.lookup_extend, show Γ[i]? = some (some b) from hi],
        (Ty.ordinary_shiftV _ _ _).mpr hb⟩

/-- 篩の self と外側の注釈を、実際に束縛した文脈で検査する。 -/
theorem Ty.assume_wellFormed {P C Γ a} (ha : Ty.Annotation P C Γ a) :
    ∀ p ∈ a.assume, Pred.WellFormed P C (Γ.extend a) p := by
  cases a <;> try (simp only [Ty.assume,Ty.core,Ty.refinementPredicates]; exact fun _ hp => False.elim (List.not_mem_nil hp))
  case base b =>
    intro p hp
    cases b <;> simp only [Ty.assume, Ty.carrierFacts, Ty.core, Ty.refinementPredicates,
      List.append_nil, integerBounds, List.mem_cons, List.not_mem_nil, or_false] at hp <;>
      try contradiction
    all_goals first | (rcases hp with rfl | rfl) | subst p
    all_goals
      constructor
      · simp [Pred.WF, Pred.VarsIn, Term.VarsIn, Ctx.extend]
      · simp [Pred.Sorted, Term.HasSort, Term.Shape, Term.References, Term.VarsIn,
          Ctx.Readable, Ctx.extend, Ty.shiftV, Ty.HasSort, Ty.sort?, Ty.core]
      · simp [Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable,
          Ctx.extend, Ty.shiftV, Ty.core]
  case refined a q =>
    rw [Ty.assume_refined ha.wf.2.2]
    intro p hp
    rcases List.mem_append.mp hp with hp | hp
    · have h := Ty.assume_wellFormed ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩ p hp
      exact wellFormed_context h (refined_map Γ a q) (refined_declaration P C Γ a q)
    · have hs : p.Sorted (Γ.extend (.refined a q)) none := by
        simpa only [predBind_id] using (Pred.sorted_conjuncts ha.sorted.2 p hp).map
          (Δ := Γ.extend (.refined a q)) (other := none) (self_images Γ a q).1 (self_images Γ a q).2
      have hd : p.Declared P C (Γ.extend (.refined a q)) none := by
        simpa only [predBind_id, Ctx.extend] using
          (Pred.Declared.map (self := some a) (other := none) (ha.declared.2.conjuncts p hp)
            (refined_declaration P C Γ a q))
      exact ⟨hs.wf_none, hs, hd⟩

/-- B は任意の表であり、組込みへの追加の信頼条件は要らない。 -/
theorem Ctx.Regular.facts (B : Builtins) {P C Γ} (h : Ctx.Regular P C Γ) :
    FactsWF P C Γ Γ.facts := by
  intro p hp
  obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
  have ha : Ty.Annotation P C Γ a := ⟨h.wf i a hi, h.sorted i a hi, h.declared i a hi⟩
  have hv : HasTypeVQ P B StoreTy.empty Qempty C Γ [] (.var i) a :=
    .V_Var hi (Ty.assume_ordinary hq)
  have ho := SubstOk.openValue (R := none) hv ha h.wf
  have hq := (Ty.assume_wellFormed ha q hq).map ho.observations ho.references ho.declaration
  have he : (valEnv (openValue (.var i))).values =
      (fun j => match j with | 0 => some (.var i) | j+1 => some (.var j)) := by
    funext j
    cases j <;> simp [valEnv, openValue, Val.toTerm?]
  rw [he] at hq
  exact hq

theorem FactsWF.extend {P C Γ Φ} (h : FactsWF P C Γ Φ) (a : Ty) :
    FactsWF P C (Γ.extend a) (Φ.map Pred.lift) := by
  intro p hp
  obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
  exact Pred.WellFormed.shift (ShiftMap.outerValue Γ (some (a.shiftV 1 0))) (h q hq)

theorem FactsWF.extendNone {P C Γ Φ} (h : FactsWF P C Γ Φ) :
    FactsWF P C Γ.extendNone (Φ.map Pred.lift) := by
  intro p hp
  obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
  exact Pred.WellFormed.shift (ShiftMap.outerValue Γ none) (h q hq)

theorem Ctx.facts_entails_extend {Γ : Ctx} {Φ : List Pred} {p : Pred} (h : Entails (Γ.facts ++ Φ) p) (a : Ty) :
    Entails ((Γ.extend a).facts ++ Φ.map Pred.lift) p.lift := by
  apply (h.bind (fun i => some (.var (i+1)))).weaken
  intro q hq
  obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
  rcases List.mem_append.mp hr with hr | hr
  · exact List.mem_append_left _ (Ctx.mem_facts_extend.mpr (Or.inr ⟨r, hr, rfl⟩))
  · exact List.mem_append_right _ (List.mem_map.mpr ⟨r, hr, rfl⟩)

theorem Ctx.facts_entails_extendNone {Γ : Ctx} {Φ : List Pred} {p : Pred} (h : Entails (Γ.facts ++ Φ) p) :
    Entails (Γ.extendNone.facts ++ Φ.map Pred.lift) p.lift := by
  apply (h.bind (fun i => some (.var (i+1)))).weaken
  intro q hq
  obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
  rcases List.mem_append.mp hr with hr | hr
  · exact List.mem_append_left _ (Ctx.mem_facts_extendNone.mpr ⟨r, hr, rfl⟩)
  · exact List.mem_append_right _ (List.mem_map.mpr ⟨r, hr, rfl⟩)

theorem Capture.bind_extend_lift (cap : Capture) (v : Val) (p : Pred) :
    predBind (valEnv (cap.extend v).env).values p.lift = predBind (valEnv cap.env).values p := by
  simp only [Pred.lift, predBind_comp]
  congr 1

theorem Capture.bind_extend_assume (cap : Capture) (v : Val) (p : Pred) :
    predBind (valEnv (cap.extend v).env).values p =
      (predBind (upValues (valEnv cap.env).values) p).openOptional v.toTerm? := by
  simp only [Pred.openOptional, predBind_comp]
  congr 1
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    change (valEnv cap.env).values i = _
    simp only [upValues]
    cases h : (valEnv cap.env).values i with
    | none => rfl
    | some t =>
      simp only [Option.map_some, Option.bind_some]
      exact (termBind_shift_open _ t).symm

theorem Capture.facts_extend {P B Ψ} {Γ : Ctx} {Φ : List Pred} {cap : Capture} {a : Ty} {v : Val}
    (hf : ∀ p ∈ Γ.facts ++ Φ, Entails [] (predBind (valEnv cap.env).values p))
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a)) :
    ∀ p ∈ (Γ.extend a).facts ++ Φ.map Pred.lift,
      Entails [] (predBind (valEnv (cap.extend v).env).values p) := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · rcases Ctx.mem_facts_extend.mp hp with hp | ⟨q, hq, rfl⟩
    · rw [Capture.bind_extend_assume]
      exact hv.assume_optional _ (Ty.assume_bind a (valEnv cap.env) (by intro i; simp [valEnv, Ty.Ordinary,Ty.core]) p hp)
    · rw [Capture.bind_extend_lift]
      exact hf q (List.mem_append_left _ hq)
  · obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
    rw [Capture.bind_extend_lift]
    exact hf q (List.mem_append_right _ hq)

theorem CaptureOk.facts_extend {P B Ψ R Γ Φ cap a v} (h : CaptureOk P B Ψ R Γ Φ cap)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a)) :
    ∀ p ∈ (Γ.extend a).facts ++ Φ.map Pred.lift,
      Entails [] (predBind (valEnv (cap.extend v).env).values p) := by
  cases h with
  | mk _ _ _ _ _ _ _ hf => exact Capture.facts_extend hf hv

end
end Benitoite.Release.Refinement
