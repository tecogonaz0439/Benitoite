import Benitoite.Release.Refinement.Surface.PredicateSimulationAlgebra
import Benitoite.Release.Refinement.StandardModelGeneral

/-! # 判定の名前解決に対応する列の操作と固定した応答 -/
namespace Benitoite.Release.Refinement.Surface.PredicateSimulation
noncomputable section

/-- 正常値は値の対応で比較し、失敗と終了のpayloadは等しい。 -/
inductive OutcomeRel (source : Program) (rows : PredicateProjection.Table.Rows) : Outcome → Outcome → Prop where
  | value {v w} : Value source rows v w → OutcomeRel source rows (.val v) (.val w)
  | error (message) : OutcomeRel source rows (.err message) (.err message)
  | exit (code) : OutcomeRel source rows (.exit code) (.exit code)

inductive OptionalOutcomeRel (source : Program) (rows : PredicateProjection.Table.Rows) : Option Outcome → Option Outcome → Prop where
  | none : OptionalOutcomeRel source rows none none
  | some {a b} : OutcomeRel source rows a b → OptionalOutcomeRel source rows (some a) (some b)

theorem OutcomeRel.refl {source rows} (outcome : Outcome) : OutcomeRel source rows outcome outcome := by
  cases outcome with
  | val value => exact .value (.refl value)
  | err message => exact .error message
  | exit code => exact .exit code

theorem OptionalOutcomeRel.refl {source rows} (outcome : Option Outcome) :
    OptionalOutcomeRel source rows outcome outcome := by
  cases outcome with
  | none => exact .none
  | some value => exact .some (.refl value)

theorem Values.length {source : Program} {rows vs ws} (h : Values source rows vs ws) : vs.length = ws.length := by
  cases h with
  | nil => rfl
  | cons _ tail => exact congrArg Nat.succ tail.length

theorem Values.append {source : Program} {rows vs ws xs ys} (h : Values source rows vs ws) (g : Values source rows xs ys) :
    Values source rows (vs ++ xs) (ws ++ ys) := by
  cases h with
  | nil => exact g
  | cons value tail => exact .cons value (tail.append g)

theorem Values.reverse {source : Program} {rows vs ws} (h : Values source rows vs ws) : Values source rows vs.reverse ws.reverse := by
  cases h with
  | nil => exact .nil
  | cons value tail =>
    simpa only [List.reverse_cons] using tail.reverse.append (.cons value .nil)

theorem Values.take {source : Program} {rows vs ws} (h : Values source rows vs ws) (n : Nat) :
    Values source rows (vs.take n) (ws.take n) := by
  cases h with
  | nil => simpa only [List.take_nil] using Values.nil (source := source) (rows := rows)
  | cons value tail => cases n with
    | zero => exact .nil
    | succ n => exact .cons value (tail.take n)

theorem Values.drop {source : Program} {rows vs ws} (h : Values source rows vs ws) (n : Nat) :
    Values source rows (vs.drop n) (ws.drop n) := by
  cases h with
  | nil => simpa only [List.drop_nil] using Values.nil (source := source) (rows := rows)
  | cons value tail => cases n with
    | zero => exact .cons value tail
    | succ n => exact tail.drop n

theorem Values.getElem? {source : Program} {rows vs ws} (h : Values source rows vs ws) (n : Nat) :
    OptionalValue source rows vs[n]? ws[n]? := by
  cases h with
  | nil => exact .none
  | cons value tail => cases n with
    | zero => exact .some value
    | succ n => exact tail.getElem? n

/-- コレクションの鍵の符号は、値の同じ有限観測から決まる。 -/
theorem Value.keyCode {source : Program} {rows v w} (h : Value source rows v w) :
    StandardCollections.valKeyCode v = StandardCollections.valKeyCode w := by
  simp only [StandardCollections.valKeyCode, h.toTerm]

def MapEntryRel (source : Program) (rows : PredicateProjection.Table.Rows)
    (a b : StandardCollections.MapEntry) : Prop :=
  a.code = b.code ∧ Value source rows a.key b.key ∧ Value source rows a.value b.value

inductive MapEntriesRel (source : Program) (rows : PredicateProjection.Table.Rows) :
    List StandardCollections.MapEntry → List StandardCollections.MapEntry → Prop where
  | nil : MapEntriesRel source rows [] []
  | cons {a b as bs} : MapEntryRel source rows a b → MapEntriesRel source rows as bs →
      MapEntriesRel source rows (a :: as) (b :: bs)

theorem MapEntriesRel.keys {source : Program} {rows as bs} (h : MapEntriesRel source rows as bs) :
    Values source rows (as.map StandardCollections.MapEntry.key) (bs.map StandardCollections.MapEntry.key) := by
  induction h with
  | nil => exact .nil
  | cons head _ ih => exact .cons head.2.1 ih

theorem MapEntriesRel.values {source : Program} {rows as bs} (h : MapEntriesRel source rows as bs) :
    Values source rows (as.map StandardCollections.MapEntry.value) (bs.map StandardCollections.MapEntry.value) := by
  induction h with
  | nil => exact .nil
  | cons head _ ih => exact .cons head.2.2 ih

/-- 同じ符号の鍵の追加又は値の置換は、キーと値の位置の対応を保つ。 -/
theorem MapEntriesRel.insert {source : Program} {rows as bs code key key' value value'}
    (h : MapEntriesRel source rows as bs) (hk : Value source rows key key') (hv : Value source rows value value') :
    MapEntriesRel source rows (StandardCollections.mapInsert code key value as)
      (StandardCollections.mapInsert code key' value' bs) := by
  induction h with
  | nil => exact .cons ⟨rfl,hk,hv⟩ .nil
  | @cons a b as bs head tail ih =>
    simp only [StandardCollections.mapInsert, head.1]
    split
    · exact .cons ⟨rfl, head.2.1, hv⟩ tail
    · exact .cons head ih

theorem MapEntriesRel.mapValue {source : Program} {rows as bs} (h : MapEntriesRel source rows as bs) :
    Value source rows (StandardCollections.mapValue as) (StandardCollections.mapValue bs) :=
  .map h.keys h.values

/-- 両幅の浮動小数の六判定は、対応する引数から同じBooleanを計算する。 -/
theorem floating_run {source : Program} {rows vs ws} (h : Values source rows vs ws)
    (width : FloatWidth) (test : PredicateResponse.FloatTest) :
    (PredicateResponse.API.floating width test).run vs =
      (PredicateResponse.API.floating width test).run ws := by
  cases h with
  | nil => rfl
  | cons head tail =>
    cases tail with
    | nil => cases head <;> cases width <;> rfl
    | cons value tail =>
      cases head with
      | constant c => cases c <;> cases width <;> rfl
      | _ => cases width <;> rfl

/-- 固定した浮動小数判定のδは、対応する引数に対して対応する応答を返す。 -/
theorem floating_delta {source : Program} {rows vs ws} (h : Values source rows vs ws)
    (width : FloatWidth) (test : PredicateResponse.FloatTest)
    (name : PrimName) (ts : List Ty) (es : List Eff) (rs : List RangeExpr) :
    OptionalOutcomeRel source rows ((PredicateResponse.API.floating width test).delta name ts es rs vs)
      ((PredicateResponse.API.floating width test).delta name ts es rs ws) := by
  unfold PredicateResponse.API.delta
  split
  · rw [floating_run h width test]
    exact .some (.value (.constant _))
  · exact .none

/-- 構造Equalityは有限観測を読むため、閉包の本体の対応に依存しない。 -/
theorem structural_equal {source : Program} {rows a b c d} (h : Value source rows a b) (g : Value source rows c d) :
    StandardListRemainingResponse.structuralEqual a c = StandardListRemainingResponse.structuralEqual b d := by
  simp only [StandardListRemainingResponse.structuralEqual, h.toTerm, g.toTerm]

/-- 構造比較の正常なBooleanとInternalComparisonの失敗をともに保つ。 -/
theorem equality_reply {source : Program} {rows a b c d} (h : Value source rows a b) (g : Value source rows c d) (equal : Bool) :
    OutcomeRel source rows (StandardStructuralEqualityResponse.reply equal a c)
      (StandardStructuralEqualityResponse.reply equal b d) := by
  unfold StandardStructuralEqualityResponse.reply
  rw [structural_equal h g]
  cases StandardListRemainingResponse.structuralEqual b d with
  | none => exact .error _
  | some _ => exact .value (.constant _)

/-- 外側の篩の動的検査は、対応する値の同じ有限観測から同じ真偽を得る。 -/
theorem check_accepts {source rows x y} (related : Value source rows x y) (type : Ty) :
    RefinementCheck.accepts x type = RefinementCheck.accepts y type := by
  cases type with
  | refined base predicate =>
    simp only [RefinementCheck.accepts, check_accepts related base, related.toTerm]
  | _ => rfl

theorem check_run {source rows x y} (related : Value source rows x y)
    (render : Ty → String) (input output : Ty) :
    OutcomeRel source rows (RefinementCheck.run render input output x)
      (RefinementCheck.run render input output y) := by
  unfold RefinementCheck.run
  rw [check_accepts related]
  split
  · exact .value (.con (.cons related .nil))
  · exact .refl _

end
end Benitoite.Release.Refinement.Surface.PredicateSimulation
