import Benitoite.Release.Refinement.MainStatements
import Benitoite.Release.Refinement.Model

namespace Benitoite.Release.Refinement
noncomputable section
namespace EffectTrial

def issuesIn (B : Builtins) (l : EffName) : Bool :=
  match B.effects l with
  | some bs => bs.any fun b => match B.sig b with
      | some s => decide (s.kind = .pathBases)
      | none => false
  | none => false

def handledD (P : Program) (B : Builtins) (h : List Clause) : Eff :=
  .mk (fun a => match a with
    | .name l _ => match effOps P B l with
      | some (o :: os) => (o :: os).all (handles h) && !issuesIn B l
      | _ => false
    | .rho _ => false) []

/-- 発行を持つラベルは、どのプログラム・節・添字でも処理済みに含まれない。 -/
theorem never_handled {P B b s cs ix}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases) :
    ¬ (handledD P B cs).mem (.name processEnvironmentEff ix) := by
  obtain ⟨bs, he, hb⟩ := (h.pathBases_shape b s hs hk).membership
  have hi : issuesIn B processEnvironmentEff = true := by
    simp only [issuesIn, he]
    exact List.any_eq_true.mpr ⟨b, hb, by simp [hs, hk]⟩
  simp only [handledD, Eff.mem, Eff.test, Eff.atoms]
  cases effOps P B processEnvironmentEff with
  | none => simp
  | some os => cases os <;> simp [hi]

/-- 群 B の反例に使われた空の外側の効果への包含は、全ての節について成り立たない。 -/
theorem empty_handle_sub_rejected {P B b s cs}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases) :
    ¬ Eff.Sub (Eff.single processEnvironmentEff) (Eff.union Eff.empty (handledD P B cs)) := by
  intro sub
  have hm := sub.1 (.name processEnvironmentEff .top)
    (by simp [Eff.single, Eff.mem, Eff.test, Eff.atoms])
  rcases (Eff.mem_union_iff _ _ _).mp hm with hm | hm
  · simp [Eff.empty, Eff.mem, Eff.test, Eff.atoms] at hm
  · exact never_handled h hs hk hm

/-- 変更後の OpPrim の種類の条件は、発行の署名を全て断る。 -/
theorem pathBases_not_operation {s : PrimSig} (hk : s.kind = .pathBases) :
    ¬ (s.kind = .io ∨ s.kind = .exit) := by
  simp [hk]

#print axioms issuesIn
#print axioms handledD
#print axioms never_handled
#print axioms empty_handle_sub_rejected
#print axioms pathBases_not_operation

end EffectTrial
end
end Benitoite.Release.Refinement
