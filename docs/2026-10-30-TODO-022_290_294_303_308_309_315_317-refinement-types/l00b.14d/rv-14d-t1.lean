import Lean
import Benitoite.Release.Refinement.LazyPreservation

/-! done のセルへの外側の書戻し。不足は格納の契約の Sorted だけであることを確かめる。 -/
namespace Benitoite.Release.Refinement
noncomputable section

open Lean Elab Command in
run_cmd liftCoreM do
  for n in [`normal_return_tail,`cont_return_annotation,`pure_ret,`closed_set,`closure_normal,`empty_sub,`empty_annotation] do
    let full := `Benitoite.Release.Refinement ++ n
    let priv := mkPrivateNameCore `Benitoite.Release.Refinement.LazyPreservation full
    let some ci := (← getEnv).find? priv | throwError "missing {priv}"
    let d : TheoremVal := { name := full, levelParams := ci.levelParams, type := ci.type, value := .const priv (ci.levelParams.map Level.param) }
    addDecl (.thmDecl d)

/-- 現在のセルを限定しない形。`hS` だけが追加の入力である（thunk の場合は導ける）。 -/
theorem update_any_cell_of_sorted {P B σ Eb v l k μ}
    (hA : Builtins.CoreAssumptions P B)
    (h : StateTyE P B σ Eb (.run (Closure.pure (.ret v)) (.update l :: k) μ))
    (hS : ∀ Ψ x, StoreOk P B σ Ψ μ → Ψ l = some (.lazy x) → x.Sorted [])
    (hc : closeVal Capture.empty v = v) :
    Step P B σ (.run (Closure.pure (.ret v)) (.update l :: k) μ) none
      (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) ∧
    StateTyE P B σ Eb (.run (Closure.pure (.ret v)) k (μ.set l (.done v))) := by
  obtain ⟨Ψ,R,a,c,ε,e,hsμ,hq,he,hcont,had,hclosed,hkc,hμc⟩ := h
  obtain ⟨rfl,x,R',hl,hle,hk⟩ := hcont.update_inv
  have hv := pure_ret hA.values hsμ.wf hq
  have han := hq.annotation
  have ha : Ty.Annotation P [] [] a := ⟨han.wf.1,han.sorted.1,han.declared.1⟩
  have hn := closure_normal hq
  have hvx : HasTypeV P B Ψ [] [] [] v x :=
    .V_Sub hv hle (hsμ.wf l _ hl) (hS Ψ x hsμ hl) (hsμ.lazy_declared hl)
  have hs' := hsμ.write_done hl hvx had.2
  obtain ⟨R'',hRn,hk'⟩ := normal_return_tail hk rfl a ha hn hle
  have hr := cont_return_annotation hk' rfl
  have hq' := ClosureTy.pure (.C_Return (R := R'') hv) (empty_annotation ha)
    (fun r hh => ⟨(hr r hh).wf,(hr r hh).declared⟩) hn hRn
  exact ⟨.E_Update (by change Comp.ret (closeVal Capture.empty v) = _; rw [hc]),
    Ψ,R'',a,c,ε,Eff.empty,hs',hq',empty_sub ε,hk',had,hclosed,
    (fun f hf => hkc f (List.mem_cons_of_mem _ hf)),closed_set hμc hclosed.2⟩

/-- 上書きの後も、別に保持した先の値の型付けは同じ Ψ のまま変わらない。 -/
theorem overwrite_keeps_held {P B σ Ψ μ l a w v h t}
    (hs : StoreOk P B σ Ψ μ) (hl : Ψ l = some (.lazy a))
    (hw : μ l = some (.done w))
    (hv : HasTypeV P B Ψ [] [] [] v a) (ha : v.Adequate σ)
    (hh : HasTypeV P B Ψ [] [] [] h t) :
    (∃ a', CellOk P B σ Ψ l (.done w) ∧ Ψ l = some (.lazy a')) ∧
    StoreOk P B σ Ψ (μ.set l (.done v)) ∧ HasTypeV P B Ψ [] [] [] h t :=
  ⟨⟨a,hs.2.2.2.2 l _ hw,hl⟩,hs.write_done hl hv ha,hh⟩

end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.update_any_cell_of_sorted
