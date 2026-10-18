import Benitoite.Release.TypeSubstLemmas

/-!
# Fail の内部を含む行の範囲

潜在効果と Fail の型を同じ共有型上で辿る。行の像の一致は、最外の所属だけでは足りない
（設計書 01-12「コア計算と脱糖」）。
-/

namespace Benitoite.Release

mutual
  /-- 型の中に再帰的に現れるすべての行が条件を満たす。 -/
  def Ty.RowsIn (pe : Nat → Prop) : Ty → Prop
    | .base _ | .opaque _ | .bytes | .ctor _ | .tvar _ => True
    | .data _ as | .tapp _ as => Ty.RowsInList pe as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.RowsIn pe
    | .fn _ ps r e => Ty.RowsInList pe ps ∧ r.RowsIn pe ∧ Eff.RowsIn pe e
    | .cont a b e => a.RowsIn pe ∧ b.RowsIn pe ∧ Eff.RowsIn pe e
    | .map a b => a.RowsIn pe ∧ b.RowsIn pe

  def Ty.RowsInList (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | t :: ts => t.RowsIn pe ∧ Ty.RowsInList pe ts

  /-- 最外の原子と、Fail の型内部の行をともに検査する。 -/
  def Eff.RowsIn (pe : Nat → Prop) : Eff → Prop
    | .mk a fs => (∀ i, a (.rho i) = true → pe i) ∧ Ty.RowsInList pe fs
end

theorem Ty.RowsInList.iff {pe : Nat → Prop} {ts : List Ty} :
    Ty.RowsInList pe ts ↔ ∀ t ∈ ts, t.RowsIn pe := by
  induction ts with
  | nil => simp [Ty.RowsInList]
  | cons t ts ih => simp [Ty.RowsInList, ih]

mutual
  theorem Ty.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
      (t : Ty) (h : t.RowsIn pe) : t.RowsIn pf := by
    cases t <;> simp only [Ty.RowsIn] at h ⊢
    all_goals first
      | trivial
      | exact Ty.RowsIn.mono hp _ h
      | exact Ty.RowsInList.mono hp _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.RowsInList.mono hp ps h.1,
      Ty.RowsIn.mono hp r h.2.1, Eff.RowsIn.mono hp e h.2.2⟩
    case cont a b e => exact ⟨Ty.RowsIn.mono hp a h.1,
      Ty.RowsIn.mono hp b h.2.1, Eff.RowsIn.mono hp e h.2.2⟩
    case map a b => exact ⟨Ty.RowsIn.mono hp a h.1, Ty.RowsIn.mono hp b h.2⟩

  theorem Ty.RowsInList.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
      (ts : List Ty) (h : Ty.RowsInList pe ts) : Ty.RowsInList pf ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.RowsIn.mono hp t h.1, Ty.RowsInList.mono hp ts h.2⟩

  theorem Eff.RowsIn.mono {pe pf : Nat → Prop} (hp : ∀ i, pe i → pf i)
      (e : Eff) (h : Eff.RowsIn pe e) : Eff.RowsIn pf e := by
    cases e with
    | mk a fs => exact ⟨fun i hi => hp i (h.1 i hi), Ty.RowsInList.mono hp fs h.2⟩
end

mutual
  /-- 正規化による並べ替えと重複除去は行の範囲を保つ。 -/
  theorem Ty.norm_rowsIn {pe : Nat → Prop} (t : Ty) (h : t.RowsIn pe) : t.norm.RowsIn pe := by
    cases t <;> simp only [Ty.RowsIn] at h <;> simp only [Ty.norm, Ty.RowsIn]
    all_goals first
      | trivial
      | exact Ty.norm_rowsIn _ h
      | exact Ty.normTys_rowsIn _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.normTys_rowsIn ps h.1,
      Ty.norm_rowsIn r h.2.1, Eff.norm_rowsIn e h.2.2⟩
    case cont a b e => exact ⟨Ty.norm_rowsIn a h.1,
      Ty.norm_rowsIn b h.2.1, Eff.norm_rowsIn e h.2.2⟩
    case map a b => exact ⟨Ty.norm_rowsIn a h.1, Ty.norm_rowsIn b h.2⟩

  theorem Ty.normTys_rowsIn {pe : Nat → Prop} (ts : List Ty) (h : Ty.RowsInList pe ts) :
      Ty.RowsInList pe (Ty.normTys ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.norm_rowsIn t h.1, Ty.normTys_rowsIn ts h.2⟩

  theorem Eff.norm_rowsIn {pe : Nat → Prop} (e : Eff) (h : Eff.RowsIn pe e) :
      Eff.RowsIn pe (Eff.norm e) := by
    cases e with
    | mk a fs =>
      refine ⟨h.1, Ty.RowsInList.iff.mpr ?_⟩
      intro t ht
      exact Ty.RowsInList.iff.mp (Ty.normTys_rowsIn fs h.2) t (Order.mem_sortUnique.mp ht)
end

mutual
  theorem Ty.rowsIn_true (t : Ty) : t.RowsIn (fun _ => True) := by
    cases t <;> simp only [Ty.RowsIn]
    all_goals first | trivial | exact Ty.rowsIn_true _ | exact Ty.rowsInList_true _ | skip
    case fn ns ps r e => exact ⟨Ty.rowsInList_true ps, Ty.rowsIn_true r, Eff.rowsIn_true e⟩
    case cont a b e => exact ⟨Ty.rowsIn_true a, Ty.rowsIn_true b, Eff.rowsIn_true e⟩
    case map a b => exact ⟨Ty.rowsIn_true a, Ty.rowsIn_true b⟩

  theorem Ty.rowsInList_true (ts : List Ty) : Ty.RowsInList (fun _ => True) ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.rowsIn_true t, Ty.rowsInList_true ts⟩

  theorem Eff.rowsIn_true (e : Eff) : Eff.RowsIn (fun _ => True) e := by
    cases e with
    | mk a fs => exact ⟨fun _ _ => trivial, Ty.rowsInList_true fs⟩
end

end Benitoite.Release
