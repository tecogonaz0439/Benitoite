import Benitoite.Interval.Range
import Benitoite.Interval.EvalClosed
import Benitoite.Interval.BudgetWhole

/-!
# 土台と七種の整数の評価・解析の独立例

同じ Surface 入力を二つの実際の入口へ渡す。期待する値・引数・演算・キーは
手で固定し、解析結果から評価の期待値を作らない。VM との一致は扱わない
（設計書 01-12「区間解析の閉じた対象入力の評価」）。
-/
namespace Benitoite.Interval.Examples
open Benitoite.Surface Benitoite.Release BudgetAnalysis

private def concrete : ConcreteEnv := ⟨[], [], fun _ => none⟩
private def abstract := AbstractEnv.ofLocals []
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
private def division : Expr := .binary .intDiv (.base .integer) one zero
private def overflow : Expr := .binary .add (.base .integer) maximum one
private def key (n : Nat) : OperationKey := ⟨"C1.examples", n⟩
private def input (source : Expr) (type : Ty := .base .integer) : EvalInput :=
  ⟨source, type, key 0⟩
private def run (i : EvalInput) (env : AbstractEnv := abstract) : Report :=
  analyzeExpr {} {} 64 env i.key i.source

-- 関数型を含む具体値全体の等号を決定せず、観察する基本値を取り出す。
private inductive ValueView where
  | integer (value : Int) | boolean (value : Bool) | unit | other
  deriving DecidableEq
private def valueView : ConcreteValue → ValueView
  | .integer n => .integer n.toInt
  | .boolean b => .boolean b
  | .unit => .unit
  | _ => .other
private inductive OutcomeView where
  | normal (value : ValueView) | failed (reason : Failure) | returned (value : ValueView)
  deriving DecidableEq
private def outcomeView : EvalOutcome → OutcomeView
  | .normal v => .normal (valueView v)
  | .failed r => .failed r
  | .returned v => .returned (valueView v)
private def binaryOp : TargetOperation → Option BinOp
  | .binary op (.base .integer) => some op
  | _ => none
private structure EventView where
  key : OperationKey
  operation : Option BinOp
  arguments : List ValueView
  outcome : OutcomeView
  deriving DecidableEq
private def observe (i : EvalInput) (env : ConcreteEnv := concrete) :=
  (evalClosed env i 16).map fun result =>
    (outcomeView result.outcome, result.trace.map fun event =>
      (⟨event.key, binaryOp event.operation, event.arguments.map valueView,
        match event.result with
        | .normal v => OutcomeView.normal (valueView v)
        | .rejected r => OutcomeView.failed r⟩ : EventView))
private def warnings (r : Report) := r.approx.warnings.map fun w =>
  (w.key, binaryOp w.operation, w.cause)

-- and/or を表で確認する。右辺へ進む場合だけ除数0に到達し、
-- 到達記録には正常に得た二引数と、実際の失敗原因が残る。
#guard
    let rhs : Expr := .binary .eq (.base .integer) division zero
    let inputs := [input (.and (.literal (.boolean false)) rhs) (.base .boolean),
      input (.or (.literal (.boolean true)) rhs) (.base .boolean),
      input (.and (.literal (.boolean true)) rhs) (.base .boolean),
      input (.or (.literal (.boolean false)) rhs) (.base .boolean)]
    inputs.map observe =
      [some (.normal (.boolean false), []), some (.normal (.boolean true), []),
       some (.failed .zeroDivisor,
         [⟨key 3, some .intDiv, [.integer 1, .integer 0], .failed .zeroDivisor⟩]),
       some (.failed .zeroDivisor,
         [⟨key 3, some .intDiv, [.integer 1, .integer 0], .failed .zeroDivisor⟩])] ∧
    (inputs.map fun i => warnings (run i)) =
      [[], [], [(key 3, some .intDiv, .zeroDivisor)],
        [(key 3, some .intDiv, .zeroDivisor)]]

-- 最初の腕の変数7で guard を評価し、偽なら元の局所値3に戻る。
-- 未選択のあふれを飛ばした後の加算の番号は詰めない。
private def guarded : EvalInput := input (.matchE (.base .integer)
  (.literal (.integer ⟨7, by decide⟩))
  (.cons [⟨.var, [0]⟩] (some (.binary .eq (.base .integer) (.local 0) zero))
    (.last overflow)
    (.cons [⟨.wild, []⟩] none
      (.last (.binary .add (.base .integer) (.local 0) one)) .nil)))
#guard
    let env : ConcreteEnv := ⟨[some (.integer ⟨3, by decide⟩)], [], fun _ => none⟩
    let result := run guarded (AbstractEnv.ofLocals [.integer (normalize 3 3)])
    observe guarded env = some (.normal (.integer 4),
      [⟨key 2, some .eq, [.integer 7, .integer 0], .normal (.boolean false)⟩,
       ⟨key 8, some .add, [.integer 3, .integer 1], .normal (.integer 4)⟩]) ∧
    result.coverage = .complete ∧ result.approx.integer = normalize 4 4 ∧
    warnings result = []

-- shadow は先頭に新しい位置を加え、別名として保存した古い位置も読める。
private def shadowBody : Block := .bind .bind (.base .integer) one
  (.bind .shadow (.base .integer) zero
    (.last (.binary .add (.base .integer) (.local 0) (.local 1))))
private def shadowed : EvalInput := input (bodyRoot shadowBody)
#guard
    observe shadowed = some (.normal (.integer 1),
      [⟨key 3, some .add, [.integer 0, .integer 1], .normal (.integer 1)⟩]) ∧
    (run shadowed).approx.integer = normalize 1 1 ∧
    warnings (run shadowed) = []

-- return のオペランドの値と trace を残し、後続の除数0には到達しない。
#guard
    let i := input (.block (.discard
      (.returnE (.base .integer) (.binary .add (.base .integer) one one)) (.last division)))
    observe i = some (.returned (.integer 2),
      [⟨key 2, some .add, [.integer 1, .integer 1], .normal (.integer 2)⟩]) ∧
    (run i).approx.live = false ∧ warnings (run i) = []

-- 外で0と分かっていても、捕捉を含む式自体は評価不能にし、
-- 別本体の入口では区間を忘れる。ラムダを任意の一値へ決めない。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 0)]
    let captured : ConcreteEnv := ⟨[some (.integer ⟨0, by decide⟩)], [], fun _ => none⟩
    let body : Block := .last (.binary .intDiv (.base .integer) one (.local 0))
    let boundary := input (.lam [] [] (.base .integer) Eff.empty body)
      (.fn [] [] (.base .integer) Eff.empty)
    let result := analyzeBody {} {} 64 "Example.c1" ⟨.lambda, body, env⟩
    (observe boundary captured).isNone = true ∧ (run boundary env).coverage = .unsupported ∧
    warnings (run boundary env) = [] ∧ result.coverage = .complete ∧
    result.approx.integer = top ∧ warnings result = [] ∧
    warnings (run (input (.binary .intDiv (.base .integer) one (.local 0))) env) =
      [(key 0, some .intDiv, .zeroDivisor)]

-- 評価は最初の除算で失敗する。解析はその警告を保存した後に停止し、
-- 後続のあふれを新たに報告せず、正常値だけ Top に退く。
private def stoppedInput := input (.block (.discard division (.last overflow)))
private def smallLimits : Budget.Limits := ⟨⟨10, 100⟩, ⟨10000, 10000⟩⟩
example :
    let result := analyzeExpr smallLimits {} 16 abstract stoppedInput.key stoppedInput.source
    observe stoppedInput = some (.failed .zeroDivisor,
      [⟨key 1, some .intDiv, [.integer 1, .integer 0], .failed .zeroDivisor⟩]) ∧
    result.coverage = .stopped (.budget (.unidentified ⟨.body, .operations⟩)) ∧
    result.approx.integer = top ∧ warnings result = [(key 1, some .intDiv, .zeroDivisor)] :=
  by decide +kernel

-- 計算した評価導出を本体入口の系へ渡す。正常値の保存は深さ0・
-- 初期消費あり・上限超過を含む任意の解析予算について成り立つ。
example (parameters : Parameters) :
    (analyzeBody parameters.limits parameters.state parameters.fuel "C1.examples"
      ⟨.function, shadowBody, abstract⟩).approx.Contains (.integer ⟨1, by decide⟩) := by
  have evaluated : EvalPartial concrete shadowed (.normal (.integer ⟨1, by decide⟩)) _ :=
    ((evalClosed concrete shadowed 16).get (by decide)).sound
  exact analyzeBody_normal parameters.limits parameters.state parameters.fuel "C1.examples"
    (show Models (forget abstract) concrete from ⟨.nil, rfl, rfl⟩) evaluated _ rfl

-- 停止後に残る警告に対しても、実際の同じキー・演算への到達を使う。
-- 警告健全性を、到達記録のない入力への含意だけで済ませない。
example :
    let result := analyzeBody smallLimits {} 16 "C1.examples"
      ⟨.function, .discard division (.last overflow), abstract⟩
    ∃ warning ∈ result.approx.warnings, ∃ event,
      Reached ((evalClosed concrete stoppedInput 16).get (by decide)).trace warning event ∧
      event.result = .rejected warning.cause.toFailure := by
  let evaluated := (evalClosed concrete stoppedInput 16).get (by decide)
  let warning : IntervalWarning := ⟨key 1, .binary .intDiv (.base .integer), .zeroDivisor⟩
  let event : EvalEvent := ⟨key 1, .binary .intDiv (.base .integer),
    [.integer ⟨1, by decide⟩, .integer ⟨0, by decide⟩], .rejected .zeroDivisor⟩
  have member : warning ∈
      (analyzeBody smallLimits {} 16 "C1.examples"
        ⟨.function, .discard division (.last overflow), abstract⟩).approx.warnings :=
    by cbv; exact List.mem_cons_self
  have reached : Reached evaluated.trace warning event := by
    exact ⟨List.mem_cons_self, rfl, rfl⟩
  refine ⟨warning, member, event, reached, ?_⟩
  exact analyzeBody_warning_sound smallLimits {} 16 "C1.examples"
    (show Models (forget abstract) concrete from ⟨.nil, rfl, rfl⟩)
    evaluated.sound warning member event reached

-- 局所算術の補題だけでは、式全体や予算付き入口への接続漏れを検出できない。
-- 同じ入力を両入口へ渡し、端点と警告位置を十進値で独立に固定する。
#guard
    let minimum : Expr := .negInt ⟨9223372036854775808, by decide⟩
    let minusThree : Expr := .negInt ⟨3, by decide⟩
    let localEnv := AbstractEnv.ofLocals [.integer (normalize (-2) 4)]
    let cases : List Expr := [
      .binary .sub (.base .integer) (.local 0) one,
      .neg (.base .integer) (.local 0),
      .binary .mul (.base .integer) (.local 0) minusThree,
      .binary .mul (.base .integer) minusThree (.local 0),
      .binary .mul (.base .integer) (.local 0) (.local 0),
      .binary .mul (.base .integer) zero (.local 0),
      .binary .sub (.base .integer) minimum one,
      .neg (.base .integer) minimum,
      .neg (.base .integer) (.binary .sub (.base .integer) minimum one),
      .binary .intDiv (.base .integer) one (.binary .sub (.base .integer) one one)]
    let expected : List (Interval × List (Nat × WarningCause)) := [
      (normalize (-3) 3, []), (normalize (-4) 2, []),
      (normalize (-12) 6, []), (normalize (-12) 6, []),
      (top, []), (normalize 0 0, []),
      (.bottom, [(0, .overflow)]), (.bottom, [(0, .overflow)]),
      (.bottom, [(1, .overflow)]), (top, [(0, .zeroDivisor)])]
    let project := fun result : BaseApprox =>
      (result.integer, result.warnings.map fun w => (w.key.surfacePreorder, w.cause))
    (cases.map fun source => project (analyzeBaseExpr 32 localEnv (key 0) source)) = expected ∧
    (cases.map fun source => project (analyzeExpr {} {} 32 localEnv (key 0) source).approx) = expected

-- 閉じた具体評価は新しい演算の値と拒否を返す。中間失敗・return は親の事象を作らない。
-- 原因と番号の期待を解析から作らず、実行結果を直接読む。
#guard
    let minimum : Expr := .negInt ⟨9223372036854775808, by decide⟩
    let cases : List Expr := [
      .binary .sub (.base .integer) zero one,
      .binary .mul (.base .integer) (.negInt ⟨3, by decide⟩)
        (.literal (.integer ⟨2, by decide⟩)),
      .neg (.base .integer) one,
      .neg (.base .integer) minimum,
      .neg (.base .integer) (.binary .sub (.base .integer) minimum one),
      .binary .mul (.base .integer) (.returnE (.base .integer) one) overflow]
    let project := fun source =>
      match evalClosed concrete (input source) 32 with
      | none => (none, none, ([] : List Nat))
      | some evaluated =>
        let normal := match evaluated.outcome with
          | .normal (.integer value) => some value.toInt
          | _ => none
        let failure := match evaluated.outcome with
          | .failed cause => some cause
          | _ => none
        (normal, failure, evaluated.trace.map fun e => e.key.surfacePreorder)
    cases.map project = [
      (some (-1), none, [0]), (some (-6), none, [0]),
      (some (-1), none, [0]), (none, some .overflow, [0]),
      (none, some .overflow, [1]), (none, none, [])]

-- 幅付きの葉を実際の評価・土台・予算付きの入口で比較する。
-- 各幅の十進の端点は、値域表や解析結果から生成しない。
private def widthValue : ConcreteValue → Option (IntKind × Int)
  | .integer n => some (.integer64, n.toInt)
  | .integer8 n => some (.integer8, n.toInt)
  | .integer16 n => some (.integer16, n.toInt)
  | .integer32 n => some (.integer32, n.toInt)
  | .unsignedInteger16 n => some (.unsignedInteger16, n.toInt)
  | .unsignedInteger32 n => some (.unsignedInteger32, n.toInt)
  | .unsignedInteger64 n => some (.unsignedInteger64, n.toInt)
  | _ => none

private def endpoints {kind : IntKind} : Interval kind → Option (Int × Int)
  | .bottom => none
  | .closed lo hi _ => some (lo, hi)

#guard
    let rows : List (IntKind × Expr × Int) := [
      (.integer8, .literal (.integer8 127), 127),
      (.integer16, .literal (.integer16 32767), 32767),
      (.integer32, .literal (.integer32 2147483647), 2147483647),
      (.unsignedInteger16, .literal (.unsignedInteger16 65535), 65535),
      (.unsignedInteger32, .literal (.unsignedInteger32 4294967295), 4294967295),
      (.unsignedInteger64, .literal (.unsignedInteger64 18446744073709551615), 18446744073709551615),
      (.integer8, .negInteger8 128, -128),
      (.integer16, .negInteger16 32768, -32768),
      (.integer32, .negInteger32 2147483648, -2147483648)]
    rows.all (fun (kind, source, expected) =>
      let evaluated := (evalClosed concrete (input source kind.type) 16).bind fun result =>
        match result.outcome with
        | .normal value => (widthValue value).map fun pair => (pair, result.trace.length)
        | _ => none
      let base := analyzeBaseExpr 16 abstract (key 0) source
      let budget := run (input source kind.type)
      evaluated == some ((kind, expected), 0) &&
      endpoints (base.rangeKind kind) == some (expected, expected) &&
      endpoints (budget.approx.rangeKind kind) == some (expected, expected) &&
      budget.coverage == .complete && budget.approx.warnings.isEmpty) = true

-- 値域外の Nat は、型検査済みの値であるかのように具体化しない。
-- Top の端点は独立した十進値と比較し、失敗を Bottom と混同しない。
#guard
    let rows : List (IntKind × Expr × (Int × Int)) := [
      (.integer8, .literal (.integer8 128), (-128, 127)),
      (.integer16, .literal (.integer16 32768), (-32768, 32767)),
      (.integer32, .literal (.integer32 2147483648), (-2147483648, 2147483647)),
      (.unsignedInteger16, .literal (.unsignedInteger16 65536), (0, 65535)),
      (.unsignedInteger32, .literal (.unsignedInteger32 4294967296), (0, 4294967295)),
      (.unsignedInteger64, .literal (.unsignedInteger64 18446744073709551616), (0, 18446744073709551615)),
      (.integer8, .negInteger8 129, (-128, 127)),
      (.integer16, .negInteger16 32769, (-32768, 32767)),
      (.integer32, .negInteger32 2147483649, (-2147483648, 2147483647))]
    rows.all (fun (kind, source, expected) =>
      let budget := run (input source kind.type)
      (evalClosed concrete (input source kind.type) 16).isNone &&
      endpoints (budget.approx.rangeKind kind) == some expected &&
      budget.coverage == .unsupported && budget.approx.live &&
      budget.approx.warnings.isEmpty) = true

-- 六幅の別名を保存した後で shadow しても、古い別名は元の値を保つ。
-- 捕捉の入口ではその事実を捨て、真偽が未知の枝では両方の正常値を合流する。
#guard
    let rows : List (IntKind × Expr × Expr × (Int × Int)) := [
      (.integer8, .negInteger8 128, .literal (.integer8 127), (-128, 127)),
      (.integer16, .negInteger16 32768, .literal (.integer16 32767), (-32768, 32767)),
      (.integer32, .negInteger32 2147483648, .literal (.integer32 2147483647), (-2147483648, 2147483647)),
      (.unsignedInteger16, .literal (.unsignedInteger16 0), .literal (.unsignedInteger16 65535), (0, 65535)),
      (.unsignedInteger32, .literal (.unsignedInteger32 0), .literal (.unsignedInteger32 4294967295), (0, 4294967295)),
      (.unsignedInteger64, .literal (.unsignedInteger64 0), .literal (.unsignedInteger64 18446744073709551615), (0, 18446744073709551615))]
    rows.all (fun (kind, lo, hi, expected) =>
      let source : Expr := .block (.bind .bind kind.type lo
        (.bind .bind kind.type (.local 0)
          (.bind .shadow kind.type hi (.last (.local 1)))))
      let seed := baseBind .bind abstract kind.type (analyzeBaseExpr 16 abstract (key 0) lo)
      let captured := analyzeBody {} {} 32 "width.captured" ⟨.lambda, .last (.local 0), seed⟩
      let joined := run (input (.ite (.local 0) (.last (.local 1)) (.last (.local 2))) kind.type)
        (AbstractEnv.ofLocals [.unknown (some (.base .boolean)),
          integerKindSlot kind (normalize 1 1 kind), integerKindSlot kind (normalize 3 3 kind)])
      endpoints ((run (input source kind.type)).approx.rangeKind kind) ==
        some (expected.1, expected.1) &&
      endpoints (captured.approx.rangeKind kind) == some expected &&
      captured.coverage == .complete &&
      endpoints (joined.approx.rangeKind kind) == some (1, 3) &&
      joined.coverage == .complete) = true

-- 幅付き演算は、葉の値だけでなく、演算後の型・引数・結果・到達位置も保つ。
-- 正常値の観察では幅を消さず、失敗とreturnを別の結果として固定する。
private inductive WidthOutcome where
  | normal (kind : IntKind) (value : Int)
  | failed (reason : Failure)
  | returned (kind : IntKind) (value : Int)
  | other
  deriving DecidableEq

private def widthOutcome : EvalOutcome → WidthOutcome
  | .normal value => match widthValue value with
      | some (kind, n) => .normal kind n | none => .other
  | .failed reason => .failed reason
  | .returned value => match widthValue value with
      | some (kind, n) => .returned kind n | none => .other

private def widthOperation : TargetOperation → Option (Option BinOp × IntKind)
  | .binary op type => (IntKind.ofType type).map fun kind => (some op, kind)
  | .neg type => (IntKind.ofType type).map fun kind => (none, kind)
  | _ => none

private structure WidthEvent where
  key : OperationKey
  operation : Option (Option BinOp × IntKind)
  arguments : List (Option (IntKind × Int))
  outcome : WidthOutcome
  deriving DecidableEq

private def observeWidth (i : EvalInput) (env : ConcreteEnv := concrete) :=
  (evalClosed env i 32).map fun result =>
    (widthOutcome result.outcome, result.trace.map fun event =>
      (⟨event.key, widthOperation event.operation, event.arguments.map widthValue,
        match event.result with
        | .normal value => widthOutcome (.normal value)
        | .rejected reason => WidthOutcome.failed reason⟩ : WidthEvent))

private def widthWarnings (report : Report) := report.approx.warnings.map fun warning =>
  (warning.key, widthOperation warning.operation, warning.cause)

-- 型の値域の期待は十進値で与える。商と剰余の解析は正常値をTopに退け、
-- 具体評価だけを一点に決める。加減乗はそれぞれ独立した正常値を返す。
private def widthSeeds : List (IntKind × Expr × Expr × Expr × (Int × Int)) := [
  (.integer8, .literal (.integer8 0), .literal (.integer8 1), .literal (.integer8 2), (-128, 127)),
  (.integer16, .literal (.integer16 0), .literal (.integer16 1), .literal (.integer16 2), (-32768, 32767)),
  (.integer32, .literal (.integer32 0), .literal (.integer32 1), .literal (.integer32 2), (-2147483648, 2147483647)),
  (.unsignedInteger16, .literal (.unsignedInteger16 0), .literal (.unsignedInteger16 1),
    .literal (.unsignedInteger16 2), (0, 65535)),
  (.unsignedInteger32, .literal (.unsignedInteger32 0), .literal (.unsignedInteger32 1),
    .literal (.unsignedInteger32 2), (0, 4294967295)),
  (.unsignedInteger64, .literal (.unsignedInteger64 0), .literal (.unsignedInteger64 1),
    .literal (.unsignedInteger64 2), (0, 18446744073709551615))]

#guard
    widthSeeds.all (fun (kind, _, one, two, bounds) =>
      let cases : List (BinOp × Expr × Expr × Int × Int × Int × Bool) := [
        (.add, one, two, 1, 2, 3, false), (.sub, two, one, 2, 1, 1, false),
        (.mul, two, one, 2, 1, 2, false), (.intDiv, two, one, 2, 1, 2, true),
        (.mod, two, one, 2, 1, 0, true)]
      cases.all (fun (op, left, right, a, b, expected, coarse) =>
        let i := input (.binary op kind.type left right) kind.type
        let report := run i
        observeWidth i == some (.normal kind expected,
          [⟨key 0, some (some op, kind), [some (kind, a), some (kind, b)],
            .normal kind expected⟩]) &&
        endpoints (report.approx.rangeKind kind) ==
          some (if coarse then bounds else (expected, expected)) &&
        report.coverage == .complete && report.approx.warnings.isEmpty)) = true

-- 0除算の警告は、六幅それぞれの演算と正常に得た引数に対応する。
-- 一般負号の子で失敗した場合とreturnした場合には、負号自身へ到達しない。
#guard
    widthSeeds.all (fun (kind, zero, one, _, bounds) =>
      let source : Expr := .binary .intDiv kind.type one zero
      let i := input source kind.type
      let report := run i
      observeWidth i == some (.failed .zeroDivisor,
        [⟨key 0, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)],
          .failed .zeroDivisor⟩]) &&
      endpoints (report.approx.rangeKind kind) == some bounds &&
      widthWarnings report == [(key 0, some (some .intDiv, kind), .zeroDivisor)] &&
      report.coverage == .complete) = true

-- 最小値の負号、符号なしの下限割れ、最大u64の積は、同じoverflowでも
-- 元の演算と幅を警告に残す。親演算と未知評価の重複導出を認めない。
#guard
    let rows : List (IntKind × Expr × Option BinOp × List Int) := [
      (.integer8, .neg (.base .integer8) (.negInteger8 128), none, [-128]),
      (.integer16, .neg (.base .integer16) (.negInteger16 32768), none, [-32768]),
      (.integer32, .neg (.base .integer32) (.negInteger32 2147483648), none, [-2147483648]),
      (.unsignedInteger16, .binary .sub (.base .unsignedInteger16)
        (.literal (.unsignedInteger16 0)) (.literal (.unsignedInteger16 1)), some .sub, [0, 1]),
      (.unsignedInteger32, .binary .sub (.base .unsignedInteger32)
        (.literal (.unsignedInteger32 0)) (.literal (.unsignedInteger32 1)), some .sub, [0, 1]),
      (.unsignedInteger64, .binary .sub (.base .unsignedInteger64)
        (.literal (.unsignedInteger64 0)) (.literal (.unsignedInteger64 1)), some .sub, [0, 1]),
      (.unsignedInteger64, .binary .mul (.base .unsignedInteger64)
        (.literal (.unsignedInteger64 18446744073709551615))
        (.literal (.unsignedInteger64 18446744073709551615)), some .mul,
        [18446744073709551615, 18446744073709551615])]
    rows.all (fun (kind, source, op, args) =>
      let i := input source kind.type
      let report := run i
      observeWidth i == some (.failed .overflow,
        [⟨key 0, some (op, kind), args.map (fun n => some (kind, n)), .failed .overflow⟩]) &&
      endpoints (report.approx.rangeKind kind) == none &&
      widthWarnings report == [(key 0, some (op, kind), .overflow)] &&
      report.coverage == .complete) = true

#guard
    let rows : List (IntKind × Expr × Expr) := [
      (.integer8, .literal (.integer8 0), .literal (.integer8 1)),
      (.integer16, .literal (.integer16 0), .literal (.integer16 1)),
      (.integer32, .literal (.integer32 0), .literal (.integer32 1))]
    rows.all (fun (kind, zero, one) =>
      let failure := input (.neg kind.type (.binary .intDiv kind.type one zero)) kind.type
      let returned := input (.neg kind.type (.returnE kind.type one)) kind.type
      let normal := input (.neg kind.type one) kind.type
      observeWidth normal == some (.normal kind (-1),
        [⟨key 0, some (none, kind), [some (kind, 1)], .normal kind (-1)⟩]) &&
      endpoints ((run normal).approx.rangeKind kind) == some (-1, -1) &&
      (run normal).coverage == .complete &&
      observeWidth failure == some (.failed .zeroDivisor,
        [⟨key 1, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)],
          .failed .zeroDivisor⟩]) &&
      widthWarnings (run failure) == [(key 1, some (some .intDiv, kind), .zeroDivisor)] &&
      observeWidth returned == some (.returned kind 1, []) &&
      (run returned).approx.warnings.isEmpty) = true

-- 二項の左右どちらで異常終了しても、親演算をtraceへ足さない。
-- 左のreturnでは未評価の右の0除算を飛ばし、右のreturnはその値を保つ。
example :
    widthSeeds.all (fun (kind, zero, one, two, _) =>
      let bad : Expr := .binary .intDiv kind.type one zero
      let leftReturn := input (.binary .mul kind.type (.returnE kind.type one) bad) kind.type
      let rightReturn := input (.binary .mul kind.type one (.returnE kind.type two)) kind.type
      let leftFailure := input (.binary .add kind.type bad two) kind.type
      let rightFailure := input (.binary .add kind.type one bad) kind.type
      observeWidth leftReturn == some (.returned kind 1, []) &&
      observeWidth rightReturn == some (.returned kind 2, []) &&
      observeWidth leftFailure == some (.failed .zeroDivisor,
        [⟨key 1, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)],
          .failed .zeroDivisor⟩]) &&
      observeWidth rightFailure == some (.failed .zeroDivisor,
        [⟨key 2, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)],
          .failed .zeroDivisor⟩])) = true := by
  decide +kernel

-- 二つの変数の積と一般の商・剰余は、具体値から正解の一点を作れても、
-- 区間をTopに退ける。局所値2と抽象区間[1,3]を別々に入力する。
#guard
    widthSeeds.all (fun (kind, _, _, _, bounds) =>
      let env := AbstractEnv.ofLocals [integerKindSlot kind (normalize 1 3 kind)]
      let value := ConcreteValue.ofInteger kind ⟨2, by cases kind <;> decide⟩
      let concreteEnv : ConcreteEnv := ⟨[some value], [], fun _ => none⟩
      let cases : List (BinOp × Int) := [(.mul, 4), (.intDiv, 1), (.mod, 0)]
      cases.all (fun (op, expected) =>
        let i := input (.binary op kind.type (.local 0) (.local 0)) kind.type
        let report := run i env
        observeWidth i concreteEnv == some (.normal kind expected,
          [⟨key 0, some (some op, kind), [some (kind, 2), some (kind, 2)],
            .normal kind expected⟩]) &&
        endpoints (report.approx.rangeKind kind) == some bounds &&
        report.approx.warnings.isEmpty && report.coverage == .complete)) = true

end Benitoite.Interval.Examples

namespace Benitoite.Interval.KindConditionExamples
open Benitoite.Surface Benitoite.Release BudgetAnalysis

private def endpoints {kind : IntKind} : Interval kind → Option (Int × Int)
  | .bottom => none
  | .closed lo hi _ => some (lo, hi)

private def seeds : List (IntKind × Expr × Expr × Int) := [
  (.integer8, .literal (.integer8 0), .literal (.integer8 2), -5),
  (.integer16, .literal (.integer16 0), .literal (.integer16 2), -5),
  (.integer32, .literal (.integer32 0), .literal (.integer32 2), -5),
  (.unsignedInteger16, .literal (.unsignedInteger16 0), .literal (.unsignedInteger16 2), 0),
  (.unsignedInteger32, .literal (.unsignedInteger32 0), .literal (.unsignedInteger32 2), 0),
  (.unsignedInteger64, .literal (.unsignedInteger64 0), .literal (.unsignedInteger64 2), 0)]

private def environment (kind : IntKind) (lo : Int) : AbstractEnv :=
  AbstractEnv.ofLocals [integerKindSlot kind (normalize lo 5 kind),
    integerKindSlot kind (normalize lo 5 kind)]

private def readCondition (kind : IntKind) (lo : Int) (source : Expr) (truth : Bool) :=
  (conditionEnv (environment kind lo) source truth).map fun inner =>
    (endpoints (integerKindAt inner kind 0), endpoints (integerKindAt inner kind 1))

-- 六幅の同型定数と反転を認定し、constと括弧を通しても同じ一位置を選ぶ。
-- 真の経路の合流は[0,2]となり、別名の位置1へ逆向きに伝播しない。
example :
    seeds.all (fun (kind, zero, two, lo) =>
      let low : Expr := .binary .ge kind.type (.paren (.local 0))
        (.constE kind.type (.paren zero))
      let high : Expr := .binary .le kind.type (.local 0) two
      let reverse : Expr := .paren (.binary .gt kind.type two (.paren (.local 0)))
      let either : Expr := .or (.binary .eq kind.type (.local 0) zero)
        (.binary .eq kind.type (.local 0) two)
      comparisonKindAt low == some ⟨kind, 0, .ge, 0⟩ &&
      comparisonKindAt reverse == some ⟨kind, 0, .lt, 2⟩ &&
      [(low, true), (reverse, true), (.not low, false),
        (.and low high, true), (either, true)].map (fun (source, truth) =>
          readCondition kind lo source truth) ==
        [some (some (0, 5), some (lo, 5)),
         some (some (lo, 1), some (lo, 5)),
         some (some (0, 5), some (lo, 5)),
         some (some (0, 2), some (lo, 5)),
         some (some (0, 2), some (lo, 5))]) = true := by
  decide +kernel

-- 型違い・値域外・二つの局所参照・Byteからは一位置の比較を作らない。
-- 負の定数は小さい符号付き幅の最小値まで認め、隣の値を拒否する。
example :
    let rejected : List Expr := [
      .binary .lt (.base .integer8) (.local 0) (.literal (.unsignedInteger64 0)),
      .binary .lt (.base .unsignedInteger64) (.local 0) (.literal (.integer8 0)),
      .binary .lt (.base .integer8) (.local 0)
        (.constE (.base .integer16) (.literal (.integer8 0))),
      .binary .lt (.base .integer8) (.local 0) (.literal (.integer8 128)),
      .binary .lt (.base .integer8) (.local 0) (.negInteger8 129),
      .binary .lt (.base .integer8) (.local 0) (.local 1),
      .binary .lt (.base .byte) (.local 0) (.literal (.byte 0))]
    rejected.all (fun source => (comparisonKindAt source).isNone) = true ∧
    integerKindConstant .integer8 (.negInteger8 128) = some (-128) ∧
    integerKindConstant .unsignedInteger64 (.literal (.unsignedInteger64 18446744073709551615)) =
      some 18446744073709551615 := by
  decide +kernel

-- 条件環境の局所関数だけでなく予算付きの解析入口へ渡す。
-- 正常に戻る枝は[0,2]、同じ値から作った別名は元の区間のままである。
#guard
    seeds.all (fun (kind, zero, two, lo) =>
      let condition : Expr := .and
        (.binary .ge kind.type (.local 0) (.constE kind.type zero))
        (.not (.binary .gt kind.type (.local 0) two))
      let cases : List (Nat × (Int × Int)) := [(0, (0, 2)), (1, (lo, 5))]
      cases.all (fun (index, expected) =>
        let source : Expr := .ite condition (.last (.local index))
          (.last (.returnE kind.type zero))
        let report := analyzeExpr {} {} 64 (environment kind lo) ⟨"Example.kindCondition", 0⟩ source
        endpoints (report.approx.rangeKind kind) == some expected &&
        report.approx.warnings.isEmpty && report.coverage == .complete)) = true

-- 六比較の具体結果は独立した真偽の表で固定する。値1と定数2を比較する。
#guard
    seeds.all (fun (kind, _, two, _) =>
      let value := ConcreteValue.ofInteger kind ⟨1, by cases kind <;> decide⟩
      let concrete : ConcreteEnv := ⟨[some value], [], fun _ => none⟩
      let cases : List (BinOp × Bool) :=
        [(.eq, false), (.ne, true), (.lt, true), (.le, true), (.gt, false), (.ge, false)]
      cases.all (fun (op, expected) =>
        let result := evalClosed concrete
          ⟨.binary op kind.type (.local 0) two, .base .boolean, ⟨"Example.kindCompare", 0⟩⟩ 16
        (result.bind fun result => match result.outcome with
          | .normal (.boolean truth) => some truth
          | _ => none) == some expected)) = true

end Benitoite.Interval.KindConditionExamples

namespace Benitoite.Interval.Examples
open Benitoite.Surface Benitoite.Release BudgetAnalysis

-- 六幅のmatchは変数・wild・guardを使い、腕の結果は照合値と別の型でもよい。
-- 具体評価では未選択の失敗を飛ばすが、解析では後続腕の候補も残す。
#guard
    widthSeeds.all (fun (kind, zero, one, two, _) =>
      let bad : Expr := .binary .intDiv kind.type one zero
      let boundCase := input (.matchE kind.type two
        (.cons [⟨.var, [0]⟩] none (.last (.local 0)) .nil)) kind.type
      let wildcard := input (.matchE (.base .integer) two
        (.cons [⟨.wild, []⟩] none (.last (.literal (.integer ⟨9, by decide⟩))) .nil))
      let boolean := input (.matchE (.base .boolean) two
        (.cons [⟨.var, [0]⟩] (some (.binary .eq kind.type (.local 0) two))
          (.last (.literal (.boolean true)))
          (.cons [⟨.wild, []⟩] none (.last (.binary .eq kind.type bad zero)) .nil)))
        (.base .boolean)
      observeWidth boundCase == some (.normal kind 2, []) &&
      endpoints ((run boundCase).approx.rangeKind kind) == some (2, 2) &&
      observe wildcard == some (.normal (.integer 9), []) &&
      endpoints (run wildcard).approx.integer == some (9, 9) &&
      observe boolean == some (.normal (.boolean true),
        [⟨key 2, none, [.other, .other], .normal (.boolean true)⟩]) &&
      (run boolean).approx.boolean == (true, true) &&
      widthWarnings (run boolean) == [(key 7, some (some .intDiv, kind), .zeroDivisor)] &&
      [boundCase, wildcard].all (fun i => (run i).approx.warnings.isEmpty) &&
      [boundCase, wildcard, boolean].all (fun i => (run i).coverage == .complete)) = true

-- slotsで選んだ照合値を元の局所位置より前へ置く。真のguardでは両方を読み、
-- 偽のguardから次の腕へ進むときには照合値の束縛を残さない。
#guard
    widthSeeds.all (fun (kind, zero, one, _, _) =>
      let value := ConcreteValue.ofInteger kind ⟨2, by cases kind <;> decide⟩
      let outer : ConcreteEnv := ⟨[some value], [], fun _ => none⟩
      let abstractOuter := AbstractEnv.ofLocals [integerKindSlot kind (normalize 2 2 kind)]
      let selected := input (.matchE kind.type one
        (.cons [⟨.var, [0]⟩] (some (.binary .eq kind.type (.local 0) one))
          (.last (.binary .sub kind.type (.local 1) (.local 0))) .nil)) kind.type
      let skipped := input (.matchE kind.type one
        (.cons [⟨.var, [0]⟩] (some (.binary .eq kind.type (.local 0) zero))
          (.last (.binary .intDiv kind.type one zero))
          (.cons [⟨.wild, []⟩] none
            (.last (.binary .add kind.type (.local 0) one)) .nil))) kind.type
      observeWidth selected outer == some (.normal kind 1,
        [⟨key 2, some (some .eq, kind), [some (kind, 1), some (kind, 1)], .other⟩,
         ⟨key 5, some (some .sub, kind), [some (kind, 2), some (kind, 1)], .normal kind 1⟩]) &&
      observeWidth skipped outer == some (.normal kind 3,
        [⟨key 2, some (some .eq, kind), [some (kind, 1), some (kind, 0)], .other⟩,
         ⟨key 8, some (some .add, kind), [some (kind, 2), some (kind, 1)], .normal kind 3⟩]) &&
      endpoints ((run selected abstractOuter).approx.rangeKind kind) == some (1, 1) &&
      endpoints ((run skipped abstractOuter).approx.rangeKind kind) == some (3, 3) &&
      [selected, skipped].all (fun i =>
        (run i abstractOuter).coverage == .complete &&
        (run i abstractOuter).approx.warnings.isEmpty)) = true

-- 照合値・guard・選んだ本体の各位置の失敗は実行済みのtraceだけを残す。
-- 照合値とguardのreturnでは本体へ進まず、正常値の近似を残さない。
#guard
    widthSeeds.all (fun (kind, zero, one, _, _) =>
      let bad : Expr := .binary .intDiv kind.type one zero
      let rows : List (Expr × Option Expr × Expr × WidthOutcome × List WidthEvent ×
          List (OperationKey × Option (Option BinOp × IntKind) × WarningCause)) := [
        (bad, none, one, .failed .zeroDivisor,
          [⟨key 1, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)], .failed .zeroDivisor⟩],
          [(key 1, some (some .intDiv, kind), .zeroDivisor)]),
        (.returnE kind.type one, none, bad, .returned kind 1, [], []),
        (one, some (.binary .eq kind.type bad zero), one, .failed .zeroDivisor,
          [⟨key 3, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)], .failed .zeroDivisor⟩],
          [(key 3, some (some .intDiv, kind), .zeroDivisor)]),
        (one, some (.returnE (.base .boolean) one), bad, .returned kind 1, [], []),
        (one, some (.literal (.boolean true)), bad, .failed .zeroDivisor,
          [⟨key 3, some (some .intDiv, kind), [some (kind, 1), some (kind, 0)], .failed .zeroDivisor⟩],
          [(key 3, some (some .intDiv, kind), .zeroDivisor)])]
      rows.all (fun (source, guard, body, expected, trace, warned) =>
        let i := input (.matchE kind.type source
          (.cons [⟨.var, [0]⟩] guard (.last body) .nil)) kind.type
        observeWidth i == some (expected, trace) &&
        widthWarnings (run i) == warned &&
        (match expected with | .returned _ _ => !(run i).approx.live | _ => true) &&
        (run i).coverage == .complete)) = true

-- 型の上下限そのものから期待値を作らず、十進の境界を七種とも固定する。
private def kindBounds : List (IntKind × Expr × Expr × Int × Int) := [
  (.integer8, .negInteger8 128, .literal (.integer8 127), -128, 127),
  (.integer16, .negInteger16 32768, .literal (.integer16 32767), -32768, 32767),
  (.integer32, .negInteger32 2147483648, .literal (.integer32 2147483647), -2147483648, 2147483647),
  (.integer64, .negInt ⟨9223372036854775808, by decide⟩,
    .literal (.integer ⟨9223372036854775807, by decide⟩),
    -9223372036854775808, 9223372036854775807),
  (.unsignedInteger16, .literal (.unsignedInteger16 0), .literal (.unsignedInteger16 65535),
    0, 65535),
  (.unsignedInteger32, .literal (.unsignedInteger32 0), .literal (.unsignedInteger32 4294967295),
    0, 4294967295),
  (.unsignedInteger64, .literal (.unsignedInteger64 0),
    .literal (.unsignedInteger64 18446744073709551615), 0, 18446744073709551615)]

private def kindLiteral (kind : IntKind) (n : Fin 4) : Expr :=
  match kind with
  | .integer8 => .literal (.integer8 n)
  | .integer16 => .literal (.integer16 n)
  | .integer32 => .literal (.integer32 n)
  | .integer64 => .literal (.integer ⟨n.val, by have := n.isLt; omega⟩)
  | .unsignedInteger16 => .literal (.unsignedInteger16 n)
  | .unsignedInteger32 => .literal (.unsignedInteger32 n)
  | .unsignedInteger64 => .literal (.unsignedInteger64 n)

-- 内向きの演算は端の隣の一点を保ち、外向きの演算はその位置で失敗する。
-- (max+1)-1 と (min-1)+1 は数学上の最終値へ戻さず、子の失敗だけを残す。
#guard
    kindBounds.all (fun (kind, lo, hi, lower, upper) =>
      let one := kindLiteral kind 1
      let rows : List (Expr × Option (Int × Int) × WidthOutcome × List WidthEvent ×
          List (OperationKey × Option (Option BinOp × IntKind) × WarningCause)) := [
        (.binary .add kind.type lo one, some (lower + 1, lower + 1), .normal kind (lower + 1),
          [⟨key 0, some (some .add, kind), [some (kind, lower), some (kind, 1)],
            .normal kind (lower + 1)⟩], []),
        (.binary .sub kind.type hi one, some (upper - 1, upper - 1), .normal kind (upper - 1),
          [⟨key 0, some (some .sub, kind), [some (kind, upper), some (kind, 1)],
            .normal kind (upper - 1)⟩], []),
        (.binary .sub kind.type lo one, none, .failed .overflow,
          [⟨key 0, some (some .sub, kind), [some (kind, lower), some (kind, 1)], .failed .overflow⟩],
          [(key 0, some (some .sub, kind), .overflow)]),
        (.binary .add kind.type hi one, none, .failed .overflow,
          [⟨key 0, some (some .add, kind), [some (kind, upper), some (kind, 1)], .failed .overflow⟩],
          [(key 0, some (some .add, kind), .overflow)]),
        (.binary .sub kind.type (.binary .add kind.type hi one) one, none, .failed .overflow,
          [⟨key 1, some (some .add, kind), [some (kind, upper), some (kind, 1)], .failed .overflow⟩],
          [(key 1, some (some .add, kind), .overflow)]),
        (.binary .add kind.type (.binary .sub kind.type lo one) one, none, .failed .overflow,
          [⟨key 1, some (some .sub, kind), [some (kind, lower), some (kind, 1)], .failed .overflow⟩],
          [(key 1, some (some .sub, kind), .overflow)])]
      rows.all (fun (source, range, outcome, trace, warned) =>
        let i := input source kind.type
        let report := run i
        observeWidth i == some (outcome, trace) &&
        endpoints (report.approx.rangeKind kind) == range &&
        widthWarnings report == warned && report.coverage == .complete)) = true

-- 同じ位置を二度読んでも相関の特例を使わず、x-x は区間の差にする。
-- 正の定数倍と0倍は左右を交換しても同じ正常区間を返す。
#guard
    kindBounds.all (fun (kind, _, _, lower, _) =>
      let env := AbstractEnv.ofLocals [integerKindSlot kind (normalize 1 3 kind)]
      let actual := ConcreteValue.ofInteger kind ⟨2, by cases kind <;> decide⟩
      let concreteEnv : ConcreteEnv := ⟨[some actual], [], fun _ => none⟩
      let rows : List (Expr × Int × Int × Int × (Int × Int) × BinOp) := [
        (.binary .sub kind.type (.local 0) (.local 0), 2, 2, 0,
          (if lower < 0 then -2 else 0, 2), .sub),
        (.binary .mul kind.type (kindLiteral kind 3) (.local 0), 3, 2, 6, (3, 9), .mul),
        (.binary .mul kind.type (.local 0) (kindLiteral kind 3), 2, 3, 6, (3, 9), .mul),
        (.binary .mul kind.type (kindLiteral kind 0) (.local 0), 0, 2, 0, (0, 0), .mul),
        (.binary .mul kind.type (.local 0) (kindLiteral kind 0), 2, 0, 0, (0, 0), .mul)]
      rows.all (fun (source, a, b, value, range, op) =>
        let i := input source kind.type
        let report := run i env
        observeWidth i concreteEnv == some (.normal kind value,
          [⟨key 0, some (some op, kind), [some (kind, a), some (kind, b)], .normal kind value⟩]) &&
        endpoints (report.approx.rangeKind kind) == some range &&
        report.approx.warnings.isEmpty && report.coverage == .complete)) = true

-- 負の定数倍は端を交換し、符号付き四種の一般負号は[-2,4]を[-4,2]にする。
-- 正常な具体値2の評価と、複数値を含む抽象入力の期待を分ける。
#guard
    let rows : List (IntKind × Expr) := [
      (.integer8, .negInteger8 3), (.integer16, .negInteger16 3),
      (.integer32, .negInteger32 3), (.integer64, .negInt ⟨3, by decide⟩)]
    rows.all (fun (kind, negative) =>
      let env := AbstractEnv.ofLocals [integerKindSlot kind (normalize (-2) 4 kind)]
      let actual := ConcreteValue.ofInteger kind ⟨2, by cases kind <;> decide⟩
      let concreteEnv : ConcreteEnv := ⟨[some actual], [], fun _ => none⟩
      let cases : List (Expr × Option BinOp × List Int × Int × (Int × Int)) := [
        (.binary .mul kind.type negative (.local 0), some .mul, [-3, 2], -6, (-12, 6)),
        (.binary .mul kind.type (.local 0) negative, some .mul, [2, -3], -6, (-12, 6)),
        (.neg kind.type (.local 0), none, [2], -2, (-4, 2))]
      cases.all (fun (source, op, args, value, range) =>
        let i := input source kind.type
        let report := run i env
        observeWidth i concreteEnv == some (.normal kind value,
          [⟨key 0, some (op, kind), args.map (fun n => some (kind, n)), .normal kind value⟩]) &&
        endpoints (report.approx.rangeKind kind) == some range &&
        report.approx.warnings.isEmpty && report.coverage == .complete)) = true

-- 0と2の枝を[0,2]へ合流してからmatchのguardで絞る。
-- 実行はどちらも1を返すが、後続腕へ先のguardの否定を伝えないので解析は[1,3]となる。
#guard
    kindBounds.all (fun (kind, _, _, _, _) =>
      let zero := kindLiteral kind 0
      let one := kindLiteral kind 1
      let two := kindLiteral kind 2
      let source : Expr := .block (.bind .bind kind.type
        (.ite (.local 0) (.last zero) (.last two))
        (.last (.matchE kind.type (.local 0)
          (.cons [⟨.var, [0]⟩] (some (.binary .gt kind.type (.local 0) one))
            (.last (.binary .sub kind.type (.local 0) one))
            (.cons [⟨.wild, []⟩] none
              (.last (.binary .add kind.type (.local 0) one)) .nil)))))
      let i := input source kind.type
      let env := AbstractEnv.ofLocals [.unknown (some (.base .boolean))]
      let report := run i env
      let concreteTrue : ConcreteEnv := ⟨[some (.boolean true)], [], fun _ => none⟩
      let concreteFalse : ConcreteEnv := ⟨[some (.boolean false)], [], fun _ => none⟩
      observeWidth i concreteTrue == some (.normal kind 1,
        [⟨key 7, some (some .gt, kind), [some (kind, 0), some (kind, 1)], .other⟩,
         ⟨key 13, some (some .add, kind), [some (kind, 0), some (kind, 1)], .normal kind 1⟩]) &&
      observeWidth i concreteFalse == some (.normal kind 1,
        [⟨key 7, some (some .gt, kind), [some (kind, 2), some (kind, 1)], .other⟩,
         ⟨key 10, some (some .sub, kind), [some (kind, 2), some (kind, 1)], .normal kind 1⟩]) &&
      endpoints (report.approx.rangeKind kind) == some (1, 3) &&
      report.approx.warnings.isEmpty && report.coverage == .complete) = true

-- 合流した全値域の片端だけが失敗する場合は、正常区間を切り詰めて残す。
-- 失敗しうる経路があっても、全ての正常引数が失敗する警告にはしない。
#guard
    kindBounds.all (fun (kind, lo, hi, lower, upper) =>
      let source : Expr := .block (.bind .bind kind.type
        (.ite (.local 0) (.last lo) (.last hi))
        (.last (.binary .sub kind.type (.local 0) (kindLiteral kind 1))))
      let i := input source kind.type
      let report := run i (AbstractEnv.ofLocals [.unknown (some (.base .boolean))])
      let concreteTrue : ConcreteEnv := ⟨[some (.boolean true)], [], fun _ => none⟩
      let concreteFalse : ConcreteEnv := ⟨[some (.boolean false)], [], fun _ => none⟩
      observeWidth i concreteTrue == some (.failed .overflow,
        [⟨key 5, some (some .sub, kind), [some (kind, lower), some (kind, 1)], .failed .overflow⟩]) &&
      observeWidth i concreteFalse == some (.normal kind (upper - 1),
        [⟨key 5, some (some .sub, kind), [some (kind, upper), some (kind, 1)],
          .normal kind (upper - 1)⟩]) &&
      endpoints (report.approx.rangeKind kind) == some (lower, upper - 1) &&
      report.approx.warnings.isEmpty && report.coverage == .complete) = true

-- 七種とも、計算した正常評価の導出を任意の予算・初期消費・深さへ渡せる。
-- 完走した場合だけの有限表では、停止時の中心定理への接続を確認できない。
example (kind : IntKind) (parameters : Parameters) :
    let i := input (.binary .sub kind.type (kindLiteral kind 2) (kindLiteral kind 1)) kind.type
    let value := ConcreteValue.ofInteger kind ⟨1, by cases kind <;> decide⟩
    (analyze abstract i parameters).normal value := by
  let i := input (.binary .sub kind.type (kindLiteral kind 2) (kindLiteral kind 1)) kind.type
  let value := ConcreteValue.ofInteger kind ⟨1, by cases kind <;> decide⟩
  let event : EvalEvent := ⟨key 0, .binary .sub kind.type,
    [.ofInteger kind ⟨2, by cases kind <;> decide⟩, value], .normal value⟩
  have evaluated : EvalPartial concrete i (.normal value) [event] := by
    cases kind <;> exact ((evalClosed concrete i 16).get (by decide +kernel)).sound
  exact analyze_normal_sound abstract concrete i parameters value [event]
    (show Models abstract concrete from ⟨.nil, rfl, rfl⟩) evaluated

end Benitoite.Interval.Examples

namespace Benitoite.Interval.Examples.RangeSurface
open Benitoite.Surface Benitoite.Release

private def names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Range.CheckedInteger.record", "Std.Result.Result", "Std.Range.Error",
  "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
private def key (n : Nat) : OperationKey := ⟨"Example.surfaceRange", n⟩
private def integer (n : Integer64Value) : ConcreteValue := .integer n
private def lit (n : Integer64Literal) : Expr := .literal (.integer n)
private def checkBinding : StandardBinding := ⟨"Std.Range.checkInteger", .rangeCheck names, []⟩
private def valueBinding : StandardBinding := ⟨"Std.Range.value", .rangeValue names.record, []⟩
private def concrete : ConcreteEnv := ⟨[], [checkBinding, valueBinding], fun k =>
  if k.surfacePreorder = 8 ∨ k.surfacePreorder = 10 then some "Std.Range.value"
  else some "Std.Range.checkInteger"⟩
private def abstract : AbstractEnv := ⟨[], concrete.standards, concrete.apiAt, .empty ⟨[], 0⟩⟩
private def resultType : Ty := .data names.result [.data names.owner [], .data names.error []]
private def payload : ConcreteValue := rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
private def result : ConcreteValue := .con names.result [.data names.owner [], .data names.error []]
  names.ok [payload]
private def checkCall : Expr := .call (.funName "Std.Range.checkInteger" [] [])
  [some "value", some "maximum", some "minimum"] [2, 1, 0]
  (.cons (.binary .add (.base .integer) (lit ⟨2, by decide⟩) (lit ⟨3, by decide⟩))
    (.cons (lit ⟨10, by decide⟩) (.cons (lit ⟨0, by decide⟩) .nil)))
private def projection : Expr := .call (.funName "Std.Range.value" [] []) [some "checked"] [0]
  (.cons (.local 0) .nil)
private def okAlt : Alternative := ⟨.con (some names.result) names.ok [.var], [0]⟩
private def arms : Arms := .cons [okAlt] none (.last projection)
  (.cons [⟨.wild, []⟩] none (.last (.negInt ⟨1, by decide⟩)) .nil)
private def addEvent : EvalEvent := ⟨key 3, .binary .add (.base .integer),
  [integer ⟨2, by decide⟩, integer ⟨3, by decide⟩], .normal (integer ⟨5, by decide⟩)⟩
private def checkEvent : EvalEvent := ⟨key 1, .standard checkBinding,
  [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩, integer ⟨5, by decide⟩], .normal payload⟩
private def valueEvent (k : OperationKey) (value : ConcreteValue) (out : OperationResult) : EvalEvent :=
  ⟨k, .standard valueBinding, [value], out⟩

private theorem check_normal : EvalPartial concrete ⟨checkCall, resultType, key 1⟩
    (.normal result) [addEvent, checkEvent] := by
  refine .standardCall concrete (key 1) _ _ _ _ checkBinding
    [integer ⟨5, by decide⟩, integer ⟨10, by decide⟩, integer ⟨0, by decide⟩]
    [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩, integer ⟨5, by decide⟩]
    (.normal payload) [addEvent] rfl ?_ rfl ?_
  · apply EvalTypedArguments.cons (ht := [addEvent]) (rt := [])
    · exact .add _ _ _ _ ⟨2, by decide⟩ ⟨3, by decide⟩ [] [] (.integer ..) (.integer ..)
    · apply EvalTypedArguments.cons (ht := []) (rt := [])
      · exact .integer _ _ ⟨10, by decide⟩
      · apply EvalTypedArguments.cons (ht := []) (rt := [])
        · exact .integer _ _ ⟨0, by decide⟩
        · exact .nil ..
  · have made : rangeCheck names (key 1) ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩ =
        .normal payload := by
      simp [rangeCheck, Checked.Range.make, Checked.Range.InRange, Integer64Value.toInt,
        payload]
    rw [← made]
    exact .rangeCheck ..

private theorem projection_run (env : ConcreteEnv) (k : OperationKey)
    (value : ConcreteValue) (out : OperationResult)
    (identified : env.standardAt k = some valueBinding)
    (read : env.locals[0]? = some (some value))
    (typed : value.type = .data names.owner [])
    (standard : EvalStandard valueBinding.rule k [value] out) :
    EvalPartial env ⟨projection, .base .integer, k⟩ (valueBinding.rule.finish out)
      [valueEvent k value out] := by
  refine .standardCall env k _ _ _ _ valueBinding [value] [value] out [] ?_ ?_ rfl standard
  · simp [rangeCallBinding, standardCallHead, identified, valueBinding, exprsChildren]
  · apply EvalTypedArguments.cons (ht := []) (rt := [])
    · simpa only [typed, valueBinding, StandardBinding.sourceTypes, StandardRule.argumentType, RangeNames.record, List.map_cons, List.map_nil] using EvalPartial.local env _ 0 value read
    · exact .nil ..

private theorem selected_ok {input value : ConcreteValue} : ResultSelection names input names.ok value [okAlt] [value] := by
  exact ⟨[], okAlt, [], [value], rfl, by simp, rfl, rfl, rfl⟩

-- ソース順では加算3→検査1→射影8へ到達し、契約位置は 0,10,5 とする。
-- 同じ成功値を選んだ実際の表層評価から、由来と新しい番号の対応まで合成する。
example :
    EvalPartial concrete ⟨.matchE (.base .integer) checkCall arms, .base .integer, key 0⟩
      (.normal (integer ⟨5, by decide⟩))
      [addEvent, checkEvent, valueEvent (key 8) payload (.normal (integer ⟨5, by decide⟩))] ∧
    let origin : RangeOrigin := ⟨names, key 1, ⟨0, by decide⟩, ⟨10, by decide⟩⟩
    let start := RangeState.empty ⟨[], 0⟩
    (rangeBindOk start origin).Models { concrete with locals := [some payload] } ∧
      (rangeBindOk start origin).scope.idAt 0 = some 0 := by
  have models : Models abstract concrete := ⟨.nil, rfl, rfl⟩
  have view : names.ResultView result names.ok payload := .ok _ rfl
  have matched : rangeResultMatch concrete result arms = some names := rfl
  have projected := projection_run {concrete with locals := [some payload]} (key 8) payload
    (.normal (integer ⟨5, by decide⟩)) rfl rfl rfl
    (.rangeValue names.record (key 8) payload ⟨5, by decide⟩ (range_payload_stored ..))
  have selected : EvalResultArms concrete (key 8) names result names.ok payload arms
      (.base .integer) (.normal (integer ⟨5, by decide⟩))
      [valueEvent (key 8) payload (.normal (integer ⟨5, by decide⟩))] :=
    .body _ _ _ _ _ _ _ _ _ _ _ _ _ selected_ok (.last _ _ _ _ _ _ projected)
  refine ⟨.matchResult concrete (key 0) checkCall arms (.base .integer) resultType result names
    names.ok payload (.normal (integer ⟨5, by decide⟩)) [addEvent, checkEvent]
    [valueEvent (key 8) payload (.normal (integer ⟨5, by decide⟩))]
    matched view check_normal selected, ?_, rfl⟩
  exact (range_match_selected_ok_models models (range_empty_models ⟨[], 0⟩ concrete)
    (by rfl) check_normal matched view selected_ok).2

-- 一度保存した実際の Result の局所参照にも由来を保ち、Ok には次の新番号1を付ける。
example :
    let start := RangeState.empty ⟨[], 0⟩
    let saved := rangeSaveResult abstract start ⟨checkCall, resultType, key 1⟩
    let savedConcrete := { concrete with locals := [some result] }
    let origin : RangeOrigin := ⟨names, key 1, ⟨0, by decide⟩, ⟨10, by decide⟩⟩
    saved.Models savedConcrete ∧
      (rangeBindOk saved origin).Models {savedConcrete with locals := [some payload, some result]} ∧
      (rangeBindOk saved origin).scope.idAt 0 = some 1 := by
  dsimp only
  have models : Models abstract concrete := ⟨.nil, rfl, rfl⟩
  have saved := range_save_result_of_eval (state := RangeState.empty ⟨[], 0⟩) models
    (range_empty_models ⟨[], 0⟩ concrete) check_normal
  have savedModels : Models (extend abstract (topSlot (some resultType)))
      {concrete with locals := [some result]} := by
    apply models_extend models
    intro type same
    cases same
    rfl
  have read := EvalPartial.local {concrete with locals := [some result]} (key 9) 0 result rfl
  have known : rangeResultMatch {concrete with locals := [some result]} result arms = some names := rfl
  have bound := range_match_selected_ok_models savedModels saved (input := ⟨.local 0, resultType, key 9⟩)
    (by rfl) read known (RangeNames.ResultView.ok payload rfl) selected_ok
  exact ⟨saved, bound.2, rfl⟩


private def unknownResult : ConcreteValue := .other resultType rfl (by simp [resultType]) (by simp [resultType])
private def unknownChecked : ConcreteValue := .other (.data names.owner []) rfl (by simp) (by simp)
private def unknownEnv : ConcreteEnv := {concrete with locals := [some unknownResult]}

private theorem match_other_run (out : OperationResult)
    (standard : EvalStandard valueBinding.rule (key 10) [unknownChecked] out) :
    EvalPartial unknownEnv
      ⟨.matchE (.base .integer) (.local 0) arms, .base .integer, key 8⟩
      (valueBinding.rule.finish out) [valueEvent (key 10) unknownChecked out] := by
  have projected := projection_run {unknownEnv with locals := [some unknownChecked, some unknownResult]}
    (key 10) unknownChecked out rfl rfl rfl standard
  have selected : EvalResultArms unknownEnv (key 10) names unknownResult names.ok unknownChecked arms
      (.base .integer) (valueBinding.rule.finish out) [valueEvent (key 10) unknownChecked out] :=
    .body _ _ _ _ _ _ _ _ _ _ _ _ _ selected_ok (.last _ _ _ _ _ _ projected)
  exact .matchResult unknownEnv (key 8) (.local 0) arms (.base .integer) resultType unknownResult
    names names.ok unknownChecked (valueBinding.rule.finish out) [] _ rfl
    (.otherOk _ _ _ unknownChecked rfl) (.local _ _ 0 unknownResult rfl) selected

-- other の Result を match してから value を呼ぶ全経路にも、任意の正常値と失敗を残す。
example (number : Integer64Value) :
    EvalPartial unknownEnv ⟨.matchE (.base .integer) (.local 0) arms, .base .integer, key 8⟩
      (.normal (.integer number)) [valueEvent (key 10) unknownChecked (.normal (.integer number))] ∧
    EvalPartial unknownEnv ⟨.matchE (.base .integer) (.local 0) arms, .base .integer, key 8⟩
      (.failed .unknown) [valueEvent (key 10) unknownChecked (.rejected .unknown)] := by
  exact ⟨match_other_run _ (.rangeValueUnknown _ _ _ _ rfl), match_other_run _ (.rangeValueUnknownFailed _ _ _ rfl)⟩

private def invalidRangeValues : List ConcreteValue := [
  .other (.data names.owner []) rfl (by simp) (by simp),
  .con "User.CheckedInteger" [] names.checkedConstructor
    [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩, integer ⟨5, by decide⟩],
  .con names.owner [] "User.constructor"
    [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩, integer ⟨5, by decide⟩],
  .con names.owner [.base .integer] names.checkedConstructor
    [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩, integer ⟨5, by decide⟩],
  .con names.owner [] names.checkedConstructor [],
  .con names.owner [] names.checkedConstructor [integer ⟨0, by decide⟩, integer ⟨10, by decide⟩],
  .con names.owner [] names.checkedConstructor
    [integer ⟨0, by decide⟩, .boolean true, integer ⟨5, by decide⟩],
  .rangeError names.owner names.invalidBounds (.invalidBounds 10 0)]

-- 未認定の表現を型の前提で除かず、両端を含む任意の正常整数と失敗の導出を作る。
example (number : Integer64Value) :
    ∀ input ∈ invalidRangeValues,
      EvalStandard valueBinding.rule (key 10) [input] (.normal (.integer number)) ∧
      EvalStandard valueBinding.rule (key 10) [input] (.rejected .unknown) := by
  intro input member
  simp only [invalidRangeValues, List.mem_cons, List.not_mem_nil, or_false] at member
  rcases member with rfl | rfl | rfl | rfl | rfl | rfl | rfl | rfl
  all_goals exact ⟨.rangeValueUnknown _ _ _ _ rfl, .rangeValueUnknownFailed _ _ _ rfl⟩

-- 閉じた評価器は未知の表現から具体値を選ばず、認定した三欄の value は正確に読む。
#guard invalidRangeValues.all fun input =>
  (ClosedEval.standard valueBinding.rule (key 10) [input]).isNone
#guard
  let input := rangePayload names.record ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
  match ClosedEval.standard valueBinding.rule (key 10) [input] with
  | some ⟨.normal (.integer value), _⟩ => value.toInt == 5
  | _ => false

-- Error は Ok の枝を選ばず、通常の Result として次の腕へ進む。
example :
    let error := ConcreteValue.rangeError names.error names.outOfRange (.outOfRange 0 10 15)
    let rejected := ConcreteValue.con names.result [.data names.owner [], .data names.error []]
      names.err [error]
    let env := {concrete with locals := [some rejected]}
    EvalPartial env ⟨.matchE (.base .integer) (.local 0) arms, .base .integer, key 8⟩
      (.normal (integer ⟨-1, by decide⟩)) [] := by
  dsimp only
  let error := ConcreteValue.rangeError names.error names.outOfRange (.outOfRange 0 10 15)
  let rejected := ConcreteValue.con names.result [.data names.owner [], .data names.error []]
    names.err [error]
  let env := {concrete with locals := [some rejected]}
  have tail : EvalResultArms env (key 13) names rejected names.err error
      (.cons [⟨.wild, []⟩] none (.last (.negInt ⟨1, by decide⟩)) .nil)
      (.base .integer) (.normal (integer ⟨-1, by decide⟩)) [] := by
    refine .body _ _ _ _ _ _ _ _ _ _ [] _ _ ?_ (.last _ _ _ _ _ _ (.negInt ..))
    exact ⟨[], ⟨.wild, []⟩, [], [], rfl, by simp, rfl, rfl, rfl⟩
  have selected : EvalResultArms env (key 10) names rejected names.err error arms
      (.base .integer) (.normal (integer ⟨-1, by decide⟩)) [] := by
    refine .skip _ _ _ _ _ _ _ _ _ _ _ _ _ ?_ tail
    intro alt member
    simp only [List.mem_singleton] at member
    subst alt
    decide +kernel
  exact .matchResult env (key 8) (.local 0) arms (.base .integer) resultType rejected
    names names.err error _ [] [] rfl (.error error rfl) (.local _ _ 0 rejected rfl) selected

-- 先頭の引数の return の後には、残る除数0と呼び出し自体の事象を作らない。
example :
    let early := Expr.returnE (.base .integer) (lit ⟨5, by decide⟩)
    let failure := Expr.binary .intDiv (.base .integer) (lit ⟨1, by decide⟩) (lit ⟨0, by decide⟩)
    let source := Expr.call (.funName "Std.Range.checkInteger" [] []) [none, none, none] [0, 1, 2]
      (.cons early (.cons failure (.cons (lit ⟨10, by decide⟩) .nil)))
    EvalPartial concrete ⟨source, resultType, key 1⟩ (.returned (integer ⟨5, by decide⟩)) [] := by
  refine .standardCallAbrupt _ _ _ _ _ _ checkBinding _ _ rfl ?_ trivial
  refine .headAbrupt _ _ _ _ _ _ _ _ ?_ trivial
  exact .returnE _ _ _ _ _ (.normal (integer ⟨5, by decide⟩)) [] (.integer ..)

-- 認定を外れる形だけを未知へ戻す。正しい形も同じ固定表で確認する。
example :
    let input : EvalInput := ⟨checkCall, resultType, key 1⟩
    let args := Exprs.cons (lit ⟨0, by decide⟩)
      (.cons (lit ⟨10, by decide⟩) (.cons (lit ⟨5, by decide⟩) .nil))
    ([input,
      {input with source := .call (.funName "User.checkInteger" [] []) [none, none, none] [0, 1, 2] args},
      {input with source := .call (.local 0) [none, none, none] [0, 1, 2] args},
      {input with source := .call (.funName "Std.Range.checkInteger" [] []) [none, none, none] [0, 0, 2] args},
      {input with source := .call (.funName "Std.Range.checkInteger" [] []) [] [0, 1, 2] args},
      {input with source := .pipe .unit checkCall}].map fun i => (rangeCallBinding concrete i).isSome) =
      [true, false, false, false, false, false] := by
  decide +kernel

-- 閉じた評価器の入口で、実際の引数計算・契約順・同じ成功値の射影を確認する。
-- 導出だけの例と違い、評価器が未接続ならこの固定値・番号列にはならない。
#guard
    (match evalClosed concrete
      ⟨.matchE (.base .integer) checkCall arms, .base .integer, key 0⟩ 32 with
    | some ⟨.normal (.integer value), trace, _⟩ =>
        value.toInt == 5 && trace.map (fun event => event.key.surfacePreorder) == [3, 1, 8]
    | _ => false) = true

-- 一度保存した Result と古い整数位置を保ち、shadow の後も成功値だけを射影する。
#guard
    let env := {concrete with apiAt := fun k =>
      if k.surfacePreorder = 1 then some "Std.Range.checkInteger" else some "Std.Range.value"}
    let source := Expr.block (.bind .bind resultType checkCall
      (.last (.matchE (.base .integer) (.local 0)
        (.cons [okAlt] none
          (.bind .shadow (.base .integer) (lit ⟨99, by decide⟩)
            (.last (.call (.funName "Std.Range.value" [] []) [some "checked"] [0]
              (.cons (.local 1) .nil)))) .nil))))
    (match evalClosed env ⟨source, .base .integer, key 0⟩ 48 with
    | some ⟨.normal (.integer value), trace, _⟩ =>
        value.toInt == 5 && trace.map (fun event => event.key.surfacePreorder) == [3, 1, 11]
    | _ => false) = true

-- 逆転は値の範囲外より優先し、API の Error は実行時の失敗へ変えない。
#guard
    let call := fun lo hi value => Expr.call (.funName "Std.Range.checkInteger" [] [])
      [none, none, none] [0, 1, 2] (.cons (lit lo) (.cons (lit hi) (.cons (lit value) .nil)))
    let cases := [(call ⟨10, by decide⟩ ⟨0, by decide⟩ ⟨15, by decide⟩, true),
      (call ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨15, by decide⟩, false)]
    cases.all (fun (source, inverted) =>
      (match evalClosed concrete ⟨source, resultType, key 1⟩ 16 with
      | some ⟨.normal (.con _ _ tag [.rangeError _ _ error]), trace, _⟩ =>
          tag == names.err && trace.length == 1 &&
            match error with
            | .invalidBounds lo hi => inverted && lo == 10 && hi == 0
            | .outOfRange lo hi value => !inverted && lo == 0 && hi == 10 && value == 15
      | _ => false) &&
      (match evalClosed concrete
          ⟨.matchE (.base .integer) source arms, .base .integer, key 0⟩ 32 with
      | some ⟨.normal (.integer value), trace, _⟩ =>
          value.toInt == -1 && trace.map (fun event => event.key.surfacePreorder) == [1]
      | _ => false)) = true

-- Ok に一致しても guard が偽なら元の環境に戻り、次の Error/全体パターンを試す。
#guard
    let guarded := Arms.cons [okAlt] (some (.literal (.boolean false)))
      (.last (.binary .intDiv (.base .integer) (lit ⟨1, by decide⟩) (lit ⟨0, by decide⟩)))
      (.cons [⟨.wild, []⟩] none (.last (.local 0)) .nil)
    let env := {concrete with locals := [some (.integer ⟨42, by decide⟩)]}
    (match evalClosed env ⟨.matchE (.base .integer) checkCall guarded, .base .integer, key 0⟩ 32 with
    | some ⟨.normal (.integer value), trace, _⟩ =>
        value.toInt == 42 && trace.map (fun event => event.key.surfacePreorder) == [3, 1]
    | _ => false) = true

-- 引数の return は後続引数と親の事象を飛ばし、先に完了した子の事象だけ残す。
#guard
    let source := Expr.call (.funName "Std.Range.checkInteger" [] []) [none, none, none] [0, 1, 2]
      (.cons (.binary .add (.base .integer) (lit ⟨2, by decide⟩) (lit ⟨3, by decide⟩))
        (.cons (.returnE (.base .integer) (lit ⟨7, by decide⟩))
          (.cons (.binary .intDiv (.base .integer) (lit ⟨1, by decide⟩) (lit ⟨0, by decide⟩)) .nil)))
    (match evalClosed concrete ⟨source, resultType, key 1⟩ 32 with
    | some ⟨.returned (.integer value), trace, _⟩ =>
        value.toInt == 7 && trace.map (fun event => event.key.surfacePreorder) == [3]
    | _ => false) = true

-- other の値には決定的な中身を選ばず、偽の宣言・未解決・型違い・深さ不足も評価不能とする。
#guard
    let unknownValue := {concrete with locals := [some unknownChecked]}
    let noApi := {concrete with apiAt := fun _ => none}
    let fake := Expr.call (.funName "User.Range.value" [] []) [none] [0] (.cons (.local 0) .nil)
    (evalClosed unknownEnv ⟨.matchE (.base .integer) (.local 0) arms, .base .integer, key 8⟩ 32).isNone = true ∧
    (evalClosed unknownValue ⟨projection, .base .integer, key 8⟩ 16).isNone = true ∧
    (evalClosed concrete ⟨fake, .base .integer, key 8⟩ 16).isNone = true ∧
    (evalClosed noApi ⟨checkCall, resultType, key 1⟩ 16).isNone = true ∧
    (evalClosed concrete ⟨checkCall, .base .integer, key 1⟩ 16).isNone = true ∧
    (evalClosed concrete ⟨checkCall, resultType, key 1⟩ 2).isNone = true

-- 土台・予算付き式・本体の実際の入口と、先頭三例の全体駆動で同じ成功値だけの区間を確認する。
-- 期待端点は手書きで固定し、未接続で全て Top を返す解析を通さない。
#guard
    let env := fun (checkIndex : Nat) => { abstract with
      apiAt := fun k => if k.surfacePreorder = checkIndex then
        some "Std.Range.checkInteger" else some "Std.Range.value" }
    let onlyOk := fun body => Arms.cons [okAlt] none body .nil
    let direct := Expr.matchE (.base .integer) checkCall (onlyOk (.last projection))
    let saved := Expr.block (.bind .bind resultType checkCall
      (.last (.matchE (.base .integer) (.local 0) (onlyOk (.last projection)))))
    let shadowed := Expr.block (.bind .bind resultType checkCall
      (.last (.matchE (.base .integer) (.local 0) (onlyOk
        (.bind .shadow (.base .integer) (lit ⟨99, by decide⟩)
          (.last (.call (.funName "Std.Range.value" [] []) [some "checked"] [0]
            (.cons (.local 1) .nil))))))))
    let checkedAlias := Expr.matchE (.base .integer) checkCall (onlyOk
      (.bind .bind (.data names.owner []) (.local 0) (.last projection)))
    let resultAlias := Expr.block (.bind .bind resultType checkCall
      (.bind .bind resultType (.local 0)
        (.last (.matchE (.base .integer) (.local 0) (onlyOk (.last projection))))))
    let dynamic := Expr.matchE (.base .integer)
      (.call (.funName "Std.Range.checkInteger" [] [])
        [some "value", some "maximum", some "minimum"] [2, 1, 0]
        (.cons (.binary .add (.base .integer) (lit ⟨2, by decide⟩) (lit ⟨3, by decide⟩))
          (.cons (lit ⟨10, by decide⟩) (.cons (.local 0) .nil))))
      (onlyOk (.last projection))
    let boundary := Expr.block (.bind .bind (.data names.owner [])
      (.tryResult [.data names.owner [], .data names.error []] names.ok names.err checkCall)
      (.last projection))
    let merged := Expr.matchE (.base .integer) checkCall (onlyOk (.last
      (.ite (.or (.binary .eq (.base .integer) (.local 1) (lit ⟨0, by decide⟩))
        (.literal (.boolean true))) (.last projection) (.last (lit ⟨1, by decide⟩)))))
    let cases : List (AbstractEnv × Expr × (Int × Int) × BudgetAnalysis.Coverage) := [
      (env 1, direct, (0, 10), .complete),
      (env 1, saved, (0, 10), .complete),
      (env 1, shadowed, (0, 10), .complete),
      (env 1, checkedAlias, (-9223372036854775808, 9223372036854775807), .complete),
      (env 1, resultAlias, (-9223372036854775808, 9223372036854775807), .unsupported),
      ({env 1 with locals := [.integer (normalize 0 0)]}, dynamic,
        (-9223372036854775808, 9223372036854775807), .unsupported),
      (env 2, boundary, (-9223372036854775808, 9223372036854775807), .unsupported),
      ({env 1 with locals := [.integer top]}, merged,
        (-9223372036854775808, 9223372036854775807), .complete)]
    let shifted := fun (environment : AbstractEnv) => {environment with
      apiAt := fun k => environment.apiAt {k with surfacePreorder := k.surfacePreorder - 1}}
    (cases.all (fun (environment, source, expected, coverage) =>
      let base := analyzeBaseExpr 64 (resetRanges environment) (key 0) source
      let budget := BudgetAnalysis.analyzeExpr {} {} 64 environment (key 0) source
      let body := BudgetAnalysis.analyzeBody {} {} 64 "Range.connection"
        ⟨.function, .last source, shifted environment⟩
      endpoints base.integer == some expected &&
        endpoints budget.approx.integer == some expected &&
        endpoints body.approx.integer == some expected &&
        base.warnings.isEmpty && budget.approx.warnings.isEmpty && body.approx.warnings.isEmpty &&
        budget.coverage == coverage && body.coverage == coverage) &&
      (cases.take 3).all (fun (environment, source, expected, coverage) =>
        let whole := BudgetWhole.analyze {} {} 64
          [⟨[⟨"Range.connection", .function, [], .last source, shifted environment⟩]⟩]
        match BudgetWhole.bodyOutputs whole with
        | [result] => endpoints result.output.approx.integer == some expected &&
            result.output.approx.warnings.isEmpty && result.output.coverage == coverage
        | _ => false)) = true

-- 未認定の親から独立入力を作っても、子の元キーで Range を認定する。
-- 親へ子の正常区間や候補を混ぜず、保存した子自身の結果だけを精密化する。
#guard
    let direct := Expr.matchE (.base .integer) checkCall
      (.cons [okAlt] none (.last projection) .nil)
    let source := Expr.call (.funName "User.consume" [] []) [none] [0] (.cons direct .nil)
    let env := { abstract with apiAt := fun k =>
      if k.surfacePreorder = 3 then some "Std.Range.checkInteger" else some "Std.Range.value" }
    let output := BudgetAnalysis.analyzeExpr {} {} 64 env (key 0) source
    output.context.independentRev.map (fun entry =>
      (entry.key.surfacePreorder, endpoints entry.approx.integer, entry.warningsRev.isEmpty)) =
      [(2, some (0, 10), true),
       (1, some (-9223372036854775808, 9223372036854775807), true)] ∧
    endpoints output.approx.integer = some (-9223372036854775808, 9223372036854775807) ∧
    output.approx.warnings = [] ∧ output.coverage = .unsupported ∧
    output.context.next.surfacePreorder = 13

-- Range.value の認定中に保持上限へ達しても、先に保存した除数0を失わない。
-- 正常な別の分岐があるため、上限25で完走すれば同じ成功値の [0,10] を得る。
#guard
    let source := Expr.matchE (.base .integer)
      (.call (.funName "Std.Range.checkInteger" [] []) [none, none, none] [0, 1, 2]
        (.cons (lit ⟨0, by decide⟩) (.cons (lit ⟨10, by decide⟩)
          (.cons (.ite (.local 0)
            (.last (.binary .intDiv (.base .integer) (lit ⟨1, by decide⟩) (lit ⟨0, by decide⟩)))
            (.last (lit ⟨5, by decide⟩))) .nil))))
      (.cons [okAlt] none (.last projection) .nil)
    let env := { abstract with
      locals := [.unknown (some (.base .boolean))]
      apiAt := fun k => if k.surfacePreorder = 1 then some "Std.Range.checkInteger" else some "Std.Range.value" }
    let rows : List (Option (Int × Int) × BudgetAnalysis.Coverage ×
        List (OperationKey × Bool × WarningCause) × Nat × Nat × Nat) :=
      ([22, 25] : List Nat).map fun cap =>
        let output := BudgetAnalysis.analyzeExpr
          {body := ⟨10000, cap⟩, whole := ⟨10000, 10000⟩} {} 64 env (key 0) source
        (endpoints output.approx.integer, output.coverage,
          output.approx.warnings.map (fun warning => (warning.key,
            (match warning.operation with | .binary .intDiv (.base .integer) => true | _ => false), warning.cause)),
          output.context.next.surfacePreorder, output.context.budget.body.saved,
          output.context.budget.body.temporary)
    (rows == [
      (some (-9223372036854775808, 9223372036854775807),
        .stopped (.budget (.exceeded ⟨.body, .items⟩)),
        [(key 7, true, .zeroDivisor)], 12, 13, 0),
      (some (0, 10), .complete,
        [(key 7, true, .zeroDivisor)], 14, 15, 0)]) = true

end Benitoite.Interval.Examples.RangeSurface

namespace Benitoite.Interval.Examples.RangeC3
open Benitoite.Surface Benitoite.Release

private def names : RangeNames := ⟨"Std.Range.CheckedInteger", "Std.Range.CheckedInteger.record", "Std.Result.Result", "Std.Range.Error",
  "Std.Result.Ok", "Std.Result.Error", "Std.Range.InvalidBounds", "Std.Range.OutOfRange"⟩
private def key (n : Nat) : OperationKey := ⟨"Example.rangeC3", n⟩
private def checkBinding : StandardBinding := ⟨"Std.Range.checkInteger", .rangeCheck names, []⟩
private def valueBinding : StandardBinding := ⟨"Std.Range.value", .rangeValue names.record, []⟩
private def concrete : ConcreteEnv := ⟨[], [checkBinding, valueBinding], fun k =>
  if k.surfacePreorder = 1 then some checkBinding.declaration else some valueBinding.declaration⟩
private def abstract : AbstractEnv := ⟨[], concrete.standards, concrete.apiAt, .empty ⟨[], 0⟩⟩
private def resultType : Ty := .data names.result [.data names.owner [], .data names.error []]

-- 最小値にも直接負号を使い、正のリテラルとして表現しない。
private def integerExpr (n : Integer64Value) : Expr :=
  if h : n.toInt < 0 then
    .negInt ⟨(-n.toInt).toNat, by
      have bounds := n.toInt_bounds
      simp only [min64, max64] at bounds
      omega⟩
  else
    .literal (.integer ⟨n.toInt.toNat, by
      have bounds := n.toInt_bounds
      simp only [min64, max64] at bounds
      omega⟩)

private def checkCall (lo hi value : Integer64Value) : Expr :=
  .call (.funName checkBinding.declaration [] [])
    [some "value", some "maximum", some "minimum"] [2, 1, 0]
    (.cons (integerExpr value) (.cons (integerExpr hi) (.cons (integerExpr lo) .nil)))

private def projection (index : Nat) : Expr :=
  .call (.funName valueBinding.declaration [] []) [some "value"] [0] (.cons (.local index) .nil)
private def okAlt : Alternative := ⟨.con (some names.result) names.ok [.var], [0]⟩
private def selectOk (call : Expr) (body : Block) : Expr :=
  .matchE (.base .integer) call (.cons [okAlt] none body
    (.cons [⟨.wild, []⟩] none (.last (.negInt ⟨99, by decide⟩)) .nil))
private def onlyOk (call : Expr) (body : Block) : Expr :=
  .matchE (.base .integer) call (.cons [okAlt] none body .nil)

private def errorFailure : Checked.Range.RangeError → Failure
  | .invalidBounds lo hi => .invalidBounds lo hi
  | .outOfRange lo hi value => .outOfRange lo hi value

-- 成功の両端・一点・符号付き64ビットの両端を、三欄と独立期待値で照合する。
-- API の正常な Result と、trace 内の包む前の成功値をそれぞれ検査する。
#guard
  let rows : List (Integer64Value × Integer64Value × Integer64Value × (Int × Int × Int)) := [
    (⟨0, by decide⟩, ⟨10, by decide⟩, ⟨0, by decide⟩, (0, 10, 0)),
    (⟨0, by decide⟩, ⟨10, by decide⟩, ⟨10, by decide⟩, (0, 10, 10)),
    (⟨7, by decide⟩, ⟨7, by decide⟩, ⟨7, by decide⟩, (7, 7, 7)),
    (⟨-9223372036854775808, by decide⟩, ⟨9223372036854775807, by decide⟩,
      ⟨-9223372036854775808, by decide⟩,
      (-9223372036854775808, 9223372036854775807, -9223372036854775808)),
    (⟨-9223372036854775808, by decide⟩, ⟨9223372036854775807, by decide⟩,
      ⟨9223372036854775807, by decide⟩,
      (-9223372036854775808, 9223372036854775807, 9223372036854775807))]
  rows.all fun (lo, hi, value, expected) =>
    let source := checkCall lo hi value
    let small := match Checked.Range.rawMake lo.toInt hi.toInt value.toInt with
      | .ok raw => (raw.minimum, raw.maximum, raw.value) == expected
      | _ => false
    small && (match evalClosed concrete ⟨source, resultType, key 1⟩ 32 with
      | some ⟨.normal (.con owner types tag [.con stored [] constructor
          [.integer minimum, .integer maximum, .integer value]]), [event], _⟩ =>
          owner == names.result && (match types with
            | [.data stored [], .data error []] => stored == names.owner && error == names.error
            | _ => false) &&
          tag == names.ok && stored == names.owner && constructor == names.checkedConstructor &&
          (minimum.toInt, maximum.toInt, value.toInt) == expected &&
          event.key == key 1 && (match event.operation with
            | .standard binding => binding.declaration == checkBinding.declaration &&
                (match binding.rule with | .rangeCheck n => n.owner == names.owner | _ => false)
            | _ => false) &&
          (event.arguments.map fun v => match v with | .integer n => some n.toInt | _ => none) ==
            [some lo.toInt, some hi.toInt, some value.toInt] &&
          (match event.result with
            | .normal (.con stored [] constructor [.integer minimum, .integer maximum, .integer value]) =>
                stored == names.owner && constructor == names.checkedConstructor &&
                (minimum.toInt, maximum.toInt, value.toInt) == expected
            | _ => false)
      | _ => false) &&
      (match evalClosed concrete ⟨selectOk source (.last (projection 0)), .base .integer, key 0⟩ 48 with
      | some ⟨.normal (.integer n), trace, _⟩ =>
          n.toInt == expected.2.2 && trace.map (·.key.surfacePreorder) == [1, 6]
      | _ => false)

-- 逆転は value の場所によらず優先し、正順では両側の範囲外を区別する。
-- Error は正常値であり、match の失敗側の -99 と検査事象一つだけを得る。
#guard
  let rows : List (Integer64Value × Integer64Value × Integer64Value × Failure) := [
    (⟨10, by decide⟩, ⟨0, by decide⟩, ⟨5, by decide⟩, .invalidBounds 10 0),
    (⟨10, by decide⟩, ⟨0, by decide⟩, ⟨15, by decide⟩, .invalidBounds 10 0),
    (⟨0, by decide⟩, ⟨10, by decide⟩, ⟨-1, by decide⟩, .outOfRange 0 10 (-1)),
    (⟨0, by decide⟩, ⟨10, by decide⟩, ⟨11, by decide⟩, .outOfRange 0 10 11)]
  rows.all fun (lo, hi, value, expected) =>
    let source := checkCall lo hi value
    (match evalClosed concrete ⟨source, resultType, key 1⟩ 32 with
      | some ⟨.normal (.con _ _ tag [.rangeError _ constructor error]), [event], _⟩ =>
          tag == names.err && errorFailure error == expected &&
          constructor == (match expected with | .invalidBounds .. => names.invalidBounds | _ => names.outOfRange) &&
          event.key == key 1 && (match event.result with | .rejected e => e == expected | _ => false)
      | _ => false) &&
    (match evalClosed concrete ⟨selectOk source (.last (projection 0)), .base .integer, key 0⟩ 48 with
      | some ⟨.normal (.integer n), trace, _⟩ =>
          n.toInt == -99 && trace.map (·.key.surfacePreorder) == [1]
      | _ => false) &&
    (BudgetAnalysis.analyzeExpr {} {} 64 abstract (key 0)
      (selectOk source (.last (projection 0)))).approx.warnings.isEmpty

-- 二つ目の成功値は同じデータ型でも [0,10] を共有しない。
-- 外側の値を読むと5、内側を読むと105になる。外側の由来も保持する。
#guard
  let first := checkCall ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩
  let second := checkCall ⟨100, by decide⟩ ⟨110, by decide⟩ ⟨105, by decide⟩
  let source := fun index => onlyOk first (.last (onlyOk second (.last (projection index))))
  let env := {concrete with apiAt := (fun k =>
    if k.surfacePreorder = 1 ∨ k.surfacePreorder = 7 then some "Std.Range.checkInteger"
    else some "Std.Range.value")}
  let abs := {abstract with apiAt := env.apiAt}
  ([((0 : Nat), 105, (100, 110)), (1, 5, (0, 10))] : List (Nat × Int × (Int × Int))).all
    fun (index, expected, bounds) =>
      (match evalClosed env ⟨source index, .base .integer, key 0⟩ 64 with
      | some ⟨.normal (.integer n), trace, _⟩ =>
          n.toInt == expected && trace.map (·.key.surfacePreorder) == [1, 7, 12] &&
          (match trace[2]? with
          | some event => match event.arguments with
            | [.con stored [] constructor [.integer minimum, .integer maximum, .integer value]] =>
                stored == names.owner && constructor == names.checkedConstructor && value.toInt == expected &&
                (minimum.toInt, maximum.toInt) == bounds
            | _ => false
          | _ => false)
      | _ => false) &&
      let base := analyzeBaseExpr 64 (resetRanges abs) (key 0) (source index)
      let budget := BudgetAnalysis.analyzeExpr {} {} 64 abs (key 0) (source index)
      endpoints base.integer == some bounds && endpoints budget.approx.integer == some bounds &&
      base.warnings.isEmpty && budget.approx.warnings.isEmpty && budget.coverage == .complete

-- 呼び出しの字面が標準名でも、同定表が別の宣言を指せば精密化しない。
-- 正しい同定との対により、全て Top の未接続実装を通さない。
#guard
  let source := onlyOk (checkCall ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩)
    (.last (projection 0))
  let fake := {concrete with apiAt := fun _ => some "User.checkInteger"}
  let abs := {abstract with apiAt := fake.apiAt}
  let known := BudgetAnalysis.analyzeExpr {} {} 64 abstract (key 0) source
  let unknown := BudgetAnalysis.analyzeExpr {} {} 64 abs (key 0) source
  endpoints known.approx.integer = some (0, 10) ∧ known.coverage = .complete ∧
  endpoints unknown.approx.integer = some (-9223372036854775808, 9223372036854775807) ∧
  unknown.coverage = .unsupported ∧ unknown.approx.warnings = [] ∧
  (evalClosed fake ⟨source, .base .integer, key 0⟩ 48).isNone

-- 引数にある別個体は同じ型でも新しい検査の由来を持たない。
-- 実際の105への導出を残し、[0,10]へ誤って狭める実装を検出する。
#guard
  let unrelated : ConcreteValue := rangePayload names.record
    ⟨100, by decide⟩ ⟨110, by decide⟩ ⟨105, by decide⟩
  let env := {concrete with locals := [some unrelated]}
  let abs := {abstract with locals := [.unknown (some (.data names.owner []))]}
  let source := onlyOk (checkCall ⟨0, by decide⟩ ⟨10, by decide⟩ ⟨5, by decide⟩)
    (.last (projection 1))
  (match evalClosed env ⟨source, .base .integer, key 0⟩ 48 with
    | some ⟨.normal (.integer n), trace, _⟩ =>
        n.toInt == 105 && trace.map (·.key.surfacePreorder) == [1, 6]
    | _ => false) &&
    let base := analyzeBaseExpr 64 (resetRanges abs) (key 0) source
    let budget := BudgetAnalysis.analyzeExpr {} {} 64 abs (key 0) source
    endpoints base.integer == some (-9223372036854775808, 9223372036854775807) &&
    endpoints budget.approx.integer == some (-9223372036854775808, 9223372036854775807) &&
    base.warnings.isEmpty && budget.approx.warnings.isEmpty && budget.coverage == .complete

-- 射影の後続算術が精密区間を使うことを確認する。上端の+1は到達後にあふれる。
#guard
  let increment := Expr.binary .add (.base .integer) (projection 0)
    (.literal (.integer ⟨1, by decide⟩))
  let rows : List (Integer64Value × Integer64Value × Integer64Value ×
      Option (Int × Int) × Option Int × List Nat) := [
    (⟨0, by decide⟩, ⟨9, by decide⟩, ⟨9, by decide⟩, some (1, 10), some 10, []),
    (⟨9223372036854775807, by decide⟩, ⟨9223372036854775807, by decide⟩,
      ⟨9223372036854775807, by decide⟩, none, none, [6])]
  rows.all fun (lo, hi, value, bounds, expected, warned) =>
    let source := onlyOk (checkCall lo hi value) (.last increment)
    let base := analyzeBaseExpr 64 (resetRanges abstract) (key 0) source
    let budget := BudgetAnalysis.analyzeExpr {} {} 64 abstract (key 0) source
    (match evalClosed concrete ⟨source, .base .integer, key 0⟩ 64 with
    | some ⟨outcome, trace, _⟩ =>
        trace.map (·.key.surfacePreorder) == [1, 7, 6] &&
        (match outcome, expected with
        | .normal (.integer n), some v => n.toInt == v
        | .failed .overflow, none => true
        | _, _ => false)
    | _ => false) &&
    endpoints base.integer == bounds && endpoints budget.approx.integer == bounds &&
    base.warnings.map (·.key.surfacePreorder) == warned &&
    budget.approx.warnings.map (·.key.surfacePreorder) == warned &&
    budget.approx.warnings.all (fun warning => warning.cause == .overflow) &&
    budget.coverage == .complete

end Benitoite.Interval.Examples.RangeC3
