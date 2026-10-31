import Lean
import Benitoite.Release.Refinement.LazyPreservation
import Benitoite.Release.Refinement.LogicSound

/-! 共変性の向きと重複の確認。 -/
namespace Benitoite.Release.Refinement
noncomputable section

abbrev I : Ty := .base .integer
abbrev p : Pred := .lt (.var 0) (.integer 8)
abbrev Small : Ty := .refined I p

/-- 矛盾した Φ の下では Lazy の契約を強められる。 -/
theorem lazy_le_under_false : Ty.LeQ [] [.falsity] (.lazy I) (.lazy Small) := by
  refine .lazy (.introduce ?_ (.false_elim (.hyp ?_)))
  · simp [Pred.Sorted,Term.HasSort,Term.References,Term.Shape,Term.VarsIn,Ctx.Readable,
      Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
  · simp [assumptions,Ctx.facts,Pred.lift,predBind]

/-- その Φ は実行時の捕捉になれない。 -/
theorem capture_rejects_false {P B Ψ R Γ cap} : ¬ CaptureOk P B Ψ R Γ [.falsity] cap := by
  intro h
  have he := h.conditions .falsity (List.mem_append_right _ List.mem_cons_self)
  have hs := he.sound (fun _ => none) (by intro q hq; cases hq)
  change false = true at hs
  cases hs

/-- 新しい公開補題 return_const は、より弱い仮定の既存の補題から直ちに従う。 -/
theorem return_const_is_existing {P B Ψ R q a e c}
    (hA : Builtins.CoreAssumptions P B) (hw : Ψ.WF)
    (h : ClosureTy P B Ψ [] R q a e) (hv : q.view = .ret (.const c)) :
    HasTypeV P B Ψ [] [] [] (.const c) a :=
  h.ret_const hA.substitutions hw hv

/-- error/exit が update を降ろす遷移は、現在のセルと無関係に閉じる。 -/
theorem update_pop_error {P B σ Eb rs l k μ}
    (h : StateTyE P B σ Eb (.error rs (.update l :: k) μ)) :
    Step P B σ (.error rs (.update l :: k) μ) none (.error rs k μ) ∧
    StateTyE P B σ Eb (.error rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
  obtain ⟨_,x,R',_,_,hk'⟩ := hk.update_inv
  exact ⟨.E_ErrPopUpdate,Ψ,R',x,b,e,hs,hk',fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμ⟩

theorem update_pop_exit {P B σ Eb n rs l k μ}
    (h : StateTyE P B σ Eb (.exit n rs (.update l :: k) μ)) :
    Step P B σ (.exit n rs (.update l :: k) μ) none (.exit n rs k μ) ∧
    StateTyE P B σ Eb (.exit n rs k μ) := by
  obtain ⟨Ψ,R,a,b,e,hs,hk,hkc,hμ⟩ := h
  obtain ⟨_,x,R',_,_,hk'⟩ := hk.update_inv
  exact ⟨.E_ExitPopUpdate,Ψ,R',x,b,e,hs,hk',fun f hf => hkc f (List.mem_cons_of_mem _ hf),hμ⟩

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.capture_rejects_false
#print axioms Benitoite.Release.Refinement.update_pop_exit
