import Benitoite.Release.Refinement.Surface.PredicateSimulationHttpShape
import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationRuntime
import Benitoite.Release.Refinement.AtStateInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationStructure

/-! # At の型付き入力と対応する捕捉からの同じ原入力 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardModel
noncomputable section

local macro "unfoldAtPreparation" : tactic => do
  let prepare := Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.AtPrepare
    `Benitoite.Release.Refinement.prepareCore)
  let finish := Lean.mkIdent (Lean.mkPrivateNameCore `Benitoite.Release.Refinement.AtPrepare
    `Benitoite.Release.Refinement.finishPreparation)
  `(tactic| simp only [AtPrepare, $prepare:ident, $finish:ident])

private theorem pattern_value_equal {P B Ψ Q source rows kind x y}
    (typed : HasTypeVQ P B Ψ Q [] [] [] y (.scopePattern kind))
    (related : Value source rows x y) : x = y := by
  obtain ⟨range,rfl⟩ := typed.canonical_scopePattern rfl
  cases related
  rfl

private theorem bases_value_equal {P B Ψ Q source rows x y}
    (typed : HasTypeVQ P B Ψ Q [] [] [] y .pathBases) (related : Value source rows x y) : x = y := by
  obtain ⟨snapshot,rfl⟩ := typed.canonical_pathBases rfl
  cases related
  rfl

private theorem content_request {B : Builtins} [lookup : RowLookup B] {name input}
    (found : B.valContent name = some input) : input = TargetTable.clientRequestTy := by
  rw [lookup.valContent] at found
  change TargetTable.valContent name = some input at found
  simp only [TargetTable.valContent,Benitoite.Release.TargetTable.valContent] at found
  split at found <;> cases found <;> rfl

private theorem admissible_bases {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (admissible : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    ∀ value, bases = some value → HasTypeVQ P B Ψ Q C Γ Φ value .pathBases := by
  cases admissible <;> assumption

private theorem admissible_pattern {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (admissible : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    HasTypeVQ P B Ψ Q C Γ Φ pattern (.scopePattern kind) ∨
      HasTypeVQ P B Ψ Q C Γ Φ pattern (.base .string) := by
  cases admissible with
  | mk _ _ _ typed _ _ _ _ => exact Or.inl typed
  | text _ _ _ typed _ _ _ _ => exact Or.inr typed

/-- 対応先のAtの型付けだけから、捕捉を閉じた全入力の生の等号を導く。 -/
theorem at_inputs_equal {externals P B Ψ R Γ Φ source rows cap cap' kind name shape
    bases bases' pattern pattern' input input' index} [RowLookup B]
    (included : Includes externals P) (formed : P.WellFormed) (valid : P.VarianceValid) (typedProgram : P.WellTyped B)
    (core : B.CoreAssumptions P) (storeWF : Ψ.WF) (sorted : Ψ.Sorted) (declared : StoreTy.Declared P Ψ)
    (capture : CaptureOk P B Ψ R Γ Φ cap')
    (admissible : AtCallAdmissible P B Ψ Qempty [] Γ Φ kind name shape bases' pattern' input' index)
    (captures : Captures source rows cap cap') (basesRelated : OptionalValue source rows bases bases')
    (patternRelated : Value source rows pattern pattern') (inputRelated : Value source rows input input') :
    bases.map (closeVal cap) = bases'.map (closeVal cap') ∧
      closeVal cap pattern = closeVal cap' pattern' ∧ closeVal cap input = closeVal cap' input' := by
  have inputEq : closeVal cap input = closeVal cap' input' := by
    obtain ⟨inputType,content,typed⟩ :=
      admissible.closed_input formed typedProgram core storeWF sorted declared capture
    rcases content with ⟨rfl,_⟩ | ⟨content,_,_⟩
    · exact constant_input_equal (.base .string) typed (inputRelated.close captures)
    · have same := content_request content
      rw [same] at typed
      exact request_value_equal included valid typed (inputRelated.close captures)
  refine ⟨?_,?_,inputEq⟩
  · cases basesRelated with
    | none => rfl
    | some value =>
      have typed := close_value_typed formed typedProgram core storeWF sorted declared capture
        (admissible_bases admissible _ rfl)
      have same := bases_value_equal typed (value.close captures)
      exact congrArg some same
  · rcases admissible_pattern admissible with patternType | textType
    · have typed := close_value_typed formed typedProgram core storeWF sorted declared capture patternType
      exact pattern_value_equal typed (patternRelated.close captures)
    · have typed := close_value_typed formed typedProgram core storeWF sorted declared capture textType
      exact constant_input_equal (.base .string) typed (patternRelated.close captures)

/-- 捕捉を閉じた原入力と表の保持内容が同じなら、準備の成功・失敗の全詳細も同じである。 -/
theorem at_prepare_equal {B D : Builtins} {cap cap' kind name bases bases' pattern pattern' input input' index}
    (kinds : B.valKind = D.valKind) (content : B.valContent = D.valContent)
    (baseEq : bases.map (closeVal cap) = bases'.map (closeVal cap'))
    (patternEq : closeVal cap pattern = closeVal cap' pattern')
    (inputEq : closeVal cap input = closeVal cap' input') :
    AtPrepare B cap kind name bases pattern input index =
      AtPrepare D cap' kind name bases' pattern' input' index := by
  cases index with
  | rvar index => simp only [AtPrepare,patternEq,inputEq]
  | fixed bound =>
    cases bases <;> cases bases'
    all_goals simp only [Option.map_none,Option.map_some] at baseEq
    all_goals first | cases baseEq | skip
    all_goals try have same := Option.some.inj baseEq
    all_goals unfoldAtPreparation
    all_goals simp only [patternEq,inputEq,kinds,content] <;> first | rfl | (simp only [same])

/-- 成功した保持値へ渡す元の要求も同じである。 -/
theorem at_request_equal {B D : Builtins} {name input input'}
    (content : B.valContent = D.valContent) (same : input = input') :
    AtRequest B name input = AtRequest D name input' := by
  simp only [AtRequest,content,same]

/-- 準備の失敗は、元のpatternと対象にない組込み名を診断の原入力へ作らない。 -/
theorem at_prepare_noMint {B cap kind name bases pattern input index detail keys}
    (patternAvoid : ValueAvoid keys (closeVal cap pattern))
    (inputAvoid : ValueAvoid keys (closeVal cap input))
    (failed : AtPrepare B cap kind name bases pattern input index = .error detail) :
    ValueAvoid keys (.atError detail) := by
  obtain ⟨snapshot,parsedPattern,parsedTarget,saved⟩ := AtPrepare.error_saved failed
  rw [saved]
  change NamesAvoid keys (PredicateGeneratedNames.valueNames (closeVal cap pattern) ++
    PredicateGeneratedNames.valueNames (closeVal cap input))
  intro key member
  rcases List.mem_append.mp member with member | member
  · exact patternAvoid key member
  · exact inputAvoid key member

/-- 範囲の検査の失敗も、保存する二つの原入力以外に組込み名を持たない。 -/
theorem at_check_noMint {pattern input snapshot parsedPattern parsedTarget failure keys}
    (patternAvoid : ValueAvoid keys pattern) (inputAvoid : ValueAvoid keys input) :
    ValueAvoid keys (.atError (AtError.fromCheck pattern input snapshot parsedPattern parsedTarget failure)) := by
  intro key member
  rcases List.mem_append.mp member with member | member
  · exact patternAvoid key member
  · exact inputAvoid key member

section
variable {source : Program} {rows : PredicateProjection.Table.Rows} {P Q : Refinement.Program}
variable {B D : Builtins} {σ : PathEnv} {cap cap' : Capture} {kind : Scope.Domain.Kind} {name : OpaqueName}
variable {shape : ResultShape} {bases bases' : Option Val} {pattern pattern' input input' : Val} {index : RangeIx}
variable {k l : Cont} {μ ν : Store}

/-- 同じ準備と範囲の成功から、対応先の実際の成功の段と同じ保持値を構成する。 -/
theorem at_ok_forward {snapshot pat target bound t}
    (captures : Captures source rows cap cap') (stack : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (kinds : B.valKind = D.valKind) (content : B.valContent = D.valContent)
    (baseEq : bases.map (closeVal cap) = bases'.map (closeVal cap'))
    (patternEq : closeVal cap pattern = closeVal cap' pattern') (inputEq : closeVal cap input = closeVal cap' input')
    (prepared : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (current : ∀ ρ, snapshot = some ρ → ρ = σ)
    (accepted : checkAt snapshot kind pat target bound = .ok t) :
    Step Q D σ (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν) none
      (.run (.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),cap'.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest D name (closeVal cap' input'))]))) l ν) ∧
    StateRel source rows
      (.run (.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),cap.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest B name (closeVal cap input))]))) k μ)
      (.run (.pure (.ret (.con shape.ok [.scoped name kind (.fixed bound),cap'.closeTy shape.errorType]
        [.checkedAt bound snapshot t (AtRequest D name (closeVal cap' input'))]))) l ν) := by
  have prepared' : AtPrepared D cap' kind name bases' pattern' input' index snapshot pat target bound := by
    unfold AtPrepared at prepared ⊢
    rw [← at_prepare_equal kinds content baseEq patternEq inputEq]
    exact prepared
  refine ⟨.E_AtOk rfl prepared' current accepted,.run (.pure (.ret ?_)) stack store⟩
  rw [captures.closeTy,at_request_equal content inputEq]
  exact .refl _

/-- 範囲の失敗は、原入力を保存する同じ詳細を対応先の段にも渡す。 -/
theorem at_error_forward {snapshot pat target bound detail}
    (captures : Captures source rows cap cap') (stack : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (kinds : B.valKind = D.valKind) (content : B.valContent = D.valContent)
    (baseEq : bases.map (closeVal cap) = bases'.map (closeVal cap'))
    (patternEq : closeVal cap pattern = closeVal cap' pattern') (inputEq : closeVal cap input = closeVal cap' input')
    (prepared : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (current : ∀ ρ, snapshot = some ρ → ρ = σ)
    (failed : checkAt snapshot kind pat target bound = .error detail) :
    Step Q D σ (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν) none
      (.run (.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),cap'.closeTy shape.errorType]
        [.atError (AtError.fromCheck (closeVal cap' pattern') (closeVal cap' input') snapshot pat target detail)]))) l ν) ∧
    StateRel source rows
      (.run (.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),cap.closeTy shape.errorType]
        [.atError (AtError.fromCheck (closeVal cap pattern) (closeVal cap input) snapshot pat target detail)]))) k μ)
      (.run (.pure (.ret (.con shape.error [.scoped name kind (.fixed bound),cap'.closeTy shape.errorType]
        [.atError (AtError.fromCheck (closeVal cap' pattern') (closeVal cap' input') snapshot pat target detail)]))) l ν) := by
  have prepared' : AtPrepared D cap' kind name bases' pattern' input' index snapshot pat target bound := by
    unfold AtPrepared at prepared ⊢
    rw [← at_prepare_equal kinds content baseEq patternEq inputEq]
    exact prepared
  refine ⟨.E_AtError rfl prepared' current failed,.run (.pure (.ret ?_)) stack store⟩
  rw [captures.closeTy,patternEq,inputEq]
  exact .refl _

/-- 準備の失敗も、診断全体を同じまま対応先の実際の段へ渡す。 -/
theorem at_prepare_error_forward {detail}
    (captures : Captures source rows cap cap') (stack : ContRel source rows k l) (store : StoreRel source rows μ ν)
    (kinds : B.valKind = D.valKind) (content : B.valContent = D.valContent)
    (baseEq : bases.map (closeVal cap) = bases'.map (closeVal cap'))
    (patternEq : closeVal cap pattern = closeVal cap' pattern') (inputEq : closeVal cap input = closeVal cap' input')
    (failed : AtPrepare B cap kind name bases pattern input index = .error detail) :
    Step Q D σ (.run (.mk cap' (.checkAt kind name shape bases' pattern' input' index)) l ν) none
      (.run (.pure (.ret (.con shape.error [.scoped name kind index,cap'.closeTy shape.errorType] [.atError detail]))) l ν) ∧
    StateRel source rows
      (.run (.pure (.ret (.con shape.error [.scoped name kind index,cap.closeTy shape.errorType] [.atError detail]))) k μ)
      (.run (.pure (.ret (.con shape.error [.scoped name kind index,cap'.closeTy shape.errorType] [.atError detail]))) l ν) := by
  have failed' : AtPrepare D cap' kind name bases' pattern' input' index = .error detail := by
    rw [← at_prepare_equal kinds content baseEq patternEq inputEq]
    exact failed
  refine ⟨.E_AtPrepareError rfl failed',.run (.pure (.ret ?_)) stack store⟩
  rw [captures.closeTy]
  exact .refl _

end

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
