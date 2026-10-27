import Benitoite.Interval.BudgetNormal
import Benitoite.Interval.BudgetLocated

/-!
# 予算付き解析の警告原因の合成

入力からある警告を除いた追加分について、位置の範囲と拒否原因を同時に保つ。
保存列の逆順と具体評価の trace の順序は独立に扱う。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 一つの範囲にある警告。到達した同じ演算だけに拒否原因を要求する。 -/
def CauseIn (key : OperationKey) (size : Nat) (trace : EvalTrace)
    (warning : IntervalWarning) : Prop :=
  KeyWithin key size warning.key ∧
    ∀ event, Reached trace warning event → event.result = .rejected warning.cause.toFailure

/-- 成功・停止に共通する警告の追加分の性質。入力列には条件を課さない。 -/
def Causal (work : Analysis α) (limits : Limits) (ctx : Context)
    (key : OperationKey) (size : Nat) (trace : EvalTrace) : Prop :=
  ListExtension (CauseIn key size trace) ctx.warningsRev (work limits ctx).2.warningsRev

theorem CauseIn.emptyTrace {key size warning} (bounds : KeyWithin key size warning.key) :
    CauseIn key size [] warning := ⟨bounds, by simp [Reached]⟩

theorem CauseIn.widen {key size trace warning key' size'}
    (h : CauseIn key size trace warning)
    (fits : ∀ k, KeyWithin key size k → KeyWithin key' size' k) :
    CauseIn key' size' trace warning := ⟨fits _ h.1, h.2⟩

/-- 別の部分木の事象を追加しても、この範囲の警告とは一致しない。 -/
theorem CauseIn.append_left {key size trace warning otherKey otherSize other}
    (h : CauseIn key size trace warning) (keys : TraceKeys otherKey otherSize other)
    (separated : key.surfacePreorder + size ≤ otherKey.surfacePreorder ∨
      otherKey.surfacePreorder + otherSize ≤ key.surfacePreorder) :
    CauseIn key size (trace ++ other) warning := by
  refine ⟨h.1, ?_⟩
  intro event reached
  rcases List.mem_append.mp reached.1 with own | foreign
  · exact h.2 event ⟨own, reached.2⟩
  · have bounds := keys.2 event foreign
    rw [reached.2.1] at bounds
    have inside := h.1
    simp only [KeyWithin] at inside
    rcases separated with separated | separated <;> omega

theorem CauseIn.append_right {key size trace warning otherKey otherSize other}
    (h : CauseIn key size trace warning) (keys : TraceKeys otherKey otherSize other)
    (separated : key.surfacePreorder + size ≤ otherKey.surfacePreorder ∨
      otherKey.surfacePreorder + otherSize ≤ key.surfacePreorder) :
    CauseIn key size (other ++ trace) warning := by
  refine ⟨h.1, ?_⟩
  intro event reached
  rcases List.mem_append.mp reached.1 with foreign | own
  · have bounds := keys.2 event foreign
    rw [reached.2.1] at bounds
    have inside := h.1
    simp only [KeyWithin] at inside
    rcases separated with separated | separated <;> omega
  · exact h.2 event ⟨own, reached.2⟩

theorem Causal.mono {work : Analysis α} {limits ctx key size trace key' size' trace'}
    (h : Causal work limits ctx key size trace)
    (imp : ∀ w, CauseIn key size trace w → CauseIn key' size' trace' w) :
    Causal work limits ctx key' size' trace' := ListExtension.mono h imp

theorem Silent.causal {work : Analysis α} (silent : Silent work) (limits ctx key size trace) :
    Causal work limits ctx key size trace :=
  ⟨[], by simpa using silent limits ctx, by simp⟩

/-- 後続の仮定は、前半が実際に成功した同じ中間状態についてだけ受け取る。 -/
theorem causal_bind {first : Analysis α} {next : α → Analysis β}
    {limits ctx key size trace}
    (hf : Causal first limits ctx key size trace)
    (hn : ∀ value middle, first limits ctx = (.ok value, middle) →
      Causal (next value) limits middle key size trace) :
    Causal (first >>= next) limits ctx key size trace := by
  unfold Causal
  simp only [bind, ReaderT.bind, ExceptT.bind, ExceptT.mk, StateT.bind]
  cases run : first limits ctx with
  | mk outcome middle =>
    cases outcome with
    | error reason =>
      simpa only [Causal, run, ExceptT.bindCont, pure, StateT.pure] using hf
    | ok value =>
      exact (show ListExtension _ ctx.warningsRev middle.warningsRev from by
        simpa only [Causal, run] using hf).trans (hn value middle run)

/-- 兄弟の警告は保存順にかかわらず、実行順の trace に対して合成できる。 -/
theorem causal_bind_append {first : Analysis α} {next : α → Analysis β}
    {limits ctx leftKey rightKey leftSize rightSize lt rt key size}
    (hf : Causal first limits ctx leftKey leftSize lt)
    (hn : ∀ value middle, first limits ctx = (.ok value, middle) →
      Causal (next value) limits middle rightKey rightSize rt)
    (lk : TraceKeys leftKey leftSize lt) (rk : TraceKeys rightKey rightSize rt)
    (separated : leftKey.surfacePreorder + leftSize ≤ rightKey.surfacePreorder ∨
      rightKey.surfacePreorder + rightSize ≤ leftKey.surfacePreorder)
    (lf : ∀ k, KeyWithin leftKey leftSize k → KeyWithin key size k)
    (rf : ∀ k, KeyWithin rightKey rightSize k → KeyWithin key size k) :
    Causal (first >>= next) limits ctx key size (lt ++ rt) := by
  apply causal_bind (hf.mono (fun _ h => (h.append_left rk separated).widen lf))
  intro value middle ok
  exact (hn value middle ok).mono (fun _ h =>
    (h.append_right lk (separated.symm)).widen rf)

theorem causal_scope {work : Unit → Analysis α} {limits ctx key size trace}
    (body : ∀ entered, scan (BudgetScan.allocate .stackFrame) limits ctx = (.ok (), entered) →
      Causal (work ()) limits entered key size trace) :
    Causal (scope work) limits ctx key size trace := by
  unfold Causal scope
  cases run : scan (BudgetScan.allocate .stackFrame) limits ctx with
  | mk outcome entered =>
    have same : entered.warningsRev = ctx.warningsRev := by
      simpa only [run] using silent_scan (BudgetScan.allocate .stackFrame) limits ctx
    cases outcome with
    | error reason => exact ⟨[], by simpa using same, by simp⟩
    | ok value =>
      cases value
      cases inner : work () limits entered with
      | mk outcome final => simpa only [Causal, inner, same] using body entered run

/-- 先行順の位置の証明から、未実行部分の警告の範囲だけを得る。 -/
theorem numberFrom_bounds {key sources k source} (member : (k, source) ∈ numberFrom key sources) :
    KeyWithin key sources.length k := by
  induction sources generalizing key with
  | nil => simp [numberFrom] at member
  | cons head rest ih =>
    simp only [numberFrom, List.mem_cons] at member
    rcases member with eq | member
    · cases eq
      exact ⟨rfl, Nat.le_refl _, by simp⟩
    · have h := ih member
      simp only [KeyWithin, advanceKey] at h ⊢
      simp only [List.length_cons]
      exact ⟨h.1, by omega, by omega⟩

theorem LocatedIn.bounds {key sources warning} (h : LocatedIn key sources warning) :
    KeyWithin key sources.length warning.key := by
  obtain ⟨source, member, _⟩ := h
  exact numberFrom_bounds member

/-- 実行していない枝にも解析の警告はあり得るが、そこへの到達事象はない。 -/
theorem causal_absent {work : Analysis α} {sources limits ctx}
    (located : Located work sources (fun _ => False)) :
    Causal work limits ctx ctx.next sources.length [] :=
  (located limits ctx).1.1.mono (fun _ h =>
    CauseIn.emptyTrace (h.resolve_left id).bounds)

/-- own の候補のうち、確保できた接頭辞だけに同じ原因の性質を渡す。 -/
theorem causal_saveWarnings (warnings : List IntervalWarning) (limits ctx key size trace)
    (good : ∀ warning ∈ warnings, CauseIn key size trace warning) :
    Causal (saveWarnings warnings) limits ctx key size trace :=
  (spec_saveWarnings warnings limits ctx _ (fun _ => True) good).1.1

theorem causal_own {op type left right limits ctx key size trace root}
    (good : ∀ w ∈ (baseOwn root op type left right).warnings, CauseIn key size trace w) :
    Causal (own root op type left right) limits ctx key size trace := by
  apply causal_bind (causal_saveWarnings _ _ _ _ _ _ good)
  intro value middle _
  exact (silent_pure _).causal limits middle key size trace

theorem causal_negOwn {root child limits ctx key size trace}
    (good : ∀ w ∈ (baseNegOwn root child).warnings, CauseIn key size trace w) :
    Causal (negOwn root child) limits ctx key size trace := by
  exact causal_bind (causal_saveWarnings _ _ _ _ _ _ good)
    (fun _ middle _ => (silent_pure _).causal limits middle key size trace)

theorem causal_negOwnTyped {root type child limits ctx key size trace}
    (good : ∀ w ∈ (baseNegOwnTyped root type child).warnings, CauseIn key size trace w) :
    Causal (negOwnTyped root type child) limits ctx key size trace := by
  exact causal_bind (causal_saveWarnings _ _ _ _ _ _ good)
    (fun _ middle _ => (silent_pure _).causal limits middle key size trace)

theorem negOwnTyped_cause_absent (key type child) {warning}
    (member : warning ∈ (baseNegOwnTyped key type child).warnings) : CauseIn key 1 [] warning := by
  cases negOwnTyped_warning member
  exact CauseIn.emptyTrace ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

theorem negOwn_cause_absent (key child) {warning}
    (member : warning ∈ (baseNegOwn key child).warnings) : CauseIn key 1 [] warning := by
  cases negOwn_warning member
  exact CauseIn.emptyTrace ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

theorem negOwn_cause {key child a warning}
    (ha : child.Contains (.integer a))
    (member : warning ∈ (baseNegOwn key child).warnings) :
    CauseIn key 1 [⟨key, .neg (.base .integer), [.integer a], checkedNeg a⟩] warning := by
  refine ⟨(negOwn_cause_absent key child member).1, ?_⟩
  intro event reached
  simp only [baseNegOwn] at member
  split at member
  · rename_i always
    cases List.mem_singleton.mp member
    cases List.mem_singleton.mp reached.1
    exact neg_always_overflows_sound (by decide) ha always
  · contradiction

/-- 親の候補を空 trace に対して合成する場合にも、親の一番号だけを使う。 -/
theorem own_cause_absent (key op type left right) {warning}
    (member : warning ∈ (baseOwn key op type left right).warnings) :
    CauseIn key 1 [] warning := by
  have origin := own_warning_origin key op type left right .unit .unit warning member
  apply CauseIn.emptyTrace
  rw [origin.1]
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

/-- 演算の種類と幅を保ち、同じ二つの正常引数への拒否を渡す。 -/
theorem own_width_cause {key kind op left right a b warning}
    (not64 : kind ≠ .integer64)
    (ha : left.Contains (.ofInteger kind a)) (hb : right.Contains (.ofInteger kind b))
    (member : warning ∈ (baseOwn key (WidthBinary.op op) kind.type left right).warnings) :
    CauseIn key 1 [⟨key, .binary op.op kind.type,
      [.ofInteger kind a, .ofInteger kind b], op.apply kind a b⟩] warning := by
  refine ⟨(own_cause_absent key op.op kind.type left right member).1, ?_⟩
  intro event reached
  cases List.mem_singleton.mp reached.1
  rw [baseOwn_atKind _ _ _ _ _ not64] at member
  exact widthOwn_warning_sound ha hb member

theorem negOwnTyped_width_cause {key kind signed child a warning}
    (not64 : kind ≠ .integer64)
    (ha : child.Contains (.ofInteger kind a))
    (member : warning ∈ (baseNegOwnTyped key kind.type child).warnings) :
    CauseIn key 1 [⟨key, .neg kind.type, [.ofInteger kind a], kind.checkedNeg signed a⟩] warning := by
  refine ⟨(negOwnTyped_cause_absent key kind.type child member).1, ?_⟩
  intro event reached
  cases List.mem_singleton.mp reached.1
  rw [baseNegOwnTyped_atKind _ _ signed _ not64] at member
  exact widthNegOwn_warning_sound ha member

theorem own_add_cause {key left right a b warning}
    (ha : left.Contains (.integer a)) (hb : right.Contains (.integer b))
    (member : warning ∈ (baseOwn key .add (.base .integer) left right).warnings) :
    CauseIn key 1
      [⟨key, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩] warning := by
  refine ⟨(own_cause_absent key .add (.base .integer) left right member).1, ?_⟩
  intro event reached
  change warning ∈ (if addAlwaysOverflows left.integer right.integer then
    [⟨key, .binary .add (.base .integer), .overflow⟩] else []) at member
  split at member
  · rename_i always
    obtain rfl := List.mem_singleton.mp member
    obtain rfl := List.mem_singleton.mp reached.1
    exact add_always_overflows_sound ha hb always
  · contradiction

theorem own_sub_cause {key left right a b warning}
    (ha : left.Contains (.integer a)) (hb : right.Contains (.integer b))
    (member : warning ∈ (baseOwn key .sub (.base .integer) left right).warnings) :
    CauseIn key 1
      [⟨key, .binary .sub (.base .integer), [.integer a, .integer b], checkedSub a b⟩] warning := by
  refine ⟨(own_cause_absent key .sub (.base .integer) left right member).1, ?_⟩
  intro event reached
  change warning ∈ (if subAlwaysOverflows left.integer right.integer then
    [⟨key, .binary .sub (.base .integer), .overflow⟩] else []) at member
  split at member
  · rename_i always
    obtain rfl := List.mem_singleton.mp member
    obtain rfl := List.mem_singleton.mp reached.1
    exact sub_always_overflows_sound ha hb always
  · contradiction

theorem own_mul_cause {key left right a b warning}
    (ha : left.Contains (.integer a)) (hb : right.Contains (.integer b))
    (member : warning ∈ (baseOwn key .mul (.base .integer) left right).warnings) :
    CauseIn key 1
      [⟨key, .binary .mul (.base .integer), [.integer a, .integer b], checkedMul a b⟩] warning := by
  refine ⟨(own_cause_absent key .mul (.base .integer) left right member).1, ?_⟩
  intro event reached
  change warning ∈ (if mulAlwaysOverflows left.integer right.integer then
    [⟨key, .binary .mul (.base .integer), .overflow⟩] else []) at member
  split at member
  · rename_i always
    obtain rfl := List.mem_singleton.mp member
    obtain rfl := List.mem_singleton.mp reached.1
    exact mul_always_overflows_sound ha hb always
  · contradiction

theorem own_div_cause {key op left right a b warning} (target : IntegerDivisionOp op)
    (ha : left.Contains (.integer a)) (hb : right.Contains (.integer b))
    (member : warning ∈ (baseOwn key op (.base .integer) left right).warnings) :
    CauseIn key 1
      [⟨key, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩] warning := by
  refine ⟨(own_cause_absent key op (.base .integer) left right member).1, ?_⟩
  intro event reached
  have notAdd : op ≠ .add := by rcases target with rfl | rfl <;> decide
  have notSub : op ≠ .sub := by rcases target with rfl | rfl <;> decide
  have notMul : op ≠ .mul := by rcases target with rfl | rfl <;> decide
  simp only [baseOwn, notAdd, notSub, notMul, ↓reduceIte, ite_eq_left target, analyzeDivMod] at member
  split at member
  · rename_i always
    obtain rfl := List.mem_singleton.mp member
    obtain rfl := List.mem_singleton.mp reached.1
    exact divMod_always_zero_sound ha hb always
  · contradiction

/-- 実際の成功で得た番号消費を使い、次の子を同じ中間状態から始める。 -/
theorem causal_bind_follow {first : Analysis α} {next : α → Analysis β}
    {limits ctx sources second lt rt}
    (walk : Walk first sources)
    (hf : Causal first limits ctx ctx.next sources.length lt)
    (hn : ∀ value middle, first limits ctx = (.ok value, middle) →
      Causal (next value) limits middle middle.next second rt)
    (lk : TraceKeys ctx.next sources.length lt)
    (rk : TraceKeys (advanceKey ctx.next sources.length) second rt) :
    Causal (first >>= next) limits ctx ctx.next (sources.length + second) (lt ++ rt) := by
  refine causal_bind_append hf (fun value middle ok => ?_) lk rk
    (Or.inl (by simp [advanceKey])) (fun k h => ?_) (fun k h => ?_)
  · simpa only [(walk.success ok).1] using hn value middle ok
  ·
    simp only [KeyWithin] at h ⊢
    exact ⟨h.1, h.2.1, by omega⟩
  ·
    simp only [KeyWithin, advanceKey] at h ⊢
    exact ⟨h.1, by omega, by omega⟩

/-- 親の一番号と子の全範囲を分け、子の後に保存する own を合成する。 -/
theorem causal_bind_root {first : Analysis α} {next : α → Analysis β}
    {limits ctx root children ct ot}
    (start : ctx.next = childKey root [])
    (hf : Causal first limits ctx ctx.next children ct)
    (hn : ∀ value middle, first limits ctx = (.ok value, middle) →
      Causal (next value) limits middle root 1 ot)
    (ck : TraceKeys ctx.next children ct) (ok : TraceKeys root 1 ot) :
    Causal (first >>= next) limits ctx root (1 + children) (ct ++ ot) := by
  refine causal_bind_append hf hn ck ok (Or.inr (by simp [start, childKey]))
    (fun k h => ?_) (fun k h => ?_)
  ·
    simp only [KeyWithin, start, childKey, List.map_nil, List.sum_nil] at h ⊢
    exact ⟨h.1, by omega, by omega⟩
  ·
    simp only [KeyWithin] at h ⊢
    exact ⟨h.1, h.2.1, by omega⟩

theorem causal_map {work : Analysis α} {limits ctx key size trace}
    (h : Causal work limits ctx key size trace) (f : α → β) :
    Causal (work >>= fun value => pure (f value)) limits ctx key size trace := by
  apply causal_bind h
  intro value middle _
  exact (silent_pure _).causal limits middle key size trace

/-- 枠の確保と返却では次キーも警告列も変えない。 -/
theorem causal_scope_same {work : Unit → Analysis α} {limits ctx key size trace}
    (body : ∀ entered, entered.next = ctx.next →
      Causal (work ()) limits entered key size trace) :
    Causal (scope work) limits ctx key size trace := by
  apply causal_scope
  intro entered ok
  apply body entered
  simpa only [ok] using (scan_preserves_saved (BudgetScan.allocate .stackFrame) limits ctx).2.2.1

/-- キーを借用するだけの読出しは、予算も保存列も次キーも変えない。 -/
theorem causal_get_bind {next : Context → Analysis α} {limits ctx key size trace}
    (h : Causal (next ctx) limits ctx key size trace) :
    Causal (get >>= next) limits ctx key size trace := by
  exact h

/-- 走査が実際に成功した状態へだけ、局所規則との一致と次キーを渡す。 -/
theorem causal_scan_bind (work : BudgetScan.Scan α) (expected : α)
    (agrees : BudgetScan.Agrees work expected) {next : α → Analysis β}
    {limits ctx key size trace}
    (hn : ∀ middle, middle.next = ctx.next → Causal (next expected) limits middle key size trace) :
    Causal (scan work >>= next) limits ctx key size trace := by
  apply causal_bind ((silent_scan work).causal limits ctx key size trace)
  intro value middle ok
  have same : value = expected := success_scan_agrees work expected agrees limits ctx value
    (by simp only [ok])
  subst value
  apply hn middle
  simpa only [ok] using (scan_preserves_saved work limits ctx).2.2.1

/-- 具体評価で選んだ枝についてだけ子の原因の仮定を要求する。 -/
theorem causal_branch_selected {env source tested truth run skip inner limits ctx key size trace}
    (entry : branchEnv env source tested.boolean truth = some inner)
    (hr : ∀ middle, middle.next = ctx.next → Causal (run inner) limits middle key size trace) :
    Causal (branch env source tested truth run skip) limits ctx key size trace := by
  unfold branch
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.branch_agrees env source tested.boolean truth)
  intro middle next
  rw [entry]
  exact hr middle (next.trans same)

/-- 未実行の枝では、解析し得る全ての入口の空 trace の性質を明示する。 -/
theorem causal_branch_absent {env source tested truth run skip limits ctx key size}
    (hr : ∀ inner middle, middle.next = ctx.next →
      Causal (run inner) limits middle key size [])
    (hs : Silent (skip ())) :
    Causal (branch env source tested truth run skip) limits ctx key size [] := by
  unfold branch
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.branch_agrees env source tested.boolean truth)
  intro middle next
  cases branchEnv env source tested.boolean truth with
  | none => exact causal_map (hs.causal limits middle key size []) (fun _ => baseEmpty)
  | some inner => exact hr inner middle (next.trans same)

/-- 腕の選択走査にも、実行された入口の子の性質だけを渡す。 -/
theorem causal_arm_selected {env source normal alts inner limits ctx key size trace}
    {run : Option AbstractEnv → Analysis α}
    (entry : matchArmEnv env source (.base .integer) normal alts = some inner)
    (hr : ∀ middle, middle.next = ctx.next → Causal (run (some inner)) limits middle key size trace) :
    Causal (scope fun _ => scan (BudgetScan.arm env source (.base .integer) normal alts) >>= run)
      limits ctx key size trace := by
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.arm_agrees env source (.base .integer) normal alts)
  intro middle next
  rw [entry]
  exact hr middle (next.trans same)

/-- 種類付きの腕でも選択済みの入口へ進む。 -/
theorem causal_kindArm_selected {env source alts inner limits ctx key size trace} {kind : IntKind} {normal : Interval kind}
    {run : Option AbstractEnv → Analysis α}
    (entry : matchKindArmEnv env source kind normal alts = some inner)
    (hr : ∀ middle, middle.next = ctx.next → Causal (run (some inner)) limits middle key size trace) :
    Causal (scope fun _ => scan (BudgetScan.armKind env source kind normal alts) >>= run)
      limits ctx key size trace := by
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.armKind_agrees env source kind normal alts)
  intro middle next
  rw [entry]
  exact hr middle (next.trans same)

/-- Result の腕入口の補助記録は、確保が成功した同じ状態へだけ渡す。 -/
theorem causal_resultArm_selected {env input alts limits ctx key size trace}
    {run : AbstractEnv → Analysis α}
    (hr : ∀ middle, middle.next = ctx.next →
      Causal (run (baseResultArmEnv env input alts)) limits middle key size trace) :
    Causal (scope fun _ => scan (BudgetScan.rangeArm env input alts) >>= run)
      limits ctx key size trace := by
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.rangeArm_agrees env input alts)
  intro middle next
  exact hr middle (next.trans same)

/-- 未選択の腕では、none の番号走査と some の空 trace の原因を分ける。 -/
theorem causal_arm_absent {env source normal alts limits ctx key size}
    {run : Option AbstractEnv → Analysis α}
    (noneSilent : Silent (run none))
    (hr : ∀ inner middle, middle.next = ctx.next →
      Causal (run (some inner)) limits middle key size []) :
    Causal (scope fun _ => scan (BudgetScan.arm env source (.base .integer) normal alts) >>= run)
      limits ctx key size [] := by
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ _ (BudgetScan.arm_agrees env source (.base .integer) normal alts)
  intro middle next
  cases matchArmEnv env source (.base .integer) normal alts with
  | none => exact noneSilent.causal limits middle key size []
  | some inner => exact hr inner middle (next.trans same)

/-- 任意の中間状態における正常値と、同じ成功実行の番号消費を一緒に得る。 -/
theorem expr_normal_next (fuel : Nat) {abstract concrete input outcome trace limits ctx approx final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace)
    (ok : expr fuel abstract input.source limits ctx = (.ok approx, final))
    (start : ctx.next = input.key := by first | assumption | simp_all only [advanceKey, childKey]) :
    NormalCovered approx outcome ∧ final.next = advanceKey ctx.next (surfaceSize input.source) :=
  ⟨expr_normal fuel models rmodels eval limits ctx start approx (by simp only [ok]),
    (expr_success fuel abstract input.source limits ctx ok).1⟩

theorem block_normal_next (fuel : Nat) {abstract concrete key body type outcome trace limits ctx approx final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace)
    (ok : block fuel abstract body limits ctx = (.ok approx, final))
    (start : ctx.next = key) :
    NormalCovered approx outcome ∧ final.next = advanceKey ctx.next (blockSize body) :=
  ⟨block_normal fuel models rmodels eval limits ctx start approx (by simp only [ok]),
    (block_success fuel abstract body limits ctx ok).1⟩

/-- 二つの正常オペランドを得た同じ状態列を、own の原因へ接続する。 -/
theorem binary_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    lhs.Contains (.integer a) ∧ rhs.Contains (.integer b) ∧
      middle.next = childKey root [left] ∧
      final.next = advanceKey (childKey root [left]) (surfaceSize right) := by
  obtain ⟨nl, kl⟩ := expr_normal_next fuel models rmodels el hl start
  have next : middle.next = childKey root [left] := by
    simpa [start, advanceKey, childKey] using kl
  obtain ⟨nr, kr⟩ := expr_normal_next fuel models rmodels er hr next
  exact ⟨nl _ rfl, nr _ rfl, next, by simpa only [next] using kr⟩

/-- 二つの成功した子から加算の原因を得る。own 自身の保存停止も含む。 -/
theorem causal_add_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .add (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .add (.base .integer), [.integer a, .integer b], checkedAdd a b⟩] := by
  obtain ⟨nl, nr, _, _⟩ := binary_operands fuel models rmodels el er start hl hr
  exact causal_own (fun _ member => own_add_cause nl nr member)

theorem causal_sub_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .sub (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .sub (.base .integer), [.integer a, .integer b], checkedSub a b⟩] := by
  obtain ⟨nl, nr, _, _⟩ := binary_operands fuel models rmodels el er start hl hr
  exact causal_own (fun _ member => own_sub_cause nl nr member)

theorem causal_mul_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root .mul (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary .mul (.base .integer), [.integer a, .integer b], checkedMul a b⟩] := by
  obtain ⟨nl, nr, _, _⟩ := binary_operands fuel models rmodels el er start hl hr
  exact causal_own (fun _ member => own_mul_cause nl nr member)

theorem causal_div_of_operands (fuel : Nat)
    {abstract concrete root left right a b lt rt limits ctx middle final lhs rhs op}
    (target : IntegerDivisionOp op) (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (el : EvalPartial concrete ⟨left, .base .integer, childKey root []⟩ (.normal (.integer a)) lt)
    (er : EvalPartial concrete ⟨right, .base .integer, childKey root [left]⟩ (.normal (.integer b)) rt)
    (start : ctx.next = childKey root [])
    (hl : expr fuel abstract left limits ctx = (.ok lhs, middle))
    (hr : expr fuel abstract right limits middle = (.ok rhs, final)) :
    Causal (own root op (.base .integer) lhs rhs) limits final root 1
      [⟨root, .binary op (.base .integer), [.integer a, .integer b], checkedDivMod op a b⟩] := by
  obtain ⟨nl, nr, _, _⟩ := binary_operands fuel models rmodels el er start hl hr
  exact causal_own (fun _ member => own_div_cause target nl nr member)

/-- 成功した条件式の正常値から、具体評価が選ぶ枝の入口と環境対応を得る。 -/
theorem branch_entry_of_success (fuel : Nat)
    {abstract concrete input truth trace limits ctx tested final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete input (.normal (.boolean truth)) trace)
    (ok : expr fuel abstract input.source limits ctx = (.ok tested, final))
    (start : ctx.next = input.key := by first | assumption | simp_all only [advanceKey, childKey]) :
    ∃ inner, branchEnv abstract input.source tested.boolean truth = some inner ∧
      Models inner concrete ∧ inner.ranges.Models concrete := by
  obtain ⟨inner, entry, modeled⟩ := branch_models models eval
    ((expr_normal_next fuel models rmodels eval ok start).1 _ rfl)
  exact ⟨inner, entry, modeled, ranges_branchEnv rmodels entry⟩

/-- 照合値を得た成功状態の近似を、そのまま整数の腕の選択へ渡す。 -/
theorem arm_entry_of_success (fuel : Nat)
    {abstract concrete source root value trace selected alts limits ctx tested final}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (eval : EvalPartial concrete ⟨source, .base .integer, root⟩ (.normal (.integer value)) trace)
    (selection : IntegerSelection alts value selected)
    (ok : expr fuel abstract source limits ctx = (.ok tested, final))
    (start : ctx.next = root := by first | assumption | simp_all only [advanceKey, childKey]) :
    ∃ inner, matchArmEnv abstract source (.base .integer) tested.integer alts = some inner ∧
      Models inner { concrete with locals := selected.reverse.map some ++ concrete.locals } := by
  exact match_selection_models models eval ((expr_normal_next fuel models rmodels eval ok start).1 _ rfl) selection

end Benitoite.Interval.BudgetAnalysis
