import Benitoite.Release.Lemmas.Irrelevant
import Benitoite.Release.Semantics

/-!
# Fail 節の形と保存継続の末尾

通常節は Fail を扱わず、Fail 節は予約した継続の位置を使えない。
保存継続の解放には、残る効果と節の効果の双方を保持する。
-/

namespace Benitoite.Release

variable {P : Program} {B : Builtins}

/-- 通常の操作の署名を持つ識別子は Fail ではない。 -/
theorem opSig_ne_fail {o sg} (h : opSig P B o = some sg) : o ≠ .fail := by
  intro heq
  subst o
  cases h

/-- 通常節の型付けは Fail を捕捉しない。 -/
theorem HasTypeClausesQ.no_failure {Ψ Q C Γ R h t ec}
    (hc : HasTypeClausesQ P B Ψ Q C Γ R h t ec) : handles h .fail = false := by
  match hc with
  | .nil => rfl
  | .cons hs _ _ _ _ _ ht =>
    have ih := HasTypeClausesQ.no_failure ht
    simp only [handles, List.any_cons, Clause.op, Bool.or_eq_false_iff]
    exact ⟨by simpa using opSig_ne_fail hs, ih⟩

/-- Fail 節はちょうど一つであり、そのエラー型が注釈と一致する。 -/
theorem HasFailureClause.shape {Ψ Q C Γ E R h t ec}
    (hc : HasFailureClause P B Ψ Q C Γ E R h t ec) :
    ∃ body, h = [.fail E body] := by
  cases hc with
  | one _ _ _ _ => exact ⟨_, rfl⟩

theorem HasFailureClause.handles {Ψ Q C Γ E R h t ec}
    (hc : HasFailureClause P B Ψ Q C Γ E R h t ec) : handles h .fail = true := by
  obtain ⟨body, rfl⟩ := hc.shape
  simp [Release.handles, Clause.op]

/-- Fail 節の予約した0番は、値置換で参照されない。 -/
theorem HasFailureClause.no_resume {Ψ Q C Γ E R h t ec}
    (hc : HasFailureClause P B Ψ Q C Γ E R h t ec) :
    ∀ body, h = [.fail E body] → IrrelevantSlot body 0 := by
  cases hc with
  | one _ _ _ hb =>
    intro body heq
    cases heq
    exact hb.irrelevant_slot rfl

/-- handled は名前だけを含み、Fail と行を含まない。 -/
theorem handled_noFail (P : Program) (B : Builtins) (h : List Clause) :
    NoFail Qempty (handled P B h) := by
  constructor
  · rfl
  · intro i hi
    change false = true at hi
    cases hi

/-- 保存する継続の上限には、残る効果と節の効果を合わせる。 -/
noncomputable def captureEff (Rest ec : Eff) : Eff := Eff.norm (Eff.union Rest ec)

theorem captureEff_left (Rest ec : Eff) : Eff.Sub Rest (captureEff Rest ec) :=
  ⟨fun _ ha => (Eff.mem_norm _ _).mpr ((Eff.mem_union _ _ _).mpr (Or.inl ha)),
    fun _ ht => (Eff.norm_memFail _ _).mpr ((Eff.memFail_union _ _ _).mpr (Or.inl ht))⟩

theorem captureEff_right (Rest ec : Eff) : Eff.Sub ec (captureEff Rest ec) :=
  ⟨fun _ ha => (Eff.mem_norm _ _).mpr ((Eff.mem_union _ _ _).mpr (Or.inr ha)),
    fun _ ht => (Eff.norm_memFail _ _).mpr ((Eff.memFail_union _ _ _).mpr (Or.inr ht))⟩

theorem captureEff_state {Rest ec eout}
    (hr : Eff.Sub Rest eout) (hc : Eff.Sub ec eout)
    (hs : Eff.mem (captureEff Rest ec) (.name stateEff)) : Eff.mem eout (.name stateEff) := by
  rcases (Eff.mem_union _ _ _).mp ((Eff.mem_norm _ _).mp hs) with hs | hs
  · exact hr.1 _ hs
  · exact hc.1 _ hs

/-- 保存継続の末尾を、Fail 用の枠と空の継続から作る。 -/
theorem failure_capture_base {Ψ R E h t Rest ec}
    (hc : HasFailureClause P B Ψ Qempty [] [] E R h t ec)
    (hn : NoFail Qempty Rest) (hw : Ty.WF 0 t) :
    ContTy P B Ψ R (Eff.union (Eff.singleFail E) Rest) [.handleF h] t t (captureEff Rest ec) R :=
  .K_Handle_Fail (.K_Empty (Eff.Sub.refl _) hw) (captureEff_left _ _) hn hc (captureEff_right _ _) hw

/-- 保存した継続の型から、既存の drop の効果条件を導く。 -/
theorem failure_drop {Ψ κ T t Rh Rest ec eout k2 b Eb Re}
    (hl : Ψ κ = some (.cont T t (captureEff Rest ec) Rh))
    (hr : Eff.Sub Rest eout) (hc : Eff.Sub ec eout)
    (hk : ContTy P B Ψ Rh eout k2 t b Eb Re) :
    ContTy P B Ψ Rh eout (.drop κ :: k2) t b Eb Re :=
  .K_Drop hl (captureEff_state hr hc) hk

end Benitoite.Release
