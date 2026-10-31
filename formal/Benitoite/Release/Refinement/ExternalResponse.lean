import Benitoite.Release.Refinement.ExternalCheck

/-!
# 外部応答の型付き入力と三つの信頼条件

errは実行時エラー、exitは外部応答では禁止する。正常応答の存在と決定性は要求しない。
-/
namespace Benitoite.Release.Refinement

noncomputable def ExternalSignature.instantiate (d : ExternalSignature) (ts : List Ty) (vs : List Val) :
    Option (Ty × Eff) :=
  if ts.length = d.tparams.length then Tel.instantiate (Tel.bind (typeEnv ts) d.parameters) vs else none

structure ExternalArgs (P : Program) (B : Builtins) (Ψ : StoreTy) (d : ExternalSignature)
    (ts : List Ty) (vs : List Val) (a : Ty) (e : Eff) : Prop where
  admissible : ExternalCallAdmissible P B [] d ts
  arguments : HasTypeTelArgsQ P B Ψ Qempty [] [] [] vs (Tel.bind (typeEnv ts) d.parameters) a e
  ground : ∀ v ∈ vs, v.Ground
  types : ∀ t ∈ ts, t.WF 0 0 0 ∧ t.Canonical
  result : a.WF 0 0 0 ∧ a.Canonical
  effect : Eff.WF 0 0 0 e ∧ e.Canonical

structure Builtins.ExternalAssumptions (P : Program) (B : Builtins) : Prop where
  external_typed : ∀ Ψ f d ts vs a e out obs,
    P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
    B.externalResponse f ts vs out obs → Outcome.Carrier P B Ψ out a ∧ (∀ n : Int, out ≠ .exit n)
  external_exists : ∀ Ψ f d ts vs a e,
    P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
    ∃ out obs, B.externalResponse f ts vs out obs
  external_no_targets : ∀ Ψ f d ts vs a e out obs,
    P.ExternalWF → P.externalFunction f = some d → ExternalArgs P B Ψ d ts vs a e →
    B.externalResponse f ts vs out obs → obs = []

theorem Builtins.ExternalAssumptions.checked_typed {P B Ψ f d ts vs a e out obs}
    (h : Builtins.ExternalAssumptions P B) (hw : P.ExternalWF)
    (hd : P.externalFunction f = some d) (ha : ExternalArgs P B Ψ d ts vs a e)
    (hr : B.externalResponse f ts vs out obs) :
    Outcome.Typed P B Ψ (externalCheckedOutcome P a out) a ∧
      (∀ n : Int, externalCheckedOutcome P a out ≠ .exit n) ∧ obs = [] := by
  obtain ⟨ht, hn⟩ := h.external_typed Ψ f d ts vs a e out obs hw hd ha hr
  refine ⟨externalCheckedOutcome_typed ht, ?_, h.external_no_targets Ψ f d ts vs a e out obs hw hd ha hr⟩
  cases out with
  | val v =>
    intro n
    simp only [externalCheckedOutcome]
    split <;> simp
  | err r => intro n; simp [externalCheckedOutcome]
  | exit n => exact False.elim (hn n rfl)

/-- 宣言と実引数から具体化した結果型だけを受信検査へ渡す。 -/
noncomputable def externalReceive (P : Program) (d : ExternalSignature)
    (ts : List Ty) (vs : List Val) (out : Outcome) : Option Outcome :=
  (d.instantiate ts vs).map fun (a, _) => externalCheckedOutcome P a out

end Benitoite.Release.Refinement
