import Benitoite.Release.Typing

/-!
# 型とエフェクトの変数の範囲（段階 B）

型の変数は de Bruijn の番号で表す（`Syntax.lean`）。`VarsIn n pe` は、項の中の型の変数の番号が、その位置で
束縛されている個数（外側の `n` に、囲む節が束縛する個数を足したもの）より小さく、エフェクト変数の番号が
`pe` を満たすことを表す。

実行中の状態の項は、型の変数を含まない（`n = 0`）。01-12 では、実行は `⟨main[;](), [], ∅⟩` から
始まり、型パラメータを束縛しない環境で型が付くので、この条件は暗黙に成り立っている。形式化では、
E-Fun と E-Op が閉じた型だけを置き換えることを、この条件で示す。
-/

namespace Benitoite.Release

def Eff.RhosIn (pe : Nat → Prop) (ε : Eff) : Prop :=
  ∀ i, ε (.rho i) = true → pe i

mutual
  /-- 型の中の型の変数の番号が `n` より小さく、エフェクト変数の番号が `pe` を満たし、継続の型を含まない
  （項の中に書ける型である）。 -/
  def Ty.VarsIn (n : Nat) (pe : Nat → Prop) : Ty → Prop
    | .base _ => True
    | .opaque _ => True
    | .data _ args => Ty.VarsInList n pe args
    | .list a => Ty.VarsIn n pe a
    | .fn params ret eff => Ty.VarsInList n pe params ∧ Ty.VarsIn n pe ret ∧ Eff.RhosIn pe eff
    | .tvar i => i < n
    | .reference a => Ty.VarsIn n pe a
    | .lazy a => Ty.VarsIn n pe a
    -- 継続の型は、項に書く型に含めない（01-12「ハンドラ」）。
    | .cont _ _ _ => False
    | .map a b => Ty.VarsIn n pe a ∧ Ty.VarsIn n pe b
    | .set a => Ty.VarsIn n pe a
    | .bytes => True
    | .dict _ τ => Ty.VarsIn n pe τ
    | .tapp i args => i < n ∧ Ty.VarsInList n pe args
    | .ctor _ => True

  def Ty.VarsInList (n : Nat) (pe : Nat → Prop) : List Ty → Prop
    | [] => True
    | a :: as => Ty.VarsIn n pe a ∧ Ty.VarsInList n pe as
end

def Eff.RhosInList (pe : Nat → Prop) : List Eff → Prop
  | [] => True
  | e :: es => Eff.RhosIn pe e ∧ Eff.RhosInList pe es

mutual
  def Val.VarsIn (n : Nat) (pe : Nat → Prop) : Val → Prop
    | .var _ => True
    | .const _ => True
    | .fnRef _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    | .prim _ tys effs => Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs
    | .lam params body => Ty.VarsInList n pe params ∧ Comp.VarsIn n pe body
    | .con _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args
    | .list elems => Val.VarsInList n pe elems
    | .op _ tys => Ty.VarsInList n pe tys
    | .loc _ => True
    | .mapV ks vs => Val.VarsInList n pe ks ∧ Val.VarsInList n pe vs
    | .setV elems => Val.VarsInList n pe elems
    | .bytesV _ => True
    | .dict _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args
    | .super v _ => Val.VarsIn n pe v

  def Val.VarsInList (n : Nat) (pe : Nat → Prop) : List Val → Prop
    | [] => True
    | v :: vs => Val.VarsIn n pe v ∧ Val.VarsInList n pe vs

  def Comp.VarsIn (n : Nat) (pe : Nat → Prop) : Comp → Prop
    | .ret v => Val.VarsIn n pe v
    | .letIn m m' => Comp.VarsIn n pe m ∧ Comp.VarsIn n pe m'
    | .app f args => Val.VarsIn n pe f ∧ Val.VarsInList n pe args
    | .ite v m m' => Val.VarsIn n pe v ∧ Comp.VarsIn n pe m ∧ Comp.VarsIn n pe m'
    | .match v arms => Val.VarsIn n pe v ∧ Arm.VarsInList n pe arms
    | .lazyC m => Comp.VarsIn n pe m
    | .escape v => Val.VarsIn n pe v
    | .use v m => Val.VarsIn n pe v ∧ Comp.VarsIn n pe m
    | .handle m h => Comp.VarsIn n pe m ∧ Clause.VarsInList n pe h
    | .resume k v => Val.VarsIn n pe k ∧ Val.VarsIn n pe v
    | .meth d _ tys effs args =>
        Val.VarsIn n pe d ∧ Ty.VarsInList n pe tys ∧ Eff.RhosInList pe effs ∧ Val.VarsInList n pe args

  def Arm.VarsInList (n : Nat) (pe : Nat → Prop) : List Arm → Prop
    | [] => True
    | .mk _ none m :: arms => Comp.VarsIn n pe m ∧ Arm.VarsInList n pe arms
    | .mk _ (some g) m :: arms =>
        Comp.VarsIn n pe g ∧ Comp.VarsIn n pe m ∧ Arm.VarsInList n pe arms

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.VarsInList (n : Nat) (pe : Nat → Prop) : List Clause → Prop
    | [] => True
    | .mk _ _ k m :: cs => Comp.VarsIn (n + k) pe m ∧ Clause.VarsInList n pe cs
end

/-! ## 宣言の変数の範囲 -/

/-- 関数の定義の型（引数、戻り値、エフェクト）と本体は、宣言した型パラメータとエフェクト変数だけを使う。
本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。 -/
def Def.Scoped (d : Def) : Prop :=
  Ty.VarsInList d.ntys (· < d.neffs) d.params ∧ Ty.VarsIn d.ntys (· < d.neffs) d.ret ∧
    Eff.RhosIn (· < d.neffs) d.eff ∧ Comp.VarsIn d.ntys (· < d.neffs) d.body

def ConDecl.Scoped (cd : ConDecl) : Prop :=
  Ty.VarsInList cd.ntys (fun _ => False) cd.args

def OpDecl.Scoped (od : OpDecl) : Prop :=
  Ty.VarsInList od.tparams.length (fun _ => False) od.params ∧
    Ty.VarsIn od.tparams.length (fun _ => False) od.ret

def PrimSig.Scoped (s : PrimSig) : Prop :=
  Ty.VarsInList s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn s.ntys (· < s.neffs) s.ret ∧
    Eff.RhosIn (· < s.neffs) s.eff

/-- メソッドの型は、メソッドの型パラメータ（番号 `0..g-1`）と型クラスの引数（番号 g）と、メソッドのエフェクト変数
だけを使う。 -/
def MethSig.Scoped (ms : MethSig) : Prop :=
  Ty.VarsInList (ms.tparams.length + 1) (· < ms.neffs) ms.params ∧
    Ty.VarsIn (ms.tparams.length + 1) (· < ms.neffs) ms.ret ∧ Eff.RhosIn (· < ms.neffs) ms.eff

def ClassDecl.Scoped (cd : ClassDecl) : Prop :=
  ∀ m ms, cd.methods m = some ms → ms.Scoped

/-- 実装の定義の辞書の引数の型、対象、上位の型クラスの辞書は、実装の型パラメータだけを使い、エフェクト変数を
使わない。メソッドの本体は、メソッドの型パラメータと実装の型パラメータ、メソッドのエフェクト変数だけを使う。 -/
def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    Ty.VarsIn id.tparams.length (fun _ => False) id.target ∧
    (∀ s u, id.supers s = some u → Val.VarsIn id.tparams.length (fun _ => False) u) ∧
    (∀ cd m ms body, P.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
      Comp.VarsIn (ms.tparams.length + id.tparams.length) (· < ms.neffs) body)

def Program.WellFormed (P : Program) : Prop :=
  (∀ f d, P.defs f = some d → d.Scoped) ∧ (∀ c cd, P.cons c = some cd → cd.Scoped) ∧
    (∀ o od, P.ops o = some od → od.Scoped) ∧ (∀ cl cd, P.classes cl = some cd → cd.Scoped) ∧
    (∀ i id, P.impls i = some id → id.Scoped P)

/-- 01-12 の性質 3 の「M がエフェクト変数を含まない」と、型パラメータを束縛しない環境の項であること。 -/
def Comp.ClosedNoEffVars (m : Comp) : Prop :=
  Comp.VarsIn 0 (fun _ => False) m

end Benitoite.Release
