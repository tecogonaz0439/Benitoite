import Benitoite.Release.Refinement.NormalizationLogic
import Benitoite.Release.Refinement.EqProofTransport

/-! # 検査済みの有限証明書から構文の導出への接続 -/
namespace Benitoite.Release.Refinement

private theorem premise_entails (Φ : List Pred) : Entails Φ (Pred.ofConjuncts Φ) := by
  apply Entails.of_conjuncts
  intro p hp
  rw [Pred.conjuncts_ofConjuncts_flat] at hp
  obtain ⟨a,ha,hp⟩ := List.mem_flatMap.mp hp
  exact (Entails.hyp ha).conjuncts p hp

private theorem substitute_atomic {Φ : List Pred} {p : Pred} {t u : Term} {eq : EqProof}
    {mode : EqualityMode} (ha : (p.open t).conjuncts = [p.open t])
    (he : eq.checkRaw Φ mode t u = true) (hr : rewritePosition p mode = true)
    (source : Entails Φ (p.open t)) : Entails Φ (p.open u) := by
  let premise := Pred.and (Pred.ofConjuncts Φ) (p.open t)
  have hm (a b : Term) (h : Pred.eq a b ∈ Φ) : Pred.eq a b ∈ premise.conjuncts := by
    apply List.mem_append_left
    rw [Pred.conjuncts_ofConjuncts_flat]
    exact List.mem_flatMap.mpr ⟨.eq a b, h, List.mem_cons_self⟩
  obtain ⟨d, hd⟩ := EqProof.recontextualize he hm
  have hs : p.open t ∈ premise.conjuncts := by
    apply List.mem_append_right
    rw [ha]
    exact List.mem_cons_self
  obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hs
  have hc : CertificateKernel.check premise (p.open u)
      (.substitute p t u d (.use i) mode) = true := by
    simp only [CertificateKernel.check, Certificate.check, Bool.and_eq_true, predEq_spec]
    exact ⟨⟨⟨trivial, hd⟩, hr⟩, by simp only [hi, predEq_spec]⟩
  apply Entails.checked hc
  exact .and_intro (premise_entails Φ) source

theorem EqProof.substitute_entails {Φ : List Pred} {p : Pred} {t u : Term} {eq : EqProof}
    {mode : EqualityMode} (he : eq.checkRaw Φ mode t u = true)
    (hr : rewritePosition p mode = true) (source : Entails Φ (p.open t)) :
    Entails Φ (p.open u) := by
  cases mode with
  | structural =>
    have htu := EqProof.structural_sound he
    rw [← htu]
    exact source
  | integer =>
    induction p with
    | truth => exact .truth
    | and p q ihp ihq =>
      have hh := (rewritePosition_spec (.and p q) .integer).mp hr
      exact .and_intro
        (ihp (.and_left source) ((rewritePosition_spec p .integer).mpr hh.1))
        (ihq (.and_right source) ((rewritePosition_spec q .integer).mpr hh.2))
    | _ => exact substitute_atomic rfl he hr source

theorem PreparedLeaf.raw_entails {Φ : List Pred} {l : PreparedLeaf}
    (h : l.checkRaw Φ = true) : Entails Φ l.predicate := by
  by_cases he : l.lemma = .sameObservation
  · cases hr : l.references with
    | nil =>
      have hc : CertificateKernel.check .truth l.predicate (.leaf l) = true := by
        simp only [CertificateKernel.check, Pred.conjuncts, Certificate.check, Bool.and_eq_true, predEq_spec]
        exact ⟨trivial, by simpa only [PreparedLeaf.checkRaw, he, hr] using h⟩
      exact Entails.checked hc .truth
    | cons i rest =>
      cases rest with
      | nil =>
        simp only [PreparedLeaf.checkRaw, he, hr] at h
        split at h
        · rename_i p t u hi hargs
          simp only [Bool.and_eq_true] at h
          rw [← (predEq_spec p l.predicate).mp h.1.2]
          exact .hyp (List.mem_of_getElem? hi)
        · cases h
      | cons j rest => simp [PreparedLeaf.checkRaw, he, hr] at h
  · have hc : CertificateKernel.check .truth l.predicate (.leaf l) = true := by
      simp only [CertificateKernel.check, Pred.conjuncts, Certificate.check, Bool.and_eq_true, predEq_spec]
      refine ⟨trivial, ?_⟩
      cases hl : l.lemma <;> simp_all [PreparedLeaf.checkRaw]
    exact Entails.checked hc .truth

theorem Certificate.refutation_entails {Φ : List Pred} {goal : Pred} {c : Certificate}
    (h : CertificateKernel.check (Pred.ofConjuncts Φ) goal c = true) : Entails Φ goal := by
  apply Entails.checked h
  exact premise_entails Φ

theorem Certificate.sound {Φ : List Pred} {goal : Pred} {c : Certificate}
    (h : c.check Φ goal = true) : Entails Φ goal := by
  induction c generalizing Φ goal with
  | use i =>
    unfold check at h
    split at h
    · rename_i p hi
      rw [← (predEq_spec p goal).mp h]
      exact .hyp (List.mem_of_getElem? hi)
    · cases h
  | leaf l =>
    simp only [check, Bool.and_eq_true] at h
    rw [← (predEq_spec l.predicate goal).mp h.1]
    exact PreparedLeaf.raw_entails h.2
  | substitute p t u eq c mode ih =>
    simp only [check, Bool.and_eq_true] at h
    rw [(predEq_spec goal (p.open u)).mp h.1.1.1]
    exact EqProof.substitute_entails h.1.1.2 h.1.2 (ih h.2)
  | consume c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check,Bool.false_eq_true] at h
      rename_i p q
      apply (ih h).cut
      intro r hr
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .and_left (q := q) (.hyp List.mem_cons_self)
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .and_right (p := p) (.hyp List.mem_cons_self)
      · exact .hyp (List.mem_cons_of_mem _ hr)
  | cases l r ihl ihr =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check,Bool.false_eq_true] at h
      rename_i p q
      simp only [Bool.and_eq_true] at h
      apply Entails.or_elim (p := p) (q := q) (.hyp List.mem_cons_self)
      · exact (ihl h.1).weaken (by intro t ht; rcases List.mem_cons.mp ht with rfl | ht; exact List.mem_cons_self; exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ ht))
      · exact (ihr h.2).weaken (by intro t ht; rcases List.mem_cons.mp ht with rfl | ht; exact List.mem_cons_self; exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ ht))
  | discard c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest => exact (ih h).weaken (fun _ ht => List.mem_cons_of_mem _ ht)
  | refute r =>
    apply Certificate.refutation_entails (c := .refute r)
    simpa only [CertificateKernel.check, check, Pred.conjuncts_ofConjuncts_flat,
      Pred.conjuncts_flat_idem] using h

end Benitoite.Release.Refinement
