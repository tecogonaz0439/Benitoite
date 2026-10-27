import Benitoite.Interval.BudgetAnalyze

/-!
# 予算付き解析の成功値と保存列の合成

入力からある保存列には新しい部分木の性質を要求しない。
成功値の性質と、成功・停止に共通の追加分の性質を別々に合成する。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 逆順の保存列。既存の接尾辞と今回の追加分を区別する。 -/
def ListExtension (good : α → Prop) (before after : List α) : Prop :=
  ∃ added, after = added ++ before ∧ ∀ value ∈ added, good value

theorem ListExtension.refl (good : α → Prop) (before : List α) :
    ListExtension good before before := ⟨[], rfl, by simp⟩

theorem ListExtension.trans {good : α → Prop} {first middle last : List α}
    (left : ListExtension good first middle) (right : ListExtension good middle last) :
    ListExtension good first last := by
  obtain ⟨xs, hx, gx⟩ := left
  obtain ⟨ys, hy, gy⟩ := right
  refine ⟨ys ++ xs, by simp [hy, hx, List.append_assoc], ?_⟩
  intro value member
  rcases List.mem_append.mp member with h | h
  · exact gy value h
  · exact gx value h

theorem ListExtension.mono {good better : α → Prop} {before after : List α}
    (h : ListExtension good before after) (imp : ∀ value, good value → better value) :
    ListExtension better before after := by
  obtain ⟨added, eq, all⟩ := h
  exact ⟨added, eq, fun value member => imp value (all value member)⟩

/-- 出力の要素が元からあった場合には、新しい追加分の性質を結論しない。 -/
theorem ListExtension.member {good : α → Prop} {before after : List α}
    (h : ListExtension good before after) {value : α} (member : value ∈ after) :
    value ∈ before ∨ good value := by
  obtain ⟨added, eq, all⟩ := h
  rw [eq] at member
  rcases List.mem_append.mp member with new | old
  · exact Or.inr (all value new)
  · exact Or.inl old

/-- 保存列だけの関係であり、予算の返却や次キーの変更を制限しない。 -/
def Saved (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop)
    (before after : Context) : Prop :=
  ListExtension warning before.warningsRev after.warningsRev ∧
  ListExtension identity before.identitiesRev after.identitiesRev

theorem Saved.refl (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop)
    (ctx : Context) : Saved warning identity ctx ctx :=
  ⟨ListExtension.refl _ _, ListExtension.refl _ _⟩

theorem Saved.trans {warning : IntervalWarning → Prop} {identity : OperationKey × Expr → Prop}
    {first middle last : Context} (left : Saved warning identity first middle)
    (right : Saved warning identity middle last) : Saved warning identity first last :=
  ⟨left.1.trans right.1, left.2.trans right.2⟩

/-- 成功値だけに post を要求し、保存列の追加分には成否によらず性質を要求する。 -/
def Spec (work : Analysis α) (limits : Limits) (ctx : Context) (post : α → Prop)
    (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop) : Prop :=
  Saved warning identity ctx (work limits ctx).2 ∧
  ∀ value, (work limits ctx).1 = .ok value → post value

theorem spec_mono {work : Analysis α} {limits : Limits} {ctx : Context}
    {post better : α → Prop} {warning warning' : IntervalWarning → Prop}
    {identity identity' : OperationKey × Expr → Prop}
    (h : Spec work limits ctx post warning identity)
    (hp : ∀ value, post value → better value)
    (hw : ∀ value, warning value → warning' value)
    (hi : ∀ value, identity value → identity' value) :
    Spec work limits ctx better warning' identity' :=
  ⟨⟨h.1.1.mono hw, h.1.2.mono hi⟩, fun value ok => hp value (h.2 value ok)⟩

theorem spec_pure (value : α) (limits : Limits) (ctx : Context)
    (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop) :
    Spec (pure value) limits ctx (· = value) warning identity := by
  exact ⟨Saved.refl _ _ _, fun _ eq => Except.ok.inj eq.symm⟩

theorem spec_throw (reason : Halt) (limits : Limits) (ctx : Context)
    (post : α → Prop) (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop) :
    Spec (throw reason) limits ctx post warning identity := by
  exact ⟨Saved.refl _ _ _, by intro value eq; cases eq⟩

/-- 先行の停止時には後続を要求しない。成功時の中間状態を後続へ渡す。 -/
theorem spec_bind {first : Analysis α} {next : α → Analysis β} {limits : Limits} {ctx : Context}
    {post : α → Prop} {result : β → Prop} {warning : IntervalWarning → Prop}
    {identity : OperationKey × Expr → Prop}
    (hfirst : Spec first limits ctx post warning identity)
    (hnext : ∀ value middle, first limits ctx = (.ok value, middle) → post value →
      Spec (next value) limits middle result warning identity) :
    Spec (first >>= next) limits ctx result warning identity := by
  unfold Spec
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases eq : first limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason =>
      simp only [ExceptT.bindCont, pure, StateT.pure]
      exact ⟨by simpa only [eq] using hfirst.1, by intro value ok; cases ok⟩
    | ok value =>
      simp only [ExceptT.bindCont]
      have saved : Saved warning identity ctx middle := by simpa only [eq] using hfirst.1
      have hp := hfirst.2 value (by simp [eq])
      have hn := hnext value middle eq hp
      exact ⟨saved.trans hn.1, hn.2⟩

/-- 局所走査は保存列を増やさず、成功値の性質だけを引き継ぐ。 -/
theorem spec_scan (work : BudgetScan.Scan α) (limits : Limits) (ctx : Context)
    (post : α → Prop) (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop)
    (success : ∀ value state, work.run limits ctx.budget = .ok value state → post value) :
    Spec (scan work) limits ctx post warning identity := by
  unfold Spec scan
  cases eq : work.run limits ctx.budget with
  | ok value state =>
    refine ⟨Saved.refl _ _ _, ?_⟩
    intro result ok
    cases ok
    exact success value state eq
  | stopped reason state => exact ⟨Saved.refl _ _ _, by intro value ok; cases ok⟩

/-- 既存の局所規則との一致を成功値の性質に利用できる。 -/
theorem spec_scan_agrees (work : BudgetScan.Scan α) (expected : α)
    (agrees : BudgetScan.Agrees work expected) (limits : Limits) (ctx : Context)
    (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop) :
    Spec (scan work) limits ctx (· = expected) warning identity :=
  spec_scan work limits ctx _ _ _ (agrees limits ctx.budget)

/-- 枠の確保で止まれば追加は空。内部の成否にかかわらず保存列を引き継ぐ。 -/
theorem spec_scope {work : Unit → Analysis α} {limits : Limits} {ctx : Context}
    {post : α → Prop} {warning : IntervalWarning → Prop} {identity : OperationKey × Expr → Prop}
    (body : ∀ entered, scan (BudgetScan.allocate .stackFrame) limits ctx = (.ok (), entered) →
      Spec (work ()) limits entered post warning identity) :
    Spec (scope work) limits ctx post warning identity := by
  have enteredSaved := (spec_scan (BudgetScan.allocate .stackFrame) limits ctx
    (fun _ => True) warning identity (by intros; trivial)).1
  unfold Spec scope
  cases eq : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    cases outcome with
    | error reason =>
      exact ⟨by simpa only [eq] using enteredSaved, by intro value ok; cases ok⟩
    | ok value =>
      cases value
      have hb := body entered eq
      have hs : Saved warning identity ctx entered := by simpa only [eq] using enteredSaved
      cases run : work () limits entered with
      | mk outcome final =>
        have all := hs.trans hb.1
        exact ⟨by simpa only [run, Saved] using all, by
          intro value ok
          exact hb.2 value (by simpa only [run] using ok)⟩

/-- 停止の分類は成功値も保存列も変えない。 -/
theorem spec_numbering {work : Unit → Analysis α} {limits : Limits} {ctx : Context}
    {post : α → Prop} {warning : IntervalWarning → Prop} {identity : OperationKey × Expr → Prop}
    (h : Spec (work ()) limits ctx post warning identity) :
    Spec (numbering work) limits ctx post warning identity := by
  refine ⟨by simpa only [numbering_context] using h.1, ?_⟩
  intro value ok
  unfold numbering at ok
  cases run : work () limits ctx with
  | mk outcome final =>
    cases outcome with
    | ok result => exact h.2 value (by simpa only [run] using ok)
    | error reason =>
      cases reason with
      | depth => simp [run] at ok
      | budget reason => cases reason <;> simp [run] at ok

/-- 一出現の完走時には、キー・次番号と追加した対応を正確に得る。 -/
theorem identify_success (source : Expr) (limits : Limits) (ctx : Context)
    {value : OperationKey} {final : Context} (ok : identify source limits ctx = (.ok value, final)) :
    value = ctx.next ∧ final.next = { ctx.next with surfacePreorder := ctx.next.surfacePreorder + 1 } ∧
    final.warningsRev = ctx.warningsRev ∧
    final.identitiesRev = (ctx.next, source) :: ctx.identitiesRev ∧
    final.unsupported = ctx.unsupported := by
  unfold identify at ok
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at ok
  change ((scan (BudgetScan.identify ctx.next) >>= fun (key, next) => do
    modify fun ctx => { ctx with next := next, identitiesRev := (key, source) :: ctx.identitiesRev }
    pure key) limits ctx) = _ at ok
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind, scan] at ok
  cases eq : (BudgetScan.identify ctx.next).run limits ctx.budget with
  | stopped reason state =>
    simp only [eq, ExceptT.bindCont, pure, StateT.pure] at ok
    cases ok
  | ok result state =>
    have agrees := BudgetScan.identify_agrees ctx.next limits ctx.budget result state eq
    simp only [eq, agrees, ExceptT.bindCont] at ok
    cases ok
    exact ⟨rfl, rfl, rfl, rfl, rfl⟩

/-- 成功時だけ一件を追加する。停止時には元の対応・警告・次番号を保つ。 -/
theorem identify_stopped (source : Expr) (limits : Limits) (ctx : Context)
    {reason : Halt} {final : Context} (stop : identify source limits ctx = (.error reason, final)) :
    final.warningsRev = ctx.warningsRev ∧ final.identitiesRev = ctx.identitiesRev ∧
    final.next = ctx.next ∧ final.unsupported = ctx.unsupported := by
  unfold identify at stop
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind] at stop
  change ((scan (BudgetScan.identify ctx.next) >>= fun (key, next) => do
    modify fun ctx => { ctx with next := next, identitiesRev := (key, source) :: ctx.identitiesRev }
    pure key) limits ctx) = _ at stop
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind, scan] at stop
  cases eq : (BudgetScan.identify ctx.next).run limits ctx.budget with
  | ok result state =>
    cases result
    simp only [eq, ExceptT.bindCont] at stop
    cases stop
  | stopped reason state =>
    simp only [eq, ExceptT.bindCont, pure, StateT.pure] at stop
    cases stop
    exact ⟨rfl, rfl, rfl, rfl⟩

theorem spec_identify (source : Expr) (limits : Limits) (ctx : Context)
    (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop)
    (good : identity (ctx.next, source)) :
    Spec (identify source) limits ctx (· = ctx.next) warning identity := by
  cases run : identify source limits ctx with
  | mk outcome final =>
    cases outcome with
    | ok value =>
      obtain ⟨valueEq, _, warningsEq, identitiesEq, _⟩ := identify_success source limits ctx run
      refine ⟨⟨?_, ?_⟩, ?_⟩
      · exact ⟨[], by simpa only [run, List.nil_append] using warningsEq, by simp⟩
      · exact ⟨[(ctx.next, source)], by simpa only [run, List.cons_append, List.nil_append] using identitiesEq,
          by simpa only [List.mem_singleton, forall_eq] using good⟩
      · intro result ok
        have eq : value = result := by simpa only [run, Except.ok.injEq] using ok
        exact eq ▸ valueEq
    | error reason =>
      obtain ⟨warningsEq, identitiesEq, _, _⟩ := identify_stopped source limits ctx run
      exact ⟨⟨⟨[], by simpa only [run, List.nil_append] using warningsEq, by simp⟩,
        ⟨[], by simpa only [run, List.nil_append] using identitiesEq, by simp⟩⟩,
        by intro value ok; simp only [run, reduceCtorEq] at ok⟩

/-- 保存したのは候補列の接頭辞である。停止時も入力からの列を区別して残す。 -/
theorem saveWarnings_progress (warnings : List IntervalWarning) (limits : Limits) (ctx : Context) :
    let (outcome, final) := saveWarnings warnings limits ctx
    ∃ written rest, warnings = written ++ rest ∧
      final.warningsRev = written.reverse ++ ctx.warningsRev ∧
      final.identitiesRev = ctx.identitiesRev ∧ final.next = ctx.next ∧
      final.unsupported = ctx.unsupported ∧ (outcome = .ok () → rest = []) := by
  induction warnings generalizing ctx with
  | nil => exact ⟨[], [], rfl, rfl, rfl, rfl, rfl, by intros; rfl⟩
  | cons warning warnings ih =>
    rw [saveWarnings]
    unfold scope
    simp only [scan, BudgetScan.allocate]
    cases frame : reserve limits ctx.budget .stackFrame .temporary with
    | stopped reason state =>
      exact ⟨[], warning :: warnings, rfl, rfl, rfl, rfl, rfl, by intro ok; cases ok⟩
    | ok state =>
      simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind, scan]
      cases item : reserve limits state .warning .saved with
      | stopped reason final =>
        simp only [ExceptT.bindCont, pure, StateT.pure]
        exact ⟨[], warning :: warnings, rfl, rfl, trivial, trivial, trivial, by intro ok; cases ok⟩
      | ok final =>
        simp only [ExceptT.bindCont]
        change (let (outcome, after) := saveWarnings warnings limits ({ ctx with
            budget := final, warningsRev := warning :: ctx.warningsRev } : Context);
          ∃ written rest, warning :: warnings = written ++ rest ∧
            after.warningsRev = written.reverse ++ ctx.warningsRev ∧
            after.identitiesRev = ctx.identitiesRev ∧ after.next = ctx.next ∧
            after.unsupported = ctx.unsupported ∧ (outcome = .ok () → rest = []))
        obtain ⟨written, rest, input, saved, ids, next, unsupported, complete⟩ :=
          ih { ctx with budget := final, warningsRev := warning :: ctx.warningsRev }
        refine ⟨warning :: written, rest, by simp [input], ?_, ids, next, unsupported, complete⟩
        simpa only [List.reverse_cons, List.append_assoc, List.singleton_append] using saved

/-- 完走時は候補列全体を逆順で追加し、それ以外の保存情報を変更しない。 -/
theorem saveWarnings_success (warnings : List IntervalWarning) (limits : Limits) (ctx : Context)
    {final : Context} (ok : saveWarnings warnings limits ctx = (.ok (), final)) :
    final.warningsRev = warnings.reverse ++ ctx.warningsRev ∧
    final.identitiesRev = ctx.identitiesRev ∧ final.next = ctx.next ∧
    final.unsupported = ctx.unsupported := by
  have progress := saveWarnings_progress warnings limits ctx
  rw [ok] at progress
  obtain ⟨written, rest, input, saved, ids, next, unsupported, complete⟩ := progress
  have empty := complete rfl
  simp only [empty, List.append_nil] at input
  exact ⟨input ▸ saved, ids, next, unsupported⟩

theorem spec_saveWarnings (warnings : List IntervalWarning) (limits : Limits) (ctx : Context)
    (warning : IntervalWarning → Prop) (identity : OperationKey × Expr → Prop)
    (good : ∀ value ∈ warnings, warning value) :
    Spec (saveWarnings warnings) limits ctx (fun _ => True) warning identity := by
  obtain ⟨written, rest, input, saved, ids, _, _, _⟩ := saveWarnings_progress warnings limits ctx
  refine ⟨⟨⟨written.reverse, saved, ?_⟩, ⟨[], ?_, by simp⟩⟩, by intros; trivial⟩
  · intro value member
    apply good value
    rw [input]
    exact List.mem_append_left _ (List.mem_reverse.mp member)
  · simpa only [List.nil_append] using ids

end Benitoite.Interval.BudgetAnalysis
