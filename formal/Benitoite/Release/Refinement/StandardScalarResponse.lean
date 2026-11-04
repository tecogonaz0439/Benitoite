import Benitoite.Release.Refinement.StandardConversionResponse
import Benitoite.Release.Refinement.StandardFloat

namespace Benitoite.Release.Refinement.StandardScalarResponse
open StandardScalar

inductive API where
  | byteFrom | byteTo | byteAnd | byteOr | byteXor | byteNot | byteLeft | byteRight
  | characterFrom | characterTo | floatNaN | float32NaN | float32Infinite
  deriving DecidableEq

def API.name : API → PrimName
  | .byteFrom => "Byte.fromInteger" | .byteTo => "Byte.toInteger"
  | .byteAnd => "Byte.bitwiseAnd" | .byteOr => "Byte.bitwiseOr"
  | .byteXor => "Byte.bitwiseExclusiveOr" | .byteNot => "Byte.bitwiseNot"
  | .byteLeft => "Byte.shiftLeft" | .byteRight => "Byte.shiftRight"
  | .characterFrom => "Character.fromInteger" | .characterTo => "Character.toInteger"
  | .floatNaN => "Float.isNaN" | .float32NaN => "Float32.isNaN" | .float32Infinite => "Float32.isInfinite"

def API.names : API → List String
  | .byteFrom | .characterFrom => ["n"] | .byteTo => ["b"] | .characterTo => ["c"]
  | .byteAnd | .byteOr | .byteXor => ["a","b"] | .byteNot => ["a"]
  | .byteLeft | .byteRight => ["a","n"] | .floatNaN => ["x"]
  | .float32NaN | .float32Infinite => ["n"]

def API.inputs : API → List Ty
  | .byteFrom | .characterFrom => [.base .integer] | .byteTo | .byteNot => [.base .byte]
  | .characterTo => [.base .character] | .byteAnd | .byteOr | .byteXor => [.base .byte,.base .byte]
  | .byteLeft | .byteRight => [.base .byte,.base .integer]
  | .floatNaN => [.base .float] | .float32NaN | .float32Infinite => [.base .float32]

def API.result : API → Ty
  | .byteFrom => .data "Option" [.base .byte] | .characterFrom => .data "Option" [.base .character]
  | .byteTo | .characterTo => .base .integer
  | .floatNaN | .float32NaN | .float32Infinite => .base .boolean
  | _ => .base .byte

def API.signature (api : API) : PrimSig :=
  ⟨[],0,api.names,api.inputs,api.result,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

def API.delta : API → PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  | .characterFrom | .characterTo => characterDelta
  | .floatNaN => float64Delta | .float32NaN | .float32Infinite => float32Delta
  | _ => byteDelta

private theorem instantiated (api : API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.result Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases api <;> simp [emptyRange,API.signature,API.inputs,API.result,API.names,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys]

private theorem arguments {P B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = api.result ∧ e = Eff.empty ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws api.inputs := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have h := args.arguments
  rw [instantiated] at h
  have names : NamesWF api.names api.inputs := by cases api <;> simp [API.names,API.inputs,NamesWF]
  obtain ⟨values,ar,ee⟩ := h.toTelValues names
  have na : api.result.norm = api.result := by cases api <;> rfl
  have ni : Ty.normTys api.inputs = api.inputs := by cases api <;> rfl
  exact ⟨rfl,rfl,rfl,args.result.2.symm.trans (ar.trans na),args.effect.2.symm.trans ee,
    ni ▸ values⟩

private theorem scalar_shape {P B Ψ v} (base : BaseTy)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base base)) :
    ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base base := by
  exact h.canonical_scalar rfl

private theorem constant_response {P B Ψ c} (ws : List Val) (typed : HasTypeVQ P B Ψ Qempty [] [] [] (.const c) c.type) :
    Outcome.Typed P B Ψ (.val (.const c)) c.type ∧ AdequateResult ws (.val (.const c)) ∧
      (∀ i, Outcome.val (.const c) ≠ .exit i) :=
  ⟨⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp⟩

/-- 原署名十三行の全実引数から、同じByte/Character/Float部分δの応答を得る。 -/
theorem response {P B Ψ ts es rs ws a e} (api : API)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments api args
  cases api with
  | byteFrom =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .integer typed
      cases c <;> cases tag
      rename_i n
      refine ⟨.val (byteOption (byteConvert n.toInt)),rfl,?_,?_,by intro i; simp⟩
      · refine ⟨byteOption_typed P B Ψ _ someDecl noneDecl arity,?_⟩
        cases byteConvert n.toInt <;> simp [byteOption,Val.Ground,Val.ClosedAt,Val.ClosedList,Ty.WF]
      · intro σ _ _; cases byteConvert n.toInt <;> trivial
  | characterFrom =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .integer typed
      cases c <;> cases tag
      rename_i n
      let value := scalarOption .character (fun c => .const (.character c)) (characterConvert n.toInt)
      refine ⟨.val value,?_,?_,?_,by intro i; simp⟩
      · change some (Outcome.val (match characterConvert n.toInt with | some c => .con "Option.Some" [.base .character] [.const (.character c)] | none => .con "Option.None" [.base .character] [])) = some (Outcome.val value)
        cases h : characterConvert n.toInt <;> simp [value,scalarOption,h]
      · refine ⟨scalarOption_typed P B Ψ .character _ _ someDecl noneDecl arity (fun _ => .V_Const trivial),?_⟩
        cases h : characterConvert n.toInt <;> simp [value,scalarOption,h,Val.Ground,Val.ClosedAt,Val.ClosedList,Ty.WF]
      · intro σ _ _; dsimp [value]; cases characterConvert n.toInt <;> trivial
  | byteTo =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte typed
      cases c <;> cases tag
      rename_i n
      let value : UInt8 := UInt8.ofNatLT n (by change n < 256; change n ≤ 255 at hc; omega)
      have delta := (byte_result P B Ψ value).2.2
      refine ⟨.val (.const (.integer (byteToInteger value))),?_,constant_response _ (.V_Const trivial)⟩
      exact delta
  | characterTo =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .character typed
      cases c <;> cases tag
      rename_i c
      exact ⟨.val (.const (.integer (characterToInteger c))),rfl,constant_response _ (.V_Const trivial)⟩
  | byteAnd =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i right
      let v := UInt8.ofNat left &&& UInt8.ofNat right
      refine ⟨.val (.const (.byte v.toNat)),?_,constant_response _ (byte_result P B Ψ v).1⟩
      change (if left ≤ 255 ∧ right ≤ 255 then some _ else none) = some _
      exact ite_eq_left ⟨hc,hd⟩
  | byteOr =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i right
      let v := UInt8.ofNat left ||| UInt8.ofNat right
      refine ⟨.val (.const (.byte v.toNat)),?_,constant_response _ (byte_result P B Ψ v).1⟩
      change (if left ≤ 255 ∧ right ≤ 255 then some _ else none) = some _
      exact ite_eq_left ⟨hc,hd⟩
  | byteXor =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i right
      let v := UInt8.ofNat left ^^^ UInt8.ofNat right
      refine ⟨.val (.const (.byte v.toNat)),?_,constant_response _ (byte_result P B Ψ v).1⟩
      change (if left ≤ 255 ∧ right ≤ 255 then some _ else none) = some _
      exact ite_eq_left ⟨hc,hd⟩
  | byteNot =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte typed
      cases c <;> cases tag
      rename_i n
      let v := ~~~UInt8.ofNat n
      refine ⟨.val (.const (.byte v.toNat)),?_,constant_response _ (byte_result P B Ψ v).1⟩
      change (if n ≤ 255 then some _ else none) = some _
      exact ite_eq_left hc
  | byteLeft =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i byte
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .integer hr
      cases c <;> cases tag
      rename_i count
      change byte ≤ 255 at hc
      by_cases valid : 0 ≤ count.toInt ∧ count.toInt ≤ 7
      · let v := UInt8.ofNat byte <<< UInt8.ofNat count.toInt.toNat
        refine ⟨.val (.const (.byte v.toNat)),?_,constant_response _ (byte_result P B Ψ v).1⟩
        change (if byte ≤ 255 then (if 0 ≤ count.toInt ∧ count.toInt ≤ 7 then some _ else _) else none) = some _
        rw [ite_eq_left hc,ite_eq_left valid]
      · refine ⟨.err "ArgumentOutOfDomain",?_,by trivial,by intro σ _ _; trivial,by intro i; simp⟩
        change (if byte ≤ 255 then (if 0 ≤ count.toInt ∧ count.toInt ≤ 7 then some _ else _) else none) = some _
        rw [ite_eq_left hc,ite_eq_right valid]; rfl
  | byteRight =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i byte
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .integer hr
      cases c <;> cases tag
      rename_i count
      change byte ≤ 255 at hc
      by_cases valid : 0 ≤ count.toInt ∧ count.toInt ≤ 7
      · let v := UInt8.ofNat byte >>> UInt8.ofNat count.toInt.toNat
        refine ⟨.val (.const (.byte v.toNat)),?_,constant_response _ (byte_result P B Ψ v).1⟩
        change (if byte ≤ 255 then (if 0 ≤ count.toInt ∧ count.toInt ≤ 7 then some _ else _) else none) = some _
        rw [ite_eq_left hc,ite_eq_left valid]
      · refine ⟨.err "ArgumentOutOfDomain",?_,by trivial,by intro σ _ _; trivial,by intro i; simp⟩
        change (if byte ≤ 255 then (if 0 ≤ count.toInt ∧ count.toInt ≤ 7 then some _ else _) else none) = some _
        rw [ite_eq_left hc,ite_eq_right valid]; rfl
  | floatNaN =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float typed
      cases c <;> cases tag
      rename_i bits
      exact ⟨.val (.const (.boolean (ieeeClass 52 11 bits.toNat .nan))),rfl,constant_response _ (.V_Const trivial)⟩
  | float32NaN =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float32 typed
      cases c <;> cases tag
      rename_i bits
      exact ⟨.val (.const (.boolean (ieeeClass 23 8 bits.toNat .nan))),rfl,constant_response _ (.V_Const trivial)⟩
  | float32Infinite =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float32 typed
      cases c <;> cases tag
      rename_i bits
      exact ⟨.val (.const (.boolean ((ieeeClass 23 8 bits.toNat .positiveInfinity || ieeeClass 23 8 bits.toNat .negativeInfinity)))),rfl,constant_response _ (.V_Const trivial)⟩

private def apis : List API := [.byteFrom,.byteTo,.byteAnd,.byteOr,.byteXor,.byteNot,.byteLeft,.byteRight,
  .characterFrom,.characterTo,.floatNaN,.float32NaN,.float32Infinite]

def lookup (b : PrimName) : Option PrimSig :=
  apis.findSome? fun api => if b = api.name then some api.signature else none

theorem lookup_name (api : API) : lookup api.name = some api.signature := by
  cases api <;> simp [lookup,apis,API.name,List.findSome?]

def table (base : Builtins) : Builtins :=
  {base with sig := lookup,delta := fun b ts es rs ws =>
    if b.startsWith "Byte." then byteDelta b ts es rs ws
    else if b.startsWith "Character." then characterDelta b ts es rs ws
    else if b.startsWith "Float32." then float32Delta b ts es rs ws
    else float64Delta b ts es rs ws}

theorem table_response {P base Ψ ts es rs ws a e} (api : API)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P (table base) Ψ api.name api.signature ts es rs ws a e) :
    (table base).sig api.name = some api.signature ∧
    ∃ out, (table base).delta api.name ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  refine ⟨lookup_name api,?_⟩
  obtain ⟨out,delta,rest⟩ := response api someDecl noneDecl arity args
  refine ⟨out,?_,rest⟩
  cases api <;> simpa [table,API.name,API.delta] using delta

example {base Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ api.name api.signature ts es rs ws a e) :
    (table base).sig api.name = some api.signature ∧
    ∃ out, (table base).delta api.name ts es rs ws = some out ∧
      Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  table_response api rfl rfl StandardConversionResponse.option_arity args

/-- Byte変換の同じ実入力・実応答でSomeの同値/域内とNoneの域外を読む。 -/
theorem byteFrom_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program B Ψ API.byteFrom.name API.byteFrom.signature ts es rs ws a e) :
    ∃ source : Benitoite.Release.Integer64Value, ws = [.const (.integer source)] ∧
      ∃ out, API.byteFrom.delta API.byteFrom.name ts es rs ws = some out ∧
        Outcome.Typed StandardCollectionModel.program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (byteOption (byteConvert source.toInt)) ∧
        (∀ target : UInt8, byteConvert source.toInt = some target ↔ (target.toNat : Int) = source.toInt) ∧
        (∀ target : UInt8, byteConvert source.toInt = some target → (target.toNat : Int) = source.toInt ∧ target.toNat ≤ 255) ∧
        (byteConvert source.toInt = none ↔ source.toInt < 0 ∨ 255 < source.toInt) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .byteFrom rfl rfl StandardConversionResponse.option_arity args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .byteFrom args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .integer sourceTyped
    cases c <;> cases tag
    rename_i source
    have same : out = .val (byteOption (byteConvert source.toInt)) := (Option.some.inj delta).symm
    refine ⟨source,rfl,out,delta,typed,adequate,nonexit,same,
      fun target => byteConvert_some source.toInt target,?_,byteConvert_none source.toInt⟩
    intro target converted
    exact ⟨(byteConvert_some source.toInt target).mp converted,by have := target.toNat_lt; omega⟩

/-- Character変換の同じ応答でscalarのSomeとsurrogate等のNoneを読む。 -/
theorem characterFrom_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program B Ψ API.characterFrom.name API.characterFrom.signature ts es rs ws a e) :
    ∃ source : Benitoite.Release.Integer64Value, ws = [.const (.integer source)] ∧
      ∃ out, API.characterFrom.delta API.characterFrom.name ts es rs ws = some out ∧
        Outcome.Typed StandardCollectionModel.program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (scalarOption .character (fun c => .const (.character c)) (characterConvert source.toInt)) ∧
        (∀ target : Char, characterConvert source.toInt = some target ↔ (target.toNat : Int) = source.toInt) ∧
        (∀ target : Char, characterConvert source.toInt = some target → (target.toNat : Int) = source.toInt ∧
          (target.toNat < 0xd800 ∨ (0xdfff < target.toNat ∧ target.toNat < 0x110000))) ∧
        (characterConvert source.toInt = none ↔ source.toInt < 0 ∨
          (0xd800 ≤ source.toInt ∧ source.toInt ≤ 0xdfff) ∨ 0x110000 ≤ source.toInt) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .characterFrom rfl rfl StandardConversionResponse.option_arity args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .characterFrom args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .integer sourceTyped
    cases c <;> cases tag
    rename_i source
    have expected : API.characterFrom.delta API.characterFrom.name [] [] [] [.const (.integer source)] =
        some (.val (scalarOption .character (fun c => .const (.character c)) (characterConvert source.toInt))) := by
      change some (Outcome.val (match characterConvert source.toInt with
        | some c => .con "Option.Some" [.base .character] [.const (.character c)]
        | none => .con "Option.None" [.base .character] [])) = _
      cases characterConvert source.toInt <;> simp [scalarOption]
    have same := Option.some.inj (delta.symm.trans expected)
    refine ⟨source,rfl,out,delta,typed,adequate,nonexit,same,
      fun target => characterConvert_some source.toInt target,?_,characterConvert_none source.toInt⟩
    intro target converted
    exact ⟨(characterConvert_some source.toInt target).mp converted,character_scalar target⟩

/-- Byte射影は同じ入力の0〜255の数をIntegerへ全域で写す。 -/
theorem byteTo_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program B Ψ API.byteTo.name API.byteTo.signature ts es rs ws a e) :
    ∃ source : UInt8, ws = [.const (.byte source.toNat)] ∧
      ∃ out, API.byteTo.delta API.byteTo.name ts es rs ws = some out ∧
        Outcome.Typed StandardCollectionModel.program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (.const (.integer (byteToInteger source))) ∧
        (byteToInteger source).toInt = (source.toNat : Int) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .byteTo rfl rfl StandardConversionResponse.option_arity args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .byteTo args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte sourceTyped
    cases c <;> cases tag
    rename_i n
    let source : UInt8 := UInt8.ofNatLT n (by change n < 256; change n ≤ 255 at hc; omega)
    have expected := (byte_result StandardCollectionModel.program B Ψ source).2.2
    refine ⟨source,rfl,out,delta,typed,adequate,nonexit,?_,rfl⟩
    exact Option.some.inj (delta.symm.trans expected)

/-- Characterのcodeを同じ実応答のInteger値へ保持する。 -/
theorem characterTo_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program B Ψ API.characterTo.name API.characterTo.signature ts es rs ws a e) :
    ∃ source : Char, ws = [.const (.character source)] ∧
      ∃ out, API.characterTo.delta API.characterTo.name ts es rs ws = some out ∧
        Outcome.Typed StandardCollectionModel.program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (.const (.integer (characterToInteger source))) ∧
        (characterToInteger source).toInt = (source.toNat : Int) ∧
        (source.toNat < 0xd800 ∨ (0xdfff < source.toNat ∧ source.toNat < 0x110000)) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .characterTo rfl rfl StandardConversionResponse.option_arity args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .characterTo args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .character sourceTyped
    cases c <;> cases tag
    rename_i source
    exact ⟨source,rfl,out,delta,typed,adequate,nonexit,(Option.some.inj delta).symm,rfl,character_scalar source⟩

example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ API.byteFrom.name API.byteFrom.signature ts es rs ws a e) := byteFrom_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ API.characterFrom.name API.characterFrom.signature ts es rs ws a e) := characterFrom_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ API.byteTo.name API.byteTo.signature ts es rs ws a e) := byteTo_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ API.characterTo.name API.characterTo.signature ts es rs ws a e) := characterTo_math args

def API.isByteBits : API → Bool
  | .byteAnd | .byteOr | .byteXor | .byteNot | .byteLeft | .byteRight => true | _ => false

def ByteBitsRelation : API → List Val → Outcome → Prop
  | .byteAnd,[.const (.byte a),.const (.byte b)],.val (.const (.byte n)) => n = (UInt8.ofNat a &&& UInt8.ofNat b).toNat
  | .byteOr,[.const (.byte a),.const (.byte b)],.val (.const (.byte n)) => n = (UInt8.ofNat a ||| UInt8.ofNat b).toNat
  | .byteXor,[.const (.byte a),.const (.byte b)],.val (.const (.byte n)) => n = (UInt8.ofNat a ^^^ UInt8.ofNat b).toNat
  | .byteNot,[.const (.byte a)],.val (.const (.byte n)) => n = (~~~UInt8.ofNat a).toNat
  | .byteLeft,[.const (.byte a),.const (.integer count)],.val (.const (.byte n)) =>
      (0 ≤ count.toInt ∧ count.toInt ≤ 7) ∧ n = (UInt8.ofNat a <<< UInt8.ofNat count.toInt.toNat).toNat
  | .byteRight,[.const (.byte a),.const (.integer count)],.val (.const (.byte n)) =>
      (0 ≤ count.toInt ∧ count.toInt ≤ 7) ∧ n = (UInt8.ofNat a >>> UInt8.ofNat count.toInt.toNat).toNat
  | .byteLeft,[_ ,.const (.integer count)],.err "ArgumentOutOfDomain"
  | .byteRight,[_ ,.const (.integer count)],.err "ArgumentOutOfDomain" => count.toInt < 0 ∨ 7 < count.toInt
  | _,_,_ => False

theorem byte_bits_relation {P B Ψ ts es rs ws a e out} (api : API) (supported : api.isByteBits = true)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e)
    (delta : api.delta api.name ts es rs ws = some out) : ByteBitsRelation api ws out := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments api args
  cases api with
  | byteFrom | byteTo | characterFrom | characterTo | floatNaN | float32NaN | float32Infinite => cases supported
  | byteAnd =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i right
      change (if left ≤ 255 ∧ right ≤ 255 then some _ else none) = some out at delta
      rw [ite_eq_left (show left ≤ 255 ∧ right ≤ 255 from ⟨hc,hd⟩)] at delta
      have same : out = .val (.const (.byte (UInt8.ofNat left &&& UInt8.ofNat right).toNat)) := (Option.some.inj delta).symm
      rw [same]; rfl
  | byteOr =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i right
      change (if left ≤ 255 ∧ right ≤ 255 then some _ else none) = some out at delta
      rw [ite_eq_left (show left ≤ 255 ∧ right ≤ 255 from ⟨hc,hd⟩)] at delta
      have same : out = .val (.const (.byte (UInt8.ofNat left ||| UInt8.ofNat right).toNat)) := (Option.some.inj delta).symm
      rw [same]; rfl
  | byteXor =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i right
      change (if left ≤ 255 ∧ right ≤ 255 then some _ else none) = some out at delta
      rw [ite_eq_left (show left ≤ 255 ∧ right ≤ 255 from ⟨hc,hd⟩)] at delta
      have same : out = .val (.const (.byte (UInt8.ofNat left ^^^ UInt8.ofNat right).toNat)) := (Option.some.inj delta).symm
      rw [same]; rfl
  | byteNot =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte typed
      cases c <;> cases tag
      rename_i left
      change (if left ≤ 255 then some _ else none) = some out at delta
      rw [ite_eq_left (show left ≤ 255 from hc)] at delta
      have same : out = .val (.const (.byte (~~~UInt8.ofNat left).toNat)) := (Option.some.inj delta).symm
      rw [same]; rfl
  | byteLeft =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .integer hr
      cases c <;> cases tag
      rename_i count
      change left ≤ 255 at hc
      change (if left ≤ 255 then (if 0 ≤ count.toInt ∧ count.toInt ≤ 7 then some _ else _) else none) = some out at delta
      rw [ite_eq_left hc] at delta
      by_cases valid : 0 ≤ count.toInt ∧ count.toInt ≤ 7
      · rw [ite_eq_left valid] at delta
        have same : out = .val (.const (.byte (UInt8.ofNat left <<< UInt8.ofNat count.toInt.toNat).toNat)) := (Option.some.inj delta).symm
        rw [same]; exact ⟨valid,rfl⟩
      · rw [ite_eq_right valid] at delta
        have same : out = .err "ArgumentOutOfDomain" := (Option.some.inj delta).symm
        rw [same]; change count.toInt < 0 ∨ 7 < count.toInt; omega
  | byteRight =>
    cases values with | cons hl rest => cases rest with | cons hr rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .integer hr
      cases c <;> cases tag
      rename_i count
      change left ≤ 255 at hc
      change (if left ≤ 255 then (if 0 ≤ count.toInt ∧ count.toInt ≤ 7 then some _ else _) else none) = some out at delta
      rw [ite_eq_left hc] at delta
      by_cases valid : 0 ≤ count.toInt ∧ count.toInt ≤ 7
      · rw [ite_eq_left valid] at delta
        have same : out = .val (.const (.byte (UInt8.ofNat left >>> UInt8.ofNat count.toInt.toNat).toNat)) := (Option.some.inj delta).symm
        rw [same]; exact ⟨valid,rfl⟩
      · rw [ite_eq_right valid] at delta
        have same : out = .err "ArgumentOutOfDomain" := (Option.some.inj delta).symm
        rw [same]; change count.toInt < 0 ∨ 7 < count.toInt; omega
theorem byte_bits_math {P B Ψ ts es rs ws a e} (api : API) (supported : api.isByteBits = true)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩) (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧ ByteBitsRelation api ws out := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response api someDecl noneDecl arity args
  exact ⟨out,delta,typed,adequate,nonexit,byte_bits_relation api supported args delta⟩

example {base Ψ ts es rs ws a e} (api : API) (supported : api.isByteBits = true)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ api.name api.signature ts es rs ws a e) :=
  byte_bits_math api supported rfl rfl StandardConversionResponse.option_arity args

def API.isFloatClass : API → Bool
  | .floatNaN | .float32NaN | .float32Infinite => true | _ => false

def FloatClassRelation (η : ObservationEnvModel) : API → List Val → Outcome → Prop
  | .floatNaN,[.const (.float64 bits)],.val (.const (.boolean value)) =>
      (Pred.floatClass .binary64 .nan (.float64 bits)).interpret η = value
  | .float32NaN,[.const (.float32 bits)],.val (.const (.boolean value)) =>
      (Pred.floatClass .binary32 .nan (.float32 bits)).interpret η = value
  | .float32Infinite,[.const (.float32 bits)],.val (.const (.boolean value)) =>
      (Pred.or (.floatClass .binary32 .positiveInfinity (.float32 bits))
        (.floatClass .binary32 .negativeInfinity (.float32 bits))).interpret η = value
  | _,_,_ => False

theorem float_class_relation {P B Ψ ts es rs ws a e out} (api : API) (supported : api.isFloatClass = true)
    (η : ObservationEnvModel)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e)
    (delta : api.delta api.name ts es rs ws = some out) : FloatClassRelation η api ws out := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments api args
  cases api with
  | byteFrom | byteTo | byteAnd | byteOr | byteXor | byteNot | byteLeft | byteRight | characterFrom | characterTo => cases supported
  | floatNaN =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float typed
      cases c <;> cases tag
      rename_i bits
      have same : out = .val (.const (.boolean (ieeeClass 52 11 bits.toNat .nan))) := (Option.some.inj delta).symm
      rw [same]
      exact (NumericContracts.float_class_exact η (.float64 bits) .nan).2 bits rfl
  | float32NaN =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float32 typed
      cases c <;> cases tag
      rename_i bits
      have same : out = .val (.const (.boolean (ieeeClass 23 8 bits.toNat .nan))) := (Option.some.inj delta).symm
      rw [same]
      exact (NumericContracts.float_class_exact η (.float32 bits) .nan).1 bits rfl
  | float32Infinite =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float32 typed
      cases c <;> cases tag
      rename_i bits
      have same : out = .val (.const (.boolean
          (ieeeClass 23 8 bits.toNat .positiveInfinity || ieeeClass 23 8 bits.toNat .negativeInfinity))) :=
        (Option.some.inj delta).symm
      rw [same]
      have positive := (NumericContracts.float_class_exact η (.float32 bits) .positiveInfinity).1 bits rfl
      have negative := (NumericContracts.float_class_exact η (.float32 bits) .negativeInfinity).1 bits rfl
      change ((Pred.floatClass .binary32 .positiveInfinity (.float32 bits)).interpret η ||
        (Pred.floatClass .binary32 .negativeInfinity (.float32 bits)).interpret η) = _
      rw [positive,negative]

theorem float_class_math {P B Ψ ts es rs ws a e} (api : API) (supported : api.isFloatClass = true)
    (η : ObservationEnvModel)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩) (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, api.delta api.name ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧ FloatClassRelation η api ws out := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response api someDecl noneDecl arity args
  exact ⟨out,delta,typed,adequate,nonexit,float_class_relation api supported η args delta⟩

example {base Ψ ts es rs ws a e} (api : API) (supported : api.isFloatClass = true) (η : ObservationEnvModel)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ api.name api.signature ts es rs ws a e) :=
  float_class_math api supported η rfl rfl StandardConversionResponse.option_arity args

end Benitoite.Release.Refinement.StandardScalarResponse
