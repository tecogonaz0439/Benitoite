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

mutual
  theorem Ty.References.norm {Γ a} (h : Ty.References Γ a) : Ty.References Γ a.norm := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ | ctor _ => trivial
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.References.norm (a := a) h
    | data _ as | external _ as | tapp _ as => exact referencesTys_norm (as := as) h
    | dependentFn t => exact Tel.References.norm (t := t) h
    | fn _ ps r e => exact ⟨referencesTys_norm (as := ps) h.1, Ty.References.norm (a := r) h.2.1, referencesEff_norm (e := e) h.2.2⟩
    | cont b t e => exact ⟨Ty.References.norm (a := b) h.1, Ty.References.norm (a := t) h.2.1, referencesEff_norm (e := e) h.2.2⟩
    | map a b => exact ⟨Ty.References.norm (a := a) h.1, Ty.References.norm (a := b) h.2⟩
    | refined a p =>
      refine ⟨Ty.References.norm (a := a) h.1, ?_⟩
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
