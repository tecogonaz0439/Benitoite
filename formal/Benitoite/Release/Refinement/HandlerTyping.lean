import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.AtPatterns

namespace Benitoite.Release.Refinement


/-- 専用発行へ進む前の通常の操作は、他の効果と同じ節の署名を持つ。 -/
theorem Builtins.CoreAssumptions.pathBases_clause_signature {P B b s eb}
    (h : Builtins.CoreAssumptions P B) (hl : B.sig b=some s) (hk : s.kind=.pathBases) :
    ∃ sg, ClauseSig P B eb (.prim b) sg ∧ sg.tparams=[] ∧ sg.params=[] ∧ sg.ret=.pathBases ∧ sg.WF := by
  have hs := h.pathBases_shape b s hl hk
  let sg : OpSig := ⟨[],s.names,[],.pathBases,processEnvironmentEff⟩
  refine ⟨sg,ClauseSig.of_opSig ?_ ?_,rfl,rfl,rfl,?_⟩
  · simp only [opSig,opSigAt,hl,hs.operation,hs.types,hs.arguments,List.map_nil,
      Option.map_some,hs.result]
    rfl
  · intro b' s' ho hl'
    cases ho
    have he := Option.some.inj (hl.symm.trans hl')
    subst s'
    simp [PrimSig.tel, signatureTel, hs.arguments, hs.result, hs.effect, hs.rows,
      Ty.RowsIn, Ty.RowsInList, Tel.RowsIn, Eff.RowsIn, processEnvironmentEff, Eff.single]
  · exact ⟨trivial,trivial⟩

private theorem resume_location_inv {P B Ψ Q C Γ Φ R m t e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m t e L) :
    ∀ l v,m=.resume (.loc l) v → ∃ b t e R', Ψ l=some (.cont b t e R') ∧ R'.map Ty.norm = R.map Ty.norm := by
  match h with
  | .C_ResumeL hl _ _ => intro l v he; cases he; exact ⟨_,_,_,_,hl,rfl⟩
  | .C_ResumeLNorm hl hr _ _ => intro l v he; cases he; exact ⟨_,_,_,_,hl,hr⟩
  | .C_Normal hm | .C_Sub hm _ _ _ _ _ | .C_Eff hm _ => exact resume_location_inv hm
  | .C_Return _ | .C_Let _ _ _ | .C_DependentApp .. | .C_App _ _ | .C_If _ _ _ _ | .C_Match _ _ _ _ _ |
    .C_BuilderLet _ _ _ _ | .C_BuilderOp _ _ _ _ | .C_Lazy _ _ | .C_Escape _ _ |
    .C_Use _ _ _ _ | .C_Handle _ _ _ | .C_Handle_Fail _ _ _ _ | .C_Resume _ _ _ | .C_ResumeNorm _ _ _ |
    .C_Meth _ _ _ _ _ _ _ _ _ _ | .C_External _ _ _ _ | .C_IssuePathBases _ _ _ _ _ _ _ _ |
    .C_CheckAt _ => intro l v he; cases he

/-- 部分型・効果拡大・正規化の下でも、格納されたRと結論のRの正規形は一致する。 -/
theorem HasTypeCQ.resume_location_contract {P B Ψ Q C Γ Φ R l v t e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) t e L) :
    ∃ b t e R', Ψ l=some (.cont b t e R') ∧ R'.map Ty.norm = R.map Ty.norm := resume_location_inv h l v rfl

end Benitoite.Release.Refinement
