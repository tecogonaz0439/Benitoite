import Benitoite.Release.Refinement.ExternalStateLeaves

/-! # At が読む構文と型・行の像 -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem checkAt_resolve {P B Ψ Q C Γ Φ R kind name shape bases pattern input index a e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.checkAt kind name shape bases pattern input index) a e L)
    (ρ : Nat → LocalRef) :
    (Comp.checkAt kind name shape bases pattern input index).resolveLocals ρ =
      .checkAt kind name shape bases pattern input index := by
  have hp := (h.read_values pattern (by simp [Comp.readValues])).choose_spec.resolve_id ρ
  have hi := (h.read_values input (by simp [Comp.readValues])).choose_spec.resolve_id ρ
  cases hb : bases with
  | none => simp only [Comp.resolveLocals,hp,hi]
  | some b =>
    have hbase := (h.read_values b (by simp [Comp.readValues,hb])).choose_spec.resolve_id ρ
    simp only [Comp.resolveLocals,hp,hi,hbase]

private theorem at_source {P B Ψ Q C Γ Φ Rs m a e L cap R kind name shape bases pattern input index}
    (h : HasTypeCQ P B Ψ Q C Γ Φ Rs m a e L) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hQ : Q = Qempty) (hC : C = [])
    (hm : m = .checkAt kind name shape bases pattern input index) :
    AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases pattern input index ∧
      Ty.LeQ P [] [] (cap.closeTy (.data shape.owner [.scoped name kind index,shape.errorType])) (cap.closeTy a) := by
  match h with
  | .C_CheckAt ha => subst Q C; cases hm; exact ⟨ha,.refl⟩
  | .C_Sub hb hl _ _ _ _ =>
    obtain ⟨ha,hle⟩ := at_source hb hc hQ hC hm
    subst Q C
    exact ⟨ha,.trans hle (hl.bind (valEnv cap.env) hc.transport)⟩
  | .C_Normal hb =>
    simpa only [Capture.closeTy,substTyValues_norm_source] using at_source hb hc hQ hC hm
  | .C_Eff hb _ => exact at_source hb hc hQ hC hm
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
    .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
    .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. |
    .C_App .. | .C_DependentApp .. | .C_IssuePathBases .. | .C_External .. => cases hm
termination_by structural h

/-- 注釈と参照先を同じ導出から取り出す。source の Γ/Φ は捕捉の証人と共有する。 -/
theorem ClosureTy.at_inputs {P B Ψ R q a e kind name shape bases pattern input index}
    (hq : ClosureTy P B Ψ [] R q a e)
    (hv : q.code = .checkAt kind name shape bases pattern input index) :
    ∃ Γ Φ, CaptureOk P B Ψ R Γ Φ q.capture ∧
      AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases pattern input index ∧
      Ty.LeQ P [] [] (q.capture.closeTy (.data shape.owner [.scoped name kind index,shape.errorType])) a := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hb,hl,hr,rfl,rfl,hrs⟩ := hq.open_zero
  cases m
  case checkAt k n sh bs p v ix =>
    have he := checkAt_resolve hb ρ
    change (Comp.checkAt k n sh bs p v ix).resolveLocals ρ = _ at hv
    rw [he] at hv
    cases hv
    obtain ⟨ha,hle⟩ := at_source hb hc rfl rfl rfl
    exact ⟨Γ,Φ,hc,ha,hle⟩
  all_goals simp only [Closure.code,Comp.resolveLocals] at hv; injection hv

private theorem closed_input_type {cap : Capture} {a : Ty} (h : a.WF 0 0 0) : cap.closeTy a.norm = a.norm := by
  change a.norm.substV (valEnv cap.env).values = a.norm
  rw [Ty.substV_of_wf_zero (Ty.wf_norm h),Ty.norm_idem]

/-- At の値入力を閉じる。request の型は捕捉元から閉じた注釈と一致する。 -/
theorem AtCallAdmissible.closed_input {P B Ψ R Γ Φ cap kind name shape bases pattern input index}
    (h : AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases pattern input index)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hc : CaptureOk P B Ψ R Γ Φ cap) :
    ∃ inputTy,
      (inputTy = .base .string ∧ B.valContent name = none ∨
        B.valContent name = some inputTy ∧ inputTy.WF 0 0 0 ∧ inputTy.RowsIn (· < 0)) ∧
      HasTypeV P B Ψ [] [] [] (closeVal cap input) inputTy.norm := by
  cases h with
  | mk _ _ _ _ hty hi _ _ =>
    refine ⟨_,hty,?_⟩
    have ht := close_value_typed hP hPB hB hw hs hd hc hi
    rw [closed_input_type (by rcases hty with ⟨rfl,_⟩ | ⟨_,hw,_⟩; trivial; exact hw)] at ht
    exact ht

/-- At の結果の型は捕捉の像で変わらない。固定添字の正規性は元の許容条件を使う。 -/
theorem AtCallAdmissible.result_image {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    {cap : Capture} (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    cap.closeTy shape.errorType = shape.errorType ∧
    cap.closeTy (.data shape.owner [.scoped name kind index,shape.errorType]) =
      .data shape.owner [.scoped name kind index,shape.errorType] ∧
    Ty.Annotation P [] [] (.data shape.owner [.scoped name kind index,shape.errorType]) ∧
    (.data shape.owner [.scoped name kind index,shape.errorType] : Ty).Normal := by
  cases h with
  | mk hs hk hb hp hty hi hw hix =>
    obtain ⟨r,rfl⟩ := AtPrepare.fixed_index hw
    have he := hs.errorType_eq
    refine ⟨?_,?_,?_,?_⟩
    · simp [he,atErrorType,Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,rawBindTys]
    · simp [he,atErrorType,Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Ty.normTys,rawBindTys,RangeIx.inst]
    · rw [he]
      exact ⟨⟨trivial,trivial,trivial⟩,⟨trivial,trivial,trivial⟩,
        ⟨⟨2,hs.arity,rfl⟩,trivial,by simpa only [he] using hs.errorType_declared (C := []) (Γ := []),trivial⟩⟩
    · rw [he]; rfl

end
end Benitoite.Release.Refinement
