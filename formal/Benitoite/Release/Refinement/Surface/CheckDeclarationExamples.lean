import Benitoite.Release.Refinement.Surface.CheckDeclarationsSound
import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.Surface.CheckMaterialsSound
import Benitoite.Release.Refinement.Surface.CheckTables

/-! 引数を持つ関数と、メソッド・上位の辞書を持つ実装の入力。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDeclarationExamples
open CheckDeclarations

private def method : MethSig := ⟨[], 0, ["value"], [.base .unit], .base .unit, Eff.empty⟩
private def runner : ClassDecl := ⟨.value, ["Root"], fun m => if m = "run" then some method else none⟩
private def root : ClassDecl := ⟨.value, [], fun _ => none⟩
private def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none
  classes := fun c => if c = "Runner" then some runner else if c = "Root" then some root else none

private def builtins : Builtins :=
  { sig := fun _ => none, delta := fun _ _ _ _ _ => none,
    ioResponse := fun _ _ _ _ _ _ => False, releaseResponse := fun _ _ => False,
    isResource := fun _ => false, effects := fun _ => none, sat := fun _ _ _ => False,
    refGet := "get", refSet := "set" }

private def input : Check.Input where
  D := declarations
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := ⟨[], fun _ => [], []⟩
  proofSteps := 1
  methods := ["run"]
  supers := ["Root"]
  methodParamNames := fun _ _ => ["value"]

private def definition : Def where
  tparams := []
  neffs := 0
  names := ["value"]
  params := [.base .unit]
  ret := .base .unit
  eff := Eff.empty
  body := .empty

private def implementation : ImplDecl where
  tparams := [{}]
  dictParams := [("Root", 0)]
  cls := "Runner"
  target := .tvar 0
  supers := fun s => if s = "Root" then some (.local 0) else none
  methods := fun m => if m = "run" then some .empty else none

private theorem effect_support : Eff.empty.Support (· ∈ input.formation.atoms) :=
  Check.empty_effect_support _

private theorem input_sound : input.Sound := by
  refine ⟨⟨?_, ?_⟩, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · intro c cd h; cases h
  · intro c cd h; cases h
  · intro i d h; cases h
  · intro f d h; cases h
  · intro f d h; cases h
  · intro f d h; cases h
  · intro c cd m ms hc hm
    simp only [input, declarations] at hc
    split at hc
    · cases hc
      simp only [runner] at hm
      split at hm
      · cases hm; exact ⟨by trivial, by trivial, effect_support, by exact ⟨trivial, trivial, effect_support⟩⟩
      · cases hm
    · split at hc
      · cases hc; cases hm
      · cases hc
  · intro f d h; cases h
  · intro C a p h; cases h
  · intro b signature C ts h; cases h
  · intro f r h; cases h
  · intro o t b ts h; cases h

/-- 非空の辞書列は、束縛した辞書の位置だけを受理する。 -/
theorem dictionaries_accept_reject :
    CheckArguments.dicts input.formation input.D input.B input.satDec []
      [some (.dict "Root" (.base .unit))] [] [.local 0] [.dict "Root" (.base .unit)] [.local] = true ∧
    CheckArguments.dicts input.formation input.D input.B input.satDec []
      [some (.dict "Root" (.base .unit))] [] [.local 1] [.dict "Root" (.base .unit)] [.local] = false := by
  constructor <;> with_unfolding_all rfl

/-- 辞書列の公開された健全性を、正常な辞書を持つ非空の列へ適用する。 -/
theorem dictionaries_typed :
    DictEv.HasTypes input.D input.B [] [some (.dict "Root" (.base .unit))]
      [.local 0] [.dict "Root" (.base .unit)] :=
  CheckArguments.dicts_sound (gs := [.local]) (path := [])
    input_sound.formation input_sound.tables.dictionaries input_sound.sat
    ((Check.CtxSupport.empty _).extend (a := .dict "Root" (.base .unit)) trivial)
    ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ dictionaries_accept_reject.1

private theorem definition_support : DefSupport input definition := by
  refine ⟨?_, trivial⟩
  exact ⟨trivial, trivial, effect_support⟩

private theorem implementation_support : ImplSupport input implementation := by
  refine ⟨trivial, ?_, ?_⟩
  · intro m body h
    simp only [implementation] at h
    split at h
    · cases h; trivial
    · cases h
  · intro s u h
    simp only [implementation] at h
    split at h
    · cases h; trivial
    · cases h

private theorem implementation_names : ImplNamesComplete input implementation := by
  constructor
  · intro cd hc m hm
    simp only [input, declarations] at hc
    split at hc
    · cases hc
      by_cases he : m = "run"
      · simp [input, he]
      · simp [implementation, runner, he] at hm
    · split at hc
      · cases hc
        by_cases he : m = "run"
        · simp [input, he]
        · simp [implementation, root, he] at hm
      · cases hc
  · intro s u h
    simp only [implementation] at h
    split at h
    · next hs => simp [input, hs]
    · cases h



/-- 同じ Unit を返す本体について、引数の契約名の重複を拒否する。 -/
theorem definition_accept_reject :
    checkDef input [] definition = .ok () ∧
    (match checkDef input [] {definition with names := ["value", "value"], params := [.base .unit, .base .unit]} with
      | .error _ => True | _ => False) := by
  constructor; with_unfolding_all rfl; trivial

/-- メソッドと上位の辞書を持つ実装は、実名が契約に一致するとき受理する。 -/
theorem implementation_accept_reject :
    checkImpl input "implementation" [] implementation = .ok () ∧
    (match checkImpl {input with methodParamNames := fun _ _ => ["other"]} "implementation" [] implementation with
      | .error _ => True | _ => False) := by
  constructor; with_unfolding_all rfl; trivial

/-- 本体を持つ宣言は、同じ成功から型付けと実名の契約を得る。 -/
theorem definitions_typed :
    definition.WellTyped input.D input.B input.opPrim ∧
    implementation.WellTyped input.D input.B input.opPrim ∧ ContractsMatch input "implementation" implementation :=
  ⟨checkDef_no_ranges_sound input_sound definition_support rfl definition_accept_reject.1,
    checkImpl_sound input_sound implementation_support implementation_names implementation_accept_reject.1,
    checkImpl_contracts implementation_names implementation_accept_reject.1⟩

/-- 関数の明示指定は既定を上書きし、0の指定は拒否する。 -/
theorem definition_budget :
    (definitionInput {input with proofSteps := 10} {definition with proofSteps := some 1}).proofSteps = 1 ∧
    (match checkDef input [] {definition with proofSteps := some 0} with
      | .error _ => True | _ => False) := by
  constructor; with_unfolding_all rfl; trivial

private def budgetGoal : Pred := .eq (.var 0) (.integer 1)

private def counted : CheckSubtyping.LogicCertificate :=
  ⟨.use 0, [.work .checkCertificate .node, .work .checkCertificate .node], none⟩

/-- ソースで選んだ上限1は、同じ含意の証明書の二つ目の操作で打ち切る。 -/
theorem definition_budget_stops :
    counted.result (definitionInput {input with proofSteps := 10} {definition with proofSteps := some 1}).proofSteps
      [budgetGoal] budgetGoal = .unknown (some .stepsExhausted) ∧
    counted.result 10 [budgetGoal] budgetGoal = .proved := by
  constructor <;> with_unfolding_all rfl

private def exprInput : Check.Input := input

/-- 式とブロックの実入口は、同じ推論結果を再検査する。 -/
theorem entrypoints_accept :
    Check.checkExpr exprInput [] [] [] none .other [] .unit = .ok (.base .unit, Eff.empty) ∧
    Check.checkBlock input [] [] [] none .other [] .empty = .ok (.base .unit, Eff.empty) := by
  constructor <;> with_unfolding_all rfl

/-- 実入口は、型付けと型・効果の受理の条件を両方結論に持つ。 -/
theorem entrypoints_typed :
    (HasTypeQ exprInput.D exprInput.B exprInput.opPrim Qempty [] [] [] [] none .other .unit (.base .unit) Eff.empty ∧
      SingleTy Qempty (.base .unit) ∧ SingleEff Qempty Eff.empty) ∧
    (HasBlockQ input.D input.B input.opPrim Qempty [] [] [] [] none .other .empty (.base .unit) Eff.empty ∧
      SingleTy Qempty (.base .unit) ∧ SingleEff Qempty Eff.empty) := by
  constructor
  · exact Check.checkExpr_sound (show exprInput.Sound from ⟨input_sound.formation, input_sound.tables, input_sound.sat, input_sound.admits, input_sound.ranges, input_sound.operators⟩) (Check.CtxSupport.empty _) (by trivial)
      (by trivial) (by trivial) effect_support entrypoints_accept.1
  · exact Check.checkBlock_sound input_sound (Check.CtxSupport.empty _) (by trivial)
      (by trivial) (by trivial) effect_support entrypoints_accept.2

private def materials : CheckTables.Materials where
  defs := [("function", definition)]
  classes := [("Runner", ⟨.value, ["Root"], [("run", method)]⟩), ("Root", ⟨.value, [], []⟩)]
  impls := [("implementation", ⟨implementation.toImplSig, [("Root", .local 0)], [("run", ⟨["value"], .empty⟩)]⟩)]

/-- 関数・実装・メソッドの実在する材料が、型の検査と二種類の名前の全件性を同時に満たす。 -/
theorem finite_materials_checked :
    CheckTables.checkProgram (materials.input input) materials.program = .ok () ∧
    CheckTables.NamesComplete (materials.input input) materials.program ∧
    CheckAccept.NamesComplete (materials.input input) materials.program :=
  ⟨(by with_unfolding_all rfl), materials.names_complete input, materials.accept_names_complete input⟩

/-- 材料のメソッドの実名は、本体を射影しても同じ表から取り出せる。 -/
theorem finite_method_names :
    (materials.input input).methodParamNames "implementation" "run" = ["value"] ∧
    implementation.methods "run" = some .empty :=
  (CheckTables.Materials.method_input (m := materials) (base := input)
    (i := "implementation") (name := "run") rfl rfl)

private theorem material_input_sound : (materials.input input).Sound := by
  apply materials.input_sound input
  · intro c cd h; cases h
  · refine ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩
    · intro i id h
      change ((CheckTables.lookup (materials.impls.map (fun (n, im) => (n, im.decl))) i).map ImplDecl.toImplSig).or none = some id at h
      rw [CheckTables.lookup_map] at h
      simp only [materials, CheckTables.lookup] at h
      split at h
      · cases h; trivial
      · cases h
    · intro f fd h
      change ((materials.program.lookupFun Def.toFunDecl accessorDecl testerDecl f).or none) = some fd at h
      simp only [Program.lookupFun] at h
      split at h
      · rename_i d hd
        have hd' : (if "function" = f then some definition else none) = some d := hd
        split at hd'
        · cases hd'; cases h
          exact ⟨by trivial, by trivial, effect_support, by exact ⟨trivial, trivial, effect_support⟩⟩
        · cases hd'
      · cases h
    · intro b sg h; cases h
    · intro o d h; cases h
    · intro c cd name ms hc hm
      change CheckTables.lookup (materials.classes.map (fun (n, cm) => (n, cm.decl))) c = some cd at hc
      simp only [materials, List.map_cons, List.map_nil, CheckTables.lookup] at hc
      split at hc
      · cases hc
        change (if "run" = name then some method else none) = some ms at hm
        split at hm
        · cases hm
          exact ⟨by trivial, by trivial, effect_support, by exact ⟨trivial, trivial, effect_support⟩⟩
        · cases hm
      · split at hc
        · cases hc; cases hm
        · cases hc
    · intro f d h; cases h
  · exact input_sound.sat
  · exact input_sound.admits
  · exact input_sound.ranges
  · exact input_sound.operators

private theorem material_definitions_support :
    ∀ n d, materials.program.defs n = some d → DefSupport (materials.input input) d := by
  intro n d h
  change (if "function" = n then some definition else none) = some d at h
  split at h
  · cases h; exact ⟨definition_support.signature, by trivial⟩
  · cases h

private theorem material_implementations_support :
    ∀ i id, materials.program.impls i = some id → ImplSupport (materials.input input) id := by
  intro i id h
  change CheckTables.lookup (materials.impls.map (fun (n, im) => (n, im.decl))) i = some id at h
  simp only [materials, List.map_cons, List.map_nil, CheckTables.lookup] at h
  split at h
  · cases h
    refine ⟨by trivial, ?_, ?_⟩
    · intro name body hm
      change (if "run" = name then some Block.empty else none) = some body at hm
      split at hm
      · cases hm; trivial
      · cases hm
    · intro s u hu
      change (if "Root" = s then some (DictEv.local 0) else none) = some u at hu
      split at hu
      · cases hu; trivial
      · cases hu
  · cases h



/-- 本体を持つ有限材料で、補完した宣言表の下での型付けを得る。 -/
theorem material_typed : CheckTables.CheckedUnder materials.program (materials.input input) :=
  CheckTables.Materials.checkProgram_sound material_input_sound material_definitions_support
    material_implementations_support finite_materials_checked.1

theorem material_typed_contracts :
    CheckTables.CheckedUnder materials.program (materials.input input) ∧
    ∀ i id, materials.program.impls i = some id → ContractsMatch (materials.input input) i id :=
  CheckTables.Materials.checkProgram_sound_contracts material_input_sound material_definitions_support
    material_implementations_support finite_materials_checked.1

/-- 信頼する補完のない同じ材料は、自身の表の下でも型付く。 -/
theorem material_empty : materials.program.WellTyped input.B input.opPrim :=
  CheckTables.Materials.checkProgram_empty material_input_sound material_definitions_support
    material_implementations_support rfl rfl finite_materials_checked.1

theorem material_empty_contracts : materials.program.WellTyped input.B input.opPrim ∧
    ∀ i id, materials.program.impls i = some id → ContractsMatch (materials.input input) i id :=
  CheckTables.Materials.checkProgram_empty_contracts material_input_sound material_definitions_support
    material_implementations_support rfl rfl finite_materials_checked.1

/-- 射影前に保持した実名は、型付けを得た同じクラスの契約名と一致する。 -/
theorem material_actual_names : ["value"] = method.names := by
  let im : CheckTables.ImplMaterial :=
    ⟨implementation.toImplSig, [("Root", .local 0)], [("run", ⟨["value"], .empty⟩)]⟩
  have hi : CheckTables.lookup materials.impls "implementation" = some im := rfl
  have hp : materials.program.impls "implementation" = some im.decl := rfl
  have hn := CheckTables.Materials.actual_contracts hi (material_typed_contracts.2 _ _ hp)
  exact hn _ rfl "run" _ _ rfl rfl

end Benitoite.Release.Refinement.Surface.CheckDeclarationExamples
