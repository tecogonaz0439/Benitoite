import Benitoite

-- 匿名の証拠を検査する。定義・補題・新しい公開名は追加しない。
-- formal/ から lake env lean -M 12288 で実行する。
open Benitoite.Release.Refinement

-- 現行の Transport は List の位置の像を制約しない。
-- 長さの観測をまだ追加していない、現在の契約についての証拠である。
#check (show ∀ t : Term,
    Transport ⟨Ty.tvar, [], [], fun _ => t⟩
      [some (.list (.base .integer))] [] [] [] from by
  intro t
  constructor
  · intro i a hi ha
    cases i with
    | zero =>
      simp only [List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      exact False.elim ha
    | succ i => simp at hi
  · intro p hp
    simp [Ctx.facts, Ty.assume] at hp)

#check Transport.values
#check Pred.sorted_bind
#check Ty.LeQ.bind
#check Program.mk
#check Builtins.mk

#print axioms Benitoite.Release.Refinement.Transport
#print axioms Benitoite.Release.Refinement.Pred.sorted_bind
#print axioms Benitoite.Release.Refinement.Ty.LeQ.bind
#print axioms Benitoite.Release.Refinement.Ty.LeQ.rawBind
#print axioms Benitoite.Release.Refinement.Ty.WF
#print axioms Benitoite.Release.Refinement.HasTypeVQ.subst
#print axioms Benitoite.Release.Refinement.HasTypeCQ.subst
#print axioms Benitoite.Release.Refinement.embed_wf
#print axioms Benitoite.Release.Model.assumptions
#print axioms Benitoite.Release.ModelTargets.assumptions
#print axioms Benitoite.Release.ModelHttp.assumptions
#print axioms Benitoite.Release.Ty.le_iff_leOld
#print axioms Benitoite.Release.Ty.wf_iff_old
#print axioms Benitoite.Release.Ty.varsIn_iff_old
#print axioms Benitoite.Release.Eff.covers_iff_sub_old
