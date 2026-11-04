import Benitoite.Release.Refinement.Ground

/-! # Atの結果の宣言と閉じた保持値 -/
namespace Benitoite.Release.Refinement

def Eff.single (l : EffName) : Eff := .mk (fun a => decide (a = .name l .top)) []

def atErrorType : Ty := .data "Scope.ScopeError" []
def atErrorFields : List Ty := List.replicate 7 (.base .string)

def ResultShape.StandardError (P : Program) (shape : ResultShape) : Prop :=
  shape.errorType = atErrorType ∧ P.DataArity "Scope.ScopeError" 0 ∧
  ∃ cd, P.cons "Scope.ScopeError.At" = some cd ∧ cd.data = "Scope.ScopeError" ∧
    cd.ntys = 0 ∧ cd.args = atErrorFields

structure ResultShape.Declared (P : Program) (shape : ResultShape) : Prop where
  standard : shape.StandardError P
  arity : P.DataArity shape.owner 2
  distinct : shape.ok ≠ shape.error
  okDecl : ∃ cd, P.cons shape.ok = some cd ∧ cd.data = shape.owner ∧
    cd.ntys = 2 ∧ cd.args = [.tvar 0]
  errorDecl : ∃ cd, P.cons shape.error = some cd ∧ cd.data = shape.owner ∧
    cd.ntys = 2 ∧ cd.args = [.tvar 1]

theorem ResultShape.Declared.errorType_eq {P : Program} {shape : ResultShape} (h : shape.Declared P) :
    shape.errorType = atErrorType := h.standard.1

theorem ResultShape.Declared.errorType_declared {P : Program} {shape : ResultShape} {C Γ} (h : shape.Declared P) :
    Ty.Declared P C Γ shape.errorType := by rw [h.errorType_eq]; exact ⟨⟨0, h.standard.2.1, rfl⟩, trivial⟩

theorem ResultShape.Declared.error_data {P : Program} {shape : ResultShape} {Γ : Ctx} {detail : AtError}
    (h : shape.Declared P) : Term.HasData P Γ
      (.dataValue "Scope.ScopeError.At" (detail.textFields.map (fun s => some (.string s)))) "Scope.ScopeError" [] := by
  obtain ⟨cd, hc, hd, hn, ha⟩ := h.standard.2.2
  exact .value hc hd hn (by simp [ha, atErrorFields, Detail.textFields])

theorem ResultShape.Declared.error_observation_declared {P : Program} {shape : ResultShape} {C Γ} {detail : AtError}
    (h : shape.Declared P) : Term.Declared P C Γ
      (.dataValue "Scope.ScopeError.At" (detail.textFields.map (fun s => some (.string s)))) := by
  obtain ⟨cd, hc, _, _, ha⟩ := h.standard.2.2
  exact ⟨by simp [Detail.textFields, declaredSlots, declaredSlot, Term.Declared], cd, hc, by simp [ha, atErrorFields, Detail.textFields]⟩


end Benitoite.Release.Refinement
