import Benitoite.Release.Refinement.PatternBindingsGround
import Benitoite.Release.Refinement.TypedMeaningExamples

/-! # List の束縛と CaptureOk の適用（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement
noncomputable section

theorem head_rest_bindings_typed {P B Ψ a vs ws} (valid : P.VarianceValid)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.list vs) (Ty.list a).norm)
    (hm : matchVal headRestPattern (.list vs) = some ws) :
    ∃ v rest, vs = v :: rest ∧ ws = [v,.list rest] ∧ vs.length = rest.length + 1 ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] [v,.list rest] [a.norm,.list a.norm] := by
  obtain ⟨v,rest,he,hws,hlen⟩ := pattern_length_relation vs ws hm
  have hp : PatTy P headRestPattern (.list a) [a,.list a] :=
    .P_List (.cons .P_Var .nil) .nil (by intro h; cases h)
  have ht := pattern_bindings_typed valid hp hv hm
  rw [hws] at ht
  exact ⟨v,rest,he,hws,hlen,ht⟩

theorem head_rest_close_typed {P B Ψ a vs ws} {cap : Capture} (valid : P.VarianceValid)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (closeVal cap (.list vs)) (cap.closeTy (.list a)))
    (hm : matchVal headRestPattern (.list vs) = some ws) :
    ∃ v rest, vs = v :: rest ∧ ws = [v,.list rest] ∧
      HasTypeVsQ P B Ψ Qempty [] [] [] [closeVal cap v,.list (closeVals cap rest)]
        [(cap.closeTy a).norm,.list (cap.closeTy a).norm] ∧
      (closeVal cap v).toTerm? = (v.subst cap.env).toTerm? ∧
      (closeVal cap (.list rest)).toTerm? = ((Val.list rest).subst cap.env).toTerm? ∧
      (closeVals cap vs).length = (closeVals cap rest).length + 1 := by
  obtain ⟨v,rest,he,hws,hmatch,hobs,hrest,hlen⟩ := pattern_length_close cap vs ws hm
  have hp : PatTy P headRestPattern (.list (cap.closeTy a)) [cap.closeTy a,.list (cap.closeTy a)] :=
    .P_List (.cons .P_Var .nil) .nil (by intro h; cases h)
  have ht := pattern_bindings_typed valid hp (by
    simpa only [Capture.closeTy,substTyValues,Ty.bind,Ty.rawBind,Ty.norm,Ty.norm_idem] using hv) hmatch
  exact ⟨v,rest,he,hws,ht,hobs,hrest,hlen⟩

theorem head_rest_two {P B Ψ a v₀ v₁} (valid : P.VarianceValid)
    (hv : HasTypeVQ P B Ψ Qempty [] [] [] (.list [v₀,v₁]) (Ty.list a).norm) :
    HasTypeVsQ P B Ψ Qempty [] [] [] [v₀,.list [v₁]] [a.norm,.list a.norm] ∧
    matchVal headRestPattern (.list [v₀,v₁]) = some [v₀,.list [v₁]] ∧
    matchVal headRestPattern (.list []) = none := by
  have hm : matchVal headRestPattern (.list [v₀,v₁]) = some [v₀,.list [v₁]] := rfl
  have hp : PatTy P headRestPattern (.list a) [a,.list a] :=
    .P_List (.cons .P_Var .nil) .nil (by intro h; cases h)
  exact ⟨pattern_bindings_typed valid hp hv hm,hm,rfl⟩

theorem month_variable_coverage {P : Program} {B : Builtins} {Ψ : StoreTy}
    (valid : P.VarianceValid)
    (hA : Builtins.SubstitutionAssumptions P B) (hstore : Ψ.WF) :
    ∃ p ∈ [monthPattern], (matchVal p TypedMeaningExamples.five).isSome := by
  have ha := PatternBindings.observable_annotation (TypedMeaningExamples.month_typed P B Ψ)
    rfl ⟨.integer,rfl⟩
  have hc := (CaptureOk.empty P B Ψ none).extend ha (v := TypedMeaningExamples.five)
    (TypedMeaningExamples.month_typed P B Ψ) (by trivial)
  have hv : HasTypeVQ P B Ψ Qempty [] (Ctx.extend [] monthType) [] (.var 0) monthType :=
    .V_Var rfl (by trivial)
  exact hc.typed_variable_coverage valid hv hA hstore (month_exhaustive P)

end
end Benitoite.Release.Refinement
