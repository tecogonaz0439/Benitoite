import Std

/-!
SD: 範囲を宛先の静的な上限に使う送信と非干渉性。
土台: SG/Model.lean の FlowLattice/System/Observer と二実行の証明。
範囲: 試作142 Scope.lean の Word から scopeLe_trans を以下へ写す。
SA/SA.lean の scopeLe/Allows と同じ包含を用いる。
本番から直接写した定義はない。SG が参照した本番の構造は
Release/Syntax.lean の Const/Val.var/Comp.letIn/Comp.ite と
Release/Typing.lean の HasTypeVQ.V_Const/V_Var、HasTypeCQ.C_Let/C_If。
本番の読取基準 san_benito: ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c。
独立ファイルであり formal/ のモジュールは import しない。
-/
namespace SD
namespace Scopes
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

end Scopes
open Scopes

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

/-- 範囲は閉じた Scope の有限な和。所属の判定は実行できる。 -/
abbrev Range := List Scope

def InRange (R : Range) (d : Event) : Prop := ∃ s ∈ R, Allows s d
instance (R : Range) (d : Event) : Decidable (InRange R d) := by
  unfold InRange
  infer_instance

structure CheckedDest (R : Range) where
  value : Event
  valid : InRange R value

def validate (R : Range) (d : Event) : Option (CheckedDest R) :=
  if h : InRange R d then some ⟨d, h⟩ else none

theorem validate_sound {R d v} (h : validate R d = some v) :
    v.value = d ∧ InRange R d := by
  unfold validate at h
  split at h
  next hr => cases h; exact ⟨rfl, hr⟩
  next => contradiction

theorem validate_failure_iff (R : Range) (d : Event) :
    validate R d = none ↔ ¬ InRange R d := by
  simp only [validate]
  split <;> simp_all

/-- SA の一原子ずつの包含は、ここで必要な意味上の包含に健全。 -/
def RangeCover (R Q : Range) : Prop :=
  ∀ a ∈ R, ∃ b ∈ Q, scopeLe a b = true

theorem rangeCover_sound {R Q} (h : RangeCover R Q) {d} :
    InRange R d → InRange Q d := by
  rintro ⟨a, ha, hd⟩
  obtain ⟨b, hb, hab⟩ := h a ha
  exact ⟨b, hb, scopeLe_sound hab d hd⟩

theorem widen_checked {R Q} (h : RangeCover R Q) (d : CheckedDest R) : InRange Q d.value :=
  rangeCover_sound h d.valid

inductive Base where
  | integer | boolean | string | rawDest | checked (R : Range)
  deriving DecidableEq, Repr

inductive Value where
  | integer (n : Int)
  | boolean (b : Bool)
  | string (s : String)
  | dest (d : Event)
  deriving DecidableEq, Repr

/-- checked R の範囲への所属は、通常の型の不変条件にも含める。 -/
inductive HasBase : Value → Base → Prop where
  | integer (n) : HasBase (.integer n) .integer
  | boolean (b) : HasBase (.boolean b) .boolean
  | string (s) : HasBase (.string s) .string
  | rawDest (d) : HasBase (.dest d) .rawDest
  | checked {R d} : InRange R d → HasBase (.dest d) (.checked R)

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
  | lit {v t} : HasBase v t → EType Γ (.lit v) t
  | var (i) : EType Γ (.var i) (Γ i).1
  | equal {a b t} : EType Γ a t → EType Γ b t → EType Γ (.equal a b) .boolean

def EnvTyped (Γ : Ctx L) (ρ : Env) : Prop := ∀ i, HasBase (ρ i) (Γ i).1

theorem eval_type {Γ : Ctx L} {e t} (h : EType Γ e t) {ρ}
    (hρ : EnvTyped Γ ρ) : HasBase (eval e ρ) t := by
  induction h with
  | lit hv => exact hv
  | var i => exact hρ i
  | equal => exact .boolean _

theorem envTyped_push {Γ : Ctx L} {ρ t l v}
    (h : EnvTyped Γ ρ) (hv : HasBase v t) :
    EnvTyped (push (t, l) Γ) (push v ρ) := by
  intro i
  cases i with
  | zero => exact hv
  | succ i => exact h i

-- 型の付いた送信では、このフォールバック値には到達しない。
def target : Value → Event
  | .dest d => d
  | _ => ⟨.https, [], 0⟩

theorem checked_member {v R} (h : HasBase v (.checked R)) : InRange R (target v) := by
  cases h with
  | checked hr => exact hr

def label (S : System L D) (Γ : Ctx L) : Expr → L
  | .lit _ => S.bottom
  | .var i => (Γ i).2
  | .equal a b => S.join (label S Γ a) (label S Γ b)

variable {L : Type} {S : System L Event}
def LowEq (O : Observer S) (Γ : Ctx L) (ρ σ : Env) : Prop :=
  ∀ i, O.visible (Γ i).2 = true → ρ i = σ i

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

/-- 自分宛ての実際の事象だけを見る。出口の印で事象を消さない。 -/
structure Receiver (S : System L Event) where
  observer : Observer S
  who : Event
  readable : observer.visible (S.sink who) = true

def receiverAt (S : System L Event) [DecidableRel S.flows] (d : Event) : Receiver S where
  observer := atLevel S (S.sink d)
  who := d
  readable := decide_eq_true (S.refl _)

abbrev Trace := List (Event × Value)
def observe (O : Receiver S) (tr : Trace) : Trace :=
  tr.filter fun ev => decide (ev.1 = O.who)

theorem observe_append (O : Receiver S) (a b : Trace) :
    observe O (a ++ b) = observe O a ++ observe O b := by
  simp [observe, List.filter_append]

/-- 全宛先について pc、宛先、本文の印を合わせて照合する。 -/
def Covers (S : System L Event) (R : Range) (l : L) : Prop :=
  ∀ d, InRange R d → S.flows l (S.sink d)

theorem covers_mono {S : System L Event} {R Q l} (h : RangeCover R Q)
    (hc : Covers S Q l) : Covers S R l := fun d hd => hc d (rangeCover_sound h hd)

inductive Cmd where
  | skip
  | letIn (e : Expr) (body : Cmd)
  | seq (a b : Cmd)
  | ite (e : Expr) (yes no : Cmd)
  | send (R : Range) (d v : Expr)
  | check (R : Range) (raw : Expr) (body : Cmd)
  | fail
  | perform
  | handle (body : Cmd)
  deriving Repr

inductive Status where
  | done | failed | aborted
  deriving DecidableEq, Repr
structure Result where
  status : Status
  trace : Trace
  deriving DecidableEq, Repr

def Result.then (a b : Result) : Result :=
  match a.status with
  | .done => ⟨b.status, a.trace ++ b.trace⟩
  | .failed => a
  | .aborted => a

/-- 一種類の操作の節が継続を再開しない。最寄りの handle で戻る。 -/
def Result.handle (r : Result) : Result :=
  match r.status with
  | .aborted => ⟨.done, r.trace⟩
  | _ => r

def observeResult (O : Receiver S) (r : Result) : Result :=
  ⟨r.status, observe O r.trace⟩

def run : Cmd → Env → Result
  | .skip, _ => ⟨.done, []⟩
  | .letIn e b, ρ => run b (push (eval e ρ) ρ)
  | .seq a b, ρ => (run a ρ).then (run b ρ)
  | .ite e a b, ρ => if eval e ρ = .boolean true then run a ρ else run b ρ
  | .send _ d v, ρ => ⟨.done, [(target (eval d ρ), eval v ρ)]⟩
  | .check R raw b, ρ =>
      match validate R (target (eval raw ρ)) with
      | some d => run b (push (.dest d.value) ρ)
      | none => ⟨.failed, []⟩
  | .fail, _ => ⟨.failed, []⟩
  | .perform, _ => ⟨.aborted, []⟩
  | .handle b, ρ => (run b ρ).handle

inductive Typed (S : System L Event) : Ctx L → L → Cmd → Prop where
  | skip {Γ pc} : Typed S Γ pc .skip
  | letIn {Γ pc e body t} : EType Γ e t →
      Typed S (push (t, S.join pc (label S Γ e)) Γ) pc body →
      Typed S Γ pc (.letIn e body)
  | seq {Γ pc a b} : Typed S Γ pc a → Typed S Γ pc b → Typed S Γ pc (.seq a b)
  | ite {Γ pc e yes no} : EType Γ e .boolean →
      Typed S Γ (S.join pc (label S Γ e)) yes →
      Typed S Γ (S.join pc (label S Γ e)) no →
      Typed S Γ pc (.ite e yes no)
  | send {Γ pc R d v t} : EType Γ d (.checked R) → EType Γ v t →
      Covers S R (S.join pc (S.join (label S Γ d) (label S Γ v))) →
      Typed S Γ pc (.send R d v)
  | check {Γ pc R raw body} : EType Γ raw .rawDest →
      S.flows (S.join pc (label S Γ raw)) S.bottom →
      Typed S (push (.checked R, S.join pc (label S Γ raw)) Γ) pc body →
      Typed S Γ pc (.check R raw body)
  | fail {Γ pc} : S.flows pc S.bottom → Typed S Γ pc .fail
  | perform {Γ pc} : S.flows pc S.bottom → Typed S Γ pc .perform
  | handle {Γ pc b} : Typed S Γ pc b → Typed S Γ pc (.handle b)

theorem observe_then (O : Receiver S) (a b : Result) :
    observeResult O (a.then b) = (observeResult O a).then (observeResult O b) := by
  cases a with
  | mk sa ta => cases sa <;> simp [Result.then, observeResult, observe_append]

theorem observe_handle (O : Receiver S) (r : Result) :
    observeResult O r.handle = (observeResult O r).handle := by
  cases r with
  | mk s t => cases s <;> rfl

theorem public_visible (O : Observer S) {l} (h : S.flows l S.bottom) :
    O.visible l = true := O.flows_visible h O.bottom_visible

/-- 高い pc は、受信も公開の失敗も非再開も起こさない。 -/
theorem high_pc (O : Receiver S) {Γ pc c} (ht : Typed S Γ pc c) :
    O.observer.visible pc = false → ∀ {ρ}, EnvTyped Γ ρ →
      observeResult O (run c ρ) = ⟨.done, []⟩ := by
  induction ht with
  | skip => intro _ _ _; rfl
  | letIn he _ ih =>
      intro hp ρ hρ
      exact ih hp (envTyped_push hρ (eval_type he hρ))
  | seq _ _ ia ib =>
      intro hp ρ hρ
      simp only [run, observe_then, ia hp hρ, ib hp hρ]
      rfl
  | ite _ _ _ ia ib =>
      intro hp ρ hρ
      simp only [run]
      split <;> first
        | exact ia (hidden_join_left O.observer hp) hρ
        | exact ib (hidden_join_left O.observer hp) hρ
  | @send Γ pc R d v t hd hv hc =>
      intro hp ρ hρ
      have hr := checked_member (eval_type hd hρ)
      have hn : target (eval d ρ) ≠ O.who := by
        intro eqd
        have hf := hc _ hr
        rw [eqd] at hf
        have hpv := visible_join_left O.observer (O.observer.flows_visible hf O.readable)
        rw [hp] at hpv
        cases hpv
      simp [run, observeResult, observe, hn]
  | check _ hf _ _ =>
      intro hp ρ _
      have hv := visible_join_left O.observer (public_visible O.observer hf)
      rw [hp] at hv
      cases hv
  | fail hf =>
      intro hp _ _
      have hv := public_visible O.observer hf
      rw [hp] at hv
      cases hv
  | perform hf =>
      intro hp _ _
      have hv := public_visible O.observer hf
      rw [hp] at hv
      cases hv
  | handle _ ih =>
      intro hp ρ hρ
      rw [run, observe_handle, ih hp hρ]
      rfl

/-- 両実行の成功を仮定しない。終了状態と各受け手への列が一致する。 -/
theorem noninterference (O : Receiver S) {Γ pc c} (ht : Typed S Γ pc c) :
    ∀ {ρ σ}, EnvTyped Γ ρ → EnvTyped Γ σ → LowEq O.observer Γ ρ σ →
      observeResult O (run c ρ) = observeResult O (run c σ) := by
  induction ht with
  | skip => intro _ _ _ _ _; rfl
  | letIn he _ ih =>
      intro ρ σ hρ hσ h
      apply ih (envTyped_push hρ (eval_type he hρ)) (envTyped_push hσ (eval_type he hσ))
      apply lowEq_push O.observer h
      intro hv
      exact expr_low_eq O.observer h _ (visible_join_right O.observer hv)
  | seq _ _ ia ib =>
      intro ρ σ hρ hσ h
      simp only [run, observe_then, ia hρ hσ h, ib hρ hσ h]
  | @ite Γ pc e yes no he hy hn iy ino =>
      intro ρ σ hρ hσ h
      cases hv : O.observer.visible (label S Γ e) with
      | true =>
          have eqv := expr_low_eq O.observer h e hv
          simp only [run, eqv]
          split
          · exact iy hρ hσ h
          · exact ino hρ hσ h
      | false =>
          have hp := hidden_join_right O.observer (a := pc) hv
          have eyρ := high_pc O hy hp hρ
          have enρ := high_pc O hn hp hρ
          have eyσ := high_pc O hy hp hσ
          have enσ := high_pc O hn hp hσ
          simp only [run]
          split <;> split <;> simp_all
  | @send Γ pc R d v t hd hv hc =>
      intro ρ σ hρ hσ h
      have one : ∀ {τ}, EnvTyped Γ τ → target (eval d τ) = O.who →
          O.observer.visible (S.join (label S Γ d) (label S Γ v)) = true := by
        intro τ hτ eqd
        have hf := hc _ (checked_member (eval_type hd hτ))
        rw [eqd] at hf
        exact visible_join_right O.observer (O.observer.flows_visible hf O.readable)
      by_cases hr : target (eval d ρ) = O.who
      · have hl := one hρ hr
        have ed := expr_low_eq O.observer h d (visible_join_left O.observer hl)
        have ev := expr_low_eq O.observer h v (visible_join_right O.observer hl)
        simp only [run, ed, ev]
      · by_cases hs : target (eval d σ) = O.who
        · have hl := one hσ hs
          have ed := expr_low_eq O.observer h d (visible_join_left O.observer hl)
          exact False.elim (hr (by rw [ed]; exact hs))
        · simp [run, observeResult, observe, hr, hs]
  | @check Γ pc R raw body he hf hb ih =>
      intro ρ σ hρ hσ h
      have hl := public_visible O.observer hf
      have eqv := expr_low_eq O.observer h raw (visible_join_right O.observer hl)
      simp only [run, eqv]
      split
      next d hd =>
        have hr := (validate_sound hd).2
        have heq := (validate_sound hd).1
        have ht : HasBase (.dest d.value) (.checked R) := .checked (by rw [heq]; exact hr)
        exact ih (envTyped_push hρ ht) (envTyped_push hσ ht)
          (lowEq_push O.observer h (fun _ => rfl))
      next => rfl
  | fail => intro _ _ _ _ _; rfl
  | perform => intro _ _ _ _ _; rfl
  | handle _ ih =>
      intro ρ σ hρ hσ h
      rw [run, run, observe_handle, observe_handle, ih hρ hσ h]

theorem trace_noninterference (O : Receiver S) {Γ pc c ρ σ}
    (ht : Typed S Γ pc c) (hρ : EnvTyped Γ ρ) (hσ : EnvTyped Γ σ)
    (h : LowEq O.observer Γ ρ σ) :
    observe O (run c ρ).trace = observe O (run c σ).trace :=
  congrArg Result.trace (noninterference O ht hρ hσ h)

theorem send_uses_checked_value {Γ : Ctx L} {R d ρ} (hd : EType Γ d (.checked R))
    (hρ : EnvTyped Γ ρ) : ∃ v : CheckedDest R, v.value = target (eval d ρ) :=
  ⟨⟨target (eval d ρ), checked_member (eval_type hd hρ)⟩, rfl⟩

theorem checked_send_has_no_range_failure (R : Range) (d v : Expr) (ρ : Env) :
    (run (.send R d v) ρ).status = .done := rfl

theorem receiver_noninterference (S : System L Event) [DecidableRel S.flows]
    (o : Event) {Γ pc c ρ σ} (ht : Typed S Γ pc c)
    (hρ : EnvTyped Γ ρ) (hσ : EnvTyped Γ σ)
    (h : LowEq (atLevel S (S.sink o)) Γ ρ σ) :
    observeResult (receiverAt S o) (run c ρ) =
      observeResult (receiverAt S o) (run c σ) :=
  noninterference (receiverAt S o) ht hρ hσ h

/-! ## 宛先の集合の束。SF 段2を SG の FlowLattice に具体化する。 -/
namespace Readers
abbrev Label := Event → Bool

def Flows (a b : Label) : Prop := ∀ d, b d = true → a d = true
def bottom : Label := fun _ => true
def top : Label := fun _ => false
def join (a b : Label) : Label := fun d => a d && b d
def meet (a b : Label) : Label := fun d => a d || b d
def singleton (d : Event) : Label := fun x => decide (x = d)

theorem flows_refl (a : Label) : Flows a a := fun _ h => h
theorem flows_trans {a b c : Label} (hab : Flows a b) (hbc : Flows b c) :
    Flows a c := fun d h => hab d (hbc d h)

theorem flows_antisymm {a b : Label} (hab : Flows a b) (hba : Flows b a) : a = b := by
  funext d
  cases ha : a d <;> cases hb : b d <;> simp_all [Flows]

theorem bottom_le (a : Label) : Flows bottom a := fun _ _ => rfl
theorem le_top (a : Label) : Flows a top := by intro d h; cases h

theorem le_join_left (a b : Label) : Flows a (join a b) := by
  intro d hd
  have hh : a d = true ∧ b d = true := by simpa only [join, Bool.and_eq_true] using hd
  exact hh.1

theorem le_join_right (a b : Label) : Flows b (join a b) := by
  intro d hd
  have hh : a d = true ∧ b d = true := by simpa only [join, Bool.and_eq_true] using hd
  exact hh.2

theorem join_le {a b c : Label} (ha : Flows a c) (hb : Flows b c) :
    Flows (join a b) c := by
  intro d hd
  simp [join, ha d hd, hb d hd]

theorem meet_le_left (a b : Label) : Flows (meet a b) a := by
  intro d hd
  simp [meet, hd]

theorem meet_le_right (a b : Label) : Flows (meet a b) b := by
  intro d hd
  simp [meet, hd]

theorem le_meet {a b c : Label} (ha : Flows c a) (hb : Flows c b) :
    Flows c (meet a b) := by
  intro d hd
  have hh : a d = true ∨ b d = true := by simpa only [meet, Bool.or_eq_true] using hd
  rcases hh with h | h
  · exact ha d h
  · exact hb d h

theorem join_comm (a b : Label) : join a b = join b a := by
  funext d
  exact Bool.and_comm _ _

theorem join_assoc (a b c : Label) : join (join a b) c = join a (join b c) := by
  funext d
  exact Bool.and_assoc _ _ _

def lattice : FlowLattice Label where
  bottom := bottom
  join := join
  meet := meet
  flows := Flows
  refl := flows_refl
  trans := flows_trans
  antisymm := flows_antisymm
  bottom_le := bottom_le
  le_join_left := le_join_left
  le_join_right := le_join_right
  join_le := join_le
  meet_le_left := meet_le_left
  meet_le_right := meet_le_right
  le_meet := le_meet

def system : System Label Event where
  toFlowLattice := lattice
  sink := singleton

def observer (d : Event) : Observer system where
  visible := fun l => l d
  bottom_visible := rfl
  join_visible := by intro a b; rfl
  flows_visible := by intro a b hf hb; exact hf d hb

def receiver (d : Event) : Receiver system where
  observer := observer d
  who := d
  readable := by simp [observer, system, singleton]

theorem flows_to_singleton_iff (a : Label) (d : Event) :
    Flows a (singleton d) ↔ a d = true := by
  constructor
  · intro hf; exact hf d (by simp [singleton])
  · intro ha x hx
    have hx : x = d := of_decide_eq_true hx
    simpa only [hx] using ha

/-- D5 の向き: 許した開示先 l が R 全体を覆う。 -/
theorem covers_iff (R : Range) (l : Label) :
    Covers system R l ↔ ∀ d, InRange R d → l d = true := by
  constructor
  · intro h d hd; exact (flows_to_singleton_iff l d).mp (h d hd)
  · intro h d hd; exact (flows_to_singleton_iff l d).mpr (h d hd)

def rangeLabel (R : Range) : Label := fun d => decide (InRange R d)

theorem range_cover_gives_flow {R Q} (h : RangeCover R Q) :
    Flows (rangeLabel Q) (rangeLabel R) := by
  intro d hd
  exact decide_eq_true (rangeCover_sound h (of_decide_eq_true hd))

theorem destination_noninterference (o : Event) {Γ pc c ρ σ}
    (ht : Typed system Γ pc c) (hρ : EnvTyped Γ ρ) (hσ : EnvTyped Γ σ)
    (h : LowEq (observer o) Γ ρ σ) :
    observeResult (receiver o) (run c ρ) = observeResult (receiver o) (run c σ) :=
  noninterference (receiver o) ht hρ hσ h
end Readers

/-! ## 段1〜4の受理例、拒否例、弱めた規則への反例。 -/
namespace Examples
open Readers (bottom top rangeLabel)

def apiA : Event := ⟨.https, ["com", "example", "a"], 443⟩
def apiB : Event := ⟨.https, ["com", "example", "b"], 443⟩
def logs : Event := ⟨.https, ["com", "logs"], 443⟩
def exactScope (d : Event) : Scope := ⟨d.kind, .exact d.target, ⟨d.port, d.port⟩⟩
def apiR : Range := [exactScope apiA, exactScope apiB]
def broadR : Range := apiR ++ [exactScope logs]
def credential := rangeLabel apiR

theorem apiA_member : InRange apiR apiA := by decide
theorem apiB_member : InRange apiR apiB := by decide
theorem logs_not_member : ¬ InRange apiR logs := by decide
theorem logs_broad_member : InRange broadR logs := by decide

def dynamicCtx : Ctx Readers.Label :=
  push (.checked apiR, bottom) (push (.string, credential) (fun _ => (.integer, bottom)))
def dynamicState (d : Event) (key : String) : Env :=
  push (.dest d) (push (.string key) (fun _ => .integer 7))
def dynamicSend : Cmd := .send apiR (.var 0) (.var 1)

theorem dynamic_state_typed (d key) (hd : InRange apiR d) :
    EnvTyped dynamicCtx (dynamicState d key) := by
  apply envTyped_push
  · apply envTyped_push
    · intro _; exact .integer 7
    · exact .string key
  · exact .checked hd

theorem accepts_dynamic_send : Typed Readers.system dynamicCtx bottom dynamicSend := by
  apply Typed.send (EType.var 0) (EType.var 1)
  apply (Readers.covers_iff _ _).mpr
  intro d hd
  simp [Readers.system, Readers.lattice, Readers.join, label, dynamicCtx, push,
    bottom, credential, rangeLabel, decide_eq_true hd]

theorem payload_states_related (d x y) :
    LowEq (Readers.observer logs) dynamicCtx (dynamicState d x) (dynamicState d y) := by
  intro i hi
  cases i with
  | zero => rfl
  | succ i =>
    cases i with
    | zero =>
      have hh : (Readers.observer logs).visible (dynamicCtx 1).2 = false := by decide
      rw [hh] at hi; cases hi
    | succ i => rfl

theorem dynamic_send_NI (d x y) (hd : InRange apiR d) :
    observeResult (Readers.receiver logs) (run dynamicSend (dynamicState d x)) =
    observeResult (Readers.receiver logs) (run dynamicSend (dynamicState d y)) :=
  Readers.destination_noninterference logs accepts_dynamic_send
    (dynamic_state_typed d x hd) (dynamic_state_typed d y hd) (payload_states_related d x y)

-- 証明は有限な宛先の列挙に依存しない。多段のホストを含む閉じた範囲にも適用。
def rangeSendCtx (R : Range) : Ctx Readers.Label :=
  push (.checked R, bottom) (push (.string, rangeLabel R) (fun _ => (.integer, bottom)))

theorem range_send_typed (R : Range) :
    Typed Readers.system (rangeSendCtx R) bottom (.send R (.var 0) (.var 1)) := by
  apply Typed.send (EType.var 0) (EType.var 1)
  apply (Readers.covers_iff _ _).mpr
  intro d hd
  simp [Readers.system, Readers.lattice, Readers.join, label, rangeSendCtx, push,
    bottom, rangeLabel, decide_eq_true hd]

def wildcardR : Range := [⟨.https, .tree ["com", "example"] 1, ⟨443, 443⟩⟩]

theorem wildcard_send_typed :
    Typed Readers.system (rangeSendCtx wildcardR) bottom
      (.send wildcardR (.var 0) (.var 1)) := range_send_typed wildcardR

#guard validate wildcardR ⟨.https, ["com", "example", "x", "y"], 443⟩ |>.isSome
#guard validate wildcardR ⟨.https, ["com", "example"], 443⟩ |>.isNone
#guard validate wildcardR logs |>.isNone

-- 本文に許す宛先が R を覆わなければ、現在の値が apiA でも静的に拒否。
def broadCtx : Ctx Readers.Label :=
  push (.checked broadR, bottom) (push (.string, credential) (fun _ => (.integer, bottom)))
def tooBroad : Cmd := .send broadR (.var 0) (.var 1)

theorem rejects_uncovered_range : ¬ Typed Readers.system broadCtx bottom tooBroad := by
  intro h
  cases h with
  | send _ _ hc =>
      have h := (Readers.covers_iff _ _).mp hc logs logs_broad_member
      change (true && (true && decide (InRange apiR logs))) = true at h
      have hn : decide (InRange apiR logs) = false := by decide
      simp [hn] at h

-- 宛先の値自体がどの受け手にも開示されていない。
def secretDestCtx : Ctx Readers.Label :=
  push (.checked apiR, top) (fun _ => (.integer, bottom))
def secretDestState (d : Event) : Env := push (.dest d) (fun _ => .integer 7)
def secretDestination : Cmd := .send apiR (.var 0) (.lit (.integer 9))

theorem rejects_secret_destination :
    ¬ Typed Readers.system secretDestCtx bottom secretDestination := by
  intro h
  cases h with
  | send _ _ hc =>
      have hh := (Readers.covers_iff _ _).mp hc apiA apiA_member
      change (true && (false && true)) = true at hh
      cases hh

theorem secret_destination_states_typed (d) (hd : InRange apiR d) :
    EnvTyped secretDestCtx (secretDestState d) := by
  apply envTyped_push (fun _ => HasBase.integer 7) (.checked hd)

theorem secret_destination_states_related (o a b) :
    LowEq (Readers.observer o) secretDestCtx (secretDestState a) (secretDestState b) := by
  intro i hi
  cases i with
  | zero => change false = true at hi; cases hi
  | succ i => rfl

/-- 宛先の印だけを規則から落とすと、この同じプログラムが通ってしまう。 -/
theorem payload_only_rule_accepts_secret_destination :
    Covers Readers.system apiR
      (Readers.system.join bottom (label Readers.system secretDestCtx (.lit (.integer 9)))) := by
  apply (Readers.covers_iff _ _).mpr
  intro d _; rfl

theorem secret_destination_leaks :
    observeResult (Readers.receiver apiA) (run secretDestination (secretDestState apiA)) ≠
    observeResult (Readers.receiver apiA) (run secretDestination (secretDestState apiB)) := by decide

-- 許した二宛先へだけ開示できる秘密なら、宛先選択にも使える。
def authorizedDestCtx : Ctx Readers.Label :=
  push (.checked apiR, credential) (fun _ => (.integer, bottom))

theorem accepts_authorized_secret_destination :
    Typed Readers.system authorizedDestCtx bottom secretDestination := by
  apply Typed.send (EType.var 0) (EType.lit (.integer 9))
  apply (Readers.covers_iff _ _).mpr
  intro d hd
  simp [Readers.system, Readers.lattice, Readers.join, label, authorizedDestCtx, push,
    bottom, credential, rangeLabel, decide_eq_true hd]

theorem authorized_destination_states_typed (d) (hd : InRange apiR d) :
    EnvTyped authorizedDestCtx (secretDestState d) :=
  envTyped_push (fun _ => HasBase.integer 7) (.checked hd)

theorem authorized_destination_states_related (a b) :
    LowEq (Readers.observer logs) authorizedDestCtx (secretDestState a) (secretDestState b) := by
  intro i hi
  cases i with
  | zero =>
      have hn : (Readers.observer logs).visible (authorizedDestCtx 0).2 = false := by decide
      rw [hn] at hi; cases hi
  | succ i => rfl

theorem authorized_secret_destination_NI :
    observeResult (Readers.receiver logs) (run secretDestination (secretDestState apiA)) =
    observeResult (Readers.receiver logs) (run secretDestination (secretDestState apiB)) :=
  Readers.destination_noninterference logs accepts_authorized_secret_destination
    (authorized_destination_states_typed apiA apiA_member)
    (authorized_destination_states_typed apiB apiB_member)
    (authorized_destination_states_related apiA apiB)

/-- 範囲を守らない環境では、型付きの送信でも非干渉性の結論は得られない。 -/
theorem forged_checked_value_counterexample :
    Typed Readers.system dynamicCtx bottom dynamicSend ∧
    LowEq (Readers.observer logs) dynamicCtx (dynamicState logs "x") (dynamicState logs "y") ∧
    ¬ EnvTyped dynamicCtx (dynamicState logs "x") ∧
    observeResult (Readers.receiver logs) (run dynamicSend (dynamicState logs "x")) ≠
    observeResult (Readers.receiver logs) (run dynamicSend (dynamicState logs "y")) := by
  refine ⟨accepts_dynamic_send, payload_states_related logs "x" "y", ?_, by decide⟩
  intro h
  have hm := checked_member (h 0)
  exact logs_not_member hm

-- 秘密による分岐で、各枝では公開の定数の宛先を使う例。
def boolCtx : Ctx Readers.Label := push (.boolean, top) (fun _ => (.integer, bottom))
def boolState (b : Bool) : Env := push (.boolean b) (fun _ => .integer 7)
def fixedSend (d : Event) : Cmd := .send [exactScope d] (.lit (.dest d)) (.lit (.integer 1))
def chooseDestination : Cmd := .ite (.var 0) (fixedSend apiA) (fixedSend apiB)

theorem bool_states_typed (b) : EnvTyped boolCtx (boolState b) :=
  envTyped_push (fun _ => HasBase.integer 7) (.boolean b)

theorem bool_states_related (o a b) :
    LowEq (Readers.observer o) boolCtx (boolState a) (boolState b) := by
  intro i hi
  cases i with
  | zero => change false = true at hi; cases hi
  | succ i => rfl

theorem rejects_secret_pc_destination : ¬ Typed Readers.system boolCtx bottom chooseDestination := by
  intro h
  cases h with
  | ite _ hy _ =>
      cases hy with
      | send _ _ hc =>
          have hh := (Readers.covers_iff _ _).mp hc apiA (by decide)
          change ((true && false) && (true && true)) = true at hh
          cases hh

theorem secret_pc_destination_leaks :
    observeResult (Readers.receiver apiA) (run chooseDestination (boolState true)) ≠
    observeResult (Readers.receiver apiA) (run chooseDestination (boolState false)) := by decide

-- 段3: 公開の raw 値の検査は失敗を含めて受理。送信での再照合はない。
def rawCtx : Ctx Readers.Label := push (.rawDest, bottom) (fun _ => (.integer, bottom))
def rawState (d : Event) : Env := push (.dest d) (fun _ => .integer 7)
def checkedSend : Cmd := .check apiR (.var 0) (.send apiR (.var 0) (.lit (.integer 5)))

theorem accepts_public_validation : Typed Readers.system rawCtx bottom checkedSend := by
  apply Typed.check (EType.var 0)
  · exact Readers.lattice.refl _
  · apply Typed.send (EType.var 0) (EType.lit (.integer 5))
    apply (Readers.covers_iff _ _).mpr
    intro d _; rfl

theorem raw_states_typed (d) : EnvTyped rawCtx (rawState d) :=
  envTyped_push (fun _ => HasBase.integer 7) (.rawDest d)

theorem public_validation_success : (run checkedSend (rawState apiA)).status = .done := by decide
theorem public_validation_failure : run checkedSend (rawState logs) = ⟨.failed, []⟩ := by decide

def secretRawCtx : Ctx Readers.Label := push (.rawDest, top) (fun _ => (.integer, bottom))
def invalidCheck : Cmd := .seq (.check apiR (.var 0) .skip) (fixedSend logs)

theorem secret_raw_states_typed (d) : EnvTyped secretRawCtx (rawState d) :=
  envTyped_push (fun _ => HasBase.integer 7) (.rawDest d)

theorem secret_raw_states_related (o a b) :
    LowEq (Readers.observer o) secretRawCtx (rawState a) (rawState b) := by
  intro i hi
  cases i with
  | zero => change false = true at hi; cases hi
  | succ i => rfl

theorem rejects_secret_validation : ¬ Typed Readers.system secretRawCtx bottom invalidCheck := by
  intro h
  cases h with
  | seq hc _ =>
      cases hc with
      | check _ hf _ =>
          have hh := hf logs rfl
          change (true && false) = true at hh
          cases hh

theorem secret_validation_leaks_status :
    (run invalidCheck (rawState apiA)).status ≠ (run invalidCheck (rawState logs)).status := by decide

theorem secret_validation_leaks_trace :
    observe (Readers.receiver logs) (run invalidCheck (rawState apiA)).trace ≠
    observe (Readers.receiver logs) (run invalidCheck (rawState logs)).trace := by decide

-- 秘密の pc による、定数の検査失敗も拒否する。
def secretPcCheck : Cmd := .seq
  (.ite (.var 0) (.check apiR (.lit (.dest logs)) .skip) .skip) (fixedSend logs)

theorem rejects_secret_pc_validation : ¬ Typed Readers.system boolCtx bottom secretPcCheck := by
  intro h
  cases h with
  | seq hi _ =>
      cases hi with
      | ite _ hc _ =>
          cases hc with
          | check _ hf _ =>
              have hh := hf logs rfl
              change ((true && false) && true) = true at hh
              cases hh

theorem secret_pc_validation_leaks :
    observeResult (Readers.receiver logs) (run secretPcCheck (boolState true)) ≠
    observeResult (Readers.receiver logs) (run secretPcCheck (boolState false)) := by decide

def secretFail : Cmd := .seq (.ite (.var 0) .fail .skip) (fixedSend logs)

theorem rejects_secret_failure : ¬ Typed Readers.system boolCtx bottom secretFail := by
  intro h
  cases h with
  | seq hi _ =>
      cases hi with
      | ite _ hf _ =>
          cases hf with
          | fail hf =>
              have hh := hf logs rfl
              change (true && false) = true at hh
              cases hh

theorem secret_failure_leaks :
    observeResult (Readers.receiver logs) (run secretFail (boolState true)) ≠
    observeResult (Readers.receiver logs) (run secretFail (boolState false)) := by decide

theorem accepts_public_failure : Typed Readers.system boolCtx bottom .fail :=
  .fail (Readers.lattice.refl _)

-- 段4: handle の内側で続きが止まり、外側へ戻る最小の非再開。
def abortLeak : Cmd := .handle (.seq (.ite (.var 0) .perform .skip) (fixedSend logs))

theorem rejects_secret_nonresumption : ¬ Typed Readers.system boolCtx bottom abortLeak := by
  intro h
  cases h with
  | handle hb =>
      cases hb with
      | seq hi _ =>
          cases hi with
          | ite _ hp _ =>
              cases hp with
              | perform hf =>
                  have hh := hf logs rfl
                  change (true && false) = true at hh
                  cases hh

/-- 両方とも done になるが、handle 内の後続送信だけが片方で消える。 -/
theorem nonresumption_leaks_trace :
    (run abortLeak (boolState true)).status = .done ∧
    (run abortLeak (boolState false)).status = .done ∧
    observe (Readers.receiver logs) (run abortLeak (boolState true)).trace ≠
    observe (Readers.receiver logs) (run abortLeak (boolState false)).trace := by decide

def publicAbort : Cmd := .seq (.handle (.seq .perform (fixedSend logs))) (fixedSend apiA)

theorem fixed_send_typed (Γ : Ctx Readers.Label) (d : Event) :
    Typed Readers.system Γ bottom (fixedSend d) := by
  apply Typed.send (EType.lit (.checked (by exact ⟨exactScope d, by simp, rfl,
    rfl, Nat.le_refl _, Nat.le_refl _⟩))) (EType.lit (.integer 1))
  apply (Readers.covers_iff _ _).mpr
  intro d _; rfl

theorem accepts_public_nonresumption : Typed Readers.system boolCtx bottom publicAbort :=
  .seq (.handle (.seq (.perform (Readers.lattice.refl _)) (fixed_send_typed _ _)))
    (fixed_send_typed _ _)

theorem public_nonresumption_result (b) :
    run publicAbort (boolState b) = ⟨.done, [(apiA, .integer 1)]⟩ := rfl

#guard run dynamicSend (dynamicState apiA "key-a") == ⟨.done, [(apiA, .string "key-a")]⟩
#guard run dynamicSend (dynamicState apiB "key-b") == ⟨.done, [(apiB, .string "key-b")]⟩
#guard observe (Readers.receiver logs) (run dynamicSend (dynamicState apiA "key-a")).trace == []
#guard validate apiR logs |>.isNone
#guard validate apiR apiA |>.isSome
#guard run checkedSend (rawState logs) == ⟨.failed, []⟩
#guard run checkedSend (rawState apiA) == ⟨.done, [(apiA, .integer 5)]⟩
#guard run abortLeak (boolState true) == ⟨.done, []⟩
#guard run abortLeak (boolState false) == ⟨.done, [(logs, .integer 1)]⟩
#guard run publicAbort (boolState true) == ⟨.done, [(apiA, .integer 1)]⟩
end Examples

#eval Lean.versionString
#print axioms noninterference
#print axioms receiver_noninterference
#print axioms Readers.destination_noninterference
#print axioms Readers.covers_iff
#print axioms Examples.rejects_uncovered_range
#print axioms Examples.rejects_secret_destination
#print axioms Examples.rejects_secret_validation
#print axioms Examples.rejects_secret_nonresumption
#print axioms Examples.forged_checked_value_counterexample
#print axioms Examples.authorized_secret_destination_NI
#print axioms Examples.nonresumption_leaks_trace
end SD
