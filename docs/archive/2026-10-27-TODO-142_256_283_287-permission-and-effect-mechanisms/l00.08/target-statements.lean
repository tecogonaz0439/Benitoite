import Benitoite.Release.Lemmas.EffectSound
import Benitoite.Scope.Domain

/-! L00.08b の一時ファイル: 名前と種類を保つ形に直した本番の対象健全性の言明の案が型検査を通ること、
到達先の言明が一段の言明から従うことを確かめる。リポジトリに置かない。 -/

namespace L008bScratch

open Benitoite
open Benitoite.Scope.Domain

/-- 一段の言明の案。IO の事象 `b(ws) ↦ o` の観測した全ての対象 t について、b の署名の `opEff` の名前 l の
種類 k が t の種類であり、継続の末尾の添字 Eb が名前 l・種類 k で t を許す。 -/
def ReleaseStepTargetStatement (obs : Release.Event → List Target)
    (effKind : Release.EffName → Option Kind)
    (allows : Release.Eff → Release.EffName → Kind → Target → Prop)
    (TA : Release.Builtins → Release.Program → Prop) : Prop :=
  ∀ (P : Release.Program) (B : Release.Builtins) (Eb : Release.Eff) (s s' : Release.State)
    (b : Release.PrimName) (ws : List Release.Val) (o : Release.Outcome),
    P.WellFormed → P.WellTyped B → P.EffectsOk B → B.Assumptions P → TA B P →
    Release.StateTyE P B Eb s → Release.Step P B s (some (.io b ws o)) s' →
    ∃ sg l, B.sig b = some sg ∧ sg.opEff = some l ∧
      ∀ t ∈ obs (.io b ws o), ∃ k, effKind l = some k ∧ allows Eb l k t

/-- 到達先の言明の案。初期の計算の型の ε を固定する。 -/
def ReleaseReachableTargetStatement (obs : Release.Event → List Target)
    (effKind : Release.EffName → Option Kind)
    (allows : Release.Eff → Release.EffName → Kind → Target → Prop)
    (TA : Release.Builtins → Release.Program → Prop) : Prop :=
  ∀ (P : Release.Program) (B : Release.Builtins) (m : Release.Comp) (a : Release.Ty) (ε : Release.Eff)
    (s s' : Release.State) (b : Release.PrimName) (ws : List Release.Val) (o : Release.Outcome),
    P.WellFormed → P.WellTyped B → P.EffectsOk B → B.Assumptions P → TA B P →
    Release.HasTypeC P B Release.StoreTy.empty [] [] none m a ε → m.ClosedNoEffVars →
    Release.Steps P B (.run m [] Release.Store.empty) s → Release.Step P B s (some (.io b ws o)) s' →
    ∃ sg l, B.sig b = some sg ∧ sg.opEff = some l ∧
      ∀ t ∈ obs (.io b ws o), ∃ k, effKind l = some k ∧ allows ε l k t

theorem reachable_of_step {obs : Release.Event → List Target} {effKind : Release.EffName → Option Kind}
    {allows : Release.Eff → Release.EffName → Kind → Target → Prop}
    {TA : Release.Builtins → Release.Program → Prop}
    (hstep : ReleaseStepTargetStatement obs effKind allows TA) :
    ReleaseReachableTargetStatement obs effKind allows TA := by
  intro P B m a ε s s' b ws o hwf hwt hdecl hb hta hm hc hsteps hst
  have h0 := Release.stateTyE_init_eff hwf hb hm hc
  have hs := Release.steps_preserve hwf hwt hdecl hb hsteps h0
  exact hstep P B ε s s' b ws o hwf hwt hdecl hb hta hs hst

#print axioms reachable_of_step

end L008bScratch
