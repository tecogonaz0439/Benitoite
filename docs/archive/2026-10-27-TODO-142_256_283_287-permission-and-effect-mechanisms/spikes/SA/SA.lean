import Std

#eval Lean.versionString

-- Copied from TODO-142 Scope.lean: Word, Pattern, Matches, patLe, Interval,
-- portLe, Kind, Scope, Allows, scopeLe, and their proofs (through scopeLe_trans).

/-!
Disposable TODO-142 spike. Independent of Benitoite and its concurrent L1b work.
Only normalized component lists are modeled; no DNS, URL, filesystem, or parser.
`tree s 0` models terminal path /**; `tree (reverse suffix) 1` models
a host wildcard accepting one or more extra labels, excluding the apex.
-/
namespace SA

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


end SA

-- Copy of san_benito Release/Order/SortUnique.lean, all declarations.

/-!
# 全順序による整列と重複除去

型内部の Fail 列の代表を一意にするための、型表現に依存しない補題である。
空列と単一要素の列は比較を評価しない（設計書 07-04「01-12 との対応」）。
-/

namespace SA.Order

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

end SA.Order

namespace SA

-- Additional hypotheses are enforced by the syntax of the second model.
-- Empty port intervals in the unmodified Scope.lean are NOT antisymmetric.
#guard portLe ⟨5, 2⟩ ⟨9, 1⟩ && portLe ⟨9, 1⟩ ⟨5, 2⟩
#guard (⟨5, 2⟩ : Interval) != ⟨9, 1⟩

theorem patLe_antisymm {a b : Pattern} (h : patLe a b = true)
    (g : patLe b a = true) : a = b := by
  cases a with
  | exact a =>
    cases b with
    | exact b => exact congrArg Pattern.exact (of_decide_eq_true h).symm
    | tree b l => simp [patLe] at g
  | tree a k =>
    cases b with
    | exact b => simp [patLe] at h
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length + k := of_decide_eq_true h
      have g : a.IsPrefix b ∧ a.length + k ≤ b.length + l := of_decide_eq_true g
      have hab : b = a := h.1.eq_of_length (Nat.le_antisymm h.1.length_le g.1.length_le)
      subst b
      have hkl : k = l := by omega
      cases hkl
      rfl

def patRank : Pattern → Nat
  | .exact a => 2 * a.length + 1
  | .tree a k => 2 * a.length + k

theorem patLe_rank {a b : Pattern} (h : patLe a b = true) : patRank b ≤ patRank a := by
  cases a with
  | exact a =>
    cases b with
    | exact b => have hab : b = a := of_decide_eq_true h; subst b; exact Nat.le_refl _
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length := of_decide_eq_true h
      have hb := h.1.length_le
      simp only [patRank]
      omega
  | tree a k =>
    cases b with
    | exact b => simp [patLe] at h
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length + k := of_decide_eq_true h
      have hb := h.1.length_le
      simp only [patRank]
      omega

theorem patLe_eq_of_rank {a b : Pattern} (h : patLe a b = true)
    (hr : patRank b = patRank a) : a = b := by
  cases a with
  | exact a =>
    cases b with
    | exact b => exact congrArg Pattern.exact (of_decide_eq_true h).symm
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length := of_decide_eq_true h
      have hb := h.1.length_le
      simp only [patRank] at hr
      omega
  | tree a k =>
    cases b with
    | exact b => simp [patLe] at h
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length + k := of_decide_eq_true h
      have hb := h.1.length_le
      simp only [patRank] at hr
      have he : b.length = a.length := by omega
      have hab : b = a := h.1.eq_of_length he
      subst b
      have hkl : k = l := by omega
      subst l
      rfl

structure ClosedScope where
  scope : Scope
  nonempty : scope.ports.lo ≤ scope.ports.hi
  bounded : scope.ports.hi ≤ 65535

instance : DecidableEq ClosedScope := fun a b =>
  decidable_of_iff (a.scope = b.scope) ⟨fun h => by cases a; cases b; cases h; rfl,
    fun h => congrArg ClosedScope.scope h⟩

def scopeRank (s : ClosedScope) : Nat :=
  patRank s.scope.pattern + s.scope.ports.lo + (65535 - s.scope.ports.hi)

theorem interval_ext (a b : Interval) (hl : a.lo = b.lo) (hh : a.hi = b.hi) : a = b := by
  cases a; cases b; simp_all

theorem scope_ext (a b : Scope) (hk : a.kind = b.kind) (hp : a.pattern = b.pattern)
    (hr : a.ports = b.ports) : a = b := by
  cases a; cases b; simp_all

theorem closedScope_antisymm {a b : ClosedScope}
    (h : scopeLe a.scope b.scope = true) (g : scopeLe b.scope a.scope = true) : a = b := by
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h g
  have hp := patLe_antisymm h.1.2 g.1.2
  have hl := (portLe_iff _ _).mp h.2 a.scope.ports.lo ⟨Nat.le_refl _, a.nonempty⟩
  have gl := (portLe_iff _ _).mp g.2 b.scope.ports.lo ⟨Nat.le_refl _, b.nonempty⟩
  have hh := (portLe_iff _ _).mp h.2 a.scope.ports.hi ⟨a.nonempty, Nat.le_refl _⟩
  have gh := (portLe_iff _ _).mp g.2 b.scope.ports.hi ⟨b.nonempty, Nat.le_refl _⟩
  simp only [InPort] at gl gh
  simp only [InPort] at hl hh
  have hlo : a.scope.ports.lo = b.scope.ports.lo := by omega
  have hhi : a.scope.ports.hi = b.scope.ports.hi := by omega
  have hs : a.scope = b.scope :=
    scope_ext _ _ h.1.1 hp (interval_ext _ _ hlo hhi)
  cases a; cases b; cases hs; rfl

theorem scopeLe_rank {a b : ClosedScope} (h : scopeLe a.scope b.scope = true) :
    scopeRank b ≤ scopeRank a := by
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h
  have hp := patLe_rank h.1.2
  have hl := (portLe_iff _ _).mp h.2 a.scope.ports.lo ⟨Nat.le_refl _, a.nonempty⟩
  have hh := (portLe_iff _ _).mp h.2 a.scope.ports.hi ⟨a.nonempty, Nat.le_refl _⟩
  have hb := b.bounded
  simp only [scopeRank]
  simp only [InPort] at hl hh
  omega

theorem scopeLe_eq_of_rank {a b : ClosedScope} (h : scopeLe a.scope b.scope = true)
    (hr : scopeRank b = scopeRank a) : a = b := by
  have hm := h
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h
  have hp := patLe_rank h.1.2
  have hl := (portLe_iff _ _).mp h.2 a.scope.ports.lo ⟨Nat.le_refl _, a.nonempty⟩
  have hh := (portLe_iff _ _).mp h.2 a.scope.ports.hi ⟨a.nonempty, Nat.le_refl _⟩
  have ha := a.bounded
  have hb := b.bounded
  simp only [InPort] at hl hh
  simp only [scopeRank] at hr
  have he : patRank b.scope.pattern = patRank a.scope.pattern := by omega
  have hpe := patLe_eq_of_rank h.1.2 he
  have hlo : a.scope.ports.lo = b.scope.ports.lo := by omega
  have hhi : a.scope.ports.hi = b.scope.ports.hi := by omega
  apply closedScope_antisymm hm
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq]
  refine ⟨⟨h.1.1.symm, ?_⟩, ?_⟩
  · rw [hpe]; exact patLe_refl _
  · simp only [portLe, decide_eq_true_eq]
    exact Or.inr ⟨by omega, by omega⟩

-- Copy of Release/Atom.lean: name/rho, adding a type-independent bounded atom.
-- A name is the upper bound for every bounded atom of the same kind.
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

theorem atomLe_antisymm {a b : Atom} (h : atomLe a b = true)
    (g : atomLe b a = true) : a = b := by
  cases a <;> cases b <;> simp_all [atomLe]
  exact closedScope_antisymm h g

def atomRank : Atom → Nat
  | .name _ | .rho _ => 0
  | .bounded s => scopeRank s + 1

theorem atomLe_strict_rank {a b : Atom} (h : atomLe a b = true)
    (g : atomLe b a ≠ true) : atomRank b < atomRank a := by
  cases a <;> cases b <;> simp_all [atomLe, atomRank]
  rename_i sa sb
  have hm := scopeLe_rank h
  have he : scopeRank sb ≠ scopeRank sa := by
    intro he
    have hab := scopeLe_eq_of_rank h he
    subst sb
    simp [scopeLe_refl] at g
  omega

-- Reduced copy of Release/Types.lean EffR.mk: exact same function/list shape.
-- Fail payloads are Nat parameters here, with arbitrary maps in substitution.
-- Nested Ty/fn/cont and type binders are NOT copied into this algebraic spike.
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

namespace Structural
open Order

-- Release/Normalize.lean Eff.norm, specialized to identity normalization on Nat.
def norm (e : Eff) : Eff := .mk e.atoms (sortUnique compare e.fails)
def Canonical (e : Eff) : Prop := norm e = e

theorem mem_norm (e : Eff) (a : Atom) : (norm e).mem a ↔ e.mem a := Iff.rfl
@[simp] theorem memFail_norm (e : Eff) (t : Nat) : (norm e).memFail t ↔ e.memFail t :=
  mem_sortUnique

theorem norm_idem (e : Eff) : norm (norm e) = norm e := by
  simp only [norm, Eff.atoms, Eff.fails, sortUnique_idem]

-- Syntactic containment and scope-aware containment remain separate.
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

-- This is the sound replacement of Effect.lean eq_of_sub_of_sub for handling 1.
-- Scope-aware Sub CANNOT replace ExactSub in this theorem.
theorem eq_of_exactSub_of_exactSub {e f : Eff} (he : Canonical e) (hf : Canonical f)
    (h : ExactSub e f) (g : ExactSub f e) : e = f := by
  apply Eff.ext (fun a => ⟨h.1 a, g.1 a⟩)
  have hs : (norm e).fails = (norm f).fails :=
    sortUnique_eq_iff_mem.mpr (fun t => ⟨h.2 t, g.2 t⟩)
  exact (congrArg Eff.fails he).symm.trans (hs.trans (congrArg Eff.fails hf))

theorem norm_ext {e f : Eff} (ha : ∀ a, e.mem a ↔ f.mem a)
    (ht : ∀ t, e.memFail t ↔ f.memFail t) : norm e = norm f := by
  apply eq_of_exactSub_of_exactSub (norm_idem e) (norm_idem f)
  · exact ⟨fun a => (ha a).mp, fun t => by simpa only [memFail_norm] using (ht t).mp⟩
  · exact ⟨fun a => (ha a).mpr, fun t => by simpa only [memFail_norm] using (ht t).mpr⟩

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

theorem union_canonical (e f : Eff) : Canonical (union e f) := norm_idem _

-- Representative rewrite of Surface/Lemmas/Sequence.union_empty_right_nested.
-- Exact membership replaces the use of scope-aware mutual Sub.
theorem union_empty_right_nested (a b : Eff) :
    union a (union b empty) = union a b := by
  apply eq_of_exactSub_of_exactSub (union_canonical _ _) (union_canonical _ _)
  all_goals
    simp only [ExactSub, mem_union, memFail_union, mem_empty, memFail_empty, or_false]
    exact ⟨fun _ => id, fun _ => id⟩

theorem sub_norm (e : Eff) : Sub e (norm e) :=
  ⟨fun a ha => ⟨a, ha, atomLe_refl a⟩, fun t ht => (memFail_norm e t).mpr ht⟩
theorem norm_sub (e : Eff) : Sub (norm e) e :=
  ⟨fun a ha => ⟨a, ha, atomLe_refl a⟩, fun t ht => (memFail_norm e t).mp ht⟩

-- Copy of Release/TypeSubst: substAtoms, rowFails, rawBind and rowImage.
-- Fail-type substitution is an arbitrary map Nat -> Nat in this reduced model.
def substAtoms (es : List Eff) (a : Atom → Bool) : Atom → Bool := fun x =>
  let kept := match x with
    | .name _ | .bounded _ => a x
    | .rho i => if i < es.length then false else a (.rho i)
  kept || (List.range es.length).any (fun i =>
    a (.rho i) && match es[i]? with
      | some e => e.atoms x
      | none => false)

def rowFails (es : List Eff) (a : Atom → Bool) : List Nat :=
  ((List.range es.length).filter (fun i => a (.rho i))).flatMap (fun i =>
    match es[i]? with
    | some e => e.fails
    | none => [])

def rawBind (τ : Nat → Nat) (es : List Eff) (e : Eff) : Eff :=
  .mk (substAtoms es e.atoms) (e.fails.map τ ++ rowFails es e.atoms)
def bind (τ : Nat → Nat) (es : List Eff) (e : Eff) : Eff := norm (rawBind τ es e)
def rowImage (es : List Eff) (i : Nat) : Eff := es[i]?.getD (singleton (.rho i))

def Ground : Atom → Prop | .rho _ => False | _ => True
instance (a : Atom) : Decidable (Ground a) := by cases a <;> unfold Ground <;> infer_instance

theorem mem_substAtoms (es : List Eff) (a : Atom → Bool) (x : Atom) :
    substAtoms es a x = true ↔
      (Ground x ∧ a x = true) ∨
      ∃ i, a (.rho i) = true ∧ (rowImage es i).mem x := by
  have hx : ∀ i e, es[i]? = some e → i < es.length :=
    fun i e h => (List.getElem?_eq_some_iff.mp h).1
  simp only [substAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
  constructor
  · rintro (hk | ⟨i, hi, ha, hm⟩)
    · cases x with
      | name l => exact Or.inl ⟨trivial, hk⟩
      | bounded s => exact Or.inl ⟨trivial, hk⟩
      | rho i =>
        have hn : ¬ i < es.length := by intro h; simp [h] at hk
        exact Or.inr ⟨i, by simpa [hn] using hk, by
          simp [rowImage, List.getElem?_eq_none (Nat.le_of_not_gt hn), mem_singleton]⟩
    · cases he : es[i]? with
      | none => simp [he] at hm
      | some e => exact Or.inr ⟨i, ha, by simpa [rowImage, he, Eff.mem] using hm⟩
  · rintro (⟨hg, ha⟩ | ⟨i, hi, hm⟩)
    · left; cases x <;> simp_all [Ground]
    · cases he : es[i]? with
      | none =>
        have hxi : x = .rho i := by simpa [rowImage, he] using hm
        subst x
        left
        simp [Nat.not_lt.mpr (List.getElem?_eq_none_iff.mp he), hi]
      | some e =>
        right
        exact ⟨i, hx i e he, hi, by simpa [rowImage, he, Eff.mem] using hm⟩

theorem mem_rowFails {es : List Eff} {a : Atom → Bool} {t : Nat} :
    t ∈ rowFails es a ↔ ∃ i e, es[i]? = some e ∧ a (.rho i) = true ∧ t ∈ e.fails := by
  simp only [rowFails, List.mem_flatMap, List.mem_filter, List.mem_range]
  constructor
  · rintro ⟨i, ⟨hi, ha⟩, ht⟩
    exact ⟨i, es[i], List.getElem?_eq_getElem hi, ha, by
      simpa only [List.getElem?_eq_getElem hi] using ht⟩
  · rintro ⟨i, e, he, ha, ht⟩
    exact ⟨i, ⟨(List.getElem?_eq_some_iff.mp he).1, ha⟩, by simpa only [he] using ht⟩

@[simp] theorem mem_bind (τ : Nat → Nat) (es : List Eff) (e : Eff) (a : Atom) :
    (bind τ es e).mem a ↔
      (Ground a ∧ e.mem a) ∨ ∃ i, e.mem (.rho i) ∧ (rowImage es i).mem a :=
  mem_substAtoms es e.atoms a

@[simp] theorem memFail_bind (τ : Nat → Nat) (es : List Eff) (e : Eff) (t : Nat) :
    (bind τ es e).memFail t ↔
      (∃ x, e.memFail x ∧ τ x = t) ∨
      ∃ i, e.mem (.rho i) ∧ (rowImage es i).memFail t := by
  rw [bind, memFail_norm]
  simp only [rawBind, Eff.memFail, Eff.fails, List.mem_append, List.mem_map]
  apply or_congr Iff.rfl
  rw [mem_rowFails]
  constructor
  · rintro ⟨i, f, hf, hi, ht⟩
    exact ⟨i, hi, by cases f; simpa [rowImage, hf, Eff.memFail, Eff.fails] using ht⟩
  · rintro ⟨i, hi, ht⟩
    cases hf : es[i]? with
    | none => simp [rowImage, hf, singleton] at ht
    | some f => exact ⟨i, f, hf, hi, by cases f; simpa [rowImage, hf, Eff.memFail, Eff.fails] using ht⟩

theorem bind_row (τ : Nat → Nat) (es : List Eff) (i : Nat) :
    bind τ es (singleton (.rho i)) = norm (rowImage es i) := by
  apply norm_ext
  · intro a
    change (rawBind τ es (singleton (.rho i))).mem a ↔ (rowImage es i).mem a
    rw [← mem_norm (rawBind τ es (singleton (.rho i))) a]
    change (bind τ es (singleton (.rho i))).mem a ↔ _
    rw [mem_bind]
    simp only [mem_singleton, Atom.rho.injEq]
    cases a <;> simp [Ground]
  · intro t
    rw [← memFail_norm (rawBind τ es (singleton (.rho i))) t]
    change (bind τ es (singleton (.rho i))).memFail t ↔ _
    rw [memFail_bind]
    simp only [mem_singleton, Atom.rho.injEq]
    simp [singleton, Eff.memFail, Eff.fails]

-- Representative substitution/union theorem from TypeComposition.bind_union.
theorem bind_union (τ : Nat → Nat) (es : List Eff) (e f : Eff) :
    bind τ es (union e f) = union (bind τ es e) (bind τ es f) := by
  apply eq_of_exactSub_of_exactSub (e := bind τ es (union e f))
    (f := union (bind τ es e) (bind τ es f)) (norm_idem _) (norm_idem _)
  all_goals constructor
  all_goals intro x hx
  all_goals simp only [mem_bind, memFail_bind, mem_union, memFail_union] at hx ⊢
  all_goals grind only

-- Exact algebra survives even though scope-aware mutual Sub no longer means =.
def composeRows (τ : Nat → Nat) (es fs : List Eff) : List Eff :=
  (List.range (max es.length fs.length)).map (fun i => bind τ fs (rowImage es i))

theorem rowImage_compose (τ : Nat → Nat) (es fs : List Eff) (i : Nat) :
    rowImage (composeRows τ es fs) i = bind τ fs (rowImage es i) := by
  by_cases hi : i < max es.length fs.length
  · simp [rowImage, composeRows, List.getElem?_map, List.getElem?_range hi]
  · have he : es.length ≤ i := by omega
    have hf : fs.length ≤ i := by omega
    have hc : (composeRows τ es fs)[i]? = none :=
      List.getElem?_eq_none (by simpa [composeRows] using Nat.le_of_not_gt hi)
    rw [rowImage, hc, Option.getD_none, rowImage, List.getElem?_eq_none he,
      Option.getD_none, bind_row, rowImage, List.getElem?_eq_none hf, Option.getD_none]
    rfl

-- Representative composition theorem: TypeComposition.Eff.bind_comp_of_types.
-- Its recursive premise about Fail types is replaced by literal function composition.
theorem bind_comp (σ τ : Nat → Nat) (es fs : List Eff) (e : Eff) :
    bind τ fs (bind σ es e) = bind (τ ∘ σ) (composeRows τ es fs) e := by
  apply eq_of_exactSub_of_exactSub (e := bind τ fs (bind σ es e))
    (f := bind (τ ∘ σ) (composeRows τ es fs) e) (norm_idem _) (norm_idem _)
  all_goals constructor
  all_goals intro x hx
  all_goals simp only [mem_bind, memFail_bind, rowImage_compose, Function.comp_apply] at hx ⊢
  all_goals try grind only [Ground]

-- Finite support is still syntactic, and needs no downward closure.
def Support (s : List Atom) (e : Eff) : Prop := ∀ a, e.mem a → a ∈ s

-- Concrete counterexample to the original eq_of_sub_of_sub under scope-aware Sub.
def broad : ClosedScope := ⟨⟨.write, .tree ["data"] 0, ⟨0, 65535⟩⟩, by decide, by decide⟩
def narrow : ClosedScope := ⟨⟨.write, .exact ["data", "b"], ⟨0, 65535⟩⟩, by decide, by decide⟩
def wide : Eff := singleton (.bounded broad)
def redundant : Eff := union wide (singleton (.bounded narrow))

#guard atomLe (.bounded narrow) (.bounded broad)
#guard !(atomLe (.bounded broad) (.bounded narrow))
#guard atomLe (.bounded broad) (.name .write)
#guard !(atomLe (.name .write) (.bounded broad))

theorem mutual_sub_neq : Canonical wide ∧ Canonical redundant ∧
    Sub wide redundant ∧ Sub redundant wide ∧ wide ≠ redundant := by
  refine ⟨rfl, union_canonical _ _, ?_, ?_, ?_⟩
  · constructor
    · intro a ha
      exact ⟨a, (mem_union _ _ _).mpr (Or.inl ha), atomLe_refl a⟩
    · intro t ht; simp [wide, singleton, Eff.memFail, Eff.fails] at ht
  · constructor
    · intro a ha
      rcases (mem_union _ _ _).mp ha with ha | ha
      · exact ⟨a, ha, atomLe_refl a⟩
      · have he : a = .bounded narrow := (mem_singleton _ _).mp ha
        subst a
        exact ⟨.bounded broad, (mem_singleton _ _).mpr rfl, by decide⟩
    · intro t ht; simp [redundant, wide, singleton, Eff.memFail, Eff.fails, union, norm, rawUnion] at ht
  · intro he
    have hn : redundant.mem (.bounded narrow) := (mem_union _ _ _).mpr
      (Or.inr ((mem_singleton _ _).mpr rfl))
    rw [← he] at hn
    have he' := (mem_singleton _ _).mp hn
    have : narrow = broad := Atom.bounded.inj he'
    have hp := congrArg (fun s => s.scope.pattern) this
    cases hp

end Structural

namespace Maximal
open Structural (Sub sub_refl sub_trans)

def IsMax (e : Eff) (a : Atom) : Prop :=
  e.mem a ∧ ∀ b, e.mem b → atomLe a b = true → atomLe b a = true

-- Mathematical norm on arbitrary Atom -> Bool, retaining only maximal generators.
-- No finite-support assumption is used. The decreasing rank proves coverage.
noncomputable def norm (e : Eff) : Eff :=
  .mk (fun a => @decide (IsMax e a) (Classical.propDecidable _))
    (Structural.norm e).fails

def Canonical (e : Eff) : Prop := norm e = e

theorem mem_norm (e : Eff) (a : Atom) : (norm e).mem a ↔ IsMax e a := by
  simp only [norm, Eff.mem, Eff.atoms, decide_eq_true_eq]

theorem memFail_norm (e : Eff) (t : Nat) : (norm e).memFail t ↔ e.memFail t :=
  Structural.memFail_norm e t

theorem exists_max (e : Eff) (a : Atom) (ha : e.mem a) :
    ∃ b, IsMax e b ∧ atomLe a b = true := by
  classical
  have go : ∀ n a, atomRank a = n → e.mem a → ∃ b, IsMax e b ∧ atomLe a b = true := by
    intro n
    induction n using Nat.strongRecOn with
    | ind n ih =>
      intro a hr ha
      by_cases hm : ∀ b, e.mem b → atomLe a b = true → atomLe b a = true
      · exact ⟨a, ⟨ha, hm⟩, atomLe_refl a⟩
      · have hex : ∃ b, e.mem b ∧ atomLe a b = true ∧ atomLe b a ≠ true := by
          apply Classical.byContradiction
          intro hn
          apply hm
          intro b hb hab
          apply Classical.byContradiction
          intro hba
          exact hn ⟨b, hb, hab, hba⟩
        obtain ⟨b, hb, hab, hba⟩ := hex
        have hn := atomLe_strict_rank hab hba
        obtain ⟨c, hc, hbc⟩ := ih (atomRank b) (by omega) b rfl hb
        exact ⟨c, hc, atomLe_trans hab hbc⟩
  exact go (atomRank a) a rfl ha

theorem norm_sub (e : Eff) : Sub (norm e) e := by
  constructor
  · intro a ha
    exact ⟨a, ((mem_norm e a).mp ha).1, atomLe_refl a⟩
  · intro t ht; exact (memFail_norm e t).mp ht

theorem sub_norm (e : Eff) : Sub e (norm e) := by
  constructor
  · intro a ha
    obtain ⟨b, hb, hab⟩ := exists_max e a ha
    exact ⟨b, (mem_norm e b).mpr hb, hab⟩
  · intro t ht; exact (memFail_norm e t).mpr ht

def Antichain (e : Eff) : Prop :=
  ∀ a b, e.mem a → e.mem b → atomLe a b = true → a = b

theorem antichain_norm (e : Eff) : Antichain (norm e) := by
  intro a b ha hb hab
  have ha := (mem_norm e a).mp ha
  have hb := (mem_norm e b).mp hb
  exact atomLe_antisymm hab (ha.2 b hb.1 hab)

theorem structural_canonical_norm (e : Eff) : Structural.Canonical (norm e) := by
  unfold Structural.Canonical
  apply Eff.ext
  · intro a; rfl
  · change Order.sortUnique compare (Order.sortUnique compare e.fails) = Order.sortUnique compare e.fails
    exact Order.sortUnique_idem _

-- The order-theoretic reason that maximal generators are unique.
theorem exactSub_of_antichain {e f : Eff} (he : Antichain e)
    (h : Sub e f) (g : Sub f e) : Structural.ExactSub e f := by
  refine ⟨?_, h.2⟩
  intro a ha
  obtain ⟨b, hb, hab⟩ := h.1 a ha
  obtain ⟨c, hc, hbc⟩ := g.1 b hb
  have hac := he a c ha hc (atomLe_trans hab hbc)
  subst c
  have hab' := atomLe_antisymm hab hbc
  simpa only [hab'] using hb

theorem eq_of_antichain_sub {e f : Eff} (he : Antichain e) (hf : Antichain f)
    (hce : Structural.Canonical e) (hcf : Structural.Canonical f)
    (h : Sub e f) (g : Sub f e) : e = f :=
  Structural.eq_of_exactSub_of_exactSub hce hcf
    (exactSub_of_antichain he h g) (exactSub_of_antichain hf g h)

theorem norm_idem (e : Eff) : norm (norm e) = norm e := by
  exact eq_of_antichain_sub (antichain_norm _) (antichain_norm _)
    (structural_canonical_norm _) (structural_canonical_norm _)
    (norm_sub _) (sub_norm _)

-- Same interface and conclusion as Release/Effect.eq_of_sub_of_sub, with new norm.
theorem eq_of_sub_of_sub {e f : Eff} (he : Canonical e) (hf : Canonical f)
    (h : Sub e f) (g : Sub f e) : e = f := by
  rw [← he, ← hf]
  exact eq_of_antichain_sub (antichain_norm _) (antichain_norm _)
    (structural_canonical_norm _) (structural_canonical_norm _)
    (sub_trans (norm_sub e) (sub_trans h (sub_norm f)))
    (sub_trans (norm_sub f) (sub_trans g (sub_norm e)))

theorem norm_eq_of_mutual {e f : Eff} (h : Sub e f) (g : Sub f e) : norm e = norm f :=
  eq_of_sub_of_sub (norm_idem _) (norm_idem _)
    (sub_trans (norm_sub _) (sub_trans h (sub_norm _)))
    (sub_trans (norm_sub _) (sub_trans g (sub_norm _)))

-- Arbitrary input order and redundant generators have no effect on the result.
theorem redundant_removed : norm Structural.redundant = norm Structural.wide :=
  norm_eq_of_mutual Structural.mutual_sub_neq.2.2.2.1 Structural.mutual_sub_neq.2.2.1

theorem norm_support (s : List Atom) (e : Eff) (h : Structural.Support s e) :
    Structural.Support s (norm e) :=
  fun a ha => h a ((mem_norm e a).mp ha).1

-- A finite-support implementation tests maximality only on the support list.
-- The result agrees on ALL atoms, not merely on the supplied support.
def normAtomsWith (s : List Atom) (e : Eff) (a : Atom) : Bool :=
  e.atoms a && !(s.any (fun b => e.atoms b && atomLe a b && !(atomLe b a)))

theorem normAtomsWith_eq (s : List Atom) (e : Eff) (hs : Structural.Support s e) :
    normAtomsWith s e = (norm e).atoms := by
  funext a
  apply Bool.eq_iff_iff.mpr
  change normAtomsWith s e a = true ↔ (norm e).mem a
  rw [mem_norm]
  simp only [normAtomsWith, Bool.and_eq_true, Bool.not_eq_true', List.any_eq_false,
    IsMax]
  constructor
  · rintro ⟨ha, hm⟩
    refine ⟨ha, ?_⟩
    intro b hb hab
    have hm := hm b (hs b hb)
    simpa [hb, hab, Eff.mem] using hm
  · rintro ⟨ha, hm⟩
    refine ⟨ha, ?_⟩
    intro b hb
    by_cases he : e.mem b
    · by_cases hab : atomLe a b = true
      · simp [Eff.mem] at he
        simp [he, hab, hm b he hab]
      · simp [hab]
    · simp [Eff.mem] at he
      simp [he]

end Maximal

namespace Structural

theorem ground_le {a b : Atom} (hg : Ground a) (h : atomLe a b = true) : Ground b := by
  cases a <;> cases b <;> simp_all [Ground, atomLe]

theorem rho_le {i : Nat} {b : Atom} (h : atomLe (.rho i) b = true) : b = .rho i := by
  cases b <;> simp_all [atomLe]

-- Input monotonicity for semantic containment. No equality of generators is used.
theorem bind_mono (τ : Nat → Nat) (es : List Eff) {e f : Eff} (h : Sub e f) :
    Sub (bind τ es e) (bind τ es f) := by
  constructor
  · intro a ha
    rcases (mem_bind τ es e a).mp ha with ⟨hg, he⟩ | ⟨i, hi, ha⟩
    · obtain ⟨b, hb, hab⟩ := h.1 a he
      exact ⟨b, (mem_bind τ es f b).mpr (Or.inl ⟨ground_le hg hab, hb⟩), hab⟩
    · obtain ⟨b, hb, hib⟩ := h.1 (.rho i) hi
      have heq := rho_le hib
      subst b
      exact ⟨a, (mem_bind τ es f a).mpr (Or.inr ⟨i, hb, ha⟩), atomLe_refl a⟩
  · intro t ht
    apply (memFail_bind τ es f t).mpr
    rcases (memFail_bind τ es e t).mp ht with ⟨x, hx, hxt⟩ | ⟨i, hi, ht⟩
    · exact Or.inl ⟨x, h.2 x hx, hxt⟩
    · obtain ⟨b, hb, hib⟩ := h.1 (.rho i) hi
      have heq := rho_le hib
      subst b
      exact Or.inr ⟨i, hb, ht⟩

-- Environment monotonicity observes out-of-range identity rows as well.
theorem bind_env_mono (τ : Nat → Nat) (es fs : List Eff) (e : Eff)
    (h : ∀ i, Sub (rowImage es i) (rowImage fs i)) :
    Sub (bind τ es e) (bind τ fs e) := by
  constructor
  · intro a ha
    rcases (mem_bind τ es e a).mp ha with ⟨hg, he⟩ | ⟨i, hi, ha⟩
    · exact ⟨a, (mem_bind τ fs e a).mpr (Or.inl ⟨hg, he⟩), atomLe_refl a⟩
    · obtain ⟨b, hb, hab⟩ := (h i).1 a ha
      exact ⟨b, (mem_bind τ fs e b).mpr (Or.inr ⟨i, hi, hb⟩), hab⟩
  · intro t ht
    apply (memFail_bind τ fs e t).mpr
    rcases (memFail_bind τ es e t).mp ht with ⟨x, hx, hxt⟩ | ⟨i, hi, ht⟩
    · exact Or.inl ⟨x, hx, hxt⟩
    · exact Or.inr ⟨i, hi, (h i).2 t ht⟩

theorem union_mono {a b c d : Eff} (h : Sub a c) (g : Sub b d) :
    Sub (union a b) (union c d) := by
  constructor
  · intro x hx
    rcases (mem_union _ _ _).mp hx with hx | hx
    · obtain ⟨y, hy, hxy⟩ := h.1 x hx
      exact ⟨y, (mem_union _ _ _).mpr (Or.inl hy), hxy⟩
    · obtain ⟨y, hy, hxy⟩ := g.1 x hx
      exact ⟨y, (mem_union _ _ _).mpr (Or.inr hy), hxy⟩
  · intro t ht
    apply (memFail_union _ _ _).mpr
    exact ((memFail_union _ _ _).mp ht).elim
      (fun hx => Or.inl (h.2 t hx)) (fun hx => Or.inr (g.2 t hx))

theorem bind_norm (τ : Nat → Nat) (es : List Eff) (e : Eff) :
    bind τ es (norm e) = bind τ es e := by
  apply eq_of_exactSub_of_exactSub (e := bind τ es (norm e)) (f := bind τ es e)
    (norm_idem _) (norm_idem _)
  all_goals constructor
  all_goals intro x hx
  all_goals simpa only [mem_bind, memFail_bind, mem_norm, memFail_norm] using hx

end Structural

namespace Maximal
open Structural (Sub sub_refl sub_trans)

noncomputable def union (e f : Eff) : Eff := norm (Structural.union e f)
noncomputable def bind (τ : Nat → Nat) (es : List Eff) (e : Eff) : Eff :=
  norm (Structural.bind τ es e)
noncomputable def composeRows (τ : Nat → Nat) (es fs : List Eff) : List Eff :=
  (Structural.composeRows τ es fs).map norm

-- Normalization commutes with union, with a final normalization on both sides.
theorem norm_union (e f : Eff) :
    norm (Structural.union (norm e) (norm f)) = norm (Structural.union e f) :=
  norm_eq_of_mutual (Structural.union_mono (norm_sub _) (norm_sub _))
    (Structural.union_mono (sub_norm _) (sub_norm _))

theorem norm_union_right (e f : Eff) :
    norm (Structural.union e (norm f)) = norm (Structural.union e f) :=
  norm_eq_of_mutual (Structural.union_mono (sub_refl _) (norm_sub _))
    (Structural.union_mono (sub_refl _) (sub_norm _))

-- Representative union theorem from Surface/Lemmas/Sequence.
theorem union_empty_right_nested (a b : Eff) :
    union a (union b Structural.empty) = union a b := by
  unfold union
  rw [norm_union_right, Structural.union_empty_right_nested]

-- Normalization and substitution commute after final normalization.
theorem norm_bind (τ : Nat → Nat) (es : List Eff) (e : Eff) :
    norm (Structural.bind τ es (norm e)) = norm (Structural.bind τ es e) :=
  norm_eq_of_mutual (Structural.bind_mono τ es (norm_sub _))
    (Structural.bind_mono τ es (sub_norm _))

theorem rowImage_map_norm (es : List Eff) (i : Nat) :
    Sub (Structural.rowImage (es.map norm) i) (Structural.rowImage es i) ∧
    Sub (Structural.rowImage es i) (Structural.rowImage (es.map norm) i) := by
  cases he : es[i]? with
  | none =>
    simp only [Structural.rowImage, List.getElem?_map, he, Option.map_none, Option.getD_none]
    exact ⟨sub_refl _, sub_refl _⟩
  | some e =>
    simp only [Structural.rowImage, List.getElem?_map, he, Option.map_some, Option.getD_some]
    exact ⟨norm_sub _, sub_norm _⟩

theorem norm_bind_rows (τ : Nat → Nat) (es : List Eff) (e : Eff) :
    norm (Structural.bind τ (es.map norm) e) = norm (Structural.bind τ es e) :=
  norm_eq_of_mutual
    (Structural.bind_env_mono τ _ _ e (fun i => (rowImage_map_norm es i).1))
    (Structural.bind_env_mono τ _ _ e (fun i => (rowImage_map_norm es i).2))

-- A formulation including normalization of both the input and the row images.
theorem norm_rawBind (τ : Nat → Nat) (es : List Eff) (e : Eff) :
    norm (Structural.rawBind τ (es.map norm) (norm e)) = norm (Structural.rawBind τ es e) := by
  have hstruct (x : Eff) : norm (Structural.norm x) = norm x :=
    norm_eq_of_mutual (Structural.norm_sub x) (Structural.sub_norm x)
  rw [← hstruct (Structural.rawBind τ (es.map norm) (norm e)),
    ← hstruct (Structural.rawBind τ es e)]
  change norm (Structural.bind τ (es.map norm) (norm e)) = norm (Structural.bind τ es e)
  rw [norm_bind, norm_bind_rows]

-- Representative composition theorem. Its conclusion remains literal equality.
theorem bind_comp (σ τ : Nat → Nat) (es fs : List Eff) (e : Eff) :
    bind τ fs (bind σ es e) = bind (τ ∘ σ) (composeRows τ es fs) e := by
  unfold bind composeRows
  rw [norm_bind, Structural.bind_comp, norm_bind_rows]

-- Representative substitution/union theorem. No weakening to Sub is needed.
theorem bind_union (τ : Nat → Nat) (es : List Eff) (e f : Eff) :
    bind τ es (union e f) = union (bind τ es e) (bind τ es f) := by
  unfold bind union
  rw [norm_bind, Structural.bind_union, norm_union]

-- Redundancy may arise only after substituting two independent rows.
-- This check uses the computational finite-support normalizer, not Classical.decide.
def afterRows : Eff := Structural.bind id
  [Structural.wide, Structural.singleton (.bounded Structural.narrow)]
  (Structural.union (Structural.singleton (.rho 0)) (Structural.singleton (.rho 1)))
#guard normAtomsWith [.bounded Structural.broad, .bounded Structural.narrow]
  afterRows (.bounded Structural.broad)
#guard !(normAtomsWith [.bounded Structural.broad, .bounded Structural.narrow]
  afterRows (.bounded Structural.narrow))

#print axioms eq_of_sub_of_sub
#print axioms norm_idem
#print axioms normAtomsWith_eq
#print axioms norm_rawBind
#print axioms bind_comp
#print axioms bind_union
#print axioms union_empty_right_nested
end Maximal

#print axioms Structural.mutual_sub_neq
#print axioms Structural.bind_comp
#print axioms Structural.bind_union
#print axioms Structural.union_empty_right_nested

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

theorem maximal_norm_denote (rows : Nat → Event → Prop) (e : Eff) (ev : Event) :
    Denote rows (Maximal.norm e) ev ↔ Denote rows e ev :=
  ⟨sub_sound (Maximal.norm_sub e) rows ev, sub_sound (Maximal.sub_norm e) rows ev⟩

theorem denote_singleton (rows : Nat → Event → Prop) (a : Atom) (ev : Event) :
    Denote rows (Structural.singleton a) ev ↔ DenoteAtom rows a ev := by
  simp [Denote, Structural.mem_singleton]

theorem denote_union (rows : Nat → Event → Prop) (e f : Eff) (ev : Event) :
    Denote rows (Structural.union e f) ev ↔ Denote rows e ev ∨ Denote rows f ev := by
  simp [Denote, Structural.mem_union, or_and_right, exists_or]

namespace Limits

def ten : ClosedScope := ⟨⟨.tcp, .exact ["api"], ⟨0, 9⟩⟩, by decide, by decide⟩
def low : ClosedScope := ⟨⟨.tcp, .exact ["api"], ⟨0, 4⟩⟩, by decide, by decide⟩
def high : ClosedScope := ⟨⟨.tcp, .exact ["api"], ⟨5, 9⟩⟩, by decide, by decide⟩
def full : Eff := Structural.singleton (.bounded ten)
def split : Eff := Structural.union (Structural.singleton (.bounded low)) (Structural.singleton (.bounded high))

theorem split_denote (rows : Nat → Event → Prop) (ev : Event) :
    Denote rows full ev ↔ Denote rows split ev := by
  rw [full, split, denote_union, denote_singleton, denote_singleton, denote_singleton]
  simp only [DenoteAtom, Allows, ten, low, high, InPort]
  constructor
  · rintro ⟨hk, hp, hl, hh⟩
    by_cases h : ev.port ≤ 4
    · exact Or.inl ⟨hk, hp, hl, h⟩
    · exact Or.inr ⟨hk, hp, by omega, hh⟩
  · rintro (⟨hk, hp, hl, hh⟩ | ⟨hk, hp, hl, hh⟩)
    · exact ⟨hk, hp, hl, by omega⟩
    · exact ⟨hk, hp, by omega, hh⟩

theorem split_not_sub : ¬ Structural.Sub full split := by
  intro h
  obtain ⟨b, hb, hab⟩ := h.1 (.bounded ten) ((Structural.mem_singleton _ _).mpr rfl)
  rcases (Structural.mem_union _ _ _).mp hb with hb | hb
  · have he := (Structural.mem_singleton _ _).mp hb
    subst b
    have hn : atomLe (.bounded ten) (.bounded low) = false := by decide
    simp [hn] at hab
  · have he := (Structural.mem_singleton _ _).mp hb
    subst b
    have hn : atomLe (.bounded ten) (.bounded high) = false := by decide
    simp [hn] at hab

theorem semantic_eq_not_norm_eq : Maximal.norm full ≠ Maximal.norm split := by
  intro heq
  have h := Maximal.sub_norm full
  rw [heq] at h
  exact split_not_sub (Structural.sub_trans h (Maximal.norm_sub split))

-- Old mem_norm and mem_union statements fail for maximal normalization.
theorem narrow_absorbed : ¬ (Maximal.norm Structural.redundant).mem (.bounded Structural.narrow) := by
  intro h
  have hm := (Maximal.mem_norm _ _).mp h
  have hb : Structural.redundant.mem (.bounded Structural.broad) :=
    (Structural.mem_union _ _ _).mpr (Or.inl ((Structural.mem_singleton _ _).mpr rfl))
  have bad := hm.2 (.bounded Structural.broad) hb (by decide)
  have hn : atomLe (.bounded Structural.broad) (.bounded Structural.narrow) = false := by decide
  simp [hn] at bad

-- A final normalization cannot be omitted after row substitution.
#guard Maximal.afterRows.atoms (.bounded Structural.narrow)

#print axioms split_denote
#print axioms split_not_sub
#print axioms semantic_eq_not_norm_eq
#print axioms narrow_absorbed
end Limits

#print axioms patLe_antisymm
#print axioms closedScope_antisymm
#print axioms atomLe_strict_rank
#print axioms sub_sound
#print axioms maximal_norm_denote

namespace Structural
-- The special bottom-effect equality needed by no-event proofs is still valid.
theorem sub_empty {e : Eff} (h : Sub e empty) : e = empty := by
  apply Eff.ext
  · intro a
    constructor
    · intro ha
      obtain ⟨b, hb, _⟩ := h.1 a ha
      exact False.elim ((mem_empty b).mp hb)
    · intro ha; exact False.elim ((mem_empty a).mp ha)
  · cases he : e.fails with
    | nil => rfl
    | cons t ts =>
      have ht : e.memFail t := by change t ∈ e.fails; rw [he]; exact List.mem_cons_self
      exact False.elim ((memFail_empty t).mp (h.2 t ht))
end Structural

namespace Maximal
-- On the old name/rho domain the maximal-atom normalizer changes nothing.
-- Arbitrary, including infinitely supported, membership functions are permitted.
theorem norm_without_bounded (e : Eff) (h : ∀ s, ¬ e.mem (.bounded s)) :
    norm e = Structural.norm e := by
  apply Eff.ext
  · intro a
    rw [mem_norm]
    change IsMax e a ↔ e.mem a
    constructor
    · exact fun ha => ha.1
    · intro ha
      refine ⟨ha, ?_⟩
      intro b hb hab
      cases a with
      | bounded s => exact False.elim (h s ha)
      | name k => cases b <;> simp_all [atomLe]
      | rho i => cases b <;> simp_all [atomLe]
  · rfl
#print axioms norm_without_bounded
end Maximal
#print axioms Structural.sub_empty
end SA
