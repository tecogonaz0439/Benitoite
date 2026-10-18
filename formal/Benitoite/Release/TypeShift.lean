import Benitoite.Release.Normalize

/-!
# 型とエフェクトの変数移動

型内部の Fail のエラー型まで移動する。束縛を越える移動は型変数だけを対象とする。
型構築後の正規形は、設計書 07-04「01-12 との対応」に従う。
-/

namespace Benitoite.Release

open Std Order

mutual
  /-- 正規化前の型の変数移動。 -/
  def Ty.rawShift (k c : Nat) : Ty → Ty
    | .base b => .base b
    | .opaque o => .opaque o
    | .data d as => .data d (Ty.rawShiftTys k c as)
    | .list a => .list (a.rawShift k c)
    | .fn ns ps r e => .fn ns (Ty.rawShiftTys k c ps) (r.rawShift k c) (Eff.rawShift k c e)
    | .tvar i => .tvar (if i < c then i else i + k)
    | .reference a => .reference (a.rawShift k c)
    | .lazy a => .lazy (a.rawShift k c)
    | .cont b t e => .cont (b.rawShift k c) (t.rawShift k c) (Eff.rawShift k c e)
    | .map a b => .map (a.rawShift k c) (b.rawShift k c)
    | .set a => .set (a.rawShift k c)
    | .bytes => .bytes
    | .dict cl a => .dict cl (a.rawShift k c)
    | .tapp i as => .tapp (if i < c then i else i + k) (Ty.rawShiftTys k c as)
    | .ctor c => .ctor c
  termination_by structural t => t

  def Ty.rawShiftTys (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => a.rawShift k c :: Ty.rawShiftTys k c as
  termination_by structural as => as

  /-- 行変数の番号は変えず、Fail の型だけを移動する。 -/
  def Eff.rawShift (k c : Nat) : Eff → Eff
    | .mk a fs => .mk a (Ty.rawShiftTys k c fs)
  termination_by structural e => e
end

@[simp] theorem Ty.rawShiftTys_eq_map (k c : Nat) (as : List Ty) :
    Ty.rawShiftTys k c as = as.map (Ty.rawShift k c) := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [Ty.rawShiftTys, List.map_cons, ih]

private theorem shiftIndex_compare (k c i j : Nat) :
    compare (if i < c then i else i + k) (if j < c then j else j + k) = compare i j := by
  have hlt : ∀ i j, (if i < c then i else i + k) < (if j < c then j else j + k) ↔ i < j := by
    intro i j
    split <;> split <;> omega
  simp only [Nat.compare_eq_ite_lt, hlt]

mutual
  /-- 生の移動は、型の生の辞書式順序を保つ。 -/
  theorem Ty.rawShift_compare (k c : Nat) (a b : Ty) :
      tyCompare (a.rawShift k c) (b.rawShift k c) = tyCompare a b := by
    cases a <;> cases b <;>
      simp only [Ty.rawShift, tyCompare, Ty.rank, Ty.rawShift_compare,
        Ty.rawShiftTys_compare, Eff.rawShift_compare, shiftIndex_compare]

  theorem Ty.rawShiftTys_compare (k c : Nat) (as bs : List Ty) :
      tysCompare (Ty.rawShiftTys k c as) (Ty.rawShiftTys k c bs) = tysCompare as bs := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs => simp only [Ty.rawShiftTys, tysCompare, Ty.rawShift_compare, Ty.rawShiftTys_compare]

  theorem Eff.rawShift_compare (k c : Nat) (e f : Eff) :
      effCompare (Eff.rawShift k c e) (Eff.rawShift k c f) = effCompare e f := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs => simp only [Eff.rawShift, effCompare, Ty.rawShiftTys_compare]
end

mutual
  /-- 正規化と生の移動の順序は交換できる。 -/
  theorem Ty.norm_rawShift (k c : Nat) (t : Ty) :
      (t.rawShift k c).norm = t.norm.rawShift k c := by
    cases t <;> simp only [Ty.rawShift, Ty.norm, Ty.norm_rawShift, Ty.normTys_rawShift, Eff.norm_rawShift]

  theorem Ty.normTys_rawShift (k c : Nat) (as : List Ty) :
      Ty.normTys (Ty.rawShiftTys k c as) = Ty.rawShiftTys k c (Ty.normTys as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawShiftTys, Ty.normTys, Ty.norm_rawShift, Ty.normTys_rawShift]

  theorem Eff.norm_rawShift (k c : Nat) (e : Eff) :
      Eff.norm (Eff.rawShift k c e) = Eff.rawShift k c (Eff.norm e) := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawShift, Eff.norm]
      rw [Ty.normTys_rawShift]
      simp only [Ty.rawShiftTys_eq_map]
      rw [sortUnique_map tyCompare tyCompare (Ty.rawShift k c) (Ty.rawShift_compare k c)]
end


/-- 生の移動でも、入力が正規形なら正規形を保つ。 -/
theorem Ty.rawShift_canonical (k c : Nat) {t : Ty} (h : t.Canonical) :
    (t.rawShift k c).Canonical := by
  unfold Ty.Canonical at h ⊢
  rw [Ty.norm_rawShift, h]

theorem Eff.rawShift_canonical (k c : Nat) {e : Eff} (h : Eff.Canonical e) :
    Eff.Canonical (Eff.rawShift k c e) := by
  unfold Eff.Canonical at h ⊢
  rw [Eff.norm_rawShift, h]

/-- 効果の公開する移動も同じ正規化を通す。 -/
noncomputable def Eff.shift (k c : Nat) (e : Eff) : Eff := Eff.norm (Eff.rawShift k c e)

mutual
  /-- 型の変数の番号を、`c` 以上のものだけ `k` ずらす。 -/
  noncomputable def Ty.shift (k c : Nat) : Ty → Ty
    | .base ι => .base ι
    | .opaque o => .opaque o
    | .data d args => .data d (Ty.shiftTys k c args)
    | .list a => .list (Ty.shift k c a)
    | .fn names params ret eff => .fn names (Ty.shiftTys k c params) (Ty.shift k c ret) (Eff.shift k c eff)
    | .tvar i => if i < c then .tvar i else .tvar (i + k)
    | .reference a => .reference (Ty.shift k c a)
    | .lazy a => .lazy (Ty.shift k c a)
    | .cont b t eff => .cont (Ty.shift k c b) (Ty.shift k c t) (Eff.shift k c eff)
    | .map a b => .map (Ty.shift k c a) (Ty.shift k c b)
    | .set a => .set (Ty.shift k c a)
    | .bytes => .bytes
    | .dict cl τ => .dict cl (Ty.shift k c τ)
    | .tapp i args => .tapp (if i < c then i else i + k) (Ty.shiftTys k c args)
    | .ctor φ => .ctor φ
  termination_by structural t => t

  /-- 型列も同じ再帰に含め、入れ子の型の移動をカーネルで簡約できるようにする。 -/
  noncomputable def Ty.shiftTys (k c : Nat) : List Ty → List Ty
    | [] => []
    | a :: as => Ty.shift k c a :: Ty.shiftTys k c as
  termination_by structural as => as
end

mutual
  /-- 公開する型の移動と、生の移動後の正規化は一致する。 -/
  theorem Ty.shift_eq_norm_rawShift (k c : Nat) (t : Ty) : t.shift k c = (t.rawShift k c).norm := by
    cases t <;> simp only [Ty.shift, Ty.rawShift, Ty.norm, Ty.shift_eq_norm_rawShift,
      Ty.shiftTys_eq_norm_rawShift, Eff.shift]
    case tvar i => split <;> rfl

  theorem Ty.shiftTys_eq_norm_rawShift (k c : Nat) (as : List Ty) :
      Ty.shiftTys k c as = Ty.normTys (Ty.rawShiftTys k c as) := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.shiftTys, Ty.rawShiftTys, Ty.normTys, Ty.shift_eq_norm_rawShift,
        Ty.shiftTys_eq_norm_rawShift]
end

/-- 正規形の型の移動は正規形を保つ。 -/
theorem Ty.shift_canonical (k c : Nat) (t : Ty) : (t.shift k c).Canonical := by
  rw [Ty.Canonical, Ty.shift_eq_norm_rawShift]; exact Ty.norm_idem _

theorem Eff.shift_canonical (k c : Nat) (e : Eff) : Eff.Canonical (Eff.shift k c e) := Eff.norm_idem _

mutual
  theorem Ty.rawShift_zero (c : Nat) (t : Ty) : t.rawShift 0 c = t := by
    cases t <;> simp only [Ty.rawShift, Ty.rawShift_zero, Ty.rawShiftTys_zero, Eff.rawShift_zero, Nat.add_zero, ite_self]

  theorem Ty.rawShiftTys_zero (c : Nat) (as : List Ty) : Ty.rawShiftTys 0 c as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.rawShiftTys, Ty.rawShift_zero, Ty.rawShiftTys_zero]

  theorem Eff.rawShift_zero (c : Nat) (e : Eff) : Eff.rawShift 0 c e = e := by
    cases e with
    | mk a fs => simp only [Eff.rawShift, Ty.rawShiftTys_zero]
end

/-- 非正規な入力での公開操作の恒等式は、正規化までを含む。 -/
theorem Ty.shift_zero_norm (c : Nat) (t : Ty) : t.shift 0 c = t.norm := by
  rw [Ty.shift_eq_norm_rawShift, Ty.rawShift_zero]

theorem Eff.shift_zero_norm (c : Nat) (e : Eff) : Eff.shift 0 c e = Eff.norm e := by
  rw [Eff.shift, Eff.rawShift_zero]

end Benitoite.Release
