import Benitoite.Release.Refinement.BuiltinTypingTransport

/-! # 同じ宣言表の応答入力・carrier・モデル条件の移送 -/
namespace Benitoite.Release.Refinement

theorem Builtins.TypingFieldsEq.symm {B B'} (h : Builtins.TypingFieldsEq B B') :
    Builtins.TypingFieldsEq B' B :=
  ⟨h.sig.symm,h.sat.symm,h.ranges.symm,h.resources.symm,h.kinds.symm,h.content.symm,h.effects.symm⟩

mutual
  theorem ExternalCarrier.of_fields {P B B' Ψ v a} (fields : Builtins.TypingFieldsEq B B')
      (typed : ExternalCarrier P B Ψ v a) : ExternalCarrier P B' Ψ v a := by
    match typed with
    | .scalar h => exact .scalar (h.of_fields fields)
    | .bytes h => exact .bytes (h.of_fields fields)
    | .handle h => exact .handle (h.of_fields fields)
    | .list h ann => exact .list (h.of_fields fields) ann
    | .map ks vs length sat a b => exact .map (ks.of_fields fields) (vs.of_fields fields) length (fields.sat ▸ sat) a b
    | .set vs sat a => exact .set (vs.of_fields fields) (fields.sat ▸ sat) a
    | .data lookup length kinds wf args ann => exact .data lookup length kinds wf (args.of_fields fields) ann
    | .refined h ann => exact .refined (h.of_fields fields) ann
  theorem ExternalCarrierEach.of_fields {P B B' Ψ vs a} (fields : Builtins.TypingFieldsEq B B')
      (typed : ExternalCarrierEach P B Ψ vs a) : ExternalCarrierEach P B' Ψ vs a := by
    match typed with
    | .nil => exact .nil
    | .cons h hs => exact .cons (h.of_fields fields) (hs.of_fields fields)
  theorem ExternalCarrierFields.of_fields {P B B' Ψ vs as} (fields : Builtins.TypingFieldsEq B B')
      (typed : ExternalCarrierFields P B Ψ vs as) : ExternalCarrierFields P B' Ψ vs as := by
    match typed with
    | .nil => exact .nil
    | .cons h hs => exact .cons (h.of_fields fields) (hs.of_fields fields)
end

theorem Outcome.Typed.of_fields {P B B' Ψ out a} (fields : Builtins.TypingFieldsEq B B')
    (typed : Outcome.Typed P B Ψ out a) : Outcome.Typed P B' Ψ out a := by
  cases out with
  | val v => exact ⟨typed.1.of_fields fields,typed.2⟩
  | err _ | exit _ => trivial

theorem Outcome.Carrier.of_fields {P B B' Ψ out a} (fields : Builtins.TypingFieldsEq B B')
    (typed : Outcome.Carrier P B Ψ out a) : Outcome.Carrier P B' Ψ out a := by
  cases out with
  | val v => exact ⟨typed.1.of_fields fields,typed.2⟩
  | err _ | exit _ => trivial

theorem ExternalArgs.of_fields {P B B' Ψ d ts vs a e} (fields : Builtins.TypingFieldsEq B B')
    (typed : ExternalArgs P B Ψ d ts vs a e) : ExternalArgs P B' Ψ d ts vs a e :=
  {typed with admissible := typed.admissible.of_fields fields,
              arguments := typed.arguments.of_fields fields}

theorem BuiltinArgs.of_fields {P B B' Ψ b s ts es rs vs a e} (fields : Builtins.TypingFieldsEq B B')
    (typed : BuiltinArgs P B Ψ b s ts es rs vs a e) : BuiltinArgs P B' Ψ b s ts es rs vs a e :=
  {typed with ranges := typed.ranges.of_fields fields, arguments := typed.arguments.of_fields fields}

private theorem builtin_args_iff {P B B' Ψ b s ts es rs vs a e} (fields : Builtins.TypingFieldsEq B B') :
    BuiltinArgs P B Ψ b s ts es rs vs a e ↔ BuiltinArgs P B' Ψ b s ts es rs vs a e :=
  ⟨BuiltinArgs.of_fields fields,BuiltinArgs.of_fields fields.symm⟩

private theorem outcome_typed_iff {P B B' Ψ out a} (fields : Builtins.TypingFieldsEq B B') :
    Outcome.Typed P B Ψ out a ↔ Outcome.Typed P B' Ψ out a :=
  ⟨Outcome.Typed.of_fields fields,Outcome.Typed.of_fields fields.symm⟩

private theorem images_iff {P B B' Ψ Q C Γ Δ Ξ ν} (fields : Builtins.TypingFieldsEq B B') :
    TypedValueImages P B Ψ Q C Γ Δ Ξ ν ↔ TypedValueImages P B' Ψ Q C Γ Δ Ξ ν := by
  constructor <;> intro h i a hi ha
  · exact (h i a hi ha).of_fields fields
  · exact (h i a hi ha).of_fields fields.symm

theorem Builtins.SubstitutionAssumptions.of_fields {P B B'} (fields : Builtins.TypingFieldsEq B B')
    (h : Builtins.SubstitutionAssumptions P B) : Builtins.SubstitutionAssumptions P B' where
  sat_rename := by simpa only [←fields.sat] using h.sat_rename
  admits_rename := by simpa only [←fields.sig] using h.admits_rename
  sat_values := by simpa only [←fields.sat,←images_iff fields] using h.sat_values
  admits_values := by simpa only [←fields.sig,←images_iff fields] using h.admits_values
  sat_renameTypes := by simpa only [←fields.sat] using h.sat_renameTypes
  admits_renameTypes := by simpa only [←fields.sig] using h.admits_renameTypes
  sat_subst := by simpa only [←fields.sat,SatAll] using h.sat_subst
  admits_subst := by simpa only [←fields.sig,SatAll,←fields.sat] using h.admits_subst

theorem ModelScopeConditions.of_responses {P B B'} (fields : Builtins.TypingFieldsEq B B')
    (delta : B.delta = B'.delta) (io : B.ioResponse = B'.ioResponse)
    (get : B.refGet = B'.refGet) (set : B.refSet = B'.refSet)
    (kind : B.effKind = B'.effKind) (h : ModelScopeConditions P B) : ModelScopeConditions P B' where
  toSubstitutionAssumptions := h.toSubstitutionAssumptions.of_fields fields
  delta_typed := by
    simpa only [←fields.sig,←delta,←builtin_args_iff fields,←outcome_typed_iff fields] using h.delta_typed
  io_typed := by
    simpa only [←fields.sig,←io,←builtin_args_iff fields,←outcome_typed_iff fields] using h.io_typed
  io_kind := by simpa only [←fields.sig,←io,←builtin_args_iff fields] using h.io_kind
  io_exists := by simpa only [←fields.sig,←io,←builtin_args_iff fields] using h.io_exists
  io_target := by simpa only [←fields.sig,←io,←builtin_args_iff fields] using h.io_target
  sig_scoped := by simpa only [←fields.sig] using h.sig_scoped
  sat_unconstrained := by simpa only [←fields.sat] using h.sat_unconstrained
  admits_sat := by simpa only [←fields.sig,SatAll,←fields.sat] using h.admits_sat
  pathBases_shape := by
    intro b s lookup shape
    have source := h.pathBases_shape b s (fields.sig.symm ▸ lookup) shape
    exact {source with membership := by simpa only [←fields.effects] using source.membership}
  io_op := by simpa only [←fields.sig,Builtins.ShapeOk,←fields.effects,←kind,←fields.kinds] using h.io_op
  opEff_io := by simpa only [←fields.sig] using h.opEff_io
  effect_ops := by simpa only [←fields.sig,←fields.effects] using h.effect_ops
  state_effect := by simpa only [←fields.effects] using h.state_effect
  ref_get := by simpa only [←fields.sig,←get] using h.ref_get
  ref_set := by simpa only [←fields.sig,←set] using h.ref_set
  store_shape := by simpa only [←fields.sig] using h.store_shape
  store_admits := by simpa only [←fields.sig] using h.store_admits
end Benitoite.Release.Refinement
