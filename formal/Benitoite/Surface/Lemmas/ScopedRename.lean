import Benitoite.Release.Lemmas.Closed

/-! 任意のエフェクト変数の範囲を保つ、コアの番号の付け替え。 -/

namespace Benitoite.Surface
open Benitoite.Release

theorem Val.VarsIn.renameScoped {depth n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) (v : Val)
    (h : Val.VarsIn n pe v) : Val.VarsIn n pe (v.rename ξ) depth :=
  Benitoite.Release.Val.VarsIn.renameLocal ξ (by omega) v h

theorem Val.VarsInList.renameScoped {depth n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) (vs : List Val)
    (h : Val.VarsInList n pe vs) : Val.VarsInList n pe (Val.renameList ξ vs) depth :=
  Benitoite.Release.Val.VarsInList.renameLocal ξ (by omega) vs h

theorem Comp.VarsIn.renameScoped {depth n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) (m : Comp)
    (h : Comp.VarsIn n pe m) : Comp.VarsIn n pe (m.rename ξ) depth :=
  Benitoite.Release.Comp.VarsIn.renameLocal ξ (by omega) m h

theorem Arm.VarsInList.renameScoped {depth n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) (arms : List Arm)
    (h : Arm.VarsInList n pe arms) : Arm.VarsInList n pe (Arm.renameList ξ arms) depth :=
  Benitoite.Release.Arm.VarsInList.renameLocal ξ (by omega) arms h

theorem Clause.VarsInList.renameScoped {depth n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) (hs : List Clause)
    (h : Clause.VarsInList n pe hs) : Clause.VarsInList n pe (Clause.renameList ξ hs) depth :=
  Benitoite.Release.Clause.VarsInList.renameLocal ξ (by omega) hs h

end Benitoite.Surface
