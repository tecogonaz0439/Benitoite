import Benitoite.Release.Refinement.Preparation
import Benitoite.Release.Refinement.PathBasesLeaves

/-! # 型付けたソースから固定した開始状態への接続 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 表層からの合成と外部応答の存在は含めず、同じ開始状態の証拠を組み合わせる。 -/
theorem InitialPrepared.source_state {P B σ m a e}
    (h : InitialPrepared P B σ (.run (Closure.pure m) [] Store.empty))
    (hext : P.ExternalWF) (hb : HasTypeC P B StoreTy.empty [] [] [] none m a e)
    (ha : Ty.Annotation P [] [] (.dependentFn (.done a e)))
    (hc : m.ClosedAt 0 0) (had : m.Adequate σ) (he : BuiltinOnly P B e) :
    StateTy P B σ (.run (Closure.pure m) [] Store.empty) ∧
      σ.Ready P B (.run (Closure.pure m) [] Store.empty) ∧ P.ExternalWF := by
  have hr : Ty.Annotation P [] [] a.norm := ⟨Ty.wf_norm ha.wf.1,Ty.sorted_norm ha.sorted.1,ha.declared.1.norm⟩
  have hann : Ty.Annotation P [] [] (.dependentFn (.done a.norm e)) :=
    ⟨⟨hr.wf,ha.wf.2⟩,⟨hr.sorted,ha.sorted.2⟩,⟨hr.declared,ha.declared.2⟩⟩
  have hq := ClosureTy.pure (.C_Normal hb) hann (by intro r hr; cases hr)
    (Ty.norm_idem _) (by intro r hr; cases hr)
  refine ⟨⟨h.ready.1,e,he,?_⟩,h.ready,hext⟩
  refine ⟨StoreTy.empty,none,a.norm,a.norm,e,e,StoreOk.empty P B σ,hq,
    ⟨fun _ h => h,fun _ h => h⟩,.K_Empty ⟨fun _ h => h,fun _ h => h⟩ hr,
    ⟨trivial,had⟩,⟨trivial,hc⟩,?_,?_⟩
  · intro f hf; cases hf
  · intro l c hc; cases hc

end
end Benitoite.Release.Refinement
