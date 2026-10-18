import Benitoite.Release.Lemmas.Basic
import Benitoite.Release.WellFormed

/-!
R14 の接続で確認した障害の再現。正式モデルの共有型と型付けの規則を読む。
後半は Fail 列だけへの制限であり、並行する型・実行のモデルは定義しない。
formal/ を作業ディレクトリとして `lake env lean ../docs/.../l1b/regularity-obstruction.lean` で確認する。
-/

namespace Benitoite.Release.L1bc1Obstruction

private abbrev unitTy : Ty := .base .unit

/-- 現在の Ty.Le は空の潜在効果から任意の効果への拡大を許す。 -/
theorem le_any_effect (e : Eff) :
    Ty.Le (.fn [] [] unitTy Eff.empty) (.fn [] [] unitTy e) :=
  Or.inr ⟨[], [], unitTy, Eff.empty, e, rfl, rfl, Eff.empty_sub e⟩

/-- Ty.Le.wf の形の保存が成り立てば、埋め込んだ全効果を受け入れてしまう。 -/
theorem le_wf_requires_all_effects (WF : Ty → Prop)
    (hempty : WF (.fn [] [] unitTy Eff.empty))
    (hpres : ∀ a b, Ty.Le a b → WF a → WF b) :
    ∀ e, WF (.fn [] [] unitTy e) := by
  intro e
  exact hpres _ _ (le_any_effect e) hempty

/-- 純粋な定数を返すラムダにも、V_Lam と C_Sub で任意の潜在効果が付く。 -/
theorem lambda_any_effect (P : Program) (B : Builtins) (Ψ : StoreTy)
    (C : List TParam) (Γ : List (Option Ty)) (e : Eff) :
    HasTypeV P B Ψ C Γ (.lam [] [] (.ret (.const .unit))) (.fn [] [] unitTy e) := by
  apply HasTypeV.V_Lam (by simp [NamesWF])
  exact .C_Sub (.C_Return .V_Const) (Or.inl rfl) (Eff.empty_sub e)

/-- このラムダの項は、強化する型の注釈も行の引数も持たない。 -/
theorem lambda_scoped :
    Val.VarsIn 0 (fun _ => True) (.lam [] [] (.ret (.const .unit))) := by
  simp [Val.VarsIn, Comp.VarsIn, Ty.VarsInList, NamesWF]

-- R13 の正規形を Fail 列に限って確認する。全要素は基本型であり、内部の norm は恒等である。
private def CanonicalFails (fs : List Ty) : Prop := Order.sortUnique tyCompare fs = fs
private def FailsSub (fs gs : List Ty) : Prop := ∀ t, t ∈ fs → t ∈ gs

/-- 重複は意味上の包含では区別されないが、R13 の生の正規形では除かれる。 -/
theorem duplicate_normalizes :
    Order.sortUnique tyCompare [unitTy, unitTy] = [unitTy] := rfl

private theorem duplicate_not_canonical : ¬ CanonicalFails [unitTy, unitTy] := by
  intro h
  have hlen := congrArg List.length h
  change 1 = 2 at hlen
  omega

/-- 空からの包含では、潜在効果の正規形を保存できない。 -/
theorem canonical_not_preserved_forward :
    ¬ (∀ fs gs, FailsSub fs gs → CanonicalFails fs → CanonicalFails gs) := by
  intro h
  apply duplicate_not_canonical
  exact h [] [unitTy, unitTy] (by simp [FailsSub]) rfl

/-- 逆向きでも、重複した列と一要素列は意味上同じなので保存できない。 -/
theorem canonical_not_preserved_backward :
    ¬ (∀ fs gs, FailsSub fs gs → CanonicalFails gs → CanonicalFails fs) := by
  intro h
  apply duplicate_not_canonical
  exact h [unitTy, unitTy] [unitTy] (by simp [FailsSub]) rfl

end Benitoite.Release.L1bc1Obstruction
