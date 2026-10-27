import Benitoite.Interval.CallReachSound
import Benitoite.Interval.BudgetIndependentSound

/-!
# 独立入力にも未認定 call の除外を保存する

既存の IndependentResult.Sound を変更せず、同じ保存列へ別の不変条件を与える。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

def CallReach.input (env : AbstractEnv) : IndependentInput → CallReach.Scope
  | .expr source => CallReach.expr env source
  | .block body => CallReach.block env body

/-- 保存した入力自身の環境・元キーで認定し、未認定 call の内側を候補から除く。 -/
def IndependentResult.CallsRecognized (entry : IndependentResult) : Prop :=
  match entry.initial with
  | none => entry.warningsRev = []
  | some env => ∀ warning ∈ entry.warningsRev, (CallReach.input env entry.input).allows entry.key warning

namespace CallExclusion

def IndependentContract (input : IndependentInput) (work : AbstractEnv → Analysis BaseApprox) : Prop :=
  ∀ env limits ctx, ctx.warningsRev = [] → forget env = env →
    IndependentResult.CallsRecognized ⟨input, ctx.next, some env, (work env limits ctx).1,
      (work env limits ctx).2.warningsRev, (work env limits ctx).2.unsupported⟩

theorem run_contract (input : IndependentInput) (fuel : Nat) :
    IndependentContract input (input.run fuel) := by
  intro env limits ctx empty _ warning member
  have h : ListExtension ((CallReach.input env input).allows ctx.next) ctx.warningsRev
      (input.run fuel env limits ctx).2.warningsRev := by
    cases input with
    | expr source => exact expr_warning_call_reach fuel env source limits ctx
    | block body => exact block_warning_call_reach fuel env body limits ctx
  exact (h.member member).resolve_left (by simp [empty])

def SavesInputs (work : Analysis α) : Prop :=
  ∀ limits ctx, ListExtension IndependentResult.CallsRecognized ctx.independentRev
    (work limits ctx).2.independentRev

theorem SavesInputs.all {work : Analysis α} (h : SavesInputs work) (limits : Limits)
    (ctx : Context) (before : ∀ entry ∈ ctx.independentRev, entry.CallsRecognized) :
    ∀ entry ∈ (work limits ctx).2.independentRev, entry.CallsRecognized := by
  intro entry member
  exact ((h limits ctx).member member).elim (before entry) id

theorem keeps_saves {work : Analysis α} (h : KeepsInputs work) : SavesInputs work := by
  intro limits ctx
  rw [h limits ctx]
  exact ListExtension.refl _ _

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

theorem savesInputs_get : SavesInputs (get : Analysis Context) := keeps_saves keepsInputs_get

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
        change ready.warningsRev = []
        exact same.1
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
    | error reason => simpa only [same] using ListExtension.refl IndependentResult.CallsRecognized ctx.independentRev
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
  exact savesInputs_bind (keeps_saves (keepsInputs_scan _))
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
  | zero => exact keeps_saves (keepsInputs_throw _)
  | succ fuel =>
    obtain ⟨_, _, _, _, sb, sa, sc, _⟩ := skip_keepsInputs fuel
    exact unknownChildren_property (@SavesInputs) (fun value => keeps_saves (keepsInputs_pure value))
      (fun reason => keeps_saves (keepsInputs_throw reason))
      (fun _ _ hf hn => savesInputs_bind hf hn) (fun _ h => savesInputs_scope h)
      (fun work => keeps_saves (keepsInputs_scan work)) runExpr runBlock
      (fun env e => independentWith_saves (.expr e) env _ (ce e) (fun initial => he initial e))
      (fun env b => independentWith_saves (.block b) env _ (cb b) (fun initial => hb initial b))
      fuel (fun b => keeps_saves (sb b)) (fun a => keeps_saves (sa a)) (fun c => keeps_saves (sc c)) env source

theorem savesInputs_pure (value : α) : SavesInputs (pure value) :=
  keeps_saves (keepsInputs_pure value)

theorem savesInputs_throw (reason : Halt) : SavesInputs (throw reason : Analysis α) :=
  keeps_saves (keepsInputs_throw reason)

theorem savesInputs_scan (work : BudgetScan.Scan α) : SavesInputs (scan work) :=
  keeps_saves (keepsInputs_scan work)

theorem savesInputs_identify (source : Expr) : SavesInputs (identify source) :=
  keeps_saves (keepsInputs_identify source)

theorem savesInputs_unsupported : SavesInputs unsupported :=
  keeps_saves keepsInputs_unsupported

/-- 幅付きの葉は番号・警告・独立入力を追加しない。 -/
theorem savesInputs_widthLiteral (kind : IntKind) (value : Int) :
    SavesInputs (widthLiteral kind value) := by
  unfold widthLiteral
  split
  · exact savesInputs_pure _
  · exact savesInputs_unsupported

theorem savesInputs_negOwn (key child) : SavesInputs (negOwn key child) :=
  keeps_saves (keepsInputs_negOwn key child)

theorem savesInputs_negOwnTyped (key type child) : SavesInputs (negOwnTyped key type child) :=
  keeps_saves (keepsInputs_negOwnTyped key type child)

theorem savesInputs_own (key op type left right) : SavesInputs (own key op type left right) :=
  keeps_saves (keepsInputs_own key op type left right)

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
  keeps_saves (keepsInputs_fixedOwn binding key selected)

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
    have ses := fun sources => keeps_saves ((skip_keepsInputs fuel).2.2.1 sources)
    have se := fun e => keeps_saves (se e)
    have sb := fun b => keeps_saves (sb b)
    have sa := fun a => keeps_saves (sa a)
    have so := fun o => keeps_saves (so o)
    have sc := unknownChildren_saves (expr fuel) (block fuel)
      (fun e => run_contract (.expr e) fuel)
      (fun b => run_contract (.block b) fuel) he hb fuel
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
        · exact savesInputs_bind (keeps_saves ((skip_keepsInputs fuel).2.2.1 rest)) (fun _ => savesInputs_pure _)
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
theorem run_saves (input : IndependentInput) (fuel : Nat) (env : AbstractEnv) :
    SavesInputs (input.run fuel env) := by
  cases input with
  | expr source => exact (analysis_savesInputs fuel).1 env source
  | block body => exact (analysis_savesInputs fuel).2.2.1 env body

/-- Expr・Block の独立解析に、入力列の逐次合成と全要素の不変条件を接続する。 -/
theorem independent_saves (fuel : Nat) (env : AbstractEnv) (input : IndependentInput) :
    SavesInputs (independent fuel env input) :=
  independentWith_saves input env (input.run fuel) (run_contract input fuel) (run_saves input fuel)


end CallExclusion

/-- 保存された全独立入力に、従来の Sound と別に call の認定を保証する。 -/
theorem analyzeExpr_independent_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (env : AbstractEnv) (key : OperationKey) (source : Expr) :
    ∀ entry ∈ (analyzeExpr limits state fuel env key source).context.independentRev,
      entry.CallsRecognized := by
  exact CallExclusion.SavesInputs.all
    ((CallExclusion.analysis_savesInputs fuel).1 (resetRanges env) source) limits
    { budget := state, next := key } (by simp)

theorem CallExclusion.bodyWork_saves (fuel : Nat) (seed : BodySeed) :
    CallExclusion.SavesInputs (bodyWork fuel seed) := by
  unfold bodyWork
  apply CallExclusion.savesInputs_scope
  exact CallExclusion.savesInputs_bind (CallExclusion.savesInputs_scan _) (fun initial =>
    (CallExclusion.analysis_savesInputs fuel).1 initial (bodyRoot seed.body))

/-- 本体の親・独立入力の保証は、停止後に保存された入力にも同時に成り立つ。 -/
theorem analyzeBody_independent_call_reach (limits : Limits) (state : Budget.State) (fuel : Nat)
    (definition : String) (seed : BodySeed) :
    ∀ entry ∈ (analyzeBody limits state fuel definition seed).context.independentRev,
      entry.CallsRecognized := by
  unfold analyzeBody
  split
  · simp [report]
  · split
    · simp [report]
    · have saved := CallExclusion.SavesInputs.all (CallExclusion.bodyWork_saves fuel seed) limits
        { budget := state, next := bodyRootKey definition } (by simp)
      cases run : bodyWork fuel seed limits { budget := state, next := bodyRootKey definition } with
      | mk result final => simpa only [run, report] using saved

end Benitoite.Interval.BudgetAnalysis
