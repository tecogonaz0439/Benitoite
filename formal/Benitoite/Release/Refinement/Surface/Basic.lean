import Benitoite.Release.Refinement.Surface.Syntax
import Benitoite.Release.Refinement.Patterns
import Benitoite.Release.BuiltinTable

/-!
# 篩付きの表層の構文の派生の定義

脱糖と型付けが共通に読む、構文の上の関数と述語である（設計書 01-12「型の情報を付けた表層の構文と型付け」）。
パターンは核のパターン `Pat` へ写し、辞書の根拠は核の値へ写す。型は篩付きの型の判断の `Ty` である。
-/

namespace Benitoite.Release.Refinement.Surface

/-! ## 演算子 -/

def Operator.typeArgs : Operator → Ty → List Ty
  | .binary .eq, t => [t]
  | .binary .ne, t => [t]
  | _, _ => []

/-- 基本型だけを演算子の型の集まりに数える。篩付きの型は演算子の型付けの前に基の型へ戻す。 -/
def Operator.allowed : Operator → Ty → Bool
  | .binary .add, .base .string => true
  | .binary .add, .base b | .binary .sub, .base b | .binary .mul, .base b =>
      Benitoite.Release.arithmeticB (.base b)
  | .binary .div, .base b => Benitoite.Release.divisionB (.base b)
  | .binary .intDiv, .base b | .binary .mod, .base b => Benitoite.Release.integerArithmeticB (.base b)
  | .binary .lt, .base b | .binary .le, .base b | .binary .gt, .base b | .binary .ge, .base b =>
      Benitoite.Release.orderedB (.base b)
  | .binary .eq, _ | .binary .ne, _ => true
  | .neg, .base b => Benitoite.Release.negationB (.base b)
  | _, _ => false

/-! ## リテラルとパターン -/

def Literal.toConst : Literal → Const
  | .integer n => .integer n.toValue
  | .float x => .float64 x.toBits
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

/-- 核のパターンの定数の形。パターンの範囲の両端は Integer と Character だけが型付く（`P_RangeInt`・`P_RangeChar`）。 -/
def _root_.Benitoite.Release.Refinement.Const.legacy : Const → Benitoite.Release.Const
  | .integer n => .integer n
  | .float64 bits => .float (Float.ofBits bits)
  | .string s => .string s
  | .character c => .character c
  | .boolean b => .boolean b
  | .unit => .unit
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

/-- 書いた順の位置と値を同時に辿る。範囲外・書かなかった位置は none。 -/
def fieldAt {α : Type} (i : Nat) : List Nat → List α → Option α
  | j :: js, v :: vs => if i = j then some v else fieldAt i js vs
  | _, _ => none

/-- 宣言の順に並べ、書かなかった位置を fallback で埋める。 -/
def recordFields {α : Type} (n : Nat) (positions : List Nat) (values : List α)
    (fallback : α) : List α :=
  (List.range n).map fun i => (fieldAt i positions values).getD fallback

/-- 更新は書き換える位置を束縛せず、残す位置だけを宣言の順に束縛する。 -/
def recordUpdatePattern (c : ConName) (n : Nat) (positions : List Nat) : Pat :=
  .con c ((List.range n).map fun i => if i ∈ positions then .wild else .var)

/-- 取得する位置だけを束縛する。 -/
def accessorPattern (c : ConName) (n k : Nat) : Pat :=
  .con c ((List.range n).map fun i => if i = k then .var else .wild)

mutual
  /-- 01-12 の pi'。修飾を除き、-n を負の定数にする。 -/
  def Pattern.toCore : Pattern → Pat
    | .wild => .wild
    | .var => .var
    | .integer n => .const (.integer n.toValue)
    | .negInt n => .const (.integer n.negValue)
    | .string s => .const (.string s)
    | .character c => .const (.character c)
    | .boolean b => .const (.boolean b)
    | .unit => .const .unit
    | .range lo hi => .range lo.legacy hi.legacy
    | .list before rest after => .list (Pattern.toCoreList before) rest (Pattern.toCoreList after)
    | .con _ c ps => .con c (Pattern.toCoreList ps)
    | .record c n positions ps =>
        .con c (recordFields n positions (Pattern.toCoreList ps) .wild)

  def Pattern.toCoreList : List Pattern → List Pat
    | [] => []
    | p :: ps => p.toCore :: Pattern.toCoreList ps
end

/-! 01-05 の範囲の大小とリストの形。両端の種類は核の `PatTy` が検査する。 -/
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

def Alternative.toCore (alt : Alternative) : Alt := ⟨alt.pat.toCore, alt.slots⟩

def Alternative.toCoreList (alts : List Alternative) : List Alt := alts.map Alternative.toCore

def Alternative.Valid (alts : List Alternative) : Prop := ∀ alt ∈ alts, alt.pat.Valid

def Pattern.binders (p : Pattern) : Nat := p.toCore.binders

/-- 変数と _ の束縛は別の構文を使う。 -/
def Pattern.Nontrivial : Pattern → Prop
  | .wild | .var => False
  | _ => True

/-! ## 辞書 -/

/-- 宣言順の辞書番号を、継続と値引数の後の de Bruijn 番号へ写す。 -/
def ClauseScope.slot (s : ClauseScope) (i : Nat) : Nat :=
  1 + s.arity + (s.dictCount - 1 - i)

mutual
  /-- V-Dict・受け取った辞書・V-Super。計算も let も作らない。 -/
  def DictEv.toVal : DictEv → Val
    | .impl i ts ds => .dict i ts (DictEv.toValList ds)
    | .local j => .var j
    | .clause s i depth => .var (depth + s.slot i)
    | .super d s => .super d.toVal s

  def DictEv.toValList : List DictEv → List Val
    | [] => []
    | d :: ds => d.toVal :: DictEv.toValList ds
end

/-! ## 補間の書式 -/

namespace FormatSpec

/-- 型とは独立した、空指定・範囲・併用の条件。字句の検査はこの定義の前に行う。 -/
def SyntaxValid (s : FormatSpec) : Prop :=
  s ≠ {} ∧
  (match s.width with | none => True | some w => 1 ≤ w ∧ w ≤ 65535) ∧
  (match s.precision with | none => True | some p => p ≤ 28 ∧ s.kind = .f) ∧
  (s.align ≠ .default → s.width.isSome = true) ∧
  (s.zero = true → s.width.isSome = true ∧ s.align = .default) ∧
  (s.alternate = true → s.kind = .b ∨ s.kind = .o ∨ s.kind = .x ∨ s.kind = .upperX)

instance (s : FormatSpec) : Decidable s.SyntaxValid := by
  unfold SyntaxValid
  cases s.width <;> cases s.precision <;> infer_instance

/-- Byte を含む八つの整数型。 -/
def IntegerType : Ty → Prop
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .byte | .base .unsignedInteger16 | .base .unsignedInteger32
  | .base .unsignedInteger64 => True
  | _ => False

/-- f が使える三型。 -/
def FractionalType : Ty → Prop
  | .base .float | .base .float32 | .base .decimal => True
  | _ => False

/-- 書式付き補間に許す閉じた14型。 -/
def SupportedType : Ty → Prop
  | .base .integer | .base .integer8 | .base .integer16 | .base .integer32
  | .base .byte | .base .unsignedInteger16 | .base .unsignedInteger32
  | .base .unsignedInteger64 | .base .float | .base .float32 | .base .decimal
  | .base .string | .base .character | .base .boolean => True
  | _ => False

/-- 種類による型の制限と、符号・ゼロ埋めを数に限る条件。 -/
def Compatible (t : Ty) (s : FormatSpec) : Prop :=
  SupportedType t ∧
  (match s.kind with
   | .default => True
   | .d | .b | .o | .x | .upperX => IntegerType t
   | .f => FractionalType t
   | .s => match t with | .base .string => True | _ => False
   | .c => match t with | .base .character => True | _ => False) ∧
  ((s.sign = .plus ∨ s.zero = true) → IntegerType t ∨ FractionalType t)

/-- 表層の型付けと検査が共通に使う書式の条件。 -/
def Valid (t : Ty) (s : FormatSpec) : Prop := s.SyntaxValid ∧ s.Compatible t

def kindCode : FormatKind → Integer64Value
  | .default => ⟨0, by decide⟩
  | .d => ⟨1, by decide⟩
  | .b => ⟨2, by decide⟩
  | .o => ⟨3, by decide⟩
  | .x => ⟨4, by decide⟩
  | .upperX => ⟨5, by decide⟩
  | .f => ⟨6, by decide⟩
  | .s => ⟨7, by decide⟩
  | .c => ⟨8, by decide⟩

def alignCode : FormatAlign → Integer64Value
  | .default => ⟨0, by decide⟩
  | .left => ⟨1, by decide⟩
  | .right => ⟨2, by decide⟩
  | .center => ⟨3, by decide⟩

def signCode : FormatSign → Integer64Value
  | .default => ⟨0, by decide⟩
  | .plus => ⟨1, by decide⟩

/-- 幅の省略は0で表す。 -/
def widthCode (s : FormatSpec) (h : s.SyntaxValid) : Integer64Value :=
  ⟨Int.ofNat (s.width.getD 0), by
    have hw := h.2.1
    cases he : s.width with
    | none => simp [min64, max64]
    | some w => simp only [he] at hw; simp [min64, max64]; omega⟩

/-- 精度の省略は-1で表す。 -/
def precisionCode (s : FormatSpec) (h : s.SyntaxValid) : Integer64Value :=
  ⟨match s.precision with | none => -1 | some p => Int.ofNat p, by
    have hp := h.2.2.1
    cases he : s.precision with
    | none => simp [min64, max64]
    | some p => simp only [he] at hp; simp [min64, max64]; omega⟩

/-- value の後へ渡す七定数。 -/
def constants (s : FormatSpec) (h : s.SyntaxValid) : List Const :=
  [.integer (kindCode s.kind), .integer (alignCode s.align), .integer (signCode s.sign),
   .boolean s.alternate, .boolean s.zero, .integer (s.widthCode h), .integer (s.precisionCode h)]

/-- 妥当な解析済み書式を七つの定数値へ写す。不正な注記の空列は型判断から到達しない。 -/
def arguments (s : FormatSpec) : List Val :=
  if h : s.SyntaxValid then (s.constants h).map Val.const else []

end FormatSpec

/-- 補間の式の部分の型。書式なしの String の式は String、変換する式は部分が持つ型である。 -/
def InterpPart.exprTypes : List InterpPart → List Ty
  | [] => []
  | .text _ :: ps => exprTypes ps
  | .stringExpr :: ps => .base .string :: exprTypes ps
  | .converted t :: ps | .formatted t _ :: ps => t :: exprTypes ps

/-- 01-06「演算子の型付け」の補間に許す型。 -/
def InterpPart.Allowed : List InterpPart → Prop
  | [] => True
  | .converted t :: ps =>
      (t = .base .integer ∨ t = .base .float ∨ t = .base .character ∨
        t = .base .boolean ∨ t = .base .byte ∨ t = .base .decimal ∨
        t = .base .integer8 ∨ t = .base .integer16 ∨ t = .base .integer32 ∨
        t = .base .unsignedInteger16 ∨ t = .base .unsignedInteger32 ∨
        t = .base .unsignedInteger64 ∨ t = .base .float32) ∧ Allowed ps
  | .formatted t s :: ps => s.Valid t ∧ Allowed ps
  | _ :: ps => Allowed ps

/-! ## 呼出しの契約 -/

/-- 位置フィールドの契約名。宣言中の位置から arg1, arg2, … を作る。 -/
def positionalNames (n : Nat) : List String :=
  (List.range n).map fun i => "arg" ++ toString (i + 1)

/-- 辞書の内部名。% は表層の識別子に含まれない（設計書 01-01「識別子」）。 -/
def internalNames (n : Nat) : List String :=
  (List.range n).map fun i => "%dict" ++ toString (i + 1)

/-- ラベルはソース順で位置と対応する。通常呼び出しの位置指定は一引数だけである。
パイプ挿入は位置 0 を先に占め、明示引数からの重複も Perm で排除する。`arity` は依存列の引数の数である。 -/
def CallOk (names : List String) (arity : Nat) (inserted : Bool)
    (labels : List (Option String)) (positions : List Nat) : Prop :=
  names.length = arity ∧ names.Nodup ∧ labels.length = positions.length ∧
    ((if inserted then [0] else []) ++ positions).Perm (List.range arity) ∧
    ((labels = [] ∧ positions = []) ∨
      (inserted = false ∧ arity = 1 ∧ labels = [none] ∧ positions = [0]) ∨
      (labels = positions.map (fun i => names[i]?) ∧
        ∀ label ∈ labels, label.isSome = true))

/-! ## 穴・分岐・節 -/

/-- 穴の型だけをソース順に集める。 -/
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

/-- ガードなしの分岐の全選択肢だけを網羅性に数える。 -/
def Arms.unguardedPatterns : Arms → List Pat
  | .nil => []
  | .cons alts none _ rest => (Alternative.toCoreList alts).map Alt.pat ++ rest.unguardedPatterns
  | .cons _ (some _) _ rest => rest.unguardedPatterns

/-- handled は操作名だけを読む。本体を捨てた節の並び。 -/
def Clauses.skeleton : Clauses → List Clause
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

/-! ## 宣言 -/

/-- 01-12「型クラス」: 制約ごとの辞書の引数を値の引数の前に置く。 -/
def FunDecl.dictTys (d : FunDecl) : List Ty :=
  d.dictParams.map fun p => .dict p.1 (.tvar p.2)

/-- コアの引数名は内部辞書と利用者の契約をこの順に持つ。 -/
def FunDecl.coreNames (d : FunDecl) : List String :=
  internalNames d.dictParams.length ++ d.names

/-- コアの引数の型。辞書の引数は値の引数の前にあり、値の引数の型は辞書の引数の下で格納されている。 -/
def FunDecl.coreParams (d : FunDecl) : List Ty :=
  d.dictTys ++ d.params

/-- コアの依存列。値の引数と結果は前の引数を値変数として参照できる。 -/
def FunDecl.tel (d : FunDecl) : Tel :=
  signatureTel d.coreNames d.coreParams d.ret d.eff

def ImplSig.dictTys (id : ImplSig) : List Ty :=
  id.dictParams.map fun p => .dict p.1 (.tvar p.2)

def Declarations.constructorNames (D : Declarations) (c : ConName) (cd : ConDecl) : List String :=
  (D.conFields c).getD (positionalNames cd.args.length)

/-- 型の宣言の照合に使う核のプログラム。関数の定義と実装の本体は持たない（型の判断はこれらを読まない）。 -/
def Declarations.core (D : Declarations) : Refinement.Program where
  defs := fun _ => none
  cons := D.cons
  ops := D.ops
  effects := D.effects
  classes := D.classes
  impls := fun _ => none
  externals := D.externals
  dataInfo := D.dataInfo

/-- フィールドを取り出す関数の基の結果型。引数 `value` の下へ移した欄の型である。 -/
def accessorBase (cd : ConDecl) (k : Nat) : Ty := ((cd.args[k]?).getD (.base .unit)).shiftV 1 0

/-- 観測できる欄。欄の事実 `FieldLink` は整数の欄の値と List の欄の長さを結ぶ。 -/
def accessorObserved (cd : ConDecl) (k : Nat) : Bool :=
  (accessorBase cd k).sort? == some .integer || (accessorBase cd k).sort? == some .list

/-- 欄の観測の sort。List の欄は List、ほかは整数である。 -/
def accessorSort (cd : ConDecl) (k : Nat) : «Sort» :=
  if (accessorBase cd k).sort? = some .list then .list else .integer

/-- 欄の観測を比べる測度。List の欄は長さ、整数の欄は値そのものを比べる。 -/
def accessorMeasure (cd : ConDecl) (k : Nat) : Option Measure :=
  if (accessorBase cd k).sort? = some .list then some .listLength else none

/-- 測度を通した項（`viewTerm` と同じ形）。 -/
def accessorView (m : Option Measure) (t : Term) : Term :=
  match m with | none => t | some m => .measure m t

/-- 欄の観測の参照。 -/
def accessorRef (c : ConName) (cd : ConDecl) (k : Nat) : FieldRef := ⟨cd.data, c, k, accessorSort cd k⟩

/-- 取り出しの関数の結果の篩。結果（番号 0）の観測が、引数（番号 1）の欄の観測に等しい。 -/
def accessorPred (c : ConName) (cd : ConDecl) (k : Nat) : Pred :=
  .eq (accessorView (accessorMeasure cd k) (.var 0))
    (accessorView (accessorMeasure cd k) (.field (accessorRef c cd k) (.var 1)))

/-- フィールドを取り出す関数の結果型。観測できる欄では `accessorPred` の篩を持つ（整数の欄は値の等号、List の欄は
長さの等号）。これにより欄の依存を写した record 全体の篩の事実が、射影の結果へ流れる。 -/
def accessorRet (c : ConName) (cd : ConDecl) (k : Nat) : Ty :=
  if accessorObserved cd k then .refined (accessorBase cd k) (accessorPred c cd k)
  else accessorBase cd k

/-- 01-05 の型パラメータは無制約。番号は構成子の宣言と同じ。 -/
def accessorDecl (c : ConName) (cd : ConDecl) (k : Nat) : FunDecl :=
  { tparams := List.replicate cd.ntys TypeCtx.valueParam, neffs := 0,
    names := ["value"], params := [.data cd.data ((List.range cd.ntys).map Ty.tvar)],
    ret := accessorRet c cd k, eff := Eff.empty }

/-! ## record の欄の依存 -/

/-- 欄の型の篩を除いた基の型。核の構成子の宣言はこの型を持つ。 -/
def fieldBase : Ty → Ty
  | .refined a _ => fieldBase a
  | a => a

/-- 欄の型の篩の列（外側が後）。番号 0 は欄自身、番号 j+1 は j 個前の欄である。 -/
def fieldPreds : Ty → List Pred
  | .refined a p => fieldPreds a ++ [p]
  | _ => []

/-- 欄 i の篩を record 全体の値（番号 0）の欄の観測へ移す対応。i 個以下の番号は欄の観測、それより外は record の外の
変数である。欄の型が sort を持たなければ観測できない。 -/
def RecordDecl.fieldEnv (r : RecordDecl) (c : ConName) (i : Nat) : ObservationEnv := fun k =>
  if k ≤ i then
    match r.fields[i - k]? with
    | some (_, t) => (fieldBase t).sort?.map fun s => .field ⟨r.data, c, i - k, s⟩ (.var 0)
    | none => none
  else some (.var (k - i))

/-- 欄の依存を写した record 全体の篩。 -/
def RecordDecl.refinement (r : RecordDecl) (c : ConName) : Pred :=
  ((List.range r.fields.length).flatMap fun i =>
    match r.fields[i]? with
    | some (_, t) => (fieldPreds t).map (predBind (r.fieldEnv c i))
    | none => []).foldr .and .truth

/-- 核の構成子の宣言。欄の型は篩を除いた基の型である。 -/
def RecordDecl.conDecl (r : RecordDecl) : ConDecl := ⟨r.data, r.ntys, r.fields.map fun f => fieldBase f.2⟩

/-- 篩の外側の変数を k 個の束縛の下へ移す（篩の self は移さない）。`Ty.shiftV` の篩の欄と同じ。 -/
def liftRef (k : Nat) (p : Pred) : Pred := predBind (fun i => some (.var (if i < 1 then i else i + k))) p

theorem shiftV_refined (k : Nat) (a : Ty) (p : Pred) :
    (Ty.refined a p).shiftV k 0 = .refined (a.shiftV k 0) (liftRef k p) := rfl

/-- 01-12「構成子の判定の関数」: 判定の関数の結果の篩。結果（番号 0）が true であることと、引数（番号 1）の構成子が c で
あることが一致する（`Boolean{r | r = true ⇔ Pred.constructorIs value C}` を or・and・not で表す）。 -/
def testerPred (c : ConName) : Pred :=
  .or (.and (.compare .boolean .eq (.var 0) (.boolean true)) (.constructorIs (.var 1) c))
    (.and (.not (.compare .boolean .eq (.var 0) (.boolean true))) (.not (.constructorIs (.var 1) c)))

/-- 構成子 c の判定の関数 `isC[T…](value: D[T…]) -> Boolean{…}` の宣言。 -/
def testerDecl (c : ConName) (cd : ConDecl) : FunDecl :=
  { tparams := List.replicate cd.ntys TypeCtx.valueParam, neffs := 0,
    names := ["value"], params := [.data cd.data ((List.range cd.ntys).map Ty.tvar)],
    ret := .refined (.base .boolean) (testerPred c), eff := Eff.empty }

/-- 通常の定義を先に引き、次にフィールドを取り出す関数、最後に構成子の判定の関数を引く。宣言と脱糖後の Σ が同じ
優先順を使う。判定の関数と同名の定義・取り出しの関数は整形式が拒む。 -/
def Program.lookupFun {α : Type} (p : Program) (ordinary : Def → α)
    (accessor : ConName → ConDecl → Nat → α) (tester : ConName → ConDecl → α) (f : FunName) : Option α :=
  match p.defs f with
  | some d => some (ordinary d)
  | none => match p.accessors f with
      | some (c, k) => (p.cons c).map fun cd => accessor c cd k
      | none => match p.testers f with
          | none => none
          | some c => (p.cons c).map fun cd => tester c cd

/-- 本体ごとの view を渡す宣言の表。 -/
def Program.declarationsFor (p : Program) (view : CoverageView) : Declarations :=
  { view := view, funs := p.lookupFun Def.toFunDecl accessorDecl testerDecl,
    cons := p.cons, conFields := p.conFields, ops := p.ops, effects := p.effects,
    classes := p.classes, impls := fun i => (p.impls i).map ImplDecl.toImplSig,
    aliases := p.aliases, records := p.records, testers := p.testers,
    externals := p.externals, dataInfo := p.dataInfo }

def Program.declarations (p : Program) : Declarations := p.declarationsFor closedView

end Benitoite.Release.Refinement.Surface
