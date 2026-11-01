import Benitoite.Release.Refinement.TypeSubstFormation
import Benitoite.Release.Refinement.TypeShiftContracts
import Benitoite.Release.Refinement.MethodArguments

/-! 呼出しの本体の型置換（設計書 07-04「01-12 との対応」）。 -/
namespace Benitoite.Release.Refinement
noncomputable section
set_option maxHeartbeats 2000000

private theorem row_kinds_subst {P C0 C1 e ts es}
    (h : kindsEff P (TypeCtx.kinds (C1 ++ C0)) e)
    (ht : TypeArgsKinded P [] ts (TypeCtx.kinds C0))
    (he : ∀ e ∈ es, kindsEff P [] e) :
    kindsEff P (TypeCtx.kinds C1) (Eff.substAt C1.length ts es e) := by
  have hk : Ty.HasKind P (TypeCtx.kinds (C1 ++ C0)) (.fn [] [] (.base .unit) e) .value :=
    ⟨by trivial, trivial, trivial, h⟩
  have hh := hk.substAt ht he
  exact hh.2.2.2

theorem SignatureInstance.substAt {P B} {Ψ : StoreTy} {C0 C1 Γ t ks as fs ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (h : SignatureInstance P (C1 ++ C0) Γ t ks as fs)
    (hr : t.RowsIn (· < fs.length)) :
    SignatureInstance P C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) t ks
      (as.map (Ty.substAt C1.length ts es)) (fs.map (Eff.substAt C1.length ts es)) := by
  refine ⟨h.source, h.types.substAt hf hi, h.kinds.substAt hi.typeKinds hi.rowKinds,
    h.rows.substAt hf hi, ?_, ?_⟩
  · intro e he
    obtain ⟨f, hf', rfl⟩ := List.mem_map.mp he
    exact row_kinds_subst (h.rowKinds f hf') hi.typeKinds hi.rowKinds
  · have ha := Tel.annotation_substAt hf hi h.result
    have hn := h.kinds.1
    rw [instantiatedTel_substAt h.source as fs (by omega) hr] at ha
    exact ha

theorem SatAll.substAt {P B C0 C1 as ps ts es}
    (hf : B.CoreAssumptions P)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (h : SatAll B (C1 ++ C0) as ps) :
    SatAll B C1 (as.map (Ty.substAt C1.length ts es)) ps := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a p ha hp
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  have hs := hf.sat_subst C0 C1 b.norm p ts es (h.2 i b p hb hp)
    hi.typeWF hi.constraints hi.typeCount
  rw [Ty.substAt_norm_source] at hs
  simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.norm_idem] using hs

theorem NoFail.substAt {Q Q' e} (h : NoFail Q e) (c : Nat) (ts : List Ty)
    (es : List Eff) (hq : RowTransport Q Q' es) :
    NoFail Q' (Eff.substAt c ts es e) := by
  have hq' : RowTransport Q Q' (typeEnvAt c ts es).rows :=
    hq.map _ (fun _ h => h.shiftTypes c 0) (fun _ => rfl)
  constructor
  · apply List.eq_nil_iff_forall_not_mem.mpr
    intro t ht
    have hm : Eff.memFail (Eff.substAt c ts es e) t := ⟨t, ht, rfl⟩
    change Eff.memFail (Eff.rawBind (typeEnvAt c ts es) e).norm t at hm
    rw [Eff.norm_memFail, Eff.memFail_rawBind] at hm
    rcases hm with ⟨x, hx, _⟩ | ⟨i, f, x, hf, he, hx, _⟩
    · simp only [h.1, List.not_mem_nil] at hx
    · have hn := hq' i (h.2 i he)
      rw [hf] at hn
      simp only [Option.getD_some] at hn
      simp only [hn.1, List.not_mem_nil] at hx
  · intro i hi
    change (Eff.rawBind (typeEnvAt c ts es) e).norm.mem (.rho i) at hi
    rw [Eff.mem_norm] at hi
    rcases (Eff.mem_rawBind _ _ _).mp hi with ⟨b, hb, he, hn⟩ | ⟨j, f, hf, hj, hi⟩
    · cases b with
      | name n r => cases he
      | rho j =>
        cases he
        have hx := hq' i (h.2 i hb)
        have hz : (typeEnvAt c ts es).rows[i]? = none :=
          List.getElem?_eq_none_iff.mpr hn
        rw [hz] at hx
        exact hx.2 i (by simp [Eff.row, Eff.test, Eff.atoms])
    · have hx := hq' j (h.2 j hj)
      rw [hf] at hx
      exact hx.2 i hi

private theorem op_subst {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ {C0 C1 o us ts es Q'}, C = C1 ++ C0 → v = .op o us →
    (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
    TypeSubstInput P B C0 C1 ts es → RowTransport Q Q' es →
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.op o us).substTyAt C1.length ts es) (a.substAt C1.length ts es) := by
  match h with
  | .V_Op (od := od) (ts := args) hl hn hs hi =>
    intro C0 C1 o us ts es Q' hC hv hf inp hq
    cases hv
    have hi' : SignatureInstance P (C1 ++ C0) Γ od.tel
        (List.replicate od.tparams.length .value) args [] := by simpa only [hC] using hi
    have hs' : SatAll B (C1 ++ C0) args od.tparams := by simpa only [hC] using hs
    have hr := (hf.1.ops _ _ hl).2.2.2.2.1
    have hx := hi'.substAt hf inp hr
    have out := HasTypeVQ.V_Normal (HasTypeVQ.V_Op (Ψ := Ψ) (Q := Q') (Φ := Φ) hl hn (hs'.substAt hf.2.2.1 inp) hx)
    have hnArgs := hi'.kinds.1
    have comm := instantiatedTel_substAt hi'.source args [] (by omega) hr C1.length ts es
    simp only [List.map_nil] at comm
    rw [← comm] at out
    simp only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind,
      Ty.norm, Tel.substAt, Tel.bind, Tel.norm_idem] at out ⊢
    exact out
  | .V_Sub (b := b) hv hl hw hs hd =>
    intro C0 C1 o us ts es Q' hC he hf inp hq
    have hsrc : Ty.Annotation P (C1 ++ C0) Γ b := by simpa only [hC] using Ty.Annotation.mk hw hs hd
    have ha := hsrc.substAt hf inp
    exact .V_Sub (op_subst hv hC he hf inp hq)
      (hl.substAt _ _ _ inp.typeKinds.ordinary) ha.wf ha.sorted ha.declared
  | .V_Normal hv =>
    intro C0 C1 o us ts es Q' hC he hf inp hq
    simpa only [Ty.substAt_norm_source] using op_subst hv hC he hf inp hq
  | .V_Refine _ _ ht .. =>
    intro C0 C1 o us ts es Q' hC he hf inp hq
    cases he
    cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. |
      .V_Prim .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. | .V_LocRef .. | .V_LocLazy .. =>
    intro C0 C1 o us ts es Q' hC he
    cases he
termination_by structural h

theorem gate_op_case {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ o us a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (_hc : TypeSubstCode es (fun nr nt ne nv => (Val.op o us).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.op o us) a) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.op o us).substTyAt C1.length ts es) (a.substAt C1.length ts es) :=
  op_subst h rfl rfl hf hi hq

private theorem fun_subst {P B Ψ Q C Γ Φ v a} (h : HasTypeVQ P B Ψ Q C Γ Φ v a) :
    ∀ {C0 C1 f us fs ts es Q'}, C = C1 ++ C0 → v = .fnRef f us fs →
    (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) →
    TypeSubstInput P B C0 C1 ts es → RowTransport Q Q' es →
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.fnRef f us fs).substTyAt C1.length ts es) (a.substAt C1.length ts es) := by
  match h with
  | .V_Fun (d := d) (ts := args) (es := effs) hl hn hs hi =>
    intro C0 C1 f us fs ts es Q' hC hv hf inp hq
    cases hv
    have hi' : SignatureInstance P (C1 ++ C0) Γ d.tel (TypeCtx.kinds d.tparams) args effs := by
      simpa only [hC] using hi
    have hs' : Admissible B (C1 ++ C0) Γ.length (TypeCtx.constraints d.tparams) d.neffs
        (Qsig d.params d.ret d.eff) Q args effs d.eff := by simpa only [hC] using hs
    have hr : d.tel.RowsIn (· < effs.length) := by
      simpa only [hs'.rowCount] using (hf.1.defs _ _ hl).2.1.2.1
    have hx := hi'.substAt hf inp hr
    have had : Admissible B C1 (Γ.bindTypes (typeEnvAt C1.length ts es)).length
        (TypeCtx.constraints d.tparams) d.neffs (Qsig d.params d.ret d.eff) Q'
        (args.map (Ty.substAt C1.length ts es))
        (effs.map (Eff.substAt C1.length ts es)) d.eff := by
      refine ⟨hs'.types.substAt hf.2.2.1 inp, hx.typeScope,
        by simpa only [List.length_map] using hs'.rowCount, ?_,
        by simpa only [List.length_map] using hs'.sourceRows,
        by simpa only [List.length_map] using hs'.sourceQ, ?_⟩
      · intro e he
        simpa only [Ctx.bindTypes, List.length_map] using (hx.rows e he).wf.2.2.2.1
      · intro i hsrc
        have hb := hs'.sourceQ i hsrc
        have he := List.getElem?_eq_getElem hb
        have hnf := (hs'.noFailRows i hsrc).substAt C1.length ts es hq
        simpa only [List.getElem?_map, he, Option.map_some, Option.getD_some] using hnf
    have out := HasTypeVQ.V_Normal (HasTypeVQ.V_Fun (Ψ := Ψ) (Q := Q') (Φ := Φ) hl hn had hx)
    have hnArgs := hi'.kinds.1
    have comm := instantiatedTel_substAt hi'.source args effs (by omega) hr C1.length ts es
    rw [←comm] at out
    simp only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind,
      Ty.norm, Tel.substAt, Tel.bind, Tel.norm_idem] at out ⊢
    exact out
  | .V_Sub (b := b) hv hl hw hs hd =>
    intro C0 C1 f us fs ts es Q' hC he hf inp hq
    have hsrc : Ty.Annotation P (C1 ++ C0) Γ b := by
      simpa only [hC] using Ty.Annotation.mk hw hs hd
    have ha := hsrc.substAt hf inp
    exact .V_Sub (fun_subst hv hC he hf inp hq)
      (hl.substAt _ _ _ inp.typeKinds.ordinary) ha.wf ha.sorted ha.declared
  | .V_Normal hv =>
    intro C0 C1 f us fs ts es Q' hC he hf inp hq
    simpa only [Ty.substAt_norm_source] using fun_subst hv hC he hf inp hq
  | .V_Refine _ _ ht .. =>
    intro C0 C1 f us fs ts es Q' hC he hf inp hq
    cases he
    cases ht
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Op .. |
      .V_Prim .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. |
      .V_Set .. | .V_Dict .. | .V_Raise .. | .V_Bytes .. | .V_Con .. | .V_Super .. |
      .V_List .. | .V_LocRef .. | .V_LocLazy .. =>
    intro C0 C1 f us fs ts es Q' hC he
    cases he
termination_by structural h

theorem gate_fun_case {P B} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ f us fs a ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (_hc : TypeSubstCode es (fun nr nt ne nv => (Val.fnRef f us fs).SourceScoped nr nt ne nv))
    (hq : RowTransport Q Q' es)
    (h : HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ (.fnRef f us fs) a) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.fnRef f us fs).substTyAt C1.length ts es) (a.substAt C1.length ts es) :=
  fun_subst h rfl rfl hf hi hq

mutual
  theorem Val.toTerm_typeSubst (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      (v.substTyAt c ts es).toTerm? = v.toTerm? := by
    cases v
    case const con => cases con <;> rfl
    all_goals simp only [Val.substTyAt, Val.toTerm?, slots_typeSubst]
  private theorem slots_typeSubst (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
      Val.toTermSlots (Val.substTyAtList c ts es vs) = Val.toTermSlots vs := by
    cases vs with
    | nil => rfl
    | cons v vs => simp only [Val.substTyAtList, Val.toTermSlots,
        Val.toTerm_typeSubst, slots_typeSubst]
end

private theorem typeEnv_open (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
    (typeEnvAt c ts es).up.mapValues (openingEnv v.toTerm?) = typeEnvAt c ts es := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i
    exact Ty.substV_shift_cancel _ (by intro i; rfl)
  · change ((typeEnvAt c ts es).rows.map (Eff.shiftV 1 0)).map
        (Eff.rawSubstV (openingEnv v.toTerm?)) = (typeEnvAt c ts es).rows
    have hh : (typeEnvAt c ts es).rows.map
        (fun e => Eff.rawSubstV (openingEnv v.toTerm?) (Eff.shiftV 1 0 e)) =
        (typeEnvAt c ts es).rows.map id :=
      List.map_congr_left (fun e _ => Eff.substV_shift_cancel e (by intro i; rfl))
    simpa only [List.map_map, Function.comp_def, List.map_id] using hh

theorem Tel.open_typeSubst (t : Tel) (v : Val) (c : Nat) (ts : List Ty) (es : List Eff) :
    Tel.bind (Tel.argumentsEnv (v.substTyAt c ts es))
      (Tel.bind (typeEnvAt c ts es).up t) =
    (Tel.bind (Tel.argumentsEnv v) t).substAt c ts es := by
  simp only [argumentsEnv_eq, Val.toTerm_typeSubst, Tel.substAt, Tel.bind, Tel.norm_rawBind]
  simp only [SubstEnv.valuesOnly, ← Tel.rawSubstV_eq_rawBind]
  rw [Tel.rawBind_substV _ _ (by simp [SubstEnv.up, typeEnvAt, upValues_id]), typeEnv_open]

theorem Tel.arguments_typeSubst (t : Tel) (vs : List Val) (c : Nat)
    (ts : List Ty) (es : List Eff) :
    Tel.arguments (t.substAt c ts es) (vs.map (Val.substTyAt c ts es)) =
      (Tel.arguments t vs).map (fun (as, r, e) =>
        (as.map (Ty.substAt c ts es), r.substAt c ts es, Eff.substAt c ts es e)) := by
  induction vs generalizing t with
  | nil => cases t <;> simp only [Tel.substAt, Tel.bind_done, Tel.bind_param,
      Tel.arguments, List.map_nil, Option.map_none, Option.map_some,
      Ty.substAt, substTypeAt, Ty.bind, Ty.norm_rawBind, Ty.norm_idem, Eff.substAt,
      substRowAt, Eff.bind, Eff.norm_rawBind, Eff.norm_idem]
  | cons v vs ih => cases t with
    | done r e => simp only [Tel.substAt, Tel.bind_done, Tel.arguments, List.map_cons, Option.map_none]
    | param n a t =>
      simp only [Tel.substAt, Tel.bind_param, List.map_cons, Tel.arguments]
      rw [Tel.open_typeSubst, ih]
      simp only [Option.map_map]
      congr 1
      funext x
      obtain ⟨as, r, e⟩ := x
      simp only [Function.comp_def, List.map_cons,
        Ty.substAt, substTypeAt, Ty.bind, Ty.norm_rawBind, Ty.norm_idem]

theorem Val.substTyAtList_eq_map (vs : List Val) (c : Nat) (ts : List Ty) (es : List Eff) :
    Val.substTyAtList c ts es vs = vs.map (Val.substTyAt c ts es) := by
  induction vs <;> simp only [Val.substTyAtList, List.map_cons, List.map_nil, *]

theorem HasTypeCQ.type_subst_meth {P B} {Ψ : StoreTy}
    {Q Q' C0 C1 Γ Φ} {R : Option Ty} {L : LocalCtx}
    {v cl τ cd m ms ss fs ws as a e ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es) (hq : RowTransport Q Q' es)
    (hc : P.classes cl = some cd) (hm : cd.methods m = some ms)
    (hn : NamesWF ms.names ms.params)
    (hs : SatAll B (C1 ++ C0) ss (TypeCtx.constraints ms.tparams))
    (hsi : SignatureInstance P (C1 ++ C0) Γ ms.tel
      (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) fs)
    (hr : MethodRowsAdmissible (C1 ++ C0) Γ.length Q ms fs)
    (ha : Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) fs) ws = some (as, a, e))
    (hann : Ty.Annotation P (C1 ++ C0) Γ a)
    (ihv : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) ((Ty.dict cl τ).substAt C1.length ts es))
    (ihws : HasTypeVsQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (ws.map (Val.substTyAt C1.length ts es)) (as.map (Ty.substAt C1.length ts es))) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (R.map (Ty.substAt C1.length ts es))
      ((Comp.meth v m ss fs ws).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) := by
  have hrows : ms.tel.RowsIn (· < fs.length) := by
    simpa only [hr.1] using (hf.1.classes cl cd hc m ms hm).2.2.1
  have si := hsi.substAt hf hi hrows
  have rr : MethodRowsAdmissible C1 (Γ.bindTypes (typeEnvAt C1.length ts es)).length Q' ms
      (fs.map (Eff.substAt C1.length ts es)) := by
    refine ⟨by simpa only [List.length_map] using hr.1, ?_,
      by simpa only [List.length_map] using hr.2.2.1,
      by simpa only [List.length_map] using hr.2.2.2.1, ?_⟩
    · intro e he
      exact (si.rows e he).wf.2.2.2.1
    · intro i hsrc
      have hb := hr.2.2.2.1 i hsrc
      have he := List.getElem?_eq_getElem hb
      have hnf := (hr.2.2.2.2 i hsrc).substAt C1.length ts es hq
      simpa only [List.getElem?_map, he, Option.map_some, Option.getD_some] using hnf
  have args := Tel.arguments_typeSubst (instantiatedTel ms.tel (ss ++ [τ]) fs) ws
    C1.length ts es
  have hnArgs := hsi.kinds.1
  rw [instantiatedTel_substAt hsi.source (ss ++ [τ]) fs (by omega) hrows, ha] at args
  simp only [List.map_append, List.map_cons, List.map_nil, Option.map_some] at si args
  have hann' := hann.substAt hf hi
  have hv : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (.dict cl (τ.substAt C1.length ts es)) := by
    simpa only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm] using ihv
  have out := HasTypeCQ.C_Meth (R := R.map (Ty.substAt C1.length ts es))
    (Δ := L.map (Option.map (fun b => match b with
      | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes)))
    hv hc hm hn (hs.substAt hf.2.2.1 hi) si rr args ihws hann'
  simp only [Comp.substTyAt, Val.substTyAtList_eq_map, Ty.substAt, Eff.substAt] at out ⊢
  exact out

theorem Eff.substAt_singleFail (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es (Eff.singleFail a) = Eff.singleFail (a.substAt c ts es) := by
  have hs : substAtoms (typeEnvAt c ts es).rows (fun _ => false) = fun _ => false := by
    funext x
    cases x <;> simp [substAtoms]
  have hr : rowFails (typeEnvAt c ts es).rows (fun _ => false) = [] := by
    simp [rowFails]
  simp only [Eff.singleFail, Eff.substAt, substRowAt, Eff.bind, Eff.rawBind,
    show (typeEnvAt c ts es).ranges = [] from rfl, instAtoms_nil, hs, hr,
    rawBindTys, List.append_nil, Eff.norm, Ty.normTys,
    Ty.substAt, substTypeAt, Ty.bind, Ty.norm_rawBind, Ty.norm_idem]
  rfl

private theorem raise_type_image (T E : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    (Ty.fn ["error"] [E] T (Eff.singleFail E)).substAt c ts es =
      .fn ["error"] [E.substAt c ts es] (T.substAt c ts es)
        (Eff.singleFail (E.substAt c ts es)) := by
  change Ty.fn ["error"] [E.substAt c ts es] (T.substAt c ts es)
    (Eff.substAt c ts es (Eff.singleFail E)) = _
  rw [Eff.substAt_singleFail]

theorem HasTypeVQ.type_subst_raise {P B} {Ψ : StoreTy} {Q' C0 C1 Γ Φ T E ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ["error"] [E] T (Eff.singleFail E)))
    (ht : Ordinary T) (he : Ordinary E) (hk : T.HasKind P (TypeCtx.kinds (C1 ++ C0)) .value) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.raise T E).substTyAt C1.length ts es)
      ((Ty.fn ["error"] [E] T (Eff.singleFail E)).substAt C1.length ts es) := by
  have ha' := ha.substAt hf hi
  rw [raise_type_image] at ha'
  rw [raise_type_image]
  exact .V_Raise ha'
    (Ty.ordinary_bind ht _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary))
    (Ty.ordinary_bind he _ (typeEnvAt_ordinary _ _ _ hi.typeKinds.ordinary))
    (hk.substAt hi.typeKinds hi.rowKinds)

theorem HasTypeCQ.type_subst_escape {P B} {Ψ : StoreTy}
    {Q' C0 C1 Γ Φ r v a e ts es} {L : LocalCtx}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (ha : Ty.Annotation P (C1 ++ C0) Γ a)
    (ih : HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      (v.substTyAt C1.length ts es) (r.substAt C1.length ts es)) :
    HasTypeCQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((some r).map (Ty.substAt C1.length ts es))
      ((Comp.escape v).substTyAt C1.length ts es)
      (a.substAt C1.length ts es) (Eff.substAt C1.length ts es e)
      (L.map (Option.map (fun b => match b with
        | .list a => .list (a.substAt C1.length ts es) | .string => .string | .bytes => .bytes))) :=
  .C_Escape ih (ha.substAt hf hi)

theorem HasTypeVQ.raise_annotation_kind {P B Ψ Q C Γ Φ v t e a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .raise t e) :
    Ty.Annotation P C Γ (.fn ["error"] [e] t (Eff.singleFail e)) ∧ Ordinary t ∧
      t.HasKind P (TypeCtx.kinds C) .value
 := by
  match h with
  | .V_Raise ha ho _ hk => cases hv; exact ⟨ha, ho, hk⟩
  | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact h.raise_annotation_kind hv
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. |
    .V_Fun .. | .V_Prim .. | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. |
    .V_PathBases .. | .V_ScopePattern .. | .V_Checked .. | .V_CheckedRequest .. |
    .V_CheckedAt .. | .V_AtError .. | .V_List .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. | .V_Super .. => cases hv
termination_by structural h

theorem HasTypeVQ.type_subst_lam {P B} {Ψ : StoreTy}
    {Q' C0 C1 Γ Φ ns ps body r ε ts es}
    (hf : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF)
    (hi : TypeSubstInput P B C0 C1 ts es)
    (hn : NamesWF ns ps)
    (ha : Ty.Annotation P (C1 ++ C0) Γ (.fn ns ps r ε))
    (ih : HasTypeCQ P B (hideBuilders Ψ) Q' C1
      (bindParams (hideConts (Γ.bindTypes (typeEnvAt C1.length ts es)))
        (ps.map (Ty.substAt C1.length ts es)))
      (liftMany (ps.map (Ty.substAt C1.length ts es)).length Φ)
      (some ((r.substAt C1.length ts es).shiftV
        (ps.map (Ty.substAt C1.length ts es)).length 0))
      (body.substTyAt C1.length (ts.map (Ty.shiftV ps.length 0))
        (es.map (Eff.shiftV ps.length 0)))
      ((r.substAt C1.length ts es).shiftV (ps.map (Ty.substAt C1.length ts es)).length 0)
      (Eff.shiftV (ps.map (Ty.substAt C1.length ts es)).length 0
        (Eff.substAt C1.length ts es ε)) []) :
    HasTypeVQ P B Ψ Q' C1 (Γ.bindTypes (typeEnvAt C1.length ts es)) Φ
      ((Val.lam ns ps body).substTyAt C1.length ts es)
      ((Ty.fn ns ps r ε).substAt C1.length ts es)
 := by
  have ha' := ha.substAt hf hi
  simp only [Val.substTyAt, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    rawBindTys_eq_map, Ty.normTys_eq_map, List.map_map] at ha' ih ⊢
  apply HasTypeVQ.V_Lam
  · simpa only [NamesWF, List.length_map] using hn
  · exact ha'.wf
  · exact ha'.sorted
  · exact ih
  · exact ha'.declared

theorem Eff.substAt_empty (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c ts es Eff.empty = Eff.empty := by
  have hs : substAtoms (typeEnvAt c ts es).rows (fun _ => false) = fun _ => false := by
    funext x
    cases x <;> simp [substAtoms]
  have hr : rowFails (typeEnvAt c ts es).rows (fun _ => false) = [] := by
    simp [rowFails]
  simp only [Eff.substAt, substRowAt, Eff.bind, Eff.rawBind, Eff.empty,
    show (typeEnvAt c ts es).ranges = [] from rfl, instAtoms_nil, hs, hr,
    rawBindTys, List.append_nil, Eff.norm, Ty.normTys]
  rfl

theorem Ty.substAt_fn (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    (Ty.fn ns ps r e).substAt c ts es = .fn ns (ps.map (Ty.substAt c ts es))
      (r.substAt c ts es) (Eff.substAt c ts es e) := by
  simp only [Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm,
    rawBindTys_eq_map, Ty.normTys_eq_map, List.map_map]
  rfl

theorem SatAll.weaken_closed {P B C1 ts ps} (hf : B.CoreAssumptions P)
    (extra : TypeCtx) (ht : ∀ t ∈ ts, t.WF 0 0 0)
    (ha : TypeAnnotations P [] [] ts) (h : SatAll B C1 ts ps) :
    SatAll B (extra ++ C1) ts ps := by
  refine ⟨h.1, ?_⟩
  intro i t p hi hp
  have hm := List.mem_of_getElem? hi
  have hn : Ty.Annotation P C1 [] t.norm := (ha t hm).closed_context.norm
  have he : t.norm.shift extra.length 0 = t.norm := by
    simp only [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes,
      Ty.shiftTypes_of_wf_zero (Ty.wf_norm (ht t hm)), Ty.norm_idem]
  have hb : Ty.Annotation P (extra ++ C1) [] (t.norm.shift extra.length 0) := by
    rw [he]
    exact (ha t hm).closed_context.norm
  have hs := hf.toTypeAssumptions.sat_shiftTypes extra hn hb
    (by simpa using h.2 i t p hi hp)
  rwa [he] at hs

theorem TypeSubstInput.under {P B C0 C1 ts es}
    (h : TypeSubstInput P B C0 C1 ts es) (hf : B.CoreAssumptions P) (extra : TypeCtx) :
    TypeSubstInput P B C0 (extra ++ C1) ts es :=
  {h with constraints := h.constraints.weaken_closed hf extra h.typeWF h.typeAnnotations}

theorem fail_input {P B Ψ Q Φ T E a} (hf : B.CoreAssumptions P)
    (h : HasTypeVQ P B Ψ Q [] [] Φ (.raise T E) a) :
    ClosedTypeSubstInput P B [TypeCtx.valueParam] [] [] [T] [] := by
  obtain ⟨ha, ho, hk⟩ := h.raise_annotation_kind rfl
  have hT : Ty.Annotation P [] [] T := ⟨ha.wf.2.2.1, ha.sorted.2.1, ha.declared.2.1⟩
  refine ⟨⟨rfl, ?_, ⟨rfl, ?_⟩, ?_, ⟨rfl, ?_⟩,
    by simp, by simp [RowAnnotations], by simp⟩, ?_⟩
  · intro b hb; simpa using (List.mem_singleton.mp hb ▸ hT.wf)
  · rintro (_ | i) b k hb hl
    · cases Option.some.inj hb
      cases Option.some.inj hl
      exact ⟨hk, fun _ => ho⟩
    · simp at hb
  · intro b hb; simpa using (List.mem_singleton.mp hb ▸ hT)
  · rintro (_ | i) b q hb hq
    · cases Option.some.inj hb
      cases Option.some.inj hq
      exact hf.sat_unconstrained T hT.wf
    · simp at hb
  · exact ⟨by intro i b hb; simp at hb, by intro i b hb; simp at hb⟩

theorem clause_prim_rowfree {P B e sg b s} (hc : B.CoreAssumptions P)
    (h : ClauseSig P B e (.prim b) sg) (hs : B.sig b = some s) :
    s.tel.RowsIn (· < 0) := by
  obtain ⟨S, _, hl, hr⟩ := h
  have hrows := hr b s rfl hs
  simp only [opSigAt, hs] at hl
  obtain ⟨l, hle, _⟩ := Option.map_eq_some_iff.mp hl
  have hz : s.neffs = 0 := by
    rcases hc.opEff_io b s l hs hle with hk | hk | hk
    · obtain ⟨_, _, _, h0, _⟩ := hc.io_op b s hs (Or.inl hk); exact h0
    · obtain ⟨_, _, _, h0, _⟩ := hc.io_op b s hs (Or.inr hk); exact h0
    · exact (hc.pathBases_shape b s hs hk).rows
  simpa only [hz] using hrows

end
end Benitoite.Release.Refinement
