import Benitoite.Release.Refinement.Context

/-! # 型域の有限な事実

設計書 01-12「篩の正規形と制約の読み方」に対応する。
明示した篩の列と、芯の数値型が与える事実を分ける。
-/
namespace Benitoite.Release.Refinement

def integerBounds (lo hi : Int) : List Pred :=
  [.le (.integer lo) (.var 0), .le (.var 0) (.integer hi)]

def Ty.carrierFacts (a : Ty) : List Pred :=
  match a.core with
  | .base .integer => integerBounds (-9223372036854775808) 9223372036854775807
  | .base .integer8 => integerBounds (-128) 127
  | .base .integer16 => integerBounds (-32768) 32767
  | .base .integer32 => integerBounds (-2147483648) 2147483647
  | .base .unsignedInteger16 => integerBounds 0 65535
  | .base .unsignedInteger32 => integerBounds 0 4294967295
  | .base .unsignedInteger64 => integerBounds 0 18446744073709551615
  | .base .byte => integerBounds 0 255
  | .base .decimal => [.decimalRepresented (.var 0)]
  | _ => []

def Ty.assumeWithCarrier (a : Ty) : List Pred :=
  match a.core with
  | .cont _ _ _ => []
  | _ => a.carrierFacts ++ a.refinementPredicates

def Ctx.factsWithCarrier (Γ : Ctx) : List Pred :=
  (Γ.zipIdx).flatMap fun (a, i) =>
    match a with
    | none => []
    | some a => a.assumeWithCarrier.map (fun p => p.open (.var i))

theorem Ty.assumeWithCarrier_eq_carrier_append {a : Ty} (h : a.Ordinary) :
    a.assumeWithCarrier = a.carrierFacts ++ a.refinementPredicates := by
  unfold Ty.assumeWithCarrier
  cases hc : a.core <;> try rfl
  exact False.elim (h _ _ _ hc)

end Benitoite.Release.Refinement
