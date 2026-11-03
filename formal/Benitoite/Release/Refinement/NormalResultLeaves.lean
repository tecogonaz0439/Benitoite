import Benitoite.Release.Refinement.PreparedLeaf
import Benitoite.Release.Refinement.NumericContracts

/-! # 正常な算術の結果から有限の葉を構成する -/
namespace Benitoite.Release.Refinement
namespace NormalResultLeaves
open Benitoite.Interval
noncomputable section

/-- 実演算と同じ数の式。除算・剰余はこの入口の対象ではない。 -/
def expression (op : WidthBinary) (a b : Int) : Term :=
  match op with
  | .add => .add (.integer a) (.integer b)
  | .sub => .add (.integer a) (.neg (.integer b))
  | _ => .scale a (.integer b)

def leaf (op : WidthBinary) (a b n : Int) : PreparedLeaf :=
  ⟨.eq (.integer n) (expression op a b), .closed, [], []⟩

/-- 本番の正常結果から作る葉。表現可能性は検査器の独立の仮定にしない。 -/
theorem binary_leaf {P : Program} (valid : P.VarianceValid) (k : IntKind) (op : WidthBinary)
    (a b v : IntegerValue k) (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) :
    (leaf op a.toInt b.toInt v.toInt).checkIn P [] [] [] = true ∧
    (embedConst (IntegerValue.toConst k v)).NumericRepresented ∧
    (Val.const (embedConst (IntegerValue.toConst k v))).toTerm? = some (.integer v.toInt) := by
  obtain ⟨number, represented, term⟩ := NumericContracts.binary_normal k op a b v supported normal
  refine ⟨?_, represented, term⟩
  rcases supported with rfl | rfl | rfl
  all_goals
    classical
    simp [PreparedLeaf.checkIn, Certificate.checkIn, Certificate.check, Certificate.AdmissibleIn,
      leaf, expression, Certificate.keys, Certificate.extraKeys, Pred.ofConjuncts,
      Pred.linearKeys, Term.linearKeys, Ctx.facts, KeyTable.checkIn, valid,
      predEq_spec, PreparedLeaf.checkRaw, Pred.closedTrue, Pred.evalClosed,
      Pred.WF, Pred.VarsIn, Term.VarsIn, Pred.Sorted, Term.HasSort,
      Term.References, Term.Shape, Pred.Declared, Term.Declared,
      Pred.evalWith, Pred.atomReady, termReady, Pred.atomValue, Term.observe, Term.interpret,
      integerAs, observeAs, Observation.sort, Observation.integerD,
      number, Int.sub_eq_add_neg]

/-- 成功した同じ有限の葉を、任意の置換像の構文の含意として読む。 -/
theorem binary_entails_at {P : Program} (valid : P.VarianceValid) (k : IntKind) (op : WidthBinary)
    (a b v : IntegerValue k) (supported : op = .add ∨ op = .sub ∨ op = .mul)
    (normal : op.apply k a b = .normal (.ofInteger k v)) (ν : ObservationEnv) :
    Entails [] (predBind ν (leaf op a.toInt b.toInt v.toInt).predicate) := by
  simpa [Ctx.facts] using PreparedLeaf.bind_entails (binary_leaf valid k op a b v supported normal).1 ν

end
end NormalResultLeaves
end Benitoite.Release.Refinement
