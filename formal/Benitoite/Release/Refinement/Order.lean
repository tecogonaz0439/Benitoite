import Benitoite.Release.Refinement.Types

/-!
# 篩を含む型の辞書式比較

有限の項と述語を木へ写し、子の型と Fail の生の構造を区別する。
-/

namespace Benitoite.Release.Refinement
open Std Order

private def intTree : Int → Tree Label
  | .ofNat n => .node (.rank 0) [.node (.nat n) []]
  | .negSucc n => .node (.rank 1) [.node (.nat n) []]

private theorem intTree_injective {a b : Int} (h : intTree a = intTree b) : a = b := by
  cases a <;> cases b <;> simp_all [intTree, Tree.node.injEq]

def termTree : Term → Tree Label
  | .var i => .node (.rank 0) [.node (.nat i) []]
  | .integer n => .node (.rank 1) [intTree n]
  | .add a b => .node (.rank 2) [termTree a, termTree b]

private theorem termTree_injective {a b : Term} (h : termTree a = termTree b) : a = b := by
  cases a <;> cases b <;> simp only [termTree, Tree.node.injEq, List.cons.injEq,
    Label.rank.injEq, Label.nat.injEq, Nat.reduceEqDiff, and_true, true_and, false_and] at h
  all_goals first
    | contradiction
    | exact congrArg Term.var h
    | exact congrArg Term.integer (intTree_injective h)
    | obtain ⟨ha, hb⟩ := h
      have ha := termTree_injective ha
      have hb := termTree_injective hb
      cases ha; cases hb; rfl

def predTree : Pred → Tree Label
  | .truth => .node (.rank 0) []
  | .falsity => .node (.rank 1) []
  | .eq a b => .node (.rank 2) [termTree a, termTree b]
  | .le a b => .node (.rank 3) [termTree a, termTree b]
  | .lt a b => .node (.rank 4) [termTree a, termTree b]
  | .and p q => .node (.rank 5) [predTree p, predTree q]
  | .or p q => .node (.rank 6) [predTree p, predTree q]
  | .not p => .node (.rank 7) [predTree p]

private theorem predTree_injective {a b : Pred} (h : predTree a = predTree b) : a = b := by
  cases a <;> cases b <;> simp only [predTree, Tree.node.injEq, List.cons.injEq,
    Label.rank.injEq, Nat.reduceEqDiff, and_true, true_and, false_and] at h
  all_goals first
    | contradiction
    | rfl
    | exact congrArg Pred.not (predTree_injective h)
    | obtain ⟨ha, hb⟩ := h
      first
        | have ha := termTree_injective ha
          have hb := termTree_injective hb
          cases ha; cases hb; rfl
        | have ha := predTree_injective ha
          have hb := predTree_injective hb
          cases ha; cases hb; rfl

mutual
  /-- 欄の境界を子の木で区切り、名前・引数・結果・潜在効果をすべて保持する。 -/
  def Ty.toTree : Ty → Tree Label
    | .base b => .node (.rank 0) [.node (.nat b.rank) []]
    | .opaque o r => .node (.rank 1) [.node (.text o) [], .node (.nat (Order.ixCode r)) []]
    | .data d args => .node (.rank 2) [.node (.text d) [], .node (.rank 0) (Ty.toTrees args)]
    | .list a => .node (.rank 3) [a.toTree]
    | .fn names params ret eff => .node (.rank 4)
        [.node (.texts names) [], .node (.rank 0) (Ty.toTrees params), ret.toTree,
          Eff.toTree eff]
    | .tvar i => .node (.rank 5) [.node (.nat i) []]
    | .reference a => .node (.rank 6) [a.toTree]
    | .lazy a => .node (.rank 7) [a.toTree]
    | .cont b t eff => .node (.rank 8) [b.toTree, t.toTree, Eff.toTree eff]
    | .map k v => .node (.rank 9) [k.toTree, v.toTree]
    | .set a => .node (.rank 10) [a.toTree]
    | .bytes => .node (.rank 11) []
    | .dict cl a => .node (.rank 12) [.node (.text cl) [], a.toTree]
    | .tapp i args => .node (.rank 13) [.node (.nat i) [], .node (.rank 0) (Ty.toTrees args)]
    | .ctor c => .node (.rank 14) [c.toTree]
    | .refined a p => .node (.rank 15) [a.toTree, predTree p]

  /-- 効果の欄と Fail 列の順序を保持する。 -/
  def Eff.toTree : Eff → Tree Label
    | .mk a fs => .node (.atoms a) (Ty.toTrees fs)

  /-- 型列をそのままの順序で木の列へ写す。 -/
  def Ty.toTrees : List Ty → List (Tree Label)
    | [] => []
    | a :: as => a.toTree :: Ty.toTrees as
end

mutual
  /-- 木の等号から、元の共有型の生の等号を導く。 -/
  private theorem Ty.toTree_injective {a b : Ty} (h : a.toTree = b.toTree) : a = b := by
    cases a <;> cases b <;>
      simp only [Ty.toTree, Tree.node.injEq, List.cons.injEq,
        Label.rank.injEq, Label.nat.injEq, Label.text.injEq, Label.texts.injEq,
        Nat.reduceEqDiff, and_true, true_and, false_and] at h
    all_goals first
      | contradiction
      | exact congrArg Ty.base (BaseTy.rank_injective h)
      | exact congrArg Ty.list (Ty.toTree_injective h)
      | exact congrArg Ty.tvar h
      | exact congrArg Ty.reference (Ty.toTree_injective h)
      | exact congrArg Ty.lazy (Ty.toTree_injective h)
      | exact congrArg Ty.set (Ty.toTree_injective h)
      | exact congrArg Ty.ctor (TyCon.toTree_injective h)
      | rfl
      | skip
    case opaque.opaque =>
      obtain ⟨rfl, h⟩ := h
      rw [Order.ixCode_injective h]
    case data.data =>
      obtain ⟨rfl, h⟩ := h
      exact congrArg (Ty.data _) (Ty.toTrees_injective h)
    case fn.fn =>
      obtain ⟨rfl, hp, hr, he⟩ := h
      have he := Eff.toTree_injective he
      cases he
      have hp := Ty.toTrees_injective hp
      have hr := Ty.toTree_injective hr
      cases hp; cases hr; rfl
    case cont.cont =>
      obtain ⟨hb, ht, he⟩ := h
      have he := Eff.toTree_injective he
      cases he
      have hb := Ty.toTree_injective hb
      have ht := Ty.toTree_injective ht
      cases hb; cases ht; rfl
    case map.map =>
      obtain ⟨hk, hv⟩ := h
      have hk := Ty.toTree_injective hk
      have hv := Ty.toTree_injective hv
      cases hk; cases hv; rfl
    case dict.dict =>
      obtain ⟨rfl, h⟩ := h
      exact congrArg (Ty.dict _) (Ty.toTree_injective h)
    case refined.refined =>
      obtain ⟨ha, hp⟩ := h
      have ha := Ty.toTree_injective ha
      have hp := predTree_injective hp
      cases ha; cases hp; rfl
    case tapp.tapp =>
      obtain ⟨rfl, h⟩ := h
      exact congrArg (Ty.tapp _) (Ty.toTrees_injective h)

  /-- 効果の写像も、生の Fail 列を区別する。 -/
  private theorem Eff.toTree_injective {e f : Eff} (h : e.toTree = f.toTree) : e = f := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs =>
        have h := Tree.node.inj h
        have ha := Label.atoms.inj h.1
        have hf := Ty.toTrees_injective h.2
        cases ha; cases hf; rfl

  /-- 木の列への写像も、型列の順序と長さを区別する。 -/
  private theorem Ty.toTrees_injective {as bs : List Ty} (h : Ty.toTrees as = Ty.toTrees bs) : as = bs := by
    cases as with
    | nil => cases bs <;> simp_all [Ty.toTrees]
    | cons a as =>
      cases bs with
      | nil => simp [Ty.toTrees] at h
      | cons b bs =>
        obtain ⟨ha, ht⟩ := List.cons.inj h
        have ha := Ty.toTree_injective ha
        have ht := Ty.toTrees_injective ht
        cases ha; cases ht; rfl
end


noncomputable def tyCompare (a b : Ty) : Ordering := treeCompare labelCompare a.toTree b.toTree

/-- 比較の eq は、型の生の等号と同値である。 -/
theorem tyCompare_eq_iff (a b : Ty) : tyCompare a b = .eq ↔ a = b := by
  rw [tyCompare, treeCompare_eq_iff]
  exact ⟨Ty.toTree_injective, congrArg Ty.toTree⟩

instance : LawfulEqCmp tyCompare where
  compare_self := (tyCompare_eq_iff _ _).mpr rfl
  eq_of_compare := (tyCompare_eq_iff _ _).mp

instance : TransCmp tyCompare where
  eq_swap {a b} := by
    simpa only [tyCompare] using
      (treeCompare_swap (cmp := labelCompare) a.toTree b.toTree)
  isLE_trans {a b c} hab hbc := by
    simpa only [tyCompare] using
      (treeCompare_isLE_trans (cmp := labelCompare) a.toTree b.toTree c.toTree
        (by simpa only [tyCompare] using hab)
        (by simpa only [tyCompare] using hbc))

/-- 型の比較は全域であり、有限支持を仮定しない。 -/
theorem tyCompare_total (a b : Ty) :
    tyCompare a b = .lt ∨ a = b ∨ tyCompare b a = .lt := by
  cases h : tyCompare a b with
  | lt => exact Or.inl rfl
  | eq => exact Or.inr (Or.inl ((tyCompare_eq_iff a b).mp h))
  | gt => exact Or.inr (Or.inr (OrientedCmp.lt_of_gt h))

/-- 狭義比較は推移する。 -/
theorem tyCompare_lt_trans {a b c : Ty}
    (hab : tyCompare a b = .lt) (hbc : tyCompare b c = .lt) : tyCompare a c = .lt :=
  TransCmp.lt_trans hab hbc

/-- 双方向の非狭義比較から、型の生の等号を導く。 -/
theorem tyCompare_antisymm {a b : Ty}
    (hab : (tyCompare a b).isLE) (hba : (tyCompare b a).isLE) : a = b :=
  (tyCompare_eq_iff a b).mp (Ordering.eq_eq_of_isLE_of_isLE_swap hab
    (by simpa only [← OrientedCmp.eq_swap] using hba))


mutual
  private theorem tree_embed (a : Benitoite.Release.Ty) : (embedTy a).toTree = a.toTree := by
    cases a <;> simp only [embedTy, Ty.toTree, Benitoite.Release.Ty.toTree,
      tree_embed, trees_embed, eff_tree_embed]
  private theorem trees_embed (as : List Benitoite.Release.Ty) :
      Ty.toTrees (embedTys as) = Benitoite.Release.Ty.toTrees as := by
    cases as <;> simp only [embedTys, Ty.toTrees, Benitoite.Release.Ty.toTrees,
      tree_embed, trees_embed]
  private theorem eff_tree_embed (e : Benitoite.Release.Eff) :
      Eff.toTree (embedEff e) = Benitoite.Release.Eff.toTree e := by
    cases e <;> simp only [embedEff, Eff.toTree, Benitoite.Release.Eff.toTree, trees_embed]
end

/-- 旧型の像について比較順を変えない。 -/
theorem tyCompare_embed (a b : Benitoite.Release.Ty) :
    tyCompare (embedTy a) (embedTy b) = Benitoite.Release.tyCompare a b := by
  rw [tyCompare, tree_embed, tree_embed, Benitoite.Release.tyCompare_eq_treeCompare]

/-- 埋め込みは型の生の等号を反映する。 -/
theorem embedTy_injective : Function.Injective embedTy := by
  intro a b h
  apply Benitoite.Release.Ty.toTree_injective
  simpa only [tree_embed] using congrArg Ty.toTree h

end Benitoite.Release.Refinement
