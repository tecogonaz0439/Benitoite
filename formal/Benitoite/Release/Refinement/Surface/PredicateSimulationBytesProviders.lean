import Benitoite.Release.Refinement.Surface.PredicateSimulationConstantInputs
import Benitoite.Release.Refinement.Surface.PredicateSimulationResponses

/-! # Bytesの固定行とByteOrderの構成子の読取り -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
open StandardBytesOrdinaryResponse
noncomputable section

private def byte_order : Val → Option Bool
  | .con "ByteOrder.BigEndian" [] [] => some true
  | .con "ByteOrder.LittleEndian" [] [] => some false
  | _ => none

private theorem byte_order_equal {source rows x y} (related : Value source rows x y) : byte_order x = byte_order y := by
  cases related with
  | @con c types xs ys children =>
    cases children with
    | nil => rfl
    | cons head tail => simp [byte_order]
  | _ => rfl

private def read_evaluation (signed : Bool) (bytes : List Nat)
    (offset count : Benitoite.Release.Integer64Value) (order : Option Bool) :
    Except String (Option Benitoite.Release.Integer64Value) :=
  match (if bytes.all (· ≤ 255) then some (bytes.map UInt8.ofNat) else none),order with
  | some bytes,some big => .ok (readInteger bytes offset.toInt count.toInt big signed)
  | _,_ => .error "invalid Bytes arguments"

private def checked_option (value : Option (List UInt8)) : Except String (Option (List UInt8)) :=
  match value with
  | none => .ok none
  | some bytes => (if bytes.length ≤ 1073741824 then Except.ok bytes else .error "ValueTooLarge").map some

private def write_evaluation (signed : Bool) (value count : Benitoite.Release.Integer64Value) (order : Option Bool) :
    Except String (Option (List UInt8)) :=
  match order with
  | some big => checked_option (writeInteger value.toInt count.toInt big signed)
  | none => .error "invalid Bytes arguments"

private theorem read_evaluation_equal {source rows x y} (related : Value source rows x y)
    (signed : Bool) (bytes : List Nat) (offset count : Benitoite.Release.Integer64Value) :
    (if signed then API.readSigned else .readUnsigned).evaluate
        [.bytesV bytes,.const (.integer offset),.const (.integer count),x] =
      (if signed then API.readSigned else .readUnsigned).evaluate
        [.bytesV bytes,.const (.integer offset),.const (.integer count),y] := by
  cases signed
  · change read_evaluation false bytes offset count (byte_order x) = read_evaluation false bytes offset count (byte_order y)
    rw [byte_order_equal related]
  · change read_evaluation true bytes offset count (byte_order x) = read_evaluation true bytes offset count (byte_order y)
    rw [byte_order_equal related]

private theorem write_evaluation_equal {source rows x y} (related : Value source rows x y)
    (signed : Bool) (value count : Benitoite.Release.Integer64Value) :
    (if signed then API.fromSigned else .fromUnsigned).evaluate [.const (.integer value),.const (.integer count),x] =
      (if signed then API.fromSigned else .fromUnsigned).evaluate [.const (.integer value),.const (.integer count),y] := by
  cases signed
  · change write_evaluation false value count (byte_order x) = write_evaluation false value count (byte_order y)
    rw [byte_order_equal related]
  · change write_evaluation true value count (byte_order x) = write_evaluation true value count (byte_order y)
    rw [byte_order_equal related]

private theorem instantiated (api : API) :
    instantiatedTel (Tel.instR [] api.signature.tel) [] [] =
      Ty.toTel api.names api.inputs api.resultKind.type Eff.empty := by
  cases api <;> simp [API.signature,API.names,API.inputs,API.resultKind,StandardPureResults.Kind.type,
    PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,Tel.substRAt,Tel.mapRanges,Tel.bind,Tel.rawBind,
    Ty.rawBind,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,Ty.toTel,Ty.shiftV,Eff.shiftV,shiftVTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,rawBindTys]

private theorem evaluate_equal {P B Ψ source rows xs ys} (api : API)
    (typed : HasTypeVsQ P B Ψ Qempty [] [] [] ys api.inputs)
    (related : Values source rows xs ys) : api.evaluate xs = api.evaluate ys := by
  cases api with
  | empty | fromIntegers | fromHex | fromBinary | toHex | toBinary | get | slice | concatenate =>
    have same := constant_values_equal typed (by simp [API.inputs,ConstantInputType.base,ConstantInputType.bytes,ConstantInputType.list]) related
    rw [same]
  | readUnsigned | readSigned =>
    cases typed with | cons bytes rest => cases rest with | cons offset rest => cases rest with | cons count rest => cases rest with | cons order rest =>
      cases rest
      obtain ⟨bytes,rfl⟩ := bytes.canonical_bytes rfl
      obtain ⟨c,rfl,_,tag⟩ := offset.canonical_scalar rfl
      cases c <;> cases tag
      obtain ⟨c,rfl,_,tag⟩ := count.canonical_scalar rfl
      cases c <;> cases tag
      cases related with | cons bytesRel restRel => cases restRel with | cons offsetRel restRel => cases restRel with | cons countRel restRel => cases restRel with | cons orderRel restRel =>
        cases restRel
        cases bytesRel
        cases offsetRel
        cases countRel
        first | exact read_evaluation_equal orderRel false _ _ _ | exact read_evaluation_equal orderRel true _ _ _
  | fromUnsigned | fromSigned =>
    cases typed with | cons value rest => cases rest with | cons count rest => cases rest with | cons order rest =>
      cases rest
      obtain ⟨c,rfl,_,tag⟩ := value.canonical_scalar rfl
      cases c <;> cases tag
      obtain ⟨c,rfl,_,tag⟩ := count.canonical_scalar rfl
      cases c <;> cases tag
      cases related with | cons valueRel restRel => cases restRel with | cons countRel restRel => cases restRel with | cons orderRel restRel =>
        cases restRel
        cases valueRel
        cases countRel
        first | exact write_evaluation_equal orderRel false _ _ | exact write_evaluation_equal orderRel true _ _

private theorem dispatch_name (api : API) : dispatch api.name = some api := by cases api <;> rfl

/-- Bytesの十三行は、ByteOrderの構成子の読取りも値の対応で比較し、同じ評価結果を持つ。 -/
theorem bytes_ordinary_provider_delta {P B Ψ source rows ts es rs xs ys a e} (api : API)
    (typed : BuiltinArgs P B Ψ api.name api.signature ts es rs ys a e)
    (related : Values source rows xs ys) :
    OptionalOutcomeRel source rows
      ((table StandardModel.signatureBase).delta api.name ts es rs xs)
      ((table StandardModel.signatureBase).delta api.name ts es rs ys) := by
  have named : NamesWF api.names api.inputs := by cases api <;> simp [API.names,API.inputs,NamesWF]
  have normal : Ty.normTys api.inputs = api.inputs := by cases api <;> rfl
  have values := monomorphic_arguments_values typed rfl rfl rfl (instantiated api) named normal
  simp only [table,dispatch_name,Option.bind_some,API.delta,evaluate_equal api values related]
  exact .refl _

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
