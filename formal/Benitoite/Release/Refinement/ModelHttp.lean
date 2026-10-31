import Benitoite.Release.ModelHttp
import Benitoite.Release.Refinement.TargetTable
import Benitoite.Release.Refinement.Embedding

/-! # 保持した要求の射影

要求の型付け・閉性・端点一致を逆転で取り出し、同じ要求を射影する。
旧モデルとの交換は構文の埋め込みに限り、任意の表の充足を仮定しない。
-/
namespace Benitoite.Release.Refinement.ModelHttp

open Benitoite.Release.Refinement

def valueRun : List Val → Outcome
  | [.checkedRequest _ req] | [.checkedAt _ _ _ (some req)] =>
      if groundVal req then .val req else .val (embedVal Benitoite.Release.ModelHttp.defaultRequest)
  | _ => .val (embedVal Benitoite.Release.ModelHttp.defaultRequest)

theorem valueRun_checkedRequest {target req} (hg : groundVal req = true) :
    valueRun [.checkedRequest target req] = .val req := by simp [valueRun,hg]

theorem valueRun_typed {P B Ψ Q C Γ Φ T target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T) :
    valueRun [.checkedRequest target req] = .val req ∧
      ∃ o A range ix, B.valContent o = some A ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
        req.Ground ∧ req.reqTarget = some target ∧
        Scope.Domain.Range.MemK .endpoint range target ∧ T.Holds o .endpoint ix ∧
        ix.Covers (.fixed (.absolute range)) := by
  obtain ⟨o,r,A,ix,_,hc,hh,hg,ht,hm,ha,hi⟩ := h.inv_checkedRequest rfl
  exact ⟨valueRun_checkedRequest hg,o,A,r,ix,hc,hh,groundVal_ground hg,ht,hm,ha,hi⟩

theorem valueRun_request {P B Ψ Q C Γ Φ T target req o ix A}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req) T)
    (ht : T.Holds o .endpoint ix) (hc : B.valContent o = some A) :
    valueRun [.checkedRequest target req] = .val req ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ req.Ground ∧ req.reqTarget = some target := by
  obtain ⟨hh,hg,he⟩ := h.checkedRequest_content ht hc
  exact ⟨valueRun_checkedRequest hg,hh,groundVal_ground hg,he⟩

theorem valueRun_checkedAt {r snapshot target req} (hg : groundVal req = true) :
    valueRun [.checkedAt r snapshot target (some req)] = .val req := by simp [valueRun,hg]

theorem valueRun_checkedAt_typed {P B Ψ Q C Γ Φ T r snapshot target req}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target (some req)) T) :
    valueRun [.checkedAt r snapshot target (some req)] = .val req ∧
      ∃ o A, B.valContent o = some A ∧ HasTypeV P B Ψ [] [] [] req A.norm ∧
        req.Ground ∧ req.reqTarget = some target := by
  obtain ⟨o,_,_,hw,_,_⟩ := h.inv_checkedAt rfl
  obtain ⟨_,A,hc,hh,hg,ht⟩ := hw.request_content
  exact ⟨valueRun_checkedAt hg,o,A,hc,hh,groundVal_ground hg,ht⟩

theorem valueRun_checkedAt_request {P B Ψ Q C Γ Φ T r snapshot target req o ix A}
    (h : HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt r snapshot target (some req)) T)
    (ht : T.Holds o .endpoint ix) (hc : B.valContent o = some A) :
    valueRun [.checkedAt r snapshot target (some req)] = .val req ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ req.Ground ∧ req.reqTarget = some target := by
  obtain ⟨o',_,_,hw,ht',_⟩ := h.inv_checkedAt rfl
  have hn := Ty.Holds.unique_name ht' ht
  subst o'
  obtain ⟨_,A',hc',hh,hg,he⟩ := hw.request_content
  have ha : A' = A := Option.some.inj (hc'.symm.trans hc)
  subst A'
  exact ⟨valueRun_checkedAt hg,hh,groundVal_ground hg,he⟩

mutual
  theorem groundTy_embed (a : Benitoite.Release.Ty) :
      groundTy (embedTy a) = Benitoite.Release.ModelHttp.groundTy a := by
    cases a <;> try rfl
    case data d ts => exact groundTys_embed ts
    case list a => exact groundTy_embed a
  theorem groundTys_embed (as : List Benitoite.Release.Ty) :
      groundTys (embedTys as) = Benitoite.Release.ModelHttp.groundTys as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [embedTys,groundTys,Benitoite.Release.ModelHttp.groundTys,
        groundTy_embed a,groundTys_embed as]
end

mutual
  theorem groundVal_embed (v : Benitoite.Release.Val) :
      groundVal (embedVal v) = Benitoite.Release.ModelHttp.groundVal v := by
    cases v <;> try rfl
    case list vs => exact groundVals_embed vs
    case con c ts vs => simp only [embedVal,groundVal,Benitoite.Release.ModelHttp.groundVal,
      groundTys_embed ts,groundVals_embed vs]
  theorem groundVals_embed (vs : List Benitoite.Release.Val) :
      groundVals (embedVals vs) = Benitoite.Release.ModelHttp.groundVals vs := by
    cases vs with
    | nil => rfl
    | cons v vs => simp only [embedVals,groundVals,Benitoite.Release.ModelHttp.groundVals,
        groundVal_embed v,groundVals_embed vs]
end

theorem valueRun_embed (vs : List Benitoite.Release.Val) :
    valueRun (embedVals vs) = embedOutcome (Benitoite.Release.ModelHttp.valueRun vs) := by
  cases vs with
  | nil => rfl
  | cons v vs =>
    cases vs with
    | cons w ws => cases v <;> rfl
    | nil =>
      cases v <;> try rfl
      case checkedRequest target req =>
        simp only [embedVals,embedVal,valueRun,Benitoite.Release.ModelHttp.valueRun,groundVal_embed]
        split <;> rfl

end Benitoite.Release.Refinement.ModelHttp
