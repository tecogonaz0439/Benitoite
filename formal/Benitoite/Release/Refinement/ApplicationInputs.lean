import Benitoite.Release.Refinement.ComputationInversion
import Benitoite.Release.Refinement.TelApplication
import Benitoite.Release.Refinement.CloseApplication

/-! # 実状態の呼出しから形成を持つ実引数列を取り出す -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 元の全前提を持つ呼出しにも、同じ実引数の一般適用を使える。 -/
example {P B Ψ Q C Γ Φ t u ws a e}
    (_hP : P.WellFormed) (_hB : B.CoreAssumptions P) (_hw : Ψ.WF)
    (hΓ : Ctx.WF 0 C.length Γ)
    (ht : Ty.Annotation P C Γ (.dependentFn t))
    (_hu : Ty.Annotation P C Γ (.dependentFn u))
    (h : TelClosure P Γ Φ t u)
    (args : HasTypeTelArgsQ P B Ψ Q C Γ Φ ws u a e) :
    ∃ b f, HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t b f ∧
      Ty.LeQ P Γ Φ b a ∧ Eff.Covers Γ Φ e f :=
  h.apply hΓ ht args

private theorem empty_regular (P : Program) : CaptureContextRegular P [] [] := by
  constructor
  · intro i a hi; cases hi
  · intro i a hi; cases hi

/-- 完全な文脈の形成から、捕捉元で読む形成条件を取り出す。 -/
theorem Ctx.Regular.capture_context {P C Γ} (h : Ctx.Regular P C Γ) :
    CaptureContextRegular P C Γ := by
  constructor
  · intro i a hi; exact (h.wf i a hi).capture
  · intro i a hi; exact ⟨(h.sorted i a hi).capture,(h.declared i a hi).capture⟩

/-- 宣言と注釈から得たRegular文脈でも、共通化の形成条件を供給する。 -/
example {P B Ψ Q C Γ Φ R T E L f ws}
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (reg : Ctx.Regular P C Γ)
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R (.app f ws) T E L) :
    ∃ t r e, HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t) ∧
      HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t r e ∧
      Ty.LeQ P Γ Φ r T ∧ Eff.Covers Γ Φ E e :=
  typed.app_tel rfl hw hs hd reg.capture_context

/-- 同じ実ストアの形成を使い、runの閉じた呼出しを共通の依存列へ移す。 -/
theorem StateTyE.app_inputs {P B σ Eb q k μ f ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app f ws) :
    ∃ Ψ R a e t r ef, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e ∧
      HasTypeVQ P B Ψ Qempty [] [] [] f (.dependentFn t) ∧
      Ty.Annotation P [] [] (.dependentFn t) ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws t r ef ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef := by
  obtain ⟨Ψ,R,a,b,e,e1,store,typed,_,_,_,_,_,_⟩ := state
  have hw := store.2.1
  have hs := store.2.2.1
  have hd := store.2.2.2.1
  have closed := typed.app_view_typed hP hPB hB hw hs hd view
  obtain ⟨t,r,ef,hf,args,le,cov⟩ := closed.app_tel rfl hw hs hd (empty_regular P)
  exact ⟨Ψ,R,a,e1,t,r,ef,store,typed,hf,
    open_value_annotation hw hs hd (empty_regular P) hf,args,le,cov⟩

/-- primitiveの実開始から、元の署名の依存列へ同じ実引数を戻す。 -/
theorem StateTyE.primitive_contract_inputs {P B σ Eb q k μ b ts es rs ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws) :
    ∃ Ψ R a e sg r ef, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e ∧
      B.sig b = some sg ∧ B.RangeAdmissible b sg rs ∧
      PrimitiveAdmissible [] 0 sg Qempty ts es ∧
      SignatureInstance P [] [] (Tel.instR rs sg.tel) (TypeCtx.kinds sg.tparams) ts es ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) r ef ∧
      Ty.LeQ P [] [] r a ∧ Eff.Covers [] [] e ef := by
  obtain ⟨Ψ,R,a,e,t,r,ef,store,typed,hf,ann,args,le,cov⟩ :=
    state.app_inputs hP hPB hB view
  obtain ⟨sg,u,hs,range,_,ad,inst,core,relation⟩ := hf.inv_prim rfl
  cases Option.some.inj core
  obtain ⟨r',ef',original,step,cover⟩ := relation.apply
    (by intro i a hi; cases hi) inst.result args
  exact ⟨Ψ,R,a,e,sg,r',ef',store,typed,hs,range,ad,inst,
    original,step.trans le,cov.trans cover⟩

/-- 結果の篩を読む後段も、元の同じ実開始から署名と型付き列を受ける。 -/
example {P B σ Eb q k μ b ts es rs ws}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (state : StateTyE P B σ Eb (.run q k μ)) (view : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws) :
    ∃ Ψ sg r ef, B.sig b = some sg ∧
      HasTypeTelArgsQ P B Ψ Qempty [] [] [] ws
        (instantiatedTel (Tel.instR rs sg.tel) ts es) r ef := by
  obtain ⟨Ψ,_,_,_,sg,r,ef,_,_,hs,_,_,_,args,_,_⟩ :=
    state.primitive_contract_inputs hP hPB hB view
  exact ⟨Ψ,sg,r,ef,hs,args⟩

end
end Benitoite.Release.Refinement
