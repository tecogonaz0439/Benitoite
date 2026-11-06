import Benitoite.Release.Refinement.Surface.Program
import Benitoite.Release.Refinement.Surface.ScopeShift

/-!
# 表層の有効範囲と脱糖の有効範囲の保存

表層の式の型注釈が、範囲パラメータ nr・型パラメータ nt・エフェクト変数 ne・値の変数 nv の範囲にあることを、構文に沿って定める
（設計書 01-12「型の情報を付けた表層の構文と型付け」、07-04「01-12 との対応」）。脱糖した計算は同じ範囲で
ソースの有効範囲（`Comp.SourceScoped`）を持つ。値の束縛の数は型付けの導出の文脈の長さと一致する。
-/

namespace Benitoite.Release.Refinement.Surface

mutual
  def DictEv.Scoped (nt ne nv : Nat) (nr : Nat := 0) : DictEv → Prop
    | .impl _ ts ds => scopedTypes nr nt ne nv ts ∧ DictEv.ScopedList nt ne nv (nr := nr) ds
    | .local j => j < nv
    | .clause s i depth => depth + s.slot i < nv
    | .super d _ => d.Scoped nt ne nv (nr := nr)
  def DictEv.ScopedList (nt ne nv : Nat) (ds : List DictEv) (nr : Nat := 0) : Prop :=
    match ds with
    | [] => True
    | d :: ds => d.Scoped nt ne nv (nr := nr) ∧ DictEv.ScopedList nt ne nv (nr := nr) ds
end

mutual
  def Expr.Scoped (nt ne nv : Nat) (nr : Nat := 0) : Expr → Prop
    | .local i => i < nv
    | .builderOp _ i args k => i < nv ∧ k.SourceScoped nr nt ne nv ∧ args.Scoped nt ne nv (nr := nr)
    | .constE _ body => body.Scoped nt ne nv (nr := nr)
    | .funName _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical)
    | .primName _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical)
    | .funDicts _ ts es ds names ps rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        DictEv.ScopedList nt ne nv (nr := nr) ds ∧ NamesWF names ps ∧ scopedTypes nr nt ne nv ps ∧
        (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical)
    | .methName d _ ss es us names ps => d.Scoped nt ne nv (nr := nr) ∧ scopedTypes nr nt ne nv ss ∧
        scopedRows nr nt ne nv es ∧ DictEv.ScopedList nt ne nv (nr := nr) us ∧ NamesWF names ps ∧ scopedTypes nr nt ne nv ps
    | .nullCon _ ts | .opName _ ts | .externalName _ ts => scopedTypes nr nt ne nv ts
    | .opDicts _ ts ds names ps => scopedTypes nr nt ne nv ts ∧ DictEv.ScopedList nt ne nv (nr := nr) ds ∧
        NamesWF names ps ∧ scopedTypes nr nt ne nv ps
    | .raise t e => t.SourceScoped nr nt ne nv ∧ e.SourceScoped nr nt ne nv
    | .handleFail e _ body clause => e.SourceScoped nr nt ne nv ∧ body.Scoped nt ne nv (nr := nr) ∧
        clause.Scoped (nt + 1) ne (nv + 2) (nr := nr)
    | .conValue _ ts names ps => scopedTypes nr nt ne nv ts ∧ NamesWF names ps ∧ scopedTypes nr nt ne nv ps
    | .literal _ | .negInt _ | .negFloat _ | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _
    | .negInteger32 _ | .negFloat32 _ | .unit => True
    | .paren e => e.Scoped nt ne nv (nr := nr)
    | .block body => body.Scoped nt ne nv (nr := nr)
    | .record _ ts _ es | .conCall _ ts es => scopedTypes nr nt ne nv ts ∧ es.Scoped nt ne nv (nr := nr)
    | .recordUpdate _ ts _ _ base es => scopedTypes nr nt ne nv ts ∧ base.Scoped nt ne nv (nr := nr) ∧ es.Scoped nt ne nv (nr := nr)
    | .call f _ _ es => f.Scoped nt ne nv (nr := nr) ∧ es.Scoped nt ne nv (nr := nr)
    | .pipe lhs rhs => lhs.Scoped nt ne nv (nr := nr) ∧ rhs.Scoped nt ne nv (nr := nr)
    | .partialCall f names args ret eff => f.Scoped nt ne nv (nr := nr) ∧ args.Scoped nt ne nv (nr := nr) ∧
        (Ty.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)).SourceScoped nr nt ne nv
    | .partialCon _ ts args => scopedTypes nr nt ne nv ts ∧ args.Scoped nt ne nv (nr := nr)
    | .binary _ t lhs rhs => t.SourceScoped nr nt ne nv ∧ lhs.Scoped nt ne nv (nr := nr) ∧ rhs.Scoped nt ne nv (nr := nr)
    | .and lhs rhs | .or lhs rhs => lhs.Scoped nt ne nv (nr := nr) ∧ rhs.Scoped nt ne nv (nr := nr)
    | .neg _ e | .not e => e.Scoped nt ne nv (nr := nr)
    | .list _ es => es.Scoped nt ne nv (nr := nr)
    | .listSpread _ f before s after => f.Scoped nt ne nv (nr := nr) ∧ before.Scoped nt ne nv (nr := nr) ∧
        s.Scoped nt ne nv (nr := nr) ∧ after.Scoped nt ne nv (nr := nr)
    | .interpolation _ es fs => es.Scoped nt ne nv (nr := nr) ∧ fs.Scoped nt ne nv (nr := nr)
    | .lam names ps _ _ body => NamesWF names ps ∧ scopedTypes nr nt ne nv ps ∧ body.Scoped nt ne (nv + ps.length) (nr := nr)
    | .ite c yes no => c.Scoped nt ne nv (nr := nr) ∧ yes.Scoped nt ne nv (nr := nr) ∧ no.Scoped nt ne nv (nr := nr)
    | .elseIf c yes no => c.Scoped nt ne nv (nr := nr) ∧ yes.Scoped nt ne nv (nr := nr) ∧ no.Scoped nt ne nv (nr := nr)
    | .ifOnly c yes => c.Scoped nt ne nv (nr := nr) ∧ yes.Scoped nt ne nv (nr := nr)
    | .matchE _ e arms => e.Scoped nt ne nv (nr := nr) ∧ arms.Scoped nt ne (nv + 1) (nr := nr)
    | .returnE _ e => e.Scoped nt ne nv (nr := nr)
    | .tryResult ts _ _ e | .tryOption ts _ _ e => scopedTypes nr nt ne nv ts ∧ e.Scoped nt ne nv (nr := nr)
    | .tryResultDie t _ _ d _ _ e message => t.SourceScoped nr nt ne nv ∧ d.Scoped nt ne nv (nr := nr) ∧ e.Scoped nt ne nv (nr := nr) ∧
        (match message with | none => True | some m => m.Scoped nt ne nv (nr := nr))
    | .tryOptionDie t _ _ _ e message => t.SourceScoped nr nt ne nv ∧ e.Scoped nt ne nv (nr := nr) ∧
        (match message with | none => True | some m => m.Scoped nt ne nv (nr := nr))
    | .withE _ e body => e.Scoped nt ne nv (nr := nr) ∧ body.Scoped nt ne (nv + 1) (nr := nr)
    | .lazyE body => body.Scoped nt ne nv (nr := nr)
    | .handleE body cs => body.Scoped nt ne nv (nr := nr) ∧ cs.Scoped nt ne nv (nr := nr)
    | .resume k e => k < nv ∧ e.Scoped nt ne nv (nr := nr)
  def Exprs.Scoped (nt ne nv : Nat) (nr : Nat := 0) : Exprs → Prop
    | .nil => True
    | .cons e es => e.Scoped nt ne nv (nr := nr) ∧ es.Scoped nt ne nv (nr := nr)
  def HoleArgs.Scoped (nt ne nv : Nat) (nr : Nat := 0) : HoleArgs → Prop
    | .nil => True
    | .expr _ _ e rest => e.Scoped nt ne nv (nr := nr) ∧ rest.Scoped nt ne nv (nr := nr)
    | .hole _ _ t rest => t.SourceScoped nr nt ne nv ∧ rest.Scoped nt ne nv (nr := nr)
  def Arms.Scoped (nt ne nv : Nat) (nr : Nat := 0) : Arms → Prop
    | .nil => True
    | .cons alts none body rest =>
        body.Scoped nt ne (nv + Arm.bindersOf (Alternative.toCoreList alts)) (nr := nr) ∧ rest.Scoped nt ne nv (nr := nr)
    | .cons alts (some guard) body rest =>
        guard.Scoped nt ne (nv + Arm.bindersOf (Alternative.toCoreList alts)) (nr := nr) ∧
          body.Scoped nt ne (nv + Arm.bindersOf (Alternative.toCoreList alts)) (nr := nr) ∧ rest.Scoped nt ne nv (nr := nr)
  def Clauses.Scoped (nt ne nv : Nat) (nr : Nat := 0) : Clauses → Prop
    | .nil => True
    | .cons _ n ntys body rest ndicts => body.Scoped (nt + ntys) ne (nv + (ndicts + n) + 1) (nr := nr) ∧ rest.Scoped nt ne nv (nr := nr)
  def Block.Scoped (nt ne nv : Nat) (nr : Nat := 0) : Block → Prop
    | .builderBind k rest => k.SourceScoped nr nt ne nv ∧ rest.Scoped nt ne (nv + 1) (nr := nr)
    | .empty => True
    | .last e | .lastDiscard e | .lastBind _ _ e | .lastPat _ _ _ e => e.Scoped nt ne nv (nr := nr)
    | .bind _ _ e rest => e.Scoped nt ne nv (nr := nr) ∧ rest.Scoped nt ne (nv + 1) (nr := nr)
    | .discard e rest | .seq e rest => e.Scoped nt ne nv (nr := nr) ∧ rest.Scoped nt ne nv (nr := nr)
    | .bindPat _ pat _ e rest => e.Scoped nt ne nv (nr := nr) ∧ rest.Scoped nt ne (nv + pat.toCore.binders) (nr := nr)
end

end Benitoite.Release.Refinement.Surface
