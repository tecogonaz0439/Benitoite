import Benitoite.Release.Refinement.ValueRenamingSyntax
import Benitoite.Release.Refinement.TermStructuralEq

/-!
# 値の改名で変わらない型の有限判定

型の効果の原子の所属は関数であり、型の等号は一般には判定できない。値の改名は原子の所属を変えず、
型・依存列・行と篩の述語だけを書き換える。改名の前後を述語の構造の等号で比べれば、改名で変わらないことを
有限に判定できる。部分適用の脱糖が非依存のラムダを選ぶ条件（外側の文脈から移した型として書けること）は、
この判定で決まる（設計書 01-12「部分適用」）。
-/
namespace Benitoite.Release.Refinement

mutual
  /-- 値の改名 ξ が型を変えないことの判定。 -/
  def Ty.renameFixed (ξ : Nat → Nat) : Ty → Bool
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ | .scoped _ _ _ | .pathBases | .scopePattern _ => true
    | .data _ as | .tapp _ as | .external _ as => renameFixedTys ξ as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.renameFixed ξ
    | .fn _ ps r e => renameFixedTys ξ ps && r.renameFixed ξ && Eff.renameFixed ξ e
    | .cont b t e => b.renameFixed ξ && t.renameFixed ξ && Eff.renameFixed ξ e
    | .map a b => a.renameFixed ξ && b.renameFixed ξ
    | .refined a p => a.renameFixed ξ && predEq (predBind (fun i => some (.var (valueUp ξ i))) p) p
    | .dependentFn t => t.renameFixed ξ
  def Tel.renameFixed (ξ : Nat → Nat) : Tel → Bool
    | .done r e => r.renameFixed ξ && Eff.renameFixed ξ e
    | .param _ a t => a.renameFixed ξ && t.renameFixed (valueUp ξ)
  def Eff.renameFixed (ξ : Nat → Nat) : Eff → Bool
    | .mk _ fs => renameFixedTys ξ fs
  def renameFixedTys (ξ : Nat → Nat) : List Ty → Bool
    | [] => true
    | a :: as => a.renameFixed ξ && renameFixedTys ξ as
end

mutual
  theorem Ty.renameFixed_iff (ξ : Nat → Nat) (a : Ty) : a.renameFixed ξ = true ↔ a.renameValues ξ = a := by
    cases a <;> simp only [Ty.renameFixed, Ty.renameValues, Bool.and_eq_true, Ty.renameFixed_iff,
      Tel.renameFixed_iff, Eff.renameFixed_iff, renameFixedTys_iff, predEq_spec, Ty.data.injEq,
      Ty.list.injEq, Ty.fn.injEq, Ty.reference.injEq, Ty.lazy.injEq, Ty.cont.injEq, Ty.map.injEq,
      Ty.set.injEq, Ty.dict.injEq, Ty.tapp.injEq, Ty.refined.injEq, Ty.dependentFn.injEq,
      Ty.external.injEq, true_and, and_assoc]
  theorem Tel.renameFixed_iff (ξ : Nat → Nat) (t : Tel) : t.renameFixed ξ = true ↔ t.renameValues ξ = t := by
    cases t <;> simp only [Tel.renameFixed, Tel.renameValues, Bool.and_eq_true, Ty.renameFixed_iff,
      Tel.renameFixed_iff, Eff.renameFixed_iff, Tel.done.injEq, Tel.param.injEq, true_and]
  theorem Eff.renameFixed_iff (ξ : Nat → Nat) (e : Eff) : Eff.renameFixed ξ e = true ↔ Eff.renameValues ξ e = e := by
    cases e; simp only [Eff.renameFixed, Eff.renameValues, renameFixedTys_iff, EffR.mk.injEq, true_and]
  theorem renameFixedTys_iff (ξ : Nat → Nat) (as : List Ty) : renameFixedTys ξ as = true ↔ renameValueTys ξ as = as := by
    cases as <;> simp only [renameFixedTys, renameValueTys, Bool.and_eq_true, Ty.renameFixed_iff,
      renameFixedTys_iff, List.cons.injEq]
end

/-- 外側の文脈の型を k 個の値の束縛の下へ移した像であることの判定に使う改名。 -/
def shiftImage (k : Nat) (i : Nat) : Nat := shiftIndex k 0 (unshiftValue k 0 i)

/-- 型が k 個の束縛の下へ移した像であることと、移し直しの改名で変わらないことは同値である。 -/
theorem Ty.shiftImage_iff (k : Nat) (a : Ty) :
    (∃ a0 : Ty, a = a0.shiftV k 0) ↔ a.renameFixed (shiftImage k) = true := by
  rw [Ty.renameFixed_iff]
  constructor
  · rintro ⟨a0, rfl⟩
    rw [show shiftImage k = fun i => shiftIndex k 0 (unshiftValue k 0 i) from rfl,
      ← Ty.renameValues_comp, Ty.unshift_shift, Ty.shiftV_eq_renameValues]
  · intro h
    refine ⟨a.renameValues (unshiftValue k 0), ?_⟩
    rw [Ty.shiftV_eq_renameValues, Ty.renameValues_comp]
    exact h.symm

theorem Eff.shiftImage_iff (k : Nat) (e : Eff) :
    (∃ e0 : Eff, e = Eff.shiftV k 0 e0) ↔ Eff.renameFixed (shiftImage k) e = true := by
  rw [Eff.renameFixed_iff]
  constructor
  · rintro ⟨e0, rfl⟩
    rw [show shiftImage k = fun i => shiftIndex k 0 (unshiftValue k 0 i) from rfl,
      ← Eff.renameValues_comp, Eff.unshift_shift, Eff.shiftV_eq_renameValues]
  · intro h
    refine ⟨Eff.renameValues (unshiftValue k 0) e, ?_⟩
    rw [Eff.shiftV_eq_renameValues, Eff.renameValues_comp]
    exact h.symm

/-- 結果型と効果の両方が移した像であることの判定。部分適用の脱糖の分岐の条件と同値である。 -/
theorem shiftImage_pair_iff (k : Nat) (r : Ty) (e : Eff) :
    (∃ (r0 : Ty) (e0 : Eff), r = r0.shiftV k 0 ∧ e = Eff.shiftV k 0 e0) ↔
      (r.renameFixed (shiftImage k) && Eff.renameFixed (shiftImage k) e) = true := by
  rw [Bool.and_eq_true, ← Ty.shiftImage_iff, ← Eff.shiftImage_iff]
  constructor
  · rintro ⟨r0, e0, hr, he⟩; exact ⟨⟨r0, hr⟩, ⟨e0, he⟩⟩
  · rintro ⟨⟨r0, hr⟩, ⟨e0, he⟩⟩; exact ⟨r0, e0, hr, he⟩

end Benitoite.Release.Refinement
