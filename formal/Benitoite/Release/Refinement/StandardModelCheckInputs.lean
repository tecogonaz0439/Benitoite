import Benitoite.Release.Refinement.StandardModelCollectionInputs

/-! # 一般の検査の正常な入力と閉じた評価の三つの結果 -/
namespace Benitoite.Release.Refinement.RefinementCheck
open StandardModel
noncomputable section

/-- 基の型・篩付き期待型・同じ値から、全 BuiltinArgs を構成する。 -/
theorem arguments {P B Ψ t u v} (hp : Declarations P)
    (ht : Ty.Annotation P [] [] t) (hu : Ty.Annotation P [] [] u)
    (kt : Ty.HasKind P [] t .value) (ku : Ty.HasKind P [] u .value)
    (ot : Ordinary t) (ou : Ordinary u) (nt : t.norm = t) (nu : u.norm = u)
    (admits : PublicNames.checkAdmits [] [t,u])
    (typed : HasTypeVQ P B Ψ Qempty [] [] [] v t) (ground : v.Ground) :
    BuiltinArgs P B Ψ PublicNames.checkName signature [t,u] [] [] [v] (result u) Eff.empty := by
  have hr : P.DataArity "Result" 2 := (hp.file ScopeDeclarations.result (by simp [ScopeDeclarations.file])).1
  have he := error_annotation hp
  have ret : Ty.Annotation P [] [] (result u) :=
    ⟨⟨hu.wf,he.wf,trivial⟩,⟨hu.sorted,he.sorted,trivial⟩,
      ⟨⟨2,hr,rfl⟩,hu.declared,he.declared,trivial⟩⟩
  have ann : Ty.Annotation P [] [] (.fn ["value"] [t] (result u) Eff.empty) :=
    ⟨⟨by simp [NamesWF],⟨ht.wf,trivial⟩,ret.wf,by simp [Eff.WF,Eff.empty,Ty.WFList],rfl⟩,
      ⟨⟨ht.sorted,trivial⟩,ret.sorted,trivial⟩,
      ⟨⟨ht.declared,trivial⟩,ret.declared,trivial⟩⟩
  refine arguments_of_toTel ?_ ?_ ?_ ?_ ?_ (instantiated t u hu.wf nt nu) ann ?_ ?_ ret.wf rfl
    (by simp [Eff.WF,Eff.empty,Ty.WFList]) (.cons typed .nil) ?_ ?_
  · constructor
    · rfl
    · simpa only [Ty.normTys,nt,nu] using (show signature.admits (TypeCtx.constraints []) [t,u] from admits)
    · intro a ha
      rcases (by simpa only [List.mem_cons,List.not_mem_nil,or_false] using ha : a = t ∨ a = u) with rfl | rfl
      · exact ⟨ht.wf,ot⟩
      · exact ⟨hu.wf,ou⟩
    · rfl
    · intro e he; cases he
    · simp [signature,Eff.RowsIn,Eff.empty,Ty.RowsInList]
    · simp [signature,result,errorType,Qsig,QTy,QTys,QEff,Eff.empty,Qempty]
    · simp [signature,result,errorType,RowTransport,Qsig,QTy,QTys,QEff,Qempty,Eff.empty]
    · simp [signature,result,errorType,PrimSig.tel,signatureTel,Tel.RowsIn,Ty.RowsIn,Ty.RowsInList,Eff.RowsIn,Eff.empty]
  · simp [Builtins.RangeAdmissible,signature]
  · simp [signature,result,errorType,PrimSig.tel,signatureTel,Tel.instR,Tel.substRAt,Tel.mapRanges,
      Tel.norm,Ty.norm,Ty.normTys,Ty.WF,Tel.WF,Ty.WFList,Eff.WF,Eff.empty,Eff.Canonical,Eff.norm]
  · refine ⟨rfl,?_⟩
    rintro (_|(_|i)) a k ha hk
    · cases ha; cases hk; exact ⟨kt,fun _ => ot⟩
    · cases ha; cases hk; exact ⟨ku,fun _ => ou⟩
    · simp at ha
  · intro a ha
    rcases (by simpa only [List.mem_cons,List.not_mem_nil,or_false] using ha : a = t ∨ a = u) with rfl | rfl
    · exact ht
    · exact hu
  · simp [Ty.normTys,nt]
  · simp [result,errorType,Ty.norm,Ty.normTys,nu]
  · intro w hw; cases List.mem_singleton.mp hw; exact ground
  · intro a ha
    rcases (by simpa only [List.mem_cons,List.not_mem_nil,or_false] using ha : a = t ∨ a = u) with rfl | rfl
    · exact ⟨ht.wf,nt⟩
    · exact ⟨hu.wf,nu⟩

def nonnegative : Ty := .refined (.base .integer) (.le (.integer 0) (.var 0))

/-- 正負の整数は、同じ公開の型引数・入力型で検査に渡せる。 -/
theorem integer_inputs (externals : List (ExternalKey × ExternalDecl)) (n : Integer64Value) :
    BuiltinArgs (program externals) (builtins (program externals)) StoreTy.empty PublicNames.checkName
      signature [.base .integer,nonnegative] [] [] [.const (.integer n)] (result nonnegative) Eff.empty := by
  refine arguments (check_declarations externals) ⟨trivial,trivial,trivial⟩ ?_ trivial
    (by simp [nonnegative,Ty.HasKind,Ty.NotContCore,Ty.core])
    (by intro b t e h; cases h) (by intro b t e h; cases h) rfl rfl ⟨_,rfl⟩ (.V_Const trivial) trivial
  constructor
  · simp [nonnegative,Ty.WF,Pred.WF,Pred.VarsIn,Term.VarsIn,Ty.NotContCore,Ty.core]
  · simp [nonnegative,Ty.Sorted,Pred.Sorted,Term.HasSort,Term.References,Term.VarsIn,
      Ctx.Readable,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
  · simp [nonnegative,Ty.Declared,Pred.Declared,Term.Declared,Ctx.declarationSelf,Ctx.Readable,Ctx.extend,Ty.shiftV,Ordinary]

/-- Ok と CheckError は同じ全入力条件で、篩の閉じた評価の真偽に従って分かれる。 -/
theorem integer_accept_reject (render : Ty → String) :
    delta render PublicNames.checkName [.base .integer,nonnegative] [] [] [.const (.integer ⟨1,by decide⟩)] =
      some (.val (ok nonnegative (.const (.integer ⟨1,by decide⟩)))) ∧
    delta render PublicNames.checkName [.base .integer,nonnegative] [] [] [.const (.integer ⟨-1,by decide⟩)] =
      some (.val (rejected nonnegative (render nonnegative))) := by
  constructor
  · simpa [delta] using congrArg some
      (run_ok (render := render) (t := .base .integer) (u := nonnegative)
        (v := .const (.integer ⟨1,by decide⟩)) rfl (by decide))
  · simp +decide [delta,run,nonnegative,Ty.core]


/-- 合成表の行の全称契約を、正負の整数を含む具体の入力へ当てる。 -/
example (externals : List (ExternalKey × ExternalDecl)) (n : Integer64Value) :
    ∃ out, (builtins (program externals)).delta PublicNames.checkName [.base .integer,nonnegative] [] []
        [.const (.integer n)] = some out ∧ (∀ i, out ≠ .exit i) ∧
      Outcome.Typed (program externals) (builtins (program externals)) StoreTy.empty out (result nonnegative) ∧
      AdequateResult [.const (.integer n)] out :=
  (scope_rows externals .p392 rfl) StoreTy.empty signature [.base .integer,nonnegative] [] []
    [.const (.integer n)] (result nonnegative) Eff.empty (row_lookup _ .p392) (integer_inputs externals n)

namespace OptionField

def carrier : Ty := .data "Option" [.base .integer]
def field : FieldRef := ⟨"Option","Option.Some",0,.integer⟩
def predicate : Pred := .eq (.field field (.var 0)) (.integer 0)
def expected : Ty := .refined carrier predicate
def absent : Val := .con "Option.None" [.base .integer] []

private theorem annotation (externals : List (ExternalKey × ExternalDecl)) :
    Ty.Annotation (program externals) [] [] carrier ∧
    Ty.Annotation (program externals) [] [] expected := by
  have hc : carrier.Annotation (program externals) [] [] :=
    ⟨by trivial,by trivial,⟨⟨1,(option_declarations externals).arity,rfl⟩,trivial,trivial⟩⟩
  refine ⟨hc,?_,?_,hc.declared,?_⟩
  · simp [expected,carrier,predicate,field,Ty.WF,Ty.WFList,Pred.WF,Pred.VarsIn,Term.VarsIn,
      Ty.NotContCore,Ty.core]
  · simp [expected,carrier,predicate,field,Ty.Sorted,sortedTys,Pred.Sorted,Term.HasSort,
      Term.References,Term.VarsIn,Ctx.Readable,Term.Shape,Ty.HasSort,Ty.sort?,Ordinary,Ty.core]
  · refine ⟨⟨by exact ⟨carrier,rfl,by trivial⟩,?_⟩,trivial⟩
    refine ⟨[.base .integer],⟨"Option",1,[.tvar 0]⟩,.tvar 0,?_,rfl,rfl,rfl,rfl,?_,rfl⟩
    · exact .var rfl rfl
    · simp [Ty.WF]

/-- 評価不能となる正常な None も、全入力条件を満たして CheckError を返す。 -/
theorem undecided (externals : List (ExternalKey × ExternalDecl)) (render : Ty → String) :
    BuiltinArgs (program externals) (builtins (program externals)) StoreTy.empty PublicNames.checkName
      signature [carrier,expected] [] [] [absent] (result expected) Eff.empty ∧
    (predicate.open (.dataValue "Option.None" [])).evalClosed = none ∧
    delta render PublicNames.checkName [carrier,expected] [] [] [absent] =
      some (.val (rejected expected (render expected))) := by
  have ann := annotation externals
  have kc : carrier.HasKind (program externals) [] .value :=
    ⟨TyCon.arity_data (option_declarations externals).arity,trivial,trivial⟩
  have ku : expected.HasKind (program externals) [] .value :=
    ⟨kc,by intro _; simp [carrier,Ty.core]⟩
  have typed : HasTypeVQ (program externals) (builtins (program externals)) StoreTy.empty Qempty [] [] []
      absent carrier := by
    have ds := option_declarations externals
    exact StandardScalar.scalarOption_typed (α := Unit) _ _ _ .integer
      (fun _ => .const (.integer ⟨0,by decide⟩)) none ds.some_decl ds.none_decl ds.arity
      (fun _ => .V_Const trivial)
  refine ⟨arguments (check_declarations externals) ann.1 ann.2 kc ku
    (by intro b t e h; cases h) (by intro b t e h; cases h) rfl rfl ⟨predicate,rfl⟩ typed
      (by simp [absent,Val.Ground,Val.ClosedAt,Val.ClosedList,Ty.WF]),rfl,?_⟩
  have hr := run_refined_rejected (render := render) (t := carrier) (a := carrier)
    (p := predicate) (v := absent) (term := .dataValue "Option.None" []) rfl rfl (Or.inr rfl)
  simpa [delta,expected] using congrArg some hr

end OptionField

end
end Benitoite.Release.Refinement.RefinementCheck
