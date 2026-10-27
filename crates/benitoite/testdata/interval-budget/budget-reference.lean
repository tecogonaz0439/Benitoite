import Benitoite.Interval.BudgetWhole

/- 予算付き解析の独立期待値（設計書 01-12「区間解析の予算付きの式とフロー」、
   02-05「区間解析の駆動と予算」）。実行定義・定理・公理は変更しない。
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
private def min : Expr := .negInt ⟨9223372036854775808, by decide⟩
private def minusOne : Expr := .negInt ⟨1, by decide⟩
private def division : Expr := .binary .intDiv int one zero
private def overflow : Expr := .binary .add int max one
private def ret (type : Ty) (source : Expr) : Block := .last (.returnE type source)
private def constant : Expr := .and (.binary .gt int one two)
  (.paren (.binary .eq int (.binary .intDiv int one zero) one))
private def openResource : Expr := .call (.primName "open" [] []) [] [] .nil
-- constE に Block の bind を埋める形は Rust の定数宣言で E0433 となるため、
-- 対応入力に含めない。定数の比較・複数展開は以下の constant/constantTwice で扱う。
private def cases : List (String × List Ty × Block) := [
  ("empty", [], .empty),
  ("builtinOperation", [], .discard
    (.call (.primName "Benitoite.Console.writeLine" [] []) [none] [0]
      (.cons (.literal (.string "x")) .nil)) (ret int division)),
  ("parens", [], ret int (.paren (.paren (.paren one)))),
  ("division", [], ret int division),
  ("skipRhs", [], ret int (.binary .add int overflow division)),
  ("skipIf", [], ret int (.ite (.literal (.boolean false)) (.last overflow) (.last one))),
  ("branches", [boolTy], ret int (.ite (.local 0) (.last division) (.last (.paren one)))),
  ("locals", [], .bind .bind int one (.bind .shadow int zero
    (ret int (.binary .add int (.local 0) one)))),
  ("short", [], ret boolTy (.and (.literal (.boolean false)) (.binary .eq int overflow zero))),
  ("match", [int], ret int (.matchE int (.local 0)
    (.cons [⟨.integer ⟨0, by decide⟩, []⟩] none (.last division)
      (.cons [⟨.wild, []⟩] (some (.literal (.boolean false))) (.last overflow)
        (.cons [⟨.wild, []⟩] none (.last one) .nil))))),
  ("narrow", [int], ret int (.ite (.binary .eq int (.local 0) zero)
    (.last (.binary .intDiv int one (.local 0))) (.last one))),
  ("reverseComparison", [int], ret int (.ite (.binary .eq int zero (.local 0))
    (.last (.binary .intDiv int one (.local 0))) (.last one))),
  ("andJoin", [int], ret int (.ite
    (.and (.binary .ge int (.local 0) zero) (.binary .le int (.local 0) zero))
    (.last (.binary .intDiv int one (.local 0))) (.last one))),
  ("orJoin", [int], ret int (.ite
    (.or (.binary .eq int (.local 0) zero) (.binary .eq int (.local 0) one))
    (.last (.binary .intDiv int one (.local 0))) (.last one))),
  ("notCondition", [int], ret int (.ite (.not (.paren (.binary .ne int (.local 0) zero)))
    (.last (.binary .intDiv int one (.local 0))) (.last one))),
  ("elseIf", [int], ret int (.elseIf (.binary .lt int (.local 0) zero) (.last one)
    (.ite (.binary .eq int (.local 0) zero)
      (.last (.binary .intDiv int one (.local 0))) (.last one)))),
  ("matchVariable", [int], ret int (.matchE int (.local 0)
    (.cons [⟨.var, [0]⟩] (some (.binary .eq int (.local 0) zero))
      (.last (.binary .intDiv int one (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last one) .nil)))),
  ("matchAlternatives", [int], ret int (.matchE int (.local 0)
    (.cons [⟨.integer ⟨0, by decide⟩, []⟩, ⟨.integer ⟨1, by decide⟩, []⟩] none
      (.last (.binary .intDiv int one (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last one) .nil)))),
  ("matchRange", [int], ret int (.matchE int (.local 0)
    (.cons [⟨.range (.integer ⟨0, by decide⟩) (.integer ⟨2, by decide⟩), []⟩] none
      (.last (.binary .intDiv int one (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last one) .nil)))),
  ("matchRangeAlternatives", [int], ret int (.matchE int (.local 0)
    (.cons [⟨.range (.integer ⟨0, by decide⟩) (.integer ⟨2, by decide⟩), []⟩,
       ⟨.integer ⟨7, by decide⟩, []⟩] none
      (.last (.binary .intDiv int one (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last one) .nil)))),
  ("guardOr", [int], ret int (.matchE int (.local 0)
    (.cons [⟨.var, [0]⟩] (some (.or (.binary .eq int (.local 0) zero)
        (.binary .eq int (.local 0) one)))
      (.last (.binary .intDiv int one (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last one) .nil)))),
  ("constantComparison", [int], ret int (.ite (.binary .eq int (.local 0) (.constE int zero))
    (.last (.binary .intDiv int one (.local 0))) (.last one))),
  ("list", [], ret (.list int) (.list int (.cons division (.cons overflow .nil)))),
  ("call", [], ret int (.call (.funName "helper" [int] []) [none] [0] (.cons division .nil))),
  ("lambda", [], .lastBind .bind (.fn [] [] int Eff.empty)
    (.lam [] [] int .empty (ret int division))),
  ("constant", [], ret boolTy (.constE boolTy constant)),
  ("constantTwice", [], ret boolTy (.and (.constE boolTy constant) (.constE boolTy constant))),
  ("unsupported", [], ret int (.binary .mul int division (.paren overflow))),
  ("negate", [], ret int (.neg int (.paren division))),
  ("subtract", [], .bind .bind int min (ret int (.binary .sub int (.local 0) one))),
  ("scaleNegative", [], .bind .bind int min
    (ret int (.binary .mul int minusOne (.local 0)))),
  ("negateMinimum", [], .bind .bind int min (ret int (.neg int (.local 0)))),
  ("generalProduct", [boolTy], .bind .bind int
    (.ite (.local 0) (.last two) (.last (.literal (.integer ⟨3, by decide⟩))))
    (ret int (.binary .mul int (.local 0) (.local 0)))),
  -- Boolean の等値と Byte の比較は型が合う未対応の二項演算である。
  -- 左右を独立に解析し、整数の子の候補を親へ移さない経路を残す。
  ("unsupportedBoolean", [], ret boolTy (.binary .eq boolTy
    (.paren (.binary .eq int division zero)) (.paren (.binary .eq int overflow zero)))),
  ("unsupportedByte", [.base .byte, .base .byte],
    ret boolTy (.binary .lt (.base .byte) (.local 1) (.local 0))),
  ("spread", [], ret (.list int) (.listSpread int (.funName "concat" [] [])
    (.cons one .nil) (.list int (.cons two .nil)) (.cons one .nil))),
  ("interpolation", [], ret (.base .string) (.interpolation [] (.cons division .nil)
    (.cons (.primName "format" [] []) .nil))),
  ("partial", [], .lastBind .bind (.fn ["left"] [int] int Eff.empty)
    (.partialCall (.funName "pair" [int, int] []) ["left", "right"]
      (.hole (some "left") 0 int (.expr (some "right") 1 division .nil)) int Eff.empty)),
  ("tryMessage", [], ret int (.tryOptionDie int "Some" "None" "exit"
    (.conCall "Some" [int] (.cons division .nil)) (some (.literal (.string "bad"))))),
  ("with", [], .last (.withE "TaskGroup" openResource (.lastDiscard division))),
  ("nestedWith", [], .last (.withE "TaskGroup" openResource
    (.last (.withE "TaskGroup" openResource (.lastDiscard division))))),
  ("recordPattern", [], .bindPat .bind (.record "Box" 1 [0] [.var]) (.data "Box" [])
    (.record "Box" [] [0] (.cons zero .nil)) (ret int (.local 0))),
  ("returnRest", [], .discard
    (.ite (.literal (.boolean true)) (ret int one) (.last .unit))
    (.discard division (ret int two)))]


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
private def widthNegative (kind : IntKind) (value : Nat) : Expr :=
  match kind with
  | .integer8 => .negInteger8 value
  | .integer16 => .negInteger16 value
  | .integer32 => .negInteger32 value
  | _ => .unit
private def widthMatch (kind : IntKind) (fallback : Expr) : Block :=
  let type := kind.type
  ret type (.matchE type (.local 0)
    (.cons [⟨.var, [0]⟩]
      (some (.binary .eq type (.local 0) (.paren (.constE type (widthLeaf kind 0)))))
      (.last (.binary .intDiv type (widthLeaf kind 1) (.local 0)))
      (.cons [⟨.wild, []⟩] none (.last fallback) .nil)))

private def widthCasesFor (label : String) (kind : IntKind) (minimum maximum : Nat) :
    List (String × List Ty × Block) := Id.run do
  let type := kind.type
  let z := widthLeaf kind 0
  let o := widthLeaf kind 1
  let divide := .binary .intDiv type o (.local 0)
  let compare op left right := Expr.binary op type left right
  let conditional c := ret type (.ite c (.last divide) (.last o))
  let ordinary := [
    ("narrow", conditional (compare .eq (.local 0) z)),
    ("reverseConstant", conditional (compare .eq (.paren (.constE type z)) (.local 0))),
    ("andJoin", conditional (.and (compare .ge (.local 0) z) (compare .le (.local 0) z))),
    ("orJoin", conditional (.or (compare .eq (.local 0) z) (compare .eq (.local 0) o))),
    ("matchVariable", widthMatch kind o),
    ("matchWildcard", ret type (.matchE type (.paren (.local 0))
      (.cons [⟨.wild, []⟩] (some (.not (.paren (compare .ne (.local 0) z)))) (.last divide)
        (.cons [⟨.wild, []⟩] none (.last o) .nil)))),
    ("matchUnknown", ret type (.matchE type
      (.call (.funName "helper" [type] []) [none] [0] (.cons (.local 0) .nil))
      (.cons [⟨.var, [0]⟩] (some (compare .eq (.local 0) z)) (.last divide)
        (.cons [⟨.wild, []⟩] none (.last o) .nil)))),
    -- 構造パターンの位置は型が整数でも unknown。先行する未対応の印なしで
    -- matchKind の未認定・skip・unsupported の順序を検査する。
    ("matchPatternUnknown", .bindPat .bind (.record "Box" 1 [0] [.var]) (.data "Box" [])
      (.local 0) (ret type (.matchE type (.local 0)
        (.cons [⟨.var, [0]⟩] (some (compare .eq (.local 0) z)) (.last divide)
          (.cons [⟨.wild, []⟩] none (.last o) .nil))))),
    ("scale", .bind .bind type (widthLeaf kind maximum)
      (ret type (.binary .mul type (.local 0) (.local 0))))]
  let signed := if minimum = 0 then [] else [
    ("negate", .bind .bind type (widthNegative kind minimum) (ret type (.neg type (.local 0)))),
    ("negativeComparison", ret type (.ite
      (compare .eq (.local 0) (.paren (.constE type (widthNegative kind minimum))))
      (.last (.neg type (.local 0))) (.last o)))]
  return (ordinary ++ signed).map fun (name, body) =>
    (label ++ "_" ++ name, if name = "matchPatternUnknown" then [.data "Box" []] else [type], body)
private def widthCases : List (String × List Ty × Block) :=
  widths.flatMap fun (label, kind, minimum, maximum) => widthCasesFor label kind minimum maximum

-- 実交換と同じ組み込みの操作の頭と、シフトの組み込み/包みを使う。
-- 宣言・順序・型は独立に記述し、解析費用から期待値を作らない。
private def shiftReferenceEnv (body : Block) : AbstractEnv := Id.run do
  let modules : List (String × ShiftOperand × Bool) := [
    ("Byte", .byte, false), ("Integer", .integer .integer64, true),
    ("Integer16", .integer .integer16, true), ("Integer32", .integer .integer32, true),
    ("Integer64", .integer .integer64, true), ("Integer8", .integer .integer8, true),
    ("UnsignedInteger", .integer .unsignedInteger64, false),
    ("UnsignedInteger16", .integer .unsignedInteger16, false),
    ("UnsignedInteger32", .integer .unsignedInteger32, false),
    ("UnsignedInteger64", .integer .unsignedInteger64, false), ("UnsignedInteger8", .byte, false)]
  let bindings := modules.flatMap fun (moduleName, operand, signed) =>
    ([ ("shiftLeft", ShiftOperation.left), ("shiftRight", ShiftOperation.right)] ++
      (if signed then [("shiftRightUnsigned", ShiftOperation.rightUnsigned)] else [])).filterMap fun (name, op) =>
        (FixedDomainApi.shift operand op).binding ("Benitoite." ++ moduleName ++ "." ++ name)
  let calls := ((surfacePreorder (.block body)).zipIdx).filterMap fun (expr, index) =>
    match expr with
    | .call (.primName name [] []) _ _ _ | .call (.funName name [] []) _ _ _ =>
        if bindings.any (fun b => b.declaration == name) then some (index, name) else none
    | _ => none
  return { (AbstractEnv.ofLocals []) with
    standards := bindings
    apiAt := fun key => (calls.find? (fun pair => pair.1 == key.surfacePreorder)).map (·.2) }
private def shiftCall (primitive : Bool) (amount : Expr) (reverse : Bool := false)
    (value : Expr := one) : Expr :=
  let head := if primitive then .primName "Benitoite.Integer.shiftLeft" [] []
    else .funName "Benitoite.Integer64.shiftLeft" [] []
  if reverse then .call head [some "n", some "a"] [1, 0] (.cons amount (.cons value .nil))
  else .call head [some "a", some "n"] [0, 1] (.cons value (.cons amount .nil))
private def sixtyFour : Expr := .literal (.integer ⟨64, by decide⟩)
private def shiftCases : List (String × List Ty × Block) :=
  [("shiftPrimInside", [], ret int (shiftCall true zero)),
   ("shiftPrimOutside", [], ret int (shiftCall true sixtyFour)),
   ("shiftPrimReverse", [], ret int (shiftCall true sixtyFour true)),
   ("shiftFunInside", [], ret int (shiftCall false zero)),
   ("shiftFunOutside", [], ret int (shiftCall false sixtyFour)),
   ("shiftReturn", [], ret int (shiftCall true sixtyFour true (.block (ret int one))))]

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

private def list (values : List Nat) : String :=
  ",".intercalate (values.map toString)
private def warnings (values : List IntervalWarning) : String :=
  list (values.reverse.map (·.key.surfacePreorder))

private def bodyRow (name : String) (params : List Ty) (body : Block) (kind cap : Nat) : String := Id.run do
  let limits : Limits := match kind with
    | 0 => ⟨⟨cap, 1000⟩, ⟨1000, 1000⟩⟩
    | 1 => ⟨⟨1000, cap⟩, ⟨1000, 1000⟩⟩
    | 2 => ⟨⟨1000, 1000⟩, ⟨cap, 1000⟩⟩
    | _ => ⟨⟨1000, 1000⟩, ⟨1000, cap⟩⟩
  let input : BudgetWhole.Definition := ⟨name, .function, params, body, if name.startsWith "range" then rangeReferenceEnv body
    else if name.startsWith "shift" then shiftReferenceEnv body else AbstractEnv.ofLocals []⟩
  let (seed, ctx) := BudgetWhole.prepareRoot input limits { next := ⟨name, 0⟩ }
  let (state, next, stop, ws, inputs, unsupported) := match seed with
    | .error reason => (ctx.budget, 0, code reason, "", "", false)
    | .ok seed =>
      let output := analyzeBody limits ctx.budget 200 name seed
      (output.context.budget, output.context.next.surfacePreorder,
        match output.coverage with | .stopped reason => code reason | _ => 0,
        warnings output.context.warningsRev,
        ";".intercalate (output.context.independentRev.reverse.map fun (entry : IndependentResult) =>
          s!"{entry.key.surfacePreorder}:{match entry.result with | .ok _ => 0 | .error e => code e}:{warnings entry.warningsRev}"),
        output.context.unsupported)
  return s!"{name}\t{kind}\t{cap}\t{state.body.operations}\t{state.body.saved}\t{state.body.peak}\t{next}\t{stop}\t{ws}\t{inputs}\t{if unsupported then 1 else 0}"

-- 各資源の全停止位置を小さい予算で覆い、完走上限の直前・ちょうど・直後も含む。
-- 200 は全入力が完走する確認用。上限が大きい通常例の全比較は X02 が担当する。
#eval do
  for (name, params, body) in cases ++ widthCases ++ rangeCases ++ shiftCases do
    for kind in [0, 1, 2, 3] do
      for cap in (List.range 201) do
        IO.println (bodyRow name params body kind cap)

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


private def phaseCode : Option (Except Halt α) → Nat
  | none => 10
  | some (.ok _) => 0
  | some (.error reason) => code reason
private def bodyOutputs (r : BudgetWhole.Report) : List BudgetWhole.BodyOutput :=
  r.definitionsRev.reverse.flatMap fun d => d.root.toList ++ d.embedded.bodiesRev.reverse

private def wholeRow (name : String) (sources : List BudgetWhole.Module) (kind cap : Nat) : String := Id.run do
  let limits : Limits := match kind with
    | 0 => ⟨⟨cap, 1000⟩, ⟨1000, 1000⟩⟩
    | 1 => ⟨⟨1000, cap⟩, ⟨1000, 1000⟩⟩
    | 2 => ⟨⟨1000, 1000⟩, ⟨cap, 1000⟩⟩
    | _ => ⟨⟨1000, 1000⟩, ⟨1000, cap⟩⟩
  let r := BudgetWhole.analyze limits {} 200 sources
  let bodies := bodyOutputs r
  let names := ",".intercalate (bodies.map (·.definition))
  let ws := ";".intercalate (bodies.map fun b =>
    s!"{b.definition}={warnings b.output.context.warningsRev}/" ++
    ";".intercalate (b.output.context.independentRev.reverse.map fun i =>
      s!"{i.key.surfacePreorder}:{match i.result with | .ok _ => 0 | .error e => code e}:{warnings i.warningsRev}"))
  let phases := ";".intercalate (r.definitionsRev.reverse.map fun d =>
    s!"{d.input.name}={phaseCode (some d.prepared)},{phaseCode (d.discovery.map (·.result))},{phaseCode d.queue},{d.embedded.stopped.map code |>.getD 10}")
  let entries := ",".intercalate (r.definitionsRev.reverse.flatMap fun d =>
    (d.discovery.toList.flatMap (·.context.entriesRev.reverse)).map fun e =>
      s!"{e.embedded.definition}:{if e.initial.isSome then 1 else 0}")
  let pending := ",".intercalate (r.definitionsRev.reverse.flatMap fun d =>
    d.embedded.pending.map (·.embedded.definition))
  let remaining := (r.remainingDefinitions.head?.map (·.name)).getD ""
  let mods := ",".intercalate (r.remainingModules.map fun m =>
    (m.definitions.head?.map (·.name)).getD "empty")
  return s!"whole:{name}\t{kind}\t{cap}\t{r.after.whole.operations}\t{r.after.whole.saved}\t{r.after.whole.peak}\t{names}\t{ws}\t{phases}\t{entries}\t{pending}\t{remaining}\t{r.stopped.map code |>.getD 10}\t{mods}"

#eval do
  for (name, sources) in wholeCases ++ widthWholeCases ++ rangeWholeCases do
    for kind in [0, 1, 2, 3] do
      for cap in List.range (if String.startsWith name "range" then 601 else 201) do
        IO.println (wholeRow name sources kind cap)
