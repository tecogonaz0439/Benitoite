import Benitoite.Interval.BudgetIndependent

/-!
# 独立入力の保証と保存列の合成

独立入力に対する正常値・警告原因・位置・構文的な到達可能性の保証を、成功と停止の両方で保存する。
親の未知の評価の trace に子の警告を押し込まない。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 保存済みの環境を具体環境が満たせば、その入力の正常値は近似に属する。 -/
theorem IndependentResult.Sound.normal {entry : IndependentResult} (sound : entry.Sound)
    {env concrete type outcome trace} (initial : entry.initial = some env)
    (models : Models env concrete)
    (eval : entry.input.Evaluates concrete entry.key type outcome trace) :
    NormalCovered entry.approx outcome := by
  have h := sound.2
  rw [initial] at h
  exact (h.2 concrete type outcome trace models eval).1

/-- 保存した候補にも、当該入力で正常な引数を得た演算の拒否原因を要求する。 -/
theorem IndependentResult.Sound.cause {entry : IndependentResult} (sound : entry.Sound)
    {env concrete type outcome trace} (initial : entry.initial = some env)
    (models : Models env concrete)
    (eval : entry.input.Evaluates concrete entry.key type outcome trace)
    {warning event} (member : warning ∈ entry.warningsRev) (reached : Reached trace warning event) :
    event.result = .rejected warning.cause.toFailure := by
  have h := sound.2
  rw [initial] at h
  exact (h.2 concrete type outcome trace models eval).2 warning member event reached

/-- 入れ子を含め、保存したすべての入口に外の整数の事実が残らない。 -/
theorem IndependentResult.Sound.forgotten {entry : IndependentResult} (sound : entry.Sound)
    {env : AbstractEnv} (initial : entry.initial = some env) : forget env = env := by
  have h := sound.2
  rw [initial] at h
  exact h.1

theorem IndependentResult.Sound.integer_top {entry : IndependentResult} (sound : entry.Sound)
    {env : AbstractEnv} (initial : entry.initial = some env) (i : Nat) : integerAt env i = top := by
  rw [← sound.forgotten initial]
  exact integerAt_forget env i

/-- 各入口が、自身の評価関係に対して結果の保証を与える条件。 -/
def IndependentContract (input : IndependentInput) (work : AbstractEnv → Analysis BaseApprox) : Prop :=
  ∀ env limits ctx, ctx.warningsRev = [] → forget env = env →
    IndependentResult.Sound ⟨input, ctx.next, some env, (work env limits ctx).1,
      (work env limits ctx).2.warningsRev, (work env limits ctx).2.unsupported⟩

/-- Expr と Block は、同じ元キーから自身の評価規則で正常値を覆う。 -/
theorem IndependentInput.run_normal (input : IndependentInput) (fuel : Nat)
    {env concrete type key outcome trace} (models : Models env concrete)
    (ranges : env.ranges.Models concrete)
    (eval : input.Evaluates concrete key type outcome trace) :
    SuccessAt key (input.run fuel env) (fun approx => NormalCovered approx outcome) := by
  cases input with
  | expr source => exact expr_normal fuel models ranges eval
  | block body => exact block_normal fuel models ranges eval

/-- 追加警告の範囲は独立入力の根から定め、未知の内側を含めない。 -/
theorem IndependentInput.run_syntactic_reach (input : IndependentInput) (fuel : Nat)
    (env : AbstractEnv) (limits : Limits) (ctx : Context) :
    ListExtension (InSyntacticReach ctx.next input.syntacticReach) ctx.warningsRev
      (input.run fuel env limits ctx).2.warningsRev := by
  cases input with
  | expr source => exact expr_warning_syntactic_reach fuel env source limits ctx
  | block body => exact block_warning_syntactic_reach fuel env body limits ctx

/-- 警告原因の保証は、親ではなく独立入力自身の trace を対象にする。 -/
theorem IndependentInput.run_causal (input : IndependentInput) (fuel : Nat)
    {env concrete type key outcome trace} (models : Models env concrete)
    (ranges : env.ranges.Models concrete)
    (eval : input.Evaluates concrete key type outcome trace) (limits : Limits) (ctx : Context)
    (start : ctx.next = key) :
    ListExtension (fun warning => ∀ event, Reached trace warning event →
      event.result = .rejected warning.cause.toFailure)
      ctx.warningsRev (input.run fuel env limits ctx).2.warningsRev := by
  cases input with
  | expr source => exact ListExtension.mono (expr_causal fuel models ranges eval limits ctx start) (fun _ h => h.2)
  | block body => exact ListExtension.mono (block_causal fuel models ranges eval limits ctx start) (fun _ h => h.2)

/-- 任意の上限・初期消費・深さで、停止後に残った候補も各入力の保証を満たす。 -/
theorem IndependentInput.run_contract (input : IndependentInput) (fuel : Nat) :
    IndependentContract input (input.run fuel) := by
  intro env limits ctx empty forgotten
  constructor
  · intro warning member
    exact ((input.run_syntactic_reach fuel env limits ctx).member member).resolve_left (by simp [empty])
  · refine ⟨forgotten, ?_⟩
    intro concrete type outcome trace models eval
    constructor
    · change NormalCovered (report (input.run fuel env limits ctx).1
        (input.run fuel env limits ctx).2).approx outcome
      apply report_normal
      intro approx ok
      have ranges : env.ranges.Models concrete := by
        rw [← forgotten]
        exact range_forget_models env.ranges concrete
      exact input.run_normal fuel models ranges eval limits ctx rfl approx ok
    · intro warning member event reached
      have ranges : env.ranges.Models concrete := by
        rw [← forgotten]
        exact range_forget_models env.ranges concrete
      have cause := (input.run_causal fuel models ranges eval limits ctx rfl).member member
      exact (cause.resolve_left (by simp [empty])) event reached

/-- 保存枠の確保後は、親の候補・未対応を復元し、忘却した環境だけを記録する。 -/
theorem captureIndependent_head (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (limits : Limits) (parent : Context) :
    let output := captureIndependent input env work limits parent
    output.2.warningsRev = parent.warningsRev ∧
    output.2.unsupported = parent.unsupported ∧
    ∃ entry rest, output.2.independentRev = entry :: rest ∧ entry.input = input ∧
      entry.key = parent.next ∧
      (∀ initial, entry.initial = some initial → initial = forget env) ∧
      (output.1 = entry.result.map (fun _ => ())) := by
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
      exact ⟨rfl, rfl, _, _, rfl, rfl, rfl, (by intro initial h; cases h), rfl⟩
    | ok initial =>
      cases run : work initial limits ready with
      | mk result final =>
        simp only [run]
        exact ⟨trivial, trivial, _, _, rfl, rfl, rfl, by
          intro value h
          cases h
          exact same.2.2.2 initial rfl, rfl⟩

/-- 内部の成否にかかわらず、既存入力を接尾辞に残し、健全な結果だけを加える。 -/
theorem captureIndependent_saves (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (contract : IndependentContract input work)
    (saved : ∀ initial, SavesInputs (work initial)) :
    SavesInputs (captureIndependent input env work) := by
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
      · simp only [List.singleton_append, same.2.1]
        rfl
      · intro entry member
        have eq := List.mem_singleton.mp member
        subst entry
        change (∀ warning ∈ ready.warningsRev, _) ∧ _
        exact ⟨by simp [same.1], ⟨reason, rfl⟩, same.1⟩
    | ok initial =>
      cases run : work initial limits ready with
      | mk result final =>
        simp only [run]
        have extension := saved initial limits ready
        rw [run, same.2.1] at extension
        have good := contract initial limits ready same.1 (by
          rw [same.2.2.2 initial rfl]
          exact forget_idempotent env)
        rw [run, same.2.2.1] at good
        exact extension.trans ⟨[_], rfl, by intro entry member; cases List.mem_singleton.mp member; exact good⟩

/-- 作業枠の確保と返却も、成否によらず入力列の追加分を保存する。 -/
theorem savesInputs_scope {work : Unit → Analysis α} (h : SavesInputs (work ())) :
    SavesInputs (scope work) := by
  intro limits ctx
  unfold scope
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    have same := keepsInputs_scan (BudgetScan.allocate .stackFrame) limits ctx
    rw [run] at same
    dsimp only at same
    cases outcome with
    | error reason => simpa only [same] using ListExtension.refl IndependentResult.Sound ctx.independentRev
    | ok value =>
      cases value
      cases inner : work () limits entered with
      | mk result final =>
        have saved := h limits entered
        simpa only [inner, same] using saved

/-- 同じ予算を使う任意の内部走査へ、入力ごとの保証と保存を合成できる。 -/
theorem independentWith_saves (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (contract : IndependentContract input work)
    (saved : ∀ initial, SavesInputs (work initial)) :
    SavesInputs (independentWith input env work) := by
  unfold independentWith
  apply savesInputs_scope
  exact savesInputs_bind (keepsInputs_scan _).saves
    (fun _ => captureIndependent_saves input env work contract saved)

/-- 入力自身の保証と入れ子の追加分の保証を、未知の構成子の全走査へ合成する。 -/
theorem unknownChildren_saves
    (runExpr : AbstractEnv → Expr → Analysis BaseApprox)
    (runBlock : AbstractEnv → Block → Analysis BaseApprox)
    (ce : ∀ e, IndependentContract (.expr e) (fun env => runExpr env e))
    (cb : ∀ b, IndependentContract (.block b) (fun env => runBlock env b))
    (he : ∀ env e, SavesInputs (runExpr env e))
    (hb : ∀ env b, SavesInputs (runBlock env b))
    (fuel : Nat) (env : AbstractEnv) (source : Expr) :
    SavesInputs (unknownChildren runExpr runBlock fuel env source) := by
  cases fuel with
  | zero => exact (keepsInputs_throw _).saves
  | succ fuel =>
    obtain ⟨_, _, _, _, sb, sa, sc, _⟩ := skip_keepsInputs fuel
    exact unknownChildren_property (@SavesInputs) (fun value => (keepsInputs_pure value).saves)
      (fun reason => (keepsInputs_throw reason).saves)
      (fun _ _ hf hn => savesInputs_bind hf hn) (fun _ h => savesInputs_scope h)
      (fun work => (keepsInputs_scan work).saves) runExpr runBlock
      (fun env e => independentWith_saves (.expr e) env _ (ce e) (fun initial => he initial e))
      (fun env b => independentWith_saves (.block b) env _ (cb b) (fun initial => hb initial b))
      fuel (fun b => (sb b).saves) (fun a => (sa a).saves) (fun c => (sc c).saves) env source

theorem savesInputs_pure (value : α) : SavesInputs (pure value) :=
  (keepsInputs_pure value).saves

theorem savesInputs_throw (reason : Halt) : SavesInputs (throw reason : Analysis α) :=
  (keepsInputs_throw reason).saves

theorem savesInputs_scan (work : BudgetScan.Scan α) : SavesInputs (scan work) :=
  (keepsInputs_scan work).saves

theorem savesInputs_identify (source : Expr) : SavesInputs (identify source) :=
  (keepsInputs_identify source).saves

theorem savesInputs_unsupported : SavesInputs unsupported :=
  keepsInputs_unsupported.saves

/-- 幅付きの葉は番号・警告・独立入力を追加しない。 -/
theorem savesInputs_widthLiteral (kind : IntKind) (value : Int) :
    SavesInputs (widthLiteral kind value) := by
  unfold widthLiteral
  split
  · exact savesInputs_pure _
  · exact savesInputs_unsupported

theorem savesInputs_negOwn (key child) : SavesInputs (negOwn key child) :=
  (keepsInputs_negOwn key child).saves

theorem savesInputs_negOwnTyped (key type child) : SavesInputs (negOwnTyped key type child) :=
  (keepsInputs_negOwnTyped key type child).saves

theorem savesInputs_own (key op type left right) : SavesInputs (own key op type left right) :=
  (keepsInputs_own key op type left right).saves

theorem savesInputs_branch (env source tested truth run skip)
    (hr : ∀ inner, SavesInputs (run inner)) (hs : SavesInputs (skip ())) :
    SavesInputs (branch env source tested truth run skip) := by
  unfold branch
  apply savesInputs_scope
  apply savesInputs_bind (savesInputs_scan _)
  intro refined
  cases refined with
  | none => exact savesInputs_bind hs (fun _ => savesInputs_pure _)
  | some inner => exact hr inner

theorem savesInputs_fixedOwn (binding key selected) : SavesInputs (fixedOwn binding key selected) :=
  (keepsInputs_fixedOwn binding key selected).saves

theorem savesInputs_selectArguments (run skip target positions sources)
    (he : ∀ source, SavesInputs (run source)) (hs : ∀ sources, SavesInputs (skip sources)) :
    SavesInputs (selectArguments run skip target positions sources) := by
  rw [selectArguments.eq_def]
  apply savesInputs_scope
  apply savesInputs_bind (savesInputs_scan _)
  intro _
  cases sources with
  | nil => exact savesInputs_pure _
  | cons source rest =>
    apply savesInputs_bind (he source)
    intro head
    split
    · exact savesInputs_bind (hs rest) (fun _ => savesInputs_pure _)
    · exact savesInputs_bind (savesInputs_selectArguments run skip target positions.tail rest he hs)
        (fun _ => savesInputs_pure _)

/-- 小さい fuel の各入力の契約と追加分を使い、入れ子の保存を任意予算で閉じる。 -/
theorem analysis_savesInputs_all (fuel : Nat) :
    (∀ env source, SavesInputs (expr fuel env source)) ∧
    (∀ env left right truth, SavesInputs (shortCircuit fuel env left right truth)) ∧
    (∀ env body, SavesInputs (block fuel env body)) ∧
    (∀ kind env source normal arms, SavesInputs (armListKind fuel kind env source normal arms)) ∧
    (∀ env sources, SavesInputs (arguments fuel env sources)) ∧
    (∀ env input arms, SavesInputs (resultArmList fuel env input arms)) := by
  induction fuel with
  | zero => exact ⟨fun _ _ => savesInputs_throw _, fun _ _ _ _ => savesInputs_throw _,
      fun _ _ => savesInputs_throw _, fun _ _ _ _ _ => savesInputs_throw _, fun _ _ => savesInputs_throw _, fun _ _ _ => savesInputs_throw _⟩
  | succ fuel ih =>
    obtain ⟨he, hs, hb, ha, hargs, hr⟩ := ih
    obtain ⟨se, _, _, _, sb, sa, _, so⟩ := skip_keepsInputs fuel
    have ses := fun sources => ((skip_keepsInputs fuel).2.2.1 sources).saves
    have se := fun e => (se e).saves
    have sb := fun b => (sb b).saves
    have sa := fun a => (sa a).saves
    have so := fun o => (so o).saves
    have sc := unknownChildren_saves (expr fuel) (block fuel)
      (fun e => IndependentInput.run_contract (.expr e) fuel)
      (fun b => IndependentInput.run_contract (.block b) fuel) he hb fuel
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro env source
      rw [expr.eq_def]
      apply savesInputs_scope
      apply savesInputs_bind (savesInputs_identify _)
      intro key
      apply savesInputs_bind (savesInputs_scan _)
      intro ignored
      cases source <;> simp only [] <;> try exact savesInputs_bind (sc env _) (fun _ => savesInputs_unsupported)
      case literal value => cases value <;> first
        | exact savesInputs_pure _
        | exact savesInputs_widthLiteral _ _
        | exact savesInputs_bind (sc env _) (fun _ => savesInputs_unsupported)
      case negInt => exact savesInputs_pure _
      case negInteger8 => exact savesInputs_widthLiteral _ _
      case negInteger16 => exact savesInputs_widthLiteral _ _
      case negInteger32 => exact savesInputs_widthLiteral _ _
      case unit => exact savesInputs_pure _
      case «local» index =>
        apply savesInputs_bind (savesInputs_scan _)
        intro slot
        cases slot with
        | none => exact savesInputs_pure _
        | some slot => cases slot <;> first
          | exact savesInputs_pure _
          | exact savesInputs_pure _
      case paren child => exact he env child
      case constE _ child => exact he _ child
      case returnE _ child => exact savesInputs_bind (he env child) (fun _ => savesInputs_pure _)
      case neg type child =>
        split
        · exact savesInputs_bind (he env child) (fun value =>
            savesInputs_bind (savesInputs_negOwnTyped key type value) (fun _ => savesInputs_pure _))
        · exact savesInputs_bind (sc env _) (fun _ => savesInputs_unsupported)
      case binary op type left right =>
        split
        · apply savesInputs_bind (he env left)
          intro lhs
          split
          · exact savesInputs_bind (se right) (fun _ => savesInputs_pure _)
          · apply savesInputs_bind (he env right)
            intro rhs
            split
            · exact savesInputs_pure _
            · exact savesInputs_bind (savesInputs_own _ _ _ _ _) (fun _ => savesInputs_pure _)
        · exact savesInputs_bind (sc env _) (fun _ => savesInputs_unsupported)
      case and left right => exact hs env left right true
      case or left right => exact hs env left right false
      case call callee labels positions sources =>
        apply savesInputs_bind (savesInputs_scan _)
        intro recognized
        cases recognized with
        | none => exact savesInputs_bind (sc env _) (fun _ => savesInputs_unsupported)
        | some binding =>
          apply savesInputs_bind (se callee)
          intro _
          split
          · apply savesInputs_bind (savesInputs_selectArguments _ _ _ _ _ (he env) ses)
            intro selected
            exact savesInputs_bind (savesInputs_fixedOwn binding key selected) (fun _ => savesInputs_pure _)
          · apply savesInputs_bind (hargs env sources)
            intro values
            exact savesInputs_bind (savesInputs_scan _) (fun _ => savesInputs_pure _)
      case matchE _ source arms =>
        apply savesInputs_bind (he env source)
        intro tested
        split
        · exact savesInputs_bind (sa arms) (fun _ => savesInputs_pure _)
        · apply savesInputs_bind (savesInputs_scan _)
          intro known
          cases known with
          | some origin => exact savesInputs_bind (hr env _ arms) (fun _ => savesInputs_pure _)
          | none =>
            cases selected : tested.matchKind with
            | some kind =>
              exact savesInputs_bind (ha kind env source (tested.rangeKind kind) arms)
                (fun _ => savesInputs_pure _)
            | none =>
              exact savesInputs_bind (sa arms) (fun _ =>
                savesInputs_bind savesInputs_unsupported (fun _ => savesInputs_pure _))
      case not child => exact savesInputs_bind (he env child) (fun _ => savesInputs_pure _)
      case block body => exact hb env body
      case ite condition yes no =>
        apply savesInputs_bind (he env condition)
        intro tested
        apply savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun inner => hb inner no) (sb no))
          (fun _ => savesInputs_pure _)
      case elseIf condition yes no =>
        apply savesInputs_bind (he env condition)
        intro tested
        apply savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun inner => he inner no) (se no))
          (fun _ => savesInputs_pure _)
      case ifOnly condition yes =>
        apply savesInputs_bind (he env condition)
        intro tested
        apply savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun inner => hb inner yes) (sb yes))
        intro positive
        exact savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun _ => savesInputs_pure _) (savesInputs_pure _))
          (fun _ => savesInputs_pure _)
    · intro env left right truth
      rw [shortCircuit.eq_def]
      apply savesInputs_bind (he env left)
      intro tested
      apply savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun inner => he inner right) (se right))
      intro continued
      exact savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun _ => savesInputs_pure _) (savesInputs_pure _))
        (fun _ => savesInputs_pure _)
    · intro env body
      rw [block.eq_def]
      apply savesInputs_scope
      apply savesInputs_bind (savesInputs_scan _)
      intro ignored
      cases body with
      | empty => exact savesInputs_pure _
      | builderBind kind rest => exact savesInputs_bind (savesInputs_scan _) (fun inner => hb inner rest)
      | last source => exact he env source
      | lastBind _ _ source | lastDiscard source | lastPat _ _ _ source =>
        exact savesInputs_bind (he env source) (fun _ => savesInputs_pure _)
      | bind kind type source rest =>
        apply savesInputs_bind savesInputs_get
        intro start
        apply savesInputs_bind (he env source)
        intro head
        split
        · exact savesInputs_bind (sb rest) (fun _ => savesInputs_pure _)
        · exact savesInputs_bind (savesInputs_scan _) (fun inner =>
            savesInputs_bind (hb inner rest) (fun _ => savesInputs_pure _))
      | discard source rest | seq source rest | bindPat _ _ _ source rest =>
        apply savesInputs_bind (he env source)
        intro head
        split
        · exact savesInputs_bind (sb rest) (fun _ => savesInputs_pure _)
        · first
          | exact savesInputs_bind (hb env rest) (fun _ => savesInputs_pure _)
          | exact savesInputs_bind (savesInputs_scan _) (fun inner =>
              savesInputs_bind (hb inner rest) (fun _ => savesInputs_pure _))
    · intro kind env source normal arms
      rw [armListKind.eq_def]
      apply savesInputs_scope
      apply savesInputs_bind (savesInputs_scan _)
      intro ignored
      cases arms with
      | nil => exact savesInputs_pure _
      | cons alts guard body rest =>
        apply savesInputs_bind
        · apply savesInputs_scope
          apply savesInputs_bind (savesInputs_scan _)
          intro inner
          cases inner with
          | none => exact savesInputs_bind (so guard) (fun _ =>
              savesInputs_bind (sb body) (fun _ => savesInputs_pure _))
          | some inner =>
            cases guard with
            | none => exact hb inner body
            | some condition =>
              apply savesInputs_bind (he inner condition)
              intro tested
              exact savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun refined => hb refined body) (sb body))
                (fun _ => savesInputs_pure _)
        · intro first
          exact savesInputs_bind (ha kind env source normal rest) (fun _ => savesInputs_pure _)


    · intro env sources
      rw [arguments.eq_def]
      apply savesInputs_scope
      apply savesInputs_bind (savesInputs_scan _)
      intro _
      cases sources with
      | nil => exact savesInputs_pure _
      | cons source rest =>
        apply savesInputs_bind (he env source)
        intro head
        split
        · exact savesInputs_bind ((skip_keepsInputs fuel).2.2.1 rest).saves (fun _ => savesInputs_pure _)
        · exact savesInputs_bind (hargs env rest) (fun _ => savesInputs_pure _)
    · intro env input arms
      rw [resultArmList.eq_def]
      apply savesInputs_scope
      apply savesInputs_bind (savesInputs_scan _)
      intro _
      cases arms with
      | nil => exact savesInputs_pure _
      | cons alts guard body rest =>
        apply savesInputs_bind
        · apply savesInputs_scope
          apply savesInputs_bind (savesInputs_scan _)
          intro inner
          cases guard with
          | none => exact hb inner body
          | some condition =>
            apply savesInputs_bind (he inner condition)
            intro tested
            exact savesInputs_bind (savesInputs_branch _ _ _ _ _ _ (fun refined => hb refined body) (sb body))
              (fun _ => savesInputs_pure _)
        · intro first
          exact savesInputs_bind (hr env input rest) (fun _ => savesInputs_pure _)

theorem analysis_savesInputs_kind (fuel : Nat) :
    (∀ env source, SavesInputs (expr fuel env source)) ∧
    (∀ env left right truth, SavesInputs (shortCircuit fuel env left right truth)) ∧
    (∀ env body, SavesInputs (block fuel env body)) ∧
    (∀ kind env source normal arms, SavesInputs (armListKind fuel kind env source normal arms)) := by
  obtain ⟨he, hs, hb, ha, _, _⟩ := analysis_savesInputs_all fuel
  exact ⟨he, hs, hb, ha⟩

/-- Integer64 の既存の入口と言明を保つ。 -/
theorem analysis_savesInputs (fuel : Nat) :
    (∀ env source, SavesInputs (expr fuel env source)) ∧
    (∀ env left right truth, SavesInputs (shortCircuit fuel env left right truth)) ∧
    (∀ env body, SavesInputs (block fuel env body)) ∧
    (∀ env source normal arms, SavesInputs (armList fuel env source normal arms))  := by
  obtain ⟨he, hs, hb, ha⟩ := analysis_savesInputs_kind fuel
  exact ⟨he, hs, hb, ha .integer64⟩

/-- 入力自身の候補に加え、内部で保存した入力の健全性も保持する。 -/
theorem IndependentInput.run_saves (input : IndependentInput) (fuel : Nat) (env : AbstractEnv) :
    SavesInputs (input.run fuel env) := by
  cases input with
  | expr source => exact (analysis_savesInputs fuel).1 env source
  | block body => exact (analysis_savesInputs fuel).2.2.1 env body

/-- Expr・Block の独立解析に、入力列の逐次合成と全要素の不変条件を接続する。 -/
theorem independent_saves (fuel : Nat) (env : AbstractEnv) (input : IndependentInput) :
    SavesInputs (independent fuel env input) :=
  independentWith_saves input env (input.run fuel) (input.run_contract fuel) (input.run_saves fuel)

/-- 復帰は内部の実消費・次キー・対応をそのまま使い、本体を終了しない。 -/
theorem captureIndependent_shared (input : IndependentInput) (env : AbstractEnv)
    (work : AbstractEnv → Analysis BaseApprox) (limits : Limits) (parent ready final : Context)
    (initial : AbstractEnv) (result : Except Halt BaseApprox)
    (prepared : prepareIndependent env limits { parent with warningsRev := [], unsupported := false } =
      (.ok initial, ready)) (run : work initial limits ready = (result, final)) :
    let output := captureIndependent input env work limits parent
    output.2.budget = final.budget ∧ output.2.next = final.next ∧
    output.2.identitiesRev = final.identitiesRev ∧ output.1 = result.map (fun _ => ()) := by
  unfold captureIndependent
  dsimp only
  rw [prepared]
  dsimp only
  rw [run]
  exact ⟨rfl, rfl, rfl, rfl⟩

/-- Expr は元の根を数え、Block は容器を数えない同じ番号列へ接続する。 -/
theorem independent_walk (fuel : Nat) (env : AbstractEnv) (input : IndependentInput) :
    Walk (independent fuel env input) (input.syntacticReach.map Prod.snd) := by
  apply independentWith_walk
  intro initial
  cases input with
  | expr source => simpa only [IndependentInput.run, IndependentInput.syntacticReach, syntacticReachExpr_sources]
      using (analysis_walk fuel).1 initial source
  | block body => simpa only [IndependentInput.run, IndependentInput.syntacticReach, syntacticReachBlock_sources]
      using (analysis_walk fuel).2.2.1 initial body

/-- 式入口から保存された入れ子の入力にも、成功・停止を問わず保証を与える。 -/
theorem analyzeExpr_independent_sound (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (source : Expr) :
    ∀ entry ∈ (analyzeExpr limits state fuel env key source).context.independentRev, entry.Sound := by
  have saved := ((analysis_savesInputs fuel).1 (resetRanges env) source).all limits
    { budget := state, next := key } (by simp)
  exact saved

/-- 本体の入口環境の忘却も、入れ子の健全な追加分と逐次合成する。 -/
theorem bodyWork_saves (fuel : Nat) (seed : BodySeed) : SavesInputs (bodyWork fuel seed) := by
  unfold bodyWork
  apply savesInputs_scope
  exact savesInputs_bind (savesInputs_scan _) (fun initial =>
    (analysis_savesInputs fuel).1 initial (bodyRoot seed.body))

/-- 全体上限の事前停止・忘却中の停止を含め、本体から保存した全入力を保証する。 -/
theorem analyzeBody_independent_sound (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) :
    ∀ entry ∈ (analyzeBody limits state fuel definition seed).context.independentRev, entry.Sound := by
  unfold analyzeBody
  split
  · simp [report]
  · split
    · simp [report]
    · have saved := (bodyWork_saves fuel seed).all limits
        { budget := state, next := bodyRootKey definition } (by simp)
      cases run : bodyWork fuel seed limits { budget := state, next := bodyRootKey definition } with
      | mk result final => simpa only [run, report] using saved

end Benitoite.Interval.BudgetAnalysis
