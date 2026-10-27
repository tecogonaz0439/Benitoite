import Benitoite.Interval.BudgetReach

/-!
# 独立した入力の保証と保存列の不変条件

実行定義は BudgetIndependentRun と BudgetAnalyze に置き、ここでは解析の証明を使う。
入力自身の保証と、番号だけの走査が入力の保存列を保つ性質を定める。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 容器には番号を加えず、式の元の先行順を使う。 -/
def IndependentInput.syntacticReach : IndependentInput → List (Bool × Expr)
  | .expr source => syntacticReachExpr source
  | .block body => syntacticReachBlock body

/-- 独立入力自身の評価関係。親の未知の評価の trace とは区別する。 -/
def IndependentInput.Evaluates (input : IndependentInput) (concrete : ConcreteEnv)
    (key : OperationKey) (type : Ty) (outcome : EvalOutcome) (trace : EvalTrace) : Prop :=
  match input with
  | .expr source => EvalPartial concrete ⟨source, type, key⟩ outcome trace
  | .block body => EvalBlock concrete key body type outcome trace

/-- 停止時の正常値は Top とし、保存に成功した入力自身の候補を付ける。 -/
def IndependentResult.approx (entry : IndependentResult) : BaseApprox :=
  { (match entry.result with | .ok value => value | .error _ => baseUnknown) with
    warnings := entry.warningsRev }

/-- 入力ごとの保証。位置・構文的な到達可能性は評価導出に依存しない。 -/
def IndependentResult.Sound (entry : IndependentResult) : Prop :=
  (∀ warning ∈ entry.warningsRev, InSyntacticReach entry.key entry.input.syntacticReach warning) ∧
  match entry.initial with
  | none => (∃ reason, entry.result = .error reason) ∧ entry.warningsRev = []
  | some env => forget env = env ∧ ∀ concrete type outcome trace, Models env concrete →
      entry.input.Evaluates concrete entry.key type outcome trace →
      NormalCovered entry.approx outcome ∧
      ∀ warning ∈ entry.warningsRev, ∀ event, Reached trace warning event →
        event.result = .rejected warning.cause.toFailure

/-- 範囲の保証には、元のキーでの構文と対象演算の一致も含まれる。 -/
theorem IndependentResult.Sound.located {entry : IndependentResult} (h : entry.Sound)
    {warning : IntervalWarning} (member : warning ∈ entry.warningsRev) :
    LocatedIn entry.key (entry.input.syntacticReach.map Prod.snd) warning :=
  (h.1 warning member).located

/-- 忘却の成功値は forget と一致し、警告列・保存入力・次キーは変えない。 -/
theorem prepareIndependent_spec (env : AbstractEnv) (limits : Limits) (ctx : Context) :
    (prepareIndependent env limits ctx).2.warningsRev = ctx.warningsRev ∧
    (prepareIndependent env limits ctx).2.independentRev = ctx.independentRev ∧
    (prepareIndependent env limits ctx).2.next = ctx.next ∧
    ∀ initial, (prepareIndependent env limits ctx).1 = .ok initial → initial = forget env := by
  unfold prepareIndependent
  cases run : scan (BudgetScan.forgetEnv env) limits ctx with
  | mk outcome final =>
    have saved := scan_preserves_saved (BudgetScan.forgetEnv env) limits ctx
    have inputs : final.independentRev = ctx.independentRev := by
      unfold scan at run
      cases h : (BudgetScan.forgetEnv env).run limits ctx.budget <;> simp [h] at run <;>
        cases run <;> rfl
    have same := success_scan_agrees _ _ (BudgetScan.forgetEnv_agrees env)
    cases outcome with
    | error reason =>
      exact ⟨by simpa only [run] using saved.1, inputs,
        by simpa only [run] using saved.2.2.1, by intro value ok; cases ok⟩
    | ok initial =>
      exact ⟨by simpa only [run] using saved.1, inputs,
        by simpa only [run] using saved.2.2.1, fun value ok => by
          cases ok; exact same limits ctx initial (by simp [run])⟩

/-- 停止を含め、一つの走査が入力の保存列へ健全な追加分だけを加える条件。 -/
def SavesInputs (work : Analysis α) : Prop :=
  ∀ limits ctx, ListExtension IndependentResult.Sound ctx.independentRev
    (work limits ctx).2.independentRev

/-- 既存列の不変条件を保ち、今回の追加分だけから全出力の不変条件を得る。 -/
theorem SavesInputs.all {work : Analysis α} (h : SavesInputs work) (limits : Limits)
    (ctx : Context) (before : ∀ entry ∈ ctx.independentRev, entry.Sound) :
    ∀ entry ∈ (work limits ctx).2.independentRev, entry.Sound := by
  intro entry member
  exact ((h limits ctx).member member).elim (before entry) id

/-- 逐次合成は、前半で止まれば後半へ進まず、保存済み入力をそのまま残す。 -/
theorem savesInputs_bind {first : Analysis α} {next : α → Analysis β}
    (hf : SavesInputs first) (hn : ∀ value, SavesInputs (next value)) :
    SavesInputs (first >>= next) := by
  intro limits ctx
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases run : first limits ctx with
  | mk outcome middle =>
    have saved := hf limits ctx
    rw [run] at saved
    cases outcome with
    | error reason => exact saved
    | ok value => exact saved.trans (hn value limits middle)

/-- 保存列を変更しない既存の処理も、入力列の合成へ組み込める。 -/
def KeepsInputs (work : Analysis α) : Prop :=
  ∀ limits ctx, (work limits ctx).2.independentRev = ctx.independentRev

theorem KeepsInputs.saves {work : Analysis α} (h : KeepsInputs work) : SavesInputs work := by
  intro limits ctx
  rw [h limits ctx]
  exact ListExtension.refl _ _

theorem keepsInputs_pure (value : α) : KeepsInputs (pure value) := by intro limits ctx; rfl

theorem keepsInputs_get : KeepsInputs (get : Analysis Context) := by intro limits ctx; rfl

theorem savesInputs_get : SavesInputs (get : Analysis Context) := keepsInputs_get.saves

theorem keepsInputs_throw (reason : Halt) : KeepsInputs (throw reason : Analysis α) := by intro limits ctx; rfl

theorem keepsInputs_scan (work : BudgetScan.Scan α) : KeepsInputs (scan work) := by
  intro limits ctx
  unfold scan
  cases work.run limits ctx.budget <;> rfl

theorem keepsInputs_bind {first : Analysis α} {next : α → Analysis β}
    (hf : KeepsInputs first) (hn : ∀ value, KeepsInputs (next value)) :
    KeepsInputs (first >>= next) := by
  intro limits ctx
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases run : first limits ctx with
  | mk outcome middle =>
    have same := hf limits ctx
    rw [run] at same
    cases outcome with
    | error reason => exact same
    | ok value => exact (hn value limits middle).trans same

theorem keepsInputs_scope {work : Unit → Analysis α} (h : KeepsInputs (work ())) :
    KeepsInputs (scope work) := by
  intro limits ctx
  unfold scope
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    have same := keepsInputs_scan (BudgetScan.allocate .stackFrame) limits ctx
    rw [run] at same
    cases outcome with
    | error reason => exact same
    | ok value =>
      cases value
      cases inner : work () limits entered with
      | mk result final =>
        have saved := h limits entered
        rw [inner] at saved
        simpa only [inner] using saved.trans same

theorem keepsInputs_numbering {work : Unit → Analysis α} (h : KeepsInputs (work ())) :
    KeepsInputs (numbering work) := by
  intro limits ctx
  simpa only [numbering_context] using h limits ctx

theorem keepsInputs_modify (f : Context → Context)
    (h : ∀ ctx, (f ctx).independentRev = ctx.independentRev) :
    KeepsInputs (modify f : Analysis Unit) := by
  intro limits ctx
  exact h ctx

theorem keepsInputs_identify (source : Expr) : KeepsInputs (identify source) := by
  unfold identify
  apply keepsInputs_bind (first := get) (by intro limits ctx; rfl)
  intro ctx
  apply keepsInputs_bind (keepsInputs_scan _)
  intro value
  apply keepsInputs_bind (keepsInputs_modify _ (by intros; rfl))
  intro ignored
  exact keepsInputs_pure _

theorem keepsInputs_saveWarnings (warnings : List IntervalWarning) : KeepsInputs (saveWarnings warnings) := by
  induction warnings with
  | nil => exact keepsInputs_pure _
  | cons warning rest ih =>
    rw [saveWarnings]
    apply keepsInputs_scope
    apply keepsInputs_bind (keepsInputs_scan _)
    intro ignored
    apply keepsInputs_bind (keepsInputs_modify _ (by intros; rfl))
    intro ignored
    exact ih

theorem keepsInputs_unsupported : KeepsInputs unsupported := by
  unfold unsupported
  apply keepsInputs_bind (keepsInputs_modify _ (by intros; rfl))
  intro ignored
  exact keepsInputs_pure _

theorem keepsInputs_own (key op type left right) : KeepsInputs (own key op type left right) := by
  unfold own
  apply keepsInputs_bind (keepsInputs_saveWarnings _)
  intro ignored
  exact keepsInputs_pure _

theorem keepsInputs_fixedOwn (binding key selected) : KeepsInputs (fixedOwn binding key selected) := by
  unfold fixedOwn
  exact keepsInputs_bind (keepsInputs_saveWarnings _) (fun _ => keepsInputs_pure _)

theorem keepsInputs_negOwn (key child) : KeepsInputs (negOwn key child) := by
  unfold negOwn
  exact keepsInputs_bind (keepsInputs_saveWarnings _) (fun _ => keepsInputs_pure _)

theorem keepsInputs_negOwnTyped (key type child) : KeepsInputs (negOwnTyped key type child) := by
  unfold negOwnTyped
  exact keepsInputs_bind (keepsInputs_saveWarnings _) (fun _ => keepsInputs_pure _)

theorem keepsInputs_branch (env source tested truth run skip)
    (hr : ∀ inner, KeepsInputs (run inner)) (hs : KeepsInputs (skip ())) :
    KeepsInputs (branch env source tested truth run skip) := by
  unfold branch
  apply keepsInputs_scope
  apply keepsInputs_bind (keepsInputs_scan _)
  intro inner
  cases inner with
  | none => exact keepsInputs_bind hs (fun _ => keepsInputs_pure _)
  | some inner => exact hr inner

/-- 番号だけを辿る処理は、既に保存した独立入力を変更しない。 -/
theorem skip_keepsInputs (fuel : Nat) :
    (∀ source, KeepsInputs (skipExpr fuel source)) ∧
    (∀ source, KeepsInputs (skipChildren fuel source)) ∧
    (∀ sources, KeepsInputs (skipExprs fuel sources)) ∧
    (∀ args, KeepsInputs (skipHoles fuel args)) ∧
    (∀ body, KeepsInputs (skipBlock fuel body)) ∧
    (∀ arms, KeepsInputs (skipArms fuel arms)) ∧
    (∀ clauses, KeepsInputs (skipClauses fuel clauses)) ∧
    (∀ value, KeepsInputs (skipOptional fuel value)) := by
  induction fuel with
  | zero => exact ⟨fun _ => keepsInputs_throw _, fun _ => keepsInputs_throw _,
      fun _ => keepsInputs_throw _, fun _ => keepsInputs_throw _, fun _ => keepsInputs_throw _,
      fun _ => keepsInputs_throw _, fun _ => keepsInputs_throw _, fun _ => keepsInputs_throw _⟩
  | succ fuel ih =>
    obtain ⟨he, hc, hes, hh, hb, ha, hcl, ho⟩ := ih
    refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩
    · intro source
      rw [skipExpr.eq_def]
      exact keepsInputs_numbering (keepsInputs_scope
        (keepsInputs_bind (keepsInputs_identify source) (fun _ => hc source)))
    · intro source
      rw [skipChildren.eq_def]
      cases source <;> first
        | exact keepsInputs_pure _
        | exact he _
        | exact hb _
        | exact hes _
        | exact hh _
        | exact keepsInputs_bind (he _) (fun _ => he _)
        | exact keepsInputs_bind (hb _) (fun _ => hb _)
        | exact keepsInputs_bind (he _) (fun _ => hes _)
        | exact keepsInputs_bind (he _) (fun _ => hh _)
        | exact keepsInputs_bind (hes _) (fun _ => hes _)
        | exact keepsInputs_bind (he _) (fun _ => hb _)
        | exact keepsInputs_bind (he _) (fun _ => ha _)
        | exact keepsInputs_bind (he _) (fun _ => ho _)
        | exact keepsInputs_bind (hb _) (fun _ => hcl _)
        | exact keepsInputs_bind (he _) (fun _ => keepsInputs_bind (hb _) (fun _ => hb _))
        | exact keepsInputs_bind (he _) (fun _ => keepsInputs_bind (hb _) (fun _ => he _))
        | exact keepsInputs_bind (he _) (fun _ => keepsInputs_bind (hes _) (fun _ =>
            keepsInputs_bind (he _) (fun _ => hes _)))
    · intro sources
      rw [skipExprs.eq_def]
      apply keepsInputs_numbering
      apply keepsInputs_scope
      apply keepsInputs_bind (keepsInputs_scan _)
      intro ignored
      cases sources with
      | nil => exact keepsInputs_pure _
      | cons source rest => exact keepsInputs_bind (he source) (fun _ => hes rest)
    · intro args
      rw [skipHoles.eq_def]
      apply keepsInputs_numbering
      apply keepsInputs_scope
      apply keepsInputs_bind (keepsInputs_scan _)
      intro ignored
      cases args with
      | nil => exact keepsInputs_pure _
      | expr _ _ source rest => exact keepsInputs_bind (he source) (fun _ => hh rest)
      | hole _ _ _ rest => exact hh rest
    · intro body
      rw [skipBlock.eq_def]
      apply keepsInputs_numbering
      apply keepsInputs_scope
      apply keepsInputs_bind (keepsInputs_scan _)
      intro ignored
      cases body <;> first
        | exact keepsInputs_pure _
        | exact hb _
        | exact he _
        | exact keepsInputs_bind (he _) (fun _ => hb _)
    · intro arms
      rw [skipArms.eq_def]
      apply keepsInputs_numbering
      apply keepsInputs_scope
      apply keepsInputs_bind (keepsInputs_scan _)
      intro ignored
      cases arms with
      | nil => exact keepsInputs_pure _
      | cons _ guard body rest => exact keepsInputs_bind (ho guard) (fun _ =>
          keepsInputs_bind (hb body) (fun _ => ha rest))
    · intro clauses
      rw [skipClauses.eq_def]
      apply keepsInputs_numbering
      apply keepsInputs_scope
      apply keepsInputs_bind (keepsInputs_scan _)
      intro ignored
      cases clauses with
      | nil => exact keepsInputs_pure _
      | cons _ _ _ body rest _ => exact keepsInputs_bind (hb body) (fun _ => hcl rest)
    · intro value
      rw [skipOptional.eq_def]
      cases value with
      | none => exact keepsInputs_pure _
      | some source => exact he source

end Benitoite.Interval.BudgetAnalysis
