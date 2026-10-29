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
