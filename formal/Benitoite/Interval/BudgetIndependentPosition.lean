import Benitoite.Interval.BudgetIndependentSound

/-!
# 独立入力の番号区間と本体内の位置

保存した入力全体の番号列が、元の本体の番号列の連続部分であることを示す。
未取得の残りも含む入力の範囲を使い、停止時に警告の位置を失わない。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 入力全体の番号列は本体の番号列の連続部分である。証明専用である。 -/
def InputSegment (key : OperationKey) (sources : List Expr) (entry : IndependentResult) : Prop :=
  ∃ beforeList afterList, numberFrom key sources =
    beforeList ++ numberFrom entry.key (entry.input.syntacticReach.map Prod.snd) ++ afterList

theorem InputSegment.full (key : OperationKey) (entry : IndependentResult)
    (start : entry.key = key) : InputSegment key (entry.input.syntacticReach.map Prod.snd) entry := by
  exact ⟨[], [], by simp [start]⟩

theorem InputSegment.left {key xs entry} (ys : List Expr) (h : InputSegment key xs entry) :
    InputSegment key (xs ++ ys) entry := by
  obtain ⟨beforeList, afterList, eq⟩ := h
  exact ⟨beforeList, afterList ++ numberFrom (advanceKey key xs.length) ys,
    by simp [numberFrom_append, eq, List.append_assoc]⟩

theorem InputSegment.right {key ys entry} (xs : List Expr)
    (h : InputSegment (advanceKey key xs.length) ys entry) : InputSegment key (xs ++ ys) entry := by
  obtain ⟨beforeList, afterList, eq⟩ := h
  exact ⟨numberFrom key xs ++ beforeList, afterList,
    by simp [numberFrom_append, eq, List.append_assoc]⟩

theorem InputSegment.located {key sources entry} (h : InputSegment key sources entry)
    (sound : entry.Sound) {warning} (member : warning ∈ entry.warningsRev) :
    LocatedIn key sources warning := by
  obtain ⟨beforeList, afterList, eq⟩ := h
  obtain ⟨source, inside, operation⟩ := sound.located member
  refine ⟨source, ?_, operation⟩
  rw [eq]
  exact List.mem_append_left _ (List.mem_append_right _ inside)

/-- 番号の接頭辞の保存と、新しく保存した入力全体の番号区間の対応を組にする。 -/
def InputWalk (work : Analysis α) (sources : List Expr) : Prop :=
  Walk work sources ∧ ∀ limits ctx,
    ListExtension (InputSegment ctx.next sources) ctx.independentRev (work limits ctx).2.independentRev

theorem KeepsInputs.inputWalk {work : Analysis α} {sources} (h : KeepsInputs work)
    (walk : Walk work sources) : InputWalk work sources := by
  refine ⟨walk, ?_⟩
  intro limits ctx
  rw [h limits ctx]
  exact ListExtension.refl _ _

theorem inputWalk_pure (value : α) : InputWalk (pure value) [] :=
  (keepsInputs_pure value).inputWalk (walk_pure value)
theorem inputWalk_get : InputWalk (get : Analysis Context) [] :=
  keepsInputs_get.inputWalk walk_get

theorem inputWalk_throw (reason : Halt) (sources : List Expr) : InputWalk (throw reason : Analysis α) sources :=
  (keepsInputs_throw reason).inputWalk (walk_throw reason sources)
theorem inputWalk_scan (work : BudgetScan.Scan α) : InputWalk (scan work) [] :=
  (keepsInputs_scan work).inputWalk (walk_scan work)
theorem inputWalk_identify (source : Expr) : InputWalk (identify source) [source] :=
  (keepsInputs_identify source).inputWalk (walk_identify source)
theorem inputWalk_unsupported : InputWalk unsupported [] :=
  keepsInputs_unsupported.inputWalk walk_unsupported
/-- 幅付きの葉は番号・警告・独立入力を追加しない。 -/
theorem inputWalk_widthLiteral (kind : IntKind) (value : Int) :
    InputWalk (widthLiteral kind value) [] := by
  unfold widthLiteral
  split
  · exact inputWalk_pure _
  · exact inputWalk_unsupported

theorem inputWalk_own (key op type left right) : InputWalk (own key op type left right) [] :=
  (keepsInputs_own key op type left right).inputWalk (walk_own key op type left right)

theorem inputWalk_negOwn (key child) : InputWalk (negOwn key child) [] :=
  (keepsInputs_negOwn key child).inputWalk (walk_negOwn key child)

theorem inputWalk_negOwnTyped (key type child) : InputWalk (negOwnTyped key type child) [] :=
  (keepsInputs_negOwnTyped key type child).inputWalk (walk_negOwnTyped key type child)

theorem inputWalk_bind {first : Analysis α} {next : α → Analysis β} {xs ys : List Expr}
    (hf : InputWalk first xs) (hn : ∀ value, InputWalk (next value) ys) :
    InputWalk (first >>= next) (xs ++ ys) := by
  refine ⟨walk_bind hf.1 (fun value => (hn value).1), ?_⟩
  intro limits ctx
  have added := (hf.2 limits ctx).mono (fun _ h => h.left ys)
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases run : first limits ctx with
  | mk outcome middle =>
    rw [run] at added
    cases outcome with
    | error reason => exact added
    | ok value =>
      have key := (hf.1.success run).1
      exact added.trans ((hn value).2 limits middle |>.mono fun _ h => InputSegment.right xs (key ▸ h))

theorem inputWalk_scope {work : Unit → Analysis α} {sources}
    (h : InputWalk (work ()) sources) : InputWalk (scope work) sources := by
  refine ⟨walk_scope h.1, ?_⟩
  intro limits ctx
  unfold scope
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    have same := scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx
    have inputs := keepsInputs_scan (BudgetScan.allocate .stackFrame) limits ctx
    rw [run] at same inputs
    dsimp only at same inputs
    cases outcome with
    | error reason => simpa only [inputs] using ListExtension.refl (InputSegment ctx.next sources) ctx.independentRev
    | ok value =>
      cases value
      cases inner : work () limits entered with
      | mk result final =>
        simpa only [inner, inputs, same.2.2.1] using h.2 limits entered

theorem inputWalk_map {work : Analysis α} {sources} (h : InputWalk work sources) (f : α → β) :
    InputWalk (work >>= fun value => pure (f value)) sources := by
  simpa only [List.append_nil] using inputWalk_bind h (fun value => inputWalk_pure (f value))

theorem inputWalk_bind_empty {work : Analysis α} {next : α → Analysis β} {sources}
    (h : InputWalk work sources) (hn : ∀ value, InputWalk (next value) []) :
    InputWalk (work >>= next) sources := by
  simpa only [List.append_nil] using inputWalk_bind h hn

theorem inputWalk_branch (env source tested truth run skip sources)
    (hr : ∀ inner, InputWalk (run inner) sources) (hs : InputWalk (skip ()) sources) :
    InputWalk (branch env source tested truth run skip) sources := by
  unfold branch
  apply inputWalk_scope
  apply inputWalk_bind (inputWalk_scan _)
  intro inner
  cases inner with
  | none => exact inputWalk_map hs _
  | some inner => exact hr inner

/-- 捕捉した入力全体と入れ子の番号区間を、成否とも元の番号列に残す。 -/
theorem captureIndependent_inputWalk (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox)
    (walking : ∀ initial, InputWalk (work initial) (input.syntacticReach.map Prod.snd)) :
    InputWalk (captureIndependent input env work) (input.syntacticReach.map Prod.snd) := by
  refine ⟨captureIndependent_walk input env work _ (fun initial => (walking initial).1), ?_⟩
  intro limits parent
  unfold captureIndependent
  dsimp only
  cases prepared : prepareIndependent env limits { parent with warningsRev := [], unsupported := false } with
  | mk outcome ready =>
    have same := prepareIndependent_spec env limits { parent with warningsRev := [], unsupported := false }
    rw [prepared] at same
    dsimp only at same
    dsimp only
    cases outcome with
    | error reason =>
      let entry : IndependentResult := ⟨input, parent.next, none, .error reason, ready.warningsRev, ready.unsupported⟩
      refine ⟨[entry], ?_, ?_⟩
      · simp only [List.singleton_append, same.2.1]; rfl
      · intro value member
        cases List.mem_singleton.mp member
        exact InputSegment.full parent.next entry rfl
    | ok initial =>
      cases run : work initial limits ready with
      | mk result final =>
        simp only [run]
        have extension := (walking initial).2 limits ready
        rw [run, same.2.1, same.2.2.1] at extension
        let entry : IndependentResult := ⟨input, parent.next, some initial, result, final.warningsRev, final.unsupported⟩
        exact extension.trans ⟨[entry], rfl, by
          intro value member
          cases List.mem_singleton.mp member
          exact InputSegment.full parent.next entry rfl⟩

theorem independentWith_inputWalk (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (sources : List Expr)
    (sourceEq : input.syntacticReach.map Prod.snd = sources)
    (walking : ∀ initial, InputWalk (work initial) sources) :
    InputWalk (independentWith input env work) sources := by
  subst sources
  unfold independentWith
  apply inputWalk_scope
  exact inputWalk_bind (inputWalk_scan _) (fun _ => captureIndependent_inputWalk input env work walking)

/-- 番号だけの走査は独立入力を作らず、任意の本体にそのまま接続できる。 -/
theorem skip_inputWalk (fuel : Nat) :
    (∀ source, InputWalk (skipExpr fuel source) (surfacePreorder source)) ∧
    (∀ source, InputWalk (skipChildren fuel source) (surfacePreorder source).tail) ∧
    (∀ sources, InputWalk (skipExprs fuel sources) (preorderExprs sources)) ∧
    (∀ args, InputWalk (skipHoles fuel args) (preorderHoles args)) ∧
    (∀ body, InputWalk (skipBlock fuel body) (preorderBlock body)) ∧
    (∀ arms, InputWalk (skipArms fuel arms) (preorderArms arms)) ∧
    (∀ clauses, InputWalk (skipClauses fuel clauses) (preorderClauses clauses)) ∧
    (∀ value, InputWalk (skipOptional fuel value)
      (match value with | none => [] | some source => surfacePreorder source)) := by
  obtain ⟨we, wc, wes, wh, wb, wa, wcl, wo⟩ := skip_walk fuel
  obtain ⟨he, hc, hes, hh, hb, ha, hcl, ho⟩ := skip_keepsInputs fuel
  exact ⟨fun e => (he e).inputWalk (we e), fun e => (hc e).inputWalk (wc e),
    fun e => (hes e).inputWalk (wes e), fun e => (hh e).inputWalk (wh e),
    fun e => (hb e).inputWalk (wb e), fun e => (ha e).inputWalk (wa e),
    fun e => (hcl e).inputWalk (wcl e), fun e => (ho e).inputWalk (wo e)⟩

theorem childContainers_inputWalk (visit : Expr → Analysis Unit)
    (hv : ∀ e, InputWalk (visit e) (surfacePreorder e)) (fuel : Nat) :
    (∀ es, InputWalk (childExprs visit fuel es) (preorderExprs es)) ∧
    (∀ args, InputWalk (childHoles visit fuel args) (preorderHoles args)) ∧
    (∀ value, InputWalk (childOptional visit fuel value)
      (match value with | none => [] | some e => surfacePreorder e)) := by
  induction fuel with
  | zero => exact ⟨fun _ => inputWalk_throw _ _, fun _ => inputWalk_throw _ _, fun _ => inputWalk_throw _ _⟩
  | succ fuel ih =>
    refine ⟨?_, ?_, ?_⟩
    · intro es
      rw [childExprs.eq_def]
      apply inputWalk_scope
      apply inputWalk_bind (inputWalk_scan _)
      intro ignored
      cases es with
      | nil => exact inputWalk_pure _
      | cons e rest => exact inputWalk_bind (hv e) (fun _ => ih.1 rest)
    · intro args
      rw [childHoles.eq_def]
      apply inputWalk_scope
      apply inputWalk_bind (inputWalk_scan _)
      intro ignored
      cases args with
      | nil => exact inputWalk_pure _
      | expr _ _ e rest => exact inputWalk_bind (hv e) (fun _ => ih.2.1 rest)
      | hole _ _ _ rest => exact ih.2.1 rest
    · intro value
      cases value with
      | none => exact inputWalk_pure _
      | some e => exact hv e

/-- 独立解析は skip と同じ先行順を一度だけ辿り、停止時も接頭辞を残す。 -/
theorem unknownChildren_inputWalk
    (runExpr : AbstractEnv → Expr → Analysis BaseApprox)
    (runBlock : AbstractEnv → Block → Analysis BaseApprox)
    (he : ∀ env e, InputWalk (runExpr env e) (surfacePreorder e))
    (hb : ∀ env b, InputWalk (runBlock env b) (preorderBlock b))
    (fuel : Nat) (env : AbstractEnv) (source : Expr) :
    InputWalk (unknownChildren runExpr runBlock fuel env source) (surfacePreorder source).tail := by
  cases fuel with
  | zero => exact inputWalk_throw _ _
  | succ fuel =>
    have ie := fun env e => independentWith_inputWalk (.expr e) env (fun initial => runExpr initial e)
      (surfacePreorder e) (by simp [IndependentInput.syntacticReach]) (fun initial => he initial e)
    have ib := fun env b => independentWith_inputWalk (.block b) env (fun initial => runBlock initial b)
      (preorderBlock b) (by simp [IndependentInput.syntacticReach]) (fun initial => hb initial b)
    obtain ⟨hes, hh, ho⟩ := childContainers_inputWalk
      (fun e => independentWith (.expr e) env (fun initial => runExpr initial e)) (ie env) fuel
    obtain ⟨_, _, _, _, sb, sa, sc, _⟩ := skip_inputWalk fuel
    cases source <;> simp only [unknownChildren, surfacePreorder, List.tail_cons, List.append_assoc]
    all_goals try (rename_i message; cases message <;> simp only [surfacePreorder, List.tail_cons])
    all_goals first
      | with_reducible exact inputWalk_pure _
      | with_reducible exact ie _ _
      | with_reducible exact ib _ _
      | with_reducible exact hes _
      | with_reducible exact hh _
      | with_reducible exact sb _
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => hes _)
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => hh _)
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => ib _ _)
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => sa _)
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => ho _)
      | with_reducible exact inputWalk_bind (ib _ _) (fun _ => sb _)
      | with_reducible exact inputWalk_bind (ib _ _) (fun _ => sc _)
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => ie _ _)
      | with_reducible exact inputWalk_bind (hes _) (fun _ => hes _)
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => inputWalk_bind (ib _ _) (fun _ => ib _ _))
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => inputWalk_bind (ib _ _) (fun _ => ie _ _))
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => inputWalk_bind (hes _) (fun _ =>
          inputWalk_bind (ie _ _) (fun _ => hes _)))
      | with_reducible exact inputWalk_bind (ie _ _) (fun _ => inputWalk_bind (inputWalk_scan _) (fun inner => ib inner _))

/-- 実際に値を解析する部分と skip する部分は、同じ先行順を共有する。 -/
theorem inputWalk_fixedOwn (binding key selected) : InputWalk (fixedOwn binding key selected) [] :=
  (keepsInputs_fixedOwn binding key selected).inputWalk (walk_fixedOwn binding key selected)

theorem inputWalk_selectArguments (run skip target positions sources)
    (he : ∀ source, InputWalk (run source) (surfacePreorder source))
    (hs : ∀ sources, InputWalk (skip sources) (preorderExprs sources)) :
    InputWalk (selectArguments run skip target positions sources) (preorderExprs sources) := by
  rw [selectArguments.eq_def]
  apply inputWalk_scope
  apply inputWalk_bind (inputWalk_scan _)
  intro _
  cases sources with
  | nil => exact inputWalk_pure _
  | cons source rest =>
    apply inputWalk_bind (he source)
    intro head
    split
    · exact inputWalk_map (hs rest) _
    · exact inputWalk_map (inputWalk_selectArguments run skip target positions.tail rest he hs) _

theorem analysis_inputWalk_all (fuel : Nat) :
    (∀ env source, InputWalk (expr fuel env source) (surfacePreorder source)) ∧
    (∀ env left right truth, InputWalk (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right)) ∧
    (∀ env body, InputWalk (block fuel env body) (preorderBlock body)) ∧
    (∀ kind env source normal arms, InputWalk (armListKind fuel kind env source normal arms) (preorderArms arms)) ∧
    (∀ env sources, InputWalk (arguments fuel env sources) (preorderExprs sources)) ∧
    (∀ env input arms, InputWalk (resultArmList fuel env input arms) (preorderArms arms)) := by
  induction fuel with
  | zero => exact ⟨fun _ _ => inputWalk_throw _ _, fun _ _ _ _ => inputWalk_throw _ _,
      fun _ _ => inputWalk_throw _ _, fun _ _ _ _ _ => inputWalk_throw _ _, fun _ _ => inputWalk_throw _ _, fun _ _ _ => inputWalk_throw _ _⟩
  | succ fuel ih =>
    obtain ⟨he, hs, hb, ha, hargs, hr⟩ := ih
    obtain ⟨se, _, _, _, sb, sa, _, so⟩ := skip_inputWalk fuel
    have sc := unknownChildren_inputWalk (expr fuel) (block fuel) he hb fuel
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro env source
      rw [expr.eq_def]
      apply inputWalk_scope
      have split : surfacePreorder source = [source] ++ (surfacePreorder source).tail := by
        rw [surfacePreorder_children]; rfl
      rw [split]
      apply inputWalk_bind (inputWalk_identify source)
      intro key
      apply inputWalk_bind (inputWalk_scan _)
      intro _
      cases source
      case literal value =>
        cases value <;> first
          | exact inputWalk_pure _
          | exact inputWalk_widthLiteral _ _
          | exact inputWalk_bind_empty (sc env _) (fun _ => inputWalk_unsupported)
      case neg type child =>
        simp only [surfacePreorder]
        split
        · exact inputWalk_bind_empty (he env child) (fun value => inputWalk_map (inputWalk_negOwnTyped key type value) _)
        · simpa only [surfacePreorder, List.tail_cons] using
            inputWalk_bind_empty (sc env (.neg type child)) (fun _ => inputWalk_unsupported)
      case binary op type left right =>
        simp only [surfacePreorder]
        split
        · apply inputWalk_bind (he env left)
          intro lhs
          split
          · exact inputWalk_map (se right) _
          · apply inputWalk_bind_empty (he env right)
            intro rhs
            split
            · exact inputWalk_pure _
            · exact inputWalk_map (inputWalk_own _ _ _ _ _) _
        · simpa only [surfacePreorder, List.tail_cons] using
            inputWalk_bind_empty (sc env (.binary op type left right)) (fun _ => inputWalk_unsupported)
      case call callee labels positions sources =>
        simp only [surfacePreorder]
        apply inputWalk_bind (inputWalk_scan _)
        intro recognized
        cases recognized with
        | none =>
          simpa only [surfacePreorder, List.tail_cons, List.append_eq] using
            inputWalk_bind_empty (sc env (.call callee labels positions sources)) (fun _ => inputWalk_unsupported)
        | some binding =>
          apply inputWalk_bind (se callee)
          intro _
          split
          · exact inputWalk_bind_empty (inputWalk_selectArguments _ _ _ _ _ (he env) ((skip_inputWalk fuel).2.2.1))
              (fun selected => inputWalk_map (inputWalk_fixedOwn binding key selected) _)
          · apply inputWalk_bind_empty (hargs env sources)
            intro values
            exact inputWalk_bind (inputWalk_scan _) (fun _ => inputWalk_pure _)
      case «local» index =>
        apply inputWalk_bind (inputWalk_scan _)
        intro slot
        cases slot with
        | none => exact inputWalk_pure _
        | some slot => cases slot <;> first
          | exact inputWalk_pure _
          | exact inputWalk_pure _
      case matchE type source arms =>
        simp only [surfacePreorder]
        apply inputWalk_bind (he env source)
        intro tested
        split
        · exact inputWalk_map (sa arms) _
        · apply inputWalk_bind (inputWalk_scan _)
          intro known
          cases known with
          | some origin => exact inputWalk_map (hr env _ arms) _
          | none =>
            cases selected : tested.matchKind with
            | some kind => exact inputWalk_map (ha kind env source (tested.rangeKind kind) arms) _
            | none => exact inputWalk_bind_empty (sa arms) (fun _ => inputWalk_map inputWalk_unsupported _)
      case ite condition yes no =>
        simp only [surfacePreorder, List.append_assoc]
        apply inputWalk_bind (he env condition)
        intro tested
        apply inputWalk_bind (inputWalk_branch _ _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact inputWalk_map (inputWalk_branch _ _ _ _ _ _ _ (fun inner => hb inner no) (sb no)) _
      case elseIf condition yes no =>
        simp only [surfacePreorder, List.append_assoc]
        apply inputWalk_bind (he env condition)
        intro tested
        apply inputWalk_bind (inputWalk_branch _ _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact inputWalk_map (inputWalk_branch _ _ _ _ _ _ _ (fun inner => he inner no) (se no)) _
      case ifOnly condition yes =>
        simp only [surfacePreorder]
        apply inputWalk_bind (he env condition)
        intro tested
        apply inputWalk_bind_empty (inputWalk_branch _ _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact inputWalk_map (inputWalk_branch _ _ _ _ _ _ [] (fun _ => inputWalk_pure _) (inputWalk_pure ())) _
      all_goals first
        | exact inputWalk_bind_empty (sc env _) (fun _ => inputWalk_unsupported)
        | exact inputWalk_pure _
        | exact inputWalk_widthLiteral _ _
        | exact inputWalk_bind (inputWalk_scan _) (fun _ => inputWalk_pure _)
        | exact he _ _
        | exact inputWalk_map (he _ _) _
        | exact hb _ _
        | exact hs _ _ _ _
    · intro env left right truth
      rw [shortCircuit]
      apply inputWalk_bind (he env left)
      intro tested
      apply inputWalk_bind_empty (inputWalk_branch _ _ _ _ _ _ _ (fun inner => he inner right) (se right))
      intro continued
      apply inputWalk_bind (inputWalk_branch _ _ _ _ _ _ [] (fun _ => inputWalk_pure _) (inputWalk_pure ()))
      intro shorted
      exact inputWalk_pure _
    · intro env body
      rw [block.eq_def]
      apply inputWalk_scope
      apply inputWalk_bind (inputWalk_scan _)
      intro _
      cases body with
      | empty => exact inputWalk_pure _
      | builderBind kind rest => exact inputWalk_bind (inputWalk_scan _) (fun inner => hb inner rest)
      | last source => exact he env source
      | lastBind _ _ source | lastDiscard source | lastPat _ _ _ source =>
        exact inputWalk_map (he env source) _
      | bind kind type source rest =>
        apply inputWalk_bind inputWalk_get
        intro start
        apply inputWalk_bind (he env source)
        intro head
        split
        · exact inputWalk_map (sb rest) _
        · exact inputWalk_bind (inputWalk_scan _) (fun inner =>
            inputWalk_map (hb inner rest) _)
      | discard source rest | seq source rest =>
        apply inputWalk_bind (he env source)
        intro head
        split
        · exact inputWalk_map (sb rest) _
        · exact inputWalk_map (hb env rest) _
      | bindPat _ pattern type source rest =>
        apply inputWalk_bind (he env source)
        intro head
        split
        · exact inputWalk_map (sb rest) _
        · exact inputWalk_bind (inputWalk_scan _) (fun inner =>
            inputWalk_map (hb inner rest) _)
    · intro kind env source normal arms
      rw [armListKind.eq_def]
      apply inputWalk_scope
      apply inputWalk_bind (inputWalk_scan _)
      intro _
      cases arms with
      | nil => exact inputWalk_pure _
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [preorderArms, List.nil_append]
          apply inputWalk_bind (ys := preorderArms rest)
          · apply inputWalk_scope
            apply inputWalk_bind (inputWalk_scan _)
            intro inner
            cases inner with
            | none => exact inputWalk_bind (so none) (fun _ => inputWalk_map (sb body) _)
            | some inner => exact hb inner body
          · intro first
            exact inputWalk_map (ha kind env source normal rest) _
        | some condition =>
          simp only [preorderArms]
          apply inputWalk_bind (ys := preorderArms rest)
          · apply inputWalk_scope
            apply inputWalk_bind (inputWalk_scan _)
            intro inner
            cases inner with
            | none => exact inputWalk_bind (so (some condition)) (fun _ => inputWalk_map (sb body) _)
            | some inner =>
              apply inputWalk_bind (he inner condition)
              intro tested
              exact inputWalk_map
                (inputWalk_branch _ _ _ _ _ _ _ (fun refined => hb refined body) (sb body)) _
          · intro first
            exact inputWalk_map (ha kind env source normal rest) _


    · intro env sources
      rw [arguments.eq_def]
      apply inputWalk_scope
      apply inputWalk_bind (inputWalk_scan _)
      intro _
      cases sources with
      | nil => exact inputWalk_pure _
      | cons source rest =>
        simp only [preorderExprs]
        apply inputWalk_bind (he env source)
        intro head
        split
        · exact inputWalk_map ((skip_inputWalk fuel).2.2.1 rest) _
        · exact inputWalk_map (hargs env rest) _
    · intro env input arms
      rw [resultArmList.eq_def]
      apply inputWalk_scope
      apply inputWalk_bind (inputWalk_scan _)
      intro _
      cases arms with
      | nil => exact inputWalk_pure _
      | cons alts guard body rest =>
        cases guard with
        | none =>
          simp only [preorderArms, List.nil_append]
          apply inputWalk_bind (ys := preorderArms rest)
          · apply inputWalk_scope
            apply inputWalk_bind (inputWalk_scan _)
            intro inner
            exact hb inner body
          · intro first
            exact inputWalk_map (hr env input rest) _
        | some condition =>
          simp only [preorderArms]
          apply inputWalk_bind (ys := preorderArms rest)
          · apply inputWalk_scope
            apply inputWalk_bind (inputWalk_scan _)
            intro inner
            apply inputWalk_bind (he inner condition)
            intro tested
            exact inputWalk_map (inputWalk_branch _ _ _ _ _ _ _ (fun refined => hb refined body) (sb body)) _
          · intro first
            exact inputWalk_map (hr env input rest) _

theorem analysis_inputWalk_kind (fuel : Nat) :
    (∀ env source, InputWalk (expr fuel env source) (surfacePreorder source)) ∧
    (∀ env left right truth, InputWalk (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right)) ∧
    (∀ env body, InputWalk (block fuel env body) (preorderBlock body)) ∧
    (∀ kind env source normal arms, InputWalk (armListKind fuel kind env source normal arms) (preorderArms arms)) := by
  obtain ⟨he, hs, hb, ha, _, _⟩ := analysis_inputWalk_all fuel
  exact ⟨he, hs, hb, ha⟩

/-- Integer64 の既存の入口と言明を保つ。 -/
theorem analysis_inputWalk (fuel : Nat) :
    (∀ env source, InputWalk (expr fuel env source) (surfacePreorder source)) ∧
    (∀ env left right truth, InputWalk (shortCircuit fuel env left right truth)
      (surfacePreorder left ++ surfacePreorder right)) ∧
    (∀ env body, InputWalk (block fuel env body) (preorderBlock body)) ∧
    (∀ env source normal arms, InputWalk (armList fuel env source normal arms) (preorderArms arms))  := by
  obtain ⟨he, hs, hb, ha⟩ := analysis_inputWalk_kind fuel
  exact ⟨he, hs, hb, ha .integer64⟩

/-- 本体入口の忘却は番号を増やさず、保存入力の番号区間を保つ。 -/
theorem bodyWork_inputWalk (fuel : Nat) (seed : BodySeed) :
    InputWalk (bodyWork fuel seed) (surfacePreorder (bodyRoot seed.body)) := by
  unfold bodyWork
  apply inputWalk_scope
  exact inputWalk_bind (inputWalk_scan _) (fun initial =>
    (analysis_inputWalk fuel).1 initial (bodyRoot seed.body))

/-- 任意の予算・途中停止で、保存した入力全体の番号列は本体の連続部分である。 -/
theorem analyzeBody_independent_segment (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) :
    ∀ entry ∈ (analyzeBody limits state fuel definition seed).context.independentRev,
      InputSegment (bodyRootKey definition) (surfacePreorder (bodyRoot seed.body)) entry := by
  unfold analyzeBody
  split
  · simp [report]
  · split
    · simp [report]
    · have saved := (bodyWork_inputWalk fuel seed).2 limits
        { budget := state, next := bodyRootKey definition }
      cases run : bodyWork fuel seed limits { budget := state, next := bodyRootKey definition } with
      | mk result final =>
        intro entry member
        have h := saved.member (by simpa only [run, report] using member)
        exact h.resolve_left (by simp)

/-- 独立入力の候補も元の本体の出現・対象演算に一致する。評価導出は要求しない。 -/
theorem analyzeBody_independent_located (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) :
    ∀ entry ∈ (analyzeBody limits state fuel definition seed).context.independentRev,
      ∀ warning ∈ entry.warningsRev,
        LocatedIn (bodyRootKey definition) (surfacePreorder (bodyRoot seed.body)) warning := by
  intro entry member warning candidate
  exact (analyzeBody_independent_segment limits state fuel definition seed entry member).located
    (analyzeBody_independent_sound limits state fuel definition seed entry member) candidate

end Benitoite.Interval.BudgetAnalysis
