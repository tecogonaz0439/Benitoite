import Benitoite.Release.Refinement.ProofContractExamples
import Benitoite.Release.Refinement.BuiltinLogicExamples

/-! # 同じ有限入力の核内での照合 -/
namespace Benitoite.Release.Refinement.ProofReplayExamples
open CertificateKernelExamples

/-- この列を核内の decide で検査する。実行時の再生も同じ rows を読む。 -/
def rows : List (String × Bool) :=
  [("linear",CertificateKernel.check premise goal twice),
   ("alteredLinear",!(CertificateKernel.check premise goal badTwice)),
   ("measure",CertificateKernel.check
     (.lt (.measure .listLength (.var 0)) (.integer 0)) .falsity negativeLength),
   ("boolean",CertificateKernel.check .truth booleanApart booleanLeaf),
   ("substitute",replacing.check [.eq (.var 0) (.var 1),source] target),
   ("legacySix",legacySix.embed.check [.and .truth (.or .truth .truth)] .truth),
   ("builtin100",BuiltinLogicExamples.registry.flatten.all (PreparedLeaf.checkRaw [])),
   ("alteredBuiltin",BuiltinLogicExamples.alteredLeaves.all
     (fun (facts,leaf) => !(leaf.checkRaw facts))),
   ("closedComparisons",BuiltinLogicExamples.closedComparisons.all
     (fun (p,b) => p.evalClosed == some b)),
   ("comparisonBoundaries",BuiltinLogicExamples.closedComparisonBoundaries.all
     (fun (p,b) => p.evalClosed == some b)),
   ("floatClasses",BuiltinLogicExamples.closedClasses.all (fun p => p.evalClosed == some true)),
   ("coefficient",CoefficientModel.save 128 170141183460469231731687303715884105727 ==
     some 170141183460469231731687303715884105727),
   ("representation",CoefficientModel.save 128
     (CoefficientModel.temporaryProduct 18446744073709551615 18446744073709551615) == none),
   ("decimal",(Observation.decimal 79228162514264337593543950335 0).compare .gt
     (.decimal 79228162514264337593543950335 28)),
   ("bytes",!(StepAccounting.compareBytes .input [65,66] [65,67]).value),
   ("steps",match StepAccounting.runActions (StepAccounting.initial 0)
       [.work .input .readByte] with | .error .stepsExhausted => true | _ => false),
   ("cleanup",match StepAccounting.runActions StepAccounting.Examples.exhausted
       (StepAccounting.rollback StepAccounting.Examples.exhausted.pending) with
     | .ok s => decide (s.used = 5 ∧ s.reserved = 0) | _ => false),
   ("byteOperations",(StepAccounting.compareBytes .input [65,66] [65,66]).actions.length == 13),
   ("inputRepresentationPrefix",(StepAccounting.merge 128
     [170141183460469231731687303715884105728] [0]).actions.length == 6),
   ("negativeDivisor",CoefficientModel.binary 128 .divide (-3) (-2) == some 2),
   ("accountedStop",!(checkAccounted 0 [.work .input .readByte] premise goal twice).isProved),
   ("accountedSuccess",(checkAccounted 1 [.work .input .readByte] premise goal twice).isProved)]

theorem rows_checked : rows.length = 22 ∧ rows.all Prod.snd = true := by decide

end Benitoite.Release.Refinement.ProofReplayExamples
