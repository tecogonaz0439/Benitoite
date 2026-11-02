import Benitoite.Release.Refinement.TypedMeaning
import Benitoite.Release.Refinement.CaptureRegularity

/-! # パターンの束縛へ渡す型の形成（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement.PatternBindings
noncomputable section

theorem observable_annotation {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hΓ : Γ = [])
    (observable : ∃ s, a.HasSort s) : Ty.Annotation P C Γ a := by
    match h with
    | .V_Var hi ho => subst Γ; simp at hi
    | .V_Const (c := c) _ => cases c <;> exact ⟨by trivial, by trivial, by trivial⟩
    | .V_Lam _ hw hs _ hd => exact ⟨hw, hs, hd⟩
    | .V_DependentLam ha _ | .V_Closure ha _ _ => exact ha
    | .V_Fun _ _ _ hi | .V_Prim _ _ _ _ hi | .V_Op _ _ _ hi |
        .V_ExternalRef _ _ _ hi => exact hi.result
    | .V_ExternalHandle _ _ _ _ _ _ ha | .V_Dict _ _ _ _ _ _ _ ha |
        .V_Con _ _ _ _ _ ha | .V_Raise ha _ _ _ => exact ha
    | .V_PathBases _ | .V_ScopePattern _ _ _ |
        .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ | .V_Bytes _ =>
      exact ⟨by trivial, by trivial, by trivial⟩
    | .V_Checked (o := o) (k := k) (range := r) _ _ _ => exact checked_annotation P C Γ o k r
    | .V_AtError he =>
      rw [he.errorType_eq]
      exact ⟨by trivial, by trivial, by simpa only [he.errorType_eq] using he.errorType_declared (C := C) (Γ := Γ)⟩
    | .V_Map _ _ _ _ ha hb => exact ⟨⟨ha.wf, hb.wf⟩, ⟨ha.sorted, hb.sorted⟩, ⟨ha.declared, hb.declared⟩⟩
    | .V_Set _ _ ha => exact ⟨ha.wf, ha.sorted, ha.declared⟩
    | .V_List _ hwa hsa hda => exact ⟨hwa, hsa, hda⟩
    | .V_LocRef .. | .V_LocLazy .. | .V_Super .. =>
      obtain ⟨s, hs⟩ := observable
      cases hs
    | .V_Sub _ _ hwb hsb hdb => exact ⟨hwb, hsb, hdb⟩
    | .V_Normal hv => exact (observable_annotation hv hΓ (by
        obtain ⟨s, hs⟩ := observable
        exact ⟨s, (Ty.hasSort_norm _ _).mp hs⟩)).norm
    | .V_Refine hv hsort _ hsp hwp _ hda hdp =>
      have ha := observable_annotation hv hΓ ⟨_,hsort⟩
      exact ⟨⟨ha.wf, hwp, hsort.ordinary⟩, ⟨ha.sorted, hsp⟩, ⟨hda, hdp⟩⟩
termination_by structural h

theorem refined_annotation {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hΓ : Γ = [])
    (preds : a.refinementPredicates ≠ []) : Ty.Annotation P C Γ a := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Normal hv =>
    exact (refined_annotation hv hΓ (by simpa only [Ty.predicates_norm] using preds)).norm
  | .V_Refine hv hi _ hs hw _ hda hdp =>
    have ha := observable_annotation hv hΓ ⟨_,hi⟩
    exact ⟨⟨ha.wf,hw,hi.ordinary⟩,⟨ha.sorted,hs⟩,⟨hda,hdp⟩⟩
  | .V_AtError he => rw [he.errorType_eq] at preds; exact (preds rfl).elim
  | .V_Const (c := c) _ => cases c <;> exact (preds rfl).elim
  | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. =>
    exact False.elim (preds rfl)
  | .V_Lam .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_List .. | .V_Map .. |
    .V_Set .. | .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. |
    .V_Bytes .. | .V_Con .. | .V_Super .. => exact (preds rfl).elim
termination_by structural h

theorem notCont_of_predicates {a : Ty} {nr nt nv} (hw : a.WF nr nt nv)
    (hp : a.refinementPredicates ≠ []) : a.NotContCore := by
  cases a with
  | refined a p => exact hw.2.2
  | _ => exact (hp rfl).elim

theorem annotation_norm_subset {P C Γ a} {b : Ty} (ha : Ty.Annotation P C Γ a)
    (hc : a.core = b.norm.core)
    (hp : ∀ p ∈ b.refinementPredicates, p ∈ a.refinementPredicates) :
    Ty.Annotation P C Γ b.norm := by
  have hbc : Ty.Annotation P C Γ b.norm.core := by
    rw [←hc]; exact ⟨ha.wf.core,ha.sorted.core,ha.declared.core⟩
  have hs : b.norm.Sorted Γ := by
    apply Ty.sorted_of_core_predicates _ hbc.sorted
    intro p hm
    rw [Ty.predicates_norm] at hm
    simpa only [hc] using ha.sorted.predicates p (hp p hm)
  refine ⟨?_,hs,?_⟩
  · rw [← Ty.pack_parts_norm b]
    cases he : b.norm.refinementPredicates with
    | nil => exact hbc.wf
    | cons p ps =>
      refine ⟨hbc.wf,Pred.wf_ofConjuncts (fun q hq => ?_),?_⟩
      · rw [←he,Ty.predicates_norm] at hq
        exact ha.wf.predicates q (hp q hq)
      · have hne : a.refinementPredicates ≠ [] := by
          intro hn
          have hm := hp p (by rw [←Ty.predicates_norm,he]; simp)
          rw [hn] at hm; cases hm
        simpa only [Ty.NotContCore,hc,Ty.core_idem] using notCont_of_predicates ha.wf hne
  · rw [← Ty.pack_parts_norm b]
    cases he : b.norm.refinementPredicates with
    | nil => exact hbc.declared
    | cons p ps =>
      refine ⟨hbc.declared,Pred.Declared.ofConjuncts ?_⟩
      intro q hq
      rw [←he,Ty.predicates_norm] at hq
      simpa only [hc] using ha.declared.predicates q (hp q hq)

theorem forget_refined {P B Ψ Q C Γ Φ v} {a : Ty} {p : Pred}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v (Ty.refined a p).norm) (hΓ : Γ = []) :
    HasTypeVQ P B Ψ Q C Γ Φ v a.norm := by
  by_cases he : p.conjuncts = []
  · have eq : (Ty.refined a p).norm = a.norm := by
      rw [Ty.norm,Ty.refineNorm,he,List.append_nil,Ty.core_norm,←Ty.predicates_norm]
      simpa only [Ty.core_norm,Ty.predicates_norm,Ty.norm_idem] using Ty.pack_parts_norm a
    rw [eq] at h; exact h
  · have ha := refined_annotation h hΓ (by
      simp only [Ty.predicates_norm,Ty.refinementPredicates]
      intro hn; have hh := List.append_eq_nil_iff.mp hn; exact he hh.2)
    have hb := annotation_norm_subset (b := a) ha (by simp) (by
      intro q hq; simpa only [Ty.predicates_norm,Ty.refinementPredicates] using List.mem_append_left p.conjuncts hq)
    exact .V_Sub h (Ty.LeQ.norm (.forget (a := a) (p := p))) hb.wf hb.sorted hb.declared

theorem args_ordinary {P Γ Φ vars xs ys} (h : TypeArgsLe P Γ Φ vars xs ys)
    (ho : ∀ a ∈ xs, Ordinary a) : ∀ b ∈ ys, Ordinary b := by
  match h with
  | .nil => intro b hb; cases hb
  | .covariant_cons hl ht =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact hl.notContCore.mp (ho _ List.mem_cons_self)
    · exact args_ordinary ht (fun a ha => ho a (List.mem_cons_of_mem _ ha)) b hb
  | .contravariant_cons hl ht =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · exact hl.notContCore.mpr (ho _ List.mem_cons_self)
    · exact args_ordinary ht (fun a ha => ho a (List.mem_cons_of_mem _ ha)) b hb
  | .invariant_cons he ht =>
    intro b hb
    rcases List.mem_cons.mp hb with rfl | hb
    · apply (Ty.ordinary_norm _).mp
      rw [←he]
      exact (Ty.ordinary_norm _).mpr (ho _ List.mem_cons_self)
    · exact args_ordinary ht (fun a ha => ho a (List.mem_cons_of_mem _ ha)) b hb

theorem values_of_get {P B Ψ Q C Γ Φ vs as}
    (hlen : vs.length = as.length)
    (get : ∀ (i : Nat) a, as[i]? = some a → ∃ v, vs[i]? = some v ∧ HasTypeVQ P B Ψ Q C Γ Φ v a) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs as := by
  induction as generalizing vs with
  | nil => cases vs <;> first | exact .nil | cases hlen
  | cons a as ih =>
    cases vs with
    | nil => cases hlen
    | cons v vs =>
      obtain ⟨w,hw,ht⟩ := get 0 a rfl
      cases Option.some.inj hw
      exact .cons ht (ih (by simpa using hlen) (by
        intro i a ha
        exact get (i+1) a ha))

theorem constructor_values {P B Ψ Q C Γ Φ c tys vs cd ts}
    (valid : P.VarianceValid) (hΓ : Γ = [])
    (hv : HasTypeVQ P B Ψ Q C Γ Φ (.con c tys vs) (.data cd.data ts))
    (hc : P.cons c = some cd) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (cd.args.map (Ty.subst ts [])) := by
  have ha := observable_annotation hv hΓ ⟨.data,rfl⟩
  obtain ⟨cd',hc',hn,hk,_,hs,us,he,hr⟩ := hv.inv_con rfl
  have eq := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  have hu : us = Ty.normTys ts := (Ty.data.inj he).2.symm
  subst us
  have ho := args_ordinary hr (by
    intro a hm
    obtain ⟨b,hb,rfl⟩ := List.mem_map.mp (show a ∈ tys.map Ty.norm from by simpa using hm)
    exact (Ty.ordinary_norm _).mpr (hk.ordinary b hb))
  apply values_of_get (by simpa only [List.length_map] using hs.length)
  intro i a hi
  cases ht : cd.args[i]? with
  | none => simp [List.getElem?_map,ht] at hi
  | some t =>
    have heq : a = t.subst ts [] := by simpa [List.getElem?_map,ht] using hi.symm
    subst a
    obtain ⟨w,hw,hwt⟩ := hv.con_field_by_type hc rfl ht valid ha.data_args.norm ho
    rw [Ty.subst_norm_images] at hwt
    exact ⟨w,hw,hwt⟩

theorem atError_declaration {P B Ψ Q C Γ Φ detail a v}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hval : v = .atError detail) :
    ∃ cd, P.cons "Scope.ScopeError.At" = some cd ∧ cd.ntys = 0 ∧ cd.args = atErrorFields := by
  match h with
  | .V_AtError hs =>
    obtain ⟨cd,hc,_,hn,ha⟩ := hs.standard.2.2
    exact ⟨cd,hc,hn,ha⟩
  | .V_Sub hv .. | .V_Normal hv | .V_Refine hv .. => exact atError_declaration hv hval
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_List .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hval

termination_by structural h

theorem each_of_mem {P B Ψ Q C Γ Φ vs a}
    (h : ∀ v ∈ vs, HasTypeVQ P B Ψ Q C Γ Φ v a) : HasTypeEachQ P B Ψ Q C Γ Φ vs a := by
  induction vs with
  | nil => exact .nil
  | cons v vs ih => exact .cons (h v List.mem_cons_self) (ih (fun w hw => h w (List.mem_cons_of_mem _ hw)))

theorem list_elements {P B Ψ Q C Γ Φ vs} {a : Ty}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.list vs) (Ty.list a).norm) (hΓ : Γ = []) :
    HasTypeEachQ P B Ψ Q C Γ Φ vs a.norm ∧ Ty.Annotation P C Γ a.norm := by
  have ha := observable_annotation h hΓ ⟨.list,rfl⟩
  have han : Ty.Annotation P C Γ a.norm := ⟨ha.wf,ha.sorted,ha.declared⟩
  obtain ⟨b,hb,c,hc,hl⟩ := h.inv_list rfl
  have he : c = a.norm := (Option.some.inj hc).symm
  subst c
  exact ⟨each_of_mem (fun v hv => .V_Sub (hb.member hv) hl han.wf han.sorted han.declared),han⟩

theorem values_append {P B Ψ Q C Γ Φ vs ws as bs}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (k : HasTypeVsQ P B Ψ Q C Γ Φ ws bs) :
    HasTypeVsQ P B Ψ Q C Γ Φ (vs++ws) (as++bs) := by
  match h with
  | .nil => exact k
  | .cons hv hs => exact .cons hv (values_append hs k)

theorem values_replicate {P B Ψ Q C Γ Φ vs a n}
    (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hn : vs.length = n) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (List.replicate n a) := by
  subst n
  match h with
  | .nil => exact .nil
  | .cons hv hs => exact .cons hv (values_replicate hs rfl)

end
end Benitoite.Release.Refinement.PatternBindings
