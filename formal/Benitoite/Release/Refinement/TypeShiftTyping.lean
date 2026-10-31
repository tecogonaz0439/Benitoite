import Benitoite.Release.Refinement.HandlerAlgebra
import Benitoite.Release.Refinement.TypeShiftExchange
import Benitoite.Release.Refinement.PatternTypeShift

namespace Benitoite.Release.Refinement

private theorem raw_singleFail (a : Ty) (k c : Nat) :
    shiftRowsTypes k c (Eff.singleFail a)=Eff.singleFail (shiftTypes k c a) := by
  simp only [Eff.singleFail,shiftRowsTypes,shiftTypesList,Ty.norm_shiftTypes]

mutual
  theorem HasTypeVQ.shift_types {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k)
      (hm : TypeCtxMap k c Γ Δ) :
      HasTypeVQ P B store Q C' Δ Φ (v.shiftEAt k c) (shiftTypes k c a) := by
    match h with
    | .V_Var hi ho => exact .V_Var (hm.lookup _ _ hi) ((Ty.ordinary_shiftTypes _ _ _).mpr ho)
    | .V_Const (c := con) hc =>
      have he : shiftTypes k c con.type=con.type := by cases con <;> rfl
      rw [he]; exact .V_Const hc
    | .V_Lam (ps := ps) hnames hw hs hb hd =>
      simp only [Val.shiftEAt,shiftTypes,shiftTypesList_eq_map]
      refine .V_Lam (by simpa only [NamesWF,List.length_map] using hnames) ?_ ?_ ?_ ?_
      · simpa only [shiftTypes,shiftTypesList_eq_map,hn,hm.length] using Ty.wf_shiftTypes hw k c
      · simpa only [shiftTypes,shiftTypesList_eq_map] using Ty.sorted_shiftTypes hs hm
      · have hh := HasTypeCQ.shift_types hb hA hstore.hide hC hn (hm.hide.params ps)
        simpa only [shiftTypes_shiftV,shiftRowsTypes_shiftV,List.length_map,Option.map_some,LocalCtx.shiftEAt,List.map_nil] using hh
      · simpa only [shiftTypes,shiftTypesList_eq_map] using hd.shiftTypes hm
    | .V_DependentLam ha hb =>
      exact .V_DependentLam (hm.annotation hn ha) (TelBodyTy.shift_types hb hA hstore.hide hC hn hm.hide)
    | .V_Closure (runtime := runtime) (t := t) ha hw hb =>
      have he := Ty.shiftTypes_of_wf_zero (show (Ty.dependentFn t).WF 0 0 0 from hw.contract_wf) k c
      simpa only [Val.shiftEAt, he] using
        HasTypeVQ.V_Closure (Ψ := store) (Q := Q) (Φ := Φ)
          (by simpa only [he] using hm.annotation hn ha) hw hb
    | .V_List hv hw hs hd =>
      exact .V_List (HasTypeEachQ.shift_types hv hA hstore hC hn hm)
        (by simpa only [hn,hm.length] using Ty.wf_shiftTypes hw k c) (Ty.sorted_shiftTypes hs hm) (hd.shiftTypes hm)
    | .V_Fun hd hnames ha hi =>
      have hc := hi.kinds.1
      have hh := HasTypeVQ.V_Fun (Ψ := store) (Q := Q) (Φ := Φ) hd hnames (hm.admissible hn hA hC hi.types hi.rows ha) (hm.signature hn hi)
      simpa only [Val.shiftEAt,shiftTypes,hi.shiftTel k c] using hh
    | .V_Prim hb hr hnames ha hi =>
      have hc := hi.kinds.1
      have hh := HasTypeVQ.V_Prim (Ψ := store) (Q := Q) (Φ := Φ) hb hr hnames (hm.primitive hn hA hC hb hi.types hi.rows ha) (hm.signature hn hi)
      simpa only [Val.shiftEAt,shiftTypes,hi.shiftTel k c] using hh
    | .V_Op ho hnames ha hi =>
      have hc := hi.kinds.1
      have hh := HasTypeVQ.V_Op (Ψ := store) (Q := Q) (Φ := Φ) ho hnames (ha.shiftTypes hA hC hm hn hi.types) (hm.signature hn hi)
      simpa only [Val.shiftEAt,shiftTypes,List.map_nil,hi.shiftTel k c] using hh
    | .V_ExternalRef hd hw ha hi =>
      have hc := hi.kinds.1
      have hh := HasTypeVQ.V_ExternalRef (Ψ := store) (Q := Q) (Φ := Φ) hd hw (ha.shiftTypes hw k c) (hm.signature hn hi)
      simpa only [Val.shiftEAt,shiftTypes,List.map_nil,hi.shiftTel k c] using hh
    | .V_ExternalHandle h td hd hc hr hl ha =>
      simpa only [Val.shiftEAt,shiftTypes,shiftTypesList_eq_map] using
        HasTypeVQ.V_ExternalHandle h td hd hc hr (by simpa using hl) (hm.annotation hn ha)
    | .V_PathBases hs => exact .V_PathBases hs
    | .V_ScopePattern hw hc hk => exact .V_ScopePattern hw hc hk
    | .V_Checked hk hc ht => exact .V_Checked hk hc ht
    | .V_CheckedRequest hk hc hv hg ht he => exact .V_CheckedRequest hk hc hv hg ht he
    | .V_CheckedAt hw => exact .V_CheckedAt hw
    | .V_AtError hs =>
      simpa only [Val.shiftEAt,hs.errorType_eq,atErrorType,shiftTypes,shiftTypesList] using
        HasTypeVQ.V_AtError (Ψ := store) (Q := Q) (C := C') (Γ := Δ) (Φ := Φ) hs
    | .V_Map hv hw hl hs ha hb =>
      exact .V_Map (HasTypeEachQ.shift_types hv hA hstore hC hn hm)
        (HasTypeEachQ.shift_types hw hA hstore hC hn hm) (by simpa using hl)
        (hA.sat_shiftTypes_raw hC ha (hm.annotation hn ha) hs) (hm.annotation hn ha) (hm.annotation hn hb)
    | .V_Set hv hs ha =>
      exact .V_Set (HasTypeEachQ.shift_types hv hA hstore hC hn hm)
        (hA.sat_shiftTypes_raw hC ha (hm.annotation hn ha) hs) (hm.annotation hn ha)
    | .V_Dict (id := id) (ts := ts) hi hs ht hk hw htarget hv ha =>
      have hl := hs.1
      have hv' := HasTypeVsQ.shift_types hv hA hstore hC hn hm
      have he : (id.dictTys.map (Ty.subst ts [])).map (shiftTypes k c)=
          id.dictTys.map (Ty.subst (ts.map (shiftTypes k c)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.subst_shiftTypes (hw a ha) ts [] (by omega) k c)
      rw [he] at hv'
      have ha' := hm.annotation hn ha
      simp only [shiftTypes,Ty.subst_shiftTypes htarget ts [] (by omega)] at ha' ⊢
      exact .V_Dict hi (hs.shiftTypes hA hC hm hn ht) (hm.annotations hn ht) (hk.shiftTypes k c hn) hw htarget hv' ha'
    | .V_Raise ha =>
      simpa only [Val.shiftEAt,shiftTypes,shiftTypesList,List.map_cons,List.map_nil,raw_singleFail] using
        HasTypeVQ.V_Raise (by simpa only [shiftTypes,shiftTypesList,raw_singleFail] using hm.annotation hn ha)
    | .V_LocRef (a := a) hl hd =>
      have he := Ty.shiftTypes_of_wf_zero (hstore _ _ hl) k c
      simpa only [Val.shiftEAt,shiftTypes,he] using HasTypeVQ.V_LocRef hl (he ▸ hd.shiftTypes hm)
    | .V_LocLazy (a := a) hl hd =>
      have he := Ty.shiftTypes_of_wf_zero (hstore _ _ hl) k c
      simpa only [Val.shiftEAt,shiftTypes,he] using HasTypeVQ.V_LocLazy hl (he ▸ hd.shiftTypes hm)
    | .V_Bytes hb => exact .V_Bytes hb
    | .V_Con (cd := cd) (ts := ts) hc hl hk hw hv ha =>
      have hh := HasTypeVsQ.shift_types hv hA hstore hC hn hm
      have he : (cd.args.map (Ty.subst ts [])).map (shiftTypes k c)=
          cd.args.map (Ty.subst (ts.map (shiftTypes k c)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.subst_shiftTypes (hw a ha) ts [] (by omega) k c)
      rw [he] at hh
      simpa only [Val.shiftEAt,shiftTypes,shiftTypesList_eq_map] using
        HasTypeVQ.V_Con hc (by simpa using hl) (hk.shiftTypes k c hn) hw hh
          (by simpa only [shiftTypes,shiftTypesList_eq_map] using hm.annotation hn ha)
    | .V_Super hv hc hs hd =>
      exact .V_Super (HasTypeVQ.shift_types hv hA hstore hC hn hm) hc hs (hd.shiftTypes hm)
    | .V_Sub hv hl hw hs hd =>
      exact .V_Sub (HasTypeVQ.shift_types hv hA hstore hC hn hm) (hl.shiftTypes hm)
        (by simpa only [hn,hm.length] using Ty.wf_shiftTypes hw k c) (Ty.sorted_shiftTypes hs hm) (hd.shiftTypes hm)
    | .V_Refine hv hi ht hs hw he hda hdp =>
      exact .V_Refine (HasTypeVQ.shift_types hv hA hstore hC hn hm)
        ((Ty.hasSort_shiftTypes _ _ _ _).mpr hi) (by simpa only [Val.toTerm_shiftEAt] using ht)
        (Pred.sorted_shiftTypes hs hm) (by simpa only [hm.length] using hw) (hm.entails he)
        (hda.shiftTypes hm) (hdp.shiftTypes hm)
  termination_by structural h

  theorem HasTypeVsQ.shift_types {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasTypeVsQ P B store Q C' Δ Φ (Val.shiftEListAt k c vs) (as.map (shiftTypes k c)) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (HasTypeVQ.shift_types hv hA hstore hC hn hm) (HasTypeVsQ.shift_types hs hA hstore hC hn hm)
  termination_by structural h

  theorem HasTypeEachQ.shift_types {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasTypeEachQ P B store Q C' Δ Φ (Val.shiftEListAt k c vs) (shiftTypes k c a) := by
    match h with
    | .nil => exact .nil
    | .cons hv hs => exact .cons (HasTypeVQ.shift_types hv hA hstore hC hn hm) (HasTypeEachQ.shift_types hs hA hstore hC hn hm)
  termination_by structural h

  theorem HasTypeCQ.shift_types {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasTypeCQ P B store Q C' Δ Φ (R.map (shiftTypes k c)) (m.shiftEAt k c)
        (shiftTypes k c a) (shiftRowsTypes k c e) (L.shiftEAt k c) := by
    match h with
    | .C_BuilderLet (kind := kind) ha hk hb hd =>
      simp only [Comp.shiftEAt]
      refine .C_BuilderLet (by simpa only [shiftKindE_contents] using hm.annotation hn ha)
        (by simpa only [shiftKindE_contents,List.map_cons,List.map_nil] using hk.shiftTypes k c hn) ?_ (hd.shiftTypes hm)
      have hh := HasTypeCQ.shift_types hb hA hstore hC hn hm.none
      simpa only [shiftTypes_shiftV,shiftRowsTypes_shiftV,Option.map_map,Function.comp_def,
        LocalCtx.shiftEAt_extend,Option.map_some,shiftKindE_rename,localExtend] using hh
    | .C_BuilderOp ha hk hr hv =>
      simp only [Comp.shiftEAt]
      rw [←shiftKindE_result]
      exact .C_BuilderOp (by simpa only [shiftKindE_contents] using hm.annotation hn ha)
        (by simpa only [shiftKindE_contents,List.map_cons,List.map_nil] using hk.shiftTypes k c hn)
        (hr.shiftTypes hstore k c) (by simpa only [shiftKindE_parameters] using HasTypeVsQ.shift_types hv hA hstore hC hn hm)
    | .C_Return hv => exact .C_Return (HasTypeVQ.shift_types hv hA hstore hC hn hm)
    | .C_DependentApp hv ht =>
      exact .C_DependentApp (HasTypeVQ.shift_types hv hA hstore hC hn hm)
        (HasTypeTelArgsQ.shift_types ht hA hstore hC hn hm)
    | .C_App hv hs =>
      exact .C_App (HasTypeVQ.shift_types hv hA hstore hC hn hm)
        (by simpa only [shiftTypesList_eq_map] using HasTypeVsQ.shift_types hs hA hstore hC hn hm)
    | .C_If hv hb he =>
      exact .C_If (HasTypeVQ.shift_types hv hA hstore hC hn hm)
        (HasTypeCQ.shift_types hb hA hstore hC hn hm) (HasTypeCQ.shift_types he hA hstore hC hn hm)
    | .C_Match hv ha hx =>
      exact .C_Match (HasTypeVQ.shift_types hv hA hstore hC hn hm)
        (HasTypeArmsQ.shift_types ha hA hstore hC hn hm) (by rw [unguardedPats_shiftEAt]; exact hx.shift_types k c)
    | .C_Lazy hb ha => exact .C_Lazy (HasTypeCQ.shift_types hb hA hstore.hide hC hn hm.hide) (hm.annotation hn ha)
    | .C_Escape hv ha => exact .C_Escape (HasTypeVQ.shift_types hv hA hstore hC hn hm) (hm.annotation hn ha)
    | .C_Use hv hr hb he =>
      exact .C_Use (HasTypeVQ.shift_types hv hA hstore hC hn hm) hr
        (HasTypeCQ.shift_types hb hA hstore hC hn hm) (by cases e; exact he)
    | .C_Handle hb hc hh =>
      exact .C_Handle (HasTypeCQ.shift_types hb hA hstore hC hn hm)
        (by simpa only [Eff.shiftTypes_union,handled_shift_types,handled_shiftEAt] using hc.shiftTypes k c)
        (HasTypeClausesQ.shift_types hh hA hstore hC hn hm)
    | .C_Handle_Fail hb hc hnf hh =>
      simp only [Comp.shiftEAt,Eff.shiftTypes_union]
      exact .C_Handle_Fail (HasTypeCQ.shift_types hb hA hstore hC hn hm)
        (by simpa only [Eff.shiftTypes_union,raw_singleFail] using hc.shiftTypes k c)
        (hnf.shiftTypes k c) (HasFailureClause.shift_types hh hA hstore hC hn hm)
    | .C_Resume hi hv hd => exact .C_Resume (hm.lookup _ _ hi) (HasTypeVQ.shift_types hv hA hstore hC hn hm) (hd.shiftTypes hm)
    | .C_ResumeL (b := b) (t := t) (ε := ε) (R := r) hl hv hd =>
      have hw := hstore _ _ hl
      have hb := Ty.shiftTypes_of_wf_zero hw.1 k c
      have ht := Ty.shiftTypes_of_wf_zero hw.2.1 k c
      have he := Eff.shiftTypes_of_wf_zero hw.2.2.1 k c
      have hr : r.map (shiftTypes k c)=r := by
        cases ho : r with
        | none => rfl
        | some a => exact congrArg some (Ty.shiftTypes_of_wf_zero (hw.2.2.2.2 a ho) k c)
      have hv' := HasTypeVQ.shift_types hv hA hstore hC hn hm
      simp only [Comp.shiftEAt,Val.shiftEAt,hb,ht,he,hr] at hv' ⊢
      exact .C_ResumeL hl hv' (ht ▸ hd.shiftTypes hm)
    | .C_Meth hv hc hmeth hnames hs hi hr hargs hvs ha =>
      have hkc := hi.kinds.1
      have hl := hs.1
      have hs' := hs.shiftTypes hA hC hm hn (fun a hm' => hi.types a (List.mem_append_left _ hm'))
      have hargs' := Tel.arguments_shiftTypes hargs k c
      rw [hi.shiftTel k c] at hargs'
      simp only [List.map_append,List.map_cons,List.map_nil] at hargs'
      exact .C_Meth (HasTypeVQ.shift_types hv hA hstore hC hn hm) hc hmeth hnames hs'
        (by simpa only [List.map_append,List.map_cons,List.map_nil] using hm.signature hn hi)
        (hm.methodRows hn hi.rows hr) hargs' (HasTypeVsQ.shift_types hvs hA hstore hC hn hm) (hm.annotation hn ha)
    | .C_External (ts := ts) hd hw ha ht =>
      have hh := HasTypeTelArgsQ.shift_types ht hA hstore hC hn hm
      have hlen := ha.count
      have he := instantiatedTel_shiftTypes hw.annotation.wf ts [] (Nat.zero_le _) k c
      simp only [List.map_nil] at he
      change shiftTelTypes k c (Tel.bind (typeEnv _) _)=_ at he
      rw [he] at hh
      exact .C_External hd hw (ha.shiftTypes hw k c) hh
    | .C_IssuePathBases b sg hb hk ho hp hr he => exact .C_IssuePathBases b sg hb hk ho hp hr he
    | .C_CheckAt (bases := bases) hc =>
      have hh := AtCallAdmissible.shift_types hc hA hstore hC hn hm
      cases bases <;> simpa only [Comp.shiftEAt,shiftTypes,shiftTypesList,shiftRowsTypes,Eff.empty,Option.map_none,Option.map_some] using
        HasTypeCQ.C_CheckAt (R := R.map (shiftTypes k c)) (Δ := L.shiftEAt k c) hh
    | .C_Sub hb hl hc hw hs hd =>
      exact .C_Sub (HasTypeCQ.shift_types hb hA hstore hC hn hm) (hl.shiftTypes hm) (hc.shiftTypes k c)
        (by simpa only [hn,hm.length] using Ty.wf_shiftTypes hw k c) (Ty.sorted_shiftTypes hs hm) (hd.shiftTypes hm)
    | .C_Eff hb hc => exact .C_Eff (HasTypeCQ.shift_types hb hA hstore hC hn hm) (hc.shiftTypes k c)
    | .C_Let (a := x) ht hb hd =>
      refine .C_Let (HasTypeCQ.shift_types ht hA hstore hC hn hm) ?_ (hd.shiftTypes hm)
      have hh := HasTypeCQ.shift_types hb hA hstore hC hn (hm.extend x)
      simpa only [shiftTypes_shiftV,shiftRowsTypes_shiftV,Option.map_map,Function.comp_def,LocalCtx.shiftEAt_localExtend] using hh
  termination_by structural h

  theorem HasTypeArmsQ.shift_types {P B store Q C Γ Φ R arms a b e L}
      (h : HasTypeArmsQ P B store Q C Γ Φ R arms a b e L) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasTypeArmsQ P B store Q C' Δ Φ (R.map (shiftTypes k c)) (Arm.shiftEListAt k c arms)
        (shiftTypes k c a) (shiftTypes k c b) (shiftRowsTypes k c e) (L.shiftEAt k c) := by
    match h with
    | .nil ha => exact .nil (hm.annotation hn ha)
    | .plain (δ := δ) hp hb hs =>
      refine .plain (hp.shift_types k c) ?_ (HasTypeArmsQ.shift_types hs hA hstore hC hn hm)
      have hh := HasTypeCQ.shift_types hb hA hstore hC hn (hm.params δ)
      simpa only [shiftTypes_shiftV,shiftRowsTypes_shiftV,Option.map_map,Function.comp_def,
        List.length_map,LocalCtx.shiftEAt_localExtend] using hh
    | .guarded (δ := δ) hp hg hb hs =>
      refine .guarded (hp.shift_types k c) ?_ ?_ (HasTypeArmsQ.shift_types hs hA hstore hC hn hm)
      · simpa only [Option.map_none,shiftTypes,shiftRowsTypes,shiftTypesList,Eff.empty,LocalCtx.shiftEAt_localExtend,List.length_map] using
          HasTypeCQ.shift_types hg hA hstore hC hn (hm.params δ).hide
      · have hh := HasTypeCQ.shift_types hb hA hstore hC hn (hm.params δ)
        simpa only [shiftTypes_shiftV,shiftRowsTypes_shiftV,Option.map_map,Function.comp_def,
          List.length_map,LocalCtx.shiftEAt_localExtend] using hh
  termination_by structural h

  theorem HasTypeClausesQ.shift_types {P B store Q C Γ Φ R eb cs t e L}
      (h : HasTypeClausesQ P B store Q C Γ Φ R eb cs t e L) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasTypeClausesQ P B store Q C' Δ Φ (R.map (shiftTypes k c)) (shiftRowsTypes k c eb)
        (Clause.shiftEListAt k c cs) (shiftTypes k c t) (shiftRowsTypes k c e) (L.shiftEAt k c) := by
    match h with
    | .nil => exact .nil
    | .cons (sg := sg) hc hnames hN hK hw hb hs =>
      refine .cons (hc.shift_types k c) hnames hN hK hw ?_ (HasTypeClausesQ.shift_types hs hA hstore hC hn hm)
      have hC' : TypeParamRenaming (sg.tparams++C) (sg.tparams++C') (shiftIndex k (c+sg.tparams.length)) := by
        simpa only [upRen_shiftIndex] using hC.under sg.tparams
      have hn' : (sg.tparams++C').length=(sg.tparams++C).length+k := by simp only [List.length_append,hn]; omega
      have hh := HasTypeCQ.shift_types hb hA hstore.hide hC' hn' (hm.clause sg hw t e)
      simpa only [Option.map_map,Function.comp_def,shiftTypes_shiftV,shiftRowsTypes_shiftV,
        shiftTypes_comm,shiftRowsTypes_comm,hK,LocalCtx.shiftEAt,List.map_nil] using hh
  termination_by structural h

  theorem HasFailureClause.shift_types {P B store Q C Γ Φ E R cs t e L}
      (h : HasFailureClause P B store Q C Γ Φ E R cs t e L) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasFailureClause P B store Q C' Δ Φ (shiftTypes k c E) (R.map (shiftTypes k c))
        (Clause.shiftEListAt k c cs) (shiftTypes k c t) (shiftRowsTypes k c e) (L.shiftEAt k c) := by
    match h with
    | .one ha ht he hb =>
      simp only [Clause.shiftEListAt]
      refine .one (hm.annotation hn ha) (hm.annotation hn ht)
        (by simpa only [List.map_cons,List.map_nil] using hm.rows hn he) ?_
      have hC' : TypeParamRenaming (({} : TParam)::C) (({} : TParam)::C') (shiftIndex k (c+1)) := by
        simpa only [List.singleton_append,List.length_cons,List.length_nil,Nat.zero_add,upRen_shiftIndex] using hC.under [{}]
      have hn' : (({} : TParam)::C').length=(({} : TParam)::C).length+k := by simp only [List.length_cons,hn]; omega
      have hh := HasTypeCQ.shift_types hb hA hstore.hide hC' hn' (hm.failure E)
      simpa only [Option.map_map,Function.comp_def,shiftTypes_shiftV,shiftRowsTypes_shiftV,
        shiftTypes_comm,shiftRowsTypes_comm,LocalCtx.shiftEAt,List.map_nil] using hh
  termination_by structural h

  theorem HasTypeTelArgsQ.shift_types {P B store Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      HasTypeTelArgsQ P B store Q C' Δ Φ (Val.shiftEListAt k c vs) (shiftTelTypes k c t)
        (shiftTypes k c a) (shiftRowsTypes k c e) := by
    match h with
    | .done ha => exact .done (hm.annotation hn ha)
    | .param ha hv ht =>
      refine .param (hm.annotation hn ha) (HasTypeVQ.shift_types hv hA hstore hC hn hm) ?_
      rw [Tel.open_shiftTypes]
      exact HasTypeTelArgsQ.shift_types ht hA hstore hC hn hm
  termination_by structural h

  theorem TelBodyTy.shift_types {P B store Q C Γ Φ t body}
      (h : TelBodyTy P B store Q C Γ Φ t body) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hw : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k)
      (hm : TypeCtxMap k c Γ Δ) :
      TelBodyTy P B store Q C' Δ Φ (shiftTelTypes k c t) (body.shiftEAt k c) := by
    match h with
    | .done hb => exact .done (HasTypeCQ.shift_types hb hA hw hC hn hm)
    | .param (a := a) hb => exact .param (TelBodyTy.shift_types hb hA hw hC hn (hm.extend a))
  termination_by structural h

  theorem AtCallAdmissible.shift_types {P B store Q C Γ Φ kind name shape bases pattern input index}
      (h : AtCallAdmissible P B store Q C Γ Φ kind name shape bases pattern input index) {C' Δ k c}
      (hA : Builtins.TypeAssumptions P B) (hstore : store.WF)
      (hC : TypeParamRenaming C C' (shiftIndex k c)) (hn : C'.length=C.length+k) (hm : TypeCtxMap k c Γ Δ) :
      AtCallAdmissible P B store Q C' Δ Φ kind name {shape with errorType := shiftTypes k c shape.errorType}
        (bases.map (Val.shiftEAt k c)) (pattern.shiftEAt k c) (input.shiftEAt k c) index := by
    match h with
    | .mk hs hk hb hp ht hv hw hi =>
      have hb' := fun b he => HasTypeVQ.shift_types (hb b he) hA hstore hC hn hm
      have he : {shape with errorType := shiftTypes k c shape.errorType}=shape := by
        have hx : shiftTypes k c shape.errorType=shape.errorType := by rw [hs.errorType_eq]; rfl
        simp only [hx]
      rw [he]
      refine .mk hs hk ?_ (HasTypeVQ.shift_types hp hA hstore hC hn hm) ?_
        (HasTypeVQ.shift_types hv hA hstore hC hn hm) hw hi
      · intro v he
        cases bases with
        | none => cases he
        | some b => cases he; exact hb' b rfl
      · rcases ht with ⟨rfl,ht⟩|ht
        · exact Or.inl ⟨rfl,ht⟩
        · exact Or.inr ⟨by rw [Ty.shiftTypes_of_wf_zero ht.2]; exact ht.1,
            by simpa only [Ty.shiftTypes_of_wf_zero ht.2] using ht.2⟩
  termination_by structural h
end

end Benitoite.Release.Refinement
