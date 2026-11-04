import Benitoite.Release.Refinement.Model
import Benitoite.Release.Refinement.PathBasesTargets
import Benitoite.Release.Refinement.PreparationTargets

/-! # 参照モデルの空引数の起点発行と At への受け渡し -/
namespace Benitoite.Release.Refinement.ModelTargetsExamples
noncomputable section
open ScopeSignatures

private theorem annotation (P : Program) :
    Ty.Annotation P [] [] (.dependentFn (.done .pathBases (Eff.single processEnvironmentEff))) :=
  ⟨⟨trivial,trivial,by simp [Eff.Canonical,Eff.norm,Eff.single]⟩,
    ⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩

private theorem instantiated : instantiatedTel (Tel.instR [] pathBases.tel) [] [] =
    .done .pathBases (Eff.single processEnvironmentEff) := by
  rw [Tel.instR_eq_bind]
  simp [instantiatedTel,Tel.bind,Tel.rawBind,SubstEnv.rangesOnly,
    pathBases,PrimSig.tel,signatureTel,Ty.rawBind,Ty.norm,Tel.norm,typeEnvAt,
    Eff.rawBind,Eff.norm,Eff.single,Ty.normTys,rowFails,instAtoms_nil,substAtoms_nil]

/-- 空の型・行・範囲・値引数は、実表の全ての入力条件を満たす。 -/
theorem call_arguments (P : Program) (Ψ : StoreTy) :
    BuiltinArgs P Model.builtins Ψ pathBasesName pathBases [] [] [] []
      .pathBases (Eff.single processEnvironmentEff) := by
  have hi : SignatureInstance P [] [] (Tel.instR [] pathBases.tel) [] [] [] := by
    refine ⟨?_,(by intro a ha; cases ha),⟨rfl,(by intro i a k ha; cases ha)⟩,
      (by intro e he; cases he),(by intro e he; cases he),?_⟩
    · exact ((Model.sig_scoped P (b := pathBasesName) rfl).inst (rs := []) rfl).2.2.2.wf
    · rw [instantiated]; exact annotation P
  refine ⟨?_,?_,hi,?_,(by intro w hw; cases hw),
    (by intro t ht; cases ht),(by intro e he; cases he),⟨trivial,rfl⟩,?_⟩
  · refine ⟨rfl,rfl,(by intro t ht; cases ht),rfl,(by intro e he; cases he),?_,?_,?_,?_⟩
    · simp [pathBases,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · simp [pathBases,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simp [pathBases,RowTransport,Qsig,QTys,QTy,QEff,Qempty,Eff.single]
    · simp [pathBases,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
  · exact ⟨rfl,(by intro i r k h; cases h),(by intro r h; cases h),
      Or.inl (by intro r h; cases h)⟩
  · rw [instantiated]; exact .done (annotation P)
  · exact ⟨by simp [Eff.WF,Eff.single,Ty.WFList],
      by simp [Eff.Canonical,Eff.norm,Eff.single]⟩

/-- 発行の実呼出しは、空引数の型付き呼出しである。 -/
theorem call_typed (P : Program) (Ψ : StoreTy) :
    HasTypeCQ P Model.builtins Ψ Qempty [] [] [] none
      (.app (.prim pathBasesName [] [] []) []) .pathBases (Eff.single processEnvironmentEff) [] := by
  have ha := call_arguments P Ψ
  exact .C_DependentApp (.V_Prim rfl ha.ranges (Model.sig_scoped P (b := pathBasesName) rfl).names
    ha.admissible ha.signature) ha.arguments

/-- 発行は専用の二遷移を使い、同じ σ の事象を宣言効果で覆う。 -/
theorem issue {P σ q k μ}
    (hv : q.view = .app (.prim pathBasesName [] [] []) [])
    (hn : NoHandler k (.prim pathBasesName)) (hσ : σ.Valid) :
    Step P Model.builtins σ (.run q k μ) none
      (.run (.mk q.capture (.issuePathBases pathBasesName)) k μ) ∧
    Step P Model.builtins σ (.run (.mk q.capture (.issuePathBases pathBasesName)) k μ)
      (some (.pathBases pathBasesName σ)) (.run (Closure.pure (.ret (.pathBases σ))) k μ) ∧
    Event.Covered Model.builtins [] [] pathBases.eff (.pathBases pathBasesName σ) ∧
    ∃ bs, Model.builtins.effects processEnvironmentEff = some bs ∧ pathBasesName ∈ bs := by
  exact ⟨.E_PathBasesApply hv rfl rfl hn,.E_IssuePathBases rfl rfl rfl rfl hσ,
    Eff.Covers.refl [] [] _,(Model.pathBases_shape (b := pathBasesName) rfl rfl).membership⟩

/-- let の結果として発行した同じ σ を、At の bases の束縛に渡す。 -/
theorem issue_to_at (P : Program) (σ : PathEnv) (kind name shape pattern input index)
    (hσ : σ.Valid) :
    let body := Comp.checkAt kind name shape (some (.var 0)) pattern input index
    Steps P Model.builtins σ
      (.run (Closure.pure (.letIn (.app (.prim pathBasesName [] [] []) []) body)) [] Store.empty)
      [.pathBases pathBasesName σ]
      (.run ((Closure.pure body).apply [.pathBases σ]) [] Store.empty) := by
  dsimp
  let body := Comp.checkAt kind name shape (some (.var 0)) pattern input index
  have hi := issue (P := P) (σ := σ)
    (q := Closure.pure (.app (.prim pathBasesName [] [] []) []))
    (k := [.letF (Closure.pure body)]) (μ := Store.empty) rfl (by simp [NoHandler]) hσ
  exact .cons (.E_Let rfl) (.cons hi.1 (.cons hi.2.1 (.cons (.E_Return rfl) .nil)))

/-- At の成功した準備は、発行した σ と同じ snapshot だけを使う。 -/
theorem issued_current {σ kind name pattern input index snap pat target bound}
    (hp : AtPrepared Model.builtins (Capture.empty.extendMany [.pathBases σ]) kind name
      (some (.var 0)) pattern input index snap pat target bound) :
    ∀ ρ, snap = some ρ → ρ = σ := by
  apply hp.current
  · exact ⟨rfl,trivial⟩
  · intro b hb; cases hb; trivial

/-- At の index の起点は、その状態の準備に必要な束縛である。 -/
theorem required_base (P : Program) (σ : PathEnv) (kind name shape pattern input b p) :
    let s := State.run ((Closure.pure (.checkAt kind name shape (some (.var 0)) pattern input
      (.fixed (.based b p)))).apply [.pathBases σ]) [] Store.empty
    PathEnv.Required P Model.builtins s (.base b) ∧
      PreparationNode.Reachable P Model.builtins (.state s) (.range (.based b p)) := by
  dsimp
  have reach : PreparationNode.Reachable P Model.builtins
      (.state (.run ((Closure.pure (.checkAt kind name shape (some (.var 0)) pattern input
        (.fixed (.based b p)))).apply [.pathBases σ]) [] Store.empty)) (.range (.based b p)) :=
    .child (.child (.child .root (Or.inl rfl)) (Or.inr rfl)) (Or.inr (Or.inl rfl))
  exact ⟨.base reach,reach⟩

/-- 必要な束縛を準備の条件から供給し、同じ範囲の解決へ渡す。 -/
example {P σ kind name shape pattern input b p}
    (ready : σ.Ready P Model.builtins
      (.run ((Closure.pure (.checkAt kind name shape (some (.var 0)) pattern input
        (.fixed (.based b p)))).apply [.pathBases σ]) [] Store.empty)) :
    (∃ w, σ.Binds b w) ∧ (∃ rs, (RangeExpr.based b p).resolve σ = some rs) := by
  have req := required_base P σ kind name shape pattern input b p
  exact ⟨ready.2 (.base b) req.1,ready.resolve_required req.2⟩

/-- 発行した token を束縛した At は、準備失敗・検査成功・検査失敗の全場合で進む。 -/
theorem issued_at (P : Program) (σ : PathEnv) (kind name shape pattern input index) :
    ∃ next, Step P Model.builtins σ
      (.run ((Closure.pure (.checkAt kind name shape (some (.var 0)) pattern input index)).apply
        [.pathBases σ]) [] Store.empty) none next := by
  cases hp : AtPrepare Model.builtins (Capture.empty.extendMany [.pathBases σ]) kind name
      (some (.var 0)) pattern input index with
  | error detail => exact ⟨_,.E_AtPrepareError rfl hp⟩
  | ok result =>
    obtain ⟨snap,pat,target,bound⟩ := result
    have current := issued_current hp
    cases hc : checkAt snap kind pat target bound with
    | ok t => exact ⟨_,.E_AtOk rfl hp current hc⟩
    | error detail => exact ⟨_,.E_AtError rfl hp current hc⟩

/-- cwd の相対入力では、任意の有効な発行 snapshot で準備が成功する。 -/
example (σ : PathEnv) (hσ : σ.Valid) :
    AtPrepared Model.builtins (Capture.empty.extendMany [.pathBases σ]) .path "Scope.PathIn"
      (some (.var 0)) (.scopePattern (.based .cwd (.exact []))) (.const (.string "."))
      (.fixed (.based .cwd (.exact []))) (some σ) (.based .cwd (.exact []))
      (.relativePath []) (.based .cwd (.exact [])) ∧
    checkAt (some σ) .path (.based .cwd (.exact [])) (.relativePath [])
      (.based .cwd (.exact [])) = .ok (.path σ.cwd) := by
  refine ⟨AtPrepared.of_path_bases rfl rfl rfl rfl rfl hσ (by decide),?_⟩
  have empty : Scope.Domain.PathWordWF [] := by trivial
  simp [checkAt,resolveSnapshot,resolveTargetSnapshot,RangeExpr.resolve,TargetInput.resolve,
    PathEnv.lookup,PathPattern.atBase,Scope.Domain.Target.WF,Scope.Domain.Target.kind,
    RangeExpr.WF,RangeExpr.FitsKind,Scope.Domain.Range.WF,Scope.Domain.Range.Mem,
    Scope.Domain.PathPattern.Matches,Scope.Domain.PathPattern.WF,hσ.2.1,empty]

/-- 全ての起点と空の secrets 一覧を供給すれば、全ての必要束縛を満たす。 -/
example (P : Program) (s : State) :
    (PathEnv.mk [] [] [] (some []) (some []) (some [])).Ready P Model.builtins s := by
  refine ⟨by simp [PathEnv.Valid,Scope.Domain.PathWordWF],?_⟩
  intro req _
  cases req with
  | base b => cases b <;> exact ⟨[],rfl⟩
  | secrets => rfl

/-- 必要な work が未束縛なら、同じ At の状態を Ready と扱わない。 -/
example (P : Program) (σ : PathEnv) (kind name shape pattern input p)
    (hw : σ.work = none) :
    ¬ σ.Ready P Model.builtins
      (.run ((Closure.pure (.checkAt kind name shape (some (.var 0)) pattern input
        (.fixed (.based .work p)))).apply [.pathBases σ]) [] Store.empty) := by
  intro ready
  obtain ⟨w,h⟩ := ready.2 (.base .work) (required_base P σ kind name shape pattern input .work p).1
  simp [PathEnv.Binds,PathEnv.lookup,hw] at h

/-- 型付きの空呼出しから、同じ σ を持つ発行事象と At の全分岐へ接続する。 -/
example (P : Program) (Ψ : StoreTy) (σ : PathEnv) (kind name shape pattern input index)
    (hσ : σ.Valid) :
    HasTypeCQ P Model.builtins Ψ Qempty [] [] [] none
      (.app (.prim pathBasesName [] [] []) []) .pathBases (Eff.single processEnvironmentEff) [] ∧
    (let body := Comp.checkAt kind name shape (some (.var 0)) pattern input index
     Steps P Model.builtins σ
       (.run (Closure.pure (.letIn (.app (.prim pathBasesName [] [] []) []) body)) [] Store.empty)
       [.pathBases pathBasesName σ]
       (.run ((Closure.pure body).apply [.pathBases σ]) [] Store.empty)) ∧
    ∃ next, Step P Model.builtins σ
      (.run ((Closure.pure (.checkAt kind name shape (some (.var 0)) pattern input index)).apply
        [.pathBases σ]) [] Store.empty) none next :=
  ⟨call_typed P Ψ,issue_to_at P σ kind name shape pattern input index hσ,
    issued_at P σ kind name shape pattern input index⟩

end
end Benitoite.Release.Refinement.ModelTargetsExamples
