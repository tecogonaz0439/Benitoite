import Benitoite.Release.Semantics

/-!
# 抽象機械の実行の例（段階 B）

小さなコア計算のプログラムを `run` で実行し、01-12 の初回リリース版の規則から期待する結果と比べる。
期待と食い違うと `decide` が失敗し、`lake build` が止まる。
-/

namespace Benitoite.Release.Examples

open Benitoite.Release

def intTy : Ty := .base .integer
def unitTy : Ty := .base .unit
def int (n : Int) : Val := .const (.integer n)

def sig (tps : List TParam) (ps : List Ty) (r : Ty) (e : Eff) (k : PrimKind)
    (op : Option EffName := none) : PrimSig :=
  { tparams := tps, neffs := 0, params := ps, ret := r, eff := e, admits := fun _ ts => ts.length = tps.length,
    kind := k, opEff := op }

/-- 例の組み込みの関数。`add` は IO を行わず、`print` は組み込みのエフェクト `Console.Write` の操作、
`open`・`close` はリソースを扱う。`new`・`get`・`set`・`update`・`force` はストアの操作である。 -/
def builtins : Builtins where
  sig
    | "add" => some (sig [] [intTy, intTy] intTy Eff.empty .pure)
    | "print" => some (sig [] [intTy] unitTy (Eff.single "Console.Write") .io (some "Console.Write"))
    | "exit" => some (sig [] [intTy] unitTy (Eff.single "Process.Exit") .exit (some "Process.Exit"))
    | "new" => some (sig [{}] [.tvar 0] (.reference (.tvar 0)) (Eff.single stateEff) .refNew)
    | "get" => some (sig [{}] [.reference (.tvar 0)] (.tvar 0) (Eff.single stateEff) .refGet)
    | "set" => some (sig [{}] [.reference (.tvar 0), .tvar 0] unitTy (Eff.single stateEff) .refSet)
    | "update" => some (sig [{}] [.reference (.tvar 0), .fn [.tvar 0] (.tvar 0) Eff.empty] unitTy
        (Eff.single stateEff) .refUpdate)
    | "force" => some (sig [{}] [.lazy (.tvar 0)] (.tvar 0) Eff.empty .force)
    | _ => none
  delta
    | "add", _, _, [.const (.integer a), .const (.integer b)] =>
        some (.val (.const (.integer (a + b))))
    | _, _, _, _ => none
  ioResponse
    | "print", _, _, [_], o => o = .val (.const .unit)
    | "exit", _, _, [.const (.integer n)], o => o = .exit n
    | _, _, _, _, _ => False
  releaseResponse _ r := r = none
  isResource o := o == "File"
  effects
    | "Console.Write" => some ["print"]
    | "Process.Exit" => some ["exit"]
    | "State" => some []
    | _ => none
  sat _ _ _ := True
  refGet := "get"
  refSet := "set"

def oracle : Oracle
  | "exit", _, _, [.const (.integer n)] => .exit n
  | _, _, _, _ => .val (.const .unit)

def rel : Val → Option ErrKind := fun _ => none

/-- 0 から 99 のうち、中身のない最初の場所。 -/
def fresh (σ : Store) : Nat :=
  ((List.range 100).find? fun l => match σ l with | none => true | some _ => false).getD 100

def semigroupMeths : MethName → Option MethSig
  | "combine" => some { tparams := [], neffs := 0, params := [.tvar 0, .tvar 0], ret := .tvar 0,
                        eff := Eff.empty }
  | _ => none

def monoidMeths : MethName → Option MethSig
  | "empty" => some { tparams := [], neffs := 0, params := [], ret := .tvar 0, eff := Eff.empty }
  | _ => none

def noSupers : ClassName → Option Val := fun _ => none

def semigroupIntMeths : MethName → Option Comp
  | "combine" => some (.app (.prim "add" [] []) [.var 1, .var 0])
  | _ => none

def monoidIntSupers : ClassName → Option Val
  | "Semigroup" => some (.dict "SemigroupInt" [] [])
  | _ => none

def monoidIntMeths : MethName → Option Comp
  | "empty" => some (.ret (int 0))
  | _ => none

/-- 環境は d, x, y の順（y が番号 0）。 -/
def semigroupBoxMeths : MethName → Option Comp
  | "combine" => some (.match (.var 1) [(.con "Box" [.var],
      .match (.var 1) [(.con "Box" [.var],
        .letIn (.meth (.var 4) "combine" [] [] [.var 1, .var 0])
          (.ret (.con "Box" [.tvar 0] [.var 0])))])])
  | _ => none

def semigroupInt : ImplDecl where
  tparams := []
  dictParams := []
  cls := "Semigroup"
  target := intTy
  supers := noSupers
  methods := semigroupIntMeths

def monoidInt : ImplDecl where
  tparams := []
  dictParams := []
  cls := "Monoid"
  target := intTy
  supers := monoidIntSupers
  methods := monoidIntMeths

def semigroupBox : ImplDecl where
  tparams := [{}]
  dictParams := [("Semigroup", 0)]
  cls := "Semigroup"
  target := .data "Box" [.tvar 0]
  supers := noSupers
  methods := semigroupBoxMeths

/-- 例のプログラム。

- `effect Abort { fail[T](message: String) -> T }`
- `effect Ask { ask() -> Integer }`
- `f() : Integer ! {} = let _ ⇐ escape 7 in return 1`（途中の `return` に当たる）
- `data Box[T] = Box(T)`
- `trait Semigroup[T] { combine(x: T, y: T) -> T }`、`trait Monoid[T: Semigroup] { empty() -> T }`
- `SemigroupInt : Semigroup[Integer]`（`combine` は `add`）、`MonoidInt : Monoid[Integer]`（`empty` は 0、
  上位の型クラスの辞書は `SemigroupInt[]()`）
- `SemigroupBox[T](d : Dict[Semigroup, T]) : Semigroup[Box[T]]`（`combine` は中身を d の `combine` で合わせる） -/
def program : Program where
  defs
    | "f" => some { tparams := [], neffs := 0, params := [], ret := intTy, eff := Eff.empty,
                    body := .letIn (.escape (int 7)) (.ret (int 1)) }
    | _ => none
  cons
    | "Box" => some { data := "Box", ntys := 1, args := [.tvar 0] }
    | _ => none
  ops
    | "fail" => some { eff := "Abort", tparams := [{}], params := [.base .string], ret := .tvar 0 }
    | "ask" => some { eff := "Ask", tparams := [], params := [], ret := intTy }
    | _ => none
  effects
    | "Abort" => some ["fail"]
    | "Ask" => some ["ask"]
    | _ => none
  classes
    | "Semigroup" => some { supers := [], methods := semigroupMeths }
    | "Monoid" => some { supers := ["Semigroup"], methods := monoidMeths }
    | _ => none
  impls
    | "SemigroupInt" => some semigroupInt
    | "MonoidInt" => some monoidInt
    | "SemigroupBox" => some semigroupBox
    | _ => none

inductive Result where
  | returned (n : Int)
  | returnedUnit
  | boxed (n : Int)
  | error (rs : List String)
  | exited (n : Int)
  | other
  deriving DecidableEq, Repr

def summarize : State × List Event → Result × Nat
  | (s, evs) =>
    let r := match s with
      | .run (.ret (.const (.integer n))) [] _ => .returned n
      | .run (.ret (.const .unit)) [] _ => .returnedUnit
      | .run (.ret (.con "Box" _ [.const (.integer n)])) [] _ => .boxed n
      | .error rs [] _ => .error rs
      | .exit n _ [] _ => .exited n
      | _ => .other
    (r, evs.length)

def exec (m : Comp) : Result × Nat :=
  summarize (run program builtins oracle rel fresh 1000 (.run m [] Store.empty) [])

def add (a b : Val) : Comp := .app (.prim "add" [] []) [a, b]

/-! ## 例 -/

/-- `handle (let x ⇐ fail[Integer]("bad") in add(x, 1)) with fail(m) k ⇒ return 0` は、`resume` せずに
0 を返す（E-Handle、E-Op、E-DropRel）。 -/
example : exec (.handle (.letIn (.app (.op "fail" [intTy]) [.const (.string "bad")]) (add (.var 0) (int 1)))
    [.mk (.user "fail") 1 1 (.ret (int 0))]) = (.returned 0, 0) := by decide

/-- `handle (let x ⇐ ask() in add(x, 1)) with ask() k ⇒ resume k 41` は 42 を返す（E-Resume、E-HRet、
E-Drop）。 -/
example : exec (.handle (.letIn (.app (.op "ask" []) []) (add (.var 0) (int 1)))
    [.mk (.user "ask") 0 0 (.resume (.var 0) (int 41))]) = (.returned 42, 0) := by decide

/-- 組み込みの操作 `print` を処理するハンドラの中の `print(3)` は、IO の事象を起こさない（E-OpPrim）。 -/
example : exec (.handle (.app (.prim "print" [] []) [int 3])
    [.mk (.prim "print") 1 0 (.resume (.var 0) (.const .unit))]) = (.returnedUnit, 0) := by decide

/-- ハンドラがなければ、`print(3)` は IO の事象を一つ起こす（E-IO）。 -/
example : exec (.app (.prim "print" [] []) [int 3]) = (.returnedUnit, 1) := by decide

/-- 同じ継続を二度再開すると、実行時エラー `ResumeTwice` で止まる（E-ResumeErr）。 -/
example : exec (.handle (.app (.op "ask" []) [])
    [.mk (.user "ask") 0 0 (.letIn (.resume (.var 0) (int 1)) (.resume (.var 1) (int 2)))]) =
    (.error ["ResumeTwice"], 0) := by decide

/-- `let r ⇐ new[Integer](1) in let _ ⇐ set[Integer](r, 5) in get[Integer](r)` は 5 を返す
（E-RefNew、E-RefSet、E-RefGet）。 -/
example : exec (.letIn (.app (.prim "new" [intTy] []) [int 1])
    (.letIn (.app (.prim "set" [intTy] []) [.var 0, int 5])
      (.app (.prim "get" [intTy] []) [.var 1]))) = (.returned 5, 0) := by decide

/-- `Reference.update` は、読んだ値に関数を適用して書き戻す（E-RefUpdate）。 -/
example : exec (.letIn (.app (.prim "new" [intTy] []) [int 1])
    (.letIn (.app (.prim "update" [intTy] []) [.var 0, .lam [intTy] (add (.var 0) (int 10))])
      (.app (.prim "get" [intTy] []) [.var 1]))) = (.returned 11, 0) := by decide

/-- `let l ⇐ lazy add(1, 2) in let _ ⇐ force(l) in force(l)` は 3 を返す。二度目の `force` は、一度目に
保存した値を使う（E-Lazy、E-Force、E-Update、E-ForceDone）。 -/
example : exec (.letIn (.lazyC (add (int 1) (int 2)))
    (.letIn (.app (.prim "force" [intTy] []) [.var 0])
      (.app (.prim "force" [intTy] []) [.var 1]))) = (.returned 3, 0) := by decide

/-- `f()` の本体の `escape 7` は、`f` の呼び出しの結果として 7 を返す（E-Fun の `mark`、E-EscLet、
E-EscMark）。 -/
example : exec (.letIn (.app (.fnRef "f" [] []) []) (add (.var 0) (int 100))) = (.returned 107, 0) := by
  decide

/-- `use` したリソースは、本体を終えた後に解放の事象を一つ起こす（E-Use、E-Release）。 -/
example : exec (.use (.const (.opaque "File" 1)) (.ret (int 1))) = (.returned 1, 1) := by decide

/-- 終了の状態は、継続に残る解放の枠を実行してから終わる（E-Exit、E-ExitRel）。 -/
example : exec (.use (.const (.opaque "File" 1)) (.app (.prim "exit" [] []) [int 3])) =
    (.exited 3, 2) := by decide

/-- `(MonoidInt[]()↑Semigroup).combine[;](1, 2)` は、上位の型クラスの辞書を取り出してから `combine` を呼び、
3 を返す（E-Super、E-Meth）。 -/
example : exec (.meth (.super (.dict "MonoidInt" [] []) "Semigroup") "combine" [] [] [int 1, int 2]) =
    (.returned 3, 0) := by decide

/-- `MonoidInt[]().empty[;]()` は 0 を返す（型クラスの引数を戻り値の型にだけ含むメソッド）。 -/
example : exec (.meth (.dict "MonoidInt" [] []) "empty" [] [] []) = (.returned 0, 0) := by decide

/-- `SemigroupBox[Integer](MonoidInt[]()↑Semigroup).combine[;](Box(1), Box(2))` は `Box(3)` を返す。実装の
メソッドの本体は、辞書の引数 d を通して `Integer` の `combine` を呼ぶ（E-Meth の辞書の引数の置き換え）。 -/
example : exec (.meth (.dict "SemigroupBox" [intTy] [.super (.dict "MonoidInt" [] []) "Semigroup"]) "combine"
    [] [] [.con "Box" [intTy] [int 1], .con "Box" [intTy] [int 2]]) = (.boxed 3, 0) := by decide

end Benitoite.Release.Examples
