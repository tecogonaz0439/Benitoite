import Lean

/- 新規の独立試作。本番 formal の定義は写していない。 -/
namespace P2
set_option maxRecDepth 4096
set_option maxHeartbeats 800000

abbrev Env := Nat → Int

def dot : List Int → Env → Int
  | [], _ => 0
  | a :: cs, ρ => a * ρ 0 + dot cs (fun i => ρ (i+1))

def addCoeffs : List Int → List Int → List Int
  | [], bs => bs
  | as, [] => as
  | a :: as, b :: bs => (a+b) :: addCoeffs as bs

def scaleCoeffs (k : Int) (cs : List Int) := cs.map (k * ·)

theorem dot_add (as bs : List Int) (ρ : Env) :
    dot (addCoeffs as bs) ρ = dot as ρ + dot bs ρ := by
  induction as generalizing bs ρ with
  | nil => simp [addCoeffs, dot]
  | cons a as ih =>
    cases bs with
    | nil => simp [addCoeffs, dot]
    | cons b bs =>
      simp only [addCoeffs, dot, ih, Int.add_mul]
      omega

theorem dot_scale (k : Int) (cs : List Int) (ρ : Env) :
    dot (scaleCoeffs k cs) ρ = k * dot cs ρ := by
  induction cs generalizing ρ with
  | nil => simp [scaleCoeffs, dot]
  | cons c cs ih =>
    simp only [scaleCoeffs, List.map_cons, dot]
    rw [show List.map (k * ·) cs = scaleCoeffs k cs from rfl, ih]
    simp [Int.mul_add, Int.mul_assoc]

structure Lin where
  coeffs : List Int
  bound : Int
  deriving Repr, BEq, DecidableEq

def Lin.Holds (l : Lin) (ρ : Env) : Prop := dot l.coeffs ρ ≤ l.bound

def Lin.neg (l : Lin) : Lin := ⟨scaleCoeffs (-1) l.coeffs, -l.bound⟩
def Lin.compl (l : Lin) : Lin := ⟨scaleCoeffs (-1) l.coeffs, -l.bound-1⟩
def Lin.strict (l : Lin) : Lin := ⟨l.coeffs, l.bound-1⟩
def Lin.zero : Lin := ⟨[], 0⟩
def Lin.add (a b : Lin) : Lin := ⟨addCoeffs a.coeffs b.coeffs, a.bound+b.bound⟩
def Lin.scale (k : Int) (a : Lin) : Lin := ⟨scaleCoeffs k a.coeffs, k*a.bound⟩

theorem Lin.add_sound (a b : Lin) (ρ : Env) (ha : a.Holds ρ) (hb : b.Holds ρ) :
    (a.add b).Holds ρ := by
  simp only [Lin.Holds, Lin.add, dot_add] at *
  omega

theorem Lin.scale_sound (a : Lin) (k : Int) (ρ : Env) (hk : 0 ≤ k) (ha : a.Holds ρ) :
    (a.scale k).Holds ρ := by
  simp only [Lin.Holds, Lin.scale, dot_scale]
  exact Int.mul_le_mul_of_nonneg_left ha hk

inductive Formula where
  | le (l : Lin)
  | eq (l : Lin)
  | ne (l : Lin)
  | and (a b : Formula)
  | or (a b : Formula)
  | not (a : Formula)
  deriving Repr

def Formula.Holds : Formula → Env → Prop
  | .le l, ρ => l.Holds ρ
  | .eq l, ρ => dot l.coeffs ρ = l.bound
  | .ne l, ρ => dot l.coeffs ρ ≠ l.bound
  | .and a b, ρ => a.Holds ρ ∧ b.Holds ρ
  | .or a b, ρ => a.Holds ρ ∨ b.Holds ρ
  | .not a, ρ => ¬ a.Holds ρ

inductive NNF where
  | le (l : Lin)
  | and (a b : NNF)
  | or (a b : NNF)
  deriving Repr

def NNF.Holds : NNF → Env → Prop
  | .le l, ρ => l.Holds ρ
  | .and a b, ρ => a.Holds ρ ∧ b.Holds ρ
  | .or a b, ρ => a.Holds ρ ∨ b.Holds ρ

def normalize : Formula → Bool → NNF
  | .le l, false => .le l
  | .le l, true => .le l.compl
  | .eq l, false => .and (.le l) (.le l.neg)
  | .eq l, true => .or (.le l.strict) (.le l.neg.strict)
  | .ne l, false => .or (.le l.strict) (.le l.neg.strict)
  | .ne l, true => .and (.le l) (.le l.neg)
  | .and a b, false => .and (normalize a false) (normalize b false)
  | .and a b, true => .or (normalize a true) (normalize b true)
  | .or a b, false => .or (normalize a false) (normalize b false)
  | .or a b, true => .and (normalize a true) (normalize b true)
  | .not a, p => normalize a (!p)

theorem normalize_correct (f : Formula) (p : Bool) (ρ : Env) :
    (normalize f p).Holds ρ ↔ (if p then ¬ f.Holds ρ else f.Holds ρ) := by
  induction f generalizing p with
  | le l => cases p <;> simp [normalize, NNF.Holds, Formula.Holds, Lin.Holds,
      Lin.compl, dot_scale] <;> omega
  | eq l => cases p <;> simp [normalize, NNF.Holds, Formula.Holds, Lin.Holds,
      Lin.neg, Lin.strict, dot_scale] <;> omega
  | ne l => cases p <;> simp [normalize, NNF.Holds, Formula.Holds, Lin.Holds,
      Lin.neg, Lin.strict, dot_scale] <;> omega
  | and a b iha ihb =>
    cases p <;> simp [normalize, NNF.Holds, Formula.Holds, iha, ihb]
    classical
    constructor
    · intro h ha hb; cases h with
      | inl h => exact h ha
      | inr h => exact h hb
    · intro h
      by_cases ha : a.Holds ρ
      · exact Or.inr (h ha)
      · exact Or.inl ha
  | or a b iha ihb =>
    cases p <;> simp [normalize, NNF.Holds, Formula.Holds, iha, ihb]
  | not a ih =>
    cases p <;> simp [normalize, Formula.Holds, ih]


/- 導出は枝内の先行する事実のみを番号で参照する。 -/
inductive Derive where
  | combine (terms : List (Nat × Int)) (expected : Lin)
  | round (id : Nat) (divisor : Int) (expected : Lin)
  deriving Repr

def combination (facts : List Lin) : List (Nat × Int) → Option Lin
  | [] => some Lin.zero
  | (i,k) :: terms => do
    if k < 0 then none else do
      let f ← facts[i]?
      let rest ← combination facts terms
      pure ((f.scale k).add rest)

def derive (facts : List Lin) : Derive → Option Lin
  | .combine terms expected => do
    let got ← combination facts terms
    if got = expected then some expected else none
  | .round i d expected => do
    let src ← facts[i]?
    if 0 < d ∧ scaleCoeffs d expected.coeffs = src.coeffs ∧
        expected.bound = src.bound / d then some expected else none

abbrev FactsHold (facts : List Lin) (ρ : Env) := ∀ l ∈ facts, l.Holds ρ
abbrev TodoHold (todo : List NNF) (ρ : Env) := ∀ f ∈ todo, f.Holds ρ

theorem lookup_sound {i : Nat} {l : Lin} (facts : List Lin) (ρ : Env) (hs : FactsHold facts ρ)
    (hi : facts[i]? = some l) : l.Holds ρ := by
  exact hs l (List.mem_of_getElem? hi)

theorem combination_sound (facts : List Lin) (ρ : Env) (hs : FactsHold facts ρ)
    (terms : List (Nat × Int)) (h : combination facts terms = some l) : l.Holds ρ := by
  induction terms generalizing l with
  | nil => simp [combination] at h; cases h; simp [Lin.Holds, Lin.zero, dot]
  | cons term terms ih =>
    rcases term with ⟨i,k⟩
    simp only [combination] at h
    split at h
    · contradiction
    · rename_i hk
      cases hi : facts[i]? with
      | none => simp [hi] at h
      | some f =>
        cases hr : combination facts terms with
        | none => simp [hi, hr] at h
        | some rest =>
          simp [hi, hr] at h
          cases h
          exact Lin.add_sound _ _ ρ
            (Lin.scale_sound f k ρ (by omega) (lookup_sound facts ρ hs hi)) (ih hr)

theorem derive_sound (facts : List Lin) (ρ : Env) (hs : FactsHold facts ρ)
    (d : Derive) (h : derive facts d = some l) : l.Holds ρ := by
  cases d with
  | combine terms expected =>
    simp only [derive] at h
    cases hc : combination facts terms with
    | none => simp [hc] at h
    | some got =>
      simp [hc] at h
      rcases h with ⟨rfl, rfl⟩
      exact combination_sound facts ρ hs terms hc
  | round i d expected =>
    simp only [derive] at h
    cases hi : facts[i]? with
    | none => simp [hi] at h
    | some src =>
      simp [hi] at h
      rcases h with ⟨⟨hd, hc, hb⟩, rfl⟩
      have hf := lookup_sound facts ρ hs hi
      unfold Lin.Holds at *
      rw [← hc, dot_scale] at hf
      rw [hb]
      exact (Int.le_ediv_iff_mul_le hd).mpr (by simpa [Int.mul_comm] using hf)

inductive Cert where
  | consume (next : Cert)
  | cases (left right : Cert)
  | derive (d : Derive) (next : Cert)
  | close (id : Nat)
  | split (var : Nat) (cut : Int) (left right : Cert)
  deriving Repr

def unitCoeffs : Nat → List Int
  | 0 => [1]
  | n+1 => 0 :: unitCoeffs n

def splitLe (var : Nat) (cut : Int) : Lin := ⟨unitCoeffs var, cut⟩
def splitGt (var : Nat) (cut : Int) : Lin := (splitLe var cut).compl

theorem dot_unit (var : Nat) (ρ : Env) : dot (unitCoeffs var) ρ = ρ var := by
  induction var generalizing ρ with
  | zero => simp [unitCoeffs, dot]
  | succ n ih => simpa [unitCoeffs, dot] using ih (fun i => ρ (i+1))

def refute (todo : List NNF) (facts : List Lin) : Cert → Bool
  | .consume next =>
    match todo with
    | .le l :: rest => refute rest (facts ++ [l]) next
    | .and a b :: rest => refute (a :: b :: rest) facts next
    | _ => false
  | .cases left right =>
    match todo with
    | .or a b :: rest => refute (a :: rest) facts left && refute (b :: rest) facts right
    | _ => false
  | .derive d next =>
    match derive facts d with
    | some l => refute todo (facts ++ [l]) next
    | none => false
  | .close i =>
    match facts[i]? with
    | some l => l.coeffs.all (· == 0) && decide (l.bound < 0)
    | none => false
  | .split var cut left right =>
    refute todo (facts ++ [splitLe var cut]) left &&
    refute todo (facts ++ [splitGt var cut]) right

def check (formula : Formula) (cert : Cert) : Bool :=
  refute [normalize formula false] [] cert

theorem append_holds (facts : List Lin) (l : Lin) (ρ : Env)
    (hs : FactsHold facts ρ) (hl : l.Holds ρ) : FactsHold (facts ++ [l]) ρ := by
  intro f hf
  simp only [List.mem_append, List.mem_singleton] at hf
  rcases hf with hf | rfl
  · exact hs f hf
  · exact hl

theorem dot_zero (cs : List Int) (ρ : Env) (h : cs.all (· == 0) = true) :
    dot cs ρ = 0 := by
  induction cs generalizing ρ with
  | nil => rfl
  | cons c cs ih =>
    simp only [List.all_cons, Bool.and_eq_true, beq_iff_eq] at h
    simp [dot, h.1, ih _ h.2]

theorem refute_sound (cert : Cert) (todo : List NNF) (facts : List Lin) (ρ : Env)
    (hc : refute todo facts cert = true) (ht : TodoHold todo ρ) (hf : FactsHold facts ρ) : False := by
  induction cert generalizing todo facts with
  | consume next ih =>
    cases todo with
    | nil => simp [refute] at hc
    | cons f rest =>
      have hh := ht f (by simp)
      have hr : TodoHold rest ρ := fun g hg => ht g (by simp [hg])
      cases f with
      | le l =>
        exact ih rest (facts ++ [l]) hc hr (append_holds facts l ρ hf hh)
      | and a b =>
        apply ih (a :: b :: rest) facts hc _ hf
        intro g hg
        simp only [List.mem_cons] at hg
        rcases hg with rfl | rfl | hg
        · exact hh.1
        · exact hh.2
        · exact hr g hg
      | or a b => simp [refute] at hc
  | cases left right ihl ihr =>
    cases todo with
    | nil => simp [refute] at hc
    | cons f rest =>
      have hh := ht f (by simp)
      have hr : TodoHold rest ρ := fun g hg => ht g (by simp [hg])
      cases f with
      | le l => simp [refute] at hc
      | and a b => simp [refute] at hc
      | or a b =>
        simp only [refute, Bool.and_eq_true] at hc
        cases hh with
        | inl ha =>
          apply ihl (a :: rest) facts hc.1 _ hf
          intro g hg; simp only [List.mem_cons] at hg
          rcases hg with rfl | hg
          · exact ha
          · exact hr g hg
        | inr hb =>
          apply ihr (b :: rest) facts hc.2 _ hf
          intro g hg; simp only [List.mem_cons] at hg
          rcases hg with rfl | hg
          · exact hb
          · exact hr g hg
  | derive d next ih =>
    cases hd : derive facts d with
    | none => simp [refute, hd] at hc
    | some l =>
      simp only [refute, hd] at hc
      exact ih todo (facts ++ [l]) hc ht
        (append_holds facts l ρ hf (derive_sound facts ρ hf d hd))
  | close i =>
    cases hi : facts[i]? with
    | none => simp [refute, hi] at hc
    | some l =>
      simp only [refute, hi, Bool.and_eq_true, decide_eq_true_eq] at hc
      have hl := lookup_sound facts ρ hf hi
      unfold Lin.Holds at hl
      rw [dot_zero _ _ hc.1] at hl
      omega
  | split var cut left right ihl ihr =>
    simp only [refute, Bool.and_eq_true] at hc
    by_cases hx : ρ var ≤ cut
    · apply ihl todo (facts ++ [splitLe var cut]) hc.1 ht
      apply append_holds facts _ ρ hf
      simpa [Lin.Holds, splitLe, dot_unit] using hx
    · apply ihr todo (facts ++ [splitGt var cut]) hc.2 ht
      apply append_holds facts _ ρ hf
      simp [Lin.Holds, splitGt, splitLe, Lin.compl, dot_scale, dot_unit]
      omega

theorem check_sound (formula : Formula) (cert : Cert) (hc : check formula cert = true) :
    ∀ ρ, ¬ formula.Holds ρ := by
  intro ρ h
  apply refute_sound cert [normalize formula false] [] ρ hc
  · intro f hf
    simp only [List.mem_singleton] at hf
    subst f
    exact (normalize_correct formula false ρ).mpr h
  · intro f hf; cases hf

theorem implication_sound (assumptions goal : Formula) (cert : Cert)
    (hc : check (.and assumptions (.not goal)) cert = true) :
    ∀ ρ, assumptions.Holds ρ → goal.Holds ρ := by
  intro ρ ha
  classical
  apply Classical.byContradiction
  intro hg
  exact check_sound _ cert hc ρ ⟨ha, hg⟩


/- 実行可能な入口で、異なる証明規則と拒否理由を確かめる。 -/
def parity : Formula := .eq ⟨[2], 1⟩
def parityRound : Cert := .consume (.consume (.consume
  (.derive (.round 0 2 ⟨[1], 0⟩)
  (.derive (.round 1 2 ⟨[-1], -1⟩)
  (.derive (.combine [(2,1), (3,1)] ⟨[0], -1⟩) (.close 4))))))
example : check parity parityRound = true := by decide
example (ρ : Env) : ¬ parity.Holds ρ := check_sound parity parityRound (by decide) ρ

def paritySplit : Cert := .consume (.consume (.consume (.split 0 0
  (.derive (.combine [(1,1), (2,2)] ⟨[0], -1⟩) (.close 3))
  (.derive (.combine [(0,1), (2,2)] ⟨[0], -1⟩) (.close 3)))))
example : check parity paritySplit = true := by decide

def difference : Formula := .and (.le ⟨[1,-1], 0⟩) (.le ⟨[-1,1], -1⟩)
def differenceProof : Cert := .consume (.consume (.consume
  (.derive (.combine [(0,1),(1,1)] ⟨[0,0], -1⟩) (.close 2))))
example : check difference differenceProof = true := by decide

def threeVariable : Formula := .and (.le ⟨[1,-1], 0⟩)
  (.and (.le ⟨[0,1,-1], 0⟩) (.le ⟨[-1,0,1], -1⟩))
def threeVariableProof : Cert := .consume (.consume (.consume (.consume (.consume
  (.derive (.combine [(0,1),(1,1),(2,1)] ⟨[0,0,0], -1⟩) (.close 3))))))
example : check threeVariable threeVariableProof = true := by decide

def orNot : Formula := .and (.or (.le ⟨[1],0⟩) (.le ⟨[-1],-2⟩))
  (.and (.not (.le ⟨[1],0⟩)) (.le ⟨[1],1⟩))
def orNotProof : Cert := .consume (.cases
  (.consume (.consume (.consume (.consume
    (.derive (.combine [(0,1),(1,1)] ⟨[0],-1⟩) (.close 3))))))
  (.consume (.consume (.consume (.consume
    (.derive (.combine [(0,1),(2,1)] ⟨[0],-1⟩) (.close 3)))))))
example : check orNot orNotProof = true := by decide

def notNot : Formula := .and (.not (.not (.le ⟨[1],0⟩))) (.le ⟨[-1],-1⟩)
example : check notNot (.consume (.consume (.consume
  (.derive (.combine [(0,1),(1,1)] ⟨[0],-1⟩) (.close 2))))) = true := by decide

-- 不等号は正規化時に選言となり、両枝が必要である。
def disequality : Formula := .and (.ne ⟨[1],0⟩) (.eq ⟨[1],0⟩)
def disequalityProof : Cert := .consume (.cases
  (.consume (.consume (.consume (.consume
    (.derive (.combine [(0,1),(2,1)] ⟨[0],-1⟩) (.close 3))))))
  (.consume (.consume (.consume (.consume
    (.derive (.combine [(0,1),(1,1)] ⟨[0],-1⟩) (.close 3)))))))
example : check disequality disequalityProof = true := by decide

-- 将来・範囲外の参照、負係数、偽の加重和、0除数、負除数、誤丸めを拒否する。
example : check (.le ⟨[1],0⟩) (.consume (.close 1)) = false := by decide
example : check (.le ⟨[1],0⟩) (.consume
  (.derive (.combine [(0,-1)] ⟨[-1],0⟩) (.close 1))) = false := by decide
example : check (.le ⟨[1],0⟩) (.consume
  (.derive (.combine [(1,1)] ⟨[0],-1⟩) (.close 1))) = false := by decide
example : check (.le ⟨[1],0⟩) (.consume
  (.derive (.combine [(0,1)] ⟨[0],-1⟩) (.close 1))) = false := by decide
example : derive [⟨[2],1⟩] (.round 0 0 ⟨[1],0⟩) = none := by decide
example : derive [⟨[2],1⟩] (.round 0 (-2) ⟨[-1],-1⟩) = none := by decide
example : derive [⟨[-2],-1⟩] (.round 0 2 ⟨[-1],0⟩) = none := by decide
example : derive [⟨[3],1⟩] (.round 0 2 ⟨[1],0⟩) = none := by decide
example : check (.or (.le ⟨[], -1⟩) (.le ⟨[],0⟩))
  (.cases (.consume (.close 0)) (.consume (.close 0))) = false := by decide
example : check (.le ⟨[1],0⟩) (.consume (.close 0)) = false := by decide


/- 実際のレコードの欄と List.length を独立変数へ写す。
   同じ recordId は同じ値を指す。値の変更や可変なストアはこのモデルにない。 -/
structure DataRecord where
  items : List Int

structure SourceEnv where
  integers : Nat → Int
  records : Nat → DataRecord

inductive Term where
  | literal (value : Int)
  | variable (id : Nat)
  | lengthItems (recordId : Nat)
  | add (a b : Term)
  | scale (k : Int) (a : Term)
  deriving Repr

def Term.eval : Term → SourceEnv → Int
  | .literal k, _ => k
  | .variable i, ρ => ρ.integers i
  | .lengthItems r, ρ => Int.ofNat (ρ.records r).items.length
  | .add a b, ρ => a.eval ρ + b.eval ρ
  | .scale k a, ρ => k * a.eval ρ

-- 偶数の変数番号は整数変数、奇数は record.items の長さである。
def purifyEnv (ρ : SourceEnv) (slot : Nat) : Int :=
  if slot % 2 = 0 then ρ.integers (slot/2)
  else Int.ofNat (ρ.records (slot/2)).items.length

structure Affine where
  coeffs : List Int
  constant : Int

def Term.purify : Term → Affine
  | .literal k => ⟨[], k⟩
  | .variable i => ⟨unitCoeffs (2*i), 0⟩
  | .lengthItems r => ⟨unitCoeffs (2*r+1), 0⟩
  | .add a b => ⟨addCoeffs a.purify.coeffs b.purify.coeffs,
      a.purify.constant + b.purify.constant⟩
  | .scale k a => ⟨scaleCoeffs k a.purify.coeffs, k*a.purify.constant⟩

theorem purifyEnv_variable (ρ : SourceEnv) (i : Nat) :
    purifyEnv ρ (2*i) = ρ.integers i := by simp [purifyEnv, Nat.mul_div_right]

theorem purifyEnv_length (ρ : SourceEnv) (r : Nat) :
    purifyEnv ρ (2*r+1) = Int.ofNat (ρ.records r).items.length := by
  simp [purifyEnv, Nat.add_div, Nat.mul_div_right]

theorem purify_term_correct (t : Term) (ρ : SourceEnv) :
    dot t.purify.coeffs (purifyEnv ρ) + t.purify.constant = t.eval ρ := by
  induction t with
  | literal k => simp [Term.purify, Term.eval, dot]
  | «variable» i => simp [Term.purify, Term.eval, dot_unit, purifyEnv_variable]
  | lengthItems r => simp [Term.purify, Term.eval, dot_unit, purifyEnv_length]
  | add a b iha ihb =>
    simp only [Term.purify, Term.eval, dot_add]
    omega
  | scale k a ih =>
    simp only [Term.purify, Term.eval, dot_scale]
    rw [← ih, Int.mul_add]

inductive SourceFormula where
  | le (a : Term) (bound : Int)
  | eq (a : Term) (bound : Int)
  | ne (a : Term) (bound : Int)
  | and (a b : SourceFormula)
  | or (a b : SourceFormula)
  | not (a : SourceFormula)

def SourceFormula.Holds : SourceFormula → SourceEnv → Prop
  | .le a k, ρ => a.eval ρ ≤ k
  | .eq a k, ρ => a.eval ρ = k
  | .ne a k, ρ => a.eval ρ ≠ k
  | .and a b, ρ => a.Holds ρ ∧ b.Holds ρ
  | .or a b, ρ => a.Holds ρ ∨ b.Holds ρ
  | .not a, ρ => ¬ a.Holds ρ

def SourceFormula.purify : SourceFormula → Formula
  | .le a k => .le ⟨a.purify.coeffs, k-a.purify.constant⟩
  | .eq a k => .eq ⟨a.purify.coeffs, k-a.purify.constant⟩
  | .ne a k => .ne ⟨a.purify.coeffs, k-a.purify.constant⟩
  | .and a b => .and a.purify b.purify
  | .or a b => .or a.purify b.purify
  | .not a => .not a.purify

theorem purify_formula_correct (f : SourceFormula) (ρ : SourceEnv) :
    f.purify.Holds (purifyEnv ρ) ↔ f.Holds ρ := by
  induction f with
  | le a k =>
    have h := purify_term_correct a ρ
    simp only [SourceFormula.purify, Formula.Holds, Lin.Holds, SourceFormula.Holds]
    omega
  | eq a k =>
    have h := purify_term_correct a ρ
    simp only [SourceFormula.purify, Formula.Holds, SourceFormula.Holds]
    omega
  | ne a k =>
    have h := purify_term_correct a ρ
    simp only [SourceFormula.purify, Formula.Holds, SourceFormula.Holds]
    omega
  | and a b iha ihb => simp [SourceFormula.purify, Formula.Holds, SourceFormula.Holds, iha, ihb]
  | or a b iha ihb => simp [SourceFormula.purify, Formula.Holds, SourceFormula.Holds, iha, ihb]
  | not a ih => simp [SourceFormula.purify, Formula.Holds, SourceFormula.Holds, ih]

theorem source_check_sound (f : SourceFormula) (cert : Cert)
    (hc : check f.purify cert = true) (ρ : SourceEnv) : ¬ f.Holds ρ := by
  intro h
  exact check_sound f.purify cert hc (purifyEnv ρ) ((purify_formula_correct f ρ).mpr h)

-- i < List.length(r.items) と List.length(r.items) ≤ i は同時に成り立たない。
def measureExample : SourceFormula :=
  .and (.le (.add (.variable 0) (.scale (-1) (.lengthItems 0))) (-1))
    (.le (.add (.lengthItems 0) (.scale (-1) (.variable 0))) 0)

def measureProof : Cert := .consume (.consume (.consume
  (.derive (.combine [(0,1),(1,1)] ⟨[0,0],-1⟩) (.close 2))))
example : check measureExample.purify measureProof = true := by decide
example (ρ : SourceEnv) : ¬ measureExample.Holds ρ :=
  source_check_sound measureExample measureProof (by decide) ρ

-- 純化した環境が常にソース値で実現するとは主張しない。
-- List.length(r.items) は非負なので、slot 1 = -1 の論理モデルは実現不能である。
theorem negative_length_model_not_realizable :
    ¬ ∃ ρ : SourceEnv, purifyEnv ρ 1 = -1 := by
  intro ⟨ρ, h⟩
  have hp := purifyEnv_length ρ 0
  simp only [Nat.mul_zero, Nat.zero_add] at hp
  have hn : (0 : Int) ≤ Int.ofNat (ρ.records 0).items.length := Int.natCast_nonneg _
  omega

#print axioms normalize_correct
#print axioms derive_sound
#print axioms refute_sound
#print axioms check_sound
#print axioms implication_sound
#print axioms purify_formula_correct
#print axioms source_check_sound

end P2

#check P2.Cert.split 0 (-1) (.close 0) (.close 0)
#check P2.Derive.round 0 (-1) ⟨[-1],-1⟩
