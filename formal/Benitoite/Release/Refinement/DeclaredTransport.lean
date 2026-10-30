import Benitoite.Release.Refinement.Declared

namespace Benitoite.Release.Refinement

noncomputable def bindDataArgs (ν : ObservationEnv) (ts : List Ty) : List Ty := ts.map (Ty.substV ν)

@[simp] theorem bindDataArgs_length (ν : ObservationEnv) (ts : List Ty) :
    (bindDataArgs ν ts).length = ts.length := List.length_map _

theorem bindDataArgs_eq_norm (ν : ObservationEnv) (ts : List Ty) :
    bindDataArgs ν ts = Ty.normTys (substVTys ν ts) := by
  simp only [bindDataArgs, substVTys_eq_map, Ty.normTys_eq_map, List.map_map]
  apply List.map_congr_left
  intro a _
  simp only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind, Function.comp_def]

theorem Ty.norm_rawSubstV (a : Ty) (ν : ObservationEnv) :
    (a.norm.rawSubstV ν).norm = (a.rawSubstV ν).norm := by
  simp only [Ty.rawSubstV_eq_rawBind, Ty.norm_rawBind]

@[simp] theorem Ty.core_norm (a : Ty) : a.norm.core = a.core.norm := by
  cases a <;> simp only [Ty.norm, Ty.core, Ty.core_norm]

@[simp] theorem Ty.core_rawSubstV (a : Ty) (ν : ObservationEnv) :
    (a.rawSubstV ν).core = a.core.rawSubstV ν := by
  cases a <;> simp only [Ty.rawSubstV, Ty.core, Ty.core_rawSubstV]

theorem Ty.dataCore_substV {a : Ty} {d ts} (h : a.norm.core = .data d ts) (ν : ObservationEnv) :
    (a.rawSubstV ν).norm.core = .data d (bindDataArgs ν ts) := by
  have hh := congrArg (fun t => (t.rawSubstV ν).norm) h
  simp only [Ty.core_norm, Ty.norm_rawSubstV] at hh
  rw [Ty.core_norm, Ty.core_rawSubstV, hh]
  simp only [Ty.rawSubstV, Ty.norm, bindDataArgs_eq_norm]

theorem Ty.substV_of_wf_zero {nr nt a} (h : Ty.WF nr nt 0 a) (ν : ObservationEnv) : a.substV ν = a := by
  simp only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind,
    Ty.rawSubstV_of_wf_zero h ν]
  exact Ty.canonical_of_wf h

theorem Ty.substV_subst_closed {nt a} (h : Ty.WF 0 nt 0 a) (ts : List Ty) (ν : ObservationEnv) :
    (a.subst ts []).substV ν = a.subst (bindDataArgs ν ts) [] := by
  rw [bindDataArgs_eq_norm, Ty.subst_norm_images]
  simp only [Ty.subst, Ty.substAt_substV, Ty.substV_of_wf_zero h ν,
    List.map_nil, substVTys_eq_map]

@[simp] theorem bindSlots_length (ν : ObservationEnv) (xs : List (Option Term)) :
    (bindSlots ν xs).length = xs.length := by
  induction xs <;> simp_all [bindSlots]

/-- 宣言照合に必要な名目の情報。sort の保存とは別に型付きの像から導く。 -/
def DataImages (P : Program) (Γ Δ : Ctx) (ν : ObservationEnv) : Prop :=
  ∀ i a d ts, Γ[i]? = some (some a) → a.norm.core = .data d ts →
    Term.HasData P Δ (termBind ν (.var i)) d (bindDataArgs ν ts)

theorem Term.HasData.bind {P Γ Δ ν t d ts} (h : Term.HasData P Γ t d ts)
    (hm : DataImages P Γ Δ ν) :
    Term.HasData P Δ (termBind ν t) d (bindDataArgs ν ts) := by
  match h with
  | .var hi hd => exact hm _ _ _ _ hi hd
  | .value hc hd hn hl =>
    simp only [termBind_dataValue]
    exact .value hc hd (by simpa only [bindDataArgs_length] using hn)
      (by simpa only [bindSlots_length] using hl)
  | .field hr hc hd hn ha hw hs hv =>
    simp only [termBind_field]
    apply Term.HasData.field (hr.bind hm) hc hd (by simpa only [bindDataArgs_length] using hn) ha hw
    · rw [← Ty.substV_subst_closed hw]
      exact Ty.hasSort_bind hs (SubstEnv.valuesOnly ν)
    · rw [← Ty.substV_subst_closed hw]
      simpa only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind, Ty.norm_idem] using
        Ty.dataCore_substV hv ν

theorem FieldRef.Declared.bind {P C Γ Δ ν t ref} (h : FieldRef.Declared P C Γ t ref)
    (hm : DataImages P Γ Δ ν) : FieldRef.Declared P C Δ (termBind ν t) ref := by
  obtain ⟨ts, cd, a, ht, hc, hd, hn, ha, hw, hs⟩ := h
  refine ⟨bindDataArgs ν ts, cd, a, ht.bind hm, hc, hd, ?_, ha, hw, ?_⟩
  · simpa only [bindDataArgs_length] using hn
  · rw [← Ty.substV_subst_closed hw]
    exact Ty.hasSort_bind hs (SubstEnv.valuesOnly ν)

structure DeclarationImages (P : Program) (C : List TParam) (Γ Δ : Ctx) (ν : ObservationEnv) : Prop where
  values : ∀ i a, Γ[i]? = some (some a) → Ordinary a →
    ∀ t, ν i = some t → Term.Declared P C Δ t
  data : DataImages P Γ Δ ν

mutual
  theorem Term.Declared.bind {P C Γ Δ ν t} (h : Term.Declared P C Γ t)
      (hm : DeclarationImages P C Γ Δ ν) : Term.Declared P C Δ (termBind ν t) := by
    cases t with
    | var i =>
      obtain ⟨a, ha, ho⟩ := h
      cases hv : ν i with
      | none => simp [termBind_var, hv, Term.Declared]
      | some t => simpa only [termBind_var, hv, Option.getD_some] using hm.values i a ha ho t hv
    | field ref t => exact ⟨Term.Declared.bind (t := t) h.1 hm, h.2.bind hm.data⟩
    | add a b => exact ⟨Term.Declared.bind (t := a) h.1 hm, Term.Declared.bind (t := b) h.2 hm⟩
    | neg t | scale _ t | measure _ t => exact Term.Declared.bind (t := t) h hm
    | listValue xs | setValue xs => exact declaredSlots_bind (xs := xs) h hm
    | mapValue ks vs => exact ⟨declaredSlots_bind (xs := ks) h.1 hm, declaredSlots_bind (xs := vs) h.2 hm⟩
    | dataValue c xs => exact ⟨declaredSlots_bind (xs := xs) h.1 hm, by simpa only [bindSlots_length] using h.2⟩
    | _ => trivial
  theorem declaredSlot_bind {P C Γ Δ ν x} (h : declaredSlot P C Γ x)
      (hm : DeclarationImages P C Γ Δ ν) : declaredSlot P C Δ (slotBind ν x) := by
    cases x with
    | none => trivial
    | some t =>
      cases hv : termBind? ν t with
      | none => simp only [slotBind, hv, declaredSlot]
      | some u =>
        have hh := Term.Declared.bind (t := t) h hm
        simpa only [slotBind, hv, declaredSlot, termBind, Option.getD_some] using hh
  theorem declaredSlots_bind {P C Γ Δ ν xs} (h : declaredSlots P C Γ xs)
      (hm : DeclarationImages P C Γ Δ ν) : declaredSlots P C Δ (bindSlots ν xs) := by
    cases xs with
    | nil => trivial
    | cons x xs => exact ⟨declaredSlot_bind (x := x) h.1 hm, declaredSlots_bind (xs := xs) h.2 hm⟩
end

@[simp] theorem Ty.core_shiftV (a : Ty) (k c : Nat) :
    (a.shiftV k c).core = a.core.shiftV k c := by
  cases a <;> simp only [Ty.shiftV, Ty.core, Ty.core_shiftV]

theorem Ty.ordinary_of_dataCore {a : Ty} {d ts} (h : a.norm.core = .data d ts) : Ordinary a := by
  cases a <;> simp_all [Ty.norm, Ty.core, Ordinary]

theorem Ty.dataCore_shiftV_iff (a : Ty) (k c : Nat) (d : DataName) (ts : List Ty) :
    (a.shiftV k c).norm.core = .data d ts ↔
      ∃ us, a.norm.core = .data d us ∧ ts = shiftVTys k c us := by
  rw [Ty.norm_shiftV, Ty.core_shiftV]
  cases hx : a.norm.core <;> simp only [Ty.shiftV,
    Ty.data.injEq] <;> try simp_all
  case data e us =>
    constructor
    · rintro ⟨rfl, rfl⟩; exact ⟨us, ⟨rfl, rfl⟩, rfl⟩
    · rintro ⟨vs, ⟨rfl, rfl⟩, rfl⟩; exact ⟨rfl, rfl⟩

theorem bindDataArgs_norm (ν : ObservationEnv) (ts : List Ty) :
    Ty.normTys (bindDataArgs ν ts) = bindDataArgs ν ts := by
  rw [bindDataArgs_eq_norm, Ty.normTys_idem]

theorem bindDataArgs_up_shift (ν : ObservationEnv) (ts : List Ty) :
    bindDataArgs (upValues ν) (shiftVTys 1 0 ts) = shiftVTys 1 0 (bindDataArgs ν ts) := by
  simp only [bindDataArgs_eq_norm, shiftVTys_eq_map, substVTys_eq_map, Ty.normTys_eq_map, List.map_map]
  apply List.map_congr_left
  intro a _
  change ((a.shiftV 1 0).rawSubstV (upValues ν)).norm = (a.rawSubstV ν).norm.shiftV 1 0
  rw [Ty.rawSubstV_up, Ty.norm_shiftV]

/-- 宣言照合のための、型注釈まで保つ改名。捕捉時に隠す継続は要求しない。 -/
structure DeclarationRenaming (Γ Δ : Ctx) (ξ : Nat → Nat) : Prop where
  lookup : ∀ i a, Γ[i]? = some (some a) → Ordinary a →
    Δ[ξ i]? = some (some (renameTy ξ a))

theorem DeclarationRenaming.images {P C Γ Δ ξ} (h : DeclarationRenaming Γ Δ ξ) :
    DeclarationImages P C Γ Δ (renEnv ξ).values := by
  constructor
  · intro i a hi ho t ht
    cases ht
    exact ⟨renameTy ξ a, h.lookup i a hi ho,
      Ty.ordinary_rawBind ho _ (by intro j; simp [renEnv])⟩
  · intro i a d ts hi hd
    simp only [renEnv_values, termBind_var, Option.getD_some]
    apply Term.HasData.var (h.lookup i a hi (Ty.ordinary_of_dataCore hd))
    simpa only [Ty.rawSubstV_eq_rawBind, renEnv_values, renameTy, renEnv] using Ty.dataCore_substV hd (renEnv ξ).values

theorem DeclarationRenaming.outer (Γ : Ctx) (a : Ty) :
    DeclarationRenaming Γ (Γ.extend a) (fun i => i+1) := by
  constructor
  intro i t hi _
  have he : renameTy (fun i => i+1) t = t.shiftV 1 0 := by
    have he : shiftIndex 1 0 = (fun i => i+1) := by funext i; simp [shiftIndex]
    rw [Ty.shiftV_eq_renameTy, he]
  simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, hi, Option.map_some, he]

theorem bindDataArgs_shift_renaming {ts : List Ty} (hn : Ty.normTys ts = ts) :
    bindDataArgs (renEnv (fun i => i+1)).values ts = shiftVTys 1 0 ts := by
  rw [bindDataArgs_eq_norm]
  have he : substVTys (renEnv (fun i => i+1)).values ts = shiftVTys 1 0 ts := by
    simp only [substVTys_eq_map, shiftVTys_eq_map]
    apply List.map_congr_left
    intro a _
    rw [Ty.rawSubstV_eq_rawBind]
    have he : shiftIndex 1 0 = (fun i => i+1) := by funext i; simp [shiftIndex]
    rw [Ty.shiftV_eq_renameTy, he]
    rfl
  rw [he, Ty.normTys_shiftV, hn]

theorem DeclarationImages.extend {P C Γ Δ ν} (h : DeclarationImages P C Γ Δ ν) (a b : Ty) (ho : Ordinary a → Ordinary b)
    (hb : b.norm.core = (a.rawSubstV ν).norm.core) :
    DeclarationImages P C (Γ.extend a) (Δ.extend b) (upValues ν) := by
  constructor
  · intro i t hi htOrd u hu
    cases i with
    | zero =>
      cases hu
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      exact ⟨b.shiftV 1 0, rfl,
        (Ty.ordinary_shiftV _ _ _).mpr (ho ((Ty.ordinary_shiftV _ _ _).mp htOrd))⟩
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some t => cases t with
        | none => simp [hg] at hi
        | some t =>
          simp only [hg, Option.map_some, Option.some.injEq] at hi
          cases hi
          simp only [upValues, Option.map_eq_some_iff] at hu
          obtain ⟨v, hv, rfl⟩ := hu
          exact Term.Declared.bind (h.values i t hg ((Ty.ordinary_shiftV _ _ _).mp htOrd) v hv)
            (DeclarationRenaming.outer Δ b).images
  · intro i t d ts hi hd
    cases i with
    | zero =>
      simp only [Ctx.extend, List.getElem?_cons_zero, Option.some.injEq] at hi
      cases hi
      obtain ⟨us, he, rfl⟩ := (Ty.dataCore_shiftV_iff a 1 0 d ts).mp hd
      simp only [upValues, termBind_var, Option.getD_some]
      apply Term.HasData.var rfl
      rw [bindDataArgs_up_shift, Ty.norm_shiftV, Ty.core_shiftV, hb, Ty.dataCore_substV he ν]
      rfl
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map] at hi
      cases hg : Γ[i]? with
      | none => simp [hg] at hi
      | some t => cases t with
        | none => simp [hg] at hi
        | some t =>
          simp only [hg, Option.map_some, Option.some.injEq] at hi
          cases hi
          obtain ⟨us, he, rfl⟩ := (Ty.dataCore_shiftV_iff t 1 0 d ts).mp hd
          have hh := h.data i t d us hg he
          cases hv : ν i with
          | none => simp only [termBind_var, hv, Option.getD_none] at hh; cases hh
          | some v =>
            simp only [termBind_var, hv, Option.getD_some] at hh
            have hl := hh.bind (DeclarationRenaming.images (C := C) (DeclarationRenaming.outer Δ b)).data
            rw [bindDataArgs_shift_renaming (bindDataArgs_norm ν us)] at hl
            simpa only [termBind_var, upValues, hv, Option.map_some, Option.getD_some,
              bindDataArgs_up_shift, renEnv_values] using hl

theorem DeclarationImages.up {P C Γ Δ ν} (h : DeclarationImages P C Γ Δ ν) (a : Ty) :
    DeclarationImages P C (Γ.extend a) (Δ.extend (a.rawSubstV ν)) (upValues ν) :=
  h.extend a (a.rawSubstV ν) (fun ho => (Ty.ordinary_rawSubstV _ _).mpr ho) rfl

@[simp] theorem Ty.rawSubstV_id (a : Ty) : a.rawSubstV (fun i => some (.var i)) = a := by
  rw [Ty.rawSubstV_eq_rawBind]
  exact Ty.rawBind_id a
@[simp] theorem Tel.rawSubstV_id (t : Tel) : Tel.rawSubstV (fun i => some (.var i)) t = t := by
  rw [Tel.rawSubstV_eq_rawBind]
  exact Tel.rawBind_id t

@[simp] theorem bindDataArgs_id (ts : List Ty) : bindDataArgs (fun i => some (.var i)) ts = Ty.normTys ts := by
  rw [bindDataArgs_eq_norm, substVTys_eq_map]
  have he : Ty.rawSubstV (fun i => some (.var i)) = _root_.id := funext Ty.rawSubstV_id
  rw [he, List.map_id]

theorem Ty.dataCore_args_norm {a : Ty} {d ts} (h : a.norm.core = .data d ts) : Ty.normTys ts = ts := by
  have hh := congrArg Ty.norm h
  have hn : a.norm.core.norm = a.norm.core := by
    rw [← Ty.core_norm, Ty.norm_idem]
  rw [hn, h] at hh
  exact (Ty.data.inj hh.symm).2

theorem DeclarationImages.id (P : Program) (C : List TParam) (Γ : Ctx) :
    DeclarationImages P C Γ Γ (fun i => some (.var i)) := by
  constructor
  · intro i a hi ho t ht; cases ht; exact ⟨a, hi, ho⟩
  · intro i a d ts hi hd
    rw [bindDataArgs_id, Ty.dataCore_args_norm hd]
    exact .var hi hd

mutual
  theorem Pred.Declared.bind {P C Γ Δ ν self p} (h : Pred.Declared P C Γ self p)
      (hm : DeclarationImages P C Γ Δ ν) :
      Pred.Declared P C Δ (self.map (Ty.rawSubstV ν))
        (predBind (match self with | none => ν | some _ => upValues ν) p) := by
    cases self with
    | none =>
      cases p <;> simp only [Pred.Declared] at h <;> simp only [Option.map_none, predBind, Pred.Declared]
      all_goals first
        | trivial
        | exact Term.Declared.bind h hm
        | exact ⟨Term.Declared.bind h.1 hm, Term.Declared.bind h.2 hm⟩
        | exact ⟨Pred.Declared.bind h.1 hm, Pred.Declared.bind h.2 hm⟩
        | exact Pred.Declared.bind h hm
        | skip
      case constructorIs t c =>
        obtain ⟨ht, d, ts, cd, hd, hc, hn⟩ := h
        exact ⟨ht.bind hm, d, bindDataArgs ν ts, cd, hd.bind hm.data, hc, hn⟩
    | some a =>
      have hu := hm.up a
      cases p <;> simp only [Pred.Declared] at h <;> simp only [Option.map_some, predBind, Pred.Declared]
      all_goals first
        | trivial
        | exact Term.Declared.bind h hu
        | exact ⟨Term.Declared.bind h.1 hu, Term.Declared.bind h.2 hu⟩
        | exact ⟨Pred.Declared.bind h.1 hm, Pred.Declared.bind h.2 hm⟩
        | exact Pred.Declared.bind h hm
        | skip
      case constructorIs t c =>
        obtain ⟨ht, d, ts, cd, hd, hc, hn⟩ := h
        exact ⟨ht.bind hu, d, bindDataArgs (upValues ν) ts, cd, hd.bind hu.data, hc, hn⟩
end

mutual
  theorem Ty.Declared.rawSubstV {P C Γ Δ ν a} (h : Ty.Declared P C Γ a)
      (hm : DeclarationImages P C Γ Δ ν) : Ty.Declared P C Δ (a.rawSubstV ν) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ => trivial
    | ctor c => cases c <;> exact h
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.Declared.rawSubstV (a := a) h hm
    | data d as => exact ⟨by simpa only [substVTys_eq_map, List.length_map] using h.1,
        declaredTys_rawSubstV (as := as) h.2 hm⟩
    | external _ as => exact ⟨by simpa only [substVTys_eq_map, List.length_map] using h.1,
        declaredTys_rawSubstV (as := as) h.2 hm⟩
    | tapp _ as => exact declaredTys_rawSubstV (as := as) h hm
    | dependentFn t => exact Tel.Declared.rawSubstV (t := t) h hm
    | fn ns ps r e => exact ⟨declaredTys_rawSubstV (as := ps) h.1 hm,
        Ty.Declared.rawSubstV (a := r) h.2.1 hm, declaredEff_rawSubstV (e := e) h.2.2 hm⟩
    | cont b t e => exact ⟨Ty.Declared.rawSubstV (a := b) h.1 hm,
        Ty.Declared.rawSubstV (a := t) h.2.1 hm, declaredEff_rawSubstV (e := e) h.2.2 hm⟩
    | map a b => exact ⟨Ty.Declared.rawSubstV (a := a) h.1 hm, Ty.Declared.rawSubstV (a := b) h.2 hm⟩
    | refined a p => exact ⟨Ty.Declared.rawSubstV (a := a) h.1 hm, Pred.Declared.bind h.2 hm⟩
  theorem Tel.Declared.rawSubstV {P C Γ Δ ν t} (h : Tel.Declared P C Γ t)
      (hm : DeclarationImages P C Γ Δ ν) : Tel.Declared P C Δ (Tel.rawSubstV ν t) := by
    cases t with
    | done r e => exact ⟨Ty.Declared.rawSubstV (a := r) h.1 hm, declaredEff_rawSubstV (e := e) h.2 hm⟩
    | param n a t => exact ⟨Ty.Declared.rawSubstV (a := a) h.1 hm, Tel.Declared.rawSubstV (t := t) h.2 (hm.up a)⟩
  theorem declaredTys_rawSubstV {P C Γ Δ ν as} (h : declaredTys P C Γ as)
      (hm : DeclarationImages P C Γ Δ ν) : declaredTys P C Δ (substVTys ν as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Declared.rawSubstV (a := a) h.1 hm, declaredTys_rawSubstV (as := as) h.2 hm⟩
  theorem declaredEff_rawSubstV {P C Γ Δ ν e} (h : declaredEff P C Γ e)
      (hm : DeclarationImages P C Γ Δ ν) : declaredEff P C Δ (Eff.rawSubstV ν e) := by
    cases e with
    | mk atoms fs => exact declaredTys_rawSubstV (as := fs) h hm
end

theorem Ty.Declared.context {P C Γ Δ a} (h : Ty.Declared P C Γ a)
    (hm : DeclarationImages P C Γ Δ (fun i => some (.var i))) : Ty.Declared P C Δ a := by
  simpa only [Ty.rawSubstV_id] using h.rawSubstV hm

theorem Tel.Declared.context {P C Γ Δ t} (h : Tel.Declared P C Γ t)
    (hm : DeclarationImages P C Γ Δ (fun i => some (.var i))) : Tel.Declared P C Δ t := by
  simpa only [Tel.rawSubstV_id] using h.rawSubstV hm

theorem Pred.Declared.map {P C Γ Δ self other ν p} (h : Pred.Declared P C Γ self p)
    (hm : DeclarationImages P C (Γ.declarationSelf self)
      (Δ.declarationSelf other) ν) :
    Pred.Declared P C Δ other (predBind ν p) := by
  cases p with
  | truth | falsity => trivial
  | eq a b | le a b | lt a b | compare _ _ a b => exact ⟨h.1.bind hm, h.2.bind hm⟩
  | floatClass _ _ a | decimalRepresented a | charactersIn a _ _ | member _ a _ => exact Term.Declared.bind h hm
  | constructorIs a c =>
    obtain ⟨ht, d, ts, cd, hd, hc, hn⟩ := h
    exact ⟨ht.bind hm, d, bindDataArgs ν ts, cd, hd.bind hm.data, hc, hn⟩
  | and p q | or p q => exact ⟨Pred.Declared.map (p := p) h.1 hm, Pred.Declared.map (p := q) h.2 hm⟩
  | not p => exact Pred.Declared.map (p := p) h hm

theorem DeclarationImages.normSelf (P : Program) (C : List TParam) (Γ : Ctx) (a : Ty) :
    DeclarationImages P C (Γ.extend a) (Γ.extend a.norm) (fun i => some (.var i)) := by
  have h := (DeclarationImages.id P C Γ).extend a a.norm
    (fun h => (Ty.ordinary_norm _).mpr h) (by simp only [Ty.norm_idem, Ty.rawSubstV_id])
  simpa only [upValues_id] using h

private theorem declaredTys_iff {P C Γ as} : declaredTys P C Γ as ↔ ∀ a ∈ as, Ty.Declared P C Γ a := by
  induction as with
  | nil => simp [declaredTys]
  | cons a as ih => simp only [declaredTys, ih, List.mem_cons, forall_eq_or_imp]

mutual
  theorem Ty.Declared.norm {P C Γ a} (h : Ty.Declared P C Γ a) : Ty.Declared P C Γ a.norm := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ | tvar _ => trivial
    | ctor c => cases c <;> exact h
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.Declared.norm (a := a) h
    | data d as => exact ⟨by simpa only [Ty.normTys_eq_map, List.length_map] using h.1, declaredTys_norm (as := as) h.2⟩
    | external _ as => exact ⟨by simpa only [Ty.normTys_eq_map, List.length_map] using h.1,
        declaredTys_norm (as := as) h.2⟩
    | tapp _ as => exact declaredTys_norm (as := as) h
    | dependentFn t => exact Tel.Declared.norm (t := t) h
    | fn ns ps r e => exact ⟨declaredTys_norm (as := ps) h.1, Ty.Declared.norm (a := r) h.2.1, declaredEff_norm (e := e) h.2.2⟩
    | cont b t e => exact ⟨Ty.Declared.norm (a := b) h.1, Ty.Declared.norm (a := t) h.2.1, declaredEff_norm (e := e) h.2.2⟩
    | map a b => exact ⟨Ty.Declared.norm (a := a) h.1, Ty.Declared.norm (a := b) h.2⟩
    | refined a p =>
      refine ⟨Ty.Declared.norm (a := a) h.1, ?_⟩
      simpa only [predBind_id] using Pred.Declared.map (Δ := Γ) (other := some a.norm) h.2 (DeclarationImages.normSelf P C Γ a)
  theorem Tel.Declared.norm {P C Γ t} (h : Tel.Declared P C Γ t) : Tel.Declared P C Γ (Tel.norm t) := by
    cases t with
    | done r e => exact ⟨Ty.Declared.norm (a := r) h.1, declaredEff_norm (e := e) h.2⟩
    | param n a t => exact ⟨Ty.Declared.norm (a := a) h.1,
        (Tel.Declared.norm (t := t) h.2).context (DeclarationImages.normSelf P C Γ a)⟩
  theorem declaredTys_norm {P C Γ as} (h : declaredTys P C Γ as) : declaredTys P C Γ (Ty.normTys as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Declared.norm (a := a) h.1, declaredTys_norm (as := as) h.2⟩
  theorem declaredEff_norm {P C Γ e} (h : declaredEff P C Γ e) : declaredEff P C Γ (Eff.norm e) := by
    cases e with
    | mk atoms fs => exact declaredTys_iff.mpr (fun a ha => declaredTys_iff.mp (declaredTys_norm (as := fs) h) a
        (Order.mem_sortUnique.mp ha))
end

theorem Ty.Declared.bind_values {P C Γ Δ ν a} (h : Ty.Declared P C Γ a)
    (hm : DeclarationImages P C Γ Δ ν) : Ty.Declared P C Δ (a.bind (SubstEnv.valuesOnly ν)) := by
  change Ty.Declared P C Δ (a.rawBind _).norm
  unfold SubstEnv.valuesOnly
  rw [← Ty.rawSubstV_eq_rawBind]
  exact (h.rawSubstV hm).norm

theorem Tel.Declared.bind_values {P C Γ Δ ν t} (h : Tel.Declared P C Γ t)
    (hm : DeclarationImages P C Γ Δ ν) : Tel.Declared P C Δ (Tel.bind (SubstEnv.valuesOnly ν) t) := by
  change Tel.Declared P C Δ (Tel.norm (Tel.rawBind _ t))
  unfold SubstEnv.valuesOnly
  rw [← Tel.rawSubstV_eq_rawBind]
  exact (h.rawSubstV hm).norm

theorem Pred.Declared.bind_values {P C Γ Δ ν a p} (h : Pred.Declared P C Γ (some a) p)
    (hm : DeclarationImages P C Γ Δ ν) :
    Pred.Declared P C Δ (some (a.substV ν)) (predBind (upValues ν) p) := by
  apply Pred.Declared.map h
  exact hm.extend a (a.substV ν) (fun h => Ty.ordinary_bind h _ (by intro i; simp [SubstEnv.valuesOnly]))
    (by simp only [Ty.substV, Ty.bind, SubstEnv.valuesOnly, ← Ty.rawSubstV_eq_rawBind, Ty.norm_idem])

theorem Ty.hasSort_core (a : Ty) (sort : «Sort») : a.core.HasSort sort ↔ a.HasSort sort := by
  cases a <;> try rfl
  case refined a p => exact Ty.hasSort_core a sort

theorem Ty.hasSort_of_dataCore {a : Ty} {d ts} (h : a.norm.core = .data d ts) : a.HasSort .data := by
  have hh : a.norm.core.HasSort .data := by rw [h]; rfl
  exact (Ty.hasSort_norm _ _).mp ((Ty.hasSort_core _ _).mp hh)

end Benitoite.Release.Refinement
