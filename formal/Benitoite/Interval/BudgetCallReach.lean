import Benitoite.Interval.CallTables

/-!
# 未認定 call の内側から親へ警告を返さないことの合成

成功と停止で同じ追加分の契約を使う。既存の構文的な到達可能性の定理は変更しない。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis.CallExclusion
open Benitoite.Surface Benitoite.Release Budget CallReach

def Within (work : Analysis α) (scope : CallReach.Scope) (extra : IntervalWarning → Prop) : Prop :=
  ∀ limits ctx, Spec work limits ctx (fun _ => True)
    (fun warning => extra warning ∨ scope.allows ctx.next warning) (fun _ => True)

theorem silent_within {work : Analysis α} (h : Silent work) (scope : CallReach.Scope)
    (extra : IntervalWarning → Prop) {sources : List Expr} (walk : Walk work sources) : Within work scope extra := by
  intro limits ctx
  exact ⟨⟨⟨[], by simpa using h limits ctx, by simp⟩,
    (walk.identities limits ctx).mono (by intros; trivial)⟩, by intros; trivial⟩

theorem within_pure (value : α) (extra : IntervalWarning → Prop) : Within (pure value) empty extra :=
  silent_within (silent_pure value) empty extra (walk_pure value)
theorem within_get (extra : IntervalWarning → Prop) : Within (get : Analysis Context) empty extra :=
  silent_within silent_get empty extra walk_get
theorem within_throw (reason : Halt) (scope : CallReach.Scope) (extra : IntervalWarning → Prop) :
    Within (throw reason : Analysis α) scope extra := silent_within (silent_throw reason) scope extra (walk_throw reason [])
theorem within_scan (work : BudgetScan.Scan α) (extra : IntervalWarning → Prop) :
    Within (scan work) empty extra := silent_within (silent_scan work) empty extra (walk_scan work)

theorem within_bind {first : Analysis α} {next : α → Analysis β} {xs ys : CallReach.Scope}
    {extra : IntervalWarning → Prop} (walk : Walk first xs.sources)
    (hf : Within first xs extra) (hn : ∀ value, Within (next value) ys extra) :
    Within (first >>= next) (xs ++ ys) extra := by
  intro limits ctx
  apply spec_bind (post := fun _ => True)
  · exact spec_mono (hf limits ctx) (by intros; trivial)
      (fun _ h => h.imp_right Or.inl) (by intros; trivial)
  · intro value middle ok _
    have key : middle.next = advanceKey ctx.next xs.sources.length := (walk.success ok).1
    exact spec_mono (hn value limits middle) (by intros; trivial)
      (fun _ h => h.imp_right (fun h => Or.inr (key ▸ h))) (by intros; trivial)

theorem within_scope {work : Unit → Analysis α} {scope : CallReach.Scope} {extra}
    (h : Within (work ()) scope extra) : Within (BudgetAnalysis.scope work) scope extra := by
  intro limits ctx
  apply spec_scope
  intro entered ok
  have key : entered.next = ctx.next := by
    simpa only [ok] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
  simpa only [key] using h limits entered

theorem within_map {work : Analysis α} {scope : CallReach.Scope} {extra}
    (walk : Walk work scope.sources) (h : Within work scope extra) (f : α → β) :
    Within (work >>= fun value => pure (f value)) scope extra := by
  simpa only [append_empty] using within_bind walk h (fun value => within_pure (f value) extra)

theorem within_bind_empty {work : Analysis α} {next : α → Analysis β} {scope : CallReach.Scope} {extra}
    (walk : Walk work scope.sources) (h : Within work scope extra)
    (hn : ∀ value, Within (next value) empty extra) : Within (work >>= next) scope extra := by
  simpa only [append_empty] using within_bind walk h hn

theorem within_scan_bind {work : BudgetScan.Scan α} {next : α → Analysis β} {expected : α}
    {scope : CallReach.Scope} {extra} (agrees : BudgetScan.Agrees work expected)
    (hn : ∀ value, value = expected → Within (next value) scope extra) :
    Within (scan work >>= next) scope extra := by
  intro limits ctx
  apply spec_bind (spec_scan_agrees _ _ agrees limits ctx _ _)
  intro value middle ok eq
  have key : middle.next = ctx.next := by
    simpa only [ok] using (scan_preserves_saved work limits ctx).2.2.1
  simpa only [key] using hn value eq limits middle

theorem within_identified {source : Expr} {children : CallReach.Scope} {next : OperationKey → Analysis α} {extra}
    (hn : ∀ key, Within (next key) children (fun w => extra w ∨ RootWarning key source w)) :
    Within (identify source >>= next) (root source ++ children) extra := by
  intro limits ctx
  apply spec_bind (spec_identify source limits ctx _ _ trivial)
  intro key middle ok same
  have advanced : middle.next = advanceKey ctx.next 1 := (identify_success source limits ctx ok).2.1
  apply spec_mono (hn key limits middle) (by intros; trivial) _ (by intros; trivial)
  intro warning member
  rcases member with (old | own) | child
  · exact Or.inl old
  · exact Or.inr (Or.inl (same ▸ own))
  · exact Or.inr (Or.inr (advanced ▸ child))

theorem within_unsupported (extra : IntervalWarning → Prop) : Within unsupported empty extra :=
  silent_within (show Silent unsupported from by intro limits ctx; rfl) empty extra walk_unsupported

theorem within_widthLiteral (kind : IntKind) (value : Int) (extra : IntervalWarning → Prop) :
    Within (widthLiteral kind value) empty extra := by
  unfold widthLiteral
  split
  · exact within_pure _ _
  · exact within_unsupported _

theorem within_own (key op type left right lhs rhs) (extra : IntervalWarning → Prop) :
    Within (own key op type left right) empty
      (fun w => extra w ∨ RootWarning key (.binary op type lhs rhs) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (own_warning_origin key op type left right lhs rhs warning member))

theorem within_negOwnTyped (key type child source) (extra : IntervalWarning → Prop) :
    Within (negOwnTyped key type child) empty
      (fun w => extra w ∨ RootWarning key (.neg type source) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (negOwnTyped_warning_origin key type child source warning member))

theorem within_branch (env source tested truth run skip plan extra)
    (hr : ∀ inner, rangeTables inner = rangeTables env → Within (run inner) plan extra)
    (hs : Within (skip ()) plan extra) (ws : Walk (skip ()) plan.sources) :
    Within (branch env source tested truth run skip) plan extra := by
  apply within_scope
  apply within_scan_bind (BudgetScan.branch_agrees _ _ _ _)
  intro refined eq
  cases refined with
  | none => exact within_map ws hs (fun _ => baseEmpty)
  | some inner => exact hr inner (tables_branch env source tested.boolean truth inner eq.symm)

theorem within_unknown (fuel : Nat) (env : AbstractEnv) (source : Expr) (plan : CallReach.Scope) (extra) :
    Within (unknownChildren (BudgetAnalysis.expr fuel) (BudgetAnalysis.block fuel) fuel env source
      >>= fun _ => unsupported) plan extra := by
  apply silent_within
    (silent_bind (unknownChildren_silent _ _ _ _ _) (fun _ => by intro limits ctx; rfl)) plan extra
  exact walk_bind_empty (unknownChildren_walk _ _ ((BudgetAnalysis.analysis_walk fuel).1)
    ((BudgetAnalysis.analysis_walk fuel).2.2.1) fuel env source) (fun _ => walk_unsupported)

theorem analysis_walk (fuel : Nat) :
    (∀ env source {scopeEnv : AbstractEnv}, Walk (BudgetAnalysis.expr fuel env source) (CallReach.expr scopeEnv source).sources) ∧
    (∀ env left right truth {scopeEnv : AbstractEnv}, Walk (shortCircuit fuel env left right truth)
      (CallReach.expr scopeEnv left ++ CallReach.expr scopeEnv right).sources) ∧
    (∀ env body {scopeEnv : AbstractEnv}, Walk (BudgetAnalysis.block fuel env body) (CallReach.block scopeEnv body).sources) ∧
    (∀ kind env source normal arms {scopeEnv : AbstractEnv}, Walk (armListKind fuel kind env source normal arms)
      (CallReach.armList scopeEnv arms).sources) ∧
    (∀ env sources {scopeEnv : AbstractEnv}, Walk (arguments fuel env sources) (CallReach.exprs scopeEnv sources).sources) ∧
    (∀ env input arms {scopeEnv : AbstractEnv}, Walk (resultArmList fuel env input arms) (CallReach.armList scopeEnv arms).sources) := by
  obtain ⟨he, hs, hb, ha, hargs, hr⟩ := BudgetAnalysis.analysis_walk_all fuel
  exact ⟨fun env source {scopeEnv} => by simpa only [expr_sources] using he env source,
    fun env left right truth {scopeEnv} => by simpa only [append_sources, expr_sources] using hs env left right truth,
    fun env body {scopeEnv} => by simpa only [block_sources] using hb env body,
    fun kind env source normal arms {scopeEnv} => by simpa only [armList_sources] using ha kind env source normal arms,
    fun env sources {scopeEnv} => by simpa only [exprs_sources] using hargs env sources,
    fun env input arms {scopeEnv} => by simpa only [armList_sources] using hr env input arms⟩

private theorem listExtension_false_eq {before after : List α}
    (h : ListExtension (fun _ => False) before after) : after = before := by
  obtain ⟨added, shape, absent⟩ := h
  cases added with
  | nil => exact shape
  | cons head tail => exact (absent head (by simp)).elim

-- 未認定の call を根とする内部走査は、停止時も入力の候補列を保つ。
theorem expr_unrecognized_call_silent_at (fuel : Nat) (env : AbstractEnv)
    (callee : Expr) (labels : List (Option String)) (positions : List Nat) (arguments : Exprs)
    (limits : Limits) (ctx : Context)
    (unknown : rangeCallAt env ctx.next (.call callee labels positions arguments) = none) :
    (BudgetAnalysis.expr fuel env (.call callee labels positions arguments) limits ctx).2.warningsRev =
      ctx.warningsRev := by
  apply listExtension_false_eq
  suffices h : Spec (BudgetAnalysis.expr fuel env (.call callee labels positions arguments)) limits ctx
      (fun _ => True) (fun _ => False) (fun _ => True) from h.1.1
  cases fuel with
  | zero => exact spec_throw _ _ _ _ _ _
  | succ fuel =>
    rw [BudgetAnalysis.expr.eq_def]
    apply spec_scope
    intro entered ok
    have same : entered.next = ctx.next := by
      simpa only [ok] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
    apply spec_bind (spec_identify _ limits entered _ _ trivial)
    intro key middle identified keyEq
    apply spec_bind (spec_scan _ limits middle (fun _ => True) _ _ (by intros; trivial))
    intro _ classified classifiedOk _
    dsimp only
    apply spec_bind (spec_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _) limits classified _ _)
    intro recognized ready recognizedOk recognizedEq
    rw [recognizedEq, keyEq, same, unknown]
    apply spec_mono (within_unknown fuel env (.call callee labels positions arguments)
      empty (fun _ => False) limits ready) (by intros; trivial) ?_ (by intros; trivial)
    intro warning member
    exact member.elim id id

theorem within_selectArguments (fuel : Nat) (env : AbstractEnv) (target positions sources extra)
    (he : ∀ source, Within (BudgetAnalysis.expr fuel env source) (CallReach.expr env source) extra) :
    Within (selectArguments (BudgetAnalysis.expr fuel env) (skipExprs fuel) target positions sources)
      (CallReach.exprs env sources) extra := by
  rw [selectArguments.eq_def]
  apply within_scope
  apply within_scan_bind (BudgetScan.agrees_unit _)
  intro _ _
  cases sources with
  | nil =>
    change Within (pure baseUnit) (exprsTables (rangeTables env) .nil) extra
    rw [exprsTables]
    exact within_pure _ _
  | cons source rest =>
    dsimp only
    change Within _ (exprsTables (rangeTables env) (.cons source rest)) extra
    rw [exprsTables]
    apply within_bind ((analysis_walk fuel).1 env source) (he source)
    intro head
    split
    · exact within_map (by simpa only [exprsTables_sources] using (skip_walk fuel).2.2.1 rest)
        (silent_within ((skip_silent fuel).2.2.1 rest) _ _ ((skip_walk fuel).2.2.1 rest)) _
    · exact within_map (by
        simpa only [exprs_sources] using (walk_selectArguments _ _ _ _ _
          ((BudgetAnalysis.analysis_walk fuel).1 env) ((BudgetAnalysis.skip_walk fuel).2.2.1)))
        (within_selectArguments fuel env target positions.tail rest extra he) _
termination_by sources

/-- 根の認定が成功した同じキーでだけ、根と子の候補を親へ返す。 -/
theorem within_recognized {source : Expr} {roots children : CallReach.Scope}
    {scanRule : OperationKey → BudgetScan.Scan (Option α)} {rule : OperationKey → Option α}
    {next : OperationKey → Option α → Analysis BaseApprox} {extra}
    (rootSources : roots.sources = [source])
    (agrees : ∀ key, BudgetScan.Agrees (scanRule key) (rule key))
    (fallbackSilent : ∀ key, Silent (next key none))
    (fallbackWalk : ∀ key, Walk (next key none) (surfacePreorder source).tail)
    (valid : ∀ key value, rule key = some value →
      Within (next key (some value)) children (fun w => extra w ∨ roots.allows key w)) :
    Within (do
      let key ← identify source
      scan (BudgetScan.tick .expression)
      let recognized ← scan (scanRule key)
      next key recognized)
      (gate (fun key => rule key ≠ none) (roots ++ children)) extra := by
  intro limits ctx
  apply spec_bind (spec_identify _ limits ctx _ _ trivial)
  intro key middle identified keyEq
  have middleKey : middle.next = advanceKey ctx.next 1 := (identify_success _ limits ctx identified).2.1
  apply spec_bind (spec_scan _ limits middle (fun _ => True) _ _ (by intros; trivial))
  intro _ classified classifiedOk _
  have classifiedKey : classified.next = advanceKey ctx.next 1 := by
    simpa only [classifiedOk, middleKey] using (scan_preserves_saved (BudgetScan.tick .expression) limits middle).2.2.1
  apply spec_bind (spec_scan_agrees _ _ (agrees key) limits classified _ _)
  intro recognized ready recognizedOk recognizedEq
  have readyKey : ready.next = advanceKey ctx.next 1 := by
    simpa only [recognizedOk, classifiedKey] using (scan_preserves_saved (scanRule key) limits classified).2.2.1
  rw [recognizedEq]
  cases known : rule key with
  | none =>
    exact spec_mono (silent_within (fallbackSilent key) empty (fun _ => False) (fallbackWalk key) limits ready)
      (by intros; trivial) (fun _ h => False.elim (h.elim id id)) (by intros; trivial)
  | some value =>
    apply spec_mono (valid key value known limits ready) (by intros; trivial) _ (by intros; trivial)
    intro warning member
    rcases member with (old | own) | child
    · exact Or.inl old
    · right
      refine ⟨?_, Or.inl ?_⟩
      · change rule ctx.next ≠ none
        rw [← keyEq, known]; exact Option.some_ne_none value
      · simpa only [keyEq] using own
    · right
      refine ⟨?_, Or.inr ?_⟩
      · change rule ctx.next ≠ none
        rw [← keyEq, known]; exact Option.some_ne_none value
      · simpa only [rootSources, List.length_singleton, readyKey] using child

theorem within_fixedOwn {env key callee labels positions sources binding selected}
    (known : rangeCallAt env key (.call callee labels positions sources) = some binding)
    (fixed : fixedBinding binding = true) (extra : IntervalWarning → Prop) :
    Within (fixedOwn binding key selected) empty
      (fun w => extra w ∨ (callRoot (rangeTables env) (.call callee labels positions sources)).allows key w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    have origin := fixedOwn_warning_origin known fixed member
    obtain ⟨same, _⟩ := baseFixedOwn_warning member
    refine Or.inl (Or.inr ⟨origin, ?_⟩)
    cases same
    exact known

-- 認定した call の引数は同じ環境で解析し、未認定なら追加分を空にする。
set_option maxHeartbeats 800000 in
theorem within_call (fuel : Nat) (env : AbstractEnv) (callee : Expr)
    (labels : List (Option String)) (positions : List Nat) (sources : Exprs) (extra)
    (ha : ∀ extra, Within (arguments fuel env sources) (CallReach.exprs env sources) extra)
    (he : ∀ extra source, Within (BudgetAnalysis.expr fuel env source) (CallReach.expr env source) extra) :
    Within (BudgetAnalysis.expr (fuel + 1) env (.call callee labels positions sources))
      (CallReach.expr env (.call callee labels positions sources)) extra := by
  have valid (key binding) (known : rangeCallAt env key (.call callee labels positions sources) = some binding) :
      Within (do
      skipExpr fuel callee
      if fixedBinding binding then do
        let selected ← selectArguments (BudgetAnalysis.expr fuel env) (skipExprs fuel)
          (bindingArgument binding) positions sources
        pure (baseThen selected (← fixedOwn binding key selected))
      else do
        let values ← arguments fuel env sources
        let output ← scan (BudgetScan.rangeValue env ⟨.call callee labels positions sources, .base .integer, key⟩)
        pure (baseThen values output))
        (outside (surfacePreorder callee) ++ CallReach.exprs env sources)
        (fun w => extra w ∨ (callRoot (rangeTables env) (.call callee labels positions sources)).allows key w) := by
    apply within_bind ((skip_walk fuel).1 callee)
      (silent_within ((skip_silent fuel).1 callee) _ _ ((skip_walk fuel).1 callee))
    intro _
    split
    · rename_i fixed
      apply within_bind_empty (by
        simpa only [exprs_sources] using (walk_selectArguments _ _ _ _ _
          ((BudgetAnalysis.analysis_walk fuel).1 env) ((BudgetAnalysis.skip_walk fuel).2.2.1)))
        (within_selectArguments fuel env _ _ _ _ (he _))
      intro selected
      exact within_map (walk_fixedOwn binding key selected) (within_fixedOwn known fixed extra) _
    · apply within_bind_empty ((analysis_walk fuel).2.2.2.2.1 env sources) (ha _)
      intro values
      simpa only [empty_append] using within_bind (walk_scan _) (within_scan _ _) (fun _ => within_pure _ _)
  intro limits ctx
  rw [BudgetAnalysis.expr.eq_def]
  apply spec_scope
  intro entered enteredOk
  have enteredKey : entered.next = ctx.next := by
    simpa only [enteredOk] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
  apply spec_bind (spec_identify _ limits entered _ _ trivial)
  intro key middle identified keyEq
  have rootKey : key = ctx.next := keyEq.trans enteredKey
  have middleKey : middle.next = advanceKey ctx.next 1 := by
    have advanced : middle.next = advanceKey entered.next 1 := (identify_success _ limits entered identified).2.1
    exact advanced.trans (congrArg (fun key => advanceKey key 1) enteredKey)
  apply spec_bind (spec_scan _ limits middle (fun _ => True) _ _ (by intros; trivial))
  intro _ classified classifiedOk _
  have classifiedKey : classified.next = advanceKey ctx.next 1 := by
    simpa only [classifiedOk, middleKey] using (scan_preserves_saved (BudgetScan.tick .expression) limits middle).2.2.1
  apply spec_bind (spec_scan_agrees _ _ (BudgetScan.rangeCall_agrees _ _ _) limits classified _ _)
  intro recognized ready recognizedOk recognizedEq
  have readyKey : ready.next = advanceKey ctx.next 1 := by
    simpa only [recognizedOk, classifiedKey] using (scan_preserves_saved (BudgetScan.rangeCall env key (.call callee labels positions sources)) limits classified).2.2.1
  rw [recognizedEq]
  cases known : rangeCallAt env key (.call callee labels positions sources) with
  | none =>
    exact spec_mono (within_unknown fuel env (.call callee labels positions sources) empty (fun _ => False) limits ready)
      (by intros; trivial) (fun _ h => False.elim (h.elim id id)) (by intros; trivial)
  | some binding =>
    apply spec_mono (valid key binding known limits ready) (by intros; trivial) _ (by intros; trivial)
    intro warning member
    rcases member with (old | own) | child
    · exact Or.inl old
    · right
      simp only [CallReach.expr, exprTables, gate, append_assoc, append_allows]
      refine ⟨?_, Or.inl ?_⟩
      · change rangeCallAt env ctx.next _ ≠ none
        rw [← rootKey, known]; exact Option.some_ne_none binding
      · simpa only [rootKey] using own
    · right
      simp only [CallReach.expr, exprTables, gate, append_assoc, append_allows]
      refine ⟨?_, Or.inr ?_⟩
      · change rangeCallAt env ctx.next _ ≠ none
        rw [← rootKey, known]; exact Option.some_ne_none binding
      · simpa only [append_sources, callRoot, List.length_singleton, readyKey, CallReach.exprs,
          append_assoc, append_allows] using child


set_option maxHeartbeats 800000 in
theorem skip_walk (fuel : Nat) (env : AbstractEnv) :
    (∀ source, Walk (skipExpr fuel source) (CallReach.expr env source).sources) ∧
    (∀ source, Walk (skipChildren fuel source) (CallReach.children env source).sources) ∧
    (∀ sources, Walk (skipExprs fuel sources) (outside (preorderExprs sources)).sources) ∧
    (∀ args, Walk (skipHoles fuel args) (outside (preorderHoles args)).sources) ∧
    (∀ body, Walk (skipBlock fuel body) (CallReach.block env body).sources) ∧
    (∀ arms, Walk (skipArms fuel arms) (CallReach.armList env arms).sources) ∧
    (∀ clauses, Walk (skipClauses fuel clauses) (outside (preorderClauses clauses)).sources) ∧
    (∀ value, Walk (skipOptional fuel value)
      (match value with | none => empty | some source => CallReach.expr env source).sources) := by
  obtain ⟨he, hc, hes, hh, hb, ha, hcl, ho⟩ := BudgetAnalysis.skip_walk fuel
  refine ⟨?_, ?_, hes, hh, ?_, ?_, hcl, ?_⟩
  · simpa only [expr_sources] using he
  · intro source
    cases source <;> simp only [CallReach.children, childrenTables, append_sources,
      exprTables_sources, exprsTables_sources, blockTables_sources, armListTables_sources, outside, surfacePreorder, List.tail_cons]
    all_goals first | exact hc _ | (split <;> simp only [append_sources, exprTables_sources] <;> exact hc _)
  · simpa only [block_sources] using hb
  · simpa only [armList_sources] using ha
  · intro value
    cases value with
    | none => exact ho none
    | some source => simpa only [expr_sources] using ho (some source)

theorem skip_within (fuel : Nat) (env : AbstractEnv) (extra) :
    (∀ source, Within (skipExpr fuel source) (CallReach.expr env source) extra) ∧
    (∀ source, Within (skipChildren fuel source) (CallReach.children env source) extra) ∧
    (∀ sources, Within (skipExprs fuel sources) (outside (preorderExprs sources)) extra) ∧
    (∀ args, Within (skipHoles fuel args) (outside (preorderHoles args)) extra) ∧
    (∀ body, Within (skipBlock fuel body) (CallReach.block env body) extra) ∧
    (∀ arms, Within (skipArms fuel arms) (CallReach.armList env arms) extra) ∧
    (∀ clauses, Within (skipClauses fuel clauses) (outside (preorderClauses clauses)) extra) ∧
    (∀ value, Within (skipOptional fuel value)
      (match value with | none => empty | some source => CallReach.expr env source) extra) := by
  obtain ⟨se, sc, ses, sh, sb, sa, scl, so⟩ := skip_silent fuel
  obtain ⟨we, wc, wes, wh, wb, wa, wcl, wo⟩ := BudgetAnalysis.skip_walk fuel
  exact ⟨fun source => silent_within (se source) _ extra (we source),
    fun source => silent_within (sc source) _ extra (wc source),
    fun sources => silent_within (ses sources) _ extra (wes sources),
    fun args => silent_within (sh args) _ extra (wh args),
    fun body => silent_within (sb body) _ extra (wb body),
    fun arms => silent_within (sa arms) _ extra (wa arms),
    fun clauses => silent_within (scl clauses) _ extra (wcl clauses),
    fun value => silent_within (so value) _ extra (wo value)⟩


theorem within_scan_then {work : BudgetScan.Scan α} {next : α → Analysis β} {plan : CallReach.Scope} {extra}
    (hn : ∀ value, Within (next value) plan extra) : Within (scan work >>= next) plan extra := by
  intro limits ctx
  apply spec_bind (spec_scan work limits ctx (fun _ => True) _ _ (by intros; trivial))
  intro value middle ok _
  have key : middle.next = ctx.next := by
    simpa only [ok] using (scan_preserves_saved work limits ctx).2.2.1
  simpa only [key] using hn value limits middle

theorem within_get_then {next : Context → Analysis β} {plan : CallReach.Scope} {extra}
    (hn : ∀ value, Within (next value) plan extra) : Within (get >>= next) plan extra := by
  intro limits ctx
  exact hn ctx limits ctx

theorem within_expr_tables {work : Analysis α} {left right : AbstractEnv} {source extra}
    (same : rangeTables left = rangeTables right) (h : Within work (CallReach.expr left source) extra) :
    Within work (CallReach.expr right source) extra := by rw [← expr_tables same]; exact h

theorem within_block_tables {work : Analysis α} {left right : AbstractEnv} {body extra}
    (same : rangeTables left = rangeTables right) (h : Within work (CallReach.block left body) extra) :
    Within work (CallReach.block right body) extra := by rw [← block_tables same]; exact h

set_option maxHeartbeats 800000 in
/-- 任意の予算・既存の保存列について、追加した警告の範囲を同時に示す。 -/
theorem analysis_within_all (fuel : Nat) :
    (∀ extra env source, Within (BudgetAnalysis.expr fuel env source) (CallReach.expr env source) extra) ∧
    (∀ extra env left right truth, Within (shortCircuit fuel env left right truth)
      (CallReach.expr env left ++ CallReach.expr env right) extra) ∧
    (∀ extra env body, Within (BudgetAnalysis.block fuel env body) (CallReach.block env body) extra) ∧
    (∀ extra kind env source normal arms, Within (armListKind fuel kind env source normal arms) (CallReach.armList env arms) extra) ∧
    (∀ extra env sources, Within (arguments fuel env sources) (CallReach.exprs env sources) extra) ∧
    (∀ extra env input arms, Within (resultArmList fuel env input arms) (CallReach.armList env arms) extra) := by
  induction fuel with
  | zero => exact ⟨fun _ _ _ => within_throw _ _ _, fun _ _ _ _ _ => within_throw _ _ _,
      fun _ _ _ => within_throw _ _ _, fun _ _ _ _ _ _ => within_throw _ _ _, fun _ _ _ => within_throw _ _ _, fun _ _ _ _ => within_throw _ _ _⟩
  | succ fuel ih =>
    obtain ⟨he, hs, hb, ha, hargs, hr⟩ := ih
    obtain ⟨we, ws, wb, wa, wargs, wr⟩ := analysis_walk fuel
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro extra env source
      obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel env
      by_cases call : ∃ callee labels positions sources, source = .call callee labels positions sources
      · obtain ⟨callee, labels, positions, sources, rfl⟩ := call
        exact within_call fuel env callee labels positions sources extra (fun extra => hargs extra env sources) (fun extra source => he extra env source)
      have split : CallReach.expr env source = root source ++ CallReach.children env source := by
        cases source <;> simp only [CallReach.expr, exprTables, CallReach.children]
        case call callee labels positions sources => exact (call ⟨callee, labels, positions, sources, rfl⟩).elim
      rw [BudgetAnalysis.expr.eq_def]
      apply within_scope
      rw [split]
      apply within_identified
      intro key
      apply within_scan_then
      intro _
      cases source <;> simp only [CallReach.children, childrenTables]
      case literal value =>
        cases value <;> first
          | exact within_pure _ _
          | exact within_widthLiteral _ _ _
          | exact within_unknown _ _ _ _ _
      case neg type child =>
        split
        · exact within_bind_empty (we env child) (he _ env child) (fun value =>
            within_map (walk_negOwnTyped key type value) (within_negOwnTyped key type value child extra) _)
        · exact within_unknown fuel env (.neg type child) _ _
      case binary op type left right =>
        split
        · apply within_bind (we env left) (he _ env left)
          intro lhs
          split
          · exact within_map (se right) ((skip_within fuel env _).1 right) _
          · apply within_bind_empty (we env right) (he _ env right)
            intro rhs
            split
            · exact within_pure _ _
            · exact within_map (walk_own _ _ _ _ _) (within_own key op type lhs rhs left right extra) _
        · exact within_unknown fuel env (.binary op type left right) _ _
      case call callee labels positions sources => exact (call ⟨callee, labels, positions, sources, rfl⟩).elim
      case «local» index =>
        apply within_scan_then
        intro slot
        cases slot with
        | none => exact within_pure _ _
        | some slot => cases slot <;> first
          | exact within_pure _ _
          | exact within_pure _ _
      case matchE type source arms =>
        apply within_bind (we env source) (he _ env source)
        intro tested
        split
        · exact within_map (sa arms) ((skip_within fuel env _).2.2.2.2.2.1 arms) _
        · apply within_scan_then
          intro known
          cases known with
          | some origin => exact within_map (wr env _ arms) (hr _ env _ arms) _
          | none =>
            cases selected : tested.matchKind with
            | some kind =>
              exact within_map (wa kind env source (tested.rangeKind kind) arms)
                (ha _ kind env source (tested.rangeKind kind) arms) _
            | none =>
              exact within_bind_empty (sa arms) ((skip_within fuel env _).2.2.2.2.2.1 arms)
                (fun _ => within_map walk_unsupported (within_unsupported _) _)
      case ite condition yes no =>
        simp only [CallReach.append_assoc]
        apply within_bind (we env condition) (he _ env condition)
        intro tested
        apply within_bind (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner yes) (sb yes))
          (within_branch _ _ _ _ _ _ _ _ (fun inner same => within_block_tables same (hb _ inner yes))
            ((skip_within fuel env _).2.2.2.2.1 yes) (sb yes))
        intro positive
        exact within_map (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner no) (sb no))
          (within_branch _ _ _ _ _ _ _ _ (fun inner same => within_block_tables same (hb _ inner no))
            ((skip_within fuel env _).2.2.2.2.1 no) (sb no)) _
      case elseIf condition yes no =>
        simp only [CallReach.append_assoc]
        apply within_bind (we env condition) (he _ env condition)
        intro tested
        apply within_bind (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner yes) (sb yes))
          (within_branch _ _ _ _ _ _ _ _ (fun inner same => within_block_tables same (hb _ inner yes))
            ((skip_within fuel env _).2.2.2.2.1 yes) (sb yes))
        intro positive
        exact within_map (walk_branch _ _ _ _ _ _ _ (fun inner => we inner no) (se no))
          (within_branch _ _ _ _ _ _ _ _ (fun inner same => within_expr_tables same (he _ inner no))
            ((skip_within fuel env _).1 no) (se no)) _
      case ifOnly condition yes =>
        apply within_bind (we env condition) (he _ env condition)
        intro tested
        apply within_bind_empty (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner yes) (sb yes))
          (within_branch _ _ _ _ _ _ _ _ (fun inner same => within_block_tables same (hb _ inner yes))
            ((skip_within fuel env _).2.2.2.2.1 yes) (sb yes))
        intro positive
        exact within_map (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure _) (walk_pure ()))
          (within_branch _ _ _ _ _ _ empty _ (fun _ _ => within_pure _ _) (within_pure _ _) (walk_pure ())) _
      all_goals first
        | exact within_unknown _ _ _ _ _
        | exact within_pure _ _
        | exact within_widthLiteral _ _ _
        | exact within_scan_then (fun _ => within_pure _ _)
        | exact he _ _ _
        | simpa only [CallReach.expr, tables_clear] using he _ (clearLocals env) _
        | exact within_map (we _ _) (he _ _ _) _
        | exact hb _ _ _
        | exact hs _ _ _ _ _
    · intro extra env left right truth
      obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel env
      rw [shortCircuit]
      apply within_bind (we env left) (he _ env left)
      intro tested
      apply within_bind_empty (walk_branch _ _ _ _ _ _ _ (fun inner => we inner right) (se right))
        (within_branch _ _ _ _ _ _ _ _ (fun inner same => within_expr_tables same (he _ inner right))
          ((skip_within fuel env _).1 right) (se right))
      intro continued
      exact within_map (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure _) (walk_pure ()))
        (within_branch _ _ _ _ _ _ empty _ (fun _ _ => within_pure _ _) (within_pure _ _) (walk_pure ())) _
    · intro extra env body
      obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel env
      rw [BudgetAnalysis.block.eq_def]
      apply within_scope
      apply within_scan_then
      intro _
      cases body with
      | empty => simpa only [CallReach.block, blockTables] using within_pure baseUnit extra
      | builderBind kind rest =>
        simp only [CallReach.block, blockTables]
        apply within_scan_bind (BudgetScan.push_agrees _ _)
        intro inner eq
        apply within_block_tables (left := inner) (by rw [eq]; rfl)
        exact hb _ inner rest
      | last source =>
        simpa only [CallReach.block, blockTables] using he extra env source
      | lastBind _ _ source | lastDiscard source | lastPat _ _ _ source =>
        simp only [CallReach.block, blockTables]
        exact within_map (we env source) (he _ env source) _
      | bind kind type source rest =>
        simp only [CallReach.block, blockTables]
        apply within_get_then
        intro start
        apply within_bind (we env source) (he _ env source)
        intro head
        split
        · exact within_map (sb rest) ((skip_within fuel env _).2.2.2.2.1 rest) _
        · apply within_scan_bind (BudgetScan.rangeBind_agrees _ _ _ _ _)
          intro inner eq
          apply within_block_tables (left := inner) (by rw [eq]; exact tables_bind _ _ _ _ _)
          exact within_map (wb inner rest) (hb _ inner rest) _
      | discard source rest | seq source rest =>
        simp only [CallReach.block, blockTables]
        apply within_bind (we env source) (he _ env source)
        intro head
        split
        · exact within_map (sb rest) ((skip_within fuel env _).2.2.2.2.1 rest) _
        · exact within_map (wb env rest) (hb _ env rest) _
      | bindPat _ pattern type source rest =>
        simp only [CallReach.block, blockTables]
        apply within_bind (we env source) (he _ env source)
        intro head
        split
        · exact within_map (sb rest) ((skip_within fuel env _).2.2.2.2.1 rest) _
        · apply within_scan_bind (BudgetScan.patternEnv_agrees _ _ _)
          intro inner eq
          apply within_block_tables (left := inner) (by rw [eq]; exact tables_pattern _ _ _)
          exact within_map (wb inner rest) (hb _ inner rest) _
    · intro extra kind env source normal arms
      obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel env
      rw [armListKind.eq_def]
      apply within_scope
      apply within_scan_then
      intro _
      cases arms with
      | nil => simpa only [CallReach.armList, armListTables] using within_pure baseEmpty extra
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [CallReach.armList, armListTables, CallReach.empty_append]
          apply within_bind (ys := CallReach.armList env rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            cases inner with
            | none => exact walk_bind (so none) (fun _ => walk_map (sb body) _)
            | some inner => exact wb inner body
          · apply within_scope
            apply within_scan_bind (BudgetScan.armKind_agrees _ _ _ _ _)
            intro selected eq
            cases selected with
            | none =>
              simpa only [empty_append] using within_bind (so none) ((skip_within fuel env _).2.2.2.2.2.2.2 none)
                (fun _ => within_map (sb body) ((skip_within fuel env _).2.2.2.2.1 body) _)
            | some inner => exact within_block_tables (tables_arm env source kind normal alts inner eq.symm) (hb _ inner body)
          · intro first
            exact within_map (wa kind env source normal rest) (ha _ kind env source normal rest) _
        | some condition =>
          simp only [CallReach.armList, armListTables]
          apply within_bind (ys := CallReach.armList env rest)
          · simp only [CallReach.append_sources]
            apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            cases inner with
            | none => exact walk_bind (so (some condition)) (fun _ => walk_map (sb body) _)
            | some inner =>
              apply walk_bind (we inner condition)
              intro tested
              exact walk_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body)) _
          · apply within_scope
            apply within_scan_bind (BudgetScan.armKind_agrees _ _ _ _ _)
            intro selected eq
            cases selected with
            | none =>
              exact within_bind (so (some condition)) ((skip_within fuel env _).2.2.2.2.2.2.2 (some condition))
                (fun _ => within_map (sb body) ((skip_within fuel env _).2.2.2.2.1 body) _)
            | some inner =>
              have same := tables_arm env source kind normal alts inner eq.symm
              rw [← same]
              obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel inner
              apply within_bind (we inner condition) (he _ inner condition)
              intro tested
              exact within_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body))
                (within_branch _ _ _ _ _ _ _ _ (fun refined same => within_block_tables same (hb _ refined body))
                  ((skip_within fuel inner _).2.2.2.2.1 body) (sb body)) _
          · intro first
            exact within_map (wa kind env source normal rest) (ha _ kind env source normal rest) _



    · intro extra env sources
      obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel env
      rw [arguments.eq_def]
      apply within_scope
      apply within_scan_then
      intro _
      cases sources with
      | nil => simpa only [CallReach.exprs, exprsTables] using within_pure baseUnit extra
      | cons source rest =>
        simp only [CallReach.exprs, exprsTables]
        apply within_bind (we env source) (he _ env source)
        intro head
        split
        · have walking : Walk (skipExprs fuel rest) (CallReach.exprs env rest).sources := by
            simpa only [exprs_sources] using (BudgetAnalysis.skip_walk fuel).2.2.1 rest
          exact within_map walking (silent_within ((skip_silent fuel).2.2.1 rest) _ _ walking) _
        · exact within_map (wargs env rest) (hargs _ env rest) _
    · intro extra env input arms
      obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel env
      rw [resultArmList.eq_def]
      apply within_scope
      apply within_scan_then
      intro _
      cases arms with
      | nil => simpa only [CallReach.armList, armListTables] using within_pure baseEmpty extra
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [CallReach.armList, armListTables, CallReach.empty_append]
          apply within_bind (ys := CallReach.armList env rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            exact wb inner body
          · apply within_scope
            apply within_scan_bind (BudgetScan.rangeArm_agrees _ _ _)
            intro inner eq
            exact within_block_tables (by rw [eq]; exact tables_resultArm _ _ _) (hb _ inner body)
          · intro first
            exact within_map (wr env input rest) (hr _ env input rest) _
        | some condition =>
          simp only [CallReach.armList, armListTables]
          apply within_bind (ys := CallReach.armList env rest)
          · simp only [CallReach.append_sources]
            apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            apply walk_bind (we inner condition)
            intro tested
            exact walk_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body)) _
          · apply within_scope
            apply within_scan_bind (BudgetScan.rangeArm_agrees _ _ _)
            intro inner eq
            have same : rangeTables inner = rangeTables env := by rw [eq]; exact tables_resultArm _ _ _
            rw [← same]
            obtain ⟨se, sc, _, _, sb, sa, _, so⟩ := skip_walk fuel inner
            apply within_bind (we inner condition) (he _ inner condition)
            intro tested
            exact within_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body))
              (within_branch _ _ _ _ _ _ _ _ (fun refined same => within_block_tables same (hb _ refined body))
                ((skip_within fuel inner _).2.2.2.2.1 body) (sb body)) _
          · intro first
            exact within_map (wr env input rest) (hr _ env input rest) _

end Benitoite.Interval.BudgetAnalysis.CallExclusion
