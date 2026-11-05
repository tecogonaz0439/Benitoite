import Benitoite.Release.Refinement.StandardModelPrimitiveLookup
import Benitoite.Release.Refinement.ExternalModelTransport

/-! # 既存の応答を参照する合成表の骨格 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section

/-- 本体や応答の算法を複製せず、選ばれた元の応答を読む。 -/
def delta (b : String) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  (primitive b).bind (fun row => row.provider.delta b ts es rs ws)

def ioResponse (b : String) (ts : List Ty) (es : List Eff) (ws : List Val)
    (out : Outcome) (obs : List Benitoite.Scope.Domain.Target) : Prop :=
  ∃ row, primitive b = some row ∧ row.provider.ioResponse b ts es ws out obs

/-- 全操作の有限の所属は、採用した署名のopEffと同じ表から求める。 -/
def effects (label : Benitoite.Release.EffName) : Option (List String) :=
  if label = stateEff then some [] else
  let rows := Primitive.all.filter (fun row => row.signature.opEff == some label)
  if rows.isEmpty then none else some (rows.map Primitive.name)

def baseBuiltins : Builtins := {signatureBase with
  sig := signature
  delta := delta
  ioResponse := ioResponse
  effects := effects}

def builtins (P : Program) : Builtins := ExternalModel.builtins P baseBuiltins
  (ResourceRelease.response baseBuiltins.isResource)

/-- 組込みの全lookupは、名前と署名を持つ台帳へ双方向に対応する。 -/
theorem builtins_lookup_iff (P : Program) (name : String) (s : PrimSig) :
    (builtins P).sig name = some s ↔ ∃ row ∈ Primitive.all, name = row.name ∧ s = row.signature :=
  signatures_iff name s

/-- 資源の名前は証拠を持つFile.Handleだけである。 -/
theorem resource_iff (P : Program) (name : String) :
    (builtins P).isResource name = true ↔ name = "File.Handle" := by
  change (name == "File.Handle") = true ↔ name = "File.Handle"
  exact beq_iff_eq

/-- getの許容述語を簡約すると、通常helperが読む同じ署名になる。 -/
theorem get_signature (P : Program) : (builtins P).sig "List.get" = some StandardBodies.listGetSig := by
  change some (StandardListRemainingResponse.API.signature signatureBase.sat .get) = some StandardBodies.listGetSig
  simp [StandardListRemainingResponse.API.signature,StandardListRemainingResponse.API.constraint,
    StandardListRemainingResponse.API.names,StandardListRemainingResponse.API.inputs,
    StandardListRemainingResponse.API.result,StandardBodies.listGetSig]
  rfl

/-- 生の外部応答の三条件は、この同じ合成表の上でも成り立つ。 -/
theorem external_assumptions (P : Program) : Builtins.ExternalAssumptions P (builtins P) :=
  ExternalModel.external_assumptions P _ _
/-- 任意の宣言表と生の入力について、同じ表が選んだ外部応答を読む。 -/
example (P : Program) (f : ExternalFunctionId) (ts : List Ty) (ws : List Val) :
    (builtins P).externalResponse f ts ws ((builtins P).selectExternal f ts ws).1
      ((builtins P).selectExternal f ts ws).2 :=
  Builtins.selectExternal_response (ExternalModel.response_exists P baseBuiltins f ts ws)

/-- 通常側と精密側の再帰を分け、元のtelを両方保つ。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    (program externals).defs "%List.mapFrom.ordinary" = some Body.b129.definition ∧
    (program externals).defs "%List.mapFrom.refined" = some Body.b101.definition ∧
    Body.b129.definition.tel = Body.b129.original.tel ∧
    Body.b101.definition.tel = Body.b101.original.tel ∧
    Body.b129.definition = FunctionNames.definition (FunctionNames.rename false) Body.b129.original ∧
    Body.b101.definition = FunctionNames.definition (FunctionNames.rename true) Body.b101.original ∧
    Body.b129.key = FunctionNames.rename false "List.mapFrom" ∧
    Body.b101.key = FunctionNames.rename true "List.mapFrom" :=
  ⟨body_lookup externals .b129,body_lookup externals .b101,Body.tel .b129,Body.tel .b101,
    Body.correspondence .b129,Body.correspondence .b101,
    Body.key_correspondence .b129,Body.key_correspondence .b101⟩

example (P : Program) :
    (∃ row ∈ Primitive.all, "List.get" = row.name ∧ StandardBodies.listGetSig = row.signature) ∧
    (builtins P).isResource "File.Handle" = true :=
  ⟨(builtins_lookup_iff P _ _).mp (get_signature P),(resource_iff P _).mpr rfl⟩

example {P Ψ f d ts ws a e} (hw : P.ExternalWF) (lookup : P.externalFunction f = some d)
    (args : ExternalArgs P (builtins P) Ψ d ts ws a e) :
    (builtins P).externalResponse f ts ws ((builtins P).selectExternal f ts ws).1
      ((builtins P).selectExternal f ts ws).2 ∧ ((builtins P).selectExternal f ts ws).2 = [] := by
  have h := external_assumptions P
  have selected := Builtins.selectExternal_response (h.external_exists _ _ _ _ _ _ _ hw lookup args)
  exact ⟨selected,h.external_no_targets _ _ _ _ _ _ _ _ _ hw lookup args selected⟩

end
end Benitoite.Release.Refinement.StandardModel
