import Benitoite.Surface.ScopeState

/-!
# 表層の式から Scope の局所解析の一段への対応

型の情報を付けた表層の構文（`Surface.Expr`・`Surface.Block`）を、`Surface.ScopeState` の一段の言語（`Step` の
`call`・`okArm`・`alias`・`unknown`、引数の `Arg`）へ対応させ、予算付きの局所解析を表層の本体の上で走らせる
（設計書 01-12「Scope の局所解析の表層からの対応」）。

- 引数: 文字列と整数のリテラル（`const` の直接参照を含む）、局所の読み取り、局所に対する直接の一引数の呼び出し
  （射影）、それ以外の式。ソース順の引数を契約の位置の順に並べ替えてから一段へ渡す（`contractOrder`）。
- 右辺: 関数名か組み込みの名前を頭に持つ直接の呼び出しは `call`、局所の参照は `alias`、それ以外は `unknown`。
  一度保存した Result の `case Result.Ok(p)` は、照合する値が局所の参照で、腕が一つの選択肢 `Ok(p)` のときだけ
  `okArm` になる。射影の結果を局所に保存してから渡す場合は、保存した位置が事実を持たないので既知にしない。
- 境界: 分岐（if の枝・match の腕）は外側の状態から始め、合流の後は外側の状態に戻る（`rejoin`）。ラムダ・遅延・
  handle の保護本体と節・失敗の節は本体の入口と出口（`Run.enter`・`Run.leave`）で区切り、由来を仮定しない。
  Task の入口はラムダの本体である。定数の埋め込み本体と、ここで辿らない式の内側には記録を置かない。
- 対応: 表層の具体の評価（`RhsEval`・`ArmEnter` と、文の始まりへ到達する関係 `ReachBlock`）は一段の具体の評価
  （`StepEval`）に対応し、解析が文の始まりに記録した状態はその地点の具体の局所に対応する（`analyzeBlock_sound`）。
  記録した状態は束縛番号の新規性の不変条件（`WellNumbered`）を満たす。

出現の番号は区間解析の先行順（`Interval.surfacePreorder`・`childKey`）と同じ数え方で、入れ子の本体の出現も囲む
定義の番号で数える。表層の具体の評価は脱糖と Release の実行とは独立の関係であり、両者の一致は結論しない。
-/

namespace Benitoite.Surface.ScopeLower

open Benitoite.Scope.Inference
open Benitoite.Surface.ScopeState
open Benitoite.Scope.Domain (Range Target)

/-- 解析が文の始まりに記録する状態の列。 -/
abbrev Records := List (Key × ScopeState)

/-! ## 出現の番号 -/

/-- 番号を n だけ進める（区間解析の `advanceKey` と同じ）。 -/
def advance (key : Key) (n : Nat) : Key := ⟨key.definition, key.surfacePreorder + n⟩

/-- 最初の子の番号は区間解析の `childKey key []` と同じである。 -/
theorem advance_one (key : Key) : advance key 1 = Interval.childKey key [] := by
  simp [advance, Interval.childKey]

/-- Block が占める番号の個数。 -/
def blockSize (body : Block) : Nat := (Interval.preorderBlock body).length

/-- guard が占める番号の個数。 -/
def guardSize : Option Expr → Nat
  | none => 0
  | some g => Interval.surfaceSize g

/-! ## 引数の形 -/

/-- 直接の呼び出しの頭。関数名か組み込みの名前の参照である（間接呼び出し・関数値・メソッドは含めない）。 -/
def directHead : Expr → Bool
  | .funName _ _ _ | .primName _ _ _ _ => true
  | _ => false

/-- 引数の形。 -/
inductive ArgForm where
  | str (s : String)
  | int (n : Release.Integer64Value)
  | loc (index : Nat)
  | proj (index : Nat)
  | other
  deriving DecidableEq, Repr

/-- リテラルと `const` の直接参照（判断 7）。定数の本体がリテラルか、さらに `const` の参照であるときだけ値が分かる。 -/
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
  | key, .cons e es => lowerArg key e :: lowerArgs (advance key (Interval.surfaceSize e)) es

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
def argsKey (key : Key) (callee : Expr) : Key := advance key (1 + Interval.surfaceSize callee)

/-! ## 右辺と腕の入口 -/

/-- 束縛の右辺の一段。直接の呼び出しは `call`（規則を持つかは表が決める）、局所の参照は別名、それ以外は未知。 -/
def rhsStep (key : Key) : Expr → Step
  | .call callee _ positions args =>
    if directHead callee then
      match contractOrder positions (lowerArgs (argsKey key callee) args) with
      | some xs => .call key xs
      | none => .unknown
    else .unknown
  | .local i => .alias i
  | _ => .unknown

/-- 照合する値の局所の位置。局所の参照だけが一度保存した Result を読む。 -/
def scrutIndex : Expr → Option Nat
  | .local i => some i
  | _ => none

/-- 腕の最初の選択肢の束縛の数。 -/
def firstSlots : List Alternative → Nat
  | [] => 0
  | a :: _ => a.slots.length

/-- 局所の値の一つの選択肢 `C(p)` の腕。照合する位置と構成子の名前。 -/
def conArm? : Option Nat → List Alternative → Option (Nat × Release.ConName)
  | some i, [⟨.con _ c [.var], _⟩] => some (i, c)
  | _, _ => none

/-- 腕の入口の一段。`Result.Ok` の構成子 ok の腕は `okArm`、それ以外は束縛の数だけの未知。 -/
def armEntry (ok : Release.ConName) (scrut : Option Nat) (alts : List Alternative) : List Step :=
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
  def analyzeExpr (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key) (r : Run) :
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
      let q := analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c)) (rejoin r p.1) yes
      let u := analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c + blockSize yes)) (rejoin r q.1) no
      (rejoin r u.1, p.2 ++ (q.2 ++ u.2))
    | .elseIf c yes no =>
      let p := analyzeExpr ok T L (advance key 1) r c
      let q := analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c)) (rejoin r p.1) yes
      let u := analyzeExpr ok T L (advance key (1 + Interval.surfaceSize c + blockSize yes)) (rejoin r q.1) no
      (rejoin r u.1, p.2 ++ (q.2 ++ u.2))
    | .ifOnly c yes =>
      let p := analyzeExpr ok T L (advance key 1) r c
      let q := analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c)) (rejoin r p.1) yes
      (rejoin r q.1, p.2 ++ q.2)
    | .matchE _ s arms =>
      let p := analyzeExpr ok T L (advance key 1) r s
      let q := analyzeArms ok T L (scrutIndex s) (advance key (1 + Interval.surfaceSize s)) (rejoin r p.1) arms
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
      let q := analyzeBlock ok T L (advance key (1 + Interval.surfaceSize e)) ((rejoin r p.1).step T L .unknown) body
      (rejoin r q.1, p.2 ++ q.2)
    | _ => (r, [])

  /-- 引数の列を順に辿る。 -/
  def analyzeExprs (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key) (r : Run) :
      Exprs → Run × Records
    | .nil => (r, [])
    | .cons e es =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeExprs ok T L (advance key (Interval.surfaceSize e)) (rejoin r p.1) es
      (rejoin r q.1, p.2 ++ q.2)

  /-- 文の並び。各文の始まりの状態を記録し、右辺の内側を辿ってから右辺の一段を進める。 -/
  def analyzeBlock (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key) (r : Run) :
      Block → Run × Records
    | .empty => (r, [])
    | .builderBind _ rest => analyzeBlock ok T L key (r.step T L .unknown) rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e =>
      let p := analyzeExpr ok T L key r e
      (p.1, (key, r.state) :: p.2)
    | .bind _ _ e rest =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeBlock ok T L (advance key (Interval.surfaceSize e)) (p.1.step T L (rhsStep key e)) rest
      (q.1, (key, r.state) :: (p.2 ++ q.2))
    | .discard e rest | .seq e rest =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeBlock ok T L (advance key (Interval.surfaceSize e)) p.1 rest
      (q.1, (key, r.state) :: (p.2 ++ q.2))
    | .bindPat _ pat _ e rest =>
      let p := analyzeExpr ok T L key r e
      let q := analyzeBlock ok T L (advance key (Interval.surfaceSize e))
        (p.1.steps T L (List.replicate pat.binders .unknown)) rest
      (q.1, (key, r.state) :: (p.2 ++ q.2))

  /-- 腕の列。各腕は外側の状態から入口の一段を進めて始め、腕の後は外側の状態へ戻る。 -/
  def analyzeArms (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (scrut : Option Nat)
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
  def analyzeClauses (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key) (r : Run) :
      Clauses → Run × Records
    | .nil => (r, [])
    | .cons _ arity _ body rest dictCount =>
      let p := analyzeBlock ok T L key (r.enter (freshN (1 + arity + dictCount) r.state.scope)) body
      let q := analyzeClauses ok T L (advance key (blockSize body)) (r.leave p.1) rest
      (rejoin r q.1, p.2 ++ q.2)
end

/-- 腕の guard の解析（`analyzeArms` の中の場合分けと同じ）。 -/
def guardRun (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key) (ra : Run) :
    Option Expr → Run × Records
  | none => (ra, [])
  | some e => analyzeExpr ok T L key ra e

theorem analyzeArms_cons (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (scrut : Option Nat)
    (key : Key) (r : Run) (alts : List Alternative) (guard : Option Expr) (body : Block) (rest : Arms) :
    analyzeArms ok T L scrut key r (.cons alts guard body rest) =
      (rejoin r (analyzeArms ok T L scrut (advance key (guardSize guard + blockSize body))
        (rejoin r (analyzeBlock ok T L (advance key (guardSize guard))
          (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1 body).1) rest).1,
       (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).2 ++
        ((analyzeBlock ok T L (advance key (guardSize guard))
          (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1 body).2 ++
         (analyzeArms ok T L scrut (advance key (guardSize guard + blockSize body))
          (rejoin r (analyzeBlock ok T L (advance key (guardSize guard))
            (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1 body).1) rest).2)) := by
  cases guard <;> simp [analyzeArms, guardRun]

/-- 関数の本体の解析。引数の位置を持つ束縛番号から、由来を仮定せず、予算を 0 から始める。 -/
def analyzeBody (ok : Release.ConName) (T : ScopeTable Release.Val) (L : Limits) (key : Key)
    (scope : Interval.BindingScope) (body : Block) : Run × Records :=
  analyzeBlock ok T L key (.running (ScopeState.empty scope) .initial) body

/-! ## 表層の具体の評価 -/

/-- 引数の具体の評価。リテラルと `const` の直接参照はその定数、局所の参照はその値、射影の形の呼び出しは表の規則で
評価し（同定されなければ任意の値）、それ以外の式は値を読まない（任意の値）。 -/
inductive ArgEval (T : ScopeTable Release.Val) (key : Key) (env : Locals) : Expr → Release.Val → Prop where
  | str {e s} : constArg? e = some (.str s) → ArgEval T key env e (.const (.string s))
  | int {e n} : constArg? e = some (.int n) → ArgEval T key env e (.const (.integer n))
  | loc {i v} : env[i]? = some (some v) → ArgEval T key env (.local i) v
  | projStd {e i w rs v} : argForm e = .proj i → env[i]? = some (some w) → EvalScope T key rs [w] v →
      ArgEval T key env e v
  | projOther {e i v} : argForm e = .proj i → T.ruleAt key = none → ArgEval T key env e v
  | other {e v} : argForm e = .other → ArgEval T key env e v

/-- ソース順の引数の具体の評価。 -/
inductive ArgEvals (T : ScopeTable Release.Val) (env : Locals) : Key → Exprs → List Release.Val → Prop where
  | nil {key} : ArgEvals T env key .nil []
  | cons {key e es v vs} : ArgEval T key env e v →
      ArgEvals T env (advance key (Interval.surfaceSize e)) es vs → ArgEvals T env key (.cons e es) (v :: vs)

/-- 直接の呼び出しと局所の参照かどうか。 -/
def callOrLocal : Expr → Bool
  | .call _ _ _ _ | .local _ => true
  | _ => false

/-- 束縛の右辺の具体の評価（束縛する値）。同定された直接の呼び出しは契約の順の引数で表の規則を評価し、局所の参照は
その値を返す。同定されない呼び出し・間接呼び出し・それ以外の式は任意の値を返してよい（内側は読まない）。 -/
inductive RhsEval (T : ScopeTable Release.Val) (key : Key) (env : Locals) : Expr → Option Release.Val → Prop where
  | callStd {callee labels positions args vals vs rs v} : directHead callee = true →
      ArgEvals T env (argsKey key callee) args vals → contractOrder positions vals = some vs →
      EvalScope T key rs vs v → RhsEval T key env (.call callee labels positions args) (some v)
  | callOther {callee labels positions args v} : T.ruleAt key = none →
      RhsEval T key env (.call callee labels positions args) (some v)
  | indirect {callee labels positions args v} : directHead callee = false →
      RhsEval T key env (.call callee labels positions args) v
  | alias {i v} : env[i]? = some (some v) → RhsEval T key env (.local i) (some v)
  | other {e v} : callOrLocal e = false → RhsEval T key env e v

/-- 腕の入口の具体の束縛。局所の値の一つの選択肢 `C(p)` の腕は、その値が構成子 C の値のときだけ入り、引数を束縛する。
それ以外の腕は、最初の選択肢の束縛の数だけの任意の値を束縛する（照合の内容は読まない）。 -/
inductive ArmEnter (env : Locals) : Option Nat → List Alternative → Locals → Prop where
  | con {scrut alts i c tys w} : conArm? scrut alts = some (i, c) →
      env[i]? = some (some (.con c tys [w])) → ArmEnter env scrut alts (some w :: env)
  | other {scrut alts vals} : conArm? scrut alts = none → vals.length = firstSlots alts →
      ArmEnter env scrut alts (vals ++ env)

/-- 文の右辺。 -/
def blockRhs? : Block → Option Expr
  | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e
  | .bind _ _ e _ | .discard e _ | .seq e _ | .bindPat _ _ _ e _ => some e
  | .empty | .builderBind _ _ => none

mutual
  /-- 式の評価の中で、番号 k の文の始まりへ局所 env' で到達する。本体（ラムダ・遅延・節）の入口の局所は任意である。 -/
  inductive ReachExpr (T : ScopeTable Release.Val) : Key → Locals → Expr → Key → Locals → Prop where
    | paren {key env e k env'} : ReachExpr T (advance key 1) env e k env' → ReachExpr T key env (.paren e) k env'
    | returnE {key env ty e k env'} : ReachExpr T (advance key 1) env e k env' →
        ReachExpr T key env (.returnE ty e) k env'
    | callee {key env callee labels positions args k env'} : ReachExpr T (advance key 1) env callee k env' →
        ReachExpr T key env (.call callee labels positions args) k env'
    | args {key env callee labels positions args k env'} : ReachExprs T (argsKey key callee) env args k env' →
        ReachExpr T key env (.call callee labels positions args) k env'
    | block {key env body k env'} : ReachBlock T (advance key 1) env body k env' →
        ReachExpr T key env (.block body) k env'
    | iteCond {key env c yes no k env'} : ReachExpr T (advance key 1) env c k env' →
        ReachExpr T key env (.ite c yes no) k env'
    | iteYes {key env c yes no k env'} : ReachBlock T (advance key (1 + Interval.surfaceSize c)) env yes k env' →
        ReachExpr T key env (.ite c yes no) k env'
    | iteNo {key env c yes no k env'} :
        ReachBlock T (advance key (1 + Interval.surfaceSize c + blockSize yes)) env no k env' →
        ReachExpr T key env (.ite c yes no) k env'
    | elseIfCond {key env c yes no k env'} : ReachExpr T (advance key 1) env c k env' →
        ReachExpr T key env (.elseIf c yes no) k env'
    | elseIfYes {key env c yes no k env'} :
        ReachBlock T (advance key (1 + Interval.surfaceSize c)) env yes k env' →
        ReachExpr T key env (.elseIf c yes no) k env'
    | elseIfNo {key env c yes no k env'} :
        ReachExpr T (advance key (1 + Interval.surfaceSize c + blockSize yes)) env no k env' →
        ReachExpr T key env (.elseIf c yes no) k env'
    | ifOnlyCond {key env c yes k env'} : ReachExpr T (advance key 1) env c k env' →
        ReachExpr T key env (.ifOnly c yes) k env'
    | ifOnlyYes {key env c yes k env'} :
        ReachBlock T (advance key (1 + Interval.surfaceSize c)) env yes k env' →
        ReachExpr T key env (.ifOnly c yes) k env'
    | matchScrut {key env ty s arms k env'} : ReachExpr T (advance key 1) env s k env' →
        ReachExpr T key env (.matchE ty s arms) k env'
    | matchArms {key env ty s arms k env'} :
        ReachArms T (scrutIndex s) (advance key (1 + Interval.surfaceSize s)) env arms k env' →
        ReachExpr T key env (.matchE ty s arms) k env'
    | lam {key env names params ret eff body env0 k env'} : ReachBlock T (advance key 1) env0 body k env' →
        ReachExpr T key env (.lam names params ret eff body) k env'
    | lazyE {key env body env0 k env'} : ReachBlock T (advance key 1) env0 body k env' →
        ReachExpr T key env (.lazyE body) k env'
    | handleBody {key env body clauses k env'} : ReachBlock T (advance key 1) env body k env' →
        ReachExpr T key env (.handleE body clauses) k env'
    | handleClauses {key env body clauses k env'} :
        ReachClauses T (advance key (1 + blockSize body)) clauses k env' →
        ReachExpr T key env (.handleE body clauses) k env'
    | failBody {key env error result body clause k env'} : ReachBlock T (advance key 1) env body k env' →
        ReachExpr T key env (.handleFail error result body clause) k env'
    | failClause {key env error result body clause env0 k env'} :
        ReachBlock T (advance key (1 + blockSize body)) env0 clause k env' →
        ReachExpr T key env (.handleFail error result body clause) k env'
    | withExpr {key env o e body k env'} : ReachExpr T (advance key 1) env e k env' →
        ReachExpr T key env (.withE o e body) k env'
    | withBody {key env o e body v k env'} :
        ReachBlock T (advance key (1 + Interval.surfaceSize e)) (v :: env) body k env' →
        ReachExpr T key env (.withE o e body) k env'

  inductive ReachExprs (T : ScopeTable Release.Val) : Key → Locals → Exprs → Key → Locals → Prop where
    | head {key env e es k env'} : ReachExpr T key env e k env' → ReachExprs T key env (.cons e es) k env'
    | tail {key env e es k env'} : ReachExprs T (advance key (Interval.surfaceSize e)) env es k env' →
        ReachExprs T key env (.cons e es) k env'

  /-- 文の並びの評価の中で、番号 k の文の始まりへ局所 env' で到達する。先の文は正常に終わったものとし、束縛は
  右辺の具体の評価（`RhsEval`）の値を置く。 -/
  inductive ReachBlock (T : ScopeTable Release.Val) : Key → Locals → Block → Key → Locals → Prop where
    | here {key env b e} : blockRhs? b = some e → ReachBlock T key env b key env
    | rhs {key env b e k env'} : blockRhs? b = some e → ReachExpr T key env e k env' → ReachBlock T key env b k env'
    | builder {key env kind rest k env'} : ReachBlock T key (none :: env) rest k env' →
        ReachBlock T key env (.builderBind kind rest) k env'
    | bind {key env kind ty e rest v k env'} : RhsEval T key env e v →
        ReachBlock T (advance key (Interval.surfaceSize e)) (v :: env) rest k env' →
        ReachBlock T key env (.bind kind ty e rest) k env'
    | discard {key env e rest k env'} : ReachBlock T (advance key (Interval.surfaceSize e)) env rest k env' →
        ReachBlock T key env (.discard e rest) k env'
    | seq {key env e rest k env'} : ReachBlock T (advance key (Interval.surfaceSize e)) env rest k env' →
        ReachBlock T key env (.seq e rest) k env'
    | bindPat {key env kind pat ty e rest vals k env'} : vals.length = pat.binders →
        ReachBlock T (advance key (Interval.surfaceSize e)) (vals ++ env) rest k env' →
        ReachBlock T key env (.bindPat kind pat ty e rest) k env'

  inductive ReachArms (T : ScopeTable Release.Val) : Option Nat → Key → Locals → Arms → Key → Locals → Prop where
    | guard {scrut key env alts g body rest envA k env'} : ArmEnter env scrut alts envA →
        ReachExpr T key envA g k env' → ReachArms T scrut key env (.cons alts (some g) body rest) k env'
    | body {scrut key env alts guard body rest envA k env'} : ArmEnter env scrut alts envA →
        ReachBlock T (advance key (guardSize guard)) envA body k env' →
        ReachArms T scrut key env (.cons alts guard body rest) k env'
    | next {scrut key env alts guard body rest k env'} :
        ReachArms T scrut (advance key (guardSize guard + blockSize body)) env rest k env' →
        ReachArms T scrut key env (.cons alts guard body rest) k env'

  /-- 節の本体の局所は任意である（継続・引数・辞書・捕捉の位置）。 -/
  inductive ReachClauses (T : ScopeTable Release.Val) : Key → Clauses → Key → Locals → Prop where
    | body {key op arity ntys body rest dictCount env0 k env'} : ReachBlock T key env0 body k env' →
        ReachClauses T key (.cons op arity ntys body rest dictCount) k env'
    | next {key op arity ntys body rest dictCount k env'} :
        ReachClauses T (advance key (blockSize body)) rest k env' →
        ReachClauses T key (.cons op arity ntys body rest dictCount) k env'
end

/-! ## 表層の評価と一段の具体の評価の対応 -/

/-- 二つの列の要素ごとの関係。 -/
inductive ListRel {α β : Type} (R : α → β → Prop) : List α → List β → Prop where
  | nil : ListRel R [] []
  | cons {x y xs ys} : R x y → ListRel R xs ys → ListRel R (x :: xs) (y :: ys)

section Correspondence

variable {ok : Release.ConName} {T : ScopeTable Release.Val}

/-- 引数の具体の評価は、その一段の式の具体の評価である。 -/
theorem argEval_lower {key : Key} {env : Locals} {e : Expr} {v : Release.Val} (h : ArgEval T key env e v) :
    EvalArg T env (lowerArg key e) v := by
  cases h with
  | str hc =>
    rename_i s
    have : argForm e = .str s := by simp [argForm, hc]
    simp only [lowerArg, this]; exact .lit _
  | int hc =>
    rename_i n
    have : argForm e = .int n := by simp [argForm, hc]
    simp only [lowerArg, this]; exact .int _
  | loc found => exact .loc _ _ found
  | projStd hf found eval => simp only [lowerArg, hf]; exact .proj _ _ _ _ _ found eval
  | projOther hf missing => simp only [lowerArg, hf]; exact .projOther _ _ _ missing
  | other hf => simp only [lowerArg, hf]; exact .other _

theorem argEvals_lower {env : Locals} {key : Key} {es : Exprs} {vals : List Release.Val}
    (h : ArgEvals T env key es vals) : ListRel (EvalArg T env) (lowerArgs key es) vals := by
  induction h with
  | nil => exact .nil
  | cons ha _ ih => exact .cons (argEval_lower ha) ih

theorem fieldAt_forall₂ {α β : Type} {R : α → β → Prop} {xs : List α} {ys : List β} (h : ListRel R xs ys)
    (j : Nat) (positions : List Nat) :
    (fieldAt j positions xs = none ∧ fieldAt j positions ys = none) ∨
      ∃ x y, fieldAt j positions xs = some x ∧ fieldAt j positions ys = some y ∧ R x y := by
  induction positions generalizing xs ys with
  | nil => left; cases xs <;> cases ys <;> simp [fieldAt]
  | cons p ps ih =>
    cases h with
    | nil => left; simp [fieldAt]
    | cons hxy rest =>
      simp only [fieldAt]
      by_cases hj : j = p
      · rw [ite_eq_left hj, ite_eq_left hj]; exact .inr ⟨_, _, rfl, rfl, hxy⟩
      · rw [ite_eq_right hj, ite_eq_right hj]; exact ih rest

theorem pick_forall₂ {α β : Type} {R : α → β → Prop} {xs : List α} {ys : List β} (h : ListRel R xs ys)
    (positions : List Nat) (js : List Nat) :
    (pick positions xs js = none ∧ pick positions ys js = none) ∨
      ∃ as bs, pick positions xs js = some as ∧ pick positions ys js = some bs ∧ ListRel R as bs := by
  induction js with
  | nil => exact .inr ⟨[], [], rfl, rfl, .nil⟩
  | cons j js ih =>
    simp only [pick]
    rcases fieldAt_forall₂ h j positions with ⟨hx, hy⟩ | ⟨x, y, hx, hy, hr⟩
    · left; simp [hx, hy]
    · rw [hx, hy]
      rcases ih with ⟨ha, hb⟩ | ⟨as, bs, ha, hb, hab⟩
      · left; simp [ha, hb]
      · right; rw [ha, hb]; exact ⟨_, _, rfl, rfl, .cons hr hab⟩

theorem evalArgs_of_forall₂ {env : Locals} {xs : List Arg} {vs : List Release.Val}
    (h : ListRel (EvalArg T env) xs vs) : EvalArgs T env xs vs := by
  induction h with
  | nil => exact .nil
  | cons ha _ ih => exact .cons ha ih

/-- 契約の順への並べ替えは、引数と値の対応を保つ。 -/
theorem contractOrder_evalArgs {env : Locals} {positions : List Nat} {xs : List Arg} {vals vs : List Release.Val}
    (h : ListRel (EvalArg T env) xs vals) (hv : contractOrder positions vals = some vs) :
    ∃ ys, contractOrder positions xs = some ys ∧ EvalArgs T env ys vs := by
  unfold contractOrder at hv ⊢
  rcases pick_forall₂ h positions (List.range positions.length) with ⟨_, hb⟩ | ⟨as, bs, ha, hb, hab⟩
  · rw [hb] at hv; cases hv
  · rw [hb] at hv; cases hv
    exact ⟨as, ha, evalArgs_of_forall₂ hab⟩

theorem rhsStep_other {key : Key} {e : Expr} (h : callOrLocal e = false) : rhsStep key e = .unknown := by
  cases e <;> simp_all [callOrLocal, rhsStep]

/-- 右辺の具体の評価は、その一段の具体の評価である（対応の健全性の中心の補題）。 -/
theorem rhsEval_step {key : Key} {env : Locals} {e : Expr} {v : Option Release.Val} (h : RhsEval T key env e v) :
    StepEval ok T env (rhsStep key e) (v :: env) := by
  cases h with
  | callStd hd hargs hord heval =>
    rename_i callee labels positions args _ _ _ _
    obtain ⟨ys, hys, hev⟩ := contractOrder_evalArgs (argEvals_lower hargs) hord
    have hstep : rhsStep key (.call callee labels positions args) = .call key ys := by simp [rhsStep, hd, hys]
    rw [hstep]
    exact .callStd hev heval
  | callOther missing =>
    simp only [rhsStep]
    split
    · split
      · exact .callOther missing
      · exact .unknown
    · exact .unknown
  | indirect hd =>
    simp only [rhsStep, hd]
    exact .unknown
  | alias found => exact .alias found
  | other hc => rw [rhsStep_other hc]; exact .unknown

theorem stepsEval_append {env env' env'' : Locals} {ss ts : List Step}
    (h1 : StepsEval ok T env ss env') (h2 : StepsEval ok T env' ts env'') : StepsEval ok T env (ss ++ ts) env'' := by
  induction h1 with
  | nil => exact h2
  | cons h hs ih => exact .cons h (ih h2)

/-- 任意の値の列を、同じ数の未知の一段で積む。 -/
theorem stepsEval_unknown (vals : List (Option Release.Val)) (env : Locals) :
    StepsEval ok T env (List.replicate vals.length .unknown) (vals ++ env) := by
  induction vals with
  | nil => exact .nil
  | cons v vals ih =>
    rw [List.length_cons, List.replicate_succ', List.cons_append]
    exact stepsEval_append ih (.cons .unknown .nil)

/-- 腕の入口の具体の束縛は、入口の一段の具体の評価である。 -/
theorem armEnter_steps {env envA : Locals} {scrut : Option Nat} {alts : List Alternative}
    (h : ArmEnter env scrut alts envA) : StepsEval ok T env (armEntry ok scrut alts) envA := by
  cases h with
  | con hc found =>
    rename_i i c tys w
    simp only [armEntry, hc]
    by_cases hok : c = ok
    · rw [ite_eq_left hok]
      subst hok
      exact .cons (.okArm found (by simp [okPayload])) .nil
    · rw [ite_eq_right hok]
      exact .cons .unknown .nil
  | other hc hlen =>
    rename_i vals
    simp only [armEntry, hc, ← hlen]
    exact stepsEval_unknown vals env

end Correspondence

/-! ## 合流と境界の対応 -/

theorem rejoin_models {M : FactModels Release.Val} {outer : Run} {env : Locals} (hm : outer.state.Models M env)
    (inner : Run) : (rejoin outer inner).state.Models M env := by
  unfold rejoin
  cases inner with
  | running _ b => cases outer <;> exact hm
  | stopped f _ b => exact ScopeState.forgetAll_models M _ env

theorem rejoin_good {outer : Run} (h : outer.Good) (inner : Run) : (rejoin outer inner).Good := by
  unfold rejoin
  cases inner with
  | running _ b => cases outer <;> exact h
  | stopped f _ b => exact noFacts_forgetAll _

section Analysis

variable {ok : Release.ConName} {T : ScopeTable Release.Val} {L : Limits}

/-- 式の解析の結果の状態は、外側の状態が対応する局所に対応する。 -/
theorem analyzeExpr_models {M : FactModels Release.Val} {key : Key} {r : Run} {env : Locals}
    (hm : r.state.Models M env) (e : Expr) : (analyzeExpr ok T L key r e).1.state.Models M env := by
  cases e <;> simp only [analyzeExpr] <;>
    first
    | exact rejoin_models hm _
    | exact Run.leave_models hm _
    | exact hm

theorem analyzeExprs_models {M : FactModels Release.Val} {key : Key} {r : Run} {env : Locals}
    (hm : r.state.Models M env) (es : Exprs) : (analyzeExprs ok T L key r es).1.state.Models M env := by
  cases es <;> simp only [analyzeExprs]
  · exact hm
  · exact rejoin_models hm _

variable {P : Parsers}

mutual
  /-- 式の内側の到達した文の始まりには、その地点の具体の局所に対応する記録がある。 -/
  theorem reachExpr_sound (hT : TableSound (models ok P) T) {key : Key} {env : Locals} {e : Expr} {k : Key}
      {env' : Locals} (h : ReachExpr T key env e k env') (r : Run) (hm : r.state.Models (models ok P) env) :
      ∃ st, (k, st) ∈ (analyzeExpr ok T L key r e).2 ∧ st.Models (models ok P) env' := by
    match h with
    | .paren h' | .returnE h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      exact ⟨st, by simpa [analyzeExpr] using hmem, hst⟩
    | .callee h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .args h' =>
      rename_i callee _ _ _
      obtain ⟨st, hmem, hst⟩ := reachExprs_sound hT h' (rejoin r (analyzeExpr ok T L (advance key 1) r callee).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .block h' =>
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' r hm
      exact ⟨st, by simpa [analyzeExpr] using hmem, hst⟩
    | .iteCond h' | .elseIfCond h' | .ifOnlyCond h' | .matchScrut h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .iteYes h' =>
      rename_i c _ _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' (rejoin r (analyzeExpr ok T L (advance key 1) r c).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .elseIfYes h' =>
      rename_i c _ _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' (rejoin r (analyzeExpr ok T L (advance key 1) r c).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .ifOnlyYes h' =>
      rename_i c _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' (rejoin r (analyzeExpr ok T L (advance key 1) r c).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .iteNo h' =>
      rename_i c yes _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h'
        (rejoin r (analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .elseIfNo h' =>
      rename_i c yes _
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h'
        (rejoin r (analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .matchArms h' =>
      rename_i _ sc _
      obtain ⟨st, hmem, hst⟩ := reachArms_sound hT h' (rejoin r (analyzeExpr ok T L (advance key 1) r sc).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .lam h' | .lazyE h' =>
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ (Run.enter_models _ _ r _)
      exact ⟨st, by simpa [analyzeExpr] using hmem, hst⟩
    | .handleBody h' | .failBody h' =>
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' (r.enter r.state.scope) (Run.enter_models _ _ r _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .handleClauses h' =>
      rename_i body _
      obtain ⟨st, hmem, hst⟩ := reachClauses_sound hT h'
        (r.leave (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .failClause h' =>
      rename_i _ _ body _ _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h'
        ((r.leave (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1).enter
          (freshN 2 (r.leave (analyzeBlock ok T L (advance key 1) (r.enter r.state.scope) body).1).state.scope))
        (Run.enter_models _ _ _ _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .withExpr h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .withBody h' =>
      rename_i _ e _ v
      have hs := Run.step_models (ok := ok) hT L
        (rejoin_models hm (analyzeExpr ok T L (advance key 1) r e).1) (StepEval.unknown (T := T) (v := v))
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hs
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩

  theorem reachExprs_sound (hT : TableSound (models ok P) T) {key : Key} {env : Locals} {es : Exprs} {k : Key}
      {env' : Locals} (h : ReachExprs T key env es k env') (r : Run) (hm : r.state.Models (models ok P) env) :
      ∃ st, (k, st) ∈ (analyzeExprs ok T L key r es).2 ∧ st.Models (models ok P) env' := by
    match h with
    | .head h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      exact ⟨st, by simp [analyzeExprs, hmem], hst⟩
    | .tail h' =>
      rename_i e _
      obtain ⟨st, hmem, hst⟩ := reachExprs_sound hT h' (rejoin r (analyzeExpr ok T L key r e).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExprs, hmem], hst⟩

  /-- 文の並びの中の到達した文の始まりには、その地点の具体の局所に対応する記録がある。 -/
  theorem reachBlock_sound (hT : TableSound (models ok P) T) {key : Key} {env : Locals} {b : Block} {k : Key}
      {env' : Locals} (h : ReachBlock T key env b k env') (r : Run) (hm : r.state.Models (models ok P) env) :
      ∃ st, (k, st) ∈ (analyzeBlock ok T L key r b).2 ∧ st.Models (models ok P) env' := by
    match h with
    | .here hb =>
      refine ⟨r.state, ?_, hm⟩
      cases b <;> simp_all [blockRhs?, analyzeBlock]
    | .rhs hb h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      refine ⟨st, ?_, hst⟩
      cases b <;> simp only [blockRhs?, Option.some.injEq, reduceCtorEq] at hb <;> subst hb <;>
        simp [analyzeBlock, hmem]
    | .builder h' =>
      have hs := Run.step_models (ok := ok) hT L hm (StepEval.unknown (T := T) (v := none))
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hs
      exact ⟨st, by simpa [analyzeBlock] using hmem, hst⟩
    | .bind hrhs h' =>
      rename_i _ _ e _ _
      have hs := Run.step_models hT L (analyzeExpr_models (ok := ok) (T := T) (L := L) (key := key) hm e)
        (rhsEval_step (ok := ok) hrhs)
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hs
      exact ⟨st, by simp [analyzeBlock, hmem], hst⟩
    | .discard h' | .seq h' =>
      rename_i e _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _
        (analyzeExpr_models (ok := ok) (T := T) (L := L) (key := key) hm e)
      exact ⟨st, by simp [analyzeBlock, hmem], hst⟩
    | .bindPat hlen h' =>
      rename_i _ _ _ e _ vals
      have hsteps : StepsEval ok T env (List.replicate _ .unknown) (vals ++ env) := hlen ▸ stepsEval_unknown vals env
      have hs := Run.steps_models hT L (analyzeExpr_models (ok := ok) (T := T) (L := L) (key := key) hm e) hsteps
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hs
      exact ⟨st, by simp [analyzeBlock, hmem], hst⟩

  theorem reachArms_sound (hT : TableSound (models ok P) T) {scrut : Option Nat} {key : Key} {env : Locals}
      {arms : Arms} {k : Key} {env' : Locals} (h : ReachArms T scrut key env arms k env') (r : Run)
      (hm : r.state.Models (models ok P) env) :
      ∃ st, (k, st) ∈ (analyzeArms ok T L scrut key r arms).2 ∧ st.Models (models ok P) env' := by
    match h with
    | .guard henter h' =>
      have ha := Run.steps_models hT L hm (armEnter_steps (ok := ok) henter)
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' _ ha
      exact ⟨st, by rw [analyzeArms_cons]; simp [guardRun, hmem], hst⟩
    | .body henter h' =>
      rename_i alts guard _ _ envA
      have ha := Run.steps_models hT L hm (armEnter_steps (ok := ok) henter)
      have hg : (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1.state.Models
          (models ok P) envA := by
        cases guard with
        | none => exact ha
        | some e => exact analyzeExpr_models ha e
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hg
      exact ⟨st, by rw [analyzeArms_cons]; simp [hmem], hst⟩
    | .next h' =>
      rename_i alts guard body _
      obtain ⟨st, hmem, hst⟩ := reachArms_sound hT h'
        (rejoin r (analyzeBlock ok T L (advance key (guardSize guard))
          (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1 body).1) (rejoin_models hm _)
      exact ⟨st, by rw [analyzeArms_cons]; simp [hmem], hst⟩

  theorem reachClauses_sound (hT : TableSound (models ok P) T) {key : Key} {clauses : Clauses} {k : Key}
      {env' : Locals} (h : ReachClauses T key clauses k env') (r : Run) :
      ∃ st, (k, st) ∈ (analyzeClauses ok T L key r clauses).2 ∧ st.Models (models ok P) env' := by
    match h with
    | .body h' =>
      rename_i _ arity _ _ _ dictCount _
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' (r.enter (freshN (1 + arity + dictCount) r.state.scope))
        (Run.enter_models _ _ r _)
      exact ⟨st, by simp [analyzeClauses, hmem], hst⟩
    | .next h' =>
      rename_i _ arity _ body _ dictCount
      obtain ⟨st, hmem, hst⟩ := reachClauses_sound hT h'
        (r.leave (analyzeBlock ok T L key (r.enter (freshN (1 + arity + dictCount) r.state.scope)) body).1)
      exact ⟨st, by simp [analyzeClauses, hmem], hst⟩
end

/-- 関数の本体の解析の健全性。本体の評価が番号 k の文の始まりへ局所 env' で到達するなら、その地点の記録は env' に
対応する（上限の値によらず、超過して Top を返す場合を含む）。 -/
theorem analyzeBody_sound (hT : TableSound (models ok P) T) {key : Key} {scope : Interval.BindingScope}
    {body : Block} {env : Locals} {k : Key} {env' : Locals} (h : ReachBlock T key env body k env') :
    ∃ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧ st.Models (models ok P) env' :=
  reachBlock_sound hT h _ (ScopeState.empty_models _ _ _)

/-- 必須の判定の健全性（表層の版）。到達した文の始まりの記録が Top でない添字を付けた位置の値は、その範囲に属する
対象を保持する値（検査済みの対象の値か検査済みの要求の値）である。 -/
theorem analyzeBody_requiredIndex (hT : TableSound (models ok P) T) {key : Key} {scope : Interval.BindingScope}
    {body : Block} {env : Locals} {k : Key} {env' : Locals} (h : ReachBlock T key env body k env') :
    ∃ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
      ∀ i v, env'[i]? = some (some v) → st.requiredIndex i ≠ .top →
        ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t := by
  obtain ⟨st, hmem, hst⟩ := analyzeBody_sound (L := L) hT h (scope := scope)
  refine ⟨st, hmem, fun i v found hne => ?_⟩
  obtain ⟨_, t, ht, -, -, hmt⟩ := requiredIndex_checked hst found hne
  exact ⟨t, ht, hmt⟩

end Analysis

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

theorem numbered_absStep (T : ScopeTable Release.Val) {st : ScopeState} (h : Numbered st) (s : Step) :
    Numbered (absStep T st s) := by
  cases s <;> first | exact numbered_extend h _ | exact numbered_forgetAll h

theorem numbered_blindStep {st : ScopeState} (h : Numbered st) (s : Step) : Numbered (blindStep st s) := by
  cases s <;> first | exact numbered_extend h _ | exact numbered_forgetAll h

theorem numbered_step (T : ScopeTable Release.Val) (L : Limits) {r : Run} (h : Numbered r.state) (s : Step) :
    Numbered (r.step T L s).state := by
  cases r with
  | running st b =>
    simp only [Run.step]
    split
    · exact numbered_absStep T h s
    · exact numbered_blindStep (numbered_forgetAll h) s
  | stopped f st b => exact numbered_blindStep h s

theorem numbered_steps (T : ScopeTable Release.Val) (L : Limits) :
    ∀ (ss : List Step) {r : Run}, Numbered r.state → Numbered (r.steps T L ss).state
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

variable {ok : Release.ConName} {T : ScopeTable Release.Val} {L : Limits}

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
      have h2 := analyzeBlock_numbered (advance key (1 + Interval.surfaceSize c))
        (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) (numbered_rejoin h _) yes
      have h3 := analyzeBlock_numbered (advance key (1 + Interval.surfaceSize c + blockSize yes))
        (rejoin r (analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (numbered_rejoin h _) no
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 (allNumbered_append h2.2 h3.2)⟩
    | .elseIf c yes no =>
      have h1 := analyzeExpr_numbered (advance key 1) r h c
      have h2 := analyzeBlock_numbered (advance key (1 + Interval.surfaceSize c))
        (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) (numbered_rejoin h _) yes
      have h3 := analyzeExpr_numbered (advance key (1 + Interval.surfaceSize c + blockSize yes))
        (rejoin r (analyzeBlock ok T L (advance key (1 + Interval.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (numbered_rejoin h _) no
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 (allNumbered_append h2.2 h3.2)⟩
    | .ifOnly c yes =>
      have h1 := analyzeExpr_numbered (advance key 1) r h c
      have h2 := analyzeBlock_numbered (advance key (1 + Interval.surfaceSize c))
        (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) (numbered_rejoin h _) yes
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .matchE _ sc arms =>
      have h1 := analyzeExpr_numbered (advance key 1) r h sc
      have h2 := analyzeArms_numbered (scrutIndex sc) (advance key (1 + Interval.surfaceSize sc))
        (rejoin r (analyzeExpr ok T L (advance key 1) r sc).1) (numbered_rejoin h _) arms
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
      have h2 := analyzeBlock_numbered (advance key (1 + Interval.surfaceSize e))
        ((rejoin r (analyzeExpr ok T L (advance key 1) r e).1).step T L .unknown)
        (numbered_step T L (numbered_rejoin h _) .unknown) body
      simp only [analyzeExpr]
      exact ⟨numbered_rejoin h _, allNumbered_append h1.2 h2.2⟩
    | .local _ | .builderOp _ _ _ _ | .constE _ _ | .funName _ _ _ | .funDicts _ _ _ _ _ _
    | .methName _ _ _ _ _ _ _ | .primName _ _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _ | .negDecimal _ _
    | .negInteger8 _ | .negInteger16 _ | .negInteger32 _ | .negFloat32 _ | .unit | .conCall _ _ _
    | .record _ _ _ _ | .recordUpdate _ _ _ _ _ _ | .pipe _ _ | .partialCall _ _ _ _ _ | .partialCon _ _ _
    | .binary _ _ _ _ | .neg _ _ | .not _ | .and _ _ | .or _ _ | .list _ _ | .listSpread _ _ _ _ _
    | .interpolation _ _ _ | .tryResult _ _ _ _ | .tryOption _ _ _ _ | .tryResultDie _ _ _ _ _ _ _ _
    | .tryOptionDie _ _ _ _ _ _ | .resume _ _ =>
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
      have h2 := analyzeExprs_numbered (advance key (Interval.surfaceSize e))
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
      have h2 := analyzeBlock_numbered (advance key (Interval.surfaceSize e))
        ((analyzeExpr ok T L key r e).1.step T L (rhsStep key e)) (numbered_step T L h1.1 (rhsStep key e)) rest
      simp only [analyzeBlock]
      exact ⟨h2.1, allNumbered_cons h (allNumbered_append h1.2 h2.2)⟩
    | .discard e rest | .seq e rest =>
      have h1 := analyzeExpr_numbered key r h e
      have h2 := analyzeBlock_numbered (advance key (Interval.surfaceSize e)) (analyzeExpr ok T L key r e).1 h1.1 rest
      simp only [analyzeBlock]
      exact ⟨h2.1, allNumbered_cons h (allNumbered_append h1.2 h2.2)⟩
    | .bindPat _ pat _ e rest =>
      have h1 := analyzeExpr_numbered key r h e
      have h2 := analyzeBlock_numbered (advance key (Interval.surfaceSize e))
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
      have hg : Numbered (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1.state ∧
          AllNumbered (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).2 := by
        match guard with
        | none =>
          simp only [guardRun]
          exact ⟨ha, allNumbered_nil⟩
        | some g =>
          simp only [guardRun]
          exact analyzeExpr_numbered key _ ha g
      have h2 := analyzeBlock_numbered (advance key (guardSize guard))
        (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1 hg.1 body
      have h3 := analyzeArms_numbered scrut (advance key (guardSize guard + blockSize body))
        (rejoin r (analyzeBlock ok T L (advance key (guardSize guard))
          (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1 body).1) (numbered_rejoin h _) rest
      rw [analyzeArms_cons]
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

end Benitoite.Surface.ScopeLower
