import Benitoite.Release.Refinement.Surface.RangeAliases
import Benitoite.Release.Refinement.RangeFormation
import Benitoite.Release.Refinement.Surface.Property1Base

/-! # 開いた範囲文脈の具体化の補助

宣言した種類に適合する閉じた範囲列と、部分型・効果の被覆を具体化する補助を定める。
空の範囲列では元の判断を保ち、範囲列が空でなければ既存の範囲具体化の保存則を使う。
-/
namespace Benitoite.Release.Refinement.Surface.OpenBody
noncomputable section

/-- 宣言した種類に適合する、閉じた範囲の具体化。 -/
abbrev Instance (ks : List Scope.Domain.Kind) := {rs : List RangeExpr // RangesFit rs ks}

/-- 元の部分型判断の具体化と、反射・正規形の等号・推移による合成。 -/
inductive Le (P : Refinement.Program) (ks : List Scope.Domain.Kind) :
    (Instance ks → Ctx) → (Instance ks → List Pred) →
      (Instance ks → Ty) → (Instance ks → Ty) → Prop
  | refl {Γ Φ a} : Le P ks Γ Φ a a
  | source {Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) :
      Le P ks (fun σ => rangeCtx σ.val Γ) (fun _ => Φ)
        (fun σ => rangeTy σ.val a) (fun σ => rangeTy σ.val b)
  | convert {Γ Φ a b} : (∀ σ, (a σ).norm = (b σ).norm) → Le P ks Γ Φ a b
  | trans {Γ Φ a b c} : Le P ks Γ Φ a b → Le P ks Γ Φ b c → Le P ks Γ Φ a c

theorem Le.at {P ks Γ Φ a b} (h : Le P ks Γ Φ a b) (σ : Instance ks) :
    Ty.LeQ P (Γ σ) (Φ σ) (a σ) (b σ) := by
  induction h with
  | refl => exact .refl
  | source h =>
    cases hr : σ.val with
    | nil => simpa only [hr, rangeCtx, rangeTy] using h
    | cons r rs => simpa only [hr, rangeCtx, rangeTy] using h.instR (r :: rs)
  | convert he => exact .convert (he σ)
  | trans _ _ ih₁ ih₂ => exact .trans ih₁ ih₂

/-- 元の被覆判断の具体化と、反射・空の効果による被覆。 -/
inductive Covers (ks : List Scope.Domain.Kind) :
    (Instance ks → Ctx) → (Instance ks → List Pred) →
      (Instance ks → Eff) → (Instance ks → Eff) → Prop
  | refl {Γ Φ e} : Covers ks Γ Φ e e
  | empty {Γ Φ e} : Covers ks Γ Φ e (fun _ => Eff.empty)
  | source {Γ Φ e f} (h : Eff.Covers Γ Φ e f) :
      Covers ks (fun σ => rangeCtx σ.val Γ) (fun _ => Φ)
        (fun σ => rangeEff σ.val e) (fun σ => rangeEff σ.val f)

theorem Covers.at {ks Γ Φ e f} (h : Covers ks Γ Φ e f) (σ : Instance ks) :
    Eff.Covers (Γ σ) (Φ σ) (e σ) (f σ) := by
  cases h with
  | refl => exact Eff.Covers.refl _ _ _
  | empty => exact ⟨(fun _ h => by simp [Eff.empty, Eff.mem, Eff.test, Eff.atoms] at h),
      (fun _ h => by simp [Eff.empty, Eff.memFail, Eff.fails] at h)⟩
  | source h =>
    cases hr : σ.val with
    | nil => simpa only [hr, rangeEff, rangeCtx] using h
    | cons r rs => simpa only [hr, rangeEff, rangeCtx] using h.instR (rs := r :: rs)

end
end Benitoite.Release.Refinement.Surface.OpenBody
