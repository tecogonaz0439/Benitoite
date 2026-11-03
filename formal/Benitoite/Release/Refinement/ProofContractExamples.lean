import Benitoite.Release.Refinement.ProofContract
import Benitoite.Release.Refinement.CertificateKernelExamples
import Benitoite.Interval.Arithmetic

/-! # 保存幅・正確な比較・使用数・予約と停止の対照 -/
namespace Benitoite.Release.Refinement.StepAccounting.Examples

open CoefficientModel StepAccounting

theorem coefficient_endpoints :
    save storageBits (-170141183460469231731687303715884105728) =
      some (-170141183460469231731687303715884105728) ∧
    save storageBits 170141183460469231731687303715884105727 =
      some 170141183460469231731687303715884105727 ∧
    save storageBits (-170141183460469231731687303715884105729) = none ∧
    save storageBits 170141183460469231731687303715884105728 = none ∧
    save 0 0 = none := by decide

theorem coefficient_operations :
    binary storageBits .add 2 3 = some 5 ∧
    binary storageBits .sub 2 3 = some (-1) ∧
    binary storageBits .mul (-2) 3 = some (-6) ∧
    binary storageBits .divide (-3) 2 = some (-2) ∧
    binary storageBits .divide 3 (-2) = some (-1) ∧
    binary storageBits .divide (-3) (-2) = some 2 ∧
    binary storageBits .divide 1 0 = none ∧
    binary storageBits .divide (-170141183460469231731687303715884105728) (-1) = none ∧
    neg storageBits (-170141183460469231731687303715884105728) = none ∧
    binary storageBits .add 170141183460469231731687303715884105727 1 = none := by decide

example : CoefficientRepresented storageBits 5 :=
  (save_some.mp (show save storageBits 5 = some 5 by decide)).2
example : 5 = CoefficientModel.Binary.eval .add 2 3 ∧ CoefficientRepresented storageBits 5 :=
  ⟨(binary_some (show binary storageBits .add 2 3 = some 5 by decide)).1,
    (binary_some (show binary storageBits .add 2 3 = some 5 by decide)).2.1⟩
example : CoefficientRepresented storageBits (-7) :=
  (neg_some (show neg storageBits 7 = some (-7) by decide)).2.1

def u64max : Int := 18446744073709551615

theorem u64_temporary :
    temporaryProduct u64max u64max = 340282366920938463426481119284349108225 ∧
    CoefficientRepresented 129 (temporaryProduct u64max u64max) ∧
    save storageBits (temporaryProduct u64max u64max) = none ∧
    Benitoite.Interval.IntKind.checkedMul .unsignedInteger64
      ⟨18446744073709551615,by decide⟩ ⟨18446744073709551615,by decide⟩ =
      .rejected .overflow := by
  refine ⟨by decide,by decide,by decide,?_⟩
  rfl

example : u64max = u64max*1 ∧ CoefficientRepresented storageBits u64max ∧
    CoefficientRepresented 129 u64max :=
  product_then_save (by decide) (show save storageBits (temporaryProduct u64max 1) = some u64max by decide)

def decimalMax : Int := 79228162514264337593543950335

theorem decimal_exact :
    (decimalAligned decimalMax 0 decimalMax 28).1 =
      792281625142643375935439503350000000000000000000000000000 ∧
    save storageBits (decimalAligned decimalMax 0 decimalMax 28).1 = none ∧
    CoefficientRepresented 192 (decimalAligned decimalMax 0 decimalMax 28).1 ∧
    (Observation.decimal decimalMax 0).compare .gt (.decimal decimalMax 28) = true := by decide

example : (Observation.decimal decimalMax 0).compare .gt (.decimal decimalMax 28) =
    Comparison.gt.fromEqLt
      (decide ((decimalAligned decimalMax 0 decimalMax 28).1 = (decimalAligned decimalMax 0 decimalMax 28).2))
      (decide ((decimalAligned decimalMax 0 decimalMax 28).1 < (decimalAligned decimalMax 0 decimalMax 28).2))
      (decide ((decimalAligned decimalMax 0 decimalMax 28).2 < (decimalAligned decimalMax 0 decimalMax 28).1)) :=
  decimal_compare _ _ _ _ _

def created : StepState := ⟨5,2,[(1,.body),(0,.handle)],2⟩
def exhausted : StepState := {created with used := 3}

theorem reservations :
    runActions (initial 5) [.create .handle,.create .body] = .ok created ∧
    created.reserved = 2 ∧ created.remaining = 1 ∧
    stepAction created (.work .input .readByte) = .ok exhausted ∧
    exhausted.remaining = 0 ∧
    execute exhausted [.work .input .readByte] = (exhausted,some .stepsExhausted) ∧
    runActions exhausted (rollback exhausted.pending) = .ok ⟨5,5,[],2⟩ ∧
    stepAction (⟨5,5,[],2⟩ : StepState) (.destroy (1,.body)) = .error .malformed ∧
    stepAction (initial 1) (.create .body) = .error .stepsExhausted := by repeat' constructor

theorem exhausted_valid : exhausted.Valid := by
  simp [StepState.Valid,StepState.reserved,exhausted,created]
example : exhausted.used+exhausted.reserved+exhausted.remaining = exhausted.limit :=
  remaining_exact exhausted_valid
example : (execute exhausted [.work .input .readByte]).1.Valid :=
  execute_valid _ _ exhausted_valid
example : runActions exhausted (rollback exhausted.pending) = .ok ⟨5,5,[],2⟩ := rollback_all _
example : ∃ final, runActions exhausted (rollback exhausted.pending) = .ok final ∧ final.Valid ∧
    final.reserved = 0 ∧ final.used = exhausted.used+exhausted.reserved :=
  rollback_within_limit exhausted_valid
example : runActions created [.work .input .readByte] = .ok exhausted :=
  execute_success (by decide)
example : stepAction (⟨5,4,[(0,.handle)],2⟩ : StepState) (.destroy (1,.body)) = .error .malformed :=
  destroy_once exhausted_valid (by rfl)
example : (⟨5,4,[(0,.handle)],2⟩ : StepState).reserved+1 = exhausted.reserved ∧
    (⟨5,4,[(0,.handle)],2⟩ : StepState).used = exhausted.used+1 :=
  destroy_reserved (t := (1,.body)) (by rfl)
example : (⟨5,4,[(0,.handle)],2⟩ : StepState).limit = exhausted.limit :=
  stepAction_limit (a := .destroy (1,.body)) (by rfl)

theorem byte_comparison :
    (compareBytes .input [65,66] [65,66]).value = true ∧
    (compareBytes .input [65,66] [65,66]).actions.length = 13 ∧
    (compareBytes .input [65,66] [65,67]).value = false ∧
    (compareBytes .input [65,66] [65,67]).actions.length = 10 ∧
    (compareBytes .input [] [65]).value = false := by decide
example : (compareBytes .input [65,66] [65,67]).value = true ↔
    ([65,66] : List UInt8) = [65,67] := compareBytes_eq _ _ _
example : (lookup .search [10,20,30] 2).value = some 30 ∧
    (lookup .search [10,20,30] 2).actions.length = 6 ∧
    (lookup .search [10,20,30] 3).value = none ∧
    currentId 3 2 = some ⟨2,by decide⟩ ∧ currentId 3 3 = none := by decide
example : (lookup .checkCertificate [10,20,30] 3).value = ([10,20,30] : List Nat)[3]? := lookup_eq _ _ _
example : (⟨2,by decide⟩ : Fin 3).val = 2 ∧ 2 < 3 := currentId_sound (by decide)

def merged : Work (Except ProofStop (List Int)) := merge storageBits [1,2] [3,4]
theorem coefficient_merge : merged.value = .ok [4,6] ∧ merged.actions.length = 33 ∧
    runActions (initial 35) merged.actions = .ok ⟨35,33,[(1,.body),(0,.body)],2⟩ ∧
    (merge storageBits [1] []).value = .error .malformed ∧
    (merge storageBits [170141183460469231731687303715884105727] [1]).value =
      .error .coefficientRepresentation := by repeat' constructor
example : ∀ c ∈ [4,6], CoefficientRepresented storageBits c :=
  (merge_eq (show (merge storageBits [1,2] [3,4]).value = .ok [4,6] by rfl)).2.2
example : (⟨35,33,[(1,.body),(0,.body)],2⟩ : StepState).used = (initial 35).used+merged.actions.length :=
  work_used (w := merged) (by rfl)
example : (⟨35,33,[(1,.body),(0,.body)],2⟩ : StepState).used+
      (⟨35,33,[(1,.body),(0,.body)],2⟩ : StepState).reserved ≤ 35 ∧
    (⟨35,33,[(1,.body),(0,.body)],2⟩ : StepState).used+
      (⟨35,33,[(1,.body),(0,.body)],2⟩ : StepState).reserved+
      (⟨35,33,[(1,.body),(0,.body)],2⟩ : StepState).remaining = 35 :=
  within_limit (actions := merged.actions) (initial_valid 35) (by rfl)
example : (cloneElements .normalize 2).length = 7 ∧
    runActions (initial 9) (cloneElements .normalize 2) = .ok ⟨9,7,[(1,.body),(0,.body)],2⟩ := by repeat' constructor
example : (⟨3,3,[],0⟩ : StepState).used = (initial 3).used+1+1+1 :=
  input_certificate_expansion [.work .input .readByte] [.work .writeCertificate .node]
    [.work .search .edge] (by rfl)

theorem stops : storeCoefficient storageBits (temporaryProduct u64max u64max) =
      .error .coefficientRepresentation ∧
    runActions (initial 0) [.work .input .readByte] = .error .stepsExhausted ∧
    (replayProof CertificateKernelExamples.premise CertificateKernelExamples.goal
      CertificateKernelExamples.badTwice).isProved = false ∧
    ProofContract.coefficientBits = 128 ∧ ProofContract.stepsVersion = "proof-steps-v1" := by repeat' constructor
example : (7 : Int) = 7 ∧ CoefficientRepresented storageBits 7 :=
  storeCoefficient_sound (bits := storageBits) (n := 7) (result := 7) (by rfl)
example (reason : ProofStop) : (ProofResult.stopped reason).isProved = false := stopped_not_proved reason
example : Entails [CertificateKernelExamples.premise] CertificateKernelExamples.goal :=
  replay_proved (c := CertificateKernelExamples.twice) (by decide)

-- 二条件の読者。全実作業との区別は設計書 01-12「篩の係数と基本操作の計上」に従う。
example (actions : List Action) (limit : Nat) (final : StepState)
    (ha : runActions (initial limit) actions = .ok final) :
    Entails [CertificateKernelExamples.premise] CertificateKernelExamples.goal ∧
      final.used = actions.length ∧ final.Valid :=
  ProofContract.Accepted.sound ⟨ha,CertificateKernelExamples.twice_checked⟩

-- byteの読取りはelementと重ねず、実行しなかった加算・出力生成は記録しない。
theorem accounting_prefixes :
    (compareBytes .input [65] [66]).actions =
      [.work .input .node,.work .input .readByte,.work .input .readByte,.work .input .compareByte] ∧
    (merge storageBits [170141183460469231731687303715884105728] [0]).actions =
      [.work .normalize .node,.work .normalize .element,.work .normalize .element,
       .work .normalize .compareWord,.work .normalize .compareWord,.work .normalize .compareWord] ∧
    (merge storageBits [-170141183460469231731687303715884105729] [0]).actions.length = 5 ∧
    (merge storageBits [0] [170141183460469231731687303715884105728]).actions.length = 9 ∧
    (merge storageBits [170141183460469231731687303715884105727] [1]).actions.length = 13 := by decide

theorem counted_stops :
    (checkAccounted 0 [.work .input .readByte] CertificateKernelExamples.premise
      CertificateKernelExamples.goal CertificateKernelExamples.twice).isProved = false ∧
    (checkAccounted 10 [.destroy (0,.body)] CertificateKernelExamples.premise
      CertificateKernelExamples.goal CertificateKernelExamples.twice).isProved = false ∧
    (checkAccounted 1 [.work .input .readByte] CertificateKernelExamples.premise
      CertificateKernelExamples.goal CertificateKernelExamples.twice).isProved = true := by decide

example : checkAccounted 0 [.work .input .readByte] CertificateKernelExamples.premise
    CertificateKernelExamples.goal CertificateKernelExamples.twice = .stopped .stepsExhausted :=
  checkAccounted_stopped (by rfl)

example : ∃ final, ProofContract.Accepted CertificateKernelExamples.premise
    CertificateKernelExamples.goal CertificateKernelExamples.twice 1 [.work .input .readByte] final :=
  checkAccounted_proved (by decide)

-- 二条件だけのAcceptedは空列も許す。全実作業の計上の証拠としては使えない。
example : ProofContract.Accepted CertificateKernelExamples.premise CertificateKernelExamples.goal
    CertificateKernelExamples.twice 0 [] (initial 0) := ⟨rfl,CertificateKernelExamples.twice_checked⟩

end Benitoite.Release.Refinement.StepAccounting.Examples
