import Benitoite.Release.Refinement.Surface.Basic

/-!
# 表層の全ての式の出現の番号

式を一つずつ数え、容器は数えず宣言のフィールド順に辿る。型や述語の注釈は走査の対象にしない。
Scope の必須の判定の記録と出現の照合は、この同じ走査を使う
（設計書 01-12「Scope の局所解析の表層からの対応」）。
-/
namespace Benitoite.Release.Refinement.Surface.Identity

mutual
  /-- 全ての構成子と相互帰納容器を辿る先行順。容器自身に番号を割り当てない。 -/
  def surfacePreorder (source : Expr) : List Expr :=
    source :: (match source with
    | .local _ | .funName _ _ _ | .funDicts _ _ _ _ _ _ | .methName _ _ _ _ _ _ _
    | .primName _ _ _ _ | .opName _ _ | .opDicts _ _ _ _ _ | .raise _ _
    | .nullCon _ _ | .conValue _ _ _ _ | .literal _ | .negInt _ | .negFloat _
    | .negDecimal _ _ | .negInteger8 _ | .negInteger16 _ | .negInteger32 _
    | .negFloat32 _ | .unit | .externalName _ _ => []
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

/-- 部分木が占める連続した番号の個数。 -/
def surfaceSize (source : Expr) : Nat := (surfacePreorder source).length


end Benitoite.Release.Refinement.Surface.Identity
