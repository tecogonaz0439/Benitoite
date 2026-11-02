import Benitoite.Release.Refinement.LegacyControlEmbedding

namespace Benitoite.Release.Refinement
noncomputable section

theorem legacy_builder_contents (kind : Benitoite.Release.BuilderKind) :
    (embedBuilderKind kind).contents = embedTy kind.contents := by cases kind <;> rfl

theorem legacy_builder_parameters (op : BuilderOp) (kind : Benitoite.Release.BuilderKind) :
    op.parameters (embedBuilderKind kind) = embedTys (op.params kind) := by
  cases op <;> cases kind <;> rfl

theorem legacy_builder_result (op : BuilderOp) (kind : Benitoite.Release.BuilderKind) :
    op.resultType (embedBuilderKind kind) = embedTy (op.result kind) := by
  cases op <;> cases kind <;> rfl

theorem LegacyBuilderInput.kinded {K P0 κ C nv kind}
    (h : LegacyBuilderInput K P0 ⟨κ,C,0,nv⟩ kind) (count : κ.length = C.length) :
    TypeArgsKinded (embedProgramWithKinds K P0) (legacyTypeCtx C κ)
      [(embedBuilderKind kind).contents] [.value] := by
  rw [legacy_builder_contents]
  refine ⟨rfl,?_⟩
  intro i a k ha hk
  cases i with
  | succ i => simp at ha
  | zero =>
    simp only [List.getElem?_cons_zero,Option.some.injEq] at ha hk
    subst a; subst k
    exact ⟨by rw [legacyTypeCtx_kinds count]; exact h.1.1,fun _ => h.2⟩

theorem legacy_localRef {Ψ L ref kind}
    (h : Benitoite.Release.LocalRef.HasKind Ψ L ref kind) :
    LocalRef.HasKind (embedStoreTy Ψ) (L.map (Option.map embedBuilderKind)) ref (embedBuilderKind kind) := by
  cases h with
  | bound hi =>
    rename_i i
    have hl : L[i]? = some (some kind) := by
      unfold Benitoite.Release.LocalCtx.kindAt at hi
      cases hli : L[i]? with
      | none => simp [hli] at hi
      | some b => cases b <;> simp_all
    exact .bound (by simp only [List.getElem?_map,hl,Option.map_some])
  | loc hi => exact .loc (by simp only [embedStoreTy,hi,Option.map_some,embedLocTy])

namespace LegacyCompCases

theorem builderLet_case {K P0 B0 B κ Ψ Q C Γ R kind m a e L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.builderLet kind m) a e L))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C (none :: Γ) R m a e (some kind :: L))) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.builderLet kind m) a e L) := by
  intro Φ
  have kindInput : LegacyBuilderInput K P0 ⟨κ,C,0,Γ.length⟩ kind := reg.2.1.1
  apply HasTypeCQ.C_BuilderLet
    (by rw [legacy_builder_contents]; exact kindInput.1.annotation_at rfl reg.1.2.2.1 _)
    (kindInput.kinded reg.1.2.2.1) _ (legacy_comp_annotation reg).declared
  simpa only [Ctx.extendNone,LocalCtx.extend,List.map_cons,Option.map_none,Option.map_some,
    legacy_local_kind_shift,legacy_shiftVCtx,legacy_local_map,legacy_shiftVR,legacy_shiftV,legacy_shiftVEff]
    using body (Φ.map Pred.lift)

theorem builderOp_case {K P0 B0 B κ Ψ Q C Γ R kind op ref vs L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.builderOp kind op ref vs)
      (op.result kind) Benitoite.Release.Eff.empty L))
    (reference : Benitoite.Release.LocalRef.HasKind Ψ L ref kind)
    (args : LegacyJudgment.Embedded K P0 B (.values κ Ψ Q C Γ vs (op.params kind))) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.builderOp kind op ref vs)
      (op.result kind) Benitoite.Release.Eff.empty L) := by
  intro Φ
  have kindInput : LegacyBuilderInput K P0 ⟨κ,C,0,Γ.length⟩ kind := reg.2.1.1
  simpa only [embedComp,legacy_builder_result,legacy_empty] using
    HasTypeCQ.C_BuilderOp (R := R.map embedTy)
      (by rw [legacy_builder_contents]; exact kindInput.1.annotation_at rfl reg.1.2.2.1 _)
      (kindInput.kinded reg.1.2.2.1) (legacy_localRef reference)
      (by rw [legacy_builder_parameters]; exact args Φ)

end LegacyCompCases
end
end Benitoite.Release.Refinement
