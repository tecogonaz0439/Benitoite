import Benitoite.Exchange.Range
import Benitoite.Release.Refinement.ProofContract
import Benitoite.Release.Refinement.Types
import Benitoite.Release.Refinement.Syntax

/-! # 篩の有限構文と論理の証明書の交換

項・述語・証明書の構造を JSON に写す。前提とゴールは推論で再計算し、交換した値の証明書を独立に検査する。
-/
namespace Benitoite.Exchange
open Lean Benitoite.Release.Refinement

instance : ToJson Benitoite.Scope.Domain.PathPattern := ⟨encodePathPattern⟩
instance : FromJson Benitoite.Scope.Domain.PathPattern := ⟨decodePathPattern⟩
instance : ToJson Benitoite.Scope.Domain.IPAddr := ⟨encodeIPAddr⟩
instance : FromJson Benitoite.Scope.Domain.IPAddr := ⟨decodeIPAddr⟩
instance : ToJson Benitoite.Scope.Domain.Port := ⟨encodePort⟩
instance : FromJson Benitoite.Scope.Domain.Port := ⟨decodePort⟩

deriving instance ToJson, FromJson for Benitoite.Scope.Domain.HostTarget, Benitoite.Scope.Domain.Endpoint, Benitoite.Scope.Domain.Target
deriving instance ToJson, FromJson for PathBase, PathEnv, «Sort», FieldRef, Measure, Comparison, FloatClass, FloatWidth, TyKind

/-- 絶対範囲は範囲の構文、基準からの範囲は based、secrets はその専用タグで書く。 -/
def encodeRangeExpr : RangeExpr → Json
  | .absolute r => encodeRange r
  | .based b p => Json.mkObj [("based", Json.mkObj [("base", toJson b), ("pattern", encodePathPattern p)])]
  | .secrets => Json.str "secrets"

def decodeRangeExpr (j : Json) : Except String RangeExpr := do
  if j == Json.str "secrets" then return .secrets
  if let .ok b := j.getObjVal? "based" then
    return .based (← b.getObjValAs? PathBase "base") (← decodePathPattern (← b.getObjVal? "pattern"))
  return .absolute (← decodeRangeStrict j)

def decodeRangeExprStrict (j : Json) : Except String RangeExpr := do
  let r ← decodeRangeExpr j
  if encodeRangeExpr r != j then throw "unexpected symbolic range fields"
  return r

instance : ToJson RangeExpr := ⟨encodeRangeExpr⟩
instance : FromJson RangeExpr := ⟨decodeRangeExprStrict⟩

def encodeRefinedIx : RangeIx → Json
  | .fixed r => Json.mkObj [("fixed", encodeRangeExpr r)]
  | .rvar i => Json.mkObj [("rvar", toJson i)]

def decodeRefinedIx (j : Json) : Except String RangeIx := do
  if let .ok r := j.getObjVal? "fixed" then return .fixed (← decodeRangeExprStrict r)
  if let .ok i := j.getObjVal? "rvar" then return .rvar (← fromJson? i)
  throw "unknown symbolic range position"

def decodeRefinedIxStrict (j : Json) : Except String RangeIx := do
  let r ← decodeRefinedIx j
  if encodeRefinedIx r != j then throw "unexpected symbolic range position fields"
  return r

instance : ToJson RangeIx := ⟨encodeRefinedIx⟩
instance : FromJson RangeIx := ⟨decodeRefinedIxStrict⟩
instance : BEq RangeIx := ⟨fun a b => decide (a = b)⟩
deriving instance Repr for RangeIx

def encodeRefinedNameBody (value : String) (ix : RangeIx) : Json :=
  Json.mkObj [("value", toJson value), ("ix", encodeRefinedIx ix)]

def decodeRefinedNameBody (j : Json) : Except String (String × RangeIx) := do
  return (← j.getObjValAs? String "value", ← decodeRefinedIxStrict (← j.getObjVal? "ix"))

def encodeRefinedOpaqueBody (name : String) (ix : RangeIx) : Json :=
  Json.mkObj [("name", toJson name), ("ix", encodeRefinedIx ix)]

def decodeRefinedOpaqueBody (j : Json) : Except String (String × RangeIx) := do
  return (← j.getObjValAs? String "name", ← decodeRefinedIxStrict (← j.getObjVal? "ix"))

instance : ToJson Char := ⟨fun c => toJson c.toNat⟩
instance : FromJson Char := ⟨fun j => do
  let n : Nat ← fromJson? j
  if n ≤ 0x10ffff && !(0xd800 ≤ n && n ≤ 0xdfff) then return Char.ofNat n
  else throw "invalid Unicode scalar in logic term"⟩
instance : ToJson UInt32 := ⟨fun n => toJson n.toNat⟩
instance : FromJson UInt32 := ⟨fun j => do
  let n : Nat ← fromJson? j
  if n < UInt32.size then return UInt32.ofNat n
  else throw "logic float32 bits outside 32-bit range"⟩

deriving instance ToJson, FromJson for Benitoite.Release.Refinement.Term, Pred
instance : BEq Benitoite.Release.Refinement.Term := ⟨termEq⟩
instance : BEq Pred := ⟨predEq⟩
instance : Repr Benitoite.Release.Refinement.Term := ⟨fun t _ => Std.Format.text (toJson t).compress⟩
instance : Repr Pred := ⟨fun p _ => Std.Format.text (toJson p).compress⟩

deriving instance ToJson, FromJson for Linear, LinearStep, BuiltinLemma, PreparedLeaf, Refutation,
  EqualityMode, EqProof, Certificate, StepAccounting.Phase, StepAccounting.Operation,
  StepAccounting.Cleanup, StepAccounting.Action, ExternalId, ComponentId, ExternalFunctionId,
  ExternalMode, ExternalPosition, ExternalPathStep, ExternalUse

/-- 論理の証明書を引く鍵。問い合わせの前提とゴールは交換しない。 -/
structure LogicCertificateEntry where
  path : List Nat
  index : Nat
  certificate : Certificate
  actions : List StepAccounting.Action
  deriving ToJson, FromJson

/-- 同じ鍵を二度書いた入力を拒否し、一意な証明書の表を作る。 -/
def LogicCertificateEntry.validate (entries : List LogicCertificateEntry) : Except String Unit := do
  let keys := entries.map (fun e => (e.path, e.index))
  if keys.eraseDups.length != keys.length then throw "duplicate logic certificate key"

end Benitoite.Exchange
