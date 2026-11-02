import Benitoite.Release.Refinement.AtStateInputs

/-! # At の応答を同じストアと継続へ戻す葉 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem result_kinds {P shape name kind index} (hs : ResultShape.Declared P shape) :
    TypeArgsKinded P [] [.scoped name kind index,shape.errorType] [.value,.value] := by
  refine ⟨rfl,?_⟩
  intro i a k ha hk
  cases i with
  | zero => cases ha; cases hk; exact ⟨trivial,by intro _ b t e he; cases he⟩
  | succ i =>
    cases i with
    | zero =>
      cases ha; cases hk
      rw [hs.errorType_eq]
      exact ⟨⟨TyCon.arity_data hs.standard.2.1,trivial⟩,by intro _ b t e he; cases he⟩
    | succ i => simp at ha

private theorem result_ok {P B Ψ shape name kind index v}
    (hs : ResultShape.Declared P shape)
    (ha : Ty.Annotation P [] [] (.data shape.owner [.scoped name kind index,shape.errorType]))
    (hv : HasTypeV P B Ψ [] [] [] v (.scoped name kind index)) :
    HasTypeV P B Ψ [] [] [] (.con shape.ok [.scoped name kind index,shape.errorType] [v])
      (.data shape.owner [.scoped name kind index,shape.errorType]) := by
  obtain ⟨cd,hcd,hd,hn,hargs⟩ := hs.okDecl
  have ht : HasTypeVsQ P B Ψ Qempty [] [] [] [v]
      (cd.args.map (Ty.subst [.scoped name kind index,shape.errorType] [])) := by
    simpa [hargs,Ty.subst,Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,Ty.norm] using
      HasTypeVsQ.cons hv HasTypeVsQ.nil
  have hc := HasTypeVQ.V_Con hcd (by simp [hn]) (by simpa only [hn,List.replicate_succ,List.replicate_zero] using result_kinds hs)
    (by intro a ha; simp only [hargs,List.mem_singleton] at ha; subst a; simp [hn,Ty.WF]) ht (hd.symm ▸ ha)
  simpa only [hd] using hc

private theorem result_error {P B Ψ shape name kind index detail}
    (hs : ResultShape.Declared P shape)
    (ha : Ty.Annotation P [] [] (.data shape.owner [.scoped name kind index,shape.errorType])) :
    HasTypeV P B Ψ [] [] [] (.con shape.error [.scoped name kind index,shape.errorType] [.atError detail])
      (.data shape.owner [.scoped name kind index,shape.errorType]) := by
  obtain ⟨cd,hcd,hd,hn,hargs⟩ := hs.errorDecl
  have herror : shape.errorType.norm = shape.errorType := by rw [hs.errorType_eq]; rfl
  have ht : HasTypeVsQ P B Ψ Qempty [] [] [] [.atError detail]
      (cd.args.map (Ty.subst [.scoped name kind index,shape.errorType] [])) := by
    simpa [hargs,Ty.subst,Ty.substAt,substTypeAt,typeEnvAt,Ty.bind,Ty.rawBind,herror] using
      (HasTypeVsQ.cons (HasTypeVQ.V_AtError hs (detail := detail)) HasTypeVsQ.nil :
        HasTypeVsQ P B Ψ Qempty [] [] [] [.atError detail] [shape.errorType])
  have hc := HasTypeVQ.V_Con hcd (by simp [hn]) (by simpa only [hn,List.replicate_succ,List.replicate_zero] using result_kinds hs)
    (by intro a ha; simp only [hargs,List.mem_singleton] at ha; subst a; simp [hn,Ty.WF]) ht (hd.symm ▸ ha)
  simpa only [hd] using hc

private theorem shape_of_at {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    shape.Declared P ∧ B.valKind name = some kind := by
  cases h with | mk hs hk _ _ _ _ _ _ => exact ⟨hs,hk⟩

theorem StateTyE.at_ok_all {P B σ Eb q kind name shape bases pattern input index snapshot pat target bound t k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hp : AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound)
    (hcurrent : ∀ ρ, snapshot = some ρ → ρ = σ)
    (hat : checkAt snapshot kind pat target bound = .ok t) :
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal q.capture input))]))) k μ) := by
  refine ⟨.E_AtOk hv hp hcurrent hat,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,hk,had,hcl,hkc,hμ⟩ := h
  obtain ⟨Γ,Φ,hcap,hsrc,hle⟩ := hq.at_inputs hv
  obtain ⟨herror,himage,hann,hn⟩ := hsrc.result_image (cap := q.capture)
  rw [himage] at hle
  have hix := hp.fixed_index
  rw [hix] at hann hn hle
  obtain ⟨hshape,hkind⟩ := shape_of_at hsrc
  have hsnap : ∀ ρ, snapshot = some ρ → ρ.Valid := fun ρ hρ => hcurrent ρ hρ ▸ hσ
  have hmem := (checkAt.sound hsnap hat).2
  obtain ⟨inputTy,hty,hi⟩ := hsrc.closed_input hP hPB hB hs.wf hs.sorted hs.declared hcap
  have hwitness : CheckedWitness P B Ψ name kind bound snapshot t (AtRequest B name (closeVal q.capture input)) := by
    rcases hty with ⟨rfl,hnone⟩ | ⟨hcontent,hwf,hrows⟩
    · simp only [AtRequest,hnone]
      exact .plain hkind hnone hmem.kind hmem
    · exact .of_prepared_request hkind hcontent hi hp hsnap hat
  have ht := result_ok hshape hann (HasTypeVQ.V_CheckedAt hwitness)
  have haInput : (closeVal q.capture input).Adequate σ := by
    have hadc : q.capture.Adequate σ ∧ q.code.Adequate σ := by cases q; exact had
    have hm := hadc.2
    rw [hv] at hm
    cases bases <;> exact closeVal_adequate hadc.1 hm.2.2
  have hreq : match AtRequest B name (closeVal q.capture input) with | none => True | some v => v.Adequate σ := by
    unfold AtRequest; cases B.valContent name
    · trivial
    · exact haInput
  have hreqg : match AtRequest B name (closeVal q.capture input) with | none => True | some v => v.Ground := by
    cases hc : B.valContent name with
    | none => simp [AtRequest,hc]
    | some T => simpa only [AtRequest,hc] using groundVal_ground (hp.request hc).1
  have hsa : SnapshotAdequate σ snapshot bound := by
    cases snapshot with
    | some ρ => exact hcurrent ρ rfl
    | none => cases bound <;> first | exact ⟨_,rfl⟩ | cases hmem
  rw [herror]
  apply reply_value_state hs hk hann hn hle ht
  · change (∀ x∈[Ty.scoped name kind (.fixed bound),shape.errorType], x.WF 0 0 0) ∧ _
    refine ⟨Ty.wfList_iff.mp hann.wf,?_,trivial⟩
    cases hr : AtRequest B name (closeVal q.capture input) with
    | none => simp only [Val.ClosedAt]
    | some v => simpa only [hr,Val.ClosedAt,Val.Ground] using hreqg
  · cases hr : AtRequest B name (closeVal q.capture input) <;>
      simpa only [Val.Adequate,adequateVals,hr] using (show (SnapshotAdequate σ snapshot bound ∧ _) ∧ True from ⟨⟨hsa,hreq⟩,trivial⟩)
  · exact hkc
  · exact hμ

theorem StateTyE.at_error_all {P B σ Eb q kind name shape bases pattern input index snapshot pat target bound detail k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hp : AtPrepared B q.capture kind name bases pattern input index snapshot pat target bound)
    (hcurrent : ∀ ρ, snapshot = some ρ → ρ = σ)
    (hat : checkAt snapshot kind pat target bound = .error detail) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ) := by
  refine ⟨.E_AtError hv hp hcurrent hat,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,hk,_,_,hkc,hμ⟩ := h
  obtain ⟨Γ,Φ,hcap,hsrc,hle⟩ := hq.at_inputs hv
  obtain ⟨herror,himage,hann,hn⟩ := hsrc.result_image (cap := q.capture)
  rw [himage] at hle
  rw [hp.fixed_index] at hann hn hle
  obtain ⟨hshape,_⟩ := shape_of_at hsrc
  have ht := result_error (B := B) (Ψ := Ψ) (detail := detail) hshape hann
  rw [herror]
  apply reply_value_state hs hk hann hn hle ht
  · exact ⟨Ty.wfList_iff.mp hann.wf,trivial,trivial⟩
  · exact ⟨trivial,trivial⟩
  · exact hkc
  · exact hμ

theorem StateTyE.at_prepare_error_all {P B σ Eb q kind name shape bases pattern input index detail k μ}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (hat : AtPrepare B q.capture kind name bases pattern input index = .error detail) :
    Step P B σ (.run q k μ) none (.run (Closure.pure (.ret (.con shape.error [.scoped name kind index,q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret (.con shape.error [.scoped name kind index,q.capture.closeTy shape.errorType]
        [.atError detail]))) k μ) := by
  refine ⟨.E_AtPrepareError hv hat,?_⟩
  obtain ⟨Ψ,R,a,b,e,e1,hs,hq,_,hk,_,_,hkc,hμ⟩ := h
  obtain ⟨Γ,Φ,hcap,hsrc,hle⟩ := hq.at_inputs hv
  obtain ⟨herror,himage,hann,hn⟩ := hsrc.result_image (cap := q.capture)
  rw [himage] at hle
  obtain ⟨hshape,_⟩ := shape_of_at hsrc
  have ht := result_error (B := B) (Ψ := Ψ) (detail := detail) hshape hann
  rw [herror]
  apply reply_value_state hs hk hann hn hle ht
  · exact ⟨Ty.wfList_iff.mp hann.wf,trivial,trivial⟩
  · exact ⟨trivial,trivial⟩
  · exact hkc
  · exact hμ

end
end Benitoite.Release.Refinement
