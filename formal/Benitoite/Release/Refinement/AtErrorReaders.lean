import Benitoite.Release.Refinement.AtTargets
import Benitoite.Release.Refinement.TypedFacts
import Benitoite.Release.Refinement.AtPatterns

/-! # 保存した内部診断から型付きの観測と照合へ -/
namespace Benitoite.Release.Refinement.AtErrorReaders
noncomputable section

/-- 全診断の同じ七欄を、型付け・項観測・照合の既存の読者へ渡す。 -/
theorem observed {P B Ψ Q C Γ Φ shape} (declared : ResultShape.Declared P shape) (d : AtError) :
    HasTypeVQ P B Ψ Q C Γ Φ (.atError d) atErrorType ∧
    (∀ t, (Val.atError d).toTerm? = some t → Term.Declared P C Γ t) ∧
    matchVal atErrorPattern (.atError d) = some d.values ∧
    HasTypeVsQ P B Ψ Q C Γ Φ d.values atErrorFields ∧
    ∀ ws, AdequateResult ws (.val (.atError d)) := by
  have typed : HasTypeVQ P B Ψ Q C Γ Φ (.atError d) atErrorType := by
    rw [← declared.errorType_eq]; exact .V_AtError declared
  exact ⟨typed,fun _ ht => typed.observation_declared ht,d.match_pattern,
    d.values_typed P B Ψ Q C Γ Φ,AtTargets.adequate_atError d⟩

/-- 準備の全失敗で、保存した元入力・解析段階・解決結果と同じ観測を読む。 -/
theorem prepare_reader {P B Ψ Q C Γ Φ shape cap kind name bases pattern input index d}
    (declared : ResultShape.Declared P shape)
    (failure : AtPrepare B cap kind name bases pattern input index = .error d) :
    d.originalPattern = closeVal cap pattern ∧ d.originalTarget = closeVal cap input ∧
    (∃ snapshot pp pt,
      d = AtError.save (closeVal cap pattern) (closeVal cap input) snapshot pp pt d.failure ∧
      d.parsedPattern = pp ∧ d.parsedTarget = pt ∧
      d.resolvedPatterns = pp.bind (resolveSnapshot snapshot) ∧
      d.resolvedTarget = pt.bind (resolveTargetSnapshot snapshot) ∧
      d.patternBase = pp.bind RangeExpr.base? ∧ d.targetBase = pt.bind TargetInput.base?) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.atError d) atErrorType ∧
    (∀ t, (Val.atError d).toTerm? = some t → Term.Declared P C Γ t) ∧
    matchVal atErrorPattern (.atError d) = some d.values ∧
    HasTypeVsQ P B Ψ Q C Γ Φ d.values atErrorFields ∧
    ∀ ws, AdequateResult ws (.val (.atError d)) := by
  obtain ⟨snapshot,pp,pt,exactFields⟩ := AtPrepare.error_saved failure
  have obs := observed (B := B) (Ψ := Ψ) (Q := Q) (C := C) (Γ := Γ) (Φ := Φ) declared d
  refine ⟨?_,?_,⟨snapshot,pp,pt,exactFields,?_,?_,?_,?_,?_,?_⟩,obs⟩
  all_goals rw [exactFields]; rfl

/-- 検査の全失敗で、同じ元入力と九欄を保持した診断を読者へ渡す。 -/
theorem check_reader {P B Ψ Q C Γ Φ shape} (declared : ResultShape.Declared P shape)
    (p t : Val) (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput)
    (d : AtCheckError) :
    let saved := AtError.fromCheck p t snapshot pat target d
    saved.originalPattern = p ∧ saved.originalTarget = t ∧ saved.failure = d.failure ∧
    saved.parsedPattern = some pat ∧ saved.parsedTarget = some target ∧
    saved.resolvedPatterns = resolveSnapshot snapshot pat ∧
    saved.resolvedTarget = resolveTargetSnapshot snapshot target ∧
    saved.patternBase = pat.base? ∧ saved.targetBase = target.base? ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.atError saved) atErrorType ∧
    (∀ term, (Val.atError saved).toTerm? = some term → Term.Declared P C Γ term) ∧
    matchVal atErrorPattern (.atError saved) = some saved.values ∧
    HasTypeVsQ P B Ψ Q C Γ Φ saved.values atErrorFields ∧
    ∀ ws, AdequateResult ws (.val (.atError saved)) :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,observed declared _⟩

/-- 準備失敗の実行の葉が保持する同じ診断も、全有効環境で適格である。 -/
example {P B σ Eb q k μ kind name shape bases pattern input index d}
    (state : StateTyE P B σ Eb (.run q k μ))
    (code : q.code = .checkAt kind name shape bases pattern input index)
    (declared : ResultShape.Declared P shape)
    (failure : AtPrepare B q.capture kind name bases pattern input index = .error d) :
    d.originalPattern = closeVal q.capture pattern ∧ d.originalTarget = closeVal q.capture input ∧
    d.failure ≠ .staticIndex ∧
    (∀ ws, AdequateResult ws (.val (.atError d))) ∧
    Step P B σ (.run q k μ) none
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind index,q.capture.closeTy shape.errorType] [.atError d]))) k μ) ∧
    StateTyE P B σ Eb
      (.run (Closure.pure (.ret (.con shape.error
        [.scoped name kind index,q.capture.closeTy shape.errorType] [.atError d]))) k μ) := by
  obtain ⟨rawPattern,rawTarget,_,_,_,_,_,adequate⟩ :=
    prepare_reader (Ψ := StoreTy.empty) (Q := Qempty) (C := []) (Γ := []) (Φ := []) declared failure
  obtain ⟨notStatic,step,preserved⟩ := state.at_prepare_failure code failure
  exact ⟨rawPattern,rawTarget,notStatic,adequate,step,preserved⟩

/-- 全失敗種別・全起点で、元入力の置換は内部の照合の項観測を変えない。 -/
example {P B Ψ Q C Γ Φ shape} (declared : ResultShape.Declared P shape)
    (p t : Val) (snapshot : Option PathEnv) (pat : RangeExpr) (target : TargetInput)
    (d : AtCheckError) (p' t' : Val) :
    let saved := AtError.fromCheck p t snapshot pat target d
    let changed : AtError := {saved with originalPattern := p', originalTarget := t'}
    HasTypeVQ P B Ψ Q C Γ Φ (.atError saved) atErrorType ∧
    saved.textFields = changed.textFields ∧
    (∀ pattern, (matchVal pattern (.atError saved)).map (List.map Val.toTerm?) =
      (matchVal pattern (.atError changed)).map (List.map Val.toTerm?)) := by
  have reader := check_reader (B := B) (Ψ := Ψ) (Q := Q) (C := C) (Γ := Γ) (Φ := Φ)
    declared p t snapshot pat target d
  exact ⟨reader.2.2.2.2.2.2.2.2.2.1,rfl,
    fun pattern => ((AtError.fromCheck p t snapshot pat target d).originals_unobserved p' t').2.2.2 pattern |>.symm⟩

/-- 内部の完全な構成子一覧は、保存値の九欄とは別に網羅性へ渡す。 -/
example {P shape cs} (declared : ResultShape.Declared P shape)
    (complete : P.StandardErrorComplete cs) (d : AtError) :
    ∃ pattern ∈ atErrorPatterns cs, (matchVal pattern (.atError d)).isSome :=
  Exhaustive.atError declared.standard complete _ (.atError ⟨rfl,declared.standard.2⟩)

end
end Benitoite.Release.Refinement.AtErrorReaders
