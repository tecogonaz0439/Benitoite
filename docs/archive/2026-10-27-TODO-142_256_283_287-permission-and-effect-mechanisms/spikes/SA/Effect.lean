import Std

/-!
Disposable TODO-142 spike. Independent of Benitoite and its concurrent L1b work.
Only normalized component lists are modeled; no DNS, URL, filesystem, or parser.
`tree s 0` models terminal path /**; `tree (reverse suffix) 1` models
a host wildcard accepting one or more extra labels, excluding the apex.
-/
namespace SA.Scope142

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


end SA.Scope142

/- Copied scope decision procedures above: TODO-142 Scope.lean,
   Word/Pattern/Matches/patLe/Interval/portLe/Scope/scopeLe and their proofs.
   The following finite normalization is new for SA. -/
namespace SA
open Scope142

theorem patLe_antisymm {a b : Pattern} (h : patLe a b = true)
    (g : patLe b a = true) : a = b := by
  cases a with
  | exact a =>
    cases b with
    | exact b => exact congrArg Pattern.exact (show b = a from of_decide_eq_true h).symm
    | tree b l => simp [patLe] at g
  | tree a k =>
    cases b with
    | exact b => simp [patLe] at h
    | tree b l =>
      have h : b.IsPrefix a ∧ b.length + l ≤ a.length + k := of_decide_eq_true h
      have g : a.IsPrefix b ∧ a.length + k ≤ b.length + l := of_decide_eq_true g
      have hab : a = b := List.IsPrefix.eq_of_length g.1 (Nat.le_antisymm g.1.length_le h.1.length_le)
      subst b
      have : k = l := by omega
      subst l
      rfl

theorem portLe_antisymm {a b : Interval} (ha : a.lo ≤ a.hi) (hb : b.lo ≤ b.hi)
    (h : portLe a b = true) (g : portLe b a = true) : a = b := by
  have h : a.hi < a.lo ∨ (b.lo ≤ a.lo ∧ a.hi ≤ b.hi) := of_decide_eq_true h
  have g : b.hi < b.lo ∨ (a.lo ≤ b.lo ∧ b.hi ≤ a.hi) := of_decide_eq_true g
  have hl : a.lo = b.lo := by omega
  have hh : a.hi = b.hi := by omega
  cases a; cases b; simp_all

theorem scopeLe_antisymm {a b : Scope} (ha : a.ports.lo ≤ a.ports.hi)
    (hb : b.ports.lo ≤ b.ports.hi)
    (h : scopeLe a b = true) (g : scopeLe b a = true) : a = b := by
  simp only [scopeLe, Bool.and_eq_true, decide_eq_true_eq] at h g
  have hp := patLe_antisymm h.1.2 g.1.2
  have hr := portLe_antisymm ha hb h.2 g.2
  cases a; cases b; simp_all

-- The original port syntax is a preorder, not a partial order.
-- Small arithmetic only; no large kernel computation.
theorem empty_ports_not_antisymm :
    ∃ a b : Interval, a ≠ b ∧ portLe a b = true ∧ portLe b a = true := by
  exact ⟨⟨1, 0⟩, ⟨2, 0⟩, by decide, by decide, by decide⟩

-- Generic finite antichain normalization. No assumptions are added as axioms:
-- reflexivity/transitivity/antisymmetry are parameters proved for our atoms below.
namespace Finite
variable {α : Type} (le : α → α → Bool)

def Cover (xs ys : List α) : Prop := ∀ a ∈ xs, ∃ b ∈ ys, le a b = true
def Irredundant (xs : List α) : Prop :=
  ∀ a ∈ xs, ∀ b ∈ xs, le a b = true → a = b

def insert (a : α) (xs : List α) : List α :=
  if xs.any (le a) then xs else a :: xs.filter (fun b => !(le b a))

def norm : List α → List α
  | [] => []
  | a :: xs => insert le a (norm xs)

variable (refl : ∀ a, le a a = true)
variable (trans : ∀ {a b c}, le a b = true → le b c = true → le a c = true)

include refl in
theorem cover_refl (xs : List α) : Cover le xs xs := fun a ha => ⟨a, ha, refl a⟩

include trans in
theorem cover_trans {xs ys zs : List α} (h : Cover le xs ys) (g : Cover le ys zs) :
    Cover le xs zs := by
  intro a ha
  obtain ⟨b, hb, hab⟩ := h a ha
  obtain ⟨c, hc, hbc⟩ := g b hb
  exact ⟨c, hc, trans hab hbc⟩

include refl in
theorem insert_cover (a : α) (xs : List α) : Cover le (a :: xs) (insert le a xs) := by
  unfold insert
  split
  · rename_i h
    obtain ⟨b, hb, hab⟩ := List.any_eq_true.mp h
    intro c hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact ⟨b, hb, hab⟩
    · exact ⟨c, hc, refl c⟩
  · intro c hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact ⟨c, by simp, refl c⟩
    · by_cases hca : le c a = true
      · exact ⟨a, by simp, hca⟩
      · exact ⟨c, by simp [hc, hca], refl c⟩

theorem insert_subset (a : α) (xs : List α) :
    ∀ c ∈ insert le a xs, c ∈ a :: xs := by
  unfold insert
  split
  · intro c hc; exact List.mem_cons_of_mem _ hc
  · intro c hc
    rcases List.mem_cons.mp hc with rfl | hc
    · simp
    · exact List.mem_cons_of_mem _ (List.mem_filter.mp hc).1

include refl trans in
theorem norm_cover (xs : List α) : Cover le xs (norm le xs) := by
  induction xs with
  | nil => intro a ha; cases ha
  | cons a xs ih =>
    apply cover_trans le trans (ys := a :: norm le xs) _ (insert_cover le refl a _)
    intro c hc
    rcases List.mem_cons.mp hc with rfl | hc
    · exact ⟨c, by simp, refl c⟩
    · obtain ⟨b, hb, hcb⟩ := ih c hc
      exact ⟨b, List.mem_cons_of_mem _ hb, hcb⟩

theorem norm_subset (xs : List α) : ∀ a ∈ norm le xs, a ∈ xs := by
  induction xs with
  | nil => simp [norm]
  | cons a xs ih =>
    intro c hc
    rcases List.mem_cons.mp (insert_subset le a _ c hc) with rfl | hc
    · simp
    · exact List.mem_cons_of_mem _ (ih c hc)

include refl in
theorem norm_sub (xs : List α) : Cover le (norm le xs) xs :=
  fun a ha => ⟨a, norm_subset le xs a ha, refl a⟩

theorem insert_irredundant (a : α) {xs : List α} (h : Irredundant le xs) :
    Irredundant le (insert le a xs) := by
  unfold insert
  split
  · exact h
  · rename_i hn
    intro b hb c hc hbc
    rcases List.mem_cons.mp hb with rfl | hb
    · rcases List.mem_cons.mp hc with rfl | hc
      · rfl
      · have hc := List.mem_filter.mp hc
        have : xs.any (le b) = true := List.any_eq_true.mpr ⟨c, hc.1, hbc⟩
        contradiction
    · have hb := List.mem_filter.mp hb
      rcases List.mem_cons.mp hc with rfl | hc
      · simp [hbc] at hb
      · exact h b hb.1 c (List.mem_filter.mp hc).1 hbc

theorem norm_irredundant (xs : List α) : Irredundant le (norm le xs) := by
  induction xs with
  | nil => simp [norm, Irredundant]
  | cons a xs ih => exact insert_irredundant le a ih

variable (antisymm : ∀ {a b}, le a b = true → le b a = true → a = b)

include trans antisymm in
theorem ext_irredundant {xs ys : List α} (hx : Irredundant le xs)
    (hy : Irredundant le ys) (h : Cover le xs ys) (g : Cover le ys xs) :
    ∀ a, a ∈ xs ↔ a ∈ ys := by
  have one : ∀ {xs ys : List α}, Irredundant le xs → Cover le xs ys → Cover le ys xs →
      ∀ a ∈ xs, a ∈ ys := by
    intro xs ys hx h g a ha
    obtain ⟨b, hb, hab⟩ := h a ha
    obtain ⟨c, hc, hbc⟩ := g b hb
    have hac : a = c := hx a ha c hc (trans hab hbc)
    subst c
    have hab' : a = b := antisymm hab hbc
    simpa [hab'] using hb
  exact fun a => ⟨one hx h g a, one hy g h a⟩

include refl trans antisymm in
theorem norm_ext {xs ys : List α} (h : Cover le xs ys) (g : Cover le ys xs) :
    ∀ a, a ∈ norm le xs ↔ a ∈ norm le ys := by
  apply ext_irredundant le trans antisymm (norm_irredundant le xs) (norm_irredundant le ys)
  · exact cover_trans le trans (cover_trans le trans (norm_sub le refl xs) h)
      (norm_cover le refl trans ys)
  · exact cover_trans le trans (cover_trans le trans (norm_sub le refl ys) g)
      (norm_cover le refl trans xs)

end Finite
end SA

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
open Scope142

-- Closed scopes are type-independent, as required by Release/Atom.lean.
structure EffName where
  label : String
  scope : Option Scope
  deriving DecidableEq, Repr

inductive Atom where
  | name (l : EffName)
  | rho (i : Nat)
  deriving DecidableEq, Repr

def nameLe (a b : EffName) : Bool :=
  decide (a.label = b.label) && match a.scope, b.scope with
    | _, none => true
    | none, some _ => false
    | some s, some t => scopeLe s t

def atomLe : Atom → Atom → Bool
  | .name a, .name b => nameLe a b
  | .rho i, .rho j => decide (i = j)
  | _, _ => false

theorem nameLe_refl (a : EffName) : nameLe a a = true := by
  cases a with
  | mk l s => cases s <;> simp [nameLe, scopeLe_refl]

theorem nameLe_trans {a b c : EffName} (h : nameLe a b = true)
    (g : nameLe b c = true) : nameLe a c = true := by
  rcases a with ⟨a, sa⟩; rcases b with ⟨b, sb⟩; rcases c with ⟨c, sc⟩
  simp only [nameLe, Bool.and_eq_true, decide_eq_true_eq] at h g ⊢
  refine ⟨h.1.trans g.1, ?_⟩
  cases sa <;> cases sb <;> cases sc <;> simp_all
  exact scopeLe_trans h.2 g.2

theorem atomLe_refl (a : Atom) : atomLe a a = true := by
  cases a <;> simp [atomLe, nameLe_refl]

theorem atomLe_trans {a b c : Atom} (h : atomLe a b = true)
    (g : atomLe b c = true) : atomLe a c = true := by
  cases a <;> cases b <;> cases c <;> simp_all [atomLe]
  exact nameLe_trans h g

def Atom.WF : Atom → Prop
  | .rho _ => True
  | .name ⟨_, none⟩ => True
  | .name ⟨_, some s⟩ => s.ports.lo ≤ s.ports.hi

theorem atomLe_antisymm {a b : Atom} (ha : a.WF) (hb : b.WF)
    (h : atomLe a b = true) (g : atomLe b a = true) : a = b := by
  cases a with
  | rho i => cases b <;> simp_all [atomLe]
  | name a =>
    cases b with
    | rho j => simp [atomLe] at h
    | name b =>
      rcases a with ⟨a, sa⟩; rcases b with ⟨b, sb⟩
      simp only [atomLe, nameLe, Bool.and_eq_true, decide_eq_true_eq] at h g
      have hab := h.1
      subst b
      cases sa with
      | none => cases sb <;> simp_all
      | some s =>
        cases sb with
        | none => simp at g
        | some t =>
          have hst := scopeLe_antisymm ha hb h.2 g.2
          subst t
          rfl

-- Copy of Release/Types.lean EffR.mk/atoms/fails/ext, with the Fail error
-- type replaced by Nat. This isolates the effect algebra; recursive Ty.norm
-- and Ty.bind obligations are NOT claimed to be proved in this model.
inductive Eff where
  | mk (atoms : Atom → Bool) (fails : List Nat)

namespace Eff
open Order

def atoms : Eff → Atom → Bool | .mk a _ => a
def fails : Eff → List Nat | .mk _ fs => fs
abbrev mem (e : Eff) (a : Atom) : Prop := e.atoms a = true
abbrev memFail (e : Eff) (t : Nat) : Prop := t ∈ e.fails

theorem ext {e f : Eff} (ha : ∀ a, mem e a ↔ mem f a) (hf : e.fails = f.fails) : e = f := by
  cases e with
  | mk a fs =>
    cases f with
    | mk b gs =>
      have hab : a = b := funext (fun x => Bool.eq_iff_iff.mpr (ha x))
      cases hab; cases hf; rfl

-- Release/Normalize.lean Eff.norm/Canonical, with already canonical Nat errors.
def norm (e : Eff) : Eff := .mk e.atoms (sortUnique compare e.fails)
def Canonical (e : Eff) : Prop := norm e = e

theorem norm_idem (e : Eff) : norm (norm e) = norm e := by
  simp [norm, atoms, fails, sortUnique_idem]

@[simp] theorem mem_norm (e : Eff) (a : Atom) : mem (norm e) a ↔ mem e a := Iff.rfl
@[simp] theorem memFail_norm (e : Eff) (t : Nat) : memFail (norm e) t ↔ memFail e t := by
  exact mem_sortUnique

def empty : Eff := .mk (fun _ => false) []
def ofList (xs : List Atom) : Eff := .mk (fun a => decide (a ∈ xs)) []
def union (e f : Eff) : Eff := norm (.mk (fun a => e.atoms a || f.atoms a) (e.fails ++ f.fails))

@[simp] theorem mem_ofList (xs : List Atom) (a : Atom) : mem (ofList xs) a ↔ a ∈ xs := by
  simp [mem, ofList, atoms]

@[simp] theorem mem_union (e f : Eff) (a : Atom) : mem (union e f) a ↔ mem e a ∨ mem f a := by
  simp [union, mem, norm, atoms]
@[simp] theorem memFail_union (e f : Eff) (t : Nat) :
    memFail (union e f) t ↔ memFail e t ∨ memFail f t := by
  simp [union, memFail, norm, fails, mem_sortUnique]

-- Treatment 1: retain the original pointwise relation for equality proofs.
def Sub (e f : Eff) : Prop :=
  (∀ a, mem e a → mem f a) ∧ (∀ t, memFail e t → memFail f t)

-- Separate widening relation: each left atom is covered by ONE right atom.
-- It is sound but deliberately incomplete for collective coverage by a union.
def ScopeSub (e f : Eff) : Prop :=
  (∀ a, mem e a → ∃ b, mem f b ∧ atomLe a b = true) ∧
  (∀ t, memFail e t → memFail f t)

theorem eq_of_sub_of_sub {e f : Eff} (he : Canonical e) (hf : Canonical f)
    (hef : Sub e f) (hfe : Sub f e) : e = f := by
  have hfs : (norm e).fails = (norm f).fails := by
    apply sortUnique_eq_iff_mem.mpr
    exact fun t => ⟨hef.2 t, hfe.2 t⟩
  apply ext (fun a => ⟨hef.1 a, hfe.1 a⟩)
  exact (congrArg fails he).symm.trans (hfs.trans (congrArg fails hf))

theorem norm_ext {e f : Eff} (ha : ∀ a, mem e a ↔ mem f a)
    (ht : ∀ t, memFail e t ↔ memFail f t) : norm e = norm f := by
  apply eq_of_sub_of_sub (norm_idem e) (norm_idem f)
  · exact ⟨fun a => by simpa using (ha a).mp, fun t => by simpa using (ht t).mp⟩
  · exact ⟨fun a => by simpa using (ha a).mpr, fun t => by simpa using (ht t).mpr⟩

theorem union_canonical (e f : Eff) : Canonical (union e f) := norm_idem _

-- Rewrite of Surface/Lemmas/Sequence.lean union_empty_right_nested.
theorem union_empty_right_nested (e f : Eff) : union e (union f empty) = union e f := by
  apply eq_of_sub_of_sub (union_canonical _ _) (union_canonical _ _)
  all_goals
    simp only [Sub, mem_union, memFail_union]
    simpa [empty, mem, memFail, atoms, fails] using
      (show (∀ a, (mem e a ∨ mem f a) → (mem e a ∨ mem f a)) ∧
        (∀ t, (memFail e t ∨ memFail f t) → (memFail e t ∨ memFail f t)) from
        ⟨fun _ => id, fun _ => id⟩)

-- Closed scopes and rows use the production finite-list substitution scheme.
structure Env where
  types : Nat → Nat
  rows : List Eff

def row (i : Nat) : Eff := ofList [.rho i]
def rowImage (es : List Eff) (i : Nat) : Eff := (es[i]?).getD (row i)
def substAtoms (es : List Eff) (a : Atom → Bool) : Atom → Bool := fun x =>
  let kept := match x with
    | .name l => a (.name l)
    | .rho i => if i < es.length then false else a (.rho i)
  kept || (List.range es.length).any (fun i =>
    a (.rho i) && match es[i]? with
      | some e => e.atoms x
      | none => false)

def rowFails (es : List Eff) (a : Atom → Bool) : List Nat :=
  ((List.range es.length).filter (fun i => a (.rho i))).flatMap (fun i =>
    match es[i]? with | some e => e.fails | none => [])

def rawBind (θ : Env) (e : Eff) : Eff :=
  .mk (substAtoms θ.rows e.atoms) (e.fails.map θ.types ++ rowFails θ.rows e.atoms)
def bind (θ : Env) (e : Eff) : Eff := norm (rawBind θ e)

@[simp] theorem mem_row (i : Nat) (a : Atom) : mem (row i) a ↔ a = .rho i := by
  simp [row]

-- Copy of Release/TypeSubstLemmas.lean Eff.mem_substAtoms.
theorem mem_substAtoms (es : List Eff) (e : Eff) (a : Atom) :
    substAtoms es e.atoms a = true ↔
      (match a with
        | .name l => mem e (.name l)
        | .rho i => es.length ≤ i ∧ mem e (.rho i)) ∨
      ∃ i f, es[i]? = some f ∧ mem e (.rho i) ∧ mem f a := by
  simp only [substAtoms, Bool.or_eq_true, List.any_eq_true, List.mem_range, Bool.and_eq_true]
  apply or_congr
  · cases a with
    | name _ => rfl
    | rho i =>
      by_cases hi : i < es.length
      · simp only [hi, ↓reduceIte, Bool.false_eq_true, false_iff, not_and]
        intro h; omega
      · simp only [hi, ↓reduceIte]
        exact ⟨fun h => ⟨by omega, h⟩, fun h => h.2⟩
  · constructor
    · rintro ⟨i, hi, h1, h2⟩
      refine ⟨i, es[i], by simp [hi], h1, ?_⟩
      simpa [List.getElem?_eq_getElem hi] using h2
    · rintro ⟨i, f, hf, h1, h2⟩
      have hi : i < es.length := (List.getElem?_eq_some_iff.mp hf).1
      refine ⟨i, hi, h1, ?_⟩
      simp [List.getElem?_eq_getElem hi] at hf ⊢
      rw [hf]; exact h2

theorem mem_bind (θ : Env) (e : Eff) (a : Atom) :
    mem (bind θ e) a ↔
      (∃ l, a = .name l ∧ mem e (.name l)) ∨
      ∃ i, mem e (.rho i) ∧ mem (rowImage θ.rows i) a := by
  change substAtoms θ.rows e.atoms a = true ↔ _
  rw [mem_substAtoms]
  constructor
  · rintro (h | ⟨i, f, hf, hi, ha⟩)
    · cases a with
      | name l => exact Or.inl ⟨l, rfl, h⟩
      | rho i => exact Or.inr ⟨i, h.2, by simp [rowImage, List.getElem?_eq_none h.1]⟩
    · exact Or.inr ⟨i, hi, by simpa [rowImage, hf] using ha⟩
  · rintro (⟨l, rfl, hl⟩ | ⟨i, hi, ha⟩)
    · exact Or.inl hl
    · cases hf : θ.rows[i]? with
      | none =>
        have ha : a = .rho i := by simpa [rowImage, hf] using ha
        subst a
        exact Or.inl ⟨List.getElem?_eq_none_iff.mp hf, hi⟩
      | some f => exact Or.inr ⟨i, f, hf, hi, by simpa [rowImage, hf] using ha⟩

-- Copy of Release/TypeSubst.lean Eff.mem_rowFails.
theorem mem_rowFails {es : List Eff} {a : Atom → Bool} {t : Nat} :
    t ∈ rowFails es a ↔ ∃ i e, es[i]? = some e ∧ a (.rho i) = true ∧ t ∈ e.fails := by
  simp only [rowFails, List.mem_flatMap, List.mem_filter, List.mem_range]
  constructor
  · rintro ⟨i, ⟨hi, ha⟩, ht⟩
    refine ⟨i, es[i], List.getElem?_eq_getElem hi, ha, ?_⟩
    simpa only [List.getElem?_eq_getElem hi] using ht
  · rintro ⟨i, e, he, ha, ht⟩
    exact ⟨i, ⟨(List.getElem?_eq_some_iff.mp he).1, ha⟩, by simpa only [he] using ht⟩

theorem memFail_bind (θ : Env) (e : Eff) (t : Nat) :
    memFail (bind θ e) t ↔
      (∃ x, memFail e x ∧ θ.types x = t) ∨
      ∃ i, mem e (.rho i) ∧ memFail (rowImage θ.rows i) t := by
  rw [bind, memFail_norm]
  change t ∈ e.fails.map θ.types ++ rowFails θ.rows e.atoms ↔ _
  rw [List.mem_append, List.mem_map, mem_rowFails]
  apply or_congr Iff.rfl
  constructor
  · rintro ⟨i, f, hf, hi, ht⟩
    exact ⟨i, hi, by simpa [rowImage, hf] using ht⟩
  · rintro ⟨i, hi, ht⟩
    cases hf : θ.rows[i]? with
    | none => simp [rowImage, hf, row, ofList, memFail, fails] at ht
    | some f => exact ⟨i, f, hf, hi, by simpa [rowImage, hf] using ht⟩

-- Rewrite of Release/TypeComposition.lean Eff.bind_union (substitution).
theorem bind_union (θ : Env) (e f : Eff) :
    bind θ (union e f) = union (bind θ e) (bind θ f) := by
  apply eq_of_sub_of_sub (e := bind θ (union e f))
    (f := union (bind θ e) (bind θ f)) (norm_idem _) (norm_idem _)
  all_goals constructor
  all_goals first
    | (intro a; simp only [mem_bind, mem_union, and_or_left, or_and_right, exists_or]; grind)
    | (intro t; simp only [memFail_bind, memFail_union, mem_union,
        and_or_left, or_and_right, exists_or]; grind)

theorem bind_norm (θ : Env) (e : Eff) : bind θ (norm e) = bind θ e := by
  apply eq_of_sub_of_sub (e := bind θ (norm e)) (f := bind θ e)
    (norm_idem _) (norm_idem _)
  all_goals constructor
  all_goals first
    | (intro a; simp only [mem_bind, mem_norm]; exact id)
    | (intro t; simp only [memFail_bind, memFail_norm, mem_norm]; exact id)

theorem bind_row (θ : Env) (i : Nat) : bind θ (row i) = norm (rowImage θ.rows i) := by
  apply norm_ext
  · intro a
    change mem (bind θ (row i)) a ↔ mem (rowImage θ.rows i) a
    simp [mem_bind]
  · intro t
    rw [← memFail_norm (rawBind θ (row i))]
    change memFail (bind θ (row i)) t ↔ memFail (rowImage θ.rows i) t
    simp [memFail_bind, row, ofList, memFail, fails]

def Env.compose (θ φ : Env) : Env :=
  ⟨fun i => φ.types (θ.types i),
    (List.range (max θ.rows.length φ.rows.length)).map (fun i => bind φ (rowImage θ.rows i))⟩

theorem rowImage_compose (θ φ : Env) (i : Nat) :
    rowImage (θ.compose φ).rows i = bind φ (rowImage θ.rows i) := by
  by_cases hi : i < max θ.rows.length φ.rows.length
  · simp [rowImage, Env.compose, List.getElem?_map, List.getElem?_range hi]
  · have he : θ.rows.length ≤ i := by omega
    have hf : φ.rows.length ≤ i := by omega
    have hc : (θ.compose φ).rows[i]? = none :=
      List.getElem?_eq_none (by simpa [Env.compose] using Nat.le_of_not_gt hi)
    rw [rowImage, hc, Option.getD_none, rowImage, List.getElem?_eq_none he,
      Option.getD_none, bind_row, rowImage, List.getElem?_eq_none hf, Option.getD_none]
    rfl

-- Rewrite of Release/TypeComposition.lean Eff.bind_comp_of_types (composition).
-- Here Nat errors make the required type-composition law definitionally true.
theorem bind_comp (θ φ : Env) (e : Eff) : bind φ (bind θ e) = bind (θ.compose φ) e := by
  apply eq_of_sub_of_sub (e := bind φ (bind θ e)) (f := bind (θ.compose φ) e)
    (norm_idem _) (norm_idem _)
  all_goals constructor
  all_goals first
    | (intro a; simp only [mem_bind, rowImage_compose]; grind only)
    | (intro t; simp only [memFail_bind, mem_bind, rowImage_compose,
        show (θ.compose φ).types = (fun i => φ.types (θ.types i)) from rfl]; grind only)

end Eff
end SA
