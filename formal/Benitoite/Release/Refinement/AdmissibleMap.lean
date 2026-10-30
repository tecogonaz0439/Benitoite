import Benitoite.Release.Refinement.ValueInstantiation

namespace Benitoite.Release.Refinement
noncomputable section

theorem instantiatedTel_shift {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es k c) :
    (Ty.dependentFn (instantiatedTel t ts es)).shiftV k c =
      .dependentFn (instantiatedTel t (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c))) :=
  Ty.subst_shiftV_closed_rows h ts es k c

theorem instantiatedTel_subst {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es) (ν : Nat → Val) :
    substTyValues ν (Ty.dependentFn (instantiatedTel t ts es)) =
      .dependentFn (instantiatedTel t (ts.map (substTyValues ν)) (es.map (substEffValues ν))) :=
  Ty.substV_subst_closed_rows h ts es (valEnv ν).values

theorem instantiatedTel_shift_eq {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es k c) :
    Tel.shiftV k c (instantiatedTel t ts es) = instantiatedTel t (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) :=
  Ty.dependentFn.inj (instantiatedTel_shift h ts es k c)

theorem instantiatedTel_subst_eq {nt t} (h : (Ty.dependentFn t).WF 0 nt 0) (ts es) (ν : Nat → Val) :
    Tel.bind (valEnv ν) (instantiatedTel t ts es) = instantiatedTel t (ts.map (substTyValues ν)) (es.map (substEffValues ν)) :=
  Ty.dependentFn.inj (instantiatedTel_subst h ts es ν)

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
    (ha : s.admits C (ts.map f))
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
