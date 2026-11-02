import Benitoite.Release.Refinement.IntervalConnection

/-! # 値の関係を強めるときに、元の入力だけでは得られない構造の情報 -/
namespace Benitoite.Release.Refinement.IntervalConnection.RelationBoundary
noncomputable section

/-- Unit と構成子の形を区別するために必要な条件。値の関係の代用ではない。 -/
def ValueShape (c : Benitoite.Interval.ConcreteValue) (v : Val) : Prop :=
  match c with
  | .unit => v = .const .unit
  | .con _ _ tag _ => ∃ ts vs, v = .con tag ts vs
  | _ => True

/-- 強い関係は、二つの旧署名の反例で用いる必要条件を満たす。 -/
theorem ValueRel.shape {c v} (h : ValueRel c v) : ValueShape c v := by
  cases h <;> first | rfl | trivial | exact ⟨_,_,rfl⟩

/-- 近似の一致と Ground だけでは、要求される Unit の形を得られない。 -/
theorem ground_signature_obstruction :
    (.unit : Benitoite.Interval.ConcreteValue).toApprox = (Val.con "Result.Error" [] []).toApprox ∧
    ¬ ValueRel .unit (.con "Result.Error" [] []) ∧
    ¬ (∀ (c : Benitoite.Interval.ConcreteValue) (v : Val),
      c.toApprox = v.toApprox → v.Ground → ValueShape c v) := by
  refine ⟨rfl,?_,?_⟩
  · intro h; have hs := ValueRel.shape h; cases hs
  intro relation
  have mismatch := relation .unit (.con "Result.Error" [] []) rfl (by simp [Val.Ground,Val.ClosedAt,Val.ClosedList])
  cases mismatch

private theorem escape_source (P : Program) (B : Builtins) (σ : PathEnv) :
    StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) := by
  have ha : Ty.Annotation P [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hq := ClosureTy.pure (B := B) (Ψ := StoreTy.empty)
    (.C_Escape (ε := Eff.empty) (.V_Const (c := .unit) (by trivial)) ha) ha.done_empty
    (by intro r hr; cases hr; exact ⟨trivial,trivial⟩) rfl (by intro r hr; cases hr; rfl)
  have hk := ContTy.K_Mark (ContTy.K_Empty (R := none) (P := P) (B := B) (σ := σ)
    (Ψ := StoreTy.empty) (show Eff.Sub Eff.empty Eff.empty from ⟨fun _ h => h,fun _ h => h⟩) ha) ha
  exact ⟨StoreTy.empty,some (.base .unit),.base .unit,.base .unit,Eff.empty,Eff.empty,
    StoreOk.empty _ _ σ,hq,⟨fun _ h => h,fun _ h => h⟩,hk,by trivial,by trivial,
    (by intro f hf; cases List.mem_singleton.mp hf; trivial),(by intro l c h; cases h)⟩

/-- 同じ適格な表と型付きの元状態があっても、近似だけから構成子の対応は得られない。 -/
theorem marked_signature_obstruction :
    ∃ (P : Program) (B : Builtins) (σ : PathEnv),
      P.WellFormed ∧ P.WellTyped B ∧ B.CoreAssumptions P ∧ σ.Valid ∧
      StateTyE P B σ Eff.empty (.run (Closure.pure (.escape (.const .unit))) [.mark] Store.empty) ∧
      (Benitoite.Interval.ConcreteValue.con "Result" [] "Result.Ok" [.unit]).toApprox = (Val.const .unit).toApprox ∧
      ¬ (∃ (q : Closure) (μ : Store) (v : Val),
        State.run (Closure.pure (.ret (.const .unit))) [] Store.empty = .run q [] μ ∧
        q.view = .ret v ∧ ValueShape (.con "Result" [] "Result.Ok" [.unit]) v) := by
  obtain ⟨σ,hσ,hP,hPB,hB,_⟩ := NormalReplyExamples.concrete_normal_replies
  refine ⟨_,_,σ,hP,hPB,hB,hσ,escape_source _ _ σ,rfl,?_⟩
  rintro ⟨q,μ,v,he,hv,hshape⟩
  obtain ⟨rfl,_,rfl⟩ := State.run.inj he
  cases Comp.ret.inj hv
  obtain ⟨ts,vs,hcon⟩ := hshape
  cases hcon

end
end Benitoite.Release.Refinement.IntervalConnection.RelationBoundary
