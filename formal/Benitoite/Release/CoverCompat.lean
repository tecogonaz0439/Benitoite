import Benitoite.Release.EffectCover

/-!
# 被覆による効果の包含の旧の像での同値（L40.6c）

L40.6c は、型付けの C-Sub・C-Eff と関数の型の効果の包含（`Ty.Le`）、継続の型付けの K-Handle の
「節の効果 εc は枠の下の継続の効果 ε に含まれる」と K-Handle-Fail の同じ前提を、構造上の包含 `Eff.Sub` から
判断 5 の一原子の被覆 `Eff.Covers` に替えた。どれも規則の前提の一つの関係だけを替えたので、旧の像（内側の効果の
原子がすべて Top の像。`Eff.TopAtoms`）での同値は、前提の水準の次の補題で示す。

- 効果の前提（C-Sub・C-Eff・K-Handle・K-Handle-Fail）: 内側が旧の効果なら、被覆は構造上の包含と同じである
  （`Eff.covers_iff_sub_of_topAtoms`。L10.5）。構造上の包含はいつでも被覆を与える（`Eff.Sub.covers`）ので、旧の規則で
  型付く導出は新しい規則でも型付く。
- 型の包含: 旧の型の包含 `Ty.LeOld` は新しい `Ty.Le` を与え（`Ty.LeOld.le`）、関数の型の潜在効果が旧の効果なら
  両者は同値である（`Ty.le_iff_leOld`）。

型付けの関係全体の同値（旧の規則の写しの帰納型との同値）は置かない（RV-L40 軽10 と同じく、規則の前提の水準の補題に
とどめる）。
-/

namespace Benitoite.Release

/-- L40.6c の前の型の包含。関数の型の効果は構造上の包含で広げる。旧の像での同値の比較に使う。 -/
def Ty.LeOld (a a' : Ty) : Prop :=
  a = a' ∨ ∃ names ps r ε ε', a = .fn names ps r ε ∧ a' = .fn names ps r ε' ∧ Eff.Sub ε ε'

/-- 関数の型の潜在効果が旧の効果（原子がすべて Top の像）である。関数の型でない型は条件を持たない。 -/
def Ty.LatentTopAtoms : Ty → Prop
  | .fn _ _ _ ε => Eff.TopAtoms ε
  | _ => True

/-- 旧の型の包含は新しい型の包含である。 -/
theorem Ty.LeOld.le {a a' : Ty} (h : Ty.LeOld a a') : Ty.Le a a' := by
  rcases h with rfl | ⟨names, ps, r, ε, ε', rfl, rfl, hs⟩
  · exact Or.inl rfl
  · exact Or.inr ⟨names, ps, r, ε, ε', rfl, rfl, hs.covers⟩

/-- 旧の像での同値: 関数の型の潜在効果が旧の効果なら、新しい型の包含は旧の型の包含と同値である。 -/
theorem Ty.le_iff_leOld {a a' : Ty} (h : a.LatentTopAtoms) : Ty.Le a a' ↔ Ty.LeOld a a' := by
  constructor
  · rintro (rfl | ⟨names, ps, r, ε, ε', rfl, rfl, hs⟩)
    · exact Or.inl rfl
    · have h' : Eff.TopAtoms ε := h
      exact Or.inr ⟨names, ps, r, ε, ε', rfl, rfl, (Eff.covers_iff_sub_of_topAtoms h').mp hs⟩
  · exact Ty.LeOld.le

/-- 旧の像での同値（効果の前提）: C-Sub・C-Eff の前提 `Eff.Covers ε' ε` と K-Handle・K-Handle-Fail の前提は、内側の
効果が旧の効果なら、旧の前提 `Eff.Sub ε ε'` と同値である。 -/
theorem Eff.covers_iff_sub_old {ε ε' : Eff} (h : ε.TopAtoms) : ε'.Covers ε ↔ Eff.Sub ε ε' :=
  Eff.covers_iff_sub_of_topAtoms h

end Benitoite.Release
