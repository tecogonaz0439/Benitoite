import Lean
import Benitoite.Interval.BudgetNormal
import Benitoite.Release.Refinement.ApproxAdapter

/-! 共有近似の入口の境界。定義は本番から読み、正例は具体入力から構成する。 -/
namespace L10A
open Benitoite Benitoite.Interval

-- 空の三表現はそれぞれ値を持たず、構造等号の一形へそろえる必要がない。
theorem three_empty (k : IntKind) :
    ∀ a ∈ [Shared.ValueApprox.bottom, .integer k .bottom, .boolean false false],
      a.WF ∧ a.possible = false ∧ ∀ v, ¬ a.Mem v := by
  intro a member
  simp only [List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl
  all_goals exact ⟨Shared.ValueApprox.wf _, rfl, (Shared.ValueApprox.not_possible_iff _).mp rfl⟩

-- 旧正常域の Integer64 と Boolean の所属を、具体値から往復する。
theorem normal_integer_roundtrip :
    let v : ConcreteValue := .integer ⟨5, by decide⟩
    (normalToShared (.base .integer) (normalize 5 5)).Mem v.toApprox ∧
      NormalMem (.base .integer) (normalize 5 5) v := by
  have normal : NormalMem (.base .integer) (normalize 5 5)
      (.integer ⟨5, by decide⟩) := by
    constructor
    · rfl
    · change Mem 5 (normalize 5 5)
      decide
  exact ⟨normalToShared_mem normal, (normalToShared_iff rfl).mp (normalToShared_mem normal)⟩

theorem normal_boolean_roundtrip :
    (normalToShared (.base .boolean) (false, true)).Mem (.boolean true) ∧
      NormalMem (.base .boolean) (false, true) (.boolean true) := by
  have shared : (normalToShared (.base .boolean) (false, true)).Mem
      (ConcreteValue.boolean true).toApprox := rfl
  exact ⟨shared, (normalToShared_iff rfl).mp shared⟩

-- unknown に粗くする型では、型一致を除く逆向きは成立しない。
theorem normal_type_required :
    (normalToShared (.base .unit) true).Mem (ConcreteValue.boolean true).toApprox ∧
      ¬ NormalMem (.base .unit) true (.boolean true) := by
  exact ⟨trivial, fun h => by cases h.1⟩

private def run (source : Surface.Expr) : BudgetAnalysis.Report :=
  BudgetAnalysis.analyzeExpr {} {} 5 (AbstractEnv.ofLocals []) ⟨"Boundary.shared", 0⟩ source

private def sumSource : Surface.Expr :=
  .binary .add (.base .integer)
    (.literal (.integer ⟨2, by decide⟩)) (.literal (.integer ⟨3, by decide⟩))

-- 実解析の出力を使い、5 の正常所属と 6 の非所属を独立の値で固定する。
theorem report_sum :
    let r := run sumSource
    r.coverage = .complete ∧
      (r.sharedFlow (.base .integer) .bottom).NormalMem
        (ConcreteValue.integer ⟨5, by decide⟩).toApprox ∧
      ¬ (r.sharedFlow (.base .integer) .bottom).NormalMem
        (ConcreteValue.integer ⟨6, by decide⟩).toApprox := by
  refine ⟨by cbv, ?_, ?_⟩
  · apply BudgetAnalysis.Report.shared_normal
    change (ConcreteValue.integer _).type = _ ∧ _
    refine ⟨rfl, ?_⟩
    change Mem 5 (run sumSource).approx.integer
    cbv
    constructor <;> constructor
  · simp only [BudgetAnalysis.Report.sharedFlow, Shared.FlowApprox.NormalMem,
      baseToShared, IntKind.ofType, BaseApprox.rangeKind, ConcreteValue.toApprox,
      Shared.ValueApprox.Mem, true_and]
    have actual : (run sumSource).approx.integer = normalize 5 5 := by cbv
    rw [actual, mem_normalize]
    simp [IntegerValue.toInt]

theorem report_width :
    let r := run (.literal (.unsignedInteger64 18446744073709551615))
    r.coverage = .complete ∧
      (r.sharedFlow (.base .unsignedInteger64) .bottom).NormalMem
      (ConcreteValue.unsignedInteger64 ⟨18446744073709551615, by decide⟩).toApprox := by
  refine ⟨by cbv, ?_⟩
  apply BudgetAnalysis.Report.shared_normal
  change (ConcreteValue.unsignedInteger64 _).type = _ ∧ _
  refine ⟨rfl, ?_⟩
  change _ = true ∧ Mem _ _
  constructor <;> cbv
  constructor <;> constructor

-- 抽象的な Report について先に証明し、具体計算は成分の等式だけへ限定する。
private theorem return_witness (r : BudgetAnalysis.Report)
    (emptyFlags : r.approx.boolean = (false, false)) :
    let f := r.sharedFlow (.base .boolean) (.boolean false true)
    f.normal.possible = false ∧ (∀ v, ¬ f.NormalMem v) ∧
      f.ResultMem (E := Unit) (.returned (.boolean true)) ∧
      ¬ (∀ result : Shared.EvalResult Shared.ApproxValue Unit, ¬ f.ResultMem result) := by
  have empty : (r.sharedFlow (.base .boolean) (.boolean false true)).normal.possible = false := by
    simp only [BudgetAnalysis.Report.sharedFlow, baseToShared, IntKind.ofType,
      Shared.ValueApprox.possible, emptyFlags, Bool.or_false]
  have absent := (Shared.ValueApprox.not_possible_iff
    (r.sharedFlow (.base .boolean) (.boolean false true)).normal).mp empty
  exact ⟨empty, absent, rfl, fun none => none (.returned (.boolean true)) rfl⟩

-- normal が空でも、明示した returned の値は共有近似に属する。
-- この returned は解析器が推論した範囲ではない。
theorem report_return :
    let r := run (.returnE (.base .boolean) (.literal (.boolean true)))
    let f := r.sharedFlow (.base .boolean) (.boolean false true)
    f.normal.possible = false ∧ (∀ v, ¬ f.NormalMem v) ∧
      f.ResultMem (E := Unit) (.returned (.boolean true)) ∧
      ¬ (∀ result : Shared.EvalResult Shared.ApproxValue Unit, ¬ f.ResultMem result) := by
  exact return_witness _ (by cbv)

private theorem unit_return_witness (r : BudgetAnalysis.Report)
    (emptyOther : r.approx.other = false) :
    let f := r.sharedFlow (.base .unit) (.integer .integer64 (normalize 7 7))
    f.normal.possible = false ∧ (∀ v, ¬ f.NormalMem v) ∧
      f.ReturnedMem (.integer .integer64 ⟨7, by decide⟩) := by
  have empty : (r.sharedFlow (.base .unit)
      (.integer .integer64 (normalize 7 7))).normal.possible = false := by
    simp [BudgetAnalysis.Report.sharedFlow, baseToShared, IntKind.ofType,
      emptyOther, Shared.ValueApprox.possible]
  have absent := (Shared.ValueApprox.not_possible_iff
    (r.sharedFlow (.base .unit) (.integer .integer64 (normalize 7 7))).normal).mp empty
  refine ⟨empty, absent, ?_⟩
  change _ = _ ∧ Mem 7 (normalize 7 7)
  exact ⟨rfl, by decide⟩

-- Unit は正常の位置の型であり、実際に返す Integer 7 の型と区別する。
theorem report_unit_return :
    let r := run (.returnE (.base .unit) (.literal (.integer ⟨7, by decide⟩)))
    let f := r.sharedFlow (.base .unit) (.integer .integer64 (normalize 7 7))
    r.coverage = .complete ∧ f.normal.possible = false ∧
      (∀ v, ¬ f.NormalMem v) ∧
      f.ReturnedMem (.integer .integer64 ⟨7, by decide⟩) := by
  exact ⟨by cbv, unit_return_witness _ (by cbv)⟩

private theorem failure_witness (r : BudgetAnalysis.Report)
    (emptyRange : r.approx.integer = .bottom) (mayFail : r.approx.mayFail = true) :
    let f := r.sharedFlow (.base .integer) .bottom
    f.normal.possible = false ∧ (∀ v, ¬ f.NormalMem v) ∧
      f.ResultMem (.failed ()) ∧
      ¬ (∀ result : Shared.EvalResult Shared.ApproxValue Unit, ¬ f.ResultMem result) := by
  have empty : (r.sharedFlow (.base .integer) .bottom).normal.possible = false := by
    simp only [BudgetAnalysis.Report.sharedFlow, baseToShared, IntKind.ofType,
      BaseApprox.rangeKind, emptyRange, Shared.ValueApprox.possible]
  have absent := (Shared.ValueApprox.not_possible_iff
    (r.sharedFlow (.base .integer) .bottom).normal).mp empty
  exact ⟨empty, absent, mayFail, fun none => none (.failed ()) mayFail⟩

-- あふれの実解析出力は正常値を持たず mayFail を保持する。
-- ResultMem は失敗理由の妥当性そのものを保証する判断ではない。
theorem report_failure :
    let r := run (.binary .add (.base .integer)
      (.literal (.integer ⟨9223372036854775807, by decide⟩))
      (.literal (.integer ⟨1, by decide⟩)))
    let f := r.sharedFlow (.base .integer) .bottom
    f.normal.possible = false ∧ (∀ v, ¬ f.NormalMem v) ∧
      f.ResultMem (.failed ()) ∧
      ¬ (∀ result : Shared.EvalResult Shared.ApproxValue Unit, ¬ f.ResultMem result) := by
  exact failure_witness _ (by cbv) (by cbv)

-- 七整数の上下端を、独立した数値の表で確認する。
private def endpoints : List (Release.Refinement.Const × IntKind × Int) :=
  [(.integer8 (-128), .integer8, -128), (.integer8 127, .integer8, 127),
   (.integer16 (-32768), .integer16, -32768), (.integer16 32767, .integer16, 32767),
   (.integer32 (-2147483648), .integer32, -2147483648),
   (.integer32 2147483647, .integer32, 2147483647),
   (.integer ⟨-9223372036854775808, by decide⟩, .integer64, -9223372036854775808),
   (.integer ⟨9223372036854775807, by decide⟩, .integer64, 9223372036854775807),
   (.unsignedInteger16 0, .unsignedInteger16, 0),
   (.unsignedInteger16 65535, .unsignedInteger16, 65535),
   (.unsignedInteger32 0, .unsignedInteger32, 0),
   (.unsignedInteger32 4294967295, .unsignedInteger32, 4294967295),
   (.unsignedInteger64 0, .unsignedInteger64, 0),
   (.unsignedInteger64 18446744073709551615, .unsignedInteger64, 18446744073709551615)]

theorem integer_endpoints (B : Release.Refinement.Builtins) :
    ∀ row ∈ endpoints, Release.Refinement.ConstOK B row.1 ∧
      IntKind.ofRefinementType row.1.type = some row.2.1 ∧
      ∃ n : IntegerValue row.2.1, row.1.toApprox = .integer row.2.1 n ∧
        n.toInt = row.2.2 := by
  intro row member
  simp only [endpoints, List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl |
    rfl | rfl | rfl | rfl | rfl | rfl
  all_goals
    refine ⟨by simp [Release.Refinement.ConstOK], rfl,
      ⟨⟨_, by decide⟩, ?_, rfl⟩⟩
    simp [Release.Refinement.Const.toApprox, Shared.ApproxValue.ofInt]

theorem integer_endpoint_entry (B : Release.Refinement.Builtins)
    (row : Release.Refinement.Const × IntKind × Int) (member : row ∈ endpoints) :
    ∃ n : IntegerValue row.2.1, row.1.toApprox = .integer row.2.1 n :=
  Release.Refinement.constOK_toApprox (integer_endpoints B row member).1
    (integer_endpoints B row member).2.1

theorem non_integer_other (B : Release.Refinement.Builtins) :
    Release.Refinement.ConstOK B (.byte 255) ∧ Release.Refinement.ConstOK B (.decimal 79228162514264337593543950335 28) ∧
      (Release.Refinement.Const.byte 255).toApprox = .other ∧
      (Release.Refinement.Const.decimal 79228162514264337593543950335 28).toApprox = .other := by
  exact ⟨by simp [Release.Refinement.ConstOK],
    by simp [Release.Refinement.ConstOK], rfl, rfl⟩

theorem outside_integer :
    ¬ Release.Refinement.ConstOK B (.integer8 128) ∧
      (Release.Refinement.Const.integer8 128).toApprox = .other ∧
      ¬ Release.Refinement.ConstOK B (.unsignedInteger64 (-1)) ∧
      (Release.Refinement.Const.unsignedInteger64 (-1)).toApprox = .other := by
  simp [Release.Refinement.ConstOK, Release.Refinement.Const.toApprox,
    Shared.ApproxValue.ofInt, IntKind.min, IntKind.max]

theorem byte_outside (B : Release.Refinement.Builtins) :
    ¬ Release.Refinement.ConstOK B (.byte 256) := by
  simp [Release.Refinement.ConstOK]

-- 上端・scale 28 の既存例と合わせ、両端・係数の外・scale の外を確認する。
theorem decimal_bounds (B : Release.Refinement.Builtins) :
    Release.Refinement.ConstOK B (.decimal (-79228162514264337593543950335) 28) ∧
      ¬ Release.Refinement.ConstOK B (.decimal (-79228162514264337593543950336) 0) ∧
      ¬ Release.Refinement.ConstOK B (.decimal 1 29) := by
  simp [Release.Refinement.ConstOK]

end L10A

-- 境界の補助と証明を含め、現在の入力で加わった全宣言を監査する。
open Lean Elab Command in
run_cmd do
  let env ← getEnv
  let names := (env.constants.toList.filterMap fun (name, _) =>
    if env.getModuleIdxFor? name == none then some name else none).mergeSort
      (fun a b => a.toString < b.toString)
  logInfo m!"AUDIT_BOUNDARY {names.length}"
  for name in names do
    elabCommand (← `(#print axioms $(mkIdent name)))
