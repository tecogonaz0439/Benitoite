import Benitoite.Release.TypeSubst

/-!
# 契約名を持つコア計算の構文

設計書 01-12「コア計算と脱糖」の「初回リリース版の拡張」のうち、コア計算に構成を加えるものを書き写す。
段階 B1 は、制御の構成（ストア、`escape`、`with`、プロセスの終了、エフェクトの名前、ハンドラ）と、型パラメータの
組み込みの制約（01-12「型パラメータの組み込みの制約」）を加えた。段階 B2 は、`Map`・`Set`・`Bytes` と、型クラスの辞書
（高カインド型を含む）を加える（設計書 07-04「進め方」）。段階 A（`Benitoite.Core`）の定義は最小実行版の
ものとして残し、段階 B は別の名前空間に写して広げる。段階 B2 は、段階 B1 の定義を同じ名前空間で広げる。

契約名は関数型・ラムダ・関数と操作の宣言・メソッドのシグネチャの静的な注釈として保持する。
既存のコアの規則（設計書 01-12「コア計算と脱糖」）から、値の束縛と位置による実行を引き継ぐ。

段階 A からの表現の違い（設計書 07-04「01-12 との対応」の表に記す）:

- 型の変数は、内側から数えた de Bruijn の番号で表す。関数の定義の本体では、定義の型パラメータが
  `0..n-1` である。`handle` の節は、操作の型パラメータを番号 `0..k-1` に束縛し、節の外側の型の変数の番号を
  k だけずらす（01-06「エフェクトの宣言とハンドラの型付け（初回リリース版）」の「その型パラメータをほかの何とも等しくない型として
  扱う」）。閉じた値は、節の内側へ運んでも変わらない。
- エフェクトの原子は、エフェクトの名前（モジュールと名前の組を一つの文字列で表す）とエフェクト変数である。
- 組み込みの関数のうち、ストアの操作（`Reference.new` など）とプロセスの終了は、組み込みの関数の種類
  （`PrimKind`）で区別する。
- 高カインドの型パラメータの型引数は、型構成子 `Ty.ctor φ` か、高カインドの型パラメータ `Ty.tvar j` である。
  型の置き換えは、`α[Ā]`（`Ty.tapp`）の α を型構成子に置き換えるとき、その型構成子を Ā に適用した型にする
  （`Ty.applyTo`）。型の種類（型パラメータが値の型か型構成子か、型構成子がとる型引数の個数）は検査しない。
-/

namespace Benitoite.Release

/-- 通常の型とは別の、専用セルの分類（設計書 01-12「構築器の分類と環境の対応」）。 -/
inductive BuilderKind where
  | string | list (element : Ty) | bytes

/-- 専用操作の四分類。 -/
inductive BuilderOp where
  | append | appendAll | copy | length
  deriving DecidableEq

/-- 構築器から取り出す通常の不変値の型。 -/
def BuilderKind.contents : BuilderKind → Ty
  | .string => .base .string
  | .list t => .list t
  | .bytes => .bytes


/-- 脱糖後に専用名の位置を埋めるセルの型。 -/
def BuilderKind.cell (k : BuilderKind) : Ty := .reference k.contents


/-- 長さの参照先のラベルは既存の標準ソースに合わせる。 -/
def BuilderKind.lengthNames : BuilderKind → List String
  | .string => ["s"]
  | .list _ => ["xs"]
  | .bytes => ["b"]


/-- 一回の追記で受け取る通常値。 -/
def BuilderKind.item : BuilderKind → Ty
  | .string => .base .string
  | .list t => t
  | .bytes => .base .byte


/-- 専用操作の通常引数の契約。セルはこの列へ含めない。 -/
def BuilderOp.params (op : BuilderOp) (k : BuilderKind) : List Ty :=
  match op with
  | .copy | .length => []
  | .append => [k.item]
  | .appendAll => [match k with | .string => .list (.base .string) | _ => k.contents]


/-- 専用操作の結果も通常の Release.Ty である。 -/
def BuilderOp.result (op : BuilderOp) (k : BuilderKind) : Ty :=
  match op with
  | .copy => k.contents
  | .length => .base .integer
  | .append | .appendAll => .base .unit


/-- 通常値の場所と構文上区別する局所参照。bound は通常変数と番号を共有する。 -/
inductive LocalRef where
  | bound (index : Nat)
  | loc (location : Nat)
  deriving DecidableEq

/-- 束縛された局所参照の範囲。場所の番号には束縛の範囲を課さない。 -/
def LocalRef.Scoped (depth : Nat) : LocalRef → Prop
  | .bound i => i < depth
  | .loc _ => True

/-- 付け替えは通常変数と同じ番号へ写す。 -/
def LocalRef.rename (ξ : Nat → Nat) : LocalRef → LocalRef
  | .bound i => .bound (ξ i)
  | .loc l => .loc l

/-- 局所参照だけを置き換え、通常値へは変換しない。 -/
def LocalRef.subst (ρ : Nat → LocalRef) : LocalRef → LocalRef
  | .bound i => ρ i
  | .loc l => .loc l

/-- List の要素型だけが型代入の対象になる。 -/
noncomputable def BuilderKind.substTyAt (c : Nat) (ts : List Ty) (es : List Eff) : BuilderKind → BuilderKind
  | .string => .string
  | .list a => .list (a.substAt c ts es)
  | .bytes => .bytes

/-- 型パラメータに付けた組み込みの制約（01-06「組み込みの制約（初回リリース版）」、01-12「型パラメータの組み込みの制約」）。 -/
structure TParam where
  equality : Bool := false
  key : Bool := false

/-- 鍵の型であるという制約（V-Map・V-Set の「A は鍵の型である」）。 -/
def TParam.keyC : TParam := { key := true }

/-- Integer の下端（設計書 01-12「構文」）。 -/
def min64 : Int := -9223372036854775808
/-- Integer の上端。別幅の整数の表現は変えない。 -/
def max64 : Int := 9223372036854775807

/-- Integer の全値は構文の時点で範囲内である。 -/
abbrev Integer64Value := { n : Int // min64 ≤ n ∧ n ≤ max64 }

/-- 区間の計算に使う数学的な整数への射影。 -/
def Integer64Value.toInt (n : Integer64Value) : Int := n.val

/-- 射影した数学的な整数も Integer の両端の内側にある。 -/
theorem Integer64Value.toInt_bounds (n : Integer64Value) :
    min64 ≤ n.toInt ∧ n.toInt ≤ max64 := n.property

/-- 正のリテラルの大きさ。 -/
abbrev Integer64Literal := { n : Nat // n ≤ 9223372036854775807 }
/-- 直接負号の大きさは、正のリテラルより一つ大きい値まで許す。 -/
abbrev Integer64Magnitude := { n : Nat // n ≤ 9223372036854775808 }

/-- 正のリテラルを全域に変換する。 -/
def Integer64Literal.toValue (n : Integer64Literal) : Integer64Value :=
  ⟨Int.ofNat n.val, by have h := n.property; simp only [min64, max64, Int.ofNat_eq_natCast]; omega⟩

/-- 直接負号は最小値の大きさも受理する。 -/
def Integer64Magnitude.negValue (n : Integer64Magnitude) : Integer64Value :=
  ⟨-Int.ofNat n.val, by have h := n.property; simp only [min64, max64, Int.ofNat_eq_natCast]; omega⟩

/-- 定数。`O` の型の値（`IOError` の値、リソースなど）は、型の名前と番号で表す。 -/
inductive Const where
  | integer (n : Integer64Value)
  | float (x : Float)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)
  | unit
  | byte (n : Nat)
  | decimal (n : Int) (scale : Nat)
  | opaque (o : OpaqueName) (id : Nat)
  /-- 幅と符号は構成子で区別する。値域の検査は型付けの条件にしない（設計書 07-04「01-12 との対応」）。 -/
  | integer8 (n : Int)
  | integer16 (n : Int)
  | integer32 (n : Int)
  | unsignedInteger16 (n : Int)
  | unsignedInteger32 (n : Int)
  | unsignedInteger64 (n : Int)
  /-- binary32 の表現を保ち、旧 Float の値と区別する。丸めの計算は形式化しない。 -/
  | float32 (bits : UInt32)

def Const.type : Const → Ty
  | .integer _ => .base .integer
  | .float _ => .base .float
  | .string _ => .base .string
  | .character _ => .base .character
  | .boolean _ => .base .boolean
  | .unit => .base .unit
  | .byte _ => .base .byte
  | .decimal _ _ => .base .decimal
  | .opaque o _ => .opaqueTop o
  | .integer8 _ => .base .integer8
  | .integer16 _ => .base .integer16
  | .integer32 _ => .base .integer32
  | .unsignedInteger16 _ => .base .unsignedInteger16
  | .unsignedInteger32 _ => .base .unsignedInteger32
  | .unsignedInteger64 _ => .base .unsignedInteger64
  | .float32 _ => .base .float32

/-- パターンに許す定数の種類。数の型の追加で暗黙に許す種類が増えないよう列挙する。 -/
def Const.patternAllowed : Const → Bool
  | .integer _ | .string _ | .character _ | .boolean _ | .unit => true
  | _ => false

/-- パターンの定数の照合。P-Const が許さない種類は等しいと判定しない。 -/
def Const.matches : Const → Const → Bool
  | .integer a, .integer b => a.toInt == b.toInt
  | .string a, .string b => a == b
  | .character a, .character b => a == b
  | .boolean a, .boolean b => a == b
  | .unit, .unit => true
  | _, _ => false

/-- リストの残りの部分。`none` は残りを許さず、`some .skip` は束縛せず、
`some .bind` は残りのリストを一つの変数に束縛する。 -/
inductive ListRest where
  | skip
  | bind
  deriving DecidableEq

def ListRest.binders : ListRest → Nat
  | .skip => 0
  | .bind => 1

inductive Pat where
  | wild
  | var
  | const (c : Const)
  | con (c : ConName) (args : List Pat)
  /-- 両端を含む範囲。型付けが両端を Integer または Character に限る。 -/
  | range (lo hi : Const)
  /-- 束縛の順は、前の要素・残りの変数・後の要素である。 -/
  | list (before : List Pat) (rest : Option ListRest) (after : List Pat)

/-- 分岐の選択肢。`slots` は分岐の変数ごとに、このパターンの左から数えた束縛位置を指定する。
最初の選択肢の対応は恒等であり、後の選択肢は同じ名前の変数に当たる位置を持つ。 -/
structure Alt where
  pat : Pat
  slots : List Nat

/-- 節が処理する操作。利用者が宣言したエフェクトの操作と、組み込みのエフェクトの操作
（外部に作用する組み込みの関数）がある（01-12「ハンドラ」）。 -/
inductive OpRef where
  | user (o : OpName)
  | prim (b : PrimName)
  | fail
  deriving DecidableEq

mutual
  /-- 値。 -/
  inductive Val where
    | var (i : Nat)
    | const (c : Const)
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
    /-- 組み込みの関数 `b[T̄; Ē; R̄]`。`rs` は具体化した範囲の列（問 5）。 -/
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
    /-- 検査済みの対象の値（問 6 の A）。範囲付きの値型 `opaque o (fixed R)` の値に当たる（設計書 01-12「構文」）。
    型と値の変数を持たないので、代入・改名・shift で変わらない。表層の構文と脱糖はこの値を作らない。型付けは
    所属を前提に持つ葉の規則 V-Checked だけで行う（`HasTypeVQ.inv_checked`）。遷移の規則はこの値を特別に作らず、
    この値を作るのは組み込みの表の δ（検査の項目）である。 -/
    | checked (t : Scope.Domain.Target)
    /-- 検査済みの要求の値（決定の判断 7）。`Http.RequestIn[H,P]` の値に当たり、検査した要求 `req` と、検査で得た実効の
    endpoint の対象 `t` を保持する（設計書 01-12「構文」）。保持する要求は `Http.ClientRequest` のレコードの閉じた値
    （同じストアの型付けのもとで、空の NoFail の文脈・型の文脈・値の文脈で型を持つ値）である。型の変数を含まないことは
    規則の前提ではなく、実例の表の検査の δ が `ModelHttp.groundVal` で保証する。閉じた値なので、代入・改名・shift は
    この値を変えない（中へ下りない）。型付けは規則 V-CheckedRequest だけで行う。 -/
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

/-- 専用セルの抽象的な不変内容。List の要素も通常値である。 -/
inductive BuilderContents where
  | string (text : String)
  | list (element : Ty) (values : List Val)
  | bytes (values : List Nat)

def Arm.alts : Arm → List Alt
  | .mk alts _ _ => alts

def Arm.guard : Arm → Option Comp
  | .mk _ guard _ => guard

def Arm.body : Arm → Comp
  | .mk _ _ body => body

def Clause.op : Clause → OpRef
  | .mk o _ _ _ => o
  | .fail _ _ => .fail

def Clause.arity : Clause → Nat
  | .mk _ n _ _ => n
  | .fail _ _ => 1

def Clause.ntys : Clause → Nat
  | .mk _ _ k _ => k
  | .fail _ _ => 1

def Clause.body : Clause → Comp
  | .mk _ _ _ m => m
  | .fail _ m => m

/-- トップレベルの関数の定義。`fn f[ᾱ : c̄; ρ̄](x̄:Ā) : B ! ε = M`。`tparams` は型パラメータと、その
組み込みの制約である（01-12「型パラメータの組み込みの制約」）。 -/
structure Def where
  tparams : List TParam
  neffs : Nat
  names : List String
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
def OpDecl.dictTys (d : OpDecl) : List Ty :=
  d.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- 利用者に見える値の引数。コアの前置辞書を除く。 -/
def OpDecl.valueParams (d : OpDecl) : List Ty := d.params.drop d.dictParams.length

/-- 利用者に見える契約名。 -/
def OpDecl.valueNames (d : OpDecl) : List String := d.names.drop d.dictParams.length

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
