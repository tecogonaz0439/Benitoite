import Benitoite.Release.Refinement.StandardSignatureExamples

namespace Benitoite.Release.Refinement.StandardArithmeticResponse
open Benitoite.Interval StandardScalar

private def unarySig (k : IntKind) (name : String) : PrimSig :=
  ⟨[],0,[name],[embedTy k.type],embedTy k.type,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private def binarySig (k right : IntKind) (leftName rightName : String) : PrimSig :=
  ⟨[],0,[leftName,rightName],[embedTy k.type,embedTy right.type],embedTy k.type,
    Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩

private theorem integer_shape {P B Ψ v} (k : IntKind)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (embedTy k.type)) :
    ∃ n : IntegerValue k, v = .const (embedConst (IntegerValue.toConst k n)) := by
  cases k <;> obtain ⟨c,rfl,hc,ht⟩ := h.canonical_scalar rfl
  all_goals cases c <;> cases ht
  all_goals first | exact ⟨_,rfl⟩ | exact ⟨⟨_,hc⟩,rfl⟩

private theorem done_bind (k : IntKind) (value : Val) :
    Tel.bind (Tel.argumentsEnv value) (.done (embedTy k.type) Eff.empty) =
      .done (embedTy k.type) Eff.empty := by
  cases k <;> simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
    Tel.argumentsEnv,Ty.normTys,valEnv,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,
    rowFails,rawBindTys,embedTy,IntKind.type]

private theorem param_bind (k right : IntKind) (value : Val) (name : String) :
    Tel.bind (Tel.argumentsEnv value)
      (.param name (embedTy right.type) (.done (embedTy k.type) Eff.empty)) =
      .param name (embedTy right.type) (.done (embedTy k.type) Eff.empty) := by
  cases k <;> cases right <;> simp [Tel.bind,Tel.rawBind,Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,
    Tel.argumentsEnv,Ty.normTys,valEnv,Eff.norm,Eff.empty,substAtoms_nil,instAtoms_nil,
    rowFails,rawBindTys,embedTy,IntKind.type]

private theorem unary_instantiated (k : IntKind) (name : String) :
    instantiatedTel (Tel.instR [] (unarySig k name).tel) [] [] =
      .param name (embedTy k.type) (.done (embedTy k.type) Eff.empty) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases k <;> simp [emptyRange,unarySig,embedTy,IntKind.type,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

private theorem binary_instantiated (k right : IntKind) (leftName rightName : String) :
    instantiatedTel (Tel.instR [] (binarySig k right leftName rightName).tel) [] [] =
      .param leftName (embedTy k.type) (.param rightName (embedTy right.type)
        (.done (embedTy k.type) Eff.empty)) := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases k <;> cases right <;> simp [emptyRange,binarySig,embedTy,IntKind.type,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
    Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,Eff.rawMapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails]

private theorem unary_arguments {P B Ψ ts es rs ws a e} (k : IntKind) (b name : String)
    (args : BuiltinArgs P B Ψ b (unarySig k name) ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = embedTy k.type ∧ e = Eff.empty ∧
    ∃ value : IntegerValue k, ws = [.const (embedConst (IntegerValue.toConst k value))] := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [unary_instantiated] at values
  cases values with
  | param _ hv rest =>
    obtain ⟨value,rfl⟩ := integer_shape k hv
    rw [done_bind] at rest
    cases rest
    exact ⟨rfl,rfl,rfl,rfl,rfl,value,rfl⟩

private theorem binary_arguments {P B Ψ ts es rs ws a e} (k right : IntKind)
    (b leftName rightName : String)
    (args : BuiltinArgs P B Ψ b (binarySig k right leftName rightName) ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = embedTy k.type ∧ e = Eff.empty ∧
    ∃ left : IntegerValue k, ∃ value : IntegerValue right,
      ws = [.const (embedConst (IntegerValue.toConst k left)),
        .const (embedConst (IntegerValue.toConst right value))] := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have values := args.arguments
  rw [binary_instantiated] at values
  cases values with
  | param _ hl rest =>
    obtain ⟨left,rfl⟩ := integer_shape k hl
    rw [param_bind] at rest
    cases rest with
    | param _ hr done =>
      obtain ⟨value,rfl⟩ := integer_shape right hr
      rw [done_bind] at done
      cases done
      exact ⟨rfl,rfl,rfl,rfl,rfl,left,value,rfl⟩

private theorem constant_response {P B Ψ} (k : IntKind) (value : IntegerValue k) (ws : List Val)
    (typed : HasTypeVQ P B Ψ Qempty [] [] []
      (.const (embedConst (IntegerValue.toConst k value))) (embedTy k.type)) :
    Outcome.Typed P B Ψ (.val (.const (embedConst (IntegerValue.toConst k value)))) (embedTy k.type) ∧
      AdequateResult ws (.val (.const (embedConst (IntegerValue.toConst k value)))) ∧
      (∀ i, Outcome.val (.const (embedConst (IntegerValue.toConst k value))) ≠ .exit i) := by
  refine ⟨⟨typed,?_⟩,?_,by intro i; simp⟩
  · cases k <;> trivial
  · intro σ _ _; cases k <;> trivial

private theorem checked_response {P B Ψ} (k : IntKind) (n : Int) (ws : List Val) :
    Outcome.Typed P B Ψ (integerOutcome (integerChecked k n)) (embedTy k.type) ∧
      AdequateResult ws (integerOutcome (integerChecked k n)) ∧
      (∀ i, integerOutcome (integerChecked k n) ≠ .exit i) := by
  rcases integerChecked_typed P B Ψ k n with err | ⟨value,_,reply,typed⟩
  · rw [err]; exact ⟨by trivial,by intro σ _ _; trivial,by intro i; simp⟩
  · rw [reply]; exact constant_response k value ws typed

private theorem checked_math (k : IntKind) (n : Int) :
    (integerOutcome (integerChecked k n) = .err "IntegerOverflow" ↔ n < k.min ∨ k.max < n) ∧
    integerOutcome (integerChecked k n) ≠ .err "DivisionByZero" ∧
    (∀ value, integerOutcome (integerChecked k n) = .val value →
      ∃ target : IntegerValue k, value = .const (embedConst (IntegerValue.toConst k target)) ∧ target.toInt = n) := by
  cases converted : integerConvert k n with
  | none =>
    have outside := (integerConvert_none k n).mp converted
    simp only [integerChecked,converted,integerOutcome]
    exact ⟨by simp [outside],by simp,by intro value bad; cases bad⟩
  | some target =>
    have number := (integerConvert_some k n target).mp converted
    have bounds := target.toInt_bounds
    have inside : ¬ (n < k.min ∨ k.max < n) := by omega
    simp only [integerChecked,converted,integerOutcome_normal]
    refine ⟨by simp [inside],by simp,?_⟩
    intro value same
    exact ⟨target,(Outcome.val.inj same).symm,number⟩


inductive API where
  | add | subtract | multiply | negate
  deriving DecidableEq

def API.name (k : IntKind) (api : API) : PrimName :=
  "%" ++ integerModule k ++ match api with
  | .add => ".add" | .subtract => ".subtract" | .multiply => ".multiply" | .negate => ".negate"

def API.signature (k : IntKind) : API → PrimSig
  | .negate => unarySig k "value" | _ => binarySig k k "left" "right"

def API.available (k : IntKind) (api : API) : Prop := api = .negate → k.min < 0

def API.number (api : API) (left right : Int) : Int := match api with
  | .add => left + right | .subtract => left - right | .multiply => left * right | .negate => -left

private theorem binary_same (k : IntKind) (op : WidthBinary) (left right : IntegerValue k)
    (supported : op = .add ∨ op = .sub ∨ op = .mul) :
    integerBinaryDelta k op left right = integerOutcome (integerChecked k
      (match op with | .add => left.toInt + right.toInt | .sub => left.toInt - right.toInt | _ => left.toInt * right.toInt)) := by
  rcases supported with rfl | rfl | rfl
  all_goals simp only [integerBinaryDelta,WidthBinary.apply,IntKind.checkedAdd,IntKind.checkedSub,
    IntKind.checkedMul,integerChecked,integerConvert]
  all_goals split <;> rfl

private theorem negate_same (k : IntKind) (signed : k.min < 0) (value : IntegerValue k) :
    integerNegDelta k signed value = integerOutcome (integerChecked k (-value.toInt)) := by
  simp only [integerNegDelta,IntKind.checkedNeg,integerChecked,integerConvert]
  split <;> rfl

/-- 実left/right又はvalueの全引数を、七幅の同じ算術δへ接続する。 -/
theorem response_math {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P B Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    ∃ left right : IntegerValue k,
      ws = (if api = .negate then [.const (embedConst (IntegerValue.toConst k left))]
        else [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))]) ∧
      ∃ out, integerDelta (API.name k api) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = integerOutcome (integerChecked k (api.number left.toInt right.toInt)) ∧
        (out = .err "IntegerOverflow" ↔ api.number left.toInt right.toInt < k.min ∨ k.max < api.number left.toInt right.toInt) ∧
        (∀ value, out = .val value → ∃ target : IntegerValue k,
          value = .const (embedConst (IntegerValue.toConst k target)) ∧ target.toInt = api.number left.toInt right.toInt) := by
  cases api with
  | add =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "left" "right" args
    have named := integerDelta_binary k .add left right (Or.inl rfl)
    have same := binary_same k .add left right (Or.inl rfl)
    refine ⟨left,right,rfl,integerOutcome (integerChecked k (left.toInt+right.toInt)),?_,?_,?_,?_,rfl,?_⟩
    · exact named.trans (congrArg some same)
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ _).2.1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).2.2
    · exact ⟨(checked_math k _).1,(checked_math k _).2.2⟩
  | subtract =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "left" "right" args
    have named := integerDelta_binary k .sub left right (Or.inr (Or.inl rfl))
    have same := binary_same k .sub left right (Or.inr (Or.inl rfl))
    refine ⟨left,right,rfl,integerOutcome (integerChecked k (left.toInt-right.toInt)),?_,?_,?_,?_,rfl,?_⟩
    · exact named.trans (congrArg some same)
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ _).2.1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).2.2
    · exact ⟨(checked_math k _).1,(checked_math k _).2.2⟩
  | multiply =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "left" "right" args
    have named := integerDelta_binary k .mul left right (Or.inr (Or.inr rfl))
    have same := binary_same k .mul left right (Or.inr (Or.inr rfl))
    refine ⟨left,right,rfl,integerOutcome (integerChecked k (left.toInt*right.toInt)),?_,?_,?_,?_,rfl,?_⟩
    · exact named.trans (congrArg some same)
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ _).2.1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).2.2
    · exact ⟨(checked_math k _).1,(checked_math k _).2.2⟩
  | negate =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,rfl⟩ := unary_arguments k _ "value" args
    have named := integerDelta_negate k (available rfl) left
    have same := negate_same k (available rfl) left
    refine ⟨left,left,rfl,integerOutcome (integerChecked k (-left.toInt)),?_,?_,?_,?_,rfl,?_⟩
    · exact named.trans (congrArg some same)
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ _).2.1
    · exact (checked_response (P := P) (B := B) (Ψ := Ψ) k _ []).2.2
    · exact ⟨(checked_math k _).1,(checked_math k _).2.2⟩

private def kinds : List IntKind :=
  [.integer8,.integer16,.integer32,.integer64,.unsignedInteger16,.unsignedInteger32,.unsignedInteger64]

private def apis (k : IntKind) : List API := [.add,.subtract,.multiply] ++ if k.min < 0 then [.negate] else []

def lookup (b : PrimName) : Option PrimSig :=
  kinds.findSome? fun k => (apis k).findSome? fun api =>
    if b = API.name k api then some (API.signature k api) else none

theorem lookup_name (k : IntKind) (api : API) (available : API.available k api) :
    lookup (API.name k api) = some (API.signature k api) := by
  cases k <;> cases api <;> simp_all [lookup,kinds,apis,API.name,API.available,
    integerModule,IntKind.min,Benitoite.Release.min64,List.findSome?]

def table (base : Builtins) : Builtins := {base with sig := lookup,delta := integerDelta}

theorem table_response {P base Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P (table base) Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    (table base).sig (API.name k api) = some (API.signature k api) ∧
    ∃ out, (table base).delta (API.name k api) ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨left,right,_,out,delta,typed,adequate,nonexit,_⟩ := response_math k api available args
  exact ⟨lookup_name k api available,out,delta,typed,adequate,nonexit⟩

example {P base Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P (table base) Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :=
  response_math k api available args
example {P base Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P (table base) Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :=
  table_response k api available args

-- 原始演算子の登録スキーマとの全欄対応。
-- %Integer.add: registered INTEGER/Add
example : (StandardArithmeticResponse.API.signature .integer64 .add) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .integer,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer64 .add = "%Integer.add" := ⟨rfl,rfl⟩

-- %Integer.subtract: registered INTEGER/Sub
example : (StandardArithmeticResponse.API.signature .integer64 .subtract) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .integer,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer64 .subtract = "%Integer.subtract" := ⟨rfl,rfl⟩

-- %Integer.multiply: registered INTEGER/Mul
example : (StandardArithmeticResponse.API.signature .integer64 .multiply) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .integer,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer64 .multiply = "%Integer.multiply" := ⟨rfl,rfl⟩

-- %Integer.negate: registered INTEGER/Neg
example : (StandardArithmeticResponse.API.signature .integer64 .negate) = (⟨[],0,["value"],[(.base .integer)],.base .integer,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer64 .negate = "%Integer.negate" := ⟨rfl,rfl⟩

-- %Integer8.add: registered INTEGER8/Add
example : (StandardArithmeticResponse.API.signature .integer8 .add) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .integer8,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer8 .add = "%Integer8.add" := ⟨rfl,rfl⟩

-- %Integer8.subtract: registered INTEGER8/Sub
example : (StandardArithmeticResponse.API.signature .integer8 .subtract) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .integer8,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer8 .subtract = "%Integer8.subtract" := ⟨rfl,rfl⟩

-- %Integer8.multiply: registered INTEGER8/Mul
example : (StandardArithmeticResponse.API.signature .integer8 .multiply) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .integer8,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer8 .multiply = "%Integer8.multiply" := ⟨rfl,rfl⟩

-- %Integer8.negate: registered INTEGER8/Neg
example : (StandardArithmeticResponse.API.signature .integer8 .negate) = (⟨[],0,["value"],[(.base .integer8)],.base .integer8,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer8 .negate = "%Integer8.negate" := ⟨rfl,rfl⟩

-- %Integer16.add: registered INTEGER16/Add
example : (StandardArithmeticResponse.API.signature .integer16 .add) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .integer16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer16 .add = "%Integer16.add" := ⟨rfl,rfl⟩

-- %Integer16.subtract: registered INTEGER16/Sub
example : (StandardArithmeticResponse.API.signature .integer16 .subtract) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .integer16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer16 .subtract = "%Integer16.subtract" := ⟨rfl,rfl⟩

-- %Integer16.multiply: registered INTEGER16/Mul
example : (StandardArithmeticResponse.API.signature .integer16 .multiply) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .integer16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer16 .multiply = "%Integer16.multiply" := ⟨rfl,rfl⟩

-- %Integer16.negate: registered INTEGER16/Neg
example : (StandardArithmeticResponse.API.signature .integer16 .negate) = (⟨[],0,["value"],[(.base .integer16)],.base .integer16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer16 .negate = "%Integer16.negate" := ⟨rfl,rfl⟩

-- %Integer32.add: registered INTEGER32/Add
example : (StandardArithmeticResponse.API.signature .integer32 .add) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .integer32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer32 .add = "%Integer32.add" := ⟨rfl,rfl⟩

-- %Integer32.subtract: registered INTEGER32/Sub
example : (StandardArithmeticResponse.API.signature .integer32 .subtract) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .integer32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer32 .subtract = "%Integer32.subtract" := ⟨rfl,rfl⟩

-- %Integer32.multiply: registered INTEGER32/Mul
example : (StandardArithmeticResponse.API.signature .integer32 .multiply) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .integer32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer32 .multiply = "%Integer32.multiply" := ⟨rfl,rfl⟩

-- %Integer32.negate: registered INTEGER32/Neg
example : (StandardArithmeticResponse.API.signature .integer32 .negate) = (⟨[],0,["value"],[(.base .integer32)],.base .integer32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .integer32 .negate = "%Integer32.negate" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.add: registered UNSIGNED_INTEGER16/Add
example : (StandardArithmeticResponse.API.signature .unsignedInteger16 .add) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .unsignedInteger16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger16 .add = "%UnsignedInteger16.add" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.subtract: registered UNSIGNED_INTEGER16/Sub
example : (StandardArithmeticResponse.API.signature .unsignedInteger16 .subtract) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .unsignedInteger16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger16 .subtract = "%UnsignedInteger16.subtract" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.multiply: registered UNSIGNED_INTEGER16/Mul
example : (StandardArithmeticResponse.API.signature .unsignedInteger16 .multiply) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .unsignedInteger16,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger16 .multiply = "%UnsignedInteger16.multiply" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.add: registered UNSIGNED_INTEGER32/Add
example : (StandardArithmeticResponse.API.signature .unsignedInteger32 .add) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .unsignedInteger32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger32 .add = "%UnsignedInteger32.add" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.subtract: registered UNSIGNED_INTEGER32/Sub
example : (StandardArithmeticResponse.API.signature .unsignedInteger32 .subtract) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .unsignedInteger32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger32 .subtract = "%UnsignedInteger32.subtract" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.multiply: registered UNSIGNED_INTEGER32/Mul
example : (StandardArithmeticResponse.API.signature .unsignedInteger32 .multiply) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .unsignedInteger32,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger32 .multiply = "%UnsignedInteger32.multiply" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.add: registered UNSIGNED_INTEGER64/Add
example : (StandardArithmeticResponse.API.signature .unsignedInteger64 .add) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .unsignedInteger64,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger64 .add = "%UnsignedInteger64.add" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.subtract: registered UNSIGNED_INTEGER64/Sub
example : (StandardArithmeticResponse.API.signature .unsignedInteger64 .subtract) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .unsignedInteger64,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger64 .subtract = "%UnsignedInteger64.subtract" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.multiply: registered UNSIGNED_INTEGER64/Mul
example : (StandardArithmeticResponse.API.signature .unsignedInteger64 .multiply) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .unsignedInteger64,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardArithmeticResponse.API.name .unsignedInteger64 .multiply = "%UnsignedInteger64.multiply" := ⟨rfl,rfl⟩

end Benitoite.Release.Refinement.StandardArithmeticResponse
