import Benitoite.Release.Refinement.Canonical
import Benitoite.Release.Refinement.ClosureTyping
namespace Benitoite.Release.Refinement.ReviewLambdaBoundary
noncomputable section
abbrev U : Ty := .base .unit
abbrev raw : Ty := .refined U .truth
abbrev srcTel : Tel := .param "x" raw (.done (U.shiftV 1 0) Eff.empty)
abbrev nTel : Tel := .param "x" U (.done U Eff.empty)

theorem closeTel_src : Capture.empty.closeTel srcTel = nTel := by
  have h : Tel.WF 0 0 0 srcTel := ⟨⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,trivial,rfl⟩⟩
  exact (Tel.bind_values_of_wf_zero h _).trans (by
    simp [srcTel,nTel,Tel.norm,Ty.norm,Ty.refineNorm,Ty.core,Ty.refinementPredicates,Pred.conjuncts,
      Ty.packRefinements,U,raw,Ty.shiftV,Eff.norm,Eff.empty,Ty.normTys,Order.sortUnique])

theorem closeTel_lam : Capture.empty.closeTel (lambdaShape ["x"] [raw]) = nTel := by
  exact closeTel_src

/-- 篩 true の付いた仮引数を一つ持つ実際の閉包を `fn` で読み、逆転する。 -/
theorem lam1_dependent (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal Capture.empty (.lam ["x"] [raw] (.ret (.const .unit))))
      (.dependentFn nTel) := by
  have ha : Ty.Annotation P [] [] (.dependentFn nTel) :=
    ⟨⟨trivial,⟨trivial,trivial,rfl⟩⟩,⟨trivial,⟨trivial,trivial⟩⟩,⟨trivial,⟨trivial,trivial⟩⟩⟩
  have hs : Ty.Annotation P [] [] (.dependentFn srcTel) :=
    ⟨⟨⟨trivial,trivial,by simp [Ty.NotContCore,Ty.core]⟩,⟨trivial,trivial,rfl⟩⟩,
     ⟨⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩,⟨⟨trivial,trivial⟩,⟨trivial,trivial⟩⟩⟩
  have hb : DependentClosureTy P B Ψ (.mk Capture.empty (.ret (.const .unit)))
      (Capture.empty.closeTel srcTel) :=
    .mk (CaptureOk.empty P B _ _) (.param (.done (.C_Return (.V_Const trivial))))
      hs (by rw [closeTel_src]; exact ha)
  rw [closeTel_src] at hb
  change HasTypeVQ P B Ψ Qempty [] [] []
    (.closure (Capture.empty.closeTel (lambdaShape ["x"] [raw])) (.mk Capture.empty (.ret (.const .unit)))) _
  rw [closeTel_lam]
  exact .V_Closure ha ⟨⟨trivial,⟨trivial,trivial,rfl⟩⟩,⟨trivial,⟨trivial,trivial,rfl⟩⟩,by simp [Tel.SameInputs]⟩ hb

theorem lam1_fn (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] []
      (closeVal Capture.empty (.lam ["x"] [raw] (.ret (.const .unit))))
      (.fn ["x"] [U] U Eff.empty) := by
  have h : (Ty.dependentFn (Ty.toTel ["x"] [U] U Eff.empty)).norm = (Ty.fn ["x"] [U] U Eff.empty).norm :=
    Ty.norm_toTel ⟨rfl, by simp⟩
  have hd := lam1_dependent P B Ψ
  have h' : (Ty.dependentFn nTel) = Ty.dependentFn (Ty.toTel ["x"] [U] U Eff.empty) := rfl
  rw [h'] at hd
  exact hd.convert h ⟨⟨⟨rfl, by simp⟩,⟨trivial,trivial⟩,trivial,trivial,rfl⟩,⟨⟨trivial,trivial⟩,trivial,trivial⟩,⟨⟨trivial,trivial⟩,trivial,trivial⟩⟩

theorem lam1_extract (P : Program) (B : Builtins) (Ψ : StoreTy) :
    ∃ body rt t u, Ty.Annotation P [] [] (.dependentFn t) ∧ Tel.RuntimeShape rt t ∧
      DependentClosureTy P B Ψ body t ∧
      (Ty.fn ["x"] [U] U Eff.empty).fnCore = some u ∧ TelClosure [] [] t u ∧ t.Normal := by
  obtain ⟨t,u,ha,hr,hb,hu,hc⟩ := (lam1_fn P B Ψ).inv_closure (runtime := nTel) (body := .mk Capture.empty (.ret (.const .unit))) (by
    change Val.closure (Capture.empty.closeTel (lambdaShape ["x"] [raw])) _ = _
    rw [closeTel_lam])
  refine ⟨_,_,t,u,ha,hr,hb,hu,hc,?_⟩
  exact hb.normal
end
end Benitoite.Release.Refinement.ReviewLambdaBoundary
#print axioms Benitoite.Release.Refinement.ReviewLambdaBoundary.lam1_extract
