import Benitoite.Interval.BudgetCause

/-!
# 任意の共有予算に対する警告の健全性

成功・停止に共通する追加警告の原因を、具体評価の部分木ごとに合成する。
（設計書 01-12「区間解析の予算付きの式とフロー」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

theorem preorder_expr_length (source : Expr) : (surfacePreorder source).length = surfaceSize source := rfl

theorem blockSize_bind (kind type source rest) :
    blockSize (.bind kind type source rest) = surfaceSize source + blockSize rest := by
  simp only [← preorderBlock_length, preorderBlock, List.length_append, surfaceSize]

theorem blockSize_discard (source rest) :
    blockSize (.discard source rest) = surfaceSize source + blockSize rest := by
  simp only [← preorderBlock_length, preorderBlock, List.length_append, surfaceSize]

theorem blockSize_seq (source rest) :
    blockSize (.seq source rest) = surfaceSize source + blockSize rest := by
  simp only [← preorderBlock_length, preorderBlock, List.length_append, surfaceSize]

theorem blockSize_bindPat (kind pattern type source rest) :
    blockSize (.bindPat kind pattern type source rest) = surfaceSize source + blockSize rest := by
  simp only [← preorderBlock_length, preorderBlock, List.length_append, surfaceSize]

/-- 子の警告を親の範囲へ広げる。到達記録は変更しない。 -/
theorem Causal.parent {work : Analysis α} {limits ctx root size trace}
    (h : Causal work limits ctx (childKey root []) size trace) :
    Causal work limits ctx root (1 + size) trace :=
  h.mono (fun _ h => h.widen (by
    intro k bounds
    simp only [KeyWithin, childKey, List.map_nil, List.sum_nil] at bounds ⊢
    exact ⟨bounds.1, by omega, by omega⟩))

/-- 成功した前半の番号消費だけを使って、後半の入力キーを確定する。 -/
theorem causal_follow {first : Analysis α} {next : α → Analysis β}
    {limits ctx key sources second lt rt}
    (start : ctx.next = key) (walk : Walk first sources)
    (hf : Causal first limits ctx key sources.length lt)
    (hn : ∀ value middle, first limits ctx = (.ok value, middle) →
      Causal (next value) limits middle (advanceKey key sources.length) second rt)
    (lk : TraceKeys key sources.length lt)
    (rk : TraceKeys (advanceKey key sources.length) second rt) :
    Causal (first >>= next) limits ctx key (sources.length + second) (lt ++ rt) := by
  subst key
  apply causal_bind_follow walk hf _ lk rk
  intro value middle ok
  simpa only [(walk.success ok).1] using hn value middle ok

/-- 識別・訪問の計上は警告を追加せず、成功時だけ子の先頭へ進む。 -/
theorem causal_identified {source : Expr} {next : OperationKey → Analysis α}
    {limits ctx root size trace} (start : ctx.next = root)
    (body : ∀ middle, middle.next = childKey root [] →
      Causal (next root) limits middle root size trace) :
    Causal (do let key ← identify source; scan (BudgetScan.tick .expression); next key)
      limits ctx root size trace := by
  apply causal_bind ((silent_identify source).causal _ _ _ _ _)
  intro key middle ok
  obtain ⟨value, position, _⟩ := identify_success source limits ctx ok
  have keyEq : key = root := value.trans start
  subst key
  apply causal_scan_bind _ () (by intro limits state value final ok; cases value; rfl)
  intro final same
  rw [start]
  apply body final
  simp only [same, position, start, childKey, List.map_nil, List.sum_nil, Nat.add_zero]

theorem silent_unsupported : Silent unsupported := by intro limits ctx; rfl

/-- 幅付きの葉は、範囲外を未知と記録するときも警告を作らない。 -/
theorem silent_widthLiteral (kind : IntKind) (value : Int) : Silent (widthLiteral kind value) := by
  unfold widthLiteral
  split
  · exact silent_pure _
  · exact silent_unsupported

/-- 未実行の部分は位置の定理から空 trace の原因を得る。 -/
theorem expr_absent (fuel : Nat) (env : AbstractEnv) (source : Expr) (limits ctx) :
    Causal (expr fuel env source) limits ctx ctx.next (surfaceSize source) [] := by
  simpa only [surfaceSize] using
    causal_absent ((analysis_located fuel).1 (fun _ => False) env source)

theorem block_absent (fuel : Nat) (env : AbstractEnv) (body : Block) (limits ctx) :
    Causal (block fuel env body) limits ctx ctx.next (blockSize body) [] := by
  simpa only [← preorderBlock_length] using
    causal_absent ((analysis_located fuel).2.2.1 (fun _ => False) env body)

theorem arms_absent (fuel : Nat) (env : AbstractEnv) (source : Expr) (normal : Interval)
    (arms : Arms) (limits ctx) :
    Causal (armList fuel env source normal arms) limits ctx ctx.next (armsSize arms) [] := by
  simpa only [armsSize] using
    causal_absent ((analysis_located fuel).2.2.2 (fun _ => False) env source normal arms)


/-- 種類付きの未実行腕の警告も空 trace の原因で覆う。 -/
theorem kindArms_absent (fuel : Nat) (kind : IntKind) (env : AbstractEnv) (source : Expr) (normal : Interval kind)
    (arms : Arms) (limits ctx) :
    Causal (armListKind fuel kind env source normal arms) limits ctx ctx.next (armsSize arms) [] := by
  simpa only [armsSize] using
    causal_absent ((analysis_located_kind fuel).2.2.2 (fun _ => False) kind env source normal arms)

/-- 左右の子と親の演算の三範囲を区別して、原因を全 trace へ移す。 -/
theorem cause_binary_left {root left right lt rt ot warning}
    (h : CauseIn (childKey root []) (surfaceSize left) lt warning)
    (rk : TraceKeys (childKey root [left]) (surfaceSize right) rt)
    (ok : TraceKeys root 1 ot) :
    CauseIn root (1 + surfaceSize left + surfaceSize right) (lt ++ rt ++ ot) warning := by
  apply ((h.append_left rk (Or.inl (by simp [childKey]))).append_left ok
    (Or.inr (by simp [childKey]))).widen
  intro k bounds
  simp only [KeyWithin, childKey, List.map_nil, List.sum_nil] at bounds ⊢
  exact ⟨bounds.1, by omega, by omega⟩

theorem cause_binary_right {root left right lt rt ot warning}
    (h : CauseIn (childKey root [left]) (surfaceSize right) rt warning)
    (lk : TraceKeys (childKey root []) (surfaceSize left) lt)
    (ok : TraceKeys root 1 ot) :
    CauseIn root (1 + surfaceSize left + surfaceSize right) (lt ++ rt ++ ot) warning := by
  apply ((h.append_right lk (Or.inr (by simp [childKey]))).append_left ok
    (Or.inr (by simp [childKey]))).widen
  intro k bounds
  simp only [KeyWithin, childKey, List.map_cons, List.sum_cons, List.map_nil, List.sum_nil] at bounds ⊢
  exact ⟨bounds.1, by omega, by omega⟩

theorem cause_binary_own {root left right lt rt ot warning}
    (h : CauseIn root 1 ot warning)
    (lk : TraceKeys (childKey root []) (surfaceSize left) lt)
    (rk : TraceKeys (childKey root [left]) (surfaceSize right) rt) :
    CauseIn root (1 + surfaceSize left + surfaceSize right) (lt ++ rt ++ ot) warning := by
  have h := (h.append_right rk (Or.inl (by simp [childKey]))).append_right lk
    (Or.inl (by simp [childKey]))
  rw [← List.append_assoc] at h
  exact h.widen (by intro k b; exact ⟨b.1, b.2.1, by have bound := b.2.2; omega⟩)

/-- 同じ二つの成功実行にだけ、演算自身の原因の仮定を要求する。 -/
theorem binary_causal (fuel : Nat) {abstract root op left right lt rt ot limits ctx}
    (_start : ctx.next = childKey root [])
    (hl : Causal (expr fuel abstract left) limits ctx (childKey root []) (surfaceSize left) lt)
    (hr : ∀ lhs middle, expr fuel abstract left limits ctx = (.ok lhs, middle) →
      Causal (expr fuel abstract right) limits middle (childKey root [left]) (surfaceSize right) rt)
    (ho : ∀ lhs middle rhs final,
      expr fuel abstract left limits ctx = (.ok lhs, middle) →
      expr fuel abstract right limits middle = (.ok rhs, final) →
      Causal (own root op (.base .integer) lhs rhs) limits final root 1 ot)
    (lk : TraceKeys (childKey root []) (surfaceSize left) lt)
    (rk : TraceKeys (childKey root [left]) (surfaceSize right) rt)
    (ok : TraceKeys root 1 ot) :
    Causal (do
      let lhs ← expr fuel abstract left
      if !lhs.live then do skipExpr fuel right; pure lhs.abrupt
      else do
        let rhs ← expr fuel abstract right
        if !rhs.live then pure (baseThen lhs rhs.abrupt)
        else do pure (baseThen lhs (baseThen rhs (← own root op (.base .integer) lhs rhs))))
      limits ctx root (1 + surfaceSize left + surfaceSize right) (lt ++ rt ++ ot) := by
  apply causal_bind (hl.mono (fun _ h => cause_binary_left h rk ok))
  intro lhs middle first
  split
  · exact (silent_bind ((skip_silent fuel).1 right) (fun _ => silent_pure _)).causal _ _ _ _ _
  · apply causal_bind ((hr lhs middle first).mono (fun _ h => cause_binary_right h lk ok))
    intro rhs final second
    split
    · exact (silent_pure _).causal _ _ _ _ _
    · exact causal_map ((ho lhs middle rhs final first second).mono
        (fun _ h => cause_binary_own h lk rk)) _

theorem binary_typed_causal (fuel : Nat) {abstract root op type left right lt rt ot limits ctx}
    (_start : ctx.next = childKey root [])
    (hl : Causal (expr fuel abstract left) limits ctx (childKey root []) (surfaceSize left) lt)
    (hr : ∀ lhs middle, expr fuel abstract left limits ctx = (.ok lhs, middle) →
      Causal (expr fuel abstract right) limits middle (childKey root [left]) (surfaceSize right) rt)
    (ho : ∀ lhs middle rhs final,
      expr fuel abstract left limits ctx = (.ok lhs, middle) →
      expr fuel abstract right limits middle = (.ok rhs, final) →
      Causal (own root op type lhs rhs) limits final root 1 ot)
    (lk : TraceKeys (childKey root []) (surfaceSize left) lt)
    (rk : TraceKeys (childKey root [left]) (surfaceSize right) rt)
    (ok : TraceKeys root 1 ot) :
    Causal (do
      let lhs ← expr fuel abstract left
      if !lhs.live then do skipExpr fuel right; pure lhs.abrupt
      else do
        let rhs ← expr fuel abstract right
        if !rhs.live then pure (baseThen lhs rhs.abrupt)
        else do pure (baseThen lhs (baseThen rhs (← own root op type lhs rhs))))
      limits ctx root (1 + surfaceSize left + surfaceSize right) (lt ++ rt ++ ot) := by
  apply causal_bind (hl.mono (fun _ h => cause_binary_left h rk ok))
  intro lhs middle first
  split
  · exact (silent_bind ((skip_silent fuel).1 right) (fun _ => silent_pure _)).causal _ _ _ _ _
  · apply causal_bind ((hr lhs middle first).mono (fun _ h => cause_binary_right h lk ok))
    intro rhs final second
    split
    · exact (silent_pure _).causal _ _ _ _ _
    · exact causal_map ((ho lhs middle rhs final first second).mono
        (fun _ h => cause_binary_own h lk rk)) _

theorem own_compare_silent (op : Comparison) (key : OperationKey) (left right : BaseApprox) :
    Silent (own key op.binOp (.base .integer) left right) := by
  have notAdd : op.binOp ≠ .add := by cases op <;> decide
  have notSub : op.binOp ≠ .sub := by cases op <;> decide
  have notMul : op.binOp ≠ .mul := by cases op <;> decide
  have notDiv : ¬ IntegerDivisionOp op.binOp := by cases op <;> simp [IntegerDivisionOp, Comparison.binOp]
  unfold own
  simp only [baseOwn, notAdd, notSub, notMul, ↓reduceIte, ite_eq_right notDiv, Comparison.ofBinOp_binOp,
    Option.isSome_some, ↓reduceIte, baseBoolean, baseEmpty, saveWarnings]
  exact silent_bind (silent_pure _) (fun _ => silent_pure _)

/-- 隣り合う二範囲の到達記録を、順序とキーの一意性を保って連結する。 -/
theorem trace_follow {key first second left right}
    (hl : TraceKeys key first left) (hr : TraceKeys (advanceKey key first) second right) :
    TraceKeys key (first + second) (left ++ right) := by
  refine ⟨List.pairwise_append.mpr ⟨hl.1, hr.1, ?_⟩, ?_⟩
  · intro a ha b hb eq
    have al := hl.2 a ha
    have br := hr.2 b hb
    have equal := congrArg OperationKey.surfacePreorder eq
    simp only [advanceKey] at br
    omega
  · intro event found
    rcases List.mem_append.mp found with found | found
    · obtain ⟨d, lo, hi⟩ := hl.2 event found
      exact ⟨d, lo, by omega⟩
    · obtain ⟨d, lo, hi⟩ := hr.2 event found
      simp only [advanceKey] at d lo hi
      exact ⟨d, by omega, by omega⟩

/-- 三つの兄弟を、各成功実行の中間状態と番号消費を使って合成する。 -/
theorem causal_three {first : Analysis α} {second : α → Analysis β}
    {third : α → β → Analysis γ} (result : α → β → γ → δ)
    {limits ctx key} {xs ys zs : List Expr} {lt mt rt}
    (start : ctx.next = key) (wx : Walk first xs) (wy : ∀ a, Walk (second a) ys)
    (hf : Causal first limits ctx key xs.length lt)
    (hm : ∀ a middle, first limits ctx = (.ok a, middle) →
      Causal (second a) limits middle (advanceKey key xs.length) ys.length mt)
    (hr : ∀ a middle b final, first limits ctx = (.ok a, middle) →
      second a limits middle = (.ok b, final) →
      Causal (third a b) limits final (advanceKey key (xs.length + ys.length)) zs.length rt)
    (lk : TraceKeys key xs.length lt)
    (mk : TraceKeys (advanceKey key xs.length) ys.length mt)
    (rk : TraceKeys (advanceKey key (xs.length + ys.length)) zs.length rt) :
    Causal (do let a ← first; let b ← second a; let c ← third a b; pure (result a b c))
      limits ctx key (xs.length + ys.length + zs.length) (lt ++ mt ++ rt) := by
  have h := causal_follow (next := fun a => do let b ← second a; let c ← third a b; pure (result a b c)) start wx hf (fun a middle ok => ?_) lk
    (trace_follow mk (by simpa only [advanceKey_add] using rk))
  · simpa only [Nat.add_assoc, List.append_assoc] using h
  · apply causal_follow ((wx.success ok).1.trans (congrArg (fun k => advanceKey k xs.length) start))
      (wy a) (hm a middle ok) _ mk (by simpa only [advanceKey_add] using rk)
    intro b final done
    exact causal_map (by simpa only [advanceKey_add] using hr a middle b final ok done) _

theorem branch_block_absent (fuel : Nat) (env : AbstractEnv) (condition : Expr)
    (tested : BaseApprox) (truth : Bool) (body : Block) (limits ctx) :
    Causal (branch env condition tested truth (fun inner => block fuel inner body)
      (fun _ => skipBlock fuel body)) limits ctx ctx.next (blockSize body) [] := by
  apply causal_branch_absent
  · intro inner middle same
    simpa only [same] using block_absent fuel inner body limits middle
  · exact (skip_silent fuel).2.2.2.2.1 body

theorem branch_expr_absent (fuel : Nat) (env : AbstractEnv) (condition : Expr)
    (tested : BaseApprox) (truth : Bool) (source : Expr) (limits ctx) :
    Causal (branch env condition tested truth (fun inner => expr fuel inner source)
      (fun _ => skipExpr fuel source)) limits ctx ctx.next (surfaceSize source) [] := by
  apply causal_branch_absent
  · intro inner middle same
    simpa only [same] using expr_absent fuel inner source limits middle
  · exact (skip_silent fuel).1 source

theorem branch_pure_silent (env source tested truth value) :
    Silent (branch env source tested truth (fun _ => pure value) (fun _ => pure ())) := by
  apply silent_scope
  apply silent_bind (silent_scan _)
  intro refined
  cases refined
  · exact silent_bind (silent_pure _) (fun _ => silent_pure _)
  · exact silent_pure _

/-- 条件と二枝の保存順を、選択枝だけを含む評価 trace へ対応させる。 -/
theorem conditional_causal (fuel : Nat) {abstract root condition yes no yesSkip noSkip}
    {ys ns : List Expr} {ct yt nt limits ctx}
    (start : ctx.next = childKey root [])
    (wy : ∀ tested, Walk (branch abstract condition tested true yes yesSkip) ys)
    (hc : Causal (expr fuel abstract condition) limits ctx (childKey root []) (surfaceSize condition) ct)
    (hy : ∀ tested middle, expr fuel abstract condition limits ctx = (.ok tested, middle) →
      Causal (branch abstract condition tested true yes yesSkip) limits middle
        (advanceKey (childKey root []) (surfaceSize condition)) ys.length yt)
    (hn : ∀ tested middle, expr fuel abstract condition limits ctx = (.ok tested, middle) →
      ∀ final, final.next = advanceKey (childKey root []) (surfaceSize condition + ys.length) →
      Causal (branch abstract condition tested false no noSkip) limits final
        (advanceKey (childKey root []) (surfaceSize condition + ys.length)) ns.length nt)
    (ck : TraceKeys (childKey root []) (surfaceSize condition) ct)
    (yk : TraceKeys (advanceKey (childKey root []) (surfaceSize condition)) ys.length yt)
    (nk : TraceKeys (advanceKey (childKey root []) (surfaceSize condition + ys.length)) ns.length nt) :
    Causal (do
      let tested ← expr fuel abstract condition
      let positive ← branch abstract condition tested true yes yesSkip
      let negative ← branch abstract condition tested false no noSkip
      pure (baseMerge tested positive negative)) limits ctx root
      (1 + surfaceSize condition + ys.length + ns.length) (ct ++ yt ++ nt) := by
  have h := causal_three (third := fun tested _ => branch abstract condition tested false no noSkip)
    baseMerge start ((analysis_walk fuel).1 abstract condition) wy hc hy
    (fun tested middle positive final ok done => hn tested middle ok final (by
      have first := (expr_success fuel abstract condition limits ctx ok).1
      have second := ((wy tested).success done).1
      simpa only [first, start, advanceKey_add] using second)) ck yk nk
  simpa only [surfaceSize, Nat.add_assoc] using h.parent

/-- 短絡の値だけの枝は警告を追加しない。 -/
theorem shortCircuit_body_causal (fuel : Nat) {abstract left right truth key lt rt limits ctx}
    (start : ctx.next = key)
    (hl : Causal (expr fuel abstract left) limits ctx key (surfaceSize left) lt)
    (hr : ∀ tested middle, expr fuel abstract left limits ctx = (.ok tested, middle) →
      Causal (branch abstract left tested truth (fun inner => expr fuel inner right)
        (fun _ => skipExpr fuel right)) limits middle (advanceKey key (surfaceSize left)) (surfaceSize right) rt)
    (lk : TraceKeys key (surfaceSize left) lt)
    (rk : TraceKeys (advanceKey key (surfaceSize left)) (surfaceSize right) rt) :
    Causal (do
      let tested ← expr fuel abstract left
      let continued ← branch abstract left tested truth (fun inner => expr fuel inner right)
        (fun _ => skipExpr fuel right)
      let shorted ← branch abstract left tested (!truth)
        (fun _ => pure (baseBoolean (truth, !truth))) (fun _ => pure ())
      pure (baseMerge tested continued shorted))
      limits ctx key (surfaceSize left + surfaceSize right) (lt ++ rt) := by
  apply causal_follow start ((analysis_walk fuel).1 abstract left) hl _ lk rk
  intro tested middle ok
  apply causal_bind (hr tested middle ok)
  intro continued final _
  exact (silent_bind (branch_pure_silent _ _ _ _ _) (fun _ => silent_pure _)).causal _ _ _ _ _

/-- 証明内だけで使う、一腕目の既存の解析の略記。 -/
private abbrev kindArmHead (fuel : Nat) (kind : IntKind) (env : AbstractEnv) (source : Expr) (normal : Interval kind)
    (alts : List Alternative) (guard : Option Expr) (body : Block) : Analysis BaseApprox :=
  scope fun _ => do
    let inner ← scan (BudgetScan.armKind env source kind normal alts)
    match inner with
    | none => do skipOptional fuel guard; skipBlock fuel body; pure baseEmpty
    | some inner =>
      match guard with
      | none => block fuel inner body
      | some condition => do
        let tested ← expr fuel inner condition
        let positive ← branch inner condition tested true
          (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
        pure (baseMerge tested positive baseEmpty)

private abbrev armSources (guard : Option Expr) (body : Block) : List Expr :=
  (match guard with | none => [] | some condition => surfacePreorder condition) ++ preorderBlock body

private theorem guardPreorder_length (guard : Option Expr) :
    (match guard with | none => [] | some condition => surfacePreorder condition).length = guardSize guard := by
  cases guard <;> rfl

private theorem armSources_length (guard : Option Expr) (body : Block) :
    (armSources guard body).length = guardSize guard + blockSize body := by
  cases guard <;> simp [armSources, guardSize, preorderBlock_length, preorder_expr_length]

private theorem kindArmHead_walk (fuel kind env source normal alts guard body) :
    Walk (kindArmHead fuel kind env source normal alts guard body) (armSources guard body) := by
  apply walk_scope
  apply walk_bind (walk_scan _)
  intro inner
  cases inner with
  | none =>
    cases guard <;>
      exact walk_bind ((skip_walk fuel).2.2.2.2.2.2.2 _) (fun _ =>
        walk_map ((skip_walk fuel).2.2.2.2.1 body) _)
  | some inner =>
    cases guard with
    | none => exact (analysis_walk fuel).2.2.1 inner body
    | some condition =>
      apply walk_bind ((analysis_walk fuel).1 inner condition)
      intro tested
      exact walk_map (walk_branch _ _ _ _ _ _ _
        (fun refined => (analysis_walk fuel).2.2.1 refined body)
        ((skip_walk fuel).2.2.2.2.1 body)) _

private theorem kindArmHead_absent (fuel kind env source normal alts guard body limits ctx) :
    Causal (kindArmHead fuel kind env source normal alts guard body) limits ctx ctx.next
      (guardSize guard + blockSize body) [] := by
  have located : Located (kindArmHead fuel kind env source normal alts guard body)
      (armSources guard body) (fun _ => False) := by
    apply located_scope
    apply located_bind (walk_scan _) (located_scan _ _)
    intro inner
    cases inner with
    | none =>
      cases guard <;>
        exact located_bind ((skip_walk fuel).2.2.2.2.2.2.2 _)
          ((skip_located fuel _).2.2.2.2.2.2.2 _) (fun _ =>
            located_map ((skip_walk fuel).2.2.2.2.1 body)
              ((skip_located fuel _).2.2.2.2.1 body) _)
    | some inner =>
      cases guard with
      | none => exact (analysis_located fuel).2.2.1 _ inner body
      | some condition =>
        apply located_bind ((analysis_walk fuel).1 inner condition)
          ((analysis_located fuel).1 _ inner condition)
        intro tested
        exact located_map
          (walk_branch _ _ _ _ _ _ _ (fun refined => (analysis_walk fuel).2.2.1 refined body)
            ((skip_walk fuel).2.2.2.2.1 body))
          (located_branch _ _ _ _ _ _ _ _
            (fun refined => (analysis_located fuel).2.2.1 _ refined body)
            ((skip_located fuel _).2.2.2.2.1 body) ((skip_walk fuel).2.2.2.2.1 body)) _
  simpa only [armSources_length] using causal_absent (limits := limits) (ctx := ctx) located

/-- 引数と Result の腕にも、実行しなかった部分の位置の保証を使える。 -/
private theorem arguments_preorder_length (sources : Exprs) :
    (preorderExprs sources).length = ((exprsChildren sources).map surfaceSize).sum := by
  cases sources with
  | nil => rfl
  | cons source rest => simp only [preorderExprs, List.length_append,
      exprsChildren, List.map_cons, List.sum_cons, arguments_preorder_length rest, surfaceSize]

private theorem surfaceSize_call (callee labels positions sources) :
    surfaceSize (.call callee labels positions sources) =
      1 + (surfaceSize callee + ((exprsChildren sources).map surfaceSize).sum) := by
  simp only [surfaceSize, surfacePreorder, List.length_cons, List.length_append,
    arguments_preorder_length, Nat.add_assoc, Nat.add_comm, Nat.add_left_comm]

theorem arguments_absent (fuel : Nat) (env : AbstractEnv) (sources : Exprs) (limits ctx) :
    Causal (arguments fuel env sources) limits ctx ctx.next
      ((exprsChildren sources).map surfaceSize).sum [] := by
  have located := (analysis_located_all fuel).2.2.2.2.1 (fun _ => False) env sources
  simpa only [arguments_preorder_length] using causal_absent (limits := limits) (ctx := ctx) located

theorem resultArms_absent (fuel : Nat) (env : AbstractEnv) (input : EvalInput)
    (arms : Arms) (limits ctx) :
    Causal (resultArmList fuel env input arms) limits ctx ctx.next (armsSize arms) [] := by
  simpa only [armsSize] using causal_absent (limits := limits) (ctx := ctx)
    ((analysis_located_all fuel).2.2.2.2.2 (fun _ => False) env input arms)

/-- Result の一腕は常に同じ元の照合値から環境を作る。 -/
private abbrev resultArmHead (fuel : Nat) (env : AbstractEnv) (input : EvalInput)
    (alts : List Alternative) (guard : Option Expr) (body : Block) : Analysis BaseApprox :=
  scope fun _ => do
    let inner ← scan (BudgetScan.rangeArm env input alts)
    match guard with
    | none => block fuel inner body
    | some condition =>
      let tested ← expr fuel inner condition
      let positive ← branch inner condition tested true
        (fun refined => block fuel refined body) (fun _ => skipBlock fuel body)
      pure (baseMerge tested positive baseEmpty)

private theorem resultArmHead_walk (fuel env input alts guard body) :
    Walk (resultArmHead fuel env input alts guard body) (armSources guard body) := by
  apply walk_scope
  apply walk_bind (walk_scan _)
  intro inner
  cases guard with
  | none => exact (analysis_walk fuel).2.2.1 inner body
  | some condition =>
    apply walk_bind ((analysis_walk fuel).1 inner condition)
    intro tested
    exact walk_map (walk_branch _ _ _ _ _ _ _
      (fun refined => (analysis_walk fuel).2.2.1 refined body)
      ((skip_walk fuel).2.2.2.2.1 body)) _

private theorem resultArmHead_absent (fuel env input alts guard body limits ctx) :
    Causal (resultArmHead fuel env input alts guard body) limits ctx ctx.next
      (guardSize guard + blockSize body) [] := by
  have located : Located (resultArmHead fuel env input alts guard body)
      (armSources guard body) (fun _ => False) := by
    apply located_scope
    apply located_bind (walk_scan _) (located_scan _ _)
    intro inner
    cases guard with
    | none => exact (analysis_located fuel).2.2.1 _ inner body
    | some condition =>
      apply located_bind ((analysis_walk fuel).1 inner condition)
        ((analysis_located fuel).1 _ inner condition)
      intro tested
      exact located_map
        (walk_branch _ _ _ _ _ _ _ (fun refined => (analysis_walk fuel).2.2.1 refined body)
          ((skip_walk fuel).2.2.2.2.1 body))
        (located_branch _ _ _ _ _ _ _ _
          (fun refined => (analysis_located fuel).2.2.1 _ refined body)
          ((skip_located fuel _).2.2.2.2.1 body) ((skip_walk fuel).2.2.2.2.1 body)) _
  simpa only [armSources_length] using causal_absent (limits := limits) (ctx := ctx) located

/-- guard と本体の追加警告を、実際に実行した二範囲へ合成する。 -/
theorem guard_causal (fuel : Nat) {abstract condition body key gt bt limits ctx}
    (start : ctx.next = key)
    (hc : Causal (expr fuel abstract condition) limits ctx key (surfaceSize condition) gt)
    (hb : ∀ tested middle, expr fuel abstract condition limits ctx = (.ok tested, middle) →
      Causal (branch abstract condition tested true (fun inner => block fuel inner body)
        (fun _ => skipBlock fuel body)) limits middle (advanceKey key (surfaceSize condition)) (blockSize body) bt)
    (ck : TraceKeys key (surfaceSize condition) gt)
    (bk : TraceKeys (advanceKey key (surfaceSize condition)) (blockSize body) bt) :
    Causal (do
      let tested ← expr fuel abstract condition
      let positive ← branch abstract condition tested true (fun inner => block fuel inner body)
        (fun _ => skipBlock fuel body)
      pure (baseMerge tested positive baseEmpty)) limits ctx key
      (surfaceSize condition + blockSize body) (gt ++ bt) := by
  apply causal_follow start ((analysis_walk fuel).1 abstract condition) hc _ ck bk
  intro tested middle ok
  exact causal_map (hb tested middle ok) _

/-- 契約位置を選ぶ解析も、引数の部分木の範囲だけに候補を作る。 -/
theorem select_absent (fuel env target positions sources limits ctx) :
    Causal (selectArguments (expr fuel env) (skipExprs fuel) target positions sources)
      limits ctx ctx.next ((exprsChildren sources).map surfaceSize).sum [] := by
  simpa only [arguments_preorder_length] using causal_absent
    (located_selectArguments _ _ _ _ _ _ ((analysis_walk fuel).1 env) ((skip_walk fuel).2.2.1)
      ((analysis_located fuel).1 (fun _ => False) env) ((skip_located fuel (fun _ => False)).2.2.1))

/-- 引数の途中の失敗・return と、正常な接頭辞を同じ順で合成する。 -/
theorem select_causal {run skip target positions env key sources types outcome trace limits ctx}
    (he : ∀ source, Walk (run source) (surfacePreorder source))
    (hs : ∀ sources, Walk (skip sources) (preorderExprs sources))
    (le : ∀ source, Located (run source) (surfacePreorder source) (fun _ => False))
    (ls : ∀ sources, Located (skip sources) (preorderExprs sources) (fun _ => False))
    (ss : ∀ sources, Silent (skip sources))
    (normal : ∀ input value trace, EvalPartial env input (.normal value) trace →
      SuccessAt input.key (run input.source) (fun approx => approx.Contains value))
    (causal : ∀ input outcome trace, EvalPartial env input outcome trace →
      ∀ limits ctx, ctx.next = input.key →
        Causal (run input.source) limits ctx input.key (surfaceSize input.source) trace)
    (eval : EvalTypedArguments env key (exprsChildren sources) types outcome trace)
    (start : ctx.next = key) :
    Causal (selectArguments run skip target positions sources) limits ctx key
      ((exprsChildren sources).map surfaceSize).sum trace := by
  rw [selectArguments.eq_def]
  apply causal_scope_same
  intro entered same
  apply causal_scan_bind _ () (BudgetScan.agrees_unit _)
  intro middle next
  have pos := next.trans (same.trans start)
  cases sources with
  | nil => cases eval; exact (silent_pure _).causal _ _ _ _ _
  | cons source rest =>
    simp only [exprsChildren, List.map_cons, List.sum_cons] at eval ⊢
    cases eval with
    | cons _ _ _ _ _ _ _ _ _ _ head tail
    | tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
      apply causal_follow pos (he source) (causal _ _ _ head limits middle pos) _
        (eval_trace_keys head) (typed_arguments_trace_keys tail)
      intro tested after ok
      have modeled := normal _ _ _ head limits middle pos tested (by simp only [ok])
      simp only [contains_live modeled, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      apply causal_map
      apply select_causal he hs le ls ss normal causal tail
      simpa only [pos, surfaceSize] using ((he source).success ok).1
    | headAbrupt _ _ _ _ _ _ _ _ head abrupt =>
      rw [← List.append_nil trace]
      apply causal_follow pos (he source) (causal _ _ _ head limits middle pos) _
        (eval_trace_keys head) (by simp [TraceKeys])
      intro tested after ok
      split
      · exact (silent_bind (ss rest) (fun _ => silent_pure _)).causal _ _ _ _ _
      · apply causal_map
        have absent := causal_absent (limits := limits) (ctx := after)
          (located_selectArguments run skip target positions.tail rest (fun _ => False) he hs le ls)
        simpa only [arguments_preorder_length, (he source).success ok |>.1, pos, surfaceSize] using absent
termination_by sources

private theorem selected_fixed_bounds {binding key selected warning}
    (member : warning ∈ (selectedFixedOwn binding key selected).warnings) : KeyWithin key 1 warning.key := by
  obtain ⟨rfl, _⟩ := baseFixedOwn_warning member
  exact ⟨rfl, Nat.le_refl _, Nat.lt_succ_self _⟩

theorem causal_fixedOwn {binding selected root limits ctx key size trace}
    (valid : ∀ warning ∈ (selectedFixedOwn binding root selected).warnings, CauseIn key size trace warning) :
    Causal (fixedOwn binding root selected) limits ctx key size trace := by
  exact causal_bind (causal_saveWarnings _ _ _ _ _ _ valid)
    (fun _ middle _ => (silent_pure _).causal limits middle key size trace)

private theorem selected_fixed_cause {binding selected root arguments output warning}
    (modeled : StandardSelected binding arguments selected)
    (evaluated : EvalStandard binding.rule root arguments output)
    (member : warning ∈ (selectedFixedOwn binding root selected).warnings) :
    CauseIn root 1 [⟨root, .standard binding, arguments, output⟩] warning := by
  refine ⟨selected_fixed_bounds member, ?_⟩
  obtain ⟨rfl, outside⟩ := baseFixedOwn_warning member
  intro event reached
  cases List.mem_singleton.mp reached.1
  exact selectedFixedOutside_reject modeled evaluated outside

private theorem surfaceSize_record (constructor types positions sources) :
    surfaceSize (.record constructor types positions sources) =
      1 + ((exprsChildren sources).map surfaceSize).sum := by
  rw [surfaceSize_children]; rfl

private theorem surfaceSize_recordUpdate (constructor types count positions base sources) :
    surfaceSize (.recordUpdate constructor types count positions base sources) =
      1 + (surfaceSize base + ((exprsChildren sources).map surfaceSize).sum) := by
  rw [surfaceSize_children]; rfl

private theorem selected_causal_run (fuel : Nat)
    {abstract concrete key sources types outcome trace target positions limits ctx}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (children : ∀ input outcome trace, EvalPartial concrete input outcome trace →
      ∀ limits ctx, ctx.next = input.key →
        Causal (expr fuel abstract input.source) limits ctx input.key (surfaceSize input.source) trace)
    (eval : EvalTypedArguments concrete key (exprsChildren sources) types outcome trace)
    (start : ctx.next = key) :
    Causal (selectArguments (expr fuel abstract) (skipExprs fuel) target positions sources)
      limits ctx key ((exprsChildren sources).map surfaceSize).sum trace := by
  exact select_causal ((analysis_walk fuel).1 abstract) ((skip_walk fuel).2.2.1)
    ((analysis_located fuel).1 (fun _ => False) abstract) ((skip_located fuel (fun _ => False)).2.2.1)
    ((skip_silent fuel).2.2.1)
    (fun input value trace child => (expr_normal fuel models ranges child).mono (fun _ covered => covered _ rfl))
    children eval start

private theorem standard_selected_models {binding positions values arguments selected}
    (models : SelectedModels (bindingArgument binding) positions values selected)
    (ordered : orderArguments positions values = some arguments) :
    StandardSelected binding arguments selected := by
  intro value found
  have bound : bindingArgument binding < positions.length := by
    rw [← order_arguments_length ordered]
    exact (List.getElem?_eq_some_iff.mp found).1
  exact models.2 value ((order_arguments_field ordered bound).trans found)

private theorem selected_call_normal_causal (fuel : Nat)
    {abstract concrete root callee labels positions sources binding values arguments output trace limits ctx}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (children : ∀ input outcome trace, EvalPartial concrete input outcome trace →
      ∀ limits ctx, ctx.next = input.key →
        Causal (expr fuel abstract input.source) limits ctx input.key (surfaceSize input.source) trace)
    (eval : EvalTypedArguments concrete (childKey root [callee]) (exprsChildren sources)
      (binding.sourceTypes positions) (.normal values) trace)
    (ordered : orderArguments positions values = some arguments)
    (evaluated : EvalStandard binding.rule root arguments output)
    (start : ctx.next = childKey root [callee]) :
    Causal (do
      let selected ← selectArguments (expr fuel abstract) (skipExprs fuel) (bindingArgument binding) positions sources
      pure (baseThen selected (← fixedOwn binding root selected)))
      limits ctx root (surfaceSize (.call callee labels positions sources))
      (trace ++ [⟨root, .standard binding, arguments, output⟩]) := by
  have rootKeys : TraceKeys root 1 [⟨root, .standard binding, arguments, output⟩] := by simp [TraceKeys, KeyWithin]
  refine causal_bind ((selected_causal_run fuel models ranges children eval start).mono ?_) ?_
  · intro warning h
    apply (h.append_left rootKeys (Or.inr (by simp [childKey]))).widen
    intro k bounds
    simp only [KeyWithin, childKey, List.map_cons, List.map_nil, List.sum_cons,
      List.sum_nil, Nat.add_zero, surfaceSize_call] at bounds ⊢
    exact ⟨bounds.1, by omega, by omega⟩
  · intro selected final ok
    have modeled := selectArguments_normal (target := bindingArgument binding) (positions := positions)
      ((analysis_walk fuel).1 abstract) ((skip_walk fuel).2.2.1)
      (fun input value trace child => expr_value_normal fuel models ranges child) eval
      limits ctx start selected (by simp only [ok])
    apply causal_map
    apply causal_fixedOwn
    intro warning member
    have own := selected_fixed_cause (standard_selected_models modeled ordered) evaluated member
    apply (own.append_right (typed_arguments_trace_keys eval) (Or.inl (by simp [childKey]))).widen
    intro k bounds
    simp only [KeyWithin, surfaceSize_call] at bounds ⊢
    exact ⟨bounds.1, bounds.2.1, by omega⟩

private theorem selected_call_abrupt_causal (fuel : Nat)
    {abstract concrete root callee labels positions sources binding types outcome trace limits ctx}
    (models : Models abstract concrete) (ranges : abstract.ranges.Models concrete)
    (children : ∀ input outcome trace, EvalPartial concrete input outcome trace →
      ∀ limits ctx, ctx.next = input.key →
        Causal (expr fuel abstract input.source) limits ctx input.key (surfaceSize input.source) trace)
    (eval : EvalTypedArguments concrete (childKey root [callee]) (exprsChildren sources) types outcome trace)
    (start : ctx.next = childKey root [callee]) :
    Causal (do
      let selected ← selectArguments (expr fuel abstract) (skipExprs fuel) (bindingArgument binding) positions sources
      pure (baseThen selected (← fixedOwn binding root selected)))
      limits ctx root (surfaceSize (.call callee labels positions sources)) trace := by
  refine causal_bind ((selected_causal_run fuel models ranges children eval start).mono ?_) ?_
  · intro warning h
    apply h.widen
    intro k bounds
    simp only [KeyWithin, childKey, List.map_cons, List.map_nil, List.sum_cons,
      List.sum_nil, Nat.add_zero, surfaceSize_call] at bounds ⊢
    exact ⟨bounds.1, by omega, by omega⟩
  · intro selected final ok
    apply causal_map
    apply causal_fixedOwn
    intro warning member
    have own := CauseIn.emptyTrace (selected_fixed_bounds member)
    have combined := own.append_right (typed_arguments_trace_keys eval) (Or.inl (by simp [childKey]))
    apply (show CauseIn root 1 trace warning from by simpa only [List.append_nil] using combined).widen
    intro k bounds
    simp only [KeyWithin, surfaceSize_call] at bounds ⊢
    exact ⟨bounds.1, bounds.2.1, by omega⟩

set_option maxHeartbeats 1600000 in
mutual
/-- 任意の共有状態に追加した警告は、その部分木で到達した演算の拒否原因と一致する。 -/
theorem expr_causal (fuel : Nat) {abstract concrete input outcome trace}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalPartial concrete input outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = input.key) :
    Causal (expr fuel abstract input.source) limits ctx input.key (surfaceSize input.source) trace := by
  by_cases empty : trace = []
  · subst trace
    simpa only [start] using expr_absent fuel abstract input.source limits ctx
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [expr.eq_def]
    apply causal_scope_same
    intro entered same
    apply causal_identified (same.trans start)
    intro middle next
    match eval with
    | .standardCall _ key callee labels positions sources binding values arguments output ct recognized children ordered evaluated =>
      apply causal_scan_bind _ _ (BudgetScan.rangeCall_agrees _ _ _)
      intro ready same
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, binding.rule.resultType, key⟩) models).trans recognized
      simp only [atCall]
      apply causal_bind (((skip_silent fuel).1 callee).causal _ _ _ _ _)
      intro ignored after skipped
      cases ignored
      have argsStart : after.next = childKey key [callee] := by
        have progress := (skipExpr_success fuel callee limits ready skipped).1
        simpa only [same, next, advanceKey, childKey, List.map_nil, List.sum_nil,
          List.map_cons, List.sum_cons, Nat.add_zero, Nat.add_assoc, surfaceSize] using progress
      split
      · exact selected_call_normal_causal fuel models rmodels
          (fun input outcome trace child => expr_causal fuel models rmodels child) children ordered evaluated argsStart
      · have ownKeys : TraceKeys key 1 [⟨key, .standard binding, arguments, output⟩] := by
          simp [TraceKeys, KeyWithin]
        refine causal_bind ((typed_arguments_causal fuel models rmodels children limits after argsStart).mono ?_) ?_
        · intro warning h
          apply (h.append_left ownKeys (Or.inr (by simp [childKey]))).widen
          intro k bounds
          simp only [KeyWithin, childKey, List.map_cons, List.map_nil, List.sum_cons,
            List.sum_nil, Nat.add_zero, surfaceSize_call] at bounds ⊢
          exact ⟨bounds.1, by omega, by omega⟩
        · intro value final ok
          exact (silent_bind (silent_scan _) (fun _ => silent_pure _)).causal _ _ _ _ _
    | .standardCallAbrupt _ key callee labels positions sources binding result ct recognized children abrupt =>
      apply causal_scan_bind _ _ (BudgetScan.rangeCall_agrees _ _ _)
      intro ready same
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, binding.rule.resultType, key⟩) models).trans recognized
      simp only [atCall]
      apply causal_bind (((skip_silent fuel).1 callee).causal _ _ _ _ _)
      intro ignored after skipped
      cases ignored
      have argsStart : after.next = childKey key [callee] := by
        have progress := (skipExpr_success fuel callee limits ready skipped).1
        simpa only [same, next, advanceKey, childKey, List.map_nil, List.sum_nil,
          List.map_cons, List.sum_cons, Nat.add_zero, Nat.add_assoc, surfaceSize] using progress
      split
      · exact selected_call_abrupt_causal fuel models rmodels
          (fun input outcome trace child => expr_causal fuel models rmodels child) children argsStart
      · refine causal_bind ((typed_arguments_causal fuel models rmodels children limits after argsStart).mono ?_) ?_
        · intro warning h
          apply h.widen
          intro k bounds
          simp only [KeyWithin, childKey, List.map_cons, List.map_nil, List.sum_cons,
            List.sum_nil, Nat.add_zero, surfaceSize_call] at bounds ⊢
          exact ⟨bounds.1, by omega, by omega⟩
        · intro value final ok
          exact (silent_bind (silent_scan _) (fun _ => silent_pure _)).causal _ _ _ _ _
    | .fixedCallFailed _ key callee labels positions sources binding values arguments reason type ct recognized fixed children ordered evaluated =>
      apply causal_scan_bind _ _ (BudgetScan.rangeCall_agrees _ _ _)
      intro ready same
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, type, key⟩) models).trans recognized
      simp only [atCall, show fixedBinding binding = true from fixed, ↓reduceIte]
      apply causal_bind (((skip_silent fuel).1 callee).causal _ _ _ _ _)
      intro ignored after skipped
      cases ignored
      have argsStart : after.next = childKey key [callee] := by
        have progress := (skipExpr_success fuel callee limits ready skipped).1
        simpa only [same, next, advanceKey, childKey, List.map_nil, List.sum_nil,
          List.map_cons, List.sum_cons, Nat.add_zero, Nat.add_assoc, surfaceSize] using progress
      exact selected_call_normal_causal fuel models rmodels
        (fun input outcome trace child => expr_causal fuel models rmodels child) children ordered evaluated argsStart
    | .fixedCallAbrupt _ key callee labels positions sources binding type outcome ct recognized fixed children abrupt =>
      apply causal_scan_bind _ _ (BudgetScan.rangeCall_agrees _ _ _)
      intro ready same
      have atCall : rangeCallAt abstract key (.call callee labels positions sources) = some binding :=
        (range_call_at_agrees (input := ⟨.call callee labels positions sources, type, key⟩) models).trans recognized
      simp only [atCall, show fixedBinding binding = true from fixed, ↓reduceIte]
      apply causal_bind (((skip_silent fuel).1 callee).causal _ _ _ _ _)
      intro ignored after skipped
      cases ignored
      have argsStart : after.next = childKey key [callee] := by
        have progress := (skipExpr_success fuel callee limits ready skipped).1
        simpa only [same, next, advanceKey, childKey, List.map_nil, List.sum_nil,
          List.map_cons, List.sum_cons, Nat.add_zero, Nat.add_assoc, surfaceSize] using progress
      exact selected_call_abrupt_causal fuel models rmodels
        (fun input outcome trace child => expr_causal fuel models rmodels child) children argsStart
    | .unknownNormal .. | .unknownFailed .. => exact False.elim (empty rfl)
    | .integer .. | .negInt .. | .boolean .. | .unit .. =>
      exact (silent_pure _).causal _ _ _ _ _
    | .integer8 .. | .integer16 .. | .integer32 .. | .unsignedInteger16 .. | .unsignedInteger32 .. | .unsignedInteger64 ..
    | .negInteger8 .. | .negInteger16 .. | .negInteger32 .. =>
      exact (silent_widthLiteral _ _).causal _ _ _ _ _
    | .local .. =>
      apply Silent.causal
      apply silent_bind (silent_scan _)
      intro slot
      cases slot with
      | none => exact silent_pure _
      | some slot => cases slot <;> first
        | exact silent_pure _
        | exact silent_pure _
    | .paren _ _ _ _ _ _ child =>
      simpa only [surfaceSize_paren] using (expr_causal fuel models rmodels child limits middle next).parent
    | .constE _ _ _ _ _ _ child =>
      simpa only [surfaceSize_constE] using (expr_causal fuel (models_clearLocals models) (ranges_clearLocals _ _) child limits middle next).parent
    | .returnE _ _ _ _ _ _ _ child | .not _ _ _ _ _ child | .notAbrupt _ _ _ _ _ child _ =>
      simpa only [surfaceSize_returnE, surfaceSize_not] using (causal_map (expr_causal fuel models rmodels child limits middle next) _).parent
    | .block _ _ _ _ _ _ child =>
      simpa only [surfaceSize_block] using (block_causal fuel models rmodels child limits middle next).parent
    | .neg _ key source a trace child =>
      simp only [surfaceSize_neg, negModeled_integer, negOwnTyped_integer, ↓reduceIte]
      apply causal_bind_root next (by simpa only [next] using expr_causal fuel models rmodels child limits middle next) _
        (by simpa only [next] using eval_trace_keys child) (by simp [TraceKeys])
      intro tested final ok
      apply causal_map
      apply causal_negOwn
      intro warning member
      exact negOwn_cause ((expr_normal_next fuel models rmodels child ok).1 _ rfl) member
    | .negAbrupt _ key source outcome trace child abrupt =>
      simp only [surfaceSize_neg, negModeled_integer, negOwnTyped_integer, ↓reduceIte]
      have h := causal_bind_root (ot := []) next
        (by simpa only [next] using expr_causal fuel models rmodels child limits middle next)
        (fun tested final _ => causal_map
          (causal_negOwn (fun _ member => negOwn_cause_absent key tested member))
          (fun approx => baseThen tested approx))
        (by simpa only [next] using eval_trace_keys child) (by simp [TraceKeys])
      simpa only [List.append_nil] using h
    | .widthNeg _ key kind source a trace not64 signed child =>
      simp only [surfaceSize_neg, negModeled_kind kind signed, ↓reduceIte]
      apply causal_bind_root next (by simpa only [next] using expr_causal fuel models rmodels child limits middle next) _
        (by simpa only [next] using eval_trace_keys child) (by simp [TraceKeys])
      intro tested final ok
      apply causal_map
      apply causal_negOwnTyped
      intro warning member
      exact negOwnTyped_width_cause not64 ((expr_normal_next fuel models rmodels child ok).1 _ rfl) member
    | .widthNegAbrupt _ key kind source outcome trace not64 signed child abrupt =>
      simp only [surfaceSize_neg, negModeled_kind kind signed, ↓reduceIte]
      have h := causal_bind_root (ot := []) next
        (by simpa only [next] using expr_causal fuel models rmodels child limits middle next)
        (fun tested final _ => causal_map
          (causal_negOwnTyped (fun _ member => negOwnTyped_cause_absent key kind.type tested member))
          (fun approx => baseThen tested approx))
        (by simpa only [next] using eval_trace_keys child) (by simp [TraceKeys])
      simpa only [List.append_nil] using h
    | .widthBinary _ key kind op left right a b lt rt not64 el er =>
      simp only [surfaceSize_binary, binarySupported_kind, ↓reduceIte]
      apply binary_typed_causal fuel next (expr_causal fuel models rmodels el limits middle next) _ _
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · intro lhs after ok
        apply expr_causal fuel models rmodels er
        have pos := (expr_success fuel abstract left limits middle ok).1
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · intro lhs after rhs final hl hr
        apply causal_own
        intro warning member
        have rightStart : after.next = childKey key [left] := by
          have progress := (expr_success fuel abstract left limits middle hl).1
          simpa only [next, advanceKey, childKey, List.map_cons, List.map_nil,
            List.sum_cons, List.sum_nil, Nat.add_zero, Nat.add_assoc] using progress
        exact own_width_cause not64 ((expr_normal_next fuel models rmodels el hl).1 _ rfl)
          ((expr_normal_next fuel models rmodels er hr rightStart).1 _ rfl) member
    | .widthBinaryLeftAbrupt _ key kind op left right outcome trace not64 el abrupt =>
      simp only [surfaceSize_binary, binarySupported_kind, ↓reduceIte]
      have h := binary_typed_causal fuel (op := op.op) (type := kind.type) (right := right) (rt := []) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        have absent := expr_absent fuel abstract right limits after
        simpa [pos, next, childKey, advanceKey, surfaceSize] using absent
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .widthBinaryRightAbrupt _ key kind op left right a outcome lt rt not64 el er abrupt =>
      simp only [surfaceSize_binary, binarySupported_kind, ↓reduceIte]
      have h := binary_typed_causal fuel (op := op.op) (type := kind.type) (right := right) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .add _ key left right a b lt rt el er =>
      simp only [surfaceSize_binary, binarySupported, true_or, decide_true, ↓reduceIte]
      apply binary_causal fuel next (expr_causal fuel models rmodels el limits middle next) _ _
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · intro lhs after ok
        have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simpa [next, childKey, advanceKey, surfaceSize] using pos
      · intro lhs after rhs final hl hr
        exact causal_add_of_operands fuel models rmodels el er next hl hr
    | .sub _ key left right a b lt rt el er =>
      simp only [surfaceSize_binary, binarySupported, true_or, or_true, decide_true, ↓reduceIte]
      apply binary_causal fuel next (expr_causal fuel models rmodels el limits middle next) _ _
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · intro lhs after ok
        have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simpa [next, childKey, advanceKey, surfaceSize] using pos
      · intro lhs after rhs final hl hr
        exact causal_sub_of_operands fuel models rmodels el er next hl hr
    | .mul _ key left right a b lt rt el er =>
      simp only [surfaceSize_binary, binarySupported, true_or, or_true, decide_true, ↓reduceIte]
      apply binary_causal fuel next (expr_causal fuel models rmodels el limits middle next) _ _
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · intro lhs after ok
        have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simpa [next, childKey, advanceKey, surfaceSize] using pos
      · intro lhs after rhs final hl hr
        exact causal_mul_of_operands fuel models rmodels el er next hl hr
    | .divMod _ key op left right a b lt rt target el er =>
      have supported : binarySupported op (.base .integer) = true := by simp [binarySupported, target]
      simp only [surfaceSize_binary, supported, ↓reduceIte]
      apply binary_causal fuel next (expr_causal fuel models rmodels el limits middle next) _ _
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · intro lhs after ok
        have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simpa [next, childKey, advanceKey, surfaceSize] using pos
      · intro lhs after rhs final hl hr
        exact causal_div_of_operands fuel target models rmodels el er next hl hr
    | .compare _ key op left right a b lt rt el er =>
      have supported : binarySupported op.binOp (.base .integer) = true := by simp [binarySupported]
      simp only [surfaceSize_binary, supported, ↓reduceIte]
      apply binary_causal fuel next (expr_causal fuel models rmodels el limits middle next) _ _
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · intro lhs after ok
        have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simpa [next, childKey, advanceKey, surfaceSize] using pos
      · intro lhs after rhs final hl hr
        exact own_compare_silent op key lhs rhs |>.causal _ _ _ _ _
    | .addLeftAbrupt _ key left right result lt el _ =>
      simp only [surfaceSize_binary, binarySupported, true_or, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := .add) (right := right) (ot := []) (rt := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        have absent := expr_absent fuel abstract right limits after
        simpa [pos, next, childKey, advanceKey, surfaceSize] using absent
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .subLeftAbrupt _ key left right result lt el _ =>
      simp only [surfaceSize_binary, binarySupported, true_or, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := .sub) (right := right) (ot := []) (rt := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        have absent := expr_absent fuel abstract right limits after
        simpa [pos, next, childKey, advanceKey, surfaceSize] using absent
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .mulLeftAbrupt _ key left right result lt el _ =>
      simp only [surfaceSize_binary, binarySupported, true_or, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := .mul) (right := right) (ot := []) (rt := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        have absent := expr_absent fuel abstract right limits after
        simpa [pos, next, childKey, advanceKey, surfaceSize] using absent
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .divModLeftAbrupt _ key op left right result lt target el _ =>
      simp only [surfaceSize_binary, binarySupported, target, true_or, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := op) (right := right) (ot := []) (rt := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        have absent := expr_absent fuel abstract right limits after
        simpa [pos, next, childKey, advanceKey, surfaceSize] using absent
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .compareLeftAbrupt _ key op left right result lt el _ =>
      simp only [surfaceSize_binary, binarySupported, Comparison.ofBinOp_binOp, Option.isSome_some, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := op.binOp) (right := right) (ot := []) (rt := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        have absent := expr_absent fuel abstract right limits after
        simpa [pos, next, childKey, advanceKey, surfaceSize] using absent
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .addRightAbrupt _ key left right a result lt rt el er _ =>
      simp only [surfaceSize_binary, binarySupported, true_or, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := .add) (right := right) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .subRightAbrupt _ key left right a result lt rt el er _ =>
      simp only [surfaceSize_binary, binarySupported, true_or, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := .sub) (right := right) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .mulRightAbrupt _ key left right a result lt rt el er _ =>
      simp only [surfaceSize_binary, binarySupported, true_or, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := .mul) (right := right) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .divModRightAbrupt _ key op left right a result lt rt target el er _ =>
      simp only [surfaceSize_binary, binarySupported, target, true_or, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := op) (right := right) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .compareRightAbrupt _ key op left right a result lt rt el er _ =>
      simp only [surfaceSize_binary, binarySupported, Comparison.ofBinOp_binOp, Option.isSome_some, or_true, decide_true, ↓reduceIte]
      have h := binary_causal fuel (op := op.binOp) (right := right) (ot := []) next
        (expr_causal fuel models rmodels el limits middle next) (fun lhs after ok => ?_) (fun _ _ _ _ _ _ => ?_)
        (eval_trace_keys el) (eval_trace_keys er) (by simp [TraceKeys])
      · simpa only [List.append_nil, surfaceSize] using h
      · have pos := (expr_success fuel abstract left limits middle ok).1
        apply expr_causal fuel models rmodels er
        simp [pos, next, childKey, advanceKey, surfaceSize]
      · exact causal_own (fun _ member => own_cause_absent _ _ _ _ _ member)
    | .iteTrue _ key cond yes no _ _ ct bt condition child =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun inner => block fuel inner no)) (noSkip := (fun _ => skipBlock fuel no))
        (ys := preorderBlock yes) (ns := preorderBlock no) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _ (fun inner => (analysis_walk fuel).2.2.1 inner yes)
          ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition)
        (by simpa [childKey, advanceKey, preorderBlock_length] using block_trace_keys child)
        (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly, preorderBlock_length, preorder_expr_length, List.append_nil, List.nil_append, List.length_nil, Nat.add_zero] using h
      · obtain ⟨inner, entry, related, rr⟩ := branch_entry_of_success fuel models rmodels condition ok
        apply causal_branch_selected entry
        intro final pos
        have key := (expr_success fuel abstract cond limits middle ok).1
        have h := block_causal fuel related rr child limits final (by
          simp [pos, key, next, childKey, advanceKey])
        simpa [childKey, advanceKey, preorderBlock_length] using h
      · have absent := branch_block_absent fuel abstract cond tested false no limits final
        simpa only [pos, preorderBlock_length, surfaceSize] using absent
    | .elseIfTrue _ key cond yes no _ _ ct bt condition child =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun inner => expr fuel inner no)) (noSkip := (fun _ => skipExpr fuel no))
        (ys := preorderBlock yes) (ns := surfacePreorder no) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _ (fun inner => (analysis_walk fuel).2.2.1 inner yes)
          ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition)
        (by simpa [childKey, advanceKey, preorderBlock_length] using block_trace_keys child)
        (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly, preorderBlock_length, preorder_expr_length, List.append_nil, List.nil_append, List.length_nil, Nat.add_zero] using h
      · obtain ⟨inner, entry, related, rr⟩ := branch_entry_of_success fuel models rmodels condition ok
        apply causal_branch_selected entry
        intro final pos
        have key := (expr_success fuel abstract cond limits middle ok).1
        have h := block_causal fuel related rr child limits final (by
          simp [pos, key, next, childKey, advanceKey])
        simpa [childKey, advanceKey, preorderBlock_length] using h
      · have absent := branch_expr_absent fuel abstract cond tested false no limits final
        simpa only [pos, preorderBlock_length, surfaceSize] using absent
    | .ifOnlyTrue _ key cond yes _ ct bt condition child =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun _ => pure baseUnit)) (noSkip := (fun _ => pure ()))
        (ys := preorderBlock yes) (ns := []) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _ (fun inner => (analysis_walk fuel).2.2.1 inner yes)
          ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition)
        (by simpa [childKey, advanceKey, preorderBlock_length] using block_trace_keys child)
        (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly, preorderBlock_length, preorder_expr_length, List.append_nil, List.nil_append, List.length_nil, Nat.add_zero] using h
      · obtain ⟨inner, entry, related, rr⟩ := branch_entry_of_success fuel models rmodels condition ok
        apply causal_branch_selected entry
        intro final pos
        have key := (expr_success fuel abstract cond limits middle ok).1
        have h := block_causal fuel related rr child limits final (by
          simp [pos, key, next, childKey, advanceKey])
        simpa [childKey, advanceKey, preorderBlock_length] using h
      · exact (branch_pure_silent _ _ _ _ _).causal _ _ _ _ _
    | .iteFalse _ key cond yes no _ _ ct bt condition child =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun inner => block fuel inner no)) (noSkip := (fun _ => skipBlock fuel no))
        (ys := preorderBlock yes) (ns := preorderBlock no) (yt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _ (fun inner => (analysis_walk fuel).2.2.1 inner yes)
          ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition) (by simp [TraceKeys])
        (by simpa [childKey, advanceKey, preorderBlock_length, blockSize, Nat.add_assoc] using block_trace_keys child)
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly, preorderBlock_length, preorder_expr_length, List.append_nil, List.nil_append, List.length_nil, Nat.add_zero] using h
      · have absent := branch_block_absent fuel abstract cond tested true yes limits after
        have key := (expr_success fuel abstract cond limits middle ok).1
        simpa only [key, next, preorderBlock_length, surfaceSize] using absent
      · obtain ⟨inner, entry, related, rr⟩ := branch_entry_of_success fuel models rmodels condition ok
        apply causal_branch_selected entry
        intro last same
        have h := block_causal fuel related rr child limits last (by
          simp [same, pos, childKey, advanceKey, preorderBlock_length, blockSize, Nat.add_assoc])
        simpa [childKey, advanceKey, preorderBlock_length, blockSize, surfaceSize, Nat.add_assoc] using h
    | .elseIfFalse _ key cond yes no _ _ ct bt condition child =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun inner => expr fuel inner no)) (noSkip := (fun _ => skipExpr fuel no))
        (ys := preorderBlock yes) (ns := surfacePreorder no) (yt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _ (fun inner => (analysis_walk fuel).2.2.1 inner yes)
          ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition) (by simp [TraceKeys])
        (by simpa [childKey, advanceKey, preorderBlock_length, blockSize, surfaceSize, Nat.add_assoc] using eval_trace_keys child)
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly, preorderBlock_length, preorder_expr_length, List.append_nil, List.nil_append, List.length_nil, Nat.add_zero] using h
      · have absent := branch_block_absent fuel abstract cond tested true yes limits after
        have key := (expr_success fuel abstract cond limits middle ok).1
        simpa only [key, next, preorderBlock_length, surfaceSize] using absent
      · obtain ⟨inner, entry, related, rr⟩ := branch_entry_of_success fuel models rmodels condition ok
        apply causal_branch_selected entry
        intro last same
        have h := expr_causal fuel related rr child limits last (by
          simp [same, pos, childKey, advanceKey, preorderBlock_length, blockSize, Nat.add_assoc])
        simpa [childKey, advanceKey, preorderBlock_length, blockSize, surfaceSize, Nat.add_assoc] using h
    | .ifOnlyFalse _ key cond yes ct condition =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun _ => pure baseUnit)) (noSkip := (fun _ => pure ()))
        (ys := preorderBlock yes) (ns := []) (yt := []) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _ (fun inner => (analysis_walk fuel).2.2.1 inner yes)
          ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition) (by simp [TraceKeys])
        (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, surfaceSize_elseIf, surfaceSize_ifOnly, preorderBlock_length, preorder_expr_length, List.append_nil, List.nil_append, List.length_nil, Nat.add_zero] using h
      · have absent := branch_block_absent fuel abstract cond tested true yes limits after
        have key := (expr_success fuel abstract cond limits middle ok).1
        simpa only [key, next, preorderBlock_length, surfaceSize] using absent
      · exact (branch_pure_silent _ _ _ _ _).causal _ _ _ _ _
    | .iteAbrupt _ key cond yes no _ _ ct condition _ =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun inner => block fuel inner no)) (noSkip := (fun _ => skipBlock fuel no))
        (ys := preorderBlock yes) (ns := preorderBlock no) (yt := []) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _
          (fun inner => (analysis_walk fuel).2.2.1 inner yes) ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition)
        (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ite, preorderBlock_length,
          preorder_expr_length, List.append_nil, List.length_nil, Nat.add_zero] using h
      · have key := (expr_success fuel abstract cond limits middle ok).1
        have h := branch_block_absent fuel abstract cond tested true yes limits after
        simpa only [key, next, surfaceSize, preorderBlock_length] using h
      · have h := branch_block_absent fuel abstract cond tested false no limits final
        simpa only [pos, surfaceSize, preorderBlock_length] using h
    | .elseIfAbrupt _ key cond yes no _ _ ct condition _ =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun inner => expr fuel inner no)) (noSkip := (fun _ => skipExpr fuel no))
        (ys := preorderBlock yes) (ns := surfacePreorder no) (yt := []) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _
          (fun inner => (analysis_walk fuel).2.2.1 inner yes) ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition)
        (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_elseIf, preorderBlock_length,
          preorder_expr_length, List.append_nil, List.length_nil, Nat.add_zero] using h
      · have key := (expr_success fuel abstract cond limits middle ok).1
        have h := branch_block_absent fuel abstract cond tested true yes limits after
        simpa only [key, next, surfaceSize, preorderBlock_length] using h
      · have h := branch_expr_absent fuel abstract cond tested false no limits final
        simpa only [pos, surfaceSize, preorderBlock_length] using h
    | .ifOnlyAbrupt _ key cond yes _ ct condition _ =>
      have h := conditional_causal fuel (yes := fun inner => block fuel inner yes)
        (yesSkip := fun _ => skipBlock fuel yes) (no := (fun _ => pure baseUnit)) (noSkip := (fun _ => pure ()))
        (ys := preorderBlock yes) (ns := []) (yt := []) (nt := []) next
        (fun tested => walk_branch _ _ _ _ _ (fun _ => skipBlock fuel yes) _
          (fun inner => (analysis_walk fuel).2.2.1 inner yes) ((skip_walk fuel).2.2.2.2.1 yes))
        (expr_causal fuel models rmodels condition limits middle next) (fun tested after ok => ?_)
        (fun tested after ok final pos => ?_) (eval_trace_keys condition)
        (by simp [TraceKeys]) (by simp [TraceKeys])
      · simpa only [EvalInput.source, EvalInput.key, surfaceSize_ifOnly, preorderBlock_length,
          preorder_expr_length, List.append_nil, List.length_nil, Nat.add_zero] using h
      · have key := (expr_success fuel abstract cond limits middle ok).1
        have h := branch_block_absent fuel abstract cond tested true yes limits after
        simpa only [key, next, surfaceSize, preorderBlock_length] using h
      · exact (branch_pure_silent _ _ _ _ _).causal _ _ _ _ _
    | .andRight _ key left right _ _ _ condition child
    | .orRight _ key left right _ _ _ condition child =>
      have h := shortCircuit_run_causal fuel models rmodels condition (by
        simpa [childKey, advanceKey] using child) limits middle next
      simpa only [surfaceSize_and, surfaceSize_or, Nat.add_assoc] using h.parent
    | .andShort _ key left right _ condition =>
      have h := shortCircuit_absent_causal fuel (right := right) (truth := true) models rmodels condition limits middle next
      simpa only [surfaceSize_and, surfaceSize_or, Nat.add_assoc] using h.parent
    | .orShort _ key left right _ condition =>
      have h := shortCircuit_absent_causal fuel (right := right) (truth := false) models rmodels condition limits middle next
      simpa only [surfaceSize_and, surfaceSize_or, Nat.add_assoc] using h.parent
    | .andAbrupt _ key left right _ _ condition _ =>
      have h := shortCircuit_absent_causal fuel (right := right) (truth := true) models rmodels condition limits middle next
      simpa only [surfaceSize_and, surfaceSize_or, Nat.add_assoc] using h.parent
    | .orAbrupt _ key left right _ _ condition _ =>
      have h := shortCircuit_absent_causal fuel (right := right) (truth := false) models rmodels condition limits middle next
      simpa only [surfaceSize_and, surfaceSize_or, Nat.add_assoc] using h.parent
    | .matchInteger _ key source arms _ integer _ st armTrace child selected =>
      simp only [surfaceSize_matchE, Nat.add_assoc]
      change Causal _ limits middle key (1 + (surfaceSize source + armsSize arms)) _
      apply Causal.parent
      apply causal_follow next
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels child limits middle next) (fun tested after ok => ?_)
        (eval_trace_keys child) (by
          simpa [childKey, advanceKey, surfaceSize] using arms_trace_keys selected)
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms) (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_scan_bind _ _ (BudgetScan.rangeMatch_agrees _ _ _)
          intro scanned preserved
          have absent := range_match_at_integer_none (kind := .integer64) (arms := arms) models rmodels child
          simp only [absent]
          cases choice : tested.matchKind with
            | some kind =>
              have inside := (expr_normal_next fuel models rmodels child ok).1 _ rfl
              have same : kind = .integer64 := (matchKind_contains (actual := .integer64) inside choice).symm
              subst kind
              apply causal_map
              apply armList_causal fuel models rmodels child inside selected
              have pos := (expr_success fuel abstract source limits middle ok).1
              simp [preserved, pos, next, childKey, advanceKey, surfaceSize]
            | none => exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms)
                (fun _ => silent_bind silent_unsupported (fun _ => silent_pure _))).causal _ _ _ _ _
    | .matchWidth _ key kind source arms _ integer _ st armTrace not64 child selected =>
      simp only [surfaceSize_matchE, Nat.add_assoc]
      change Causal _ limits middle key (1 + (surfaceSize source + armsSize arms)) _
      apply Causal.parent
      apply causal_follow next
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels child limits middle next) (fun tested after ok => ?_)
        (eval_trace_keys child) (by
          simpa [childKey, advanceKey, surfaceSize] using widthArms_trace_keys selected)
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms) (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_scan_bind _ _ (BudgetScan.rangeMatch_agrees _ _ _)
          intro scanned preserved
          have absent := range_match_at_integer_none (kind := kind) (arms := arms) models rmodels child
          simp only [absent]
          cases choice : tested.matchKind with
            | some chosen =>
              have inside := (expr_normal_next fuel models rmodels child ok).1 _ rfl
              have same : chosen = kind := (matchKind_contains inside choice).symm
              subst chosen
              apply causal_map
              apply armListKind_causal fuel not64 models rmodels child
                (BaseApprox.contains_rangeKind kind integer inside) selected
              have pos := (expr_success fuel abstract source limits middle ok).1
              simp [preserved, pos, next, childKey, advanceKey, surfaceSize]
            | none => exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms)
                (fun _ => silent_bind silent_unsupported (fun _ => silent_pure _))).causal _ _ _ _ _
    | .matchResult _ key source arms type sourceType result names tag payload outcome st armTrace recognized view child selected =>
      simp only [surfaceSize_matchE, Nat.add_assoc]
      change Causal _ limits middle key (1 + (surfaceSize source + armsSize arms)) _
      apply Causal.parent
      apply causal_follow (second := armsSize arms) next
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels child limits middle next) (fun tested after ok => ?_)
        (eval_trace_keys child) (by
          simpa [childKey, advanceKey, surfaceSize] using resultArms_trace_keys selected)
      have inside := (expr_normal_next fuel models rmodels child ok next).1 _ rfl
      simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
      apply causal_scan_bind _ _ (BudgetScan.rangeMatch_agrees _ _ _)
      intro scanned preserved
      cases found : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms with
      | none =>
        simp only [noninteger_matchKind_none inside (range_result_view_noninteger view)]
        exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms)
          (fun _ => silent_bind silent_unsupported (fun _ => silent_pure _))).causal _ _ _ _ _
      | some origin =>
        have actual : rangeMatchAt abstract ⟨source, sourceType, childKey key []⟩ arms = some origin := by
          exact (range_match_at_type abstract ⟨source, .base .unit, childKey key []⟩ sourceType arms).trans found
        have matched := range_match_at_evaluated models rmodels actual child
        have sameNames : origin.names = names := Option.some.inj (matched.symm.trans recognized)
        subst names
        apply causal_map
        apply resultArmList_causal fuel models rmodels child found matched view selected
        have progression := (expr_success fuel abstract source limits middle ok).1
        simp [preserved, progression, next, childKey, advanceKey, surfaceSize]
    | .matchAbrupt _ key source arms _ _ _ st child _
    | .matchOtherNormal _ key source arms _ _ _ _ st child _ _ _
    | .matchOtherFailed _ key source arms _ _ _ st child _ _ =>
      simp only [surfaceSize_matchE, Nat.add_assoc]
      change Causal _ limits middle key (1 + (surfaceSize source + armsSize arms)) _
      apply Causal.parent
      rw [← List.append_nil st]
      apply causal_follow (second := armsSize arms) (rt := []) next
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels child limits middle next) (fun tested after ok => ?_)
        (eval_trace_keys child) (by simp [TraceKeys])
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms) (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_scan_bind _ _ (BudgetScan.rangeMatch_agrees _ _ _)
          intro scanned preserved
          cases known : rangeMatchAt abstract ⟨source, .base .unit, childKey key []⟩ arms with
          | some origin =>
            apply causal_map
            have pos := (expr_success fuel abstract source limits middle ok).1
            simpa only [preserved, pos, next, surfaceSize] using
              resultArms_absent fuel abstract ⟨source, .base .unit, childKey key []⟩ arms limits scanned
          | none =>
            cases choice : tested.matchKind with
              | some kind =>
                apply causal_map
                have pos := (expr_success fuel abstract source limits middle ok).1
                simpa only [preserved, pos, next, surfaceSize] using kindArms_absent fuel kind abstract source (tested.rangeKind kind) arms limits scanned
              | none => exact (silent_bind ((skip_silent fuel).2.2.2.2.2.1 arms)
                  (fun _ => silent_bind silent_unsupported (fun _ => silent_pure _))).causal _ _ _ _ _

/-- 実行した右辺には、左辺の成功から得た絞った環境を渡す。 -/
theorem shortCircuit_run_causal (fuel : Nat)
    {abstract concrete left right key truth lt outcome rt}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ (.normal (.boolean truth)) lt)
    (child : EvalPartial concrete ⟨right, .base .boolean, advanceKey key (surfaceSize left)⟩ outcome rt)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (shortCircuit fuel abstract left right truth) limits ctx key
      (surfaceSize left + surfaceSize right) (lt ++ rt) := by
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [shortCircuit]
    apply shortCircuit_body_causal fuel start (expr_causal fuel models rmodels condition limits ctx start) _
      (eval_trace_keys condition) (eval_trace_keys child)
    intro tested middle ok
    obtain ⟨inner, entry, related, rr⟩ := branch_entry_of_success fuel models rmodels condition ok
    apply causal_branch_selected entry
    intro final same
    apply expr_causal fuel related rr child
    simp only [same, (expr_success fuel abstract left limits ctx ok).1, start]

/-- 短絡・異常終了で具体評価しない右辺には、空 trace の位置の保証だけを使う。 -/
theorem shortCircuit_absent_causal (fuel : Nat)
    {abstract concrete left right key truth outcome lt}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (condition : EvalPartial concrete ⟨left, .base .boolean, key⟩ outcome lt)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (shortCircuit fuel abstract left right truth) limits ctx key
      (surfaceSize left + surfaceSize right) lt := by
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [shortCircuit]
    have h := shortCircuit_body_causal fuel (truth := truth) (right := right) (rt := []) start
      (expr_causal fuel models rmodels condition limits ctx start) (fun tested middle ok => ?_)
      (eval_trace_keys condition) (by simp [TraceKeys])
    · simpa only [List.append_nil] using h
    · have h := branch_expr_absent fuel abstract left tested truth right limits middle
      simpa only [(expr_success fuel abstract left limits ctx ok).1, start] using h

theorem block_causal (fuel : Nat) {abstract concrete key body type outcome trace}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete) (eval : EvalBlock concrete key body type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (block fuel abstract body) limits ctx key (blockSize body) trace := by
  by_cases empty : trace = []
  · subst trace
    simpa only [start] using block_absent fuel abstract body limits ctx
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [block.eq_def]
    apply causal_scope_same
    intro entered same
    apply causal_scan_bind _ () (by intro limits state value final ok; cases value; rfl)
    intro middle next
    have pos := next.trans (same.trans start)
    match eval with
    | .empty .. => exact (silent_pure _).causal _ _ _ _ _
    | .builderBind _ _ _ _ _ _ _ child =>
      apply causal_scan_bind _ _ (BudgetScan.push_agrees _ _)
      intro final same
      exact block_causal fuel (models_extend (slot := .builder _) models (value := none) trivial) (ranges_extend rmodels none) child limits final (same.trans pos)
    | .last _ _ _ _ _ _ child => exact expr_causal fuel models rmodels child limits middle pos
    | .lastBind _ _ _ _ _ _ _ child
    | .lastDiscard _ _ _ _ _ _ child
    | .lastPat _ _ _ _ _ _ _ _ child =>
      exact causal_map (expr_causal fuel models rmodels child limits middle pos) _
    | .bind _ key kind type source rest _ value _ et rt head tail =>
      apply causal_get_bind
      have h := causal_follow (next := fun head => do
          if !head.live then do skipBlock fuel rest; pure head.abrupt
          else do
            let inner ← scan (BudgetScan.rangeBind kind abstract type head ⟨source, type, middle.next⟩)
            pure (baseThen head (← block fuel inner rest))) (second := blockSize rest) pos
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels head limits middle pos) (fun approx after ok => ?_)
        (eval_trace_keys head) (by simpa only [surfaceSize] using block_trace_keys tail)
      · simpa only [preorder_expr_length, blockSize_bind] using h
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.1 rest) (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_scan_bind _ _ (BudgetScan.rangeBind_agrees _ _ _ _ _)
          intro final same
          apply causal_map
          exact block_causal fuel
            (abstract := baseBindSource kind abstract type approx ⟨source, type, middle.next⟩)
            (bind_models kind models (eval_normal_typed head) ((expr_normal_next fuel models rmodels head ok pos).1 _ rfl))
            (by
              have saved := range_save_result_of_eval models rmodels head
              simpa only [baseBindSource, pos] using saved)
            tail limits final (by simp only [same, (expr_success fuel abstract source limits middle ok).1, pos])
    | .discard _ key source rest _ _ value _ et rt head tail
    | .seq _ key source rest _ value _ et rt head tail =>
      have h := causal_follow (next := fun head => do
          if !head.live then do skipBlock fuel rest; pure head.abrupt
          else do pure (baseThen head (← block fuel abstract rest))) (second := blockSize rest) pos
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels head limits middle pos) (fun approx after ok => ?_)
        (eval_trace_keys head) (by simpa only [surfaceSize] using block_trace_keys tail)
      · simpa only [preorder_expr_length, blockSize_discard, blockSize_seq] using h
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.1 rest) (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_map
          exact block_causal fuel models rmodels tail limits after (by
            simp only [(expr_success fuel abstract source limits middle ok).1, pos])
    | .bindPat _ key kind pattern type source rest _ value _ et rt values head bindings tail =>
      have h := causal_follow (next := fun head => do
          if !head.live then do skipBlock fuel rest; pure head.abrupt
          else do
            let inner ← scan (BudgetScan.patternEnv abstract pattern type)
            pure (baseThen head (← block fuel inner rest))) (second := blockSize rest) pos
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels head limits middle pos) (fun approx after ok => ?_)
        (eval_trace_keys head) (by simpa only [surfaceSize] using block_trace_keys tail)
      · simpa only [preorder_expr_length, blockSize_bindPat] using h
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.1 rest) (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_scan_bind _ _ (BudgetScan.patternEnv_agrees _ _ _)
          intro final same
          apply causal_map
          exact block_causal fuel (pattern_models models (eval_normal_typed head) bindings)
            (pattern_ranges (type := type) rmodels bindings) tail limits final (by simp only [same, (expr_success fuel abstract source limits middle ok).1, pos])
    | .bindAbrupt _ key kind type source rest _ _ _ head _
    | .discardAbrupt _ key source rest _ _ _ _ head _
    | .seqAbrupt _ key source rest _ _ _ head _
    | .bindPatAbrupt _ key kind pattern type source rest _ _ _ head _ =>
      try apply causal_get_bind
      simp only [blockSize_bind, blockSize_discard, blockSize_seq, blockSize_bindPat]
      rw [← List.append_nil trace]
      apply causal_follow (second := blockSize rest) pos
        ((analysis_walk fuel).1 abstract source)
        (expr_causal fuel models rmodels head limits middle pos) (fun approx after ok => ?_)
        (eval_trace_keys head) (by simp [TraceKeys])
      · split
        · exact (silent_bind ((skip_silent fuel).2.2.2.2.1 rest) (fun _ => silent_pure _)).causal _ _ _ _ _
        · first
          | apply causal_scan_bind _ _ (BudgetScan.rangeBind_agrees _ _ _ _ _)
            intro final same
            apply causal_map
            simpa only [same, (expr_success fuel abstract source limits middle ok).1, pos, surfaceSize] using
              block_absent fuel _ rest limits final
          | apply causal_scan_bind _ _ (BudgetScan.patternEnv_agrees _ _ _)
            intro final same
            apply causal_map
            simpa only [same, (expr_success fuel abstract source limits middle ok).1, pos, surfaceSize] using
              block_absent fuel _ rest limits final
          | apply causal_map
            simpa only [(expr_success fuel abstract source limits middle ok).1, pos, surfaceSize] using
              block_absent fuel abstract rest limits after

theorem armList_causal (fuel : Nat)
    {abstract concrete source normal key scrutineeKey integer arms type outcome trace st}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, .base .integer, scrutineeKey⟩ (.normal (.integer integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalArms concrete key integer arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (armList fuel abstract source normal arms) limits ctx key (armsSize arms) trace := by
  by_cases empty : trace = []
  · subst trace
    simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
      preorder_expr_length, preorderBlock_length, start] using arms_absent fuel abstract source normal arms limits ctx
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [armList, armListKind.eq_def]
    simp only [BudgetScan.armKind_integer64]
    apply causal_scope_same
    intro entered same
    apply causal_scan_bind _ () (by intro limits state value final ok; cases value; rfl)
    intro middle next
    have pos := next.trans (same.trans start)
    match eval with
    | .nil .. => exact (silent_pure _).causal _ _ _ _ _
    | .skip _ key integer alts guard body rest _ _ trace _ tail =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armList fuel abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := []) (rt := trace) pos
        (kindArmHead_walk fuel .integer64 abstract source normal alts guard body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, List.nil_append, guardPreorder_length,
          preorderBlock_length, guardSize, armsSize_cons]
        congr 1
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, pos] using
          kindArmHead_absent fuel .integer64 abstract source normal alts guard body limits middle
      · simp only [armSources, List.length_append, guardPreorder_length, preorderBlock_length, guardSize]
        apply causal_map
        apply armList_causal fuel models rmodels scrutinee inside tail
        simp only [armSources, List.length_append, guardPreorder_length, preorderBlock_length, (kindArmHead_walk fuel .integer64 abstract source normal alts guard body).success ok |>.1, pos, guardSize]
      · simp [TraceKeys]
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using arms_trace_keys tail
    | .body _ key integer alts body rest _ selected _ trace selection child =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armList fuel abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := trace) (rt := []) pos
        (kindArmHead_walk fuel .integer64 abstract source normal alts none body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.nil_append, preorderBlock_length, guardSize, Option.map_none,
          Option.getD_none, Nat.zero_add, armsSize_cons, List.append_nil]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
        have rr := match_selection_ranges models rmodels scrutinee inside selection entry
        apply causal_arm_selected entry
        intro final same
        simpa [guardPreorder_length, armSources, preorderBlock_length, preorder_expr_length, guardSize,
          Option.map_none, Option.getD_none, Nat.zero_add] using
          block_causal fuel related rr child limits final (same.trans pos)
      · apply causal_map
        have absent := arms_absent fuel abstract source normal rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (kindArmHead_walk fuel .integer64 abstract source normal alts none body).success ok |>.1, pos] using absent
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_none,
          Option.getD_none, Nat.zero_add] using block_trace_keys child
      · simp [TraceKeys]
    | .guardTrue _ key integer alts condition body rest _ selected _ gt bt selection conditionEval child =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armList fuel abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := (gt ++ bt)) (rt := []) pos
        (kindArmHead_walk fuel .integer64 abstract source normal alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons, List.append_nil]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
        have rr := match_selection_ranges models rmodels scrutinee inside selection entry
        apply causal_arm_selected entry
        intro final same
        have h := guard_causal fuel (body := body) (bt := bt) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · obtain ⟨refined, branchEntry, modeled, refinedRanges⟩ := branch_entry_of_success fuel related rr conditionEval ok
          apply causal_branch_selected branchEntry
          intro last next
          exact block_causal fuel modeled refinedRanges child limits last (by
            simp only [next, (expr_success fuel inner condition limits final ok).1, same, pos])
        · exact block_trace_keys child
      · apply causal_map
        have absent := arms_absent fuel abstract source normal rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (kindArmHead_walk fuel .integer64 abstract source normal alts (some condition) body).success ok |>.1, pos] using absent
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using
          trace_follow (eval_trace_keys conditionEval) (block_trace_keys child)
      · simp [TraceKeys]
    | .guardFalse _ key integer alts condition body rest _ selected _ gt rt selection conditionEval tail =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armList fuel abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := gt) (rt := rt) pos
        (kindArmHead_walk fuel .integer64 abstract source normal alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
        have rr := match_selection_ranges models rmodels scrutinee inside selection entry
        apply causal_arm_selected entry
        intro final same
        have h := guard_causal fuel (body := body) (bt := []) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · have absent := branch_block_absent fuel inner condition tested true body limits after
          simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length,
            (expr_success fuel inner condition limits final ok).1, same, pos] using absent
        · simp [TraceKeys]
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        apply causal_map
        apply armList_causal fuel models rmodels scrutinee inside tail
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, (kindArmHead_walk fuel .integer64 abstract source normal alts (some condition) body).success ok |>.1, pos]
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        refine ⟨(eval_trace_keys conditionEval).1, ?_⟩
        intro event found
        obtain ⟨defn, lo, hi⟩ := (eval_trace_keys conditionEval).2 event found
        dsimp only [EvalInput.key, EvalInput.source] at defn lo hi
        exact ⟨defn, lo, by omega⟩
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using arms_trace_keys tail
    | .guardAbrupt _ key integer alts condition body rest _ selected _ gt selection conditionEval _ =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armList fuel abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := gt) (rt := []) pos
        (kindArmHead_walk fuel .integer64 abstract source normal alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons, List.append_nil]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_selection_models models scrutinee inside selection
        have rr := match_selection_ranges models rmodels scrutinee inside selection entry
        apply causal_arm_selected entry
        intro final same
        have h := guard_causal fuel (body := body) (bt := []) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · have absent := branch_block_absent fuel inner condition tested true body limits after
          simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length,
            (expr_success fuel inner condition limits final ok).1, same, pos] using absent
        · simp [TraceKeys]
      · apply causal_map
        have absent := arms_absent fuel abstract source normal rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (kindArmHead_walk fuel .integer64 abstract source normal alts (some condition) body).success ok |>.1, pos] using absent
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        refine ⟨(eval_trace_keys conditionEval).1, ?_⟩
        intro event found
        obtain ⟨defn, lo, hi⟩ := (eval_trace_keys conditionEval).2 event found
        dsimp only [EvalInput.key, EvalInput.source] at defn lo hi
        exact ⟨defn, lo, by omega⟩
      · simp [TraceKeys]

/-- 六幅の腕・guard・本体も、同じ番号と実行 trace で原因を覆う。 -/
theorem armListKind_causal (fuel : Nat)
    {abstract concrete source key scrutineeKey arms type outcome trace st} {kind : IntKind}
    {normal : Interval kind} {integer : IntegerValue kind}
    (not64 : kind ≠ .integer64)
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete ⟨source, kind.type, scrutineeKey⟩ (.normal (.ofInteger kind integer)) st)
    (inside : Mem integer.toInt normal)
    (eval : EvalWidthArms concrete key kind integer arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (armListKind fuel kind abstract source normal arms) limits ctx key (armsSize arms) trace := by
  by_cases empty : trace = []
  · subst trace
    simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
      preorder_expr_length, preorderBlock_length, start] using kindArms_absent fuel kind abstract source normal arms limits ctx
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [armListKind.eq_def]
    apply causal_scope_same
    intro entered same
    apply causal_scan_bind _ () (by intro limits state value final ok; cases value; rfl)
    intro middle next
    have pos := next.trans (same.trans start)
    match eval with
    | .nil .. => exact (silent_pure _).causal _ _ _ _ _
    | .skip _ key _ integer alts guard body rest _ _ trace _ tail =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armListKind fuel kind abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := []) (rt := trace) pos
        (kindArmHead_walk fuel kind abstract source normal alts guard body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, List.nil_append, guardPreorder_length,
          preorderBlock_length, guardSize, armsSize_cons]
        congr 1
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, pos] using
          kindArmHead_absent fuel kind abstract source normal alts guard body limits middle
      · simp only [armSources, List.length_append, guardPreorder_length, preorderBlock_length, guardSize]
        apply causal_map
        apply armListKind_causal fuel not64 models rmodels scrutinee inside tail
        simp only [armSources, List.length_append, guardPreorder_length, preorderBlock_length, (kindArmHead_walk fuel kind abstract source normal alts guard body).success ok |>.1, pos, guardSize]
      · simp [TraceKeys]
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using widthArms_trace_keys tail
    | .body _ key _ integer alts body rest _ selected _ trace selection child =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armListKind fuel kind abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := trace) (rt := []) pos
        (kindArmHead_walk fuel kind abstract source normal alts none body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.nil_append, preorderBlock_length, guardSize, Option.map_none,
          Option.getD_none, Nat.zero_add, armsSize_cons, List.append_nil]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
        have rr := match_width_selection_ranges models rmodels scrutinee inside selection not64 entry
        apply causal_kindArm_selected entry
        intro final same
        simpa [guardPreorder_length, armSources, preorderBlock_length, preorder_expr_length, guardSize,
          Option.map_none, Option.getD_none, Nat.zero_add] using
          block_causal fuel related rr child limits final (same.trans pos)
      · apply causal_map
        have absent := kindArms_absent fuel kind abstract source normal rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (kindArmHead_walk fuel kind abstract source normal alts none body).success ok |>.1, pos] using absent
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_none,
          Option.getD_none, Nat.zero_add] using block_trace_keys child
      · simp [TraceKeys]
    | .guardTrue _ key _ integer alts condition body rest _ selected _ gt bt selection conditionEval child =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armListKind fuel kind abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := (gt ++ bt)) (rt := []) pos
        (kindArmHead_walk fuel kind abstract source normal alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons, List.append_nil]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
        have rr := match_width_selection_ranges models rmodels scrutinee inside selection not64 entry
        apply causal_kindArm_selected entry
        intro final same
        have h := guard_causal fuel (body := body) (bt := bt) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · obtain ⟨refined, branchEntry, modeled, refinedRanges⟩ := branch_entry_of_success fuel related rr conditionEval ok
          apply causal_branch_selected branchEntry
          intro last next
          exact block_causal fuel modeled refinedRanges child limits last (by
            simp only [next, (expr_success fuel inner condition limits final ok).1, same, pos])
        · exact block_trace_keys child
      · apply causal_map
        have absent := kindArms_absent fuel kind abstract source normal rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (kindArmHead_walk fuel kind abstract source normal alts (some condition) body).success ok |>.1, pos] using absent
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using
          trace_follow (eval_trace_keys conditionEval) (block_trace_keys child)
      · simp [TraceKeys]
    | .guardFalse _ key _ integer alts condition body rest _ selected _ gt rt selection conditionEval tail =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armListKind fuel kind abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := gt) (rt := rt) pos
        (kindArmHead_walk fuel kind abstract source normal alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
        have rr := match_width_selection_ranges models rmodels scrutinee inside selection not64 entry
        apply causal_kindArm_selected entry
        intro final same
        have h := guard_causal fuel (body := body) (bt := []) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · have absent := branch_block_absent fuel inner condition tested true body limits after
          simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length,
            (expr_success fuel inner condition limits final ok).1, same, pos] using absent
        · simp [TraceKeys]
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        apply causal_map
        apply armListKind_causal fuel not64 models rmodels scrutinee inside tail
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, (kindArmHead_walk fuel kind abstract source normal alts (some condition) body).success ok |>.1, pos]
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        refine ⟨(eval_trace_keys conditionEval).1, ?_⟩
        intro event found
        obtain ⟨defn, lo, hi⟩ := (eval_trace_keys conditionEval).2 event found
        dsimp only [EvalInput.key, EvalInput.source] at defn lo hi
        exact ⟨defn, lo, by omega⟩
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using widthArms_trace_keys tail
    | .guardAbrupt _ key _ integer alts condition body rest _ selected _ gt selection conditionEval _ =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← armListKind fuel kind abstract source normal rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := gt) (rt := []) pos
        (kindArmHead_walk fuel kind abstract source normal alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons, List.append_nil]
        congr 1
      · obtain ⟨inner, entry, related⟩ := match_width_selection_models models scrutinee inside selection not64
        have rr := match_width_selection_ranges models rmodels scrutinee inside selection not64 entry
        apply causal_kindArm_selected entry
        intro final same
        have h := guard_causal fuel (body := body) (bt := []) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · have absent := branch_block_absent fuel inner condition tested true body limits after
          simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length,
            (expr_success fuel inner condition limits final ok).1, same, pos] using absent
        · simp [TraceKeys]
      · apply causal_map
        have absent := kindArms_absent fuel kind abstract source normal rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (kindArmHead_walk fuel kind abstract source normal alts (some condition) body).success ok |>.1, pos] using absent
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        refine ⟨(eval_trace_keys conditionEval).1, ?_⟩
        intro event found
        obtain ⟨defn, lo, hi⟩ := (eval_trace_keys conditionEval).2 event found
        dsimp only [EvalInput.key, EvalInput.source] at defn lo hi
        exact ⟨defn, lo, by omega⟩
      · simp [TraceKeys]

/-- 認定済みの引数だけを同じ環境で解析し、正常に評価した接頭辞の原因を保つ。 -/
theorem typed_arguments_causal (fuel : Nat) {abstract concrete key sources types outcome trace}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (eval : EvalTypedArguments concrete key (exprsChildren sources) types outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (arguments fuel abstract sources) limits ctx key
      ((exprsChildren sources).map surfaceSize).sum trace := by
  by_cases empty : trace = []
  · subst trace
    simpa only [start] using arguments_absent fuel abstract sources limits ctx
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [arguments.eq_def]
    apply causal_scope_same
    intro entered same
    apply causal_scan_bind _ () (by intro limits state value final ok; cases value; rfl)
    intro middle next
    have pos := next.trans (same.trans start)
    cases sources with
    | nil => cases eval; exact False.elim (empty rfl)
    | cons source rest =>
      simp only [exprsChildren, List.map_cons, List.sum_cons] at eval ⊢
      match eval with
      | .cons _ _ _ _ _ _ _ _ _ _ head tail
      | .tailAbrupt _ _ _ _ _ _ _ _ _ _ head tail =>
        apply causal_follow pos ((analysis_walk fuel).1 abstract source)
          (expr_causal fuel models rmodels head limits middle pos) _
          (eval_trace_keys head) (typed_arguments_trace_keys tail)
        intro tested after ok
        have inside := (expr_normal_next fuel models rmodels head ok pos).1 _ rfl
        simp only [contains_live inside, Bool.not_true, Bool.false_eq_true, ↓reduceIte]
        apply causal_map
        apply typed_arguments_causal fuel models rmodels tail
        simpa only [pos] using (expr_success fuel abstract source limits middle ok).1
      | .headAbrupt _ _ _ _ _ _ _ _ head abrupt =>
        rw [← List.append_nil trace]
        apply causal_follow pos ((analysis_walk fuel).1 abstract source)
          (expr_causal fuel models rmodels head limits middle pos) _
          (eval_trace_keys head) (by simp [TraceKeys])
        intro tested after ok
        split
        · exact (silent_bind ((skip_silent fuel).2.2.1 rest)
            (fun _ => silent_pure _)).causal _ _ _ _ _
        · apply causal_map
          simpa only [(expr_success fuel abstract source limits middle ok).1, pos, surfaceSize] using
            arguments_absent fuel abstract rest limits after

theorem arguments_causal (fuel : Nat) {abstract concrete key sources type outcome trace}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (eval : EvalArguments concrete key (exprsChildren sources) type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (arguments fuel abstract sources) limits ctx key
      ((exprsChildren sources).map surfaceSize).sum trace :=
  typed_arguments_causal fuel models rmodels (arguments_typed eval) limits ctx start

/-- 同じ検査の Result の腕で保存した候補を、実際の選択と guard の trace に対応させる。 -/
theorem resultArmList_causal (fuel : Nat)
    {abstract concrete input sourceType fullArms key arms type outcome trace origin result tag payload st}
    (models : Models abstract concrete) (rmodels : abstract.ranges.Models concrete)
    (scrutinee : EvalPartial concrete { input with type := sourceType } (.normal result) st)
    (recognized : rangeMatchAt abstract input fullArms = some origin)
    (matched : rangeResultMatch concrete result fullArms = some origin.names)
    (view : origin.names.ResultView result tag payload)
    (eval : EvalResultArms concrete key origin.names result tag payload arms type outcome trace)
    (limits : Limits) (ctx : Context) (start : ctx.next = key) :
    Causal (resultArmList fuel abstract input arms) limits ctx key (armsSize arms) trace := by
  by_cases empty : trace = []
  · subst trace
    simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
      preorder_expr_length, preorderBlock_length, start] using resultArms_absent fuel abstract input arms limits ctx
  cases fuel with
  | zero => exact (silent_throw _).causal _ _ _ _ _
  | succ fuel =>
    rw [resultArmList.eq_def]
    apply causal_scope_same
    intro entered same
    apply causal_scan_bind _ () (by intro limits state value final ok; cases value; rfl)
    intro middle next
    have pos := next.trans (same.trans start)
    match eval with
    | .nil .. => exact (silent_pure _).causal _ _ _ _ _
    | .skip _ key _ _ _ _ alts guard body rest _ _ trace _ tail =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← resultArmList fuel abstract input rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := []) (rt := trace) pos
        (resultArmHead_walk fuel abstract input alts guard body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, List.nil_append, guardPreorder_length,
          preorderBlock_length, guardSize, armsSize_cons]
        congr 1
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, pos] using
          resultArmHead_absent fuel abstract input alts guard body limits middle
      · simp only [armSources, List.length_append, guardPreorder_length, preorderBlock_length, guardSize]
        apply causal_map
        apply resultArmList_causal fuel models rmodels scrutinee
          recognized matched view tail
        simp only [armSources, List.length_append, guardPreorder_length, preorderBlock_length, (resultArmHead_walk fuel abstract input alts guard body).success ok |>.1, pos, guardSize]
      · simp [TraceKeys]
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using resultArms_trace_keys tail
    | .body _ key _ _ _ _ alts body rest _ selected _ trace selection child =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← resultArmList fuel abstract input rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := trace) (rt := []) pos
        (resultArmHead_walk fuel abstract input alts none body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.nil_append, preorderBlock_length, guardSize, Option.map_none,
          Option.getD_none, Nat.zero_add, armsSize_cons, List.append_nil]
      · let inner := baseResultArmEnv abstract input alts
        have related := baseResultArmEnv_models (input := input) models selection
        have actual : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
          exact (range_match_at_type abstract input sourceType fullArms).trans recognized
        have rr := baseResultArmEnv_ranges models rmodels actual scrutinee matched view selection
        rw [baseResultArmEnv_type] at rr
        apply causal_resultArm_selected
        intro final same
        simpa [guardPreorder_length, armSources, preorderBlock_length, preorder_expr_length, guardSize,
          Option.map_none, Option.getD_none, Nat.zero_add] using
          block_causal fuel related rr child limits final (same.trans pos)
      · apply causal_map
        have absent := resultArms_absent fuel abstract input rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (resultArmHead_walk fuel abstract input alts none body).success ok |>.1, pos] using absent
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_none,
          Option.getD_none, Nat.zero_add] using block_trace_keys child
      · simp [TraceKeys]
    | .guardTrue _ key _ _ _ _ alts condition body rest _ selected _ gt bt selection conditionEval child =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← resultArmList fuel abstract input rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := (gt ++ bt)) (rt := []) pos
        (resultArmHead_walk fuel abstract input alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons, List.append_nil]
      · let inner := baseResultArmEnv abstract input alts
        have related := baseResultArmEnv_models (input := input) models selection
        have actual : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
          exact (range_match_at_type abstract input sourceType fullArms).trans recognized
        have rr := baseResultArmEnv_ranges models rmodels actual scrutinee matched view selection
        rw [baseResultArmEnv_type] at rr
        apply causal_resultArm_selected
        intro final same
        have h := guard_causal fuel (body := body) (bt := bt) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · obtain ⟨refined, branchEntry, modeled, refinedRanges⟩ := branch_entry_of_success fuel related rr conditionEval ok
          apply causal_branch_selected branchEntry
          intro last next
          exact block_causal fuel modeled refinedRanges child limits last (by
            simp only [next, (expr_success fuel inner condition limits final ok).1, same, pos])
        · exact block_trace_keys child
      · apply causal_map
        have absent := resultArms_absent fuel abstract input rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (resultArmHead_walk fuel abstract input alts (some condition) body).success ok |>.1, pos] using absent
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using
          trace_follow (eval_trace_keys conditionEval) (block_trace_keys child)
      · simp [TraceKeys]
    | .guardFalse _ key _ _ _ _ alts condition body rest _ selected _ gt rt selection conditionEval tail =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← resultArmList fuel abstract input rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := gt) (rt := rt) pos
        (resultArmHead_walk fuel abstract input alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons]
      · let inner := baseResultArmEnv abstract input alts
        have related := baseResultArmEnv_models (input := input) models selection
        have actual : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
          exact (range_match_at_type abstract input sourceType fullArms).trans recognized
        have rr := baseResultArmEnv_ranges models rmodels actual scrutinee matched view selection
        rw [baseResultArmEnv_type] at rr
        apply causal_resultArm_selected
        intro final same
        have h := guard_causal fuel (body := body) (bt := []) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · have absent := branch_block_absent fuel inner condition tested true body limits after
          simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length,
            (expr_success fuel inner condition limits final ok).1, same, pos] using absent
        · simp [TraceKeys]
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        apply causal_map
        apply resultArmList_causal fuel models rmodels scrutinee
          recognized matched view tail
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, (resultArmHead_walk fuel abstract input alts (some condition) body).success ok |>.1, pos]
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        refine ⟨(eval_trace_keys conditionEval).1, ?_⟩
        intro event found
        obtain ⟨defn, lo, hi⟩ := (eval_trace_keys conditionEval).2 event found
        dsimp only [EvalInput.key, EvalInput.source] at defn lo hi
        exact ⟨defn, lo, by omega⟩
      · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
          Option.getD_some] using resultArms_trace_keys tail
    | .guardAbrupt _ key _ _ _ _ alts condition body rest _ selected _ gt selection conditionEval _ =>
      have h := causal_follow (limits := limits) (next := fun first => do
          let tail ← resultArmList fuel abstract input rest
          pure (baseJoin first tail)) (second := armsSize rest) (lt := gt) (rt := []) pos
        (resultArmHead_walk fuel abstract input alts (some condition) body) ?_ (fun first after ok => ?_) ?_ ?_
      · refine Eq.mpr ?_ h
        simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length, guardSize,
          Option.map_some, Option.getD_some, armsSize_cons, List.append_nil]
      · let inner := baseResultArmEnv abstract input alts
        have related := baseResultArmEnv_models (input := input) models selection
        have actual : rangeMatchAt abstract { input with type := sourceType } fullArms = some origin := by
          exact (range_match_at_type abstract input sourceType fullArms).trans recognized
        have rr := baseResultArmEnv_ranges models rmodels actual scrutinee matched view selection
        rw [baseResultArmEnv_type] at rr
        apply causal_resultArm_selected
        intro final same
        have h := guard_causal fuel (body := body) (bt := []) (same.trans pos)
          (expr_causal fuel related rr conditionEval limits final (same.trans pos))
          (fun tested after ok => ?_) (eval_trace_keys conditionEval) ?_
        · simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length, armsSize_cons, guardSize, Option.map_some,
            Option.getD_some, List.append_nil] using h
        · have absent := branch_block_absent fuel inner condition tested true body limits after
          simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
            preorder_expr_length, preorderBlock_length,
            (expr_success fuel inner condition limits final ok).1, same, pos] using absent
        · simp [TraceKeys]
      · apply causal_map
        have absent := resultArms_absent fuel abstract input rest limits after
        simpa only [armSources, List.length_append, List.length_nil, List.nil_append, guardPreorder_length,
          preorder_expr_length, preorderBlock_length,
          (resultArmHead_walk fuel abstract input alts (some condition) body).success ok |>.1, pos] using absent
      · simp only [armSources, List.length_append, preorder_expr_length, preorderBlock_length]
        refine ⟨(eval_trace_keys conditionEval).1, ?_⟩
        intro event found
        obtain ⟨defn, lo, hi⟩ := (eval_trace_keys conditionEval).2 event found
        dsimp only [EvalInput.key, EvalInput.source] at defn lo hi
        exact ⟨defn, lo, by omega⟩
      · simp [TraceKeys]


end

/-- 空の保存列から始める同じ入口では、停止後に残った警告も原因どおりに拒否される。 -/
theorem analyzeExpr_warning_sound (limits : Limits) (state : Budget.State) (fuel : Nat)
    {abstract concrete input outcome trace}
    (models : Models abstract concrete) (eval : EvalPartial concrete input outcome trace)
    (warning : IntervalWarning)
    (member : warning ∈ (analyzeExpr limits state fuel abstract input.key input.source).approx.warnings)
    (event : EvalEvent) (reached : Reached trace warning event) :
    event.result = .rejected warning.cause.toFailure := by
  have h := expr_causal fuel (models_resetRanges models) (ranges_reset_models _ _) eval
    limits { budget := state, next := input.key } rfl
  have cause := (h.member member).resolve_left (by simp)
  exact cause.2 event reached

/-- 完走・予算内・事前の警告健全性を仮定せず、既存の警告の中心命題を満たす。 -/
theorem analyze_warning_sound : WarningSoundness Models analyze := by
  intro abstract concrete input parameters outcome trace models eval warning member event reached
  exact analyzeExpr_warning_sound parameters.limits parameters.state parameters.fuel
    models eval warning member event reached

end Benitoite.Interval.BudgetAnalysis
