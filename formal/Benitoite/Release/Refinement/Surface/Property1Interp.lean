import Benitoite.Release.Refinement.Surface.Property1Spread

/-!
# 性質1の文字列補間の補題

脱糖は式を書いた順に束縛し、変換の結果を断片の順に束縛してから、部分を文字列の連結の組み込みの関数で左から結ぶ
（設計書 01-12「文字列補間」）。最後の連結だけを束縛しない。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

theorem string_annotation (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx) :
    Ty.Annotation P C Γ (.base .string) := ⟨trivial, trivial, trivial⟩

theorem addHead_apply (b : PrimName) (k : Nat) (ws : List Val) :
    ((CallHead.app (.prim b [] [] []) []).rename (· + k)).apply ws = .app (.prim b [] [] []) ws := by
  simp [CallHead.rename, CallHead.apply, Val.rename, Val.renameList]

theorem heads_rename (fs : Exprs) (k : Nat) :
    ((directHeads fs).map (CallHead.rename (· + k))).map (CallHead.rename (· + 1)) =
      (directHeads fs).map (CallHead.rename (· + (k + 1))) := by
  rw [List.map_map]
  congr 1
  funext h
  simp only [Function.comp_def, CallHead.rename_compose]
  rfl

theorem JoinTy.typed {D Γ0 tadd k Γ' Φ' depth left rest e b op R L} (h : JoinTy D B C Γ0 tadd k Γ' Φ' depth left rest e)
    (hop : op (.binary .add) (.base .string) = some (b, []))
    (hh : CallHeadTy D B Q C Γ0 (.primName b [] [] []) tadd []) (hR : D.Realizes P)
    (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ') :
    HasTypeCQ P B StoreTy.empty Q C Γ' Φ' R (joinStringFrom op depth left rest) (.base .string) e L := by
  induction h generalizing R L with
  | last hv hle hc =>
    have hg := hh.glue (R := R) (L := L) rfl hR hA hm hm hv hle hc (string_annotation _ _ _)
    simp only [List.map_nil] at hg; rw [addHead_apply] at hg
    simpa [joinStringFrom, hop] using hg
  | @step k Γ' Φ' depth left right x xs r e' e hv ho ha hc _ ih =>
    have hg := hh.glue (R := R) (L := L) rfl hR hA hm hm hv .refl hc ha
    simp only [List.map_nil] at hg; rw [addHead_apply] at hg
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r) := by
      simpa [bindParams_single] using ShiftMap.outer Γ' [r]
    have hrest := ih (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) (ShiftMap.comp hm hm1)
    rw [joinStringFrom, hop]
    exact .C_Let hg (by simpa [string_shiftV] using hrest) trivial

theorem JoinPartsTy.typed {D Γ0 op k Γ' Φ' acc e R L} (h : JoinPartsTy D B Q C Γ0 op k Γ' Φ' acc e)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ') :
    HasTypeCQ P B StoreTy.empty Q C Γ' Φ' R (joinStringParts op acc) (.base .string) e L := by
  cases h with
  | empty => exact .C_Eff (.C_Return (.V_Const trivial)) (Eff.covers_empty _ _ _)
  | single hv hle =>
    exact .C_Eff (.C_Return (.V_Sub (hv.core hR hA hm) (hle.sameTypes hR.types) trivial trivial trivial))
      (Eff.covers_empty _ _ _)
  | many hop hh hj => exact hj.typed hop hh hR hA hm

theorem InterpTy.typed {D Γ0 op k Γ' Φ' ps vs fs acc e R L} (h : InterpTy D B Q C Γ0 op k Γ' Φ' ps vs fs acc e)
    (hR : D.Realizes P) (hA : Builtins.ValueAssumptions P B) (hm : ShiftMap k 0 Γ0 Γ') :
    HasTypeCQ P B StoreTy.empty Q C Γ' Φ' R
      (interpolate op ps vs ((directHeads fs).map (CallHead.rename (· + k))) acc) (.base .string) e L := by
  induction h generalizing R L with
  | done hj => exact hj.typed hR hA hm
  | text _ ih => exact ih hm
  | stringExpr _ ih => exact ih hm
  | @converted k Γ' Φ' c ps v vs f fs acc t ds r e' e hh hv ho ha hc _ ih =>
    obtain ⟨hd, hdc⟩ := hh.direct
    have hg := hh.glue (R := R) (L := L) hdc hR hA hm hm hv .refl hc ha
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r) := by
      simpa [bindParams_single] using ShiftMap.outer Γ' [r]
    have hrest := ih (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) (ShiftMap.comp hm hm1)
    simp only [directHeads, hdc, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    exact .C_Let hg (by simpa [string_shiftV] using hrest) trivial
  | @formatted k Γ' Φ' c spec ps v vs f fs acc t ds r e' e hh hv ho ha hc _ ih =>
    obtain ⟨hd, hdc⟩ := hh.direct
    have hg := hh.glue (R := R) (L := L) hdc hR hA hm hm hv .refl hc ha
    have hm1 : ShiftMap 1 0 Γ' (Γ'.extend r) := by
      simpa [bindParams_single] using ShiftMap.outer Γ' [r]
    have hrest := ih (R := R.map (Ty.shiftV 1 0)) (L := localExtend 1 L) (ShiftMap.comp hm hm1)
    simp only [directHeads, hdc, Option.getD_some, List.map_cons, interpolate]
    rw [heads_rename]
    exact .C_Let hg (by simpa [string_shiftV] using hrest) trivial

end Benitoite.Release.Refinement.Surface
