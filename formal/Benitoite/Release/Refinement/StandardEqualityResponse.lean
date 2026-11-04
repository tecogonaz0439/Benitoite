import Benitoite.Release.Refinement.StandardOrderResponse

namespace Benitoite.Release.Refinement.StandardEqualityResponse
open Benitoite.Interval StandardScalar

def fullSignature (sat : List TParam → Ty → TParam → Prop) : PrimSig :=
  ⟨[⟨{equality := true},.value⟩],0,["left","right"],[.tvar 0,.tvar 0],.base .boolean,Eff.empty,
    (fun C ts => ts.length = 1 ∧ ∀ (i : Nat) (t : Ty) (p : TParam),
      ts[i]? = some t → [{equality := true}][i]? = some p → sat C t p),
    .pure,none,[],.untargeted⟩

private def integerTag : Option BaseTy → Option IntKind
  | some .integer => some .integer64 | some .integer8 => some .integer8
  | some .integer16 => some .integer16 | some .integer32 => some .integer32
  | some .unsignedInteger16 => some .unsignedInteger16
  | some .unsignedInteger32 => some .unsignedInteger32
  | some .unsignedInteger64 => some .unsignedInteger64 | _ => none

private theorem integer_type_delta (base : BaseTy) (T : Ty) (equal : Bool) (ws : List Val)
    (h : scalarTypeCore T = some base) :
    integerDelta (if equal then "%eq" else "%ne") [T] [] [] ws =
      integerDelta (if equal then "%eq" else "%ne") [.base base] [] [] ws := by
  cases equal
  all_goals simp [integerDelta]
  all_goals congr 1
  all_goals change integerTag (scalarTypeCore T) = integerTag (scalarTypeCore (.base base))
  all_goals rw [h]; rfl

private theorem scalar_core : ∀ (T : Ty) (base : BaseTy),
    scalarTypeCore T = some base → T.norm.core = .base base
  | .base b,base,h => by cases Option.some.inj h; rfl
  | .refined T p,base,h => by simpa only [Ty.refined_norm_core] using scalar_core T base h
  | .opaque _ _,_,h | .data _ _,_,h | .list _,_,h | .fn _ _ _ _,_,h
  | .tvar _,_,h | .reference _,_,h | .lazy _,_,h | .cont _ _ _,_,h
  | .map _ _,_,h | .set _,_,h | .bytes,_,h | .dict _ _,_,h
  | .tapp _ _,_,h | .ctor _,_,h | .dependentFn _,_,h | .external _ _,_,h
  | .scoped _ _ _,_,h | .pathBases,_,h | .scopePattern _,_,h => by cases h

private theorem instantiated (T : Ty) (na : T.norm = T) (wa : T.WF 0 0 0) (sat) :
    instantiatedTel (Tel.instR [] (fullSignature sat).tel) [T] [] =
      Ty.toTel ["left","right"] [T,T] (.base .boolean) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  simp [fullSignature,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,
    Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,Tel.bind,Tel.rawBind,
    Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,
    na,substAtoms_nil,instAtoms_nil,rowFails,emptyRange,Ty.toTel,
    Ty.shiftV,shiftVTys,Eff.shiftV,Ty.shiftV_of_wf_zero wa]

private theorem arguments {P B Ψ ts es rs ws a e} (equal : Bool)
    (args : BuiltinArgs P B Ψ (if equal then "%eq" else "%ne") (fullSignature B.sat) ts es rs ws a e) :
    ∃ T, ts = [T] ∧ es = [] ∧ rs = [] ∧ Ty.Annotation P [] [] T ∧ T.norm = T ∧ Ordinary T ∧
      B.sat [] T.norm {equality := true} ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws [T,T] ∧ a = .base .boolean ∧ e = Eff.empty := by
  have count := args.admissible.typeCount
  change ts.length = 1 at count
  rcases ts with _ | ⟨T,ts⟩
  · cases count
  have tail : ts = [] := List.length_eq_zero_iff.mp (by simpa using count)
  subst ts
  have rows : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have ranges : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst es; subst rs
  have ha := args.signature.types T (by simp)
  have na : T.norm = T := (args.types T (by simp)).2
  have sat : B.sat [] T.norm {equality := true} := args.admissible.admits.2 0 _ _ rfl rfl
  have h := args.arguments
  rw [instantiated T na ha.wf B.sat] at h
  obtain ⟨values,ar,ee⟩ := h.toTelValues (by simp [NamesWF])
  have ni : Ty.normTys [T,T] = [T,T] := by simp [Ty.normTys,na]
  exact ⟨T,rfl,rfl,rfl,ha,na,args.admissible.typeScope T (by simp) |>.2,sat,
    ni ▸ values,args.result.2.symm.trans ar,args.effect.2.symm.trans ee⟩

private theorem type_delta (kind : StandardOrderResponse.Kind) (T : Ty) (equal : Bool) (ws : List Val)
    (h : scalarTypeCore T = some kind.base) :
    kind.delta (if equal then "%eq" else "%ne") [T] [] [] ws =
      kind.delta (if equal then "%eq" else "%ne") [.base kind.base] [] [] ws := by
  cases kind with
  | integer8 | integer16 | integer32 | integer64 | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 =>
    exact integer_type_delta _ T equal ws h
  | byte | character | float32 | float64 | decimal =>
    cases equal <;> simp [StandardOrderResponse.Kind.delta,byteDelta,characterDelta,float32Delta,float64Delta,
      decimalDelta,scalarDelta,scalarArguments,scalarTypeCore,h]

private theorem integer_shape {P B Ψ v T} (k : IntKind)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v T)
    (core : scalarTypeCore T = some (match k with
      | .integer8 => .integer8 | .integer16 => .integer16 | .integer32 => .integer32
      | .integer64 => .integer | .unsignedInteger16 => .unsignedInteger16
      | .unsignedInteger32 => .unsignedInteger32 | .unsignedInteger64 => .unsignedInteger64)) :
    ∃ n : IntegerValue k, v = .const (embedConst (IntegerValue.toConst k n)) := by
  cases k <;> obtain ⟨c,rfl,hc,ht⟩ := h.canonical_scalar (scalar_core T _ core)
  all_goals cases c <;> cases ht
  all_goals first | exact ⟨_,rfl⟩ | exact ⟨⟨_,hc⟩,rfl⟩

private theorem scalar_shape {P B Ψ v T} (base : BaseTy)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v T) (core : scalarTypeCore T = some base) :
    ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base base :=
  h.canonical_scalar (scalar_core T base core)

set_option maxHeartbeats 2000000 in
/-- Full Equality署名を保ち、scalar-domain条件の下で同じ型引数の部分δを読む。 -/
theorem response_math {P B Ψ ts es rs ws a e} (kind : StandardOrderResponse.Kind) (equal : Bool)
    (η : ObservationEnvModel)
    (args : BuiltinArgs P B Ψ (if equal then "%eq" else "%ne") (fullSignature B.sat) ts es rs ws a e)
    (scalar : ∀ T ∈ ts, scalarTypeCore T = some kind.base) :
    ∃ T, ts = [T] ∧ Ty.Annotation P [] [] T ∧ Ordinary T ∧ B.sat [] T.norm {equality := true} ∧
      ∃ out, kind.delta (if equal then "%eq" else "%ne") ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        StandardOrderResponse.Relation kind (if equal then .eq else .ne) η ws out := by
  obtain ⟨T,rfl,rfl,rfl,ha,na,ordinary,sat,values,rfl,rfl⟩ := arguments equal args
  have core := scalar T (by simp)
  refine ⟨T,rfl,ha,ordinary,sat,?_⟩
  cases values with | cons hl rest => cases rest with | cons hr rest =>
    cases rest
    cases kind with
    | integer8 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer8 hl core
      obtain ⟨right,rfl⟩ := integer_shape .integer8 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .integer8 left right equal
      have actual := type_delta .integer8 T equal
        [.const (embedConst (IntegerValue.toConst .integer8 left)),.const (embedConst (IntegerValue.toConst .integer8 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer8 left)),.const (embedConst (IntegerValue.toConst .integer8 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer8 left).2
      · exact (NumericContracts.integer_result .integer8 right).2
    | integer16 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer16 hl core
      obtain ⟨right,rfl⟩ := integer_shape .integer16 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .integer16 left right equal
      have actual := type_delta .integer16 T equal
        [.const (embedConst (IntegerValue.toConst .integer16 left)),.const (embedConst (IntegerValue.toConst .integer16 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer16 left)),.const (embedConst (IntegerValue.toConst .integer16 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer16 left).2
      · exact (NumericContracts.integer_result .integer16 right).2
    | integer32 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer32 hl core
      obtain ⟨right,rfl⟩ := integer_shape .integer32 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .integer32 left right equal
      have actual := type_delta .integer32 T equal
        [.const (embedConst (IntegerValue.toConst .integer32 left)),.const (embedConst (IntegerValue.toConst .integer32 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer32 left)),.const (embedConst (IntegerValue.toConst .integer32 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer32 left).2
      · exact (NumericContracts.integer_result .integer32 right).2
    | integer64 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer64 hl core
      obtain ⟨right,rfl⟩ := integer_shape .integer64 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .integer64 left right equal
      have actual := type_delta .integer64 T equal
        [.const (embedConst (IntegerValue.toConst .integer64 left)),.const (embedConst (IntegerValue.toConst .integer64 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer64 left)),.const (embedConst (IntegerValue.toConst .integer64 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer64 left).2
      · exact (NumericContracts.integer_result .integer64 right).2
    | unsignedInteger16 =>
      obtain ⟨left,rfl⟩ := integer_shape .unsignedInteger16 hl core
      obtain ⟨right,rfl⟩ := integer_shape .unsignedInteger16 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .unsignedInteger16 left right equal
      have actual := type_delta .unsignedInteger16 T equal
        [.const (embedConst (IntegerValue.toConst .unsignedInteger16 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger16 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .unsignedInteger16 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger16 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .unsignedInteger16 left).2
      · exact (NumericContracts.integer_result .unsignedInteger16 right).2
    | unsignedInteger32 =>
      obtain ⟨left,rfl⟩ := integer_shape .unsignedInteger32 hl core
      obtain ⟨right,rfl⟩ := integer_shape .unsignedInteger32 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .unsignedInteger32 left right equal
      have actual := type_delta .unsignedInteger32 T equal
        [.const (embedConst (IntegerValue.toConst .unsignedInteger32 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger32 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .unsignedInteger32 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger32 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .unsignedInteger32 left).2
      · exact (NumericContracts.integer_result .unsignedInteger32 right).2
    | unsignedInteger64 =>
      obtain ⟨left,rfl⟩ := integer_shape .unsignedInteger64 hl core
      obtain ⟨right,rfl⟩ := integer_shape .unsignedInteger64 hr core
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η (if equal then .eq else .ne) left.toInt right.toInt
      have named := integerDelta_equality .unsignedInteger64 left right equal
      have actual := type_delta .unsignedInteger64 T equal
        [.const (embedConst (IntegerValue.toConst .unsignedInteger64 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger64 right))] core
      refine ⟨.val (.const (.boolean value)),actual.trans (named.trans (congrArg some reply)),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .unsignedInteger64 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger64 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .unsignedInteger64 left).2
      · exact (NumericContracts.integer_result .unsignedInteger64 right).2
    | byte =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl core
      cases c <;> cases tag
      rename_i n
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr core
      cases c <;> cases tag
      rename_i m
      let left : UInt8 := UInt8.ofNatLT n (by change n < 256; change n ≤ 255 at hc; omega)
      let right : UInt8 := UInt8.ofNatLT m (by change m < 256; change m ≤ 255 at hd; omega)
      obtain ⟨value,delta,typed,fact⟩ := byte_compare P B Ψ η left right (if equal then .eq else .ne)
      have named : byteDelta (if equal then "%eq" else "%ne") [.base .byte] [] []
          [.const (.byte n),.const (.byte m)] = some (.val (.const (.boolean value))) := by
        cases equal <;> exact delta
      have actual := type_delta .byte T equal [.const (.byte n),.const (.byte m)] core
      exact ⟨.val (.const (.boolean value)),actual.trans named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.byte n),.const (.byte m),.integer n,.integer m,value,rfl,rfl,rfl,rfl,fact⟩
    | character =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .character hl core
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .character hr core
      cases c <;> cases tag
      rename_i right
      obtain ⟨value,delta,typed,fact⟩ := character_compare P B Ψ η left right (if equal then .eq else .ne)
      have named : characterDelta (if equal then "%eq" else "%ne") [.base .character] [] []
          [.const (.character left),.const (.character right)] = some (.val (.const (.boolean value))) := by
        cases equal <;> exact delta
      have actual := type_delta .character T equal [.const (.character left),.const (.character right)] core
      exact ⟨.val (.const (.boolean value)),actual.trans named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.character left),.const (.character right),.character left,.character right,value,rfl,rfl,rfl,rfl,fact⟩
    | float32 =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float32 hl core
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .float32 hr core
      cases c <;> cases tag
      rename_i right
      obtain ⟨value,delta,typed,fact⟩ := float32_compare_reply P B Ψ η left right (if equal then .eq else .ne)
      have named : float32Delta (if equal then "%eq" else "%ne") [.base .float32] [] []
          [.const (.float32 left),.const (.float32 right)] = some (.val (.const (.boolean value))) := by
        cases equal <;> exact delta
      have actual := type_delta .float32 T equal [.const (.float32 left),.const (.float32 right)] core
      exact ⟨.val (.const (.boolean value)),actual.trans named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.float32 left),.const (.float32 right),.float32 left,.float32 right,value,rfl,rfl,rfl,rfl,fact⟩
    | float64 =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float hl core
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .float hr core
      cases c <;> cases tag
      rename_i right
      obtain ⟨value,delta,typed,fact⟩ := float64_compare_reply P B Ψ η left right (if equal then .eq else .ne)
      have named : float64Delta (if equal then "%eq" else "%ne") [.base .float] [] []
          [.const (.float64 left),.const (.float64 right)] = some (.val (.const (.boolean value))) := by
        cases equal <;> exact delta
      have actual := type_delta .float64 T equal [.const (.float64 left),.const (.float64 right)] core
      exact ⟨.val (.const (.boolean value)),actual.trans named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.float64 left),.const (.float64 right),.float64 left,.float64 right,value,rfl,rfl,rfl,rfl,fact⟩
    | decimal =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .decimal hl core
      cases c <;> cases tag
      rename_i left ls
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .decimal hr core
      cases c <;> cases tag
      rename_i right rs
      obtain ⟨value,delta,typed,fact⟩ := decimal_compare_reply P B Ψ η left right ls rs hc hd (if equal then .eq else .ne)
      have named : decimalDelta (if equal then "%eq" else "%ne") [.base .decimal] [] []
          [.const (.decimal left ls),.const (.decimal right rs)] = some (.val (.const (.boolean value))) := by
        cases equal <;> exact delta
      have actual := type_delta .decimal T equal [.const (.decimal left ls),.const (.decimal right rs)] core
      exact ⟨.val (.const (.boolean value)),actual.trans named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.decimal left ls),.const (.decimal right rs),.decimal left ls,.decimal right rs,value,rfl,rfl,rfl,rfl,fact⟩

/-- Full署名は全Equality型を許す。ここに収集するδは既存scalar部分だけである。 -/
def partialScalarDelta (b : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) (ws : List Val) : Option Outcome :=
  if b = "%eq" ∨ b = "%ne" then
    match ts with
    | [T] => match scalarTypeCore T with
      | some .integer8 | some .integer16 | some .integer32 | some .integer
      | some .unsignedInteger16 | some .unsignedInteger32 | some .unsignedInteger64 => integerDelta b ts es rs ws
      | some .byte => byteDelta b ts es rs ws | some .character => characterDelta b ts es rs ws
      | some .float32 => float32Delta b ts es rs ws | some .float => float64Delta b ts es rs ws
      | some .decimal => decimalDelta b ts es rs ws | _ => none
    | _ => none
  else none

def table (base : Builtins) : Builtins :=
  {base with
    sig := fun b => if b = "%eq" ∨ b = "%ne" then some (fullSignature base.sat) else none
    delta := partialScalarDelta}

theorem table_response {P base Ψ ts es rs ws a e} (kind : StandardOrderResponse.Kind) (equal : Bool)
    (η : ObservationEnvModel)
    (args : BuiltinArgs P (table base) Ψ (if equal then "%eq" else "%ne")
      (fullSignature (table base).sat) ts es rs ws a e)
    (scalar : ∀ T ∈ ts, scalarTypeCore T = some kind.base) :
    (table base).sig (if equal then "%eq" else "%ne") = some (fullSignature (table base).sat) ∧
    ∃ T, ts = [T] ∧ Ty.Annotation P [] [] T ∧ Ordinary T ∧ (table base).sat [] T.norm {equality := true} ∧
      ∃ out, (table base).delta (if equal then "%eq" else "%ne") ts es rs ws = some out ∧
        Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        StandardOrderResponse.Relation kind (if equal then .eq else .ne) η ws out := by
  obtain ⟨T,sameT,ha,ordinary,sat,out,delta,typed,adequate,nonexit,related⟩ := response_math kind equal η args scalar
  have core := scalar T (by rw [sameT]; simp)
  refine ⟨by cases equal <;> rfl,T,sameT,ha,ordinary,sat,out,?_,typed,adequate,nonexit,related⟩
  cases kind <;> cases equal
  all_goals simpa [table,partialScalarDelta,sameT,core,StandardOrderResponse.Kind.delta,StandardOrderResponse.Kind.base] using delta

example {P base Ψ ts es rs ws a e} (kind : StandardOrderResponse.Kind) (equal : Bool)
    (η : ObservationEnvModel)
    (args : BuiltinArgs P (table base) Ψ (if equal then "%eq" else "%ne")
      (fullSignature (table base).sat) ts es rs ws a e)
    (scalar : ∀ T ∈ ts, scalarTypeCore T = some kind.base) :=
  table_response kind equal η args scalar

end Benitoite.Release.Refinement.StandardEqualityResponse
