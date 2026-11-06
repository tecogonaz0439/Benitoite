import Benitoite.Release.Refinement.Surface.CheckSoundSupport
import Benitoite.Release.Refinement.Surface.CheckOpenSoundBase

/-! 型の検査の各規則で共通に使う、有限照合の健全性。 -/
namespace Benitoite.Release.Refinement.Surface.CheckOpen
open Check CheckArguments
open Check
open CheckCompare CheckFormation CheckOpenArguments

theorem head_sound {q rows C Γ path source h i t ds} (hq : OpenSound q)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hi : HeadInputsSupport q.formation q.B source) (hh : h.Support q.formation.atoms)
    (hc : head q rows C Γ path source h i = some (t, ds)) :
    OpenSurface.CallHeadTy q.D q.B q.formation.rangeKinds (CheckAdmissible.NoFailCtxOf rows) C Γ source t ds ∧
      t.Support (· ∈ q.formation.atoms) ∧ ds = headDictionaries source := by
  exact ⟨CheckOpenArguments.head_sound hq.formation hq.tables hq.sat hq.admits hq.ranges hΓ hi (hh.head i) hc,
    CheckOpenArguments.head_result_support hq.tables hi (hh.head i) hc⟩

theorem valsTel_sound {q C Γ0 k Γ Φ path vs t r e h i} (hq : OpenSound q)
    (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hv : ValuesSupport q.formation.atoms vs) (ht : t.Support (· ∈ q.formation.atoms))
    (hr : r.Support (· ∈ q.formation.atoms)) (he : e.Support (· ∈ q.formation.atoms))
    (hh : h.Support q.formation.atoms) (hc : valsTel q C Γ0 k Γ Φ path vs t r e h i = true) :
    OpenSurface.ValsTel q.D q.B q.formation.rangeKinds C Γ0 k Γ Φ vs t r e :=
  CheckOpenArguments.valsTel_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ hv ht hr he (hh.args i) hc

theorem valsTys_sound {q C Γ0 k Γ Φ path vs as h i} (hq : OpenSound q)
    (hΓ0 : CheckFormation.CtxSupport q.formation.atoms Γ0)
    (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hv : ValuesSupport q.formation.atoms vs) (ha : Ty.SupportList (· ∈ q.formation.atoms) as)
    (hh : h.Support q.formation.atoms) (hc : valsTys q C Γ0 k Γ Φ path vs as h i = true) :
    OpenSurface.ValsTys q.D q.B q.formation.rangeKinds C Γ0 k Γ Φ vs as :=
  CheckOpenArguments.valsTys_sound hq.formation hq.tables.dictionaries hq.sat hΓ0 hΓ hv ha (hh.args i) hc

end Benitoite.Release.Refinement.Surface.CheckOpen
