import Benitoite.Release.Refinement.MainTheorems
import Benitoite.Release.Refinement.TypedMeaning

/-! 試し（既定ビルドの外）: 結果型を添字に固定した状態の型付けの両端（開始と正常な返却）。保存は置かない。
形式化の根で `lake env lean -M 12288 <このファイル>` として検査する。 -/
namespace Benitoite.Release.Refinement
noncomputable section

def StateTyR (P : Program) (B : Builtins) (σ : PathEnv) (Eb : Eff) (b : Ty) : State → Prop
  | .run q k μ => ∃ Ψ R a e e1, StoreOk P B σ Ψ μ ∧ ClosureTy P B Ψ [] R q a e1 ∧
      Eff.Sub e1 e ∧ ContTy P B σ Ψ R e k a b Eb none ∧ q.Adequate σ ∧ q.ClosedAt 0 ∧ k.Closed ∧ μ.Closed
  | .matchRun v cap arms next k μ => ∃ Ψ R a e e1, StoreOk P B σ Ψ μ ∧
      (∃ vs, v = closeVal cap vs ∧ ClosureTy P B Ψ [] R (.mk cap (.match vs arms)) a e1) ∧ Eff.Sub e1 e ∧
      ContTy P B σ Ψ R e k a b Eb none ∧ v.Adequate σ ∧ cap.Adequate σ ∧
      MatchPrefix v arms next ∧ v.Ground ∧ adequateArms σ arms ∧ (cap.Closed ∧ Arm.ClosedList 0 cap.values.length arms) ∧ k.Closed ∧ μ.Closed
  | .error _ k μ | .exit _ _ k μ => ∃ Ψ R a e, StoreOk P B σ Ψ μ ∧
      ContTy P B σ Ψ R e k a b Eb none ∧ k.Closed ∧ μ.Closed

theorem StateTyE.iff_result {P B σ Eb} (s : State) : StateTyE P B σ Eb s ↔ ∃ b, StateTyR P B σ Eb b s := by
  cases s <;> simp only [StateTyE, StateTyR] <;> constructor
  all_goals first
    | (rintro ⟨Ψ,R,a,b,e,e1,h⟩; exact ⟨b,Ψ,R,a,e,e1,h⟩)
    | (rintro ⟨b,Ψ,R,a,e,e1,h⟩; exact ⟨Ψ,R,a,b,e,e1,h⟩)
    | (rintro ⟨Ψ,R,a,b,e,h⟩; exact ⟨b,Ψ,R,a,e,h⟩)
    | (rintro ⟨b,Ψ,R,a,e,h⟩; exact ⟨Ψ,R,a,b,e,h⟩)

/-- 開始の状態は、開始の閉包の型を結果型の添字に固定して型付く。 -/
theorem initial_result {P B σ q a ε} (hq : ClosureTy P B StoreTy.empty [] none q a ε)
    (hstart : StartCondition P B σ q) : StateTyR P B σ ε a (.run q [] Store.empty) := by
  have ha := hq.annotation
  exact ⟨StoreTy.empty,none,a,ε,ε,StoreOk.empty P B σ,hq,⟨fun _ h => h,fun _ h => h⟩,
    .K_Empty ⟨fun _ h => h,fun _ h => h⟩ ⟨ha.wf.1,ha.sorted.1,ha.declared.1⟩,
    hstart.adequate,hstart.closed,(by intro f hf; cases hf),(by intro l c h; cases h)⟩

/-- 結果型 b を固定して型付いた、継続が空の返却の状態の値は、b の意味を満たす。変性の妥当性は
主定理の前提 `P.WellTyped B` の欄 `variance` から得る。 -/
theorem final_result_meaning {P B σ Eb b q μ v}
    (hP : P.WellFormed) (hPB : P.WellTyped B) (hB : B.CoreAssumptions P)
    (h : StateTyR P B σ Eb b (.run q [] μ)) (hv : q.view = .ret v) :
    ValueMeaning P (fun _ => none) b v := by
  obtain ⟨Ψ,R,a,e,e1,hs,hq,_,hk,_⟩ := h
  have hva := hq.ret_view_typed hP hPB hB hs.wf hs.sorted hs.declared hv
  obtain ⟨hle,_,_,hb⟩ := hk.nil_inv rfl
  exact typed_value_meaning_closed hPB.variance (HasTypeVQ.V_Sub hva hle hb.wf hb.sorted hb.declared)

end
end Benitoite.Release.Refinement
