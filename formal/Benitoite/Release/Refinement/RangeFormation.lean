import Benitoite.Release.Refinement.TypeVariables
import Benitoite.Release.Refinement.PrimitiveScoped
import Benitoite.Release.Refinement.Context.Declarations
import Benitoite.Release.Refinement.RangeTypeProperties

/-! # 四名前空間の上限と同時置換（設計書 01-12「コア計算と脱糖」） -/
namespace Benitoite.Release.Refinement

theorem RangeIx.wf_inst {nr : Nat} {ix : RangeIx} {rs : List RangeExpr}
    (h : ix.WF nr) (hn : rs.length = nr) : (ix.inst rs).WF 0 := by
  cases ix with
  | fixed r => trivial
  | rvar i =>
    have hi : i < rs.length := by simpa only [hn, RangeIx.WF] using h
    simp only [RangeIx.inst, List.getElem?_eq_getElem hi, RangeIx.WF]

theorem Ty.SourceScoped.bind {nr nt ne nv mr mt me mv : Nat} {a : Ty} {θ : SubstEnv}
    (h : a.SourceScoped nr nt ne nv) (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (a.bind θ).SourceScoped mr mt me mv := by
  have wf := a.bind_wf h.1 hw
  exact ⟨wf,
    (Ty.rowsIn_iff_support _ _).mpr
      (Ty.norm_support _ (Ty.rawBind_support _ _ θ a
        ((Ty.rowsIn_iff_support _ _).mp h.2.1) he)),
    (Ty.rangesScoped_iff_support _ wf).mpr
      (Ty.norm_support _ (Ty.rawBind_support _ _ θ a
        ((Ty.rangesScoped_iff_support _ h.1).mp h.2.2) hr))⟩

noncomputable section

theorem SupportTransport.rangesOnly {p q : Atom → Prop} (rs : List RangeExpr)
    (h : ∀ a, p a → q (a.instR rs)) : SupportTransport p q (.rangesOnly rs) := by
  refine ⟨fun _ => trivial, by simp [SubstEnv.rangesOnly], ?_⟩
  intro a ha
  constructor
  · intro b hb
    rcases (Eff.mem_rawBind (.rangesOnly rs) (.mk (fun x => decide (x=a)) []) b).mp hb with
      ⟨x,hx,he,_⟩ | ⟨i,f,hf,_,_⟩
    · have hx' : x = a := by simpa [Eff.mem,Eff.test,Eff.atoms] using hx
      subst x
      subst b
      exact h a ha
    · simp [SubstEnv.rangesOnly] at hf
  · simp [SubstEnv.rangesOnly,rawBindTys,rowFails,Ty.SupportList]

theorem SubstEnv.rangesOnly_wfImages {nr nt nv : Nat} {rs : List RangeExpr}
    (hn : rs.length = nr) : (SubstEnv.rangesOnly rs).WFImages nr nt nv 0 nt nv := by
  refine ⟨fun _ hi => hi, by simp [SubstEnv.rangesOnly], ?_, ?_, ?_⟩
  · intro ix hi; exact RangeIx.wf_inst hi hn
  · intro i hi t ht; cases ht; exact hi
  · intro i; simp [SubstEnv.rangesOnly, Ordinary, Ty.core]

theorem Tel.sourceScoped_bind {nr nt ne nv mr mt me mv : Nat} {t : Tel} {θ : SubstEnv}
    (h : (Ty.dependentFn t).SourceScoped nr nt ne nv)
    (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (Ty.dependentFn (Tel.bind θ t)).SourceScoped mr mt me mv := by
  have wf := Tel.rawBind_norm_wf t h.1 hw
  exact ⟨wf,
    (Tel.rowsIn_iff_support _ _).mpr
      (Tel.norm_support _ (Tel.rawBind_support _ _ θ t
        ((Tel.rowsIn_iff_support _ _).mp h.2.1) he)),
    (Tel.rangesScoped_iff_support _ wf).mpr
      (Tel.norm_support _ (Tel.rawBind_support _ _ θ t
        ((Tel.rangesScoped_iff_support _ h.1).mp h.2.2) hr))⟩

theorem PrimSig.Scoped.inst_source {P : Program} {s : PrimSig} (h : s.Scoped P)
    {rs : List RangeExpr} (hn : rs.length = s.rkinds.length) :
    (Ty.dependentFn (Tel.instR rs s.tel)).SourceScoped 0 s.tparams.length s.neffs 0 := by
  rw [Tel.instR_eq_bind]
  refine Tel.sourceScoped_bind h.source (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial


theorem PrimSig.Scoped.inst {P : Program} {s : PrimSig} (h : s.Scoped P)
    {rs : List RangeExpr} (hn : rs.length = s.rkinds.length) :
    SignatureScoped P s.tparams s.neffs (Tel.instR rs s.tel) := by
  have hs := h.inst_source hn
  refine ⟨hs,hs.2.1,?_,⟨hs.1,?_,?_⟩⟩
  · exact kindsTel_norm (Ty.HasKind.rawMapRanges (a := .dependentFn s.tel) h.kinds _)
  · exact Tel.sorted_norm (h.sorted.rawMapRanges _)
  · exact Tel.Declared.norm (h.declared.rawMapRanges _)

theorem Builtins.CoreAssumptions.opSignaturesWF {P B} (h : Builtins.CoreAssumptions P B) :
    B.OpSignaturesWF := fun b s hs ho => ((h.sig_scoped b s hs).operation ho).1

theorem Eff.SourceScoped.bind {nr nt ne nv mr mt me mv : Nat} {e : Eff} {θ : SubstEnv}
    (h : e.SourceScoped nr nt ne nv) (hw : θ.WFImages nr nt nv mr mt mv)
    (he : SupportTransport (rowCondition (· < ne)) (rowCondition (· < me)) θ)
    (hr : SupportTransport (rangeCondition nr) (rangeCondition mr) θ) :
    (Eff.bind θ e).SourceScoped mr mt me mv := by
  have wf := Eff.rawBind_norm_wf e h.1 hw
  exact ⟨wf,
    (Eff.rowsIn_iff_support _ _).mpr
      (Eff.norm_support _ (Eff.rawBind_support _ _ θ e
        ((Eff.rowsIn_iff_support _ _).mp h.2.1) he)),
    (Eff.rangesScoped_iff_support _ wf).mpr
      (Eff.norm_support _ (Eff.rawBind_support _ _ θ e
        ((Eff.rangesScoped_iff_support _ h.1).mp h.2.2) hr))⟩

theorem Ty.SourceScoped.instR {nr nt ne nv : Nat} {a : Ty} {rs : List RangeExpr}
    (h : a.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (a.instR rs).SourceScoped 0 nt ne nv := by
  rw [Ty.instR_eq_bind]
  refine Ty.SourceScoped.bind h (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial

theorem Eff.SourceScoped.instR {nr nt ne nv : Nat} {e : Eff} {rs : List RangeExpr}
    (h : e.SourceScoped nr nt ne nv) (hn : rs.length = nr) :
    (Eff.instR rs e).SourceScoped 0 nt ne nv := by
  rw [Eff.instR_eq_bind]
  refine Eff.SourceScoped.bind h (SubstEnv.rangesOnly_wfImages hn)
    (SupportTransport.rangesOnly rs ?_) (SupportTransport.rangesOnly rs ?_)
  · intro a ha; cases a <;> exact ha
  · intro a ha; cases a with
    | name l ix => exact RangeIx.wf_inst ha hn
    | rho i => trivial

end
end Benitoite.Release.Refinement
