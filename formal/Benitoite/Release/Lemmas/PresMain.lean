import Benitoite.Release.Lemmas.Dict

/-!
# 保存の定理の本体（段階 B）

遷移の規則ごとに、遷移した先の状態の型付けを作る。継続の末尾で許すエフェクト Eb は変わらない。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-! ## 保存 -/

theorem preservationE (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {Eb : Eff} {s : State} {ev : Option Event} {s' : State}
    (hs : StateTyE P B Eb s) (hst : Step P B s ev s') : StateTyE P B Eb s' := by
  cases hst with
  | E_Let =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a', b', ε', hm1, hn, hle, hs'⟩ := hm.inv_let rfl
      simp only [Comp.VarsIn] at hmc
      exact ⟨Ψ, R, a', b, ε, ε', hσ, hm1, hs'.trans hε, .K_Let hn (hs'.trans hε) (.K_Sub hk hle), hmc.1,
        Cont.Closed.cons.mpr ⟨hmc.2, hkc⟩, hσc⟩
  | E_Return =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a0, hv, hle⟩ := hm.inv_ret rfl
      obtain ⟨a', c, ε2, hle', hn, hs2, hk'⟩ := hk.inv_let
      simp only [Comp.VarsIn] at hmc
      have hkc' := Cont.Closed.cons.mp hkc
      have hwa : Ty.WF 0 a' := (hle.trans hle').wf (HasTypeV.wf hwf hb hv (envWF_nil 0) hσ.wf hmc)
      have hn' := hn
      rw [show ([some a'] : List (Option Ty)) = binds [a'] by simp [binds]] at hn'
      exact ⟨Ψ, R, c, b, ε, ε2, hσ,
        hn'.instantiate (InstOk.of_values hb (.cons (.V_Sub hv (hle.trans hle')) .nil) (by simpa using hwa)
          ⟨hmc, trivial⟩),
        hs2, hk', Comp.VarsIn.instantiate ⟨hmc, trivial⟩ hkc'.1, hkc'.2, hσc⟩
  | E_Lam hlen =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨as, b', ε', hf, hargs, hle, hs'⟩ := hm.inv_app rfl
      obtain ⟨r, ε'', hbody, hle2⟩ := hf.inv_lam rfl
      obtain ⟨hps, hr, hs2⟩ := Ty.Le.fn_fn' hle2
      subst hps hr
      simp only [Comp.VarsIn] at hmc
      have hlc := hmc.1
      simp only [Val.VarsIn] at hlc
      have hw := HasTypeV.wf hwf hb hf (envWF_nil 0) hσ.wf hmc.1
      simp only [Ty.WF] at hw
      have hbody' := hbody
      simp only [hideConts, List.map_nil, List.append_nil] at hbody'
      exact ⟨Ψ, some r, r, b, ε, ε'', hσ,
        hbody'.instantiate (InstOk.of_values hb hargs (hargs.wf_all hwf hb hσ.wf hmc.2) hmc.2),
        hs2.trans (hs'.trans hε), hk.markPush hle hw.2, Comp.VarsIn.instantiate hmc.2 hlc.2, hkc.markPush,
        hσc⟩
  | @E_Fun f ts es ws k σ d hd hwl htl hel =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨as, b', ε', hf, hargs, hle, hs'⟩ := hm.inv_app rfl
      obtain ⟨d', hd', hsat, hesl, hle2⟩ := hf.inv_fnRef rfl
      rw [hd] at hd'; cases hd'
      rw [fnTy_eq] at hle2
      obtain ⟨hps, hr, hs2⟩ := Ty.Le.fn_fn' hle2
      subst hps hr
      simp only [Comp.VarsIn] at hmc
      have hfc := hmc.1
      simp only [Val.VarsIn] at hfc
      have htsC : ClosedArgs ts := closedArgs_of hfc.1
      have hsc := hwf.1 f d hd
      have hθ := HasTypeC.substTy (c := 0) hwf hb (hwt.1 f d hd) (Nat.zero_le _) htsC (by simpa using hsat)
        (StoreFix.empty ts es)
      simp only [List.take_zero, Option.map_some, envSubst] at hθ
      rw [← binds_map] at hθ
      have hθ' := hθ.store (Ψ' := Ψ) (fun l x h => by simp [StoreTy.empty] at h)
      have hlen : ts.length = d.tparams.length := hsat.1
      have hretw : Ty.WF 0 (Ty.subst ts es d.ret) :=
        Ty.subst_wf0 es htsC (by rw [hlen]; exact Ty.VarsIn.wf _ hsc.2.1)
      refine ⟨Ψ, some (Ty.subst ts es d.ret), Ty.subst ts es d.ret, b, ε, Eff.substRho es d.eff, hσ,
        hθ'.instantiate (InstOk.of_values hb hargs (hargs.wf_all hwf hb hσ.wf hmc.2) hmc.2),
        hs2.trans (hs'.trans hε), hk.markPush hle hretw, ?_, hkc.markPush, hσc⟩
      refine Comp.VarsIn.instantiate hmc.2 (Comp.VarsIn.substTyAt (c := 0) es
        (fun u hu => varsInList_mem hfc.1 hu) d.body ?_)
      rw [Nat.zero_add, hlen]
      exact Comp.VarsIn.toTrue _ hsc.2.2.2
  | @E_Meth i ts vs m ss es ws k σ id body cd ms hi hbody hcd hms hwl hvl htl hsl hel =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      have hmc0 := hmc
      obtain ⟨cl, τ, cd', ms', hv, hcl, hms', hsat, hesl, hws, hle, hs'⟩ := hm.inv_meth rfl
      obtain ⟨id', hi', hsatI, hvs, he⟩ := hv.inv_dict rfl
      rw [hi] at hi'; cases hi'
      simp only [Ty.dict.injEq] at he
      obtain ⟨rfl, rfl⟩ := he
      rw [hcd] at hcl; cases hcl
      rw [hms] at hms'; cases hms'
      simp only [Comp.VarsIn, Val.VarsIn] at hmc
      have htsC : ClosedArgs (ss ++ ts) := by
        intro t ht
        rcases List.mem_append.mp ht with ht | ht
        · exact closedArgs_of hmc.2.1 t ht
        · exact closedArgs_of hmc.1.1 t ht
      obtain ⟨cd'', hcd'', _, _, hmeths, _⟩ := hwt.impl hi
      rw [hcd] at hcd''; cases hcd''
      obtain ⟨body', hbody', hbt⟩ := hmeths m ms hms
      rw [hbody] at hbody'; cases hbody'
      have hsc := hwf.impl hi
      have hmsc := hwf.meth hcd hms
      have hθ := HasTypeC.substTy (c := 0) (es' := es) hwf hb hbt (Nat.zero_le _) htsC
        (by simpa using SatAll.append hsat hsatI) (StoreFix.empty _ es)
      simp only [List.take_zero, Option.map_some, envSubst] at hθ
      rw [← binds_map, List.map_append] at hθ
      obtain ⟨hpar, hret⟩ := ImplDecl.methTy_subst (es := es) hsc hmsc hsatI.1 hsat.1
      have hdt := ImplDecl.dictTys_subst hsc es hsatI.1 hsat.1
      simp only [Ty.subst] at hpar hret hdt hθ
      rw [hpar, hret, hdt] at hθ
      have hθ' := hθ.store (Ψ' := Ψ) (fun l x h => by simp [StoreTy.empty] at h)
      have hretw := hle.wf_rev (HasTypeC.wf hwf hb hm (envWF_nil 0) hσ.wf hmc0)
      have hargs := HasTypeVs.append hvs hws
      have hargc := Val.VarsInList.append hmc.1.2 hmc.2.2.2
      refine ⟨Ψ, _, _, b, ε, _, hσ,
        hθ'.instantiate (InstOk.of_values hb hargs (hargs.wf_all hwf hb hσ.wf hargc) hargc),
        hs'.trans hε, hk.markPush hle (by simpa [Ty.subst] using hretw), ?_, hkc.markPush, hσc⟩
      have htsOK : ∀ u ∈ ss ++ ts, TyOK 0 u := by
        intro u hu
        rcases List.mem_append.mp hu with hu | hu
        · exact varsInList_mem hmc.2.1 hu
        · exact varsInList_mem hmc.1.1 hu
      refine Comp.VarsIn.instantiate hargc (Comp.VarsIn.substTyAt (c := 0) es htsOK body ?_)
      rw [Nat.zero_add, List.length_append, hsat.1, hsatI.1]
      exact Comp.VarsIn.toTrue _ (hsc.2.2.2 cd m ms body hcd hms hbody)
  | E_Super hsup =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨cl, τ, cd, ms, hv, hcl, hms, hsat, hesl, hws, hle, hs'⟩ := hm.inv_meth rfl
      simp only [Comp.VarsIn] at hmc
      obtain ⟨hv', hvc'⟩ := superStep_typed hwf hwt hb hσ.wf hsup hv hmc.1
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, .C_Sub (.C_Meth hv' hcl hms hsat hesl hws) hle hs', hε, hk,
        ⟨hvc', hmc.2⟩, hkc, hσc⟩
  | E_IfT =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a', ε', _, hm1, _, hle, hs'⟩ := hm.inv_ite rfl
      simp only [Comp.VarsIn] at hmc
      exact ⟨Ψ, R, a', b, ε, ε', hσ, hm1, hs'.trans hε, .K_Sub hk hle, hmc.2.1, hkc, hσc⟩
  | E_IfF =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a', ε', _, _, hm2, hle, hs'⟩ := hm.inv_ite rfl
      simp only [Comp.VarsIn] at hmc
      exact ⟨Ψ, R, a', b, ε, ε', hσ, hm2, hs'.trans hε, .K_Sub hk hle, hmc.2.2, hkc, hσc⟩
  | E_Match =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc,
        by intro ar har; simp at har⟩
  | E_MatchSkip hi hskip =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc, hp⟩ := hs
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc,
        hp.advance hi (by intro _; exact hskip)⟩
  | E_MatchBody hi hmatch =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc, _⟩ := hs
      obtain ⟨t, c, ε', hv, harms, _, hle, hsub⟩ := hm.inv_match rfl
      have hmem := List.mem_of_getElem? hi
      obtain ⟨δ, ha, hbody, _⟩ := harms.mem hmem
      simp only [Comp.VarsIn] at hmc
      obtain ⟨hbodyc, _⟩ := hmc.2.mem hmem
      have hws := ha.firstAlt_typed hv hmatch
      have hwsc := firstAlt_closed hmc.1 hmatch
      simp only [Arm.body, List.append_nil] at hbody hbodyc
      exact ⟨Ψ, R, c, b, ε, ε', hσ,
        hbody.instantiate (InstOk.of_values hb hws (hws.wf_all hwf hb hσ.wf hwsc) hwsc),
        hsub.trans hε, .K_Sub hk hle, Comp.VarsIn.instantiate hwsc hbodyc, hkc, hσc⟩
  | E_MatchGuard hi hmatch =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc, hp⟩ := hs
      obtain ⟨t, c, ε', hv, harms, _, hle, hsub⟩ := hm.inv_match rfl
      have hmem := List.mem_of_getElem? hi
      obtain ⟨δ, ha, hbody, hg⟩ := harms.mem hmem
      have hguard := hg _ rfl
      simp only [Comp.VarsIn] at hmc
      obtain ⟨hbodyc, hgc⟩ := hmc.2.mem hmem
      have hguardc := hgc _ rfl
      have hws := ha.firstAlt_typed hv hmatch
      have hwsc := firstAlt_closed hmc.1 hmatch
      have hiok := InstOk.of_values (R0 := R) hb hws (hws.wf_all hwf hb hσ.wf hwsc) hwsc
      simp only [Arm.body, List.append_nil] at hbody hguard hbodyc
      have hbody' := hbody.instantiate hiok
      have hguard' := hguard.subst ((SubstOk.inst hiok).hide none)
      simp only [hideConts, List.map_nil] at hguard'
      have hbc := Comp.VarsIn.instantiate hwsc hbodyc
      exact ⟨Ψ, none, .base .boolean, b, Eff.empty, Eff.empty, hσ, hguard', Eff.Sub.refl _,
        .K_Guard hm hε (hp.advance hi (by intro he; cases he)) (.C_Sub hbody' hle hsub) hk,
        Comp.VarsIn.instantiate hwsc hguardc, Cont.Closed.cons.mpr ⟨⟨hmc.1, hmc.2, hbc⟩, hkc⟩, hσc⟩
  | E_GuardT =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, _, _, hk, _, hkc, hσc⟩ := hs
      obtain ⟨R', ε', ε2, c, _, _, _, _, hε, _, hbody, hk'⟩ := hk.inv_guard
      have hcl := Cont.Closed.cons.mp hkc
      exact ⟨Ψ, R', c, b, ε', ε2, hσ, hbody, hε, hk', hcl.1.2.2, hcl.2, hσc⟩
  | E_GuardF =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, _, _, hk, _, hkc, hσc⟩ := hs
      obtain ⟨R', ε', ε2, c, _, _, _, hm, hε, hp, _, hk'⟩ := hk.inv_guard
      have hcl := Cont.Closed.cons.mp hkc
      exact ⟨Ψ, R', c, b, ε', ε2, hσ, hm, hε, hk', ⟨hcl.1.1, hcl.1.2.1⟩, hcl.2, hσc, hp⟩
  | E_ErrPopGuard =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, _, _, _, _, _, hk'⟩ := hk.inv_guard
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitPopGuard =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, _, _, _, _, _, hk'⟩ := hk.inv_guard
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | @E_Prim b0 ts es ws k σ s0 v hsig hkind hδ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨s', hs', htl, hel, had, hargs, hle, _⟩ := inv_prim_app hm
      rw [hsig] at hs'; cases hs'
      obtain ⟨o, hδ', _, hot⟩ := hb.delta_typed Ψ b0 _ ts es ws hsig hkind htl hel had hargs
      rw [hδ] at hδ'; cases hδ'
      exact stE_ret hσ hot.1 hle hk hot.2 hkc hσc
  | E_Err =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      exact stE_error hσ hk hkc hσc
  | @E_IO b0 ts es ws k σ s0 v hsig hkind _ hresp =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨s', hs', htl, hel, had, hargs, hle, _⟩ := inv_prim_app hm
      rw [hsig] at hs'; cases hs'
      have hot := hb.io_typed Ψ b0 _ ts es ws _ hsig (Or.inl hkind) htl hel had hargs hresp
      exact stE_ret hσ hot.1 hle hk hot.2 hkc hσc
  | E_IOErr =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      exact stE_error hσ hk hkc hσc
  | E_Exit =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      exact stE_exit hσ hk hkc hσc
  | @E_RefNew b0 ts es v k σ s0 l hsig hkind hl =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, rfl, rfl, hargs, hle, _⟩ := store_prim_inv hb hsig (by simp [hkind]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkind] at hsh
      obtain ⟨_, _, hps, hret, _⟩ := hsh
      rw [hps] at hargs; rw [hret] at hle
      simp only [List.map_cons, List.map_nil, Ty.subst_tvar0] at hargs
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hle
      rcases hargs with _ | ⟨hv, _⟩
      simp only [Comp.VarsIn] at hmc
      have ht := ClosedArgs.single hmc.1
      have hvc : Val.VarsIn 0 (fun _ => True) v := hmc.2.1
      have hΨl := hσ.none_of hl
      have hsub := StoreTy.set_sub (x := .ref t) (Or.inl hΨl)
      have hΨ'l : (Ψ.set l (.ref t)) l = some (.ref t) := by simp [StoreTy.set]
      exact stE_ret (hσ.set (x := .ref t) (ht t (by simp)).1 (Or.inl hΨl) ⟨t, hΨ'l, hv.store hsub⟩) (.V_LocRef hΨ'l) hle
        (hk.store hsub) trivial hkc (hσc.set hvc)
  | @E_RefGet b0 ts es l k σ s0 v hsig hkind hσl =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, rfl, rfl, hargs, hle, _⟩ := store_prim_inv hb hsig (by simp [hkind]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkind] at hsh
      obtain ⟨_, _, hps, hret, _⟩ := hsh
      rw [hps] at hargs; rw [hret, Ty.subst_tvar0] at hle
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs
      rcases hargs with _ | ⟨hl, _⟩
      obtain ⟨l', hl', hΨl⟩ := hl.canonical_ref
      cases hl'
      obtain ⟨a', hΨl2, hv'⟩ := hσ.2.2.2 _ _ hσl
      rw [hΨl] at hΨl2; cases hΨl2
      exact stE_ret hσ hv' hle hk (hσc _ _ hσl) hkc hσc
  | @E_RefSet b0 ts es l v k σ s0 hsig hkind =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, rfl, rfl, hargs, hle, _⟩ := store_prim_inv hb hsig (by simp [hkind]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkind] at hsh
      obtain ⟨_, _, hps, hret, _⟩ := hsh
      rw [hps] at hargs; rw [hret] at hle
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs hle
      rcases hargs with _ | ⟨hl, _ | ⟨hv, _⟩⟩
      obtain ⟨l', hl', hΨl⟩ := hl.canonical_ref
      cases hl'
      simp only [Comp.VarsIn] at hmc
      have hvc : Val.VarsIn 0 (fun _ => True) v := hmc.2.2.1
      exact stE_ret (hσ.set_same hΨl ⟨t, hΨl, hv⟩) (.V_Const (c := .unit)) hle hk trivial hkc (hσc.set hvc)
  | @E_RefUpdate b0 ts es l f k σ s0 hsig hkind =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, rfl, rfl, hargs, hle, hsub⟩ := store_prim_inv hb hsig (by simp [hkind]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkind] at hsh
      obtain ⟨_, _, hps, hret, heff⟩ := hsh
      rw [hps] at hargs; rw [hret] at hle; rw [heff] at hsub
      simp [Ty.subst, Ty.substAt, Ty.shift_zero, Eff.substRho_nil] at hargs hle
      rcases hargs with _ | ⟨hl, _ | ⟨hf, _⟩⟩
      obtain ⟨l', hl', hΨl⟩ := hl.canonical_ref
      cases hl'
      simp only [Comp.VarsIn] at hmc
      have ht := ClosedArgs.single hmc.1
      have hfc : Val.VarsIn 0 (fun _ => True) f := hmc.2.2.1
      have htc : Ty.VarsIn 0 (fun _ => True) t := by
        have := hmc.1
        simp only [Val.VarsIn, Ty.VarsInList] at this
        exact this.1.1
      refine ⟨Ψ, R, a, b, ε, ε1, hσ, .C_Sub (refUpdate_typed hb hΨl hf ht) hle hsub, hε, hk, ?_, hkc, hσc⟩
      simp only [Comp.VarsIn, Val.VarsIn, Val.VarsInList, Ty.VarsInList, Eff.RhosInList, and_true]
      exact ⟨htc, Val.VarsIn.rename _ f hfc, htc⟩
  | @E_Lazy m k σ l hl =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      have hw : Ty.WF 0 a := HasTypeC.wf hwf hb hm (envWF_nil 0) hσ.wf hmc
      obtain ⟨a', hm1, rfl⟩ := hm.inv_lazy rfl
      simp only [Ty.WF] at hw
      simp only [Comp.VarsIn] at hmc
      simp only [hideConts, List.map_nil] at hm1
      have hΨl := hσ.none_of hl
      have hsub := StoreTy.set_sub (x := .lazy a') (Or.inl hΨl)
      have hΨ'l : (Ψ.set l (.lazy a')) l = some (.lazy a') := by simp [StoreTy.set]
      exact stE_ret (hσ.set (x := .lazy a') hw (Or.inl hΨl) ⟨a', hΨ'l, hm1.store hsub⟩) (.V_LocLazy hΨ'l) (Ty.Le.refl _)
        (hk.store hsub) trivial hkc (hσc.set hmc)
  | @E_ForceDone b0 ts es l k σ s0 v hsig hkind hσl =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, rfl, rfl, hargs, hle, _⟩ := store_prim_inv hb hsig (by simp [hkind]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkind] at hsh
      obtain ⟨_, _, hps, hret, _⟩ := hsh
      rw [hps] at hargs; rw [hret, Ty.subst_tvar0] at hle
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs
      rcases hargs with _ | ⟨hl, _⟩
      obtain ⟨l', hl', hΨl⟩ := hl.canonical_lazy
      cases hl'
      obtain ⟨a', hΨl2, hv'⟩ := hσ.2.2.2 _ _ hσl
      rw [hΨl] at hΨl2; cases hΨl2
      exact stE_ret hσ hv' hle hk (hσc _ _ hσl) hkc hσc
  | @E_Force b0 ts es l k σ s0 m hsig hkind hσl =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, rfl, rfl, hargs, hle, _⟩ := store_prim_inv hb hsig (by simp [hkind]) hm
      have hsh := hb.store_shape _ _ hsig
      unfold PrimSig.StoreShape at hsh; rw [hkind] at hsh
      obtain ⟨_, _, hps, hret, _⟩ := hsh
      rw [hps] at hargs; rw [hret, Ty.subst_tvar0] at hle
      simp [Ty.subst, Ty.substAt, Ty.shift_zero] at hargs
      rcases hargs with _ | ⟨hl, _⟩
      obtain ⟨l', hl', hΨl⟩ := hl.canonical_lazy
      cases hl'
      obtain ⟨a', hΨl2, hm'⟩ := hσ.2.2.2 _ _ hσl
      rw [hΨl] at hΨl2; cases hΨl2
      exact ⟨Ψ, none, t, b, ε, Eff.empty, hσ, hm', Eff.empty_sub _, .K_Update hΨl (.K_Sub hk hle),
        hσc _ _ hσl, Cont.Closed.cons.mpr ⟨trivial, hkc⟩, hσc⟩
  | E_Update =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a0, hv, hle⟩ := hm.inv_ret rfl
      obtain ⟨a', R', hle', _, hΨl, hk'⟩ := hk.inv_update
      simp only [Comp.VarsIn] at hmc
      have hv' := HasTypeV.V_Sub hv (hle.trans hle')
      exact stE_ret (hσ.set_same hΨl ⟨a', hΨl, hv'⟩) hv' (Ty.Le.refl _) hk' hmc
        (Cont.Closed.cons.mp hkc).2 (hσc.set hmc)
  | E_Mark =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a0, hv, hle⟩ := hm.inv_ret rfl
      obtain ⟨a', R', hle', _, hk', _⟩ := hk.inv_mark
      simp only [Comp.VarsIn] at hmc
      exact stE_ret hσ hv (hle.trans hle') hk' hmc (Cont.Closed.cons.mp hkc).2 hσc
  | E_EscLet =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨r, hR, hv⟩ := hm.inv_escape rfl
      have hwa : Ty.WF 0 a := HasTypeC.wf hwf hb hm (envWF_nil 0) hσ.wf hmc
      obtain ⟨a', c, ε2, hle', hn, hs2, hk'⟩ := hk.inv_let
      have hkc' := Cont.Closed.cons.mp hkc
      have hwc : Ty.WF 0 c := HasTypeC.wf hwf hb hn (envWF_single (hle'.wf hwa)) hσ.wf hkc'.1
      subst hR
      exact ⟨Ψ, some r, c, b, ε, Eff.empty, hσ, .C_Escape hv hwc, Eff.empty_sub _, hk', hmc, hkc'.2, hσc⟩
  | E_EscHandle =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨r, hR, hv⟩ := hm.inv_escape rfl
      obtain ⟨t, εb, εc, _, _, hk', _, _, htw⟩ := hk.inv_handle
      subst hR
      exact ⟨Ψ, some r, t, b, εb, Eff.empty, hσ, .C_Escape hv htw, Eff.empty_sub _, hk', hmc,
        (Cont.Closed.cons.mp hkc).2, hσc⟩
  | E_EscMark =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨r, hR, hv⟩ := hm.inv_escape rfl
      obtain ⟨a', R', _, hR', hk', _⟩ := hk.inv_mark
      rw [hR] at hR'; cases hR'
      exact stE_ret hσ hv (Ty.Le.refl _) hk' hmc (Cont.Closed.cons.mp hkc).2 hσc
  | E_Use =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨o, b', ε', hv, hres, hm1, hst, hle, hs'⟩ := hm.inv_use rfl
      simp only [Comp.VarsIn] at hmc
      exact ⟨Ψ, R, b', b, ε, ε', hσ, hm1, hs'.trans hε,
        .K_Release hv hres (hε _ (hs' _ hst)) (.K_Sub hk hle), hmc.2, Cont.Closed.cons.mpr ⟨hmc.1, hkc⟩,
        hσc⟩
  | E_Release =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk', hmc, (Cont.Closed.cons.mp hkc).2, hσc⟩
  | E_RelErr =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_EscRel =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk', hmc, (Cont.Closed.cons.mp hkc).2, hσc⟩
  | E_EscRelErr =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrPopLet =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, hk'⟩ := hk.inv_let
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrPopMark =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk', _⟩ := hk.inv_mark
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrPopUpdate =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, hk'⟩ := hk.inv_update
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrPopHandle =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, hk', _⟩ := hk.inv_handle
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrRel =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrRelErr =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitPopLet =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, hk'⟩ := hk.inv_let
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitPopMark =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk', _⟩ := hk.inv_mark
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitPopUpdate =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, hk'⟩ := hk.inv_update
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitPopHandle =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, hk', _⟩ := hk.inv_handle
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitRel =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitRelErr =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, hk'⟩ := hk.inv_release
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_Handle =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨t, εm, ε', hm1, hsubm, hcl, hle, hs'⟩ := hm.inv_handle rfl
      simp only [Comp.VarsIn] at hmc
      have htw : Ty.WF 0 t := HasTypeC.wf hwf hb hm1 (envWF_nil 0) hσ.wf hmc.1
      exact ⟨Ψ, R, t, b, _, εm, hσ, hm1, hsubm, .K_Handle (.K_Sub hk hle) (hs'.trans hε) hcl htw, hmc.1,
        Cont.Closed.cons.mpr ⟨hmc.2, hkc⟩, hσc⟩
  | E_HRet =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨a0, hv, hle⟩ := hm.inv_ret rfl
      obtain ⟨t, εb, εc, hle', _, hk', _⟩ := hk.inv_handle
      simp only [Comp.VarsIn] at hmc
      exact stE_ret hσ hv (hle.trans hle') hk' hmc (Cont.Closed.cons.mp hkc).2 hσc
  | E_Op hsplit hc hκ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨od, hod, hsat, hargs, hle, _⟩ := inv_op_app hm
      simp only [Comp.VarsIn] at hmc
      have hvc := hmc.1
      simp only [Val.VarsIn] at hvc
      exact pres_op_common hwf hb hσ hk hvc hmc.2 hkc hσc (sg := ⟨od.tparams, od.params, od.ret, od.eff⟩)
        (by simp [opSig, hod]) hsat hargs hle hsplit hc hκ
  | @E_OpPrim b0 ts es ws k σ s0 k1 h k2 c κ hsig hkind hsplit hc hκ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨s', hs', htl, hel, had, hargs, hle, _⟩ := inv_prim_app hm
      rw [hsig] at hs'; cases hs'
      obtain ⟨l, bs, hop, _, hne, _, _⟩ := hb.io_op b0 _ hsig hkind
      have : es = [] := List.eq_nil_of_length_eq_zero (hel.trans hne)
      subst this
      simp only [Comp.VarsIn] at hmc
      have hvc := hmc.1
      simp only [Val.VarsIn] at hvc
      exact pres_op_common hwf hb hσ hk hvc.1 hmc.2 hkc hσc (sg := ⟨s0.tparams, s0.params, s0.ret, l⟩)
        (by simp [opSig, hsig, hop]) (hb.admits_sat b0 s0 [] ts hsig had) hargs hle hsplit hc hκ
  | E_Resume hσκ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨b', t', ε', hΨκ, hv, hle, hs'⟩ := hm.inv_resumeL rfl
      obtain ⟨b2, t2, ε2, r2, hΨκ2, hend, R'', ε'', hcell⟩ := hσ.2.2.2 _ _ hσκ
      rw [hΨκ] at hΨκ2
      simp only [Option.some.injEq, LocTy.cont.injEq] at hΨκ2
      obtain ⟨rfl, rfl, rfl, rfl⟩ := hΨκ2
      simp only [Comp.VarsIn] at hmc
      have hk' := hcell.resume_append hend hle hk (hs'.trans hε)
      have hkc' : Cont.Closed _ := hσc _ _ hσκ
      exact stE_ret (hσ.set_same hΨκ ⟨_, _, _, _, hΨκ⟩) hv (Ty.Le.refl _) hk' hmc.2
        (Cont.Closed.append.mpr ⟨hkc', hkc⟩) (hσc.set trivial)
  | E_ResumeErr =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      exact stE_error hσ hk hkc hσc
  | E_Drop =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, hk'⟩ := hk.inv_drop
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk', hmc, (Cont.Closed.cons.mp hkc).2, hσc⟩
  | E_DropRel hσκ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨h1, h2, h3, h4⟩ := dropRel_common hdecl hb hσ hσκ hk hkc hσc
      exact ⟨Ψ, R, a, b, ε, ε1, h1, hm, hε, h2, hmc, h3, h4⟩
  | E_EscDrop =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, hk'⟩ := hk.inv_drop
      exact ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk', hmc, (Cont.Closed.cons.mp hkc).2, hσc⟩
  | E_EscDropRel hσκ =>
      obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, hmc, hkc, hσc⟩ := hs
      obtain ⟨h1, h2, h3, h4⟩ := dropRel_common hdecl hb hσ hσκ hk hkc hσc
      exact ⟨Ψ, R, a, b, ε, ε1, h1, hm, hε, h2, hmc, h3, h4⟩
  | E_ErrDrop =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, hk'⟩ := hk.inv_drop
      exact stE_error hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ErrDropRel hσκ =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨h1, h2, h3, h4⟩ := dropRel_common hdecl hb hσ hσκ hk hkc hσc
      exact stE_error h1 h2 h3 h4
  | E_ExitDrop =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨_, _, _, _, _, _, hk'⟩ := hk.inv_drop
      exact stE_exit hσ hk' (Cont.Closed.cons.mp hkc).2 hσc
  | E_ExitDropRel hσκ =>
      obtain ⟨Ψ, R, a, b, ε, hσ, hk, hkc, hσc⟩ := hs
      obtain ⟨h1, h2, h3, h4⟩ := dropRel_common hdecl hb hσ hσκ hk hkc hσc
      exact stE_exit h1 h2 h3 h4

end Benitoite.Release
