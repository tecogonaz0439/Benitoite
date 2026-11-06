import Benitoite.Release.Refinement.Surface.CheckFormation
import Benitoite.Release.Refinement.Surface.Rules

/-! パターンの欄の経路と、腕へ渡す事実の形成の有限検査。 -/
namespace Benitoite.Release.Refinement.Surface.CheckPatterns

/-- パターンの束縛位置と、宣言した欄の経路を照合する。 -/
def binderPathCheck : List FieldRef → Pat → Nat → Bool
  | [], .var, raw => decide (raw = 0)
  | ref :: route, .con c ps, raw =>
      match ps[ref.position]? with
      | none => false
      | some p =>
          let before := Pat.bindersList (ps.take ref.position)
          decide (ref.constructor = c ∧ before ≤ raw) && binderPathCheck route p (raw - before)
  | _, _, _ => false

theorem binderPathCheck_sound {route : List FieldRef} {p : Pat} {raw : Nat}
    (h : binderPathCheck route p raw = true) : BinderPath p raw route := by
  induction route generalizing p raw with
  | nil =>
      cases p <;> simp only [binderPathCheck, Bool.false_eq_true, decide_eq_true_eq] at h
      cases h
      exact .var
  | cons ref route ih =>
      cases p <;> simp only [binderPathCheck, Bool.false_eq_true] at h
      rename_i c ps
      cases hp : ps[ref.position]? with
      | none => simp [hp] at h
      | some child =>
          simp only [hp, Bool.and_eq_true, decide_eq_true_eq] at h
          have hb := BinderPath.con hp h.1.1 rfl (ih h.2)
          simpa only [Nat.add_sub_of_le h.1.2] using hb

theorem binderPathCheck_complete {route : List FieldRef} {p : Pat} {raw : Nat}
    (h : BinderPath p raw route) : binderPathCheck route p raw = true := by
  induction h with
  | var => rfl
  | @con c ps j p i route ref hp hc hj _ ih =>
      simp only [binderPathCheck, hj, hp, hc, decide_true, true_and, Nat.le_add_right,
        Nat.add_sub_cancel_left, ih, Bool.true_and]

private def fieldLinkValid (alts : List Alt) (n : Nat) (link : FieldLink) : Bool :=
  match alts with
  | [⟨.con c ps, slots⟩] =>
      decide (link.slot < n) && (decide (slots[link.slot]? = some link.raw) &&
        (binderPathCheck link.route (.con c ps) link.raw &&
          (decide (link.route ≠ []) && decide (link.measure = none ∨ link.measure = some .listLength))))
  | _ => false

private theorem fieldLinkValid_spec (alts : List Alt) (n : Nat) (link : FieldLink) :
    fieldLinkValid alts n link = true ↔ link.Valid alts n := by
  constructor
  · intro h
    unfold fieldLinkValid at h
    split at h
    · rename_i c ps slots
      simp only [Bool.and_eq_true, decide_eq_true_eq] at h
      exact ⟨⟨.con c ps, slots⟩, rfl, ⟨c, ps, rfl⟩, h.1, h.2.1,
        binderPathCheck_sound h.2.2.1, h.2.2.2.1, h.2.2.2.2⟩
    · cases h
  · rintro ⟨alt, rfl, ⟨c, ps, hp⟩, hn, hs, hb, hr, hm⟩
    cases alt with
    | mk pat slots =>
      dsimp only at hp
      subst pat
      simp only [fieldLinkValid, Bool.and_eq_true, decide_eq_true_eq]
      exact ⟨hn, hs, binderPathCheck_complete hb, hr, hm⟩

/-- 欄の関係はパターンの構文・並べ替え・測度の列を全て照合する。 -/
def linksValid (alts : List Alt) (n : Nat) (links : List FieldLink) : Bool :=
  links.all (fieldLinkValid alts n)

theorem linksValid_spec (alts : List Alt) (n : Nat) (links : List FieldLink) :
    linksValid alts n links = true ↔ LinksValid alts n links := by
  simp only [linksValid, List.all_eq_true, fieldLinkValid_spec, LinksValid]

/-- 事実の子の経路は、先頭が0、残りが1である。 -/
def factsWF (q : CheckFormation.Input) (P : Refinement.Program) (C : TypeCtx) (Γ : Ctx)
    (path : List Nat) : List Pred → Bool
  | [] => true
  | p :: ps =>
      (decide (p.Sorted Γ none) && CheckFormation.declaredPred q P C Γ none (path ++ [0]) p) &&
        factsWF q P C Γ (path ++ [1]) ps

theorem factsWF_sound {q P C Γ path Φ} (hq : q.Sound P) (hΓ : CheckFormation.CtxSupport q.atoms Γ)
    (h : factsWF q P C Γ path Φ = true) : FactsWF P C Γ Φ := by
  induction Φ generalizing path with
  | nil => intro p hp; cases hp
  | cons p ps ih =>
      simp only [factsWF, Bool.and_eq_true] at h
      obtain ⟨⟨hs, hd⟩, hrest⟩ := h
      have hs : p.Sorted Γ none := of_decide_eq_true hs
      intro a ha
      rcases List.mem_cons.mp ha with rfl | ha
      · exact ⟨hs.wf_none, hs,
          CheckFormation.declaredPred_sound hq hΓ (by intro a h; cases h) hd⟩
      · exact ih hrest a ha

/-- 存在するsortを、先頭の変数の型から有限に読む。 -/
def scrutObservation (Γ : Ctx) : Option Term :=
  match (Γ[0]?).join with
  | none => none
  | some a => match a.sort? with
    | none => none
    | some s => if decide ((Term.var 0).HasSort Γ s) then some (.var 0) else none

private theorem variable_sort {Γ : Ctx} {a : Ty} {s : «Sort»}
    (ha : (Γ[0]?).join = some a) (hs : (Term.var 0).HasSort Γ s) : a.HasSort s := by
  obtain ⟨b, hb, hbs⟩ := hs.2
  have he : a = b := Option.some.inj (ha.symm.trans (by simp only [hb, Option.join_some]))
  exact he ▸ hbs

/-- 計算による観測の有無は、型付け規則の存在条件と同じである。 -/
theorem scrutObservation_eq (Γ : Ctx) : scrutObservation Γ = scrutObs Γ := by
  cases hzero : (Γ[0]?).join with
  | none =>
      have hn : ¬ ∃ s, (Term.var 0).HasSort Γ s := by
        rintro ⟨s, hs⟩
        obtain ⟨a, ha, _⟩ := hs.2
        simp only [ha, Option.join_some] at hzero
        cases hzero
      simp [scrutObservation, hzero, scrutObs, hn]
  | some a =>
      cases hsort : a.sort? with
      | none =>
          have hn : ¬ ∃ s, (Term.var 0).HasSort Γ s := by
            rintro ⟨s, hs⟩
            have ht := variable_sort hzero hs
            simp only [Ty.HasSort, hsort] at ht
            cases ht
          simp [scrutObservation, hzero, hsort, scrutObs, hn]
      | some s =>
          by_cases hs : (Term.var 0).HasSort Γ s
          · have he : ∃ t, (Term.var 0).HasSort Γ t := ⟨s, hs⟩
            simp [scrutObservation, hzero, hsort, hs, scrutObs, he]
          · have hn : ¬ ∃ t, (Term.var 0).HasSort Γ t := by
              rintro ⟨t, ht⟩
              have he : s = t := Ty.hasSort_unique hsort (variable_sort hzero ht)
              exact hs (he ▸ ht)
            simp [scrutObservation, hzero, hsort, hs, scrutObs, hn]

end Benitoite.Release.Refinement.Surface.CheckPatterns
