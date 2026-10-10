import Benitoite.Surface.Syntax
import Benitoite.Release.WellFormed

/-!
# 表層の番号の範囲（C1・C2・C4・C5a-1・C6a-1・C6a-2・C6a-3・C7b-2）

型・エフェクトの範囲と、局所変数の範囲を入力の木で検査する。
脱糖の結果に条件を課さない。型には Release の VarsIn を使い、継続の型を含めない。
型の範囲は型付けの判断とは独立であり、空のリストや return の具体化した型にも課す。
-/

namespace Benitoite.Surface

open Benitoite.Release

mutual
  def DictEv.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : DictEv → Prop
    -- 01-12「型クラス」V-Dict: 実装の型引数と制約の辞書 V̄。
    | .impl _ ts ds => Ty.VarsInList nt pe ts ∧ DictEv.ScopedList nt pe nv ds
    -- 同節の辞書の決め方: 受け取った辞書は Γ の普通の変数。
    | .local j => j < nv
    -- V-Super: V↑S は V の範囲を保つ。
    | .super d _ => d.Scoped nt pe nv

  def DictEv.ScopedList (nt : Nat) (pe : Nat → Prop) (nv : Nat) : List DictEv → Prop
    | [] => True
    | d :: ds => d.Scoped nt pe nv ∧ DictEv.ScopedList nt pe nv ds
end

mutual
  def Expr.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : Expr → Prop
    | .local i => i < nv
    -- P5: 型の範囲は使用位置のまま、値の変数は 0 個で本体を検査する。
    | .constE a body => Ty.VarsIn nt pe a ∧ body.Scoped nt pe 0
    | .funName _ ts es | .primName _ ts es =>
        Ty.VarsInList nt pe ts ∧ Eff.RhosInList pe es
    -- 01-12「型クラス」第 4 行: 型引数・エフェクト引数・Ū・ラムダの値引数型。
    | .funDicts _ ts es ds ps =>
        Ty.VarsInList nt pe ts ∧ Eff.RhosInList pe es ∧
          DictEv.ScopedList nt pe nv ds ∧ Ty.VarsInList nt pe ps
    -- 同表第 2 行: V と Ū は、ラムダに入る前の Γ で指す。
    | .methName d _ ss es us ps =>
        d.Scoped nt pe nv ∧ Ty.VarsInList nt pe ss ∧ Eff.RhosInList pe es ∧
          DictEv.ScopedList nt pe nv us ∧ Ty.VarsInList nt pe ps
    | .nullCon _ ts => Ty.VarsInList nt pe ts
    | .opName _ ts => Ty.VarsInList nt pe ts
    | .conValue _ ts ps => Ty.VarsInList nt pe ts ∧ Ty.VarsInList nt pe ps
    | .literal _ | .negInt _ | .negFloat _ | .negDecimal _ _ | .unit => True
    | .paren e => e.Scoped nt pe nv
    | .record _ ts _ es => Ty.VarsInList nt pe ts ∧ es.Scoped nt pe nv
    | .recordUpdate _ ts _ _ base es =>
        Ty.VarsInList nt pe ts ∧ base.Scoped nt pe nv ∧ es.Scoped nt pe nv
    | .conCall _ ts es => Ty.VarsInList nt pe ts ∧ es.Scoped nt pe nv
    | .call f es => f.Scoped nt pe nv ∧ es.Scoped nt pe nv
    | .pipe lhs rhs => lhs.Scoped nt pe nv ∧ rhs.Scoped nt pe nv
    | .partialCall f args r ε =>
        f.Scoped nt pe nv ∧ args.Scoped nt pe nv ∧ Ty.VarsIn nt pe r ∧ Eff.RhosIn pe ε
    | .partialCon _ ts args => Ty.VarsInList nt pe ts ∧ args.Scoped nt pe nv
    | .binary _ t lhs rhs => Ty.VarsIn nt pe t ∧ lhs.Scoped nt pe nv ∧ rhs.Scoped nt pe nv
    | .neg t e => Ty.VarsIn nt pe t ∧ e.Scoped nt pe nv
    | .not e => e.Scoped nt pe nv
    | .and lhs rhs | .or lhs rhs => lhs.Scoped nt pe nv ∧ rhs.Scoped nt pe nv
    | .list a es => Ty.VarsIn nt pe a ∧ es.Scoped nt pe nv
    | .listSpread a f before s after =>
        Ty.VarsIn nt pe a ∧ f.Scoped nt pe nv ∧ before.Scoped nt pe nv ∧
          s.Scoped nt pe nv ∧ after.Scoped nt pe nv
    | .interpolation parts es fs =>
        Ty.VarsInList nt pe (InterpPart.exprTypes parts) ∧ es.Scoped nt pe nv ∧ fs.Scoped nt pe nv
    | .lam ps r ε body =>
        Ty.VarsInList nt pe ps ∧ Ty.VarsIn nt pe r ∧ Eff.RhosIn pe ε ∧
          body.Scoped nt pe (ps.length + nv)
    | .ite c yes no => c.Scoped nt pe nv ∧ yes.Scoped nt pe nv ∧ no.Scoped nt pe nv
    | .elseIf c yes no => c.Scoped nt pe nv ∧ yes.Scoped nt pe nv ∧ no.Scoped nt pe nv
    | .ifOnly c yes => c.Scoped nt pe nv ∧ yes.Scoped nt pe nv
    | .matchE b e arms => Ty.VarsIn nt pe b ∧ e.Scoped nt pe nv ∧ arms.Scoped nt pe nv
    | .returnE a e => Ty.VarsIn nt pe a ∧ e.Scoped nt pe nv
    | .tryResult ts _ _ e | .tryOption ts _ _ e =>
        Ty.VarsInList nt pe ts ∧ e.Scoped nt pe nv
    | .withE _ e body => e.Scoped nt pe nv ∧ body.Scoped nt pe (nv + 1)
    | .lazyE body => body.Scoped nt pe nv
    | .handleE body cs => body.Scoped nt pe nv ∧ cs.Scoped nt pe nv
    | .resume k e => k < nv ∧ e.Scoped nt pe nv

  def Exprs.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : Exprs → Prop
    | .nil => True
    | .cons e es => e.Scoped nt pe nv ∧ es.Scoped nt pe nv

  def HoleArgs.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : HoleArgs → Prop
    | .nil => True
    | .expr e rest => e.Scoped nt pe nv ∧ rest.Scoped nt pe nv
    | .hole t rest => Ty.VarsIn nt pe t ∧ rest.Scoped nt pe nv

  /-- 選択肢には型注釈や自由変数がない。slots の範囲は AltsTy が検査する。 -/
  def Arms.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : Arms → Prop
    | .nil => True
    | .cons alts none body rest =>
        body.Scoped nt pe (Arm.bindersOf (Alternative.toCoreList alts) + nv) ∧ rest.Scoped nt pe nv
    | .cons alts (some guard) body rest =>
        guard.Scoped nt pe (Arm.bindersOf (Alternative.toCoreList alts) + nv) ∧
          body.Scoped nt pe (Arm.bindersOf (Alternative.toCoreList alts) + nv) ∧ rest.Scoped nt pe nv

  def Clauses.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : Clauses → Prop
    | .nil => True
    | .cons _ n ntys body rest =>
        body.Scoped (nt + ntys) pe (nv + 1 + n) ∧ rest.Scoped nt pe nv

  def Block.Scoped (nt : Nat) (pe : Nat → Prop) (nv : Nat) : Block → Prop
    | .empty => True
    | .last e | .lastDiscard e => e.Scoped nt pe nv
    | .lastBind _ t e => Ty.VarsIn nt pe t ∧ e.Scoped nt pe nv
    | .bind _ t e rest => Ty.VarsIn nt pe t ∧ e.Scoped nt pe nv ∧ rest.Scoped nt pe (nv + 1)
    | .discard e rest | .seq e rest => e.Scoped nt pe nv ∧ rest.Scoped nt pe nv
    | .lastPat _ _ t e => Ty.VarsIn nt pe t ∧ e.Scoped nt pe nv
    | .bindPat _ pat t e rest =>
        Ty.VarsIn nt pe t ∧ e.Scoped nt pe nv ∧ rest.Scoped nt pe (pat.binders + nv)
end

-- 01-12「型クラス」: 辞書の型 Dict[Cl, α] の α は宣言の型パラメータを指す。
-- 本体は辞書の引数と値の引数の両方を束縛した環境に置く。
def Def.Scoped (d : Def) : Prop :=
  Ty.VarsInList d.tparams.length (· < d.neffs) d.params ∧
    Ty.VarsIn d.tparams.length (· < d.neffs) d.ret ∧ Eff.RhosIn (· < d.neffs) d.eff ∧
    (∀ p ∈ d.dictParams, p.2 < d.tparams.length) ∧
    d.body.Scoped d.tparams.length (· < d.neffs) (d.dictParams.length + d.params.length)

-- 01-12「型クラス」D-Impl: β̄ と γ̄、ρ̄、d̄ と x̄ の束縛の範囲。
def ImplDecl.Scoped (D : Declarations) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    Ty.VarsIn id.tparams.length (fun _ => False) id.target ∧
    (∀ s u, id.supers s = some u → u.Scoped id.tparams.length (fun _ => False) id.dictParams.length) ∧
    (∀ cd m ms body, D.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
      body.Scoped (ms.tparams.length + id.tparams.length) (· < ms.neffs)
        (id.dictParams.length + ms.params.length))

/-- 構成子が一つだけのデータ型と、フィールドを取り出す関数の表。
フィールド名の解決は済んでいるため、名前ではなく位置を検査する。 -/
def Program.RecordsOk (p : Program) : Prop :=
  ∀ f c k, p.accessors f = some (c, k) → p.defs f = none ∧
    ∃ cd, p.cons c = some cd ∧ k < cd.args.length ∧
      (∀ c' cd', p.cons c' = some cd' → cd'.data = cd.data → c' = c)

def Program.WellFormed (p : Program) : Prop :=
  (∀ f d, p.defs f = some d → d.Scoped) ∧ (∀ c cd, p.cons c = some cd → cd.Scoped) ∧
    (∀ o od, p.ops o = some od → od.Scoped) ∧
    (∀ l os o, p.effects l = some os → o ∈ os → ∃ od, p.ops o = some od ∧ od.eff = l) ∧
    (∀ o od, p.ops o = some od → ∃ os, p.effects od.eff = some os ∧ o ∈ os) ∧
    -- 01-12「型クラス」: 型クラスのメソッドの宣言と D-Impl の定義の範囲。
    (∀ cl cd, p.classes cl = some cd → cd.Scoped) ∧
    (∀ i id, p.impls i = some id → id.Scoped p.declarations) ∧ p.RecordsOk

end Benitoite.Surface
