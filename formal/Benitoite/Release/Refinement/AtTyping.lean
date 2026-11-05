import Benitoite.Release.Refinement.TypingDeclared
import Benitoite.Release.Refinement.Adequate
import Benitoite.Release.Refinement.AtPrepare
import Benitoite.Release.Refinement.AtSound
import Benitoite.Release.Refinement.ScopePublicValues

/-! # 保持対象の静的な証拠と固定したσへの接続 -/
namespace Benitoite.Release.Refinement

/-- 照合が束縛する九欄の公開形の値は、公開の宣言を持つ同じ P で AtDetail の型を持つ。 -/
theorem Detail.values_typed (P B Ψ Q C Γ Φ) (hp : P.HasScopePublic) (detail : AtError) :
    HasTypeVsQ P B Ψ Q C Γ Φ detail.values atErrorFields :=
  .cons (detail.publicTree_typed.val hp) .nil

theorem CheckedWitness.kind {P B Ψ o k r snapshot target req}
    (h : CheckedWitness P B Ψ o k r snapshot target req) : target.kind = k := by
  cases h with
  | plain _ _ ht _ => exact ht
  | request _ _ _ _ _ hm => exact hm.kind

theorem CheckedWitness.membership {P B Ψ o k r snapshot target req σ}
    (h : CheckedWitness P B Ψ o k r snapshot target req)
    (ha : SnapshotAdequate σ snapshot r) : r.Mem σ k target := by
  cases h with
  | plain _ _ _ hm | request _ _ _ _ _ hm => exact hm.current ha

theorem HasTypeVQ.checked_opaque {P B Ψ Q C Γ Φ o k r t}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k r t) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checked t) (.opaque o (.fixed (.absolute r))) :=
  .V_Sub (.V_Checked hk hc hm) .scoped_forget trivial trivial trivial

theorem HasTypeVQ.checkedRequest_opaque {P B Ψ Q C Γ Φ o r t req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (hv : HasTypeV P B Ψ [] [] [] req T) (hg : groundVal req = true)
    (ht : req.reqTarget = some t) (hm : Scope.Domain.Range.MemK .endpoint r t) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest t req) (.opaque o (.fixed (.absolute r))) :=
  .V_Sub (.V_CheckedRequest hk hc hv.V_Normal hg ht hm) .scoped_forget trivial trivial trivial

theorem CheckedWitness.absolute_plain {P B Ψ o k r t}
    (hk : B.valKind o = some k) (hc : B.valContent o = none)
    (hm : Scope.Domain.Range.MemK k r t) :
    CheckedWitness P B Ψ o k (.absolute r) none t none := .plain hk hc hm.1 hm

theorem CheckedWitness.absolute_request {P B Ψ o r t req T}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some T)
    (hv : HasTypeV P B Ψ [] [] [] req T) (hg : groundVal req = true)
    (ht : req.reqTarget = some t) (hm : Scope.Domain.Range.MemK .endpoint r t) :
    CheckedWitness P B Ψ o .endpoint (.absolute r) none t (some req) := .request hk hc hv.V_Normal hg ht hm

/-- 準備と所属検査の成功から、遷移が作る同じ要求の保持証拠を得る。 -/
theorem CheckedWitness.of_prepared_request
    {P B Ψ cap name kind T bases pattern input index snapshot pat target bound t}
    (hk : B.valKind name = some kind) (hc : B.valContent name = some T)
    (hi : HasTypeV P B Ψ [] [] [] (closeVal cap input) T.norm)
    (hp : AtPrepared B cap kind name bases pattern input index snapshot pat target bound)
    (hv : ∀ σ, snapshot = some σ → σ.Valid)
    (ha : checkAt snapshot kind pat target bound = .ok t) :
    CheckedWitness P B Ψ name kind bound snapshot t (AtRequest B name (closeVal cap input)) := by
  obtain ⟨hg,t0,hr,ht⟩ := hp.request hc
  rw [ht] at ha
  have he := checkAt.absolute ha
  subst t0
  have hm := (checkAt.sound hv ha).2
  have hend := Val.reqTarget_kind hr
  have hk' : kind = .endpoint := hm.kind.symm.trans hend
  subst kind
  simp only [AtRequest,hc]
  exact .request hk hc hi hg hr hm

theorem HasTypeVQ.checkedAt_subst {P B Ψ Q C Γ Φ o k r snapshot t req}
    (ν : Nat → Val) (ρ : Nat → LocalRef) (h : CheckedWitness P B Ψ o k r snapshot t req) :
    HasTypeVQ P B Ψ Q C Γ Φ ((Val.checkedAt r snapshot t req).subst ν ρ)
      (substTyValues ν (.scoped o k (.fixed r))) := .V_CheckedAt h

theorem AtCallAdmissible.fixed_index {P B Ψ Q C Γ Φ kind name shape bases pattern input index}
    (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index) :
    ∃ r, index = .fixed r := by
  cases h with | mk _ _ _ _ _ _ hw _ => exact AtPrepare.fixed_index hw | text _ _ _ _ _ _ hw _ => exact AtPrepare.fixed_index hw

theorem AtCallAdmissible.no_staticIndex {P B Ψ Q C Γ Φ kind name shape bases pattern input index cap detail}
    (h : AtCallAdmissible P B Ψ Q C Γ Φ kind name shape bases pattern input index)
    (he : AtPrepare B cap kind name bases pattern input index = .error detail) :
    detail.failure ≠ .staticIndex := by
  cases h with | mk _ _ _ _ _ _ hw _ => exact AtPrepare.no_staticIndex hw he | text _ _ _ _ _ _ hw _ => exact AtPrepare.no_staticIndex hw he

theorem Pred.member_bind (ν : ObservationEnv) (kind t r) :
    predBind ν (.member kind t r) = .member kind (termBind ν t) r := rfl

theorem Term.targetValue_wf (snapshot : Option PathEnv) (t : Scope.Domain.Target) (nv : Nat) :
    termWF nv (.targetValue snapshot t) := trivial

theorem Val.checkedAt_snapshot_subst (ν : Nat → Val) (ρ : Nat → LocalRef)
    (r snapshot t req) :
    ((Val.checkedAt r snapshot t req).subst ν ρ).toTerm? = some (.targetValue snapshot t) := rfl

end Benitoite.Release.Refinement
