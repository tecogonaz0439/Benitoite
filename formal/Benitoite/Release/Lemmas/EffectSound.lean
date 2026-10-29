import Benitoite.Release.Lemmas.Progress
import Benitoite.Release.Lemmas.Names

/-!
# エフェクトの健全性（契約名を持つコア）

継続の末尾で許すエフェクト Eb が空の状態は、事象を伴う遷移をせず、どの `handle` の枠も処理しない操作を
呼ばない。保存の定理は Eb を変えないので、`⟨M, [], ∅⟩` から到達するどの状態でも Eb は空である。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

theorem builtinOnly_empty : BuiltinOnly P B Eff.empty :=
  ⟨rfl, fun a h => by simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at h⟩

/-- 組み込みのエフェクト L の操作 op を処理する `handle` の枠が継続にないとき、ε が L を含めば、継続の末尾も
L を許す。 -/
theorem ContTy.end_of_noHandler (hdecl : P.EffectsOk B) {Ψ R ε k a b Eb Re l bs b0}
    (hk : ContTy P B Ψ R ε k a b Eb Re) (hbs : B.effects l = some bs) (hb0 : b0 ∈ bs)
    (hε : Eff.mem ε (.nameTop l)) (hno : NoHandler k (.prim b0)) : Eff.mem Eb (.nameTop l) := by
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
  simp only [Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps, hPl, hbs, Option.map_some]
  revert hall
  cases bs.map OpRef.prim <;> simp

/-- `ContTy.end_of_noHandler` の範囲付きの版。組み込みのエフェクト L の操作 op を処理する `handle` の枠が継続に
ないとき、ε が範囲の位置 r の L の原子を含めば、継続の末尾もそれを覆う L の原子を含む（`ContTy.name_end_ix`）。 -/
theorem ContTy.end_of_noHandler_ix (hdecl : P.EffectsOk B) {Ψ R ε k a b Eb Re l r bs b0}
    (hk : ContTy P B Ψ R ε k a b Eb Re) (hbs : B.effects l = some bs) (hb0 : b0 ∈ bs)
    (hε : Eff.mem ε (.name l r)) (hno : NoHandler k (.prim b0)) :
    ∃ r', Eff.mem Eb (.name l r') ∧ (Atom.name l r').Covers (.name l r) := by
  have hPl : P.effects l = none := by
    cases e : P.effects l with
    | none => rfl
    | some os => rw [hdecl.2.2 l os e] at hbs; cases hbs
  refine hk.name_end_ix hε (fun hs hin => ?_)
  have hh := hno hs hin
  have hall : (bs.map OpRef.prim).all (handles hs) = false := by
    rw [Bool.eq_false_iff]; intro h
    rw [List.all_eq_true] at h
    have := h (.prim b0) (List.mem_map.mpr ⟨b0, hb0, rfl⟩)
    rw [hh] at this; cases this
  simp only [Eff.test, Eff.atoms, Eff.ofAtoms, handled, effOps, hPl, hbs, Option.map_some]
  revert hall
  cases bs.map OpRef.prim <;> simp

/-- 継続の末尾で許すエフェクトが空の状態は、事象を伴う遷移をしない。 -/
theorem no_event (hdecl : P.EffectsOk B) (hb : B.CoreAssumptions P) {s : State}
    (hs : StateTyE P B Eff.empty s) : ∀ ev s', ¬ Step P B s (some ev) s' := by
  intro ev s' hst
  -- 解放の枠：`State` を含むエフェクトの継続は、末尾でも `State` を許す。
  have hrel : ∀ {Ψ R ε v k a b}, ContTy P B Ψ R ε (.release v :: k) a b Eff.empty none → False := by
    intro Ψ R ε v k a b hk
    obtain ⟨_, _, _, hst, _⟩ := hk.inv_release
    have := hk.state_end hdecl hb hst
    simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at this
  -- IO：`handle` の枠がなければ、継続の末尾が組み込みのエフェクトを許す。
  have hio : ∀ {Ψ R a ε1 ε b' b0 ts es rs ws k s0}, HasTypeC P B Ψ [] [] R (.app (.prim b0 ts es rs) ws) a ε1 →
      Eff.Sub ε1 ε → ContTy P B Ψ R ε k a b' Eff.empty none → B.sig b0 = some s0 →
      (s0.kind = .io ∨ s0.kind = .exit) → NoHandler k (.prim b0) → False := by
    intro Ψ R a ε1 ε b' b0 ts es rs ws k s0 hm hε hk hsig hkd hno
    obtain ⟨s', hs', _, _, _, _, _, hsub, _⟩ := inv_prim_app hm
    rw [hsig] at hs'; cases hs'
    -- 形の検査（`io_op`）から、具体化した効果は名前 l の原子を含む（範囲の位置は具体化による）。
    obtain ⟨l, bs, ix, _, hbs, hb0, hmem⟩ := (hb.io_op b0 _ hsig hkd).inst_eff_mem rs
    obtain ⟨a1, ha1, ha1c⟩ := hsub.1 _ (Eff.substAt_name hmem)
    obtain ⟨jx, rfl⟩ := ha1c.name_right
    have hl : Eff.mem ε (.name l jx) := hε.1 _ ha1
    obtain ⟨r', this, -⟩ := hk.end_of_noHandler_ix hdecl hbs hb0 hl hno
    simp [Eff.mem, Eff.test, Eff.atoms, Eff.empty] at this
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
              apply hε.1; apply hsub.nameTop
              rw [Eff.substAt_single]
              exact (Eff.mem_single _ _).mpr rfl
          | raise T E =>
              obtain ⟨Ψ, R, a, b, ε, ε1, hσ, hm, hε, hk, _⟩ := hs
              obtain ⟨names, as, r, e, hf, ha, _, _⟩ := hm.inv_app rfl
              obtain ⟨_, _, hl⟩ := hf.inv_raise rfl
              obtain ⟨_, hps, _, _⟩ := Ty.Le.fn_fn' hl
              rw [← hps] at ha
              cases ha with
              | cons hv tail =>
                  cases tail
                  have hend := hk.fail_end hu ((hm.inv_raise_app.2.2.2.1.trans hε).2 _
                    ((Eff.memFail_singleFail _ _).mpr rfl))
                  exact ((Eff.fails_eq_nil_iff Eb).mp hEb.1 E hend).elim
          | _ => exact (show False from hu)
      | _ => exact (show False from hu)
  | _ => exact (show False from hu)

/-- 実行を始める状態のラムダ名は、型付けから導く。 -/
theorem stateTyE_init_noLamNames (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {m : Comp} {a : Ty}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a Eff.empty)
    (hc : Comp.VarsInNoLamNames 0 (fun _ => False) m) :
    StateTyE P B Eff.empty (.run m [] Store.empty) := by
  have hc := (hm.varsIn_iff_noLamNames 0 (fun _ => False)).mpr hc
  have hmc : Comp.VarsIn 0 (fun _ => True) m := Comp.VarsIn.toTrue m hc
  have hΨ : StoreTy.WF StoreTy.empty := fun l x h => by simp [StoreTy.empty] at h
  have hw : Ty.WF 0 0 a := HasTypeCQ.wf hwf hb hm (envWF_nil 0) hΨ hmc
  refine ⟨StoreTy.empty, none, a, a, Eff.empty, Eff.empty, ?_, hm, Eff.Sub.refl _,
    .K_Empty (Eff.Sub.refl _) hw, hmc, fun f hf => by simp at hf, fun l c h => by simp [Store.empty] at h⟩
  refine ⟨⟨0, fun l _ => rfl⟩, fun l x h => ?_, fun l x h => ?_, fun l c h => ?_⟩ <;>
    simp [StoreTy.empty, Store.empty] at h

/-- 既存の閉じた項の前提でも、ラムダ名の条件は型付けから導いて初期状態を作る。 -/
theorem stateTyE_init (hwf : P.WellFormed) (hb : B.CoreAssumptions P) {m : Comp} {a : Ty}
    (hm : HasTypeC P B StoreTy.empty [] [] none m a Eff.empty) (hc : m.ClosedNoEffVars) :
    StateTyE P B Eff.empty (.run m [] Store.empty) :=
  stateTyE_init_noLamNames hwf hb hm ((hm.varsIn_iff_noLamNames 0 (fun _ => False)).mp hc)

/-- 初期状態の型付けを任意の ε へ広げたもの（`stateTyE_init` は空の ε だけ）。範囲付きのエフェクトの
対象の健全性の到達先の言明が、初期の計算の型の同じ ε を継続の末尾に固定するために使う。証明は
`stateTyE_init_noLamNames` と同じである。 -/
theorem stateTyE_init_eff {P : Release.Program} {B : Release.Builtins} (hwf : P.WellFormed)
    (hb : B.CoreAssumptions P) {m : Release.Comp} {a : Release.Ty} {ε : Release.Eff}
    (hm : Release.HasTypeC P B Release.StoreTy.empty [] [] none m a ε) (hc : m.ClosedNoEffVars) :
    Release.StateTyE P B ε (.run m [] Release.Store.empty) := by
  have hc' := (hm.varsIn_iff_noLamNames 0 (fun _ => False)).mp hc
  have hc := (hm.varsIn_iff_noLamNames 0 (fun _ => False)).mpr hc'
  have hmc : Release.Comp.VarsIn 0 (fun _ => True) m := Release.Comp.VarsIn.toTrue m hc
  have hΨ : Release.StoreTy.WF Release.StoreTy.empty := fun l x h => by simp [Release.StoreTy.empty] at h
  have hw : Release.Ty.WF 0 0 a := Release.HasTypeCQ.wf hwf hb hm (Release.envWF_nil 0) hΨ hmc
  refine ⟨Release.StoreTy.empty, none, a, a, ε, ε, ?_, hm, Release.Eff.Sub.refl _,
    .K_Empty (Release.Eff.Sub.refl _) hw, hmc, fun f hf => by simp at hf,
    fun l c h => by simp [Release.Store.empty] at h⟩
  refine ⟨⟨0, fun l _ => rfl⟩, fun l x h => ?_, fun l x h => ?_, fun l c h => ?_⟩ <;>
    simp [Release.StoreTy.empty, Release.Store.empty] at h

theorem steps_preserve (hwf : P.WellFormed) (hwt : P.WellTyped B) (hdecl : P.EffectsOk B)
    (hb : B.CoreAssumptions P) {Eb : Eff} {s s' : State} (hsteps : Steps P B s s') (hs : StateTyE P B Eb s) :
    StateTyE P B Eb s' := by
  induction hsteps with
  | refl => exact hs
  | step hst _ ih => exact ih (preservationE hwf hwt hdecl hb hs hst)

end Benitoite.Release
