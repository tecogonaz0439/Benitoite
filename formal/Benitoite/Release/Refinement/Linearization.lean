import Benitoite.Release.Refinement.CertificateSyntax
import Benitoite.Release.Refinement.LinearSound

/-! # 有限の鍵を係数位置に用いる線形化

設計書 01-12「閉じた述語の評価と捕捉」に対応する。
構文を先に分解し、残る項は登録済みの鍵の整数射影として読む。
-/
namespace Benitoite.Release.Refinement

private def checkAffine (n : Nat) (a : List Int × Int) : Option (List Int × Int) :=
  if a.1.length = n then some a else none

private theorem bind_checkAffine {n : Nat} {x : Option (List Int × Int)} {a : List Int × Int} :
    x.bind (checkAffine n) = some a ↔ x = some a ∧ a.1.length = n := by
  cases x with
  | none => simp
  | some b =>
    simp only [Option.bind_some, checkAffine]
    split <;> simp_all [eq_comm]

/-- 鍵番号の単位係数。範囲外の番号を成功とみなさないのはkeyIndexの役割である。 -/
def keyCoefficients : Nat → Nat → List Int
  | 0, _ => []
  | n+1, 0 => 1 :: List.replicate n 0
  | n+1, i+1 => 0 :: keyCoefficients n i

private theorem linearDot_zero (n : Nat) (ρ : Nat → Int) :
    linearDot (List.replicate n 0) ρ = 0 := by
  induction n generalizing ρ with
  | zero => rfl
  | succ n ih => simp [linearDot, List.replicate_succ, ih]

theorem linearDot_keyCoefficients {n i : Nat} (h : i < n) (ρ : Nat → Int) :
    linearDot (keyCoefficients n i) ρ = ρ i := by
  induction n generalizing i ρ with
  | zero => omega
  | succ n ih =>
    cases i with
    | zero => simp [keyCoefficients, linearDot, linearDot_zero]
    | succ i => simpa [keyCoefficients, linearDot] using ih (by omega) (fun j => ρ (j+1))

def linearize (keys : KeyTable) (t : Term) : Option (List Int × Int) :=
  (match t with
  | .integer n => some (List.replicate keys.length 0, n)
  | .add a b => do
      let (as, x) ← linearize keys a
      let (bs, y) ← linearize keys b
      if as.length = bs.length then some (List.zipWith (·+·) as bs, x+y) else none
  | .neg a => do
      let (as, x) ← linearize keys a
      some (as.map ((-1) * ·), -x)
  | .scale k a => do
      let (as, x) ← linearize keys a
      some (as.map (k * ·), k*x)
  | a => do
      let i ← keyIndex keys a
      some (keyCoefficients keys.length i, 0)).bind (checkAffine keys.length)
termination_by structural t

theorem linearize_length {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
    (h : linearize keys t = some (cs,b)) : keys.length = cs.length := by
  unfold linearize at h
  rw [bind_checkAffine] at h
  exact h.2.symm

private theorem keyEnv_lookup {keys : KeyTable} {t : Term} {i : Nat}
    (h : keys[i]? = some t) (ν : ObservationEnv) (η : ObservationEnvModel) :
    keyEnv η (keys.map (termBind ν)) i = integerAs η (termBind ν t) := by
  simp [keyEnv, List.getElem?_map, h]

theorem linearDot_add {as bs : List Int} (h : as.length = bs.length) (ρ : Nat → Int) :
    linearDot (List.zipWith (·+·) as bs) ρ = linearDot as ρ + linearDot bs ρ := by
  induction as generalizing bs ρ with
  | nil => cases bs <;> simp_all [linearDot]
  | cons a as ih =>
    cases bs with
    | nil => simp at h
    | cons b bs =>
      simp only [List.length_cons, Nat.add_right_cancel_iff] at h
      simp only [List.zipWith_cons_cons, linearDot, ih h, Int.add_mul]
      omega

theorem linearize_sound_at {keys : KeyTable} {t : Term} {cs : List Int} {b : Int}
    (h : linearize keys t = some (cs,b)) (ν : ObservationEnv) (η : ObservationEnvModel) :
    integerAs η (termBind ν t) = linearDot cs (keyEnv η (keys.map (termBind ν))) + b := by
  cases t with
  | integer n =>
    unfold linearize at h
    rw [bind_checkAffine] at h
    have hr := h.1
    cases hr
    simp [termBind_integer, integerAs_eq_integerD, Term.interpret, Observation.integerD,
      linearDot_zero]
  | add a c =>
    unfold linearize at h
    rw [bind_checkAffine] at h
    have hr := h.1
    simp only [bind, Option.bind_eq_some_iff] at hr
    obtain ⟨⟨as,x⟩, ha, ⟨⟨bs,y⟩, hb, hr⟩⟩ := hr
    split at hr
    · rename_i hl
      cases hr
      rw [integerAs_bind_add, linearize_sound_at ha ν η, linearize_sound_at hb ν η,
        linearDot_add hl]
      dsimp only
      omega
    · cases hr
  | neg a =>
    unfold linearize at h
    rw [bind_checkAffine] at h
    have hr := h.1
    simp only [bind, Option.bind_eq_some_iff] at hr
    obtain ⟨⟨as,x⟩, ha, hr⟩ := hr
    cases hr
    rw [integerAs_bind_neg, linearize_sound_at ha ν η, linearDot_scale]
    dsimp only
    omega
  | scale k a =>
    unfold linearize at h
    rw [bind_checkAffine] at h
    have hr := h.1
    simp only [bind, Option.bind_eq_some_iff] at hr
    obtain ⟨⟨as,x⟩, ha, hr⟩ := hr
    cases hr
    rw [integerAs_bind_scale, linearize_sound_at ha ν η, linearDot_scale, Int.mul_add]
  | _ =>
    unfold linearize at h
    rw [bind_checkAffine] at h
    have hr := h.1
    simp only [bind, Option.bind_eq_some_iff] at hr
    obtain ⟨i, hi, hr⟩ := hr
    cases hr
    have hk := keyIndex_sound hi
    have hn : i < keys.length := List.getElem?_eq_some_iff.mp hk |>.1
    rw [linearDot_keyCoefficients hn, keyEnv_lookup hk]
    omega
termination_by t

end Benitoite.Release.Refinement
