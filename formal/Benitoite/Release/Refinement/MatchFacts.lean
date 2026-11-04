import Benitoite.Release.Refinement.MatchPaths

/-! # 実際の照合の成否から得る経路条件 -/
namespace Benitoite.Release.Refinement.MatchFacts

variable {P : Program}
noncomputable section

mutual
  theorem PatTy.binders_length {P p a δ} (h : PatTy P p a δ) : δ.length = p.binders := by
    match h with
    | .P_Refined hp => exact PatTy.binders_length hp
    | .P_Convert _ hp => simpa only [List.length_map] using PatTy.binders_length hp
    | .P_Wild | .P_Var | .P_Const _ | .P_RangeInt | .P_RangeChar => rfl
    | .P_Con _ _ _ hs => exact PatTys.binders_length hs
    | .P_List (rest := rest) hb ha _ =>
      have hb' := PatTys.binders_length hb
      have ha' := PatTys.binders_length ha
      cases rest with
      | none => simp_all [Pat.binders,ListRest.binders,restTys]
      | some r => cases r <;> simp_all [Pat.binders,ListRest.binders,restTys] <;> omega
  theorem PatTys.binders_length {P ps as δ} (h : PatTys P ps as δ) : δ.length = Pat.bindersList ps := by
    match h with
    | .nil => rfl
    | .cons hp hs => simp only [List.length_append,Pat.bindersList]; rw [PatTy.binders_length hp,PatTys.binders_length hs]
end

mutual
  theorem matchVal_binders {p v ws} (h : matchVal p v = some ws) : ws.length = p.binders := by
    cases p with
    | wild => cases Option.some.inj h; rfl
    | var => cases Option.some.inj h; rfl
    | const c | range c d =>
      cases v <;> simp only [matchVal] at h
      all_goals first | cases h | (split at h <;> first | (cases Option.some.inj h; rfl) | cases h)
    | con c ps =>
      cases v <;> simp only [matchVal] at h
      all_goals first | cases h | (split at h <;> first | exact matchList_binders h | cases h)
    | list before rest after =>
      cases v <;> simp only [matchVal] at h
      all_goals try cases h
      rename_i elems
      by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length else before.length + after.length = elems.length)
      · rw [if_pos hlen] at h
        cases hl : matchList before (elems.take before.length) with
        | none => simp [hl] at h
        | some left =>
          cases hr : matchList after (elems.drop (elems.length-after.length)) with
          | none => simp [hl,hr] at h
          | some right =>
            simp only [hl,hr] at h
            have he := Option.some.inj h
            cases he
            have hb := matchList_binders hl
            have ha := matchList_binders hr
            cases rest with
            | none => simp_all [Pat.binders]
            | some r => cases r <;> simp_all [Pat.binders,ListRest.binders] <;> omega
      · rw [if_neg hlen] at h; cases h
  termination_by sizeOf p
  theorem matchList_binders {ps vs ws} (h : matchList ps vs = some ws) : ws.length = Pat.bindersList ps := by
    cases ps with
    | nil => cases vs <;> cases h; rfl
    | cons p ps =>
      cases vs with
      | nil => cases h
      | cons v vs =>
        simp only [matchList] at h
        cases hp : matchVal p v with
        | none => simp [hp] at h
        | some left =>
          cases hs : matchList ps vs with
          | none => simp [hp,hs] at h
          | some right =>
            simp only [hp,hs] at h
            change some (left ++ right) = some ws at h
            cases Option.some.inj h
            simp only [List.length_append,Pat.bindersList]
            rw [matchVal_binders hp,matchList_binders hs]
  termination_by sizeOf ps
end

theorem selectSlots_total {α : Type} {xs : List α} {slots : List Nat}
    (h : ∀ i ∈ slots, i < xs.length) : ∃ ys, selectSlots xs slots = some ys := by
  induction slots with
  | nil => exact ⟨[],rfl⟩
  | cons i is ih =>
    obtain ⟨ys,hy⟩ := ih (fun j hj => h j (List.mem_cons_of_mem _ hj))
    let x := xs[i]' (h i List.mem_cons_self)
    have hx : xs[i]? = some x := List.getElem?_eq_some_iff.mpr ⟨h i List.mem_cons_self,rfl⟩
    exact ⟨x::ys,by simp [selectSlots,hx,hy]⟩

theorem firstAlt_none_all {P alts a δ v} (ha : AltsTy P alts a δ)
    (hf : firstAlt v alts = none) : ∀ alt ∈ alts, matchVal alt.pat v = none := by
  have walk : ∀ (as : List Alt),
      (∀ alt ∈ as, ∃ γ, PatTy P alt.pat a γ ∧ alt.slots.Perm (List.range γ.length)) →
      firstAlt v as = none → ∀ alt ∈ as, matchVal alt.pat v = none := by
    intro as
    induction as with
    | nil => intro _ _ alt hm; cases hm
    | cons alt rest ih =>
      intro hty h alt' hm
      cases hmatch : matchVal alt.pat v with
      | none =>
        rcases List.mem_cons.mp hm with rfl | hm
        · exact hmatch
        · exact ih (fun x hx => hty x (List.mem_cons_of_mem _ hx)) (by simpa [firstAlt,hmatch] using h) alt' hm
      | some ws =>
        obtain ⟨γ,hp,hperm⟩ := hty alt List.mem_cons_self
        have hlen := (matchVal_binders hmatch).trans (PatTy.binders_length hp).symm
        obtain ⟨ys,hy⟩ := selectSlots_total (xs := ws) (slots := alt.slots) (by
          intro i hi; rw [hlen]; exact List.mem_range.mp (hperm.mem_iff.mp hi))
        simp [firstAlt,hmatch,hy] at h
  exact walk alts (fun alt hm => by obtain ⟨γ,hp,hs,_⟩ := ha.2.2.2 alt hm; exact ⟨γ,hp,hs⟩) hf

theorem firstAlt_some_mem {v ws} : ∀ {alts : List Alt}, firstAlt v alts = some ws →
    ∃ alt ∈ alts, ∃ us, matchVal alt.pat v = some us := by
  intro alts
  induction alts with
  | nil => intro h; cases h
  | cons alt rest ih =>
    intro h
    cases hm : matchVal alt.pat v with
    | some us => exact ⟨alt,List.mem_cons_self,us,hm⟩
    | none =>
      obtain ⟨a,ha,us,hu⟩ := ih (by simpa [firstAlt,hm] using h)
      exact ⟨a,List.mem_cons_of_mem _ ha,us,hu⟩

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



theorem observeSlots_length (η : ObservationEnvModel) (slots : List (Option Term)) :
    (observeSlots η slots).length = slots.length := by
  induction slots with
  | nil => rfl
  | cons x xs ih => cases x <;> simp [observeSlots,ih]

@[simp] theorem allowed_character (op : Comparison) : decide (Comparison.Allowed .character op) = true := by
  cases op <;> decide
@[simp] theorem allowed_boolean_eq : decide (Comparison.Allowed .boolean .eq) = true := by decide
@[simp] theorem allowed_string_eq : decide (Comparison.Allowed .string .eq) = true := by decide
@[simp] theorem allowed_unit_eq : decide (Comparison.Allowed .unit .eq) = true := by decide

macro "match_eval_simp" : tactic => `(tactic|
  simp_all [PathTest.predicate,PathLiteral.predicate,Pred.evalWith,Pred.atomReady,Pred.atomValue,
    Integer64Value.toInt,termReady,Term.observe,Term.interpret,Observation.sort,Observation.compare,Comparison.fromEqLt,
    allowed_character,allowed_boolean_eq,allowed_string_eq,allowed_unit_eq,observeAs,integerAs,Observation.measure,observeSlots_length])

theorem eval_constructor (c d : ConName) (slots : List (Option Term)) :
    (Pred.constructorIs (.dataValue d slots) c).evalWith (fun _ => none) = some (decide (d=c)) := by
  match_eval_simp

theorem eval_nonempty (slots : List (Option Term)) :
    (PathTest.nonempty.predicate (.listValue slots)).evalWith (fun _ => none) = some (decide (0<slots.length)) := by
  match_eval_simp

theorem eval_empty (slots : List (Option Term)) :
    (PathTest.empty.predicate (.listValue slots)).evalWith (fun _ => none) = some (decide (slots.length=0)) := by
  match_eval_simp

theorem literal_test_true {c v ws lit t}
    (hp : pathLiteral? c = some lit) (hm : matchVal (.const c) v = some ws)
    (ht : v.toTerm? = some t) : ((PathTest.literal lit).predicate t).evalWith (fun _ => none) = some true := by
  have hv : ∃ c', v = .const c' := by
    cases v <;> first | exact ⟨_,rfl⟩ | cases hm
  obtain ⟨c',rfl⟩ := hv
  have hb : patternMatches c c' = true := by
    simp only [matchVal] at hm
    split at hm
    · assumption
    · cases hm
  cases c <;> simp only [pathLiteral?,Option.some.injEq] at hp <;> try cases hp
  all_goals cases c' <;> simp [patternMatches] at hb
  all_goals cases ht; match_eval_simp <;> first | rfl | omega

theorem range_test_true {lo hi v ws test t}
    (hp : patternTest? (.range lo hi) = some test) (hm : matchVal (.range lo hi) v = some ws)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some true := by
  have hv : ∃ c', v = .const c' := by
    cases v <;> first | exact ⟨_,rfl⟩ | cases hm
  obtain ⟨c',rfl⟩ := hv
  have hb : patternRange lo hi c' = true := by
    simp only [matchVal] at hm
    split at hm
    · assumption
    · cases hm
  cases lo <;> cases hi <;> simp only [patternTest?,Option.some.injEq] at hp <;> try cases hp
  all_goals cases c' <;> simp [patternRange] at hb
  all_goals cases ht
  case integer.integer.refl.integer.refl => match_eval_simp
  case character.character.refl.character.refl =>
    rename_i lo hi n
    have char_le : ∀ (a b : Char), a.toNat ≤ b.toNat → (decide (a.toNat < b.toNat) || (a == b)) = true := by
      intro a b hh
      by_cases he : a = b
      · simp [he]
      · have hn : a.toNat ≠ b.toNat := fun heq => he (Char.toNat_inj.mp heq)
        have hl : a.toNat < b.toNat := by omega
        simp [hl]
    have h1 := char_le lo n hb.1
    have h2 := char_le n hi hb.2
    change (match some (decide (lo.toNat < n.toNat) || (lo == n)),
        some (decide (n.toNat < hi.toNat) || (n == hi)) with
      | some false, _ | _, some false => some false
      | some true, some true => some true | _, _ => none) = some true
    rw [h1,h2]

theorem list_test_cases {before rest after test}
    (hp : patternTest? (.list before rest after) = some test) :
    (test = .nonempty ∧ nonemptyPattern (.list before rest after) = true) ∨
    (test = .empty ∧ before = [] ∧ rest = none ∧ after = []) := by
  cases before <;> cases rest <;> cases after <;>
    simp_all [patternTest?,nonemptyPattern]

theorem empty_root {v ws} (hm : matchVal (.list [] none []) v = some ws) :
    ∃ slots, v.toTerm? = some (.listValue slots) ∧ slots.length = 0 := by
  cases v <;> simp only [matchVal] at hm <;> try cases hm
  rename_i elems
  have he : elems.length = 0 := by
    by_cases h : 0 = elems.length
    · omega
    · simp [h] at hm
  exact ⟨_,rfl,by simpa [Val.toTermSlots_eq_map] using he⟩

theorem pattern_test_true {pat v ws test t}
    (hp : patternTest? pat = some test) (hm : matchVal pat v = some ws)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some true := by
  cases pat with
  | wild | var => cases hp
  | const c =>
    cases hl : pathLiteral? c with
    | none => simp [patternTest?,hl] at hp
    | some lit =>
      have he : test = .literal lit := by simpa [patternTest?,hl] using hp.symm
      subst test
      exact literal_test_true hl hm ht
  | range lo hi => exact range_test_true hp hm ht
  | con c ps =>
    have he : test = .constructor c := by simpa [patternTest?] using hp.symm
    subst test
    obtain ⟨slots,hroot⟩ := con_root hm
    cases ht.symm.trans hroot
    simpa only [PathTest.predicate,decide_true] using eval_constructor c c slots
  | list before rest after =>
    rcases list_test_cases hp with ⟨rfl,hn⟩ | ⟨rfl,rfl,rfl,rfl⟩
    · obtain ⟨slots,hroot,hpos⟩ := list_root (by simpa [nonemptyPattern] using hn) hm
      cases ht.symm.trans hroot
      simpa [hpos] using eval_nonempty slots
    · obtain ⟨slots,hroot,hlen⟩ := empty_root hm
      cases ht.symm.trans hroot
      simpa [hlen] using eval_empty slots

theorem alternatives_test_true {alts test alt v ws t}
    (hp : alternativesTest alts = some test) (ha : alt ∈ alts)
    (hm : matchVal alt.pat v = some ws) (ht : v.toTerm? = some t) :
    (test.predicate t).evalWith (fun _ => none) = some true := by
  induction alts generalizing test with
  | nil => cases ha
  | cons a rest ih =>
    cases rest with
    | nil =>
      rcases List.mem_cons.mp ha with rfl | ha
      · exact pattern_test_true hp hm ht
      · cases ha
    | cons b rest =>
      cases hl : patternTest? a.pat with
      | none => simp [alternativesTest,hl] at hp
      | some left =>
        cases hr : alternativesTest (b::rest) with
        | none => simp [alternativesTest,hl,hr] at hp
        | some right =>
          have he : test = .either left right := by simpa [alternativesTest,hl,hr] using hp.symm
          subst test
          rcases List.mem_cons.mp ha with rfl | ha
          · exact Pred.evalWith_or_true_left (pattern_test_true hl hm ht)
          · exact Pred.evalWith_or_true_right (ih hr ha)

theorem matched_true {v ws alts test t}
    (hf : firstAlt v alts = some ws) (hm : test ∈ matchedTests alts)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some true := by
  obtain ⟨alt,ha,us,hu⟩ := firstAlt_some_mem hf
  cases alts with
  | nil => cases ha
  | cons a rest =>
    cases hp : patternTest? a.pat with
    | none => simp [matchedTests,hp] at hm
    | some first =>
      simp only [matchedTests,hp] at hm
      split at hm
      · rename_i hall
        have he : test = first := List.mem_singleton.mp hm
        subst test
        have htest : patternTest? alt.pat = some first := by
          rcases List.mem_cons.mp ha with rfl | ha
          · exact hp
          · simpa using List.all_eq_true.mp hall alt ha
        exact pattern_test_true htest hu ht
      · cases hp' : alternativesTest (a::rest) with
        | none => simp [hp'] at hm
        | some other =>
          have he : test = other := by simpa [hp'] using hm
          subst test
          exact alternatives_test_true hp' ha hu ht

theorem matched_evalClosed_true {v ws alts test t}
    (hf : firstAlt v alts = some ws) (hm : test ∈ matchedTests alts)
    (ht : v.toTerm? = some t) (hw : (test.predicate t).WF 0)
    (hs : (test.predicate t).Sorted [] none) : (test.predicate t).evalClosed = some true := by
  unfold Pred.evalClosed
  rw [if_pos (show (test.predicate t).WF 0 ∧ (test.predicate t).Sorted [] none from ⟨hw,hs⟩)]
  exact matched_true hf hm ht



/-- 照合の除外に必要な根だけの形。要素と欄の型適合は要求しない。 -/
def RootShape (P : Program) : Ty → Val → Prop
  | .base base, v => ∃ c, v = .const c ∧ c.type = .base base
  | .list _, v => ∃ elems, v = .list elems
  | .data _ _, v =>
      (∃ c tys args cd, v = .con c tys args ∧ P.cons c = some cd ∧ args.length = cd.args.length) ∨
      (∃ detail cd, v = .atError detail ∧ P.cons "Scope.ScopeError.At" = some cd ∧
        cd.args.length = detail.values.length)
  | .refined a _, v => RootShape P a v
  | _, _ => True

theorem RootShape.core {P a v} : RootShape P a.core v ↔ RootShape P a v := by
  cases a with
  | refined a p => exact RootShape.core (a := a)
  | _ => rfl

theorem RootShape.refineNorm {P a p v} : RootShape P (a.refineNorm p) v ↔ RootShape P a v := by
  unfold Ty.refineNorm Ty.packRefinements
  split <;> exact RootShape.core

theorem RootShape.norm {P a v} : RootShape P a.norm v ↔ RootShape P a v := by
  cases a with
  | refined a p => exact RootShape.refineNorm.trans (RootShape.norm (a := a))
  | dependentFn t => unfold Ty.norm Ty.foldFn; split <;> rfl
  | _ => rfl

theorem RootShape.subtype {P Γ Φ a b v} (h : Ty.LeQ P Γ Φ a b)
    (hv : RootShape P a v) : RootShape P b v := by
  match h with
  | .refl => exact hv
  | .convert he => exact RootShape.norm.mp (he ▸ RootShape.norm.mpr hv)
  | .trans h g => exact RootShape.subtype g (RootShape.subtype h hv)
  | .refine (a := a) (b := b) h .. => exact RootShape.subtype (a := a) (b := b) h hv
  | .data .. | .forget | .introduce .. | .list .. => exact hv
  | .fn_effect .. | .lazy .. | .map_value .. | .dependentFn .. | .scoped .. | .scoped_forget => trivial

theorem typed_values_length {P B Ψ Q C Γ Φ vs as}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as) : vs.length = as.length := by
  match h with
  | .nil => rfl
  | .cons _ hs => exact congrArg Nat.succ (typed_values_length hs)

private theorem rootShape_of_typing_aux {P B Ψ Q C Γ Φ v a}
    (h : HasTypeVQ P B Ψ Q C Γ Φ v a) (hΓ : Γ = []) : RootShape P a v := by
  match h with
  | .V_Var hi _ => subst Γ; simp at hi
  | .V_Const (c := c) _ => cases c <;> first | exact ⟨_,rfl,rfl⟩ | trivial
  | .V_Con hc _ _ _ hs _ =>
    exact .inl ⟨_,_,_,_,rfl,hc,by simpa only [List.length_map] using typed_values_length hs⟩
  | .V_AtError (detail := detail) hs =>
    rw [hs.errorType_eq]
    obtain ⟨cd,hc,_,_,ha⟩ := hs.standard.2.2
    exact .inr ⟨detail,cd,rfl,hc,by simp [ha,atErrorFields,Detail.values,Detail.textFields]⟩
  | .V_List .. => exact ⟨_,rfl⟩
  | .V_Sub h hl .. => exact RootShape.subtype hl (rootShape_of_typing_aux h hΓ)
  | .V_Normal h => exact RootShape.norm.mpr (rootShape_of_typing_aux h hΓ)
  | .V_Refine (a := a) h .. => exact rootShape_of_typing_aux (a := a) h hΓ
  | .V_Lam .. | .V_DependentLam .. | .V_Closure .. | .V_Fun .. | .V_Prim .. | .V_Op .. |
      .V_ExternalRef .. | .V_ExternalHandle .. | .V_PathBases .. | .V_ScopePattern .. |
      .V_Checked .. | .V_CheckedRequest .. | .V_CheckedAt .. | .V_Map .. | .V_Set .. |
      .V_Dict .. | .V_Raise .. | .V_LocRef .. | .V_LocLazy .. | .V_Bytes .. | .V_Super .. => trivial

/-- 閉じた値の導出から根の形を得る。scoped_forget・正規化・篩を含む。 -/
theorem rootShape_of_typing {P B Ψ Q C Φ v a}
    (h : HasTypeVQ P B Ψ Q C [] Φ v a) : RootShape P a v := rootShape_of_typing_aux h rfl

theorem RootShape.scalar {P a v base} (h : RootShape P a v) (ha : a = .base base) :
    ∃ c, v = .const c ∧ c.type = .base base := by subst a; exact h

theorem RootShape.list {P a v element} (h : RootShape P a v) (ha : a = .list element) :
    ∃ elems, v = .list elems := by subst a; exact h

theorem RootShape.data {P a v d ts} (h : RootShape P a v) (ha : a = .data d ts) :
    (∃ c tys args cd, v = .con c tys args ∧ P.cons c = some cd ∧ args.length = cd.args.length) ∨
    (∃ detail cd, v = .atError detail ∧ P.cons "Scope.ScopeError.At" = some cd ∧
      cd.args.length = detail.values.length) := by subst a; exact h

theorem const_match_false {c c'} (h : matchVal (.const c) (.const c') = none) : patternMatches c c' = false := by
  simp only [matchVal] at h
  split at h
  · cases h
  · exact Bool.eq_false_iff.mpr (by assumption)

theorem literal_test_false {P c v lit t}
    (hc : c.patternAllowed = true) (hv : RootShape P (embedConst c).type v)
    (hp : pathLiteral? c = some lit) (hm : matchVal (.const c) v = none)
    (ht : v.toTerm? = some t) : ((PathTest.literal lit).predicate t).evalWith (fun _ => none) = some false := by
  cases c <;> simp only [Benitoite.Release.Const.patternAllowed,Bool.false_eq_true] at hc <;> try cases hc
  all_goals obtain ⟨c',rfl,hc'⟩ := RootShape.scalar hv rfl
  all_goals cases c' <;> simp [Const.type,embedConst] at hc'
  all_goals have hb := const_match_false hm
  all_goals simp [patternMatches,Integer64Value.toInt] at hb
  all_goals simp only [pathLiteral?,Option.some.injEq] at hp
  all_goals cases hp
  all_goals cases ht
  all_goals match_eval_simp <;> first | rfl | simp_all [eq_comm]

theorem character_le_decide (a b : Char) :
    (decide (a.toNat < b.toNat) || (a == b)) = decide (a.toNat ≤ b.toNat) := by
  by_cases he : a = b
  · simp [he]
  · have hn : a.toNat ≠ b.toNat := fun hh => he (Char.toNat_inj.mp hh)
    by_cases hl : a.toNat < b.toNat
    · simp [hl,Nat.le_of_lt hl]
    · have hnle : ¬ a.toNat ≤ b.toNat := by omega
      simp [hl,he,hnle]

theorem eval_integer_range (lo hi n : Integer64Value) :
    ((PathTest.integerRange lo.val hi.val).predicate (.integer n.val)).evalWith (fun _ => none) =
      some (patternRange (.integer lo) (.integer hi) (.integer n)) := by
  by_cases h1 : lo.val ≤ n.val <;> by_cases h2 : n.val ≤ hi.val <;>
    simp [PathTest.predicate,Pred.evalWith,Pred.atomReady,Pred.atomValue,patternRange,Integer64Value.toInt,
      termReady,Term.observe,Term.interpret,Observation.sort,observeAs,integerAs,h1,h2]

theorem eval_character_range (lo hi n : Char) :
    ((PathTest.characterRange lo hi).predicate (.character n)).evalWith (fun _ => none) =
      some (patternRange (.character lo) (.character hi) (.character n)) := by
  change (match some (decide (lo.toNat < n.toNat) || (lo == n)),
      some (decide (n.toNat < hi.toNat) || (n == hi)) with
    | some false, _ | _, some false => some false
    | some true, some true => some true | _, _ => none) = _
  rw [character_le_decide,character_le_decide]
  by_cases h1 : lo.toNat ≤ n.toNat <;> by_cases h2 : n.toNat ≤ hi.toNat <;> simp [patternRange,h1,h2]

private theorem range_test_false_aux {P pat lo hi v test t a δ}
    (hpat : PatTy P pat a δ) (hr : pat = .range lo hi) (hv : RootShape P a v)
    (hp : patternTest? (.range lo hi) = some test) (hm : matchVal (.range lo hi) v = none)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some false := by
  match hpat with
  | .P_Refined hp' => exact range_test_false_aux hp' hr hv hp hm ht
  | .P_Convert he hp' => exact range_test_false_aux hp' hr (RootShape.norm.mp (he.symm ▸ RootShape.norm.mpr hv)) hp hm ht
  | .P_RangeInt =>
    cases hr
    obtain ⟨c,rfl,hc⟩ := RootShape.scalar hv rfl
    cases c <;> simp [Const.type] at hc
    rename_i lo hi n
    have hb : patternRange (.integer lo) (.integer hi) (.integer n) = false := by
      simp only [matchVal] at hm
      split at hm
      · cases hm
      · exact Bool.eq_false_iff.mpr (by assumption)
    cases ht
    have he : test = .integerRange lo.val hi.val := by simpa [patternTest?] using hp.symm
    subst test
    simpa only [Integer64Value.toInt,hb] using eval_integer_range lo hi n
  | .P_RangeChar =>
    cases hr
    obtain ⟨c,rfl,hc⟩ := RootShape.scalar hv rfl
    cases c <;> simp [Const.type] at hc
    rename_i lo hi n
    have hb : patternRange (.character lo) (.character hi) (.character n) = false := by
      simp only [matchVal] at hm
      split at hm
      · cases hm
      · exact Bool.eq_false_iff.mpr (by assumption)
    cases ht
    have he : test = .characterRange lo hi := by simpa [patternTest?] using hp.symm
    subst test
    simpa only [hb] using eval_character_range lo hi n
  | .P_Wild | .P_Var | .P_Const _ | .P_List _ _ _ | .P_Con _ _ _ _ => cases hr
termination_by structural hpat

theorem range_test_false {P lo hi v test t a δ}
    (hpat : PatTy P (.range lo hi) a δ) (hv : RootShape P a v)
    (hp : patternTest? (.range lo hi) = some test) (hm : matchVal (.range lo hi) v = none)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some false :=
  range_test_false_aux hpat rfl hv hp hm ht

theorem PatTys.arity_length {P ps as δ} (h : PatTys P ps as δ) : ps.length = as.length := by
  match h with
  | .nil => rfl
  | .cons _ hs => exact congrArg Nat.succ (PatTys.arity_length hs)

theorem irrefutable_fields_match {ps vs} (hf : ps.all irrefutableField = true)
    (hl : ps.length = vs.length) : ∃ ws, matchList ps vs = some ws := by
  induction ps generalizing vs with
  | nil => cases vs <;> simp_all [matchList]
  | cons p ps ih =>
    cases vs with
    | nil => simp at hl
    | cons v vs =>
      have hparts : irrefutableField p = true ∧ ps.all irrefutableField = true := by simpa only [List.all_cons,Bool.and_eq_true] using hf
      have hp := hparts.1
      obtain ⟨ws,hw⟩ := ih hparts.2 (by simpa using hl)
      cases p <;> simp only [irrefutableField] at hp <;> try cases hp
      · exact ⟨ws,by simp [matchList,matchVal,hw]⟩
      · exact ⟨v::ws,by simp [matchList,matchVal,hw]⟩

theorem constructor_test_false {P c ps cd ts δ v t}
    (hc : P.cons c = some cd) (hp : PatTys P ps (cd.args.map (Ty.subst ts [])) δ)
    (hfields : ps.all irrefutableField = true) (hv : RootShape P (.data cd.data ts) v)
    (hm : matchVal (.con c ps) v = none) (ht : v.toTerm? = some t) :
    (Pred.constructorIs t c).evalWith (fun _ => none) = some false := by
  have hps : ps.length = cd.args.length := by simpa only [List.length_map] using PatTys.arity_length hp
  rcases RootShape.data hv rfl with ⟨c',tys,args,cd',rfl,hc',hargs⟩ | ⟨detail,cdAt,rfl,hAt,hAtLen⟩
  · have he : c' ≠ c := by
      intro he; subst c'
      have hd : cd' = cd := Option.some.inj (hc'.symm.trans hc)
      subst cd'
      obtain ⟨ws,hw⟩ := irrefutable_fields_match hfields (hps.trans hargs.symm)
      simp [matchVal,hw] at hm
    cases ht
    simpa [he] using eval_constructor c c' (Val.toTermSlots args)
  · have he : "Scope.ScopeError.At" ≠ c := by
      intro he; subst c
      have hd : cdAt = cd := Option.some.inj (hAt.symm.trans hc)
      subst cdAt
      have hlen : ps.length = detail.values.length := hps.trans hAtLen
      obtain ⟨ws,hw⟩ := irrefutable_fields_match hfields hlen
      simp [matchVal,hw] at hm
    cases ht
    simpa [he] using eval_constructor c "Scope.ScopeError.At" (detail.textFields.map (fun x => some (.string x)))

private theorem empty_test_excluded_aux {P pat a δ v t}
    (hp : PatTy P pat a δ) (hr : pat = .list [] none []) (hv : RootShape P a v)
    (hm : matchVal (.list [] none []) v = none) (ht : v.toTerm? = some t) :
    (PathTest.nonempty.predicate t).evalWith (fun _ => none) = some true := by
  match hp with
  | .P_Refined hp' => exact empty_test_excluded_aux hp' hr hv hm ht
  | .P_Convert he hp' => exact empty_test_excluded_aux hp' hr (RootShape.norm.mp (he.symm ▸ RootShape.norm.mpr hv)) hm ht
  | .P_List hb ha _ =>
    cases hr
    obtain ⟨elems,rfl⟩ := RootShape.list hv rfl
    have hpos : 0 < elems.length := by
      by_cases h : 0 < elems.length
      · exact h
      have he : elems = [] := List.eq_nil_of_length_eq_zero (by omega)
      subst elems
      simp [matchVal,matchList] at hm
    cases ht
    simpa [Val.toTermSlots_eq_map,hpos] using eval_nonempty (Val.toTermSlots elems)
  | .P_Wild | .P_Var | .P_Const _ | .P_RangeInt | .P_RangeChar | .P_Con _ _ _ _ => cases hr
termination_by structural hp

theorem empty_test_excluded {P a δ v t}
    (hp : PatTy P (.list [] none []) a δ) (hv : RootShape P a v)
    (hm : matchVal (.list [] none []) v = none) (ht : v.toTerm? = some t) :
    (PathTest.nonempty.predicate t).evalWith (fun _ => none) = some true :=
  empty_test_excluded_aux hp rfl hv hm ht

theorem excluded_list_cases {before rest after test}
    (hp : excludedTest? (.list before rest after) = some test) :
    test = .nonempty ∧ before = [] ∧ rest = none ∧ after = [] := by
  cases before <;> cases rest <;> cases after <;> simp_all [excludedTest?]

theorem eval_not_of_false {p : Pred} {η : ObservationEnvModel} (h : p.evalWith η = some false) :
    p.not.evalWith η = some true := by
  change (p.evalWith η).map Bool.not = some true
  rw [h]
  rfl

/-- パターンの入力型に適合する実際の値を使う。値幅や構成子の欄数を観測の sort だけで代用しない。 -/
theorem pattern_excluded_true {P pat a δ v test t}
    (hpat : PatTy P pat a δ) (hv : RootShape P a v)
    (hp : excludedTest? pat = some test) (hm : matchVal pat v = none)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some true := by
  have hpat0 := hpat
  match hpat with
  | .P_Refined hp' => exact pattern_excluded_true hp' hv hp hm ht
  | .P_Convert he hp' => exact pattern_excluded_true hp' (RootShape.norm.mp (he.symm ▸ RootShape.norm.mpr hv)) hp hm ht
  | .P_Wild | .P_Var => cases hp
  | .P_Const hc =>
    rename_i c
    cases hl : pathLiteral? c with
    | none => simp [excludedTest?,hl] at hp
    | some lit =>
      have he : test = .negated (.literal lit) := by simpa [excludedTest?,hl] using hp.symm
      subst test
      have hf := literal_test_false hc hv hl hm ht
      simpa only [PathTest.predicate] using eval_not_of_false hf
  | .P_RangeInt =>
    rename_i lo hi
    have he : test = .negated (.integerRange lo.val hi.val) := by simpa [excludedTest?] using hp.symm
    subst test
    have hf := range_test_false hpat0 hv (test := .integerRange lo.val hi.val) rfl hm ht
    simpa only [PathTest.predicate] using eval_not_of_false hf
  | .P_RangeChar =>
    rename_i lo hi
    have he : test = .negated (.characterRange lo hi) := by simpa [excludedTest?] using hp.symm
    subst test
    have hf := range_test_false hpat0 hv (test := .characterRange lo hi) rfl hm ht
    simpa only [PathTest.predicate] using eval_not_of_false hf
  | .P_List hb ha _ =>
    obtain ⟨rfl,rfl,rfl,rfl⟩ := excluded_list_cases hp
    exact empty_test_excluded hpat0 hv hm ht
  | .P_Con hc hn hw hps =>
    simp only [excludedTest?] at hp
    split at hp
    · rename_i hall
      cases Option.some.inj hp
      have hf := constructor_test_false hc hps hall hv hm ht
      simpa only [PathTest.predicate] using eval_not_of_false hf
    · cases hp

theorem excluded_true {P alts a δ v test t}
    (ha : AltsTy P alts a δ) (hv : RootShape P a v)
    (hf : firstAlt v alts = none) (hm : test ∈ excludedTests alts)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some true := by
  obtain ⟨alt,hmem,hp⟩ := List.mem_filterMap.mp hm
  obtain ⟨γ,hpat,_,_⟩ := ha.2.2.2 alt hmem
  exact pattern_excluded_true hpat hv hp (firstAlt_none_all ha hf alt hmem) ht

theorem excluded_evalClosed_true {P alts a δ v test t}
    (ha : AltsTy P alts a δ) (hv : RootShape P a v)
    (hf : firstAlt v alts = none) (hm : test ∈ excludedTests alts)
    (ht : v.toTerm? = some t) (hw : (test.predicate t).WF 0)
    (hs : (test.predicate t).Sorted [] none) : (test.predicate t).evalClosed = some true := by
  unfold Pred.evalClosed
  rw [if_pos (show (test.predicate t).WF 0 ∧ (test.predicate t).Sorted [] none from ⟨hw,hs⟩)]
  exact excluded_true ha hv hf hm ht

theorem matched_paths_true {v alts ws}
    (hm : firstAlt v alts = some ws)
    (hw : ∀ p ∈ pathFacts v.toTerm? (matchedTests alts), p.WF 0 ∧ p.Sorted [] none) :
    PathsEvaluated v (matchedTests alts) := by
  intro p hp
  cases ht : v.toTerm? with
  | none => simp [pathFacts,ht] at hp
  | some t =>
    have hmem : p ∈ (matchedTests alts).map (fun test => test.predicate t) := by simpa only [pathFacts,ht] using hp
    obtain ⟨test,hTest,rfl⟩ := List.mem_map.mp hmem
    exact matched_evalClosed_true hm hTest ht (hw _ hp).1 (hw _ hp).2

theorem excluded_paths_true {P alts a δ v}
    (ha : AltsTy P alts a δ) (hv : RootShape P a v) (hm : firstAlt v alts = none)
    (hw : ∀ p ∈ pathFacts v.toTerm? (excludedTests alts), p.WF 0 ∧ p.Sorted [] none) :
    PathsEvaluated v (excludedTests alts) := by
  intro p hp
  cases ht : v.toTerm? with
  | none => simp [pathFacts,ht] at hp
  | some t =>
    have hmem : p ∈ (excludedTests alts).map (fun test => test.predicate t) := by simpa only [pathFacts,ht] using hp
    obtain ⟨test,hTest,rfl⟩ := List.mem_map.mp hmem
    exact excluded_evalClosed_true ha hv hm hTest ht (hw _ hp).1 (hw _ hp).2

/-- 根の形の補助入力は閉じた値の型付けから構成する。 -/
theorem excluded_true_of_typing {P B Ψ Q C Φ alts a δ v test t}
    (ha : AltsTy P alts a δ) (hv : HasTypeVQ P B Ψ Q C [] Φ v a)
    (hf : firstAlt v alts = none) (hm : test ∈ excludedTests alts)
    (ht : v.toTerm? = some t) : (test.predicate t).evalWith (fun _ => none) = some true :=
  excluded_true ha (rootShape_of_typing hv) hf hm ht

theorem excluded_evalClosed_true_of_typing {P B Ψ Q C Φ alts a δ v test t}
    (ha : AltsTy P alts a δ) (hv : HasTypeVQ P B Ψ Q C [] Φ v a)
    (hf : firstAlt v alts = none) (hm : test ∈ excludedTests alts)
    (ht : v.toTerm? = some t) (hw : (test.predicate t).WF 0)
    (hs : (test.predicate t).Sorted [] none) : (test.predicate t).evalClosed = some true :=
  excluded_evalClosed_true ha (rootShape_of_typing hv) hf hm ht hw hs

theorem excluded_paths_true_of_typing {P B Ψ Q C Φ alts a δ v}
    (ha : AltsTy P alts a δ) (hv : HasTypeVQ P B Ψ Q C [] Φ v a)
    (hm : firstAlt v alts = none)
    (hw : ∀ p ∈ pathFacts v.toTerm? (excludedTests alts), p.WF 0 ∧ p.Sorted [] none) :
    PathsEvaluated v (excludedTests alts) :=
  excluded_paths_true ha (rootShape_of_typing hv) hm hw

end/-- 実行時に構成子の欄だけをたどる。ScopeErrorも通常の欄列として読む。 -/
def conFields? : Val → Option (ConName × List Val)
  | .con c _ vs => some (c,vs)
  | .atError detail => some ("Scope.ScopeError.At",detail.values)
  | _ => none

def readPath (v : Val) : List FieldRef → Option Val
  | [] => some v
  | r :: rs => do
    let (c,vs) ← conFields? v
    if c = r.constructor then readPath (←vs[r.position]?) rs else none

/-- matchListの中の一つのパターンの束縛位置を、連結後の位置へ対応させる。 -/
theorem matchList_selected {ps vs ws j p}
    (hm : matchList ps vs = some ws) (hp : ps[j]? = some p) :
    ∃ v zs, vs[j]? = some v ∧ matchVal p v = some zs ∧
      ∀ i w, zs[i]? = some w → ws[Pat.bindersList (ps.take j)+i]? = some w := by
  induction ps generalizing vs ws j with
  | nil => simp at hp
  | cons head ps ih =>
    cases vs with
    | nil => cases hm
    | cons v vs =>
      simp only [matchList] at hm
      cases hhead : matchVal head v with
      | none => simp [hhead] at hm
      | some front =>
        cases htail : matchList ps vs with
        | none => simp [hhead,htail] at hm
        | some back =>
          simp [hhead,htail] at hm
          subst ws
          cases j with
          | zero =>
            cases Option.some.inj hp
            refine ⟨v,front,rfl,hhead,?_⟩
            intro i w hw
            have hi : i < front.length := (List.getElem?_eq_some_iff.mp hw).1
            simpa [Pat.bindersList,List.getElem?_append,hi] using hw
          | succ j =>
            obtain ⟨w,zs,hw,hz,hindex⟩ := ih htail hp
            refine ⟨w,zs,hw,hz,?_⟩
            intro i x hx
            have hb := hindex i x hx
            have count := matchVal_binders hhead
            simp only [List.take_succ_cons,Pat.bindersList]
            rw [←count]
            simp only [List.getElem?_append]
            rw [ite_eq_right (by omega)]
            simpa [Nat.add_assoc] using hb

/-- 巣の構成子を含め、生成に使う生の束縛が実際の欄の値である。 -/
theorem BinderPath.matched {pat i rs} (hp : BinderPath pat i rs) {v ws}
    (hm : matchVal pat v = some ws) :
    ∃ w, ws[i]? = some w ∧ readPath v rs = some w := by
  induction hp generalizing v ws with
  | var =>
    cases Option.some.inj hm
    exact ⟨v,rfl,rfl⟩
  | @con c ps j p i route ref hat constructor position child ih =>
    cases v <;> simp only [matchVal] at hm
    all_goals first | (cases hm; done) | skip
    case con c' ts vs =>
      split at hm
      · rename_i he; subst c'
        obtain ⟨w,zs,hw,hz,hindex⟩ := matchList_selected hm hat
        obtain ⟨x,hx,hr⟩ := ih hz
        refine ⟨x,hindex i x hx,?_⟩
        simp [readPath,conFields?,constructor,position,hw,hr]
      · cases hm
    case atError detail =>
      split at hm
      · rename_i he
        obtain ⟨w,zs,hw,hz,hindex⟩ := matchList_selected hm hat
        obtain ⟨x,hx,hr⟩ := ih hz
        refine ⟨x,hindex i x hx,?_⟩
        simp [readPath,conFields?,constructor,position,he,hw,hr]
      · cases hm



private theorem value_observe_shape {v : Val} {t : Term} {s : «Sort»}
    (ht : v.toTerm? = some t) (hs : t.Shape [] s) (η : ObservationEnvModel) :
    ∃ o, t.observe η = some o ∧ o.sort = s := by
  cases v
  case var i => cases Option.some.inj ht; obtain ⟨a,ha,_⟩ := hs; cases ha
  case const c =>
    cases c <;> simp only [Val.toTerm?,reduceCtorEq] at ht <;> cases Option.some.inj ht <;> exact ⟨_,rfl,hs.symm⟩
  all_goals simp only [Val.toTerm?,reduceCtorEq] at ht
  all_goals cases Option.some.inj ht
  all_goals exact ⟨_,rfl,hs.symm⟩

private def routeInputSort (route : List FieldRef) (s : «Sort») : «Sort» :=
  match route with | [] => s | _ :: _ => .data

private theorem routeTerm_input_shape {Γ t route s}
    (hs : (routeTerm t route).Shape Γ s) : t.Shape Γ (routeInputSort route s) := by
  induction route generalizing t with
  | nil => exact hs
  | cons r rs ih =>
    have hh := ih (t := .field r t) hs
    exact hh.1

private theorem readPath_data {v route w} (hne : route ≠ []) (h : readPath v route = some w) :
    ∃ c slots, v.toTerm? = some (.dataValue c slots) := by
  cases route with
  | nil => contradiction
  | cons r rs =>
    cases v <;> simp only [readPath,conFields?] at h <;> try cases h
    all_goals exact ⟨_,_,rfl⟩

private theorem observeSlots_at {vs : List Val} {i : Nat} {v : Val} (hv : vs[i]? = some v)
    (η : ObservationEnvModel) :
    (observeSlots η (Val.toTermSlots vs))[i]? = some (v.toTerm?.bind (Term.observe η)) := by
  induction vs generalizing i with
  | nil => cases hv
  | cons x xs ih =>
    cases i with
    | zero => cases Option.some.inj hv; cases h : v.toTerm? <;> simp [Val.toTermSlots,observeSlots,h]
    | succ i => cases h : x.toTerm? <;> simpa [Val.toTermSlots,observeSlots,h] using ih hv

/-- 欄のsortと実際の欄の値を使い、巣の経路の部分観測が成功することを示す。 -/
private theorem readPath_observe {v w : Val} {route : List FieldRef} {t : Term} {s : «Sort»}
    {η : ObservationEnvModel} {o : Observation}
    (hr : readPath v route = some w)
    (ht : t.observe η = v.toTerm?.bind (Term.observe η))
    (hs : (routeTerm t route).Shape [] s)
    (ho : w.toTerm?.bind (Term.observe η) = some o) (hos : o.sort = s) :
    (routeTerm t route).observe η = some o := by
  induction route generalizing v t with
  | nil => cases Option.some.inj hr; exact ht.trans ho
  | cons r rs ih =>
    have hstep := routeTerm_input_shape (t := .field r t) hs
    obtain ⟨c,vs,hcv,hindex,hread⟩ : ∃ c vs, conFields? v = some (c,vs) ∧
        c = r.constructor ∧ ∃ u, vs[r.position]? = some u ∧ readPath u rs = some w := by
      cases hc : conFields? v with
      | none => simp [readPath,hc] at hr
      | some pair =>
        rcases pair with ⟨c,vs⟩
        simp only [readPath,hc] at hr
        dsimp only [Bind.bind,Option.bind] at hr
        split at hr
        · rename_i he
          cases hu : vs[r.position]? with
          | none => simp [hu] at hr
          | some u => exact ⟨c,vs,rfl,he,u,hu,by simpa only [hu] using hr⟩
        · cases hr
    obtain ⟨u,hu,hur⟩ := hread
    have huSort : ∃ ou, u.toTerm?.bind (Term.observe η) = some ou ∧ ou.sort = r.result := by
      cases rs with
      | nil =>
        cases Option.some.inj hur
        exact ⟨o,ho,hos.trans hstep.2⟩
      | cons a rest =>
        obtain ⟨d,slots,hud⟩ := readPath_data (by simp) hur
        exact ⟨.dataValue d (observeSlots η slots),by rw [hud]; rfl,hstep.2⟩
    obtain ⟨ou,hou,hous⟩ := huSort
    have htFields : t.observe η = some (.dataValue c (observeSlots η (Val.toTermSlots vs))) := by
      rw [ht]
      cases v <;> simp only [conFields?,Option.some.injEq,Prod.mk.injEq] at hcv
      all_goals first | (cases hcv; done) | skip
      case con c' ts args => obtain ⟨rfl,rfl⟩ := hcv; rfl
      case atError d =>
        obtain ⟨rfl,rfl⟩ := hcv
        simp [Val.toTerm?,Detail.values,Detail.textFields,Val.toTermSlots_eq_map,List.map_map,Term.observe]
    have hfield : (Term.field r t).observe η = u.toTerm?.bind (Term.observe η) := by
      simp only [Term.observe,htFields,hindex]
      dsimp only [Bind.bind,Option.bind]
      simp only [bne_self_eq_false,Bool.false_eq_true,ite_false]
      rw [observeSlots_at hu η]
      dsimp only [Bind.bind,Option.bind]
      cases hut : u.toTerm? with
      | none => simp [hut] at hou
      | some ut =>
        have huo : ut.observe η = some ou := by simpa [hut] using hou
        simp [hut,huo,hous]
    exact ih hur hfield hs



private theorem selectSlots_at {xs : List Val} {slots : List Nat} {ys : List Val} {i raw : Nat} {w : Val}
    (hs : selectSlots xs slots = some ys) (hi : slots[i]? = some raw)
    (hw : xs[raw]? = some w) : ys[i]? = some w := by
  induction slots generalizing ys i with
  | nil => cases hi
  | cons j slots ih =>
    cases hj : xs[j]? with
    | none => simp [selectSlots,hj] at hs
    | some x =>
      cases ht : selectSlots xs slots with
      | none => simp [selectSlots,hj,ht] at hs
      | some zs =>
        have he : ys = x :: zs := by simpa [selectSlots,hj,ht] using hs.symm
        subst ys
        cases i with
        | zero => cases Option.some.inj hi; simpa only [List.getElem?_cons_zero,hj] using hw
        | succ i => simpa only [List.getElem?_cons_succ] using ih (ys := zs) (i := i) ht hi

/-- slotsによる並べ替え後の束縛と、実行時の欄の経路は同じ値を選ぶ。 -/
theorem FieldLink.matched {alts n link v ws}
    (valid : FieldLink.Valid alts n link) (hm : firstAlt v alts = some ws) :
    ∃ w, ws[link.slot]? = some w ∧ readPath v link.route = some w := by
  obtain ⟨alt,ha,_,_,hslot,hpath,_⟩ := valid
  subst alts
  cases hr : matchVal alt.pat v with
  | none => simp [firstAlt,hr] at hm
  | some raw =>
    have hs : selectSlots raw alt.slots = some ws := by simpa [firstAlt,hr] using hm
    obtain ⟨w,hw,hread⟩ := BinderPath.matched hpath hr
    exact ⟨w,selectSlots_at hs hslot hw,hread⟩

private theorem integer_equality_eval {a b : Term} {z : Int}
    (ha : a.observe (fun _ => none) = some (.integer z))
    (hb : b.observe (fun _ => none) = some (.integer z)) :
    (Pred.eq a b).evalWith (fun _ => none) = some true := by
  have hai := Term.observe_sound ha
  have hbi := Term.observe_sound hb
  simp [Pred.evalWith,Pred.atomReady,termReady,ha,hb,Observation.sort,
    Pred.atomValue,integerAs,observeAs,hai,hbi]

/-- 整数欄の値又はList欄の長さの等号は、実際の部分観測で真である。 -/
theorem field_equality_true {v w : Val} {route : List FieldRef} {t tw : Term}
    {m : Option Measure}
    (hr : readPath v route = some w)
    (ht : t.observe (fun _ => none) = v.toTerm?.bind (Term.observe (fun _ => none)))
    (hw : w.toTerm? = some tw)
    (allowed : m = none ∨ m = some .listLength)
    (sl : (viewTerm m tw).Shape [] .integer)
    (sr : (viewTerm m (routeTerm t route)).Shape [] .integer) :
    (Pred.eq (viewTerm m tw) (viewTerm m (routeTerm t route))).evalWith (fun _ => none) = some true := by
  rcases allowed with rfl | rfl
  · obtain ⟨o,ho,hos⟩ := value_observe_shape hw sl (fun _ => none)
    have ho' : w.toTerm?.bind (Term.observe (fun _ => none)) = some o := by rw [hw]; exact ho
    have hright := readPath_observe hr ht sr ho' hos
    cases o <;> simp only [Observation.sort,reduceCtorEq] at hos
    exact integer_equality_eval ho hright
  · obtain ⟨o,ho,hos⟩ := value_observe_shape hw sl.1 (fun _ => none)
    have ho' : w.toTerm?.bind (Term.observe (fun _ => none)) = some o := by rw [hw]; exact ho
    have hright := readPath_observe hr ht sr.1 ho' hos
    cases o <;> simp only [Observation.sort,Measure.input,reduceCtorEq] at hos
    rename_i elements
    apply integer_equality_eval (z := Int.ofNat elements.length)
    · simp [viewTerm,Term.observe,ho,Observation.measure,Option.bind,Option.map]
    · simp [viewTerm,Term.observe,hright,Observation.measure,Option.bind,Option.map]


end Benitoite.Release.Refinement.MatchFacts
