import Benitoite.Release.Subst

/-!
# 局所参照の番号と置換

通常変数と局所参照は束縛の番号を共有するが、局所の場所を通常値へ移す操作は置かない。
設計書 01-12「構築器の分類と環境の対応」に対応する。
-/
namespace Benitoite.Release

@[simp] theorem LocalRef.rename_id (r : LocalRef) : r.rename id = r := by
  cases r <;> rfl

@[simp] theorem LocalRef.subst_id (r : LocalRef) : r.subst LocalRef.bound = r := by
  cases r <;> rfl

theorem LocalRef.rename_comp (r : LocalRef) (ξ ζ : Nat → Nat) :
    (r.rename ξ).rename ζ = r.rename (ζ ∘ ξ) := by
  cases r <;> rfl

theorem LocalRef.subst_comp (r : LocalRef) (ρ τ : Nat → LocalRef) :
    (r.subst ρ).subst τ = r.subst (fun i => (ρ i).subst τ) := by
  cases r <;> rfl

theorem LocalRef.Scoped.rename {n m : Nat} {r : LocalRef} (h : r.Scoped n)
    {ξ : Nat → Nat} (hξ : ∀ i, i < n → ξ i < m) : (r.rename ξ).Scoped m := by
  cases r with
  | bound i => exact hξ i h
  | loc _ => trivial

theorem LocalRef.Scoped.subst {n m : Nat} {r : LocalRef} (h : r.Scoped n)
    {ρ : Nat → LocalRef} (hρ : ∀ i, i < n → (ρ i).Scoped m) : (r.subst ρ).Scoped m := by
  cases r with
  | bound i => exact hρ i h
  | loc _ => trivial

theorem LocalRef.Scoped.mono {n m : Nat} {r : LocalRef} (h : r.Scoped n) (hn : n ≤ m) :
    r.Scoped m := by
  cases r with
  | bound i => exact Nat.lt_of_lt_of_le h hn
  | loc _ => trivial

theorem upRen_scoped {n m : Nat} {ξ : Nat → Nat}
    (hξ : ∀ i, i < n → ξ i < m) (k : Nat) :
    ∀ i, i < k + n → upRen k ξ i < k + m := by
  intro i hi
  unfold upRen
  split
  · omega
  · have := hξ (i - k) (by omega); omega

theorem upLocalSubst_scoped {n m : Nat} {ρ : Nat → LocalRef}
    (hρ : ∀ i, i < n → (ρ i).Scoped m) (k : Nat) :
    ∀ i, i < k + n → (upLocalSubst k ρ i).Scoped (k + m) := by
  intro i hi
  unfold upLocalSubst
  split
  · change i < k + m; omega
  · exact (hρ (i - k) (by omega)).rename (fun j hj => by omega)

theorem builderLocalSubst_scoped (l n : Nat) :
    ∀ i, i < n + 1 → (builderLocalSubst l i).Scoped n := by
  intro i hi
  cases i with
  | zero => trivial
  | succ i => change i < n; omega

/-- String と Bytes の上限は UTF-8 のバイト数／バイト数である。 -/
def maxBuilderBytes : Nat := 1073741824
/-- List の上限は要素数であり、要素が参照する値の大きさは含めない。 -/
def maxBuilderListLen : Nat := 16777216

theorem maxBuilderBytes_le_max64 : (maxBuilderBytes : Int) ≤ max64 := by decide
theorem maxBuilderListLen_le_max64 : (maxBuilderListLen : Int) ≤ max64 := by decide

end Benitoite.Release
