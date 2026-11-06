import Benitoite

/-! 一般の check に対する閉じた評価の全域性の反例。
本番の定義を変えず、合成プログラムの Option の二構成子だけを使う。 -/
namespace Benitoite.Release.Refinement.F2ResumeEvidence
open Benitoite.Release.Refinement
noncomputable section
abbrev P := StandardModel.program []
def carrier : Ty := .data "Option" [.base .integer]
def field : FieldRef := ⟨"Option", "Option.Some", 0, .integer⟩
def predicate : Pred := .eq (.field field (.var 0)) (.integer 0)
def expected : Ty := .refined carrier predicate
def absent : Val := .con "Option.None" [.base .integer] []
def present (n : Benitoite.Release.Integer64Value) : Val := .con "Option.Some" [.base .integer] [.const (.integer n)]
theorem admits : PublicNames.checkAdmits [] [carrier,expected] := ⟨predicate,rfl⟩
theorem wellformed : expected.WF 0 0 0 := by
  simp [expected, carrier, predicate, Ty.WF, Ty.WFList, Pred.WF, Pred.VarsIn, Term.VarsIn, field, Ty.NotContCore, Ty.core]
theorem sorted : expected.Sorted [] := by
  simp [expected, carrier, predicate, Ty.Sorted, sortedTys, Pred.Sorted, Term.HasSort, Term.References, Term.VarsIn, Ctx.Readable, Term.Shape, Ty.HasSort, Ty.sort?, field, Ordinary, Ty.core]
theorem source : predicate.Source := by trivial
theorem field_declared : FieldRef.Declared P [] [some carrier] (.var 0) field := by
  refine ⟨[.base .integer], ⟨"Option",1,[.tvar 0]⟩, .tvar 0, ?_, rfl, rfl, rfl, rfl, ?_, rfl⟩
  · exact .var rfl rfl
  · simp [Ty.WF]
theorem predicate_declared : predicate.Declared P [] [] (some carrier) := by
  exact ⟨⟨by exact ⟨carrier,rfl,by trivial⟩, field_declared⟩, trivial⟩
theorem carrier_annotation : carrier.Annotation P [] [] := by
  refine ⟨by simp [carrier, Ty.WF, Ty.WFList], by simp [carrier, Ty.Sorted, sortedTys], ?_⟩
  exact ⟨⟨1, (StandardModel.option_declarations []).arity, rfl⟩, trivial, trivial⟩
theorem expected_annotation : expected.Annotation P [] [] :=
  ⟨wellformed, sorted, carrier_annotation.declared, predicate_declared⟩
theorem absent_typed (B : Builtins) (Ψ : StoreTy) :
    HasTypeVQ P B Ψ Qempty [] [] [] absent carrier := by
  have ds := StandardModel.option_declarations []
  exact StandardScalar.scalarOption_typed (α := Unit) P B Ψ .integer (fun _ => .const (.integer ⟨0,by decide⟩)) none
    ds.some_decl ds.none_decl ds.arity (fun _ => .V_Const trivial)
theorem expected_kind : expected.HasKind P [] .value := by
  refine ⟨?_, ?_⟩
  · exact ⟨(TyCon.arity_data (StandardModel.option_declarations []).arity), trivial, trivial⟩
  · intro _; simp [carrier, Ty.core]
theorem admits_normalized : PublicNames.checkAdmits [] (Ty.normTys [carrier,expected]) := by
  exact ⟨predicate, rfl⟩
theorem closed_absent_undecided :
    (predicate.open (.dataValue "Option.None" [])).evalClosed = none := by rfl
theorem closed_absent_sorted :
    (predicate.open (.dataValue "Option.None" [])).Sorted [] none := by
  simp [predicate, Pred.open, predBind, termBind, termBind?, Pred.Sorted, Term.HasSort,
    Term.References, Term.VarsIn, varsInSlots, Term.Shape, field]
theorem closed_absent_declared :
    (predicate.open (.dataValue "Option.None" [])).Declared P [] [] none := by
  refine ⟨⟨⟨trivial, ⟨⟨"Option",1,[]⟩,rfl,rfl⟩⟩, ?_⟩, trivial⟩
  refine ⟨[.base .integer], ⟨"Option",1,[.tvar 0]⟩, .tvar 0, ?_, rfl, rfl, rfl, rfl, ?_, rfl⟩
  · exact .value rfl rfl rfl rfl
  · simp [Ty.WF]
theorem absent_closed_wf :
    (predicate.open (.dataValue "Option.None" [])).WF 0 := by
  simp [predicate, Pred.open, predBind, termBind, termBind?, Pred.WF, Pred.VarsIn, Term.VarsIn, varsInSlots]

theorem present_typed (B : Builtins) (Ψ : StoreTy) (n : Benitoite.Release.Integer64Value) :
    HasTypeVQ P B Ψ Qempty [] [] [] (present n) carrier := by
  have ds := StandardModel.option_declarations []
  exact StandardScalar.scalarOption_typed P B Ψ .integer (fun x => .const (.integer x)) (some n)
    ds.some_decl ds.none_decl ds.arity (fun _ => .V_Const trivial)

theorem absent_undecided : predicate.evalWith (selfModel (fun _ => none) absent) = none := by
  rfl
theorem present_true : predicate.evalWith (selfModel (fun _ => none) (present ⟨0, by decide⟩)) = some true := by rfl
theorem present_false : predicate.evalWith (selfModel (fun _ => none) (present ⟨1, by decide⟩)) = some false := by rfl
/-- 短絡の検査がある述語では、欄のない正常値にも真偽を決められる。 -/
theorem guarded_absent :
    (Pred.or (.constructorIs (.var 0) "Option.None") predicate).evalWith
      (selfModel (fun _ => none) absent) = some true ∧
    (Pred.and (.constructorIs (.var 0) "Option.Some") predicate).evalWith
      (selfModel (fun _ => none) absent) = some false := ⟨rfl,rfl⟩

/-- 整形式の篩・型付きの正常値・許容だけでは、閉じた評価の全域性を得られない。 -/
theorem totality_obstruction (B : Builtins) (Ψ : StoreTy) :
    ¬ (∀ (a : Ty) (p : Pred) (v : Val),
      a.Annotation P [] [] → (Ty.refined a p).Annotation P [] [] →
      PublicNames.checkAdmits [] [a, .refined a p] →
      HasTypeVQ P B Ψ Qempty [] [] [] v a →
      ∃ b, p.evalWith (selfModel (fun _ => none) v) = some b) := by
  intro h
  obtain ⟨b, hb⟩ := h carrier predicate absent carrier_annotation expected_annotation admits (absent_typed B Ψ)
  rw [absent_undecided] at hb
  cases hb

end
end Benitoite.Release.Refinement.F2ResumeEvidence
