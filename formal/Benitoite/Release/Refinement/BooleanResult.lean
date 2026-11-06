import Benitoite.Release.Refinement.BuiltinResponse
import Benitoite.Release.Refinement.StringMembership

namespace Benitoite.Release.Refinement.BooleanResult

def accepts (b : Bool) : Ty → Bool
  | .base .boolean => true
  | .refined a p => accepts b a && (p.open (.boolean b)).closedTrue
  | _ => false

theorem sort {a : Ty} {b : Bool} (h : accepts b a = true) : a.HasSort .boolean := by
  cases a with
  | refined a p =>
    have hh : accepts b a = true ∧ (p.open (.boolean b)).closedTrue = true := by
      simpa only [accepts, Bool.and_eq_true] using h
    exact sort (a := a) hh.1
  | base k => cases k <;> simp only [accepts, Bool.false_eq_true] at h <;> rfl
  | _ => simp only [accepts, Bool.false_eq_true] at h
termination_by structural a

theorem typed {P : Program} {B : Builtins} {Ψ : StoreTy} {a : Ty} {b : Bool}
    (ha : Ty.Annotation P [] [] a) (h : accepts b a = true) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean b)) a := by
  cases a with
  | base k => cases k <;> simp only [accepts, Bool.false_eq_true] at h <;> exact .V_Const trivial
  | refined a p =>
    have hh : accepts b a = true ∧ (p.open (.boolean b)).closedTrue = true := by
      simpa only [accepts, Bool.and_eq_true] using h
    obtain ⟨hb,hp⟩ := hh
    have he : (p.open (.boolean b)).evalClosed = some true := by simpa [Pred.closedTrue] using hp
    have hw : (p.open (.boolean b)).WF 0 ∧ (p.open (.boolean b)).Sorted [] none := by
      unfold Pred.evalClosed at he
      split at he
      · assumption
      · cases he
    exact .V_Refine (typed ⟨ha.wf.1, ha.sorted.1, ha.declared.1⟩ hb)
      (sort hb) rfl ha.sorted.2 ha.wf.2.1 (.closed hw.1 hw.2 he) ha.declared.1 ha.declared.2
  | _ => simp only [accepts, Bool.false_eq_true] at h
termination_by structural a

/-- 真の受理と偽の拒否は、結果型の同じ篩を読む。 -/
example : accepts true (.refined (.base .boolean)
    (.compare .boolean .eq (.var 0) (.boolean true))) = true ∧
    accepts false (.refined (.base .boolean)
      (.compare .boolean .eq (.var 0) (.boolean true))) = false := by decide

example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean true)) (.base .boolean) :=
  typed ⟨trivial,trivial,trivial⟩ rfl

/-- 閉じた評価を満たす Boolean に、同じ篩付きの期待型を与える具体の適用。 -/
example (P : Program) (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] (.const (.boolean true))
      (.refined (.base .boolean) (.compare .boolean .eq (.var 0) (.boolean true))) := by
  apply typed
  · constructor
    · simp [Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
    · simp [Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,Term.Shape,
        Ctx.Readable,Ty.HasSort,Ty.sort?,Comparison.Allowed,Ordinary,Ty.core]
    · simp [Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ctx.extend,Ty.shiftV,Ordinary]
  · decide

end Benitoite.Release.Refinement.BooleanResult
