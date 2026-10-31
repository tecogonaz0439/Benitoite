import Benitoite.Release.Refinement.ValueRegularity

/-!
# 値置換と正規化による参照の保存

sort を持たない関数の snapshot も参照の判断で扱う。
-/
namespace Benitoite.Release.Refinement

mutual
  theorem Ty.References.rawSubstV {Γ Δ ν a} (h : Ty.References Γ a)
      (hm : Term.ImageReferences Γ Δ ν) : Ty.References Δ (a.rawSubstV ν) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ | ctor _ => trivial
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.References.rawSubstV (a := a) h hm
    | data _ as | external _ as | tapp _ as => exact referencesTys_rawSubstV (as := as) h hm
    | dependentFn t => exact Tel.References.rawSubstV (t := t) h hm
    | fn _ ps r e => exact ⟨referencesTys_rawSubstV (as := ps) h.1 hm,
        Ty.References.rawSubstV (a := r) h.2.1 hm, referencesEff_rawSubstV (e := e) h.2.2 hm⟩
    | cont b t e => exact ⟨Ty.References.rawSubstV (a := b) h.1 hm,
        Ty.References.rawSubstV (a := t) h.2.1 hm, referencesEff_rawSubstV (e := e) h.2.2 hm⟩
    | map a b => exact ⟨Ty.References.rawSubstV (a := a) h.1 hm, Ty.References.rawSubstV (a := b) h.2 hm⟩
    | refined a p => exact ⟨Ty.References.rawSubstV (a := a) h.1 hm,
        Pred.references_bind h.2 ν (fun h => (Ty.ordinary_rawSubstV _ _).mpr h) hm⟩
  theorem Tel.References.rawSubstV {Γ Δ ν t} (h : Tel.References Γ t)
      (hm : Term.ImageReferences Γ Δ ν) : Tel.References Δ (Tel.rawSubstV ν t) := by
    cases t with
    | done r e => exact ⟨Ty.References.rawSubstV (a := r) h.1 hm, referencesEff_rawSubstV (e := e) h.2 hm⟩
    | param n a t => exact ⟨Ty.References.rawSubstV (a := a) h.1 hm,
        Tel.References.rawSubstV (t := t) h.2 (Term.imageReferences_extend hm a (a.rawSubstV ν)
          (fun h => (Ty.ordinary_rawSubstV _ _).mpr h))⟩
  theorem referencesTys_rawSubstV {Γ Δ ν as} (h : referencesTys Γ as)
      (hm : Term.ImageReferences Γ Δ ν) : referencesTys Δ (substVTys ν as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.References.rawSubstV (a := a) h.1 hm, referencesTys_rawSubstV (as := as) h.2 hm⟩
  theorem referencesEff_rawSubstV {Γ Δ ν e} (h : Eff.References Γ e)
      (hm : Term.ImageReferences Γ Δ ν) : Eff.References Δ (Eff.rawSubstV ν e) := by
    cases e with
    | mk _ fs => exact referencesTys_rawSubstV (as := fs) h hm
end

mutual
  theorem Ty.References.context {Γ Δ a} (h : Ty.References Γ a) (hm : Ctx.TypeMap Γ Δ) : Ty.References Δ a := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ | ctor _ => trivial
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.References.context (a := a) h hm
    | data _ as | external _ as | tapp _ as => exact referencesTys_context (as := as) h hm
    | dependentFn t => exact Tel.References.context (t := t) h hm
    | fn _ ps r e => exact ⟨referencesTys_context (as := ps) h.1 hm,
        Ty.References.context (a := r) h.2.1 hm, referencesEff_context (e := e) h.2.2 hm⟩
    | cont b t e => exact ⟨Ty.References.context (a := b) h.1 hm,
        Ty.References.context (a := t) h.2.1 hm, referencesEff_context (e := e) h.2.2 hm⟩
    | map a b => exact ⟨Ty.References.context (a := a) h.1 hm, Ty.References.context (a := b) h.2 hm⟩
    | refined a p =>
      refine ⟨Ty.References.context (a := a) h.1 hm, ?_⟩
      simpa only [renEnv_values, id_eq, upValues_id, predBind_id] using
        Pred.references_bind h.2 (renEnv id).values (fun h => h) hm.references
  theorem Tel.References.context {Γ Δ t} (h : Tel.References Γ t) (hm : Ctx.TypeMap Γ Δ) : Tel.References Δ t := by
    cases t with
    | done r e => exact ⟨Ty.References.context (a := r) h.1 hm, referencesEff_context (e := e) h.2 hm⟩
    | param n a t => exact ⟨Ty.References.context (a := a) h.1 hm,
        Tel.References.context (t := t) h.2 (hm.extend a a (fun _ h => h) (fun h => h) (fun _ h => h))⟩
  theorem referencesTys_context {Γ Δ as} (h : referencesTys Γ as)
      (hm : Ctx.TypeMap Γ Δ) : referencesTys Δ as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.References.context (a := a) h.1 hm, referencesTys_context (as := as) h.2 hm⟩
  theorem referencesEff_context {Γ Δ e} (h : Eff.References Γ e) (hm : Ctx.TypeMap Γ Δ) : Eff.References Δ e := by
    cases e with
    | mk _ fs => exact referencesTys_context (as := fs) h hm
end

private theorem referencesTys_iff {Γ as} : referencesTys Γ as ↔ ∀ a ∈ as, Ty.References Γ a := by
  induction as with
  | nil => simp [referencesTys]
  | cons a as ih => simp only [referencesTys, ih, List.mem_cons, forall_eq_or_imp]

theorem Ty.references_shiftV_rev {Γ : Ctx} {a b : Ty} (h : (a.shiftV 1 0).References (Γ.extend b)) : a.References Γ := by
  obtain ⟨t, ht⟩ := Term.drop_reference_images Γ b
  have hh := h.rawSubstV ht
  rwa [Ty.substV_shift_cancel _ (dropValue_shift t)] at hh

theorem referencesTys_shiftV_rev {Γ : Ctx} {as : List Ty} {b : Ty} (h : referencesTys (Γ.extend b) (shiftVTys 1 0 as)) : referencesTys Γ as := by
  cases as with
  | nil => trivial
  | cons a as => exact ⟨Ty.references_shiftV_rev h.1, referencesTys_shiftV_rev h.2⟩

theorem referencesEff_shiftV_rev {Γ : Ctx} {e : Eff} {b : Ty} (h : Eff.References (Γ.extend b) (e.shiftV 1 0)) : Eff.References Γ e := by
  cases e; exact referencesTys_shiftV_rev h

theorem Ty.references_of_toTel {Γ ns ps r e} (hn : NamesWF ns ps)
    (h : Tel.References Γ (Ty.toTel ns ps r e)) : (Ty.fn ns ps r e).References Γ := by
  induction ns generalizing Γ ps r e with
  | nil => cases ps with
    | nil => exact ⟨trivial, h⟩
    | cons => simp [NamesWF] at hn
  | cons n ns ih => cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      have hh := ih hn' h.2
      exact ⟨⟨h.1, referencesTys_shiftV_rev hh.1⟩, Ty.references_shiftV_rev hh.2.1, referencesEff_shiftV_rev hh.2.2⟩

theorem Ty.references_foldFn {Γ t} (h : Tel.References Γ t) : (Ty.foldFn t).References Γ := by
  classical
  by_cases he : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := he
    rw [Ty.foldFn_toTel]
    exact Ty.references_of_toTel f.names_wf h
  · rw [Ty.foldFn_no_view he]; exact h

theorem Pred.references_conjuncts {Γ : Ctx} {self : Option Ty} {p : Pred} (h : p.References Γ self) : ∀ q : Pred, q ∈ p.conjuncts → q.References Γ self := by
  cases p with
  | truth => intro q hq; cases hq
  | and p q =>
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact Pred.references_conjuncts h.1 r hr
    · exact Pred.references_conjuncts h.2 r hr
  | _ => intro q hq; cases List.mem_singleton.mp hq; exact h

theorem Pred.references_ofConjuncts {Γ : Ctx} {self : Option Ty} {ps : List Pred} (h : ∀ p ∈ ps, p.References Γ self) :
    (Pred.ofConjuncts ps).References Γ self := by
  induction ps with
  | nil => trivial
  | cons p ps ih => cases ps with
    | nil => exact h p List.mem_cons_self
    | cons q qs => exact ⟨h p List.mem_cons_self, ih (fun r hr => h r (List.mem_cons_of_mem p hr))⟩

private theorem references_coreSelf {Γ : Ctx} {a : Ty} {p : Pred}
    (h : p.References Γ (some a)) : p.References Γ (some a.core) := by
  simpa only [renEnv_values, id_eq, upValues_id, predBind_id] using
    Pred.references_bind h (renEnv id).values
      (fun ho => by simpa only [Ordinary, Ty.core_idem] using ho)
      (Transport.id Γ []).references

theorem Ty.References.core {Γ : Ctx} {a : Ty} (h : a.References Γ) : a.core.References Γ := by
  cases a with
  | refined a p => exact Ty.References.core (a := a) h.1
  | _ => exact h

theorem Ty.References.predicates {Γ : Ctx} {a : Ty} (h : a.References Γ) :
    ∀ p : Pred, p ∈ a.refinementPredicates → p.References Γ (some a.core) := by
  cases a with
  | refined a p =>
    intro q hq
    rcases List.mem_append.mp hq with hq | hq
    · exact Ty.References.predicates (a := a) h.1 q hq
    · exact Pred.references_conjuncts (references_coreSelf h.2) q hq
  | _ => intro p hp; cases hp

theorem Ty.references_refineNorm {Γ : Ctx} {a : Ty} {p : Pred} (ha : a.References Γ) (hp : p.References Γ (some a)) :
    (a.refineNorm p).References Γ := by
  unfold Ty.refineNorm
  cases he : a.refinementPredicates ++ p.conjuncts with
  | nil => exact ha.core
  | cons q qs =>
    refine ⟨ha.core, Pred.references_ofConjuncts ?_⟩
    intro r hr
    rw [←he] at hr
    rcases List.mem_append.mp hr with hr | hr
    · exact ha.predicates r hr
    · exact Pred.references_conjuncts (references_coreSelf hp) r hr

mutual
  theorem Ty.References.norm {Γ a} (h : Ty.References Γ a) : Ty.References Γ a.norm := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ | ctor _ => trivial
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.References.norm (a := a) h
    | data _ as | external _ as | tapp _ as => exact referencesTys_norm (as := as) h
    | dependentFn t => exact Ty.references_foldFn (Tel.References.norm (t := t) h)
    | fn _ ps r e => exact ⟨referencesTys_norm (as := ps) h.1, Ty.References.norm (a := r) h.2.1, referencesEff_norm (e := e) h.2.2⟩
    | cont b t e => exact ⟨Ty.References.norm (a := b) h.1, Ty.References.norm (a := t) h.2.1, referencesEff_norm (e := e) h.2.2⟩
    | map a b => exact ⟨Ty.References.norm (a := a) h.1, Ty.References.norm (a := b) h.2⟩
    | refined a p =>
      apply Ty.references_refineNorm (Ty.References.norm (a := a) h.1)
      simpa only [renEnv_values, id_eq, upValues_id, predBind_id] using
        Pred.references_bind h.2 (renEnv id).values (fun h => (Ty.ordinary_norm _).mpr h) (Transport.id Γ []).references
  theorem Tel.References.norm {Γ t} (h : Tel.References Γ t) : Tel.References Γ (Tel.norm t) := by
    cases t with
    | done r e => exact ⟨Ty.References.norm (a := r) h.1, referencesEff_norm (e := e) h.2⟩
    | param n a t => exact ⟨Ty.References.norm (a := a) h.1,
        (Tel.References.norm (t := t) h.2).context
          ((Ctx.TypeMap.id Γ).extend a a.norm (fun _ h => (Ty.hasSort_norm _ _).mpr h)
            (fun h => (Ty.ordinary_norm _).mpr h) (by simp only [Ty.assume_norm]; exact fun _ h => h))⟩
  theorem referencesTys_norm {Γ as} (h : referencesTys Γ as) : referencesTys Γ (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.References.norm (a := a) h.1, referencesTys_norm (as := as) h.2⟩
  theorem referencesEff_norm {Γ e} (h : Eff.References Γ e) : Eff.References Γ (Eff.norm e) := by
    cases e with
    | mk _ fs => exact referencesTys_iff.mpr (fun a ha => referencesTys_iff.mp (referencesTys_norm (as := fs) h) a
        (Order.mem_sortUnique.mp ha))
end

theorem Ty.References.bind_values {Γ Δ ν a} (h : Ty.References Γ a) (hm : Term.ImageReferences Γ Δ ν) :
    Ty.References Δ (a.bind (SubstEnv.valuesOnly ν)) := by
  change Ty.References Δ (a.rawBind _).norm
  unfold SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind]
  exact (h.rawSubstV hm).norm

theorem Tel.References.bind_values {Γ Δ ν t} (h : Tel.References Γ t) (hm : Term.ImageReferences Γ Δ ν) :
    Tel.References Δ (Tel.bind (SubstEnv.valuesOnly ν) t) := by
  change Tel.References Δ (Tel.norm (Tel.rawBind _ t))
  unfold SubstEnv.valuesOnly
  rw [← Tel.rawSubstV_eq_rawBind]
  exact (h.rawSubstV hm).norm

theorem Eff.References.bind_values {Γ Δ ν e} (h : Eff.References Γ e) (hm : Term.ImageReferences Γ Δ ν) :
    Eff.References Δ (Eff.bind (SubstEnv.valuesOnly ν) e) := by
  change Eff.References Δ (Eff.norm (Eff.rawBind _ e))
  unfold SubstEnv.valuesOnly
  rw [← Eff.rawSubstV_eq_rawBind]
  exact referencesEff_norm (referencesEff_rawSubstV h hm)

end Benitoite.Release.Refinement
