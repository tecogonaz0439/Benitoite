import Benitoite.Release.Refinement.Surface.Property1Calls

/-!
# 性質1の分岐と束縛の補題

条件の値を一つ束縛した文脈で枝を型付ける（設計書 01-12「リスト、ラムダ、条件分岐、match」）。表層の枝は元の文脈で
型付け、脱糖は枝の自由変数を一つ移す。枝の事実の列は、束縛した条件の値の真偽から導ける。
-/

namespace Benitoite.Release.Refinement.Surface

variable {P : Refinement.Program} {B : Builtins} {Q : NoFailCtx} {C : TypeCtx}

/-- 元の文脈の計算を、一つ束縛を加えた文脈へ移す。事実は束縛の下で導ける。 -/
theorem shift_one {Γ Φ Φ' R L m b ε a} (hA : Builtins.ValueAssumptions P B)
    (h : HasTypeCQ P B StoreTy.empty Q C Γ Φ R m b ε L)
    (hf : ∀ q ∈ Φ, Entails ((Γ.extend a).facts ++ Φ') (q.shiftV 1 0)) :
    HasTypeCQ P B StoreTy.empty Q C (Γ.extend a) Φ' (R.map (Ty.shiftV 1 0)) (m.rename (· + 1))
      (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L) := by
  have hm : FullShiftMap 1 0 Γ (Γ.extend a) := by simpa only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add] using FullShiftMap.outer Γ [a]
  have hh := h.shift_values hA storeEmpty_wf (StoreTy.Extends.refl _) hm (LocalCtx.Shift.outer 1 L) hf
  simpa only [shiftIndex_add] using hh

/-- 同じ事実の列は、一つ束縛を加えた文脈でも導ける。 -/
theorem facts_lift (Γ : Ctx) (Φ : List Pred) (a : Ty) (Ξ : List Pred) :
    ∀ q ∈ Φ, Entails ((Γ.extend a).facts ++ Ξ ++ Φ.map Pred.lift) (q.shiftV 1 0) := by
  intro q hq
  have h := Entails.under_params (Γ := Γ) (Φ := Φ) (Entails.hyp (List.mem_append_right _ hq)) [a]
  simp only [bindParams_single, List.length_cons, List.length_nil, Nat.zero_add, liftMany_one] at h
  apply h.weaken
  intro r hr
  rcases List.mem_append.mp hr with hr | hr
  · exact List.mem_append_left _ (List.mem_append_left _ hr)
  · exact List.mem_append_right _ hr

/-- 条件の計算を束縛し、その値で分岐する。枝は条件の値を束縛した文脈で型付ける。 -/
theorem ite_typed {Γ Φ R L m yes no a b ε} (hm : HasTypeCQ P B StoreTy.empty Q C Γ Φ R m a ε L)
    (ho : Ordinary a) (hle : Ty.LeQ P (Γ.extend a) (Φ.map Pred.lift) (a.shiftV 1 0) (.base .boolean))
    (hy : HasTypeCQ P B StoreTy.empty Q C (Γ.extend a) (boolCond (.var 0) true :: Φ.map Pred.lift)
      (R.map (Ty.shiftV 1 0)) yes (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L))
    (hn : HasTypeCQ P B StoreTy.empty Q C (Γ.extend a) (boolCond (.var 0) false :: Φ.map Pred.lift)
      (R.map (Ty.shiftV 1 0)) no (b.shiftV 1 0) (Eff.shiftV 1 0 ε) (localExtend 1 L))
    (hb : Ty.Declared P C Γ b) :
    HasTypeCQ P B StoreTy.empty Q C Γ Φ R (.letIn m (.ite (.var 0) yes no)) b ε L := by
  have hv : HasTypeVQ P B StoreTy.empty Q C (Γ.extend a) (Φ.map Pred.lift) (.var 0) (a.shiftV 1 0) :=
    .V_Var (by simp [Ctx.extend]) ((Ty.ordinary_shiftV _ _ _).mpr ho)
  have hbool : HasTypeVQ P B StoreTy.empty Q C (Γ.extend a) (Φ.map Pred.lift) (.var 0) (.base .boolean) :=
    .V_Sub hv hle trivial trivial trivial
  exact .C_Let hm (.C_If hbool rfl hy hn) hb

/-- 外側の文脈の通常の値を、継続を隠してから引数を束縛した文脈で読む。 -/
theorem ShiftMap.hideOuter (Γ : Ctx) (ps : List Ty) : ShiftMap ps.length 0 Γ (bindParams (hideConts Γ) ps) := by
  have h := ShiftMap.outer (hideConts Γ) ps
  refine ⟨by simpa [hideConts] using h.length, fun i a hi ho => h.lookup i a ?_ ho⟩
  exact hideConts_lookup.mpr ⟨hi, ho⟩

end Benitoite.Release.Refinement.Surface
