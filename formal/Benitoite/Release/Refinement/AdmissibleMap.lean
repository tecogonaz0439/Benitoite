import Benitoite.Release.Refinement.ValueInstantiation
import Benitoite.Release.Refinement.InversionCore

namespace Benitoite.Release.Refinement
noncomputable section

theorem TypeAnnotations.norm {P C Γ ts} (h : TypeAnnotations P C Γ ts) :
    TypeAnnotations P C Γ (Ty.normTys ts) := by
  intro a hm
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp (by simpa only [Ty.normTys_eq_map] using hm)
  exact ⟨Ty.wf_norm (h b hb).wf, Ty.sorted_norm (h b hb).sorted, (h b hb).declared.norm⟩

theorem Ty.Annotation.norm {P C Γ a} (h : Ty.Annotation P C Γ a) : Ty.Annotation P C Γ a.norm :=
  ⟨Ty.wf_norm h.wf, Ty.sorted_norm h.sorted, h.declared.norm⟩

theorem HasTypeVQ.norm {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (ha : Ty.Annotation P C Γ a) : HasTypeVQ P B Ψ Q C Γ Φ v a.norm :=
  h.convert (Ty.norm_idem a).symm ha.norm

theorem HasTypeCQ.norm {P B Ψ Q C Γ Φ R m a e L} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L)
    (ha : Ty.Annotation P C Γ a) : HasTypeCQ P B Ψ Q C Γ Φ R m a.norm e L :=
  h.convert (Ty.norm_idem a).symm ha.norm

/-- 組込みへ渡す型・行引数を正規化しても、具体化した依存列は変わらない。 -/
theorem instantiatedTel_norm_images (t : Tel) (ts : List Ty) (es : List Eff) :
    instantiatedTel t (Ty.normTys ts) (es.map Eff.norm) = instantiatedTel t ts es := by
  apply Ty.foldFn_injective
  simpa only [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,Ty.norm,
    instantiatedTel,Tel.bind,Ty.normTys_eq_map] using
    Ty.subst_norm_images_all (.dependentFn t) ts es


theorem TypeArgsKinded.norm {P C ts ks} (h : TypeArgsKinded P C ts ks) :
    TypeArgsKinded P C (Ty.normTys ts) ks := by
  obtain ⟨hn,K,hK,h⟩ := h
  refine ⟨by simpa only [Ty.normTys_eq_map,List.length_map] using hn,K,hK,?_⟩
  intro i a k ha hk
  obtain ⟨b,hb,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [Ty.normTys_eq_map,List.getElem?_map] using ha)
  exact (h i b k hb hk).norm

theorem SignatureInstance.norm_images {P C Γ t ks ts es}
    (h : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Γ t ks (Ty.normTys ts) (es.map Eff.norm) := by
  refine ⟨h.source,h.types.norm,h.kinds.norm,?_,?_⟩
  · intro e he
    obtain ⟨f,hf,rfl⟩ := List.mem_map.mp he
    simpa only [Ty.norm,Ty.normTys] using (h.rows f hf).norm
  · rw [instantiatedTel_norm_images]; exact h.result

theorem instantiatedTel_shift_eq {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es k c) :
    Tel.shiftV k c (instantiatedTel t ts es) = instantiatedTel t (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) := by
  have he := Ty.subst_shiftV_closed_rows h ts es k c
  apply Ty.foldFn_injective
  simpa only [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    instantiatedTel, Tel.bind, Ty.foldFn_shiftV] using he

theorem instantiatedTel_shift {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es k c) :
    (Ty.dependentFn (instantiatedTel t ts es)).shiftV k c =
      .dependentFn (instantiatedTel t (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c))) :=
  congrArg Ty.dependentFn (instantiatedTel_shift_eq h ts es k c)

theorem instantiatedTel_subst {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es) (ν : Nat → Val) :
    substTyValues ν (Ty.dependentFn (instantiatedTel t ts es)) =
      (Ty.dependentFn (instantiatedTel t (ts.map (substTyValues ν)) (es.map (substEffValues ν)))).norm := by
  have he := Ty.substV_subst_closed_rows h ts es (valEnv ν).values
  have hty : Ty.substV (valEnv ν).values = substTyValues ν := rfl
  have hef : Eff.substV (valEnv ν).values = substEffValues ν := rfl
  rw [hty, hef] at he
  simpa only [Ty.subst, Ty.substAt, substTypeAt, Ty.substV, Ty.bind, Ty.rawBind, Ty.norm,
    Ty.rawBind_foldFn_norm, instantiatedTel, Tel.bind, Tel.norm_idem,
    substTyValues, substEffValues, SubstEnv.valuesOnly, valEnv] using he

theorem instantiatedTel_subst_eq {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es) (ν : Nat → Val) :
    Tel.bind (valEnv ν) (instantiatedTel t ts es) = instantiatedTel t (ts.map (substTyValues ν)) (es.map (substEffValues ν)) := by
  apply Ty.foldFn_injective
  simpa only [substTyValues, Ty.bind, Ty.rawBind, Ty.norm, instantiatedTel, Tel.bind, Tel.norm_idem]
    using instantiatedTel_subst h ts es ν

theorem Ty.subst_values_closed {nt : Nat} {a : Ty} (h : a.WF 0 nt 0) (ts) (ν : Nat → Val) :
    substTyValues ν (a.subst ts []) = a.subst (ts.map (substTyValues ν)) [] :=
  Ty.substV_subst_closed h ts (valEnv ν).values

theorem Ty.bind_base (b) (ν : Nat → Val) : Ty.bind (valEnv ν) (.base b) = .base b := rfl

theorem Ty.bind_dict (cl a) (ν : Nat → Val) :
    substTyValues ν (.dict cl a) = .dict cl (substTyValues ν a) := rfl

theorem RowTransport.map {Qs Qt es} (h : RowTransport Qs Qt es) (g : Eff → Eff)
    (hg : ∀ e, NoFail Qt e → NoFail Qt (g e)) (hr : ∀ i, g (Eff.row i) = Eff.row i) :
    RowTransport Qs Qt (es.map g) := by
  intro i hi
  have hh := hg _ (h i hi)
  cases he : es[i]? with
  | none => simpa only [List.getElem?_map, he, Option.map_none, Option.getD_none, hr] using hh
  | some e => simpa only [List.getElem?_map, he, Option.map_some, Option.getD_some] using hh

theorem NoFail.shift_values {Q e} (h : NoFail Q e) (k c) : NoFail Q (e.shiftV k c) := by
  cases e with
  | mk ats fs =>
    obtain ⟨rfl, ha⟩ := h
    exact ⟨rfl, ha⟩

theorem NoFail.subst_values {Q e} (h : NoFail Q e) (ν : Nat → Val) :
    NoFail Q (substEffValues ν e) := by
  cases e with
  | mk ats fs =>
    obtain ⟨rfl, ha⟩ := h
    simpa [substEffValues, Eff.bind, Eff.rawBind, rowFails, valEnv, valEnv_valuesOnly,
      rawBindTys, List.nil_append, instAtoms_nil, substAtoms_nil, Eff.norm, Ty.normTys,
      NoFail, Eff.test, Eff.fails, Eff.atoms] using (show ([] : List Ty) = [] ∧ ∀ i, ats (.rho i) = true → Q i from ⟨rfl, ha⟩)


theorem NoFail.norm {Q e} (h : NoFail Q e) : NoFail Q e.norm := by
  cases e with
  | mk ats fs =>
    obtain ⟨rfl,ha⟩ := h
    exact ⟨rfl,ha⟩

theorem PrimitiveAdmissible.norm {C nv s Q ts es}
    (h : PrimitiveAdmissible C nv s Q ts es) :
    PrimitiveAdmissible C nv s Q (Ty.normTys ts) (es.map Eff.norm) := by
  refine ⟨?_,?_,?_,?_,?_,?_,?_,?_⟩
  · simpa only [Ty.normTys_eq_map,List.length_map] using h.typeCount
  · simpa only [Ty.normTys_eq_map,List.map_map,Function.comp_def,Ty.norm_idem] using h.admits
  · intro a ha
    obtain ⟨b,hb,rfl⟩ := List.mem_map.mp (by simpa only [Ty.normTys_eq_map] using ha)
    exact ⟨Ty.wf_norm (h.typeScope b hb).1,(Ty.ordinary_norm _).mpr (h.typeScope b hb).2⟩
  · simpa only [List.length_map] using h.rowCount
  · intro e he
    obtain ⟨f,hf,rfl⟩ := List.mem_map.mp he
    exact Eff.wf_norm (h.rowScope f hf)
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ
  · intro i hi
    have hh := (h.noFailRows i hi).norm
    cases he : es[i]? with
    | none => simpa only [List.getElem?_map,he,Option.map_none,Option.getD_none] using h.noFailRows i hi
    | some e => simpa only [List.getElem?_map,he,Option.map_some,Option.getD_some] using hh

theorem Admissible.map {B C nv tps ne Qs Qt ts es e}
    (h : Admissible B C nv tps ne Qs Qt ts es e) {nv'} (f : Ty → Ty) (g : Eff → Eff)
    (hsat : SatAll B C (ts.map f) tps)
    (ht : ∀ a ∈ ts, (f a).WF 0 C.length nv' ∧ (f a).Ordinary)
    (he : ∀ e ∈ es, (g e).WF 0 C.length nv')
    (hn : RowTransport Qs Qt (es.map g)) :
    Admissible B C nv' tps ne Qs Qt (ts.map f) (es.map g) e := by
  refine ⟨hsat, ?_, by simpa using h.rowCount, ?_, ?_, ?_, hn⟩
  · intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact ht x hx
  · intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact he x hx
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

theorem PrimitiveAdmissible.map {C nv s Q ts es}
    (h : PrimitiveAdmissible C nv s Q ts es) {nv'} (f : Ty → Ty) (g : Eff → Eff)
    (ha : s.admits C (Ty.normTys (ts.map f)))
    (ht : ∀ a ∈ ts, (f a).WF 0 C.length nv' ∧ (f a).Ordinary)
    (he : ∀ e ∈ es, (g e).WF 0 C.length nv')
    (hn : RowTransport (Qsig s.params s.ret s.eff) Q (es.map g)) :
    PrimitiveAdmissible C nv' s Q (ts.map f) (es.map g) := by
  refine ⟨by simpa using h.typeCount, ha, ?_, by simpa using h.rowCount, ?_, ?_, ?_, hn⟩
  · intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact ht x hx
  · intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact he x hx
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

theorem MethodRowsAdmissible.map {C nv Q ms es}
    (h : MethodRowsAdmissible C nv Q ms es) {nv'} (g : Eff → Eff)
    (he : ∀ e ∈ es, (g e).WF 0 C.length nv')
    (hn : RowTransport (Qsig ms.params ms.ret ms.eff) Q (es.map g)) :
    MethodRowsAdmissible C nv' Q ms (es.map g) := by
  refine ⟨by simpa using h.1, ?_, ?_, ?_, hn⟩
  · intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact he x hx
  · simpa only [List.length_map] using h.2.2.1
  · simpa only [List.length_map] using h.2.2.2.1

end
end Benitoite.Release.Refinement
