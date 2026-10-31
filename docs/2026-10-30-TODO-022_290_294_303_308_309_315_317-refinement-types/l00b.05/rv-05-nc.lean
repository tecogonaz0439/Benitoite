import Benitoite.Release.Refinement.Certificate
open Benitoite.Release.Refinement
example : Certificate.check [.truth] .truth (.use 0) = true := by decide
example : EqProof.check (.integer 0) (.integer 0) .refl = true := by decide
