/-!
# コア計算の構文（段階 A）

設計書 01-12「コア計算と脱糖」の「構文」を書き写す。段階 A は最小実行版の範囲だけを扱う
（設計書 07-04「進め方」）。

01-12 との表現の違い（設計書 07-04「01-12 との対応」の表に記す）:

- 項の変数は de Bruijn の番号で表す。`λ(x1:A1, …, xn:An). M` は n 個の変数を一度に束縛し、
  本体の中で番号 0 が `xn`、番号 n-1 が `x1` を指す。
- 型パラメータ `α` とエフェクト変数 `ρ` は、それを宣言したトップレベルの関数の中での番号で表す。
  局所の束縛とラムダは多相にならない（ADR 0009）ので、型の中に型の変数を束縛する構成はない。
- エフェクトの集合は、エフェクトの原子から真偽値への関数で表す。集合の等しさを関数の等しさにして、
  `{IO, ρ}` と `{ρ, IO}` のような並びの違いを型の等しさに持ち込まないためである。
-/

namespace Benitoite.Core

/-- エフェクトの原子。01-12 の `e ::= IO | ρ`。`rho i` は、関数の宣言の i 番目のエフェクト変数。 -/
inductive Atom where
  | io
  | rho (i : Nat)
  deriving DecidableEq, Repr

/-- エフェクトの集合。01-12 の `ε ::= { e1, …, en }`。 -/
def Eff := Atom → Bool

namespace Eff

/-- 空集合 `{ }`。 -/
def empty : Eff := fun _ => false

/-- `{ IO }`。 -/
def io : Eff := fun a => a == .io

/-- 包含 `ε ⊆ ε'`。 -/
def Sub (ε ε' : Eff) : Prop := ∀ a, ε a = true → ε' a = true

/-- 和集合 `ε ∪ ε'`。 -/
def union (ε ε' : Eff) : Eff := fun a => ε a || ε' a

/-- エフェクト変数の置き換え `ε[Ē/ρ̄]`（01-12「構文」）。
番号が `es` の長さより小さい `rho i` を `es[i]` に置き換え、ほかの原子はそのまま残す。 -/
def substRho (es : List Eff) (ε : Eff) : Eff := fun a =>
  let kept := match a with
    | .io => ε .io
    | .rho i => if i < es.length then false else ε (.rho i)
  kept || (List.range es.length).any (fun i =>
    ε (.rho i) && match es[i]? with
      | some e => e a
      | none => false)

end Eff

/-- 基本型。01-12 の `ι`。 -/
inductive BaseTy where
  | integer | float | string | character | boolean | unit
  deriving DecidableEq, Repr

/-- 中身を見せない prelude の型。01-12 の `O`（段階 A では `IOError` だけ）。 -/
inductive OpaqueTy where
  | ioError
  deriving DecidableEq, Repr

/-- 代数的データ型の名前 `D`、構成子の名前 `C`、トップレベルの関数の名前 `f`、
組み込みの関数の名前 `b`。 -/
abbrev DataName := String
abbrev ConName := String
abbrev FunName := String
abbrev PrimName := String

/-- 型。01-12 の `A, B ::= ι | O | D[Ā] | List[A] | (Ā) → B ! ε | α`。
`tvar i` は、関数の宣言の i 番目の型パラメータ。 -/
inductive Ty where
  | base (ι : BaseTy)
  | opaque (o : OpaqueTy)
  | data (d : DataName) (args : List Ty)
  | list (a : Ty)
  | fn (params : List Ty) (ret : Ty) (eff : Eff)
  | tvar (i : Nat)

/-- 定数。01-12 の `c`（`Integer`・`Float`・`String`・`Character` の値、`true`、`false`、`()`、
IO の関数が返す `IOError` の値）。`IOError` の値の中身は扱わないので、番号で区別する。 -/
inductive Const where
  | integer (n : Int)
  | float (x : Float)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)
  | unit
  | ioError (id : Nat)

/-- 定数の型 `type(c)`（01-12「型付け規則」の V-Const）。 -/
def Const.type : Const → Ty
  | .integer _ => .base .integer
  | .float _ => .base .float
  | .string _ => .base .string
  | .character _ => .base .character
  | .boolean _ => .base .boolean
  | .unit => .base .unit
  | .ioError _ => .opaque .ioError

/-- パターンの定数の照合に使う、定数どうしの等しさ。P-Const は `Float` と `IOError` の定数を
パターンに許さないので、その二つは等しいと判定しない。 -/
def Const.matches : Const → Const → Bool
  | .integer a, .integer b => a == b
  | .string a, .string b => a == b
  | .character a, .character b => a == b
  | .boolean a, .boolean b => a == b
  | .unit, .unit => true
  | _, _ => false

/-- パターン。01-12 の `p ::= _ | x | c | C(p̄)`。変数のパターンが束縛する変数は、
左から順に番号を振る（`Pat.binders`）。 -/
inductive Pat where
  | wild
  | var
  | const (c : Const)
  | con (c : ConName) (args : List Pat)

mutual
  /-- 値。01-12 の `V, W`。 -/
  inductive Val where
    | var (i : Nat)
    | const (c : Const)
    /-- `f[T̄; Ē]` -/
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
    /-- `b[T̄; Ē]` -/
    | prim (b : PrimName) (tys : List Ty) (effs : List Eff)
    /-- `λ(x1:A1, …, xn:An). M` -/
    | lam (params : List Ty) (body : Comp)
    /-- `C[T̄](V̄)` -/
    | con (c : ConName) (tys : List Ty) (args : List Val)
    /-- `[V1, …, Vn]` -/
    | list (elems : List Val)

  /-- 計算。01-12 の `M, N`。 -/
  inductive Comp where
    | ret (v : Val)
    /-- `let x ⇐ M in N`。N の中で番号 0 が x を指す。 -/
    | letIn (m : Comp) (n : Comp)
    | app (f : Val) (args : List Val)
    | ite (v : Val) (m n : Comp)
    /-- `match V { p1 ⇒ M1 | … }`。各分岐の本体の中で、パターンが束縛した変数は、
    最後に束縛した変数を番号 0 とする。 -/
    | «match» (v : Val) (arms : List (Pat × Comp))
end

/-- トップレベルの関数の定義。01-12 の `fn f[ᾱ; ρ̄](x1:A1, …, xn:An) : B ! ε = M`。
`ntys` と `neffs` は ᾱ と ρ̄ の個数である。 -/
structure Def where
  ntys : Nat
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp

/-- 代数的データ型の構成子の宣言。構成子 `C` は `D[ᾱ]` の構成子で、引数の型は `C̄` である。
`args` の中の `tvar i` は `D` の i 番目の型パラメータを指す。 -/
structure ConDecl where
  data : DataName
  ntys : Nat
  args : List Ty

/-- プログラム。01-12 の定義の集まり Σ と、型の宣言の集まり。 -/
structure Program where
  defs : FunName → Option Def
  cons : ConName → Option ConDecl

end Benitoite.Core
