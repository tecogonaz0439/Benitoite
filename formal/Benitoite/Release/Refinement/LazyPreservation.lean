import Benitoite.Release.Refinement.LazyStore

/-! # 明示遅延の実際の遷移に対する保存の代表 -/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

private theorem store_arguments {P B Ψ b s ts es rs ws r e}
    (h : BuiltinArgs P B Ψ b s ts es rs ws r e)
    (hn : s.tparams.length = 1) (he : s.neffs = 0) (hr : s.rkinds = []) :
    ∃ a, ts = [a] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] a ∧ a.Normal := by
  have ht := h.admissible.typeCount
  rw [hn] at ht
  cases ts with
  | nil => cases ht
  | cons a ts =>
    have hts : ts = [] := List.length_eq_zero_iff.mp (by simpa using ht)
    subst ts
    have hes : es = [] := List.length_eq_zero_iff.mp (h.admissible.rowCount.trans he)
    have hrs : rs = [] := List.length_eq_zero_iff.mp (by simpa [hr] using h.ranges.1)
    exact ⟨a,rfl,hes,hrs,h.signature.types a List.mem_cons_self,(h.types a List.mem_cons_self).2⟩

private theorem force_tel {s : PrimSig} {a : Ty}
    (hk : s.kind = .force) (hs : s.StoreShape) (hn : a.Normal) (hw : a.WF 0 0 0) :
    instantiatedTel (Tel.instR [] s.tel) [a] [] = .param "value" (.lazy a) (.done a Eff.empty) := by
  change a.norm = a at hn
  simp only [PrimSig.StoreShape,hk] at hs
  rcases hs with ⟨hns,_,_,hps,hr,he,_⟩
  simp only [instantiatedTel,Tel.bind,typeEnvAt,Nat.not_lt_zero,↓reduceIte,Nat.sub_zero,
    List.length_cons,List.length_nil,List.map_nil,Tel.instR,Tel.substRAt,Tel.mapRanges,
    PrimSig.tel,hns,hps,hr,he,Eff.empty,signatureTel,Tel.rawMapRanges,Ty.rawMapRanges,
    Eff.rawMapRanges,Tel.norm,Ty.norm,Eff.norm,Tel.rawBind,Ty.rawBind,Nat.zero_lt_succ,
    List.getElem?_cons_zero,Option.getD_some,SubstEnv.up,Eff.rawBind,instAtoms_nil,
    substAtoms_nil,rowFails,List.range_zero,List.filter_nil,List.flatMap_nil,List.append_nil]
  simp only [shiftTypes_zero,hn,Ty.shiftV_of_wf_zero hw,mapRangeAtoms_rangeAt,
    instAtoms_nil,Nat.zero_add,Nat.lt_one_iff,upValues_id,mapRangesTys,Ty.normTys_eq_map,
    List.map_nil,Order.sortUnique_nil,rawBindTys_eq_map]

theorem BuiltinArgs.force {P B Ψ b s ts es rs l r e}
    (h : BuiltinArgs P B Ψ b s ts es rs [.loc l] r e)
    (hs : s.StoreShape) (hk : s.kind = .force) :
    ∃ a, Ty.Annotation P [] [] a ∧ a.Normal ∧
      HasTypeV P B Ψ [] [] [] (.loc l) (.lazy a) ∧ r = a ∧ e = Eff.empty := by
  have sh := hs
  simp only [PrimSig.StoreShape,hk] at sh
  obtain ⟨a,rfl,rfl,rfl,ha,hn⟩ := store_arguments h sh.2.1 sh.2.2.1 sh.2.2.2.2.2.2
  have ht := h.arguments
  rw [force_tel hk hs hn ha.wf] at ht
  cases ht with
  | param _ hv ht =>
    have hbind : Tel.bind (Tel.argumentsEnv (.loc l)) (.done a Eff.empty) = .done a Eff.empty := by
      rw [←valEnv_openValue]
      change Tel.done (substTyValues (openValue (.loc l)) a) (substEffValues (openValue (.loc l)) Eff.empty) = _
      rw [Ty.subst_values_of_wf_zero ha.wf,hn,Eff.subst_values_empty]
    rw [hbind] at ht
    cases ht
    exact ⟨_,ha,hn,hv,rfl,rfl⟩

private theorem empty_sub (ε : Eff) : Eff.Sub Eff.empty ε := by
  constructor
  · intro a ha; cases ha
  · intro t ht; obtain ⟨u,hu,_⟩ := ht; cases hu

private theorem empty_annotation {P a} (ha : Ty.Annotation P [] [] a) :
    Ty.Annotation P [] [] (.dependentFn (.done a Eff.empty)) :=
  ⟨⟨ha.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
    ⟨ha.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,⟨ha.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩

theorem StateTyE.force_done_transition {P B σ Eb b ts es rs l k μ s v}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.done v)) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ) none
      (.run (Closure.pure (.ret v)) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k μ) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  have step := Step.E_ForceDone (P := P) (σ := σ) (k := k) (Closure.pure_primitive_view hclosed rfl) hs hk hl
  obtain ⟨r,f,hargs,hle,_⟩ := hq.pure_primitive hA.values hsμ.wf
    (by intro w hw; rcases List.mem_cons.mp hw with rfl | hw; trivial; cases hw) hs
  obtain ⟨x,hx,hn,hv,rfl,rfl⟩ := hargs.force (hA.store_shape b s hs (by rw [hk]; decide)) hk
  obtain ⟨loc,y,hvl,hΨ,hxy⟩ := hv.canonical_lazy rfl
  cases Val.loc.inj hvl
  obtain ⟨y',hΨ',hread,had'⟩ := hsμ.cell l _ hl
  cases Option.some.inj (hΨ'.symm.trans hΨ)
  have hvx : HasTypeV P B Ψ [] [] [] v r := .V_Sub hread hxy hx.wf hx.sorted hx.declared
  exact ⟨step,Ψ,R,r,c,ε,Eff.empty,hsμ,hq.pure_return hvx hx hn,
    empty_sub ε,.K_Sub hcont hle,⟨trivial,had'⟩,⟨trivial,hμc l _ hl⟩,hkc,hμc⟩

theorem StateTyE.force_thunk_transition {P B σ Eb b ts es rs l k μ s m}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ))
    (hs : B.sig b = some s) (hk : s.kind = .force) (hl : μ l = some (.thunk m)) :
    Step P B σ (.run (Closure.pure (.app (.prim b ts es rs) [.loc l])) k μ) none
      (.run m (.update l :: k) μ) ∧
    StateTyE P B σ Eb (.run m (.update l :: k) μ) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  have step := Step.E_Force (P := P) (σ := σ) (k := k) (Closure.pure_primitive_view hclosed rfl) hs hk hl
  obtain ⟨r,f,hargs,hle,_⟩ := hq.pure_primitive hA.values hsμ.wf
    (by intro w hw; rcases List.mem_cons.mp hw with rfl | hw; trivial; cases hw) hs
  obtain ⟨x,hx,hn,hv,rfl,rfl⟩ := hargs.force (hA.store_shape b s hs (by rw [hk]; decide)) hk
  obtain ⟨loc,y,hvl,hΨ,hxy⟩ := hv.canonical_lazy rfl
  cases Val.loc.inj hvl
  obtain ⟨y',hΨ',hbody,had'⟩ := hsμ.cell l _ hl
  cases Option.some.inj (hΨ'.symm.trans hΨ)
  refine ⟨step,Ψ,none,y,c,ε,Eff.empty,hsμ,
    hbody.store hA.values hsμ.wf.hide (StoreTy.hide_extends Ψ),empty_sub ε,
    .K_Update hΨ' ⟨hbody.annotation.wf.1,hbody.annotation.sorted.1,hbody.annotation.declared.1⟩
      (.K_Sub hcont (.trans hxy hle)),had',hμc l _ hl,?_,hμc⟩
  intro f hf
  rcases List.mem_cons.mp hf with rfl | hf
  · trivial
  · exact hkc f hf

private theorem lazy_inv {P B Ψ Q C Γ Φ R code a e L m}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .lazyC m) :
    ∃ x, Ty.Annotation P C Γ x ∧
      HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m x Eff.empty [] ∧
      Ty.LeQ P Γ Φ (.lazy x) a := by
  match h with
  | .C_Lazy hb ha => cases hc; exact ⟨_,ha,hb,.refl⟩
  | .C_Sub hh hl _ _ _ _ =>
    obtain ⟨x,hx,hb,hle⟩ := lazy_inv hh hc
    exact ⟨x,hx,hb,.trans hle hl⟩
  | .C_Normal hh =>
    obtain ⟨x,hx,hb,hle⟩ := lazy_inv hh hc
    exact ⟨x,hx,hb,.trans hle (.convert (Ty.norm_idem _).symm)⟩
  | .C_Eff hh _ => exact lazy_inv hh hc
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. |
    .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private def isLazy : Comp → Bool | .lazyC _ => true | _ => false

private theorem hide_annotation {P Γ x} (ha : Ty.Annotation P [] Γ x) :
    Ty.Annotation P [] (hideConts Γ) x := by
  have hm : ShiftMap 0 0 Γ (hideConts Γ) := by
    refine ⟨by simp [hideConts],?_⟩
    intro i a hi ho
    simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hideConts_lookup.mpr ⟨hi,ho⟩
  simpa only [Ty.shiftV_zero] using hm.annotation ha

theorem ClosureTy.lazy_body {P B Ψ R q a e m}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R q a e) (hv : q.view = .lazyC m) :
    ∃ x, Ty.Annotation P [] [] x ∧
      ClosureTy P B (hideBuilders Ψ) [] none (.mk q.capture m) x Eff.empty ∧
      Ty.LeQ P [] [] (.lazy x) a := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hq,hcap,hbody,hL,hR,ha,he,hr⟩ := h.open_zero
  subst q
  have htag : isLazy code0 = true := by
    have hh := congrArg isLazy hv
    cases code0 <;> exact hh
  cases code0 <;> try cases htag
  rename_i body
  have hm : body.resolveLocals ρ = m := Comp.lazyC.inj hv
  obtain ⟨x,hx,hb,hle⟩ := lazy_inv hbody rfl
  have hm0 := hb.resolve_id ρ (LocalsFixed.empty _)
  rw [hm0] at hm
  subst m
  have hc' := (hcap.store hA hw (StoreTy.preserves_hide Ψ)).hideConts_any (R' := none)
  have hx' := hide_annotation hx
  have ht : Ty.Annotation P [] (hideConts Γ) (.dependentFn (.done x Eff.empty)) :=
    ⟨⟨hx'.wf,by simp [Eff.WF,Eff.empty,Eff.Canonical,Eff.norm,Ty.WFList]⟩,
      ⟨hx'.sorted,by simp [sortedEff,Eff.empty,sortedTys]⟩,
      ⟨hx'.declared,by simp [declaredEff,Eff.empty,declaredTys]⟩⟩
  have hxclosed := hc'.substOk.annotation hx'
  have hcl := ClosureTy.capture hc' hb ht (by rfl) (by intros; contradiction)
  have hle' := hle.bind (valEnv cap.env) hcap.transport
  change Ty.LeQ P [] [] (.lazy (cap.closeTy x)) (cap.closeTy as) at hle'
  rw [ha] at hle'
  exact ⟨cap.closeTy x,hxclosed,by simpa only [Closure.capture,Capture.closeEff,Eff.subst_values_empty,hm0] using hcl,hle'⟩

private theorem return_inv {P B Ψ Q C Γ Φ R code a e L v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code a e L) (hc : code = .ret v) :
    HasTypeVQ P B Ψ Q C Γ Φ v a := by
  match h with
  | .C_Return hv => cases hc; exact hv
  | .C_Sub hh hl _ hw hs hd => exact .V_Sub (return_inv hh hc) hl hw hs hd
  | .C_Normal hh => exact (return_inv hh hc).V_Normal
  | .C_Eff hh _ => exact return_inv hh hc
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Lazy .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. |
    .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hc
termination_by structural h

private theorem value_closed_wf {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hw : Ψ.WF) (hC : C = []) (hΓ : Γ = []) :
    a.WF 0 0 0 := by
  match h with
  | .V_Var hi _ => subst Γ; cases hi
  | .V_Const (c := c) _ => cases c <;> trivial
  | .V_Lam _ ha .. => subst C Γ; exact ha
  | .V_DependentLam ha _ | .V_Closure ha .. => subst C Γ; exact ha.wf
  | .V_Fun _ _ _ hi | .V_Prim _ _ _ _ hi | .V_Op _ _ _ hi | .V_ExternalRef _ _ _ hi =>
    subst C Γ; exact hi.result.wf
  | .V_ExternalHandle _ _ _ _ _ _ ha | .V_Dict _ _ _ _ _ _ _ ha | .V_Con _ _ _ _ _ ha =>
    subst C Γ; exact ha.wf
  | .V_List _ ha _ _ => subst C Γ; exact ha
  | .V_Map _ _ _ _ ha hb => subst C Γ; exact ⟨ha.wf,hb.wf⟩
  | .V_Set _ _ ha => subst C Γ; exact ha.wf
  | .V_Raise ha hot hoe hkind => subst C Γ; exact ha.wf
  | .V_Super hh _ _ _ =>
    have hh' := value_closed_wf hh hw hC hΓ
    exact hh'
  | .V_LocRef hl _ | .V_LocLazy hl _ => exact hw _ _ hl
  | .V_Normal hh => exact Ty.wf_norm (value_closed_wf hh hw hC hΓ)
  | .V_Sub _ _ ha _ _ => subst C Γ; exact ha
  | .V_Refine hh hi ht hs hp _ _ _ =>
    exact ⟨value_closed_wf hh hw hC hΓ,by simpa [hΓ] using hp,hi.ordinary⟩
  | .V_AtError hs => rw [hs.errorType_eq]; trivial
  | .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_Bytes .. => trivial
termination_by structural h

private theorem pure_ret {P B Ψ R v a e}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R (Closure.pure (.ret v)) a e) :
    HasTypeV P B Ψ [] [] [] v a := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hq,hcap,hbody,hL,hR,ha,he,hr⟩ := h.open_zero
  have hc : cap = Capture.empty := (Closure.mk.inj hq).1.symm
  subst cap
  have hΓ : Γ = [] := by
    cases hcap with
    | mk _ hn _ _ _ _ _ _ => exact List.length_eq_zero_iff.mp hn.symm
  subst Γ
  have hΦ : ∀ p ∈ Φ, Entails [] p := by
    cases hcap with
    | mk _ _ _ _ hfw _ _ hf =>
      intro p hp
      have hh := hf p (List.mem_append_right _ hp)
      rwa [Pred.bind_closed (hfw p hp).1] at hh
  have hb := hbody.weaken_conditions hA hw (Ξ := []) (by simpa [Ctx.facts] using hΦ)
  have hc0 : code0.resolveLocals ρ = .ret v := (Closure.mk.inj hq).2.symm
  have htag : (match code0 with | .ret _ => true | _ => false) = true := by
    cases code0 <;> exact congrArg (fun c => match c with | .ret _ => true | _ => false) hc0
  cases code0 <;> try cases htag
  rename_i v0
  have hv := return_inv hb rfl
  have hve : v0 = v := by
    rw [show (Comp.ret v0).resolveLocals ρ = .ret v0 from by simp only [Comp.resolveLocals,hv.resolve_id]] at hc0
    exact Comp.ret.inj hc0
  subst v0
  have hnorm : Capture.empty.closeTy as = as.norm :=
    Ty.subst_values_of_wf_zero (value_closed_wf hv hw rfl rfl) _
  rw [←ha,hnorm]
  exact hv.V_Normal

private theorem cont_return_annotation {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none) :
    ∀ r, R = some r → Ty.Annotation P [] [] r := by
  match h with
  | .K_Empty _ _ => intro r hr; rw [hRe] at hr; cases hr
  | .K_Mark _ ha => intro r hr; cases hr; exact ha
  | .K_Update .. | .K_Guard .. => intro r hr; cases hr
  | .K_Let _ _ _ _ ht | .K_Release _ _ _ _ ht | .K_Drop _ _ ht | .K_Sub ht _ =>
    exact cont_return_annotation ht hRe
  | .K_Handle ht .. | .K_Handle_Fail ht .. => exact cont_return_annotation ht hRe
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


theorem StateTyE.lazy_transition {P B σ Eb q m k μ l}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .lazyC m) (hl : μ l = none) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (.mk q.capture m)))) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.loc l))) k (μ.set l (.thunk (.mk q.capture m)))) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  obtain ⟨x,hx,hbody,hle⟩ := hq.lazy_body hA.values hsμ.wf hv
  have hnone : Ψ l = none := by
    cases hp : Ψ l with
    | none => rfl
    | some t => exact False.elim (hsμ.domain l t hp hl)
  have hext := StoreTy.extends_put (x := LocTy.lazy x) hnone
  have hmc : (Closure.mk q.capture m).ClosedAt 0 := by
    cases q with
    | mk cap code => cases code <;> cases hv <;> exact hclosed
  have hma : (Closure.mk q.capture m).Adequate σ := by
    cases q with
    | mk cap code => cases code <;> cases hv <;> exact had
  have hs' := hsμ.allocate_lazy hA.values hl hx hbody hma
  have hloc : HasTypeV P B (Ψ.put l (.lazy x)) [] [] [] (.loc l) (.lazy x) :=
    .V_LocLazy (by simp [StoreTy.put]) hx.declared
  have hla : Ty.Annotation P [] [] (.lazy x) := ⟨hx.wf,hx.sorted,hx.declared⟩
  have hr := cont_return_annotation hcont rfl
  have hq' := ClosureTy.pure (.C_Return (R := R) hloc) (empty_annotation hla)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩)
    (congrArg Ty.lazy (closure_normal hbody)) hq.return_normal
  exact ⟨.E_Lazy hv hl,Ψ.put l (.lazy x),R,.lazy x,c,ε,Eff.empty,hs',hq',empty_sub ε,
    .K_Sub (hcont.store hA.values hsμ.wf hext) hle,⟨trivial,trivial⟩,⟨trivial,trivial⟩,
    hkc,closed_set hμc hmc⟩

private theorem normal_return_tail {P B σ Ψ R ε k a b Eb Re}
    (h : ContTy P B σ Ψ R ε k a b Eb Re) (hRe : Re = none)
    (n : Ty) (ha : Ty.Annotation P [] [] n) (hn : n.Normal) (hl : Ty.LeQ P [] [] n a) :
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

/-- 現在のセルの内容を限定せず、更新枠が保持する格納の契約へ書き戻す。 -/
theorem StateTyE.lazy_update_any_cell {P B σ Eb v l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.ret v)) (.update l :: k) μ))
    (hc : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.ret v)) (.update l :: k) μ) none
      (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  obtain ⟨rfl,x,R',hl,hle,hx,hk⟩ := hcont.update_inv
  have hv := pure_ret hA.values hsμ.wf hq
  have han := hq.annotation
  have ha : Ty.Annotation P [] [] a := ⟨han.wf.1,han.sorted.1,han.declared.1⟩
  have hn := closure_normal hq
  have hvx : HasTypeV P B Ψ [] [] [] v x := .V_Sub hv hle hx.wf hx.sorted hx.declared
  have hs' := hsμ.write_done hl hvx had.2
  obtain ⟨R'',hRn,hk'⟩ := normal_return_tail hk rfl a ha hn hle
  have hr := cont_return_annotation hk' rfl
  have hq' := ClosureTy.pure (.C_Return (R := R'') hv) (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) hn hRn
  exact ⟨.E_Update (by change Comp.ret (closeVal Capture.empty v) = _; rw [hc]),
    Ψ,R'',a,c,ε,Eff.empty,hs',hq',empty_sub ε,hk',had,hclosed,
    (fun f hf => hkc f (List.mem_cons_of_mem _ hf)),closed_set hμc hclosed.2⟩

/-- 捕捉した事実を既存の定数の逆転で閉じ、セルの現在の内容によらず書き戻す。 -/
theorem StateTyE.lazy_update_const_transition {P B σ Eb q c l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.update l :: k) μ))
    (hv : q.view = .ret (.const c)) :
    Step P B σ (.run q (.update l :: k) μ) none
      (.run (Closure.pure (.ret (.const c))) k (μ.set l (.done (.const c)))) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.const c))) k (μ.set l (.done (.const c)))) := by
  obtain ⟨Ψ,R,a,d,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  obtain ⟨rfl,x,R',hl,hle,hx,hk⟩ := hcont.update_inv
  have hv0 := hq.ret_const hA.substitutions hsμ.wf hv
  have han := hq.annotation
  have ha : Ty.Annotation P [] [] a := ⟨han.wf.1,han.sorted.1,han.declared.1⟩
  have hn := closure_normal hq
  have hvx : HasTypeV P B Ψ [] [] [] (.const c) x := .V_Sub hv0 hle hx.wf hx.sorted hx.declared
  have hs' := hsμ.write_done hl hvx trivial
  obtain ⟨R'',hRn,hk'⟩ := normal_return_tail hk rfl a ha hn hle
  have hr := cont_return_annotation hk' rfl
  have hq' := ClosureTy.pure (.C_Return (R := R'') hv0) (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) hn hRn
  exact ⟨.E_Update hv,Ψ,R'',a,d,ε,Eff.empty,hs',hq',empty_sub ε,hk',
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩,
    (fun f hf => hkc f (List.mem_cons_of_mem _ hf)),closed_set hμc (by trivial)⟩

/-- エラーでは更新枠だけを降ろし、実ストアとセルの型付けをそのまま保つ。 -/
theorem StateTyE.lazy_update_pop_error {P B σ Eb rs l k μ}
    (h : StateTyE P B σ Eb (.error rs (.update l :: k) μ)) :
    Step P B σ (.error rs (.update l :: k) μ) none (.error rs k μ) ∧
    StateTyE P B σ Eb (.error rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
  obtain ⟨_,x,R',_,_,_,hk'⟩ := hk.update_inv
  exact ⟨.E_ErrPopUpdate,Ψ,R',x,b,e,hs,hk',fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμ⟩

/-- 終了でも更新枠だけを降ろし、値の書戻しを行わない。 -/
theorem StateTyE.lazy_update_pop_exit {P B σ Eb n rs l k μ}
    (h : StateTyE P B σ Eb (.exit n rs (.update l :: k) μ)) :
    Step P B σ (.exit n rs (.update l :: k) μ) none (.exit n rs k μ) ∧
    StateTyE P B σ Eb (.exit n rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
  obtain ⟨_,x,R',_,_,_,hk'⟩ := hk.update_inv
  exact ⟨.E_ExitPopUpdate,Ψ,R',x,b,e,hs,hk',fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμ⟩

end
end Benitoite.Release.Refinement
