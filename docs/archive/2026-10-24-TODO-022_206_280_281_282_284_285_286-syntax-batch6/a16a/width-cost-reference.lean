import Benitoite.Interval.BudgetWhole

/- 既存の六幅の費用表の生成入力。
   Range 認定の走査を含む現行 Lean から、表の全行を生成する。 -/
open Benitoite.Surface Benitoite.Release Benitoite.Interval
open Budget BudgetAnalysis
private def seven (kind : IntKind) : Expr := match kind with
  | .integer64 => .literal (.integer ⟨7, by decide⟩)
  | .integer8 => .literal (.integer8 7)
  | .integer16 => .literal (.integer16 7)
  | .integer32 => .literal (.integer32 7)
  | .unsignedInteger16 => .literal (.unsignedInteger16 7)
  | .unsignedInteger32 => .literal (.unsignedInteger32 7)
  | .unsignedInteger64 => .literal (.unsignedInteger64 7)
private def nine (kind : IntKind) : Expr := match kind with
  | .integer64 => .literal (.integer ⟨9, by decide⟩)
  | .integer8 => .literal (.integer8 9)
  | .integer16 => .literal (.integer16 9)
  | .integer32 => .literal (.integer32 9)
  | .unsignedInteger16 => .literal (.unsignedInteger16 9)
  | .unsignedInteger32 => .literal (.unsignedInteger32 9)
  | .unsignedInteger64 => .literal (.unsignedInteger64 9)
private def body (kind : IntKind) : Block :=
  .bind .bind kind.type (seven kind)
    (.discard (.list kind.type (.cons (.local 0) .nil))
      (.last (.returnE kind.type (.ite (.or (.local 2) (.local 1))
        (.last (.local 0)) (.last (nine kind))))))
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
  let input : BudgetWhole.Definition := ⟨name, .function, params, body, AbstractEnv.ofLocals []⟩
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


#eval do
  for width in [IntKind.integer64, .integer8, .integer16, .integer32,
      .unsignedInteger16, .unsignedInteger32, .unsignedInteger64] do
    for resource in [0, 1, 2, 3] do
      for cap in [0, 20, 50, 1000] do
        IO.println (bodyRow (reprStr width) [.base .boolean, .base .boolean] (body width) resource cap)
