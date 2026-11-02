import Benitoite.Release.Refinement.LegacyValues
import Benitoite.Release.TypeSubstLemmas
import Benitoite.Release.Refinement.TypeSubst

namespace Benitoite.Release.Refinement
noncomputable section


theorem legacy_eff_test (e : Benitoite.Release.Eff) (x : Atom) :
    (embedEff e).test x = embedAtoms e.test x := by cases e; rfl

theorem legacy_substAtoms (es : List Benitoite.Release.Eff) (a : Benitoite.Release.Atom → Bool) :
    embedAtoms (Benitoite.Release.Eff.substAtoms es a) = substAtoms (es.map embedEff) (embedAtoms a) := by
  funext x
  cases x with
  | rho i =>
    simp only [embedAtoms,Atom.toOld?,Option.map_some,Option.getD_some,
      Benitoite.Release.Eff.substAtoms,substAtoms,List.length_map]
    congr 2
    funext j
    cases he : es[j]? <;> simp [List.getElem?_map,he,legacy_eff_test,embedAtoms,Atom.toOld?]
  | name l ix =>
    cases ix with
    | rvar i =>
      simp only [embedAtoms,Atom.toOld?,Option.map_some,Option.getD_some,
        Benitoite.Release.Eff.substAtoms,substAtoms,List.length_map]
      congr 2
      funext j
      cases he : es[j]? <;> simp [List.getElem?_map,he,legacy_eff_test,embedAtoms,Atom.toOld?]
    | fixed r =>
      cases r <;> simp only [embedAtoms,Atom.toOld?,Option.map_some,Option.map_none,
        Option.getD_some,Option.getD_none,Benitoite.Release.Eff.substAtoms,substAtoms,List.length_map]
      all_goals first
        | (congr 2; funext j;
            cases he : es[j]? <;> simp [List.getElem?_map,he,legacy_eff_test,embedAtoms,Atom.toOld?])
        | (symm; apply List.any_eq_false.mpr; intro j hj;
            cases he : es[j]? <;> simp [List.getElem?_map,he,legacy_eff_test,embedAtoms,Atom.toOld?])

theorem legacy_rowFails (es : List Benitoite.Release.Eff) (a : Benitoite.Release.Atom → Bool) :
    embedTys (Benitoite.Release.Eff.rowFails es a) = rowFails (es.map embedEff) (embedAtoms a) := by
  simp only [Benitoite.Release.Eff.rowFails,rowFails,List.length_map,
    show ∀ i, embedAtoms a (.rho i) = a (.rho i) from fun _ => rfl,
    embedTys_eq_map,List.map_flatMap]
  congr 1
  funext i
  cases he : es[i]? with
  | none => simp [List.getElem?_map,he]
  | some e => cases e; simp [List.getElem?_map,he,embedEff,Benitoite.Release.Eff.fails,Eff.fails]

theorem legacy_ordinary (a : Benitoite.Release.Ty)
    (h : ∀ b t e, a ≠ .cont b t e) : Ordinary (embedTy a) := by
  cases a <;> simp_all [Ordinary,embedTy,Ty.core]

private theorem legacy_rawApply (a : Benitoite.Release.Ty) (as : List Benitoite.Release.Ty) :
    embedTy (a.rawApplyTo as) = rawApply (embedTy a) (embedTys as) := by
  cases a <;> try rfl
  case ctor c =>
    cases c <;> cases as <;> try rfl
    rename_i a as
    cases as <;> rfl

mutual
  theorem legacy_rawBind (θ : Benitoite.Release.SubstEnv) (σ : SubstEnv)
      (ht : ∀ i, embedTy (θ.types i) = σ.types i) (hs : σ.rows = θ.rows.map embedEff)
      (hrr : σ.ranges = []) (a : Benitoite.Release.Ty) :
      embedTy (a.rawBind θ) = (embedTy a).rawBind σ := by
    cases a <;> simp only [Benitoite.Release.Ty.rawBind,embedTy,Ty.rawBind,
      legacy_rawBind θ σ ht hs hrr,legacy_rawBindTys θ σ ht hs hrr,
      legacy_rawBindEff θ σ ht hs hrr,legacy_rawApply,ht,hrr,RangeIx.inst_nil]
  theorem legacy_rawBindTys (θ : Benitoite.Release.SubstEnv) (σ : SubstEnv)
      (ht : ∀ i, embedTy (θ.types i) = σ.types i) (hs : σ.rows = θ.rows.map embedEff)
      (hrr : σ.ranges = []) (as : List Benitoite.Release.Ty) :
      embedTys (Benitoite.Release.Ty.rawBindTys θ as) = rawBindTys σ (embedTys as) := by
    cases as <;> simp only [Benitoite.Release.Ty.rawBindTys,embedTys,rawBindTys,
      legacy_rawBind θ σ ht hs hrr,legacy_rawBindTys θ σ ht hs hrr]
  theorem legacy_rawBindEff (θ : Benitoite.Release.SubstEnv) (σ : SubstEnv)
      (ht : ∀ i, embedTy (θ.types i) = σ.types i) (hs : σ.rows = θ.rows.map embedEff)
      (hrr : σ.ranges = []) (e : Benitoite.Release.Eff) :
      embedEff (Benitoite.Release.Eff.rawBind θ e) = Eff.rawBind σ (embedEff e) := by
    cases e with
    | mk a fs =>
      simp only [Benitoite.Release.Eff.rawBind,embedEff,Eff.rawBind,hs,hrr,instAtoms_nil]
      rw [←legacy_substAtoms,←legacy_rawBindTys θ σ ht hs hrr,←legacy_rowFails]
      simp only [embedTys_eq_map,List.map_append]
end

theorem legacy_subst (a : Benitoite.Release.Ty) (ts : List Benitoite.Release.Ty) :
    embedTy (a.subst ts []) = (embedTy a).subst (embedTys ts) [] := by
  simp only [Benitoite.Release.Ty.subst,Benitoite.Release.Ty.substAt_eq_bind,
    Benitoite.Release.Ty.bind,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,embedTy_norm]
  congr 1
  apply legacy_rawBind _ _ _ rfl rfl
  intro i
  simp only [Benitoite.Release.SubstEnv.at,typeEnvAt,Nat.not_lt_zero,ite_false,
    Nat.sub_zero,embedTys_eq_map,List.length_map,List.getElem?_map]
  split
  · simp only [Benitoite.Release.Ty.rawShift_zero,shiftTypes_zero]
    cases ts[i]? <;> rfl
  · rfl

theorem legacy_subst_rows (a : Benitoite.Release.Ty) (ts : List Benitoite.Release.Ty)
    (es : List Benitoite.Release.Eff) :
    embedTy (a.subst ts es) = (embedTy a).subst (embedTys ts) (es.map embedEff) := by
  simp only [Benitoite.Release.Ty.subst,Benitoite.Release.Ty.substAt_eq_bind,
    Benitoite.Release.Ty.bind,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,embedTy_norm]
  congr 1
  apply legacy_rawBind _ _ _ _ rfl
  · intro i
    simp only [Benitoite.Release.SubstEnv.at,typeEnvAt,Nat.not_lt_zero,ite_false,
      Nat.sub_zero,embedTys_eq_map,List.length_map,List.getElem?_map]
    split
    · simp only [Benitoite.Release.Ty.rawShift_zero,shiftTypes_zero]
      cases ts[i]? <;> rfl
    · rfl
  · simp only [typeEnvAt,Benitoite.Release.SubstEnv.at,List.map_map,Function.comp_def,
      shiftRowsTypes_zero,Benitoite.Release.Eff.rawShift_zero]

mutual
  theorem legacy_shiftV (a : Benitoite.Release.Ty) (k c : Nat) :
      (embedTy a).shiftV k c = embedTy a := by
    cases a <;> simp only [embedTy,Ty.shiftV,legacy_shiftV,legacy_shiftVTys,legacy_shiftVEff]
  theorem legacy_shiftVTys (as : List Benitoite.Release.Ty) (k c : Nat) :
      shiftVTys k c (embedTys as) = embedTys as := by
    cases as <;> simp only [embedTys,shiftVTys,legacy_shiftV,legacy_shiftVTys]
  theorem legacy_shiftVEff (e : Benitoite.Release.Eff) (k c : Nat) :
      Eff.shiftV k c (embedEff e) = embedEff e := by
    cases e; simp only [embedEff,Eff.shiftV,legacy_shiftVTys]
end

theorem legacy_embedParameters (ps : List Benitoite.Release.Ty) : embedParameters ps = embedTys ps := by
  simp only [embedParameters,legacy_shiftV,embedTys_eq_map]
  change List.map (embedTy ∘ Prod.fst) ps.zipIdx = ps.map embedTy
  rw [←List.map_map]
  simp

theorem legacy_signatureTel (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) :
    signatureTel ns (embedTys ps) (embedTy r) (embedEff e) =
      Ty.toTel ns (embedTys ps) (embedTy r) (embedEff e) := by
  induction ns generalizing ps with
  | nil => rfl
  | cons n ns ih =>
    cases ps with
    | nil => rfl
    | cons a ps => simp only [embedTys,signatureTel,Ty.toTel,legacy_shiftV,legacy_shiftVTys,legacy_shiftVEff,ih]

theorem legacy_annotation_context (a : Benitoite.Release.Ty) {P C Γ Δ}
    (h : Ty.Annotation P C Γ (embedTy a)) : Ty.Annotation P C Δ (embedTy a) :=
  ⟨(embedTy_wf_values a 0 C.length Γ.length Δ.length).mp h.wf,
    embedTy_sorted a Δ,(embedTy_declared_context a P C C Γ Δ rfl).mp h.declared⟩

theorem legacy_signatureTel_annotation (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) {P C Γ}
    (ha : Ty.Annotation P C Γ (embedTy (.fn ns ps r e))) :
    Ty.Annotation P C Γ (.dependentFn (signatureTel ns (embedTys ps) (embedTy r) (embedEff e))) := by
  induction ns generalizing ps Γ with
  | nil =>
    cases ps with
    | cons => have hn := ha.wf.1.1; simp at hn
    | nil => exact ⟨ha.wf.2.2,ha.sorted.2,ha.declared.2⟩
  | cons n ns ih =>
    cases ps with
    | nil => have hn := ha.wf.1.1; simp at hn
    | cons a ps =>
      have tail : Ty.Annotation P C Γ (embedTy (.fn ns ps r e)) :=
        ⟨⟨⟨by simpa only [NamesWF,embedTys_eq_map,List.length_map,List.length_cons] using Nat.succ.inj ha.wf.1.1,
              ha.wf.1.2.of_cons⟩,ha.wf.2.1.2,ha.wf.2.2⟩,
          ⟨ha.sorted.1.2,ha.sorted.2⟩,⟨ha.declared.1.2,ha.declared.2⟩⟩
      have ht := ih ps (Γ := Γ.extend (embedTy a)) (legacy_annotation_context _ tail)
      exact ⟨⟨ha.wf.2.1.1,by simpa only [Ty.WF,Ctx.extend,List.length_cons,List.length_map] using ht.wf⟩,
        ⟨ha.sorted.1.1,ht.sorted⟩,⟨ha.declared.1.1,ht.declared⟩⟩

theorem legacy_substEff (e : Benitoite.Release.Eff) (ts : List Benitoite.Release.Ty)
    (es : List Benitoite.Release.Eff) :
    embedEff (Benitoite.Release.Eff.substAt 0 ts es e) = Eff.subst (embedTys ts) (es.map embedEff) (embedEff e) := by
  simp only [Benitoite.Release.Eff.substAt,Benitoite.Release.Eff.rawSubstAt,
    Eff.subst,Eff.substAt,substRowAt,Eff.bind,embedEff_norm]
  congr 1
  apply legacy_rawBindEff _ _ _ _ rfl
  · intro i
    simp only [Benitoite.Release.SubstEnv.at,typeEnvAt,Nat.not_lt_zero,ite_false,
      Nat.sub_zero,embedTys_eq_map,List.length_map,List.getElem?_map]
    split
    · simp only [Benitoite.Release.Ty.rawShift_zero,shiftTypes_zero]
      cases ts[i]? <;> rfl
    · rfl
  · simp only [typeEnvAt,Benitoite.Release.SubstEnv.at,List.map_map,Function.comp_def,
      shiftRowsTypes_zero,Benitoite.Release.Eff.rawShift_zero]

theorem legacy_instantiatedTel (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (ts : List Benitoite.Release.Ty)
    (es : List Benitoite.Release.Eff) :
    instantiatedTel (signatureTel ns (embedTys ps) (embedTy r) (embedEff e))
        (embedTys ts) (es.map embedEff) =
      signatureTel ns (embedTys (ps.map (Benitoite.Release.Ty.subst ts es)))
        (embedTy (r.subst ts es)) (embedEff (Benitoite.Release.Eff.substAt 0 ts es e)) := by
  rw [instantiatedTel,legacy_signatureTel,Tel.bind_toTel,legacy_signatureTel]
  congr 1
  · simp only [embedTys_eq_map,List.map_map,Function.comp_def,legacy_subst_rows,Ty.subst,Ty.substAt,substTypeAt]
  · exact (legacy_subst_rows r ts es).symm
  · exact (legacy_substEff e ts es).symm

theorem legacy_instantiated_annotation (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (ts : List Benitoite.Release.Ty)
    (es : List Benitoite.Release.Eff) {P C Γ}
    (ha : Ty.Annotation P C Γ (embedTy (Benitoite.Release.fnTy ns ps r e ts es))) :
    Ty.Annotation P C Γ (.dependentFn (instantiatedTel
      (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)) (embedTys ts) (es.map embedEff))) := by
  rw [legacy_instantiatedTel]
  apply legacy_signatureTel_annotation
  simpa only [Benitoite.Release.fnTy,Benitoite.Release.Ty.subst,Benitoite.Release.Ty.substAt,
    Benitoite.Release.Ty.substTysAt_eq_map] using ha

theorem legacy_instantiated_norm (ns : List String) (ps : List Benitoite.Release.Ty)
    (r : Benitoite.Release.Ty) (e : Benitoite.Release.Eff) (ts : List Benitoite.Release.Ty)
    (es : List Benitoite.Release.Eff) (names : Benitoite.Release.NamesWF ns ps) :
    (Ty.dependentFn (instantiatedTel
      (signatureTel ns (embedTys ps) (embedTy r) (embedEff e)) (embedTys ts) (es.map embedEff))).norm =
      (embedTy (Benitoite.Release.fnTy ns ps r e ts es)).norm := by
  have hn : NamesWF ns (embedTys (ps.map (Benitoite.Release.Ty.subst ts es))) :=
    ⟨by simpa only [embedTys_eq_map,List.length_map] using names.1,names.2⟩
  rw [legacy_instantiatedTel,legacy_signatureTel,Ty.norm_toTel hn]
  simp only [Benitoite.Release.fnTy,Benitoite.Release.Ty.subst,Benitoite.Release.Ty.substAt,
    Benitoite.Release.Ty.substTysAt_eq_map]
  rfl

private theorem legacy_eff_injective : Function.Injective embedEff := by
  intro a b h
  have he : embedTy (.fn [] [] (.base .unit) a) = embedTy (.fn [] [] (.base .unit) b) := by
    change Ty.fn [] [] (.base .unit) (embedEff a) = Ty.fn [] [] (.base .unit) (embedEff b)
    rw [h]
  have := embedTy_injective he
  cases this
  rfl

private theorem legacy_canonical {e : Benitoite.Release.Eff} (h : (embedEff e).Canonical) :
    e.Canonical := legacy_eff_injective ((embedEff_norm e).trans h)

mutual
  theorem legacy_wf {nr nt nv : Nat} {a : Benitoite.Release.Ty}
      (h : (embedTy a).WF nr nt nv) : a.WF nr nt := by
    cases a <;> simp only [embedTy,Ty.WF] at h <;> simp only [Benitoite.Release.Ty.WF]
    all_goals first | exact h | exact legacy_wf h | exact legacy_wfTys h | skip
    case «opaque» o ix => cases ix <;> exact h
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF,Benitoite.Release.NamesWF,embedTys_eq_map,List.length_map] using h.1,
        legacy_wfTys h.2.1,legacy_wf h.2.2.1,legacy_wfEff h.2.2.2.1,legacy_canonical h.2.2.2.2⟩
    case cont a b e => exact ⟨legacy_wf h.1,legacy_wf h.2.1,legacy_wfEff h.2.2.1,legacy_canonical h.2.2.2⟩
    case map a b => exact ⟨legacy_wf h.1,legacy_wf h.2⟩
    case tapp i as => exact ⟨h.1,legacy_wfTys h.2⟩
  theorem legacy_wfTys {nr nt nv : Nat} {as : List Benitoite.Release.Ty}
      (h : Ty.WFList nr nt nv (embedTys as)) : Benitoite.Release.Ty.WFList nr nt as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨legacy_wf h.1,legacy_wfTys h.2⟩
  theorem legacy_wfEff {nr nt nv : Nat} {e : Benitoite.Release.Eff}
      (h : (embedEff e).WF nr nt nv) : e.WF nr nt := by
    cases e; exact legacy_wfTys h
end

end
end Benitoite.Release.Refinement
