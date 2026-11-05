import Benitoite.Release.Refinement.StandardModelIOInputs

/-! # 合成表の28+1欄の前提と、純粋な正常応答の篩の事実

`StandardModel.core` と `StandardModel.targets` の欄のうち、置換の八欄・admits_sat・外部応答の二欄・IOの
四欄の前提を、合成表の上で正常な入力が満たすことを示す。外部応答の欄は外部関数を一つ持つ外部宣言の表で、
正常値の生応答によって満たす。純粋な行の正常応答の項観測から、結果型の篩の事実も同じ表で読む。 -/
namespace Benitoite.Release.Refinement.StandardModel
noncomputable section
set_option linter.unusedSimpArgs false


/-- Map.getの行の署名。鍵の制約を持つ型パラメータと、制約のない型パラメータを持つ。 -/
theorem map_get_lookup (P : Program) :
    (builtins P).sig "Map.get" = some (StandardCollections.MapAPI.signature signatureBase.sat .get) :=
  row_lookup P .p272

/-- 鍵の制約を持つ一つの型パラメータの文脈。 -/
def keyContext : TypeCtx := [⟨TParam.keyC, .value⟩]

theorem key_variable_annotation {P : Program} : Ty.Annotation P keyContext [] (.tvar 0) :=
  ⟨by simp [Ty.WF, keyContext], trivial, by simp [Ty.Declared, keyContext]⟩

theorem key_renaming : TypeParamRenaming keyContext keyContext id := by
  intro i p hp
  exact ⟨p, hp, rfl, fun h => h, fun h => h⟩

/-- 置換の八欄の前提は、合成表の上で、Integerと鍵の制約を持つ型変数・恒等の改名・Integerへの具体化で満たせる。 -/
theorem substitution_inputs (externals : List (ExternalKey × ExternalDecl)) :
    let P := program externals
    let B := builtins P
    (∃ C Γ Δ a p, ∃ ξ : Nat → Nat, (∀ i j, i < j → ξ i < ξ j) ∧ Ty.Annotation P C Γ a ∧
      Ty.Annotation P C Δ (renameTy ξ a) ∧ B.sat (TypeCtx.constraints C) a p) ∧
    (∃ b sg C Γ Δ ts, ∃ ξ : Nat → Nat, B.sig b = some sg ∧ (∀ i j, i < j → ξ i < ξ j) ∧
      TypeAnnotations P C Γ ts ∧ TypeAnnotations P C Δ (ts.map (renameTy ξ)) ∧
      sg.admits (TypeCtx.constraints C) ts) ∧
    (∃ Ψ Q C Γ Δ Ξ ν a p, TypedValueImages P B Ψ Q C Γ Δ Ξ ν ∧ Ty.Annotation P C Γ a ∧
      B.sat (TypeCtx.constraints C) a p) ∧
    (∃ b sg Ψ Q C Γ Δ Ξ ν ts, B.sig b = some sg ∧ TypedValueImages P B Ψ Q C Γ Δ Ξ ν ∧
      TypeAnnotations P C Γ ts ∧ sg.admits (TypeCtx.constraints C) ts) ∧
    (∃ C C' Γ Δ a p, ∃ ρ : Nat → Nat, TypeParamRenaming C C' ρ ∧ Ty.Annotation P C Γ a ∧
      Ty.Annotation P C' Δ (a.renameTypes ρ) ∧ B.sat (TypeCtx.constraints C) a p) ∧
    (∃ b sg C C' Γ Δ ts, ∃ ρ : Nat → Nat, B.sig b = some sg ∧ TypeParamRenaming C C' ρ ∧
      TypeAnnotations P C Γ ts ∧ TypeAnnotations P C' Δ (ts.map (fun a => a.renameTypes ρ)) ∧
      sg.admits (TypeCtx.constraints C) ts) ∧
    (∃ C0 C1 a p ts, B.sat (TypeCtx.constraints (C1 ++ C0)) a p ∧ (∀ t ∈ ts, t.WF 0 0 0) ∧
      SatAll B C1 ts (TypeCtx.constraints C0) ∧ ts.length = C0.length) ∧
    (∃ b sg C0 C1 ts ts', B.sig b = some sg ∧ sg.admits (TypeCtx.constraints (C1 ++ C0)) ts ∧
      (∀ t ∈ ts', t.WF 0 0 0) ∧ SatAll B C1 ts' (TypeCtx.constraints C0) ∧ ts'.length = C0.length) := by
  intro P B
  have integers : TypeAnnotations P [] [] [.base .integer, .base .integer] := by
    intro t ht; simp at ht; rcases ht with rfl | rfl <;> exact base_annotation _
  have admits : (StandardCollections.MapAPI.signature signatureBase.sat .get).admits [] [.base .integer, .base .integer] :=
    ⟨rfl, integers_sat (P := P) (by simp) _⟩
  have keyAdmits : (StandardCollections.MapAPI.signature signatureBase.sat .get).admits
      (TypeCtx.constraints keyContext) [.tvar 0, .base .integer] := by
    refine ⟨rfl, ?_⟩
    intro i t p ht hp
    rcases i with _ | _ | i <;> simp at ht hp
    · subst ht; subst hp; rfl
    · subst ht; subst hp; exact integer_sat P _ _
  have keyAnnotations : TypeAnnotations P keyContext [] [.tvar 0, .base .integer] := by
    intro t ht; simp at ht
    rcases ht with rfl | rfl
    · exact key_variable_annotation
    · exact ⟨trivial, trivial, trivial⟩
  have satOne : SatAll B [] [.base .integer] (TypeCtx.constraints keyContext) :=
    ⟨rfl, fun i t p ht hp => by
      rcases i with _ | i <;> simp at ht; subst ht; exact integer_sat P _ _⟩
  refine ⟨⟨[], [], [], .base .integer, TParam.keyC, id, fun _ _ h => h, base_annotation _, base_annotation _,
      integer_sat P _ _⟩,
    ⟨"Map.get", _, [], [], [], [.base .integer, .base .integer], id, map_get_lookup P, fun _ _ h => h, integers,
      by simpa [renameTy, Ty.rawBind] using integers, admits⟩,
    ⟨StoreTy.empty, Qempty, [], [], [], [], fun _ => .const .unit, .base .integer, TParam.keyC,
      (by intro i a h; cases i <;> cases h), base_annotation _, integer_sat P _ _⟩,
    ⟨"Map.get", _, StoreTy.empty, Qempty, [], [], [], [], fun _ => .const .unit, [.base .integer, .base .integer],
      map_get_lookup P, (by intro i a h; cases i <;> cases h), integers, admits⟩,
    ⟨keyContext, keyContext, [], [], .tvar 0, TParam.keyC, id, key_renaming, key_variable_annotation,
      by simpa [Ty.norm] using (key_variable_annotation (P := P)), rfl⟩,
    ⟨"Map.get", _, keyContext, keyContext, [], [], [.tvar 0, .base .integer], id, map_get_lookup P, key_renaming,
      keyAnnotations, by simpa [Ty.norm] using keyAnnotations, keyAdmits⟩,
    ⟨keyContext, [], .tvar 0, TParam.keyC, [.base .integer], rfl, (by intro t ht; simp at ht; subst ht; trivial),
      satOne, rfl⟩,
    ⟨"Map.get", _, keyContext, [], [.tvar 0, .base .integer], [.base .integer], map_get_lookup P, keyAdmits,
      (by intro t ht; simp at ht; subst ht; trivial), satOne, rfl⟩⟩

/-- admits_satの前提は、Map.getの行とIntegerの二つの型引数で満たせる。結論の制約の判定は型引数を読み、
Floatは鍵の制約を満たさない。 -/
theorem admits_sat_input (externals : List (ExternalKey × ExternalDecl)) :
    (∃ b s C ts, (builtins (program externals)).sig b = some s ∧
      s.admits (TypeCtx.constraints C) (Ty.normTys ts)) ∧
    ¬ (builtins (program externals)).sat [] (.base .float) TParam.keyC :=
  ⟨⟨"Map.get", _, [], [.base .integer, .base .integer], map_get_lookup _,
    ⟨rfl, integers_sat (P := program externals) (by simp [Ty.normTys, Ty.norm]) _⟩⟩, by intro h; cases h⟩

/-- 一つの外部関数 `0 < self` を持つ外部宣言の表。 -/
def positiveExternals : List (ExternalKey × ExternalDecl) :=
  [(.function ⟨0⟩, .function ⟨0⟩ ExternalModelExamples.positiveSignature)]

theorem positive_annotation :
    Ty.Annotation (program positiveExternals) [] [] ExternalModelExamples.positiveType := by
  constructor <;> simp [ExternalModelExamples.positiveType,Ty.WF,Ty.Sorted,Ty.Declared,Pred.WF,Pred.VarsIn,
    Pred.Sorted,Pred.Declared,Ty.NotContCore,Term.VarsIn,Term.HasSort,Term.References,
    Term.Shape,Ctx.Readable,Ty.HasSort,Ty.sort?,Ordinary,Term.Declared,Ctx.declarationSelf,Ctx.extend,Ty.shiftV,Ty.core]

theorem positive_wf : (program positiveExternals).ExternalWF := by
  have ann := positive_annotation
  have signatureWF : ExternalModelExamples.positiveSignature.WF (program positiveExternals) := by
    refine ⟨rfl,rfl,?_,⟨by simp [ExternalModelExamples.positiveType,Ty.HasKind,Ty.NotContCore],
      by simp [kindsEff,kindsList,Eff.empty]⟩,?_,
      by simp [ExternalModelExamples.positiveSignature],.done (.refined (.scalar trivial)) rfl,?_⟩
    · exact ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩
    · intro use
      simp only [ExternalModelExamples.positiveSignature,List.not_mem_nil,false_iff]
      intro site
      cases site with | result occurrence => cases occurrence with | refined h => cases h
    · exact ⟨trivial,by simp [Eff.RowsIn,Ty.RowsInList,Eff.empty]⟩
  refine ⟨by simp [program, positiveExternals],?_⟩
  intro key decl member
  simp only [program,positiveExternals,List.mem_singleton,Prod.mk.injEq] at member
  rcases member with ⟨rfl,rfl⟩
  exact ⟨rfl,signatureWF⟩

theorem positive_arguments (Ψ : StoreTy) :
    ExternalArgs (program positiveExternals) (builtins (program positiveExternals)) Ψ
      ExternalModelExamples.positiveSignature [] [] ExternalModelExamples.positiveType Eff.empty := by
  have ann := positive_annotation
  refine ⟨⟨rfl,⟨rfl,by intros i t k hi; cases hi⟩,
    ⟨rfl,by intros i t p hi; cases hi⟩,by simp [TypeAnnotations]⟩,?_,by simp,by simp,
    ⟨ann.wf,rfl⟩,⟨trivial,rfl⟩⟩
  have bind : Tel.bind (typeEnv []) ExternalModelExamples.positiveSignature.parameters =
      .done ExternalModelExamples.positiveType Eff.empty := by
    have h := Tel.substAt_nil_of_wf (c := 0) [] ExternalModelExamples.positiveSignature.parameters ⟨ann.wf,trivial,rfl⟩
    change Tel.bind (typeEnv []) ExternalModelExamples.positiveSignature.parameters = _ at h
    simpa only [ExternalModelExamples.positiveSignature,Tel.norm,
      show ExternalModelExamples.positiveType.norm = ExternalModelExamples.positiveType from rfl,
      show Eff.norm Eff.empty = Eff.empty from rfl] using h
  rw [bind]
  exact .done ⟨⟨ann.wf,trivial,rfl⟩,⟨ann.sorted,trivial⟩,⟨ann.declared,trivial⟩⟩

/-- external_typed・external_no_targetsの前提は、外部関数を一つ持つ合成プログラムで、正常値1の生応答によって
満たせる。同じ入力にerrの応答も属し、正常値の応答には合成表の外部の条件がcarrierと空の観測を返す。 -/
theorem positive_inputs :
    let P := program positiveExternals
    let B := builtins P
    (∃ Ψ f d ts vs a e out obs, P.ExternalWF ∧ P.externalFunction f = some d ∧
      ExternalArgs P B Ψ d ts vs a e ∧ B.externalResponse f ts vs out obs ∧ (∃ v, out = .val v)) ∧
    B.externalResponse ⟨0⟩ [] [] (.err "ExternalError") [] ∧
    (∀ Ψ, Outcome.Carrier P B Ψ (.val (.const (.integer ⟨1, by decide⟩))) ExternalModelExamples.positiveType) := by
  intro P B
  have lookup : P.externalFunction ⟨0⟩ = some ExternalModelExamples.positiveSignature := rfl
  have normal : B.externalResponse ⟨0⟩ [] [] (.val (.const (.integer ⟨1, by decide⟩))) [] :=
    ExternalModel.response_value lookup (positive_arguments StoreTy.empty).instantiate
      (fun _ => .refined (.scalar (.V_Const trivial)) positive_annotation) (by trivial)
  refine ⟨⟨StoreTy.empty, ⟨0⟩, _, [], [], _, _, _, [], positive_wf, lookup, positive_arguments _, normal, _, rfl⟩,
    ExternalModel.response_err _ _ _ _ _ _, fun Ψ => ?_⟩
  exact ((core positiveExternals).external_typed Ψ ⟨0⟩ _ [] [] _ _ _ [] positive_wf lookup
    (positive_arguments Ψ) normal).1

/-- IOの四欄と対象の条件の前提は、合成表のFile.readTextInの行と保持したパスで満たせる。応答は合成表のIO応答の
存在から選び、その観測は保持したパスの一つである。 -/
theorem io_field_inputs (externals : List (ExternalKey × ExternalDecl)) :
    let P := program externals
    let B := builtins P
    ∃ Ψ b sg ts es rs ws a e, B.sig b = some sg ∧ (sg.kind = .io ∨ sg.kind = .exit) ∧
      BuiltinArgs P B Ψ b sg ts es rs ws a e ∧ ∃ out obs, B.ioResponse b ts es ws out obs := by
  intro P B
  obtain ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args⟩ := io_inputs externals .p161 rfl
  have kind : sg.kind = .io := by
    cases Option.some.inj (lookup.symm.trans (row_lookup P .p161)); rfl
  exact ⟨Ψ, _, sg, ts, es, rs, ws, a, e, lookup, Or.inl kind, args,
    (core externals).io_exists Ψ _ sg ts es rs ws a e lookup (Or.inl kind) args⟩

/-- 純粋な行の正常応答の項観測から、同じ応答の結果型の篩の事実を得る。 -/
theorem normal_facts {externals Ψ b sg ts es rs ws a e v t}
    (lookup : (builtins (program externals)).sig b = some sg) (kind : sg.kind = .pure)
    (args : BuiltinArgs (program externals) (builtins (program externals)) Ψ b sg ts es rs ws a e)
    (delta : (builtins (program externals)).delta b ts es rs ws = some (.val v)) (term : v.toTerm? = some t) :
    ∀ r ∈ a.assume, Entails [] (r.open t) := by
  obtain ⟨out, hd, _, typed, _⟩ := (core externals).delta_typed Ψ b sg ts es rs ws a e lookup kind args
  cases Option.some.inj (hd.symm.trans delta)
  exact typed.1.facts term

/-- 前提を満たす入力で、Map.getの行の契約は合成表のδの型付きの応答を返し、正常値なら結果型の篩の事実を持つ。 -/
example (externals : List (ExternalKey × ExternalDecl)) (hw : (program externals).ExternalWF) :
    ∃ Ψ sg ts es rs ws a e, (builtins (program externals)).sig "Map.get" = some sg ∧
      BuiltinArgs (program externals) (builtins (program externals)) Ψ "Map.get" sg ts es rs ws a e ∧
      ∃ out, (builtins (program externals)).delta "Map.get" ts es rs ws = some out ∧
        Outcome.Typed (program externals) (builtins (program externals)) Ψ out a ∧
        ∀ v t, out = .val v → v.toTerm? = some t → ∀ r ∈ a.assume, Entails [] (r.open t) := by
  obtain ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args⟩ := collection_inputs externals hw .p272 rfl
  obtain ⟨out, delta, _, typed, _⟩ := collection_rows externals .p272 rfl Ψ sg ts es rs ws a e lookup args
  have kind : sg.kind = .pure := by
    cases Option.some.inj (lookup.symm.trans (row_lookup _ .p272)); rfl
  refine ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args, out, delta, typed, ?_⟩
  intro v t hv ht
  subst hv
  exact normal_facts lookup kind args delta ht

/-- 前提を満たす入力で、範囲付きの行・IOの行の契約は応答と対象の条件を返す。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    PureRow.Satisfiable (program externals) "Scope.pathInValue" ∧
    ∃ Ψ sg ts es rs ws a e, (builtins (program externals)).sig "File.readTextIn" = some sg ∧
      BuiltinArgs (program externals) (builtins (program externals)) Ψ "File.readTextIn" sg ts es rs ws a e ∧
      ∃ out obs, (builtins (program externals)).ioResponse "File.readTextIn" ts es ws out obs ∧
        Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs := by
  refine ⟨scope_inputs externals .p282 rfl, ?_⟩
  obtain ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args⟩ := io_inputs externals .p161 rfl
  obtain ⟨contract, out, obs, response⟩ := io_rows externals .p161 rfl Ψ sg ts es rs ws a e lookup args
  exact ⟨Ψ, sg, ts, es, rs, ws, a, e, lookup, args, out, obs, response, (contract out obs response).2.2.2⟩

/-- 置換の欄とadmits_satの入力に合成表の同じ欄を当てると、改名した型も同じ制約を満たし、許容の入力から
制約の判定が出る。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    (∃ C a p, ∃ ξ : Nat → Nat, (builtins (program externals)).sat (TypeCtx.constraints C) (renameTy ξ a) p) ∧
    (∃ b s C ts, (builtins (program externals)).sig b = some s ∧
      SatAll (builtins (program externals)) C ts (s.tparams.map TParamDecl.constraints)) := by
  obtain ⟨⟨C, Γ, Δ, a, p, ξ, mono, ha, hb, sat⟩, _⟩ := substitution_inputs externals
  obtain ⟨⟨b, s, C', ts, lookup, admits⟩, _⟩ := admits_sat_input externals
  exact ⟨⟨C, a, p, ξ, (core externals).sat_rename C Γ Δ a p ξ mono ha hb sat⟩,
    ⟨b, s, C', ts, lookup, (core externals).admits_sat b s C' ts lookup admits⟩⟩

/-- 外部応答・IOの欄の入力は、同じ表の欄の結論へ渡せる。 -/
example (externals : List (ExternalKey × ExternalDecl)) :
    (∃ Ψ f d ts vs a e out obs, (program positiveExternals).ExternalWF ∧
      (program positiveExternals).externalFunction f = some d ∧
      ExternalArgs (program positiveExternals) (builtins (program positiveExternals)) Ψ d ts vs a e ∧
      (builtins (program positiveExternals)).externalResponse f ts vs out obs ∧ obs = []) ∧
    (∃ Ψ b sg ts es rs ws a e out obs, (builtins (program externals)).sig b = some sg ∧
      BuiltinArgs (program externals) (builtins (program externals)) Ψ b sg ts es rs ws a e ∧
      (builtins (program externals)).ioResponse b ts es ws out obs ∧
      Outcome.Typed (program externals) (builtins (program externals)) Ψ out a) := by
  constructor
  · obtain ⟨⟨Ψ, f, d, ts, vs, a, e, out, obs, hw, lookup, args, response, _⟩, _, _⟩ := positive_inputs
    exact ⟨Ψ, f, d, ts, vs, a, e, out, obs, hw, lookup, args, response,
      (core positiveExternals).external_no_targets Ψ f d ts vs a e out obs hw lookup args response⟩
  · obtain ⟨Ψ, b, sg, ts, es, rs, ws, a, e, lookup, kind, args, out, obs, response⟩ := io_field_inputs externals
    exact ⟨Ψ, b, sg, ts, es, rs, ws, a, e, out, obs, lookup, args, response,
      ((core externals).io_typed Ψ b sg ts es rs ws a e out obs lookup kind args response).1⟩

end
end Benitoite.Release.Refinement.StandardModel
