import Benitoite.Release.Refinement.AtStateLeaves

/-! # 固定した σ の発行 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem path_annotation (P : Program) (Γ : Ctx) :
    Ty.Annotation P [] Γ (.dependentFn (.done .pathBases (Eff.single processEnvironmentEff))) :=
  ⟨⟨trivial,trivial,by simp [Eff.Canonical,Eff.norm,Eff.single]⟩,⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem path_arguments {P B Ψ b s r e}
    (hB : B.CoreAssumptions P) (hs : B.sig b = some s) (hk : s.kind = .pathBases)
    (h : BuiltinArgs P B Ψ b s [] [] [] [] r e) :
    r = .pathBases ∧ e = Eff.single processEnvironmentEff := by
  have sh := hB.pathBases_shape b s hs hk
  have hn : s.names = [] := by
    have he := (hB.sig_scoped b s hs).names.1
    rw [sh.arguments] at he
    exact List.eq_nil_of_length_eq_zero he
  have ht : instantiatedTel (Tel.instR [] s.tel) [] [] = .done .pathBases (Eff.single processEnvironmentEff) := by
    simp [instantiatedTel,PrimSig.tel,hn,sh.arguments,sh.result,sh.effect,signatureTel,
      Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,Eff.rawMapRanges,
      Tel.bind,Tel.rawBind,Ty.rawBind,Tel.norm,Ty.norm,Eff.rawBind,Eff.norm,Eff.single,Ty.normTys,
      instAtoms_nil,substAtoms_nil,rowFails,typeEnvAt,mapRangeAtoms_rangeAt]
  have ha := h.arguments
  rw [ht] at ha
  cases ha
  exact ⟨rfl,rfl⟩

theorem StateTyE.path_bases_apply_all {P B σ Eb q b s k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .app (.prim b [] [] []) [])
    (hsig : B.sig b = some s) (hkind : s.kind = .pathBases) (hnh : NoHandler k (.prim b)) :
    Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ) ∧
    StateTyE P B σ Eb (.run (.mk q.capture (.issuePathBases b)) k μ) := by
  refine ⟨.E_PathBasesApply hv hsig hkind hnh,?_⟩
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,he,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨r,ef,ha,hle,hcov⟩ := hq.primitive_view_inputs hP hPB hB hs.wf hs.sorted hs.declared hcl hv hsig
  obtain ⟨rfl,rfl⟩ := path_arguments hB hsig hkind ha
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,hqeq,hcap,hbody,hl,hR,hat,het,hrs⟩ := hq.open_zero
  have hb := hB.issuePathBases_typed (Ψ := Ψ) (Q := Qempty) (C := []) (Γ := Γ) (Φ := Φ) (R := Rs) (Δ := []) hsig hkind
  have hq' := ClosureTy.capture hcap hb (path_annotation P Γ) hR hrs
  have hbase : cap.closeTy .pathBases = .pathBases := rfl
  have hrow : cap.closeEff (Eff.single processEnvironmentEff) = Eff.single processEnvironmentEff := Eff.subst_values_single _ _
  rw [hbase,hrow] at hq'
  have hcapEq : q.capture = cap := by rw [hqeq]; rfl
  rw [←hcapEq] at hq'
  obtain ⟨hq'',hsub⟩ := hq'.widen_atoms (he.covers.trans hcov)
  refine ⟨Ψ,R,.pathBases,c,e,_,hs,hq'',hsub,.K_Sub hk hle,?_,?_,hkc,hμ⟩
  · have hc : q.capture.Adequate σ := by cases q; exact had.1
    exact ⟨hc,trivial⟩
  · have hc : q.capture.Closed := by cases q; exact hcl.1
    exact ⟨hc,trivial⟩

private theorem issue_source {P B Ψ Q C Γ Φ Rs m a e L cap R b}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = []) (hm : m = .issuePathBases b) :
    Ty.LeQ P [] [] .pathBases (cap.closeTy a) := by
  match h with
  | .C_IssuePathBases _ _ _ _ _ _ _ _ => subst Q C; cases hm; exact .refl
  | .C_Sub hb hl _ _ _ _ =>
    have hh := issue_source hb hc hQ hC hm
    subst Q C
    exact .trans hh (hl.bind (valEnv cap.env) hc.transport)
  | .C_Normal hb =>
    simpa only [Capture.closeTy,substTyValues_norm_source] using issue_source hb hc hQ hC hm
  | .C_Eff hb _ => exact issue_source hb hc hQ hC hm
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_App .. | .C_DependentApp .. | .C_CheckAt .. | .C_External .. => cases hm
termination_by structural h

theorem ClosureTy.issue_path_bases_input {P B Ψ R q a e b}
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .issuePathBases b) :
    Ty.LeQ P [] [] .pathBases a := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,hl,hr,rfl,rfl,hrs⟩ := hq.open_zero
  cases m
  case issuePathBases b0 => cases hv; exact issue_source hb hc rfl rfl rfl
  case checkAt k o sh bs p v ix =>
    cases bs <;> (simp only [Comp.resolveLocals,Closure.view] at hv; injection hv)
  all_goals (simp only [Comp.resolveLocals,Closure.view] at hv; injection hv)

theorem StateTyE.issue_path_bases_all {P B σ Eb q b s k μ}
    (h : StateTyE P B σ Eb (.run q k μ)) (hv : q.view = .issuePathBases b)
    (hsig : B.sig b = some s) (hkind : s.kind = .pathBases)
    (hop : s.opEff = some processEnvironmentEff) (hσ : σ.Valid) :
    Step P B σ (.run q k μ) (some (.pathBases b σ)) (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.pathBases σ))) k μ) := by
  refine ⟨.E_IssuePathBases hv hsig hkind hop hσ,?_⟩
  obtain ⟨Ψ,R,a,c,e,e1,hs,hq,_,hk,_,_,hkc,hμ⟩ := h
  have ha : Ty.Annotation P [] [] .pathBases := ⟨trivial,trivial,trivial⟩
  exact reply_value_state hs hk ha rfl (hq.issue_path_bases_input hv) (.V_PathBases hσ) trivial rfl hkc hμ

end
end Benitoite.Release.Refinement
