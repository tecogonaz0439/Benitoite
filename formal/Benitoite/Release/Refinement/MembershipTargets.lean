import Benitoite.Release.Refinement.ScopeCoverage
import Benitoite.Release.Refinement.CanonicalValues
import Benitoite.Release.Refinement.ClosedEvaluation
import Benitoite.Release.Refinement.ModelHttp
import Benitoite.Release.Refinement.ScopeDeclarations

/-! # 型付きの保持値の対象と範囲への所属 -/
namespace Benitoite.Release.Refinement
open Scope.Domain

private theorem holds_index {T : Ty} {o k ix o' k' ix'} (h : T.Holds o k ix)
    (h' : T.Holds o' k' ix') : ix = ix' := by
  rcases h with h | h <;> rcases h' with h' | h'
  all_goals have he := h.symm.trans h'
  all_goals cases he
  all_goals rfl

theorem HasTypeVQ.target_member {P B Ψ Q v T o k r σ}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (ha : v.Adequate σ) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t := by
  rcases hv.canonical_held ht with ⟨o',payload,rfl⟩ | ⟨t,rfl⟩ |
    ⟨t,req,rfl⟩ | ⟨s,snapshot,t,req,rfl⟩
  · obtain ⟨hc,he⟩ := hv.inv_const rfl
    have ht' : T.Holds o' k (.fixed .top) := Or.inr he
    cases Ty.Holds.unique_name ht' ht
    change B.valKind o = none ∧ _ at hc
    rw [hk] at hc
    cases hc.1
  · obtain ⟨o',k',s,ix,hk',_,hm,ht',hc⟩ := hv.inv_checked rfl
    cases Ty.Holds.unique_name ht' ht
    cases Option.some.inj (hk'.symm.trans hk)
    cases holds_index ht ht'
    exact ⟨t,rfl,hc.mem σ ⟨hm.1,by simpa [RangeExpr.resolve] using hm.2⟩⟩
  · obtain ⟨o',s,A,ix,hk',_,_,_,_,hm,ht',hc⟩ := hv.inv_checkedRequest rfl
    cases Ty.Holds.unique_name ht' ht
    cases Option.some.inj (hk'.symm.trans hk)
    cases holds_index ht ht'
    exact ⟨t,rfl,hc.mem σ ⟨hm.1,by simpa [RangeExpr.resolve] using hm.2⟩⟩
  · obtain ⟨o',k',ix,hw,ht',hc⟩ := hv.inv_checkedAt rfl
    cases Ty.Holds.unique_name ht' ht
    cases holds_index ht ht'
    cases hw with
    | plain hk' _ _ hm =>
      cases Option.some.inj (hk'.symm.trans hk)
      exact ⟨t,rfl,hc.mem σ (hm.current ha.1)⟩
    | request hk' _ _ _ _ hm =>
      cases Option.some.inj (hk'.symm.trans hk)
      exact ⟨t,rfl,hc.mem σ (hm.current ha.1)⟩

/-- 対象の所属の解釈は、同じ snapshot のまま被覆で広げられる。 -/
theorem Pred.member_mono {η : ObservationEnvModel} {k : Kind} {a : Term}
    {r s : RangeExpr} (hc : s.Covers r)
    (hm : (Pred.member k a r).interpret η = true) :
    (Pred.member k a s).interpret η = true := by
  change (Pred.member k a r).atomValue η = true at hm
  change (Pred.member k a s).atomValue η = true
  unfold Pred.atomValue at hm ⊢
  cases ho : observeAs η (.target k) a <;> simp only [ho] at hm ⊢ <;> try cases hm
  exact of_decide_eq_true hm |>.mono hc |> decide_eq_true

example {η : ObservationEnvModel} {a : Term} {r s : RangeExpr} (hc : s.Covers r) :
    ((Pred.member .path a r).interpret η = true → (Pred.member .path a s).interpret η = true) ∧
    ((Pred.member .host a r).interpret η = true → (Pred.member .host a s).interpret η = true) ∧
    ((Pred.member .endpoint a r).interpret η = true → (Pred.member .endpoint a s).interpret η = true) :=
  ⟨Pred.member_mono hc, Pred.member_mono hc, Pred.member_mono hc⟩

/-- 範囲の具体化で固定範囲を得た所属を、同時に具体化した被覆側へ渡す。 -/
theorem Pred.member_inst_mono {η : ObservationEnvModel} {k : Kind} {a : Term}
    {outer inner : RangeIx} (hc : outer.Covers inner) (rs : List RangeExpr)
    {r : RangeExpr} (hi : inner.inst rs = .fixed r)
    (hm : (Pred.member k a r).interpret η = true) :
    ∃ s, outer.inst rs = .fixed s ∧ (Pred.member k a s).interpret η = true := by
  have hh := hc.inst rs
  rw [hi] at hh
  cases ho : outer.inst rs with
  | rvar i => rw [ho] at hh; cases hh
  | fixed s => rw [ho] at hh; exact ⟨s, rfl, Pred.member_mono hh hm⟩

example {η : ObservationEnvModel} (k : Kind) (a : Term) (rs : List RangeExpr)
    (i : Nat) {r : RangeExpr} (hi : rs[i]? = some r)
    (hm : (Pred.member k a r).interpret η = true) :
    ∃ s, (RangeIx.rvar i).inst rs = .fixed s ∧ (Pred.member k a s).interpret η = true :=
  Pred.member_inst_mono (outer := .rvar i) (inner := .rvar i) rfl rs
    (by simp [RangeIx.inst, hi]) hm

example (η : ObservationEnvModel) (k : Kind) (a : Term) (b : PathBase) (p : PathPattern)
    (t : Target) (ho : a.observe η = some (.targetValue none t)) :
    (Pred.member k a (.based b p)).evalWith η = none := by
  simp [Pred.evalWith, Pred.atomReady, memberReady, ho, resolveSnapshot]
/-- 対象の種類を持つ型の閉じた値は、三つの保持構文のいずれかである。 -/
theorem HasTypeVQ.canonical_target {P B Ψ Q v T o k r σ}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (ha : v.Adequate σ) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t ∧
      (v = .checked t ∨ (∃ req, v = .checkedRequest t req) ∨
        ∃ s snapshot req, v = .checkedAt s snapshot t req) := by
  obtain ⟨t,he,hm⟩ := hv.target_member ht hk ha
  refine ⟨t,he,hm,?_⟩
  rcases hv.canonical_held ht with ⟨o',payload,rfl⟩ | ⟨u,rfl⟩ |
    ⟨u,req,rfl⟩ | ⟨s,snapshot,u,req,rfl⟩
  · cases he
  · cases he; exact Or.inl rfl
  · cases he; exact Or.inr (Or.inl ⟨req,rfl⟩)
  · cases he; exact Or.inr (Or.inr ⟨s,snapshot,req,rfl⟩)

/-- 有効な同じ環境の対象観測から、対象所属の述語を解釈する。 -/
theorem HasTypeVQ.target_member_interpret {P B Ψ Q v T o k r σ η a}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (ha : v.Adequate σ) (valid : σ.Valid)
    (observed : ∀ t, v.target? = some t →
      observeAs η (.target k) a = .targetValue (some σ) t) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t ∧
      (Pred.member k a r).interpret η = true := by
  obtain ⟨t,he,hm,_⟩ := hv.canonical_target ht hk ha
  refine ⟨t,he,hm,?_⟩
  change (match observeAs η (.target k) a with
    | .targetValue bs t => decide (SnapshotMem bs k r t) | _ => false) = true
  rw [observed t he]
  exact decide_eq_true (show SnapshotMem (some σ) k r t from ⟨valid,hm⟩)

/-- パス・ホスト・端点のいずれも、Topを含む同じ範囲と同じ観測を使う。 -/
example {P B Ψ Q v T o r σ η a} (k : Scope.Domain.Kind)
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o k (.fixed r)) (hk : B.valKind o = some k)
    (ha : v.Adequate σ) (valid : σ.Valid)
    (observed : ∀ t, v.target? = some t →
      observeAs η (.target k) a = .targetValue (some σ) t) :
    ∃ t, v.target? = some t ∧ r.Mem σ k t ∧
      (Pred.member k a r).interpret η = true := by
  cases k <;> exact hv.target_member_interpret ht hk ha valid observed

/-- 内容型を持つ端点の型付き値は、要求を保持する二構文のいずれかである。 -/
theorem HasTypeVQ.request_form {P B Ψ Q v T o r σ A}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o .endpoint (.fixed r)) (hk : B.valKind o = some .endpoint)
    (hc : B.valContent o = some A) (ha : v.Adequate σ) :
    ∃ target req, v = .checkedRequest target req ∨
      ∃ s snapshot, v = .checkedAt s snapshot target (some req) := by
  have hne : B.valContent o ≠ none := by rw [hc]; simp
  obtain ⟨t,_,_,hf⟩ := hv.canonical_target ht hk ha
  rcases hf with rfl | ⟨req,rfl⟩ | ⟨s,snapshot,req,rfl⟩
  · exact absurd hv (HasTypeVQ.checked_without_request hne ht)
  · exact ⟨t,req,Or.inl rfl⟩
  · cases req with
    | none => exact absurd hv (HasTypeVQ.checkedAt_without_request hne ht)
    | some req => exact ⟨t,req,Or.inr ⟨s,snapshot,rfl⟩⟩

/-- 型付きの端点から、保持する要求と同じ内容・端点・範囲所属を得る。 -/
theorem HasTypeVQ.request_target {P B Ψ Q v T o r σ A}
    (hv : HasTypeVQ P B Ψ Q [] [] [] v T)
    (ht : T.Holds o .endpoint (.fixed r)) (hk : B.valKind o = some .endpoint)
    (hc : B.valContent o = some A) (ha : v.Adequate σ) :
    ∃ target req, (v = .checkedRequest target req ∨
      ∃ s snapshot, v = .checkedAt s snapshot target (some req)) ∧
      ModelHttp.valueRun [v] = .val req ∧
      HasTypeV P B Ψ [] [] [] req A.norm ∧ groundVal req = true ∧
      req.reqTarget = some target ∧ r.Mem σ .endpoint target := by
  obtain ⟨target,req,form⟩ := hv.request_form ht hk hc ha
  refine ⟨target,req,form,?_⟩
  obtain ⟨t,he,hm⟩ := hv.target_member ht hk ha
  rcases form with rfl | ⟨s,snapshot,rfl⟩
  · cases he
    obtain ⟨hh,hg,hr⟩ := hv.checkedRequest_content ht hc
    exact ⟨(ModelHttp.valueRun_request hv ht hc).1,hh,hg,hr,hm⟩
  · cases he
    obtain ⟨o',_,_,hw,ht',_⟩ := hv.inv_checkedAt rfl
    cases Ty.Holds.unique_name ht' ht
    obtain ⟨_,A',hc',hh,hg,hr⟩ := hw.request_content
    cases Option.some.inj (hc'.symm.trans hc)
    exact ⟨(ModelHttp.valueRun_checkedAt_request hv ht hc).1,hh,hg,hr,hm⟩

/-- ground な同じ要求は二つの導入経路で受理され、端点を変えた要求は拒否される。 -/
example {P B Ψ Q C Γ Φ o A req target range other}
    (hk : B.valKind o = some .endpoint) (hc : B.valContent o = some A)
    (hh : HasTypeV P B Ψ [] [] [] req A.norm) (hg : groundVal req = true)
    (hr : req.reqTarget = some target) (hm : Range.MemK .endpoint range target)
    (hne : other ≠ target) :
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest target req)
      (.scoped o .endpoint (.fixed (.absolute range))) ∧
    HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt (.absolute range) none target (some req))
      (.scoped o .endpoint (.fixed (.absolute range))) ∧
    (∀ T, ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedRequest other req) T) ∧
    (∀ T, ¬ HasTypeVQ P B Ψ Q C Γ Φ (.checkedAt (.absolute range) none other (some req)) T) := by
  have bad : req.reqTarget ≠ some other := by simpa [hr] using hne.symm
  exact ⟨.V_CheckedRequest hk hc hh hg hr hm,
    .V_CheckedAt (.request hk hc hh hg hr hm),
    fun _ => HasTypeVQ.checkedRequest_mismatch bad,
    fun _ => HasTypeVQ.checkedAt_request_mismatch bad⟩

namespace RequestMembershipExamples
noncomputable section

private def stringTrue : Ty := .refined (.base .string) .truth
private def header : Val := .con "Pair.Pair" [stringTrue,.base .string]
  [.const (.string "Accept"),.const (.string "text/plain")]
private def request : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"),.const (.string "https://127.0.0.1/"),
    .list [header],.bytesV [],.const (.integer ⟨1,by decide⟩)]
private def endpoint : Target := .endpoint ⟨.ip (.v4 2130706433 (by decide)),⟨443,by decide⟩⟩
private def otherEndpoint : Target := .endpoint ⟨.ip (.v4 2130706433 (by decide)),⟨80,by decide⟩⟩

private theorem typed {P B Ψ} (hP : ScopeDeclarations.HasHttp P) :
    HasTypeV P B Ψ [] [] [] request TargetTable.clientRequestTy := by
  have hp := hP ScopeDeclarations.pair (by simp [ScopeDeclarations.http])
  have hc := hP ScopeDeclarations.clientRequest (by simp [ScopeDeclarations.http])
  have pairLookup : P.cons "Pair.Pair" = some ⟨"Pair",2,[.tvar 0,.tvar 1]⟩ :=
    hp.2 ("Pair.Pair", ⟨"Pair",2,[.tvar 0,.tvar 1]⟩)
      (by simp [ScopeDeclarations.pair,StandardKeyTyping.DataDecl.entries])
  have reqLookup : P.cons "Http.ClientRequest" = some ⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
       .bytes,.base .integer]⟩ :=
    hc.2 ("Http.ClientRequest",⟨"Http.ClientRequest",0,
      [.base .string,.base .string,.list (.data "Pair" [.base .string,.base .string]),
       .bytes,.base .integer]⟩)
      (by simp [ScopeDeclarations.clientRequest,StandardKeyTyping.DataDecl.entries])
  have hd : Ty.Declared P [] [] (.data "Pair" [stringTrue,.base .string]) :=
    ⟨⟨2,hp.1,rfl⟩,⟨⟨trivial,trivial⟩,trivial,trivial⟩⟩
  have ht : HasTypeV P B Ψ [] [] [] (.const (.string "Accept")) stringTrue :=
    .V_Sub (.V_Const trivial) (.introduce trivial .truth)
      ⟨trivial,trivial,by intro b t e h; cases h⟩ ⟨trivial,trivial⟩ ⟨trivial,trivial⟩
  have hh : HasTypeV P B Ψ [] [] [] header (.data "Pair" [stringTrue,.base .string]) := by
    refine .V_Con pairLookup rfl ?_ ?_ ?_ ⟨?_,?_,hd⟩
    · constructor
      · rfl
      · intro i a k ha hk
        cases i with
        | zero => simp at ha hk; subst a; subst k
                  exact ⟨⟨trivial,by intro b t e h; cases h⟩,by intro _ b t e h; cases h⟩
        | succ i =>
          cases i with
          | zero => simp at ha hk; subst a; subst k
                    exact ⟨trivial,by intro _ b t e h; cases h⟩
          | succ i => simp at ha
    · intro t hm; simp at hm; rcases hm with rfl | rfl <;> simp [Ty.WF]
    · simpa [Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,
        stringTrue,Ty.norm_refined_truth,Ty.norm] using
        (show HasTypeVsQ P B Ψ Qempty [] [] []
          [.const (.string "Accept"),.const (.string "text/plain")]
          [stringTrue.norm,.base .string] from .cons ht.V_Normal (.cons (.V_Const trivial) .nil))
    · simp [Ty.WF,Ty.WFList,stringTrue,Pred.WF,Pred.VarsIn,Ty.NotContCore,Ty.core]
    · simp [Ty.Sorted,sortedTys,stringTrue,Pred.Sorted]
  have headerPlain : HasTypeV P B Ψ [] [] [] header (.data "Pair" [.base .string,.base .string]) := by
    simpa only [Ty.norm,Ty.normTys,List.map_cons,List.map_nil,stringTrue,
      Ty.norm_refined_truth] using hh.V_Normal
  refine .V_Con reqLookup rfl ?_ ?_ ?_ ⟨?_,?_,?_⟩
  · exact ⟨rfl,by intro i a k ha; cases i <;> cases ha⟩
  · intro t hm
    simp at hm
    rcases hm with rfl | rfl | rfl | rfl <;> simp [Ty.WF,Ty.WFList]
  · exact .cons (.V_Const trivial) (.cons (.V_Const trivial)
      (.cons (.V_List (.cons headerPlain .nil) (by trivial) (by trivial)
        ⟨⟨2,hp.1,rfl⟩,by trivial⟩)
      (.cons (.V_Bytes (by simp)) (.cons (.V_Const trivial) .nil))))
  · trivial
  · trivial
  · exact ⟨⟨0,hc.1,rfl⟩,trivial⟩

/-- Pair の型引数に true の篩を含む要求でも、同じ endpoint の両導入が成立する。 -/
example {P B Ψ Q} (hP : ScopeDeclarations.HasHttp P)
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some TargetTable.clientRequestTy) :
    HasTypeVQ P B Ψ Q [] [] [] (.checkedRequest endpoint request)
      (.scoped "Http.RequestIn" .endpoint (.fixed .top)) ∧
    HasTypeVQ P B Ψ Q [] [] [] (.checkedAt .top none endpoint (some request))
      (.scoped "Http.RequestIn" .endpoint (.fixed .top)) ∧
    ModelHttp.valueRun [.checkedRequest endpoint request] = .val request ∧
    ModelHttp.valueRun [.checkedAt .top none endpoint (some request)] = .val request ∧
    (∀ T, ¬ HasTypeVQ P B Ψ Q [] [] [] (.checkedRequest otherEndpoint request) T) ∧
    (∀ T, ¬ HasTypeVQ P B Ψ Q [] [] [] (.checkedAt .top none otherEndpoint (some request)) T) := by
  have hh : HasTypeV P B Ψ [] [] [] request TargetTable.clientRequestTy.norm := (typed hP).V_Normal
  have hg : groundVal request = true := by decide
  have hr : request.reqTarget = some endpoint := parseUrlTarget_https_loopback
  have hm : Range.MemK .endpoint .top endpoint := ⟨rfl,trivial⟩
  have checked : HasTypeVQ P B Ψ Q [] [] [] (.checkedRequest endpoint request)
      (.scoped "Http.RequestIn" .endpoint (.fixed .top)) :=
    .V_CheckedRequest hk hc hh hg hr hm
  have atChecked : HasTypeVQ P B Ψ Q [] [] [] (.checkedAt .top none endpoint (some request))
      (.scoped "Http.RequestIn" .endpoint (.fixed .top)) :=
    .V_CheckedAt (.request hk hc hh hg hr hm)
  let σ : PathEnv := ⟨[],[],[],none,none,none⟩
  obtain ⟨_,req₁,_,first,_,_,_⟩ := checked.request_target (σ := σ) (Or.inl rfl) hk hc
    (by trivial)
  obtain ⟨_,req₂,_,second,_,_,_⟩ := atChecked.request_target (σ := σ) (Or.inl rfl) hk hc
    (by simp [Val.Adequate,adequateVals,SnapshotAdequate,RangeExpr.top,request,header])
  have req₁_eq : req₁ = request := by simpa [ModelHttp.valueRun,hg] using first.symm
  have req₂_eq : req₂ = request := by simpa [ModelHttp.valueRun,hg] using second.symm
  subst req₁; subst req₂
  have bad : request.reqTarget ≠ some otherEndpoint := by rw [hr]; decide
  exact ⟨checked,atChecked,first,second,
    fun _ => HasTypeVQ.checkedRequest_mismatch bad,
    fun _ => HasTypeVQ.checkedAt_request_mismatch bad⟩

end
end RequestMembershipExamples
end Benitoite.Release.Refinement
