import Benitoite.Interval.BudgetProof

/-!
# 予算付き解析の先行順の保存

成否によらず保存した対応を先行順の接頭辞とし、完走時だけ全体との一致を得る。
実行時の解析に平坦化や事前走査を追加しない。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 証明用の列への連続した番号付け。実行する解析からは呼ばない。 -/
def numberFrom (key : OperationKey) : List Expr → List (OperationKey × Expr)
  | [] => []
  | source :: rest => (key, source) :: numberFrom (advanceKey key 1) rest

@[simp] theorem advanceKey_zero (key : OperationKey) : advanceKey key 0 = key := by
  cases key; rfl

@[simp] theorem advanceKey_add (key : OperationKey) (a b : Nat) :
    advanceKey (advanceKey key a) b = advanceKey key (a + b) := by
  simp [advanceKey, Nat.add_assoc]

theorem numberFrom_append (key : OperationKey) (xs ys : List Expr) :
    numberFrom key (xs ++ ys) =
      numberFrom key xs ++ numberFrom (advanceKey key xs.length) ys := by
  induction xs generalizing key with
  | nil => simp [numberFrom]
  | cons x xs ih => simp [numberFrom, ih, Nat.add_comm]

/-- 入力の対応列を保ち、今回保存した分だけを先行順の接頭辞とする。 -/
def Traversal (sources : List Expr) (before : Context) (outcome : Except Halt α)
    (after : Context) : Prop :=
  ∃ visited rest, sources = visited ++ rest ∧
    after.identitiesRev = (numberFrom before.next visited).reverse ++ before.identitiesRev ∧
    after.next = advanceKey before.next visited.length ∧
    (∀ value, outcome = .ok value → rest = [])

/-- 任意の予算と入力 Context に対する番号走査の契約。 -/
def Walk (work : Analysis α) (sources : List Expr) : Prop :=
  ∀ limits ctx, Traversal sources ctx (work limits ctx).1 (work limits ctx).2

theorem traversal_empty {before after : Context} {outcome : Except Halt α}
    (ids : after.identitiesRev = before.identitiesRev) (next : after.next = before.next) :
    Traversal [] before outcome after :=
  ⟨[], [], rfl, ids, by simpa using next, by intros; rfl⟩

theorem walk_pure (value : α) : Walk (pure value) [] := by
  intro limits ctx
  exact traversal_empty rfl rfl

/-- 深さ0や確保の拒否で、まだ訪問していない部分を消費済みにしない。 -/
theorem walk_get : Walk (get : Analysis Context) [] := by
  intro limits ctx
  exact traversal_empty rfl rfl

theorem walk_throw (reason : Halt) (sources : List Expr) :
    Walk (throw reason : Analysis α) sources := by
  intro limits ctx
  exact ⟨[], sources, rfl, rfl, (advanceKey_zero _).symm, by intro value ok; cases ok⟩

theorem walk_scan (work : BudgetScan.Scan α) : Walk (scan work) [] := by
  intro limits ctx
  have h := scan_preserves_saved work limits ctx
  exact traversal_empty h.2.1 h.2.2.1

/-- 前半で止まれば後半は未訪問。成功した前半だけ全長を使って後半を接続する。 -/
theorem walk_bind {first : Analysis α} {next : α → Analysis β} {xs ys : List Expr}
    (hf : Walk first xs) (hn : ∀ value, Walk (next value) ys) :
    Walk (first >>= next) (xs ++ ys) := by
  intro limits ctx
  have h := hf limits ctx
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases run : first limits ctx with
  | mk outcome middle =>
    rw [run] at h
    obtain ⟨visited, rest, input, ids, key, complete⟩ := h
    dsimp only at ids key complete
    cases outcome with
    | error reason =>
      simp only [ExceptT.bindCont, pure, StateT.pure]
      exact ⟨visited, rest ++ ys, by simp [input, List.append_assoc], ids, key,
        by intro value ok; cases ok⟩
    | ok value =>
      simp only [ExceptT.bindCont]
      have empty := complete value rfl
      have full : xs = visited := by simpa [empty] using input
      subst visited
      obtain ⟨tail, rest, input', ids', key', complete'⟩ := hn value limits middle
      refine ⟨xs ++ tail, rest, by simp [input', List.append_assoc], ?_, ?_, complete'⟩
      · simp [numberFrom_append, List.reverse_append, List.append_assoc, ids', ids, key]
      · simp [key', key]

theorem walk_scope {work : Unit → Analysis α} {sources : List Expr}
    (h : Walk (work ()) sources) : Walk (scope work) sources := by
  intro limits ctx
  have preserved := scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx
  unfold scope
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    rw [run] at preserved
    dsimp only at preserved
    cases outcome with
    | error reason =>
      exact ⟨[], sources, rfl, preserved.2.1, by simpa using preserved.2.2.1,
        by intro value ok; cases ok⟩
    | ok value =>
      have inner := h limits entered
      cases body : work () limits entered with
      | mk result final =>
        simpa only [body, Traversal, preserved.2.1, preserved.2.2.1] using inner

theorem walk_numbering {work : Unit → Analysis α} {sources : List Expr}
    (h : Walk (work ()) sources) : Walk (numbering work) sources := by
  intro limits ctx
  obtain ⟨visited, rest, input, ids, key, complete⟩ := h limits ctx
  refine ⟨visited, rest, input, by simpa only [numbering_context] using ids,
    by simpa only [numbering_context] using key, ?_⟩
  intro value ok
  apply complete value
  unfold numbering at ok
  cases run : work () limits ctx with
  | mk result final =>
    cases result with
    | ok result => simpa only [run] using ok
    | error reason =>
      cases reason with
      | depth => simp [run] at ok
      | budget reason => cases reason <;> simp [run] at ok

/-- 環境の忘却と保存への移行では、出現の番号と対応を消費しない。 -/
theorem prepareIndependent_walk (env : AbstractEnv) : Walk (prepareIndependent env) [] := by
  intro limits ctx
  unfold prepareIndependent
  cases run : scan (BudgetScan.forgetEnv env) limits ctx with
  | mk result final =>
    have h := walk_scan (BudgetScan.forgetEnv env) limits ctx
    rw [run] at h
    cases result <;> simpa only [Traversal] using h

/-- 独立入力も同じ先行順を一度だけ辿る。停止時には取得済みの接頭辞を残す。 -/
theorem captureIndependent_walk (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (sources : List Expr)
    (walking : ∀ initial, Walk (work initial) sources) :
    Walk (captureIndependent input env work) sources := by
  intro limits parent
  unfold captureIndependent
  dsimp only
  cases prepared : prepareIndependent env limits { parent with warningsRev := [], unsupported := false } with
  | mk outcome ready =>
    have h := prepareIndependent_walk env limits { parent with warningsRev := [], unsupported := false }
    rw [prepared] at h
    obtain ⟨visited, rest, sizes, ids, key, complete⟩ := h
    have empty : visited = [] := by
      cases visited with
      | nil => rfl
      | cons head tail => cases sizes
    subst visited
    dsimp only at ids key
    simp only [numberFrom, List.reverse_nil, List.nil_append] at ids
    simp only [List.length_nil, advanceKey_zero] at key
    dsimp only
    cases outcome with
    | error reason =>
      exact ⟨[], sources, rfl, ids, by simpa using key, by intro value ok; cases ok⟩
    | ok initial =>
      cases run : work initial limits ready with
      | mk result final =>
        simp only [run]
        have traversed := walking initial limits ready
        rw [run] at traversed
        obtain ⟨visited, rest, sizes, saved, next, full⟩ := traversed
        refine ⟨visited, rest, sizes, ?_, ?_, ?_⟩
        · simpa only [key, ids] using saved
        · simpa only [key] using next
        · intro value ok
          cases result with
          | error reason => cases ok
          | ok approx => exact full approx rfl

/-- 保存枠と作業枠は番号を増やさない。内部走査だけが出現を一度ずつ消費する。 -/
theorem independentWith_walk (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (sources : List Expr)
    (walking : ∀ initial, Walk (work initial) sources) :
    Walk (independentWith input env work) sources := by
  unfold independentWith
  apply walk_scope
  simpa only [List.nil_append] using walk_bind (walk_scan _)
    (fun _ => captureIndependent_walk input env work sources walking)

theorem walk_identify (source : Expr) : Walk (identify source) [source] := by
  intro limits ctx
  cases run : identify source limits ctx with
  | mk outcome final =>
    cases outcome with
    | ok value =>
      obtain ⟨_, key, _, ids, _⟩ := identify_success source limits ctx run
      exact ⟨[source], [], rfl, by simpa [numberFrom] using ids,
        by simpa [advanceKey] using key, by intros; rfl⟩
    | error reason =>
      obtain ⟨_, ids, key, _⟩ := identify_stopped source limits ctx run
      exact ⟨[], [source], rfl, ids, by simpa using key, by intro value ok; cases ok⟩

theorem walk_saveWarnings (warnings : List IntervalWarning) : Walk (saveWarnings warnings) [] := by
  intro limits ctx
  obtain ⟨_, _, _, _, ids, key, _, _⟩ := saveWarnings_progress warnings limits ctx
  exact traversal_empty ids key

theorem walk_unsupported : Walk unsupported [] := by
  intro limits ctx
  exact traversal_empty rfl rfl

/-- 幅付きの葉は番号・警告・独立入力を追加しない。 -/
theorem walk_widthLiteral (kind : IntKind) (value : Int) :
    Walk (widthLiteral kind value) [] := by
  unfold widthLiteral
  split
  · exact walk_pure _
  · exact walk_unsupported

theorem walk_own (key : OperationKey) (op : BinOp) (type : Ty) (left right : BaseApprox) :
    Walk (own key op type left right) [] := by
  exact walk_bind (walk_saveWarnings _) (fun _ => walk_pure _)

theorem walk_negOwn (key child) : Walk (negOwn key child) [] := by
  exact walk_bind (walk_saveWarnings _) (fun _ => walk_pure _)

theorem walk_negOwnTyped (key type child) : Walk (negOwnTyped key type child) [] := by
  exact walk_bind (walk_saveWarnings _) (fun _ => walk_pure _)

theorem walk_branch (env : AbstractEnv) (source : Expr) (tested : BaseApprox) (truth : Bool)
    (run : AbstractEnv → Analysis BaseApprox) (skip : Unit → Analysis Unit) (sources : List Expr)
    (hr : ∀ inner, Walk (run inner) sources) (hs : Walk (skip ()) sources) :
    Walk (branch env source tested truth run skip) sources := by
  apply walk_scope
  apply walk_bind (walk_scan _)
  intro refined
  cases refined with
  | none => simpa only [List.append_nil] using walk_bind hs (fun _ => walk_pure baseEmpty)
  | some inner => exact hr inner

/-- 全 skip 群の成否に共通する先行順の契約。 -/
theorem skip_walk (fuel : Nat) :
    (∀ source, Walk (skipExpr fuel source) (surfacePreorder source)) ∧
    (∀ source, Walk (skipChildren fuel source) (surfacePreorder source).tail) ∧
    (∀ sources, Walk (skipExprs fuel sources) (preorderExprs sources)) ∧
    (∀ args, Walk (skipHoles fuel args) (preorderHoles args)) ∧
    (∀ body, Walk (skipBlock fuel body) (preorderBlock body)) ∧
    (∀ arms, Walk (skipArms fuel arms) (preorderArms arms)) ∧
    (∀ clauses, Walk (skipClauses fuel clauses) (preorderClauses clauses)) ∧
    (∀ value, Walk (skipOptional fuel value)
      (match value with | none => [] | some source => surfacePreorder source)) := by
  induction fuel with
  | zero => exact ⟨fun _ => walk_throw _ _, fun _ => walk_throw _ _,
      fun _ => walk_throw _ _, fun _ => walk_throw _ _, fun _ => walk_throw _ _,
      fun _ => walk_throw _ _, fun _ => walk_throw _ _, fun _ => walk_throw _ _⟩
  | succ fuel ih =>
    obtain ⟨he, hc, hes, hh, hb, ha, hcl, ho⟩ := ih
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro source
      rw [skipExpr]
      apply walk_numbering
      apply walk_scope
      have h := walk_bind (walk_identify source) (fun _ => hc source)
      simpa only [List.singleton_append, surfacePreorder_children, List.tail_cons] using h
    · intro source
      cases source <;> simp only [skipChildren, surfacePreorder, List.tail_cons, List.append_assoc]
      all_goals try (rename_i message; cases message <;>
        simp only [surfacePreorder, List.tail_cons])
      all_goals first
        | exact walk_pure ()
        | exact hes _
        | exact he _
        | exact hb _
        | exact hh _
        | exact walk_bind (he _) (fun _ => hes _)
        | exact walk_bind (he _) (fun _ => hh _)
        | exact walk_bind (he _) (fun _ => hb _)
        | exact walk_bind (he _) (fun _ => ha _)
        | exact walk_bind (he _) (fun _ => ho _)
        | exact walk_bind (hb _) (fun _ => hb _)
        | exact walk_bind (hb _) (fun _ => hcl _)
        | exact walk_bind (he _) (fun _ => he _)
        | exact walk_bind (hes _) (fun _ => hes _)
        | exact walk_bind (he _) (fun _ => walk_bind (hb _) (fun _ => hb _))
        | exact walk_bind (he _) (fun _ => walk_bind (hb _) (fun _ => he _))
        | exact walk_bind (he _) (fun _ => walk_bind (hes _) (fun _ =>
            walk_bind (he _) (fun _ => hes _)))
    · intro sources
      rw [skipExprs.eq_def]
      apply walk_numbering
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases sources with
      | nil => exact walk_pure ()
      | cons source rest => exact walk_bind (he source) (fun _ => hes rest)
    · intro args
      rw [skipHoles.eq_def]
      apply walk_numbering
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases args with
      | nil => exact walk_pure ()
      | expr _ _ source rest => exact walk_bind (he source) (fun _ => hh rest)
      | hole _ _ _ rest => exact hh rest
    · intro body
      rw [skipBlock.eq_def]
      apply walk_numbering
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases body <;> first
        | exact walk_pure ()
        | exact hb _
        | exact he _
        | exact walk_bind (he _) (fun _ => hb _)
    · intro arms
      rw [skipArms.eq_def]
      apply walk_numbering
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases arms with
      | nil => exact walk_pure ()
      | cons alts guard body rest =>
        cases guard <;> simpa only [preorderArms, List.append_assoc] using
          walk_bind (ho _) (fun _ => walk_bind (hb body) (fun _ => ha rest))
    · intro clauses
      rw [skipClauses.eq_def]
      apply walk_numbering
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases clauses with
      | nil => exact walk_pure ()
      | cons _ _ _ body rest _ => exact walk_bind (hb body) (fun _ => hcl rest)
    · intro value
      rw [skipOptional.eq_def]
      cases value with
      | none => exact walk_pure ()
      | some source => exact he source

/-- 容器自身に番号を与えず、各子の走査を宣言順に合成する。 -/
theorem childContainers_walk (visit : Expr → Analysis Unit)
    (hv : ∀ e, Walk (visit e) (surfacePreorder e)) (fuel : Nat) :
    (∀ es, Walk (childExprs visit fuel es) (preorderExprs es)) ∧
    (∀ args, Walk (childHoles visit fuel args) (preorderHoles args)) ∧
    (∀ value, Walk (childOptional visit fuel value)
      (match value with | none => [] | some e => surfacePreorder e)) := by
  induction fuel with
  | zero => exact ⟨fun _ => walk_throw _ _, fun _ => walk_throw _ _, fun _ => walk_throw _ _⟩
  | succ fuel ih =>
    refine ⟨?_, ?_, ?_⟩
    · intro es
      rw [childExprs.eq_def]
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro ignored
      cases es with
      | nil => exact walk_pure _
      | cons e rest => exact walk_bind (hv e) (fun _ => ih.1 rest)
    · intro args
      rw [childHoles.eq_def]
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro ignored
      cases args with
      | nil => exact walk_pure _
      | expr _ _ e rest => exact walk_bind (hv e) (fun _ => ih.2.1 rest)
      | hole _ _ _ rest => exact ih.2.1 rest
    · intro value
      cases value with
      | none => exact walk_pure _
      | some e => exact hv e

/-- 独立解析は skip と同じ先行順を一度だけ辿り、停止時も接頭辞を残す。 -/
theorem unknownChildren_walk
    (runExpr : AbstractEnv → Expr → Analysis BaseApprox)
    (runBlock : AbstractEnv → Block → Analysis BaseApprox)
    (he : ∀ env e, Walk (runExpr env e) (surfacePreorder e))
    (hb : ∀ env b, Walk (runBlock env b) (preorderBlock b))
    (fuel : Nat) (env : AbstractEnv) (source : Expr) :
    Walk (unknownChildren runExpr runBlock fuel env source) (surfacePreorder source).tail := by
  cases fuel with
  | zero => exact walk_throw _ _
  | succ fuel =>
    have ie := fun env e => independentWith_walk (.expr e) env (fun initial => runExpr initial e)
      (surfacePreorder e) (fun initial => he initial e)
    have ib := fun env b => independentWith_walk (.block b) env (fun initial => runBlock initial b)
      (preorderBlock b) (fun initial => hb initial b)
    obtain ⟨hes, hh, ho⟩ := childContainers_walk
      (fun e => independentWith (.expr e) env (fun initial => runExpr initial e)) (ie env) fuel
    obtain ⟨_, _, _, _, sb, sa, sc, _⟩ := skip_walk fuel
    cases source <;> simp only [unknownChildren, surfacePreorder, List.tail_cons, List.append_assoc]
    all_goals try (rename_i message; cases message <;> simp only [surfacePreorder, List.tail_cons])
    all_goals first
      | with_reducible exact walk_pure _
      | with_reducible exact ie _ _
      | with_reducible exact ib _ _
      | with_reducible exact hes _
      | with_reducible exact hh _
      | with_reducible exact sb _
      | with_reducible exact walk_bind (ie _ _) (fun _ => hes _)
      | with_reducible exact walk_bind (ie _ _) (fun _ => hh _)
      | with_reducible exact walk_bind (ie _ _) (fun _ => ib _ _)
      | with_reducible exact walk_bind (ie _ _) (fun _ => sa _)
      | with_reducible exact walk_bind (ie _ _) (fun _ => ho _)
      | with_reducible exact walk_bind (ib _ _) (fun _ => sb _)
      | with_reducible exact walk_bind (ib _ _) (fun _ => sc _)
      | with_reducible exact walk_bind (ie _ _) (fun _ => ie _ _)
      | with_reducible exact walk_bind (hes _) (fun _ => hes _)
      | with_reducible exact walk_bind (ie _ _) (fun _ => walk_bind (ib _ _) (fun _ => ib _ _))
      | with_reducible exact walk_bind (ie _ _) (fun _ => walk_bind (ib _ _) (fun _ => ie _ _))
      | with_reducible exact walk_bind (ie _ _) (fun _ => walk_bind (hes _) (fun _ =>
          walk_bind (ie _ _) (fun _ => hes _)))
      | with_reducible exact walk_bind (ie _ _) (fun _ => walk_bind (walk_scan _) (fun inner => ib inner _))

/-- 戻り値だけの変換は番号を消費しない。 -/
theorem walk_map {work : Analysis α} {sources : List Expr} (h : Walk work sources) (f : α → β) :
    Walk (work >>= fun value => pure (f value)) sources := by
  simpa only [List.append_nil] using walk_bind h (fun value => walk_pure (f value))

/-- 後処理で番号を使わない場合、訪問列をそのまま保つ。 -/
theorem walk_bind_empty {work : Analysis α} {sources : List Expr} {next : α → Analysis β}
    (h : Walk work sources) (hn : ∀ value, Walk (next value) []) :
    Walk (work >>= next) sources := by
  simpa only [List.append_nil] using walk_bind h hn

theorem walk_fixedOwn (binding key selected) : Walk (fixedOwn binding key selected) [] := by
  unfold fixedOwn
  exact walk_bind (walk_saveWarnings _) (fun _ => walk_pure _)

/-- 契約位置の選択でも、途中停止と Bottom の後の番号を区別する。 -/
theorem walk_selectArguments (run skip target positions sources)
    (he : ∀ source, Walk (run source) (surfacePreorder source))
    (hs : ∀ sources, Walk (skip sources) (preorderExprs sources)) :
    Walk (selectArguments run skip target positions sources) (preorderExprs sources) := by
  rw [selectArguments.eq_def]
  apply walk_scope
  apply walk_bind (walk_scan _)
  intro _
  cases sources with
  | nil => exact walk_pure _
  | cons source rest =>
    apply walk_bind (he source)
    intro head
    split
    · exact walk_map (hs rest) _
    · exact walk_map (walk_selectArguments run skip target positions.tail rest he hs) _

/-- 実際に値を解析する部分と skip する部分は、同じ先行順を共有する。 -/
theorem analysis_walk_all (fuel : Nat) :
    (∀ env source, Walk (expr fuel env source) (surfacePreorder source)) ∧
    (∀ env left right truth, Walk (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right)) ∧
    (∀ env body, Walk (block fuel env body) (preorderBlock body)) ∧
    (∀ kind env source normal arms, Walk (armListKind fuel kind env source normal arms) (preorderArms arms)) ∧
    (∀ env sources, Walk (arguments fuel env sources) (preorderExprs sources)) ∧
    (∀ env input arms, Walk (resultArmList fuel env input arms) (preorderArms arms)) := by
  induction fuel with
  | zero => exact ⟨fun _ _ => walk_throw _ _, fun _ _ _ _ => walk_throw _ _,
      fun _ _ => walk_throw _ _, fun _ _ _ _ _ => walk_throw _ _, fun _ _ => walk_throw _ _, fun _ _ _ => walk_throw _ _⟩
  | succ fuel ih =>
    obtain ⟨he, hs, hb, ha, hargs, hr⟩ := ih
    obtain ⟨se, _, _, _, sb, sa, _, so⟩ := skip_walk fuel
    have sc := unknownChildren_walk (expr fuel) (block fuel) he hb fuel
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro env source
      rw [expr.eq_def]
      apply walk_scope
      have split : surfacePreorder source = [source] ++ (surfacePreorder source).tail := by
        rw [surfacePreorder_children]; rfl
      rw [split]
      apply walk_bind (walk_identify source)
      intro key
      apply walk_bind (walk_scan _)
      intro _
      cases source
      case literal value =>
        cases value <;> first
          | exact walk_pure _
          | exact walk_widthLiteral _ _
          | exact walk_bind_empty (sc env _) (fun _ => walk_unsupported)
      case neg type child =>
        simp only [surfacePreorder]
        split
        · exact walk_bind_empty (he env child) (fun value => walk_map (walk_negOwnTyped key type value) _)
        · simpa only [surfacePreorder, List.tail_cons] using
            walk_bind_empty (sc env (.neg type child)) (fun _ => walk_unsupported)
      case binary op type left right =>
        simp only [surfacePreorder]
        split
        · apply walk_bind (he env left)
          intro lhs
          split
          · exact walk_map (se right) _
          · apply walk_bind_empty (he env right)
            intro rhs
            split
            · exact walk_pure _
            · exact walk_map (walk_own _ _ _ _ _) _
        · simpa only [surfacePreorder, List.tail_cons] using
            walk_bind_empty (sc env (.binary op type left right)) (fun _ => walk_unsupported)
      case call callee labels positions sources =>
        simp only [surfacePreorder]
        apply walk_bind (walk_scan _)
        intro recognized
        cases recognized with
        | none =>
          simpa only [surfacePreorder, List.tail_cons, List.append_eq] using
            walk_bind_empty (sc env (.call callee labels positions sources)) (fun _ => walk_unsupported)
        | some binding =>
          apply walk_bind (se callee)
          intro _
          split
          · exact walk_bind_empty (walk_selectArguments _ _ _ _ _ (he env) ((skip_walk fuel).2.2.1))
              (fun selected => walk_map (walk_fixedOwn binding key selected) _)
          · apply walk_bind_empty (hargs env sources)
            intro values
            exact walk_bind (walk_scan _) (fun _ => walk_pure _)
      case «local» index =>
        apply walk_bind (walk_scan _)
        intro slot
        cases slot with
        | none => exact walk_pure _
        | some slot => cases slot <;> first
          | exact walk_pure _
          | exact walk_pure _
      case matchE type source arms =>
        simp only [surfacePreorder]
        apply walk_bind (he env source)
        intro tested
        split
        · exact walk_map (sa arms) _
        · apply walk_bind (walk_scan _)
          intro known
          cases known with
          | some origin => exact walk_map (hr env _ arms) _
          | none =>
            cases selected : tested.matchKind with
            | some kind => exact walk_map (ha kind env source (tested.rangeKind kind) arms) _
            | none => exact walk_bind_empty (sa arms) (fun _ => walk_map walk_unsupported _)
      case ite condition yes no =>
        simp only [surfacePreorder, List.append_assoc]
        apply walk_bind (he env condition)
        intro tested
        apply walk_bind (walk_branch _ _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact walk_map (walk_branch _ _ _ _ _ _ _ (fun inner => hb inner no) (sb no)) _
      case elseIf condition yes no =>
        simp only [surfacePreorder, List.append_assoc]
        apply walk_bind (he env condition)
        intro tested
        apply walk_bind (walk_branch _ _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact walk_map (walk_branch _ _ _ _ _ _ _ (fun inner => he inner no) (se no)) _
      case ifOnly condition yes =>
        simp only [surfacePreorder]
        apply walk_bind (he env condition)
        intro tested
        apply walk_bind_empty (walk_branch _ _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact walk_map (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure _) (walk_pure ())) _
      all_goals first
        | exact walk_bind_empty (sc env _) (fun _ => walk_unsupported)
        | exact walk_pure _
        | exact walk_widthLiteral _ _
        | exact walk_bind (walk_scan _) (fun _ => walk_pure _)
        | exact he _ _
        | exact walk_map (he _ _) _
        | exact hb _ _
        | exact hs _ _ _ _
    · intro env left right truth
      rw [shortCircuit]
      apply walk_bind (he env left)
      intro tested
      apply walk_bind_empty (walk_branch _ _ _ _ _ _ _ (fun inner => he inner right) (se right))
      intro continued
      apply walk_bind (walk_branch _ _ _ _ _ _ [] (fun _ => walk_pure _) (walk_pure ()))
      intro shorted
      exact walk_pure _
    · intro env body
      rw [block.eq_def]
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases body with
      | empty => exact walk_pure _
      | builderBind kind rest => exact walk_bind (walk_scan _) (fun inner => hb inner rest)
      | last source => exact he env source
      | lastBind _ _ source | lastDiscard source | lastPat _ _ _ source =>
        exact walk_map (he env source) _
      | bind kind type source rest =>
        apply walk_bind walk_get
        intro start
        apply walk_bind (he env source)
        intro head
        split
        · exact walk_map (sb rest) _
        · exact walk_bind (walk_scan _) (fun inner =>
            walk_map (hb inner rest) _)
      | discard source rest | seq source rest =>
        apply walk_bind (he env source)
        intro head
        split
        · exact walk_map (sb rest) _
        · exact walk_map (hb env rest) _
      | bindPat _ pattern type source rest =>
        apply walk_bind (he env source)
        intro head
        split
        · exact walk_map (sb rest) _
        · exact walk_bind (walk_scan _) (fun inner =>
            walk_map (hb inner rest) _)
    · intro kind env source normal arms
      rw [armListKind.eq_def]
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases arms with
      | nil => exact walk_pure _
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [preorderArms, List.nil_append]
          apply walk_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            cases inner with
            | none => exact walk_bind (so none) (fun _ => walk_map (sb body) _)
            | some inner => exact hb inner body
          · intro first
            exact walk_map (ha kind env source normal rest) _
        | some condition =>
          simp only [preorderArms]
          apply walk_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            cases inner with
            | none => exact walk_bind (so (some condition)) (fun _ => walk_map (sb body) _)
            | some inner =>
              apply walk_bind (he inner condition)
              intro tested
              exact walk_map
                (walk_branch _ _ _ _ _ _ _ (fun refined => hb refined body) (sb body)) _
          · intro first
            exact walk_map (ha kind env source normal rest) _


    · intro env sources
      rw [arguments.eq_def]
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases sources with
      | nil => exact walk_pure _
      | cons source rest =>
        simp only [preorderExprs]
        apply walk_bind (he env source)
        intro head
        split
        · exact walk_map ((skip_walk fuel).2.2.1 rest) _
        · exact walk_map (hargs env rest) _
    · intro env input arms
      rw [resultArmList.eq_def]
      apply walk_scope
      apply walk_bind (walk_scan _)
      intro _
      cases arms with
      | nil => exact walk_pure _
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [preorderArms, List.nil_append]
          apply walk_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            exact hb inner body
          · intro first
            exact walk_map (hr env input rest) _
        | some condition =>
          simp only [preorderArms]
          apply walk_bind (ys := preorderArms rest)
          · apply walk_scope
            apply walk_bind (walk_scan _)
            intro inner
            apply walk_bind (he inner condition)
            intro tested
            exact walk_map (walk_branch _ _ _ _ _ _ _ (fun refined => hb refined body) (sb body)) _
          · intro first
            exact walk_map (hr env input rest) _

theorem analysis_walk_kind (fuel : Nat) :
    (∀ env source, Walk (expr fuel env source) (surfacePreorder source)) ∧
    (∀ env left right truth, Walk (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right)) ∧
    (∀ env body, Walk (block fuel env body) (preorderBlock body)) ∧
    (∀ kind env source normal arms, Walk (armListKind fuel kind env source normal arms) (preorderArms arms)) := by
  obtain ⟨he, hs, hb, ha, _, _⟩ := analysis_walk_all fuel
  exact ⟨he, hs, hb, ha⟩

/-- Integer64 の既存の入口と言明を保つ。 -/
theorem analysis_walk (fuel : Nat) :
    (∀ env source, Walk (expr fuel env source) (surfacePreorder source)) ∧
    (∀ env left right truth, Walk (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right)) ∧
    (∀ env body, Walk (block fuel env body) (preorderBlock body)) ∧
    (∀ env source normal arms, Walk (armList fuel env source normal arms) (preorderArms arms))  := by
  obtain ⟨he, hs, hb, ha⟩ := analysis_walk_kind fuel
  exact ⟨he, hs, hb, ha .integer64⟩

/-- 証明用の再帰列と、識別規則の zipIdx による番号付けは一致する。 -/
theorem numberFrom_zipIdx (key : OperationKey) (sources : List Expr) :
    numberFrom key sources = (sources.zipIdx key.surfacePreorder).map
      (fun (source, index) => (⟨key.definition, index⟩, source)) := by
  induction sources generalizing key with
  | nil => rfl
  | cons source rest ih =>
    simp only [numberFrom, List.zipIdx_cons, List.map_cons, ih]
    cases key
    rfl

@[simp] theorem numberFrom_length (key : OperationKey) (sources : List Expr) :
    (numberFrom key sources).length = sources.length := by
  rw [numberFrom_zipIdx]
  simp

theorem numberFrom_numbered (key : OperationKey) (source : Expr) :
    numberFrom key (surfacePreorder source) = numbered key source :=
  numberFrom_zipIdx key (surfacePreorder source)

/-- 停止時も、今回の追加分は全番号列の接頭辞であり、次番号を詰めない。 -/
theorem Traversal.prefix {sources : List Expr} {before after : Context} {outcome : Except Halt α}
    (h : Traversal sources before outcome after) :
    ∃ added, after.identitiesRev = added.reverse ++ before.identitiesRev ∧
      added <+: numberFrom before.next sources ∧
      after.next = advanceKey before.next added.length := by
  obtain ⟨visited, rest, input, ids, key, _⟩ := h
  refine ⟨numberFrom before.next visited, ids, ?_, by simpa using key⟩
  rw [input, numberFrom_append]
  exact List.prefix_append _ _

/-- 完走時だけ、保存列全体と部分木の全長の消費を結論する。 -/
theorem Walk.success {work : Analysis α} {sources : List Expr} (h : Walk work sources)
    {limits : Limits} {ctx final : Context} {value : α}
    (ok : work limits ctx = (.ok value, final)) :
    final.next = advanceKey ctx.next sources.length ∧
    final.identitiesRev = (numberFrom ctx.next sources).reverse ++ ctx.identitiesRev := by
  have progress := h limits ctx
  rw [ok] at progress
  obtain ⟨visited, rest, input, ids, key, complete⟩ := progress
  have empty := complete value rfl
  have full : sources = visited := by simpa only [empty, List.append_nil] using input
  subst visited
  exact ⟨key, ids⟩

/-- 入力からの保存列には、現在の部分木への所属を要求しない。 -/
theorem Walk.identities {work : Analysis α} {sources : List Expr} (h : Walk work sources)
    (limits : Limits) (ctx : Context) :
    ListExtension (fun identity => identity ∈ numberFrom ctx.next sources)
      ctx.identitiesRev (work limits ctx).2.identitiesRev := by
  obtain ⟨added, ids, hp, _⟩ := (h limits ctx).prefix
  refine ⟨added.reverse, ids, ?_⟩
  intro identity member
  exact hp.subset (List.mem_reverse.mp member)

/-- 番号だけの走査も、完走時は元の識別規則の全列と一致する。 -/
theorem skipExpr_success (fuel : Nat) (source : Expr) (limits : Limits) (ctx : Context)
    {final : Context} (ok : skipExpr fuel source limits ctx = (.ok (), final)) :
    final.next = advanceKey ctx.next (surfaceSize source) ∧
    final.identitiesRev = (numbered ctx.next source).reverse ++ ctx.identitiesRev := by
  simpa only [surfaceSize, numberFrom_numbered] using (skip_walk fuel).1 source |>.success ok

/-- 値の解析と skip の混在でも、完走した式の番号範囲を変えない。 -/
theorem expr_success (fuel : Nat) (env : AbstractEnv) (source : Expr) (limits : Limits) (ctx : Context)
    {value : BaseApprox} {final : Context} (ok : expr fuel env source limits ctx = (.ok value, final)) :
    final.next = advanceKey ctx.next (surfaceSize source) ∧
    final.identitiesRev = (numbered ctx.next source).reverse ++ ctx.identitiesRev := by
  simpa only [surfaceSize, numberFrom_numbered] using (analysis_walk fuel).1 env source |>.success ok

/-- 評価関係が使う Block の大きさと、先行順の長さを合わせる。 -/
theorem preorderBlock_length (body : Block) : (preorderBlock body).length = blockSize body := by
  have h := surfaceSize_block body
  change (preorderBlock body).length + 1 = 1 + blockSize body at h
  omega

theorem block_success (fuel : Nat) (env : AbstractEnv) (body : Block) (limits : Limits) (ctx : Context)
    {value : BaseApprox} {final : Context} (ok : block fuel env body limits ctx = (.ok value, final)) :
    final.next = advanceKey ctx.next (blockSize body) ∧
    final.identitiesRev = (numberFrom ctx.next (preorderBlock body)).reverse ++ ctx.identitiesRev := by
  simpa only [preorderBlock_length] using (analysis_walk fuel).2.2.1 env body |>.success ok

theorem armList_success (fuel : Nat) (env : AbstractEnv) (source : Expr) (normal : Interval)
    (arms : Arms) (limits : Limits) (ctx : Context) {value : BaseApprox} {final : Context}
    (ok : armList fuel env source normal arms limits ctx = (.ok value, final)) :
    final.next = advanceKey ctx.next (armsSize arms) ∧
    final.identitiesRev = (numberFrom ctx.next (preorderArms arms)).reverse ++ ctx.identitiesRev :=
  (analysis_walk fuel).2.2.2 env source normal arms |>.success ok

theorem shortCircuit_success (fuel : Nat) (env : AbstractEnv) (left right : Expr) (truth : Bool)
    (limits : Limits) (ctx : Context) {value : BaseApprox} {final : Context}
    (ok : shortCircuit fuel env left right truth limits ctx = (.ok value, final)) :
    final.next = advanceKey ctx.next (surfaceSize left + surfaceSize right) ∧
    final.identitiesRev = (numberFrom ctx.next (surfacePreorder left ++ surfacePreorder right)).reverse ++
      ctx.identitiesRev := by
  simpa only [List.length_append, surfaceSize] using
    (analysis_walk fuel).2.1 env left right truth |>.success ok

/-- 停止後の位置にも、全先行順に対する連続した接頭辞の対応を残す。 -/
theorem expr_prefix (fuel : Nat) (env : AbstractEnv) (source : Expr) (limits : Limits) (ctx : Context) :
    let final := (expr fuel env source limits ctx).2
    ∃ added, final.identitiesRev = added.reverse ++ ctx.identitiesRev ∧
      added <+: numbered ctx.next source ∧ final.next = advanceKey ctx.next added.length := by
  simpa only [numberFrom_numbered] using ((analysis_walk fuel).1 env source limits ctx).prefix

theorem skipExpr_prefix (fuel : Nat) (source : Expr) (limits : Limits) (ctx : Context) :
    let final := (skipExpr fuel source limits ctx).2
    ∃ added, final.identitiesRev = added.reverse ++ ctx.identitiesRev ∧
      added <+: numbered ctx.next source ∧ final.next = advanceKey ctx.next added.length := by
  simpa only [numberFrom_numbered] using ((skip_walk fuel).1 source limits ctx).prefix

end Benitoite.Interval.BudgetAnalysis
