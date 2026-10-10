import Benitoite.Surface.Lemmas.Extensions

/-! リストの展開と文字列補間の、型変数・エフェクト変数の範囲保存。 -/
namespace Benitoite.Surface
open Benitoite.Release

theorem Val.VarsInList.takeDrop {nt pe vs} (hv : Val.VarsInList nt pe vs) (n : Nat) :
    Val.VarsInList nt pe (vs.take n) ∧ Val.VarsInList nt pe (vs.drop n) := by
  induction n generalizing vs with
  | zero => exact ⟨trivial, hv⟩
  | succ n ih =>
      cases vs with
      | nil => exact ⟨trivial, trivial⟩
      | cons v vs => exact ⟨⟨hv.1, (ih hv.2).1⟩, (ih hv.2).2⟩

theorem spreadFinish_scoped {nt pe h before s after}
    (hh : h.Scoped nt pe) (hb : Val.VarsInList nt pe before)
    (hs : Val.VarsIn nt pe s) (ha : Val.VarsInList nt pe after) :
    Comp.VarsIn nt pe (spreadFinish h before s after) := by
  cases before <;> cases after <;> simp only [spreadFinish]
  · exact hs
  · exact hh.apply ⟨hs, ha, trivial⟩
  · exact hh.apply ⟨hb, hs, trivial⟩
  · exact ⟨hh.apply ⟨hb, hs, trivial⟩,
      (hh.rename _).apply ⟨trivial, Val.VarsInList.renameScoped _ _ ha, trivial⟩⟩

theorem spreadValues_scoped {nt pe h n vs} (hh : h.Scoped nt pe)
    (hv : Val.VarsInList nt pe vs) : Comp.VarsIn nt pe (spreadValues h n vs) := by
  obtain ⟨hb, hs⟩ := Val.VarsInList.takeDrop hv n
  unfold spreadValues
  cases he : vs.drop n with
  | nil => trivial
  | cons s after =>
      rw [he] at hs
      exact spreadFinish_scoped hh hb hs.1 hs.2

theorem heads_scoped_rename {nt pe} {hs : List CallHead} (hh : ∀ h ∈ hs, h.Scoped nt pe) (ξ : Nat → Nat) :
    ∀ h ∈ hs.map (CallHead.rename ξ), h.Scoped nt pe := by
  intro h hm
  obtain ⟨h', hm', rfl⟩ := List.mem_map.mp hm
  exact (hh h' hm').rename ξ

theorem joinStringFrom_scoped {nt pe op depth left rest}
    (hl : Val.VarsIn nt pe left) (hr : Val.VarsInList nt pe rest)
    (ha : rest ≠ [] → ∃ b, op (.binary .add) (.base .string) = some (b, [])) :
    Comp.VarsIn nt pe (joinStringFrom op depth left rest) := by
  induction rest generalizing left depth with
  | nil => exact hl
  | cons w rest ih =>
      obtain ⟨b, hop⟩ := ha (by simp)
      have hc : Comp.VarsIn nt pe (.app (.prim b [] []) [left, w.rename (· + depth)]) :=
        ⟨⟨trivial, trivial⟩, hl, Val.VarsIn.renameScoped _ _ hr.1, trivial⟩
      cases rest with
      | nil => simpa only [joinStringFrom, hop] using hc
      | cons v rest =>
          simp only [joinStringFrom, hop, Comp.VarsIn]
          exact ⟨hc, by simpa only [joinStringFrom, hop] using
            (ih (depth := depth + 1) (left := .var 0) trivial hr.2 (fun _ => ⟨b, hop⟩))⟩

theorem joinStringParts_scoped {nt pe op vs}
    (hv : Val.VarsInList nt pe vs)
    (ha : 2 ≤ vs.length → ∃ b, op (.binary .add) (.base .string) = some (b, [])) :
    Comp.VarsIn nt pe (joinStringParts op vs) := by
  cases vs with
  | nil => trivial
  | cons v vs =>
      apply joinStringFrom_scoped hv.1 hv.2
      intro hn; apply ha
      have := List.length_pos_iff.mpr hn
      simp only [List.length_cons]; omega

theorem interpolate_scoped {nt pe op parts vs hs acc}
    (hv : Val.VarsInList nt pe vs) (hh : ∀ h ∈ hs, h.Scoped nt pe)
    (hc : Val.VarsInList nt pe acc)
    (ha : 2 ≤ acc.length + InterpPart.count parts →
      ∃ b, op (.binary .add) (.base .string) = some (b, [])) :
    Comp.VarsIn nt pe (interpolate op parts vs hs acc) := by
  induction parts generalizing vs hs acc with
  | nil => exact joinStringParts_scoped hc (by simpa [InterpPart.count] using ha)
  | cons p ps ih =>
      cases p with
      | text s =>
          simp only [interpolate]
          split
          · rename_i he; exact ih hv hh hc (by simpa [InterpPart.count, he] using ha)
          · rename_i he
            exact ih hv hh (Val.VarsInList.append hc ⟨trivial, trivial⟩)
              (by simpa [InterpPart.count, he, List.length_append, Nat.add_assoc] using ha)
      | stringExpr =>
          cases vs with
          | nil => trivial
          | cons v vs =>
              exact ih hv.2 hh (Val.VarsInList.append hc ⟨hv.1, trivial⟩)
                (by simpa [InterpPart.count, List.length_append, Nat.add_assoc] using ha)
      | converted t =>
          cases vs with
          | nil => trivial
          | cons v vs =>
              cases hs with
              | nil => trivial
              | cons h hs =>
                  exact ⟨(hh h (by simp)).apply ⟨hv.1, trivial⟩,
                    ih (Val.VarsInList.renameScoped _ _ hv.2)
                      (heads_scoped_rename (fun h hm => hh h (by simp [hm])) _)
                      (Val.VarsInList.append (Val.VarsInList.renameScoped _ _ hc) ⟨trivial, trivial⟩)
                      (by simpa [InterpPart.count, List.length_append, Val.renameList_length,
                        Nat.add_assoc] using ha)⟩

end Benitoite.Surface
