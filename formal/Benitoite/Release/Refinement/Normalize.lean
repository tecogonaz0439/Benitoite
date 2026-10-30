import Benitoite.Release.Refinement.Order

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
    | .refined a p => .refined a.norm p
    | .dependentFn t => .dependentFn (Tel.norm t)
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
    cases t <;> simp only [Ty.norm, Ty.norm_idem, Ty.normTys_idem, Eff.norm_idem, Tel.norm_idem]

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
