import Benitoite.Release.Coverage

/-! E1c-1: 診断に使う反例の表示。表示名とフィールド名は宣言側から受け取る。 -/
namespace Benitoite.Release

structure CoverageDisplay where
  typeName : String
  constructorName : String
  sameName : Bool
  fields : Option (List String)

mutual
  def CoverageWitness.show (table : ConName → Option CoverageDisplay) : CoverageWitness → String
    | .wild | .other | .interval _ _ _ | .string _ | .invalidCon _ => "_"
    | .boolean b => if b then "true" else "false"
    | .unit => "()"
    | .exact xs => "[" ++ String.intercalate ", " (showWitnesses table xs) ++ "]"
    | .long min before after =>
        if min = 0 then "[..]" else
        let front := showWitnesses table before
        let count := max before.length (min - after.length)
        "[" ++ String.intercalate ", "
          (front ++ List.replicate (count - before.length) "_" ++ [".."] ++
            showWitnesses table after) ++ "]"
    | .con c args =>
        match table c with
        | none => "_"
        | some d =>
            let name := if d.sameName || d.fields.isSome then d.constructorName
              else d.typeName ++ "." ++ d.constructorName
            let values := showWitnesses table args
            match d.fields with
            | some fields => name ++ "(" ++ String.intercalate ", "
                ((fields.zip values).map fun (f, v) => f ++ ": " ++ v) ++ ")"
            | none => if args.isEmpty then name
                else name ++ "(" ++ String.intercalate ", " values ++ ")"
  def showWitnesses (table : ConName → Option CoverageDisplay) : List CoverageWitness → List String
    | [] => []
    | w :: ws => w.show table :: showWitnesses table ws
end

private def displayExample : ConName → Option CoverageDisplay
  | "some" => some ⟨"Option", "Some", false, none⟩
  | "pair" => some ⟨"Pair", "Pair", true, none⟩
  | "rec" => some ⟨"Record", "Record", true, some ["first", "last"]⟩
  | "none" => some ⟨"Option", "None", false, none⟩
  | _ => none

example : (CoverageWitness.con "some" [.boolean false]).show displayExample =
    "Option.Some(false)" := by decide
example : (CoverageWitness.con "pair" [.wild, .unit]).show displayExample =
    "Pair(_, ())" := by decide
example : (CoverageWitness.con "rec" [.boolean true, .exact [.unit]]).show displayExample =
    "Record(first: true, last: [()])" := by decide
example : (CoverageWitness.con "none" []).show displayExample = "Option.None" := by decide
example : (CoverageWitness.long 4 [.boolean true] [.boolean false]).show displayExample =
    "[true, _, _, .., false]" := by decide
example : (CoverageWitness.long 0 [] []).show displayExample = "[..]" := by decide
example : (CoverageWitness.long 1 [.unit, .wild] [.unit]).show displayExample =
    "[(), _, .., ()]" := by decide
example : showWitnesses displayExample [.wild, .other, .interval false (-4) 5,
    .string "literal", .invalidCon "bad"] = ["_", "_", "_", "_", "_"] := by decide

end Benitoite.Release
