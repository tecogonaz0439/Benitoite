import Benitoite.Release.Refinement.LegacyClauseEmbedding

namespace Benitoite.Release.Refinement
noncomputable section

theorem LegacyRule.embed_comp {K P0 B0 B κ Ψ Q C Γ R m a e L children}
    (rule : LegacyRule K P0 B0 (.comp κ Ψ Q C Γ R m a e L) children)
    (kinds : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R m a e L))
    (inputs : ∀ child ∈ children, LegacyOutputInput K P0 B0 B child)
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L) := by
  cases rule with
  | C_Return => exact LegacyCompCases.return_case (ih _ (by simp))
  | @C_Let _ _ _ _ _ _ _ m n mid => exact LegacyCompCases.let_case (a := mid) reg (ih _ (by simp)) (ih _ (by simp))
  | @C_App _ _ _ _ _ _ _ f args ns as => exact LegacyCompCases.app_case (ns := ns) (as := as) (ih _ (by simp)) (ih _ (by simp))
  | @C_Meth _ _ _ _ _ _ _ v cl τ cd m ms ss es ws lookup method names sat scope rows source args =>
    exact LegacyCompCases.meth_case kinds tables reg lookup method names sat scope rows source args
      (inputs (.value κ Ψ Q C Γ v (.dict cl τ)) (by simp)).regular
      (inputs (.values κ Ψ Q C Γ ws (ms.params.map (Benitoite.Release.Ty.subst (ss ++ [τ]) es))) (by simp)).regular
      (ih _ (by simp)) (ih _ (by simp))
  | C_If => exact LegacyCompCases.if_case (ih _ (by simp)) (ih _ (by simp)) (ih _ (by simp))
  | @C_Match _ _ _ _ _ _ _ v arms a b eff coverage =>
    exact LegacyCompCases.match_case tables
      (inputs (.value κ Ψ Q C Γ v a) (by simp)).regular coverage (ih _ (by simp)) (ih _ (by simp))
  | C_Lazy => exact LegacyCompCases.lazy_case reg (ih _ (by simp))
  | C_Escape _ => exact LegacyCompCases.escape_case reg (ih _ (by simp))
  | C_Use resource state => exact LegacyCompCases.use_case tables resource state (ih _ (by simp)) (ih _ (by simp))
  | C_BuilderLet _ => exact LegacyCompCases.builderLet_case reg (ih _ (by simp))
  | C_BuilderOp _ ref => exact LegacyCompCases.builderOp_case reg ref (ih _ (by simp))
  | C_Handle sub => exact LegacyCompCases.handle_case tables reg.2.1.2 sub (ih _ (by simp)) (ih _ (by simp))
  | C_Handle_Fail sub nf => exact LegacyCompCases.handleFail_case sub nf (ih _ (by simp)) (ih _ (by simp))
  | C_Resume lookup => exact LegacyCompCases.resume_case reg lookup (ih _ (by simp))
  | C_ResumeL lookup => exact LegacyCompCases.resumeL_case reg lookup (ih _ (by simp))
  | C_Sub sub eff _ => exact LegacyCompCases.sub_case reg sub eff (ih _ (by simp))
  | C_Eff eff => exact LegacyCompCases.eff_case eff (ih _ (by simp))

theorem LegacyRule.embed_arms {K P0 B0 B κ Ψ Q C Γ R xs a b e L children}
    (rule : LegacyRule K P0 B0 (.arms κ Ψ Q C Γ R xs a b e L) children)
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.arms κ Ψ Q C Γ R xs a b e L))
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R xs a b e L) := by
  cases rule with
  | Arms_nil _ => exact LegacyArmCases.nil_case reg
  | Arms_plain pat => exact LegacyArmCases.plain_case tables pat (ih _ (by simp)) (ih _ (by simp))
  | Arms_guarded pat => exact LegacyArmCases.guarded_case tables pat (ih _ (by simp)) (ih _ (by simp)) (ih _ (by simp))

theorem LegacyRule.embed_clauses {K P0 B0 B κ Ψ Q C Γ R eb cs a e L children}
    (rule : LegacyRule K P0 B0 (.clauses κ Ψ Q C Γ R eb cs a e L) children)
    (tables : LegacyTables K P0 B0 B)
    (reg : LegacyNodeRegular K P0 B0 B (.clauses κ Ψ Q C Γ R eb cs a e L))
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.clauses κ Ψ Q C Γ R eb cs a e L) := by
  cases rule with
  | Clauses_nil => exact LegacyClauseCases.nil_case
  | Clauses_cons sig names arity ntys _ =>
    exact LegacyClauseCases.cons_case tables reg sig names arity ntys (ih _ (by simp)) (ih _ (by simp))

theorem LegacyRule.embed_failure {K P0 B0 B κ Ψ Q C Γ E R cs a e L children}
    (rule : LegacyRule K P0 B0 (.failure κ Ψ Q C Γ E R cs a e L) children)
    (reg : LegacyNodeRegular K P0 B0 B (.failure κ Ψ Q C Γ E R cs a e L))
    (ih : ∀ child ∈ children, LegacyJudgment.Embedded K P0 B child) :
    LegacyJudgment.Embedded K P0 B (.failure κ Ψ Q C Γ E R cs a e L) := by
  cases rule with
  | Failure_one _ _ _ => exact LegacyClauseCases.failure_case reg (ih _ (by simp))

theorem LegacyOutputInput.embed {K P0 B0 B j}
    (kinds : K.WF P0) (tables : LegacyTables K P0 B0 B)
    (input : LegacyOutputInput K P0 B0 B j) : LegacyJudgment.Embedded K P0 B j := by
  apply input.induct_regular
  intro j children rule reg inputs ih
  cases j with
  | value => exact rule.embed_value kinds tables reg ih
  | values => exact rule.embed_values ih
  | each => exact rule.embed_each ih
  | comp => exact rule.embed_comp kinds tables reg inputs ih
  | arms => exact rule.embed_arms tables reg ih
  | clauses => exact rule.embed_clauses tables reg ih
  | failure => exact rule.embed_failure reg ih

theorem embedHasTypeVQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.value κ Ψ Q C Γ v a) →
      ∀ Φ : List Pred, HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (embedVal v) (embedTy a) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasTypeVQ_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.value κ Ψ Q C Γ v a) →
      HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (embedVal v) (embedTy a) := by
  intro kinds tables input
  exact embedHasTypeVQ K κ kinds tables input []

theorem embedHasTypeVsQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {ts : List Benitoite.Release.Ty} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.values κ Ψ Q C Γ vs ts) →
      ∀ Φ : List Pred, HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTys ts) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasTypeVsQ_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {ts : List Benitoite.Release.Ty} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.values κ Ψ Q C Γ vs ts) →
      HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (embedVals vs) (embedTys ts) := by
  intro kinds tables input
  exact embedHasTypeVsQ K κ kinds tables input []

theorem embedHasTypeEachQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.each κ Ψ Q C Γ vs a) →
      ∀ Φ : List Pred, HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (embedVals vs) (embedTy a) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasTypeEachQ_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.each κ Ψ Q C Γ vs a) →
      HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (embedVals vs) (embedTy a) := by
  intro kinds tables input
  exact embedHasTypeEachQ K κ kinds tables input []

theorem embedHasTypeCQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.comp κ Ψ Q C Γ R m a e L) →
      ∀ Φ : List Pred, HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasTypeCQ_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.comp κ Ψ Q C Γ R m a e L) →
      HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input
  exact embedHasTypeCQ K κ kinds tables input []

theorem embedHasTypeArmsQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {xs : List Benitoite.Release.Arm}
      {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.arms κ Ψ Q C Γ R xs a b e L) →
      ∀ Φ : List Pred, HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) none
        (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasTypeArmsQ_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {xs : List Benitoite.Release.Arm}
      {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.arms κ Ψ Q C Γ R xs a b e L) →
      HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (R.map embedTy) none
        (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input
  exact embedHasTypeArmsQ K κ kinds tables input []

theorem embedHasTypeClausesQ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.clauses κ Ψ Q C Γ R eb cs a e L) →
      ∀ Φ : List Pred, HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (R.map embedTy) (embedEff eb)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasTypeClausesQ_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.clauses κ Ψ Q C Γ R eb cs a e L) →
      HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (R.map embedTy) (embedEff eb)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input
  exact embedHasTypeClausesQ K κ kinds tables input []

theorem embedHasFailureClause {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {E : Benitoite.Release.Ty} {R : Option Benitoite.Release.Ty}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.failure κ Ψ Q C Γ E R cs a e L) →
      ∀ Φ : List Pred, HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) Φ (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input Φ
  exact input.embed kinds tables Φ

theorem embedHasFailureClause_empty {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {E : Benitoite.Release.Ty} {R : Option Benitoite.Release.Ty}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (κ : KindCtx) :
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyOutputInput K P0 B0 B (.failure κ Ψ Q C Γ E R cs a e L) →
      HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q (legacyTypeCtx C κ)
        (Γ.map (Option.map embedTy)) [] (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro kinds tables input
  exact embedHasFailureClause K κ kinds tables input []


end
end Benitoite.Release.Refinement
