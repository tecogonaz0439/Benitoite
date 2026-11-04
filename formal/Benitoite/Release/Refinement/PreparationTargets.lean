import Benitoite.Release.Refinement.SourcePreparation
import Benitoite.Release.Refinement.Source

/-! # 必要な束縛からの解決とソースの適格性 -/
namespace Benitoite.Release.Refinement

theorem PathEnv.Ready.resolve_required {P B σ s r}
    (ready : σ.Ready P B s)
    (reach : PreparationNode.Reachable P B (.state s) (.range r)) :
    ∃ rs, r.resolve σ = some rs := by
  cases r with
  | absolute r => exact ⟨[r],rfl⟩
  | based b p =>
    obtain ⟨w,hw⟩ := ready.2 (.base b) (.base reach)
    exact ⟨[.path (PathPattern.atBase w p)],by simp only [RangeExpr.resolve,PathEnv.Binds] at hw ⊢; rw [hw]; rfl⟩
  | secrets =>
    have hs := ready.2 .secrets (.secrets reach)
    cases he : σ.secrets with
    | none => simp [he] at hs
    | some ps => exact ⟨ps.map Scope.Domain.Range.path,by simp [RangeExpr.resolve,he]⟩

mutual
  theorem Val.Source.adequate {v : Val} (h : v.Source) (σ : PathEnv) : v.Adequate σ := by
    cases v <;> try {simp only [Val.Source] at h; contradiction} <;> try trivial
    case lam ns ps m => exact Comp.Source.adequate (m := m) h σ
    case dependentLam t m => exact Comp.Source.adequate (m := m) h σ
    case con c ts vs => exact sourceVals_adequate h σ
    case list vs => exact sourceVals_adequate h σ
    case dict i ts vs => exact sourceVals_adequate h σ
    case setV vs => exact sourceVals_adequate h σ
    case mapV ks vs => exact ⟨sourceVals_adequate h.1 σ,sourceVals_adequate h.2 σ⟩
    case super v cl => exact Val.Source.adequate (v := v) h σ
  termination_by sizeOf v
  theorem sourceVals_adequate {vs : List Val} (h : sourceVals vs) (σ : PathEnv) : adequateVals σ vs := by
    cases vs with
    | nil => trivial
    | cons v vs =>
      simp only [sourceVals,adequateVals] at h ⊢
      exact ⟨Val.Source.adequate h.1 σ,sourceVals_adequate h.2 σ⟩
  termination_by sizeOf vs
  theorem Comp.Source.adequate {m : Comp} (h : m.Source) (σ : PathEnv) : m.Adequate σ := by
    cases m <;> try trivial
    case builderLet k m => exact Comp.Source.adequate (m := m) h σ
    case builderOp k op r vs => exact sourceVals_adequate h σ
    case ret v => exact Val.Source.adequate h σ
    case escape v => exact Val.Source.adequate h σ
    case letIn m n => exact ⟨Comp.Source.adequate h.1 σ,Comp.Source.adequate h.2 σ⟩
    case app f vs => exact ⟨Val.Source.adequate h.1 σ,sourceVals_adequate h.2 σ⟩
    case ite v m n => exact ⟨Val.Source.adequate h.1 σ,Comp.Source.adequate h.2.1 σ,Comp.Source.adequate h.2.2 σ⟩
    case «match» v arms => exact ⟨Val.Source.adequate h.1 σ,sourceArms_adequate h.2 σ⟩
    case lazyC m => exact Comp.Source.adequate (m := m) h σ
    case use v m => exact ⟨Val.Source.adequate h.1 σ,Comp.Source.adequate h.2 σ⟩
    case handle m cs => exact ⟨Comp.Source.adequate h.1 σ,sourceClauses_adequate h.2 σ⟩
    case resume k v => exact ⟨Val.Source.adequate h.1 σ,Val.Source.adequate h.2 σ⟩
    case meth f m ts es vs => exact ⟨Val.Source.adequate h.1 σ,sourceVals_adequate h.2 σ⟩
    case externalCall f ts vs => exact sourceVals_adequate h σ
    case checkAt k o sh bs p v ix =>
      rw [Comp.Source.eq_def] at h
      rw [Comp.Adequate.eq_def]
      obtain ⟨hb,hp,hv⟩ := h
      refine ⟨?_,Val.Source.adequate hp σ,Val.Source.adequate hv σ⟩
      cases bs with
      | none => trivial
      | some b => exact Val.Source.adequate hb σ
  termination_by sizeOf m
  theorem sourceArms_adequate {arms : List Arm} (h : sourceArms arms) (σ : PathEnv) : adequateArms σ arms := by
    cases arms with
    | nil => trivial
    | cons a arms =>
      cases a with
      | mk alts guard body =>
        rw [sourceArms.eq_def] at h
        rw [adequateArms.eq_def]
        obtain ⟨hg,hbody,harms⟩ := h
        refine ⟨?_,Comp.Source.adequate hbody σ,sourceArms_adequate harms σ⟩
        cases guard with
        | none => trivial
        | some g => exact Comp.Source.adequate hg σ
  termination_by sizeOf arms
  theorem sourceClauses_adequate {cs : List Clause} (h : sourceClauses cs) (σ : PathEnv) : adequateClauses σ cs := by
    cases cs with
    | nil => trivial
    | cons c cs => cases c <;> simp only [sourceClauses,adequateClauses] at h ⊢ <;> exact ⟨Comp.Source.adequate h.1 σ,sourceClauses_adequate h.2 σ⟩
  termination_by sizeOf cs
end

noncomputable section

/-- ソースの適格性を同じ開始状態の型付けへ供給する。 -/
theorem InitialPrepared.source_state_of_source {P B σ m a e}
    (h : InitialPrepared P B σ (.run (Closure.pure m) [] Store.empty))
    (hext : P.ExternalWF) (hb : HasTypeC P B StoreTy.empty [] [] [] none m a e)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e)))
    (hc : m.ClosedAt 0 0) (hsource : m.Source) (he : BuiltinOnly P B e) :
    StateTy P B σ (.run (Closure.pure m) [] Store.empty) ∧
      σ.Ready P B (.run (Closure.pure m) [] Store.empty) ∧ P.ExternalWF :=
  h.source_state hext hb ha hc (hsource.adequate σ) he

example {P B σ}
    (h : InitialPrepared P B σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty))
    (hext : P.ExternalWF) :
    StateTy P B σ (.run (Closure.pure (.ret (.const .unit))) [] Store.empty) := by
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  exact (h.source_state_of_source hext (.C_Return (.V_Const trivial)) ha.done_empty
    trivial (by trivial) ⟨rfl,by intro a ha; cases ha⟩).1

example {P B σ s b p} (h : σ.Ready P B s)
    (hr : PreparationNode.Reachable P B (.state s) (.range (.based b p))) :
    ∃ rs, (RangeExpr.based b p).resolve σ = some rs := h.resolve_required hr

/-- 未指定と空の一覧は解決の成否が異なる。空の一覧へ所属する対象はない。 -/
example (σ : PathEnv) (k : Scope.Domain.Kind) (t : Scope.Domain.Target) :
    RangeExpr.secrets.resolve {σ with secrets := none} = none ∧
    RangeExpr.secrets.resolve {σ with secrets := some []} = some [] ∧
    ¬ RangeExpr.secrets.Mem {σ with secrets := some []} k t := by
  simp [RangeExpr.resolve,RangeExpr.Mem]

example (σ : PathEnv) (p : Scope.Domain.PathPattern) :
    (RangeExpr.based .work p).resolve {σ with work := none} = none ∧
    (RangeExpr.based .tmp p).resolve {σ with tmp := none} = none ∧
    σ.lookup .root = some σ.root ∧ σ.lookup .cwd = some σ.cwd ∧
    σ.lookup .home = some σ.home := ⟨rfl,rfl,rfl,rfl,rfl⟩

end
end Benitoite.Release.Refinement
