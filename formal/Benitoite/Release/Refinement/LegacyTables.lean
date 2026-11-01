import Benitoite.Release.Refinement.LegacyRegularity
import Benitoite.Release.WellFormed

/-! # 旧表との対応と構成子の形成 -/
namespace Benitoite.Release.Refinement
noncomputable section

structure LegacyPrimSignature (s0 : Benitoite.Release.PrimSig) (s : PrimSig) : Prop where
  constraints : s.tparams.map TParamDecl.constraints = s0.tparams
  neffs : s.neffs = s0.neffs
  names : s.names = s0.names
  params : s.params = embedParameters s0.params
  ret : s.ret = (embedTy s0.ret).shiftV s0.params.length 0
  eff : s.eff = (embedEff s0.eff).shiftV s0.params.length 0
  kind : s.kind = embedPrimKind s0.kind
  opEff : s.opEff = s0.opEff
  rkinds : s.rkinds = s0.rkinds
  shape : s.shape = s0.shape
  admits : ∀ C ts, s0.admits C ts → s.admits C (Ty.normTys (embedTys ts))
  operationKinds : s.opEff ≠ none →
    TypeCtx.kinds s.tparams = List.replicate s.tparams.length .value

/-- 新型付けや遷移の結論ではなく、表の各位置の対応を読む。 -/
structure LegacyTables (K : DeclarationKinds) (P0 : Benitoite.Release.Program)
    (B0 : Benitoite.Release.Builtins) (B : Builtins) : Prop where
  primitives : ∀ b s0, B0.sig b = some s0 → ∃ s, B.sig b = some s ∧ LegacyPrimSignature s0 s
  sat : ∀ C a p, B0.sat C a p → B.sat C (embedTy a).norm p
  resources : B.isResource = B0.isResource
  effects : B.effects = B0.effects
  refGet : B.refGet = B0.refGet
  refSet : B.refSet = B0.refSet
  effKind : B.effKind = B0.effKind
  valKind : B.valKind = B0.valKind
  valContent : ∀ o, B.valContent o = (B0.valContent o).map embedTy
  ranges : ∀ b rs, B0.admitsR b rs → B.admitsR b (rs.map embedRange)
  constructorArity : ∀ c cd c' cd', P0.cons c = some cd → P0.cons c' = some cd' →
    cd.data = cd'.data → cd.ntys = cd'.ntys
  constructorFields : ∀ c cd, P0.cons c = some cd → ∀ a ∈ cd.args,
    Ty.Annotation (embedProgramWithKinds K P0) (List.replicate cd.ntys TypeCtx.valueParam) [] (embedTy a) ∧
    Ty.HasKind (embedProgramWithKinds K P0) (List.replicate cd.ntys .value) (embedTy a) .value
  constructorScope : ∀ c cd, P0.cons c = some cd → ∀ a ∈ cd.args,
    (embedTy a).SourceScoped 0 cd.ntys 0 0

end
end Benitoite.Release.Refinement
