import Benitoite.Release.Refinement.Surface.OpenSurfaceCalls
import Benitoite.Release.Refinement.Surface.OpenSurfaceBasicExpr
import Benitoite.Release.Refinement.External
import Benitoite.Release.Refinement.StandardModelResponse

/-! # 開いた署名と許容の有限な形成条件

型・行の深さを開いた文脈で一度検査し、範囲の具体化の形成保存で葉の全具体化を得る。
組込みの任意の許容述語には保存を仮定せず、閉じた引数か、表自身から証明した保存を使う。
-/
namespace Benitoite.Release.Refinement.Surface.OpenLeafFormation
noncomputable section
open OpenSurface

/-- 組込みの許容の構文上の条件。範囲の深さを呼出し元の種類列に合わせる。 -/
structure PrimitiveCheck (ks : List Scope.Domain.Kind) (C : TypeCtx) (nv : Nat) (s : PrimSig)
    (Q : NoFailCtx) (ts : List Ty) (es : List Eff) : Prop where
  typeCount : ts.length = s.tparams.length
  admits : s.admits (TypeCtx.constraints C) (Ty.normTys ts)
  typeScope : ∀ t ∈ ts, t.WF ks.length C.length nv ∧ Ordinary t
  rowCount : es.length = s.neffs
  rowScope : ∀ f ∈ es, f.WF ks.length C.length nv
  sourceRows : s.eff.RowsIn (· < es.length)
  sourceQ : ∀ i, Qsig s.params s.ret s.eff i → i < es.length
  noFailRows : RowTransport (Qsig s.params s.ret s.eff) Q es
  sourceTelRows : s.tel.RowsIn (· < es.length)

/-- 関数の許容の構文上の条件。制約の照合は元の開いた型の正規形に一度適用する。 -/
structure AdmitsCheck (B : Builtins) (ks : List Scope.Domain.Kind) (C : TypeCtx) (nv : Nat)
    (ps : List TParam) (ne : Nat) (Qs Q : NoFailCtx) (ts : List Ty) (es : List Eff) (e : Eff) : Prop where
  types : SatAll B C ts ps
  typeScope : ∀ t ∈ ts, t.WF ks.length C.length nv ∧ Ordinary t
  rowCount : es.length = ne
  rowScope : ∀ f ∈ es, f.WF ks.length C.length nv
  sourceRows : e.RowsIn (· < es.length)
  sourceQ : ∀ i, Qs i → i < es.length
  noFailRows : RowTransport Qs Q es

/-- メソッドの行引数の有限な形成条件。 -/
structure MethodRowsCheck (ks : List Scope.Domain.Kind) (C : TypeCtx) (nv : Nat) (Q : NoFailCtx)
    (ms : MethSig) (es : List Eff) : Prop where
  count : es.length = ms.neffs
  scope : ∀ f ∈ es, f.WF ks.length C.length nv
  sourceRows : ms.eff.RowsIn (· < es.length)
  sourceQ : ∀ i, Qsig ms.params ms.ret ms.eff i → i < es.length
  noFailRows : RowTransport (Qsig ms.params ms.ret ms.eff) Q es

/-- 宣言と、その型・行の像と結果を開いた文脈で形成する。 -/
structure SignatureCheck (P : Refinement.Program) (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx)
    (t : Tel) (kinds : List TyKind) (ts : List Ty) (es : List Eff) : Prop where
  source : t.WF ks.length kinds.length 0
  types : Annotations P ks C Γ ts
  kinds : TypeArgsKinded P C ts kinds
  rows : OpenSurface.RowAnnotations P ks C Γ es
  rowKinds : ∀ e ∈ es, kindsEff P (TypeCtx.kinds C) e
  result : Ty.AnnotationR P ks C Γ (.dependentFn (instantiatedTel t ts es))

/-- 型の形成は、同じ長さの範囲の具体化で閉じる。 -/
theorem type_scope {ks : List Scope.Domain.Kind} {nt nv : Nat} {a : Ty} (h : a.WF ks.length nt nv) (σ : Instance ks) :
    (rangeTy σ.val a).WF 0 nt nv := by
  cases hr : σ.val with
  | nil =>
    have hk : ks.length = 0 := by simpa [hr] using σ.property.1.symm
    simpa only [hr, rangeTy, hk] using h
  | cons r rs =>
    simp only [rangeTy, Ty.instR_eq_bind]
    exact a.bind_wf h (SubstEnv.rangesOnly_wfImages (hr ▸ σ.property.1))

/-- 行の形成も同じ範囲の具体化で閉じる。 -/
theorem row_scope {ks : List Scope.Domain.Kind} {nt nv : Nat} {e : Eff} (h : e.WF ks.length nt nv) (σ : Instance ks) :
    (rangeEff σ.val e).WF 0 nt nv := by
  cases hr : σ.val with
  | nil =>
    have hk : ks.length = 0 := by simpa [hr] using σ.property.1.symm
    simpa only [hr, rangeEff, hk] using h
  | cons r rs =>
    simp only [rangeEff, Eff.instR_eq_bind]
    exact Eff.rawBind_norm_wf e h (SubstEnv.rangesOnly_wfImages (hr ▸ σ.property.1))

private theorem noFail_range {Q e} (h : NoFail Q e) (rs : List RangeExpr) :
    NoFail Q (rangeEff rs e) := by
  cases rs with
  | nil => exact h
  | cons r rs =>
    constructor
    · cases e with
      | mk atoms fails =>
        change Order.sortUnique tyCompare (Ty.normTys (mapRangesTys _ fails)) = []
        rw [show fails = [] from h.1]
        rfl
    · intro i hi
      apply h.2 i
      change ((Eff.rawMapRanges (rangeAt 0 (r :: rs)) e).norm).mem (.rho i) at hi
      rw [Eff.mem_norm] at hi
      cases e with
      | mk atoms fails => simpa only [Eff.mem, Eff.test, Eff.atoms, Eff.rawMapRanges, mapRangeAtoms_rho] using hi

private theorem rangeEff_row (rs : List RangeExpr) (i : Nat) : rangeEff rs (Eff.row i) = Eff.row i := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    simp only [rangeEff, Eff.instR, Eff.substRAt, Eff.mapRanges, Eff.row, Eff.rawMapRanges,
      mapRangesTys, Eff.norm, Ty.normTys, Order.sortUnique]
    congr 1
    funext a
    apply Bool.eq_iff_iff.mpr
    constructor
    · intro h
      obtain ⟨z, hz, he⟩ := (mapRangeAtoms_spec _ _ _).mp h
      cases z with
      | name _ _ => cases hz
      | rho j => cases he; exact hz
    · intro h
      cases a with
      | name _ _ => cases h
      | rho j => exact (mapRangeAtoms_spec _ _ _).mpr ⟨.rho j, h, rfl⟩

/-- NoFail の行の照合は、範囲の具体化で保つ。 -/
theorem row_transport {Qs Q es} (h : RowTransport Qs Q es) (rs : List RangeExpr) :
    RowTransport Qs Q (es.map (rangeEff rs)) :=
  h.map (rangeEff rs) (fun _ he => noFail_range he rs) (rangeEff_row rs)

private theorem kinds_range {P C ts kinds} (h : TypeArgsKinded P C ts kinds) (rs : List RangeExpr) :
    TypeArgsKinded P C (ts.map (rangeTy rs)) kinds := by
  refine ⟨by simpa using h.1, ?_⟩
  intro i a k ha hk
  obtain ⟨b, hb, rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using ha)
  have ht := h.2 i b k hb hk
  cases rs with
  | nil => exact ht
  | cons r rs => exact ⟨(ht.1.rawMapRanges _).norm,
      fun hv => (Ty.ordinary_norm _).mpr ((Ty.ordinary_rawMapRanges _ _).mpr (ht.2 hv))⟩

private theorem row_kinds_range {P C e} (h : kindsEff P (TypeCtx.kinds C) e) (rs : List RangeExpr) :
    kindsEff P (TypeCtx.kinds C) (rangeEff rs e) := by
  have hk : Ty.HasKind P (TypeCtx.kinds C) (.fn [] [] (.base .unit) e) .value :=
    ⟨by simp [NamesWF], trivial, trivial, h⟩
  cases rs with
  | nil => exact h
  | cons r rs => exact ((hk.rawMapRanges _).norm).2.2.2

/-- 一度の開いた署名の形成から、全具体化の署名の葉を供給する。 -/
theorem SignatureCheck.sound {P ks C Γ t kinds ts es}
    (h : SignatureCheck P ks C Γ t kinds ts es) : OpenSurface.Signature P ks C Γ t kinds ts es := by
  intro σ
  refine ⟨?_, ?_, kinds_range h.kinds σ.val, ?_, ?_, ?_⟩
  · cases hr : σ.val with
    | nil =>
      have hk : ks.length = 0 := by simpa [hr] using σ.property.1.symm
      simpa only [hr, rangeTel, hk, Ty.WF] using h.source
    | cons r rs =>
      simp only [rangeTel, Tel.instR_eq_bind, Ty.WF]
      exact Tel.rawBind_norm_wf t h.source (SubstEnv.rangesOnly_wfImages (hr ▸ σ.property.1))
  · intro a ha
    obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
    exact annotation (B := (StandardModel.builtins P)) (h.types b hb) σ
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    have ann := annotation (B := (StandardModel.builtins P)) (h.rows f hf) σ
    simpa only [rangeTy_fn, List.map_nil,
      show rangeTy σ.val (.base .unit) = .base .unit from by cases σ.val <;> rfl] using ann
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    exact row_kinds_range (h.rowKinds f hf) σ.val
  · rw [← OpenSignatureExchange.rangeTel_instantiated]
    cases hr : σ.val with
    | nil => simpa only [hr, rangeCtx, rangeTel] using
        (Ty.annotationR_nil.mp (show Ty.AnnotationR P [] C Γ (.dependentFn (instantiatedTel t ts es)) from by
          have hk : ks = [] := List.eq_nil_of_length_eq_zero (by simpa [hr] using σ.property.1.symm)
          simpa [hk] using h.result))
    | cons r rs =>
      let ρ := rangeAt 0 (r :: rs)
      have ann : Ty.Annotation P C (Γ.rawMapRanges ρ)
          (.dependentFn (Tel.instR (r :: rs) (instantiatedTel t ts es))) := by
        refine ⟨?_, Tel.sorted_norm (h.result.sorted.rawMapRanges ρ),
          Tel.Declared.norm (h.result.declared.rawMapRanges ρ)⟩
        simpa only [Ctx.rawMapRanges, List.length_map, Tel.instR_eq_bind, Ty.WF, Tel.bind] using
          Tel.rawBind_norm_wf (instantiatedTel t ts es) h.result.wf
            (SubstEnv.rangesOnly_wfImages (hr ▸ σ.property.1))
      exact (rangeCtx_normEq Γ ρ).annotation (B := StandardModel.builtins P) ann

/-- メソッドの行の葉は、開いた行の一度の形成から得られる。 -/
theorem MethodRowsCheck.sound {ks C nv Q ms es} (h : MethodRowsCheck ks C nv Q ms es) :
    OpenSurface.MethodRows ks C nv Q ms es := by
  intro σ
  refine ⟨by simpa using h.count, ?_, ?_, ?_, row_transport h.noFailRows σ.val⟩
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    exact row_scope (h.scope f hf) σ
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

/-- 一つの具体化で許容述語を供給すれば、残りの欄は有限な構文条件から従う。 -/
theorem primitive_at {ks C nv s Q ts es} (h : PrimitiveCheck ks C nv s Q ts es) (σ : Instance ks)
    (ha : s.admits (TypeCtx.constraints C) (Ty.normTys (ts.map (rangeTy σ.val)))) :
    PrimitiveAdmissible C nv s Q (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val)) := by
  refine ⟨by simpa using h.typeCount, ha, ?_, by simpa using h.rowCount, ?_, ?_, ?_,
    row_transport h.noFailRows σ.val, ?_⟩
  · intro a hm
    obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hm
    exact ⟨type_scope (h.typeScope b hb).1 σ, rangeTy_ordinary (h.typeScope b hb).2 σ.val⟩
  · intro e hm
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hm
    exact row_scope (h.rowScope f hf) σ
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ
  · simpa only [List.length_map] using h.sourceTelRows

/-- 一つの具体化で制約の照合を供給すれば、残りの欄は有限な構文条件から従う。 -/
theorem admits_at {B ks C nv ps ne Qs Q ts es e} (h : AdmitsCheck B ks C nv ps ne Qs Q ts es e)
    (σ : Instance ks) (ht : SatAll B C (ts.map (rangeTy σ.val)) ps) :
    Admissible B C nv ps ne Qs Q (ts.map (rangeTy σ.val)) (es.map (rangeEff σ.val)) e := by
  refine ⟨ht, ?_, by simpa using h.rowCount, ?_, ?_, ?_, row_transport h.noFailRows σ.val⟩
  · intro a hm
    obtain ⟨b, hb, rfl⟩ := List.mem_map.mp hm
    exact ⟨type_scope (h.typeScope b hb).1 σ, rangeTy_ordinary (h.typeScope b hb).2 σ.val⟩
  · intro f hm
    obtain ⟨g, hg, rfl⟩ := List.mem_map.mp hm
    exact row_scope (h.rowScope g hg) σ
  · simpa only [List.length_map] using h.sourceRows
  · simpa only [List.length_map] using h.sourceQ

private theorem rangeTy_closed_norm (rs : List RangeExpr) {a : Ty} (h : a.RangesScoped 0) :
    (rangeTy rs a).norm = a.norm := by
  cases rs with
  | nil => rfl
  | cons r rs =>
    change ((a.rawMapRanges (rangeAt 0 (r :: rs))).norm).norm = _
    rw [Ty.norm_idem, Ty.rawMapRanges_of_rangesClosed a h]

/-- 範囲閉の型引数の制約は、任意の表でも一度の照合から全具体化へ移る。 -/
theorem satisfies_of_closed {B ks C ts ps} (h : SatAll B C ts ps)
    (hc : ∀ a ∈ ts, a.RangesScoped 0) : OpenSurface.Satisfies B ks C ts ps := by
  intro σ
  apply h.map (rangeTy σ.val)
  intro a ha p hp
  rwa [rangeTy_closed_norm σ.val (hc a ha)]

/-- 範囲閉の型引数は、任意の表の組込みの許容を保つ。 -/
theorem primitive_of_closed {ks C nv s Q ts es} (h : PrimitiveCheck ks C nv s Q ts es)
    (hc : ∀ a ∈ ts, a.RangesScoped 0) : OpenSurface.Primitive ks C nv s Q ts es := by
  intro σ
  apply primitive_at h σ
  have he : Ty.normTys (ts.map (rangeTy σ.val)) = Ty.normTys ts := by
    simp only [Ty.normTys_eq_map, List.map_map]
    exact List.map_congr_left (fun a ha => rangeTy_closed_norm σ.val (hc a ha))
  rw [he]
  exact h.admits

/-- 範囲閉の型引数は、任意の表の関数の許容を保つ。 -/
theorem admits_of_closed {B ks C nv ps ne Qs Q ts es e} (h : AdmitsCheck B ks C nv ps ne Qs Q ts es e)
    (hc : ∀ a ∈ ts, a.RangesScoped 0) : OpenSurface.Admits B ks C nv ps ne Qs Q ts es e :=
  fun σ => admits_at h σ (satisfies_of_closed h.types hc σ)

/-- 単相の外部署名の許容は、元の有限な検査をそのまま全具体化へ移す。 -/
theorem external_of_check {P B ks C d ts} (ht : d.tparams = []) (h : ExternalCallAdmissible P B C d ts) :
    OpenSurface.ExternalAdmits P B ks C d ts := by
  have hn : ts = [] := List.eq_nil_of_length_eq_zero (by simpa only [ht, List.length_nil] using h.count)
  subst ts
  intro σ
  exact h

/-- 固定範囲だけを渡す呼出しでは、表の元の範囲許容を一度検査すればよい。 -/
theorem ranges_of_fixed {B ks b s rs} (h : B.RangeAdmissible b s rs) :
    OpenSurface.RangesAdmit B ks b s (rs.map RangeIx.fixed) := by
  intro σ
  have he : (rs.map RangeIx.fixed).map (closeRange σ.val) = rs := by
    rw [List.map_map]
    change rs.map id = rs
    exact List.map_id rs
  rw [he]
  exact h

end
end Benitoite.Release.Refinement.Surface.OpenLeafFormation
