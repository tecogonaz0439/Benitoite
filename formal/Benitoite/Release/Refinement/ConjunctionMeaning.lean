import Benitoite.Release.Refinement.ClosedEvaluation
import Benitoite.Release.Refinement.Conjunction

/-! # 連言の列と同じ置換像での意味 -/
namespace Benitoite.Release.Refinement

theorem Pred.interpret_conjuncts (p : Pred) (η : ObservationEnvModel) :
    p.interpret η = true ↔ ∀ q ∈ p.conjuncts, q.interpret η = true := by
  induction p with
  | truth => simp [Pred.interpret,Pred.atomValue,Pred.conjuncts]
  | and p q ihp ihq => simp only [Pred.interpret,Bool.and_eq_true,Pred.conjuncts,
      List.mem_append,or_imp,forall_and,←ihp,←ihq]
  | _ => simp only [Pred.conjuncts,List.mem_singleton,forall_eq]

theorem Pred.interpret_conjuncts_at (p : Pred) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν p).interpret η = true ↔ ∀ q ∈ p.conjuncts, (predBind ν q).interpret η = true := by
  rw [Pred.interpret_conjuncts, Pred.conjuncts_bind]
  simp only [List.mem_map, forall_exists_index, and_imp]
  constructor
  · intro h q hq; exact h _ q hq rfl
  · intro h q a ha he; subst q; exact h a ha

theorem Pred.interpret_ofConjuncts_at (ps : List Pred) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (Pred.ofConjuncts ps)).interpret η = true ↔
      ∀ p ∈ ps, (predBind ν p).interpret η = true := by
  induction ps with
  | nil => simp [Pred.ofConjuncts, predBind, Pred.interpret, Pred.atomValue]
  | cons p ps ih =>
    cases ps with
    | nil => simp [Pred.ofConjuncts]
    | cons q qs =>
      simp only [Pred.ofConjuncts, predBind, Pred.interpret, Bool.and_eq_true] at ih ⊢
      rw [ih]
      simp only [List.mem_cons, forall_eq_or_imp]

theorem Pred.conjuncts_ofConjuncts_flat (ps : List Pred) :
    (Pred.ofConjuncts ps).conjuncts = ps.flatMap Pred.conjuncts := by
  induction ps with
  | nil => rfl
  | cons p ps ih =>
    cases ps with
    | nil => simp only [Pred.ofConjuncts, List.flatMap_cons, List.flatMap_nil, List.append_nil]
    | cons q qs => simpa only [Pred.ofConjuncts, Pred.conjuncts, List.flatMap_cons] using congrArg (p.conjuncts ++ ·) ih

theorem Pred.conjuncts_flat_idem (ps : List Pred) :
    (ps.flatMap Pred.conjuncts).flatMap Pred.conjuncts = ps.flatMap Pred.conjuncts := by
  induction ps with
  | nil => rfl
  | cons p ps ih =>
    simp only [List.flatMap_cons, List.flatMap_append, ih]
    congr 1
    have h := Pred.conjuncts_atoms p
    generalize p.conjuncts = qs at h ⊢
    induction qs with
    | nil => rfl
    | cons q qs ih =>
      simp only [List.flatMap_cons]
      rw [Pred.conjuncts_atom (h q List.mem_cons_self)]
      simp only [List.singleton_append]
      congr 1
      exact ih (fun a ha => h a (List.mem_cons_of_mem _ ha))

end Benitoite.Release.Refinement
