import Benitoite.Release.Refinement.Surface.ScopeState
import Benitoite.Release.Refinement.Surface.Identity

/-!
# 表層の構文から Scope の必須の判定への対応

本体の文の始まりの状態を、式の先行順の番号で記録する。記録しない出現も走査の番号を使い、
受理では事実を持たない状態で判定する。照合の腕の文脈には、照合する値とパターンの束縛を加える
（設計書 01-12「Scope の局所解析の表層からの対応」）。
-/
namespace Benitoite.Release.Refinement.Surface.ScopeLower

open Benitoite.Scope.Inference
open Benitoite.Release.Refinement.Surface.ScopeState
open Benitoite.Scope.Domain (Range)

/-- 解析が文の始まりに記録する状態の列。 -/
abbrev Records := List (Key × ScopeState)

/-! ## 出現の番号 -/

/-- 番号を n だけ進める（区間解析の `advanceKey` と同じ）。 -/
def advance (key : Key) (n : Nat) : Key := ⟨key.definition, key.surfacePreorder + n⟩

/-- Block が占める番号の個数。 -/
def blockSize (body : Block) : Nat := (Identity.preorderBlock body).length

/-- guard が占める番号の個数。 -/
def guardSize : Option Expr → Nat
  | none => 0
  | some g => Identity.surfaceSize g

/-! ## 引数の形 -/

/-- 直接の呼び出しの頭。関数名か組み込みの名前の参照である（間接呼び出し・関数値・メソッドは含めない）。 -/
def directHead : Expr → Bool
  | .funName _ _ _ | .primName _ _ _ _ => true
  | _ => false

/-- 引数の形。 -/
inductive ArgForm where
  | str (s : String)
  | int (n : Integer64Value)
  | loc (index : Nat)
  | proj (index : Nat)
  | other
  deriving DecidableEq, Repr

/-- リテラルと `const` の直接参照。定数の本体がリテラルか、さらに `const` の参照であるときだけ値が分かる。 -/
def constArg? : Expr → Option ArgForm
  | .literal (.string s) => some (.str s)
  | .literal (.integer n) => some (.int n.toValue)
  | .negInt n => some (.int n.negValue)
  | .constE _ body => constArg? body
  | _ => none

/-- 引数の形の分類。局所の値に対する一引数の直接の呼び出しは射影の候補であり、規則を持つかは表が決める。 -/
def argForm (e : Expr) : ArgForm :=
  match constArg? e with
  | some f => f
  | none =>
    match e with
    | .local i => .loc i
    | .call callee _ [0] (.cons (.local i) .nil) => if directHead callee then .proj i else .other
    | _ => .other

/-- 引数の一段の式。key はその引数の式の出現の番号である。 -/
def lowerArg (key : Key) (e : Expr) : Arg :=
  match argForm e with
  | .str s => .lit s
  | .int n => .int n
  | .loc i => .loc i
  | .proj i => .proj key i
  | .other => .other

/-- ソース順の引数の列。 -/
def lowerArgs : Key → Exprs → List Arg
  | _, .nil => []
  | key, .cons e es => lowerArg key e :: lowerArgs (advance key (Identity.surfaceSize e)) es

/-- 契約の位置 js の順に、ソース順の列から引数を取り出す。 -/
def pick {α : Type} (positions : List Nat) (xs : List α) : List Nat → Option (List α)
  | [] => some []
  | j :: js =>
    match fieldAt j positions xs, pick positions xs js with
    | some x, some rest => some (x :: rest)
    | _, _ => none

/-- ソース順の引数の列を契約の位置の順に並べる（`CallOk` の positions はソース順の各引数の契約の位置）。 -/
def contractOrder {α : Type} (positions : List Nat) (xs : List α) : Option (List α) :=
  pick positions xs (List.range positions.length)

/-- 直接の呼び出しの引数の最初の番号。 -/
def argsKey (key : Key) (callee : Expr) : Key := advance key (1 + Identity.surfaceSize callee)

/-! ## 右辺と腕の入口 -/

/-- 束縛の右辺の一段。直接の呼び出しは `call`（規則を持つかは表が決める）、局所の参照は別名、それ以外は未知。 -/
def rhsStep (key : Key) : Expr → ScopeState.Step
  | .call callee _ positions args =>
    if directHead callee then
      match contractOrder positions (lowerArgs (argsKey key callee) args) with
      | some xs => .call key xs
      | none => .unknown
    else .unknown
  | .local i => .alias i
  | _ => .unknown

/-- 照合する値を束縛した腕の文脈における、元の局所の位置。局所の参照だけが一度保存した Result を読む。 -/
def scrutIndex : Expr → Option Nat
  | .local i => some (i + 1)
  | _ => none

/-- 腕の最初の選択肢の束縛の数。 -/
def firstSlots : List Alternative → Nat
  | [] => 0
  | a :: _ => a.slots.length

/-- 局所の値の一つの選択肢 `C(p)` の腕。照合する位置と構成子の名前。 -/
def conArm? : Option Nat → List Alternative → Option (Nat × ConName)
  | some i, [⟨.con _ c [.var], _⟩] => some (i, c)
  | _, _ => none

/-- 腕の入口の一段。`Result.Ok` の構成子 ok の腕は `okArm`、それ以外は束縛の数だけの未知。 -/
def armEntry (ok : ConName) (scrut : Option Nat) (alts : List Alternative) : List ScopeState.Step :=
  match conArm? scrut alts with
  | some (i, c) => [if c = ok then .okArm i else .unknown]
  | none => List.replicate (firstSlots alts) .unknown

/-- 本体の入口の束縛番号。囲む本体の位置の上に n 個の新しい位置を置く。 -/
def freshN : Nat → Interval.BindingScope → Interval.BindingScope
  | 0, s => s
  | n + 1, s => (freshN n s).fresh

/-- 分岐の合流。外側の状態へ戻り、予算は内側の消費を引き継ぐ。内側が止まったら、外側の由来を忘れて止まる。 -/
def rejoin (outer inner : Run) : Run :=
  match inner with
  | .running _ b =>
    match outer with
    | .running st _ => .running st b
    | .stopped f st _ => .stopped f st b
  | .stopped f _ b => .stopped f outer.state.forgetAll b

/-! ## 解析 -/

mutual
  /-- 式の内側の文の始まりを辿る。結果の状態は外側の状態（または超過でその忘却）である。 -/
  def analyzeExpr (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key) (r : Run) :
      Expr → Run × Records
    | .paren e | .returnE _ e =>
      let p := analyzeExpr ok T L (advance key 1) r e
      (rejoin r p.1, p.2)
    | .call callee _ _ args =>
      let p := analyzeExpr ok T L (advance key 1) r callee
      let q := analyzeExprs ok T L (argsKey key callee) (rejoin r p.1) args
      (rejoin r q.1, p.2 ++ q.2)
    | .block body =>
      let p := analyzeBlock ok T L (advance key 1) r body
      (rejoin r p.1, p.2)
    | .ite c yes no =>
      let p := analyzeExpr ok T L (advance key 1) r c
      let q := analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c)) (rejoin r p.1) yes
      let u := analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c + blockSize yes)) (rejoin r q.1) no
      (rejoin r u.1, p.2 ++ (q.2 ++ u.2))
    | .elseIf c yes no =>
      let p := analyzeExpr ok T L (advance key 1) r c
      let q := analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c)) (rejoin r p.1) yes
      let u := analyzeExpr ok T L (advance key (1 + Identity.surfaceSize c + blockSize yes)) (rejoin r q.1) no
      (rejoin r u.1, p.2 ++ (q.2 ++ u.2))
    | .ifOnly c yes =>
      let p := analyzeExpr ok T L (advance key 1) r c
      let q := analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c)) (rejoin r p.1) yes
      (rejoin r q.1, p.2 ++ q.2)
    | .matchE _ s arms =>
      let p := analyzeExpr ok T L (advance key 1) r s
      let q := analyzeArms ok T L (scrutIndex s) (advance key (1 + Identity.surfaceSize s)) ((rejoin r p.1).step T L .unknown) arms
      (rejoin r q.1, p.2 ++ q.2)
    | .lam _ params _ _ body =>
      let p := analyzeBlock ok T L (advance key 1) (r.enter (freshN params.length r.state.scope)) body
      (r.leave p.1, p.2)
    | .lazyE body =>
      let p := analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body
      (r.leave p.1, p.2)
    | .handleE body clauses =>
      let p := analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body
      let q := analyzeClauses ok T L (advance key (1 + blockSize body)) (r.leave p.1) clauses
      (rejoin r q.1, p.2 ++ q.2)
    | .handleFail _ _ body clause =>
      let p := analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body
      let r1 := r.leave p.1
      let q := analyzeBlock ok T L (advance key (1 + blockSize body)) (r1.enter (freshN 2 r1.state.scope)) clause
      (rejoin r (r1.leave q.1), p.2 ++ q.2)
    | .withE _ e body =>
      let p := analyzeExpr ok T L (advance key 1) r e
      let q := analyzeBlock ok T L (advance key (1 + Identity.surfaceSize e)) ((rejoin r p.1).step T L .unknown) body
      (rejoin r q.1, p.2 ++ q.2)
    | _ => (r, [])

  /-- 引数の列を順に辿る。 -/
  def analyzeExprs (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key) (r : Run) :
      Exprs → Run × Records
    | .nil => (r, [])
    | .cons e es =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeExprs ok T L (advance key (Identity.surfaceSize e)) (rejoin r p.1) es
      (rejoin r q.1, p.2 ++ q.2)

  /-- 文の並び。各文の始まりの状態を記録し、右辺の内側を辿ってから右辺の一段を進める。 -/
  def analyzeBlock (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key) (r : Run) :
      Block → Run × Records
    | .empty => (r, [])
    | .builderBind _ rest => analyzeBlock ok T L key (r.step T L .unknown) rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e =>
      let p := analyzeExpr ok T L key r e
      (p.1, (key, r.state) :: p.2)
    | .bind _ _ e rest =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeBlock ok T L (advance key (Identity.surfaceSize e)) (p.1.step T L (rhsStep key e)) rest
      (q.1, (key, r.state) :: (p.2 ++ q.2))
    | .discard e rest | .seq e rest =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeBlock ok T L (advance key (Identity.surfaceSize e)) p.1 rest
      (q.1, (key, r.state) :: (p.2 ++ q.2))
    | .bindPat _ pat _ e rest =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeBlock ok T L (advance key (Identity.surfaceSize e))
        (p.1.steps T L (List.replicate pat.binders .unknown)) rest
      (q.1, (key, r.state) :: (p.2 ++ q.2))

  /-- 腕の列。各腕は外側の状態から入口の一段を進めて始め、腕の後は外側の状態へ戻る。 -/
  def analyzeArms (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (scrut : Option Nat)
      (key : Key) (r : Run) : Arms → Run × Records
    | .nil => (r, [])
    | .cons alts guard body rest =>
      let ra := r.steps T L (armEntry ok scrut alts)
      let g : Run × Records :=
        match guard with
        | none => (ra, [])
        | some e => analyzeExpr ok T L key ra e
      let b := analyzeBlock ok T L (advance key (guardSize guard)) g.1 body
      let q := analyzeArms ok T L scrut (advance key (guardSize guard + blockSize body)) (rejoin r b.1) rest
      (rejoin r q.1, g.2 ++ (b.2 ++ q.2))

  /-- handle の節。各節は本体の入口と出口で区切る。 -/
  def analyzeClauses (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key) (r : Run) :
      Clauses → Run × Records
    | .nil => (r, [])
    | .cons _ arity _ body rest dictCount =>
      let p := analyzeBlock ok T L key (r.enter (freshN (1 + arity + dictCount) r.state.scope)) body
      let q := analyzeClauses ok T L (advance key (blockSize body)) (r.leave p.1) rest
      (rejoin r q.1, p.2 ++ q.2)
end

/-- 関数の本体の解析。引数の位置を持つ束縛番号から、由来を仮定せず、予算を 0 から始める。 -/
def analyzeBody (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key)
    (scope : Interval.BindingScope) (body : Block) : Run × Records :=
  analyzeBlock ok T L key (.running (ScopeState.empty scope) .initial) body


end Benitoite.Release.Refinement.Surface.ScopeLower
