import Benitoite.Release.TypeVariables

/-!
# 型とエフェクトの変数の範囲（段階 B）

型の変数は de Bruijn の番号で表す（`Syntax.lean`）。`VarsIn n pe` は、項の中の型の変数の番号が、その位置で
束縛されている個数（外側の `n` に、囲む節が束縛する個数を足したもの）より小さく、エフェクト変数の番号が
`pe` を満たすことを表す。

実行中の状態の項は、型の変数を含まない（`n = 0`）。01-12 では、実行は `⟨main[;](), [], ∅⟩` から
始まり、型パラメータを束縛しない環境で型が付くので、この条件は暗黙に成り立っている。形式化では、
E-Fun と E-Op が閉じた型だけを置き換えることを、この条件で示す。

項と宣言の型は、範囲の変数の個数の文脈 0 の `Ty.VarsIn 0` で読む。利用者の宣言と項には、不透明型と効果の名前の
原子の範囲の位置に範囲の変数（`Scope.Signature.Ix.rvar`）を置けない（問 3 の P1、設計書 01-12「型付け規則」）。
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
    | .fnRef _ tys effs => Ty.VarsInList 0 n pe tys ∧ Eff.VarsInList 0 n pe effs
    | .prim _ tys effs _ => Ty.VarsInList 0 n pe tys ∧ Eff.VarsInList 0 n pe effs
    | .lam names params body => NamesWF names params ∧ Ty.VarsInList 0 n pe params ∧ Comp.VarsIn n pe body (depth + params.length)
    | .con _ tys args => Ty.VarsInList 0 n pe tys ∧ Val.VarsInList n pe args depth
    | .list elems => Val.VarsInList n pe elems depth
    | .op _ tys => Ty.VarsInList 0 n pe tys
    | .raise t e => Ty.VarsIn 0 n pe t ∧ Ty.VarsIn 0 n pe e
    | .loc _ => True
    | .mapV ks vs => Val.VarsInList n pe ks depth ∧ Val.VarsInList n pe vs depth
    | .setV elems => Val.VarsInList n pe elems depth
    | .bytesV _ => True
    | .dict _ tys args => Ty.VarsInList 0 n pe tys ∧ Val.VarsInList n pe args depth
    | .super v _ => Val.VarsIn n pe v depth
    | .checked _ => True
    | .checkedRequest _ _ => True

  def Val.VarsInList (n : Nat) (pe : Nat → Prop) (vs : List Val) (depth : Nat := 0) : Prop :=
    match vs with
    | [] => True
    | v :: vs => Val.VarsIn n pe v depth ∧ Val.VarsInList n pe vs depth

  def Comp.VarsIn (n : Nat) (pe : Nat → Prop) (m : Comp) (depth : Nat := 0) : Prop :=
    match m with
    | .builderLet k body => (match k with | .list a => Ty.VarsIn 0 n pe a | _ => True) ∧
        Comp.VarsIn n pe body (depth + 1)
    | .builderOp k _ r args => (match k with | .list a => Ty.VarsIn 0 n pe a | _ => True) ∧
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
        Val.VarsIn n pe d depth ∧ Ty.VarsInList 0 n pe tys ∧ Eff.VarsInList 0 n pe effs ∧ Val.VarsInList n pe args depth

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
    | .fail e m :: cs => Ty.VarsIn 0 n pe e ∧ Comp.VarsIn (n + 1) pe m (depth + 2) ∧ Clause.VarsInList n pe cs depth
end

/-! ## 宣言の変数の範囲 -/

/-- 関数の定義の型（引数、戻り値、エフェクト）と本体は、宣言した型パラメータとエフェクト変数だけを使う。
本体の範囲は、E-Fun の後の状態が型の変数を含まないことに要る。 -/
def Def.Scoped (d : Def) : Prop :=
  NamesWF d.names d.params ∧
    Ty.VarsInList 0 d.ntys (· < d.neffs) d.params ∧ Ty.VarsIn 0 d.ntys (· < d.neffs) d.ret ∧
    Eff.VarsIn 0 d.ntys (· < d.neffs) d.eff ∧ Comp.VarsIn d.ntys (· < d.neffs) d.body d.params.length

def ConDecl.Scoped (cd : ConDecl) : Prop :=
  Ty.VarsInList 0 cd.ntys (fun _ => False) cd.args

def OpDecl.Scoped (od : OpDecl) : Prop :=
  NamesWF od.names od.params ∧
    Ty.VarsInList 0 od.tparams.length (fun _ => False) od.params ∧
    Ty.VarsIn 0 od.tparams.length (fun _ => False) od.ret

/-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数と範囲の変数だけを使う（`sig_scoped`・表層の `hsig`
が読む形）。範囲の位置は署名の範囲の変数の個数 `s.nranges` の文脈で読み、範囲の変数の番号の上限を確かめる（問 18
の行 4）。さらに次の二つの位置の条件を課す。

- 引数の範囲の変数は最上位の対象の位置（不透明型の引数）だけに置く（`PrimSig.TargetRangesOnly`）。具体化は引数の
  最上位の対象の位置だけを具体化するので、具体化した引数の型が範囲の変数を持たないための条件である（V-Prim の正則性）。
- 組み込みの操作の項目（`opEff = some l`）の結果の型は範囲の変数を持たない。節は操作の型を範囲の列 Top で具体化して
  型付け、継続へ結果の型の値を渡すので、結果の型が範囲の列で変わると、呼び出しの継続へ Top の型の値が渡る
  （`E_OpPrim` の保存）。

範囲の変数のない項目では、文脈 0 の旧の形と同じである（`PrimSig.scoped_iff_old`）。 -/
def PrimSig.Scoped (s : PrimSig) : Prop :=
  NamesWF s.names s.params ∧
    Ty.VarsInList s.nranges s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn s.nranges s.ntys (· < s.neffs) s.ret ∧
    Eff.VarsIn s.nranges s.ntys (· < s.neffs) s.eff ∧
    (∀ p ∈ s.params, (∃ o ix, p = .opaque o ix) ∨ Ty.VarsIn 0 s.ntys (· < s.neffs) p) ∧
    (∀ l, s.opEff = some l → Ty.VarsIn 0 s.ntys (· < s.neffs) s.ret)

/-- 組み込みの関数の型は、宣言した型パラメータとエフェクト変数と範囲の変数だけを使う。範囲の位置は署名の範囲の
変数の個数 `s.nranges` の文脈で読み、範囲の変数の番号の上限を確かめる（問 18 の行 4）。範囲の変数を置く位置は
制限しない（引数の対象の位置だけを具体化することは `PrimSig.inst` の定義が受け持つ。RV-PL10 重大1）。 -/
def PrimSig.ScopedRanges (s : PrimSig) : Prop :=
  NamesWF s.names s.params ∧
    Ty.VarsInList s.nranges s.ntys (· < s.neffs) s.params ∧ Ty.VarsIn s.nranges s.ntys (· < s.neffs) s.ret ∧
    Eff.VarsIn s.nranges s.ntys (· < s.neffs) s.eff

/-- メソッドの型は、メソッドの型パラメータ（番号 `0..g-1`）と型クラスの引数（番号 g）と、メソッドのエフェクト変数
だけを使う。 -/
def MethSig.Scoped (ms : MethSig) : Prop :=
  NamesWF ms.names ms.params ∧
    Ty.VarsInList 0 (ms.tparams.length + 1) (· < ms.neffs) ms.params ∧
    Ty.VarsIn 0 (ms.tparams.length + 1) (· < ms.neffs) ms.ret ∧ Eff.VarsIn 0 (ms.tparams.length + 1) (· < ms.neffs) ms.eff

def ClassDecl.Scoped (cd : ClassDecl) : Prop :=
  ∀ m ms, cd.methods m = some ms → ms.Scoped

/-- 実装の定義の辞書の引数の型、対象、上位の型クラスの辞書は、実装の型パラメータだけを使い、エフェクト変数を
使わない。メソッドの本体は、メソッドの型パラメータと実装の型パラメータ、メソッドのエフェクト変数だけを使う。 -/
def ImplDecl.Scoped (P : Program) (id : ImplDecl) : Prop :=
  (∀ p ∈ id.dictParams, p.2 < id.tparams.length) ∧
    Ty.VarsIn 0 id.tparams.length (fun _ => False) id.target ∧
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
