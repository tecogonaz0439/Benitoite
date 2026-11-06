import Benitoite.Release.Refinement.TypeSubstTyping
import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.LegacyMethodEmbedding

namespace Benitoite.Release.Refinement
noncomputable section
theorem legacy_unguarded (xs : List Benitoite.Release.Arm) :
    unguardedPats (embedArms xs) = Benitoite.Release.unguardedPats xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    cases x with
    | mk alts guard body => cases guard <;> simp only [embedArms,embedArm,unguardedPats,
        Benitoite.Release.unguardedPats,ih]

namespace LegacyCompCases

theorem if_case {K P0 B κ Ψ Q C Γ R v m n a e L}
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v (.base .boolean)))
    (yes : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L))
    (no : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R n a e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.ite v m n) a e L) := by
  intro Φ
  obtain ⟨t,ht,_⟩ := (value Φ).observation rfl
  exact .C_If (value Φ) ht (yes (boolCond t true :: Φ)) (no (boolCond t false :: Φ))

theorem match_case {K P0 B0 B κ Ψ Q C Γ R v arms a b e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a))
    (coverage : Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a))
    (body : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.match v arms) b e L) := by
  intro Φ
  have hw : a.WF 0 C.length := by
    have ht := legacy_wf (input.2.2.2 a (by simp)).2.1
    simpa only [input.1.2.2.1] using ht
  have hd := (input.2.2.2 a (by simp)).annotation_at rfl input.1.2.2.1 (Γ.map (Option.map embedTy))
  exact HasTypeCQ.match_legacy (value Φ) (body Φ) hd.declared
    (by rw [legacy_unguarded]; exact embedExhaustive tables hw coverage)

/-- 旧照合の型入力から、同じ照合の型置換の結論を得る。 -/
theorem match_type_subst {K P0 B0 B κ Ψ Q C Γ R v arms a b e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a))
    (coverage : Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a))
    (body : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    ∀ Φ, S02Internal.CGoal (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) Φ (R.map embedTy)
      (embedComp (.match v arms)) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind)) := by
  intro Φ
  exact S02Internal.deriveC _ _ _ _ _ _ _ _ _ _ _ _ (match_case tables input coverage value body Φ)

example {K P0 B0 B κ Ψ Q C Γ R v arms a b e L}
    (tables : LegacyTables K P0 B0 B)
    (input : LegacyNodeRegular K P0 B0 B (.value κ Ψ Q C Γ v a))
    (coverage : Benitoite.Release.Exhaustive P0 a (Benitoite.Release.unguardedPats arms))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v a))
    (body : LegacyJudgment.Embedded K P0 B (.arms κ Ψ Q C Γ R arms a b e L)) :
    S02Internal.CGoal (embedProgramWithKinds K P0) B (embedStoreTy Ψ) Q
      (legacyTypeCtx C κ) (Γ.map (Option.map embedTy)) [] (R.map embedTy)
      (embedComp (.match v arms)) (embedTy b) (embedEff e) (L.map (Option.map embedBuilderKind)) :=
  match_type_subst tables input coverage value body []

theorem lazy_case {K P0 B0 B κ Ψ Q C Γ R m a L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.lazyC m) (.lazy a) Benitoite.Release.Eff.empty L))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ.hideBuilders Q C
      (Benitoite.Release.hideConts Γ) none m a Benitoite.Release.Eff.empty [])) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.lazyC m) (.lazy a) Benitoite.Release.Eff.empty L) := by
  intro Φ
  have ha := legacy_comp_annotation reg
  simpa only [embedComp,embedTy,legacy_empty] using
    HasTypeCQ.C_Lazy (R := R.map embedTy) (Δ := L.map (Option.map embedBuilderKind))
      (by simpa only [legacy_hideBuilders,legacy_hideConts,legacy_empty,List.map_nil,Option.map_none] using body Φ)
      (show Ty.Annotation _ _ _ (embedTy a) from ⟨ha.wf,ha.sorted,ha.declared⟩)

theorem escape_case {K P0 B0 B κ Ψ Q C Γ r v a e L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ (some r) (.escape v) a e L))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v r)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ (some r) (.escape v) a e L) := by
  intro Φ
  exact .C_Escape (value Φ) (legacy_comp_annotation reg)

theorem use_case {K P0 B0 B κ Ψ Q C Γ R v o m a e L}
    (tables : LegacyTables K P0 B0 B)
    (resource : B0.isResource o = true)
    (state : Benitoite.Release.Eff.mem e (.nameTop Benitoite.Release.stateEff))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v (.opaqueTop o)))
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.use v m) a e L) := by
  intro Φ
  exact .C_Use (value Φ) (by rw [tables.resources]; exact resource) (body Φ)
    (by rw [legacy_eff_test]; exact state)

theorem resume_case {K P0 B0 B κ Ψ Q C Γ R i v b t e L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.resume (.var i) v) t e L))
    (lookup : Γ[i]? = some (some (.cont b t e)))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v b)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.resume (.var i) v) t e L) := by
  intro Φ
  exact .C_Resume (by simp only [List.getElem?_map,lookup,Option.map_some,embedTy])
    (value Φ) (legacy_comp_annotation reg).declared

theorem resumeL_case {K P0 B0 B κ Ψ Q C Γ R l v b t e L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R (.resume (.loc l) v) t e L))
    (lookup : Ψ l = some (.cont b t e R))
    (value : LegacyJudgment.Embedded K P0 B (.value κ Ψ Q C Γ v b)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R (.resume (.loc l) v) t e L) := by
  intro Φ
  exact .C_ResumeL (by simp only [embedStoreTy,lookup,Option.map_some,embedLocTy])
    (value Φ) (legacy_comp_annotation reg).declared

theorem sub_case {K P0 B0 B κ Ψ Q C Γ R m a b e f L}
    (reg : LegacyNodeRegular K P0 B0 B (.comp κ Ψ Q C Γ R m b f L))
    (sub : Benitoite.Release.Ty.Le a b) (eff : Benitoite.Release.Eff.Covers f e)
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m b f L) := by
  intro Φ
  have ha := legacy_comp_annotation reg
  exact .C_Sub (body Φ) (embedLe sub) (embedCovers eff) ha.wf ha.sorted ha.declared

theorem eff_case {K P0 B κ Ψ Q C Γ R m a e f L}
    (eff : Benitoite.Release.Eff.Covers f e)
    (body : LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a e L)) :
    LegacyJudgment.Embedded K P0 B (.comp κ Ψ Q C Γ R m a f L) := by
  intro Φ
  exact .C_Eff (body Φ) (embedCovers eff)

end LegacyCompCases
end
end Benitoite.Release.Refinement
