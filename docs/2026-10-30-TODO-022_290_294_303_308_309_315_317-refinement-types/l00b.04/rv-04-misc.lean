import Benitoite.Release.Refinement.ExternalCheck
import Benitoite.Release.Refinement.ClosedKeys
import Benitoite.Release.Refinement.LogicSound
namespace Benitoite.Release.Refinement.RV04b
-- .base の定数は型が一致すれば検査を通る
theorem const_ok (P : Program) (c : Const) (k) (h : c.type = .base k) : externalCheck P (.const c) (.base k) = true := by
  simp [externalCheck, h]
-- And/Or の ClosedObservable
example : (Pred.or (.and .truth .falsity) (.not (.lt (.integer 1) (.integer 2)))).ClosedObservable :=
  .or (.and (.atom trivial rfl) (.atom trivial rfl)) (.not (.atom trivial (by decide)))
-- 入れ子の鍵の Decimal
example : Key.equal (.listValue [some (.decimal 10 1)]) (.listValue [some (.decimal 1 0)]) = some true := by decide +kernel
example : Key.equal (.dataValue "A" [some (.decimal 10 1)]) (.dataValue "B" [some (.decimal 1 0)]) = some false := by decide +kernel
example : Key.equal (.string "ab") (.string "ac") = some false := by decide +kernel
example : (Pred.eq (.measure .setSize (.setValue [some (.integer 1), some (.integer 2), some (.integer 1)])) (.integer 2)).evalClosed = some true := by decide +kernel
example : (Pred.eq (.measure .mapSize (.mapValue [some (.integer 1)] [])) (.integer 1)).evalClosed = none := by decide +kernel
example : (Pred.eq (.measure .bytesLength (.bytesValue [256])) (.integer 1)).evalClosed = none := by decide
-- 鍵の Float を含む data は拒否
example : (Pred.eq (.measure .setSize (.setValue [some (.dataValue "A" [some (.float64 0)])])) (.integer 1)).evalClosed = none := by decide +kernel
-- sort 不適格: compare の Allowed
example : (Pred.compare .integer .eq (.integer 1) (.integer 1)).evalClosed = none := by decide
example : (Pred.compare .string .lt (.string "a") (.string "b")).evalClosed = none := by decide
-- 空虚でない: Entails は falsity を導かない
theorem no_false : ¬ Entails [] .falsity := fun h => by
  have := h.sound (fun _ => none) (by simp); simp [Pred.interpret, Pred.atomValue] at this
-- 閉じた偽は導けない
theorem closed_false (p : Pred) (hw : p.WF 0) (hs : p.Sorted [] none) (h : p.evalClosed = some false) : ¬ Entails [] p := fun he => by
  have h1 := he.sound (fun _ => none) (by simp)
  have h2 := Pred.evalClosed_sound hw hs h
  rw [h2] at h1; cases h1
-- 無矛盾性: p と not p の両方が closed で成功しない
theorem closed_excl (p : Pred) (h1 : p.evalClosed = some true) (h2 : p.not.evalClosed = some true) : False := by
  simp only [Pred.evalClosed] at h1 h2
  split at h1
  · rename_i hc
    simp only [Pred.WF] at hc
    have : p.not.WF 0 ∧ p.not.Sorted [] none := hc
    simp only [this, and_self, if_true] at h2
    simp [Pred.evalWith, h1] at h2
  · cases h1
-- no-exit の保存
theorem no_exit {P a out} (h : ∀ n : Int, out ≠ .exit n) (n : Int) : externalCheckedOutcome P a out ≠ .exit n := by
  cases out with
  | val v => simp only [externalCheckedOutcome]; split <;> simp
  | err e => simp [externalCheckedOutcome]
  | exit m => exact absurd rfl (h m)
-- 再帰する data: 深い位置の違反を拒む
def pos : Ty := .refined (.base .integer8) (.lt (.integer 0) (.var 0))
def nilD : ConDecl := ⟨"L",0,[]⟩
def consD : ConDecl := ⟨"L",0,[pos, .data "L" []]⟩
def prog : Program := ⟨fun _ => none, fun c => if c = "Nil" then some nilD else if c = "Cons" then some consD else none,
  fun _ => none, fun _ => none, fun _ => none, fun _ => none, []⟩
noncomputable def lst (n : Int) : Val := .con "Cons" [] [.const (.integer8 1), .con "Cons" [] [.const (.integer8 n), .con "Nil" [] []]]
theorem pos_subst : pos.subst [] [] = pos := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, pos, typeEnvAt]
theorem l_subst : (Ty.data "L" []).subst [] [] = .data "L" [] := by
  simp [Ty.subst, Ty.substAt, substTypeAt, Ty.bind, Ty.rawBind, Ty.norm, typeEnvAt]
macro "chk" : tactic => `(tactic| (simp only [externalCheck, pos, Val.toTerm?, Const.type, Ty.sort?, Pred.open, predBind, termBind, termBind?]; decide))
theorem p1 : externalCheck P (.const (.integer8 1)) pos = true := by chk
theorem p2 : externalCheck P (.const (.integer8 2)) pos = true := by chk
theorem p0 : externalCheck P (.const (.integer8 0)) pos = false := by chk
theorem deep_ok : externalCheck prog (lst 2) (.data "L" []) = true := by
  simp [lst, externalCheck, externalCheckFields, prog, consD, nilD, pos_subst, l_subst, p1, p2]
theorem deep_bad : externalCheck prog (lst 0) (.data "L" []) = false := by
  simp [lst, externalCheck, externalCheckFields, prog, consD, nilD, pos_subst, l_subst, p1, p0]
#print axioms Entails.sound
#print axioms ExternalCarrier.checked_typed
#print axioms externalCheckedOutcome_typed
#print axioms Pred.evalClosed_complete
#check @Ty.carrier
end Benitoite.Release.Refinement.RV04b
