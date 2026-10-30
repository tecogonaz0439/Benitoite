/- P3: P1.TyLe.refine と P2.implication_sound の接続。
   本文の前に P1/Skeleton.lean と P2/lean/P2.lean を複写して検査する。
   本番の machine/delta の対応を証明したファイルではない。 -/
namespace P3M6
open P1 P2

inductive Width where
  | integer | int8 | int16 | int32 | uint16 | uint32 | uint64 | byte
  deriving DecidableEq

def Width.bounds : Width → Int × Int
  | .integer => (-(2^63), 2^63-1)
  | .int8 => (-(2^7), 2^7-1)
  | .int16 => (-(2^15), 2^15-1)
  | .int32 => (-(2^31), 2^31-1)
  | .byte => (0, 2^8-1)
  | .uint16 => (0, 2^16-1)
  | .uint32 => (0, 2^32-1)
  | .uint64 => (0, 2^64-1)

/-- key は別名を解決した安定した根・可視な不変の欄の列・measure の組を想定する。
    その正規化器自体の証明は本番で必要。 -/
structure Model (V K : Type) where
  valid : (Option V → Value) → Prop
  slot : K → Nat
  unique : Function.Injective slot
  atom : K → P1.Expr (Option V)
  captured : (Option V → Value) → K → Int
  current : (Option V → Value) → K → Int
  stable : ∀ ρ, valid ρ → ∀ k, current ρ k = captured ρ k
  machine_exact : ∀ ρ, valid ρ → ∀ k, (atom k).eval ρ = some (.int (current ρ k))
  width : K → Option Width
  represented : ∀ ρ, valid ρ → ∀ k w, width k = some w →
    w.bounds.1 ≤ current ρ k ∧ current ρ k ≤ w.bounds.2

noncomputable def Model.env (m : Model V K) (ρ : Option V → Value) : P2.Env :=
  by
  classical
  exact fun n => if h : ∃ k, m.slot k = n then m.captured ρ (Classical.choose h) else 0

theorem Model.env_slot (m : Model V K) (ρ : Option V → Value) (k : K) :
    m.env ρ (m.slot k) = m.captured ρ k := by
  classical
  unfold Model.env
  split
  next h =>
    have he : Classical.choose h = k := m.unique (Classical.choose_spec h)
    rw [he]
  next h => exact False.elim (h ⟨k, rfl⟩)

theorem Model.atom_exact (m : Model V K) (ρ : Option V → Value) (hv : m.valid ρ) (k : K) :
    (m.atom k).eval ρ = some (.int (m.env ρ (m.slot k))) := by
  rw [m.env_slot, ← m.stable ρ hv]
  exact m.machine_exact ρ hv k

theorem Model.width_fact (m : Model V K) (ρ : Option V → Value) (hv : m.valid ρ) (k : K) (w : Width)
    (hw : m.width k = some w) :
    w.bounds.1 ≤ m.env ρ (m.slot k) ∧ m.env ρ (m.slot k) ≤ w.bounds.2 := by
  rw [m.env_slot, ← m.stable ρ hv]
  exact m.represented ρ hv k w hw

inductive Term (K : Type) where
  | lit (i : Int)
  | key (k : K)
  | add (a b : Term K)

def Term.source (m : Model V K) : Term K → P1.Expr (Option V)
  | .lit i => .lit (.int i)
  | .key k => m.atom k
  | .add a b => .add (a.source m) (b.source m)

def Term.lower (m : Model V K) : Term K → Affine
  | .lit i => ⟨[], i⟩
  | .key k => ⟨unitCoeffs (m.slot k), 0⟩
  | .add a b => ⟨addCoeffs (a.lower m).coeffs (b.lower m).coeffs,
      (a.lower m).constant + (b.lower m).constant⟩

noncomputable def Term.denote (m : Model V K) (t : Term K) (ρ : Option V → Value) : Int :=
  dot (t.lower m).coeffs (m.env ρ) + (t.lower m).constant

theorem Term.source_exact (m : Model V K) (t : Term K) (ρ : Option V → Value) (hv : m.valid ρ) :
    (t.source m).eval ρ = some (.int (t.denote m ρ)) := by
  induction t with
  | lit i => simp [source, P1.Expr.eval, denote, lower, dot]
  | key k => simpa [source, denote, lower, dot_unit] using m.atom_exact ρ hv k
  | add a b ia ib =>
    simp only [source, P1.Expr.eval, ia, ib]
    congr 2
    simp [denote, lower, dot_add]
    omega

def comparison (a b : Affine) : Lin :=
  ⟨addCoeffs a.coeffs (scaleCoeffs (-1) b.coeffs), b.constant - a.constant⟩

inductive Predicate (K : Type) where
  | le (a b : Term K)
  | eq (a b : Term K)
  | and (p q : Predicate K)
  | or (p q : Predicate K)
  | not (p : Predicate K)

def Predicate.source (m : Model V K) : Predicate K → P1.Pred (Option V)
  | .le a b => .le (a.source m) (b.source m)
  | .eq a b => .eq (a.source m) (b.source m)
  | .and p q => .and (p.source m) (q.source m)
  | .or p q => .or (p.source m) (q.source m)
  | .not p => .not (p.source m)

def Predicate.lower (m : Model V K) : Predicate K → Formula
  | .le a b => .le (comparison (a.lower m) (b.lower m))
  | .eq a b => .eq (comparison (a.lower m) (b.lower m))
  | .and p q => .and (p.lower m) (q.lower m)
  | .or p q => .or (p.lower m) (q.lower m)
  | .not p => .not (p.lower m)

theorem Predicate.lower_correct (m : Model V K) (p : Predicate K) (ρ : Option V → Value) (hv : m.valid ρ) :
    (p.lower m).Holds (m.env ρ) ↔ (p.source m).Holds ρ := by
  induction p with
  | le a b =>
    simp only [lower, Formula.Holds, Lin.Holds, comparison, dot_add, dot_scale,
      source, P1.Pred.Holds, Term.source_exact m _ ρ hv]
    constructor
    · intro h
      exact ⟨a.denote m ρ, b.denote m ρ, rfl, rfl, by unfold Term.denote; omega⟩
    · rintro ⟨x, y, hx, hy, hxy⟩
      have hx' : a.denote m ρ = x := by exact Value.int.inj (Option.some.inj hx)
      have hy' : b.denote m ρ = y := by exact Value.int.inj (Option.some.inj hy)
      unfold Term.denote at hx' hy'
      omega
  | eq a b =>
    simp only [lower, Formula.Holds, comparison, dot_add, dot_scale,
      source, P1.Pred.Holds, Term.source_exact m _ ρ hv]
    constructor
    · intro h
      refine ⟨.int (a.denote m ρ), rfl, ?_⟩
      congr 2
      unfold Term.denote
      omega
    · rintro ⟨v, hv, hw⟩
      have he : a.denote m ρ = b.denote m ρ := by
        have hh := hv.trans hw.symm
        exact Value.int.inj (Option.some.inj hh)
      unfold Term.denote at he
      omega
  | and p q ip iq => exact and_congr ip iq
  | or p q ip iq => exact or_congr ip iq
  | not p ip => exact not_congr ip

/-- trustedFacts は利用者の任意の登録口ではない。本番では有限の組込みの補題から構成する。
    幅の上下限は width_fact、List の非負性は Int.ofNat_nonneg 等で証明して渡す。 -/
theorem checked_subtype (m : Model V K) (w : World) (η : Interp T E R)
    (Φ : (V → Value) → Prop) (carrier : Ty T E R V)
    (p q : Predicate K) (contextFacts trustedFacts : Formula)
    (sort_ok : ∀ ρ, Φ ρ → ∀ x, carrier.Mem w η ρ x → m.valid (extend ρ x))
    (context_ok : ∀ ρ, Φ ρ → ∀ x, carrier.Mem w η ρ x →
      contextFacts.Holds (m.env (extend ρ x)))
    (builtin_ok : ∀ ρ, Φ ρ → ∀ x, carrier.Mem w η ρ x →
      trustedFacts.Holds (m.env (extend ρ x)))
    (cert : Cert)
    (checked : check (.and (.and contextFacts (.and trustedFacts (p.lower m)))
      (.not (q.lower m))) cert = true) :
    TyLe w η Φ (.refined carrier (p.source m)) (.refined carrier (q.source m)) := by
  apply TyLe.refine TyLe.refl
  intro ρ hΦ x hc hp
  apply (q.lower_correct m (extend ρ x) (sort_ok ρ hΦ x hc)).mp
  apply implication_sound (.and contextFacts (.and trustedFacts (p.lower m)))
    (q.lower m) cert checked (m.env (extend ρ x))
  exact ⟨context_ok ρ hΦ x hc, builtin_ok ρ hΦ x hc,
    (p.lower_correct m (extend ρ x) (sort_ok ρ hΦ x hc)).mpr hp⟩

/-- 同じ番号を異なる値へ使うと、値の意味を保存する環境を作れない。 -/
theorem collision_impossible (slot : Bool → Nat) (h : slot false = slot true)
    (env : Nat → Int) (h0 : env (slot false) = 0) (h1 : env (slot true) = 1) : False := by
  rw [h] at h0
  omega

def listLength (v : Value) : Int := match v with
  | .list xs => xs.length
  | _ => 0

def lengthModel : Model Empty Unit where
  valid ρ := ∃ xs, ρ none = .list xs
  slot _ := 0
  unique := by intro a b _; cases a; cases b; rfl
  atom _ := .length (.var none)
  captured ρ _ := listLength (ρ none)
  current ρ _ := listLength (ρ none)
  stable _ _ _ := rfl
  machine_exact := by
    intro ρ h _
    rcases h with ⟨xs, hx⟩
    simp [P1.Expr.eval, hx, listLength]
  width _ := none
  represented := by intro ρ _ k w h; cases h

def zeroLeZero : Predicate Unit := .le (.lit 0) (.lit 0)
def nonnegativeLength : Predicate Unit := .le (.lit 0) (.key ())
def trueFact : Formula := .le ⟨[], 0⟩
def lengthFact : Formula := .le ⟨[-1], 0⟩
def consumeMany : Nat → Cert → Cert
  | 0, c => c
  | n+1, c => .consume (consumeMany n c)
def lengthCert : Cert := consumeMany 7
  (.derive (.combine [(1,1), (3,1)] ⟨[0],-1⟩) (.close 4))

example : check (.and (.and trueFact (.and lengthFact (zeroLeZero.lower lengthModel)))
    (.not (nonnegativeLength.lower lengthModel))) lengthCert = true := by decide

theorem length_fact_valid (ρ : Option Empty → Value) (hv : lengthModel.valid ρ) :
    lengthFact.Holds (lengthModel.env ρ) := by
  have he := lengthModel.env_slot ρ ()
  rcases hv with ⟨xs, hx⟩
  change lengthModel.env ρ 0 = listLength (ρ none) at he
  rw [hx] at he
  change lengthModel.env ρ 0 = (xs.length : Int) at he
  simp only [lengthFact, Formula.Holds, Lin.Holds, dot]
  rw [he]
  omega

/-- 組込みの長さの非負性を事実として使い、実際の証明書を検査して篩を導入する例。 -/
theorem length_subtype (w : World) (η : Interp Empty Empty Empty) :
    TyLe w η (fun _ : Empty → Value => True)
      (.refined (.list .int) (zeroLeZero.source lengthModel))
      (.refined (.list .int) (nonnegativeLength.source lengthModel)) := by
  apply checked_subtype lengthModel w η (fun _ => True) (.list .int)
    zeroLeZero nonnegativeLength trueFact lengthFact (cert := lengthCert)
  · intro ρ _ x hc
    rcases hc with ⟨xs, hx, _⟩
    exact ⟨xs, hx⟩
  · intro ρ _ x _
    simp [trueFact, Formula.Holds, Lin.Holds, dot]
  · intro ρ _ x hc
    rcases hc with ⟨xs, hx, _⟩
    exact length_fact_valid (extend ρ x) ⟨xs, hx⟩
  · decide

def wordModel (width : Width) (i : Int) (hi : width.bounds.1 ≤ i ∧ i ≤ width.bounds.2) :
    Model Empty Unit where
  valid _ := True
  slot _ := 0
  unique := by intro a b _; cases a; cases b; rfl
  atom _ := .lit (.int i)
  captured _ _ := i
  current _ _ := i
  stable _ _ _ := rfl
  machine_exact _ _ _ := rfl
  width _ := some width
  represented _ _ _ _ he := by cases he; exact hi

example : (wordModel .uint64 (2^64-1) (by decide)).width () = some .uint64 := rfl
example : (2^64-1 : Int) > 9223372036854775807 := by decide

#print axioms checked_subtype
#print axioms Predicate.lower_correct
#print axioms collision_impossible
#print axioms length_subtype
end P3M6
