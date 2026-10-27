import Benitoite.Surface.Syntax

/-!
# 表層の出現の識別

Expr 一つに一番号を割り当て、容器は数えず宣言のフィールド順に辿る。
評価で未対応の部分木も数え、constE の埋め込み本体も含める
（設計書 01-12「区間解析の対象構文の評価関係」）。
-/
namespace Benitoite.Interval
open Benitoite.Release Benitoite.Surface

/-- Exprsは容器自身を数えず、書いた順の式を返す。 -/
def exprsChildren : Exprs → List Expr
  | .nil => []
  | .cons e rest => e :: exprsChildren rest

/-- 穴は式を持たず、通常の引数だけが子になる。 -/
def holeChildren : HoleArgs → List Expr
  | .nil => []
  | .expr _ _ e rest => e :: holeChildren rest
  | .hole _ _ _ rest => holeChildren rest

/-- 全Block形の順序。builder位置を整数の子として作らない。 -/
def blockChildren : Block → List Expr
  | .empty => []
  | .builderBind _ rest => blockChildren rest
  | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => [e]
  | .bind _ _ e rest | .discard e rest | .seq e rest | .bindPat _ _ _ e rest =>
      e :: blockChildren rest

/-- 腕のguardを本体より前に置き、パターンから式を作らない。 -/
def armsChildren : Arms → List Expr
  | .nil => []
  | .cons _ guard body rest => guard.toList ++ blockChildren body ++ armsChildren rest

/-- 節の本体も構文上は子である。評価の境界とは区別する。 -/
def clausesChildren : Clauses → List Expr
  | .nil => []
  | .cons _ _ _ body rest _ => blockChildren body ++ clausesChildren rest

/-- 宣言のフィールド順の直接の子。全相互帰納容器を扱うが、評価は行わない。 -/
def children : Expr → List Expr
  | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
  | .primName _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
  | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
  | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
  | .negFloat32 _ | .unit => []
  | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es =>
      exprsChildren es
  | .constE _ e | .paren e | .neg _ e | .not e | .returnE _ e
  | .tryResult _ _ _ e | .tryOption _ _ _ e | .resume _ e => [e]
  | .block body | .lam _ _ _ _ body | .lazyE body => blockChildren body
  | .handleFail _ _ body clause => blockChildren body ++ blockChildren clause
  | .recordUpdate _ _ _ _ base es => base :: exprsChildren es
  | .call callee _ _ es => callee :: exprsChildren es
  | .pipe lhs rhs | .binary _ _ lhs rhs | .and lhs rhs | .or lhs rhs => [lhs, rhs]
  | .partialCall callee _ args _ _ => callee :: holeChildren args
  | .partialCon _ _ args => holeChildren args
  | .listSpread _ concat before spread after =>
      [concat] ++ exprsChildren before ++ [spread] ++ exprsChildren after
  | .interpolation _ es converters => exprsChildren es ++ exprsChildren converters
  | .ite cond yes no => [cond] ++ blockChildren yes ++ blockChildren no
  | .elseIf cond yes no => [cond] ++ blockChildren yes ++ [no]
  | .ifOnly cond yes => cond :: blockChildren yes
  | .matchE _ scrutinee arms => scrutinee :: armsChildren arms
  | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message =>
      e :: message.toList
  | .withE _ e body => e :: blockChildren body
  | .handleE body clauses => blockChildren body ++ clausesChildren clauses

/-- 定義名はモジュール名を含む。番号の付与と元ASTとの対応は別に検査する。 -/
structure OperationKey where
  definition : String
  surfacePreorder : Nat
  deriving DecidableEq, Repr

mutual
  /-- 全53構成子と相互帰納容器を辿る先行順。容器自身に番号を割り当てない。 -/
  def surfacePreorder (source : Expr) : List Expr :=
    source :: (match source with
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit => []
    | .builderOp _ _ es _ | .conCall _ _ es | .record _ _ _ es | .list _ es =>
        preorderExprs es
    | .constE _ e | .paren e | .neg _ e | .not e | .returnE _ e
    | .tryResult _ _ _ e | .tryOption _ _ _ e | .resume _ e => surfacePreorder e
    | .block body | .lam _ _ _ _ body | .lazyE body => preorderBlock body
    | .handleFail _ _ body clause => preorderBlock body ++ preorderBlock clause
    | .recordUpdate _ _ _ _ base es => surfacePreorder base ++ preorderExprs es
    | .call callee _ _ es => surfacePreorder callee ++ preorderExprs es
    | .pipe lhs rhs | .binary _ _ lhs rhs | .and lhs rhs | .or lhs rhs =>
        surfacePreorder lhs ++ surfacePreorder rhs
    | .partialCall callee _ args _ _ => surfacePreorder callee ++ preorderHoles args
    | .partialCon _ _ args => preorderHoles args
    | .listSpread _ concat before spread after =>
        surfacePreorder concat ++ preorderExprs before ++ surfacePreorder spread ++ preorderExprs after
    | .interpolation _ es converters => preorderExprs es ++ preorderExprs converters
    | .ite cond yes no => surfacePreorder cond ++ preorderBlock yes ++ preorderBlock no
    | .elseIf cond yes no => surfacePreorder cond ++ preorderBlock yes ++ surfacePreorder no
    | .ifOnly cond yes => surfacePreorder cond ++ preorderBlock yes
    | .matchE _ scrutinee arms => surfacePreorder scrutinee ++ preorderArms arms
    | .tryResultDie _ _ _ _ _ _ e message | .tryOptionDie _ _ _ _ e message =>
        surfacePreorder e ++ (match message with | none => [] | some m => surfacePreorder m)
    | .withE _ e body => surfacePreorder e ++ preorderBlock body
    | .handleE body clauses => preorderBlock body ++ preorderClauses clauses)

  /-- 通常引数の列を、ソース順に番号付けの走査へ含める。 -/
  def preorderExprs : Exprs → List Expr
    | .nil => []
    | .cons e rest => surfacePreorder e ++ preorderExprs rest

  /-- 穴は番号を使わず、通常の引数だけを走査する。 -/
  def preorderHoles : HoleArgs → List Expr
    | .nil => []
    | .expr _ _ e rest => surfacePreorder e ++ preorderHoles rest
    | .hole _ _ _ rest => preorderHoles rest

  /-- 文の右辺と続きを辿り、専用束縛の位置自身は数えない。 -/
  def preorderBlock : Block → List Expr
    | .empty => []
    | .builderBind _ rest => preorderBlock rest
    | .last e | .lastBind _ _ e | .lastDiscard e | .lastPat _ _ _ e => surfacePreorder e
    | .bind _ _ e rest | .discard e rest | .seq e rest | .bindPat _ _ _ e rest =>
        surfacePreorder e ++ preorderBlock rest

  /-- 腕ごとに guard、本体、残りの腕の順に辿る。 -/
  def preorderArms : Arms → List Expr
    | .nil => []
    | .cons _ guard body rest =>
        (match guard with | none => [] | some g => surfacePreorder g) ++
          preorderBlock body ++ preorderArms rest

  /-- 節の本体を宣言の順に辿る。 -/
  def preorderClauses : Clauses → List Expr
    | .nil => []
    | .cons _ _ _ body rest _ => preorderBlock body ++ preorderClauses rest

end

private theorem preorderExprs_children (es : Exprs) :
    preorderExprs es = (exprsChildren es).flatMap surfacePreorder := by
  cases es with
  | nil => rfl
  | cons e rest => simp [preorderExprs, exprsChildren, preorderExprs_children rest]

private theorem preorderHoles_children (args : HoleArgs) :
    preorderHoles args = (holeChildren args).flatMap surfacePreorder := by
  cases args with
  | nil => rfl
  | expr _ _ e rest => simp [preorderHoles, holeChildren, preorderHoles_children rest]
  | hole _ _ _ rest => exact preorderHoles_children rest

private theorem preorderBlock_children (body : Block) :
    preorderBlock body = (blockChildren body).flatMap surfacePreorder := by
  cases body with
  | builderBind _ rest => exact preorderBlock_children rest
  | bind _ _ e rest | discard e rest | seq e rest | bindPat _ _ _ e rest =>
      simp [preorderBlock, blockChildren, preorderBlock_children rest]
  | _ => simp [preorderBlock, blockChildren]

private theorem preorderArms_children (arms : Arms) :
    preorderArms arms = (armsChildren arms).flatMap surfacePreorder := by
  cases arms with
  | nil => rfl
  | cons alts guard body rest =>
      cases guard <;> simp [preorderArms, armsChildren, preorderBlock_children,
        preorderArms_children rest]

private theorem preorderClauses_children (clauses : Clauses) :
    preorderClauses clauses = (clausesChildren clauses).flatMap surfacePreorder := by
  cases clauses with
  | nil => rfl
  | cons op arity ntys body rest dictCount =>
      simp [preorderClauses, clausesChildren, preorderBlock_children,
        preorderClauses_children rest]

/-- 番号付けの走査は、直接の子の列挙とすべての構成子で一致する。 -/
theorem surfacePreorder_children (source : Expr) :
    surfacePreorder source = source :: (children source).flatMap surfacePreorder := by
  cases source <;> simp [surfacePreorder, children, preorderExprs_children,
    preorderHoles_children, preorderBlock_children, preorderArms_children,
    preorderClauses_children]
  all_goals rename_i message; cases message <;> simp [surfacePreorder]

/-- 部分木が占める連続した番号の個数。 -/
def surfaceSize (source : Expr) : Nat := (surfacePreorder source).length

/-- 親の直後から、先行する子の部分木の個数だけ進める。preceding は直接の子の接頭辞。 -/
def childKey (parent : OperationKey) (preceding : List Expr) : OperationKey :=
  ⟨parent.definition, parent.surfacePreorder + 1 + (preceding.map surfaceSize).sum⟩

/-- 先行順の各出現を、根の番号から連続するキーと組にする。 -/
def numbered (root : OperationKey) (source : Expr) : List (OperationKey × Expr) :=
  (surfacePreorder source).zipIdx root.surfacePreorder |>.map fun (e, i) =>
    (⟨root.definition, i⟩, e)

/-- 直接の子の部分木を連ねた長さが、親の直後の番号範囲を占める。 -/
theorem surfaceSize_children (source : Expr) :
    surfaceSize source = 1 + ((children source).map surfaceSize).sum := by
  have lengths (es : List Expr) :
      (es.flatMap surfacePreorder).length = (es.map surfaceSize).sum := by
    induction es with
    | nil => rfl
    | cons e rest ih => simp [surfaceSize, ih]
  simp [surfaceSize, surfacePreorder_children source, lengths, Nat.add_comm]

@[simp] theorem surfaceSize_pos (source : Expr) : 0 < surfaceSize source := by
  rw [surfaceSize_children]
  omega

/-- 式の番号は根から連続し、未対応の部分木でも欠番や重複を作らない。 -/
theorem numbered_preorders (root : OperationKey) (source : Expr) :
    (numbered root source).map (fun p => p.1.surfacePreorder) =
      List.range' root.surfacePreorder (surfaceSize source) := by
  simp [numbered, List.map_map, Function.comp_def, List.zipIdx_map_snd, surfaceSize]

/-- 構文の同じ内容が繰り返されても、その出現のキーは異なる。 -/
theorem numbered_keys_nodup (root : OperationKey) (source : Expr) :
    ((numbered root source).map Prod.fst).Nodup := by
  have nums : ((numbered root source).map (fun p => p.1.surfacePreorder)).Nodup := by
    rw [numbered_preorders]
    exact List.nodup_range'
  apply List.pairwise_map.mpr
  exact (List.pairwise_map.mp nums).imp fun different equal =>
    different (congrArg OperationKey.surfacePreorder equal)

@[simp] theorem surfaceSize_paren (e : Expr) :
    surfaceSize (.paren e) = 1 + surfaceSize e := by
  simp [surfaceSize, surfacePreorder, Nat.add_comm]

@[simp] theorem surfaceSize_constE (t : Ty) (e : Expr) :
    surfaceSize (.constE t e) = 1 + surfaceSize e := by
  simp [surfaceSize, surfacePreorder, Nat.add_comm]

@[simp] theorem surfaceSize_returnE (t : Ty) (e : Expr) :
    surfaceSize (.returnE t e) = 1 + surfaceSize e := by
  simp [surfaceSize, surfacePreorder, Nat.add_comm]

@[simp] theorem surfaceSize_binary (op : BinOp) (t : Ty) (l r : Expr) :
    surfaceSize (.binary op t l r) = 1 + surfaceSize l + surfaceSize r := by
  simp [surfaceSize, surfacePreorder, Nat.add_comm, Nat.add_assoc]

/-- 交換の入力は空でないモジュール付き名を渡し、内部本体用の % を含めない。
名前解決の正しさはこの述語からは導かない。 -/
def QualifiedDefinition (name : String) : Prop :=
  name ≠ "" ∧ '.' ∈ name.toList ∧ '%' ∉ name.toList

/-- 関数・定数・別本体の根は明示した block 式で統一する。
Block 容器に番号を付けるのではなく、この Expr に番号0を付ける。 -/
def bodyRoot (body : Block) : Expr := .block body

/-- 各本体は独立した名前の番号0から開始する。 -/
def bodyRootKey (definition : String) : OperationKey := ⟨definition, 0⟩

/-- 根の block 式の直後にある、本体内の最初の式のキー。空本体では未使用。 -/
def bodyContentKey (definition : String) : OperationKey := ⟨definition, 1⟩

/-- 本体を囲む構文の種類。通常節の位置は ordinal で区別する。 -/
inductive BoundaryKind where
  | constant | lambda | lazy | handler | failure
  deriving DecidableEq, Repr

/-- 親は常に元のモジュール付き定義の走査を指す。
入れ子でも親の解析結果や別本体で振り直した番号を使わない。 -/
structure EmbeddedBody where
  owner : OperationKey
  ordinal : Nat
  kind : BoundaryKind
  body : Block
  parentStart : Nat

/-- % は利用者の識別子に含まれないため、元の定義名と内部名を区別できる。
同じ handle の複数の節には0からの ordinal を付ける。 -/
def EmbeddedBody.definition (entry : EmbeddedBody) : String :=
  entry.owner.definition ++ "%body:" ++ toString entry.owner.surfacePreorder ++
    ":" ++ toString entry.ordinal

/-- 別本体の根は新しい block 式であり、親の先行順には挿入しない。 -/
def EmbeddedBody.root (entry : EmbeddedBody) : OperationKey := bodyRootKey entry.definition

/-- 別本体の根以外を、元の定義の連続する部分へ戻す。
空本体と範囲外の番号を、実在する元の式へ対応させない。 -/
def EmbeddedBody.parentKey (entry : EmbeddedBody) (index : Nat) : Option OperationKey :=
  match index with
  | 0 => none
  | i + 1 => if i < (preorderBlock entry.body).length then
      some ⟨entry.owner.definition, entry.parentStart + i⟩ else none

/-- 節容器に番号を足さず、先行する本体の式数だけ親の位置を進める。
この列挙と大きさは数学的な指定であり、予算付きの実行からは呼ばない。 -/
def clauseBodies (owner : OperationKey) (start ordinal : Nat) : Clauses → List EmbeddedBody
  | .nil => []
  | .cons _ _ _ body rest _ =>
      ⟨owner, ordinal, .handler, body, start⟩ ::
        clauseBodies owner (start + (preorderBlock body).length) (ordinal + 1) rest

/-- 一出現が直接持つ別本体。const の子は親で解析し、別本体を作らない。
handle の保護された本体と with/try は別本体を増やさない。 -/
def embeddedBodies (owner : OperationKey) : Expr → List EmbeddedBody
  | .lam _ _ _ _ body => [⟨owner, 0, .lambda, body, owner.surfacePreorder + 1⟩]
  | .lazyE body => [⟨owner, 0, .lazy, body, owner.surfacePreorder + 1⟩]
  | .handleFail _ _ body clause =>
      [⟨owner, 0, .failure, clause, owner.surfacePreorder + 1 + (preorderBlock body).length⟩]
  | .handleE body clauses =>
      clauseBodies owner (owner.surfacePreorder + 1 + (preorderBlock body).length) 0 clauses
  | _ => []

/-- 全別本体の数学的な manifest。順序は境界式の先行順、同じ式では節の順。
親は常に元の定義なので、入れ子でも名前を再帰的に連結しない。
予算付きの実行では全列挙を事前計算せず、取得した出現と容器を逐次使う。 -/
def bodyManifest (definition : String) (body : Block) : List EmbeddedBody :=
  (numbered (bodyRootKey definition) (bodyRoot body)).flatMap fun (key, source) =>
    embeddedBodies key source

/-- 同じ内容の境界も、その親の出現番号または節位置が異なれば別本体である。 -/
def EmbeddedBody.address (entry : EmbeddedBody) : OperationKey × Nat :=
  (entry.owner, entry.ordinal)

/-- 新しい根は親に対応する式を持たず、内容だけが一つずれた連続列になる。 -/
theorem bodyRoot_preorder (body : Block) :
    surfacePreorder (bodyRoot body) = bodyRoot body :: preorderBlock body := rfl

/-- 空本体も根の一番号を持つ。 -/
theorem bodyRoot_size (body : Block) :
    surfaceSize (bodyRoot body) = 1 + (preorderBlock body).length := by
  simp [surfaceSize, bodyRoot_preorder, Nat.add_comm]

/-- 有効な別本体の式番号から、親の出現を一意に決める。 -/
theorem EmbeddedBody.parentKey_content (entry : EmbeddedBody) (i : Nat)
    (inside : i < (preorderBlock entry.body).length) :
    entry.parentKey (i + 1) = some ⟨entry.owner.definition, entry.parentStart + i⟩ := by
  simp [EmbeddedBody.parentKey, inside]

/-- 別本体内で異なる有効な番号を、同じ親の出現へ潰さない。 -/
theorem EmbeddedBody.parentKey_injective (entry : EmbeddedBody) (i j : Nat)
    (hi : i < (preorderBlock entry.body).length)
    (hj : j < (preorderBlock entry.body).length)
    (same : entry.parentKey (i + 1) = entry.parentKey (j + 1)) : i = j := by
  simp only [entry.parentKey_content i hi, entry.parentKey_content j hj,
    Option.some.injEq, OperationKey.mk.injEq] at same
  omega

/-- 元 AST の対応表は Rust にだけ保持する。Lean には表示位置の型を持ち込まず、
対象演算の全キーが同じ元演算へ対応するという入力の条件だけを定める。
異なるキーの像が同じでもよく、対応のない合成節点を対象に含めない。 -/
def SourceCorrespondence {α : Type} (target : OperationKey → Prop)
    (origin : OperationKey → Option α) (operation : OperationKey → α → Prop) : Prop :=
  ∀ key, target key → ∃ source, origin key = some source ∧ operation key source

/-- 対応漏れのキーを対象とする入力は対応の条件を満たさない。 -/
theorem sourceCorrespondence_missing {α : Type} {target : OperationKey → Prop}
    {origin : OperationKey → Option α} {operation : OperationKey → α → Prop}
    {key : OperationKey} (missing : origin key = none) (selected : target key) :
    ¬ SourceCorrespondence target origin operation := by
  intro valid
  obtain ⟨source, atSource, _⟩ := valid key selected
  rw [missing] at atSource
  contradiction

-- 未対応の境界も番号を使う。容器・穴・builder位置を数えず、名前付き引数を
-- 契約位置で並べ替えない。const本体、guard、本体、節、任意の説明も書いた順に辿る。
example :
    let source : Expr := .handleE
      (.builderBind .string (.seq (.constE (.base .integer) (.local 0))
        (.last (.partialCall (.local 1) []
          (.hole none 0 (.base .integer) (.expr (some "value") 1 (.local 2) .nil))
          (.base .unit) Eff.empty))))
      (.cons (.user "Example.first") 0 0
        (.last (.matchE (.base .unit) (.local 3)
          (.cons [] (some (.call (.local 4) [some "b", some "a"] [1, 0]
            (.cons (.local 5) (.cons (.local 6) .nil))))
            (.last (.tryOptionDie (.base .unit) "Some" "None" "exit"
              (.local 7) (some (.local 8)))) .nil)))
        (.cons (.user "Example.second") 0 0 (.lastDiscard (.local 9)) .nil))
    (numbered ⟨"Example.preorder", 10⟩ source).map
      (fun (key, e) => (key.surfacePreorder, match e with
        | .local index => some index | _ => none)) =
      [(10, none), (11, none), (12, some 0), (13, none), (14, some 1),
       (15, some 2), (16, none), (17, some 3), (18, none), (19, some 4),
       (20, some 5), (21, some 6), (22, none), (23, some 7), (24, some 8), (25, some 9)] := by
  rfl

end Benitoite.Interval
