import Benitoite.Release.Refinement.Surface.CheckEntrypoints
import Benitoite.Release.Refinement.Surface.CheckOpenInfer
import Benitoite.Release.Refinement.Surface.CheckOpenSound
import Benitoite.Release.Refinement.Surface.CheckFinite
import Benitoite.Release.Refinement.Surface.CheckDeclarationBase

/-! # 範囲パラメータを持つ関数の本体の推論と有限な検査 -/
noncomputable section

namespace Benitoite.Release.Refinement.Surface.CheckOpenDeclarations
open Check CheckAdmissible

def definitionInput (q : Check.Input) (d : Def) : Check.Input :=
  { q with
    formation := { q.formation with rangeKinds := d.rangeParams }
    proofSteps := d.proofSteps.getD q.proofSteps }

private theorem input_sound {q d} (h : q.Sound) : (definitionInput q d).Sound := by
  exact ⟨⟨h.formation.ctors, h.formation.fields⟩, h.tables, h.sat, h.admits, h.ranges, h.operators⟩

private theorem require_ok {path reason ok} (h : Check.require path reason ok = .ok ()) : ok = true := by
  unfold Check.require at h
  split at h
  · assumption
  · cases h

/-- 本体の期待型と効果を署名から取り、ソースから案内を計算して再検査する。 -/
def bodyResult (q : Check.Input) (rows : List Bool) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred)
    (path : List Nat) (body : Block) (a : Ty) (e : Eff) : Check.Result Unit :=
  match (CheckOpenInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e).toCheck with
  | .error err => .error err
  | .ok result =>
    let g := CheckFinite.guide q.formation.atoms result.guide
    if CheckOpen.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e g then .ok ()
    else .error (Check.proofFailure path q.proofSteps g)

private def bodyTelResult (q : Check.Input) (rows : List Bool) (C : TypeCtx)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : Tel → Block → Check.Result Unit
  | .done a e, body => bodyResult q rows C Γ Φ path body a e
  | .param _ a rest, body => bodyTelResult q rows C (Γ.extend a) (Φ.map Pred.lift) path rest body

private theorem bodyResult_sound {q rows C Γ Φ path body a e}
    (hq : CheckOpen.OpenSound q) (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (hb : Check.BlockSupport q body) (ha : a.Support (· ∈ q.formation.atoms))
    (he : e.Support (· ∈ q.formation.atoms)) (h : bodyResult q rows C Γ Φ path body a e = .ok ()) :
    OpenSurface.HasBlockQ q.D q.B q.formation.rangeKinds q.opPrim (NoFailCtxOf rows) [] C Γ Φ
      (some a) .tail body a e := by
  cases hs : (CheckOpenInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e).toCheck with
  | error err => simp only [bodyResult, hs] at h; cases h
  | ok result =>
    have hc : CheckOpen.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e
        (CheckFinite.guide q.formation.atoms result.guide) = true := by
      by_cases hc : CheckOpen.checkBlockAt q rows [] C Γ Φ (some a) .tail path body a e
          (CheckFinite.guide q.formation.atoms result.guide) = true
      · exact hc
      · simp [bodyResult, hs, hc] at h
    exact CheckOpen.checkBlockAt_sound hq (by intro i k h; cases i <;> cases h)
      hΓ ha hb ha he (CheckFinite.guide_support _ _) hc

private theorem bodyTelResult_sound {q rows C Γ Φ path t body}
    (hq : CheckOpen.OpenSound q) (hΓ : CheckFormation.CtxSupport q.formation.atoms Γ)
    (ht : t.Support (· ∈ q.formation.atoms)) (hb : Check.BlockSupport q body)
    (h : bodyTelResult q rows C Γ Φ path t body = .ok ()) :
    OpenSurface.BodyTy q.D q.B q.formation.rangeKinds q.opPrim (NoFailCtxOf rows) C Γ Φ t body := by
  cases t with
  | done a e => exact .done (bodyResult_sound hq hΓ hb ht.1 ht.2 h)
  | param name a rest => exact .param (bodyTelResult_sound hq (hΓ.extend ht.1) ht.2 hb h)

/-- 宣言の構文形成と全構成子の範囲閉性を確認してから本体を検査する。 -/
def checkDef (q : Check.Input) (path : List Nat) (d : Def) : Check.Result Unit :=
  let input := definitionInput q d
  Except.bind (Check.require path "function declaration is invalid"
    (CheckOpen.constructorsClosed input &&
      (decide (NamesWF d.coreNames d.coreParams) &&
        (rowsTelCheck input.formation.atoms d.neffs d.toFunDecl.tel &&
          (CheckFormation.kindTy input.formation input.D.core (TypeCtx.kinds d.tparams) (.dependentFn d.toFunDecl.tel) .value &&
            CheckOpen.annotation input d.tparams [] (path ++ [0]) (.dependentFn d.toFunDecl.tel))))))
    (fun _ => bodyTelResult input (telQ d.neffs d.toFunDecl.tel) d.tparams [] [] (path ++ [1]) d.toFunDecl.tel d.body)

/-- 成功した開いた定義は、一度の表層の本体の導出を持つ。 -/
theorem checkDef_sound {q path d} (hq : q.Sound) (hd : CheckDeclarations.DefSupport q d)
    (hc : CheckVariance.CtorsComplete q.D.core q.ctorNames) (hk : d.rangeParams ≠ [])
    (h : checkDef q path d = .ok ()) : d.WellTyped q.D q.B q.opPrim := by
  have hinput := input_sound (d := d) hq
  have hh : CheckOpen.constructorsClosed (definitionInput q d) = true ∧
      NamesWF d.coreNames d.coreParams ∧
      rowsTelCheck q.formation.atoms d.neffs d.toFunDecl.tel = true ∧
      CheckFormation.kindTy (definitionInput q d).formation q.D.core (TypeCtx.kinds d.tparams)
        (.dependentFn d.toFunDecl.tel) .value = true ∧
      CheckOpen.annotation (definitionInput q d) d.tparams [] (path ++ [0]) (.dependentFn d.toFunDecl.tel) = true ∧
      bodyTelResult (definitionInput q d) (telQ d.neffs d.toFunDecl.tel) d.tparams [] []
        (path ++ [1]) d.toFunDecl.tel d.body = .ok () := by
    unfold checkDef at h
    dsimp only at h
    generalize hguard : Check.require path "function declaration is invalid" _ = guard at h
    cases guard with
    | error err => simp only [Except.bind] at h; cases h
    | ok value =>
      have ht := require_ok hguard
      simp only [Bool.and_eq_true, decide_eq_true_eq] at ht
      exact ⟨ht.1, ht.2.1, ht.2.2.1, ht.2.2.2.1, ht.2.2.2.2, by simpa only [Except.bind] using h⟩
  have hopen : CheckOpen.OpenSound (definitionInput q d) := ⟨hinput, hc, hh.1⟩
  have hrows := (rowsTelCheck_spec d.neffs d.toFunDecl.tel hd.signature).mp hh.2.2.1
  have hQ : NoFailCtxOf (telQ d.neffs d.toFunDecl.tel) = QTel d.toFunDecl.tel :=
    funext fun i => propext (telQ_scoped hrows i)
  refine ⟨hh.2.1, CheckFormation.kindTy_sound hinput.formation.ctors hh.2.2.2.1,
    CheckOpen.annotation_sound hopen (Check.CtxSupport.empty _) hd.signature hh.2.2.2.2.1, ?_⟩
  simp only [BodyTyR, hk, ite_false]
  rw [← hQ]
  exact bodyTelResult_sound hopen (Check.CtxSupport.empty _) hd.signature (CheckSource.blockSupport_rangeKinds.mpr hd.body) hh.2.2.2.2.2

/-- 同じ開いた本体で、推論又は生成した証明書の会計が実際に停止した。 -/
def InferenceStopped (q : Check.Input) (r : CheckInfer.Result CheckOpenInfer.Synth) : Prop :=
  (∃ path reason, r = .error (.stopped path reason)) ∨
    ∃ s, r = .ok s ∧ ∃ c ∈ CheckDiagnostics.guideQueries (CheckFinite.guide q.formation.atoms s.guide),
      CheckDiagnostics.StoppedQuery q.proofSteps c

def BodyTelStopped (q : Check.Input) (rows : List Bool) (C : TypeCtx)
    (Γ : Ctx) (Φ : List Pred) (path : List Nat) : Tel → Block → Prop
  | .done a e, body => InferenceStopped q
      (CheckOpenInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e)
  | .param _ a rest, body => BodyTelStopped q rows C (Γ.extend a) (Φ.map Pred.lift) path rest body

private theorem bodyResult_unknown {q rows C Γ Φ path body a e error}
    (h : bodyResult q rows C Γ Φ path body a e = .error error) (hu : error.kind = .unknown) :
    InferenceStopped q
      (CheckOpenInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e) := by
  cases hr : (CheckOpenInfer.inferBlockExpected q ⟨q.logicCertificates⟩ rows [] C Γ Φ (some a) .tail path body a e).toCheck with
  | error err =>
    simp only [bodyResult, hr] at h
    cases h
    exact Or.inl (CheckInfer.Result.toCheck_unknown hr hu)
  | ok s =>
    simp only [bodyResult, hr] at h
    split at h
    · cases h
    · cases h
      exact Or.inr ⟨s, CheckInfer.Result.toCheck_ok.mp hr, Check.proofFailure_unknown hu⟩

private theorem bodyTelResult_unknown {q rows C Γ Φ path t body error}
    (h : bodyTelResult q rows C Γ Φ path t body = .error error) (hu : error.kind = .unknown) :
    BodyTelStopped q rows C Γ Φ path t body := by
  cases t with
  | done a e => exact bodyResult_unknown h hu
  | param name a rest => exact bodyTelResult_unknown (Γ := Γ.extend a) (Φ := Φ.map Pred.lift) h hu

/-- 開いた関数の unknown は、宣言の本体における実際の打ち切りに由来する。 -/
theorem checkDef_unknown {q path d error} (h : checkDef q path d = .error error)
    (hu : error.kind = .unknown) :
    BodyTelStopped (definitionInput q d) (telQ d.neffs d.toFunDecl.tel) d.tparams [] []
      (path ++ [1]) d.toFunDecl.tel d.body := by
  unfold checkDef at h
  dsimp only at h
  generalize hguard : Check.require path "function declaration is invalid" _ = guard at h
  cases guard with
  | error err =>
    simp only [Except.bind, Except.error.injEq] at h
    subst err
    unfold Check.require at hguard
    split at hguard
    · cases hguard
    · cases hguard; cases hu
  | ok value => exact bodyTelResult_unknown (by simpa only [Except.bind] using h) hu

end Benitoite.Release.Refinement.Surface.CheckOpenDeclarations
