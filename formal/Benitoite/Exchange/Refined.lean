import Lean
import Benitoite.Exchange.Range
import Benitoite.Release.Refinement.TermSyntax

/-! # 篩付きの型を運ぶ交換の版

処理系の書き出しと Lean の入口の間の交換の新しい版の構文と、版の判定を定める（設計書 07-04「証明する性質」）。
読み手は新しい版だけを受け、それより前の版を版の誤りで断る。新しい版は旧版の欄に加えて、篩付きの型（述語と項）、
基準と secrets を持つ範囲の位置、関数の依存する引数列、範囲パラメータ、`@proofSteps` の上限、型の別名の値引数と
範囲パラメータ、欄どうしの依存を持つ record を運ぶ。版の番号は仮の値であり、処理系の書き出しと同じ変更で改める。
-/
namespace Benitoite.Exchange.Refined
open Lean

/-- 新しい版の番号（仮）。コーパスと付随の表で世代を分ける既存の数え方を保つ。 -/
def corpusVersion : Nat := 16
def sidecarVersion : Nat := 8

/-- 入力の種類ごとに受ける版。 -/
def versionOf (kind : String) : Nat := if kind == "corpus" then corpusVersion else sidecarVersion

/-- 版の欄を読み、新しい版だけを受ける。旧版と未知の版は版の誤りで断る。 -/
def readVersion (kind : String) (j : Json) : Except String Unit := do
  let version ← j.getObjValAs? Nat "version"
  if version != versionOf kind then
    throw s!"unsupported {kind} exchange version: {version}; regenerate with version {versionOf kind}"

/-- 型の位置の範囲。固定の範囲の式（絶対形・基準からの形・secrets）か、署名の範囲の変数である。 -/
inductive RangeIndex where
  | fixed (range : Benitoite.Release.Refinement.RangeExpr)
  | rvar (index : Nat)

/-- 型構成子。 -/
inductive TyCon where
  | data (name : String)
  | list | set | map | reference | lazyT

mutual
  /-- エフェクトの原子。名前と範囲の位置、行変数、Fail のエラー型。 -/
  inductive Atom where
    | name (value : String) (ix : RangeIndex)
    | rho (index : Nat)
    | fail (error : Ty)
  /-- 型。旧版の型に、篩・依存する関数型・外部型・範囲付きの値型・起点の型・範囲の pattern の型を加える。
  篩の述語と項は核の `Pred`・`Term` の形で運ぶ（番号 0 が篩を付けた値）。 -/
  inductive Ty where
    | base (name : String)
    | opaque (name : String) (ix : RangeIndex)
    | data (name : String) (args : List Ty)
    | list (elem : Ty)
    | fn (names : List String) (params : List Ty) (ret : Ty) (eff : List Atom)
    | tvar (index : Nat)
    | reference (elem : Ty)
    | lazyT (elem : Ty)
    | map (key value : Ty)
    | set (elem : Ty)
    | bytes
    | dict (cls : String) (arg : Ty)
    | tapp (index : Nat) (args : List Ty)
    | ctor (head : TyCon)
    | refined (base : Ty) (predicate : Benitoite.Release.Refinement.Pred)
    /-- 引数と結果が前の引数を値変数として参照できる関数型（最後の引数が番号 0）。 -/
    | dependentFn (names : List String) (params : List Ty) (ret : Ty) (eff : List Atom)
    | external (id : String) (args : List Ty)
    | scoped (name : String) (kind : Scope.Domain.Kind) (ix : RangeIndex)
    | pathBases
    | scopePattern (kind : Scope.Domain.Kind)
end

/-- 関数の宣言の頭部。旧版の欄に、範囲パラメータの種類の列と `@proofSteps` の上限を加える。 -/
structure Header where
  tparams : List (Bool × Bool)
  neffs : Nat
  noFail : List Bool
  names : List String
  params : List Ty
  ret : Ty
  eff : List Atom
  rangeParams : List Scope.Domain.Kind
  proofSteps : Option Nat

/-- 型の別名の宣言。値引数は篩の項に現れる種類の値、範囲パラメータは範囲の変数として本体が読む。 -/
structure AliasEntry where
  name : String
  tparams : Nat
  valueParams : List (String × Ty)
  rangeParams : List Scope.Domain.Kind
  body : Ty

/-- 欄どうしの依存を持つ record の構成子。欄の型は前の欄を値変数として参照できる（直前の欄が番号 0）。 -/
structure RecordEntry where
  constructor : String
  data : String
  ntys : Nat
  fields : List (String × Ty)

/-- 生成した構成子の判定の関数と、判定する構成子。 -/
structure TesterEntry where
  function : String
  constructor : String

/-- 篩付きの型だけで書ける宣言の欄。各入力が旧版の宣言の欄と並べて持つ。 -/
structure Declarations where
  aliases : List AliasEntry
  records : List RecordEntry
  testers : List TesterEntry

/-- 旧版の入力は版の誤りで断られ、新しい版の入力は版の判定を通る。 -/
example : (readVersion "corpus" (Json.mkObj [("version", toJson (15 : Nat))])).toBool = false ∧
    (readVersion "corpus" (Json.mkObj [("version", toJson corpusVersion)])).toBool = true ∧
    (readVersion "builtins" (Json.mkObj [("version", toJson (7 : Nat))])).toBool = false ∧
    (readVersion "builtins" (Json.mkObj [("version", toJson sidecarVersion)])).toBool = true := by
  decide

/-- 篩付きの引数と `@proofSteps(500)` を持つ関数の頭部（`function f(x: Integer{v | 0 < v}) -> Integer`）。 -/
example : Header :=
  { tparams := [], neffs := 0, noFail := [], names := ["x"],
    params := [.refined (.base "Integer") (.lt (.integer 0) (.var 0))], ret := .base "Integer", eff := [],
    rangeParams := [], proofSteps := some 500 }

end Benitoite.Exchange.Refined
