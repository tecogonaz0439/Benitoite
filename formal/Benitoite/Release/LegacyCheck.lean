import Benitoite.Release.Normalize

/-!
# 旧入力の計算できる検査

型と潜在効果をすべて辿り、Failを持たない入力を検出する。
検査器の移行中の制限に使う（設計書 07-04「01-12 との対応」）。
-/
namespace Benitoite.Release

/-- 最上位にFailの型があれば旧入力ではない。 -/
def Eff.isLegacy (e : Eff) : Bool := e.fails.isEmpty

mutual
  def Ty.isLegacy : Ty → Bool
    | .data _ ts | .tapp _ ts => Ty.areLegacy ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t => t.isLegacy
    | .fn _ ps r e => Ty.areLegacy ps && r.isLegacy && Eff.isLegacy e
    | .cont a b e => a.isLegacy && b.isLegacy && Eff.isLegacy e
    | .map a b => a.isLegacy && b.isLegacy
    | _ => true
  def Ty.areLegacy : List Ty → Bool
    | [] => true
    | t :: ts => t.isLegacy && Ty.areLegacy ts
end

@[simp] theorem Eff.isLegacy_spec (e : Eff) : Eff.isLegacy e = true ↔ Eff.Legacy e :=
  List.isEmpty_iff

mutual
  theorem Ty.isLegacy_spec (t : Ty) : t.isLegacy = true ↔ t.Legacy := by
    cases t <;> simp [Ty.isLegacy, Ty.Legacy, Ty.isLegacy_spec, Ty.areLegacy_spec,
      Eff.isLegacy_spec, Bool.and_eq_true, and_assoc]
  theorem Ty.areLegacy_spec (ts : List Ty) : Ty.areLegacy ts = true ↔ Ty.LegacyTys ts := by
    cases ts with
    | nil => simp [Ty.areLegacy, Ty.LegacyTys]
    | cons t ts => simp only [Ty.areLegacy, Ty.LegacyTys, Bool.and_eq_true, Ty.isLegacy_spec, Ty.areLegacy_spec]
end

end Benitoite.Release
