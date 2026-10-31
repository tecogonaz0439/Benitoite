import Benitoite.Release.Refinement.Observation
import Benitoite.Release.Refinement.ClosedDecidable

/-! # 閉じた有限述語の評価と二値の解釈 -/
namespace Benitoite.Release.Refinement

/-- IEEEの有限ビット列を、NaN・符号・大きさを保って比較する。 -/
def ieeeNaN (fraction exponent bits : Nat) : Bool :=
  decide (bits / 2^fraction % 2^exponent = 2^exponent-1 ∧ bits % 2^fraction ≠ 0)
def ieeeZero (fraction exponent bits : Nat) : Bool := decide (bits % 2^(fraction+exponent) = 0)
def ieeeClass (fraction exponent bits : Nat) (c : FloatClass) : Bool :=
  let sign := bits / 2^(fraction+exponent) != 0
  let inf := decide (bits % 2^(fraction+exponent) = (2^exponent-1)*2^fraction)
  match c with
  | .finite => decide (bits / 2^fraction % 2^exponent ≠ 2^exponent-1)
  | .nan => ieeeNaN fraction exponent bits
  | .positiveInfinity => !sign && inf
  | .negativeInfinity => sign && inf
  | .positiveZero => !sign && ieeeZero fraction exponent bits
  | .negativeZero => sign && ieeeZero fraction exponent bits

def Comparison.fromEqLt (o : Comparison) (eq lt gt : Bool) : Bool := match o with
  | .eq => eq | .ne => !eq | .lt => lt | .le => lt || eq | .gt => gt | .ge => gt || eq

def ieeeCompare (fraction exponent x y : Nat) (o : Comparison) : Bool :=
  if ieeeNaN fraction exponent x || ieeeNaN fraction exponent y then o == .ne
  else
    let bothZero := ieeeZero fraction exponent x && ieeeZero fraction exponent y
    let sx := decide (x / 2^(fraction+exponent) ≠ 0)
    let sy := decide (y / 2^(fraction+exponent) ≠ 0)
    let eq := decide (x = y) || bothZero
    let lt := !bothZero && (if sx != sy then sx else if sx then decide (y < x) else decide (x < y))
    let gt := !bothZero && (if sx != sy then sy else if sx then decide (x < y) else decide (y < x))
    o.fromEqLt eq lt gt


def observeAs (η : ObservationEnvModel) (s : «Sort») (t : Term) : Observation :=
  match t.interpret η with
  | some o => if o.sort = s then o else Observation.default s
  | none => Observation.default s

def integerAs (η : ObservationEnvModel) (t : Term) : Int := match observeAs η .integer t with
  | .integer n => n | _ => 0

def Observation.compare (o : Comparison) (a b : Observation) : Bool := match a,b with
  | .character x, .character y => o.fromEqLt (x == y) (decide (x.toNat < y.toNat)) (decide (y.toNat < x.toNat))
  | .decimal c s, .decimal d t =>
      let x := c * (10 : Int)^t
      let y := d * (10 : Int)^s
      o.fromEqLt (x == y) (decide (x < y)) (decide (y < x))
  | .float64 x, .float64 y => ieeeCompare 52 11 x.toNat y.toNat o
  | .float32 x, .float32 y => ieeeCompare 23 8 x.toNat y.toNat o
  | .boolean x, .boolean y => o.fromEqLt (x == y) false false
  | .string x, .string y => o.fromEqLt (x == y) false false
  | .unitValue, .unitValue => o.fromEqLt true false false
  | _,_ => false

def Pred.atomValue (η : ObservationEnvModel) : Pred → Bool
  | .truth => true | .falsity => false
  | .eq a b => decide (integerAs η a = integerAs η b)
  | .le a b => decide (integerAs η a ≤ integerAs η b)
  | .lt a b => decide (integerAs η a < integerAs η b)
  | .compare s o a b => (observeAs η s a).compare o (observeAs η s b)
  | .floatClass w c a => match w,observeAs η (match w with | .binary32 => .float32 | .binary64 => .float64) a with
    | .binary32, .float32 b => ieeeClass 23 8 b.toNat c
    | .binary64, .float64 b => ieeeClass 52 11 b.toNat c
    | _,_ => false
  | .decimalRepresented a => match observeAs η .decimal a with
    | .decimal c s => decide (c.natAbs < 2^96 ∧ s ≤ 28) | _ => false
  | .charactersIn a lo hi => match observeAs η .string a with
    | .string s => s.toList.all (fun c => decide (lo.toNat ≤ c.toNat ∧ c.toNat ≤ hi.toNat)) | _ => false
  | .member k a r => match observeAs η (.target k) a with
    | .targetValue bs t => decide (SnapshotMem bs k r t) | _ => false
  | .constructorIs a c => match observeAs η .data a with
    | .dataValue d _ => decide (d = c) | _ => false
  | .and _ _ | .or _ _ | .not _ => false

def Pred.interpret (η : ObservationEnvModel) : Pred → Bool
  | .and p q => p.interpret η && q.interpret η
  | .or p q => p.interpret η || q.interpret η
  | .not p => !p.interpret η
  | p => p.atomValue η

def termReady (η : ObservationEnvModel) (s : «Sort») (t : Term) : Bool :=
  (t.observe η).any fun o => o.sort == s

/-- readyなら、部分的な観測とモデルの射影が同じsortの値を返す。 -/
theorem termReady_observation {η : ObservationEnvModel} {s : «Sort»} {t : Term}
    (h : termReady η s t = true) :
    ∃ o, t.observe η = some o ∧ o.sort = s ∧ t.interpret η = some o ∧ observeAs η s t = o := by
  unfold termReady at h
  cases ho : t.observe η with
  | none => simp [ho] at h
  | some o =>
    have hs : o.sort = s := by simpa [ho] using h
    have hi := Term.observe_sound ho
    exact ⟨o,rfl,hs,hi,by simp [observeAs,hi,hs]⟩

/-- 解決不能な所属はfalseという観測値でなく、評価不能として扱う。 -/
def memberReady (η : ObservationEnvModel) (k : Scope.Domain.Kind) (a : Term) (r : RangeExpr) : Bool :=
  match a.observe η with
  | some (.targetValue bs t) => decide (t.kind = k ∧ t.WF ∧ r.WF ∧ r.FitsKind k) &&
      (match bs with | none => true | some σ => decide σ.Valid) &&
      (resolveSnapshot bs r).isSome
  | _ => false

def Pred.atomReady (η : ObservationEnvModel) : Pred → Bool
  | .truth | .falsity => true
  | .eq a b | .le a b | .lt a b => termReady η .integer a && termReady η .integer b
  | .compare s o a b => decide (Comparison.Allowed s o) && termReady η s a && termReady η s b
  | .floatClass w _ a => termReady η (match w with | .binary32 => .float32 | .binary64 => .float64) a
  | .decimalRepresented a => termReady η .decimal a
  | .charactersIn a _ _ => termReady η .string a
  | .member k a r => memberReady η k a r
  | .constructorIs a _ => termReady η .data a
  | .and _ _ | .or _ _ | .not _ => false

def Pred.evalWith (η : ObservationEnvModel) : Pred → Option Bool
  | .and p q => match p.evalWith η, q.evalWith η with
    | some false, _ | _, some false => some false
    | some true, some true => some true
    | _, _ => none
  | .or p q => match p.evalWith η, q.evalWith η with
    | some true, _ | _, some true => some true
    | some false, some false => some false
    | _, _ => none
  | .not p => (p.evalWith η).map Bool.not
  | p => if p.atomReady η then some (p.atomValue η) else none

def Pred.evalClosed (p : Pred) : Option Bool :=
  if p.WF 0 ∧ p.Sorted [] none then p.evalWith (fun _ => none) else none

def Pred.Atomic : Pred → Prop
  | .and _ _ | .or _ _ | .not _ => False
  | _ => True

/-- 構文を辿り、原子に必要な観測がすべて得られることを検査する。 -/
inductive Pred.ClosedObservable : Pred → Prop where
  | atom {p : Pred} : p.Atomic → p.atomReady (fun _ => none) = true → Pred.ClosedObservable p
  | and {p q : Pred} : Pred.ClosedObservable p → Pred.ClosedObservable q → Pred.ClosedObservable (.and p q)
  | or {p q : Pred} : Pred.ClosedObservable p → Pred.ClosedObservable q → Pred.ClosedObservable (.or p q)
  | not {p : Pred} : Pred.ClosedObservable p → Pred.ClosedObservable (.not p)

theorem Pred.evalWith_sound {p : Pred} {b : Bool} {η : ObservationEnvModel} (h : p.evalWith η = some b) : p.interpret η = b := by
  induction p generalizing b with
  | and p q ihp ihq | or p q ihp ihq =>
    cases hp : p.evalWith η with
    | none =>
      cases hq : q.evalWith η with
      | none => simp [Pred.evalWith, hp, hq] at h
      | some c => cases c <;> simp_all [Pred.evalWith, Pred.interpret]
    | some c =>
      cases c <;> cases hq : q.evalWith η with
      | none => simp_all [Pred.evalWith, Pred.interpret]
      | some d => cases d <;> simp_all [Pred.evalWith, Pred.interpret]
  | not p ih =>
    cases hp : p.evalWith η <;> simp [Pred.evalWith, hp] at h
    cases h; simp [Pred.interpret, ih hp]
  | _ =>
    simp only [Pred.evalWith] at h
    split at h <;> simp_all [Pred.interpret]

theorem Pred.evalClosed_sound {p : Pred} {b : Bool} (_hw : p.WF 0) (_hs : p.Sorted [] none)
    (h : p.evalClosed = some b) : p.interpret (fun _ => none) = b := by
  unfold Pred.evalClosed at h
  split at h
  · exact Pred.evalWith_sound h
  · cases h

private theorem observable_eval {p : Pred} (h : p.ClosedObservable) :
    p.evalWith (fun _ => none) = some (p.interpret (fun _ => none)) := by
  induction h with
  | @atom p ha hr => cases p <;> simp_all [Pred.Atomic, Pred.evalWith, Pred.interpret]
  | @and p q _ _ ih₁ ih₂ | @or p q _ _ ih₁ ih₂ =>
    cases hp : p.interpret (fun _ => none) <;> cases hq : q.interpret (fun _ => none) <;>
      simp_all [Pred.evalWith, Pred.interpret]
  | not _ ih => simp [Pred.evalWith, Pred.interpret, ih]

theorem Pred.evalClosed_complete {p : Pred} (hw : p.WF 0) (hs : p.Sorted [] none)
    (h : p.ClosedObservable) : p.evalClosed = some (p.interpret (fun _ => none)) := by
  simpa [Pred.evalClosed, hw, hs] using observable_eval h

/-- 相手の観測が欠けても、偽との連言と真との選言は左右どちらでも決まる。 -/
theorem Pred.evalWith_and_false_left {p q : Pred} {η : ObservationEnvModel}
    (h : p.evalWith η = some false) : (p.and q).evalWith η = some false := by
  simp [Pred.evalWith, h]
theorem Pred.evalWith_and_false_right {p q : Pred} {η : ObservationEnvModel}
    (h : q.evalWith η = some false) : (p.and q).evalWith η = some false := by
  cases hp : p.evalWith η with
  | none => simp [Pred.evalWith, hp, h]
  | some b => cases b <;> simp [Pred.evalWith, hp, h]
theorem Pred.evalWith_or_true_left {p q : Pred} {η : ObservationEnvModel}
    (h : p.evalWith η = some true) : (p.or q).evalWith η = some true := by
  simp [Pred.evalWith, h]
theorem Pred.evalWith_or_true_right {p q : Pred} {η : ObservationEnvModel}
    (h : q.evalWith η = some true) : (p.or q).evalWith η = some true := by
  cases hp : p.evalWith η with
  | none => simp [Pred.evalWith, hp, h]
  | some b => cases b <;> simp [Pred.evalWith, hp, h]

private theorem evalWith_of_evalClosed {p : Pred} {b : Bool}
    (h : p.evalClosed = some b) : p.evalWith (fun _ => none) = some b := by
  unfold Pred.evalClosed at h
  split at h
  · exact h
  · cases h

theorem Pred.evalClosed_and_false_left {p q : Pred}
    (hw : (p.and q).WF 0) (hs : (p.and q).Sorted [] none)
    (h : p.evalClosed = some false) : (p.and q).evalClosed = some false := by
  simpa [Pred.evalClosed, hw, hs] using
    (Pred.evalWith_and_false_left (q := q) (evalWith_of_evalClosed h))
theorem Pred.evalClosed_and_false_right {p q : Pred}
    (hw : (p.and q).WF 0) (hs : (p.and q).Sorted [] none)
    (h : q.evalClosed = some false) : (p.and q).evalClosed = some false := by
  simpa [Pred.evalClosed, hw, hs] using
    (Pred.evalWith_and_false_right (p := p) (evalWith_of_evalClosed h))
theorem Pred.evalClosed_or_true_left {p q : Pred}
    (hw : (p.or q).WF 0) (hs : (p.or q).Sorted [] none)
    (h : p.evalClosed = some true) : (p.or q).evalClosed = some true := by
  simpa [Pred.evalClosed, hw, hs] using
    (Pred.evalWith_or_true_left (q := q) (evalWith_of_evalClosed h))
theorem Pred.evalClosed_or_true_right {p q : Pred}
    (hw : (p.or q).WF 0) (hs : (p.or q).Sorted [] none)
    (h : q.evalClosed = some true) : (p.or q).evalClosed = some true := by
  simpa [Pred.evalClosed, hw, hs] using
    (Pred.evalWith_or_true_right (p := p) (evalWith_of_evalClosed h))

theorem Pred.bind_closed {p : Pred} (h : p.WF 0) (ν : ObservationEnv) : predBind ν p = p := by
  calc
    predBind ν p = predBind (fun i => some (.var i)) p :=
      Pred.bind_congr (Pred.varsIn_mono h (fun _ hi => by omega))
    _ = p := predBind_id p

theorem Pred.interpret_congr {p : Pred} {η ξ : ObservationEnvModel}
    (h : p.VarsIn (fun i => η i = ξ i)) : p.interpret η = p.interpret ξ := by
  cases p with
  | truth | falsity => rfl
  | and p q | or p q =>
    simp only [Pred.interpret]
    rw [Pred.interpret_congr h.1, Pred.interpret_congr h.2]
  | not p => simp only [Pred.interpret]; rw [Pred.interpret_congr (p := p) h]
  | eq a b | le a b | lt a b =>
    simp only [Pred.interpret, Pred.atomValue, integerAs, observeAs]
    simp only [Term.interpret_congr (t := a) h.1, Term.interpret_congr (t := b) h.2]
    rfl
  | compare s o a b =>
    simp only [Pred.interpret, Pred.atomValue, observeAs]
    simp only [Term.interpret_congr (t := a) h.1, Term.interpret_congr (t := b) h.2]
  | floatClass w c a | decimalRepresented a | charactersIn a lo hi | member k a r | constructorIs a c =>
    simp only [Pred.interpret, Pred.atomValue, observeAs]
    simp only [Term.interpret_congr (t := a) h]

theorem Pred.interpret_closed {p : Pred} (h : p.WF 0) (η : ObservationEnvModel) :
    p.interpret η = p.interpret (fun _ => none) :=
  Pred.interpret_congr (Pred.varsIn_mono h (fun _ hi => by omega))

/-- sort不適格と自由変数残りは、原子の既定値によって成功にならない。 -/
theorem Pred.evalClosed_unsorted {p : Pred} (h : ¬ p.Sorted [] none) : p.evalClosed = none := by
  simp [Pred.evalClosed, h]
theorem Pred.evalClosed_open {p : Pred} (h : ¬ p.WF 0) : p.evalClosed = none := by
  simp [Pred.evalClosed, h]
theorem Pred.evalClosed_not_failure {p : Pred} (h : p.evalClosed = none) :
    p.not.evalClosed = none := by
  have he : p.not.evalClosed = p.evalClosed.map Bool.not := by
    unfold Pred.evalClosed
    change (if p.WF 0 ∧ p.Sorted [] none then p.not.evalWith (fun _ => none) else none) = _
    by_cases hw : p.WF 0 ∧ p.Sorted [] none <;> simp [hw, Pred.evalWith]
  rw [he, h]
  rfl

end Benitoite.Release.Refinement
