import Benitoite.Release.Refinement.RefutationSyntax

/-! # 同じ置換像で読む枝の事実と線形の導出

設計書 01-12「閉じた述語の評価と捕捉」に対応する。
- 個々の規則は現在のtodo/factsだけを読む。
- 組込みの葉を含む反証全体の帰納とは分ける。
-/
namespace Benitoite.Release.Refinement

/-- literalを含むため、鍵列のmapだけで述語の置換を代用しない。 -/
def NNF.HoldsAt (keys : KeyTable) (ν : ObservationEnv) (η : ObservationEnvModel) (q : NNF) : Prop :=
  (predBind ν (q.toPred keys)).interpret η = true

theorem normalize_holds_at {keys p negative q} (h : normalize keys p negative = some q)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    q.HoldsAt keys ν η ↔
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) = true := by
  unfold NNF.HoldsAt
  rw [normalize_sound_at h ν η]

/-- 線形化とNNFの意味を同じkeysとνの上で合成する。 -/
theorem normalize_linear_at {keys p negative l} (h : normalize keys p negative = some (.linear l))
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    l.Holds (keyEnv η (keys.map (termBind ν))) ↔
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) = true := by
  rw [← Linear.toPred_sound_at η ν keys l]
  exact normalize_holds_at h ν η

/-- 同じνの上で、未処理と既知の両方の条件を読む。 -/
def BranchHoldsAt (keys : KeyTable) (todo facts : List NNF)
    (ν : ObservationEnv) (η : ObservationEnvModel) : Prop :=
  ∀ q ∈ todo ++ facts, q.HoldsAt keys ν η

def BranchRefutedAt (keys : KeyTable) (todo facts : List NNF)
    (ν : ObservationEnv) (η : ObservationEnvModel) : Prop :=
  BranchHoldsAt keys todo facts ν η → False

namespace CertificateKernel

theorem consume_sound_at {keys todo facts next}
    (h : consume next todo facts = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η := by
  intro hm
  cases todo with
  | nil => simp [consume] at h
  | cons q rest =>
    have hq := hm q (by simp)
    have tail : BranchHoldsAt keys rest facts ν η := fun a ha => hm a (by simp_all)
    cases q with
    | truth => exact child _ _ h tail
    | falsity => exact Bool.noConfusion hq
    | linear l | literal p n =>
      apply child _ _ h
      intro a ha
      simp only [List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at ha
      rcases ha with ha | ha | rfl
      · exact tail a (List.mem_append_left _ ha)
      · exact tail a (List.mem_append_right _ ha)
      · exact hq
    | and p q =>
      have hh : p.HoldsAt keys ν η ∧ q.HoldsAt keys ν η := by
        simpa only [NNF.HoldsAt, NNF.toPred, predBind, Pred.interpret, Bool.and_eq_true] using hq
      apply child _ _ h
      intro a ha
      simp only [List.mem_append, List.mem_cons] at ha
      rcases ha with (rfl | rfl | ha) | ha
      · exact hh.1
      · exact hh.2
      · exact tail a (List.mem_append_left _ ha)
      · exact tail a (List.mem_append_right _ ha)
    | or p q => simp [consume] at h

theorem cases_sound_at {keys todo facts left right}
    (h : cases left right todo facts = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (hl : ∀ ts fs, left ts fs = true → BranchRefutedAt keys ts fs ν η)
    (hr : ∀ ts fs, right ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η := by
  intro hm
  cases todo with
  | nil => simp [cases] at h
  | cons q rest =>
    cases q <;> simp only [cases, Bool.false_eq_true] at h
    rename_i p q
    have hq := hm (.or p q) (by simp)
    have hh : p.HoldsAt keys ν η ∨ q.HoldsAt keys ν η := by
      simpa only [NNF.HoldsAt, NNF.toPred, predBind, Pred.interpret, Bool.or_eq_true] using hq
    have tail : ∀ a ∈ rest ++ facts, a.HoldsAt keys ν η := fun a ha => hm a (by simp_all)
    have extend (a : NNF) (ha : a.HoldsAt keys ν η) : BranchHoldsAt keys (a::rest) facts ν η := by
      intro b hb
      rcases List.mem_cons.mp hb with rfl | hb
      · exact ha
      · exact tail b hb
    simp only [Bool.and_eq_true] at h
    rcases h with ⟨hleft,hright⟩
    rcases hh with hp | hq
    · exact hl _ _ hleft (extend p hp)
    · exact hr _ _ hright (extend q hq)

theorem derive_sound_at {keys : KeyTable} {todo facts : List NNF} {step : LinearStep}
    {next : List NNF → List NNF → Bool}
    (h : (step.check keys.length facts && next todo (facts ++ [.linear step.result])) = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η := by
  intro hm
  simp only [Bool.and_eq_true] at h
  have hl := LinearStep.sound h.1 (keyEnv η (keys.map (termBind ν))) (by
    intro q hq a he
    subst q
    exact (Linear.toPred_sound_at η ν keys a).mp (hm _ (List.mem_append_right _ hq)))
  apply child _ _ h.2
  intro q hq
  simp only [List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at hq
  rcases hq with hq | hq | rfl
  · exact hm q (List.mem_append_left _ hq)
  · exact hm q (List.mem_append_right _ hq)
  · exact (Linear.toPred_sound_at η ν keys _).mpr hl

theorem split_sound_at {keys todo facts key cut left right}
    (h : split keys todo facts key cut left right = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (hl : ∀ ts fs, left ts fs = true → BranchRefutedAt keys ts fs ν η)
    (hr : ∀ ts fs, right ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η := by
  intro hm
  unfold split at h
  cases hk : keys[key]? with
  | none => simp [hk] at h
  | some t =>
    simp only [hk, Bool.and_eq_true] at h
    have hi := (List.getElem?_eq_some_iff.mp hk).1
    have he : keyEnv η (keys.map (termBind ν)) key = integerAs η (termBind ν t) := by
      simp [keyEnv, List.getElem?_map, hk]
    have extend (q : NNF) (hq : q.HoldsAt keys ν η) :
        BranchHoldsAt keys todo (facts ++ [q]) ν η := by
      intro a ha
      simp only [List.mem_append, List.mem_cons, List.not_mem_nil, or_false] at ha
      rcases ha with ha | ha | rfl
      · exact hm a (List.mem_append_left _ ha)
      · exact hm a (List.mem_append_right _ ha)
      · exact hq
    rcases integerAs_split_at η ν t cut with hleft | hright
    · apply hl _ _ h.1
      apply extend
      change (predBind ν ((Linear.mk (keyCoefficients keys.length key) cut).toPred keys)).interpret η = true
      rw [Linear.toPred_sound_at]
      change linearDot _ _ ≤ cut
      rw [linearDot_keyCoefficients hi, he]
      exact hleft
    · apply hr _ _ h.2
      apply extend
      change (predBind ν ((Linear.mk ((keyCoefficients keys.length key).map ((-1) * ·)) (-(cut+1))).toPred keys)).interpret η = true
      rw [Linear.toPred_sound_at]
      change linearDot _ _ ≤ -(cut+1)
      rw [linearDot_scale, linearDot_keyCoefficients hi, he]
      omega

theorem close_linear_sound_at {keys todo facts i} (h : closeLinear facts i = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) : BranchRefutedAt keys todo facts ν η := by
  intro hm
  unfold closeLinear at h
  split at h
  · rename_i l hi
    have hc := of_decide_eq_true h
    have ht := (Linear.toPred_sound_at η ν keys l).mp
      (hm _ (List.mem_append_right _ (List.mem_of_getElem? hi)))
    change linearDot l.coefficients _ ≤ l.bound at ht
    rw [hc.1, linearDot_zero] at ht
    omega
  · cases h

theorem close_atom_sound_at {keys todo facts p n} (h : closeAtom facts p n = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) : BranchRefutedAt keys todo facts ν η := by
  intro hm
  unfold closeAtom at h
  split at h
  · rename_i a b hp hn
    have he := (predEq_spec a b).mp h
    subst b
    have ha := hm _ (List.mem_append_right _ (List.mem_of_getElem? hp))
    have hb := hm _ (List.mem_append_right _ (List.mem_of_getElem? hn))
    exact Pred.opposite_at a ν η ⟨ha,hb⟩
  · cases h

theorem discard_todo_sound_at {keys todo facts next} (h : discardTodo next todo facts = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η := by
  intro hm
  cases todo with
  | nil => simp [discardTodo] at h
  | cons q rest => exact child _ _ h (fun a ha => hm a (by simp_all))

theorem discard_fact_sound_at {keys todo facts next i} (h : discardFact next todo facts i = true)
    (ν : ObservationEnv) (η : ObservationEnvModel)
    (child : ∀ ts fs, next ts fs = true → BranchRefutedAt keys ts fs ν η) :
    BranchRefutedAt keys todo facts ν η := by
  intro hm
  unfold discardFact at h
  split at h
  · apply child _ _ h
    intro a ha
    rcases List.mem_append.mp ha with ha | ha
    · exact hm a (List.mem_append_left _ ha)
    · exact hm a (List.mem_append_right _ (List.mem_of_mem_eraseIdx ha))
  · cases h

end CertificateKernel
end Benitoite.Release.Refinement
