import Benitoite.Surface.ScopeAccept

/-!
# 到達した文の右辺と出現の番号の一致（L50.4、RV-L50 中4）

Scope の接続定理（`Surface.ScopeSound`）は、表層の具体の評価が番号 k の文の始まりへ到達すること（`ReachBlock`）と、
その文の右辺の呼び出しが出現の一覧（`occurrences`）の番号 k にあること（`hocc`）を別の前提に取る。本ファイルは、
到達した文の右辺 e を添字に持つ到達の関係 `ReachAtBlock`（`ReachBlock` の全ての構成子に、到達した文の右辺を一つ足した
写し）を置き、次の二つを示す（設計書 07-04「証明する性質」）。

- `ReachAtBlock.toReach`・`ReachBlock.toAt`: 右辺を添字に持つ到達は `ReachBlock` の到達であり、`ReachBlock` のどの
  到達にも到達した文の右辺がある。
- `ReachAtBlock.occ`: 番号 k の文の始まりへ到達し、その文の右辺が e なら、`(k, e)` は出現の一覧に入る。到達の関係の
  各構成子が子へ渡す番号（`advance`・`argsKey`・`blockSize`・`guardSize`）は、出現の一覧の先行順
  （`Interval.surfacePreorder`）の位置と同じ数え方である。

接続定理の系（`ScopeSound` の `*_at`）は、`hreach` と `hocc` の代わりに `ReachAtBlock` を前提に取る。
-/

namespace Benitoite.Surface.ScopeOccurrence

open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Surface.ScopeLower
open Benitoite.Surface.ScopeAccept

/-! ## 出現の一覧の一般形 -/

/-- 式の列を番号 key から先行順に番号付けする（`occurrences` の一般形）。 -/
def occ (key : Key) (xs : List Expr) : List (Key × Expr) :=
  xs.zipIdx key.surfacePreorder |>.map fun (e, i) => (⟨key.definition, i⟩, e)

theorem occurrences_eq (key : Key) (body : Block) : occurrences key body = occ key (Interval.preorderBlock body) := rfl

theorem occ_cons (key : Key) (x : Expr) (xs : List Expr) : occ key (x :: xs) = (key, x) :: occ (advance key 1) xs := by
  simp [occ, advance, List.zipIdx_cons]

theorem occ_append (key : Key) (xs ys : List Expr) :
    occ key (xs ++ ys) = occ key xs ++ occ (advance key xs.length) ys := by
  simp [occ, advance, List.zipIdx_append]

theorem advance_advance (key : Key) (a b : Nat) : advance (advance key a) b = advance key (a + b) := by
  simp [advance, Nat.add_assoc]

theorem mem_occ_head {key : Key} {x : Expr} {xs : List Expr} : (key, x) ∈ occ key (x :: xs) := by
  rw [occ_cons]; exact List.mem_cons_self

theorem mem_occ_cons {key : Key} {x : Expr} {xs : List Expr} {p : Key × Expr}
    (h : p ∈ occ (advance key 1) xs) : p ∈ occ key (x :: xs) := by
  rw [occ_cons]; exact List.mem_cons_of_mem _ h

theorem mem_occ_left {key : Key} {xs ys : List Expr} {p : Key × Expr} (h : p ∈ occ key xs) :
    p ∈ occ key (xs ++ ys) := by
  rw [occ_append]; exact List.mem_append_left _ h

theorem mem_occ_right {key : Key} {xs ys : List Expr} {p : Key × Expr} {n : Nat} (hn : xs.length = n)
    (h : p ∈ occ (advance key n) ys) : p ∈ occ key (xs ++ ys) := by
  rw [occ_append, hn]; exact List.mem_append_right _ h

/-- 番号の和の付け替え（`advance` を一つにまとめる）。 -/
theorem mem_occ_key {k1 k2 : Key} {xs : List Expr} {p : Key × Expr} (hk : k1 = k2) (h : p ∈ occ k1 xs) :
    p ∈ occ k2 xs := hk ▸ h

/-- 文の並びの右辺は、その並びの先行順の先頭である。 -/
theorem preorderBlock_rhs {b : Block} {e : Expr} (h : blockRhs? b = some e) :
    ∃ rest, Interval.preorderBlock b = e :: rest := by
  cases b <;> simp [blockRhs?] at h <;> subst h <;>
    simp [Interval.preorderBlock, Interval.surfacePreorder_children]

/-- guard の先行順。 -/
def guardPre : Option Expr → List Expr
  | none => []
  | some g => Interval.surfacePreorder g

theorem guardPre_length {guard : Option Expr} : (guardPre guard).length = guardSize guard := by
  cases guard <;> rfl

theorem preorderArms_cons {alts : List Alternative} {guard : Option Expr} {body : Block} {rest : Arms} :
    Interval.preorderArms (.cons alts guard body rest) =
      guardPre guard ++ Interval.preorderBlock body ++ Interval.preorderArms rest := by
  cases guard <;> simp [Interval.preorderArms, guardPre]

/-! ## 到達した文の右辺を添字に持つ到達の関係 -/

mutual
  /-- `ReachExpr` の写し。最後の添字 e は、到達した文の右辺である。 -/
  inductive ReachAtExpr (T : ScopeTable Release.Val) : Key → Locals → Expr → Key → Locals → Expr → Prop where
    | paren {key env e k env' x} : ReachAtExpr T (advance key 1) env e k env' x → ReachAtExpr T key env (.paren e) k env' x
    | returnE {key env ty e k env' x} : ReachAtExpr T (advance key 1) env e k env' x →
        ReachAtExpr T key env (.returnE ty e) k env' x
    | callee {key env callee labels positions args k env' x} : ReachAtExpr T (advance key 1) env callee k env' x →
        ReachAtExpr T key env (.call callee labels positions args) k env' x
    | args {key env callee labels positions args k env' x} : ReachAtExprs T (argsKey key callee) env args k env' x →
        ReachAtExpr T key env (.call callee labels positions args) k env' x
    | block {key env body k env' x} : ReachAtBlock T (advance key 1) env body k env' x →
        ReachAtExpr T key env (.block body) k env' x
    | iteCond {key env c yes no k env' x} : ReachAtExpr T (advance key 1) env c k env' x →
        ReachAtExpr T key env (.ite c yes no) k env' x
    | iteYes {key env c yes no k env' x} :
        ReachAtBlock T (advance key (1 + Interval.surfaceSize c)) env yes k env' x →
        ReachAtExpr T key env (.ite c yes no) k env' x
    | iteNo {key env c yes no k env' x} :
        ReachAtBlock T (advance key (1 + Interval.surfaceSize c + blockSize yes)) env no k env' x →
        ReachAtExpr T key env (.ite c yes no) k env' x
    | elseIfCond {key env c yes no k env' x} : ReachAtExpr T (advance key 1) env c k env' x →
        ReachAtExpr T key env (.elseIf c yes no) k env' x
    | elseIfYes {key env c yes no k env' x} :
        ReachAtBlock T (advance key (1 + Interval.surfaceSize c)) env yes k env' x →
        ReachAtExpr T key env (.elseIf c yes no) k env' x
    | elseIfNo {key env c yes no k env' x} :
        ReachAtExpr T (advance key (1 + Interval.surfaceSize c + blockSize yes)) env no k env' x →
        ReachAtExpr T key env (.elseIf c yes no) k env' x
    | ifOnlyCond {key env c yes k env' x} : ReachAtExpr T (advance key 1) env c k env' x →
        ReachAtExpr T key env (.ifOnly c yes) k env' x
    | ifOnlyYes {key env c yes k env' x} :
        ReachAtBlock T (advance key (1 + Interval.surfaceSize c)) env yes k env' x →
        ReachAtExpr T key env (.ifOnly c yes) k env' x
    | matchScrut {key env ty s arms k env' x} : ReachAtExpr T (advance key 1) env s k env' x →
        ReachAtExpr T key env (.matchE ty s arms) k env' x
    | matchArms {key env ty s arms k env' x} :
        ReachAtArms T (scrutIndex s) (advance key (1 + Interval.surfaceSize s)) env arms k env' x →
        ReachAtExpr T key env (.matchE ty s arms) k env' x
    | lam {key env names params ret eff body env0 k env' x} : ReachAtBlock T (advance key 1) env0 body k env' x →
        ReachAtExpr T key env (.lam names params ret eff body) k env' x
    | lazyE {key env body env0 k env' x} : ReachAtBlock T (advance key 1) env0 body k env' x →
        ReachAtExpr T key env (.lazyE body) k env' x
    | handleBody {key env body clauses k env' x} : ReachAtBlock T (advance key 1) env body k env' x →
        ReachAtExpr T key env (.handleE body clauses) k env' x
    | handleClauses {key env body clauses k env' x} :
        ReachAtClauses T (advance key (1 + blockSize body)) clauses k env' x →
        ReachAtExpr T key env (.handleE body clauses) k env' x
    | failBody {key env error result body clause k env' x} : ReachAtBlock T (advance key 1) env body k env' x →
        ReachAtExpr T key env (.handleFail error result body clause) k env' x
    | failClause {key env error result body clause env0 k env' x} :
        ReachAtBlock T (advance key (1 + blockSize body)) env0 clause k env' x →
        ReachAtExpr T key env (.handleFail error result body clause) k env' x
    | withExpr {key env o e body k env' x} : ReachAtExpr T (advance key 1) env e k env' x →
        ReachAtExpr T key env (.withE o e body) k env' x
    | withBody {key env o e body v k env' x} :
        ReachAtBlock T (advance key (1 + Interval.surfaceSize e)) (v :: env) body k env' x →
        ReachAtExpr T key env (.withE o e body) k env' x

  /-- `ReachExprs` の写し。 -/
  inductive ReachAtExprs (T : ScopeTable Release.Val) : Key → Locals → Exprs → Key → Locals → Expr → Prop where
    | head {key env e es k env' x} : ReachAtExpr T key env e k env' x → ReachAtExprs T key env (.cons e es) k env' x
    | tail {key env e es k env' x} : ReachAtExprs T (advance key (Interval.surfaceSize e)) env es k env' x →
        ReachAtExprs T key env (.cons e es) k env' x

  /-- `ReachBlock` の写し。`here` は到達した文の右辺 e を添字に置く。 -/
  inductive ReachAtBlock (T : ScopeTable Release.Val) : Key → Locals → Block → Key → Locals → Expr → Prop where
    | here {key env b e} : blockRhs? b = some e → ReachAtBlock T key env b key env e
    | rhs {key env b e k env' x} : blockRhs? b = some e → ReachAtExpr T key env e k env' x →
        ReachAtBlock T key env b k env' x
    | builder {key env kind rest k env' x} : ReachAtBlock T key (none :: env) rest k env' x →
        ReachAtBlock T key env (.builderBind kind rest) k env' x
    | bind {key env kind ty e rest v k env' x} : RhsEval T key env e v →
        ReachAtBlock T (advance key (Interval.surfaceSize e)) (v :: env) rest k env' x →
        ReachAtBlock T key env (.bind kind ty e rest) k env' x
    | discard {key env e rest k env' x} : ReachAtBlock T (advance key (Interval.surfaceSize e)) env rest k env' x →
        ReachAtBlock T key env (.discard e rest) k env' x
    | seq {key env e rest k env' x} : ReachAtBlock T (advance key (Interval.surfaceSize e)) env rest k env' x →
        ReachAtBlock T key env (.seq e rest) k env' x
    | bindPat {key env kind pat ty e rest vals k env' x} : vals.length = pat.binders →
        ReachAtBlock T (advance key (Interval.surfaceSize e)) (vals ++ env) rest k env' x →
        ReachAtBlock T key env (.bindPat kind pat ty e rest) k env' x

  /-- `ReachArms` の写し。 -/
  inductive ReachAtArms (T : ScopeTable Release.Val) : Option Nat → Key → Locals → Arms → Key → Locals → Expr → Prop where
    | guard {scrut key env alts g body rest envA k env' x} : ArmEnter env scrut alts envA →
        ReachAtExpr T key envA g k env' x → ReachAtArms T scrut key env (.cons alts (some g) body rest) k env' x
    | body {scrut key env alts guard body rest envA k env' x} : ArmEnter env scrut alts envA →
        ReachAtBlock T (advance key (guardSize guard)) envA body k env' x →
        ReachAtArms T scrut key env (.cons alts guard body rest) k env' x
    | next {scrut key env alts guard body rest k env' x} :
        ReachAtArms T scrut (advance key (guardSize guard + blockSize body)) env rest k env' x →
        ReachAtArms T scrut key env (.cons alts guard body rest) k env' x

  /-- `ReachClauses` の写し。 -/
  inductive ReachAtClauses (T : ScopeTable Release.Val) : Key → Clauses → Key → Locals → Expr → Prop where
    | body {key op arity ntys body rest dictCount env0 k env' x} : ReachAtBlock T key env0 body k env' x →
        ReachAtClauses T key (.cons op arity ntys body rest dictCount) k env' x
    | next {key op arity ntys body rest dictCount k env' x} :
        ReachAtClauses T (advance key (blockSize body)) rest k env' x →
        ReachAtClauses T key (.cons op arity ntys body rest dictCount) k env' x
end

variable {T : ScopeTable Release.Val}

/-! ## 右辺を添字に持つ到達は `ReachBlock` の到達である -/

mutual
  theorem ReachAtExpr.toReach {key env e k env' x} (h : ReachAtExpr T key env e k env' x) :
      ReachExpr T key env e k env' := by
    match h with
    | .paren h' => exact .paren h'.toReach
    | .returnE h' => exact .returnE h'.toReach
    | .callee h' => exact .callee h'.toReach
    | .args h' => exact .args h'.toReach
    | .block h' => exact .block h'.toReach
    | .iteCond h' => exact .iteCond h'.toReach
    | .iteYes h' => exact .iteYes h'.toReach
    | .iteNo h' => exact .iteNo h'.toReach
    | .elseIfCond h' => exact .elseIfCond h'.toReach
    | .elseIfYes h' => exact .elseIfYes h'.toReach
    | .elseIfNo h' => exact .elseIfNo h'.toReach
    | .ifOnlyCond h' => exact .ifOnlyCond h'.toReach
    | .ifOnlyYes h' => exact .ifOnlyYes h'.toReach
    | .matchScrut h' => exact .matchScrut h'.toReach
    | .matchArms h' => exact .matchArms h'.toReach
    | .lam h' => exact .lam h'.toReach
    | .lazyE h' => exact .lazyE h'.toReach
    | .handleBody h' => exact .handleBody h'.toReach
    | .handleClauses h' => exact .handleClauses h'.toReach
    | .failBody h' => exact .failBody h'.toReach
    | .failClause h' => exact .failClause h'.toReach
    | .withExpr h' => exact .withExpr h'.toReach
    | .withBody h' => exact .withBody h'.toReach

  theorem ReachAtExprs.toReach {key env es k env' x} (h : ReachAtExprs T key env es k env' x) :
      ReachExprs T key env es k env' := by
    match h with
    | .head h' => exact .head h'.toReach
    | .tail h' => exact .tail h'.toReach

  theorem ReachAtBlock.toReach {key env b k env' x} (h : ReachAtBlock T key env b k env' x) :
      ReachBlock T key env b k env' := by
    match h with
    | .here hb => exact .here hb
    | .rhs hb h' => exact .rhs hb h'.toReach
    | .builder h' => exact .builder h'.toReach
    | .bind hv h' => exact .bind hv h'.toReach
    | .discard h' => exact .discard h'.toReach
    | .seq h' => exact .seq h'.toReach
    | .bindPat hl h' => exact .bindPat hl h'.toReach

  theorem ReachAtArms.toReach {scrut key env arms k env' x} (h : ReachAtArms T scrut key env arms k env' x) :
      ReachArms T scrut key env arms k env' := by
    match h with
    | .guard ha h' => exact .guard ha h'.toReach
    | .body ha h' => exact .body ha h'.toReach
    | .next h' => exact .next h'.toReach

  theorem ReachAtClauses.toReach {key cs k env' x} (h : ReachAtClauses T key cs k env' x) :
      ReachClauses T key cs k env' := by
    match h with
    | .body h' => exact .body h'.toReach
    | .next h' => exact .next h'.toReach
end

/-! ## `ReachBlock` の到達には、到達した文の右辺がある -/

mutual
  theorem _root_.Benitoite.Surface.ScopeLower.ReachExpr.toAt {key env e k env'} (h : ReachExpr T key env e k env') :
      ∃ x, ReachAtExpr T key env e k env' x := by
    match h with
    | .paren h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .paren h'⟩
    | .returnE h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .returnE h'⟩
    | .callee h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .callee h'⟩
    | .args h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .args h'⟩
    | .block h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .block h'⟩
    | .iteCond h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .iteCond h'⟩
    | .iteYes h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .iteYes h'⟩
    | .iteNo h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .iteNo h'⟩
    | .elseIfCond h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .elseIfCond h'⟩
    | .elseIfYes h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .elseIfYes h'⟩
    | .elseIfNo h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .elseIfNo h'⟩
    | .ifOnlyCond h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .ifOnlyCond h'⟩
    | .ifOnlyYes h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .ifOnlyYes h'⟩
    | .matchScrut h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .matchScrut h'⟩
    | .matchArms h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .matchArms h'⟩
    | .lam h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .lam h'⟩
    | .lazyE h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .lazyE h'⟩
    | .handleBody h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .handleBody h'⟩
    | .handleClauses h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .handleClauses h'⟩
    | .failBody h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .failBody h'⟩
    | .failClause h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .failClause h'⟩
    | .withExpr h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .withExpr h'⟩
    | .withBody h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .withBody h'⟩

  theorem _root_.Benitoite.Surface.ScopeLower.ReachExprs.toAt {key env es k env'} (h : ReachExprs T key env es k env') :
      ∃ x, ReachAtExprs T key env es k env' x := by
    match h with
    | .head h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .head h'⟩
    | .tail h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .tail h'⟩

  theorem _root_.Benitoite.Surface.ScopeLower.ReachBlock.toAt {key env b k env'} (h : ReachBlock T key env b k env') :
      ∃ x, ReachAtBlock T key env b k env' x := by
    match h with
    | .here hb => exact ⟨_, .here hb⟩
    | .rhs hb h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .rhs hb h'⟩
    | .builder h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .builder h'⟩
    | .bind hv h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .bind hv h'⟩
    | .discard h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .discard h'⟩
    | .seq h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .seq h'⟩
    | .bindPat hl h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .bindPat hl h'⟩

  theorem _root_.Benitoite.Surface.ScopeLower.ReachArms.toAt {scrut key env arms k env'} (h : ReachArms T scrut key env arms k env') :
      ∃ x, ReachAtArms T scrut key env arms k env' x := by
    match h with
    | .guard ha h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .guard ha h'⟩
    | .body ha h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .body ha h'⟩
    | .next h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .next h'⟩

  theorem _root_.Benitoite.Surface.ScopeLower.ReachClauses.toAt {key cs k env'} (h : ReachClauses T key cs k env') :
      ∃ x, ReachAtClauses T key cs k env' x := by
    match h with
    | .body h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .body h'⟩
    | .next h' => obtain ⟨x, h'⟩ := h'.toAt; exact ⟨x, .next h'⟩
end

/-! ## 到達した文の右辺は出現の一覧の同じ番号にある -/

/-- 番号の付け替えに使う簡約。 -/
theorem advance_one_add (key : Key) (n : Nat) : advance (advance key 1) n = advance key (1 + n) :=
  advance_advance key 1 n

mutual
  theorem ReachAtExpr.occ {key env e k env' x} (h : ReachAtExpr T key env e k env' x) :
      (k, x) ∈ occ key (Interval.surfacePreorder e) := by
    match h with
    | .paren h' | .returnE h' =>
      simp only [Interval.surfacePreorder]; exact mem_occ_cons h'.occ
    | .callee h' =>
      simp only [Interval.surfacePreorder]; exact mem_occ_cons (mem_occ_left h'.occ)
    | .args (callee := callee) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [argsKey, advance_advance, Interval.surfaceSize]) h'.occ))
    | .block h' | .lam h' | .lazyE h' =>
      simp only [Interval.surfacePreorder]; exact mem_occ_cons h'.occ
    | .iteCond h' | .elseIfCond h' =>
      simp only [Interval.surfacePreorder]; exact mem_occ_cons (mem_occ_left (mem_occ_left h'.occ))
    | .ifOnlyCond h' | .matchScrut h' | .withExpr h' =>
      simp only [Interval.surfacePreorder]; exact mem_occ_cons (mem_occ_left h'.occ)
    | .iteYes (c := c) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_left (mem_occ_right rfl
        (mem_occ_key (by simp [Interval.surfaceSize, advance_advance]) h'.occ)))
    | .iteNo (c := c) (yes := yes) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Interval.surfaceSize, blockSize, advance_advance, Nat.add_assoc]) h'.occ))
    | .elseIfYes (c := c) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_left (mem_occ_right rfl
        (mem_occ_key (by simp [Interval.surfaceSize, advance_advance]) h'.occ)))
    | .elseIfNo (c := c) (yes := yes) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Interval.surfaceSize, blockSize, advance_advance, Nat.add_assoc]) h'.occ))
    | .ifOnlyYes (c := c) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl (mem_occ_key (by simp [Interval.surfaceSize, advance_advance]) h'.occ))
    | .matchArms (s := s) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl (mem_occ_key (by simp [Interval.surfaceSize, advance_advance]) h'.occ))
    | .handleBody h' | .failBody h' =>
      simp only [Interval.surfacePreorder]; exact mem_occ_cons (mem_occ_left h'.occ)
    | .handleClauses (body := body) h' | .failClause (body := body) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl (mem_occ_key (by simp [blockSize, advance_advance]) h'.occ))
    | .withBody (e := e) h' =>
      simp only [Interval.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl (mem_occ_key (by simp [Interval.surfaceSize, advance_advance]) h'.occ))

  theorem ReachAtExprs.occ {key env es k env' x} (h : ReachAtExprs T key env es k env' x) :
      (k, x) ∈ occ key (Interval.preorderExprs es) := by
    match h with
    | .head h' => simp only [Interval.preorderExprs]; exact mem_occ_left h'.occ
    | .tail h' => simp only [Interval.preorderExprs]; exact mem_occ_right rfl h'.occ

  theorem ReachAtBlock.occ {key env b k env' x} (h : ReachAtBlock T key env b k env' x) :
      (k, x) ∈ occ key (Interval.preorderBlock b) := by
    match h with
    | .here hb =>
      obtain ⟨rest, hr⟩ := preorderBlock_rhs hb
      rw [hr]; exact mem_occ_head
    | .rhs (b := b) hb h' =>
      cases b <;> simp [blockRhs?] at hb <;> subst hb <;> simp only [Interval.preorderBlock] <;>
        first | exact h'.occ | exact mem_occ_left h'.occ
    | .builder h' => simp only [Interval.preorderBlock]; exact h'.occ
    | .bind _ h' | .discard h' | .seq h' | .bindPat _ h' =>
      simp only [Interval.preorderBlock]; exact mem_occ_right rfl h'.occ

  theorem ReachAtArms.occ {scrut key env arms k env' x} (h : ReachAtArms T scrut key env arms k env' x) :
      (k, x) ∈ occ key (Interval.preorderArms arms) := by
    match h with
    | .guard _ h' => simp only [Interval.preorderArms]; exact mem_occ_left (mem_occ_left h'.occ)
    | .body _ h' =>
      rw [preorderArms_cons]; exact mem_occ_left (mem_occ_right guardPre_length h'.occ)
    | .next h' =>
      rw [preorderArms_cons]; exact mem_occ_right (by simp [guardPre_length, blockSize]) h'.occ

  theorem ReachAtClauses.occ {key cs k env' x} (h : ReachAtClauses T key cs k env' x) :
      (k, x) ∈ occ key (Interval.preorderClauses cs) := by
    match h with
    | .body h' => simp only [Interval.preorderClauses]; exact mem_occ_left h'.occ
    | .next h' => simp only [Interval.preorderClauses]; exact mem_occ_right rfl h'.occ
end

/-- 番号 k の文の始まりへ到達し、その文の右辺が e なら、`(k, e)` は本体の出現の一覧に入る（RV-L50 中4。接続定理の
前提 `hocc` を到達から得る）。 -/
theorem reachAt_occurrences {key env body k env' x} (h : ReachAtBlock T key env body k env' x) :
    (k, x) ∈ occurrences key body := by
  rw [occurrences_eq]; exact h.occ

/-- `ReachBlock` のどの到達でも、到達した文の右辺は出現の一覧の同じ番号にある。 -/
theorem reach_occurrences {key env body k env'} (h : ReachBlock T key env body k env') :
    ∃ x, ReachAtBlock T key env body k env' x ∧ (k, x) ∈ occurrences key body := by
  obtain ⟨x, hx⟩ := h.toAt
  exact ⟨x, hx, reachAt_occurrences hx⟩

end Benitoite.Surface.ScopeOccurrence
