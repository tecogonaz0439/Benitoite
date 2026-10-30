import Benitoite.Release.Refinement.ConstraintAssumptions
import Benitoite.Release.Refinement.LocalTransport
import Benitoite.Release.Refinement.MethodArguments

/-!
# 型付きの値を束縛の下へ移す

改名は順序を保つ shiftIndex に限る。捕捉境界では継続の変数を隠す。
-/
namespace Benitoite.Release.Refinement

theorem Ty.IntegerCarrier.ordinary {a : Ty} (h : a.IntegerCarrier) : a.Ordinary := Ty.HasSort.ordinary h

theorem Ty.assume_ordinary {a : Ty} {p : Pred} (hp : p ∈ a.assume) : a.Ordinary := by
  cases a <;> simp_all [Ty.assume, Ty.Ordinary]

theorem Ty.NotContCore.ordinary {a : Ty} (h : a.NotContCore) : a.Ordinary := by
  cases a <;> simp_all [Ty.Ordinary, Ty.NotContCore, Ty.core]

theorem Ty.notContCore_of_wf_ordinary {nr nt nv a} (hw : Ty.WF nr nt nv a)
    (ho : a.Ordinary) : a.NotContCore := by
  cases a <;> simp_all [Ty.Ordinary, Ty.NotContCore, Ty.core]
  case refined a p => exact hw.2.2

theorem Ty.LeQ.notContCore {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) : a.NotContCore ↔ b.NotContCore := by
  match h with
  | .refl => rfl
  | .trans h₁ h₂ => exact h₁.notContCore.trans h₂.notContCore
  | .fn_effect _ | .list _ | .lazy _ | .map_value _ _ | .dependentFn _ | .scoped _ | .scoped_forget => simp [Ty.NotContCore, Ty.core]
  | .forget | .introduce _ _ => rfl
  | .refine hv _ _ _ => exact hv.notContCore

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
      cases t <;> simp [Ty.Ordinary] <;> rintro rfl <;> simp

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
  change Ty.Annotation P C Δ (((Ty.dependentFn t).subst ts es).shiftV k c) at hh
  rw [Ty.subst_shiftV_closed_rows ht.source] at hh
  exact hh

theorem ShiftMap.admissible {P B C k c Γ Δ tps ne Qs Qt ts es e}
    (h : ShiftMap k c Γ Δ) (hA : Builtins.ValueAssumptions P B)
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : Admissible B C Γ.length tps ne Qs Qt ts es e) :
    Admissible B C Δ.length tps ne Qs Qt (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) e := by
  apply ha.map (Ty.shiftV k c) (Eff.shiftV k c)
  · apply ha.types.map
    intro a ha p hp
    simpa only [renameTy_shiftIndex] using hA.sat_rename C Γ Δ a p (shiftIndex k c)
      (shiftIndex_strict k c) (ht a ha) (by simpa only [renameTy_shiftIndex] using h.annotation (ht a ha)) hp
  · intro a hm; exact ⟨h.wf (ht a hm).wf, (Ty.ordinary_shiftV _ _ _).mpr (ha.typeScope a hm).2⟩
  · intro e he'; exact (h.annotation (he e he')).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hn => hn.shift_values k c) (fun _ => rfl)

theorem ShiftMap.primitive {P B C k c Γ Δ b sg Q ts es}
    (h : ShiftMap k c Γ Δ) (hA : Builtins.ValueAssumptions P B) (hb : B.sig b = some sg)
    (ht : TypeAnnotations P C Γ ts) (he : RowAnnotations P C Γ es)
    (ha : PrimitiveAdmissible C Γ.length sg Q ts es) :
    PrimitiveAdmissible C Δ.length sg Q (ts.map (Ty.shiftV k c)) (es.map (Eff.shiftV k c)) := by
  apply ha.map (Ty.shiftV k c) (Eff.shiftV k c)
  · simpa only [renameTy_shiftIndex] using hA.admits_rename b sg C Γ Δ ts (shiftIndex k c) hb
      (shiftIndex_strict k c) ht (by simpa only [renameTy_shiftIndex] using h.typeAnnotations ht) ha.admits
  · intro a hm; exact ⟨h.wf (ht a hm).wf, (Ty.ordinary_shiftV _ _ _).mpr (ha.typeScope a hm).2⟩
  · intro e hm; exact (h.annotation (he e hm)).wf.2.2.2.1
  · exact ha.noFailRows.map _ (fun _ hn => hn.shift_values k c) (fun _ => rfl)

theorem ShiftMap.methodRows {P C k c Γ Δ Q ms es} (h : ShiftMap k c Γ Δ)
    (he : RowAnnotations P C Γ es) (ha : MethodRowsAdmissible C Γ.length Q ms es) :
    MethodRowsAdmissible C Δ.length Q ms (es.map (Eff.shiftV k c)) :=
  ha.map _ (fun e hm => (h.annotation (he e hm)).wf.2.2.2.1)
    (ha.2.2.2.2.map _ (fun _ hn => hn.shift_values k c) (fun _ => rfl))

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
          (hm.hide.underParams ps) (.empty _ _ _)
          (hm.hide.conditions_params (fun p hp => (hf p hp).hideConts) ps)
        simpa only [List.length_map, Ty.shiftV_comm, Eff.shiftV_comm, Option.map_some] using hb'
      · simpa only [Ty.shiftV, shiftVTys_eq_map] using hm.declared hd
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
        simpa only [renameTy_shiftIndex] using hA.sat_rename C Γ Δ a p (shiftIndex k c)
          (shiftIndex_strict k c) (hi.types a ha) (by simpa only [renameTy_shiftIndex] using hm.annotation (hi.types a ha)) hp)
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
    | .V_Map hk hv hn hs ha hb =>
      exact .V_Map (HasTypeEachQ.shift_values hk hA hstore hpres hm hf)
        (HasTypeEachQ.shift_values hv hA hstore hpres hm hf) (by simpa using hn)
        (by simpa only [renameTy_shiftIndex] using (hA.sat_rename C Γ Δ _ _ (shiftIndex k c) (shiftIndex_strict k c) ha (by simpa only [renameTy_shiftIndex] using hm.annotation ha) hs))
        (hm.annotation ha) (hm.annotation hb)
    | .V_Set hv hs ha =>
      exact .V_Set (HasTypeEachQ.shift_values hv hA hstore hpres hm hf)
        (by simpa only [renameTy_shiftIndex] using (hA.sat_rename C Γ Δ _ _ (shiftIndex k c) (shiftIndex_strict k c) ha (by simpa only [renameTy_shiftIndex] using hm.annotation ha) hs)) (hm.annotation ha)
    | .V_Dict (id := id) (ts := ts) hi hs ht hk hw htarget hv ha =>
      have hv' := HasTypeVsQ.shift_values hv hA hstore hpres hm hf
      have he : (id.dictTys.map (Ty.subst ts [])).map (Ty.shiftV k c) =
          id.dictTys.map (Ty.subst (ts.map (Ty.shiftV k c)) []) := by
        rw [List.map_map]; exact List.map_congr_left (fun a ha => Ty.subst_shiftV_closed (hw a ha) ts k c)
      rw [he] at hv'
      have hs' := hs.map (Ty.shiftV k c) (fun a hm' p hp => by
        simpa only [renameTy_shiftIndex] using hA.sat_rename C Γ Δ a p (shiftIndex k c)
          (shiftIndex_strict k c) (ht a hm') (by simpa only [renameTy_shiftIndex] using hm.annotation (ht a hm')) hp)
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
  theorem HasTypeCQ.shift_values {P B store Q C Γ Φ R m a e L}
      (h : HasTypeCQ P B store Q C Γ Φ R m a e L) {k c Δ Ξ store' L'}
      (hA : Builtins.ValueAssumptions P B)
      (hstore : StoreTy.WF store)
      (hext : StoreTy.Extends store store')
      (hm : ShiftMap k c Γ Δ)
      (hL : LocalCtx.Shift k c L L')
      (hf : ∀ p ∈ Φ, Entails (Δ.facts ++ Ξ) (p.shiftV k c)) :
      HasTypeCQ P B store' Q C Δ Ξ (R.map (Ty.shiftV k c)) (m.rename (shiftIndex k c))
        (a.shiftV k c) (Eff.shiftV k c e) L' := by
    match h with
    | .C_BuilderLet (kind := kind) ha hk hb hd =>
      simp only [Comp.rename, upRen_shiftIndex]
      refine .C_BuilderLet (by simpa only [BuilderKind.contents_rename] using hm.annotation ha)
        (by simpa only [BuilderKind.contents_rename, List.map_cons, List.map_nil] using hk.shift k c) ?_ (hm.declared hd)
      have hh := HasTypeCQ.shift_values (Ξ := Ξ.map Pred.lift) hb hA hstore hext hm.underNone (hL.extend (some kind))
        (fun p hp => by
          obtain ⟨q, hq, rfl⟩ := List.mem_map.mp hp
          simpa only [Pred.shiftV_lift] using (hf q hq).under_none)
      simpa only [Ty.shiftV_comm, Eff.shiftV_comm, Option.map_map, Option.map_some, Function.comp_def] using hh
    | .C_BuilderOp ha hk hr hv =>
      simp only [Comp.rename]
      rw [← BuilderOp.resultType_rename]
      exact .C_BuilderOp (by simpa only [BuilderKind.contents_rename] using hm.annotation ha)
        (by simpa only [BuilderKind.contents_rename, List.map_cons, List.map_nil] using hk.shift k c)
        (hr.shift hstore hext hL)
        (by simpa only [BuilderOp.parameters_rename] using HasTypeVsQ.shift_values hv hA hstore hext.preservesNormals hm hf)
    | .C_Return hv => exact .C_Return (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm hf)
    | .C_App hv hs =>
      have hv' := HasTypeVQ.shift_values (store' := store') hv hA hstore hext.preservesNormals hm hf
      simp only [Ty.shiftV, shiftVTys_eq_map] at hv'
      exact .C_App hv' (HasTypeVsQ.shift_values hs hA hstore hext.preservesNormals hm hf)
    | .C_If hv hm' hn =>
      exact .C_If (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm hf)
        (HasTypeCQ.shift_values hm' hA hstore hext hm hL hf) (HasTypeCQ.shift_values hn hA hstore hext hm hL hf)
    | .C_Lazy hb ha =>
      refine .C_Lazy ?_ (hm.annotation ha)
      exact HasTypeCQ.shift_values hb hA hstore.hide hext.preservesNormals.hide hm.hide (.empty _ _ _)
        (fun p hp => (hf p hp).hideConts)
    | .C_Escape hv ha =>
      exact .C_Escape
        (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm hf) (hm.annotation ha)
    | .C_Use hv hr hb he =>
      exact .C_Use
        (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm hf) hr
        (HasTypeCQ.shift_values hb hA hstore hext hm hL hf) (by cases e; exact he)
    | .C_Meth hv hc hmeth hn hs hi hr hargs hvs ha =>
      simp only [Comp.rename, renameTy_shiftIndex, renameEff_shiftIndex]
      have hs' := hs.map (Ty.shiftV k c) (fun a hm' p hp => by
        have hat := hi.types a (List.mem_append_left _ hm')
        simpa only [renameTy_shiftIndex] using hA.sat_rename C Γ Δ a p (shiftIndex k c)
          (shiftIndex_strict k c) hat (by simpa only [renameTy_shiftIndex] using hm.annotation hat) hp)
      have hargs' := Tel.arguments_shift hargs k c
      rw [instantiatedTel_shift_eq hi.source] at hargs'
      simp only [List.map_append, List.map_cons, List.map_nil] at hargs'
      exact .C_Meth (HasTypeVQ.shift_values hv hA hstore hext.preservesNormals hm hf) hc hmeth hn hs'
        (by simpa only [List.map_append, List.map_cons, List.map_nil] using hm.signature hi)
        (hm.methodRows hi.rows hr) hargs' (HasTypeVsQ.shift_values hvs hA hstore hext.preservesNormals hm hf)
        (hm.annotation ha)
    | .C_External (ts := ts) hd hw ha hargs =>
      have hh := HasTypeTelArgsQ.shift_values hargs hA hstore hext.preservesNormals hm hf
      have he := instantiatedTel_shift_eq hw.annotation.wf ts [] k c
      simp only [List.map_nil] at he
      change Tel.shiftV k c (Tel.bind (typeEnv _) _) = _ at he
      rw [he] at hh
      simpa only [Comp.rename, renameTy_shiftIndex] using HasTypeCQ.C_External hd hw (ha.map hw _) hh
    | .C_Sub ht hl hc hw hs hd =>
      have hl' := hl.rawBind (renEnv (shiftIndex k c)) (hm.transport hf)
      change Ty.LeQ Δ Ξ (renameTy (shiftIndex k c) _) (renameTy (shiftIndex k c) _) at hl'
      rw [renameTy_shiftIndex] at hl'
      exact .C_Sub (HasTypeCQ.shift_values ht hA hstore hext hm hL hf) hl' (hc.shiftV k c) (hm.wf hw) (hm.sorted hs) (hm.declared hd)
    | .C_Eff ht hc => exact .C_Eff (HasTypeCQ.shift_values ht hA hstore hext hm hL hf) (hc.shiftV k c)
    | .C_Let (a := x) ht hb hd =>
      simp only [Comp.rename, upRen_shiftIndex]
      refine .C_Let (HasTypeCQ.shift_values ht hA hstore hext hm hL hf) ?_ (hm.declared hd)
      have hb' := HasTypeCQ.shift_values (store' := store') (L' := localExtend 1 L') hb hA hstore hext
        (hm.underParams [x]) (hL.extend none) (hm.conditions_params hf [x])
      simp only [List.length_cons, List.length_nil, Nat.zero_add, List.map_cons, List.map_nil,
        Ty.shiftV_comm, Eff.shiftV_comm, Option.map_map] at hb'
      have hr : (fun x => (x.shiftV 1 0).shiftV k (c+1)) =
          (fun x : Ty => (x.shiftV k c).shiftV 1 0) := funext (fun x => Ty.shiftV_comm x 1 k c)
      simpa only [bindParams, Ctx.extend, List.reverse_cons, List.reverse_nil,
        List.nil_append, List.map_cons, List.map_nil, List.cons_append, List.nil_append,
        List.length_cons, List.length_nil, Nat.zero_add, liftMany_one,
        Option.map_map, Function.comp_def, hr] using hb'

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

end

end Benitoite.Release.Refinement
