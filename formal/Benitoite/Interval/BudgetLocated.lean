import Benitoite.Interval.BudgetTraversal

/-!
# 予算付き解析が追加する警告の位置

入力からある警告は現在の部分木に属するとは限らないため、追加分だけを扱う。
番号の走査と警告の保存のどちらで停止しても、保存済みの位置と対象演算を保つ。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 成否によらず警告列を変更しない処理。対応列の追加は妨げない。 -/
def Silent (work : Analysis α) : Prop :=
  ∀ limits ctx, (work limits ctx).2.warningsRev = ctx.warningsRev

theorem silent_pure (value : α) : Silent (pure value) := by intro limits ctx; rfl
theorem silent_get : Silent (get : Analysis Context) := by intro limits ctx; rfl

theorem silent_throw (reason : Halt) : Silent (throw reason : Analysis α) := by intro limits ctx; rfl
theorem silent_scan (work : BudgetScan.Scan α) : Silent (scan work) :=
  fun limits ctx => (scan_preserves_saved work limits ctx).1

theorem silent_bind {first : Analysis α} {next : α → Analysis β}
    (hf : Silent first) (hn : ∀ value, Silent (next value)) : Silent (first >>= next) := by
  intro limits ctx
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases run : first limits ctx with
  | mk outcome middle =>
    have eq : middle.warningsRev = ctx.warningsRev := by simpa only [run] using hf limits ctx
    cases outcome with
    | error reason => exact eq
    | ok value => exact (hn value limits middle).trans eq

theorem silent_scope {work : Unit → Analysis α} (h : Silent (work ())) : Silent (scope work) := by
  intro limits ctx
  unfold scope
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    have eq : entered.warningsRev = ctx.warningsRev := by
      simpa only [run] using silent_scan (BudgetScan.allocate .stackFrame) limits ctx
    cases outcome with
    | error reason => exact eq
    | ok value =>
      cases inner : work () limits entered with
      | mk outcome final =>
        simp only [inner]
        exact (show final.warningsRev = entered.warningsRev from by
          simpa only [inner] using h limits entered).trans eq

/-- 解析の内側が追加した候補を親の警告列へ混ぜない。 -/
theorem independentWith_silent (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) : Silent (independentWith input env work) := by
  unfold independentWith
  apply silent_scope
  apply silent_bind (silent_scan _)
  intro ignored limits parent
  unfold captureIndependent
  dsimp only
  cases prepareIndependent env limits { parent with warningsRev := [], unsupported := false } with
  | mk outcome ready =>
    cases outcome with
    | error reason => rfl
    | ok initial => cases work initial limits ready; rfl

theorem silent_numbering {work : Unit → Analysis α} (h : Silent (work ())) : Silent (numbering work) :=
  fun limits ctx => by simpa only [numbering_context] using h limits ctx

theorem silent_identify (source : Expr) : Silent (identify source) := by
  intro limits ctx
  cases run : identify source limits ctx with
  | mk outcome final =>
    cases outcome with
    | ok value => exact (identify_success source limits ctx run).2.2.1
    | error reason => exact (identify_stopped source limits ctx run).1

/-- 全 skip 群は、任意の入力列を停止時にもそのまま保持する。 -/
theorem skip_silent (fuel : Nat) :
    (∀ source, Silent (skipExpr fuel source)) ∧
    (∀ source, Silent (skipChildren fuel source)) ∧
    (∀ sources, Silent (skipExprs fuel sources)) ∧
    (∀ args, Silent (skipHoles fuel args)) ∧
    (∀ body, Silent (skipBlock fuel body)) ∧
    (∀ arms, Silent (skipArms fuel arms)) ∧
    (∀ clauses, Silent (skipClauses fuel clauses)) ∧
    (∀ value, Silent (skipOptional fuel value)) := by
  induction fuel with
  | zero => exact ⟨fun _ => silent_throw _, fun _ => silent_throw _,
      fun _ => silent_throw _, fun _ => silent_throw _, fun _ => silent_throw _,
      fun _ => silent_throw _, fun _ => silent_throw _, fun _ => silent_throw _⟩
  | succ fuel ih =>
    obtain ⟨he, hc, hes, hh, hb, ha, hcl, ho⟩ := ih
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro source
      rw [skipExpr]
      exact silent_numbering (silent_scope (silent_bind (silent_identify source) (fun _ => hc source)))
    · intro source
      cases source <;> simp only [skipChildren]
      all_goals try (rename_i message; cases message <;> simp only)
      all_goals first
        | exact silent_pure _
        | exact hes _
        | exact he _
        | exact hb _
        | exact hh _
        | exact silent_bind (he _) (fun _ => hes _)
        | exact silent_bind (he _) (fun _ => hh _)
        | exact silent_bind (he _) (fun _ => hb _)
        | exact silent_bind (he _) (fun _ => ha _)
        | exact silent_bind (he _) (fun _ => ho _)
        | exact silent_bind (hb _) (fun _ => hb _)
        | exact silent_bind (hb _) (fun _ => hcl _)
        | exact silent_bind (he _) (fun _ => he _)
        | exact silent_bind (hes _) (fun _ => hes _)
        | exact silent_bind (he _) (fun _ => silent_bind (hb _) (fun _ => hb _))
        | exact silent_bind (he _) (fun _ => silent_bind (hb _) (fun _ => he _))
        | exact silent_bind (he _) (fun _ => silent_bind (hes _) (fun _ =>
            silent_bind (he _) (fun _ => hes _)))
    · intro sources
      rw [skipExprs.eq_def]
      apply silent_numbering; apply silent_scope; apply silent_bind (silent_scan _)
      intro _
      cases sources with
      | nil => exact silent_pure _
      | cons source rest => exact silent_bind (he source) (fun _ => hes rest)
    · intro args
      rw [skipHoles.eq_def]
      apply silent_numbering; apply silent_scope; apply silent_bind (silent_scan _)
      intro _
      cases args with
      | nil => exact silent_pure _
      | expr _ _ source rest => exact silent_bind (he source) (fun _ => hh rest)
      | hole _ _ _ rest => exact hh rest
    · intro body
      rw [skipBlock.eq_def]
      apply silent_numbering; apply silent_scope; apply silent_bind (silent_scan _)
      intro _
      cases body <;> first
        | exact silent_pure _
        | exact hb _
        | exact he _
        | exact silent_bind (he _) (fun _ => hb _)
    · intro arms
      rw [skipArms.eq_def]
      apply silent_numbering; apply silent_scope; apply silent_bind (silent_scan _)
      intro _
      cases arms with
      | nil => exact silent_pure _
      | cons alts guard body rest =>
        exact silent_bind (ho guard) (fun _ => silent_bind (hb body) (fun _ => ha rest))
    · intro clauses
      rw [skipClauses.eq_def]
      apply silent_numbering; apply silent_scope; apply silent_bind (silent_scan _)
      intro _
      cases clauses with
      | nil => exact silent_pure _
      | cons _ _ _ body rest _ => exact silent_bind (hb body) (fun _ => hcl rest)
    · intro value
      rw [skipOptional.eq_def]
      cases value with
      | none => exact silent_pure _
      | some source => exact he source

/-- 独立入力の候補は各入力に保存し、親の候補列へは追加しない。 -/
theorem unknownChildren_silent
    (runExpr : AbstractEnv → Expr → Analysis BaseApprox)
    (runBlock : AbstractEnv → Block → Analysis BaseApprox)
    (fuel : Nat) (env : AbstractEnv) (source : Expr) :
    Silent (unknownChildren runExpr runBlock fuel env source) := by
  cases fuel with
  | zero => exact silent_throw _
  | succ fuel =>
    obtain ⟨_, _, _, _, sb, sa, sc, _⟩ := skip_silent fuel
    exact unknownChildren_property (@Silent) (fun value => silent_pure value)
      (fun reason => silent_throw reason)
      (fun _ _ hf hn => silent_bind hf hn) (fun _ h => silent_scope h)
      (fun work => silent_scan work) runExpr runBlock
      (fun env e => independentWith_silent (.expr e) env _)
      (fun env b => independentWith_silent (.block b) env _)
      fuel sb sa sc env source

/-- 一つの番号列に属し、その構文から認定した対象演算に一致する警告。 -/
def LocatedIn (key : OperationKey) (sources : List Expr) (warning : IntervalWarning) : Prop :=
  ∃ source, (warning.key, source) ∈ numberFrom key sources ∧
    WarningOperationSyntax source warning.operation

/-- 親自身の警告は extra で渡し、子の警告はその子の番号列で位置を確かめる。 -/
def Located (work : Analysis α) (sources : List Expr) (extra : IntervalWarning → Prop) : Prop :=
  ∀ limits ctx, Spec work limits ctx (fun _ => True)
    (fun warning => extra warning ∨ LocatedIn ctx.next sources warning) (fun _ => True)

theorem Silent.located {work : Analysis α} (h : Silent work) (sources : List Expr)
    (walk : Walk work sources) (extra : IntervalWarning → Prop) : Located work sources extra := by
  intro limits ctx
  exact ⟨⟨⟨[], by simpa using h limits ctx, by simp⟩,
    (walk.identities limits ctx).mono (by intros; trivial)⟩, by intros; trivial⟩

theorem located_pure (value : α) (extra : IntervalWarning → Prop) : Located (pure value) [] extra :=
  (silent_pure value).located [] (walk_pure value) extra

theorem located_get (extra : IntervalWarning → Prop) :
    Located (get : Analysis Context) [] extra := silent_get.located [] walk_get extra

theorem located_throw (reason : Halt) (sources : List Expr) (extra : IntervalWarning → Prop) :
    Located (throw reason : Analysis α) sources extra :=
  (silent_throw reason).located sources (walk_throw reason sources) extra

theorem located_scan (work : BudgetScan.Scan α) (extra : IntervalWarning → Prop) :
    Located (scan work) [] extra := (silent_scan work).located [] (walk_scan work) extra

theorem LocatedIn.left {key xs warning} (ys : List Expr) (h : LocatedIn key xs warning) :
    LocatedIn key (xs ++ ys) warning := by
  obtain ⟨source, member, operation⟩ := h
  exact ⟨source, by rw [numberFrom_append]; exact List.mem_append_left _ member, operation⟩

theorem LocatedIn.right {key ys warning} (xs : List Expr)
    (h : LocatedIn (advanceKey key xs.length) ys warning) : LocatedIn key (xs ++ ys) warning := by
  obtain ⟨source, member, operation⟩ := h
  exact ⟨source, by rw [numberFrom_append]; exact List.mem_append_right _ member, operation⟩

/-- 停止した前半だけで追加分を閉じ、成功時に限って後半の開始番号を進める。 -/
theorem located_bind {first : Analysis α} {next : α → Analysis β} {xs ys : List Expr}
    {extra : IntervalWarning → Prop} (walk : Walk first xs)
    (hf : Located first xs extra) (hn : ∀ value, Located (next value) ys extra) :
    Located (first >>= next) (xs ++ ys) extra := by
  intro limits ctx
  apply spec_bind (post := fun _ => True)
  · exact spec_mono (hf limits ctx) (by intros; trivial)
      (fun _ h => h.imp_right (LocatedIn.left ys)) (by intros; trivial)
  · intro value middle ok _
    have key := (walk.success ok).1
    exact spec_mono (hn value limits middle) (by intros; trivial)
      (fun _ h => h.imp_right (fun h => LocatedIn.right xs (key ▸ h))) (by intros; trivial)

theorem located_scope {work : Unit → Analysis α} {sources : List Expr} {extra}
    (h : Located (work ()) sources extra) : Located (scope work) sources extra := by
  intro limits ctx
  apply spec_scope
  intro entered ok
  have key : entered.next = ctx.next := by
    simpa only [ok] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1
  simpa only [key] using h limits entered

theorem located_map {work : Analysis α} {sources : List Expr} {extra}
    (walk : Walk work sources) (h : Located work sources extra) (f : α → β) :
    Located (work >>= fun value => pure (f value)) sources extra := by
  simpa only [List.append_nil] using located_bind walk h (fun value => located_pure (f value) extra)

theorem located_bind_empty {work : Analysis α} {next : α → Analysis β} {sources : List Expr} {extra}
    (walk : Walk work sources) (h : Located work sources extra)
    (hn : ∀ value, Located (next value) [] extra) : Located (work >>= next) sources extra := by
  simpa only [List.append_nil] using located_bind walk h hn

theorem located_unsupported (extra : IntervalWarning → Prop) : Located unsupported [] extra := by
  exact (show Silent unsupported from by intro limits ctx; rfl).located [] walk_unsupported extra

/-- 幅付きの葉は番号・警告・独立入力を追加しない。 -/
theorem located_widthLiteral (kind : IntKind) (value : Int) (extra : IntervalWarning → Prop) :
    Located (widthLiteral kind value) [] extra := by
  unfold widthLiteral
  split
  · exact located_pure _ _
  · exact located_unsupported _

/-- 親の identify より後では、親自身を extra に加えて子の列を解析する。 -/
def RootWarning (key : OperationKey) (source : Expr) (warning : IntervalWarning) : Prop :=
  warning.key = key ∧ WarningOperationSyntax source warning.operation

theorem located_identified {source : Expr} {children : List Expr} {next : OperationKey → Analysis α}
    {extra : IntervalWarning → Prop}
    (hn : ∀ key, Located (next key) children (fun w => extra w ∨ RootWarning key source w)) :
    Located (identify source >>= next) (source :: children) extra := by
  intro limits ctx
  apply spec_bind (spec_identify source limits ctx _ _ trivial)
  intro key middle ok same
  have advanced : middle.next = advanceKey ctx.next 1 := (identify_success source limits ctx ok).2.1
  apply spec_mono (hn key limits middle) (by intros; trivial) _ (by intros; trivial)
  intro warning member
  rcases member with (old | root) | child
  · exact Or.inl old
  · right
    exact ⟨source, by simp [numberFrom, root.1, same], root.2⟩
  · right
    simpa only [List.singleton_append] using
      LocatedIn.right [source] (advanced ▸ child)

theorem own_warning_origin (key op type left right lhs rhs warning)
    (member : warning ∈ (baseOwn key op type left right).warnings) :
    RootWarning key (.binary op type lhs rhs) warning := by
  cases type <;> try contradiction
  rename_i base
  cases base <;> simp only [baseOwn, baseOwnKind, IntKind.ofType, analyzeDivMod] at member
  all_goals repeat' split at member
  all_goals simp_all [RootWarning, WarningOperationSyntax, arithmeticOperationAt, baseUnknown, baseBoolean, baseEmpty,
    IntKind.ofType, IntKind.type]


theorem located_own (key op type left right lhs rhs) (extra : IntervalWarning → Prop) :
    Located (own key op type left right) []
      (fun w => extra w ∨ RootWarning key (.binary op type lhs rhs) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (own_warning_origin key op type left right lhs rhs warning member))

theorem negOwn_warning_origin (key child source warning)
    (member : warning ∈ (baseNegOwn key child).warnings) :
    RootWarning key (.neg (.base .integer) source) warning := by
  cases negOwn_warning member
  exact ⟨rfl, rfl⟩

theorem located_negOwn (key child source) (extra : IntervalWarning → Prop) :
    Located (negOwn key child) []
      (fun w => extra w ∨ RootWarning key (.neg (.base .integer) source) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (negOwn_warning_origin key child source warning member))

theorem negOwnTyped_warning_origin (key type child source warning)
    (member : warning ∈ (baseNegOwnTyped key type child).warnings) :
    RootWarning key (.neg type source) warning := by
  cases negOwnTyped_warning member
  exact ⟨rfl, negOwnTyped_warning_located member⟩

theorem located_negOwnTyped (key type child source) (extra : IntervalWarning → Prop) :
    Located (negOwnTyped key type child) []
      (fun w => extra w ∨ RootWarning key (.neg type source) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (negOwnTyped_warning_origin key type child source warning member))

theorem located_branch (env source tested truth run skip sources extra)
    (hr : ∀ inner, Located (run inner) sources extra)
    (hs : Located (skip ()) sources extra) (ws : Walk (skip ()) sources) :
    Located (branch env source tested truth run skip) sources extra := by
  apply located_scope
  simpa only [List.nil_append] using located_bind (walk_scan _) (located_scan _ extra) (fun refined => by
    cases refined with
    | none => exact located_map ws hs (fun _ => baseEmpty)
    | some inner => exact hr inner)

/-- 値を解析しない部分は、任意の警告述語に対して空の追加分を返す。 -/
theorem skip_located (fuel : Nat) (extra : IntervalWarning → Prop) :
    (∀ source, Located (skipExpr fuel source) (surfacePreorder source) extra) ∧
    (∀ source, Located (skipChildren fuel source) (surfacePreorder source).tail extra) ∧
    (∀ sources, Located (skipExprs fuel sources) (preorderExprs sources) extra) ∧
    (∀ args, Located (skipHoles fuel args) (preorderHoles args) extra) ∧
    (∀ body, Located (skipBlock fuel body) (preorderBlock body) extra) ∧
    (∀ arms, Located (skipArms fuel arms) (preorderArms arms) extra) ∧
    (∀ clauses, Located (skipClauses fuel clauses) (preorderClauses clauses) extra) ∧
    (∀ value, Located (skipOptional fuel value)
      (match value with | none => [] | some source => surfacePreorder source) extra) := by
  obtain ⟨se, sc, ses, sh, sb, sa, scl, so⟩ := skip_silent fuel
  obtain ⟨we, wc, wes, wh, wb, wa, wcl, wo⟩ := skip_walk fuel
  exact ⟨fun source => (se source).located _ (we source) extra,
    fun source => (sc source).located _ (wc source) extra,
    fun sources => (ses sources).located _ (wes sources) extra,
    fun args => (sh args).located _ (wh args) extra,
    fun body => (sb body).located _ (wb body) extra,
    fun arms => (sa arms).located _ (wa arms) extra,
    fun clauses => (scl clauses).located _ (wcl clauses) extra,
    fun value => (so value).located _ (wo value) extra⟩

/-- 走査が認定した値だけを継続へ渡す。保存列と次キーは走査で変わらない。 -/
theorem located_scanned {work : BudgetScan.Scan α} {expected : α} {next : α → Analysis β}
    {sources extra} (agrees : BudgetScan.Agrees work expected)
    (valid : Located (next expected) sources extra) : Located (scan work >>= next) sources extra := by
  intro limits ctx
  apply spec_bind (spec_scan_agrees work expected agrees limits ctx _ _)
  intro value middle ok same
  subst value
  have advanced : middle.next = ctx.next := by simpa only [ok] using (scan_preserves_saved work limits ctx).2.2.1
  simpa only [advanced] using valid limits middle

theorem located_selectArguments (run skip target positions sources extra)
    (he : ∀ source, Walk (run source) (surfacePreorder source))
    (hs : ∀ sources, Walk (skip sources) (preorderExprs sources))
    (le : ∀ source, Located (run source) (surfacePreorder source) extra)
    (ls : ∀ sources, Located (skip sources) (preorderExprs sources) extra) :
    Located (selectArguments run skip target positions sources) (preorderExprs sources) extra := by
  rw [selectArguments.eq_def]
  apply located_scope
  apply located_bind (walk_scan _) (located_scan _ _)
  intro _
  cases sources with
  | nil => exact located_pure _ _
  | cons source rest =>
    apply located_bind (he source) (le source)
    intro head
    split
    · exact located_map (hs rest) (ls rest) _
    · exact located_map (walk_selectArguments run skip target positions.tail rest he hs)
        (located_selectArguments run skip target positions.tail rest extra he hs le ls) _

theorem fixedOwn_warning_origin {env key callee labels positions sources binding selected warning}
    (known : rangeCallAt env key (.call callee labels positions sources) = some binding)
    (fixed : fixedBinding binding = true)
    (member : warning ∈ (selectedFixedOwn binding key selected).warnings) :
    RootWarning key (.call callee labels positions sources) warning := by
  obtain ⟨rfl, _⟩ := baseFixedOwn_warning member
  exact ⟨rfl, fixed, (call_binding_identity known).2⟩

theorem located_fixedOwn {env key callee labels positions sources binding selected}
    (known : rangeCallAt env key (.call callee labels positions sources) = some binding)
    (fixed : fixedBinding binding = true) (extra : IntervalWarning → Prop) :
    Located (fixedOwn binding key selected) []
      (fun w => extra w ∨ RootWarning key (.call callee labels positions sources) w) := by
  intro limits ctx
  apply spec_bind (spec_saveWarnings _ limits ctx _ _ ?_)
  · intro value middle _ _
    exact spec_mono (spec_pure _ limits middle _ (fun _ => True)) (by intros; trivial)
      (by intros; assumption) (by intros; trivial)
  · intro warning member
    exact Or.inl (Or.inr (fixedOwn_warning_origin known fixed member))

theorem analysis_located_all (fuel : Nat) :
    (∀ extra env source, Located (expr fuel env source) (surfacePreorder source) extra) ∧
    (∀ extra env left right truth, Located (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right) extra) ∧
    (∀ extra env body, Located (block fuel env body) (preorderBlock body) extra) ∧
    (∀ extra kind env source normal arms, Located (armListKind fuel kind env source normal arms) (preorderArms arms) extra) ∧
    (∀ extra env sources, Located (arguments fuel env sources) (preorderExprs sources) extra) ∧
    (∀ extra env input arms, Located (resultArmList fuel env input arms) (preorderArms arms) extra) := by
  induction fuel with
  | zero => exact ⟨fun _ _ _ => located_throw _ _ _, fun _ _ _ _ _ => located_throw _ _ _,
      fun _ _ _ => located_throw _ _ _, fun _ _ _ _ _ _ => located_throw _ _ _, fun _ _ _ => located_throw _ _ _, fun _ _ _ _ => located_throw _ _ _⟩
  | succ fuel ih =>
    obtain ⟨he, hs, hb, ha, hargs, hr⟩ := ih
    obtain ⟨we, ws, wb, wa, wargs, wr⟩ := analysis_walk_all fuel
    obtain ⟨se, _, _, _, sb, sa, _, so⟩ := skip_walk fuel
    have sc := unknownChildren_walk (expr fuel) (block fuel) we wb fuel
    have lc := fun env source extra =>
      (unknownChildren_silent (expr fuel) (block fuel) fuel env source).located _ (sc env source) extra
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro extra env source
      rw [expr.eq_def]
      apply located_scope
      have split : surfacePreorder source = [source] ++ (surfacePreorder source).tail := by
        rw [surfacePreorder_children]; rfl
      rw [split]
      apply located_identified
      intro key
      apply located_bind (walk_scan _) (located_scan _ _)
      intro _
      cases source
      case literal value =>
        cases value <;> first
          | exact located_pure _ _
          | exact located_widthLiteral _ _ _
          | exact located_bind_empty (sc env _) (lc env _ _) (fun _ => located_unsupported _)
      case neg type child =>
        simp only [surfacePreorder]
        split
        · exact located_bind_empty (we env child) (he _ env child) (fun value =>
            located_map (walk_negOwnTyped key type value) (located_negOwnTyped key type value child extra) _)
        · simpa only [surfacePreorder, List.tail_cons] using
            located_bind_empty (sc env (.neg type child)) (lc env (.neg type child) _) (fun _ => located_unsupported _)
      case binary op type left right =>
        simp only [surfacePreorder]
        split
        · apply located_bind (we env left) (he _ env left)
          intro lhs
          split
          · exact located_map (se right) ((skip_located fuel _).1 right) _
          · apply located_bind_empty (we env right) (he _ env right)
            intro rhs
            split
            · exact located_pure _ _
            · exact located_map (walk_own _ _ _ _ _) (located_own key op type lhs rhs left right extra) _
        · simpa only [surfacePreorder, List.tail_cons] using
            located_bind_empty (sc env (.binary op type left right))
              (lc env (.binary op type left right) _) (fun _ => located_unsupported _)
      case call callee labels positions sources =>
        simp only [surfacePreorder]
        apply located_scanned (BudgetScan.rangeCall_agrees env key _)
        cases found : rangeCallAt env key (.call callee labels positions sources) with
        | none =>
          simpa only [surfacePreorder, List.tail_cons, List.append_eq] using
            located_bind_empty (sc env (.call callee labels positions sources))
              (lc env (.call callee labels positions sources) _) (fun _ => located_unsupported _)
        | some binding =>
          apply located_bind (se callee) ((skip_located fuel _).1 callee)
          intro _
          split
          · rename_i fixed
            exact located_bind_empty
              (walk_selectArguments _ _ _ _ _ (we env) ((skip_walk fuel).2.2.1))
              (located_selectArguments _ _ _ _ _ _ (we env) ((skip_walk fuel).2.2.1)
                (he _ env) ((skip_located fuel _).2.2.1))
              (fun selected => located_map (walk_fixedOwn binding key selected)
                (located_fixedOwn found fixed extra) _)
          · apply located_bind_empty (wargs env sources) (hargs _ env sources)
            intro values
            exact located_bind (walk_scan _) (located_scan _ _) (fun _ => located_pure _ _)
      case «local» index =>
        apply located_bind (walk_scan _) (located_scan _ _)
        intro slot
        cases slot with
        | none => exact located_pure _ _
        | some slot => cases slot <;> first
          | exact located_pure _ _
          | exact located_pure _ _
      case matchE type source arms =>
        simp only [surfacePreorder]
        apply located_bind (we env source) (he _ env source)
        intro tested
        split
        · exact located_map (sa arms) ((skip_located fuel _).2.2.2.2.2.1 arms) _
        · apply located_bind (walk_scan _) (located_scan _ _)
          intro known
          cases known with
          | some origin => exact located_map (wr env _ arms) (hr _ env _ arms) _
          | none =>
            cases selected : tested.matchKind with
            | some kind =>
              exact located_map (wa kind env source (tested.rangeKind kind) arms)
                (ha _ kind env source (tested.rangeKind kind) arms) _
            | none =>
              exact located_bind_empty (sa arms) ((skip_located fuel _).2.2.2.2.2.1 arms)
                (fun _ => located_map walk_unsupported (located_unsupported _) _)
      case ite condition yes no =>
        simp only [surfacePreorder, List.append_assoc]
        apply located_bind (we env condition) (he _ env condition)
        intro tested
        apply located_bind (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner yes) (sb yes))
          (located_branch _ _ _ _ _ _ _ _ (fun inner => hb _ inner yes)
            ((skip_located fuel _).2.2.2.2.1 yes) (sb yes))
        intro positive
        exact located_map (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner no) (sb no))
          (located_branch _ _ _ _ _ _ _ _ (fun inner => hb _ inner no)
            ((skip_located fuel _).2.2.2.2.1 no) (sb no)) _
      case elseIf condition yes no =>
        simp only [surfacePreorder, List.append_assoc]
        apply located_bind (we env condition) (he _ env condition)
        intro tested
        apply located_bind (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner yes) (sb yes))
          (located_branch _ _ _ _ _ _ _ _ (fun inner => hb _ inner yes)
            ((skip_located fuel _).2.2.2.2.1 yes) (sb yes))
        intro positive
        exact located_map (walk_branch _ _ _ _ _ _ _ (fun inner => we inner no) (se no))
          (located_branch _ _ _ _ _ _ _ _ (fun inner => he _ inner no)
            ((skip_located fuel _).1 no) (se no)) _
      case ifOnly condition yes =>
        simp only [surfacePreorder]
        apply located_bind (we env condition) (he _ env condition)
        intro tested
        apply located_bind_empty (walk_branch _ _ _ _ _ _ _ (fun inner => wb inner yes) (sb yes))
          (located_branch _ _ _ _ _ _ _ _ (fun inner => hb _ inner yes)
            ((skip_located fuel _).2.2.2.2.1 yes) (sb yes))
        intro positive
        exact located_map (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure _) (walk_pure ()))
          (located_branch _ _ _ _ _ _ [] _ (fun _ => located_pure _ _) (located_pure _ _) (walk_pure ())) _
      all_goals first
        | exact located_bind_empty (sc env _) (lc env _ _) (fun _ => located_unsupported _)
        | exact located_pure _ _
        | exact located_widthLiteral _ _ _
        | exact located_bind (walk_scan _) (located_scan _ _) (fun _ => located_pure _ _)
        | exact he _ _ _
        | exact located_map (we _ _) (he _ _ _) _
        | exact hb _ _ _
        | exact hs _ _ _ _ _
    · intro extra env left right truth
      rw [shortCircuit]
      apply located_bind (we env left) (he _ env left)
      intro tested
      apply located_bind_empty (walk_branch _ _ _ _ _ _ _ (fun inner => we inner right) (se right))
        (located_branch _ _ _ _ _ _ _ _ (fun inner => he _ inner right)
          ((skip_located fuel _).1 right) (se right))
      intro continued
      apply located_bind (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure _) (walk_pure ()))
        (located_branch _ _ _ _ _ _ [] _ (fun _ => located_pure _ _) (located_pure _ _) (walk_pure ()))
      intro shorted
      exact located_pure _ _
    · intro extra env body
      rw [block.eq_def]
      apply located_scope
      apply located_bind (walk_scan _) (located_scan _ _)
      intro _
      cases body with
      | empty => exact located_pure _ _
      | builderBind kind rest => exact located_bind (walk_scan _) (located_scan _ _) (fun inner => hb _ inner rest)
      | last source => exact he _ env source
      | lastBind _ _ source | lastDiscard source | lastPat _ _ _ source =>
        exact located_map (we env source) (he _ env source) _
      | bind kind type source rest =>
        apply located_bind (walk_get) (located_get _)
        intro start
        apply located_bind (we env source) (he _ env source)
        intro head
        split
        · exact located_map (sb rest) ((skip_located fuel _).2.2.2.2.1 rest) _
        · exact located_bind (walk_scan _) (located_scan _ _) (fun inner =>
            located_map (wb inner rest) (hb _ inner rest) _)
      | discard source rest | seq source rest =>
        apply located_bind (we env source) (he _ env source)
        intro head
        split
        · exact located_map (sb rest) ((skip_located fuel _).2.2.2.2.1 rest) _
        · exact located_map (wb env rest) (hb _ env rest) _
      | bindPat _ pattern type source rest =>
        apply located_bind (we env source) (he _ env source)
        intro head
        split
        · exact located_map (sb rest) ((skip_located fuel _).2.2.2.2.1 rest) _
        · exact located_bind (walk_scan _) (located_scan _ _) (fun inner =>
            located_map (wb inner rest) (hb _ inner rest) _)
    · intro extra kind env source normal arms
      rw [armListKind.eq_def]
      apply located_scope
      apply located_bind (walk_scan _) (located_scan _ _)
      intro _
      cases arms with
      | nil => exact located_pure _ _
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [preorderArms, List.nil_append]
          apply located_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            cases inner with
            | none => exact walk_bind (so none) (fun _ => walk_map (sb body) _)
            | some inner => exact wb inner body
          · apply located_scope
            apply located_bind (walk_scan _) (located_scan _ _)
            intro inner
            cases inner with
            | none =>
              exact located_bind (so none) ((skip_located fuel _).2.2.2.2.2.2.2 none)
                (fun _ => located_map (sb body) ((skip_located fuel _).2.2.2.2.1 body) _)
            | some inner => exact hb _ inner body
          · intro first
            exact located_map (wa kind env source normal rest) (ha _ kind env source normal rest) _
        | some condition =>
          simp only [preorderArms]
          apply located_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            cases inner with
            | none => exact walk_bind (so (some condition)) (fun _ => walk_map (sb body) _)
            | some inner =>
              apply walk_bind (we inner condition)
              intro tested
              exact walk_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body)) _
          · apply located_scope
            apply located_bind (walk_scan _) (located_scan _ _)
            intro inner
            cases inner with
            | none =>
              exact located_bind (so (some condition)) ((skip_located fuel _).2.2.2.2.2.2.2 (some condition))
                (fun _ => located_map (sb body) ((skip_located fuel _).2.2.2.2.1 body) _)
            | some inner =>
              apply located_bind (we inner condition) (he _ inner condition)
              intro tested
              exact located_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body))
                (located_branch _ _ _ _ _ _ _ _ (fun refined => hb _ refined body)
                  ((skip_located fuel _).2.2.2.2.1 body) (sb body)) _
          · intro first
            exact located_map (wa kind env source normal rest) (ha _ kind env source normal rest) _


    · intro extra env sources
      rw [arguments.eq_def]
      apply located_scope
      apply located_bind (walk_scan _) (located_scan _ _)
      intro _
      cases sources with
      | nil => exact located_pure _ _
      | cons source rest =>
        simp only [preorderExprs]
        apply located_bind (we env source) (he _ env source)
        intro head
        split
        · exact located_map ((skip_walk fuel).2.2.1 rest) ((skip_located fuel _).2.2.1 rest) _
        · exact located_map (wargs env rest) (hargs _ env rest) _
    · intro extra env input arms
      rw [resultArmList.eq_def]
      apply located_scope
      apply located_bind (walk_scan _) (located_scan _ _)
      intro _
      cases arms with
      | nil => exact located_pure _ _
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [preorderArms, List.nil_append]
          apply located_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            exact wb inner body
          · apply located_scope
            apply located_bind (walk_scan _) (located_scan _ _)
            intro inner
            exact hb _ inner body
          · intro first
            exact located_map (wr env input rest) (hr _ env input rest) _
        | some condition =>
          simp only [preorderArms]
          apply located_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            apply walk_bind (we inner condition)
            intro tested
            exact walk_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body)) _
          · apply located_scope
            apply located_bind (walk_scan _) (located_scan _ _)
            intro inner
            apply located_bind (we inner condition) (he _ inner condition)
            intro tested
            exact located_map (walk_branch _ _ _ _ _ _ _ (fun refined => wb refined body) (sb body))
              (located_branch _ _ _ _ _ _ _ _ (fun refined => hb _ refined body)
                ((skip_located fuel _).2.2.2.2.1 body) (sb body)) _
          · intro first
            exact located_map (wr env input rest) (hr _ env input rest) _

theorem analysis_located_kind (fuel : Nat) :
    (∀ extra env source, Located (expr fuel env source) (surfacePreorder source) extra) ∧
    (∀ extra env left right truth, Located (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right) extra) ∧
    (∀ extra env body, Located (block fuel env body) (preorderBlock body) extra) ∧
    (∀ extra kind env source normal arms, Located (armListKind fuel kind env source normal arms) (preorderArms arms) extra) := by
  obtain ⟨he, hs, hb, ha, _, _⟩ := analysis_located_all fuel
  exact ⟨he, hs, hb, ha⟩

/-- Integer64 の既存の入口と言明を保つ。 -/
theorem analysis_located (fuel : Nat) :
    (∀ extra env source, Located (expr fuel env source) (surfacePreorder source) extra) ∧
    (∀ extra env left right truth, Located (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right) extra) ∧
    (∀ extra env body, Located (block fuel env body) (preorderBlock body) extra) ∧
    (∀ extra env source normal arms, Located (armList fuel env source normal arms) (preorderArms arms) extra)  := by
  obtain ⟨he, hs, hb, ha⟩ := analysis_located_kind fuel
  exact ⟨he, hs, hb, fun extra => ha extra .integer64⟩

/-- 既存の警告に現在の部分木の所属を要求せず、新しく追加した分だけを結論する。 -/
theorem expr_located (fuel : Nat) (env : AbstractEnv) (source : Expr) (limits : Limits) (ctx : Context) :
    ListExtension (fun warning => ∃ node, (warning.key, node) ∈ numbered ctx.next source ∧
      WarningOperationSyntax node warning.operation)
      ctx.warningsRev (expr fuel env source limits ctx).2.warningsRev := by
  have h := ((analysis_located fuel).1 (fun _ => False) env source limits ctx).1.1
  exact h.mono (fun _ member => by
    simpa only [LocatedIn, numberFrom_numbered] using member.resolve_left id)

/-- 短絡の左右の範囲に属する追加警告。到達しない右辺の skip は警告を作らない。 -/
theorem shortCircuit_located (fuel : Nat) (env : AbstractEnv) (left right : Expr) (truth : Bool)
    (limits : Limits) (ctx : Context) :
    ListExtension (LocatedIn ctx.next (surfacePreorder left ++ surfacePreorder right))
      ctx.warningsRev (shortCircuit fuel env left right truth limits ctx).2.warningsRev :=
  ((analysis_located fuel).2.1 (fun _ => False) env left right truth limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

/-- Block の追加警告は、容器が番号を消費しない先行順に対応する。 -/
theorem block_located (fuel : Nat) (env : AbstractEnv) (body : Block) (limits : Limits) (ctx : Context) :
    ListExtension (LocatedIn ctx.next (preorderBlock body))
      ctx.warningsRev (block fuel env body limits ctx).2.warningsRev :=
  ((analysis_located fuel).2.2.1 (fun _ => False) env body limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

/-- 腕列の追加警告は、guard・本体・後続腕を並べた範囲に対応する。 -/
theorem armList_located (fuel : Nat) (env : AbstractEnv) (source : Expr) (normal : Interval)
    (arms : Arms) (limits : Limits) (ctx : Context) :
    ListExtension (LocatedIn ctx.next (preorderArms arms))
      ctx.warningsRev (armList fuel env source normal arms limits ctx).2.warningsRev :=
  ((analysis_located fuel).2.2.2 (fun _ => False) env source normal arms limits ctx).1.1.mono
    (fun _ member => member.resolve_left id)

end Benitoite.Interval.BudgetAnalysis
