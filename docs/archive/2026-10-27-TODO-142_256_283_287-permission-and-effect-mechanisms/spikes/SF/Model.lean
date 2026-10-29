import Std

/-!
SF: 逐次計算の情報の流れを調べる試作。2026-10-26。
formal/ は import しない。対象言語の再帰、ストア、例外、並行、
一般の開示、DNS、実際のネットワークの操作は含めない。

次は構造を参照した出どころであり、そのまま写した定義ではない。
san_benito の 8b6feef2b36ae2a379c15ed5474b159d3622435f:
formal/Benitoite/Release/Syntax.lean の Const, Val.var, Comp.letIn, Comp.ite;
formal/Benitoite/Release/Typing.lean の HasTypeVQ.V_Const/V_Var,
HasTypeCQ.C_Let/C_If。本番の規則には情報の流れの印はない。
印の代数、事象列の意味、二実行の証明はこの試作で定義した。
-/
namespace SF

inductive Base where
  | integer | boolean
  deriving DecidableEq, Repr

inductive Value where
  | integer (n : Int)
  | boolean (b : Bool)
  deriving DecidableEq, Repr

def Value.type : Value → Base
  | .integer _ => .integer
  | .boolean _ => .boolean

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

/-- flows は情報の機密性の順序であり、実行した効果の集合とは分ける。 -/
structure System (L D : Type) where
  bottom : L
  join : L → L → L
  flows : L → L → Prop
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

namespace TwoPoint

inductive Level where
  | low | high
  deriving DecidableEq, Repr

def join : Level → Level → Level
  | .low, .low => .low
  | _, _ => .high

def Flows (a b : Level) : Prop := a = .low ∨ b = .high

inductive Dest where
  | console | vault
  deriving DecidableEq, Repr

def system : System Level Dest where
  bottom := .low
  join := join
  flows := Flows
  sink := fun d => match d with | .console => .low | .vault => .high

def publicObserver : Observer system where
  visible := fun l => l == .low
  bottom_visible := rfl
  join_visible := by intro a b; cases a <;> cases b <;> rfl
  flows_visible := by
    intro a b hf hb
    cases a <;> cases b <;> simp_all [system, Flows]

def context : Ctx Level := fun i =>
  if i = 0 then (.boolean, .high) else (.integer, .low)

def explicitLeak : Cmd Dest := .send .console (.var 0)

def implicitLeak : Cmd Dest := .ite (.var 0)
  (.send .console (.lit (.integer 1))) (.send .console (.lit (.integer 0)))

theorem reject_explicit : ¬ Typed system context .low explicitLeak := by
  intro h
  cases h with
  | send _ hf => simp [system, Flows, join, label, context] at hf

theorem reject_implicit : ¬ Typed system context .low implicitLeak := by
  intro h
  cases h with
  | ite _ hy _ =>
      cases hy with
      | send _ hf => simp [system, Flows, join, label, context] at hf

def safeProgram : Cmd Dest :=
  .seq (.send .console (.var 1))
    (.letIn (.var 0) (.ite (.var 0)
      (.send .vault (.lit (.integer 1))) (.send .vault (.lit (.integer 0)))))

theorem safeProgram_typed : Typed system context .low safeProgram := by
  apply Typed.seq
  · exact Typed.send (.var 1) (by simp [system, Flows, join, label, context])
  · apply Typed.letIn (EType.var 0)
    apply Typed.ite (EType.var 0)
    · exact Typed.send (.lit _) (by simp [system, Flows])
    · exact Typed.send (.lit _) (by simp [system, Flows])

theorem public_trace_equal {ρ σ : Env} (h : LowEq publicObserver context ρ σ) :
    observe publicObserver (run safeProgram ρ) =
      observe publicObserver (run safeProgram σ) :=
  noninterference publicObserver safeProgram_typed h

def state (secret : Bool) : Env := fun i =>
  if i = 0 then .boolean secret else .integer 7

theorem states_low_eq : LowEq publicObserver context (state true) (state false) := by
  intro i hi
  by_cases h0 : i = 0
  · subst i
    simp [publicObserver, context] at hi
  · simp [state, h0]

theorem state_typed (b : Bool) : EnvTyped context (state b) := by
  intro i
  by_cases h0 : i = 0 <;> simp [state, context, h0, Value.type]

#guard run explicitLeak (state true) != run explicitLeak (state false)
#guard run implicitLeak (state true) != run implicitLeak (state false)
#guard observe publicObserver (run safeProgram (state true)) == [(.console, .integer 7)]
#guard observe publicObserver (run safeProgram (state false)) == [(.console, .integer 7)]

end TwoPoint

/-! ## 段2: 受け手の集合と逆包含の順序。 -/
namespace Readers

abbrev Label := String → Bool

def Flows (a b : Label) : Prop := ∀ d, b d = true → a d = true
def bottom : Label := fun _ => true
def top : Label := fun _ => false
def join (a b : Label) : Label := fun d => a d && b d
def meet (a b : Label) : Label := fun d => a d || b d
def singleton (d : String) : Label := fun x => decide (x = d)

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

def system : System Label String where
  bottom := bottom
  join := join
  flows := Flows
  sink := singleton

def observer (d : String) : Observer system where
  visible := fun l => l d
  bottom_visible := rfl
  join_visible := by intro a b; rfl
  flows_visible := by intro a b hf hb; exact hf d hb

/-- 観測者dに対し、d宛ての事象だけを観測に残す。 -/
theorem observer_sink (o d : String) :
    (observer o).visible (system.sink d) = decide (o = d) := by
  simp [observer, system, singleton]

theorem flows_to_singleton_iff (a : Label) (d : String) :
    Flows a (singleton d) ↔ a d = true := by
  constructor
  · intro hf
    exact hf d (by simp [singleton])
  · intro ha x hx
    have hx : x = d := of_decide_eq_true hx
    simpa only [hx] using ha

theorem destination_noninterference (o : String) {Γ pc c} (ht : Typed system Γ pc c)
    {ρ σ} (h : LowEq (observer o) Γ ρ σ) :
    observe (observer o) (run c ρ) = observe (observer o) (run c σ) :=
  noninterference (observer o) ht h

def api := "api.example.com"
def logs := "logs.example.com"
def credential : Label := singleton api
def context : Ctx Label := fun i =>
  if i = 0 then (.integer, credential) else (.integer, bottom)

theorem credential_to_api : Flows credential (singleton api) := flows_refl _

theorem credential_not_to_logs : ¬ Flows credential (singleton logs) := by
  intro h
  have hx := h logs (by decide)
  change decide (logs = api) = true at hx
  simp [logs, api] at hx

theorem permitted_send : Typed system context bottom (.send api (.var 0)) := by
  apply Typed.send (EType.var 0)
  intro d hd
  simpa [system, join, bottom, label, context, credential] using hd

theorem forbidden_send : ¬ Typed system context bottom (.send logs (.var 0)) := by
  intro h
  cases h with
  | send _ hf =>
      apply credential_not_to_logs
      intro d hd
      have hh := hf d hd
      simpa [system, join, bottom, label, context] using hh

/-- API以外の観測者に対しては、API用の秘密が違っていてもよい。 -/
theorem credential_hidden_at_logs (x y : Int) :
    LowEq (observer logs) context
      (push (.integer x) (fun _ => .integer 9))
      (push (.integer y) (fun _ => .integer 9)) := by
  intro i hi
  cases i with
  | zero => simp [observer, context, credential, singleton, logs, api] at hi
  | succ i => rfl

#guard (join (singleton api) (singleton logs)) api == false
#guard (join (singleton api) (singleton logs)) logs == false

/-!
次は試作142から写した最小部分である。
docs/todo/sources/2026-10-17-feasibility-spikes/142/Scope.lean の
Spike142.Word, Pattern, Matches, patLe, patLe_sound と tree_witness の証明。
tree _ 1 は、逆順のホストの要素列に一段以上の追加を許す。
URLの解析、DNS、リダイレクト、実行の許可までは扱わない。
-/
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

def denotes (p : Pattern) : Word → Bool := fun w => decide (Matches p w)
def WordFlows (a b : Word → Bool) : Prop := ∀ w, b w = true → a w = true

/-- 受け手集合の順序に合わせ、patLe の引数の向きを逆にする。 -/
theorem pattern_inclusion_gives_flow {a b : Pattern} (h : patLe b a = true) :
    WordFlows (denotes a) (denotes b) := by
  intro w hw
  exact decide_eq_true (patLe_sound h w (of_decide_eq_true hw))

theorem pattern_nonempty (p : Pattern) : ∃ w, Matches p w := by
  cases p with
  | exact w => exact ⟨w, rfl⟩
  | tree a k =>
      exact ⟨a ++ List.replicate k "x", List.prefix_append _ _, by simp⟩

def apiPattern : Pattern := .exact ["com", "example", "api"]
def logsPattern : Pattern := .exact ["com", "example", "logs"]
def subdomains : Pattern := .tree ["com", "example"] 1

#guard patLe apiPattern subdomains
#guard !(patLe subdomains apiPattern)
#guard !(patLe (.exact ["com", "example"]) subdomains)
#guard patLe (.exact ["com", "example", "a", "b"]) subdomains

theorem subdomain_credential_to_api : WordFlows (denotes subdomains) (denotes apiPattern) :=
  pattern_inclusion_gives_flow (by decide)

def hostSystem : System (Word → Bool) Word where
  bottom := fun _ => true
  join := fun a b w => a w && b w
  flows := WordFlows
  sink := fun d w => decide (w = d)

def hostObserver (o : Word) : Observer hostSystem where
  visible := fun l => l o
  bottom_visible := rfl
  join_visible := by intro a b; rfl
  flows_visible := by intro a b hf hb; exact hf o hb

def hostContext : Ctx (Word → Bool) := fun _ => (.integer, denotes subdomains)

theorem host_pattern_send_typed :
    Typed hostSystem hostContext hostSystem.bottom
      (.send ["com", "example", "api"] (.var 0)) := by
  apply Typed.send (EType.var 0)
  intro w hw
  have hw : w = ["com", "example", "api"] := of_decide_eq_true hw
  subst w
  change (true && denotes subdomains ["com", "example", "api"]) = true
  decide

theorem host_pattern_noninterference (o : Word) {Γ pc c}
    (ht : Typed hostSystem Γ pc c) {ρ σ} (he : LowEq (hostObserver o) Γ ρ σ) :
    observe (hostObserver o) (run c ρ) = observe (hostObserver o) (run c σ) :=
  noninterference (hostObserver o) ht he

/-- 異なる完全一致パターンの空の共通部分を、元の単一パターンでは表せない。 -/
theorem intersection_not_single_pattern :
    ¬ ∃ p, ∀ w, Matches p w ↔ Matches apiPattern w ∧ Matches logsPattern w := by
  rintro ⟨p, hp⟩
  obtain ⟨w, hw⟩ := pattern_nonempty p
  obtain ⟨ha, hb⟩ := (hp w).mp hw
  have heq : (["com", "example", "api"] : Word) = ["com", "example", "logs"] :=
    ha.trans hb.symm
  exact (by decide : (["com", "example", "api"] : Word) ≠ ["com", "example", "logs"]) heq

/-- 生のパターン列では、意味上の相互包含から構造の等号を導けない。 -/
def denoteMany (ps : List Pattern) : Word → Bool := fun w => ps.any (fun p => denotes p w)

theorem raw_lists_same_denotation :
    denoteMany [apiPattern] = denoteMany [apiPattern, apiPattern] := by
  funext w
  simp [denoteMany]

theorem raw_lists_different : [apiPattern] ≠ [apiPattern, apiPattern] := by
  intro h
  have hl := congrArg List.length h
  simp at hl

end Readers

/-! ## 段3: 一階の操作一つと、末尾で再開する深いハンドラ。

ハンドラは導入時の環境を捕捉する。節では出力してから純粋な式を返し、
その結果で継続を一度だけ末尾再開する。非再開、継続の保存、
節の中のask、ハンドラの入れ子は含めない。
本番の Clause/Comp.handle/Comp.resume を制限した構造であり、
その全ての振る舞いを扱うモデルではない。
-/
namespace Handlers

structure Signature (L : Type) where
  argType : Base
  argLabel : L
  retType : Base
  retLabel : L
  callPc : L

structure Handler (D : Type) where
  work : Cmd D
  reply : Expr

inductive Body (D : Type) where
  | skip
  | letIn (e : Expr) (body : Body D)
  | seq (a b : Body D)
  | ite (e : Expr) (yes no : Body D)
  | send (d : D) (e : Expr)
  | ask (arg : Expr) (next : Body D)
  deriving Repr

def runH (h : Handler D) (captured : Env) : Body D → Env → Trace D
  | .skip, _ => []
  | .letIn e body, ρ => runH h captured body (push (eval e ρ) ρ)
  | .seq a b, ρ => runH h captured a ρ ++ runH h captured b ρ
  | .ite e yes no, ρ =>
      if eval e ρ = .boolean true then runH h captured yes ρ else runH h captured no ρ
  | .send d e, ρ => [(d, eval e ρ)]
  | .ask arg next, ρ =>
      let clauseEnv := push (eval arg ρ) captured
      run h.work clauseEnv ++ runH h captured next (push (eval h.reply clauseEnv) ρ)

structure HandlerOK (S : System L D) (capturedΓ : Ctx L) (sg : Signature L)
    (h : Handler D) : Prop where
  work : Typed S (push (sg.argType, sg.argLabel) capturedΓ)
    (S.join sg.callPc sg.argLabel) h.work
  reply : EType (push (sg.argType, sg.argLabel) capturedΓ) h.reply sg.retType
  replyFlow : S.flows (label S (push (sg.argType, sg.argLabel) capturedΓ) h.reply) sg.retLabel

inductive BodyTyped (S : System L D) (sg : Signature L) : Ctx L → L → Body D → Prop where
  | skip {Γ pc} : BodyTyped S sg Γ pc .skip
  | letIn {Γ pc e body t} :
      EType Γ e t →
      BodyTyped S sg (push (t, S.join pc (label S Γ e)) Γ) pc body →
      BodyTyped S sg Γ pc (.letIn e body)
  | seq {Γ pc a b} : BodyTyped S sg Γ pc a → BodyTyped S sg Γ pc b →
      BodyTyped S sg Γ pc (.seq a b)
  | ite {Γ pc e yes no} :
      EType Γ e .boolean →
      BodyTyped S sg Γ (S.join pc (label S Γ e)) yes →
      BodyTyped S sg Γ (S.join pc (label S Γ e)) no →
      BodyTyped S sg Γ pc (.ite e yes no)
  | send {Γ pc d e t} : EType Γ e t →
      S.flows (S.join pc (label S Γ e)) (S.sink d) →
      BodyTyped S sg Γ pc (.send d e)
  | ask {Γ pc arg next} :
      EType Γ arg sg.argType →
      S.flows (label S Γ arg) sg.argLabel →
      S.flows pc sg.callPc →
      BodyTyped S sg (push (sg.retType, S.join pc sg.retLabel) Γ) pc next →
      BodyTyped S sg Γ pc (.ask arg next)

structure Effects where
  ask : Bool
  send : Bool
  deriving DecidableEq, Repr

def Effects.union (a b : Effects) : Effects := ⟨a.ask || b.ask, a.send || b.send⟩
def Effects.removeAsk (a : Effects) : Effects := ⟨false, a.send⟩

def effects : Body D → Effects
  | .skip => ⟨false, false⟩
  | .letIn _ body => effects body
  | .seq a b | .ite _ a b => (effects a).union (effects b)
  | .send _ _ => ⟨false, true⟩
  | .ask _ next => ⟨true, (effects next).send⟩

def workEffects : Cmd D → Effects
  | .skip => ⟨false, false⟩
  | .letIn _ body => workEffects body
  | .seq a b | .ite _ a b => (workEffects a).union (workEffects b)
  | .send _ _ => ⟨false, true⟩

/-- 本番のC_Handleと同じく、処理した効果を除き、節の効果を加える。
情報の流れの前提は別に保つ。
-/
inductive HandleTyped (S : System L D) (Γ : Ctx L) (pc : L) :
    Handler D → Body D → Effects → Prop where
  | handle {sg h body} :
      HandlerOK S Γ sg h → BodyTyped S sg Γ pc body →
      HandleTyped S Γ pc h body ((effects body).removeAsk.union (workEffects h.work))

theorem work_no_ask (c : Cmd D) : (workEffects c).ask = false := by
  induction c with
  | skip => rfl
  | letIn _ _ ih => exact ih
  | seq _ _ ia ib | ite _ _ _ ia ib => simp [workEffects, Effects.union, ia, ib]
  | send => rfl

theorem handled_ask_removed {S : System L D} {Γ pc h body eff}
    (ht : HandleTyped S Γ pc h body eff) : eff.ask = false := by
  cases ht
  simp [Effects.removeAsk, Effects.union, work_no_ask]

theorem hidden_of_flow (O : Observer S) {a b} (hf : S.flows a b)
    (ha : O.visible a = false) : O.visible b = false := by
  cases hb : O.visible b with
  | false => rfl
  | true => have hv := O.flows_visible hf hb; simp [ha] at hv

theorem high_pc (O : Observer S) {capturedΓ sg h Γ pc c}
    (hh : HandlerOK S capturedΓ sg h) (ht : BodyTyped S sg Γ pc c) :
    O.visible pc = false → ∀ ρ captured, observe O (runH h captured c ρ) = [] := by
  induction ht with
  | skip => intro _ _ _; rfl
  | letIn _ _ ih => intro hp ρ cap; exact ih hp _ cap
  | seq _ _ ia ib =>
      intro hp ρ cap
      simp only [runH, observe_append, ia hp ρ cap, ib hp ρ cap, List.nil_append]
  | ite _ _ _ ia ib =>
      intro hp ρ cap
      simp only [runH]
      split <;> first
        | exact ia (hidden_join_left O hp) ρ cap
        | exact ib (hidden_join_left O hp) ρ cap
  | @send Γ pc d e t he hf =>
      intro hp ρ cap
      have hd := hidden_of_flow O hf (hidden_join_left O hp)
      simp [runH, observe, hd]
  | ask he ha hc hn ih =>
      intro hp ρ cap
      have hcall := hidden_of_flow O hc hp
      have hw := SF.high_pc O hh.work (hidden_join_left O hcall)
      simp only [runH, observe_append, hw, ih hp, List.nil_append]

theorem noninterference (O : Observer S) {capturedΓ sg h Γ pc c}
    (hh : HandlerOK S capturedΓ sg h) (ht : BodyTyped S sg Γ pc c)
    {capρ capσ : Env} (hcap : LowEq O capturedΓ capρ capσ) :
    ∀ {ρ σ}, LowEq O Γ ρ σ →
      observe O (runH h capρ c ρ) = observe O (runH h capσ c σ) := by
  induction ht with
  | skip => intro ρ σ _; rfl
  | letIn he hb ih =>
      intro ρ σ h
      apply ih (lowEq_push O h ?_)
      intro hv
      exact expr_low_eq O h _ (visible_join_right O hv)
  | seq ha hb ia ib =>
      intro ρ σ h
      simp only [runH, observe_append, ia h, ib h]
  | @ite Γ pc e yes no he hy hn iy ino =>
      intro ρ σ hρσ
      cases hv : O.visible (label S Γ e) with
      | true =>
          have eqv := expr_low_eq O hρσ e hv
          simp only [runH, eqv]
          split
          · exact iy hρσ
          · exact ino hρσ
      | false =>
          have hp := hidden_join_right O (a := pc) hv
          have eyρ := high_pc O hh hy hp ρ capρ
          have enρ := high_pc O hh hn hp ρ capρ
          have eyσ := high_pc O hh hy hp σ capσ
          have enσ := high_pc O hh hn hp σ capσ
          simp only [runH]
          split <;> split <;> simp_all
  | @send Γ pc d e t he hf =>
      intro ρ σ hρσ
      cases hd : O.visible (S.sink d) with
      | false => simp [runH, observe, hd]
      | true =>
          have hv := visible_join_right O (O.flows_visible hf hd)
          have eqv := expr_low_eq O hρσ e hv
          simp only [runH, eqv]
  | @ask Γ pc arg next he ha hc hn ih =>
      intro ρ σ hρσ
      have harg : O.visible sg.argLabel = true → eval arg ρ = eval arg σ := by
        intro hv
        exact expr_low_eq O hρσ arg (O.flows_visible ha hv)
      have hclause := lowEq_push O (t := sg.argType) hcap harg
      have hwork := SF.noninterference O hh.work hclause
      have hret : O.visible (S.join pc sg.retLabel) = true →
          eval h.reply (push (eval arg ρ) capρ) = eval h.reply (push (eval arg σ) capσ) := by
        intro hv
        exact expr_low_eq O hclause h.reply
          (O.flows_visible hh.replyFlow (visible_join_right O hv))
      have hnext := ih (lowEq_push O hρσ hret)
      simp only [runH, observe_append, hwork, hnext]

theorem handled_noninterference (O : Observer S) {Γ pc h body eff}
    (ht : HandleTyped S Γ pc h body eff) {ρ σ} (hρσ : LowEq O Γ ρ σ) :
    observe O (runH h ρ body ρ) = observe O (runH h σ body σ) := by
  cases ht with
  | handle hh hb => exact noninterference O hh hb hρσ hρσ

namespace Examples
open TwoPoint

def publicSig : Signature Level := ⟨.boolean, .low, .boolean, .low, .low⟩
def secretSig : Signature Level := ⟨.boolean, .high, .boolean, .high, .high⟩
def secretReply : Handler Dest := ⟨.skip, .var 1⟩

theorem secretReply_ok : HandlerOK system context secretSig secretReply := by
  constructor
  · exact Typed.skip
  · exact EType.var 1
  · simp [system, Flows, secretSig]

theorem no_public_reply_contract : ¬ HandlerOK system context publicSig secretReply := by
  intro h
  have hf := h.replyFlow
  simp [system, Flows, publicSig, secretReply, label, push, context] at hf

def leakReply : Body Dest := .ask (.lit (.boolean false))
  (.ite (.var 0) (.send .console (.lit (.integer 1))) (.send .console (.lit (.integer 0))))

/-- 呼び出し元だけを調べると、公開と偽った返り値の署名でも通る。 -/
theorem caller_accepts_public_signature : BodyTyped system publicSig context .low leakReply := by
  apply BodyTyped.ask (EType.lit _)
  · simp [system, Flows, label]
  · simp [system, Flows]
  · apply BodyTyped.ite (EType.var 0)
    · exact BodyTyped.send (EType.lit _) (by simp [system, Flows, join, label, push, publicSig])
    · exact BodyTyped.send (EType.lit _) (by simp [system, Flows, join, label, push, publicSig])

theorem caller_rejects_secret_signature : ¬ BodyTyped system secretSig context .low leakReply := by
  intro h
  cases h with
  | ask _ _ _ hn =>
      cases hn with
      | ite _ hy _ =>
          cases hy with
          | send _ hf => simp [system, Flows, secretSig, join, label, push] at hf

def safeBody : Body Dest := .ask (.var 0)
  (.seq (.send .vault (.var 0)) (.send .console (.var 2)))

theorem safeBody_typed : BodyTyped system secretSig context .low safeBody := by
  apply BodyTyped.ask (EType.var 0)
  · simp [system, Flows, secretSig]
  · simp [system, Flows]
  · apply BodyTyped.seq
    · exact BodyTyped.send (EType.var 0) (by simp [system, Flows])
    · exact BodyTyped.send (EType.var 2) (by simp [system, Flows, join, label, push, context])

def outwardSafe : Effects := (effects safeBody).removeAsk.union (workEffects secretReply.work)

theorem safe_handled : HandleTyped system context .low secretReply safeBody outwardSafe :=
  .handle secretReply_ok safeBody_typed

theorem safe_handled_noninterference {ρ σ} (he : LowEq publicObserver context ρ σ) :
    observe publicObserver (runH secretReply ρ safeBody ρ) =
    observe publicObserver (runH secretReply σ safeBody σ) :=
  handled_noninterference publicObserver safe_handled he

def echoArgument : Handler Dest := ⟨.send .console (.var 0), .lit (.boolean false)⟩

theorem reject_argument_leak : ¬ HandlerOK system context secretSig echoArgument := by
  intro h
  cases h.work with
  | send _ hf => simp [system, Flows, secretSig, join, label, push] at hf

def announcesCall : Handler Dest := ⟨.send .console (.lit (.integer 9)), .lit (.boolean false)⟩

theorem announcesCall_ok : HandlerOK system context publicSig announcesCall := by
  constructor
  · exact Typed.send (EType.lit _) (by simp [system, Flows, join, label, publicSig])
  · exact EType.lit _
  · exact Or.inl rfl

def secretCall : Body Dest := .ite (.var 0)
  (.ask (.lit (.boolean false)) .skip) .skip

theorem reject_secret_call : ¬ BodyTyped system publicSig context .low secretCall := by
  intro h
  cases h with
  | ite _ hy _ =>
      cases hy with
      | ask _ _ hc _ => simp [system, Flows, publicSig, join, label, context] at hc

theorem effect_erasure_does_not_erase_secret :
    ((effects leakReply).removeAsk.union (workEffects secretReply.work)).ask = false ∧
    observe publicObserver (runH secretReply (state true) leakReply (state true)) ≠
    observe publicObserver (runH secretReply (state false) leakReply (state false)) := by
  constructor
  · rfl
  · decide

#guard (effects leakReply).ask
#guard !((effects leakReply).removeAsk.union (workEffects secretReply.work)).ask
#guard observe publicObserver (runH secretReply (state true) leakReply (state true)) !=
  observe publicObserver (runH secretReply (state false) leakReply (state false))
#guard observe publicObserver (runH announcesCall (state true) secretCall (state true)) !=
  observe publicObserver (runH announcesCall (state false) secretCall (state false))
#guard observe publicObserver (runH secretReply (state true) safeBody (state true)) ==
  [(.console, .integer 7)]
#guard !outwardSafe.ask

end Examples
end Handlers

/-! ## 段4: 値の印とpcを追い、拒否で停止する実行時監視。

印と値は、印付きの環境の二つの射影として保持する。
静的なTypedを前提にせず、実行された枝だけを検査する。
拒否した場合は、それまでの出力列を残して全体を停止する。
証明した二実行の定理は、両方の正常終了を前提にする。
-/
namespace Dynamic

abbrev Tags (L : Type) := Nat → L

def levels (S : System L D) (tags : Tags L) : Expr → L
  | .lit _ => S.bottom
  | .var i => tags i
  | .equal a b => S.join (levels S tags a) (levels S tags b)

def LowEq (O : Observer S) (tags : Tags L) (ρ σ : Env) : Prop :=
  ∀ i, O.visible (tags i) = true → ρ i = σ i

theorem expr_low_eq (O : Observer S) {tags ρ σ} (he : LowEq O tags ρ σ)
    (e : Expr) (hv : O.visible (levels S tags e) = true) : eval e ρ = eval e σ := by
  induction e with
  | lit => rfl
  | var i => exact he i hv
  | equal a b ia ib =>
      rw [eval, eval, ia (visible_join_left O hv), ib (visible_join_right O hv)]

theorem lowEq_push (O : Observer S) {tags ρ σ l v w}
    (h : LowEq O tags ρ σ) (hv : O.visible l = true → v = w) :
    LowEq O (push l tags) (push v ρ) (push w σ) := by
  intro i hi
  cases i with
  | zero => exact hv hi
  | succ i => exact h i hi

/-- 実行時監視の成功した評価の関係。
静的な型付けと異なり、選んだ枝だけを前提にする。
-/
inductive Accepted (S : System L D) : Tags L → L → Cmd D → Env → Trace D → Prop where
  | skip {tags pc ρ} : Accepted S tags pc .skip ρ []
  | letIn {tags pc e body ρ tr} :
      Accepted S (push (S.join pc (levels S tags e)) tags) pc body (push (eval e ρ) ρ) tr →
      Accepted S tags pc (.letIn e body) ρ tr
  | seq {tags pc a b ρ ta tb} : Accepted S tags pc a ρ ta → Accepted S tags pc b ρ tb →
      Accepted S tags pc (.seq a b) ρ (ta ++ tb)
  | ite {tags pc e yes no ρ tr} :
      Accepted S tags (S.join pc (levels S tags e))
        (if eval e ρ = .boolean true then yes else no) ρ tr →
      Accepted S tags pc (.ite e yes no) ρ tr
  | send {tags pc d e ρ} : S.flows (S.join pc (levels S tags e)) (S.sink d) →
      Accepted S tags pc (.send d e) ρ [(d, eval e ρ)]

theorem high_pc (O : Observer S) {tags pc c ρ tr} (ha : Accepted S tags pc c ρ tr) :
    O.visible pc = false → observe O tr = [] := by
  induction ha with
  | skip => intro _; rfl
  | letIn _ ih => exact ih
  | seq _ _ ia ib => intro hp; simp [observe_append, ia hp, ib hp]
  | ite _ ih => intro hp; exact ih (hidden_join_left O hp)
  | @send tags pc d e ρ hf =>
      intro hp
      have hd := Handlers.hidden_of_flow O hf (hidden_join_left O hp)
      simp [observe, hd]

theorem accepted_noninterference (O : Observer S) {tags pc c ρ tr}
    (ha : Accepted S tags pc c ρ tr) :
    ∀ {σ ts}, LowEq O tags ρ σ → Accepted S tags pc c σ ts → observe O tr = observe O ts := by
  induction ha with
  | skip => intro σ ts _ hb; cases hb; rfl
  | @letIn tags pc e body ρ tr hb ih =>
      intro σ ts he hs
      cases hs with
      | letIn hs =>
          apply ih (lowEq_push O he ?_) hs
          intro hv
          exact expr_low_eq O he e (visible_join_right O hv)
  | seq ha hb ia ib =>
      intro σ ts he hs
      cases hs with
      | seq sa sb => simp only [observe_append, ia he sa, ib he sb]
  | @ite tags pc e yes no ρ tr hb ih =>
      intro σ ts he hs
      cases hs with
      | ite hs =>
          cases hv : O.visible (levels S tags e) with
          | true =>
              have eqv := expr_low_eq O he e hv
              rw [← eqv] at hs
              exact ih he hs
          | false =>
              have hp := hidden_join_right O (a := pc) hv
              rw [high_pc O hb hp, high_pc O hs hp]
  | @send tags pc d e ρ hf =>
      intro σ ts he hs
      cases hs with
      | send _ =>
          cases hd : O.visible (S.sink d) with
          | false => simp [observe, hd]
          | true =>
              have hv := visible_join_right O (O.flows_visible hf hd)
              rw [expr_low_eq O he e hv]

inductive Result (D : Type) where
  | done (trace : Trace D)
  | blocked (trace : Trace D)
  deriving DecidableEq, Repr

def Result.trace : Result D → Trace D
  | .done tr | .blocked tr => tr

def Result.then (a b : Result D) : Result D :=
  match a, b with
  | .blocked tr, _ => .blocked tr
  | .done ta, .done tb => .done (ta ++ tb)
  | .done ta, .blocked tb => .blocked (ta ++ tb)

variable [DecidableRel S.flows]

def monitor (S : System L D) [DecidableRel S.flows] (tags : Tags L) (pc : L) :
    Cmd D → Env → Result D
  | .skip, _ => .done []
  | .letIn e body, ρ =>
      monitor S (push (S.join pc (levels S tags e)) tags) pc body (push (eval e ρ) ρ)
  | .seq a b, ρ => (monitor S tags pc a ρ).then (monitor S tags pc b ρ)
  | .ite e yes no, ρ =>
      if eval e ρ = .boolean true then monitor S tags (S.join pc (levels S tags e)) yes ρ
      else monitor S tags (S.join pc (levels S tags e)) no ρ
  | .send d e, ρ =>
      if S.flows (S.join pc (levels S tags e)) (S.sink d) then .done [(d, eval e ρ)]
      else .blocked []

theorem monitor_success_sound {tags pc c ρ tr} (h : monitor S tags pc c ρ = .done tr) :
    Accepted S tags pc c ρ tr := by
  induction c generalizing tags pc ρ tr with
  | skip => cases h; exact Accepted.skip
  | letIn e body ih => exact Accepted.letIn (ih h)
  | seq a b ia ib =>
      cases ha : monitor S tags pc a ρ with
      | blocked ta => simp [monitor, ha, Result.then] at h
      | done ta =>
          cases hb : monitor S tags pc b ρ with
          | blocked tb => simp [monitor, ha, hb, Result.then] at h
          | done tb =>
              have ht : tr = ta ++ tb := by simpa [monitor, ha, hb, Result.then] using h.symm
              rw [ht]
              exact Accepted.seq (ia ha) (ib hb)
  | ite e yes no iy ino =>
      apply Accepted.ite
      by_cases hc : eval e ρ = .boolean true
      · simp only [ite_eq_left hc]
        exact iy (by simpa only [monitor, ite_eq_left hc] using h)
      · simp only [ite_eq_right hc]
        exact ino (by simpa only [monitor, ite_eq_right hc] using h)
  | send d e =>
      by_cases hf : S.flows (S.join pc (levels S tags e)) (S.sink d)
      · have ht : tr = [(d, eval e ρ)] := by simpa only [monitor, ite_eq_left hf, Result.done.injEq] using h.symm
        rw [ht]
        exact Accepted.send hf
      · simp [monitor, hf] at h

theorem monitor_success_complete {tags pc c ρ tr} (ha : Accepted S tags pc c ρ tr) :
    monitor S tags pc c ρ = .done tr := by
  induction ha with
  | skip => rfl
  | letIn _ ih => exact ih
  | seq _ _ ia ib => simp only [monitor, ia, ib, Result.then]
  | @ite tags pc e yes no ρ tr hb ih =>
      by_cases hc : eval e ρ = .boolean true
      · simpa only [monitor, ite_eq_left hc] using ih
      · simpa only [monitor, ite_eq_right hc] using ih
  | send hf => simp only [monitor, ite_eq_left hf]

/-- 両方が正常終了する場合のTINI。
片方を拒否した場合の、そこまでの出力列の一致は主張しない。
-/
theorem monitor_noninterference (O : Observer S) {tags pc c ρ σ tr ts}
    (he : LowEq O tags ρ σ)
    (hρ : monitor S tags pc c ρ = .done tr) (hσ : monitor S tags pc c σ = .done ts) :
    observe O tr = observe O ts :=
  accepted_noninterference O (monitor_success_sound hρ) he (monitor_success_sound hσ)

namespace Examples
open TwoPoint

instance : DecidableRel system.flows := fun a b => by
  change Decidable (Flows a b)
  unfold Flows
  infer_instance

def tags : Tags Level := fun i => if i = 0 then .high else .low

def rejectionChangesSuffix : Cmd Dest := .seq
  (.ite (.var 0) (.send .console (.lit (.integer 1))) .skip)
  (.send .console (.lit (.integer 2)))

theorem initial_low_eq : LowEq publicObserver tags (state true) (state false) := by
  intro i hi
  by_cases h0 : i = 0
  · subst i
    simp [publicObserver, tags] at hi
  · simp [state, h0]

#guard monitor system tags .low implicitLeak (state true) == .blocked []
#guard monitor system tags .low implicitLeak (state false) == .blocked []
#guard monitor system tags .low explicitLeak (state true) == .blocked []
#guard monitor system tags .low rejectionChangesSuffix (state true) == .blocked []
#guard monitor system tags .low rejectionChangesSuffix (state false) ==
  .done [(.console, .integer 2)]

theorem unconditional_trace_equality_fails :
    observe publicObserver (monitor system tags .low rejectionChangesSuffix (state true)).trace ≠
    observe publicObserver (monitor system tags .low rejectionChangesSuffix (state false)).trace := by
  decide

/-- 実行時検査は到達しない不正な枝を通せる。
静的な規則は両方の枝を検査するため、同じプログラムを拒否する。
-/
def deadUnsafeBranch : Cmd Dest := .ite (.lit (.boolean false)) explicitLeak
  (.send .console (.lit (.integer 2)))

theorem static_rejects_dead_branch : ¬ Typed system context .low deadUnsafeBranch := by
  intro h
  cases h with
  | ite _ hy _ => exact reject_explicit hy

#guard monitor system tags .low deadUnsafeBranch (state true) ==
  .done [(.console, .integer 2)]

end Examples
end Dynamic

#eval Lean.versionString
#print axioms noninterference
#print axioms TwoPoint.reject_explicit
#print axioms TwoPoint.reject_implicit
#print axioms Readers.destination_noninterference
#print axioms Readers.pattern_inclusion_gives_flow
#print axioms Readers.intersection_not_single_pattern
#print axioms Readers.host_pattern_noninterference
#print axioms Handlers.handled_noninterference
#print axioms Handlers.handled_ask_removed
#print axioms Handlers.Examples.no_public_reply_contract
#print axioms Handlers.Examples.reject_argument_leak
#print axioms Handlers.Examples.reject_secret_call
#print axioms Handlers.Examples.effect_erasure_does_not_erase_secret
#print axioms Dynamic.monitor_noninterference
#print axioms Dynamic.Examples.unconditional_trace_equality_fails
end SF
