import Benitoite.Interval.SyntacticReach
import Benitoite.Interval.BudgetBody
import Benitoite.Interval.CallReachSound

/-!
# 予算付き解析の構文的な到達可能性の保存

未知の内側を親の範囲から除き、任意の上限・初期消費・深さについて
成功と停止の両方で追加警告の所属を示す。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 親自身の警告は extra で渡し、子の警告はその子の番号列で位置を確かめる。 -/
def Within (work : Analysis α) (slots : List (Bool × Expr)) (extra : IntervalWarning → Prop) : Prop :=
  ∀ limits ctx, Spec work limits ctx (fun _ => True)
    (fun warning => extra warning ∨ InSyntacticReach ctx.next slots warning) (fun _ => True)

theorem Silent.within {work : Analysis α} (h : Silent work) (slots : List (Bool × Expr))
    {sources : List Expr} (walk : Walk work sources) (extra : IntervalWarning → Prop) : Within work slots extra := by
  intro limits ctx
  exact ⟨⟨⟨[], by simpa using h limits ctx, by simp⟩,
    (walk.identities limits ctx).mono (by intros; trivial)⟩, by intros; trivial⟩

theorem within_pure (value : α) (extra : IntervalWarning → Prop) : Within (pure value) [] extra :=
  (silent_pure value).within [] (walk_pure value) extra

theorem within_get (extra : IntervalWarning → Prop) :
    Within (get : Analysis Context) [] extra := silent_get.within [] walk_get extra

theorem within_throw (reason : Halt) (slots : List (Bool × Expr)) (extra : IntervalWarning → Prop) :
    Within (throw reason : Analysis α) slots extra :=
  (silent_throw reason).within slots (walk_throw reason []) extra

theorem within_scan (work : BudgetScan.Scan α) (extra : IntervalWarning → Prop) :
    Within (scan work) [] extra := (silent_scan work).within [] (walk_scan work) extra

theorem InSyntacticReach.left {key xs warning} (ys : List (Bool × Expr)) (h : InSyntacticReach key xs warning) :
    InSyntacticReach key (xs ++ ys) warning := by
  obtain ⟨source, member, operation⟩ := h
  exact ⟨source, by rw [numberSyntacticReach_append]; exact List.mem_append_left _ member, operation⟩

theorem InSyntacticReach.right {key ys warning} (xs : List (Bool × Expr))
    (h : InSyntacticReach (advanceKey key xs.length) ys warning) : InSyntacticReach key (xs ++ ys) warning := by
  obtain ⟨source, member, operation⟩ := h
  exact ⟨source, by rw [numberSyntacticReach_append]; exact List.mem_append_right _ member, operation⟩

/-- 停止した前半だけで追加分を閉じ、成功時に限って後半の開始番号を進める。 -/
theorem within_bind {first : Analysis α} {next : α → Analysis β} {xs ys : List (Bool × Expr)}
    {extra : IntervalWarning → Prop} (walk : Walk first (xs.map Prod.snd))
    (hf : Within first xs extra) (hn : ∀ value, Within (next value) ys extra) :
    Within (first >>= next) (xs ++ ys) extra := by
  intro limits ctx
  apply spec_bind (post := fun _ => True)
  · exact spec_mono (hf limits ctx) (by intros; trivial)
      (fun _ h => h.imp_right (InSyntacticReach.left ys)) (by intros; trivial)
  · intro value middle ok _
    have key : middle.next = advanceKey ctx.next xs.length := by
      simpa only [List.length_map] using (walk.success ok).1
    exact spec_mono (hn value limits middle) (by intros; trivial)
      (fun _ h => h.imp_right (fun h => InSyntacticReach.right xs (key ▸ h))) (by intros; trivial)

theorem within_scope {work : Unit → Analysis α} {sources : List (Bool × Expr)} {extra}
    (h : Within (work ()) sources extra) : Within (scope work) sources extra := by
  intro limits ctx
  apply spec_scope
  intro entered ok
  have key : entered.next = ctx.next := by
    simpa only [ok] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
  simpa only [key] using h limits entered

theorem within_map {work : Analysis α} {sources : List (Bool × Expr)} {extra}
    (walk : Walk work (sources.map Prod.snd)) (h : Within work sources extra) (f : α → β) :
    Within (work >>= fun value => pure (f value)) sources extra := by
  simpa only [List.append_nil] using within_bind walk h (fun value => within_pure (f value) extra)

theorem within_bind_empty {work : Analysis α} {next : α → Analysis β} {sources : List (Bool × Expr)} {extra}
    (walk : Walk work (sources.map Prod.snd)) (h : Within work sources extra)
    (hn : ∀ value, Within (next value) [] extra) : Within (work >>= next) sources extra := by
  simpa only [List.append_nil] using within_bind walk h hn

theorem within_unsupported (extra : IntervalWarning → Prop) : Within unsupported [] extra := by
  exact (show Silent unsupported from by intro limits ctx; rfl).within [] walk_unsupported extra

/-- 幅付きの葉は番号・警告・独立入力を追加しない。 -/
theorem within_widthLiteral (kind : IntKind) (value : Int) (extra : IntervalWarning → Prop) :
    Within (widthLiteral kind value) [] extra := by
  unfold widthLiteral
  split
  · exact within_pure _ _
  · exact within_unsupported _

theorem within_identified {source : Expr} {children : List (Bool × Expr)} {next : OperationKey → Analysis α}
    {extra : IntervalWarning → Prop}
    (hn : ∀ key, Within (next key) children (fun w => extra w ∨ RootWarning key source w)) :
    Within (identify source >>= next) ((concreteRule source, source) :: children) extra := by
  intro limits ctx
  apply spec_bind (spec_identify source limits ctx _ _ trivial)
  intro key middle ok same
  have advanced : middle.next = advanceKey ctx.next 1 := (identify_success source limits ctx ok).2.1
  apply spec_mono (hn key limits middle) (by intros; trivial) _ (by intros; trivial)
  intro warning member
  rcases member with (old | root) | child
  · exact Or.inl old
  · right
    exact ⟨source, by simp [numberSyntacticReach, root.1, same, warning_target_concrete root.2], root.2⟩
  · right
    simpa only [List.singleton_append] using
      InSyntacticReach.right [(concreteRule source, source)] (advanced ▸ child)

theorem within_own (key op type left right lhs rhs) (extra : IntervalWarning → Prop) :
    Within (own key op type left right) []
      (fun w => extra w ∨ RootWarning key (.binary op type lhs rhs) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (own_warning_origin key op type left right lhs rhs warning member))

theorem within_negOwn (key child source) (extra : IntervalWarning → Prop) :
    Within (negOwn key child) []
      (fun w => extra w ∨ RootWarning key (.neg (.base .integer) source) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (negOwn_warning_origin key child source warning member))

theorem within_negOwnTyped (key type child source) (extra : IntervalWarning → Prop) :
    Within (negOwnTyped key type child) []
      (fun w => extra w ∨ RootWarning key (.neg type source) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (negOwnTyped_warning_origin key type child source warning member))

theorem within_branch (env source tested truth run skip sources extra)
    (hr : ∀ inner, Within (run inner) sources extra)
    (hs : Within (skip ()) sources extra) (ws : Walk (skip ()) (sources.map Prod.snd)) :
    Within (branch env source tested truth run skip) sources extra := by
  apply within_scope
  simpa only [List.nil_append] using within_bind (walk_scan _) (within_scan _ extra) (fun refined => by
    cases refined with
    | none => exact within_map ws hs (fun _ => baseEmpty)
    | some inner => exact hr inner)

/-- 独立した子の候補を親へ戻さないため、親の範囲に警告を追加しない。 -/
theorem within_unknown (fuel : Nat) (env : AbstractEnv) (source : Expr) (slots : List (Bool × Expr))
    (extra : IntervalWarning → Prop) :
    Within (unknownChildren (expr fuel) (block fuel) fuel env source >>= fun _ => unsupported) slots extra := by
  have silent : Silent unsupported := by intro limits ctx; rfl
  exact (silent_bind (unknownChildren_silent (expr fuel) (block fuel) fuel env source) (fun _ => silent)).within slots
    (walk_bind (unknownChildren_walk (expr fuel) (block fuel) (analysis_walk fuel).1
      (analysis_walk fuel).2.2.1 fuel env source) (fun _ => walk_unsupported)) extra

/-- 印を忘れた列は、実際の番号走査の列と等しい。 -/
theorem syntacticReach_analysis_walk_all (fuel : Nat) :
    (∀ env source, Walk (expr fuel env source) ((syntacticReachExpr source).map Prod.snd)) ∧
    (∀ env left right truth, Walk (shortCircuit fuel env left right truth)
      ((syntacticReachExpr left ++ syntacticReachExpr right).map Prod.snd)) ∧
    (∀ env body, Walk (block fuel env body) ((syntacticReachBlock body).map Prod.snd)) ∧
    (∀ kind env source normal arms, Walk (armListKind fuel kind env source normal arms)
      ((syntacticReachArms arms).map Prod.snd)) ∧
    (∀ env sources, Walk (arguments fuel env sources) ((syntacticReachExprs sources).map Prod.snd)) ∧
    (∀ env input arms, Walk (resultArmList fuel env input arms) ((syntacticReachArms arms).map Prod.snd)) := by
  simpa only [List.map_append, syntacticReachExpr_sources, syntacticReachBlock_sources, syntacticReachArms_sources, syntacticReachExprs_sources]
    using analysis_walk_all fuel

theorem syntacticReach_analysis_walk_kind (fuel : Nat) :
    (∀ env source, Walk (expr fuel env source) ((syntacticReachExpr source).map Prod.snd)) ∧
    (∀ env left right truth, Walk (shortCircuit fuel env left right truth)
      ((syntacticReachExpr left ++ syntacticReachExpr right).map Prod.snd)) ∧
    (∀ env body, Walk (block fuel env body) ((syntacticReachBlock body).map Prod.snd)) ∧
    (∀ kind env source normal arms, Walk (armListKind fuel kind env source normal arms)
      ((syntacticReachArms arms).map Prod.snd)) := by
  simpa only [List.map_append, syntacticReachExpr_sources, syntacticReachBlock_sources, syntacticReachArms_sources]
    using analysis_walk_kind fuel

theorem syntacticReach_analysis_walk (fuel : Nat) :
    (∀ env source, Walk (expr fuel env source) ((syntacticReachExpr source).map Prod.snd)) ∧
    (∀ env left right truth, Walk (shortCircuit fuel env left right truth)
      ((syntacticReachExpr left ++ syntacticReachExpr right).map Prod.snd)) ∧
    (∀ env body, Walk (block fuel env body) ((syntacticReachBlock body).map Prod.snd)) ∧
    (∀ env source normal arms, Walk (armList fuel env source normal arms)
      ((syntacticReachArms arms).map Prod.snd)) := by
  simpa only [List.map_append, syntacticReachExpr_sources, syntacticReachBlock_sources, syntacticReachArms_sources]
    using analysis_walk fuel

theorem syntacticReach_skip_walk (fuel : Nat) :
    (∀ source, Walk (skipExpr fuel source) ((syntacticReachExpr source).map Prod.snd)) ∧
    (∀ source, Walk (skipChildren fuel source) ((syntacticReachChildren source).map Prod.snd)) ∧
    (∀ sources, Walk (skipExprs fuel sources) (preorderExprs sources)) ∧
    (∀ args, Walk (skipHoles fuel args) (preorderHoles args)) ∧
    (∀ body, Walk (skipBlock fuel body) ((syntacticReachBlock body).map Prod.snd)) ∧
    (∀ arms, Walk (skipArms fuel arms) ((syntacticReachArms arms).map Prod.snd)) ∧
    (∀ clauses, Walk (skipClauses fuel clauses) (preorderClauses clauses)) ∧
    (∀ value, Walk (skipOptional fuel value)
      ((match value with | none => [] | some source => syntacticReachExpr source).map Prod.snd)) := by
  obtain ⟨he, hc, hes, hh, hb, ha, hcl, ho⟩ := skip_walk fuel
  refine ⟨?_, ?_, hes, hh, ?_, ?_, hcl, ?_⟩
  · simpa only [syntacticReachExpr_sources] using he
  · simpa only [syntacticReachChildren_sources] using hc
  · simpa only [syntacticReachBlock_sources] using hb
  · simpa only [syntacticReachArms_sources] using ha
  · intro value
    cases value with
    | none => simpa only [List.map_nil] using ho none
    | some source => simpa only [syntacticReachExpr_sources] using ho (some source)

/-- 値を解析しない部分は、任意の警告述語に対して空の追加分を返す。 -/
theorem skip_within (fuel : Nat) (extra : IntervalWarning → Prop) :
    (∀ source, Within (skipExpr fuel source) (syntacticReachExpr source) extra) ∧
    (∀ source, Within (skipChildren fuel source) (syntacticReachChildren source) extra) ∧
    (∀ sources, Within (skipExprs fuel sources) (outsideSyntacticReach (preorderExprs sources)) extra) ∧
    (∀ args, Within (skipHoles fuel args) (outsideSyntacticReach (preorderHoles args)) extra) ∧
    (∀ body, Within (skipBlock fuel body) (syntacticReachBlock body) extra) ∧
    (∀ arms, Within (skipArms fuel arms) (syntacticReachArms arms) extra) ∧
    (∀ clauses, Within (skipClauses fuel clauses) (outsideSyntacticReach (preorderClauses clauses)) extra) ∧
    (∀ value, Within (skipOptional fuel value)
      (match value with | none => [] | some source => syntacticReachExpr source) extra) := by
  obtain ⟨se, sc, ses, sh, sb, sa, scl, so⟩ := skip_silent fuel
  obtain ⟨we, wc, wes, wh, wb, wa, wcl, wo⟩ := skip_walk fuel
  exact ⟨fun source => (se source).within _ (we source) extra,
    fun source => (sc source).within _ (wc source) extra,
    fun sources => (ses sources).within _ (wes sources) extra,
    fun args => (sh args).within _ (wh args) extra,
    fun body => (sb body).within _ (wb body) extra,
    fun arms => (sa arms).within _ (wa arms) extra,
    fun clauses => (scl clauses).within _ (wcl clauses) extra,
    fun value => (so value).within _ (wo value) extra⟩

-- 全構成子の相互帰納と番号列の書き換えに要する証明器の枠。解析のfuel・予算は変えない。
set_option maxHeartbeats 800000 in
/-- 任意の予算・既存の保存列について、追加した警告の範囲を同時に示す。 -/
private theorem within_of_calls {work : Analysis α} {scope slots extra}
    (compatible : CallReach.Compatible scope slots)
    (inside : CallExclusion.Within work scope extra) : Within work slots extra := by
  intro limits ctx
  apply spec_mono (inside limits ctx) (by intros; trivial) _ (by intros; trivial)
  intro warning member
  exact member.imp_right (compatible.2 ctx.next warning)

theorem analysis_within_all (fuel : Nat) :
    (∀ extra env source, Within (expr fuel env source) (syntacticReachExpr source) extra) ∧
    (∀ extra env left right truth, Within (shortCircuit fuel env left right truth)
      (syntacticReachExpr left ++ syntacticReachExpr right) extra) ∧
    (∀ extra env body, Within (block fuel env body) (syntacticReachBlock body) extra) ∧
    (∀ extra kind env source normal arms, Within (armListKind fuel kind env source normal arms) (syntacticReachArms arms) extra) ∧
    (∀ extra env sources, Within (arguments fuel env sources) (syntacticReachExprs sources) extra) ∧
    (∀ extra env input arms, Within (resultArmList fuel env input arms) (syntacticReachArms arms) extra) := by
  obtain ⟨he, hs, hb, ha, hargs, hr⟩ := CallExclusion.analysis_within_all fuel
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
  · intro extra env source
    exact within_of_calls (CallReach.expr_compatible env source) (he extra env source)
  · intro extra env left right truth
    exact within_of_calls (CallReach.compatible_append (CallReach.expr_compatible env left)
      (CallReach.expr_compatible env right)) (hs extra env left right truth)
  · intro extra env body
    exact within_of_calls (CallReach.block_compatible env body) (hb extra env body)
  · intro extra kind env source normal arms
    exact within_of_calls (CallReach.arms_compatible env arms) (ha extra kind env source normal arms)
  · intro extra env sources
    exact within_of_calls (CallReach.exprs_compatible env sources) (hargs extra env sources)
  · intro extra env input arms
    exact within_of_calls (CallReach.arms_compatible env arms) (hr extra env input arms)

theorem analysis_within_kind (fuel : Nat) :
    (∀ extra env source, Within (expr fuel env source) (syntacticReachExpr source) extra) ∧
    (∀ extra env left right truth, Within (shortCircuit fuel env left right truth)
      (syntacticReachExpr left ++ syntacticReachExpr right) extra) ∧
    (∀ extra env body, Within (block fuel env body) (syntacticReachBlock body) extra) ∧
    (∀ extra kind env source normal arms, Within (armListKind fuel kind env source normal arms) (syntacticReachArms arms) extra) := by
  obtain ⟨he, hs, hb, ha, _, _⟩ := analysis_within_all fuel
  exact ⟨he, hs, hb, ha⟩

/-- Integer64 の既存の入口と言明を保つ。 -/
theorem analysis_within (fuel : Nat) :
    (∀ extra env source, Within (expr fuel env source) (syntacticReachExpr source) extra) ∧
    (∀ extra env left right truth, Within (shortCircuit fuel env left right truth)
      (syntacticReachExpr left ++ syntacticReachExpr right) extra) ∧
    (∀ extra env body, Within (block fuel env body) (syntacticReachBlock body) extra) ∧
    (∀ extra env source normal arms, Within (armList fuel env source normal arms) (syntacticReachArms arms) extra)  := by
  obtain ⟨he, hs, hb, ha⟩ := analysis_within_kind fuel
  exact ⟨he, hs, hb, fun extra => ha extra .integer64⟩

/-- 元からある警告は接尾辞として残し、式の追加警告だけをその範囲へ制限する。 -/
theorem expr_warning_syntactic_reach (fuel : Nat) (env : AbstractEnv) (source : Expr)
    (limits : Limits) (ctx : Context) :
    ListExtension (InSyntacticReach ctx.next (syntacticReachExpr source))
      ctx.warningsRev (expr fuel env source limits ctx).2.warningsRev :=
  ((analysis_within fuel).1 (fun _ => False) env source limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

theorem shortCircuit_warning_syntactic_reach (fuel : Nat) (env : AbstractEnv) (left right : Expr) (truth : Bool)
    (limits : Limits) (ctx : Context) :
    ListExtension (InSyntacticReach ctx.next (syntacticReachExpr left ++ syntacticReachExpr right))
      ctx.warningsRev (shortCircuit fuel env left right truth limits ctx).2.warningsRev :=
  ((analysis_within fuel).2.1 (fun _ => False) env left right truth limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

theorem block_warning_syntactic_reach (fuel : Nat) (env : AbstractEnv) (body : Block)
    (limits : Limits) (ctx : Context) :
    ListExtension (InSyntacticReach ctx.next (syntacticReachBlock body))
      ctx.warningsRev (block fuel env body limits ctx).2.warningsRev :=
  ((analysis_within fuel).2.2.1 (fun _ => False) env body limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

theorem armList_warning_syntactic_reach (fuel : Nat) (env : AbstractEnv) (source : Expr) (normal : Interval)
    (arms : Arms) (limits : Limits) (ctx : Context) :
    ListExtension (InSyntacticReach ctx.next (syntacticReachArms arms))
      ctx.warningsRev (armList fuel env source normal arms limits ctx).2.warningsRev :=
  ((analysis_within fuel).2.2.2 (fun _ => False) env source normal arms limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

/-- 式の入口は空の保存列から始め、停止時も全出力警告の範囲を保証する。 -/
theorem analyzeExpr_warning_syntactic_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (source : Expr) (warning : IntervalWarning)
    (member : warning ∈ (analyzeExpr limits state fuel env key source).approx.warnings) :
    InSyntacticReach key (syntacticReachExpr source) warning := by
  have h := expr_warning_syntactic_reach fuel (resetRanges env) source limits { budget := state, next := key }
  exact (h.member member).resolve_left (by simp)

/-- 中心二命題と同じ式の入口に、任意の予算・初期消費・深さで接続する。 -/
theorem analyze_warning_syntactic_reach : WarningsInSyntacticReach analyze := by
  refine ⟨?_, analyze_warning_located⟩
  intro env input parameters warning member
  exact analyzeExpr_warning_syntactic_reach parameters.limits parameters.state parameters.fuel
    env input.key input.source warning member

/-- 入口の忘却と枠の計上は、根の式の構文的な到達可能性を変更しない。 -/
theorem bodyWork_warning_syntactic_reach (fuel : Nat) (seed : BodySeed) :
    Within (bodyWork fuel seed) (syntacticReachExpr (bodyRoot seed.body)) (fun _ => False) := by
  unfold bodyWork
  apply within_scope
  simpa only [List.nil_append] using
    within_bind (walk_scan _) (within_scan _ _) (fun initial =>
      (analysis_within fuel).1 (fun _ => False) initial (bodyRoot seed.body))

/-- 全体上限の事前停止と忘却中の停止を含め、本体の全警告が根の範囲に属する。 -/
theorem analyzeBody_warning_syntactic_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) (warning : IntervalWarning)
    (member : warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings) :
    InSyntacticReach (bodyRootKey definition) (syntacticReachExpr (bodyRoot seed.body)) warning := by
  have all : ∀ warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings,
      InSyntacticReach (bodyRootKey definition) (syntacticReachExpr (bodyRoot seed.body)) warning := by
    apply analyzeBody_property limits state fuel definition seed
      (fun approx => ∀ warning ∈ approx.warnings,
        InSyntacticReach (bodyRootKey definition) (syntacticReachExpr (bodyRoot seed.body)) warning)
    · simp
    · intro result ctx run warning member
      have h := (bodyWork_warning_syntactic_reach fuel seed limits
        { budget := state, next := bodyRootKey definition }).1.1
      have added := h.member (show warning ∈ (bodyWork fuel seed limits
        { budget := state, next := bodyRootKey definition }).2.warningsRev from by
          simpa only [run, report_warnings] using member)
      exact (added.resolve_left (by simp)).resolve_left id
  exact all warning member

/-- 算術警告の対象は、従来の arithmeticOperationAt の範囲に残る。 -/
theorem analyze_warning_arithmetic (env : AbstractEnv) (input : EvalInput)
    (parameters : Parameters) (warning : IntervalWarning)
    (member : warning ∈ (analyze env input parameters).warnings)
    (arithmetic : ∀ binding, warning.operation ≠ .standard binding) :
    ∃ source, (warning.key, true, source) ∈
        numberSyntacticReach input.key (syntacticReachExpr input.source) ∧
      arithmeticOperationAt source = some warning.operation :=
  (analyze_warning_syntactic_reach.1 env input parameters warning member).arithmetic arithmetic

/-- 本体の入口でも、算術警告は従来の演算の認定に従う。 -/
theorem analyzeBody_warning_arithmetic (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) (warning : IntervalWarning)
    (member : warning ∈ (analyzeBody limits state fuel definition seed).approx.warnings)
    (arithmetic : ∀ binding, warning.operation ≠ .standard binding) :
    ∃ source, (warning.key, true, source) ∈
        numberSyntacticReach (bodyRootKey definition) (syntacticReachExpr (bodyRoot seed.body)) ∧
      arithmeticOperationAt source = some warning.operation :=
  (analyzeBody_warning_syntactic_reach limits state fuel definition seed warning member).arithmetic arithmetic

end Benitoite.Interval.BudgetAnalysis
