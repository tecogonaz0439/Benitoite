import Benitoite.Release.Refinement.TypeSubstCodeNormal
import Benitoite.Release.Refinement.TypeSubstCalls

/-! # 局所署名と外側の型・行の置換（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
set_option maxHeartbeats 2000000

private theorem substAtoms_rowfree (es : List Eff) (a : Atom → Bool)
    (h : ∀ i, a (.rho i) = false) : substAtoms es a = a := by
  funext x
  cases x <;> simp [substAtoms, h]

private theorem rowFails_rowfree (es : List Eff) (a : Atom → Bool)
    (h : ∀ i, a (.rho i) = false) : rowFails es a = [] := by
  simp [rowFails, h]

mutual
  theorem Ty.rawBind_rows_rowfree (a : Ty) (hr : a.RowsIn (· < 0))
      (θ : SubstEnv) (rs ss : List Eff) :
      a.rawBind {θ with rows := rs} = a.rawBind {θ with rows := ss} := by
    cases a <;> simp only [Ty.RowsIn] at hr <;> simp only [Ty.rawBind]
    all_goals try rfl
    case data _ _ => rw [Ty.rawBindTys_rows_rowfree _ hr θ rs ss]
    case external _ _ => rw [Ty.rawBindTys_rows_rowfree _ hr θ rs ss]
    case tapp _ _ => rw [Ty.rawBindTys_rows_rowfree _ hr θ rs ss]
    case fn _ _ _ _ => rw [Ty.rawBindTys_rows_rowfree _ hr.1 θ rs ss,
      Ty.rawBind_rows_rowfree _ hr.2.1 θ rs ss,Eff.rawBind_rows_rowfree _ hr.2.2 θ rs ss]
    case cont _ _ _ => rw [Ty.rawBind_rows_rowfree _ hr.1 θ rs ss,
      Ty.rawBind_rows_rowfree _ hr.2.1 θ rs ss,Eff.rawBind_rows_rowfree _ hr.2.2 θ rs ss]
    case map _ _ => rw [Ty.rawBind_rows_rowfree _ hr.1 θ rs ss,Ty.rawBind_rows_rowfree _ hr.2 θ rs ss]
    case dependentFn _ => rw [Tel.rawBind_rows_rowfree _ hr θ rs ss]
    all_goals rw [Ty.rawBind_rows_rowfree _ hr θ rs ss]
  theorem Ty.rawBindTys_rows_rowfree (as : List Ty) (hr : Ty.RowsInList (· < 0) as)
      (θ : SubstEnv) (rs ss : List Eff) :
      rawBindTys {θ with rows := rs} as = rawBindTys {θ with rows := ss} as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys,Ty.rawBind_rows_rowfree _ hr.1 θ rs ss,
        Ty.rawBindTys_rows_rowfree _ hr.2 θ rs ss]
  theorem Eff.rawBind_rows_rowfree (e : Eff) (hr : e.RowsIn (· < 0))
      (θ : SubstEnv) (rs ss : List Eff) :
      Eff.rawBind {θ with rows := rs} e = Eff.rawBind {θ with rows := ss} e := by
    cases e with
    | mk ats fs =>
      have hz : ∀ i, ats (.rho i) = false := by
        intro i
        cases he : ats (.rho i) <;> simp_all [Eff.RowsIn]
      have hz' : ∀ i, (instAtoms θ.ranges ats) (.rho i) = false := by
        intro i
        simpa only [instAtoms] using hz i
      simp only [Eff.rawBind,substAtoms_rowfree _ _ hz',rowFails_rowfree _ _ hz,
        List.append_nil,Ty.rawBindTys_rows_rowfree _ hr.2 θ rs ss]
  theorem Tel.rawBind_rows_rowfree (t : Tel) (hr : t.RowsIn (· < 0))
      (θ : SubstEnv) (rs ss : List Eff) :
      Tel.rawBind {θ with rows := rs} t = Tel.rawBind {θ with rows := ss} t := by
    cases t with
    | done r e => simp only [Tel.rawBind,Ty.rawBind_rows_rowfree _ hr.1 θ rs ss,
        Eff.rawBind_rows_rowfree _ hr.2 θ rs ss]
    | param n a t =>
      simp only [Tel.rawBind,Ty.rawBind_rows_rowfree _ hr.1 θ rs ss]
      exact congrArg (Tel.param n (a.rawBind {θ with rows := ss}))
        (Tel.rawBind_rows_rowfree t hr.2 θ.up (rs.map (Eff.shiftV 1 0)) (ss.map (Eff.shiftV 1 0)))
end

theorem Ty.substAt_local_rowfree {nr nv k c : Nat} (ts : List Ty) (es : List Eff)
    (a : Ty) (hw : a.WF nr k nv) (hr : a.RowsIn (· < 0)) (hk : k ≤ c) :
    a.substAt c ts es = a.norm := by
  change (a.rawBind (typeEnvAt c ts es)).norm = a.norm
  have he : a.rawBind (typeEnvAt c ts es) = a.rawBind (typeEnvAt c ts []) :=
    Ty.rawBind_rows_rowfree a hr (typeEnvAt c ts []) _ []
  rw [he]
  have ha : SubstEnv.AgreesBelow k (typeEnvAt c ts []) (renEnv id) := by
    refine ⟨?_,rfl,rfl,rfl⟩
    intro i hi
    have hic : i < c := by omega
    simp only [typeEnvAt,hic,↓reduceIte,renEnv,id_eq]
  rw [Ty.rawBind_agrees hw ha,Ty.rawBind_id]

theorem signatureTel.rows {ns ps r e pe} (hn : NamesWF ns ps)
    (hr : (signatureTel ns ps r e).RowsIn pe) :
    Ty.RowsInList pe ps ∧ r.RowsIn pe ∧ e.RowsIn pe := by
  cases ns <;> cases ps <;> simp only [NamesWF,List.length_cons,List.length_nil] at hn
  · exact ⟨trivial,hr⟩
  · omega
  · omega
  · simp only [signatureTel,Tel.RowsIn] at hr
    have hh := signatureTel.rows ⟨by omega,hn.2.of_cons⟩ hr.2
    exact ⟨⟨hr.1,hh.1⟩,hh.2⟩

theorem ClauseSig.localRows {P B e o sg} (hp : P.WellFormed) (hb : B.CoreAssumptions P)
    (h : ClauseSig P B e o sg) (hn : NamesWF sg.names sg.params) :
    Ty.RowsInList (· < 0) sg.params ∧ sg.ret.RowsIn (· < 0) := by
  obtain ⟨S,hi,hl,hs⟩ := h
  cases o with
  | fail => cases hl
  | user o =>
    simp only [opSigAt] at hl
    obtain ⟨d,hd,rfl⟩ := Option.map_eq_some_iff.mp hl
    have hr := (hp.ops o d hd).2.2.2.2.1
    have hh := signatureTel.rows hn hr
    exact ⟨hh.1,hh.2.1⟩
  | prim b =>
    cases hsig : B.sig b with
    | none => simp [opSigAt,hsig] at hl
    | some s =>
      have hr := clause_prim_rowfree hb ⟨S,hi,hl,hs⟩ hsig
      simp only [opSigAt,hsig] at hl
      obtain ⟨l,hop,rfl⟩ := Option.map_eq_some_iff.mp hl
      have hn' : NamesWF s.names s.params := by simpa only [List.length_map,NamesWF] using hn
      have hh := signatureTel.rows hn' hr
      constructor
      · rw [Ty.RowsInList.iff] at hh ⊢
        intro a ha
        obtain ⟨x,hx,rfl⟩ := List.mem_map.mp ha
        have hrow := hh.1 x hx
        cases x <;> try exact hrow
        all_goals rename_i ix; cases ix <;> trivial
      · exact hh.2.1

theorem BinderTypes.LocalWF.substAt_local {nt n c ts es ps}
    (hw : BinderTypes.LocalWF nt n ps) (hr : Ty.RowsInList (· < 0) ps) (hc : nt ≤ c) :
    ps.map (Ty.substAt c ts es) = ps.map Ty.norm := by
  induction ps generalizing n with
  | nil => rfl
  | cons a ps ih =>
    simp only [List.map_cons,Ty.substAt_local_rowfree ts es a hw.1 hr.1 hc,
      ih hw.2 hr.2]

theorem OpSig.substAt_local {sg : OpSig} {c ts es} (hw : sg.WF)
    (hr : Ty.RowsInList (· < 0) sg.params ∧ sg.ret.RowsIn (· < 0)) (hc : sg.tparams.length ≤ c) :
    sg.substAt c ts es = {sg with params := sg.params.map Ty.norm, ret := sg.ret.norm} := by
  simp only [OpSig.substAt,BinderTypes.LocalWF.substAt_local hw.1 hr.1 hc,
    Ty.substAt_local_rowfree ts es sg.ret hw.2 hr.2 hc]

theorem Ty.cont_of_norm_wf {a b t : Ty} {e : Eff} {nr nt nv : Nat}
    (hw : a.WF nr nt nv) (he : a.norm = .cont b t e) :
    ∃ b' t' e', a = .cont b' t' e' := by
  cases a <;> simp only [Ty.norm] at he <;> try cases he
  case cont => exact ⟨_,_,_,rfl⟩
  case refined a p =>
    have hn := (Ty.notContCore_norm (Ty.refined a p)).mpr (by
      simpa only [Ty.NotContCore,Ty.core] using hw.2.2)
    simp only [Ty.norm] at hn
    rw [he] at hn
    exact False.elim (hn _ _ _ rfl)
  case dependentFn t =>
    unfold Ty.foldFn at he
    split at he <;> cases he

theorem Ctx.NormEq.extend {Γ Δ : Ctx} {a b : Ty} (h : Γ.NormEq Δ) (he : a.norm = b.norm) :
    (Γ.extend a).NormEq (Δ.extend b) := by
  simp only [Ctx.NormEq,Ctx.extend,List.map_cons,Option.map_some,Ty.norm_shiftV,he]
  exact congrArg (List.cons _) (h.shiftV 1 0)

private theorem Ty.cont_of_shiftV {a x y : Ty} {e : Eff} {n c : Nat}
    (h : a.shiftV n c = .cont x y e) : ∃ (x' y' : Ty) (e' : Eff), a = .cont x' y' e' := by
  cases a <;> simp only [Ty.shiftV] at h <;> try cases h
  exact ⟨_,_,_,rfl⟩

theorem Ctx.continuations_extend {Γ Δ : Ctx} {a b : Ty}
    (hc : ∀ (i : Nat) (x y : Ty) (e : Eff), Γ[i]? = some (some (.cont x y e)) →
      ∃ (x' y' : Ty) (e' : Eff), Δ[i]? = some (some (.cont x' y' e')))
    (ha : ∀ x y e, a = .cont x y e → ∃ (x' y' : Ty) (e' : Eff), b = .cont x' y' e') :
    ∀ (i : Nat) (x y : Ty) (e : Eff), (Γ.extend a)[i]? = some (some (.cont x y e)) →
      ∃ (x' y' : Ty) (e' : Eff), (Δ.extend b)[i]? = some (some (.cont x' y' e')) := by
  intro i x y e hi
  cases i with
  | zero =>
    simp only [Ctx.extend,List.getElem?_cons_zero,Option.some.injEq] at hi
    obtain ⟨x',y',e',he⟩ := Ty.cont_of_shiftV hi
    obtain ⟨x'',y'',e'',hb⟩ := ha x' y' e' he
    exact ⟨x''.shiftV 1 0,y''.shiftV 1 0,Eff.shiftV 1 0 e'',by simp [Ctx.extend,hb,Ty.shiftV]⟩
  | succ i =>
    simp only [Ctx.extend,List.getElem?_cons_succ,List.getElem?_map] at hi ⊢
    obtain ⟨u,hu,he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some u =>
      simp only [Option.map_some,Option.some.injEq] at he
      obtain ⟨x',y',e',rfl⟩ := Ty.cont_of_shiftV he
      obtain ⟨x'',y'',e'',hb⟩ := hc i x' y' e' hu
      exact ⟨x''.shiftV 1 0,y''.shiftV 1 0,Eff.shiftV 1 0 e'',by simp [hb,Ty.shiftV]⟩

theorem Ctx.NormEq.extendMany_local {Γ Δ : Ctx} {ps : List Ty} {nt n}
    (h : Γ.NormEq Δ) (hw : BinderTypes.LocalWF nt n ps) :
    (Γ.extendMany (ps.map Ty.norm)).NormEq (Δ.extendMany ps) := by
  induction ps generalizing Γ Δ n with
  | nil => exact h
  | cons a ps ih => exact ih (h.extend (Ty.norm_idem a)) hw.2

theorem Ctx.continuations_extendMany_local {Γ Δ : Ctx} {ps : List Ty} {nt n}
    (hc : ∀ (i : Nat) (x y : Ty) (e : Eff), Γ[i]? = some (some (.cont x y e)) →
      ∃ (x' y' : Ty) (e' : Eff), Δ[i]? = some (some (.cont x' y' e')))
    (hw : BinderTypes.LocalWF nt n ps) :
    ∀ (i : Nat) (x y : Ty) (e : Eff), (Γ.extendMany (ps.map Ty.norm))[i]? = some (some (.cont x y e)) →
      ∃ (x' y' : Ty) (e' : Eff), (Δ.extendMany ps)[i]? = some (some (.cont x' y' e')) := by
  induction ps generalizing Γ Δ n with
  | nil => exact hc
  | cons a ps ih =>
    exact ih (Ctx.continuations_extend hc (fun x y e he => Ty.cont_of_norm_wf hw.1 he)) hw.2

theorem OpSig.context_normEq (sg : OpSig) (hw : sg.WF) (Γ : Ctx) (t : Ty) (e : Eff) :
    Ctx.NormEq ({sg with params := sg.params.map Ty.norm, ret := sg.ret.norm}.context Γ t e)
      (sg.context Γ t e) := by
  apply Ctx.NormEq.extend
    (Ctx.NormEq.extendMany_local (Ctx.NormEq.refl (Γ.shiftE sg.tparams.length)) hw.1)
  simp only [OpSig.continuation,List.length_map,Ty.norm,Ty.norm_idem]

theorem OpSig.context_continuations (sg : OpSig) (hw : sg.WF) (Γ : Ctx) (t : Ty) (e : Eff) :
    ∀ (i : Nat) (b u : Ty) (f : Eff),
      ({sg with params := sg.params.map Ty.norm, ret := sg.ret.norm}.context Γ t e)[i]? =
        some (some (.cont b u f)) →
      ∃ (b' u' : Ty) (f' : Eff), (sg.context Γ t e)[i]? = some (some (.cont b' u' f')) := by
  apply Ctx.continuations_extend
    (Ctx.continuations_extendMany_local (fun i b t e hi => ⟨b,t,e,hi⟩) hw.1)
  intro x y f _
  exact ⟨sg.ret,_,_,rfl⟩

theorem OpSig.typeSubst_body {P B C0 C1 ts es Ψ Q C Γ Φ c f}
    {R : Option Ty} {m : Comp} {a : Ty} {L : LocalCtx}
    (hi : TypeSubstInput P B C0 C1 ts es) (sg : OpSig) (hw : sg.WF)
    (hr : Ty.RowsInList (· < 0) sg.params ∧ sg.ret.RowsIn (· < 0))
    (ha : Builtins.SubstitutionAssumptions P B) (hs : Ψ.WF) (t : Ty) (e : Eff)
    (ht : HasTypeCQ P B Ψ Q C
      ((sg.context Γ t e).bindTypes (typeEnvAt (c+sg.tparams.length) ts es)) Φ
      (R.map (Ty.substAt (c+sg.tparams.length) ts es))
      (m.substTyAt (c+sg.tparams.length) ts es) (a.substAt (c+sg.tparams.length) ts es)
      (Eff.substAt (c+sg.tparams.length) ts es f)
      (L.map (Option.map (BuilderKind.substAt (c+sg.tparams.length) ts es)))) :
    HasTypeCQ P B Ψ Q C
      (sg.context (Γ.bindTypes (typeEnvAt c ts es)) (t.substAt c ts es) (Eff.substAt c ts es e)) Φ
      (R.map (Ty.substAt (c+sg.tparams.length) ts es))
      (m.substTyAt (c+sg.tparams.length) ts es) (a.substAt (c+sg.tparams.length) ts es)
      (Eff.substAt (c+sg.tparams.length) ts es f)
      (L.map (Option.map (BuilderKind.substAt (c+sg.tparams.length) ts es))) := by
  rw [OpSig.context_typeSubst hi,OpSig.substAt_local hw hr (by omega)] at ht
  exact (sg.context_normEq hw _ _ _).typeSubst_comp
    (sg.context_continuations hw _ _ _) ha hs ht

theorem ClauseSig.substAt {P B e o sg} (h : ClauseSig P B e o sg)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    ClauseSig P B (Eff.substAt c ts es e) o sg := by
  obtain ⟨S,hi,hl,hr⟩ := h
  refine ⟨S,?_,hl,hr⟩
  rcases hi with htop | ⟨b,s,l,ho,hs,hop,he⟩
  · exact Or.inl htop
  · apply Or.inr
    refine ⟨b,s,l,ho,hs,hop,?_⟩
    have hat : (Eff.substAt c ts es e).atoms = e.atoms := by
      cases e with
      | mk ats fs =>
        have hz : ∀ i, ats (.rho i) = false := by
          intro i
          cases ha : ats (.rho i) <;> try rfl
          exact False.elim (he.1 i ha)
        simp only [Eff.substAt,substRowAt,Eff.bind,Eff.rawBind,Eff.norm,Eff.atoms,
          typeEnvAt,instAtoms_nil,substAtoms_rowfree _ _ hz]
    simpa only [Eff.ClauseRangeIs,Eff.mem,Eff.test,hat] using he

end Benitoite.Release.Refinement
