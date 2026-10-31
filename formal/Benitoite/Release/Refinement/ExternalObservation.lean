import Benitoite.Release.Refinement.TypedFacts
import Benitoite.Release.Refinement.Carrier

namespace Benitoite.Release.Refinement

/-- carrier は型の sort だけを保存し、値の所属の代用にはしない。 -/
theorem Ty.sort_carrier (a : Ty) : a.carrier.sort? = a.sort? := by
  cases a <;> simp only [Ty.carrier,Ty.sort?]
  case refined a p => exact a.sort_carrier

theorem HasTypeVQ.closed_observation {P B Ψ Q C Φ v a s}
    (h : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.HasSort s) :
    ∃ t, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed := by
  obtain ⟨t,ht,hst⟩ := h.observation hs
  refine ⟨t,ht,hst,?_⟩
  exact Term.varsIn_mono (h.observation_references ht) (by intro i hi; obtain ⟨b,hb,_⟩ := hi; cases hb)

theorem HasTypeVQ.argumentsEnv_observation {P B Ψ Q C Φ v a s}
    (h : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.HasSort s) :
    ∃ t, (Tel.argumentsEnv v).values 0 = some t ∧
      termBind (Tel.argumentsEnv v).values (.var 0) = t ∧ t.Closed := by
  obtain ⟨t,ht,_,hc⟩ := h.closed_observation hs
  refine ⟨t,ht,?_,hc⟩
  change v.toTerm?.getD (.integer 0) = t
  rw [ht]; rfl

/-- 篩を除いた構文でsortを選んでも、実際の型付き値の観測を使える。 -/
theorem HasTypeVQ.represented {P B Ψ Q C Φ v a s}
    (h : HasTypeVQ P B Ψ Q C [] Φ v a) (hs : a.carrier.HasSort s) :
    ∃ t, v.toTerm? = some t ∧ t.HasSort [] s ∧ t.Closed := by
  apply h.closed_observation
  simpa only [Ty.HasSort,Ty.sort_carrier] using hs

/-- 数値の表現可能性。保持対象の条件はここへ混ぜない。 -/
def Const.NumericRepresented : Const → Prop
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -79228162514264337593543950335 ≤ n ∧
      n ≤ 79228162514264337593543950335 ∧ scale ≤ 28
  | _ => True

theorem ConstOK.represented {B c} (h : ConstOK B c) : c.NumericRepresented := by
  cases c <;> first | exact h | trivial

end Benitoite.Release.Refinement
