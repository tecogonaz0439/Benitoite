import Benitoite.Interval.Environment
import Benitoite.Interval.Arithmetic

/-!
# 区間解析の本体の列挙と局所の演算

全表層構文から別本体を取り出す。
捕捉境界の整数の事実を捨て、束縛の位置だけを保つ
（設計書 01-12「区間解析の局所環境と本体境界」）。
整数除算と剰余の警告は、到達した正常引数についてだけ失敗を主張する
（設計書 01-12「区間解析のInteger64除算と剰余」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- 関数・定数・捕捉境界ごとの入口。 -/
inductive BodyKind where
  | function | constant | lambda | lazy | clause
  deriving DecidableEq, Repr

/-- 本体の構文と初期環境。式の識別番号はこの列挙と別に付ける。 -/
structure BodySeed where
  kind : BodyKind
  body : Block
  initial : AbstractEnv

/-- 新しい本体では、引数と捕捉値の整数の区間をすべて Top にする。 -/
def startBody (kind : BodyKind) (params : List (Option Ty))
    (captures : AbstractEnv) (body : Block) : BodySeed :=
  ⟨kind, body, forget (extendValues captures params)⟩

/-- 節の型パラメータの追加で型の同一性を推測しない。専用位置は残す。 -/
def untypedCaptures (env : AbstractEnv) : AbstractEnv :=
  { env with locals := env.locals.map fun slot => match slot with
    | .integer _ => .integer top
    | .integerKind kind _ => .integerKind kind (top kind)
    | .unknown _ => .unknown none
    | .builder kind => .builder kind
    | .unavailable => .unavailable, ranges := env.ranges.forget }

mutual
  /-- 全53構成子を列挙する。未対応の部分木にも入り、解析の伝播とは区別する。 -/
  def discoverBodies (env : AbstractEnv) : Expr → List BodySeed
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit => []
    -- 埋め込み本体は親で解析する。中の捕捉境界だけを別本体として残す。
    | .constE _ expr => discoverBodies (clearLocals env) expr
    | .paren expr | .neg _ expr | .not expr | .returnE _ expr => discoverBodies env expr
    | .block body => discoverBlock env body
    | .binary _ _ lhs rhs | .and lhs rhs | .or lhs rhs =>
        discoverBodies env lhs ++ discoverBodies env rhs
    | .ite cond yes no =>
        discoverBodies env cond ++ discoverBlock env yes ++ discoverBlock env no
    | .elseIf cond yes no =>
        discoverBodies env cond ++ discoverBlock env yes ++ discoverBodies env no
    | .ifOnly cond yes => discoverBodies env cond ++ discoverBlock env yes
    | .matchE _ scrutinee arms => discoverBodies env scrutinee ++ discoverArms env arms
    | .lam _ params _ _ body =>
        let seed := startBody .lambda (params.map some) env body
        seed :: discoverBlock seed.initial body
    | .lazyE body =>
        let seed := startBody .lazy [] env body
        seed :: discoverBlock seed.initial body
    | .handleFail _ _ body clause =>
        -- 非再開節の先頭は利用不能な継続位置、その次がエラーである。
        let initial := extend (extend (untypedCaptures env) (.unknown none)) .unavailable
        let seed := startBody .clause [] initial clause
        discoverBlock (forget env) body ++ seed :: discoverBlock seed.initial clause
    | .handleE body clauses =>
        discoverBlock (forget env) body ++ discoverClauses env clauses
    | .withE owner expr body =>
        discoverBodies (forget env) expr ++
          discoverBlock (extend (forget env) (topSlot (some (.opaque owner)))) body
    | .tryResult _ _ _ expr | .tryOption _ _ _ expr | .resume _ expr =>
        discoverBodies (forget env) expr
    | .tryResultDie _ _ _ _ _ _ expr message | .tryOptionDie _ _ _ _ expr message =>
        discoverBodies (forget env) expr ++ discoverOptional (forget env) message
    | .builderOp _ _ args _ | .conCall _ _ args | .record _ _ _ args | .list _ args =>
        discoverExprs (forget env) args
    | .recordUpdate _ _ _ _ base args =>
        discoverBodies (forget env) base ++ discoverExprs (forget env) args
    | .call callee _ _ args =>
        discoverBodies (forget env) callee ++ discoverExprs (forget env) args
    | .pipe lhs rhs => discoverBodies (forget env) lhs ++ discoverBodies (forget env) rhs
    | .partialCall callee _ args _ _ =>
        discoverBodies (forget env) callee ++ discoverHoles (forget env) args
    | .partialCon _ _ args => discoverHoles (forget env) args
    | .listSpread _ concat before spread after =>
        discoverBodies (forget env) concat ++ discoverExprs (forget env) before ++
          discoverBodies (forget env) spread ++ discoverExprs (forget env) after
    | .interpolation _ args converters =>
        discoverExprs (forget env) args ++ discoverExprs (forget env) converters

  /-- ソース順の通常引数。 -/
  def discoverExprs (env : AbstractEnv) : Exprs → List BodySeed
    | .nil => []
    | .cons expr rest => discoverBodies env expr ++ discoverExprs env rest

  /-- 固定式から本体を探すとき、穴の仮引数の位置を追加しない。 -/
  def discoverHoles (env : AbstractEnv) : HoleArgs → List BodySeed
    | .nil => []
    | .expr _ _ expr rest => discoverBodies env expr ++ discoverHoles env rest
    | .hole _ _ _ rest => discoverHoles env rest

  /-- 右辺の後で通常・パターン・専用位置を追加し、discard は追加しない。 -/
  def discoverBlock (env : AbstractEnv) : Block → List BodySeed
    | .empty => []
    | .builderBind kind rest => discoverBlock (extend env (.builder kind)) rest
    | .last expr | .lastBind _ _ expr | .lastDiscard expr | .lastPat _ _ _ expr =>
        discoverBodies env expr
    | .bind _ type expr rest =>
        discoverBodies env expr ++ discoverBlock (extend env (topSlot (some type))) rest
    | .discard expr rest | .seq expr rest => discoverBodies env expr ++ discoverBlock env rest
    | .bindPat _ pattern type expr rest =>
        discoverBodies env expr ++ discoverBlock (extendPattern env pattern type) rest

  /-- 型検査済みの選択肢は同数の束縛を持つ。guard と本体は共通の局所位置を使う。 -/
  def discoverArms (env : AbstractEnv) : Arms → List BodySeed
    | .nil => []
    | .cons alts guard body rest =>
        let count := (alts.head?.map fun alt => alt.slots.length).getD 0
        let inner := { env with locals := List.replicate count (.unknown none) ++ env.locals }
        discoverOptional inner guard ++ discoverBlock inner body ++ discoverArms env rest

  /-- 継続が番号0、値引数の逆順、その後に辞書の逆順、最後が捕捉位置である。 -/
  def discoverClauses (env : AbstractEnv) : Clauses → List BodySeed
    | .nil => []
    | .cons _ arity _ body rest dictCount =>
        let seed := startBody .clause (List.replicate (dictCount + arity + 1) none)
          (untypedCaptures env) body
        seed :: (discoverBlock seed.initial body ++ discoverClauses env rest)

  /-- guard と die の任意の式も、その場の位置で辿る。 -/
  def discoverOptional (env : AbstractEnv) : Option Expr → List BodySeed
    | none => []
    | some expr => discoverBodies env expr
end

/-- 関数は他の本体の局所環境を受け取らず、引数を Top から開始する。 -/
def functionBodies (params : List Ty) (body : Block) : List BodySeed :=
  let seed := startBody .function (params.map some) (AbstractEnv.ofLocals []) body
  seed :: discoverBlock seed.initial body

/-- 忘却した環境の整数の lookup は、位置や元の狭さによらず Top になる。 -/
theorem integerAt_forget (env : AbstractEnv) (index : Nat) :
    integerAt (forget env) index = top := by
  rcases env with ⟨slots, standards, apiAt, ranges⟩
  change integerAt (⟨slots.map forgetSlot, standards, apiAt, ranges.forget⟩) index = top
  induction slots generalizing index with
  | nil => rfl
  | cons slot rest ih =>
      cases index with
      | zero => cases slot <;> rfl
      | succ index => exact ih index

/-- 引数と捕捉値のどちらにも、外側の整数の狭さを伝えない。 -/
theorem startBody_top (kind params captures body index) :
    integerAt (startBody kind params captures body).initial index = top :=
  integerAt_forget _ _

/-- 整数除算・剰余の局所規則。子の警告列との合成や式全体の解析は行わない。 -/
def analyzeDivMod (key : OperationKey) (op : BinOp)
    (left right : IntegerApprox) : AnalysisResult :=
  let approx := divModApprox left right
  ⟨fun value => match value with
      | .integer integer => Mem integer.toInt approx.normal
      | _ => False,
    approx.mayFail,
    if divModAlwaysZero op left.normal right.normal then
      [⟨key, .binary op (.base .integer), .zeroDivisor⟩]
    else []⟩

/-- 正常な二引数が子の近似に属すれば、局所規則はどの正常な整数結果も失わない。 -/
theorem analyzeDivMod_normal_sound {key op left right} {a b value : Integer64Value}
    (ha : Mem a.toInt left.normal) (hb : Mem b.toInt right.normal) :
    (analyzeDivMod key op left right).normal (.integer value) :=
  divMod_normal_sound ha hb

/-- 局所の警告は、到達した正常引数が子の区間に属する場合にその原因で拒否する。
キーだけから子の区間との対応を推測せず、全体の解析との合成時にこの対応を渡す。 -/
theorem analyzeDivMod_warning_sound {env input outcome trace key op left right warning event}
    (eval : EvalPartial env input outcome trace)
    (warned : warning ∈ (analyzeDivMod key op left right).warnings)
    (reached : Reached trace warning event)
    (arguments : ∀ a b, event.arguments = [.integer a, .integer b] →
      Mem a.toInt left.normal ∧ Mem b.toInt right.normal) :
    event.result = .rejected warning.cause.toFailure := by
  change warning ∈ (if divModAlwaysZero op left.normal right.normal then
    [⟨key, .binary op (.base .integer), .zeroDivisor⟩] else []) at warned
  split at warned
  · rename_i always
    simp only [List.mem_singleton] at warned
    subst warning
    obtain ⟨a, b, args, result⟩ := eval_divMod_event eval reached.1 reached.2.2
      (divMod_always_zero_target always)
    have modeled := arguments a b args
    exact result.trans (divMod_always_zero_sound modeled.1 modeled.2 always)
  · contradiction

-- 一点0だけを警告し、0を含むだけの区間・実数の /・子Bottomには警告を作らない。
-- 期待する原因と演算の種類は解析関数から生成しない。
example (key : OperationKey) :
    ((analyzeDivMod key .intDiv ⟨top, true⟩ ⟨normalize 0 0, false⟩).warnings.map
      fun warning => (warning.key, warning.operation, warning.cause)) =
        [(key, .binary .intDiv (.base .integer), .zeroDivisor)] ∧
    (analyzeDivMod key .mod ⟨top, false⟩ ⟨normalize 0 0, false⟩).warnings.length = 1 ∧
    (analyzeDivMod key .intDiv ⟨top, false⟩ ⟨normalize (-1) 1, false⟩).warnings = [] ∧
    (analyzeDivMod key .div ⟨top, false⟩ ⟨normalize 0 0, false⟩).warnings = [] ∧
    (analyzeDivMod key .intDiv ⟨.bottom, true⟩ ⟨normalize 0 0, false⟩).warnings = [] ∧
    (analyzeDivMod key .mod ⟨normalize 1 1, false⟩ ⟨.bottom, true⟩).warnings = [] ∧
    (divModApprox ⟨.bottom, false⟩ ⟨top, true⟩).mayFail = false ∧
    (divModApprox ⟨top, false⟩ ⟨.bottom, true⟩).mayFail = true := by
  repeat' constructor

-- 同じ除数0の規則を商と剰余で通し、正常な二引数を得た演算だけを記録する。
example (env : ConcreteEnv) (key : OperationKey) (op : BinOp)
    (target : IntegerDivisionOp op) :
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let event : EvalEvent := ⟨key, .binary op (.base .integer),
      [.integer ⟨1, by decide⟩, .integer ⟨0, by decide⟩], .rejected .zeroDivisor⟩
    EvalPartial env ⟨.binary op (.base .integer) one zero, .base .integer, key⟩
      (.failed .zeroDivisor) [event] ∧
    Reached [event] ⟨key, .binary op (.base .integer), .zeroDivisor⟩ event := by
  dsimp only
  constructor
  · simpa [checkedDivMod, target, OperationResult.outcome,
      Integer64Literal.toValue, Integer64Value.toInt] using
      (EvalPartial.divMod env key op _ _ _ _ [] [] target
        (.integer env _ ⟨1, by decide⟩) (.integer env _ ⟨0, by decide⟩))
  · exact ⟨by simp, rfl, rfl⟩

-- 左右の子の失敗とreturnは、除数が0でも親の演算に到達させない。
example (env : ConcreteEnv) (key : OperationKey) (op : BinOp)
    (target : IntegerDivisionOp op) :
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let unknown : Expr := .funName "Example.unknown" [] []
    EvalPartial env ⟨.binary op (.base .integer) unknown zero, .base .integer, key⟩
      (.failed .unknown) [] ∧
    EvalPartial env ⟨.binary op (.base .integer) one unknown, .base .integer, key⟩
      (.failed .unknown) [] ∧
    EvalPartial env ⟨.binary op (.base .integer)
      (.returnE (.base .integer) one) zero, .base .integer, key⟩
      (.returned (.integer ⟨1, by decide⟩)) [] ∧
    EvalPartial env ⟨.binary op (.base .integer) one
      (.returnE (.base .integer) zero), .base .integer, key⟩
      (.returned (.integer ⟨0, by decide⟩)) [] := by
  dsimp only
  refine ⟨?_, ?_, ?_, ?_⟩
  · exact .divModLeftAbrupt env key op _ _ _ [] target
      (.unknownFailed _ _ (Or.inl (Or.inr rfl))) trivial
  · exact .divModRightAbrupt env key op _ _ _ _ [] [] target
      (.integer _ _ _) (.unknownFailed _ _ (Or.inl (Or.inr rfl))) trivial
  · exact .divModLeftAbrupt env key op _ _ _ [] target
      (.returnE env (childKey key []) (.base .integer) _ (.base .integer) _ []
        (.integer _ _ _)) trivial
  · exact .divModRightAbrupt env key op _ _ _ _ [] [] target
      (.integer _ _ _) (.returnE env _ (.base .integer) _ (.base .integer) _ []
        (.integer _ _ _)) trivial

-- (max64+1) intDiv 0 では、先に失敗する加算だけが記録される。
-- 親の除数0の警告も、子のBottomで抑制される。
example (env : ConcreteEnv) :
    let parent : OperationKey := ⟨"Example.divisionChild", 0⟩
    let child : OperationKey := ⟨"Example.divisionChild", 1⟩
    let maximum : Expr := .literal (.integer ⟨9223372036854775807, by decide⟩)
    let one : Expr := .literal (.integer ⟨1, by decide⟩)
    let zero : Expr := .literal (.integer ⟨0, by decide⟩)
    let trace : EvalTrace := [⟨child, .binary .add (.base .integer),
      [.integer ⟨max64, by constructor <;> decide⟩, .integer ⟨1, by decide⟩],
      .rejected .overflow⟩]
    let left := addApprox ⟨normalize max64 max64, false⟩ ⟨normalize 1 1, false⟩
    EvalPartial env ⟨.binary .intDiv (.base .integer)
      (.binary .add (.base .integer) maximum one) zero, .base .integer, parent⟩
      (.failed .overflow) trace ∧
    (∀ event ∈ trace, event.key ≠ parent) ∧
    (analyzeDivMod parent .intDiv left ⟨normalize 0 0, false⟩).warnings = [] := by
  dsimp only
  refine ⟨?_, ?_, ?_⟩
  · apply EvalPartial.divModLeftAbrupt
    · exact Or.inl rfl
    · exact EvalPartial.add env ⟨"Example.divisionChild", 1⟩
        _ _ _ _ [] []
        (.integer _ _ _) (.integer _ _ _)
    · trivial
  · simp [OperationKey.mk.injEq]
  · rfl

-- 捕捉した一点は、ラムダ・lazy・節の入口で全値域に戻る。
example :
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize 7 7)])
    (discoverBodies env (.lam [] [] (.base .unit) Eff.empty (.last (.local 0)))).map
      (fun seed => integerAt seed.initial 0) = [top] ∧
    (discoverBodies env (.lazyE (.last (.local 0)))).map
      (fun seed => integerAt seed.initial 0) = [top] ∧
    (discoverBodies env (.constE (.base .unit)
      (.lam [] [] (.base .unit) Eff.empty (.last .unit)))).map
      (fun seed => seed.initial.locals.length) = [0] ∧
    (discoverClauses env (.cons (.user "Example.op") 1 0 (.last (.local 2)) .nil 1)).map
      (fun seed => (seed.initial.locals.length, integerAt seed.initial 3)) = [(4, top)] := by
  exact ⟨rfl, rfl, rfl, rfl⟩

-- 未対応の引数・穴・guardにも本体があり得る。穴は固定式の番号をずらさない。
example :
    let env : AbstractEnv := (AbstractEnv.ofLocals [.integer (normalize 2 2)])
    let lazyExpr : Expr := .lazyE (.last (.local 0))
    (discoverBodies env (.partialCall (.funName "Example.f" [] []) []
      (.hole none 0 (.base .integer) (.expr none 1 lazyExpr .nil))
      (.base .unit) Eff.empty)).map (fun seed => seed.initial.locals.length) = [1] ∧
    (discoverArms env (.cons [⟨.var, [0]⟩] (some lazyExpr)
      (.last lazyExpr) .nil)).map (fun seed => seed.initial.locals.length) = [2, 2] := by
  exact ⟨rfl, rfl⟩

-- 右辺には追加前の位置が見え、shadow は一位置、wildcard は零位置だけを増やす。
-- Reference の内容を整数の局所位置として登録しない。
example :
    let expr : Expr := .lazyE (.last (.local 0))
    let body : Block := .builderBind .string
      (.bind .shadow (.base .integer) expr
        (.bindPat .bind .wild (.base .integer) expr
          (.discard expr (.last expr))))
    (discoverBlock (AbstractEnv.ofLocals [.unknown (some (.reference (.base .integer)))]) body).map
      (fun seed => (seed.initial.locals.length, integerAt seed.initial 1)) =
        [(2, top), (3, top), (3, top), (3, top)] := rfl

-- 構造のパターンはコアの束縛順に必要な位置数を保ち、値の型は推測しない。
example :
    let pattern : Pattern := .con none "Example.Pair" [.var, .wild, .var]
    let body : Block := .bindPat .bind pattern (.data "Example.Pair" []) .unit
      (.last (.lam ["x", "y"] [.base .integer, .reference (.base .integer)]
        (.base .unit) Eff.empty (.last .unit)))
    (discoverBlock (AbstractEnv.ofLocals []) body).map (fun seed =>
      (seed.initial.locals.length, integerAt seed.initial 0, integerAt seed.initial 1)) =
        [(4, top, top)] := rfl

end Benitoite.Interval
