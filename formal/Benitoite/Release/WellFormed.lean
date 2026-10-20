import Benitoite.Release.TypeVariables

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

def Eff.RhosInList (pe : Nat → Prop) : List Eff → Prop
  | [] => True
  | e :: es => Eff.RhosIn pe e ∧ Eff.RhosInList pe es

mutual
  def Val.VarsIn (n : Nat) (pe : Nat → Prop) (v : Val) (depth : Nat := 0) : Prop :=
    match v with
    | .var _ => True
    | .const _ => True
    | .fnRef _ tys effs => Ty.VarsInList n pe tys ∧ Eff.VarsInList n pe effs
    | .prim _ tys effs => Ty.VarsInList n pe tys ∧ Eff.VarsInList n pe effs
    | .lam names params body => NamesWF names params ∧ Ty.VarsInList n pe params ∧ Comp.VarsIn n pe body (depth + params.length)
    | .con _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args depth
    | .list elems => Val.VarsInList n pe elems depth
    | .op _ tys => Ty.VarsInList n pe tys
    | .raise t e => Ty.VarsIn n pe t ∧ Ty.VarsIn n pe e
    | .loc _ => True
    | .mapV ks vs => Val.VarsInList n pe ks depth ∧ Val.VarsInList n pe vs depth
    | .setV elems => Val.VarsInList n pe elems depth
    | .bytesV _ => True
    | .dict _ tys args => Ty.VarsInList n pe tys ∧ Val.VarsInList n pe args depth
    | .super v _ => Val.VarsIn n pe v depth

  def Val.VarsInList (n : Nat) (pe : Nat → Prop) (vs : List Val) (depth : Nat := 0) : Prop :=
    match vs with
    | [] => True
    | v :: vs => Val.VarsIn n pe v depth ∧ Val.VarsInList n pe vs depth

  def Comp.VarsIn (n : Nat) (pe : Nat → Prop) (m : Comp) (depth : Nat := 0) : Prop :=
    match m with
    | .builderLet k body => (match k with | .list a => Ty.VarsIn n pe a | _ => True) ∧
        Comp.VarsIn n pe body (depth + 1)
    | .builderOp k _ r args => (match k with | .list a => Ty.VarsIn n pe a | _ => True) ∧
        r.Scoped depth ∧ Val.VarsInList n pe args depth
    | .ret v => Val.VarsIn n pe v depth
    | .letIn m m' => Comp.VarsIn n pe m depth ∧ Comp.VarsIn n pe m' (depth + 1)
    | .app f args => Val.VarsIn n pe f depth ∧ Val.VarsInList n pe args depth
    | .ite v m m' => Val.VarsIn n pe v depth ∧ Comp.VarsIn n pe m depth ∧ Comp.VarsIn n pe m' depth
    | .match v arms => Val.VarsIn n pe v depth ∧ Arm.VarsInList n pe arms depth
    | .lazyC m => Comp.VarsIn n pe m depth
    | .escape v => Val.VarsIn n pe v depth
    | .use v m => Val.VarsIn n pe v depth ∧ Comp.VarsIn n pe m depth
    | .handle m h => Comp.VarsIn n pe m depth ∧ Clause.VarsInList n pe h depth
    | .resume k v => Val.VarsIn n pe k depth ∧ Val.VarsIn n pe v depth
    | .meth d _ tys effs args =>
        Val.VarsIn n pe d depth ∧ Ty.VarsInList n pe tys ∧ Eff.VarsInList n pe effs ∧ Val.VarsInList n pe args depth

  def Arm.VarsInList (n : Nat) (pe : Nat → Prop) (arms : List Arm) (depth : Nat := 0) : Prop :=
    match arms with
    | [] => True
    | .mk alts none m :: arms => Comp.VarsIn n pe m (depth + Arm.bindersOf alts) ∧ Arm.VarsInList n pe arms depth
    | .mk alts (some g) m :: arms =>
        Comp.VarsIn n pe g (depth + Arm.bindersOf alts) ∧ Comp.VarsIn n pe m (depth + Arm.bindersOf alts) ∧ Arm.VarsInList n pe arms depth

  /-- 節の本体では、操作の型パラメータの個数だけ、束縛された型の変数が増える。 -/
  def Clause.VarsInList (n : Nat) (pe : Nat → Prop) (cs : List Clause) (depth : Nat := 0) : Prop :=
    match cs with
    | [] => True
    | .mk _ arity k m :: cs => Comp.VarsIn (n + k) pe m (depth + arity + 1) ∧ Clause.VarsInList n pe cs depth
    | .fail e m :: cs => Ty.VarsIn n pe e ∧ Comp.VarsIn (n + 1) pe m (depth + 2) ∧ Clause.VarsInList n pe cs depth
end

/-! ## 宣言の変数の範囲 -/

/-- 関数の定義の型（引数、戻り値、エフェクト）と本体は、宣言した型パラメータとエフェクト変数だけを使う。
本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。 -/
def Def.Scoped (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    Ty.VarsInList d.ntys (· < d.neffs) d.params ∧ Ty.VarsIn d.ntys (· < d.neffs) d.ret ∧
    Eff.VarsIn d.ntys (· < d.neffs) d.eff ∧ Comp.VarsIn d.ntys (· < d.neffs) d.body d.params.length

def ConDecl.Scoped (cd : ConDecl) : Prop :=
  Ty.VarsInList cd.ntys (fun _ => False) cd.args

def OpDecl.Scoped (od : OpDecl) : Prop :=
  NamesWF od.names od.params ∧
    Ty.VarsInList od.tparams.length (fun _ => False) od.params ∧
    Ty.VarsIn od.tparams.length (fun _ => False) od.ret

def PrimSig.Scoped (s : PrimSig) : Prop :=
  NamesWF s.names s.params ∧
    Ty.VarsInList s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn s.ntys (· < s.neffs) s.ret ∧
    Eff.VarsIn s.ntys (· < s.neffs) s.eff

/-- メソッドの型は、メソッドの型パラメータ（番号 `0..g-1`）と型クラスの引数（番号 g）と、メソッドのエフェクト変数
だけを使う。 -/
def MethSig.Scoped (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    Ty.VarsInList (ms.tparams.length + 1) (· < ms.neffs) ms.params ∧
    Ty.VarsIn (ms.tparams.length + 1) (· < ms.neffs) ms.ret ∧ Eff.VarsIn (ms.tparams.length + 1) (· < ms.neffs) ms.eff

def ClassDecl.Scoped (cd : ClassDecl) : Prop :=
  ∀ m ms, cd.methods m = some ms → ms.Scoped

/-- 実装の定義の辞書の引数の型、対象、上位の型クラスの辞書は、実装の型パラメータだけを使い、エフェクト変数を
使わない。メソッドの本体は、メソッドの型パラメータと実装の型パラメータ、メソッドのエフェクト変数だけを使う。 -/
def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    Ty.VarsIn id.tparams.length (fun _ => False) id.target ∧
    (∀ s u, id.supers s = some u → Val.VarsIn id.tparams.length (fun _ => False) u) ∧
    (∀ cd m ms body, P.classes id.cls = some cd → cd.methods m = some ms → id.methods m = some body →
      Comp.VarsIn (ms.tparams.length + id.tparams.length) (· < ms.neffs) body (id.dictTys.length + ms.params.length))

def Program.WellFormed (P : Program) : Prop :=
  (∀ f d, P.defs f = some d → d.Scoped) ∧ (∀ c cd, P.cons c = some cd → cd.Scoped) ∧
    (∀ o od, P.ops o = some od → od.Scoped) ∧ (∀ cl cd, P.classes cl = some cd → cd.Scoped) ∧
    (∀ i id, P.impls i = some id → id.Scoped P)

/-- 01-12 の性質 3 の「M がエフェクト変数を含まない」と、型パラメータを束縛しない環境の項であること。 -/
def Comp.ClosedNoEffVars (m : Comp) : Prop :=
  Comp.VarsIn 0 (fun _ => False) m

end Benitoite.Release
