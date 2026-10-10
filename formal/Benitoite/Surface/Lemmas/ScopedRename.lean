import Benitoite.Release.Lemmas.Closed

/-! 任意のエフェクト変数の範囲を保つ、コアの番号の付け替え。 -/

namespace Benitoite.Surface
open Benitoite.Release

mutual
  theorem Val.VarsIn.renameScoped {n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) : (v : Val) → Val.VarsIn n pe v →
      Val.VarsIn n pe (v.rename ξ)
    | .var _, _ => trivial
    | .const _, _ => trivial
    | .fnRef _ _ _, h => h
    | .prim _ _ _, h => h
    | .lam ps body, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Comp.VarsIn.renameScoped _ body h.2⟩
    | .con _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.renameScoped ξ args h.2⟩
    | .list elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsInList.renameScoped ξ elems h
    | .op _ _, h => h
    | .loc _, _ => trivial
    | .mapV ks vs, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨Val.VarsInList.renameScoped ξ ks h.1, Val.VarsInList.renameScoped ξ vs h.2⟩
    | .setV elems, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsInList.renameScoped ξ elems h
    | .bytesV _, _ => by simp [Val.rename, Val.VarsIn]
    | .dict _ _ args, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]
        exact ⟨h.1, Val.VarsInList.renameScoped ξ args h.2⟩
    | .super v _, h => by
        simp only [Val.VarsIn] at h; simp only [Val.rename, Val.VarsIn]; exact Val.VarsIn.renameScoped ξ v h

  theorem Val.VarsInList.renameScoped {n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) : (vs : List Val) →
      Val.VarsInList n pe vs → Val.VarsInList n pe (Val.renameList ξ vs)
    | [], _ => trivial
    | v :: vs, h => by
        simp only [Val.VarsInList] at h; simp only [Val.renameList, Val.VarsInList]
        exact ⟨Val.VarsIn.renameScoped ξ v h.1, Val.VarsInList.renameScoped ξ vs h.2⟩

  theorem Comp.VarsIn.renameScoped {n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) : (m : Comp) → Comp.VarsIn n pe m →
      Comp.VarsIn n pe (m.rename ξ)
    | .ret v, h => by simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Val.VarsIn.renameScoped ξ v h
    | .letIn m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Comp.VarsIn.renameScoped ξ m h.1, Comp.VarsIn.renameScoped _ k h.2⟩
    | .app f args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameScoped ξ f h.1, Val.VarsInList.renameScoped ξ args h.2⟩
    | .ite v m k, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameScoped ξ v h.1, Comp.VarsIn.renameScoped ξ m h.2.1, Comp.VarsIn.renameScoped ξ k h.2.2⟩
    | .match v arms, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameScoped ξ v h.1, Arm.VarsInList.renameScoped ξ arms h.2⟩
    | .lazyC m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Comp.VarsIn.renameScoped ξ m h
    | .escape v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]; exact Val.VarsIn.renameScoped ξ v h
    | .use v m, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameScoped ξ v h.1, Comp.VarsIn.renameScoped ξ m h.2⟩
    | .handle m hs, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Comp.VarsIn.renameScoped ξ m h.1, Clause.VarsInList.renameScoped ξ hs h.2⟩
    | .resume k v, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameScoped ξ k h.1, Val.VarsIn.renameScoped ξ v h.2⟩
    | .meth d _ _ _ args, h => by
        simp only [Comp.VarsIn] at h; simp only [Comp.rename, Comp.VarsIn]
        exact ⟨Val.VarsIn.renameScoped ξ d h.1, h.2.1, h.2.2.1, Val.VarsInList.renameScoped ξ args h.2.2.2⟩

  theorem Arm.VarsInList.renameScoped {n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) : (arms : List Arm) →
      Arm.VarsInList n pe arms →
      Arm.VarsInList n pe (Arm.renameList ξ arms)
    | [], _ => trivial
    | .mk alts none m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.renameList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.renameScoped _ m h.1, Arm.VarsInList.renameScoped ξ arms h.2⟩
    | .mk alts (some g) m :: arms, h => by
        simp only [Arm.VarsInList] at h; simp only [Arm.renameList, Arm.VarsInList]
        exact ⟨Comp.VarsIn.renameScoped _ g h.1,
          Comp.VarsIn.renameScoped _ m h.2.1, Arm.VarsInList.renameScoped ξ arms h.2.2⟩

  theorem Clause.VarsInList.renameScoped {n : Nat} {pe : Nat → Prop} (ξ : Nat → Nat) : (hs : List Clause) →
      Clause.VarsInList n pe hs →
      Clause.VarsInList n pe (Clause.renameList ξ hs)
    | [], _ => trivial
    | .mk o a k m :: cs, h => by
        simp only [Clause.VarsInList] at h; simp only [Clause.renameList, Clause.VarsInList]
        exact ⟨Comp.VarsIn.renameScoped _ m h.1, Clause.VarsInList.renameScoped ξ cs h.2⟩
end

end Benitoite.Surface
