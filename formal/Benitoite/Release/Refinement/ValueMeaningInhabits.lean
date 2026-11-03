import Benitoite.Release.Refinement.PatternNormalForm
import Benitoite.Release.Refinement.ObservationSubstitution

namespace Benitoite.Release.Refinement
noncomputable section

theorem RefinementPossible.of_meaning {p : Pred} {v : Val} {η : ObservationEnvModel}
    (hp : p.interpret (selfModel η v) = true) : RefinementPossible p v := by
  intro hn
  have hm : ObservationEnvModel.InfoLE (selfModel (fun _ => none) v) (selfModel η v) := by
    intro i; cases i with
    | zero => exact .refl _
    | succ i => exact .none _
  have hf := Pred.evalWith_sound (p.evalWith_mono _ _ false hm hn)
  rw [hp] at hf
  cases hf

mutual
  theorem valueMeaning_inhabits_normal {P : Program} {η : ObservationEnvModel} {a : Ty} {v : Val}
      (h : ValueMeaning P η a v) : Inhabits P a.norm v := by
    match h with
    | .mk hs hp hc =>
      exact Inhabits.of_core_possible (valueShapeMeaning_inhabits hs)
        (fun p hm => RefinementPossible.of_meaning (hp p hm))
  theorem valueShapeMeaning_inhabits {P : Program} {η : ObservationEnvModel} {a : Ty} {v : Val}
      (h : ValueShapeMeaning P η a v) : Inhabits P a v := by
    match h with
    | .const => exact .const
    | .con hc hn hw hs => exact .con hc hn hw (valueMeanings_inhabit hs)
    | .atError hs => exact .atError hs
    | .list hs => exact .list (valueMeaningEach_inhabit hs)
    | .fn => exact .fn
    | .dependentFn => exact .dependentFn
    | .tvar => exact .tvar
    | .reference => exact .reference
    | .lazy => exact .lazy
    | .cont => exact .cont
    | .map => exact .map
    | .set => exact .set
    | .bytes => exact .bytes
    | .dict => exact .dict
    | .tapp => exact .tapp
    | .ctor => exact .ctor
    | .external => exact .external
    | .scoped _ => exact .scoped
    | .pathBases => exact .pathBases
    | .scopePattern => exact .scopePattern
    | .checked => exact .checked
    | .checkedRequest => exact .checkedRequest
    | .checkedAtOpaque => exact .checkedAtOpaque
  theorem valueMeanings_inhabit {P : Program} {η : ObservationEnvModel} {as : List Ty} {vs : List Val}
      (h : ValueMeanings P η as vs) : InhabitsAll P as vs := by
    match h with
    | .nil => exact .nil
    | .cons h hs =>
      exact .cons ((Inhabits.norm_all_iff _ _).mp (valueMeaning_inhabits_normal h))
          (valueMeanings_inhabit hs)
  theorem valueMeaningEach_inhabit {P : Program} {η : ObservationEnvModel} {a : Ty} {vs : List Val}
      (h : ValueMeaningEach P η a vs) : InhabitsEach P a vs := by
    match h with
    | .nil => exact .nil
    | .cons h hs =>
      exact .cons ((Inhabits.norm_all_iff _ _).mp (valueMeaning_inhabits_normal h))
          (valueMeaningEach_inhabit hs)
end

end
end Benitoite.Release.Refinement
