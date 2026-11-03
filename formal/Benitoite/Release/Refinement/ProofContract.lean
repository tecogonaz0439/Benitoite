import Benitoite.Release.Refinement.AccountingWork
import Benitoite.Release.Refinement.Certificate

/-! # 有限検査と、実装へ渡す計上の契約 -/
namespace Benitoite.Release.Refinement

namespace StepAccounting

/-- I・C・P を基本操作列として与えた場合の、使用数の増分。 -/
theorem input_certificate_expansion {s s' : StepState} (input certificate expansion : List Action)
    (h : runActions s (input ++ certificate ++ expansion) = .ok s') :
    s'.used = s.used + input.length + certificate.length + expansion.length := by
  have hu := runActions_used h
  simp only [List.length_append] at hu
  omega

theorem within_limit {s s' : StepState} {actions : List Action} (hs : s.Valid)
    (h : runActions s actions = .ok s') : s'.used+s'.reserved ≤ s'.limit ∧
      s'.used+s'.reserved+s'.remaining = s'.limit :=
  ⟨(runActions_valid hs h).1,remaining_exact (runActions_valid hs h)⟩

end StepAccounting

inductive ProofResult where
  | proved (certificate : Certificate)
  | unproved
  | stopped (reason : ProofStop)

def ProofResult.isProved : ProofResult → Bool
  | .proved _ => true | _ => false

def storeCoefficient (bits : Nat) (n : Int) : Except ProofStop Int :=
  match CoefficientModel.save bits n with
  | some n => .ok n
  | none => .error .coefficientRepresentation

theorem storeCoefficient_sound {bits : Nat} {n result : Int}
    (h : storeCoefficient bits n = .ok result) :
    result = n ∧ CoefficientRepresented bits result := by
  unfold storeCoefficient at h
  split at h
  · rename_i n' hn
    cases h
    obtain ⟨rfl,hr⟩ := CoefficientModel.save_some.mp hn
    exact ⟨rfl,hr⟩
  · cases h

/-- raw の再生だけを行う。全実作業の計上との区別は設計書 01-12「篩の係数と基本操作の計上」に従う。 -/
def replayProof (premise goal : Pred) (certificate : Certificate) : ProofResult :=
  if CertificateKernel.check premise goal certificate then .proved certificate
  else .stopped .malformed

theorem replay_checked {p q : Pred} {c : Certificate} :
    (replayProof p q c).isProved = true ↔ CertificateKernel.check p q c = true := by
  cases hc : CertificateKernel.check p q c <;> simp [replayProof,ProofResult.isProved,hc]

theorem replay_proved {p q : Pred} {c : Certificate}
    (h : (replayProof p q c).isProved = true) : Entails [p] q := by
  exact Entails.checked (replay_checked.mp h) (.hyp List.mem_cons_self)

/-- 三種の停止は、検査成功の証拠を生成しない。 -/
theorem stopped_not_proved (reason : ProofStop) :
    (ProofResult.stopped reason).isProved = false := rfl

namespace ProofContract

def stepsVersion : String := StepAccounting.version
def coefficientBits : Nat := CoefficientModel.storageBits

/-- 成功した操作列と raw 再生の二条件。全実作業との一致は要求しない（設計書 01-12「篩の係数と基本操作の計上」）。 -/
structure Accepted (p q : Pred) (c : Certificate)
    (limit : Nat) (actions : List StepAccounting.Action) (final : StepAccounting.StepState) : Prop where
  accounted : StepAccounting.runActions (StepAccounting.initial limit) actions = .ok final
  checked : CertificateKernel.check p q c = true

theorem Accepted.sound {p q : Pred} {c : Certificate} {limit actions final}
    (h : Accepted p q c limit actions final) :
    Entails [p] q ∧ final.used = actions.length ∧ final.Valid := by
  refine ⟨Entails.checked h.checked (.hyp List.mem_cons_self), ?_, ?_⟩
  · simpa only [StepAccounting.initial, Nat.zero_add] using StepAccounting.runActions_used h.accounted
  · exact StepAccounting.runActions_valid (StepAccounting.initial_valid limit) h.accounted

end ProofContract

/-- 与えられた操作列の失敗時には再生へ進まない。全実作業との一致は別の義務である
（設計書 01-12「篩の係数と基本操作の計上」）。 -/
def checkAccounted (limit : Nat) (actions : List StepAccounting.Action)
    (premise goal : Pred) (certificate : Certificate) : ProofResult :=
  match StepAccounting.runActions (StepAccounting.initial limit) actions with
  | .error reason => .stopped reason
  | .ok _ => replayProof premise goal certificate

theorem checkAccounted_stopped {limit actions p q c reason}
    (h : StepAccounting.runActions (StepAccounting.initial limit) actions = .error reason) :
    checkAccounted limit actions p q c = .stopped reason := by
  simp only [checkAccounted,h]

theorem checkAccounted_proved {limit actions p q c}
    (h : (checkAccounted limit actions p q c).isProved = true) :
    ∃ final, ProofContract.Accepted p q c limit actions final := by
  unfold checkAccounted at h
  split at h
  · cases h
  · rename_i final he
    exact ⟨final,he,replay_checked.mp h⟩

end Benitoite.Release.Refinement
