import Std

/-!
SG: 汎用の束・段階の互換性・完全性の印。2026-10-27。
SF/Model.lean の Base/Value/Expr/EType/Cmd/Typed と非干渉の証明を土台にする。
変更: String を追加、System に束の法則を要求、閾値の観測者を法則から導出。
formal/ は import しない。本番から直接写した定義はない。
SF が構造を参照した元は formal/Benitoite/Release/Syntax.lean の
Const/Val.var/Comp.letIn/Comp.ite と Release/Typing.lean の
HasTypeVQ.V_Const/V_Var, HasTypeCQ.C_Let/C_If である。
本番の読取基準: san_benito の 0414065298d373cdb83838749eaeb1bb256d292e。
-/
namespace SG

inductive Base where
  | integer | boolean | string
  deriving DecidableEq, Repr

inductive Value where
  | integer (n : Int)
  | boolean (b : Bool)
  | string (s : String)
  deriving DecidableEq, Repr

def Value.type : Value → Base
  | .integer _ => .integer
  | .boolean _ => .boolean
  | .string _ => .string

inductive Expr where
  | lit (v : Value)
  | var (i : Nat)
  | equal (a b : Expr)
  deriving Repr

abbrev Env := Nat → Value
abbrev Ctx (L : Type) := Nat → Base × L

def push (x : α) (xs : Nat → α) : Nat → α
  | 0 => x
  | n + 1 => xs n

def eval : Expr → Env → Value
  | .lit v, _ => v
  | .var i, ρ => ρ i
  | .equal a b, ρ => .boolean (decide (eval a ρ = eval b ρ))

inductive EType (Γ : Ctx L) : Expr → Base → Prop where
  | lit (v) : EType Γ (.lit v) v.type
  | var (i) : EType Γ (.var i) (Γ i).1
  | equal {a b t} : EType Γ a t → EType Γ b t → EType Γ (.equal a b) .boolean

/-- 初期環境の通常の型と、情報の流れの印を区別する。 -/
def EnvTyped (Γ : Ctx L) (ρ : Env) : Prop := ∀ i, (ρ i).type = (Γ i).1

theorem eval_type {Γ : Ctx L} {e t} (h : EType Γ e t) {ρ}
    (hρ : EnvTyped Γ ρ) : (eval e ρ).type = t := by
  induction h with
  | lit => rfl
  | var i => exact hρ i
  | equal => rfl

/-- 最小元を持つ束。非干渉の証明は交わりを使わず、結び半束で足りる。 -/
structure FlowLattice (L : Type) where
  bottom : L
  join : L → L → L
  meet : L → L → L
  flows : L → L → Prop
  refl : ∀ a, flows a a
  trans : ∀ {a b c}, flows a b → flows b c → flows a c
  antisymm : ∀ {a b}, flows a b → flows b a → a = b
  bottom_le : ∀ a, flows bottom a
  le_join_left : ∀ a b, flows a (join a b)
  le_join_right : ∀ a b, flows b (join a b)
  join_le : ∀ {a b c}, flows a c → flows b c → flows (join a b) c
  meet_le_left : ∀ a b, flows (meet a b) a
  meet_le_right : ∀ a b, flows (meet a b) b
  le_meet : ∀ {a b c}, flows c a → flows c b → flows c (meet a b)

namespace FlowLattice

theorem join_comm (A : FlowLattice L) (a b : L) : A.join a b = A.join b a := by
  apply A.antisymm
  · exact A.join_le (A.le_join_right b a) (A.le_join_left b a)
  · exact A.join_le (A.le_join_right a b) (A.le_join_left a b)

theorem join_assoc (A : FlowLattice L) (a b c : L) :
    A.join (A.join a b) c = A.join a (A.join b c) := by
  apply A.antisymm
  · apply A.join_le
    · exact A.join_le (A.le_join_left a (A.join b c))
        (A.trans (A.le_join_left b c) (A.le_join_right a (A.join b c)))
    · exact A.trans (A.le_join_right b c) (A.le_join_right a (A.join b c))
  · apply A.join_le
    · exact A.trans (A.le_join_left a b) (A.le_join_left (A.join a b) c)
    · exact A.join_le
        (A.trans (A.le_join_right a b) (A.le_join_left (A.join a b) c))
        (A.le_join_right (A.join a b) c)

theorem join_idem (A : FlowLattice L) (a : L) : A.join a a = a :=
  A.antisymm (A.join_le (A.refl a) (A.refl a)) (A.le_join_left a a)

theorem join_bottom (A : FlowLattice L) (a : L) : A.join A.bottom a = a :=
  A.antisymm (A.join_le (A.bottom_le a) (A.refl a)) (A.le_join_right A.bottom a)

end FlowLattice

structure System (L D : Type) extends FlowLattice L where
  sink : D → L

/-- 一人の観測者について証明に必要な法則。段2では有界束の法則も示す。 -/
structure Observer (S : System L D) where
  visible : L → Bool
  bottom_visible : visible S.bottom = true
  join_visible : ∀ a b, visible (S.join a b) = (visible a && visible b)
  flows_visible : ∀ {a b}, S.flows a b → visible b = true → visible a = true

def label (S : System L D) (Γ : Ctx L) : Expr → L
  | .lit _ => S.bottom
  | .var i => (Γ i).2
  | .equal a b => S.join (label S Γ a) (label S Γ b)

inductive Cmd (D : Type) where
  | skip
  | letIn (e : Expr) (body : Cmd D)
  | seq (a b : Cmd D)
  | ite (e : Expr) (yes no : Cmd D)
  | send (dest : D) (e : Expr)
  deriving Repr

abbrev Trace (D : Type) := List (D × Value)

/-- let は外側の環境を変更しないため、分岐後のストアの対応を要しない。 -/
def run : Cmd D → Env → Trace D
  | .skip, _ => []
  | .letIn e body, ρ => run body (push (eval e ρ) ρ)
  | .seq a b, ρ => run a ρ ++ run b ρ
  | .ite e yes no, ρ =>
      if eval e ρ = .boolean true then run yes ρ else run no ρ
  | .send d e, ρ => [(d, eval e ρ)]

inductive Typed (S : System L D) : Ctx L → L → Cmd D → Prop where
  | skip {Γ pc} : Typed S Γ pc .skip
  | letIn {Γ pc e body t} :
      EType Γ e t →
      Typed S (push (t, S.join pc (label S Γ e)) Γ) pc body →
      Typed S Γ pc (.letIn e body)
  | seq {Γ pc a b} : Typed S Γ pc a → Typed S Γ pc b → Typed S Γ pc (.seq a b)
  | ite {Γ pc e yes no} :
      EType Γ e .boolean →
      Typed S Γ (S.join pc (label S Γ e)) yes →
      Typed S Γ (S.join pc (label S Γ e)) no →
      Typed S Γ pc (.ite e yes no)
  | send {Γ pc d e t} :
      EType Γ e t → S.flows (S.join pc (label S Γ e)) (S.sink d) →
      Typed S Γ pc (.send d e)

variable {L D : Type} {S : System L D}

def LowEq (O : Observer S) (Γ : Ctx L) (ρ σ : Env) : Prop :=
  ∀ i, O.visible (Γ i).2 = true → ρ i = σ i

def observe (O : Observer S) (tr : Trace D) : Trace D :=
  tr.filter fun ev => O.visible (S.sink ev.1)

theorem observe_append (O : Observer S) (a b : Trace D) :
    observe O (a ++ b) = observe O a ++ observe O b := by
  simp [observe, List.filter_append]

theorem visible_join_left (O : Observer S) {a b}
    (h : O.visible (S.join a b) = true) : O.visible a = true := by
  have hh : O.visible a = true ∧ O.visible b = true := by
    simpa only [O.join_visible, Bool.and_eq_true] using h
  exact hh.1

theorem visible_join_right (O : Observer S) {a b}
    (h : O.visible (S.join a b) = true) : O.visible b = true := by
  have hh : O.visible a = true ∧ O.visible b = true := by
    simpa only [O.join_visible, Bool.and_eq_true] using h
  exact hh.2

theorem hidden_join_left (O : Observer S) {a b}
    (h : O.visible a = false) : O.visible (S.join a b) = false := by
  simp [O.join_visible, h]

theorem hidden_join_right (O : Observer S) {a b}
    (h : O.visible b = false) : O.visible (S.join a b) = false := by
  simp [O.join_visible, h]

theorem expr_low_eq (O : Observer S) {Γ ρ σ} (hρσ : LowEq O Γ ρ σ)
    (e : Expr) (he : O.visible (label S Γ e) = true) : eval e ρ = eval e σ := by
  induction e with
  | lit => rfl
  | var i => exact hρσ i he
  | equal a b ia ib =>
      rw [eval, eval, ia (visible_join_left O he), ib (visible_join_right O he)]

theorem lowEq_push (O : Observer S) {Γ ρ σ t l v w}
    (h : LowEq O Γ ρ σ) (hv : O.visible l = true → v = w) :
    LowEq O (push (t, l) Γ) (push v ρ) (push w σ) := by
  intro i hi
  cases i with
  | zero => exact hv hi
  | succ i => exact h i hi

/-- 観測者に見えないpcから、観測者が見える事象を出せないことを示す。 -/
theorem high_pc (O : Observer S) {Γ pc c} (ht : Typed S Γ pc c) :
    O.visible pc = false → ∀ ρ, observe O (run c ρ) = [] := by
  induction ht with
  | skip => intro _ _; rfl
  | letIn _ _ ih => intro hp ρ; exact ih hp (push _ ρ)
  | seq _ _ ia ib =>
      intro hp ρ
      simp only [run, observe_append, ia hp ρ, ib hp ρ, List.nil_append]
  | ite _ _ _ ia ib =>
      intro hp ρ
      simp only [run]
      split <;> first
        | exact ia (hidden_join_left O hp) ρ
        | exact ib (hidden_join_left O hp) ρ
  | @send Γ pc d e t he hf =>
      intro hp ρ
      have hn : O.visible (S.sink d) = false := by
        cases hs : O.visible (S.sink d) with
        | false => rfl
        | true =>
            have hv := visible_join_left O (O.flows_visible hf hs)
            simp [hp] at hv
      simp [run, observe, hn]

/-- 秘密の入力だけが違う二実行から、同じ公開出力列を得る。
対象言語の計算は全て終了するので、停止を観測から除いた主張も満たす。
発散を含む言語についての定理へは広げない。
-/
theorem noninterference (O : Observer S) {Γ pc c} (ht : Typed S Γ pc c) :
    ∀ {ρ σ}, LowEq O Γ ρ σ → observe O (run c ρ) = observe O (run c σ) := by
  induction ht with
  | skip => intro ρ σ _; rfl
  | letIn he hb ih =>
      intro ρ σ h
      apply ih (lowEq_push O h ?_)
      intro hv
      exact expr_low_eq O h _ (visible_join_right O hv)
  | seq ha hb ia ib =>
      intro ρ σ h
      simp only [run, observe_append, ia h, ib h]
  | @ite Γ pc e yes no he hy hn iy ino =>
      intro ρ σ h
      cases hv : O.visible (label S Γ e) with
      | true =>
          have eqv := expr_low_eq O h e hv
          simp only [run, eqv]
          split
          · exact iy h
          · exact ino h
      | false =>
          have hp := hidden_join_right O (a := pc) hv
          have eyρ := high_pc O hy hp ρ
          have enρ := high_pc O hn hp ρ
          have eyσ := high_pc O hy hp σ
          have enσ := high_pc O hn hp σ
          simp only [run]
          split <;> split <;> simp_all
  | @send Γ pc d e t he hf =>
      intro ρ σ h
      cases hd : O.visible (S.sink d) with
      | false => simp [run, observe, hd]
      | true =>
          have hv := visible_join_right O (O.flows_visible hf hd)
          have eqv := expr_low_eq O h e hv
          simp only [run, eqv]


/-! ## 段1: 観測者の条件を任意の束の法則から導く。 -/
def atLevel (S : System L D) [DecidableRel S.flows] (o : L) : Observer S where
  visible := fun l => decide (S.flows l o)
  bottom_visible := decide_eq_true (S.bottom_le o)
  join_visible := by
    intro a b
    apply Bool.eq_iff_iff.mpr
    simp only [decide_eq_true_eq, Bool.and_eq_true]
    exact ⟨fun h => ⟨S.trans (S.le_join_left a b) h,
      S.trans (S.le_join_right a b) h⟩, fun h => S.join_le h.1 h.2⟩
  flows_visible := by
    intro a b hab hb
    exact decide_eq_true (S.trans hab (of_decide_eq_true hb))

theorem lattice_noninterference (S : System L D) [DecidableRel S.flows]
    (o : L) {Γ pc c} (ht : Typed S Γ pc c) {ρ σ}
    (he : LowEq (atLevel S o) Γ ρ σ) :
    observe (atLevel S o) (run c ρ) = observe (atLevel S o) (run c σ) :=
  noninterference (atLevel S o) ht he

/-- 順序が決定不能な束にも定理を述べられる。実行できる判定器は得ない。 -/
noncomputable def abstractObserver (S : System L D) (o : L) : Observer S := by
  classical
  exact atLevel S o

theorem arbitrary_lattice_noninterference (S : System L D) (o : L) {Γ pc c}
    (ht : Typed S Γ pc c) {ρ σ} (he : LowEq (abstractObserver S o) Γ ρ σ) :
    observe (abstractObserver S o) (run c ρ) = observe (abstractObserver S o) (run c σ) :=
  noninterference (abstractObserver S o) ht he

/-! ## 段2: 有限の秘密の分類。Phase 1 の規則は独立した帰納的定義。 -/
namespace FiniteSecrets

abbrev Label (n : Nat) := Fin n → Bool

def empty : Label n := fun _ => false
def union (a b : Label n) : Label n := fun k => a k || b k
def inter (a b : Label n) : Label n := fun k => a k && b k
def Subset (a b : Label n) : Prop := ∀ k, a k = true → b k = true

instance : DecidableRel (Subset (n := n)) := fun _ _ => by
  unfold Subset
  infer_instance

def lattice (n : Nat) : FlowLattice (Label n) where
  bottom := empty
  join := union
  meet := inter
  flows := Subset
  refl := fun _ _ h => h
  trans := fun h₁ h₂ k h => h₂ k (h₁ k h)
  antisymm := by
    intro a b hab hba
    funext k
    cases ha : a k <;> cases hb : b k <;> simp_all [Subset]
  bottom_le := by intro a k h; cases h
  le_join_left := by intro a b k h; simp [union, h]
  le_join_right := by intro a b k h; simp [union, h]
  join_le := by
    intro a b c ha hb k h
    have hh : a k = true ∨ b k = true := by
      simpa only [union, Bool.or_eq_true] using h
    rcases hh with h | h
    · exact ha k h
    · exact hb k h
  meet_le_left := by
    intro a b k h
    have hh : a k = true ∧ b k = true := by simpa only [inter, Bool.and_eq_true] using h
    exact hh.1
  meet_le_right := by
    intro a b k h
    have hh : a k = true ∧ b k = true := by simpa only [inter, Bool.and_eq_true] using h
    exact hh.2
  le_meet := by intro a b c ha hb k h; simp [inter, ha k h, hb k h]

def system (accept : D → Label n) : System (Label n) D where
  toFlowLattice := lattice n
  sink := accept

instance (accept : D → Label n) : DecidableRel (system accept).flows :=
  inferInstanceAs (DecidableRel Subset)

/-- Phase 1 の表現で、秘密の分類の和を直接計算する。 -/
def phaseLabel (Γ : Ctx (Label n)) : Expr → Label n
  | .lit _ => empty
  | .var i => (Γ i).2
  | .equal a b => union (phaseLabel Γ a) (phaseLabel Γ b)

/-- 汎用 Typed の別名や写像で定義せず、有限集合の規則を独立に与える。 -/
inductive PhaseTyped (accept : D → Label n) : Ctx (Label n) → Label n → Cmd D → Prop where
  | skip {Γ pc} : PhaseTyped accept Γ pc .skip
  | letIn {Γ pc e body t} : EType Γ e t →
      PhaseTyped accept (push (t, union pc (phaseLabel Γ e)) Γ) pc body →
      PhaseTyped accept Γ pc (.letIn e body)
  | seq {Γ pc a b} : PhaseTyped accept Γ pc a → PhaseTyped accept Γ pc b →
      PhaseTyped accept Γ pc (.seq a b)
  | ite {Γ pc e yes no} : EType Γ e .boolean →
      PhaseTyped accept Γ (union pc (phaseLabel Γ e)) yes →
      PhaseTyped accept Γ (union pc (phaseLabel Γ e)) no →
      PhaseTyped accept Γ pc (.ite e yes no)
  | send {Γ pc d e t} : EType Γ e t →
      Subset (union pc (phaseLabel Γ e)) (accept d) →
      PhaseTyped accept Γ pc (.send d e)

theorem phaseLabel_eq (accept : D → Label n) (Γ : Ctx (Label n)) (e : Expr) :
    phaseLabel Γ e = label (system accept) Γ e := by
  induction e with
  | lit => rfl
  | var => rfl
  | equal a b ia ib => simp only [phaseLabel, label, ia, ib]; rfl

theorem phase_to_generic {accept : D → Label n} {Γ pc c}
    (h : PhaseTyped accept Γ pc c) : Typed (system accept) Γ pc c := by
  induction h with
  | skip => exact .skip
  | letIn he hb ih =>
      apply Typed.letIn he
      simpa only [phaseLabel_eq accept, system, lattice] using ih
  | seq ha hb ia ib => exact .seq ia ib
  | ite he hy hn iy ino =>
      apply Typed.ite he
      · simpa only [phaseLabel_eq accept, system, lattice] using iy
      · simpa only [phaseLabel_eq accept, system, lattice] using ino
  | send he hf =>
      apply Typed.send he
      simpa only [phaseLabel_eq accept, system, lattice] using hf

theorem generic_to_phase {accept : D → Label n} {Γ pc c}
    (h : Typed (system accept) Γ pc c) : PhaseTyped accept Γ pc c := by
  induction h with
  | skip => exact .skip
  | letIn he hb ih =>
      apply PhaseTyped.letIn he
      simpa only [phaseLabel_eq accept, system, lattice] using ih
  | seq ha hb ia ib => exact .seq ia ib
  | ite he hy hn iy ino =>
      apply PhaseTyped.ite he
      · simpa only [phaseLabel_eq accept, system, lattice] using iy
      · simpa only [phaseLabel_eq accept, system, lattice] using ino
  | send he hf =>
      apply PhaseTyped.send he
      simpa only [phaseLabel_eq accept, system, lattice] using hf

theorem phase_iff_generic {accept : D → Label n} {Γ pc c} :
    PhaseTyped accept Γ pc c ↔ Typed (system accept) Γ pc c :=
  ⟨phase_to_generic, generic_to_phase⟩

/-- Phase 1 自身の観測: 観測者が許されない分類を含む値は不可視。 -/
def phaseVisible (o l : Label n) : Bool := decide (Subset l o)
def PhaseLowEq (o : Label n) (Γ : Ctx (Label n)) (ρ σ : Env) : Prop :=
  ∀ i, phaseVisible o (Γ i).2 = true → ρ i = σ i

def phaseObserve (accept : D → Label n) (o : Label n) (tr : Trace D) : Trace D :=
  tr.filter fun ev => phaseVisible o (accept ev.1)

theorem phase_noninterference {accept : D → Label n} (o : Label n) {Γ pc c}
    (ht : PhaseTyped accept Γ pc c) {ρ σ} (he : PhaseLowEq o Γ ρ σ) :
    phaseObserve accept o (run c ρ) = phaseObserve accept o (run c σ) :=
  lattice_noninterference (system accept) o (phase_to_generic ht) he

inductive Dest where
  | console | api | privateFile
  deriving DecidableEq, Repr

/-- 2分類: 0 は service-token、1 は private-config。 -/
def token : Label 2 := fun k => k == 0
def all : Label 2 := fun _ => true

def accept : Dest → Label 2
  | .console => empty
  | .api => token
  | .privateFile => all

def context : Ctx (Label 2) := fun i =>
  if i = 0 then (.string, token) else (.string, empty)

theorem phase_accepts_api : PhaseTyped accept context empty (.send .api (.var 0)) := by
  apply PhaseTyped.send (EType.var 0)
  intro k hk
  simpa [union, phaseLabel, context, empty, accept] using hk

theorem generic_accepts_same_program :
    Typed (system accept) context empty (.send .api (.var 0)) :=
  phase_iff_generic.mp phase_accepts_api

theorem phase_rejects_console : ¬ PhaseTyped accept context empty (.send .console (.var 0)) := by
  intro h
  cases h with
  | send _ hf =>
      have hf := hf 0 (by decide)
      cases hf

#guard phaseVisible empty token == false
#guard phaseVisible token token == true
#guard phaseVisible empty (union token empty) == false

end FiniteSecrets

/-! ## 段3: 機密性と完全性の積。 -/

def productLattice (A : FlowLattice L) (B : FlowLattice I) : FlowLattice (L × I) where
  bottom := (A.bottom, B.bottom)
  join := fun a b => (A.join a.1 b.1, B.join a.2 b.2)
  meet := fun a b => (A.meet a.1 b.1, B.meet a.2 b.2)
  flows := fun a b => A.flows a.1 b.1 ∧ B.flows a.2 b.2
  refl := fun a => ⟨A.refl a.1, B.refl a.2⟩
  trans := fun h₁ h₂ => ⟨A.trans h₁.1 h₂.1, B.trans h₁.2 h₂.2⟩
  antisymm := fun h₁ h₂ => Prod.ext (A.antisymm h₁.1 h₂.1) (B.antisymm h₁.2 h₂.2)
  bottom_le := fun a => ⟨A.bottom_le a.1, B.bottom_le a.2⟩
  le_join_left := fun a b => ⟨A.le_join_left a.1 b.1, B.le_join_left a.2 b.2⟩
  le_join_right := fun a b => ⟨A.le_join_right a.1 b.1, B.le_join_right a.2 b.2⟩
  join_le := fun ha hb => ⟨A.join_le ha.1 hb.1, B.join_le ha.2 hb.2⟩
  meet_le_left := fun a b => ⟨A.meet_le_left a.1 b.1, B.meet_le_left a.2 b.2⟩
  meet_le_right := fun a b => ⟨A.meet_le_right a.1 b.1, B.meet_le_right a.2 b.2⟩
  le_meet := fun ha hb => ⟨A.le_meet ha.1 hb.1, B.le_meet ha.2 hb.2⟩

namespace Integrity
open FiniteSecrets (empty all)

/-- false は信頼する値、true は信頼しない値。
信頼度の高低に対して双対の「汚染」の順序 trusted ⊑ untrusted を使う。
任意の Bool を型だけで trusted にする規則はない。 -/
def taintLattice : FlowLattice Bool where
  bottom := false
  join := Bool.or
  meet := Bool.and
  flows := fun a b => a = true → b = true
  refl := fun _ h => h
  trans := fun hab hbc h => hbc (hab h)
  antisymm := by intro a b hab hba; cases a <;> cases b <;> simp_all
  bottom_le := by intro a h; cases h
  le_join_left := by intro a b h; simp [h]
  le_join_right := by intro a b h; simp [h]
  join_le := by intro a b c ha hb h; cases a <;> cases b <;> simp_all
  meet_le_left := by intro a b h; cases a <;> cases b <;> simp_all
  meet_le_right := by intro a b h; cases a <;> cases b <;> simp_all
  le_meet := by intro a b c ha hb h; simp [ha h, hb h]

abbrev Label := FiniteSecrets.Label 2 × Bool

def lattice : FlowLattice Label := productLattice (FiniteSecrets.lattice 2) taintLattice

inductive Dest where
  | console | exec | vault
  deriving DecidableEq, Repr

/-- exec は全分類を扱えても信頼しない入力を受け付けない。 -/
def accept : Dest → Label
  | .console => (empty, true)
  | .exec => (all, false)
  | .vault => (all, true)

def system : System Label Dest where
  toFlowLattice := lattice
  sink := accept

instance : DecidableRel system.flows := fun a b => by
  change Decidable (FiniteSecrets.Subset a.1 b.1 ∧ (a.2 = true → b.2 = true))
  infer_instance

/-- 機密性の全分類を許す一方、信頼を要する出口だけを観測する。 -/
def trustedObserver : Observer system := atLevel system (all, false)

theorem sees_exec_only (d : Dest) :
    trustedObserver.visible (system.sink d) = decide (d = .exec) := by
  cases d <;> decide

/-- 普通のプログラムでは、信頼しない入力を変えても exec の列は変わらない。 -/
theorem integrity_noninterference {Γ pc c} (ht : Typed system Γ pc c)
    {ρ σ} (he : LowEq trustedObserver Γ ρ σ) :
    observe trustedObserver (run c ρ) = observe trustedObserver (run c σ) :=
  lattice_noninterference system (all, false) ht he

def confidentialityObserver (o : FiniteSecrets.Label 2) : Observer system :=
  atLevel system (o, true)

theorem confidentiality_noninterference (o : FiniteSecrets.Label 2) {Γ pc c}
    (ht : Typed system Γ pc c) {ρ σ} (he : LowEq (confidentialityObserver o) Γ ρ σ) :
    observe (confidentialityObserver o) (run c ρ) =
      observe (confidentialityObserver o) (run c σ) :=
  lattice_noninterference system (o, true) ht he

def publicTrusted : Label := (empty, false)
def publicUntrusted : Label := (empty, true)

def context : Ctx Label := fun i =>
  if i = 0 then (.string, publicUntrusted) else (.string, publicTrusted)

def badCommand : Cmd Dest := .send .exec (.var 0)
def badControl : Cmd Dest := .ite (.equal (.var 0) (.lit (.string "yes")))
  (.send .exec (.lit (.string "/usr/bin/true"))) .skip

theorem reject_unchecked_command : ¬ Typed system context publicTrusted badCommand := by
  intro h
  cases h with
  | send _ hf =>
      have hf := hf.2
      simp [system, lattice, productLattice, taintLattice, label, context,
        publicTrusted, publicUntrusted, accept] at hf

theorem reject_untrusted_control : ¬ Typed system context publicTrusted badControl := by
  intro h
  cases h with
  | ite _ hy _ =>
      cases hy with
      | send _ hf =>
          have hf := hf.2
          simp [system, lattice, productLattice, taintLattice, label, context,
            publicTrusted, publicUntrusted, accept] at hf

def safeProgram : Cmd Dest := .seq (.send .console (.var 0)) (.send .exec (.var 1))

theorem safeProgram_typed : Typed system context publicTrusted safeProgram := by
  apply Typed.seq
  · apply Typed.send (EType.var 0)
    constructor
    · intro k hk
      simp [system, lattice, productLattice, label, context, publicTrusted,
        publicUntrusted, FiniteSecrets.union, FiniteSecrets.empty, FiniteSecrets.lattice] at hk
    · intro _; rfl
  · apply Typed.send (EType.var 1)
    constructor
    · intro _ _; rfl
    · simp [system, lattice, productLattice, taintLattice, label, context,
        publicTrusted]

def state (s : String) : Env := fun i =>
  if i = 0 then .string s else .string "/usr/bin/true"

theorem untrusted_inputs_related (s t : String) :
    LowEq trustedObserver context (state s) (state t) := by
  intro i hi
  by_cases h : i = 0
  · subst i
    have hn : trustedObserver.visible (context 0).2 = false := by decide
    rw [hn] at hi
    cases hi
  · simp [state, h]

theorem trusted_commands_unchanged (s t : String) :
    observe trustedObserver (run safeProgram (state s)) =
      observe trustedObserver (run safeProgram (state t)) :=
  integrity_noninterference safeProgram_typed (untrusted_inputs_related s t)

#guard observe trustedObserver (run safeProgram (state "attacker")) ==
  [(.exec, .string "/usr/bin/true")]
#guard observe trustedObserver (run badCommand (state "attacker")) !=
  observe trustedObserver (run badCommand (state "other"))

/-! Endorsement は束の順序を破る、方針に記された検査である。
この節だけでは通常の非干渉を主張せず、許した検査結果の一致を前提とする。
入口は top-level に一つ、入力の機密性は public に限る。
検査に失敗すると出力なしで終える。OS の失敗や診断はまだモデル外。 -/
structure Policy where
  permits : Nat → Bool
  check : Nat → Value → Option Value
  approved : Value → Prop
  check_sound : ∀ r x v, permits r = true → check r x = some v →
    v.type = .string ∧ approved v

def runEndorse (P : Policy) (rule : Nat) (e : Expr) (body : Cmd Dest) (ρ : Env) : Trace Dest :=
  if P.permits rule then
    match P.check rule (eval e ρ) with
    | none => []
    | some v => run body (push v ρ)
  else []

structure EndorseTyped (P : Policy) (Γ : Ctx Label) (pc : Label)
    (rule : Nat) (e : Expr) (body : Cmd Dest) : Prop where
  input : EType Γ e .string
  permitted : P.permits rule = true
  publicInput : (label system Γ e).1 = empty
  trustedPc : pc.2 = false
  body : Typed system (push (.string, publicTrusted) Γ) pc body

theorem endorsement_noninterference (P : Policy) (O : Observer system)
    {Γ pc rule e body} (ht : EndorseTyped P Γ pc rule e body) {ρ σ}
    (he : LowEq O Γ ρ σ)
    (hc : P.check rule (eval e ρ) = P.check rule (eval e σ)) :
    observe O (runEndorse P rule e body ρ) = observe O (runEndorse P rule e body σ) := by
  simp only [runEndorse, ht.permitted, ↓reduceIte]
  rw [← hc]
  cases hcheck : P.check rule (eval e ρ) with
  | none => rfl
  | some v =>
      exact noninterference O ht.body (lowEq_push O he (fun _ => rfl))

/-- public な入力だけを endorsement するため、機密性の保証は弱めない。 -/
theorem endorsement_preserves_confidentiality (P : Policy) (o : FiniteSecrets.Label 2)
    {Γ pc rule e body} (ht : EndorseTyped P Γ pc rule e body) {ρ σ}
    (he : LowEq (confidentialityObserver o) Γ ρ σ) :
    observe (confidentialityObserver o) (runEndorse P rule e body ρ) =
      observe (confidentialityObserver o) (runEndorse P rule e body σ) := by
  apply endorsement_noninterference P (confidentialityObserver o) ht he
  have hv : (confidentialityObserver o).visible (label system Γ e) = true := by
    apply decide_eq_true
    change FiniteSecrets.Subset (label system Γ e).1 o ∧
      ((label system Γ e).2 = true → true = true)
    constructor
    · rw [ht.publicInput]
      exact (FiniteSecrets.lattice 2).bottom_le o
    · intro _; rfl
  rw [expr_low_eq (confidentialityObserver o) he e hv]

theorem endorsement_env_typed (P : Policy) {Γ pc rule e body ρ v}
    (ht : EndorseTyped P Γ pc rule e body) (hρ : EnvTyped Γ ρ)
    (hv : P.check rule (eval e ρ) = some v) :
    EnvTyped (push (.string, publicTrusted) Γ) (push v ρ) := by
  intro i
  cases i with
  | zero => exact (P.check_sound rule _ v ht.permitted hv).1
  | succ i => exact hρ i

/-- 方針に許した検査だけが、検査済みの文字列を trusted として束縛できる。 -/
def checkedExec : Cmd Dest := .send .exec (.var 0)

theorem checkedExec_typed {Γ pc} (hp : pc.2 = false) :
    Typed system (push (.string, publicTrusted) Γ) pc checkedExec := by
  apply Typed.send (EType.var 0)
  constructor
  · intro _ _; rfl
  · change (pc.2 || false) = true → false = true
    simp [hp]

theorem endorsed_command_approved (P : Policy) {r e ρ d v}
    (hp : P.permits r = true)
    (hv : (d, v) ∈ runEndorse P r e checkedExec ρ) : d = .exec ∧ P.approved v := by
  simp only [runEndorse, hp, ↓reduceIte] at hv
  cases hc : P.check r (eval e ρ) with
  | none => simp [hc] at hv
  | some w =>
      simp only [hc, checkedExec, run, eval, push, List.mem_cons, List.not_mem_nil,
        or_false, Prod.mk.injEq] at hv
      rcases hv with ⟨hd, hval⟩
      exact ⟨hd, hval ▸ (P.check_sound r _ w hp hc).2⟩

def fixedPolicy : Policy where
  permits := fun r => r == 0
  check := fun _ v => match v with
    | .string s => if s = "/usr/bin/true" ∨ s = "/usr/bin/false" then some v else none
    | _ => none
  approved := fun v => v = .string "/usr/bin/true" ∨ v = .string "/usr/bin/false"
  check_sound := by
    intro r x v _ hc
    cases x with
    | integer => simp at hc
    | boolean => simp at hc
    | string s =>
        change (if s = "/usr/bin/true" ∨ s = "/usr/bin/false" then
          some (.string s) else none) = some v at hc
        by_cases hs : s = "/usr/bin/true" ∨ s = "/usr/bin/false"
        · simp only [ite_eq_left hs, Option.some.injEq] at hc
          subst v
          exact ⟨rfl, by simpa only [Value.string.injEq] using hs⟩
        · simp [hs] at hc

theorem accepts_checked_command :
    EndorseTyped fixedPolicy context publicTrusted 0 (.var 0) checkedExec := by
  constructor
  · exact .var 0
  · rfl
  · rfl
  · rfl
  · exact checkedExec_typed rfl

theorem rejects_unpermitted_endorsement :
    ¬ EndorseTyped fixedPolicy context publicTrusted 1 (.var 0) checkedExec := by
  intro h
  have h := h.permitted
  cases h

/-- 方針で許した結果まで任意に変えれば、通常の完全性の非干渉は成り立たない。 -/
theorem unconditional_endorsement_NI_false :
    LowEq trustedObserver context (state "/usr/bin/true") (state "/usr/bin/false") ∧
    observe trustedObserver (runEndorse fixedPolicy 0 (.var 0) checkedExec (state "/usr/bin/true")) ≠
    observe trustedObserver (runEndorse fixedPolicy 0 (.var 0) checkedExec (state "/usr/bin/false")) := by
  constructor
  · exact untrusted_inputs_related _ _
  · decide

#guard runEndorse fixedPolicy 0 (.var 0) checkedExec (state "/usr/bin/true") ==
  [(.exec, .string "/usr/bin/true")]
#guard runEndorse fixedPolicy 0 (.var 0) checkedExec (state "rm -rf /") == []
#guard runEndorse fixedPolicy 1 (.var 0) checkedExec (state "/usr/bin/true") == []

end Integrity

/-! Phase 2 で完全性の次元を加える場合の、追加の一方向の対応。
既存の全入力・出口に trusted を割り当てる埋め込みに限る。
既存の外部入力を untrusted に再分類した場合の互換性は主張しない。 -/
namespace Compatibility
open FiniteSecrets (PhaseTyped phaseLabel empty union)

abbrev Label (n : Nat) := FiniteSecrets.Label n × Bool

def liftLabel (l : FiniteSecrets.Label n) : Label n := (l, false)
def liftCtx (Γ : Ctx (FiniteSecrets.Label n)) : Ctx (Label n) :=
  fun i => ((Γ i).1, liftLabel (Γ i).2)

def system (accept : D → FiniteSecrets.Label n) : System (Label n) D where
  toFlowLattice := productLattice (FiniteSecrets.lattice n) Integrity.taintLattice
  sink := fun d => liftLabel (accept d)

theorem lift_join (accept : D → FiniteSecrets.Label n) (a b : FiniteSecrets.Label n) :
    (system accept).join (liftLabel a) (liftLabel b) = liftLabel (union a b) := rfl

theorem lift_push (Γ : Ctx (FiniteSecrets.Label n)) (t : Base) (l : FiniteSecrets.Label n) :
    liftCtx (push (t, l) Γ) = push (t, liftLabel l) (liftCtx Γ) := by
  funext i
  cases i <;> rfl

theorem lift_label (accept : D → FiniteSecrets.Label n) (Γ : Ctx (FiniteSecrets.Label n)) (e : Expr) :
    label (system accept) (liftCtx Γ) e = liftLabel (phaseLabel Γ e) := by
  induction e with
  | lit => rfl
  | var => rfl
  | equal a b ia ib => simp only [label, phaseLabel, ia, ib, lift_join]

theorem lift_etype {Γ : Ctx (FiniteSecrets.Label n)} {e t} (h : EType Γ e t) :
    EType (liftCtx Γ) e t := by
  induction h with
  | lit v => exact .lit v
  | var i => exact .var i
  | equal ha hb ia ib => exact .equal ia ib

theorem phase1_lifts_to_product {accept : D → FiniteSecrets.Label n} {Γ pc c}
    (h : PhaseTyped accept Γ pc c) :
    Typed (system accept) (liftCtx Γ) (liftLabel pc) c := by
  induction h with
  | skip => exact .skip
  | letIn he hb ih =>
      apply Typed.letIn (lift_etype he)
      simpa only [lift_label, lift_join, ← lift_push] using ih
  | seq ha hb ia ib => exact .seq ia ib
  | ite he hy hn iy ino =>
      apply Typed.ite (lift_etype he)
      · simpa only [lift_label, lift_join] using iy
      · simpa only [lift_label, lift_join] using ino
  | send he hf =>
      apply Typed.send (lift_etype he)
      rw [lift_label, lift_join]
      exact ⟨hf, by intro h; cases h⟩

end Compatibility

/-! ## 段4(a): fail の後の出力を打ち切り、成功/失敗も観測する。 -/
namespace Failure

inductive Cmd (D : Type) where
  | skip
  | letIn (e : Expr) (body : Cmd D)
  | seq (a b : Cmd D)
  | ite (e : Expr) (yes no : Cmd D)
  | send (d : D) (e : Expr)
  | fail
  deriving Repr

inductive Result (D : Type) where
  | done (trace : Trace D)
  | failed (trace : Trace D)
  deriving DecidableEq, Repr

def Result.then (a b : Result D) : Result D :=
  match a, b with
  | .failed tr, _ => .failed tr
  | .done ta, .done tb => .done (ta ++ tb)
  | .done ta, .failed tb => .failed (ta ++ tb)

/-- trace の投影は成功/失敗を消さない。 -/
def observeResult (O : Observer S) : Result D → Result D
  | .done tr => .done (observe O tr)
  | .failed tr => .failed (observe O tr)

def run : Cmd D → Env → Result D
  | .skip, _ => .done []
  | .letIn e body, ρ => run body (push (eval e ρ) ρ)
  | .seq a b, ρ => (run a ρ).then (run b ρ)
  | .ite e yes no, ρ =>
      if eval e ρ = .boolean true then run yes ρ else run no ρ
  | .send d e, ρ => .done [(d, eval e ρ)]
  | .fail, _ => .failed []

/-- 公開の終了状態を守るため、fail は公開の pc からだけ許す。 -/
inductive Typed (S : System L D) : Ctx L → L → Cmd D → Prop where
  | skip {Γ pc} : Typed S Γ pc .skip
  | letIn {Γ pc e body t} : EType Γ e t →
      Typed S (push (t, S.join pc (label S Γ e)) Γ) pc body →
      Typed S Γ pc (.letIn e body)
  | seq {Γ pc a b} : Typed S Γ pc a → Typed S Γ pc b → Typed S Γ pc (.seq a b)
  | ite {Γ pc e yes no} : EType Γ e .boolean →
      Typed S Γ (S.join pc (label S Γ e)) yes →
      Typed S Γ (S.join pc (label S Γ e)) no →
      Typed S Γ pc (.ite e yes no)
  | send {Γ pc d e t} : EType Γ e t →
      S.flows (S.join pc (label S Γ e)) (S.sink d) → Typed S Γ pc (.send d e)
  | fail {Γ pc} : S.flows pc S.bottom → Typed S Γ pc .fail

theorem observe_then (O : Observer S) (a b : Result D) :
    observeResult O (a.then b) = (observeResult O a).then (observeResult O b) := by
  cases a <;> cases b <;> simp [Result.then, observeResult, observe_append]

/-- 見えない pc では、見える出力だけでなく公開の失敗も起こせない。 -/
theorem high_pc (O : Observer S) {Γ pc c} (ht : Typed S Γ pc c) :
    O.visible pc = false → ∀ ρ, observeResult O (run c ρ) = .done [] := by
  induction ht with
  | skip => intro _ _; rfl
  | letIn _ _ ih => intro hp ρ; exact ih hp (push _ ρ)
  | @seq Γ pc a b ha hb ia ib =>
      intro hp ρ
      change observeResult O ((run a ρ).then (run b ρ)) = .done []
      rw [observe_then, ia hp ρ, ib hp ρ]
      rfl
  | ite _ _ _ ia ib =>
      intro hp ρ
      simp only [run]
      split <;> first
        | exact ia (hidden_join_left O hp) ρ
        | exact ib (hidden_join_left O hp) ρ
  | @send Γ pc d e t he hf =>
      intro hp ρ
      have hn : O.visible (S.sink d) = false := by
        cases hs : O.visible (S.sink d) with
        | false => rfl
        | true =>
            have hv := visible_join_left O (O.flows_visible hf hs)
            simp [hp] at hv
      simp [run, observeResult, observe, hn]
  | fail hf =>
      intro hp _
      have hv := O.flows_visible hf O.bottom_visible
      rw [hp] at hv
      cases hv

/-- 両方の成功を仮定せず、失敗まで含めた結果と出力列が一致する。 -/
theorem noninterference (O : Observer S) {Γ pc c} (ht : Typed S Γ pc c) :
    ∀ {ρ σ}, LowEq O Γ ρ σ →
      observeResult O (run c ρ) = observeResult O (run c σ) := by
  induction ht with
  | skip => intro ρ σ _; rfl
  | letIn he hb ih =>
      intro ρ σ h
      apply ih (lowEq_push O h ?_)
      intro hv
      exact expr_low_eq O h _ (visible_join_right O hv)
  | seq ha hb ia ib =>
      intro ρ σ h
      simp only [run, observe_then, ia h, ib h]
  | @ite Γ pc e yes no he hy hn iy ino =>
      intro ρ σ h
      cases hv : O.visible (label S Γ e) with
      | true =>
          have eqv := expr_low_eq O h e hv
          simp only [run, eqv]
          split
          · exact iy h
          · exact ino h
      | false =>
          have hp := hidden_join_right O (a := pc) hv
          have eyρ := high_pc O hy hp ρ
          have enρ := high_pc O hn hp ρ
          have eyσ := high_pc O hy hp σ
          have enσ := high_pc O hn hp σ
          simp only [run]
          split <;> split <;> simp_all
  | @send Γ pc d e t he hf =>
      intro ρ σ h
      cases hd : O.visible (S.sink d) with
      | false => simp [run, observeResult, observe, hd]
      | true =>
          have hv := visible_join_right O (O.flows_visible hf hd)
          have eqv := expr_low_eq O h e hv
          simp only [run, eqv]
  | fail => intro ρ σ _; rfl

namespace Examples
open FiniteSecrets (empty token context accept)

def system := FiniteSecrets.system accept
instance : DecidableRel system.flows :=
  inferInstanceAs (DecidableRel (FiniteSecrets.system accept).flows)
def publicObserver := atLevel system empty

def secretFailure : Cmd FiniteSecrets.Dest := .seq
  (.ite (.equal (.var 0) (.lit (.string "x"))) .fail .skip)
  (.send .console (.lit (.integer 2)))

theorem rejects_secret_failure : ¬ Typed system context empty secretFailure := by
  intro h
  cases h with
  | seq hi _ =>
      cases hi with
      | ite _ hf _ =>
          cases hf with
          | fail hf =>
              have hf := hf 0 (by decide)
              cases hf

def state (s : String) : Env := push (.string s) (fun _ => .string "same")

theorem states_related : LowEq publicObserver context (state "x") (state "y") := by
  intro i hi
  cases i with
  | zero =>
      have hn : publicObserver.visible (context 0).2 = false := by decide
      rw [hn] at hi
      cases hi
  | succ i => rfl

theorem secret_failure_changes_result :
    observeResult publicObserver (run secretFailure (state "x")) ≠
    observeResult publicObserver (run secretFailure (state "y")) := by decide

/-- fail 自体をすべて禁じた証明ではない。両方失敗する受理例。 -/
def publicFailure : Cmd FiniteSecrets.Dest :=
  .seq (.send .console (.lit (.integer 7))) .fail

theorem accepts_public_failure : Typed system context empty publicFailure := by
  apply Typed.seq
  · apply Typed.send (EType.lit _)
    exact FiniteSecrets.lattice 2 |>.bottom_le _
  · exact Typed.fail ((FiniteSecrets.lattice 2).refl _)

theorem accepted_failure_results_equal {ρ σ} (h : LowEq publicObserver context ρ σ) :
    observeResult publicObserver (run publicFailure ρ) =
    observeResult publicObserver (run publicFailure σ) :=
  noninterference publicObserver accepts_public_failure h

#guard run secretFailure (state "x") == .failed []
#guard run secretFailure (state "y") == .done [(.console, .integer 2)]
#guard run publicFailure (state "x") == .failed [(.console, .integer 7)]

end Examples
end Failure

#eval Lean.versionString
#print axioms arbitrary_lattice_noninterference
#print axioms lattice_noninterference
#print axioms FiniteSecrets.phase_iff_generic
#print axioms FiniteSecrets.phase_noninterference
#print axioms Integrity.integrity_noninterference
#print axioms Integrity.endorsement_noninterference
#print axioms Integrity.endorsement_preserves_confidentiality
#print axioms Integrity.endorsement_env_typed
#print axioms Integrity.endorsed_command_approved
#print axioms Integrity.unconditional_endorsement_NI_false
#print axioms Compatibility.phase1_lifts_to_product
#print axioms FlowLattice.join_assoc
#print axioms Failure.noninterference
#print axioms Failure.Examples.rejects_secret_failure
#print axioms Failure.Examples.accepts_public_failure
end SG
