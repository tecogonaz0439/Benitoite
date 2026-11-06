import Benitoite.Release.Refinement.Surface.CheckSoundSupport

/-! 呼出しの値の並べ替えと、部分適用で作る束縛型の有限支持。 -/
namespace Benitoite.Release.Refinement.Surface.Check
open CheckArguments

theorem value_support_member {s vs v} (hv : ValuesSupport s vs) (hm : v ∈ vs) : ValueSupport s v := by
  induction vs with
  | nil => cases hm
  | cons w ws ih =>
    rcases List.mem_cons.mp hm with rfl | hm
    · exact hv.1
    · exact ih hv.2 hm

private theorem values_support_members {s vs} (hv : ∀ v ∈ vs, ValueSupport s v) : ValuesSupport s vs := by
  induction vs with
  | nil => trivial
  | cons v vs ih => exact ⟨hv v (by simp), ih (fun w hw => hv w (by simp [hw]))⟩

private theorem fieldAt_support {s positions vs fallback} (hv : ValuesSupport s vs) (hf : ValueSupport s fallback)
    (i : Nat) : ValueSupport s ((fieldAt i positions vs).getD fallback) := by
  induction positions generalizing vs with
  | nil => exact hf
  | cons j js ih =>
    cases vs with
    | nil => exact hf
    | cons v vs =>
      simp only [fieldAt]
      split
      · exact hv.1
      · exact ih hv.2

/-- 未指定の欄の値も含めて、並べ替えは値に現れる型の有限支持を保つ。 -/
theorem recordFields_support {s n positions vs fallback} (hv : ValuesSupport s vs) (hf : ValueSupport s fallback) :
    ValuesSupport s (recordFields n positions vs fallback) := by
  apply values_support_members
  intro v hm
  obtain ⟨i, _, rfl⟩ := List.mem_map.mp hm
  exact fieldAt_support hv hf i

theorem holeTypes_support {q args} (h : HolesSupport q args) :
    Ty.SupportList (· ∈ q.formation.atoms) args.holeTypes := by
  cases args with
  | nil => trivial
  | expr label pos e rest => exact holeTypes_support (args := rest) h.2
  | hole label pos a rest => exact ⟨h.1, holeTypes_support (args := rest) h.2⟩

/-- 穴の値と固定の式の値は、どちらも局所の変数を指す。 -/
theorem argVals_support (s : List Atom) (args : HoleArgs) (n : Nat) :
    ValuesSupport s (args.argVals n) := by
  cases args with
  | nil => trivial
  | expr label pos e rest | hole label pos a rest => exact ⟨trivial, argVals_support s rest n⟩

theorem holeTel_support {s : List Atom} {ps r e} (hp : Ty.SupportList (· ∈ s) ps)
    (hr : r.Support (· ∈ s)) (he : e.Support (· ∈ s)) (ns : List String) (i : Nat) :
    (holeTel ns ps i r e).Support (· ∈ s) := by
  induction ns generalizing ps i with
  | nil => exact ⟨hr, he⟩
  | cons name ns ih =>
    cases ps with
    | nil => exact ⟨hr, he⟩
    | cons a ps => exact ⟨type_shift_support hp.1 i 0, ih hp.2 (i + 1)⟩

mutual
  theorem value_shift_support {s v} (h : ValueSupport s v) (k : Nat) :
      ValueSupport s (v.rename (· + k)) := by
    cases v <;> try trivial
    case list vs => exact values_shift_support h k
    case super v cl => exact value_shift_support (v := v) h k
    case dict i ts vs =>
      refine ⟨?_, values_shift_support h.2 k⟩
      apply Ty.SupportList.iff.mpr
      intro a ha
      obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
      have hi : shiftIndex k 0 = (· + k) := by funext j; simp [shiftIndex]
      rw [← hi, ← Ty.shiftV_eq_renameTy]
      exact type_shift_support (Ty.SupportList.iff.mp h.1 b hb) k 0
  termination_by sizeOf v
  decreasing_by all_goals subst_vars <;> simp_wf <;> omega

  theorem values_shift_support {s vs} (h : ValuesSupport s vs) (k : Nat) :
      ValuesSupport s (Val.renameList (· + k) vs) := by
    cases vs with
    | nil => trivial
    | cons v vs => exact ⟨value_shift_support (v := v) h.1 k, values_shift_support (vs := vs) h.2 k⟩
  termination_by sizeOf vs
  decreasing_by all_goals subst_vars <;> simp_wf <;> omega
end

end Benitoite.Release.Refinement.Surface.Check
