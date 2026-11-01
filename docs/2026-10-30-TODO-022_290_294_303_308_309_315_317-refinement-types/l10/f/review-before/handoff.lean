import Lean
import Benitoite

/-! 未実装の埋め込みの型を検査する。以下は命題の定義であり、証明ではない。 -/
namespace Benitoite.Release.Refinement.L10FHandoff
noncomputable section

def embedHasTypeVQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {v : Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValueInput K P0 B0 B Δ v →
      LegacyOutputInput K P0 B0 B (.value Δ.kinds Ψ Q C Γ v a) →
      Benitoite.Release.HasTypeVQ P0 B0 Ψ Q C Γ v a →
      HasTypeVQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedVal v) (embedTy a)

def embedHasTypeVsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {ts : List Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.values Δ.kinds Ψ Q C Γ vs ts) →
      Benitoite.Release.HasTypeVsQ P0 B0 Ψ Q C Γ vs ts →
      HasTypeVsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedVals vs) (embedTys ts)

def embedHasTypeEachQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {vs : List Benitoite.Release.Val} {a : Benitoite.Release.Ty} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyValuesInput K P0 B0 B Δ vs →
      LegacyOutputInput K P0 B0 B (.each Δ.kinds Ψ Q C Γ vs a) →
      Benitoite.Release.HasTypeEachQ P0 B0 Ψ Q C Γ vs a →
      HasTypeEachQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedVals vs) (embedTy a)

def embedHasTypeCQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {m : Benitoite.Release.Comp}
      {a : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyCompInput K P0 B0 B Δ m →
      LegacyOutputInput K P0 B0 B (.comp Δ.kinds Ψ Q C Γ R m a e L) →
      Benitoite.Release.HasTypeCQ P0 B0 Ψ Q C Γ R m a e L →
      HasTypeCQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (R.map embedTy)
        (embedComp m) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeArmsQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {xs : List Benitoite.Release.Arm}
      {a b : Benitoite.Release.Ty} {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyArmsInput K P0 B0 B Δ xs →
      LegacyOutputInput K P0 B0 B (.arms Δ.kinds Ψ Q C Γ R xs a b e L) →
      Benitoite.Release.HasTypeArmsQ P0 B0 Ψ Q C Γ R xs a b e L →
      HasTypeArmsQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (R.map embedTy) none
        (embedArms xs) (embedTy a) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasTypeClausesQ : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {R : Option Benitoite.Release.Ty} {eb : Benitoite.Release.Eff}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.clauses Δ.kinds Ψ Q C Γ R eb cs a e L) →
      Benitoite.Release.HasTypeClausesQ P0 B0 Ψ Q C Γ R eb cs a e L →
      HasTypeClausesQ (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (R.map embedTy) (embedEff eb)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedHasFailureClause : Prop :=
    ∀ {P0 : Benitoite.Release.Program} {B0 : Benitoite.Release.Builtins} {B : Builtins}
      {Ψ : Benitoite.Release.StoreTy} {Q : Benitoite.Release.NoFailCtx}
      {C : List Benitoite.Release.TParam} {Γ : List (Option Benitoite.Release.Ty)}
      {E : Benitoite.Release.Ty} {R : Option Benitoite.Release.Ty}
      {cs : List Benitoite.Release.Clause} {a : Benitoite.Release.Ty}
      {e : Benitoite.Release.Eff} {L : Benitoite.Release.LocalCtx} (K : DeclarationKinds) (Δ : LegacyInputCtx),
      K.WF P0 → LegacyTables K P0 B0 B →
      LegacyContextInput K P0 Ψ C Γ Δ →
      LegacyClausesInput K P0 B0 B Δ cs →
      LegacyOutputInput K P0 B0 B (.failure Δ.kinds Ψ Q C Γ E R cs a e L) →
      Benitoite.Release.HasFailureClause P0 B0 Ψ Q C Γ E R cs a e L →
      HasFailureClause (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q C
        (Γ.map (Option.map embedTy)) [] (embedTy E) (R.map embedTy)
        (embedClauses cs) (embedTy a) (embedEff e) (L.map (Option.map embedBuilderKind))

def embedStateTyE
    (LegacyStateInput : DeclarationKinds → Benitoite.Release.Program →
      Benitoite.Release.Builtins → Builtins → PathEnv → Benitoite.Release.State → Prop) : Prop :=
    ∀ {P0 B0 B σ Eb s} (K : DeclarationKinds),
      K.WF P0 → LegacyTables K P0 B0 B → σ.Valid →
      LegacyStateInput K P0 B0 B σ s → Benitoite.Release.StateTyE P0 B0 Eb s →
      StateTyE (embedProgramWithKinds K P0) B σ (embedEff Eb) (embedState s)

/-- P0.defs f = some d の関数本体。 -/
def functionBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (f : FunName) (d : Benitoite.Release.Def) : Prop :=
  LegacyOutputInput K P0 B0 B (.comp (K.functionParams f) Benitoite.Release.StoreTy.empty
    (Benitoite.Release.Qsig d.params d.ret d.eff) d.tparams (Benitoite.Release.binds d.params)
    (some d.ret) d.body d.ret d.eff [])

/-- P0.impls i = some id、クラスとメソッドの lookup、id.methods m = some body の本体。 -/
def methodBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (m : MethName) (ms : Benitoite.Release.MethSig) (body : Benitoite.Release.Comp) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.comp (K.methodParams id.cls m ++ List.replicate id.tparams.length .value)
      Benitoite.Release.StoreTy.empty (Benitoite.Release.Qsig ms.params ms.ret ms.eff)
      (ms.tparams ++ id.tparams)
      (Benitoite.Release.binds (id.dictTys.map (Benitoite.Release.Ty.shift ms.tparams.length 0) ++
        ms.params.map (id.methTy ms)))
      (some (id.methTy ms ms.ret)) body (id.methTy ms ms.ret)
      (Benitoite.Release.Eff.substAt ms.tparams.length [id.target] [] ms.eff) [])

/-- s ∈ cd.supers と id.supers s = some value の上位の辞書。 -/
def superBodyInput (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) (id : Benitoite.Release.ImplDecl)
    (s : ClassName) (value : Benitoite.Release.Val) : Prop :=
  LegacyOutputInput K P0 B0 B
    (.value (List.replicate id.tparams.length .value) Benitoite.Release.StoreTy.empty Benitoite.Release.Qempty
      id.tparams (Benitoite.Release.binds id.dictTys) value (.dict s id.target))


def declarationBodyInputs (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop :=
  (∀ f d, P0.defs f = some d → functionBodyInput K P0 B0 B f d) ∧
  (∀ i id cd m ms body, P0.impls i = some id → P0.classes id.cls = some cd →
    cd.methods m = some ms → id.methods m = some body →
    methodBodyInput K P0 B0 B id m ms body) ∧
  (∀ i id cd s value, P0.impls i = some id → P0.classes id.cls = some cd →
    s ∈ cd.supers → id.supers s = some value → superBodyInput K P0 B0 B id s value)

end
end Benitoite.Release.Refinement.L10FHandoff

#check @Benitoite.Release.Refinement.LegacyTables
#check @Benitoite.Release.Refinement.LegacyPrimSignature
#check @Benitoite.Release.Refinement.LegacyInputCtx
#check @Benitoite.Release.Refinement.DeclarationKinds.WF
#check @Benitoite.Release.Refinement.LegacyTypeInput
#check @Benitoite.Release.Refinement.LegacyTypesInput
#check @Benitoite.Release.Refinement.LegacyRowsInput
#check @Benitoite.Release.Refinement.LegacyContextInput
#check @Benitoite.Release.Refinement.LegacyDeclarationsInput
#check @Benitoite.Release.Refinement.LegacyNodeContext
#check @Benitoite.Release.Refinement.LegacyNodeTypes
#check @Benitoite.Release.Refinement.LegacyNodeLocal
#check @Benitoite.Release.Refinement.LegacyNodeRegular
#check @Benitoite.Release.Refinement.LegacyRule.old
#check @Benitoite.Release.Refinement.LegacyOutputInput.old
#check @Benitoite.Release.Refinement.LegacyOutputInput.regular
#check @Benitoite.Release.Refinement.LegacyTables.dataArity
#check @Benitoite.Release.Refinement.LegacyTables.constructor_scoped
#check @Benitoite.Release.Refinement.LegacyTables.varianceValid
#check @Benitoite.Release.Refinement.LegacyClausesInput.signature_wf
#check @Benitoite.Release.Refinement.legacy_signatureInstance
#check @Benitoite.Release.Refinement.embed_const
#check @Benitoite.Release.Refinement.embed_bytes
#check @Benitoite.Release.Refinement.embed_checked
#check @Benitoite.Release.Refinement.embed_checkedRequest
#check @Benitoite.Release.Refinement.embed_normal_eq_iff
#check @Benitoite.Release.Refinement.SignatureInstance.typeScope
#check @Benitoite.Release.Refinement.SignatureInstance.method_typeScope
#check @Benitoite.Release.Refinement.HasTypeVQ.op_typeScope
#check @Benitoite.Release.Refinement.HasTypeVQ.dict_typeScope
#check @Benitoite.Release.Refinement.HasTypeVQ.raise_typeScope
#check @Benitoite.Release.Refinement.HasTypeVQ.raise_subst_wf
#check @Benitoite.Release.Refinement.HasTypeVQ.raise_subst_le
#check @Benitoite.Release.Refinement.HasTypeCQ.method_body_typeScope
#check @Benitoite.Release.Refinement.LegacyTypesInput.iff_of_notCont
#check @Benitoite.Release.Refinement.notCont_of_legacyVarsInList
#check @Benitoite.Release.Refinement.LocalCtx.Shift.empty
