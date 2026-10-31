import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.LogicSound
import Benitoite.Release.Refinement.TypedFacts

/-!
# 有限な証明書の葉と枝内の参照

証明書は正規化の履歴や未検査の導出を含まない。閉じた葉は評価を再実行する。
開いた算術と全sortの合同性は、この有限な入口を拡張して扱う。
-/
namespace Benitoite.Release.Refinement
noncomputable section

/-- measureの正常結果は有限な個数又は文字コードであり、数学上の非負整数である。 -/
theorem Observation.measure_nonnegative {m o n} (h : Observation.measure m o = some (.integer n)) :
    0 ≤ n := by
  cases m <;> cases o <;> simp_all [Observation.measure]
  all_goals first | omega | skip
  case bytesLength.bytesValue bs => split at h <;> simp_all <;> omega
  case mapSize.mapValue ks vs => cases he : mapKeys ks vs <;> simp_all <;> omega
  case setSize.setValue xs => cases he : keySetCodes xs [] <;> simp_all <;> omega

inductive EqProof where
  | refl
  | symm (proof : EqProof)
  | trans (middle : Term) (left right : EqProof)
  | add (left right : EqProof)

def EqProof.check (t u : Term) : EqProof → Bool
  | .refl => decide (t = u)
  | .symm c => c.check u t
  | .trans m l r => l.check t m && r.check m u
  | .add l r => match t,u with
    | .add a b, .add c d => l.check a c && r.check b d
    | _,_ => false

theorem EqProof.sound {t u c} (h : EqProof.check t u c = true) : t = u := by
  induction c generalizing t u with
  | refl => simpa [check] using h
  | symm c ih => exact (ih h).symm
  | trans m l r ihl ihr =>
    simp only [check,Bool.and_eq_true] at h
    exact (ihl h.1).trans (ihr h.2)
  | add l r ihl ihr =>
    cases t <;> cases u <;> simp only [check,Bool.false_eq_true] at h
    rename_i a b c d
    simp only [Bool.and_eq_true] at h
    rw [ihl h.1,ihr h.2]

inductive BuiltinLemma where
  | closed
  | lengthNonnegative
  deriving DecidableEq

structure PreparedLeaf where
  predicate : Pred
  lemma : BuiltinLemma

def PreparedLeaf.check (l : PreparedLeaf) : Bool :=
  l.predicate.closedTrue && match l.lemma, l.predicate with
    | .closed, _ => true
    | .lengthNonnegative, .le (.integer 0) (.measure .listLength _) => true
    | _,_ => false

theorem PreparedLeaf.entails {l : PreparedLeaf} (h : l.check = true) : Entails Φ l.predicate := by
  have hc : l.predicate.closedTrue = true := by
    simp only [PreparedLeaf.check, Bool.and_eq_true] at h; exact h.1
  exact (Pred.closedTrue_entails hc).2.2.weaken (by simp)

/-- 機械評価が成功した葉は、全域モデルでも真となる。 -/
theorem PreparedLeaf.machine_exact {l : PreparedLeaf} (h : l.check = true) (η : ObservationEnvModel) :
    l.predicate.interpret η = true := (l.entails (Φ := []) h).sound η (by simp)

/-- 閉じた葉は任意の値置換で変わらない。 -/
theorem PreparedLeaf.stable {l : PreparedLeaf} (h : l.check = true) (ν : ObservationEnv) :
    predBind ν l.predicate = l.predicate := by
  have hc : l.predicate.closedTrue = true := by
    simp only [PreparedLeaf.check, Bool.and_eq_true] at h; exact h.1
  exact Pred.bind_closed (Pred.closedTrue_entails hc).1 ν

inductive Certificate where
  | use (index : Nat)
  | leaf (value : PreparedLeaf)
  | substitute (predicate : Pred) (left right : Term) (eq : EqProof) (proof : Certificate)
  | consume (next : Certificate)
  | cases (left right : Certificate)
  | discard (next : Certificate)

def Certificate.check (Φ : List Pred) (goal : Pred) : Certificate → Bool
  | .use i => Φ[i]? == some goal
  | .leaf l => decide (l.predicate = goal) && l.check
  | .substitute p t u eq c => decide (goal = p.open u) && eq.check t u && c.check Φ (p.open t)
  | .consume c => match Φ with
    | .and p q :: rest => c.check (p::q::rest) goal
    | _ => false
  | .cases l r => match Φ with
    | .or p q :: rest => l.check (p::rest) goal && r.check (q::rest) goal
    | _ => false
  | .discard c => match Φ with
    | _::rest => c.check rest goal
    | [] => false

theorem Certificate.sound {Φ goal c} (h : Certificate.check Φ goal c = true) : Entails Φ goal := by
  induction c generalizing Φ goal with
  | use i =>
    have hh : Φ[i]? = some goal := by simpa [check] using h
    exact .hyp (List.mem_of_getElem? hh)
  | leaf l =>
    simp only [check,Bool.and_eq_true,decide_eq_true_eq] at h
    rw [←h.1]; exact l.entails h.2
  | substitute p t u eq c ih =>
    simp only [check,Bool.and_eq_true,decide_eq_true_eq] at h
    have he := EqProof.sound h.1.2
    rw [h.1.1,←he]; exact ih h.2
  | consume c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check,Bool.false_eq_true] at h
      rename_i p q
      apply (ih h).cut
      intro r hr
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .and_left (q := q) (.hyp List.mem_cons_self)
      rcases List.mem_cons.mp hr with rfl | hr
      · exact .and_right (p := p) (.hyp List.mem_cons_self)
      · exact .hyp (List.mem_cons_of_mem _ hr)
  | cases l r ihl ihr =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest =>
      cases p <;> simp only [check,Bool.false_eq_true] at h
      rename_i p q
      simp only [Bool.and_eq_true] at h
      apply Entails.or_elim (p := p) (q := q) (.hyp (List.mem_cons_self))
      · exact (ihl h.1).weaken (by intro t ht; rcases List.mem_cons.mp ht with rfl | ht; exact List.mem_cons_self; exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ ht))
      · exact (ihr h.2).weaken (by intro t ht; rcases List.mem_cons.mp ht with rfl | ht; exact List.mem_cons_self; exact List.mem_cons_of_mem _ (List.mem_cons_of_mem _ ht))
  | discard c ih =>
    cases Φ with
    | nil => simp [check] at h
    | cons p rest => exact (ih h).weaken (fun _ ht => List.mem_cons_of_mem _ ht)

/-- 宣言側が選んだ文脈とsortを検査し、等号の証拠と分離しない。 -/
def EqProof.checkSorted (Γ : Ctx) (s : «Sort») (t u : Term) (c : EqProof) : Bool :=
  decide (t.HasSort Γ s ∧ u.HasSort Γ s) && c.check t u

theorem EqProof.checkSorted_sound {Γ s t u c} (h : EqProof.checkSorted Γ s t u c = true) :
    t.HasSort Γ s ∧ u.HasSort Γ s ∧ t = u := by
  simp only [checkSorted,Bool.and_eq_true,decide_eq_true_eq] at h
  exact ⟨h.1.1,h.1.2,EqProof.sound h.2⟩

/-- 論理の再生とsortの入口を一つにし、不適格な仮定も拒否する。 -/
def Certificate.checkSorted (Γ : Ctx) (Φ : List Pred) (goal : Pred) (c : Certificate) : Bool :=
  decide (goal.Sorted Γ none ∧ ∀ p ∈ Φ, p.Sorted Γ none) && c.check Φ goal

theorem Certificate.checkSorted_sound {Γ Φ goal c} (h : Certificate.checkSorted Γ Φ goal c = true) :
    goal.Sorted Γ none ∧ (∀ p ∈ Φ, p.Sorted Γ none) ∧ Entails Φ goal := by
  simp only [checkSorted,Bool.and_eq_true,decide_eq_true_eq] at h
  exact ⟨h.1.1,h.1.2,Certificate.sound h.2⟩

end
end Benitoite.Release.Refinement
