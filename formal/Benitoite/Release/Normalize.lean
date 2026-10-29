import Benitoite.Release.Order.Types

/-!
# 型とエフェクトの正規形

型内部を先に正規化し、Fail の型の列を固定順で整列して重複を除く。
名前と行の関数は変更しない（設計書 07-04「01-12 との対応」）。
-/

namespace Benitoite.Release

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
    cases t <;> simp only [Ty.norm, Ty.norm_idem, Ty.normTys_idem, Eff.norm_idem]

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
  /-- Fail のない旧型は、効果の支持の有限性によらず保持する。 -/
  def Ty.Legacy : Ty → Prop
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ => True
    | .data _ as | .tapp _ as => Ty.LegacyTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.Legacy
    | .fn _ ps r e => Ty.LegacyTys ps ∧ r.Legacy ∧ Eff.Legacy e
    | .cont b t e => b.Legacy ∧ t.Legacy ∧ Eff.Legacy e
    | .map a b => a.Legacy ∧ b.Legacy

  def Ty.LegacyTys : List Ty → Prop
    | [] => True
    | a :: as => a.Legacy ∧ Ty.LegacyTys as

  def Eff.Legacy (e : Eff) : Prop := e.fails = []
end

mutual
  /-- 旧型の正規化は恒等である。 -/
  theorem Ty.norm_legacy (t : Ty) (h : t.Legacy) : t.norm = t := by
    cases t <;> simp only [Ty.Legacy] at h <;>
      simp only [Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.norm_legacy _ h)
      | exact congrArg _ (Ty.normTys_legacy _ h)
      | skip
    case fn ns ps r e =>
      rw [Ty.normTys_legacy ps h.1, Ty.norm_legacy r h.2.1, Eff.norm_legacy e h.2.2]
    case cont b t e =>
      rw [Ty.norm_legacy b h.1, Ty.norm_legacy t h.2.1, Eff.norm_legacy e h.2.2]
    case map a b => rw [Ty.norm_legacy a h.1, Ty.norm_legacy b h.2]

  theorem Ty.normTys_legacy (as : List Ty) (h : Ty.LegacyTys as) : Ty.normTys as = as := by
    cases as with
    | nil => rfl
    | cons a as =>
      simp only [Ty.normTys, Ty.norm_legacy a h.1, Ty.normTys_legacy as h.2]

  /-- Fail 列が空なら、原子の関数の比較へ到達しない。 -/
  theorem Eff.norm_legacy (e : Eff) (h : e.Legacy) : e.norm = e := by
    cases e with
    | mk a fs => cases h; rfl
end

mutual
  /-- すべての深さで Fail の列が高々一要素である。 -/
  def Ty.FailsLeOne : Ty → Prop
    | .base _ | .opaque _ _ | .tvar _ | .bytes | .ctor _ => True
    | .data _ as | .tapp _ as => Ty.FailsLeOneTys as
    | .list a | .reference a | .lazy a | .set a | .dict _ a => a.FailsLeOne
    | .fn _ ps r e => Ty.FailsLeOneTys ps ∧ r.FailsLeOne ∧ Eff.FailsLeOne e
    | .cont b t e => b.FailsLeOne ∧ t.FailsLeOne ∧ Eff.FailsLeOne e
    | .map a b => a.FailsLeOne ∧ b.FailsLeOne

  def Ty.FailsLeOneTys : List Ty → Prop
    | [] => True
    | a :: as => a.FailsLeOne ∧ Ty.FailsLeOneTys as

  def Eff.FailsLeOne : Eff → Prop
    | .mk _ fs => fs.length ≤ 1 ∧ Ty.FailsLeOneTys fs
end

mutual
  /-- 読者が作る高々一つの Fail の型は、比較の計算を必要とせず正規形となる。 -/
  theorem Ty.canonical_of_failsLeOne (t : Ty) (h : t.FailsLeOne) : t.Canonical := by
    cases t <;> simp only [Ty.FailsLeOne] at h <;> unfold Ty.Canonical <;> simp only [Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.canonical_of_failsLeOne _ h)
      | exact congrArg _ (Ty.canonicalTys_of_failsLeOne _ h)
      | skip
    case fn ns ps r e =>
      rw [Ty.canonicalTys_of_failsLeOne ps h.1, Ty.canonical_of_failsLeOne r h.2.1,
        Eff.canonical_of_failsLeOne e h.2.2]
    case cont b t e =>
      rw [Ty.canonical_of_failsLeOne b h.1, Ty.canonical_of_failsLeOne t h.2.1,
        Eff.canonical_of_failsLeOne e h.2.2]
    case map a b => rw [Ty.canonical_of_failsLeOne a h.1, Ty.canonical_of_failsLeOne b h.2]

  theorem Ty.canonicalTys_of_failsLeOne (as : List Ty) (h : Ty.FailsLeOneTys as) : Ty.normTys as = as := by
    cases as with
    | nil => rfl
    | cons a as =>
      rw [Ty.normTys, Ty.canonical_of_failsLeOne a h.1, Ty.canonicalTys_of_failsLeOne as h.2]

  theorem Eff.canonical_of_failsLeOne (e : Eff) (h : Eff.FailsLeOne e) : Eff.Canonical e := by
    cases e with
    | mk a fs =>
      obtain ⟨hlen, hfs⟩ := h
      unfold Eff.Canonical
      simp only [Eff.norm, Ty.canonicalTys_of_failsLeOne fs hfs]
      cases fs with
      | nil => rfl
      | cons t ts =>
        cases ts with
        | nil => rfl
        | cons u us => simp at hlen
end

end Benitoite.Release
