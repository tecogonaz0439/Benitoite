import Benitoite
/-! G03/G04 の入力として基盤が足りるかの試行。Ordinary を与えた場合の正例。 -/
open Benitoite.Release.Refinement
namespace RvT2
abbrev TParam := Benitoite.Release.TParam

/-- 文脈の型の一括置換。Ctx.WF が同じ値深さで移る。 -/
theorem ctx_wf_bindTypes {nr nt mr mt : Nat} {Γ : Ctx} {θ : SubstEnv} (h : Ctx.WF nr nt Γ)
    (hi : θ.WFImages nr nt Γ.length mr mt Γ.length) : Ctx.WF mr mt (Γ.bindTypes θ) := by
  intro i a ha
  have hlen : (Γ.bindTypes θ).length = Γ.length := by simp [Ctx.bindTypes]
  rw [hlen]
  simp only [Ctx.bindTypes, List.getElem?_map, Option.map_eq_some_iff] at ha
  obtain ⟨o, ho, hoa⟩ := ha
  obtain ⟨b, rfl, rfl⟩ := hoa
  exact Ty.bind_wf b (h i b ho) hi

theorem apply_formed {P : Program} {C : List TParam} {Δ : Ctx} {K : KindCtx} {f : Ty} {bs : List Ty} {n : Nat}
    (hk : f.HasKind P K (.constructor n)) (hl : bs.length = n)
    (hs : sortedTys Δ bs) (hd : declaredTys P C Δ bs) :
    (rawApply f bs).Sorted Δ ∧ Ty.Declared P C Δ (rawApply f bs) := by
  have hp := rawApply_proper hk hl
  rcases hk.constructor_shape with ⟨c, rfl, hc⟩ | ⟨j, rfl, _⟩
  · generalize hr : rawApply (.ctor c) bs = r at hp ⊢
    cases hp with
    | list a | set a | reference a | lazy a => exact ⟨hs.1, hd.1⟩
    | map a b => exact ⟨⟨hs.1, hs.2.1⟩, ⟨hd.1, hd.2.1⟩⟩
    | data d bs =>
      refine ⟨hs, ⟨?_, hd⟩⟩
      by_cases h : ∃ m, P.DataArity d m
      · obtain ⟨m, hm⟩ := h
        rw [TyCon.arity_data hm] at hc
        cases hc
        exact ⟨_, hm, hl⟩
      · simp [TyCon.arity, h] at hc
  · exact ⟨hs, hd⟩

/-- 型構成子の像を持つ tapp の Annotation の一場合。WF は基盤から、Sorted/Declared は kind と args から。 -/
theorem tapp_annotation_case {P : Program} {C : List TParam} {Δ : Ctx} {K : KindCtx} {θ : SubstEnv}
    {nt nv : Nat} {i n : Nat} {as : List Ty}
    (hw : (Ty.tapp i as).WF 0 nt nv) (hi : θ.WFImages 0 nt nv 0 C.length Δ.length)
    (hk : (θ.types i).HasKind P K (.constructor n)) (hn : as.length = n)
    (hs : sortedTys Δ (Ty.normTys (rawBindTys θ as)))
    (hd : declaredTys P C Δ (Ty.normTys (rawBindTys θ as))) :
    Ty.Annotation P C Δ ((Ty.tapp i as).bind θ) := by
  have hl : (Ty.normTys (rawBindTys θ as)).length = n := by
    simp only [Ty.normTys_eq_map, rawBindTys_eq_map, List.length_map]; exact hn
  have hb : (Ty.tapp i as).bind θ = (rawApply (θ.types i) (Ty.normTys (rawBindTys θ as))).norm := by
    simp only [Ty.bind, Ty.rawBind, rawApply_norm_args]
  obtain ⟨hsr, hdr⟩ := apply_formed hk hl hs hd
  refine ⟨?_, ?_, ?_⟩
  · exact Ty.bind_wf _ hw hi
  · rw [hb]; exact Ty.sorted_norm hsr
  · rw [hb]; exact hdr.norm

/-- Admissible の入力から、呼出しの Tel の WF を得る（値深さの弱化を含む）。 -/
theorem admissible_instantiated_wf {B C nv tps ne Qs Qt ts es e} {t : Tel}
    (h : Admissible B C nv tps ne Qs Qt ts es e)
    (src : (Ty.dependentFn t).WF 0 ts.length 0) :
    (Ty.dependentFn (instantiatedTel t ts es)).WF 0 C.length nv := by
  have hi := typeEnvAt_wfImages (nr := 0) (n := C.length) (nv := nv) 0 ts es
    (fun a ha => (h.typeScope a ha).1) (fun f hf => h.rowScope f hf) (fun a ha => (h.typeScope a ha).2)
  have hs : Tel.WF 0 (0+ts.length) nv t := Tel.WF.weaken src (by omega) (by omega)
  exact Tel.rawBind_norm_wf t hs hi

/-- 項の型置換が値束縛で行う ts のずらしと、WFImages.up が同じ置換である。 -/
theorem typeEnvAt_up_agrees (c : Nat) (ts : List Ty) (es : List Eff) :
    SubstEnv.AgreesBelow (c+ts.length) (typeEnvAt c ts es).up
      (typeEnvAt c (ts.map (Ty.shiftV 1 0)) (es.map (Eff.shiftV 1 0))) := by
  constructor
  · intro i hi
    simp only [SubstEnv.up_types, typeEnvAt, List.length_map]
    split
    · rfl
    · have hl : i-c < ts.length := by omega
      simp only [hl, ↓reduceIte, List.getElem?_eq_getElem hl, Option.getD_some, List.getElem?_map,
        Option.map_some, shiftTypes_shiftV]
  · simp only [SubstEnv.up_rows, typeEnvAt, List.map_map]
    apply List.map_congr_left
    intro e _
    simp only [Function.comp, shiftRowsTypes_shiftV]
  · rfl
  · funext i
    cases i with
    | zero => rfl
    | succ i => simp [SubstEnv.up_values, typeEnvAt, upValues]

/-- 閉じた型は置換で正規化だけを受ける。旧 substAt_nil_of_wf の新しい形。 -/
theorem substAt_of_closed (nr nv : Nat) (ts : List Ty) (a : Ty) (h : a.WF nr 0 nv) :
    a.substAt 0 ts [] = a.norm := by
  have hag : SubstEnv.AgreesBelow 0 (typeEnvAt 0 ts []) (renEnv id) :=
    ⟨fun i hi => by omega, rfl, rfl, rfl⟩
  change (a.rawBind (typeEnvAt 0 ts [])).norm = a.norm
  rw [Ty.rawBind_agrees h hag, Ty.rawBind_id]

/-- G04: 捕捉の値が閉じていれば、非継続の束縛の型は closeTy の後に閉じて WF である。 -/
theorem close_wf {a : Ty} {n : Nat} {ν : Nat → Val} (ha : a.WF 0 0 n)
    (hv : ∀ i, i < n → ∀ t, (ν i).toTerm? = some t → termWF 0 t) :
    (substTyValues ν a).WF 0 0 0 := by
  have hi : (valEnv ν).WFImages 0 0 n 0 0 0 := by
    constructor
    · intro i h; omega
    · intro e he; cases he
    · intro ix hix; simpa only [valEnv, RangeIx.inst_nil] using hix
    · exact hv
    · intro i; simp [valEnv, Ordinary, Ty.core]
  exact Ty.bind_wf a ha hi

mutual
  theorem ground_term {nt : Nat} {v : Val} {t : Term} (h : v.ClosedAt nt 0) (ht : v.toTerm? = some t) :
      termWF 0 t := by
    cases v with
    | var i => exact absurd h (Nat.not_lt_zero _)
    | const k => cases k <;> simp only [Val.toTerm?, Option.some.injEq, reduceCtorEq] at ht <;> first | (subst ht; trivial) | skip
    | con c ts vs =>
      simp only [Val.toTerm?, Option.some.injEq] at ht; subst ht; exact ground_slots h.2
    | list vs =>
      simp only [Val.toTerm?, Option.some.injEq] at ht; subst ht; exact ground_slots h
    | setV vs =>
      simp only [Val.toTerm?, Option.some.injEq] at ht; subst ht; exact ground_slots h
    | mapV ks vs =>
      simp only [Val.toTerm?, Option.some.injEq] at ht; subst ht; exact ⟨ground_slots h.1, ground_slots h.2⟩
    | _ =>
      simp only [Val.toTerm?, Option.some.injEq, reduceCtorEq] at ht
      try (subst ht; exact trivial)
      try (subst ht
           show varsInSlots (fun i => i < 0) (List.map (fun s => some (Term.string s)) _)
           generalize AtError.textFields _ = xs
           induction xs with
           | nil => trivial
           | cons x xs ih => exact ⟨trivial, ih⟩)
  theorem ground_slots {nt : Nat} {vs : List Val} (h : Val.ClosedList nt 0 vs) :
      varsInSlots (fun i => i < 0) (Val.toTermSlots vs) := by
    cases vs with
    | nil => trivial
    | cons v vs =>
      refine ⟨?_, ground_slots h.2⟩
      cases ht : v.toTerm? with
      | none => simp only [varsInSlot]
      | some t => exact ground_term h.1 ht
end

/-- 捕捉の値が Ground なら close_wf の仮定は満たされる。 -/
theorem close_wf_ground {a : Ty} {n : Nat} {ν : Nat → Val} (ha : a.WF 0 0 n)
    (hg : ∀ i, (ν i).Ground) : (substTyValues ν a).WF 0 0 0 :=
  close_wf ha (fun i _ _ ht => ground_term (hg i) ht)

end RvT2
