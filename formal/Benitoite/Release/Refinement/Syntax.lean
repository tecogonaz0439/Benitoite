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
    | fnRef (f : FunName) (tys : List Ty) (effs : List Eff)
    /-- 組み込みの関数 `b[T̄; Ē; R̄]`。`rs` は具体化した範囲の列。 -/
    | prim (b : PrimName) (tys : List Ty) (effs : List Eff) (rs : List RangeExpr)
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
