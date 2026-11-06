import Benitoite.Release.Refinement.ProgramWellFormed
import Benitoite.Release.Refinement.Patterns

/-! 静的な構成子パターンだけから束縛の注釈を得る補題に対する確認入力。 -/
namespace Benitoite.Release.Refinement.PatternContextObstruction
noncomputable section

def field : Ty := .refined (.tvar 0) (.not .falsity)
def declaration : ConDecl := ⟨"Box", 1, [field]⟩
def program : Program where
  defs := fun _ => none
  cons := fun c => if c = "Box" then some declaration else none
  ops := fun _ => none
  effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none

theorem lookup : program.cons "Box" = some declaration := by simp [program]

theorem lookup_eq {c cd} (h : program.cons c = some cd) : cd = declaration := by
  simp only [program] at h
  split at h
  · exact Option.some.inj h.symm
  · cases h

theorem arity : program.DataArity "Box" 1 := by
  refine ⟨⟨"Box", declaration, lookup, rfl⟩, ?_⟩
  intro c cd h _
  cases lookup_eq h
  rfl

def continuation : Ty := .cont (.base .unit) (.base .unit) Eff.empty
def scrutinee : Ty := .data "Box" [continuation]
def binding : Ty := .refined continuation (.not .falsity)

theorem continuation_annotation {Γ : Ctx} : Ty.Annotation program [] Γ continuation := by
  exact ⟨⟨trivial, trivial, trivial, rfl⟩, ⟨trivial, trivial, trivial⟩,
    ⟨trivial, trivial, trivial⟩⟩

theorem scrutinee_annotation {Γ : Ctx} : Ty.Annotation program [] Γ scrutinee := by
  exact ⟨⟨continuation_annotation.wf, trivial⟩,
    ⟨continuation_annotation.sorted, trivial⟩,
    ⟨⟨1, arity, rfl⟩, continuation_annotation.declared, trivial⟩⟩

theorem scrutinee_kinded : Ty.HasKind program [] scrutinee .value := by
  exact ⟨TyCon.arity_data arity, ⟨⟨trivial, trivial, trivial⟩, trivial⟩⟩

theorem field_wf : field.WF 0 1 0 := by
  refine ⟨by change 0 < 1; decide, trivial, ?_⟩
  intro b t e h
  cases h

theorem field_subst : field.subst [continuation] [] = binding := rfl

theorem pattern_typed : PatTy program (.con "Box" [.var]) scrutinee [binding] := by
  apply PatTy.P_Con lookup rfl
  · intro a ha
    cases List.mem_singleton.mp ha
    exact field_wf
  · change PatTys program [.var] [field.subst [continuation] []] [binding]
    rw [field_subst]
    exact .cons .P_Var .nil

theorem binding_not_wf {nr nt nv} : ¬ binding.WF nr nt nv := by
  intro h
  exact h.2.2 (.base .unit) (.base .unit) Eff.empty rfl

theorem bindings_not_annotations {Γ : Ctx} : ¬ TypeAnnotations program [] Γ [binding] := by
  intro h
  exact binding_not_wf (h binding List.mem_cons_self).wf

theorem field_annotation :
    Ty.Annotation program [TypeCtx.valueParam] [] field := by
  exact ⟨field_wf, ⟨trivial, trivial⟩, ⟨trivial, trivial⟩⟩

theorem field_kinded : Ty.HasKind program [.value] field .value := by
  refine ⟨rfl, ?_⟩
  intro b t e h
  cases h

theorem external_wf : program.ExternalWF := by
  exact ⟨List.nodup_nil, by intro key decl h; cases h⟩

theorem program_wellFormed : program.WellFormed := by
  refine ⟨(by intro f d h; cases h), ?_, (by intro o d h; cases h),
    (by intro cl d h; cases h), (by intro i d h; cases h), ?_, external_wf⟩
  · intro c cd h
    cases lookup_eq h
    refine ⟨arity, ?_⟩
    intro a ha
    cases List.mem_singleton.mp ha
    exact ⟨⟨field_wf, trivial, trivial⟩, field_annotation, field_kinded⟩
  · intro d info h
    cases h

theorem program_wellTyped (B : Builtins) : program.WellTyped B := by
  refine ⟨⟨?_, ?_⟩, external_wf, (by intro f d h; cases h),
    (by intro i d h; cases h)⟩
  · intro d info h
    cases h
  · intro c cd h
    cases lookup_eq h
    refine ⟨(by intro info h; cases h), ?_⟩
    intro a ha
    cases List.mem_singleton.mp ha
    refine ⟨field_annotation, field_kinded, ?_⟩
    exact ⟨.invariant, rfl, trivial⟩

theorem scrutinee_typed (B : Builtins) :
    HasTypeVQ program B StoreTy.empty Qempty []
      (Ctx.extend [] scrutinee) [] (.var 0) scrutinee := by
  refine .V_Var rfl ?_
  intro b t e h
  cases h

theorem context_regular : Ctx.Regular program [] (Ctx.extend [] scrutinee) :=
  (show Ctx.Regular program [] [] from ⟨by simp [Ctx.WF], by simp [Ctx.Sorted],
    by simp [Ctx.Declared], by simp [Ctx.Ordered]⟩).extend scrutinee_annotation

/-- コア型の継続を型引数へ許した場合、静的な文脈形成だけでは束縛の注釈を得ない。
表層の型構文からこの継続型を直接記述することはできない。 -/
theorem obstruction (B : Builtins) :
    program.WellFormed ∧ program.WellTyped B ∧
    Ctx.Regular program [] (Ctx.extend [] scrutinee) ∧
    Ty.Annotation program [] (Ctx.extend [] scrutinee) scrutinee ∧
    Ty.HasKind program [] scrutinee .value ∧
    HasTypeVQ program B StoreTy.empty Qempty []
      (Ctx.extend [] scrutinee) [] (.var 0) scrutinee ∧
    PatTy program (.con "Box" [.var]) scrutinee [binding] ∧
    ¬ TypeAnnotations program [] (Ctx.extend [] scrutinee) [binding] :=
  ⟨program_wellFormed, program_wellTyped B, context_regular, scrutinee_annotation,
    scrutinee_kinded, scrutinee_typed B, pattern_typed, bindings_not_annotations⟩

end
end Benitoite.Release.Refinement.PatternContextObstruction
