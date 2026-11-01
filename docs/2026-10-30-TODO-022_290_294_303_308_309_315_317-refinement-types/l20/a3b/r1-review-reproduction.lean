import Benitoite
open Benitoite.Release.Refinement
namespace RVA3bS02
noncomputable section

def A0 : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def ΨA : StoreTy := fun _ => some (.ref A0)

/-- `.loc` の型の正規形の芯は格納された型に固定される。 -/
def Fixed (a : Ty) : Prop := a.norm.core = (Ty.reference A0).norm

theorem foldFn_not_reference {t : Tel} {r : Ty} : (Ty.foldFn t).core ≠ .reference r := by
  intro h
  unfold Ty.foldFn at h
  split at h <;> simp [Ty.core] at h

theorem fixed_of_le {P Γ Φ a b} (h : Ty.LeQ P Γ Φ a b) (ha : Fixed a) : Fixed b := by
  match h with
  | .refl => exact ha
  | .convert he => simpa only [Fixed, he] using ha
  | .trans h g => exact fixed_of_le g (fixed_of_le h ha)
  | .fn_effect _ => simp [Fixed, Ty.norm, A0] at ha
  | .list _ => simp [Fixed, Ty.norm, A0] at ha
  | .lazy _ => simp [Fixed, Ty.norm, A0] at ha
  | .map_value _ _ => simp [Fixed, Ty.norm, A0] at ha
  | .forget => simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using ha
  | .introduce _ _ => simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using ha
  | .refine hb _ _ _ =>
    have := fixed_of_le hb (by simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using ha)
    simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using this
  | .dependentFn (t := t) _ =>
    exfalso
    simp only [Fixed, Ty.norm, A0] at ha
    exact foldFn_not_reference ha
  | .scoped _ => simp [Fixed, Ty.norm, A0] at ha
  | .scoped_forget => simp [Fixed, Ty.norm, A0] at ha
  | .data _ => simp [Fixed, Ty.norm, A0] at ha

theorem loc_fixed {P B Ψ Q C Γ Φ v a l} (hΨ : Ψ l = some (.ref A0))
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hv : v = .loc l) : Fixed a := by
  match h with
  | .V_LocRef hl _ =>
    cases hv
    have := Option.some.inj (hl.symm.trans hΨ)
    cases this
    rfl
  | .V_LocLazy hl _ =>
    cases hv
    cases Option.some.inj (hl.symm.trans hΨ)
  | .V_Sub hv' hle .. => exact fixed_of_le hle (loc_fixed hΨ hv' hv)
  | .V_Normal hv' =>
    have := loc_fixed hΨ hv' hv
    simpa only [Fixed, Ty.norm_idem] using this
  | .V_Refine hv' .. =>
    have := loc_fixed hΨ hv' hv
    simpa only [Fixed, Ty.norm, Ty.core_refineNorm] using this
  | .V_Var .. | .V_Const .. | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim ..
  | .V_Op .. | .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. | .V_Checked ..
  | .V_CheckedRequest .. | .V_CheckedAt .. | .V_AtError .. | .V_Map .. | .V_Set .. | .V_Dict ..
  | .V_Raise .. | .V_Bytes .. | .V_Con .. | .V_Super .. | .V_List .. => cases hv

def es0 : List Eff := [Eff.empty]

theorem source {P B Q} : HasTypeVQ P B ΨA Q [] [] [] (.loc 0) (.reference A0) :=
  .V_LocRef rfl (by simp [A0, Ty.Declared, declaredTys, declaredEff, Eff.row, Ty.Declared])

theorem target_type_not_fixed : ¬ Fixed ((Ty.reference A0).substAt 0 [] es0) := by
  intro h
  simp only [Fixed, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, A0, Ty.core,
    Ty.reference.injEq, Ty.fn.injEq] at h
  have := h.2.2.2
  have hm := congrArg (fun e => Eff.test e (.rho 0)) this
  simp [Eff.rawBind, Eff.norm, es0, typeEnvAt, Eff.test, Eff.row, Eff.empty, Eff.atoms, substAtoms, instAtoms] at hm

/-- 型像なし・行像 [empty] の結論は偽である。 -/
theorem S02_V_row_false {P B} :
    ¬ HasTypeVQ P B ΨA Benitoite.Release.Qempty [] (Ctx.bindTypes [] (typeEnvAt 0 [] es0)) []
      (Val.substTyAt 0 [] es0 (.loc 0)) ((Ty.reference A0).substAt 0 [] es0) := by
  intro h
  exact target_type_not_fixed (loc_fixed rfl h rfl)

/-- 入力の九欄は全て満たされる（F を除き P・B に依らない）。 -/
theorem input_ok {P B} : ClosedTypeSubstInput P B [] [] [] [] es0 := by
  refine ⟨rfl, by simp, ⟨rfl, by simp⟩, by simp [TypeAnnotations], ⟨rfl, by simp⟩, ?_, ?_, ?_, ?_⟩
  · intro e he; simp [es0] at he; subst he; simp [Eff.WF, Eff.empty, Ty.WFList]
  · intro e he; simp [es0] at he; subst he
    constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared, Ty.WFList, sortedTys, declaredTys, Eff.WF, Eff.empty, NamesWF, sortedEff, declaredEff, Eff.Canonical, Eff.norm]
  · intro e he; simp [es0] at he; subst he; simp [kindsEff, kindsList, Eff.empty]
  · exact ⟨fun i a hi => by simp at hi, fun i a hi => by simp at hi⟩

theorem row_transport : RowTransport Benitoite.Release.Qempty Benitoite.Release.Qempty es0 := by
  intro i hi; simp [Benitoite.Release.Qempty] at hi

theorem store_wf : StoreTy.WF ΨA := by
  intro l t ht
  cases Option.some.inj ht
  simp [LocTy.WF, A0, Ty.WF, Ty.WFList, Eff.WF, Eff.row, NamesWF, Eff.Canonical, Eff.norm]

/-- S02_V の字面を任意の F の下で否定する。 -/
theorem S02_V_refuted {P : Program} {B : Builtins}
    (hF : P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P)
    (S02_V : ∀ {P : Program} {B : Builtins} {Ψ : StoreTy} {Q Q' C0 C1 Γ Φ v a ts es},
      (P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ Ψ.WF) → (ClosedTypeSubstInput P B C0 C1 Γ ts es) → RowTransport Q Q' es →
      HasTypeVQ P B Ψ Q (C1 ++ C0) Γ Φ v a →
      HasTypeVQ P B Ψ Q' C1 ((fun (Δ : Ctx) => Δ.bindTypes (typeEnvAt C1.length ts es)) Γ) Φ ((Val.substTyAt C1.length ts es) v) ((Ty.substAt C1.length ts es) a)) :
    False :=
  S02_V_row_false (S02_V (P := P) (B := B) (Ψ := ΨA) (C0 := []) (C1 := []) (Γ := []) (Φ := [])
    (ts := []) (es := es0) ⟨hF.1, hF.2.1, hF.2.2, store_wf⟩ input_ok row_transport source)

end
end RVA3bS02

#print axioms RVA3bS02.S02_V_refuted

namespace RVA3bS02
open Benitoite.Release.Refinement

theorem new_guard_rejects_review :
    ¬ TypeSubstCode es0 (fun nr nt ne nv => (Val.loc 0).SourceScoped nr nt ne nv) := by
  rintro (h | ⟨nr, nt, ne, nv, h⟩)
  · cases h
  · exact h
#print axioms new_guard_rejects_review
end RVA3bS02
