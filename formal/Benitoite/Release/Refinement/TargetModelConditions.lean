import Benitoite.Release.Refinement.ConstraintAssumptions

/-! # 対象付きモデルが構成する条件の出力 -/
namespace Benitoite.Release.Refinement
structure ModelScopeConditions (P : Program) (B : Builtins) : Prop extends
    Builtins.SubstitutionAssumptions P B,
    Builtins.ResponseAssumptions P B,
    Builtins.TargetAgreement P B where
  sig_scoped : ∀ b s, B.sig b = some s → PrimSig.Scoped P s
  sat_unconstrained : ∀ t : Ty, t.WF 0 0 0 → B.sat [] t.norm ({} : TParam)
  admits_sat : ∀ b s C ts, B.sig b = some s →
    s.admits (TypeCtx.constraints C) (Ty.normTys ts) →
    SatAll B C ts (s.tparams.map TParamDecl.constraints)
  pathBases_shape : ∀ b s, B.sig b = some s → s.kind = .pathBases →
    s.PathBasesShape B b
  io_op : ∀ b s, B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
    B.ShapeOk b s
  opEff_io : ∀ b s l, B.sig b = some s → s.opEff = some l →
    s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases
  effect_ops : ∀ l bs b, B.effects l = some bs → b ∈ bs →
    ∃ s, B.sig b = some s ∧ (s.kind = .io ∨ s.kind = .exit ∨ s.kind = .pathBases) ∧
      s.opEff = some l
  state_effect : B.effects stateEff = some []
  ref_get : ∃ s, B.sig B.refGet = some s ∧ s.kind = .refGet
  ref_set : ∃ s, B.sig B.refSet = some s ∧ s.kind = .refSet
  store_shape : ∀ b s, B.sig b = some s → s.kind ≠ .pathBases → s.StoreShape
  store_admits : ∀ b s C ts, B.sig b = some s → s.kind ≠ .pure → s.kind ≠ .io →
    s.kind ≠ .exit → s.kind ≠ .pathBases → ts.length = s.tparams.length → s.admits C ts

/-- 同じ表の外部応答と解放の条件だけを合わせ、既存の Core を作る。 -/
theorem ModelScopeConditions.core {P B} (h : ModelScopeConditions P B)
    (external : Builtins.ExternalAssumptions P B)
    (release : ∀ Ψ v o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) →
      B.isResource o = true → ∃ r, B.releaseResponse v r) : Builtins.CoreAssumptions P B where
  toSubstitutionAssumptions := h.toSubstitutionAssumptions
  toExternalAssumptions := external
  toResponseAssumptions := h.toResponseAssumptions
  sig_scoped := h.sig_scoped
  sat_unconstrained := h.sat_unconstrained
  admits_sat := h.admits_sat
  release_exists := release
  pathBases_shape := h.pathBases_shape
  io_op := h.io_op
  opEff_io := h.opEff_io
  effect_ops := h.effect_ops
  state_effect := h.state_effect
  ref_get := h.ref_get
  ref_set := h.ref_set
  store_shape := h.store_shape
  store_admits := h.store_admits

/-- 観測対象の条件は、Core と区別して同じ表について保持する。 -/
example {P B} (h : ModelScopeConditions P B)
    (external : Builtins.ExternalAssumptions P B)
    (release : ∀ Ψ v o, HasTypeV P B Ψ [] [] [] v (.opaque o (.fixed .top)) →
      B.isResource o = true → ∃ r, B.releaseResponse v r) :
    Builtins.CoreAssumptions P B ∧ Builtins.TargetAgreement P B :=
  ⟨h.core external release, h.toTargetAgreement⟩
end Benitoite.Release.Refinement
