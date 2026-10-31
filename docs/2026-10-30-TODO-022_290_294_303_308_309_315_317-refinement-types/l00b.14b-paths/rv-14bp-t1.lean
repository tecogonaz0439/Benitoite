import Benitoite.Release.Refinement.MatchPaths
import Benitoite.Release.Refinement.LogicSound
namespace Benitoite.Release.Refinement
noncomputable section
#check @CaptureOk.extend

/-- (b) 構成子の根: 照合の成功から実際の観測の根が c である。 -/
theorem con_root {c ps v ws} (h : matchVal (.con c ps) v = some ws) :
    ∃ slots, v.toTerm? = some (.dataValue c slots) := by
  cases v <;> simp only [matchVal] at h
  all_goals first | (cases h; done) | skip
  case con c' ts args =>
    split at h
    · rename_i he; subst he; exact ⟨_,rfl⟩
    · cases h
  case atError d =>
    split at h
    · rename_i he; subst he; exact ⟨_,rfl⟩
    · cases h

theorem list_root {b r a v ws} (hn : !(b.isEmpty && a.isEmpty) = true)
    (h : matchVal (.list b r a) v = some ws) :
    ∃ slots, v.toTerm? = some (.listValue slots) ∧ 0 < slots.length := by
  cases v <;> simp only [matchVal] at h
  all_goals first | (cases h; done) | skip
  case list elems =>
    refine ⟨_,rfl,?_⟩
    have hpos : 0 < b.length + a.length := by
      cases b <;> cases a <;> simp_all <;> omega
    have hle : b.length + a.length ≤ elems.length := by
      apply Classical.byContradiction
      intro hne
      have : ¬ (if r.isSome = true then b.length + a.length ≤ elems.length else b.length + a.length = elems.length) := by
        split <;> omega
      rw [if_neg this] at h
      cases h
    simp only [Val.toTermSlots_eq_map,List.length_map]
    omega

theorem firstAlt_some_mem {v ws} : ∀ {alts : List Alt}, firstAlt v alts = some ws →
    ∃ a ∈ alts, ∃ us, matchVal a.pat v = some us := by
  intro alts
  induction alts with
  | nil => intro h; cases h
  | cons a as ih =>
    intro h
    simp only [firstAlt] at h
    cases hm : matchVal a.pat v with
    | some us => exact ⟨a,List.mem_cons_self,us,hm⟩
    | none =>
      simp only [hm] at h
      obtain ⟨b,hb,us,hu⟩ := ih h
      exact ⟨b,List.mem_cons_of_mem _ hb,us,hu⟩

/-- 全選択肢の根が c なら、どの選択肢が選ばれても根は c。 -/
theorem matched_constructor_true {v ws alts c}
    (hf : firstAlt v alts = some ws)
    (hm : PathTest.constructor c ∈ matchedTests alts) :
    ∃ slots, v.toTerm? = some (.dataValue c slots) := by
  have hall : ∀ a ∈ alts, rootConstructor a.pat = some c := by
    cases alts with
    | nil => cases hm
    | cons a as =>
      unfold matchedTests at hm
      cases hr : rootConstructor a.pat with
      | none =>
        simp only [hr] at hm
        split at hm <;> simp at hm
      | some d =>
        simp only [hr] at hm
        split at hm
        · rename_i ha
          have hd : d = c := by
            have hx : c = d := by simpa using hm
            exact hx.symm
          subst hd
          intro b hb
          rcases List.mem_cons.mp hb with rfl | hb
          · exact hr
          · simpa using (List.all_eq_true.mp ha) b hb
        · cases hm
  obtain ⟨a,ha,us,hu⟩ := firstAlt_some_mem hf
  have hr := hall a ha
  cases hp : a.pat <;> simp [hp,rootConstructor] at hr
  subst hr
  rw [hp] at hu
  exact con_root hu

theorem matched_nonempty_true {v ws alts}
    (hf : firstAlt v alts = some ws)
    (hm : PathTest.nonempty ∈ matchedTests alts) :
    ∃ slots, v.toTerm? = some (.listValue slots) ∧ 0 < slots.length := by
  have hall : ∀ a ∈ alts, nonemptyPattern a.pat = true := by
    cases alts with
    | nil => cases hm
    | cons a as =>
      unfold matchedTests at hm
      cases hr : rootConstructor a.pat with
      | none =>
        simp only [hr] at hm
        split at hm
        · rename_i ha; intro b hb; exact List.all_eq_true.mp ha b hb
        · cases hm
      | some d =>
        simp only [hr] at hm
        split at hm <;> simp at hm
  obtain ⟨a,ha,us,hu⟩ := firstAlt_some_mem hf
  have hr := hall a ha
  cases hp : a.pat <;> simp [hp,nonemptyPattern] at hr
  case list b r af =>
    rw [hp] at hu
    exact list_root (by simpa [nonemptyPattern] using hr) hu

/-- 除外: 全選択肢の順列が空（`.con c []` を含む腕の AltsTy が強制）で firstAlt が失敗し、
    c の値に欄がないなら、根は c ではない。 -/
theorem firstAlt_none_all {v} : ∀ {alts : List Alt}, (∀ a ∈ alts, a.slots = []) →
    firstAlt v alts = none → ∀ a ∈ alts, matchVal a.pat v = none := by
  intro alts
  induction alts with
  | nil => intro _ _ a ha; cases ha
  | cons a as ih =>
    intro hs h b hb
    simp only [firstAlt] at h
    cases hm : matchVal a.pat v with
    | some us =>
      simp only [hm,hs a List.mem_cons_self,selectSlots] at h
      cases h
    | none =>
      simp only [hm] at h
      rcases List.mem_cons.mp hb with rfl | hb
      · exact hm
      · exact ih (fun x hx => hs x (List.mem_cons_of_mem _ hx)) h b hb

theorem excluded_true {v alts c slots d}
    (hs : ∀ a ∈ alts, a.slots = [])
    (hf : firstAlt v alts = none) (ht : PathTest.excluded c ∈ excludedTests alts)
    (hv : v.toTerm? = some (.dataValue d slots))
    (hargs : ∀ ts args, v = .con c ts args → args = [])
    (hat : ∀ e, v = .atError e → c ≠ "Scope.ScopeError.At") : d ≠ c := by
  obtain ⟨a,ha,hx⟩ := List.mem_filterMap.mp ht
  have hp : a.pat = .con c [] := by
    cases hq : a.pat <;> simp [hq] at hx
    case con k ps =>
      cases ps with
      | nil => simp at hx; subst hx; rfl
      | cons _ _ => simp at hx
  have hn := firstAlt_none_all hs hf a ha
  rw [hp] at hn
  intro he
  subst he
  cases v with
  | con c' ts args =>
    simp only [Val.toTerm?,Option.some.injEq,Term.dataValue.injEq] at hv
    obtain ⟨rfl,_⟩ := hv
    have := hargs ts args rfl
    subst this
    simp [matchVal,matchList] at hn
  | atError e =>
    simp only [Val.toTerm?,Option.some.injEq,Term.dataValue.injEq] at hv
    exact hat e rfl hv.1.symm
  | const k => cases k <;> simp [Val.toTerm?] at hv
  | _ => simp [Val.toTerm?] at hv

/-- 閉じた評価への接続。`Entails` ではなく実際の evalClosed が true になる。 -/
theorem eval_con {t c} {slots} (ht : t = Term.dataValue c slots)
    (hw : (Pred.constructorIs t c).WF 0) (hs : (Pred.constructorIs t c).Sorted [] none) :
    (Pred.constructorIs t c).evalClosed = some true := by
  subst ht
  have hr : termReady (fun _ => none) .data (.dataValue c slots) = true := by
    simp [termReady,Term.observe,Observation.sort]
  obtain ⟨o,ho,_,_,hobs⟩ := termReady_observation hr
  simp only [Term.observe,Option.some.injEq] at ho
  simp [Pred.evalClosed,hw,hs,Pred.evalWith,Pred.atomReady,hr,Pred.atomValue,hobs,←ho]

end
end Benitoite.Release.Refinement
open Benitoite.Release.Refinement in
#print axioms Benitoite.Release.Refinement.matched_constructor_true
open Benitoite.Release.Refinement in
#print axioms Benitoite.Release.Refinement.matched_nonempty_true
#print axioms Benitoite.Release.Refinement.excluded_true
#print axioms Benitoite.Release.Refinement.eval_con
