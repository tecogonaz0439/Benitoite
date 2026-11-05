import Benitoite.Release.Refinement.Surface.Syntax

/-!
# 篩付きの型の表層の型付けの判断の型

表層の型付けの判断の引数の並びを定める（設計書 01-12「型の情報を付けた表層の構文と型付け」）。旧表層の判断の
並び（宣言の表・組み込みの表・演算子の表・NoFail の文脈・構築器の文脈・型パラメータ・値の文脈・戻り先・位置・項・
型・効果）を保ち、値の文脈 Γ の直後に事実の列 Φ を置く。型パラメータの文脈は kind と制約を持つ `TypeCtx`、
値の文脈は篩付きの型の `Ctx` である。各判断の規則は、この型を持つ相互帰納の判断として置く。
-/

namespace Benitoite.Release.Refinement.Surface

/-- 式の型付け `HasTypeQ`。 -/
abbrev ExprJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Position → Expr → Ty → Eff → Prop

/-- 引数の列の型付け `HasTypesQ`（位置ごとの型）。 -/
abbrev ExprsJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Exprs → List Ty → Eff → Prop

/-- リストの要素の型付け `HasEachQ`（同じ要素型）。 -/
abbrev EachJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Exprs → Ty → Eff → Prop

/-- 穴を持つ引数の型付け `HasHoleArgsQ`。 -/
abbrev HoleArgsJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → HoleArgs → List Ty → Eff → Prop

/-- 分岐の型付け `HasArmsQ`（照合する値の型と結果型）。 -/
abbrev ArmsJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Position → Arms → Ty → Ty → Eff → Prop

/-- ハンドラの節の型付け `HasClausesQ`（保護本体の効果を添字に持つ）。 -/
abbrev ClausesJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Eff → Clauses → Ty → Eff → Prop

/-- 文の列の型付け `HasBlockQ`。 -/
abbrev BlockJudgment := Declarations → Builtins → OpPrim → NoFailCtx →
  BuilderCtx → TypeCtx → Ctx → List Pred → Option Ty → Position → Block → Ty → Eff → Prop

/-- 辞書の型付け `DictEv.HasType`。 -/
abbrev DictJudgment := Declarations → Builtins → TypeCtx → Ctx → DictEv → Ty → Prop

/-! ## 構文と宣言の例 -/

/-- 欄 `high` の型が前の欄 `low` を参照する record（`high: Integer{h | low <= h}`）。篩の中の番号 0 は欄自身、
番号 1 は直前の欄である。 -/
def spanRecord : RecordDecl where
  data := "Span"
  ntys := 0
  fields := [("low", .base .integer), ("high", .refined (.base .integer) (.le (.var 1) (.var 0)))]

/-- 値引数 `n: Integer` を持つ型の別名（`type Window(n: Integer) = Integer{x | 0 <= x && x < n}`）。 -/
def windowAlias : AliasDecl where
  tparams := []
  valueParams := [("n", .base .integer)]
  body := .refined (.base .integer) (.and (.le (.integer 0) (.var 0)) (.lt (.var 0) (.var 1)))

/-- 篩付きの引数と `@proofSteps(500)` を持つトップレベルの関数の宣言。 -/
def positiveDecl : FunDecl where
  tparams := []
  neffs := 0
  names := ["x"]
  params := [.refined (.base .integer) (.lt (.integer 0) (.var 0))]
  ret := .base .integer
  eff := Eff.empty
  proofSteps := some 500

example : spanRecord.fields.length = 2 ∧ windowAlias.valueParams.length = 1 ∧
    positiveDecl.proofSteps = some 500 ∧ positiveDecl.rangeParams = [] :=
  ⟨rfl, rfl, rfl, rfl⟩

end Benitoite.Release.Refinement.Surface
