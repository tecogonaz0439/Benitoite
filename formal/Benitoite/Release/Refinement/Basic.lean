import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.Le

/-!
# 値の移動と論理の置換

self を残す up と、外側の値の Nat/cutoff を区別する。
構文の含意の導出を移し、意味上の包含を仮定しない。
-/
namespace Benitoite.Release.Refinement

@[simp] theorem termBind_id (t : Term) : termBind Term.var t = t := by
  induction t <;> simp_all [termBind]

@[simp] theorem predBind_id (p : Pred) : predBind Term.var p = p := by
  induction p <;> simp_all [predBind]

theorem termBind_comp (σ τ : Nat → Term) (t : Term) :
    termBind τ (termBind σ t) = termBind (fun i => termBind τ (σ i)) t := by
  induction t <;> simp_all [termBind]

theorem predBind_comp (σ τ : Nat → Term) (p : Pred) :
    predBind τ (predBind σ p) = predBind (fun i => termBind τ (σ i)) p := by
  induction p <;> simp_all [predBind, termBind_comp]

@[simp] theorem upValues_id : upValues Term.var = Term.var := by
  funext i
  cases i <;> rfl

theorem upValues_comp (σ τ : Nat → Term) :
    (fun i => termBind (upValues τ) (upValues σ i)) =
      upValues (fun i => termBind τ (σ i)) := by
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [upValues, termBind_comp]
    congr 1

/-- 外側の置換と self の導入が交換する。 -/
theorem predBind_lift (σ : Nat → Term) (p : Pred) :
    predBind (upValues σ) p.lift = (predBind σ p).lift := by
  simp only [Pred.lift, predBind_comp]
  congr 1

/-- self を開くとき、置換像を二度置換しない。 -/
theorem predBind_open (σ : Nat → Term) (p : Pred) (t : Term) :
    predBind σ (p.open t) = (predBind (upValues σ) p).open (termBind σ t) := by
  simp only [Pred.open, predBind_comp]
  congr 1
  funext i
  cases i with
  | zero => rfl
  | succ i =>
    simp only [upValues, termBind_comp]
    exact (termBind_id (σ i)).symm

/-- 有限の含意の全規則に対する、論理項の同時置換。 -/
theorem Entails.bind {Ξ p} (h : Entails Ξ p) (σ : Nat → Term) :
    Entails (Ξ.map (predBind σ)) (predBind σ p) := by
  induction h with
  | hyp h => exact .hyp (List.mem_map.mpr ⟨_, h, rfl⟩)
  | truth => exact .truth
  | false_elim _ ih => exact .false_elim ih
  | and_intro _ _ ih₁ ih₂ => exact .and_intro ih₁ ih₂
  | and_left _ ih => exact .and_left ih
  | and_right _ ih => exact .and_right ih
  | or_left _ ih => exact .or_left ih
  | or_right _ ih => exact .or_right ih
  | or_elim _ _ _ ih₀ ih₁ ih₂ => exact .or_elim ih₀ ih₁ ih₂
  | not_intro _ ih => exact .not_intro ih
  | not_elim _ _ ih₁ ih₂ => exact .not_elim ih₁ ih₂
  | not_not_elim _ ih => exact .not_not_elim ih
  | eq_refl => exact .eq_refl
  | le_refl => exact .le_refl
  | integer_eq h => exact .integer_eq h
  | integer_le h => exact .integer_le h
  | integer_lt h => exact .integer_lt h

def shiftIndex (k c i : Nat) : Nat := if i < c then i else i+k

def Pred.shiftV (k c : Nat) (p : Pred) : Pred :=
  predBind (fun i => .var (shiftIndex k c i)) p

theorem upValues_shiftIndex (k c : Nat) :
    upValues (fun i => .var (shiftIndex k c i)) =
      (fun i => .var (shiftIndex k (c+1) i)) := by
  funext i
  cases i with
  | zero => simp [upValues, shiftIndex]
  | succ i =>
    simp only [upValues, termBind, shiftIndex]
    split <;> split <;> simp_all <;> omega

theorem Entails.shiftV {Ξ p} (h : Entails Ξ p) (k c : Nat) :
    Entails (Ξ.map (Pred.shiftV k c)) (p.shiftV k c) := h.bind _

/-- WF は置換像の番号の上限から保存される。 -/
theorem termWF_bind {nv mv : Nat} {t : Term} (h : termWF nv t)
    (σ : Nat → Term) (hs : ∀ i, i < nv → termWF mv (σ i)) :
    termWF mv (termBind σ t) := by
  induction t with
  | var i => exact hs i h
  | integer _ => trivial
  | add a b ia ib => exact ⟨ia h.1, ib h.2⟩

theorem Pred.wf_bind {nv mv : Nat} {p : Pred} (h : p.WF nv)
    (σ : Nat → Term) (hs : ∀ i, i < nv → termWF mv (σ i)) :
    (predBind σ p).WF mv := by
  induction p with
  | truth | falsity => trivial
  | eq a b | le a b | lt a b => exact ⟨termWF_bind h.1 σ hs, termWF_bind h.2 σ hs⟩
  | and p q ip iq | or p q ip iq => exact ⟨ip h.1, iq h.2⟩
  | not p ip => exact ip h

theorem Pred.wf_shiftV {nv : Nat} {p : Pred} (h : p.WF nv) (k c : Nat) :
    (p.shiftV k c).WF (nv+k) := by
  apply Pred.wf_bind h
  intro i hi
  simp only [termWF, shiftIndex]
  split <;> omega

/-- 整数だけを観測する項の置換。None を整数の変数として扱わない。 -/
theorem termSorted_bind {Γ Δ : Ctx} {t : Term} (h : termSorted Γ t)
    (σ : Nat → Term)
    (hs : ∀ i a, Γ[i]? = some (some a) → a.IntegerCarrier → termSorted Δ (σ i)) :
    termSorted Δ (termBind σ t) := by
  induction t with
  | var i => obtain ⟨a, ha, hi⟩ := h; exact hs i a ha hi
  | integer _ => trivial
  | add a b ia ib => exact ⟨ia h.1, ib h.2⟩

theorem instAtoms_nil (a : Atom → Bool) : Benitoite.Release.Eff.instAtoms [] a = a := by
  funext x
  rcases x with ⟨l, r | i⟩ | i <;> simp [Benitoite.Release.Eff.instAtoms]

theorem substAtoms_nil (a : Atom → Bool) : substAtoms [] a = a := by
  funext x
  cases x <;> simp [substAtoms]

mutual
  /-- Context の移動と、項の型注釈に使う改名の実装は一致する。 -/
  theorem Ty.shiftV_eq_renameTy (a : Ty) (k c : Nat) :
      a.shiftV k c = renameTy (shiftIndex k c) a := by
    cases a <;> simp only [Ty.shiftV, renameTy, Ty.rawBind, renEnv,
      Scope.Signature.Ix.inst_nil, rawApply, Ty.shiftVTys_eq_rename, Eff.shiftV_eq_renameEff,
      Ty.shiftV_eq_renameTy, renameTy, renameEff]
    case refined a p =>
      congr 1
      exact congrArg (fun σ => predBind σ p) (upValues_shiftIndex k c).symm
  theorem Ty.shiftVTys_eq_rename (as : List Ty) (k c : Nat) :
      shiftVTys k c as = rawBindTys (renEnv (shiftIndex k c)) as := by
    cases as with
    | nil => rfl
    | cons a as =>
      simp only [shiftVTys, rawBindTys, Ty.shiftV_eq_renameTy, renameTy, Ty.shiftVTys_eq_rename]
  theorem Eff.shiftV_eq_renameEff (e : Eff) (k c : Nat) :
      Eff.shiftV k c e = renameEff (shiftIndex k c) e := by
    cases e with
    | mk a fs =>
      simp only [Eff.shiftV, renameEff, Eff.rawBind, renEnv, instAtoms_nil,
        substAtoms_nil, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil, Ty.shiftVTys_eq_rename]
end

@[simp] theorem renEnv_types (ξ : Nat → Nat) : (renEnv ξ).types = Ty.tvar := rfl
@[simp] theorem renEnv_rows (ξ : Nat → Nat) : (renEnv ξ).rows = [] := rfl
@[simp] theorem renEnv_ranges (ξ : Nat → Nat) : (renEnv ξ).ranges = [] := rfl
@[simp] theorem renEnv_values (ξ : Nat → Nat) : (renEnv ξ).values = fun i => .var (ξ i) := rfl

end Benitoite.Release.Refinement
