import Benitoite.Release.Refinement.Surface.ScopeLower

/-!
# Scope の局所解析の束縛番号の新規性

設計書 01-12「Scope の局所解析の表層からの対応」に対応する。局所解析が文の始まりに記録した状態は、束縛番号の新規性の
不変条件（`WellNumbered`。全ての位置の番号は次の番号より小さく、互いに異なる）を満たす（`analyzeBody_numbered`）。
成功値番号（`okArm` が書く番号）は新しい位置にだけ結び付く（`WellNumbered.idAt_inj`・`WellNumbered.fresh_new`）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeLower

open Benitoite.Scope.Inference
open Benitoite.Release.Refinement.Surface.ScopeState

/-! ## 束縛番号の新規性の不変条件 -/

/-- 束縛番号の新規性の不変条件。現在の全ての位置の番号は次の番号より小さく、互いに異なる
（`BindingScope.fresh_valid`・`fresh_distinct`）。 -/
def WellNumbered (s : Interval.BindingScope) : Prop :=
  (∀ id ∈ s.positions, id < s.nextId) ∧ s.positions.Nodup

theorem WellNumbered.fresh {s : Interval.BindingScope} (h : WellNumbered s) : WellNumbered s.fresh :=
  ⟨Interval.BindingScope.fresh_valid s h.1,
   List.nodup_cons.mpr ⟨Interval.BindingScope.fresh_distinct s h.1, h.2⟩⟩

theorem WellNumbered.freshN {s : Interval.BindingScope} (h : WellNumbered s) : ∀ n, WellNumbered (freshN n s)
  | 0 => h
  | n + 1 => (WellNumbered.freshN h n).fresh

/-- 同じ番号を持つ位置は一つだけである。成功値番号は一つの位置にだけ結び付く。 -/
theorem WellNumbered.idAt_inj {s : Interval.BindingScope} (h : WellNumbered s) {i j id : Nat}
    (hi : s.idAt i = some id) (hj : s.idAt j = some id) : i = j := by
  unfold Interval.BindingScope.idAt at hi hj
  obtain ⟨hlt, _⟩ := List.getElem?_eq_some_iff.mp hi
  exact h.2.eq_of_getElem?_eq hlt (hi.trans hj.symm)

/-- 新しい位置の番号は、それより奥の位置の番号と異なる。`okArm` が書く成功値番号は新しい位置にだけ有効である。 -/
theorem WellNumbered.fresh_new {s : Interval.BindingScope} (h : WellNumbered s) (j : Nat) :
    s.fresh.idAt (j + 1) ≠ some s.nextId := by
  rw [(Interval.BindingScope.fresh_idAt s).2 j]
  intro hj
  exact Interval.BindingScope.fresh_distinct s h.1 (List.mem_of_getElem? hj)

/-- 局所状態の束縛番号が新規性の不変条件を満たす。 -/
def Numbered (st : ScopeState) : Prop := WellNumbered st.scope

theorem numbered_extend {st : ScopeState} (h : Numbered st) (f : Option ScopeFact) : Numbered (st.extend f) :=
  WellNumbered.fresh h

theorem numbered_forgetAll {st : ScopeState} (h : Numbered st) : Numbered st.forgetAll := h

theorem numbered_absStep (T : ScopeTable Refinement.Val) {st : ScopeState} (h : Numbered st) (s : ScopeState.Step) :
    Numbered (absStep T st s) := by
  cases s <;> first | exact numbered_extend h _ | exact numbered_forgetAll h

theorem numbered_blindStep {st : ScopeState} (h : Numbered st) (s : ScopeState.Step) : Numbered (blindStep st s) := by
  cases s <;> first | exact numbered_extend h _ | exact numbered_forgetAll h

theorem numbered_step (T : ScopeTable Refinement.Val) (L : Limits) {r : Run} (h : Numbered r.state) (s : ScopeState.Step) :
    Numbered (r.step T L s).state := by
  cases r with
  | running st b =>
    simp only [Run.step]
    split
    · exact numbered_absStep T h s
    · exact numbered_blindStep (numbered_forgetAll h) s
  | stopped f st b => exact numbered_blindStep h s

theorem numbered_steps (T : ScopeTable Refinement.Val) (L : Limits) :
    ∀ (ss : List ScopeState.Step) {r : Run}, Numbered r.state → Numbered (r.steps T L ss).state
  | [], _, h => h
  | s :: ss, _, h => numbered_steps T L ss (numbered_step T L h s)

theorem numbered_enter {scope : Interval.BindingScope} (h : WellNumbered scope) (r : Run) :
    Numbered (r.enter scope).state := by
  cases r with
  | running => exact h
  | stopped f st b =>
    simp only [Run.enter]
    split <;> exact h

theorem numbered_leave {outer : Run} (h : Numbered outer.state) (inner : Run) :
    Numbered (outer.leave inner).state := by
  cases inner with
  | stopped f _ ib =>
    simp only [Run.leave]
    split
    · exact numbered_forgetAll h
    · cases outer <;> exact h
  | running _ ib => cases outer <;> exact h

theorem numbered_rejoin {outer : Run} (h : Numbered outer.state) (inner : Run) :
    Numbered (rejoin outer inner).state := by
  unfold rejoin
  cases inner with
  | running _ b => cases outer <;> exact h
  | stopped f _ b => exact numbered_forgetAll h

section Numbering

variable {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits}

/-- 記録が全て新規性の不変条件を満たすこと。 -/
def AllNumbered (rs : Records) : Prop := ∀ p ∈ rs, Numbered p.2

theorem allNumbered_nil : AllNumbered [] := fun _ h => by cases h

theorem allNumbered_append {a b : Records} (ha : AllNumbered a) (hb : AllNumbered b) : AllNumbered (a ++ b) := by
  intro p hp
  rcases List.mem_append.mp hp with h | h
  · exact ha p h
  · exact hb p h

theorem allNumbered_cons {p : Key × ScopeState} {a : Records} (hp : Numbered p.2) (ha : AllNumbered a) :
    AllNumbered (p :: a) := by
  intro q hq
  rcases List.mem_cons.mp hq with h | h
  · exact h ▸ hp
  · exact ha q h

mutual
  /-- 式の解析は新規性の不変条件を保ち、記録も満たす。 -/
  theorem analyzeExpr_numbered (key : Key) (r : Run) (h : Numbered r.state) (e : Expr) :
      Numbered (analyzeExpr ok T L key r e).1.state ∧ AllNumbered (analyzeExpr ok T L key r e).2 := by
    match e with
    | .paren e | .returnE _ e =>
      have h1 := analyzeExpr_numbered (advance key 1) r h e
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, h1.2⟩
    | .call callee _ _ args =>
      have h1 := analyzeExpr_numbered (advance key 1) r h callee
      have h2 := analyzeExprs_numbered (argsKey key callee) (rejoin r (analyzeExpr ok T L (advance key 1) r callee).1)
        (numbered_rejoin h _) args
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .block body =>
      have h1 := analyzeBlock_numbered (advance key 1) r h body
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, h1.2⟩
    | .ite c yes no =>
      have h1 := analyzeExpr_numbered (advance key 1) r h c
      have h2 := analyzeBlock_numbered (advance key (1 + Identity.surfaceSize c))
        (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) (numbered_rejoin h _) yes
      have h3 := analyzeBlock_numbered (advance key (1 + Identity.surfaceSize c + blockSize yes))
        (rejoin r (analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (numbered_rejoin h _) no
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 (allNumbered_append h2.2 h3.2)⟩
    | .elseIf c yes no =>
      have h1 := analyzeExpr_numbered (advance key 1) r h c
      have h2 := analyzeBlock_numbered (advance key (1 + Identity.surfaceSize c))
        (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) (numbered_rejoin h _) yes
      have h3 := analyzeExpr_numbered (advance key (1 + Identity.surfaceSize c + blockSize yes))
        (rejoin r (analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (numbered_rejoin h _) no
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 (allNumbered_append h2.2 h3.2)⟩
    | .ifOnly c yes =>
      have h1 := analyzeExpr_numbered (advance key 1) r h c
      have h2 := analyzeBlock_numbered (advance key (1 + Identity.surfaceSize c))
        (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) (numbered_rejoin h _) yes
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .matchE _ sc arms =>
      have h1 := analyzeExpr_numbered (advance key 1) r h sc
      have h2 := analyzeArms_numbered (scrutIndex sc) (advance key (1 + Identity.surfaceSize sc))
        ((rejoin r (analyzeExpr ok T L (advance key 1) r sc).1).step T L .unknown)
        (numbered_step T L (numbered_rejoin h _) .unknown) arms
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .lam _ params _ _ body =>
      have h1 := analyzeBlock_numbered (advance key 1) (r.enter (freshN params.length r.state.scope))
        (numbered_enter (WellNumbered.freshN h params.length) r) body
      simp only [analyzeExpr]
      exact ⟨numbered_leave h _, h1.2⟩
    | .lazyE body =>
      have h1 := analyzeBlock_numbered (advance key 1) (r.enter r.state.scope) (numbered_enter h r) body
      simp only [analyzeExpr]
      exact ⟨numbered_leave h _, h1.2⟩
    | .handleE body clauses =>
      have h1 := analyzeBlock_numbered (advance key 1) (r.enter r.state.scope) (numbered_enter h r) body
      have h2 := analyzeClauses_numbered (advance key (1 + blockSize body))
        (r.leave (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1) (numbered_leave h _) clauses
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .handleFail _ _ body clause =>
      have h1 := analyzeBlock_numbered (advance key 1) (r.enter r.state.scope) (numbered_enter h r) body
      have hl := numbered_leave h (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1
      have h2 := analyzeBlock_numbered (advance key (1 + blockSize body))
        ((r.leave (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1).enter
          (freshN 2 (r.leave (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1).state.scope))
        (numbered_enter (WellNumbered.freshN hl 2) _) clause
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .withE _ e body =>
      have h1 := analyzeExpr_numbered (advance key 1) r h e
      have h2 := analyzeBlock_numbered (advance key (1 + Identity.surfaceSize e))
        ((rejoin r (analyzeExpr ok T L (advance key 1) r e).1).step T L .unknown)
        (numbered_step T L (numbered_rejoin h _) .unknown) body
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .local .. | .builderOp .. | .constE .. | .funName .. | .funDicts .. | .methName .. | .primName .. | .opName .. | .opDicts .. | .raise .. | .nullCon .. | .conValue .. | .literal .. | .negInt .. | .negFloat .. | .negDecimal .. | .negInteger8 .. | .negInteger16 .. | .negInteger32 .. | .negFloat32 .. | .unit .. | .conCall .. | .record .. | .recordUpdate .. | .pipe .. | .partialCall .. | .partialCon .. | .binary .. | .neg .. | .not .. | .and .. | .or .. | .list .. | .listSpread .. | .interpolation .. | .tryResult .. | .tryOption .. | .tryResultDie .. | .tryOptionDie .. | .resume .. | .externalName .. =>
      simp only [analyzeExpr]
      exact ⟨h, allNumbered_nil⟩

  theorem analyzeExprs_numbered (key : Key) (r : Run) (h : Numbered r.state) (es : Exprs) :
      Numbered (analyzeExprs ok T L key r es).1.state ∧ AllNumbered (analyzeExprs ok T L key r es).2 := by
    match es with
    | .nil =>
      simp only [analyzeExprs]
      exact ⟨h, allNumbered_nil⟩
    | .cons e es =>
      have h1 := analyzeExpr_numbered key r h e
      have h2 := analyzeExprs_numbered (advance key (Identity.surfaceSize e))
        (rejoin r (analyzeExpr ok T L key r e).1) (numbered_rejoin h _) es
      simp only [analyzeExprs]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩

  theorem analyzeBlock_numbered (key : Key) (r : Run) (h : Numbered r.state) (b : Block) :
      Numbered (analyzeBlock ok T L key r b).1.state ∧ AllNumbered (analyzeBlock ok T L key r b).2 := by
    match b with
    | .empty =>
      simp only [analyzeBlock]
      exact ⟨h, allNumbered_nil⟩
    | .builderBind _ rest =>
      have h1 := analyzeBlock_numbered key (r.step T L .unknown) (numbered_step T L h .unknown) rest
      simp only [analyzeBlock]
      exact h1
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e =>
      have h1 := analyzeExpr_numbered key r h e
      simp only [analyzeBlock]
      exact ⟨h1.1, allNumbered_cons h h1.2⟩
    | .bind _ _ e rest =>
      have h1 := analyzeExpr_numbered key r h e
      have h2 := analyzeBlock_numbered (advance key (Identity.surfaceSize e))
        ((analyzeExpr ok T L key r e).1.step T L (rhsStep key e)) (numbered_step T L h1.1 (rhsStep key e)) rest
      simp only [analyzeBlock]
      exact ⟨h2.1, allNumbered_cons h (allNumbered_append h1.2 h2.2)⟩
    | .discard e rest | .seq e rest =>
      have h1 := analyzeExpr_numbered key r h e
      have h2 := analyzeBlock_numbered (advance key (Identity.surfaceSize e)) (analyzeExpr ok T L key r e).1 h1.1 rest
      simp only [analyzeBlock]
      exact ⟨h2.1, allNumbered_cons h (allNumbered_append h1.2 h2.2)⟩
    | .bindPat _ pat _ e rest =>
      have h1 := analyzeExpr_numbered key r h e
      have h2 := analyzeBlock_numbered (advance key (Identity.surfaceSize e))
        ((analyzeExpr ok T L key r e).1.steps T L (List.replicate pat.binders .unknown))
        (numbered_steps T L (List.replicate pat.binders .unknown) h1.1) rest
      simp only [analyzeBlock]
      exact ⟨h2.1, allNumbered_cons h (allNumbered_append h1.2 h2.2)⟩

  theorem analyzeArms_numbered (scrut : Option Nat) (key : Key) (r : Run) (h : Numbered r.state) (arms : Arms) :
      Numbered (analyzeArms ok T L scrut key r arms).1.state ∧ AllNumbered (analyzeArms ok T L scrut key r arms).2 := by
    match arms with
    | .nil =>
      simp only [analyzeArms]
      exact ⟨h, allNumbered_nil⟩
    | .cons alts guard body rest =>
      have ha := numbered_steps T L (armEntry ok scrut alts) h
      cases guard with
      | none =>
        have h2 := analyzeBlock_numbered (advance key (guardSize none)) (r.steps T L (armEntry ok scrut alts)) ha body
        have h3 := analyzeArms_numbered scrut (advance key (guardSize none + blockSize body))
          (rejoin r (analyzeBlock ok T L (advance key (guardSize none)) (r.steps T L (armEntry ok scrut alts)) body).1)
          (numbered_rejoin h _) rest
        simp only [analyzeArms]
        exact ⟨numbered_rejoin h _, allNumbered_append allNumbered_nil (allNumbered_append h2.2 h3.2)⟩
      | some g =>
        have hg := analyzeExpr_numbered key (r.steps T L (armEntry ok scrut alts)) ha g
        have h2 := analyzeBlock_numbered (advance key (guardSize (some g)))
          (analyzeExpr ok T L key (r.steps T L (armEntry ok scrut alts)) g).1 hg.1 body
        have h3 := analyzeArms_numbered scrut (advance key (guardSize (some g) + blockSize body))
          (rejoin r (analyzeBlock ok T L (advance key (guardSize (some g)))
            (analyzeExpr ok T L key (r.steps T L (armEntry ok scrut alts)) g).1 body).1)
          (numbered_rejoin h _) rest
        simp only [analyzeArms]
        exact ⟨numbered_rejoin h _, allNumbered_append hg.2 (allNumbered_append h2.2 h3.2)⟩

  theorem analyzeClauses_numbered (key : Key) (r : Run) (h : Numbered r.state) (clauses : Clauses) :
      Numbered (analyzeClauses ok T L key r clauses).1.state ∧ AllNumbered (analyzeClauses ok T L key r clauses).2 := by
    match clauses with
    | .nil =>
      simp only [analyzeClauses]
      exact ⟨h, allNumbered_nil⟩
    | .cons _ arity _ body rest dictCount =>
      have h1 := analyzeBlock_numbered key (r.enter (freshN (1 + arity + dictCount) r.state.scope))
        (numbered_enter (WellNumbered.freshN h (1 + arity + dictCount)) r) body
      have h2 := analyzeClauses_numbered (advance key (blockSize body))
        (r.leave (analyzeBlock ok T L key (r.enter (freshN (1 + arity + dictCount) r.state.scope)) body).1)
        (numbered_leave h _) rest
      simp only [analyzeClauses]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
end

/-- 関数の本体の解析の記録は、入口の束縛番号が不変条件を満たせば、全て不変条件を満たす。 -/
theorem analyzeBody_numbered (key : Key) {scope : Interval.BindingScope} (h : WellNumbered scope) (body : Block) :
    AllNumbered (analyzeBody ok T L key scope body).2 :=
  (analyzeBlock_numbered key (.running (ScopeState.empty scope) .initial) h body).2

end Numbering

end Benitoite.Release.Refinement.Surface.ScopeLower
