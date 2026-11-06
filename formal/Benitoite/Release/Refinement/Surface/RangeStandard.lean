import Benitoite.Release.Refinement.StandardModelSubstitution
import Benitoite.Release.Refinement.StandardModelScoped
import Benitoite.Release.Refinement.RangeFormation
import Benitoite.Release.Refinement.StandardModelWellFormed
import Benitoite.Release.Refinement.Surface.OpenPatterns
import Benitoite.Release.Refinement.Surface.OpenStandardClauses
import Benitoite.Release.Refinement.Surface.OpenSurfaceHandlers
import Benitoite.Release.Refinement.Surface.OpenLeafFormation

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

/-- 開いた型の正規形に一度適用した制約の照合を、全具体化へ接続する。 -/
theorem sat_range_norm (P : Refinement.Program) (C : List TParam) (a : Ty) (p : TParam)
    (rs : List RangeExpr) :
    (StandardModel.builtins P).sat C (rangeTy rs a).norm p ↔
      (StandardModel.builtins P).sat C a.norm p := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    have he : a.norm.instR (r :: rs) = (rangeTy (r :: rs) a).norm := by
      simp only [rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges, Ty.norm_rawMapRanges, Ty.norm_idem]
    rw [← he]
    exact sat_instR P C a.norm p (r :: rs)

/-- 合成表の制約の全具体化の葉は、元の開いた型の有限な照合から得る。 -/
theorem satisfies_of_check {P : Refinement.Program} {ks C ts ps}
    (h : SatAll (StandardModel.builtins P) C ts ps) :
    OpenSurface.Satisfies (StandardModel.builtins P) ks C ts ps := by
  intro σ
  apply h.map (rangeTy σ.val)
  intro a ha p hp
  exact (sat_range_norm P (TypeCtx.constraints C) a p σ.val).mpr hp

/-- 合成表の組込みの葉を、一度の開いた構文の検査と許容の保存から導く。 -/
theorem primitive_of_check {P : Refinement.Program} {ks C nv b s Q ts es}
    (hs : (StandardModel.builtins P).sig b = some s)
    (h : OpenLeafFormation.PrimitiveCheck ks C nv s Q ts es) :
    OpenSurface.Primitive ks C nv s Q ts es := by
  intro σ
  apply OpenLeafFormation.primitive_at h σ
  cases hr : σ.val with
  | nil =>
    change s.admits (TypeCtx.constraints C) (Ty.normTys (ts.map id))
    simpa only [List.map_id] using h.admits
  | cons r rs =>
    have ha := admits_instR hs h.admits (r :: rs)
    have he : (Ty.normTys ts).map (Ty.instR (r :: rs)) = Ty.normTys (ts.map (rangeTy (r :: rs))) := by
      simp only [Ty.normTys_eq_map, List.map_map]
      exact List.map_congr_left (fun a _ => by
        simp only [Function.comp_apply, rangeTy, Ty.instR, Ty.substRAt, Ty.mapRanges,
          Ty.norm_rawMapRanges, Ty.norm_idem])
    simpa only [hr, he] using ha

/-- 関数の許容の全欄を、一度の開いた構文の検査から導く。 -/
theorem admits_of_check {P : Refinement.Program} {ks C nv ps ne Qs Q ts es e}
    (h : OpenLeafFormation.AdmitsCheck (StandardModel.builtins P) ks C nv ps ne Qs Q ts es e) :
    OpenSurface.Admits (StandardModel.builtins P) ks C nv ps ne Qs Q ts es e :=
  fun σ => OpenLeafFormation.admits_at h σ (satisfies_of_check h.types σ)

/-- 標準の範囲引数の許容を、範囲変数を残した有限な構文で照合する。 -/
def RangeCheck (b : PrimName) (xs : List RangeIx) : Prop :=
  (∀ ix ∈ xs, ix = .fixed .top) ∨
  ((b = "Scope.widenPathIn" ∨ b = "Http.widenRequestIn") ∧
    ∃ inner outer, xs = [inner, outer] ∧ (outer = .fixed .top ∨ outer.Covers inner)) ∨
  ((b = "File.readTextIn" ∨ b = "File.readBytesIn" ∨ b = "File.writeTextIn" ∨
    b = "File.appendTextIn" ∨ b = "File.writeBytesIn" ∨ b = "File.appendBytesIn" ∨
    b = "Http.sendIn" ∨ b = "Scope.checkPathIn" ∨ b = "Http.checkRequestIn" ∨
    b = "Scope.pathInValue" ∨ b = "Http.requestInValue") ∧ xs.length = 1)

/-- 範囲の種類と標準の有限な許容条件から、範囲の全具体化の葉を得る。 -/
theorem ranges_of_check {P : Refinement.Program} {ks b s xs}
    (hx : RangeArguments ks xs s.rkinds) (h : RangeCheck b xs) :
    OpenSurface.RangesAdmit (StandardModel.builtins P) ks b s xs := by
  intro σ
  have hf := OpenSurface.ranges_fit_close hx σ.property
  refine ⟨hf.1, hf.2.1, hf.2.2, ?_⟩
  rcases h with htop | ⟨hname, inner, outer, rfl, hc⟩ | ⟨hname, hlen⟩
  · apply Or.inl
    intro r hr
    obtain ⟨ix, hi, rfl⟩ := List.mem_map.mp hr
    rw [htop ix hi]
    rfl
  · apply Or.inr
    have he := OpenSurface.ranges_close hx σ.property
    simp only [List.map_cons, List.map_nil, List.cons.injEq] at he
    have hcov : (OpenSurface.closeRange σ.val outer).Covers (OpenSurface.closeRange σ.val inner) := by
      rcases hc with rfl | hc
      · exact RangeExpr.top_covers _
      · have hcov := hc.inst σ.val
        rw [he.2.1, he.1] at hcov
        exact hcov
    change ScopeSignatures.admitsR b _
    rcases hname with rfl | rfl <;>
      exact ⟨OpenSurface.closeRange σ.val inner, OpenSurface.closeRange σ.val outer, rfl, hcov⟩
  · apply Or.inr
    change ScopeSignatures.admitsR b _
    rcases hname with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl <;>
      simpa [ScopeSignatures.admitsR] using hlen

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
    OpenSurface.ClauseSyntax sg := by
  have hs := OpenStandardClauses.standard_clauseSig_prim h
  exact ⟨fun a ha => (hs.1 a ha).1, hs.2.1⟩

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
