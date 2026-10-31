import Benitoite.Release.Refinement.TermSyntax

/-! # 順序と重複を保つ連言の正規形 -/
namespace Benitoite.Release.Refinement

def Pred.conjuncts : Pred → List Pred
  | .truth => []
  | .and p q => p.conjuncts ++ q.conjuncts
  | p => [p]

def Pred.ofConjuncts : List Pred → Pred
  | [] => .truth
  | [p] => p
  | p :: q :: ps => .and p (Pred.ofConjuncts (q :: ps))

def Pred.conjNorm (p : Pred) : Pred := Pred.ofConjuncts p.conjuncts

def Pred.ConjAtom : Pred → Prop
  | .truth | .and _ _ => False
  | _ => True

theorem Pred.conjuncts_atom {p : Pred} (h : p.ConjAtom) : p.conjuncts = [p] := by
  cases p <;> first | rfl | cases h

theorem Pred.conjuncts_atoms (p : Pred) : ∀ q ∈ p.conjuncts, q.ConjAtom := by
  cases p with
  | and p q =>
    intro r hr
    rcases List.mem_append.mp hr with hr | hr
    · exact Pred.conjuncts_atoms p r hr
    · exact Pred.conjuncts_atoms q r hr
  | truth => intro q h; cases h
  | _ => intro q h; cases List.mem_singleton.mp h; trivial

theorem Pred.conjuncts_ofConjuncts {ps : List Pred} (h : ∀ p ∈ ps, p.ConjAtom) :
    (Pred.ofConjuncts ps).conjuncts = ps := by
  induction ps with
  | nil => rfl
  | cons p ps ih =>
    cases ps with
    | nil => exact Pred.conjuncts_atom (h p List.mem_cons_self)
    | cons q qs =>
      simp only [Pred.ofConjuncts, Pred.conjuncts, Pred.conjuncts_atom (h p List.mem_cons_self)]
      rw [ih (fun r hr => h r (List.mem_cons_of_mem p hr))]
      rfl

theorem Pred.conjuncts_conjNorm (p : Pred) : p.conjNorm.conjuncts = p.conjuncts :=
  Pred.conjuncts_ofConjuncts (Pred.conjuncts_atoms p)

theorem Pred.conjNorm_idem (p : Pred) : p.conjNorm.conjNorm = p.conjNorm := by
  change Pred.ofConjuncts p.conjNorm.conjuncts = _
  rw [Pred.conjuncts_conjNorm]
  rfl

theorem Pred.conjuncts_bind (ν : ObservationEnv) (p : Pred) :
    (predBind ν p).conjuncts = p.conjuncts.map (predBind ν) := by
  cases p <;> simp only [predBind, Pred.conjuncts, List.map_nil, List.map_cons,
    List.map_append, Pred.conjuncts_bind]

theorem Pred.ofConjuncts_bind (ν : ObservationEnv) (ps : List Pred) :
    predBind ν (Pred.ofConjuncts ps) = Pred.ofConjuncts (ps.map (predBind ν)) := by
  induction ps with
  | nil => rfl
  | cons p ps ih => cases ps <;> simp_all only [Pred.ofConjuncts, predBind, List.map_cons, List.map_nil]

theorem Pred.conjNorm_bind (ν : ObservationEnv) (p : Pred) :
    (predBind ν p).conjNorm = predBind ν p.conjNorm := by
  simp only [Pred.conjNorm, Pred.conjuncts_bind, Pred.ofConjuncts_bind]

theorem Pred.ofConjuncts_eq_truth_iff {ps : List Pred} (h : ∀ p ∈ ps, p.ConjAtom) :
    Pred.ofConjuncts ps = .truth ↔ ps = [] := by
  constructor
  · intro he
    have hh := congrArg Pred.conjuncts he
    rwa [Pred.conjuncts_ofConjuncts h] at hh
  · rintro rfl; rfl

end Benitoite.Release.Refinement
