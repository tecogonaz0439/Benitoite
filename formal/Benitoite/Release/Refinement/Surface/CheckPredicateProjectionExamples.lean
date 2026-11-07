import Benitoite.Release.Refinement.Surface.CheckEntrypointsSound
import Benitoite.Release.Refinement.Surface.CheckAccept
import Benitoite.Release.Refinement.Surface.CheckDeclarationsSound
import Benitoite.Release.Refinement.Surface.PredicateProjectionFixture
import Benitoite.Release.Refinement.Surface.PredicateStandardSupport

/-! # レコードの欄の判定と、条件分岐の事実の実入口の例 -/
namespace Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples
open PredicateRows PredicateResponse PredicateProjection PredicateAccessorPaths
open PredicateProjectionFixture
noncomputable section

private def textRef : FieldRef := ⟨"Predicate.Box", "Predicate.Box.make", 0, .string⟩
private def innerRef : FieldRef := ⟨"Predicate.Outer", "Predicate.Outer.make", 0, .data⟩
private def numberRef : FieldRef := ⟨"Predicate.Box", "Predicate.Box.make", 1, .float64⟩

private def textProjection : Projection :=
  ⟨1, "Predicate.Box", [textRef], .characters 'a' 'z'⟩

private def numberProjection : Projection :=
  ⟨1, "Predicate.Outer", [innerRef, numberRef], .floating .binary64 .finite⟩

private def rows : Table.Rows :=
  [("%Predicate.text", .projected textProjection),
   ("%Predicate.number", .projected numberProjection)]

private def getter (f : FunName) (type : Ty) (receiver : Expr) : Expr :=
  .call (.funName f [type] [] []) [some "value"] [0] (.cons receiver .nil)

private def textSource (type : Ty) : Expr := getter "Predicate.Box.text" type (.local 0)

private def numberSource (type childType : Ty) : Expr :=
  getter "Predicate.Box.number" childType (getter "Predicate.Outer.inner" type (.local 0))

private def textCondition (type : Ty) : Expr :=
  PredicateProjectionCalls.resolveCall rows program "String.charactersIn"
    [some "text", some "minimum", some "maximum"] [0, 1, 2]
    (.cons (textSource type) (.cons (.literal (.character 'a'))
      (.cons (.literal (.character 'z')) .nil)))

private def numberCondition (type childType : Ty) : Expr :=
  PredicateProjectionCalls.resolveCall rows program "Float.isFinite" [none] [0]
    (.cons (numberSource type childType) .nil)

private def textStep (type : Ty) : PredicateAccessorTargets.Step :=
  ⟨"Predicate.Box.text", "Predicate.Box.make", box, 0, [type], .string⟩

private def innerStep (type : Ty) : PredicateAccessorTargets.Step :=
  ⟨"Predicate.Outer.inner", "Predicate.Outer.make", outer, 0, [type], .data⟩

private def numberStep (type : Ty) : PredicateAccessorTargets.Step :=
  ⟨"Predicate.Box.number", "Predicate.Box.make", box, 1, [type], .float64⟩

private def textParsed (type : Ty) : PredicateAccessorTargets.Parsed program (textSource type) :=
  ⟨.local 0, .var 0, .field textRef (.var 0), [textStep type],
    .accessor (s := textStep type) rfl rfl rfl rfl rfl rfl (by decide) (.value rfl rfl)⟩

private def numberParsed (type childType : Ty) : PredicateAccessorTargets.Parsed program
    (numberSource type childType) :=
  ⟨.local 0, .var 0, .field numberRef (.field innerRef (.var 0)), [innerStep type, numberStep childType],
    .accessor (s := numberStep childType) rfl rfl rfl rfl rfl rfl (by decide)
      (.accessor (s := innerStep type) rfl rfl rfl rfl rfl rfl (by decide) (.value rfl rfl))⟩

private theorem parsed_text (type : Ty) :
    PredicateAccessorTargets.parse program (textSource type) = some (textParsed type) :=
  (textParsed type).sound.parse

private theorem parsed_number (type childType : Ty) :
    PredicateAccessorTargets.parse program (numberSource type childType) =
      some (numberParsed type childType) :=
  (numberParsed type childType).sound.parse

private theorem stripped_text (type : Ty) :
    PredicateCalls.stripParens (textSource type) = textSource type := rfl

private theorem stripped_number (type childType : Ty) :
    PredicateCalls.stripParens (numberSource type childType) = numberSource type childType := rfl

private theorem stripped_literal (literal : Literal) :
    PredicateCalls.stripParens (.literal literal) = .literal literal := rfl

section
attribute [local cbv_opaque] PredicateAccessorTargets.parse PredicateCalls.stripParens program textSource numberSource
attribute [local cbv_eval] parsed_text parsed_number stripped_text stripped_number stripped_literal

private theorem text_condition (type : Ty) : textCondition type =
    PredicateProjectionCalls.encodedCall "%Predicate.text" [type] textProjection
      (.local 0) (textSource type) (.var 0) := by cbv

private theorem number_condition (type childType : Ty) : numberCondition type childType =
    PredicateProjectionCalls.encodedCall "%Predicate.number" [type] numberProjection
      (.local 0) (numberSource type childType) (.var 0) := by cbv

private theorem text_resolved (type : Ty) :
    PredicateProjectionCalls.resolve rows program (.characters 'a' 'z') (textSource type) =
      some (textCondition type) := by cbv

private theorem number_resolved (type childType : Ty) :
    PredicateProjectionCalls.resolve rows program (.floating .binary64 .finite)
      (numberSource type childType) = some (numberCondition type childType) := by cbv

private theorem text_candidate :
    PredicateProjectionCalls.candidate (textParsed (.base .unit)) (.characters 'a' 'z') =
      some (textProjection, [.base .unit]) := by rfl

private theorem number_candidate :
    PredicateProjectionCalls.candidate (numberParsed (.base .unit) (.base .unit)) (.floating .binary64 .finite) =
      some (numberProjection, [.base .unit]) := by rfl

private def textChain : CheckedChain textProjection.input (textParsed (.base .unit)).steps :=
  (checkChain textProjection.input (textParsed (.base .unit)).steps).get (by cbv)

private def numberChain : CheckedChain numberProjection.input (numberParsed (.base .unit) (.base .unit)).steps :=
  (checkChain numberProjection.input (numberParsed (.base .unit) (.base .unit)).steps).get (by cbv)

/-- 別の型名を持つ受け手からは、同じ欄の経路を生成しない。 -/
theorem wrong_receiver_chain :
    (checkChain textProjection.input (numberParsed (.base .unit) (.base .unit)).steps).isNone = true := by
  simp [checkChain, textProjection, Projection.input, numberParsed, innerStep, outer]

/-- ソースの取り出しを解析した結果から、元の受け手だけを渡す脱糖を得る。 -/
theorem text_desugar :
    ∃ name types projection value,
      rows.lookup name = some (.projected projection) ∧
      desugarExpr (fun _ _ => none) .other (textCondition (.base .unit)) =
        .app (.prim name types [] []) [value] :=
  PredicateProjectionCalls.resolve_desugar
    (rows := rows) (p := program) (entry := .characters 'a' 'z')
    (source := textSource (.base .unit))
    (output := textCondition (.base .unit)) (text_resolved _) (fun _ _ => none) .other

/-- 同じ解決結果の型付けは、元の取り出しを純粋に再検査した証拠を含む。 -/
theorem text_source_checked {D B op Q Δ C Γ Φ R position a ε}
    (typed : HasTypeQ D B op Q Δ C Γ Φ R position
      (textCondition (.base .unit)) a ε) :
    ∃ input, HasTypeQ D B op Q Δ C Γ Φ R .other (textSource (.base .unit)) input Eff.empty :=
  PredicateProjectionCalls.resolve_source_checked
    (rows := rows) (program := program) (entry := .characters 'a' 'z') (text_resolved _) typed

end

attribute [local cbv_opaque] textCondition numberCondition
attribute [local cbv_eval] text_condition number_condition

private def input : Check.Input where
  D := program.declarations
  builtinSource := .predicates data rows
  opPrim := fun _ _ => none
  formation := {formation with atoms := PredicateStandardSupport.atoms}
  satDec := fun _ _ parameter => !parameter.equality && !parameter.key
  admitsDec := fun b _ ts =>
    decide (b = "%Predicate.text" ∨ b = "%Predicate.number") && decide (ts.length = 1)
  proofSteps := 200
  ctorNames := ["Predicate.Box.make", "Predicate.Outer.make"]

private theorem signature_support (projection : Projection) :
    projection.signature.tel.Support (· ∈ ([] : List Atom)) := by
  cases projection.entry <;> try (rename_i width test; cases width <;> cases test)
  all_goals simp [Projection.signature, Projection.input, Projection.result,
    PrimSig.tel, signatureTel, Entry.result, Entry.predicate, agreement, agreementAt,
    FloatTest.predicate, Ty.Support, Ty.SupportList, Tel.Support, Eff.Support, Eff.empty]
  all_goals apply Ty.SupportList.iff.mpr
  all_goals intro a ha
  all_goals obtain ⟨i, hi, rfl⟩ := List.mem_map.mp ha
  all_goals trivial

private theorem signature_scoped (projection : Projection)
    (hformation : formation.Sound program.declarations.core)
    (shape : projection = textProjection ∨ projection = numberProjection) :
    PrimSig.Scoped program.declarations.core projection.signature := by
  rcases shape with rfl | rfl
  all_goals constructor
  all_goals first
    | (apply CheckFormation.kindTy_sound hformation.ctors; cbv)
    | (apply CheckFormation.sortedTel_sound; cbv)
    | (apply CheckFormation.declaredTel_sound (path := []) hformation
        (by intro i a hi; cases i <;> cases hi)
        (signature_support _); cbv)
    | simp [textProjection, numberProjection, textRef, innerRef, numberRef,
        Projection.signature, Projection.input, Projection.result, Entry.result,
        Entry.predicate, agreement, agreementAt, FloatTest.predicate, PrimSig.tel,
        signatureTel, NamesWF, Ty.SourceScoped, Ty.WF, Tel.WF, Ty.WFList,
        Ty.RowsIn, Tel.RowsIn, Ty.RowsInList, Eff.RowsIn, Ty.RangesScoped,
        Tel.RangesScoped, rangesScopedTypes, Eff.RangesScoped, Eff.WF,
        Eff.empty, Eff.Canonical, Eff.norm, Ty.normTys, Pred.WF, Pred.VarsIn,
        Term.VarsIn, routeTerm, Ty.NotContCore]

private theorem text_valid : Valid program.declarations.core textProjection :=
  PredicateAccessorPaths.Parsed.valid_projection (textParsed (.base .unit)) formed text_candidate textChain.proof (by cbv) trivial
    (PredicateProjectionCalls.candidate_sorted text_candidate)
    (signature_scoped _ formation_sound (Or.inl rfl))

private theorem number_valid : Valid program.declarations.core numberProjection :=
  PredicateAccessorPaths.Parsed.valid_projection (numberParsed (.base .unit) (.base .unit)) formed number_candidate numberChain.proof (by cbv) trivial
    (PredicateProjectionCalls.candidate_sorted number_candidate)
    (signature_scoped _ formation_sound (Or.inr rfl))

/-- 各段の宣言と取り出しの整形式から、内部行の全入力に使う経路を構成する。 -/
theorem rows_valid : rows.Valid program.declarations.core := by
  constructor
  · intro name row member
    simp only [rows, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at member
    rcases member with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    · exact text_valid
    · exact number_valid
  · intro name row member
    simp only [rows, List.mem_cons, List.not_mem_nil, or_false, Prod.mk.injEq] at member
    rcases member with ⟨rfl, rfl⟩ | ⟨rfl, rfl⟩
    all_goals refine ⟨?_, by decide, by decide, by decide, by decide⟩
    all_goals intro hm
    all_goals change _ ∈ StandardModel.Primitive.all.map StandardModel.Primitive.name at hm
    all_goals obtain ⟨primitive, _, he⟩ := List.mem_map.mp hm
    all_goals
      have fresh : primitive.name ≠ "%Predicate.text" ∧ primitive.name ≠ "%Predicate.number" := by
        cases primitive <;> decide
    all_goals first | exact fresh.1 he | exact fresh.2 he

/-- 型引数を具体化した二段の経路の全入力に、同じ真偽と述語を結ぶ応答を与える。 -/
theorem nested_response {B Ψ name types effectRows ranges values a e}
    (args : BuiltinArgs program.declarations.core B Ψ name numberProjection.signature
      types effectRows ranges values a e) :
    ∃ out, numberProjection.delta types effectRows ranges values = some out ∧
      Outcome.Typed program.declarations.core B Ψ out a ∧ AdequateResult values out ∧
      ∀ n, out ≠ .exit n :=
  PredicateProjection.response numberProjection number_valid formed.types variance args

private theorem text_signature : (Table.builtins data rows).sig "%Predicate.text" = some textProjection.signature :=
  Table.lookup_signature (name := "%Predicate.text") (entry := .projected textProjection) data rows_valid rfl

private theorem number_signature : (Table.builtins data rows).sig "%Predicate.number" = some numberProjection.signature :=
  Table.lookup_signature (name := "%Predicate.number") (entry := .projected numberProjection) data rows_valid rfl

/-- 標準表と二つの内部行を合成した入力は、全署名の支持と許容判定の対応を満たす。 -/
theorem input_sound : input.Sound := by
  refine ⟨?_, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, ?_, ?_, ?_, ?_⟩
  · refine ⟨formation_sound.ctors, ?_⟩
    intro c cd hc
    exact Ty.supportList_mono _ (formation_sound.fields c cd hc) (by intro a ha; cases ha)
  · intro i d found; cases found
  · exact fun _ _ found => funs_support _ found
  · exact fun _ _ found => PredicateStandardSupport.table data rows found
  · intro o d found; cases found
  · intro c cd m ms found; cases found
  · intro f d found; cases found
  · intro C a p accepted
    have flags : p.equality = false ∧ p.key = false := by
      simpa only [input, Bool.and_eq_true, Bool.not_eq_true'] using accepted
    cases p with
    | mk eq key =>
      obtain ⟨rfl,rfl⟩ := flags
      exact ModelConstraints.sat_unconstrained _ _ _
  · intro name signature C types found accepted
    have chosen : (name = "%Predicate.text" ∨ name = "%Predicate.number") ∧ types.length = 1 := by
      simpa only [input, Bool.and_eq_true, decide_eq_true_eq] using accepted
    change (Table.builtins data rows).sig name = some signature at found
    rcases chosen.1 with rfl | rfl
    · rw [text_signature] at found
      cases found
      exact chosen.2
    · rw [number_signature] at found
      cases found
      exact chosen.2
  · intro name ranges accepted; cases accepted
  · intro op type name types found; cases found

attribute [local cbv_opaque] Table.builtins data rows
attribute [local cbv_eval] text_signature number_signature

/-- 欄を含む事実をUnitの注釈で要求する。注釈の自己変数の分だけ受け手を持ち上げる。 -/
private def branch (projection : Projection) (positive : Bool) : Block :=
  let p := projection.entry.predicate (routeTerm (.var 1) projection.route)
  .lastBind .bind (.refined (.base .unit) (if positive then p else .not p)) .unit

private def expression (projection : Projection) (condition : Expr) (facts : Bool) : Expr :=
  .ite (if facts then condition else .literal (.boolean true))
    (branch projection true) (branch projection false)

private def textChecked (facts : Bool) : Check.Result Check.Inferred :=
  Check.checkExpr input [] [some (.data "Predicate.Box" [.base .unit])] [] none .other []
    (expression textProjection (textCondition (.base .unit)) facts)

private def numberChecked (facts : Bool) : Check.Result Check.Inferred :=
  Check.checkExpr input [] [some (.data "Predicate.Outer" [.base .unit])] [] none .other []
    (expression numberProjection (numberCondition (.base .unit) (.base .unit)) facts)

/-- 一段の文字列欄について、両枝が要求する事実を実入口が受理する。 -/
theorem text_branches :
    textChecked true = .ok (.base .unit, Eff.empty) ∧ (textChecked false).toBool = false := by
  cbv <;> simp [Eff.atoms]

/-- 型パラメータを持つ二段の欄についても、同じ受け手の分類を両枝へ加える。 -/
theorem nested_float_branches :
    numberChecked true = .ok (.base .unit, Eff.empty) ∧ (numberChecked false).toBool = false := by
  cbv <;> simp [Eff.atoms]

private def openType : Ty := .scoped "Scope.PathIn" .path (.rvar 0)

/-- 開いた型引数の解決も、同じ開いた文脈の元の取り出しの型付けを残す。 -/
theorem open_number_source_checked {D B ks op Q Δ C Γ Φ R position a ε}
    (typed : OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R position
      (numberCondition openType openType) a ε) :
    ∃ input, OpenSurface.HasTypeQ D B ks op Q Δ C Γ Φ R .other
      (numberSource openType openType) input Eff.empty :=
  PredicateProjectionCalls.resolve_source_checked_open
    (rows := rows) (program := program) (entry := .floating .binary64 .finite) (number_resolved _ _) typed

private def definition (projection : Projection) (condition : Expr) : Def where
  tparams := []
  neffs := 0
  names := ["receiver"]
  params := [.data projection.owner [openType]]
  ret := .base .unit
  eff := Eff.empty
  rangeParams := [.path]
  body := .last (expression projection condition true)

/-- 範囲変数を含む型引数を取り出しへ渡しても、関数の本体を開いたまま検査する。 -/
theorem open_type_arguments :
    CheckDeclarations.checkDef input []
      (definition textProjection (textCondition openType)) = .ok () ∧
    CheckDeclarations.checkDef input []
      (definition numberProjection (numberCondition openType openType)) = .ok () := by
  cbv

/-- 内側の取り出しに異なる型引数を書くと、保持した元の式の検査が拒否する。 -/
theorem wrong_child_type :
    (Check.checkExpr input [] [some (.data "Predicate.Outer" [.base .unit])] [] none .other []
      (numberCondition (.base .unit) (.base .string))).toBool = false ∧
    (CheckDeclarations.checkDef input []
      (definition numberProjection (numberCondition openType (.base .unit)))).toBool = false := by
  cbv

private theorem getter_supported (f : FunName) {receiver : Expr}
    (hr : Check.ExprSupport input receiver) :
    Check.ExprSupport input (getter f (.base .unit) receiver) :=
  ⟨CheckArguments.function_empty_support (by trivial) (by simp), hr, trivial⟩

private theorem text_source_support : Check.ExprSupport input (textSource (.base .unit)) :=
  getter_supported _ (by trivial)

private theorem text_condition_support : Check.ExprSupport input (textCondition (.base .unit)) := by
  rw [text_condition]
  have head := CheckArguments.primitive_empty_support (b := "%Predicate.text") (ts := [.base .unit])
    input_sound.tables (by trivial)
  simpa [Check.ExprSupport, CheckSource.ExprSupport, CheckSource.HolesSupport,
    PredicateProjectionCalls.encodedCall, Projection.result, Entry.result,
    Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using ⟨head, text_source_support⟩

private theorem text_context_support : CheckFormation.CtxSupport input.formation.atoms
    [some (.data "Predicate.Box" [.base .unit])] := by
  intro i a found
  cases i <;> simp at found
  cases found
  trivial

private theorem text_condition_success :
    Check.checkExpr input [] [some (.data "Predicate.Box" [.base .unit])] [] none .other []
      (textCondition (.base .unit)) = .ok (textProjection.result (.var 1), Eff.empty) := by
  cbv <;> simp [Eff.atoms]

/-- 投影の検査の成功を、標準表と内部行の同じ入力の健全性から型付けへ移す。 -/
theorem text_condition_typed :
    HasTypeQ input.D input.B input.opPrim Qempty [] []
      [some (.data "Predicate.Box" [.base .unit])] [] none .other
      (textCondition (.base .unit)) (textProjection.result (.var 1)) Eff.empty :=
  (Check.checkExpr_sound input_sound text_context_support (by trivial) text_condition_support
    (by trivial) (Check.empty_effect_support _) text_condition_success).1

/-- 元の取り出しの型付けの仮定は、同じ入力の検査の成功から実際に満たせる。 -/
theorem text_source_derivation :
    ∃ a, HasTypeQ input.D input.B input.opPrim Qempty [] []
      [some (.data "Predicate.Box" [.base .unit])] [] none .other
      (textSource (.base .unit)) a Eff.empty :=
  text_source_checked text_condition_typed

private def openInput : Check.Input :=
  { input with formation := {input.formation with rangeKinds := [.path]} }

private theorem open_input_sound : CheckOpen.OpenSound openInput := by
  refine ⟨?_, constructors_complete, ?_⟩
  · exact ⟨⟨input_sound.formation.ctors, input_sound.formation.fields⟩, input_sound.tables,
      input_sound.sat, input_sound.admits, input_sound.ranges, input_sound.operators⟩
  · cbv

private def openContext : Ctx := [some (.data "Predicate.Outer" [openType])]

private def openNumberGuide : Check.Guide :=
  let inferred := CheckOpenInfer.inferExprFuel
    (4 * sizeOf (numberCondition openType openType) + 4) openInput ⟨openInput.logicCertificates⟩ [] [] [] openContext [] none .other []
    (numberCondition openType openType)
  CheckFinite.guide openInput.formation.atoms
    (match inferred with | .ok result => result.guide | .error _ => .unknown)

private theorem open_number_support : Check.ExprSupport openInput (numberCondition openType openType) := by
  rw [number_condition]
  have head := CheckArguments.primitive_empty_support (b := "%Predicate.number") (ts := [openType])
    open_input_sound.toSound.tables (by trivial)
  have functionHead : ∀ f, CheckArguments.HeadInputsSupport openInput.formation openInput.B
      (.funName f [openType] [] []) := fun _ =>
    CheckArguments.function_empty_support (by trivial) (by simp)
  simpa [Check.ExprSupport, CheckSource.ExprSupport, CheckSource.ExprsSupport, CheckSource.HolesSupport,
    PredicateProjectionCalls.encodedCall, Projection.result, Entry.result, numberSource, getter,
    Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using
      ⟨head, functionHead "Predicate.Box.number", functionHead "Predicate.Outer.inner"⟩

/-- 開いた型引数を持つ二段の投影も、実際の推論の案内を再検査して型付ける。 -/
theorem open_number_condition_typed :
    OpenSurface.HasTypeQ openInput.D openInput.B [.path] openInput.opPrim Qempty [] [] openContext [] none .other
      (numberCondition openType openType) (numberProjection.result (.var 1)) Eff.empty := by
  have hQ : CheckAdmissible.NoFailCtxOf [] = Qempty := by
    funext i
    apply propext
    simp [CheckAdmissible.NoFailCtxOf, Qempty]
  rw [← hQ]
  apply (CheckOpen.guideSound openNumberGuide).expr (q := openInput) (rows := [])
    (Δ := []) (C := []) (Γ := openContext) (Φ := []) (R := none) (p := .other) (path := []) open_input_sound (by intro i k h; cases i <;> cases h)
    ?_ (by trivial) open_number_support (by trivial) (Check.empty_effect_support _)
    (CheckFinite.guide_support _ _) ?_
  · intro i a found
    cases i <;> simp [openContext] at found
    cases found
    trivial
  · cbv <;> simp [Eff.atoms]

/-- 開いた元の取り出しも、型付けを仮定せずに導出する。 -/
theorem open_number_source_derivation :
    ∃ a, OpenSurface.HasTypeQ openInput.D openInput.B [.path] openInput.opPrim Qempty [] [] openContext [] none .other
      (numberSource openType openType) a Eff.empty :=
  open_number_source_checked open_number_condition_typed

private def publicTextCondition : Expr :=
  .call (.primName "String.charactersIn" [] [] []) [some "text", some "minimum", some "maximum"] [0,1,2]
    (.cons (textSource (.base .unit)) (.cons (.literal (.character 'a')) (.cons (.literal (.character 'z')) .nil)))

private def sourceDefinition (facts : Bool) : Def where
  tparams := []
  neffs := 0
  names := ["receiver"]
  params := [.data "Predicate.Box" [.base .unit]]
  ret := .base .unit
  eff := Eff.empty
  body := .last (expression textProjection publicTextCondition facts)

private def sourceProgram (facts : Bool) : Program :=
  { program with defs := fun name => if name = "sourcePredicate" then some (sourceDefinition facts) else none }

private def sourceInput (facts : Bool) : Check.Input :=
  { input with
    D := (sourceProgram facts).declarations
    builtinSource := .predicates data []
    admitsDec := fun _ _ _ => false
    defs := ["sourcePredicate"] }

private def required : CheckAccept.AcceptInput where
  ok := "Ok"
  rules := fun _ => none
  limits := ⟨⟨100,100⟩,⟨100,100⟩⟩
  methodKey := fun i m => i ++ "." ++ m

private theorem source_input_sound (facts : Bool) : (sourceInput facts).Sound := by
  refine ⟨input_sound.formation, ⟨⟨?_⟩, ?_, ?_, ?_, ?_, ?_⟩, input_sound.sat, ?_, ?_, input_sound.operators⟩
  · intro i d found; cases found
  · intro name d found
    by_cases hn : name = "sourcePredicate"
    · subst name
      have same : d = (sourceDefinition facts).toFunDecl := by
        simpa only [sourceInput, sourceProgram, Program.declarations, Program.declarationsFor,
          Program.lookupFun, ite_true, Option.some.injEq] using found.symm
      subst d
      simp [CheckArguments.SignatureSupport, sourceDefinition, FunDecl.coreNames, FunDecl.coreParams,
        FunDecl.dictTys, FunDecl.tel, internalNames, signatureTel, Ty.Support, Ty.SupportList,
        Tel.Support, Eff.Support, Eff.empty]
    · have same : (sourceInput facts).D.funs name = program.declarations.funs name := by
        simp only [sourceInput, sourceProgram, Program.declarations, Program.declarationsFor, Program.lookupFun,
          program, hn, ite_false]
      rw [same] at found
      exact funs_support _ found
  · intro name signature found
    exact PredicateStandardSupport.table data [] found
  · intro o d found; cases found
  · intro c cd m ms found; cases found
  · intro f d found; cases found
  · intro name signature C types found accepted; cases accepted
  · intro name ranges accepted; cases accepted

section

private theorem source_program_defs (facts : Bool) (name : FunName) :
    (sourceProgram facts).defs name = if name = "sourcePredicate" then some (sourceDefinition facts) else none := rfl
private theorem resolve_text_identity (resolver) :
    PredicateCalls.resolveExprWith resolver (textSource (.base .unit)) = textSource (.base .unit) := rfl

private def sourceTextParsed : PredicateAccessorTargets.Parsed (sourceProgram true) (textSource (.base .unit)) :=
  ⟨.local 0, .var 0, .field textRef (.var 0), [textStep (.base .unit)],
    .accessor (s := textStep (.base .unit)) rfl rfl rfl rfl rfl rfl (by decide) (.value rfl rfl)⟩

private theorem source_parsed_text :
    PredicateAccessorTargets.parse (sourceProgram true) (textSource (.base .unit)) = some sourceTextParsed :=
  sourceTextParsed.sound.parse

attribute [local cbv_opaque] PredicateAccessorTargets.parse sourceProgram textSource
attribute [local cbv_eval] source_parsed_text source_program_defs resolve_text_identity stripped_text stripped_literal

private def sourceRows : Table.Rows := [("%Predicate.0", .projected textProjection)]

private def sourceResolvedDefinition : Def :=
  { sourceDefinition true with
    body := .last (expression textProjection
      (PredicateProjectionCalls.encodedCall "%Predicate.0" [.base .unit] textProjection
        (.local 0) (textSource (.base .unit)) (.var 0)) true) }

private theorem source_names_inventory :
    PredicateGeneratedNames.sourceNames (sourceInput true) (sourceProgram true) = ["String.charactersIn"] := by
  rfl

private theorem source_prepared :
    CheckPreparation.prepare (sourceInput true) (sourceProgram true) =
      ⟨CheckPreparation.input (sourceInput true) sourceRows,
       CheckPreparation.resolveProgram sourceRows (sourceProgram true)⟩ := by
  unfold CheckPreparation.prepare PredicateGeneratedNames.forbidden
  rw [source_names_inventory]
  cbv

private theorem source_definitions (name : FunName) :
    (CheckPreparation.prepare (sourceInput true) (sourceProgram true)).program.defs name =
      if name = "sourcePredicate" then some sourceResolvedDefinition else none := by
  rw [source_prepared]
  by_cases hn : name = "sourcePredicate"
  · subst name
    cbv
  · simp only [CheckPreparation.resolveProgram, sourceProgram, hn, ite_false, Option.map_none]

private theorem source_prepared_final :
    CheckPreparation.prepare (sourceInput true) (sourceProgram true) =
      ⟨CheckPreparation.input (sourceInput true) sourceRows,
       {sourceProgram true with defs := fun name => if name = "sourcePredicate" then some sourceResolvedDefinition else none}⟩ := by
  rw [source_prepared]
  congr 1
  unfold CheckPreparation.resolveProgram
  congr 1
  · funext name
    simpa only [source_prepared, CheckPreparation.resolveProgram] using source_definitions name

end

/-- レコード欄の公開呼出しも、手で解決せずに全プログラムの実入口へ渡す。 -/
theorem source_entry :
    CheckTables.checkProgram (sourceInput true) (sourceProgram true) = .ok () ∧
    CheckAccept.checkProgramAccepted (sourceInput true) required (sourceProgram true) = .ok () ∧
    (CheckTables.checkProgram (sourceInput false) (sourceProgram false)).toBool = false := by
  simp only [CheckAccept.checkProgramAccepted, CheckTables.checkProgram, source_prepared_final]
  cbv <;> simp [Eff.atoms]

private theorem source_names : CheckTables.NamesComplete (sourceInput true) (sourceProgram true) := by
  refine ⟨?_, ?_, ?_, ?_, ?_, constructors_complete⟩
  · intro name d found
    change (if name = "sourcePredicate" then some (sourceDefinition true) else none) = some d at found
    split at found
    · simp [sourceInput, ‹name = "sourcePredicate"›]
    · cases found
  · intro name id found; cases found
  · intro name operations found; cases found
  · intro name operation found; cases found
  · intro name info found; cases found

/-- 公開の欄の判定を含む実入口の成功から、標準表と内部行の下で全プログラムを型付ける。 -/
theorem source_typed :
    CheckTables.CheckedUnder
      (CheckPreparation.prepare (sourceInput true) (sourceProgram true)).program
      (CheckPreparation.prepare (sourceInput true) (sourceProgram true)).input := by
  have sound := CheckPreparation.prepare_sound (source_input_sound true) (sourceProgram true)
  apply CheckTables.checkProgram_sound (q := sourceInput true) (p := sourceProgram true)
    sound (CheckTables.prepare_names source_names) ?_ ?_ ?_ ?_ source_entry.1
  · intro name d found
    rw [source_definitions] at found
    rw [source_prepared]
    split at found
    · cases found
      constructor
      · simp [sourceResolvedDefinition, sourceDefinition, FunDecl.coreNames, FunDecl.coreParams,
          FunDecl.dictTys, FunDecl.tel, internalNames, signatureTel, Ty.Support, Ty.SupportList,
          Tel.Support, Eff.Support, Eff.empty]
      · have head := CheckArguments.primitive_empty_support (b := "%Predicate.0") (ts := [.base .unit])
          sound.tables (by trivial)
        rw [source_prepared] at head
        have getterHead := CheckArguments.function_empty_support
          (q := (CheckPreparation.input (sourceInput true) sourceRows).formation)
          (B := (CheckPreparation.input (sourceInput true) sourceRows).B)
          (f := "Predicate.Box.text") (ts := [.base .unit]) (es := []) (by trivial) (by simp)
        simpa [Check.BlockSupport, CheckSource.BlockSupport, CheckSource.ExprSupport, CheckSource.ExprsSupport,
          CheckSource.HolesSupport, sourceResolvedDefinition, expression, branch,
          PredicateProjectionCalls.encodedCall, textSource, getter, Projection.result, Entry.result,
          Ty.Support, Ty.SupportList, Eff.Support, Eff.empty] using ⟨head, getterHead⟩
    · cases found
  · rw [source_prepared]
    intro name id found; cases found
  · rw [source_prepared]
    intro name id found; cases found
  · apply CheckTables.prepare_extension
    exact CheckTables.Extends.refl _

end
end Benitoite.Release.Refinement.Surface.CheckPredicateProjectionExamples
