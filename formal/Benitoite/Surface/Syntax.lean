import Benitoite.Release.Subst

/-!
# 型の情報を付けた表層の構文（C1・C2・C4・C5a-1・C6a-1・C6a-2・C6a-3・C7b-2）

名前解決と型検査の後の情報を持つ。型とエフェクトは Release のものを使う。
局所変数は de Bruijn の番号であり、引数の最後が番号 0 である。
`bind`・`shadow` は続きを一つ束縛し、`bind _` と式文は束縛しない。
リストと通常の引数は `Exprs`、穴を含む引数は `HoleArgs`、分岐は `Arms`、ハンドラの節は `Clauses` で表し、
脱糖の相互再帰を構造的にする。パターンの束縛の番号は Release の `binds` に合わせる。
-/

namespace Benitoite.Surface

open Benitoite.Release

inductive Position where
  | tail | other
  deriving DecidableEq

inductive BinOp where
  | add | sub | mul | div | intDiv | mod | eq | ne | lt | le | gt | ge
  deriving DecidableEq

inductive Operator where
  | binary (op : BinOp)
  | neg
  deriving DecidableEq

/-- 02-06「コア IR」の演算子の表。等値は `eq[T]`・`ne[T]`、ほかは型引数なし。 -/
abbrev OpPrim := Operator → Ty → Option (PrimName × List Ty)

def Operator.typeArgs : Operator → Ty → List Ty
  | .binary .eq, t => [t]
  | .binary .ne, t => [t]
  | _, _ => []

/-- 表層のリテラル。Unit は `Expr.unit` に分ける。Decimal は係数と scale を持つ。 -/
inductive Literal where
  | integer (n : Nat)
  | float (x : Float)
  | decimal (n : Int) (scale : Nat)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)

def Literal.toConst : Literal → Const
  | .integer n => .integer (Int.ofNat n)
  | .float x => .float x
  | .decimal n scale => .decimal n scale
  | .string s => .string s
  | .character c => .character c
  | .boolean b => .boolean b

inductive BindKind where
  | bind | shadow
  deriving DecidableEq

/-- 書いた順の位置と値を同時に辿る。範囲外・書かなかった位置は none。
型付けは構築・更新の位置を検査する。パターンでは最初に書いた位置を使う。
重複は型検査で排除される。処理系は後の値を使うが、型の付いた入力では区別がない。 -/
def fieldAt {α : Type} (i : Nat) : List Nat → List α → Option α
  | j :: js, v :: vs => if i = j then some v else fieldAt i js vs
  | _, _ => none

/-- 宣言の順に並べ、書かなかった位置を fallback で埋める。 -/
def recordFields {α : Type} (n : Nat) (positions : List Nat) (values : List α)
    (fallback : α) : List α :=
  (List.range n).map fun i => (fieldAt i positions values).getD fallback

/-- 更新は書き換える位置を束縛せず、残す位置だけを宣言の順に束縛する。 -/
def recordUpdatePattern (c : ConName) (n : Nat) (positions : List Nat) : Release.Pat :=
  .con c ((List.range n).map fun i => if i ∈ positions then .wild else .var)

/-- 取得する位置だけを束縛する。 -/
def accessorPattern (c : ConName) (n k : Nat) : Release.Pat :=
  .con c ((List.range n).map fun i => if i = k then .var else .wild)

/-- 名前解決済みのパターン。修飾は表示の情報で、c は一意な構成子名である。
変数名の重複・シャドーイングは名前解決で検査済み。Float・Decimal の単独パターンは
構文に含めない。範囲の両端の種類は型付けで検査する。 -/
inductive Pattern where
  | wild
  | var
  | integer (n : Nat)
  | negInt (n : Nat)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)
  | unit
  /-- 両端は処理系の `range_bounds` と同じく値で持つ。 -/
  | range (lo hi : Release.Const)
  | list (before : List Pattern) (rest : Option Release.ListRest) (after : List Pattern)
  | con (qualifier : Option DataName) (c : ConName) (args : List Pattern)
  /-- n は全フィールド数。positions と args は書いた順の並行したリスト。
  省略したフィールドは wild。束縛の順は toCore 後の宣言の順。 -/
  | record (c : ConName) (n : Nat) (positions : List Nat) (args : List Pattern)

mutual
  /-- 01-12 の pi'。修飾を除き、-n を負の定数にする。 -/
  def Pattern.toCore : Pattern → Release.Pat
    | .wild => .wild
    | .var => .var
    | .integer n => .const (.integer (Int.ofNat n))
    | .negInt n => .const (.integer (-Int.ofNat n))
    | .string s => .const (.string s)
    | .character c => .const (.character c)
    | .boolean b => .const (.boolean b)
    | .unit => .const .unit
    | .range lo hi => .range lo hi
    | .list before rest after => .list (Pattern.toCoreList before) rest (Pattern.toCoreList after)
    | .con _ c ps => .con c (Pattern.toCoreList ps)
    -- 01-12「レコード」: R(g1:p1,…,gk:pk)、R(g1:p1,…,..) | C_R(q1,…,qn)。
    -- qi は対応する pj'、書いていなければ _。
    | .record c n positions ps =>
        .con c (recordFields n positions (Pattern.toCoreList ps) .wild)

  def Pattern.toCoreList : List Pattern → List Release.Pat
    | [] => []
    | p :: ps => p.toCore :: Pattern.toCoreList ps
end

/-! 01-05 の範囲の大小とリストの形。両端の種類は Release.PatTy が検査する。
入れ子の構成子・レコード・リストの中にも同じ条件を課す。
リストの形の条件は `Release.P_List` と同じで、束縛の左辺と選択肢で同じ述語を使うために重ねて置く。 -/
mutual
  def Pattern.Valid : Pattern → Prop
    | .range (.integer lo) (.integer hi) => lo ≤ hi
    | .range (.character lo) (.character hi) => lo.toNat ≤ hi.toNat
    | .con _ _ ps | .record _ _ _ ps => Pattern.ValidList ps
    | .list before rest after =>
        Pattern.ValidList before ∧ Pattern.ValidList after ∧ (rest = none → after = [])
    | _ => True

  def Pattern.ValidList : List Pattern → Prop
    | [] => True
    | p :: ps => p.Valid ∧ Pattern.ValidList ps
end

/-- slots は分岐の変数ごとに使う束縛の位置。最初の選択肢は恒等対応（AltsTy）。 -/
structure Alternative where
  pat : Pattern
  slots : List Nat

def Alternative.toCore (alt : Alternative) : Release.Alt := ⟨alt.pat.toCore, alt.slots⟩

def Alternative.toCoreList (alts : List Alternative) : List Release.Alt := alts.map Alternative.toCore

def Alternative.Valid (alts : List Alternative) : Prop := ∀ alt ∈ alts, alt.pat.Valid

def Pattern.binders (p : Pattern) : Nat := p.toCore.binders

/-- 変数と _ の束縛は C1 の構文を使う。 -/
def Pattern.Nontrivial : Pattern → Prop
  | .wild | .var => False
  | _ => True

/-- 01-12「型クラス」: 型検査が決めた辞書。local は普通の環境 Γ の番号（P6）。 -/
inductive DictEv where
  | impl (i : ImplName) (tys : List Ty) (args : List DictEv)
  | local (j : Nat)
  | super (d : DictEv) (s : ClassName)

mutual
  /-- V-Dict・受け取った辞書・V-Super。計算も let も作らない。 -/
  def DictEv.toVal : DictEv → Release.Val
    -- 01-12「型クラス」V-Dict: I[T̄](V̄)。
    | .impl i ts ds => .dict i ts (DictEv.toValList ds)
    -- 同節の辞書の決め方: 受け取った辞書の引数 d。
    | .local j => .var j
    -- V-Super: V↑S。上位の上位へはこの構成を重ねる。
    | .super d s => .super d.toVal s

  def DictEv.toValList : List DictEv → List Release.Val
    | [] => []
    | d :: ds => d.toVal :: DictEv.toValList ds
end

/-- 補間の並行したリストの案内。子の式を含まないため、入れ子の帰納型にならない。
text の空文字列は脱糖で省く。converted は String 以外の式と変換関数を一つずつ使う。 -/
inductive InterpPart where
  | text (s : String)
  | stringExpr
  | converted (ty : Ty)

def InterpPart.exprTypes : List InterpPart → List Ty
  | [] => []
  | .text _ :: ps => exprTypes ps
  | .stringExpr :: ps => .base .string :: exprTypes ps
  | .converted t :: ps => t :: exprTypes ps

def InterpPart.converterTypes : List InterpPart → List Ty
  | [] => []
  | .converted t :: ps => .fn [t] (.base .string) Eff.empty :: converterTypes ps
  | _ :: ps => converterTypes ps

/-- 01-06「演算子の型付け」の補間に許す型。補間の制約を持つ型変数は型パラメータと等しくなれず、
本体の検査を終えた時点で具体的な型に決まるので、型検査の後の補間の式の型は必ずこの 7 つのどれかである。 -/
def InterpPart.Allowed : List InterpPart → Prop
  | [] => True
  | .converted t :: ps =>
      (t = .base .integer ∨ t = .base .float ∨ t = .base .character ∨
        t = .base .boolean ∨ t = .base .byte ∨ t = .base .decimal) ∧ Allowed ps
  | _ :: ps => Allowed ps

def InterpPart.count : List InterpPart → Nat
  | [] => 0
  | .text s :: ps => (if s = "" then 0 else 1) + count ps
  | _ :: ps => 1 + count ps

mutual
  inductive Expr where
    | local (i : Nat)
    /-- 01-12「トップレベルの定数」。宣言の型と本体を参照の位置に埋め込む（P5）。
    本体の中の定数参照も埋め込んだ有限の木。型引数を受け取らず、局所変数を捕えない。 -/
    | constE (ty : Ty) (body : Expr)
    | funName (f : FunName) (tys : List Ty) (effs : List Eff)
    /-- 01-12「型クラス」の表の第 4 行。params は具体化した値の引数の型。 -/
    | funDicts (f : FunName) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (params : List Ty)
    /-- 同表の第 2 行。dicts はメソッド自身の制約、params は辞書を除いた引数型。 -/
    | methName (dict : DictEv) (m : MethName) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (params : List Ty)
    | primName (b : PrimName) (tys : List Ty) (effs : List Eff)
    | opName (o : OpName) (tys : List Ty)
    | nullCon (c : ConName) (tys : List Ty)
    | conValue (c : ConName) (tys params : List Ty)
    | literal (l : Literal)
    | negInt (n : Nat)
    /-- 括弧を挟まず Float リテラル x に適用した単項の -。x は符号反転前の値。 -/
    | negFloat (x : Float)
    /-- 括弧を挟まず Decimal リテラルへ適用した -。scale を変えない。 -/
    | negDecimal (n : Int) (scale : Nat)
    | unit
    | paren (e : Expr)
    | conCall (c : ConName) (tys : List Ty) (args : Exprs)
    /-- positions は書いた各フィールドの宣言中の位置。全フィールドを一度ずつ書く。 -/
    | record (c : ConName) (tys : List Ty) (positions : List Nat) (args : Exprs)
    /-- n は全フィールド数、tys は base の型引数。positions と args は書いた順。 -/
    | recordUpdate (c : ConName) (tys : List Ty) (n : Nat) (positions : List Nat)
        (base : Expr) (args : Exprs)
    | call (callee : Expr) (args : Exprs)
    | pipe (lhs rhs : Expr)
    /-- 一つ以上の穴を持つ呼び出し。戻り値・エフェクトは展開後のラムダの情報。 -/
    | partialCall (callee : Expr) (args : HoleArgs) (ret : Ty) (eff : Eff)
    | partialCon (c : ConName) (tys : List Ty) (args : HoleArgs)
    | binary (op : BinOp) (operandTy : Ty) (lhs rhs : Expr)
    | neg (operandTy : Ty) (e : Expr)
    | not (e : Expr)
    | and (lhs rhs : Expr)
    | or (lhs rhs : Expr)
    | list (elemTy : Ty) (elems : Exprs)
    /-- concat は型検査が決めた直接の呼ぶ値。展開は一つだけである。 -/
    | listSpread (elemTy : Ty) (concat : Expr) (before : Exprs) (spread : Expr) (after : Exprs)
    /-- parts の式の部分と es、converted の部分と converters がそれぞれ対応する。 -/
    | interpolation (parts : List InterpPart) (es converters : Exprs)
    | lam (params : List Ty) (ret : Ty) (eff : Eff) (body : Block)
    | ite (cond : Expr) (yes no : Block)
    /-- `no` は `else if` 以下を閉じた式。括弧やブロックの合成で消さない。 -/
    | elseIf (cond : Expr) (yes : Block) (no : Expr)
    | ifOnly (cond : Expr) (yes : Block)
    | matchE (resultTy : Ty) (scrutinee : Expr) (arms : Arms)
    /-- 型検査が決めた、この位置の型。非末尾の型付けでは結果型として使い、
    末尾の型付けと脱糖では注釈を使わない。 -/
    | returnE (resultTy : Ty) (e : Expr)
    /-- `try e`（Result）。retArgs は最も内側の関数の戻り値の型引数 [U, E]。
    ok・err は名前解決済みの Ok・Error の名前である。 -/
    | tryResult (retArgs : List Ty) (ok err : ConName) (e : Expr)
    /-- `try e`（Option）。retArgs は戻り値の型引数 [U]。 -/
    | tryOption (retArgs : List Ty) (someCon noneCon : ConName) (e : Expr)
    /-- 一つのリソースの束縛。複数の束縛は body の最後に withE を入れ子にする。
    o はリソースの型名。本体に一つ束縛を加え、その変数を番号 0 にする。
    空の束縛列と `_` の束縛は、この構文では表せない。 -/
    | withE (o : OpaqueName) (e : Expr) (body : Block)
    /-- 明示遅延。本体は新しい値の変数を束縛しない。 -/
    | lazyE (body : Block)
    /-- 本体と各節は非末尾位置。節の型注釈は型パラメータをずらした後の形で持つ。 -/
    | handleE (body : Block) (clauses : Clauses)
    /-- 節の継続の番号。内側の handle の本体では外側の節の継続も指せる。 -/
    | resume (k : Nat) (e : Expr)

  inductive Exprs where
    | nil
    | cons (head : Expr) (tail : Exprs)

  /-- 穴は呼び出しの直接の引数だけに置ける。非穴の式には新しい引数が見えない。 -/
  inductive HoleArgs where
    | nil
    | expr (head : Expr) (tail : HoleArgs)
    | hole (ty : Ty) (tail : HoleArgs)

  inductive Arms where
    | nil
    | cons (alts : List Alternative) (guard : Option Expr) (body : Block) (rest : Arms)

  /-- 番号 0 は継続、その後は最後の引数から順に並ぶ。arity は `_` も数える。 -/
  inductive Clauses where
    | nil
    | cons (op : OpRef) (arity ntys : Nat) (body : Block) (rest : Clauses)

  inductive Block where
    | empty
    | last (e : Expr)
    | lastBind (kind : BindKind) (boundTy : Ty) (e : Expr)
    | lastDiscard (e : Expr)
    | bind (kind : BindKind) (boundTy : Ty) (e : Expr) (rest : Block)
    | discard (e : Expr) (rest : Block)
    | seq (e : Expr) (rest : Block)
    | lastPat (kind : BindKind) (pattern : Pattern) (boundTy : Ty) (e : Expr)
    | bindPat (kind : BindKind) (pattern : Pattern) (boundTy : Ty) (e : Expr) (rest : Block)
end

def HoleArgs.holeTypes : HoleArgs → List Ty
  | .nil => []
  | .expr _ rest => rest.holeTypes
  | .hole t rest => t :: rest.holeTypes

/-- 単一選択肢・恒等対応・ガードなしの分岐の短縮形。 -/
def Arms.single (pat : Pattern) (body : Block) (rest : Arms) : Arms :=
  .cons [⟨pat, List.range pat.binders⟩] none body rest

/-- ガードなしの分岐の全選択肢だけを網羅性に数える。 -/
def Arms.unguardedPatterns : Arms → List Release.Pat
  | .nil => []
  | .cons alts none _ rest => (Alternative.toCoreList alts).map Release.Alt.pat ++ rest.unguardedPatterns
  | .cons _ (some _) _ rest => rest.unguardedPatterns

/-- handled は操作名だけを読む。本体を型付けに依存せずに捨てた節の並び。 -/
def Clauses.skeleton : Clauses → List Release.Clause
  | .nil => []
  | .cons o n k _ rest => .mk o n k (.ret (.const .unit)) :: rest.skeleton

/-- パイプの規則 2。呼び出しと裸の構成子の名前は別の規則で型付けする。 -/
def Expr.PipeValue : Expr → Prop
  | .call _ _ | .conCall _ _ _ | .conValue _ _ _ => False
  | _ => True

def Exprs.length : Exprs → Nat
  | .nil => 0
  | .cons _ es => es.length + 1

mutual
  /-- 01-06「必ず抜ける文」。呼び出しやオペランドの中まで検査しない。 -/
  def Expr.Exits : Expr → Prop
    | .returnE _ _ => True
    -- ソース言語の定数式は return を含まない。形式化では R を保つので本体の return に
    -- 型が付く場合もあるが、名前の参照として本体を辿らず、必ず抜ける文に数えない。
    | .constE _ _ => False
    | .negFloat _ => False
    | .ite _ yes no => yes.Exits ∧ no.Exits
    | .elseIf _ yes no => yes.Exits ∧ no.Exits
    | .paren e => e.Exits
    | .matchE _ _ arms => arms.Exits
    | .withE _ _ body => body.Exits
    | _ => False

  def Block.Exits : Block → Prop
    | .last e => e.Exits
    | .seq e rest => e.Exits ∨ rest.Exits
    | .bind _ _ _ rest | .discard _ rest | .bindPat _ _ _ _ rest => rest.Exits
    | _ => False

  def Arms.Exits : Arms → Prop
    | .nil => True
    | .cons _ _ body rest => body.Exits ∧ rest.Exits
end

/-- 宣言のシグネチャ。表層の型付けがコアの本体を参照しないために分ける。 -/
structure FunDecl where
  tparams : List TParam
  neffs : Nat
  params : List Ty
  ret : Ty
  eff : Eff
  dictParams : List (ClassName × Nat) := []

/-- 01-12「型クラス」: 制約ごとの辞書の引数を値の引数の前に置く。 -/
def FunDecl.dictTys (d : FunDecl) : List Ty :=
  d.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- 表層の辞書の型付けが読む、実装の本体を含まないシグネチャ。 -/
structure ImplSig where
  tparams : List TParam
  dictParams : List (ClassName × Nat)
  cls : ClassName
  target : Ty

def ImplSig.dictTys (id : ImplSig) : List Ty :=
  id.dictParams.map fun p => .dict p.1 (.tvar p.2)

structure Declarations where
  funs : FunName → Option FunDecl
  cons : ConName → Option ConDecl
  ops : OpName → Option OpDecl := fun _ => none
  effects : EffName → Option (List OpName) := fun _ => none
  classes : ClassName → Option Release.ClassDecl := fun _ => none
  impls : ImplName → Option ImplSig := fun _ => none

/-- PatTy・Exhaustive・opSig・handled が読む宣言の表を備えたプログラム。 -/
def Declarations.patternProgram (D : Declarations) : Release.Program :=
  { defs := fun _ => none, cons := D.cons, ops := D.ops,
    effects := D.effects, classes := D.classes, impls := fun _ => none }

structure Def extends FunDecl where
  body : Block

/-- D-Impl。上位の辞書は根拠、メソッドの本体は表層のブロックで持つ。 -/
structure ImplDecl extends ImplSig where
  supers : ClassName → Option DictEv
  methods : MethName → Option Block

def ImplDecl.methTy (id : ImplDecl) (ms : MethSig) (t : Ty) : Ty :=
  t.substAt ms.tparams.length [id.target] []

/-- 01-05 の型パラメータは無制約。番号は構成子の宣言と同じ。 -/
def accessorDecl (cd : ConDecl) (k : Nat) : FunDecl :=
  { tparams := List.replicate cd.ntys {}, neffs := 0,
    params := [.data cd.data ((List.range cd.ntys).map Ty.tvar)],
    ret := (cd.args[k]?).getD (.base .unit), eff := Eff.empty }

structure Program where
  defs : FunName → Option Def
  cons : ConName → Option ConDecl
  ops : OpName → Option OpDecl := fun _ => none
  effects : EffName → Option (List OpName) := fun _ => none
  classes : ClassName → Option Release.ClassDecl := fun _ => none
  impls : ImplName → Option ImplDecl := fun _ => none

  /-- 関数名からレコードの構成子と宣言中のフィールドの位置を引く。 -/
  accessors : FunName → Option (ConName × Nat) := fun _ => none

/-- 通常の定義を先に引く。宣言と脱糖後の Σ が同じ優先順を使う。
RecordsOk は処理系の BindingId に合わせ、両方の表の重複を排除する。
RecordsOk の下では優先の順は結果に影響しない。 -/
def Program.lookupFun {α : Type} (p : Program) (ordinary : Def → α)
    (accessor : ConName → ConDecl → Nat → α) (f : FunName) : Option α :=
  match p.defs f with
  | some d => some (ordinary d)
  | none => match p.accessors f with
      | none => none
      | some (c, k) => (p.cons c).map fun cd => accessor c cd k

def Program.declarations (p : Program) : Declarations :=
  { funs := p.lookupFun Def.toFunDecl (fun _ cd k => accessorDecl cd k), cons := p.cons,
    ops := p.ops, effects := p.effects, classes := p.classes,
    impls := fun i => (p.impls i).map ImplDecl.toImplSig }

end Benitoite.Surface
