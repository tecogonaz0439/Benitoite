import Benitoite.Release.Refinement.FiniteSupport
import Benitoite.Release.Order.FiniteAtoms

/-! 有限支持付きの生の構造比較。型全域の決定可能等号ではない。 -/
namespace Benitoite.Release.Refinement
open Order

private def labelTag : Label → Nat
  | .rank _ => 0 | .nat _ => 1 | .text _ => 2 | .texts _ => 3 | .atoms _ => 4

private def scalarLabelCompare : Label → Label → Ordering
  | .rank a, .rank b | .nat a, .nat b => compare a b
  | .text a, .text b => stringCompare a b
  | .texts a, .texts b => List.compareLex stringCompare a b
  | a, b => compare (labelTag a) (labelTag b)

private def scalarLabel : Label → Prop
  | .atoms _ => False | _ => True

mutual
  private def scalarTree : Tree Label → Prop
    | .node a as => scalarLabel a ∧ scalarTrees as
  private def scalarTrees : List (Tree Label) → Prop
    | [] => True
    | a :: as => scalarTree a ∧ scalarTrees as
end

private theorem scalar_label_compare {a b : Label} (ha : scalarLabel a) (hb : scalarLabel b) :
    scalarLabelCompare a b = labelCompare a b := by
  cases a <;> cases b <;> first | contradiction | rfl

mutual
  private theorem scalar_tree_compare (a b : Tree Label) (ha : scalarTree a) (hb : scalarTree b) :
      treeCompare scalarLabelCompare a b = treeCompare labelCompare a b := by
    cases a; cases b
    simp only [treeCompare, scalar_label_compare ha.1 hb.1, scalar_trees_compare _ _ ha.2 hb.2]
  private theorem scalar_trees_compare (as bs : List (Tree Label))
      (ha : scalarTrees as) (hb : scalarTrees bs) :
      treesCompare scalarLabelCompare as bs = treesCompare labelCompare as bs := by
    cases as <;> cases bs <;> first | rfl | skip
    simp only [treesCompare, scalar_tree_compare _ _ ha.1 hb.1, scalar_trees_compare _ _ ha.2 hb.2]
end

mutual
  private theorem termTree_scalar (t : Term) : scalarTree (termTree t) := by
    cases t <;> simp only [termTree, scalarTree, scalarTrees, scalarLabel,
      termTree_scalar, slotTrees_scalar, and_self]
  private theorem slotTree_scalar (t : Option Term) : scalarTree (slotTree t) := by
    cases t <;> simp only [slotTree, scalarTree, scalarTrees, scalarLabel, termTree_scalar, and_self]
  private theorem slotTrees_scalar (ts : List (Option Term)) : scalarTrees (slotTrees ts) := by
    cases ts <;> simp only [slotTrees, scalarTrees, slotTree_scalar, slotTrees_scalar, and_self]
end

private theorem predTree_scalar (p : Pred) : scalarTree (predTree p) := by
  cases p <;> simp only [predTree, scalarTree, scalarTrees, scalarLabel,
    termTree_scalar, predTree_scalar, and_self]

private def predCompare (a b : Pred) : Ordering :=
  treeCompare scalarLabelCompare (predTree a) (predTree b)

private theorem predCompare_eq (a b : Pred) :
    predCompare a b = treeCompare labelCompare (predTree a) (predTree b) :=
  scalar_tree_compare _ _ (predTree_scalar a) (predTree_scalar b)

private def conCompare (a b : TyCon) : Ordering :=
  treeCompare scalarLabelCompare a.toTree b.toTree

private theorem conCompare_eq (a b : TyCon) :
    conCompare a b = treeCompare labelCompare a.toTree b.toTree := by
  apply scalar_tree_compare
  · cases a <;> simp [TyCon.toTree, scalarTree, scalarTrees, scalarLabel]
  · cases b <;> simp [TyCon.toTree, scalarTree, scalarTrees, scalarLabel]

private def typeRank : Ty → Nat
  | .base _ => 0
  | .opaque _ _ => 1
  | .data _ _ => 2
  | .list _ => 3
  | .fn _ _ _ _ => 4
  | .tvar _ => 5
  | .reference _ => 6
  | .lazy _ => 7
  | .cont _ _ _ => 8
  | .map _ _ => 9
  | .set _ => 10
  | .bytes => 11
  | .dict _ _ => 12
  | .tapp _ _ => 13
  | .ctor _ => 14
  | .refined _ _ => 15
  | .dependentFn _ => 16
  | .external _ _ => 17
  | .scoped _ _ _ => 18
  | .pathBases => 19
  | .scopePattern _ => 20

/-- 実行側は候補上の所属だけを調べ、旧rhoの符号順を保つ。 -/
def finiteEncodeAtoms (s : List Atom) (f : Atom → Bool) : Benitoite.Release.Atom → Bool := fun old =>
  s.any (fun a => decide (old = Benitoite.Release.Atom.rho a.code) && f a)

private def finiteAtomsCompare (s : List Atom) (f g : Atom → Bool) : Ordering :=
  Benitoite.Release.atomsCompareWith (s.map (fun a => .rho a.code))
    (finiteEncodeAtoms s f) (finiteEncodeAtoms s g)

mutual
  /-- 型の組へ再帰し、効果原子は有限候補上の所属だけで比較する。 -/
  def tyCompareWith (s : List Atom) : Ty → Ty → Ordering
    | .base a, .base b => compare a.rank b.rank
    | .opaque a r, .opaque b r2 => (stringCompare a b).then (compare r.code r2.code)
    | .data d as, .data e bs => (stringCompare d e).then (tysCompareWith s as bs)
    | .list a, .list b => tyCompareWith s a b
    | .fn ns as a e, .fn ms bs b f =>
        (List.compareLex stringCompare ns ms).then
          ((tysCompareWith s as bs).then ((tyCompareWith s a b).then (effCompareWith s e f)))
    | .tvar i, .tvar j => compare i j
    | .reference a, .reference b => tyCompareWith s a b
    | .lazy a, .lazy b => tyCompareWith s a b
    | .cont a b e, .cont c d f =>
        (tyCompareWith s a c).then ((tyCompareWith s b d).then (effCompareWith s e f))
    | .map a b, .map c d => (tyCompareWith s a c).then (tyCompareWith s b d)
    | .set a, .set b => tyCompareWith s a b
    | .bytes, .bytes => .eq
    | .dict cl a, .dict dl b => (stringCompare cl dl).then (tyCompareWith s a b)
    | .tapp i as, .tapp j bs => (compare i j).then (tysCompareWith s as bs)
    | .ctor a, .ctor b => conCompare a b
    | .refined a p, .refined b q => (tyCompareWith s a b).then (predCompare p q)
    | .dependentFn a, .dependentFn b => telCompareWith s a b
    | .external i as, .external j bs => (compare (code i) (code j)).then (tysCompareWith s as bs)
    | .scoped o k ix, .scoped p l jx =>
        (stringCompare o p).then ((compare (code k) (code l)).then (compare ix.code jx.code))
    | .pathBases, .pathBases => .eq
    | .scopePattern k, .scopePattern l => compare (code k) (code l)
    | a, b => compare (typeRank a) (typeRank b)

  termination_by structural a _ => a

  /-- 効果は名前・行の関数、Fail 列の順で比較する。 -/
  def effCompareWith (s : List Atom) : Eff → Eff → Ordering
    | .mk a fs, .mk b gs => (finiteAtomsCompare s a b).then (tysCompareWith s fs gs)

  termination_by structural a _ => a

  /-- 型列の辞書式比較。空列では型の比較を呼ばない。 -/
  def tysCompareWith (s : List Atom) : List Ty → List Ty → Ordering
    | [], [] => .eq
    | [], _ :: _ => .lt
    | _ :: _, [] => .gt
    | a :: as, b :: bs => (tyCompareWith s a b).then (tysCompareWith s as bs)
  termination_by structural a _ => a

  def telCompareWith (s : List Atom) : Tel → Tel → Ordering
    | .done r e, .done t f => (tyCompareWith s r t).then (effCompareWith s e f)
    | .param n a t, .param m b u =>
        (stringCompare n m).then ((tyCompareWith s a b).then (telCompareWith s t u))
    | .done _ _, .param _ _ _ => .lt
    | .param _ _ _, .done _ _ => .gt
  termination_by structural a _ => a
end

theorem finiteEncodeAtoms_eq (s : List Atom) (f : Atom → Bool)
    (hf : ∀ a, f a = true → a ∈ s) : finiteEncodeAtoms s f = encodeAtoms f := by
  funext old
  cases old with
  | name l ix => simp [finiteEncodeAtoms, encodeAtoms]
  | rho n =>
    by_cases h : ∃ a : Atom, a.code = n
    · obtain ⟨a, rfl⟩ := h
      rw [encodeAtoms_at]
      cases hfa : f a with
      | true => simp [finiteEncodeAtoms]; exact ⟨a, hf a hfa, rfl, hfa⟩
      | false =>
        simp [finiteEncodeAtoms]
        intro b _ hc
        have := Atom.code_injective hc
        subst this; simpa using hfa
    · have : encodeAtoms f (.rho n) = false := by
        classical
        simp only [encodeAtoms, h, dite_eq_right, not_false_eq_true]
      rw [this]
      simp only [finiteEncodeAtoms, List.any_eq_false]
      intro a _ 
      simp
      intro hn
      exact absurd ⟨a, hn.symm⟩ h

private theorem finiteEncodeAtoms_support (s : List Atom) (f : Atom → Bool) :
    ∀ a, finiteEncodeAtoms s f a = true → a ∈ s.map (fun a => Benitoite.Release.Atom.rho a.code) := by
  intro old h
  simp only [finiteEncodeAtoms, List.any_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨a, ha, he, _⟩ := h
  exact List.mem_map.mpr ⟨a, ha, he.symm⟩

private theorem finiteAtomsCompare_eq (s : List Atom) (f g : Atom → Bool)
    (hf : ∀ a, f a = true → a ∈ s) (hg : ∀ a, g a = true → a ∈ s) :
    finiteAtomsCompare s f g = Benitoite.Release.atomsCompare (encodeAtoms f) (encodeAtoms g) := by
  unfold finiteAtomsCompare
  rw [Benitoite.Release.atomsCompareWith_eq_compare (finiteEncodeAtoms_support s f) (finiteEncodeAtoms_support s g),
    finiteEncodeAtoms_eq s f hf, finiteEncodeAtoms_eq s g hg]

set_option maxRecDepth 4096 in
mutual
  theorem compareWith_eq_compare (s : List Atom) (a b : Ty)
      (ha : a.Support (· ∈ s)) (hb : b.Support (· ∈ s)) :
      tyCompareWith s a b = tyCompare a b := by
    cases a <;> cases b <;>
      simp_all only [tyCompareWith, tyCompare, Ty.toTree,
        treeCompare, treesCompare, labelCompare, typeRank, Ty.Support,
        compareWith_eq_compare, tysCompareWith_eq_compare, effCompareWith_eq_compare,
        telCompareWith_eq_compare, predCompare_eq, conCompare_eq]
    all_goals first | rfl | (simp only [Std.ReflCmp.compare_self, Ordering.eq_then, Ordering.then_eq] <;> rfl)
  termination_by structural a

  theorem tysCompareWith_eq_compare (s : List Atom) (as bs : List Ty)
      (ha : Ty.SupportList (· ∈ s) as) (hb : Ty.SupportList (· ∈ s) bs) :
      tysCompareWith s as bs = treesCompare labelCompare (Ty.toTrees as) (Ty.toTrees bs) := by
    cases as <;> cases bs <;>
      simp_all only [tysCompareWith, Ty.toTrees, treesCompare, Ty.SupportList,
        compareWith_eq_compare, tysCompareWith_eq_compare, tyCompare]

  termination_by structural as

  theorem effCompareWith_eq_compare (s : List Atom) (e f : Eff)
      (he : e.Support (· ∈ s)) (hf : f.Support (· ∈ s)) :
      effCompareWith s e f = treeCompare labelCompare (Eff.toTree e) (Eff.toTree f) := by
    cases e; cases f
    simp only [effCompareWith, Eff.toTree, treeCompare, labelCompare,
      finiteAtomsCompare_eq s _ _ he.1 hf.1, tysCompareWith_eq_compare s _ _ he.2 hf.2]
  termination_by structural e

  theorem telCompareWith_eq_compare (s : List Atom) (t u : Tel)
      (ht : t.Support (· ∈ s)) (hu : u.Support (· ∈ s)) :
      telCompareWith s t u = treeCompare labelCompare (Tel.toTree t) (Tel.toTree u) := by
    cases t <;> cases u <;>
      simp_all only [telCompareWith, Tel.toTree, treeCompare, treesCompare, labelCompare, Tel.Support,
        compareWith_eq_compare, effCompareWith_eq_compare, telCompareWith_eq_compare, tyCompare]
    all_goals first | rfl | (simp only [Std.ReflCmp.compare_self, Ordering.eq_then, Ordering.then_eq] <;> rfl)
  termination_by structural t
end

end Benitoite.Release.Refinement
