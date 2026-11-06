import Benitoite.Release.Refinement.Surface.Basic
import Benitoite.Release.Refinement.Surface.Typing
import Benitoite.Release.Refinement.ValueRegularity
import Benitoite.Release.Refinement.DeclaredTransport
import Benitoite.Release.Refinement.TypeBounds
import Benitoite.Release.Refinement.SourceScope
import Benitoite.Release.Refinement.RangeSubst
import Benitoite.Release.Refinement.AdmissibleMap
import Benitoite.Release.Refinement.ValueReferences
import Benitoite.Release.Refinement.RangeFormation
import Benitoite.Release.Refinement.TypeFormation
import Benitoite.Release.Refinement.KindTypeSubst

/-!
# 型の別名の展開

型の別名 `type W[ᾱ](x̄: Ā)[r̄] = T` の適用 `W[T̄](t̄)[R̄]` を、本体の型パラメータ・値引数・範囲パラメータの置換として展開する
（設計書 01-12「型の情報を付けた表層の構文と型付け」）。値引数は篩の項に現れる全ての sort の値であり、本体は最後の
値引数を値変数 0 として読む。値の置換は核の `Ty.bind`（`SubstEnv.valuesOnly`）、範囲の置換は `Ty.instR` を使う。
範囲の引数は閉じた範囲に限る（関数の範囲パラメータを別名へ渡す形は扱わない）。
-/

namespace Benitoite.Release.Refinement.Surface

/-- 値引数の項の列（ソース順）から、本体の値変数への像を作る。最後の値引数が番号 0 である。 -/
def aliasValueEnv (vs : List Term) : ObservationEnv := fun i => vs.reverse[i]?

/-- 別名の値引数を束縛した文脈。 -/
def AliasDecl.context (a : AliasDecl) : Ctx := bindParams [] (a.valueParams.map Prod.snd)

/-- 範囲パラメータを閉じた範囲の列で具体化した後の、値引数を束縛した文脈。 -/
noncomputable def AliasDecl.rangeContext (a : AliasDecl) (rs : List RangeExpr) : Ctx :=
  a.context.rawMapRanges (rangeAt 0 rs)

/-- 別名の適用の展開。型パラメータ、範囲パラメータ、値引数の順に置換する。 -/
noncomputable def AliasDecl.expand (a : AliasDecl) (ts : List Ty) (vs : List Term) (rs : List RangeExpr) : Ty :=
  Ty.bind (SubstEnv.valuesOnly (aliasValueEnv vs)) (Ty.instR rs (a.body.subst ts []))

/-- 別名の宣言の整形式。値引数の名前は重ならず、値引数の型はそれぞれ sort を持ち（sort の種類は問わない）、本体は
型パラメータ・範囲パラメータ・値引数の文脈で整形式で、整列し、宣言済みである。 -/
structure AliasDecl.WellFormed (P : Refinement.Program) (a : AliasDecl) : Prop where
  names : (a.valueParams.map Prod.fst).Nodup
  sorts : ∀ p ∈ a.valueParams, ∃ s, p.2.HasSort s
  bodyWF : a.body.WF a.rangeParams.length a.tparams.length a.context.length
  bodySorted : a.body.Sorted a.context
  bodyDeclared : a.body.Declared P a.tparams a.context
  ranges : a.body.RangesScoped a.rangeParams.length

/-- 別名の範囲の実引数。範囲パラメータと同じ数の、整形式で種類の合う閉じた範囲である。 -/
def AliasDecl.RangeArgs (a : AliasDecl) (rs : List RangeExpr) : Prop :=
  rs.length = a.rangeParams.length ∧
    ∀ (i : Nat) (r : RangeExpr) (k : Scope.Domain.Kind), rs[i]? = some r → a.rangeParams[i]? = some k →
      r.WF ∧ r.FitsKind k

/-- 値引数の像の条件。像は展開する位置の文脈 Γ で整形式で、各値引数の sort の項であり、宣言済みである。 -/
structure AliasArgs (P : Refinement.Program) (C : TypeCtx) (Γa Γ : Ctx) (σ : ObservationEnv) : Prop where
  wf : Term.ImageWF Γa Γ σ
  sorted : Term.ImagesSorted Γa Γ σ
  references : Term.ImageReferences Γa Γ σ
  declared : DeclarationImages P C Γa Γ σ

/-- 値引数の置換は注釈の整形式を保つ（値引数の sort ごとの像の条件 `Term.ImagesSorted` は全ての sort を量化する）。 -/
theorem aliasValues_annotation {P C Γa Γ σ b} (h : Ty.Annotation P C Γa b) (hr : b.References Γa)
    (hσ : AliasArgs P C Γa Γ σ) : Ty.Annotation P C Γ (b.bind (SubstEnv.valuesOnly σ)) :=
  ⟨Ty.wf_bind_values h.wf hr σ hσ.wf, Ty.sorted_bind_values h.sorted σ hσ.sorted hσ.references,
    h.declared.bind_values hσ.declared⟩

/-- 範囲の変数を nr 個持つ型を同じ数の閉じた範囲で具体化すると、範囲を具体化した文脈で注釈として整形式になる。 -/
theorem instR_annotation {P : Refinement.Program} {C : TypeCtx} {Γ : Ctx} {a : Ty} {nr : Nat} {rs : List RangeExpr}
    (hw : a.WF nr C.length Γ.length) (hs : a.Sorted Γ) (hd : a.Declared P C Γ) (hn : rs.length = nr) :
    Ty.Annotation P C (Γ.rawMapRanges (rangeAt 0 rs)) (Ty.instR rs a) := by
  refine ⟨?_, ?_, ?_⟩
  · rw [Ty.instR_eq_bind]
    have h := Ty.bind_wf a hw (SubstEnv.rangesOnly_wfImages (nt := C.length) (nv := Γ.length) hn)
    simpa [Ctx.rawMapRanges] using h
  · exact Ty.sorted_norm (Ty.Sorted.rawMapRanges hs (rangeAt 0 rs))
  · exact (Ty.Declared.rawMapRanges hd (rangeAt 0 rs)).norm

private theorem alias_declared_apply {P C Γ a n as} (hk : Ty.HasKind P (TypeCtx.kinds C) a (.constructor n))
    (hn : as.length = n) (hs : declaredTys P C Γ as) : Ty.Declared P C Γ (rawApply a as) := by
  cases rawApply_proper hk hn with
  | «variable» i as => exact ⟨by simpa only [Ty.HasKind, ← hn] using hk, hs⟩
  | list a | set a | reference a | lazy a => exact hs.1
  | map a b => exact ⟨hs.1, hs.2.1⟩
  | data d as => exact ⟨⟨n, TyCon.dataArity_of_arity hk, hn⟩, hs⟩

private theorem alias_sorted_apply {P C Γ a n as} (hk : Ty.HasKind P (TypeCtx.kinds C) a (.constructor n))
    (hn : as.length = n) (hs : sortedTys Γ as) : Ty.Sorted Γ (rawApply a as) := by
  cases rawApply_proper hk hn with
  | «variable» i as => exact hs
  | list a | set a | reference a | lazy a => exact hs.1
  | map a b => exact ⟨hs.1, hs.2.1⟩
  | data d as => exact hs

mutual
  private theorem alias_declared_types {P C D Γ Δ a f} (h : Ty.Declared P C Γ a)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f)
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, Ty.Declared P D Δ (f i)) : Ty.Declared P D Δ (a.rawBind (.typesOnly f)) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ => trivial
    | tvar i => exact hf i
    | ctor c => cases c <;> exact h
    | list a | reference a | lazy a | set a | dict _ a => exact alias_declared_types (a := a) h valid hm hk hf
    | data d as | external d as => exact ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1,
        alias_declared_tys h.2 valid hm hk hf⟩
    | tapp i as =>
      exact alias_declared_apply (hk i _ h.1).1
        (by simp only [rawBindTys_eq_map, List.length_map]) (alias_declared_tys h.2 valid hm hk hf)
    | dependentFn _ => exact alias_declared_tel h valid hm hk hf
    | fn _ _ _ _ => exact ⟨alias_declared_tys h.1 valid hm hk hf,
        alias_declared_types h.2.1 valid hm hk hf, alias_declared_eff h.2.2 valid hm hk hf⟩
    | cont _ _ _ => exact ⟨alias_declared_types h.1 valid hm hk hf,
        alias_declared_types h.2.1 valid hm hk hf, alias_declared_eff h.2.2 valid hm hk hf⟩
    | map _ _ => exact ⟨alias_declared_types h.1 valid hm hk hf, alias_declared_types h.2 valid hm hk hf⟩
    | refined a p =>
      simp only [Ty.rawBind, SubstEnv.typesOnly, upValues_id, predBind_id, Ty.Declared]
      exact ⟨alias_declared_types h.1 valid hm hk hf, Pred.Declared.typesOnly h.2 valid hm⟩
  private theorem alias_declared_tys {P C D Γ Δ as f} (h : declaredTys P C Γ as)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f)
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, Ty.Declared P D Δ (f i)) : declaredTys P D Δ (rawBindTys (.typesOnly f) as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨alias_declared_types h.1 valid hm hk hf, alias_declared_tys h.2 valid hm hk hf⟩
  private theorem alias_declared_eff {P C D Γ Δ e f} (h : declaredEff P C Γ e)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f)
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, Ty.Declared P D Δ (f i)) : declaredEff P D Δ (Eff.rawBind (.typesOnly f) e) := by
    cases e
    simpa only [Eff.rawBind, SubstEnv.typesOnly, rowFails, List.length_nil, List.range_zero, List.filter_nil,
      List.flatMap_nil, List.append_nil, declaredEff] using alias_declared_tys h valid hm hk hf
  private theorem alias_declared_tel {P C D Γ Δ t f} (h : Tel.Declared P C Γ t)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f)
      (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, Ty.Declared P D Δ (f i)) : Tel.Declared P D Δ (Tel.rawBind (.typesOnly f) t) := by
    cases t with
    | done r e => exact ⟨alias_declared_types h.1 valid hm hk hf, alias_declared_eff h.2 valid hm hk hf⟩
    | param _ a t =>
      refine ⟨alias_declared_types h.1 valid hm hk hf, ?_⟩
      simp only [SubstEnv.typesOnly_up]
      apply alias_declared_tel h.2 valid (hm.extend a)
      · intro i k hi
        exact ⟨(hk i k hi).1.shift_values 1 0,
          fun hv => (Ty.ordinary_shiftV _ _ _).mpr ((hk i k hi).2 hv)⟩
      · intro i
        rw [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
        exact (hf i).rawSubstV (DeclarationRenaming.outer Δ (a.rawBind (.typesOnly f))).images
end

mutual
  private theorem alias_sorted_types {P C D Γ Δ a f} (h : Ty.Sorted Γ a) (hd : Ty.Declared P C Γ a)
      (hm : TypeFormationMap Γ Δ f) (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, (f i).Sorted Δ) : (a.rawBind (.typesOnly f)).Sorted Δ := by
    cases a <;> simp only [Ty.Sorted, Ty.Declared] at h hd <;> simp only [Ty.rawBind, Ty.Sorted]
    all_goals first | trivial | exact alias_sorted_types h hd hm hk hf | skip
    case data _ _ => exact alias_sorted_tys h hd.2 hm hk hf
    case external _ _ => exact alias_sorted_tys h hd.2 hm hk hf
    case tvar i => exact hf i
    case tapp i as =>
      exact alias_sorted_apply (hk i _ hd.1).1
        (by simp only [rawBindTys_eq_map, List.length_map]) (alias_sorted_tys h hd.2 hm hk hf)
    case fn _ _ _ _ => exact ⟨alias_sorted_tys h.1 hd.1 hm hk hf,
        alias_sorted_types h.2.1 hd.2.1 hm hk hf, alias_sorted_eff h.2.2 hd.2.2 hm hk hf⟩
    case cont _ _ _ => exact ⟨alias_sorted_types h.1 hd.1 hm hk hf,
        alias_sorted_types h.2.1 hd.2.1 hm hk hf, alias_sorted_eff h.2.2 hd.2.2 hm hk hf⟩
    case map _ _ => exact ⟨alias_sorted_types h.1 hd.1 hm hk hf, alias_sorted_types h.2 hd.2 hm hk hf⟩
    case refined a p =>
      refine ⟨alias_sorted_types h.1 hd.1 hm hk hf, ?_⟩
      simp only [SubstEnv.typesOnly, upValues_id, predBind_id]
      exact Pred.Sorted.sortMap hm.sortMap h.2 (fun _ hs => Ty.hasSort_rawBind hs _)
        (fun ho => Ty.ordinary_rawBind ho _ hm.ordinary)
    case dependentFn _ => exact alias_sorted_tel h hd hm hk hf
  private theorem alias_sorted_tys {P C D Γ Δ as f} (h : sortedTys Γ as) (hd : declaredTys P C Γ as)
      (hm : TypeFormationMap Γ Δ f) (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, (f i).Sorted Δ) : sortedTys Δ (rawBindTys (.typesOnly f) as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨alias_sorted_types h.1 hd.1 hm hk hf, alias_sorted_tys h.2 hd.2 hm hk hf⟩
  private theorem alias_sorted_eff {P C D Γ Δ e f} (h : sortedEff Γ e) (hd : declaredEff P C Γ e)
      (hm : TypeFormationMap Γ Δ f) (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, (f i).Sorted Δ) : sortedEff Δ (Eff.rawBind (.typesOnly f) e) := by
    cases e
    simpa only [Eff.rawBind, SubstEnv.typesOnly, rowFails, List.length_nil, List.range_zero, List.filter_nil,
      List.flatMap_nil, List.append_nil, sortedEff] using alias_sorted_tys h hd hm hk hf
  private theorem alias_sorted_tel {P C D Γ Δ t f} (h : Tel.Sorted Γ t) (hd : Tel.Declared P C Γ t)
      (hm : TypeFormationMap Γ Δ f) (hk : TypeImagesKinded P (TypeCtx.kinds C) (TypeCtx.kinds D) f)
      (hf : ∀ i, (f i).Sorted Δ) : Tel.Sorted Δ (Tel.rawBind (.typesOnly f) t) := by
    cases t with
    | done r e => exact ⟨alias_sorted_types h.1 hd.1 hm hk hf, alias_sorted_eff h.2 hd.2 hm hk hf⟩
    | param _ a t =>
      refine ⟨alias_sorted_types h.1 hd.1 hm hk hf, ?_⟩
      simp only [SubstEnv.typesOnly_up]
      apply alias_sorted_tel h.2 hd.2 (hm.extend a)
      · intro i k hi
        exact ⟨(hk i k hi).1.shift_values 1 0,
          fun hv => (Ty.ordinary_shiftV _ _ _).mpr ((hk i k hi).2 hv)⟩
      · intro i; exact (hf i).shift_outer _
end

/-- 型引数を代入した値引数の文脈。型は正規化前の像を格納し、値の番号を保つ。 -/
noncomputable def AliasDecl.typeContext (a : AliasDecl) (ts : List Ty) : Ctx :=
  a.context.map (Option.map (Ty.rawBind (typeEnvAt 0 ts [])))

/-- 型引数を代入し、範囲引数で具体化した値引数の文脈。 -/
noncomputable def AliasDecl.instantiatedContext (a : AliasDecl) (ts : List Ty) (rs : List RangeExpr) : Ctx :=
  (a.typeContext ts).rawMapRanges (rangeAt 0 rs)

/-- 別名の型引数の形成。数と kind が一致し、各像は型引数を代入した文脈で整形式・整列済み・宣言済みである。
型パラメータや値・範囲の変数を含む像も、対応する文脈の下で受ける。 -/
structure AliasTypeArgs (P : Refinement.Program) (C : TypeCtx) (a : AliasDecl) (ts : List Ty) : Prop where
  kinds : TypeArgsKinded P C ts (TypeCtx.kinds a.tparams)
  wf : ∀ t ∈ ts, t.WF a.rangeParams.length C.length a.context.length
  sorted : ∀ t ∈ ts, t.Sorted (a.typeContext ts)
  declared : ∀ t ∈ ts, t.Declared P C (a.typeContext ts)

/-- 型パラメータ・値引数・範囲パラメータを持つ別名の本体への型の代入は、各形成条件を保つ。
範囲の上限は別名が宣言した数のままであり、型引数の像の kind は型構成子の適用も含む。 -/
theorem AliasDecl.subst_formation {P : Refinement.Program} {C : TypeCtx} {a : AliasDecl} {ts : List Ty}
    (hwf : a.WellFormed P) (valid : P.VarianceValid) (ht : AliasTypeArgs P C a ts) :
    (a.body.subst ts []).WF a.rangeParams.length C.length (a.typeContext ts).length ∧
      (a.body.subst ts []).Sorted (a.typeContext ts) ∧
      (a.body.subst ts []).Declared P C (a.typeContext ts) := by
  let f := (typeEnvAt 0 ts []).types
  have hn : ts.length = a.tparams.length := by simpa [TypeCtx.kinds] using ht.kinds.1
  have ho : ∀ i, Ordinary (f i) := typeEnvAt_ordinary 0 ts [] ht.kinds.ordinary
  have hm : TypeFormationMap a.context (a.typeContext ts) f := by
    refine ⟨?_, ho⟩
    intro i b hi
    simp only [AliasDecl.typeContext, List.getElem?_map, hi, Option.map_some, f, typeEnvAt_zero_eq_typesOnly, SubstEnv.typesOnly]
  have hin : ∀ i (hi : i < ts.length), f i = ts[i] := by
    intro i hi
    simp [f, typeEnvAt, hi, shiftTypes_zero]
  have hk : TypeImagesKinded P (TypeCtx.kinds a.tparams) (TypeCtx.kinds C) f := by
    intro i k hi
    have hlt : i < ts.length := by have := (List.getElem?_eq_some_iff.mp hi).1; simpa [TypeCtx.kinds, hn] using this
    rw [hin i hlt]
    exact ht.kinds.2 i _ k (List.getElem?_eq_getElem hlt) hi
  have hs : ∀ i, (f i).Sorted (a.typeContext ts) := by
    intro i
    by_cases hi : i < ts.length
    · rw [hin i hi]; exact ht.sorted _ (List.getElem_mem hi)
    · simp [f, typeEnvAt, hi, Ty.Sorted]
  have hd : ∀ i, (f i).Declared P C (a.typeContext ts) := by
    intro i
    by_cases hi : i < ts.length
    · rw [hin i hi]; exact ht.declared _ (List.getElem_mem hi)
    · simp [f, typeEnvAt, hi, Ty.Declared]
  refine ⟨?_, ?_, ?_⟩
  · have h := Ty.subst_wf ts [] ht.wf (by simp) ht.kinds.ordinary a.body (hn ▸ hwf.bodyWF)
    simpa only [AliasDecl.typeContext, List.length_map] using h
  · simpa only [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, f, typeEnvAt_zero_eq_typesOnly, SubstEnv.typesOnly] using
      Ty.sorted_norm (alias_sorted_types hwf.bodySorted hwf.bodyDeclared hm hk hs)
  · simpa only [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, f, typeEnvAt_zero_eq_typesOnly, SubstEnv.typesOnly] using
      (alias_declared_types hwf.bodyDeclared valid hm hk hd).norm

/-- 一般の別名の展開は、宣言・型引数・閉じた範囲引数の形成と、具体化した文脈の下の全 sort の値引数の像から、
展開先の文脈で注釈として整形式である。 -/
theorem AliasDecl.expand_annotation {P : Refinement.Program} {C : TypeCtx} {a : AliasDecl} {Γ : Ctx}
    {ts : List Ty} {vs : List Term} {rs : List RangeExpr} (hwf : a.WellFormed P) (valid : P.VarianceValid)
    (ht : AliasTypeArgs P C a ts) (hr : a.RangeArgs rs)
    (hσ : AliasArgs P C (a.instantiatedContext ts rs) Γ (aliasValueEnv vs)) :
    Ty.Annotation P C Γ (a.expand ts vs rs) := by
  obtain ⟨hw, hs, hd⟩ := a.subst_formation hwf valid ht
  have hb := instR_annotation hw hs hd hr.1
  exact aliasValues_annotation hb (Ty.Sorted.references hb.sorted) hσ

/-- 型パラメータを持たない別名の展開は、別名の宣言の整形式、範囲の実引数の条件、値引数の像の条件から注釈として
整形式である。範囲パラメータを持つ別名を含む。 -/
theorem AliasDecl.expand_annotation_monomorphic {P : Refinement.Program} {a : AliasDecl} {Γ : Ctx}
    {ts : List Ty} {vs : List Term} {rs : List RangeExpr} (hwf : a.WellFormed P) (ht : a.tparams = [])
    (hr : a.RangeArgs rs) (hσ : AliasArgs P a.tparams (a.rangeContext rs) Γ (aliasValueEnv vs)) :
    Ty.Annotation P a.tparams Γ (a.expand ts vs rs) := by
  have hw := hwf.bodyWF
  have hw0 := hw
  rw [ht] at hw0
  have he : a.body.subst ts [] = a.body.norm := Ty.substAt_nil_of_wf ts a.body hw0
  have hb := instR_annotation (C := a.tparams) (Ty.wf_norm hw) (Ty.sorted_norm hwf.bodySorted)
    hwf.bodyDeclared.norm hr.1
  unfold AliasDecl.expand
  rw [he]
  exact aliasValues_annotation hb (Ty.Sorted.references hb.sorted) hσ

/-! ## 例 -/

theorem windowAlias_wellFormed (P : Refinement.Program) : windowAlias.WellFormed P := by
  refine ⟨by decide, ?_, ?_, ?_, ?_, ?_⟩
  · intro p hp
    simp [windowAlias] at hp
    subst hp
    exact ⟨.integer, rfl⟩
  · simp [windowAlias, AliasDecl.context, Ty.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, bindParams, Ty.NotContCore, Ty.core]
  · simp [windowAlias, AliasDecl.context, Ty.Sorted, Pred.Sorted, Term.HasSort, Term.References, Term.Shape,
      Term.VarsIn, Ctx.Readable, bindParams, Ty.HasSort, Ty.sort?, Ty.shiftV, Ty.core]
  · simp [windowAlias, AliasDecl.context, Ty.Declared, Pred.Declared, Term.Declared, Ctx.declarationSelf,
      Ctx.Readable, bindParams, Ctx.extend, Ty.shiftV, Ty.core]
  · simp [windowAlias, Ty.RangesScoped]
theorem windowAlias_args (P : Refinement.Program) :
    AliasArgs P windowAlias.tparams (windowAlias.rangeContext []) [] (aliasValueEnv [.integer 10]) := by
  have hctx : windowAlias.rangeContext [] = [some (.base .integer)] := by
    simp [windowAlias, AliasDecl.rangeContext, AliasDecl.context, bindParams, Ty.shiftV, Ctx.rawMapRanges,
      Ty.rawMapRanges]
  refine ⟨?_, ?_, ?_, ⟨?_, ?_⟩⟩
  · intro i a hi _ t ht
    rw [hctx] at hi
    cases i with
    | zero =>
      simp [aliasValueEnv] at ht
      subst ht
      simp [termWF, Term.VarsIn]
    | succ j => simp at hi
  · intro i a s hi hs
    rw [hctx] at hi
    cases i with
    | zero =>
      simp at hi
      subst hi
      simp [Ty.HasSort, Ty.sort?] at hs
      subst hs
      exact ⟨.integer 10, rfl, by simp [Term.HasSort, Term.References, Term.Shape, Term.VarsIn]⟩
    | succ j => simp at hi
  · intro i a hi _ t ht
    rw [hctx] at hi
    cases i with
    | zero =>
      simp [aliasValueEnv] at ht
      subst ht
      simp [Term.References, Term.VarsIn]
    | succ j => simp at hi
  · intro i a hi _ t ht
    rw [hctx] at hi
    cases i with
    | zero =>
      simp [aliasValueEnv] at ht
      subst ht
      simp [Term.Declared]
    | succ j => simp at hi
  · intro i a d ts hi hd
    rw [hctx] at hi
    cases i with
    | zero =>
      simp at hi
      subst hi
      simp [Ty.norm, Ty.core] at hd
    | succ j => simp at hi

/-- `Window(10)` の展開は空の文脈で注釈として整形式である。 -/
theorem window_expand_annotation (P : Refinement.Program) :
    Ty.Annotation P [] [] (windowAlias.expand [] [.integer 10] []) :=
  AliasDecl.expand_annotation_monomorphic (windowAlias_wellFormed P) rfl ⟨rfl, fun _ _ _ h => by simp at h⟩
    (windowAlias_args P)

/-- 範囲パラメータを宣言し、本体が `Scope.PathIn[R]` の別名（`type InPath[range R: path] = Scope.PathIn[R]`）。 -/
def pathAlias : AliasDecl where
  tparams := []
  valueParams := []
  rangeParams := [.path]
  body := .scoped "Scope.PathIn" .path (.rvar 0)

theorem pathAlias_wellFormed (P : Refinement.Program) : pathAlias.WellFormed P :=
  ⟨by decide, by simp [pathAlias], by simp [pathAlias, Ty.WF, RangeIx.WF], by simp [pathAlias, Ty.Sorted],
    by simp [pathAlias, Ty.Declared], by simp [pathAlias, Ty.RangesScoped, RangeIx.WF]⟩

/-- 別名の範囲パラメータを閉じた範囲（全体のパス）で具体化した `InPath[/**]` は、空の文脈で注釈として整形式である。 -/
theorem pathAlias_expand_annotation (P : Refinement.Program) :
    Ty.Annotation P [] [] (pathAlias.expand [] [] [RangeExpr.top]) := by
  refine AliasDecl.expand_annotation_monomorphic (pathAlias_wellFormed P) rfl ⟨rfl, fun i r k hr hk => ?_⟩ ?_
  · cases i with
    | zero =>
      simp [pathAlias] at hr hk
      subst hr hk
      decide
    | succ j => simp at hr
  · have hctx : pathAlias.rangeContext [RangeExpr.top] = [] := rfl
    rw [hctx]
    exact ⟨fun _ _ h => by simp at h, fun _ _ _ h => by simp at h, fun _ _ h => by simp at h,
      ⟨fun _ _ h => by simp at h, fun _ _ _ _ h => by simp at h⟩⟩

/-- 型引数 A、値引数 n、範囲引数 R を持つ別名。長さ n の List[A] から Scope.PathIn[R] への関数である。 -/
def sizedPathAlias : AliasDecl where
  tparams := [TypeCtx.valueParam]
  valueParams := [("n", .base .integer)]
  rangeParams := [.path]
  body := .fn ["items"] [.refined (.list (.tvar 0)) (.eq (.measure .listLength (.var 0)) (.var 1))]
    (.scoped "Scope.PathIn" .path (.rvar 0)) Eff.empty

theorem sizedPathAlias_wellFormed (P : Refinement.Program) : sizedPathAlias.WellFormed P := by
  refine ⟨by decide, ?_, ?_, ?_, ?_, ?_⟩
  · intro p hp
    simp [sizedPathAlias] at hp
    subst hp
    exact ⟨.integer, rfl⟩
  · simp [sizedPathAlias, AliasDecl.context, bindParams, Ty.shiftV, Ty.WF, Ty.WFList, Eff.WF,
      Eff.empty, Eff.Canonical, Eff.norm, RangeIx.WF, Pred.WF, Pred.VarsIn, Term.VarsIn, NamesWF, Ty.NotContCore, Ty.core]
  · simp [sizedPathAlias, AliasDecl.context, bindParams, Ty.shiftV, Ty.Sorted, sortedTys, sortedEff,
      Eff.empty, Pred.Sorted, Term.HasSort, Term.References, Term.Shape, Term.VarsIn, Ctx.Readable,
      Ty.HasSort, Ty.sort?, Measure.input, Measure.output]
  · simp [sizedPathAlias, AliasDecl.context, bindParams, Ty.shiftV, Ty.Declared, declaredTys,
      declaredEff, Eff.empty, Pred.Declared, Term.Declared, Ctx.declarationSelf, Ctx.Readable, Ctx.extend,
      Ty.core]
  · simp [sizedPathAlias, Ty.RangesScoped, rangesScopedTypes, Eff.RangesScoped, Eff.empty, RangeIx.WF]

theorem sizedPathAlias_typeArgs (P : Refinement.Program) :
    AliasTypeArgs P [] sizedPathAlias [.base .integer] := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · refine ⟨rfl, ?_⟩
    intro i t k ht hk
    cases i with
    | zero => simp [sizedPathAlias, TypeCtx.kinds, TypeCtx.valueParam] at ht hk; subst ht hk; simp [Ty.HasKind, Ordinary, Ty.core]
    | succ i => simp at ht
  · intro t ht; simp at ht; subst ht; trivial
  · intro t ht; simp at ht; subst ht; trivial
  · intro t ht; simp at ht; subst ht; trivial

theorem sizedPathAlias_args (P : Refinement.Program) :
    AliasArgs P [] (sizedPathAlias.instantiatedContext [.base .integer] [RangeExpr.top]) []
      (aliasValueEnv [.integer 10]) := by
  have he : sizedPathAlias.instantiatedContext [.base .integer] [RangeExpr.top] = windowAlias.rangeContext [] := rfl
  rw [he]
  exact windowAlias_args P

/-- 三種類の引数を同時に具体化した展開は、一般の展開定理から空の文脈で注釈として整形式である。 -/
theorem sizedPathAlias_expand_annotation {P : Refinement.Program} (valid : P.VarianceValid) :
    Ty.Annotation P [] [] (sizedPathAlias.expand [.base .integer] [.integer 10] [RangeExpr.top]) := by
  refine AliasDecl.expand_annotation (sizedPathAlias_wellFormed P) valid (sizedPathAlias_typeArgs P)
    ⟨rfl, ?_⟩ (sizedPathAlias_args P)
  intro i r k hr hk
  cases i with
  | zero => simp [sizedPathAlias] at hr hk; subst hr hk; decide
  | succ i => simp at hr

/-- 宣言を持たない具体のプログラムでも、三種類の引数を持つ別名の形成の前提は満たせる。 -/
example : Ty.Annotation
    (⟨fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, fun _ => none, [], fun _ => none⟩ : Refinement.Program)
    [] [] (sizedPathAlias.expand [.base .integer] [.integer 10] [RangeExpr.top]) :=
  sizedPathAlias_expand_annotation ⟨(fun _ _ h => by cases h), (fun _ _ h => by cases h)⟩

example : aliasValueEnv [.integer 10] 0 = some (.integer 10) := rfl
example : aliasValueEnv [.integer 1, .integer 2] 0 = some (.integer 2) := rfl
example : windowAlias.context = bindParams [] [.base .integer] := rfl

end Benitoite.Release.Refinement.Surface
