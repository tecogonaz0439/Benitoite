import Benitoite.Release.Refinement.Types
import Benitoite.Release.Refinement.AtomOrder

/-!
# 篩を含む型の辞書式比較

有限の項と述語を木へ写し、子の型と Fail の生の構造を区別する。
-/

namespace Benitoite.Release.Refinement
open Std Order

mutual
  def termTree : Term → Tree Label
    | .var x0 => .node (.rank 0) [.node (.nat (code x0)) []]
    | .integer x0 => .node (.rank 1) [.node (.nat (code x0)) []]
    | .add x0 x1 => .node (.rank 2) [termTree x0, termTree x1]
    | .character x0 => .node (.rank 3) [.node (.nat (code x0)) []]
    | .float64 x0 => .node (.rank 4) [.node (.nat (code x0)) []]
    | .float32 x0 => .node (.rank 5) [.node (.nat (code x0)) []]
    | .decimal x0 x1 => .node (.rank 6) [.node (.nat (code x0)) [], .node (.nat (code x1)) []]
    | .boolean x0 => .node (.rank 7) [.node (.nat (code x0)) []]
    | .unitValue  => .node (.rank 8) []
    | .string x0 => .node (.rank 9) [.node (.nat (code x0)) []]
    | .listValue x0 => .node (.rank 10) [.node (.rank 0) (slotTrees x0)]
    | .bytesValue x0 => .node (.rank 11) [.node (.nat (code x0)) []]
    | .mapValue x0 x1 => .node (.rank 12) [.node (.rank 0) (slotTrees x0), .node (.rank 0) (slotTrees x1)]
    | .setValue x0 => .node (.rank 13) [.node (.rank 0) (slotTrees x0)]
    | .dataValue x0 x1 => .node (.rank 14) [.node (.nat (code x0)) [], .node (.rank 0) (slotTrees x1)]
    | .targetValue x0 x1 => .node (.rank 15) [.node (.nat (code x0)) [], .node (.nat (code x1)) []]
    | .field x0 x1 => .node (.rank 16) [.node (.nat (code x0)) [], termTree x1]
    | .measure x0 x1 => .node (.rank 17) [.node (.nat (code x0)) [], termTree x1]
    | .neg x0 => .node (.rank 18) [termTree x0]
    | .scale x0 x1 => .node (.rank 19) [.node (.nat (code x0)) [], termTree x1]
  def slotTree : Option Term → Tree Label
    | none => .node (.rank 0) []
    | some t => .node (.rank 1) [termTree t]
  def slotTrees : List (Option Term) → List (Tree Label)
    | [] => []
    | t :: ts => slotTree t :: slotTrees ts
end

mutual
  private theorem termTree_injective {a b : Term} (h : termTree a = termTree b) : a = b := by
    cases a <;> cases b <;> simp only [termTree, Tree.node.injEq, List.cons.injEq,
      Label.rank.injEq, Label.nat.injEq, Nat.reduceEqDiff, and_true, true_and, false_and] at h
    all_goals try contradiction
    case var.var =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case integer.integer =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case add.add =>
      obtain ⟨h0, h1⟩ := h
      have he0 := termTree_injective h0
      have he1 := termTree_injective h1
      cases he0; cases he1; rfl
    case character.character =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case float64.float64 =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case float32.float32 =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case decimal.decimal =>
      obtain ⟨h0, h1⟩ := h
      have he0 := code_injective h0
      have he1 := code_injective h1
      cases he0; cases he1; rfl
    case boolean.boolean =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case unitValue.unitValue =>
      rfl
    case string.string =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case listValue.listValue =>
      have h0 := h
      have he0 := slotTrees_injective h0
      cases he0; rfl
    case bytesValue.bytesValue =>
      have h0 := h
      have he0 := code_injective h0
      cases he0; rfl
    case mapValue.mapValue =>
      obtain ⟨h0, h1⟩ := h
      have he0 := slotTrees_injective h0
      have he1 := slotTrees_injective h1
      cases he0; cases he1; rfl
    case setValue.setValue =>
      have h0 := h
      have he0 := slotTrees_injective h0
      cases he0; rfl
    case dataValue.dataValue =>
      obtain ⟨h0, h1⟩ := h
      have he0 := code_injective h0
      have he1 := slotTrees_injective h1
      cases he0; cases he1; rfl
    case targetValue.targetValue =>
      obtain ⟨h0, h1⟩ := h
      have he0 := code_injective h0
      have he1 := code_injective h1
      cases he0; cases he1; rfl
    case field.field =>
      obtain ⟨h0, h1⟩ := h
      have he0 := code_injective h0
      have he1 := termTree_injective h1
      cases he0; cases he1; rfl
    case measure.measure =>
      obtain ⟨h0, h1⟩ := h
      have he0 := code_injective h0
      have he1 := termTree_injective h1
      cases he0; cases he1; rfl
    case neg.neg =>
      have h0 := h
      have he0 := termTree_injective h0
      cases he0; rfl
    case scale.scale =>
      obtain ⟨h0, h1⟩ := h
      have he0 := code_injective h0
      have he1 := termTree_injective h1
      cases he0; cases he1; rfl
  private theorem slotTree_injective {a b : Option Term} (h : slotTree a = slotTree b) : a = b := by
    cases a <;> cases b <;> simp only [slotTree, Tree.node.injEq, List.cons.injEq,
      Label.rank.injEq, Nat.reduceEqDiff, and_true, true_and, false_and] at h
    all_goals first | contradiction | rfl | exact congrArg some (termTree_injective h)
  private theorem slotTrees_injective {as bs : List (Option Term)}
      (h : slotTrees as = slotTrees bs) : as = bs := by
    cases as with
    | nil => cases bs <;> simp_all [slotTrees]
    | cons a as =>
      cases bs with
      | nil => simp [slotTrees] at h
      | cons b bs =>
        have h := List.cons.inj h
        have ha := slotTree_injective h.1
        have hb := slotTrees_injective h.2
        cases ha; cases hb; rfl
end

def predTree : Pred → Tree Label
  | .truth  => .node (.rank 0) []
  | .falsity  => .node (.rank 1) []
  | .eq x0 x1 => .node (.rank 2) [termTree x0, termTree x1]
  | .le x0 x1 => .node (.rank 3) [termTree x0, termTree x1]
  | .lt x0 x1 => .node (.rank 4) [termTree x0, termTree x1]
  | .and x0 x1 => .node (.rank 5) [predTree x0, predTree x1]
  | .or x0 x1 => .node (.rank 6) [predTree x0, predTree x1]
  | .not x0 => .node (.rank 7) [predTree x0]
  | .compare x0 x1 x2 x3 => .node (.rank 8) [.node (.nat (code x0)) [], .node (.nat (code x1)) [], termTree x2, termTree x3]
  | .floatClass x0 x1 x2 => .node (.rank 9) [.node (.nat (code x0)) [], .node (.nat (code x1)) [], termTree x2]
  | .decimalRepresented x0 => .node (.rank 10) [termTree x0]
  | .charactersIn x0 x1 x2 => .node (.rank 11) [termTree x0, .node (.nat (code x1)) [], .node (.nat (code x2)) []]
  | .member x0 x1 x2 => .node (.rank 12) [.node (.nat (code x0)) [], termTree x1, .node (.nat (code x2)) []]
  | .constructorIs x0 x1 => .node (.rank 13) [termTree x0, .node (.nat (code x1)) []]

private theorem predTree_injective {a b : Pred} (h : predTree a = predTree b) : a = b := by
  cases a <;> cases b <;> simp only [predTree, Tree.node.injEq, List.cons.injEq,
    Label.rank.injEq, Label.nat.injEq, Nat.reduceEqDiff, and_true, true_and, false_and] at h
  all_goals try contradiction
  case truth.truth =>
    rfl
  case falsity.falsity =>
    rfl
  case eq.eq =>
    obtain ⟨h0, h1⟩ := h
    have he0 := termTree_injective h0
    have he1 := termTree_injective h1
    cases he0; cases he1; rfl
  case le.le =>
    obtain ⟨h0, h1⟩ := h
    have he0 := termTree_injective h0
    have he1 := termTree_injective h1
    cases he0; cases he1; rfl
  case lt.lt =>
    obtain ⟨h0, h1⟩ := h
    have he0 := termTree_injective h0
    have he1 := termTree_injective h1
    cases he0; cases he1; rfl
  case and.and =>
    obtain ⟨h0, h1⟩ := h
    have he0 := predTree_injective h0
    have he1 := predTree_injective h1
    cases he0; cases he1; rfl
  case or.or =>
    obtain ⟨h0, h1⟩ := h
    have he0 := predTree_injective h0
    have he1 := predTree_injective h1
    cases he0; cases he1; rfl
  case not.not =>
    have h0 := h
    have he0 := predTree_injective h0
    cases he0; rfl
  case compare.compare =>
    obtain ⟨h0, h1, h2, h3⟩ := h
    have he0 := code_injective h0
    have he1 := code_injective h1
    have he2 := termTree_injective h2
    have he3 := termTree_injective h3
    cases he0; cases he1; cases he2; cases he3; rfl
  case floatClass.floatClass =>
    obtain ⟨h0, h1, h2⟩ := h
    have he0 := code_injective h0
    have he1 := code_injective h1
    have he2 := termTree_injective h2
    cases he0; cases he1; cases he2; rfl
  case decimalRepresented.decimalRepresented =>
    have h0 := h
    have he0 := termTree_injective h0
    cases he0; rfl
  case charactersIn.charactersIn =>
    obtain ⟨h0, h1, h2⟩ := h
    have he0 := termTree_injective h0
    have he1 := code_injective h1
    have he2 := code_injective h2
    cases he0; cases he1; cases he2; rfl
  case member.member =>
    obtain ⟨h0, h1, h2⟩ := h
    have he0 := code_injective h0
    have he1 := termTree_injective h1
    have he2 := code_injective h2
    cases he0; cases he1; cases he2; rfl
  case constructorIs.constructorIs =>
    obtain ⟨h0, h1⟩ := h
    have he0 := termTree_injective h0
    have he1 := code_injective h1
    cases he0; cases he1; rfl

mutual
  /-- 欄の境界を子の木で区切り、名前・引数・結果・潜在効果をすべて保持する。 -/
  noncomputable def Ty.toTree : Ty → Tree Label
    | .base b => .node (.rank 0) [.node (.nat b.rank) []]
    | .opaque o r => .node (.rank 1) [.node (.text o) [], .node (.nat r.code) []]
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
    | .dependentFn t => .node (.rank 16) [Tel.toTree t]
    | .external id as => .node (.rank 17) [.node (.nat (code id)) [], .node (.rank 0) (Ty.toTrees as)]
    | .scoped o k ix => .node (.rank 18) [.node (.text o) [], .node (.nat (code k)) [], .node (.nat ix.code) []]
    | .pathBases => .node (.rank 19) []
    | .scopePattern k => .node (.rank 20) [.node (.nat (code k)) []]

  /-- 効果の欄と Fail 列の順序を保持する。 -/
  noncomputable def Eff.toTree : Eff → Tree Label
    | .mk a fs => .node (.atoms (encodeAtoms a)) (Ty.toTrees fs)

  noncomputable def Tel.toTree : Tel → Tree Label
    | .done r e => .node (.rank 0) [r.toTree, Eff.toTree e]
    | .param n a t => .node (.rank 1) [.node (.text n) [], a.toTree, Tel.toTree t]

  /-- 型列をそのままの順序で木の列へ写す。 -/
  noncomputable def Ty.toTrees : List Ty → List (Tree Label)
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
      rw [RangeIx.code_injective h]
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

    case dependentFn.dependentFn => exact congrArg Ty.dependentFn (Tel.toTree_injective h)
    case external.external =>
      obtain ⟨hi, has⟩ := h
      have hi := code_injective hi
      have has := Ty.toTrees_injective has
      cases hi; cases has; rfl
    case scoped.scoped =>
      obtain ⟨rfl, hk, hi⟩ := h
      have hk := code_injective hk
      have hi := RangeIx.code_injective hi
      cases hk; cases hi; rfl
    case scopePattern.scopePattern => exact congrArg Ty.scopePattern (code_injective h)

  private theorem Tel.toTree_injective {a b : Tel} (h : Tel.toTree a = Tel.toTree b) : a = b := by
    cases a <;> cases b <;> simp only [Tel.toTree, Tree.node.injEq, List.cons.injEq,
      Label.rank.injEq, Label.text.injEq, Nat.reduceEqDiff, and_true, true_and, false_and] at h
    all_goals try contradiction
    case done.done =>
      have hr := Ty.toTree_injective h.1
      have he := Eff.toTree_injective h.2
      cases hr; cases he; rfl
    case param.param =>
      obtain ⟨rfl, ha, ht⟩ := h
      have ha := Ty.toTree_injective ha
      have ht := Tel.toTree_injective ht
      cases ha; cases ht; rfl

  /-- 効果の写像も、生の Fail 列を区別する。 -/
  private theorem Eff.toTree_injective {e f : Eff} (h : e.toTree = f.toTree) : e = f := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs =>
        have h := Tree.node.inj h
        have ha := encodeAtoms_injective (Label.atoms.inj h.1)
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


private theorem node_compare (a b : Label) (as bs : List (Tree Label)) :
    treeCompare labelCompare (.node a as) (.node b bs) =
      (labelCompare a b).then (treesCompare labelCompare as bs) := rfl

mutual
  private theorem tree_embed_compare (a b : Benitoite.Release.Ty) :
      treeCompare labelCompare (embedTy a).toTree (embedTy b).toTree =
        treeCompare labelCompare a.toTree b.toTree := by
    cases a <;> cases b <;>
      simp [-embedTys_eq_map, embedTy, Ty.toTree, Benitoite.Release.Ty.toTree, node_compare, treesCompare,
        labelCompare, tree_embed_compare, trees_embed_compare, eff_tree_embed_compare,
        Nat.compare_eq_ite_lt]
  private theorem trees_embed_compare (as bs : List Benitoite.Release.Ty) :
      treesCompare labelCompare (Ty.toTrees (embedTys as)) (Ty.toTrees (embedTys bs)) =
        treesCompare labelCompare (Benitoite.Release.Ty.toTrees as) (Benitoite.Release.Ty.toTrees bs) := by
    cases as with
    | nil => cases bs <;> rfl
    | cons a as =>
      cases bs with
      | nil => rfl
      | cons b bs => simp only [embedTys, Ty.toTrees, Benitoite.Release.Ty.toTrees,
          treesCompare, tree_embed_compare, trees_embed_compare]
  private theorem eff_tree_embed_compare (e f : Benitoite.Release.Eff) :
      treeCompare labelCompare (Eff.toTree (embedEff e)) (Eff.toTree (embedEff f)) =
        treeCompare labelCompare (Benitoite.Release.Eff.toTree e) (Benitoite.Release.Eff.toTree f) := by
    cases e with
    | mk a fs =>
      cases f with
      | mk b gs => simp only [embedEff, Eff.toTree, Benitoite.Release.Eff.toTree,
          treeCompare, labelCompare, atomsCompare_embed, trees_embed_compare]
end

theorem tyCompare_embed (a b : Benitoite.Release.Ty) :
    tyCompare (embedTy a) (embedTy b) = Benitoite.Release.tyCompare a b := by
  rw [tyCompare, tree_embed_compare, Benitoite.Release.tyCompare_eq_treeCompare]

theorem embedTy_injective : Function.Injective embedTy := by
  intro a b h
  apply (Benitoite.Release.tyCompare_eq_iff a b).mp
  rw [← tyCompare_embed, h]
  exact (tyCompare_eq_iff _ _).mpr rfl

end Benitoite.Release.Refinement
