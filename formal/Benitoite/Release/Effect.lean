import Benitoite.Release.TypeShift

/-!
# 型を保持するエフェクトの操作

名前と行の点ごとの所属と、正規化した Fail の型の所属を区別する。
包含は両方を要求する（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release.Eff

open Benitoite.Release.Order

/-- 空の効果。 -/
def empty : Eff := .mk (fun _ => false) []

/-- 名前一つの効果。 -/
def single (l : EffName) : Eff := ofAtoms (fun a => a == .nameTop l)

/-- 範囲の位置 ix を持つ名前一つの効果。単一の対象の形の IO の項目の効果 `{L[rvar 0]}` に使う（`Builtins.ShapeOk`）。
`single l` は `singleAt l Ix.top` と同じ項である。 -/
def singleAt (l : EffName) (ix : Scope.Signature.Ix) : Eff := ofAtoms (fun a => a == .name l ix)

theorem single_eq_singleAt (l : EffName) : single l = singleAt l Scope.Signature.Ix.top := rfl

/-- 行一つの効果。 -/
def row (i : Nat) : Eff := ofAtoms (fun a => a == .rho i)

/-- Fail の型を正規化してから一要素の効果にする。 -/
noncomputable def singleFail (t : Ty) : Eff := .mk (fun _ => false) [t.norm]

/-- 名前と行の包含と、Fail の型の集合としての包含。 -/
def Sub (e f : Eff) : Prop :=
  (∀ a, mem e a → mem f a) ∧ (∀ t, memFail e t → memFail f t)

/-- 和は、子の正規化と Fail 列の整列・重複除去を通す。 -/
noncomputable def union (e f : Eff) : Eff := norm (.mk (fun a => test e a || test f a) (e.fails ++ f.fails))

theorem mem_empty (a : Atom) : mem empty a ↔ False := by simp [mem, test, atoms, empty]

theorem mem_single (l : EffName) (a : Atom) : mem (single l) a ↔ a = .nameTop l := by
  simp [mem, test, single, ofAtoms, atoms]

/-- `Eff.single l` は Top の原子だけを含み、範囲付きの同じ名前の原子を含まない。 -/
theorem mem_single_name (l m : EffName) (r : Scope.Signature.Ix) :
    mem (single l) (.name m r) ↔ m = l ∧ r = Scope.Signature.Ix.top := by
  rw [mem_single]
  constructor
  · intro h; cases h; exact ⟨rfl, rfl⟩
  · rintro ⟨rfl, rfl⟩; rfl

theorem mem_singleAt (l : EffName) (ix : Scope.Signature.Ix) (a : Atom) : mem (singleAt l ix) a ↔ a = .name l ix := by
  simp [mem, test, singleAt, ofAtoms, atoms]

theorem mem_row (i : Nat) (a : Atom) : mem (row i) a ↔ a = .rho i := by
  simp [mem, test, row, ofAtoms, atoms]

theorem mem_union (e f : Eff) (a : Atom) : mem (union e f) a ↔ mem e a ∨ mem f a := by
  simp [mem, test, union, norm, atoms]

theorem memFail_empty (t : Ty) : memFail empty t ↔ False := by
  simp [memFail, empty, fails]

theorem memFail_single (l : EffName) (t : Ty) : memFail (single l) t ↔ False := by
  simp [memFail, single, ofAtoms, fails]

theorem memFail_singleFail (a b : Ty) : memFail (singleFail a) b ↔ a.norm = b.norm := by
  simp [memFail, singleFail, fails, Ty.norm_idem]

theorem memFail_union (e f : Eff) (t : Ty) : memFail (union e f) t ↔ memFail e t ∨ memFail f t := by
  unfold union
  rw [norm_memFail]
  simp only [memFail, fails, List.mem_append, or_and_right, exists_or]

/-- 正規化は名前と行の所属を保つ。 -/
@[simp] theorem mem_norm (e : Eff) (a : Atom) : mem (norm e) a ↔ mem e a := by
  cases e; rfl

/-- 生の表現の重複と順序は、包含の結果に影響しない。 -/
theorem sub_norm (e f : Eff) : Sub e f ↔ Sub (norm e) (norm f) := by
  simp only [Sub, mem_norm, norm_memFail]

/-- 和は正規形である。 -/
theorem union_canonical (e f : Eff) : Canonical (union e f) := norm_idem _

/-- 名前だけの効果は、型の正規化の計算を必要としない。 -/
theorem canonical_ofAtoms (a : Atom → Bool) : Canonical (ofAtoms a) := rfl

/-- 正規形に限れば、両方の包含から生の効果の等号が得られる。 -/
theorem eq_of_sub_of_sub {e f : Eff} (he : Canonical e) (hf : Canonical f)
    (hef : Sub e f) (hfe : Sub f e) : e = f := by
  have ha : e.atoms = f.atoms := by
    funext a
    exact Bool.eq_iff_iff.mpr ⟨hef.1 a, hfe.1 a⟩
  have hfs : (norm e).fails = (norm f).fails := by
    cases e with
    | mk a es =>
      cases f with
      | mk b fs =>
        simp only [norm, fails]
        apply (sortUnique_eq_iff_mem).mpr
        intro t
        simp only [Ty.normTys_eq_map, List.mem_map]
        constructor
        · rintro ⟨x, hx, rfl⟩
          obtain ⟨y, hy, hyx⟩ := hef.2 x ⟨x, hx, rfl⟩
          exact ⟨y, hy, hyx⟩
        · rintro ⟨x, hx, rfl⟩
          obtain ⟨y, hy, hyx⟩ := hfe.2 x ⟨x, hx, rfl⟩
          exact ⟨y, hy, hyx⟩
  apply ext (fun a => Bool.eq_iff_iff.mp (congrFun ha a))
  exact (congrArg fails he).symm.trans (hfs.trans (congrArg fails hf))

/-- 型変数の移動は効果の包含を保つ。 -/
theorem shift_mono (k c : Nat) {e f : Eff} (h : Sub e f) : Sub (shift k c e) (shift k c f) := by
  cases e with
  | mk a fs =>
    cases f with
    | mk b gs =>
      constructor
      · exact h.1
      · intro t ht
        rw [shift, norm_memFail] at ht ⊢
        simp only [memFail, rawShift, fails, Ty.rawShiftTys_eq_map, List.mem_map] at ht ⊢
        obtain ⟨x, ⟨y, hy, rfl⟩, hyt⟩ := ht
        obtain ⟨z, hz, hzy⟩ := h.2 y ⟨y, hy, rfl⟩
        refine ⟨z.rawShift k c, ⟨z, hz, rfl⟩, ?_⟩
        rw [Ty.norm_rawShift] at hyt ⊢
        exact (congrArg (Ty.rawShift k c) hzy).trans hyt

/-- 最上位の効果は未整列でも、正規化した効果と相互に包含する。 -/
theorem sub_norm_self (e : Eff) : Sub e (norm e) := by
  simp only [Sub, mem_norm, norm_memFail]
  exact ⟨fun _ => id, fun _ => id⟩

theorem norm_sub_self (e : Eff) : Sub (norm e) e := by
  simp only [Sub, mem_norm, norm_memFail]
  exact ⟨fun _ => id, fun _ => id⟩

end Benitoite.Release.Eff
