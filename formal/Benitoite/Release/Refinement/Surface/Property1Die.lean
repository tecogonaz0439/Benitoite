import Benitoite.Release.Refinement.Surface.Property1Match
import Benitoite.Release.Refinement.LocalTyping

/-!
# 性質1の die の補題

or die の失敗側は、照合の束縛の下で説明・原因を順に束縛し、終了の組み込みの関数を呼ぶ（設計書 01-12「die のモデル」）。
説明は継続を隠した元の文脈で戻り値型を持たずに型付け、脱糖は失敗側の束縛の数だけ自由変数を移す。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

/-- 継続を隠した元の文脈の値は、移した先の文脈で同じ型を持つ。隠した文脈には継続がない。 -/
theorem ShiftMap.fromHidden {k c Γ Δ} (h : ShiftMap k c Γ Δ) : FullShiftMap k c (hideConts Γ) Δ :=
  ⟨by simpa [hideConts] using h.length, fun i a hi =>
    h.lookup i a (hideConts_lookup.mp hi).1 (hideConts_lookup.mp hi).2⟩

theorem bindParams_three (Γ : Ctx) (x y z : Ty) :
    bindParams Γ [x, y, z] = ((Γ.extend x).extend (y.shiftV 1 0)).extend (z.shiftV 2 0) := by
  have h := bindParams_snoc Γ [x, y] z
  simpa [bindParams_two] using h

theorem bindParams_four (Γ : Ctx) (x y z w : Ty) :
    bindParams Γ [x, y, z, w] =
      (((Γ.extend x).extend (y.shiftV 1 0)).extend (z.shiftV 2 0)).extend (w.shiftV 3 0) := by
  have h := bindParams_snoc Γ [x, y, z] w
  simpa [bindParams_three] using h

theorem string_shiftV (k c : Nat) : Ty.shiftV k c (.base .string) = .base .string := by simp [Ty.shiftV]

/-- 説明の計算を、失敗側の k 個の束縛の下へ移す。説明は純粋で戻り値型を使わないので、任意の効果と戻り値型で読める。 -/
theorem message_shift {Γ Γ' Φ Φ' L m k} (hA : Builtins.ValueAssumptions P B)
    (h : HasTypeCQ P B StoreTy.empty Q C (hideConts Γ) Φ none m (.base .string) Eff.empty L)
    (hm : ShiftMap k 0 Γ Γ') (hf : ∀ q ∈ Φ, Entails (Γ'.facts ++ Φ') (q.shiftV k 0)) (R' : Option Ty) (ε' : Eff) :
    HasTypeCQ P B StoreTy.empty Q C Γ' Φ' R' (m.rename (· + k)) (.base .string) ε' (localExtend k L) := by
  have hh := h.shift_values hA storeEmpty_wf (StoreTy.Extends.refl _) (ShiftMap.fromHidden hm) (LocalCtx.Shift.outer k L) hf
  simp only [shiftIndex_add, string_shiftV] at hh
  have he : Eff.shiftV k 0 Eff.empty = Eff.empty := by simp [Eff.shiftV, Eff.empty]
  rw [he] at hh
  exact .C_Eff (HasTypeCQ.withReturn hh rfl rfl R') (Eff.covers_empty _ _ _)

/-- 外側の事実の列は、外側の文脈を引数で延ばした文脈で導ける。 -/
theorem facts_under (Γ : Ctx) (Φ : List Pred) (as : List Ty) :
    ∀ q ∈ Φ, Entails ((bindParams Γ as).facts ++ liftMany as.length Φ) (q.shiftV as.length 0) := by
  intro q hq
  exact Entails.under_params (Γ := Γ) (Φ := Φ) (Entails.hyp (List.mem_append_right _ hq)) as

end Benitoite.Release.Refinement.Surface
