import Benitoite.Release.Refinement.Surface.ScopeEval
import Benitoite.Release.Refinement.Surface.ScopeAccept

/-!
# 表層の具体の評価と Scope の局所解析の健全性

型の情報を付けた表層の構文の上に、文の始まりへ到達する具体の評価（`ReachAtBlock`。到達した文の右辺を添字に持つ）を
置き、局所解析が文の始まりに記録した状態がその地点の具体の局所の値に対応することを示す（`analyzeBody_sound`）。
必須の判定が Top でない添字を付けた位置の値は、その範囲に属する対象を保持する（`analyzeBody_requiredIndex`）。
到達した文の右辺は、本体の出現の一覧の同じ番号にある（`reachAt_occurrences`）
（設計書 01-12「Scope の局所解析の表層からの対応」「Scope の局所解析の接続定理」）。

- 引数（`ArgEval`）: リテラルと `const` の直接参照はその定数、局所の参照はその値、射影の形の呼び出しは表の規則で
  評価する（同定されなければ任意の値）。それ以外の式は値を読まない（任意の値）。
- 右辺（`RhsEval`）: 同定された直接の呼び出しは契約の順の引数で表の規則を評価し、局所の参照はその値を返す。
  それ以外は任意の値を返してよい。
- 腕の入口（`ArmEnter`）: 局所の値の一つの選択肢 `C(p)` の腕は、その値が構成子 C の値のときだけ入り、引数を束縛する。
  照合の腕の文脈は照合する値を一つ束縛した上に置く（任意の値）。
- 境界: ラムダ・遅延・handle の保護本体と節・失敗の節の入口の局所は任意である。

表層の具体の評価は脱糖と核の実行とは独立の関係であり、両者の一致は結論しない。核の実行の形との接続は、規則の実行を
本番の δ にした表で、同じ範囲の列を持つ核の組み込みの呼び出しが E_Prim で同じ値へ進むことで述べる
（`Surface.ScopeConnection`）。
-/

namespace Benitoite.Release.Refinement.Surface.ScopeLower

open Benitoite.Scope.Inference
open Benitoite.Release.Refinement.Surface.ScopeState
open Benitoite.Release.Refinement.Surface.ScopeAccept
open Benitoite.Scope.Domain (Range Target)

/-! ## 表層の具体の評価 -/

/-- 引数の具体の評価。 -/
inductive ArgEval (T : ScopeTable Refinement.Val) (key : Key) (env : Locals) : Expr → Refinement.Val → Prop where
  | str {e s} : constArg? e = some (.str s) → ArgEval T key env e (.const (.string s))
  | int {e n} : constArg? e = some (.int n) → ArgEval T key env e (.const (.integer n))
  | loc {i v} : env[i]? = some (some v) → ArgEval T key env (.local i) v
  | projStd {e i w rs v} : argForm e = .proj i → env[i]? = some (some w) → EvalScope T key rs [w] v →
      ArgEval T key env e v
  | projOther {e i v} : argForm e = .proj i → T.ruleAt key = none → ArgEval T key env e v
  | other {e v} : argForm e = .other → ArgEval T key env e v

/-- ソース順の引数の具体の評価。 -/
inductive ArgEvals (T : ScopeTable Refinement.Val) (env : Locals) : Key → Exprs → List Refinement.Val → Prop where
  | nil {key} : ArgEvals T env key .nil []
  | cons {key e es v vs} : ArgEval T key env e v →
      ArgEvals T env (advance key (Identity.surfaceSize e)) es vs → ArgEvals T env key (.cons e es) (v :: vs)

/-- 直接の呼び出しと局所の参照かどうか。 -/
def callOrLocal : Expr → Bool
  | .call _ _ _ _ | .local _ => true
  | _ => false

/-- 束縛の右辺の具体の評価（束縛する値）。 -/
inductive RhsEval (T : ScopeTable Refinement.Val) (key : Key) (env : Locals) : Expr → Option Refinement.Val → Prop where
  | callStd {callee labels positions args vals vs rs v} : directHead callee = true →
      ArgEvals T env (argsKey key callee) args vals → contractOrder positions vals = some vs →
      EvalScope T key rs vs v → RhsEval T key env (.call callee labels positions args) (some v)
  | callOther {callee labels positions args v} : T.ruleAt key = none →
      RhsEval T key env (.call callee labels positions args) (some v)
  | indirect {callee labels positions args v} : directHead callee = false →
      RhsEval T key env (.call callee labels positions args) v
  | alias {i v} : env[i]? = some (some v) → RhsEval T key env (.local i) (some v)
  | other {e v} : callOrLocal e = false → RhsEval T key env e v

/-- 腕の入口の具体の束縛。 -/
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
  /-- 式の評価の中で、番号 k の文の始まりへ局所 env' で到達し、その文の右辺が x である。本体（ラムダ・遅延・節）の
  入口の局所は任意である。 -/
  inductive ReachAtExpr (T : ScopeTable Refinement.Val) : Key → Locals → Expr → Key → Locals → Expr → Prop where
    | paren {key env e k env' x} : ReachAtExpr T (advance key 1) env e k env' x →
        ReachAtExpr T key env (.paren e) k env' x
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
        ReachAtBlock T (advance key (1 + Identity.surfaceSize c)) env yes k env' x →
        ReachAtExpr T key env (.ite c yes no) k env' x
    | iteNo {key env c yes no k env' x} :
        ReachAtBlock T (advance key (1 + Identity.surfaceSize c + blockSize yes)) env no k env' x →
        ReachAtExpr T key env (.ite c yes no) k env' x
    | elseIfCond {key env c yes no k env' x} : ReachAtExpr T (advance key 1) env c k env' x →
        ReachAtExpr T key env (.elseIf c yes no) k env' x
    | elseIfYes {key env c yes no k env' x} :
        ReachAtBlock T (advance key (1 + Identity.surfaceSize c)) env yes k env' x →
        ReachAtExpr T key env (.elseIf c yes no) k env' x
    | elseIfNo {key env c yes no k env' x} :
        ReachAtExpr T (advance key (1 + Identity.surfaceSize c + blockSize yes)) env no k env' x →
        ReachAtExpr T key env (.elseIf c yes no) k env' x
    | ifOnlyCond {key env c yes k env' x} : ReachAtExpr T (advance key 1) env c k env' x →
        ReachAtExpr T key env (.ifOnly c yes) k env' x
    | ifOnlyYes {key env c yes k env' x} :
        ReachAtBlock T (advance key (1 + Identity.surfaceSize c)) env yes k env' x →
        ReachAtExpr T key env (.ifOnly c yes) k env' x
    | matchScrut {key env ty s arms k env' x} : ReachAtExpr T (advance key 1) env s k env' x →
        ReachAtExpr T key env (.matchE ty s arms) k env' x
    /-- 腕の文脈は、照合する値（任意の値）を一つ束縛した上に置く。 -/
    | matchArms {key env ty s arms v k env' x} :
        ReachAtArms T (scrutIndex s) (advance key (1 + Identity.surfaceSize s)) (v :: env) arms k env' x →
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
        ReachAtBlock T (advance key (1 + Identity.surfaceSize e)) (v :: env) body k env' x →
        ReachAtExpr T key env (.withE o e body) k env' x

  inductive ReachAtExprs (T : ScopeTable Refinement.Val) : Key → Locals → Exprs → Key → Locals → Expr → Prop where
    | head {key env e es k env' x} : ReachAtExpr T key env e k env' x → ReachAtExprs T key env (.cons e es) k env' x
    | tail {key env e es k env' x} : ReachAtExprs T (advance key (Identity.surfaceSize e)) env es k env' x →
        ReachAtExprs T key env (.cons e es) k env' x

  /-- 文の並びの評価の中で、番号 k の文の始まりへ局所 env' で到達する。先の文は正常に終わったものとし、束縛は
  右辺の具体の評価（`RhsEval`）の値を置く。`here` は到達した文の右辺を添字に置く。 -/
  inductive ReachAtBlock (T : ScopeTable Refinement.Val) : Key → Locals → Block → Key → Locals → Expr → Prop where
    | here {key env b e} : blockRhs? b = some e → ReachAtBlock T key env b key env e
    | rhs {key env b e k env' x} : blockRhs? b = some e → ReachAtExpr T key env e k env' x →
        ReachAtBlock T key env b k env' x
    | builder {key env kind rest k env' x} : ReachAtBlock T key (none :: env) rest k env' x →
        ReachAtBlock T key env (.builderBind kind rest) k env' x
    | bind {key env kind ty e rest v k env' x} : RhsEval T key env e v →
        ReachAtBlock T (advance key (Identity.surfaceSize e)) (v :: env) rest k env' x →
        ReachAtBlock T key env (.bind kind ty e rest) k env' x
    | discard {key env e rest k env' x} : ReachAtBlock T (advance key (Identity.surfaceSize e)) env rest k env' x →
        ReachAtBlock T key env (.discard e rest) k env' x
    | seq {key env e rest k env' x} : ReachAtBlock T (advance key (Identity.surfaceSize e)) env rest k env' x →
        ReachAtBlock T key env (.seq e rest) k env' x
    | bindPat {key env kind pat ty e rest vals k env' x} : vals.length = pat.binders →
        ReachAtBlock T (advance key (Identity.surfaceSize e)) (vals ++ env) rest k env' x →
        ReachAtBlock T key env (.bindPat kind pat ty e rest) k env' x

  inductive ReachAtArms (T : ScopeTable Refinement.Val) :
      Option Nat → Key → Locals → Arms → Key → Locals → Expr → Prop where
    | guard {scrut key env alts g body rest envA k env' x} : ArmEnter env scrut alts envA →
        ReachAtExpr T key envA g k env' x → ReachAtArms T scrut key env (.cons alts (some g) body rest) k env' x
    | body {scrut key env alts guard body rest envA k env' x} : ArmEnter env scrut alts envA →
        ReachAtBlock T (advance key (guardSize guard)) envA body k env' x →
        ReachAtArms T scrut key env (.cons alts guard body rest) k env' x
    | next {scrut key env alts guard body rest k env' x} :
        ReachAtArms T scrut (advance key (guardSize guard + blockSize body)) env rest k env' x →
        ReachAtArms T scrut key env (.cons alts guard body rest) k env' x

  /-- 節の本体の局所は任意である（継続・引数・辞書・捕捉の位置）。 -/
  inductive ReachAtClauses (T : ScopeTable Refinement.Val) : Key → Clauses → Key → Locals → Expr → Prop where
    | body {key op arity ntys body rest dictCount env0 k env' x} : ReachAtBlock T key env0 body k env' x →
        ReachAtClauses T key (.cons op arity ntys body rest dictCount) k env' x
    | next {key op arity ntys body rest dictCount k env' x} :
        ReachAtClauses T (advance key (blockSize body)) rest k env' x →
        ReachAtClauses T key (.cons op arity ntys body rest dictCount) k env' x
end

/-- 本体の評価が番号 k の文の始まりへ局所 env' で到達する（到達した文の右辺を問わない）。 -/
def ReachBlock (T : ScopeTable Refinement.Val) (key : Key) (env : Locals) (body : Block) (k : Key)
    (env' : Locals) : Prop :=
  ∃ x, ReachAtBlock T key env body k env' x

/-! ## 表層の評価と一段の具体の評価の対応 -/

/-- 二つの列の要素ごとの関係。 -/
inductive ListRel {α β : Type} (R : α → β → Prop) : List α → List β → Prop where
  | nil : ListRel R [] []
  | cons {x y xs ys} : R x y → ListRel R xs ys → ListRel R (x :: xs) (y :: ys)

section Correspondence

variable {ok : ConName} {T : ScopeTable Refinement.Val}

/-- 引数の具体の評価は、その一段の式の具体の評価である。 -/
theorem argEval_lower {key : Key} {env : Locals} {e : Expr} {v : Refinement.Val} (h : ArgEval T key env e v) :
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

theorem argEvals_lower {env : Locals} {key : Key} {es : Exprs} {vals : List Refinement.Val}
    (h : ArgEvals T env key es vals) : ListRel (EvalArg T env) (lowerArgs key es) vals := by
  induction h with
  | nil => exact .nil
  | cons ha _ ih => exact .cons (argEval_lower ha) ih

private theorem fieldAt_rel {α β : Type} {R : α → β → Prop} {xs : List α} {ys : List β} (h : ListRel R xs ys)
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

private theorem pick_rel {α β : Type} {R : α → β → Prop} {xs : List α} {ys : List β} (h : ListRel R xs ys)
    (positions : List Nat) (js : List Nat) :
    (pick positions xs js = none ∧ pick positions ys js = none) ∨
      ∃ as bs, pick positions xs js = some as ∧ pick positions ys js = some bs ∧ ListRel R as bs := by
  induction js with
  | nil => exact .inr ⟨[], [], rfl, rfl, .nil⟩
  | cons j js ih =>
    simp only [pick]
    rcases fieldAt_rel h j positions with ⟨hx, hy⟩ | ⟨x, y, hx, hy, hr⟩
    · left; simp [hx, hy]
    · rw [hx, hy]
      rcases ih with ⟨ha, hb⟩ | ⟨as, bs, ha, hb, hab⟩
      · left; simp [ha, hb]
      · right; rw [ha, hb]; exact ⟨_, _, rfl, rfl, .cons hr hab⟩

private theorem evalArgs_of_rel {env : Locals} {xs : List Arg} {vs : List Refinement.Val}
    (h : ListRel (EvalArg T env) xs vs) : EvalArgs T env xs vs := by
  induction h with
  | nil => exact .nil
  | cons ha _ ih => exact .cons ha ih

/-- 契約の順への並べ替えは、引数と値の対応を保つ。 -/
theorem contractOrder_evalArgs {env : Locals} {positions : List Nat} {xs : List Arg}
    {vals vs : List Refinement.Val}
    (h : ListRel (EvalArg T env) xs vals) (hv : contractOrder positions vals = some vs) :
    ∃ ys, contractOrder positions xs = some ys ∧ EvalArgs T env ys vs := by
  unfold contractOrder at hv ⊢
  rcases pick_rel h positions (List.range positions.length) with ⟨_, hb⟩ | ⟨as, bs, ha, hb, hab⟩
  · rw [hb] at hv; cases hv
  · rw [hb] at hv; cases hv
    exact ⟨as, ha, evalArgs_of_rel hab⟩

private theorem rhsStep_other {key : Key} {e : Expr} (h : callOrLocal e = false) : rhsStep key e = .unknown := by
  cases e <;> simp_all [callOrLocal, rhsStep]

/-- 右辺の具体の評価は、その一段の具体の評価である（対応の健全性の中心の補題）。 -/
theorem rhsEval_step {key : Key} {env : Locals} {e : Expr} {v : Option Refinement.Val}
    (h : RhsEval T key env e v) : StepEval ok T env (rhsStep key e) (v :: env) := by
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

private theorem stepsEval_append {env env' env'' : Locals} {ss ts : List ScopeState.Step}
    (h1 : StepsEval ok T env ss env') (h2 : StepsEval ok T env' ts env'') :
    StepsEval ok T env (ss ++ ts) env'' := by
  induction h1 with
  | nil => exact h2
  | cons h hs ih => exact .cons h (ih h2)

/-- 任意の値の列を、同じ数の未知の一段で積む。 -/
private theorem stepsEval_unknown (vals : List (Option Refinement.Val)) (env : Locals) :
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

private theorem rejoin_models {M : FactModels Refinement.Val} {outer : Run} {env : Locals}
    (hm : outer.state.Models M env) (inner : Run) : (rejoin outer inner).state.Models M env := by
  unfold rejoin
  cases inner with
  | running _ b => cases outer <;> exact hm
  | stopped f _ b => exact ScopeState.forgetAll_models M _ env

/-- guard の解析。 -/
private def guardRun (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits) (key : Key) (ra : Run) :
    Option Expr → Run × Records
  | none => (ra, [])
  | some e => analyzeExpr ok T L key ra e

private theorem analyzeArms_cons (ok : ConName) (T : ScopeTable Refinement.Val) (L : Limits)
    (scrut : Option Nat) (key : Key) (r : Run) (alts : List Alternative) (guard : Option Expr) (body : Block)
    (rest : Arms) :
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

section Analysis

variable {ok : ConName} {T : ScopeTable Refinement.Val} {L : Limits}

private theorem analyzeExpr_models {M : FactModels Refinement.Val} {key : Key} {r : Run} {env : Locals}
    (hm : r.state.Models M env) (e : Expr) : (analyzeExpr ok T L key r e).1.state.Models M env := by
  cases e <;> simp only [analyzeExpr] <;>
    first
    | exact rejoin_models hm _
    | exact Run.leave_models hm _
    | exact hm

variable {pattern : String → Option Range}

mutual
  private theorem reachExpr_sound (hT : TableSound (models ok pattern) T) {key : Key} {env : Locals} {e : Expr}
      {k : Key} {env' : Locals} {x : Expr} (h : ReachAtExpr T key env e k env' x) (r : Run)
      (hm : r.state.Models (models ok pattern) env) :
      ∃ st, (k, st) ∈ (analyzeExpr ok T L key r e).2 ∧ st.Models (models ok pattern) env' := by
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
        (rejoin r (analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .elseIfNo h' =>
      rename_i c yes _
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h'
        (rejoin r (analyzeBlock ok T L (advance key (1 + Identity.surfaceSize c))
          (rejoin r (analyzeExpr ok T L (advance key 1) r c).1) yes).1) (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩
    | .matchArms (v := v) h' =>
      rename_i _ sc _
      have hs := Run.step_models (ok := ok) hT L
        (rejoin_models hm (analyzeExpr ok T L (advance key 1) r sc).1) (StepEval.unknown (T := T) (v := v))
      obtain ⟨st, hmem, hst⟩ := reachArms_sound hT h' _ hs
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
    | .withBody (v := v) h' =>
      rename_i _ e _
      have hs := Run.step_models (ok := ok) hT L
        (rejoin_models hm (analyzeExpr ok T L (advance key 1) r e).1) (StepEval.unknown (T := T) (v := v))
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hs
      exact ⟨st, by simp [analyzeExpr, hmem], hst⟩

  private theorem reachExprs_sound (hT : TableSound (models ok pattern) T) {key : Key} {env : Locals} {es : Exprs}
      {k : Key} {env' : Locals} {x : Expr} (h : ReachAtExprs T key env es k env' x) (r : Run)
      (hm : r.state.Models (models ok pattern) env) :
      ∃ st, (k, st) ∈ (analyzeExprs ok T L key r es).2 ∧ st.Models (models ok pattern) env' := by
    match h with
    | .head h' =>
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' r hm
      exact ⟨st, by simp [analyzeExprs, hmem], hst⟩
    | .tail h' =>
      rename_i e _
      obtain ⟨st, hmem, hst⟩ := reachExprs_sound hT h' (rejoin r (analyzeExpr ok T L key r e).1)
        (rejoin_models hm _)
      exact ⟨st, by simp [analyzeExprs, hmem], hst⟩

  private theorem reachBlock_sound (hT : TableSound (models ok pattern) T) {key : Key} {env : Locals} {b : Block}
      {k : Key} {env' : Locals} {x : Expr} (h : ReachAtBlock T key env b k env' x) (r : Run)
      (hm : r.state.Models (models ok pattern) env) :
      ∃ st, (k, st) ∈ (analyzeBlock ok T L key r b).2 ∧ st.Models (models ok pattern) env' := by
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
      have hsteps : StepsEval ok T env (List.replicate _ .unknown) (vals ++ env) :=
        hlen ▸ stepsEval_unknown vals env
      have hs := Run.steps_models hT L (analyzeExpr_models (ok := ok) (T := T) (L := L) (key := key) hm e) hsteps
      obtain ⟨st, hmem, hst⟩ := reachBlock_sound hT h' _ hs
      exact ⟨st, by simp [analyzeBlock, hmem], hst⟩

  private theorem reachArms_sound (hT : TableSound (models ok pattern) T) {scrut : Option Nat} {key : Key}
      {env : Locals} {arms : Arms} {k : Key} {env' : Locals} {x : Expr}
      (h : ReachAtArms T scrut key env arms k env' x) (r : Run)
      (hm : r.state.Models (models ok pattern) env) :
      ∃ st, (k, st) ∈ (analyzeArms ok T L scrut key r arms).2 ∧ st.Models (models ok pattern) env' := by
    match h with
    | .guard henter h' =>
      have ha := Run.steps_models hT L hm (armEnter_steps (ok := ok) henter)
      obtain ⟨st, hmem, hst⟩ := reachExpr_sound hT h' _ ha
      exact ⟨st, by rw [analyzeArms_cons]; simp [guardRun, hmem], hst⟩
    | .body henter h' =>
      rename_i alts guard _ _ envA
      have ha := Run.steps_models hT L hm (armEnter_steps (ok := ok) henter)
      have hg : (guardRun ok T L key (r.steps T L (armEntry ok scrut alts)) guard).1.state.Models
          (models ok pattern) envA := by
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

  private theorem reachClauses_sound (hT : TableSound (models ok pattern) T) {key : Key} {clauses : Clauses}
      {k : Key} {env' : Locals} {x : Expr} (h : ReachAtClauses T key clauses k env' x) (r : Run) :
      ∃ st, (k, st) ∈ (analyzeClauses ok T L key r clauses).2 ∧ st.Models (models ok pattern) env' := by
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
対応する（上限の値によらず、超過して由来を忘れる場合を含む）。 -/
theorem analyzeBody_sound (hT : TableSound (models ok pattern) T) {key : Key} {scope : Interval.BindingScope}
    {body : Block} {env : Locals} {k : Key} {env' : Locals} (h : ReachBlock T key env body k env') :
    ∃ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧ st.Models (models ok pattern) env' := by
  obtain ⟨_, h⟩ := h
  exact reachBlock_sound hT h _ (ScopeState.empty_models _ _ _)

/-- 必須の判定の健全性（表層の版）。到達した文の始まりの記録が Top でない添字を付けた位置の値は、その範囲に属する
対象を保持する値である。 -/
theorem analyzeBody_requiredIndex (hT : TableSound (models ok pattern) T) {key : Key}
    {scope : Interval.BindingScope} {body : Block} {env : Locals} {k : Key} {env' : Locals}
    (h : ReachBlock T key env body k env') :
    ∃ st, (k, st) ∈ (analyzeBody ok T L key scope body).2 ∧
      ∀ i v, env'[i]? = some (some v) → st.requiredIndex i ≠ .top →
        ∃ t, v.target? = some t ∧ (st.requiredIndex i).Mem t := by
  obtain ⟨st, hmem, hst⟩ := analyzeBody_sound (L := L) hT h (scope := scope)
  refine ⟨st, hmem, fun i v found hne => ?_⟩
  obtain ⟨_, t, ht, -, -, hmt⟩ := requiredIndex_checked hst found hne
  exact ⟨t, ht, hmt⟩

end Analysis

/-! ## 到達した文の右辺と出現の番号の一致 -/

/-- 式の列を番号 key から先行順に番号付けする（`occurrences` の一般形）。 -/
private def occ (key : Key) (xs : List Expr) : List (Key × Expr) :=
  xs.zipIdx key.surfacePreorder |>.map fun (e, i) => (⟨key.definition, i⟩, e)

private theorem occ_cons (key : Key) (x : Expr) (xs : List Expr) :
    occ key (x :: xs) = (key, x) :: occ (advance key 1) xs := by
  simp [occ, advance, List.zipIdx_cons]

private theorem occ_append (key : Key) (xs ys : List Expr) :
    occ key (xs ++ ys) = occ key xs ++ occ (advance key xs.length) ys := by
  simp [occ, advance, List.zipIdx_append]

private theorem advance_advance (key : Key) (a b : Nat) : advance (advance key a) b = advance key (a + b) := by
  simp [advance, Nat.add_assoc]

private theorem mem_occ_head {key : Key} {x : Expr} {xs : List Expr} : (key, x) ∈ occ key (x :: xs) := by
  rw [occ_cons]; exact List.mem_cons_self

private theorem mem_occ_cons {key : Key} {x : Expr} {xs : List Expr} {p : Key × Expr}
    (h : p ∈ occ (advance key 1) xs) : p ∈ occ key (x :: xs) := by
  rw [occ_cons]; exact List.mem_cons_of_mem _ h

private theorem mem_occ_left {key : Key} {xs ys : List Expr} {p : Key × Expr} (h : p ∈ occ key xs) :
    p ∈ occ key (xs ++ ys) := by
  rw [occ_append]; exact List.mem_append_left _ h

private theorem mem_occ_right {key : Key} {xs ys : List Expr} {p : Key × Expr} {n : Nat} (hn : xs.length = n)
    (h : p ∈ occ (advance key n) ys) : p ∈ occ key (xs ++ ys) := by
  rw [occ_append, hn]; exact List.mem_append_right _ h

private theorem mem_occ_key {k1 k2 : Key} {xs : List Expr} {p : Key × Expr} (hk : k1 = k2) (h : p ∈ occ k1 xs) :
    p ∈ occ k2 xs := hk ▸ h

private theorem surfacePreorder_head (e : Expr) : ∃ rest, Identity.surfacePreorder e = e :: rest := by
  unfold Identity.surfacePreorder; exact ⟨_, rfl⟩

private theorem preorderBlock_rhs {b : Block} {e : Expr} (h : blockRhs? b = some e) :
    ∃ rest, Identity.preorderBlock b = e :: rest := by
  obtain ⟨r, hr⟩ := surfacePreorder_head e
  cases b <;> simp only [blockRhs?, Option.some.injEq, reduceCtorEq] at h <;> subst h <;>
    simp [Identity.preorderBlock, hr]

private def guardPre : Option Expr → List Expr
  | none => []
  | some g => Identity.surfacePreorder g

private theorem guardPre_length {guard : Option Expr} : (guardPre guard).length = guardSize guard := by
  cases guard <;> rfl

private theorem preorderArms_cons {alts : List Alternative} {guard : Option Expr} {body : Block} {rest : Arms} :
    Identity.preorderArms (.cons alts guard body rest) =
      guardPre guard ++ Identity.preorderBlock body ++ Identity.preorderArms rest := by
  cases guard <;> simp [Identity.preorderArms, guardPre]

variable {T : ScopeTable Refinement.Val}

mutual
  private theorem ReachAtExpr.occ {key env e k env' x} (h : ReachAtExpr T key env e k env' x) :
      (k, x) ∈ occ key (Identity.surfacePreorder e) := by
    match h with
    | .paren h' | .returnE h' =>
      simp only [Identity.surfacePreorder]; exact mem_occ_cons h'.occ
    | .callee h' =>
      simp only [Identity.surfacePreorder]; exact mem_occ_cons (mem_occ_left h'.occ)
    | .args (callee := callee) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [argsKey, advance_advance, Identity.surfaceSize]) h'.occ))
    | .block h' | .lam h' | .lazyE h' =>
      simp only [Identity.surfacePreorder]; exact mem_occ_cons h'.occ
    | .iteCond h' | .elseIfCond h' =>
      simp only [Identity.surfacePreorder]; exact mem_occ_cons (mem_occ_left (mem_occ_left h'.occ))
    | .ifOnlyCond h' | .matchScrut h' | .withExpr h' =>
      simp only [Identity.surfacePreorder]; exact mem_occ_cons (mem_occ_left h'.occ)
    | .iteYes (c := c) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_left (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, advance_advance]) h'.occ)))
    | .iteNo (c := c) (yes := yes) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, blockSize, advance_advance, Nat.add_assoc]) h'.occ))
    | .elseIfYes (c := c) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_left (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, advance_advance]) h'.occ)))
    | .elseIfNo (c := c) (yes := yes) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, blockSize, advance_advance, Nat.add_assoc]) h'.occ))
    | .ifOnlyYes (c := c) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, advance_advance]) h'.occ))
    | .matchArms (s := s) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, advance_advance]) h'.occ))
    | .handleBody h' | .failBody h' =>
      simp only [Identity.surfacePreorder]; exact mem_occ_cons (mem_occ_left h'.occ)
    | .handleClauses (body := body) h' | .failClause (body := body) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl (mem_occ_key (by simp [blockSize, advance_advance]) h'.occ))
    | .withBody (e := e) h' =>
      simp only [Identity.surfacePreorder]
      exact mem_occ_cons (mem_occ_right rfl
        (mem_occ_key (by simp [Identity.surfaceSize, advance_advance]) h'.occ))

  private theorem ReachAtExprs.occ {key env es k env' x} (h : ReachAtExprs T key env es k env' x) :
      (k, x) ∈ occ key (Identity.preorderExprs es) := by
    match h with
    | .head h' => simp only [Identity.preorderExprs]; exact mem_occ_left h'.occ
    | .tail h' => simp only [Identity.preorderExprs]; exact mem_occ_right rfl h'.occ

  private theorem ReachAtBlock.occ {key env b k env' x} (h : ReachAtBlock T key env b k env' x) :
      (k, x) ∈ occ key (Identity.preorderBlock b) := by
    match h with
    | .here hb =>
      obtain ⟨rest, hr⟩ := preorderBlock_rhs hb
      rw [hr]; exact mem_occ_head
    | .rhs (b := b) hb h' =>
      cases b <;> simp [blockRhs?] at hb <;> subst hb <;> simp only [Identity.preorderBlock] <;>
        first | exact h'.occ | exact mem_occ_left h'.occ
    | .builder h' => simp only [Identity.preorderBlock]; exact h'.occ
    | .bind _ h' | .discard h' | .seq h' | .bindPat _ h' =>
      simp only [Identity.preorderBlock]; exact mem_occ_right rfl h'.occ

  private theorem ReachAtArms.occ {scrut key env arms k env' x} (h : ReachAtArms T scrut key env arms k env' x) :
      (k, x) ∈ occ key (Identity.preorderArms arms) := by
    match h with
    | .guard _ h' => simp only [Identity.preorderArms]; exact mem_occ_left (mem_occ_left h'.occ)
    | .body _ h' =>
      rw [preorderArms_cons]; exact mem_occ_left (mem_occ_right guardPre_length h'.occ)
    | .next h' =>
      rw [preorderArms_cons]; exact mem_occ_right (by simp [guardPre_length, blockSize]) h'.occ

  private theorem ReachAtClauses.occ {key cs k env' x} (h : ReachAtClauses T key cs k env' x) :
      (k, x) ∈ occ key (Identity.preorderClauses cs) := by
    match h with
    | .body h' => simp only [Identity.preorderClauses]; exact mem_occ_left h'.occ
    | .next h' => simp only [Identity.preorderClauses]; exact mem_occ_right rfl h'.occ
end

/-- 番号 k の文の始まりへ到達し、その文の右辺が x なら、`(k, x)` は本体の出現の一覧に入る（接続定理の前提の出現を
到達から得る）。 -/
theorem reachAt_occurrences {key env body k env' x} (h : ReachAtBlock T key env body k env' x) :
    (k, x) ∈ occurrences key body := h.occ

end Benitoite.Release.Refinement.Surface.ScopeLower
