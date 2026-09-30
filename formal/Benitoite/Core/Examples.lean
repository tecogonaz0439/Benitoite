import Benitoite.Core.Semantics

/-!
# 抽象機械の実行の例（段階 A）

小さなコア計算のプログラムを `run` で実行し、01-12 の規則から期待する結果と比べる。
書き写しの誤りを証明の前に見つけるためのものであり、定理ではない（設計書 07-04「道具と置き場所」）。
期待と食い違うと `decide` が失敗し、`lake build` が止まる。
-/

namespace Benitoite.Core.Examples

open Benitoite.Core

/-! ## 例で使う組み込みの関数とプログラム -/

def intTy : Ty := .base .integer
def unitTy : Ty := .base .unit

/-- 例の組み込みの関数。`add` と `divide` は IO を行わず、`print` は IO を行う。 -/
def builtins : Builtins where
  sig
    | "add" => some { ntys := 0, neffs := 0, params := [intTy, intTy], ret := intTy,
                      eff := Eff.empty, admits := fun _ => True, io := false }
    | "divide" => some { ntys := 0, neffs := 0, params := [intTy, intTy], ret := intTy,
                         eff := Eff.empty, admits := fun _ => True, io := false }
    | "print" => some { ntys := 0, neffs := 0, params := [intTy], ret := unitTy,
                        eff := Eff.io, admits := fun _ => True, io := true }
    | _ => none
  delta
    | "add", _, _, [.const (.integer a), .const (.integer b)] =>
        some (.val (.const (.integer (a + b))))
    | "divide", _, _, [.const (.integer _), .const (.integer 0)] => some (.err "DivisionByZero")
    | "divide", _, _, [.const (.integer a), .const (.integer b)] =>
        some (.val (.const (.integer (a.tdiv b))))
    | _, _, _, _ => none
  ioResponse
    | "print", _, _, [_], o => o = .val (.const .unit)
    | _, _, _, _, _ => False

/-- `print` の応答として常に `()` を返す。 -/
def oracle : Oracle := fun _ _ _ _ => .val (.const .unit)

def int (n : Int) : Val := .const (.integer n)

/-- 例のプログラム。

- `double(x: Integer) : Integer ! {} = add(x, x)`
- `apply[α, β; ρ](f: (α) → β ! {ρ}, x: α) : β ! {ρ} = f(x)`
- `data Option[α] = None | Some(α)` -/
def program : Program where
  defs
    | "double" => some { ntys := 0, neffs := 0, params := [intTy], ret := intTy,
                         eff := Eff.empty,
                         body := .app (.prim "add" [] []) [.var 0, .var 0] }
    | "apply" => some { ntys := 2, neffs := 1,
                        params := [.fn [.tvar 0] (.tvar 1) (fun a => a == .rho 0), .tvar 0],
                        ret := .tvar 1, eff := fun a => a == .rho 0,
                        -- 番号 0 が x、番号 1 が f
                        body := .app (.var 1) [.var 0] }
    | _ => none
  cons
    | "None" => some { data := "Option", ntys := 1, args := [] }
    | "Some" => some { data := "Option", ntys := 1, args := [.tvar 0] }
    | _ => none

/-- 実行の結果を、例で比べやすい形にしたもの。 -/
inductive Result where
  | returned (n : Int)
  | returnedUnit
  | error (r : String)
  | other
  deriving DecidableEq, Repr

def summarize : State × List Event → Result × Nat
  | (s, evs) =>
    let r := match s with
      | .run (.ret (.const (.integer n))) [] => .returned n
      | .run (.ret (.const .unit)) [] => .returnedUnit
      | .error r => .error r
      | _ => .other
    (r, evs.length)

def exec (m : Comp) : Result × Nat :=
  summarize (run program builtins oracle 1000 (.run m []) [])

/-! ## 例 -/

/-- `let y ⇐ double(21) in return y` は 42 を返し、IO の事象を伴わない（E-Let、E-Fun、E-Prim、
E-Return）。 -/
example : exec (.letIn (.app (.fnRef "double" [] []) [int 21]) (.ret (.var 0))) =
    (.returned 42, 0) := by decide

/-- `(λ(x: Integer, y: Integer). divide(x, y))(7, 2)` は 3 を返す。引数の並びと番号の対応
（番号 0 が最後の引数 y）を確かめる。 -/
example : exec (.app (.lam [intTy, intTy] (.app (.prim "divide" [] []) [.var 1, .var 0]))
    [int 7, int 2]) = (.returned 3, 0) := by decide

/-- 0 での除算は `error(r)` で止まり、継続を捨てる（E-Err）。 -/
example : exec (.letIn (.app (.prim "divide" [] []) [int 1, int 0]) (.ret (int 5))) =
    (.error "DivisionByZero", 0) := by decide

/-- `match Some[Integer](5) { None ⇒ return 0 | Some(x) ⇒ return add(x, 1) }` は、
照合する最初の分岐を選び、6 を返す（E-Match）。 -/
example : exec (.match (.con "Some" [intTy] [int 5])
    [(.con "None" [], .ret (int 0)),
     (.con "Some" [.var], .app (.prim "add" [] []) [.var 0, int 1])]) = (.returned 6, 0) := by
  decide

/-- `apply[Integer, Unit; {IO}](print, 3)` は IO の事象を一つ伴い、`()` を返す（E-Fun の型と
エフェクトの置き換え、E-IO）。 -/
example : exec (.app (.fnRef "apply" [intTy, unitTy] [Eff.io]) [.prim "print" [] [], int 3]) =
    (.returnedUnit, 1) := by decide

/-- `if true then return 1 else return 2` は 1 を返す（E-IfT）。 -/
example : exec (.ite (.const (.boolean true)) (.ret (int 1)) (.ret (int 2))) =
    (.returned 1, 0) := by decide

end Benitoite.Core.Examples
