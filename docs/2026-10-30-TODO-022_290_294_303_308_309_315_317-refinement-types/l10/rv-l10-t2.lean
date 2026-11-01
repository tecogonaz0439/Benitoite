import Benitoite
open Benitoite Benitoite.Release.Refinement
namespace RVT2
#check @OpDecl.tel
#check @PrimSig.tel
#check @signatureTel
#check @Benitoite.Release.Refinement.StoreTy
noncomputable def DefTel (d : Def) : Tel := signatureTel d.names d.params d.ret d.eff
def DWT (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (d.tparams.map TParamDecl.kind) (.dependentFn (DefTel d)) .value ∧
  Ty.Annotation P (d.tparams.map TParamDecl.constraints) [] (.dependentFn (DefTel d)) ∧
  TelBodyTy P B (fun _ => none) (QTel (DefTel d))
    (d.tparams.map TParamDecl.constraints) [] [] (DefTel d) d.body
#check d_tel
end RVT2
