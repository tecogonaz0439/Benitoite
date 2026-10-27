import Benitoite.Interval.Sound

/-!
# guard と return の局所規則の独立例

実際の土台の式・Block の解析を局所規則へ渡し、正常区間と警告順を固定値と比べる
（設計書 01-12「区間解析のguardとreturnの局所規則」）。
後半の独立例は match 全体の解析と、具体評価の導出・中心二定理を使う。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

-- 既存の解析結果から、局所規則が受け取る型の正常範囲だけを取り出す。
private def integerExpr (key : OperationKey) (env : AbstractEnv) (expr : Expr) :
    FlowApprox (.base .integer) :=
  let result := analyzeBaseExpr 32 env key expr
  ⟨result.integer, result.mayFail, result.warnings⟩

private def booleanExpr (key : OperationKey) (env : AbstractEnv) (expr : Expr) :
    FlowApprox (.base .boolean) :=
  let result := analyzeBaseExpr 32 env key expr
  ⟨result.boolean, result.mayFail, result.warnings⟩

private def integerBlock (key : OperationKey) (env : AbstractEnv) (body : Block) :
    FlowApprox (.base .integer) :=
  let result := analyzeBaseBlock 32 env key body
  ⟨result.integer, result.mayFail, result.warnings⟩

private def signature (result : FlowApprox (.base .integer)) :
    Interval × Bool × List (Nat × WarningCause) :=
  (result.normal, result.mayFail,
    result.warnings.map fun warning => (warning.key.surfacePreorder, warning.cause))

-- guard は腕の追加位置0を狭める。本体でだけ max64+1 を断定できる。
-- 後続腕は元環境から入り、追加位置も guard の真偽の事実も共有しない。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 max64)]
    let guard : Expr := .binary .eq (.base .integer) (.local 0)
      (.literal (.integer ⟨9223372036854775807, by decide⟩))
    let body : Block := .last (.binary .add (.base .integer) (.local 0)
      (.literal (.integer ⟨1, by decide⟩)))
    let guarded := analyzeMatchArm env (.local 0) (.base .integer) (normalize 0 max64)
      [⟨.var, [0]⟩] (some guard) body
      (booleanExpr ⟨"Example.guard", 2⟩) (integerBlock ⟨"Example.guard", 5⟩)
    let later := analyzeMatchArm env (.local 0) (.base .integer) (normalize 0 max64)
      [⟨.wild, []⟩] none body
      (booleanExpr ⟨"Example.guard", 9⟩) (integerBlock ⟨"Example.guard", 9⟩)
    signature guarded = (.bottom, true, [(5, WarningCause.overflow)]) ∧
    signature later = (normalize 1 max64, true, []) ∧
    integerAt env 0 = normalize 0 max64 ∧ env.locals.length = 1

-- 偽・失敗・return・パターンとの空の交差は、本体のあふれ警告を追加しない。
-- 失敗する guard 自身の警告は保存する。未知の guard は本体を除外しない。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 1)]
    let maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
    let overflow : Expr := .binary .add (.base .integer) maximum
      (.literal (.integer ⟨1, by decide⟩))
    let run := fun guard => signature (analyzeMatchArm env (.local 0) (.base .integer)
      (normalize 0 1) [⟨.var, [0]⟩] guard (.last overflow)
      (booleanExpr ⟨"Example.guardStop", 2⟩) (integerBlock ⟨"Example.guardStop", 10⟩))
    [run (some (.literal (.boolean false))),
     run (some (.binary .eq (.base .integer) overflow maximum)),
     run (some (.returnE (.base .boolean) (.literal (.boolean true)))),
     run (some (.funName "Example.unknown" [] []))] =
      [(.bottom, false, []), (.bottom, true, [(3, WarningCause.overflow)]),
       (.bottom, false, []), (.bottom, true, [(10, .overflow)])] ∧
    signature (analyzeMatchArm env (.local 0) (.base .integer) (normalize 0 1)
      [⟨.integer ⟨2, by decide⟩, []⟩] (some (.binary .eq (.base .integer) overflow maximum))
      (.last overflow) (booleanExpr ⟨"Example.guardStop", 2⟩)
      (integerBlock ⟨"Example.guardStop", 10⟩)) = (.bottom, false, [])

-- guard が正常値も持つ場合、guard の子の警告、本体の警告の順を保つ。
-- div/mod の結果区間は Top のままという既存の近似を変えない。
#guard
    let env := AbstractEnv.ofLocals []
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let guard : Expr := .binary .eq (.base .integer)
      (.binary .intDiv (.base .integer) one zero) zero
    let body : Block := .last (.binary .add (.base .integer)
      (.literal (.integer ⟨9223372036854775807, by decide⟩)) one)
    signature (analyzeMatchArm env zero (.base .integer) (normalize 0 0)
      [⟨.wild, []⟩] (some guard) body
      (booleanExpr ⟨"Example.guardOrder", 2⟩) (integerBlock ⟨"Example.guardOrder", 7⟩)) =
        (.bottom, true, [(3, WarningCause.zeroDivisor), (7, .overflow)])

-- return はオペランドまで解析し、後続の除数0を解析しない。
-- オペランドのあふれと正常な戻り値を、失敗可能性で区別する。
#guard
    let env := AbstractEnv.ofLocals []
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let overflow : Expr := .binary .add (.base .integer)
      (.literal (.integer ⟨9223372036854775807, by decide⟩)) one
    let later := fun _ : Unit => integerExpr ⟨"Example.return", 20⟩ env
      (.binary .intDiv (.base .integer) one zero)
    let run := fun operand => signature (thenFlow
      (analyzeReturn (.base .integer) env operand (integerExpr ⟨"Example.return", 3⟩)) later)
    [run one, run overflow, run (.returnE (.base .integer) one)] =
      [(.bottom, false, []), (.bottom, true, [(3, WarningCause.overflow)]),
       (.bottom, false, [])] ∧
    signature (thenFlow (integerExpr ⟨"Example.return", 3⟩ env one) later) =
      (top, true, [(20, WarningCause.zeroDivisor)])

-- 腕本体の return の後の式を切る。guard の事実を if 後へ持ち出さない。
-- try/with/handle の内側の return は、既存どおり未知の境界を越えて推測しない。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize 0 max64)]
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let guard : Expr := .binary .eq (.base .integer) (.local 0)
      (.literal (.integer ⟨9223372036854775807, by decide⟩))
    let body : Block := .seq (.returnE (.base .integer) (.local 0))
      (.last (.binary .add (.base .integer) (.local 0) one))
    let arm := analyzeMatchArm env (.local 0) (.base .integer) (normalize 0 max64)
      [⟨.var, [0]⟩] (some guard) body
      (booleanExpr ⟨"Example.returnArm", 2⟩) (integerBlock ⟨"Example.returnArm", 5⟩)
    let afterIf : Block := .seq (.ifOnly guard (.last (.returnE (.base .unit) .unit)))
      (.last (.local 0))
    signature arm = (.bottom, true, []) ∧
    signature (integerBlock ⟨"Example.afterIf", 0⟩ env afterIf) = (normalize 0 max64, true, []) ∧
    (([.tryResult [.base .integer, .base .unit] "Result.Ok" "Result.Error"
         (.returnE (.base .integer) one),
       .withE "Example.Resource" .unit (.last (.returnE (.base .integer) one)),
       .handleE (.last (.returnE (.base .integer) one)) .nil] : List Expr).map
      (fun expr => signature (integerExpr ⟨"Example.boundary", 0⟩ env expr))) =
        [(top, true, []), (top, true, []), (top, true, [])]

-- 実際の解析入口で、腕の束縛と guard、空の交差、return、非整数の退避を確認する。
-- 局所規則のコールバックだけでは、matchE への接続漏れとキーのずれを検出できない。
#guard
    let env := AbstractEnv.ofLocals [.integer (normalize (-1) 1)]
    let key : OperationKey := ⟨"Example.fullMatch", 0⟩
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
    let overflow : Block := .last (.binary .add (.base .integer) maximum one)
    let lastOne : Arms := .cons [⟨.wild, []⟩] none (.last one) .nil
    let inputs : List Expr := [
      .matchE (.base .integer) (.local 0)
        (.cons [⟨.var, [0]⟩] (some (.binary .gt (.base .integer) (.local 0) zero))
          (.last (.binary .add (.base .integer) (.local 0) maximum))
          (.cons [⟨.wild, []⟩] none (.last zero) .nil)),
      .matchE (.base .integer) one
        (.cons [⟨.integer ⟨2, by decide⟩, []⟩] none overflow lastOne),
      .matchE (.base .integer) (.returnE (.base .integer) one)
        (.cons [⟨.wild, []⟩] none overflow .nil),
      .matchE (.base .integer) one
        (.cons [⟨.wild, []⟩] (some (.literal (.boolean false))) overflow lastOne),
      .matchE (.base .integer) (.literal (.boolean true))
        (.cons [⟨.wild, []⟩] none overflow .nil),
      .matchE (.base .integer) one
        (.cons [⟨.wild, []⟩]
          (some (.binary .eq (.base .integer) (.binary .intDiv (.base .integer) one zero) zero))
          overflow lastOne),
      .matchE (.base .integer) one
        (.cons [⟨.wild, []⟩] (some (.returnE (.base .boolean) (.literal (.boolean true)))) overflow .nil),
      .matchE (.base .integer) one
        (.cons [⟨.var, [0]⟩] none (.seq (.returnE (.base .unit) (.local 0)) overflow) .nil),
      .matchE (.base .integer) one
        (.cons [⟨.integer ⟨0, by decide⟩, []⟩,
          ⟨.range (.integer ⟨1, by decide⟩) (.integer ⟨2, by decide⟩), []⟩]
          none (.last (.literal (.integer ⟨3, by decide⟩))) .nil)]
    (inputs.map fun expr =>
      let result := analyzeBaseExpr 32 env key expr
      (result.integer, result.mayFail,
        result.warnings.map fun warning => (warning.key.surfacePreorder, warning.cause))) =
      [(normalize 0 0, true, [(5, WarningCause.overflow)]),
       (normalize 1 1, false, []), (.bottom, false, []),
       (normalize 1 1, false, []), (top, true, []),
       (normalize 1 1, true, [(3, .zeroDivisor), (7, .overflow)]),
       (.bottom, false, []), (.bottom, true, []), (normalize 3 3, false, [])]

-- guard が偽のときは、未実行の本体の番号も飛ばして次の腕の除数0へ到達する。
private def traceMatchInput : EvalInput :=
  let one : Expr := .literal (.integer ⟨1, by decide⟩)
  let zero : Expr := .literal (.integer ⟨0, by decide⟩)
  let skipped : Block := .last (.binary .add (.base .integer)
    (.literal (.integer ⟨9223372036854775807, by decide⟩)) one)
  ⟨.matchE (.base .integer) one
    (.cons [⟨.wild, []⟩] (some (.literal (.boolean false))) skipped
      (.cons [⟨.wild, []⟩] none (.last (.binary .intDiv (.base .integer) one zero)) .nil)),
    .base .integer, ⟨"Example.matchTrace", 0⟩⟩

example :
    let warning : IntervalWarning := ⟨⟨"Example.matchTrace", 6⟩,
      .binary .intDiv (.base .integer), .zeroDivisor⟩
    ∃ trace, EvalPartial ⟨[], [], fun _ => none⟩ traceMatchInput (.failed .zeroDivisor) trace ∧
      trace.map (fun event => (event.key.surfacePreorder, event.result)) =
        [(6, OperationResult.rejected .zeroDivisor)] ∧
      warning ∈ (analyzeBase (AbstractEnv.ofLocals []) traceMatchInput 32).warnings ∧
      ∀ event, Reached trace warning event → event.result = .rejected .zeroDivisor := by
  dsimp only
  let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
  have selected : IntegerSelection [⟨.wild, []⟩] ⟨1, by decide⟩ [] := by
    exact ⟨[], ⟨.wild, []⟩, [], [], [], rfl, by simp, rfl, rfl, rfl, rfl⟩
  have eval : EvalPartial env traceMatchInput (.failed .zeroDivisor) _ :=
    .matchInteger env _ _ _ _ ⟨1, by decide⟩ _ [] _
      (.integer _ _ ⟨1, by decide⟩)
      (.guardFalse _ _ _ _ _ _ _ _ [] _ [] _ selected (.boolean _ _ false)
        (.body _ _ _ _ _ _ _ [] _ _ selected
          (.last _ _ _ _ _ _ (.divMod _ _ .intDiv _ _ ⟨1, by decide⟩ ⟨0, by decide⟩ [] []
            (Or.inl rfl) (.integer _ _ ⟨1, by decide⟩) (.integer _ _ ⟨0, by decide⟩)))))
  refine ⟨_, eval, rfl, by change _ ∈ [_]; exact List.mem_cons_self, ?_⟩
  exact analyzeBase_warning_sound (AbstractEnv.ofLocals []) env _ 32 _ _ ⟨.nil, rfl, rfl⟩ eval _ (by change _ ∈ [_]; exact List.mem_cons_self)

-- 照合値を腕の変数へ保存し、guard の真の分岐で同じ正常値を返す導出を使う。
-- 中心定理は深さ0を含む任意の打ち切りで、この値の所属を保証する。
private def normalMatchInput : EvalInput :=
  let one : Expr := .literal (.integer ⟨1, by decide⟩)
  ⟨.matchE (.base .integer) one
    (.cons [⟨.var, [0]⟩] (some (.literal (.boolean true))) (.last (.local 0)) .nil),
    .base .integer, ⟨"Example.matchNormal", 0⟩⟩

example (fuel : Nat) :
    (analyzeBase (AbstractEnv.ofLocals []) normalMatchInput fuel).normal (.integer ⟨1, by decide⟩) := by
  let env : ConcreteEnv := ⟨[], [], fun _ => none⟩
  have selected : IntegerSelection [⟨.var, [0]⟩] ⟨1, by decide⟩ [.integer ⟨1, by decide⟩] := by
    exact ⟨[], ⟨.var, [0]⟩, [], [.integer ⟨1, by decide⟩], [.const (.integer ⟨1, by decide⟩)],
      rfl, by simp, rfl, rfl, rfl, rfl⟩
  have eval : EvalPartial env normalMatchInput (.normal (.integer ⟨1, by decide⟩)) _ := EvalPartial.matchInteger env _ _ _ _ ⟨1, by decide⟩ _ [] _
    (.integer _ _ ⟨1, by decide⟩) (.guardTrue _ _ _ _ _ _ _ _ [.integer ⟨1, by decide⟩] _ [] [] selected
      (.boolean _ _ true) (.last _ _ _ _ _ _ (.local _ _ 0 (.integer ⟨1, by decide⟩) rfl)))
  exact analyzeBase_normal_sound (AbstractEnv.ofLocals []) env _ fuel _ _ ⟨.nil, rfl, rfl⟩ eval

end Benitoite.Interval
