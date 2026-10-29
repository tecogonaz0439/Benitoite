import Benitoite.Exchange.CheckInput

/-!
# 交換の形式の範囲の例（corpus 15・sidecar 7）

範囲付きの原子・不透明型・組み込みの呼び出しの範囲の列の読み書き、旧版の明示の Top での読み込み、新版の欄の
欠落の拒否、書き出しの一覧にない原子の拒否、表のデータの判定を、既定ビルドの小さな例で確かめる
（設計書 07-04「交換の形式の版」）。一般の性質は `Exchange/Range.lean`・`Exchange/Convert.lean` の定理にある。
-/
namespace Benitoite.Exchange.RangeExamples
open Lean Benitoite.Scope.Domain Benitoite.Scope.Signature

private def dataTree : Range := .path (.tree ["data"])
private def v4cidr : Range := .host (.ip (.cidr ⟨.v4, ⟨0xc0000200, by decide⟩, 24⟩))
private def apiEndpoint : Range := .endpoint ⟨.name (.many ["example", "com"]), ⟨443, 443⟩⟩

-- 範囲と範囲の位置は書き出しと読み込みで往復する（一般の補題は `decodeRange_encodeRange`）。
#guard [Range.top, dataTree, v4cidr, apiEndpoint].all fun r =>
  match decodeRangeStrict (encodeRange r) with | .ok r' => r' == r | .error _ => false
#guard [Ix.top, .fixed dataTree, .rvar 1].all fun ix =>
  match decodeIxStrict (encodeIx ix) with | .ok ix' => ix' == ix | .error _ => false

-- 余りの欄、族の幅を超える値、範囲外のポートは誤りにする（黙って切り詰めない）。
#guard !(decodeRangeStrict (Json.mkObj [("path", Json.mkObj [("tree", encodeWord ["data"])]),
  ("extra", Json.null)])).isOk
#guard !(decodeIPAddr (Json.mkObj [("family", .str "v4"), ("bits", encodeNat (2 ^ 32))])).isOk
#guard !(decodePort (encodeNat 65536)).isOk

/-- 新版の名前の原子と不透明型。 -/
private def writeAtom : Atom := .name "File.Write" (.fixed dataTree)
private def pathIn : Ty := .opaque "Scope.PathIn" (.fixed dataTree)

#guard match (fromJson? (toJson writeAtom) : Except String Atom) with
  | .ok a => a == writeAtom | .error _ => false
#guard match (fromJson? (toJson pathIn) : Except String Ty) with
  | .ok t => t == pathIn | .error _ => false
-- 新版は範囲の位置の欄を必須とし、欠けた欄を Top で補わない。
#guard !(fromJson? (legacyNameAtomJson "File.Write") : Except String Atom).isOk
#guard !(fromJson? (legacyOpaqueJson "IOError") : Except String Ty).isOk
-- 旧版の綴りは明示の Top を加えてから読む。
#guard match (fromJson? (legacyRanges (legacyNameAtomJson "File.Write")) : Except String Atom) with
  | .ok a => a == .name "File.Write" Ix.top | .error _ => false
#guard match (fromJson? (legacyRanges (legacyOpaqueJson "IOError")) : Except String Ty) with
  | .ok t => t == .opaque "IOError" Ix.top | .error _ => false

private def versioned (kind : String) (version : Nat) (payload : Json) : Json :=
  Json.mkObj [("version", toJson version), (kind, payload)]

-- 旧版に範囲の欄を置かせない。新版の corpus に範囲の変数を置かせない（組み込みの表の署名だけが持つ）。
#guard !(exchangeJson "corpus" (versioned "x" 14 (toJson writeAtom))).isOk
#guard (exchangeJson "corpus" (versioned "x" 15 (toJson writeAtom))).isOk
#guard !(exchangeJson "corpus" (versioned "x" 15 (toJson (Atom.name "File.Write" (.rvar 0))))).isOk
-- 組み込みの表でも、範囲の変数は項目の署名の中だけに、項目の範囲の変数の個数より小さい番号で置ける（L50.2）。
#guard !(exchangeJson "builtins" (versioned "x" 7 (toJson (Atom.name "File.Write" (.rvar 0))))).isOk
private def primWith (rkinds : List Kind) (eff : List Atom) : Json :=
  Json.mkObj [("version", toJson 7), ("inputs", Json.arr #[Json.mkObj [
    ("prims", Json.arr #[Json.mkObj [("name", .str "File.writeTextIn"), ("rkinds", toJson rkinds), ("eff", toJson eff)]]),
    ("admitsR", Json.arr #[])]])]
#guard (exchangeJson "builtins" (primWith [.path] [Atom.name "File.Write" (.rvar 0)])).isOk
#guard !(exchangeJson "builtins" (primWith [.path] [Atom.name "File.Write" (.rvar 1)])).isOk
#guard !(exchangeJson "builtins" (primWith [] [Atom.name "File.Write" (.rvar 0)])).isOk
#guard !(exchangeJson "stdlib" (versioned "x" 7 (toJson (Atom.name "File.Write" (.rvar 0))))).isOk
-- 旧版の corpus の原子と呼び出しは、明示の Top と空の範囲の列で読む。
#guard match exchangeJson "corpus" (versioned "x" 14 (legacyNameAtomJson "File.Write")) with
  | .ok j => ((j.getObjVal? "x").bind (fromJson? · : Json → Except String Atom)).toOption ==
      some (.name "File.Write" Ix.top)
  | .error _ => false
private def legacyPrim : Json := Json.mkObj [("prim", Json.mkObj [("name", .str "File.readText"),
  ("tys", Json.arr #[]), ("effs", Json.arr #[])])]
#guard match exchangeJson "corpus" (versioned "x" 14 legacyPrim) with
  | .ok j => ((j.getObjVal? "x").bind decodeVal).toOption == some (.prim "File.readText" [] [] [])
  | .error _ => false
-- 新版の呼び出しは範囲の列の欄を必須とする。
#guard !(decodeVal legacyPrim).isOk
#guard [8, 9, 10, 11, 12, 13, 14, 15].map sidecarVersion == [2, 3, 3, 4, 4, 5, 6, 7]

/-! ## 項の範囲の列と効果の書き出し -/

private def atoms : Eff := [.name "State" Ix.top, writeAtom, .name "File.Read" Ix.top]

-- 項 `.prim` の範囲の列を書き出す（L40.5 の誤りを置き換えた）。
#guard match fromVal atoms (fun _ => 0) (.prim "File.writeTextIn" [] [] [dataTree]) with
  | .ok v => v == .prim "File.writeTextIn" [] [] [dataTree] | .error _ => false

private def writeEff : Release.Eff := .mk (fun a => a == .name "File.Write" (.fixed dataTree)) []

-- 範囲付きの原子は一覧にあれば書き出す。
#guard match fromEff atoms writeEff with
  | .ok e => e == [writeAtom] | .error _ => false
-- 一覧にない範囲付きの原子は、候補にあれば誤りにする（黙って落とさない）。
#guard !(fromEff [.name "State" Ix.top] writeEff [.name "File.Write" (.fixed dataTree)]).isOk
-- 原子が全て Top の効果を読んで書き戻すと同じ列になる（一般の定理は `top_eff_roundtrip`）。
#guard match fromEff atoms (Eff.namesToRelease [.name "File.Read" Ix.top, .name "State" Ix.top]) with
  | .ok e => (Eff.namesToRelease e).test (.nameTop "File.Read") && (Eff.namesToRelease e).test (.nameTop "State") &&
      e.length == 2
  | .error _ => false

/-! ## 署名と表のデータ -/

private def admits : List AdmitsEntry :=
  [⟨"Scope.widenPathIn", .covers 0 1⟩, ⟨"File.writeTextIn", .any⟩]

-- 拡大は戻りの範囲が入力の範囲を覆う組だけを許す（`ScopeAcceptExamples.admitsRDec` と同じ判定）。
#guard AdmitsEntry.admitsRDec admits "Scope.widenPathIn" [.path (.tree ["data", "x"]), dataTree]
#guard !AdmitsEntry.admitsRDec admits "Scope.widenPathIn" [dataTree, .path (.tree ["data", "x"])]
#guard AdmitsEntry.admitsRDec admits "File.writeTextIn" [dataTree]
#guard !AdmitsEntry.admitsRDec admits "File.readTextIn" [dataTree]

-- 署名の形・種類・表のデータは往復する。
#guard [IOShape.untargeted, .topTargeted .path, .single .endpoint 0].all fun s =>
  match (fromJson? (toJson s) : Except String IOShape) with | .ok s' => s' == s | .error _ => false
#guard match (fromJson? (toJson admits) : Except String (List AdmitsEntry)) with
  | .ok xs => xs.map (·.rule) == admits.map (·.rule) | .error _ => false

-- 具体化した範囲の原子を交換の原子の一覧に加える。
#guard instAtoms [.name "File.Write" (.rvar 0), .name "State" Ix.top] [dataTree] == [writeAtom]
#guard instAtoms [.name "File.Write" (.rvar 1)] [dataTree] == []

end Benitoite.Exchange.RangeExamples
