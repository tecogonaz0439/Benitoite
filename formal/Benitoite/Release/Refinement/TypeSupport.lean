import Benitoite.Release.Refinement.TypeSubst

/-! 型内部・Fail・依存列に現れる効果原子の支持。値参照の整形式とは区別する。 -/
namespace Benitoite.Release.Refinement

mutual
  def Ty.Support (p : Atom → Prop) : Ty → Prop
    | .data _ ts | .tapp _ ts | .external _ ts => Ty.SupportList p ts
    | .list t | .reference t | .lazy t | .set t | .dict _ t | .refined t _ => t.Support p
    | .fn _ ps r e => Ty.SupportList p ps ∧ r.Support p ∧ Eff.Support p e
    | .cont a b e => a.Support p ∧ b.Support p ∧ Eff.Support p e
    | .map a b => a.Support p ∧ b.Support p
    | .dependentFn t => Tel.Support p t
    | _ => True
  def Ty.SupportList (p : Atom → Prop) : List Ty → Prop
    | [] => True
    | t :: ts => t.Support p ∧ Ty.SupportList p ts
  def Eff.Support (p : Atom → Prop) : Eff → Prop
    | .mk a fs => (∀ x, a x = true → p x) ∧ Ty.SupportList p fs
  def Tel.Support (p : Atom → Prop) : Tel → Prop
    | .done r e => r.Support p ∧ Eff.Support p e
    | .param _ a t => a.Support p ∧ Tel.Support p t
end

theorem Ty.SupportList.iff {p ts} : Ty.SupportList p ts ↔ ∀ t ∈ ts, t.Support p := by
  induction ts with
  | nil => simp [Ty.SupportList]
  | cons t ts ih => simp [Ty.SupportList, ih]


def Ty.Finite (a : Ty) : Prop := ∃ s : List Atom, a.Support (· ∈ s)
def Eff.Finite (e : Eff) : Prop := ∃ s : List Atom, e.Support (· ∈ s)

theorem Eff.support_iff {p : Atom → Prop} (e : Eff) :
    e.Support p ↔ (∀ a, e.test a = true → p a) ∧ Ty.SupportList p e.fails := by
  cases e; rfl

mutual
  theorem Ty.support_mono {p q : Atom → Prop} (t : Ty) (h : t.Support p)
      (hp : ∀ a, p a → q a) : t.Support q := by
    cases t <;> simp only [Ty.Support] at h ⊢
    all_goals first
      | trivial
      | exact Ty.support_mono _ h hp
      | exact Ty.supportList_mono _ h hp
      | exact Tel.support_mono _ h hp
      | skip
    case fn ns ps r e => exact ⟨Ty.supportList_mono ps h.1 hp,
      Ty.support_mono r h.2.1 hp, Eff.support_mono e h.2.2 hp⟩
    case cont a b e => exact ⟨Ty.support_mono a h.1 hp,
      Ty.support_mono b h.2.1 hp, Eff.support_mono e h.2.2 hp⟩
    case map a b => exact ⟨Ty.support_mono a h.1 hp, Ty.support_mono b h.2 hp⟩
  theorem Ty.supportList_mono {p q : Atom → Prop} (ts : List Ty) (h : Ty.SupportList p ts)
      (hp : ∀ a, p a → q a) : Ty.SupportList q ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.support_mono t h.1 hp, Ty.supportList_mono ts h.2 hp⟩
  theorem Eff.support_mono {p q : Atom → Prop} (e : Eff) (h : Eff.Support p e)
      (hp : ∀ a, p a → q a) : Eff.Support q e := by
    cases e
    exact ⟨fun a ha => hp a (h.1 a ha), Ty.supportList_mono _ h.2 hp⟩
  theorem Tel.support_mono {p q : Atom → Prop} (t : Tel) (h : t.Support p)
      (hp : ∀ a, p a → q a) : t.Support q := by
    cases t with
    | done r e => exact ⟨Ty.support_mono r h.1 hp, Eff.support_mono e h.2 hp⟩
    | param n a t => exact ⟨Ty.support_mono a h.1 hp, Tel.support_mono t h.2 hp⟩
end

mutual
  theorem Ty.support_renameValues_iff (p : Atom → Prop) (a : Ty) (ξ : Nat → Nat) :
      (a.renameValues ξ).Support p ↔ a.Support p := by
    cases a <;> simp only [Ty.renameValues, Ty.Support, Ty.support_renameValues_iff,
      Ty.supportList_renameValues_iff, Eff.support_renameValues_iff, Tel.support_renameValues_iff]
  theorem Ty.supportList_renameValues_iff (p : Atom → Prop) (as : List Ty) (ξ : Nat → Nat) :
      Ty.SupportList p (renameValueTys ξ as) ↔ Ty.SupportList p as := by
    cases as <;> simp only [renameValueTys, Ty.SupportList, Ty.support_renameValues_iff,
      Ty.supportList_renameValues_iff]
  theorem Eff.support_renameValues_iff (p : Atom → Prop) (e : Eff) (ξ : Nat → Nat) :
      (Eff.renameValues ξ e).Support p ↔ e.Support p := by
    cases e
    simp only [Eff.renameValues, Eff.Support, Ty.supportList_renameValues_iff]
  theorem Tel.support_renameValues_iff (p : Atom → Prop) (t : Tel) (ξ : Nat → Nat) :
      (t.renameValues ξ).Support p ↔ t.Support p := by
    cases t <;> simp only [Tel.renameValues, Tel.Support, Ty.support_renameValues_iff,
      Eff.support_renameValues_iff, Tel.support_renameValues_iff]
end

theorem Ty.support_shiftV_iff (p : Atom → Prop) (a : Ty) (k c : Nat) :
    (a.shiftV k c).Support p ↔ a.Support p := by
  rw [Ty.shiftV_eq_renameValues]; exact Ty.support_renameValues_iff p a _
theorem Eff.support_shiftV_iff (p : Atom → Prop) (e : Eff) (k c : Nat) :
    (Eff.shiftV k c e).Support p ↔ e.Support p := by
  rw [Eff.shiftV_eq_renameValues]; exact Eff.support_renameValues_iff p e _
theorem Ty.supportList_shiftV_iff (p : Atom → Prop) (as : List Ty) (k c : Nat) :
    Ty.SupportList p (shiftVTys k c as) ↔ Ty.SupportList p as := by
  rw [shiftVTys_eq_map, Ty.SupportList.iff, Ty.SupportList.iff]
  simp only [List.mem_map, forall_exists_index, and_imp]
  constructor
  · intro h a ha; exact (Ty.support_shiftV_iff p a k c).mp (h _ a ha rfl)
  · intro h _ a ha he; subst he; exact (Ty.support_shiftV_iff p a k c).mpr (h a ha)

theorem Ty.support_toTel_iff (p : Atom → Prop) (ns : List String) (ps : List Ty) (r : Ty) (e : Eff)
    (hn : NamesWF ns ps) :
    (Ty.toTel ns ps r e).Support p ↔ Ty.SupportList p ps ∧ r.Support p ∧ e.Support p := by
  induction ns generalizing ps r e with
  | nil =>
    cases ps with
    | nil => simp [Ty.toTel, Tel.Support, Ty.SupportList]
    | cons => simp [NamesWF] at hn
  | cons n ns ih =>
    cases ps with
    | nil => simp [NamesWF] at hn
    | cons a ps =>
      have hn' : NamesWF ns (shiftVTys 1 0 ps) :=
        ⟨by simpa [NamesWF] using Nat.succ.inj hn.1, hn.2.of_cons⟩
      simp only [Ty.toTel, Tel.Support, ih _ _ _ hn', Ty.SupportList,
        Ty.supportList_shiftV_iff, Ty.support_shiftV_iff, Eff.support_shiftV_iff, and_assoc]

theorem Ty.support_foldFn_iff (p : Atom → Prop) (t : Tel) :
    (Ty.foldFn t).Support p ↔ t.Support p := by
  classical
  by_cases h : ∃ f : FnView, f.toTel = t
  · obtain ⟨f, rfl⟩ := h
    rw [Ty.foldFn_toTel]
    exact (Ty.support_toTel_iff p f.names f.params f.result f.effect f.names_wf).symm
  · rw [Ty.foldFn_no_view h]; rfl

theorem Ty.support_core_iff (p : Atom → Prop) (a : Ty) : a.core.Support p ↔ a.Support p := by
  cases a <;> try rfl
  case refined a q => exact Ty.support_core_iff p a

theorem Ty.support_refineNorm_iff (p : Atom → Prop) (a : Ty) (q : Pred) :
    (a.refineNorm q).Support p ↔ a.Support p := by
  unfold Ty.refineNorm
  generalize a.refinementPredicates ++ q.conjuncts = ps
  cases ps <;> exact Ty.support_core_iff p a

mutual
  theorem Ty.norm_support {p} (t : Ty) (h : t.Support p) : t.norm.Support p := by
    cases t <;> simp only [Ty.norm, Ty.Support] at h ⊢
    all_goals first
      | trivial
      | exact Ty.norm_support _ h
      | exact Ty.normTys_support _ h
      | skip
    case refined a q => exact (Ty.support_refineNorm_iff p a.norm q).mpr (Ty.norm_support a h)
    case dependentFn t => exact (Ty.support_foldFn_iff p (Tel.norm t)).mpr (Tel.norm_support t h)
    case fn ns ps r e => exact ⟨Ty.normTys_support ps h.1, Ty.norm_support r h.2.1,
      Eff.norm_support e h.2.2⟩
    case cont a b e => exact ⟨Ty.norm_support a h.1, Ty.norm_support b h.2.1,
      Eff.norm_support e h.2.2⟩
    case map a b => exact ⟨Ty.norm_support a h.1, Ty.norm_support b h.2⟩
  theorem Ty.normTys_support {p} (ts : List Ty) (h : Ty.SupportList p ts) :
      Ty.SupportList p (Ty.normTys ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.norm_support t h.1, Ty.normTys_support ts h.2⟩
  theorem Eff.norm_support {p} (e : Eff) (h : Eff.Support p e) : Eff.Support p (Eff.norm e) := by
    cases e with
    | mk a fs =>
      refine ⟨h.1, Ty.SupportList.iff.mpr ?_⟩
      intro t ht
      exact Ty.SupportList.iff.mp (Ty.normTys_support fs h.2) t (Order.mem_sortUnique.mp ht)
  theorem Tel.norm_support {p} (t : Tel) (h : t.Support p) : (Tel.norm t).Support p := by
    cases t with
    | done r e => exact ⟨Ty.norm_support r h.1, Eff.norm_support e h.2⟩
    | param n a t => exact ⟨Ty.norm_support a h.1, Tel.norm_support t h.2⟩
end
mutual
  theorem Ty.rawShift_support {p} (k c : Nat) (t : Ty) (h : t.Support p) :
      (shiftTypes k c t).Support p := by
    cases t <;> simp only [Ty.Support] at h <;> simp only [shiftTypes, Ty.Support]
    all_goals first
      | trivial
      | exact Ty.rawShift_support k c _ h
      | exact Ty.rawShiftTys_support k c _ h
      | exact Tel.rawShift_support k c _ h
      | skip
    case fn ns ps r e => exact ⟨Ty.rawShiftTys_support k c ps h.1,
      Ty.rawShift_support k c r h.2.1, Eff.rawShift_support k c e h.2.2⟩
    case cont a b e => exact ⟨Ty.rawShift_support k c a h.1,
      Ty.rawShift_support k c b h.2.1, Eff.rawShift_support k c e h.2.2⟩
    case map a b => exact ⟨Ty.rawShift_support k c a h.1, Ty.rawShift_support k c b h.2⟩
  theorem Ty.rawShiftTys_support {p} (k c : Nat) (ts : List Ty) (h : Ty.SupportList p ts) :
      Ty.SupportList p (shiftTypesList k c ts) := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨Ty.rawShift_support k c t h.1, Ty.rawShiftTys_support k c ts h.2⟩
  theorem Eff.rawShift_support {p} (k c : Nat) (e : Eff) (h : Eff.Support p e) :
      Eff.Support p (shiftRowsTypes k c e) := by
    cases e with
    | mk a fs => exact ⟨h.1, Ty.rawShiftTys_support k c fs h.2⟩
  theorem Tel.rawShift_support {p} (k c : Nat) (t : Tel) (h : t.Support p) :
      (shiftTelTypes k c t).Support p := by
    cases t with
    | done r e => exact ⟨Ty.rawShift_support k c r h.1, Eff.rawShift_support k c e h.2⟩
    | param n a t => exact ⟨Ty.rawShift_support k c a h.1, Tel.rawShift_support k c t h.2⟩
end

theorem Ty.shift_support {p} (k c : Nat) (t : Ty) (h : t.Support p) :
    (t.shift k c).Support p := by
  simp only [Ty.shift, Ty.bind, Ty.rawBind_shiftTypes]
  exact Ty.norm_support _ (Ty.rawShift_support k c t h)

theorem Eff.shift_support {p} (k c : Nat) (e : Eff) (h : e.Support p) :
    (Eff.shift k c e).Support p := by
  simp only [Eff.shift, Eff.bind, Eff.rawBind_shiftTypes]
  exact Eff.norm_support _ (Eff.rawShift_support k c e h)

def SupportTransport (p q : Atom → Prop) (θ : SubstEnv) : Prop :=
  (∀ i, (θ.types i).Support q) ∧
  (∀ e ∈ θ.rows, e.Support q) ∧
  (∀ a, p a → (Eff.rawBind θ (.mk (fun b => decide (b = a)) [])).Support q)

theorem SupportTransport.up {p q : Atom → Prop} {θ : SubstEnv}
    (h : SupportTransport p q θ) : SupportTransport p q θ.up := by
  refine ⟨fun i => (Ty.support_shiftV_iff q _ 1 0).mpr (h.1 i), ?_, ?_⟩
  · intro e he
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp he
    exact (Eff.support_shiftV_iff q _ 1 0).mpr (h.2.1 f hf)
  · intro a ha
    have he := Eff.rawBind_up (.mk (fun b => decide (b = a)) []) θ
    change Eff.rawBind θ.up (.mk (fun b => decide (b = a)) []) = _ at he
    rw [he]
    exact (Eff.support_shiftV_iff q _ 1 0).mpr (h.2.2 a ha)

theorem rawApply_support {p : Atom → Prop} (a : Ty) (as : List Ty)
    (h : a.Support p) (hs : Ty.SupportList p as) : (rawApply a as).Support p := by
  cases a <;> try exact h
  case tvar i => exact hs
  case refined a q => exact rawApply_support a as h hs
  case ctor c =>
    cases c <;> cases as <;> simp_all [rawApply, Ty.Support, Ty.SupportList]
    all_goals rename_i as; cases as <;> simp_all [Ty.Support, Ty.SupportList]

mutual
  theorem Ty.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (a : Ty)
      (h : a.Support p) (ht : SupportTransport p q θ) : (a.rawBind θ).Support q := by
    cases a <;> simp only [Ty.Support] at h <;> simp only [Ty.rawBind, Ty.Support]
    all_goals first
      | trivial
      | exact Ty.rawBind_support p q θ _ h ht
      | exact Ty.rawBindTys_support p q θ _ h ht
      | exact Tel.rawBind_support p q θ _ h ht
      | skip
    case tvar i => exact ht.1 i
    case fn ns ps r e => exact ⟨Ty.rawBindTys_support p q θ ps h.1 ht,
      Ty.rawBind_support p q θ r h.2.1 ht, Eff.rawBind_support p q θ e h.2.2 ht⟩
    case cont a b e => exact ⟨Ty.rawBind_support p q θ a h.1 ht,
      Ty.rawBind_support p q θ b h.2.1 ht, Eff.rawBind_support p q θ e h.2.2 ht⟩
    case map a b => exact ⟨Ty.rawBind_support p q θ a h.1 ht, Ty.rawBind_support p q θ b h.2 ht⟩
    case tapp i as => exact rawApply_support _ _ (ht.1 i) (Ty.rawBindTys_support p q θ as h ht)
  theorem Ty.rawBindTys_support (p q : Atom → Prop) (θ : SubstEnv) (as : List Ty)
      (h : Ty.SupportList p as) (ht : SupportTransport p q θ) :
      Ty.SupportList q (rawBindTys θ as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.rawBind_support p q θ a h.1 ht, Ty.rawBindTys_support p q θ as h.2 ht⟩
  theorem Eff.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (e : Eff)
      (h : e.Support p) (ht : SupportTransport p q θ) : (Eff.rawBind θ e).Support q := by
    rw [Eff.support_iff]
    constructor
    · intro a ha
      rcases (Eff.mem_rawBind θ e a).mp ha with ⟨b, hb, he, hi⟩ | ⟨i, f, hf, _, hm⟩
      · apply (ht.2.2 b (((Eff.support_iff e).mp h).1 b hb)).1 a
        exact (Eff.mem_rawBind θ (.mk (fun x => decide (x = b)) []) a).mpr
          (Or.inl ⟨b, by simp [Eff.mem, Eff.test, Eff.atoms], he, hi⟩)
      · exact ((Eff.support_iff f).mp (ht.2.1 f (List.mem_of_getElem? hf))).1 a hm
    · cases e with
      | mk a fs =>
        apply Ty.SupportList.iff.mpr
        intro t hm
        rcases List.mem_append.mp hm with hm | hm
        · exact Ty.SupportList.iff.mp (Ty.rawBindTys_support p q θ fs h.2 ht) t hm
        · obtain ⟨i, f, hf, _, hm⟩ := Eff.mem_rowFails.mp hm
          exact Ty.SupportList.iff.mp ((Eff.support_iff f).mp (ht.2.1 f (List.mem_of_getElem? hf))).2 t hm
  theorem Tel.rawBind_support (p q : Atom → Prop) (θ : SubstEnv) (t : Tel)
      (h : t.Support p) (ht : SupportTransport p q θ) : (Tel.rawBind θ t).Support q := by
    cases t with
    | done r e => exact ⟨Ty.rawBind_support p q θ r h.1 ht, Eff.rawBind_support p q θ e h.2 ht⟩
    | param n a t => exact ⟨Ty.rawBind_support p q θ a h.1 ht, Tel.rawBind_support p q θ.up t h.2 ht.up⟩
end

theorem typeEnvAt_support (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ a ∈ ts, a.Support q) (he : ∀ e ∈ es, e.Support q)
    (ha : ∀ a, p a → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q) :
    SupportTransport p q (typeEnvAt c ts es) := by
  refine ⟨?_, ?_, ha⟩
  · intro i
    simp only [typeEnvAt]
    split
    · trivial
    · split
      · apply Ty.rawShift_support
        cases hi : ts[i-c]? with
        | none => trivial
        | some a => exact ht a (List.mem_of_getElem? hi)
      · trivial
  · intro e hm
    obtain ⟨f, hf, rfl⟩ := List.mem_map.mp hm
    exact Eff.rawShift_support c 0 f (he f hf)

theorem Ty.substAt_support (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q)
    (ha : ∀ x, p x → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = x)) [])).Support q) :
    (a.substAt c ts es).Support q :=
  Ty.norm_support _ (Ty.rawBind_support p q _ a h (typeEnvAt_support p q c ts es ht he ha))

theorem Eff.substAt_support (p q : Atom → Prop) (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q)
    (ha : ∀ x, p x → (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = x)) [])).Support q) :
    (Eff.substAt c ts es a).Support q :=
  Eff.norm_support _ (Eff.rawBind_support p q _ a h (typeEnvAt_support p q c ts es ht he ha))

/-- 候補を広げるだけの場合、単一原子の像の条件は行の像から導ける。 -/
theorem typeEnvAt_atom {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (he : ∀ e ∈ es, e.Support q) (hpq : ∀ x, p x → q x) (a : Atom) (ha : p a) :
    (Eff.rawBind (typeEnvAt c ts es) (.mk (fun b => decide (b = a)) [])).Support q := by
  have hrows : ∀ f ∈ (typeEnvAt c ts es).rows, f.Support q := by
    intro f hf
    obtain ⟨g, hg, rfl⟩ := List.mem_map.mp hf
    exact Eff.rawShift_support c 0 g (he g hg)
  rw [Eff.support_iff]
  constructor
  · intro x hx
    rcases (Eff.mem_rawBind _ _ x).mp hx with ⟨b, hb, hi, _⟩ | ⟨i, f, hf, _, hm⟩
    · have hba : b = a := of_decide_eq_true hb
      subst hba
      have : b.instR (typeEnvAt c ts es).ranges = b := by
        rcases b with ⟨l, r | i⟩ | i <;> simp [typeEnvAt, Atom.instR, RangeIx.inst]
      rw [this] at hi
      exact hi ▸ hpq b ha
    · exact ((Eff.support_iff f).mp (hrows f (List.mem_of_getElem? hf))).1 x hm
  · apply Ty.SupportList.iff.mpr
    intro t hm
    rcases List.mem_append.mp hm with hm | hm
    · cases hm
    · obtain ⟨i, f, hf, _, hm⟩ := Eff.mem_rowFails.mp hm
      exact Ty.SupportList.iff.mp ((Eff.support_iff f).mp (hrows f (List.mem_of_getElem? hf))).2 t hm


/-- 型・行の有限置換では、原子の条件を支持述語の包含から供給できる。 -/
theorem typeEnvAt_support_of_imp {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q) (hpq : ∀ x, p x → q x) :
    SupportTransport p q (typeEnvAt c ts es) :=
  typeEnvAt_support p q c ts es ht he (typeEnvAt_atom c ts es he hpq)

theorem Ty.substAt_support_of_imp {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q)
    (hpq : ∀ x, p x → q x) : (a.substAt c ts es).Support q :=
  Ty.substAt_support p q c ts es a h ht he (typeEnvAt_atom c ts es he hpq)

theorem Eff.substAt_support_of_imp {p q : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support q) (he : ∀ e ∈ es, e.Support q)
    (hpq : ∀ x, p x → q x) : (Eff.substAt c ts es a).Support q :=
  Eff.substAt_support p q c ts es a h ht he (typeEnvAt_atom c ts es he hpq)

theorem Ty.substAt_support_same {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Ty) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, e.Support p) :
    (a.substAt c ts es).Support p := Ty.substAt_support_of_imp c ts es a h ht he (fun _ => id)

theorem Eff.substAt_support_same {p : Atom → Prop} (c : Nat) (ts : List Ty) (es : List Eff)
    (a : Eff) (h : a.Support p) (ht : ∀ t ∈ ts, t.Support p) (he : ∀ e ∈ es, e.Support p) :
    (Eff.substAt c ts es a).Support p := Eff.substAt_support_of_imp c ts es a h ht he (fun _ => id)

end Benitoite.Release.Refinement
