import Benitoite.Release.Refinement.Surface.CheckPatterns

/-! 篩のパターン、選択肢の並べ替え、欄の経路の検査の適用例。 -/
namespace Benitoite.Release.Refinement.Surface.CheckPatternExamples
open CheckPatterns

private def declarations : Declarations where
  funs := fun _ => none
  cons := fun _ => none

private def input : CheckFormation.Input where
  atoms := []
  ctors := fun _ => []

private theorem input_sound : input.Sound declarations.core := by
  refine ⟨?_, ?_, ?_⟩
  · intro c cd h; cases h
  · intro c cd h; cases h
  · intro path; trivial

/-- 同じ正常値を持つ篩の型で、Unit と Boolean のパターンを区別する。 -/
theorem refined_accept_reject (q : CheckFormation.Input) (P : Refinement.Program) :
    patTy q P (.const .unit) (.refined (.base .unit) .truth) = some [] ∧
    patTy q P (.const (.boolean true)) (.refined (.base .unit) .truth) = none := by
  constructor <;> rfl

theorem refined_input (P : Refinement.Program) :
    Inhabits P (.refined (.base .unit) .truth) (.const .unit) :=
  .refined (Inhabits.const (c := .unit)) (by simp [RefinementPossible, Pred.evalWith, Pred.atomReady, Pred.atomValue])

/-- 変数の束縛型は、元の篩の型を正規化する。 -/
theorem refined_variable {q : CheckFormation.Input} {P : Refinement.Program} (hq : q.Sound P) :
    PatTy P .var (.refined (.base .unit) .truth) [(Ty.refined (.base .unit) .truth).normWith q.atoms] ∧
    Ty.SupportList (· ∈ q.atoms) [(Ty.refined (.base .unit) .truth).normWith q.atoms] := by
  have h : patTy q P .var (.refined (.base .unit) .truth) = some [(Ty.refined (.base .unit) .truth).normWith q.atoms] := rfl
  exact ⟨patTy_sound hq (by trivial) h, patTy_support hq (by trivial) h⟩

/-- ソースのパターンと核のパターンは、同じ束縛の判断を使う。 -/
theorem source_variable {q : CheckFormation.Input} {D : Declarations} (hq : q.Sound D.core) :
    PatTy D.core Pattern.var.toCore (.base .unit) [.base .unit] ∧
    Ty.SupportList (· ∈ q.atoms) [.base .unit] :=
  ⟨surfacePatTy_sound hq (by trivial) rfl, surfacePatTy_support (p := .var) (a := .base .unit) hq (by trivial) rfl⟩

theorem pattern_list {q : CheckFormation.Input} {P : Refinement.Program} (hq : q.Sound P) :
    PatTys P [.var, .const .unit] [.base .unit, .base .unit] [.base .unit] ∧
    Ty.SupportList (· ∈ q.atoms) [.base .unit] :=
  ⟨patTys_sound hq (by trivial) rfl, patTys_support (ps := [.var, .const .unit]) (as := [.base .unit, .base .unit]) hq (by trivial) rfl⟩

private def twoVariables : Pat := .list [.var, .var] none []
private def ordered : Alt := ⟨twoVariables, [0, 1]⟩
private def permuted : Alt := ⟨twoVariables, [1, 0]⟩
private def repeated : Alt := ⟨twoVariables, [0, 0]⟩

/-- 二つの実在する束縛の交換は受理し、重複した位置は拒否する。 -/
theorem alternatives_accept_reject (q : CheckFormation.Input) (P : Refinement.Program) :
    altsTy q P [ordered, permuted] (.list (.base .unit)) = some [.base .unit, .base .unit] ∧
    altsTy q P [ordered, repeated] (.list (.base .unit)) = none := by
  constructor <;> rfl

theorem alternatives_typed {q : CheckFormation.Input} {P : Refinement.Program} (hq : q.Sound P) :
    AltsTy P [ordered, permuted] (.list (.base .unit)) [.base .unit, .base .unit] ∧
    Ty.SupportList (· ∈ q.atoms) [.base .unit, .base .unit] := by
  have h := (alternatives_accept_reject q P).1
  exact ⟨altsTy_sound hq (by trivial) h, altsTy_support hq (by trivial) h⟩

private def field : FieldRef := ⟨"Box", "Box.Make", 0, .integer⟩
private def link : FieldLink := ⟨0, 0, [field], none⟩
private def constructorAlt : Alt := ⟨.con "Box.Make" [.var], [0]⟩

theorem field_path : BinderPath constructorAlt.pat 0 [field] := binderPathCheck_sound rfl

theorem field_path_computed : binderPathCheck [field] constructorAlt.pat 0 = true :=
  binderPathCheck_complete field_path

theorem field_links : LinksValid [constructorAlt] 1 [link] := (linksValid_spec _ _ _).mp rfl

theorem facts {q : CheckFormation.Input} {P : Refinement.Program} (hq : q.Sound P) :
    FactsWF P [] [] [.truth] := factsWF_sound (path := []) hq (by intro i a h; cases h) rfl

theorem observed_integer : scrutObservation [some (.base .integer)] = some (.var 0) ∧
    scrutObs [some (.base .integer)] = some (.var 0) :=
  ⟨rfl, (scrutObservation_eq _).symm.trans rfl⟩

theorem valid_source : Pattern.Valid (.list [.var] none []) ∧
    Pattern.Nontrivial (.unit) ∧ Alternative.Valid [⟨.unit, []⟩] := by decide

/-- 宣言表と支持の前提は、正常な空の表で同時に満たせる。 -/
theorem checked_pattern_input :
    PatTy declarations.core .var (.refined (.base .unit) .truth)
      [(Ty.refined (.base .unit) .truth).normWith input.atoms] ∧
    AltsTy declarations.core [ordered, permuted] (.list (.base .unit)) [.base .unit, .base .unit] ∧
    FactsWF declarations.core [] [] [.truth] :=
  ⟨(refined_variable input_sound).1, (alternatives_typed input_sound).1, facts input_sound⟩

end Benitoite.Release.Refinement.Surface.CheckPatternExamples
