import Benitoite.Release.Refinement.TypeSubstFormation
namespace Benitoite.Release.Refinement.A3bClosure
noncomputable section

def inner : Ty := .fn [] [] (.base .unit) (Eff.row 0)
def tel : Tel := .param "x" (.reference inner) (.done (.base .unit) Eff.empty)
def body : Comp := .ret (.const .unit)
def closed : Closure := .mk Capture.empty body

private theorem annotation (P : Program) : Ty.Annotation P [] [] (.dependentFn tel) := by
  constructor <;> simp [tel, inner, Ty.WF, Tel.WF, NamesWF, Ty.WFList, Eff.WF,
    Eff.Canonical, Eff.norm, Eff.row, Eff.empty, Ty.Sorted, Tel.Sorted, sortedTys,
    sortedEff, Ty.Declared, Tel.Declared, declaredTys, declaredEff]

theorem captured {P B Ψ} : DependentClosureTy P B Ψ closed tel := by
  have hbody : TelBodyTy P B (hideBuilders Ψ) Qempty [] [] [] tel body :=
    .param (.done (.C_Return (.V_Const trivial)))
  have h := DependentClosureTy.mk (CaptureOk.empty P B (hideBuilders Ψ) none)
    hbody (annotation P) (by
      simpa [Capture.closeTel, Tel.bind, Tel.rawBind, valEnv, Tel.norm, tel, inner,
        Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys, Eff.rawBind, Eff.norm,
        Eff.row, Eff.empty, rowFails, substAtoms_nil, instAtoms_nil, RangeIx.inst_nil] using annotation P)
  simpa [closed, Capture.closeTel, Tel.bind, Tel.rawBind, valEnv, Tel.norm, tel, inner,
    Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys, Eff.rawBind, Eff.norm,
    Eff.row, Eff.empty, rowFails, substAtoms_nil, instAtoms_nil] using h

theorem source {P B Ψ Q} : HasTypeVQ P B Ψ Q [] [] [] (.closure tel closed) (.dependentFn tel) :=
  .V_Closure (annotation P) ⟨(annotation P).wf, (annotation P).wf, ⟨rfl, rfl, trivial⟩⟩ captured

-- 不変の実行時署名と、行の置換後の契約の入力は一致しない。
theorem target_runtime_shape_false : ¬ Tel.RuntimeShape tel (tel.substAt 0 [] [Eff.empty]) := by
  intro h
  have he := h.inputs.2.1
  have hx := congrArg (fun a : Ty => match a with
    | .reference (.fn _ _ _ e) => Eff.test e (.rho 0)
    | _ => false) he
  simp [tel, inner, Tel.substAt, Tel.bind, Tel.rawBind, Tel.norm, Ty.rawBind, Ty.norm,
    rawBindTys, Ty.normTys, Eff.rawBind, Eff.norm, typeEnvAt, Eff.test,
    Eff.row, Eff.empty, Eff.atoms, substAtoms, instAtoms, rowFails] at hx

private def firstRef : Tel → Option Ty
  | .param _ a _ => a.refCore
  | .done _ _ => none

private theorem firstRef_le {P Γ Φ t u a} (h : TelLe P Γ Φ t u) (ha : firstRef t = some a) :
    ∃ b, firstRef u = some b ∧ a.norm = b.norm := by
  cases h with
  | done => cases ha
  | param hb ht =>
    obtain ⟨b, he, hn⟩ := hb.refCore_right ha
    exact ⟨b, he, hn.symm⟩

private theorem firstRef_closure {P Γ Φ t u a} (h : TelClosure P Γ Φ t u) (ha : firstRef t = some a) :
    ∃ b, firstRef u = some b ∧ a.norm = b.norm := by
  match h with
  | .refl => exact ⟨a, ha, rfl⟩
  | .tail h g =>
    obtain ⟨b, hb, hn⟩ := firstRef_closure h ha
    obtain ⟨c, hc, hm⟩ := firstRef_le g hb
    exact ⟨c, hc, hn.trans hm⟩

-- Sub/Normal/Refine の包装を通っても、行置換後の型では型付けられない。
theorem substituted_not_typed {P B Ψ Q} :
    ¬ HasTypeVQ P B Ψ Q [] [] [] (.closure tel closed)
      ((Ty.dependentFn tel).substAt 0 [] [Eff.empty]) := by
  intro h
  obtain ⟨t, u, ha, hr, hb, hu, htu⟩ := h.inv_closure rfl
  have hs : firstRef t = some inner := by
    cases t with
    | done r e => cases hr.inputs
    | param n a rest =>
      have he : Ty.reference inner = a := hr.inputs.2.1
      simp only [firstRef, ← he, Ty.refCore]
  have he : ((Ty.dependentFn tel).substAt 0 [] [Eff.empty]).fnCore =
      some (tel.substAt 0 [] [Eff.empty]) := Ty.fnCore_foldFn _
  have hx := Option.some.inj (hu.symm.trans he)
  subst u
  obtain ⟨b, hb, hn⟩ := firstRef_closure htu hs
  have hh : (firstRef (tel.substAt 0 [] [Eff.empty])).map Ty.norm = some inner.norm := by
    rw [hb, Option.map_some, hn]
  have hx := congrArg (fun o : Option Ty => o.map (fun a => match a with
    | .fn _ _ _ e => Eff.test e (.rho 0)
    | _ => false)) hh
  simp [firstRef, tel, inner, Tel.substAt, Tel.bind, Tel.rawBind, Tel.norm,
    Ty.refCore, Ty.rawBind, Ty.norm, rawBindTys, Ty.normTys,
    Eff.rawBind, Eff.norm, typeEnvAt, Eff.test, Eff.row, Eff.empty,
    Eff.atoms, substAtoms, instAtoms, rowFails] at hx

#print axioms substituted_not_typed

#print axioms captured
#print axioms source
#print axioms target_runtime_shape_false
end
end Benitoite.Release.Refinement.A3bClosure
