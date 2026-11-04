import Benitoite.Release.Refinement.StandardFloatOperatorResponse
import Benitoite.Release.Refinement.StandardDecimalOperatorResponse

/-! 旧部分δの応答不存在と、新しい名前付きδの全入力の応答存在を区別する対照。 -/
namespace Benitoite.Release.Refinement.StandardResponseContrast

theorem float_add_present {P B Ψ ts es rs ws a e}
    (args : BuiltinArgs P B Ψ "%Float.add"
      (StandardFloatOperatorResponse.signature false .add) ts es rs ws a e) :
    ∃ out, StandardFloatOperatorResponse.delta false .add "%Float.add" ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) :=
  StandardFloatOperatorResponse.response false .add args

theorem decimal_add_present {P B Ψ ts es rs ws a e}
    (args : BuiltinArgs P B Ψ "%Decimal.add"
      (StandardDecimalOperatorResponse.signature .add) ts es rs ws a e) :
    ∃ out, StandardDecimalOperatorResponse.delta .add "%Decimal.add" ts es rs ws=some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out≠.exit i) :=
  StandardDecimalOperatorResponse.response .add args

#print axioms float_add_present
#print axioms decimal_add_present
end Benitoite.Release.Refinement.StandardResponseContrast
