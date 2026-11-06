import Benitoite.Release.Refinement.SubstAgreement

/-! # 型付きの値と計算の置換の合同（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem substTypes_congr {Γ σ τ as} (h : referencesTys Γ as) (hs : SubstAgree Γ σ τ) :
    as.map (substTyValues σ) = as.map (substTyValues τ) := by
  cases as with
  | nil => rfl
  | cons a as => simp only [List.map_cons,substTyValues_congr h.1 hs,substTypes_congr h.2 hs]

theorem TypeAnnotations.subst_congr {P C Γ ts σ τ} (h : TypeAnnotations P C Γ ts)
    (hs : SubstAgree Γ σ τ) : ts.map (substTyValues σ) = ts.map (substTyValues τ) :=
  List.map_congr_left (fun a ha => substTyValues_congr (h a ha).sorted.references hs)

theorem RowAnnotations.subst_congr {P C Γ es σ τ} (h : RowAnnotations P C Γ es)
    (hs : SubstAgree Γ σ τ) : es.map (substEffValues σ) = es.map (substEffValues τ) :=
  List.map_congr_left (fun e he => substEffValues_congr (h e he).sorted.references.2.2 hs)

theorem substKind_congr {Γ σ τ kind} (h : Ty.References Γ kind.contents) (hs : SubstAgree Γ σ τ) :
    substKind σ kind = substKind τ kind := by
  cases kind with
  | string | bytes => rfl
  | list a => exact congrArg BuilderKind.list (substTyValues_congr h hs)

private theorem option_map_congr {α β : Type} (o : Option α) {f g : α → β}
    (h : ∀ v, o = some v → f v = g v) : o.map f = o.map g := by
  cases o with
  | none => rfl
  | some v => exact congrArg some (h v rfl)

private theorem checkAt_subst_congr {kind name shape bases pattern input index σ τ ρ η}
    (he : substTyValues σ shape.errorType = substTyValues τ shape.errorType)
    (hb : bases.map (fun v => v.subst σ ρ) = bases.map (fun v => v.subst τ η))
    (hp : pattern.subst σ ρ = pattern.subst τ η) (hv : input.subst σ ρ = input.subst τ η) :
    (Comp.checkAt kind name shape bases pattern input index).subst σ ρ =
      (Comp.checkAt kind name shape bases pattern input index).subst τ η := by
  cases bases with
  | none => simp only [Comp.subst,he,hp,hv]
  | some b =>
    simp only [Option.map_some,Option.some.injEq] at hb
    simp only [Comp.subst,he,hb,hp,hv]

mutual
  theorem HasTypeVQ.subst_congr {P B Ψ Q C Γ Φ v a σ τ ρ η}
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hs : SubstAgree Γ σ τ) :
      v.subst σ ρ = v.subst τ η := by
    match h with
    | .V_Var hi ho => exact hs _ _ hi
    | .V_Const .. | .V_Closure .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked ..
    | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => rfl
    | .V_Lam hn hw hsorted hb hd =>
      simp only [Val.subst,substTypes_congr (Ty.Sorted.references hsorted).1 hs]
      rw [HasTypeCQ.subst_congr hb (hs.hide.params _) (LocalSubstAgree.empty _ _)]
    | .V_DependentLam ha hb =>
      simp only [Val.subst,telBindValues_congr ha.sorted.references hs]
      rw [TelBodyTy.subst_congr (ρ := ρ) (η := η) hb hs.hide]
    | .V_Fun hd hn hr had hi => simp only [Val.subst,hi.types.subst_congr hs,hi.rows.subst_congr hs]
    | .V_Prim hb hr hn had hi => simp only [Val.subst,hi.types.subst_congr hs,hi.rows.subst_congr hs]
    | .V_Op ho hn had hi => simp only [Val.subst,hi.types.subst_congr hs]
    | .V_ExternalRef hd hw had hi => simp only [Val.subst,hi.types.subst_congr hs]
    | .V_ExternalHandle hh td hd hc hr hn ha =>
      simp only [Val.subst,substTypes_congr ha.sorted.references hs]
    | .V_Map hk hv hn hsat ha hb =>
      simp only [Val.subst,HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hk hs,HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Set hv hsat ha => simp only [Val.subst,HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Dict hi hsat hts hk hw ht hv ha =>
      simp only [Val.subst,hts.subst_congr hs,HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Raise ha hot hoe hk =>
      simp only [Val.subst,substTyValues_congr ha.sorted.references.2.1 hs,
        substTyValues_congr ha.sorted.references.1.1 hs]
    | .V_Con hc hn hk hw hv ha =>
      simp only [Val.subst,substTypes_congr ha.sorted.references hs,HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Super hv hc hm hd => simp only [Val.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_List hv hw hsorted hd => simp only [Val.subst,HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .V_Sub hv hl hw hsorted hd | .V_Normal hv => exact HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs
    | .V_Refine hv hi ht hsorted hw he hd hp => exact HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs
  termination_by structural h

  theorem HasTypeVsQ.subst_congr {P B Ψ Q C Γ Φ vs as σ τ ρ η}
      (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η := by
    match h with
    | .nil => rfl
    | .cons hv hvs => simp only [Val.substList,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hvs hs]
  termination_by structural h

  theorem HasTypeEachQ.subst_congr {P B Ψ Q C Γ Φ vs a σ τ ρ η}
      (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η := by
    match h with
    | .nil => rfl
    | .cons hv hvs => simp only [Val.substList,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,HasTypeEachQ.subst_congr (ρ := ρ) (η := η) hvs hs]
  termination_by structural h

  theorem HasTypeCQ.subst_congr {P B Ψ Q C Γ Φ R m a e L σ τ ρ η}
      (h : HasTypeCQ P B Ψ Q C Γ Φ R m a e L) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree L ρ η) : m.subst σ ρ = m.subst τ η := by
    match h with
    | .C_BuilderLet ha hk hb hd =>
      simp only [Comp.subst,substKind_congr ha.sorted.references hs]
      rw [HasTypeCQ.subst_congr hb (hs.extendOption none) (hL.extend _)]
    | .C_BuilderOp ha hk hr hargs =>
      simp only [Comp.subst,substKind_congr ha.sorted.references hs,hr.subst_congr hL,HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hargs hs]
    | .C_Return hv => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_Let hm hn hd => simp only [Comp.subst,HasTypeCQ.subst_congr hm hs hL,
        HasTypeCQ.subst_congr hn (hs.extendOption _) (hL.localExtend 1)]
    | .C_App hf hargs => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hf hs,HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hargs hs]
    | .C_DependentApp hf hargs => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hf hs,HasTypeTelArgsQ.subst_congr (ρ := ρ) (η := η) hargs hs]
    | .C_If hv ht hm hn => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,
        HasTypeCQ.subst_congr hm hs hL,HasTypeCQ.subst_congr hn hs hL]
    | .C_Match hv ho har hdecl hx => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,HasTypeArmsQ.subst_congr har hs hL]
    | .C_Lazy hb ha => simp only [Comp.subst,HasTypeCQ.subst_congr (ρ := ρ) (η := η) hb hs.hide (LocalSubstAgree.empty _ _)]
    | .C_Escape hv ha => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_Use hv hr hm he => simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,HasTypeCQ.subst_congr hm hs hL]
    | .C_Handle hm he hc => simp only [Comp.subst,HasTypeCQ.subst_congr hm hs hL,HasTypeClausesQ.subst_congr hc hs hL]
    | .C_Handle_Fail hm he hn hc => simp only [Comp.subst,HasTypeCQ.subst_congr hm hs hL,HasFailureClause.subst_congr hc hs hL]
    | .C_Resume hi hv hd | .C_ResumeNorm hi hv hd =>
      simp only [Comp.subst,Val.subst,hs _ _ hi,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_ResumeL hl hv hd => simp only [Comp.subst,Val.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_ResumeLNorm hl hr hv hd => simp only [Comp.subst,Val.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs]
    | .C_Normal hm | .C_Eff hm he | .C_Sub hm hl he hw hsorted hd => exact HasTypeCQ.subst_congr hm hs hL
    | .C_Meth (ss := ss) hv hc hm hn hsat hi hr hargs hvs ha =>
      have hts := (show TypeAnnotations P C Γ ss from fun a ha => hi.types a (List.mem_append_left _ ha)).subst_congr hs
      have hes := (show RowAnnotations P C Γ _ from hi.rows).subst_congr hs
      simp only [Comp.subst,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,hts,hes,HasTypeVsQ.subst_congr (ρ := ρ) (η := η) hvs hs]
    | .C_External hd hw had hargs =>
      simp only [Comp.subst,had.types_nil hw,List.map_nil,HasTypeTelArgsQ.subst_congr (ρ := ρ) (η := η) hargs hs]
    | .C_IssuePathBases .. => rfl
    | .C_CheckAt (shape := shape) (bases := bases) ha =>
      obtain ⟨hb,hp,hv⟩ := ha.subst_congr hs (ρ := ρ) (η := η)
      have hd : shape.Declared P := by cases ha <;> assumption
      have he : substTyValues σ shape.errorType = substTyValues τ shape.errorType := by
        rw [hd.errorType_eq]
        rfl
      exact checkAt_subst_congr he hb hp hv
  termination_by structural h

  theorem HasTypeTelArgsQ.subst_congr {P B Ψ Q C Γ Φ vs t a e σ τ ρ η}
      (h : HasTypeTelArgsQ P B Ψ Q C Γ Φ vs t a e) (hs : SubstAgree Γ σ τ) :
      Val.substList σ vs ρ = Val.substList τ vs η := by
    match h with
    | .done ha => rfl
    | .param ha hv ht => simp only [Val.substList,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs,HasTypeTelArgsQ.subst_congr (ρ := ρ) (η := η) ht hs]
  termination_by structural h

  theorem TelBodyTy.subst_congr {P B Ψ Q C Γ Φ t body σ τ ρ η}
      (h : TelBodyTy P B Ψ Q C Γ Φ t body) (hs : SubstAgree Γ σ τ) :
      body.subst (upSubst (telBinders t) σ) (upLocalSubst (telBinders t) ρ) =
        body.subst (upSubst (telBinders t) τ) (upLocalSubst (telBinders t) η) := by
    match h with
    | .done hb => simpa only [telBinders,upSubst_zero,upLocalSubst_zero] using
        HasTypeCQ.subst_congr hb hs (LocalSubstAgree.empty _ _)
    | .param hb => simpa only [telBinders,upSubst_add,upLocalSubst_add,Nat.add_comm 1] using
        TelBodyTy.subst_congr (ρ := upLocalSubst 1 ρ) (η := upLocalSubst 1 η) hb (hs.extendOption _)
  termination_by structural h

  theorem AtCallAdmissible.subst_congr {P B Ψ Q C Γ Φ kind name shape bases pattern input index σ τ ρ η}
      (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index)
      (hs : SubstAgree Γ σ τ) :
      bases.map (fun v => v.subst σ ρ) = bases.map (fun v => v.subst τ η) ∧
      pattern.subst σ ρ = pattern.subst τ η ∧ input.subst σ ρ = input.subst τ η := by
    match h with
    | .mk hd hk hb hp hi hv hw hr =>
      refine ⟨?_,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hp hs,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs⟩
      exact option_map_congr bases (fun v hv => HasTypeVQ.subst_congr (ρ := ρ) (η := η) (hb v hv) hs)
    | .text hd hk hb hp hi hv hw hr =>
      refine ⟨?_,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hp hs,HasTypeVQ.subst_congr (ρ := ρ) (η := η) hv hs⟩
      exact option_map_congr bases (fun v hv => HasTypeVQ.subst_congr (ρ := ρ) (η := η) (hb v hv) hs)

  termination_by structural h

  theorem HasTypeArmsQ.subst_congr {P B Ψ Q C Γ Φ R obs arms a b e L σ τ ρ η}
      (h : HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b e L) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree L ρ η) : Arm.substList σ arms ρ = Arm.substList τ arms η := by
    match h with
    | .nil ha => rfl
    | .plain hp hvf hfw hf hb ht =>
      simp only [Arm.substList,←hp.2.1]
      rw [HasTypeCQ.subst_congr hb (hs.params _) (hL.localExtend _),HasTypeArmsQ.subst_congr ht hs hL]
    | .guarded hp hvf hfw hf ha hg hb ht =>
      simp only [Arm.substList,←hp.2.1]
      rw [HasTypeCQ.subst_congr hg (hs.params _).hide (hL.localExtend _),
        HasTypeCQ.subst_congr hb (hs.params _) (hL.localExtend _),HasTypeArmsQ.subst_congr ht hs hL]
  termination_by structural h

  theorem HasTypeClausesQ.subst_congr {P B Ψ Q C Γ Φ R eb cs t e L σ τ ρ η}
      (h : HasTypeClausesQ P B Ψ Q C Γ Φ R eb cs t e L) (hs : SubstAgree Γ σ τ)
      (hL : LocalSubstAgree L ρ η) : Clause.substList σ cs ρ = Clause.substList τ cs η := by
    match h with
    | .nil => rfl
    | .cons (sg := sg) hs0 hn hn0 hk hw hb ht =>
      have hx := ((hs.shiftE sg.tparams.length).extendMany sg.params).extendOption (some ((sg.continuation t e).shiftV 1 0))
      simp only [Clause.substList,hn0,hk]
      rw [HasTypeCQ.subst_congr hb (by simpa only [OpSig.context,Ctx.extend,upSubst_add] using hx) (LocalSubstAgree.empty _ _),
        HasTypeClausesQ.subst_congr ht hs hL]
  termination_by structural h

  theorem HasFailureClause.subst_congr {P B Ψ Q C Γ Φ E R cs t e L σ τ ρ η}
      (h : HasFailureClause P B Ψ Q C Γ Φ E R cs t e L) (hs : SubstAgree Γ σ τ)
      (_hL : LocalSubstAgree L ρ η) : Clause.substList σ cs ρ = Clause.substList τ cs η := by
    match h with
    | .one he ht hec hb =>
      have hx := ((hs.shiftE 1).extendOption (some ((shiftTypes 1 0 E).shiftV 1 0))).extendOption none
      simp only [Clause.substList,substTyValues_congr he.sorted.references hs]
      rw [HasTypeCQ.subst_congr hb (by simpa only [failureContext,Ctx.extend,Ctx.extendNone,upSubst_add] using hx) (LocalSubstAgree.empty _ _)]
  termination_by structural h
end

end
end Benitoite.Release.Refinement
