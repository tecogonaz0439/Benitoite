import Lean
import Benitoite
import Benitoite.Release.Refinement.StandardModelResponse
namespace Benitoite.RefinementSignatureTargets
open Benitoite.Release.Refinement

-- 同じ宣言表・全添字を保つ完成した移送。
#check HasTypeVQ.of_fields
#check HasTypeCQ.of_fields
#check ExternalCarrier.of_fields
#check ExternalCarrierEach.of_fields
#check ExternalCarrierFields.of_fields
#check BuiltinArgs.of_fields
#check ExternalArgs.of_fields
#check Outcome.Typed.of_fields
#check Outcome.Carrier.of_fields
#check ModelScopeConditions.of_responses

def Preserves (transform : Ty → Ty) : Prop :=
  ∀ (id : ExternalId) (args : List Ty), ∃ resultArgs,
    (transform (.external id args)).core = .external id resultArgs

theorem norm_preserves : Preserves Ty.norm := by
  intro id args
  exact ⟨Ty.normTys args,rfl⟩

theorem use_mode {P n tel use} (h : ExternalUseAt P n tel use) :
    (∀ i, use.position = .argument i → use.mode = .borrow) ∧
    (use.position = .result → use.mode = .own) := by
  induction h with
  | argument _ => exact ⟨fun _ _ => rfl,fun h => by cases h⟩
  | next _ ih => exact ih
  | result _ =>
    constructor
    · intro i h; cases h
    · intro h; rfl

#check ExternalSignature.WF.shape
#check ExternalModel.response
#check ExternalModel.external_assumptions
#check Builtins.selectExternal
#check Builtins.selectExternal_response
#check ExternalModels.model_scope
#check ExternalModels.targets_scope
#check ExternalModels.http_scope

-- 後続が証明する状態の接続。型は既存の状態・遷移をそのまま読む。
def ExternalStepTarget (P : Program) (B : Builtins) : Prop :=
  ∀ σ Eb q f ts ws k μ,
    P.WellFormed → P.WellTyped B → Builtins.CoreAssumptions P B →
    StateTyE P B σ Eb (.run q k μ) → q.view = .externalCall f ts ws →
    ∃ out obs dest, B.externalResponse f ts ws out obs ∧ obs = [] ∧
      Step P B σ (.run q k μ) none dest ∧ StateTyE P B σ Eb dest

def SelectedStepTarget (P : Program) (B : Builtins) : Prop :=
  ∀ σ Eb oracle rel fresh q f ts ws k μ result,
    P.WellFormed → P.WellTyped B → Builtins.CoreAssumptions P B →
    StateTyE P B σ Eb (.run q k μ) → q.view = .externalCall f ts ws →
    step P B σ oracle B.selectExternal rel fresh (.run q k μ) = some result →
      Step P B σ (.run q k μ) result.1 result.2 ∧ StateTyE P B σ Eb result.2

#check ResourceRelease.response
#check ResourceRelease.canonical
#check ResourceRelease.typed_response
#check ResourceRelease.targets_classification

-- 全件の本体再証明・全条件の合成の出力の型。証明の代わりには数えない。
def DefinitionTarget : Prop :=
  ∀ (externals : List (ExternalKey × ExternalDecl))
    (_hw : (StandardModel.program externals).ExternalWF) (f : Benitoite.Release.FunName) (d : Def),
    (StandardModel.program externals).defs f = some d →
      d.WellTyped (StandardModel.program externals)
        (StandardModel.builtins (StandardModel.program externals))

def BodyTarget : Prop :=
  ∀ (externals : List (ExternalKey × ExternalDecl))
    (_hw : (StandardModel.program externals).ExternalWF) (body : StandardModel.Body),
    body.definition.WellTyped (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))

def ProgramTarget : Prop :=
  ∀ (externals : List (ExternalKey × ExternalDecl))
    (_hw : (StandardModel.program externals).ExternalWF),
    (StandardModel.program externals).WellTyped
      (StandardModel.builtins (StandardModel.program externals))

def WellFormedTarget : Prop :=
  ∀ (externals : List (ExternalKey × ExternalDecl))
    (_hw : (StandardModel.program externals).ExternalWF), (StandardModel.program externals).WellFormed

def CoreTarget : Prop :=
  ∀ (externals : List (ExternalKey × ExternalDecl))
    (_hw : (StandardModel.program externals).ExternalWF),
    Builtins.CoreAssumptions (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))

def TargetsTarget : Prop :=
  ∀ (externals : List (ExternalKey × ExternalDecl)),
    Builtins.TargetAgreement (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals))

-- 有限の全本体の再証明と、任意のlookupを量化する証明先は同値である。
theorem definition_target_iff : DefinitionTarget ↔ BodyTarget := by
  constructor
  · intro h externals hw body
    exact h externals hw body.key body.definition (StandardModel.body_lookup externals body)
  · intro h externals hw f d lookup
    obtain ⟨body,_,_,rfl⟩ := StandardModel.lookup_body lookup
    exact h externals hw body

theorem program_target_of_definition
    (variance : ∀ externals, (StandardModel.program externals).VarianceValid)
    (definitions : DefinitionTarget) : ProgramTarget := by
  intro externals hw
  refine ⟨variance externals,hw,definitions externals hw,?_⟩
  intro i id lookup
  cases lookup

#check ExternalSurface.ref_typed
#check ExternalSurface.call_typed
end Benitoite.RefinementSignatureTargets

open Lean Elab Command in
run_cmd do
  let mut seen : Std.HashSet Name := {}
  repeat
    let env ← getEnv
    let names := env.constants.toList.filterMap fun (n, _) =>
      if (env.getModuleIdxFor? n).isNone && !seen.contains n then some n else none
    if names.isEmpty then break
    for n in names do
      seen := seen.insert n
      logInfo m!"LOCAL_AUDIT {n}"
      let deps ← Lean.collectAxioms n
      logInfo m!"'{n}' depends on axioms: [{String.intercalate ", " (deps.toList.map Name.toString)}]"
