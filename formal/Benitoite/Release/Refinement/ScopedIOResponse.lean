import Benitoite.Release.Refinement.ScopeResponse
import Benitoite.Release.Refinement.EffectTargets

/-! # 保持したパスと要求を使う七つの IO 応答 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace ScopedIOResponse
open Scope.Domain ScopeSignatures ScopeDeclarations

/-- IO が返す成功値の四つの型。 -/
inductive ResultKind where
  | text | bytes | unit | http
  deriving DecidableEq

def ResultKind.type : ResultKind → Ty
  | .text => .base .string
  | .bytes => .bytes
  | .unit => .base .unit
  | .http => .opaque "Http.Response" .top

def ResultKind.errorName : ResultKind → OpaqueName
  | .http => "NetworkError"
  | _ => "IOError"

def ResultKind.result (k : ResultKind) : Ty :=
  resultTy k.type (.opaque k.errorName .top)

/-- 型付けの判断を含めず、具体の返却値を構成する。 -/
inductive Payload : ResultKind → Val → Prop where
  | text (s : String) : Payload .text (.const (.string s))
  | bytes (bs : List Nat) (bounded : ∀ b ∈ bs, b ≤ 255) : Payload .bytes (.bytesV bs)
  | unit : Payload .unit (.const .unit)
  | http (id : Nat) : Payload .http (.const (.opaque "Http.Response" id))

/-- Result の成功・失敗と、処理系の停止に対応する実行時エラー。 -/
inductive Reply (k : ResultKind) : Outcome → Prop where
  | ok {v} : Payload k v → Reply k (.val (ScopeDelta.resultValue true k.type (.opaque k.errorName .top) v))
  | error (id : Nat) : Reply k (.val (ScopeDelta.resultValue false k.type (.opaque k.errorName .top)
      (.const (.opaque k.errorName id))))
  | err (reason : String) : Reply k (.err reason)

/-- 定数の許可は既存の分類の二欄で決まる。 -/
def ResultKind.Constants (k : ResultKind) (B : Builtins) : Prop :=
  (B.valKind k.errorName = none ∧ B.valContent k.errorName = none) ∧
  (k = .http → B.valKind "Http.Response" = none ∧ B.valContent "Http.Response" = none)

private theorem payload_safe {P B Ψ k v} (hc : k.Constants B) (h : Payload k v) :
    HasTypeVQ P B Ψ Qempty [] [] [] v k.type ∧ v.Ground ∧ ∀ σ, v.Adequate σ := by
  cases h with
  | text s => exact ⟨.V_Const trivial,trivial,fun _ => trivial⟩
  | bytes bs hb => exact ⟨.V_Bytes hb,trivial,fun _ => trivial⟩
  | unit => exact ⟨.V_Const trivial,trivial,fun _ => trivial⟩
  | http id => exact ⟨.V_Const (hc.2 rfl),trivial,fun _ => trivial⟩

private theorem reply_safe {P B Ψ k out ws} (hp : HasFile P)
    (hc : k.Constants B) (h : Reply k out) :
    Outcome.Typed P B Ψ out k.result ∧ AdequateResult ws out ∧ ∀ n, out ≠ .exit n := by
  have ha : Ty.Annotation P [] [] k.type := by
    cases k <;> exact ⟨trivial,trivial,trivial⟩
  have he := (ScopeDelta.checked_annotation (P := P) k.errorName (.absolute .top)).1
  have ka : Ty.HasKind P [] k.type .value := by cases k <;> trivial
  have na : k.type.norm = k.type := by cases k <;> rfl
  have oa : Ordinary k.type := by cases k <;> intro b c d hh <;> cases hh
  have oe : Ordinary (Ty.opaque k.errorName .top) := by intro b c d hh; cases hh
  cases h with
  | ok payload =>
    obtain ⟨hv,hg,had⟩ := payload_safe hc payload
    have h := ScopeDelta.result_safe (Ψ := Ψ) (ws := ws) hp true ha he ka trivial na rfl oa oe
      hv hg (by intro σ _ _; exact had σ)
    exact ⟨h.1,h.2.1,h.2.2.2⟩
  | error id =>
    have h := ScopeDelta.result_safe (Ψ := Ψ) (ws := ws) hp false ha he ka trivial na rfl oa oe
      (v := .const (.opaque k.errorName id)) (.V_Const hc.1) trivial (by intro σ _ _; trivial)
    exact ⟨h.1,h.2.1,h.2.2.2⟩
  | err reason => exact ⟨trivial,by intro σ _ _; trivial,by intro n; simp⟩

/-- 共通表の実名に対応する七つの操作。 -/
inductive Operation where
  | readText | readBytes | writeText | writeBytes | appendText | appendBytes | send
  deriving DecidableEq

def Operation.name : Operation → PrimName
  | .readText => "File.readTextIn"
  | .readBytes => "File.readBytesIn"
  | .writeText => "File.writeTextIn"
  | .writeBytes => "File.writeBytesIn"
  | .appendText => "File.appendTextIn"
  | .appendBytes => "File.appendBytesIn"
  | .send => "Http.sendIn"

def Operation.signature : Operation → PrimSig
  | .readText => ScopeSignatures.readTextIn
  | .readBytes => ScopeSignatures.readBytesIn
  | .writeText => ScopeSignatures.writeTextIn
  | .writeBytes => ScopeSignatures.writeBytesIn
  | .appendText => ScopeSignatures.appendTextIn
  | .appendBytes => ScopeSignatures.appendBytesIn
  | .send => ScopeSignatures.sendIn

def Operation.output : Operation → ResultKind
  | .readText => .text
  | .readBytes => .bytes
  | .send => .http
  | _ => .unit

def Operation.kind : Operation → Kind
  | .send => .endpoint
  | _ => .path

def Operation.params (op : Operation) (r : RangeExpr) : List Ty :=
  match op with
  | .readText | .readBytes => [.opaque "Scope.PathIn" (.fixed r)]
  | .writeText | .appendText => [.opaque "Scope.PathIn" (.fixed r),.base .string]
  | .writeBytes | .appendBytes => [.opaque "Scope.PathIn" (.fixed r),.bytes]
  | .send => [.opaque "Http.RequestIn" (.fixed r)]

private def Operation.effect (op : Operation) (r : RangeExpr) : Eff :=
  .mk (fun a => decide (a = .name (if op = .readText ∨ op = .readBytes then "File.Read"
    else if op = .send then "Http.Connect" else "File.Write") (.fixed r))) []

/-- 送信時に射影した要求全体と、同じ要求の endpoint を照合する。 -/
def RequestSent (op : Operation) (ws : List Val) (t : Target) : Prop :=
  op = .send → ∃ w req, ws = [w] ∧
    (w = .checkedRequest t req ∨ ∃ r snap, w = .checkedAt r snap t (some req)) ∧
    ModelHttp.valueRun [w] = .val req ∧
    groundVal req = true ∧ req.reqTarget = some t

/-- 観測は最初の保持対象一つ。型付けや外部状態を関係の定義に含めない。 -/
def ioResponse (b : PrimName) (ts : List Ty) (es : List Eff) (ws : List Val)
    (out : Outcome) (obs : List Target) : Prop :=
  ∃ op : Operation, b = op.name ∧ ts = [] ∧ es = [] ∧ Reply op.output out ∧
    ∃ t, (ws[0]?).bind Val.target? = some t ∧ t.kind = op.kind ∧ obs = [t] ∧ RequestSent op ws t

private theorem instantiated (op : Operation) (r : RangeExpr) :
    instantiatedTel (Tel.instR [r] op.signature.tel) [] [] =
      Ty.toTel op.signature.names (op.params r) op.output.result (op.effect r) := by
  have atoms (l : EffName) : mapRangeAtoms (rangeAt 0 [r])
      (fun a => decide (a = .name l (.rvar 0))) =
      (fun a => decide (a = .name l (.fixed r))) := by
    funext a
    simp [mapRangeAtoms,mapAtomRanges,mapIx,rangeAt,eq_comm]
  cases op <;>
    simp [Operation.signature,Operation.params,Operation.output,Operation.effect,ResultKind.result,
      ResultKind.type,ResultKind.errorName,ScopeSignatures.readTextIn,ScopeSignatures.readBytesIn,
      ScopeSignatures.writeTextIn,ScopeSignatures.writeBytesIn,
      ScopeSignatures.appendTextIn,ScopeSignatures.appendBytesIn,ScopeSignatures.sendIn,
      ioIn,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,
      Ty.rawMapRanges,Eff.rawMapRanges,atoms,Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,
      Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,Eff.norm,
      typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,mapIx,rangeAt,RangeIx.inst]

private theorem inputs {P B Ψ ts es rs ws a e} (op : Operation)
    (args : BuiltinArgs P B Ψ op.name op.signature ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ ∃ r, rs = [r] ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws (op.params r) ∧ a = op.output.result := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp (by cases op <;> exact args.admissible.typeCount)
  have es0 : es = [] := List.length_eq_zero_iff.mp (by cases op <;> exact args.admissible.rowCount)
  subst ts; subst es
  have count : rs.length = 1 := by cases op <;> exact args.ranges.1
  obtain ⟨r,rfl⟩ : ∃ r, rs = [r] := by
    cases rs with | nil => cases count | cons r rs => cases rs with
    | nil => exact ⟨r,rfl⟩
    | cons => cases count
  have values := args.arguments
  rw [instantiated] at values
  have names : NamesWF op.signature.names (op.params r) := by
    cases op <;> simp [Operation.signature,Operation.params,ScopeSignatures.readTextIn,
      ScopeSignatures.readBytesIn,ScopeSignatures.writeTextIn,ScopeSignatures.writeBytesIn,
      ScopeSignatures.appendTextIn,ScopeSignatures.appendBytesIn,ScopeSignatures.sendIn,ioIn,NamesWF]
  have all := values.toTelValues names
  have normParams : Ty.normTys (op.params r) = op.params r := by cases op <;> rfl
  have normResult : op.output.result.norm = op.output.result := by cases op <;> rfl
  exact ⟨rfl,rfl,r,rfl,by simpa only [normParams] using all.1,
    args.result.2.symm.trans (all.2.1.trans normResult)⟩

private theorem file_input {P B Ψ op r ws}
    (notSend : op ≠ Operation.send)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (h : HasTypeVsQ P B Ψ Qempty [] [] [] ws (op.params r)) :
    ∃ t, (ws[0]?).bind Val.target? = some t ∧ t.kind = op.kind ∧ RequestSent op ws t := by
  cases op <;> try contradiction
  all_goals cases h with
    | cons hv hs =>
      first
        | (cases hs with | cons content rest => cases rest)
        | cases hs
      all_goals
        obtain ⟨w,hw⟩ := ScopeDelta.path_target hv hk
        exact ⟨.path w,by simpa only [List.getElem?_cons_zero,Option.bind_some] using hw,rfl,
          by intro he; cases he⟩

private theorem file_response {P B Ψ ts es rs ws a e} (op : Operation)
    (notSend : op ≠ .send) (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path) (hc : op.output.Constants B)
    (args : BuiltinArgs P B Ψ op.name op.signature ts es rs ws a e) :
    (∀ out obs, ioResponse op.name ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (op.signature.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse op.name ts es ws out obs := by
  obtain ⟨rfl,rfl,r,_,hw,rfl⟩ := inputs op args
  obtain ⟨t,ht,hk',hsent⟩ := file_input notSend hk hw
  have shape : op.signature.shape = .single op.kind 0 := by cases op <;> rfl
  constructor
  · intro out obs ⟨other,hn,_,_,reply,t',ht',_,hobs,_⟩
    have unique : other = op := by cases other <;> cases op <;> simp_all [Operation.name]
    subst other
    have safe := reply_safe (Ψ := Ψ) (ws := ws) hp hc reply
    refine ⟨safe.1,safe.2.1,safe.2.2,?_⟩
    simp only [PrimSig.shapeAt,shape,ht',Option.isSome_some,↓reduceIte]
    exact ⟨t',ht',hobs⟩
  · exact ⟨_,[t],op,rfl,rfl,rfl,.error 0,t,ht,hk',rfl,hsent⟩

/-- 読取りの全型付き入力と、同じ保持対象を観測する全応答。 -/
theorem readTextIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (args : BuiltinArgs P B Ψ "File.readTextIn" ScopeSignatures.readTextIn ts es rs ws a e) :
    (∀ out obs, ioResponse "File.readTextIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.readTextIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "File.readTextIn" ts es ws out obs :=
  file_response .readText (by decide) hp hk ⟨hc,by intro h; cases h⟩ args

/-- バイト列の読取りも、同じ実名・全入力で存在と非 exit を持つ。 -/
theorem readBytesIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (args : BuiltinArgs P B Ψ "File.readBytesIn" ScopeSignatures.readBytesIn ts es rs ws a e) :
    (∀ out obs, ioResponse "File.readBytesIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.readBytesIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "File.readBytesIn" ts es ws out obs :=
  file_response .readBytes (by decide) hp hk ⟨hc,by intro h; cases h⟩ args

/-- 二つの実引数を持つ書込みの、全応答と存在の契約。 -/
theorem writeTextIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (args : BuiltinArgs P B Ψ "File.writeTextIn" ScopeSignatures.writeTextIn ts es rs ws a e) :
    (∀ out obs, ioResponse "File.writeTextIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.writeTextIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "File.writeTextIn" ts es ws out obs :=
  file_response .writeText (by decide) hp hk ⟨hc,by intro h; cases h⟩ args

/-- 二つの実引数を持つ書込みの、全応答と存在の契約。 -/
theorem writeBytesIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (args : BuiltinArgs P B Ψ "File.writeBytesIn" ScopeSignatures.writeBytesIn ts es rs ws a e) :
    (∀ out obs, ioResponse "File.writeBytesIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.writeBytesIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "File.writeBytesIn" ts es ws out obs :=
  file_response .writeBytes (by decide) hp hk ⟨hc,by intro h; cases h⟩ args

/-- 追記の独立した実名を、共有の応答と同じ保持対象へ接続する。 -/
theorem appendTextIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (args : BuiltinArgs P B Ψ "File.appendTextIn" ScopeSignatures.appendTextIn ts es rs ws a e) :
    (∀ out obs, ioResponse "File.appendTextIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.appendTextIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "File.appendTextIn" ts es ws out obs :=
  file_response .appendText (by decide) hp hk ⟨hc,by intro h; cases h⟩ args

/-- 追記の独立した実名を、共有の応答と同じ保持対象へ接続する。 -/
theorem appendBytesIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Scope.PathIn" = some .path)
    (hc : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (args : BuiltinArgs P B Ψ "File.appendBytesIn" ScopeSignatures.appendBytesIn ts es rs ws a e) :
    (∀ out obs, ioResponse "File.appendBytesIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.appendBytesIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "File.appendBytesIn" ts es ws out obs :=
  file_response .appendBytes (by decide) hp hk ⟨hc,by intro h; cases h⟩ args

/-- 型付き送信の要求全体を射影し、保持値の対象と照合する。 -/
private theorem send_input {P B Ψ r ws}
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (h : HasTypeVsQ P B Ψ Qempty [] [] [] ws (Operation.send.params r)) :
    ∃ t, (ws[0]?).bind Val.target? = some t ∧ t.kind = .endpoint ∧ RequestSent .send ws t := by
  cases h with
  | cons hv hs =>
    cases hs
    rename_i v
    obtain ⟨t,req,form,run,_,ground,target⟩ := RequestDelta.retained_request hv hk hc
    have held : v.target? = some t := by
      rcases form with rfl | ⟨s,snap,rfl⟩ <;> rfl
    exact ⟨t,held,Val.reqTarget_kind target,fun _ => ⟨v,req,rfl,form,run,ground,target⟩⟩

/-- 全要求を同じ endpoint へ送る関係の、全応答と応答存在。 -/
theorem sendIn {P B Ψ ts es rs ws a e} (hp : HasFile P)
    (hk : B.valKind "Http.RequestIn" = some .endpoint)
    (hc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (responseConst : B.valKind "Http.Response" = none ∧ B.valContent "Http.Response" = none)
    (errorConst : B.valKind "NetworkError" = none ∧ B.valContent "NetworkError" = none)
    (args : BuiltinArgs P B Ψ "Http.sendIn" ScopeSignatures.sendIn ts es rs ws a e) :
    (∀ out obs, ioResponse "Http.sendIn" ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (ScopeSignatures.sendIn.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse "Http.sendIn" ts es ws out obs := by
  obtain ⟨rfl,rfl,r,_,hw,rfl⟩ := inputs .send args
  obtain ⟨t,ht,hkind,hsent⟩ := send_input hk hc hw
  constructor
  · intro out obs ⟨op,hn,_,_,reply,t',ht',_,hobs,_⟩
    have unique : op = .send := by cases op <;> simp only [Operation.name] at hn <;> first | rfl | contradiction
    subst op
    have safe := reply_safe (Ψ := Ψ) (ws := ws) hp ⟨errorConst,fun _ => responseConst⟩ reply
    refine ⟨safe.1,safe.2.1,safe.2.2,?_⟩
    simp only [PrimSig.shapeAt,ScopeSignatures.sendIn,ioIn,ht',Option.isSome_some,↓reduceIte]
    exact ⟨t',ht',hobs⟩
  · exact ⟨_,[t],.send,rfl,rfl,rfl,.error 0,t,ht,hkind,rfl,hsent⟩

/-- 同じ送信関係から、応答によらず同じ要求の端点だけを観測する。 -/
theorem sent_request {ts es ws out obs}
    (h : ioResponse "Http.sendIn" ts es ws out obs) :
    ∃ w req t, ws = [w] ∧ ModelHttp.valueRun [w] = .val req ∧
      groundVal req = true ∧ req.reqTarget = some t ∧ w.target? = some t ∧ obs = [t] := by
  obtain ⟨op,hn,_,_,_,t,ht,_,hobs,hsent⟩ := h
  have unique : op = .send := by cases op <;> simp only [Operation.name] at hn <;> first | rfl | contradiction
  subst op
  obtain ⟨w,req,rfl,_,hr,hg,hreq⟩ := hsent rfl
  exact ⟨w,req,t,rfl,hr,hg,hreq,ht,hobs⟩

/-- 七つの実名は共通表の同じ署名を引く。 -/
theorem Operation.lookup (op : Operation) : entries.lookup op.name = some op.signature := by
  cases op <;> rfl

private theorem lookup_operation {b sg} (hs : entries.lookup b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit) :
    ∃ op : Operation, b = op.name ∧ sg = op.signature := by
  have hm := ScopeSignatures.lookup_mem hs
  simp only [entries,List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at hm
  rcases hm with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  all_goals solve
    | (cases kind with | inl h => cases h | inr h => cases h)
    | exact ⟨.readText,rfl,rfl⟩
    | exact ⟨.readBytes,rfl,rfl⟩
    | exact ⟨.writeText,rfl,rfl⟩
    | exact ⟨.writeBytes,rfl,rfl⟩
    | exact ⟨.appendText,rfl,rfl⟩
    | exact ⟨.appendBytes,rfl,rfl⟩
    | exact ⟨.send,rfl,rfl⟩

/-- 任意の P・B の元の全 BuiltinArgs を、七つの実 IO 関係へ渡す。 -/
theorem response {P B Ψ b sg ts es rs ws a e} (hp : HasFile P)
    (hs : entries.lookup b = some sg) (kind : sg.kind = .io ∨ sg.kind = .exit)
    (pk : B.valKind "Scope.PathIn" = some .path)
    (rk : B.valKind "Http.RequestIn" = some .endpoint)
    (rc : B.valContent "Http.RequestIn" = some clientRequestTy)
    (ioError : B.valKind "IOError" = none ∧ B.valContent "IOError" = none)
    (httpResponse : B.valKind "Http.Response" = none ∧ B.valContent "Http.Response" = none)
    (networkError : B.valKind "NetworkError" = none ∧ B.valContent "NetworkError" = none)
    (args : BuiltinArgs P B Ψ b sg ts es rs ws a e) :
    (∀ out obs, ioResponse b ts es ws out obs →
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ n, out ≠ .exit n) ∧
      Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs) ∧
    ∃ out obs, ioResponse b ts es ws out obs := by
  obtain ⟨op,rfl,rfl⟩ := lookup_operation hs kind
  cases op
  · exact readTextIn hp pk ioError args
  · exact readBytesIn hp pk ioError args
  · exact writeTextIn hp pk ioError args
  · exact writeBytesIn hp pk ioError args
  · exact appendTextIn hp pk ioError args
  · exact appendBytesIn hp pk ioError args
  · exact sendIn hp rk rc httpResponse networkError args

/-- 同じ署名 lookup と全応答で、対象のない Top への fallback を使わない。 -/
theorem targets {b sg ts es ws out obs} (hs : entries.lookup b = some sg)
    (hr : ioResponse b ts es ws out obs) :
    Scope.Signature.ShapeTargets Val.target? (sg.shapeAt ws) ws obs := by
  obtain ⟨op,rfl,_,_,_,t,ht,_,hobs,_⟩ := hr
  have eq := Option.some.inj (hs.symm.trans op.lookup)
  subst sg
  have shape : op.signature.shape = .single op.kind 0 := by cases op <;> rfl
  simp only [PrimSig.shapeAt,shape,ht,Option.isSome_some,↓reduceIte]
  exact ⟨t,ht,hobs⟩

/-- 共通表の IO 応答は、全入力で対象一致を満たす。 -/
theorem targetAgreement (P : Program)
    (delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome) :
    (builtins delta ioResponse).TargetAgreement P := by
  constructor
  intro Ψ b sg ts es rs ws a e out obs hs _ _ hr
  obtain ⟨_,_,_,hr⟩ := hr
  exact targets hs hr

/-- 同じ応答の全観測が、同じ σ で具体化した効果の上限に属する。 -/
theorem obs_allowed {P delta Ψ b sg ts es rs ws a e out obs σ}
    (hp : HasHttp P) (hs : (builtins delta ioResponse).sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P (builtins delta ioResponse) Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : (builtins delta ioResponse).ioResponse b ts es ws out obs) :
    ∃ l, sg.opEff = some l ∧ ∀ t ∈ obs, Eff.Allows σ (builtins delta ioResponse).effKind e l t :=
  Builtins.TargetAgreement.obs_allowed (ScopeSignatures.io_op hs kind)
    (targetAgreement P delta) hs kind (ScopeSignatures.sig_scoped hp hs).namesWF args had hr

/-- 七行の全応答で、観測対象・引数・範囲所属・効果の許容が一致する。 -/
theorem target_member {P delta Ψ b sg ts es rs ws a e out obs σ}
    (hp : HasHttp P) (hs : (builtins delta ioResponse).sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P (builtins delta ioResponse) Ψ b sg ts es rs ws a e)
    (had : ∀ w ∈ ws, w.Adequate σ)
    (hr : (builtins delta ioResponse).ioResponse b ts es ws out obs) :
    ∃ k r t l, sg.shape = .single k 0 ∧ rs = [r] ∧ obs = [t] ∧
      (ws[0]?).bind Val.target? = some t ∧ r.Mem σ k t ∧
      sg.shapeAt ws = .single k 0 ∧ sg.opEff = some l ∧
      Eff.Allows σ (builtins delta ioResponse).effKind e l t := by
  obtain ⟨op,hb,hsg⟩ := lookup_operation hs kind
  have shape : sg.shape = .single op.kind 0 := by rw [hsg]; cases op <;> rfl
  have names := (ScopeSignatures.sig_scoped hp hs).namesWF
  obtain ⟨r,t,hrr,held,member,shapeAt⟩ :=
    (ScopeSignatures.io_op hs kind).single_target shape names args had
  have agreement := (targetAgreement P delta).io_target Ψ b sg ts es rs ws a e out obs hs kind args hr
  rw [shapeAt] at agreement
  obtain ⟨other,hother,hobs⟩ := agreement
  have eq : other = t := Option.some.inj (hother.symm.trans held)
  subst other
  obtain ⟨l,hl,allowed⟩ := obs_allowed hp hs kind args had hr
  exact ⟨op.kind,r,t,l,shape,hrr,hobs,held,member,shapeAt,hl,allowed t (by simp [hobs])⟩

/-- 全七行の型と適格性は、同じ表の応答関係から得る。 -/
theorem io_typed {P delta Ψ b sg ts es rs ws a e out obs} (hp : HasFile P)
    (hs : (builtins delta ioResponse).sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P (builtins delta ioResponse) Ψ b sg ts es rs ws a e)
    (hr : (builtins delta ioResponse).ioResponse b ts es ws out obs) :
    Outcome.Typed P (builtins delta ioResponse) Ψ out a ∧ AdequateResult ws out := by
  obtain ⟨_,_,_,hr⟩ := hr
  have h := (response hp hs kind rfl rfl rfl ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ args).1 out obs hr
  exact ⟨h.1,h.2.1⟩

/-- IO の存在は Result.Error から構成し、成功応答を要求しない。 -/
theorem io_exists {P delta Ψ b sg ts es rs ws a e} (hp : HasFile P)
    (hs : (builtins delta ioResponse).sig b = some sg)
    (kind : sg.kind = .io ∨ sg.kind = .exit)
    (args : BuiltinArgs P (builtins delta ioResponse) Ψ b sg ts es rs ws a e) :
    ∃ out obs, (builtins delta ioResponse).ioResponse b ts es ws out obs := by
  obtain ⟨out,obs,hr⟩ := (response hp hs kind rfl rfl rfl ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ ⟨rfl,rfl⟩ args).2
  exact ⟨out,obs,sg,hs,kind,hr⟩

/-- 七行はすべて IO であり、実行時エラーも exit に変わらない。 -/
theorem io_kind {delta b sg ts es ws out obs}
    (hs : (builtins delta ioResponse).sig b = some sg)
    (hr : (builtins delta ioResponse).ioResponse b ts es ws out obs) :
    sg.kind = .io ∧ ∀ n, out ≠ .exit n := by
  obtain ⟨other,ho,kind,op,hn,_,_,reply,_⟩ := hr
  have eq := Option.some.inj (hs.symm.trans ho)
  subst other
  have lookup := op.lookup
  rw [← hn] at lookup
  cases Option.some.inj (hs.symm.trans lookup)
  refine ⟨by cases op <;> rfl,?_⟩
  cases reply <;> intro n <;> simp

/-- 六純粋行と七 IO 行を同じ応答条件へ構成する。 -/
theorem responseAssumptions {P} (hp : HasHttp P) :
    (builtins ScopeResponse.delta ioResponse).ResponseAssumptions P where
  delta_typed := fun _ _ _ _ _ _ _ _ _ hs kind args => ScopeResponse.delta_typed hp hs kind args
  io_typed := fun _ _ _ _ _ _ _ _ _ _ _ hs kind args hr => io_typed hp.file hs kind args hr
  io_kind := fun _ _ _ _ _ _ _ _ _ _ _ hs _ hr => Or.inl (io_kind hs hr)
  io_exists := fun _ _ _ _ _ _ _ _ _ hs kind args => io_exists hp.file hs kind args

end ScopedIOResponse
end
end Benitoite.Release.Refinement
