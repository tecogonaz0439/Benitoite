import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.LogicSound
namespace Benitoite.Release.Refinement
noncomputable section

/-! 現行の Entails の下で apart が導けないことの証明。閉じていない原子をすべて真とする模型。 -/
def Inv : Pred → Bool
  | .and p q => Inv p && Inv q
  | .or p q => Inv p || Inv q
  | .not p => !Inv p
  | p => if p.WF 0 then p.atomValue (fun _ => none) else true

theorem Inv_eval : ∀ {p : Pred} {b : Bool}, p.WF 0 → p.evalWith (fun _ => none) = some b → Inv p = b := by
  intro p
  induction p with
  | and p q ihp ihq =>
    intro b hw h
    simp only [Pred.evalWith] at h
    have hw' : p.WF 0 ∧ q.WF 0 := hw
    cases hp : p.evalWith (fun _ => none) with
    | none =>
      cases hq : q.evalWith (fun _ => none) with
      | none => simp [hp,hq] at h
      | some c => cases c <;> simp [hp,hq] at h
                  subst h; simp [Inv,ihq hw'.2 hq]
    | some c =>
      cases c
      · simp [hp] at h; subst h; simp [Inv,ihp hw'.1 hp]
      · cases hq : q.evalWith (fun _ => none) with
        | none => simp [hp,hq] at h
        | some e =>
          cases e
          · simp [hp,hq] at h; subst h; simp [Inv,ihq hw'.2 hq]
          · simp [hp,hq] at h; subst h; simp [Inv,ihp hw'.1 hp,ihq hw'.2 hq]
  | or p q ihp ihq =>
    intro b hw h
    simp only [Pred.evalWith] at h
    have hw' : p.WF 0 ∧ q.WF 0 := hw
    cases hp : p.evalWith (fun _ => none) with
    | none =>
      cases hq : q.evalWith (fun _ => none) with
      | none => simp [hp,hq] at h
      | some c => cases c <;> simp [hp,hq] at h
                  subst h; simp [Inv,ihq hw'.2 hq]
    | some c =>
      cases c
      · cases hq : q.evalWith (fun _ => none) with
        | none => simp [hp,hq] at h
        | some e =>
          cases e
          · simp [hp,hq] at h; subst h; simp [Inv,ihp hw'.1 hp,ihq hw'.2 hq]
          · simp [hp,hq] at h; subst h; simp [Inv,ihq hw'.2 hq]
      · simp [hp] at h; subst h; simp [Inv,ihp hw'.1 hp]
  | not p ih =>
    intro b hw h
    simp only [Pred.evalWith] at h
    cases hp : p.evalWith (fun _ => none) with
    | none => simp [hp] at h
    | some c => simp [hp] at h; subst h; simp [Inv,ih hw hp]
  | _ =>
    intro b hw h
    simp only [Pred.evalWith] at h
    split at h
    · simp [Inv,hw]; first | simpa using h | skip
    · cases h

theorem integerAs_lit (n : Int) : integerAs (fun _ => none) (.integer n) = n := by
  have ho : observeAs (fun _ => none) .integer (.integer n) = .integer n := by
    simp [observeAs,Term.interpret,Observation.sort]
  simp only [integerAs,ho]

theorem Inv_sound {Ξ p} (h : Entails Ξ p) : (∀ q ∈ Ξ, Inv q = true) → Inv p = true := by
  induction h with
  | hyp hm => intro hq; exact hq _ hm
  | truth => intro _; simp [Inv,Pred.WF,Pred.VarsIn,Pred.atomValue]
  | false_elim _ ih =>
    intro hq; have := ih hq
    simp [Inv,Pred.WF,Pred.VarsIn,Pred.atomValue] at this
  | and_intro _ _ ih1 ih2 => intro hq; simp [Inv,ih1 hq,ih2 hq]
  | and_left _ ih => intro hq; have := ih hq; simp [Inv] at this; exact this.1
  | and_right _ ih => intro hq; have := ih hq; simp [Inv] at this; exact this.2
  | or_left _ ih => intro hq; simp [Inv,ih hq]
  | or_right _ ih => intro hq; simp [Inv,ih hq]
  | or_elim _ _ _ ih0 ih1 ih2 =>
    intro hq
    have h0 := ih0 hq
    simp [Inv] at h0
    rcases h0 with h0 | h0
    · exact ih1 (fun x hx => by rcases List.mem_cons.mp hx with rfl | hx; exact h0; exact hq x hx)
    · exact ih2 (fun x hx => by rcases List.mem_cons.mp hx with rfl | hx; exact h0; exact hq x hx)
  | not_intro _ ih =>
    rename_i r _
    intro hq
    simp only [Inv,Bool.not_eq_true']
    cases hp : Inv r with
    | false => rfl
    | true =>
      have := ih (fun x hx => by rcases List.mem_cons.mp hx with rfl | hx; exact hp; exact hq x hx)
      simp [Inv,Pred.WF,Pred.VarsIn,Pred.atomValue] at this
  | not_elim _ _ ih1 ih2 =>
    intro hq; have h1 := ih1 hq; have h2 := ih2 hq; simp [Inv,h1] at h2
  | not_not_elim _ ih => intro hq; have := ih hq; simpa [Inv] using this
  | eq_refl => intro _; simp only [Inv]; split <;> simp [Pred.atomValue]
  | le_refl => intro _; simp only [Inv]; split <;> simp [Pred.atomValue]
  | integer_eq he => intro _; subst he; simp only [Inv]; split <;> simp [Pred.atomValue]
  | integer_le he => intro _; simp only [Inv]; split <;> simp [Pred.atomValue,integerAs_lit,he]
  | integer_lt he => intro _; simp only [Inv]; split <;> simp [Pred.atomValue,integerAs_lit,he]
  | closed hw hs he =>
    intro _
    unfold Pred.evalClosed at he
    rw [if_pos ⟨hw,hs⟩] at he
    exact Inv_eval hw he

theorem apart_not_derivable :
    ¬ (∀ Ξ t, Entails Ξ (boolCond t true) → Entails Ξ (boolCond t false) → Entails Ξ .falsity) := by
  intro apart
  have h := apart [boolCond (.var 0) true,boolCond (.var 0) false] (.var 0)
    (.hyp (by simp)) (.hyp (by simp))
  have := Inv_sound h (by
    intro q hq
    simp only [List.mem_cons,List.not_mem_nil,or_false] at hq
    rcases hq with rfl | rfl <;> simp [Inv,boolCond,Pred.WF,Pred.VarsIn,Term.VarsIn])
  simp [Inv,Pred.WF,Pred.VarsIn,Pred.atomValue] at this
end
end Benitoite.Release.Refinement
#print axioms Benitoite.Release.Refinement.apart_not_derivable
