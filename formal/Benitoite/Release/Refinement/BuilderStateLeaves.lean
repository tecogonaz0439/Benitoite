import Benitoite.Release.Refinement.StoreGeneral
import Benitoite.Release.Refinement.RuntimeBuilderScope
import Benitoite.Release.Refinement.BuilderValueTyping

/-! # 構築器の実際の捕捉と専用セルの状態の葉 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem builder_new_inputs {P B Ψ Q C Γ Φ R code a e L kind body}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hh : code = .builderLet kind body) :
    ∃ t et, Ty.Annotation P C Γ kind.contents ∧
      TypeArgsKinded P C [kind.contents] [.value] ∧
      HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
        body (t.shiftV 1 0) (et.shiftV 1 0)
        (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) L) ∧
      t.Declared P C Γ ∧ Ty.LeQ P Γ Φ t a ∧ Eff.Covers Γ Φ e et := by
  match h with
  | .C_BuilderLet hk hkind hb hd => cases hh; exact ⟨_,_,hk,hkind,hb,hd,.refl,.refl _ _ _⟩
  | .C_Sub hb hl he _ _ _ =>
    obtain ⟨t,et,hk,hkind,hb,hd,hle,hcov⟩ := builder_new_inputs hb hh
    exact ⟨t,et,hk,hkind,hb,hd,.trans hle hl,he.trans hcov⟩
  | .C_Normal hb =>
    obtain ⟨t,et,hk,hkind,hb,hd,hle,hcov⟩ := builder_new_inputs hb hh
    exact ⟨t,et,hk,hkind,hb,hd,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_Eff hb he =>
    obtain ⟨t,et,hk,hkind,hb,hd,hle,hcov⟩ := builder_new_inputs hb hh
    exact ⟨t,et,hk,hkind,hb,hd,hle,he.trans hcov⟩
  | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. |
    .C_ResumeL .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases hh
termination_by structural h

private theorem builder_empty_cell {P B σ} {Ψ : StoreTy} {l : Nat} {kind : BuilderKind}
    (ha : Ty.Annotation P [] [] kind.contents) :
    CellOk P B σ (Ψ.put l (.builder kind)) l (.builder kind.empty) := by
  refine ⟨kind,by simp [StoreTy.put],?_,?_⟩
  · cases kind with
    | string => exact ⟨by decide,trivial⟩
    | bytes => exact ⟨Nat.zero_le _,by intro b hb; cases hb⟩
    | list a => exact ⟨Nat.zero_le _,⟨ha.wf,ha.sorted,ha.declared⟩,.nil⟩
  · cases kind <;> trivial

private theorem builder_location_annotation {P} {kind : BuilderKind}
    (ha : Ty.Annotation P [] [] kind.contents) :
    (LocTy.builder kind).WF ∧ (LocTy.builder kind).Sorted ∧ (LocTy.builder kind).Declared P := by
  cases kind <;> first | exact ⟨trivial,trivial,trivial⟩ | exact ⟨ha.wf,ha.sorted,ha.declared⟩

private theorem close_kind_contents (cap : Capture) (kind : BuilderKind) :
    (substKind cap.env kind).contents = cap.closeTy kind.contents := by
  cases kind <;> rfl

private theorem builder_close_return (cap : Capture) (R : Option Ty) :
    cap.closeR ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst)) = cap.closeR R := by
  cases R with
  | none => rfl
  | some r => exact congrArg some (cap.closeTy_builder_image r)

private theorem builder_image_declared {P C Γ R}
    (hr : ∀ r, R = some r → r.Declared P C Γ) :
    ∀ r, ((R.map (Ty.shiftV 1 0)).map (substTyValues builderValueSubst)) = some r → r.Declared P C Γ := by
  intro r hh
  cases R with
  | none => cases hh
  | some t =>
    have heq := Option.some.inj hh
    rw [←builderValueSubst_eq,Ty.openValue_shift] at heq
    rw [←heq]
    exact (hr t rfl).norm

private theorem inner_done_all {P a t e f}
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e))) (ht : Ty.Annotation P [] [] t)
    (hc : Eff.Covers [] [] e f) (hn : f.Canonical) :
    Ty.Annotation P [] [] (.dependentFn (.done t f)) :=
  done_annotation_of_covers
    ⟨⟨ht.wf,ha.wf.2⟩,⟨ht.sorted,ha.sorted.2⟩,⟨ht.declared,ha.declared.2⟩⟩ hc hn

/-- 捕捉元の本体を hidden な値束縛だけ取り除いて実行し、専用セルを割り当てる。 -/
theorem StateTyE.builder_new {P B σ Eb q kind body k μ l}
    (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderLet kind body) (hl : μ l = none) :
    Step P B σ (.run q k μ) none
      (.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty))) ∧
    StateTyE P B σ Eb
      (.run (.mk q.capture (body.subst builderValueSubst (builderLocalSubst l))) k (μ.set l (.builder kind.empty))) := by
  refine ⟨.E_BuilderNew hv hl,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  have hann := hq.annotation
  obtain ⟨cap,Γ,Φ,Rs,code,as,es,L,ρ,rfl,hc,hb,hL,hR,ha,hee,hr⟩ := hq.open_zero
  cases code
  case builderLet kind0 body0 =>
    obtain ⟨t,et,hka,hkind,hbody,htd,hle,hcov⟩ := builder_new_inputs hb rfl
    simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv
    obtain ⟨rfl,rfl⟩ := Comp.builderLet.inj hv
    have hka' := hc.substOk.annotation hka
    change Ty.Annotation P [] [] (cap.closeTy kind0.contents) at hka'
    rw [←close_kind_contents] at hka'
    obtain ⟨hwk,hsk,hdk⟩ := builder_location_annotation hka'
    have hs' := hs.allocate_cell hB.values hl hwk hsk hdk (builder_empty_cell hka')
    have hnone : Ψ l = none := by
      cases hx : Ψ l with
      | none => rfl
      | some x => exact False.elim (hs.domain l x hx hl)
    have hext := StoreTy.extends_put (x := .builder (substKind cap.env kind0)) hnone
    have hbody' := (hbody.store_extend hB.values hs.wf hext).builderBody_image hB.substitutions hs'.wf
    have hcap' := hc.store hB.values hs.wf hext.preservesNormals
    have hlocal := (fun i kind hi => by
      obtain ⟨loc,hr,ht⟩ := hL i kind hi
      exact ⟨loc,hr,hext loc _ ht⟩ : CaptureLocals (Ψ.put l (.builder (substKind cap.env kind0))) cap.env L ρ)
    have hlocal' := CaptureLocals.pushBuilder (CaptureLocals.imageLocal hlocal) (l := l) (kind := imageKind kind0)
      (by rw [substKind_image]; simp [StoreTy.put])
    have hresult := capture_comp_annotation hs.wf hs.sorted hs.declared
      (hc.extendHidden (.const .unit) trivial) hbody
    rw [Capture.closeTy_shift] at hresult
    have hcov' : Eff.Covers [] [] (cap.closeEff es) (cap.closeEff et) := hcov.bind (valEnv cap.env)
    rw [hee] at hcov'
    have hann' := inner_done_all hann hresult hcov' (Eff.norm_idem _)
    have hAnnImage : Ty.Annotation P [] [] (.dependentFn (.done
        (cap.closeTy (substTyValues builderValueSubst (t.shiftV 1 0)))
        (cap.closeEff (substEffValues builderValueSubst (et.shiftV 1 0))))) := by
      rwa [Capture.closeTy_builder_image,Capture.closeEff_builder_image]
    have hdst := ClosureTy.capture_resolved_closed hcap' hbody' hlocal' hAnnImage
      ((builder_close_return cap Rs).trans hR) (builder_image_declared hr)
    rw [Capture.closeTy_builder_image,Capture.closeEff_builder_image] at hdst
    rw [←Comp.builderBody_resolve] at hdst
    have hle' := hle.bind (valEnv cap.env) hc.transport
    change Ty.LeQ P [] [] (cap.closeTy t) (cap.closeTy as) at hle'
    rw [ha] at hle'
    obtain ⟨hdst,hsub⟩ := hdst.widen_atoms (he.covers.trans hcov')
    have hscope := Comp.ClosedAt.builder_subst_scope (l := l) (c := 0) hcl.2.2 had.2 (Nat.zero_le _)
    refine ⟨_,R,cap.closeTy t,b,e,_,hs',hdst,hsub,(ContTy.K_Sub hk hle').store hB.values hs.wf hext,
      ⟨had.1,?_⟩,⟨hcl.1,?_⟩,hkc,?_⟩
    · simpa only [upSubst_zero,upLocalSubst_zero] using hscope.2
    · simpa only [upSubst_zero,upLocalSubst_zero,Closure.capture,Nat.add_zero] using hscope.1
    · apply hμ.set_cell
      cases kind0 <;> trivial
  case checkAt _ _ _ bs _ _ _ =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)


private theorem close_builder_operation {P B Ψ Q C Γ Φ Rs m a e L cap R kind op ref args ρ}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hl : CaptureLocals Ψ cap.env L ρ)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .builderOp kind op ref args) :
    HasTypeCQ P B Ψ Qempty [] [] [] R
      (.builderOp (substKind cap.env kind) op (ref.subst ρ) (closeVals cap args))
      (cap.closeTy a) (cap.closeEff e) [] := by
  match h with
  | .C_BuilderOp ha hk hr hv =>
    subst Q C
    cases hm
    have hlocal : LocalSubstOk Ψ L cap.env ρ [] := by
      intro i b hi
      obtain ⟨l,he,ht⟩ := hl i b hi
      rw [he]
      exact .loc ht
    have ha' := hc.substOk.annotation ha
    have hk' := hk.subst cap.env
    have hr' := hr.subst hw hlocal
    have hv' := close_values_typed hP hPB hB hw hs hd hc hv
    simp only [Capture.closeTy,Capture.closeEff]
    rw [←BuilderOp.resultType_subst,substEffValues_empty]
    exact .C_BuilderOp (by simpa only [BuilderKind.contents_subst] using ha')
      (by simpa only [BuilderKind.contents_subst,List.map_cons,List.map_nil] using hk') hr'
      (by simpa only [BuilderOp.parameters_subst,Capture.closeTy] using hv')
  | .C_Sub hb hle he hwf hsort hdecl =>
    have hh := close_builder_operation hb hP hPB hB hw hs hd hc hl hQ hC hm
    subst Q C
    have ht := hc.substOk.annotation (Ty.Annotation.mk hwf hsort hdecl)
    exact .C_Sub hh (hle.bind (valEnv cap.env) hc.transport)
      (he.bind (valEnv cap.env)) ht.wf ht.sorted ht.declared
  | .C_Normal hb =>
    have hh := close_builder_operation hb hP hPB hB hw hs hd hc hl hQ hC hm
    simpa only [Capture.closeTy,substTyValues_norm_source] using hh
  | .C_Eff hb he =>
    have hh := close_builder_operation hb hP hPB hB hw hs hd hc hl hQ hC hm
    subst Q C
    exact .C_Eff hh (he.bind (valEnv cap.env))
  | .C_BuilderLet .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. |
    .C_ResumeL .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

private theorem builder_arguments_resolve {P B Ψ Q C Γ Φ Rs m a e L kind op ref args}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L) (hm : m = .builderOp kind op ref args) (ρ) :
    Val.resolveLocalsList ρ args = args := by
  match h with
  | .C_BuilderOp _ _ _ hv => cases hm; exact hv.resolve_id ρ
  | .C_Sub hb .. | .C_Normal hb | .C_Eff hb _ => exact builder_arguments_resolve hb hm ρ
  | .C_BuilderLet .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. |
    .C_ResumeL .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases hm
termination_by structural h

theorem builder_view_operation {P B Ψ R q a e kind op ref args}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .builderOp kind op ref args) :
    HasTypeCQ P B Ψ Qempty [] [] [] R (.builderOp kind op ref args) a e [] := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,hL,_,ha,he,_⟩ := hq.open_zero
  cases m
  case builderOp kind0 op0 ref0 args0 =>
    have hh := close_builder_operation hb hP hPB hB hw hs hd hc hL rfl rfl rfl
    simp only [Comp.resolveLocals,builder_arguments_resolve hb rfl ρ,Closure.view,Closure.code,Closure.capture] at hv
    obtain ⟨hkind,hop,href,hargs⟩ := Comp.builderOp.inj hv
    rw [hkind,hop,href,hargs,ha,he] at hh
    exact hh
  case checkAt _ _ _ bs _ _ _ =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view,Closure.code] at hv; injection hv)


theorem builder_operation_inputs {P B Ψ Q C Γ Φ R code a e L kind op ref args}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hh : code = .builderOp kind op ref args) :
    Ty.Annotation P C Γ kind.contents ∧ LocalRef.HasKind Ψ L ref kind ∧
      HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind) ∧ Ty.LeQ P Γ Φ (op.resultType kind) a := by
  match h with
  | .C_BuilderOp ha _ hr hv => cases hh; exact ⟨ha,hr,hv,.refl⟩
  | .C_Sub hb hl _ _ _ _ =>
    obtain ⟨ha,hr,hv,hle⟩ := builder_operation_inputs hb hh
    exact ⟨ha,hr,hv,.trans hle hl⟩
  | .C_Normal hb =>
    obtain ⟨ha,hr,hv,hle⟩ := builder_operation_inputs hb hh
    exact ⟨ha,hr,hv,.trans hle (.convert (Ty.norm_idem _).symm)⟩
  | .C_Eff hb _ => exact builder_operation_inputs hb hh
  | .C_BuilderLet .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. |
    .C_ResumeL .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases hh
termination_by structural h

theorem builder_local_inv {Ψ L kind ref l}
    (h : LocalRef.HasKind Ψ L ref kind) (hh : ref = .loc l) :
    ∃ k, Ψ l = some (.builder k) ∧ k.norm = kind.norm := by
  match h with
  | .loc hp => cases hh; exact ⟨_,hp,rfl⟩
  | .normal h =>
    obtain ⟨k,hp,he⟩ := builder_local_inv h hh
    exact ⟨k,hp,he.trans (BuilderKind.norm_idem _).symm⟩
  | .bound _ => cases hh
termination_by structural h

private theorem builder_cell_annotation {P B Ψ kind c}
    (h : BuilderCellOk P B Ψ kind c) : Ty.Annotation P [] [] kind.contents := by
  cases kind <;> cases c <;> try cases h.2
  · exact ⟨trivial,trivial,trivial⟩
  · exact ⟨h.2.1.wf,h.2.1.sorted,h.2.1.declared⟩
  · exact ⟨trivial,trivial,trivial⟩

theorem builder_cell_convert {P B Ψ source target c}
    (h : BuilderCellOk P B Ψ source c) (ha : Ty.Annotation P [] [] target.contents)
    (he : source.norm = target.norm) : BuilderCellOk P B Ψ target c := by
  cases source <;> cases target <;> try cases he
  case string.string => exact h
  case bytes.bytes => exact h
  case list.list a b =>
    cases c <;> try cases h.2
    case list vs =>
      have heq : a.norm = b.norm := BuilderKind.list.inj he
      exact ⟨h.1,⟨ha.wf,ha.sorted,ha.declared⟩,
        PatternBindings.each_of_mem (fun v hv => .V_Sub (h.2.2.member hv) (.convert heq) ha.wf ha.sorted ha.declared)⟩

private theorem builder_closed_values {vs : List Val} (h : ∀ v ∈ vs, v.Ground) :
    Val.ClosedList 0 0 vs := by
  cases vs with
  | nil => trivial
  | cons v vs => exact ⟨h v List.mem_cons_self,builder_closed_values (fun w hw => h w (List.mem_cons_of_mem _ hw))⟩

/-- 成功応答の内容だけを更新し、元の Ψ と末尾の効果を使って通常値を返す。 -/
theorem StateTyE.builder_operation {P B σ Eb q kind op l args k μ c c' v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op (.loc l) args)
    (hl : μ l = some (.builder c)) (hr : builderApply op c args = some (.value c' v)) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret v)) k (μ.set l (.builder c'))) ∧
      StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.builder c'))) := by
  refine ⟨.E_BuilderOp hv hl hr,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨hkind,hlocal,hargs,hle⟩ := builder_operation_inputs
    (builder_view_operation hP hPB hB hs.wf hs.sorted hs.declared hq hv) rfl
  obtain ⟨source,hsource,hkn⟩ := builder_local_inv hlocal rfl
  obtain ⟨other,hother,hcell,hcad⟩ := hs.cell l _ hl
  cases Option.some.inj (hother.symm.trans hsource)
  have hargsg : Val.ClosedList 0 0 args := by
    exact builder_closed_values (fun w hw => hq.view_read_ground hcl (by rw [hv]; exact hw))
  have hva := Closure.view_adequate had
  rw [hv] at hva
  obtain ⟨hc',hvt⟩ := builderApply_value_typed (builder_cell_convert hcell hkind hkn) hargs hr
  obtain ⟨hcc,hvg,hca,hva'⟩ := builderApply_value_scope (hμ l _ hl) hcad hargsg hva hr
  have hsourceann := builder_cell_annotation hcell
  have hstored := builder_cell_convert hc' hsourceann hkn.symm
  have hs' := hs.write_cell (show CellOk P B σ Ψ l (.builder c') from ⟨source,hsource,hstored,hca⟩)
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  have hvt' := HasTypeVQ.V_Sub hvt hle ha.wf ha.sorted ha.declared
  have hret := hk.return_annotation rfl
  have hdst := ClosureTy.pure (.C_Return (R := R) hvt') ha.done_empty
    (fun r hh => ⟨(hret r hh).wf,(hret r hh).declared⟩) hq.result_normal hq.return_normal
  have hsub : Eff.Sub Eff.empty e := by
    constructor
    · intro x hx; cases hx
    · intro t ht; obtain ⟨x,hx,_⟩ := ht; cases hx
  exact ⟨Ψ,R,a,b,e,Eff.empty,hs',hdst,hsub,
    hk,⟨trivial,hva'⟩,⟨trivial,hvg⟩,hkc,hμ.set_cell hcc⟩

/-- エラー応答は内容を更新せず、元の継続とストアを使う。 -/
theorem StateTyE.builder_error {P B σ Eb q kind op l args k μ c r}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .builderOp kind op (.loc l) args)
    (hl : μ l = some (.builder c)) (hr : builderApply op c args = some (.error r)) :
    Step P B σ (.run q k μ) none (.error [r] k μ) ∧ StateTyE P B σ Eb (.error [r] k μ) := by
  obtain ⟨Ψ,R,a,b,e,_,hs,_,_,hk,_,_,hkc,hμ⟩ := h
  exact ⟨.E_BuilderErr hv hl hr,Ψ,R,a,b,e,hs,hk,hkc,hμ⟩

end
end Benitoite.Release.Refinement
