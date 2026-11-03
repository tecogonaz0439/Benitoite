import Benitoite.Release.Refinement.PreparedLeafSyntax
import Benitoite.Release.Refinement.CertificateKernelBind
import Benitoite.Release.Refinement.MeasureNonnegative

/-! # 登録済みの有限な論理補題の意味

設計書01-12「閉じた述語の評価と捕捉」に対応する。
閉じた評価の成功と、任意の置換像で成立する一般則を区別する。
-/
namespace Benitoite.Release.Refinement

theorem Pred.closedTrue_sound_at {p : Pred} (h : p.closedTrue = true)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true := by
  have he : p.evalClosed = some true := by simpa [Pred.closedTrue] using h
  have hw : p.WF 0 ∧ p.Sorted [] none := by
    unfold Pred.evalClosed at he
    split at he
    · assumption
    · cases he
  exact Pred.closed_sound_at hw.1 hw.2 he ν η

theorem measure_nonnegative_at (m : Measure) (t : Term)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.le (.integer 0) (.measure m t))).interpret η = true := by
  simp only [predBind, Pred.interpret, Pred.atomValue, decide_eq_true_eq,
    termBind_integer, termBind_measure, integerAs_eq_integerD, Term.interpret,
    Observation.integerD]
  cases ht : (termBind ν t).interpret η with
  | none => simp
  | some o =>
    cases hm : o.measure m with
    | none => simp [hm]
    | some v =>
      cases v <;> simp [hm]
      exact Observation.measure_nonnegative hm

theorem observeAs_sort (η : ObservationEnvModel) (s : «Sort») (t : Term) :
    (observeAs η s t).sort = s := by
  have hd : (Observation.default s).sort = s := by
    cases s <;> try rfl
    rename_i k
    cases k <;> rfl
  unfold observeAs
  cases t.interpret η with
  | none => exact hd
  | some o =>
    simp only
    split
    · assumption
    · exact hd

theorem boolean_apart_at (t : Term) (b : Bool)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.not (.and (.compare .boolean .eq t (.boolean b))
      (.compare .boolean .eq t (.boolean (!b)))))).interpret η = true := by
  have hs := observeAs_sort η .boolean (termBind ν t)
  simp only [predBind, Pred.interpret, Pred.atomValue]
  cases ho : observeAs η .boolean (termBind ν t) <;>
    simp only [ho, Observation.sort] at hs <;> try contradiction
  rename_i v
  cases v <;> cases b <;> rfl

theorem characterCode_projection (t : Term) (η : ObservationEnvModel) :
    integerAs η (.measure .characterCode t) =
      match observeAs η .character t with | .character c => (c.toNat : Int) | _ => 0 := by
  simp only [integerAs_eq_integerD, Term.interpret, observeAs]
  cases ht : t.interpret η with
  | none => rfl
  | some o => cases o <;> rfl

theorem characters_subset_at (t : Term) (lo hi lo' hi' : Char)
    (hl : lo'.toNat ≤ lo.toNat) (hh : hi.toNat ≤ hi'.toNat)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.charactersIn t lo hi)).interpret η = true →
      (predBind ν (.charactersIn t lo' hi')).interpret η = true := by
  have hs := observeAs_sort η .string (termBind ν t)
  simp only [predBind, Pred.interpret, Pred.atomValue]
  cases ho : observeAs η .string (termBind ν t) <;>
    simp only [ho, Observation.sort, reduceCtorEq] at hs <;> try contradiction
  rename_i s
  simp only [List.all_eq_true, decide_eq_true_eq]
  intro h c hc
  have := h c hc
  omega

theorem constructor_apart_at (t : Term) (c d : ConName) (hd : c ≠ d)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (.not (.and (.constructorIs t c) (.constructorIs t d)))).interpret η = true := by
  have hs := observeAs_sort η .data (termBind ν t)
  simp only [predBind, Pred.interpret, Pred.atomValue]
  cases ho : observeAs η .data (termBind ν t) <;>
    simp only [ho, Observation.sort, reduceCtorEq] at hs <;> try contradiction
  rename_i tag fields
  simp
  apply Classical.byContradiction
  intro h
  simp only [not_or, Classical.not_not] at h
  exact hd (h.1.symm.trans h.2)

theorem character_code_range_at (t : Term) (ν : ObservationEnv) (η : ObservationEnvModel) :
    let n := integerAs η (termBind ν (.measure .characterCode t))
    0 ≤ n ∧ n ≤ 1114111 ∧ (n < 55296 ∨ 57343 < n) := by
  dsimp only
  simp only [termBind_measure, characterCode_projection]
  have hs := observeAs_sort η .character (termBind ν t)
  cases ho : observeAs η .character (termBind ν t) <;>
    simp only [ho, Observation.sort, reduceCtorEq] at hs <;> try contradiction
  rename_i c
  have hc := c.valid
  simp only [UInt32.isValidChar, Nat.isValidChar] at hc
  change 0 ≤ (c.val.toNat : Int) ∧ (c.val.toNat : Int) ≤ 1114111 ∧
    ((c.val.toNat : Int) < 55296 ∨ 57343 < (c.val.toNat : Int))
  omega

end Benitoite.Release.Refinement
