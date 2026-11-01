import Benitoite.Release.Refinement.ClosureTyping

/-! # 捕捉した値の閉性と固定した経路環境との対応 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Capture.Closed.env {cap : Capture} (h : cap.Closed) (i : Nat) : (cap.env i).Ground := by
  cases cap with
  | mk vs =>
    induction vs generalizing i with
    | nil => trivial
    | cons v vs ih =>
      cases i with
      | zero => cases v with
        | none => trivial
        | some v => exact h.1
      | succ i =>
        have hh : (Capture.mk vs).Closed := by cases v <;> first | exact h | exact h.2
        exact ih i hh

theorem Capture.Adequate.env {σ : PathEnv} {cap : Capture} (h : cap.Adequate σ) (i : Nat) : (cap.env i).Adequate σ := by
  cases cap with
  | mk vs =>
    induction vs generalizing i with
    | nil => trivial
    | cons v vs ih =>
      cases i with
      | zero => cases v with
        | none => trivial
        | some v => exact h.1
      | succ i =>
        have hh : (Capture.mk vs).Adequate σ := by cases v <;> first | exact h | exact h.2
        exact ih i hh

mutual
  theorem closeVal_adequate {σ : PathEnv} {cap : Capture} {v : Val} (hc : cap.Adequate σ) (hv : v.Adequate σ) :
      (closeVal cap v).Adequate σ := by
    cases v <;> try exact hv <;> try trivial
    case var i => exact hc.env i
    case lam ns ps body => exact ⟨hc,hv⟩
    case dependentLam t body => exact ⟨hc,hv⟩
    case con c ts vs => exact closeVals_adequate hc hv
    case list vs => exact closeVals_adequate hc hv
    case dict i ts vs => exact closeVals_adequate hc hv
    case setV vs => exact closeVals_adequate hc hv
    case mapV ks vs => exact ⟨closeVals_adequate hc hv.1,closeVals_adequate hc hv.2⟩
    case super v cl => exact closeVal_adequate (v := v) hc hv
  theorem closeVals_adequate {σ : PathEnv} {cap : Capture} {vs : List Val} (hc : cap.Adequate σ) (hv : adequateVals σ vs) :
      adequateVals σ (closeVals cap vs) := by
    cases vs with
    | nil => trivial
    | cons v vs => exact ⟨closeVal_adequate (v := v) hc hv.1,closeVals_adequate (vs := vs) hc hv.2⟩
end

theorem typeAnnotations_of_lists {P C Γ ts}
    (hw : Ty.WFList 0 C.length Γ.length ts) (hs : sortedTys Γ ts) (hd : declaredTys P C Γ ts) :
    TypeAnnotations P C Γ ts := by
  induction ts with
  | nil => intro t ht; cases ht
  | cons t ts ih =>
    intro a ha
    rcases List.mem_cons.mp ha with rfl | ha
    · exact ⟨hw.1,hs.1,hd.1⟩
    · exact ih hw.2 hs.2 hd.2 a ha

theorem CaptureOk.close_annotations {P B Ψ R Γ Φ cap C ts}
    (hc : CaptureOk P B Ψ R Γ Φ cap) (ht : TypeAnnotations P C Γ ts) (hC : C = []) :
    ∀ a ∈ ts.map cap.closeTy, a.WF 0 0 0 := by
  intro a ha
  obtain ⟨t,ht',rfl⟩ := List.mem_map.mp ha
  exact (hc.substOk.annotation (hC ▸ ht t ht')).wf

mutual
  theorem HasTypeVQ.close_ground {P B Ψ Q C Γ Φ v a cap R}
      (h : HasTypeVQ P B Ψ Q C Γ Φ v a)
      (hc : CaptureOk P B Ψ R Γ Φ cap) (hC : C = []) (hcap : cap.Closed)
      (hv : v.ClosedAt 0 cap.values.length) : (closeVal cap v).Ground := by
    match h with
    | .V_Var .. => exact hcap.env _
    | .V_Const .. | .V_AtError .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. => trivial
    | .V_CheckedAt (request := req) _ => cases req <;> first | trivial | exact hv
    | .V_CheckedRequest .. | .V_Closure .. => exact hv
    | .V_Normal h | .V_Sub h .. | .V_Refine h .. => exact h.close_ground hc hC hcap hv
    | .V_Lam (ns := ns) (ps := ps) (body := body) hn hw hs hb hd =>
      have hps : TypeAnnotations P C Γ ps := typeAnnotations_of_lists hw.2.1 hs.1 hd.1
      have hpsw := hc.close_annotations hps hC
      have ht : (cap.closeTel (lambdaShape ns ps)).WF 0 0 0 := by
        rw [Capture.closeTel,lambdaShape,Tel.bind_toTel]
        exact Tel.wf_toTel ⟨by simpa using hn.1,hn.2⟩ (Ty.wfList_iff.mpr hpsw) trivial trivial rfl
      have har : telBinders (cap.closeTel (lambdaShape ns ps)) = ps.length := by
        rw [Capture.closeTel,telBinders_bind,telBinders_arity]
        exact Tel.arity_toTel hn
      exact ⟨ht,hcap,by simpa only [har] using hv.2.2⟩
    | .V_DependentLam (t := t) ha hb =>
      have ht := hc.substOk.telAnnotation (hC ▸ ha)
      exact ⟨ht.wf,hcap,by simpa only [Capture.closeTel,telBinders_bind] using hv.2⟩
    | .V_Fun _ _ _ hi =>
      refine ⟨hc.close_annotations hi.types hC,?_⟩
      intro out hout
      obtain ⟨row,hrow,rfl⟩ := List.mem_map.mp hout
      have ht := hc.substOk.annotation (hC ▸ hi.rows row hrow)
      exact ⟨ht.wf.2.2.2.1,ht.wf.2.2.2.2⟩
    | .V_Prim _ _ _ _ hi =>
      refine ⟨hc.close_annotations hi.types hC,?_,hv.2.2⟩
      intro out hout
      obtain ⟨row,hrow,rfl⟩ := List.mem_map.mp hout
      have ht := hc.substOk.annotation (hC ▸ hi.rows row hrow)
      exact ⟨ht.wf.2.2.2.1,ht.wf.2.2.2.2⟩
    | .V_Op _ _ _ hi => exact hc.close_annotations hi.types hC
    | .V_ExternalRef _ _ _ hi => exact hc.close_annotations hi.types hC
    | .V_ExternalHandle _ _ _ _ _ _ ha =>
      exact hc.close_annotations (typeAnnotations_of_lists ha.wf ha.sorted ha.declared.2) hC
    | .V_Con _ _ _ _ hs ha =>
      exact ⟨hc.close_annotations (typeAnnotations_of_lists ha.wf ha.sorted ha.declared.2) hC,
        HasTypeVsQ.close_ground hs hc hC hcap hv.2⟩
    | .V_List hs _ _ _ | .V_Set hs _ _ => exact HasTypeEachQ.close_ground hs hc hC hcap hv
    | .V_Map hk hv' _ _ _ _ =>
      exact ⟨HasTypeEachQ.close_ground hk hc hC hcap hv.1,HasTypeEachQ.close_ground hv' hc hC hcap hv.2⟩
    | .V_Dict _ _ hts _ _ _ hs _ => exact ⟨hc.close_annotations hts hC,HasTypeVsQ.close_ground hs hc hC hcap hv.2⟩
    | .V_Super h _ _ _ => exact h.close_ground hc hC hcap hv
    | .V_Raise ha hot hoe =>
      have ha := hC ▸ ha
      exact ⟨(hc.substOk.annotation ⟨ha.wf.2.2.1,ha.sorted.2.1,ha.declared.2.1⟩).wf,
        (hc.substOk.annotation ⟨ha.wf.2.1.1,ha.sorted.1.1,ha.declared.1.1⟩).wf⟩
  termination_by structural h

  theorem HasTypeVsQ.close_ground {P B Ψ Q C Γ Φ vs as cap R}
      (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as)
      (hc : CaptureOk P B Ψ R Γ Φ cap) (hC : C = []) (hcap : cap.Closed)
      (hv : Val.ClosedList 0 cap.values.length vs) : Val.ClosedList 0 0 (closeVals cap vs) := by
    match h with
    | .nil => trivial
    | .cons h hs => exact ⟨h.close_ground hc hC hcap hv.1,hs.close_ground hc hC hcap hv.2⟩
  termination_by structural h

  theorem HasTypeEachQ.close_ground {P B Ψ Q C Γ Φ vs a cap R}
      (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a)
      (hc : CaptureOk P B Ψ R Γ Φ cap) (hC : C = []) (hcap : cap.Closed)
      (hv : Val.ClosedList 0 cap.values.length vs) : Val.ClosedList 0 0 (closeVals cap vs) := by
    match h with
    | .nil => trivial
    | .cons h hs => exact ⟨h.close_ground hc hC hcap hv.1,hs.close_ground hc hC hcap hv.2⟩
  termination_by structural h
end

end
end Benitoite.Release.Refinement
