import Benitoite.Release.Refinement.StandardModelSubstitution
import Benitoite.Release.Refinement.StandardModelScoped
import Benitoite.Release.Refinement.RangeFormation
import Benitoite.Release.Refinement.StandardModelWellFormed
import Benitoite.Release.Refinement.Surface.OpenPatterns
import Benitoite.Release.Refinement.Surface.OpenStandardClauses
import Benitoite.Release.Refinement.Surface.OpenSurfaceHandlers

/-! # 合成表の許容と範囲の具体化

範囲の具体化は制約の骨格を変えず、List.sort の順序の検査も保つ。
-/
namespace Benitoite.Release.Refinement.Surface.RangeStandard
noncomputable section

/-- 合成表の制約の照合は、範囲の具体化で同値である。 -/
theorem sat_instR (P : Refinement.Program) (C : List TParam) (a : Ty) (p : TParam)
    (rs : List RangeExpr) :
    (StandardModel.builtins P).sat C (a.instR rs) p ↔ (StandardModel.builtins P).sat C a p := by
  change ModelConstraints.sat StandardModel.summaries C (a.instR rs) p ↔ _
  rw [Ty.instR_eq_bind]
  exact ModelConstraints.sat_bind_values _ _ _ _ _ (fun _ => rfl)

private theorem scalar_core (a : Ty) :
    StandardScalar.scalarTypeCore a.core = StandardScalar.scalarTypeCore a := by
  cases a <;> try rfl
  case refined a _ => exact scalar_core a

private theorem scalar_refine (a : Ty) (p : Pred) :
    StandardScalar.scalarTypeCore (a.refineNorm p) = StandardScalar.scalarTypeCore a := by
  unfold Ty.refineNorm
  cases (a.refinementPredicates ++ p.conjuncts) <;>
    simpa only [Ty.packRefinements, StandardScalar.scalarTypeCore] using scalar_core a

private theorem scalar_fold (t : Tel) : StandardScalar.scalarTypeCore (Ty.foldFn t) = none := by
  unfold Ty.foldFn
  split <;> rfl

private theorem scalar_ranges (a : Ty) (rs : List RangeExpr) :
    StandardScalar.scalarTypeCore (a.instR rs) = StandardScalar.scalarTypeCore a := by
  cases a <;> simp only [Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.rawMapRanges, Ty.norm,
    StandardScalar.scalarTypeCore]
  case refined a p =>
    rw [scalar_refine]
    exact scalar_ranges a rs
  case dependentFn t => exact scalar_fold _

/-- 合成表のすべての組込みで、型引数の許容は範囲の具体化で保たれる。 -/
theorem admits_instR {P : Refinement.Program} {b s C ts} (hs : (StandardModel.builtins P).sig b = some s)
    (h : s.admits C ts) (rs : List RangeExpr) : s.admits C (ts.map (Ty.instR rs)) := by
  obtain ⟨row, _, rfl, rfl⟩ := (StandardModel.builtins_lookup_iff P b s).mp hs
  rcases StandardModel.admits_form row with form | rfl
  · apply (form _ _).mpr
    apply ModelConstraints.admits_map (S := StandardModel.summaries) (f := Ty.instR rs) _ ((form _ _).mp h)
    intro a p ha
    exact (sat_instR P C a p rs).mpr ha
  · change (_ ∧ _ ∧ _) at h ⊢
    refine ⟨by simpa using h.1, ?_, ?_⟩
    · intro z
      cases z
    · intro _ a ha
      obtain ⟨t, ht, rfl⟩ := List.mem_map.mp ha
      have ordered := h.2.2 rfl t ht
      simpa only [StandardListRemainingResponse.orderedType, scalar_ranges] using ordered

/-- 合成表の署名は、宣言した範囲の深さで形成されている。 -/
theorem signature_ranges (externals : List (ExternalKey × ExternalDecl)) {b s}
    (hs : (StandardModel.builtins (StandardModel.program externals)).sig b = some s) :
    s.tel.RangesScoped s.rkinds.length :=
  (StandardModel.sig_scoped externals b s hs).source.2.2

/-- 合成表の構成子の欄に自由な範囲変数はない。 -/
theorem pattern_ranges_closed (externals : List (ExternalKey × ExternalDecl)) :
    PatternRangesClosed (StandardModel.program externals) :=
  fun c cd hc a ha => ((StandardModel.cons_scoped externals c cd hc).2 a ha).1.2.2

/-- 合成プログラムの関数の依存列は、宣言した範囲と型の深さで形成されている。 -/
theorem function_formation (externals : List (ExternalKey × ExternalDecl)) {f d}
    (hd : (StandardModel.program externals).defs f = some d) :
    d.tel.RangesScoped d.rkinds.length ∧ d.tel.WF d.rkinds.length d.tparams.length 0 :=
  ⟨(StandardModel.definition_scoped externals f d hd).2.1.1.2.2,
   (StandardModel.definition_scoped externals f d hd).2.1.1.1⟩

/-- 合成表の操作・実装・型クラスの宣言の表は空である。 -/
theorem declarations_empty (externals : List (ExternalKey × ExternalDecl)) :
    (StandardModel.program externals).ops = (fun _ => none) ∧
    (StandardModel.program externals).impls = (fun _ => none) ∧
    (StandardModel.program externals).classes = (fun _ => none) := ⟨rfl, rfl, rfl⟩

/-- 標準の組込みを処理する節の署名は、閉じた範囲と型の正規形を持つ。 -/
theorem clause_formation {externals e b sg}
    (h : ClauseSig (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals)) e (.prim b) sg) :
    OpenSurface.ClauseSyntax sg := OpenStandardClauses.standard_clauseSig_prim h

/-- 標準の固定宣言は、外部関数の宣言を追加しない。 -/
theorem external_signature_formation {f d}
    (h : (StandardModel.program []).externalFunction f = some d) : d.parameters.RangesScoped 0 := by
  cases h

example : PatternRangesClosed (StandardModel.program []) :=
  (StandardModel.program_wellFormed [] ⟨List.nodup_nil, by intro key decl member; cases member⟩).patternRangesClosed

-- 外部宣言を持つ合成表にも、同じ範囲の許容と構文形成の証拠を供給する。
example (externals : List (ExternalKey × ExternalDecl)) :
    (∀ b s C ts, (StandardModel.builtins (StandardModel.program externals)).sig b = some s →
      s.admits C ts → ∀ rs, s.admits C (ts.map (Ty.instR rs))) ∧
    (∀ C a p rs, (StandardModel.builtins (StandardModel.program externals)).sat C (a.instR rs) p ↔
      (StandardModel.builtins (StandardModel.program externals)).sat C a p) ∧
    (∀ b s, (StandardModel.builtins (StandardModel.program externals)).sig b = some s →
      s.tel.RangesScoped s.rkinds.length) ∧
    PatternRangesClosed (StandardModel.program externals) ∧
    (∀ f d, (StandardModel.program externals).defs f = some d →
      d.tel.RangesScoped d.rkinds.length ∧ d.tel.WF d.rkinds.length d.tparams.length 0) ∧
    ((StandardModel.program externals).ops = (fun _ => none) ∧
      (StandardModel.program externals).impls = (fun _ => none) ∧
      (StandardModel.program externals).classes = (fun _ => none)) ∧
    (∀ e b sg, ClauseSig (StandardModel.program externals)
      (StandardModel.builtins (StandardModel.program externals)) e (.prim b) sg → OpenSurface.ClauseSyntax sg) ∧
    (∀ f d, (StandardModel.program []).externalFunction f = some d → d.parameters.RangesScoped 0) :=
  ⟨fun _ _ _ _ hs h rs => admits_instR hs h rs,
   fun C a p rs => sat_instR _ C a p rs,
   fun _ _ hs => signature_ranges externals hs,
   pattern_ranges_closed externals,
   fun _ _ hd => function_formation externals hd,
   declarations_empty externals,
   fun _ _ _ h => clause_formation h,
   fun _ _ h => external_signature_formation h⟩

end
end Benitoite.Release.Refinement.Surface.RangeStandard
