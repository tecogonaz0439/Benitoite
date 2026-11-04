import Benitoite.Release.Refinement.RequestDelta
import Benitoite.Release.Refinement.ScopeValueDelta

/-! # 保持する要求の射影と同じ値の拡大 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace RequestDelta
open Scope.Domain ScopeSignatures

/-- 型付きの要求は二つの保持形のいずれかであり、default の枝へ入らない。 -/
theorem retained_request {P B Ψ Q v r}
    (h : HasTypeVQ P B Ψ Q [] [] [] v (.opaque "Http.RequestIn" (.fixed r)))
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy) :
    ∃ target req, (v = .checkedRequest target req ∨
      ∃ s snapshot, v = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [v] = .val req ∧
      HasTypeV P B Ψ [] [] [] req clientRequestTy.norm ∧
      groundVal req = true ∧ req.reqTarget = some target := by
  have holds : (Ty.opaque "Http.RequestIn" (.fixed r)).Holds "Http.RequestIn" .endpoint (.fixed r) := Or.inr rfl
  rcases h.canonical_held holds with ⟨o,n,rfl⟩ | ⟨t,rfl⟩ | ⟨t,req,rfl⟩ | ⟨s,snap,t,req,rfl⟩
  · obtain ⟨hc',he⟩ := h.inv_const rfl
    have hh : (Ty.opaque "Http.RequestIn" (.fixed r)).Holds o .endpoint (.fixed .top) := Or.inr he
    cases Ty.Holds.unique_name hh holds
    change B.valKind "Http.RequestIn" = none ∧ _ at hc'
    rw [hk] at hc'; cases hc'.1
  · exact absurd h (HasTypeVQ.checked_without_request (by rw [hc]; simp) holds)
  · obtain ⟨hh,hg,ht⟩ := h.checkedRequest_content holds hc
    exact ⟨t,req,Or.inl rfl,(ModelHttp.valueRun_request h holds hc).1,hh,hg,ht⟩
  · cases req with
    | none => exact absurd h (HasTypeVQ.checkedAt_without_request (by rw [hc]; simp) holds)
    | some req =>
      obtain ⟨hr,hh,hg,ht⟩ := ModelHttp.valueRun_checkedAt_request h holds hc
      obtain ⟨o,k,ix,hw,hh',_⟩ := h.inv_checkedAt rfl
      cases Ty.Holds.unique_name hh' holds
      obtain ⟨_,A,hc',_,hg',_⟩ := hw.request_content
      exact ⟨t,req,Or.inr ⟨s,snap,rfl⟩,hr,hh,hg',ht⟩

def valueDelta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if ts = [] ∧ es = [] then
    if b = "Http.requestInValue" then match rs with | [_] => some (ModelHttp.valueRun ws) | _ => none
    else if b = "Http.widenRequestIn" then match rs with | [_,_] => some (ScopeDelta.widenRun ws) | _ => none
    else none
  else none
private theorem value_instantiated (r : RangeExpr)  :
    instantiatedTel (Tel.instR [r] requestInValue.tel) [] [] =
      Ty.toTel ["request"] [.opaque "Http.RequestIn" (.fixed r)] clientRequestTy Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,requestInValue,pureIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    mapIx,rangeAt,RangeIx.inst,TargetTable.clientRequestTy,
    Benitoite.Release.TargetTable.clientRequestTy,embedTy]

private theorem widen_instantiated (r : RangeExpr) (s : RangeExpr) :
    instantiatedTel (Tel.instR [r,s] widenRequestIn.tel) [] [] =
      Ty.toTel ["request"] [.opaque "Http.RequestIn" (.fixed r)] (.opaque "Http.RequestIn" (.fixed s)) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r,s]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,widenRequestIn,pureIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    mapIx,rangeAt,RangeIx.inst]

/-- 全 BuiltinArgs から、保持する同じ要求への応答を得る。 -/
theorem requestInValue_response {P B Ψ ts es rs ws a e}
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (args : BuiltinArgs P B Ψ "Http.requestInValue" requestInValue ts es rs ws a e) :
    ∃ out, valueDelta "Http.requestInValue" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  subst ts; subst es
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    have hc := args.ranges.1
    cases rs with | nil => cases hc | cons r rs => cases rs with | nil => exact ⟨r,rfl⟩ | cons => cases hc
  have values := args.arguments
  rw [value_instantiated] at values
  have all := values.toTelValues (by simp [NamesWF])
  have ar : a = clientRequestTy := args.result.2.symm.trans all.2.1
  subst a
  have typed : HasTypeVsQ P B Ψ Qempty [] [] [] ws [.opaque "Http.RequestIn" (.fixed r)] := all.1
  cases typed with
  | cons hv hs =>
    cases hs
    rename_i v
    obtain ⟨target,req,form,hr,ht,hg,_⟩ := retained_request hv hk hc
    have ground := groundVal_ground hg
    refine ⟨.val req,?_,by intro n; simp,⟨ht,ground⟩,?_,?_⟩
    · simp [valueDelta,hr]
    · intro σ _ had
      rcases form with form | ⟨s,snap,form⟩
      · cases form
        exact had (.checkedRequest target req) (by simp)
      · cases form
        exact (had (.checkedAt s snap target (some req)) (by simp)).2
    · intro w hw; cases hw; exact ground

/-- 許容表が指定する被覆から、同じ値を目的の不透明型へ渡す。 -/
theorem widenRequestIn_response {P B Ψ ts es rs ws a e}
    (covers : ∀ r s, B.admitsR "Http.widenRequestIn" [r,s] → s.Covers r)
    (args : BuiltinArgs P B Ψ "Http.widenRequestIn" widenRequestIn ts es rs ws a e) :
    ∃ out, valueDelta "Http.widenRequestIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  subst ts; subst es
  obtain ⟨r,s,rfl⟩ : ∃ r s, rs = [r,s] := by
    have hc := args.ranges.1
    cases rs with | nil => cases hc | cons r rs => cases rs with
    | nil => cases hc
    | cons s rs => cases rs with | nil => exact ⟨r,s,rfl⟩ | cons => cases hc
  have hc : s.Covers r := by
    rcases args.ranges.2.2.2 with top | permitted
    · rw [top r (by simp),top s (by simp)]; exact RangeExpr.Covers.refl _
    · exact covers r s permitted
  have values := args.arguments
  rw [widen_instantiated] at values
  have all := values.toTelValues (by simp [NamesWF])
  have ar : a = .opaque "Http.RequestIn" (.fixed s) := args.result.2.symm.trans all.2.1
  subst a
  have typed : HasTypeVsQ P B Ψ Qempty [] [] [] ws [.opaque "Http.RequestIn" (.fixed r)] := all.1
  cases typed with
  | cons hv hs =>
    cases hs
    rename_i v
    have hg := args.ground v (by simp)
    exact ⟨.val v,by simp [valueDelta,ScopeDelta.widenRun],by intro n; simp,
      ⟨hv.widen_opaque hc,hg⟩,by intro σ _ had; exact had v (by simp),by intro w hw; cases hw; exact hg⟩


/-- 全型付き要求の拡大は、同じ req・端点と保持値を変えない。 -/
example {P B Ψ Q v r s}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v (.opaque "Http.RequestIn" (.fixed r)))
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy) (cover : s.Covers r) :
    ∃ target req, ScopeDelta.widenRun [v] = .val v ∧
      HasTypeVQ P B Ψ Q [] [] [] v (.opaque "Http.RequestIn" (.fixed s)) ∧
      ModelHttp.valueRun [v] = .val req ∧ req.reqTarget = some target ∧
      (v = .checkedRequest target req ∨ ∃ bound snapshot, v = .checkedAt bound snapshot target (some req)) := by
  obtain ⟨target,req,form,run,_,_,endpoint⟩ := retained_request hv hk hc
  exact ⟨target,req,rfl,hv.widen_opaque cover,run,endpoint,form⟩

/-- 二つの保持経路は同じ要求を射影し、拡大も同じ保持値を返す。 -/
example (req : Val) (hg : groundVal req = true) (target : Target) (r : RangeExpr)
    (snapshot : Option PathEnv) :
    ModelHttp.valueRun [.checkedRequest target req] = .val req ∧
    ModelHttp.valueRun [.checkedAt r snapshot target (some req)] = .val req ∧
    ScopeDelta.widenRun [.checkedAt r snapshot target (some req)] =
      .val (.checkedAt r snapshot target (some req)) :=
  ⟨ModelHttp.valueRun_checkedRequest hg,ModelHttp.valueRun_checkedAt hg,rfl⟩

end RequestDelta
end
end Benitoite.Release.Refinement
