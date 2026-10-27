import Benitoite.Interval.BudgetChildren
import Benitoite.Interval.BudgetRange
import Benitoite.Interval.BudgetSelect

/-!
# 式・Block・腕列への共有予算の接続

停止した残りは Top に退き、保存に成功した警告を保持する。
正常値の合成証明は BudgetNormal、警告の位置と原因の合成は別の証明で扱う。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 候補の保存に失敗したら、その候補を追加せず既存の列を残す。 -/
def saveWarnings : List IntervalWarning → Analysis Unit
  | [] => pure ()
  | warning :: rest => scope fun _ => do
    scan (BudgetScan.allocate .warning .saved)
    modify fun ctx => { ctx with warningsRev := warning :: ctx.warningsRev }
    saveWarnings rest

/-- 固定域の候補も、同じ共有列へ保存する。 -/
def fixedOwn (binding : StandardBinding) (key : OperationKey) (selected : BaseApprox) :
    Analysis BaseApprox := do
  let result := selectedFixedOwn binding key selected
  saveWarnings result.warnings
  pure { result with warnings := [] }

/-- 未対応は停止ではなく、子の値の事実を利用しない正常な Top である。 -/
def unsupported : Analysis BaseApprox := do
  modify fun ctx => { ctx with unsupported := true }
  pure baseUnknown

/-- 値域外の表層数値は未知と記録し、値域内の葉だけ一点区間を返す。 -/
def widthLiteral (kind : IntKind) (value : Int) : Analysis BaseApprox :=
  if kind.min ≤ value ∧ value ≤ kind.max then pure (baseWidthLiteral kind value)
  else unsupported

/-- 警告を別の共有列に保存し、正常値の合成で警告列を複製しない。 -/
def own (key : OperationKey) (op : BinOp) (type : Ty) (left right : BaseApprox) :
    Analysis BaseApprox := do
  let result := baseOwn key op type left right
  saveWarnings result.warnings
  pure { result with warnings := [] }

/-- 負号の警告も同じ共有列へ保存する。 -/
def negOwn (key : OperationKey) (child : BaseApprox) : Analysis BaseApprox := do
  let result := baseNegOwn key child
  saveWarnings result.warnings
  pure { result with warnings := [] }

/-- 型を保った負号の候補も、親自身の共有列へ一度だけ保存する。 -/
def negOwnTyped (key : OperationKey) (type : Ty) (child : BaseApprox) : Analysis BaseApprox := do
  let result := baseNegOwnTyped key type child
  saveWarnings result.warnings
  pure { result with warnings := [] }

@[simp] theorem negOwnTyped_integer (key child) :
    negOwnTyped key (.base .integer) child = negOwn key child := rfl

/-- 到達可能な枝だけ値を解析する。番号は到達不能の枝でも消費する。 -/
def branch (env : AbstractEnv) (source : Expr) (tested : BaseApprox) (truth : Bool)
    (run : AbstractEnv → Analysis BaseApprox) (skip : Unit → Analysis Unit) : Analysis BaseApprox :=
  scope fun _ => do
    let refined ← scan (BudgetScan.branch env source tested.boolean truth)
    match refined with
    | none => do skip (); pure baseEmpty
    | some inner => run inner

/-- 現 profile が具体評価する二項演算だけ、子の事実と警告を利用する。 -/
def binarySupported (op : BinOp) : Ty → Bool
  | .base .integer => decide (op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true)
  | type => (IntKind.ofType type).isSome &&
      decide (op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨ (Comparison.ofBinOp op).isSome = true)

/-- 負号は Integer64 の具体規則だけを対象にする。 -/
def negSupported : Ty → Bool
  | .base .integer => true
  | _ => false

theorem negSupported_eq (type : Ty) : negSupported type = true ↔ type = .base .integer := by
  cases type <;> try simp [negSupported]
  rename_i base
  cases base <;> simp

/-- 具体評価を持つ符号付き四種だけ、子から同じ本体の事実を受け取る。 -/
def negModeled (type : Ty) : Bool :=
  match IntKind.ofType type with
  | some kind => decide (kind.min < 0)
  | none => false

@[simp] theorem negModeled_integer : negModeled (.base .integer) = true := by decide

theorem binarySupported_kind (op : WidthBinary) (kind : IntKind) :
    binarySupported op.op kind.type = true := by
  cases kind <;> cases op <;> simp [binarySupported, WidthBinary.op, IntKind.type,
    IntKind.ofType, IntegerDivisionOp]

theorem binarySupported_iff (op : BinOp) (type : Ty) :
    binarySupported op type = true ↔
      (IntKind.ofType type).isSome = true ∧
      (op = .add ∨ op = .sub ∨ op = .mul ∨ IntegerDivisionOp op ∨
        (Comparison.ofBinOp op).isSome = true) := by
  cases type <;> try simp [binarySupported, IntKind.ofType]
  rename_i base
  cases base <;> simp [binarySupported, IntKind.ofType]

theorem negModeled_kind (kind : IntKind) (signed : kind.min < 0) :
    negModeled kind.type = true := by
  cases kind <;> simp_all [negModeled, IntKind.type, IntKind.ofType]

/-- 種類付きの正常区間を局所位置へ保存し、同じ追加費用を計上する。 -/
def bindApprox (kind : BindKind) (env : AbstractEnv) (type : Ty) (value : BaseApprox) :
    BudgetScan.Scan AbstractEnv :=
  match IntKind.ofType type with
  | some width => BudgetScan.push env (integerKindSlot width (value.rangeKind width))
  | none => BudgetScan.bindEnv kind env type value.integer

/-- 種類の選択と位置の追加は、予算なしの束縛規則と一致する。 -/
theorem bindApprox_agrees (kind env type value) :
    BudgetScan.Agrees (bindApprox kind env type value) (baseBind kind env type value) := by
  cases found : IntKind.ofType type with
  | none =>
    simpa only [bindApprox, baseBind, found] using BudgetScan.bindEnv_agrees kind env type value.integer
  | some width =>
    simpa only [bindApprox, baseBind, found, bindRangeKind] using
      BudgetScan.push_agrees env (integerKindSlot width (value.rangeKind width))

mutual
/-- 式の訪問・番号・局所操作を一つの状態で逐次実行する。 -/
def expr : Nat → AbstractEnv → Expr → Analysis BaseApprox
  | 0, _, _ => throw .depth
  | fuel + 1, env, source => scope fun _ => do
    let key ← identify source
    scan (BudgetScan.tick .expression)
    match source with
    | .literal (.integer value) => pure (baseInteger (normalize value.toValue.toInt value.toValue.toInt))
    | .negInt value => pure (baseInteger (normalize value.negValue.toInt value.negValue.toInt))
    | .literal (.integer8 value) => widthLiteral .integer8 (value : Int)
    | .literal (.integer16 value) => widthLiteral .integer16 (value : Int)
    | .literal (.integer32 value) => widthLiteral .integer32 (value : Int)
    | .literal (.unsignedInteger16 value) => widthLiteral .unsignedInteger16 (value : Int)
    | .literal (.unsignedInteger32 value) => widthLiteral .unsignedInteger32 (value : Int)
    | .literal (.unsignedInteger64 value) => widthLiteral .unsignedInteger64 (value : Int)
    | .negInteger8 value => widthLiteral .integer8 (-(value : Int))
    | .negInteger16 value => widthLiteral .integer16 (-(value : Int))
    | .negInteger32 value => widthLiteral .integer32 (-(value : Int))
    | .literal (.boolean value) => pure (baseBoolean (!value, value))
    | .unit => pure baseUnit
    | .local index =>
      let slot ← scan (BudgetScan.read env index)
      match slot with
      | some (.integer range) => pure (baseInteger range true)
      | some (.integerKind width range) => pure (baseIntegerKind width range true)
      | _ => pure baseUnknown
    | .paren child => expr fuel env child
    | .constE _ child => expr fuel (clearLocals env) child
    | .returnE _ child => do pure (← expr fuel env child).abrupt
    | .neg type child =>
      if negModeled type then do
        let value ← expr fuel env child
        pure (baseThen value (← negOwnTyped key type value))
      else do
        unknownChildren (expr fuel) (block fuel) fuel env source
        unsupported
    | .binary op type left right =>
      if binarySupported op type then do
        let lhs ← expr fuel env left
        if !lhs.live then
          skipExpr fuel right
          pure lhs.abrupt
        else do
          let rhs ← expr fuel env right
          if !rhs.live then pure (baseThen lhs rhs.abrupt)
          else do pure (baseThen lhs (baseThen rhs (← own key op type lhs rhs)))
      else do
        unknownChildren (expr fuel) (block fuel) fuel env source
        unsupported
    | .and left right => shortCircuit fuel env left right true
    | .or left right => shortCircuit fuel env left right false
    | .call callee labels positions sources =>
      let recognized ← scan (BudgetScan.rangeCall env key source)
      match recognized with
      | none => do
        unknownChildren (expr fuel) (block fuel) fuel env source
        unsupported
      | some binding => do
        skipExpr fuel callee
        if fixedBinding binding then do
          let selected ← selectArguments (expr fuel env) (skipExprs fuel)
            (bindingArgument binding) positions sources
          pure (baseThen selected (← fixedOwn binding key selected))
        else do
          let values ← arguments fuel env sources
          let output ← scan (BudgetScan.rangeValue env ⟨source, .base .integer, key⟩)
          pure (baseThen values output)
    | .matchE _ source arms =>
      let tested ← expr fuel env source
      if !tested.live then do skipArms fuel arms; pure tested.abrupt
      else do
        let input : EvalInput := ⟨source, .base .unit, childKey key []⟩
        let known ← scan (BudgetScan.rangeMatch env input arms)
        match known with
        | some _ => pure (baseThen tested (← resultArmList fuel env input arms))
        | none => match tested.matchKind with
          | some kind => pure (baseThen tested (← armListKind fuel kind env source (tested.rangeKind kind) arms))
          | none => do
            skipArms fuel arms
            pure (baseThen tested (← unsupported))
    | .not child =>
      let value ← expr fuel env child
      pure { baseBoolean (value.boolean.2, value.boolean.1) with mayFail := value.mayFail }
    | .block body => block fuel env body
    | .ite condition yes no =>
      let tested ← expr fuel env condition
      let positive ← branch env condition tested true
        (fun inner => block fuel inner yes) (fun _ => skipBlock fuel yes)
      let negative ← branch env condition tested false
        (fun inner => block fuel inner no) (fun _ => skipBlock fuel no)
      pure (baseMerge tested positive negative)
    | .elseIf condition yes no =>
      let tested ← expr fuel env condition
      let positive ← branch env condition tested true
        (fun inner => block fuel inner yes) (fun _ => skipBlock fuel yes)
      let negative ← branch env condition tested false
        (fun inner => expr fuel inner no) (fun _ => skipExpr fuel no)
      pure (baseMerge tested positive negative)
    | .ifOnly condition yes =>
      let tested ← expr fuel env condition
      let positive ← branch env condition tested true
        (fun inner => block fuel inner yes) (fun _ => skipBlock fuel yes)
      let negative ← branch env condition tested false (fun _ => pure baseUnit) (fun _ => pure ())
      pure (baseMerge tested positive negative)
    | _ => do
      unknownChildren (expr fuel) (block fuel) fuel env source
      unsupported

/-- 左辺の正常値で継続する右辺だけを解析する。 -/
def shortCircuit : Nat → AbstractEnv → Expr → Expr → Bool → Analysis BaseApprox
  | 0, _, _, _, _ => throw .depth
  | fuel + 1, env, left, right, continueTruth => do
    let tested ← expr fuel env left
    let continued ← branch env left tested continueTruth
      (fun inner => expr fuel inner right) (fun _ => skipExpr fuel right)
    let shorted ← branch env left tested (!continueTruth)
      (fun _ => pure (baseBoolean (continueTruth, !continueTruth))) (fun _ => pure ())
    pure (baseMerge tested continued shorted)

/-- 容器自身は番号を増やさず、分類と作業枠を計上する。 -/
def block : Nat → AbstractEnv → Block → Analysis BaseApprox
  | 0, _, _ => throw .depth
  | fuel + 1, env, body => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match body with
    | .empty => pure baseUnit
    | .builderBind kind rest =>
      let inner ← scan (BudgetScan.push env (.builder kind))
      block fuel inner rest
    | .last source => expr fuel env source
    | .lastBind _ _ source | .lastDiscard source | .lastPat _ _ _ source => do
      pure (baseDiscard (← expr fuel env source))
    | .bind kind type source rest =>
      let start ← get
      let head ← expr fuel env source
      if !head.live then do skipBlock fuel rest; pure head.abrupt
      else do
        let inner ← scan (BudgetScan.rangeBind kind env type head ⟨source, type, start.next⟩)
        pure (baseThen head (← block fuel inner rest))
    | .discard source rest | .seq source rest =>
      let head ← expr fuel env source
      if !head.live then do skipBlock fuel rest; pure head.abrupt
      else do pure (baseThen head (← block fuel env rest))
    | .bindPat _ pattern type source rest =>
      let head ← expr fuel env source
      if !head.live then do skipBlock fuel rest; pure head.abrupt
      else do
        let inner ← scan (BudgetScan.patternEnv env pattern type)
        pure (baseThen head (← block fuel inner rest))

/-- 前の腕の失敗・guard の偽から次の腕へ事実を渡さない。 -/
def armListKind : (fuel : Nat) → (kind : IntKind) → AbstractEnv → Expr → Interval kind → Arms → Analysis BaseApprox
  | 0, _, _, _, _, _ => throw .depth
  | fuel + 1, kind, env, source, normal, arms => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match arms with
    | .nil => pure baseEmpty
    | .cons alts guard body rest =>
      let first ← scope fun _ => do
        let inner ← scan (BudgetScan.armKind env source kind normal alts)
        match inner with
        | none => do skipOptional fuel guard; skipBlock fuel body; pure baseEmpty
        | some inner =>
          match guard with
          | none => block fuel inner body
          | some condition =>
            let tested ← expr fuel inner condition
            let positive ← branch inner condition tested true
              (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
            pure (baseMerge tested positive baseEmpty)
      let tail ← armListKind fuel kind env source normal rest
      pure (baseJoin first tail)
/-- 認定した標準引数をソース順に解析し、代表の Unit へ正常性を射影する。 -/
def arguments : Nat → AbstractEnv → Exprs → Analysis BaseApprox
  | 0, _, _ => throw .depth
  | fuel + 1, env, sources => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match sources with
    | .nil => pure baseUnit
    | .cons source rest =>
      let head ← expr fuel env source
      if !head.live then do skipExprs fuel rest; pure head.abrupt
      else pure (baseThen head (← arguments fuel env rest))

/-- Result の各腕で新しい位置を作り、Ok の同じ成功値だけへ由来を付ける。 -/
def resultArmList : Nat → AbstractEnv → EvalInput → Arms → Analysis BaseApprox
  | 0, _, _, _ => throw .depth
  | fuel + 1, env, input, arms => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match arms with
    | .nil => pure baseEmpty
    | .cons alts guard body rest =>
      let first ← scope fun _ => do
        let inner ← scan (BudgetScan.rangeArm env input alts)
        match guard with
        | none => block fuel inner body
        | some condition =>
          let tested ← expr fuel inner condition
          let positive ← branch inner condition tested true
            (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
          pure (baseMerge tested positive baseEmpty)
      let tail ← resultArmList fuel env input rest
      pure (baseJoin first tail)

end

/-- Integer64 の腕入口を、従来の引数で保つ。 -/
abbrev armList (fuel : Nat) (env : AbstractEnv) (source : Expr) (normal : Interval) (arms : Arms) :
    Analysis BaseApprox := armListKind fuel .integer64 env source normal arms

/-- 忘却後の環境を受け取り、本体の初期化や終了を挟まず走査する。 -/
def IndependentInput.run (input : IndependentInput) (fuel : Nat) (env : AbstractEnv) :
    Analysis BaseApprox :=
  match input with
  | .expr source => BudgetAnalysis.expr fuel env source
  | .block body => BudgetAnalysis.block fuel env body

/-- Expr と Block に共通の独立入力の入口。親へ値・return・絞り込みを戻さない。 -/
def independent (fuel : Nat) (env : AbstractEnv) (input : IndependentInput) : Analysis Unit :=
  independentWith input env (input.run fuel)

/-- 完走の有無と未対応を区別し、Bottom は正常値から独立に判定する。 -/
inductive Coverage where
  | complete | unsupported | stopped (reason : Halt)
  deriving DecidableEq, Repr

/-- 保存列は逆順。context は本体終了前、after は次の本体へ渡す状態である。 -/
structure Report where
  approx : BaseApprox
  coverage : Coverage
  context : Context
  after : Budget.State

/-- 停止時は正常値を Top に退けるが、保存済みの警告を捨てない。 -/
def report (result : Except Halt BaseApprox) (ctx : Context) : Report :=
  let approx := match result with | .ok value => value | .error _ => baseUnknown
  let coverage := match result with
    | .error reason => Coverage.stopped reason
    | .ok _ => if ctx.unsupported then .unsupported else .complete
  ⟨{ approx with warnings := ctx.warningsRev }, coverage, ctx, finishBody ctx.budget⟩

/-- 完走・停止のどちらでも、出力は保存に成功した警告列をそのまま含む。 -/
theorem report_warnings (result : Except Halt BaseApprox) (ctx : Context) :
    (report result ctx).approx.warnings = ctx.warningsRev := rfl

/-- 停止時の Top は未取得の正常値を捨てず、停止理由と保存済み警告を残す。 -/
theorem report_stopped (reason : Halt) (ctx : Context) :
    (report (.error reason) ctx).approx.integer = top ∧
    (report (.error reason) ctx).approx.boolean = (true, true) ∧
    (report (.error reason) ctx).approx.other = true ∧
    (report (.error reason) ctx).coverage = .stopped reason ∧
    (report (.error reason) ctx).approx.warnings = ctx.warningsRev := by
  exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- 本体終了後も、累積操作数・保存項目・最大同時保持を次へ渡す。 -/
theorem report_after (result : Except Halt BaseApprox) (ctx : Context) :
    (report result ctx).after.whole.operations = ctx.budget.whole.operations ∧
    (report result ctx).after.savedHeld = ctx.budget.savedHeld ∧
    (report result ctx).after.whole.peak = ctx.budget.whole.peak :=
  ⟨finish_operations _, finish_saved _, finish_peak _⟩

/-- 既に保持した環境を借用する、式の解析の入口。深さは独立に制限できる。 -/
def analyzeExpr (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (source : Expr) : Report :=
  let (result, ctx) := expr fuel (resetRanges env) source limits { budget := state, next := key }
  report result ctx

/-- 中心命題は上限・初期消費・深さのどれにも制約を付けずに量化する。 -/
structure Parameters where
  limits : Limits
  state : Budget.State
  fuel : Nat

/-- 型内の正常値と近似への所属を共通の解析結果へ射影する。 -/
def Report.toAnalysisResult (output : Report) (type : Ty) : AnalysisResult :=
  ⟨fun value => value.type = type ∧ output.approx.Contains value,
    output.approx.mayFail, output.approx.warnings⟩

/-- 共有予算を受け取る中心命題の入口。停止も成功と同じ射影を使う。 -/
def analyze (env : AbstractEnv) (input : EvalInput) (parameters : Parameters) : AnalysisResult :=
  Report.toAnalysisResult
    (analyzeExpr parameters.limits parameters.state parameters.fuel env input.key input.source) input.type

/-- 本体の根も式として数え、入口環境の一時項目は解析の終了まで保持する。 -/
def bodyWork (fuel : Nat) (seed : BodySeed) : Analysis BaseApprox :=
  scope fun _ => do
    let initial ← scan (BudgetScan.forgetEnv seed.initial)
    expr fuel initial (bodyRoot seed.body)

/-- 本体入口も予算内で作り、終了時には一時項目だけを返す。
全体が尽きた後の本体は環境の構築・番号付けを始めない。 -/
def analyzeBody (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) : Report :=
  let ctx : Context := { budget := state, next := bodyRootKey definition }
  if state.whole.operations ≥ limits.whole.operations then
    report (.error (.budget (.exceeded ⟨.whole, .operations⟩))) ctx
  else if state.wholeHeld ≥ limits.whole.items then
    report (.error (.budget (.exceeded ⟨.whole, .items⟩))) ctx
  else
    let (result, final) := bodyWork fuel seed limits ctx
    report result final

end Benitoite.Interval.BudgetAnalysis
