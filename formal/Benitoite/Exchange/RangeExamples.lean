import Benitoite.Exchange.Convert

/-!
# 範囲と篩の交換境界の例

固定の範囲と記号付きの範囲を読み書きし、版・必須欄・宣言の深さ・原子の一覧の境界を確かめる
（設計書 07-04「交換の形式の版」）。
-/
namespace Benitoite.Exchange.RangeExamples
open Lean Benitoite.Scope.Domain Benitoite.Scope.Signature
open Benitoite.Release.Refinement

private def dataTree : Range := .path (.tree ["data"])
private def v4cidr : Range := .host (.ip (.cidr ⟨.v4, ⟨0xc0000200, by decide⟩, 24⟩))
private def apiEndpoint : Range := .endpoint ⟨.name (.many ["example", "com"]), ⟨443, 443⟩⟩

#guard [Range.top, dataTree, v4cidr, apiEndpoint].all fun r =>
  match decodeRangeStrict (encodeRange r) with | .ok r' => r' == r | .error _ => false
#guard ([RangeIx.top, .fixed (.absolute dataTree), .rvar 1,
    .fixed (.based .work (.tree ["data"])), .fixed .secrets] : List RangeIx).all fun ix =>
  match decodeRefinedIxStrict (encodeRefinedIx ix) with | .ok ix' => ix' == ix | .error _ => false

#guard !(decodeRangeStrict (Json.mkObj [("path", Json.mkObj [("tree", encodeWord ["data"])]),
  ("extra", Json.null)])).isOk
#guard !(decodeIPAddr (Json.mkObj [("family", .str "v4"), ("bits", encodeNat (2 ^ 32))])).isOk
#guard !(decodePort (encodeNat 65536)).isOk

private def writeAtom : Atom := .name "File.Write" (.fixed (.absolute dataTree))
private def pathIn : Ty := .scoped "Scope.PathIn" .path (.fixed (.absolute dataTree))

#guard match (fromJson? (toJson writeAtom) : Except String Atom) with
  | .ok a => a == writeAtom | .error _ => false
#guard match (fromJson? (toJson pathIn) : Except String Ty) with
  | .ok t => t == pathIn | .error _ => false
#guard !(fromJson? (Json.mkObj [("name", Json.mkObj [("value", .str "File.Write")])]) : Except String Atom).isOk
#guard !(fromJson? (Json.mkObj [("opaque", Json.mkObj [("name", .str "IOError")])]) : Except String Ty).isOk

private def emptyCorpus (version : Nat) : Json := Json.mkObj [
  ("version", toJson version), ("operators", toJson ([] : List OperatorEntry)), ("inputs", Json.arr #[])]

#guard (exchangeJson "corpus" (emptyCorpus 16)).isOk
#guard !(exchangeJson "corpus" (emptyCorpus 15)).isOk
#guard !(exchangeJson "corpus" (Json.mkObj [("version", toJson (16 : Nat)), ("inputs", Json.arr #[])])).isOk
#guard !(exchangeJson "corpus" (Json.mkObj [("version", toJson (16 : Nat)),
    ("operators", Json.arr #[]), ("inputs", Json.arr #[]), ("extra", Json.null)])).isOk

-- 範囲変数は宣言した深さの中だけに置ける。関数の範囲文脈は本体にも渡す。
#guard (validateRanges 1 (toJson (Atom.name "File.Write" (.rvar 0)))).isOk
#guard !(validateRanges 1 (toJson (Atom.name "File.Write" (.rvar 1)))).isOk
#guard !(validateRanges 0 (toJson (Atom.name "File.Write" (.rvar 0)))).isOk
#guard (validateRanges 0 (Json.mkObj [
  ("header", Json.mkObj [("rangeParams", toJson [Kind.path])]),
  ("body", toJson (Atom.name "File.Write" (.rvar 0)))])).isOk

private def primWith (rkinds : List Kind) (eff : List Atom) : Json :=
  Json.mkObj [("version", toJson (8 : Nat)), ("inputs", Json.arr #[Json.mkObj [
    ("prims", Json.arr #[Json.mkObj [("name", .str "File.writeTextIn"), ("rkinds", toJson rkinds), ("eff", toJson eff)]]),
    ("admitsR", Json.arr #[])]])]
#guard (exchangeJson "builtins" (primWith [.path] [Atom.name "File.Write" (.rvar 0)])).isOk
#guard !(exchangeJson "builtins" (primWith [.path] [Atom.name "File.Write" (.rvar 1)])).isOk
#guard !(exchangeJson "builtins" (primWith [] [Atom.name "File.Write" (.rvar 0)])).isOk

private def missingRanges : Json := Json.mkObj [("prim", Json.mkObj [("name", .str "File.readText"),
  ("tys", Json.arr #[]), ("effs", Json.arr #[])])]
#guard !(decodeVal missingRanges).isOk
#guard sidecarVersion 16 == 8

private def atoms : Eff := [.name "State" .top, writeAtom, .name "File.Read" .top]

#guard match fromVal atoms (fun _ => 0) (.prim "File.writeTextIn" [] [] [.fixed (.absolute dataTree)]) with
  | .ok v => v == .prim "File.writeTextIn" [] [] [.fixed (.absolute dataTree)] | .error _ => false

private def writeEff : Benitoite.Release.Refinement.Eff :=
  .mk (fun a => decide (a = .name "File.Write" (.fixed (.absolute dataTree)))) []

#guard match fromEff atoms writeEff with
  | .ok e => e == [writeAtom] | .error _ => false
#guard !(fromEff [.name "State" .top] writeEff [.name "File.Write" (.fixed (.absolute dataTree))]).isOk
#guard match fromEff atoms (Eff.namesToRelease [.name "File.Read" .top, .name "State" .top]) with
  | .ok e => (Eff.namesToRelease e).atoms (.nameTop "File.Read") && (Eff.namesToRelease e).atoms (.nameTop "State") && e.length == 2
  | .error _ => false

private def admits : List AdmitsEntry :=
  [⟨"Scope.widenPathIn", .covers 0 1⟩, ⟨"File.writeTextIn", .any⟩]

#guard AdmitsEntry.admitsRDec admits "Scope.widenPathIn" [.path (.tree ["data", "x"]), dataTree]
#guard !AdmitsEntry.admitsRDec admits "Scope.widenPathIn" [dataTree, .path (.tree ["data", "x"])]
#guard AdmitsEntry.admitsRDec admits "File.writeTextIn" [dataTree]
#guard !AdmitsEntry.admitsRDec admits "File.readTextIn" [dataTree]

#guard [IOShape.untargeted, .topTargeted .path, .single .endpoint 0].all fun s =>
  match (fromJson? (toJson s) : Except String IOShape) with | .ok s' => s' == s | .error _ => false
#guard match (fromJson? (toJson admits) : Except String (List AdmitsEntry)) with
  | .ok xs => xs.map (·.rule) == admits.map (·.rule) | .error _ => false

#guard instAtoms [.name "File.Write" (.rvar 0), .name "State" .top] [.fixed (.absolute dataTree)] == [writeAtom]
#guard instAtoms [.name "File.Write" (.rvar 1)] [.fixed (.absolute dataTree)] == []

end Benitoite.Exchange.RangeExamples
