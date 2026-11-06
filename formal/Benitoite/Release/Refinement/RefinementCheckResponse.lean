import Benitoite.Release.Refinement.RefinementCheck

/-! # 明示的な検査の全入力に対する Result の型付け -/
namespace Benitoite.Release.Refinement.RefinementCheck
open ScopeDeclarations
noncomputable section

/-- 誤りの有限宣言と Result は、同じプログラムの lookup から供給する。 -/
structure Declarations (P : Program) : Prop where
  file : HasFile P
  error : P.cons "Refinement.CheckError" = some PublicNames.checkErrorDecl
  arity : P.DataArity "Refinement.CheckError" 0

theorem error_annotation {P} (h : Declarations P) : Ty.Annotation P [] [] errorType :=
  ⟨trivial,trivial,⟨⟨0,h.arity,rfl⟩,trivial⟩⟩

private theorem error_typed {P B Ψ} (h : Declarations P) (s : String) :
    HasTypeVQ P B Ψ Qempty [] [] [] (errorValue s) errorType := by
  refine .V_Con h.error rfl ⟨rfl,by intro i t k ht; cases i <;> cases ht⟩ ?_
    (.cons (.V_Const trivial) .nil) (error_annotation h)
  intro t ht; cases List.mem_singleton.mp ht; trivial

/-- 閉じた正規形の二つの型引数で具体化した依存列。 -/
theorem instantiated (t u : Ty) (hu : u.WF 0 0 0)
    (nt : t.norm = t) (nu : u.norm = u) :
    instantiatedTel (Tel.instR [] signature.tel) [t,u] [] =
      Ty.toTel ["value"] [t] (result u) Eff.empty := by
  simp [signature,result,errorType,PrimSig.tel,signatureTel,instantiatedTel,Tel.instR,
    Tel.substRAt,Tel.mapRanges,
    Tel.bind,Tel.rawBind,Ty.rawBind,rawBindTys,Eff.rawBind,Tel.norm,Ty.norm,Ty.normTys,
    Eff.norm,Eff.empty,typeEnvAt,SubstEnv.up,substAtoms_nil,instAtoms_nil,rowFails,
    Ty.toTel,Ty.shiftV,Eff.shiftV,nt,nu,Ty.shiftV_of_wf_zero hu]

/-- 任意の表の型付き入力から、同じ検査の δ の非終了応答を得る。 -/
theorem response {P B Ψ ts es rs ws a e} (hp : Declarations P) (render : Ty → String)
    (args : BuiltinArgs P B Ψ PublicNames.checkName signature ts es rs ws a e) :
    ∃ out, delta render PublicNames.checkName ts es rs ws = some out ∧
      Outcome.Typed P B Ψ out a ∧ AdequateResult ws out ∧ ∀ n, out ≠ .exit n := by
  have es0 : es = [] := List.length_eq_zero_iff.mp args.admissible.rowCount
  have rs0 : rs = [] := List.length_eq_zero_iff.mp args.ranges.1
  subst es; subst rs
  obtain ⟨t,u,rfl⟩ : ∃ t u, ts = [t,u] := by
    have hc := args.admissible.typeCount
    cases ts with | nil => cases hc | cons t ts => cases ts with
    | nil => cases hc
    | cons u ts => cases ts with | nil => exact ⟨t,u,rfl⟩ | cons => cases hc
  have annT := args.signature.types t (by simp)
  have au := args.signature.types u (by simp)
  have nt : t.norm = t := (args.types t (by simp)).2
  have nu : u.norm = u := (args.types u (by simp)).2
  have argTel := args.arguments
  rw [instantiated t u au.wf nt nu] at argTel
  obtain ⟨inputs,ar,_⟩ := argTel.toTelValues (by simp [NamesWF])
  rw [show (result u).norm = result u by simp [result,errorType,Ty.norm,Ty.normTys,nu]] at ar
  have ha : a = result u := args.result.2.symm.trans ar
  subst a
  rw [show Ty.normTys [t] = [t] by simp [Ty.normTys,nt]] at inputs
  cases inputs with | cons typed rest =>
    cases rest
    rename_i v
    have ku : Ty.HasKind P [] u .value :=
      (args.signature.kinds.2 1 u .value rfl rfl).1
    have ou : Ordinary u := args.signature.ordinary u (by simp)
    have ground := args.ground v (by simp)
    have adequate : AdequateResult [v] (.val v) := by intro σ _ hs; exact hs v (by simp)
    have ne : errorType.norm = errorType := rfl
    have ke : Ty.HasKind P [] errorType .value := ⟨TyCon.arity_data hp.arity,trivial⟩
    have oe : Ordinary errorType := by intro b t e h; cases h
    by_cases hc : t.core = u.core ∧ accepts v u = true
    · have vt := to_core annT typed
      rw [hc.1] at vt
      have vu := accepted_typed au vt hc.2
      obtain ⟨outTyped,outAdequate,_,nonexit⟩ := ScopeDelta.result_safe hp.file true au (error_annotation hp)
        ku ke nu ne ou oe vu ground adequate
      exact ⟨.val (ok u v),by simp [delta,run,hc],outTyped,outAdequate,nonexit⟩
    · have ge : (errorValue (render u)).Ground := by
        simp [errorValue,Val.Ground,Val.ClosedAt,Val.ClosedList]
      have ae : AdequateResult [v] (.val (errorValue (render u))) := by intro σ _ _; exact ⟨trivial,trivial⟩
      obtain ⟨outTyped,outAdequate,_,nonexit⟩ := ScopeDelta.result_safe hp.file false au (error_annotation hp)
        ku ke nu ne ou oe (error_typed hp _) ge ae
      exact ⟨.val (rejected u (render u)),by simp [delta,run,hc],outTyped,outAdequate,nonexit⟩

end
end Benitoite.Release.Refinement.RefinementCheck
