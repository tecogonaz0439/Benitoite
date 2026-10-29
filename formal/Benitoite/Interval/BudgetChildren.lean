import Benitoite.Interval.BudgetIndependentRun

/-!
# 未知の形の子の独立した走査

解析本体を引数に受け取り、容器を先に平坦化せず元のフィールド順で辿る。
別本体は番号だけを消費し、独立入力の値を親のフローへ戻さない。
（設計書 01-12「区間解析の独立入力の保存と保証」）。
-/
namespace Benitoite.Interval.BudgetAnalysis
open Benitoite.Surface Benitoite.Release Budget

/-- 容器の分類・枠も共有予算で計上する。各要素の入口は呼び出し側が渡す。 -/
def childExprs (visit : Expr → Analysis Unit) : Nat → Exprs → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, sources => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match sources with
    | .nil => pure ()
    | .cons source rest => do visit source; childExprs visit fuel rest

/-- 穴は評価せず、式の引数だけを宣言順に独立解析する。 -/
def childHoles (visit : Expr → Analysis Unit) : Nat → HoleArgs → Analysis Unit
  | 0, _ => throw .depth
  | fuel + 1, args => scope fun _ => do
    scan (BudgetScan.tick .classification)
    match args with
    | .nil => pure ()
    | .expr _ _ source rest => do visit source; childHoles visit fuel rest
    | .hole _ _ _ rest => childHoles visit fuel rest

/-- 任意のメッセージも、オペランドとは別の入力とする。 -/
def childOptional (visit : Expr → Analysis Unit) : Nat → Option Expr → Analysis Unit
  | 0, _ => throw .depth
  | _ + 1, none => pure ()
  | _ + 1, some source => visit source

/-- 子の値・return・絞り込みは使わず、番号を一度だけ消費する。
with の位置0は型だけを持つ Top として予算内で追加する。
ラムダ・lazy・handler 節は別本体なので、ここでは番号だけを辿る。 -/
def unknownChildren (runExpr : AbstractEnv → Expr → Analysis BaseApprox)
    (runBlock : AbstractEnv → Block → Analysis BaseApprox)
    (fuel : Nat) (env : AbstractEnv) (source : Expr) : Analysis Unit :=
  match fuel with
  | 0 => throw .depth
  | fuel + 1 =>
    let visit := fun e => independentWith (.expr e) env (fun initial => runExpr initial e)
    let body := fun b => independentWith (.block b) env (fun initial => runBlock initial b)
    match source with
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit => pure ()
    | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es => childExprs visit fuel es
    | .constE _ e | .paren e | .neg _ e | .not e | .returnE _ e
    | .tryResult _ _ _ e | .tryOption _ _ _ e | .resume _ e => visit e
    | .block b => body b
    | .lam _ _ _ _ b | .lazyE b => skipBlock fuel b
    | .handleFail _ _ b clause => do body b; skipBlock fuel clause
    | .recordUpdate _ _ _ _ base es => do visit base; childExprs visit fuel es
    | .call callee _ _ es => do visit callee; childExprs visit fuel es
    | .pipe left right | .binary _ _ left right | .and left right | .or left right => do
      visit left; visit right
    | .partialCall callee _ args _ _ => do visit callee; childHoles visit fuel args
    | .partialCon _ _ args => childHoles visit fuel args
    | .listSpread _ concat before spread after => do
      visit concat; childExprs visit fuel before; visit spread; childExprs visit fuel after
    | .interpolation _ es converters => do childExprs visit fuel es; childExprs visit fuel converters
    | .ite cond yes no => do visit cond; body yes; body no
    | .elseIf cond yes no => do visit cond; body yes; visit no
    | .ifOnly cond yes => do visit cond; body yes
    | .matchE _ e arms => do visit e; skipArms fuel arms
    | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message => do
      visit e; childOptional visit fuel message
    | .withE owner e b => do
      visit e
      let inner ← scan (BudgetScan.push env (topSlot (some (.opaqueTop owner))))
      independentWith (.block b) inner (fun initial => runBlock initial b)
    | .handleE b clauses => do body b; skipClauses fuel clauses

/-- 子の実行に関する成否共通の性質を、容器の走査へ合成する。
述語の合成則を明示し、解析の健全性そのものを仮定として隠さない。 -/
theorem childContainers_property
    (P : {α : Type} → Analysis α → Prop)
    (hp : ∀ {α} (value : α), P (pure value))
    (ht : ∀ {α} reason, P (throw reason : Analysis α))
    (hb : ∀ {α β} (first : Analysis α) (next : α → Analysis β),
      P first → (∀ value, P (next value)) → P (first >>= next))
    (hs : ∀ {α} (work : Unit → Analysis α), P (work ()) → P (scope work))
    (hc : ∀ {α} (work : BudgetScan.Scan α), P (scan work))
    (visit : Expr → Analysis Unit) (hv : ∀ e, P (visit e)) (fuel : Nat) :
    (∀ es, P (childExprs visit fuel es)) ∧
    (∀ args, P (childHoles visit fuel args)) ∧
    (∀ value, P (childOptional visit fuel value)) := by
  induction fuel with
  | zero => exact ⟨fun _ => ht _, fun _ => ht _, fun _ => ht _⟩
  | succ fuel ih =>
    refine ⟨?_, ?_, ?_⟩
    · intro es
      rw [childExprs.eq_def]
      apply hs
      apply hb _ _ (hc _)
      intro ignored
      cases es with
      | nil => exact hp _
      | cons e rest => exact hb _ _ (hv e) (fun _ => ih.1 rest)
    · intro args
      rw [childHoles.eq_def]
      apply hs
      apply hb _ _ (hc _)
      intro ignored
      cases args with
      | nil => exact hp _
      | expr _ _ e rest => exact hb _ _ (hv e) (fun _ => ih.2.1 rest)
      | hole _ _ _ rest => exact ih.2.1 rest
    · intro value
      cases value with
      | none => exact hp _
      | some e => exact hv e

/-- 独立した子と別本体の走査の性質を、全構成子のフィールド順へ接続する。 -/
theorem unknownChildren_property
    (P : {α : Type} → Analysis α → Prop)
    (hp : ∀ {α} (value : α), P (pure value))
    (ht : ∀ {α} reason, P (throw reason : Analysis α))
    (hb : ∀ {α β} (first : Analysis α) (next : α → Analysis β),
      P first → (∀ value, P (next value)) → P (first >>= next))
    (hs : ∀ {α} (work : Unit → Analysis α), P (work ()) → P (scope work))
    (hc : ∀ {α} (work : BudgetScan.Scan α), P (scan work))
    (runExpr : AbstractEnv → Expr → Analysis BaseApprox)
    (runBlock : AbstractEnv → Block → Analysis BaseApprox)
    (he : ∀ env e, P (independentWith (.expr e) env (fun initial => runExpr initial e)))
    (hbody : ∀ env b, P (independentWith (.block b) env (fun initial => runBlock initial b)))
    (fuel : Nat)
    (sb : ∀ b, P (skipBlock fuel b)) (sa : ∀ a, P (skipArms fuel a))
    (sc : ∀ c, P (skipClauses fuel c)) (env : AbstractEnv) (source : Expr) :
    P (unknownChildren runExpr runBlock (fuel + 1) env source) := by
  obtain ⟨hes, hh, ho⟩ := childContainers_property P hp ht hb hs hc
    (fun e => independentWith (.expr e) env (fun initial => runExpr initial e)) (he env) fuel
  cases source <;> simp only [unknownChildren]
  all_goals first
    | with_reducible exact hp _
    | with_reducible exact he _ _
    | with_reducible exact hbody _ _
    | with_reducible exact hes _
    | with_reducible exact hh _
    | with_reducible exact sb _
    | with_reducible exact hb _ _ (he _ _) (fun _ => hes _)
    | with_reducible exact hb _ _ (he _ _) (fun _ => hh _)
    | with_reducible exact hb _ _ (he _ _) (fun _ => hbody _ _)
    | with_reducible exact hb _ _ (he _ _) (fun _ => sa _)
    | with_reducible exact hb _ _ (he _ _) (fun _ => ho _)
    | with_reducible exact hb _ _ (hbody _ _) (fun _ => sb _)
    | with_reducible exact hb _ _ (hbody _ _) (fun _ => sc _)
    | with_reducible exact hb _ _ (he _ _) (fun _ => he _ _)
    | with_reducible exact hb _ _ (hes _) (fun _ => hes _)
    | with_reducible exact hb _ _ (he _ _) (fun _ => hb _ _ (hbody _ _) (fun _ => hbody _ _))
    | with_reducible exact hb _ _ (he _ _) (fun _ => hb _ _ (hbody _ _) (fun _ => he _ _))
    | with_reducible exact hb _ _ (he _ _) (fun _ => hb _ _ (hes _) (fun _ =>
        hb _ _ (he _ _) (fun _ => hes _)))
    | with_reducible exact hb _ _ (he _ _) (fun _ => hb _ _ (hc _) (fun inner => hbody inner _))

end Benitoite.Interval.BudgetAnalysis
