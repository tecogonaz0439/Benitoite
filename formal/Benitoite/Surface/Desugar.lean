import Benitoite.Surface.Syntax
import Benitoite.Release.Subst

/-!
# 表層からの脱糖（C1・C2・C4・C5a-2・C6a-1・C6a-2・C6a-3・C7b-2）

再帰は Expr・Exprs・HoleArgs・Arms・Clauses・Block の構造に沿う。子を元の環境で脱糖してから、
挿入する let の個数だけ Release.Comp.rename で自由変数をずらす。
let の中の局所束縛とラムダの引数は rename の upRen により保護される。
opPrim が未定義の項には Unit を返す。型付けの E_Binary・E_Neg がこの場合を排除する。
-/

namespace Benitoite.Surface

open Benitoite.Release

/-- x1,…,xn は、すべて束縛した後で番号 n-1,…,0 になる。 -/
def boundVars (n : Nat) : List Val := (List.range n).reverse.map Val.var

/-- ms は同じ元の環境で脱糖済み。body は全 let を束縛した環境の計算。 -/
def letChain (depth : Nat) (ms : List Comp) (body : Comp) : Comp :=
  match ms with
  | [] => body
  | m :: rest => .letIn (m.rename (· + depth)) (letChain (depth + 1) rest body)

def sequence (ms : List Comp) (finish : List Val → Comp) : Comp :=
  letChain 0 ms (finish (boundVars ms.length))

/-- 呼び出しの頭。辞書は計算を作らず、値引数より先に渡す。 -/
inductive CallHead where
  | app (func : Val) (dicts : List Val)
  | meth (dict : Val) (method : MethName) (tys : List Ty) (effs : List Eff) (dicts : List Val)

/-- 頭の辞書も、元の環境の自由変数として移す。 -/
def CallHead.rename (ξ : Nat → Nat) : CallHead → CallHead
  | .app v ds => .app (v.rename ξ) (Val.renameList ξ ds)
  | .meth d m ss es us => .meth (d.rename ξ) m ss es (Val.renameList ξ us)

/-- `.app` は 01-12「呼び出し」の直接の呼び出しと「型クラス」第 3 行:
f[T̄; Ē](Ū, x1, …, xn)（Ū は決めた辞書。辞書が空なら名前の直接の呼び出し）。 -/
def CallHead.apply : CallHead → List Val → Comp
  | .app v ds, ws => .app v (ds ++ ws)
  -- 同表第 1 行: V.m[S̄; Ē](Ū, x1, …, xn)。
  | .meth d m ss es us, ws => .meth d m ss es (us ++ ws)

/-- Rust prepare と同じく裸の名前だけを直接の頭にする。括弧は値の形を保つ。 -/
def directCallee : Expr → Option CallHead
  | .funName f ts es => some (.app (.fnRef f ts es) [])
  -- 01-12「型クラス」第 3 行: 制約を持つ関数の呼び出し。
  | .funDicts f ts es ds _ => some (.app (.fnRef f ts es) (DictEv.toValList ds))
  -- 同表第 1 行: メソッドの呼び出し。
  | .methName d m ss es us _ => some (.meth d.toVal m ss es (DictEv.toValList us))
  | .primName b ts es => some (.app (.prim b ts es) [])
  -- 01-12「ハンドラ」: 利用者の操作を直接呼ぶ op(e1,…,en)。
  | .opName o ts => some (.app (.op o ts) [])
  | _ => none

/-- 変換関数はすべて直接の頭。型付けが none の場合を排除する。 -/
def Exprs.AllDirect : Exprs → Prop
  | .nil => True
  | .cons f fs => (∃ h, directCallee f = some h) ∧ fs.AllDirect

def directHeads : Exprs → List CallHead
  | .nil => []
  | .cons f fs => (directCallee f).getD (.app (.const .unit) []) :: directHeads fs

/-- 空の側の concat を省く。両側が非空なら最初の結果だけを束縛する。 -/
def spreadFinish (h : CallHead) (before : List Val) (s : Val) (after : List Val) : Comp :=
  match before, after with
  | [], [] => .ret s
  | [], _ => h.apply [s, .list after]
  | _, [] => h.apply [.list before, s]
  | _, _ => .letIn (h.apply [.list before, s])
      ((h.rename (· + 1)).apply [.var 0, .list (Val.renameList (· + 1) after)])

def spreadValues (h : CallHead) (n : Nat) (vs : List Val) : Comp :=
  match vs.drop n with
  | s :: after => spreadFinish h (vs.take n) s after
  | [] => .ret (.const .unit)

/-- 左から連結し、最後の連結だけを末尾の計算にする。0・1 部分では呼ばない。 -/
def joinStringFrom (op : OpPrim) (depth : Nat) (left : Val) : List Val → Comp
  | [] => .ret left
  | right :: rest => match op (.binary .add) (.base .string) with
      | none => .ret (.const .unit)
      | some (b, ts) => match rest with
          | [] => .app (.prim b ts []) [left, right.rename (· + depth)]
          | _ :: _ => .letIn (.app (.prim b ts []) [left, right.rename (· + depth)])
              (joinStringFrom op (depth + 1) (.var 0) rest)

def joinStringParts (op : OpPrim) : List Val → Comp
  | [] => .ret (.const (.string ""))
  | v :: rest => joinStringFrom op 0 v rest

/-- 式の評価は sequence で完了済み。変換を断片の順に束縛し、その後で連結する。
新しい変換結果の下へ、残る式の値・呼ぶ値・既に集めた部分を一つずらす。 -/
def interpolate (op : OpPrim) : List InterpPart → List Val → List CallHead → List Val → Comp
  | [], _, _, acc => joinStringParts op acc
  | .text s :: ps, vs, hs, acc =>
      interpolate op ps vs hs (if s = "" then acc else acc ++ [.const (.string s)])
  | .stringExpr :: ps, v :: vs, hs, acc => interpolate op ps vs hs (acc ++ [v])
  | .converted _ :: ps, v :: vs, h :: hs, acc => .letIn (h.apply [v])
      (interpolate op ps (Val.renameList (· + 1) vs) (hs.map (CallHead.rename (· + 1)))
        (Val.renameList (· + 1) acc ++ [.var 0]))
  | _, _, _, _ => .ret (.const .unit)

/-- 呼び出しの共通の組み立て。callee は元の環境で脱糖済みである。
shift は元の自由変数の移動量、inserted はすでに評価した挿入引数である。
ms は挿入引数を束縛する前の環境で計算し、穴の引数だけはラムダ引数の下で計算する。 -/
def callComp (shift : Nat) (inserted : List Val) (f : Expr) (callee : Comp)
    (ms : List Comp) : Comp :=
  match directCallee f with
  | some h => letChain inserted.length ms
      ((h.rename (· + (shift + ms.length))).apply
        (Val.renameList (· + ms.length) inserted ++ boundVars ms.length))
  | none => .letIn (callee.rename (· + shift))
      (letChain (inserted.length + 1) ms
        (.app (.var ms.length)
          (Val.renameList (· + (ms.length + 1)) inserted ++ boundVars ms.length)))

/-- パターンの束縛数だけ書いた値をずらし、残すフィールドの番号を右から数える。 -/
def recordUpdateValues (c : ConName) (n : Nat) (positions : List Nat) (vs : List Val) : List Val :=
  let b := (recordUpdatePattern c n positions).binders
  (List.range n).map fun i => match fieldAt i positions vs with
    | some v => v.rename (· + b)
    | none => .var (((List.range n).drop (i + 1)).filter (fun j => j ∉ positions)).length

/-- 単一のパターンを、恒等の束縛対応とガードなしの分岐にする。 -/
def mkArm (pat : Release.Pat) (body : Comp) : Arm :=
  .mk [⟨pat, List.range pat.binders⟩] none body

mutual
  def desugarExpr (opPrim : OpPrim) (p : Position) : Expr → Comp
    -- 01-12「名前とリテラル」: 局所の束縛の名前 x | return x
    | .local i => .ret (.var i)
    -- 01-12「トップレベルの定数」:
    -- 定数 `const k: A = e` の名前 `k` を、`⟦e⟧` に置き換える。
    -- `e` の中の定数の名前も同じく置き換える。
    | .constE _ body => desugarExpr opPrim .other body
    -- 同節: トップレベルの関数の名前 f | return f[T̄; Ē]
    | .funName f ts es => .ret (.fnRef f ts es)
    -- 01-12「型クラス」第 4 行: return λ(ȳ:Ā). f[T̄; Ē](Ū, ȳ)。
    -- 処理系は名前の変数なのでずらさない。de Bruijn の番号ではラムダ引数の下へ移すため、
    -- 値引数の個数だけずらす（意味は Rust dictionary_lambda と同じ）。
    | .funDicts f ts es ds ps => .ret (.lam ps
        (.app (.fnRef f ts es)
          (Val.renameList (· + ps.length) (DictEv.toValList ds) ++ boundVars ps.length)))
    -- 同表第 2 行: return λ(ȳ:Ā). V.m[S̄; Ē](Ū, ȳ)。V と Ū の両方をずらす。
    | .methName d m ss es us ps => .ret (.lam ps
        (.meth (d.toVal.rename (· + ps.length)) m ss es
          (Val.renameList (· + ps.length) (DictEv.toValList us) ++ boundVars ps.length)))
    -- 同節: prelude の関数 M.g | return b[T̄; Ē]（Σ にあるものは関数の名前）
    | .primName b ts es => .ret (.prim b ts es)
    -- 01-12「ハンドラ」: 利用者の操作の名前 op を、呼ばずに値として使う | return op[T̄]
    | .opName o ts => .ret (.op o ts)
    -- 同節: 引数のない構成子 T.C、Option.None | return C[T̄]()
    | .nullCon c ts => .ret (.con c ts [])
    -- 同節: 引数を持つ構成子 T.C を値として使う
    -- | return λ(y1:A1,…,yn:An). return C[T̄](y1,…,yn)
    | .conValue c ts ps => .ret (.lam ps (.ret (.con c ts (boundVars ps.length))))
    -- 同節: リテラル | return c（c はリテラルが表す値）
    -- 01-12「基本型とコレクションの型」: Decimal のリテラル（1.25m など）は return c に移す。
    | .literal l => .ret (.const l.toConst)
    -- 01-12「名前とリテラル」: 単項の - を整数リテラルに直接適用した式 -n | return c（c は −n）
    | .negInt n => .ret (.const (.integer (-Int.ofNat n)))
    -- 同節: 単項の - を Float リテラルに直接適用した式 -x | return c（c は −x）
    | .negFloat x => .ret (.const (.float (-x)))
    -- 01-12「基本型とコレクションの型」: 単項の - を Decimal のリテラルに直接適用した式
    -- | return c（c は係数の符号を反転し、小数の桁数を保った値。負のゼロはない）。
    -- Rust unary と同じ。n は符号を反転する前の係数。
    | .negDecimal n scale => .ret (.const (.decimal (-n) scale))
    -- 01-12「名前とリテラル」: () | return ()
    | .unit => .ret (.const .unit)
    -- 同節: (e) | ⟦e⟧
    | .paren e => desugarExpr opPrim p e
    -- 01-12「呼び出し」: T.C(e1,…,en) | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return C[T̄](x1,…,xn)
    -- 01-12「レコード」: R(g1:e1,…,gn:en) | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in
    -- return C_R[T̄](y1,…,yn)（yi は宣言の i 番目を書いた位置の xj）。
    | .record c ts positions args => sequence (desugarExprs opPrim args)
        (fun vs => .ret (.con c ts (recordFields positions.length positions vs (.const .unit))))
    -- 01-12「レコード」: R(..e,g1:e1,…,gk:ek) | let r ⇐ ⟦e⟧ in let x1 ⇐ ⟦e1⟧ in …
    -- let xk ⇐ ⟦ek⟧ in match r { C_R(q1,…,qn) ⇒ return C_R[T̄](y1,…,yn) }
    -- （qi は書き換えるなら _、そうでなければ zi。Rust record と同じ）。
    -- 全フィールドを更新する場合も match を作る。r の番号は書いた値の個数。
    | .recordUpdate c ts n positions base args =>
        .letIn (desugarExpr opPrim .other base)
          (letChain 1 (desugarExprs opPrim args)
            (.match (.var args.length) [mkArm (recordUpdatePattern c n positions)
              (.ret (.con c ts (recordUpdateValues c n positions (boundVars args.length))))]))
    | .conCall c ts args => sequence (desugarExprs opPrim args) (fun vs => .ret (.con c ts vs))
    -- 同節: e0(e1,…,en) | let y ⇐ ⟦e0⟧ in let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in y(x1,…,xn)
    -- 同表: f(e1,…,en) | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in f[T̄; Ē](x1,…,xn)
    -- 01-12「型クラス」第 1 行: Cl.m(e1,…,en)
    -- | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in V.m[S̄; Ē](Ū,x1,…,xn)
    -- 同表第 3 行: 制約を持つ関数 f の呼び出し f(e1,…,en)
    -- | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in f[T̄; Ē](Ū,x1,…,xn)（頭は束縛しない）
    -- 01-12「ハンドラ」: 利用者の操作を直接呼ぶ op(e1,…,en)
    -- | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in op[T̄](x1,…,xn)
    | .call f args => callComp 0 [] f (desugarExpr opPrim .other f) (desugarExprs opPrim args)
    -- 同節: パイプ e1 |> e2 | let t ⇐ ⟦e1⟧ in ⟦e'⟧
    -- e' は 01-02 の展開。表層を作らず、各形から直接コアへ移す。
    -- 同表の注記どおり、展開で差し込んだ t は let x ⇐ return t で束縛し直さない。
    | .pipe lhs rhs => .letIn (desugarExpr opPrim .other lhs) (match rhs with
        | .conCall c ts args =>
            let ms := desugarExprs opPrim args
            letChain 1 ms (.ret (.con c ts (.var ms.length :: boundVars ms.length)))
        | .call f args => callComp 1 [.var 0] f
            (desugarExpr opPrim .other f) (desugarExprs opPrim args)
        | .conValue c ts _ => .ret (.con c ts [.var 0])
        | other => callComp 1 [.var 0] other (desugarExpr opPrim .other other) [])
    -- 01-12「表層からの脱糖」の前段: プレースホルダをラムダに展開してから移す。
    -- 01-12「リスト、ラムダ、条件分岐、match」のラムダの行: return λ(p̄). ⟦B⟧。
    -- 非穴の式と callee はラムダの本体で評価する。穴も let x ⇐ return p で束縛する。
    | .partialCall f args _ _ => .ret (.lam args.holeTypes
        (callComp args.holeTypes.length [] f (desugarExpr opPrim .other f)
          (desugarHoleArgs opPrim args.holeTypes.length args)))
    -- 同前段: T.C(a1,…,_,…,an) | return λ(p̄). ⟦T.C(a1,…,p,…,an)⟧
    | .partialCon c ts args => .ret (.lam args.holeTypes
        (sequence (desugarHoleArgs opPrim args.holeTypes.length args)
          (fun vs => .ret (.con c ts vs))))
    -- 01-12「演算子」: e1 ⊕ e2 | let x ⇐ ⟦e1⟧ in let y ⇐ ⟦e2⟧ in ⊕_T(x,y)
    -- 02-06: =・<> は eq[T]・ne[T]、ほかは型ごとの項目で型引数なし。
    | .binary o t lhs rhs =>
        match opPrim (.binary o) t with
        | some (b, ts) => sequence [desugarExpr opPrim .other lhs, desugarExpr opPrim .other rhs]
            (fun vs => .app (.prim b ts []) vs)
        | none => .ret (.const .unit)
    -- 同節: -e（直接の整数・Float リテラルを除く） | let x ⇐ ⟦e⟧ in neg_T(x)
    | .neg t e =>
        match opPrim .neg t with
        | some (b, ts) => .letIn (desugarExpr opPrim .other e) (.app (.prim b ts []) [.var 0])
        | none => .ret (.const .unit)
    -- 同節: not e | let x ⇐ ⟦e⟧ in if x then return false else return true
    | .not e => .letIn (desugarExpr opPrim .other e)
        (.ite (.var 0) (.ret (.const (.boolean false))) (.ret (.const (.boolean true))))
    -- 同節: e1 and e2 | let x ⇐ ⟦e1⟧ in if x then ⟦e2⟧ else return false
    | .and lhs rhs => .letIn (desugarExpr opPrim .other lhs)
        (.ite (.var 0) ((desugarExpr opPrim p rhs).rename (· + 1)) (.ret (.const (.boolean false))))
    -- 同節: e1 or e2 | let x ⇐ ⟦e1⟧ in if x then return true else ⟦e2⟧
    | .or lhs rhs => .letIn (desugarExpr opPrim .other lhs)
        (.ite (.var 0) (.ret (.const (.boolean true))) ((desugarExpr opPrim p rhs).rename (· + 1)))
    -- 01-12「リスト、ラムダ、条件分岐、match」: [e1,…,en] | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in return [x1,…,xn]
    | .list _ es => sequence (desugarExprs opPrim es) (fun vs => .ret (.list vs))
    -- 01-12「リストの展開」: [e1,…,ek,..e,ek+1,…,en]（0 < k < n）
    -- | let x1 ⇐ ⟦e1⟧ in … let xk ⇐ ⟦ek⟧ in let s ⇐ ⟦e⟧ in
    --   let xk+1 ⇐ ⟦ek+1⟧ in … let xn ⇐ ⟦en⟧ in
    --   let y ⇐ concat_T([x1,…,xk],s) in concat_T(y,[xk+1,…,xn])。
    -- 同表: 展開が先頭 | … concat_T(s,[x1,…,xn])、展開が末尾 | … concat_T([x1,…,xn],s)、
    -- [..e] | let s ⇐ ⟦e⟧ in return s。空の側の concat_T は作らない（Rust list と同じ）。
    | .listSpread _ f before s after =>
        let ms := desugarExprs opPrim before ++ desugarExpr opPrim .other s :: desugarExprs opPrim after
        sequence ms (fun vs => match directCallee f with
          | some h => spreadValues (h.rename (· + ms.length)) before.length vs
          | none => .ret (.const .unit))
    -- 01-12「文字列補間」: "s0${e1}s1…${en}sn"
    -- | let x1 ⇐ ⟦e1⟧ in … let xn ⇐ ⟦en⟧ in、String でない式についてだけ書いた順に
    --   let yi ⇐ str_Ti(xi) in、部分 u1,…,um（空でない断片と式の値）を左から +_String で連結する。
    -- 同節: 最後の連結だけを束縛しない。m = 0 なら return ""、m = 1 なら return u1。
    | .interpolation parts es fs =>
        let ms := desugarExprs opPrim es
        sequence ms (fun vs => interpolate opPrim parts vs
          ((directHeads fs).map (CallHead.rename (· + ms.length))) [])
    -- 01-12「リスト、ラムダ、条件分岐、match」: lambda(x1,…,xn) B end lambda | return λ(x1:A1,…,xn:An). ⟦B⟧
    | .lam ps _ _ body => .ret (.lam ps (desugarBlock opPrim .tail body))
    -- 同節: if e then B1 else B2 end if | let x ⇐ ⟦e⟧ in if x then ⟦B1⟧ else ⟦B2⟧
    | .ite c yes no => .letIn (desugarExpr opPrim .other c)
        (.ite (.var 0) ((desugarBlock opPrim p yes).rename (· + 1))
          ((desugarBlock opPrim p no).rename (· + 1)))
    -- 同節: if e then B1 else if … | else if 以下を、閉じた一つの if として B2 に置く
    | .elseIf c yes no => .letIn (desugarExpr opPrim .other c)
        (.ite (.var 0) ((desugarBlock opPrim p yes).rename (· + 1))
          ((desugarExpr opPrim p no).rename (· + 1)))
    -- 同節: if e then B1 end if（else なし） | let x ⇐ ⟦e⟧ in if x then ⟦B1⟧ else return ()
    | .ifOnly c yes => .letIn (desugarExpr opPrim .other c)
        (.ite (.var 0) ((desugarBlock opPrim p yes).rename (· + 1)) (.ret (.const .unit)))
    -- 同節: match e with case p1 -> B1 … case pn -> Bn end match
    -- | let x ⇐ ⟦e⟧ in match x { p1' ⇒ ⟦B1⟧ | … | pn' ⇒ ⟦Bn⟧ }
    | .matchE _ e arms => .letIn (desugarExpr opPrim .other e)
        (.match (.var 0) (desugarArms opPrim p arms))
    -- 01-12「return」: return e（末尾位置にあるもの） | ⟦e⟧
    -- 同節: return e（末尾位置にないもの） | let x ⇐ ⟦e⟧ in escape x
    | .returnE _ e => match p with
        | .tail => desugarExpr opPrim .tail e
        | .other => .letIn (desugarExpr opPrim .other e) (.escape (.var 0))
    -- 01-12「関数の境界と `escape`：途中の `return` と `try`」:
    -- try e（e が Result[T, E]、関数の戻り値の型が Result[U, E]）
    -- | let x ⇐ ⟦e⟧ in match x { Ok(y) ⇒ return y | Error(z) ⇒ escape Error[U, E](z) }
    | .tryResult ts ok err e => .letIn (desugarExpr opPrim .other e)
        (.match (.var 0) [mkArm (.con ok [.var]) (.ret (.var 0)),
          mkArm (.con err [.var]) (.escape (.con err ts [.var 0]))])
    -- 同節: try e（e が Option[T]、関数の戻り値の型が Option[U]）
    -- | let x ⇐ ⟦e⟧ in match x { Some(y) ⇒ return y | None ⇒ escape None[U]() }
    | .tryOption ts someCon noneCon e => .letIn (desugarExpr opPrim .other e)
        (.match (.var 0) [mkArm (.con someCon [.var]) (.ret (.var 0)),
          mkArm (.con noneCon []) (.escape (.con noneCon ts []))])
    -- 01-12「解放の枠と実行時エラーの継続：`with`」:
    -- with x1 = e1, …, xn = en do B end with
    -- | let x1 ⇐ ⟦e1⟧ in use x1 in (let x2 ⇐ ⟦e2⟧ in use x2 in …
    --   (let xn ⇐ ⟦en⟧ in use xn in ⟦B⟧) …)（B は末尾位置にないものとして移す）
    -- 単一束縛の入れ子でこの並びを表す。body は既にその束縛の下にあり、rename は不要。
    | .withE _ e body => .letIn (desugarExpr opPrim .other e)
        (.use (.var 0) (desugarBlock opPrim .other body))
    -- 01-12「ストア：可変のセルと明示遅延」:
    -- lazy B end lazy | lazy ⟦B⟧（B は文の並びで、末尾位置にないものとして移す）
    | .lazyE body => .lazyC (desugarBlock opPrim .other body)
    -- 01-12「ハンドラ」: handle B with case op1(x̄1) -> N1 … case opn(x̄n) -> Nn end handle
    -- | handle ⟦B⟧ with { op1'(x̄1) k1 ⇒ ⟦N1⟧ | … | opn'(x̄n) kn ⇒ ⟦Nn⟧ }
    -- ki は新しい変数。opi' は利用者の操作なら op、組み込みの操作なら組み込みの関数 b。
    -- 節の引数の `_` は新しい変数にする。B と Ni は非末尾位置であり、R は退避しない。
    | .handleE body cs => .handle (desugarBlock opPrim .other body) (desugarClauses opPrim cs)
    -- 同節: 節の中の resume(v) | let x ⇐ ⟦v⟧ in resume k x
    -- 新しい let の下で継続の番号を一つずらす。原子的な値でも let を作る。
    | .resume k e => .letIn (desugarExpr opPrim .other e) (.resume (.var (k + 1)) (.var 0))

  /-- 引数とリストの要素は、すべて非末尾位置で左から脱糖する。 -/
  def desugarExprs (opPrim : OpPrim) : Exprs → List Comp
    | .nil => []
    | .cons e es => desugarExpr opPrim .other e :: desugarExprs opPrim es

  /-- n 個のラムダ引数の下での計算列。穴の番号は右に残る穴の個数である。
  穴の値も計算にして letChain に渡すので、Rust placeholder と同じ再束縛になる。 -/
  def desugarHoleArgs (opPrim : OpPrim) (n : Nat) : HoleArgs → List Comp
    | .nil => []
    | .expr e rest => (desugarExpr opPrim .other e).rename (· + n) ::
        desugarHoleArgs opPrim n rest
    | .hole _ rest => .ret (.var rest.holeTypes.length) :: desugarHoleArgs opPrim n rest

  /-- 選択肢・ガード・本体を一つの Arm に移す。照合対象の let の下でも、
  最初の選択肢の束縛を保護する。ガードは常に非末尾位置で脱糖する。 -/
  def desugarArms (opPrim : OpPrim) (p : Position) : Arms → List Arm
    | .nil => []
    | .cons alts none body rest =>
        .mk (Alternative.toCoreList alts) none
          ((desugarBlock opPrim p body).rename (upRen (Arm.bindersOf (Alternative.toCoreList alts)) (· + 1))) ::
          desugarArms opPrim p rest
    | .cons alts (some guard) body rest =>
        .mk (Alternative.toCoreList alts)
          (some ((desugarExpr opPrim .other guard).rename (upRen (Arm.bindersOf (Alternative.toCoreList alts)) (· + 1))))
          ((desugarBlock opPrim p body).rename (upRen (Arm.bindersOf (Alternative.toCoreList alts)) (· + 1))) ::
          desugarArms opPrim p rest

  /-- 01-12「ハンドラ」の opi'(x̄i) ki ⇒ ⟦Ni⟧。型注釈と変数番号は入力で確定済み。 -/
  def desugarClauses (opPrim : OpPrim) : Clauses → List Release.Clause
    | .nil => []
    | .cons o n ntys body rest =>
        .mk o n ntys (desugarBlock opPrim .other body) :: desugarClauses opPrim rest

  def desugarBlock (opPrim : OpPrim) (p : Position) : Block → Comp
    -- 01-12「ブロック」: { } | return ()
    | .empty => .ret (.const .unit)
    -- 同節: { e }（最後の文が式） | ⟦e⟧
    | .last e => desugarExpr opPrim p e
    -- 同節: { bind x <- e }（最後の文が束縛の文） | let x ⇐ ⟦e⟧ in return ()（shadow も同じ）
    | .lastBind _ _ e => .letIn (desugarExpr opPrim .other e) (.ret (.const .unit))
    -- 同節: { bind _ <- e } | let z ⇐ ⟦e⟧ in return ()（最後の束縛の行の _ の場合）
    | .lastDiscard e => .letIn (desugarExpr opPrim .other e) (.ret (.const .unit))
    -- 同節: { bind p <- e }（変数と _ 以外の必ず照合するパターン）
    -- | let z ⇐ ⟦e⟧ in match z { p' ⇒ return () }（shadow も同じ）
    | .lastPat _ pat _ e => .letIn (desugarExpr opPrim .other e)
        (.match (.var 0) [mkArm pat.toCore (.ret (.const .unit))])
    -- 同節: { bind x <- e; s̄ }（型注釈も同じ） | let x ⇐ ⟦e⟧ in ⟦{s̄}⟧（shadow も同じ）
    | .bind _ _ e rest => .letIn (desugarExpr opPrim .other e) (desugarBlock opPrim p rest)
    -- 同節: { bind p <- e; s̄ }（変数と _ 以外の必ず照合するパターン）
    -- | let z ⇐ ⟦e⟧ in match z { p' ⇒ ⟦{s̄}⟧ }（shadow も同じ）
    | .bindPat _ pat _ e rest => .letIn (desugarExpr opPrim .other e)
        (.match (.var 0) [mkArm pat.toCore
          ((desugarBlock opPrim p rest).rename (upRen pat.toCore.binders (· + 1)))])
    -- 同節: { bind _ <- e; s̄ } | let z ⇐ ⟦e⟧ in ⟦{s̄}⟧
    | .discard e rest => .letIn (desugarExpr opPrim .other e)
        ((desugarBlock opPrim p rest).rename (· + 1))
    -- 同節: { e; s̄ }（式文） | let z ⇐ ⟦e⟧ in ⟦{s̄}⟧
    | .seq e rest => .letIn (desugarExpr opPrim .other e)
        ((desugarBlock opPrim p rest).rename (· + 1))
end

-- 01-12「トップレベルの関数」: function f[ᾱ,effect ρ̄](x̄:Ā)→B uses ε B0
-- | fn f[ᾱ;ρ̄](x̄:Ā):B ! ε = ⟦B0⟧。型パラメータの制約はそのまま写す。
def desugarDef (opPrim : OpPrim) (d : Def) : Release.Def :=
  -- 01-12「型クラス」: 制約ごとの Dict[Cl, α] の引数を値の引数の前に持つ。
  { tparams := d.tparams, neffs := d.neffs, params := d.dictTys ++ d.params, ret := d.ret, eff := d.eff,
    body := desugarBlock opPrim .tail d.body }

-- 01-12「型クラス」D-Impl: 上位の辞書 Ui は値、メソッド Mj は末尾位置で移す。
-- Rust definition も Position::Tail。型引数と環境は Release の γ̄, β̄ / d̄, x̄ の並び。
def desugarImpl (opPrim : OpPrim) (id : ImplDecl) : Release.ImplDecl :=
  { tparams := id.tparams, dictParams := id.dictParams, cls := id.cls, target := id.target,
    supers := fun s => (id.supers s).map DictEv.toVal,
    methods := fun m => (id.methods m).map (desugarBlock opPrim .tail) }

-- 01-12「レコード」: R.fi | Σ の fn R.fi[ᾱ;](r:R[ᾱ]):Ai ! {} =
-- match r { C_R(q1,…,qn) ⇒ return z }（qi は変数 z、そのほかは _。Rust getters と同じ）。
def accessorDef (c : ConName) (cd : ConDecl) (k : Nat) : Release.Def :=
  let d := accessorDecl cd k
  { tparams := d.tparams, neffs := d.neffs, params := d.params, ret := d.ret, eff := d.eff,
    body := .match (.var 0) [mkArm (accessorPattern c cd.args.length k) (.ret (.var 0))] }

def desugarProgram (opPrim : OpPrim) (p : Program) : Release.Program :=
  { defs := p.lookupFun (desugarDef opPrim) accessorDef, cons := p.cons,
    ops := p.ops, effects := p.effects, classes := p.classes,
    impls := fun i => (p.impls i).map (desugarImpl opPrim) }

end Benitoite.Surface
