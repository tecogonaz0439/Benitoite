import Benitoite.Release.Refinement.TypeRegularity
import Benitoite.Release.Refinement.TypeShiftContext

/-! 四名前空間の像の条件から、同時置換後の正規化した型のWFを得る。
旧のRawWF層を経由しない（設計書01-12「コア計算と脱糖」）。 -/
namespace Benitoite.Release.Refinement

/-- nr/nt/nvは入力、mr/mt/mvは出力の範囲・型・値の深さである。
行の像は有限列で、行変数の上限と範囲の上限を混同しない。 -/
structure SubstEnv.WFImages (nr nt nv mr mt mv : Nat) (θ : SubstEnv) : Prop where
  types : ∀ i, i < nt → (θ.types i).WF mr mt mv
  rows : ∀ e ∈ θ.rows, e.WF mr mt mv
  ranges : ∀ (ix : RangeIx), ix.WF nr → (ix.inst θ.ranges).WF mr
  values : ∀ i, i < nv → ∀ t, θ.values i = some t → termWF mv t
  ordinary : ∀ i, Ordinary (θ.types i)

theorem observationWF_up {nv mv : Nat} {ν : ObservationEnv}
    (h : ∀ i, i < nv → ∀ t, ν i = some t → termWF mv t) :
    ∀ i, i < nv+1 → ∀ t, upValues ν i = some t → termWF (mv+1) t := by
  intro i hi t ht
  cases i with
  | zero => cases ht; exact Nat.zero_lt_succ _
  | succ i =>
    simp only [upValues, Option.map_eq_some_iff] at ht
    obtain ⟨u, hu, rfl⟩ := ht
    apply termWF_bind (h i (by omega) u hu)
    intro j hj v hv
    cases hv
    exact Nat.succ_lt_succ hj

theorem SubstEnv.WFImages.up {nr nt nv mr mt mv : Nat} {θ : SubstEnv}
    (h : θ.WFImages nr nt nv mr mt mv) : θ.up.WFImages nr nt (nv+1) mr mt (mv+1) := by
  constructor
  · intro i hi; exact Ty.wf_shiftV (h.types i hi) 1 0
  · intro e he
    change e ∈ θ.rows.map (Eff.shiftV 1 0) at he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    exact Eff.wf_shiftV (h.rows f hf) 1 0
  · exact h.ranges
  · exact observationWF_up h.values
  · intro i; exact (Ty.ordinary_shiftV _ _ _).mpr (h.ordinary i)

theorem rawApply_notContCore {t : Ty} (h : t.NotContCore) (as : List Ty) :
    (rawApply t as).NotContCore := by
  cases t <;> try simp only [rawApply]
  all_goals try exact h
  case tvar i => simp [Ty.NotContCore, Ty.core]
  case ctor c => cases c <;> simp [rawApply, Ty.NotContCore, Ty.core]
  case refined a p => exact rawApply_notContCore (t := a) h as

/-- ここではscopeだけを示す。arityとkindには別にProperApply/HasKindを使う。 -/
theorem rawApply_wf {nr nt nv : Nat} {t : Ty} (ht : t.WF nr nt nv) (as : List Ty)
    (hs : Ty.WFList nr nt nv as) : (rawApply t as).WF nr nt nv := by
  cases t <;> try simp only [rawApply]
  all_goals try exact ht
  case tvar i => exact ⟨ht, hs⟩
  case refined a p => exact ⟨rawApply_wf ht.1 as hs, ht.2.1, rawApply_notContCore ht.2.2 as⟩
  case ctor c =>
    cases c <;> cases as <;> simp only [rawApply, Ty.WF, List.headD_nil,
      List.headD_cons, List.tail_nil, List.tail_cons] at *
    all_goals first | trivial | exact hs | exact hs.1 | skip
    case map.cons a as =>
      cases as with
      | nil => exact ⟨hs.1, trivial⟩
      | cons b bs => exact ⟨hs.1, hs.2.1⟩

private theorem wfList_sortUnique {nr nt nv : Nat} {as : List Ty}
    (h : Ty.WFList nr nt nv as) : Ty.WFList nr nt nv (Order.sortUnique tyCompare as) := by
  rw [Ty.wfList_iff] at h ⊢
  exact fun a ha => h a (Order.mem_sortUnique.mp ha)

mutual
  theorem Ty.rawBind_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (a : Ty)
      (h : a.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) :
      (a.rawBind θ).norm.WF mr mt mv := by
    cases a <;> simp only [Ty.WF] at h <;> simp only [Ty.rawBind, Ty.norm, Ty.WF]
    all_goals first | trivial | exact Ty.rawBind_norm_wf _ h hi |
      exact rawBindTys_norm_wf _ h hi | exact hi.ranges _ h | skip
    case fn ns ps r e => exact ⟨by
        simpa only [NamesWF, Ty.normTys_eq_map, rawBindTys_eq_map, List.length_map] using h.1,
      rawBindTys_norm_wf ps h.2.1 hi, Ty.rawBind_norm_wf r h.2.2.1 hi,
      Eff.rawBind_norm_wf e h.2.2.2.1 hi, Eff.norm_idem _⟩
    case tvar i => exact Ty.wf_norm (hi.types i h)
    case cont a b e => exact ⟨Ty.rawBind_norm_wf a h.1 hi,
      Ty.rawBind_norm_wf b h.2.1 hi, Eff.rawBind_norm_wf e h.2.2.1 hi, Eff.norm_idem _⟩
    case map a b => exact ⟨Ty.rawBind_norm_wf a h.1 hi, Ty.rawBind_norm_wf b h.2 hi⟩
    case tapp i as =>
      rw [← rawApply_norm_args]
      exact Ty.wf_norm (rawApply_wf (hi.types i h.1) _ (rawBindTys_norm_wf as h.2 hi))
    case refined a p =>
      exact Ty.wf_refineNorm (Ty.rawBind_norm_wf a h.1 hi)
        (Pred.wf_bind h.2.1 _ (observationWF_up hi.values))
        ((Ty.notContCore_norm _).mpr (Ty.ordinary_rawBind h.2.2 θ hi.ordinary))
    case dependentFn t => exact Ty.wf_foldFn (Tel.rawBind_norm_wf t h hi)
  theorem rawBindTys_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (as : List Ty)
      (h : Ty.WFList nr nt nv as) (hi : θ.WFImages nr nt nv mr mt mv) :
      Ty.WFList mr mt mv (Ty.normTys (rawBindTys θ as)) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawBind_norm_wf a h.1 hi, rawBindTys_norm_wf as h.2 hi⟩
  theorem Eff.rawBind_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (e : Eff)
      (h : e.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) :
      (Eff.rawBind θ e).norm.WF mr mt mv := by
    cases e with
    | mk atoms fs =>
      apply wfList_sortUnique
      rw [Ty.normTys_append, Ty.wfList_iff]
      intro a ha
      rcases List.mem_append.mp ha with ha | ha
      · exact Ty.wfList_iff.mp (rawBindTys_norm_wf fs h hi) a ha
      · obtain ⟨t, ht, rfl⟩ := List.mem_map.mp (show a ∈ (rowFails θ.rows atoms).map Ty.norm from by simpa only [Ty.normTys_eq_map] using ha)
        obtain ⟨i, f, hf, _, htf⟩ := Eff.mem_rowFails.mp ht
        apply Ty.wf_norm
        have hw : Ty.WFList mr mt mv f.fails := by
          cases f; exact hi.rows _ (List.mem_of_getElem? hf)
        exact Ty.wfList_iff.mp hw t htf
  theorem Tel.rawBind_norm_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (t : Tel)
      (h : t.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) :
      (Tel.norm (Tel.rawBind θ t)).WF mr mt mv := by
    cases t with
    | done r e => exact ⟨Ty.rawBind_norm_wf r h.1 hi, Eff.rawBind_norm_wf e h.2.1 hi, Eff.norm_idem _⟩
    | param n a t => exact ⟨Ty.rawBind_norm_wf a h.1 hi, Tel.rawBind_norm_wf t h.2 hi.up⟩
end

theorem Ty.bind_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (a : Ty)
    (h : a.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) : (a.bind θ).WF mr mt mv :=
  Ty.rawBind_norm_wf a h hi

/-- 名前の原子に現れる範囲変数の条件。Fail内のWFとは別の条件である。 -/
def Eff.AtomsWF (nr : Nat) (e : Eff) : Prop := ∀ l ix, e.mem (.name l ix) → ix.WF nr

theorem Eff.substAt_atoms_wf {nr c : Nat} {ts : List Ty} {es : List Eff} {e : Eff}
    (h : e.AtomsWF nr) (he : ∀ f ∈ es, f.AtomsWF nr) :
    (Eff.substAt c ts es e).AtomsWF nr := by
  intro l ix hm
  change (Eff.bind (typeEnvAt c ts es) e).mem (.name l ix) at hm
  rw [Eff.bind, Eff.mem_norm, Eff.mem_rawBind] at hm
  rcases hm with ⟨b, hb, hbi, _⟩ | ⟨i, f, hf, _, hm⟩
  · simp only [typeEnvAt, Atom.instR_nil] at hbi
    subst b
    exact h l ix hb
  · obtain ⟨g, hg, hfg⟩ := List.mem_of_getElem? hf |> List.mem_map.mp
    subst f
    cases g
    exact he _ hg l ix hm


theorem Ty.rawShift_eq_rawBind (k c : Nat) (a : Ty) :
    shiftTypes k c a = a.rawBind (SubstEnv.shiftTypes k c) := (Ty.rawBind_shiftTypes a k c).symm

theorem Ty.rawShiftTys_eq_rawBindTys (k c : Nat) (as : List Ty) :
    shiftTypesList k c as = rawBindTys (SubstEnv.shiftTypes k c) as := (rawBindTys_shiftTypes as k c).symm

theorem Eff.rawShift_eq_rawBind (k c : Nat) (e : Eff) :
    shiftRowsTypes k c e = Eff.rawBind (SubstEnv.shiftTypes k c) e :=
  (Eff.rawBind_shiftTypes e k c).symm

theorem typeEnvAt_wfImages {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) :
    (typeEnvAt c ts es).WFImages nr (c+ts.length) nv nr (n+c) nv := by
  constructor
  · intro i hi
    simp only [typeEnvAt]
    split
    · change i < n+c; omega
    · rename_i hic
      have hl : i-c < ts.length := by omega
      simp only [hl, ↓reduceIte, List.getElem?_eq_getElem hl, Option.getD_some]
      exact Ty.wf_shiftTypes (ht _ (List.getElem_mem hl)) c 0
  · intro e hm
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hm
    exact Eff.wf_shiftTypes (he f hf) c 0
  · intro ix hw; simpa only [typeEnvAt, RangeIx.inst_nil] using hw
  · intro i hi t ht
    cases ht
    exact hi
  · exact typeEnvAt_ordinary c ts es ho

theorem Ty.substAt_wf {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (a : Ty) (h : a.WF nr (c+ts.length) nv) :
    (Ty.substAt c ts es a).WF nr (n+c) nv :=
  Ty.bind_wf a h (typeEnvAt_wfImages c ts es ht he ho)

theorem Ty.subst_wf {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (a : Ty) (h : a.WF nr ts.length nv) :
    (Ty.subst ts es a).WF nr n nv := by
  simpa only [Ty.subst, Nat.zero_add, Nat.add_zero] using Ty.substAt_wf 0 ts es ht he ho a (by simpa using h)

theorem Eff.bind_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (e : Eff)
    (h : e.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) :
    (Eff.bind θ e).WF mr mt mv := Eff.rawBind_norm_wf e h hi

theorem Eff.substAt_wf {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (e : Eff) (h : e.WF nr (c+ts.length) nv) :
    (Eff.substAt c ts es e).WF nr (n+c) nv :=
  Eff.bind_wf e h (typeEnvAt_wfImages c ts es ht he ho)

theorem Eff.subst_wf {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (e : Eff) (h : e.WF nr ts.length nv) :
    (Eff.subst ts es e).WF nr n nv := by
  simpa only [Eff.subst, Nat.zero_add, Nat.add_zero] using Eff.substAt_wf 0 ts es ht he ho e (by simpa using h)

theorem Ty.substList_wf {nr n nv : Nat} (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (as : List Ty) (h : Ty.WFList nr ts.length nv as) :
    Ty.WFList nr n nv (as.map (Ty.subst ts es)) := by
  rw [Ty.wfList_iff]
  rintro a ha
  obtain ⟨b, hb, rfl⟩ := List.mem_map.mp ha
  exact Ty.subst_wf ts es ht he ho b (Ty.wfList_iff.mp h b hb)

/-- 依存列の公開bindも同じ像の条件でWFを保つ。 -/
theorem Tel.bind_wf {nr nt nv mr mt mv : Nat} {θ : SubstEnv} (t : Tel)
    (h : t.WF nr nt nv) (hi : θ.WFImages nr nt nv mr mt mv) :
    (Tel.bind θ t).WF mr mt mv := Tel.rawBind_norm_wf t h hi

theorem Tel.substAt_wf {nr n nv : Nat} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.WF nr n nv) (he : ∀ e ∈ es, e.WF nr n nv)
    (ho : ∀ a ∈ ts, Ordinary a) (t : Tel) (h : t.WF nr (c+ts.length) nv) :
    (Tel.substAt c ts es t).WF nr (n+c) nv :=
  Tel.bind_wf t h (typeEnvAt_wfImages c ts es ht he ho)

/-- cutoffより内側だけを使う型へは、有限列の置換を適用しない。 -/
theorem typeEnvAt_agrees_id_below (c : Nat) (ts : List Ty) :
    SubstEnv.AgreesBelow c (typeEnvAt c ts []) (renEnv id) := by
  refine ⟨?_, rfl, rfl, rfl⟩
  intro i hi
  simp only [typeEnvAt, hi, ↓reduceIte, renEnv, id_eq]

theorem Ty.substAt_nil_of_wf {nr nv c : Nat} (ts : List Ty) (a : Ty)
    (h : a.WF nr c nv) : a.substAt c ts [] = a.norm := by
  change (a.rawBind (typeEnvAt c ts [])).norm = a.norm
  rw [Ty.rawBind_agrees h (typeEnvAt_agrees_id_below c ts), Ty.rawBind_id]

theorem Eff.substAt_nil_of_wf {nr nv c : Nat} (ts : List Ty) (e : Eff)
    (h : e.WF nr c nv) : Eff.substAt c ts [] e = e.norm := by
  change (Eff.rawBind (typeEnvAt c ts []) e).norm = e.norm
  rw [Eff.rawBind_agrees h (typeEnvAt_agrees_id_below c ts), Eff.rawBind_id]

theorem Tel.substAt_nil_of_wf {nr nv c : Nat} (ts : List Ty) (t : Tel)
    (h : t.WF nr c nv) : Tel.substAt c ts [] t = Tel.norm t := by
  change Tel.norm (Tel.rawBind (typeEnvAt c ts []) t) = Tel.norm t
  rw [Tel.rawBind_agrees h (typeEnvAt_agrees_id_below c ts), Tel.rawBind_id]

end Benitoite.Release.Refinement
