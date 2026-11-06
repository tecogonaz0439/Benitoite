import Benitoite.Release.Refinement.Surface.CheckFormation

/-! 宣言と項だけから欄の名目型を求める形成の入口の適用例。 -/
namespace Benitoite.Release.Refinement.Surface.CheckDataHintExamples
open CheckFormation

private def program : Refinement.Program where
  defs := fun _ => none
  cons := fun c => if c = "Nested.make" then some ⟨"Nested", 1, [.data "Box" [.tvar 0]]⟩
    else if c = "Box.make" then some ⟨"Box", 1, [.tvar 0]⟩ else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

private def input : CheckFormation.Input where
  atoms := []
  ctors := fun _ => ["Nested.make", "Box.make"]

private def outerField : FieldRef := ⟨"Nested", "Nested.make", 0, .data⟩
private def valueField : FieldRef := ⟨"Box", "Box.make", 0, .integer⟩
private def wrongOwner : FieldRef := ⟨"Other", "Box.make", 0, .integer⟩
private def variableReceiver : Term := .field outerField (.var 0)
private def boxed : Term := .dataValue "Box.make" [some (.integer 1)]
private def nested : Term := .dataValue "Nested.make" [some boxed]
private def environment : Ctx := [some (.data "Nested" [.base .integer])]

/-- 変数の既知の型引数と、構成子で消去された型引数の両方から、二段の欄を観測できる。 -/
theorem nested_fields :
    declaredTerm input program [] environment [] (.field valueField variableReceiver) = true ∧
    declaredTerm input program [] [] [] (.field valueField (.field outerField nested)) = true := by
  constructor <;> rfl

/-- 型引数を持たない構成子の項は宣言の欄型から検査し、所有する型の不一致を拒否する。 -/
theorem erased_arguments :
    declaredTerm input program [] [] [] (.field valueField boxed) = true ∧
    declaredTerm input program [] [] [] (.field wrongOwner boxed) = false := by
  constructor <;> rfl

/-- 構成子の判定も、項と宣言から受け手の名目型を計算する。 -/
theorem constructor_source :
    declaredPred input program [] [] none [] (.constructorIs boxed "Box.make") = true := by
  rfl

private theorem input_sound : input.Sound program := by
  constructor
  · intro c cd h
    simp only [program] at h
    split at h
    · rename_i hc
      subst c
      simp [input]
    · split at h
      · rename_i hc
        subst c
        simp [input]
      · cases h
  · intro c cd h
    simp only [program] at h
    split at h
    · cases h; trivial
    · split at h
      · cases h; trivial
      · cases h

/-- 同じ非空の宣言表で、計算の成功を欄の宣言の意味へ接続する。 -/
theorem nested_fields_declared :
    Term.Declared program [] environment (.field valueField variableReceiver) := by
  apply declaredTerm_sound input_sound _ nested_fields.1
  intro i a h
  cases i with
  | zero => simp only [environment, List.getElem?_cons_zero, Option.some.injEq] at h; cases h; trivial
  | succ i => simp only [environment, List.getElem?_cons_succ, List.getElem?_nil] at h; cases h

end Benitoite.Release.Refinement.Surface.CheckDataHintExamples
