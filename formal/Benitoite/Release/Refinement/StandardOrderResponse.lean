import Benitoite.Release.Refinement.StandardArithmeticResponse

namespace Benitoite.Release.Refinement.StandardOrderResponse
open Benitoite.Interval StandardScalar

inductive Kind where
  | integer8 | integer16 | integer32 | integer64 | unsignedInteger16 | unsignedInteger32 | unsignedInteger64 | byte | character | float32 | float64 | decimal
  deriving DecidableEq

def Kind.base : Kind → BaseTy
  | .integer8 => .integer8
  | .integer16 => .integer16
  | .integer32 => .integer32
  | .integer64 => .integer
  | .unsignedInteger16 => .unsignedInteger16
  | .unsignedInteger32 => .unsignedInteger32
  | .unsignedInteger64 => .unsignedInteger64
  | .byte => .byte
  | .character => .character
  | .float32 => .float32
  | .float64 => .float
  | .decimal => .decimal

def Kind.module : Kind → String
  | .integer8 => "Integer8"
  | .integer16 => "Integer16"
  | .integer32 => "Integer32"
  | .integer64 => "Integer"
  | .unsignedInteger16 => "UnsignedInteger16"
  | .unsignedInteger32 => "UnsignedInteger32"
  | .unsignedInteger64 => "UnsignedInteger64"
  | .byte => "Byte"
  | .character => "Character"
  | .float32 => "Float32"
  | .float64 => "Float"
  | .decimal => "Decimal"

def name (kind : Kind) (op : Comparison) : PrimName :=
  "%" ++ kind.module ++ match op with
  | .lt => ".less" | .le => ".lessOrEqual" | .gt => ".greater" | .ge => ".greaterOrEqual"
  | .eq => ".equal" | .ne => ".notEqual"

def Ordered (op : Comparison) : Prop := op = .lt ∨ op = .le ∨ op = .gt ∨ op = .ge

def signature (kind : Kind) : PrimSig :=
  ⟨[],0,["left","right"],[.base kind.base,.base kind.base],.base .boolean,Eff.empty,
    (fun _ ts => ts = []),.pure,none,[],.untargeted⟩

def Kind.delta : Kind → PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  | .byte => byteDelta | .character => characterDelta | .float32 => float32Delta
  | .float64 => float64Delta | .decimal => decimalDelta | _ => integerDelta

def predicate (kind : Kind) (op : Comparison) (left right : Term) : Pred :=
  match kind with
  | .character => Pred.compare .character op left right
  | .float32 => Pred.compare .float32 op left right
  | .float64 => Pred.compare .float64 op left right
  | .decimal => Pred.compare .decimal op left right
  | _ => integerComparePred op left right

def Relation (kind : Kind) (op : Comparison) (η : ObservationEnvModel) (ws : List Val) (out : Outcome) : Prop :=
  ∃ left right : Val, ∃ lt rt : Term, ∃ value : Bool,
    ws = [left,right] ∧ left.toTerm? = some lt ∧ right.toTerm? = some rt ∧
    out = .val (.const (.boolean value)) ∧ (predicate kind op lt rt).interpret η = value

private theorem instantiated (kind : Kind) :
    instantiatedTel (Tel.instR [] (signature kind).tel) [] [] =
      Ty.toTel ["left","right"] [.base kind.base,.base kind.base] (.base .boolean) Eff.empty := by
  have emptyRange : mapRangeAtoms (rangeAt 0 []) (fun _ => false) = (fun _ => false) := by
    funext x; cases x <;> simp [mapRangeAtoms]
  cases kind <;> simp [emptyRange,signature,Kind.base,PrimSig.tel,signatureTel,instantiatedTel,
    Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.rawMapRanges,Ty.rawMapRanges,mapRangesTys,
    Eff.rawMapRanges,Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys]

private theorem arguments {P B Ψ ts es rs ws a e} (kind : Kind) (op : Comparison)
    (args : BuiltinArgs P B Ψ (name kind op) (signature kind) ts es rs ws a e) :
    ts = [] ∧ es = [] ∧ rs = [] ∧ a = .base .boolean ∧ e = Eff.empty ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] ws [.base kind.base,.base kind.base] := by
  have ts0 : ts = [] := List.length_eq_zero_iff.mp args.admissible.typeCount
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst ts; subst es; subst rs
  have h := args.arguments
  rw [instantiated] at h
  obtain ⟨values,ar,ee⟩ := h.toTelValues (by simp [NamesWF])
  exact ⟨rfl,rfl,rfl,args.result.2.symm.trans ar,args.effect.2.symm.trans ee,values⟩

private theorem integer_shape {P B Ψ v} (k : IntKind)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (embedTy k.type)) :
    ∃ n : IntegerValue k, v = .const (embedConst (IntegerValue.toConst k n)) := by
  cases k <;> obtain ⟨c,rfl,hc,ht⟩ := h.canonical_scalar rfl
  all_goals cases c <;> cases ht
  all_goals first | exact ⟨_,rfl⟩ | exact ⟨⟨_,hc⟩,rfl⟩

private theorem scalar_shape {P B Ψ v} (base : BaseTy)
    (h : HasTypeVQ P B Ψ Qempty [] [] [] v (.base base)) :
    ∃ c, v = .const c ∧ ConstOK B c ∧ c.type.norm.core = .base base :=
  h.canonical_scalar rfl

set_option maxHeartbeats 2000000 in
/-- 全十二数値型・四比較の実left/rightを、同じδと観測述語へ接続する。 -/
theorem response_math {P B Ψ ts es rs ws a e} (kind : Kind) (op : Comparison)
    (ordered : Ordered op) (η : ObservationEnvModel)
    (args : BuiltinArgs P B Ψ (name kind op) (signature kind) ts es rs ws a e) :
    ∃ out, kind.delta (name kind op) ts es rs ws = some out ∧ Outcome.Typed P B Ψ out a ∧
      AdequateResult ws out ∧ (∀ i, out ≠ .exit i) ∧ Relation kind op η ws out := by
  obtain ⟨rfl,rfl,rfl,rfl,rfl,values⟩ := arguments kind op args
  cases values with | cons hl rest => cases rest with | cons hr rest =>
    cases rest
    cases kind with
    | integer8 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer8 hl
      obtain ⟨right,rfl⟩ := integer_shape .integer8 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .integer8 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .integer8 left)),.const (embedConst (IntegerValue.toConst .integer8 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .integer8 .lt left right (Or.inl rfl)
        · exact integerDelta_order .integer8 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .integer8 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .integer8 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer8 left)),.const (embedConst (IntegerValue.toConst .integer8 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer8 left).2
      · exact (NumericContracts.integer_result .integer8 right).2
    | integer16 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer16 hl
      obtain ⟨right,rfl⟩ := integer_shape .integer16 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .integer16 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .integer16 left)),.const (embedConst (IntegerValue.toConst .integer16 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .integer16 .lt left right (Or.inl rfl)
        · exact integerDelta_order .integer16 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .integer16 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .integer16 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer16 left)),.const (embedConst (IntegerValue.toConst .integer16 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer16 left).2
      · exact (NumericContracts.integer_result .integer16 right).2
    | integer32 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer32 hl
      obtain ⟨right,rfl⟩ := integer_shape .integer32 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .integer32 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .integer32 left)),.const (embedConst (IntegerValue.toConst .integer32 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .integer32 .lt left right (Or.inl rfl)
        · exact integerDelta_order .integer32 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .integer32 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .integer32 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer32 left)),.const (embedConst (IntegerValue.toConst .integer32 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer32 left).2
      · exact (NumericContracts.integer_result .integer32 right).2
    | integer64 =>
      obtain ⟨left,rfl⟩ := integer_shape .integer64 hl
      obtain ⟨right,rfl⟩ := integer_shape .integer64 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .integer64 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .integer64 left)),.const (embedConst (IntegerValue.toConst .integer64 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .integer64 .lt left right (Or.inl rfl)
        · exact integerDelta_order .integer64 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .integer64 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .integer64 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .integer64 left)),.const (embedConst (IntegerValue.toConst .integer64 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .integer64 left).2
      · exact (NumericContracts.integer_result .integer64 right).2
    | unsignedInteger16 =>
      obtain ⟨left,rfl⟩ := integer_shape .unsignedInteger16 hl
      obtain ⟨right,rfl⟩ := integer_shape .unsignedInteger16 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .unsignedInteger16 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .unsignedInteger16 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger16 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .unsignedInteger16 .lt left right (Or.inl rfl)
        · exact integerDelta_order .unsignedInteger16 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .unsignedInteger16 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .unsignedInteger16 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .unsignedInteger16 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger16 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .unsignedInteger16 left).2
      · exact (NumericContracts.integer_result .unsignedInteger16 right).2
    | unsignedInteger32 =>
      obtain ⟨left,rfl⟩ := integer_shape .unsignedInteger32 hl
      obtain ⟨right,rfl⟩ := integer_shape .unsignedInteger32 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .unsignedInteger32 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .unsignedInteger32 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger32 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .unsignedInteger32 .lt left right (Or.inl rfl)
        · exact integerDelta_order .unsignedInteger32 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .unsignedInteger32 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .unsignedInteger32 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .unsignedInteger32 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger32 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .unsignedInteger32 left).2
      · exact (NumericContracts.integer_result .unsignedInteger32 right).2
    | unsignedInteger64 =>
      obtain ⟨left,rfl⟩ := integer_shape .unsignedInteger64 hl
      obtain ⟨right,rfl⟩ := integer_shape .unsignedInteger64 hr
      obtain ⟨value,reply,fact⟩ := integerCompare_reply η op left.toInt right.toInt
      have named : integerDelta (name .unsignedInteger64 op) [] [] []
          [.const (embedConst (IntegerValue.toConst .unsignedInteger64 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger64 right))] =
          some (integerCompareDelta op left.toInt right.toInt) := by
        rcases ordered with rfl | rfl | rfl | rfl
        · exact integerDelta_order .unsignedInteger64 .lt left right (Or.inl rfl)
        · exact integerDelta_order .unsignedInteger64 .le left right (Or.inr (Or.inl rfl))
        · exact integerDelta_order .unsignedInteger64 .gt left right (Or.inr (Or.inr (Or.inl rfl)))
        · exact integerDelta_order .unsignedInteger64 .ge left right (Or.inr (Or.inr (Or.inr rfl)))
      refine ⟨.val (.const (.boolean value)),named.trans (congrArg some reply),⟨.V_Const trivial,trivial⟩,
        by intro σ _ _; trivial,by intro i; simp,
        .const (embedConst (IntegerValue.toConst .unsignedInteger64 left)),.const (embedConst (IntegerValue.toConst .unsignedInteger64 right)),
        .integer left.toInt,.integer right.toInt,value,rfl,?_,?_,rfl,fact⟩
      · exact (NumericContracts.integer_result .unsignedInteger64 left).2
      · exact (NumericContracts.integer_result .unsignedInteger64 right).2
    | byte =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .byte hl
      cases c <;> cases tag
      rename_i n
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .byte hr
      cases c <;> cases tag
      rename_i m
      let left : UInt8 := UInt8.ofNatLT n (by change n < 256; change n ≤ 255 at hc; omega)
      let right : UInt8 := UInt8.ofNatLT m (by change m < 256; change m ≤ 255 at hd; omega)
      obtain ⟨value,delta,typed,fact⟩ := byte_compare P B Ψ η left right op
      have named : byteDelta (name .byte op) [] [] [] [.const (.byte n),.const (.byte m)] = some (.val (.const (.boolean value))) := by
        rcases ordered with rfl | rfl | rfl | rfl <;> exact delta
      exact ⟨.val (.const (.boolean value)),named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.byte n),.const (.byte m),.integer n,.integer m,value,rfl,rfl,rfl,rfl,fact⟩
    | character =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .character hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .character hr
      cases c <;> cases tag
      rename_i right
      obtain ⟨value,delta,typed,fact⟩ := character_compare P B Ψ η left right op
      have named : characterDelta (name .character op) [] [] [] [.const (.character left),.const (.character right)] = some (.val (.const (.boolean value))) := by
        rcases ordered with rfl | rfl | rfl | rfl <;> exact delta
      exact ⟨.val (.const (.boolean value)),named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.character left),.const (.character right),.character left,.character right,value,rfl,rfl,rfl,rfl,fact⟩
    | float32 =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float32 hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .float32 hr
      cases c <;> cases tag
      rename_i right
      obtain ⟨value,delta,typed,fact⟩ := float32_compare_reply P B Ψ η left right op
      have named : float32Delta (name .float32 op) [] [] [] [.const (.float32 left),.const (.float32 right)] = some (.val (.const (.boolean value))) := by
        rcases ordered with rfl | rfl | rfl | rfl <;> exact delta
      exact ⟨.val (.const (.boolean value)),named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.float32 left),.const (.float32 right),.float32 left,.float32 right,value,rfl,rfl,rfl,rfl,fact⟩
    | float64 =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .float hl
      cases c <;> cases tag
      rename_i left
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .float hr
      cases c <;> cases tag
      rename_i right
      obtain ⟨value,delta,typed,fact⟩ := float64_compare_reply P B Ψ η left right op
      have named : float64Delta (name .float64 op) [] [] [] [.const (.float64 left),.const (.float64 right)] = some (.val (.const (.boolean value))) := by
        rcases ordered with rfl | rfl | rfl | rfl <;> exact delta
      exact ⟨.val (.const (.boolean value)),named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.float64 left),.const (.float64 right),.float64 left,.float64 right,value,rfl,rfl,rfl,rfl,fact⟩
    | decimal =>
      obtain ⟨c,rfl,hc,tag⟩ := scalar_shape .decimal hl
      cases c <;> cases tag
      rename_i left ls
      obtain ⟨c,rfl,hd,tag⟩ := scalar_shape .decimal hr
      cases c <;> cases tag
      rename_i right rs
      obtain ⟨value,delta,typed,fact⟩ := decimal_compare_reply P B Ψ η left right ls rs hc hd op
      have named : decimalDelta (name .decimal op) [] [] [] [.const (.decimal left ls),.const (.decimal right rs)] = some (.val (.const (.boolean value))) := by
        rcases ordered with rfl | rfl | rfl | rfl <;> exact delta
      exact ⟨.val (.const (.boolean value)),named,⟨typed,trivial⟩,by intro σ _ _; trivial,by intro i; simp,
        .const (.decimal left ls),.const (.decimal right rs),.decimal left ls,.decimal right rs,value,rfl,rfl,rfl,rfl,fact⟩

private def kinds : List Kind := [.integer8,.integer16,.integer32,.integer64,
  .unsignedInteger16,.unsignedInteger32,.unsignedInteger64,.byte,.character,.float32,.float64,.decimal]

private def comparisons : List Comparison := [.lt,.le,.gt,.ge]

def lookup (b : PrimName) : Option PrimSig :=
  kinds.findSome? fun kind => comparisons.findSome? fun op =>
    if b = name kind op then some (signature kind) else none

set_option maxHeartbeats 2000000 in
theorem lookup_name (kind : Kind) (op : Comparison) (ordered : Ordered op) :
    lookup (name kind op) = some (signature kind) := by
  cases kind <;> rcases ordered with rfl | rfl | rfl | rfl
  all_goals simp [lookup,kinds,comparisons,name,Kind.module,List.findSome?]

def table (base : Builtins) : Builtins :=
  {base with sig := lookup,delta := fun b ts es rs ws =>
    if b.startsWith "%Byte." then byteDelta b ts es rs ws
    else if b.startsWith "%Character." then characterDelta b ts es rs ws
    else if b.startsWith "%Float32." then float32Delta b ts es rs ws
    else if b.startsWith "%Float." then float64Delta b ts es rs ws
    else if b.startsWith "%Decimal." then decimalDelta b ts es rs ws
    else integerDelta b ts es rs ws}

theorem table_response {P base Ψ ts es rs ws a e} (kind : Kind) (op : Comparison)
    (ordered : Ordered op) (η : ObservationEnvModel)
    (args : BuiltinArgs P (table base) Ψ (name kind op) (signature kind) ts es rs ws a e) :
    (table base).sig (name kind op) = some (signature kind) ∧
    ∃ out, (table base).delta (name kind op) ts es rs ws = some out ∧
      Outcome.Typed P (table base) Ψ out a ∧ AdequateResult ws out ∧
      (∀ i, out ≠ .exit i) ∧ Relation kind op η ws out := by
  obtain ⟨out,delta,typed,adequate,nonexit,related⟩ := response_math kind op ordered η args
  refine ⟨lookup_name kind op ordered,out,?_,typed,adequate,nonexit,related⟩
  cases kind <;> rcases ordered with rfl | rfl | rfl | rfl
  all_goals simpa [table,name,Kind.module,Kind.delta] using delta

example {P base Ψ ts es rs ws a e} (kind : Kind) (op : Comparison)
    (ordered : Ordered op) (η : ObservationEnvModel)
    (args : BuiltinArgs P (table base) Ψ (name kind op) (signature kind) ts es rs ws a e) :=
  table_response kind op ordered η args

-- 原始演算子の登録スキーマとの全欄対応。
-- %Integer.less: registered INTEGER/Lt
example : (StandardOrderResponse.signature .integer64) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer64 .lt = "%Integer.less" := ⟨rfl,rfl⟩

-- %Integer.lessOrEqual: registered INTEGER/Le
example : (StandardOrderResponse.signature .integer64) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer64 .le = "%Integer.lessOrEqual" := ⟨rfl,rfl⟩

-- %Integer.greater: registered INTEGER/Gt
example : (StandardOrderResponse.signature .integer64) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer64 .gt = "%Integer.greater" := ⟨rfl,rfl⟩

-- %Integer.greaterOrEqual: registered INTEGER/Ge
example : (StandardOrderResponse.signature .integer64) = (⟨[],0,["left","right"],[(.base .integer),(.base .integer)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer64 .ge = "%Integer.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Float.less: registered FLOAT/Lt
example : (StandardOrderResponse.signature .float64) = (⟨[],0,["left","right"],[(.base .float),(.base .float)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float64 .lt = "%Float.less" := ⟨rfl,rfl⟩

-- %Float.lessOrEqual: registered FLOAT/Le
example : (StandardOrderResponse.signature .float64) = (⟨[],0,["left","right"],[(.base .float),(.base .float)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float64 .le = "%Float.lessOrEqual" := ⟨rfl,rfl⟩

-- %Float.greater: registered FLOAT/Gt
example : (StandardOrderResponse.signature .float64) = (⟨[],0,["left","right"],[(.base .float),(.base .float)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float64 .gt = "%Float.greater" := ⟨rfl,rfl⟩

-- %Float.greaterOrEqual: registered FLOAT/Ge
example : (StandardOrderResponse.signature .float64) = (⟨[],0,["left","right"],[(.base .float),(.base .float)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float64 .ge = "%Float.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Decimal.less: registered DECIMAL/Lt
example : (StandardOrderResponse.signature .decimal) = (⟨[],0,["left","right"],[(.base .decimal),(.base .decimal)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .decimal .lt = "%Decimal.less" := ⟨rfl,rfl⟩

-- %Decimal.lessOrEqual: registered DECIMAL/Le
example : (StandardOrderResponse.signature .decimal) = (⟨[],0,["left","right"],[(.base .decimal),(.base .decimal)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .decimal .le = "%Decimal.lessOrEqual" := ⟨rfl,rfl⟩

-- %Decimal.greater: registered DECIMAL/Gt
example : (StandardOrderResponse.signature .decimal) = (⟨[],0,["left","right"],[(.base .decimal),(.base .decimal)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .decimal .gt = "%Decimal.greater" := ⟨rfl,rfl⟩

-- %Decimal.greaterOrEqual: registered DECIMAL/Ge
example : (StandardOrderResponse.signature .decimal) = (⟨[],0,["left","right"],[(.base .decimal),(.base .decimal)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .decimal .ge = "%Decimal.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Character.less: registered CHARACTER/Lt
example : (StandardOrderResponse.signature .character) = (⟨[],0,["left","right"],[(.base .character),(.base .character)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .character .lt = "%Character.less" := ⟨rfl,rfl⟩

-- %Character.lessOrEqual: registered CHARACTER/Le
example : (StandardOrderResponse.signature .character) = (⟨[],0,["left","right"],[(.base .character),(.base .character)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .character .le = "%Character.lessOrEqual" := ⟨rfl,rfl⟩

-- %Character.greater: registered CHARACTER/Gt
example : (StandardOrderResponse.signature .character) = (⟨[],0,["left","right"],[(.base .character),(.base .character)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .character .gt = "%Character.greater" := ⟨rfl,rfl⟩

-- %Character.greaterOrEqual: registered CHARACTER/Ge
example : (StandardOrderResponse.signature .character) = (⟨[],0,["left","right"],[(.base .character),(.base .character)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .character .ge = "%Character.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Byte.less: registered BYTE/Lt
example : (StandardOrderResponse.signature .byte) = (⟨[],0,["left","right"],[(.base .byte),(.base .byte)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .byte .lt = "%Byte.less" := ⟨rfl,rfl⟩

-- %Byte.lessOrEqual: registered BYTE/Le
example : (StandardOrderResponse.signature .byte) = (⟨[],0,["left","right"],[(.base .byte),(.base .byte)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .byte .le = "%Byte.lessOrEqual" := ⟨rfl,rfl⟩

-- %Byte.greater: registered BYTE/Gt
example : (StandardOrderResponse.signature .byte) = (⟨[],0,["left","right"],[(.base .byte),(.base .byte)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .byte .gt = "%Byte.greater" := ⟨rfl,rfl⟩

-- %Byte.greaterOrEqual: registered BYTE/Ge
example : (StandardOrderResponse.signature .byte) = (⟨[],0,["left","right"],[(.base .byte),(.base .byte)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .byte .ge = "%Byte.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Integer8.less: registered INTEGER8/Lt
example : (StandardOrderResponse.signature .integer8) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer8 .lt = "%Integer8.less" := ⟨rfl,rfl⟩

-- %Integer8.lessOrEqual: registered INTEGER8/Le
example : (StandardOrderResponse.signature .integer8) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer8 .le = "%Integer8.lessOrEqual" := ⟨rfl,rfl⟩

-- %Integer8.greater: registered INTEGER8/Gt
example : (StandardOrderResponse.signature .integer8) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer8 .gt = "%Integer8.greater" := ⟨rfl,rfl⟩

-- %Integer8.greaterOrEqual: registered INTEGER8/Ge
example : (StandardOrderResponse.signature .integer8) = (⟨[],0,["left","right"],[(.base .integer8),(.base .integer8)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer8 .ge = "%Integer8.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Integer16.less: registered INTEGER16/Lt
example : (StandardOrderResponse.signature .integer16) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer16 .lt = "%Integer16.less" := ⟨rfl,rfl⟩

-- %Integer16.lessOrEqual: registered INTEGER16/Le
example : (StandardOrderResponse.signature .integer16) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer16 .le = "%Integer16.lessOrEqual" := ⟨rfl,rfl⟩

-- %Integer16.greater: registered INTEGER16/Gt
example : (StandardOrderResponse.signature .integer16) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer16 .gt = "%Integer16.greater" := ⟨rfl,rfl⟩

-- %Integer16.greaterOrEqual: registered INTEGER16/Ge
example : (StandardOrderResponse.signature .integer16) = (⟨[],0,["left","right"],[(.base .integer16),(.base .integer16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer16 .ge = "%Integer16.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Integer32.less: registered INTEGER32/Lt
example : (StandardOrderResponse.signature .integer32) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer32 .lt = "%Integer32.less" := ⟨rfl,rfl⟩

-- %Integer32.lessOrEqual: registered INTEGER32/Le
example : (StandardOrderResponse.signature .integer32) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer32 .le = "%Integer32.lessOrEqual" := ⟨rfl,rfl⟩

-- %Integer32.greater: registered INTEGER32/Gt
example : (StandardOrderResponse.signature .integer32) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer32 .gt = "%Integer32.greater" := ⟨rfl,rfl⟩

-- %Integer32.greaterOrEqual: registered INTEGER32/Ge
example : (StandardOrderResponse.signature .integer32) = (⟨[],0,["left","right"],[(.base .integer32),(.base .integer32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .integer32 .ge = "%Integer32.greaterOrEqual" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.less: registered UNSIGNED_INTEGER16/Lt
example : (StandardOrderResponse.signature .unsignedInteger16) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger16 .lt = "%UnsignedInteger16.less" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.lessOrEqual: registered UNSIGNED_INTEGER16/Le
example : (StandardOrderResponse.signature .unsignedInteger16) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger16 .le = "%UnsignedInteger16.lessOrEqual" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.greater: registered UNSIGNED_INTEGER16/Gt
example : (StandardOrderResponse.signature .unsignedInteger16) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger16 .gt = "%UnsignedInteger16.greater" := ⟨rfl,rfl⟩

-- %UnsignedInteger16.greaterOrEqual: registered UNSIGNED_INTEGER16/Ge
example : (StandardOrderResponse.signature .unsignedInteger16) = (⟨[],0,["left","right"],[(.base .unsignedInteger16),(.base .unsignedInteger16)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger16 .ge = "%UnsignedInteger16.greaterOrEqual" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.less: registered UNSIGNED_INTEGER32/Lt
example : (StandardOrderResponse.signature .unsignedInteger32) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger32 .lt = "%UnsignedInteger32.less" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.lessOrEqual: registered UNSIGNED_INTEGER32/Le
example : (StandardOrderResponse.signature .unsignedInteger32) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger32 .le = "%UnsignedInteger32.lessOrEqual" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.greater: registered UNSIGNED_INTEGER32/Gt
example : (StandardOrderResponse.signature .unsignedInteger32) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger32 .gt = "%UnsignedInteger32.greater" := ⟨rfl,rfl⟩

-- %UnsignedInteger32.greaterOrEqual: registered UNSIGNED_INTEGER32/Ge
example : (StandardOrderResponse.signature .unsignedInteger32) = (⟨[],0,["left","right"],[(.base .unsignedInteger32),(.base .unsignedInteger32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger32 .ge = "%UnsignedInteger32.greaterOrEqual" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.less: registered UNSIGNED_INTEGER64/Lt
example : (StandardOrderResponse.signature .unsignedInteger64) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger64 .lt = "%UnsignedInteger64.less" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.lessOrEqual: registered UNSIGNED_INTEGER64/Le
example : (StandardOrderResponse.signature .unsignedInteger64) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger64 .le = "%UnsignedInteger64.lessOrEqual" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.greater: registered UNSIGNED_INTEGER64/Gt
example : (StandardOrderResponse.signature .unsignedInteger64) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger64 .gt = "%UnsignedInteger64.greater" := ⟨rfl,rfl⟩

-- %UnsignedInteger64.greaterOrEqual: registered UNSIGNED_INTEGER64/Ge
example : (StandardOrderResponse.signature .unsignedInteger64) = (⟨[],0,["left","right"],[(.base .unsignedInteger64),(.base .unsignedInteger64)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .unsignedInteger64 .ge = "%UnsignedInteger64.greaterOrEqual" := ⟨rfl,rfl⟩

-- %Float32.less: registered FLOAT32/Lt
example : (StandardOrderResponse.signature .float32) = (⟨[],0,["left","right"],[(.base .float32),(.base .float32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float32 .lt = "%Float32.less" := ⟨rfl,rfl⟩

-- %Float32.lessOrEqual: registered FLOAT32/Le
example : (StandardOrderResponse.signature .float32) = (⟨[],0,["left","right"],[(.base .float32),(.base .float32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float32 .le = "%Float32.lessOrEqual" := ⟨rfl,rfl⟩

-- %Float32.greater: registered FLOAT32/Gt
example : (StandardOrderResponse.signature .float32) = (⟨[],0,["left","right"],[(.base .float32),(.base .float32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float32 .gt = "%Float32.greater" := ⟨rfl,rfl⟩

-- %Float32.greaterOrEqual: registered FLOAT32/Ge
example : (StandardOrderResponse.signature .float32) = (⟨[],0,["left","right"],[(.base .float32),(.base .float32)],.base .boolean,Eff.empty,(fun _ ts => ts = []),.pure,none,[],.untargeted⟩ : PrimSig) ∧
    StandardOrderResponse.name .float32 .ge = "%Float32.greaterOrEqual" := ⟨rfl,rfl⟩

end Benitoite.Release.Refinement.StandardOrderResponse
