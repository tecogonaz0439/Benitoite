import Benitoite.Interval.BudgetWhole

/- BudgetWhole の件数と停止の射影を独立期待値にする
   （設計書 02-05「区間解析の報告の集計」）。実行定義・定理・公理は変更しない。
   再生成は同じディレクトリの README.md と regenerate-reference.py を参照する。 -/
open Benitoite.Surface Benitoite.Release Benitoite.Interval
open Budget BudgetAnalysis


-- RANGE_EXCHANGE: regenerate-reference.py が実交換から宣言をここへ渡す。

private def rangeInt : Ty := .base .integer
private def rangeResult : Ty := .data referenceRangeNames.result
  [.data referenceRangeNames.owner [], .data referenceRangeNames.error []]

private def rangeZero : Expr := .literal (.integer ⟨0, by decide⟩)
private def rangeOne : Expr := .literal (.integer ⟨1, by decide⟩)
private def rangeTen : Expr := .literal (.integer ⟨10, by decide⟩)
private def rangeFive : Expr := .literal (.integer ⟨5, by decide⟩)
private def rangeMinus : Expr := .negInt ⟨99, by decide⟩
private def rangeCheckCall (value : Expr) (hi : Expr := rangeTen) (lo : Expr := rangeZero) : Expr :=
  .call (.funName referenceRangeCheck [] [])
    [some "value", some "maximum", some "minimum"] [2, 1, 0]
    (.cons value (.cons hi (.cons lo .nil)))
private def rangeValueCall (index : Nat) : Expr :=
  .call (.funName referenceRangeValue [] []) [some "value"] [0] (.cons (.local index) .nil)
private def rangeFakeCall (value : Expr) : Expr :=
  .call (.funName "User.checkInteger" [] [])
    [some "value", some "maximum", some "minimum"] [2, 1, 0]
    (.cons value (.cons rangeTen (.cons rangeZero .nil)))
private def rangeOk : Alternative :=
  ⟨.con (some referenceRangeNames.result) referenceRangeNames.ok [.var], [0]⟩
private def rangeErr : Alternative :=
  ⟨.con (some referenceRangeNames.result) referenceRangeNames.err [.wild], []⟩
private def rangeSelect (source : Expr) (body : Expr) : Expr :=
  .matchE rangeInt source (.cons [rangeOk] none (.last body)
    (.cons [rangeErr] none (.last (.returnE rangeInt rangeMinus)) .nil))

private def rangeCases : List (String × List Ty × Block) := [
  ("rangeCall", [rangeInt], .last (.returnE rangeResult (rangeCheckCall (.local 0)))),
  ("rangeSaved", [rangeInt], .bind .bind rangeResult (rangeCheckCall (.local 0))
    (.last (.returnE rangeInt (rangeSelect (.local 0) (rangeValueCall 0))))),
  ("rangeAllArms", [rangeInt], .last (.returnE rangeInt
    (.matchE rangeInt (rangeCheckCall (.local 0))
      (.cons [rangeOk] (some (.binary .eq rangeInt (rangeValueCall 0) rangeZero))
        (.last (.binary .intDiv rangeInt rangeOne rangeZero))
        (.cons [rangeErr] none (.last (.binary .intDiv rangeInt rangeOne rangeZero))
          (.cons [⟨.wild, []⟩] none (.last rangeOne) .nil)))))),
  ("rangeValue", [.data referenceRangeNames.owner []], .last (.returnE rangeInt (rangeValueCall 0))),
  ("rangeFake", [rangeInt], .last (.returnE rangeInt (rangeFakeCall (.local 0)))),
  ("rangeDynamic", [rangeInt], .last (.returnE rangeInt
    (rangeSelect (rangeCheckCall rangeFive (.local 0)) (rangeValueCall 0)))),
  ("rangeIncrement", [rangeInt], .last (.returnE rangeInt
    (rangeSelect (rangeCheckCall (.local 0) rangeZero)
      (.binary .intDiv rangeInt rangeOne (rangeValueCall 0))))),
  ("rangeUnrecognized", [rangeInt], .last (.returnE rangeInt
    (rangeFakeCall (.binary .intDiv rangeInt (.local 0) rangeZero))))]

-- 元の先行順から出現表を作る。解析結果と費用は入力の生成に使わない。
private def rangeReferenceEnv (body : Block) : AbstractEnv := Id.run do
  let calls := ((surfacePreorder (.block body)).zipIdx).filterMap fun (expr, index) =>
    match expr with
    | .call (.funName name [] []) _ _ _ =>
      if name == referenceRangeCheck || name == referenceRangeValue then some (index, name) else none
    | _ => none
  return { (AbstractEnv.ofLocals []) with
    standards := if calls.isEmpty then [] else
      [⟨referenceRangeCheck, .rangeCheck referenceRangeNames, []⟩,
       ⟨referenceRangeValue, .rangeValue referenceRangeNames.record, []⟩]
    apiAt := fun key => (calls.find? (fun pair => pair.1 == key.surfacePreorder)).map (·.2) }
private def rangeDefinition (name : String) (params : List Ty) (body : Block) : BudgetWhole.Definition :=
  ⟨name, .function, params, body, rangeReferenceEnv body⟩
private def rangeWholeCases : List (String × List BudgetWhole.Module) :=
  rangeCases.map fun (name, params, body) =>
    -- Rust の前置きの利用者関数も定義順に含める。
    (name, [⟨[⟨".checkInteger", .function, [rangeInt, rangeInt, rangeInt],
      .last (.returnE rangeInt (.local 0)), AbstractEnv.ofLocals []⟩,
      rangeDefinition ".sample" params body]⟩])

private def int : Ty := .base .integer
private def boolTy : Ty := .base .boolean
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def two : Expr := .literal (.integer ⟨2, by decide⟩)
private def max : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
private def division : Expr := .binary .intDiv int one zero
private def overflow : Expr := .binary .add int max one
private def ret (type : Ty) (source : Expr) : Block := .last (.returnE type source)

private def widths : List (String × IntKind × Nat × Nat) := [
  ("s8", .integer8, 128, 127), ("s16", .integer16, 32768, 32767),
  ("s32", .integer32, 2147483648, 2147483647),
  ("u16", .unsignedInteger16, 0, 65535), ("u32", .unsignedInteger32, 0, 4294967295),
  ("u64", .unsignedInteger64, 0, 18446744073709551615)]

private def widthLeaf (kind : IntKind) (value : Nat) : Expr :=
  match kind with
  | .integer8 => .literal (.integer8 value)
  | .integer16 => .literal (.integer16 value)
  | .integer32 => .literal (.integer32 value)
  | .unsignedInteger16 => .literal (.unsignedInteger16 value)
  | .unsignedInteger32 => .literal (.unsignedInteger32 value)
  | .unsignedInteger64 => .literal (.unsignedInteger64 value)
  | .integer64 => .unit
private def widthMatch (kind : IntKind) (fallback : Expr) : Block :=
  let type := kind.type
  ret type (.matchE type (.local 0)
    (.cons [⟨.var, [0]⟩]
      (some (.binary .eq type (.local 0) (.paren (.constE type (widthLeaf kind 0)))))
      (.last (.binary .intDiv type (widthLeaf kind 1) (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last fallback) .nil)))

private def code : Halt → Nat
  | .depth => 9
  | .budget (.exceeded ⟨.body, .operations⟩) => 1
  | .budget (.exceeded ⟨.body, .items⟩) => 2
  | .budget (.unidentified ⟨.body, .operations⟩) => 3
  | .budget (.unidentified ⟨.body, .items⟩) => 4
  | .budget (.exceeded ⟨.whole, .operations⟩) => 5
  | .budget (.exceeded ⟨.whole, .items⟩) => 6
  | .budget (.unidentified ⟨.whole, .operations⟩) => 7
  | .budget (.unidentified ⟨.whole, .items⟩) => 8

private def definition (name : String) (body : Block) (params : List Ty := []) : BudgetWhole.Definition :=
  ⟨name, .function, params, body, AbstractEnv.ofLocals []⟩
private def wholeCases : List (String × List BudgetWhole.Module) := [
  ("lazy", [⟨[
    definition ".a" (.discard division (.lastBind .bind (.lazy int) (.lazyE (.last division)))) ,
    definition ".b" (.lastDiscard division)]⟩,
    ⟨[definition "Other.c" (.lastDiscard division)]⟩]),
  ("handler", [⟨[definition ".sample" (.lastDiscard (.handleE (.last division)
    (.cons (.user ".E.get") 0 0 (.last overflow) .nil 0)))]⟩]),
  ("captured", [⟨[definition ".sample"
    (.bind .bind int zero (.lastBind .bind (.fn ["flag"] [boolTy] int Eff.empty)
      (.lam ["flag"] [boolTy] int Eff.empty
        (ret int (.ite (.local 0) (.last (.binary .intDiv int one (.local 1))) (.last (.local 2)))))))
    [int]]⟩]),
  ("constantModule", [⟨[
    ⟨".limit", .constant, [], .last zero, AbstractEnv.ofLocals []⟩,
    definition ".sample" (ret int (.ite (.binary .eq int (.local 0) (.constE int zero))
      (.last (.binary .intDiv int one (.local 0))) (.last one))) [int]]⟩]),
  ("validModules", [⟨[
    definition ".sample" (ret int (.ite (.binary .eq int (.local 0) (.constE int zero))
      (.last (.binary .intDiv int one (.local 0))) (.last one))) [int]]⟩,
    ⟨[⟨"Other.limit", .constant, [], .last zero, AbstractEnv.ofLocals []⟩,
      definition "Other.c" (.lastDiscard division)]⟩])]


private def widthWholeCases : List (String × List BudgetWhole.Module) :=
  widths.map fun (label, kind, minimum, maximum) =>
    let type := kind.type
    let product := Expr.binary .mul type (widthLeaf kind maximum) (widthLeaf kind maximum)
    let fallback := if minimum = 0 then product else Expr.neg type (.paren product)
    ("width_" ++ label, [⟨[
      ⟨".limit", .constant, [], .last (widthLeaf kind 0), AbstractEnv.ofLocals []⟩,
      definition ".sample" (widthMatch kind fallback) [type]]⟩])


private def summaryRow (name : String) (sources : List BudgetWhole.Module) (kind cap : Nat) : String := Id.run do
  let limits : Limits := match kind with
    | 0 => ⟨⟨cap, 1000⟩, ⟨1000, 1000⟩⟩
    | 1 => ⟨⟨1000, cap⟩, ⟨1000, 1000⟩⟩
    | 2 => ⟨⟨1000, 1000⟩, ⟨cap, 1000⟩⟩
    | _ => ⟨⟨1000, 1000⟩, ⟨1000, cap⟩⟩
  let r := BudgetWhole.analyze limits {} 200 sources
  let stops := ",".intercalate ((BudgetWhole.phaseStops r).map (toString ∘ code))
  return s!"whole:{name}\t{kind}\t{cap}\t{BudgetWhole.inputDefinitionCount r}\t{BudgetWhole.unsupportedBodies r}\t{BudgetWhole.bodyBudgetExceeded r}\t{BudgetWhole.wholeBudgetSkipped r}\t{BudgetWhole.unidentifiedBodies r}\t{stops}"

#eval do
  for (name, sources) in wholeCases ++ widthWholeCases ++ rangeWholeCases do
    for kind in [0, 1, 2, 3] do
      for cap in List.range (if String.startsWith name "range" then 601 else 201) do
        IO.println (summaryRow name sources kind cap)
