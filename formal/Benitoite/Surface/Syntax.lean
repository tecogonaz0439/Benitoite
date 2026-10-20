import Benitoite.Release.BuiltinTable
import Benitoite.Surface.BuilderSyntax
import Benitoite.Release.Coverage

/-!
# 型の情報を付けた表層の構文（C1・C2・C4・C5a-1・C6a-1・C6a-2・C6a-3・C7b-2）

名前解決と型検査の後の情報を持つ。型とエフェクトは Release のものを使う。
局所変数は de Bruijn の番号であり、引数の最後が番号 0 である。
`bind`・`shadow` は続きを一つ束縛し、`bind _` と式文は束縛しない。
リストと通常の引数は `Exprs`、穴を含む引数は `HoleArgs`、分岐は `Arms`、ハンドラの節は `Clauses` で表し、
脱糖の相互再帰を構造的にする。通常呼び出しと穴には、ソース順のラベルと契約上の位置を持たせる。パターンの束縛の番号は Release の `binds` に合わせる。
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

/-- 演算子の閉じた型集合。等値の制約は組み込みの表の admits が検査する。
表が不正な算術を含んでも、表層の規則はその型を受理しない（設計書 01-12「型の情報を付けた表層の構文と型付け」）。 -/
def Operator.allowed : Operator → Ty → Bool
  | .binary .add, .base .string => true
  | .binary .add, t | .binary .sub, t | .binary .mul, t => arithmeticB t
  | .binary .div, t => divisionB t
  | .binary .intDiv, t | .binary .mod, t => integerArithmeticB t
  | .binary .lt, t | .binary .le, t | .binary .gt, t | .binary .ge, t => orderedB t
  | .binary .eq, _ | .binary .ne, _ => true
  | .neg, t => negationB t

/-- 表層のリテラル。Unit は `Expr.unit` に分ける。Decimal は係数と scale を持つ。 -/
inductive Literal where
  | integer (n : Integer64Literal)
  | float (x : Float)
  | decimal (n : Int) (scale : Nat)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)
  /-- 接尾辞の幅は構成子に、符号反転前の大きさは自然数に持つ。
  字句の読み取りと値域の検査は対象外である（設計書 07-04「01-12 との対応」）。 -/
  | integer8 (n : Nat)
  | integer16 (n : Nat)
  | integer32 (n : Nat)
  | byte (n : Nat)
  | unsignedInteger16 (n : Nat)
  | unsignedInteger32 (n : Nat)
  | unsignedInteger64 (n : Nat)
  /-- 数字列から binary32 への丸めを終えたビット列。 -/
  | float32 (bits : UInt32)

def Literal.toConst : Literal → Const
  | .integer n => .integer n.toValue
  | .float x => .float x
  | .decimal n scale => .decimal n scale
  | .string s => .string s
  | .character c => .character c
  | .boolean b => .boolean b
  | .integer8 n => .integer8 (Int.ofNat n)
  | .integer16 n => .integer16 (Int.ofNat n)
  | .integer32 n => .integer32 (Int.ofNat n)
  | .byte n => .byte n
  | .unsignedInteger16 n => .unsignedInteger16 (Int.ofNat n)
  | .unsignedInteger32 n => .unsignedInteger32 (Int.ofNat n)
  | .unsignedInteger64 n => .unsignedInteger64 (Int.ofNat n)
  | .float32 bits => .float32 bits

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
  | integer (n : Integer64Literal)
  | negInt (n : Integer64Magnitude)
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
    | .integer n => .const (.integer n.toValue)
    | .negInt n => .const (.integer n.negValue)
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
    | .range (.integer lo) (.integer hi) => lo.toInt ≤ hi.toInt
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

/-- 節の辞書の所属。outer は節の外側の値環境の長さである。 -/
structure ClauseScope where
  outer : Nat
  arity : Nat
  dictCount : Nat
  deriving DecidableEq

/-- 宣言順の辞書番号を、継続と値引数の後の de Bruijn 番号へ写す。 -/
def ClauseScope.slot (s : ClauseScope) (i : Nat) : Nat :=
  1 + s.arity + (s.dictCount - 1 - i)

/-- 01-12「型クラス」: 型検査が決めた辞書。節の所属を普通の局所番号と区別する。 -/
inductive DictEv where
  | impl (i : ImplName) (tys : List Ty) (args : List DictEv)
  | local (j : Nat)
  /-- depth は節の内側で追加した値束縛の数。所属は内側のラムダでも保つ。 -/
  | clause (scope : ClauseScope) (constraint : Nat) (depth : Nat := 0)
  | super (d : DictEv) (s : ClassName)

mutual
  /-- V-Dict・受け取った辞書・V-Super。計算も let も作らない。 -/
  def DictEv.toVal : DictEv → Release.Val
    -- 01-12「型クラス」V-Dict: I[T̄](V̄)。
    | .impl i ts ds => .dict i ts (DictEv.toValList ds)
    -- 同節の辞書の決め方: 受け取った辞書の引数 d。
    | .local j => .var j
    | .clause s i depth => .var (depth + s.slot i)
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

/-- 公開の変換関数は宣言の実名を保ち、内部の Boolean の変換には value を使う。 -/
def InterpPart.converterName : Ty → String
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .unsignedInteger16 | .base .unsignedInteger32 | .base .unsignedInteger64
  | .base .float32 => "n"
  | .base .float | .base .decimal => "x"
  | .base .character => "c"
  | .base .byte => "b"
  | _ => "value"

def InterpPart.converterTypes : List InterpPart → List Ty
  | [] => []
  | .converted t :: ps => .fn [converterName t] [t] (.base .string) Eff.empty :: converterTypes ps
  | _ :: ps => converterTypes ps

/-- 01-06「演算子の型付け」の補間に許す型。補間の制約を持つ型変数は型パラメータと等しくなれず、
本体の検査を終えた時点で具体的な型に決まる。幅付きの七種も変換を許す。 -/
def InterpPart.Allowed : List InterpPart → Prop
  | [] => True
  | .converted t :: ps =>
      (t = .base .integer ∨ t = .base .float ∨ t = .base .character ∨
        t = .base .boolean ∨ t = .base .byte ∨ t = .base .decimal ∨
        t = .base .integer8 ∨ t = .base .integer16 ∨ t = .base .integer32 ∨
        t = .base .unsignedInteger16 ∨ t = .base .unsignedInteger32 ∨
        t = .base .unsignedInteger64 ∨ t = .base .float32) ∧ Allowed ps
  | _ :: ps => Allowed ps

def InterpPart.count : List InterpPart → Nat
  | [] => 0
  | .text s :: ps => (if s = "" then 0 else 1) + count ps
  | _ :: ps => 1 + count ps

/-- 位置フィールドの契約名。宣言中の位置から arg1, arg2, … を作る。 -/
def positionalNames (n : Nat) : List String :=
  (List.range n).map fun i => "arg" ++ toString (i + 1)

/-- 辞書の内部名。% は表層の識別子に含まれない（設計書 01-01「識別子」）。 -/
def internalNames (n : Nat) : List String :=
  (List.range n).map fun i => "%dict" ++ toString (i + 1)

/-- ラベルはソース順で位置と対応する。通常呼び出しの位置指定は一引数だけである。
パイプ挿入は位置 0 を先に占め、明示引数からの重複も Perm で排除する。 -/
def CallOk (names : List String) (params : List Ty) (inserted : Bool)
    (labels : List (Option String)) (positions : List Nat) : Prop :=
  NamesWF names params ∧ labels.length = positions.length ∧
    ((if inserted then [0] else []) ++ positions).Perm (List.range params.length) ∧
    ((labels = [] ∧ positions = []) ∨
      (inserted = false ∧ params.length = 1 ∧ labels = [none] ∧ positions = [0]) ∨
      (labels = positions.map (fun i => names[i]?) ∧
        ∀ label ∈ labels, label.isSome = true))

/-- 宣言順の型から、明示引数のソース順の期待型を取り出す。
範囲外の既定値は CallOk が排除する。 -/
def sourceTypes (params : List Ty) (positions : List Nat) : List Ty :=
  positions.map fun i => params[i]?.getD (.base .unit)

mutual
  inductive Expr where
    | local (i : Nat)
    /-- セルは専用位置から読み、通常引数だけを Exprs に保持する。 -/
    | builderOp (op : BuilderOp) (i : Nat) (args : Exprs) (kind : BuilderKind)
    /-- 01-12「トップレベルの定数」。宣言の型と本体を参照の位置に埋め込む（P5）。
    本体の中の定数参照も埋め込んだ有限の木。型引数を受け取らず、局所変数を捕えない。 -/
    | constE (ty : Ty) (body : Expr)
    | funName (f : FunName) (tys : List Ty) (effs : List Eff)
    /-- 01-12「型クラス」の表の第 4 行。params は具体化した値の引数の型。 -/
    | funDicts (f : FunName) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (names : List String) (params : List Ty)
    /-- 同表の第 2 行。dicts はメソッド自身の制約、params は辞書を除いた引数型。 -/
    | methName (dict : DictEv) (m : MethName) (tys : List Ty) (effs : List Eff)
        (dicts : List DictEv) (names : List String) (params : List Ty)
    | primName (b : PrimName) (tys : List Ty) (effs : List Eff)
    | opName (o : OpName) (tys : List Ty)
    /-- 辞書は操作名を解決した位置で選ぶ。params と names は公開の値引数だけ。 -/
    | opDicts (o : OpName) (tys : List Ty) (dicts : List DictEv)
        (names : List String) (params : List Ty)
    /-- 標準 Fail.raise。通常の操作表には登録しない。 -/
    | raise (result error : Ty)
    /-- 型付け後の非再開の一節。通常節の列との混在を表さない。 -/
    | handleFail (error result : Ty) (body clause : Block)
    | nullCon (c : ConName) (tys : List Ty)
    | conValue (c : ConName) (tys : List Ty) (names : List String) (params : List Ty)
    | literal (l : Literal)
    | negInt (n : Integer64Magnitude)
    /-- 括弧を挟まず Float リテラル x に適用した単項の -。x は符号反転前の値。 -/
    | negFloat (x : Float)
    /-- 括弧を挟まず Decimal リテラルへ適用した -。scale を変えない。 -/
    | negDecimal (n : Int) (scale : Nat)
    /-- 括弧を挟まない符号付きリテラルの負号。最小値も正の大きさから作る。
    符号なしの負号はこの形を持たず、一般の neg の型付けで拒否する。 -/
    | negInteger8 (n : Nat)
    | negInteger16 (n : Nat)
    | negInteger32 (n : Nat)
    /-- binary32 の符号反転前のビット列。 -/
    | negFloat32 (bits : UInt32)
    | unit
    | paren (e : Expr)
    /-- 文列の値を返し、囲む関数の戻り先と末尾位置を保つ。 -/
    | block (body : Block)
    | conCall (c : ConName) (tys : List Ty) (args : Exprs)
    /-- positions は書いた各フィールドの宣言中の位置。全フィールドを一度ずつ書く。 -/
    | record (c : ConName) (tys : List Ty) (positions : List Nat) (args : Exprs)
    /-- n は全フィールド数、tys は base の型引数。positions と args は書いた順。 -/
    | recordUpdate (c : ConName) (tys : List Ty) (n : Nat) (positions : List Nat)
        (base : Expr) (args : Exprs)
    /-- labels と positions は明示引数のソース順。callee の契約との対応は CallOk が検査する。 -/
    | call (callee : Expr) (labels : List (Option String)) (positions : List Nat) (args : Exprs)
    | pipe (lhs rhs : Expr)
    /-- 一つ以上の穴を持つ呼び出し。names は callee の型と一致する元の契約。
    戻り値・エフェクトは展開後のラムダの情報。ラベルのない穴も names から実名を取る。 -/
    | partialCall (callee : Expr) (names : List String) (args : HoleArgs) (ret : Ty) (eff : Eff)
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
    | lam (names : List String) (params : List Ty) (ret : Ty) (eff : Eff) (body : Block)
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
    /-- die の先行構文。成功型と標準の参照を持ち、囲む関数の戻り値を持たない。
    辞書と説明は入力と同じ字句スコープにある。型付けは E_TryResultDie・E_TryOptionDie、
    検査は checkExprR の die の場合で行う。処理系には未接続である
    （設計書 01-12「die の先行モデル」、07-04「道具と置き場所」）。 -/
    | tryResultDie (successTy : Ty) (ok err : ConName) (dict : DictEv) (showMethod : MethName)
        (exit : PrimName) (e : Expr) (message : Option Expr)
    /-- Option の失敗原因は固定の String であり、Show の辞書を必要としない。 -/
    | tryOptionDie (successTy : Ty) (someCon noneCon : ConName) (exit : PrimName)
        (e : Expr) (message : Option Expr)
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

  /-- 穴は呼び出しの直接の引数だけに置ける。各要素はソース順のラベルと契約位置を持つ。
  非穴の式には新しい引数が見えない。 -/
  inductive HoleArgs where
    | nil
    | expr (label : Option String) (position : Nat) (head : Expr) (tail : HoleArgs)
    | hole (label : Option String) (position : Nat) (ty : Ty) (tail : HoleArgs)

  inductive Arms where
    | nil
    | cons (alts : List Alternative) (guard : Option Expr) (body : Block) (rest : Arms)

  /-- 番号 0 は継続、その後は最後の引数から順に並ぶ。arity は `_` も数える。 -/
  inductive Clauses where
    | nil
    | cons (op : OpRef) (arity ntys : Nat) (body : Block) (rest : Clauses) (dictCount : Nat := 0)

  inductive Block where
    | builderBind (kind : BuilderKind) (rest : Block)
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

/-- 穴の型だけをソース順に集める。契約位置順への並べ替えは行わない。 -/
def HoleArgs.holeTypes : HoleArgs → List Ty
  | .nil => []
  | .expr _ _ _ rest => rest.holeTypes
  | .hole _ _ t rest => t :: rest.holeTypes

def HoleArgs.labels : HoleArgs → List (Option String)
  | .nil => []
  | .expr label _ _ rest | .hole label _ _ rest => label :: rest.labels

def HoleArgs.positions : HoleArgs → List Nat
  | .nil => []
  | .expr _ i _ rest | .hole _ i _ rest => i :: rest.positions

/-- 穴の名前は元の契約から取り出し、穴を書いた順を維持する。 -/
def HoleArgs.holeNames (names : List String) : HoleArgs → List String
  | .nil => []
  | .expr _ _ _ rest => rest.holeNames names
  | .hole _ i _ rest => names[i]?.getD "" :: rest.holeNames names

/-- 直接の構成子の穴にはラベルを許さず、宣言の位置順を保つ。 -/
def HoleArgs.ConstructorOk (args : HoleArgs) (n : Nat) : Prop :=
  args.labels = List.replicate n none ∧ args.positions = List.range n

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
  | .cons o n k _ rest d => .mk o (d + n) k (.ret (.const .unit)) :: rest.skeleton

/-- パイプの規則 2。呼び出しと裸の構成子の名前は別の規則で型付けする。 -/
def Expr.PipeValue : Expr → Prop
  | .call _ _ _ _ | .conCall _ _ _ | .conValue _ _ _ _ => False
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
    | .block body => body.Exits
    | .matchE _ _ arms => arms.Exits
    | .withE _ _ body => body.Exits
    | _ => False

  def Block.Exits : Block → Prop
    | .builderBind _ rest => rest.Exits
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
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  dictParams : List (ClassName × Nat) := []

/-- 01-12「型クラス」: 制約ごとの辞書の引数を値の引数の前に置く。 -/
def FunDecl.dictTys (d : FunDecl) : List Ty :=
  d.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- コアの引数名は内部辞書と利用者の契約をこの順に持つ。 -/
def FunDecl.coreNames (d : FunDecl) : List String :=
  internalNames d.dictParams.length ++ d.names

/-- 表層の辞書の型付けが読む、実装の本体を含まないシグネチャ。 -/
structure ImplSig where
  tparams : List TParam
  dictParams : List (ClassName × Nat)
  cls : ClassName
  target : Ty

def ImplSig.dictTys (id : ImplSig) : List Ty :=
  id.dictParams.map fun p => .dict p.1 (.tvar p.2)

structure Declarations where
  /-- この本体のソース照合で将来の形を加える型（設計書 01-12「型の情報を付けた表層の構文と型付け」）。 -/
  view : CoverageView := closedView
  funs : FunName → Option FunDecl
  cons : ConName → Option ConDecl
  /-- レコード構成子だけが持つ宣言順のフィールド名。 -/
  conFields : ConName → Option (List String) := fun _ => none
  ops : OpName → Option OpDecl := fun _ => none
  effects : EffName → Option (List OpName) := fun _ => none
  classes : ClassName → Option Release.ClassDecl := fun _ => none
  impls : ImplName → Option ImplSig := fun _ => none

/-- PatTy・Exhaustive・opSig・handled が読む宣言の表を備えたプログラム。 -/
def Declarations.patternProgram (D : Declarations) : Release.Program :=
  { defs := fun _ => none, cons := D.cons, ops := D.ops,
    effects := D.effects, classes := D.classes, impls := fun _ => none }

/-- view だけを替えてもコアに渡す宣言を変えない。 -/
def Declarations.withView (D : Declarations) (view : CoverageView) : Declarations :=
  { D with view }

@[simp] theorem Declarations.withView_patternProgram (D : Declarations) (view : CoverageView) :
    (D.withView view).patternProgram = D.patternProgram := rfl

@[simp] theorem Declarations.withView_funs (D : Declarations) (view : CoverageView) :
    (D.withView view).funs = D.funs := rfl

@[simp] theorem Declarations.withView_cons (D : Declarations) (view : CoverageView) :
    (D.withView view).cons = D.cons := rfl

@[simp] theorem Declarations.withView_conFields (D : Declarations) (view : CoverageView) :
    (D.withView view).conFields = D.conFields := rfl

@[simp] theorem Declarations.withView_ops (D : Declarations) (view : CoverageView) :
    (D.withView view).ops = D.ops := rfl

@[simp] theorem Declarations.withView_effects (D : Declarations) (view : CoverageView) :
    (D.withView view).effects = D.effects := rfl

@[simp] theorem Declarations.withView_classes (D : Declarations) (view : CoverageView) :
    (D.withView view).classes = D.classes := rfl

@[simp] theorem Declarations.withView_impls (D : Declarations) (view : CoverageView) :
    (D.withView view).impls = D.impls := rfl

/-- ソース照合の追加条件。完全な宣言表で view 付き有用性がないことを要求する。
将来の形を現在の値とせず、現在のコアの網羅性を導く（設計書 01-12「型の情報を付けた表層の構文と型付け」）。 -/
def ViewExhaustive (D : Declarations) (view : CoverageView) (a : Ty)
    (ps : List Release.Pat) : Prop :=
  ∃ ctors, CtorsComplete D.patternProgram ctors ∧
    usefulWithView D.patternProgram ctors view [a] (ps.map fun p => [p]) [.wild] = none

/-- ソースの追加条件から従来の現在の値についての網羅性へ接続する。 -/
theorem ViewExhaustive.exhaustive {D view a ps} (h : ViewExhaustive D view a ps) :
    Exhaustive D.patternProgram a ps := by
  obtain ⟨ctors, hc, hu⟩ := h
  intro v hv
  exact usefulWithView_singleton_none_sound D.patternProgram ctors view a ps .wild hc hu v hv rfl

def Declarations.constructorNames (D : Declarations) (c : ConName) (cd : ConDecl) : List String :=
  (D.conFields c).getD (positionalNames cd.args.length)

structure Def extends FunDecl where
  body : Block

/-- D-Impl。上位の辞書は根拠、メソッドの本体は表層のブロックで持つ。 -/
structure ImplDecl extends ImplSig where
  supers : ClassName → Option DictEv
  methods : MethName → Option Block

noncomputable def ImplDecl.methTy (id : ImplDecl) (ms : MethSig) (t : Ty) : Ty :=
  t.substAt ms.tparams.length [id.target] []

/-- 01-05 の型パラメータは無制約。番号は構成子の宣言と同じ。 -/
def accessorDecl (cd : ConDecl) (k : Nat) : FunDecl :=
  { tparams := List.replicate cd.ntys {}, neffs := 0,
    names := ["value"], params := [.data cd.data ((List.range cd.ntys).map Ty.tvar)],
    ret := (cd.args[k]?).getD (.base .unit), eff := Eff.empty }

structure Program where
  /-- 関数の本体ごとの有効な指定。旧い入力は閉じたまま読む。 -/
  functionViews : FunName → CoverageView := fun _ => closedView
  /-- 同じ実装のメソッドも、それぞれの本体の指定を選ぶ。 -/
  methodViews : ImplName → MethName → CoverageView := fun _ _ => closedView
  defs : FunName → Option Def
  cons : ConName → Option ConDecl
  /-- レコード構成子だけが持つ宣言順のフィールド名。 -/
  conFields : ConName → Option (List String) := fun _ => none
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
  { funs := p.lookupFun Def.toFunDecl (fun _ cd k => accessorDecl cd k), cons := p.cons, conFields := p.conFields,
    ops := p.ops, effects := p.effects, classes := p.classes,
    impls := fun i => (p.impls i).map ImplDecl.toImplSig }

/-- 共有する宣言を保ち、本体のソース照合にだけ指定を渡す。 -/
def Program.declarationsFor (p : Program) (view : CoverageView) : Declarations :=
  p.declarations.withView view

@[simp] theorem Program.declarationsFor_patternProgram (p : Program) (view : CoverageView) :
    (p.declarationsFor view).patternProgram = p.declarations.patternProgram := rfl

@[simp] theorem Program.declarationsFor_funs (p : Program) (view : CoverageView) :
    (p.declarationsFor view).funs = p.declarations.funs :=
  Declarations.withView_funs p.declarations view

@[simp] theorem Program.declarationsFor_cons (p : Program) (view : CoverageView) :
    (p.declarationsFor view).cons = p.declarations.cons :=
  Declarations.withView_cons p.declarations view

@[simp] theorem Program.declarationsFor_conFields (p : Program) (view : CoverageView) :
    (p.declarationsFor view).conFields = p.declarations.conFields :=
  Declarations.withView_conFields p.declarations view

@[simp] theorem Program.declarationsFor_ops (p : Program) (view : CoverageView) :
    (p.declarationsFor view).ops = p.declarations.ops :=
  Declarations.withView_ops p.declarations view

@[simp] theorem Program.declarationsFor_effects (p : Program) (view : CoverageView) :
    (p.declarationsFor view).effects = p.declarations.effects :=
  Declarations.withView_effects p.declarations view

@[simp] theorem Program.declarationsFor_classes (p : Program) (view : CoverageView) :
    (p.declarationsFor view).classes = p.declarations.classes :=
  Declarations.withView_classes p.declarations view

@[simp] theorem Program.declarationsFor_impls (p : Program) (view : CoverageView) :
    (p.declarationsFor view).impls = p.declarations.impls :=
  Declarations.withView_impls p.declarations view

@[simp] theorem Program.declarationsFor_closed (p : Program) :
    p.declarationsFor closedView = p.declarations := rfl

end Benitoite.Surface
