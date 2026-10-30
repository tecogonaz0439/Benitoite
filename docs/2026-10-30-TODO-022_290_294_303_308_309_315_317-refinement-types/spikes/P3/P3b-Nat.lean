import Benitoite.Release.Lemmas.Basic
import Benitoite.Release.TypeBounds

/- Nat の de Bruijn と本番 Ty.WF/Ty.shift を保つ代表。
   元: Release/Types.lean:42-59, TypeShift.lean:19-55,137-155,
   Lemmas/Basic.lean:99-109, TypeBounds.lean:215-220。
   本番 Ty を変更せず、最外の篩の述語を付けるアダプタである。
   依存する関数の Nat 版全体や全ソートの実装ではない。 -/
namespace P3bNat
open Benitoite.Release
set_option maxHeartbeats 200000

inductive Term where
  | var (index : Nat)
  | integer (value : Int)
  | add (a b : Term)
  deriving DecidableEq

def Term.rename (ξ : Nat → Nat) : Term → Term
  | .var i => .var (ξ i)
  | .integer n => .integer n
  | .add a b => .add (a.rename ξ) (b.rename ξ)

def Term.WF (n : Nat) : Term → Prop
  | .var i => i < n
  | .integer _ => True
  | .add a b => a.WF n ∧ b.WF n

inductive Pred where
  | truth
  | le (a b : Term)
  | and (p q : Pred)
  deriving DecidableEq

def Pred.rename (ξ : Nat → Nat) : Pred → Pred
  | .truth => .truth
  | .le a b => .le (a.rename ξ) (b.rename ξ)
  | .and p q => .and (p.rename ξ) (q.rename ξ)

def Pred.WF (n : Nat) : Pred → Prop
  | .truth => True
  | .le a b => a.WF n ∧ b.WF n
  | .and p q => p.WF n ∧ q.WF n

theorem Term.wf_rename {n m : Nat} {t : Term} (h : t.WF n)
    (ξ : Nat → Nat) (hξ : ∀ i, i < n → ξ i < m) : (t.rename ξ).WF m := by
  induction t with
  | var i => exact hξ i h
  | integer _ => trivial
  | add a b ia ib => exact ⟨ia h.1, ib h.2⟩

theorem Pred.wf_rename {n m : Nat} {p : Pred} (h : p.WF n)
    (ξ : Nat → Nat) (hξ : ∀ i, i < n → ξ i < m) : (p.rename ξ).WF m := by
  induction p with
  | truth => trivial
  | le a b => exact ⟨a.wf_rename h.1 ξ hξ, b.wf_rename h.2 ξ hξ⟩
  | and p q ip iq => exact ⟨ip h.1, iq h.2⟩

-- これは論理の有限の構文規則であり、意味上の Subtype を前提にしない。
inductive Entails (Φ : List Pred) : Pred → Pred → Prop where
  | refl (p) : Entails Φ p p
  | trans {p q r} : Entails Φ p q → Entails Φ q r → Entails Φ p r
  | hypothesis {p q} : q ∈ Φ → Entails Φ p q
  | truth {p} : Entails Φ p .truth
  | and_intro {p q r} : Entails Φ p q → Entails Φ p r → Entails Φ p (.and q r)
  | and_left {p q} : Entails Φ (.and p q) p
  | and_right {p q} : Entails Φ (.and p q) q
  | le_refl (t) : Entails Φ .truth (.le t t)

theorem Entails.rename {Φ : List Pred} {p q : Pred} (h : Entails Φ p q) (ξ : Nat → Nat) :
    Entails (Φ.map (Pred.rename ξ)) (p.rename ξ) (q.rename ξ) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ ih1 ih2 => exact .trans ih1 ih2
  | hypothesis h => exact .hypothesis (List.mem_map.mpr ⟨_, h, rfl⟩)
  | truth => exact .truth
  | and_intro _ _ ih1 ih2 => exact .and_intro ih1 ih2
  | and_left => exact .and_left
  | and_right => exact .and_right
  | le_refl => exact .le_refl _

-- Φ も自己変数を0に持つ同じ論理文脈で読む。
-- 外側のΓの事実は自己変数を導入する際にsuccで移す。
structure RefTy where
  carrier : Ty
  predicate : Pred

def RefTy.WF (nr nt nv : Nat) (t : RefTy) :=
  Ty.WF nr nt t.carrier ∧ t.predicate.WF (nv+1)

def shiftIndex (k c i : Nat) : Nat := if i < c then i else i+k
def upNat (ξ : Nat → Nat) : Nat → Nat
  | 0 => 0
  | i+1 => ξ i + 1

theorem up_shiftIndex (k c : Nat) : upNat (shiftIndex k c) = shiftIndex k (c+1) := by
  funext i
  cases i with
  | zero => simp [upNat, shiftIndex]
  | succ i => simp only [upNat, shiftIndex]; split <;> split <;> omega

noncomputable def RefTy.shift (kt ct kv cv : Nat) (t : RefTy) : RefTy :=
  ⟨t.carrier.shift kt ct, t.predicate.rename (shiftIndex kv (cv+1))⟩

inductive Le (Φ : List Pred) : RefTy → RefTy → Prop where
  | refl (a) : Le Φ a a
  | trans {a b c} : Le Φ a b → Le Φ b c → Le Φ a c
  | refine {a b} : Ty.Le a.carrier b.carrier →
      Entails Φ a.predicate b.predicate → Le Φ a b

-- Basic.lean:107のshiftと同じ本番の型移動に、値cutoffを増やす述語の移動を加える。
theorem Le.shift {Φ : List Pred} {a b : RefTy} (h : Le Φ a b) (kt ct kv cv : Nat) :
    Le (Φ.map (Pred.rename (shiftIndex kv (cv+1))))
      (a.shift kt ct kv cv) (b.shift kt ct kv cv) := by
  induction h with
  | refl a => exact .refl _
  | trans _ _ ih1 ih2 => exact .trans ih1 ih2
  | refine hc hp => exact .refine (Ty.Le.shift kt ct hc) (hp.rename _)

theorem RefTy.shift_wf {nr nt nv : Nat} {a : RefTy} (h : a.WF nr nt nv) (kt kv : Nat) :
    (a.shift kt 0 kv 0).WF nr (nt+kt) (nv+kv) := by
  refine ⟨Ty.shift_wf kt a.carrier h.1, ?_⟩
  apply a.predicate.wf_rename h.2
  intro i hi
  simp only [shiftIndex]
  split <;> omega

def Term.bind (σ : Nat → Term) : Term → Term
  | .var i => σ i
  | .integer n => .integer n
  | .add a b => .add (a.bind σ) (b.bind σ)

def Pred.bind (σ : Nat → Term) : Pred → Pred
  | .truth => .truth
  | .le a b => .le (a.bind σ) (b.bind σ)
  | .and p q => .and (p.bind σ) (q.bind σ)

theorem Entails.bind {Φ : List Pred} {p q : Pred} (h : Entails Φ p q) (σ : Nat → Term) :
    Entails (Φ.map (Pred.bind σ)) (p.bind σ) (q.bind σ) := by
  induction h with
  | refl => exact .refl _
  | trans _ _ ih1 ih2 => exact .trans ih1 ih2
  | hypothesis h => exact .hypothesis (List.mem_map.mpr ⟨_, h, rfl⟩)
  | truth => exact .truth
  | and_intro _ _ ih1 ih2 => exact .and_intro ih1 ih2
  | and_left => exact .and_left
  | and_right => exact .and_right
  | le_refl => exact .le_refl _

def upSub (σ : Nat → Term) : Nat → Term
  | 0 => .var 0
  | i+1 => (σ i).rename Nat.succ

noncomputable def RefTy.substAt (c : Nat) (ts : List Ty) (es : List Eff)
    (σ : Nat → Term) (a : RefTy) : RefTy :=
  ⟨a.carrier.substAt c ts es, a.predicate.bind (upSub σ)⟩

-- Basic.lean:99の本番substAtを使い、Φと篩の値置換を素通ししない。
theorem Le.substAt {Φ : List Pred} {a b : RefTy} (h : Le Φ a b)
    (c : Nat) (ts : List Ty) (es : List Eff) (σ : Nat → Term) :
    Le (Φ.map (Pred.bind (upSub σ))) (a.substAt c ts es σ) (b.substAt c ts es σ) := by
  induction h with
  | refl a => exact .refl _
  | trans _ _ ih1 ih2 => exact .trans ih1 ih2
  | refine hc hp => exact .refine (Ty.Le.substAt c ts es hc) (hp.bind _)

theorem Term.wf_bind {n m : Nat} {t : Term} (h : t.WF n)
    (σ : Nat → Term) (hσ : ∀ i, i < n → (σ i).WF m) : (t.bind σ).WF m := by
  induction t with
  | var i => exact hσ i h
  | integer _ => trivial
  | add a b ia ib => exact ⟨ia h.1, ib h.2⟩

theorem Pred.wf_bind {n m : Nat} {p : Pred} (h : p.WF n)
    (σ : Nat → Term) (hσ : ∀ i, i < n → (σ i).WF m) : (p.bind σ).WF m := by
  induction p with
  | truth => trivial
  | le a b => exact ⟨a.wf_bind h.1 σ hσ, b.wf_bind h.2 σ hσ⟩
  | and p q ip iq => exact ⟨ip h.1, iq h.2⟩

theorem upSub_wf {n m : Nat} {σ : Nat → Term}
    (h : ∀ i, i < n → (σ i).WF m) : ∀ i, i < n+1 → (upSub σ i).WF (m+1) := by
  intro i hi
  cases i with
  | zero => change 0 < m+1; omega
  | succ i => exact (σ i).wf_rename (h i (by omega)) Nat.succ (by intro j hj; omega)

theorem Term.rename_bind (ξ : Nat → Nat) (σ : Nat → Term) (t : Term) :
    (t.rename ξ).bind σ = t.bind (fun i => σ (ξ i)) := by
  induction t <;> simp_all [Term.rename, Term.bind]

theorem Term.bind_rename (σ : Nat → Term) (ξ : Nat → Nat) (t : Term) :
    (t.bind σ).rename ξ = t.bind (fun i => (σ i).rename ξ) := by
  induction t <;> simp_all [Term.rename, Term.bind]

theorem Term.bind_comp (σ τ : Nat → Term) (t : Term) :
    (t.bind σ).bind τ = t.bind (fun i => (σ i).bind τ) := by
  induction t <;> simp_all [Term.bind]

-- 自己束縛の下の置換合成。本番のNat/cutoff版で新たに必要な交換の代表。
theorem upSub_comp (σ τ : Nat → Term) :
    (fun i => (upSub σ i).bind (upSub τ)) = upSub (fun i => (σ i).bind τ) := by
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [upSub, Term.rename_bind, Term.bind_rename]

theorem RefTy.value_bind_wf {nr nt nv nw : Nat} {a : RefTy} (h : a.WF nr nt nv)
    (σ : Nat → Term) (hσ : ∀ i, i < nv → (σ i).WF nw) :
    RefTy.WF nr nt nw ⟨a.carrier, a.predicate.bind (upSub σ)⟩ :=
  ⟨h.1, a.predicate.wf_bind h.2 _ (upSub_wf hσ)⟩

-- Natでの自己束縛を越える値移動。落としても型としては書けるためWFが必要。
example : upNat (shiftIndex 2 1) 2 = 4 := by decide
example : shiftIndex 2 1 0 = 0 := by decide
example : ¬ (Pred.le (.var 2) (.integer 0)).WF 2 := by simp [Pred.WF, Term.WF]
example : RefTy.WF 1 2 3 ⟨.list (.tvar 1), .le (.var 0) (.var 3)⟩ := by
  simp [RefTy.WF, Ty.WF, Pred.WF, Term.WF]

#print axioms Le.shift
#print axioms RefTy.shift_wf
#print axioms up_shiftIndex
#print axioms Le.substAt
#print axioms upSub_comp
end P3bNat
