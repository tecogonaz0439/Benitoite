import Benitoite.Release.Refinement.ResourceReleaseLeaves

/-! # 三モデルの拡張表で読む二十五欄・外部三欄・解放一欄

外部応答と通常資源の解放の関係を持つ三つの表について、同じ表の既存の二十五欄、外部応答の三欄、
解放の一欄を読み、各表のCoreAssumptionsとTargetAgreementを返す。欄の分類に使う前提の否定、
定数の証人、前提を満たす入力も同じ表で示す。 -/
namespace Benitoite.Release.Refinement.ExternalModels
noncomputable section

/-- 同じ拡張表の二十五欄・外部三欄・解放一欄と、各表のCoreAssumptions・TargetAgreement。
宣言条件はModelでTrue、TargetsでHasFile、HttpでHasHttpであり、外部宣言の有無を制限しない。 -/
theorem ModelCase.composition (m : ModelCase) (P : Program) (decls : m.Declarations P) :
    ModelScopeConditions P (m.table P) ∧
    Builtins.ExternalAssumptions P (m.table P) ∧
    (∀ Ψ v o, HasTypeV P (m.table P) Ψ [] [] [] v (.opaque o (.fixed .top)) →
      (m.table P).isResource o = true → ∀ r, (m.table P).releaseResponse v r) ∧
    Builtins.CoreAssumptions P (m.table P) ∧ Builtins.TargetAgreement P (m.table P) := by
  obtain ⟨scope, external⟩ := conditions m P decls
  refine ⟨scope, external, m.release_all P, ?_, scope.toTargetAgreement⟩
  cases m with
  | model => exact model_core P
  | targets => exact targets_core P decls
  | http => exact http_core P decls

/-- Modelの拡張表で、delta_typed・io_typed・io_kind・io_exists・io_op・io_targetの各前提は
Falseになる。pure・IO・exitの署名がなく、IO応答の関係が空だからである。 -/
theorem model_vacuous_premises (P : Program) :
    (∀ Ψ b sg ts es rs ws a e, (model P).sig b = some sg → sg.kind = .pure →
      BuiltinArgs P (model P) Ψ b sg ts es rs ws a e → False) ∧
    (∀ Ψ b sg ts es rs ws a e out obs, (model P).sig b = some sg →
      (sg.kind = .io ∨ sg.kind = .exit) → BuiltinArgs P (model P) Ψ b sg ts es rs ws a e →
      (model P).ioResponse b ts es ws out obs → False) ∧
    (∀ Ψ b sg ts es rs ws a e out obs, (model P).sig b = some sg →
      BuiltinArgs P (model P) Ψ b sg ts es rs ws a e →
      (model P).ioResponse b ts es ws out obs → False) ∧
    (∀ Ψ b sg ts es rs ws a e, (model P).sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) →
      BuiltinArgs P (model P) Ψ b sg ts es rs ws a e → False) ∧
    (∀ b s, (model P).sig b = some s → (s.kind = .io ∨ s.kind = .exit) → False) ∧
    (∀ Ψ b sg ts es rs ws a e out obs, (model P).sig b = some sg →
      (sg.kind = .io ∨ sg.kind = .exit) → BuiltinArgs P (model P) Ψ b sg ts es rs ws a e →
      (model P).ioResponse b ts es ws out obs → False) := by
  have pure : ∀ b sg, (model P).sig b = some sg → sg.kind = .pure → False :=
    fun _ _ lookup kind => (model_no_response_kind lookup).1 kind
  have io : ∀ b sg, (model P).sig b = some sg → (sg.kind = .io ∨ sg.kind = .exit) → False := by
    intro _ _ lookup kind
    rcases kind with kind | kind
    · exact (model_no_response_kind lookup).2.1 kind
    · exact (model_no_response_kind lookup).2.2 kind
  have empty : ∀ b ts es ws out obs, ¬ (model P).ioResponse b ts es ws out obs :=
    fun _ _ _ _ _ _ response => response
  exact ⟨fun _ b sg _ _ _ _ _ _ lookup kind _ => pure b sg lookup kind,
    fun _ b sg _ _ _ _ _ _ _ _ lookup kind _ _ => io b sg lookup kind,
    fun _ b _ ts es _ ws _ _ out obs _ _ response => empty b ts es ws out obs response,
    fun _ b sg _ _ _ _ _ _ lookup kind _ => io b sg lookup kind,
    io,
    fun _ b sg _ _ _ _ _ _ _ _ lookup kind _ _ => io b sg lookup kind⟩

/-- 外部応答の存在欄は、宣言・引数・ストアのどの入力も読まない同じ定数errと空観測で閉じる。 -/
theorem ModelCase.external_constant (m : ModelCase) (P : Program) (f : ExternalFunctionId)
    (ts : List Ty) (vs : List Val) :
    (m.table P).externalResponse f ts vs (.err "External") [] := by
  cases m <;> exact ExternalModel.response_err P _ f ts vs "External"

/-- 新しい十二欄の前提を満たす入力。外部の型・対象の二欄は六形の正常値で、Targetsの解放欄は
型付きFile.Handle定数で満たす。ModelとHttpの解放欄は前提がFalseになる。 -/
theorem ModelCase.new_field_inputs (m : ModelCase) (s : ExternalModelExamples.Shape) (Ψ : StoreTy) :
    (m.Declarations (ExternalModelExamples.program s true) ∧
      (ExternalModelExamples.program s true).ExternalWF ∧
      ExternalArgs (ExternalModelExamples.program s true)
        (m.table (ExternalModelExamples.program s true)) Ψ
        (ExternalModelExamples.signature s true) [] [] (s.type true) Eff.empty ∧
      (m.table (ExternalModelExamples.program s true)).externalResponse ⟨0⟩ [] []
        (.val (s.raw true)) []) ∧
    (∀ P, (m = .targets → ∃ v o, HasTypeV P (m.table P) Ψ [] [] [] v (.opaque o (.fixed .top)) ∧
        (m.table P).isResource o = true) ∧
      (m ≠ .targets → ∀ o, (m.table P).isResource o ≠ true)) := by
  have input := shape_inputs m s true Ψ
  refine ⟨⟨input.1, input.2.1, input.2.2.1, input.2.2.2.1⟩, fun P => ⟨?_, ?_⟩⟩
  · rintro rfl
    exact ⟨_, _, targets_resource_input P Ψ 0⟩
  · intro hm o
    exact m.release_premise_false hm P o

/-- 三表の合成を任意のPで読み、ModelとTargetsとHttpの各宣言条件を同じPから供給する。 -/
example (P : Program) (hp : ScopeDeclarations.HasHttp P) :
    (∀ m : ModelCase, m.Declarations P →
      Builtins.CoreAssumptions P (m.table P) ∧ Builtins.TargetAgreement P (m.table P)) ∧
    (Builtins.CoreAssumptions P (ModelCase.http.table P) ∧
      Builtins.CoreAssumptions P (ModelCase.targets.table P) ∧
      Builtins.CoreAssumptions P (ModelCase.model.table P)) := by
  have all : ∀ m : ModelCase, m.Declarations P →
      Builtins.CoreAssumptions P (m.table P) ∧ Builtins.TargetAgreement P (m.table P) :=
    fun m decls => (m.composition P decls).2.2.2
  exact ⟨all, (all .http hp).1, (all .targets hp.file).1, (all .model trivial).1⟩

/-- 同じ拡張表の二十五欄・外部三欄・解放一欄から、各表のCoreAssumptionsを組み立てられる。 -/
example (m : ModelCase) (P : Program) (decls : m.Declarations P) :
    Builtins.CoreAssumptions P (m.table P) :=
  (conditions m P decls).1.core (conditions m P decls).2 (m.resource_table P).release_exists

/-- Modelの六欄の前提の否定と、三表の存在欄の定数の証人を同じ表で読む。 -/
example (P : Program) (m : ModelCase) (f : ExternalFunctionId) :
    (∀ b s, (model P).sig b = some s → (s.kind = .io ∨ s.kind = .exit) → False) ∧
    ∃ out obs, (m.table P).externalResponse f [] [] out obs :=
  ⟨(model_vacuous_premises P).2.2.2.2.1, _, _, m.external_constant P f [] []⟩

/-- 新しい条件の前提を満たす入力を同じ表の外部の型の条件とTargetsの解放の条件へ渡す。 -/
example (m : ModelCase) (s : ExternalModelExamples.Shape) (Ψ : StoreTy) (P : Program) :
    Outcome.Carrier (ExternalModelExamples.program s true) (m.table (ExternalModelExamples.program s true)) Ψ
      (.val (s.raw true)) (s.type true) ∧
    (m = .targets → ∃ v o, ∀ r, (m.table P).releaseResponse v r ∧
      HasTypeV P (m.table P) Ψ [] [] [] v (.opaque o (.fixed .top))) := by
  obtain ⟨⟨decls, wf, args, raw⟩, release⟩ := m.new_field_inputs s Ψ
  refine ⟨((conditions m _ decls).2.external_typed _ _ _ _ _ _ _ _ _ wf rfl args raw).1, ?_⟩
  intro hm
  obtain ⟨v, o, typed, resource⟩ := (release P).1 hm
  exact ⟨v, o, fun r => ⟨m.release_all P Ψ v o typed resource r, typed⟩⟩

end
end Benitoite.Release.Refinement.ExternalModels
