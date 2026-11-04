import Benitoite.Release.Refinement.StandardScalarResponse
import Benitoite.Release.Refinement.StandardDecimal

namespace Benitoite.Release.Refinement.StandardDecimalResponse
open Benitoite.Interval StandardScalar

private def declarations : List StandardKeyTyping.DataDecl := [
  ⟨"Option",1,[("Option.Some",[.tvar 0]),("Option.None",[])]⟩,
  ⟨"RoundingMode",0,[("RoundingMode.HalfToEven",[]),("RoundingMode.HalfAwayFromZero",[]),
    ("RoundingMode.TowardZero",[]),("RoundingMode.TowardNegativeInfinity",[]),("RoundingMode.TowardPositiveInfinity",[])]⟩]

def program : Program := {StandardCollectionModel.program with
  cons := fun c => (declarations.flatMap StandardKeyTyping.DataDecl.entries).lookup c}

private theorem cons_member {c cd} (h : program.cons c = some cd) :
    (c,cd) ∈ declarations.flatMap StandardKeyTyping.DataDecl.entries := by
  obtain ⟨before,after,eq,_⟩ := List.lookup_eq_some_iff.mp h
  rw [eq]; exact List.mem_append_right _ (List.mem_cons_self ..)

private theorem option_arity : program.DataArity "Option" 1 := by
  refine ⟨⟨"Option.Some",_,rfl,rfl⟩,?_⟩
  intro c cd h same
  have mem := cons_member h
  change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("RoundingMode.HalfToEven",⟨"RoundingMode",0,[]⟩),("RoundingMode.HalfAwayFromZero",⟨"RoundingMode",0,[]⟩),("RoundingMode.TowardZero",⟨"RoundingMode",0,[]⟩),("RoundingMode.TowardNegativeInfinity",⟨"RoundingMode",0,[]⟩),("RoundingMode.TowardPositiveInfinity",⟨"RoundingMode",0,[]⟩)] at mem
  simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
  rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all

private theorem mode_shape {B Ψ v}
    (h : HasTypeVQ program B Ψ Qempty [] [] [] v (.data "RoundingMode" [])) :
    ∃ mode : DecimalRounding, v = .con ("RoundingMode." ++ mode.name) [] [] := by
  rcases h.canonical_data rfl with ⟨c,ts,vs,rfl⟩ | ⟨detail,rfl⟩
  · obtain ⟨cd,hc,nt,_,_,values,us,tag,_⟩ := h.inv_con rfl
    have mem := cons_member hc
    change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("RoundingMode.HalfToEven",⟨"RoundingMode",0,[]⟩),("RoundingMode.HalfAwayFromZero",⟨"RoundingMode",0,[]⟩),("RoundingMode.TowardZero",⟨"RoundingMode",0,[]⟩),("RoundingMode.TowardNegativeInfinity",⟨"RoundingMode",0,[]⟩),("RoundingMode.TowardPositiveInfinity",⟨"RoundingMode",0,[]⟩)] at mem
    simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at mem
    rcases mem with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals try { exact False.elim ((by decide : ("RoundingMode" : String) ≠ "Option") (Ty.data.inj tag).1) }
    all_goals
      have ts0 : ts = [] := List.length_eq_zero_iff.mp nt
      subst ts
      cases values
      first | exact ⟨.halfToEven,rfl⟩ | exact ⟨.halfAwayFromZero,rfl⟩ |
        exact ⟨.towardZero,rfl⟩ | exact ⟨.towardNegativeInfinity,rfl⟩ | exact ⟨.towardPositiveInfinity,rfl⟩
  · obtain ⟨shape,declared,tag⟩ := h.inv_atError rfl
    rw [declared.errorType_eq] at tag
    have wrong : ("RoundingMode" : String) = "Scope.ScopeError" := (Ty.data.inj tag).1
    exact False.elim ((by decide : ("RoundingMode" : String) ≠ "Scope.ScopeError") wrong)

inductive API where
  | round | absolute | fromInteger | toDecimal | truncate | fromDecimal
  deriving DecidableEq

def API.name : API → PrimName
  | .round => "Decimal.round" | .absolute => "Decimal.absolute" | .fromInteger => "Decimal.fromInteger"
  | .toDecimal => "UnsignedInteger64.toDecimal" | .truncate => "Decimal.truncate"
  | .fromDecimal => "UnsignedInteger64.fromDecimal"

def API.names : API → List String
  | .round => ["x","places","mode"] | .fromInteger | .toDecimal => ["n"] | _ => ["x"]

def API.inputs : API → List Ty
  | .round => [.base .decimal,.base .integer,.data "RoundingMode" []]
  | .fromInteger => [.base .integer] | .toDecimal => [.base .unsignedInteger64] | _ => [.base .decimal]

def API.result : API → Ty
  | .truncate => .data "Option" [.base .integer]
  | .fromDecimal => .data "Option" [.base .unsignedInteger64]
  | _ => .base .decimal

def API.signature (api : API) : PrimSig :=
  ⟨[],0,api.names,api.inputs,api.result,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

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


private theorem integer_option_safe (k : IntKind) (v : Option (IntegerValue k)) (ws : List Val) :
    (integerOption k v).Ground ∧ AdequateResult ws (.val (integerOption k v)) := by
  cases k <;> cases v <;> refine ⟨?_,by intro σ _ _; trivial⟩
  all_goals simp [integerOption,Val.Ground,Val.ClosedAt,Val.ClosedList,embedTy,IntKind.type,Ty.WF]

/-- 五モードを含む同じ宣言表の六実名の全型付き引数を接続する。 -/
theorem response {B Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs program B Ψ api.name api.signature ts es rs ws a e) :
    ∃ out, decimalDelta api.name ts es rs ws = some out ∧
      Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments api args
  cases api with
  | fromInteger =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .integer typed
      cases c <;> cases tag
      rename_i n
      have reply := (decimal_integer_conversions program B Ψ n ⟨0,by decide⟩).1
      exact ⟨.val (.const (.decimal n.toInt 0)),reply.1,constant_response _ reply.2⟩
  | toDecimal =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .unsignedInteger64 typed
      cases c <;> cases tag
      rename_i n
      let u : IntegerValue .unsignedInteger64 := ⟨n,hc⟩
      have reply := (decimal_integer_conversions program B Ψ ⟨0,by decide⟩ u).2
      exact ⟨.val (.const (.decimal n 0)),reply.1,constant_response _ reply.2⟩
  | absolute =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .decimal typed
      cases c <;> cases tag
      rename_i c scale
      have reply := decimalAbsolute_reply program B Ψ c scale hc
      exact ⟨.val (.const (.decimal c.natAbs scale)),reply.1,constant_response _ reply.2⟩
  | fromDecimal =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .decimal typed
      cases c <;> cases tag
      rename_i c scale
      let value := integerOption .unsignedInteger64 (decimalToUnsigned64 c scale)
      refine ⟨.val value,?_,?_,(integer_option_safe .unsignedInteger64 _ _).2,by intro i; simp⟩
      · change (if decimalRepresentable c scale then some _ else none) = some _
        exact ite_eq_left hc
      · exact ⟨integerOption_typed program B Ψ .unsignedInteger64 _ rfl rfl option_arity,
          (integer_option_safe .unsignedInteger64 _ []).1⟩
  | truncate =>
    cases values with | cons typed rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .decimal typed
      cases c <;> cases tag
      rename_i c scale
      change decimalRepresentable c scale at hc
      obtain ⟨d,_,reply⟩ := decimalTruncate_round c scale hc
      let value := integerOption .integer64 (integerConvert .integer64 d)
      refine ⟨.val value,?_,?_,(integer_option_safe .integer64 _ _).2,by intro i; simp⟩
      · change (if decimalRepresentable c scale then some (decimalTruncateReply c scale) else none) = some _
        rw [ite_eq_left hc,reply]
      · exact ⟨integerOption_typed program B Ψ .integer64 _ rfl rfl option_arity,
          (integer_option_safe .integer64 _ []).1⟩
  | round =>
    cases values with | cons hd rest => cases rest with | cons hp rest => cases rest with | cons hm rest =>
      cases rest
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .decimal hd
      cases c <;> cases tag
      rename_i c scale
      obtain ⟨p,rfl,placesOK,tag⟩ := scalar_shape .integer hp
      cases p <;> cases tag
      rename_i places
      obtain ⟨mode,rfl⟩ := mode_shape hm
      refine ⟨decimalRoundReply c scale places.toInt mode,decimalDelta_round c scale hc places mode,?_⟩
      cases normal : decimalRound c scale places.toInt mode with
      | normal d t =>
        obtain ⟨reply,typed,_⟩ := decimalRound_typed program B Ψ c scale places.toInt mode d t normal
        rw [reply]
        exact constant_response _ typed
      | invalidPlaces =>
        simp only [decimalRoundReply,normal]
        exact ⟨by trivial,by intro σ _ _; trivial,by intro i; simp⟩
      | overflow =>
        simp only [decimalRoundReply,normal]
        exact ⟨by trivial,by intro σ _ _; trivial,by intro i; simp⟩

private def apis : List API := [.round,.absolute,.fromInteger,.toDecimal,.truncate,.fromDecimal]

def lookup (b : PrimName) : Option PrimSig :=
  apis.findSome? fun api => if b = api.name then some api.signature else none

theorem lookup_name (api : API) : lookup api.name = some api.signature := by
  cases api <;> simp [lookup,apis,API.name,List.findSome?]

def table (base : Builtins) : Builtins := {base with sig := lookup,delta := decimalDelta}

theorem table_response {base Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs program (table base) Ψ api.name api.signature ts es rs ws a e) :
    (table base).sig api.name = some api.signature ∧
    ∃ out, (table base).delta api.name ts es rs ws = some out ∧
      Outcome.Typed program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  ⟨lookup_name api,response api args⟩

example {base Ψ ts es rs ws a e} (api : API)
    (args : BuiltinArgs program (table base) Ψ api.name api.signature ts es rs ws a e) :
    (table base).sig api.name = some api.signature ∧
    ∃ out, (table base).delta api.name ts es rs ws = some out ∧
      Outcome.Typed program (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  table_response api args

/-- fromFloatの原署名。解析結果はこの署名の引数に追加しない。 -/
def fromFloatSignature : PrimSig :=
  ⟨[],0,["x"],[.base .float],.data "Option" [.base .decimal],Eff.empty,
    (fun _ ts => ts = []),.pure,none,[],.untargeted⟩

/-- 外側の解析結果の再検査出口。実bitsからparsedを供給したとは結論しない。 -/
theorem fromFloat_exit {B Ψ ts es rs ws a e} (parsed : Option (Int × Nat))
    (args : BuiltinArgs program B Ψ "Decimal.fromFloat" fromFloatSignature ts es rs ws a e) :
    ∃ bits : UInt64, ts = [] ∧ es = [] ∧ rs = [] ∧ ws = [.const (.float64 bits)] ∧
      a = .data "Option" [.base .decimal] ∧ e = Eff.empty ∧
      ∃ out, decimalFromFloatDelta parsed "Decimal.fromFloat" ts es rs ws = some out ∧
        Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  have tel : instantiatedTel (Tel.instR [] fromFloatSignature.tel) [] [] =
      .param "x" (.base .float) (.done (.data "Option" [.base .decimal]) Eff.empty) := by
    have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
      funext x; cases x <;> simp [mapRangeAtoms]
    simp [emptyRange,fromFloatSignature,PrimSig.tel,signatureTel,instantiatedTel,
      Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,
      Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,
      Ty.norm,Ty.normTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]
  rw [tel] at values
  cases values with
  | param _ typed done =>
    have bind (v : Val) : Tel.bind (Tel.argumentsEnv v) (.done (.data "Option" [.base .decimal]) Eff.empty) =
      .done (.data "Option" [.base .decimal]) Eff.empty := by
      simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
        Tel.argumentsEnv,Ty.normTys,valEnv,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,
        rowFails,rawBindTys]
    rw [bind] at done
    cases done
    obtain ⟨c,rfl,hc,tag⟩ := typed.canonical_scalar rfl
    cases c <;> cases tag
    rename_i bits
    refine ⟨bits,rfl,rfl,rfl,rfl,rfl,rfl,
      .val (decimalOption (parsed.bind (fun p => decimalChecked p.1 p.2))),rfl,?_,?_,by intro i; simp⟩
    · refine ⟨decimalOption_typed program B Ψ _ rfl rfl option_arity ?_,?_⟩
      · intro c scale h
        obtain ⟨p,_,hp⟩ := Option.bind_eq_some_iff.mp h
        obtain ⟨hc,hs,hr⟩ := (decimalChecked_some p.1 c p.2 scale).mp hp
        exact hc ▸ hs ▸ hr
      · cases h : parsed.bind (fun p => decimalChecked p.1 p.2) <;>
          simp [decimalOption,Val.Ground,Val.ClosedAt,Val.ClosedList,Ty.WF]
    · intro σ _ _
      cases parsed.bind (fun p => decimalChecked p.1 p.2) <;> trivial

example {B Ψ ts es rs ws a e} (parsed : Option (Int × Nat))
    (args : BuiltinArgs program B Ψ "Decimal.fromFloat" fromFloatSignature ts es rs ws a e) :=
  fromFloat_exit parsed args

private theorem round_invalid (c : Int) (scale : Nat) (places : Int) (mode : DecimalRounding) :
    decimalRound c scale places mode = .invalidPlaces ↔ places < 0 ∨ 28 < places := by
  let p := places.toNat
  let magnitude := c.natAbs
  let rounded := if scale ≤ p then magnitude * 10^(p-scale) else
    let divisor := 10^(scale-p)
    let quotient := magnitude / divisor
    let remainder := magnitude % divisor
    quotient + if mode.increment (c < 0) quotient remainder divisor then 1 else 0
  change (if places < 0 ∨ 28 < places then DecimalRoundResult.invalidPlaces else
    if rounded ≤ 79228162514264337593543950335 then
      .normal (if c < 0 then -(rounded : Int) else rounded) p else .overflow) = .invalidPlaces ↔ _
  by_cases bad : places < 0 ∨ 28 < places
  · simp [bad]
  · by_cases bound : rounded ≤ 79228162514264337593543950335 <;> simp [bad,bound]

private theorem round_errors (c : Int) (scale : Nat) (places : Int) (mode : DecimalRounding) :
    (decimalRoundReply c scale places mode = .err "ArgumentOutOfDomain" ↔ places < 0 ∨ 28 < places) ∧
    (decimalRoundReply c scale places mode = .err "DecimalOverflow" ↔ decimalRound c scale places mode = .overflow) := by
  have invalid := round_invalid c scale places mode
  cases normal : decimalRound c scale places mode with
  | invalidPlaces => simp [decimalRoundReply,normal] at *; exact invalid
  | overflow => simp [decimalRoundReply,normal] at *; exact invalid
  | normal d t => simp [decimalRoundReply,normal] at *; exact invalid

/-- 五モードの同じ実入力・丸め・応答から正常値と二つのerrを読む。 -/
theorem round_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs program B Ψ API.round.name API.round.signature ts es rs ws a e) :
    ∃ c scale, ∃ places : Benitoite.Release.Integer64Value, ∃ mode : DecimalRounding,
      ws = [.const (.decimal c scale),.const (.integer places),.con ("RoundingMode." ++ mode.name) [] []] ∧
      decimalRepresentable c scale ∧
      ∃ out, decimalDelta API.round.name ts es rs ws = some out ∧
        Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = decimalRoundReply c scale places.toInt mode ∧
        (out = .err "ArgumentOutOfDomain" ↔ places.toInt < 0 ∨ 28 < places.toInt) ∧
        (out = .err "DecimalOverflow" ↔ decimalRound c scale places.toInt mode = .overflow) ∧
        (∀ d t, decimalRound c scale places.toInt mode = .normal d t →
          out = .val (.const (.decimal d t)) ∧ decimalRepresentable d t ∧
            (Val.const (.decimal d t)).toTerm? = some (.decimal d t)) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .round args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .round args
  cases values with | cons hd rest => cases rest with | cons hp rest => cases rest with | cons hm rest =>
    cases rest
    obtain ⟨v,rfl,hc,tag⟩ := scalar_shape .decimal hd
    cases v <;> cases tag
    rename_i c scale
    obtain ⟨v,rfl,placesOK,tag⟩ := scalar_shape .integer hp
    cases v <;> cases tag
    rename_i places
    obtain ⟨mode,rfl⟩ := mode_shape hm
    have same : out = decimalRoundReply c scale places.toInt mode :=
      Option.some.inj (delta.symm.trans (decimalDelta_round c scale hc places mode))
    refine ⟨c,scale,places,mode,rfl,hc,out,delta,typed,adequate,nonexit,same,?_,?_,?_⟩
    · rw [same]; exact (round_errors c scale places.toInt mode).1
    · rw [same]; exact (round_errors c scale places.toInt mode).2
    · intro d t normal
      rw [same]
      exact ⟨(decimalRound_typed program B Ψ c scale places.toInt mode d t normal).1,
        decimalRound_represented c scale places.toInt mode d t normal,rfl⟩

/-- TowardZeroの同じ丸め結果をIntegerのSome/Noneへ接続する。 -/
theorem truncate_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs program B Ψ API.truncate.name API.truncate.signature ts es rs ws a e) :
    ∃ c scale, ws = [.const (.decimal c scale)] ∧ decimalRepresentable c scale ∧
      ∃ d, decimalRound c scale 0 .towardZero = .normal d 0 ∧
        ∃ out, decimalDelta API.truncate.name ts es rs ws = some out ∧
          Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
          out = .val (integerOption .integer64 (integerConvert .integer64 d)) ∧
          (∀ target : IntegerValue .integer64, integerConvert .integer64 d = some target ↔ target.toInt = d) ∧
          (integerConvert .integer64 d = none ↔ d < IntKind.integer64.min ∨ IntKind.integer64.max < d) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .truncate args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .truncate args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨v,rfl,hc,tag⟩ := scalar_shape .decimal sourceTyped
    cases v <;> cases tag
    rename_i c scale
    change decimalRepresentable c scale at hc
    obtain ⟨d,normal,reply⟩ := decimalTruncate_round c scale hc
    have expected : decimalDelta API.truncate.name [] [] [] [.const (.decimal c scale)] =
        some (.val (integerOption .integer64 (integerConvert .integer64 d))) := by
      change (if decimalRepresentable c scale then some (decimalTruncateReply c scale) else none) = _
      rw [ite_eq_left hc,reply]
    exact ⟨c,scale,rfl,hc,d,normal,out,delta,typed,adequate,nonexit,
      Option.some.inj (delta.symm.trans expected),fun target => integerConvert_some .integer64 d target,
      integerConvert_none .integer64 d⟩

/-- u64変換の同じDecimal入力で整数性・同値・Noneを保持する。 -/
theorem fromDecimal_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs program B Ψ API.fromDecimal.name API.fromDecimal.signature ts es rs ws a e) :
    ∃ c scale, ws = [.const (.decimal c scale)] ∧ decimalRepresentable c scale ∧
      ∃ out, decimalDelta API.fromDecimal.name ts es rs ws = some out ∧
        Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (integerOption .unsignedInteger64 (decimalToUnsigned64 c scale)) ∧
        (∀ target : IntegerValue .unsignedInteger64, decimalToUnsigned64 c scale = some target ↔
          c.tmod (10^scale) = 0 ∧ target.toInt = c.tdiv (10^scale)) ∧
        (∀ target : IntegerValue .unsignedInteger64, decimalToUnsigned64 c scale = some target →
          c = target.toInt * 10^scale ∧ 0 ≤ target.toInt ∧ target.toInt ≤ 18446744073709551615) ∧
        (decimalToUnsigned64 c scale = none ↔ c.tmod (10^scale) ≠ 0 ∨
          c.tdiv (10^scale) < 0 ∨ 18446744073709551615 < c.tdiv (10^scale)) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .fromDecimal args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .fromDecimal args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨v,rfl,hc,tag⟩ := scalar_shape .decimal sourceTyped
    cases v <;> cases tag
    rename_i c scale
    have expected : decimalDelta API.fromDecimal.name [] [] [] [.const (.decimal c scale)] =
        some (.val (integerOption .unsignedInteger64 (decimalToUnsigned64 c scale))) := by
      change (if decimalRepresentable c scale then some _ else none) = _
      exact ite_eq_left hc
    refine ⟨c,scale,rfl,hc,out,delta,typed,adequate,nonexit,Option.some.inj (delta.symm.trans expected),
      fun target => decimalToUnsigned64_some c scale target,?_,decimalToUnsigned64_none c scale⟩
    intro target converted
    exact ⟨decimalToUnsigned64_exact c scale target converted,target.toInt_bounds⟩

example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs program (table base) Ψ API.round.name API.round.signature ts es rs ws a e) := round_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs program (table base) Ψ API.truncate.name API.truncate.signature ts es rs ws a e) := truncate_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs program (table base) Ψ API.fromDecimal.name API.fromDecimal.signature ts es rs ws a e) := fromDecimal_math args

theorem absolute_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs program B Ψ API.absolute.name API.absolute.signature ts es rs ws a e) :
    ∃ c scale, ws = [.const (.decimal c scale)] ∧ decimalRepresentable c scale ∧
      ∃ out, decimalDelta API.absolute.name ts es rs ws = some out ∧
        Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (.const (.decimal c.natAbs scale)) ∧ decimalRepresentable c.natAbs scale ∧
        0 ≤ (c.natAbs : Int) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .absolute args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .absolute args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨v,rfl,hc,tag⟩ := scalar_shape .decimal sourceTyped
    cases v <;> cases tag
    rename_i c scale
    have expected := (decimalAbsolute_reply program B Ψ c scale hc).1
    exact ⟨c,scale,rfl,hc,out,delta,typed,adequate,nonexit,
      Option.some.inj (delta.symm.trans expected),decimalAbsolute_represented c scale hc,by omega⟩

theorem fromInteger_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs program B Ψ API.fromInteger.name API.fromInteger.signature ts es rs ws a e) :
    ∃ source : Benitoite.Release.Integer64Value, ws = [.const (.integer source)] ∧
      ∃ out, decimalDelta API.fromInteger.name ts es rs ws = some out ∧
        Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (.const (.decimal source.toInt 0)) ∧ decimalRepresentable source.toInt 0 := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .fromInteger args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .fromInteger args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨v,rfl,hc,tag⟩ := scalar_shape .integer sourceTyped
    cases v <;> cases tag
    rename_i source
    have represented : decimalRepresentable source.toInt 0 := by
      have bounds := source.toInt_bounds
      simp only [Benitoite.Release.min64,Benitoite.Release.max64] at bounds
      unfold decimalRepresentable
      omega
    exact ⟨source,rfl,out,delta,typed,adequate,nonexit,(Option.some.inj delta).symm,represented⟩

theorem toDecimal_math {B Ψ ts es rs ws a e}
    (args : BuiltinArgs program B Ψ API.toDecimal.name API.toDecimal.signature ts es rs ws a e) :
    ∃ source : IntegerValue .unsignedInteger64,
      ws = [.const (.unsignedInteger64 source.toInt)] ∧
      ∃ out, decimalDelta API.toDecimal.name ts es rs ws = some out ∧
        Outcome.Typed program B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (.const (.decimal source.toInt 0)) ∧ decimalRepresentable source.toInt 0 ∧
        0 ≤ source.toInt ∧ source.toInt ≤ 18446744073709551615 := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response .toDecimal args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments .toDecimal args
  cases values with | cons sourceTyped rest =>
    cases rest
    obtain ⟨v,rfl,hc,tag⟩ := scalar_shape .unsignedInteger64 sourceTyped
    cases v <;> cases tag
    rename_i n
    let source : IntegerValue .unsignedInteger64 := ⟨n,hc⟩
    have expected := (decimal_integer_conversions program B Ψ ⟨0,by decide⟩ source).2
    have represented : decimalRepresentable source.toInt 0 := by
      have bounds := source.toInt_bounds
      change 0 ≤ source.toInt ∧ source.toInt ≤ 18446744073709551615 at bounds
      unfold decimalRepresentable
      omega
    exact ⟨source,rfl,out,delta,typed,adequate,nonexit,
      Option.some.inj (delta.symm.trans expected.1),represented,source.toInt_bounds⟩

example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs program (table base) Ψ API.absolute.name API.absolute.signature ts es rs ws a e) := absolute_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs program (table base) Ψ API.fromInteger.name API.fromInteger.signature ts es rs ws a e) := fromInteger_math args
example {base Ψ ts es rs ws a e}
    (args : BuiltinArgs program (table base) Ψ API.toDecimal.name API.toDecimal.signature ts es rs ws a e) := toDecimal_math args

end Benitoite.Release.Refinement.StandardDecimalResponse
