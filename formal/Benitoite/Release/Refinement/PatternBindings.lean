import Benitoite.Release.Refinement.PatternBindingSupport
import Benitoite.Release.Refinement.AtPatterns

/-! # 照合成功から束縛列の型付け（設計書 01-12「篩を読む網羅性と値の意味」） -/
namespace Benitoite.Release.Refinement
noncomputable section
open PatternBindings

mutual
  theorem pattern_bindings_aux {P B Ψ p a δ v ws} (valid : P.VarianceValid)
      (hp : PatTy P p a δ) (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a.norm)
      (hm : matchVal p v = some ws) : HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm) := by
    match hp with
    | .P_Wild => cases Option.some.inj hm; exact .nil
    | .P_Var => cases Option.some.inj hm; exact .cons hv .nil
    | .P_Const _ | .P_RangeInt | .P_RangeChar =>
      cases v <;> simp only [matchVal] at hm
      all_goals first | cases hm | (split at hm <;> first | (cases Option.some.inj hm; exact .nil) | cases hm)
    | .P_Convert he hp =>
      rw [←he] at hv
      simpa only [List.map_map,Function.comp_def,Ty.norm_idem] using pattern_bindings_aux valid hp hv hm
    | .P_Refined hp => exact pattern_bindings_aux valid hp (forget_refined hv rfl) hm
    | .P_Con (cd := cd) (ts := ts) hc hn _ hs =>
      have ih := fun (vs ws : List Val) =>
        patterns_bindings_aux (B := B) (Ψ := Ψ) (vs := vs) (ws := ws) valid hs
      cases v <;> simp only [matchVal] at hm
      all_goals try cases hm
      case con c tys vs =>
        split at hm
        · rename_i he
          subst c
          have hvs := constructor_values valid rfl hv hc
          have heq : (cd.args.map (Ty.subst ts [])).map Ty.norm = cd.args.map (Ty.subst ts []) := by
            rw [List.map_map]
            apply List.map_congr_left
            intro a _
            change ((a.rawBind (typeEnvAt 0 ts [])).norm).norm = _
            exact Ty.norm_idem _
          have hts : Ty.subst (Ty.normTys ts) [] = Ty.subst ts [] := funext (fun a => Ty.subst_norm_images a ts)
          rw [hts] at hvs
          rw [←heq] at hvs
          exact ih _ _ hvs hm
        · cases hm
      case atError detail =>
        split at hm
        · rename_i he
          subst he
          obtain ⟨cd',hc',hzero,hargs⟩ := atError_declaration hv rfl
          have heq := Option.some.inj (hc.symm.trans hc')
          subst cd'
          have hts : ts = [] := List.eq_nil_iff_length_eq_zero.mpr (hn.trans hzero)
          subst ts
          have hvals := detail.values_typed P B Ψ Qempty [] [] []
          have heq : (cd.args.map (Ty.subst [] [])).map Ty.norm = atErrorFields := by rw [hargs]; rfl
          rw [←heq] at hvals
          exact ih _ _ hvals hm
        · cases hm
    | .P_List (before := before) (rest := rest) (after := after) (a := a) hb ha _ =>
      cases v <;> simp only [matchVal] at hm
      all_goals try cases hm
      rename_i elems
      obtain ⟨heach,hann⟩ := list_elements hv rfl
      by_cases hlen : (if rest.isSome then before.length + after.length ≤ elems.length else before.length + after.length = elems.length)
      · rw [ite_eq_left hlen] at hm
        cases hl : matchList before (elems.take before.length) with
        | none => simp [hl] at hm
        | some left =>
          cases hr : matchList after (elems.drop (elems.length-after.length)) with
          | none => simp [hl,hr] at hm
          | some right =>
            have hn : before.length + after.length ≤ elems.length := by
              cases rest <;> simp_all
            have hleft := patterns_bindings_aux valid hb
              (by
                simpa only [List.map_replicate] using values_replicate
                  (each_of_mem (fun v h => heach.member (List.mem_of_mem_take h)))
                  (show (elems.take before.length).length = before.length by simp; omega)) hl
            have hright := patterns_bindings_aux valid ha
              (by
                simpa only [List.map_replicate] using values_replicate
                  (each_of_mem (fun v h => heach.member (List.mem_of_mem_drop h)))
                  (show (elems.drop (elems.length-after.length)).length = after.length by simp; omega)) hr
            have hmiddle : HasTypeEachQ P B Ψ Qempty [] [] []
                ((elems.drop before.length).take (elems.length-(before.length+after.length))) a.norm :=
              each_of_mem (fun v h => heach.member (List.mem_of_mem_drop (List.mem_of_mem_take h)))
            cases rest with
            | none =>
              simp only [hl,hr] at hm
              cases Option.some.inj hm
              simpa only [restTys,List.append_nil,List.map_append] using values_append hleft hright
            | some rest =>
              cases rest with
              | skip =>
                simp only [hl,hr] at hm
                cases Option.some.inj hm
                simpa only [restTys,List.append_nil,List.map_append] using values_append hleft hright
              | bind =>
                simp only [hl,hr] at hm
                cases Option.some.inj hm
                have hmty : HasTypeVQ P B Ψ Qempty [] [] []
                    (.list ((elems.drop before.length).take (elems.length-(before.length+after.length)))) (.list a.norm) :=
                  .V_List hmiddle hann.wf hann.sorted hann.declared
                simpa only [restTys,List.map_append,List.map_cons,List.map_nil,Ty.norm] using
                  values_append (values_append hleft (.cons hmty .nil)) hright
      · rw [ite_eq_right hlen] at hm; cases hm
  termination_by structural hp
  theorem patterns_bindings_aux {P B Ψ ps as δ vs ws} (valid : P.VarianceValid)
      (hp : PatTys P ps as δ) (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs (as.map Ty.norm))
      (hm : matchList ps vs = some ws) : HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm) := by
    match hp with
    | .nil => cases hv; cases Option.some.inj hm; exact .nil
    | .cons (p := p) (ps := ps) hp hs =>
      cases hv with
      | cons hv ht =>
        rename_i v vs
        simp only [matchList] at hm
        cases hl : matchVal p v with
        | none => simp [hl] at hm
        | some left =>
          cases hr : matchList ps vs with
          | none => simp [hl,hr] at hm
          | some right =>
            simp only [hl,hr] at hm
            cases Option.some.inj hm
            simpa only [List.map_append] using values_append
              (pattern_bindings_aux valid hp hv hl) (patterns_bindings_aux valid hs ht hr)
  termination_by structural hp
end

theorem pattern_bindings_typed {P B Ψ p a δ v ws} (valid : P.VarianceValid)
    (hp : PatTy P p a δ) (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a.norm)
    (hm : matchVal p v = some ws) : HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm) :=
  pattern_bindings_aux valid hp hv hm

theorem patterns_bindings_typed {P B Ψ ps as δ vs ws} (valid : P.VarianceValid)
    (hp : PatTys P ps as δ) (hv : HasTypeVsQ P B Ψ Qempty [] [] [] vs (as.map Ty.norm))
    (hm : matchList ps vs = some ws) : HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm) :=
  patterns_bindings_aux valid hp hv hm

theorem HasTypeVsQ.select_slots {P B Ψ Q C Γ Φ vs as slots bs ws}
    (h : HasTypeVsQ P B Ψ Q C Γ Φ vs as)
    (ht : selectSlots as slots = some bs) (hv : selectSlots vs slots = some ws) :
    HasTypeVsQ P B Ψ Q C Γ Φ ws bs := by
  induction slots generalizing bs ws with
  | nil => cases Option.some.inj ht; cases Option.some.inj hv; exact .nil
  | cons i slots ih =>
    simp only [selectSlots] at ht hv
    cases hi : as[i]? with
    | none => simp [hi] at ht
    | some a =>
      obtain ⟨v,hvi,hva⟩ := h.get hi
      cases hts : selectSlots as slots with
      | none => simp [hi,hts] at ht
      | some ts =>
        cases hvs : selectSlots vs slots with
        | none => simp [hvi,hvs] at hv
        | some vs' =>
          simp only [hi,hts] at ht
          simp only [hvi,hvs] at hv
          cases Option.some.inj ht
          cases Option.some.inj hv
          exact .cons hva (ih hts hvs)

theorem alternatives_bindings_typed {P B Ψ alts a δ v ws} (valid : P.VarianceValid)
    (hp : AltsTy P alts a δ) (hv : HasTypeVQ P B Ψ Qempty [] [] [] v a.norm)
    (hm : firstAlt v alts = some ws) : HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm) := by
  have walk : ∀ alts : List Alt,
      (∀ alt ∈ alts, ∃ γ, PatTy P alt.pat a γ ∧ selectSlots γ alt.slots = some δ) →
      firstAlt v alts = some ws → HasTypeVsQ P B Ψ Qempty [] [] [] ws (δ.map Ty.norm) := by
    intro alts
    induction alts with
    | nil => intro _ hm; cases hm
    | cons alt alts ih =>
      intro hall hm
      simp only [firstAlt] at hm
      cases hmatch : matchVal alt.pat v with
      | none => exact ih (fun x hx => hall x (List.mem_cons_of_mem _ hx)) (by simpa only [hmatch] using hm)
      | some bindings =>
        obtain ⟨γ,hpat,hslots⟩ := hall alt List.mem_cons_self
        have hb := pattern_bindings_typed valid hpat hv hmatch
        exact hb.select_slots (by rw [selectSlots_map,hslots]; rfl) (by simpa only [hmatch] using hm)
  exact walk alts (fun alt hm => by
    obtain ⟨γ,hpat,_,hslots⟩ := hp.2.2.2 alt hm
    exact ⟨γ,hpat,hslots⟩) hm

theorem pattern_length_relation (vs ws : List Val)
    (hm : matchVal (.list [.var] (some .bind) []) (.list vs) = some ws) :
    ∃ v rest, vs = v :: rest ∧ ws = [v, .list rest] ∧ vs.length = rest.length + 1 := by
  cases vs with
  | nil => simp [matchVal] at hm
  | cons v rest =>
    have he : ws = [v,.list rest] := by simpa [matchVal,matchList] using hm.symm
    exact ⟨v,rest,rfl,he,by simp⟩

theorem pattern_length_close (cap : Capture) (vs ws : List Val)
    (hm : matchVal headRestPattern (.list vs) = some ws) :
    ∃ v rest, vs = v :: rest ∧ ws = [v,.list rest] ∧
      matchVal headRestPattern (closeVal cap (.list vs)) = some [closeVal cap v,.list (closeVals cap rest)] ∧
      (closeVal cap v).toTerm? = (v.subst cap.env).toTerm? ∧
      (closeVal cap (.list rest)).toTerm? = ((Val.list rest).subst cap.env).toTerm? ∧
      (closeVals cap vs).length = (closeVals cap rest).length + 1 := by
  obtain ⟨v,rest,he,hws,hlen⟩ := pattern_length_relation vs ws hm
  refine ⟨v,rest,he,hws,?_,closeVal_observation cap v,closeVal_observation cap (.list rest),?_⟩
  · rw [he]
    simp [headRestPattern,closeVal,closeVals,matchVal,matchList]
    rw [←closeVals_length cap rest]
    simp only [List.drop_length,List.take_length,matchList]
    rfl
  · simpa only [closeVals_length] using hlen


end
end Benitoite.Release.Refinement
