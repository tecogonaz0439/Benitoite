import Benitoite.Release.Refinement.Surface.Aliases
import Benitoite.Release.Refinement.RangeTyping

/-! # 範囲変数を実引数とする別名の展開

別名の範囲パラメータは、呼出し元の範囲文脈の変数又は閉じた範囲で具体化する。
-/
namespace Benitoite.Release.Refinement.Surface
noncomputable section

/-- 呼出し元の範囲文脈で、宣言した種類の範囲を表す添字。 -/
def RangeArgument (ks : List Scope.Domain.Kind) (ix : RangeIx) (k : Scope.Domain.Kind) : Prop :=
  match ix with
  | .fixed r => r.WF ∧ r.Canonical ∧ r.FitsKind k
  | .rvar i => ks[i]? = some k

/-- 範囲引数は宣言と同数であり、それぞれ宣言した種類を持つ。 -/
def RangeArguments (ks : List Scope.Domain.Kind) (xs : List RangeIx) (kinds : List Scope.Domain.Kind) : Prop :=
  xs.length = kinds.length ∧ ∀ (i : Nat) ix k, xs[i]? = some ix → kinds[i]? = some k → RangeArgument ks ix k

/-- 別名の範囲変数への同時置換。 -/
def aliasRangeEnv (xs : List RangeIx) (i : Nat) : RangeIx :=
  (xs[i]?).getD (.rvar (i - xs.length))

private theorem rangeArgument_wf {ks ix k} (h : RangeArgument ks ix k) : ix.WF ks.length := by
  cases ix with
  | fixed _ => trivial
  | rvar i => exact (List.getElem?_eq_some_iff.mp h).1

/-- 種類の合う範囲引数による同時置換は、範囲変数の上限を保つ。 -/
theorem RangeArguments.images {ks xs kinds} (h : RangeArguments ks xs kinds) :
    ∀ ix, ix.WF kinds.length → (mapIx (aliasRangeEnv xs) ix).WF ks.length := by
  intro ix hi
  cases ix with
  | fixed _ => trivial
  | rvar i =>
    have hki : i < kinds.length := hi
    have hxi : i < xs.length := h.1 ▸ hki
    have hk := List.getElem?_eq_getElem hki
    have hx := List.getElem?_eq_getElem hxi
    simpa [mapIx, aliasRangeEnv, hx] using rangeArgument_wf (h.2 i _ _ hx hk)

mutual
  /-- 範囲添字の像が上限を保てば、型の範囲写像と正規化は形成を保つ。 -/
  theorem annotation_range_wf {nr mr nt nv} (a : Ty) (h : a.WF nr nt nv)
      (ρ : Nat → RangeIx) (hi : ∀ ix, ix.WF nr → (mapIx ρ ix).WF mr) :
      (a.rawMapRanges ρ).norm.WF mr nt nv := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.rawMapRanges, Ty.norm, Ty.WF]
    all_goals first | trivial | exact annotation_range_wf _ h ρ hi | exact wf_ranges_tys _ h ρ hi | exact hi _ h | skip
    case fn ns ps r e => exact ⟨by simpa only [NamesWF, Ty.normTys_eq_map,
        mapRangesTys_eq_map, List.length_map] using h.1,
      wf_ranges_tys ps h.2.1 ρ hi, annotation_range_wf r h.2.2.1 ρ hi,
      wf_ranges_eff e h.2.2.2.1 ρ hi, Eff.norm_idem _⟩
    case cont a b e => exact ⟨annotation_range_wf a h.1 ρ hi, annotation_range_wf b h.2.1 ρ hi,
      wf_ranges_eff e h.2.2.1 ρ hi, Eff.norm_idem _⟩
    case map a b => exact ⟨annotation_range_wf a h.1 ρ hi, annotation_range_wf b h.2 ρ hi⟩
    case tapp i as => exact ⟨h.1, wf_ranges_tys as h.2 ρ hi⟩
    case refined a p =>
      exact Ty.wf_refineNorm (annotation_range_wf a h.1 ρ hi) h.2.1
        ((Ty.notContCore_norm _).mpr ((Ty.ordinary_rawMapRanges a ρ).mpr h.2.2))
    case dependentFn t => exact Ty.wf_foldFn (wf_ranges_tel t h ρ hi)
  private theorem wf_ranges_tys {nr mr nt nv} (as : List Ty) (h : Ty.WFList nr nt nv as)
      (ρ : Nat → RangeIx) (hi : ∀ ix, ix.WF nr → (mapIx ρ ix).WF mr) :
      Ty.WFList mr nt nv (Ty.normTys (mapRangesTys ρ as)) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨annotation_range_wf a h.1 ρ hi, wf_ranges_tys as h.2 ρ hi⟩
  private theorem wf_ranges_eff {nr mr nt nv} (e : Eff) (h : e.WF nr nt nv)
      (ρ : Nat → RangeIx) (hi : ∀ ix, ix.WF nr → (mapIx ρ ix).WF mr) :
      (Eff.rawMapRanges ρ e).norm.WF mr nt nv := by
    cases e with
    | mk atoms fs =>
      apply Ty.wfList_iff.mpr
      intro a ha
      exact Ty.wfList_iff.mp (wf_ranges_tys fs h ρ hi) a (Order.mem_sortUnique.mp ha)
  private theorem wf_ranges_tel {nr mr nt nv} (t : Tel) (h : t.WF nr nt nv)
      (ρ : Nat → RangeIx) (hi : ∀ ix, ix.WF nr → (mapIx ρ ix).WF mr) :
      (Tel.norm (Tel.rawMapRanges ρ t)).WF mr nt nv := by
    cases t with
    | done a e => exact ⟨annotation_range_wf a h.1 ρ hi, wf_ranges_eff e h.2.1 ρ hi, Eff.norm_idem _⟩
    | param n a t => exact ⟨annotation_range_wf a h.1 ρ hi, wf_ranges_tel t h.2 ρ hi⟩
end

/-- 開いた範囲を渡す別名の展開。型・範囲・値の順に置換する。 -/
def AliasDecl.expandOpen (a : AliasDecl) (ts : List Ty) (vs : List Term) (xs : List RangeIx) : Ty :=
  Ty.bind (.valuesOnly (aliasValueEnv vs)) ((a.body.subst ts []).mapRanges (aliasRangeEnv xs))

/-- 開いた範囲を具体化した値引数の文脈。 -/
def AliasDecl.openContext (a : AliasDecl) (ts : List Ty) (xs : List RangeIx) : Ctx :=
  (a.typeContext ts).rawMapRanges (aliasRangeEnv xs)

/-- 値引数の置換は、範囲文脈の下でも注釈の形成を保つ。 -/
theorem aliasValues_annotationR {P ks C Γa Γ σ b} (h : Ty.AnnotationR P ks C Γa b)
    (hr : b.References Γa) (hσ : AliasArgs P C Γa Γ σ) :
    Ty.AnnotationR P ks C Γ (b.bind (.valuesOnly σ)) :=
  ⟨Ty.wf_bind_values h.wf hr σ hσ.wf, Ty.sorted_bind_values h.sorted σ hσ.sorted hσ.references,
    h.declared.bind_values hσ.declared⟩

/-- 宣言と三種類の実引数から、呼出し元の範囲文脈で展開の注釈を形成する。 -/
theorem AliasDecl.expandOpen_annotation {P : Refinement.Program} {ks C a Γ ts vs xs}
    (hwf : a.WellFormed P) (valid : P.VarianceValid) (ht : AliasTypeArgs P C a ts)
    (hx : RangeArguments ks xs a.rangeParams)
    (hv : AliasArgs P C (a.openContext ts xs) Γ (aliasValueEnv vs)) :
    Ty.AnnotationR P ks C Γ (a.expandOpen ts vs xs) := by
  obtain ⟨hw, hs, hd⟩ := a.subst_formation hwf valid ht
  have hb : Ty.AnnotationR P ks C (a.openContext ts xs)
      ((a.body.subst ts []).mapRanges (aliasRangeEnv xs)) := by
    refine ⟨?_, Ty.sorted_norm (Ty.Sorted.rawMapRanges hs _), (hd.rawMapRanges _).norm⟩
    simpa only [AliasDecl.openContext, Ctx.rawMapRanges, List.length_map, Ty.mapRanges] using
      annotation_range_wf _ hw _ hx.images
  exact aliasValues_annotationR hb (Ty.Sorted.references hb.sorted) hv

/-- 呼出し元の path 範囲変数を、そのまま InPath の範囲引数にする注釈。 -/
theorem pathAlias_expandOpen_annotation (P : Refinement.Program) (valid : P.VarianceValid) :
    Ty.AnnotationR P [.path] [] [] (pathAlias.expandOpen [] [] [.rvar 0]) := by
  have ht : AliasTypeArgs P [] pathAlias [] := by
    refine ⟨⟨rfl, ?_⟩, ?_, ?_, ?_⟩
    all_goals intros <;> contradiction
  have hv : AliasArgs P [] (pathAlias.openContext [] [.rvar 0]) [] (aliasValueEnv []) := by
    change AliasArgs P [] [] [] (aliasValueEnv [])
    exact ⟨(fun _ _ h => by simp at h), (fun _ _ _ h => by simp at h),
      (fun _ _ h => by simp at h), ⟨(fun _ _ h => by simp at h), (fun _ _ _ _ h => by simp at h)⟩⟩
  apply AliasDecl.expandOpen_annotation (pathAlias_wellFormed P) valid ht _ hv
  · refine ⟨rfl, ?_⟩
    intro i ix k hi hk
    cases i with
    | zero => simp only [pathAlias, List.getElem?_cons_zero, Option.some.injEq] at hi hk; subst hi hk; rfl
    | succ i => simp at hi

/-- 開いた範囲引数の展開でも、呼出し元の番号は範囲変数として残る。 -/
example : pathAlias.expandOpen [] [] [.rvar 0] = .scoped "Scope.PathIn" .path (.rvar 0) := by
  simp [AliasDecl.expandOpen, pathAlias, Ty.subst, Ty.substAt, substTypeAt,
    Ty.bind, Ty.rawBind, Ty.mapRanges, Ty.rawMapRanges, Ty.norm, typeEnvAt, RangeIx.inst,
    SubstEnv.valuesOnly, aliasRangeEnv, mapIx]

end
end Benitoite.Release.Refinement.Surface
