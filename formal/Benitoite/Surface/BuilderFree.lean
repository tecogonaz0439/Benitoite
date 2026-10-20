import Benitoite.Surface.Syntax

/-! 構築器を含まない構文を、すべての子まで明示的に検査する。
対応する意味保存は設計書 01-12「構築器の局所文脈と旧構文の意味」に従う。 -/
namespace Benitoite.Surface
open Benitoite.Release

mutual
  /-- 専用構文を含まない。捕捉の境界の内側も検査する。 -/
  def Expr.BuilderFree : Expr → Prop
    | .builderOp _ _ _ _ => False
    | .local _ => True
    | .constE _ body => body.BuilderFree
    | .funName _ _ _ => True
    | .funDicts _ _ _ _ _ _ => True
    | .methName _ _ _ _ _ _ _ => True
    | .primName _ _ _ => True
    | .opName _ _ => True
    | .opDicts _ _ _ _ _ => True
    | .raise _ _ => True
    | .handleFail _ _ body clause => body.BuilderFree ∧ clause.BuilderFree
    | .nullCon _ _ => True
    | .conValue _ _ _ _ => True
    | .literal _ => True
    | .negInt _ => True
    | .negFloat _ => True
    | .negDecimal _ _ => True
    | .negInteger8 _ => True
    | .negInteger16 _ => True
    | .negInteger32 _ => True
    | .negFloat32 _ => True
    | .unit => True
    | .paren e => e.BuilderFree
    | .block body => body.BuilderFree
    | .conCall _ _ args => args.BuilderFree
    | .record _ _ _ args => args.BuilderFree
    | .recordUpdate _ _ _ _ base args => base.BuilderFree ∧ args.BuilderFree
    | .call callee _ _ args => callee.BuilderFree ∧ args.BuilderFree
    | .pipe lhs rhs => lhs.BuilderFree ∧ rhs.BuilderFree
    | .partialCall callee _ args _ _ => callee.BuilderFree ∧ args.BuilderFree
    | .partialCon _ _ args => args.BuilderFree
    | .binary _ _ lhs rhs => lhs.BuilderFree ∧ rhs.BuilderFree
    | .neg _ e => e.BuilderFree
    | .not e => e.BuilderFree
    | .and lhs rhs => lhs.BuilderFree ∧ rhs.BuilderFree
    | .or lhs rhs => lhs.BuilderFree ∧ rhs.BuilderFree
    | .list _ elems => elems.BuilderFree
    | .listSpread _ concat before spread after => concat.BuilderFree ∧ before.BuilderFree ∧ spread.BuilderFree ∧ after.BuilderFree
    | .interpolation _ es converters => es.BuilderFree ∧ converters.BuilderFree
    | .lam _ _ _ _ body => body.BuilderFree
    | .ite cond yes no => cond.BuilderFree ∧ yes.BuilderFree ∧ no.BuilderFree
    | .elseIf cond yes no => cond.BuilderFree ∧ yes.BuilderFree ∧ no.BuilderFree
    | .ifOnly cond yes => cond.BuilderFree ∧ yes.BuilderFree
    | .matchE _ scrutinee arms => scrutinee.BuilderFree ∧ arms.BuilderFree
    | .returnE _ e => e.BuilderFree
    | .tryResult _ _ _ e => e.BuilderFree
    | .tryOption _ _ _ e => e.BuilderFree
    | .tryResultDie _ _ _ _ _ _ e message => e.BuilderFree ∧ (∀ e, message = some e → e.BuilderFree)
    | .tryOptionDie _ _ _ _ e message => e.BuilderFree ∧ (∀ e, message = some e → e.BuilderFree)
    | .withE _ e body => e.BuilderFree ∧ body.BuilderFree
    | .lazyE body => body.BuilderFree
    | .handleE body clauses => body.BuilderFree ∧ clauses.BuilderFree
    | .resume _ e => e.BuilderFree

  /-- 専用構文を含まない。捕捉の境界の内側も検査する。 -/
  def Exprs.BuilderFree : Exprs → Prop
    | .nil => True
    | .cons head tail => head.BuilderFree ∧ tail.BuilderFree

  /-- 専用構文を含まない。捕捉の境界の内側も検査する。 -/
  def HoleArgs.BuilderFree : HoleArgs → Prop
    | .nil => True
    | .expr _ _ head tail => head.BuilderFree ∧ tail.BuilderFree
    | .hole _ _ _ tail => tail.BuilderFree

  /-- 専用構文を含まない。捕捉の境界の内側も検査する。 -/
  def Arms.BuilderFree : Arms → Prop
    | .nil => True
    | .cons _ guard body rest => (∀ e, guard = some e → e.BuilderFree) ∧ body.BuilderFree ∧ rest.BuilderFree

  /-- 専用構文を含まない。捕捉の境界の内側も検査する。 -/
  def Clauses.BuilderFree : Clauses → Prop
    | .nil => True
    | .cons _ _ _ body rest _ => body.BuilderFree ∧ rest.BuilderFree

  /-- 専用構文を含まない。捕捉の境界の内側も検査する。 -/
  def Block.BuilderFree : Block → Prop
    | .builderBind .. => False
    | .empty => True
    | .last e => e.BuilderFree
    | .lastBind _ _ e => e.BuilderFree
    | .lastDiscard e => e.BuilderFree
    | .bind _ _ e rest => e.BuilderFree ∧ rest.BuilderFree
    | .discard e rest => e.BuilderFree ∧ rest.BuilderFree
    | .seq e rest => e.BuilderFree ∧ rest.BuilderFree
    | .lastPat _ _ _ e => e.BuilderFree
    | .bindPat _ _ _ e rest => e.BuilderFree ∧ rest.BuilderFree

end

end Benitoite.Surface
