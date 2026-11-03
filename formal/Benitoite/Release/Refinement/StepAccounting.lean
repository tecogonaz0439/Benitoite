import Std

/-! # 基本操作の使用数と、個別に予約する後始末 -/
namespace Benitoite.Release.Refinement

inductive ProofStop where
  | malformed | coefficientRepresentation | stepsExhausted
  deriving DecidableEq, Repr

namespace StepAccounting

def version : String := "proof-steps-v1"

inductive Phase where
  | input | normalize | search | realize | writeCertificate | checkCertificate | cleanup
  deriving DecidableEq, Repr

/-- 各タグは一回の基本操作。可変長の比較や算術は操作列へ分ける。 -/
inductive Operation where
  | readByte | compareByte | node | edge | element
  | add | sub | mul | divide | negate | compareWord
  deriving DecidableEq, Repr

inductive Cleanup where
  | handle | body | rollbackEntry | stackEntry
  deriving DecidableEq, Repr

abbrev Ticket := Nat × Cleanup

structure StepState where
  limit : Nat
  used : Nat
  pending : List Ticket
  next : Nat
  deriving DecidableEq, Repr

def StepState.reserved (s : StepState) : Nat := s.pending.length
def StepState.remaining (s : StepState) : Nat := s.limit - (s.used+s.reserved)
def StepState.Valid (s : StepState) : Prop :=
  s.used+s.reserved ≤ s.limit ∧ s.pending.Nodup ∧ ∀ t ∈ s.pending, t.1 < s.next

def initial (limit : Nat) : StepState := ⟨limit,0,[],0⟩

theorem initial_valid (limit : Nat) : (initial limit).Valid := by
  simp [initial, StepState.Valid, StepState.reserved]

theorem remaining_exact {s : StepState} (h : s.Valid) :
    s.used+s.reserved+s.remaining = s.limit := by
  simp only [StepState.remaining]
  have := h.1
  omega

inductive Action where
  | work (phase : Phase) (op : Operation)
  | create (cleanup : Cleanup)
  | destroy (ticket : Ticket)
  deriving DecidableEq, Repr

/-- 生成は一要素を計上し、その後始末一操作を同時に予約する。 -/
def stepAction (s : StepState) : Action → Except ProofStop StepState
  | .work _ _ =>
    if s.used+s.reserved+1 ≤ s.limit then .ok {s with used := s.used+1}
    else .error .stepsExhausted
  | .create k =>
    if s.used+s.reserved+2 ≤ s.limit then
      .ok {s with used := s.used+1, pending := (s.next,k)::s.pending, next := s.next+1}
    else .error .stepsExhausted
  | .destroy t =>
    if t ∈ s.pending then .ok {s with used := s.used+1, pending := s.pending.erase t}
    else .error .malformed

theorem stepAction_used {s s' : StepState} {a : Action} (h : stepAction s a = .ok s') :
    s'.used = s.used+1 := by
  cases a <;> simp only [stepAction] at h <;> split at h <;> cases h <;> rfl

theorem stepAction_limit {s s' : StepState} {a : Action} (h : stepAction s a = .ok s') :
    s'.limit = s.limit := by
  cases a <;> simp only [stepAction] at h <;> split at h <;> cases h <;> rfl

theorem stepAction_valid {s s' : StepState} {a : Action} (hs : s.Valid)
    (h : stepAction s a = .ok s') : s'.Valid := by
  rcases hs with ⟨hb, hn, hf⟩
  cases a with
  | work phase op =>
    simp only [stepAction] at h
    split at h
    · cases h
      refine ⟨?_, hn, hf⟩
      simpa only [StepState.reserved, Nat.add_right_comm] using ‹s.used+s.reserved+1 ≤ s.limit›
    · cases h
  | create k =>
    simp only [stepAction] at h
    split at h
    · rename_i hc
      cases h
      refine ⟨?_, ?_, ?_⟩
      · simp only [StepState.reserved, List.length_cons] at *
        omega
      · apply List.nodup_cons.mpr
        exact ⟨fun hm => Nat.lt_irrefl s.next (hf _ hm), hn⟩
      · intro t ht
        rcases List.mem_cons.mp ht with rfl | ht
        · exact Nat.lt_succ_self _
        · exact Nat.lt_succ_of_lt (hf t ht)
    · cases h
  | destroy t =>
    simp only [stepAction] at h
    split at h
    · rename_i ht
      cases h
      refine ⟨?_, hn.erase t, fun u hu => hf u (List.mem_of_mem_erase hu)⟩
      have hl := List.length_erase_of_mem ht
      have hp : 0 < s.pending.length := List.length_pos_iff.mpr (List.ne_nil_of_mem ht)
      simp only [StepState.reserved] at *
      omega
    · cases h

theorem destroy_reserved {s s' : StepState} {t : Ticket}
    (h : stepAction s (.destroy t) = .ok s') :
    s'.reserved+1 = s.reserved ∧ s'.used = s.used+1 := by
  simp only [stepAction] at h
  split at h
  · rename_i ht
    cases h
    have hl := List.length_erase_of_mem ht
    have hp : 0 < s.pending.length := List.length_pos_iff.mpr (List.ne_nil_of_mem ht)
    simp only [StepState.reserved]
    exact ⟨by omega,trivial⟩
  · cases h

theorem destroy_once {s s' : StepState} {t : Ticket} (hs : s.Valid)
    (h : stepAction s (.destroy t) = .ok s') : stepAction s' (.destroy t) = .error .malformed := by
  simp only [stepAction] at h
  split at h
  · cases h
    simp only [stepAction]
    have hn : t ∉ s.pending.erase t := by
      exact List.Nodup.not_mem_erase hs.2.1
    simp [hn]
  · cases h

def runActions : StepState → List Action → Except ProofStop StepState
  | s, [] => .ok s
  | s, a::as => match stepAction s a with
    | .ok s' => runActions s' as
    | .error reason => .error reason

theorem runActions_used {as : List Action} {s s' : StepState} (h : runActions s as = .ok s') :
    s'.used = s.used+as.length := by
  induction as generalizing s with
  | nil => cases h; simp
  | cons a as ih =>
    simp only [runActions] at h
    split at h
    · rename_i s₁ he
      have := ih h
      have := stepAction_used he
      simp only [List.length_cons]
      omega
    · cases h

theorem runActions_valid {as : List Action} {s s' : StepState} (hs : s.Valid)
    (h : runActions s as = .ok s') : s'.Valid := by
  induction as generalizing s with
  | nil => cases h; exact hs
  | cons a as ih =>
    simp only [runActions] at h
    split at h
    · rename_i s₁ he
      exact ih (stepAction_valid hs he) h
    · cases h

/-- 停止した接頭辞の状態を保持し、予約済みの後始末を続けられる。 -/
def execute : StepState → List Action → StepState × Option ProofStop
  | s, [] => (s,none)
  | s, a::as => match stepAction s a with
    | .ok s' => execute s' as
    | .error reason => (s,some reason)

theorem execute_valid (s : StepState) (as : List Action) (hs : s.Valid) :
    (execute s as).1.Valid := by
  induction as generalizing s with
  | nil => exact hs
  | cons a as ih =>
    simp only [execute]
    split
    · rename_i s' he
      exact ih s' (stepAction_valid hs he)
    · exact hs

theorem execute_success {s s' : StepState} {as : List Action}
    (h : execute s as = (s',none)) : runActions s as = .ok s' := by
  induction as generalizing s with
  | nil => cases h; rfl
  | cons a as ih =>
    simp only [execute] at h
    simp only [runActions]
    split at h
    · exact ih h
    · cases h

end StepAccounting
end Benitoite.Release.Refinement
