/-!
# コア計算の構文（段階 B）

設計書 01-12「コア計算と脱糖」の「初回リリース版の拡張」のうち、コア計算に構成を加えるものを書き写す。
段階 B1 は、制御の構成（ストア、`escape`、`with`、プロセスの終了、エフェクトの名前、ハンドラ）と、型パラメータの
組み込みの制約（OPEN-070、ADR 0297）を加えた。段階 B2 は、`Map`・`Set`・`Bytes` と、型クラスの辞書
（高カインド型を含む）を加える（設計書 07-04「進め方」）。段階 A（`Benitoite.Core`）の定義は最小実行版の
ものとして残し、段階 B は別の名前空間に写して広げる。段階 B2 は、段階 B1 の定義を同じ名前空間で広げる。

段階 A からの表現の違い（設計書 07-04「01-12 との対応」の表に記す）:

- 型の変数は、内側から数えた de Bruijn の番号で表す。関数の定義の本体では、定義の型パラメータが
  `0..n-1` である。`handle` の節は、操作の型パラメータを番号 `0..k-1` に束縛し、節の外側の型の変数の番号を
  k だけずらす（01-06「エフェクトの宣言とハンドラの型付け」の「その型パラメータをほかの何とも等しくない型として
  扱う」）。閉じた値は、節の内側へ運んでも変わらない。
- エフェクトの原子は、エフェクトの名前（モジュールと名前の組を一つの文字列で表す）とエフェクト変数である。
- 組み込みの関数のうち、ストアの操作（`Reference.new` など）とプロセスの終了は、組み込みの関数の種類
  （`PrimKind`）で区別する。
- 高カインドの型パラメータの型引数は、型構成子 `Ty.ctor φ` か、高カインドの型パラメータ `Ty.tvar j` である。
  型の置き換えは、`α[Ā]`（`Ty.tapp`）の α を型構成子に置き換えるとき、その型構成子を Ā に適用した型にする
  （`Ty.applyTo`）。型の種類（型パラメータが値の型か型構成子か、型構成子がとる型引数の個数）は検査しない。
-/

namespace Benitoite.Release

/-- エフェクトの名前。01-12「エフェクトの名前と開始状態」の `L`。宣言したモジュールと名前の組を、
一つの文字列で表す。 -/
abbrev EffName := String

/-- 状態を扱う組み込みの関数と解放のエフェクト `State`（01-07「可変のセル（初回リリース版）」）。 -/
def stateEff : EffName := "State"

/-- エフェクトの原子。01-12 の `e ::= L | ρ`。 -/
inductive Atom where
  | name (l : EffName)
  | rho (i : Nat)
  deriving DecidableEq, Repr

/-- エフェクトの集合。 -/
def Eff := Atom → Bool

namespace Eff

def empty : Eff := fun _ => false

/-- 名前一つの集合 `{L}`。 -/
def single (l : EffName) : Eff := fun a => a == .name l

def Sub (ε ε' : Eff) : Prop := ∀ a, ε a = true → ε' a = true

def union (ε ε' : Eff) : Eff := fun a => ε a || ε' a

/-- エフェクト変数の置き換え `ε[Ē/ρ̄]`（段階 A と同じ）。 -/
def substRho (es : List Eff) (ε : Eff) : Eff := fun a =>
  let kept := match a with
    | .name l => ε (.name l)
    | .rho i => if i < es.length then false else ε (.rho i)
  kept || (List.range es.length).any (fun i =>
    ε (.rho i) && match es[i]? with
      | some e => e a
      | none => false)

end Eff

/-- 基本型。01-12 の `ι`（初回リリース版の `Byte`・`Decimal` を含む）。 -/
inductive BaseTy where
  | integer | float | string | character | boolean | unit | byte | decimal
  deriving DecidableEq, Repr

abbrev DataName := String
abbrev ConName := String
abbrev FunName := String
abbrev PrimName := String
abbrev OpName := String
/-- 中身を見せない型の名前（`IOError`・`NetworkError`・リソースの型など）。01-12 の `O`。 -/
abbrev OpaqueName := String
abbrev ClassName := String
abbrev ImplName := String
abbrev MethName := String

/-- 型構成子 φ（01-12「型クラス」の `τ ::= A | φ`）。型引数を与えずに書いた型構成子であり、高カインドの
型パラメータの型引数と、型構成子を引数にとる型クラスの辞書の型に現れる。高カインドの型パラメータそのものを
型構成子として書く形は、型の変数 `Ty.tvar` で表す。 -/
inductive TyCon where
  | data (d : DataName)
  | list
  | set
  | map
  | reference
  | lazy

/-- 型。01-12 の型に、初回リリース版の拡張が加える型を加えたもの。
`tvar i` は番号 i の型パラメータ。`cont b t ε` は継続の型 `Cont(B → T ! ε)`。`dict cl τ` は辞書の型
`Dict[Cl, τ]`、`tapp i Ā` は型構成子を表す型パラメータの適用 `α[Ā]`、`ctor φ` は型構成子 φ である。 -/
inductive Ty where
  | base (ι : BaseTy)
  | opaque (o : OpaqueName)
  | data (d : DataName) (args : List Ty)
  | list (a : Ty)
  | fn (params : List Ty) (ret : Ty) (eff : Eff)
  | tvar (i : Nat)
  | reference (a : Ty)
  | lazy (a : Ty)
  | cont (b : Ty) (t : Ty) (eff : Eff)
  | map (k : Ty) (v : Ty)
  | set (a : Ty)
  | bytes
  | dict (cl : ClassName) (τ : Ty)
  | tapp (i : Nat) (args : List Ty)
  | ctor (φ : TyCon)

/-- 型パラメータに付けた組み込みの制約（01-06「組み込みの制約（初回リリース版）」、ADR 0297）。 -/
structure TParam where
  equality : Bool := false
  key : Bool := false

/-- 鍵の型であるという制約（V-Map・V-Set の「A は鍵の型である」）。 -/
def TParam.keyC : TParam := { key := true }

/-- 定数。`O` の型の値（`IOError` の値、リソースなど）は、型の名前と番号で表す。 -/
inductive Const where
  | integer (n : Int)
  | float (x : Float)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)
  | unit
  | byte (n : Nat)
  | decimal (n : Int) (scale : Nat)
  | opaque (o : OpaqueName) (id : Nat)

def Const.type : Const → Ty
  | .integer _ => .base .integer
  | .float _ => .base .float
  | .string _ => .base .string
  | .character _ => .base .character
  | .boolean _ => .base .boolean
  | .unit => .base .unit
  | .byte _ => .base .byte
  | .decimal _ _ => .base .decimal
  | .opaque o _ => .opaque o

/-- パターンの定数の照合。P-Const は `Float`・`Byte`・`Decimal` と `O` の型の値をパターンに許さないので、
その四つは等しいと判定しない。 -/
def Const.matches : Const → Const → Bool
  | .integer a, .integer b => a == b
  | .string a, .string b => a == b
  | .character a, .character b => a == b
  | .boolean a, .boolean b => a == b
  | .unit, .unit => true
  | _, _ => false

inductive Pat where
  | wild
  | var
  | const (c : Const)
  | con (c : ConName) (args : List Pat)

/-- 節が処理する操作。利用者が宣言したエフェクトの操作と、組み込みのエフェクトの操作
（外部に作用する組み込みの関数）がある（01-12「ハンドラ」）。 -/
inductive OpRef where
  | user (o : OpName)
  | prim (b : PrimName)
  deriving DecidableEq

mutual
  /-- 値。 -/
  inductive Val where
    | var (i : Nat)
    | const (c : Const)
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
    | prim (b : PrimName) (tys : List Ty) (effs : List Eff)
    | lam (params : List Ty) (body : Comp)
    | con (c : ConName) (tys : List Ty) (args : List Val)
    | list (elems : List Val)
    /-- 利用者が宣言したエフェクトの操作 `op[T̄]`。 -/
    | op (o : OpName) (tys : List Ty)
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

  inductive Comp where
    | ret (v : Val)
    | letIn (m : Comp) (n : Comp)
    | app (f : Val) (args : List Val)
    | ite (v : Val) (m n : Comp)
    | «match» (v : Val) (arms : List (Pat × Comp))
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
end

def Clause.op : Clause → OpRef
  | .mk o _ _ _ => o

def Clause.arity : Clause → Nat
  | .mk _ n _ _ => n

def Clause.ntys : Clause → Nat
  | .mk _ _ k _ => k

def Clause.body : Clause → Comp
  | .mk _ _ _ m => m

/-- トップレベルの関数の定義。`fn f[ᾱ : c̄; ρ̄](x̄:Ā) : B ! ε = M`。`tparams` は型パラメータと、その
組み込みの制約である（ADR 0297）。 -/
structure Def where
  tparams : List TParam
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp

def Def.ntys (d : Def) : Nat := d.tparams.length

structure ConDecl where
  data : DataName
  ntys : Nat
  args : List Ty

/-- 利用者が宣言したエフェクトの操作 `function op[ᾱ](x̄: Ā) -> B` の宣言。型は
`∀ᾱ. (Ā) → B ! {L}` である（01-06「エフェクトの宣言とハンドラの型付け」）。 -/
structure OpDecl where
  eff : EffName
  tparams : List TParam
  params : List Ty
  ret : Ty

/-- 型クラスのメソッドの型 `∀γ̄ ρ̄. (Ā) → B ! ε`（01-12 の C-Meth）。型の中では、メソッドの型パラメータ γ̄ が
番号 `0..g-1`（g は γ̄ の個数）、型クラスの引数 P が番号 g である。メソッドが自分の型クラスの制約を持つときは、
Ā がその制約ごとの辞書の型を値の引数の前に含む。 -/
structure MethSig where
  tparams : List TParam
  neffs : Nat
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
def ImplDecl.dictTys (id : ImplDecl) : List Ty :=
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

end Benitoite.Release
