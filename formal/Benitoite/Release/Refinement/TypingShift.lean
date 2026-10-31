import Benitoite.Release.Refinement.HandlerAlgebra
import Benitoite.Release.Refinement.PatternSemantics
import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.LocalTransport
import Benitoite.Release.Refinement.MethodArguments

/-!
# 型付きの値を束縛の下へ移す

改名は順序を保つ shiftIndex に限る。捕捉境界では継続の変数を隠す。
-/
namespace Benitoite.Release.Refinement

theorem Ty.IntegerCarrier.ordinary {a : Ty} (h : a.IntegerCarrier) : a.Ordinary := Ty.HasSort.ordinary h

theorem Ty.NotContCore.ordinary {a : Ty} (h : a.NotContCore) : a.Ordinary := by
  cases a <;> simp_all [Ty.Ordinary, Ty.NotContCore, Ty.core]

theorem Ty.notContCore_of_wf_ordinary {nr nt nv a} (hw : Ty.WF nr nt nv a)
    (ho : a.Ordinary) : a.NotContCore := by
  cases a <;> simp_all [Ty.Ordinary, Ty.NotContCore, Ty.core]

/-- 使える変数だけを移し、None と捕捉時に隠す継続は要求しない。 -/
structure ShiftMap (k c : Nat) (Γ Δ : Ctx) : Prop where
  length : Δ.length = Γ.length+k
  lookup : ∀ i a, Γ[i]? = some (some a) → a.Ordinary →
    Δ[shiftIndex k c i]? = some (some (a.shiftV k c))

theorem renameTy_shiftIndex (k c : Nat) : renameTy (shiftIndex k c) = Ty.shiftV k c :=
  funext (fun a => (Ty.shiftV_eq_renameTy a k c).symm)

theorem renameEff_shiftIndex (k c : Nat) : renameEff (shiftIndex k c) = Eff.shiftV k c :=
  funext (fun e => (Eff.shiftV_eq_renameEff e k c).symm)

theorem ShiftMap.declarationRenaming {k c Γ Δ} (h : ShiftMap k c Γ Δ) :
    DeclarationRenaming Γ Δ (shiftIndex k c) := by
  constructor
  intro i a hi ho
  simpa only [renameTy_shiftIndex] using h.lookup i a hi ho

theorem ShiftMap.declared {P C k c Γ Δ a} (h : ShiftMap k c Γ Δ) (ha : Ty.Declared P C Γ a) :
    Ty.Declared P C Δ (a.shiftV k c) := by
  have hh := ha.rawSubstV h.declarationRenaming.images
  simpa only [Ty.rawSubstV_eq_rawBind, renEnv_values, renameTy, renEnv, ← renameTy_shiftIndex] using hh

theorem ShiftMap.predDeclared {P C k c Γ Δ a p} (h : ShiftMap k c Γ Δ)
    (hp : Pred.Declared P C Γ (some a) p) : Pred.Declared P C Δ (some (a.shiftV k c)) (p.shiftV k (c+1)) := by
  have hh := hp.bind h.declarationRenaming.images
  simpa only [Ty.rawSubstV_eq_rawBind, renEnv_values, Option.map_some, renameTy, renEnv,
    ← renameTy_shiftIndex, Pred.shiftV, ← upValues_shiftIndex] using hh

theorem ShiftMap.values {k c Γ Δ} (h : ShiftMap k c Γ Δ) :
    Term.ImagesSorted Γ Δ (renEnv (shiftIndex k c)).values := by
  intro i a sort hi ha
  have hg := h.lookup i a hi ha.ordinary
  have hs := (Ty.hasSort_shiftV a k c sort).mpr ha
  exact ⟨.var (shiftIndex k c i), rfl, ⟨a.shiftV k c, hg, hs.ordinary⟩,
    a.shiftV k c, hg, hs⟩

theorem ShiftMap.references {k c Γ Δ} (h : ShiftMap k c Γ Δ) :
    Term.ImageReferences Γ Δ (renEnv (shiftIndex k c)).values := by
  intro i a hi ho t ht
  cases ht
  exact ⟨a.shiftV k c, h.lookup i a hi ho, (Ty.ordinary_shiftV _ _ _).mpr ho⟩

theorem ShiftMap.facts {k c Γ Δ} (h : ShiftMap k c Γ Δ) {p} (hp : p ∈ Γ.facts) :
    p.shiftV k c ∈ Δ.facts := by
  obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
  refine Ctx.mem_facts.mpr ⟨shiftIndex k c i, a.shiftV k c, q.shiftV k (c+1),
    h.lookup i a hi (Ty.assume_ordinary hq), ?_, ?_⟩
  · rw [Ty.assume_shiftV]
    exact List.mem_map.mpr ⟨q, hq, rfl⟩
  · simp only [Pred.shiftV, ← upValues_shiftIndex, predBind_open_renaming, termBind?, termBind, Option.getD_some]

theorem ShiftMap.transport {k c Γ Δ Φ Ξ} (h : ShiftMap k c Γ Δ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
    Transport (renEnv (shiftIndex k c)) Γ Φ Δ Ξ := by
  refine ⟨h.values, h.references, (by intro i; simp [renEnv]), ?_⟩
  intro p hp
  rcases List.mem_append.mp hp with hp | hp
  · exact .hyp (List.mem_append_left _ (h.facts hp))
  · exact hf p hp

theorem hideConts_lookup {Γ : Ctx} {i : Nat} {a : Ty} : (hideConts Γ)[i]? = some (some a) ↔
    Γ[i]? = some (some a) ∧ a.Ordinary := by
  simp only [hideConts, List.getElem?_map]
  cases hi : Γ[i]? with
  | none => simp
  | some x => cases x with
    | none => simp
    | some t =>
      cases hc : t.core <;> simp [hc, Ty.Ordinary, Ordinary] <;> rintro rfl <;> simp [hc]

theorem ShiftMap.hide {k c Γ Δ} (h : ShiftMap k c Γ Δ) :
    ShiftMap k c (hideConts Γ) (hideConts Δ) := by
  constructor
  · simpa only [hideConts, List.length_map] using h.length
  · intro i a hi ha
    exact hideConts_lookup.mpr ⟨h.lookup i a (hideConts_lookup.mp hi).1 ha,
      (Ty.ordinary_shiftV _ _ _).mpr ha⟩

theorem ShiftMap.underParams {k c Γ Δ} (h : ShiftMap k c Γ Δ) (ps : List Ty) :
    ShiftMap k (c+ps.length) (bindParams Γ ps) (bindParams Δ (ps.map (Ty.shiftV k c))) := by
  constructor
  · simp only [bindParams, List.length_append, List.length_map, List.length_reverse, h.length]
    omega
  · intro i a hi ha
    by_cases hil : i < ps.length
    · have hie : shiftIndex k (c+ps.length) i = i := by simp [shiftIndex, show i<c+ps.length by omega]
      rw [hie]
      rw [bindParams, List.getElem?_append_left (by simpa using hil)]
      simp only [← List.map_reverse, List.getElem?_map, List.length_map]
      rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi
      simp only [List.getElem?_map] at hi
      cases hu : ps.reverse[i]? with
      | none => simp [hu] at hi
      | some u =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        simp only [Option.map_some, Ty.shiftV_comm]
    · have hij : ps.length ≤ shiftIndex k (c+ps.length) i := by unfold shiftIndex; split <;> omega
      have hie : shiftIndex k (c+ps.length) i - ps.length = shiftIndex k c (i-ps.length) := by
        unfold shiftIndex; split <;> split <;> omega
      rw [bindParams, List.getElem?_append_right (by simpa using hij)]
      simp only [List.length_map, List.length_reverse, List.getElem?_map, hie]
      rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi
      simp only [List.length_map, List.length_reverse, List.getElem?_map] at hi
      cases hu : Γ[i-ps.length]? with
      | none => simp [hu] at hi
      | some u => cases u with
        | none => simp [hu] at hi
        | some u =>
          simp only [hu, Option.map_some, Option.some.injEq] at hi
          cases hi
          rw [h.lookup _ u hu ((Ty.ordinary_shiftV _ _ _).mp ha)]
          simp only [Option.map_some, Ty.shiftV_comm]

theorem ShiftMap.underNone {k c Γ Δ} (h : ShiftMap k c Γ Δ) :
    ShiftMap k (c+1) Γ.extendNone Δ.extendNone := by
  refine ⟨by simp [Ctx.extendNone, h.length]; omega, ?_⟩
  intro i a hi ho
  cases i with
  | zero => simp [Ctx.extendNone] at hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨u, hu, he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some b =>
      cases he
      have hh := h.lookup i b hu ((Ty.ordinary_shiftV _ _ _).mp ho)
      have hs : shiftIndex k (c+1) (i+1) = shiftIndex k c i+1 := by unfold shiftIndex; split <;> split <;> omega
      simp only [Ctx.extendNone, hs, List.getElem?_cons_succ, List.getElem?_map, hh,
        Option.map_some, Ty.shiftV_comm]

theorem ShiftMap.outer (Γ : Ctx) (ps : List Ty) : ShiftMap ps.length 0 Γ (bindParams Γ ps) := by
  constructor
  · simp only [bindParams, List.length_append, List.length_map, List.length_reverse]; omega
  · intro i a hi ha
    simp only [shiftIndex, Nat.not_lt_zero, ↓reduceIte, bindParams]
    rw [List.getElem?_append_right (by simp only [List.length_map, List.length_reverse]; omega)]
    simp only [List.length_map, List.length_reverse, Nat.add_sub_cancel_right, List.getElem?_map,
      hi, Option.map_some]

theorem ShiftMap.outerNone (Γ : Ctx) : ShiftMap 1 0 Γ Γ.extendNone := by
  constructor
  · simp [Ctx.extendNone]
  · intro i a hi ho
    simp only [shiftIndex, Nat.not_lt_zero, ↓reduceIte, Ctx.extendNone,
      List.getElem?_cons_succ, List.getElem?_map, hi, Option.map_some]

theorem Entails.under_none {Γ : Ctx} {Φ p} (h : Entails (Γ.facts ++ Φ) p) :
    Entails (Γ.extendNone.facts ++ Φ.map Pred.lift) p.lift := by
  apply (h.bind (fun i => some (.var (i+1)))).weaken
  intro q hq
  obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
  rcases List.mem_append.mp hr with hr | hr
  · exact List.mem_append_left _ (Ctx.mem_facts_extendNone.mpr ⟨r,hr,rfl⟩)
  · exact List.mem_append_right _ (List.mem_map.mpr ⟨r,hr,rfl⟩)

theorem liftMany_eq (n : Nat) (Φ : List Pred) :
    liftMany n Φ = Φ.map (Pred.shiftV n 0) := by
  induction n with
  | zero =>
    change Φ = Φ.map (Pred.shiftV 0 0)
    have he : Pred.shiftV 0 0 = id := by
      funext p
      change predBind (fun i => some (.var (shiftIndex 0 0 i))) p = p
      have hi : (fun i => some (Term.var (shiftIndex 0 0 i))) = (fun i => some (.var i)) := by
        funext i; simp [shiftIndex]
      rw [hi]; exact predBind_id p
    rw [he, List.map_id]
  | succ n ih =>
    change (liftMany n Φ).map Pred.lift = _
    rw [ih, List.map_map]
    congr 1

    funext p
    simp only [Function.comp_apply, Pred.lift, Pred.shiftV, predBind_comp]
    congr 1

@[simp] theorem liftMany_one (Φ : List Pred) : liftMany 1 Φ = Φ.map Pred.lift := rfl

theorem liftMany_shiftV (n k c : Nat) (Φ : List Pred) :
    (liftMany n Φ).map (Pred.shiftV k (c+n)) = liftMany n (Φ.map (Pred.shiftV k c)) := by
  simp only [liftMany_eq, List.map_map]
  congr 1
  funext p
  simp only [Function.comp_apply, Pred.shiftV, predBind_comp]
  congr 1
  funext i
  simp only [Option.bind_some, termBind?, shiftIndex, Nat.not_lt_zero, ↓reduceIte]
  by_cases hi : i<c <;> simp [hi, show (i+n<c+n) ↔ i<c by omega]
  all_goals omega

theorem Entails.under_params {Γ Φ p} (h : Entails (Γ.facts ++ Φ) p) (ps : List Ty) :
    Entails ((bindParams Γ ps).facts ++ liftMany ps.length Φ) (p.shiftV ps.length 0) := by
  apply (h.bind (fun i => some (.var (shiftIndex ps.length 0 i)))).weaken
  intro q hq
  obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
  rcases List.mem_append.mp hr with hr | hr
  · exact List.mem_append_left _ ((ShiftMap.outer Γ ps).facts hr)
  · exact List.mem_append_right _ (by rw [liftMany_eq]; exact List.mem_map.mpr ⟨r, hr, rfl⟩)

theorem ShiftMap.conditions_params {k c Γ Δ Φ Ξ} (_h : ShiftMap k c Γ Δ)
    (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) (ps : List Ty) :
    ∀ p ∈ liftMany ps.length Φ,
      Entails ((bindParams Δ (ps.map (Ty.shiftV k c))).facts ++ liftMany ps.length Ξ)
        (p.shiftV k (c+ps.length)) := by
  intro p hp
  rw [liftMany_eq] at hp
  obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
  have he := (hf q hq).under_params (ps.map (Ty.shiftV k c))
  simp only [List.length_map] at he
  have eqp : (q.shiftV ps.length 0).shiftV k (c+ps.length) =
      (q.shiftV k c).shiftV ps.length 0 := by
    have := congrArg (fun xs => xs.head?) (liftMany_shiftV ps.length k c [q])
    simpa only [liftMany_eq, List.map_cons, List.map_nil, List.head?_cons, Option.some.injEq] using this
  rw [eqp]
  exact he

theorem Ctx.mem_facts_hide {Γ : Ctx} {p : Pred} : p ∈ (hideConts Γ).facts ↔ p ∈ Γ.facts := by
  constructor
  · intro hp
    obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
    exact Ctx.mem_facts.mpr ⟨i, a, q, (hideConts_lookup.mp hi).1, hq, rfl⟩
  · intro hp
    obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
    exact Ctx.mem_facts.mpr ⟨i, a, q, hideConts_lookup.mpr ⟨hi, Ty.assume_ordinary hq⟩, hq, rfl⟩

theorem Entails.hideConts {Γ Φ p} (h : Entails (Γ.facts ++ Φ) p) :
    Entails ((hideConts Γ).facts ++ Φ) p := by
  apply h.weaken
  intro q hq
  rcases List.mem_append.mp hq with hq | hq
  · exact List.mem_append_left _ (Ctx.mem_facts_hide.mpr hq)
  · exact List.mem_append_right _ hq

theorem Transport.entails {θ Γ Φ Δ Ξ p} (ht : Transport θ Γ Φ Δ Ξ)
    (h : Entails (Γ.facts ++ Φ) p) : Entails (Δ.facts ++ Ξ) (predBind θ.values p) := by
  apply (h.bind θ.values).cut
  intro q hq
  obtain ⟨r, hr, rfl⟩ := List.mem_map.mp hq
  exact ht.facts r hr

theorem ShiftMap.sorted {k c Γ Δ a} (h : ShiftMap k c Γ Δ) (ha : Ty.Sorted Γ a) :
    (a.shiftV k c).Sorted Δ := by
  rw [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
  exact Ty.sorted_rawSubstV ha _ h.values h.references

theorem ShiftMap.wf {k c Γ Δ nr nt a} (h : ShiftMap k c Γ Δ) (ha : Ty.WF nr nt Γ.length a) :
    (a.shiftV k c).WF nr nt Δ.length := by
  rw [h.length]
  exact Ty.wf_shiftV ha k c

theorem Ty.shiftV_of_wf_zero {nr nt a} (h : Ty.WF nr nt 0 a) (k c : Nat) : a.shiftV k c = a := by
  rw [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
  exact Ty.rawSubstV_of_wf_zero h _

theorem ShiftMap.annotation {P C k c Γ Δ a} (h : ShiftMap k c Γ Δ)
    (ha : Ty.Annotation P C Γ a) : Ty.Annotation P C Δ (a.shiftV k c) :=
  ⟨h.wf ha.wf, h.sorted ha.sorted, h.declared ha.declared⟩

@[simp] theorem Val.renameList_length (vs : List Val) (ξ : Nat → Nat) :
    (Val.renameList ξ vs).length = vs.length := by
  induction vs <;> simp_all [Val.renameList]

theorem Eff.shiftV_singleFail (a : Ty) (k c : Nat) :
    Eff.shiftV k c (Eff.singleFail a) = Eff.singleFail (a.shiftV k c) := by
  simp only [Eff.singleFail, Eff.shiftV, shiftVTys, Ty.norm_shiftV]

theorem shiftIndex_strict (k c : Nat) : ∀ i j, i < j → shiftIndex k c i < shiftIndex k c j := by
  intro i j h; unfold shiftIndex; split <;> split <;> omega

theorem ShiftMap.typeAnnotations {P C k c Γ Δ ts} (h : ShiftMap k c Γ Δ)
    (ht : TypeAnnotations P C Γ ts) : TypeAnnotations P C Δ (ts.map (Ty.shiftV k c)) := by
  intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact h.annotation (ht x hx)

theorem ShiftMap.rowAnnotations {P C k c Γ Δ es} (h : ShiftMap k c Γ Δ)
    (ht : RowAnnotations P C Γ es) : RowAnnotations P C Δ (es.map (Eff.shiftV k c)) := by
  intro a ha; obtain ⟨x, hx, rfl⟩ := List.mem_map.mp ha; exact h.annotation (ht x hx)

theorem ShiftMap.signature {P C k c Γ Δ t ks ts es} (h : ShiftMap k c Γ Δ)
    (ht : SignatureInstance P C Γ t ks ts es) :
    SignatureInstance P C Δ t ks (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) := by
  refine ⟨ht.source, h.typeAnnotations ht.types, ht.kinds.shift k c, h.rowAnnotations ht.rows, ?_⟩
  have hh := h.annotation ht.result
  simpa only [Ty.shiftV, instantiatedTel_shift_eq ht.source] using hh

theorem Builtins.ValueAssumptions.sat_shiftV_norm {P B C Γ Δ a p k c}
    (hA : Builtins.ValueAssumptions P B) (ha : Ty.Annotation P C Γ a)
    (hb : Ty.Annotation P C Δ (a.shiftV k c)) (hs : B.sat C a.norm p) :
    B.sat C (a.shiftV k c).norm p := by
  have hh := hA.sat_rename C Γ Δ a.norm p (shiftIndex k c) (shiftIndex_strict k c) ha.norm
    (by simpa only [renameTy_shiftIndex, ← Ty.norm_shiftV] using hb.norm) hs
  simpa only [renameTy_shiftIndex, ← Ty.norm_shiftV] using hh

theorem Builtins.ValueAssumptions.admits_shiftV_norm {P B C Γ Δ b sg ts k c}
    (hA : Builtins.ValueAssumptions P B) (hl : B.sig b = some sg)
    (ha : TypeAnnotations P C Γ ts) (hb : TypeAnnotations P C Δ (ts.map (Ty.shiftV k c)))
    (hs : sg.admits C (Ty.normTys ts)) : sg.admits C (Ty.normTys (ts.map (Ty.shiftV k c))) := by
  have he : (Ty.normTys ts).map (renameTy (shiftIndex k c)) = Ty.normTys (ts.map (Ty.shiftV k c)) := by
    simp only [renameTy_shiftIndex, Ty.normTys_eq_map, List.map_map, Function.comp_def, Ty.norm_shiftV]
  simpa only [he] using hA.admits_rename b sg C Γ Δ (Ty.normTys ts) (shiftIndex k c) hl
    (shiftIndex_strict k c) ha.norm (by simpa only [he] using hb.norm) hs

theorem ShiftMap.admissible {P B C k c Γ Δ tps ne Qs Qt ts es e}
    (h : ShiftMap k c Γ Δ) (hA : Builtins.ValueAssumptions P B)
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : Admissible B C Γ.length tps ne Qs Qt ts es e) :
    Admissible B C Δ.length tps ne Qs Qt (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) e := by
  apply ha.map (Ty.shiftV k c) (Eff.shiftV k c)
  · apply ha.types.map
    intro a ha p hp
    exact hA.sat_shiftV_norm (ht a ha) (h.annotation (ht a ha)) hp
  · intro a hm; exact ⟨h.wf (ht a hm).wf, (Ty.ordinary_shiftV _ _ _).mpr (ha.typeScope a hm).2⟩
  · intro e he'; exact (h.annotation (he e he')).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hn => hn.shift_values k c) (fun _ => rfl)

theorem ShiftMap.primitive {P B C k c Γ Δ b sg Q ts es}
    (h : ShiftMap k c Γ Δ) (hA : Builtins.ValueAssumptions P B) (hb : B.sig b = some sg)
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : PrimitiveAdmissible C Γ.length sg Q ts es) :
    PrimitiveAdmissible C Δ.length sg Q (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) := by
  apply ha.map (Ty.shiftV k c) (Eff.shiftV k c)
  · exact hA.admits_shiftV_norm hb ht (h.typeAnnotations ht) ha.admits
  · intro a hm; exact ⟨h.wf (ht a hm).wf, (Ty.ordinary_shiftV _ _ _).mpr (ha.typeScope a hm).2⟩
  · intro e hm; exact (h.annotation (he e hm)).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hn => hn.shift_values k c) (fun _ => rfl)

theorem ShiftMap.methodRows {P C k c Γ Δ Q ms es} (h : ShiftMap k c Γ Δ)
    (he : RowAnnotations P C Γ es) (ha : MethodRowsAdmissible C Γ.length Q ms es) :
    MethodRowsAdmissible C Δ.length Q ms (es.map (Eff.shiftV k c)) :=
  ha.map _ (fun e hm => (h.annotation (he e hm)).wf.2.2.2.1)
    (ha.2.2.2.2.map _ (fun _ hn => hn.shift_values k c) (fun _ => rfl))

private theorem retained_shiftIndex_zero : shiftIndex 0 0 = id := by
  funext i; simp [shiftIndex]
private theorem retained_shift_zero (a : Ty) : a.shiftV 0 0 = a := by
  rw [Ty.shiftV_eq_renameTy, retained_shiftIndex_zero, renameTy_id]
private theorem retained_shift_empty : ShiftMap 0 0 [] [] :=
  ⟨rfl, by intro i a hi; simp at hi⟩

theorem Eff.shiftV_single (l : EffName) (k c : Nat) :
    Eff.shiftV k c (Eff.single l) = Eff.single l := rfl

/-- 計算の移動では、resumeが読む継続の位置も保存する。 -/
structure FullShiftMap (k c : Nat) (Γ Δ : Ctx) : Prop where
  length : Δ.length = Γ.length+k
  lookup : ∀ i a, Γ[i]? = some (some a) → Δ[shiftIndex k c i]? = some (some (a.shiftV k c))

theorem FullShiftMap.values {k c Γ Δ} (h : FullShiftMap k c Γ Δ) : ShiftMap k c Γ Δ :=
  ⟨h.length, fun i a hi _ => h.lookup i a hi⟩

theorem ShiftMap.hideFull {k c Γ Δ} (h : ShiftMap k c Γ Δ) :
    FullShiftMap k c (hideConts Γ) (hideConts Δ) :=
  ⟨h.hide.length, fun i a hi => h.hide.lookup i a hi (hideConts_lookup.mp hi).2⟩

theorem FullShiftMap.underParams {k c Γ Δ} (h : FullShiftMap k c Γ Δ) (ps : List Ty) :
    FullShiftMap k (c+ps.length) (bindParams Γ ps) (bindParams Δ (ps.map (Ty.shiftV k c))) := by
  constructor
  · simp only [bindParams, List.length_append, List.length_map, List.length_reverse, h.length]
    omega
  · intro i a hi
    by_cases hil : i < ps.length
    · have hie : shiftIndex k (c+ps.length) i = i := by simp [shiftIndex, show i<c+ps.length by omega]
      rw [hie]
      rw [bindParams, List.getElem?_append_left (by simpa using hil)]
      simp only [← List.map_reverse, List.getElem?_map, List.length_map]
      rw [bindParams, List.getElem?_append_left (by simpa using hil)] at hi
      simp only [List.getElem?_map] at hi
      cases hu : ps.reverse[i]? with
      | none => simp [hu] at hi
      | some u =>
        simp only [hu, Option.map_some, Option.some.injEq] at hi
        cases hi
        simp only [Option.map_some, Ty.shiftV_comm]
    · have hij : ps.length ≤ shiftIndex k (c+ps.length) i := by unfold shiftIndex; split <;> omega
      have hie : shiftIndex k (c+ps.length) i - ps.length = shiftIndex k c (i-ps.length) := by
        unfold shiftIndex; split <;> split <;> omega
      rw [bindParams, List.getElem?_append_right (by simpa using hij)]
      simp only [List.length_map, List.length_reverse, List.getElem?_map, hie]
      rw [bindParams, List.getElem?_append_right (by simpa using Nat.le_of_not_gt hil)] at hi
      simp only [List.length_map, List.length_reverse, List.getElem?_map] at hi
      cases hu : Γ[i-ps.length]? with
      | none => simp [hu] at hi
      | some u => cases u with
        | none => simp [hu] at hi
        | some u =>
          simp only [hu, Option.map_some, Option.some.injEq] at hi
          cases hi
          rw [h.lookup _ u hu]
          simp only [Option.map_some, Ty.shiftV_comm]

theorem FullShiftMap.underNone {k c Γ Δ} (h : FullShiftMap k c Γ Δ) :
    FullShiftMap k (c+1) Γ.extendNone Δ.extendNone := by
  refine ⟨by simp [Ctx.extendNone, h.length]; omega, ?_⟩
  intro i a hi
  cases i with
  | zero => simp [Ctx.extendNone] at hi
  | succ i =>
    simp only [Ctx.extendNone, List.getElem?_cons_succ, List.getElem?_map] at hi
    obtain ⟨u, hu, he⟩ := Option.map_eq_some_iff.mp hi
    cases u with
    | none => cases he
    | some b =>
      cases he
      have hh := h.lookup i b hu
      have hs : shiftIndex k (c+1) (i+1) = shiftIndex k c i+1 := by unfold shiftIndex; split <;> split <;> omega
      simp only [Ctx.extendNone, hs, List.getElem?_cons_succ, List.getElem?_map, hh,
        Option.map_some, Ty.shiftV_comm]

theorem FullShiftMap.outer (Γ : Ctx) (ps : List Ty) : FullShiftMap ps.length 0 Γ (bindParams Γ ps) := by
  constructor
  · simp only [bindParams, List.length_append, List.length_map, List.length_reverse]; omega
  · intro i a hi
    simp only [shiftIndex, Nat.not_lt_zero, ↓reduceIte, bindParams]
    rw [List.getElem?_append_right (by simp only [List.length_map, List.length_reverse]; omega)]
    simp only [List.length_map, List.length_reverse, Nat.add_sub_cancel_right, List.getElem?_map,
      hi, Option.map_some]

theorem FullShiftMap.outerNone (Γ : Ctx) : FullShiftMap 1 0 Γ Γ.extendNone := by
  constructor
  · simp [Ctx.extendNone]
  · intro i a hi
    simp only [shiftIndex, Nat.not_lt_zero, ↓reduceIte, Ctx.extendNone,
      List.getElem?_cons_succ, List.getElem?_map, hi, Option.map_some]

theorem FullShiftMap.hide {k c Γ Δ} (h : FullShiftMap k c Γ Δ) :
    FullShiftMap k c (hideConts Γ) (hideConts Δ) := h.values.hideFull


theorem Eff.shiftV_of_wf_zero {nr nt e} (h : Eff.WF nr nt 0 e) (k c : Nat) :
    Eff.shiftV k c e = e := by
  rw [Eff.shiftV_eq_renameEff, renameEff_eq_rawSubstV, Eff.rawSubstV_of_wf_zero h]

theorem liftMany_add (m n : Nat) (Φ : List Pred) :
    liftMany n (liftMany m Φ) = liftMany (m+n) Φ := by
  simp only [liftMany_eq, List.map_map, Function.comp_def, Pred.shiftV_add]

@[simp] theorem bindParams_single (Γ : Ctx) (a : Ty) : bindParams Γ [a]=Γ.extend a := rfl

theorem FullShiftMap.underMany {k c Γ Δ} (h : FullShiftMap k c Γ Δ) (ps : List Ty) :
    FullShiftMap k (c+ps.length) (Γ.extendMany ps) (Δ.extendMany (binderRenames k c ps)) := by
  induction ps generalizing Γ Δ c with
  | nil => simpa only [Ctx.extendMany,binderRenames,List.length_nil,Nat.add_zero] using h
  | cons a as ih =>
    have hh := ih (by simpa only [bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,Nat.zero_add] using h.underParams [a])
    simpa only [Ctx.extendMany,binderRenames,List.length_cons,Nat.add_assoc,Nat.add_comm 1] using hh

theorem FullShiftMap.shiftEAt {k c Γ Δ} (h : FullShiftMap k c Γ Δ) (n d : Nat) :
    FullShiftMap k c (Γ.shiftEAt n d) (Δ.shiftEAt n d) := by
  constructor
  · simpa only [Ctx.shiftEAt,List.length_map] using h.length
  · intro i a hi
    simp only [Ctx.shiftEAt,List.getElem?_map] at hi ⊢
    cases hg : Γ[i]? with
    | none => simp [hg] at hi
    | some u => cases u with
      | none => simp [hg] at hi
      | some b =>
        simp only [hg,Option.map_some,Option.some.injEq] at hi
        cases hi
        rw [h.lookup _ _ hg]
        simp only [Option.map_some,shiftTypes_shiftV]

theorem FullShiftMap.conditions_many {k c Γ Δ Φ Ξ} (h : FullShiftMap k c Γ Δ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (p.shiftV k c)) (ps : List Ty) :
    ∀ p∈liftMany ps.length Φ,
      Entails ((Δ.extendMany (binderRenames k c ps)).facts++liftMany ps.length Ξ) (p.shiftV k (c+ps.length)) := by
  induction ps generalizing Γ Δ c Φ Ξ with
  | nil =>
    change ∀ p∈Φ,Entails (Δ.facts++Ξ) (p.shiftV k c)
    exact hf
  | cons a as ih =>
    have hm : FullShiftMap k (c+1) (Γ.extend a) (Δ.extend (a.shiftV k c)) := by
      simpa only [bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,Nat.zero_add] using h.underParams [a]
    have hf1 : ∀ p∈Φ.map Pred.lift,Entails ((Δ.extend (a.shiftV k c)).facts++Ξ.map Pred.lift) (p.shiftV k (c+1)) := by
      simpa only [bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,Nat.zero_add,liftMany_one] using h.values.conditions_params hf [a]
    have hh := ih hm hf1
    simpa only [Ctx.extendMany,binderRenames,List.length_cons,←liftMany_one,liftMany_add,Nat.add_assoc,Nat.add_comm 1] using hh

theorem OpSig.continuation_shift_values {sg : OpSig} (hw : sg.WF) (t : Ty) (e : Eff) (k c : Nat) :
    (sg.continuation t e).shiftV k (c+sg.params.length)=sg.continuation (t.shiftV k c) (e.shiftV k c) := by
  simp only [OpSig.continuation,Ty.shiftV,Ty.shiftV_fixed_before hw.2 k (c+sg.params.length) (by omega),
    Ty.shiftV_comm,Eff.shiftV_comm,←shiftTypes_shiftV,←shiftRowsTypes_shiftV]

theorem FullShiftMap.clause {k c Γ Δ} (h : FullShiftMap k c Γ Δ) (sg : OpSig) (hw : sg.WF) (t : Ty) (e : Eff) :
    FullShiftMap k (c+(sg.params.length+1)) (sg.context Γ t e)
      (sg.context Δ (t.shiftV k c) (e.shiftV k c)) := by
  have hh := (h.shiftEAt sg.tparams.length 0).underMany sg.params
  have hps : binderRenames k c sg.params=sg.params := by simpa using binderRenames_fixed hw.1 k c
  rw [hps] at hh
  have hx := hh.underParams [sg.continuation t e]
  simpa only [OpSig.context,Ctx.shiftE,bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,
    Nat.zero_add,Nat.add_assoc,OpSig.continuation_shift_values hw] using hx

theorem FullShiftMap.conditions_clause {k c Γ Δ Φ Ξ} (h : FullShiftMap k c Γ Δ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (p.shiftV k c)) (sg : OpSig) (hw : sg.WF) (t : Ty) (e : Eff) :
    ∀ p∈liftMany (sg.params.length+1) Φ,
      Entails ((sg.context Δ (t.shiftV k c) (e.shiftV k c)).facts++liftMany (sg.params.length+1) Ξ)
        (p.shiftV k (c+(sg.params.length+1))) := by
  have hm0 := h.shiftEAt sg.tparams.length 0
  have hf0 : ∀ p∈Φ,Entails ((Δ.shiftE sg.tparams.length).facts++Ξ) (p.shiftV k c) :=
    fun p hp => (TypeCtxMap.shiftEAt Δ sg.tparams.length 0).entails (hf p hp)
  have hm1 := hm0.underMany sg.params
  have hf1 := hm0.conditions_many hf0 sg.params
  have hps : binderRenames k c sg.params=sg.params := by simpa using binderRenames_fixed hw.1 k c
  rw [hps] at hm1 hf1
  have hh := hm1.values.conditions_params hf1 [sg.continuation t e]
  simpa only [OpSig.context,Ctx.shiftE,bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,
    Nat.zero_add,←liftMany_one,liftMany_add,Nat.add_assoc,OpSig.continuation_shift_values hw] using hh

theorem FullShiftMap.failure {k c Γ Δ} (h : FullShiftMap k c Γ Δ) (E : Ty) :
    FullShiftMap k (c+2) (failureContext Γ E) (failureContext Δ (E.shiftV k c)) := by
  have hh := (h.shiftEAt 1 0).underParams [shiftTypes 1 0 E]
  have hx := hh.underNone
  simpa only [failureContext,Ctx.shiftE,bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,
    Nat.zero_add,←shiftTypes_shiftV,Nat.add_assoc] using hx

theorem FullShiftMap.conditions_failure {k c Γ Δ Φ Ξ} (h : FullShiftMap k c Γ Δ)
    (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (p.shiftV k c)) (E : Ty) :
    ∀ p∈liftMany 2 Φ,Entails ((failureContext Δ (E.shiftV k c)).facts++liftMany 2 Ξ) (p.shiftV k (c+2)) := by
  have hm0 := h.shiftEAt 1 0
  have hf0 : ∀ p∈Φ,Entails ((Δ.shiftE 1).facts++Ξ) (p.shiftV k c) :=
    fun p hp => (TypeCtxMap.shiftEAt Δ 1 0).entails (hf p hp)
  have hf1 := hm0.values.conditions_params hf0 [shiftTypes 1 0 E]
  simp only [bindParams_single,List.map_cons,List.map_nil,List.length_cons,List.length_nil,Nat.zero_add,liftMany_one,←shiftTypes_shiftV] at hf1
  intro p hp
  obtain ⟨q,hq,rfl⟩ := List.mem_map.mp hp
  simpa only [failureContext,Ctx.shiftE,Pred.shiftV_lift,Nat.add_assoc,show liftMany 2 Ξ=(Ξ.map Pred.lift).map Pred.lift from rfl] using (hf1 q hq).under_none

theorem shiftIndex_zero (c : Nat) : shiftIndex 0 c = id := by
  funext i; simp [shiftIndex]

theorem shiftIndex_add (k : Nat) : shiftIndex k 0 = (fun i => i+k) := by
  funext i; simp [shiftIndex]

theorem Ty.shiftV_zero (a : Ty) (c : Nat) : a.shiftV 0 c = a := by
  rw [Ty.shiftV_eq_renameTy, shiftIndex_zero, renameTy_id]

theorem Eff.shiftV_zero (e : Eff) (c : Nat) : Eff.shiftV 0 c e = e := by
  rw [Eff.shiftV_eq_renameEff, shiftIndex_zero, renameEff_id]

theorem Pred.shiftV_zero (p : Pred) (c : Nat) : p.shiftV 0 c = p := by
  simp only [Pred.shiftV, shiftIndex_zero]
  exact predBind_id p

theorem Tel.shiftV_zero (t : Tel) (c : Nat) : Tel.shiftV 0 c t = t := by
  rw [Tel.shiftV_eq_rawBind, shiftIndex_zero]
  exact Tel.rawBind_id t


mutual
  theorem HasTypeVQ.shift_values {P B store Q C Γ Φ v a}
      (h : HasTypeVQ P B store Q C Γ Φ v a) {k c Δ Ξ store'}
      (hA : Builtins.ValueAssumptions P B)
      (hstore : StoreTy.WF store)
      (hpres : StoreTy.PreservesNormals store store')
      (hm : ShiftMap k c Γ Δ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeVQ P B store' Q C Δ Ξ (v.rename (shiftIndex k c)) (a.shiftV k c) := by
    match h with
    | .V_Var hi ho => exact .V_Var (hm.lookup _ _ hi ho) ((Ty.ordinary_shiftV _ _ _).mpr ho)
    | .V_Const (c := con) hc =>
      have he : (Const.type con).shiftV k c = Const.type con := by
        cases con <;> rfl
      rw [he]
      exact .V_Const hc
    | .V_Lam (ps := ps) hn hw hs hb hd =>
      simp only [Val.rename, renameTy_shiftIndex, upRen_shiftIndex, Ty.shiftV, shiftVTys_eq_map]
      refine .V_Lam (by simpa only [NamesWF, List.length_map] using hn) ?_ ?_ ?_ ?_
      · simpa only [Ty.shiftV, shiftVTys_eq_map] using hm.wf hw
      · simpa only [Ty.shiftV, shiftVTys_eq_map] using hm.sorted hs
      · have hb' := HasTypeCQ.shift_values (store' := hideBuilders store') (L' := []) hb hA hstore.hide hpres.hide
          (hm.hideFull.underParams ps) (.empty _ _ _)
          (hm.hide.conditions_params (fun p hp => (hf p hp).hideConts) ps)
        simpa only [List.length_map, Ty.shiftV_comm, Eff.shiftV_comm, Option.map_some] using hb'
      · simpa only [Ty.shiftV, shiftVTys_eq_map] using hm.declared hd
    | .V_DependentLam (t := t) ha hb =>
      simp only [Val.rename, Ty.shiftV, ← Tel.shiftV_eq_rawBind]
      refine .V_DependentLam (hm.annotation ha) ?_
      have hh := TelBodyTy.shift_values hb hA hstore.hide hpres.hide hm.hideFull
        (fun p hp => (hf p hp).hideConts)
      simpa only [Val.rename, Tel.shiftV_eq_rawBind] using hh
    | .V_Closure (runtime := runtime) (t := t) ha hw hb =>
      change HasTypeVQ P B store' Q C Δ Ξ (.closure runtime _) ((Ty.dependentFn t).shiftV k c)
      rw [Ty.shiftV_of_wf_zero (show (Ty.dependentFn t).WF 0 0 0 from hw.contract_wf)]
      exact .V_Closure (by simpa only [Ty.shiftV_of_wf_zero (show (Ty.dependentFn t).WF 0 0 0 from hw.contract_wf)] using hm.annotation ha) hw
        (DependentClosureTy.store hb hA hstore hpres)
    | .V_List he hw hs hd =>
      exact .V_List (HasTypeEachQ.shift_values he hA hstore hpres hm hf) (hm.wf hw) (hm.sorted hs) (hm.declared hd)
    | .V_Fun hd hn ha hi =>
      have hh := HasTypeVQ.V_Fun (Ψ := store') (Φ := Ξ) hd hn (hm.admissible hA hi.types hi.rows ha) (hm.signature hi)
      simpa only [Val.rename, renameTy_shiftIndex, renameEff_shiftIndex,
        instantiatedTel_shift hi.source] using hh
    | .V_Prim hb hr hn ha hi =>
      have hh := HasTypeVQ.V_Prim (Ψ := store') (Φ := Ξ) hb hr hn (hm.primitive hA hb hi.types hi.rows ha) (hm.signature hi)
      simpa only [Val.rename, renameTy_shiftIndex, renameEff_shiftIndex,
        instantiatedTel_shift hi.source] using hh
    | .V_Op ho hn ha hi =>
      have hs := ha.map (Ty.shiftV k c) (fun a ha p hp => by
        exact hA.sat_shiftV_norm (hi.types a ha) (hm.annotation (hi.types a ha)) hp)
      have hh := HasTypeVQ.V_Op (Q := Q) (Ψ := store') (Φ := Ξ) ho hn hs (hm.signature hi)
      simpa only [Val.rename, renameTy_shiftIndex, renameEff_shiftIndex, List.map_nil,
        instantiatedTel_shift hi.source] using hh
    | .V_ExternalRef hd hw ha hi =>
      have hh := HasTypeVQ.V_ExternalRef (Q := Q) (Ψ := store') (Φ := Ξ) hd hw
        (ha.map hw (Ty.shiftV k c)) (hm.signature hi)
      simpa only [Val.rename, renameTy_shiftIndex, List.map_nil, instantiatedTel_shift hi.source] using hh
    | .V_ExternalHandle h td hd hc hr hn ha =>
      simpa only [Val.rename, renameTy_shiftIndex, Ty.shiftV, shiftVTys_eq_map] using
        HasTypeVQ.V_ExternalHandle (Ψ := store') (Φ := Ξ) h td hd hc hr
          (by simpa only [List.length_map] using hn)
          (by simpa only [Ty.shiftV, shiftVTys_eq_map] using hm.annotation ha)
    | .V_PathBases hs => exact .V_PathBases hs
    | .V_ScopePattern hw hc hk => exact .V_ScopePattern hw hc hk
    | .V_Checked hk hc hm => exact .V_Checked hk hc hm
    | .V_CheckedRequest hk hc hv hg ht hm =>
      have hh := HasTypeVQ.shift_values (store' := store') hv hA hstore hpres retained_shift_empty
        (Ξ := []) (by simp)
      simp only [retained_shiftIndex_zero, Val.rename_identity, retained_shift_zero] at hh
      exact .V_CheckedRequest hk hc hh hg ht hm
    | .V_CheckedAt hw => exact .V_CheckedAt (CheckedWitness.shift_store hw hA hstore hpres)
    | .V_AtError (shape := shape) hs =>
      simpa only [Val.rename, hs.errorType_eq, atErrorType, Ty.shiftV, shiftVTys] using
        (HasTypeVQ.V_AtError (Ψ := store') (Q := Q) (C := C) (Γ := Δ) (Φ := Ξ) hs)
    | .V_Map hk hv hn hs ha hb =>
      exact .V_Map (HasTypeEachQ.shift_values hk hA hstore hpres hm hf)
        (HasTypeEachQ.shift_values hv hA hstore hpres hm hf) (by simpa using hn)
        (hA.sat_shiftV_norm ha (hm.annotation ha) hs)
        (hm.annotation ha) (hm.annotation hb)
    | .V_Set hv hs ha =>
      exact .V_Set (HasTypeEachQ.shift_values hv hA hstore hpres hm hf)
        (hA.sat_shiftV_norm ha (hm.annotation ha) hs) (hm.annotation ha)
    | .V_Dict (id := id) (ts := ts) hi hs ht hk hw htarget hv ha =>
      have hv' := HasTypeVsQ.shift_values hv hA hstore hpres hm hf
      have he : (id.dictTys.map (Ty.subst ts [])).map (Ty.shiftV k c) =
          id.dictTys.map (Ty.subst (ts.map (Ty.shiftV k c)) []) := by
        rw [List.map_map]; exact List.map_congr_left (fun a ha => Ty.subst_shiftV_closed (hw a ha) ts k c)
      rw [he] at hv'
      have hs' := hs.map (Ty.shiftV k c) (fun a hm' p hp => by
        exact hA.sat_shiftV_norm (ht a hm') (hm.annotation (ht a hm')) hp)
      have ha' := hm.annotation ha
      simp only [Ty.shiftV, Ty.subst_shiftV_closed htarget] at ha' ⊢
      simpa only [Val.rename, renameTy_shiftIndex] using
        HasTypeVQ.V_Dict hi hs' (hm.typeAnnotations ht) (hk.shift k c) hw htarget hv' ha'
    | .V_Raise (t := t) (e := e) ha =>
      have hh := hm.annotation ha
      simp only [Val.rename, renameTy_shiftIndex, Ty.shiftV, shiftVTys_eq_map,
        List.map_cons, List.map_nil, Eff.shiftV_singleFail]
      apply HasTypeVQ.V_Raise
      simpa only [Ty.shiftV, shiftVTys_eq_map, List.map_cons, List.map_nil, Eff.shiftV_singleFail] using hh
    | .V_LocRef (a := a) hl hd =>
      have hw := hstore _ _ hl
      have he := Ty.shiftV_of_wf_zero hw k c
      simp only [Val.rename, Ty.shiftV, he]
      exact .V_LocRef (hpres _ _ hl trivial) (he ▸ hm.declared hd)
    | .V_LocLazy (a := a) hl hd =>
      have hw := hstore _ _ hl
      have he := Ty.shiftV_of_wf_zero hw k c
      simp only [Val.rename, Ty.shiftV, he]
      exact .V_LocLazy (hpres _ _ hl trivial) (he ▸ hm.declared hd)
    | .V_Bytes hb => exact .V_Bytes hb
    | .V_Con (cd := cd) (ts := ts) hc hn hk hw hv ha =>
      have hh := HasTypeVsQ.shift_values hv hA hstore hpres hm hf
      have he : (cd.args.map (Ty.subst ts [])).map (Ty.shiftV k c) =
          cd.args.map (Ty.subst (ts.map (Ty.shiftV k c)) []) := by
        rw [List.map_map]
        exact List.map_congr_left (fun a ha => Ty.subst_shiftV_closed (hw a ha) ts k c)
      rw [he] at hh
      simp only [Val.rename, renameTy_shiftIndex, Ty.shiftV, shiftVTys_eq_map]
      exact .V_Con hc (by simpa only [List.length_map] using hn) (hk.shift k c) hw hh (by simpa only [Ty.shiftV, shiftVTys_eq_map] using hm.annotation ha)
    | .V_Super hv hc hmemb hd =>
      exact .V_Super (HasTypeVQ.shift_values hv hA hstore hpres hm hf) hc hmemb (hm.declared hd)
    | .V_Normal hv =>
      simpa only [Ty.norm_shiftV] using (HasTypeVQ.shift_values hv hA hstore hpres hm hf).V_Normal
    | .V_Sub hv hl hw hs hd =>
      have hl' := hl.rawBind (renEnv (shiftIndex k c)) (hm.transport hf)
      change Ty.LeQ Δ Ξ (renameTy (shiftIndex k c) _) (renameTy (shiftIndex k c) _) at hl'
      rw [renameTy_shiftIndex] at hl'
      exact .V_Sub (HasTypeVQ.shift_values hv hA hstore hpres hm hf) hl' (hm.wf hw) (hm.sorted hs) (hm.declared hd)
    | .V_Refine (a := a) (t := t) (p := p) hv hi ht hs hw he hda hdp =>
      change HasTypeVQ P B store' Q C Δ Ξ _ (.refined (a.shiftV k c) (p.shiftV k (c+1)))
      refine .V_Refine (t := termBind (fun i => some (.var (shiftIndex k c i))) t)
        (HasTypeVQ.shift_values hv hA hstore hpres hm hf)
        ((Ty.hasSort_shiftV _ _ _ _).mpr hi) ?_ ?_ ?_ ?_ (hm.declared hda) (hm.predDeclared hdp)
      · simp only [Val.toTerm_rename, ht, Option.map_some]
      · simpa only [Pred.shiftV, ← upValues_shiftIndex] using
          Pred.sorted_bind hs (fun i => some (.var (shiftIndex k c i)))
            (fun sort hi => (Ty.hasSort_shiftV a k c sort).mpr hi)
            (fun hi => (Ty.ordinary_shiftV _ _ _).mpr hi) hm.values hm.references
      · simpa only [hm.length, Nat.add_assoc, Nat.add_right_comm Γ.length 1 k] using
          Pred.wf_shiftV hw k (c+1)
      · have he' := (hm.transport hf).entails he
        simpa only [renEnv_values, predBind_open_renaming, termBind?, termBind, Pred.shiftV, ← upValues_shiftIndex] using he'
  termination_by structural h
  theorem HasTypeVsQ.shift_values {P B store Q C Γ Φ vs as}
      (h : HasTypeVsQ P B store Q C Γ Φ vs as) {k c Δ Ξ store'}
      (hA : Builtins.ValueAssumptions P B)
      (hstore : StoreTy.WF store)
      (hpres : StoreTy.PreservesNormals store store')
      (hm : ShiftMap k c Γ Δ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeVsQ P B store' Q C Δ Ξ (Val.renameList (shiftIndex k c) vs) (as.map (Ty.shiftV k c)) := by
    match h with
    | .nil => exact .nil
    | .cons hv ht => exact .cons (HasTypeVQ.shift_values hv hA hstore hpres hm hf) (HasTypeVsQ.shift_values ht hA hstore hpres hm hf)
  termination_by structural h
  theorem HasTypeEachQ.shift_values {P B store Q C Γ Φ vs a}
      (h : HasTypeEachQ P B store Q C Γ Φ vs a) {k c Δ Ξ store'}
      (hA : Builtins.ValueAssumptions P B)
      (hstore : StoreTy.WF store)
      (hpres : StoreTy.PreservesNormals store store')
      (hm : ShiftMap k c Γ Δ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeEachQ P B store' Q C Δ Ξ (Val.renameList (shiftIndex k c) vs) (a.shiftV k c) := by
    match h with
    | .nil => exact .nil
    | .cons hv ht => exact .cons (HasTypeVQ.shift_values hv hA hstore hpres hm hf) (HasTypeEachQ.shift_values ht hA hstore hpres hm hf)
  termination_by structural h
  theorem HasTypeCQ.shift_values {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) {k c Δ Ξ store' L'}
      (hA : Builtins.ValueAssumptions P B)
      (hstore : StoreTy.WF store)
      (hext : StoreTy.Extends store store')
      (hm : FullShiftMap k c Γ Δ)
      (hL : LocalCtx.Shift k c L L')
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeCQ P B store' Q C Δ Ξ (R.map (Ty.shiftV k c)) (m.rename (shiftIndex k c))
        (a.shiftV k c) (Eff.shiftV k c e) L' := by
    match h with
    | .C_BuilderLet (kind := kind) ha hk hb hd =>
      simp only [Comp.rename, upRen_shiftIndex]
      refine .C_BuilderLet (by simpa only [BuilderKind.contents_rename] using hm.values.annotation ha)
        (by simpa only [BuilderKind.contents_rename, List.map_cons, List.map_nil] using hk.shift k c) ?_ (hm.values.declared hd)
      have hh := HasTypeCQ.shift_values (Ξ := Ξ.map Pred.lift) hb hA hstore hext hm.underNone (hL.extend (some kind))
        (fun p hp => by
          obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
          simpa only [Pred.shiftV_lift] using (hf q hq).under_none)
      simpa only [Ty.shiftV_comm, Eff.shiftV_comm, Option.map_map, Option.map_some, Function.comp_def] using hh
    | .C_BuilderOp ha hk hr hv =>
      simp only [Comp.rename]
      rw [← BuilderOp.resultType_rename]
      exact .C_BuilderOp (by simpa only [BuilderKind.contents_rename] using hm.values.annotation ha)
        (by simpa only [BuilderKind.contents_rename, List.map_cons, List.map_nil] using hk.shift k c)
        (hr.shift hstore hext hL)
        (by simpa only [BuilderOp.parameters_rename] using HasTypeVsQ.shift_values hv hA hstore hext.preservesNormals hm.values hf)
    | .C_Return hv => exact .C_Return (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf)
    | .C_App hv hs =>
      have hv' := HasTypeVQ.shift_values (store' := store') hv hA hstore hext.preservesNormals hm.values hf
      simp only [Ty.shiftV, shiftVTys_eq_map] at hv'
      exact .C_App hv' (HasTypeVsQ.shift_values hs hA hstore hext.preservesNormals hm.values hf)
    | .C_DependentApp hv ht =>
      exact .C_DependentApp (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf)
        (HasTypeTelArgsQ.shift_values ht hA hstore hext.preservesNormals hm.values hf)
    | .C_Normal hb =>
      simpa only [Ty.norm_shiftV] using (HasTypeCQ.shift_values hb hA hstore hext hm hL hf).C_Normal
    | .C_If (t := t) hv ht hm' hn =>
      refine .C_If (t := termBind (fun i => some (.var (shiftIndex k c i))) t) (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf)
        (by simp only [Val.toTerm_rename, ht, Option.map_some])
        ?_ ?_
      · exact HasTypeCQ.shift_values hm' hA hstore hext hm hL
          (by
            intro p hp
            rcases List.mem_cons.mp hp with rfl | hp
            · exact .hyp (List.mem_append_right _ List.mem_cons_self)
            · exact (hf p hp).weaken (by
                intro q hq
                rcases List.mem_append.mp hq with hq | hq
                · exact List.mem_append_left _ hq
                · exact List.mem_append_right _ (List.mem_cons_of_mem _ hq)))
      · exact HasTypeCQ.shift_values hn hA hstore hext hm hL
          (by
            intro p hp
            rcases List.mem_cons.mp hp with rfl | hp
            · exact .hyp (List.mem_append_right _ List.mem_cons_self)
            · exact (hf p hp).weaken (by
                intro q hq
                rcases List.mem_append.mp hq with hq | hq
                · exact List.mem_append_left _ hq
                · exact List.mem_append_right _ (List.mem_cons_of_mem _ hq)))
    | .C_Match (obs := obs) hv ho ha hx =>
      refine .C_Match (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf)
        ?_ (HasTypeArmsQ.shift_values ha hA hstore hext hm hL hf)
        (by rw [unguardedPats_rename]; exact hx.shift_values k c)
      intro t ht
      cases obs with
      | none => cases ht
      | some u =>
        cases ht
        obtain ⟨hu,s,hs⟩ := ho u rfl
        exact ⟨by simp only [Val.toTerm_rename,hu,Option.map_some],s,
          Term.hasSort_termBind hs _ hm.values.values hm.values.references⟩
    | .C_Lazy hb ha =>
      refine .C_Lazy ?_ (hm.values.annotation ha)
      exact HasTypeCQ.shift_values hb hA hstore.hide hext.preservesNormals.hide hm.hide (.empty _ _ _)
        (fun p hp => (hf p hp).hideConts)
    | .C_Escape hv ha =>
      exact .C_Escape
        (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf) (hm.values.annotation ha)
    | .C_Use hv hr hb he =>
      exact .C_Use
        (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf) hr
        (HasTypeCQ.shift_values hb hA hstore hext hm hL hf) (by cases e; exact he)
    | .C_Handle hb hc hh =>
      exact .C_Handle (HasTypeCQ.shift_values hb hA hstore hext hm hL hf)
        (by simpa only [Eff.shiftV_union,handled_shift_values,handled_rename] using hc.shiftV k c)
        (HasTypeClausesQ.shift_values hh hA hstore hext hm hL hf)
    | .C_Handle_Fail hb hc hn hh =>
      simp only [Comp.rename,Eff.shiftV_union]
      exact .C_Handle_Fail (HasTypeCQ.shift_values hb hA hstore hext hm hL hf)
        (by simpa only [Eff.shiftV_union,Eff.shiftV_singleFail] using hc.shiftV k c)
        (hn.shift_values k c) (HasFailureClause.shift_values hh hA hstore hext hm hL hf)
    | .C_Resume hi hv hd =>
      exact .C_Resume (hm.lookup _ _ hi)
        (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf) (hm.values.declared hd)
    | .C_ResumeNorm hi hv hd =>
      have hv' := HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf
      have hd' := hm.values.declared hd
      have hh := HasTypeCQ.C_ResumeNorm (R := R.map (Ty.shiftV k c)) (Δ := L') (hm.lookup _ _ hi)
        (by simpa only [← Ty.norm_shiftV] using hv')
        (by simpa only [← Ty.norm_shiftV] using hd')
      simpa only [Ty.norm_shiftV, Eff.norm_shiftV, Comp.rename, Val.rename] using hh
    | .C_ResumeLNorm (b := b) (t := t) (ε := ε) (R' := r) hl hr hv hd =>
      have hw := hstore _ _ hl
      have hb := Ty.shiftV_of_wf_zero hw.1 k c
      have ht := Ty.shiftV_of_wf_zero hw.2.1 k c
      have he := Eff.shiftV_of_wf_zero hw.2.2.1 k c
      have hbr : b.norm.shiftV k c = b.norm := by rw [← Ty.norm_shiftV, hb]
      have hR : r.map (Ty.shiftV k c) = r := by
        cases ho : r with
        | none => rfl
        | some a => exact congrArg some (Ty.shiftV_of_wf_zero (hw.2.2.2.2 a ho) k c)
      have comm (R : Option Ty) : (R.map Ty.norm).map (Ty.shiftV k c) =
          (R.map (Ty.shiftV k c)).map Ty.norm := by
        cases R <;> simp only [Option.map_none, Option.map_some, Ty.norm_shiftV]
      have hr' := congrArg (Option.map (Ty.shiftV k c)) hr
      rw [comm, comm, hR] at hr'
      have hv' := HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf
      simp only [Comp.rename, Val.rename, ←Ty.norm_shiftV, ←Eff.norm_shiftV, hb, ht, he] at hv' ⊢
      exact .C_ResumeLNorm (hext _ _ hl) hr' hv' (by simpa only [←Ty.norm_shiftV, ht] using hm.values.declared hd)
    | .C_ResumeL (b := b) (t := t) (ε := ε) (R := r) hl hv hd =>
      have hw := hstore _ _ hl
      have hb := Ty.shiftV_of_wf_zero hw.1 k c
      have ht := Ty.shiftV_of_wf_zero hw.2.1 k c
      have he := Eff.shiftV_of_wf_zero hw.2.2.1 k c
      have hr : r.map (Ty.shiftV k c) = r := by
        cases ho : r with
        | none => rfl
        | some x => simp only [Option.map_some]; exact congrArg some (Ty.shiftV_of_wf_zero (hw.2.2.2.2 x ho) k c)
      have hv' := HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf
      simp only [Comp.rename, Val.rename, hb, ht, he, hr] at hv' ⊢
      exact .C_ResumeL (hext _ _ hl) hv' (by simpa only [ht] using hm.values.declared hd)
    | .C_Meth hv hc hmeth hn hs hi hr hargs hvs ha =>
      simp only [Comp.rename, renameTy_shiftIndex, renameEff_shiftIndex]
      have hs' := hs.map (Ty.shiftV k c) (fun a hm' p hp => by
        have hat := hi.types a (List.mem_append_left _ hm')
        exact hA.sat_shiftV_norm hat (hm.values.annotation hat) hp)
      have hargs' := Tel.arguments_shift hargs k c
      rw [instantiatedTel_shift_eq hi.source] at hargs'
      simp only [List.map_append, List.map_cons, List.map_nil] at hargs'
      exact .C_Meth (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm.values hf) hc hmeth hn hs'
        (by simpa only [List.map_append, List.map_cons, List.map_nil] using hm.values.signature hi)
        (hm.values.methodRows hi.rows hr) hargs' (HasTypeVsQ.shift_values hvs hA hstore hext.preservesNormals hm.values hf)
        (hm.values.annotation ha)
    | .C_External (ts := ts) hd hw ha hargs =>
      have hh := HasTypeTelArgsQ.shift_values hargs hA hstore hext.preservesNormals hm.values hf
      have he := instantiatedTel_shift_eq hw.annotation.wf ts [] k c
      simp only [List.map_nil] at he
      change Tel.shiftV k c (Tel.bind (typeEnv _) _) = _ at he
      rw [he] at hh
      simpa only [Comp.rename, renameTy_shiftIndex] using HasTypeCQ.C_External hd hw (ha.map hw _) hh
    | .C_IssuePathBases b sg hb hk ho hp hr he =>
      exact .C_IssuePathBases b sg hb hk ho hp hr he
    | .C_CheckAt (bases := bases) hc =>
      have hh := AtCallAdmissible.shift_values hc hA hstore hext.preservesNormals hm.values hf
      cases bases <;> simpa only [Comp.rename, renameTy_shiftIndex, Ty.shiftV, shiftVTys,
        Eff.shiftV, Eff.empty] using
        (HasTypeCQ.C_CheckAt (R := R.map (Ty.shiftV k c)) (Δ := L')
          hh)
    | .C_Sub ht hl hc hw hs hd =>
      have hl' := hl.rawBind (renEnv (shiftIndex k c)) (hm.values.transport hf)
      change Ty.LeQ Δ Ξ (renameTy (shiftIndex k c) _) (renameTy (shiftIndex k c) _) at hl'
      rw [renameTy_shiftIndex] at hl'
      exact .C_Sub (HasTypeCQ.shift_values ht hA hstore hext hm hL hf) hl' (hc.shiftV k c) (hm.values.wf hw) (hm.values.sorted hs) (hm.values.declared hd)
    | .C_Eff ht hc => exact .C_Eff (HasTypeCQ.shift_values ht hA hstore hext hm hL hf) (hc.shiftV k c)
    | .C_Let (a := x) ht hb hd =>
      simp only [Comp.rename, upRen_shiftIndex]
      refine .C_Let (HasTypeCQ.shift_values ht hA hstore hext hm hL hf) ?_ (hm.values.declared hd)
      have hb' := HasTypeCQ.shift_values (store' := store') (L' := localExtend 1 L') hb hA hstore hext
        (hm.underParams [x]) (hL.extend none) (hm.values.conditions_params hf [x])
      simp only [List.length_cons, List.length_nil, Nat.zero_add, List.map_cons, List.map_nil,
        Ty.shiftV_comm, Eff.shiftV_comm, Option.map_map] at hb'
      have hr : (fun x => (x.shiftV 1 0).shiftV k (c+1)) =
          (fun x : Ty => (x.shiftV k c).shiftV 1 0) := funext (fun x => Ty.shiftV_comm x 1 k c)
      simpa only [bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil,
        List.nil_append, List.map_cons, List.map_nil, List.cons_append, List.nil_append,
        List.length_cons, List.length_nil, Nat.zero_add, liftMany_one,
        Option.map_map, Function.comp_def, hr] using hb'

  termination_by structural h
  theorem HasTypeArmsQ.shift_values {P B store Q C Γ Φ R obs arms a b e L}
      (h : HasTypeArmsQ P B store Q C Γ Φ R obs arms a b e L) {k c Δ Ξ store' L'}
      (hA : Builtins.ValueAssumptions P B) (hstore : StoreTy.WF store)
      (hext : StoreTy.Extends store store') (hm : FullShiftMap k c Γ Δ)
      (hL : LocalCtx.Shift k c L L')
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeArmsQ P B store' Q C Δ Ξ (R.map (Ty.shiftV k c))
        (obs.map (termBind (fun i => some (.var (shiftIndex k c i))))) (Arm.renameList (shiftIndex k c) arms) (a.shiftV k c) (b.shiftV k c) (e.shiftV k c) L' := by
    match h with
    | .nil ha => exact .nil (hm.values.annotation ha)
    | .plain (δ := δ) (alts := alts) hp hw hb hs =>
      have hw' := hw.rename_paths hm.values.values hm.values.references hm.values.declarationRenaming.images
      have hmF := Entails.extend_conditions hf (pathFacts_rename obs (matchedTests alts) (shiftIndex k c))
      have heF := Entails.extend_conditions hf (pathFacts_rename obs (excludedTests alts) (shiftIndex k c))
      refine .plain (hp.shift_values k c) hw' ?_ (HasTypeArmsQ.shift_values hs hA hstore hext hm hL heF)
      have hh := HasTypeCQ.shift_values hb hA hstore hext (hm.underParams δ)
        (hL.localExtend δ.length) (hm.values.conditions_params hmF δ)
      simpa only [List.length_map,Option.map_map,Function.comp_def,
        Ty.shiftV_comm,Eff.shiftV_comm,hp.2.1,upRen_shiftIndex,
          List.cons_append,List.nil_append,Pred.shiftV,shiftIndex] using hh
    | .guarded (δ := δ) (alts := alts) (p := p) hp hw hgp hg hb hs =>
      have hw' := hw.rename_paths hm.values.values hm.values.references hm.values.declarationRenaming.images
      have hmF := Entails.extend_conditions hf (pathFacts_rename obs (matchedTests alts) (shiftIndex k c))
      have hgAnn := (hm.underParams δ).hide.values.annotation hgp
      refine .guarded (hp.shift_values k c) hw' (by simpa only [Ty.shiftV,List.length_map] using hgAnn) ?_ ?_
        (HasTypeArmsQ.shift_values hs hA hstore hext hm hL hf)
      · have hh := HasTypeCQ.shift_values hg hA hstore hext (hm.underParams δ).hide
          (hL.localExtend δ.length) (fun p hp => ((hm.values.conditions_params hmF δ) p hp).hideConts)
        simpa only [List.length_map,Option.map_none,Ty.shiftV,Eff.shiftV,Eff.empty,shiftVTys,
          hp.2.1,upRen_shiftIndex] using hh
      · have hconds := hm.values.conditions_params hmF δ
        have hconds' := Entails.extend_conditions hconds
          (added := [p.open (.boolean true)])
          (added' := [(p.shiftV k (c+δ.length+1)).open (.boolean true)])
          (by
            simp only [List.map_cons,List.map_nil,List.cons.injEq,and_true]
            simpa only [Pred.shiftV,←upValues_shiftIndex,termBind_boolean] using
              predBind_open_renaming (shiftIndex k (c+δ.length)) p (.boolean true))
        have hh := HasTypeCQ.shift_values hb hA hstore hext (hm.underParams δ) (hL.localExtend δ.length) hconds'
        simpa only [List.length_map,Option.map_map,Function.comp_def,
          Ty.shiftV_comm,Eff.shiftV_comm,hp.2.1,upRen_shiftIndex,
          List.cons_append,List.nil_append,Pred.shiftV,shiftIndex] using hh
  termination_by structural h

  theorem HasTypeClausesQ.shift_values {P B store Q C Γ Φ R eb cs t e L}
      (h : HasTypeClausesQ P B store Q C Γ Φ R eb cs t e L) {k c Δ Ξ store' L'}
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hext : store.Extends store')
      (hm : FullShiftMap k c Γ Δ) (_hL : LocalCtx.Shift k c L L')
      (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (p.shiftV k c)) :
      HasTypeClausesQ P B store' Q C Δ Ξ (R.map (Ty.shiftV k c)) (eb.shiftV k c)
        (Clause.renameList (shiftIndex k c) cs) (t.shiftV k c) (e.shiftV k c) L' := by
    match h with
    | .nil => exact .nil
    | .cons (sg := sg) hc hnames hN hK hw hb hs =>
      refine .cons (hc.shift_values k c) hnames hN hK hw ?_
        (HasTypeClausesQ.shift_values hs hA hstore hext hm _hL hf)
      have hh := HasTypeCQ.shift_values (L' := []) hb hA hstore.hide hext.preservesNormals.hide
        (hm.clause sg hw t e) (.empty _ _ _) (hm.conditions_clause hf sg hw t e)
      simpa only [Option.map_map,Function.comp_def,Ty.shiftV_comm,Eff.shiftV_comm,
        ←shiftTypes_shiftV,←shiftRowsTypes_shiftV,hN,upRen_shiftIndex] using hh
  termination_by structural h

  theorem HasFailureClause.shift_values {P B store Q C Γ Φ E R cs t e L}
      (h : HasFailureClause P B store Q C Γ Φ E R cs t e L) {k c Δ Ξ store' L'}
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF) (hext : store.Extends store')
      (hm : FullShiftMap k c Γ Δ) (_hL : LocalCtx.Shift k c L L')
      (hf : ∀ p∈Φ,Entails (Δ.facts++Ξ) (p.shiftV k c)) :
      HasFailureClause P B store' Q C Δ Ξ (E.shiftV k c) (R.map (Ty.shiftV k c))
        (Clause.renameList (shiftIndex k c) cs) (t.shiftV k c) (e.shiftV k c) L' := by
    match h with
    | .one ha ht he hb =>
      simp only [Clause.renameList,renameTy_shiftIndex]
      refine .one (hm.values.annotation ha) (hm.values.annotation ht) (hm.values.rowAnnotations he) ?_
      have hh := HasTypeCQ.shift_values (L' := []) hb hA hstore.hide hext.preservesNormals.hide
        (hm.failure E) (.empty _ _ _) (hm.conditions_failure hf E)
      simpa only [Option.map_map,Function.comp_def,Ty.shiftV_comm,Eff.shiftV_comm,
        ←shiftTypes_shiftV,←shiftRowsTypes_shiftV,upRen_shiftIndex,renameTy_shiftIndex] using hh
  termination_by structural h

  theorem HasTypeTelArgsQ.shift_values {P B store Q C Γ Φ vs t a e}
      (h : HasTypeTelArgsQ P B store Q C Γ Φ vs t a e) {k c Δ Ξ store'}
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
      (hpres : StoreTy.PreservesNormals store store') (hm : ShiftMap k c Γ Δ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeTelArgsQ P B store' Q C Δ Ξ (Val.renameList (shiftIndex k c) vs)
        (Tel.shiftV k c t) (a.shiftV k c) (e.shiftV k c) := by
    match h with
    | .done ha => exact .done (hm.annotation ha)
    | .param ha hv ht =>
      apply HasTypeTelArgsQ.param (hm.annotation ha) (HasTypeVQ.shift_values hv hA hstore hpres hm hf)
      rw [Tel.open_shift]
      exact HasTypeTelArgsQ.shift_values ht hA hstore hpres hm hf

  termination_by structural h
  theorem TelBodyTy.shift_values {P B store Q C Γ Φ t body}
      (h : TelBodyTy P B store Q C Γ Φ t body) {k c Δ Ξ store'}
      (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
      (hext : store.Extends store') (hm : FullShiftMap k c Γ Δ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      TelBodyTy P B store' Q C Δ Ξ (Tel.shiftV k c t)
        (body.rename (upRen (telBinders t) (shiftIndex k c))) := by
    match h with
    | .done hb =>
      simpa only [Tel.shiftV, telBinders, upRen_shiftIndex, Nat.not_lt_zero, ↓reduceIte,
        Nat.sub_zero, Nat.add_zero, Option.map_some] using
        TelBodyTy.done (HasTypeCQ.shift_values hb hA hw hext hm (.empty _ _ _) hf)
    | .param (a := a) (rest := rest) hb =>
      have hh := TelBodyTy.shift_values hb hA hw hext (hm.underParams [a])
        (hm.values.conditions_params hf [a])
      apply TelBodyTy.param
      simpa only [bindParams_single, List.map_cons, List.map_nil, List.length_cons,
        List.length_nil, Nat.zero_add, liftMany_one, Tel.shiftV, telBinders,
        upRen_shiftIndex, Nat.add_assoc, Nat.add_comm 1] using hh
  termination_by structural h

  theorem CaptureOk.store {P B store R Γ Φ cap} (h : CaptureOk P B store R Γ Φ cap) {store'}
      (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.PreservesNormals store') :
      CaptureOk P B store' R Γ Φ cap := by
    match h with
    | .mk hg hn hs hr hf hc hi he =>
      refine .mk hg hn hs hr hf hc ?_ he
      exact fun i a hx => ImageOk.store (hi i a hx) hA hw hp
  termination_by structural h

  theorem ImageOk.store {P B store Q C Δ Ξ R ν i a}
      (h : ImageOk P B store Q C Δ Ξ R ν i a) {store'}
      (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.PreservesNormals store') :
      ImageOk P B store' Q C Δ Ξ R ν i a := by
    match h with
    | .ordinary ho hv =>
      refine .ordinary ho ?_
      have hh := HasTypeVQ.shift_values hv (k := 0) (c := 0) hA hw hp
        ⟨rfl, by intro i a h _; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using h⟩
        (Ξ := Ξ) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
      simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using hh
    | .hidden hn hc => exact .hidden hn hc
    | .contLoc ha hb hc hl ht hr => exact .contLoc ha hb hc hl (hp _ _ ht trivial) hr
    | .contVar ha hv ht => exact .contVar ha hv ht
  termination_by structural h

  theorem DependentClosureTy.store {P B store q t} (h : DependentClosureTy P B store q t) {store'}
      (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.PreservesNormals store') :
      DependentClosureTy P B store' q t := by
    match h with
    | .mk hc hb hs ha =>
      refine .mk (CaptureOk.store hc hA hw.hide hp.hide.preservesNormals) ?_ hs ha
      have hh := TelBodyTy.shift_values hb (k := 0) (c := 0) hA hw.hide hp.hide ⟨rfl, by intro i a h; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using h⟩ (Ξ := _)
        (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
      simpa only [Tel.shiftV_zero, shiftIndex_zero, upRen_identity, Comp.rename_identity] using hh
  termination_by structural h

  theorem CheckedWitness.shift_store {P B store o kind range snapshot target request}
      (h : CheckedWitness P B store o kind range snapshot target request) {store'}
      (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
      (hpres : store.PreservesNormals store') :
      CheckedWitness P B store' o kind range snapshot target request := by
    match h with
    | .plain hk hc ht hm => exact .plain hk hc ht hm
    | .request hk hc hv hg ht hm =>
      have hh := HasTypeVQ.shift_values (store' := store') hv hA hstore hpres retained_shift_empty
        (Ξ := []) (by simp)
      simp only [retained_shiftIndex_zero, Val.rename_identity, retained_shift_zero] at hh
      exact .request hk hc hh hg ht hm

  termination_by structural h
  theorem AtCallAdmissible.shift_values {P B store Q C Γ Φ kind name shape bases pattern input index}
      (h : AtCallAdmissible P B store Q C Γ Φ kind name shape bases pattern input index)
      {k c Δ Ξ store'} (hA : Builtins.ValueAssumptions P B) (hstore : store.WF)
      (hpres : store.PreservesNormals store') (hm : ShiftMap k c Γ Δ)
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      AtCallAdmissible P B store' Q C Δ Ξ kind name
        {shape with errorType := shape.errorType.shiftV k c}
        (match bases with | none => none | some b => some (b.rename (shiftIndex k c)))
        (pattern.rename (shiftIndex k c)) (input.rename (shiftIndex k c)) index := by
    match h with
    | .mk (inputTy := inputTy) hs hk hb hp ht hv hw hi =>
      have hb' := fun b (he : bases = some b) =>
        HasTypeVQ.shift_values (hb b he) hA hstore hpres hm hf
      have he : {shape with errorType := shape.errorType.shiftV k c} = shape := by
        have hx : shape.errorType.shiftV k c = shape.errorType := by
          rw [hs.errorType_eq]; rfl
        simp only [hx]
      rw [he]
      refine AtCallAdmissible.mk (inputTy := inputTy) hs hk ?_ (HasTypeVQ.shift_values hp hA hstore hpres hm hf) ht ?_ hw hi
      · intro v he
        cases bases with
        | none => cases he
        | some b =>
          cases he
          exact hb' b rfl
      · have hh := HasTypeVQ.shift_values hv hA hstore hpres hm hf
        rcases ht with ⟨rfl, ht⟩ | ht
        · exact hh
        · simpa only [← Ty.norm_shiftV, Ty.shiftV_of_wf_zero ht.2] using hh

  termination_by structural h
end

theorem ClosureTy.store {P B store ps R q a e} (h : ClosureTy P B store ps R q a e) {store'}
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF) (hp : store.Extends store') :
    ClosureTy P B store' ps R q a e := by
  cases h with
  | mk hc hb hl heq hss hps hR ha he hsd hrd =>
    refine .mk (CaptureOk.store hc hA hw hp.preservesNormals) ?_
      (fun i kind hi => by obtain ⟨l,hr,ht⟩ := hl i kind hi; exact ⟨l,hr,hp l _ ht⟩)
      heq hss hps hR ha he hsd hrd
    have hh := HasTypeCQ.shift_values hb (k := 0) (c := 0) hA hw hp
      ⟨rfl,by intro i a hi; simpa only [shiftIndex_zero,id_eq,Ty.shiftV_zero] using hi⟩
      (LocalCtx.Shift.refl _) (Ξ := _) (fun p hp => by rw [Pred.shiftV_zero]; exact .hyp (List.mem_append_right _ hp))
    simpa only [Ty.shiftV_zero,Eff.shiftV_zero,shiftIndex_zero,Comp.rename_identity,
      show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0),Option.map_id,id_eq] using hh


/-- 既存の導出の条件を、それらを導ける条件の列へ置き換える。 -/
theorem HasTypeVQ.weaken_conditions {P B store Q C Γ Φ v a Ξ}
    (h : HasTypeVQ P B store Q C Γ Φ v a)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (hf : ∀ p ∈ Φ, Entails (Γ.facts ++ Ξ) p) :
    HasTypeVQ P B store Q C Γ Ξ v a := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw (StoreTy.PreservesNormals.refl _)
    ⟨rfl, by intro i a hi _; simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hi⟩
    (Ξ := Ξ) (fun p hp => by rw [Pred.shiftV_zero]; exact hf p hp)
  simpa only [shiftIndex_zero, Val.rename_identity, Ty.shiftV_zero] using hh

theorem HasTypeCQ.weaken_conditions {P B store Q C Γ Φ R m a e L Ξ}
    (h : HasTypeCQ P B store Q C Γ Φ R m a e L)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (hf : ∀ p ∈ Φ, Entails (Γ.facts ++ Ξ) p) :
    HasTypeCQ P B store Q C Γ Ξ R m a e L := by
  have hh := h.shift_values (k := 0) (c := 0) hA hw (StoreTy.Extends.refl _)
    ⟨rfl, by intro i a hi; simpa only [shiftIndex_zero, id_eq, Ty.shiftV_zero] using hi⟩
    (LocalCtx.Shift.refl _) (Ξ := Ξ) (fun p hp => by rw [Pred.shiftV_zero]; exact hf p hp)
  simpa only [shiftIndex_zero, Comp.rename_identity, Ty.shiftV_zero, Eff.shiftV_zero,
    show Ty.shiftV 0 0 = id from funext (fun t => t.shiftV_zero 0), Option.map_id, id_eq] using hh

theorem ImageOk.weaken_conditions {P B store Q C Γ Φ R ν i a Ξ}
    (h : ImageOk P B store Q C Γ Φ R ν i a)
    (hA : Builtins.ValueAssumptions P B) (hw : store.WF)
    (hf : ∀ p ∈ Φ, Entails (Γ.facts ++ Ξ) p) :
    ImageOk P B store Q C Γ Ξ R ν i a := by
  cases h with
  | ordinary ho hv => exact .ordinary ho (hv.weaken_conditions hA hw hf)
  | hidden ho hc => exact .hidden ho hc
  | contLoc ha hb hc hd he hr => exact .contLoc ha hb hc hd he hr
  | contVar ha hb hc => exact .contVar ha hb hc

end Benitoite.Release.Refinement
