import Benitoite.Release.Refinement.StandardIntegerResponse

namespace Benitoite.Release.Refinement.StandardIntegerAPI
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

private theorem bits_response {P B Ψ} (k : IntKind) (op : IntegerBits)
    (left right : IntegerValue k) (count : Int) (ws : List Val) :
    Outcome.Typed P B Ψ (integerBitsDelta k op left right count) (embedTy k.type) ∧
      AdequateResult ws (integerBitsDelta k op left right count) ∧
      (∀ i, integerBitsDelta k op left right count ≠ .exit i) := by
  rcases integerBits_typed P B Ψ k op left right count with err | ⟨value,reply,typed⟩
  · rw [err]; exact ⟨by trivial,by intro σ _ _; trivial,by intro i; simp⟩
  · rw [reply]; exact constant_response k value ws typed


inductive API where
  | floorDivide | floorModulo | absolute
  | bitwiseAnd | bitwiseOr | bitwiseExclusiveOr | bitwiseNot
  | shiftLeft | shiftRight | shiftRightUnsigned
  deriving DecidableEq

def API.name (k : IntKind) (api : API) : PrimName :=
  integerModule k ++ match api with
  | .floorDivide => ".floorDivide" | .floorModulo => ".floorModulo" | .absolute => ".absolute"
  | .bitwiseAnd => ".bitwiseAnd" | .bitwiseOr => ".bitwiseOr"
  | .bitwiseExclusiveOr => ".bitwiseExclusiveOr" | .bitwiseNot => ".bitwiseNot"
  | .shiftLeft => ".shiftLeft" | .shiftRight => ".shiftRight" | .shiftRightUnsigned => ".shiftRightUnsigned"

def API.signature (k : IntKind) : API → PrimSig
  | .absolute => unarySig k "n"
  | .bitwiseNot => unarySig k "a"
  | .shiftLeft | .shiftRight | .shiftRightUnsigned => binarySig k .integer64 "a" "n"
  | _ => binarySig k k "a" "b"

def API.available (k : IntKind) (api : API) : Prop :=
  api = .shiftRightUnsigned → k.min < 0

private theorem floor_response {P B Ψ ts es rs ws a e} (k : IntKind) (modulo : Bool)
    (args : BuiltinArgs P B Ψ
      (integerModule k ++ if modulo then ".floorModulo" else ".floorDivide")
      (binarySig k k "a" "b") ts es rs ws a e) :
    ∃ out, integerDelta (integerModule k ++ if modulo then ".floorModulo" else ".floorDivide")
      ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧
      (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "a" "b" args
  refine ⟨integerFloorDelta k modulo left right,integerDelta_floor k modulo left right,?_⟩
  by_cases zero : right.toInt = 0
  · simp only [integerFloorDelta,ite_eq_left zero]
    exact ⟨by trivial,by intro σ _ _; trivial,by intro i; simp⟩
  · simp only [integerFloorDelta,ite_eq_right zero]
    exact checked_response k _ _

private theorem absolute_response {P B Ψ ts es rs ws a e} (k : IntKind)
    (args : BuiltinArgs P B Ψ (API.name k .absolute) (API.signature k .absolute) ts es rs ws a e) :
    ∃ out, integerDelta (API.name k .absolute) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,value,rfl⟩ := unary_arguments k _ "n" args
  exact ⟨integerAbsoluteDelta k value,integerDelta_absolute k value,checked_response k _ _⟩

private theorem binary_bits_response {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (op : IntegerBits)
    (same : api = .bitwiseAnd ∧ op = .bitwiseAnd ∨ api = .bitwiseOr ∧ op = .bitwiseOr ∨
      api = .bitwiseExclusiveOr ∧ op = .bitwiseExclusiveOr)
    (args : BuiltinArgs P B Ψ (API.name k api) (binarySig k k "a" "b") ts es rs ws a e) :
    ∃ out, integerDelta (API.name k api) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "a" "b" args
  refine ⟨integerBitsDelta k op left right 0,?_,bits_response k op left right 0 _⟩
  rcases same with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · exact integerDelta_bitwise k .bitwiseAnd left right (Or.inl rfl)
  · exact integerDelta_bitwise k .bitwiseOr left right (Or.inr (Or.inl rfl))
  · exact integerDelta_bitwise k .bitwiseExclusiveOr left right (Or.inr (Or.inr rfl))

private theorem not_response {P B Ψ ts es rs ws a e} (k : IntKind)
    (args : BuiltinArgs P B Ψ (API.name k .bitwiseNot) (API.signature k .bitwiseNot) ts es rs ws a e) :
    ∃ out, integerDelta (API.name k .bitwiseNot) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,value,rfl⟩ := unary_arguments k _ "a" args
  exact ⟨integerBitsDelta k .bitwiseNot value value 0,integerDelta_bitwiseNot k value,
    bits_response k .bitwiseNot value value 0 _⟩

private theorem shift_response {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (op : IntegerBits)
    (same : api = .shiftLeft ∧ op = .shiftLeft ∨ api = .shiftRight ∧ op = .shiftRight ∨
      api = .shiftRightUnsigned ∧ op = .shiftRightUnsigned)
    (available : API.available k api)
    (args : BuiltinArgs P B Ψ (API.name k api) (binarySig k .integer64 "a" "n") ts es rs ws a e) :
    ∃ out, integerDelta (API.name k api) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,value,count,rfl⟩ := binary_arguments k .integer64 _ "a" "n" args
  refine ⟨integerBitsDelta k op value value count.toInt,?_,bits_response k op value value count.toInt _⟩
  rcases same with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
  · exact integerDelta_shift k .shiftLeft value count (Or.inl rfl) (by intro h; cases h)
  · exact integerDelta_shift k .shiftRight value count (Or.inr (Or.inl rfl)) (by intro h; cases h)
  · exact integerDelta_shift k .shiftRightUnsigned value count (Or.inr (Or.inr rfl)) (by intro _; exact available rfl)

/-- 実名六十七行の全引数から同じ部分δの全応答契約を得る。 -/
theorem response {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P B Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    ∃ out, integerDelta (API.name k api) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) := by
  cases api with
  | floorDivide => exact floor_response k false args
  | floorModulo => exact floor_response k true args
  | absolute => exact absolute_response k args
  | bitwiseAnd => exact binary_bits_response k .bitwiseAnd .bitwiseAnd (Or.inl ⟨rfl,rfl⟩) args
  | bitwiseOr => exact binary_bits_response k .bitwiseOr .bitwiseOr (Or.inr (Or.inl ⟨rfl,rfl⟩)) args
  | bitwiseExclusiveOr => exact binary_bits_response k .bitwiseExclusiveOr .bitwiseExclusiveOr (Or.inr (Or.inr ⟨rfl,rfl⟩)) args
  | bitwiseNot => exact not_response k args
  | shiftLeft => exact shift_response k .shiftLeft .shiftLeft (Or.inl ⟨rfl,rfl⟩) available args
  | shiftRight => exact shift_response k .shiftRight .shiftRight (Or.inr (Or.inl ⟨rfl,rfl⟩)) available args
  | shiftRightUnsigned => exact shift_response k .shiftRightUnsigned .shiftRightUnsigned (Or.inr (Or.inr ⟨rfl,rfl⟩)) available args

private def kinds : List IntKind :=
  [.integer8,.integer16,.integer32,.integer64,.unsignedInteger16,.unsignedInteger32,.unsignedInteger64]

private def apis (k : IntKind) : List API :=
  [.floorDivide,.floorModulo,.absolute,.bitwiseAnd,.bitwiseOr,.bitwiseExclusiveOr,
    .bitwiseNot,.shiftLeft,.shiftRight] ++ if k.min < 0 then [.shiftRightUnsigned] else []

def lookup (name : PrimName) : Option PrimSig :=
  kinds.findSome? fun k => (apis k).findSome? fun api =>
    if name = API.name k api then some (API.signature k api) else none

set_option maxHeartbeats 2000000 in
theorem lookup_name (k : IntKind) (api : API) (available : API.available k api) :
    lookup (API.name k api) = some (API.signature k api) := by
  cases k <;> cases api <;> simp_all [lookup,kinds,apis,API.name,API.signature,API.available,
    integerModule,IntKind.min,Benitoite.Release.min64,List.findSome?]

def table (base : Builtins) : Builtins := {base with sig := lookup,delta := integerDelta}

theorem table_response {P base Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P (table base) Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    (table base).sig (API.name k api) = some (API.signature k api) ∧
    ∃ out, (table base).delta (API.name k api) ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  ⟨lookup_name k api available,response k api available args⟩

example {P base Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (available : API.available k api)
    (args : BuiltinArgs P (table base) Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    (table base).sig (API.name k api) = some (API.signature k api) ∧
    ∃ out, (table base).delta (API.name k api) ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) :=
  table_response k api available args

/-- 同じabsoluteの正常応答から数学値・非負性・幅を読む。 -/
theorem absolute_normal_math {P B Ψ ts es rs ws a e value} (k : IntKind)
    (args : BuiltinArgs P B Ψ (API.name k .absolute) (API.signature k .absolute) ts es rs ws a e)
    (normal : integerDelta (API.name k .absolute) ts es rs ws = some (.val value)) :
    ∃ source target : IntegerValue k,
      ws = [.const (embedConst (IntegerValue.toConst k source))] ∧
      value = .const (embedConst (IntegerValue.toConst k target)) ∧
      target.toInt = (source.toInt.natAbs : Int) ∧ 0 ≤ target.toInt ∧
      k.min ≤ target.toInt ∧ target.toInt ≤ k.max ∧
      (k.min = 0 → target.toInt = source.toInt) := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,source,rfl⟩ := unary_arguments k _ "n" args
  have same : integerAbsoluteDelta k source = .val value :=
    Option.some.inj ((integerDelta_absolute k source).symm.trans normal)
  cases converted : integerConvert k (source.toInt.natAbs : Int) with
  | none => simp [integerAbsoluteDelta,integerChecked,converted,integerOutcome] at same
  | some target =>
    have reply : integerAbsoluteDelta k source = .val (.const (embedConst (IntegerValue.toConst k target))) := by
      simp only [integerAbsoluteDelta,integerChecked,converted,integerOutcome_normal]
    have eq := Outcome.val.inj (same.symm.trans reply)
    have number := (integerConvert_some k (source.toInt.natAbs : Int) target).mp converted
    refine ⟨source,target,rfl,eq,number,by omega,target.property.1,target.property.2,?_⟩
    intro unsigned
    have nonnegative : 0 ≤ source.toInt := by have := source.toInt_bounds; omega
    omega

example {P base Ψ ts es rs ws a e value} (k : IntKind)
    (args : BuiltinArgs P (table base) Ψ (API.name k .absolute) (API.signature k .absolute) ts es rs ws a e)
    (normal : (table base).delta (API.name k .absolute) ts es rs ws = some (.val value)) :=
  absolute_normal_math k args normal

/-- 既存床演算が使う商・剰余と符号補正の同じ数学値。 -/
def floorNumber (modulo : Bool) (left right : Int) : Int :=
  let quotient := left.tdiv right
  let remainder := left.tmod right
  if modulo then
    if remainder ≠ 0 ∧ ((remainder < 0) ≠ (right < 0)) then remainder + right else remainder
  else if remainder ≠ 0 ∧ ((left < 0) ≠ (right < 0)) then quotient - 1 else quotient

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

private theorem floor_characterization (k : IntKind) (modulo : Bool) (left right : IntegerValue k) :
    (integerFloorDelta k modulo left right = .err "DivisionByZero" ↔ right.toInt = 0) ∧
    (integerFloorDelta k modulo left right = .err "IntegerOverflow" ↔ right.toInt ≠ 0 ∧
      (floorNumber modulo left.toInt right.toInt < k.min ∨ k.max < floorNumber modulo left.toInt right.toInt)) ∧
    (∀ value, integerFloorDelta k modulo left right = .val value → ∃ target : IntegerValue k,
      value = .const (embedConst (IntegerValue.toConst k target)) ∧
      target.toInt = floorNumber modulo left.toInt right.toInt) := by
  by_cases zero : right.toInt = 0
  · simp [integerFloorDelta,zero]
  · simp only [integerFloorDelta,ite_eq_right zero]
    have checked := checked_math k (floorNumber modulo left.toInt right.toInt)
    exact ⟨⟨fun impossible => False.elim (checked.2.1 impossible),
      fun impossible => False.elim (zero impossible)⟩,checked.1.trans (by simp [zero]),checked.2.2⟩

/-- 七幅の床商/床剰余の同じ実入力・応答を、zeroと結果幅の検査へ結ぶ。 -/
theorem floor_math {P B Ψ ts es rs ws a e} (k : IntKind) (modulo : Bool)
    (args : BuiltinArgs P B Ψ (API.name k (if modulo then .floorModulo else .floorDivide))
      (API.signature k (if modulo then .floorModulo else .floorDivide)) ts es rs ws a e) :
    ∃ left right : IntegerValue k,
      ws = [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))] ∧
      ∃ out, integerDelta (API.name k (if modulo then .floorModulo else .floorDivide)) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        (out = .err "DivisionByZero" ↔ right.toInt = 0) ∧
        (out = .err "IntegerOverflow" ↔ right.toInt ≠ 0 ∧
          (floorNumber modulo left.toInt right.toInt < k.min ∨ k.max < floorNumber modulo left.toInt right.toInt)) ∧
        (∀ value, out = .val value → ∃ target : IntegerValue k,
          value = .const (embedConst (IntegerValue.toConst k target)) ∧
          target.toInt = floorNumber modulo left.toInt right.toInt) := by
  have signature_eq : API.signature k (if modulo then .floorModulo else .floorDivide) = binarySig k k "a" "b" := by
    cases modulo <;> rfl
  rw [signature_eq] at args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "a" "b" args
  have named : API.name k (if modulo then .floorModulo else .floorDivide) =
      integerModule k ++ if modulo then ".floorModulo" else ".floorDivide" := by cases modulo <;> rfl
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := floor_response k modulo (by simpa [named] using args)
  have same : out = integerFloorDelta k modulo left right :=
    Option.some.inj (delta.symm.trans (integerDelta_floor k modulo left right))
  refine ⟨left,right,rfl,out,?_,typed,adequate,nonexit,?_⟩
  · simpa [named] using delta
  · rw [same]; exact floor_characterization k modulo left right

example {P base Ψ ts es rs ws a e} (k : IntKind) (modulo : Bool)
    (args : BuiltinArgs P (table base) Ψ (API.name k (if modulo then .floorModulo else .floorDivide))
      (API.signature k (if modulo then .floorModulo else .floorDivide)) ts es rs ws a e) :=
  floor_math k modulo args

private theorem modulo_bounds (k : IntKind) (left right : IntegerValue k) (nonzero : right.toInt ≠ 0) :
    k.min ≤ floorNumber true left.toInt right.toInt ∧ floorNumber true left.toInt right.toInt ≤ k.max := by
  have zero_bounds : k.min ≤ 0 ∧ 0 ≤ k.max := by cases k <;> decide
  have right_bounds := right.toInt_bounds
  by_cases positive : 0 < right.toInt
  · have lo := Int.lt_tmod_of_pos left.toInt positive
    have hi := Int.tmod_lt_of_pos left.toInt positive
    have notnegative : ¬ right.toInt < 0 := by omega
    by_cases negative : left.toInt.tmod right.toInt < 0
    · have remainder_nonzero : left.toInt.tmod right.toInt ≠ 0 := by omega
      simp only [floorNumber,ite_true]
      rw [ite_eq_left (by simp [negative,notnegative,remainder_nonzero])]
      omega
    · simp [floorNumber,negative,notnegative]
      omega
  · have negative : right.toInt < 0 := by omega
    have positive_neg : 0 < -right.toInt := by omega
    have lo := Int.lt_tmod_of_pos left.toInt positive_neg
    have hi := Int.tmod_lt_of_pos left.toInt positive_neg
    simp only [Int.tmod_neg,Int.neg_neg] at lo hi
    by_cases remainder_positive : 0 < left.toInt.tmod right.toInt
    · have remainder_nonzero : left.toInt.tmod right.toInt ≠ 0 := by omega
      have notnegative : ¬left.toInt.tmod right.toInt < 0 := by omega
      simp only [floorNumber,ite_true]
      rw [ite_eq_left (by simp [negative,notnegative,remainder_nonzero])]
      omega
    · by_cases remainder_negative : left.toInt.tmod right.toInt < 0
      · simp [floorNumber,remainder_negative,negative]; omega
      · have remainder_zero : left.toInt.tmod right.toInt = 0 := by omega
        simp [floorNumber,remainder_zero,zero_bounds]

/-- 床剰余は商の表現外を理由とするoverflow応答を返さない。 -/
theorem modulo_no_overflow {P B Ψ ts es rs ws a e} (k : IntKind)
    (args : BuiltinArgs P B Ψ (API.name k .floorModulo) (API.signature k .floorModulo) ts es rs ws a e) :
    ∃ out, integerDelta (API.name k .floorModulo) ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
      out ≠ .err "IntegerOverflow" := by
  obtain ⟨left,right,_,out,delta,typed,adequate,nonexit,_,overflow,_⟩ := floor_math k true args
  refine ⟨out,delta,typed,adequate,nonexit,?_⟩
  intro impossible
  obtain ⟨nonzero,outside⟩ := overflow.mp impossible
  have bounds := modulo_bounds k left right nonzero
  omega

example {P base Ψ ts es rs ws a e} (k : IntKind)
    (args : BuiltinArgs P (table base) Ψ (API.name k .floorModulo) (API.signature k .floorModulo) ts es rs ws a e) :=
  modulo_no_overflow k args

private theorem absolute_overflow (k : IntKind) (source : IntegerValue k) :
    integerAbsoluteDelta k source = .err "IntegerOverflow" ↔ k.min < 0 ∧ source.toInt = k.min := by
  unfold integerAbsoluteDelta
  rw [(checked_math k (source.toInt.natAbs : Int)).1]
  have bounds := source.toInt_bounds
  by_cases nonnegative : 0 ≤ source.toInt
  · rw [Int.natAbs_of_nonneg nonnegative]
    cases k <;> simp only [IntKind.min,IntKind.max,Benitoite.Release.min64,Benitoite.Release.max64] at * <;> omega
  · rw [Int.ofNat_natAbs_of_nonpos (by omega : source.toInt ≤ 0)]
    cases k <;> simp only [IntKind.min,IntKind.max,Benitoite.Release.min64,Benitoite.Release.max64] at * <;> omega

private theorem absolute_unsigned (k : IntKind) (source : IntegerValue k) (unsigned : k.min = 0) :
    integerAbsoluteDelta k source = .val (.const (embedConst (IntegerValue.toConst k source))) := by
  have bounds := source.toInt_bounds
  have nonnegative : 0 ≤ source.toInt := by omega
  have converted := (integerConvert_some k source.toInt source).mpr rfl
  simp only [integerAbsoluteDelta,Int.natAbs_of_nonneg nonnegative,integerChecked,converted,integerOutcome_normal]

/-- absoluteの同じ全引数・応答でsigned最小値の拒否とunsignedの同値を保持する。 -/
theorem absolute_response_math {P B Ψ ts es rs ws a e} (k : IntKind)
    (args : BuiltinArgs P B Ψ (API.name k .absolute) (API.signature k .absolute) ts es rs ws a e) :
    ∃ source : IntegerValue k, ws = [.const (embedConst (IntegerValue.toConst k source))] ∧
      ∃ out, integerDelta (API.name k .absolute) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        (out = .err "IntegerOverflow" ↔ k.min < 0 ∧ source.toInt = k.min) ∧
        (k.min = 0 → out = .val (.const (embedConst (IntegerValue.toConst k source)))) ∧
        (∀ value, out = .val value → ∃ target : IntegerValue k,
          value = .const (embedConst (IntegerValue.toConst k target)) ∧
          target.toInt = (source.toInt.natAbs : Int) ∧ 0 ≤ target.toInt ∧
          k.min ≤ target.toInt ∧ target.toInt ≤ k.max) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := absolute_response k args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,source,rfl⟩ := unary_arguments k _ "n" args
  have same : out = integerAbsoluteDelta k source :=
    Option.some.inj (delta.symm.trans (integerDelta_absolute k source))
  refine ⟨source,rfl,out,delta,typed,adequate,nonexit,?_,?_,?_⟩
  · rw [same]; exact absolute_overflow k source
  · intro unsigned; rw [same]; exact absolute_unsigned k source unsigned
  · intro value normal
    have checked : integerOutcome (integerChecked k (source.toInt.natAbs : Int)) = .val value := same.symm.trans normal
    obtain ⟨target,eq,number⟩ := (checked_math k _).2.2 value checked
    exact ⟨target,eq,number,by omega,target.toInt_bounds⟩

example {P base Ψ ts es rs ws a e} (k : IntKind)
    (args : BuiltinArgs P (table base) Ψ (API.name k .absolute) (API.signature k .absolute) ts es rs ws a e) :=
  absolute_response_math k args

private theorem floor_partition (left right : Int) :
    floorNumber false left right * right + floorNumber true left right = left := by
  have partition := Int.tdiv_mul_add_tmod left right
  by_cases zero : left.tmod right = 0
  · simpa [floorNumber,zero] using partition
  · have signs : (left.tmod right < 0) = (left < 0) := by
      apply propext
      by_cases nonnegative : 0 ≤ left
      · have remainder_nonnegative := Int.tmod_nonneg right nonnegative
        omega
      · have remainder_nonnegative := Int.tmod_nonneg right (by omega : 0 ≤ -left)
        rw [Int.neg_tmod] at remainder_nonnegative
        omega
    simp only [floorNumber,Bool.false_eq_true,ite_false,ite_true,signs]
    by_cases correction : left.tmod right ≠ 0 ∧ ((left < 0) ≠ (right < 0))
    · rw [ite_eq_left correction,ite_eq_left correction]
      simp only [Int.sub_mul,Int.one_mul]
      omega
    · rw [ite_eq_right correction,ite_eq_right correction]
      exact partition

/-- 同じ床演算の実入力に、符号補正した商と剰余の分解等式を保持する。 -/
theorem floor_equation {P B Ψ ts es rs ws a e} (k : IntKind) (modulo : Bool)
    (args : BuiltinArgs P B Ψ (API.name k (if modulo then .floorModulo else .floorDivide))
      (API.signature k (if modulo then .floorModulo else .floorDivide)) ts es rs ws a e) :
    ∃ left right : IntegerValue k,
      ws = [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))] ∧
      floorNumber false left.toInt right.toInt * right.toInt + floorNumber true left.toInt right.toInt = left.toInt ∧
      ∃ out, integerDelta (API.name k (if modulo then .floorModulo else .floorDivide)) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        (∀ value, out = .val value → ∃ target : IntegerValue k,
          value = .const (embedConst (IntegerValue.toConst k target)) ∧
          target.toInt = floorNumber modulo left.toInt right.toInt) := by
  obtain ⟨left,right,same,out,delta,typed,adequate,nonexit,_,_,normal⟩ := floor_math k modulo args
  exact ⟨left,right,same,floor_partition left.toInt right.toInt,out,delta,typed,adequate,nonexit,normal⟩

example {P base Ψ ts es rs ws a e} (k : IntKind) (modulo : Bool)
    (args : BuiltinArgs P (table base) Ψ (API.name k (if modulo then .floorModulo else .floorDivide))
      (API.signature k (if modulo then .floorModulo else .floorDivide)) ts es rs ws a e) :=
  floor_equation k modulo args

def API.isBits : API → Bool
  | .floorDivide | .floorModulo | .absolute => false | _ => true

def API.bitOperation : API → IntegerBits
  | .bitwiseAnd => .bitwiseAnd | .bitwiseOr => .bitwiseOr | .bitwiseExclusiveOr => .bitwiseExclusiveOr
  | .bitwiseNot => .bitwiseNot | .shiftLeft => .shiftLeft | .shiftRight => .shiftRight
  | .shiftRightUnsigned => .shiftRightUnsigned | _ => .bitwiseAnd

def bitInputs (k : IntKind) (api : API) (left right : IntegerValue k)
    (count : Benitoite.Release.Integer64Value) : List Val :=
  match api with
  | .bitwiseNot => [.const (embedConst (IntegerValue.toConst k left))]
  | .shiftLeft | .shiftRight | .shiftRightUnsigned =>
      [.const (embedConst (IntegerValue.toConst k left)),.const (.integer count)]
  | _ => [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))]

/-- 同じ幅のビット・シフト本体がwrapする数学値。 -/
def bitNumber (k : IntKind) (op : IntegerBits) (left right count : Int) : Int :=
  let x := (left % (2 ^ integerWidth k)).toNat
  let y := (right % (2 ^ integerWidth k)).toNat
  match op with
  | .bitwiseAnd => (x &&& y : Nat) | .bitwiseOr => (x ||| y : Nat)
  | .bitwiseExclusiveOr => (x ^^^ y : Nat) | .bitwiseNot => (x ^^^ (2 ^ integerWidth k - 1) : Nat)
  | .shiftLeft => left <<< count.toNat | .shiftRight => left >>> count.toNat
  | .shiftRightUnsigned => (left % (2 ^ integerWidth k)) >>> count.toNat

private theorem bits_arguments {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (supported : api.isBits = true)
    (args : BuiltinArgs P B Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = embedTy k.type ∧ e = Eff.empty ∧
      ∃ left right : IntegerValue k, ∃ count : Benitoite.Release.Integer64Value,
        ws = bitInputs k api left right count := by
  cases api with
  | floorDivide | floorModulo | absolute => cases supported
  | bitwiseAnd | bitwiseOr | bitwiseExclusiveOr =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,rfl⟩ := binary_arguments k k _ "a" "b" args
    exact ⟨rfl,rfl,rfl,rfl,rfl,left,right,⟨0,by decide⟩,rfl⟩
  | bitwiseNot =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,rfl⟩ := unary_arguments k _ "a" args
    exact ⟨rfl,rfl,rfl,rfl,rfl,left,left,⟨0,by decide⟩,rfl⟩
  | shiftLeft | shiftRight | shiftRightUnsigned =>
    obtain ⟨rfl,rfl,rfl,rfl,rfl,left,count,rfl⟩ := binary_arguments k .integer64 _ "a" "n" args
    exact ⟨rfl,rfl,rfl,rfl,rfl,left,left,count,rfl⟩

private theorem bits_named (k : IntKind) (api : API) (supported : api.isBits = true)
    (available : API.available k api) (left right : IntegerValue k) (count : Benitoite.Release.Integer64Value) :
    integerDelta (API.name k api) [] [] [] (bitInputs k api left right count) =
      some (integerBitsDelta k api.bitOperation left right count.toInt) := by
  cases api with
  | floorDivide | floorModulo | absolute => cases supported
  | bitwiseAnd =>
    have same : integerDelta (API.name k .bitwiseAnd) [] [] []
      [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))] =
      some (integerBitsDelta k .bitwiseAnd left right 0) := integerDelta_bitwise k .bitwiseAnd left right (Or.inl rfl)
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same
  | bitwiseOr =>
    have same : integerDelta (API.name k .bitwiseOr) [] [] []
      [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))] =
      some (integerBitsDelta k .bitwiseOr left right 0) := integerDelta_bitwise k .bitwiseOr left right (Or.inr (Or.inl rfl))
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same
  | bitwiseExclusiveOr =>
    have same : integerDelta (API.name k .bitwiseExclusiveOr) [] [] []
      [.const (embedConst (IntegerValue.toConst k left)),.const (embedConst (IntegerValue.toConst k right))] =
      some (integerBitsDelta k .bitwiseExclusiveOr left right 0) := integerDelta_bitwise k .bitwiseExclusiveOr left right (Or.inr (Or.inr rfl))
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same
  | bitwiseNot =>
    have same : integerDelta (API.name k .bitwiseNot) [] [] [] [.const (embedConst (IntegerValue.toConst k left))] =
        some (integerBitsDelta k .bitwiseNot left left 0) := integerDelta_bitwiseNot k left
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same
  | shiftLeft =>
    have same : integerDelta (API.name k .shiftLeft) [] [] []
        [.const (embedConst (IntegerValue.toConst k left)),.const (.integer count)] =
        some (integerBitsDelta k .shiftLeft left left count.toInt) :=
      integerDelta_shift k .shiftLeft left count (Or.inl rfl) (by intro bad; cases bad)
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same
  | shiftRight =>
    have same : integerDelta (API.name k .shiftRight) [] [] []
        [.const (embedConst (IntegerValue.toConst k left)),.const (.integer count)] =
        some (integerBitsDelta k .shiftRight left left count.toInt) :=
      integerDelta_shift k .shiftRight left count (Or.inr (Or.inl rfl)) (by intro bad; cases bad)
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same
  | shiftRightUnsigned =>
    have same : integerDelta (API.name k .shiftRightUnsigned) [] [] []
        [.const (embedConst (IntegerValue.toConst k left)),.const (.integer count)] =
        some (integerBitsDelta k .shiftRightUnsigned left left count.toInt) :=
      integerDelta_shift k .shiftRightUnsigned left count (Or.inr (Or.inr rfl)) (by intro _; exact available rfl)
    simpa [bitInputs,API.bitOperation,integerBitsDelta] using same

/-- 同じ実ビット応答にwrapする値とcount域外のerrを保持する。 -/
theorem bits_math {P B Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (supported : api.isBits = true) (available : API.available k api)
    (args : BuiltinArgs P B Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :
    ∃ left right : IntegerValue k, ∃ count : Benitoite.Release.Integer64Value,
      ws = bitInputs k api left right count ∧
      ∃ out, integerDelta (API.name k api) ts es rs ws = some out ∧
        Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧
        out = integerBitsDelta k api.bitOperation left right count.toInt ∧
        (out = .err "ArgumentOutOfDomain" ↔
          (api.bitOperation = .shiftLeft ∨ api.bitOperation = .shiftRight ∨ api.bitOperation = .shiftRightUnsigned) ∧
            (count.toInt < 0 ∨ (integerWidth k : Int) ≤ count.toInt)) ∧
        (¬ ((api.bitOperation = .shiftLeft ∨ api.bitOperation = .shiftRight ∨ api.bitOperation = .shiftRightUnsigned) ∧
            (count.toInt < 0 ∨ (integerWidth k : Int) ≤ count.toInt)) →
          out = .val (.const (embedConst (IntegerValue.toConst k
            (integerWrap k (bitNumber k api.bitOperation left.toInt right.toInt count.toInt)))))) := by
  obtain ⟨out,delta,typed,adequate,nonexit⟩ := response k api available args
  obtain ⟨rfl,rfl,rfl,rfl,rfl,left,right,count,rfl⟩ := bits_arguments k api supported args
  have same : out = integerBitsDelta k api.bitOperation left right count.toInt :=
    Option.some.inj (delta.symm.trans (bits_named k api supported available left right count))
  refine ⟨left,right,count,rfl,out,delta,typed,adequate,nonexit,same,?_,?_⟩
  · rw [same]
    by_cases bad : (api.bitOperation = .shiftLeft ∨ api.bitOperation = .shiftRight ∨ api.bitOperation = .shiftRightUnsigned) ∧
      (count.toInt < 0 ∨ (integerWidth k : Int) ≤ count.toInt)
    · simp [integerBitsDelta,bad]
    · simp [integerBitsDelta,bad]
  · intro valid
    rw [same]
    simp only [integerBitsDelta,ite_eq_right valid]
    rfl

example {P base Ψ ts es rs ws a e} (k : IntKind) (api : API)
    (supported : api.isBits = true) (available : API.available k api)
    (args : BuiltinArgs P (table base) Ψ (API.name k api) (API.signature k api) ts es rs ws a e) :=
  bits_math k api supported available args

end Benitoite.Release.Refinement.StandardIntegerAPI
