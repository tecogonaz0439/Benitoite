import Benitoite.Release.Refinement.Surface.Program
import Benitoite.Release.Refinement.Surface.ScopeShift

/-!
# 表層の有効範囲と脱糖の有効範囲の保存

表層の式の型注釈が、型パラメータ nt・エフェクト変数 ne・値の変数 nv の範囲にあることを、構文に沿って定める
（設計書 01-12「型の情報を付けた表層の構文と型付け」、07-04「01-12 との対応」）。脱糖した計算は同じ範囲で
ソースの有効範囲（`Comp.SourceScoped`）を持つ。値の束縛の数は型付けの導出の文脈の長さと一致する。
-/

namespace Benitoite.Release.Refinement.Surface

mutual
  def DictEv.Scoped (nt ne nv : Nat) : DictEv → Prop
    | .impl _ ts ds => scopedTypes 0 nt ne nv ts ∧ DictEv.ScopedList nt ne nv ds
    | .local j => j < nv
    | .clause s i depth => depth + s.slot i < nv
    | .super d _ => d.Scoped nt ne nv
  def DictEv.ScopedList (nt ne nv : Nat) : List DictEv → Prop
    | [] => True
    | d :: ds => d.Scoped nt ne nv ∧ DictEv.ScopedList nt ne nv ds
end

mutual
  def Expr.Scoped (nt ne nv : Nat) : Expr → Prop
    | .local i => i < nv
    | .builderOp _ i args k => i < nv ∧ k.SourceScoped 0 nt ne nv ∧ args.Scoped nt ne nv
    | .constE _ body => body.Scoped nt ne nv
    | .funName _ ts es => scopedTypes 0 nt ne nv ts ∧ scopedRows 0 nt ne nv es
    | .primName _ ts es rs => scopedTypes 0 nt ne nv ts ∧ scopedRows 0 nt ne nv es ∧
        ∀ r ∈ rs, (RangeExpr.absolute r).WF ∧ (RangeExpr.absolute r).Canonical
    | .funDicts _ ts es ds names ps => scopedTypes 0 nt ne nv ts ∧ scopedRows 0 nt ne nv es ∧
        DictEv.ScopedList nt ne nv ds ∧ NamesWF names ps ∧ scopedTypes 0 nt ne nv ps
    | .methName d _ ss es us names ps => d.Scoped nt ne nv ∧ scopedTypes 0 nt ne nv ss ∧
        scopedRows 0 nt ne nv es ∧ DictEv.ScopedList nt ne nv us ∧ NamesWF names ps ∧ scopedTypes 0 nt ne nv ps
    | .nullCon _ ts | .opName _ ts | .externalName _ ts => scopedTypes 0 nt ne nv ts
    | .opDicts _ ts ds names ps => scopedTypes 0 nt ne nv ts ∧ DictEv.ScopedList nt ne nv ds ∧
        NamesWF names ps ∧ scopedTypes 0 nt ne nv ps
    | .raise t e => t.SourceScoped 0 nt ne nv ∧ e.SourceScoped 0 nt ne nv
    | .handleFail e _ body clause => e.SourceScoped 0 nt ne nv ∧ body.Scoped nt ne nv ∧
        clause.Scoped (nt + 1) ne (nv + 2)
    | .conValue _ ts names ps => scopedTypes 0 nt ne nv ts ∧ NamesWF names ps ∧ scopedTypes 0 nt ne nv ps
    | .literal _ | .negInt _ | .negFloat _ | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _
    | .negInteger32 _ | .negFloat32 _ | .unit => True
    | .paren e => e.Scoped nt ne nv
    | .block body => body.Scoped nt ne nv
    | .record _ ts _ es | .conCall _ ts es => scopedTypes 0 nt ne nv ts ∧ es.Scoped nt ne nv
    | .recordUpdate _ ts _ _ base es => scopedTypes 0 nt ne nv ts ∧ base.Scoped nt ne nv ∧ es.Scoped nt ne nv
    | .call f _ _ es => f.Scoped nt ne nv ∧ es.Scoped nt ne nv
    | .pipe lhs rhs => lhs.Scoped nt ne nv ∧ rhs.Scoped nt ne nv
    | .partialCall f names args ret eff => f.Scoped nt ne nv ∧ args.Scoped nt ne nv ∧
        (Ty.dependentFn (holeTel (args.holeNames names) args.holeTypes 0 ret eff)).SourceScoped 0 nt ne nv
    | .partialCon _ ts args => scopedTypes 0 nt ne nv ts ∧ args.Scoped nt ne nv
    | .binary _ t lhs rhs => t.SourceScoped 0 nt ne nv ∧ lhs.Scoped nt ne nv ∧ rhs.Scoped nt ne nv
    | .and lhs rhs | .or lhs rhs => lhs.Scoped nt ne nv ∧ rhs.Scoped nt ne nv
    | .neg _ e | .not e => e.Scoped nt ne nv
    | .list _ es => es.Scoped nt ne nv
    | .listSpread _ f before s after => f.Scoped nt ne nv ∧ before.Scoped nt ne nv ∧
        s.Scoped nt ne nv ∧ after.Scoped nt ne nv
    | .interpolation _ es fs => es.Scoped nt ne nv ∧ fs.Scoped nt ne nv
    | .lam names ps _ _ body => NamesWF names ps ∧ scopedTypes 0 nt ne nv ps ∧ body.Scoped nt ne (nv + ps.length)
    | .ite c yes no => c.Scoped nt ne nv ∧ yes.Scoped nt ne nv ∧ no.Scoped nt ne nv
    | .elseIf c yes no => c.Scoped nt ne nv ∧ yes.Scoped nt ne nv ∧ no.Scoped nt ne nv
    | .ifOnly c yes => c.Scoped nt ne nv ∧ yes.Scoped nt ne nv
    | .matchE _ e arms => e.Scoped nt ne nv ∧ arms.Scoped nt ne (nv + 1)
    | .returnE _ e => e.Scoped nt ne nv
    | .tryResult ts _ _ e | .tryOption ts _ _ e => scopedTypes 0 nt ne nv ts ∧ e.Scoped nt ne nv
    | .tryResultDie t _ _ d _ _ e message => t.SourceScoped 0 nt ne nv ∧ d.Scoped nt ne nv ∧ e.Scoped nt ne nv ∧
        (match message with | none => True | some m => m.Scoped nt ne nv)
    | .tryOptionDie t _ _ _ e message => t.SourceScoped 0 nt ne nv ∧ e.Scoped nt ne nv ∧
        (match message with | none => True | some m => m.Scoped nt ne nv)
    | .withE _ e body => e.Scoped nt ne nv ∧ body.Scoped nt ne (nv + 1)
    | .lazyE body => body.Scoped nt ne nv
    | .handleE body cs => body.Scoped nt ne nv ∧ cs.Scoped nt ne nv
    | .resume k e => k < nv ∧ e.Scoped nt ne nv
  def Exprs.Scoped (nt ne nv : Nat) : Exprs → Prop
    | .nil => True
    | .cons e es => e.Scoped nt ne nv ∧ es.Scoped nt ne nv
  def HoleArgs.Scoped (nt ne nv : Nat) : HoleArgs → Prop
    | .nil => True
    | .expr _ _ e rest => e.Scoped nt ne nv ∧ rest.Scoped nt ne nv
    | .hole _ _ t rest => t.SourceScoped 0 nt ne nv ∧ rest.Scoped nt ne nv
  def Arms.Scoped (nt ne nv : Nat) : Arms → Prop
    | .nil => True
    | .cons alts none body rest =>
        body.Scoped nt ne (nv + Arm.bindersOf (Alternative.toCoreList alts)) ∧ rest.Scoped nt ne nv
    | .cons alts (some guard) body rest =>
        guard.Scoped nt ne (nv + Arm.bindersOf (Alternative.toCoreList alts)) ∧
          body.Scoped nt ne (nv + Arm.bindersOf (Alternative.toCoreList alts)) ∧ rest.Scoped nt ne nv
  def Clauses.Scoped (nt ne nv : Nat) : Clauses → Prop
    | .nil => True
    | .cons _ n ntys body rest ndicts => body.Scoped (nt + ntys) ne (nv + (ndicts + n) + 1) ∧ rest.Scoped nt ne nv
  def Block.Scoped (nt ne nv : Nat) : Block → Prop
    | .builderBind k rest => k.SourceScoped 0 nt ne nv ∧ rest.Scoped nt ne (nv + 1)
    | .empty => True
    | .last e | .lastDiscard e | .lastBind _ _ e | .lastPat _ _ _ e => e.Scoped nt ne nv
    | .bind _ _ e rest => e.Scoped nt ne nv ∧ rest.Scoped nt ne (nv + 1)
    | .discard e rest | .seq e rest => e.Scoped nt ne nv ∧ rest.Scoped nt ne nv
    | .bindPat _ pat _ e rest => e.Scoped nt ne nv ∧ rest.Scoped nt ne (nv + pat.toCore.binders)
end

end Benitoite.Release.Refinement.Surface
