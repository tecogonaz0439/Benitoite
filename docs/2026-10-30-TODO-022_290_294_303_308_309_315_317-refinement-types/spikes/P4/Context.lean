import Logic

namespace P4
open Benitoite.Release
set_option maxHeartbeats 400000

/- 最外の篩の本番 Ty アダプタ。再帰する型判断の試作は Derivations.lean。
   Γ の要素は通常の型と篩の構文であり、意味の述語を格納しない。
   各 Γ[i] の自由な値変数は、lookup 後の Γ 全体に対する絶対番号として格納する。
   束縛を増やす際には、既存の全要素の値変数を移動する必要がある。 -/
structure RefTy where
  carrier : Ty
  predicate : Pred

def RefTy.WF (nr nt nv : Nat) (a : RefTy) : Prop :=
  Ty.WF nr nt a.carrier ∧ a.predicate.WF (nv+1)

def RefTy.bind (σ : Nat → Term) (a : RefTy) : RefTy :=
  ⟨a.carrier, a.predicate.bind (upSub σ)⟩

noncomputable def RefTy.substAt (c : Nat) (ts : List Ty) (es : List Eff) (σ : Nat → Term) (a : RefTy) : RefTy :=
  ⟨a.carrier.substAt c ts es, a.predicate.bind (upSub σ)⟩

def shiftIndex (k c i : Nat) : Nat := if i < c then i else i+k

noncomputable def RefTy.shift (kt ct kv cv : Nat) (a : RefTy) : RefTy :=
  ⟨a.carrier.shift kt ct, a.predicate.bind (upSub (fun i => .var (shiftIndex kv cv i)))⟩

theorem RefTy.value_bind_wf {nr nt nv nw : Nat} {a : RefTy} (ha : a.WF nr nt nv)
    (σ : Nat → Term) (hs : ∀ i, i < nv → (σ i).WF nw) : (a.bind σ).WF nr nt nw :=
  ⟨ha.1, a.predicate.wf_bind ha.2 _ (upSub_wf hs)⟩

theorem RefTy.shift_wf {nr nt nv : Nat} {a : RefTy} (ha : a.WF nr nt nv) (kt kv : Nat) :
    (a.shift kt 0 kv 0).WF nr (nt+kt) (nv+kv) := by
  refine ⟨Ty.shift_wf kt a.carrier ha.1, a.predicate.wf_bind ha.2 _ (upSub_wf ?_)⟩
  intro i hi
  change shiftIndex kv 0 i < nv+kv
  simp [shiftIndex]
  omega

abbrev Ctx := List (Option RefTy)
def Ctx.ordinary (Γ : Ctx) : List (Option Ty) := Γ.map (Option.map RefTy.carrier)

def factsFrom (k : Nat) : Ctx → List Pred
  | [] => []
  | none :: Γ => factsFrom (k+1) Γ
  | some a :: Γ => a.predicate.open (.var k) :: factsFrom (k+1) Γ

def Ctx.facts (Γ : Ctx) : List Pred := factsFrom 0 Γ

theorem factsFrom_mem {Γ : Ctx} {k : Nat} {p : Pred} :
    p ∈ factsFrom k Γ ↔ ∃ (i : Nat) (a : RefTy), Γ[i]? = some (some a) ∧ p = a.predicate.open (.var (k+i)) := by
  induction Γ generalizing k with
  | nil => simp [factsFrom]
  | cons head tail ih =>
      cases head with
      | none =>
          simp only [factsFrom, ih]
          constructor
          · rintro ⟨i, a, hi, hp⟩
            exact ⟨i+1, a, hi, by simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hp⟩
          · rintro ⟨i, a, hi, hp⟩
            cases i with
            | zero => simp at hi
            | succ i => exact ⟨i, a, hi, by simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hp⟩
      | some a =>
          simp only [factsFrom, List.mem_cons, ih]
          constructor
          · rintro (rfl | ⟨i, b, hi, hp⟩)
            · exact ⟨0, a, rfl, by simp⟩
            · exact ⟨i+1, b, hi, by simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hp⟩
          · rintro ⟨i, b, hi, hp⟩
            cases i with
            | zero =>
                have he : a = b := Option.some.inj (Option.some.inj hi)
                subst b
                exact Or.inl (by simpa using hp)
            | succ i => exact Or.inr ⟨i, b, hi, by simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using hp⟩

theorem Ctx.fact_lookup {Γ : Ctx} {i : Nat} {a : RefTy} (h : Γ[i]? = some (some a)) :
    a.predicate.open (.var i) ∈ Γ.facts :=
  factsFrom_mem.mpr ⟨i, a, h, by simp⟩

-- 閉じた値の canonical forms から Φ の束縛の事実を作る。
theorem facts_of_values (Γ : Ctx) (parse) (ρ : Nat → Value)
    (hc : ∀ (i : Nat) (a : RefTy), Γ[i]? = some (some a) → a.predicate.Holds parse (extend ρ (ρ i))) :
    Satisfies parse ρ Γ.facts := by
  intro p hp
  obtain ⟨i, a, hi, rfl⟩ := factsFrom_mem.mp hp
  apply (a.predicate.holds_open parse ρ (.var (0+i)) (ρ i) (by simp [Term.eval])).mpr
  exact hc i a hi

inductive Le (Φ : List Pred) : RefTy → RefTy → Prop where
  | refl (a) : Le Φ a a
  | trans {a b c} : Le Φ a b → Le Φ b c → Le Φ a c
  | refine {a b} : Ty.Le a.carrier b.carrier →
      Entails (a.predicate :: Φ.map Pred.lift) b.predicate → Le Φ a b

theorem Le.predicate {Φ a b} (h : Le Φ a b) (t : Term) (hp : Entails Φ (a.predicate.open t)) :
    Entails Φ (b.predicate.open t) := by
  induction h with
  | refl => exact hp
  | trans _ _ ia ib => exact ib (ia hp)
  | refine _ h => exact h.apply t hp

theorem Le.carrier {Φ a b} (h : Le Φ a b) : Ty.Le a.carrier b.carrier := by
  induction h with
  | refl => exact Ty.Le.refl _
  | trans _ _ i₁ i₂ => exact Ty.Le.trans i₁ i₂
  | refine h _ => exact h

theorem Le.substAt {Φ a b} (h : Le Φ a b) (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : Nat → Term) : Le (Φ.map (Pred.bind σ)) (a.substAt c ts es σ) (b.substAt c ts es σ) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂
  | @refine a b hc hp =>
      apply Le.refine (Ty.Le.substAt c ts es hc)
      have hh := hp.bind (upSub σ)
      simpa only [List.map_cons, List.map_map, Function.comp_def, Pred.lift_bind, RefTy.substAt, RefTy.bind, RefTy.shift] using hh

theorem Le.bind {Φ a b} (h : Le Φ a b) (σ : Nat → Term) :
    Le (Φ.map (Pred.bind σ)) (a.bind σ) (b.bind σ) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂
  | @refine a b hc hp =>
      apply Le.refine (a := a.bind σ) (b := b.bind σ) hc
      have hh := hp.bind (upSub σ)
      simpa only [List.map_cons, List.map_map, Function.comp_def, Pred.lift_bind, RefTy.substAt, RefTy.bind, RefTy.shift] using hh

theorem Le.shift {Φ a b} (h : Le Φ a b) (kt ct kv cv : Nat) :
    Le (Φ.map (Pred.bind (fun i => .var (shiftIndex kv cv i))))
      (a.shift kt ct kv cv) (b.shift kt ct kv cv) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂
  | refine hc hp =>
      apply Le.refine (Ty.Le.shift kt ct hc)
      have hh := hp.bind (upSub (fun i => .var (shiftIndex kv cv i)))
      simpa only [List.map_cons, List.map_map, Function.comp_def, Pred.lift_bind, RefTy.substAt, RefTy.bind, RefTy.shift] using hh

theorem Le.cut {Φ Ψ a b} (h : Le Φ a b) (hm : ∀ p ∈ Φ, Entails Ψ p) : Le Ψ a b := by
  induction h with
  | refl => exact .refl _
  | trans _ _ i₁ i₂ => exact .trans i₁ i₂
  | @refine a b hc hp =>
      apply Le.refine hc
      apply hp.cut
      intro q hq
      rcases List.mem_cons.mp hq with rfl | hq
      · exact .hyp (by simp)
      · obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hq
        apply ((hm p hp).bind (fun i => .var (i+1))).cut
        intro r hr
        exact .hyp (List.mem_cons_of_mem _ hr)

-- Native は閉じた観測値と通常の型の関係。本番との実例は Production.lean で与える。
-- canonical の証明は Native の意味や関数/Reference の意味の所属を使わない。
inductive Typed (Native : Value → Ty → Prop) (Γ : Ctx) (Φ : List Pred) : Term → RefTy → Prop where
  | var {i a} : Γ[i]? = some (some a) → Typed Native Γ Φ (.var i) a
  | literal {v a} : Native v a → Typed Native Γ Φ (.lit v) ⟨a, .truth⟩
  | refine {t a p} : Typed Native Γ Φ t a → Entails (Γ.facts ++ Φ) (p.open t) →
      Typed Native Γ Φ t ⟨a.carrier, p⟩
  | V_Sub {t a b} : Typed Native Γ Φ t a → Le (Γ.facts ++ Φ) a b → Typed Native Γ Φ t b

theorem Typed.predicate {Native Γ Φ t a} (h : Typed Native Γ Φ t a) :
    Entails (Γ.facts ++ Φ) (a.predicate.open t) := by
  induction h with
  | var hh => exact .hyp (List.mem_append_left _ (Ctx.fact_lookup hh))
  | literal => exact .truth
  | refine _ hp _ => exact hp
  | V_Sub _ hl ih => exact hl.predicate _ ih

-- 置換の「文脈保存」は構文の証拠だけから作る。
theorem context_map_of_typed {Native : Value → Ty → Prop} {Γ Δ : Ctx} {Φ Ψ : List Pred} {σ : Nat → Term}
    (hs : ∀ (i : Nat) (a : RefTy), Γ[i]? = some (some a) → Typed Native Δ Ψ (σ i) (a.bind σ))
    (hΦ : ∀ p ∈ Φ, Entails (Δ.facts ++ Ψ) (p.bind σ)) :
    ∀ p ∈ Γ.facts ++ Φ, Entails (Δ.facts ++ Ψ) (p.bind σ) := by
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · obtain ⟨i, a, hi, rfl⟩ := factsFrom_mem.mp hp
    simpa only [Pred.open_bind, Term.bind, Nat.zero_add, RefTy.bind] using (hs i a hi).predicate
  · exact hΦ p hp

theorem Typed.subst {Native Γ Φ t a} (h : Typed Native Γ Φ t a) :
    ∀ (Δ : Ctx) (Ψ : List Pred) (σ : Nat → Term),
      (∀ (i : Nat) (a : RefTy), Γ[i]? = some (some a) → Typed Native Δ Ψ (σ i) (a.bind σ)) →
      (∀ p ∈ Φ, Entails (Δ.facts ++ Ψ) (p.bind σ)) →
      Typed Native Δ Ψ (t.bind σ) (a.bind σ) := by
  induction h with
  | var hi => intro Δ Ψ σ hs _; exact hs _ _ hi
  | literal hv => intro Δ Ψ σ _ _; exact .literal hv
  | @refine t a p ht hp ih =>
      intro Δ Ψ σ hs hΦ
      apply Typed.refine (ih Δ Ψ σ hs hΦ)
      have hh := (hp.bind σ).cut (by
        intro q hq
        obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hq
        exact context_map_of_typed hs hΦ p hp)
      simpa only [Pred.open_bind] using hh
  | @V_Sub t a b ht hl ih =>
      intro Δ Ψ σ hs hΦ
      apply Typed.V_Sub (ih Δ Ψ σ hs hΦ)
      apply (hl.bind σ).cut
      intro q hq
      obtain ⟨p, hp, rfl⟩ := List.mem_map.mp hq
      exact context_map_of_typed hs hΦ p hp

theorem Typed.canonical {Native v a} (h : Typed Native [] [] (.lit v) a)
    (parse) (ρ : Nat → Value) : a.predicate.Holds parse (extend ρ v) := by
  have hp := h.predicate.sound parse ρ (by simp [Satisfies, Ctx.facts, factsFrom])
  exact (a.predicate.holds_open parse ρ (.lit v) v rfl).mp hp

-- 全ての閉じた型付き像から Γ の論理の埋め込みの充足を得る。
-- 型の変数・閉包・セルの中身の意味の所属は前提に含めない。
theorem closed_embedding {Native : Value → Ty → Prop} (Γ : Ctx) (values : Nat → Value)
    (ht : ∀ (i : Nat) (a : RefTy), Γ[i]? = some (some a) →
      Typed Native [] [] (.lit (values i)) (a.bind (fun j => .lit (values j))))
    (parse : String → Option Benitoite.Scope.Domain.Target) : Satisfies parse values Γ.facts := by
  apply facts_of_values
  intro i a hi
  have hc := (ht i a hi).canonical parse (fun _ => Value.other)
  exact (a.predicate.holds_bind (upSub (fun j => .lit (values j)))
    (extend (fun _ => Value.other) (values i)) (extend values (values i))
    (eval_up _ _ _ (fun _ => rfl) (values i)) parse).mp hc

-- if の真の枝で、束縛の下に条件を足す。偽の枝では .not p を同じ位置へ足せる。
def branchFacts (Φ : List Pred) (p : Pred) : List Pred := p :: Φ.map Pred.lift

theorem branchFacts_sound (parse) (ρ : Nat → Value) (v : Value) (Φ : List Pred) (p : Pred)
    (hΦ : Satisfies parse ρ Φ) (hp : p.Holds parse (extend ρ v)) :
    Satisfies parse (extend ρ v) (branchFacts Φ p) := by
  intro q hq
  rcases List.mem_cons.mp hq with rfl | hq
  · exact hp
  · obtain ⟨p, hmem, rfl⟩ := List.mem_map.mp hq
    exact (p.holds_lift parse ρ v).mpr (hΦ p hmem)

theorem branchFacts_bind (σ : Nat → Term) (Φ : List Pred) (p : Pred) :
    (branchFacts Φ p).map (Pred.bind (upSub σ)) =
      branchFacts (Φ.map (Pred.bind σ)) (p.bind (upSub σ)) := by
  simp only [branchFacts, List.map_cons, List.map_map, Function.comp_def, Pred.lift_bind]

def Ctx.extend (Γ : Ctx) (a : RefTy) : Ctx :=
  some (a.bind (fun i => .var (i+1))) :: Γ.map (Option.map (RefTy.bind (fun i => .var (i+1))))

def Ctx.WF (nr nt : Nat) (Γ : Ctx) : Prop :=
  ∀ (i : Nat) (a : RefTy), Γ[i]? = some (some a) → a.WF nr nt Γ.length

theorem Ctx.extend_ordinary (Γ : Ctx) (a : RefTy) :
    (Γ.extend a).ordinary = some a.carrier :: Γ.ordinary := by
  simp only [Ctx.extend, Ctx.ordinary, List.map_cons, Option.map_some, RefTy.bind,
    List.map_map, Function.comp_def]
  congr 1
  apply List.map_congr_left
  intro x hx
  cases x <;> rfl

theorem bound_fact (p : Pred) :
    (p.bind (upSub (fun i => .var (i+1)))).open (.var 0) = p := by
  simp only [Pred.open, Pred.bind_comp]
  have he : (fun i => (upSub (fun j => Term.var (j+1)) i).bind (instantiate (.var 0))) = Term.var := by
    funext i
    cases i <;> rfl
  rw [he]
  exact p.bind_id

theorem factsFrom_shift (Γ : Ctx) (k : Nat) :
    factsFrom (k+1) (Γ.map (Option.map (RefTy.bind (fun i => .var (i+1))))) =
      (factsFrom k Γ).map Pred.lift := by
  induction Γ generalizing k with
  | nil => rfl
  | cons head tail ih =>
      cases head with
      | none => simpa only [List.map_cons, Option.map_none, factsFrom] using ih (k+1)
      | some a =>
          simp only [List.map_cons, Option.map_some, factsFrom]
          rw [ih (k+1)]
          congr 1
          exact (a.predicate.open_bind (fun i => .var (i+1)) (.var k)).symm

theorem Ctx.extend_facts (Γ : Ctx) (a : RefTy) :
    (Γ.extend a).facts = a.predicate :: Γ.facts.map Pred.lift := by
  simp only [Ctx.facts, Ctx.extend, factsFrom, RefTy.bind, bound_fact]
  exact congrArg (List.cons a.predicate) (factsFrom_shift Γ 0)

theorem Ctx.extend_wf {Γ : Ctx} {a : RefTy} {nr nt : Nat}
    (hΓ : Γ.WF nr nt) (ha : a.WF nr nt Γ.length) : (Γ.extend a).WF nr nt := by
  intro i b hi
  have hs {t : RefTy} (ht : t.WF nr nt Γ.length) :
      (t.bind (fun j => .var (j+1))).WF nr nt (Γ.length+1) := by
    apply t.value_bind_wf ht
    intro j hj
    change j+1 < Γ.length+1
    omega
  cases i with
  | zero =>
      have he : a.bind (fun j => .var (j+1)) = b := Option.some.inj (Option.some.inj hi)
      subst b
      simpa only [Ctx.extend, List.length_cons, List.length_map] using hs ha
  | succ i =>
      have hm : (Γ.map (Option.map (RefTy.bind (fun j => .var (j+1)))))[i]? = some (some b) := hi
      rw [List.getElem?_map] at hm
      cases hg : Γ[i]? with
      | none => simp [hg] at hm
      | some entry =>
          cases entry with
          | none => simp [hg] at hm
          | some c =>
              have he : c.bind (fun j => .var (j+1)) = b := by simpa [hg] using hm
              subst b
              simpa only [Ctx.extend, List.length_cons, List.length_map] using hs (hΓ i c hg)

theorem Typed.shift {Native Γ Φ t a} (h : Typed Native Γ Φ t a) (bound : RefTy) :
    Typed Native (Γ.extend bound) (Φ.map Pred.lift)
      (t.rename Nat.succ) (a.bind (fun i => .var (i+1))) := by
  apply h.subst
  · intro i b hi
    apply Typed.var (i := i+1)
    change (Γ.map (Option.map (RefTy.bind (fun j => .var (j+1)))))[i]? = _
    simp [hi]
  · intro p hp
    exact .hyp (List.mem_append_right _ (List.mem_map.mpr ⟨p, hp, rfl⟩))

theorem Ctx.extend_satisfies (Γ : Ctx) (a : RefTy) (parse) (ρ : Nat → Value) (v : Value)
    (hΓ : Satisfies parse ρ Γ.facts) (hv : a.predicate.Holds parse (P4.extend ρ v)) :
    Satisfies parse (P4.extend ρ v) (Γ.extend a).facts := by
  rw [Ctx.extend_facts]
  exact branchFacts_sound parse ρ v Γ.facts a.predicate hΓ hv

#print axioms Typed.shift
#print axioms Ctx.extend_facts
#print axioms Ctx.extend_wf
#print axioms Ctx.extend_satisfies
#print axioms closed_embedding
#print axioms Typed.canonical
#print axioms Typed.subst
#print axioms context_map_of_typed
#print axioms Le.substAt
#print axioms Le.shift
#print axioms RefTy.shift_wf
#print axioms facts_of_values
#print axioms branchFacts_sound
#print axioms branchFacts_bind
end P4
