import Benitoite.Release.Refinement.StandardIntegerAPI
import Benitoite.Release.Refinement.StandardCollectionExamples

namespace Benitoite.Release.Refinement.StandardConversionResponse
open Benitoite.Interval StandardScalar

private def inputKind (k : IntKind) (fromInteger : Bool) : IntKind :=
  if fromInteger then .integer64 else k

def name (k : IntKind) (fromInteger : Bool) : PrimName :=
  integerModule k ++ if fromInteger then ".fromInteger" else ".toInteger"

def result (k : IntKind) (fromInteger : Bool) : Ty :=
  if fromInteger then .data "Option" [embedTy k.type]
  else if k = .unsignedInteger64 then .data "Option" [.base .integer] else .base .integer

def signature (k : IntKind) (fromInteger : Bool) : PrimSig :=
  ⟨[],0,["n"],[embedTy (inputKind k fromInteger).type],result k fromInteger,
    Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private theorem integer_shape {P B Ψ v} (k : IntKind)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (embedTy k.type)) :
    ∃ n : IntegerValue k, v = .const (embedConst (IntegerValue.toConst k n)) := by
  cases k <;> obtain ⟨c,rfl,hc,ht⟩ := h.canonical_scalar rfl
  all_goals cases c <;> cases ht
  all_goals first | exact ⟨_,rfl⟩ | exact ⟨⟨_,hc⟩,rfl⟩

private theorem instantiated (k : IntKind) (fromInteger : Bool) :
    instantiatedTel (Tel.instR [] (signature k fromInteger).tel) [] [] =
      .param "n" (embedTy (inputKind k fromInteger).type) (.done (result k fromInteger) Eff.empty) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases k <;> cases fromInteger <;> simp [emptyRange,signature,inputKind,result,embedTy,IntKind.type,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

private theorem done_bind (k : IntKind) (fromInteger : Bool) (value : Val) :
    Tel.bind (Tel.argumentsEnv value) (.done (result k fromInteger) Eff.empty) =
      .done (result k fromInteger) Eff.empty := by
  cases k <;> cases fromInteger <;> simp [result,embedTy,IntKind.type,
    Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
    Tel.argumentsEnv,Ty.normTys,valEnv,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,
    rowFails,rawBindTys]

private theorem arguments {P B Ψ ts es rs ws a e} (k : IntKind) (fromInteger : Bool)
    (args : BuiltinArgs P B Ψ (name k fromInteger) (signature k fromInteger) ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = result k fromInteger ∧ e = Eff.empty ∧
    ∃ value : IntegerValue (inputKind k fromInteger),
      ws = [.const (embedConst (IntegerValue.toConst (inputKind k fromInteger) value))] := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [instantiated] at values
  cases values with
  | param _ hv rest =>
    obtain ⟨value,rfl⟩ := integer_shape (inputKind k fromInteger) hv
    rw [done_bind] at rest
    cases rest
    exact ⟨rfl,rfl,rfl,rfl,rfl,value,rfl⟩

private theorem option_safe (k : IntKind) (v : Option (IntegerValue k)) (ws : List Val) :
    (integerOption k v).Ground ∧ AdequateResult ws (.val (integerOption k v)) := by
  cases k <;> cases v <;> refine ⟨?_,by intro σ _ _; trivial⟩
  all_goals simp [integerOption,Val.Ground,Val.ClosedAt,Val.ClosedList,embedTy,IntKind.type,Ty.WF]

/-- 十二変換の全型付き入力を同じδのSome/None又は全域拡大へ接続する。 -/
theorem response {P B Ψ ts es rs ws a e} (k : IntKind) (fromInteger : Bool)
    (available : k ≠ .integer64)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩)
    (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ (name k fromInteger) (signature k fromInteger) ts es rs ws a e) :
    ∃ out, integerDelta (name k fromInteger) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,value,rfl⟩ := arguments k fromInteger args
  cases fromInteger with
  | true =>
    refine ⟨.val (integerOption k (integerConvert k value.toInt)),
      integerDelta_fromInteger k value available,?_,(option_safe k _ _).2,by intro i; simp⟩
    exact ⟨integerOption_typed P B Ψ k _ someDecl noneDecl arity,(option_safe k _ []).1⟩
  | false =>
    rw [show name k false = integerModule k ++ ".toInteger" from rfl]
    change ∃ out, integerDelta (integerModule k ++ ".toInteger") [] [] []
      [.const (embedConst (IntegerValue.toConst k value))] = some out ∧
      Outcome.Typed P B Ψ out (result k false) ∧
      AdequateResult [.const (embedConst (IntegerValue.toConst k value))] out ∧ (∀ i, out ≠ .exit i)
    rw [integerDelta_toInteger k value available]
    by_cases unsigned : k = .unsignedInteger64
    · subst k
      refine ⟨.val (integerOption .integer64 (integerConvert .integer64 value.toInt)),?_,?_,
        (option_safe .integer64 _ _).2,by intro i; simp⟩
      · simp [integerToIntegerDelta]; rfl
      · exact ⟨integerOption_typed P B Ψ .integer64 _ someDecl noneDecl arity,(option_safe .integer64 _ []).1⟩
    · obtain ⟨wide,conversion,_⟩ := integerWiden k unsigned value
      refine ⟨.val (.const (.integer wide)),?_,?_,by intro σ _ _; trivial,by intro i; simp⟩
      · simp [integerToIntegerDelta,unsigned,conversion]; rfl
      · change HasTypeVQ P B Ψ Qempty [] [] [] (.const (.integer wide)) (result k false) ∧ True
        rw [show result k false = .base .integer by simp [result,unsigned]]
        exact ⟨integer_result_typed P B Ψ Qempty [] [] [] .integer64 wide,trivial⟩

private def kinds : List IntKind :=
  [.integer8,.integer16,.integer32,.unsignedInteger16,.unsignedInteger32,.unsignedInteger64]

def lookup (b : PrimName) : Option PrimSig :=
  kinds.findSome? fun k =>
    if b = name k true then some (signature k true)
    else if b = name k false then some (signature k false) else none

theorem lookup_name (k : IntKind) (fromInteger : Bool) (available : k ≠ .integer64) :
    lookup (name k fromInteger) = some (signature k fromInteger) := by
  cases k <;> cases fromInteger <;> simp_all [lookup,kinds,name,integerModule,List.findSome?]

def table (base : Builtins) : Builtins := {base with sig := lookup,delta := integerDelta}

theorem option_arity : StandardCollectionModel.program.DataArity "Option" 1 := by
  refine ⟨⟨"Option.Some",_,rfl,rfl⟩,?_⟩
  intro c cd h same
  have mem := List.lookup_eq_some_iff.mp h
  obtain ⟨before,after,eq,_⟩ := mem
  have member : (c,cd) ∈ StandardCollectionModel.declarations.flatMap StandardKeyTyping.DataDecl.entries := by
    rw [eq]; exact List.mem_append_right _ (List.mem_cons_self ..)
  change (c,cd) ∈ [("Option.Some",⟨"Option",1,[.tvar 0]⟩),("Option.None",⟨"Option",1,[]⟩),("Pair.Pair",⟨"Pair",2,[.tvar 0,.tvar 1]⟩)] at member
  simp only [List.mem_cons,List.not_mem_nil,or_false,Prod.mk.injEq] at member
  rcases member with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ <;> simp_all

theorem table_response {base Ψ ts es rs ws a e} (k : IntKind) (fromInteger : Bool)
    (available : k ≠ .integer64)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ
      (name k fromInteger) (signature k fromInteger) ts es rs ws a e) :
    (table base).sig (name k fromInteger) = some (signature k fromInteger) ∧
    ∃ out, (table base).delta (name k fromInteger) ts es rs ws = some out ∧
      Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  ⟨lookup_name k fromInteger available,response k fromInteger available rfl rfl option_arity args⟩

example {base Ψ ts es rs ws a e} (k : IntKind) (fromInteger : Bool)
    (available : k ≠ .integer64)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ
      (name k fromInteger) (signature k fromInteger) ts es rs ws a e) :
    (table base).sig (name k fromInteger) = some (signature k fromInteger) ∧
    ∃ out, (table base).delta (name k fromInteger) ts es rs ws = some out ∧
      Outcome.Typed StandardCollectionModel.program (table base) Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  table_response k fromInteger available args

/-- 同じ実入力・実応答でSomeの同値と幅、Noneの域外を読む。 -/
theorem fromInteger_math {P B Ψ ts es rs ws a e} (k : IntKind) (available : k ≠ .integer64)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩) (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ (name k true) (signature k true) ts es rs ws a e) :
    ∃ source : IntegerValue .integer64,
      ws = [.const (.integer source)] ∧
      ∃ out, integerDelta (name k true) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = .val (integerOption k (integerConvert k source.toInt)) ∧
        (∀ target : IntegerValue k, integerConvert k source.toInt = some target ↔ target.toInt = source.toInt) ∧
        (∀ target : IntegerValue k, integerConvert k source.toInt = some target →
          target.toInt = source.toInt ∧ k.min ≤ target.toInt ∧ target.toInt ≤ k.max) ∧
        (integerConvert k source.toInt = none ↔ source.toInt < k.min ∨ k.max < source.toInt) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response k true available someDecl noneDecl arity args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,source,rfl⟩ := arguments k true args
  have reply := integerDelta_fromInteger k source available
  have eq : out = .val (integerOption k (integerConvert k source.toInt)) := Option.some.inj (delta.symm.trans reply)
  refine ⟨source,rfl,out,delta,typed,adequate,nonexit,eq,
    fun target => integerConvert_some k source.toInt target,?_,integerConvert_none k source.toInt⟩
  intro target converted
  exact ⟨(integerConvert_some k source.toInt target).mp converted,target.property⟩

/-- 同じ入力で、小幅の全域拡大とu64のOptionを区別する。 -/
theorem toInteger_math {P B Ψ ts es rs ws a e} (k : IntKind) (available : k ≠ .integer64)
    (someDecl : P.cons "Option.Some" = some ⟨"Option",1,[.tvar 0]⟩)
    (noneDecl : P.cons "Option.None" = some ⟨"Option",1,[]⟩) (arity : P.DataArity "Option" 1)
    (args : BuiltinArgs P B Ψ (name k false) (signature k false) ts es rs ws a e) :
    ∃ source : IntegerValue k, ws = [.const (embedConst (IntegerValue.toConst k source))] ∧
      ∃ out, integerDelta (name k false) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        (k = .unsignedInteger64 → out = .val (integerOption .integer64 (integerConvert .integer64 source.toInt))) ∧
        (k ≠ .unsignedInteger64 → ∃ wide : IntegerValue .integer64,
          out = .val (.const (.integer wide)) ∧ wide.toInt = source.toInt) ∧
        (∀ target : IntegerValue .integer64, integerConvert .integer64 source.toInt = some target ↔ target.toInt = source.toInt) ∧
        (integerConvert .integer64 source.toInt = none ↔
          source.toInt < IntKind.integer64.min ∨ IntKind.integer64.max < source.toInt) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response k false available someDecl noneDecl arity args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,source,rfl⟩ := arguments k false args
  have reply := integerDelta_toInteger k source available
  have actual : integerToIntegerDelta k source = some out := reply.symm.trans delta
  refine ⟨source,rfl,out,delta,typed,adequate,nonexit,?_,?_,
    fun target => integerConvert_some .integer64 source.toInt target,integerConvert_none .integer64 source.toInt⟩
  · intro unsigned
    subst k
    exact (Option.some.inj actual).symm
  · intro small
    obtain ⟨wide,conversion,same⟩ := integerWiden k small source
    refine ⟨wide,?_,same⟩
    have expected : integerToIntegerDelta k source = some (.val (.const (.integer wide))) := by
      simp [integerToIntegerDelta,small,conversion]; rfl
    exact Option.some.inj (actual.symm.trans expected)

example {base Ψ ts es rs ws a e} (k : IntKind) (available : k ≠ .integer64)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ (name k true) (signature k true) ts es rs ws a e) :=
  fromInteger_math k available rfl rfl option_arity args

example {base Ψ ts es rs ws a e} (k : IntKind) (available : k ≠ .integer64)
    (args : BuiltinArgs StandardCollectionModel.program (table base) Ψ (name k false) (signature k false) ts es rs ws a e) :=
  toInteger_math k available rfl rfl option_arity args

end Benitoite.Release.Refinement.StandardConversionResponse
