import Benitoite.Release.Refinement.RangeExchange
import Benitoite.Release.Refinement.NormalWellFormed

namespace Benitoite.Release.Refinement

/-- 正規化後の型は正規形である。WFは固定点の仮定ではない。 -/
theorem Ty.normal_norm (a : Ty) : a.norm.Normal := Ty.norm_idem a

theorem Tel.normal_norm (t : Tel) : (Tel.norm t).Normal := Tel.norm_idem t

private theorem predBind_fixed {nv p} (h : Pred.WF nv p) (σ : ObservationEnv)
    (hf : ∀ i, i<nv → σ i = some (.var i)) : predBind σ p = p :=
  (Pred.bind_congr (Pred.varsIn_mono h hf)).trans (predBind_id p)

private theorem upValues_fixed {nv} {σ : ObservationEnv}
    (hf : ∀ i, i < nv → σ i = some (.var i)) :
    ∀ i, i < nv+1 → upValues σ i = some (.var i) := by
  intro i hi
  cases i with
  | zero => rfl
  | succ i => simp [upValues, hf i (by omega)]

mutual
  theorem Ty.rawSubstV_fixed {nr nt nv a} (h : Ty.WF nr nt nv a) (σ : ObservationEnv)
      (hf : ∀ i, i < nv → σ i = some (.var i)) : a.rawSubstV σ = a := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.rawSubstV]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.rawSubstV_fixed h σ hf)
      | exact congrArg _ (substVTys_fixed h σ hf)
      | exact congrArg _ (Tel.rawSubstV_fixed h σ hf)
      | skip
    case fn ns ps r e => rw [substVTys_fixed h.2.1 σ hf,
      Ty.rawSubstV_fixed h.2.2.1 σ hf, Eff.rawSubstV_fixed h.2.2.2.1 σ hf]
    case cont b t e => rw [Ty.rawSubstV_fixed h.1 σ hf,
      Ty.rawSubstV_fixed h.2.1 σ hf, Eff.rawSubstV_fixed h.2.2.1 σ hf]
    case map a b => rw [Ty.rawSubstV_fixed h.1 σ hf, Ty.rawSubstV_fixed h.2 σ hf]
    case tapp i as => rw [substVTys_fixed h.2 σ hf]
    case refined a p => rw [Ty.rawSubstV_fixed h.1 σ hf, predBind_fixed h.2.1 _ (upValues_fixed hf)]
  theorem Tel.rawSubstV_fixed {nr nt nv t} (h : Tel.WF nr nt nv t) (σ : ObservationEnv)
      (hf : ∀ i, i < nv → σ i = some (.var i)) : Tel.rawSubstV σ t = t := by
    cases t with
    | done r e => simp only [Tel.rawSubstV]; rw [Ty.rawSubstV_fixed h.1 σ hf, Eff.rawSubstV_fixed h.2.1 σ hf]
    | param n a t => simp only [Tel.rawSubstV]; rw [Ty.rawSubstV_fixed h.1 σ hf, Tel.rawSubstV_fixed h.2 _ (upValues_fixed hf)]
  theorem substVTys_fixed {nr nt nv as} (h : Ty.WFList nr nt nv as) (σ : ObservationEnv)
      (hf : ∀ i, i < nv → σ i = some (.var i)) : substVTys σ as = as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [substVTys, Ty.rawSubstV_fixed h.1 σ hf, substVTys_fixed h.2 σ hf]
  theorem Eff.rawSubstV_fixed {nr nt nv e} (h : Eff.WF nr nt nv e) (σ : ObservationEnv)
      (hf : ∀ i, i < nv → σ i = some (.var i)) : Eff.rawSubstV σ e = e := by
    cases e; simp only [Eff.rawSubstV, substVTys_fixed h σ hf]
end

theorem Ty.rawSubstV_of_wf_zero {nr nt a} (h : Ty.WF nr nt 0 a) (σ : ObservationEnv) :
    a.rawSubstV σ = a := Ty.rawSubstV_fixed h σ (by intro i hi; omega)
theorem Tel.rawSubstV_of_wf_zero {nr nt t} (h : Tel.WF nr nt 0 t) (σ : ObservationEnv) :
    Tel.rawSubstV σ t = t := Tel.rawSubstV_fixed h σ (by intro i hi; omega)
theorem substVTys_of_wf_zero {nr nt as} (h : Ty.WFList nr nt 0 as) (σ : ObservationEnv) :
    substVTys σ as = as := substVTys_fixed h σ (by intro i hi; omega)
theorem Eff.rawSubstV_of_wf_zero {nr nt e} (h : Eff.WF nr nt 0 e) (σ : ObservationEnv) :
    Eff.rawSubstV σ e = e := Eff.rawSubstV_fixed h σ (by intro i hi; omega)


@[simp] theorem Ty.notContCore_rawSubstV (a : Ty) (σ : ObservationEnv) :
    (a.rawSubstV σ).NotContCore ↔ a.NotContCore := by
  cases a <;> simp [Ty.rawSubstV, Ty.NotContCore, Ty.core]
  case refined a p => exact Ty.notContCore_rawSubstV a σ

  @[simp] theorem Ty.hasSort_rawSubstV (a : Ty) (σ : ObservationEnv) (sort : «Sort») :
      (a.rawSubstV σ).HasSort sort ↔ a.HasSort sort := by
    cases a <;> simp only [Ty.rawSubstV, Ty.HasSort, Ty.sort?]
    case refined a p => exact Ty.hasSort_rawSubstV a σ sort

@[simp] theorem Ty.integerCarrier_rawSubstV (a : Ty) (σ : ObservationEnv) :
    (a.rawSubstV σ).IntegerCarrier ↔ a.IntegerCarrier := Ty.hasSort_rawSubstV a σ .integer

@[simp] theorem Ty.ordinary_rawSubstV (a : Ty) (σ : ObservationEnv) :
    Ordinary (a.rawSubstV σ) ↔ Ordinary a := by
  cases a <;> simp [Ty.rawSubstV, Ordinary]
  case refined a p => exact Ty.ordinary_rawSubstV a σ


end Benitoite.Release.Refinement
