import Benitoite.Release.TypeScopedSubst

/-! Fail の一要素の効果と型代入の対応。型の内部の正規化も保持する。 -/
namespace Benitoite.Release

/-- Fail の型を型と行の代入で変換する。 -/
theorem Eff.substAt_singleFail (c : Nat) (ts : List Ty) (es : List Eff) (t : Ty) :
    Eff.substAt c ts es (Eff.singleFail t) = Eff.singleFail (t.substAt c ts es) := by
  simp only [Eff.singleFail, Eff.substAt, Eff.rawSubstAt, Eff.rawBind,
    Eff.substAtoms_false, Eff.rowFails_false, Ty.rawBindTys, List.append_nil,
    Eff.norm, Ty.normTys, Ty.norm_rawBind, Ty.norm_idem,
    Order.sortUnique_singleton, Ty.substAt_eq_rawBind]

end Benitoite.Release
