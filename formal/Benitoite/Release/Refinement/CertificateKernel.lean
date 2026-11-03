import Benitoite.Release.Refinement.CertificateData
import Benitoite.Release.Refinement.RefutationSound
import Benitoite.Release.Refinement.EqCertificate
import Benitoite.Release.Refinement.ConjunctionMeaning

/-! # 論理の導出や型付けに依存しない証明書の検査 -/
namespace Benitoite.Release.Refinement

def Certificate.check (Φ : List Pred) (goal : Pred) : Certificate → Bool
  | .use i => match Φ[i]? with | some p => predEq p goal | none => false
  | .leaf l => predEq l.predicate goal && l.checkRaw Φ
  | .substitute p t u eq c mode => predEq goal (p.open u) && eq.checkRaw Φ mode t u &&
      rewritePosition p mode && c.check Φ (p.open t)
  | .consume c => match Φ with
    | .and p q :: rest => c.check (p::q::rest) goal | _ => false
  | .cases l r => match Φ with
    | .or p q :: rest => l.check (p::rest) goal && r.check (q::rest) goal | _ => false
  | .discard c => match Φ with | _::rest => c.check rest goal | [] => false
  | .refute r =>
      let premise := Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)
      let keys := (Certificate.refute r).keys premise goal
      match normalize keys (.and premise (.not goal)) false with
      | some q => CertificateKernel.refute keys [q] [] r
      | none => false

theorem Certificate.sound_at {Φ : List Pred} {goal : Pred} {c : Certificate}
    (h : c.check Φ goal = true) (ν : ObservationEnv) (η : ObservationEnvModel)
    (facts : ∀ p ∈ Φ, (predBind ν p).interpret η = true) :
    (predBind ν goal).interpret η = true := by
  induction c generalizing Φ goal with
  | use i =>
    unfold check at h
    split at h
    · rename_i p hi
      rw [← (predEq_spec p goal).mp h]
      exact facts p (List.mem_of_getElem? hi)
    · cases h
  | leaf l =>
    simp only [check, Bool.and_eq_true] at h
    rw [← (predEq_spec l.predicate goal).mp h.1]
    exact PreparedLeaf.raw_sound_at h.2 ν η facts
  | substitute p t u eq c mode ih =>
    simp only [check, Bool.and_eq_true] at h
    rw [(predEq_spec goal (p.open u)).mp h.1.1.1]
    rw [← EqProof.substitute_sound_at h.1.1.2 h.1.2 ν η facts]
    exact ih h.2 facts
  | consume c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check, Bool.false_eq_true] at h
      rename_i p q
      apply ih h
      intro a ha
      have hh := facts (.and p q) List.mem_cons_self
      simp only [predBind, Pred.interpret, Bool.and_eq_true] at hh
      rcases List.mem_cons.mp ha with rfl | ha
      · exact hh.1
      rcases List.mem_cons.mp ha with rfl | ha
      · exact hh.2
      · exact facts a (List.mem_cons_of_mem _ ha)
  | cases l r ihl ihr =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check, Bool.false_eq_true] at h
      rename_i p q
      simp only [Bool.and_eq_true] at h
      have hh := facts (.or p q) List.mem_cons_self
      simp only [predBind, Pred.interpret, Bool.or_eq_true] at hh
      have extend (a : Pred) (ha : (predBind ν a).interpret η = true) :
          ∀ b ∈ a::rest, (predBind ν b).interpret η = true := by
        intro b hb
        rcases List.mem_cons.mp hb with rfl | hb
        · exact ha
        · exact facts b (List.mem_cons_of_mem _ hb)
      rcases hh with hp | hq
      · exact ihl h.1 (extend p hp)
      · exact ihr h.2 (extend q hq)
  | discard c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest => exact ih h (fun a ha => facts a (List.mem_cons_of_mem p ha))
  | refute r =>
    unfold check at h
    dsimp only at h
    split at h
    · rename_i q hn
      cases hg : (predBind ν goal).interpret η with
      | true => rfl
      | false =>
        have hp := (Pred.interpret_ofConjuncts_at (Φ.flatMap Pred.conjuncts) ν η).mpr (by
          intro p hp
          obtain ⟨a,ha,hp⟩ := List.mem_flatMap.mp hp
          exact (Pred.interpret_conjuncts_at a ν η).mp (facts a ha) p hp)
        have ha : (predBind ν (.and (Pred.ofConjuncts (Φ.flatMap Pred.conjuncts)) (.not goal))).interpret η = true := by
          simp only [predBind, Pred.interpret, hp, hg, Bool.not_false, Bool.and_self]
        have hq := (normalize_holds_at hn ν η).mpr ha
        exact False.elim (CertificateKernel.refute_sound_at h ν η (by
          intro a ha
          simp only [List.append_nil, List.mem_singleton] at ha
          subst a
          exact hq))
    · cases h

namespace CertificateKernel

def check (premise goal : Pred) (c : Certificate) : Bool := c.check premise.conjuncts goal

theorem implication_sound_at {p q : Pred} {c : Certificate} (h : check p q c = true) :
    ∀ (ν : ObservationEnv) (η : ObservationEnvModel),
      (predBind ν p).interpret η = true → (predBind ν q).interpret η = true := by
  intro ν η hp
  exact Certificate.sound_at h ν η ((Pred.interpret_conjuncts_at p ν η).mp hp)

theorem implication_sound {p q : Pred} {c : Certificate} (h : check p q c = true) :
    ∀ η : ObservationEnvModel, p.interpret η = true → q.interpret η = true := by
  intro η
  simpa only [predBind_id] using implication_sound_at h (fun i => some (.var i)) η

theorem check_sound {premise goal : Pred} {c : Certificate} (h : check premise goal c = true) :
    ∀ η : ObservationEnvModel, (Pred.and premise (.not goal)).interpret η ≠ true := by
  intro η ha
  simp only [Pred.interpret, Bool.and_eq_true] at ha
  have ht := implication_sound h η ha.1
  simp [ht] at ha

end CertificateKernel
end Benitoite.Release.Refinement
