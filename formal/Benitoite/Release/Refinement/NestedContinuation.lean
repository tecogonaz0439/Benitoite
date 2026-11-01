import Benitoite.Release.Refinement.ClosureTyping
import Benitoite.Release.Refinement.ValueFacts
import Benitoite.Release.Refinement.RuntimeMatch

/-! 入れ子の継続を含む List の値（設計書 07-04「01-12 との対応」）。 -/
namespace Benitoite.Release.Refinement

private theorem list_cont_aux {P B Ψ Q C Γ Φ v T a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v T) (hΓ : Γ = [])
    (ht : T.listCore = some a) (ha : ¬ a.NotContCore) : v = .list [] := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_List hs .. =>
    cases ht
    cases hs with
    | nil => rfl
    | cons hv _ => exact False.elim (ha (hv.notContCore (by subst Γ; simp [Ctx.WF])))
  | .V_Normal (a := T0) hv =>
    have hl : Ty.LeQ P Γ Φ T0 T0.norm := .convert (Ty.norm_idem T0).symm
    obtain ⟨b, hb, hba⟩ := hl.listCore_right ht
    exact list_cont_aux hv hΓ hb (fun hn => ha (hba.notContCore.mp hn))
  | .V_Sub hv hl .. =>
    obtain ⟨b, hb, hba⟩ := hl.listCore_right ht
    exact list_cont_aux hv hΓ hb (fun hn => ha (hba.notContCore.mp hn))
  | .V_Refine hv .. => exact list_cont_aux hv hΓ ht ha
  | .V_AtError hs => rw [hs.errorType_eq] at ht; cases ht
  | .V_Const (c := c) _ => cases c <;> cases ht
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
    .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
    .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. |
    .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Con .. |
    .V_Super .. => cases ht
termination_by structural h

theorem list_cont_empty {P B Ψ Q C Φ v b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.list (.cont b t e))) : v = .list [] :=
  list_cont_aux h rfl rfl (fun hn => hn b t e rfl)

theorem singleton_no_match {P B Ψ Q C Φ v b t e}
    (h : HasTypeVQ P B Ψ Q C [] Φ v (.list (.cont b t e))) :
    matchVal (.list [.var] none []) v = none := by
  rw [list_cont_empty h]
  rfl

theorem reject_cont_value {P B Ψ Q C Φ v b t e} :
    ¬ HasTypeVQ P B Ψ Q C [] Φ v (.cont b t e) := by
  intro h
  exact h.notContCore (by simp [Ctx.WF]) b t e rfl

theorem reject_nested_cont_value {P B Ψ Q C Φ v vs b t e} :
    ¬ HasTypeVQ P B Ψ Q C [] Φ (.list (v :: vs)) (.list (.cont b t e)) := by
  intro h
  cases list_cont_empty h

theorem HasTypeVQ.con_list_cont_field_empty {P : Program} {B : Builtins}
    {Ψ : StoreTy} {Q : NoFailCtx} {C : TypeCtx} {Φ : List Pred}
    {T : Ty} {c : ConName} {ts : List Ty} {vs : List Val} {cd : ConDecl} {i : Nat}
    {a b t : Ty} {e : Eff}
    (h : HasTypeVQ P B Ψ Q C [] Φ (.con c ts vs) T)
    (hc : P.cons c = some cd) (ha : cd.args[i]? = some a)
    (hi : a.subst ts [] = .list (.cont b t e)) :
    vs[i]? = some (Val.list []) := by
  obtain ⟨v, hv, ht⟩ := h.con_field hc ha
  rw [hi] at ht
  simpa only [list_cont_empty ht] using hv

theorem CaptureOk.list_cont_empty {P B Ψ R Γ Φ cap i a b t e}
    (h : CaptureOk P B Ψ R Γ Φ cap)
    (hi : Γ[i]? = some (some (.list a)))
    (ha : substTyValues cap.env (.list a) = .list (.cont b t e)) :
    cap.env i = .list [] := by
  cases h with
  | mk _ _ _ _ _ _ himg _ =>
    cases himg i (.list a) hi with
    | ordinary _ hv => rw [ha] at hv; exact Benitoite.Release.Refinement.list_cont_empty hv
    | hidden ho _ => exact False.elim (ho (by trivial))
    | contLoc he _ _ _ _ _ => cases he
    | contVar he _ _ => cases he

end Benitoite.Release.Refinement
