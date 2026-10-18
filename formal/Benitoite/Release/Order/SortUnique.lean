import Std

/-!
# 全順序による整列と重複除去

型内部の Fail 列の代表を一意にするための、型表現に依存しない補題である。
空列と単一要素の列は比較を評価しない（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release.Order

open Std

/-- 整列済みの列へ一要素を挿入し、比較が等しい要素をまとめる。 -/
def insertUnique (cmp : α → α → Ordering) (a : α) : List α → List α
  | [] => [a]
  | b :: bs => match cmp a b with
    | .lt => a :: b :: bs
    | .eq => b :: bs
    | .gt => b :: insertUnique cmp a bs

/-- 構造再帰による挿入ソート。比較の結果が eq の要素は一つだけ残す。 -/
def sortUnique (cmp : α → α → Ordering) : List α → List α
  | [] => []
  | a :: as => insertUnique cmp a (sortUnique cmp as)

/-- 空列では比較を評価しない。 -/
@[simp] theorem sortUnique_nil (cmp : α → α → Ordering) : sortUnique cmp [] = [] := rfl

/-- 単一要素の列でも、比較の計算可能性によらずカーネルで簡約できる。 -/
@[simp] theorem sortUnique_singleton (cmp : α → α → Ordering) (a : α) :
    sortUnique cmp [a] = [a] := rfl

/-- 比較を保つ写像は、一要素の挿入と可換である。 -/
theorem insertUnique_map {α : Type u} {β : Type v}
    (cmp : α → α → Ordering) (cmp' : β → β → Ordering) (f : α → β)
    (hf : ∀ a b, cmp' (f a) (f b) = cmp a b) (a : α) (as : List α) :
    insertUnique cmp' (f a) (as.map f) = (insertUnique cmp a as).map f := by
  induction as with
  | nil => rfl
  | cons b bs ih =>
    simp only [List.map_cons, insertUnique, hf]
    cases cmp a b <;> simp_all

/-- 比較を保つ写像は、整列・重複除去と可換である。 -/
theorem sortUnique_map {α : Type u} {β : Type v}
    (cmp : α → α → Ordering) (cmp' : β → β → Ordering) (f : α → β)
    (hf : ∀ a b, cmp' (f a) (f b) = cmp a b) (as : List α) :
    sortUnique cmp' (as.map f) = (sortUnique cmp as).map f := by
  induction as with
  | nil => rfl
  | cons a as ih =>
    simp only [List.map_cons, sortUnique, ih, insertUnique_map cmp cmp' f hf]

variable {α : Type u} {cmp : α → α → Ordering} [LawfulEqCmp cmp] [TransCmp cmp]

omit [TransCmp cmp] in
/-- 挿入は、既存の要素と挿入する要素をちょうど保つ。 -/
theorem mem_insertUnique {x a : α} {as : List α} :
    x ∈ insertUnique cmp a as ↔ x = a ∨ x ∈ as := by
  induction as with
  | nil => simp [insertUnique]
  | cons b bs ih =>
    cases h : cmp a b with
    | lt => simp [insertUnique, h]
    | eq =>
      have := LawfulEqCmp.eq_of_compare h
      subst b
      simp [insertUnique, h]
    | gt => simp [insertUnique, h, ih, or_left_comm]

omit [TransCmp cmp] in
/-- 整列と重複除去は所属を変えない。 -/
theorem mem_sortUnique {x : α} {as : List α} : x ∈ sortUnique cmp as ↔ x ∈ as := by
  induction as with
  | nil => rfl
  | cons a as ih => simp [sortUnique, mem_insertUnique, ih]

private theorem pairwise_insertUnique {a : α} {as : List α}
    (h : as.Pairwise (fun x y => cmp x y = .lt)) :
    (insertUnique cmp a as).Pairwise (fun x y => cmp x y = .lt) := by
  induction as with
  | nil => simp [insertUnique]
  | cons b bs ih =>
    obtain ⟨hb, hbs⟩ := List.pairwise_cons.mp h
    cases hab : cmp a b with
    | lt =>
      simp only [insertUnique, hab]
      apply List.pairwise_cons.mpr
      refine ⟨?_, h⟩
      intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hab
      · exact TransCmp.lt_trans hab (hb x hx)
    | eq => simpa [insertUnique, hab] using h
    | gt =>
      simp only [insertUnique, hab]
      apply List.pairwise_cons.mpr
      refine ⟨?_, ih hbs⟩
      intro x hx
      rcases mem_insertUnique.mp hx with rfl | hx
      · exact OrientedCmp.lt_of_gt hab
      · exact hb x hx

/-- 出力は狭義昇順であり、重複を持たない。 -/
theorem pairwise_sortUnique (as : List α) :
    (sortUnique cmp as).Pairwise (fun x y => cmp x y = .lt) := by
  induction as with
  | nil => exact .nil
  | cons a as ih => exact pairwise_insertUnique ih

/-- 狭義昇順の二列は、所属する要素が同じなら列として等しい。 -/
theorem eq_of_pairwise_mem {as bs : List α}
    (ha : as.Pairwise (fun x y => cmp x y = .lt))
    (hb : bs.Pairwise (fun x y => cmp x y = .lt))
    (hm : ∀ x, x ∈ as ↔ x ∈ bs) : as = bs := by
  classical
  induction as generalizing bs with
  | nil =>
    cases bs with
    | nil => rfl
    | cons b bs => have := (hm b).mpr (by simp); simp at this
  | cons a as ih =>
    cases bs with
    | nil => have := (hm a).mp (by simp); simp at this
    | cons b bs =>
      have hab : a = b := by
        by_cases hne : a = b
        · exact hne
        apply False.elim
        have ham : a ∈ bs := (List.mem_cons.mp ((hm a).mp (by simp))).resolve_left hne
        have hbm : b ∈ as := (List.mem_cons.mp ((hm b).mpr (by simp))).resolve_left (Ne.symm hne)
        exact OrientedCmp.not_lt_of_lt (List.rel_of_pairwise_cons ha hbm)
          (List.rel_of_pairwise_cons hb ham)
      subst b
      congr 1
      apply ih (List.pairwise_cons.mp ha).2 (List.pairwise_cons.mp hb).2
      intro x
      by_cases hx : x = a
      · subst x
        have hna : a ∉ as := fun h => by
          have := List.rel_of_pairwise_cons ha h
          simp [ReflCmp.compare_self] at this
        have hnb : a ∉ bs := fun h => by
          have := List.rel_of_pairwise_cons hb h
          simp [ReflCmp.compare_self] at this
        simp [hna, hnb]
      · simpa [hx] using hm x

/-- 既に狭義昇順の列は変わらない。 -/
theorem sortUnique_eq_self {as : List α}
    (h : as.Pairwise (fun x y => cmp x y = .lt)) : sortUnique cmp as = as :=
  eq_of_pairwise_mem (pairwise_sortUnique as) h (fun _ => mem_sortUnique)

/-- 出力の等号は、入力の集合としての一致と同値である。 -/
theorem sortUnique_eq_iff_mem {as bs : List α} :
    sortUnique cmp as = sortUnique cmp bs ↔ ∀ x, x ∈ as ↔ x ∈ bs := by
  constructor
  · intro h x
    rw [← mem_sortUnique (cmp := cmp), h, mem_sortUnique]
  · intro h
    exact eq_of_pairwise_mem (pairwise_sortUnique as) (pairwise_sortUnique bs)
      (fun x => by simpa only [mem_sortUnique] using h x)

/-- 整列・重複除去を繰り返しても出力は変わらない。 -/
theorem sortUnique_idem (as : List α) : sortUnique cmp (sortUnique cmp as) = sortUnique cmp as :=
  sortUnique_eq_iff_mem.mpr (fun _ => mem_sortUnique)

/-- 連結する前に各列を整列しても、最終の代表は変わらない。 -/
theorem sortUnique_append (as bs : List α) :
    sortUnique cmp (sortUnique cmp as ++ sortUnique cmp bs) = sortUnique cmp (as ++ bs) := by
  apply sortUnique_eq_iff_mem.mpr
  intro x
  simp only [List.mem_append, mem_sortUnique]

omit [TransCmp cmp] in
/-- 写像で順序が逆転したり像が重複したりしても、元の列の重複除去は最終結果を変えない。 -/
theorem sortUnique_map_sortUnique {β : Type v} {cmp' : β → β → Ordering}
    [LawfulEqCmp cmp'] [TransCmp cmp'] (f : α → β) (as : List α) :
    sortUnique cmp' ((sortUnique cmp as).map f) = sortUnique cmp' (as.map f) := by
  apply sortUnique_eq_iff_mem.mpr
  intro x
  simp only [List.mem_map, mem_sortUnique]

/-- 連結した列の正規形は、両側の正規形だけで決まる。 -/
theorem sortUnique_append_congr {as as' bs bs' : List α}
    (ha : sortUnique cmp as = sortUnique cmp as')
    (hb : sortUnique cmp bs = sortUnique cmp bs') :
    sortUnique cmp (as ++ bs) = sortUnique cmp (as' ++ bs') := by
  rw [← sortUnique_append as bs, ha, hb, sortUnique_append as' bs']

end Benitoite.Release.Order
