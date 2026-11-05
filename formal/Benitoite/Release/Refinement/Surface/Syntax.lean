import Benitoite.Release.Refinement.Syntax
import Benitoite.Release.Coverage

/-!
# 篩付きの型の情報を付けた表層の構文

名前解決と型検査の後の情報を持つ表層の構文である（設計書 01-12「型の情報を付けた表層の構文と型付け」）。型と
エフェクトは篩付きの型の判断の `Ty`・`Eff` を使う。篩の注釈は型の側の `Ty.refined` で表すので、式の構成子を
増やさない。型の別名の値引数と範囲パラメータの適用、一般の check（`Refinement.check(value:)`）、生成する構成子の
判定の関数の呼出しは、既存の呼出しの形で表す。
局所変数は de Bruijn の番号であり、引数の最後が番号 0 である。`bind`・`shadow` は続きを一つ束縛し、`bind _` と
式文は束縛しない。リストと通常の引数は `Exprs`、穴を含む引数は `HoleArgs`、分岐は `Arms`、ハンドラの節は
`Clauses` で表し、脱糖の相互再帰を構造的にする。
-/

namespace Benitoite.Release.Refinement.Surface

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

inductive BindKind where
  | bind | shadow
  deriving DecidableEq

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
  | range (lo hi : Const)
  | list (before : List Pattern) (rest : Option ListRest) (after : List Pattern)
  | con (qualifier : Option DataName) (c : ConName) (args : List Pattern)
  /-- n は全フィールド数。positions と args は書いた順の並行したリスト。
  省略したフィールドは wild。束縛の順は宣言の順。 -/
  | record (c : ConName) (n : Nat) (positions : List Nat) (args : List Pattern)

/-- slots は分岐の変数ごとに使う束縛の位置。最初の選択肢は恒等対応である。 -/
structure Alternative where
  pat : Pattern
  slots : List Nat

/-- 節の辞書の所属。outer は節の外側の値環境の長さである。 -/
structure ClauseScope where
  outer : Nat
  arity : Nat
  dictCount : Nat
  deriving DecidableEq

/-- 01-12「型クラス」: 型検査が決めた辞書。節の所属を普通の局所番号と区別する。 -/
inductive DictEv where
  | impl (i : ImplName) (tys : List Ty) (args : List DictEv)
  | local (j : Nat)
  /-- depth は節の内側で追加した値束縛の数。所属は内側のラムダでも保つ。 -/
  | clause (scope : ClauseScope) (constraint : Nat) (depth : Nat := 0)
  | super (d : DictEv) (s : ClassName)

/-- 種類の省略は、型ごとの既存の表記を使う。 -/
inductive FormatKind where
  | default | d | b | o | x | upperX | f | s | c
  deriving DecidableEq, Repr

/-- 寄せの省略は、数なら右、それ以外なら左と解釈する。 -/
inductive FormatAlign where
  | default | left | right | center
  deriving DecidableEq, Repr

/-- 明示できる符号指定は + だけである。 -/
inductive FormatSign where
  | default | plus
  deriving DecidableEq, Repr

/-- 元の字面と位置は持たず、幅・精度の省略と明示を区別する。 -/
structure FormatSpec where
  kind : FormatKind := .default
  align : FormatAlign := .default
  sign : FormatSign := .default
  alternate : Bool := false
  zero : Bool := false
  width : Option Nat := none
  precision : Option Nat := none
  deriving DecidableEq, Repr

/-- 補間の並行したリストの案内。子の式を含まないため、入れ子の帰納型にならない。
text の空文字列は脱糖で省く。converted は String 以外の式と変換関数を一つずつ使い、
formatted は String を含む式と七定数を受ける書式化の関数を一つずつ使う。 -/
inductive InterpPart where
  | text (s : String)
  | stringExpr
  | converted (ty : Ty)
  | formatted (ty : Ty) (spec : FormatSpec)

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
    /-- 組み込みの関数の名前。`ranges` は型検査器が選んだ範囲の変数の具体化（範囲の変数のない項目では空の列。
    設計書 01-12「型の情報を付けた表層の構文と型付け」）。 -/
    | primName (b : PrimName) (tys : List Ty) (effs : List Eff) (ranges : List Scope.Domain.Range)
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
    /-- parts の式の部分と es、converted・formatted の部分と converters がそれぞれ対応する。 -/
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

/-! ## 宣言 -/

/-- 関数の宣言のシグネチャ。型パラメータの文脈・辞書と値の引数・結果・効果を持ち、引数と結果の型は前の引数を値
変数として参照できる（最後の引数が番号 0）。`rangeParams` は宣言した範囲パラメータの種類の列（`[range R: path]`）、
`proofSteps` は `@proofSteps(n)` の指定（正の整数で、トップレベルの関数だけが持つ）であり、篩の証明の検査の上限として
検査器へ渡す。 -/
structure FunDecl where
  tparams : TypeCtx
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  dictParams : List (ClassName × Nat) := []
  rangeParams : List Scope.Domain.Kind := []
  proofSteps : Option Nat := none

/-- 表層の辞書の型付けが読む、実装の本体を含まないシグネチャ。 -/
structure ImplSig where
  tparams : List TParam
  dictParams : List (ClassName × Nat)
  cls : ClassName
  target : Ty

/-- 型の別名の宣言。型パラメータ・値引数（篩の項に現れる種類の値）・範囲パラメータを持ち、本体は篩付きの型である。
本体は値引数を値変数（最後の値引数が番号 0）、範囲パラメータを範囲の変数として読む。 -/
structure AliasDecl where
  tparams : TypeCtx
  valueParams : List (String × Ty)
  rangeParams : List Scope.Domain.Kind := []
  body : Ty

/-- record の宣言。欄の型は前の欄を値変数として参照できる（直前の欄が番号 0）。核の構成子の宣言 `ConDecl` には欄の
篩を除いた型を置き、欄どうしの依存は record 全体の篩（`Ty.refined (.data data ts) p`）へ写す。 -/
structure RecordDecl where
  data : DataName
  ntys : Nat
  fields : List (String × Ty)

structure Declarations where
  /-- この本体のソース照合で将来の形を加える型（設計書 01-12「型の情報を付けた表層の構文と型付け」）。 -/
  view : CoverageView := closedView
  funs : FunName → Option FunDecl
  cons : ConName → Option ConDecl
  /-- レコード構成子だけが持つ宣言順のフィールド名。 -/
  conFields : ConName → Option (List String) := fun _ => none
  ops : OpName → Option OpDecl := fun _ => none
  effects : EffName → Option (List OpName) := fun _ => none
  classes : ClassName → Option ClassDecl := fun _ => none
  impls : ImplName → Option ImplSig := fun _ => none
  /-- 型の別名の宣言。 -/
  aliases : String → Option AliasDecl := fun _ => none
  /-- 欄どうしの依存を持つ record の構成子の宣言。 -/
  records : ConName → Option RecordDecl := fun _ => none
  /-- 生成した構成子の判定の関数の名前から、判定する構成子の名前を引く。 -/
  testers : FunName → Option ConName := fun _ => none

structure Def extends FunDecl where
  body : Block

/-- 上位の辞書は根拠、メソッドの本体は表層のブロックで持つ。 -/
structure ImplDecl extends ImplSig where
  supers : ClassName → Option DictEv
  methods : MethName → Option Block

structure Program where
  /-- 関数の本体ごとの有効な指定。 -/
  functionViews : FunName → CoverageView := fun _ => closedView
  /-- 同じ実装のメソッドも、それぞれの本体の指定を選ぶ。 -/
  methodViews : ImplName → MethName → CoverageView := fun _ _ => closedView
  defs : FunName → Option Def
  cons : ConName → Option ConDecl
  conFields : ConName → Option (List String) := fun _ => none
  ops : OpName → Option OpDecl := fun _ => none
  effects : EffName → Option (List OpName) := fun _ => none
  classes : ClassName → Option ClassDecl := fun _ => none
  impls : ImplName → Option ImplDecl := fun _ => none
  /-- 関数名からレコードの構成子と宣言中のフィールドの位置を引く。 -/
  accessors : FunName → Option (ConName × Nat) := fun _ => none
  aliases : String → Option AliasDecl := fun _ => none
  records : ConName → Option RecordDecl := fun _ => none
  testers : FunName → Option ConName := fun _ => none

/-- 構築器の局所の文脈。専用位置の種類を値の環境と同じ番号で持つ。 -/
abbrev BuilderCtx := List (Option BuilderKind)

end Benitoite.Release.Refinement.Surface
