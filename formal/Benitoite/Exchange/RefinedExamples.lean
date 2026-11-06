import Benitoite.Exchange.Convert
import Benitoite.Exchange.FormationTypes

/-! # 篩・依存列・証明書の交換の例

構文の読者と変換の境界で、篩と束縛の位置を保持し、未知の欄と証明書の重複する鍵を拒否する。
-/
namespace Benitoite.Exchange.RefinedExamples
open Lean Benitoite.Release.Refinement

private def dependentType : Ty :=
  .dependentFn ["limit", "value"] [.base "Integer", .refined (.base "Integer") (.le (.var 0) (.var 1))]
    (.refined (.base "Integer") (.le (.var 0) (.var 2))) []

#guard match (fromJson? (toJson dependentType) : Except String Ty) with
  | .ok actual => actual == dependentType
  | .error _ => false
#guard match dependentType.toRelease >>= fromTy [] with
  | .ok actual => actual == dependentType
  | .error _ => false

#guard match FormationTypes.formedTy [] dependentType with
  | .ok ⟨.dependentFn (.param "limit" (.base .integer)
      (.param "value" (.refined (.base .integer) (.le (.var 0) (.var 1)))
        (.done (.refined (.base .integer) (.le (.var 0) (.var 2))) _))), _⟩ => true
  | _ => false

private def nestedFailure : Eff := [.fail (.fn [] [] (.base "Integer") [.rho 0])]
#guard !(FormationTypes.formedEff [] nestedFailure).isOk
#guard (FormationTypes.formedEff [.rho 0] nestedFailure).isOk

private def scopedType : Ty := .scoped "Scope.PathIn" .path (.fixed (.based .work (.tree ["data"])))
#guard match scopedType.toRelease with
  | .ok (.scoped "Scope.PathIn" .path (.fixed (.based .work (.tree ["data"])))) => true
  | _ => false

#guard match FormationTypes.formedTys [] [.refined (.base "Integer8") .truth, scopedType] with
  | .ok ⟨[.refined (.base .integer8) .truth, .scoped "Scope.PathIn" .path _], _⟩ => true
  | _ => false

private def header : Header := {
  tparams := [(false, false)], tparamKinds := [.constructor 1], neffs := 0, effParams := [],
  names := ["value"], params := [.base "Integer"], ret := .base "Integer", eff := [],
  rangeParams := [.host], proofSteps := some 17 }
#guard header.typeContext.isOk
#guard !(({header with tparamKinds := []} : Header).typeContext).isOk
#guard (validateSyntaxFields (toJson header)).isOk
private def extraHeader : Json := match toJson header with
  | .obj xs => Json.mkObj (xs.toArray.toList ++ [("extra", Json.null)])
  | j => j
#guard !(validateSyntaxFields extraHeader).isOk

#guard (validateIntegerConstants (toJson (Benitoite.Release.Refinement.Term.integer 9223372036854775808))).isOk
#guard !(validateIntegerConstants (toJson (Expr.literal (.integer 9223372036854775808)))).isOk

#guard ((fromHeader [] [] 0 [] [] (.base .unit) Benitoite.Release.Refinement.Eff.empty [.host]).map (·.rangeParams)).toOption == some [Benitoite.Scope.Domain.Kind.host]

private def method : SurfaceDef := {
  package := "root", coverageView := [], header := {header with rangeParams := [], proofSteps := none},
  body := .empty, dictParams := [], implementation := some "Implementation", method := some "method", supers := [] }
#guard method.toSurface.isOk
#guard !(({method with header := {method.header with rangeParams := [.host]}} : SurfaceDef).toSurface).isOk
#guard !(({method with header := {method.header with proofSteps := some 17}} : SurfaceDef).toSurface).isOk

private def certificate : LogicCertificateEntry := ⟨[0, 0, 1, 0], 0, .use 0, []⟩
#guard (LogicCertificateEntry.validate [certificate]).isOk
#guard !(LogicCertificateEntry.validate [certificate, certificate]).isOk
#guard (LogicCertificateEntry.validate [certificate, {certificate with index := 1}]).isOk

#guard match (Expr.externalName 3 []).toSurface with
  | .ok (.externalName (.mk 3) []) => true
  | _ => false
#guard match (Ty.external 2 []).toRelease with
  | .ok (.external (.mk 2) []) => true
  | _ => false

end Benitoite.Exchange.RefinedExamples
