import Benitoite.Release.Refinement.TypedMeaning
import Benitoite.Release.Refinement.CloseTyping

/-! # CaptureOk から網羅性（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem Capture.typed_coverage {P : Program} {B Ψ a w ps} {cap : Capture}
    (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] w (cap.closeTy a))
    (coverage : Exhaustive P a ps) : ∃ p ∈ ps, (matchVal p w).isSome :=
  Capture.meaning_coverage (typed_value_meaning_closed valid typed) coverage

theorem CaptureOk.typed_variable_coverage {P : Program} {B Ψ R Γ Φ cap i a ps}
    (valid : P.VarianceValid) (hc : CaptureOk P B Ψ R Γ Φ cap)
    (hv : HasTypeVQ P B Ψ Qempty [] Γ Φ (.var i) a)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : Ψ.WF)
    (coverage : Exhaustive P a ps) :
    ∃ p ∈ ps, (matchVal p (closeVal cap (.var i))).isSome := by
  obtain ⟨typed, cover⟩ := hc.variable_coverage hv hA hstore coverage
  exact cover (typed_value_meaning_closed valid typed)

/-- closeVal の閉じた型付けを入力に、同じ値の意味と元の型への所属を得る。 -/
theorem Capture.typed_meaning {P : Program} {B Ψ cap v a}
    (valid : P.VarianceValid)
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap v) (cap.closeTy a)) :
    ValueMeaning P (fun _ => none) (cap.closeTy a) (closeVal cap v) ∧
      Inhabits P a (closeVal cap v) := by
  exact ⟨typed_value_meaning_closed valid typed,
    (inhabits_of_typed_raw valid typed).of_subst_values cap.env a rfl⟩

end
end Benitoite.Release.Refinement
