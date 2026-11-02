import Benitoite.Release.Refinement.StoreGeneral
import Benitoite.Release.Refinement.PatternBindingSupport

/-! # 専用操作の内容・上限・返却値の型付け -/
namespace Benitoite.Release.Refinement
noncomputable section

private theorem each_append_all {P B Ψ Q C Γ Φ a vs ws}
    (h : HasTypeEachQ P B Ψ Q C Γ Φ vs a) (k : HasTypeEachQ P B Ψ Q C Γ Φ ws a) :
    HasTypeEachQ P B Ψ Q C Γ Φ (vs++ws) a := by
  match h with
  | .nil => exact k
  | .cons hv ht => exact .cons hv (each_append_all ht k)

private theorem builder_list_elements {P B Ψ a vs}
    (hv : HasTypeV P B Ψ [] [] [] (.list vs) (.list a)) (ha : Ty.Annotation P [] [] a) :
    HasTypeEach P B Ψ [] [] [] vs a := by
  obtain ⟨b,hb,t,ht,hle⟩ := hv.inv_list rfl
  cases Option.some.inj ht
  exact PatternBindings.each_of_mem (fun v hv => .V_Sub (hb.member hv) hle ha.wf ha.sorted ha.declared)

private theorem builder_snapshot {P B Ψ kind c} (h : BuilderCellOk P B Ψ kind c) :
    HasTypeV P B Ψ [] [] [] c.snapshot kind.contents := by
  cases kind <;> cases c <;> try cases h.2
  · exact .V_Const trivial
  · exact .V_List h.2.2 h.2.1.wf h.2.1.sorted h.2.1.declared
  · exact .V_Bytes h.2

private def BuilderPayload (P : Program) (B : Builtins) (Ψ : StoreTy) : BuilderKind → BuilderContents → Prop
  | .string,.string _ | .bytes,.bytes _ => True
  | .list a,.list vs => Ty.Annotation P [] [] a ∧ HasTypeEach P B Ψ [] [] [] vs a
  | _,_ => False

private theorem builder_checked_value {P B Ψ kind c c' v}
    (ht : BuilderPayload P B Ψ kind c) (hr : builderCheckUpdate c = .value c' v) :
    BuilderCellOk P B Ψ kind c' ∧ HasTypeV P B Ψ [] [] [] v (.base .unit) := by
  cases kind <;> cases c <;> simp only [BuilderPayload] at ht <;> try contradiction
  case string.string s =>
    simp only [builderCheckUpdate] at hr
    split at hr
    · rename_i hbound
      cases hr; exact ⟨⟨hbound,trivial⟩,.V_Const trivial⟩
    · cases hr
  case list.list a vs =>
    simp only [builderCheckUpdate] at hr
    split at hr
    · rename_i hbound
      cases hr; exact ⟨⟨hbound,ht⟩,.V_Const trivial⟩
    · cases hr
  case bytes.bytes bs =>
    simp only [builderCheckUpdate] at hr
    split at hr
    · rename_i hbound
      split at hr
      · rename_i hbytes
        cases hr
        refine ⟨⟨hbound,?_⟩,.V_Const trivial⟩
        intro b hb
        have hh := List.all_eq_true.mp hbytes b hb
        simp only [decide_eq_true_eq] at hh
        omega
      · cases hr
    · cases hr

/-- 成功した全操作に、同じ専用セルの型と通常の返却値の型を付ける。 -/
theorem builderApply_value_typed {P B Ψ kind c op args c' v}
    (hok : BuilderCellOk P B Ψ kind c)
    (hargs : HasTypeVs P B Ψ [] [] [] args (op.parameters kind))
    (hr : builderApply op c args = some (.value c' v)) :
    BuilderCellOk P B Ψ kind c' ∧ HasTypeV P B Ψ [] [] [] v (op.resultType kind) := by
  unfold builderApply at hr
  split at hr
  · cases hr; exact ⟨hok,builder_snapshot hok⟩
  · split at hr
    · cases hr; exact ⟨hok,.V_Const trivial⟩
    · cases hr
  · exact builder_checked_value (c := .string _) (by cases kind <;> first | trivial | exact hok.2) (Option.some.inj hr)
  · rename_i s vs
    cases hj : builderJoin vs with
    | none => simp [hj] at hr
    | some t =>
      simp only [hj,Option.map_some,Option.some.injEq] at hr
      exact builder_checked_value (c := .string _) (by cases kind <;> first | trivial | exact hok.2) hr
  · rename_i vs w
    cases kind with
    | string => cases hok.2
    | bytes => cases hok.2
    | list a =>
      have hcell := hok.2
      cases hargs with
      | cons hw rest =>
        cases rest
        exact builder_checked_value (c := .list (vs++[w])) ⟨hcell.1,each_append_all hcell.2 (.cons hw .nil)⟩ (Option.some.inj hr)
  · rename_i vs ws
    cases kind with
    | string => cases hok.2
    | bytes => cases hok.2
    | list a =>
      have hcell := hok.2
      cases hargs with
      | cons hw rest =>
        cases rest
        exact builder_checked_value (c := .list (vs++ws)) ⟨hcell.1,each_append_all hcell.2 (builder_list_elements hw hcell.1)⟩ (Option.some.inj hr)
  · exact builder_checked_value (c := .bytes _) (by cases kind <;> first | trivial | exact hok.2) (Option.some.inj hr)
  · exact builder_checked_value (c := .bytes _) (by cases kind <;> first | trivial | exact hok.2) (Option.some.inj hr)
  · cases hr


private theorem builder_closed_append {vs ws : List Val}
    (h : Val.ClosedList 0 0 vs) (k : Val.ClosedList 0 0 ws) : Val.ClosedList 0 0 (vs++ws) := by
  cases vs with
  | nil => exact k
  | cons v vs => exact ⟨h.1,builder_closed_append h.2 k⟩

private theorem builder_adequate_append {σ : PathEnv} {vs ws : List Val}
    (h : adequateVals σ vs) (k : adequateVals σ ws) : adequateVals σ (vs++ws) := by
  cases vs with
  | nil => exact k
  | cons v vs => exact ⟨h.1,builder_adequate_append h.2 k⟩

private theorem builder_snapshot_scope {c : BuilderContents} {σ : PathEnv}
    (h : (Cell.builder c).Closed) (ha : (Cell.builder c).Adequate σ) :
    c.snapshot.Ground ∧ c.snapshot.Adequate σ := by
  cases c <;> exact ⟨h,ha⟩

private theorem builder_checked_scope {c c' : BuilderContents} {v : Val} {σ : PathEnv}
    (h : (Cell.builder c).Closed) (ha : (Cell.builder c).Adequate σ)
    (hr : builderCheckUpdate c = .value c' v) :
    (Cell.builder c').Closed ∧ v.Ground ∧ (Cell.builder c').Adequate σ ∧ v.Adequate σ := by
  cases c <;> simp only [builderCheckUpdate] at hr
  all_goals split at hr
  all_goals first
    | (cases hr <;> exact ⟨h,trivial,ha,trivial⟩)
    | (split at hr <;> cases hr <;> exact ⟨h,trivial,ha,trivial⟩)

/-- 実際の成功応答に保存する全値の閉性と適格性を渡す。 -/
theorem builderApply_value_scope {op c args c' v σ}
    (hc : (Cell.builder c).Closed) (hac : (Cell.builder c).Adequate σ)
    (ha : Val.ClosedList 0 0 args) (haa : adequateVals σ args)
    (hr : builderApply op c args = some (.value c' v)) :
    (Cell.builder c').Closed ∧ v.Ground ∧ (Cell.builder c').Adequate σ ∧ v.Adequate σ := by
  unfold builderApply at hr
  split at hr
  · cases hr
    have hs := builder_snapshot_scope hc hac
    exact ⟨hc,hs.1,hac,hs.2⟩
  · split at hr
    · cases hr; exact ⟨hc,trivial,hac,trivial⟩
    · cases hr
  · exact builder_checked_scope (c := .string _) trivial trivial (Option.some.inj hr)
  · rename_i s vs
    cases hj : builderJoin vs with
    | none => simp [hj] at hr
    | some t =>
      simp only [hj,Option.map_some,Option.some.injEq] at hr
      exact builder_checked_scope (c := .string _) trivial trivial hr
  · rename_i vs w
    exact builder_checked_scope (c := .list (vs++[w]))
      (builder_closed_append hc (show Val.ClosedList 0 0 [w] from ⟨ha.1,trivial⟩))
      (builder_adequate_append hac (show adequateVals σ [w] from ⟨haa.1,trivial⟩)) (Option.some.inj hr)
  · exact builder_checked_scope (c := .list _) (builder_closed_append hc ha.1)
      (builder_adequate_append hac haa.1) (Option.some.inj hr)
  · exact builder_checked_scope (c := .bytes _) trivial trivial (Option.some.inj hr)
  · exact builder_checked_scope (c := .bytes _) trivial trivial (Option.some.inj hr)
  · cases hr

end
end Benitoite.Release.Refinement
