import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckAcceptedRanges
import Benitoite.Release.Refinement.Surface.CheckDeclarationBase
import Benitoite.Release.Refinement.Surface.CheckTables
import Benitoite.Release.Refinement.Surface.CheckMaterialsSound

/-! 必須の範囲判定を持つプログラムによる、検査と受理の適用例。 -/
namespace Benitoite.Release.Refinement.Surface.CheckExamples
open Check CheckAccept CheckArguments
open Benitoite.Scope.Inference Scope.Domain

private def requiredSignature : PrimSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  admits := fun _ _ => True
  kind := .pure
  opEff := none
  rkinds := [.path]

private def builtins : Builtins where
  sig := fun n => if n = "Example.required" then some requiredSignature else none
  delta := fun n _ _ _ _ => if n = "Example.required" then some (.val (.const .unit)) else none
  ioResponse := fun _ _ _ _ _ _ => False
  releaseResponse := fun _ _ => False
  isResource := fun _ => false
  effects := fun _ => none
  sat := fun _ _ _ => False
  refGet := "Reference.get"
  refSet := "Reference.set"
  admitsR := fun _ _ => True

private def body (r : Range) : Block :=
  .last (.call (.primName "Example.required" [] [] [.fixed (.absolute r)]) [] [] .nil)

private def definition (r : Range) : Def where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty
  body := body r

private def method : MethSig where
  tparams := []
  neffs := 0
  names := []
  params := []
  ret := .base .unit
  eff := Eff.empty

private def classDeclaration : ClassDecl where
  supers := []
  methods := fun n => if n = "run" then some method else none

private def implementation (r : Range) : ImplDecl where
  tparams := []
  dictParams := []
  cls := "Example.Required"
  target := .base .unit
  supers := fun _ => none
  methods := fun n => if n = "run" then some (body r) else none

private def program (r : Range) : Program where
  defs := fun n => if n = "Example.main" then some (definition r) else none
  cons := fun _ => none
  classes := fun n => if n = "Example.Required" then some classDeclaration else none
  impls := fun n => if n = "Example.UnitRequired" then some (implementation r) else none

private def input (r : Range) : Check.Input where
  D := (program r).declarations
  builtinSource := .custom builtins
  opPrim := fun _ _ => none
  formation := { atoms := [], ctors := fun _ => [] }
  admitsDec := fun _ _ _ => true
  admitsRDec := fun _ _ => true
  proofSteps := 1
  defs := ["Example.main"]
  impls := ["Example.UnitRequired"]
  methods := ["run"]

private def requiredRule : ScopeRule Refinement.Val where
  index := fun _ => [.path (.tree ["data"])]
  run := fun _ _ => some (.const .unit)
  transfer := fun _ _ => none

private def acceptInput : AcceptInput where
  ok := "Ok"
  rules := fun n => if n = "Example.required" then some requiredRule else none
  limits := ⟨⟨100, 100⟩, ⟨100, 100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

private theorem input_sound (r : Range) : (input r).Sound := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · refine ⟨?_, ?_⟩
    · intro c cd h; cases h
    · intro c cd h; cases h
  · refine ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩
    · intro i id h
      change (if i = "Example.UnitRequired" then some (implementation r) else none).map ImplDecl.toImplSig = some id at h
      split at h
      · cases h; trivial
      · cases h
    · intro f fd h
      change (program r).lookupFun Def.toFunDecl accessorDecl testerDecl f = some fd at h
      simp only [Program.lookupFun, program] at h
      split at h
      · rename_i d hd
        have hd' : (if f = "Example.main" then some (definition r) else none) = some d := hd
        split at hd'
        · cases hd'; cases h
          exact ⟨trivial, trivial, empty_effect_support _, trivial, empty_effect_support _⟩
        · cases hd'
      · cases h
    · intro b s h
      change (if b = "Example.required" then some requiredSignature else none) = some s at h
      split at h
      · cases h; exact ⟨trivial, trivial, empty_effect_support _, trivial, empty_effect_support _⟩
      · cases h
    · intro o d h; cases h
    · intro c cd m ms hc hm
      change (if c = "Example.Required" then some classDeclaration else none) = some cd at hc
      split at hc
      · cases hc
        change (if m = "run" then some method else none) = some ms at hm
        split at hm
        · cases hm; exact ⟨trivial, trivial, empty_effect_support _, trivial, empty_effect_support _⟩
        · cases hm
      · cases hc
    · intro f d h; cases h
  · intro C a p h; cases h
  · intro b s C ts hb _
    change (if b = "Example.required" then some requiredSignature else none) = some s at hb
    split at hb
    · cases hb; trivial
    · cases hb
  · intro b rs _; trivial
  · intro o t b ts h; cases h

private theorem names_complete (r : Range) : CheckTables.NamesComplete (input r) (program r) where
  defs := by
    intro n d h
    change (if n = "Example.main" then some (definition r) else none) = some d at h
    split at h
    · simp [input, ‹n = "Example.main"›]
    · cases h
  impls := by
    intro n id h
    change (if n = "Example.UnitRequired" then some (implementation r) else none) = some id at h
    split at h
    · simp [input, ‹n = "Example.UnitRequired"›]
    · cases h
  effects := by intro n os h; cases h
  operations := by intro n od h; cases h
  dataNames := by intro n info h; cases h
  ctorNames := by intro n cd h; cases h

private theorem accept_names_complete (r : Range) : CheckAccept.NamesComplete (input r) (program r) := by
  refine ⟨(names_complete r).defs, (names_complete r).impls, ?_⟩
  intro i id hi m mb hm
  change (if i = "Example.UnitRequired" then some (implementation r) else none) = some id at hi
  split at hi
  · cases hi
    change (if m = "run" then some (body r) else none) = some mb at hm
    split at hm
    · simp [input, ‹m = "run"›]
    · cases hm
  · cases hi

private theorem body_support (r : Range) : Check.BlockSupport (input r) (body r) := by
  refine ⟨⟨trivial, ?_, ?_⟩, trivial⟩
  · intro e he; cases he
  · intro rs hrs s hs
    change (if "Example.required" = "Example.required" then some requiredSignature else none) = some s at hs
    simp only [ite_true, Option.some.injEq] at hs
    subst s
    refine ⟨trivial, ?_, trivial⟩
    intro a ha
    simp [mapRangeAtoms] at ha

private theorem empty_hints_support (atoms : List Atom) : ({} : Hints).Support atoms :=
  ⟨trivial, by simp, by simp, by simp, by simp, by simp, by simp⟩

private theorem node_support {atoms : List Atom} (rule : Rule) {children : List Guide}
    (h : GuidesSupport atoms children) : (Guide.node rule {} children).Support atoms :=
  ⟨empty_hints_support atoms, h⟩


private theorem definition_support (r : Range) : CheckDeclarations.DefSupport (input r) (definition r) :=
  ⟨⟨trivial, empty_effect_support _⟩, body_support r⟩

private theorem implementation_support (r : Range) : CheckDeclarations.ImplSupport (input r) (implementation r) := by
  refine ⟨trivial, ?_, ?_⟩
  · intro m b hb
    change (if m = "run" then some (body r) else none) = some b at hb
    split at hb
    · cases hb; exact body_support r
    · cases hb
  · intro s u hu; cases hu

private theorem implementation_names_complete (r : Range) :
    CheckDeclarations.ImplNamesComplete (input r) (implementation r) where
  methods := by
    intro cd hc m hm
    change (if "Example.Required" = "Example.Required" then some classDeclaration else none) = some cd at hc
    simp only [ite_true, Option.some.injEq] at hc
    subst cd
    by_cases hm' : m = "run"
    · simp [input, hm']
    · simp [implementation, classDeclaration, hm'] at hm
  supers := by intro s u hu; cases hu

private theorem definitions_support (r : Range) :
    ∀ n d, (program r).defs n = some d → CheckDeclarations.DefSupport (input r) d := by
  intro n d hd
  change (if n = "Example.main" then some (definition r) else none) = some d at hd
  split at hd
  · cases hd; exact definition_support r
  · cases hd

private theorem implementations_support (r : Range) :
    ∀ i id, (program r).impls i = some id → CheckDeclarations.ImplSupport (input r) id := by
  intro i id hi
  change (if i = "Example.UnitRequired" then some (implementation r) else none) = some id at hi
  split at hi
  · cases hi; exact implementation_support r
  · cases hi

private theorem implementations_names_complete (r : Range) :
    ∀ i id, (program r).impls i = some id → CheckDeclarations.ImplNamesComplete (input r) id := by
  intro i id hi
  change (if i = "Example.UnitRequired" then some (implementation r) else none) = some id at hi
  split at hi
  · cases hi; exact implementation_names_complete r
  · cases hi

private theorem declarations_extend (r : Range) :
    CheckTables.Extends (input r).D (program r).declarations :=
  ⟨fun _ _ h => h, fun _ _ h => h, rfl, rfl, rfl, rfl, rfl⟩

/-- 二つのプログラムは、関数と実装メソッドの型付けの検査にともに成功する。 -/
theorem required_programs_checked :
    CheckTables.checkProgram (input (.path (.tree ["data"]))) (program (.path (.tree ["data"]))) = .ok () ∧
    CheckTables.checkProgram (input (.path (.tree ["other"]))) (program (.path (.tree ["other"]))) = .ok () := ⟨(by with_unfolding_all rfl), (by with_unfolding_all rfl)⟩

/-- 非空の規則は、正常値を返す実行を持つ。 -/
theorem required_rule_value : acceptInput.rules "Example.required" = some requiredRule ∧
    requiredRule.run [.path (.tree ["data"])] [] = some (.const .unit) := ⟨(by with_unfolding_all rfl), (by with_unfolding_all rfl)⟩

/-- 範囲の受理とは別に、両方の同じ本体は表層の規則で型付く。 -/
theorem required_programs_typed :
    (program (.path (.tree ["data"]))).WellTyped builtins (fun _ _ => none) ∧
    (program (.path (.tree ["other"]))).WellTyped builtins (fun _ _ => none) := by
  constructor
  · exact CheckTables.checkProgram_empty (input_sound _) (names_complete _) (definitions_support _)
      (implementations_support _) (implementations_names_complete _)
      rfl required_programs_checked.1
  · exact CheckTables.checkProgram_empty (input_sound _) (names_complete _) (definitions_support _)
      (implementations_support _) (implementations_names_complete _)
      rfl required_programs_checked.2

/-- 同じ成功結果から、宣言表の下での型付けと全本体の受理を得る。 -/
theorem required_entry_checked :
    CheckTables.CheckedUnder (program (.path (.tree ["data"]))) (input (.path (.tree ["data"]))) ∧
    CheckAccept.Accepted acceptInput (input (.path (.tree ["data"]))) (program (.path (.tree ["data"]))) :=
  checkProgramAccepted_sound (input_sound _) (names_complete _) (definitions_support _)
    (implementations_support _) (implementations_names_complete _)
    (declarations_extend _) (accept_names_complete _) (by with_unfolding_all rfl)

/-- 補完のない実入口が、関数と実装メソッドの型付けと必須の範囲判定の受理を同時に返す。 -/
theorem required_entry_accepted :
    (program (.path (.tree ["data"]))).WellTyped builtins (fun _ _ => none) ∧
    CheckAccept.Accepted acceptInput (input (.path (.tree ["data"]))) (program (.path (.tree ["data"]))) :=
  checkProgramAccepted_empty (input_sound _) (names_complete _) (definitions_support _)
    (implementations_support _) (implementations_names_complete _)
    rfl (accept_names_complete _) (by with_unfolding_all rfl)

/-- 実入口で受理した関数と実装メソッドの、全出現・全記録と未記録時の契約を得る。 -/
theorem required_entry_ranges :
    BodyRanges acceptInput (bodyKey "Example.main") (entryScope 0) (body (.path (.tree ["data"]))) ∧
    BodyRanges acceptInput (bodyKey (acceptInput.methodKey "Example.UnitRequired" "run"))
      (entryScope 0) (body (.path (.tree ["data"]))) :=
  ⟨required_entry_accepted.2.def_ranges (n := "Example.main") (d := definition (.path (.tree ["data"]))) (by with_unfolding_all rfl),
    required_entry_accepted.2.method_ranges (i := "Example.UnitRequired") (m := "run")
      (id := implementation (.path (.tree ["data"]))) (body := body (.path (.tree ["data"]))) (by with_unfolding_all rfl) (by with_unfolding_all rfl)⟩

/-- 型付けが同じく成功するもう一方の契約は、実入口で範囲の不一致として拒否する。 -/
theorem required_entry_rejected :
    checkProgramAccepted (input (.path (.tree ["other"]))) acceptInput (program (.path (.tree ["other"]))) =
      .error (.cover ⟨"Example.main", 0⟩ .notCovered) ∧
      ¬ CheckAccept.Accepted acceptInput (input (.path (.tree ["other"])))
        (program (.path (.tree ["other"]))) := by
  refine ⟨(by with_unfolding_all rfl), ?_⟩
  intro h
  have hh := h.1 "Example.main" (definition (.path (.tree ["other"]))) (by with_unfolding_all rfl)
  cases hh

private def materials (r : Range) : CheckTables.Materials where
  defs := [("Example.main", definition r)]
  classes := [("Example.Required", { methods := [("run", method)] })]
  impls := [("Example.UnitRequired", {
    signature := (implementation r).toImplSig
    methods := [("run", ⟨[], body r⟩)] })]

private theorem materials_program (r : Range) : (materials r).program = program r := by
  simp [materials, CheckTables.Materials.program, program, CheckTables.ClassMaterial.decl,
    CheckTables.ImplMaterial.decl, CheckTables.lookup, implementation, classDeclaration,
    eq_comm]
  exact ⟨rfl, rfl⟩

private theorem materials_declarations (r : Range) : (materials r).declarations = (program r).declarations :=
  (CheckTables.Materials.declarations_empty (m := materials r) rfl rfl).trans
    (congrArg Program.declarations (materials_program r))

private theorem materials_input (r : Range) : (materials r).input (input r) = input r := by
  have hd := materials_declarations r
  simp only [CheckTables.Materials.input, hd]
  congr 1
  funext i name
  by_cases hi : "Example.UnitRequired" = i <;> by_cases hm : "run" = name <;>
    simp [CheckTables.Materials.methodNames, materials, CheckTables.lookup, hi, hm]

private theorem materials_input_sound (r : Range) : ((materials r).input (input r)).Sound :=
  (materials r).input_sound (input r)
    (by intro c cd hc; cases hc)
    (by rw [materials_declarations r]; simpa only [input] using (input_sound r).tables)
    (input_sound r).sat (input_sound r).admits (input_sound r).ranges (input_sound r).operators

private theorem materials_definitions_support (r : Range) :
    ∀ n d, (materials r).program.defs n = some d → CheckDeclarations.DefSupport ((materials r).input (input r)) d := by
  simpa only [materials_input r, materials_program r] using definitions_support r

private theorem materials_implementations_support (r : Range) :
    ∀ i id, (materials r).program.impls i = some id → CheckDeclarations.ImplSupport ((materials r).input (input r)) id := by
  simpa only [materials_input r, materials_program r] using implementations_support r


/-- 有限材料から作った全定義・全実装の入口も、非空の規則表の下で型付けと受理を返す。 -/
theorem required_materials_entry_checked :
    CheckTables.CheckedUnder (materials (.path (.tree ["data"]))).program
      ((materials (.path (.tree ["data"]))).input (input (.path (.tree ["data"])))) ∧
    CheckAccept.Accepted acceptInput ((materials (.path (.tree ["data"]))).input (input (.path (.tree ["data"]))))
      (materials (.path (.tree ["data"]))).program :=
  CheckTables.Materials.checkProgramAccepted_sound (materials_input_sound _) (materials_definitions_support _)
    (materials_implementations_support _) (by with_unfolding_all rfl)

/-- 補完のない同じ有限材料では、自身の宣言表での型付けと全本体の受理を得る。 -/
theorem required_materials_entry_accepted :
    (materials (.path (.tree ["data"]))).program.WellTyped builtins (fun _ _ => none) ∧
    CheckAccept.Accepted acceptInput ((materials (.path (.tree ["data"]))).input (input (.path (.tree ["data"]))))
      (materials (.path (.tree ["data"]))).program :=
  CheckTables.Materials.checkProgramAccepted_empty (materials_input_sound _) (materials_definitions_support _)
    (materials_implementations_support _) rfl rfl (by with_unfolding_all rfl)

private def auxiliaryInput : Check.Input := input (.path (.tree ["data"]))

private def unitGuide : Guide := .node .E_Unit {} []

/-- 一つの式を持つ型の列に、全入力の列の健全性を適用する。 -/
theorem auxiliary_types :
    HasTypesQ auxiliaryInput.D auxiliaryInput.B auxiliaryInput.opPrim Qempty [] [] [] [] none
      (.cons .unit .nil) [.base .unit] Eff.empty := by
  simpa only [CheckAdmissible.NoFailCtxOf_nil] using
    (checkTypesAt_sound (q := auxiliaryInput) (rows := []) (Δ := []) (C := []) (Γ := []) (Φ := []) (R := none) (path := []) (ε := Eff.empty) (es := .cons .unit .nil) (as := [.base .unit]) (g := .node .Types_cons {} [unitGuide, .node .Types_nil {} []])
      (input_sound _) (by intro i kind h; cases i <;> cases h) (CtxSupport.empty _) trivial
      ⟨trivial, trivial⟩ ⟨trivial, trivial⟩ (empty_effect_support _)
      (node_support _ ⟨node_support _ trivial, node_support _ trivial, trivial⟩) (by with_unfolding_all rfl))

/-- 同じ型を持つ非空の式の列を検査する。 -/
theorem auxiliary_each :
    HasEachQ auxiliaryInput.D auxiliaryInput.B auxiliaryInput.opPrim Qempty [] [] [] [] none
      (.cons .unit .nil) (.base .unit) Eff.empty := by
  simpa only [CheckAdmissible.NoFailCtxOf_nil] using
    (checkEachAt_sound (q := auxiliaryInput) (rows := []) (Δ := []) (C := []) (Γ := []) (Φ := []) (R := none) (path := []) (ε := Eff.empty) (es := .cons .unit .nil) (a := .base .unit) (g := .node .Each_cons {} [unitGuide, .node .Each_nil {} []])
      (input_sound _) (by intro i kind h; cases i <;> cases h) (CtxSupport.empty _) trivial
      ⟨trivial, trivial⟩ trivial (empty_effect_support _)
      (node_support _ ⟨node_support _ trivial, node_support _ trivial, trivial⟩) (by with_unfolding_all rfl))

/-- 固定した式と穴を持つ引数の列で、固定した式の型付けを得る。 -/
theorem auxiliary_fixed :
    HasFixedQ auxiliaryInput.D auxiliaryInput.B auxiliaryInput.opPrim Qempty [] [] [] [] none
      (.expr none 0 .unit (.hole none 1 (.base .unit) .nil)) [.base .unit] Eff.empty := by
  simpa only [CheckAdmissible.NoFailCtxOf_nil] using
    (checkFixedAt_sound (q := auxiliaryInput) (rows := []) (Δ := []) (C := []) (Γ := []) (Φ := []) (R := none) (path := []) (ε := Eff.empty) (args := .expr none 0 .unit (.hole none 1 (.base .unit) .nil)) (as := [.base .unit])
      (g := .node .Fixed_expr {} [unitGuide, .node .Fixed_hole {} [.node .Fixed_nil {} []]])
      (input_sound _) (by intro i kind h; cases i <;> cases h) (CtxSupport.empty _) trivial
      ⟨trivial, trivial, trivial⟩ ⟨trivial, trivial⟩ (empty_effect_support _)
      (node_support _ ⟨node_support _ trivial, node_support _ ⟨node_support _ trivial, trivial⟩, trivial⟩) (by with_unfolding_all rfl))

/-- 正常なUnit値を照合する非空の腕は、scrutineeを束縛した文脈で型付く。 -/
theorem auxiliary_arms :
    HasArmsQ auxiliaryInput.D auxiliaryInput.B auxiliaryInput.opPrim Qempty [] [] [some (.base .unit)] [] none .tail
      (.cons [⟨.unit, []⟩] none (.last .unit) .nil) (.base .unit) (.base .unit) Eff.empty := by
  simpa only [CheckAdmissible.NoFailCtxOf_nil] using
    (checkArmsAt_sound (q := auxiliaryInput) (rows := []) (Δ := []) (C := []) (Γ := [some (.base .unit)]) (Φ := []) (R := none) (path := []) (ε := Eff.empty) (arms := .cons [⟨.unit, []⟩] none (.last .unit) .nil) (a := .base .unit) (b := .base .unit) (p := .tail)
      (g := .node .Arms_plain {} [.node .B_Last {} [unitGuide], .node .Arms_nil {} []])
      (input_sound _) (by intro i kind h; cases i <;> cases h)
      ((CtxSupport.empty _).extend (a := .base .unit) trivial) trivial
      ⟨trivial, trivial, trivial⟩ trivial trivial (empty_effect_support _)
      (node_support _ ⟨node_support _ ⟨node_support _ trivial, trivial⟩, node_support _ trivial, trivial⟩) (by with_unfolding_all rfl))

/-- 空のハンドラ節に対する適用。空の列の規則だけを使う自明な場合である。 -/
theorem auxiliary_empty_clauses :
    HasClausesQ auxiliaryInput.D auxiliaryInput.B auxiliaryInput.opPrim Qempty [] [] [] [] none
      Eff.empty .nil (.base .unit) Eff.empty := by
  simpa only [CheckAdmissible.NoFailCtxOf_nil] using
    (checkClausesAt_sound (q := auxiliaryInput) (rows := []) (Δ := []) (C := []) (Γ := []) (Φ := []) (R := none) (path := []) (ε := Eff.empty) (cs := .nil) (εbody := Eff.empty) (a := .base .unit) (g := .node .Clauses_nil {} [])
      (input_sound _) (by intro i kind h; cases i <;> cases h) (CtxSupport.empty _) trivial trivial
      (empty_effect_support _) trivial (empty_effect_support _) (node_support _ trivial) (by with_unfolding_all rfl))

end Benitoite.Release.Refinement.Surface.CheckExamples
