import Benitoite.Release.Refinement.Context

namespace Benitoite.Release.Refinement

abbrev Const := Benitoite.Release.Const
abbrev BuilderOp := Benitoite.Release.BuilderOp

def Const.type (c : Const) : Ty := embedTy (Benitoite.Release.Const.type c)

inductive BuilderKind where
  | string | list (element : Ty) | bytes

mutual
  /-- 値。 -/
  inductive Val where
    | var (i : Nat)
    | const (c : Const)
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
    /-- 組み込みの関数 `b[T̄; Ē; R̄]`。`rs` は具体化した範囲の列。 -/
    | prim (b : PrimName) (tys : List Ty) (effs : List Eff) (rs : List Scope.Domain.Range)
    | lam (names : List String) (params : List Ty) (body : Comp)
    | con (c : ConName) (tys : List Ty) (args : List Val)
    | list (elems : List Val)
    /-- 利用者が宣言したエフェクトの操作 `op[T̄]`。 -/
    | op (o : OpName) (tys : List Ty)
    /-- 型付きの中断。結果型は節の内側で一つ束縛する。 -/
    | raise (result error : Ty)
    /-- ストアの場所 ℓ（可変のセルと明示遅延）と、継続の場所 κ。 -/
    | loc (l : Nat)
    /-- マップ `{V1 ↦ W1, …, Vn ↦ Wn}`。鍵の並びと値の並びで表す。 -/
    | mapV (keys : List Val) (vals : List Val)
    /-- 集合 `{V1, …, Vn}`。 -/
    | setV (elems : List Val)
    /-- バイト列 `bytes(k1, …, kn)`。ki は `Byte` の値（`Const.byte` と同じく自然数で表す）。 -/
    | bytesV (bs : List Nat)
    /-- 実装の辞書 `I[T̄](V̄)`。 -/
    | dict (i : ImplName) (tys : List Ty) (args : List Val)
    /-- 上位の型クラスの辞書 `V↑S`。 -/
    | super (v : Val) (s : ClassName)
    /-- 検査済みの対象。対象自身に型や値の自由変数はない（設計書 01-12「構文」）。 -/
    | checked (t : Scope.Domain.Target)
    /-- 要求と検査済みの endpoint を保持する。型付けの葉では閉じた要求の型付けに加え、
    groundVal と reqTarget による端点一致を検査する。葉の規則は構文と別に追加する。 -/
    | checkedRequest (t : Scope.Domain.Target) (req : Val)

  inductive Comp where
    | builderLet (kind : BuilderKind) (body : Comp)
    | builderOp (kind : BuilderKind) (op : BuilderOp) (ref : LocalRef) (args : List Val)
    | ret (v : Val)
    | letIn (m : Comp) (n : Comp)
    | app (f : Val) (args : List Val)
    | ite (v : Val) (m n : Comp)
    /-- 選択肢とガードを持つ照合。Release の照合はこの構成の一種類だけである。 -/
    | «match» (v : Val) (arms : List Arm)
    /-- `lazy M` -/
    | lazyC (m : Comp)
    /-- `escape V` -/
    | escape (v : Val)
    /-- `use V in M` -/
    | use (v : Val) (m : Comp)
    /-- `handle M with H` -/
    | handle (m : Comp) (h : List Clause)
    /-- `resume κ V`。κ は節の変数か、継続の場所。 -/
    | resume (k : Val) (v : Val)
    /-- メソッドの呼び出し `V.m[S̄; Ē](W̄)`。 -/
    | meth (d : Val) (m : MethName) (tys : List Ty) (effs : List Eff) (args : List Val)

  /-- 節 `op(x̄) k ⇒ N`。`arity` は x̄ の個数、`ntys` は操作の型パラメータの個数である。N の中で、番号 0 が k、
  番号 1 から n が x̄ を最後の引数から順に指す。操作の型パラメータは、N の中の型の変数の番号 `0..ntys-1` である。 -/
  inductive Clause where
    | mk (op : OpRef) (arity : Nat) (ntys : Nat) (body : Comp)
    /-- 0番は利用不能、1番はエラーであり、本体だけが結果型を束縛する。 -/
    | fail (error : Ty) (body : Comp)

  /-- 照合の分岐。本体とガードは分岐ごとに一つだけ持つ。 -/
  inductive Arm where
    | mk (alts : List Alt) (guard : Option Comp) (body : Comp)
end

structure Def where
  tparams : List TParam
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp

private def Def.ntys (d : Def) : Nat := d.tparams.length

structure ConDecl where
  data : DataName
  ntys : Nat
  args : List Ty

/-- 利用者が宣言したエフェクトの操作 `function op[ᾱ](x̄: Ā) -> B` の宣言。型は
`∀ᾱ. (Ā) → B ! {L}` である（01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」）。 -/
structure OpDecl where
  eff : EffName
  tparams : List TParam
  names : List String
  params : List Ty
  ret : Ty
  /-- 制約の宣言順。params と names の先頭はこの列の辞書である。 -/
  dictParams : List (ClassName × Nat) := []

/-- 操作の辞書の型。組み込みの制約は辞書に含めない。 -/
private def OpDecl.dictTys (d : OpDecl) : List Ty :=
  d.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- 利用者に見える値の引数。コアの前置辞書を除く。 -/
private def OpDecl.valueParams (d : OpDecl) : List Ty := d.params.drop d.dictParams.length

/-- 利用者に見える契約名。 -/
private def OpDecl.valueNames (d : OpDecl) : List String := d.names.drop d.dictParams.length

/-- 型クラスのメソッドの型 `∀γ̄ ρ̄. (Ā) → B ! ε`（01-12 の C-Meth）。型の中では、メソッドの型パラメータ γ̄ が
番号 `0..g-1`（g は γ̄ の個数）、型クラスの引数 P が番号 g である。メソッドが自分の型クラスの制約を持つときは、
Ā がその制約ごとの辞書の型を値の引数の前に含む。 -/
structure MethSig where
  tparams : List TParam
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff

/-- 型クラスの宣言。上位の型クラスの並びと、メソッドの型。 -/
structure ClassDecl where
  supers : List ClassName
  methods : MethName → Option MethSig

/-- 実装の定義 `impl I[β̄](d̄ : Dict[Cl', β̄']) : Dict[Cl, τ] = { S1 = U1, …, Sl = Ul; m1 = D1, …, mk = Dk }`。
型の中では、実装の型パラメータ β̄ が番号 `0..b-1` である。`dictParams` は辞書の引数 d̄ の型 `Dict[Cl', β']` を、
型クラス Cl' と型パラメータ β' の番号の組で表す。`target` は τ、
`supers` は上位の型クラスごとの辞書 U、`methods` はメソッドごとの本体の定義 D の本体である。D の型パラメータ、
引数と戻り値の型、エフェクトは、D-Impl が型クラスの宣言から決めるので、本体だけを持つ。メソッドの本体の中では、
メソッドの型パラメータ γ̄ が番号 `0..g-1`、実装の型パラメータ β̄ が番号 `g..g+b-1` であり、値の変数は
辞書の引数 d̄ の後にメソッドの引数 x̄ を束縛した並びである。 -/
structure ImplDecl where
  tparams : List TParam
  dictParams : List (ClassName × Nat)
  cls : ClassName
  target : Ty
  supers : ClassName → Option Val
  methods : MethName → Option Comp

/-- 辞書の引数 d̄ の型 `Dict[Cl', β']` の並び。 -/
private def ImplDecl.dictTys (id : ImplDecl) : List Ty :=
  id.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- プログラム。定義の集まり Σ、型の宣言、エフェクトの宣言、型クラスの宣言と実装の定義。 -/
structure Program where
  defs : FunName → Option Def
  cons : ConName → Option ConDecl
  ops : OpName → Option OpDecl
  /-- 利用者が宣言したエフェクトの操作の一覧。 -/
  effects : EffName → Option (List OpName)
  classes : ClassName → Option ClassDecl
  impls : ImplName → Option ImplDecl


inductive Outcome where
  | val (v : Val)
  | err (r : ErrKind)
  | exit (n : Int)

structure PrimSig where
  tparams : List TParam
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
  admits : List TParam → List Ty → Prop
  kind : PrimKind
  /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
  opEff : Option EffName
  /-- 署名の範囲の変数ごとの対象の種類。範囲の変数 `Ix.rvar i` の i 番目の種類である。
  既定は空の列（範囲の変数のない旧の項目）。既定の空の列のまま `rvar` を書いた項目は、`PrimSig.Scoped` の
  番号の上限で拒否される（範囲を書かないと黙って Top になる既定引数とは別である）。 -/
  rkinds : List Scope.Domain.Kind := []
  /-- IO を行う項目の形（`Scope.Signature.IOShape`）。対象なし（`untargeted`）、旧 Top の対象あり
  （`topTargeted k`）、単一の対象（`single k p`。引数の位置 p が種類 k の範囲付きの値型）のどれかである。
  `Builtins.Assumptions` の `io_op`（形の検査 `Builtins.ShapeOk`）が効果・範囲の変数・引数と照らし合わせ、
  `io_target`（`TargetAgreement`）が観測の条件に使う。IO を行わない項目は読まない。既定は対象なし。 -/
  shape : Scope.Signature.IOShape := .untargeted

structure Builtins where
  sig : PrimName → Option PrimSig
  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（01-12「実行の規則」）。 -/
  delta : PrimName → List Ty → List Eff → List Scope.Domain.Range → List Val → Option Outcome
  /-- IO を行う組み込みの関数の応答と、その応答で作用した対象の観測（有限列）として起こりうるもの
  （設計書 01-12「実行の規則」。観測は応答の関係に含める）。 -/
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop
  /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
  releaseResponse : Val → Option ErrKind → Prop
  /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
  isResource : OpaqueName → Bool
  /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
  effects : EffName → Option (List PrimName)
  /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型（初回リリース版）」）。制約の並び `C` のもとで判定する。 -/
  sat : List TParam → Ty → TParam → Prop
  /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
  refGet : PrimName
  refSet : PrimName
  /-- エフェクトの名前の対象の種類（`File.Read`・`File.Write` は path、`Http.Connect` は endpoint）。対象を持たない
  名前は `none` である。表のデータであり、正しさは信頼の対象である（設計書 07-04「形式化で仮定するもの」）。
  `Builtins.Assumptions` の欄にはしない。既定は全て `none`。 -/
  effKind : EffName → Option Scope.Domain.Kind := fun _ => none
  /-- 範囲付きの値型の名前の対象の種類（`Scope.PathIn` は path、`Http.RequestIn` は endpoint）。既存の不透明型と
  資源の型は `none` である。表のデータであり、正しさは信頼の対象である。既定は全て `none`。 -/
  valKind : OpaqueName → Option Scope.Domain.Kind := fun _ => none
  /-- 組み込みの関数ごとの範囲の具体化の制約（明示拡大の被覆など。型引数の `admits` に当たる）。全て Top の列は
  この制約によらず許す（`Builtins.RangeAdmissible`）。表のデータであり、正しさは信頼の対象である。既定は何も
  許さない（Top の列だけを許す）。 -/
  admitsR : PrimName → List Scope.Domain.Range → Prop := fun _ _ => False
  /-- 範囲付きの値型の名前の値が保持する要求の型（`Http.RequestIn` は `Http.ClientRequest` のレコードの型）。検査済みの
  要求の値の規則 V-CheckedRequest が読む。表のデータであり、正しさは信頼の対象である。既定は全て `none`。 -/
  valContent : OpaqueName → Option Ty := fun _ => none

inductive LocTy where
  | builder (kind : BuilderKind)
  | ref (a : Ty)
  | lazy (a : Ty)
  | cont (b t : Ty) (ε : Eff) (r : Option Ty)

/-- ストアの型付け Ψ。 -/
abbrev StoreTy := Nat → Option LocTy


abbrev LocalCtx := List (Option BuilderKind)

/-- 数値の表現可能性と、標準対象型の裸 opaque の除外。 -/
def ConstOK (B : Builtins) : Const → Prop
  | .integer _ => True
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -79228162514264337593543950335 ≤ n ∧
      n ≤ 79228162514264337593543950335 ∧ scale ≤ 28
  | .opaque o _ => B.valKind o = none ∧ B.valContent o = none
  | _ => True

/-- 算術で観測できる値だけを整数項へ写す。 -/
def Val.toTerm? : Val → Option Term
  | .var i => some (.var i)
  | .const (.integer n) => some (.integer n.toInt)
  | .const (.integer8 n) | .const (.integer16 n) | .const (.integer32 n)
  | .const (.unsignedInteger16 n) | .const (.unsignedInteger32 n)
  | .const (.unsignedInteger64 n) => some (.integer n)
  | .const (.byte n) => some (.integer (Int.ofNat n))
  | _ => none

end Benitoite.Release.Refinement
