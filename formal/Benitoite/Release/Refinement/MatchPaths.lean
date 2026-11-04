import Benitoite.Release.Refinement.PathConditions
import Benitoite.Release.Refinement.ClosedCapture

/-! # 照合と guard の経路条件を閉じる入口 -/
namespace Benitoite.Release.Refinement

variable {P : Program}
noncomputable section

abbrev BooleanTy : Ty := .base .boolean

theorem HasTypeArmsQ.weaken_conditions {P B Ψ Q C Γ Φ R obs arms a b e L Ξ}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (hf : ∀ p ∈ Φ, Entails (Γ.facts ++ Ξ) p) :
    HasTypeArmsQ P B Ψ Q C Γ Ξ R obs arms a b e L := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw (StoreTy.Extends.refl _)
    ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
    (LocalCtx.Shift.refl _) (Ξ := Ξ) (fun p hp => by rw [Pred.shiftV_zero]; exact hf p hp)
  simpa only [shiftIndex_zero,Arm.renameList_identity,Ty.shiftV_zero,Eff.shiftV_zero,
    id_eq,termBind_identity,Option.map_id,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0)] using hh

theorem HasTypeArmsQ.plain_legacy {P B Ψ Q C Γ Φ R alts body arms a b e δ L}
    (hp : AltsTy P alts a δ)
    (hb : HasTypeCQ P B Ψ Q C (bindParams Γ δ) (liftMany δ.length Φ)
      (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
      (localExtend δ.length L))
    (hs : HasTypeArmsQ P B Ψ Q C Γ Φ R none arms a b e L) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R none (.mk alts none body :: arms) a b e L :=
  .plainEmpty hp (by intro p hp; cases hp) hb hs

theorem HasTypeArmsQ.guarded_legacy {P B Ψ Q C Γ Φ R alts guard body arms a b e δ L}
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF)
    (hp : AltsTy P alts a δ)
    (hg : HasTypeCQ P B Ψ Q C (hideConts (bindParams Γ δ)) (liftMany δ.length Φ)
      none guard BooleanTy Eff.empty (localExtend δ.length L))
    (hb : HasTypeCQ P B Ψ Q C (bindParams Γ δ) (liftMany δ.length Φ)
      (R.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
      (localExtend δ.length L))
    (hs : HasTypeArmsQ P B Ψ Q C Γ Φ R none arms a b e L) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R none (.mk alts (some guard) body :: arms) a b e L := by
  have ha : Ty.Annotation P C (hideConts (bindParams Γ δ)) (.refined BooleanTy .truth) := by
    refine ⟨⟨trivial,trivial,?_⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩
    simp [BooleanTy,Ty.NotContCore,Ty.core]
  refine .guardedEmpty (p := .truth) hp (by intro p hp; cases hp) ha ?_ ?_ hs
  · exact .C_Sub hg (.introduce trivial .truth) (Eff.Covers.refl _ _ _)
      ha.wf ha.sorted ha.declared
  · exact hb.weaken_conditions hA hw
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ hp)))

theorem HasTypeCQ.match_legacy {P B Ψ Q C Γ Φ R v arms a b e L}
    (hv : HasTypeVQ P B Ψ Q C Γ Φ v a)
    (ha : HasTypeArmsQ P B Ψ Q C Γ Φ R none arms a b e L)
    (hx : Exhaustive P a (unguardedPats arms)) :
    HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b e L :=
  .C_Match hv (by intro t ht; cases ht) ha hx

/-- Boolean の self を実際の結果で開く。整形式は値の真偽に依存しない。 -/
theorem Ty.Annotation.open_boolean {P C Γ p} (b : Bool)
    (ha : Ty.Annotation P C Γ (.refined BooleanTy p)) :
    Pred.WellFormed P C Γ (p.open (.boolean b)) := by
  let ν : ObservationEnv := openingEnv (some (.boolean b))
  have hs : Term.ImagesSorted (some BooleanTy :: Γ) Γ ν := by
    intro i a sort hi ht
    cases i with
    | zero =>
      cases Option.some.inj hi
      have he : sort = .boolean := (Option.some.inj ht).symm
      subst sort
      exact ⟨.boolean b,rfl,trivial,rfl⟩
    | succ i =>
      exact ⟨.var i,rfl,⟨a,hi,ht.ordinary⟩,a,hi,ht⟩
  have hr : Term.ImageReferences (some BooleanTy :: Γ) Γ ν := by
    intro i a hi ho t ht
    cases i with
    | zero => cases ht; trivial
    | succ i => cases ht; exact ⟨a,hi,ho⟩
  have hp : (p.open (.boolean b)).Sorted Γ none :=
    ha.sorted.2.map (Δ := Γ) (other := none) hs hr
  have hd := DeclarationImages.drop (P := P) (C := C) (Γ := Γ) (a := BooleanTy)
    (t := .boolean b) (by trivial) (by intro d ts h; cases h)
  exact ⟨hp.wf_none,hp,ha.declared.2.map (other := none) hd⟩

/-- 閉じた契約が既にある入口。ソースの行の Annotation を追加で要求しない。 -/
theorem ClosureTy.capture_resolved_closed {P B Ψ R Rs Γ Φ cap body a e L ρ}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hb : HasTypeCQ P B Ψ Qempty [] Γ Φ Rs body a e L)
    (hl : CaptureLocals Ψ cap.env L ρ)
    (ht : Ty.Annotation P [] [] (.dependentFn (.done (cap.closeTy a) (cap.closeEff e))))
    (hR : cap.closeR Rs = R) (hr : ∀ r, Rs = some r → r.Declared P [] Γ) :
    ClosureTy P B Ψ [] R (.mk cap (body.resolveLocals ρ)) (cap.closeTy a) (cap.closeEff e) := by
  have hr' : ∀ r, R = some r → r.Declared P [] [] := by
    intro r hh
    cases hs : Rs with
    | none => simp [Capture.closeR,hs] at hR; rw [←hR] at hh; cases hh
    | some rs =>
      have he : cap.closeTy rs = r := by simpa [Capture.closeR,hs,hh] using hR
      rw [←he]; exact (hr rs hs).bind_values hc.substOk.declaration
  have hb' : HasTypeCQ P B Ψ Qempty [] (bindParams Γ []) (liftMany 0 Φ) Rs body a e L := by
    simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,liftMany_eq,
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hb
  have hh := ClosureTy.mk (ss := []) (Rs := Rs) (a := a) (e := e) hc hb'
    (by simpa only [List.length_nil,upSubst_zero] using hl) rfl
    (by simp [TypeAnnotations]) (by simp [TypeAnnotations])
    (by simpa [Capture.closeRAt,Capture.closeR,Capture.closeTyAt,Capture.closeTy,upSubst_zero] using hR)
    (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,Capture.closeTyAt,Capture.closeTy,upSubst_zero]
        using (show Ty.Annotation P [] [] (cap.closeTy a) from ⟨ht.wf.1,ht.sorted.1,ht.declared.1⟩))
    (by simpa only [List.map_nil,List.length_nil,bindParams,List.reverse_nil,List.nil_append,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using ht)
    (by simpa only [bindParams,List.reverse_nil,List.map_nil,List.nil_append,List.length_nil,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,List.map_id] using hr) hr'
  simpa only [List.map_nil,List.length_nil,Capture.closeTyAt,Capture.closeEffAt,Capture.closeTy,Capture.closeEff,upSubst_zero] using hh

theorem GuardBodyTy.input_annotation {P B Ψ R body input a e}
    (h : GuardBodyTy P B Ψ R body input a e) : Ty.Annotation P [] [] input := by
  cases h with
  | mk hc hg hb hl he ha hR hr => exact hc.substOk.annotation hg

theorem GuardBodyTy.result_annotation {P B Ψ R body input a e}
    (h : GuardBodyTy P B Ψ R body input a e) :
    Ty.Annotation P [] [] (.dependentFn (.done a e)) := by
  cases h with
  | mk hc hg hb hl he ha hR hr => exact ha

/-- 値の結果型から guard の真の条件を導き、本体の捕捉へ足す。 -/
theorem GuardBodyTy.of_true {P B Ψ R body input a e}
    (h : GuardBodyTy P B Ψ R body input a e)
    (hv : HasTypeV P B Ψ [] [] [] (.const (.boolean true)) input) :
    ClosureTy P B Ψ [] R body a e := by
  match h with
  | .mk (p := p) (cap := cap) hc hg hb hl hcode ha hR hr =>
    let q := predBind (upValues (valEnv cap.env).values) p
    have hg' := hc.substOk.raw_bool_annotation hg
    have he : cap.closeTy (.refined BooleanTy p) = (Ty.refined BooleanTy q).norm := by
      simp only [Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm]
      rfl
    rw [he] at hv
    have hv' := HasTypeVQ.V_Sub hv (.convert (Ty.norm_idem _)) hg'.wf hg'.sorted hg'.declared
    have hfact : Entails [] (q.open (.boolean true)) := by
      apply Entails.of_conjuncts
      intro r hr
      rw [Pred.open,Pred.conjuncts_bind] at hr
      obtain ⟨s,hs,rfl⟩ := List.mem_map.mp hr
      exact hv'.facts rfl s (by
        rw [Ty.assume_refined (by simp [BooleanTy,Ty.Ordinary,Ordinary,Ty.core])]
        exact List.mem_append_right _ hs)
    have hp : Entails [] (predBind (valEnv cap.env).values (p.open (.boolean true))) := by
      rw [predBind_open_of_some _ p (.boolean true) (.boolean true) rfl]
      exact hfact
    have hcap := hc.addEntailed (hg.open_boolean true) hp
    have hh := ClosureTy.capture_resolved_closed hcap hb hl ha hR hr
    rwa [←hcode] at hh

private theorem ContTy.guard_true_inv {P B σ Ψ R ε ks input b Eb Re a}
    (h : ContTy P B σ Ψ R ε ks input b Eb Re) {v cap arms next body k}
    (hframes : ks = .guardF v cap arms next body :: k)
    (hv : HasTypeV P B Ψ [] [] [] (.const (.boolean true)) a)
    (hle : Ty.LeQ P [] [] a input) :
    ∃ R' ε' t e, ClosureTy P B Ψ [] R' body t e ∧ Eff.Sub e ε' ∧
      ContTy P B σ Ψ R' ε' k t b Eb Re := by
  match h with
  | .K_Guard hc hv' ho har hl hea hr hx hev hR hat het hb he hp hk had =>
    cases hframes
    have hi := hb.input_annotation
    exact ⟨_,_,_,_,hb.of_true (.V_Sub hv hle hi.wf hi.sorted hi.declared),he,hk⟩
  | .K_Sub hk hsub => exact hk.guard_true_inv hframes hv (.trans hle hsub)
  | .K_Empty .. | .K_Let .. | .K_Mark .. | .K_Update .. | .K_Release .. |
    .K_Handle .. | .K_Handle_Fail .. | .K_Drop .. => cases hframes
termination_by structural h

theorem ContTy.guard_true {P B σ Ψ R ε v cap arms next body k input b Eb Re a}
    (h : ContTy P B σ Ψ R ε (.guardF v cap arms next body :: k) input b Eb Re)
    (hv : HasTypeV P B Ψ [] [] [] (.const (.boolean true)) a)
    (hle : Ty.LeQ P [] [] a input) :
    ∃ R' ε' t e, ClosureTy P B Ψ [] R' body t e ∧ Eff.Sub e ε' ∧
      ContTy P B σ Ψ R' ε' k t b Eb Re := h.guard_true_inv rfl hv hle

private theorem ContTy.guard_false_inv {P B σ Ψ R ε ks input b Eb Re}
    (h : ContTy P B σ Ψ R ε ks input b Eb Re) {v cap arms next body k}
    (hframes : ks = .guardF v cap arms next body :: k) :
    ∃ R' ε' t e,
      (∃ vs, v = closeVal cap vs ∧ ClosureTy P B Ψ [] R' (.mk cap (.match vs arms)) t e) ∧
      Eff.Sub e ε' ∧ ContTy P B σ Ψ R' ε' k t b Eb Re ∧ MatchPrefix v arms next := by
  match h with
  | .K_Guard hc hv ho har hl hea hr hx hev hR hat het hb he hp hk had =>
    cases hframes
    have ha := hb.result_annotation
    rw [←hat,←het] at ha
    have hh := ClosureTy.capture_resolved_closed hc (.C_Match hv ho har hx) hl ha hR hr
    simp only [Comp.resolveLocals,HasTypeVQ.resolve_id hv,←hea] at hh
    rw [hat,het] at hh
    exact ⟨_,_,_,_,⟨_,hev,hh⟩,he,hk,hp⟩
  | .K_Sub hk hsub => exact hk.guard_false_inv hframes
  | .K_Empty .. | .K_Let .. | .K_Mark .. | .K_Update .. | .K_Release .. |
    .K_Handle .. | .K_Handle_Fail .. | .K_Drop .. => cases hframes
termination_by structural h

theorem ContTy.guard_false {P B σ Ψ R ε v cap arms next body k input b Eb Re}
    (h : ContTy P B σ Ψ R ε (.guardF v cap arms next body :: k) input b Eb Re) :
    ∃ R' ε' t e,
      (∃ vs, v = closeVal cap vs ∧ ClosureTy P B Ψ [] R' (.mk cap (.match vs arms)) t e) ∧
      Eff.Sub e ε' ∧ ContTy P B σ Ψ R' ε' k t b Eb Re ∧ MatchPrefix v arms next :=
  h.guard_false_inv rfl

private def Comp.isRet : Comp → Bool
  | .ret _ => true
  | _ => false

private theorem Closure.isRet_view (q : Closure) : q.view.isRet = q.code.isRet := by
  cases q with
  | mk cap code => cases code <;> rfl

private theorem Comp.isRet_resolve (m : Comp) (ρ : Nat → LocalRef) :
    (m.resolveLocals ρ).isRet = m.isRet := by
  cases m <;> rfl

private theorem closeVal_const_subst {cap : Capture} {v : Val} {c : Const}
    (h : closeVal cap v = .const c) : v.subst cap.env = .const c := by
  cases v <;> simp only [closeVal,Val.subst] at h ⊢ <;> first | exact h | cases h

/-- return の実際の定数を、開始の閉包の最終の結果型で型付ける。 -/
theorem ClosureTy.ret_const {P B Ψ R q a e c}
    (hA : Builtins.SubstitutionAssumptions P B) (hw : Ψ.WF)
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .ret (.const c)) :
    HasTypeV P B Ψ [] [] [] (.const c) a := by
  generalize hps : ([] : List Ty) = ps at hq
  cases hq with
  | mk hc hb hl hcode hss hcs hR ha hae hrs hrd =>
    rename_i ss cap code0 code Γ Φ Rs as es L ρ
    have hs : ss = [] := List.map_eq_nil_iff.mp hps.symm
    subst ss
    simp only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
      liftMany_eq,Ty.shiftV_zero,Capture.closeTyAt,Capture.closeEffAt,Capture.closeRAt,upSubst_zero,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      Option.map_id,List.map_id] at hb ⊢
    subst code
    have htag : code0.isRet = true := by
      have hh := congrArg Comp.isRet hv
      rw [Closure.isRet_view,Closure.code,Comp.isRet_resolve] at hh
      exact hh
    cases code0 <;> try cases htag
    rename_i v
    have ht := hb.ret_value rfl
    simp only [Comp.resolveLocals,Closure.view,Closure.code,Closure.capture,HasTypeVQ.resolve_id ht] at hv
    have hv' := Comp.ret.inj hv
    have hh := ht.subst hA hw hc.substOk
      (fun p hp => hc.conditions p (List.mem_append_right _ hp))
    rw [closeVal_const_subst hv'] at hh
    exact hh

theorem StateTyE.guard_true {P B σ Eb q v cap arms next body k μ}
    (hA : Builtins.SubstitutionAssumptions P B)
    (h : StateTyE P B σ Eb (.run q (.guardF v cap arms next body :: k) μ))
    (hv : q.view = .ret (.const (.boolean true))) :
    StateTyE P B σ Eb (.run body k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμc⟩ := h
  have ht := hq.ret_const hA hs.wf hv
  obtain ⟨R',ε',t,e',hb,hsub,hk'⟩ := hk.guard_true ht .refl
  have hf := hk.adequate _ List.mem_cons_self
  have hc := hkc _ List.mem_cons_self
  exact ⟨Ψ,R',t,b,ε',e',hs,hb,hsub,hk',hf.2.2.2,hc.2.2.2,
    (fun f hh => hkc f (List.mem_cons_of_mem _ hh)),hμc⟩

theorem StateTyE.guard_false {P B σ Eb q v cap arms next body k μ}
    (h : StateTyE P B σ Eb (.run q (.guardF v cap arms next body :: k) μ))
    (_hv : q.view = .ret (.const (.boolean false))) :
    StateTyE P B σ Eb (.matchRun v cap arms next k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμc⟩ := h
  obtain ⟨R',ε',t,e',hb,hsub,hk',hp⟩ := hk.guard_false
  have hf := hk.adequate _ List.mem_cons_self
  have hc := hkc _ List.mem_cons_self
  exact ⟨Ψ,R',t,b,ε',e',hs,hb,hsub,hk',hf.1,hf.2.1,hp,hc.1,hf.2.2.1,
    ⟨hc.2.1,hc.2.2.1⟩,(fun f hh => hkc f (List.mem_cons_of_mem _ hh)),hμc⟩

theorem Ty.LeQ.under_params {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) (ps : List Ty) :
    Ty.LeQ P (bindParams Γ ps) (liftMany ps.length Φ) (a.shiftV ps.length 0) (b.shiftV ps.length 0) := by
  have hm := ShiftMap.outer Γ ps
  have hh := h.rawBind (renEnv (shiftIndex ps.length 0))
    (hm.transport (fun p hp => (Entails.hyp (List.mem_append_right _ hp)).under_params ps))
  change Ty.LeQ P (bindParams Γ ps) (liftMany ps.length Φ)
    (renameTy (shiftIndex ps.length 0) a) (renameTy (shiftIndex ps.length 0) b) at hh
  rwa [renameTy_shiftIndex] at hh

/-- 全腕の期待型と効果を拡大する。追加した経路条件も同じ導出で読む。 -/
theorem HasTypeArmsQ.sub_result {P B Ψ Q C Γ Φ R obs arms a b e L b' e'}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L)
    (hle : Ty.LeQ P Γ Φ b b') (he : Eff.Covers Γ Φ e' e) (ha : Ty.Annotation P C Γ b') :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b' e' L := by
  match h with
  | .nil _ => exact .nil ha
  | .plain (δ := δ) (alts := alts) (links := links) hp hvf hfw hw hb hs =>
    have hlem := hle.weaken_conditions (Ξ := pathFacts obs (matchedTests alts) ++ Φ)
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_append_right _ hp)))
    have hlee := hle.weaken_conditions (Ξ := pathFacts obs (excludedTests alts) ++ Φ)
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_append_right _ hp)))
    have ha' := (ShiftMap.outer Γ δ).annotation ha
    have hbody := (hlem.under_params δ).weaken_conditions
      (Ξ := fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ))
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_append_right _ hp)))
    exact .plain hp hvf hfw hw (.C_Sub hb hbody (he.shiftV _ _)
      ha'.wf ha'.sorted ha'.declared) (hs.sub_result hlee he ha)
  | .guarded (δ := δ) (alts := alts) (p := p) (links := links) hp hvf hfw hw hgp hg hb hs =>
    have hlem := hle.weaken_conditions (Ξ := pathFacts obs (matchedTests alts) ++ Φ)
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_append_right _ hp)))
    have hbody := (hlem.under_params δ).weaken_conditions
      (Ξ := p.open (.boolean true) :: (fieldFacts δ.length obs links ++ liftMany δ.length (pathFacts obs (matchedTests alts) ++ Φ)))
      (by intro p hp; exact .hyp (List.mem_append_right _ (List.mem_cons_of_mem _ (List.mem_append_right _ hp))))
    have ha' := (ShiftMap.outer Γ δ).annotation ha
    exact .guarded hp hvf hfw hw hgp hg (.C_Sub hb hbody (he.shiftV _ _) ha'.wf ha'.sorted ha'.declared)
      (hs.sub_result hle he ha)
termination_by structural h

theorem HasTypeArmsQ.normal_result {P B Ψ Q C Γ Φ R obs arms a b e L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b.norm e L := by
  match h with
  | .nil ha => exact .nil ha.norm
  | .plain hp hvf hfw hw hb hs =>
    exact .plain hp hvf hfw hw (by simpa only [Ty.norm_shiftV] using hb.C_Normal) hs.normal_result
  | .guarded hp hvf hfw hw hgp hg hb hs =>
    exact .guarded hp hvf hfw hw hgp hg (by simpa only [Ty.norm_shiftV] using hb.C_Normal) hs.normal_result
termination_by structural h

theorem HasTypeArmsQ.eff_result {P B Ψ Q C Γ Φ R obs arms a b e e' L}
    (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) (he : Eff.Covers Γ Φ e' e) :
    HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e' L := by
  match h with
  | .nil ha => exact .nil ha
  | .plain hp hvf hfw hw hb hs => exact .plain hp hvf hfw hw (.C_Eff hb (he.shiftV _ _)) (hs.eff_result he)
  | .guarded hp hvf hfw hw hgp hg hb hs => exact .guarded hp hvf hfw hw hgp hg (.C_Eff hb (he.shiftV _ _)) (hs.eff_result he)
termination_by structural h

/-- match の変換規則の連鎖を、全腕の期待型へ戻す。 -/
theorem HasTypeCQ.match_arms {P B Ψ Q C Γ Φ R code b e L v arms}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code b e L) (hm : code = .match v arms) :
    ∃ a obs, HasTypeVQ P B Ψ Q C Γ Φ v a ∧
      (∀ t, obs = some t → v.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort) ∧
      HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L ∧ Exhaustive P a (unguardedPats arms) := by
  match h with
  | .C_Match hv ho ha hx => cases hm; exact ⟨_,_,hv,ho,ha,hx⟩
  | .C_Sub h hl he hw hs hd =>
    obtain ⟨a,obs,hv,ho,ha,hx⟩ := h.match_arms hm
    exact ⟨a,obs,hv,ho,ha.sub_result hl he ⟨hw,hs,hd⟩,hx⟩
  | .C_Eff h he =>
    obtain ⟨a,obs,hv,ho,ha,hx⟩ := h.match_arms hm
    exact ⟨a,obs,hv,ho,ha.eff_result he,hx⟩
  | .C_Normal h =>
    obtain ⟨a,obs,hv,ho,ha,hx⟩ := h.match_arms hm
    exact ⟨a,obs,hv,ho,ha.normal_result,hx⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. |
    .C_DependentApp .. | .C_If .. | .C_Lazy .. | .C_Escape .. | .C_Use .. |
    .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. |
    .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

/-- 未束縛入力のない閉包を、ソースの文脈・条件・局所参照の解決へ逆転する。 -/
theorem ClosureTy.open_zero {P B Ψ R q a e} (hq : ClosureTy P B Ψ [] R q a e) :
    ∃ cap Γ Φ Rs code0 as es L ρ,
      q = .mk cap (code0.resolveLocals ρ) ∧ CaptureOk P B Ψ R Γ Φ cap ∧
      HasTypeCQ P B Ψ Qempty [] Γ Φ Rs code0 as es L ∧ CaptureLocals Ψ cap.env L ρ ∧
      cap.closeR Rs = R ∧ cap.closeTy as = a ∧ cap.closeEff es = e ∧
      (∀ r, Rs = some r → r.Declared P [] Γ) := by
  generalize hps : ([] : List Ty) = ps at hq
  cases hq with
  | mk hc hb hl hcode hss hcs hR ha hae hrs hrd =>
    rename_i ss cap code0 code Γ Φ Rs as es L ρ
    have hs : ss = [] := List.map_eq_nil_iff.mp hps.symm
    subst ss
    simp only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
      liftMany_eq,Capture.closeTyAt,Capture.closeEffAt,Capture.closeRAt,upSubst_zero,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
      show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),
      Option.map_id,List.map_id] at hb hl hR hrs ⊢
    exact ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,by rw [hcode],hc,hb,hl,hR,rfl,rfl,hrs⟩

private def Comp.isMatch : Comp → Bool
  | .match .. => true
  | _ => false

private theorem Closure.isMatch_view (q : Closure) : q.view.isMatch = q.code.isMatch := by
  cases q with
  | mk cap code => cases code <;> rfl

private theorem Comp.isMatch_resolve (m : Comp) (ρ : Nat → LocalRef) :
    (m.resolveLocals ρ).isMatch = m.isMatch := by
  cases m <;> rfl

theorem ClosureTy.match_input_ground {P B Ψ R q a e v arms}
    (hq : ClosureTy P B Ψ [] R q a e) (hc : q.ClosedAt 0)
    (hv : q.view = .match v arms) : v.Ground := by
  obtain ⟨cap,Γ,Φ,Rs,code0,as,es,L,ρ,hqeq,hcap,hbody,hL,hR,ha,he,hr⟩ := hq.open_zero
  rw [hqeq] at hv hc
  have htag : code0.isMatch = true := by
    have hh := congrArg Comp.isMatch hv
    rw [Closure.isMatch_view,Closure.code,Comp.isMatch_resolve] at hh
    exact hh
  cases code0 <;> try cases htag
  rename_i vs as'
  obtain ⟨a0,obs,ht,ho,hars,hx⟩ := hbody.match_arms rfl
  simp only [Comp.resolveLocals,Closure.view,Closure.code,Closure.capture,HasTypeVQ.resolve_id ht] at hv hc
  have hv' := (Comp.match.inj hv).1
  rw [←hv']
  exact ht.close_ground hcap rfl hc.1 hc.2.1

theorem StateTyE.match_start {P B σ Eb q k μ v arms}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .match v arms) :
    StateTyE P B σ Eb (.matchRun v q.capture arms 0 k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,had,hcl,hkc,hμc⟩ := h
  have hg := hq.match_input_ground hcl hv
  cases q with
  | mk cap code =>
    have htag : code.isMatch = true := (Closure.isMatch_view _).symm.trans (congrArg Comp.isMatch hv)
    cases code <;> try cases htag
    rename_i vs as'
    simp only [Closure.view,Closure.code,Closure.capture] at hv
    have hpair := Comp.match.inj hv
    have hvEq := hpair.1
    cases hpair.2
    refine ⟨Ψ,R,a,b,e,e1,hs,⟨vs,hvEq.symm,hq⟩,he,hk,?_,had.1,?_,hg,had.2.2,
      ⟨hcl.1,hcl.2.2⟩,hkc,hμc⟩
    · rw [←hvEq]; exact closeVal_adequate had.1 had.2.1
    · intro arm hm; cases hm


theorem MatchPrefix.advance {v arms n alts guard body}
    (hp : MatchPrefix v arms n) (hi : arms[n]? = some (.mk alts guard body))
    (hf : firstAlt v alts = none) : MatchPrefix v arms (n+1) := by
  induction n generalizing arms with
  | zero =>
    cases arms with
    | nil => cases hi
    | cons arm arms =>
      cases Option.some.inj hi
      intro arm hm hg
      rcases List.mem_cons.mp hm with rfl | hm
      · exact hf
      · cases hm
  | succ n ih =>
    cases arms with
    | nil => cases hi
    | cons arm arms =>
      have htail : MatchPrefix v arms n := by
        intro a ha hg
        exact hp a (List.mem_cons_of_mem _ ha) hg
      have htail' := ih htail hi
      intro a ha hg
      rcases List.mem_cons.mp ha with rfl | ha
      · exact hp a List.mem_cons_self hg
      · exact htail' a ha hg

theorem StateTyE.match_skip {P B σ Eb v cap arms n alts guard body k μ}
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts guard body)) (hf : firstAlt v alts = none) :
    StateTyE P B σ Eb (.matchRun v cap arms (n+1) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,hva,hca,hp,hvg,har,hcl,hkc,hμc⟩ := h
  exact ⟨Ψ,R,a,b,e,e1,hs,hq,he,hk,hva,hca,hp.advance hi hf,hvg,har,hcl,hkc,hμc⟩

/-- 評価の成功だけを与える境界。本体の型付け・到達状態は入力に含めない。 -/
def PathsEvaluated (v : Val) (tests : List PathTest) : Prop :=
  ∀ p ∈ pathFacts v.toTerm? tests, p.evalClosed = some true

def MatchPathsEvaluated (v : Val) (arms : List Arm) (next : Nat) : Prop :=
  (∀ i alts guard body, arms[i]? = some (.mk alts guard body) → i < next → guard = none →
    PathsEvaluated v (excludedTests alts)) ∧
  (∀ alts guard body, arms[next]? = some (.mk alts guard body) →
    PathsEvaluated v (matchedTests alts))

theorem CaptureOk.addEvaluatedFacts {P B Ψ R Γ Φ cap added}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (hw : FactsWF P [] Γ added)
    (he : ∀ p ∈ added, (predBind (valEnv cap.env).values p).evalClosed = some true) :
    CaptureOk P B Ψ R Γ (added ++ Φ) cap := by
  induction added with
  | nil => exact hc
  | cons p ps ih =>
    exact (ih (fun q hq => hw q (List.mem_cons_of_mem _ hq))
      (fun q hq => he q (List.mem_cons_of_mem _ hq))).addEvaluated
        (hw p List.mem_cons_self) (he p List.mem_cons_self)

theorem CaptureOk.paths_evaluate {P B Ψ R Γ Φ cap vs obs tests v}
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs) (he : PathsEvaluated v tests) :
    ∀ p ∈ pathFacts obs tests, (predBind (valEnv cap.env).values p).evalClosed = some true := by
  cases obs with
  | none => intro p hp; cases hp
  | some t =>
    obtain ⟨ht,sort,hs⟩ := ho t rfl
    obtain ⟨u,hu,_⟩ := Term.hasSort_bind hs (valEnv cap.env).values
      hc.substOk.observations hc.substOk.references
    have hv' : v.toTerm? = some (termBind (valEnv cap.env).values t) := by
      rw [hv,closeVal_observation,Val.toTerm_subst_optional,ht,Option.bind_some,hu]
      simp only [termBind,hu,Option.getD_some]
    intro p hp
    change p ∈ tests.map (fun test => test.predicate t) at hp
    obtain ⟨test,htest,rfl⟩ := List.mem_map.mp hp
    rw [PathTest.bind]
    exact he _ (by simp only [pathFacts,hv']; exact List.mem_map.mpr ⟨test,htest,rfl⟩)

theorem HasTypeArmsQ.capture_plain {P B Ψ Γ Φ R Rs obs arms a b e L cap vs v n alts body}
    (h : HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms a b e L)
    (hc : CaptureOk P B Ψ R Γ Φ cap)
    (ho : ∀ t, obs = some t → vs.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort)
    (hv : v = closeVal cap vs)
    (hi : arms[n]? = some (.mk alts none body))
    (hz : Arm.bindersOf alts = 0)
    (he : MatchPathsEvaluated v arms n) :
    ∃ δ Ξ, AltsTy P alts a δ ∧ CaptureOk P B Ψ R Γ Ξ cap ∧
      HasTypeCQ P B Ψ Qempty [] (bindParams Γ δ) (liftMany δ.length Ξ)
        (Rs.map (Ty.shiftV δ.length 0)) body (b.shiftV δ.length 0) (e.shiftV δ.length 0)
        (localExtend δ.length L) := by
  match h with
  | .nil _ => simp at hi
  | .plain (δ := δ) (links := links) hp hvf hfw hw hb hs =>
    cases n with
    | zero =>
      cases Option.some.inj hi
      have hc' := hc.addEvaluatedFacts (FactsWF.left (by simpa only [pathFacts_append] using hw))
        (hc.paths_evaluate ho hv (he.2 _ _ _ rfl))
      have hlinks := hvf
      rw [hp.2.1,hz] at hlinks
      rw [hlinks.zero_eq_nil,fieldFacts_empty,List.nil_append] at hb
      exact ⟨δ,_,hp,hc',hb⟩
    | succ n =>
      have hc' := hc.addEvaluatedFacts (FactsWF.right (by simpa only [pathFacts_append] using hw))
        (hc.paths_evaluate ho hv (he.1 0 _ _ _ rfl (by omega) rfl))
      exact hs.capture_plain hc' ho hv hi hz ⟨
        (by intro i as g m hh hn hg; exact he.1 (i+1) as g m hh (by omega) hg),
        (by intro as g m hh; exact he.2 as g m hh)⟩
  | .guarded hp hvf hfw hw hgp hg hb hs =>
    cases n with
    | zero => cases Option.some.inj hi
    | succ n => exact hs.capture_plain hc ho hv hi hz ⟨
        (by intro i as g m hh hn hg; exact he.1 (i+1) as g m hh (by omega) hg),
        (by intro as g m hh; exact he.2 as g m hh)⟩
termination_by n

/-- 局所参照の解決はパターンと guard の有無を変えない。 -/
theorem Arm.resolveLocalsList_at {arms : List Arm} {n : Nat} {ρ : Nat → LocalRef} {arm : Arm}
    (h : (Arm.resolveLocalsList ρ arms)[n]? = some arm) :
    ∃ alts guard body, arms[n]? = some (.mk alts guard body) ∧
      arm = .mk alts (guard.map (Comp.resolveLocals (upLocalSubst (Arm.bindersOf alts) ρ)))
        (body.resolveLocals (upLocalSubst (Arm.bindersOf alts) ρ)) := by
  induction arms generalizing n with
  | nil => simp [Arm.resolveLocalsList] at h
  | cons a arms ih =>
    cases a with
    | mk alts guard body =>
      cases guard <;> cases n with
      | zero => cases Option.some.inj h; exact ⟨_,_,_,rfl,rfl⟩
      | succ n => exact ih h

theorem MatchPathsEvaluated.unresolve {v arms n ρ}
    (h : MatchPathsEvaluated v (Arm.resolveLocalsList ρ arms) n) :
    MatchPathsEvaluated v arms n := by
  have hat : ∀ (i : Nat) (as : List Alt) (g : Option Comp) (m : Comp), arms[i]? = some (.mk as g m) →
      (Arm.resolveLocalsList ρ arms)[i]? = some (.mk as
        (g.map (Comp.resolveLocals (upLocalSubst (Arm.bindersOf as) ρ)))
        (m.resolveLocals (upLocalSubst (Arm.bindersOf as) ρ))) := by
    clear h
    intro i as g m hi
    induction arms generalizing i with
    | nil => cases hi
    | cons a arms ih =>
      cases a with
      | mk as' g' m' =>
        cases i with
        | zero => cases Option.some.inj hi; cases g <;> rfl
        | succ i => cases g' <;> exact ih i hi
  exact ⟨(by intro i as g m hi hn hg; subst g; exact h.1 i as _ _ (hat _ _ _ _ hi) hn rfl),
    (by intro as g m hi; exact h.2 as _ _ (hat _ _ _ _ hi))⟩

/-- 閉包を逆転して得る照合のソース。外側の変換は既に腕へ反映する。 -/
theorem ClosureTy.match_source {P B Ψ R cap vs arms a e}
    (hq : ClosureTy P B Ψ [] R (.mk cap (.match vs arms)) a e) :
    ∃ Γ Φ Rs root obs arms0 input as es L ρ,
      CaptureOk P B Ψ R Γ Φ cap ∧ HasTypeV P B Ψ [] Γ Φ root input ∧
      (∀ t, obs = some t → root.toTerm? = some t ∧ ∃ sort, t.HasSort Γ sort) ∧
      HasTypeArmsQ P B Ψ Qempty [] Γ Φ Rs obs arms0 input as es L ∧
      CaptureLocals Ψ cap.env L ρ ∧ arms = Arm.resolveLocalsList ρ arms0 ∧
      vs = root ∧ cap.closeR Rs = R ∧ cap.closeTy as = a ∧ cap.closeEff es = e ∧
      (∀ r, Rs = some r → r.Declared P [] Γ) ∧ Exhaustive P input (unguardedPats arms0) := by
  obtain ⟨cap',Γ,Φ,Rs,code0,as,es,L,ρ,hqeq,hcap,hbody,hL,hR,ha,he,hr⟩ := hq.open_zero
  have hpair := Closure.mk.inj hqeq
  cases hpair.1
  have htag : code0.isMatch = true := by
    have hh := congrArg Comp.isMatch hpair.2
    rw [Comp.isMatch_resolve] at hh
    exact hh.symm
  cases code0 <;> try cases htag
  rename_i root arms0
  obtain ⟨input,obs,ht,ho,hars,hx⟩ := hbody.match_arms rfl
  simp only [Comp.resolveLocals,HasTypeVQ.resolve_id ht] at hpair
  have hcomp := Comp.match.inj hpair.2
  exact ⟨Γ,Φ,Rs,root,obs,arms0,input,as,es,L,ρ,hcap,ht,ho,hars,hL,
    hcomp.2,hcomp.1,hR,ha,he,hr,hx⟩

theorem adequateArms_body {σ : PathEnv} {arms : List Arm} {n : Nat} {alts : List Alt} {guard : Option Comp} {body : Comp} (h : adequateArms σ arms)
    (hi : arms[n]? = some (.mk alts guard body)) : body.Adequate σ := by
  induction arms generalizing n with
  | nil => cases hi
  | cons a arms ih =>
    cases a with
    | mk as g m =>
      cases n with
      | zero => cases Option.some.inj hi; cases guard <;> exact h.2.1
      | succ n => cases g <;> exact ih h.2.2 hi

theorem Arm.ClosedList_body {nt nv : Nat} {arms : List Arm} {n : Nat} {alts : List Alt} {guard : Option Comp} {body : Comp} (h : Arm.ClosedList nt nv arms)
    (hi : arms[n]? = some (.mk alts guard body)) : body.ClosedAt nt (nv + Arm.bindersOf alts) := by
  induction arms generalizing n with
  | nil => cases hi
  | cons a arms ih =>
    cases a with
    | mk as g m =>
      cases n with
      | zero => cases Option.some.inj hi; cases guard <;> exact h.2.1
      | succ n => cases g <;> exact ih h.2.2 hi

/-- 束縛数0の腕への E_MatchBody。評価の成功を境界入力とし、到達を逆転から導く。 -/
theorem StateTyE.match_body_zero {P B σ Eb v cap arms n alts body k μ}
    (h : StateTyE P B σ Eb (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts none body)) (hz : Arm.bindersOf alts = 0)
    (_hmatch : firstAlt v alts = some []) (heval : MatchPathsEvaluated v arms n) :
    StateTyE P B σ Eb (.run (.mk cap body) k μ) := by
  obtain ⟨Ψ,R,a,b,e,e1,hs,⟨vs,hv,hq⟩,he,hk,hva,hca,hprefix,hvg,har,hcl,hkc,hμc⟩ := h
  obtain ⟨Γ,Φ,Rs,root,obs,arms0,input,as,es,L,ρ,hcap,ht,ho,hars,hL,hea,hroot,hR,ha,hee,hr,hx⟩ := hq.match_source
  rw [hroot] at hv
  have hi' := hi
  rw [hea] at hi'
  obtain ⟨alts0,g0,body0,hi0,harmeq⟩ := Arm.resolveLocalsList_at hi'
  obtain ⟨healts,heguard,hebody⟩ := Arm.mk.inj harmeq
  have hg0 : g0 = none := by
    cases g0 with
    | none => rfl
    | some g => cases heguard
  subst g0
  cases healts
  have hbodyeq : body = body0.resolveLocals ρ := by simpa only [hz,upLocalSubst_zero] using hebody
  obtain ⟨δ,Ξ,hpat,hcap',hb⟩ := hars.capture_plain hcap ho hv hi0 hz (hea ▸ heval).unresolve
  have hd : δ = [] := List.eq_nil_of_length_eq_zero (hpat.2.1.trans hz)
  subst δ
  simp only [List.length_nil,bindParams,List.reverse_nil,List.map_nil,List.nil_append,
    liftMany_eq,Ty.shiftV_zero,Eff.shiftV_zero,localExtend,id_eq,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),
    show Pred.shiftV 0 0 = id from funext (fun p => p.shiftV_zero 0),Option.map_id,List.map_id] at hb
  have hAnn := hq.annotation
  rw [←ha,←hee] at hAnn
  have hdst := ClosureTy.capture_resolved_closed hcap' hb hL hAnn hR hr
  rw [ha,hee,←hbodyeq] at hdst
  have had : body.Adequate σ := adequateArms_body har hi
  have hclosed : body.ClosedAt 0 cap.values.length := by
    simpa only [hz,Nat.add_zero] using Arm.ClosedList_body hcl.2 hi
  exact ⟨Ψ,R,a,b,e,e1,hs,hdst,he,hk,⟨hca,had⟩,⟨hcl.1,hclosed⟩,hkc,hμc⟩

theorem StateTy.guard_true {P B σ q v cap arms next body k μ}
    (hA : Builtins.SubstitutionAssumptions P B)
    (h : StateTy P B σ (.run q (.guardF v cap arms next body :: k) μ))
    (hv : q.view = .ret (.const (.boolean true))) : StateTy P B σ (.run body k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.guard_true hA hv⟩

theorem StateTy.guard_false {P B σ q v cap arms next body k μ}
    (h : StateTy P B σ (.run q (.guardF v cap arms next body :: k) μ))
    (hv : q.view = .ret (.const (.boolean false))) : StateTy P B σ (.matchRun v cap arms next k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.guard_false hv⟩

theorem StateTy.match_start {P B σ q v arms k μ}
    (h : StateTy P B σ (.run q k μ)) (hv : q.view = .match v arms) :
    StateTy P B σ (.matchRun v q.capture arms 0 k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.match_start hv⟩

theorem StateTy.match_skip {P B σ v cap arms n alts guard body k μ}
    (h : StateTy P B σ (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts guard body)) (hf : firstAlt v alts = none) :
    StateTy P B σ (.matchRun v cap arms (n+1) k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.match_skip hi hf⟩

theorem StateTy.match_body_zero {P B σ v cap arms n alts body k μ}
    (h : StateTy P B σ (.matchRun v cap arms n k μ))
    (hi : arms[n]? = some (.mk alts none body)) (hz : Arm.bindersOf alts = 0)
    (hm : firstAlt v alts = some []) (he : MatchPathsEvaluated v arms n) :
    StateTy P B σ (.run (.mk cap body) k μ) := by
  obtain ⟨hσ,Eb,hEb,hs⟩ := h
  exact ⟨hσ,Eb,hEb,hs.match_body_zero hi hz hm he⟩

end
end Benitoite.Release.Refinement
