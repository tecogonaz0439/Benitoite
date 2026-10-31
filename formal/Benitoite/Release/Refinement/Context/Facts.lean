import Benitoite.Release.Refinement.Context.WF

/-!
# 有限の経路条件と文脈の事実の再構成

事実は型付きの像から含意として作る。捕捉を延長する前に、延長後の
事実を仮定しない。未観測の値は openOptional により部分観測のまま扱う。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def Ctx.sortSelf (Γ : Ctx) : Option Ty → Ctx
  | none => Γ
  | some a => some a :: Γ

theorem Pred.Sorted.map {Γ Δ : Ctx} {self other : Option Ty} {ν : ObservationEnv} {p : Pred}
    (h : p.Sorted Γ self)
    (hs : Term.ImagesSorted (Ctx.sortSelf Γ self)
      (Ctx.sortSelf Δ other) ν)
    (hr : Term.ImageReferences (Ctx.sortSelf Γ self)
      (Ctx.sortSelf Δ other) ν) :
    (predBind ν p).Sorted Δ other := by
  cases p <;> simp only [Pred.Sorted] at h <;> simp only [predBind, Pred.Sorted]
  all_goals first
    | trivial
    | exact ⟨Term.hasSort_termBind h.1 _ hs hr, Term.hasSort_termBind h.2 _ hs hr⟩
    | exact ⟨h.1, Term.hasSort_termBind h.2.1 _ hs hr, Term.hasSort_termBind h.2.2 _ hs hr⟩
    | exact Term.hasSort_termBind h _ hs hr
    | exact ⟨Pred.Sorted.map (Γ := Γ) (Δ := Δ) (self := self) (other := other) (ν := ν) h.1 hs hr, Pred.Sorted.map (Γ := Γ) (Δ := Δ) (self := self) (other := other) (ν := ν) h.2 hs hr⟩
    | exact Pred.Sorted.map (Γ := Γ) (Δ := Δ) (self := self) (other := other) (ν := ν) h hs hr

theorem Pred.Sorted.wf_none {Γ : Ctx} {p : Pred} (h : p.Sorted Γ none) : p.WF Γ.length :=
  Pred.varsIn_mono h.references (fun _ ⟨_, hi, _⟩ => (List.getElem?_eq_some_iff.mp hi).1)

structure Pred.WellFormed (P : Program) (C : List TParam) (Γ : Ctx) (p : Pred) : Prop where
  wf : p.WF Γ.length
  sorted : p.Sorted Γ none
  declared : p.Declared P C Γ none

def FactsWF (P : Program) (C : List TParam) (Γ : Ctx) (Φ : List Pred) : Prop :=
  ∀ p ∈ Φ, Pred.WellFormed P C Γ p

theorem Pred.WellFormed.map {P C Γ Δ p ν} (h : Pred.WellFormed P C Γ p)
    (hs : Term.ImagesSorted Γ Δ ν) (hr : Term.ImageReferences Γ Δ ν)
    (hd : DeclarationImages P C Γ Δ ν) : Pred.WellFormed P C Δ (predBind ν p) := by
  have hp : (predBind ν p).Sorted Δ none := h.sorted.map hs hr
  exact ⟨hp.wf_none, hp, h.declared.map hd⟩

theorem Pred.WellFormed.shift {P C Γ Δ p k c} (hm : ShiftMap k c Γ Δ)
    (h : Pred.WellFormed P C Γ p) : Pred.WellFormed P C Δ (p.shiftV k c) :=
  h.map hm.values hm.references hm.declarationRenaming.images

private theorem wellFormed_context {P C Γ Δ p} (h : Pred.WellFormed P C Γ p)
    (hm : Ctx.TypeMap Γ Δ) (hd : DeclarationImages P C Γ Δ (fun i => some (.var i))) :
    Pred.WellFormed P C Δ p := by
  simpa only [renEnv_values, id_eq, predBind_id] using h.map hm.values hm.references hd

private theorem assume_subset (a : Ty) (p : Pred) :
    ∀ q ∈ a.assume, q ∈ (Ty.refined a p).assume := fun _ h => List.mem_cons_of_mem _ h

private theorem refined_map (Γ : Ctx) (a : Ty) (p : Pred) :
    Ctx.TypeMap (Γ.extend a) (Γ.extend (.refined a p)) :=
  (Ctx.TypeMap.id Γ).extend a (.refined a p) (fun _ h => h)
    (fun _ => by simp [Ordinary]) (assume_subset a p)

private theorem refined_declaration (P : Program) (C : List TParam) (Γ : Ctx) (a : Ty) (p : Pred) :
    DeclarationImages P C (Γ.extend a) (Γ.extend (.refined a p)) (fun i => some (.var i)) := by
  have h := (DeclarationImages.id P C Γ).extend a (.refined a p)
    (fun _ => by simp [Ordinary]) (by simp [Ty.norm, Ty.core])
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
      exact ⟨_, rfl, by simp [Ty.shiftV, Ordinary]⟩
    | succ i =>
      exact ⟨b.shiftV 1 0, by simp [Ctx.lookup_extend, show Γ[i]? = some (some b) from hi],
        (Ty.ordinary_shiftV _ _ _).mpr hb⟩

/-- 篩の self と外側の注釈を、実際に束縛した文脈で検査する。 -/
theorem Ty.assume_wellFormed {P C Γ a} (ha : Ty.Annotation P C Γ a) :
    ∀ p ∈ a.assume, Pred.WellFormed P C (Γ.extend a) p := by
  cases a <;> simp only [Ty.assume]
  all_goals first | exact fun p hp => False.elim (List.not_mem_nil hp) | skip
  case refined a q =>
    intro p hp
    rcases List.mem_cons.mp hp with rfl | hp
    · have hs : p.Sorted (Γ.extend (.refined a p)) none := by
        simpa only [predBind_id] using ha.sorted.2.map
          (Δ := Γ.extend (.refined a p)) (other := none) (self_images Γ a p).1 (self_images Γ a p).2
      have hd : p.Declared P C (Γ.extend (.refined a p)) none := by
        simpa only [predBind_id, Ctx.extend] using
          (Pred.Declared.map (self := some a) (other := none) ha.declared.2
            (refined_declaration P C Γ a p))
      exact ⟨hs.wf_none, hs, hd⟩
    · have h := Ty.assume_wellFormed ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩ p hp
      exact wellFormed_context h (refined_map Γ a q) (refined_declaration P C Γ a q)

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
      exact hv.assume_optional _ (Ty.assume_bind a (valEnv cap.env) p hp)
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
