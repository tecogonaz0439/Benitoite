import Benitoite.Exchange.Syntax

/-! # 篩を含む交換の版

入力の構文は `Exchange.Syntax` の型を使い、同じ欄を二つの型に重ねない。
コーパスと付随の表の版を一組として判定する（設計書 07-04「交換の形式の版」）。
-/
namespace Benitoite.Exchange.Refined
open Lean

abbrev RangeIndex := Benitoite.Release.Refinement.RangeIx
abbrev TyCon := Exchange.TyCon
abbrev Atom := Exchange.Atom
abbrev Ty := Exchange.Ty
abbrev Header := Exchange.Header
abbrev AliasEntry := Exchange.AliasEntry
abbrev RecordEntry := Exchange.RecordEntry
abbrev TesterEntry := Exchange.TesterEntry

def corpusVersion : Nat := 16
def sidecarVersion : Nat := 8

def versionOf (kind : String) : Nat := if kind == "corpus" then corpusVersion else sidecarVersion

def readVersion (kind : String) (j : Json) : Except String Unit := do
  let version ← j.getObjValAs? Nat "version"
  if version != versionOf kind then
    throw s!"unsupported {kind} exchange version: {version}; regenerate with version {versionOf kind}"

/-- 一つ前の版は拒否し、現在のコーパスと付随の表の版は受ける。 -/
example : (readVersion "corpus" (Json.mkObj [("version", toJson (15 : Nat))])).toBool = false ∧
    (readVersion "corpus" (Json.mkObj [("version", toJson corpusVersion)])).toBool = true ∧
    (readVersion "builtins" (Json.mkObj [("version", toJson (7 : Nat))])).toBool = false ∧
    (readVersion "builtins" (Json.mkObj [("version", toJson sidecarVersion)])).toBool = true := by
  decide

/-- 篩付きの引数と証明の上限を持つ関数の頭部。 -/
example : Header :=
  { tparams := [], tparamKinds := [], neffs := 0, effParams := [], names := ["x"],
    params := [.refined (.base "Integer") (.lt (.integer 0) (.var 0))], ret := .base "Integer", eff := [],
    rangeParams := [], proofSteps := some 500 }

end Benitoite.Exchange.Refined
