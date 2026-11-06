# 再開4の核の定義と規則の完全な形

本番のソースから台本で写した。名前空間は `Benitoite.Release.Refinement`。各欄の本文と全分岐を省略しない。証明と追加の読者は各本番モジュールを正とする。

## Syntax.lean（全定義と補助）

```lean
import Benitoite.Release.Refinement.Context
import Benitoite.Release.Refinement.PathResolution
import Benitoite.Release.Refinement.VarianceSyntax
import Benitoite.Release.Refinement.ScopePublic

namespace Benitoite.Release.Refinement

inductive Const where
  | integer (n : Integer64Value)
  | float64 (bits : UInt64)
  | string (s : String)
  | character (c : Char)
  | boolean (b : Bool)
  | unit
  | byte (n : Nat)
  | decimal (n : Int) (scale : Nat)
  | opaque (o : OpaqueName) (id : Nat)
  /-- 幅と符号は構成子で区別し、ConstOK が各幅の値域を型付けの前提として検査する
  （設計書 01-12「篩を含むコア計算の形式化」、07-04「篩を含む形式化の範囲」）。 -/
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
  | .float64 _ => .base .float
  | .string _ => .base .string
  | .character _ => .base .character
  | .boolean _ => .base .boolean
  | .unit => .base .unit
  | .byte _ => .base .byte
  | .decimal _ _ => .base .decimal
  | .opaque o _ => .opaque o (.fixed .top)
  | .integer8 _ => .base .integer8
  | .integer16 _ => .base .integer16
  | .integer32 _ => .base .integer32
  | .unsignedInteger16 _ => .base .unsignedInteger16
  | .unsignedInteger32 _ => .base .unsignedInteger32
  | .unsignedInteger64 _ => .base .unsignedInteger64
  | .float32 _ => .base .float32

def embedConst : Benitoite.Release.Const → Const
  | .integer n => .integer n
  | .float x => .float64 x.toBits
  | .string s => .string s
  | .character c => .character c
  | .boolean b => .boolean b
  | .unit  => .unit 
  | .byte n => .byte n
  | .decimal n s => .decimal n s
  | .opaque o i => .opaque o i
  | .integer8 n => .integer8 n
  | .integer16 n => .integer16 n
  | .integer32 n => .integer32 n
  | .unsignedInteger16 n => .unsignedInteger16 n
  | .unsignedInteger32 n => .unsignedInteger32 n
  | .unsignedInteger64 n => .unsignedInteger64 n
  | .float32 b => .float32 b

theorem Const.type_embed (c : Benitoite.Release.Const) :
    (embedConst c).type = embedTy c.type := by
  cases c <;> rfl

abbrev BuilderOp := Benitoite.Release.BuilderOp

inductive BuilderKind where
  | string | list (element : Ty) | bytes

inductive ExternalMode where
  | borrow | own
  deriving DecidableEq, BEq

noncomputable def BuilderKind.norm : BuilderKind → BuilderKind
  | .list a => .list a.norm
  | b => b


structure ExternalTypeDecl where
  id : ExternalId
  component : ComponentId
  displayName : String
  arity : Nat
  resource : Nat

inductive ExternalPosition where
  | argument (index : Nat)
  | result
  deriving DecidableEq, BEq

inductive ExternalPathStep where
  | element | key | value
  | field (constructor : ConName) (index : Nat)
  deriving DecidableEq, BEq

structure ExternalUse where
  position : ExternalPosition
  path : List ExternalPathStep
  mode : ExternalMode
  typeId : ExternalId
  deriving DecidableEq, BEq

structure ExternalSignature where
  component : ComponentId
  displayName : String
  tparams : List TParam
  kinds : KindCtx
  parameters : Tel
  uses : List ExternalUse

inductive ExternalDecl where
  | type (declaration : ExternalTypeDecl)
  | function (id : ExternalFunctionId) (signature : ExternalSignature)

inductive ExternalKey where
  | type (id : ExternalId)
  | function (id : ExternalFunctionId)
  deriving DecidableEq

structure ExternalHandle where
  typeId : ExternalId
  component : ComponentId
  resource : Nat
  identity : Nat
  deriving DecidableEq, BEq

structure ResultShape where
  owner : DataName
  ok : ConName
  error : ConName
  errorType : Ty

mutual
  /-- 値。 -/
  inductive Val where
    | var (i : Nat)
    | const (c : Const)
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff) (rs : List RangeIx := [])
    /-- 組み込みの関数 `b[T̄; Ē; R̄]`。`rs` は具体化した範囲の列。 -/
    | prim (b : PrimName) (tys : List Ty) (effs : List Eff) (rs : List RangeIx)
    | lam (names : List String) (params : List Ty) (body : Comp)
    | dependentLam (signature : Tel) (body : Comp)
    | closure (signature : Tel) (body : Closure)
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
    /-- 検査済みの対象。対象自身に型や値の自由変数はない（設計書 01-12「構文」）。 -/
    | externalRef (id : ExternalFunctionId) (types : List Ty)
    | externalHandle (handle : ExternalHandle) (types : List Ty)
    | pathBases (snapshot : PathEnv)
    | scopePattern (range : RangeExpr)
    | checkedAt (range : RangeExpr) (snapshot : Option PathEnv)
        (target : Scope.Domain.Target) (request : Option Val)
    | atError (detail : Detail Val)
    | checked (t : Scope.Domain.Target)
    /-- 要求と検査済みの endpoint を保持する。型付けの葉では閉じた要求の型付けに加え、
    groundVal と reqTarget による端点一致を検査する。葉の規則は構文と別に追加する。 -/
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
    | externalCall (id : ExternalFunctionId) (types : List Ty) (arguments : List Val)
    | issuePathBases (primitive : PrimName)
    | checkAt (kind : Scope.Domain.Kind) (name : OpaqueName) (result : ResultShape)
        (bases : Option Val) (pattern input : Val) (index : RangeIx)
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
  inductive Capture where
    | mk (values : List (Option Val))

  inductive Closure where
    | mk (capture : Capture) (code : Comp)
end

abbrev AtError := Detail Val

def AtError.save (p t : Val) (snapshot : Option PathEnv)
    (pp : Option RangeExpr) (pt : Option TargetInput) (f : AtFailure) : AtError where
  failure := f
  originalPattern := p
  originalTarget := t
  parsedPattern := pp
  parsedTarget := pt
  resolvedPatterns := pp.bind (resolveSnapshot snapshot)
  resolvedTarget := pt.bind (resolveTargetSnapshot snapshot)
  patternBase := pp.bind RangeExpr.base?
  targetBase := pt.bind TargetInput.base?

/-- 解析済みの検査の失敗へ、同じ準備が読んだ元入力を付ける。 -/
def AtError.fromCheck (p t : Val) (snapshot : Option PathEnv)
    (pat : RangeExpr) (target : TargetInput) (d : AtCheckError) : AtError :=
  AtError.save p t snapshot (some pat) (some target) d.failure


def Capture.values : Capture → List (Option Val)
  | .mk vs => vs

def Closure.capture : Closure → Capture
  | .mk cap _ => cap

def Closure.code : Closure → Comp
  | .mk _ m => m

def Capture.empty : Capture := .mk []

structure Def where
  tparams : List TParamDecl
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  body : Comp
  /-- 宣言した範囲パラメータの種類。 -/
  rkinds : List Scope.Domain.Kind := []

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
private def OpDecl.dictTys (d : OpDecl) : List Ty :=
  d.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- 利用者に見える値の引数。コアの前置辞書を除く。 -/
private def OpDecl.valueParams (d : OpDecl) : List Ty := d.params.drop d.dictParams.length

/-- 利用者に見える契約名。 -/
private def OpDecl.valueNames (d : OpDecl) : List String := d.names.drop d.dictParams.length

/-- 型クラスのメソッドの型 `∀γ̄ ρ̄. (Ā) → B ! ε`（01-12 の C-Meth）。型の中では、メソッドの型パラメータ γ̄ が
番号 `0..g-1`（g は γ̄ の個数）、型クラスの引数 P が番号 g である。メソッドが自分の型クラスの制約を持つときは、
Ā がその制約ごとの辞書の型を値の引数の前に含む。 -/
structure MethSig where
  tparams : List TParamDecl
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff

/-- 型クラスの宣言。上位の型クラスの並びと、メソッドの型。 -/
structure ClassDecl where
  argumentKind : TyKind := .value
  supers : List ClassName
  methods : MethName → Option MethSig

/-- 旧の各注釈は外側で読まれるため、格納位置の先行引数数だけ移す。 -/
def embedParameters (ps : List Benitoite.Release.Ty) : List Ty :=
  ps.zipIdx.map (fun (a, i) => (embedTy a).shiftV i 0)

/-- 旧のメソッド宣言の型・行と制約を保ち、追加のkindはvalueへ写す。 -/
def embedMethSig (d : Benitoite.Release.MethSig) : MethSig :=
  ⟨d.tparams.map embedTParam, d.neffs, d.names, embedParameters d.params, (embedTy d.ret).shiftV d.params.length 0, (embedEff d.eff).shiftV d.params.length 0⟩

def embedClassDecl (d : Benitoite.Release.ClassDecl) : ClassDecl :=
  { argumentKind := .value, supers := d.supers, methods := fun m => (d.methods m).map embedMethSig }

@[simp] theorem embedMethSig_constraints (d : Benitoite.Release.MethSig) :
    (embedMethSig d).tparams.map TParamDecl.constraints = d.tparams := by
  simp [embedMethSig, List.map_map, Function.comp_def]

@[simp] theorem embedClassDecl_argumentKind (d : Benitoite.Release.ClassDecl) :
    (embedClassDecl d).argumentKind = .value := rfl

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
  externals : List (ExternalKey × ExternalDecl) := []
  dataInfo : DataName → Option DataVarianceDecl := fun _ => none

/-- arity の不一致や metadata のない旧宣言には不変の列を使う。 -/
def Program.varianceFor (P : Program) (d : DataName) (n : Nat) : List Variance :=
  match P.dataInfo d with
  | some info => if info.arity = n ∧ info.variances.length = n then info.variances
      else List.replicate n .invariant
  | none => List.replicate n .invariant

@[simp] theorem Program.varianceFor_length (P : Program) (d : DataName) (n : Nat) :
    (P.varianceFor d n).length = n := by
  simp only [Program.varianceFor]
  split
  · split
    · rename_i h; exact h.2
    · exact List.length_replicate
  · exact List.length_replicate


def Program.externalType (P : Program) (id : ExternalId) : Option ExternalTypeDecl :=
  match P.externals.lookup (.type id) with
  | some (.type d) => some d
  | _ => none

def Program.externalFunction (P : Program) (id : ExternalFunctionId) : Option ExternalSignature :=
  match P.externals.lookup (.function id) with
  | some (.function _ d) => some d
  | _ => none


inductive Outcome where
  | val (v : Val)
  | err (r : ErrKind)
  | exit (n : Int)

inductive PrimKind where
  | pure | io | exit | refNew | refGet | refSet | refUpdate | force | pathBases
  deriving DecidableEq

def embedPrimKind : Benitoite.Release.PrimKind → PrimKind
  | .pure => .pure | .io => .io | .exit => .exit | .refNew => .refNew
  | .refGet => .refGet | .refSet => .refSet | .refUpdate => .refUpdate | .force => .force

def processEnvironmentEff : EffName := "Process.Environment"

structure PrimSig where
  tparams : List TParamDecl
  neffs : Nat
  names : List String
  params : List Ty
  ret : Ty
  eff : Eff
  /-- 型パラメータの制約（組み込みの制約と演算子の型の集まり）。制約の並び `C` のもとで判定する。 -/
  admits : List TParam → List Ty → Prop
  kind : PrimKind
  /-- 組み込みのエフェクトの操作のとき、そのエフェクトの名前。 -/
  opEff : Option EffName
  /-- 署名の範囲の変数ごとの対象の種類。範囲の変数 `Ix.rvar i` の i 番目の種類である。
  既定は空の列（範囲の変数のない旧の項目）。既定の空の列のまま `rvar` を書いた項目は、`PrimSig.Scoped` の
  番号の上限で拒否される（範囲を書かないと黙って Top になる既定引数とは別である）。 -/
  rkinds : List Scope.Domain.Kind := []
  /-- IO を行う項目の形（`Scope.Signature.IOShape`）。対象なし（`untargeted`）、旧 Top の対象あり
  （`topTargeted k`）、単一の対象（`single k p`。引数の位置 p が種類 k の範囲付きの値型）のどれかである。
  `Builtins.Assumptions` の `io_op`（形の検査 `Builtins.ShapeOk`）が効果・範囲の変数・引数と照らし合わせ、
  `io_target`（`TargetAgreement`）が観測の条件に使う。IO を行わない項目は読まない。既定は対象なし。 -/
  shape : Scope.Signature.IOShape := .untargeted

structure Builtins where
  sig : PrimName → Option PrimSig
  /-- IO を行わない組み込みの関数の値 δ(b[T̄; Ē], W̄)（01-12「実行の規則」）。 -/
  delta : PrimName → List Ty → List Eff → List RangeExpr → List Val → Option Outcome
  /-- IO を行う組み込みの関数の応答と、その応答で作用した対象の観測（有限列）として起こりうるもの
  （設計書 01-12「実行の規則」。観測は応答の関係に含める）。 -/
  ioResponse : PrimName → List Ty → List Eff → List Val → Outcome → List Scope.Domain.Target → Prop
  /-- 事象 `release(V)` の応答として起こりうるもの。`none` が `ok`、`some r` が `error(r)`。 -/
  releaseResponse : Val → Option ErrKind → Prop
  /-- リソースの型か。リソースの型の解放のエフェクト `rel(O_r)` は `{State}` である。 -/
  isResource : OpaqueName → Bool
  /-- 組み込みのエフェクトと、その操作。`State` は操作を持たない。 -/
  effects : EffName → Option (List PrimName)
  /-- 型が組み込みの制約を満たすか（01-06「等値の型」「鍵の型（初回リリース版）」）。制約の並び `C` のもとで判定する。 -/
  sat : List TParam → Ty → TParam → Prop
  /-- `Reference.get` と `Reference.set` の名前。`Reference.update` の遷移が使う。 -/
  refGet : PrimName
  refSet : PrimName
  /-- エフェクトの名前の対象の種類（`File.Read`・`File.Write` は path、`Http.Connect` は endpoint）。対象を持たない
  名前は `none` である。表のデータであり、正しさは信頼の対象である（設計書 07-04「形式化で仮定するもの」）。
  `Builtins.Assumptions` の欄にはしない。既定は全て `none`。 -/
  effKind : EffName → Option Scope.Domain.Kind := fun _ => none
  /-- 範囲付きの値型の名前の対象の種類（`Scope.PathIn` は path、`Http.RequestIn` は endpoint）。既存の不透明型と
  資源の型は `none` である。表のデータであり、正しさは信頼の対象である。既定は全て `none`。 -/
  valKind : OpaqueName → Option Scope.Domain.Kind := fun _ => none
  /-- 組み込みの関数ごとの範囲の具体化の制約（明示拡大の被覆など。型引数の `admits` に当たる）。全て Top の列は
  この制約によらず許す（`Builtins.RangeAdmissible`）。表のデータであり、正しさは信頼の対象である。既定は何も
  許さない（Top の列だけを許す）。 -/
  admitsR : PrimName → List RangeExpr → Prop := fun _ _ => False
  /-- 範囲付きの値型の名前の値が保持する要求の型（`Http.RequestIn` は `Http.ClientRequest` のレコードの型）。検査済みの
  要求の値の規則 V-CheckedRequest が読む。表のデータであり、正しさは信頼の対象である。既定は全て `none`。 -/
  valContent : OpaqueName → Option Ty := fun _ => none
  externalResponse : ExternalFunctionId → List Ty → List Val → Outcome → List Scope.Domain.Target → Prop :=
    fun _ _ _ _ _ => False

/-- 宣言は既に先行する値の引数の下で格納されている。 -/
def signatureTel : List String → List Ty → Ty → Eff → Tel
  | n :: ns, a :: ps, r, e => .param n a (signatureTel ns ps r e)
  | _, _, r, e => .done r e

def Def.tel (d : Def) : Tel := signatureTel d.names d.params d.ret d.eff
def PrimSig.tel (s : PrimSig) : Tel := signatureTel s.names s.params s.ret s.eff
def OpDecl.tel (d : OpDecl) : Tel := signatureTel d.names d.params d.ret
  (.mk (fun a => match a with | .name n (.fixed .top) => decide (n = d.eff) | _ => false) [])
def MethSig.tel (s : MethSig) : Tel := signatureTel s.names s.params s.ret s.eff

inductive LocTy where
  | builder (kind : BuilderKind)
  | ref (a : Ty)
  | lazy (a : Ty)
  | cont (b t : Ty) (ε : Eff) (r : Option Ty)

/-- ストアの型付け Ψ。 -/
abbrev StoreTy := Nat → Option LocTy


abbrev LocalCtx := List (Option BuilderKind)

/-- V_Const の適格性。Integer64 は証拠付きの値、他の六整数幅・Byte・Decimal は
この述語で表現可能性を検査する。V_Bytes の全要素の上限は別の前提である。
裸 opaque は valKind と valContent がともに none の名前に限る。Top でもこの条件を外さず、
対象を保持する値と要求は V_Checked/V_CheckedRequest で型付けする。
旧 Release の数値・Top の抽象化からの規則の変更であり、旧主定理の欠陥の修正ではない
（設計書 01-12「篩を含むコア計算の形式化」、07-04「篩を含む形式化の範囲」）。 -/
def ConstOK (B : Builtins) : Const → Prop
  | .integer _ => True
  | .integer8 n => -128 ≤ n ∧ n ≤ 127
  | .integer16 n => -32768 ≤ n ∧ n ≤ 32767
  | .integer32 n => -2147483648 ≤ n ∧ n ≤ 2147483647
  | .unsignedInteger16 n => 0 ≤ n ∧ n ≤ 65535
  | .unsignedInteger32 n => 0 ≤ n ∧ n ≤ 4294967295
  | .unsignedInteger64 n => 0 ≤ n ∧ n ≤ 18446744073709551615
  | .byte n => n ≤ 255
  | .decimal n scale => -79228162514264337593543950335 ≤ n ∧
      n ≤ 79228162514264337593543950335 ∧ scale ≤ 28
  | .opaque o _ => B.valKind o = none ∧ B.valContent o = none
  | _ => True

mutual
  /-- 公開の値の木の値。Option だけが型引数を持つ。 -/
  def ScopePublic.PublicTree.toVal : ScopePublic.PublicTree → Val
    | .text s => .const (.string s)
    | .integer n => .const (.integer n)
    | .bytes bs => .bytesV bs
    | .list _ xs => .list (ScopePublic.PublicTree.toVals xs)
    | .none a => .con "Option.None" [a.ty] []
    | .some a x => .con "Option.Some" [a.ty] [x.toVal]
    | .con c xs => .con c [] (ScopePublic.PublicTree.toVals xs)
  def ScopePublic.PublicTree.toVals : List ScopePublic.PublicTree → List Val
    | [] => []
    | x :: xs => x.toVal :: ScopePublic.PublicTree.toVals xs
end

/-- 元の入力の値の公開形。文字列は Text、解析済みの pattern は Pattern であり、ほかの値は公開形を持たない。 -/
def ScopePublic.inputOfVal : Val → Option ScopePublic.PublicTree
  | .const (.string s) => some (ScopePublic.inputText s)
  | .scopePattern r => some (ScopePublic.inputPattern r)
  | _ => none

/-- 保存した九欄の公開形（`Scope.AtDetail` の値）。公開形を持たない診断は固定の値で観測する。 -/
def Detail.publicTree (d : AtError) : ScopePublic.PublicTree :=
  (ScopePublic.detailTree? ScopePublic.inputOfVal d).getD ScopePublic.unreachableTree

/-- `Scope.ScopeError.At` の欄の値。九欄の公開形の一つの値である。 -/
def Detail.values (d : AtError) : List Val := [d.publicTree.toVal]

mutual
  /-- 観測できる部分だけを有限のsnapshotに写す。スロットの欠落を保つ。 -/
  def Val.toTerm? : Val → Option Term
    | .var i => some (.var i)
    | .const (.integer n) => some (.integer n.toInt)
    | .const (.integer8 n) | .const (.integer16 n) | .const (.integer32 n)
    | .const (.unsignedInteger16 n) | .const (.unsignedInteger32 n)
    | .const (.unsignedInteger64 n) => some (.integer n)
    | .const (.byte n) => some (.integer (Int.ofNat n))
    | .const (.float64 bits) => some (.float64 bits)
    | .const (.float32 bits) => some (.float32 bits)
    | .const (.character c) => some (.character c)
    | .const (.string s) => some (.string s)
    | .const (.boolean b) => some (.boolean b)
    | .const .unit => some .unitValue
    | .const (.decimal c scale) => some (.decimal c scale)
    | .con c _ vs => some (.dataValue c (Val.toTermSlots vs))
    | .list vs => some (.listValue (Val.toTermSlots vs))
    | .mapV ks vs => some (.mapValue (Val.toTermSlots ks) (Val.toTermSlots vs))
    | .setV vs => some (.setValue (Val.toTermSlots vs))
    | .bytesV bs => some (.bytesValue bs)
    | .checked t | .checkedRequest t _ => some (.targetValue none t)
    | .checkedAt _ snapshot t _ => some (.targetValue snapshot t)
    | .atError d => some (.dataValue "Scope.ScopeError.At" [some d.publicTree.toTerm])
    | _ => none
  def Val.toTermSlots : List Val → List (Option Term)
    | [] => []
    | v :: vs => v.toTerm? :: Val.toTermSlots vs
end

@[simp] theorem Val.toTermSlots_eq_map (vs : List Val) :
    Val.toTermSlots vs = vs.map Val.toTerm? := by
  induction vs <;> simp_all [Val.toTermSlots]

mutual
  theorem ScopePublic.PublicTree.toVal_toTerm :
      ∀ t : ScopePublic.PublicTree, t.toVal.toTerm? = Option.some t.toTerm
    | .text _ | .integer _ | .bytes _ | .none _ => rfl
    | .list _ xs => by
      simp only [ScopePublic.PublicTree.toVal, Val.toTerm?, ScopePublic.PublicTree.toTerm,
        ScopePublic.PublicTree.toVals_toTermSlots]
    | .some _ x => by
      simp only [ScopePublic.PublicTree.toVal, Val.toTerm?, Val.toTermSlots, ScopePublic.PublicTree.toTerm,
        ScopePublic.PublicTree.toVal_toTerm x]
    | .con _ xs => by
      simp only [ScopePublic.PublicTree.toVal, Val.toTerm?, ScopePublic.PublicTree.toTerm,
        ScopePublic.PublicTree.toVals_toTermSlots]
  theorem ScopePublic.PublicTree.toVals_toTermSlots :
      ∀ xs : List ScopePublic.PublicTree,
        Val.toTermSlots (ScopePublic.PublicTree.toVals xs) = ScopePublic.PublicTree.toTermSlots xs
    | [] => rfl
    | x :: xs => by
      simp only [ScopePublic.PublicTree.toVals, Val.toTermSlots, ScopePublic.PublicTree.toTermSlots,
        ScopePublic.PublicTree.toVal_toTerm x, ScopePublic.PublicTree.toVals_toTermSlots xs]
end

/-- At の診断の観測は、照合が束縛する欄の値の観測と同じである。 -/
theorem Detail.values_toTerm (d : AtError) :
    (Val.atError d).toTerm? = Option.some (.dataValue "Scope.ScopeError.At" (Val.toTermSlots d.values)) := by
  simp only [Val.toTerm?, Detail.values, Val.toTermSlots, ScopePublic.PublicTree.toVal_toTerm]

end Benitoite.Release.Refinement
```

## RangeCode.lean（全定義と補助）

```lean
import Benitoite.Release.Refinement.RangeSubst
import Benitoite.Release.Refinement.Subst
import Benitoite.Release.Refinement.Telescope

/-! # 項の範囲変数の置換 -/
namespace Benitoite.Release.Refinement

noncomputable def BuilderKind.mapRanges (ρ : Nat → RangeIx) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (a.rawMapRanges ρ)

mutual
  noncomputable def Val.mapRanges (ρ : Nat → RangeIx) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (Ty.rawMapRanges ρ)) (effs.map (Eff.rawMapRanges ρ)) (rs.map (mapIx ρ))
    | .prim b tys effs rs => .prim b (tys.map (Ty.rawMapRanges ρ)) (effs.map (Eff.rawMapRanges ρ)) (rs.map (mapIx ρ))
    | .lam names params body => .lam names (params.map (Ty.rawMapRanges ρ)) (Comp.mapRanges ρ body)
    | .dependentLam t body => .dependentLam (Tel.rawMapRanges ρ t) (Comp.mapRanges ρ body)
    | .closure t body => .closure t body
    | .con c tys args => .con c (tys.map (Ty.rawMapRanges ρ)) (Val.mapRangesList ρ args)
    | .list elems => .list (Val.mapRangesList ρ elems)
    | .op o tys => .op o (tys.map (Ty.rawMapRanges ρ))
    | .raise t e => .raise (Ty.rawMapRanges ρ t) (Ty.rawMapRanges ρ e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.mapRangesList ρ ks) (Val.mapRangesList ρ vs)
    | .setV elems => .setV (Val.mapRangesList ρ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (Ty.rawMapRanges ρ)) (Val.mapRangesList ρ args)
    | .super v cl => .super (Val.mapRanges ρ v) cl
    | .externalRef f tys => .externalRef f (tys.map (Ty.rawMapRanges ρ))
    | .externalHandle h tys => .externalHandle h (tys.map (Ty.rawMapRanges ρ))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  noncomputable def Val.mapRangesList (ρ : Nat → RangeIx) : List Val → List Val
    | [] => []
    | v :: vs => Val.mapRanges ρ v :: Val.mapRangesList ρ vs

  noncomputable def Comp.mapRanges (ρ : Nat → RangeIx) : Comp → Comp
    | .builderLet k body => .builderLet (BuilderKind.mapRanges ρ k) (Comp.mapRanges ρ body)
    | .builderOp k op r args => .builderOp (BuilderKind.mapRanges ρ k) op r (Val.mapRangesList ρ args)
    | .ret v => .ret (Val.mapRanges ρ v)
    | .letIn m n => .letIn (Comp.mapRanges ρ m) (Comp.mapRanges ρ n)
    | .app f args => .app (Val.mapRanges ρ f) (Val.mapRangesList ρ args)
    | .ite v m n => .ite (Val.mapRanges ρ v) (Comp.mapRanges ρ m) (Comp.mapRanges ρ n)
    | .match v arms => .match (Val.mapRanges ρ v) (Arm.mapRangesList ρ arms)
    | .lazyC m => .lazyC (Comp.mapRanges ρ m)
    | .escape v => .escape (Val.mapRanges ρ v)
    | .use v m => .use (Val.mapRanges ρ v) (Comp.mapRanges ρ m)
    | .handle m h => .handle (Comp.mapRanges ρ m) (Clause.mapRangesList ρ h)
    | .resume k v => .resume (Val.mapRanges ρ k) (Val.mapRanges ρ v)
    | .externalCall f tys args => .externalCall f (tys.map (Ty.rawMapRanges ρ)) (Val.mapRangesList ρ args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := Ty.rawMapRanges ρ sh.errorType}
        (match bs with | none => none | some b => some (b.mapRanges ρ)) (p.mapRanges ρ) (v.mapRanges ρ) (mapIx ρ ix)
    | .meth d m tys effs args => .meth (Val.mapRanges ρ d) m (tys.map (Ty.rawMapRanges ρ)) (effs.map (Eff.rawMapRanges ρ)) (Val.mapRangesList ρ args)

  noncomputable def Arm.mapRangesList (ρ : Nat → RangeIx) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.mapRanges ρ m) :: Arm.mapRangesList ρ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.mapRanges ρ g))
          (Comp.mapRanges ρ m) :: Arm.mapRangesList ρ arms

  noncomputable def Clause.mapRangesList (ρ : Nat → RangeIx) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.mapRanges ρ m) :: Clause.mapRangesList ρ cs
    | .fail e m :: cs => .fail (Ty.rawMapRanges ρ e) (Comp.mapRanges ρ m) :: Clause.mapRangesList ρ cs
end
noncomputable def BuilderKind.mapRangesN (ρ : Nat → RangeIx) : BuilderKind → BuilderKind
  | .string => .string
  | .bytes => .bytes
  | .list a => .list (a.mapRanges ρ)

mutual
  noncomputable def Val.mapRangesN (ρ : Nat → RangeIx) : Val → Val
    | .var i => .var i
    | .const c => .const c
    | .fnRef f tys effs rs => .fnRef f (tys.map (Ty.mapRanges ρ)) (effs.map (Eff.mapRanges ρ)) (rs.map (mapIx ρ))
    | .prim b tys effs rs => .prim b (tys.map (Ty.mapRanges ρ)) (effs.map (Eff.mapRanges ρ)) (rs.map (mapIx ρ))
    | .lam names params body => .lam names (params.map (Ty.mapRanges ρ)) (Comp.mapRangesN ρ body)
    | .dependentLam t body => .dependentLam (Tel.mapRanges ρ t) (Comp.mapRangesN ρ body)
    | .closure t body => .closure t body
    | .con c tys args => .con c (tys.map (Ty.mapRanges ρ)) (Val.mapRangesListN ρ args)
    | .list elems => .list (Val.mapRangesListN ρ elems)
    | .op o tys => .op o (tys.map (Ty.mapRanges ρ))
    | .raise t e => .raise (Ty.mapRanges ρ t) (Ty.mapRanges ρ e)
    | .loc l => .loc l
    | .mapV ks vs => .mapV (Val.mapRangesListN ρ ks) (Val.mapRangesListN ρ vs)
    | .setV elems => .setV (Val.mapRangesListN ρ elems)
    | .bytesV bs => .bytesV bs
    | .dict i tys args => .dict i (tys.map (Ty.mapRanges ρ)) (Val.mapRangesListN ρ args)
    | .super v cl => .super (Val.mapRangesN ρ v) cl
    | .externalRef f tys => .externalRef f (tys.map (Ty.mapRanges ρ))
    | .externalHandle h tys => .externalHandle h (tys.map (Ty.mapRanges ρ))
    | .pathBases σ => .pathBases σ
    | .scopePattern r => .scopePattern r
    | .checkedAt r σ t req => .checkedAt r σ t req
    | .atError d => .atError d
    | .checked t => .checked t
    | .checkedRequest t c => .checkedRequest t c

  noncomputable def Val.mapRangesListN (ρ : Nat → RangeIx) : List Val → List Val
    | [] => []
    | v :: vs => Val.mapRangesN ρ v :: Val.mapRangesListN ρ vs

  noncomputable def Comp.mapRangesN (ρ : Nat → RangeIx) : Comp → Comp
    | .builderLet k body => .builderLet (BuilderKind.mapRangesN ρ k) (Comp.mapRangesN ρ body)
    | .builderOp k op r args => .builderOp (BuilderKind.mapRangesN ρ k) op r (Val.mapRangesListN ρ args)
    | .ret v => .ret (Val.mapRangesN ρ v)
    | .letIn m n => .letIn (Comp.mapRangesN ρ m) (Comp.mapRangesN ρ n)
    | .app f args => .app (Val.mapRangesN ρ f) (Val.mapRangesListN ρ args)
    | .ite v m n => .ite (Val.mapRangesN ρ v) (Comp.mapRangesN ρ m) (Comp.mapRangesN ρ n)
    | .match v arms => .match (Val.mapRangesN ρ v) (Arm.mapRangesListN ρ arms)
    | .lazyC m => .lazyC (Comp.mapRangesN ρ m)
    | .escape v => .escape (Val.mapRangesN ρ v)
    | .use v m => .use (Val.mapRangesN ρ v) (Comp.mapRangesN ρ m)
    | .handle m h => .handle (Comp.mapRangesN ρ m) (Clause.mapRangesListN ρ h)
    | .resume k v => .resume (Val.mapRangesN ρ k) (Val.mapRangesN ρ v)
    | .externalCall f tys args => .externalCall f (tys.map (Ty.mapRanges ρ)) (Val.mapRangesListN ρ args)
    | .issuePathBases b => .issuePathBases b
    | .checkAt k o sh bs p v ix => .checkAt k o {sh with errorType := Ty.mapRanges ρ sh.errorType}
        (match bs with | none => none | some b => some (b.mapRangesN ρ)) (p.mapRangesN ρ) (v.mapRangesN ρ) (mapIx ρ ix)
    | .meth d m tys effs args => .meth (Val.mapRangesN ρ d) m (tys.map (Ty.mapRanges ρ)) (effs.map (Eff.mapRanges ρ)) (Val.mapRangesListN ρ args)

  noncomputable def Arm.mapRangesListN (ρ : Nat → RangeIx) : List Arm → List Arm
    | [] => []
    | .mk alts none m :: arms =>
        .mk alts none (Comp.mapRangesN ρ m) :: Arm.mapRangesListN ρ arms
    | .mk alts (some g) m :: arms =>
        .mk alts (some (Comp.mapRangesN ρ g))
          (Comp.mapRangesN ρ m) :: Arm.mapRangesListN ρ arms

  noncomputable def Clause.mapRangesListN (ρ : Nat → RangeIx) : List Clause → List Clause
    | [] => []
    | .mk o n k m :: cs => .mk o n k (Comp.mapRangesN ρ m) :: Clause.mapRangesListN ρ cs
    | .fail e m :: cs => .fail (Ty.mapRanges ρ e) (Comp.mapRangesN ρ m) :: Clause.mapRangesListN ρ cs
end
noncomputable def Capture.mapRanges (ρ : Nat → RangeIx) : Capture → Capture
  | .mk vs => .mk (vs.map (Option.map (Val.mapRanges ρ)))

noncomputable def Closure.mapRanges (ρ : Nat → RangeIx) : Closure → Closure
  | .mk cap m => .mk (cap.mapRanges ρ) (m.mapRanges ρ)

noncomputable def Val.substR (c : Nat) (rs : List RangeExpr) (v : Val) : Val :=
  match rs with | [] => v | _ => v.mapRangesN (rangeAt c rs)
noncomputable def Comp.substR (c : Nat) (rs : List RangeExpr) (m : Comp) : Comp :=
  match rs with | [] => m | _ => m.mapRangesN (rangeAt c rs)
noncomputable def Val.instR (rs : List RangeExpr) (v : Val) : Val := v.substR 0 rs
noncomputable def Comp.instR (rs : List RangeExpr) (m : Comp) : Comp := m.substR 0 rs

/-- 種類の列に適合する、閉じた範囲の具体化。 -/
def RangesFit (rs : List RangeExpr) (ks : List Scope.Domain.Kind) : Prop :=
  rs.length = ks.length ∧
  (∀ (i : Nat) (r : RangeExpr) (k : Scope.Domain.Kind),
    rs[i]? = some r → ks[i]? = some k → r.FitsKind k) ∧
  (∀ r ∈ rs, r.WF ∧ r.Canonical)

/-- 利用者の関数では、種類に適合するすべての具体化を許す。 -/
def Def.RangeAdmissible (d : Def) (rs : List RangeExpr) : Prop := RangesFit rs d.rkinds

/-- 空の具体化は元の引数列を保ち、非空の具体化では範囲の置換と正規化を行う。 -/
noncomputable def Def.instTel (d : Def) (rs : List RangeExpr) : Tel :=
  match rs with | [] => d.tel | _ => Tel.instR rs d.tel

@[simp] theorem mapIx_id (r : RangeIx) : mapIx RangeIx.rvar r = r := by cases r <;> rfl
@[simp] theorem mapAtomRanges_id (a : Atom) : mapAtomRanges RangeIx.rvar a = a := by
  cases a <;> simp [mapAtomRanges]
@[simp] theorem mapRangeAtoms_id (a : Atom → Bool) : mapRangeAtoms RangeIx.rvar a = a := by
  classical
  funext x
  simp [mapRangeAtoms]

mutual
  @[simp] theorem Ty.rawMapRanges_id (a : Ty) : a.rawMapRanges RangeIx.rvar = a := by
    cases a <;> simp only [Ty.rawMapRanges, mapIx_id, mapRangesTys_id,
      Ty.rawMapRanges_id, Tel.rawMapRanges_id, Eff.rawMapRanges_id]
  @[simp] theorem Tel.rawMapRanges_id (t : Tel) : Tel.rawMapRanges RangeIx.rvar t = t := by
    cases t <;> simp only [Tel.rawMapRanges, Ty.rawMapRanges_id, Eff.rawMapRanges_id,
      Tel.rawMapRanges_id]
  @[simp] theorem mapRangesTys_id (as : List Ty) : mapRangesTys RangeIx.rvar as = as := by
    cases as <;> simp only [mapRangesTys, Ty.rawMapRanges_id, mapRangesTys_id]
  @[simp] theorem Eff.rawMapRanges_id (e : Eff) : Eff.rawMapRanges RangeIx.rvar e = e := by
    cases e; simp only [Eff.rawMapRanges, mapRangeAtoms_id, mapRangesTys_id]
end

@[simp] theorem Ty.rawMapRanges_id_fun : Ty.rawMapRanges RangeIx.rvar = id := funext Ty.rawMapRanges_id
@[simp] theorem Eff.rawMapRanges_id_fun : Eff.rawMapRanges RangeIx.rvar = id := funext Eff.rawMapRanges_id
@[simp] theorem mapIx_id_fun : mapIx RangeIx.rvar = id := funext mapIx_id

@[simp] theorem rangeAt_nil (c : Nat) : rangeAt c [] = RangeIx.rvar := by
  funext i
  simp [rangeAt]

@[simp] theorem BuilderKind.mapRanges_id (k : BuilderKind) : k.mapRanges RangeIx.rvar = k := by
  cases k <;> simp [BuilderKind.mapRanges]

mutual
  @[simp] theorem Val.mapRanges_id (v : Val) : v.mapRanges RangeIx.rvar = v := by
    cases v <;> simp [Val.mapRanges, Val.mapRangesList_id, Comp.mapRanges_id, Val.mapRanges_id]
  termination_by structural v
  @[simp] theorem Val.mapRangesList_id (vs : List Val) : Val.mapRangesList RangeIx.rvar vs = vs := by
    cases vs <;> simp [Val.mapRangesList, Val.mapRanges_id, Val.mapRangesList_id]
  termination_by structural vs
  @[simp] theorem Comp.mapRanges_id (m : Comp) : m.mapRanges RangeIx.rvar = m := by
    cases m with
    | checkAt k o sh bs p v ix =>
      cases bs <;> simp only [Comp.mapRanges, Ty.rawMapRanges_id, Val.mapRanges_id, mapIx_id]
    | _ => simp [Comp.mapRanges, Val.mapRanges_id, Val.mapRangesList_id,
        Comp.mapRanges_id, Arm.mapRangesList_id, Clause.mapRangesList_id]
  termination_by structural m
  @[simp] theorem Arm.mapRangesList_id (as : List Arm) : Arm.mapRangesList RangeIx.rvar as = as := by
    cases as with
    | nil => rfl
    | cons a as => cases a with
      | mk alts guard body => cases guard <;>
          simp [Arm.mapRangesList, Comp.mapRanges_id, Arm.mapRangesList_id]
  termination_by structural as
  @[simp] theorem Clause.mapRangesList_id (cs : List Clause) : Clause.mapRangesList RangeIx.rvar cs = cs := by
    cases cs with
    | nil => rfl
    | cons c cs => cases c <;>
        simp [Clause.mapRangesList, Comp.mapRanges_id, Clause.mapRangesList_id]
  termination_by structural cs
end

@[simp] theorem Val.instR_nil (v : Val) : v.instR [] = v := by simp [Val.instR, Val.substR]
@[simp] theorem Comp.instR_nil (m : Comp) : m.instR [] = m := by simp [Comp.instR, Comp.substR]
@[simp] theorem Def.instTel_nil (d : Def) : d.instTel [] = d.tel := by simp [Def.instTel]

/-- 実行時に、すべての範囲引数が固定範囲であることを検査する。 -/
def closedRanges : List RangeIx → Option (List RangeExpr)
  | [] => some []
  | .fixed r :: rs => (closedRanges rs).map (r :: ·)
  | .rvar _ :: _ => none

@[simp] theorem closedRanges_fixed (rs : List RangeExpr) :
    closedRanges (rs.map RangeIx.fixed) = some rs := by
  induction rs <;> simp_all [closedRanges]

theorem closedRanges_eq_some (rs : List RangeIx) (ρ : List RangeExpr) :
    closedRanges rs = some ρ ↔ rs = ρ.map RangeIx.fixed := by
  induction rs generalizing ρ with
  | nil => cases ρ <;> simp [closedRanges]
  | cons ix rs ih =>
    cases ix with
    | rvar i => cases ρ <;> simp [closedRanges]
    | fixed r =>
      cases ρ with
      | nil => simp [closedRanges]
      | cons s ρ =>
        simp only [closedRanges, Option.map_eq_some_iff, List.map_cons, List.cons.injEq,
          RangeIx.fixed.injEq]
        constructor
        · rintro ⟨xs,hxs,h⟩
          obtain ⟨rfl,rfl⟩ := h
          exact ⟨rfl,(ih _).mp hxs⟩
        · rintro ⟨rfl,h⟩
          exact ⟨ρ,(ih _).mpr h,rfl,rfl⟩

/-- 固定範囲列の値の読み出し。未具体化の項の実行には `closedRanges` の成功を別に要求する。 -/
def rangeValues (rs : List RangeIx) : List RangeExpr :=
  rs.map (fun ix => match ix with | .fixed r => r | .rvar _ => .top)

@[simp] theorem rangeValues_fixed (rs : List RangeExpr) :
    rangeValues (rs.map RangeIx.fixed) = rs := by simp [rangeValues, List.map_map, Function.comp_def]

theorem fixed_ranges_of_wf0 {rs : List RangeIx} (h : ∀ ix ∈ rs, ix.WF 0) :
    ∃ ρ : List RangeExpr, rs = ρ.map RangeIx.fixed := by
  induction rs with
  | nil => exact ⟨[],rfl⟩
  | cons ix rs ih =>
    obtain ⟨ρ,rfl⟩ := ih (fun ix hx => h ix (List.mem_cons_of_mem _ hx))
    cases ix with
    | fixed r => exact ⟨r :: ρ,rfl⟩
    | rvar i => have hi := h (.rvar i) (by simp); cases Nat.not_lt_zero i hi

noncomputable def Capture.instR (rs : List RangeExpr) (cap : Capture) : Capture :=
  match rs, cap with
  | [], _ => cap
  | _, .mk vs => .mk (vs.map (Option.map (Val.instR rs)))
noncomputable def Closure.instR (rs : List RangeExpr) (c : Closure) : Closure :=
  match rs, c with
  | [], _ => c
  | _, .mk cap m => .mk (cap.instR rs) (m.instR rs)
noncomputable def Arm.instRList (rs : List RangeExpr) (as : List Arm) : List Arm :=
  match rs with | [] => as | _ => Arm.mapRangesListN (rangeAt 0 rs) as
noncomputable def Clause.instRList (rs : List RangeExpr) (cs : List Clause) : List Clause :=
  match rs with | [] => cs | _ => Clause.mapRangesListN (rangeAt 0 rs) cs

theorem Tel.names_rawMapRanges (t : Tel) (ρ : Nat → RangeIx) :
    (Tel.rawMapRanges ρ t).names = t.names := by
  cases t with
  | done => rfl
  | param n a t => simpa only [Tel.rawMapRanges, Tel.names] using congrArg (n :: ·) (Tel.names_rawMapRanges t ρ)

@[simp] theorem Def.instTel_names (d : Def) (rs : List RangeExpr) :
    (d.instTel rs).names = d.tel.names := by
  cases rs with
  | nil => rfl
  | cons r rs => simp only [Def.instTel, Tel.instR, Tel.substRAt, Tel.mapRanges, Tel.names_norm, Tel.names_rawMapRanges]

/-- 各種類は Top による適格な具体化を持つ。 -/
theorem RangesFit.top (ks : List Scope.Domain.Kind) :
    RangesFit (ks.map (fun _ => RangeExpr.top)) ks := by
  refine ⟨by simp, ?_, ?_⟩
  · intro i r k hr hk
    obtain ⟨_,_,rfl⟩ := Option.map_eq_some_iff.mp (by simpa only [List.getElem?_map] using hr)
    exact Scope.Domain.Range.top_fitsKind k
  · intro r hr
    obtain ⟨_,_,rfl⟩ := List.mem_map.mp hr
    exact ⟨trivial,trivial⟩

end Benitoite.Release.Refinement
```

## RangeTyping.lean（全定義と補助）

```lean
import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.RangeTypeProperties

/-! # 範囲パラメータを持つ本体の具体化

範囲文脈の下の判断は、種類の合う閉じた範囲列のすべての具体化で検査する。
ストアは実行時の閉じた状態であり、この文脈の変数を含めない。
-/
namespace Benitoite.Release.Refinement
noncomputable section

def rangeTy (rs : List RangeExpr) (a : Ty) : Ty :=
  match rs with | [] => a | _ => a.instR rs
def rangeEff (rs : List RangeExpr) (e : Eff) : Eff :=
  match rs with | [] => e | _ => Eff.instR rs e
def rangeTel (rs : List RangeExpr) (t : Tel) : Tel :=
  match rs with | [] => t | _ => Tel.instR rs t
def rangeCtx (rs : List RangeExpr) (Γ : Ctx) : Ctx :=
  match rs with | [] => Γ | _ => Γ.mapRanges (rangeAt 0 rs)
def rangeLocal (rs : List RangeExpr) (L : LocalCtx) : LocalCtx :=
  match rs with | [] => L | _ => L.map (Option.map (BuilderKind.mapRangesN (rangeAt 0 rs)))

structure Ty.AnnotationR (P : Program) (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx) (a : Ty) : Prop where
  wf : a.WF ks.length C.length Γ.length
  sorted : a.Sorted Γ
  declared : a.Declared P C Γ

/-- 範囲文脈が空の注釈は、通常の注釈と同じ三条件を持つ。 -/
theorem Ty.Annotation.range_empty {P C Γ a} (h : Ty.Annotation P C Γ a) :
    Ty.AnnotationR P [] C Γ a := ⟨h.wf,h.sorted,h.declared⟩

@[simp] theorem Ty.annotationR_nil {P C Γ a} :
    Ty.AnnotationR P [] C Γ a ↔ Ty.Annotation P C Γ a :=
  ⟨fun h => ⟨h.wf,h.sorted,h.declared⟩, Ty.Annotation.range_empty⟩

def HasTypeVQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (v : Val) (a : Ty) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeVQ P B Ψ Q C (rangeCtx rs Γ) Φ (v.instR rs) (rangeTy rs a)

theorem HasTypeVQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (v : Val) (a : Ty) (h : HasTypeVQR P B ks Ψ Q C Γ Φ v a)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeVQ P B Ψ Q C (rangeCtx rs Γ) Φ (v.instR rs) (rangeTy rs a) := h rs hr

def HasTypeVsQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (as : List Ty) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeVsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (as.map (rangeTy rs))

theorem HasTypeVsQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (as : List Ty) (h : HasTypeVsQR P B ks Ψ Q C Γ Φ vs as)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeVsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (as.map (rangeTy rs)) := h rs hr

def HasTypeEachQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (a : Ty) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeEachQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTy rs a)

theorem HasTypeEachQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (a : Ty) (h : HasTypeEachQR P B ks Ψ Q C Γ Φ vs a)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeEachQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTy rs a) := h rs hr

def HasTypeCQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeCQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (m.instR rs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L)

theorem HasTypeCQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (m : Comp) (a : Ty) (e : Eff) (L : LocalCtx := []) (h : HasTypeCQR P B ks Ψ Q C Γ Φ R m a e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeCQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (m.instR rs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def HasTypeTelArgsQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (t : Tel) (a : Ty) (e : Eff) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeTelArgsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTel rs t) (rangeTy rs a) (rangeEff rs e)

theorem HasTypeTelArgsQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (vs : List Val) (t : Tel) (a : Ty) (e : Eff) (h : HasTypeTelArgsQR P B ks Ψ Q C Γ Φ vs t a e)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeTelArgsQ P B Ψ Q C (rangeCtx rs Γ) Φ (vs.map (Val.instR rs)) (rangeTel rs t) (rangeTy rs a) (rangeEff rs e) := h rs hr

def CaptureOkR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (R : Option Ty) (Γ : Ctx) (Φ : List Pred) (cap : Capture) : Prop :=
  ∀ rs, RangesFit rs ks → CaptureOk P B Ψ (R.map (rangeTy rs)) (rangeCtx rs Γ) Φ (cap.instR rs)

theorem CaptureOkR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (R : Option Ty) (Γ : Ctx) (Φ : List Pred) (cap : Capture) (h : CaptureOkR P B ks Ψ R Γ Φ cap)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    CaptureOk P B Ψ (R.map (rangeTy rs)) (rangeCtx rs Γ) Φ (cap.instR rs) := h rs hr

def DependentClosureTyR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (c : Closure) (t : Tel) : Prop :=
  ∀ rs, RangesFit rs ks → DependentClosureTy P B Ψ (c.instR rs) (rangeTel rs t)

theorem DependentClosureTyR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (c : Closure) (t : Tel) (h : DependentClosureTyR P B ks Ψ c t)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    DependentClosureTy P B Ψ (c.instR rs) (rangeTel rs t) := h rs hr

def CheckedWitnessR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (o : OpaqueName) (k : Scope.Domain.Kind) (r : RangeExpr) (snap : Option PathEnv) (target : Scope.Domain.Target) (req : Option Val) : Prop :=
  ∀ rs, RangesFit rs ks → CheckedWitness P B Ψ o k r snap target (req.map (Val.instR rs))

theorem CheckedWitnessR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (o : OpaqueName) (k : Scope.Domain.Kind) (r : RangeExpr) (snap : Option PathEnv) (target : Scope.Domain.Target) (req : Option Val) (h : CheckedWitnessR P B ks Ψ o k r snap target req)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    CheckedWitness P B Ψ o k r snap target (req.map (Val.instR rs)) := h rs hr

def AtCallAdmissibleR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (k : Scope.Domain.Kind) (o : OpaqueName) (sh : ResultShape) (bs : Option Val) (pat input : Val) (ix : RangeIx) : Prop :=
  ∀ rs, RangesFit rs ks → AtCallAdmissible P B Ψ Q C (rangeCtx rs Γ) Φ k o {sh with errorType := rangeTy rs sh.errorType} (bs.map (Val.instR rs)) (pat.instR rs) (input.instR rs) (ix.inst rs)

theorem AtCallAdmissibleR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (k : Scope.Domain.Kind) (o : OpaqueName) (sh : ResultShape) (bs : Option Val) (pat input : Val) (ix : RangeIx) (h : AtCallAdmissibleR P B ks Ψ Q C Γ Φ k o sh bs pat input ix)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    AtCallAdmissible P B Ψ Q C (rangeCtx rs Γ) Φ k o {sh with errorType := rangeTy rs sh.errorType} (bs.map (Val.instR rs)) (pat.instR rs) (input.instR rs) (ix.inst rs) := h rs hr

def HasTypeArmsQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (obs : Option Term) (arms : List Arm) (a b : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeArmsQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) obs (Arm.instRList rs arms) (rangeTy rs a) (rangeTy rs b) (rangeEff rs e) (rangeLocal rs L)

theorem HasTypeArmsQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (obs : Option Term) (arms : List Arm) (a b : Ty) (e : Eff) (L : LocalCtx := []) (h : HasTypeArmsQR P B ks Ψ Q C Γ Φ R obs arms a b e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeArmsQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) obs (Arm.instRList rs arms) (rangeTy rs a) (rangeTy rs b) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def HasTypeClausesQR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (eb : Eff) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasTypeClausesQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (rangeEff rs eb) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L)

theorem HasTypeClausesQR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (eb : Eff) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) (h : HasTypeClausesQR P B ks Ψ Q C Γ Φ R eb cs a e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasTypeClausesQ P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (rangeEff rs eb) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def HasFailureClauseR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (E : Ty) (R : Option Ty) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) : Prop :=
  ∀ rs, RangesFit rs ks → HasFailureClause P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTy rs E) (R.map (rangeTy rs)) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L)

theorem HasFailureClauseR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (E : Ty) (R : Option Ty) (cs : List Clause) (a : Ty) (e : Eff) (L : LocalCtx := []) (h : HasFailureClauseR P B ks Ψ Q C Γ Φ E R cs a e L)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    HasFailureClause P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTy rs E) (R.map (rangeTy rs)) (Clause.instRList rs cs) (rangeTy rs a) (rangeEff rs e) (rangeLocal rs L) := h rs hr

def ImageOkR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (ν : Nat → Val) (i : Nat) (a : Ty) : Prop :=
  ∀ rs, RangesFit rs ks → ImageOk P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (fun i => (ν i).instR rs) i (rangeTy rs a)

theorem ImageOkR.instR (P : Program) (B : Builtins) (ks : List Scope.Domain.Kind) (Ψ : StoreTy) (Q : NoFailCtx) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (R : Option Ty) (ν : Nat → Val) (i : Nat) (a : Ty) (h : ImageOkR P B ks Ψ Q C Γ Φ R ν i a)
    (rs : List RangeExpr) (hr : RangesFit rs ks) :
    ImageOk P B Ψ Q C (rangeCtx rs Γ) Φ (R.map (rangeTy rs)) (fun i => (ν i).instR rs) i (rangeTy rs a) := h rs hr

/-- 範囲パラメータがなければ既存の本体の判断をそのまま読む。 -/
def TelBodyTyR (P : Program) (B : Builtins) (Ψ : StoreTy) (Q : NoFailCtx)
    (ks : List Scope.Domain.Kind) (C : TypeCtx) (Γ : Ctx) (Φ : List Pred) (t : Tel) (body : Comp) : Prop :=
  if ks = [] then TelBodyTy P B Ψ Q C Γ Φ t body
  else ∀ rs, RangesFit rs ks → TelBodyTy P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTel rs t) (body.instR rs)

@[simp] theorem telBodyTyR_nil {P B Ψ Q C Γ Φ t body} :
    TelBodyTyR P B Ψ Q [] C Γ Φ t body ↔ TelBodyTy P B Ψ Q C Γ Φ t body := by
  simp only [TelBodyTyR, ite_true]

theorem TelBodyTyR.instR {P B Ψ Q ks C Γ Φ t body rs}
    (h : TelBodyTyR P B Ψ Q ks C Γ Φ t body) (hr : RangesFit rs ks) :
    TelBodyTy P B Ψ Q C (rangeCtx rs Γ) Φ (rangeTel rs t) (body.instR rs) := by
  by_cases hk : ks = []
  · subst ks
    have hnil : rs = [] := List.eq_nil_of_length_eq_zero hr.1
    subst rs
    simpa [TelBodyTyR, rangeCtx, rangeTel] using h
  · simp only [TelBodyTyR, hk, ↓reduceIte] at h
    exact h rs hr

end
end Benitoite.Release.Refinement
```

## ProgramTyping.lean（全定義と補助）

```lean
import Benitoite.Release.Refinement.Typing
import Benitoite.Release.Refinement.RangeTyping
import Benitoite.Release.Refinement.VarianceValidation

/-! # 定義・実装・プログラムの型付け（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 依存列と非依存の呼出し側で、同じ行変数の条件を読む。 -/
theorem QTel_signatureTel (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) :
    QTel (signatureTel ns ps r e) = Qsig ps r e := by
  induction ns generalizing ps with
  | nil =>
    have hp : ps = [] := List.eq_nil_of_length_eq_zero hn.1.symm
    subst ps
    funext i
    apply propext
    simp [signatureTel, QTel, Qsig, QTys, Qempty]
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hns : NamesWF ns ps := ⟨by simpa using hn.1, hn.2.tail⟩
      funext i
      apply propext
      simp only [signatureTel, QTel, ih ps hns, Qsig, QTys]
      exact or_assoc.symm

theorem Def.QTel_eq_Qsig (d : Def) (hn : NamesWF d.names d.params) :
    QTel d.tel = Qsig d.params d.ret d.eff :=
  QTel_signatureTel d.names d.params d.ret d.eff hn

theorem MethSig.QTel_eq_Qsig (ms : MethSig) (hn : NamesWF ms.names ms.params) :
    QTel ms.tel = Qsig ms.params ms.ret ms.eff :=
  QTel_signatureTel ms.names ms.params ms.ret ms.eff hn

/-- 各引数を順に束縛し、done の結果型を return 契約にする。 -/
def Def.WellTyped (P : Program) (B : Builtins) (d : Def) : Prop :=
  NamesWF d.names d.params ∧
  Ty.HasKind P (TypeCtx.kinds d.tparams) (.dependentFn d.tel) .value ∧
  Ty.AnnotationR P d.rkinds d.tparams [] (.dependentFn d.tel) ∧
  TelBodyTyR P B StoreTy.empty (QTel d.tel)
    d.rkinds d.tparams [] [] d.tel d.body

/-- 型クラスの引数の型代入の後、実装の辞書の個数だけ値参照を移す。 -/
def ImplDecl.WellTyped (P : Program) (B : Builtins) (id : ImplDecl) : Prop :=
  ∃ cd, P.classes id.cls = some cd ∧
    (∀ m, (id.methods m).isSome = (cd.methods m).isSome) ∧
    (∀ s, (id.supers s).isSome = decide (s ∈ cd.supers)) ∧
    Ty.HasKind P (TypeCtx.kinds (TypeCtx.values id.tparams)) id.target cd.argumentKind ∧
    TypeAnnotations P (TypeCtx.values id.tparams) [] id.dictTys ∧
    (∀ m ms, cd.methods m = some ms → ∃ body, id.methods m = some body ∧
      NamesWF ms.names ms.params ∧
      let θ := typeEnvAt ms.tparams.length [id.target] []
      let t := Tel.bind θ ms.tel
      let C := ms.tparams ++ TypeCtx.values id.tparams
      let Γ := bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))
      let t' := Tel.shiftV id.dictTys.length 0 t
      TelBodyTy P B StoreTy.empty (QTel ms.tel) C Γ [] t' body) ∧
    (∀ s ∈ cd.supers, ∃ u, id.supers s = some u ∧
      HasTypeV P B StoreTy.empty (TypeCtx.values id.tparams) (bindParams [] id.dictTys) []
        u (.dict s id.target))

/-- 呼出し規則 C-Meth が読む代入前の Qsig で、実装の本体を取り出す。 -/
theorem ImplDecl.WellTyped.method_body {P : Program} {B : Builtins} {id : ImplDecl}
    (h : id.WellTyped P B) {cd : ClassDecl} {m : MethName} {ms : MethSig}
    (hc : P.classes id.cls = some cd) (hm : cd.methods m = some ms) :
    ∃ body, id.methods m = some body ∧ NamesWF ms.names ms.params ∧
      TelBodyTy P B StoreTy.empty (Qsig ms.params ms.ret ms.eff)
        (ms.tparams ++ TypeCtx.values id.tparams)
        (bindParams [] (id.dictTys.map (Ty.shift ms.tparams.length 0))) []
        (Tel.shiftV id.dictTys.length 0
          (Tel.bind (typeEnvAt ms.tparams.length [id.target] []) ms.tel)) body := by
  obtain ⟨cd', hc', _, _, _, _, hb, _⟩ := h
  have he : cd' = cd := Option.some.inj (hc'.symm.trans hc)
  subst cd'
  obtain ⟨body, hbody, hn, ht⟩ := hb m ms hm
  exact ⟨body, hbody, hn, by simpa only [ms.QTel_eq_Qsig hn] using ht⟩

/-- 変性と外部宣言の構造検証を、全 lookup の本体の型付けと同じ P に対して要求する。 -/
structure Program.WellTyped (P : Program) (B : Builtins) : Prop where
  variance : P.VarianceValid
  external : P.ExternalWF
  defs : ∀ f d, P.defs f = some d → Def.WellTyped P B d
  impls : ∀ i id, P.impls i = some id → ImplDecl.WellTyped P B id

end
end Benitoite.Release.Refinement
```

## SourceScope.lean（全定義と補助）

```lean
import Benitoite.Release.Refinement.Admissible
import Benitoite.Release.Refinement.Source

/-! # ソースの四名前空間の上限（設計書 01-12「型付け規則」） -/
namespace Benitoite.Release.Refinement
noncomputable section

/- Eff.WF は Fail の型だけを読むため、効果原子の範囲添字を別に検査する。 -/
mutual
  def Ty.RangesScoped (nr : Nat) : Ty → Prop
    | .opaque _ ix | .scoped _ _ ix => ix.WF nr
    | .data _ as | .tapp _ as | .external _ as => rangesScopedTypes nr as
    | .list a | .reference a | .lazy a | .set a | .dict _ a | .refined a _ => a.RangesScoped nr
    | .map a b => a.RangesScoped nr ∧ b.RangesScoped nr
    | .fn _ ps r e => rangesScopedTypes nr ps ∧ r.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .cont a b e => a.RangesScoped nr ∧ b.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .dependentFn t => t.RangesScoped nr
    | _ => True
  def Tel.RangesScoped (nr : Nat) : Tel → Prop
    | .done a e => a.RangesScoped nr ∧ Eff.RangesScoped nr e
    | .param _ a t => a.RangesScoped nr ∧ t.RangesScoped nr
  def Eff.RangesScoped (nr : Nat) : Eff → Prop
    | .mk atoms fs => (∀ name ix, atoms (.name name ix) = true → ix.WF nr) ∧ rangesScopedTypes nr fs
  def rangesScopedTypes (nr : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.RangesScoped nr ∧ rangesScopedTypes nr as
end

/-- 四名前空間のうち、型注釈に現れる範囲・型・値と、行変数の上限。 -/
def Ty.SourceScoped (nr nt ne nv : Nat) (a : Ty) : Prop :=
  a.WF nr nt nv ∧ a.RowsIn (· < ne) ∧ a.RangesScoped nr

def Eff.SourceScoped (nr nt ne nv : Nat) (e : Eff) : Prop :=
  e.WF nr nt nv ∧ e.RowsIn (· < ne) ∧ Eff.RangesScoped nr e

def BuilderKind.SourceScoped (nr nt ne nv : Nat) : BuilderKind → Prop
  | .list a => a.SourceScoped nr nt ne nv
  | .string | .bytes => True

mutual
  /-- ソースの値構文だけを受け入れ、束縛位置で各名前空間の深さを増やす。 -/
  def Val.SourceScoped (nr nt ne nv : Nat) : Val → Prop
    | .var i => i < nv
    | .const _ | .bytesV _ => True
    | .fnRef _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical)
    | .prim _ ts es rs => scopedTypes nr nt ne nv ts ∧ scopedRows nr nt ne nv es ∧
        (∀ ix ∈ rs, ix.WF nr ∧ ∀ r, ix = .fixed r → r.WF ∧ r.Canonical)
    | .lam ns ps body => NamesWF ns ps ∧ scopedTypes nr nt ne nv ps ∧
        body.SourceScoped nr nt ne (nv + ps.length)
    | .dependentLam t body => (Ty.dependentFn t).SourceScoped nr nt ne nv ∧
        body.SourceScoped nr nt ne (nv + telBinders t)
    | .con _ ts vs | .dict _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .list vs | .setV vs => scopedValues nr nt ne nv vs
    | .op _ ts | .externalRef _ ts => scopedTypes nr nt ne nv ts
    | .raise a e => a.SourceScoped nr nt ne nv ∧ e.SourceScoped nr nt ne nv
    | .mapV ks vs => scopedValues nr nt ne nv ks ∧ scopedValues nr nt ne nv vs
    | .super v _ => v.SourceScoped nr nt ne nv
    | .scopePattern r => r.WF ∧ r.Canonical
    | .closure _ _ | .loc _ | .externalHandle _ _ | .pathBases _ |
        .checkedAt _ _ _ _ | .atError _ | .checked _ | .checkedRequest _ _ => False
  def scopedValues (nr nt ne nv : Nat) : List Val → Prop
    | [] => True
    | v :: vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
  def Comp.SourceScoped (nr nt ne nv : Nat) : Comp → Prop
    | .builderLet k m => k.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne (nv+1)
    | .builderOp k _ r vs => k.SourceScoped nr nt ne nv ∧
        (match r with | .bound i => i < nv | .loc _ => False) ∧ scopedValues nr nt ne nv vs
    | .ret v | .escape v => v.SourceScoped nr nt ne nv
    | .letIn m n => m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne (nv+1)
    | .app v vs => v.SourceScoped nr nt ne nv ∧ scopedValues nr nt ne nv vs
    | .ite v m n => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv ∧ n.SourceScoped nr nt ne nv
    | .match v arms => v.SourceScoped nr nt ne nv ∧ scopedArms nr nt ne nv arms
    | .lazyC m => m.SourceScoped nr nt ne nv
    | .use v m => v.SourceScoped nr nt ne nv ∧ m.SourceScoped nr nt ne nv
    | .handle m cs => m.SourceScoped nr nt ne nv ∧ scopedClauses nr nt ne nv cs
    | .resume k v => k.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .externalCall _ ts vs => scopedTypes nr nt ne nv ts ∧ scopedValues nr nt ne nv vs
    | .issuePathBases _ => False
    | .checkAt _ _ sh bs p v ix => sh.errorType.SourceScoped nr nt ne nv ∧ ix.WF nr ∧
        (match bs with | none => True | some b => b.SourceScoped nr nt ne nv) ∧
        p.SourceScoped nr nt ne nv ∧ v.SourceScoped nr nt ne nv
    | .meth d _ ts es vs => d.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv ts ∧
        scopedRows nr nt ne nv es ∧ scopedValues nr nt ne nv vs
  def scopedArms (nr nt ne nv : Nat) : List Arm → Prop
    | [] => True
    | .mk alts guard body :: arms =>
        (match guard with | none => True | some g => g.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts)) ∧
        body.SourceScoped nr nt ne (nv + Benitoite.Release.Arm.bindersOf alts) ∧ scopedArms nr nt ne nv arms
  def scopedClauses (nr nt ne nv : Nat) : List Clause → Prop
    | [] => True
    | .mk _ arity k body :: cs => body.SourceScoped nr (nt+k) ne (nv+arity+1) ∧ scopedClauses nr nt ne nv cs
    | .fail e body :: cs => e.SourceScoped nr nt ne nv ∧
        body.SourceScoped nr (nt+1) ne (nv+2) ∧ scopedClauses nr nt ne nv cs
  def scopedTypes (nr nt ne nv : Nat) : List Ty → Prop
    | [] => True
    | a :: as => a.SourceScoped nr nt ne nv ∧ scopedTypes nr nt ne nv as
  def scopedRows (nr nt ne nv : Nat) : List Eff → Prop
    | [] => True
    | e :: es => e.SourceScoped nr nt ne nv ∧ scopedRows nr nt ne nv es
end

/-- WF は依存列内の深さを増やし、Annotation は参照順序・sort・宣言を同時に読む。 -/
def SignatureScoped (P : Program) (C : TypeCtx) (ne : Nat) (t : Tel) : Prop :=
  (Ty.dependentFn t).SourceScoped 0 C.length ne 0 ∧ t.RowsIn (· < ne) ∧
    Ty.HasKind P (TypeCtx.kinds C) (.dependentFn t) .value ∧ Ty.Annotation P C [] (.dependentFn t)

end
end Benitoite.Release.Refinement
```

## Typing.lean

```lean
    | V_Fun {Ψ Q C Γ Φ f d ts es rs} : P.defs f = some d → NamesWF d.names d.params →
        Def.RangeAdmissible d rs →
        Admissible B C Γ.length (TypeCtx.constraints d.tparams) d.neffs
          (Qsig d.params d.ret d.eff) Q ts es d.eff →
        SignatureInstance P C Γ (d.instTel rs) (TypeCtx.kinds d.tparams) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.fnRef f ts es (rs.map RangeIx.fixed))
          (.dependentFn (instantiatedTel (d.instTel rs) ts es))
    | V_Prim {Ψ Q C Γ Φ b s ts es rs} : B.sig b = some s → B.RangeAdmissible b s rs →
        NamesWF s.names s.params → PrimitiveAdmissible C Γ.length s Q ts es →
        SignatureInstance P C Γ (Tel.instR rs s.tel) (TypeCtx.kinds s.tparams) ts es →
        HasTypeVQ P B Ψ Q C Γ Φ (.prim b ts es (rs.map RangeIx.fixed))
          (.dependentFn (instantiatedTel (Tel.instR rs s.tel) ts es))
```

## Typing.lean

```lean
    | C_Match {Ψ Q C Γ Φ Δ R v obs arms a b ε} :
        HasTypeVQ P B Ψ Q C Γ Φ v a →
        (∀ t, obs = some t → v.toTerm? = some t ∧ ∃ s, t.HasSort Γ s) →
        HasTypeArmsQ P B Ψ Q C Γ Φ R obs arms a b ε Δ →
        Ty.Declared P C Γ a →
        Exhaustive P a (unguardedPats arms) →
        HasTypeCQ P B Ψ Q C Γ Φ R (.match v arms) b ε Δ
```

## Typing.lean

```lean
    | C_Handle {Ψ Q C Γ Φ Δ R m h t εm ε} : HasTypeCQ P B Ψ Q C Γ Φ R m t εm Δ →
        Eff.Sub εm (Eff.union ε (handled P B h)) →
        HasTypeClausesQ P B Ψ Q C Γ Φ R εm h t ε Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) t ε Δ
    | C_Handle_Fail {Ψ Q C Γ Φ Δ R m h t E eb rest ec} : HasTypeCQ P B Ψ Q C Γ Φ R m t eb Δ →
        Eff.Sub eb (Eff.union (Eff.singleFail E) rest) → NoFail Q rest →
        HasFailureClause P B Ψ Q C Γ Φ E R h t ec Δ →
        HasTypeCQ P B Ψ Q C Γ Φ R (.handle m h) t (Eff.union rest ec) Δ
```

## HandlerContracts.lean

```lean
def Builtins.issuesIn (B : Builtins) (l : EffName) : Bool :=
  match B.effects l with
  | some bs => bs.any fun b => match B.sig b with
      | some s => decide (s.kind = .pathBases)
      | none => false
  | none => false

/-- 利用者の一覧を選んだラベルでは、組込みの一覧を読まない。 -/
def issuesSelected (P : Program) (B : Builtins) (l : EffName) : Bool :=
  match P.effects l with
  | some _ => false
  | none => B.issuesIn l

def handled (P : Program) (B : Builtins) (h : List Clause) : Eff :=
  .mk (fun a => match a with
    | .name l _ => match effOps P B l with
      | some (o::os) => (o::os).all (handles h) && !issuesSelected P B l
      | _ => false
    | .rho _ => false) []

abbrev handledSelected (P : Program) (B : Builtins) (h : List Clause) : Eff := handled P B h
```

## Semantics.lean

```lean
  | E_Fun {f ts es rs ws k μ d} {q : Closure} :
      q.view = (.app (.fnRef f ts es (List.map RangeIx.fixed rs)) ws) →
      P.defs f = some d →
      ws.length = d.params.length → ts.length = d.ntys → es.length = d.neffs →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (Capture.empty.extendMany ws) ((d.body.instR rs).substTy ts es)) (markPush k) μ)
  
  | E_Meth {i ts vs m ss es ws k μ id body cd ms} {q : Closure} :
      q.view = (.meth (.dict i ts vs) m ss es ws) →
      P.impls i = some id → id.methods m = some body → P.classes id.cls = some cd →
      cd.methods m = some ms →
      ws.length = ms.params.length → vs.length = id.dictTys.length → ts.length = id.tparams.length →
      ss.length = ms.tparams.length → es.length = ms.neffs →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (Capture.empty.extendMany (vs ++ ws)) (body.substTy (ss ++ ts) es)) (markPush k) μ)
  
  | E_Super {v v' m ss es ws k μ} {q : Closure} :
      q.view = (.meth v m ss es ws) →
      v.superStep P = some v' →
      Step P B σ (.run q k μ) none (.run (Closure.pure (.meth v' m ss es ws)) k μ)
  | E_IfT {m n k μ} {q : Closure} :
      q.view = (.ite (.const (.boolean true)) m n) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture m) k μ)
  | E_IfF {m n k μ} {q : Closure} :
      q.view = (.ite (.const (.boolean false)) m n) →
      Step P B σ (.run q k μ) none (.run (Closure.mk q.capture n) k μ)
  | E_Match {v arms k μ} {q : Closure} :
      q.view = (.match v arms) →
      Step P B σ (.run q k μ) none (.matchRun v q.capture arms 0 k μ)
  | E_MatchSkip {v arms next alts guard body k μ} {cap : Capture} :
      arms[next]? = some (.mk alts guard body) → firstAlt v alts = none →
      Step P B σ (.matchRun v cap arms next k μ) none (.matchRun v cap arms (next + 1) k μ)
  | E_MatchBody {v arms next alts body ws k μ} {cap : Capture} :
      arms[next]? = some (.mk alts none body) → firstAlt v alts = some ws →
      Step P B σ (.matchRun v cap arms next k μ) none (.run (Closure.mk (cap.extendMany ws) body) k μ)
  | E_MatchGuard {v arms next alts guard body ws k μ} {cap : Capture} :
      arms[next]? = some (.mk alts (some guard) body) → firstAlt v alts = some ws →
      Step P B σ (.matchRun v cap arms next k μ) none
        (.run (Closure.mk (cap.extendMany ws) guard) (.guardF v cap arms (next + 1) (Closure.mk (cap.extendMany ws) body) :: k) μ)
  | E_GuardT {v arms next body k μ} {q : Closure} {cap : Capture} :
      q.view = (.ret (.const (.boolean true))) →
      Step P B σ (.run q (.guardF v cap arms next body :: k) μ) none (.run body k μ)
  | E_GuardF {v arms next body k μ} {q : Closure} {cap : Capture} :
      q.view = (.ret (.const (.boolean false))) →
      Step P B σ (.run q (.guardF v cap arms next body :: k) μ) none
        (.matchRun v cap arms next k μ)
  | E_ErrPopGuard {rs v arms next body k μ} {cap : Capture} :
      Step P B σ (.error rs (.guardF v cap arms next body :: k) μ) none (.error rs k μ)
  | E_ExitPopGuard {n rs v arms next body k μ} {cap : Capture} :
      Step P B σ (.exit n rs (.guardF v cap arms next body :: k) μ) none (.exit n rs k μ)
```

## Semantics.lean

```lean
  | E_PathBasesApply {q : Closure} {b sg k μ} :
      q.view = .app (.prim b [] [] []) [] → B.sig b = some sg → sg.kind = .pathBases →
      Step P B σ (.run q k μ) none (.run (.mk q.capture (.issuePathBases b)) k μ)
  | E_IssuePathBases {q : Closure} {b sg k μ} :
      q.view = .issuePathBases b → B.sig b = some sg → sg.kind = .pathBases →
      sg.opEff = some processEnvironmentEff → σ.Valid →
      Step P B σ (.run q k μ) (some (.pathBases b σ))
        (.run (Closure.pure (.ret (.pathBases σ))) k μ)
```

## Semantics.lean

```lean
  | E_OpPrim {b ts es rs ws k μ s k1 h k2 c κ} {q : Closure} {hcap : Capture} :
      q.view = (.app (.prim b ts es (List.map RangeIx.fixed rs)) ws) →
      B.sig b = some s → (s.kind = .io ∨ s.kind = .exit) →
      SplitAt (.prim b) k k1 hcap h k2 → findClause h (.prim b) = some c → μ κ = none →
      Step P B σ (.run q k μ) none
        (.run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts [])) (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
```

## Step.lean（組込みの適用の全分岐）

```lean
  | (.app (.prim b ts es rs) ws), k, μ =>
      match closedRanges rs with
      | none => none
      | some rs =>
        match B.sig b with
        | none => none
        | some s =>
            match s.kind, ws with
            | .pure, _ =>
                match B.delta b (Ty.normTys ts) (es.map Eff.norm) rs ws with
                | some (.val v) => some (none, .run (Closure.pure (.ret v)) k μ)
                | some (.err r) => some (none, .error [r] k μ)
                | _ => none
            | .pathBases, _ =>
                if ts.isEmpty && es.isEmpty && rs.isEmpty && ws.isEmpty then
                  some (none, .run (.mk q.capture (.issuePathBases b)) k μ)
                else none
            | .io, _ | .exit, _ =>
                match splitHandler (.prim b) k with
                | some (k1, hcap, h, k2) =>
                    match findClause h (.prim b) with
                    | some c =>
                        let κ := fresh μ
                        some (none, .run (Closure.mk (hcap.extendMany (ws ++ [.loc κ])) (c.body.substTy ts []))
                          (.drop κ :: k2) (μ.set κ (.cont (k1 ++ [.handleF hcap h]))))
                    | none => none
                | none =>
                  match s.kind, oracle b (Ty.normTys ts) (es.map Eff.norm) ws with
                    | .io, (.val v, obs) => some (some (.io b ws (.val v) obs), .run (Closure.pure (.ret v)) k μ)
                    | _, (.err r, obs) => some (some (.io b ws (.err r) obs), .error [r] k μ)
                    | .exit, (.exit n, obs) => some (some (.io b ws (.exit n) obs), .exit n [] k μ)
                    | _, _ => none
            | .refNew, [v] =>
                let l := fresh μ
                some (none, .run (Closure.pure (.ret (.loc l))) k (μ.set l (.val v)))
            | .refGet, [.loc l] =>
                match μ l with
                | some (.val v) => some (none, .run (Closure.pure (.ret v)) k μ)
                | _ => none
            | .refSet, [.loc l, v] => some (none, .run (Closure.pure (.ret (.const .unit))) k (μ.set l (.val v)))
            | .refUpdate, [.loc l, f] =>
                some (none, .run (Closure.pure (.letIn (.app (.prim B.refGet ts [] []) [.loc l])
                  (.letIn (.app (f.rename (· + 1)) [.var 0])
                    (.app (.prim B.refSet ts [] []) [.loc l, .var 0])))) k μ)
            | .force, [.loc l] =>
                match μ l with
                | some (.done v) => some (none, .run (Closure.pure (.ret v)) k μ)
                | some (.thunk m) => some (none, .run m (.update l :: k) μ)
                | _ => none
            | _, _ => none
```

## HandlerGeneral.lean（追加した入口の完全署名）

```lean
theorem StateTyE.primitive_effect_input {P B σ Eb q b s ts es rs ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eb (.run q k μ))
    (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit) :
    ∃ Ψ R a z e l bs ix, ContTy P B σ Ψ R e k a z Eb none ∧
      B.effects l = some bs ∧ b ∈ bs ∧ e.mem (.name l ix)
```

## MainEffects.lean（全定義と証明）

```lean
import Benitoite.Release.Refinement.MainTheorems

/-! # 空のエフェクトから始めた実行の健全性 -/
namespace Benitoite.Release.Refinement
noncomputable section

/-- 専用の発行の view を持つ閉包の効果は、発行の効果を覆う。 -/
theorem ClosureTy.issue_path_bases_effect {P B Ψ R q a e b}
    (hq : ClosureTy P B Ψ [] R q a e) (hv : q.view = .issuePathBases b) :
    Eff.Covers [] [] e (Eff.single processEnvironmentEff) := by
  obtain ⟨cap,Γ,Φ,Rs,m,as,es,L,ρ,rfl,hc,hbody,hl,hr,rfl,rfl,hrs⟩ := hq.open_zero
  have hm : m = .issuePathBases b := by
    cases m
    case issuePathBases b0 => cases hv; rfl
    case checkAt k o sh bs p v ix =>
      cases bs <;> (simp only [Comp.resolveLocals,Closure.view] at hv; injection hv)
    all_goals (simp only [Comp.resolveLocals,Closure.view] at hv; injection hv)
  obtain ⟨_,_,_,_,_,_,_,_,hcov⟩ := hbody.inv_issuePathBases hm
  have hh := hcov.bind (Δ := []) (Ψ := []) (valEnv cap.env)
  change Eff.Covers [] [] (cap.closeEff es) (cap.closeEff (Eff.single processEnvironmentEff)) at hh
  simpa only [Capture.closeEff,Eff.subst_values_single] using hh

private theorem empty_no_name {l ix} (h : Eff.empty.mem (.name l ix)) : False := by
  cases h

private theorem release_no_empty {P B σ Ψ R e k a b Re v}
    (hN : NoStateHandled P B) (hk : ContTy P B σ Ψ R e k a b Eff.empty Re)
    (hf : Frame.release v ∈ k) : False :=
  empty_no_name (hk.framesOk hN _ hf).2

private theorem primitive_no_empty {P B σ q b s ts es rs ws k μ}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eff.empty (.run q k μ))
    (hv : q.view = .app (.prim b ts es (List.map RangeIx.fixed rs)) ws)
    (hsig : B.sig b = some s) (hkind : s.kind = .io ∨ s.kind = .exit) (hn : NoHandler k (.prim b)) : False := by
  obtain ⟨Ψ,R,a,z,e,l,bs,ix,hcont,he,hb,hm⟩ := h.primitive_effect_input hP hPB hB hv hsig hkind
  obtain ⟨ix2,hm2,_⟩ := hcont.name_end_ix hm
    (fun cap cs jx hf => hdecl.operation_not_handled he hb (hn cap cs hf))
  exact empty_no_name hm2

/-- 空の末尾効果を持つ状態には、IO・解放・起点発行の事象を出す遷移がない。 -/
theorem StateTyE.no_event {P B σ s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (h : StateTyE P B σ Eff.empty s) : ∀ ev s', ¬ Step P B σ s (some ev) s' := by
  intro ev s' hst
  have hN := hdecl.noStateHandled hB
  cases hst with
  | E_IO hv hs hk hn _ =>
    exact primitive_no_empty hP hPB hdecl hB h hv hs (Or.inl hk) hn
  | E_IOErr hv hs hk hn _ =>
    exact primitive_no_empty hP hPB hdecl hB h hv hs hk hn
  | E_Exit hv hs hk hn _ =>
    exact primitive_no_empty hP hPB hdecl hB h hv hs (Or.inr hk) hn
  | E_IssuePathBases hv hs hk _ _ =>
    obtain ⟨Ψ,R,a,b,e,e1,_,hq,hsub,hcont,_⟩ := h
    have hm : (Eff.single processEnvironmentEff).mem (.name processEnvironmentEff (.fixed .top)) := by
      simp [Eff.single,Eff.mem,Eff.test,Eff.atoms]
    obtain ⟨atom,ha,hcover⟩ := (hq.issue_path_bases_effect hv).1 _ hm
    obtain ⟨ix,rfl⟩ := hcover.name_right
    obtain ⟨jx,hj,_⟩ := hcont.name_end_ix (hsub.1 _ ha)
      (fun _ _ _ _ => hB.pathBases_never_handled hdecl hs hk)
    exact empty_no_name hj
  | E_Release | E_RelErr | E_EscRel | E_EscRelErr =>
    obtain ⟨_,_,_,_,_,_,_,_,_,hk,_⟩ := h
    exact release_no_empty hN hk List.mem_cons_self
  | E_ErrRel | E_ErrRelErr | E_ExitRel | E_ExitRelErr =>
    obtain ⟨_,_,_,_,_,_,hk,_⟩ := h
    exact release_no_empty hN hk List.mem_cons_self

/-- 処理する枠のない操作の呼出しは、終端ではない。 -/
theorem UnhandledOp.not_final {s} (h : UnhandledOp s) : ¬ s.Final := by
  cases s with
  | run q k μ =>
    intro hf
    cases k with
    | cons f k => cases hf
    | nil =>
      obtain ⟨v,hv⟩ := hf
      simp [UnhandledOp,hv] at h
  | _ => cases h

/-- 処理する枠のない操作の呼出しには、一段の規則がない。 -/
theorem UnhandledOp.not_step {P B σ s} (h : UnhandledOp s) :
    ∀ label dest, ¬ Step P B σ s label dest := by
  intro label dest hst
  cases hst <;> simp_all [UnhandledOp]
  case E_Lam q f signature body ws k μ hv hc ha =>
    cases f <;> simp_all [closeVal]
  case E_AtOk => simp_all [Closure.view]
  case E_AtError => simp_all [Closure.view]
  case E_AtPrepareError => simp_all [Closure.view]
  case E_Op o ts ws k μ k1 cs k2 c κ q cap hv hs hc hf =>
    have hh := h cap cs (by rw [hs.1]; simp)
    rw [hs.2.1] at hh
    cases hh
  case E_OpFail T E' v k μ k1 E body k2 κ q cap hv hs hf =>
    have hh := h cap [.fail E body] (by rw [hs.1]; simp)
    rw [hs.2.1] at hh
    cases hh

/-- 進行の条件を満たす型付きの状態は、処理されない操作の呼出しではない。 -/
theorem StateTyE.no_unhandledOp {P B σ Eb s}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (hσ : σ.Valid) (hEb : BuiltinOnly P B Eb) (h : StateTyE P B σ Eb s) : ¬ UnhandledOp s := by
  intro hu
  rcases h.progress hP hPB hdecl hB hσ hEb with hf | ⟨label,dest,hst⟩
  · exact hu.not_final hf
  · exact hu.not_step label dest hst

/-- 空の効果で型付けした閉包から到達する全状態について、事象と未処理の操作を排除する。 -/
theorem effect_soundness (P : Program) (B : Builtins) (σ : PathEnv) :
    EffectSoundnessStatement P B σ := by
  intro hP hPB hdecl hB q a hq hstart evs s hsteps
  have hσ := hstart.prepared.ready.1
  have h0 := initial_typing P B σ hP hPB hB q a Eff.empty hq hstart
  have h := h0.steps_preserved hP hPB hdecl hB hσ hsteps
  exact ⟨h.no_event hP hPB hdecl hB,
    h.no_unhandledOp hP hPB hdecl hB hσ ⟨rfl,fun _ hm => by cases hm⟩⟩

/-- ラムダ名を条件に含めない閉じ方から、同じ到達状態の二条件を得る。名前の整形式は型付けから供給する。 -/
theorem effect_soundness_noLamNames (P : Program) (B : Builtins) (σ : PathEnv)
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hdecl : P.EffectsOk B) (hB : B.CoreAssumptions P)
    (q : Closure) (a : Ty) (hq : ClosureTy P B StoreTy.empty [] none q a Eff.empty)
    (had : q.Adequate σ) (hc : q.ClosedNoLamNames 0)
    (hp : InitialPrepared P B σ (.run q [] Store.empty)) :
    ∀ evs s, Steps P B σ (.run q [] Store.empty) evs s →
      (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s :=
  effect_soundness P B σ hP hPB hdecl hB q a hq
    (StartCondition.of_typed_noLamNames hq had hc hp)

end
end Benitoite.Release.Refinement
```

## EffectSoundnessExamples.lean（全定義と証明）

```lean
import Benitoite.Release.Refinement.MainEffects
import Benitoite.Release.Refinement.OperationStateExamples

/-! # 起点発行の効果を残す型付けと、空の効果の拒否 -/
namespace Benitoite.Release.Refinement
noncomputable section
namespace EffectSoundnessExamples

open ScopeSignatures

/-- 宣言を持たないプログラム。 -/
def program : Program where
  defs := fun _ => none
  cons := fun _ => none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

/-- すべての起点と secrets を束縛する σ。 -/
def σFull : PathEnv := ⟨[],[],[],some [],some [],some []⟩

def clauses : List Clause := [.mk (.prim pathBasesName) 0 0 (.ret (.const .unit))]
def body : Comp := .letIn (.issuePathBases pathBasesName) (.ret (.const .unit))
def start : Closure := Closure.pure (.handle body clauses)

theorem valid : σFull.Valid := by
  simp [PathEnv.Valid,σFull,Scope.Domain.PathWordWF]

theorem wellFormed : program.WellFormed where
  defs := by intro f d h; cases h
  cons := by intro c cd h; cases h
  ops := by intro o od h; cases h
  classes := by intro cl cd h; cases h
  impls := by intro i id h; cases h
  metadata := by intro d info h; cases h
  external := ⟨by simp [program],by intro key decl h; cases h⟩

theorem wellTyped : program.WellTyped Model.builtins where
  variance := ⟨(by intro d info h; cases h),(by intro c cd h; cases h)⟩
  external := ⟨by simp [program],by intro key decl h; cases h⟩
  defs := by intro f d h; cases h
  impls := by intro i id h; cases h

theorem effectsOk : program.EffectsOk Model.builtins :=
  ⟨by intro l os o h; simp [program] at h,by intro o od h; simp [program] at h,
    by intro l os h; simp [program] at h⟩

theorem core : Model.builtins.CoreAssumptions program :=
  (Model.scopeConditions program).core
    ⟨by intro _ _ _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,program] at h,
      by intro _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,program] at h,
      by intro _ _ _ _ _ _ _ _ _ _ h; simp [Program.externalFunction,program] at h⟩
    (by intro Ψ v o _ h; cases h)

theorem sig : Model.builtins.sig pathBasesName = some pathBases := rfl

private theorem empty_sub (e : Eff) : Eff.Sub Eff.empty e :=
  ⟨by intro a ha; simp [Eff.empty,Eff.mem,Eff.test,Eff.atoms] at ha,
    by intro t ht; obtain ⟨u,hu,_⟩ := ht; simp [Eff.empty,Eff.fails] at hu⟩

/-- 発行を含む保護本体の効果は、同じ節で空へ除けない。 -/
theorem handled_environment_rejected :
    ¬ Eff.Sub (Eff.single processEnvironmentEff) (Eff.union Eff.empty (handled program Model.builtins clauses)) := by
  intro hsub
  have hm : (Eff.single processEnvironmentEff).mem (.name processEnvironmentEff (.fixed .top)) := by
    simp [Eff.single,Eff.mem,Eff.test,Eff.atoms]
  rcases (Eff.mem_union_iff _ _ _).mp (hsub.1 _ hm) with he | he
  · cases he
  · exact core.pathBases_never_handled effectsOk sig rfl he

/-- 開始の閉包は発行の効果を保って型が付く。 -/
theorem typed_environment : ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) (Eff.single processEnvironmentEff) := by
  have ha : Ty.Annotation program [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hissue : HasTypeC program Model.builtins StoreTy.empty [] [] [] none (.issuePathBases pathBasesName)
      .pathBases (Eff.single processEnvironmentEff) :=
    core.issuePathBases_typed sig rfl
  have hbody : HasTypeC program Model.builtins StoreTy.empty [] [] [] none body (.base .unit)
      (Eff.single processEnvironmentEff) :=
    .C_Let hissue (.C_Eff (.C_Return (.V_Const (c := .unit) (by trivial))) (empty_sub _).covers) (by trivial)
  let sg : OpSig := ⟨[],[],[],.pathBases,processEnvironmentEff⟩
  have hcs : HasTypeClauses program Model.builtins StoreTy.empty [] [] [] none
      (Eff.single processEnvironmentEff) clauses (.base .unit) (Eff.single processEnvironmentEff) := by
    refine .cons (sg := sg) (ClauseSig.of_opSig ?_ ?_) (by trivial) rfl rfl (by trivial) ?_ .nil
    · simp [opSig,opSigAt,sig,pathBases,sg]
    · intro b s ho hs
      cases ho
      cases Option.some.inj (hs.symm.trans sig)
      simp [pathBases,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Eff.RowsIn,Ty.RowsInList,Eff.single]
    · exact .C_Eff (.C_Return (.V_Const (by trivial))) (empty_sub _).covers
  have hann : Ty.Annotation program [] [] (.dependentFn (.done (.base .unit) (Eff.single processEnvironmentEff))) :=
    ⟨by simp [Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.single,Eff.Canonical,Eff.norm,Ty.normTys],by trivial,by trivial⟩
  exact ClosureTy.pure (.C_Handle hbody
    ⟨fun a ha => (Eff.mem_union_iff _ _ _).mpr (.inl ha),
      fun a ha => (Eff.memFail_union_iff _ _ _).mpr (.inl ha)⟩ hcs) hann
    (by intro r hr; cases hr) rfl (by intro r hr; cases hr)

/-- 開始の条件を満たす。σ がすべての起点と secrets を束縛するので、必要な束縛は辿り方によらない。 -/
theorem startCondition : StartCondition program Model.builtins σFull start := by
  refine ⟨by simp [start,Closure.pure,body,clauses,Closure.Adequate,Comp.Adequate,adequateClauses,
      Capture.Adequate,adequateCaptureSlots,Capture.empty,Val.Adequate],
    by simp [start,Closure.pure,body,clauses,Closure.ClosedAt,Comp.ClosedAt,Clause.ClosedList,Val.ClosedAt,
      Capture.Closed,captureSlotsClosed,Capture.empty],⟨valid,fun r _ => ?_⟩⟩
  cases r with
  | base b => cases b <;> exact ⟨_,rfl⟩
  | secrets => rfl

/-- 二段で、発行の計算が処理する枠の下に現れる。 -/
theorem reach : Steps program Model.builtins σFull (.run start [] Store.empty) []
    (.run (Closure.mk Capture.empty (.issuePathBases pathBasesName))
      [.letF (Closure.mk Capture.empty (.ret (.const .unit))),.handleF Capture.empty clauses] Store.empty) :=
  .cons (.E_Handle rfl) (.cons (.E_Let rfl) .nil)

/-- その状態は σ の発行の事象を伴って遷移する。 -/
theorem issue : Step program Model.builtins σFull
    (.run (Closure.mk Capture.empty (.issuePathBases pathBasesName))
      [.letF (Closure.mk Capture.empty (.ret (.const .unit))),.handleF Capture.empty clauses] Store.empty)
    (some (.pathBases pathBasesName σFull))
    (.run (Closure.pure (.ret (.pathBases σFull)))
      [.letF (Closure.mk Capture.empty (.ret (.const .unit))),.handleF Capture.empty clauses] Store.empty) :=
  .E_IssuePathBases rfl sig rfl rfl valid

/-- 同じ開始条件と実際の発行を持つ入力には、空の効果の型付けがない。 -/
theorem empty_typing_rejected :
    ¬ ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) Eff.empty := by
  intro typed
  have h := effect_soundness program Model.builtins σFull wellFormed wellTyped effectsOk core
    start (.base .unit) typed startCondition [] _ reach
  exact h.1 _ _ issue

/-- 発行の開始は空の効果では拒否され、宣言した効果では型付きの実行と正常値を持つ。 -/
theorem environment_witness :
    (¬ Eff.Sub (Eff.single processEnvironmentEff) (Eff.union Eff.empty (handled program Model.builtins clauses))) ∧
    (¬ ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) Eff.empty) ∧
    ClosureTy program Model.builtins StoreTy.empty [] none start (.base .unit) (Eff.single processEnvironmentEff) ∧
    StartCondition program Model.builtins σFull start ∧
    ∃ s t, Steps program Model.builtins σFull (.run start [] Store.empty) [] s ∧
      Step program Model.builtins σFull s (some (.pathBases pathBasesName σFull)) t ∧
      StateTyE program Model.builtins σFull (Eff.single processEnvironmentEff) t := by
  have h0 := initial_typing program Model.builtins σFull wellFormed wellTyped core
    _ _ _ typed_environment startCondition
  have hr := h0.steps_preserved wellFormed wellTyped effectsOk core valid reach
  exact ⟨handled_environment_rejected,empty_typing_rejected,typed_environment,startCondition,_,_,reach,issue,
    hr.step_preserved wellFormed wellTyped effectsOk core valid issue⟩

/-- 同じ発行の組込みの節がある具体の型付きの状態でも、発行を差し替えない。 -/
theorem handler_bypass_witness :
    ∃ q cap cs mid next,
      handles cs (.prim pathBasesName) = true ∧
      StateTyE program Model.builtins σFull
        (Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff))
        (.run q [.handleF cap cs] Store.empty) ∧
      Step program Model.builtins σFull (.run q [.handleF cap cs] Store.empty) none mid ∧
      Step program Model.builtins σFull mid (some (.pathBases pathBasesName σFull)) next ∧
      StateTyE program Model.builtins σFull
        (Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff)) mid ∧
      StateTyE program Model.builtins σFull
        (Eff.union (Eff.single processEnvironmentEff) (Eff.single stateEff)) next := by
  obtain ⟨hsource,happly,hmid,hissue,hnext⟩ :=
    OperationStateExamples.primitive_pathBases wellFormed wellTyped core rfl valid
  refine ⟨_,_,_,_,_,?_,hsource,happly,hissue,hmid,hnext⟩
  rfl

/-- 同じ実表と有効環境の単位値の開始に、ラムダ名を前提にしない定理を適用する。 -/
theorem unit_noLamNames_witness :
    ∃ q, ClosureTy program Model.builtins StoreTy.empty [] none q (.base .unit) Eff.empty ∧
      q.Adequate σFull ∧ q.ClosedNoLamNames 0 ∧ InitialPrepared program Model.builtins σFull (.run q [] Store.empty) ∧
      (∀ ev s', ¬ Step program Model.builtins σFull (.run q [] Store.empty) (some ev) s') ∧
      ¬ UnhandledOp (.run q [] Store.empty) := by
  let q := Closure.pure (.ret (.const .unit))
  have ha : Ty.Annotation program [] [] (.base .unit) := ⟨trivial,trivial,trivial⟩
  have hm : HasTypeC program Model.builtins StoreTy.empty [] [] [] none
      (.ret (.const .unit)) (.base .unit) Eff.empty := .C_Return (.V_Const (by trivial))
  have hq : ClosureTy program Model.builtins StoreTy.empty [] none q (.base .unit) Eff.empty :=
    ClosureTy.pure hm ha.done_empty (by intro r hr; cases hr) rfl (by intro r hr; cases hr)
  have hp : InitialPrepared program Model.builtins σFull (.run q [] Store.empty) := by
    refine ⟨valid,fun r _ => ?_⟩
    cases r with
    | base b => cases b <;> exact ⟨_,rfl⟩
    | secrets => rfl
  have hn := effect_soundness_noLamNames program Model.builtins σFull wellFormed wellTyped effectsOk core
    q (.base .unit) hq (by trivial) (by trivial) hp [] _ .nil
  exact ⟨q,hq,(by trivial),(by trivial),hp,hn⟩

end EffectSoundnessExamples
end
end Benitoite.Release.Refinement
```

## MainStatements.lean

```lean
def EffectSoundnessStatement (P : Program) (B : Builtins) (σ : PathEnv) : Prop :=
  P.WellFormed → P.WellTyped B → P.EffectsOk B → B.CoreAssumptions P →
    ∀ q a, ClosureTy P B StoreTy.empty [] none q a Eff.empty → StartCondition P B σ q →
      ∀ evs s, Steps P B σ (.run q [] Store.empty) evs s →
        (∀ ev s', ¬ Step P B σ s (some ev) s') ∧ ¬ UnhandledOp s

/-- 一段の対象健全性。継続の末尾に効果 Eb を固定した状態の IO の事象の観測の対象は、その操作の名前の Eb の原子が
σ の下で許す。事象の実引数の型付けを閉じた view から得るので、プログラムの整形式と型付けを前提に読む。 -/
```
