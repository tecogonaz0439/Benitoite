import Benitoite.Release.Refinement.Exchange
import Benitoite.Release.Refinement.NormalWellFormed

/-!
# 型と行の有限列による置換

型の像を挿入する際に同じ置換を再適用しない。Γ の None と番号を保つ。
-/
namespace Benitoite.Release.Refinement

/-- 値の番号を保ったまま、格納された型を置換する。 -/
noncomputable def Ctx.bindTypes (Γ : Ctx) (θ : SubstEnv) : Ctx :=
  Γ.map (Option.map (Ty.bind θ))

/-- 値を恒等に保つ型・行・範囲の置換では、元の事実が新しい事実に含まれる。 -/
theorem Ctx.facts_bindTypes (Γ : Ctx) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i)))
    (ht : ∀ i, Ordinary (θ.types i)) {p : Pred} (hp : p ∈ Γ.facts) : p ∈ (Γ.bindTypes θ).facts := by
  obtain ⟨i, a, q, hi, hq, rfl⟩ := Ctx.mem_facts.mp hp
  apply Ctx.mem_facts.mpr
  refine ⟨i, a.bind θ, q, ?_, ?_, rfl⟩
  · simp only [Ctx.bindTypes, List.getElem?_map, hi, Option.map_some]
  · simpa only [hv, upValues_id, predBind_id] using Ty.assume_bind a θ ht q hq

/-- 型・行・範囲の像によって事実が増えることを許す、構文の移送。 -/
theorem Transport.types (Γ : Ctx) (Φ : List Pred) (θ : SubstEnv) (hv : θ.values = (fun i => some (.var i)))
    (ht : ∀ i, Ordinary (θ.types i)) :
    Transport θ Γ Φ (Γ.bindTypes θ) Φ := by
  constructor
  · intro i a s hi ha
    have hi' : (Γ.bindTypes θ)[i]? = some (some (a.bind θ)) := by
      simp [Ctx.bindTypes, List.getElem?_map, hi]
    exact ⟨.var i, by rw [hv], ⟨a.bind θ, hi', Ty.ordinary_bind ha.ordinary θ ht⟩,
      a.bind θ, hi', Ty.hasSort_bind ha θ⟩
  · intro i a hi ho u hu
    rw [hv] at hu
    cases hu
    exact ⟨a.bind θ, by simp [Ctx.bindTypes, List.getElem?_map, hi], Ty.ordinary_bind ho θ ht⟩
  · exact ht
  · intro p hp
    rw [hv, predBind_id]
    apply Entails.hyp
    rcases List.mem_append.mp hp with hp | hp
    · exact List.mem_append_left _ (Ctx.facts_bindTypes Γ θ hv ht hp)
    · exact List.mem_append_right _ hp

noncomputable def Ty.substAt (c : Nat) (ts : List Ty) (es : List Eff) (a : Ty) : Ty :=
  substTypeAt c ts es a
noncomputable def Eff.substAt (c : Nat) (ts : List Ty) (es : List Eff) (e : Eff) : Eff :=
  substRowAt c ts es e
noncomputable def Ty.subst (ts : List Ty) (es : List Eff) (a : Ty) : Ty := a.substAt 0 ts es
noncomputable def Eff.subst (ts : List Ty) (es : List Eff) (e : Eff) : Eff := Eff.substAt 0 ts es e

theorem shiftTypes_ordinary {a : Ty} (h : Ordinary a) (k c : Nat) : Ordinary (shiftTypes k c a) := by
  cases a <;> simp_all [shiftTypes, Ordinary]
  case refined a p => exact shiftTypes_ordinary (a := a) h k c

theorem typeEnvAt_ordinary (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, Ordinary a) : ∀ i, Ordinary ((typeEnvAt c ts es).types i) := by
  intro i
  simp only [typeEnvAt]
  split
  · simp [Ordinary]
  · split
    · cases hg : ts[i-c]? with
      | none => simp [Ordinary, shiftTypes]
      | some a => exact shiftTypes_ordinary (ht a (List.mem_of_getElem? hg)) c 0
    · simp [Ordinary]

/-- 型引数の cutoff は値の束縛と独立であり、型・行の像は外側値に依存してよい。 -/
theorem Ty.LeQ.substAt {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, Ordinary a) :
    Ty.LeQ (Γ.bindTypes (typeEnvAt c ts es)) Φ (a.substAt c ts es) (b.substAt c ts es) :=
  h.bind _ (Transport.types Γ Φ _ rfl (typeEnvAt_ordinary c ts es ht))

theorem Ty.LeQ.subst {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, Ordinary a) :
    Ty.LeQ (Γ.bindTypes (typeEnvAt 0 ts es)) Φ (a.subst ts es) (b.subst ts es) :=
  h.substAt 0 ts es ht

theorem Eff.Covers.substAt {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f)
    (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.Covers Δ Ψ (Eff.substAt c ts es e) (Eff.substAt c ts es f) := h.bind _

theorem Eff.Covers.subst {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (ts : List Ty) (es : List Eff) :
    Eff.Covers Δ Ψ (Eff.subst ts es e) (Eff.subst ts es f) := h.substAt 0 ts es

/-- 型変数の移動を一般の構文置換として行う。 -/
def SubstEnv.shiftTypes (k c : Nat) : SubstEnv :=
  ⟨fun i => .tvar (shiftIndex k c i), [], [], (fun i => some (.var i))⟩

noncomputable def Ty.shift (k c : Nat) (a : Ty) : Ty := a.bind (.shiftTypes k c)
noncomputable def Eff.shift (k c : Nat) (e : Eff) : Eff := Eff.bind (.shiftTypes k c) e

theorem Ty.LeQ.shift {Γ Φ a b} (h : Ty.LeQ Γ Φ a b) (k c : Nat) :
    Ty.LeQ (Γ.bindTypes (.shiftTypes k c)) Φ (a.shift k c) (b.shift k c) :=
  h.bind _ (Transport.types Γ Φ _ rfl (by intro i; simp [SubstEnv.shiftTypes]))

theorem Eff.Covers.shift {Γ Φ Δ Ψ e f} (h : Eff.Covers Γ Φ e f) (k c : Nat) :
    Eff.Covers Δ Ψ (Eff.shift k c e) (Eff.shift k c f) := h.bind _

mutual
  theorem shiftTypes_shiftV (a : Ty) (kt ct kv cv : Nat) :
      shiftTypes kt ct (a.shiftV kv cv) = (shiftTypes kt ct a).shiftV kv cv := by
    cases a <;> simp only [shiftTypes, Ty.shiftV, shiftTypesList_shiftV, shiftRowsTypes_shiftV,
      shiftTypes_shiftV, shiftTelTypes_shiftV]
  theorem shiftTelTypes_shiftV (t : Tel) (kt ct kv cv : Nat) :
      shiftTelTypes kt ct (Tel.shiftV kv cv t) = Tel.shiftV kv cv (shiftTelTypes kt ct t) := by
    cases t <;> simp only [shiftTelTypes, Tel.shiftV, shiftTypes_shiftV, shiftRowsTypes_shiftV, shiftTelTypes_shiftV]
  theorem shiftTypesList_shiftV (as : List Ty) (kt ct kv cv : Nat) :
      shiftTypesList kt ct (shiftVTys kv cv as) = shiftVTys kv cv (shiftTypesList kt ct as) := by
    cases as <;> simp only [shiftTypesList, shiftVTys, shiftTypes_shiftV, shiftTypesList_shiftV]
  theorem shiftRowsTypes_shiftV (e : Eff) (kt ct kv cv : Nat) :
      shiftRowsTypes kt ct (Eff.shiftV kv cv e) = Eff.shiftV kv cv (shiftRowsTypes kt ct e) := by
    cases e
    simp only [shiftRowsTypes, Eff.shiftV, shiftTypesList_shiftV]
end

/-- 依存する値の束縛を越える型・行の有限列の up。 -/
theorem typeEnvAt_up (c : Nat) (ts : List Ty) (es : List Eff) :
    (typeEnvAt c ts es).up = typeEnvAt c (ts.map (Ty.shiftV 1 0)) (es.map (Eff.shiftV 1 0)) := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  · funext i
    simp only [typeEnvAt, List.length_map, List.getElem?_map]
    split
    · rfl
    · split
      · cases hi : ts[i-c]? with
        | none => rfl
        | some a => exact (shiftTypes_shiftV a c 0 1 0).symm
      · rfl
  · simp only [typeEnvAt, List.map_map]
    congr 1
    funext e
    exact (shiftRowsTypes_shiftV e c 0 1 0).symm
  · exact upValues_id

theorem Ty.substAt_up (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    (a.shiftV 1 0).substAt c (ts.map (Ty.shiftV 1 0)) (es.map (Eff.shiftV 1 0)) =
      (a.substAt c ts es).shiftV 1 0 := by
  change (a.shiftV 1 0).bind _ = (a.bind _).shiftV 1 0
  rw [← typeEnvAt_up]
  exact a.bind_up _

theorem Eff.substAt_up (e : Eff) (c : Nat) (ts : List Ty) (es : List Eff) :
    Eff.substAt c (ts.map (Ty.shiftV 1 0)) (es.map (Eff.shiftV 1 0)) (Eff.shiftV 1 0 e) =
      Eff.shiftV 1 0 (Eff.substAt c ts es e) := by
  change Eff.bind _ (Eff.shiftV 1 0 e) = Eff.shiftV 1 0 (Eff.bind _ e)
  rw [← typeEnvAt_up]
  exact Eff.bind_up e _

mutual
  @[simp] theorem shiftTypes_zero (a : Ty) (c : Nat) : shiftTypes 0 c a = a := by
    cases a <;> simp only [shiftTypes, shiftTypesList_zero, shiftRowsTypes_zero, shiftTypes_zero, shiftTelTypes_zero,
      Nat.add_zero, ite_self]
  @[simp] theorem shiftTelTypes_zero (t : Tel) (c : Nat) : shiftTelTypes 0 c t = t := by
    cases t <;> simp only [shiftTelTypes, shiftTypes_zero, shiftRowsTypes_zero, shiftTelTypes_zero]
  @[simp] theorem shiftTypesList_zero (as : List Ty) (c : Nat) : shiftTypesList 0 c as = as := by
    cases as <;> simp only [shiftTypesList, shiftTypes_zero, shiftTypesList_zero]
  @[simp] theorem shiftRowsTypes_zero (e : Eff) (c : Nat) : shiftRowsTypes 0 c e = e := by
    cases e
    simp only [shiftRowsTypes, shiftTypesList_zero]
end

private theorem wfList_sortUnique {nr nt nv : Nat} {as : List Ty} (h : Ty.WFList nr nt nv as) :
    Ty.WFList nr nt nv (Order.sortUnique tyCompare as) := by
  rw [Ty.wfList_iff] at h ⊢
  exact fun a ha => h a (Order.mem_sortUnique.mp ha)

@[simp] theorem shiftTypesList_length (as : List Ty) (k c : Nat) :
    (shiftTypesList k c as).length = as.length := by
  induction as <;> simp_all [shiftTypesList]

theorem Ty.notContCore_shiftTypes (a : Ty) (k c : Nat) :
    (shiftTypes k c a).NotContCore ↔ a.NotContCore := by
  cases a <;> simp [shiftTypes, Ty.NotContCore, Ty.core]
  case refined a p => exact Ty.notContCore_shiftTypes a k c

mutual
  theorem Ty.wf_shiftTypes_norm {nr nt nv : Nat} {a : Ty} (h : a.WF nr nt nv) (k c : Nat) :
      (shiftTypes k c a).norm.WF nr (nt+k) nv := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [shiftTypes, Ty.norm, Ty.WF]
    all_goals first | exact h | exact Ty.wf_shiftTypes_norm h k c | exact wfList_shiftTypes_norm h k c | exact Tel.wf_shiftTypes_norm h k c | skip
    case fn ns ps r e =>
      exact ⟨by simpa only [NamesWF, Ty.normTys_eq_map, List.length_map, shiftTypesList_length] using h.1,
        wfList_shiftTypes_norm h.2.1 k c, Ty.wf_shiftTypes_norm h.2.2.1 k c,
        Eff.wf_shiftTypes_norm h.2.2.2.1 k c, Eff.norm_idem _⟩
    case tvar i => split <;> omega
    case cont b t e =>
      exact ⟨Ty.wf_shiftTypes_norm h.1 k c, Ty.wf_shiftTypes_norm h.2.1 k c,
        Eff.wf_shiftTypes_norm h.2.2.1 k c, Eff.norm_idem _⟩
    case map a b => exact ⟨Ty.wf_shiftTypes_norm h.1 k c, Ty.wf_shiftTypes_norm h.2 k c⟩
    case tapp i as => exact ⟨by split <;> omega, wfList_shiftTypes_norm h.2 k c⟩
    case refined a p =>
      exact Ty.wf_refineNorm (Ty.wf_shiftTypes_norm h.1 k c) h.2.1
        ((Ty.notContCore_norm _).mpr ((Ty.notContCore_shiftTypes _ _ _).mpr h.2.2))
    case dependentFn t => exact Ty.wf_foldFn (Tel.wf_shiftTypes_norm h k c)
  theorem Tel.wf_shiftTypes_norm {nr nt nv : Nat} {t : Tel} (h : Tel.WF nr nt nv t) (k c : Nat) :
      Tel.WF nr (nt+k) nv (Tel.norm (shiftTelTypes k c t)) := by
    cases t with
    | done r e => exact ⟨Ty.wf_shiftTypes_norm h.1 k c, Eff.wf_shiftTypes_norm h.2.1 k c, Eff.norm_idem _⟩
    | param n a t => exact ⟨Ty.wf_shiftTypes_norm h.1 k c, Tel.wf_shiftTypes_norm h.2 k c⟩
  theorem wfList_shiftTypes_norm {nr nt nv : Nat} {as : List Ty} (h : Ty.WFList nr nt nv as) (k c : Nat) :
      Ty.WFList nr (nt+k) nv (Ty.normTys (shiftTypesList k c as)) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_shiftTypes_norm h.1 k c, wfList_shiftTypes_norm h.2 k c⟩
  theorem Eff.wf_shiftTypes_norm {nr nt nv : Nat} {e : Eff} (h : e.WF nr nt nv) (k c : Nat) :
      (shiftRowsTypes k c e).norm.WF nr (nt+k) nv := by
    cases e
    exact wfList_sortUnique (wfList_shiftTypes_norm h k c)
end

@[simp] theorem SubstEnv.shiftTypes_up (k c : Nat) : (SubstEnv.shiftTypes k c).up = SubstEnv.shiftTypes k c := by
  change SubstEnv.mk _ _ _ _ = SubstEnv.mk _ _ _ _
  congr 1
  exact upValues_id

mutual
  theorem Ty.rawBind_shiftTypes (a : Ty) (k c : Nat) :
      a.rawBind (SubstEnv.shiftTypes k c) = shiftTypes k c a := by
    cases a <;> simp only [Ty.rawBind, shiftTypes, rawApply,
      Ty.rawBind_shiftTypes, rawBindTys_shiftTypes, Eff.rawBind_shiftTypes, Tel.rawBind_shiftTypes]
    all_goals simp [SubstEnv.shiftTypes, rawApply, RangeIx.inst_nil, upValues_id, predBind_id, shiftIndex]
  theorem Tel.rawBind_shiftTypes (t : Tel) (k c : Nat) :
      Tel.rawBind (SubstEnv.shiftTypes k c) t = shiftTelTypes k c t := by
    cases t with
    | done r e =>
      change Tel.done (r.rawBind (SubstEnv.shiftTypes k c)) (Eff.rawBind (SubstEnv.shiftTypes k c) e) = _
      rw [Ty.rawBind_shiftTypes, Eff.rawBind_shiftTypes]
      rfl
    | param n a t =>
      change Tel.param n (a.rawBind (SubstEnv.shiftTypes k c)) (Tel.rawBind (SubstEnv.shiftTypes k c).up t) = _
      rw [SubstEnv.shiftTypes_up, Ty.rawBind_shiftTypes, Tel.rawBind_shiftTypes]
      rfl
  theorem rawBindTys_shiftTypes (as : List Ty) (k c : Nat) :
      rawBindTys (SubstEnv.shiftTypes k c) as = shiftTypesList k c as := by
    cases as <;> simp only [rawBindTys, shiftTypesList, Ty.rawBind_shiftTypes, rawBindTys_shiftTypes]
  theorem Eff.rawBind_shiftTypes (e : Eff) (k c : Nat) :
      Eff.rawBind (SubstEnv.shiftTypes k c) e = shiftRowsTypes k c e := by
    cases e with
    | mk a fs =>
      simp only [Eff.rawBind, shiftRowsTypes,
        rawBindTys_shiftTypes, rowFails]
      simp [SubstEnv.shiftTypes, instAtoms_nil, substAtoms_nil]
end

theorem Ty.wf_shift {nr nt nv : Nat} {a : Ty} (h : a.WF nr nt nv) (k c : Nat) :
    (a.shift k c).WF nr (nt+k) nv := by
  simpa only [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes] using Ty.wf_shiftTypes_norm h k c

theorem Eff.wf_shift {nr nt nv : Nat} {e : Eff} (h : e.WF nr nt nv) (k c : Nat) :
    (Eff.shift k c e).WF nr (nt+k) nv := by
  simpa only [Eff.shift, Eff.bind, Eff.rawBind_shiftTypes] using Eff.wf_shiftTypes_norm h k c

@[simp] theorem Ty.substAt_norm_source (a : Ty) (c : Nat) (ts : List Ty) (es : List Eff) :
    a.norm.substAt c ts es = a.substAt c ts es := Ty.norm_rawBind _ a

@[simp] theorem Ty.subst_norm_source (a : Ty) (ts : List Ty) (es : List Eff) :
    a.norm.subst ts es = a.subst ts es := Ty.norm_rawBind _ a

end Benitoite.Release.Refinement
