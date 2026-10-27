import Benitoite.Interval.BudgetTraversal

/-!
# 任意の予算に対する正常値の保存

成功値の所属を共有状態の逐次実行に沿って合成し、停止時は Top に退く。
警告の保存・位置・原因の証明とは分けて扱う。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 任意の入力状態から成功した値の性質。停止した実行には値を要求しない。 -/
def Success (work : Analysis α) (post : α → Prop) : Prop :=
  ∀ limits ctx value, (work limits ctx).1 = .ok value → post value

theorem success_any (work : Analysis α) : Success work (fun _ => True) := by
  intro limits ctx value ok
  trivial

theorem success_pure (value : α) {post : α → Prop} (h : post value) :
    Success (pure value) post := by
  intro limits ctx result ok
  cases ok
  exact h

theorem success_throw (reason : Halt) (post : α → Prop) :
    Success (throw reason) post := by
  intro limits ctx value ok
  cases ok

theorem success_bind {first : Analysis α} {next : α → Analysis β}
    {post : α → Prop} {result : β → Prop}
    (hf : Success first post) (hn : ∀ value, post value → Success (next value) result) :
    Success (first >>= next) result := by
  intro limits ctx value ok
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at ok
  cases run : first limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason => simp [run, ExceptT.bindCont, pure, StateT.pure] at ok
    | ok a =>
      exact hn a (hf limits ctx a (by simp [run])) limits middle value
        (by simpa only [run, ExceptT.bindCont] using ok)

theorem success_scope {work : Unit → Analysis α} {post : α → Prop}
    (h : Success (work ()) post) : Success (scope work) post := by
  intro limits ctx value ok
  unfold scope at ok
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    cases outcome with
    | error reason => simp [run] at ok
    | ok u =>
      cases inner : work () limits entered with
      | mk result final =>
        exact h limits entered value (by simpa only [run, inner] using ok)

theorem success_scan_agrees (work : BudgetScan.Scan α) (expected : α)
    (agrees : BudgetScan.Agrees work expected) : Success (scan work) (· = expected) := by
  intro limits ctx value ok
  exact (spec_scan_agrees work expected agrees limits ctx (fun _ => True) (fun _ => True)).2 value ok

theorem success_unsupported : Success unsupported (· = baseUnknown) := by
  intro limits ctx value ok
  cases ok
  rfl

/-- 型の値域外の表層数値は、未知の正常値を引き続き許す。 -/
theorem success_widthLiteral_unknown (kind : IntKind) (number : Int)
    (outside : ¬ (kind.min ≤ number ∧ number ≤ kind.max)) (outcome : EvalOutcome) :
    Success (widthLiteral kind number) (fun approx => NormalCovered approx outcome) := by
  simp only [widthLiteral, outside, ↓reduceIte]
  intro limits ctx approx ok
  have same := success_unsupported limits ctx approx ok
  subst approx
  exact fun value _ => unknown_contains value

/-- 正常な幅付きの葉は、共有予算でもその幅の一点区間を保つ。 -/
theorem success_widthLiteral_normal (kind : IntKind) (number : Int)
    (bounded : kind.min ≤ number ∧ number ≤ kind.max) :
    Success (widthLiteral kind number)
      (fun approx => NormalCovered approx (.normal (.ofInteger kind ⟨number, bounded⟩))) := by
  simp only [widthLiteral, bounded, ↓reduceIte]
  exact success_pure _ (by
    intro value normal
    cases normal
    exact baseWidthLiteral_contains kind number bounded)

/-- 警告欄の変更は正常値への所属を変えない。 -/
theorem contains_warnings (approx : BaseApprox) (warnings : List IntervalWarning)
    (value : ConcreteValue) :
    ({ approx with warnings := warnings } : BaseApprox).Contains value ↔ approx.Contains value := by
  cases value <;> rfl

theorem success_own (key op type left right) :
    Success (own key op type left right)
      (fun value => ∀ concrete, value.Contains concrete ↔
        (baseOwn key op type left right).Contains concrete) := by
  dsimp only [own]
  refine success_bind (first := saveWarnings _) (success_any _) ?_
  intro u _
  exact success_pure _ (contains_warnings _ _)

theorem success_negOwn (key child) :
    Success (negOwn key child)
      (fun value => ∀ concrete, value.Contains concrete ↔ (baseNegOwn key child).Contains concrete) := by
  dsimp only [negOwn]
  exact success_bind (success_any _) (fun _ _ => success_pure _ (contains_warnings _ _))

theorem success_negOwnTyped (key type child) :
    Success (negOwnTyped key type child)
      (fun value => ∀ concrete, value.Contains concrete ↔
        (baseNegOwnTyped key type child).Contains concrete) := by
  dsimp only [negOwnTyped]
  exact success_bind (success_any _) (fun _ _ => success_pure _ (contains_warnings _ _))

/-- 選択された枝では、走査の成功値の一致だけを使って同じ環境へ進む。 -/
theorem success_branch_selected {env source tested truth run skip inner post}
    (entry : branchEnv env source tested.boolean truth = some inner)
    (h : Success (run inner) post) :
    Success (branch env source tested truth run skip) post := by
  unfold branch
  apply success_scope
  refine success_bind (first := scan (BudgetScan.branch env source tested.boolean truth))
    (success_scan_agrees _ _ (BudgetScan.branch_agrees env source tested.boolean truth)) ?_
  intro refined eq
  rw [eq, entry]
  exact h

/-- 前半の値を使わない継続でも、前半の停止を成功と扱わない。 -/
theorem success_before (first : Analysis α) {next : α → Analysis β} {post : β → Prop}
    (h : ∀ value, Success (next value) post) : Success (first >>= next) post :=
  success_bind (success_any first) (fun value _ => h value)

theorem success_any_covered (work : Analysis BaseApprox) {outcome : EvalOutcome}
    (abrupt : ∀ value, outcome ≠ .normal value) :
    Success work (fun approx => NormalCovered approx outcome) := by
  intro limits ctx approx ok value normal
  exact False.elim (abrupt value normal)

theorem success_unknown_after (first : Analysis α) (outcome : EvalOutcome) :
    Success (first >>= fun _ => unsupported) (fun approx => NormalCovered approx outcome) := by
  refine success_before first (fun _ => ?_)
  intro limits ctx approx ok value normal
  have eq := success_unsupported limits ctx approx ok
  subst approx
  exact unknown_contains value

/-- 正常値の所属は警告のキーには依存しない。 -/
theorem own_contains {key op type left right value}
    (inside : (baseBinary key op type left right).Contains value)
    (hl : left.live = true) (hr : right.live = true)
    (supported : binarySupported op type = true) :
    (baseOwn key op type left right).Contains value := by
  have enabled := ((binarySupported_iff op type).mp supported).2
  cases type <;> try contradiction
  rename_i base
  cases base <;> try contradiction
  all_goals cases value <;> simpa only [baseBinary, baseOwn, IntKind.ofType, enabled,
    ↓reduceIte, baseThen, hl, hr, BaseApprox.Contains] using inside

/-- 開始キーを具体評価に合わせた、成功値の局所契約。 -/
def SuccessAt (key : OperationKey) (work : Analysis α) (post : α → Prop) : Prop :=
  ∀ limits ctx, ctx.next = key → ∀ value, (work limits ctx).1 = .ok value → post value

theorem Success.at {work : Analysis α} {post : α → Prop} (h : Success work post)
    (key : OperationKey) : SuccessAt key work post := by
  intro limits ctx _ value ok
  exact h limits ctx value ok

theorem SuccessAt.rekey {key other : OperationKey} {work : Analysis α} {post : α → Prop}
    (h : SuccessAt key work post)
    (same : other = key := by
      first
      | rfl
      | assumption
      | exact Eq.symm (by assumption)
      | simp_all [advanceKey, childKey, surfaceSize, preorderBlock_length, blockSize,
          guardSize, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]) :
    SuccessAt other work post := by
  intro limits ctx start value ok
  exact h limits ctx (start.trans same) value ok

/-- 成功した実行の次キーだけを、正常値の合成に用いる。 -/
class NormalWalk (work : Analysis α) (size : outParam Nat) : Prop where
  next : ∀ limits ctx value final, work limits ctx = (.ok value, final) →
    final.next = advanceKey ctx.next size

private theorem normalWalk_of_walk {work : Analysis α} {sources : List Expr}
    (h : Walk work sources) : NormalWalk work sources.length :=
  ⟨fun _ _ _ _ ok => (h.success ok).1⟩

instance normalWalk_pure (value : α) : NormalWalk (pure value : Analysis α) 0 :=
  normalWalk_of_walk (walk_pure value)
instance normalWalk_scan (work : BudgetScan.Scan α) : NormalWalk (scan work) 0 :=
  normalWalk_of_walk (walk_scan work)
instance normalWalk_expr (fuel env source) : NormalWalk (expr fuel env source) (surfaceSize source) :=
  normalWalk_of_walk ((analysis_walk fuel).1 env source)
instance normalWalk_block (fuel env body) : NormalWalk (block fuel env body) (blockSize body) := by
  simpa only [preorderBlock_length] using
    normalWalk_of_walk ((analysis_walk fuel).2.2.1 env body)
instance normalWalk_kindArms (fuel kind env source normal arms) :
    NormalWalk (armListKind fuel kind env source normal arms) (armsSize arms) :=
  normalWalk_of_walk ((analysis_walk_kind fuel).2.2.2 kind env source normal arms)
instance normalWalk_skipExpr (fuel source) : NormalWalk (skipExpr fuel source) (surfaceSize source) :=
  normalWalk_of_walk ((skip_walk fuel).1 source)
instance normalWalk_skipBlock (fuel body) : NormalWalk (skipBlock fuel body) (blockSize body) := by
  simpa only [preorderBlock_length] using normalWalk_of_walk ((skip_walk fuel).2.2.2.2.1 body)
instance normalWalk_skipArms (fuel arms) : NormalWalk (skipArms fuel arms) (armsSize arms) :=
  normalWalk_of_walk ((skip_walk fuel).2.2.2.2.2.1 arms)
instance normalWalk_own (key op type left right) : NormalWalk (own key op type left right) 0 :=
  normalWalk_of_walk (walk_own key op type left right)
instance normalWalk_negOwn (key child) : NormalWalk (negOwn key child) 0 :=
  normalWalk_of_walk (walk_negOwn key child)
instance normalWalk_negOwnTyped (key type child) : NormalWalk (negOwnTyped key type child) 0 :=
  normalWalk_of_walk (walk_negOwnTyped key type child)
instance normalWalk_unsupported : NormalWalk unsupported 0 := normalWalk_of_walk walk_unsupported
instance normalWalk_branchExpr (fuel env source tested truth child) :
    NormalWalk (branch env source tested truth
      (fun inner => expr fuel inner child) (fun _ => skipExpr fuel child)) (surfaceSize child) :=
  normalWalk_of_walk (walk_branch _ _ _ _ _ _ (surfacePreorder child)
    (fun inner => (analysis_walk fuel).1 inner child) ((skip_walk fuel).1 child))

instance normalWalk_branchBlock (fuel env source tested truth body) :
    NormalWalk (branch env source tested truth
      (fun inner => block fuel inner body) (fun _ => skipBlock fuel body)) (blockSize body) := by
  simpa only [preorderBlock_length] using normalWalk_of_walk
    (walk_branch _ _ _ _ _ _ (preorderBlock body)
      (fun inner => (analysis_walk fuel).2.2.1 inner body) ((skip_walk fuel).2.2.2.2.1 body))

instance normalWalk_branchPure (env source tested truth value) :
    NormalWalk (branch env source tested truth
      (fun _ => pure value) (fun _ => pure ())) 0 :=
  normalWalk_of_walk (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure value) (walk_pure ()))

instance normalWalk_skipOptional (fuel value) : NormalWalk (skipOptional fuel value) (guardSize value) := by
  cases value with
  | none => exact normalWalk_of_walk ((skip_walk fuel).2.2.2.2.2.2.2 none)
  | some source => exact normalWalk_of_walk ((skip_walk fuel).2.2.2.2.2.2.2 (some source))

instance (priority := 1100) normalWalk_kindArmFirst (fuel kind env source normal alts guard body) :
    NormalWalk (scope fun _ => do
      let inner ← scan (BudgetScan.armKind env source kind normal alts)
      match inner with
      | none => do skipOptional fuel guard; skipBlock fuel body; pure baseEmpty
      | some inner =>
        match guard with
        | none => block fuel inner body
        | some condition => do
          let tested ← expr fuel inner condition
          let positive ← branch inner condition tested true
            (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
          pure (baseMerge tested positive baseEmpty))
      (guardSize guard + blockSize body) := by
  have he := (analysis_walk fuel).1
  have hb := (analysis_walk fuel).2.2.1
  have sb := (skip_walk fuel).2.2.2.2.1
  have so := (skip_walk fuel).2.2.2.2.2.2.2
  have walked : Walk (scope fun _ => do
      let inner ← scan (BudgetScan.armKind env source kind normal alts)
      match inner with
      | none => do skipOptional fuel guard; skipBlock fuel body; pure baseEmpty
      | some inner =>
        match guard with
        | none => block fuel inner body
        | some condition => do
          let tested ← expr fuel inner condition
          let positive ← branch inner condition tested true
            (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
          pure (baseMerge tested positive baseEmpty))
      ((match guard with | none => [] | some g => surfacePreorder g) ++ preorderBlock body) := by
    apply walk_scope
    simpa only [List.nil_append] using walk_bind (walk_scan _) (fun inner => by
      cases inner with
      | none => exact walk_bind (so guard) (fun _ => walk_map (sb body) _)
      | some inner =>
        cases guard with
        | none => exact hb inner body
        | some condition =>
          apply walk_bind (he inner condition)
          intro tested
          exact walk_map (walk_branch _ _ _ _ _ _ _
            (fun refined => hb refined body) (sb body)) _)
  cases guard with
  | none => simpa only [guardSize, Option.map_none, Option.getD_none, Nat.zero_add,
      List.nil_append, preorderBlock_length] using normalWalk_of_walk walked
  | some condition => simpa only [guardSize, Option.map_some, Option.getD_some,
      List.length_append, surfaceSize, preorderBlock_length] using normalWalk_of_walk walked

instance normalWalk_arguments (fuel env sources) :
    NormalWalk (arguments fuel env sources) (preorderExprs sources).length :=
  normalWalk_of_walk ((analysis_walk_all fuel).2.2.2.2.1 env sources)
instance normalWalk_resultArms (fuel env input arms) :
    NormalWalk (resultArmList fuel env input arms) (armsSize arms) :=
  normalWalk_of_walk ((analysis_walk_all fuel).2.2.2.2.2 env input arms)

instance (priority := 1100) normalWalk_resultArmFirst (fuel env input alts guard body) :
    NormalWalk (scope fun _ => do
      let inner ← scan (BudgetScan.rangeArm env input alts)
      match guard with
      | none => block fuel inner body
      | some condition => do
        let tested ← expr fuel inner condition
        let positive ← branch inner condition tested true
          (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
        pure (baseMerge tested positive baseEmpty))
      (guardSize guard + blockSize body) := by
  have he := (analysis_walk fuel).1
  have hb := (analysis_walk fuel).2.2.1
  have sb := (skip_walk fuel).2.2.2.2.1
  have walked : Walk (scope fun _ => do
      let inner ← scan (BudgetScan.rangeArm env input alts)
      match guard with
      | none => block fuel inner body
      | some condition => do
        let tested ← expr fuel inner condition
        let positive ← branch inner condition tested true
          (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
        pure (baseMerge tested positive baseEmpty))
      ((match guard with | none => [] | some g => surfacePreorder g) ++ preorderBlock body) := by
    apply walk_scope
    simpa only [List.nil_append] using walk_bind (walk_scan _) (fun inner => by
      cases guard with
      | none => exact hb inner body
      | some condition =>
        apply walk_bind (he inner condition)
        intro tested
        exact walk_map (walk_branch _ _ _ _ _ _ _
          (fun refined => hb refined body) (sb body)) _)
  cases guard with
  | none => simpa only [guardSize, Option.map_none, Option.getD_none, Nat.zero_add,
      List.nil_append, preorderBlock_length] using normalWalk_of_walk walked
  | some condition => simpa only [guardSize, Option.map_some, Option.getD_some,
      List.length_append, surfaceSize, preorderBlock_length] using normalWalk_of_walk walked

instance (priority := 1200) normalWalk_resultArmFirst_none (fuel env input alts body) :
    NormalWalk (scope fun _ => do
      let inner ← scan (BudgetScan.rangeArm env input alts)
      block fuel inner body) (blockSize body) := by
  simpa only [guardSize, Option.map_none, Option.getD_none, Nat.zero_add] using
    normalWalk_resultArmFirst fuel env input alts none body

instance (priority := 1200) normalWalk_resultArmFirst_some (fuel env input alts condition body) :
    NormalWalk (scope fun _ => do
      let inner ← scan (BudgetScan.rangeArm env input alts)
      let tested ← expr fuel inner condition
      let positive ← branch inner condition tested true
        (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
      pure (baseMerge tested positive baseEmpty)) (surfaceSize condition + blockSize body) := by
  simpa only [guardSize, Option.map_some, Option.getD_some] using
    normalWalk_resultArmFirst fuel env input alts (some condition) body

theorem successAt_bind {key : OperationKey} {first : Analysis α} {next : α → Analysis β}
    {post : α → Prop} {result : β → Prop} {size : Nat} [walk : NormalWalk first size]
    (hf : SuccessAt key first post)
    (hn : ∀ value, post value → SuccessAt (advanceKey key size) (next value) result) :
    SuccessAt key (first >>= next) result := by
  intro limits ctx start value ok
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at ok
  cases run : first limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason => simp [run, ExceptT.bindCont, pure, StateT.pure] at ok
    | ok a =>
      exact hn a (hf limits ctx start a (by simp [run])) limits middle
        (by simpa only [start] using walk.next limits ctx a middle run) value
        (by simpa only [run, ExceptT.bindCont] using ok)

theorem successAt_before (first : Analysis α) {key : OperationKey}
    {next : α → Analysis β} {post : β → Prop} {size : Nat} [NormalWalk first size]
    (h : ∀ value, SuccessAt (advanceKey key size) (next value) post) :
    SuccessAt key (first >>= next) post :=
  successAt_bind ((success_any first).at key) (fun value _ => h value)

theorem successAt_scope {key : OperationKey} {work : Unit → Analysis α} {post : α → Prop}
    (h : SuccessAt key (work ()) post) : SuccessAt key (scope work) post := by
  intro limits ctx start value ok
  unfold scope at ok
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    cases outcome with
    | error reason => simp [run] at ok
    | ok u =>
      have next : entered.next = key := by
        have same := (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
        simpa only [run] using same.trans start
      cases inner : work () limits entered with
      | mk result final =>
        exact h limits entered next value (by simpa only [run, inner] using ok)

theorem successAt_identify {key : OperationKey} (source : Expr)
    {next : OperationKey → Analysis α} {post : α → Prop}
    (h : SuccessAt (childKey key []) (next key) post) :
    SuccessAt key (identify source >>= next) post := by
  intro limits ctx start value ok
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at ok
  cases run : identify source limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason => simp [run, ExceptT.bindCont, pure, StateT.pure] at ok
    | ok found =>
      obtain ⟨same, nextKey, _⟩ := identify_success source limits ctx run
      have found_eq : found = key := same.trans start
      subst found
      exact h limits middle (by simpa only [start, childKey, List.map_nil, List.sum_nil,
        Nat.add_zero] using nextKey) value
        (by simpa only [run, ExceptT.bindCont, start] using ok)

theorem successAt_get {key : OperationKey} {next : Context → Analysis α} {post : α → Prop}
    (h : ∀ ctx, ctx.next = key → SuccessAt key (next ctx) post) :
    SuccessAt key (get >>= next) post := by
  intro limits ctx start value ok
  exact h ctx start limits ctx start value ok

theorem successAt_branch_selected {key env source tested truth run skip inner post}
    (entry : branchEnv env source tested.boolean truth = some inner)
    (h : SuccessAt key (run inner) post) :
    SuccessAt key (branch env source tested truth run skip) post := by
  unfold branch
  apply successAt_scope
  refine successAt_bind ((success_scan_agrees _ _
    (BudgetScan.branch_agrees env source tested.boolean truth)).at key) ?_
  intro refined eq
  rw [eq, entry]
  exact h.rekey

theorem indexed_success_pure {key : OperationKey} (value : α) {post : α → Prop}
    (h : post value) : SuccessAt key (pure value) post := (success_pure value h).at key

theorem indexed_success_any_covered {key : OperationKey} (work : Analysis BaseApprox)
    {outcome : EvalOutcome} (abrupt : ∀ value, outcome ≠ .normal value) :
    SuccessAt key work (fun approx => NormalCovered approx outcome) :=
  (success_any_covered work abrupt).at key

theorem indexed_success_scan_agrees {key : OperationKey}
    (work : BudgetScan.Scan α) (expected : α) (agrees : BudgetScan.Agrees work expected) :
    SuccessAt key (scan work) (· = expected) := (success_scan_agrees work expected agrees).at key

theorem indexed_success_unsupported {key : OperationKey} :
    SuccessAt key unsupported (· = baseUnknown) := success_unsupported.at key

theorem indexed_success_own {start : OperationKey} (key op type left right) :
    SuccessAt start (own key op type left right)
      (fun value => ∀ concrete, value.Contains concrete ↔
        (baseOwn key op type left right).Contains concrete) :=
  (success_own key op type left right).at start

theorem indexed_success_negOwn {start : OperationKey} (key child) :
    SuccessAt start (negOwn key child)
      (fun value => ∀ concrete, value.Contains concrete ↔ (baseNegOwn key child).Contains concrete) :=
  (success_negOwn key child).at start

theorem indexed_success_negOwnTyped {start : OperationKey} (key type child) :
    SuccessAt start (negOwnTyped key type child)
      (fun value => ∀ concrete, value.Contains concrete ↔
        (baseNegOwnTyped key type child).Contains concrete) :=
  (success_negOwnTyped key type child).at start

/-- 選択した位置に正常値があれば、その区間への所属を保持する。 -/
def SelectedModels (target : Nat) (positions : List Nat) (values : List ConcreteValue)
    (approx : BaseApprox) : Prop :=
  approx.live = true ∧ ∀ value, fieldAt target positions values = some value → approx.Contains value

private theorem then_valueModels {left right value} (live : left.live = true)
    (model : right.Contains value) : (baseThen left right).Contains value := by
  exact then_contains live model

private theorem then_live {left right} (hl : left.live = true) (hr : right.live = true) :
    (baseThen left right).live = true := by
  unfold baseThen
  rw [if_pos hl]
  exact hr

theorem selectArguments_normal {run skip target positions env key sources types values trace}
    (he : ∀ source, Walk (run source) (surfacePreorder source))
    (hs : ∀ sources, Walk (skip sources) (preorderExprs sources))
    (children : ∀ input value trace, EvalPartial env input (.normal value) trace →
      SuccessAt input.key (run input.source) (fun approx => approx.Contains value))
    (eval : EvalTypedArguments env key (exprsChildren sources) types (.normal values) trace) :
    SuccessAt key (selectArguments run skip target positions sources) (SelectedModels target positions values) := by
  haveI (source : Expr) : NormalWalk (run source) (surfaceSize source) := normalWalk_of_walk (he source)
  haveI (sources : Exprs) (positions : List Nat) :
      NormalWalk (selectArguments run skip target positions sources) (preorderExprs sources).length :=
    normalWalk_of_walk (walk_selectArguments run skip target positions sources he hs)
  rw [selectArguments.eq_def]
  apply successAt_scope
  refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
  simp only [advanceKey_zero]
  cases sources with
  | nil =>
    cases eval
    exact indexed_success_pure _ ⟨rfl, by simp [fieldAt, exprsChildren]⟩
  | cons source rest =>
    cases eval with
    | cons _ _ _ _ _ _ _ _ _ _ head tail =>
      refine successAt_bind (children _ _ _ head) ?_
      intro first modeled
      simp only [contains_live modeled, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (selectArguments_normal he hs children tail).rekey ?_
      intro last modeledTail
      apply indexed_success_pure
      have firstLive := contains_live modeled
      have tailLive := modeledTail.1
      cases positions with
      | nil =>
        simp only [List.head?_nil, reduceCtorEq, ↓reduceIte]
        exact ⟨then_live firstLive (then_live tailLive tailLive), by simp [fieldAt]⟩
      | cons position positions =>
        by_cases selected : target = position
        · simp only [List.head?_cons, ← selected, ↓reduceIte]
          refine ⟨then_live firstLive (then_live tailLive firstLive), ?_⟩
          intro value atValue
          simp only [fieldAt, selected, ↓reduceIte, Option.some.injEq] at atValue
          subst value
          exact then_valueModels firstLive (then_valueModels tailLive modeled)
        · simp only [List.head?_cons, Option.some.injEq, Ne.symm selected, ↓reduceIte]
          refine ⟨then_live firstLive (then_live tailLive tailLive), ?_⟩
          intro value atValue
          apply then_valueModels firstLive
          apply then_valueModels tailLive
          apply modeledTail.2 value
          simpa only [fieldAt, selected, ↓reduceIte, List.tail_cons] using atValue
termination_by sources

/-- 二つの成功時の性質は同じ実行結果へ要求できる。 -/
theorem SuccessAt.and {key work} {p q : BaseApprox → Prop}
    (left : SuccessAt key work p) (right : SuccessAt key work q) :
    SuccessAt key work (fun approx => p approx ∧ q approx) :=
  fun limits ctx start approx ok => ⟨left limits ctx start approx ok, right limits ctx start approx ok⟩

/-- 選択した値と、標準評価の同じ契約位置の値との対応。 -/
def StandardSelected (binding : StandardBinding) (arguments : List ConcreteValue)
    (selected : BaseApprox) : Prop :=
  ∀ value, arguments[bindingArgument binding]? = some value → selected.Contains value

/-- 定義域の警告は、正常な全引数が揃った同じ標準事象の拒否を示す。 -/
theorem selectedFixedOutside_reject {binding key arguments result selected}
    (models : StandardSelected binding arguments selected)
    (evaluated : EvalStandard binding.rule key arguments result)
    (outside : baseFixedOutside binding [bindingArgument binding] [selected] = true) :
    result = .rejected .outsideDomain := by
  cases binding with
  | mk declaration rule types =>
    cases evaluated with
    | rangeCheck | rangeValue | rangeValueUnknown | rangeValueUnknownFailed =>
      simp [baseFixedOutside] at outside
    | domainNormal position lo hi result key args integer output atInteger inside typed
    | domainOtherFailure position lo hi result key args integer atInteger inside =>
      have model := models _ atInteger
      have bad : baseDomainDisjoint lo hi selected.integer = true := by
        simpa only [baseFixedOutside, bindingArgument, fieldAt, ↓reduceIte, bind, Option.bind] using outside
      exact False.elim ((baseDomainDisjoint_outside bad model) inside)
    | domainRejected => rfl
theorem selectedFixedOwn_normal {binding key arguments result selected}
    (models : StandardSelected binding arguments selected)
    (evaluated : EvalStandard binding.rule key arguments result) :
    NormalCovered (selectedFixedOwn binding key selected) (binding.rule.finish result) := by
  intro value normal
  unfold selectedFixedOwn baseFixedOwn
  split
  · rename_i outside
    have rejected := selectedFixedOutside_reject models evaluated outside
    rw [rejected] at normal
    have failed : binding.rule.finish (.rejected .outsideDomain) = .failed .outsideDomain := by
      cases binding.rule <;> rfl
    rw [failed] at normal
    contradiction
  · exact unknown_contains value

private theorem selected_ordered_models {binding positions values arguments selected}
    (models : SelectedModels (bindingArgument binding) positions values selected)
    (ordered : orderArguments positions values = some arguments) :
    StandardSelected binding arguments selected := by
  intro value found
  have bound : bindingArgument binding < positions.length := by
    rw [← order_arguments_length ordered]
    exact (List.getElem?_eq_some_iff.mp found).1
  exact models.2 value ((order_arguments_field ordered bound).trans found)

/-- Integer64 だけを含む近似からは、その具体的な整数を取り出せる。 -/
theorem selected_integer {approx : BaseApprox} {value : ConcreteValue} (modeled : approx.Contains value)
    (only : approx.onlyInteger = true) :
    ∃ integer, value = .integer integer ∧ Mem integer.toInt approx.integer := by
  cases value <;> simp_all [BaseApprox.Contains, BaseApprox.onlyInteger]
  case boolean value => cases value <;> simp_all

private theorem selected_field_exists {positions : List Nat} {values : List ConcreteValue} {target}
    (length : values.length = positions.length) (member : target ∈ positions) :
    ∃ value, fieldAt target positions values = some value := by
  induction positions generalizing values with
  | nil => simp at member
  | cons position rest ih =>
    cases values with
    | nil => simp at length
    | cons value values =>
      by_cases same : target = position
      · exact ⟨value, by simp [fieldAt, same]⟩
      · simp only [List.mem_cons, same, false_or] at member
        simpa only [fieldAt, same, ↓reduceIte] using ih (by simpa using length) member

/-- 単体の成功時の補助条件を、同じ結果に射影する。 -/
theorem SuccessAt.mono {key work} {p q : BaseApprox → Prop}
    (valid : SuccessAt key work p) (imp : ∀ approx, p approx → q approx) : SuccessAt key work q :=
  fun limits ctx start approx ok => imp approx (valid limits ctx start approx ok)

instance normalWalk_select (fuel env target positions sources) :
    NormalWalk (selectArguments (expr fuel env) (skipExprs fuel) target positions sources)
      (preorderExprs sources).length :=
  normalWalk_of_walk (walk_selectArguments _ _ _ _ _ ((analysis_walk fuel).1 env)
    ((skip_walk fuel).2.2.1))

private theorem success_fixedOwn_normal (binding key selected) :
    Success (fixedOwn binding key selected)
      (fun approx => ∀ value, approx.Contains value ↔ (selectedFixedOwn binding key selected).Contains value) := by
  unfold fixedOwn
  exact success_before _ (fun _ => success_pure _ (contains_warnings _ _))

instance normalWalk_fixedOwn (binding key selected) : NormalWalk (fixedOwn binding key selected) 0 :=
  normalWalk_of_walk (walk_fixedOwn binding key selected)

set_option maxRecDepth 2048 in
set_option maxHeartbeats 800000 in
mutual
/-- 同じ開始キーと Range の局所対応から、成功した式の正常値を保存する。 -/
theorem expr_normal (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace) :
    SuccessAt input.key (expr fuel abstract input.source) (fun approx => NormalCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [expr]
    apply successAt_scope
    apply successAt_identify
    refine successAt_before (scan (BudgetScan.tick .expression)) (fun _ => ?_)
    simp only [advanceKey_zero]
    match eval with
    | .standardCall env root callee labels positions sources binding values orderedValues result trace recognized children ordered evaluated =>
      have whole := EvalPartial.standardCall env root callee labels positions sources binding values
        orderedValues result trace recognized children ordered evaluated
      have atCall : rangeCallAt abstract root (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources,
          binding.rule.resultType, root⟩) models).trans recognized
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _)) ?_
      intro found same
      rw [same, atCall]
      refine successAt_before (skipExpr fuel callee) (fun _ => ?_)
      split
      · refine successAt_bind (selectArguments_normal ((analysis_walk fuel).1 abstract)
          ((skip_walk fuel).2.2.1)
          (fun input value trace child => expr_value_normal fuel models ranges child) children).rekey ?_
        intro selected modeled
        refine successAt_bind ((success_fixedOwn_normal binding root selected).at _) ?_
        intro own same
        exact indexed_success_pure _ (fun value normal => then_contains modeled.1
          ((same value).mpr (selectedFixedOwn_normal (selected_ordered_models modeled ordered) evaluated value normal)))
      · refine successAt_bind (typed_arguments_normal fuel models ranges children).rekey ?_
        intro args argsNormal
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeValue_agrees _ _)) ?_
        intro output same
        subst output
        exact indexed_success_pure _ (fun value normal =>
          then_contains (contains_live argsNormal) ((baseRangeCall_normal models ranges whole) value normal))
    | .fixedCallFailed .. => exact indexed_success_any_covered _ (by intro value h; cases h)
    | .fixedCallAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt
    | .standardCallAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)
    | .unknownNormal unknownEnv unknownInput normalValue unsupported typed =>
      cases unknownInput with
      | mk source type evalKey =>
        cases source <;> try exact (success_unknown_after _ _).at _
        all_goals simp [UnknownAt, Unsupported, Unmodeled, classify] at unsupported
        all_goals try contradiction
        all_goals try
          apply Success.at
          apply success_widthLiteral_unknown
          simp only [IntKind.min, IntKind.max] at *
          omega
        case literal literal =>
          cases literal <;> try simp at unsupported
          all_goals
            first
            | contradiction
            | exact (success_unknown_after _ _).at _
            | apply Success.at
              apply success_widthLiteral_unknown
              simp only [IntKind.min, IntKind.max] at *
              omega
        case call callee labels positions sources =>
          have atCall : rangeCallAt abstract evalKey (.call callee labels positions sources) = none :=
            (range_call_at_agrees (input := ⟨.call callee labels positions sources, type, evalKey⟩)
              models).trans unsupported
          refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _)) ?_
          intro found same
          rw [same, atCall]
          exact (success_unknown_after _ _).at _
        case neg operand child =>
          have noSupport : negModeled operand = false := by
            cases operand <;> try rfl
            rename_i base
            cases base <;> simp_all [negModeled, IntKind.ofType, IntKind.min, min64]
          simp only [noSupport, Bool.false_eq_true, ↓reduceIte]
          exact (success_unknown_after _ _).at _
        case binary op operand left right =>
          have absent : binarySupported op operand = false := by
            cases operand <;> try rfl
            rename_i base
            cases base <;> simp_all [binarySupported, IntKind.ofType]
          dsimp only
          rw [absent]
          simp only [Bool.false_eq_true, ↓reduceIte]
          exact (success_unknown_after _ _).at _
    | .unknownFailed .. => exact indexed_success_any_covered _ (by intro value h; cases h)
    | .integer .. | .negInt .. =>
      apply indexed_success_pure
      intro value h; cases h
      apply (mem_normalize _ _ _).mpr
      exact ⟨(Integer64Value.toInt_bounds _).1, (Integer64Value.toInt_bounds _).2,
        Int.le_refl _, Int.le_refl _⟩
    | .integer8 _ _ value bounded =>
      exact (success_widthLiteral_normal .integer8 _ bounded).at _
    | .integer16 _ _ value bounded =>
      exact (success_widthLiteral_normal .integer16 _ bounded).at _
    | .integer32 _ _ value bounded =>
      exact (success_widthLiteral_normal .integer32 _ bounded).at _
    | .unsignedInteger16 _ _ value bounded =>
      exact (success_widthLiteral_normal .unsignedInteger16 _ bounded).at _
    | .unsignedInteger32 _ _ value bounded =>
      exact (success_widthLiteral_normal .unsignedInteger32 _ bounded).at _
    | .unsignedInteger64 _ _ value bounded =>
      exact (success_widthLiteral_normal .unsignedInteger64 _ bounded).at _
    | .negInteger8 _ _ value bounded =>
      exact (success_widthLiteral_normal .integer8 _ bounded).at _
    | .negInteger16 _ _ value bounded =>
      exact (success_widthLiteral_normal .integer16 _ bounded).at _
    | .negInteger32 _ _ value bounded =>
      exact (success_widthLiteral_normal .integer32 _ bounded).at _
    | .boolean _ _ truth =>
      apply indexed_success_pure
      intro value h; cases h; cases truth <;> rfl
    | .unit .. => exact indexed_success_pure _ (by intro value h; cases h; exact ⟨rfl, rfl⟩)
    | .local _ _ index v atIndex =>
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.read_agrees _ _)) ?_
      intro slot eq
      subst slot
      have known := baseLocal_contains models atIndex
      unfold baseLocal at known
      cases entry : lookup abstract index with
      | none =>
        exact indexed_success_pure _ (fun value h => by cases h; exact unknown_contains _)
      | some slot =>
        cases slot <;> first
          | exact indexed_success_pure _ (fun value h => by cases h; simpa only [entry] using known)
          | exact indexed_success_pure _ (fun value h => by cases h; exact unknown_contains _)
    | .paren _ _ _ _ _ _ child => exact (expr_normal fuel models ranges child).rekey
    | .constE _ _ _ _ _ _ child =>
      exact expr_normal fuel (abstract := clearLocals abstract)
        (concrete := { concrete with locals := [] }) (models_clearLocals models) (ranges_clearLocals _ _) child |>.rekey
    | .returnE _ _ _ _ _ result _ _ =>
      exact indexed_success_any_covered _ (by intro value h; cases result <;> cases h)
    | .neg _ key _ _ _ child =>
      simp only [negModeled_integer, negOwnTyped_integer, ↓reduceIte]
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      refine successAt_bind (indexed_success_negOwn key tested) ?_
      intro approx same
      exact indexed_success_pure _ (fun value normal => by
        have known := checkedNeg_contains (key := key) inside normal
        have ownInside : (baseNegOwn key tested).Contains value := by
          cases value <;> simpa only [baseNeg, ↓reduceIte, baseThen, contains_live inside, BaseApprox.Contains] using known
        exact then_contains (contains_live inside) ((same value).mpr ownInside))
    | .widthBinary _ _ kind op _ _ _ _ _ _ not64 el er =>
      simp only [binarySupported_kind, ↓reduceIte]
      exact (widthBinary_normal fuel models ranges el er
        (by simp [childKey, advanceKey, Nat.add_assoc])
        (fun _ _ hl hr _ h => checkedWidthBinaryOwn_contains not64 hl hr h)).rekey
    | .widthNeg _ key kind _ _ _ not64 signed child =>
      simp only [negModeled_kind kind signed, ↓reduceIte]
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      refine successAt_bind (indexed_success_negOwnTyped key kind.type tested) ?_
      intro approx same
      exact indexed_success_pure _ (fun value normal =>
        then_contains (contains_live inside) ((same value).mpr
          (checkedWidthNegOwn_contains not64 signed inside normal)))
    | .add _ _ _ _ _ _ _ _ el er =>
      exact (binary_normal fuel models ranges el er (by simp [childKey, advanceKey, Nat.add_assoc]) rfl (fun _ _ hl hr _ h => checkedAdd_contains hl hr h)).rekey
    | .sub _ _ _ _ _ _ _ _ el er =>
      exact (binary_normal fuel models ranges el er (by simp [childKey, advanceKey, Nat.add_assoc]) rfl (fun _ _ hl hr _ h => checkedSub_contains hl hr h)).rekey
    | .mul _ _ _ _ _ _ _ _ el er =>
      exact (binary_normal fuel models ranges el er (by simp [childKey, advanceKey, Nat.add_assoc]) rfl (fun _ _ hl hr _ h => checkedMul_contains hl hr h)).rekey
    | .divMod _ _ op _ _ _ _ _ _ target el er =>
      have supported : binarySupported op (.base .integer) = true := by
        simp [binarySupported, target]
      simp only [supported, ↓reduceIte]
      exact (binary_normal fuel models ranges el er (by simp [childKey, advanceKey, Nat.add_assoc]) supported
        (fun _ _ hl hr _ h => checkedDiv_contains target hl hr h)).rekey
    | .compare _ _ op _ _ a b _ _ el er =>
      have recognized : Comparison.ofBinOp op.binOp = some op := by cases op <;> rfl
      have supported : binarySupported op.binOp (.base .integer) = true := by
        simp [binarySupported, recognized]
      simp only [supported, ↓reduceIte]
      exact (binary_normal fuel models ranges el er (by simp [childKey, advanceKey, Nat.add_assoc]) supported (by
        intro left right hl hr value h
        cases h
        have notAdd : op.binOp ≠ .add := by cases op <;> decide
        have notSub : op.binOp ≠ .sub := by cases op <;> decide
        have notMul : op.binOp ≠ .mul := by cases op <;> decide
        have notDiv : ¬ IntegerDivisionOp op.binOp := by cases op <;> simp [IntegerDivisionOp, Comparison.binOp]
        simp [baseBinary, baseOwn, notAdd, notSub, notMul, notDiv, recognized, baseThen,
          contains_live hl, contains_live hr, BaseApprox.Contains, baseBoolean]
        cases decide (op.Holds a.toInt b.toInt) <;> trivial)).rekey
    | .not _ _ _ truth _ child =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro approx covered
      apply indexed_success_pure
      intro value h; cases h
      have inside := covered _ rfl
      cases truth <;> exact inside
    | .andShort _ _ _ _ _ condition =>
      exact (shortCircuit_short_normal fuel models ranges condition rfl).rekey
    | .orShort _ _ _ _ _ condition =>
      exact (shortCircuit_short_normal fuel models ranges condition rfl).rekey
    | .andRight _ _ _ _ _ _ _ condition child =>
      exact (shortCircuit_right_normal fuel models ranges condition child (by
        simp [childKey, advanceKey, Nat.add_assoc])).rekey
    | .orRight _ _ _ _ _ _ _ condition child =>
      exact (shortCircuit_right_normal fuel models ranges condition child (by
        simp [childKey, advanceKey, Nat.add_assoc])).rekey
    | .matchInteger _ key source arms _ integer _ _ _ child selected =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro recognized same
      have absent := range_match_at_integer_none (kind := .integer64)
        (arms := arms) models ranges child
      rw [same, absent]
      cases choice : tested.matchKind with
      | some kind =>
        have same : kind = .integer64 := (matchKind_contains (actual := .integer64) inside choice).symm
        subst kind
        refine successAt_bind (armList_normal fuel models ranges child inside selected).rekey ?_
        intro approx covered
        exact indexed_success_pure _ (fun value h => then_contains (contains_live inside) (covered value h))
      | none =>
        refine successAt_before _ (fun _ => ?_)
        refine successAt_bind indexed_success_unsupported ?_
        intro approx eq; subst approx
        exact indexed_success_pure _ (fun value _ => then_contains (contains_live inside) (unknown_contains value))
    | .matchWidth _ key kind source arms _ integer _ _ _ not64 child selected =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro recognized same
      have absent := range_match_at_integer_none (kind := kind)
        (arms := arms) models ranges child
      rw [same, absent]
      cases choice : tested.matchKind with
      | some chosen =>
        have same : chosen = kind := (matchKind_contains inside choice).symm
        subst chosen
        refine successAt_bind (armListKind_normal fuel not64 models ranges child
          (BaseApprox.contains_rangeKind kind integer inside) selected).rekey ?_
        intro approx covered
        exact indexed_success_pure _ (fun value h => then_contains (contains_live inside) (covered value h))
      | none =>
        refine successAt_before _ (fun _ => ?_)
        refine successAt_bind indexed_success_unsupported ?_
        intro approx eq; subst approx
        exact indexed_success_pure _ (fun value _ => then_contains (contains_live inside) (unknown_contains value))
    | .matchResult env root source arms type sourceType result names tag payload outcome st armTrace recognized view child selected =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro known same
      rw [same]
      cases found : rangeMatchAt abstract ⟨source, .base .unit, childKey root []⟩ arms with
      | none =>
        simp only [noninteger_matchKind_none inside (range_result_view_noninteger view)]
        refine successAt_before _ (fun _ => ?_)
        refine successAt_bind indexed_success_unsupported ?_
        intro approx eq; subst approx
        exact indexed_success_pure _ (fun value _ =>
          then_contains (contains_live inside) (unknown_contains value))
      | some origin =>
        have actual : rangeMatchAt abstract ⟨source, sourceType, childKey root []⟩ arms = some origin := by
          simpa only [range_match_at_type] using
            (range_match_at_type abstract ⟨source, sourceType, childKey root []⟩ (.base .unit) arms).symm.trans found
        have matched := range_match_at_evaluated models ranges actual child
        have namesSame : origin.names = names := Option.some.inj (matched.symm.trans recognized)
        subst names
        refine successAt_bind
          (resultArmList_normal fuel models ranges found child matched view selected).rekey ?_
        intro result covered
        exact indexed_success_pure _ (fun value normal =>
          then_contains (contains_live inside) (covered value normal))
    | .matchOtherNormal _ _ _ arms _ _ _ _ _ child noninteger _ absent =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro tested covered
      have inside := covered _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeMatch_agrees _ _ _)) ?_
      intro known same
      rw [same, range_match_at_none_of_unmodeled models ranges child absent]
      simp only [noninteger_matchKind_none inside noninteger]
      refine successAt_before _ (fun _ => ?_)
      refine successAt_bind indexed_success_unsupported ?_
      intro approx eq; subst approx
      exact indexed_success_pure _ (by intro value h; cases h; exact then_contains (contains_live inside) (unknown_contains _))
    | .block _ _ _ _ _ _ child => exact (block_normal fuel models ranges child).rekey
    | .iteTrue _ _ _ _ _ _ _ _ _ condition child
    | .elseIfTrue _ _ _ _ _ _ _ _ _ condition child
    | .ifOnlyTrue _ _ _ _ _ _ _ condition child =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_bind (successAt_branch_selected entry
        (block_normal fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
      intro positive covered
      refine successAt_before _ (fun negative => ?_)
      exact indexed_success_pure _ (fun value h => merge_contains (Or.inl (covered value h)))
    | .iteFalse _ _ _ _ _ _ _ _ _ condition child =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_before _ (fun positive => ?_)
      refine successAt_bind (successAt_branch_selected entry
        (block_normal fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
      intro negative covered
      exact indexed_success_pure _ (fun value h => merge_contains (Or.inr (covered value h)))
    | .elseIfFalse _ _ _ _ _ _ _ _ _ condition child =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_before _ (fun positive => ?_)
      refine successAt_bind (successAt_branch_selected entry
        (expr_normal fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
      intro negative covered
      exact indexed_success_pure _ (fun value h => merge_contains (Or.inr (covered value h)))
    | .ifOnlyFalse _ _ _ _ _ condition =>
      refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
      intro tested covered
      obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
      refine successAt_before _ (fun positive => ?_)
      refine successAt_bind (successAt_branch_selected entry (indexed_success_pure (post := fun approx => NormalCovered approx (.normal .unit)) _ (by intro value h; cases h; exact ⟨rfl, rfl⟩))) ?_
      intro negative covered
      exact indexed_success_pure _ (fun value h => merge_contains (Or.inr (covered value h)))
    | .matchOtherFailed .. => exact indexed_success_any_covered _ (by intro value h; cases h)
    | .matchAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .addLeftAbrupt _ _ _ _ _ _ _ abrupt | .subLeftAbrupt _ _ _ _ _ _ _ abrupt | .mulLeftAbrupt _ _ _ _ _ _ _ abrupt
    | .addRightAbrupt _ _ _ _ _ _ _ _ _ _ abrupt | .subRightAbrupt _ _ _ _ _ _ _ _ _ _ abrupt | .mulRightAbrupt _ _ _ _ _ _ _ _ _ _ abrupt
    | .divModLeftAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .divModRightAbrupt _ _ _ _ _ _ _ _ _ _ _ _ abrupt
    | .compareLeftAbrupt _ _ _ _ _ _ _ _ abrupt
    | .compareRightAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt
    | .andAbrupt _ _ _ _ _ _ _ abrupt
    | .orAbrupt _ _ _ _ _ _ _ abrupt
    | .widthBinaryLeftAbrupt _ _ _ _ _ _ _ _ _ _ abrupt
    | .widthBinaryRightAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt
    | .widthNegAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .negAbrupt _ _ _ _ _ _ abrupt
    | .notAbrupt _ _ _ _ _ _ abrupt
    | .iteAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .elseIfAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .ifOnlyAbrupt _ _ _ _ _ _ _ abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)

termination_by 2 * fuel + 0
decreasing_by all_goals omega

/-- 二項演算の成功値は、子の正常値と演算自身の正常値から得る。 -/
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
      (fun approx => NormalCovered approx outcome) := by
  refine successAt_bind (expr_normal fuel models ranges el).rekey ?_
  intro left covered
  have hl := covered _ rfl
  simp only [contains_live hl, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind (expr_normal fuel models ranges er).rekey ?_
  intro right covered
  have hr := covered _ rfl
  simp only [contains_live hr, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind (indexed_success_own key op (.base .integer) left right) ?_
  intro approx same
  exact indexed_success_pure _ (fun value normal =>
    then_contains (contains_live hl) (then_contains (contains_live hr)
      ((same value).mpr (own_contains (operation left right hl hr value normal)
        (contains_live hl) (contains_live hr) supported))))

termination_by 2 * fuel + 1
decreasing_by all_goals omega

/-- 同じ種類の二値を得た演算を、型を落とさず共有予算へ合成する。 -/
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
      (fun approx => NormalCovered approx outcome) := by
  refine successAt_bind (expr_normal fuel models ranges el).rekey ?_
  intro left covered
  have hl := covered _ rfl
  simp only [contains_live hl, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind (expr_normal fuel models ranges er).rekey ?_
  intro right covered
  have hr := covered _ rfl
  simp only [contains_live hr, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
  refine successAt_bind (indexed_success_own key op kind.type left right) ?_
  intro approx same
  exact indexed_success_pure _ (fun value normal =>
    then_contains (contains_live hl) (then_contains (contains_live hr)
      ((same value).mpr (operation left right hl hr value normal))))

termination_by 2 * fuel + 1
decreasing_by all_goals omega

/-- 短絡する真偽では、右辺の走査の成否にかかわらず成功値を失わない。 -/
theorem shortCircuit_short_normal (fuel : Nat) {abstract concrete left right truth key trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (shorted : truth = !continueTruth) :
    SuccessAt key (shortCircuit fuel abstract left right continueTruth)
      (fun approx => NormalCovered approx (.normal (.boolean truth))) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [shortCircuit]
    refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
    intro tested covered
    obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
    rw [shorted] at entry
    refine successAt_before _ (fun continued => ?_)
    refine successAt_bind (successAt_branch_selected entry (indexed_success_pure _ rfl)) ?_
    intro short same
    subst short
    apply indexed_success_pure
    intro value h; cases h
    apply merge_contains (Or.inr ?_)
    cases continueTruth <;> simp_all [baseBoolean, BaseApprox.Contains]

termination_by 2 * fuel + 0
decreasing_by all_goals omega

/-- 継続する真偽では、絞った環境の右辺の正常値を合流に入れる。 -/
theorem shortCircuit_right_normal (fuel : Nat) {abstract concrete left right truth key rightKey trace outcome rt}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) trace)
    (child : EvalPartial concrete ⟨right, .base .boolean, rightKey⟩ outcome rt)
    (rightStart : rightKey = advanceKey key (surfaceSize left)) :
    SuccessAt key (shortCircuit fuel abstract left right truth)
      (fun approx => NormalCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [shortCircuit]
    refine successAt_bind (expr_normal fuel models ranges condition).rekey ?_
    intro tested covered
    obtain ⟨inner, entry, related⟩ := branch_models models condition (covered _ rfl)
    refine successAt_bind (successAt_branch_selected entry
        (expr_normal fuel related (ranges_branchEnv ranges entry) child).rekey) ?_
    intro continued covered
    refine successAt_before _ (fun short => ?_)
    exact indexed_success_pure _ (fun value h => merge_contains (Or.inl (covered value h)))

termination_by 2 * fuel + 0
decreasing_by all_goals omega

/-- 束縛とパターンの成功値を、後続の環境へ渡す。 -/
theorem block_normal (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace) :
    SuccessAt key (block fuel abstract body) (fun approx => NormalCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [block.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .empty .. => exact indexed_success_pure _ (by intro value h; cases h; exact ⟨rfl, rfl⟩)
    | .builderBind _ _ kind _ _ _ _ child =>
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.push_agrees _ _)) ?_
      intro inner eq; subst inner
      exact (block_normal fuel (models_extend (slot := .builder kind) models (value := none) trivial)
        (ranges_extend (slot := .builder kind) ranges none) child).rekey
    | .last _ _ _ _ _ _ child => exact (expr_normal fuel models ranges child).rekey
    | .lastBind _ _ _ _ _ result _ child
    | .lastDiscard _ _ _ _ result _ child
    | .lastPat _ _ _ _ _ _ result _ child =>
      refine successAt_bind (expr_normal fuel models ranges child).rekey ?_
      intro approx covered
      apply indexed_success_pure
      intro value h
      cases result <;> try cases h
      exact then_contains (contains_live (covered _ rfl)) ⟨rfl, rfl⟩
    | .bind _ _ kind _ _ _ _ _ _ _ _ head tail =>
      apply successAt_get
      intro start atKey
      simp only [atKey]
      refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
      intro approx modeled
      have inside := modeled
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeBind_agrees _ _ _ _ _)) ?_
      intro inner eq; subst inner
      refine successAt_bind (block_normal fuel
        (show Models (baseBindSource kind _ _ _ _) _ from
          bind_models kind models (eval_normal_typed head) inside)
        (range_save_result_of_eval models ranges head) tail).rekey ?_
      intro result covered
      exact indexed_success_pure _ (fun value h => then_contains (contains_live inside) (covered value h))
    | .discard _ _ _ _ _ _ _ _ _ _ head tail
    | .seq _ _ _ _ _ _ _ _ _ head tail =>
      refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
      intro approx covered
      have inside := covered
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (block_normal fuel models ranges tail).rekey ?_
      intro result covered
      exact indexed_success_pure _ (fun value h => then_contains (contains_live inside) (covered value h))
    | .bindPat _ _ _ _ _ _ _ _ _ _ _ _ _ head bindings tail =>
      refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
      intro approx covered
      have inside := covered
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.patternEnv_agrees _ _ _)) ?_
      intro inner eq; subst inner
      refine successAt_bind (block_normal fuel (pattern_models models (eval_normal_typed head) bindings)
        (pattern_ranges ranges bindings) tail).rekey ?_
      intro result covered
      exact indexed_success_pure _ (fun value h => then_contains (contains_live inside) (covered value h))
    | .bindAbrupt _ _ _ _ _ _ _ _ _ _ abrupt
    | .discardAbrupt _ _ _ _ _ _ _ _ _ abrupt
    | .seqAbrupt _ _ _ _ _ _ _ _ abrupt
    | .bindPatAbrupt _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)

termination_by 2 * fuel + 0
decreasing_by all_goals omega

/-- 正常に選択された腕だけが合流への所属の証拠を与える。 -/
theorem armList_normal (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace) :
    SuccessAt key (armList fuel abstract source normal arms) (fun approx => NormalCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [armList, armListKind.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .nil .. => exact indexed_success_pure _ (by intro value h; cases h)
    | .skip _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      refine successAt_before _ (fun first => ?_)
      refine successAt_bind (armList_normal fuel models ranges scrutinee inside tail).rekey ?_
      intro rest covered
      exact indexed_success_pure _ (fun value h => join_contains (Or.inr (covered value h)))
    | .body _ _ _ _ _ _ _ _ _ _ selection body =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models ranges scrutinee inside selection entry
      refine successAt_bind (post := fun approx => NormalCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.arm_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        exact (block_normal fuel related innerRanges body).rekey
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun value h => join_contains (Or.inl (covered value h)))
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
      have innerRanges := match_selection_ranges models ranges scrutinee inside selection entry
      refine successAt_bind (post := fun approx => NormalCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.arm_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        refine successAt_bind (expr_normal fuel related innerRanges condition).rekey ?_
        intro tested covered
        obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition (covered _ rfl)
        refine successAt_bind (successAt_branch_selected atEnv
          (block_normal fuel modeled (ranges_branchEnv innerRanges atEnv) body).rekey) ?_
        intro positive covered
        exact indexed_success_pure _ (fun value h => merge_contains (Or.inl (covered value h)))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun value h => join_contains (Or.inl (covered value h)))
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)
termination_by 2 * fuel + 0
decreasing_by all_goals omega


/-- 六幅の選択された腕も、その種類の局所位置で正常値を覆う。 -/
theorem armListKind_normal (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace) :
    SuccessAt key (armListKind fuel kind abstract source normal arms) (fun approx => NormalCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [armListKind.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .nil .. => exact indexed_success_pure _ (by intro value h; cases h)
    | .skip _ _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      refine successAt_before _ (fun first => ?_)
      refine successAt_bind (armListKind_normal fuel not64 models ranges scrutinee inside tail).rekey ?_
      intro rest covered
      exact indexed_success_pure _ (fun value h => join_contains (Or.inr (covered value h)))
    | .body _ _ _ _ _ _ _ _ _ _ _ selection body =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models ranges scrutinee inside selection not64 entry
      refine successAt_bind (post := fun approx => NormalCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.armKind_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        exact (block_normal fuel related innerRanges body).rekey
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun value h => join_contains (Or.inl (covered value h)))
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
      have innerRanges := match_width_selection_ranges models ranges scrutinee inside selection not64 entry
      refine successAt_bind (post := fun approx => NormalCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.armKind_agrees _ _ _ _ _)) ?_
        intro refined eq; rw [eq, entry]
        refine successAt_bind (expr_normal fuel related innerRanges condition).rekey ?_
        intro tested covered
        obtain ⟨refined, atEnv, modeled⟩ := branch_models related condition (covered _ rfl)
        refine successAt_bind (successAt_branch_selected atEnv
          (block_normal fuel modeled (ranges_branchEnv innerRanges atEnv) body).rekey) ?_
        intro positive covered
        exact indexed_success_pure _ (fun value h => merge_contains (Or.inl (covered value h)))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun value h => join_contains (Or.inl (covered value h)))
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)
termination_by 2 * fuel + 0
decreasing_by all_goals omega

/-- 正常に完了した標準引数列は、代表値 Unit の正常性を保つ。 -/
theorem typed_arguments_normal (fuel : Nat)
    {abstract concrete key sources types values trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (eval : EvalTypedArguments concrete key (exprsChildren sources) types (.normal values) trace) :
    SuccessAt key (arguments fuel abstract sources) (fun approx => approx.Contains .unit) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [arguments.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    cases sources with
    | nil => exact indexed_success_pure _ ⟨rfl, rfl⟩
    | cons source rest =>
      cases eval with
      | cons _ _ _ _ _ _ _ _ _ _ head tail =>
        refine successAt_bind (expr_value_normal fuel models ranges head).rekey ?_
        intro tested covered
        have inside := covered
        simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
        refine successAt_bind (typed_arguments_normal fuel models ranges tail).rekey ?_
        intro rest covered
        exact indexed_success_pure _ (then_contains (contains_live inside) covered)
termination_by 2 * fuel + 0
decreasing_by all_goals omega

theorem arguments_normal (fuel : Nat)
    {abstract concrete key sources type values trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (eval : EvalArguments concrete key (exprsChildren sources) type (.normal values) trace) :
    SuccessAt key (arguments fuel abstract sources) (fun approx => approx.Contains .unit) :=
  typed_arguments_normal fuel models ranges (arguments_typed eval)
termination_by 2 * fuel + 1

/-- 認定した Result の腕では、同じ入力の成功由来だけを局所位置へ渡す。 -/
theorem resultArmList_normal (fuel : Nat)
    {abstract concrete input sourceType fullArms origin result tag payload key arms type outcome trace st}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (known : rangeMatchAt abstract input fullArms = some origin)
    (scrutinee : EvalPartial concrete { input with type := sourceType } (.normal result) st)
    (matched : rangeResultMatch concrete result fullArms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (eval : EvalResultArms concrete key origin.names result tag payload arms type outcome trace) :
    SuccessAt key (resultArmList fuel abstract input arms)
      (fun approx => NormalCovered approx outcome) := by
  cases fuel with
  | zero => exact (success_throw _ _).at _
  | succ fuel =>
    rw [resultArmList.eq_def]
    apply successAt_scope
    refine successAt_before (scan (BudgetScan.tick .classification)) (fun _ => ?_)
    match eval with
    | .nil .. => exact indexed_success_pure _ (by intro value h; cases h)
    | .skip _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail
    | .guardFalse _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ tail =>
      refine successAt_before _ (fun first => ?_)
      refine successAt_bind
        (resultArmList_normal fuel models ranges known scrutinee matched view tail).rekey ?_
      intro rest covered
      exact indexed_success_pure _ (fun value h => join_contains (Or.inr (covered value h)))
    | .body _ _ _ _ _ _ _ _ _ _ _ _ _ selection body =>
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have actualKnown : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
        simpa only [range_match_at_type] using known
      have innerRanges := baseResultArmEnv_ranges models ranges actualKnown scrutinee matched view selection
      rw [baseResultArmEnv_type] at innerRanges
      refine successAt_bind (post := fun approx => NormalCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeArm_agrees _ _ _)) ?_
        intro inner same; subst inner
        exact (block_normal fuel innerModels innerRanges body).rekey
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun value h => join_contains (Or.inl (covered value h)))
    | .guardTrue _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ selection condition body =>
      have innerModels := baseResultArmEnv_models (input := input) models selection
      have actualKnown : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
        simpa only [range_match_at_type] using known
      have innerRanges := baseResultArmEnv_ranges models ranges actualKnown scrutinee matched view selection
      rw [baseResultArmEnv_type] at innerRanges
      refine successAt_bind (post := fun approx => NormalCovered approx outcome) ?_ ?_
      · apply successAt_scope
        refine successAt_bind (indexed_success_scan_agrees _ _ (BudgetScan.rangeArm_agrees _ _ _)) ?_
        intro inner same; subst inner
        refine successAt_bind (expr_normal fuel innerModels innerRanges condition).rekey ?_
        intro tested covered
        obtain ⟨refined, entry, refinedModels⟩ := branch_models innerModels condition (covered _ rfl)
        refine successAt_bind (successAt_branch_selected entry
          (block_normal fuel refinedModels (ranges_branchEnv innerRanges entry) body).rekey) ?_
        intro positive covered
        exact indexed_success_pure _ (fun value h => merge_contains (Or.inl (covered value h)))
      · intro first covered
        refine successAt_before _ (fun rest => ?_)
        exact indexed_success_pure _ (fun value h => join_contains (Or.inl (covered value h)))
    | .guardAbrupt _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ _ abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)
termination_by 2 * fuel + 0
decreasing_by all_goals omega


/-- 正常評価のとき、同じ実行から正常値の所属を取り出す。 -/
theorem expr_value_normal (fuel : Nat) {abstract concrete input value trace}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input (.normal value) trace) :
    SuccessAt input.key (expr fuel abstract input.source) (fun approx => approx.Contains value) :=
  (expr_normal fuel models ranges eval).mono (fun approx valid => valid value rfl)
termination_by 2 * fuel + 1

end

/-- 短絡式の評価規則に対し、成功した補助解析の正常値を保存する。 -/
theorem shortCircuit_normal (fuel : Nat) {abstract concrete left right continueTruth key outcome trace}
    (models : Models abstract concrete)
    (ranges : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete
      ⟨if continueTruth then .and left right else .or left right, .base .boolean, key⟩ outcome trace) :
    SuccessAt (childKey key []) (shortCircuit fuel abstract left right continueTruth)
      (fun approx => NormalCovered approx outcome) := by
  cases continueTruth with
  | false =>
    simp only [Bool.false_eq_true, ↓reduceIte] at eval
    cases eval with
    | unknownNormal env input value unknown typed => simp [UnknownAt, Unsupported, Unmodeled, classify] at unknown
    | unknownFailed => exact indexed_success_any_covered _ (by intro value h; cases h)
    | orShort env key left right trace condition => exact (shortCircuit_short_normal fuel models ranges condition rfl).rekey
    | orRight env key left right trace outcome rt condition child => exact (shortCircuit_right_normal fuel models ranges condition child (by
        simp [childKey, advanceKey, Nat.add_assoc])).rekey
    | orAbrupt env key left right trace outcome condition abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)
  | true =>
    simp only [↓reduceIte] at eval
    cases eval with
    | unknownNormal env input value unknown typed => simp [UnknownAt, Unsupported, Unmodeled, classify] at unknown
    | unknownFailed => exact indexed_success_any_covered _ (by intro value h; cases h)
    | andShort env key left right trace condition => exact (shortCircuit_short_normal fuel models ranges condition rfl).rekey
    | andRight env key left right trace outcome rt condition child => exact (shortCircuit_right_normal fuel models ranges condition child (by
        simp [childKey, advanceKey, Nat.add_assoc])).rekey
    | andAbrupt env key left right trace outcome condition abrupt =>
      exact indexed_success_any_covered _ (by intro value h; rw [h] at abrupt; contradiction)

/-- 停止時の全値域と、成功時の値への所属を同じ出力へ接続する。 -/
theorem report_normal {result : Except Halt BaseApprox} (ctx : Context) {outcome : EvalOutcome}
    (success : ∀ approx, result = .ok approx → NormalCovered approx outcome) :
    NormalCovered (report result ctx).approx outcome := by
  cases result with
  | error reason =>
    intro value normal
    exact (contains_warnings baseUnknown ctx.warningsRev value).mpr (unknown_contains value)
  | ok approx =>
    intro value normal
    exact (contains_warnings approx ctx.warningsRev value).mpr (success approx rfl value normal)

/-- 初期消費・上限・深さ・完走状態を制限せず、入口の正常値を保存する。 -/
theorem analyzeExpr_normal (limits : Limits) (state : Budget.State) (fuel : Nat)
    {abstract concrete input outcome trace}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace) :
    NormalCovered (analyzeExpr limits state fuel abstract input.key input.source).approx outcome := by
  unfold analyzeExpr
  cases run : expr fuel (resetRanges abstract) input.source limits { budget := state, next := input.key } with
  | mk result ctx =>
    apply report_normal
    intro approx ok
    exact expr_normal fuel (models_resetRanges models) (ranges_reset_models _ _) eval limits
      { budget := state, next := input.key } rfl approx
      (by simpa only [run] using ok)

/-- 任意の予算を量化する既存の中心命題を、そのまま満たす。 -/
theorem analyze_normal_sound : NormalSoundness Models analyze := by
  intro abstract concrete input parameters value trace models eval
  exact ⟨eval_normal_typed eval,
    analyzeExpr_normal parameters.limits parameters.state parameters.fuel models eval value rfl⟩

end Benitoite.Interval.BudgetAnalysis
