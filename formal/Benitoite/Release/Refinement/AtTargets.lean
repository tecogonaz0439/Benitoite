import Benitoite.Release.Refinement.PathBasesTargets

/-! # At の準備と検査から同じ状態の保存へ -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 準備された対象の解決は失敗しない。snapshot なしでは両範囲も解決する。 -/
theorem AtPrepared.resolution {B cap kind name bases pattern input index snapshot pat target bound}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    (∃ t, resolveTargetSnapshot snapshot target = some t) ∧
    (snapshot = none → (∃ ps, resolveSnapshot snapshot pat = some ps) ∧
      ∃ bs, resolveSnapshot snapshot bound = some bs) := by
  obtain ⟨_,_,hn⟩ := h.formed
  cases snapshot with
  | none =>
    obtain ⟨p,t,b,rfl,rfl,rfl⟩ := hn rfl
    exact ⟨⟨t,rfl⟩,fun _ => ⟨⟨[p],rfl⟩,⟨[b],rfl⟩⟩⟩
  | some σ =>
    refine ⟨?_,by intro h; cases h⟩
    cases target <;> exact ⟨_,rfl⟩

theorem AtPrepared.no_invalidPattern {B cap kind name bases pattern input index snapshot pat target bound detail}
    (h : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (he : checkAt snapshot kind pat target bound = .error detail) :
    detail.failure ≠ .invalidPattern :=
  checkAt.no_invalidPattern ⟨h.formed.1.2.1,h.formed.1.1⟩
    ⟨h.formed.2.1.2.1,h.formed.2.1.1⟩ he

/-- 型付けた At の範囲添字は、準備前から閉じている。 -/
theorem StateTyE.at_index {P B σ Eb q k μ kind name shape bases pattern input index}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index) : index.WF 0 := by
  obtain ⟨_,_,_,_,_,_,_,hq,_⟩ := h
  obtain ⟨_,_,_,hs,_⟩ := hq.at_inputs hv
  cases hs with | mk _ _ _ _ _ _ hw _ => exact hw

/-- すべての準備失敗を、同じ Error と既存の保存の葉へ渡す。 -/
theorem StateTyE.at_prepare_failure {P B σ Eb q k μ kind name shape bases pattern input index detail}
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index)
    (he : AtPrepare B q.capture kind name bases pattern input index = .error detail) :
    detail.failure ≠ .staticIndex ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind index,q.capture.closeTy shape.errorType] [.atError detail]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind index,q.capture.closeTy shape.errorType] [.atError detail]))) k μ) :=
  ⟨AtPrepare.no_staticIndex (h.at_index hv) he,h.at_prepare_error_all hv he⟩

/-- 同じ準備結果を一度分岐し、全入力で At の三保存葉のいずれかへ進む。 -/
theorem StateTyE.at_step {P B σ Eb q k μ kind name shape bases pattern input index}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index) :
    ∃ next, Step P B σ (.run q k μ) none next ∧ StateTyE P B σ Eb next := by
  cases hp : AtPrepare B q.capture kind name bases pattern input index with
  | error detail => exact ⟨_,(h.at_prepare_failure hv hp).2⟩
  | ok prepared =>
    rcases prepared with ⟨snap,pat,target,bound⟩
    have hp : AtPrepared B q.capture kind name bases pattern input index snap pat target bound := hp
    have hc := h.at_current hv hp
    obtain ⟨hi,hbs⟩ := hp.origins
    rcases hi with hi | hi <;> rcases hbs with hbs | hbs
    all_goals
      cases he : checkAt snap kind pat target bound with
      | ok t => exact ⟨_,h.at_ok_all hP hPB hB hσ hv hp hc he⟩
      | error detail => exact ⟨_,h.at_error_all hv hp hc he⟩

namespace AtTargets
theorem adequate_atError (detail : AtError) (ws : List Val) :
    AdequateResult ws (.val (.atError detail)) := by intro σ _ _; trivial

example (detail : AtError) (ws : List Val) (σ : PathEnv) (hv : σ.Valid)
    (hws : ∀ w ∈ ws, w.Adequate σ) : (Val.atError detail).Adequate σ :=
  adequate_atError detail ws σ hv hws
end AtTargets

/-- 元入力は保存されるが、現在の項観測とパターン照合は元入力を取り出さない。 -/
theorem Detail.originals_unobserved (d : AtError) (p t : Val) :
    let d' : AtError := {d with originalPattern := p, originalTarget := t}
    d'.textFields = d.textFields ∧ d'.values = d.values ∧
    (Val.atError d').toTerm? = (Val.atError d).toTerm? ∧
    ∀ pat, (matchVal pat (.atError d')).map (List.map Val.toTerm?) =
      (matchVal pat (.atError d)).map (List.map Val.toTerm?) := by
  refine ⟨rfl,rfl,rfl,?_⟩
  intro pat
  cases pat <;> rfl

example (d : AtError) (p t : Val) (ws : List Val) :
    let d' : AtError := {d with originalPattern := p, originalTarget := t}
    AdequateResult ws (.val (.atError d')) ∧
      (Val.atError d').toTerm? = (Val.atError d).toTerm? ∧
      ∀ pat, (matchVal pat (.atError d')).map (List.map Val.toTerm?) =
      (matchVal pat (.atError d)).map (List.map Val.toTerm?) :=
  ⟨AtTargets.adequate_atError _ ws,(d.originals_unobserved p t).2.2⟩

example (p t : Val) (snapshot : Option PathEnv) (pat : RangeExpr)
    (target : TargetInput) (d : AtCheckError) :
    let saved := AtError.fromCheck p t snapshot pat target d
    saved.originalPattern = p ∧ saved.originalTarget = t ∧ saved.failure = d.failure ∧
    saved.parsedPattern = some pat ∧ saved.parsedTarget = some target ∧
    saved.resolvedPatterns = resolveSnapshot snapshot pat ∧
    saved.resolvedTarget = resolveTargetSnapshot snapshot target ∧
    saved.patternBase = pat.base? ∧ saved.targetBase = target.base? :=
  AtError.save_exact p t snapshot (some pat) (some target) d.failure

example {B cap kind name bases pattern input index snapshot pat target bound detail}
    (hp : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (he : checkAt snapshot kind pat target bound = .error detail) :
    detail.failure ≠ .invalidPattern := hp.no_invalidPattern he

example {B cap kind name bases pattern input index snapshot pat target bound}
    (hp : AtPrepared B cap kind name bases pattern input index snapshot pat target bound) :
    resolveTargetSnapshot snapshot target ≠ none ∧
    (snapshot = none → resolveSnapshot snapshot pat ≠ none ∧ resolveSnapshot snapshot bound ≠ none) := by
  obtain ⟨⟨t,ht⟩,hn⟩ := hp.resolution
  constructor
  · rw [ht]; simp
  · intro hs
    obtain ⟨⟨ps,hp⟩,⟨bs,hb⟩⟩ := hn hs
    rw [hp,hb]
    simp

example {P B σ Eb q k μ kind name shape bases pattern input index}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P) (hσ : σ.Valid)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.code = .checkAt kind name shape bases pattern input index) :
    ∃ next, Step P B σ (.run q k μ) none next ∧ StateTyE P B σ Eb next :=
  h.at_step hP hPB hB hσ hv

/-- 動的な条件で要求した起点が未束縛なら、検査は Error を返す。 -/
example (σ : PathEnv) (kind : Scope.Domain.Kind) (b : PathBase)
    (p : Scope.Domain.PathPattern) (input : TargetInput) (bound : RangeExpr)
    (hb : σ.lookup b = none) :
    checkAt (some σ) kind (.based b p) input bound =
      .error (atDetail (some σ) (.based b p) input (.unbound b)) := by
  simp [checkAt,resolveSnapshot,RangeExpr.resolve,hb]; rfl

/-- 未指定の一覧と、解決した空の一覧は異なる Error を返す。 -/
example (σ : PathEnv) (w : Scope.Domain.Word) (hw : Scope.Domain.PathWordWF w) :
    checkAt (some {σ with secrets := none}) .path .secrets (.absolute (.path w)) .top =
      .error (atDetail (some {σ with secrets := none}) .secrets (.absolute (.path w)) .secretsUnbound) ∧
    checkAt (some {σ with secrets := some []}) .path .secrets (.absolute (.path w)) .top =
      .error (atDetail (some {σ with secrets := some []}) .secrets (.absolute (.path w)) .dynamicCondition) := by
  constructor
  · simp [checkAt,resolveSnapshot,RangeExpr.resolve]; rfl
  · simp [checkAt,resolveSnapshot,resolveTargetSnapshot,RangeExpr.resolve,Scope.Domain.Target.WF,
      Scope.Domain.Target.kind,RangeExpr.WF,RangeExpr.FitsKind,Scope.Domain.Range.WF,
      Scope.Domain.Range.FitsKind,Scope.Domain.Range.kind?,hw]

end
end Benitoite.Release.Refinement
