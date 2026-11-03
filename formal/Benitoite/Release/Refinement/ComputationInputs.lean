import Benitoite.Release.Refinement.ComputationInversion
import Benitoite.Release.Refinement.PathConditions

/-! # 計算の開始から直接規則の全前提を取り出す -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem HasTypeCQ.inv_builderLet {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {body} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.builderLet kind body)) :
∃ a ε,
      (Ty.Annotation P C Γ kind.contents) ∧
      (TypeArgsKinded P C [kind.contents] [.value]) ∧
      (HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
          body (a.shiftV 1 0) (ε.shiftV 1 0)
          (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) Δ)) ∧
      (Ty.Declared P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε := by
  match typed with
  | .C_BuilderLet h0 h1 h2 h3 => cases hm; exact ⟨_, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, x1, h0, h1, h2, h3, le, cov⟩ := hh.inv_builderLet hm
    exact ⟨x0, x1, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, x1, h0, h1, h2, h3, le, cov⟩ := hh.inv_builderLet hm
    exact ⟨x0, x1, h0, h1, h2, h3, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, x1, h0, h1, h2, h3, le, cov⟩ := hh.inv_builderLet hm
    exact ⟨x0, x1, h0, h1, h2, h3, le, cover.trans cov⟩
  | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_builderOp {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {op} {ref} {args} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.builderOp kind op ref args)) :
(Ty.Annotation P C Γ kind.contents) ∧
      (TypeArgsKinded P C [kind.contents] [.value]) ∧
      (LocalRef.HasKind Ψ Δ ref kind) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind)) ∧
      Ty.LeQ P Γ Φ (op.resultType kind) T ∧ Eff.Covers Γ Φ outEff Eff.empty := by
  match typed with
  | .C_BuilderOp h0 h1 h2 h3 => cases hm; exact ⟨h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨h0, h1, h2, h3, le, cov⟩ := hh.inv_builderOp hm
    exact ⟨h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨h0, h1, h2, h3, le, cov⟩ := hh.inv_builderOp hm
    exact ⟨h0, h1, h2, h3, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨h0, h1, h2, h3, le, cov⟩ := hh.inv_builderOp hm
    exact ⟨h0, h1, h2, h3, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_match {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {arms} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.match v arms)) :
∃ obs a b ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v a) ∧
      ((∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s)) ∧
      (HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ) ∧
      (Exhaustive P a (unguardedPats arms)) ∧
      Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε := by
  match typed with
  | .C_Match h0 h1 h2 h3 => cases hm; exact ⟨_, _, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cov⟩ := hh.inv_match hm
    exact ⟨x0, x1, x2, x3, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cov⟩ := hh.inv_match hm
    exact ⟨x0, x1, x2, x3, h0, h1, h2, h3, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cov⟩ := hh.inv_match hm
    exact ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_lazy {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.lazyC m)) :
∃ a,
      (HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty []) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ (.lazy a) T ∧ Eff.Covers Γ Φ outEff Eff.empty := by
  match typed with
  | .C_Lazy h0 h1 => cases hm; exact ⟨_, h0, h1, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, h0, h1, le, cov⟩ := hh.inv_lazy hm
    exact ⟨x0, h0, h1, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, h0, h1, le, cov⟩ := hh.inv_lazy hm
    exact ⟨x0, h0, h1, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, h0, h1, le, cov⟩ := hh.inv_lazy hm
    exact ⟨x0, h0, h1, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_use {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.use v m)) :
∃ o a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top))) ∧
      (B.isResource o = true) ∧
      (HasTypeCQ P B Ψ Q C Γ Φ R m a ε Δ) ∧
      (ε.test (.name stateEff (.fixed .top)) = true) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε := by
  match typed with
  | .C_Use h0 h1 h2 h3 => cases hm; exact ⟨_, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_use hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_use hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_use hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_handle {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {m} {handlers} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.handle m handlers)) :
(∃ t εm ε,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ) ∧
      (Eff.Sub εm (Eff.union ε (handled P B handlers))) ∧
      (HasTypeClausesQ P B Ψ Q C Γ Φ R εm handlers t ε Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
    (∃ t E eb rest ec,
      (HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ) ∧
      (Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) ∧
      (NoFail Q rest) ∧
      (HasFailureClause P B Ψ Q C Γ Φ E R handlers t ec Δ) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff (Eff.union rest ec)) := by
  match typed with
  | .C_Handle h0 h1 h2 => cases hm; exact Or.inl (⟨_, _, _, h0, h1, h2, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_Handle_Fail h0 h1 h2 h3 => cases hm; exact Or.inr (⟨_, _, _, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_Normal hh =>
    rcases hh.inv_handle hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
  | .C_Sub hh step cover .. =>
    rcases hh.inv_handle hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans step, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le.trans step, cover.trans cov⟩)
  | .C_Eff hh cover =>
    rcases hh.inv_handle hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, x4, h0, h1, h2, h3, le, cover.trans cov⟩)
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_resumeVar {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {i} {v} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.resume (.var i) v)) :
(∃ b t ε,
      (Γ[i]? = some (some (.cont b t ε))) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
      (Ty.Declared P C Γ t) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
    (∃ b t ε,
      (Γ[i]? = some (some (.cont b t ε))) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
      (Ty.Declared P C Γ t.norm) ∧
      Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε)) := by
  match typed with
  | .C_Resume h0 h1 h2 => cases hm; exact Or.inl (⟨_, _, _, h0, h1, h2, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_ResumeNorm h0 h1 h2 => cases hm; exact Or.inr (⟨_, _, _, h0, h1, h2, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_Normal hh =>
    rcases hh.inv_resumeVar hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, h0, h1, h2, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
    · exact Or.inr (⟨x0, x1, x2, h0, h1, h2, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
  | .C_Sub hh step cover .. =>
    rcases hh.inv_resumeVar hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, h0, h1, h2, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans step, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, h0, h1, h2, le.trans step, cover.trans cov⟩)
  | .C_Eff hh cover =>
    rcases hh.inv_resumeVar hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, h0, h1, h2, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, h0, h1, h2, le, cover.trans cov⟩)
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_ResumeL .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_resumeL {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {l} {v} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.resume (.loc l) v)) :
(∃ b t ε,
      (Ψ l = some (.cont b t ε R)) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
      (Ty.Declared P C Γ t) ∧
      Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
    (∃ R' b t ε,
      (Ψ l = some (.cont b t ε R')) ∧
      (R'.map Ty.norm = R.map Ty.norm) ∧
      (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
      (Ty.Declared P C Γ t.norm) ∧
      Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε)) := by
  match typed with
  | .C_ResumeL h0 h1 h2 => cases hm; exact Or.inl (⟨_, _, _, h0, h1, h2, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_ResumeLNorm h0 h1 h2 h3 => cases hm; exact Or.inr (⟨_, _, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩)
  | .C_Normal hh =>
    rcases hh.inv_resumeL hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩)
  | .C_Sub hh step cover .. =>
    rcases hh.inv_resumeL hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le.trans step, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, h0, h1, h2, h3, le.trans step, cover.trans cov⟩)
  | .C_Eff hh cover =>
    rcases hh.inv_resumeL hm with ⟨x0, x1, x2, h0, h1, h2, le, cov⟩ | ⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cov⟩
    · exact Or.inl (⟨x0, x1, x2, h0, h1, h2, le, cover.trans cov⟩)
    · exact Or.inr (⟨x0, x1, x2, x3, h0, h1, h2, h3, le, cover.trans cov⟩)
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_meth {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {v} {m} {ss} {es} {ws} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.meth v m ss es ws)) :
∃ cl τ cd ms as a ε,
      (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl τ)) ∧
      (P.classes cl = some cd) ∧
      (cd.methods m = some ms) ∧
      (NamesWF ms.names ms.params) ∧
      (SatAll B C ss (TypeCtx.constraints ms.tparams)) ∧
      (SignatureInstance P C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es) ∧
      (MethodRowsAdmissible C Γ.length Q ms es) ∧
      (Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) es) ws = some (as, a, ε)) ∧
      (HasTypeVsQ P B Ψ Q C Γ Φ ws as) ∧
      (Ty.Annotation P C Γ a) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε := by
  match typed with
  | .C_Meth h0 h1 h2 h3 h4 h5 h6 h7 h8 h9 => cases hm; exact ⟨_, _, _, _, _, _, _, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, x1, x2, x3, x4, x5, x6, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, le, cov⟩ := hh.inv_meth hm
    exact ⟨x0, x1, x2, x3, x4, x5, x6, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, x1, x2, x3, x4, x5, x6, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, le, cov⟩ := hh.inv_meth hm
    exact ⟨x0, x1, x2, x3, x4, x5, x6, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, x1, x2, x3, x4, x5, x6, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, le, cov⟩ := hh.inv_meth hm
    exact ⟨x0, x1, x2, x3, x4, x5, x6, h0, h1, h2, h3, h4, h5, h6, h7, h8, h9, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_External .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_external {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {f} {ts} {vs} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.externalCall f ts vs)) :
∃ d a e,
      (P.externalFunction f = some d) ∧
      (d.WF P) ∧
      (ExternalCallAdmissible P B C d ts) ∧
      (HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e) ∧
      Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff e := by
  match typed with
  | .C_External h0 h1 h2 h3 => cases hm; exact ⟨_, _, _, h0, h1, h2, h3, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_external hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_external hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, x1, x2, h0, h1, h2, h3, le, cov⟩ := hh.inv_external hm
    exact ⟨x0, x1, x2, h0, h1, h2, h3, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_IssuePathBases .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_issuePathBases {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {b : PrimName} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.issuePathBases b)) :
∃ (sg : PrimSig),
      (B.sig b = some sg) ∧
      (sg.kind = .pathBases) ∧
      (sg.opEff = some processEnvironmentEff) ∧
      (sg.params = []) ∧
      (sg.ret = .pathBases) ∧
      (sg.eff = Eff.single processEnvironmentEff) ∧
      Ty.LeQ P Γ Φ .pathBases T ∧ Eff.Covers Γ Φ outEff (Eff.single processEnvironmentEff) := by
  match typed with
  | .C_IssuePathBases _ _ h0 h1 h2 h3 h4 h5 => cases hm; exact ⟨_, h0, h1, h2, h3, h4, h5, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨x0, h0, h1, h2, h3, h4, h5, le, cov⟩ := hh.inv_issuePathBases hm
    exact ⟨x0, h0, h1, h2, h3, h4, h5, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨x0, h0, h1, h2, h3, h4, h5, le, cov⟩ := hh.inv_issuePathBases hm
    exact ⟨x0, h0, h1, h2, h3, h4, h5, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨x0, h0, h1, h2, h3, h4, h5, le, cov⟩ := hh.inv_issuePathBases hm
    exact ⟨x0, h0, h1, h2, h3, h4, h5, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_CheckAt .. => cases hm

theorem HasTypeCQ.inv_checkAt {P : Program} {B : Builtins} {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx} {Φ : List Pred} {T : Ty} {R : Option Ty} {Δ : LocalCtx} {outEff : Eff} {kind} {name} {shape} {bases} {pattern} {input} {index} {code}
    (typed : HasTypeCQ P B Ψ Q C Γ Φ R code T outEff Δ) (hm : code = (.checkAt kind name shape bases pattern input index)) :
(AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) ∧
      Ty.LeQ P Γ Φ (.data shape.owner [.scoped name kind index, shape.errorType]) T ∧ Eff.Covers Γ Φ outEff Eff.empty := by
  match typed with
  | .C_CheckAt h0 => cases hm; exact ⟨h0, .refl, Eff.Covers.refl _ _ _⟩
  | .C_Normal hh =>
    obtain ⟨h0, le, cov⟩ := hh.inv_checkAt hm
    exact ⟨h0, le.trans (.convert (Ty.norm_idem _).symm), cov⟩
  | .C_Sub hh step cover .. =>
    obtain ⟨h0, le, cov⟩ := hh.inv_checkAt hm
    exact ⟨h0, le.trans step, cover.trans cov⟩
  | .C_Eff hh cover =>
    obtain ⟨h0, le, cov⟩ := hh.inv_checkAt hm
    exact ⟨h0, le, cover.trans cov⟩
  | .C_BuilderLet .. | .C_BuilderOp .. | .C_Return .. | .C_Let .. | .C_App .. | .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. | .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Resume .. | .C_ResumeL .. | .C_ResumeNorm .. | .C_ResumeLNorm .. | .C_Meth .. | .C_External .. | .C_IssuePathBases .. => cases hm

/-- 各開始構文の直接前提。app/handle/resumeの複数規則は選言を保つ。 -/
def Comp.Inputs (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (T : Ty) (outEff : Eff)
    (L : LocalCtx) : Comp → Prop
  | .builderLet kind body =>
      ∃ a ε,
            (Ty.Annotation P C Γ kind.contents) ∧
            (TypeArgsKinded P C [kind.contents] [.value]) ∧
            (HasTypeCQ P B Ψ Q C Γ.extendNone (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
                body (a.shiftV 1 0) (ε.shiftV 1 0)
                (LocalCtx.extend (some (renameKind (shiftIndex 1 0) kind)) L)) ∧
            (Ty.Declared P C Γ a) ∧
            Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε
  | .builderOp kind op ref args =>
      (Ty.Annotation P C Γ kind.contents) ∧
            (TypeArgsKinded P C [kind.contents] [.value]) ∧
            (LocalRef.HasKind Ψ L ref kind) ∧
            (HasTypeVsQ P B Ψ Q C Γ Φ args (op.parameters kind)) ∧
            Ty.LeQ P Γ Φ (op.resultType kind) T ∧ Eff.Covers Γ Φ outEff Eff.empty
  | .match v arms =>
      ∃ obs a b ε,
            (HasTypeVQ P B Ψ Q C Γ Φ v a) ∧
            ((∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s)) ∧
            (HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε L) ∧
            (Exhaustive P a (unguardedPats arms)) ∧
            Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε
  | .lazyC m =>
      ∃ a,
            (HasTypeCQ P B (hideBuilders Ψ) Q C (hideConts Γ) Φ none m a Eff.empty []) ∧
            (Ty.Annotation P C Γ a) ∧
            Ty.LeQ P Γ Φ (.lazy a) T ∧ Eff.Covers Γ Φ outEff Eff.empty
  | .use v m =>
      ∃ o a ε,
            (HasTypeVQ P B Ψ Q C Γ Φ v (.opaque o (.fixed .top))) ∧
            (B.isResource o = true) ∧
            (HasTypeCQ P B Ψ Q C Γ Φ R m a ε L) ∧
            (ε.test (.name stateEff (.fixed .top)) = true) ∧
            Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε
  | .handle m handlers =>
      (∃ t εm ε,
            (HasTypeCQ P B Ψ Q C Γ Φ R m t εm L) ∧
            (Eff.Sub εm (Eff.union ε (handled P B handlers))) ∧
            (HasTypeClausesQ P B Ψ Q C Γ Φ R εm handlers t ε L) ∧
            Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
          (∃ t E eb rest ec,
            (HasTypeCQ P B Ψ Q C Γ Φ R m t eb L) ∧
            (Eff.Sub eb (Eff.union (Eff.singleFail E) rest)) ∧
            (NoFail Q rest) ∧
            (HasFailureClause P B Ψ Q C Γ Φ E R handlers t ec L) ∧
            Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff (Eff.union rest ec))
  | .resume (.var i) v =>
      (∃ b t ε,
            (Γ[i]? = some (some (.cont b t ε))) ∧
            (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
            (Ty.Declared P C Γ t) ∧
            Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
          (∃ b t ε,
            (Γ[i]? = some (some (.cont b t ε))) ∧
            (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
            (Ty.Declared P C Γ t.norm) ∧
            Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε))
  | .resume (.loc l) v =>
      (∃ b t ε,
            (Ψ l = some (.cont b t ε R)) ∧
            (HasTypeVQ P B Ψ Q C Γ Φ v b) ∧
            (Ty.Declared P C Γ t) ∧
            Ty.LeQ P Γ Φ t T ∧ Eff.Covers Γ Φ outEff ε) ∨
          (∃ R' b t ε,
            (Ψ l = some (.cont b t ε R')) ∧
            (R'.map Ty.norm = R.map Ty.norm) ∧
            (HasTypeVQ P B Ψ Q C Γ Φ v b.norm) ∧
            (Ty.Declared P C Γ t.norm) ∧
            Ty.LeQ P Γ Φ t.norm T ∧ Eff.Covers Γ Φ outEff (Eff.norm ε))
  | .meth v m ss es ws =>
      ∃ cl τ cd ms as a ε,
            (HasTypeVQ P B Ψ Q C Γ Φ v (.dict cl τ)) ∧
            (P.classes cl = some cd) ∧
            (cd.methods m = some ms) ∧
            (NamesWF ms.names ms.params) ∧
            (SatAll B C ss (TypeCtx.constraints ms.tparams)) ∧
            (SignatureInstance P C Γ ms.tel (TypeCtx.kinds ms.tparams ++ [cd.argumentKind]) (ss ++ [τ]) es) ∧
            (MethodRowsAdmissible C Γ.length Q ms es) ∧
            (Tel.arguments (instantiatedTel ms.tel (ss ++ [τ]) es) ws = some (as, a, ε)) ∧
            (HasTypeVsQ P B Ψ Q C Γ Φ ws as) ∧
            (Ty.Annotation P C Γ a) ∧
            Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε
  | .externalCall f ts vs =>
      ∃ d a e,
            (P.externalFunction f = some d) ∧
            (d.WF P) ∧
            (ExternalCallAdmissible P B C d ts) ∧
            (HasTypeTelArgsQ P B Ψ Q C Γ Φ vs (Tel.bind (typeEnv ts) d.parameters) a e) ∧
            Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff e
  | .issuePathBases b =>
      ∃ (sg : PrimSig),
            (B.sig b = some sg) ∧
            (sg.kind = .pathBases) ∧
            (sg.opEff = some processEnvironmentEff) ∧
            (sg.params = []) ∧
            (sg.ret = .pathBases) ∧
            (sg.eff = Eff.single processEnvironmentEff) ∧
            Ty.LeQ P Γ Φ .pathBases T ∧ Eff.Covers Γ Φ outEff (Eff.single processEnvironmentEff)
  | .checkAt kind name shape bases pattern input index =>
      (AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) ∧
            Ty.LeQ P Γ Φ (.data shape.owner [.scoped name kind index, shape.errorType]) T ∧ Eff.Covers Γ Φ outEff Eff.empty
  | .letIn m n =>
      ∃ a b ε,
            (HasTypeCQ P B Ψ Q C Γ Φ R m a ε L) ∧
            (HasTypeCQ P B Ψ Q C (Γ.extend a) (Φ.map Pred.lift) (R.map (Ty.shiftV 1 0))
                n (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L)) ∧
            (Ty.Declared P C Γ b) ∧
            Ty.LeQ P Γ Φ b T ∧ Eff.Covers Γ Φ outEff ε
  | .escape v =>
      ∃ r a ε,
            (R = (some r)) ∧
            (HasTypeVQ P B Ψ Q C Γ Φ v r) ∧
            (Ty.Annotation P C Γ a) ∧
            Ty.LeQ P Γ Φ a T ∧ Eff.Covers Γ Φ outEff ε
  | .app f ws =>
      (∃ ns ps r e, HasTypeVQ P B Ψ Q C Γ Φ f (.fn ns ps r e) ∧
            HasTypeVsQ P B Ψ Q C Γ Φ ws ps ∧ Ty.LeQ P Γ Φ r T ∧ Eff.Covers Γ Φ outEff e) ∨
          (∃ t r e, HasTypeVQ P B Ψ Q C Γ Φ f (.dependentFn t) ∧
            HasTypeTelArgsQ P B Ψ Q C Γ Φ ws t r e ∧ Ty.LeQ P Γ Φ r T ∧ Eff.Covers Γ Φ outEff e)
  | .ret v => HasTypeVQ P B Ψ Q C Γ Φ v T
  | .ite v m n => ∀ b : Bool, ∃ t,
      HasTypeVQ P B Ψ Q C Γ Φ v (.base .boolean) ∧ v.toTerm? = some t ∧
      HasTypeCQ P B Ψ Q C Γ (boolCond t b :: Φ) R (if b then m else n) T outEff L
  | .resume _ _ => False

private theorem resume_form {P B Ψ Q C Γ Φ R code T E L f v}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T E L) (hc : code = .resume f v) :
    (∃ i, f = .var i) ∨ (∃ l, f = .loc l) := by
  match h with
  | .C_Resume .. | .C_ResumeNorm .. => cases hc; exact Or.inl ⟨_,rfl⟩
  | .C_ResumeL .. | .C_ResumeLNorm .. => cases hc; exact Or.inr ⟨_,rfl⟩
  | .C_Sub h .. | .C_Eff h .. | .C_Normal h => exact resume_form h hc
  | .C_Return .. | .C_BuilderLet .. | .C_BuilderOp .. | .C_Let .. | .C_App .. |
      .C_DependentApp .. | .C_If .. | .C_Match .. | .C_Lazy .. | .C_Escape .. |
      .C_Use .. | .C_Handle .. | .C_Handle_Fail .. | .C_Meth .. | .C_External .. |
      .C_IssuePathBases .. | .C_CheckAt .. => cases hc

/-- 任意のrawな導出から直接の開始入力を取り出す。形成条件は追加しない。 -/
theorem HasTypeCQ.inputs {P B Ψ Q C Γ Φ R code T E L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R code T E L) :
    code.Inputs P B Ψ Q C Γ Φ R T E L := by
  cases code with
  | builderLet => exact h.inv_builderLet rfl
  | builderOp => exact h.inv_builderOp rfl
  | «match» => exact h.inv_match rfl
  | lazyC => exact h.inv_lazy rfl
  | use => exact h.inv_use rfl
  | handle => exact h.inv_handle rfl
  | meth => exact h.inv_meth rfl
  | externalCall => exact h.inv_external rfl
  | issuePathBases => exact h.inv_issuePathBases rfl
  | checkAt => exact h.inv_checkAt rfl
  | letIn => exact h.inv_let rfl
  | escape => exact h.inv_escape rfl
  | app => exact h.inv_app rfl
  | ret => exact h.ret_value rfl
  | ite => exact fun b => h.ite_branch rfl b
  | resume f v =>
    rcases resume_form h rfl with ⟨i,rfl⟩ | ⟨l,rfl⟩
    · exact h.inv_resumeVar rfl
    · exact h.inv_resumeL rfl

end
end Benitoite.Release.Refinement
