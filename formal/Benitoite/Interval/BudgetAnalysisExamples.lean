import Benitoite.Interval.BudgetNormal

/-!
# 共有予算の解析の独立例

局所走査だけでは検出できない、式・Block・腕列の接続と途中停止を確かめる。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

private def emptyEnv := AbstractEnv.ofLocals []
private def key : OperationKey := ⟨"Example.budget", 0⟩
private def one : Expr := .literal (.integer ⟨1, by decide⟩)
private def zero : Expr := .literal (.integer ⟨0, by decide⟩)
private def maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
private def overflow : Expr := .binary .add (.base .integer) maximum one
private def division : Expr := .binary .intDiv (.base .integer) one zero
private def cap (operations items : Nat) : Limits := ⟨⟨operations, items⟩, ⟨10000, 10000⟩⟩
private def run (source : Expr) : Report := analyzeExpr {} {} 200 emptyEnv key source
private def warnings (r : Report) := r.approx.warnings.map fun w =>
  (w.key.surfacePreorder, (match w.operation with
    | .binary op (.base .integer) => some op | _ => none), w.cause)

-- 深さ0は本体にも番号にも着手せず Top。未対応と正常な Bottom は停止と別である。
#guard
    let depth := analyzeExpr {} {} 0 emptyEnv key one
    let unknown := run (.funName "Example.unknown" [] [])
    let bottom := run overflow
    depth.coverage = .stopped .depth ∧ depth.approx.integer = top ∧
    depth.context.budget = ({} : Budget.State) ∧ depth.context.next = key ∧
    unknown.coverage = .unsupported ∧ unknown.approx.integer = top ∧ warnings unknown = [] ∧
    bottom.coverage = .complete ∧ bottom.approx.integer = .bottom ∧
    warnings bottom = [(0, some .add, .overflow)]

-- 一回の番号計上後、式の訪問が上限を超える。子で予算を作り直してはならない。
-- 番号の保存が拒否された場合には、その出現のキーを進めない。
#guard
    let operations := analyzeExpr (cap 1 100) {} 100 emptyEnv key one
    let unidentified := analyzeExpr (cap 100 1) {} 100 emptyEnv key one
    operations.coverage = .stopped (.budget (.exceeded ⟨.body, .operations⟩)) ∧
    operations.context.budget.body.operations = 1 ∧
    operations.context.budget.body.saved = 1 ∧ operations.context.budget.body.temporary = 0 ∧
    operations.approx.integer = top ∧
    unidentified.coverage = .stopped (.budget (.unidentified ⟨.body, .items⟩)) ∧
    unidentified.context.budget.body.saved = 0 ∧ unidentified.context.next = key

private def twoBranches : Expr := .ite (.local 0) (.last division) (.last (.paren one))

-- 一方の枝の警告を保存した後、もう一方の枝で停止しても警告を残す。
-- 操作上限・保持上限・番号付け中の上限を区別し、枠はすべて返す。
#guard
    let operationStop := analyzeExpr (cap 14 100) {} 100 emptyEnv key twoBranches
    let itemStop := analyzeExpr (cap 100 11) {} 100 emptyEnv key twoBranches
    let numberingStop := analyzeExpr (cap 17 100) {} 100 emptyEnv key twoBranches
    operationStop.coverage = .stopped (.budget (.exceeded ⟨.body, .operations⟩)) ∧
    itemStop.coverage = .stopped (.budget (.exceeded ⟨.body, .items⟩)) ∧
    numberingStop.coverage = .stopped (.budget (.unidentified ⟨.body, .operations⟩)) ∧
    warnings operationStop = [(2, some .intDiv, .zeroDivisor)] ∧
    warnings itemStop = [(2, some .intDiv, .zeroDivisor)] ∧
    warnings numberingStop = [(2, some .intDiv, .zeroDivisor)] ∧
    operationStop.approx.integer = top ∧ itemStop.approx.integer = top ∧
    operationStop.context.budget.body.temporary = 0 ∧
    itemStop.context.budget.body.temporary = 0 ∧ numberingStop.context.budget.body.temporary = 0 ∧
    operationStop.context.budget.body.operations = 14 ∧
    itemStop.context.budget.body.peak = 11

-- 警告候補の確保そのものが拒否された場合は候補を追加しない。
#guard
    let result := analyzeExpr (cap 100 5) {} 100 emptyEnv key division
    result.coverage = .stopped (.budget (.exceeded ⟨.body, .items⟩)) ∧
    warnings result = [] ∧ result.context.budget.body.saved = 3 ∧
    result.context.budget.body.temporary = 0

-- 未到達の枝と短絡した右辺を番号だけで通過する。後の警告の番号は詰めない。
#guard
    let result := run (.block (.seq
      (.ite (.literal (.boolean false)) (.last overflow) (.last one))
      (.last division)))
    let shorted := run (.and (.literal (.boolean false))
      (.binary .eq (.base .integer) overflow zero))
    result.coverage = .complete ∧
    warnings result = [(7, some .intDiv, .zeroDivisor)] ∧
    result.context.next.surfacePreorder = 10 ∧
    warnings shorted = [] ∧ shorted.approx.boolean = (true, false) ∧
    shorted.context.next.surfacePreorder = 7

-- 捕捉境界の子に外の事実を持ち込まない。乗算では子のあふれだけを残す。
-- const の埋込み本体では外の局所位置も忘れる。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 0)]
    let boundary := analyzeExpr {} {} 100 env key
      (.lam [] [] (.base .integer) Eff.empty (.last (.binary .intDiv (.base .integer) one (.local 0))))
    let product := run (.binary .mul (.base .integer) overflow one)
    let constant := analyzeExpr {} {} 100 env key (.constE (.base .integer) (.local 0))
    boundary.coverage = .unsupported ∧ boundary.approx.integer = top ∧ warnings boundary = [] ∧
    boundary.context.next.surfacePreorder = 4 ∧
    product.coverage = .complete ∧ warnings product = [(1, some .add, .overflow)] ∧
    constant.approx.integer = top ∧ warnings constant = []

-- bind・shadow は新しい局所位置へコピーし、後続の参照・加算を同じ予算で処理する。
#guard
    let result := run (.block (.bind .bind (.base .integer) one
      (.bind .shadow (.base .integer) zero
        (.last (.binary .add (.base .integer) (.local 0) (.local 1))))))
    result.coverage = .complete ∧ result.approx.integer = normalize 1 1 ∧
    warnings result = [] ∧ result.context.budget.body.temporary = 0

-- guard はパターンで追加した位置だけを狭める。次の腕には元の環境を渡す。
-- 警告の保存列は逆順で、停止時にも同じ列を共有する。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 max64)]
    let result := analyzeExpr {} {} 200 env key (.matchE (.base .integer) (.local 0)
      (.cons [⟨.var, [0]⟩] (some (.binary .eq (.base .integer) (.local 0) maximum))
        (.last (.binary .add (.base .integer) (.local 0) one))
        (.cons [⟨.wild, []⟩] none (.last (.binary .add (.base .integer) (.local 0) one)) .nil)))
    result.coverage = .complete ∧ result.approx.integer = normalize 1 max64 ∧
    warnings result = [(5, some .add, .overflow)] ∧
    result.context.budget.body.temporary = 0

-- return の子の警告を残し、後続には新しい警告を付けない。
-- 空のパターン交差と guard の偽も、本体を番号だけで通過する。
#guard
    let returned := run (.block (.seq (.returnE (.base .integer) overflow) (.last division)))
    let matched := run (.matchE (.base .integer) one
      (.cons [⟨.integer ⟨2, by decide⟩, []⟩] none (.last overflow)
        (.cons [⟨.wild, []⟩] (some (.literal (.boolean false))) (.last division) .nil)))
    returned.coverage = .complete ∧ returned.approx.live = false ∧
    warnings returned = [(2, some .add, .overflow)] ∧
    returned.context.next.surfacePreorder = 8 ∧ matched.coverage = .complete ∧
    matched.approx.live = false ∧ warnings matched = []

-- 最初の本体の保存項目・操作数を後の本体へ渡す。
-- 全体上限に達した後の本体は入口環境を構築しない。
#guard
    let limits : Limits := ⟨⟨100, 100⟩, ⟨9, 100⟩⟩
    let first := analyzeBody limits {} 100 "Example.budget" ⟨.function, .last division, emptyEnv⟩
    let second := analyzeBody limits first.after 100 "Example.second"
      ⟨.function, .last one, emptyEnv⟩
    let third := analyzeBody limits second.after 100 "Example.third"
      ⟨.function, .last one, emptyEnv⟩
    first.coverage = .complete ∧ first.after.whole.operations = 9 ∧ first.after.whole.saved = 5 ∧
    warnings first = [(1, some .intDiv, .zeroDivisor)] ∧
    first.context.identitiesRev.reverse.map (fun entry => entry.1.surfacePreorder) = [0, 1, 2, 3] ∧
    second.coverage = .stopped (.budget (.exceeded ⟨.whole, .operations⟩)) ∧
    second.approx.integer = top ∧ second.after.whole.operations = 9 ∧
    second.after.whole.saved = 5 ∧
    third.coverage = .stopped (.budget (.exceeded ⟨.whole, .operations⟩)) ∧
    third.context.budget.body.operations = 0 ∧ third.after = second.after

-- 本体入口の捕捉区間は、既存の狭さを使わず予算付きで Top に戻す。
-- 忘却で確保した一時環境を、本体の終了まで保持してから返す。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 0)]
    let result := analyzeBody {} {} 100 "Example.budget" ⟨.lambda, .last (.local 0), env⟩
    result.coverage = .complete ∧ result.approx.integer = top ∧ warnings result = [] ∧
    result.context.budget.body.operations = 8 ∧ result.context.budget.body.temporary = 0 ∧
    result.after.whole.saved = 2

-- 候補を複数保存する場合も一件ずつ計上し、列の逆順を出力の契約として保つ。
#guard
    let result := run (.block (.seq division (.last overflow)))
    result.coverage = .complete ∧ result.approx.integer = .bottom ∧
    warnings result = [(4, some .add, .overflow), (1, some .intDiv, .zeroDivisor)] ∧
    result.context.budget.body.saved = 9 ∧ result.after.whole.saved = 9

private instance (state : Budget.State) : Decidable state.Valid := by
  unfold Budget.State.Valid
  infer_instance
private instance (limits : Limits) (state : Budget.State) : Decidable (state.Within limits) := by
  unfold Budget.State.Within
  infer_instance

-- 共有状態への接続後も、複数の境界で上限・整合性・保存数と借用項目を守る。
-- 小さい本体上限と全体上限を独立に変え、拒否した確保の二重計上も検出する。
#guard
    let capacities : List Limits := [
      ⟨⟨0, 0⟩, ⟨100, 100⟩⟩, ⟨⟨1, 100⟩, ⟨100, 100⟩⟩,
      ⟨⟨100, 1⟩, ⟨100, 100⟩⟩, ⟨⟨14, 100⟩, ⟨100, 100⟩⟩,
      ⟨⟨100, 11⟩, ⟨100, 100⟩⟩, ⟨⟨21, 13⟩, ⟨100, 100⟩⟩,
      ⟨⟨100, 100⟩, ⟨14, 100⟩⟩, ⟨⟨100, 100⟩, ⟨100, 11⟩⟩]
    (capacities.all fun limits =>
      let r := analyzeExpr limits {} 100 emptyEnv key twoBranches
      decide (r.context.budget.Valid ∧ r.context.budget.Within limits ∧
        r.context.budget.body.saved = r.context.warningsRev.length + r.context.identitiesRev.length ∧
        r.context.budget.body.temporary = 0)) = true ∧
    (analyzeExpr {} ⟨⟨0, 3, 0, 3⟩, ⟨0, 0, 3⟩⟩ 100 emptyEnv key twoBranches).context.budget.body.temporary = 3

-- 入力からある警告・対応は接尾辞として残す。二件目の候補だけが確保できない場合と
-- 完走を比べ、既存列の消失・入力順の逆転・拒否した候補の混入を検出する。
example :
    let old : IntervalWarning := ⟨⟨"Example.old", 99⟩, .binary .add (.base .integer), .overflow⟩
    let first : IntervalWarning := ⟨⟨"Example.new", 1⟩, .binary .intDiv (.base .integer), .zeroDivisor⟩
    let second : IntervalWarning := ⟨⟨"Example.new", 2⟩, .binary .add (.base .integer), .overflow⟩
    let ctx : Context := {
      budget := ⟨⟨0, 0, 2, 2⟩, ⟨0, 0, 2⟩⟩
      next := ⟨"Example.new", 17⟩
      warningsRev := [old]
      identitiesRev := [(⟨"Example.old", 8⟩, .unit)]
      unsupported := true }
    let stopped := saveWarnings [first, second] (cap 100 5) ctx
    let complete := saveWarnings [first, second] {} ctx
    (match stopped.1 with
      | .error (.budget (.exceeded ⟨.body, .items⟩)) => true | _ => false) = true ∧
    complete.1.isOk = true ∧
    stopped.2.warningsRev.map (fun w => (w.key.definition, w.key.surfacePreorder, w.cause)) =
      [("Example.new", 1, .zeroDivisor), ("Example.old", 99, .overflow)] ∧
    complete.2.warningsRev.map (fun w => (w.key.definition, w.key.surfacePreorder, w.cause)) =
      [("Example.new", 2, .overflow), ("Example.new", 1, .zeroDivisor), ("Example.old", 99, .overflow)] ∧
    ([stopped, complete].all fun result =>
      result.2.identitiesRev.map (fun (k, e) => (k.definition, k.surfacePreorder,
        match e with | .unit => true | _ => false)) == [("Example.old", 8, true)] &&
      result.2.next == ⟨"Example.new", 17⟩ && result.2.unsupported &&
      result.2.budget.body.temporary == 0) = true ∧
    stopped.2.budget.body.saved = 3 ∧ complete.2.budget.body.saved = 4 := by decide +kernel

-- 非零の開始番号と既存の対応列から、解析・番号走査の完走と途中停止を比べる。
-- 短絡で飛ばす match の guard・const 本体も数え、後の除算の番号を詰めない。
#guard
    let source : Expr := .block (.seq
      (.and (.literal (.boolean false)) (.matchE (.base .unit) one
        (.cons [⟨.wild, []⟩] (some (.paren (.local 7)))
          (.last (.constE (.base .unit) .unit)) .nil)))
      (.last division))
    let ctx : Context := {
      budget := ⟨⟨0, 0, 1, 1⟩, ⟨0, 0, 1⟩⟩
      next := ⟨"Example.new", 20⟩
      identitiesRev := [(⟨"Example.old", 99⟩, .local 9)] }
    let view := fun (ctx : Context) => ctx.identitiesRev.map fun (p : OperationKey × Expr) =>
      (p.1.definition, p.1.surfacePreorder, match p.2 with
        | .block _ => "block" | .and _ _ => "and" | .literal (.boolean _) => "bool"
        | .matchE _ _ _ => "match" | .literal (.integer _) => "integer" | .paren _ => "paren"
        | .local _ => "local" | .constE _ _ => "const" | .unit => "unit"
        | .binary _ _ _ _ => "binary" | _ => "other")
    let expected := [
      ("Example.new", 31, "integer"), ("Example.new", 30, "integer"),
      ("Example.new", 29, "binary"), ("Example.new", 28, "unit"),
      ("Example.new", 27, "const"), ("Example.new", 26, "local"),
      ("Example.new", 25, "paren"), ("Example.new", 24, "integer"),
      ("Example.new", 23, "match"), ("Example.new", 22, "bool"),
      ("Example.new", 21, "and"), ("Example.new", 20, "block"),
      ("Example.old", 99, "local")]
    let parsed := expr 100 emptyEnv source {} ctx
    let skipped := skipExpr 100 source {} ctx
    let partialParsed := expr 100 emptyEnv source (cap 8 1000) ctx
    let partialSkipped := skipExpr 100 source (cap 8 1000) ctx
    parsed.1.isOk = true ∧ skipped.1.isOk = true ∧
    view parsed.2 = expected ∧ view skipped.2 = expected ∧
    parsed.2.next = ⟨"Example.new", 32⟩ ∧ skipped.2.next = ⟨"Example.new", 32⟩ ∧
    view partialParsed.2 = expected.drop 8 ∧ view partialSkipped.2 = expected.drop 6 ∧
    partialParsed.2.next = ⟨"Example.new", 24⟩ ∧ partialSkipped.2.next = ⟨"Example.new", 26⟩ ∧
    (match partialParsed.1, partialSkipped.1 with
      | .error (.budget (.unidentified ⟨.body, .operations⟩)),
        .error (.budget (.unidentified ⟨.body, .operations⟩)) => true
      | _, _ => false) = true ∧
    parsed.2.warningsRev.map (fun w => (w.key.surfacePreorder, w.cause)) = [(29, .zeroDivisor)]

-- 共通の解析結果まで接続し、完走時の精度と停止時の全値域、型の制約を比べる。
-- 深さ2は短絡の補助解析で止まり、深さ4では飛ばす右辺の番号走査も完走する。
#guard @decide (
    let input : EvalInput := ⟨.and (.literal (.boolean false)) (.literal (.boolean true)),
      .base .boolean, key⟩
    let complete := analyze emptyEnv input ⟨{}, {}, 4⟩
    let depth := analyze emptyEnv input ⟨{}, {}, 2⟩
    let exhausted := analyze emptyEnv input ⟨cap 0 1000, {}, 4⟩
    complete.normal (.boolean false) ∧ ¬complete.normal (.boolean true) ∧
    depth.normal (.boolean false) ∧ depth.normal (.boolean true) ∧
    exhausted.normal (.boolean false) ∧ exhausted.normal (.boolean true) ∧
    ¬exhausted.normal (.integer ⟨0, by decide⟩)) (by
  dsimp only [analyze, Report.toAnalysisResult, BaseApprox.Contains, ConcreteValue.type]
  simp only [Ty.base.injEq, reduceCtorEq, true_and, false_and, not_false_eq_true, and_true]
  infer_instance)


end Benitoite.Interval.BudgetAnalysis
