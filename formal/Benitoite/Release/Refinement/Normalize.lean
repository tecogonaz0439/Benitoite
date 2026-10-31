import Benitoite.Release.Refinement.RefinementNormalForm

/-!
# 型とエフェクトの正規形

型内部を先に正規化し、Fail の型の列を固定順で整列して重複を除く。
名前と行の関数は変更しない（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release.Refinement

open Order

mutual
  /-- 型のすべての子と、埋め込まれた効果を正規化する。 -/
  noncomputable def Ty.norm : Ty → Ty
    | .base b => .base b
    | .opaque o r => .opaque o r
    | .data d as => .data d (Ty.normTys as)
    | .list a => .list a.norm
    | .fn ns ps r e => .fn ns (Ty.normTys ps) r.norm (Eff.norm e)
    | .tvar i => .tvar i
    | .reference a => .reference a.norm
    | .lazy a => .lazy a.norm
    | .cont b t e => .cont b.norm t.norm (Eff.norm e)
    | .map a b => .map a.norm b.norm
    | .set a => .set a.norm
    | .bytes => .bytes
    | .dict cl a => .dict cl a.norm
    | .tapp i as => .tapp i (Ty.normTys as)
    | .ctor c => .ctor c
    | .refined a p => Ty.refineNorm a.norm p
    | .dependentFn t => Ty.foldFn (Tel.norm t)
    | .external id as => .external id (Ty.normTys as)
    | .scoped o k ix => .scoped o k ix
    | .pathBases => .pathBases
    | .scopePattern k => .scopePattern k
  termination_by structural t => t

  noncomputable def Tel.norm : Tel → Tel
    | .done r e => .done r.norm (Eff.norm e)
    | .param n a t => .param n a.norm (Tel.norm t)
  termination_by structural t => t

  /-- 型列も同じ構造再帰に含める。 -/
  noncomputable def Ty.normTys : List Ty → List Ty
    | [] => []
    | a :: as => a.norm :: Ty.normTys as
  termination_by structural as => as

  /-- 名前と行を保ち、子の正規化後に Fail 列を整列する。 -/
  noncomputable def Eff.norm : Eff → Eff
    | .mk a fs => .mk a (sortUnique tyCompare (Ty.normTys fs))
  termination_by structural e => e
end

@[simp] theorem Ty.normTys_eq_map (as : List Ty) : Ty.normTys as = as.map Ty.norm := by
  induction as with
  | nil => rfl
  | cons a as ih => simp only [Ty.normTys, List.map_cons, ih]

/-- 正規形は正規化の固定点である。 -/
def Ty.Canonical (t : Ty) : Prop := t.norm = t

/-- 最上位の計算の効果には、この条件を要求しない。 -/
def Eff.Canonical (e : Eff) : Prop := e.norm = e

/-- 型の正規形は norm の固定点である。WFとは別の判断である。 -/
abbrev Ty.Normal (a : Ty) : Prop := a.Canonical
def Tel.Normal (t : Tel) : Prop := Tel.norm t = t

mutual
  theorem Ty.norm_shiftV (a : Ty) (k c : Nat) :
      (a.shiftV k c).norm = a.norm.shiftV k c := by
    cases a <;> simp only [Ty.shiftV, Ty.norm, Ty.norm_shiftV, Ty.normTys_shiftV, Eff.norm_shiftV, Tel.norm_shiftV, Ty.foldFn_shiftV]
    case refined a p => exact (Ty.refineNorm_shiftV a.norm p k c).symm
  theorem Tel.norm_shiftV (t : Tel) (k c : Nat) :
      Tel.norm (Tel.shiftV k c t) = Tel.shiftV k c (Tel.norm t) := by
    cases t <;> simp only [Tel.norm, Tel.shiftV, Ty.norm_shiftV, Eff.norm_shiftV, Tel.norm_shiftV]
  theorem Ty.normTys_shiftV (as : List Ty) (k c : Nat) :
      Ty.normTys (shiftVTys k c as) = shiftVTys k c (Ty.normTys as) := by
    cases as <;> simp only [shiftVTys, Ty.normTys, Ty.norm_shiftV, Ty.normTys_shiftV]
  theorem Eff.norm_shiftV (e : Eff) (k c : Nat) :
      (Eff.shiftV k c e).norm = Eff.shiftV k c e.norm := by
    cases e with
    | mk a fs =>
      simp only [Eff.shiftV, Eff.norm]
      rw [Ty.normTys_shiftV]
      simp only [shiftVTys_eq_map]
      rw [sortUnique_map tyCompare tyCompare (Ty.shiftV k c) (Ty.shiftV_compare k c)]
end

theorem Tel.norm_toTel (ns ps r e) :
    Tel.norm (Ty.toTel ns ps r e) = Ty.toTel ns (Ty.normTys ps) r.norm e.norm := by
  induction ns generalizing ps r e with
  | nil => rfl
  | cons n ns ih =>
    cases ps with
    | nil => rfl
    | cons a ps =>
      simp only [Ty.toTel, Ty.normTys, Tel.norm, ih, Ty.normTys_shiftV, Ty.norm_shiftV, Eff.norm_shiftV]


@[simp] theorem Ty.core_norm (a : Ty) : a.norm.core = a.core.norm := by
  cases a <;> first | rfl | skip
  case refined a p => exact (Ty.core_refineNorm a.norm p).trans (Ty.core_norm a)
  case dependentFn t => exact Ty.core_foldFn (Tel.norm t)

@[simp] theorem Ty.predicates_norm (a : Ty) : a.norm.refinementPredicates = a.refinementPredicates := by
  cases a <;> first | rfl | skip
  case refined a p =>
    rw [Ty.norm, Ty.predicates_refineNorm, Ty.predicates_norm]
    rfl
  case dependentFn t => exact Ty.predicates_foldFn (Tel.norm t)

theorem Ty.norm_packRefinements (a : Ty) (ps : List Pred) (hc : a.core = a)
    (hp : ∀ p ∈ ps, p.ConjAtom) :
    (Ty.packRefinements a ps).norm = Ty.packRefinements a.norm ps := by
  cases ps with
  | nil => rfl
  | cons p ps =>
    have hz : a.refinementPredicates = [] := by
      rw [←hc]; exact Ty.predicates_core a
    simp only [Ty.packRefinements, Ty.norm, Ty.refineNorm, Ty.core_norm, hc,
      Ty.predicates_norm, hz, List.nil_append, Pred.conjuncts_ofConjuncts hp]

theorem Ty.norm_refineNorm (a : Ty) (p : Pred) :
    (Ty.refineNorm a p).norm = Ty.refineNorm a.norm p := by
  unfold Ty.refineNorm
  rw [Ty.norm_packRefinements _ _ (Ty.core_idem a)]
  · rw [Ty.core_norm, Ty.predicates_norm]
  · intro q hq
    rcases List.mem_append.mp hq with hq | hq
    · exact Ty.refinementPredicates_atoms a q hq
    · exact Pred.conjuncts_atoms p q hq

noncomputable def FnView.norm (f : FnView) : FnView :=
  ⟨f.names, Ty.normTys f.params, f.result.norm, f.effect.norm,
    ⟨by simpa only [Ty.normTys_eq_map, List.length_map] using f.names_wf.1, f.names_wf.2⟩⟩

theorem FnView.norm_toTel (f : FnView) : f.norm.toTel = Tel.norm f.toTel :=
  (Tel.norm_toTel _ _ _ _).symm

theorem Ty.norm_foldFn (t : Tel) : (Ty.foldFn t).norm = Ty.foldFn (Tel.norm t) := by
  classical
  by_cases h : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := h
    rw [Ty.foldFn_toTel, ←FnView.norm_toTel, Ty.foldFn_toTel]
    rfl
  · rw [Ty.foldFn_no_view h]
    rfl

theorem Ty.norm_toTel {ns ps r e} (hn : NamesWF ns ps) :
    (Ty.dependentFn (Ty.toTel ns ps r e)).norm = (Ty.fn ns ps r e).norm := by
  let f : FnView := ⟨ns, ps, r, e, hn⟩
  change Ty.foldFn (Tel.norm f.toTel) = (Ty.fn ns ps r e).norm
  rw [←FnView.norm_toTel, Ty.foldFn_toTel]
  rfl

theorem Ty.norm_reconstruct (a : Ty) :
    a.norm = Ty.packRefinements a.core.norm a.refinementPredicates := by
  cases a <;> first | rfl | skip
  case refined a p =>
    simp only [Ty.norm, Ty.refineNorm, Ty.core_norm, Ty.predicates_norm, Ty.core,
      Ty.refinementPredicates]

theorem Ty.pack_parts_norm (a : Ty) :
    Ty.packRefinements a.norm.core a.norm.refinementPredicates = a.norm := by
  rw [Ty.core_norm, Ty.predicates_norm, ←Ty.norm_reconstruct]

theorem Ty.norm_refined_truth (a : Ty) : (Ty.refined a .truth).norm = a.norm := by
  simp only [Ty.norm, Ty.refineNorm, Pred.conjuncts, List.append_nil, Ty.pack_parts_norm]

private theorem normTys_sortUnique {as : List Ty} (h : Ty.normTys as = as) :
    Ty.normTys (sortUnique tyCompare as) = sortUnique tyCompare as := by
  rw [Ty.normTys_eq_map] at h ⊢
  have hf : ∀ a ∈ as, a.norm = a := by
    intro a ha
    exact List.map_eq_map_iff.mp (h.trans (List.map_id as).symm) a ha
  induction hs : sortUnique tyCompare as with
  | nil => rfl
  | cons a bs _ih =>
    simp only [List.map_cons]
    congr 1
    · exact hf a (mem_sortUnique.mp (by rw [hs]; exact List.mem_cons_self))
    · calc
        bs.map Ty.norm = bs.map id := List.map_congr_left (fun b hb =>
          hf b (mem_sortUnique.mp (by rw [hs]; exact List.mem_cons_of_mem a hb)))
        _ = bs := List.map_id bs

mutual
  /-- 正規化は型で冪等である。 -/
  theorem Ty.norm_idem (t : Ty) : t.norm.norm = t.norm := by
    cases t <;> simp only [Ty.norm, Ty.norm_idem, Ty.normTys_idem, Eff.norm_idem,
      Tel.norm_idem, Ty.norm_refineNorm, Ty.norm_foldFn]

  theorem Tel.norm_idem (t : Tel) : (Tel.norm (Tel.norm t)) = Tel.norm t := by
    cases t <;> simp only [Tel.norm, Ty.norm_idem, Eff.norm_idem, Tel.norm_idem]

  /-- 型列でも二度目の正規化は変化を起こさない。 -/
  theorem Ty.normTys_idem (as : List Ty) : Ty.normTys (Ty.normTys as) = Ty.normTys as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [Ty.normTys, Ty.norm_idem, Ty.normTys_idem]

  /-- 効果でも子の冪等性と整列の冪等性を使う。 -/
  theorem Eff.norm_idem (e : Eff) : e.norm.norm = e.norm := by
    cases e with
    | mk a fs =>
      simp only [Eff.norm, normTys_sortUnique (Ty.normTys_idem fs), sortUnique_idem]
end

/-- 生の効果の Fail 所属は、要素の正規形によって定める。 -/
def Eff.memFail (e : Eff) (t : Ty) : Prop := ∃ x ∈ e.fails, x.norm = t.norm

/-- 正規化前後で Fail の意味を保つ。 -/
theorem Eff.norm_memFail (e : Eff) (t : Ty) : e.norm.memFail t ↔ e.memFail t := by
  cases e with
  | mk a fs =>
    simp only [Eff.memFail, Eff.norm, Eff.fails, mem_sortUnique, Ty.normTys_eq_map, List.mem_map]
    constructor
    · rintro ⟨x, ⟨y, hy, rfl⟩, hx⟩
      exact ⟨y, hy, (Ty.norm_idem y) ▸ hx⟩
    · rintro ⟨x, hx, ht⟩
      exact ⟨x.norm, ⟨x, hx, rfl⟩, (Ty.norm_idem x).trans ht⟩



mutual
  /-- 旧正規化の後に写しても、新型上で正規化しても同じである。 -/
  theorem embedTy_norm (a : Benitoite.Release.Ty) :
      embedTy a.norm = (embedTy a).norm := by
    cases a <;> simp only [Benitoite.Release.Ty.norm, embedTy, Ty.norm,
      embedTy_norm, embedTys_norm, embedEff_norm]
  private theorem embedTys_norm (as : List Benitoite.Release.Ty) :
      embedTys (Benitoite.Release.Ty.normTys as) = Ty.normTys (embedTys as) := by
    cases as <;> simp only [Benitoite.Release.Ty.normTys, embedTys, Ty.normTys,
      embedTy_norm, embedTys_norm]
  theorem embedEff_norm (e : Benitoite.Release.Eff) :
      embedEff e.norm = (embedEff e).norm := by
    cases e with
    | mk a fs =>
      simp only [Benitoite.Release.Eff.norm, embedEff, Eff.norm]
      rw [embedTys_eq_map, ← sortUnique_map _ _ _ tyCompare_embed,
        ← embedTys_eq_map, embedTys_norm]
end

theorem embed_memFail (e : Benitoite.Release.Eff) (t : Benitoite.Release.Ty) :
    e.memFail t ↔ (embedEff e).memFail (embedTy t) := by
  cases e with
  | mk a fs =>
    simp only [Benitoite.Release.Eff.memFail, Benitoite.Release.Eff.fails,
      Eff.memFail, embedEff, Eff.fails, embedTys_eq_map, List.mem_map]
    constructor
    · rintro ⟨x, hx, he⟩
      exact ⟨embedTy x, ⟨x, hx, rfl⟩, by rw [← embedTy_norm, ← embedTy_norm, he]⟩
    · rintro ⟨_, ⟨x, hx, rfl⟩, he⟩
      exact ⟨x, hx, embedTy_injective (by simpa only [embedTy_norm] using he)⟩

theorem embed_canonical {e : Benitoite.Release.Eff} (h : e.Canonical) :
    (embedEff e).Canonical := by
  unfold Eff.Canonical
  rw [← embedEff_norm, h]


def Eff.empty : Eff := .mk (fun _ => false) []
noncomputable def Eff.singleFail (t : Ty) : Eff := .mk (fun _ => false) [t.norm]
noncomputable def Eff.union (e f : Eff) : Eff :=
  Eff.norm (.mk (fun a => e.test a || f.test a) (e.fails ++ f.fails))

end Benitoite.Release.Refinement
