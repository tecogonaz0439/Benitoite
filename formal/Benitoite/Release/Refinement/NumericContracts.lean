import Benitoite.Interval.Arithmetic
import Benitoite.Release.Refinement.Embedding
import Benitoite.Release.Refinement.CarrierFactsMeaning
import Benitoite.Release.Refinement.ExternalObservation

/-! # 本番の正常な算術結果と型域 -/
namespace Benitoite.Release.Refinement
namespace NumericContracts
open Benitoite.Interval

/-- 本番の幅付き整数を篩の定数へ写しても、数と表現可能性を保つ。 -/
theorem integer_result (k : IntKind) (v : IntegerValue k) :
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? =
      some (.integer v.toInt) := by
  have bounds := v.toInt_bounds
  cases k <;> simp_all [IntegerValue.toConst, embedConst, Const.NumericRepresented,
    Val.toTerm?, IntKind.min, IntKind.max, Benitoite.Release.min64, Benitoite.Release.max64]
  rfl

/-- 七幅の加算・減算・積を同じ正常結果の観測へ結ぶ。 -/
theorem binary_normal (k : IntKind) (op : WidthBinary)
    (a b v : IntegerValue k) (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) :
    (v.toInt = match op with
      | .add => a.toInt + b.toInt
      | .sub => a.toInt - b.toInt
      | _ => a.toInt * b.toInt) ∧
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? =
      some (.integer v.toInt) := by
  refine ⟨?_, integer_result k v⟩
  rcases supported with rfl | rfl | rfl
  · exact (checkedAdd_normal_iff a b v).mp normal
  · exact (checkedSub_normal_iff a b v).mp normal
  · exact (checkedMul_normal_iff a b v).mp normal

/-- 符号付き四幅の負号。signed は既存演算と同じ前提である。 -/
theorem neg_normal (k : IntKind) (signed : k.min < 0) (a v : IntegerValue k)
    (normal : k.checkedNeg signed a = .normal (.ofInteger k v)) :
    v.toInt = -a.toInt ∧ (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? =
      some (.integer v.toInt) :=
  ⟨(checkedNeg_normal_iff signed a v).mp normal, integer_result k v⟩

/-- あふれの応答は、同じ演算の正常応答を構成しない。 -/
theorem rejected_not_normal {r : OperationResult} {why : Failure}
    (rejected : r = .rejected why) (v : ConcreteValue) : r ≠ .normal v := by
  rw [rejected]; intro h; cases h

/-- 255以下のByteと同じ数のUnsignedInteger16は、ともに表現可能である。 -/
theorem byte_and_u16_represented (n : Nat) (h : n ≤ 255) :
    (Const.byte n).NumericRepresented ∧
    (Val.const (.byte n)).toTerm? = some (.integer n) ∧
    (Const.unsignedInteger16 n).NumericRepresented := by
  exact ⟨h, rfl, by simp only [Const.NumericRepresented]; omega⟩

/-- 成功した同じ sort の観測では、全域の比較も実観測と一致する。 -/
theorem compare_exact {s : «Sort»} {t u : Term} {a b : Observation}
    (η : ObservationEnvModel) (ht : t.observe η = some a) (hu : u.observe η = some b)
    (ha : a.sort = s) (hb : b.sort = s) (op : Comparison) :
    (Pred.compare s op t u).interpret η = a.compare op b := by
  simp [Pred.interpret, Pred.atomValue, observeAs, Term.observe_sound ht,
    Term.observe_sound hu, ha, hb]

/-- 二幅の分類は、観測されたビット列をそのまま読む。 -/
theorem float_class_exact (η : ObservationEnvModel) (t : Term) (c : FloatClass) :
    (∀ b : UInt32, t.observe η = some (.float32 b) →
      (Pred.floatClass .binary32 c t).interpret η = ieeeClass 23 8 b.toNat c) ∧
    (∀ b : UInt64, t.observe η = some (.float64 b) →
      (Pred.floatClass .binary64 c t).interpret η = ieeeClass 52 11 b.toNat c) := by
  constructor <;> intro b h <;>
    simp [Pred.interpret, Pred.atomValue, observeAs, Term.observe_sound h, Observation.sort]

/-- 表現可能な Decimal の実定数は、型域と同じ係数・scale で観測される。 -/
theorem decimal_result {B : Builtins} {c : Int} {scale : Nat}
    (ok : ConstOK B (.decimal c scale)) (η : ObservationEnvModel) :
    (Const.decimal c scale).NumericRepresented ∧
    (Val.const (.decimal c scale)).toTerm? = some (.decimal c scale) ∧
    (Term.decimal c scale).observe η = some (.decimal c scale) ∧
    ∀ p ∈ (Const.decimal c scale).type.carrierFacts,
      p.interpret (selfModel η (.const (.decimal c scale))) = true :=
  ⟨ok.represented, rfl, rfl, ok.represented.carrierFacts η⟩

end NumericContracts
end Benitoite.Release.Refinement
