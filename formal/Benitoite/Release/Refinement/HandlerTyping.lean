import Benitoite.Release.Refinement.SubstTyping
import Benitoite.Release.Refinement.AtPatterns

namespace Benitoite.Release.Refinement

/-- 専用発行へ進む前の通常の操作は、他の効果と同じ節の署名を持つ。 -/
theorem Builtins.CoreAssumptions.pathBases_clause_signature {P B b s eb}
    (h : Builtins.CoreAssumptions P B) (hl : B.sig b=some s) (hk : s.kind=.pathBases) :
    ∃ sg, ClauseSig P B eb (.prim b) sg ∧ sg.tparams=[] ∧ sg.params=[] ∧ sg.ret=.pathBases ∧ sg.WF := by
  have hs := h.pathBases_shape b s hl hk
  let sg : OpSig := ⟨[],s.names,[],.pathBases,processEnvironmentEff⟩
  refine ⟨sg,ClauseSig.of_opSig ?_,rfl,rfl,rfl,?_⟩
  · simp only [opSig,opSigAt,hl,hs.operation,hs.types,hs.arguments,List.map_nil,
      Option.map_some,hs.result]
    rfl
  · exact ⟨trivial,trivial⟩

private theorem resume_location_inv {P B Ψ Q C Γ Φ R m t e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R m t e L) :
    ∀ l v,m=.resume (.loc l) v → ∃ b t e,Ψ l=some (.cont b t e R) := by
  match h with
  | .C_ResumeL hl _ _ => intro l v he; cases he; exact ⟨_,_,_,hl⟩
  | .C_Sub hm _ _ _ _ _ | .C_Eff hm _ => exact resume_location_inv hm
  | .C_Return _ | .C_Let _ _ _ | .C_DependentApp .. | .C_App _ _ | .C_If _ _ _ | .C_Match _ _ _ |
    .C_BuilderLet _ _ _ _ | .C_BuilderOp _ _ _ _ | .C_Lazy _ _ | .C_Escape _ _ |
    .C_Use _ _ _ _ | .C_Handle _ _ _ | .C_Handle_Fail _ _ _ _ | .C_Resume _ _ _ |
    .C_Meth _ _ _ _ _ _ _ _ _ _ | .C_External _ _ _ _ | .C_IssuePathBases _ _ _ _ _ _ _ _ |
    .C_CheckAt _ => intro l v he; cases he

/-- 部分型と効果拡大の下でも、継続場所に格納されたRは結論のRに一致する。 -/
theorem HasTypeCQ.resume_location_contract {P B Ψ Q C Γ Φ R l v t e L}
    (h : HasTypeCQ P B Ψ Q C Γ Φ R (.resume (.loc l) v) t e L) :
    ∃ b t e,Ψ l=some (.cont b t e R) := resume_location_inv h l v rfl

end Benitoite.Release.Refinement
