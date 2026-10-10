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
  | "combine" => some (.match (.var 1) [.mk [⟨.con "Box" [.var], [0]⟩] none
      (.match (.var 1) [.mk [⟨.con "Box" [.var], [0]⟩] none
        (.letIn (.meth (.var 4) "combine" [] [] [.var 1, .var 0])
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

/-! ## 拡張したパターン（C7）

実行結果を境界として、選択肢の順、束縛の対応、ガードの偽で飛ばす範囲、範囲の両端、
リストの長さと束縛を確かめる。Box の例のガードなし・単一選択肢の照合では、これらの誤りを検出できない。
-/

/-- A(x, y), B(y, x) の二番目の選択肢では、x は二番目の束縛になる。 -/
def choiceMatch : Comp := .match (.con "B" [] [int 10, int 20])
  [.mk [⟨.con "A" [.var, .var], [0, 1]⟩, ⟨.con "B" [.var, .var], [1, 0]⟩] none (.ret (.var 1)),
   .mk [⟨.wild, []⟩] none (.ret (int 99))]

example : exec choiceMatch = (.returned 20, 0) := by decide

/-- 二つとも照合する選択肢は、左の選択肢の束縛を使う。 -/
example : exec (.match (.list [int 10, int 20])
    [.mk [⟨.list [.var, .wild] none [], [0]⟩, ⟨.list [.wild, .var] none [], [0]⟩]
      none (.ret (.var 0)), .mk [⟨.wild, []⟩] none (.ret (int 99))]) = (.returned 10, 0) := by decide

/-- 一番目の選択肢は false を、二番目は true を束縛する。
一番目でガードが偽なら、二番目の選択肢を試さず次の分岐へ進む。 -/
def guardSkip : Comp := .match (.list [.const (.boolean false), .const (.boolean true)])
  [.mk [⟨.list [.var, .wild] none [], [0]⟩, ⟨.list [.wild, .var] none [], [0]⟩]
    (some (.ret (.var 0))) (.ret (int 1)),
   .mk [⟨.wild, []⟩] none (.ret (int 2))]

example : exec guardSkip = (.returned 2, 0) := by decide

/-- ガードを計算して真になったとき、束縛を置換した本体に戻る。 -/
example : exec (.match (int 7)
    [.mk [⟨.var, [0]⟩]
      (some (.letIn (.ret (.const (.boolean true))) (.ret (.var 0)))) (.ret (.var 0)),
     .mk [⟨.wild, []⟩] none (.ret (int 99))]) = (.returned 7, 0) := by decide

/-- Integer の負の下端と両端を含み、範囲外は次の分岐へ進む。 -/
example : ([-3, -2, 0, 2, 3] : List Int).map (fun n => exec (.match (int n)
    [.mk [⟨.range (.integer (-2)) (.integer 2), []⟩] none (.ret (int 1)),
     .mk [⟨.wild, []⟩] none (.ret (int 0))])) =
    [(.returned 0, 0), (.returned 1, 0), (.returned 1, 0), (.returned 1, 0), (.returned 0, 0)] := by decide

/-- Character も両端を含む。 -/
example : (['`', 'a', 'm', 'z', '{'] : List Char).map (fun c => exec (.match (.const (.character c))
    [.mk [⟨.range (.character 'a') (.character 'z'), []⟩] none (.ret (int 1)),
     .mk [⟨.wild, []⟩] none (.ret (int 0))])) =
    [(.returned 0, 0), (.returned 1, 0), (.returned 1, 0), (.returned 1, 0), (.returned 0, 0)] := by decide

/-- 長さが一つなら残りなし、二つ以上なら残りを束縛せず末尾を返し、空なら 0 を返す。 -/
example : ([[], [int 1], [int 1, int 2], [int 1, int 2, int 3, int 4]] : List (List Val)).map
    (fun vs => exec (.match (.list vs)
      [.mk [⟨.list [.var] none [], [0]⟩] none (.ret (.var 0)),
       .mk [⟨.list [.wild] (some .skip) [.var], [0]⟩] none (.ret (.var 0)),
       .mk [⟨.list [] none [], []⟩] none (.ret (int 0))])) =
    [(.returned 0, 0), (.returned 1, 0), (.returned 2, 0), (.returned 4, 0)] := by decide

/-- 前・残り・後の束縛順を、値として返す。残りは切り取ったリストである。 -/
example : (run program builtins oracle rel fresh 20
    (.run (.match (.list [int 1, int 2, int 3, int 4])
      [.mk [⟨.list [.var] (some .bind) [.var], [0, 1, 2]⟩] none
        (.ret (.list [.var 2, .var 1, .var 0]))]) [] Store.empty) []).1 =
    .run (.ret (.list [int 1, .list [int 2, int 3], int 4])) [] Store.empty := by rfl

/-- 必要な長さと等しい場合、残りの束縛は空のリストになる。 -/
example : (run program builtins oracle rel fresh 20
    (.run (.match (.list [int 1, int 4])
      [.mk [⟨.list [.var] (some .bind) [.var], [0, 1, 2]⟩] none
        (.ret (.var 1))]) [] Store.empty) []).1 =
    .run (.ret (.list [])) [] Store.empty := by rfl

/-! ## 拡張した分岐の型付け

実行例とは別に、選択肢の対応とガードの型付けの前提が満たせることを示す。
-/

private theorem wildAltsTy (P : Program) (a : Ty) : AltsTy P [⟨.wild, []⟩] a [] := by
  refine ⟨by decide, rfl, ?_, ?_⟩
  · intro alt h; simp at h; subst alt; rfl
  · intro alt h; simp at h; subst alt
    exact ⟨[], .P_Wild, .refl _, rfl⟩

/-- ガードの環境は継続を隠し、ガードを R なし・空のエフェクトで検査できる。 -/
example : HasTypeC program builtins StoreTy.empty [] [] none guardSkip intTy Eff.empty := by
  have ha : AltsTy program
      [⟨.list [.var, .wild] none [], [0]⟩, ⟨.list [.wild, .var] none [], [0]⟩]
      (.list (.base .boolean)) [.base .boolean] := by
    refine ⟨by decide, rfl, ?_, ?_⟩
    · intro alt h; simp at h; subst alt; rfl
    · intro alt h
      simp only [List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with rfl | rfl
      · exact ⟨[.base .boolean], .P_List (.cons .P_Var (.cons .P_Wild .nil)) .nil
          (by intro _; rfl), .refl _, rfl⟩
      · exact ⟨[.base .boolean], .P_List (.cons .P_Wild (.cons .P_Var .nil)) .nil
          (by intro _; rfl), .refl _, rfl⟩
  refine .C_Match (.V_List (.cons .V_Const (.cons .V_Const .nil)) trivial)
    (.guarded ha (.C_Return (.V_Var rfl (by intro b t e h; cases h)))
      (.C_Return .V_Const)
      (.plain (wildAltsTy program _) (.C_Return .V_Const) (.nil trivial))) ?_
  intro v _
  exact ⟨.wild, by simp [unguardedPats], rfl⟩

/-- A と B は、二つの Integer を持つ同じデータ型の構成子である。 -/
def choiceProgram : Program := { program with
  cons := fun c => if c = "A" ∨ c = "B" then
    some { data := "Choice", ntys := 0, args := [intTy, intTy] } else program.cons c }

/-- B(y, x) の対応 [1, 0] は、A(x, y) と同じ分岐の変数の型を持つ。 -/
example : HasTypeC choiceProgram builtins StoreTy.empty [] [] none choiceMatch intTy Eff.empty := by
  have ha : AltsTy choiceProgram
      [⟨.con "A" [.var, .var], [0, 1]⟩, ⟨.con "B" [.var, .var], [1, 0]⟩]
      (.data "Choice" []) [intTy, intTy] := by
    refine ⟨by decide, rfl, ?_, ?_⟩
    · intro alt h; simp at h; subst alt; rfl
    · intro alt h
      simp only [List.mem_cons, List.not_mem_nil, or_false] at h
      rcases h with rfl | rfl
      · exact ⟨[intTy, intTy], .P_Con (cd := { data := "Choice", ntys := 0, args := [intTy, intTy] })
          (by simp [choiceProgram]) rfl
          (by simpa [Ty.subst, Ty.substAt, intTy] using
              (PatTys.cons (PatTy.P_Var (a := intTy)) (PatTys.cons (PatTy.P_Var (a := intTy)) .nil))), .refl _, rfl⟩
      · exact ⟨[intTy, intTy], .P_Con (cd := { data := "Choice", ntys := 0, args := [intTy, intTy] })
          (by simp [choiceProgram]) rfl
          (by simpa [Ty.subst, Ty.substAt, intTy] using
              (PatTys.cons (PatTy.P_Var (a := intTy)) (PatTys.cons (PatTy.P_Var (a := intTy)) .nil))), .swap 0 1 [], rfl⟩
  refine .C_Match (a := .data "Choice" [])
    (.V_Con (cd := { data := "Choice", ntys := 0, args := [intTy, intTy] })
      (by simp [choiceProgram]) rfl (by
        simpa [Ty.subst, Ty.substAt, intTy, int, Const.type] using
          (HasTypeVs.cons (HasTypeV.V_Const (c := .integer 10))
            (HasTypeVs.cons (HasTypeV.V_Const (c := .integer 20)) .nil))))
    (.plain ha (.C_Return (.V_Var rfl (by intro b t e h; cases h)))
      (.plain (wildAltsTy choiceProgram _) (.C_Return .V_Const) (.nil trivial))) ?_
  intro v _
  exact ⟨.wild, by simp [unguardedPats], rfl⟩

end Benitoite.Release.Examples
