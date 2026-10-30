import P2
import Benitoite.Release.Lemmas.Basic
import Benitoite.Release.TypeBounds

/- P4 の新規定義。Nat/upSub の形は P3b-Nat.lean:14-260、
   部分的な観測は P3b-Derivations.lean:13-139 を参照。
   Value は閉じた値の観測用の写しであり、実行の意味やストアのモデルではない。
   本番の Ty、Ty.WF、Ty.Le の補題を再利用する。 -/
namespace P4
open Benitoite.Release
open Benitoite.Scope.Domain (Target Range)
set_option maxHeartbeats 400000
set_option maxRecDepth 4096

inductive Value where
  | int (n : Int)
  | string (s : String)
  | list (xs : List Value)
  | con (owner constructor : String) (fields : List Value)
  | reference (loc : Nat)
  | closure (code : Val)
  | request (endpoint : Target) (retained : Value)
  | other
  | unobserved (original : Val)

-- 欄の射影は名目の data と構成子を明記する。Reference の読み取りは構文にない。
inductive Term where
  | var (index : Nat)
  | lit (v : Value)
  | add (a b : Term)
  | length (a : Term)
  | field (owner constructor : String) (index : Nat) (a : Term)
  | requestValue (a : Term)

def Term.bind (σ : Nat → Term) : Term → Term
  | .var i => σ i
  | .lit v => .lit v
  | .add a b => .add (a.bind σ) (b.bind σ)
  | .length a => .length (a.bind σ)
  | .field d c i a => .field d c i (a.bind σ)
  | .requestValue a => .requestValue (a.bind σ)

def Term.rename (ξ : Nat → Nat) : Term → Term := bind (fun i => .var (ξ i))

def Term.eval (ρ : Nat → Value) : Term → Option Value
  | .var i => some (ρ i)
  | .lit v => some v
  | .add a b => do
      let .int x ← a.eval ρ | none
      let .int y ← b.eval ρ | none
      pure (.int (x+y))
  | .length a => do
      let .list xs ← a.eval ρ | none
      pure (.int xs.length)
  | .field d c i a => do
      let .con d' c' fs ← a.eval ρ | none
      if d = d' ∧ c = c' then fs[i]? else none
  | .requestValue a => do
      let .request _ req ← a.eval ρ | none
      pure req

def Term.WF (n : Nat) : Term → Prop
  | .var i => i < n
  | .lit _ => True
  | .add a b => a.WF n ∧ b.WF n
  | .length a | .field _ _ _ a | .requestValue a => a.WF n

theorem Term.bind_id (a : Term) : a.bind .var = a := by
  induction a <;> simp_all [bind]

theorem Term.bind_comp (σ τ : Nat → Term) (a : Term) :
    (a.bind σ).bind τ = a.bind (fun i => (σ i).bind τ) := by
  induction a <;> simp_all [bind]

theorem Term.eval_bind (σ : Nat → Term) (ρ ρ' : Nat → Value)
    (hs : ∀ i, (σ i).eval ρ = some (ρ' i)) (a : Term) :
    (a.bind σ).eval ρ = a.eval ρ' := by
  induction a <;> simp_all only [bind, eval]

theorem Term.eval_rename (ξ : Nat → Nat) (ρ : Nat → Value) (a : Term) :
    (a.rename ξ).eval ρ = a.eval (ρ ∘ ξ) :=
  a.eval_bind _ _ _ (fun _ => rfl)

theorem Term.wf_bind {n m : Nat} (a : Term) (ha : a.WF n)
    (σ : Nat → Term) (hs : ∀ i, i < n → (σ i).WF m) : (a.bind σ).WF m := by
  induction a with
  | var i => exact hs i ha
  | lit => trivial
  | add a b ia ib => exact ⟨ia ha.1, ib ha.2⟩
  | length a ia | field _ _ _ a ia | requestValue a ia => exact ia ha

def extend (ρ : Nat → Value) (v : Value) : Nat → Value
  | 0 => v
  | i+1 => ρ i

def upSub (σ : Nat → Term) : Nat → Term
  | 0 => .var 0
  | i+1 => (σ i).rename Nat.succ

def instantiate (t : Term) : Nat → Term
  | 0 => t
  | i+1 => .var i

theorem upSub_comp (σ τ : Nat → Term) :
    (fun i => (upSub σ i).bind (upSub τ)) = upSub (fun i => (σ i).bind τ) := by
  funext i
  cases i with
  | zero => rfl
  | succ i => simp only [upSub, Term.rename, Term.bind_comp, Term.bind]

theorem instantiate_up (σ : Nat → Term) (t : Term) (p : Term) :
    (p.bind (instantiate t)).bind σ =
      (p.bind (upSub σ)).bind (instantiate (t.bind σ)) := by
  simp only [Term.bind_comp]
  congr 1
  funext i
  cases i with
  | zero => rfl
  | succ i =>
      simp only [instantiate, upSub, Term.bind, Term.rename, Term.bind_comp]
      exact (Term.bind_id _).symm

theorem eval_up (σ : Nat → Term) (ρ ρ' : Nat → Value)
    (hs : ∀ i, (σ i).eval ρ = some (ρ' i)) (v : Value) (i : Nat) :
    (upSub σ i).eval (extend ρ v) = some (extend ρ' v i) := by
  cases i with
  | zero => rfl
  | succ i => simpa only [upSub, Term.eval_rename, extend, Function.comp_def] using hs i

-- P2 の鍵は有限列。評価不能な鍵を 0 で補って真としない。
def KeyValues (ρ : Nat → Value) (keys : List Term) (ν : P2.Env) : Prop :=
  ∀ (i : Nat) (t : Term), keys[i]? = some t → t.eval ρ = some (.int (ν i))

def urlOf : Value → Option String
  | .con "Http.ClientRequest" "Http.ClientRequest" [_, .string url, _, _, _] => some url
  | _ => none

def reqTarget (parse : String → Option Target) (req : Value) : Option Target :=
  (urlOf req).bind parse

inductive Pred where
  | truth | falsity
  | eq (a b : Term)
  | le (a b : Term)
  | isList (a : Term)
  | aligned (a : Term)
  | arithmetic (keys : List Term) (formula : P2.Formula)
  | and (p q : Pred)
  | or (p q : Pred)
  | not (p : Pred)

def Pred.bind (σ : Nat → Term) : Pred → Pred
  | .truth => .truth
  | .falsity => .falsity
  | .eq a b => .eq (a.bind σ) (b.bind σ)
  | .le a b => .le (a.bind σ) (b.bind σ)
  | .isList a => .isList (a.bind σ)
  | .aligned a => .aligned (a.bind σ)
  | .arithmetic ks f => .arithmetic (ks.map (Term.bind σ)) f
  | .and p q => .and (p.bind σ) (q.bind σ)
  | .or p q => .or (p.bind σ) (q.bind σ)
  | .not p => .not (p.bind σ)

def Pred.lift (p : Pred) : Pred := p.bind (fun i => .var (i+1))
def Pred.open (p : Pred) (t : Term) : Pred := p.bind (instantiate t)

def Pred.Holds (parse : String → Option Target) (ρ : Nat → Value) : Pred → Prop
  | .truth => True
  | .falsity => False
  | .eq a b => ∃ v, a.eval ρ = some v ∧ b.eval ρ = some v
  | .le a b => ∃ x y, a.eval ρ = some (.int x) ∧ b.eval ρ = some (.int y) ∧ x ≤ y
  | .isList a => ∃ xs, a.eval ρ = some (.list xs)
  | .aligned a => ∃ t req, a.eval ρ = some (.request t req) ∧ reqTarget parse req = some t
  | .arithmetic ks f => ∃ ν, KeyValues ρ ks ν ∧ f.Holds ν
  | .and p q => p.Holds parse ρ ∧ q.Holds parse ρ
  | .or p q => p.Holds parse ρ ∨ q.Holds parse ρ
  | .not p => ¬ p.Holds parse ρ

def Pred.WF (n : Nat) : Pred → Prop
  | .truth | .falsity => True
  | .eq a b | .le a b => a.WF n ∧ b.WF n
  | .isList a | .aligned a => a.WF n
  | .arithmetic ks _ => ∀ t ∈ ks, t.WF n
  | .and p q | .or p q => p.WF n ∧ q.WF n
  | .not p => p.WF n

theorem Pred.bind_id (p : Pred) : p.bind .var = p := by
  have he : Term.bind .var = id := by funext t; exact t.bind_id
  induction p <;> simp_all [bind, Term.bind_id]

theorem Pred.bind_comp (σ τ : Nat → Term) (p : Pred) :
    (p.bind σ).bind τ = p.bind (fun i => (σ i).bind τ) := by
  induction p <;> simp_all [bind, Term.bind_comp, List.map_map, Function.comp_def]

theorem Pred.open_bind (σ : Nat → Term) (p : Pred) (t : Term) :
    (p.open t).bind σ = (p.bind (upSub σ)).open (t.bind σ) := by
  simp only [Pred.open, bind_comp]
  congr 1
  funext i
  cases i with
  | zero => rfl
  | succ i =>
      simp only [instantiate, upSub, Term.bind, Term.rename, Term.bind_comp]
      exact (Term.bind_id _).symm

theorem Pred.holds_bind (σ : Nat → Term) (ρ ρ' : Nat → Value)
    (hs : ∀ i, (σ i).eval ρ = some (ρ' i)) (p : Pred) (parse) :
    (p.bind σ).Holds parse ρ ↔ p.Holds parse ρ' := by
  have hk (ks : List Term) (ν : P2.Env) :
      KeyValues ρ (ks.map (Term.bind σ)) ν ↔ KeyValues ρ' ks ν := by
    simp only [KeyValues, List.getElem?_map]
    constructor
    · intro h i t ht
      have hh := h i (t.bind σ) (by simp [ht])
      simpa only [Term.eval_bind σ ρ ρ' hs] using hh
    · intro h i t ht
      cases he : ks[i]? with
      | none => simp [he] at ht
      | some t' =>
          have hh : t'.bind σ = t := by simpa [he] using ht
          subst t
          exact (t'.eval_bind σ ρ ρ' hs).trans (h i t' he)
  induction p with
  | truth | falsity => rfl
  | eq a b | le a b => simp only [bind, Holds, Term.eval_bind σ ρ ρ' hs]
  | isList a | aligned a => simp only [bind, Holds, Term.eval_bind σ ρ ρ' hs]
  | arithmetic ks f => simp only [bind, Holds, hk]
  | and p q ip iq => exact and_congr ip iq
  | or p q ip iq => exact or_congr ip iq
  | not p ip => exact not_congr ip

theorem Pred.holds_lift (p : Pred) (parse) (ρ : Nat → Value) (v : Value) :
    p.lift.Holds parse (extend ρ v) ↔ p.Holds parse ρ :=
  p.holds_bind _ _ _ (fun _ => rfl) parse

theorem Pred.holds_open (p : Pred) (parse) (ρ : Nat → Value) (t : Term) (v : Value)
    (ht : t.eval ρ = some v) :
    (p.open t).Holds parse ρ ↔ p.Holds parse (extend ρ v) := by
  apply p.holds_bind
  intro i
  cases i with
  | zero => exact ht
  | succ => rfl

def Satisfies (parse : String → Option Target) (ρ : Nat → Value) (Φ : List Pred) : Prop :=
  ∀ p ∈ Φ, p.Holds parse ρ

def lengthFact : P2.Formula := .le ⟨[-1], 0⟩

-- 全ての規則は有限の構文の導出。任意の意味の含意を登録する規則はない。
inductive Entails (Φ : List Pred) : Pred → Prop where
  | hyp {p} : p ∈ Φ → Entails Φ p
  | truth : Entails Φ .truth
  | and_intro {p q} : Entails Φ p → Entails Φ q → Entails Φ (.and p q)
  | and_left {p q} : Entails Φ (.and p q) → Entails Φ p
  | and_right {p q} : Entails Φ (.and p q) → Entails Φ q
  | or_left {p q} : Entails Φ p → Entails Φ (.or p q)
  | or_right {p q} : Entails Φ q → Entails Φ (.or p q)
  | false_elim {p} : Entails Φ .falsity → Entails Φ p
  | integer {a b : Int} : a ≤ b → Entails Φ (.le (.lit (.int a)) (.lit (.int b)))
  | literal_eq (v : Value) : Entails Φ (.eq (.lit v) (.lit v))
  | length_eq (xs : List Value) :
      Entails Φ (.eq (.length (.lit (.list xs))) (.lit (.int xs.length)))
  | field_eq (d c : String) (fs : List Value) (i : Nat) (v : Value) :
      fs[i]? = some v → Entails Φ (.eq (.field d c i (.lit (.con d c fs))) (.lit v))
  | request_value (t : Target) (req : Value) :
      Entails Φ (.eq (.requestValue (.lit (.request t req))) (.lit req))
  | list_shape (xs : List Value) : Entails Φ (.isList (.lit (.list xs)))
  | length_nonnegative {t} : Entails Φ (.isList t) →
      Entails Φ (.arithmetic [.length t] lengthFact)
  | checked {ks p q cert} :
      P2.check (.and p (.not q)) cert = true → Entails Φ (.arithmetic ks p) →
      Entails Φ (.arithmetic ks q)

theorem Entails.sound {Φ p} (h : Entails Φ p) (parse) (ρ : Nat → Value)
    (hΦ : Satisfies parse ρ Φ) : p.Holds parse ρ := by
  induction h with
  | hyp hm => exact hΦ _ hm
  | truth => trivial
  | and_intro _ _ ih₁ ih₂ => exact ⟨ih₁, ih₂⟩
  | and_left _ ih => exact ih.1
  | and_right _ ih => exact ih.2
  | or_left _ ih => exact Or.inl ih
  | or_right _ ih => exact Or.inr ih
  | false_elim _ ih => exact ih.elim
  | integer h => exact ⟨_, _, rfl, rfl, h⟩
  | literal_eq => exact ⟨_, rfl, rfl⟩
  | length_eq xs => exact ⟨_, rfl, rfl⟩
  | field_eq d c fs i v h => exact ⟨v, by simp [Term.eval, h], rfl⟩
  | request_value t req => exact ⟨_, rfl, rfl⟩
  | list_shape => exact ⟨_, rfl⟩
  | @length_nonnegative t _ ih =>
      obtain ⟨xs, hx⟩ := ih
      refine ⟨fun _ => xs.length, ?_, ?_⟩
      · intro i a ha
        cases i with
        | zero =>
            have he : a = .length t := by simpa using ha.symm
            subst a
            simp [Term.eval, hx]
        | succ i => simp at ha
      · simp [lengthFact, P2.Formula.Holds, P2.Lin.Holds, P2.dot]
  | @checked ks p q cert hc _ ih =>
      obtain ⟨ν, hv, hp⟩ := ih
      exact ⟨ν, hv, P2.implication_sound p q cert hc ν hp⟩

-- σ の像は任意の構文の項。型/行の意味の所属や World は使わない。
theorem Entails.bind {Φ p} (h : Entails Φ p) (σ : Nat → Term) :
    Entails (Φ.map (Pred.bind σ)) (p.bind σ) := by
  induction h with
  | hyp hm => exact .hyp (List.mem_map.mpr ⟨_, hm, rfl⟩)
  | truth => exact .truth
  | and_intro _ _ i₁ i₂ => exact .and_intro i₁ i₂
  | and_left _ ih => exact .and_left ih
  | and_right _ ih => exact .and_right ih
  | or_left _ ih => exact .or_left ih
  | or_right _ ih => exact .or_right ih
  | false_elim _ ih => exact .false_elim ih
  | integer h => exact .integer h
  | literal_eq v => exact .literal_eq v
  | length_eq xs => exact .length_eq xs
  | field_eq d c fs i v h => exact .field_eq d c fs i v h
  | request_value t req => exact .request_value t req
  | list_shape xs => exact .list_shape xs
  | length_nonnegative _ ih => exact .length_nonnegative ih
  | checked hc _ ih => exact .checked hc ih

theorem Entails.cut {Φ Ψ p} (h : Entails Φ p)
    (hm : ∀ q ∈ Φ, Entails Ψ q) : Entails Ψ p := by
  induction h with
  | hyp h => exact hm _ h
  | truth => exact .truth
  | and_intro _ _ i₁ i₂ => exact .and_intro i₁ i₂
  | and_left _ ih => exact .and_left ih
  | and_right _ ih => exact .and_right ih
  | or_left _ ih => exact .or_left ih
  | or_right _ ih => exact .or_right ih
  | false_elim _ ih => exact .false_elim ih
  | integer h => exact .integer h
  | literal_eq v => exact .literal_eq v
  | length_eq xs => exact .length_eq xs
  | field_eq d c fs i v h => exact .field_eq d c fs i v h
  | request_value t req => exact .request_value t req
  | list_shape xs => exact .list_shape xs
  | length_nonnegative _ ih => exact .length_nonnegative ih
  | checked hc _ ih => exact .checked hc ih

theorem Pred.wf_bind {n m : Nat} (p : Pred) (hp : p.WF n)
    (σ : Nat → Term) (hs : ∀ i, i < n → (σ i).WF m) : (p.bind σ).WF m := by
  induction p with
  | truth | falsity => trivial
  | eq a b | le a b => exact ⟨a.wf_bind hp.1 σ hs, b.wf_bind hp.2 σ hs⟩
  | isList a | aligned a => exact a.wf_bind hp σ hs
  | arithmetic ks f =>
      intro t ht
      obtain ⟨u, hu, rfl⟩ := List.mem_map.mp ht
      exact u.wf_bind (hp u hu) σ hs
  | and p q ip iq | or p q ip iq => exact ⟨ip hp.1, iq hp.2⟩
  | not p ip => exact ip hp

theorem upSub_wf {n m : Nat} {σ : Nat → Term}
    (hs : ∀ i, i < n → (σ i).WF m) : ∀ i, i < n+1 → (upSub σ i).WF (m+1) := by
  intro i hi
  cases i with
  | zero => change 0 < m+1; omega
  | succ i =>
      apply Term.wf_bind _ (hs i (by omega))
      intro j hj
      change j+1 < m+1
      omega

theorem Pred.lift_open (p : Pred) (t : Term) : p.lift.open t = p := by
  simp only [lift, Pred.open, bind_comp, Term.bind, instantiate]
  exact p.bind_id

theorem Pred.lift_bind (σ : Nat → Term) (p : Pred) :
    p.lift.bind (upSub σ) = (p.bind σ).lift := by
  simp only [lift, bind_comp, Term.bind, upSub, Term.rename]

theorem Entails.apply {Φ p q} (h : Entails (p :: Φ.map Pred.lift) q)
    (t : Term) (hp : Entails Φ (p.open t)) : Entails Φ (q.open t) := by
  apply (h.bind (instantiate t)).cut
  intro r hr
  obtain ⟨u, hu, rfl⟩ := List.mem_map.mp hr
  rcases List.mem_cons.mp hu with rfl | hu
  · exact hp
  · obtain ⟨v, hv, rfl⟩ := List.mem_map.mp hu
    change Entails Φ (v.lift.open t)
    rw [Pred.lift_open]
    exact .hyp hv

#print axioms Entails.sound
#print axioms Entails.bind
#print axioms Entails.cut
#print axioms Pred.holds_bind
#print axioms Pred.open_bind
end P4
