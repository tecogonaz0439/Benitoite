import Benitoite.Release.Lemmas.Progress

/-!
# エフェクトの健全性（段階 B）

継続の末尾で許すエフェクト Eb が空の状態は、事象を伴う遷移をせず、どの `handle` の枠も処理しない操作を
呼ばない。保存の定理は Eb を変えないので、`⟨M, [], ∅⟩` から到達するどの状態でも Eb は空である。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

theorem builtinOnly_empty : BuiltinOnly P B Eff.empty := fun a h => by simp [Eff.empty] at h

/-- 組み込みのエフェクト L の操作 op を処理する `handle` の枠が継続にないとき、ε が L を含めば、継続の末尾も
L を許す。 -/
theorem ContTy.end_of_noHandler (hdecl : P.EffectsOk B) {Ψ R ε k a b Eb Re l bs b0}
    (hk : ContTy P B Ψ R ε k a b Eb Re) (hbs : B.effects l = some bs) (hb0 : b0 ∈ bs)
    (hε : ε (.name l) = true) (hno : NoHandler k (.prim b0)) : Eb (.name l) = true := by
  have hPl : P.effects l = none := by
    cases e : P.effects l with
    | none => rfl
    | some os => rw [hdecl.2.2 l os e] at hbs; cases hbs
  refine hk.name_end hε (fun hs hin => ?_)
  have hh := hno hs hin
  have hall : (bs.map OpRef.prim).all (handles hs) = false := by
    rw [Bool.eq_false_iff]; intro h
    rw [List.all_eq_true] at h
    have := h (.prim b0) (List.mem_map.mpr ⟨b0, hb0, rfl⟩)
    rw [hh] at this; cases this
  simp only [handled, effOps, hPl, hbs, Option.map_some]
  revert hall
  cases bs.map OpRef.prim <;> simp

/-- 継続の末尾で許すエフェクトが空の状態は、事象を伴う遷移をしない。 -/
theorem no_event (hdecl : P.EffectsOk B) (hb : B.Assumptions P) {s : State}
    (hs : StateTyE P B Eff.empty s) : ∀ ev s', ¬ Step P B s (some ev) s' := by
  intro ev s' hst
  -- 解放の枠：`State` を含むエフェクトの継続は、末尾でも `State` を許す。
  have hrel : ∀ {Ψ R ε v k a b}, ContTy P B Ψ R ε (.release v :: k) a b Eff.empty none → False := by
    intro Ψ R ε v k a b hk
    obtain ⟨_, _, _, hst, _⟩ := hk.inv_release
    have := hk.state_end hdecl hb hst
    simp [Eff.empty] at this
  -- IO：`handle` の枠がなければ、継続の末尾が組み込みのエフェクトを許す。
  have hio : ∀ {Ψ R a ε1 ε b' b0 ts es ws k s0}, HasTypeC P B Ψ [] [] R (.app (.prim b0 ts es) ws) a ε1 →
      Eff.Sub ε1 ε → ContTy P B Ψ R ε k a b' Eff.empty none → B.sig b0 = some s0 →
      (s0.kind = .io ∨ s0.kind = .exit) → NoHandler k (.prim b0) → False := by
    intro Ψ R a ε1 ε b' b0 ts es ws k s0 hm hε hk hsig hkd hno
    obtain ⟨s', hs', _, _, _, _, _, hsub⟩ := inv_prim_app hm
    rw [hsig] at hs'; cases hs'
    obtain ⟨l, bs, _, heff, _, hbs, hb0⟩ := hb.io_op b0 _ hsig hkd
    have hl : ε (.name l) = true := by
      apply hε; apply hsub; rw [heff]; apply Eff.substRho_name; simp [Eff.single]
    have := hk.end_of_noHandler hdecl hbs hb0 hl hno
    simp [Eff.empty] at this
  cases hst with
  | E_IO hsig hkd hno _ =>
      obtain ⟨_, _, _, _, _, _, _, hm, hε, hk, _⟩ := hs
      exact hio hm hε hk hsig (Or.inl hkd) hno
  | E_IOErr hsig hkd hno _ =>
      obtain ⟨_, _, _, _, _, _, _, hm, hε, hk, _⟩ := hs
      exact hio hm hε hk hsig hkd hno
  | E_Exit hsig hkd hno _ =>
      obtain ⟨_, _, _, _, _, _, _, hm, hε, hk, _⟩ := hs
      exact hio hm hε hk hsig (Or.inr hkd) hno
  | E_Release => obtain ⟨_, _, _, _, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_RelErr => obtain ⟨_, _, _, _, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_EscRel => obtain ⟨_, _, _, _, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_EscRelErr => obtain ⟨_, _, _, _, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_ErrRel => obtain ⟨_, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_ErrRelErr => obtain ⟨_, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_ExitRel => obtain ⟨_, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk
  | E_ExitRelErr => obtain ⟨_, _, _, _, _, _, hk, _⟩ := hs; exact hrel hk

/-- 型の付いた状態は、どの `handle` の枠も処理しない利用者の操作を呼ばない。 -/
theorem no_unhandledOp (hdecl : P.EffectsOk B) {Eb : Eff} {s : State} (hs : StateTyE P B Eb s)
    (hEb : BuiltinOnly P B Eb) : ¬ UnhandledOp s := by
  intro hu
  cases s with
  | run m k σ =>
      cases m with
      | app f ws =>
          cases f with
          | op o ts =>
              obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, _⟩ := hs
              obtain ⟨od, hod, _, _, _, hsub⟩ := inv_op_app hm
              refine no_unhandled_user hdecl hk hEb hod ?_ hu
              apply hε; apply hsub
              rw [Eff.substRho_nil]
              simp [Eff.single]
          | _ => exact (show False from hu)
      | _ => exact (show False from hu)
  | _ => exact (show False from hu)

/-- 実行を始める状態の型付け。 -/
theorem stateTyE_init (hwf : P.WellFormed) (hb : B.Assumptions P) {m : Comp} {a : Ty}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a Eff.empty) (hc : m.ClosedNoEffVars) :
    StateTyE P B Eff.empty (.run m [] Store.empty) := by
  have hmc : Comp.VarsIn 0 (fun _ => True) m := Comp.VarsIn.toTrue m hc
  have hΨ : StoreTy.WF StoreTy.empty := fun l x h => by simp [StoreTy.empty] at h
  have hw : Ty.WF 0 a := HasTypeC.wf hwf hb hm (envWF_nil 0) hΨ hmc
  refine ⟨StoreTy.empty, none, a, a, Eff.empty, Eff.empty, ?_, hm, Eff.Sub.refl _,
    .K_Empty (Eff.Sub.refl _) hw, hmc, fun f hf => by simp at hf, fun l c h => by simp [Store.empty] at h⟩
  refine ⟨⟨0, fun l _ => rfl⟩, fun l x h => ?_, fun l x h => ?_, fun l c h => ?_⟩ <;>
    simp [StoreTy.empty, Store.empty] at h

theorem steps_preserve (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.Assumptions P) {Eb : Eff} {s s' : State} (hsteps : Steps P B s s') (hs : StateTyE P B Eb s) :
    StateTyE P B Eb s' := by
  induction hsteps with
  | refl => exact hs
  | step hst _ ih => exact ih (preservationE hwf hwt hdecl hb hs hst)

end Benitoite.Release
