import Benitoite.Release.Refinement.Linearization

/-! # 整数比較と符号付き原子の否定標準形

設計書 01-12「閉じた述語の評価と捕捉」に対応する。
入力の述語だけを構造再帰で読み、正規化のtraceは受け取らない。
-/
namespace Benitoite.Release.Refinement

/-- a-b≤bound。線形化が得た定数項を右辺に移す。 -/
def normalizeBound (keys : KeyTable) (a b : Term) (bound : Int) : Option NNF := do
  let (cs,c) ← linearize keys (.add a (.neg b))
  some (.linear ⟨cs,bound-c⟩)

def normalize (keys : KeyTable) (p : Pred) (negative : Bool) : Option NNF :=
  match p with
  | .truth => some (if negative then .falsity else .truth)
  | .falsity => some (if negative then .truth else .falsity)
  | .eq a b => do
      let l ← normalizeBound keys a b (if negative then -1 else 0)
      let r ← normalizeBound keys b a (if negative then -1 else 0)
      some (if negative then .or l r else .and l r)
  | .le a b => if negative then normalizeBound keys b a (-1) else normalizeBound keys a b 0
  | .lt a b => if negative then normalizeBound keys b a 0 else normalizeBound keys a b (-1)
  | .and p q => do
      let l ← normalize keys p negative
      let r ← normalize keys q negative
      some (if negative then .or l r else .and l r)
  | .or p q => do
      let l ← normalize keys p negative
      let r ← normalize keys q negative
      some (if negative then .and l r else .or l r)
  | .not p => normalize keys p (!negative)
  | p => some (.literal p negative)
termination_by structural p

theorem normalizeBound_sound_at {keys : KeyTable} {a b : Term} {bound : Int} {q : NNF}
    (h : normalizeBound keys a b bound = some q) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (q.toPred keys)).interpret η =
      decide (integerAs η (termBind ν a) - integerAs η (termBind ν b) ≤ bound) := by
  simp only [normalizeBound, bind, Option.bind_eq_some_iff] at h
  obtain ⟨⟨cs,c⟩, hl, h⟩ := h
  cases h
  have hv := linearize_sound_at hl ν η
  rw [integerAs_bind_add, integerAs_bind_neg] at hv
  apply Bool.eq_iff_iff.mpr
  rw [NNF.toPred, Linear.toPred_sound_at η ν _ _]
  simp only [Linear.Holds, Linear.eval, decide_eq_true_eq]
  omega

private theorem literal_sound (keys : KeyTable) (p : Pred) (negative : Bool)
    (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν ((NNF.literal p negative).toPred keys)).interpret η =
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) := by
  cases negative <;> rfl

private theorem integer_eq_normalized (x y : Int) (negative : Bool) :
    (if negative then decide (x-y ≤ -1) || decide (y-x ≤ -1)
      else decide (x-y ≤ 0) && decide (y-x ≤ 0)) =
      (if negative then !(decide (x=y)) else decide (x=y)) := by
  cases negative <;> apply Bool.eq_iff_iff.mpr <;> simp <;> omega

private theorem integer_le_normalized (x y : Int) (negative : Bool) :
    (if negative then decide (y-x ≤ -1) else decide (x-y ≤ 0)) =
      (if negative then !(decide (x≤y)) else decide (x≤y)) := by
  cases negative <;> apply Bool.eq_iff_iff.mpr <;> simp <;> omega

private theorem integer_lt_normalized (x y : Int) (negative : Bool) :
    (if negative then decide (y-x ≤ 0) else decide (x-y ≤ -1)) =
      (if negative then !(decide (x<y)) else decide (x<y)) := by
  cases negative <;> apply Bool.eq_iff_iff.mpr <;> simp <;> omega

theorem normalize_sound_at {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
    (h : normalize keys p negative = some q) (ν : ObservationEnv) (η : ObservationEnvModel) :
    (predBind ν (q.toPred keys)).interpret η =
      (if negative then !((predBind ν p).interpret η) else (predBind ν p).interpret η) := by
  cases p with
  | truth | falsity =>
    unfold normalize at h
    cases h
    cases negative <;> rfl
  | eq a b =>
    unfold normalize at h
    simp only [bind, Option.bind_eq_some_iff] at h
    obtain ⟨l, hl, r, hr, h⟩ := h
    cases h
    have hleft := normalizeBound_sound_at hl ν η
    have hright := normalizeBound_sound_at hr ν η
    cases negative <;>
      simp only [Bool.false_eq_true, ↓reduceIte, NNF.toPred,
        predBind, Pred.interpret, Pred.atomValue] at hleft hright ⊢
    all_goals rw [hleft, hright]
    · exact integer_eq_normalized _ _ false
    · exact integer_eq_normalized _ _ true
  | le a b =>
    unfold normalize at h
    cases negative <;>
      simp only [Bool.false_eq_true, ↓reduceIte] at h ⊢
    · rw [normalizeBound_sound_at h ν η]
      exact integer_le_normalized _ _ false
    · rw [normalizeBound_sound_at h ν η]
      exact integer_le_normalized _ _ true
  | lt a b =>
    unfold normalize at h
    cases negative <;>
      simp only [Bool.false_eq_true, ↓reduceIte] at h ⊢
    · rw [normalizeBound_sound_at h ν η]
      exact integer_lt_normalized _ _ false
    · rw [normalizeBound_sound_at h ν η]
      exact integer_lt_normalized _ _ true
  | and a b | or a b =>
    unfold normalize at h
    simp only [bind, Option.bind_eq_some_iff] at h
    obtain ⟨l, hl, r, hr, h⟩ := h
    cases h
    have hleft := normalize_sound_at hl ν η
    have hright := normalize_sound_at hr ν η
    cases negative <;> simp_all [NNF.toPred, predBind, Pred.interpret,
      Bool.not_and, Bool.not_or]
  | not a =>
    unfold normalize at h
    rw [normalize_sound_at h ν η]
    cases negative <;> simp [predBind, Pred.interpret]
  | _ =>
    unfold normalize at h
    cases h
    exact literal_sound _ _ _ ν η
termination_by p

theorem normalize_sound {keys : KeyTable} {p : Pred} {negative : Bool} {q : NNF}
    (h : normalize keys p negative = some q) : ∀ η : ObservationEnvModel,
    (q.toPred keys).interpret η = (if negative then !(p.interpret η) else p.interpret η) := by
  intro η
  simpa only [predBind_id] using normalize_sound_at h (fun i => some (.var i)) η

end Benitoite.Release.Refinement
