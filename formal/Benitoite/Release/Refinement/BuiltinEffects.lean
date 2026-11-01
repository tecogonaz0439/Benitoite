import Benitoite.Release.Refinement.HandlerEffects

/-! # 組込みの宣言の効果による、実際の IO と PathBases の事象の被覆 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- ShapeOk は操作名の所属と、事象に対応する一原子の効果を与える。 -/
theorem Builtins.ShapeOk.operation {B : Builtins} {b : PrimName} {s : PrimSig} (h : B.ShapeOk b s) :
    ∃ l bs r, s.opEff = some l ∧ B.effects l = some bs ∧ b ∈ bs ∧
      s.eff = EffR.mk (fun a => decide (a = .name l r)) [] := by
  obtain ⟨l, bs, ho, hn, he, hb, hshape⟩ := h
  refine ⟨l, bs, ?_⟩
  cases hsh : s.shape <;> simp only [hsh] at hshape
  case untargeted => exact ⟨.fixed .top, ho, he, hb, hshape.2.2⟩
  case topTargeted k => exact ⟨.fixed .top, ho, he, hb, hshape.2.2⟩
  case single k p => exact ⟨.rvar 0, ho, he, hb, hshape.2.2.1⟩

/-- IO の宣言に書かれた効果は、その項目の実際の応答の事象を覆う。 -/
theorem Builtins.CoreAssumptions.io_event_covered {P B b s Γ Φ ws out obs}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s)
    (hk : s.kind = .io ∨ s.kind = .exit) :
    Event.Covered B Γ Φ s.eff (.io b ws out obs) := by
  obtain ⟨l, bs, r, ho, _, _, he⟩ := (h.io_op b s hs hk).operation
  exact ⟨s, l, r, hs, ho, by rw [he]; exact Eff.Covers.refl Γ Φ _⟩

/-- E_IO の同じ入力から、実際の遷移と宣言の効果による事象の被覆を得る。
継続の最終効果へ移す全状態の健全性は、この局所の補題には含まない。 -/
theorem Builtins.CoreAssumptions.io_transition_covered {P B σ q b s ts es rs ws k μ v obs Γ Φ}
    (h : Builtins.CoreAssumptions P B) (hv : q.view = .app (.prim b ts es rs) ws)
    (hs : B.sig b = some s) (hk : s.kind = .io) (hn : NoHandler k (.prim b))
    (hr : B.ioResponse b (Ty.normTys ts) (es.map Eff.norm) ws (.val v) obs) :
    Step P B σ (.run q k μ) (some (.io b ws (.val v) obs))
      (.run (Closure.pure (.ret v)) k μ) ∧
    Event.Covered B Γ Φ s.eff (.io b ws (.val v) obs) :=
  ⟨.E_IO hv hs hk hn hr, h.io_event_covered hs (Or.inl hk)⟩

/-- σ の発行も、宣言に書かれた効果で事象を覆う。 -/
theorem Builtins.CoreAssumptions.pathBases_event_covered {P B b s σ Γ Φ}
    (h : Builtins.CoreAssumptions P B) (hs : B.sig b = some s) (hk : s.kind = .pathBases) :
    Event.Covered B Γ Φ s.eff (.pathBases b σ) := by
  have he := (h.pathBases_shape b s hs hk).effect
  rw [Event.covered_pathBases, he]
  exact Eff.Covers.refl Γ Φ _

/-- E_IssuePathBases の同じ入力から、実際の遷移と事象の被覆を得る。 -/
theorem Builtins.CoreAssumptions.pathBases_transition_covered {P B σ q b s k μ Γ Φ}
    (h : Builtins.CoreAssumptions P B) (hv : q.view = .issuePathBases b)
    (hs : B.sig b = some s) (hk : s.kind = .pathBases) (hσ : σ.Valid) :
    Step P B σ (.run q k μ) (some (.pathBases b σ))
      (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
    Event.Covered B Γ Φ s.eff (.pathBases b σ) :=
  ⟨.E_IssuePathBases hv hs hk (h.pathBases_shape b s hs hk).operation hσ,
    h.pathBases_event_covered hs hk⟩

/-- 所属する操作の節がなければ、その効果全体は handled に入らない。 -/
theorem Program.EffectsOk.operation_not_handled {P B l bs b cs ix}
    (h : P.EffectsOk B) (he : B.effects l = some bs) (hb : b ∈ bs)
    (hn : handles cs (.prim b) = false) : ¬ (handled P B cs).mem (.name l ix) := by
  have hp : P.effects l = none := by
    cases hp : P.effects l with
    | none => rfl
    | some os => have hh := h.2.2 l os hp; rw [he] at hh; cases hh
  have hall : (bs.map OpRef.prim).all (handles cs) = false := by
    rw [Bool.eq_false_iff]
    intro ha
    rw [List.all_eq_true] at ha
    have hh := ha (.prim b) (List.mem_map.mpr ⟨b, hb, rfl⟩)
    rw [hn] at hh
    cases hh
  simp only [handled, effOps, hp, he, Option.map_some, Eff.mem, Eff.test, Eff.atoms]
  revert hall
  cases bs.map OpRef.prim <;> simp

/-- PathBasesShape の所属条件により、節のない発行の効果を消せない。 -/
theorem Builtins.CoreAssumptions.pathBases_not_handled {P B b s cs ix}
    (h : Builtins.CoreAssumptions P B) (hd : P.EffectsOk B)
    (hs : B.sig b = some s) (hk : s.kind = .pathBases)
    (hn : handles cs (.prim b) = false) :
    ¬ (handled P B cs).mem (.name processEnvironmentEff ix) := by
  obtain ⟨bs, he, hb⟩ := (h.pathBases_shape b s hs hk).membership
  exact hd.operation_not_handled he hb hn

end
end Benitoite.Release.Refinement
