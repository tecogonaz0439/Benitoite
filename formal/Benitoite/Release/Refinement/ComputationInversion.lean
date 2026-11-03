import Benitoite.Release.Refinement.ValueInversion
import Benitoite.Release.Refinement.CloseTyping
import Benitoite.Release.Refinement.ReferenceCalls

/-! # 計算の直接規則と到達する結果・効果の逆転 -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeCQ.inv_let {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {n} {code}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.letIn m n)) :
    ∃ a b ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 Δ)) ∧
      (Ty.Declared P C Γ b) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε  := by
  match h with
  | .C_Let h0 h1 h2 => cases hm; exact ⟨_, _, _, h0, h1, h2, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal h =>
    obtain ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ := h.inv_let hm
    exact ⟨x0, x1, x2, h0, h1, h2, .trans le (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub h hl he .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ := h.inv_let hm
    exact ⟨x0, x1, x2, h0, h1, h2, .trans le hl, he.trans cov⟩
  | .C_Eff h he =>
    obtain ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ := h.inv_let hm
    exact ⟨x0, x1, x2, h0, h1, h2, le, he.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_App .. |
      .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. |
      .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
      .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. |
      .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_escape {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {code}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.escape v)) :
    ∃ r a ε,
      (R = (some r)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v r) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε  := by
  match h with
  | .C_Escape h0 h1 => cases hm; exact ⟨_, _, _, rfl, h0, h1, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal h =>
    obtain ⟨x0, x1, x2, hr, h0, h1, le, cov⟩ := h.inv_escape hm
    exact ⟨x0, x1, x2, hr, h0, h1, .trans le (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub h hl he .. =>
    obtain ⟨x0, x1, x2, hr, h0, h1, le, cov⟩ := h.inv_escape hm
    exact ⟨x0, x1, x2, hr, h0, h1, .trans le hl, he.trans cov⟩
  | .C_Eff h he =>
    obtain ⟨x0, x1, x2, hr, h0, h1, le, cov⟩ := h.inv_escape hm
    exact ⟨x0, x1, x2, hr, h0, h1, le, he.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. |
      .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. |
      .C_Lazy .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. |
      .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. |
      .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

/-- appの二規則を、その直接前提と到達する結果・効果の選言で返す。 -/
theorem HasTypeCQ.inv_app {P B Ψ Q C Γ Φ R code T E L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T E L) (hm : code = .app f ws) :
    (∃ ns ps r e, HasTypeVQ P B Ψ Q C Γ Φ f (.fn ns ps r e) ∧
      HasTypeVsQ P B Ψ Q C Γ Φ ws ps ∧ Ty.LeQ P Γ Φ r T ∧ Eff.Covers Γ Φ E e) ∨
    (∃ t r e, HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t) ∧
      HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t r e ∧ Ty.LeQ P Γ Φ r T ∧ Eff.Covers Γ Φ E e) := by
  match h with
  | .C_App hf hs => cases hm; exact .inl ⟨_,_,_,_,hf,hs,.refl,.refl _ _ _⟩
  | .C_DependentApp hf hs => cases hm; exact .inr ⟨_,_,_,hf,hs,.refl,.refl _ _ _⟩
  | .C_Normal h =>
    rcases h.inv_app hm with ⟨ns,ps,r,e,hf,hs,le,cov⟩ | ⟨t,r,e,hf,hs,le,cov⟩
    · exact .inl ⟨ns,ps,r,e,hf,hs,.trans le (.convert (Ty.norm_idem _).symm),cov⟩
    · exact .inr ⟨t,r,e,hf,hs,.trans le (.convert (Ty.norm_idem _).symm),cov⟩
  | .C_Sub h hl he .. =>
    rcases h.inv_app hm with ⟨ns,ps,r,e,hf,hs,le,cov⟩ | ⟨t,r,e,hf,hs,le,cov⟩
    · exact .inl ⟨ns,ps,r,e,hf,hs,.trans le hl,he.trans cov⟩
    · exact .inr ⟨t,r,e,hf,hs,.trans le hl,he.trans cov⟩
  | .C_Eff h he =>
    rcases h.inv_app hm with ⟨ns,ps,r,e,hf,hs,le,cov⟩ | ⟨t,r,e,hf,hs,le,cov⟩
    · exact .inl ⟨ns,ps,r,e,hf,hs,le,he.trans cov⟩
    · exact .inr ⟨t,r,e,hf,hs,le,he.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_If .. |
      .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. |
      .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. |
      .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

private theorem bind_shift_ty (a : Ty) (v : Val) :
    (a.shiftV 1 0).bind (Tel.argumentsEnv v) = a.norm := by
  rw [argumentsEnv_eq]
  unfold Ty.bind SubstEnv.valuesOnly
  rw [←Ty.rawSubstV_eq_rawBind,Ty.substV_shift_cancel a (by intro i; rfl)]

private theorem bind_shift_eff (e : Eff) (v : Val) :
    Eff.bind (Tel.argumentsEnv v) (e.shiftV 1 0) = e.norm := by
  rw [argumentsEnv_eq]
  unfold Eff.bind SubstEnv.valuesOnly
  rw [←Eff.rawSubstV_eq_rawBind,Eff.substV_shift_cancel e (by intro i; rfl)]

private theorem vs_normal {P B Ψ Q C Γ Φ vs ps}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs ps) :
    HasTypeVsQ P B Ψ Q C Γ Φ vs (Ty.normTys ps) := by
  match h with
  | .nil => exact .nil
  | .cons hv hs => exact .cons hv.V_Normal (vs_normal hs)

private theorem vs_toTel {P B Ψ Q C Γ Φ vs ns ps r e}
    (ha : Ty.Annotation P C Γ (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Q C Γ Φ vs ps) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e) := by
  induction ns generalizing ps vs r e with
  | nil =>
    cases ps with
    | cons => have hn := ha.wf.1.1; simp at hn
    | nil => cases hs; exact .done (ha.norm.toTel)
  | cons n ns ih =>
    cases ps with
    | nil => have hn := ha.wf.1.1; simp at hn
    | cons x ps =>
      cases hs with
      | cons hv hs =>
        have hr : Ty.Annotation P C Γ (.fn ns ps r e) :=
          ⟨⟨⟨by simpa [NamesWF] using Nat.succ.inj ha.wf.1.1,ha.wf.1.2.of_cons⟩,
            ha.wf.2.1.2,ha.wf.2.2⟩,⟨ha.sorted.1.2,ha.sorted.2⟩,
            ⟨ha.declared.1.2,ha.declared.2⟩⟩
        apply HasTypeTelArgsQ.param (⟨ha.wf.2.1.1,ha.sorted.1.1,ha.declared.1.1⟩ : Ty.Annotation P C Γ x).norm hv.V_Normal
        have hh := ih hr.norm (vs_normal hs)
        simpa only [Ty.toTel,Tel.bind_toTel,bind_shift_ty,bind_shift_eff,
          shiftVTys_eq_map,List.map_map,Function.comp_def,Ty.normTys_eq_map,
          Ty.norm_idem,Eff.norm_idem] using hh

/-- 非依存の値列を、開いた同じ文脈の正規化した依存列へ移す。 -/
theorem HasTypeVsQ.toTel_in_context {P B Ψ Q C Γ Φ vs ns ps r e}
    (ha : Ty.Annotation P C Γ (.fn ns ps r e))
    (hs : HasTypeVsQ P B Ψ Q C Γ Φ vs ps) :
    HasTypeTelArgsQ P B Ψ Q C Γ Φ vs
      (Ty.toTel ns (Ty.normTys ps) r.norm (Eff.norm e)) r.norm (Eff.norm e) :=
  vs_toTel ha hs

/-- 任意のΓで、StoreのWF・Sorted・DeclaredとCaptureContextRegularを使い、appの二枝を同じ依存列へ統一する。 -/
theorem HasTypeCQ.app_tel {P B Ψ Q C Γ Φ R code T E L f ws}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T E L) (hm : code = .app f ws)
    (hw : Ψ.WF) (hs : Ψ.Sorted) (hd : StoreTy.Declared P Ψ)
    (hΓ : CaptureContextRegular P C Γ) :
    ∃ t r e, HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t) ∧
      HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t r e ∧
      Ty.LeQ P Γ Φ r T ∧ Eff.Covers Γ Φ E e := by
  rcases h.inv_app hm with ⟨ns,ps,r,e,hf,args,le,cov⟩ | ⟨t,r,e,hf,args,le,cov⟩
  · have ann := open_value_annotation hw hs hd hΓ hf
    have tel := args.toTel_in_context ann
    have same := Ty.norm_toTel (r := r.norm) (e := Eff.norm e) ann.norm.wf.1
    have fann := ann.norm.toTel
    refine ⟨_,_,_,hf.V_Sub (.convert ?_) fann.wf fann.sorted fann.declared,tel,
      .trans (.convert (Ty.norm_idem _)) le,?_⟩
    · exact (Ty.norm_idem _).symm.trans same.symm
    · exact Eff.covers_norm_right.mpr cov
  · exact ⟨t,r,e,hf,args,le,cov⟩

/-- letの後半を失わず、束縛の外の結果型の宣言も取り出す。 -/
example {P B Ψ Q C Γ Φ R T E L m n}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.letIn m n) T E L) :
    ∃ a b e, HasTypeCQ P B Ψ Q C Γ Φ R m a e L ∧ Ty.Declared P C Γ b := by
  obtain ⟨a,b,e,hm,_,hd,_,_⟩ := h.C_Normal.inv_let rfl
  exact ⟨a,b,e,hm,hd⟩

/-- escapeは到達する結果型と独立に、元の戻り先と同じ値を保持する。 -/
example {P B Ψ Q C Γ Φ R T E L v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.escape v) T E L) :
    ∃ r, R = some r ∧ HasTypeVQ P B Ψ Q C Γ Φ v r := by
  obtain ⟨r,_,_,hr,hv,_,_,_⟩ := h.C_Normal.inv_escape rfl
  exact ⟨r,hr,hv⟩


end
end Benitoite.Release.Refinement
