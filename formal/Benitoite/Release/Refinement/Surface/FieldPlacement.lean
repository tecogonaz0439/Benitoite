import Benitoite.Release.Refinement.Surface.Basic

/-! ソース順の値を宣言の位置へ並べる構文上の性質。値の型付けには依存しない。 -/
namespace Benitoite.Release.Refinement.Surface

/-- 位置が一意なら、検索は同じソース位置の値を返す。値の型には依存しない。 -/
theorem fieldAt_getElem {α : Type} {positions : List Nat} {vs : List α} {k : Nat}
    (hn : positions.Nodup) (hl : vs.length = positions.length) (hk : k < positions.length) :
    fieldAt positions[k] positions vs = some (vs[k]'(by omega)) := by
  induction positions generalizing vs k with
  | nil => simp at hk
  | cons j js ih =>
      cases vs with
      | nil => simp at hl
      | cons v vs =>
          obtain ⟨hj, hn⟩ := List.nodup_cons.mp hn
          cases k with
          | zero => simp [fieldAt]
          | succ k =>
              have hk' : k < js.length := by simpa using hk
              have he : js[k] ≠ j := by
                intro he
                exact hj (he ▸ List.getElem_mem hk')
              simpa only [List.getElem_cons_succ, fieldAt, ite_eq_right he] using
                ih hn (by simpa using hl) hk'

/-- 宣言位置への並べ替えは、元のソース位置の値そのものを保持する。 -/
theorem recordFields_getElem {α : Type} {n : Nat} {positions : List Nat} {vs : List α}
    (fallback : α) (hp : positions.Perm (List.range n)) (hl : vs.length = positions.length)
    {k : Nat} (hk : k < positions.length) :
    (recordFields n positions vs fallback)[positions[k]]? = some (vs[k]'(by omega)) := by
  have hi : positions[k] < n := List.mem_range.mp (hp.mem_iff.mp (List.getElem_mem hk))
  have hf := fieldAt_getElem (hp.nodup_iff.mpr List.nodup_range) hl hk
  simp [recordFields, hi, hf]


end Benitoite.Release.Refinement.Surface
