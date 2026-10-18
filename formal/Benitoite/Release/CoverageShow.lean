import Benitoite.Release.Coverage

/-! 設計書 02-05「本体の後の検査」に対応する反例の表示。
表示名とフィールド名は宣言側から受け取る。 -/
namespace Benitoite.Release

structure CoverageDisplay where
  typeName : String
  constructorName : String
  sameName : Bool
  fields : Option (List String)

/-- 将来の形には実在の構成子がないため、型の出どころから表示を引く。 -/
structure CoverageTypeDisplay where
  typeName : String
  isRecord : Bool

/-- 文字区間の下端を実在の文字に戻す。不正な区間は表示用の値にしない。 -/
def CoverageWitness.characterValue (lo hi : Int) : Option Char :=
  if 0 ≤ lo ∧ lo ≤ hi ∧ lo < 0x110000 ∧ (lo < 0xD800 ∨ 0xE000 ≤ lo) then
    some (Char.ofNat lo.toNat) else none

/-- ASCIIの可視文字はリテラル、それ以外は小文字のUnicodeエスケープで示す。 -/
def CoverageWitness.showCharacter (c : Char) : String :=
  let body := if c = '\n' then "\\n" else if c = '\r' then "\\r" else if c = '\t' then "\\t"
    else if c = '\\' then "\\\\" else if c = '\'' then "\\'"
    else if 0x20 ≤ c.toNat ∧ c.toNat ≤ 0x7E then String.singleton c
    else "\\u{" ++ String.ofList (Nat.toDigits 16 c.toNat) ++ "}"
  "'" ++ body ++ "'"

mutual
  /-- 型の表示表から将来の形の型名も表示する入口（設計書 02-05「本体の後の検査」）。 -/
  def CoverageWitness.showWithTypes (table : ConName → Option CoverageDisplay)
      (types : DataName → Option CoverageTypeDisplay) : CoverageWitness → String
    | .wild | .other | .interval false _ _ | .string _ | .invalidCon _ => "_"
    | .interval true lo hi =>
        ((CoverageWitness.characterValue lo hi).map CoverageWitness.showCharacter).getD "_"
    | .future d =>
        match types d with
        | none => "_"
        | some t => "<future " ++ (if t.isRecord then "shape" else "constructor") ++
            " of " ++ t.typeName ++ ">"
    | .boolean b => if b then "true" else "false"
    | .unit => "()"
    | .exact xs => "[" ++ String.intercalate ", " (showWitnessesWithTypes table types xs) ++ "]"
    | .long min before after =>
        if min = 0 then "[..]" else
        let front := showWitnessesWithTypes table types before
        let count := max before.length (min - after.length)
        "[" ++ String.intercalate ", "
          (front ++ List.replicate (count - before.length) "_" ++ [".."] ++
            showWitnessesWithTypes table types after) ++ "]"
    | .con c args =>
        match table c with
        | none => "_"
        | some d =>
            let name := if d.sameName || d.fields.isSome then d.constructorName
              else d.typeName ++ "." ++ d.constructorName
            let values := showWitnessesWithTypes table types args
            match d.fields with
            | some fields => name ++ "(" ++ String.intercalate ", "
                ((fields.zip values).map fun (f, v) => f ++ ": " ++ v) ++ ")"
            | none => if args.isEmpty then name
                else name ++ "(" ++ String.intercalate ", " values ++ ")"
  def showWitnessesWithTypes (table : ConName → Option CoverageDisplay)
      (types : DataName → Option CoverageTypeDisplay) : List CoverageWitness → List String
    | [] => []
    | w :: ws => w.showWithTypes table types :: showWitnessesWithTypes table types ws
end

/-- 既存の閉じた判定の表示入口。呼び出し元は型の表示表へまだ接続しない。 -/
def CoverageWitness.show (table : ConName → Option CoverageDisplay) (w : CoverageWitness) : String :=
  w.showWithTypes table (fun _ => none)

def showWitnesses (table : ConName → Option CoverageDisplay) (ws : List CoverageWitness) : List String :=
  showWitnessesWithTypes table (fun _ => none) ws

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

private def typeDisplayExample : DataName → Option CoverageTypeDisplay
  | "kind-id" => some ⟨"IOErrorKind", false⟩
  | "record-id" => some ⟨"ParseError", true⟩
  | _ => none

/-- 型引数・構成子名・識別用の名前ではなく、DataName に対応する型の表示名を使う。 -/
example : showWitnessesWithTypes displayExample typeDisplayExample
    [.future "kind-id", .future "record-id", .other, .future "missing",
     .con "some" [.future "kind-id"],
     .con "rec" [.future "record-id", .exact [.future "kind-id"]],
     .long 1 [.future "record-id"] []] =
    ["<future constructor of IOErrorKind>", "<future shape of ParseError>", "_", "_",
     "Option.Some(<future constructor of IOErrorKind>)",
     "Record(first: <future shape of ParseError>, last: [<future constructor of IOErrorKind>])",
     "[<future shape of ParseError>, ..]"] := by decide

/-- 判定が返した文字を独立した期待値と比べ、元の分岐に照合しないことを確認する。 -/
example : ([
    ([CoverageExamples.chars 97 122], (0 : Int), "'\\u{0}'"),
    ([CoverageExamples.chars 0 96, CoverageExamples.chars 98 0x10FFFF], 97, "'a'"),
    ([CoverageExamples.chars 0 0xD7FF, CoverageExamples.chars 0xE001 0x10FFFF], 0xE000, "'\\u{e000}'"),
    ([CoverageExamples.chars 0 0x10FFFE], 0x10FFFF, "'\\u{10ffff}'")]
    : List (List Pat × Int × String)).all (fun (ps, expected, text) =>
      match (checkMatch CoverageExamples.program CoverageExamples.ctors (.base .character)
        (ps.map fun p => CoverageExamples.plain [p])).uncovered with
      | some (.interval true lo hi) =>
          lo == expected && (CoverageWitness.interval true lo hi).show displayExample == text &&
            match CoverageWitness.characterValue lo hi with
            | none => false
            | some c => ps.all fun p => (Pat.matchVal p (.const (.character c))).isNone
      | _ => false) = true := by decide

/-- 入れ子の反例でも、表示した文字と構成子の組合せは元の全分岐に照合しない。 -/
example : (let ps : List Pat := [.con "L" [CoverageExamples.chars 1 0x10FFFF], .con "R" [.wild]]
    let table := fun c => if c == "L" then some ⟨"Choice", "L", false, none⟩ else displayExample c
    match (checkMatch CoverageExamples.program CoverageExamples.ctors
      (.data "Choice" [.base .character]) (ps.map fun p => CoverageExamples.plain [p])).uncovered with
    | some (.con "L" [.interval true lo hi]) =>
        (CoverageWitness.con "L" [.interval true lo hi]).show table == "Choice.L('\\u{0}')" &&
          lo == 0 && match CoverageWitness.characterValue lo hi with
          | none => false
          | some c => ps.all (fun p => (Pat.matchVal p (.con "L" [] [.const (.character c)])).isNone)
    | _ => false) = true := by decide

example : (['a', '\n', '\r', '\t', '\\', '\'', Char.ofNat 0, Char.ofNat 0xD7FF,
    Char.ofNat 0xE000, Char.ofNat 0x10FFFF] : List Char).map CoverageWitness.showCharacter =
    ["'a'", "'\\n'", "'\\r'", "'\\t'", "'\\\\'", "'\\''", "'\\u{0}'", "'\\u{d7ff}'",
     "'\\u{e000}'", "'\\u{10ffff}'"] := by decide

end Benitoite.Release
