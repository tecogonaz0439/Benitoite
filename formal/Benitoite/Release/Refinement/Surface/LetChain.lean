import Benitoite.Release.Refinement.Surface.Rules
import Benitoite.Release.Refinement.ClosureTyping

/-!
# 脱糖の let の連なりの型付け

脱糖は部分式を元の文脈で脱糖してから、挿入する let の個数だけ自由変数を移す（設計書 01-12「表層からの脱糖」）。
元の文脈で型付けた計算の列を、前の束縛の型を加えた文脈へ移し、`C_Let` で順に束縛する。束縛の後の文脈は
`bindParams Γ (pre ++ as)` であり、計算の型は束縛の数だけ移した型で格納する。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

@[simp] theorem bindParams_nil (Γ : Ctx) : bindParams Γ [] = Γ := by
  simp only [bindParams, List.reverse_nil, List.map_nil, List.nil_append, List.length_nil]
  conv => rhs; rw [← List.map_id Γ]
  congr 1; funext x; cases x <;> simp [Ty.shiftV_zero]

/-- 最後の束縛は、前の束縛の数だけ移した型で文脈を延ばす。 -/
theorem bindParams_snoc (Γ : Ctx) (pre : List Ty) (a : Ty) :
    bindParams Γ (pre ++ [a]) = (bindParams Γ pre).extend (a.shiftV pre.length 0) := by
  simp only [bindParams, Ctx.extend, List.reverse_append, List.reverse_cons, List.reverse_nil,
    List.nil_append, List.singleton_append, List.map_cons, List.length_append, List.length_cons,
    List.length_nil, List.map_append, List.map_map, Function.comp_def, Option.map_map, Ty.shiftV_add]
  simp [Ty.shiftV_add]

theorem renameKind_shift_add (b : BuilderKind) (m : Nat) :
    renameKind (shiftIndex 1 0) (renameKind (shiftIndex m 0) b) = renameKind (shiftIndex (m + 1) 0) b := by
  cases b <;> simp only [renameKind_shift, Ty.shiftV_add]

/-- 局所の構築器の文脈を、外側に n 個の値の束縛を加えた文脈へ移す。 -/
theorem LocalCtx.Shift.outer (n : Nat) (L : LocalCtx) : LocalCtx.Shift n 0 L (localExtend n L) := by
  induction n with
  | zero =>
    intro i b hi
    have hb : renameKind (shiftIndex 0 0) b = b := by cases b <;> simp [renameKind_shift, Ty.shiftV_zero]
    simpa only [Refinement.localExtend, shiftIndex, Nat.not_lt_zero, ↓reduceIte, Nat.add_zero, hb] using hi
  | succ n ih =>
    intro i b hi
    have h := ih i b hi
    simp only [Refinement.localExtend, LocalCtx.extend, shiftIndex, Nat.not_lt_zero, ↓reduceIte] at h ⊢
    rw [show i + (n + 1) = (i + n) + 1 by omega, List.getElem?_cons_succ, List.getElem?_map, h]
    simp only [Option.map_some, renameKind_shift_add b n]

/-- 同じ元の文脈で型付けた計算の列。各計算は同じ効果で型付ける。 -/
inductive CompsTy (P : Refinement.Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx)
    (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (L : LocalCtx) : List Comp → List Ty → Eff → Prop
  | nil {ε} : CompsTy P B Ψ Q C Γ Φ R L [] [] ε
  | cons {m ms a as ε} : HasTypeCQ P B Ψ Q C Γ Φ R m a ε L → CompsTy P B Ψ Q C Γ Φ R L ms as ε →
      CompsTy P B Ψ Q C Γ Φ R L (m :: ms) (a :: as) ε

theorem CompsTy.length {P B Ψ Q C Γ Φ R L ms as ε} (h : CompsTy P B Ψ Q C Γ Φ R L ms as ε) :
    ms.length = as.length := by
  induction h with
  | nil => rfl
  | cons _ _ ih => simp [ih]

theorem CompsTy.append {P B Ψ Q C Γ Φ R L ms as ns bs ε} (h : CompsTy P B Ψ Q C Γ Φ R L ms as ε)
    (g : CompsTy P B Ψ Q C Γ Φ R L ns bs ε) : CompsTy P B Ψ Q C Γ Φ R L (ms ++ ns) (as ++ bs) ε := by
  induction h with
  | nil => exact g
  | cons hm _ ih => exact .cons hm (ih g)

/-- 元の文脈の計算を、前の束縛 pre を加えた文脈へ移す。 -/
theorem _root_.Benitoite.Release.Refinement.HasTypeCQ.under_params {Ψ Γ Φ R L m a ε} (h : HasTypeCQ P B Ψ Q C Γ Φ R m a ε L)
    (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) (pre : List Ty) :
    HasTypeCQ P B Ψ Q C (bindParams Γ pre) (liftMany pre.length Φ) (R.map (Ty.shiftV pre.length 0))
      (m.rename (· + pre.length)) (a.shiftV pre.length 0) (Eff.shiftV pre.length 0 ε)
      (localExtend pre.length L) := by
  have hh := h.shift_values hA hw (StoreTy.Extends.refl _) (FullShiftMap.outer Γ pre)
    (LocalCtx.Shift.outer pre.length L) (fun p hp => Entails.under_params (Entails.hyp
      (List.mem_append_right _ hp)) pre)
  simpa only [shiftIndex_add] using hh

/-- 計算の列を順に束縛する。本体は全ての束縛を加えた文脈で、束縛を含まない結果型と効果を移した形で型付ける。 -/
theorem letChain_typed {Ψ Γ Φ R L} (hA : Builtins.ValueAssumptions P B) (hw : Ψ.WF) :
    ∀ (ms : List Comp) (pre as : List Ty) (body : Comp) (b : Ty) (ε : Eff),
      CompsTy P B Ψ Q C Γ Φ R L ms as ε →
      HasTypeCQ P B Ψ Q C (bindParams Γ (pre ++ as)) (liftMany (pre.length + as.length) Φ)
        (R.map (Ty.shiftV (pre.length + as.length) 0)) body (b.shiftV (pre.length + as.length) 0)
        (Eff.shiftV (pre.length + as.length) 0 ε) (localExtend (pre.length + as.length) L) →
      Ty.Declared P C Γ b →
      HasTypeCQ P B Ψ Q C (bindParams Γ pre) (liftMany pre.length Φ) (R.map (Ty.shiftV pre.length 0))
        (letChain pre.length ms body) (b.shiftV pre.length 0) (Eff.shiftV pre.length 0 ε)
        (localExtend pre.length L)
  | [], pre, as, body, b, ε, h, hb, _ => by
    cases h
    simpa only [letChain, List.append_nil, List.length_nil, Nat.add_zero] using hb
  | m :: ms, pre, as, body, b, ε, h, hb, hd => by
    cases h with
    | cons hm hms =>
    rename_i a as'
    have hm' := hm.under_params hA hw pre
    have ih := letChain_typed hA hw ms (pre ++ [a]) as' body b ε hms
      (by simpa only [List.append_assoc, List.singleton_append, List.length_append, List.length_cons,
        List.length_nil, Nat.add_assoc, Nat.add_comm 1] using hb) hd
    simp only [letChain]
    refine .C_Let hm' ?_ ((FullShiftMap.outer Γ pre).values.declared hd)
    rw [bindParams_snoc] at ih
    simpa only [List.length_append, List.length_cons, List.length_nil, liftMany, Option.map_map,
      Function.comp_def, Ty.shiftV_add, Eff.shiftV_add, Refinement.localExtend, Nat.zero_add] using ih

end Benitoite.Release.Refinement.Surface
