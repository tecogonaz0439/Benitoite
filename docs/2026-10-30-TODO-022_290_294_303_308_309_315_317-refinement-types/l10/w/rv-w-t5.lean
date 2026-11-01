import Benitoite.Release.Refinement.ProgramWellFormed
/-! 二つの入口が読まない条件の確認。 -/
namespace Benitoite.Release.Refinement.RVW5
open Benitoite.Release.Refinement
noncomputable section
def unit : Ty := .base .unit
def P0 : Program := {
  defs := fun _ => none, cons := fun _ => none, ops := fun _ => none, effects := fun _ => none
  classes := fun _ => none
  impls := fun _ => none }

@[simp] theorem annotation_iff (P : Program) (C : List TParam) (Γ : Ctx) (a : Ty) :
    Ty.Annotation P C Γ a ↔ a.WF 0 C.length Γ.length ∧ a.Sorted Γ ∧ a.Declared P C Γ :=
  ⟨fun h => ⟨h.wf, h.sorted, h.declared⟩, fun h => ⟨h.1, h.2.1, h.2.2⟩⟩

-- 辞書の引数の型は Annotation だけを読み、宣言のない型クラスを通す。
theorem ghost_dict_annotated : TypeAnnotations P0 [{}] [] [.dict "Ghost" (.tvar 0)] := by
  intro a ha
  simp at ha
  subst a
  constructor <;> simp [Ty.WF, Ty.Sorted, Ty.Declared]
theorem ghost_dict_not_kinded : ¬ Ty.HasKind P0 [.value] (.dict "Ghost" (.tvar 0)) .value := by
  rintro ⟨cd, hc, _⟩
  cases hc

-- 操作の dictParams と params の先頭の対応は OpDecl.Scoped が読まない。
def op : OpDecl := ⟨"E", [{}], ["x"], [unit], unit, [("C", 0)]⟩
theorem op_scoped_without_dictionary_prefix : op.Scoped P0 := by
  refine ⟨by simp [NamesWF, op], ?_, ?_⟩
  · intro p hp; simp [op] at hp; subst p; simp [op]
  · constructor <;> simp [Ty.SourceScoped, Ty.RangesScoped, Tel.RangesScoped, Eff.RangesScoped, rangesScopedTypes, RangeIx.WF, Ty.WF, Tel.WF, Eff.WF, Ty.WFList, Eff.Canonical, Eff.norm, Ty.normTys, Ty.Sorted, Tel.Sorted, sortedEff, sortedTys, Ty.Declared, Tel.Declared, declaredEff, declaredTys, signatureTel, unit, op, OpDecl.tel, Eff.RowsIn, Ty.RowsInList, Tel.RowsIn, Ty.RowsIn, Ty.HasKind, kindsTel, kindsEff, kindsList]
    intro name ix hi
    cases ix with
    | fixed r => trivial
    | rvar i => cases hi

-- 行変数を含む公開境界は VarianceOK を通り、MetadataScoped で拒まれる。
def rowBoundary : Ty := .fn [] [] unit (Eff.row 0)
def info : DataVarianceDecl := ⟨0, [], [], [(.positive, rowBoundary)]⟩
def P1 : Program := { P0 with dataInfo := fun d => if d = "Box" then some info else none }
theorem boundary_row_variance : rowBoundary.VarianceOK P1 [] .positive := by
  simp [rowBoundary, unit, Ty.VarianceOK, varianceTysOK, Eff.VarianceOK, Eff.row]
theorem boundary_row_rejected : ¬ P1.MetadataScoped := by
  intro h
  have hs := ((h "Box" info (by simp [P1])).2.2 rowBoundary (by simp [info])).1.2.1
  have hr := hs.2.2.1 0 (by simp [Eff.row])
  exact Nat.not_lt_zero 0 hr
end
end Benitoite.Release.Refinement.RVW5
