# 変更した内部補助定理の言明

基準は `8a59b630f9fdef8d1e1595f7999c6242d167d739`。公開入口の定理は同じ言明を保つ。以下は private や属性を含む内部補助定理38件の正確な差分である。引数の既定証明内の `:=` と本文の `:=` を区別して抽出した。

## formal/Benitoite/Interval/BudgetBody.lean:bodyWork_normal

変更前:

```lean
theorem bodyWork_normal (fuel : Nat) {seed : BodySeed} {concrete type key outcome trace}
    (models : Models (forget seed.initial) concrete)
    (eval : EvalPartial concrete ⟨bodyRoot seed.body, type, key⟩ outcome trace) :
    Success (bodyWork fuel seed) (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem bodyWork_normal (fuel : Nat) {seed : BodySeed} {concrete type key outcome trace}
    (models : Models (forget seed.initial) concrete)
    (eval : EvalPartial concrete ⟨bodyRoot seed.body, type, key⟩ outcome trace) :
    SuccessAt key (bodyWork fuel seed) (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetCause.lean:expr_normal_next

変更前:

```lean
theorem expr_normal_next (fuel : Nat) {abstract concrete input outcome trace limits ctx approx final}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace)
    (ok : expr fuel abstract input.source limits ctx = (.ok approx, final)) :
    NormalCovered approx outcome ∧ final.next = advanceKey ctx.next (surfaceSize input.source)
```

変更後:

```lean
theorem expr_normal_next (fuel : Nat) {abstract concrete input outcome trace limits ctx approx final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace)
    (ok : expr fuel abstract input.source limits ctx = (.ok approx, final))
    (start : ctx.next = input.key := by first | assumption | simp_all only [advanceKey, childKey]) :
    NormalCovered approx outcome ∧ final.next = advanceKey ctx.next (surfaceSize input.source)
```

## formal/Benitoite/Interval/BudgetCause.lean:block_normal_next

変更前:

```lean
theorem block_normal_next (fuel : Nat) {abstract concrete key body type outcome trace limits ctx approx final}
    (models : Models abstract concrete) (eval : EvalBlock concrete key body type outcome trace)
    (ok : block fuel abstract body limits ctx = (.ok approx, final)) :
    NormalCovered approx outcome ∧ final.next = advanceKey ctx.next (blockSize body)
```

変更後:

```lean
theorem block_normal_next (fuel : Nat) {abstract concrete key body type outcome trace limits ctx approx final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace)
    (ok : block fuel abstract body limits ctx = (.ok approx, final))
    (start : ctx.next = key) :
    NormalCovered approx outcome ∧ final.next = advanceKey ctx.next (blockSize body)
```

## formal/Benitoite/Interval/BudgetCause.lean:binary_operands

変更前:

```lean
theorem binary_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    lhs.Contains (.integer a) ∧ rhs.Contains (.integer b) ∧
      middle.next = childKey root [left] ∧
      final.next = advanceKey (childKey root [left]) (surfaceSize right)
```

変更後:

```lean
theorem binary_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    lhs.Contains (.integer a) ∧ rhs.Contains (.integer b) ∧
      middle.next = childKey root [left] ∧
      final.next = advanceKey (childKey root [left]) (surfaceSize right)
```

## formal/Benitoite/Interval/BudgetCause.lean:causal_add_of_operands

変更前:

```lean
theorem causal_add_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .add (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩]
```

変更後:

```lean
theorem causal_add_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .add (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩]
```

## formal/Benitoite/Interval/BudgetCause.lean:causal_sub_of_operands

変更前:

```lean
theorem causal_sub_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .sub (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .sub (.base .integer), [.integer a, .integer b], checkedSub a b⟩]
```

変更後:

```lean
theorem causal_sub_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .sub (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .sub (.base .integer), [.integer a, .integer b], checkedSub a b⟩]
```

## formal/Benitoite/Interval/BudgetCause.lean:causal_mul_of_operands

変更前:

```lean
theorem causal_mul_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .mul (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .mul (.base .integer), [.integer a, .integer b], checkedMul a b⟩]
```

変更後:

```lean
theorem causal_mul_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .mul (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .mul (.base .integer), [.integer a, .integer b], checkedMul a b⟩]
```

## formal/Benitoite/Interval/BudgetCause.lean:causal_div_of_operands

変更前:

```lean
theorem causal_div_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs op}
    (target : IntegerDivisionOp op) (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root op (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩]
```

変更後:

```lean
theorem causal_div_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs op}
    (target : IntegerDivisionOp op) (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root op (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩]
```

## formal/Benitoite/Interval/BudgetCause.lean:branch_entry_of_success

変更前:

```lean
theorem branch_entry_of_success (fuel : Nat)
    {abstract concrete input truth trace limits ctx tested final}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace)
    (ok : expr fuel abstract input.source limits ctx = (.ok tested, final)) :
    ∃ inner, branchEnv abstract input.source tested.boolean truth = some inner ∧
      Models inner concrete
```

変更後:

```lean
theorem branch_entry_of_success (fuel : Nat)
    {abstract concrete input truth trace limits ctx tested final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace)
    (ok : expr fuel abstract input.source limits ctx = (.ok tested, final))
    (start : ctx.next = input.key := by first | assumption | simp_all only [advanceKey, childKey]) :
    ∃ inner, branchEnv abstract input.source tested.boolean truth = some inner ∧
      Models inner concrete ∧ inner.ranges.Models concrete
```

## formal/Benitoite/Interval/BudgetCause.lean:arm_entry_of_success

変更前:

```lean
theorem arm_entry_of_success (fuel : Nat)
    {abstract concrete source root value trace selected alts limits ctx tested final}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete ⟨source, .base .integer, root⟩ (.normal (.integer value)) trace)
    (selection : IntegerSelection alts value selected)
    (ok : expr fuel abstract source limits ctx = (.ok tested, final)) :
    ∃ inner, matchArmEnv abstract source (.base .integer) tested.integer alts = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals }
```

変更後:

```lean
theorem arm_entry_of_success (fuel : Nat)
    {abstract concrete source root value trace selected alts limits ctx tested final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete ⟨source, .base .integer, root⟩ (.normal (.integer value)) trace)
    (selection : IntegerSelection alts value selected)
    (ok : expr fuel abstract source limits ctx = (.ok tested, final))
    (start : ctx.next = root := by first | assumption | simp_all only [advanceKey, childKey]) :
    ∃ inner, matchArmEnv abstract source (.base .integer) tested.integer alts = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals }
```

## formal/Benitoite/Interval/BudgetIndependentSound.lean:IndependentInput.run_normal

変更前:

```lean
theorem IndependentInput.run_normal (input : IndependentInput) (fuel : Nat)
    {env concrete type key outcome trace} (models : Models env concrete)
    (eval : input.Evaluates concrete key type outcome trace) :
    Success (input.run fuel env) (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem IndependentInput.run_normal (input : IndependentInput) (fuel : Nat)
    {env concrete type key outcome trace} (models : Models env concrete)
    (ranges : env.ranges.Models concrete)
    (eval : input.Evaluates concrete key type outcome trace) :
    SuccessAt key (input.run fuel env) (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetIndependentSound.lean:IndependentInput.run_causal

変更前:

```lean
theorem IndependentInput.run_causal (input : IndependentInput) (fuel : Nat)
    {env concrete type key outcome trace} (models : Models env concrete)
    (eval : input.Evaluates concrete key type outcome trace) (limits : Limits) (ctx : Context)
    (start : ctx.next = key) :
    ListExtension (fun warning => ∀ event, Reached trace warning event →
      event.result = .rejected warning.cause.toFailure)
      ctx.warningsRev (input.run fuel env limits ctx).2.warningsRev
```

変更後:

```lean
theorem IndependentInput.run_causal (input : IndependentInput) (fuel : Nat)
    {env concrete type key outcome trace} (models : Models env concrete)
    (ranges : env.ranges.Models concrete)
    (eval : input.Evaluates concrete key type outcome trace) (limits : Limits) (ctx : Context)
    (start : ctx.next = key) :
    ListExtension (fun warning => ∀ event, Reached trace warning event →
      event.result = .rejected warning.cause.toFailure)
      ctx.warningsRev (input.run fuel env limits ctx).2.warningsRev
```

## formal/Benitoite/Interval/BudgetNormal.lean:expr_normal

変更前:

```lean
theorem expr_normal (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace) :
    Success (expr fuel abstract input.source) (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem expr_normal (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace) :
    SuccessAt input.key (expr fuel abstract input.source) (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:binary_normal

変更前:

```lean
theorem binary_normal (fuel : Nat) {abstract concrete key op leftSource rightSource a b lt rt outcome}
    (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨leftSource, .base .integer, leftKey⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨rightSource, .base .integer, rightKey⟩ (.normal (.integer b)) rt)
    (supported : binarySupported op (.base .integer) = true)
    (operation : ∀ left right, left.Contains (.integer a) → right.Contains (.integer b) →
      NormalCovered (baseBinary key op (.base .integer) left right) outcome) :
    Success (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt
      else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt)
        else pure (baseThen lhs (baseThen rhs (← own key op (.base .integer) lhs rhs))))
      (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem binary_normal (fuel : Nat) {abstract concrete key op leftSource rightSource a b lt rt outcome}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨leftSource, .base .integer, leftKey⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨rightSource, .base .integer, rightKey⟩ (.normal (.integer b)) rt)
    (rightStart : rightKey = advanceKey leftKey (surfaceSize leftSource))
    (supported : binarySupported op (.base .integer) = true)
    (operation : ∀ left right, left.Contains (.integer a) → right.Contains (.integer b) →
      NormalCovered (baseBinary key op (.base .integer) left right) outcome) :
    SuccessAt leftKey (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt
      else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt)
        else pure (baseThen lhs (baseThen rhs (← own key op (.base .integer) lhs rhs))))
      (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:widthBinary_normal

変更前:

```lean
theorem widthBinary_normal (fuel : Nat)
    {abstract concrete key op kind leftSource rightSource a b lt rt outcome}
    (models : Models abstract concrete)
    (el : EvalPartial concrete ⟨leftSource, IntKind.type kind, leftKey⟩
      (.normal (.ofInteger kind a)) lt)
    (er : EvalPartial concrete ⟨rightSource, IntKind.type kind, rightKey⟩
      (.normal (.ofInteger kind b)) rt)
    (operation : ∀ left right, left.Contains (.ofInteger kind a) →
      right.Contains (.ofInteger kind b) →
      NormalCovered (baseOwn key op kind.type left right) outcome) :
    Success (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt
      else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt)
        else pure (baseThen lhs (baseThen rhs (← own key op kind.type lhs rhs))))
      (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem widthBinary_normal (fuel : Nat)
    {abstract concrete key op kind leftSource rightSource a b lt rt outcome}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨leftSource, IntKind.type kind, leftKey⟩
      (.normal (.ofInteger kind a)) lt)
    (er : EvalPartial concrete ⟨rightSource, IntKind.type kind, rightKey⟩
      (.normal (.ofInteger kind b)) rt)
    (rightStart : rightKey = advanceKey leftKey (surfaceSize leftSource))
    (operation : ∀ left right, left.Contains (.ofInteger kind a) →
      right.Contains (.ofInteger kind b) →
      NormalCovered (baseOwn key op kind.type left right) outcome) :
    SuccessAt leftKey (do
      let lhs ← expr fuel abstract leftSource
      if !lhs.live then do skipExpr fuel rightSource; pure lhs.abrupt
      else do
        let rhs ← expr fuel abstract rightSource
        if !rhs.live then pure (baseThen lhs rhs.abrupt)
        else pure (baseThen lhs (baseThen rhs (← own key op kind.type lhs rhs))))
      (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:shortCircuit_short_normal

変更前:

```lean
theorem shortCircuit_short_normal (fuel : Nat) {abstract concrete left right truth key trace}
    (models : Models abstract concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (shorted : truth = !continueTruth) :
    Success (shortCircuit fuel abstract left right continueTruth)
      (fun approx => NormalCovered approx (.normal (.boolean truth)))
```

変更後:

```lean
theorem shortCircuit_short_normal (fuel : Nat) {abstract concrete left right truth key trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (shorted : truth = !continueTruth) :
    SuccessAt key (shortCircuit fuel abstract left right continueTruth)
      (fun approx => NormalCovered approx (.normal (.boolean truth)))
```

## formal/Benitoite/Interval/BudgetNormal.lean:shortCircuit_right_normal

変更前:

```lean
theorem shortCircuit_right_normal (fuel : Nat) {abstract concrete left right truth key rightKey trace outcome rt}
    (models : Models abstract concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (child : EvalPartial concrete ⟨right, .base .boolean, rightKey⟩ outcome rt) :
    Success (shortCircuit fuel abstract left right truth)
      (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem shortCircuit_right_normal (fuel : Nat) {abstract concrete left right truth key rightKey trace outcome rt}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (child : EvalPartial concrete ⟨right, .base .boolean, rightKey⟩ outcome rt)
    (rightStart : rightKey = advanceKey key (surfaceSize left)) :
    SuccessAt key (shortCircuit fuel abstract left right truth)
      (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:block_normal

変更前:

```lean
theorem block_normal (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (eval : EvalBlock concrete key body type outcome trace) :
    Success (block fuel abstract body) (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem block_normal (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace) :
    SuccessAt key (block fuel abstract body) (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:armList_normal

変更前:

```lean
theorem armList_normal (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    Success (armList fuel abstract source normal arms) (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem armList_normal (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    SuccessAt key (armList fuel abstract source normal arms) (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:armListKind_normal

変更前:

```lean
theorem armListKind_normal (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    Success (armListKind fuel kind abstract source normal arms) (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem armListKind_normal (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    SuccessAt key (armListKind fuel kind abstract source normal arms) (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetNormal.lean:shortCircuit_normal

変更前:

```lean
theorem shortCircuit_normal (fuel : Nat) {abstract concrete left right continueTruth key outcome trace}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete
      ⟨if continueTruth then .and left right else .or left right, .base .boolean, key⟩ outcome trace) :
    Success (shortCircuit fuel abstract left right continueTruth)
      (fun approx => NormalCovered approx outcome)
```

変更後:

```lean
theorem shortCircuit_normal (fuel : Nat) {abstract concrete left right continueTruth key outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete
      ⟨if continueTruth then .and left right else .or left right, .base .boolean, key⟩ outcome trace) :
    SuccessAt (childKey key []) (shortCircuit fuel abstract left right continueTruth)
      (fun approx => NormalCovered approx outcome)
```

## formal/Benitoite/Interval/BudgetPatterns.lean:selectReverse_agrees

変更前:

```lean
theorem selectReverse_agrees (slots : List AbstractSlot) (positions : List Nat)
    (tail : List AbstractSlot) :
    Agrees (selectReverse slots positions tail)
      ((selectSlots slots positions).map fun selected => selected.reverse ++ tail)
```

変更後:

```lean
theorem selectReverse_agrees (slots : List AbstractSlot) (positions : List Nat)
    (tail : List AbstractSlot) (ranges : RangeState) :
    Agrees (selectReverse slots positions tail ranges)
      ((selectSlots slots positions).map fun selected =>
        (selected.reverse ++ tail, ranges.extendUnknown selected.length))
```

## formal/Benitoite/Interval/BudgetSound.lean:expr_causal

変更前:

```lean
theorem expr_causal (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = input.key) :
    Causal (expr fuel abstract input.source) limits ctx input.key (surfaceSize input.source) trace
```

変更後:

```lean
theorem expr_causal (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = input.key) :
    Causal (expr fuel abstract input.source) limits ctx input.key (surfaceSize input.source) trace
```

## formal/Benitoite/Interval/BudgetSound.lean:shortCircuit_run_causal

変更前:

```lean
theorem shortCircuit_run_causal (fuel : Nat)
    {abstract concrete left right key truth lt outcome rt}
    (models : Models abstract concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) lt)
    (child : EvalPartial concrete ⟨right, .base .boolean, advanceKey key (surfaceSize left)⟩ outcome rt)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (shortCircuit fuel abstract left right truth) limits ctx key
      (surfaceSize left + surfaceSize right) (lt ++ rt)
```

変更後:

```lean
theorem shortCircuit_run_causal (fuel : Nat)
    {abstract concrete left right key truth lt outcome rt}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) lt)
    (child : EvalPartial concrete ⟨right, .base .boolean, advanceKey key (surfaceSize left)⟩ outcome rt)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (shortCircuit fuel abstract left right truth) limits ctx key
      (surfaceSize left + surfaceSize right) (lt ++ rt)
```

## formal/Benitoite/Interval/BudgetSound.lean:shortCircuit_absent_causal

変更前:

```lean
theorem shortCircuit_absent_causal (fuel : Nat)
    {abstract concrete left right key truth outcome lt}
    (models : Models abstract concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ outcome lt)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (shortCircuit fuel abstract left right truth) limits ctx key
      (surfaceSize left + surfaceSize right) lt
```

変更後:

```lean
theorem shortCircuit_absent_causal (fuel : Nat)
    {abstract concrete left right key truth outcome lt}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ outcome lt)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (shortCircuit fuel abstract left right truth) limits ctx key
      (surfaceSize left + surfaceSize right) lt
```

## formal/Benitoite/Interval/BudgetSound.lean:block_causal

変更前:

```lean
theorem block_causal (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (eval : EvalBlock concrete key body type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (block fuel abstract body) limits ctx key (blockSize body) trace
```

変更後:

```lean
theorem block_causal (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (block fuel abstract body) limits ctx key (blockSize body) trace
```

## formal/Benitoite/Interval/BudgetSound.lean:armList_causal

変更前:

```lean
theorem armList_causal (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (armList fuel abstract source normal arms) limits ctx key (armsSize arms) trace
```

変更後:

```lean
theorem armList_causal (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (armList fuel abstract source normal arms) limits ctx key (armsSize arms) trace
```

## formal/Benitoite/Interval/BudgetSound.lean:armListKind_causal

変更前:

```lean
theorem armListKind_causal (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (armListKind fuel kind abstract source normal arms) limits ctx key (armsSize arms) trace
```

変更後:

```lean
theorem armListKind_causal (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (armListKind fuel kind abstract source normal arms) limits ctx key (armsSize arms) trace
```

## formal/Benitoite/Interval/Sound.lean:unknown_base

変更前:

```lean
private theorem unknown_base (fuel : Nat) {concrete input}
    (unknown : UnknownAt concrete input) (env : AbstractEnv) :
    analyzeBaseExpr fuel env input.key input.source = baseUnknown
```

変更後:

```lean
private theorem unknown_base (fuel : Nat) {concrete input}
    (unknown : UnknownAt concrete input) (env : AbstractEnv) (models : Models env concrete) :
    analyzeBaseExpr fuel env input.key input.source = baseUnknown
```

## formal/Benitoite/Interval/Sound.lean:base_normal_sound

変更前:

```lean
private theorem base_normal_sound (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete)
    (eval : EvalPartial concrete input outcome trace) :
    NormalCovered (analyzeBaseExpr fuel abstract input.key input.source) outcome
```

変更後:

```lean
private theorem base_normal_sound (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input outcome trace) :
    NormalCovered (analyzeBaseExpr fuel abstract input.key input.source) outcome
```

## formal/Benitoite/Interval/Sound.lean:base_block_normal_sound

変更前:

```lean
private theorem base_block_normal_sound (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete)
    (eval : EvalBlock concrete key body type outcome trace) :
    NormalCovered (analyzeBaseBlock fuel abstract key body) outcome
```

変更後:

```lean
private theorem base_block_normal_sound (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (eval : EvalBlock concrete key body type outcome trace) :
    NormalCovered (analyzeBaseBlock fuel abstract key body) outcome
```

## formal/Benitoite/Interval/Sound.lean:base_arms_normal_sound

変更前:

```lean
private theorem base_arms_normal_sound (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    NormalCovered (analyzeBaseArms fuel abstract source normal key arms) outcome
```

変更後:

```lean
private theorem base_arms_normal_sound (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    NormalCovered (analyzeBaseArms fuel abstract source normal key arms) outcome
```

## formal/Benitoite/Interval/Sound.lean:base_widthArms_normal_sound

変更前:

```lean
private theorem base_widthArms_normal_sound (fuel : Nat) (kind : IntKind)
    {abstract concrete source key scrutineeKey arms type outcome trace st}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64) (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    NormalCovered (analyzeBaseKindArms fuel kind abstract source normal key arms) outcome
```

変更後:

```lean
private theorem base_widthArms_normal_sound (fuel : Nat) (kind : IntKind)
    {abstract concrete source key scrutineeKey arms type outcome trace st}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64) (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    NormalCovered (analyzeBaseKindArms fuel kind abstract source normal key arms) outcome
```

## formal/Benitoite/Interval/Sound.lean:base_warning_sound

変更前:

```lean
private theorem base_warning_sound (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace) :
    Good input.key (surfaceSize input.source)
      (analyzeBaseExpr fuel abstract input.key input.source).warnings trace
```

変更後:

```lean
private theorem base_warning_sound (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace) :
    Good input.key (surfaceSize input.source)
      (analyzeBaseExpr fuel abstract input.key input.source).warnings trace
```

## formal/Benitoite/Interval/Sound.lean:base_block_warning_sound

変更前:

```lean
private theorem base_block_warning_sound (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (eval : EvalBlock concrete key body type outcome trace) :
    Good key (blockSize body) (analyzeBaseBlock fuel abstract key body).warnings trace
```

変更後:

```lean
private theorem base_block_warning_sound (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace) :
    Good key (blockSize body) (analyzeBaseBlock fuel abstract key body).warnings trace
```

## formal/Benitoite/Interval/Sound.lean:base_arms_warning_sound

変更前:

```lean
private theorem base_arms_warning_sound (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseArms fuel abstract source normal key arms).warnings trace
```

変更後:

```lean
private theorem base_arms_warning_sound (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseArms fuel abstract source normal key arms).warnings trace
```

## formal/Benitoite/Interval/Sound.lean:base_widthArms_warning_sound

変更前:

```lean
private theorem base_widthArms_warning_sound (fuel : Nat) (kind : IntKind)
    {abstract concrete source key scrutineeKey arms type outcome trace st}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64) (models : Models abstract concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseKindArms fuel kind abstract source normal key arms).warnings trace
```

変更後:

```lean
private theorem base_widthArms_warning_sound (fuel : Nat) (kind : IntKind)
    {abstract concrete source key scrutineeKey arms type outcome trace st}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64) (models : Models abstract concrete) (rangeRelated : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    Good key (armsSize arms) (analyzeBaseKindArms fuel kind abstract source normal key arms).warnings trace
```

## formal/Benitoite/Interval/SyntacticReach.lean:concreteRule_known

変更前:

```lean
theorem concreteRule_known {source : Expr} (concrete : concreteRule source = true)
    (env : ConcreteEnv) (type : Ty) (key : OperationKey) :
    ¬ UnknownAt env ⟨source, type, key⟩
```

変更後:

```lean
theorem concreteRule_known {source : Expr} (concrete : concreteRule source = true)
    (env : ConcreteEnv) (type : Ty) (key : OperationKey)
    (callKnown : ∀ callee labels positions arguments,
      source = .call callee labels positions arguments →
      rangeCallBinding env ⟨source, type, key⟩ ≠ none) :
    ¬ UnknownAt env ⟨source, type, key⟩
```
