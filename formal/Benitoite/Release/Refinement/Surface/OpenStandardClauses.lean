import Benitoite.Release.Refinement.StandardModelScoped
import Benitoite.Release.Refinement.StandardModelCoreRows

/-! # 合成表の操作の節の署名の範囲閉性と正規性 -/
namespace Benitoite.Release.Refinement.Surface.OpenStandardClauses
noncomputable section

def ClauseShape (s : PrimSig) (S : RangeExpr) : Prop :=
    (∀ a ∈ s.params.map (Ty.instTarget (List.replicate s.rkinds.length S)),
      a.RangesScoped 0 ∧ a.norm = a) ∧
      s.ret.RangesScoped 0 ∧ s.ret.norm = s.ret

theorem primitive_instTarget_closed_normal (row : StandardModel.Primitive)
    (S : RangeExpr) (hop : row.signature.opEff ≠ none) : ClauseShape row.signature S := by
  cases row
  all_goals try exact absurd rfl hop
  all_goals first
    | change ClauseShape ScopeSignatures.pathBases S
    | change ClauseShape ScopeSignatures.appendBytesIn S
    | change ClauseShape ScopeSignatures.appendTextIn S
    | change ClauseShape ScopeSignatures.readBytesIn S
    | change ClauseShape ModelTargets.readTextSig S
    | change ClauseShape ScopeSignatures.readTextIn S
    | change ClauseShape ScopeSignatures.writeBytesIn S
    | change ClauseShape ScopeSignatures.writeTextIn S
    | change ClauseShape ScopeSignatures.sendIn S
    | change ClauseShape ModelTargets.exitSig S
    | change ClauseShape ModelTargets.printSig S
  all_goals simp [ClauseShape, ScopeSignatures.pathBases, ScopeSignatures.appendBytesIn,
    ScopeSignatures.appendTextIn, ScopeSignatures.readBytesIn, ScopeSignatures.readTextIn,
    ScopeSignatures.sendIn,
    ScopeSignatures.ioIn, ScopeSignatures.unscopedIO, ModelTargets.readTextSig,
    ModelTargets.exitSig, ModelTargets.printSig, Ty.instTarget, RangeIx.inst,
    Ty.RangesScoped, rangesScopedTypes, RangeIx.WF, RangeIx.top,
    Ty.norm, Ty.normTys]

theorem primitive_clause {P : Refinement.Program} {B : Builtins} {b s sg S}
    (hstd : B = StandardModel.builtins P) (hs : B.sig b = some s)
    (hsg : opSigAt P B S (.prim b) = some sg) :
    (∀ a ∈ sg.params, a.RangesScoped 0 ∧ a.norm = a) ∧
      sg.ret.RangesScoped 0 ∧ sg.ret.norm = sg.ret := by
  subst B
  obtain ⟨row, _, _, rfl⟩ := (StandardModel.builtins_lookup_iff P b s).mp hs
  simp only [opSigAt, hs] at hsg
  obtain ⟨l, hl, he⟩ := Option.map_eq_some_iff.mp hsg
  cases he
  exact primitive_instTarget_closed_normal row S (by simp [hl])

theorem standard_opSigAt_prim {externals b s sg S}
    (hs : (StandardModel.builtins (StandardModel.program externals)).sig b = some s)
    (hsg : opSigAt (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals)) S (.prim b) = some sg) :
    (∀ a ∈ sg.params, a.RangesScoped 0 ∧ a.norm = a) ∧
      sg.ret.RangesScoped 0 ∧ sg.ret.norm = sg.ret :=
  primitive_clause rfl hs hsg

theorem standard_clauseSig_prim {externals e b sg}
    (h : ClauseSig (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals)) e (.prim b) sg) :
    (∀ a ∈ sg.params, a.RangesScoped 0 ∧ a.norm = a) ∧
      sg.ret.RangesScoped 0 ∧ sg.ret.norm = sg.ret := by
  obtain ⟨S, _, hs, _⟩ := h
  cases hb : (StandardModel.builtins (StandardModel.program externals)).sig b with
  | none => simp only [opSigAt, hb] at hs; cases hs
  | some s => exact standard_opSigAt_prim hb hs

end
end Benitoite.Release.Refinement.Surface.OpenStandardClauses
