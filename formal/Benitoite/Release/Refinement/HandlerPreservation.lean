import Benitoite.Release.Refinement.HandlerEffects

/-! # 節からの返却と一度だけの再開の代表 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem ContTy.return_annotation {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none) :
    ∀ r, R = some r → Ty.Annotation P [] [] r := by
  match h with
  | .K_Empty _ _ => intro r hr; rw [hRe] at hr; cases hr
  | .K_Mark _ ha => intro r hr; cases hr; exact ha
  | .K_Update .. | .K_Guard .. => intro r hr; cases hr
  | .K_Let _ _ _ _ ht | .K_Release _ _ _ _ ht | .K_Drop _ _ ht | .K_Sub ht _ =>
    exact ContTy.return_annotation ht hRe
  | .K_Handle ht .. | .K_Handle_Fail ht .. => exact ContTy.return_annotation ht hRe
termination_by structural h

private theorem closed_set {μ : Store} {l c} (h : μ.Closed) (hc : c.Closed) :
    (μ.set l c).Closed := by
  intro i x hx
  by_cases hi : i = l
  · subst i; simp only [Store.set,↓reduceIte,Option.some.injEq] at hx; subst x; exact hc
  · simp only [Store.set,hi,↓reduceIte] at hx; exact h i x hx


private theorem closure_normal {P B Ψ R q a e}
    (hq : ClosureTy P B Ψ [] R q a e) : a.Normal := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hq,hcap,hbody,hL,hR,ha,he,hr⟩ := hq.open_zero
  rw [←ha]
  exact substTyValues_normal _ _

private theorem normal_return_tail {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none)
    (n : Ty) (ha : Ty.Annotation P [] [] n) (hn : n.Normal) (hl : Ty.LeQ [] [] n a) :
    ∃ R', (∀ r, R' = some r → r.Normal) ∧ ContTy P B σ Ψ R' ε k n b Eb Re := by
  match h with
  | hh@(.K_Empty ..) =>
    exact ⟨_,(by intro r hr; rw [hRe] at hr; cases hr),.K_Sub hh hl⟩
  | hh@(.K_Let hq ..) =>
    refine ⟨_,?_,.K_Sub hh hl⟩
    intro r hr
    have hh := hq.return_normal (r.shiftV 1 0) (by rw [hr]; rfl)
    apply Ty.shiftV_injective 1 0
    change (r.shiftV 1 0).norm = r.shiftV 1 0 at hh
    simpa only [Ty.norm_shiftV] using hh
  | .K_Mark ht _ => exact ⟨some n,by intro r hr; cases hr; exact hn,.K_Mark (.K_Sub ht hl) ha⟩
  | hh@(.K_Update ..) | hh@(.K_Guard ..) => exact ⟨none,by intros; contradiction,.K_Sub hh hl⟩
  | .K_Release hv had hr hs ht =>
    obtain ⟨R',hR,ht'⟩ := normal_return_tail ht hRe n ha hn hl
    exact ⟨R',hR,.K_Release hv had hr hs ht'⟩
  | .K_Drop hloc hs ht =>
    obtain ⟨R',hR,ht'⟩ := normal_return_tail ht hRe n ha hn hl
    exact ⟨R',hR,.K_Drop hloc hs ht'⟩
  | hh@(.K_Handle _ _ _ _ _ hR ..) | hh@(.K_Handle_Fail _ _ _ _ _ hR ..) =>
    exact ⟨_,fun r hr => closeR_normal (hR.trans hr),.K_Sub hh hl⟩
  | .K_Sub ht hle => exact normal_return_tail ht hRe n ha hn (.trans hl hle)
termination_by structural h


private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

private theorem empty_annotation {P a} (ha : Ty.Annotation P [] [] a) :
    Ty.Annotation P [] [] (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩

private theorem handler_inv {P B σ Ψ R e k a b Eb Re cap cs}
    (h : ContTy P B σ Ψ R e (.handleF cap cs :: k) a b Eb Re) :
    ∃ t et, Ty.LeQ [] [] a t ∧ ContTy P B σ Ψ R et k t b Eb Re := by
  generalize he : (.handleF cap cs :: k) = frames at h
  induction h with
  | K_Handle ht _ _ _ _ _ _ _ _ _ _ _ _ => cases he; exact ⟨_,_,.refl,ht⟩
  | K_Handle_Fail ht _ _ _ _ _ _ _ _ _ _ _ _ _ => cases he; exact ⟨_,_,.refl,ht⟩
  | K_Sub _ hl ih =>
    obtain ⟨t,et,hle,ht⟩ := ih he
    exact ⟨t,et,.trans hl hle,ht⟩
  | _ => cases he

private theorem drop_inv {P B σ Ψ R e k a b Eb Re l}
    (h : ContTy P B σ Ψ R e (.drop l :: k) a b Eb Re) :
    ∃ t, Ty.LeQ [] [] a t ∧ ContTy P B σ Ψ R e k t b Eb Re := by
  generalize he : (.drop l :: k) = frames at h
  induction h with
  | K_Drop _ _ ht => cases he; exact ⟨_,.refl,ht⟩
  | K_Sub _ hl ih =>
    obtain ⟨t,hle,ht⟩ := ih he
    exact ⟨t,.trans hl hle,ht⟩
  | _ => cases he

theorem StateTyE.handler_return_const {P B σ Eb q c cap cs k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.handleF cap cs :: k) μ))
    (hv : q.view = .ret (.const c)) :
    Step P B σ (.run q (.handleF cap cs :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨t,et,hle,ht⟩ := handler_inv hk
  have hv' := hq.ret_const hA.substitutions hs.wf hv
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  obtain ⟨R',hRn,ht⟩ := normal_return_tail ht rfl a ha (closure_normal hq) hle
  have hr := ContTy.return_annotation ht rfl
  have hq' := ClosureTy.pure (.C_Return (R := R') hv') (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) (closure_normal hq) hRn
  exact ⟨.E_HRet hv,Ψ,R',a,b,et,Eff.empty,hs,hq',empty_sub et,ht,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμ⟩

theorem StateTyE.drop_used_const {P B σ Eb q c l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret (.const c)) (hl : μ l = some .used) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨t,hle,ht⟩ := drop_inv hk
  have hv' := hq.ret_const hA.substitutions hs.wf hv
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  obtain ⟨R',hRn,ht⟩ := normal_return_tail ht rfl a ha (closure_normal hq) hle
  have hr := ContTy.return_annotation ht rfl
  have hq' := ClosureTy.pure (.C_Return (R := R') hv') (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) (closure_normal hq) hRn
  exact ⟨.E_Drop hv hl,Ψ,R',a,b,e,Eff.empty,hs,hq',empty_sub e,ht,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμ⟩

theorem StateTyE.resume_used {P B σ Eb q l v k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) v) (hl : μ l = some .used) :
    Step P B σ (.run q k μ) none (.error [rResume] k μ) ∧
    StateTyE P B σ Eb (.error [rResume] k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  exact ⟨.E_ResumeErr hv hl,Ψ,R,a,b,e,hs,hk,hkc,hμ⟩

private theorem close_atomic_const {cap : Capture} {v : Val} {c : Const}
    (h : closeVal cap v = .const c) (ρ : Nat → LocalRef) : v.subst cap.env ρ = .const c := by
  cases v <;> first | exact h | (cases h <;> rfl)

private theorem close_atomic_loc {cap : Capture} {v : Val} {l : Nat}
    (h : closeVal cap v = .loc l) (ρ : Nat → LocalRef) : v.subst cap.env ρ = .loc l := by
  cases v <;> first | exact h | (cases h <;> rfl)

private theorem resume_resolve {P B Ψ Q C Γ Φ R code a e L kv v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (he : code = .resume kv v) (ρ) :
    code.resolveLocals ρ = code := by
  match h with
  | .C_Resume _ hv _ | .C_ResumeL _ hv _ | .C_ResumeNorm _ hv _ | .C_ResumeLNorm _ _ hv _ =>
    cases he; simp only [Comp.resolveLocals,Val.resolveLocals,hv.resolve_id]
  | .C_Normal hh | .C_Sub hh .. | .C_Eff hh _ => exact resume_resolve hh he ρ
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases he
termination_by structural h

private theorem resume_closed {P B Ψ R q l c a e}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .resume (.loc l) (.const c)) :
    HasTypeC P B Ψ [] [] [] R (.resume (.loc l) (.const c)) a e := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hq,hcap,hbody,hL,hR,ha,he,hr⟩ := hq.open_zero
  subst q
  have htag : (match code0 with | .resume .. => true | _ => false) = true := by
    have hh := congrArg (fun code => match code with | .resume .. => true | _ => false) hv
    cases code0 <;> exact hh
  cases code0 <;> try cases htag
  rename_i kv v
  rw [resume_resolve hbody rfl ρ] at hv
  obtain ⟨hkv,hvv⟩ := Comp.resume.inj hv
  have hh := hbody.subst (Δ := []) (Ξ := []) (σ := cap.env) hA hw (by
      change SubstOk P B Ψ Qempty [] Γ Φ [] [] (cap.closeR Rs) cap.env
      rw [hR]; exact hcap.substOk)
    (fun p hp => hcap.conditions p (List.mem_append_right _ hp))
    (L' := []) (ρ := ρ) (by
      intro i kind hi
      obtain ⟨ll,hll,hlook⟩ := hL i kind hi
      rw [hll]
      exact .loc hlook)
  have hvs : v.subst cap.env ρ = .const c := close_atomic_const hvv ρ
  have hks : kv.subst cap.env ρ = .loc l := close_atomic_loc hkv ρ
  simp only [Comp.subst,hvs,hks] at hh
  change HasTypeCQ P B Ψ Qempty [] [] [] (cap.closeR Rs) _ (cap.closeTy as) (cap.closeEff es) [] at hh
  rwa [hR,ha,he] at hh

private theorem resume_inv {P B Ψ Q C Γ Φ R code a e L l c}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (he : code = .resume (.loc l) (.const c)) :
    ∃ x t ec r, Ψ l = some (.cont x t ec r) ∧ r.map Ty.norm = R.map Ty.norm ∧
      HasTypeVQ P B Ψ Q C Γ Φ (.const c) x.norm ∧ Ty.LeQ Γ Φ t.norm a ∧ Eff.Covers Γ Φ e ec := by
  match h with
  | .C_ResumeL hl hv hd => cases he; exact ⟨_,_,_,_,hl,rfl,hv.V_Normal,.convert (Ty.norm_idem _),.refl _ _ _⟩
  | .C_ResumeLNorm hl hr hv hd => cases he; exact ⟨_,_,_,_,hl,hr,hv,.refl,Eff.covers_norm_left.mpr (.refl _ _ _)⟩
  | .C_Sub hh hl hc _ _ _ =>
    obtain ⟨x,t,ec,r,hp,hr,hv,hle,hcov⟩ := resume_inv hh he
    exact ⟨x,t,ec,r,hp,hr,hv,.trans hle hl,hc.trans hcov⟩
  | .C_Normal hh =>
    obtain ⟨x,t,ec,r,hp,hr,hv,hle,hcov⟩ := resume_inv hh he
    exact ⟨x,t,ec,r,hp,hr,hv,.trans hle (.convert (Ty.norm_idem _).symm),hcov⟩
  | .C_Eff hh hc =>
    obtain ⟨x,t,ec,r,hp,hr,hv,hle,hcov⟩ := resume_inv hh he
    exact ⟨x,t,ec,r,hp,hr,hv,hle,hc.trans hcov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. | .C_Meth .. | .C_External .. |
    .C_IssuePathBases .. | .C_CheckAt .. => cases he
termination_by structural h

private theorem const_annotation {P B Ψ Q C Γ Φ v a c}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .const c) : Ty.Annotation P C Γ a := by
  match h with
  | .V_Const (c := c) _ => cases c <;> exact ⟨trivial,trivial,trivial⟩
  | .V_Normal hh => exact (const_annotation hh hv).norm
  | .V_Sub _ _ hw hs hd => exact ⟨hw,hs,hd⟩
  | .V_Refine hh hi ht hs hw he hd hp =>
    have ha := const_annotation hh hv
    exact ⟨⟨ha.wf,hw,by simpa [Ty.NotContCore] using hi.ordinary⟩,⟨ha.sorted,hs⟩,⟨hd,hp⟩⟩
  | .V_Var .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. |
    .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. |
    .V_List .. | .V_Con .. | .V_Map .. | .V_Set .. | .V_Dict .. | .V_Super .. | .V_Raise .. |
    .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => cases hv
termination_by structural h

theorem StateTyE.resume_const {P B σ Eb q l c k μ saved}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .resume (.loc l) (.const c)) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.const c))) (saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.const c))) (saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨x,t,ec,r,hp,hr,hv',hle,hcov⟩ := resume_inv (resume_closed hA.substitutions hs.wf hq hv) rfl
  have hrraw := resume_raw_return hs hp hl hr hq.return_normal
  subst r
  obtain ⟨x',t',ec',r',hp',hend,R0,e0,hks⟩ := hs.2.2.2.2 l _ hl
  cases Option.some.inj (hp'.symm.trans hp)
  have ht := hks.resume_append hend (.trans (.convert (Ty.norm_idem _).symm) hle) hk
    (he.covers.trans hcov)
  have hxa := const_annotation hv' rfl
  have ht' := ContTy.K_Sub ht (Ty.LeQ.convert (Ty.norm_idem x))
  obtain ⟨R'',hRn,ht''⟩ := normal_return_tail ht' rfl x.norm hxa (Ty.norm_idem _) .refl
  have hra := ContTy.return_annotation ht'' rfl
  have hq' := ClosureTy.pure (.C_Return (R := R'') hv') (empty_annotation hxa)
    (fun r hh => ⟨(hra r hh).wf,(hra r hh).declared⟩) (Ty.norm_idem _) hRn
  exact ⟨.E_Resume hv hl,Ψ,R'',x.norm,b,e0,Eff.empty,hs.use_continuation hp,hq',empty_sub e0,ht'',
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,
    (fun f hf => by
      rcases List.mem_append.mp hf with hf | hf
      · exact hμ l _ hl f hf
      · exact hkc f hf),closed_set hμ trivial⟩

private theorem drop_release_inv {P B σ Ψ R e k a b Eb Re l}
    (h : ContTy P B σ Ψ R e (.drop l :: k) a b Eb Re) :
    ∃ t b' t' e' R', Ψ l = some (.cont b' t' e' R') ∧ (e'.mem (.name stateEff (.fixed .top)) → e.mem (.name stateEff (.fixed .top))) ∧
      Ty.LeQ [] [] a t ∧ ContTy P B σ Ψ R e k t b Eb Re := by
  generalize he : (.drop l :: k) = frames at h
  induction h with
  | K_Drop hl hc ht => cases he; exact ⟨_,_,_,_,_,hl,hc,.refl,ht⟩
  | K_Sub _ hl ih =>
    obtain ⟨t,b',t',e',R',hp,hc,hle,ht⟩ := ih he
    exact ⟨t,b',t',e',R',hp,hc,.trans hl hle,ht⟩
  | _ => cases he

theorem releases_mem (f : Frame) (k : Cont) (h : f ∈ releases k) : f ∈ k := by
  induction k with
  | nil => simp [releases] at h
  | cons g k ih =>
    cases g with
    | release v | drop l =>
      simp only [releases,List.mem_cons] at h
      rcases h with rfl | h
      · exact List.mem_cons_self
      · exact List.mem_cons_of_mem _ (ih h)
    | _ =>
      simp only [releases] at h
      exact List.mem_cons_of_mem _ (ih h)

/-- E_DropRel は、State の予約と宣言の分離の下で定数の view で閉じる。 -/
theorem StateTyE.drop_rel_const {P B σ Eb q c l k μ saved} (hdecl : P.EffectsOk B)
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.drop l :: k) μ))
    (hv : q.view = .ret (.const c)) (hl : μ l = some (.cont saved)) :
    Step P B σ (.run q (.drop l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.const c))) (releases saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨t,b',t',e',R',hp,hcond,hle,ht⟩ := drop_release_inv hk
  have hv' := hq.ret_const hA.substitutions hs.wf hv
  have ha : Ty.Annotation P [] [] a := ⟨hq.annotation.wf.1,hq.annotation.sorted.1,hq.annotation.declared.1⟩
  obtain ⟨x,t2,e2,r2,hp2,_,R0,e0,hsv⟩ := hs.2.2.2.2 l _ hl
  cases Option.some.inj (hp2.symm.trans hp)
  have ht2 := ContTy.prepend_releases (hdecl.noStateHandled hA) hsv ht hcond
  obtain ⟨R2,hRn,ht3⟩ := normal_return_tail ht2 rfl a ha (closure_normal hq) hle
  have hr := ContTy.return_annotation ht3 rfl
  have hq' := ClosureTy.pure (.C_Return (R := R2) hv') (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) (closure_normal hq) hRn
  refine ⟨.E_DropRel hv hl,Ψ,R2,a,b,e,Eff.empty,hs.use_continuation hp,hq',empty_sub e,ht3,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,?_,closed_set hμ trivial⟩
  intro f hf
  rcases List.mem_append.mp hf with hf | hf
  · have hc := hμ l _ hl
    have hmem := releases_mem f saved hf
    exact hc f hmem
  · exact hkc f (List.mem_cons_of_mem _ hf)

/-- 閉じた定数の escape は同じ閉包のまま、解放の前置と used 化を行う。 -/
theorem StateTyE.esc_drop_rel_const {P B σ Eb c l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.escape (.const c))) (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    Step P B σ (.run (Closure.pure (.escape (.const c))) (.drop l :: k) μ) none
      (.run (Closure.pure (.escape (.const c))) (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.escape (.const c))) (releases saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨t,b',t',e',R',hp,hcond,hle,ht⟩ := drop_release_inv hk
  obtain ⟨x,t2,e2,r2,hp2,_,R0,e0,hsv⟩ := hs.2.2.2.2 l _ hl
  cases Option.some.inj (hp2.symm.trans hp)
  have ht2 := ContTy.prepend_releases (hdecl.noStateHandled hA) hsv (.K_Sub ht hle) hcond
  refine ⟨.E_EscDropRel rfl hl,Ψ,R,a,b,e,e1,hs.use_continuation hp,hq,he,ht2,had,hcl,?_,closed_set hμ trivial⟩
  intro f hf
  rcases List.mem_append.mp hf with hf | hf
  · exact hμ l _ hl f (releases_mem f saved hf)
  · exact hkc f (List.mem_cons_of_mem _ hf)

/-- 解放を伴う err の伝播も、同じ State の効果と捕捉した契約を保存する。 -/
theorem StateTyE.err_drop_rel {P B σ Eb rs l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.error rs (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    Step P B σ (.error rs (.drop l :: k) μ) none
      (.error rs (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.error rs (releases saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
  obtain ⟨t,b',t',e',R',hp,hcond,hle,ht⟩ := drop_release_inv hk
  obtain ⟨x,t2,e2,r2,hp2,_,R0,e0,hsv⟩ := hs.2.2.2.2 l _ hl
  cases Option.some.inj (hp2.symm.trans hp)
  have ht2 := ContTy.prepend_releases (hdecl.noStateHandled hA) hsv ht hcond
  refine ⟨.E_ErrDropRel hl,Ψ,R,t,b,e,hs.use_continuation hp,ht2,?_,closed_set hμ trivial⟩
  intro f hf
  rcases List.mem_append.mp hf with hf | hf
  · exact hμ l _ hl f (releases_mem f saved hf)
  · exact hkc f (List.mem_cons_of_mem _ hf)

/-- 解放を伴う exit の伝播も、同じ State の効果と捕捉した契約を保存する。 -/
theorem StateTyE.exit_drop_rel {P B σ Eb n rs l k μ saved}
    (hdecl : P.EffectsOk B) (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.exit n rs (.drop l :: k) μ))
    (hl : μ l = some (.cont saved)) :
    Step P B σ (.exit n rs (.drop l :: k) μ) none
      (.exit n rs (releases saved ++ k) (μ.set l .used)) ∧
    StateTyE P B σ Eb (.exit n rs (releases saved ++ k) (μ.set l .used)) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
  obtain ⟨t,b',t',e',R',hp,hcond,hle,ht⟩ := drop_release_inv hk
  obtain ⟨x,t2,e2,r2,hp2,_,R0,e0,hsv⟩ := hs.2.2.2.2 l _ hl
  cases Option.some.inj (hp2.symm.trans hp)
  have ht2 := ContTy.prepend_releases (hdecl.noStateHandled hA) hsv ht hcond
  refine ⟨.E_ExitDropRel hl,Ψ,R,t,b,e,hs.use_continuation hp,ht2,?_,closed_set hμ trivial⟩
  intro f hf
  rcases List.mem_append.mp hf with hf | hf
  · exact hμ l _ hl f (releases_mem f saved hf)
  · exact hkc f (List.mem_cons_of_mem _ hf)

end
end Benitoite.Release.Refinement
