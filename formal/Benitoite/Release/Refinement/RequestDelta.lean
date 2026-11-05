import Benitoite.Release.Refinement.ScopeDelta

/-! # 同じ要求と端点を保持する純粋チェックの具体応答 -/
namespace Benitoite.Release.Refinement.RequestDelta
open Scope.Domain ScopeDeclarations ScopeSignatures
noncomputable section
set_option maxRecDepth 4000
set_option maxHeartbeats 2000000

/-- 字句解析は既存の対象解析に固定し、ホスト条件の exact・one・many・CIDR を組み立てる。 -/
def parseHostPattern (raw : String) : Option HostPattern := do
  let pattern ←
    if raw.startsWith "**." then
      match parseAtInput .host (.const (.string (String.ofList (raw.toList.drop 3)))) with
      | some (.absolute (.host (.name w))) => some (HostPattern.name (.many w))
      | _ => none
    else if raw.startsWith "*." then
      match parseAtInput .host (.const (.string (String.ofList (raw.toList.drop 2)))) with
      | some (.absolute (.host (.name w))) => some (HostPattern.name (.one w))
      | _ => none
    else match (raw.toList.splitOn '/').map String.ofList with
      | [address,prefixText] => do
        if prefixText.length ≥ 4 ∨ (prefixText.length ≥ 2 ∧ prefixText.startsWith "0") then none else do
        let n ← prefixText.toNat?
        match parseAtInput .host (.const (.string address)) with
        | some (.absolute (.host (.ip ip))) => some (HostPattern.ip (.cidr ⟨ip.family,ip.bits,n⟩))
        | _ => none
      | [host] => match parseAtInput .host (.const (.string host)) with
        | some (.absolute (.host (.name w))) => some (HostPattern.name (.exact w))
        | some (.absolute (.host (.ip ip))) => some (HostPattern.ip (.exact ip))
        | _ => none
      | _ => none
  if pattern.WF then some pattern.normalize else none

private def urlText : Val → String
  | .con "Http.ClientRequest" _ [_,.const (.string url),_,_,_] => url
  | _ => "invalid request"

/-- 元の authority からホストの綴りを取り出す。 -/
private def hostText (req : Val) : String :=
  ((parseUrlShape (urlText req)).map Prod.fst).getD ""

/-- 解析済みのポートは言語の Integer に収まる。 -/
private def portValue (p : Port) : Integer64Value :=
  ⟨(p.val : Int),by have h := p.isLt; change -9223372036854775808 ≤ (p.val : Int) ∧
    (p.val : Int) ≤ 9223372036854775807; omega⟩

namespace text
def INVALID_URL : String := "expected an absolute ASCII http or https URL with a host, valid percent escapes, no userinfo, and a port in 0..65535"
def INVALID_HOST : String := "expected an ASCII host name, canonical IPv4, or numeric IPv6 without a zone identifier"
end text

def invalidUrl : Val := .con "Http.RequestCheckError.InvalidUrl" [] [.const (.string text.INVALID_URL)]
def scopeError (v : Val) : Val := .con "Http.RequestCheckError.Scope" [] [v]

theorem invalidUrl_safe {P B Ψ} (hp : HasHttp P) :
    HasTypeVQ P B Ψ Qempty [] [] [] invalidUrl requestCheckErrorTy ∧
      invalidUrl.Ground ∧ ∀ σ, invalidUrl.Adequate σ := by
  have h := hp requestCheckError (by simp [http])
  refine ⟨.V_Con (h.2 ("Http.RequestCheckError.InvalidUrl",⟨"Http.RequestCheckError",0,[.base .string]⟩)
    (by simp [requestCheckError,StandardKeyTyping.DataDecl.entries])) rfl
    ⟨rfl,by intro i a k ha; cases i <;> cases ha⟩ ?_ ?_
    ⟨trivial,trivial,⟨⟨0,h.1,rfl⟩,trivial⟩⟩,
    by simp [invalidUrl,Val.Ground,Val.ClosedAt,Val.ClosedList],by intro σ; trivial⟩
  · intro t ht; cases List.mem_singleton.mp ht; trivial
  · exact .cons (.V_Const trivial) .nil

/-- Scope の全六 payload と内部の静的拒否を、同じ RequestCheckError で包む。 -/
theorem scopeError_safe {P B Ψ v} (hp : HasHttp P)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] v atErrorType) (hg : v.Ground) :
    HasTypeVQ P B Ψ Qempty [] [] [] (scopeError v) requestCheckErrorTy ∧
      (scopeError v).Ground ∧ ∀ σ, v.Adequate σ → (scopeError v).Adequate σ := by
  have h := hp requestCheckError (by simp [http])
  have hs := (hp ScopeDeclarations.scopeError (by simp [http,file])).1
  refine ⟨.V_Con (h.2 ("Http.RequestCheckError.Scope",⟨"Http.RequestCheckError",0,[atErrorType]⟩)
    (by simp [requestCheckError,StandardKeyTyping.DataDecl.entries])) rfl
    ⟨rfl,by intro i a k ha; cases i <;> cases ha⟩ ?_ ?_
    ⟨trivial,trivial,⟨⟨0,h.1,rfl⟩,trivial⟩⟩,
    ⟨by simp,hg,trivial⟩,fun _ hv => ⟨hv,trivial⟩⟩
  · intro t ht; cases List.mem_singleton.mp ht; trivial
  · simpa [atErrorType,Ty.subst,Ty.substAt,substTypeAt,Ty.bind,Ty.rawBind,typeEnvAt,rawBindTys,
      Ty.norm,Ty.normTys] using (HasTypeVsQ.cons hv HasTypeVsQ.nil)

def checkTys (r : RangeExpr) : List Ty := [.opaque "Http.RequestIn" (.fixed r),requestCheckErrorTy]
def ok (r : RangeExpr) (v : Val) : Outcome :=
  .val (ScopeDelta.resultValue true (.opaque "Http.RequestIn" (.fixed r)) requestCheckErrorTy v)
def error (r : RangeExpr) (v : Val) : Outcome :=
  .val (ScopeDelta.resultValue false (.opaque "Http.RequestIn" (.fixed r)) requestCheckErrorTy v)

/-- 結果の型の静的な範囲に入らない端点の拒否。旧 API は旧構成子で返す。上限が端点の条件でホストが合えば、
上限のポート範囲と端点のポートを持つ PortOutsideScope、それ以外は元のホスト条件とホストの綴りを持つ
OutsideScope とする。 -/
private def staticError (pattern : String) (lo hi : Integer64Value) (req : Val)
    (checked : Checked.Scope.CheckedEndpoint) (endpoint : Endpoint) : RangeExpr → Val
  | .absolute (.endpoint bound) =>
    if bound.host.Matches endpoint.host then
      ScopeDelta.errorValue pattern (hostText req) (portValue bound.ports.lo) (portValue bound.ports.hi)
        (portValue endpoint.port) (.portOutsideScope bound.ports.lo.val bound.ports.hi.val endpoint.port.val)
    else ScopeDelta.errorValue pattern (hostText req) lo hi (portValue endpoint.port)
      (.outsideScope (.host checked.hostPattern) (.endpoint endpoint))
  | _ => ScopeDelta.errorValue pattern (hostText req) lo hi (portValue endpoint.port)
      (.outsideScope (.host checked.hostPattern) (.endpoint endpoint))

/-- URL の取得後、既存の host・port の順で検査し、成功時に同じ要求を保持する。 -/
def run (r : RangeExpr) : List Val → Outcome
  | [.const (.string pattern),.const (.integer lo),.const (.integer hi),req] =>
    if groundVal req then
      match parseUrlShape (urlText req) with
      | none => error r invalidUrl
      | some (host, _) =>
        match req.reqTarget with
        | some (.endpoint endpoint) =>
          match parseHostPattern pattern with
          | none => error r (scopeError (ScopeDelta.invalidPattern pattern ScopeDelta.text.ENDPOINT_PATTERN))
          | some p =>
            match Checked.Scope.makeEndpoint p endpoint.host lo.toInt hi.toInt (portValue endpoint.port).toInt with
            | .error err => error r (scopeError (ScopeDelta.errorValue pattern (hostText req) lo hi (portValue endpoint.port) err))
            | .ok checked => match r with
              | .absolute bound =>
                if Range.MemK .endpoint bound (.endpoint endpoint) then ok r (.checkedRequest (.endpoint endpoint) req)
                else error r (scopeError (staticError pattern lo hi req checked endpoint r))
              | .based _ _ | .secrets => error r (scopeError (staticError pattern lo hi req checked endpoint r))
        | _ => error r (scopeError (ScopeDelta.invalidTarget host
            (if urlHostMapped host then ScopeDelta.text.MAPPED_TARGET else text.INVALID_HOST)))
    else error r invalidUrl
  | _ => error r invalidUrl

def delta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b = "Http.checkRequestIn" ∧ ts = [] ∧ es = [] then
    match rs with | [r] => some (run r ws) | _ => none
  else ScopeDelta.delta b ts es rs ws

private theorem error_reply {P B Ψ r ws v} (hp : HasHttp P)
    (safe : HasTypeVQ P B Ψ Qempty [] [] [] v requestCheckErrorTy ∧ v.Ground ∧ ∀ σ, v.Adequate σ) :
    Outcome.Typed P B Ψ (error r v) (.data "Result" (checkTys r)) ∧
      AdequateResult ws (error r v) ∧
      (∀ w, error r v = .val w → w.Ground) ∧ ∀ n, error r v ≠ .exit n := by
  have he := (hp requestCheckError (by simp [http])).1
  have h := ScopeDelta.result_safe (Ψ := Ψ) (ws := ws)
    (a := .opaque "Http.RequestIn" (.fixed r)) (e := requestCheckErrorTy) hp.file false
    (ScopeDelta.checked_annotation "Http.RequestIn" r).1
    ⟨trivial,trivial,⟨⟨0,he,rfl⟩,trivial⟩⟩ trivial ⟨TyCon.arity_data he,trivial⟩
    rfl rfl (by intro b c d h; cases h) (by intro b c d h; cases h)
    safe.1 safe.2.1 (by intro σ _ _; exact safe.2.2 σ)
  exact ⟨h.1,h.2.1,by intro w hw; cases hw; exact h.2.2.1,h.2.2.2⟩

private theorem scope_reply {P B Ψ r ws v} (hp : HasHttp P)
    (safe : HasTypeVQ P B Ψ Qempty [] [] [] v atErrorType ∧ v.Ground ∧ ∀ σ, v.Adequate σ) :
    Outcome.Typed P B Ψ (error r (scopeError v)) (.data "Result" (checkTys r)) ∧
      AdequateResult ws (error r (scopeError v)) ∧
      (∀ w, error r (scopeError v) = .val w → w.Ground) ∧ ∀ n, error r (scopeError v) ≠ .exit n := by
  have h := scopeError_safe hp safe.1 safe.2.1
  exact error_reply hp ⟨h.1,h.2.1,fun σ => h.2.2 σ (safe.2.2 σ)⟩

private theorem static_safe {P B Ψ} (hp : HasHttp P) (pattern : String) (lo hi : Integer64Value) (req : Val)
    (checked : Checked.Scope.CheckedEndpoint) (endpoint : Endpoint) (r : RangeExpr) :
    HasTypeVQ P B Ψ Qempty [] [] [] (staticError pattern lo hi req checked endpoint r) atErrorType ∧
      (staticError pattern lo hi req checked endpoint r).Ground ∧
      ∀ σ, (staticError pattern lo hi req checked endpoint r).Adequate σ := by
  unfold staticError
  split
  · split
    · exact ScopeDelta.error_safe hp.file _ _ _ _ _ _
    · exact ScopeDelta.error_safe hp.file _ _ _ _ _ _
  · exact ScopeDelta.error_safe hp.file _ _ _ _ _ _

/-- 全型付き入力と全範囲で、同じ要求の応答契約を満たす。 -/
theorem run_safe {P B Ψ} (hp : HasHttp P)
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy) (r : RangeExpr) (ws : List Val)
    (typed : HasTypeVsQ P B Ψ Qempty [] [] [] ws
      [.base .string,.base .integer,.base .integer,clientRequestTy]) :
    Outcome.Typed P B Ψ (run r ws) (.data "Result" (checkTys r)) ∧
      AdequateResult ws (run r ws) ∧ (∀ v, run r ws = .val v → v.Ground) ∧
      ∀ n, run r ws ≠ .exit n := by
  unfold run
  split
  · rename_i pattern lo hi req
    cases typed with | cons _ hs => cases hs with | cons _ hs => cases hs with | cons _ hs => cases hs with | cons reqTyped _ =>
      split
      · rename_i hg
        split
        · exact error_reply hp (invalidUrl_safe hp)
        · rename_i shape hs
          rcases shape with ⟨host,port⟩
          split
          · rename_i endpoint ht
            split
            · exact scope_reply hp (ScopeDelta.error_safe hp.file _ _ _ _ _ _ ScopeDelta.text.ENDPOINT_PATTERN)
            · rename_i p _
              split
              · exact scope_reply hp (ScopeDelta.error_safe hp.file _ _ _ _ _ _)
              · rename_i checked _
                cases r with
                | absolute bound =>
                  dsimp only
                  split
                  · rename_i hm
                    have he := (hp requestCheckError (by simp [http])).1
                    have h := ScopeDelta.result_safe (Ψ := Ψ)
                      (a := .opaque "Http.RequestIn" (.fixed (.absolute bound))) (e := requestCheckErrorTy)
                      (ws := [.const (.string pattern),.const (.integer lo),.const (.integer hi),req]) hp.file true
                      (ScopeDelta.checked_annotation "Http.RequestIn" (.absolute bound)).1
                      ⟨trivial,trivial,⟨⟨0,he,rfl⟩,trivial⟩⟩ trivial ⟨TyCon.arity_data he,trivial⟩
                      rfl rfl (by intro b c d he; cases he) (by intro b c d he; cases he)
                      (HasTypeVQ.checkedRequest_opaque hk hc reqTyped hg ht hm)
                      (by change req.Ground; exact groundVal_ground hg)
                      (by intro σ _ had; exact had req (by simp))
                    exact ⟨h.1,h.2.1,by intro v hv; cases hv; exact h.2.2.1,h.2.2.2⟩
                  · exact scope_reply hp (static_safe hp _ _ _ _ _ _ _)
                | based _ _ | secrets =>
                  exact scope_reply hp (static_safe hp _ _ _ _ _ _ _)
          · exact scope_reply hp (ScopeDelta.invalidTarget_safe hp.file _ _)
      · exact error_reply hp (invalidUrl_safe hp)
  · exact error_reply hp (invalidUrl_safe hp)

private theorem instantiated (r : RangeExpr) :
    instantiatedTel (Tel.instR [r] ScopeSignatures.checkRequestIn.tel) [] [] =
      Ty.toTel ["hostPattern","minimumPort","maximumPort","request"]
        [.base .string,.base .integer,.base .integer,clientRequestTy]
        (.data "Result" (checkTys r)) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 [r]) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [emptyRange,ScopeSignatures.checkRequestIn,pureIn,PrimSig.tel,signatureTel,
    instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
    Ty.rawMapRanges,Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
    Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,Eff.empty,
    typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,checkTys,
    TargetTable.clientRequestTy,Benitoite.Release.TargetTable.clientRequestTy,embedTy,
    mapIx,rangeAt,RangeIx.inst]

/-- 全 BuiltinArgs を同じ要求の具体 δ に接続する。 -/
theorem response {P B Ψ ts es rs ws a e} (hp : HasHttp P)
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (args : BuiltinArgs P B Ψ "Http.checkRequestIn" ScopeSignatures.checkRequestIn ts es rs ws a e) :
    ∃ out, delta "Http.checkRequestIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      ∀ v, out = .val v → v.Ground := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    have count := args.ranges.1
    cases rs with
    | nil => cases count
    | cons r rs => cases rs with
      | nil => exact ⟨r,rfl⟩
      | cons r' rs => cases count
  subst ts; subst es
  have values := args.arguments
  rw [instantiated] at values
  have all := values.toTelValues (by simp [NamesWF])
  have ar : a = .data "Result" (checkTys r) := args.result.2.symm.trans all.2.1
  subst a
  have typed : HasTypeVsQ P B Ψ Qempty [] [] [] ws
      [.base .string,.base .integer,.base .integer,clientRequestTy] := all.1
  have h := run_safe hp hk hc r ws typed
  exact ⟨run r ws,by simp [delta],h.2.2.2,h.1,h.2.1,h.2.2.1⟩

/-- 共通16行の同じ lookup と δ から、全ての具体化と実入力の契約を得る。 -/
example {P io Ψ sg ts es rs ws a e} (hp : HasHttp P)
    (hs : (ScopeSignatures.builtins delta io).sig "Http.checkRequestIn" = some sg)
    (args : BuiltinArgs P (ScopeSignatures.builtins delta io) Ψ "Http.checkRequestIn" sg ts es rs ws a e) :
    ∃ out, (ScopeSignatures.builtins delta io).delta "Http.checkRequestIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed P (ScopeSignatures.builtins delta io) Ψ out a ∧
      AdequateResult ws out ∧ ∀ v, out = .val v → v.Ground := by
  have he : sg = ScopeSignatures.checkRequestIn := (Option.some.inj hs).symm
  subst sg
  exact response hp rfl rfl args

/-- 同じ δ のパスの行も、同じ P と共通表で使う。 -/
example {io Ψ sg ts es rs ws a e}
    (hs : (ScopeSignatures.builtins delta io).sig "Scope.checkPathIn" = some sg)
    (args : BuiltinArgs ScopeDeclarations.program (ScopeSignatures.builtins delta io) Ψ
      "Scope.checkPathIn" sg ts es rs ws a e) :
    ∃ out, (ScopeSignatures.builtins delta io).delta "Scope.checkPathIn" ts es rs ws = some out ∧
      (∀ n, out ≠ .exit n) ∧ Outcome.Typed ScopeDeclarations.program (ScopeSignatures.builtins delta io) Ψ out a ∧
      AdequateResult ws out ∧ ∀ v, out = .val v → v.Ground := by
  have he : sg = ScopeSignatures.checkPathIn := (Option.some.inj hs).symm
  subst sg
  obtain ⟨out,hd,hn,ht,ha,hg⟩ := ScopeDelta.response program_hasHttp.file rfl rfl args
  exact ⟨out,by simpa [ScopeSignatures.builtins,RequestDelta.delta] using hd,hn,ht,ha,hg⟩

/-- 同じ端点を得た後の全入力は、既存の順序で host・port と静的上限を検査する。 -/
theorem run_endpoint {req pattern endpoint p}
    (hg : groundVal req = true) (hs : (parseUrlShape (urlText req)).isSome = true)
    (ht : req.reqTarget = some (.endpoint endpoint))
    (hp : parseHostPattern pattern = some p) (r : RangeExpr) (lo hi : Integer64Value) :
    run r [.const (.string pattern),.const (.integer lo),.const (.integer hi),req] =
      match Checked.Scope.makeEndpoint p endpoint.host lo.toInt hi.toInt (portValue endpoint.port).toInt with
      | .error err => error r (scopeError (ScopeDelta.errorValue pattern (hostText req) lo hi (portValue endpoint.port) err))
      | .ok checked => match r with
        | .absolute bound => if Range.MemK .endpoint bound (.endpoint endpoint) then
            ok r (.checkedRequest (.endpoint endpoint) req)
          else error r (scopeError (staticError pattern lo hi req checked endpoint r))
        | .based _ _ | .secrets => error r (scopeError (staticError pattern lo hi req checked endpoint r)) := by
  cases he : parseUrlShape (urlText req) with
  | none => simp [he] at hs
  | some shape => rcases shape with ⟨host,port⟩; simp only [run,hg,he,ht,hp,↓reduceIte]

/-- 全成功入力で、同じ req と端点を返し、解析器を差し替えない。 -/
example {req pattern endpoint p checked bound lo hi}
    (hg : groundVal req = true) (hs : (parseUrlShape (urlText req)).isSome = true)
    (ht : req.reqTarget = some (.endpoint endpoint))
    (hp : parseHostPattern pattern = some p)
    (hd : Checked.Scope.makeEndpoint p endpoint.host lo.toInt hi.toInt (portValue endpoint.port).toInt = .ok checked)
    (hm : Range.MemK .endpoint bound (.endpoint endpoint)) :
    run (.absolute bound) [.const (.string pattern),.const (.integer lo),.const (.integer hi),req] =
      ok (.absolute bound) (.checkedRequest (.endpoint endpoint) req) := by
  simp [run_endpoint hg hs ht hp,hd,hm]

private def sampleIP : IPAddr := .v4 2130706433 (by decide)
private def sampleEndpoint : Endpoint := ⟨.ip sampleIP,⟨443,by decide⟩⟩
private def samplePort : Integer64Value := ⟨443,by decide⟩
private def sampleRequest : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"),.const (.string "https://127.0.0.1/"),.list [],.bytesV [],.const (.integer ⟨1,by decide⟩)]
private def sampleBound : Range := .endpoint ⟨.ip (.exact sampleIP),⟨⟨443,by decide⟩,⟨443,by decide⟩⟩⟩

/-- 一点の静的上限でも同じ要求を返し、異なるポートの動的条件は拒否する。 -/
example :
    run (.absolute sampleBound)
      [.const (.string "127.0.0.1"),.const (.integer samplePort),.const (.integer samplePort),sampleRequest] =
        ok (.absolute sampleBound) (.checkedRequest (.endpoint sampleEndpoint) sampleRequest) ∧
    run (.absolute sampleBound)
      [.const (.string "127.0.0.1"),.const (.integer ⟨80,by decide⟩),.const (.integer ⟨80,by decide⟩),sampleRequest] =
        error (.absolute sampleBound) (scopeError
          (ScopeDelta.errorValue "127.0.0.1" (hostText sampleRequest) ⟨80,by decide⟩ ⟨80,by decide⟩
            (portValue sampleEndpoint.port) (.portOutsideScope 80 80 443))) := by
  have hg : groundVal sampleRequest = true := by decide
  have hs : (parseUrlShape (urlText sampleRequest)).isSome = true := by cbv
  have ht : sampleRequest.reqTarget = some (.endpoint sampleEndpoint) := parseUrlTarget_https_loopback
  have hp : parseHostPattern "127.0.0.1" = some (.ip (.exact sampleIP)) := by
    have star : "127.0.0.1".startsWith "*." = false := by simp
    have many : "127.0.0.1".startsWith "**." = false := by simp
    have parts : ("127.0.0.1".toList.splitOn '/').map String.ofList = ["127.0.0.1"] := by decide +kernel
    simp only [parseHostPattern,star,many,Bool.false_eq_true,↓reduceIte,parts,parseAtInput_host_loopback]
    simp [HostPattern.WF,IPPattern.WF,HostPattern.normalize,IPPattern.normalize,sampleIP]
  constructor
  · rw [run_endpoint hg hs ht hp]
    simp +decide [Checked.Scope.makeEndpoint,sampleEndpoint,samplePort,portValue,Integer64Value.toInt,
      sampleIP,sampleBound]
  · rw [run_endpoint hg hs ht hp]
    simp +decide [Checked.Scope.makeEndpoint,sampleEndpoint,portValue,Integer64Value.toInt,
      sampleIP,ScopeDelta.errorValue]

private def otherPortBound : Range := .endpoint ⟨.ip (.exact sampleIP),⟨⟨8443,by decide⟩,⟨8443,by decide⟩⟩⟩
private def otherHostBound : Range := .endpoint ⟨.name (.exact ["example","com"]),⟨⟨443,by decide⟩,⟨443,by decide⟩⟩⟩

/-- 動的な条件に入り静的な上限に入らない端点は、旧構成子で拒否する。ホストが上限に合えば上限のポート範囲の
PortOutsideScope、合わなければ OutsideScope である。 -/
example :
    run (.absolute otherPortBound)
      [.const (.string "127.0.0.1"),.const (.integer samplePort),.const (.integer samplePort),sampleRequest] =
        error (.absolute otherPortBound) (scopeError (.con "Scope.ScopeError.PortOutsideScope" []
          [.const (.integer ⟨8443,by decide⟩),.const (.integer ⟨8443,by decide⟩),.const (.integer samplePort)])) ∧
    run (.absolute otherHostBound)
      [.const (.string "127.0.0.1"),.const (.integer samplePort),.const (.integer samplePort),sampleRequest] =
        error (.absolute otherHostBound) (scopeError (.con "Scope.ScopeError.OutsideScope" []
          [.const (.string "127.0.0.1"),.const (.string (hostText sampleRequest))])) := by
  have hg : groundVal sampleRequest = true := by decide
  have hs : (parseUrlShape (urlText sampleRequest)).isSome = true := by cbv
  have ht : sampleRequest.reqTarget = some (.endpoint sampleEndpoint) := parseUrlTarget_https_loopback
  have hp : parseHostPattern "127.0.0.1" = some (.ip (.exact sampleIP)) := by
    have star : "127.0.0.1".startsWith "*." = false := by simp
    have many : "127.0.0.1".startsWith "**." = false := by simp
    have parts : ("127.0.0.1".toList.splitOn '/').map String.ofList = ["127.0.0.1"] := by decide +kernel
    simp only [parseHostPattern,star,many,Bool.false_eq_true,↓reduceIte,parts,parseAtInput_host_loopback]
    simp [HostPattern.WF,IPPattern.WF,HostPattern.normalize,IPPattern.normalize,sampleIP]
  constructor
  · rw [run_endpoint hg hs ht hp]
    simp +decide [Checked.Scope.makeEndpoint,sampleEndpoint,samplePort,portValue,Integer64Value.toInt,
      sampleIP,otherPortBound,staticError,ScopeDelta.errorValue]
    rfl
  · rw [run_endpoint hg hs ht hp]
    simp +decide [Checked.Scope.makeEndpoint,sampleEndpoint,samplePort,portValue,Integer64Value.toInt,
      sampleIP,otherHostBound,staticError,ScopeDelta.errorValue]

/-- 関門入力は URL 全体でなく、元のホスト綴りを payload に保存する。 -/
private def gateRequest (url : String) : Val := .con "Http.ClientRequest" []
  [.const (.string "GET"),.const (.string url),.list [],.bytesV [],.const (.integer ⟨1,by decide⟩)]

private def gateRun (pattern url : String) : Outcome :=
  run (.absolute .top) [.const (.string pattern),.const (.integer ⟨0,by decide⟩),
    .const (.integer ⟨65535,by decide⟩),gateRequest url]

private theorem gateGround (url : String) : groundVal (gateRequest url) = true := by rfl

/-- URL 形式不正の固定説明は、ホスト条件とポート範囲の失敗より先に返る。 -/
example : run (.absolute .top)
    [.const (.string "bad..pattern"),.const (.integer ⟨-1,by decide⟩),
      .const (.integer ⟨-1,by decide⟩),gateRequest "ftp://example.com/"] =
    error (.absolute .top) (.con "Http.RequestCheckError.InvalidUrl" []
      [.const (.string "expected an absolute ASCII http or https URL with a host, valid percent escapes, no userinfo, and a port in 0..65535")]) := by cbv

/-- URL の形は正しいがホストが不正なら、元のホストと INVALID_HOST を返す。 -/
example :
    gateRun "127.1" "http://127.1/" = error (.absolute .top)
      (scopeError (ScopeDelta.invalidTarget "127.1" text.INVALID_HOST)) ∧
    gateRun "example.com" "https://example.com./" = error (.absolute .top)
      (scopeError (ScopeDelta.invalidTarget "example.com." text.INVALID_HOST)) := by
  have hs₁ : parseUrlShape "http://127.1/" = some ("127.1",⟨80,by decide⟩) := by cbv
  have ht₁ : parseUrlTarget "http://127.1/" = none := by cbv
  have hm₁ : urlHostMapped "127.1" = false := by cbv
  have hs₂ : parseUrlShape "https://example.com./" = some ("example.com.",⟨443,by decide⟩) := by cbv
  have ht₂ : parseUrlTarget "https://example.com./" = none := parseUrlTarget_trailing_dot
  have hm₂ : urlHostMapped "example.com." = false := by cbv
  simp only [gateRun,run,gateGround,↓reduceIte]
  simp [urlText,Val.reqTarget,gateRequest,hs₁,ht₁,hm₁,hs₂,ht₂,hm₂]

/-- 射影形は IPv4 字句・16進字句のどちらも、ホスト条件を読む前に拒否する。 -/
example :
    gateRun "::/0" "http://[::ffff:127.0.0.1]:18081/" = error (.absolute .top)
      (scopeError (ScopeDelta.invalidTarget "::ffff:127.0.0.1" ScopeDelta.text.MAPPED_TARGET)) ∧
    gateRun "::/0" "http://[::FfFf:7F00:0001]:18081/" = error (.absolute .top)
      (scopeError (ScopeDelta.invalidTarget "::FfFf:7F00:0001" ScopeDelta.text.MAPPED_TARGET)) := by cbv

/-- 要求の対象と At の endpoint 入力も、同じ根で射影形を拒否する。 -/
example :
    (gateRequest "http://[::ffff:127.0.0.1]:18081/").reqTarget = none ∧
    parseAtInput .endpoint (.const (.string "http://[::ffff:127.0.0.1]:18081/")) = none ∧
    (parseHostPattern "::ffff:0.0.0.0/96").isSome = true := by cbv

/-- ホスト条件の形式不正の説明は ENDPOINT_PATTERN である。 -/
example : gateRun "bad..pattern" "http://example.com/" = error (.absolute .top)
    (scopeError (.con "Scope.ScopeError.InvalidPattern" []
      [.const (.string "bad..pattern"),.const (.string "expected a host pattern or a canonical IP address or CIDR")])) := by
  have hs : parseUrlShape "http://example.com/" = some ("example.com",⟨80,by decide⟩) := by cbv
  have ht : (parseUrlTarget "http://example.com/").isSome = true := by simpa using congrArg Option.isSome (parseUrlTarget_example false)
  have hp : parseHostPattern "bad..pattern" = none := by
    have star : "bad..pattern".startsWith "*." = false := by decide +kernel
    have many : "bad..pattern".startsWith "**." = false := by decide +kernel
    have parts : ("bad..pattern".toList.splitOn '/').map String.ofList = ["bad..pattern"] := by decide +kernel
    simp only [parseHostPattern,star,many,Bool.false_eq_true,↓reduceIte,parts,parseAtInput_host_bad_pattern]
    rfl
  cases he : parseUrlTarget "http://example.com/" with
  | none => simp [he] at ht
  | some target =>
    have hk := parseUrlTarget_kind he
    cases target <;> simp [Target.kind] at hk
    rename_i endpoint
    simp only [gateRun,run,gateGround,↓reduceIte]
    simp [urlText,Val.reqTarget,gateRequest,hs,he,hp,
      ScopeDelta.invalidPattern,ScopeDelta.errorValue,ScopeDelta.text.ENDPOINT_PATTERN]

/-- OutsideScope は URL の authority から取った、角括弧なしの綴りを保存する。 -/
example :
    gateRun "other.example" "https://example.com/" = error (.absolute .top)
      (scopeError (.con "Scope.ScopeError.OutsideScope" []
        [.const (.string "other.example"),.const (.string "example.com")])) ∧
    gateRun "127.0.0.1" "http://[::1]/" = error (.absolute .top)
      (scopeError (.con "Scope.ScopeError.OutsideScope" []
        [.const (.string "127.0.0.1"),.const (.string "::1")])) := by
  have hs₁ : parseUrlShape "https://example.com/" = some ("example.com",⟨443,by decide⟩) := by cbv
  have ht₁ : parseUrlTarget "https://example.com/" = some (.endpoint ⟨.name ["example","com"],⟨443,by decide⟩⟩) := parseUrlTarget_example true
  have hp₁ : parseHostPattern "other.example" = some (.name (.exact ["other","example"])) := by
    have star : "other.example".startsWith "*." = false := by decide +kernel
    have many : "other.example".startsWith "**." = false := by decide +kernel
    have parts : ("other.example".toList.splitOn '/').map String.ofList = ["other.example"] := by decide +kernel
    simp only [parseHostPattern,star,many,Bool.false_eq_true,↓reduceIte,parts,parseAtInput_host_other_example]
    decide +kernel
  have hs₂ : parseUrlShape "http://[::1]/" = some ("::1",⟨80,by decide⟩) := by cbv
  have ht₂ : parseUrlTarget "http://[::1]/" = some (.endpoint ⟨.ip (.v6 1 (by decide)),⟨80,by decide⟩⟩) := by cbv
  have hp₂ : parseHostPattern "127.0.0.1" = some (.ip (.exact (.v4 2130706433 (by decide)))) := by cbv
  simp only [gateRun,run,gateGround,↓reduceIte]
  simp +decide [urlText,Val.reqTarget,gateRequest,hostText,
    hs₁,ht₁,hp₁,hs₂,ht₂,hp₂,Checked.Scope.makeEndpoint,ScopeDelta.errorValue]

/-- CIDR の prefix は前置の 0 と四桁以上を拒否し、通常の prefix は受け入れる。 -/
example : parseHostPattern "10.0.0.0/08" = none ∧
    parseHostPattern "10.0.0.0/0008" = none ∧
    (parseHostPattern "10.0.0.0/8").isSome = true := by cbv

/-- 射影形の両端を拒否し、前後の通常の IPv6 は対象として受理する。 -/
example :
    parseUrlTarget "http://[::ffff:0.0.0.0]:18081/" = none ∧
    parseUrlTarget "http://[::ffff:255.255.255.255]:18081/" = none ∧
    (parseUrlTarget "http://[::fffe:ffff:ffff]/").isSome = true ∧
    (parseUrlTarget "http://[::1:0:0:0]/").isSome = true := by cbv

/-- 内部の不正な値列と未閉鎖の要求には、任意の静的添字で型付きの失敗を返す。 -/
example (r : RangeExpr) :
    run r [] = error r invalidUrl ∧
    run r [.const (.string "example.com"),.const (.integer ⟨0,by decide⟩),
      .const (.integer ⟨65535,by decide⟩),
      .con "Http.ClientRequest" [] [.var 0,.const (.string "https://example.com/"),
        .list [],.bytesV [],.const (.integer ⟨1,by decide⟩)]] = error r invalidUrl := by
  constructor <;> rfl

end
end Benitoite.Release.Refinement.RequestDelta
