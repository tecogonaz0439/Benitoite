import Benitoite.Release.Refinement.PatternBindings
import Benitoite.Release.Refinement.ClosureStateLeaves

/-! # 照合が選んだ束縛型の注釈 -/
namespace Benitoite.Release.Refinement
noncomputable section
open PatternBindings

private def annotationType (normal : Bool) (a : Ty) : Ty := if normal then a.norm else a

@[simp] private theorem annotationType_false : annotationType false = id := rfl
@[simp] private theorem annotationType_true : annotationType true = Ty.norm := rfl

private theorem constructor_ordinary {P B Ψ c tys vs cd ts}
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.con c tys vs) (.data cd.data ts))
    (hc : P.cons c = some cd) : ∀ a ∈ ts, a.Ordinary := by
  obtain ⟨cd',hc',_,hk,_,_,us,he,hr⟩ := hv.inv_con rfl
  have eq := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  have hu : us = Ty.normTys ts := (Ty.data.inj he).2.symm
  subst us
  have ho := args_ordinary hr (by
    intro a hm
    obtain ⟨b,hb,rfl⟩ := List.mem_map.mp (show a ∈ tys.map Ty.norm from by simpa using hm)
    exact (Ty.ordinary_norm _).mpr (hk.ordinary b hb))
  intro a ha
  exact (Ty.ordinary_norm _).mp (ho _ (by simpa only [Ty.normTys_eq_map] using List.mem_map.mpr ⟨a,ha,rfl⟩))

mutual
  private theorem annotations_aux {P B Ψ R Γ Φ cap pat a δ}
      (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hp : PatTy P pat a δ) (normal : Bool) {v ws}
      (ha : Ty.Annotation P [] Γ (annotationType normal a))
      (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
      (hm : matchVal pat v = some ws) :
      TypeAnnotations P [] Γ (δ.map (annotationType normal)) := by
    match hp with
    | .P_Wild | .P_Const _ | .P_RangeInt | .P_RangeChar => intro t ht; cases ht
    | .P_Var => intro t ht; cases List.mem_singleton.mp ht; exact ha
    | .P_Convert (a := a0) he hp =>
      have ha' : Ty.Annotation P [] Γ a.norm := by
        cases normal <;> simpa only [annotationType_false,annotationType_true,id_eq,Ty.norm_idem] using ha.norm
      have ha0 : Ty.Annotation P [] Γ a0.norm := he.symm ▸ ha'
      have heq : cap.closeTy a0 = cap.closeTy a := Ty.rawBind_norm_congr (valEnv cap.env) he
      have hv0 : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a0) := heq.symm ▸ hv
      have hh := annotations_aux valid hc hp true ha0 hv0 hm
      cases normal <;> simpa only [annotationType_false,annotationType_true,id_eq,List.map_map,Function.comp_def,Ty.norm_idem,List.map_id] using hh
    | .P_Refined (a := a) (φ := p) hp =>
      have ha0 : Ty.Annotation P [] Γ (annotationType normal a) := by
        cases normal with
        | false => exact ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩
        | true =>
          exact annotation_norm_subset ha (by simp [annotationType]) (by
            intro q hq
            simpa only [annotationType_false,annotationType_true,id_eq,Ty.predicates_norm,Ty.refinementPredicates] using List.mem_append_left p.conjuncts hq)
      have hac : Ty.Annotation P [] [] (cap.closeTy a) := by
        have hh := hc.substOk.annotation ha0
        cases normal <;> simpa only [annotationType_false,annotationType_true,id_eq,substTyValues_norm_source,Capture.closeTy] using hh
      have hl : Ty.LeQ P [] [] (cap.closeTy (.refined a p)) (cap.closeTy a) :=
        (Ty.LeQ.forget (Γ := Γ) (Φ := Φ)).bind (valEnv cap.env) hc.transport
      exact annotations_aux valid hc hp normal ha0 (.V_Sub hv hl hac.wf hac.sorted hac.declared) hm
    | .P_Con (c := c) (cd := cd) (ts := ts) hl hn hw hp =>
      have ih := fun (vs ws : List Val) => annotations_list_aux valid hc hp normal (vs := vs) (ws := ws)
      have hat : TypeAnnotations P [] Γ (ts.map (annotationType normal)) := by
        cases normal with
        | false => simpa only [annotationType_false,annotationType_true,id_eq,List.map_id] using ha.data_args
        | true => simpa only [annotationType_false,annotationType_true,id_eq,Ty.norm,Ty.normTys_eq_map] using ha.data_args
      cases v <;> simp only [matchVal] at hm
      all_goals try cases hm
      case con c' tys vs =>
        split at hm
        · rename_i he
          subst c'
          have hv' : HasTypeVQ P B Ψ Qempty [] [] [] (.con c tys vs) (.data cd.data (ts.map cap.closeTy)) := by
            simpa only [Capture.closeTy,substTyValues,Ty.bind_data,substTyValues_eq_bind] using hv
          have htsOrd := constructor_ordinary hv' hl
          have ho : ∀ t ∈ ts, t.Ordinary := by
            intro t ht
            exact (Ty.ordinary_bind_values t cap.env).mp (htsOrd _ (List.mem_map.mpr ⟨t,ht,rfl⟩))
          have hfield : TypeAnnotations P [] Γ (cd.args.map (Ty.subst ts [])) := by
            intro t ht
            obtain ⟨x,hx,rfl⟩ := List.mem_map.mp ht
            have hlen : (ts.map (annotationType normal)).length = cd.ntys := by simpa using hn
            have hh := valid.field_annotation hl hx hlen hat (by
              intro t ht; obtain ⟨u,hu,rfl⟩ := List.mem_map.mp ht
              cases normal with
              | false => exact ho u hu
              | true => exact (Ty.ordinary_norm u).mpr (ho u hu))
            cases normal <;> simpa only [annotationType_false,annotationType_true,id_eq,List.map_id,←Ty.normTys_eq_map,Ty.subst_norm_images] using hh
          have hvs := constructor_values valid rfl hv' hl
          have heq : (cd.args.map (Ty.subst ts [])).map cap.closeTy = cd.args.map (Ty.subst (ts.map cap.closeTy) []) := by
            rw [List.map_map]
            apply List.map_congr_left
            intro x hx
            exact dependent_result_close (hw x hx) ts cap
          rw [←heq] at hvs
          have hann : TypeAnnotations P [] Γ ((cd.args.map (Ty.subst ts [])).map (annotationType normal)) := by
            cases normal
            · simpa only [annotationType_false,annotationType_true,id_eq,List.map_id] using hfield
            · simpa only [annotationType_true,Ty.normTys_eq_map] using hfield.norm
          exact ih vs ws hann hvs hm
        · cases hm
      case atError detail =>
        split at hm
        · rename_i he
          subst he
          obtain ⟨cd',hl',hz,hargs,hpub⟩ := atError_declaration hv rfl
          have he := Option.some.inj (hl.symm.trans hl')
          subst cd'
          have hts : ts = [] := List.eq_nil_iff_length_eq_zero.mpr (hn.trans hz)
          subst ts
          have hfield : TypeAnnotations P [] Γ (cd.args.map (Ty.subst [] [])) := by
            intro t ht; obtain ⟨x,hx,rfl⟩ := List.mem_map.mp ht
            exact valid.field_annotation hl hx hz.symm (by intro t ht; cases ht) (by intro t ht; cases ht)
          have hvals := detail.values_typed P B Ψ Qempty [] [] [] hpub
          have heq : (cd.args.map (Ty.subst [] [])).map cap.closeTy = atErrorFields := by rw [hargs]; rfl
          have hann : TypeAnnotations P [] Γ ((cd.args.map (Ty.subst [] [])).map (annotationType normal)) := by
            cases normal
            · simpa only [annotationType_false,annotationType_true,id_eq,List.map_id] using hfield
            · simpa only [annotationType_true,Ty.normTys_eq_map] using hfield.norm
          exact ih detail.values ws hann (heq ▸ hvals) hm
        · cases hm
    | .P_List (before := before) (rest := rest) (after := after) (a := a) hb hafter _ =>
      have harg : Ty.Annotation P [] Γ (annotationType normal a) := by cases normal <;> exact ⟨ha.wf,ha.sorted,ha.declared⟩
      cases v <;> simp only [matchVal] at hm
      all_goals try cases hm
      rename_i elems
      have hv' : HasTypeVQ P B Ψ Qempty [] [] [] (.list elems) (.list (cap.closeTy a)) := hv
      obtain ⟨heach,_⟩ := list_elements hv' rfl
      change HasTypeEachQ P B Ψ Qempty [] [] [] elems (cap.closeTy a) at heach
      by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length else before.length + after.length = elems.length)
      · rw [ite_eq_left hlen] at hm
        cases hl : matchList before (elems.take before.length) with
        | none => simp [hl] at hm
        | some left =>
          cases hr : matchList after (elems.drop (elems.length-after.length)) with
          | none => simp [hl,hr] at hm
          | some right =>
            have hn : before.length + after.length ≤ elems.length := by cases rest <;> simp_all
            have hleft := annotations_list_aux valid hc hb normal
              (by simpa only [List.map_replicate] using (show TypeAnnotations P [] Γ (List.replicate before.length (annotationType normal a)) from by
                intro t ht; cases List.mem_replicate.mp ht |>.2; exact harg))
              (by
                simpa only [List.map_replicate] using values_replicate
                  (each_of_mem (fun v h => heach.member (List.mem_of_mem_take h)))
                  (show (elems.take before.length).length = before.length by simp; omega)) hl
            have hright := annotations_list_aux valid hc hafter normal
              (by simpa only [List.map_replicate] using (show TypeAnnotations P [] Γ (List.replicate after.length (annotationType normal a)) from by
                intro t ht; cases List.mem_replicate.mp ht |>.2; exact harg))
              (by
                simpa only [List.map_replicate] using values_replicate
                  (each_of_mem (fun v h => heach.member (List.mem_of_mem_drop h)))
                  (show (elems.drop (elems.length-after.length)).length = after.length by simp; omega)) hr
            intro t ht
            simp only [List.map_append,List.mem_append] at ht
            rcases ht with (ht | ht) | ht
            · exact hleft t ht
            · cases rest with
              | none => cases ht
              | some r => cases r with
                | skip => cases ht
                | bind =>
                  cases List.mem_singleton.mp ht
                  cases normal <;> exact ⟨harg.wf,harg.sorted,harg.declared⟩
            · exact hright t ht
      · rw [ite_eq_right hlen] at hm; cases hm
  termination_by structural hp
  private theorem annotations_list_aux {P B Ψ R Γ Φ cap ps as δ}
      (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
      (hp : PatTys P ps as δ) (normal : Bool) {vs ws}
      (ha : TypeAnnotations P [] Γ (as.map (annotationType normal)))
      (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs (as.map cap.closeTy))
      (hm : matchList ps vs = some ws) :
      TypeAnnotations P [] Γ (δ.map (annotationType normal)) := by
    match hp with
    | .nil => intro t ht; cases ht
    | .cons (p := p) (ps := ps) hp hs =>
      cases hv with
      | cons hv ht =>
        rename_i v vs
        simp only [matchList] at hm
        cases hl : matchVal p v with
        | none => simp [hl] at hm
        | some left =>
          cases hr : matchList ps vs with
          | none => simp [hl,hr] at hm
          | some right =>
            have hleft := annotations_aux valid hc hp normal (ha _ List.mem_cons_self) hv hl
            have hright := annotations_list_aux valid hc hs normal
              (fun t ht => ha t (List.mem_cons_of_mem _ ht)) ht hr
            intro t ht
            rcases List.mem_append.mp (show t ∈ _ ++ _ from by simpa only [List.map_append] using ht) with ht | ht
            · exact hleft t ht
            · exact hright t ht
  termination_by structural hp
end

theorem PatTy.bindings_annotation {P B Ψ R Γ Φ cap pat a δ v ws}
    (valid : P.VarianceValid)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : PatTy P pat a δ) (ha : Ty.Annotation P [] Γ a)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hm : matchVal pat v = some ws) : TypeAnnotations P [] Γ δ := by
  simpa only [annotationType_false,annotationType_true,id_eq,List.map_id] using annotations_aux valid hc hp false ha hv hm


theorem AltsTy.bindings_annotation {P B Ψ R Γ Φ cap alts a δ v ws}
    (valid : P.VarianceValid)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hp : AltsTy P alts a δ) (ha : Ty.Annotation P [] Γ a)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v (cap.closeTy a))
    (hm : firstAlt v alts = some ws) : TypeAnnotations P [] Γ δ := by
  obtain ⟨alt,hmem,us,hmatch⟩ := MatchFacts.firstAlt_some_mem hm
  obtain ⟨γ,hpat,_,hslots⟩ := hp.2.2.2 alt hmem
  have hγ := hpat.bindings_annotation valid hc ha hv hmatch
  exact fun t ht => hγ t (selectSlots_mem hslots t ht)

end
end Benitoite.Release.Refinement
