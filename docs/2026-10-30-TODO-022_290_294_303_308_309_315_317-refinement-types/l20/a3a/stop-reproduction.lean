import Benitoite.Release.Refinement.TypeShiftExchange

namespace Benitoite.Release.Refinement.A3aStop
noncomputable section

private theorem result_declared {P B store Q C Γ Φ v a}
    (h : HasTypeVQ P B store Q C Γ Φ v a) (hΓ : (∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → Ty.Declared P C Γ a)) :
    Ty.Declared P C Γ a := by
  match h with
  | .V_Var hi _ => exact hΓ _ _ hi
  | .V_Const (c := c) _ => cases c <;> trivial
  | .V_DependentLam ha _ | .V_Closure ha _ _ => exact ha.declared
  | .V_Lam _ _ _ _ hd => exact hd
  | .V_List _ _ _ hd => exact hd
  | .V_Fun _ _ _ hi | .V_Prim _ _ _ _ hi | .V_Op _ _ _ hi => exact hi.result.declared
  | .V_ExternalRef _ _ _ hi => exact hi.result.declared
  | .V_ExternalHandle _ _ _ _ _ _ ha => exact ha.declared
  | .V_Map _ _ _ _ ha hb => exact ⟨ha.declared, hb.declared⟩
  | .V_Set _ _ ha => exact ha.declared
  | .V_Dict _ _ _ _ _ _ _ ha => exact ha.declared
  | .V_Con _ _ _ _ _ ha => exact ha.declared
  | .V_Super _ _ _ hd => exact hd
  | .V_Raise ha hot hoe hkind => exact ha.declared
  | .V_LocRef _ hd | .V_LocLazy _ hd => exact hd
  | .V_Bytes _ => trivial
  | .V_PathBases _ | .V_ScopePattern _ _ _ | .V_Checked _ _ _ |
      .V_CheckedRequest _ _ _ _ _ _ | .V_CheckedAt _ => trivial
  | .V_AtError hs => exact hs.errorType_declared
  | .V_Normal hv => exact (result_declared hv hΓ).norm
  | .V_Sub _ _ _ _ hd => exact hd
  | .V_Refine _ _ _ _ _ _ hda hdp => exact ⟨hda, hdp⟩

def caller : TypeCtx := [⟨{}, .constructor 0⟩]
def changed : TypeCtx := [TypeCtx.valueParam]
def input : Ty := .fn [] [] .bytes Eff.empty
def output : Ty := .fn [] [] .bytes (Eff.singleFail (.tapp 0 []))
def context : Ctx := [some input]

theorem output_annotation (P : Program) : Ty.Annotation P caller context output := by
  constructor
  · simp [output, caller, context, Ty.WF, Ty.WFList, Eff.WF, Eff.Canonical, Eff.singleFail,
      Ty.norm, Ty.normTys, Eff.norm, NamesWF]
  · simp [output, Ty.Sorted, sortedTys, sortedEff, Eff.singleFail, Ty.norm, Ty.normTys]
  · simp [output, caller, Ty.Declared, declaredTys, declaredEff, Eff.singleFail,
      Ty.norm, Ty.normTys, TypeCtx.kinds]

theorem source_typed (P : Program) (B : Builtins) :
    HasTypeVQ P B StoreTy.empty Qempty caller context [] (.var 0) output := by
  have ha := output_annotation P
  apply HasTypeVQ.V_Sub (a := input) (.V_Var rfl (by simp [input, Ordinary, Ty.core]))
    (.fn_effect ?_) ha.wf ha.sorted ha.declared
  constructor
  · intro a ha; simp [Eff.mem, Eff.empty, Eff.test, Eff.atoms] at ha
  · intro a ha; simp [Eff.memFail, Eff.empty, Eff.fails] at ha

theorem target_untyped (P : Program) (B : Builtins) :
    ¬ HasTypeVQ P B StoreTy.empty Qempty changed context [] (.var 0) output := by
  intro h
  have hd := result_declared h (by
    intro i a hi
    cases i with
    | zero => simp only [context, List.getElem?_cons_zero, Option.some.injEq] at hi
              cases hi; trivial
    | succ i => simp [context] at hi)
  simp [output, changed, TypeCtx.valueParam, TypeCtx.kinds, Ty.Declared,
    declaredTys, declaredEff, Eff.singleFail, Ty.norm, Ty.normTys] at hd

theorem map_identity : TypeCtxMap 0 0 context context := by
  constructor
  · rfl
  · intro i a hi
    simpa only [shiftTypes_zero] using hi

theorem length_equal : changed.length = caller.length + 0 := rfl

theorem head_mismatch :
    ¬ KindRenaming (TypeCtx.kinds caller) (TypeCtx.kinds changed) (shiftIndex 0 0) := by
  intro h
  have h0 := h 0 (.constructor 0) rfl
  simp [changed, TypeCtx.kinds, TypeCtx.valueParam, shiftIndex] at h0

/-- 公開補題の現行署名は、kind の異なる同長の文脈を許すため成立しない。 -/
theorem signature_false (P : Program) (B : Builtins) :
    ¬ (∀ {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Γ : Ctx}
      {Φ : List Pred} {i : Nat} {a : Ty},
      HasTypeVQ P B Ψ Q C Γ Φ (.var i) a →
      ∀ {Ψ' : StoreTy} {C' : TypeCtx} {Δ : Ctx} {k c : Nat},
      C'.length = C.length + k → TypeCtxMap k c Γ Δ →
      HasTypeVQ P B Ψ' Q C' Δ Φ (.var i) (shiftTypes k c a)) := by
  intro h
  have ht := h (source_typed P B) (Ψ' := StoreTy.empty) length_equal map_identity
  exact target_untyped P B (by simpa only [shiftTypes_zero] using ht)

end
end Benitoite.Release.Refinement.A3aStop

#print axioms Benitoite.Release.Refinement.A3aStop.source_typed
#print axioms Benitoite.Release.Refinement.A3aStop.target_untyped

#print axioms Benitoite.Release.Refinement.A3aStop.signature_false
