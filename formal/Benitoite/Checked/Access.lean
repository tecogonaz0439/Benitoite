import Std

/-!
# 解決済みの所有元による公開境界の小モデル

内部表現を隠した型について、型名の公開範囲を通った後の判定だけを扱う。文字列からの名前解決や
パッケージの可視性は証明しない（設計書 01-12「検査済みの値の独立した小モデル」）。
-/
namespace Benitoite.Checked.Access

abbrev Module := String
abbrev Owner := Module

/-- 内部表現を使うには宣言元のモジュールと一致しなければならない。 -/
def mayInspect (owner : Owner) (caller : Module) : Bool := decide (owner = caller)

theorem mayInspect_iff (owner : Owner) (caller : Module) :
    mayInspect owner caller = true ↔ owner = caller := by
  simp [mayInspect]

/-- 別名の綴りと、解決済みの型の所有元を分ける。 -/
structure ResolvedType where
  owner : Owner
  name : String
  deriving DecidableEq

def importAlias (ref : ResolvedType) (alias : String) : ResolvedType :=
  { ref with name := alias }

theorem importAlias_preservesOwner (ref : ResolvedType) (alias : String) :
    (importAlias ref alias).owner = ref.owner := rfl

theorem importAlias_preservesBoundary (ref : ResolvedType) (alias : String) (caller : Module) :
    mayInspect (importAlias ref alias).owner caller = mayInspect ref.owner caller := rfl

/-- 型名の利用・通常値の受け渡しと、内部表現を使う操作を区別する。 -/
inductive Operation where
  | typeAnnotation | typeArgument | passValue | bindValue | wildcard
  | constructorValue | constructorCall | partialConstructor | constructorPattern
  | recordBuild | recordUpdate | recordPattern | accessor
  deriving DecidableEq

def mayUse (owner : Owner) (caller : Module) : Operation → Bool
  | .typeAnnotation | .typeArgument | .passValue | .bindValue | .wildcard => true
  | _ => mayInspect owner caller

theorem outside_constructor_denied (owner caller : Module) (h : owner ≠ caller) :
    mayUse owner caller .constructorValue = false ∧
    mayUse owner caller .partialConstructor = false ∧
    mayUse owner caller .accessor = false := by
  simp [mayUse, mayInspect, h]

-- 同じ値の受け渡しと内部構築の境界を対照する。
example : mayUse "Scope" "Client" .passValue = true ∧
    mayUse "Scope" "Client" .recordBuild = false ∧
    mayUse "Scope" "Scope" .recordBuild = true := by decide

end Benitoite.Checked.Access
