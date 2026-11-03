import Benitoite.Release.Refinement.BuiltinLogicExamples
import Benitoite.Release.Refinement.CertificateKernelExamples

open Benitoite.Release.Refinement
open BuiltinLogicExamples CertificateKernelExamples

def main : IO Unit := do
  let checks : List (String × Bool) :=
    [("registry100", registry.flatten.length == 100 && registry.flatten.all (PreparedLeaf.checkRaw [])),
     ("comparisons30", closedComparisons.length == 30 &&
       closedComparisons.all (fun (p,b) => p.evalClosed == some b)),
     ("comparisonBoundaries48", closedComparisonBoundaries.length == 48 &&
       closedComparisonBoundaries.all (fun (p,b) => p.evalClosed == some b)),
     ("alteredLeaves6", alteredLeaves.length == 6 &&
       alteredLeaves.all (fun (Φ,l) => !(l.checkRaw Φ))),
     ("classes12", closedClasses.length == 12 && closedClasses.all (fun p => p.evalClosed == some true)),
     ("twelveAcceptReject", samples.all (fun (Φ,l) => l.checkRaw Φ &&
       !(PreparedLeaf.checkRaw Φ {l with predicate := .falsity}))),
     ("linearAccept", CertificateKernel.check premise goal twice),
     ("linearReject", !(CertificateKernel.check premise goal badTwice)),
     ("builtin", CertificateKernel.check (.lt (.measure .listLength (.var 0)) (.integer 0))
       .falsity negativeLength),
     ("boolean", CertificateKernel.check .truth booleanApart booleanLeaf)]
  for (name, ok) in checks do
    IO.println s!"{name}: {ok}"
  if !(checks.all Prod.snd) then
    throw (IO.userError "logical kernel check failed")
