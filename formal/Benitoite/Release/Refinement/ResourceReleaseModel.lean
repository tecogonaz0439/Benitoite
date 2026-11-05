import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.ModelTargets
import Benitoite.Release.Refinement.ModelHttpConditions

/-! # 通常資源値に限定する抽象の解放応答 -/
namespace Benitoite.Release.Refinement.ResourceRelease

/-- 分類されたopaque資源値について、成功と失敗の両方を許す。 -/
def response (isResource : Benitoite.Release.OpaqueName → Bool)
    (v : Val) (_r : Option Benitoite.Release.ErrKind) : Prop :=
  ∃ o i, v = .const (.opaque o i) ∧ isResource o = true

/-- 対象の値型へ分類されない名前oのopaque型に型付く閉じた値は、同じ名前のopaque定数である。 -/
theorem canonical {P B Ψ Q C Φ v o}
    (typed : HasTypeVQ P B Ψ Q C [] Φ v (.opaque o (.fixed .top)))
    (kind : B.valKind o = none) : ∃ i, v = .const (.opaque o i) := by
  have holds : (Ty.opaque o (.fixed .top)).Holds o .path (.fixed .top) := Or.inr rfl
  rcases typed.canonical_held holds with ⟨name,i,hv⟩ | ⟨target,hv⟩ |
    ⟨target,req,hv⟩ | ⟨r,snapshot,target,req,hv⟩
  · have hc := (typed.inv_const hv).2
    simp only [Const.type, Ty.norm, Ty.core, Ty.opaque.injEq] at hc
    exact ⟨i, hc.1 ▸ hv⟩
  · obtain ⟨name,k,range,ix,hk,_,_,ht,_⟩ := typed.inv_checked hv
    have he := holds.unique_name ht
    subst name
    simp [kind] at hk
  · obtain ⟨name,range,A,ix,hk,_,_,_,_,_,ht,_⟩ := typed.inv_checkedRequest hv
    have he := holds.unique_name ht
    subst name
    simp [kind] at hk
  · obtain ⟨name,k,ix,hw,ht,_⟩ := typed.inv_checkedAt hv
    have he := holds.unique_name ht
    subst name
    cases hw with
    | plain hk _ _ _ => simp [kind] at hk
    | request hk _ _ _ _ _ => simp [kind] at hk

/-- 分類は表から供給し、任意の型付き資源に任意の解放結果を与える。 -/
theorem typed_response {P B Ψ Q C Φ v o}
    (classification : ∀ name, B.isResource name = true → B.valKind name = none)
    (typed : HasTypeVQ P B Ψ Q C [] Φ v (.opaque o (.fixed .top)))
    (resource : B.isResource o = true) (r : Option Benitoite.Release.ErrKind) :
    response B.isResource v r := by
  obtain ⟨i,hv⟩ := canonical typed (classification o resource)
  exact ⟨o,i,hv,resource⟩

theorem targets_classification (o : Benitoite.Release.OpaqueName)
    (resource : ModelTargets.builtins.isResource o = true) : ModelTargets.builtins.valKind o = none := by
  change (o == "File.Handle") = true at resource
  have he : o = "File.Handle" := eq_of_beq resource
  subst o
  rfl

/-- 型付きFile.Handleでは成功と失敗を許し、通常の整数と外部ハンドルは断る。 -/
example (P : Program) (Ψ : StoreTy) (r : Benitoite.Release.ErrKind)
    (h : ExternalHandle) (ts : List Ty) :
    HasTypeV P ModelTargets.builtins Ψ [] [] [] (.const (.opaque "File.Handle" 0))
      (.opaque "File.Handle" (.fixed .top)) ∧
    response ModelTargets.builtins.isResource (.const (.opaque "File.Handle" 0)) none ∧
    response ModelTargets.builtins.isResource (.const (.opaque "File.Handle" 0)) (some r) ∧
    ¬ response ModelTargets.builtins.isResource (.const (.integer8 0)) none ∧
    ¬ response ModelTargets.builtins.isResource (.externalHandle h ts) none := by
  have typed : HasTypeV P ModelTargets.builtins Ψ [] [] []
      (.const (.opaque "File.Handle" 0)) (.opaque "File.Handle" (.fixed .top)) := .V_Const ⟨rfl,rfl⟩
  refine ⟨typed, typed_response targets_classification typed rfl none,
    typed_response targets_classification typed rfl (some r), ?_, ?_⟩
  · rintro ⟨o,i,hv,_⟩; cases hv
  · rintro ⟨o,i,hv,_⟩; cases hv

/-- 資源を登録しない二表の解放条件は、資源の前提からFalseになる。 -/
example (o : Benitoite.Release.OpaqueName) :
    Model.builtins.isResource o ≠ true ∧ ModelHttp.builtins.isResource o ≠ true :=
  ⟨Bool.noConfusion, Bool.noConfusion⟩

end Benitoite.Release.Refinement.ResourceRelease
