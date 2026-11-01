import Benitoite.Release.Refinement.ProgramWellFormed
/-! 辞書引数からの C_Meth、handler の下の escape、kind と dictParams の空き。 -/
namespace Benitoite.Release.Refinement.RVW4
open Benitoite.Release.Refinement
noncomputable section

def unit : Ty := .base .unit
def pm : MethSig := ⟨[], 0, ["x"], [.tvar 0], .tvar 0, Eff.empty⟩
def parentC : ClassDecl := ⟨.value, [], fun m => if m = "pm" then some pm else none⟩
def P0 : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun c => if c = "Parent" then some parentC else none
  impls := fun _ => none }

theorem pm_inst : instantiatedTel pm.tel [.tvar 0] [] = .param "x" (.tvar 0) (.done (.tvar 0) Eff.empty) := by
  simp [instantiatedTel, pm, MethSig.tel, signatureTel, Tel.bind, Tel.rawBind, typeEnvAt, Ty.rawBind, SubstEnv.shiftTypes, shiftTypes, Tel.norm, Ty.norm, Eff.norm, Eff.rawBind, rowFails, Ty.normTys, Eff.empty, Ty.shiftV, shiftIndex]
  funext a
  cases a with
  | name l ix => cases ix <;> simp [substAtoms, instAtoms]
  | rho i => simp [substAtoms, instAtoms]

/-- 本体 `d.pm(x)`: 辞書の引数（番号1）からメソッドを呼ぶ。 -/
theorem call_through_dictionary (B : Builtins) :
    TelBodyTy P0 B StoreTy.empty (fun _ => False) [{}]
      [some (.dict "Parent" (.tvar 0))] []
      (.param "x" (.tvar 0) (.done (.tvar 0) Eff.empty))
      (.meth (.var 1) "pm" [] [] [.var 0]) := by
  have ha : Ty.Annotation P0 [{}] [some (.tvar 0), some (.dict "Parent" (.tvar 0))] (.tvar 0) := ⟨by simp [Ty.WF], trivial, trivial⟩
  refine .param (.done ?_)
  have hΓ : Ctx.extend [some (.dict "Parent" (.tvar 0))] (.tvar 0) = [some (.tvar 0), some (.dict "Parent" (.tvar 0))] := by
    simp [Ctx.extend, Ty.shiftV]
  rw [hΓ]
  have hsi : SignatureInstance P0 [{}] [some (.tvar 0), some (.dict "Parent" (.tvar 0))] pm.tel ([] ++ [TyKind.value]) [.tvar 0] [] := by
    refine ⟨?_, ?_, ?_, ?_, ?_⟩
    · simp [Ty.WF, Tel.WF, pm, MethSig.tel, signatureTel, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys]
    · intro t ht; simp at ht; subst t; exact ha
    · exact ⟨rfl, [.value], rfl, by
        intro i a k h1 h2
        cases i with
        | zero =>
          simp at h1 h2; subst h1; subst h2; rfl
        | succ i => simp at h1⟩
    · intro e he; cases he
    · rw [pm_inst]
      constructor <;> simp [Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.empty, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys]
  have hargs : Tel.arguments (instantiatedTel pm.tel ([] ++ [.tvar 0]) []) [.var 0] = some ([.tvar 0], .tvar 0, Eff.empty) := by
    simp only [List.nil_append, pm_inst, Tel.arguments, Tel.bind, Tel.rawBind, Tel.argumentsEnv]
    simp [Tel.arguments, Ty.rawBind, Eff.rawBind, Tel.norm, Ty.norm, Eff.norm, Ty.normTys, Eff.empty, rowFails, valEnv]
    funext a
    cases a with
    | name l ix => cases ix <;> simp [substAtoms, instAtoms, valEnv, Tel.bind]
    | rho i => simp [substAtoms, instAtoms, valEnv]
  have hmeth := @HasTypeCQ.C_Meth P0 B StoreTy.empty (fun _ => False) [{}]
    [some (.tvar 0), some (.dict "Parent" (.tvar 0))] [] [] (some (.tvar 0)) (.var 1) "Parent" (.tvar 0) parentC "pm" pm [] [] [.var 0] [.tvar 0] (.tvar 0) Eff.empty
    (.V_Var rfl (by intro b t e h; cases h)) rfl (by simp [parentC])
    (by simp [NamesWF, pm]) ⟨rfl, by intro i t p h; cases i <;> simp at h⟩ hsi
    ⟨rfl, (by intro f hf; cases hf), by simp [pm, Eff.empty, Eff.RowsIn, Ty.RowsInList], by simp [pm, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty], by intro i hi; simp [pm, Qsig, QTys, QTy, QEff, Eff.empty, Benitoite.Release.Qempty] at hi⟩
    hargs (.cons (.V_Var rfl (by intro b t e h; cases h)) .nil) ha
  exact hmeth

/-- handler の下の escape も done の return 契約を読む。 -/
theorem escape_under_handler (B : Builtins) (Γ) (h1 : Γ[0]? = some (some unit)) :
    HasTypeCQ P0 B StoreTy.empty (fun _ => False) [] Γ [] (some unit) (.handle (.escape (.var 0)) []) unit Eff.empty [] := by
  refine .C_Handle (εm := Eff.empty) (.C_Escape (.V_Var h1 (by intro b t e h; cases h)) ⟨?_, ?_, ?_⟩) ?_ .nil
  · trivial
  · trivial
  · trivial
  · constructor <;> intro x hx <;> simp [Eff.mem, Eff.memFail, Eff.empty, Eff.test, Eff.fails, Eff.atoms] at hx
end
end Benitoite.Release.Refinement.RVW4
