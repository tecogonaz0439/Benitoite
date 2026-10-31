import Benitoite.Release.Refinement.DependentBeta
namespace Benitoite.Release.Refinement
example : Entails [] (.eq (.integer 7) (.integer 7)) := .eq_refl
#print axioms StateTy.dependent_beta_one
#print axioms HasTypeCQ.open_one
#print axioms Builtins.ExternalAssumptions.received_facts
#print Outcome.Carrier
end Benitoite.Release.Refinement
