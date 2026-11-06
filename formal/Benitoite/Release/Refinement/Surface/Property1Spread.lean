import Benitoite.Release.Refinement.Surface.Property1Die

/-!
# 性質1のリストの展開の補題

脱糖は前の要素・展開の式・後の要素を書いた順に束縛し、束縛した変数の列を三つに分けて連結の頭へ渡す
（設計書 01-12「リストの展開」）。空の側の連結は作らない。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

theorem boundVars_succ (n : Nat) : boundVars (n + 1) = .var n :: boundVars n := by
  simp [boundVars, List.range_succ]

/-- 先に束縛した m 個の変数は、後に束縛した c 個の下で c だけずれる。 -/
theorem boundVars_add (m c : Nat) :
    boundVars (m + c) = Val.renameList (· + c) (boundVars m) ++ boundVars c := by
  induction m with
  | zero => simp [boundVars, Val.renameList]
  | succ m ih =>
    rw [Nat.succ_add, boundVars_succ, boundVars_succ, ih]
    simp [Val.renameList, Val.rename, Nat.add_comm]

theorem CallHead.rename_compose (h : CallHead) (ξ ζ : Nat → Nat) :
    (h.rename ξ).rename ζ = h.rename (fun i => ζ (ξ i)) := by
  cases h <;> simp [CallHead.rename, Val.rename_compose, Val.renameList_compose, List.map_map, Function.comp_def,
    renameTy_comp, renameEff_comp]

theorem ShiftMap.comp {k j Γ Δ E} (h1 : ShiftMap k 0 Γ Δ) (h2 : ShiftMap j 0 Δ E) : ShiftMap (k + j) 0 Γ E := by
  refine ⟨by rw [h2.length, h1.length, Nat.add_assoc], fun i a hi ho => ?_⟩
  have h := h2.lookup _ _ (h1.lookup i a hi ho) ((Ty.ordinary_shiftV _ _ _).mpr ho)
  rw [Ty.shiftV_add] at h
  simpa only [shiftIndex_add, Nat.add_assoc] using h

theorem boundVars_length (n : Nat) : (boundVars n).length = n := by simp [boundVars]

theorem renameList_length (ξ : Nat → Nat) (vs : List Val) : (Val.renameList ξ vs).length = vs.length := by
  rw [Val.renameList_map, List.length_map]

/-- 束縛した変数の列を、前の b 個・展開の値・後の a 個に分ける。 -/
theorem spreadValues_boundVars (h : CallHead) (b a : Nat) :
    spreadValues h b (boundVars (b + (a + 1))) =
      spreadFinish h (Val.renameList (· + (a + 1)) (boundVars b)) (.var a) (boundVars a) := by
  have hl : (Val.renameList (· + (a + 1)) (boundVars b)).length = b := by
    rw [renameList_length, boundVars_length]
  rw [spreadValues, boundVars_add, boundVars_succ, List.drop_left' hl, List.take_left' hl]

/-- 連結の型付けから、連結の計算の核の型付けを作る。 -/
theorem SpreadTy.typed {D Γ f t ds k Γ' Φ' before s after b e h R L} (hs : SpreadTy D B C Γ t ds k Γ' Φ' before s after b e)
    (hh : CallHeadTy D B Q C Γ f t ds) (hd : directCallee f = some h) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ Γ') :
    HasTypeCQ P B StoreTy.empty Q C Γ' Φ' R (spreadFinish (h.rename (· + k)) before s after) b e L := by
  cases hs with
  | only hv hle hb =>
    have hb' := hb.sameTypes hR.types
    exact .C_Eff (.C_Return (.V_Sub (hv.core hR hA hm) (hle.sameTypes hR.types) hb'.wf hb'.sorted hb'.declared))
      (Eff.covers_empty _ _ _)
  | front hv hle hc hb => exact hh.glue hd hR hA hm hm hv hle hc hb
  | back hv hle hc hb => exact hh.glue hd hR hA hm hm hv hle hc hb
  | @middle y ys s x xs r1 e1 r2 e2 b e hv1 ho1 ha1 hc1 hv2 hle2 hc2 hb =>
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r1) := by
      simpa [bindParams_single] using ShiftMap.outer Γ' [r1]
    have hm2 := ShiftMap.comp hm hm1
    have hfirst := hh.glue (R := R) (L := L) hd hR hA hm hm hv1 .refl hc1 ha1
    have hb1 : Ty.Annotation D.core C (Γ'.extend r1) (b.shiftV 1 0) := by
      simpa [bindParams_single] using hb.under [r1]
    have hsecond := hh.glue (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) hd hR hA hm2 hm2 hv2 hle2 hc2 hb1
    have hcomp : (h.rename (· + k)).rename (· + 1) = h.rename (· + (k + 1)) := by
      rw [CallHead.rename_compose]; rfl
    simp only [spreadFinish]
    rw [hcomp]
    exact .C_Let hfirst hsecond (hb.sameTypes hR.types).declared

end Benitoite.Release.Refinement.Surface
