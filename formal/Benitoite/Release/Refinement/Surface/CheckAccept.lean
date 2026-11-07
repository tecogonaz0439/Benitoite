import Benitoite.Release.Refinement.Surface.CheckProgramSound
import Benitoite.Release.Refinement.Surface.CheckAcceptBase

/-! 型付けの検査と、全本体の必須の判定の受理を行う入口。 -/
noncomputable section

namespace Benitoite.Release.Refinement.Surface.CheckAccept
open CheckTables CheckDeclarations ScopeAccept

inductive EntryError where
  | typing (error : Check.Error)
  | cover (key : Benitoite.Interval.OperationKey) (reason : CoverFailure)
  deriving Repr

/-- 型付けに成功した同じプログラムの全本体で、必須の判定の範囲を受理する。 -/
def checkProgramAccepted (q : Check.Input) (A : AcceptInput) (p : Program) : Except EntryError Unit :=
  match checkProgram q p with
  | .error error => .error (.typing error)
  | .ok () => match acceptProgram A q p with
    | .error (key, reason) => .error (.cover key reason)
    | .ok () => .ok ()

theorem checkProgramAccepted_ok {q A p} (h : checkProgramAccepted q A p = .ok ()) :
    checkProgram q p = .ok () ∧ acceptProgram A q p = .ok () := by
  unfold checkProgramAccepted at h
  split at h
  · cases h
  · next hc =>
    split at h
    · cases h
    · next ha => exact ⟨hc, ha⟩

/-- 受理の入口も、型付けの unknown を本体の実際の打ち切りまで追跡できる。 -/
theorem checkProgramAccepted_unknown {q A p error}
    (h : checkProgramAccepted q A p = .error (.typing error)) (hu : error.kind = .unknown) :
    CheckTables.ProgramStopped (CheckPreparation.prepare q p).input
      (CheckPreparation.prepare q p).program := by
  unfold checkProgramAccepted at h
  cases hc : checkProgram q p with
  | error err =>
    simp only [hc, Except.error.injEq, EntryError.typing.injEq] at h
    exact CheckTables.checkProgram_unknown (h ▸ hc) hu
  | ok value =>
    cases value
    simp only [hc] at h
    split at h
    · cases h
    · cases h

/-- 全プログラムでの型付けと必須の判定の受理を、同じ入口の成功から得る。 -/
theorem checkProgramAccepted_sound {q : Check.Input} {A : AcceptInput} {p : Program}
    (hq : (CheckPreparation.prepare q p).input.Sound) (hn : CheckTables.NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d → DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (hext : Extends (CheckPreparation.prepare q p).input.D (CheckPreparation.prepare q p).program.declarations) (ha : NamesComplete q p)
    (h : checkProgramAccepted q A p = .ok ()) : CheckedUnder (CheckPreparation.prepare q p).program (CheckPreparation.prepare q p).input ∧ Accepted A q p := by
  obtain ⟨hc, haccept⟩ := checkProgramAccepted_ok h
  exact ⟨checkProgram_sound hq hn hd hi him hext hc, acceptProgram_sound ha haccept⟩

/-- 宣言の補完が不要なとき、自身の表の下での型付けと受理を同時に得る。 -/
theorem checkProgramAccepted_empty {q : Check.Input} {A : AcceptInput} {p : Program}
    (hq : (CheckPreparation.prepare q p).input.Sound) (hn : CheckTables.NamesComplete (CheckPreparation.prepare q p).input (CheckPreparation.prepare q p).program)
    (hd : ∀ n d, (CheckPreparation.prepare q p).program.defs n = some d → DefSupport (CheckPreparation.prepare q p).input d)
    (hi : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplSupport (CheckPreparation.prepare q p).input id)
    (him : ∀ n id, (CheckPreparation.prepare q p).program.impls n = some id → ImplNamesComplete (CheckPreparation.prepare q p).input id)
    (hD : (CheckPreparation.prepare q p).input.D = (CheckPreparation.prepare q p).program.declarations) (ha : NamesComplete q p)
    (h : checkProgramAccepted q A p = .ok ()) : (CheckPreparation.prepare q p).program.WellTyped (CheckPreparation.prepare q p).input.B (CheckPreparation.prepare q p).input.opPrim ∧ Accepted A q p := by
  obtain ⟨hc, haccept⟩ := checkProgramAccepted_ok h
  exact ⟨checkProgram_empty hq hn hd hi him hD hc, acceptProgram_sound ha haccept⟩

end Benitoite.Release.Refinement.Surface.CheckAccept
