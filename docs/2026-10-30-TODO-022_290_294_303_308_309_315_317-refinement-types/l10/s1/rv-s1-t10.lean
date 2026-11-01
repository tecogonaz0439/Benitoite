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
namespace Benitoite.Release.Refinement
open Order

/-- 深さごとの注釈を外側へ戻す候補。再構築の検査までは依存の有無を断定しない。 -/
private def Tel.fnParts : Tel → List Ty × Ty × Eff
  | .done r e => ([], r, e)
  | .param _ a t =>
    let f := t.fnParts
    (a :: f.1.map (Ty.renameValues (unshiftValue 1 0)),
      f.2.1.renameValues (unshiftValue 1 0), Eff.renameValues (unshiftValue 1 0) f.2.2)

private theorem Tel.fnParts_support (p : Atom → Prop) (t : Tel) (h : t.Support p) :
    Ty.SupportList p t.fnParts.1 ∧ t.fnParts.2.1.Support p ∧ t.fnParts.2.2.Support p := by
  cases t with
  | done r e => exact ⟨trivial, h.1, h.2⟩
  | param n a t =>
    obtain ⟨hps, hr, he⟩ := Tel.fnParts_support p t h.2
    exact ⟨⟨h.1, by simpa only [←renameValueTys_eq_map] using
      (Ty.supportList_renameValues_iff p _ (unshiftValue 1 0)).mpr hps⟩,
      (Ty.support_renameValues_iff p _ _).mpr hr, (Eff.support_renameValues_iff p _ _).mpr he⟩

private theorem Tel.fnParts_toTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) : (Ty.toTel ns ps r e).fnParts = (ps, r, e) := by
  induction ns generalizing ps r e with
  | nil =>
    cases ps with
    | nil => rfl
    | cons => simp [NamesWF] at hn
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      change (a :: ((Ty.toTel ns (shiftVTys 1 0 ps) (r.shiftV 1 0) (Eff.shiftV 1 0 e)).fnParts.1.map
        (Ty.renameValues (unshiftValue 1 0))), _, _) = _
      rw [ih _ _ _ hn']
      simp only [Ty.unshift_shift, Eff.unshift_shift, shiftVTys_eq_map, List.map_map,
        Function.comp_def]
      exact congrArg (fun xs => (a :: xs, r, e)) (List.map_id ps)

private def viewSupport (s : List Atom) (t : Tel) (f : FnView) : List Atom :=
  s ++ t.collectAtoms s ++ f.toTel.collectAtoms s

private theorem viewSupport_input {s : List Atom} {t : Tel} {f : FnView} (ht : Tel.Support (· ∈ s) t) :
    t.Support (· ∈ viewSupport s t f) :=
  Tel.support_mono t ht (fun _ ha => List.mem_append_left _ (List.mem_append_left _ ha))

private theorem viewSupport_view {s : List Atom} {t : Tel} {f : FnView} (hf : Tel.Support (· ∈ s) f.toTel) :
    f.toTel.Support (· ∈ viewSupport s t f) :=
  Tel.support_mono f.toTel hf (fun _ ha => List.mem_append_left _ (List.mem_append_left _ ha))

instance (ns : List String) (ps : List Ty) : Decidable (NamesWF ns ps) := by
  unfold NamesWF; infer_instance

def Tel.fnViewWith? (s : List Atom) (t : Tel) : Option FnView :=
  let ps := t.fnParts
  if hn : NamesWF t.names ps.1 then
    let f : FnView := ⟨t.names, ps.1, ps.2.1, ps.2.2, hn⟩
    if telCompareWith (viewSupport s t f) f.toTel t = .eq then some f else none
  else none

def Ty.foldFnWith (s : List Atom) (t : Tel) : Ty :=
  match t.fnViewWith? s with
  | some f => .fn f.names f.params f.result f.effect
  | none => .dependentFn t

theorem telCompareWith_eq_iff (s : List Atom) (t u : Tel)
    (ht : t.Support (· ∈ s)) (hu : u.Support (· ∈ s)) :
    telCompareWith s t u = .eq ↔ t = u := by
  have h := compareWith_eq_compare s (.dependentFn t) (.dependentFn u) ht hu
  simp only [tyCompareWith] at h
  rw [h, tyCompare_eq_iff, Ty.dependentFn.injEq]

private theorem Tel.fnViewWith?_sound (s : List Atom) (t : Tel) (f : FnView)
    (ht : t.Support (· ∈ s)) (h : t.fnViewWith? s = some f) : f.toTel = t := by
  unfold Tel.fnViewWith? at h
  dsimp only at h
  split at h
  next hn =>
    let g : FnView := ⟨t.names, t.fnParts.1, t.fnParts.2.1, t.fnParts.2.2, hn⟩
    have hg : g.toTel.Support (· ∈ s) :=
      (Ty.support_toTel_iff _ _ _ _ _ hn).mpr (Tel.fnParts_support _ t ht)
    split at h
    next he =>
      have hgf : g = f := Option.some.inj h
      exact hgf ▸ (telCompareWith_eq_iff _ _ _ (viewSupport_view hg) (viewSupport_input ht)).mp he
    next => cases h
  next => cases h

private theorem Tel.fnViewWith?_toTel (s : List Atom) (f : FnView)
    (ht : f.toTel.Support (· ∈ s)) : f.toTel.fnViewWith? s = some f := by
  unfold Tel.fnViewWith?
  simp only [FnView.toTel, Tel.names_toTel f.names_wf, Tel.fnParts_toTel _ _ _ _ f.names_wf]
  rw [dite_eq_left f.names_wf]
  have he : (⟨f.names, f.params, f.result, f.effect, f.names_wf⟩ : FnView) = f := by cases f; rfl
  simp only [he]
  change (if telCompareWith (viewSupport s f.toTel f) f.toTel f.toTel = .eq then some f else none) = some f
  exact ite_eq_left ((telCompareWith_eq_iff _ _ _ (viewSupport_view ht) (viewSupport_input ht)).mpr rfl)

theorem Tel.fnViewWith?_eq_some_iff (s : List Atom) (t : Tel) (f : FnView)
    (ht : t.Support (· ∈ s)) : t.fnViewWith? s = some f ↔ f.toTel = t := by
  refine ⟨Tel.fnViewWith?_sound s t f ht, ?_⟩
  intro he
  subst t
  exact Tel.fnViewWith?_toTel s f ht

theorem Tel.fnViewWith?_eq_fnView? (s : List Atom) (t : Tel)
    (ht : t.Support (· ∈ s)) : t.fnViewWith? s = t.fnView? := by
  cases hw : t.fnViewWith? s with
  | some f => exact ((Tel.fnView?_eq_some_iff t f).mpr
      ((Tel.fnViewWith?_eq_some_iff s t f ht).mp hw)).symm
  | none =>
    cases hr : t.fnView? with
    | none => rfl
    | some f =>
      have h := (Tel.fnViewWith?_eq_some_iff s t f ht).mpr ((Tel.fnView?_eq_some_iff t f).mp hr)
      rw [hw] at h
      cases h

theorem Ty.foldFnWith_eq_foldFn (s : List Atom) (t : Tel)
    (ht : t.Support (· ∈ s)) : Ty.foldFnWith s t = Ty.foldFn t := by
  simp only [Ty.foldFnWith, Ty.foldFn, Tel.fnViewWith?_eq_fnView? s t ht]
  rfl

end Benitoite.Release.Refinement

namespace Benitoite.Release.Refinement
open Order

mutual
  /-- 型のすべての子と、埋め込まれた効果を正規化する。 -/
  def Ty.normWith (s : List Atom) : Ty → Ty
    | .base b => .base b
    | .opaque o r => .opaque o r
    | .data d as => .data d (Ty.normTysWith s as)
    | .list a => .list (Ty.normWith s a)
    | .fn ns ps r e => .fn ns (Ty.normTysWith s ps) (Ty.normWith s r) (Eff.normWith s e)
    | .tvar i => .tvar i
    | .reference a => .reference (Ty.normWith s a)
    | .lazy a => .lazy (Ty.normWith s a)
    | .cont b t e => .cont (Ty.normWith s b) (Ty.normWith s t) (Eff.normWith s e)
    | .map a b => .map (Ty.normWith s a) (Ty.normWith s b)
    | .set a => .set (Ty.normWith s a)
    | .bytes => .bytes
    | .dict cl a => .dict cl (Ty.normWith s a)
    | .tapp i as => .tapp i (Ty.normTysWith s as)
    | .ctor c => .ctor c
    | .refined a p => Ty.refineNorm (Ty.normWith s a) p
    | .dependentFn t => Ty.foldFnWith s (Tel.normWith s t)
    | .external id as => .external id (Ty.normTysWith s as)
    | .scoped o k ix => .scoped o k ix
    | .pathBases => .pathBases
    | .scopePattern k => .scopePattern k
  termination_by structural t => t

  def Tel.normWith (s : List Atom) : Tel → Tel
    | .done r e => .done (Ty.normWith s r) (Eff.normWith s e)
    | .param n a t => .param n (Ty.normWith s a) (Tel.normWith s t)
  termination_by structural t => t

  /-- 型列も同じ構造再帰に含める。 -/
  def Ty.normTysWith (s : List Atom) : List Ty → List Ty
    | [] => []
    | a :: as => (Ty.normWith s a) :: Ty.normTysWith s as
  termination_by structural as => as

  /-- 名前と行を保ち、子の正規化後に Fail 列を整列する。 -/
  def Eff.normWith (s : List Atom) : Eff → Eff
    | .mk a fs => .mk a (sortUnique (tyCompareWith s) (Ty.normTysWith s fs))
  termination_by structural e => e
end

private theorem insertUnique_congrOn {p : α → Prop} (c d : α → α → Ordering)
    (hc : ∀ a b, p a → p b → c a b = d a b) (a : α) (ha : p a)
    (bs : List α) (hb : ∀ b ∈ bs, p b) : insertUnique c a bs = insertUnique d a bs := by
  induction bs with
  | nil => rfl
  | cons b bs ih =>
    simp only [insertUnique, hc a b ha (hb b List.mem_cons_self)]
    cases d a b <;> simp_all

private theorem sortUnique_congrOn {p : α → Prop} (c d : α → α → Ordering)
    [Std.LawfulEqCmp d] [Std.TransCmp d]
    (hc : ∀ a b, p a → p b → c a b = d a b)
    (as : List α) (ha : ∀ a ∈ as, p a) : sortUnique c as = sortUnique d as := by
  induction as with
  | nil => rfl
  | cons a as ih =>
    simp only [sortUnique]
    rw [ih (fun b hb => ha b (List.mem_cons_of_mem a hb))]
    exact insertUnique_congrOn c d hc a (ha a List.mem_cons_self) _
      (fun b hb => ha b (List.mem_cons_of_mem a (mem_sortUnique.mp hb)))

mutual
  theorem Ty.normWith_eq_norm (s : List Atom) (t : Ty) (h : t.Support (· ∈ s)) :
      t.normWith s = t.norm := by
    cases t <;> simp only [Ty.Support] at h
    all_goals simp only [Ty.normWith, Ty.norm]
    all_goals first
      | rfl
      | exact congrArg _ (Ty.normWith_eq_norm s _ h)
      | exact congrArg _ (Ty.normTysWith_eq_norm s _ h)
      | skip
    case refined a q => rw [Ty.normWith_eq_norm s a h]
    case dependentFn t =>
      rw [Tel.normWith_eq_norm s t h, Ty.foldFnWith_eq_foldFn s _ (Tel.norm_support t h)]
    case fn ns ps r e => rw [Ty.normTysWith_eq_norm s ps h.1,
      Ty.normWith_eq_norm s r h.2.1, Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h.2.2).2]
    case cont a b e => rw [Ty.normWith_eq_norm s a h.1,
      Ty.normWith_eq_norm s b h.2.1, Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h.2.2).2]
    case map a b => rw [Ty.normWith_eq_norm s a h.1, Ty.normWith_eq_norm s b h.2]

  theorem Ty.normTysWith_eq_norm (s : List Atom) (ts : List Ty)
      (h : Ty.SupportList (· ∈ s) ts) : Ty.normTysWith s ts = Ty.normTys ts := by
    cases ts with
    | nil => rfl
    | cons t ts =>
      simp only [Ty.normTysWith, Ty.normTys]
      rw [Ty.normWith_eq_norm s t h.1, Ty.normTysWith_eq_norm s ts h.2]

  theorem Eff.normWith_eq_norm_of_fails (s : List Atom) (e : Eff)
      (h : Ty.SupportList (· ∈ s) e.fails) :
      Eff.normWith s e = Eff.norm e := by
    cases e with
    | mk a fs =>
      simp only [Eff.normWith, Eff.norm]
      rw [Ty.normTysWith_eq_norm s fs h]
      congr 1
      exact sortUnique_congrOn _ _ (compareWith_eq_compare s) _
        (Ty.SupportList.iff.mp (Ty.normTys_support fs h))
  theorem Tel.normWith_eq_norm (s : List Atom) (t : Tel) (h : t.Support (· ∈ s)) :
      Tel.normWith s t = Tel.norm t := by
    cases t with
    | done r e =>
      simp only [Tel.normWith, Tel.norm, Ty.normWith_eq_norm s r h.1,
        Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h.2).2]
    | param n a t =>
      simp only [Tel.normWith, Tel.norm, Ty.normWith_eq_norm s a h.1, Tel.normWith_eq_norm s t h.2]
end

/-- 最上位の原子関数は変更しないので、正規化の一致にはFail内部の支持だけで足りる。 -/
theorem Eff.normWith_eq_norm (s : List Atom) (e : Eff) (h : Eff.Support (· ∈ s) e) :
    Eff.normWith s e = Eff.norm e :=
  Eff.normWith_eq_norm_of_fails s e ((Eff.support_iff e).mp h).2


@[simp] theorem Ty.normTysWith_eq_map (s : List Atom) (ts : List Ty) :
    Ty.normTysWith s ts = ts.map (Ty.normWith s) := by
  induction ts with
  | nil => rfl
  | cons t ts ih => simp only [Ty.normTysWith, List.map_cons, ih]

theorem Ty.normWith_support (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) :
    (a.normWith s).Support (· ∈ s) := by
  rw [Ty.normWith_eq_norm s a h]
  exact Ty.norm_support a h

theorem Ty.normWith_canonical (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) :
    (a.normWith s).Canonical := by
  rw [Ty.normWith_eq_norm s a h]
  exact Ty.norm_idem a

theorem Ty.normWith_idem (s : List Atom) (a : Ty) (h : a.Support (· ∈ s)) :
    (a.normWith s).normWith s = a.normWith s := by
  rw [Ty.normWith_eq_norm s _ (Ty.normWith_support s a h), Ty.normWith_eq_norm s a h, Ty.norm_idem]

theorem Ty.normWith_support_independent (s t : List Atom) (a : Ty)
    (hs : a.Support (· ∈ s)) (ht : a.Support (· ∈ t)) : a.normWith s = a.normWith t :=
  (Ty.normWith_eq_norm s a hs).trans (Ty.normWith_eq_norm t a ht).symm

theorem Eff.normWith_support (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) :
    (a.normWith s).Support (· ∈ s) := by
  rw [Eff.normWith_eq_norm s a h]
  exact Eff.norm_support a h

theorem Eff.normWith_canonical (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) :
    (a.normWith s).Canonical := by
  rw [Eff.normWith_eq_norm s a h]
  exact Eff.norm_idem a

theorem Eff.normWith_idem (s : List Atom) (a : Eff) (h : a.Support (· ∈ s)) :
    (a.normWith s).normWith s = a.normWith s := by
  rw [Eff.normWith_eq_norm s _ (Eff.normWith_support s a h), Eff.normWith_eq_norm s a h, Eff.norm_idem]

theorem Eff.normWith_support_independent (s t : List Atom) (a : Eff)
    (hs : a.Support (· ∈ s)) (ht : a.Support (· ∈ t)) : a.normWith s = a.normWith t :=
  (Eff.normWith_eq_norm s a hs).trans (Eff.normWith_eq_norm t a ht).symm

end Benitoite.Release.Refinement

namespace Benitoite.Release.Refinement
def rowT : Eff := .mk (fun a => decide (a = .rho 1)) []
def w : Ty := .fn [] [] (.base .unit) rowT
def wo : Ty := .fn [] [] (.base .unit) Eff.empty
def fsT : Eff := .mk (fun _ => false) [w, wo, w]
example : (Eff.normWith [.rho 1] fsT).fails.length = 2 := by decide
example : (Eff.normWith [] fsT).fails.length = 1 := rfl
def nd : Tel := .param "x" (.base .unit) (.done (.base .unit) rowT)
def dp : Tel := .param "x" (.base .integer) (.done (.refined (.base .integer) (.eq (.var 0) (.var 1))) rowT)
example : (nd.fnViewWith? [.rho 1]).isSome = true := by decide
example : (dp.fnViewWith? [.rho 1]).isSome = false := by decide
end Benitoite.Release.Refinement
