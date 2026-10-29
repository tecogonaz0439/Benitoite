import Std

#eval Lean.versionString

/-!
SK: disposable first-order IO/handler model. No production imports.
Scope/Atom/Eff/Structural/Denote are copied from SA.lean handling 1.
Scope originated in TODO-142 Scope.lean; ordering originated in
san_benito:formal/Benitoite/Release/Order/SortUnique.lean.
Only parsed normalized component lists are modeled. Host labels are reversed.
File events use port 0 and a dummy universal interval. No OS or DNS resolution.

Copied definitions and origins:
* SA.lean: Word through scopeLe_trans (originally spike 142/Scope.lean).
* SA.lean: ClosedScope; Atom/name/bounded/rho and atomLe/refl/trans
  (extension of Release/Atom.lean).
* SA.lean: Eff/mem/ext (reduced Release/Types.lean), Structural.norm,
  Canonical, ExactSub, Sub, singleton/union and membership lemmas
  (handling 1; Release/Normalize.lean and Effect.lean as their base).
* SA.lean: DenoteAtom/Denote/atomLe_sound/sub_sound/denote_singleton/union.
* Release/Order/SortUnique.lean: every declaration under namespace Order,
  copied through SA.lean without changing its proofs.
-/
namespace SK

abbrev Word := List String

inductive Pattern where
  | exact (word : Word)
  | tree (stem : Word) (extra : Nat)
  deriving DecidableEq, Repr

def Matches : Pattern → Word → Prop
  | .exact a, w => a = w
  | .tree a k, w => a.IsPrefix w ∧ a.length + k ≤ w.length

instance (p : Pattern) (w : Word) : Decidable (Matches p w) := by
  cases p <;> unfold Matches <;> infer_instance

def patLe : Pattern → Pattern → Bool
  | .exact a, b => decide (Matches b a)
  | .tree _ _, .exact _ => false
  | .tree a k, .tree b l => decide (b.IsPrefix a ∧ b.length + l ≤ a.length + k)

theorem patLe_sound {a b : Pattern} (h : patLe a b = true) :
    ∀ w, Matches a w → Matches b w := by
  cases a with
  | exact a =>
    have h : Matches b a := of_decide_eq_true h
    intro w hw
    cases hw
    exact h
  | tree a k =>
    cases b with
    | exact b => simp [patLe] at h
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length + k := of_decide_eq_true h
      intro w hw
      exact ⟨h.1.trans hw.1, Nat.le_trans h.2 hw.2⟩

theorem patLe_refl (p : Pattern) : patLe p p = true := by
  cases p <;> simp [patLe, Matches]

theorem patLe_trans {a b c : Pattern} (h : patLe a b = true)
    (g : patLe b c = true) : patLe a c = true := by
  cases a with
  | exact a => exact decide_eq_true (patLe_sound g a (of_decide_eq_true h))
  | tree a k =>
    cases b with
    | exact b => simp [patLe] at h
    | tree b l =>
      cases c with
      | exact c => simp [patLe] at g
      | tree c m =>
        have h : b.IsPrefix a ∧ b.length + l ≤ a.length + k := of_decide_eq_true h
        have g : c.IsPrefix b ∧ c.length + m ≤ b.length + l := of_decide_eq_true g
        exact decide_eq_true ⟨g.1.trans h.1, Nat.le_trans g.2 h.2⟩

-- Two extensions with different next components share no longer prefix.
theorem common_stem (a b xs ys : Word) (x y : String) (hne : x ≠ y)
    (hx : b.IsPrefix (a ++ x :: xs)) (hy : b.IsPrefix (a ++ y :: ys)) :
    b.IsPrefix a := by
  induction a generalizing b with
  | nil =>
    cases b with
    | nil => exact List.prefix_refl _
    | cons z zs =>
      have hx : z = x ∧ zs.IsPrefix xs := by simpa using hx
      have hy : z = y ∧ zs.IsPrefix ys := by simpa using hy
      exact False.elim (hne (hx.1.symm.trans hy.1))
  | cons c cs ih =>
    cases b with
    | nil => exact List.nil_prefix
    | cons z zs =>
      have hx : z = c ∧ zs.IsPrefix (cs ++ x :: xs) := by simpa using hx
      have hy : z = c ∧ zs.IsPrefix (cs ++ y :: ys) := by simpa using hy
      exact List.cons_prefix_cons.mpr ⟨hx.1, ih zs hx.2 hy.2⟩

theorem tree_witness (a : Word) (k : Nat) (x : String) :
    Matches (.tree a k) (a ++ List.replicate k x) := by
  exact ⟨List.prefix_append _ _, by simp⟩

theorem patLe_complete {a b : Pattern}
    (h : ∀ w, Matches a w → Matches b w) : patLe a b = true := by
  cases a with
  | exact a => exact decide_eq_true (h a rfl)
  | tree a k =>
    have hx := h _ (tree_witness a k "x")
    cases b with
    | exact b =>
      have hy := h _ (tree_witness a (k + 1) "x" |> fun hw =>
        (show Matches (.tree a k) (a ++ List.replicate (k + 1) "x") from
          ⟨hw.1, by simp⟩))
      have heq : a ++ List.replicate k "x" = a ++ List.replicate (k + 1) "x" := hx.symm.trans hy
      have heq := congrArg List.length heq
      simp only [List.length_append, List.length_replicate] at heq
      omega
    | tree b l =>
      have hb : b.IsPrefix a := by
        cases k with
        | zero => simpa only [List.replicate_zero, List.append_nil] using hx.1
        | succ k =>
          have hy := h _ (tree_witness a (k + 1) "y")
          exact common_stem a b _ _ "x" "y" (by decide) hx.1 hy.1
      exact decide_eq_true ⟨hb, by simpa using hx.2⟩

theorem patLe_iff (a b : Pattern) :
    patLe a b = true ↔ ∀ w, Matches a w → Matches b w :=
  ⟨patLe_sound, patLe_complete⟩

-- A computational Decidable instance for semantic (infinite-word) inclusion.
instance (a b : Pattern) : Decidable (∀ w, Matches a w → Matches b w) :=
  decidable_of_iff (patLe a b = true) (patLe_iff a b)

structure Interval where
  lo : Nat
  hi : Nat
  deriving DecidableEq, Repr

def InPort (r : Interval) (p : Nat) : Prop := r.lo ≤ p ∧ p ≤ r.hi

-- Empty intervals are permitted and included in every interval.
def portLe (a b : Interval) : Bool :=
  decide (a.hi < a.lo ∨ (b.lo ≤ a.lo ∧ a.hi ≤ b.hi))

theorem portLe_iff (a b : Interval) :
    portLe a b = true ↔ ∀ p, InPort a p → InPort b p := by
  simp only [portLe, decide_eq_true_eq]
  constructor
  · rintro (he | ⟨hl, hh⟩) p ⟨hp, hq⟩
    · omega
    · exact ⟨Nat.le_trans hl hp, Nat.le_trans hq hh⟩
  · intro h
    by_cases he : a.hi < a.lo
    · exact Or.inl he
    · right
      have hl := h a.lo ⟨Nat.le_refl _, by omega⟩
      have hh := h a.hi ⟨by omega, Nat.le_refl _⟩
      exact ⟨hl.1, hh.2⟩

theorem portLe_refl (p : Interval) : portLe p p = true :=
  (portLe_iff p p).mpr (fun _ h => h)

theorem portLe_trans {a b c : Interval} (h : portLe a b = true)
    (g : portLe b c = true) : portLe a c = true :=
  (portLe_iff a c).mpr (fun p hp => (portLe_iff b c).mp g p ((portLe_iff a b).mp h p hp))

inductive Kind where
  | https | tcp | write
  deriving DecidableEq, Repr

-- File events ignore the dummy port by using the universal interval in examples.
structure Scope where
  kind : Kind
  pattern : Pattern
  ports : Interval
  deriving DecidableEq, Repr

structure Event where
  kind : Kind
  target : Word
  port : Nat
  deriving DecidableEq, Repr

def Allows (s : Scope) (ev : Event) : Prop :=
  s.kind = ev.kind ∧ Matches s.pattern ev.target ∧ InPort s.ports ev.port

instance (s : Scope) (ev : Event) : Decidable (Allows s ev) := by
  unfold Allows InPort
  infer_instance

def scopeLe (a b : Scope) : Bool :=
  decide (a.kind = b.kind) && patLe a.pattern b.pattern && portLe a.ports b.ports

theorem scopeLe_sound {a b : Scope} (h : scopeLe a b = true) :
    ∀ ev, Allows a ev → Allows b ev := by
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h
  intro ev ⟨hk, hp, hr⟩
  exact ⟨h.1.1.symm.trans hk, patLe_sound h.1.2 _ hp, (portLe_iff _ _).mp h.2 _ hr⟩

theorem scopeLe_refl (a : Scope) : scopeLe a a = true := by
  simp [scopeLe, patLe_refl, portLe_refl]

theorem scopeLe_trans {a b c : Scope} (h : scopeLe a b = true)
    (g : scopeLe b c = true) : scopeLe a c = true := by
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h g ⊢
  exact ⟨⟨h.1.1.trans g.1.1, patLe_trans h.1.2 g.1.2⟩, portLe_trans h.2 g.2⟩

structure ClosedScope where
  scope : Scope
  nonempty : scope.ports.lo ≤ scope.ports.hi
  bounded : scope.ports.hi ≤ 65535

instance : DecidableEq ClosedScope := fun a b =>
  decidable_of_iff (a.scope = b.scope) ⟨fun h => by cases a; cases b; cases h; rfl,
    fun h => congrArg ClosedScope.scope h⟩


inductive Atom where
  | name (kind : Kind)
  | bounded (s : ClosedScope)
  | rho (i : Nat)
  deriving DecidableEq

def atomLe : Atom → Atom → Bool
  | .name a, .name b => decide (a = b)
  | .bounded a, .name b => decide (a.scope.kind = b)
  | .bounded a, .bounded b => scopeLe a.scope b.scope
  | .rho i, .rho j => decide (i = j)
  | _, _ => false

theorem atomLe_refl (a : Atom) : atomLe a a = true := by
  cases a <;> simp [atomLe, scopeLe_refl]

theorem atomLe_trans {a b c : Atom} (h : atomLe a b = true)
    (g : atomLe b c = true) : atomLe a c = true := by
  cases a <;> cases b <;> cases c <;> simp_all [atomLe]
  · simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h
    exact h.1.1.trans g
  · exact scopeLe_trans h g


inductive Eff where
  | mk (atoms : Atom → Bool) (fails : List Nat)

def Eff.atoms : Eff → Atom → Bool | .mk a _ => a
def Eff.fails : Eff → List Nat | .mk _ fs => fs
abbrev Eff.mem (e : Eff) (a : Atom) := e.atoms a = true
abbrev Eff.memFail (e : Eff) (t : Nat) := t ∈ e.fails

theorem Eff.ext {e f : Eff} (ha : ∀ a, e.mem a ↔ f.mem a) (hf : e.fails = f.fails) :
    e = f := by
  cases e with | mk a fs =>
    cases f with | mk b gs =>
      have hab : a = b := funext (fun x => Bool.eq_iff_iff.mpr (ha x))
      cases hab; cases hf; rfl


end SK

namespace SK.Order

open Std

/-- 整列済みの列へ一要素を挿入し、比較が等しい要素をまとめる。 -/
def insertUnique (cmp : α → α → Ordering) (a : α) : List α → List α
  | [] => [a]
  | b :: bs => match cmp a b with
    | .lt => a :: b :: bs
    | .eq => b :: bs
    | .gt => b :: insertUnique cmp a bs

/-- 構造再帰による挿入ソート。比較の結果が eq の要素は一つだけ残す。 -/
def sortUnique (cmp : α → α → Ordering) : List α → List α
  | [] => []
  | a :: as => insertUnique cmp a (sortUnique cmp as)

/-- 空列では比較を評価しない。 -/
@[simp] theorem sortUnique_nil (cmp : α → α → Ordering) : sortUnique cmp [] = [] := rfl

/-- 単一要素の列でも、比較の計算可能性によらずカーネルで簡約できる。 -/
@[simp] theorem sortUnique_singleton (cmp : α → α → Ordering) (a : α) :
    sortUnique cmp [a] = [a] := rfl

/-- 比較を保つ写像は、一要素の挿入と可換である。 -/
theorem insertUnique_map {α : Type u} {β : Type v}
    (cmp : α → α → Ordering) (cmp' : β → β → Ordering) (f : α → β)
    (hf : ∀ a b, cmp' (f a) (f b) = cmp a b) (a : α) (as : List α) :
    insertUnique cmp' (f a) (as.map f) = (insertUnique cmp a as).map f := by
  induction as with
  | nil => rfl
  | cons b bs ih =>
    simp only [List.map_cons, insertUnique, hf]
    cases cmp a b <;> simp_all

/-- 比較を保つ写像は、整列・重複除去と可換である。 -/
theorem sortUnique_map {α : Type u} {β : Type v}
    (cmp : α → α → Ordering) (cmp' : β → β → Ordering) (f : α → β)
    (hf : ∀ a b, cmp' (f a) (f b) = cmp a b) (as : List α) :
    sortUnique cmp' (as.map f) = (sortUnique cmp as).map f := by
  induction as with
  | nil => rfl
  | cons a as ih =>
    simp only [List.map_cons, sortUnique, ih, insertUnique_map cmp cmp' f hf]

variable {α : Type u} {cmp : α → α → Ordering} [LawfulEqCmp cmp] [TransCmp cmp]

omit [TransCmp cmp] in
/-- 挿入は、既存の要素と挿入する要素をちょうど保つ。 -/
theorem mem_insertUnique {x a : α} {as : List α} :
    x ∈ insertUnique cmp a as ↔ x = a ∨ x ∈ as := by
  induction as with
  | nil => simp [insertUnique]
  | cons b bs ih =>
    cases h : cmp a b with
    | lt => simp [insertUnique, h]
    | eq =>
      have := LawfulEqCmp.eq_of_compare h
      subst b
      simp [insertUnique, h]
    | gt => simp [insertUnique, h, ih, or_left_comm]

omit [TransCmp cmp] in
/-- 整列と重複除去は所属を変えない。 -/
theorem mem_sortUnique {x : α} {as : List α} : x ∈ sortUnique cmp as ↔ x ∈ as := by
  induction as with
  | nil => rfl
  | cons a as ih => simp [sortUnique, mem_insertUnique, ih]

private theorem pairwise_insertUnique {a : α} {as : List α}
    (h : as.Pairwise (fun x y => cmp x y = .lt)) :
    (insertUnique cmp a as).Pairwise (fun x y => cmp x y = .lt) := by
  induction as with
  | nil => simp [insertUnique]
  | cons b bs ih =>
    obtain ⟨hb, hbs⟩ := List.pairwise_cons.mp h
    cases hab : cmp a b with
    | lt =>
      simp only [insertUnique, hab]
      apply List.pairwise_cons.mpr
      refine ⟨?_, h⟩
      intro x hx
      rcases List.mem_cons.mp hx with rfl | hx
      · exact hab
      · exact TransCmp.lt_trans hab (hb x hx)
    | eq => simpa [insertUnique, hab] using h
    | gt =>
      simp only [insertUnique, hab]
      apply List.pairwise_cons.mpr
      refine ⟨?_, ih hbs⟩
      intro x hx
      rcases mem_insertUnique.mp hx with rfl | hx
      · exact OrientedCmp.lt_of_gt hab
      · exact hb x hx

/-- 出力は狭義昇順であり、重複を持たない。 -/
theorem pairwise_sortUnique (as : List α) :
    (sortUnique cmp as).Pairwise (fun x y => cmp x y = .lt) := by
  induction as with
  | nil => exact .nil
  | cons a as ih => exact pairwise_insertUnique ih

/-- 狭義昇順の二列は、所属する要素が同じなら列として等しい。 -/
theorem eq_of_pairwise_mem {as bs : List α}
    (ha : as.Pairwise (fun x y => cmp x y = .lt))
    (hb : bs.Pairwise (fun x y => cmp x y = .lt))
    (hm : ∀ x, x ∈ as ↔ x ∈ bs) : as = bs := by
  classical
  induction as generalizing bs with
  | nil =>
    cases bs with
    | nil => rfl
    | cons b bs => have := (hm b).mpr (by simp); simp at this
  | cons a as ih =>
    cases bs with
    | nil => have := (hm a).mp (by simp); simp at this
    | cons b bs =>
      have hab : a = b := by
        by_cases hne : a = b
        · exact hne
        apply False.elim
        have ham : a ∈ bs := (List.mem_cons.mp ((hm a).mp (by simp))).resolve_left hne
        have hbm : b ∈ as := (List.mem_cons.mp ((hm b).mpr (by simp))).resolve_left (Ne.symm hne)
        exact OrientedCmp.not_lt_of_lt (List.rel_of_pairwise_cons ha hbm)
          (List.rel_of_pairwise_cons hb ham)
      subst b
      congr 1
      apply ih (List.pairwise_cons.mp ha).2 (List.pairwise_cons.mp hb).2
      intro x
      by_cases hx : x = a
      · subst x
        have hna : a ∉ as := fun h => by
          have := List.rel_of_pairwise_cons ha h
          simp [ReflCmp.compare_self] at this
        have hnb : a ∉ bs := fun h => by
          have := List.rel_of_pairwise_cons hb h
          simp [ReflCmp.compare_self] at this
        simp [hna, hnb]
      · simpa [hx] using hm x

/-- 既に狭義昇順の列は変わらない。 -/
theorem sortUnique_eq_self {as : List α}
    (h : as.Pairwise (fun x y => cmp x y = .lt)) : sortUnique cmp as = as :=
  eq_of_pairwise_mem (pairwise_sortUnique as) h (fun _ => mem_sortUnique)

/-- 出力の等号は、入力の集合としての一致と同値である。 -/
theorem sortUnique_eq_iff_mem {as bs : List α} :
    sortUnique cmp as = sortUnique cmp bs ↔ ∀ x, x ∈ as ↔ x ∈ bs := by
  constructor
  · intro h x
    rw [← mem_sortUnique (cmp := cmp), h, mem_sortUnique]
  · intro h
    exact eq_of_pairwise_mem (pairwise_sortUnique as) (pairwise_sortUnique bs)
      (fun x => by simpa only [mem_sortUnique] using h x)

/-- 整列・重複除去を繰り返しても出力は変わらない。 -/
theorem sortUnique_idem (as : List α) : sortUnique cmp (sortUnique cmp as) = sortUnique cmp as :=
  sortUnique_eq_iff_mem.mpr (fun _ => mem_sortUnique)

/-- 連結する前に各列を整列しても、最終の代表は変わらない。 -/
theorem sortUnique_append (as bs : List α) :
    sortUnique cmp (sortUnique cmp as ++ sortUnique cmp bs) = sortUnique cmp (as ++ bs) := by
  apply sortUnique_eq_iff_mem.mpr
  intro x
  simp only [List.mem_append, mem_sortUnique]

omit [TransCmp cmp] in
/-- 写像で順序が逆転したり像が重複したりしても、元の列の重複除去は最終結果を変えない。 -/
theorem sortUnique_map_sortUnique {β : Type v} {cmp' : β → β → Ordering}
    [LawfulEqCmp cmp'] [TransCmp cmp'] (f : α → β) (as : List α) :
    sortUnique cmp' ((sortUnique cmp as).map f) = sortUnique cmp' (as.map f) := by
  apply sortUnique_eq_iff_mem.mpr
  intro x
  simp only [List.mem_map, mem_sortUnique]

/-- 連結した列の正規形は、両側の正規形だけで決まる。 -/
theorem sortUnique_append_congr {as as' bs bs' : List α}
    (ha : sortUnique cmp as = sortUnique cmp as')
    (hb : sortUnique cmp bs = sortUnique cmp bs') :
    sortUnique cmp (as ++ bs) = sortUnique cmp (as' ++ bs') := by
  rw [← sortUnique_append as bs, ha, hb, sortUnique_append as' bs']

end SK.Order

namespace SK.Structural
open SK.Order

-- Release/Normalize.lean Eff.norm, specialized to identity normalization on Nat.
def norm (e : Eff) : Eff := .mk e.atoms (sortUnique compare e.fails)
def Canonical (e : Eff) : Prop := norm e = e

theorem mem_norm (e : Eff) (a : Atom) : (norm e).mem a ↔ e.mem a := Iff.rfl
@[simp] theorem memFail_norm (e : Eff) (t : Nat) : (norm e).memFail t ↔ e.memFail t :=
  mem_sortUnique

theorem norm_idem (e : Eff) : norm (norm e) = norm e := by
  simp only [norm, Eff.atoms, Eff.fails, sortUnique_idem]

def ExactSub (e f : Eff) : Prop :=
  (∀ a, e.mem a → f.mem a) ∧ (∀ t, e.memFail t → f.memFail t)
def Sub (e f : Eff) : Prop :=
  (∀ a, e.mem a → ∃ b, f.mem b ∧ atomLe a b = true) ∧
  (∀ t, e.memFail t → f.memFail t)

theorem sub_refl (e : Eff) : Sub e e :=
  ⟨fun a ha => ⟨a, ha, atomLe_refl a⟩, fun _ => id⟩
theorem sub_trans {e f g : Eff} (h : Sub e f) (k : Sub f g) : Sub e g := by
  constructor
  · intro a ha
    obtain ⟨b, hb, hab⟩ := h.1 a ha
    obtain ⟨c, hc, hbc⟩ := k.1 b hb
    exact ⟨c, hc, atomLe_trans hab hbc⟩
  · exact fun t ht => k.2 t (h.2 t ht)

theorem exactSub_sub {e f : Eff} (h : ExactSub e f) : Sub e f :=
  ⟨fun a ha => ⟨a, h.1 a ha, atomLe_refl a⟩, h.2⟩
def empty : Eff := .mk (fun _ => false) []
def singleton (a : Atom) : Eff := .mk (fun x => decide (x = a)) []
def rawUnion (e f : Eff) : Eff := .mk (fun a => e.atoms a || f.atoms a) (e.fails ++ f.fails)
def union (e f : Eff) : Eff := norm (rawUnion e f)

@[simp] theorem mem_empty (a : Atom) : empty.mem a ↔ False := by simp [Eff.mem, empty, Eff.atoms]
@[simp] theorem mem_singleton (x a : Atom) : (singleton a).mem x ↔ x = a := by
  simp [singleton, Eff.mem, Eff.atoms]
@[simp] theorem memFail_empty (t : Nat) : empty.memFail t ↔ False := by simp [empty, Eff.memFail, Eff.fails]
@[simp] theorem mem_union (e f : Eff) (a : Atom) :
    (union e f).mem a ↔ e.mem a ∨ f.mem a := by
  simp [union, norm, rawUnion, Eff.mem, Eff.atoms]
@[simp] theorem memFail_union (e f : Eff) (t : Nat) :
    (union e f).memFail t ↔ e.memFail t ∨ f.memFail t := by
  simp [union, Eff.memFail, norm, Eff.fails, rawUnion, mem_sortUnique]

end SK.Structural

namespace SK

-- Semantics of atoms, including the unscoped all-targets upper bound.
def DenoteAtom (rows : Nat → Event → Prop) : Atom → Event → Prop
  | .name kind, ev => kind = ev.kind
  | .bounded s, ev => Allows s.scope ev
  | .rho i, ev => rows i ev

def Denote (rows : Nat → Event → Prop) (e : Eff) (ev : Event) : Prop :=
  ∃ a, e.mem a ∧ DenoteAtom rows a ev

theorem atomLe_sound {a b : Atom} (h : atomLe a b = true)
    (rows : Nat → Event → Prop) (ev : Event) : DenoteAtom rows a ev → DenoteAtom rows b ev := by
  cases a <;> cases b <;> simp_all [atomLe, DenoteAtom]
  · exact fun ha => h.symm.trans ha.1
  · exact scopeLe_sound h ev

theorem sub_sound {e f : Eff} (h : Structural.Sub e f)
    (rows : Nat → Event → Prop) (ev : Event) : Denote rows e ev → Denote rows f ev := by
  rintro ⟨a, ha, hd⟩
  obtain ⟨b, hb, hab⟩ := h.1 a ha
  exact ⟨b, hb, atomLe_sound hab rows ev hd⟩
theorem denote_singleton (rows : Nat → Event → Prop) (a : Atom) (ev : Event) :
    Denote rows (Structural.singleton a) ev ↔ DenoteAtom rows a ev := by
  simp [Denote, Structural.mem_singleton]

theorem denote_union (rows : Nat → Event → Prop) (e f : Eff) (ev : Event) :
    Denote rows (Structural.union e f) ev ↔ Denote rows e ev ∨ Denote rows f ev := by
  simp [Denote, Structural.mem_union, or_and_right, exists_or]

/-! Release/Syntax.Comp.app and Release/Typing.PrimSig, reduced to one
target argument, a closed signature, and a unit result. No functions, binders,
store, release, user effects, nested handlers, or continuation locations. -/
open Structural

inductive PrimName where
  | writeA | writeB | writeAny | httpsGet | tcpConnect
  deriving DecidableEq, Repr

structure Value where
  target : Word
  port : Nat
  deriving DecidableEq, Repr

inductive ArgTy where
  | raw
  | checked (scope : ClosedScope)
  deriving DecidableEq

def Value.HasType (v : Value) : ArgTy → Prop
  | .raw => True
  | .checked s => Matches s.scope.pattern v.target ∧ InPort s.scope.ports v.port

instance (v : Value) (t : ArgTy) : Decidable (v.HasType t) := by
  cases t <;> simp only [Value.HasType, InPort] <;> infer_instance

abbrev Checked (s : ClosedScope) := {v : Value // v.HasType (.checked s)}

def check (s : ClosedScope) (v : Value) : Option (Checked s) :=
  if h : v.HasType (.checked s) then some ⟨v, h⟩ else none

theorem checked_invariant (s : ClosedScope) (v : Checked s) :
    Allows s.scope ⟨s.scope.kind, v.val.target, v.val.port⟩ :=
  ⟨rfl, v.property⟩

theorem check_sound {s : ClosedScope} {v : Value} {cv : Checked s}
    (h : check s v = some cv) : cv.val = v ∧ v.HasType (.checked s) := by
  unfold check at h
  split at h
  · rename_i hv
    cases h; exact ⟨rfl, hv⟩
  · cases h

structure PrimSig where
  kind : Kind
  argTy : ArgTy
  eff : Eff
  neffs : Nat := 0

-- Replacement for Release.Assumptions.Builtins.Assumptions.io_op:
-- keep operation-family membership and neffs=0; replace eff=single name
-- by a closed envelope linked to the checked argument's scope.
def PrimSig.IOShape (s : PrimSig) : Prop :=
  s.neffs = 0 ∧
    ((s.argTy = .raw ∧ s.eff = Structural.singleton (.name s.kind)) ∨
     ∃ sc, sc.scope.kind = s.kind ∧ s.argTy = .checked sc ∧
       s.eff = Structural.singleton (.bounded sc))

-- Release.Semantics.Event.io b ws o, reduced to name + explicit observation.
-- Arguments and the outcome remain in ioResponse, rather than in this record.
-- The event's site is independent of its arguments until TargetAgreement.
structure IOEvent where
  name : PrimName
  site : Event
  deriving DecidableEq, Repr

-- Unit results are represented by token 0. Errors and exits are retained.
inductive Outcome where
  | val (token : Nat)
  | err (message : String)
  | exit (code : Int)
  deriving DecidableEq, Repr

def OutcomeTy : Outcome → Prop
  | .val n => n = 0
  | .err _ | .exit _ => True

structure Builtins where
  sig : PrimName → PrimSig
  effects : Kind → List PrimName
  ioResponse : PrimName → Value → IOEvent → Outcome → Prop

-- These are assumptions about signatures, result types and existence.
-- None of these fields constrains the actual target.
structure Builtins.BasicAssumptions (B : Builtins) : Prop where
  io_op : ∀ b, (B.sig b).IOShape ∧ b ∈ B.effects (B.sig b).kind
  effect_ops : ∀ k b, b ∈ B.effects k → (B.sig b).kind = k ∧ (B.sig b).IOShape
  io_typed : ∀ b v ev o, v.HasType (B.sig b).argTy → B.ioResponse b v ev o → OutcomeTy o
  io_exists : ∀ b v, v.HasType (B.sig b).argTy → ∃ ev o, B.ioResponse b v ev o

-- NEW trust condition, separate from io_op and from target soundness.
-- A relation to arguments, not a postulate of membership in the final effect.
structure Builtins.TargetAgreement (B : Builtins) : Prop where
  io_target : ∀ b v ev o, B.ioResponse b v ev o →
    ev.name = b ∧ ev.site = ⟨(B.sig b).kind, v.target, v.port⟩

structure Builtins.Assumptions (B : Builtins) : Prop extends
    B.BasicAssumptions, B.TargetAgreement

def noRows : Nat → Event → Prop := fun _ _ => False

def EventWithin (B : Builtins) (e : Eff) (ev : IOEvent) : Prop :=
  (B.sig ev.name).kind = ev.site.kind ∧ Denote noRows e ev.site

-- This proof uses checked-value invariants, not any behavior contract.
theorem argument_bound {s : PrimSig} (hs : s.IOShape) {v : Value}
    (hv : v.HasType s.argTy) :
    Denote noRows s.eff ⟨s.kind, v.target, v.port⟩ := by
  rcases hs.2 with ⟨ht, he⟩ | ⟨sc, hk, ht, he⟩
  · rw [he, denote_singleton]; exact rfl
  · rw [he, denote_singleton]
    rw [ht] at hv
    exact ⟨hk, hv⟩

-- The separate behavior contract connects the mathematical invariant
-- to the actual observation of the abstract IO relation.
theorem io_bound {B : Builtins} (hb : B.Assumptions) {b v ev o}
    (hv : v.HasType (B.sig b).argTy) (hr : B.ioResponse b v ev o) :
    EventWithin B (B.sig b).eff ev := by
  obtain ⟨hn, he⟩ := hb.io_target b v ev o hr
  constructor
  · rw [hn, he]
  · rw [he]; exact argument_bound (hb.io_op b).1 hv

-- If an event merely records the REQUEST argument (as Release's current
-- Event.io does), this weaker property needs no new behavior assumption.
-- It says nothing about which target the external implementation used.
def requestEvent (B : Builtins) (b : PrimName) (v : Value) : IOEvent :=
  ⟨b, ⟨(B.sig b).kind, v.target, v.port⟩⟩

theorem request_argument_bound {B : Builtins} (hb : B.BasicAssumptions) {b v}
    (hv : v.HasType (B.sig b).argTy) : EventWithin B (B.sig b).eff (requestEvent B b v) :=
  ⟨rfl, argument_bound (hb.io_op b).1 hv⟩

theorem within_sub {B : Builtins} {e f : Eff} {ev : IOEvent}
    (hs : Sub e f) (h : EventWithin B e ev) : EventWithin B f ev :=
  ⟨h.1, sub_sound hs noRows ev.site h.2⟩

theorem outside_handled {B : Builtins} {e : Eff} {ev : IOEvent} {k : Kind}
    (h : EventWithin B (Structural.union e (Structural.singleton (.name k))) ev)
    (hn : (B.sig ev.name).kind ≠ k) : EventWithin B e ev := by
  refine ⟨h.1, ?_⟩
  rcases (denote_union _ _ _ _).mp h.2 with he | hk
  · exact he
  · have hk : k = ev.site.kind := (denote_singleton _ _ _).mp hk
    exact False.elim (hn (h.1.trans hk.symm))

-- Reduced Release.Comp.ret / app / letIn. Continuations only return unit.
inductive Code where
  | done
  | call (b : PrimName) (arg : Value) (rest : Code)
  deriving DecidableEq, Repr

inductive CodeTy (B : Builtins) : Code → Eff → Prop where
  | done {e} : CodeTy B .done e
  | call {b v c e} : v.HasType (B.sig b).argTy → Sub (B.sig b).eff e →
      CodeTy B c e → CodeTy B (.call b v c) e

theorem CodeTy.tail {B b v c e} (h : CodeTy B (.call b v c) e) : CodeTy B c e := by
  cases h; assumption

-- A first-order handler handles ALL operations of one family. Its fixed clause
-- runs outside the handler; the remaining body resumes under the same handler.
-- This is a restricted E_OpPrim + deep, one-shot tail resume, without a store.
inductive Process where
  | plain (code : Code)
  | handled (family : Kind) (clause body : Code)
  | seq (left right : Process)
  | failed (message : String)
  | exited (code : Int)
  deriving DecidableEq, Repr

inductive ProcessTy (B : Builtins) : Process → Eff → Prop where
  | plain {c e} : CodeTy B c e → ProcessTy B (.plain c) e
  | handled {k clause body em e} : CodeTy B body em →
      Sub em (Structural.union e (Structural.singleton (.name k))) → CodeTy B clause e →
      ProcessTy B (.handled k clause body) e
  | seq {p q e} : ProcessTy B p e → ProcessTy B q e → ProcessTy B (.seq p q) e
  | failed {r e} : ProcessTy B (.failed r) e
  | exited {n e} : ProcessTy B (.exited n) e

def after (o : Outcome) (c : Code) : Process :=
  match o with
  | .val _ => .plain c
  | .err r => .failed r
  | .exit n => .exited n

def afterHandled (k : Kind) (clause : Code) (o : Outcome) (c : Code) : Process :=
  match o with
  | .val _ => .handled k clause c
  | .err r => .failed r
  | .exit n => .exited n

-- Small-step IO is copied from Release.Semantics.E_IO/E_IOErr/E_Exit.
-- The existence of an IO response is NOT required for an intercepted call.
inductive Step (B : Builtins) : Process → Option IOEvent → Process → Prop where
  | io {b v c ev o} : B.ioResponse b v ev o →
      Step B (.plain (.call b v c)) (some ev) (after o c)
  | hit {b v body k clause} : (B.sig b).kind = k →
      Step B (.handled k clause (.call b v body)) none
        (.seq (.plain clause) (.handled k clause body))
  | pass {b v body k clause ev o} : (B.sig b).kind ≠ k → B.ioResponse b v ev o →
      Step B (.handled k clause (.call b v body)) (some ev) (afterHandled k clause o body)
  | handledDone {k clause} : Step B (.handled k clause .done) none (.plain .done)
  | seqStep {p p' q ev} : Step B p ev p' → Step B (.seq p q) ev (.seq p' q)
  | seqDone {q} : Step B (.seq (.plain .done) q) none q
  | seqErr {r q} : Step B (.seq (.failed r) q) none (.failed r)
  | seqExit {n q} : Step B (.seq (.exited n) q) none (.exited n)

def Final : Process → Prop
  | .plain .done | .failed _ | .exited _ => True
  | _ => False

theorem after_typed {B c e} (h : CodeTy B c e) (o : Outcome) :
    ProcessTy B (after o c) e := by
  cases o <;> simp only [after]
  · exact .plain h
  · exact .failed
  · exact .exited

theorem afterHandled_typed {B k clause c em e} (h : CodeTy B c em)
    (hs : Sub em (Structural.union e (Structural.singleton (.name k)))) (hc : CodeTy B clause e) (o : Outcome) :
    ProcessTy B (afterHandled k clause o c) e := by
  cases o <;> simp only [afterHandled]
  · exact .handled h hs hc
  · exact .failed
  · exact .exited

-- This restricted preservation proof needs no target-behavior assumption.
-- Values are not substituted and all results are discarded unit results.
theorem preservation {B : Builtins} {p ev q e}
    (hs : Step B p ev q) (ht : ProcessTy B p e) : ProcessTy B q e := by
  induction hs generalizing e with
  | io hr =>
      cases ht with
      | plain hc => exact after_typed hc.tail _
  | hit hk =>
      cases ht with
      | handled hc hs hcl => exact .seq (.plain hcl) (.handled hc.tail hs hcl)
  | pass hn hr =>
      cases ht with
      | handled hc hs hcl => exact afterHandled_typed hc.tail hs hcl _
  | handledDone => exact .plain .done
  | seqStep hs ih =>
      cases ht with
      | seq hp hq => exact .seq (ih hp) hq
  | seqDone => cases ht with | seq _ hq => exact hq
  | seqErr => exact .failed
  | seqExit => exact .exited

theorem progress {B : Builtins} (hb : B.BasicAssumptions) {p e}
    (ht : ProcessTy B p e) : Final p ∨ ∃ ev q, Step B p ev q := by
  induction ht with
  | plain hc =>
      cases hc with
      | done => exact Or.inl trivial
      | call hv hs ht =>
          obtain ⟨ev, o, hr⟩ := hb.io_exists _ _ hv
          exact Or.inr ⟨some ev, _, .io hr⟩
  | @handled k clause body em e hc hs hcl =>
      cases hc with
      | done => exact Or.inr ⟨none, _, .handledDone⟩
      | @call b v c _ hv hsub htail =>
          by_cases hk : (B.sig b).kind = k
          · exact Or.inr ⟨none, _, .hit hk⟩
          · obtain ⟨ev, o, hr⟩ := hb.io_exists _ _ hv
            exact Or.inr ⟨some ev, _, .pass hk hr⟩
  | @seq p q e hp hq ihp ihq =>
      right
      rcases ihp with hf | ⟨ev, p', hs⟩
      · cases p with
        | plain c =>
            cases c with
            | done => exact ⟨none, _, .seqDone⟩
            | call _ _ _ => exact False.elim hf
        | failed r => exact ⟨none, _, .seqErr⟩
        | exited n => exact ⟨none, _, .seqExit⟩
        | handled _ _ _ => exact False.elim hf
        | seq _ _ => exact False.elim hf
      · exact ⟨ev, _, .seqStep hs⟩
  | failed | exited => exact Or.inl trivial

-- The old empty-effect property needs only the statically declared operation
-- family. It does not need to trust the observed event's name or target.
def Atom.Family : Atom → Option Kind
  | .name k => some k
  | .bounded s => some s.scope.kind
  | .rho _ => none

def HasKind (e : Eff) (k : Kind) : Prop :=
  ∃ a, e.mem a ∧ a.Family = some k

theorem atomLe_family {a b : Atom} (h : atomLe a b = true) : a.Family = b.Family := by
  cases a <;> cases b <;> simp_all [atomLe, Atom.Family]
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h
  exact h.1.1

theorem hasKind_sub {e f : Eff} {k : Kind} (hs : Sub e f) (h : HasKind e k) : HasKind f k := by
  obtain ⟨a, ha, hk⟩ := h
  obtain ⟨b, hb, hab⟩ := hs.1 a ha
  exact ⟨b, hb, (atomLe_family hab).symm.trans hk⟩

theorem signature_hasKind {s : PrimSig} (hs : s.IOShape) : HasKind s.eff s.kind := by
  rcases hs.2 with ⟨_, he⟩ | ⟨sc, hk, _, he⟩
  · exact ⟨.name s.kind, by rw [he]; exact (mem_singleton _ _).mpr rfl, rfl⟩
  · exact ⟨.bounded sc, by rw [he]; exact (mem_singleton _ _).mpr rfl, congrArg some hk⟩

theorem hasKind_outside_handled {e : Eff} {k l : Kind}
    (h : HasKind (Structural.union e (Structural.singleton (.name k))) l)
    (hn : l ≠ k) : HasKind e l := by
  obtain ⟨a, ha, hk⟩ := h
  rcases (mem_union _ _ _).mp ha with he | hh
  · exact ⟨a, he, hk⟩
  · have he := (mem_singleton _ _).mp hh
    subst a
    exact False.elim (hn (Option.some.inj hk).symm)

theorem step_requires_kind {B : Builtins} (hb : B.BasicAssumptions) {p q e ev}
    (ht : ProcessTy B p e) (hs : Step B p (some ev) q) : ∃ k, HasKind e k := by
  generalize he : some ev = label at hs
  induction hs generalizing e with
  | @io b v c observed o hr =>
      cases ht with
      | plain hc =>
          cases hc with
          | call hv hsub _ => exact ⟨_, hasKind_sub hsub (signature_hasKind (hb.io_op b).1)⟩
  | @pass b v body k clause observed o hn hr =>
      cases ht with
      | handled hc hs hcl =>
          cases hc with
          | call hv hsub _ =>
              exact ⟨_, hasKind_outside_handled
                (hasKind_sub (sub_trans hsub hs) (signature_hasKind (hb.io_op b).1)) hn⟩
  | seqStep hs ih =>
      cases ht with
      | seq hp hq => exact ih hp he
  | hit _ | handledDone | seqDone | seqErr | seqExit => cases he

theorem empty_has_no_kind (k : Kind) : ¬ HasKind Structural.empty k := by
  rintro ⟨a, ha, _⟩; exact (mem_empty a).mp ha

theorem step_target_soundness {B : Builtins} (hb : B.Assumptions) {p q e ev}
    (ht : ProcessTy B p e) (hs : Step B p (some ev) q) : EventWithin B e ev := by
  generalize he : some ev = label at hs
  induction hs generalizing e with
  | io hr =>
      cases he
      cases ht with
      | plain hc =>
          cases hc with
          | call hv hsub _ => exact within_sub hsub (io_bound hb hv hr)
  | pass hn hr =>
      cases he
      cases ht with
      | handled hc hs hcl =>
          cases hc with
          | call hv hsub _ =>
              have hbound := within_sub (sub_trans hsub hs) (io_bound hb hv hr)
              have hname := (hb.io_target _ _ _ _ hr).1
              apply outside_handled hbound
              simpa only [hname] using hn
  | seqStep hs ih =>
      cases ht with
      | seq hp hq => exact ih hp he
  | hit _ | handledDone | seqDone | seqErr | seqExit => cases he

-- Multi-step relation records only external IO observations, not handled calls.
inductive Steps (B : Builtins) : Process → List IOEvent → Process → Prop where
  | refl {p} : Steps B p [] p
  | step {p q r label trace} : Step B p label q → Steps B q trace r →
      Steps B p (label.toList ++ trace) r

theorem steps_preserve {B p trace q e} (hs : Steps B p trace q)
    (ht : ProcessTy B p e) : ProcessTy B q e := by
  induction hs with
  | refl => exact ht
  | step h _ ih => exact ih (preservation h ht)

theorem trace_target_soundness {B : Builtins} (hb : B.Assumptions) {p trace q e}
    (ht : ProcessTy B p e) (hs : Steps B p trace q) :
    ∀ ev ∈ trace, EventWithin B e ev := by
  induction hs with
  | refl => simp
  | @step p q r label trace hstep hsteps ih =>
      intro ev hmem
      rcases List.mem_append.mp hmem with h | h
      · cases label with
        | none => simp at h
        | some observed =>
            have he : ev = observed := by simpa using h
            subst ev
            exact step_target_soundness hb ht hstep
      · exact ih (preservation hstep ht) ev h

theorem reachable_target_soundness {B : Builtins} (hb : B.Assumptions)
    {p trace q e ev r} (ht : ProcessTy B p e) (hs : Steps B p trace q)
    (hnext : Step B q (some ev) r) : EventWithin B e ev :=
  step_target_soundness hb (steps_preserve hs ht) hnext

theorem empty_has_no_target (ev : Event) : ¬ Denote noRows Structural.empty ev := by
  rintro ⟨a, ha, _⟩; exact (mem_empty a).mp ha

-- Separate completion criterion from target soundness; analogous to
-- Release.effect_soundness's no-event half (no user operations in this model).
theorem effect_soundness {B : Builtins} (hb : B.BasicAssumptions) {p trace q ev r}
    (ht : ProcessTy B p Structural.empty) (hs : Steps B p trace q) : ¬ Step B q (some ev) r := by
  intro h
  obtain ⟨k, hk⟩ := step_requires_kind hb (steps_preserve hs ht) h
  exact empty_has_no_kind k hk

theorem pure_trace_empty {B : Builtins} (hb : B.BasicAssumptions) {p trace q}
    (ht : ProcessTy B p Structural.empty) (hs : Steps B p trace q) : trace = [] := by
  induction hs with
  | refl => rfl
  | @step p q r label trace hstep hsteps ih =>
      cases label with
      | none => exact ih (preservation hstep ht)
      | some observed =>
          obtain ⟨k, hk⟩ := step_requires_kind hb ht hstep
          exact False.elim (empty_has_no_kind k hk)

/-! Concrete implementations witness consistency of all assumptions.
The malicious implementation keeps signatures, result types and existence,
but ignores the checked argument's target. -/
namespace Examples

def scopeA : ClosedScope :=
  ⟨⟨.write, .exact ["out", "a.txt"], ⟨0, 65535⟩⟩, by change 0 ≤ 65535; omega, Nat.le_refl _⟩
def scopeB : ClosedScope :=
  ⟨⟨.write, .exact ["outside", "b.txt"], ⟨0, 65535⟩⟩, by change 0 ≤ 65535; omega, Nat.le_refl _⟩
def hostScope : ClosedScope :=
  ⟨⟨.tcp, .tree ["com", "example"] 1, ⟨443, 443⟩⟩, Nat.le_refl _, by change 443 ≤ 65535; omega⟩
def httpsScope : ClosedScope :=
  ⟨⟨.https, .exact ["com", "example", "api"], ⟨443, 443⟩⟩,
    Nat.le_refl _, by change 443 ≤ 65535; omega⟩
def argA : Value := ⟨["out", "a.txt"], 0⟩
def argB : Value := ⟨["outside", "b.txt"], 0⟩
def effA : Eff := Structural.singleton (.bounded scopeA)
def effB : Eff := Structural.singleton (.bounded scopeB)

def boundedSig (s : ClosedScope) : PrimSig :=
  ⟨s.scope.kind, .checked s, Structural.singleton (.bounded s), 0⟩
def rawSig (k : Kind) : PrimSig :=
  ⟨k, .raw, Structural.singleton (.name k), 0⟩

theorem bounded_shape (s : ClosedScope) : (boundedSig s).IOShape :=
  ⟨rfl, Or.inr ⟨s, rfl, rfl, rfl⟩⟩
theorem raw_shape (k : Kind) : (rawSig k).IOShape :=
  ⟨rfl, Or.inl ⟨rfl, rfl⟩⟩

theorem bounded_not_old_io_op (sc : ClosedScope) :
    (boundedSig sc).eff ≠ Structural.singleton (.name sc.scope.kind) := by
  intro he
  have hm : (boundedSig sc).eff.mem (.bounded sc) := (mem_singleton _ _).mpr rfl
  rw [he] at hm
  have hf := (mem_singleton _ _).mp hm
  cases hf

def signature : PrimName → PrimSig
  | .writeA => boundedSig scopeA
  | .writeB => boundedSig scopeB
  | .writeAny => rawSig .write
  | .httpsGet => boundedSig httpsScope
  | .tcpConnect => boundedSig hostScope

theorem signature_shape (b : PrimName) : (signature b).IOShape := by
  cases b
  · exact bounded_shape _
  · exact bounded_shape _
  · exact raw_shape _
  · exact bounded_shape _
  · exact bounded_shape _

def names : List PrimName := [.writeA, .writeB, .writeAny, .httpsGet, .tcpConnect]
def effects (k : Kind) : List PrimName := names.filter (fun b => decide ((signature b).kind = k))

theorem all_names (b : PrimName) : b ∈ names := by cases b <;> simp [names]

def observe (b : PrimName) (v : Value) : IOEvent :=
  ⟨b, ⟨(signature b).kind, v.target, v.port⟩⟩
def misobserve (b : PrimName) (_v : Value) : IOEvent :=
  ⟨b, ⟨(signature b).kind, argB.target, argB.port⟩⟩

def implementation (obs : PrimName → Value → IOEvent) : Builtins where
  sig := signature
  effects := effects
  ioResponse b v ev o := ev = obs b v ∧ OutcomeTy o

theorem implementation_basic (obs : PrimName → Value → IOEvent) :
    (implementation obs).BasicAssumptions where
  io_op b := ⟨signature_shape b, List.mem_filter.mpr ⟨all_names b, by simp [implementation]⟩⟩
  effect_ops k b h :=
    ⟨of_decide_eq_true (List.mem_filter.mp h).2, signature_shape b⟩
  io_typed _ _ _ _ _ h := h.2
  io_exists b v _ := ⟨obs b v, .val 0, rfl, rfl⟩

def good : Builtins := implementation observe
def bad : Builtins := implementation misobserve

theorem good_assumptions : good.Assumptions where
  toBasicAssumptions := implementation_basic observe
  io_target b v ev o h := by
    obtain ⟨rfl, _⟩ := h
    exact ⟨rfl, rfl⟩

theorem bad_basic : bad.BasicAssumptions := implementation_basic misobserve

theorem argA_checked : argA.HasType (.checked scopeA) := by
  simp [Value.HasType, scopeA, argA, Matches, InPort]
theorem argB_checked : argB.HasType (.checked scopeB) := by
  simp [Value.HasType, scopeB, argB, Matches, InPort]

def eventA := observe .writeA argA
def eventB := observe .writeB argB
def bodyA : Code := .call .writeA argA .done
def clauseB : Code := .call .writeB argB .done
def redirect : Process := .handled .write clauseB bodyA

theorem eventB_not_A : ¬ EventWithin good effA eventB := by
  intro h
  have hd := (denote_singleton noRows (.bounded scopeA) eventB.site).mp h.2
  have hp := hd.2.1
  simp [Matches, scopeA, eventB, observe, argB] at hp

-- No property of the checked value forces an arbitrary IO implementation
-- to respect it. All BasicAssumptions still hold in this countermodel.
theorem checked_alone_insufficient :
    bad.BasicAssumptions ∧ ∃ ev, argA.HasType (bad.sig .writeA).argTy ∧
      bad.ioResponse .writeA argA ev (.val 0) ∧
      ¬ EventWithin bad (bad.sig .writeA).eff ev := by
  refine ⟨bad_basic, misobserve .writeA argA, argA_checked, ⟨rfl, rfl⟩, ?_⟩
  intro h
  have hd := (denote_singleton noRows (.bounded scopeA)
    (misobserve .writeA argA).site).mp h.2
  have hp := hd.2.1
  simp [Matches, scopeA, misobserve, argB] at hp

theorem bad_has_no_target_agreement : ¬ bad.TargetAgreement := by
  intro ht
  obtain ⟨_, he⟩ := ht.io_target .writeA argA (misobserve .writeA argA) (.val 0) ⟨rfl, rfl⟩
  have hp := congrArg Event.target he
  simp [misobserve, argA, argB] at hp

theorem bounded_to_whole (sc : ClosedScope) (k : Kind) (hk : sc.scope.kind = k) :
    Sub (Structural.singleton (.bounded sc)) (Structural.singleton (.name k)) := by
  constructor
  · intro a ha
    have he : a = .bounded sc := (mem_singleton _ _).mp ha
    subst a
    exact ⟨.name k, (mem_singleton _ _).mpr rfl, by simpa [atomLe] using decide_eq_true hk⟩
  · intro t ht
    simp [Eff.memFail, Structural.singleton, Eff.fails] at ht

theorem sub_union_right (e f : Eff) : Sub f (Structural.union e f) := by
  constructor
  · intro a ha; exact ⟨a, (mem_union _ _ _).mpr (Or.inr ha), atomLe_refl a⟩
  · intro t ht; exact (memFail_union _ _ _).mpr (Or.inr ht)

theorem bodyA_typed : CodeTy good bodyA effA :=
  .call argA_checked (sub_refl _) .done
theorem clauseB_typed : CodeTy good clauseB effB :=
  .call argB_checked (sub_refl _) .done

theorem redirect_typed : ProcessTy good redirect effB :=
  .handled bodyA_typed
    (sub_trans (bounded_to_whole scopeA .write rfl) (sub_union_right _ _)) clauseB_typed

-- The clause changes both the builtin and its target, but keeps the same
-- operation family. It is not intercepted again by its own handler.
theorem redirect_exec : Steps good redirect [eventB]
    (.seq (.plain .done) (.handled .write clauseB .done)) := by
  have h1 : Step good redirect none (.seq (.plain clauseB) (.handled .write clauseB .done)) :=
    .hit (b := .writeA) rfl
  have h2 : Step good (.seq (.plain clauseB) (.handled .write clauseB .done)) (some eventB)
      (.seq (.plain .done) (.handled .write clauseB .done)) :=
    .seqStep (.io (B := good) (b := .writeB) (o := .val 0) ⟨rfl, rfl⟩)
  exact .step h1 (.step h2 .refl)

theorem redirect_event_in_bound : EventWithin good effB eventB :=
  trace_target_soundness good_assumptions redirect_typed redirect_exec eventB (by simp)

-- WRONG rule: allow the clause some effect ec without requiring ec <= e.
def WrongHandleRule (B : Builtins) (k : Kind) (clause body : Code) (e : Eff) : Prop :=
  ∃ em ec, CodeTy B body em ∧ Sub em (Structural.union e (Structural.singleton (.name k))) ∧
    CodeTy B clause ec

theorem wrong_rule_admits_empty : WrongHandleRule good .write clauseB bodyA Structural.empty :=
  ⟨effA, effB, bodyA_typed,
    sub_trans (bounded_to_whole scopeA .write rfl) (sub_union_right _ _), clauseB_typed⟩

theorem wrong_rule_unsound :
    WrongHandleRule good .write clauseB bodyA Structural.empty ∧
    Steps good redirect [eventB] (.seq (.plain .done) (.handled .write clauseB .done)) ∧
    ¬ EventWithin good Structural.empty eventB :=
  ⟨wrong_rule_admits_empty, redirect_exec, fun h => empty_has_no_target _ h.2⟩

theorem original_target_budget_rejected : ¬ ProcessTy good redirect effA := by
  intro ht
  exact eventB_not_A (trace_target_soundness good_assumptions ht redirect_exec eventB (by simp))

theorem empty_budget_rejected : ¬ ProcessTy good redirect Structural.empty := by
  intro ht
  have h := trace_target_soundness good_assumptions ht redirect_exec eventB (by simp)
  exact empty_has_no_target _ h.2

-- The old String-like entry accepts arbitrary parsed target and port values;
-- it has the all-targets operation-family bound, not a fabricated narrow scope.
theorem unscoped_all_targets (v : Value) :
    ProcessTy good (.plain (.call .writeAny v .done))
      (Structural.singleton (.name .write)) ∧
    EventWithin good (Structural.singleton (.name .write)) (observe .writeAny v) := by
  constructor
  · exact .plain (.call trivial (sub_refl _) .done)
  · exact io_bound good_assumptions (b := .writeAny) (v := v) (o := .val 0) trivial ⟨rfl, rfl⟩

theorem bounded_tcp_target :
    EventWithin good (Structural.singleton (.bounded hostScope))
      (observe .tcpConnect ⟨["com", "example", "api"], 443⟩) := by
  apply io_bound good_assumptions (b := .tcpConnect)
    (v := ⟨["com", "example", "api"], 443⟩) (o := .val 0)
  · simp [good, implementation, signature, boundedSig, Value.HasType, hostScope,
      Matches, InPort, List.IsPrefix]
  · exact ⟨rfl, rfl⟩

theorem bounded_https_target :
    EventWithin good (Structural.singleton (.bounded httpsScope))
      (observe .httpsGet ⟨["com", "example", "api"], 443⟩) := by
  apply io_bound good_assumptions (b := .httpsGet)
    (v := ⟨["com", "example", "api"], 443⟩) (o := .val 0)
  · simp [good, implementation, signature, boundedSig, Value.HasType, httpsScope,
      Matches, InPort]
  · exact ⟨rfl, rfl⟩

-- Finite compute checks at the boundary of closed host/port scopes.
#guard (check hostScope ⟨["com", "example", "api"], 443⟩).isSome
#guard (check hostScope ⟨["com", "example"], 443⟩).isNone
#guard (check hostScope ⟨["com", "example", "api"], 80⟩).isNone

end Examples

#print axioms checked_invariant
#print axioms argument_bound
#print axioms request_argument_bound
#print axioms io_bound
#print axioms preservation
#print axioms progress
#print axioms trace_target_soundness
#print axioms reachable_target_soundness
#print axioms effect_soundness
#print axioms Examples.checked_alone_insufficient
#print axioms Examples.good_assumptions
#print axioms Examples.wrong_rule_unsound
#print axioms Examples.original_target_budget_rejected
#print axioms Examples.bounded_tcp_target
#print axioms Examples.bounded_https_target

end SK
