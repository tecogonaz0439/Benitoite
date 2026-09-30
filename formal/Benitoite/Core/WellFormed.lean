import Benitoite.Core.Typing

/-!
# 型とエフェクトの変数の範囲（段階 A）

01-12 は、型パラメータ ᾱ とエフェクト変数 ρ̄ を名前で書き、関数の宣言 `fn f[ᾱ; ρ̄]` が束縛する。
形式化では番号で表す（`Syntax.lean`）ので、定義の中の番号が、その定義が宣言した個数より小さいこと
（名前で書けば、宣言していない名前を使っていないこと）を別に言明する。01-12 では、この条件は
名前の束縛として暗黙に成り立っている。

同じ述語で、01-12 の性質 3 の「M がエフェクト変数を含まない」も表す。
-/

namespace Benitoite.Core

/-- エフェクトの集合の中のエフェクト変数の番号が、すべて `pe` を満たす。 -/
def Eff.RhosIn (pe : Nat → Prop) (ε : Eff) : Prop :=
  ∀ i, ε (.rho i) = true → pe i

mutual
  /-- 型の中の型パラメータの番号が `pt` を、エフェクト変数の番号が `pe` を満たす。 -/
  def Ty.VarsIn (pt pe : Nat → Prop) : Ty → Prop
    | .base _ => True
    | .opaque _ => True
    | .data _ args => Ty.VarsInList pt pe args
    | .list a => Ty.VarsIn pt pe a
    | .fn params ret eff => Ty.VarsInList pt pe params ∧ Ty.VarsIn pt pe ret ∧ Eff.RhosIn pe eff
    | .tvar i => pt i

  def Ty.VarsInList (pt pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | a :: as => Ty.VarsIn pt pe a ∧ Ty.VarsInList pt pe as
end

def Eff.RhosInList (pe : Nat → Prop) : List Eff → Prop
  | [] => True
  | e :: es => Eff.RhosIn pe e ∧ Eff.RhosInList pe es

mutual
  /-- 値の中に現れる型とエフェクトの変数の番号が、`pt` と `pe` を満たす。 -/
  def Val.VarsIn (pt pe : Nat → Prop) : Val → Prop
    | .var _ => True
    | .const _ => True
    | .fnRef _ tys effs => Ty.VarsInList pt pe tys ∧ Eff.RhosInList pe effs
    | .prim _ tys effs => Ty.VarsInList pt pe tys ∧ Eff.RhosInList pe effs
    | .lam params body => Ty.VarsInList pt pe params ∧ Comp.VarsIn pt pe body
    | .con _ tys args => Ty.VarsInList pt pe tys ∧ Val.VarsInList pt pe args
    | .list elems => Val.VarsInList pt pe elems

  def Val.VarsInList (pt pe : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.VarsIn pt pe v ∧ Val.VarsInList pt pe vs

  def Comp.VarsIn (pt pe : Nat → Prop) : Comp → Prop
    | .ret v => Val.VarsIn pt pe v
    | .letIn m n => Comp.VarsIn pt pe m ∧ Comp.VarsIn pt pe n
    | .app f args => Val.VarsIn pt pe f ∧ Val.VarsInList pt pe args
    | .ite v m n => Val.VarsIn pt pe v ∧ Comp.VarsIn pt pe m ∧ Comp.VarsIn pt pe n
    | .match v arms => Val.VarsIn pt pe v ∧ Comp.VarsInArms pt pe arms

  def Comp.VarsInArms (pt pe : Nat → Prop) : List (Pat × Comp) → Prop
    | [] => True
    | (_, m) :: arms => Comp.VarsIn pt pe m ∧ Comp.VarsInArms pt pe arms
end

/-- 定義の中の型パラメータとエフェクト変数が、その定義が宣言したものに限られる。 -/
def Def.Scoped (d : Def) : Prop :=
  let pt := (· < d.ntys)
  let pe := (· < d.neffs)
  Ty.VarsInList pt pe d.params ∧ Ty.VarsIn pt pe d.ret ∧ Eff.RhosIn pe d.eff ∧
    Comp.VarsIn pt pe d.body

/-- 構成子の引数の型の中の型パラメータが、代数的データ型が宣言したものに限られ、
エフェクト変数を含まない。 -/
def ConDecl.Scoped (cd : ConDecl) : Prop :=
  Ty.VarsInList (· < cd.ntys) (fun _ => False) cd.args

/-- 組み込みの関数の型の中の型パラメータとエフェクト変数が、宣言したものに限られる。 -/
def PrimSig.Scoped (s : PrimSig) : Prop :=
  let pt := (· < s.ntys)
  let pe := (· < s.neffs)
  Ty.VarsInList pt pe s.params ∧ Ty.VarsIn pt pe s.ret ∧ Eff.RhosIn pe s.eff

/-- プログラムのすべての定義と構成子の宣言が、宣言した変数だけを使う。 -/
def Program.WellFormed (P : Program) : Prop :=
  (∀ f d, P.defs f = some d → d.Scoped) ∧ (∀ c cd, P.cons c = some cd → cd.Scoped)

/-- 01-12 の性質 3 の「M がエフェクト変数を含まない」。 -/
def Comp.NoEffVars (m : Comp) : Prop :=
  Comp.VarsIn (fun _ => True) (fun _ => False) m

end Benitoite.Core
