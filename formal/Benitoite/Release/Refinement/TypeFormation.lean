import Benitoite.Release.Refinement.VarianceTransport
import Benitoite.Release.Refinement.TypeShiftAlgebra

namespace Benitoite.Release.Refinement
set_option maxHeartbeats 2000000

/-- 値型だけの型パラメータを具体化する環境。値・行・範囲を置き換えない。 -/
def SubstEnv.typesOnly (f : Nat → Ty) : SubstEnv := ⟨f, [], [], fun i => some (.var i)⟩

@[simp] theorem SubstEnv.typesOnly_up (f : Nat → Ty) :
    (SubstEnv.typesOnly f).up = SubstEnv.typesOnly (fun i => (f i).shiftV 1 0) := by
  simp only [SubstEnv.up, SubstEnv.typesOnly, List.map_nil, upValues_id]

mutual
  /-- 型構成子変数の適用を含まない。固定した型構成子そのものは含んでよい。 -/
  def Ty.NoTapp : Ty → Prop
    | .tapp _ _ => False
    | .data _ as | .external _ as => noTappTys as
    | .list a | .lazy a | .reference a | .set a | .dict _ a | .refined a _ => a.NoTapp
    | .map a b => a.NoTapp ∧ b.NoTapp
    | .fn _ ps r e => noTappTys ps ∧ r.NoTapp ∧ noTappEff e
    | .cont a b e => a.NoTapp ∧ b.NoTapp ∧ noTappEff e
    | .dependentFn t => noTappTel t
    | _ => True
  def noTappTys : List Ty → Prop
    | [] => True
    | a :: as => a.NoTapp ∧ noTappTys as
  def noTappEff : Eff → Prop
    | .mk _ fs => noTappTys fs
  def noTappTel : Tel → Prop
    | .done r e => r.NoTapp ∧ noTappEff e
    | .param _ a t => a.NoTapp ∧ noTappTel t
end

mutual
  theorem Ty.HasKind.noTapp {P n a k} (h : Ty.HasKind P (List.replicate n .value) a k) : a.NoTapp := by
    cases k with
    | constructor m =>
      cases a <;> simp only [Ty.HasKind] at h <;> try contradiction
      all_goals trivial
    | value =>
      cases a <;> simp only [Ty.HasKind] at h <;> simp only [Ty.NoTapp]
      all_goals first | trivial | exact Ty.HasKind.noTapp h | exact noTapp_kindsList h | exact noTapp_kindsTel h | skip
      case data _ _ => exact noTapp_kindsList h.2
      case fn _ _ _ _ => exact ⟨noTapp_kindsList h.2.1, Ty.HasKind.noTapp h.2.2.1, noTapp_kindsEff h.2.2.2⟩
      case cont _ _ _ => exact ⟨Ty.HasKind.noTapp h.1, Ty.HasKind.noTapp h.2.1, noTapp_kindsEff h.2.2⟩
      case map _ _ => exact ⟨Ty.HasKind.noTapp h.1, Ty.HasKind.noTapp h.2⟩
      case dict _ _ => obtain ⟨_,_,hk⟩ := h; exact Ty.HasKind.noTapp hk
      case refined _ _ => exact Ty.HasKind.noTapp h.1
      case tapp _ _ =>
        simp only [List.getElem?_replicate] at h
        split at h <;> simp_all
  theorem noTapp_kindsList {P n as} (h : kindsList P (List.replicate n .value) as) : noTappTys as := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.HasKind.noTapp h.1, noTapp_kindsList h.2⟩
  theorem noTapp_kindsEff {P n e} (h : kindsEff P (List.replicate n .value) e) : noTappEff e := by
    cases e; exact noTapp_kindsList h
  theorem noTapp_kindsTel {P n t} (h : kindsTel P (List.replicate n .value) t) : noTappTel t := by
    cases t with
    | done r e => exact ⟨Ty.HasKind.noTapp h.1, noTapp_kindsEff h.2⟩
    | param _ a t => exact ⟨Ty.HasKind.noTapp h.1, noTapp_kindsTel h.2⟩
end

mutual
  theorem Ty.rawBind_typesOnly_comp {a : Ty} (ha : a.NoTapp) (f g : Nat → Ty) :
      (a.rawBind (.typesOnly f)).rawBind (.typesOnly g) =
        a.rawBind (.typesOnly (fun i => (f i).rawBind (.typesOnly g))) := by
    cases a <;> simp only [Ty.NoTapp] at ha <;> simp only [Ty.rawBind]
    all_goals try rfl
    case «opaque» _ _ => simp [SubstEnv.typesOnly, RangeIx.inst_nil]
    case «scoped» _ _ _ => simp [SubstEnv.typesOnly, RangeIx.inst_nil]
    case data _ _ => rw [rawBindTys_typesOnly_comp ha]
    case external _ _ => rw [rawBindTys_typesOnly_comp ha]
    case fn _ _ _ _ => rw [rawBindTys_typesOnly_comp ha.1, Ty.rawBind_typesOnly_comp ha.2.1, Eff.rawBind_typesOnly_comp ha.2.2]
    case cont _ _ _ => rw [Ty.rawBind_typesOnly_comp ha.1, Ty.rawBind_typesOnly_comp ha.2.1, Eff.rawBind_typesOnly_comp ha.2.2]
    case map _ _ => rw [Ty.rawBind_typesOnly_comp ha.1, Ty.rawBind_typesOnly_comp ha.2]
    case dependentFn _ => rw [Tel.rawBind_typesOnly_comp ha]
    case refined a p =>
      simp only [SubstEnv.typesOnly, upValues_id, predBind_id]
      exact congrArg (fun a => Ty.refined a p) (Ty.rawBind_typesOnly_comp ha f g)
    all_goals rw [Ty.rawBind_typesOnly_comp ha]
  theorem rawBindTys_typesOnly_comp {as} (ha : noTappTys as) (f g : Nat → Ty) :
      rawBindTys (.typesOnly g) (rawBindTys (.typesOnly f) as) =
        rawBindTys (.typesOnly (fun i => (f i).rawBind (.typesOnly g))) as := by
    cases as with
    | nil => rfl
    | cons a as => simp only [rawBindTys, Ty.rawBind_typesOnly_comp ha.1, rawBindTys_typesOnly_comp ha.2]
  theorem Eff.rawBind_typesOnly_comp {e} (ha : noTappEff e) (f g : Nat → Ty) :
      Eff.rawBind (.typesOnly g) (Eff.rawBind (.typesOnly f) e) =
        Eff.rawBind (.typesOnly (fun i => (f i).rawBind (.typesOnly g))) e := by
    cases e with
    | mk at' fs =>
      simp only [Eff.rawBind, SubstEnv.typesOnly, instAtoms_nil, substAtoms_nil,
        rowFails, List.length_nil, List.range_zero, List.filter_nil, List.flatMap_nil, List.append_nil]
      change EffR.mk _ (rawBindTys (.typesOnly g) (rawBindTys (.typesOnly f) fs)) = _
      rw [rawBindTys_typesOnly_comp ha]
      rfl
  theorem Tel.rawBind_typesOnly_comp {t} (ha : noTappTel t) (f g : Nat → Ty) :
      Tel.rawBind (.typesOnly g) (Tel.rawBind (.typesOnly f) t) =
        Tel.rawBind (.typesOnly (fun i => (f i).rawBind (.typesOnly g))) t := by
    cases t with
    | done r e => simp only [Tel.rawBind, Ty.rawBind_typesOnly_comp ha.1, Eff.rawBind_typesOnly_comp ha.2]
    | param n a t =>
      simp only [Tel.rawBind, SubstEnv.typesOnly_up, Ty.rawBind_typesOnly_comp ha.1,
        Tel.rawBind_typesOnly_comp ha.2]
      congr 2
      apply congrArg SubstEnv.typesOnly
      funext i
      simpa only [SubstEnv.typesOnly_up] using Ty.rawBind_up (f i) (.typesOnly g)
end

@[simp] theorem typeEnvAt_zero_eq_typesOnly (ts : List Ty) :
    typeEnvAt 0 ts [] = SubstEnv.typesOnly (fun i =>
      if i < ts.length then ts[i]?.getD (.tvar i) else .tvar (i-ts.length)) := by
  simp [typeEnvAt, SubstEnv.typesOnly, shiftTypes_zero]

/-- 総称の欄に二度型を代入する場合。値・行・範囲の名前空間は保つ。 -/
theorem Ty.subst_typesOnly_closed {n : Nat} {a : Ty} (hw : a.WF 0 n 0) (ha : a.NoTapp)
    (xs : List Ty) (hn : n ≤ xs.length) (f : Nat → Ty) :
    (a.subst xs []).bind (.typesOnly f) = a.subst (xs.map (Ty.bind (.typesOnly f))) [] := by
  have hm : xs.map (Ty.bind (.typesOnly f)) = Ty.normTys (rawBindTys (.typesOnly f) xs) := by
    simp only [rawBindTys_eq_map, Ty.normTys_eq_map, List.map_map]
    rfl
  rw [hm, Ty.subst_norm_images]
  change (Ty.rawBind (.typesOnly f) (a.rawBind (typeEnvAt 0 xs [])).norm).norm =
    (a.rawBind (typeEnvAt 0 (rawBindTys (.typesOnly f) xs) [])).norm
  rw [Ty.norm_rawBind, typeEnvAt_zero_eq_typesOnly, Ty.rawBind_typesOnly_comp ha]
  congr 1
  apply Ty.rawBind_agrees hw
  refine ⟨?_, rfl, rfl, rfl⟩
  intro i hi
  have hl : i < xs.length := by omega
  simp only [SubstEnv.typesOnly, typeEnvAt, Nat.not_lt_zero, ↓reduceIte, Nat.sub_zero,
    rawBindTys_eq_map, List.length_map, List.getElem?_map, hl]
  have hx := List.getElem?_eq_getElem hl
  simp [hx, shiftTypes_zero]

mutual
  @[simp] theorem Ty.observationType_idem (a : Ty) : a.observationType.observationType = a.observationType := by
    cases a <;> simp only [Ty.observationType, observationTypes_idem, Ty.observationType_idem]
  @[simp] theorem observationTypes_idem (as : List Ty) : observationTypes (observationTypes as) = observationTypes as := by
    cases as <;> simp only [observationTypes, Ty.observationType_idem, observationTypes_idem]
end

@[simp] theorem Ty.observationType_ordinary (a : Ty) : Ordinary a.observationType ↔ Ordinary a := by
  cases a <;> simp only [Ty.observationType, Ty.Ordinary, Benitoite.Release.Refinement.Ordinary, Ty.core]
  case refined a p => exact Ty.observationType_ordinary a
  all_goals simp

private theorem observationType_rawApply (a : Ty) (as : List Ty) :
    (rawApply a as).observationType =
      (rawApply a.observationType (observationTypes as)).observationType := by
  cases a <;> try rfl
  case ctor c => cases c <;> simp [rawApply, Ty.observationType]
  case tvar i => simp [rawApply, Ty.observationType]
  case data d xs => simp [rawApply, Ty.observationType]
  case refined a p => exact observationType_rawApply a as
  case tapp i xs => simp [rawApply, Ty.observationType]

private theorem observationType_rawApply_args (a : Ty) (as : List Ty) :
    (rawApply a (observationTypes as)).observationType = (rawApply a as).observationType := by
  cases a <;> try rfl
  case ctor c => cases c <;> simp [rawApply, Ty.observationType]
  case tvar i => simp [rawApply, Ty.observationType]
  case refined a p => exact observationType_rawApply_args a as

mutual
  theorem Ty.observationType_rawBind_typesOnly (a : Ty) (f : Nat → Ty) :
      (a.rawBind (.typesOnly f)).observationType =
        (a.observationType.rawBind (.typesOnly (fun i => (f i).observationType))).observationType := by
    cases a <;> simp only [Ty.rawBind, Ty.observationType]
    all_goals try rfl
    case tvar i => exact (Ty.observationType_idem (f i)).symm
    case data d as => rw [observationTypes_rawBind_typesOnly]
    case refined a p => exact Ty.observationType_rawBind_typesOnly a f
    case tapp i as =>
      change (rawApply (f i) (rawBindTys (.typesOnly f) as)).observationType = _
      rw [observationType_rawApply]
      change (rawApply (f i).observationType (observationTypes (rawBindTys (.typesOnly f) as))).observationType = _
      rw [observationTypes_rawBind_typesOnly]
      exact observationType_rawApply_args _ _
  theorem observationTypes_rawBind_typesOnly (as : List Ty) (f : Nat → Ty) :
      observationTypes (rawBindTys (.typesOnly f) as) =
        observationTypes (rawBindTys (.typesOnly (fun i => (f i).observationType)) (observationTypes as)) := by
    cases as with
    | nil => rfl
    | cons a as =>
      simp only [rawBindTys, observationTypes]
      rw [Ty.observationType_rawBind_typesOnly a f, observationTypes_rawBind_typesOnly as f]
end

theorem DataObservationLe.bind_typesOnly {P d as bs} (h : DataObservationLe P d as bs)
    (f : Nat → Ty) (ho : ∀ i, Ordinary (f i)) :
    DataObservationLe P d (as.map (Ty.bind (.typesOnly f))) (bs.map (Ty.bind (.typesOnly f))) := by
  have hh := TypeArgsLe.rawBind h (.typesOnly (fun i => (f i).observationType))
    (Transport.types [] [] _ rfl (fun i => (Ty.observationType_ordinary _).mpr (ho i)))
  have hh := hh.observationType
  simp only [DataObservationLe, List.length_map,
    observationTypes_eq_map, rawBindTys_eq_map, List.map_map, Function.comp_def,
    Ty.bind, Ty.observationType_norm] at hh ⊢
  have hs := observationTypes_rawBind_typesOnly as f
  have ht := observationTypes_rawBind_typesOnly bs f
  simp only [observationTypes_eq_map, rawBindTys_eq_map, List.map_map, Function.comp_def] at hs ht
  rw [hs, ht]
  exact hh

/-- 値の位置を保ち、文脈中の型だけを具体化する。 -/
structure TypeFormationMap (Γ Δ : Ctx) (f : Nat → Ty) : Prop where
  lookup : ∀ (i : Nat) (a : Ty), Γ[i]? = some (some a) → Δ[i]? = some (some (a.rawBind (.typesOnly f)))
  ordinary : ∀ i, Ordinary (f i)

theorem TypeFormationMap.sortMap {Γ Δ f} (h : TypeFormationMap Γ Δ f) : SortMap Γ Δ := by
  constructor
  intro i a hi
  exact ⟨_, h.lookup i a hi, fun _ hs => Ty.hasSort_rawBind hs _, fun ho => Ty.ordinary_rawBind ho _ h.ordinary⟩

theorem TypeFormationMap.extend {Γ Δ f} (h : TypeFormationMap Γ Δ f) (a : Ty) :
    TypeFormationMap (Γ.extend a) (Δ.extend (a.rawBind (.typesOnly f))) (fun i => (f i).shiftV 1 0) := by
  constructor
  · intro i b hi
    cases i with
    | zero =>
      cases Option.some.inj hi
      simpa only [Ctx.extend, List.getElem?_cons_zero, SubstEnv.typesOnly_up] using congrArg (fun a => some (some a)) (Ty.rawBind_up a (.typesOnly f)).symm
    | succ i =>
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, Option.map_eq_some_iff] at hi
      obtain ⟨_, hx, x, rfl, rfl⟩ := hi
      simp only [Ctx.extend, List.getElem?_cons_succ, List.getElem?_map, h.lookup i x hx, Option.map_some]
      simp only [← SubstEnv.typesOnly_up, Ty.rawBind_up]
  · intro i; exact (Ty.ordinary_shiftV _ _ _).mpr (h.ordinary i)

theorem Ty.Annotation.shift_outer {P C Γ a} (h : Ty.Annotation P C Γ a) (b : Ty) :
    Ty.Annotation P C (Γ.extend b) (a.shiftV 1 0) := by
  refine ⟨?_, ?_, ?_⟩
  · simpa only [Ctx.extend, List.length_cons, List.length_map] using Ty.wf_shiftV h.wf 1 0
  · apply (Ty.sorted_shiftV h.sorted 1 0).sortMap
    constructor
    intro i a hi
    cases i with
    | zero => simp [Ctx.shiftV] at hi
    | succ i => exact ⟨a, hi, fun _ hs => hs, fun ho => ho⟩
  · rw [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
    exact h.declared.rawSubstV (DeclarationRenaming.outer Γ b).images

private theorem wfList_sortUnique_types {nt nv : Nat} {as : List Ty} (h : Ty.WFList 0 nt nv as) :
    Ty.WFList 0 nt nv (Order.sortUnique tyCompare as) := by
  rw [Ty.wfList_iff] at h ⊢
  exact fun a ha => h a (Order.mem_sortUnique.mp ha)

mutual
  theorem Ty.wf_typesOnly {a : Ty} {n nv nt mv : Nat} (hw : a.WF 0 n nv) (ha : a.NoTapp)
      (f : Nat → Ty) (hnv : nv ≤ mv) (hf : ∀ i, i < n → (f i).WF 0 nt mv)
      (ho : ∀ i, Ordinary (f i)) : (a.rawBind (.typesOnly f)).norm.WF 0 nt mv := by
    cases a <;> simp only [Ty.WF] at hw <;> simp only [Ty.NoTapp] at ha <;>
      simp only [Ty.rawBind, Ty.norm, Ty.WF]
    all_goals first | trivial | exact Ty.wf_typesOnly hw ha f hnv hf ho | exact wfTys_typesOnly hw ha f hnv hf ho | skip
    case «opaque» _ _ => simpa [SubstEnv.typesOnly, RangeIx.inst_nil] using hw
    case «scoped» _ _ _ => simpa [SubstEnv.typesOnly, RangeIx.inst_nil] using hw
    case fn ns ps r e => exact ⟨by simpa only [NamesWF, rawBindTys_eq_map, Ty.normTys_eq_map, List.length_map] using hw.1,
      wfTys_typesOnly hw.2.1 ha.1 f hnv hf ho, Ty.wf_typesOnly hw.2.2.1 ha.2.1 f hnv hf ho,
      wfEff_typesOnly hw.2.2.2.1 ha.2.2 f hnv hf ho, Eff.norm_idem _⟩
    case tvar i => exact Ty.wf_norm (hf i hw)
    case cont a b e => exact ⟨Ty.wf_typesOnly hw.1 ha.1 f hnv hf ho,
      Ty.wf_typesOnly hw.2.1 ha.2.1 f hnv hf ho, wfEff_typesOnly hw.2.2.1 ha.2.2 f hnv hf ho, Eff.norm_idem _⟩
    case map a b => exact ⟨Ty.wf_typesOnly hw.1 ha.1 f hnv hf ho, Ty.wf_typesOnly hw.2 ha.2 f hnv hf ho⟩
    case refined a p =>
      simp only [SubstEnv.typesOnly, upValues_id, predBind_id]
      apply Ty.wf_refineNorm (Ty.wf_typesOnly hw.1 ha f hnv hf ho)
      · exact Pred.varsIn_mono hw.2.1 (by intro i hi; omega)
      · exact (Ty.ordinary_norm _).mpr (Ty.ordinary_rawBind hw.2.2 _ ho)
    case dependentFn t => exact Ty.wf_foldFn (wfTel_typesOnly hw ha f hnv hf ho)
  theorem wfTys_typesOnly {as : List Ty} {n nv nt mv : Nat} (hw : Ty.WFList 0 n nv as) (ha : noTappTys as)
      (f : Nat → Ty) (hnv : nv ≤ mv) (hf : ∀ i, i < n → (f i).WF 0 nt mv)
      (ho : ∀ i, Ordinary (f i)) : Ty.WFList 0 nt mv (Ty.normTys (rawBindTys (.typesOnly f) as)) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.wf_typesOnly hw.1 ha.1 f hnv hf ho, wfTys_typesOnly hw.2 ha.2 f hnv hf ho⟩
  theorem wfEff_typesOnly {e : Eff} {n nv nt mv : Nat} (hw : e.WF 0 n nv) (ha : noTappEff e)
      (f : Nat → Ty) (hnv : nv ≤ mv) (hf : ∀ i, i < n → (f i).WF 0 nt mv)
      (ho : ∀ i, Ordinary (f i)) : (Eff.rawBind (.typesOnly f) e).norm.WF 0 nt mv := by
    cases e with
    | mk at' fs =>
      simp only [Eff.rawBind, SubstEnv.typesOnly, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil, Eff.norm, Eff.WF]
      exact wfList_sortUnique_types (wfTys_typesOnly hw ha f hnv hf ho)
  theorem wfTel_typesOnly {t : Tel} {n nv nt mv : Nat} (hw : Tel.WF 0 n nv t) (ha : noTappTel t)
      (f : Nat → Ty) (hnv : nv ≤ mv) (hf : ∀ i, i < n → (f i).WF 0 nt mv)
      (ho : ∀ i, Ordinary (f i)) : Tel.WF 0 nt mv (Tel.norm (Tel.rawBind (.typesOnly f) t)) := by
    cases t with
    | done r e => exact ⟨Ty.wf_typesOnly hw.1 ha.1 f hnv hf ho, wfEff_typesOnly hw.2.1 ha.2 f hnv hf ho, Eff.norm_idem _⟩
    | param _ a t =>
      refine ⟨Ty.wf_typesOnly hw.1 ha.1 f hnv hf ho, ?_⟩
      simp only [SubstEnv.typesOnly_up]
      apply wfTel_typesOnly hw.2 ha.2 _ (by omega)
      · intro i hi; exact Ty.wf_shiftV (hf i hi) 1 0
      · intro i; exact (Ty.ordinary_shiftV _ _ _).mpr (ho i)
end

theorem Ty.Sorted.shift_outer {Γ a} (h : Ty.Sorted Γ a) (b : Ty) : (a.shiftV 1 0).Sorted (Γ.extend b) := by
  apply (Ty.sorted_shiftV h 1 0).sortMap
  constructor
  intro i a hi
  cases i with
  | zero => simp [Ctx.shiftV] at hi
  | succ i => exact ⟨a, hi, fun _ hs => hs, fun ho => ho⟩

mutual
  theorem Ty.Sorted.typesOnly {Γ Δ a f} (h : Ty.Sorted Γ a) (ha : a.NoTapp)
      (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, (f i).Sorted Δ) : (a.rawBind (.typesOnly f)).Sorted Δ := by
    cases a <;> simp only [Ty.Sorted] at h <;> simp only [Ty.NoTapp] at ha <;> simp only [Ty.rawBind, Ty.Sorted]
    all_goals first | trivial | exact Ty.Sorted.typesOnly h ha hm hf | exact sortedTys_typesOnly h ha hm hf | skip
    case fn _ _ _ _ => exact ⟨sortedTys_typesOnly h.1 ha.1 hm hf, Ty.Sorted.typesOnly h.2.1 ha.2.1 hm hf, sortedEff_typesOnly h.2.2 ha.2.2 hm hf⟩
    case tvar i => exact hf i
    case cont _ _ _ => exact ⟨Ty.Sorted.typesOnly h.1 ha.1 hm hf, Ty.Sorted.typesOnly h.2.1 ha.2.1 hm hf, sortedEff_typesOnly h.2.2 ha.2.2 hm hf⟩
    case map _ _ => exact ⟨Ty.Sorted.typesOnly h.1 ha.1 hm hf, Ty.Sorted.typesOnly h.2 ha.2 hm hf⟩
    case refined a p =>
      refine ⟨Ty.Sorted.typesOnly h.1 ha hm hf, ?_⟩
      simp only [SubstEnv.typesOnly, upValues_id, predBind_id]
      exact Pred.Sorted.sortMap hm.sortMap h.2 (fun _ hs => Ty.hasSort_rawBind hs _) (fun ho => Ty.ordinary_rawBind ho _ hm.ordinary)
    case dependentFn _ => exact sortedTel_typesOnly h ha hm hf
  theorem sortedTys_typesOnly {Γ Δ as f} (h : sortedTys Γ as) (ha : noTappTys as)
      (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, (f i).Sorted Δ) : sortedTys Δ (rawBindTys (.typesOnly f) as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Sorted.typesOnly h.1 ha.1 hm hf, sortedTys_typesOnly h.2 ha.2 hm hf⟩
  theorem sortedEff_typesOnly {Γ Δ e f} (h : sortedEff Γ e) (ha : noTappEff e)
      (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, (f i).Sorted Δ) : sortedEff Δ (Eff.rawBind (.typesOnly f) e) := by
    cases e with
    | mk at' fs =>
      simp only [Eff.rawBind, SubstEnv.typesOnly, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil, sortedEff]
      exact sortedTys_typesOnly h ha hm hf
  theorem sortedTel_typesOnly {Γ Δ t f} (h : Tel.Sorted Γ t) (ha : noTappTel t)
      (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, (f i).Sorted Δ) : Tel.Sorted Δ (Tel.rawBind (.typesOnly f) t) := by
    cases t with
    | done r e => exact ⟨Ty.Sorted.typesOnly h.1 ha.1 hm hf, sortedEff_typesOnly h.2 ha.2 hm hf⟩
    | param _ a t =>
      refine ⟨Ty.Sorted.typesOnly h.1 ha.1 hm hf, ?_⟩
      simp only [SubstEnv.typesOnly_up]
      exact sortedTel_typesOnly h.2 ha.2 (hm.extend a) (fun i => (hf i).shift_outer _)
end

theorem Ty.dataCore_typesOnly {a : Ty} {d xs} (h : a.norm.core = .data d xs) (f : Nat → Ty) :
    (a.rawBind (.typesOnly f)).norm.core = .data d (xs.map (Ty.bind (.typesOnly f))) := by
  cases a <;> simp only [Ty.norm, Ty.core] at h
  case data d as =>
    cases h
    simp only [Ty.rawBind, Ty.norm, Ty.core, Ty.normTys_eq_map, rawBindTys_eq_map, List.map_map, Function.comp_def]
    congr 2
    funext a
    exact (Ty.norm_rawBind _ a).symm
  case refined a p =>
    simp only [Ty.core_refineNorm] at h
    simpa only [Ty.rawBind, Ty.norm, Ty.core_refineNorm] using Ty.dataCore_typesOnly h f
  case dependentFn t => exact False.elim (Ty.notDataCore_dependentFn h)
  all_goals cases h

/-- 型置換は widen の観測の対応を再び射影して保つ。 -/
theorem Term.HasData.typesOnly {P Γ Δ t d xs f} (h : Term.HasData P Γ t d xs)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) :
    Term.HasData P Δ t d (xs.map (Ty.bind (.typesOnly f))) := by
  match h with
  | .widen hr hs => exact .widen (hr.typesOnly valid hm) (hs.bind_typesOnly f hm.ordinary)
  | .var hi hd => exact .var (hm.lookup _ _ hi) (Ty.dataCore_typesOnly hd f)
  | .value hc hd hn hl => exact .value hc hd (by simpa only [List.length_map] using hn) hl
  | .field (ts := ts) hr hc hd hn ha hw hs hv =>
    have hk := ((valid.2 _ _ hc).2 _ (List.mem_of_getElem? ha)).2.1
    have he := Ty.subst_typesOnly_closed hw hk.noTapp ts (by omega) f
    refine .field (hr.typesOnly valid hm) hc hd (by simpa only [List.length_map] using hn) ha hw ?_ ?_
    · rw [← he]; exact Ty.hasSort_bind hs _
    · rw [← he]
      simpa only [Ty.bind, Ty.norm_idem] using Ty.dataCore_typesOnly hv f

theorem FieldRef.Declared.typesOnly {P C D Γ Δ t ref f} (h : FieldRef.Declared P C Γ t ref)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) : FieldRef.Declared P D Δ t ref := by
  obtain ⟨xs, cd, a, ht, hc, hd, hn, ha, hw, hs⟩ := h
  have hk := ((valid.2 _ _ hc).2 _ (List.mem_of_getElem? ha)).2.1
  refine ⟨xs.map (Ty.bind (.typesOnly f)), cd, a, ht.typesOnly valid hm, hc, hd, ?_, ha, hw, ?_⟩
  · simpa only [List.length_map] using hn
  · rw [← Ty.subst_typesOnly_closed hw hk.noTapp _ (by omega) f]
    exact Ty.hasSort_bind hs _

mutual
  theorem Term.Declared.typesOnly {P C D Γ Δ t f} (h : Term.Declared P C Γ t)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) : Term.Declared P D Δ t := by
    cases t <;> simp only [Term.Declared] at h ⊢
    all_goals first | trivial | exact Term.Declared.typesOnly h valid hm | skip
    case var i =>
      obtain ⟨a, hi, ho⟩ := h
      exact ⟨_, hm.lookup i a hi, Ty.ordinary_rawBind ho _ hm.ordinary⟩
    case field ref t => exact ⟨Term.Declared.typesOnly h.1 valid hm, FieldRef.Declared.typesOnly h.2 valid hm⟩
    case add a b => exact ⟨Term.Declared.typesOnly h.1 valid hm, Term.Declared.typesOnly h.2 valid hm⟩
    case listValue _ => exact declaredSlots_typesOnly h valid hm
    case setValue _ => exact declaredSlots_typesOnly h valid hm
    case mapValue _ _ => exact ⟨declaredSlots_typesOnly h.1 valid hm, declaredSlots_typesOnly h.2 valid hm⟩
    case dataValue _ _ => exact ⟨declaredSlots_typesOnly h.1 valid hm, h.2⟩
  theorem declaredSlot_typesOnly {P C D Γ Δ t f} (h : declaredSlot P C Γ t)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) : declaredSlot P D Δ t := by
    cases t with
    | none => trivial
    | some t => exact Term.Declared.typesOnly h valid hm
  theorem declaredSlots_typesOnly {P C D Γ Δ ts f} (h : declaredSlots P C Γ ts)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) : declaredSlots P D Δ ts := by
    cases ts with
    | nil => trivial
    | cons t ts => exact ⟨declaredSlot_typesOnly h.1 valid hm, declaredSlots_typesOnly h.2 valid hm⟩
end

theorem Pred.Declared.typesOnly {P C D Γ Δ self p f} (h : Pred.Declared P C Γ self p)
    (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) :
    Pred.Declared P D Δ (self.map (Ty.rawBind (.typesOnly f))) p := by
  cases self with
  | none =>
    cases p <;> simp only [Pred.Declared] at h <;> simp only [Option.map_none, Pred.Declared]
    all_goals first
      | trivial
      | exact Term.Declared.typesOnly h valid hm
      | exact ⟨Term.Declared.typesOnly h.1 valid hm, Term.Declared.typesOnly h.2 valid hm⟩
      | exact ⟨Pred.Declared.typesOnly h.1 valid hm, Pred.Declared.typesOnly h.2 valid hm⟩
      | exact Pred.Declared.typesOnly h valid hm
      | skip
    case constructorIs t c =>
      obtain ⟨ht, d, ts, cd, hd, hc, hn⟩ := h
      exact ⟨ht.typesOnly valid hm, d, ts.map (Ty.bind (.typesOnly f)), cd, hd.typesOnly valid hm, hc, hn⟩
  | some a =>
    have hu := hm.extend a
    cases p <;> simp only [Pred.Declared] at h <;> simp only [Option.map_some, Pred.Declared]
    all_goals first
      | trivial
      | exact Term.Declared.typesOnly h valid hu
      | exact ⟨Term.Declared.typesOnly h.1 valid hu, Term.Declared.typesOnly h.2 valid hu⟩
      | exact ⟨Pred.Declared.typesOnly h.1 valid hm, Pred.Declared.typesOnly h.2 valid hm⟩
      | exact Pred.Declared.typesOnly h valid hm
      | skip
    case constructorIs t c =>
      obtain ⟨ht, d, ts, cd, hd, hc, hn⟩ := h
      exact ⟨ht.typesOnly valid hu, d, ts.map (Ty.bind (.typesOnly (fun i => (f i).shiftV 1 0))), cd,
        hd.typesOnly valid hu, hc, hn⟩

mutual
  theorem Ty.Declared.typesOnly {P C D Γ Δ a f} (h : Ty.Declared P C Γ a) (ha : a.NoTapp)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, Ty.Declared P D Δ (f i)) :
      Ty.Declared P D Δ (a.rawBind (.typesOnly f)) := by
    cases a with
    | base _ | bytes | «opaque» _ _ | «scoped» _ _ _ | pathBases | scopePattern _ => trivial
    | tvar i => exact hf i
    | ctor c => cases c <;> exact h
    | list a | reference a | lazy a | set a | dict _ a => exact Ty.Declared.typesOnly (a := a) h ha valid hm hf
    | data d as => exact ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1,
        declaredTys_typesOnly h.2 ha valid hm hf⟩
    | external _ as => exact ⟨by simpa only [rawBindTys_eq_map, List.length_map] using h.1,
        declaredTys_typesOnly h.2 ha valid hm hf⟩
    | tapp _ _ => exact False.elim ha
    | dependentFn _ => exact declaredTel_typesOnly h ha valid hm hf
    | fn _ _ _ _ => exact ⟨declaredTys_typesOnly h.1 ha.1 valid hm hf,
        Ty.Declared.typesOnly h.2.1 ha.2.1 valid hm hf, declaredEff_typesOnly h.2.2 ha.2.2 valid hm hf⟩
    | cont _ _ _ => exact ⟨Ty.Declared.typesOnly h.1 ha.1 valid hm hf,
        Ty.Declared.typesOnly h.2.1 ha.2.1 valid hm hf, declaredEff_typesOnly h.2.2 ha.2.2 valid hm hf⟩
    | map _ _ => exact ⟨Ty.Declared.typesOnly h.1 ha.1 valid hm hf, Ty.Declared.typesOnly h.2 ha.2 valid hm hf⟩
    | refined a p =>
      simp only [Ty.rawBind, SubstEnv.typesOnly, upValues_id, predBind_id, Ty.Declared]
      exact ⟨Ty.Declared.typesOnly h.1 ha valid hm hf, Pred.Declared.typesOnly h.2 valid hm⟩
  theorem declaredTys_typesOnly {P C D Γ Δ as f} (h : declaredTys P C Γ as) (ha : noTappTys as)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, Ty.Declared P D Δ (f i)) :
      declaredTys P D Δ (rawBindTys (.typesOnly f) as) := by
    cases as with
    | nil => trivial
    | cons a as => exact ⟨Ty.Declared.typesOnly h.1 ha.1 valid hm hf, declaredTys_typesOnly h.2 ha.2 valid hm hf⟩
  theorem declaredEff_typesOnly {P C D Γ Δ e f} (h : declaredEff P C Γ e) (ha : noTappEff e)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, Ty.Declared P D Δ (f i)) :
      declaredEff P D Δ (Eff.rawBind (.typesOnly f) e) := by
    cases e with
    | mk at' fs =>
      simp only [Eff.rawBind, SubstEnv.typesOnly, rowFails, List.length_nil, List.range_zero, List.filter_nil,
        List.flatMap_nil, List.append_nil, declaredEff]
      exact declaredTys_typesOnly h ha valid hm hf
  theorem declaredTel_typesOnly {P C D Γ Δ t f} (h : Tel.Declared P C Γ t) (ha : noTappTel t)
      (valid : P.VarianceValid) (hm : TypeFormationMap Γ Δ f) (hf : ∀ i, Ty.Declared P D Δ (f i)) :
      Tel.Declared P D Δ (Tel.rawBind (.typesOnly f) t) := by
    cases t with
    | done r e => exact ⟨Ty.Declared.typesOnly h.1 ha.1 valid hm hf, declaredEff_typesOnly h.2 ha.2 valid hm hf⟩
    | param _ a t =>
      refine ⟨Ty.Declared.typesOnly h.1 ha.1 valid hm hf, ?_⟩
      simp only [SubstEnv.typesOnly_up]
      apply declaredTel_typesOnly h.2 ha.2 valid (hm.extend a)
      intro i
      rw [Ty.shiftV_eq_renameTy, renameTy_eq_rawSubstV]
      exact (hf i).rawSubstV (DeclarationRenaming.outer Δ (a.rawBind (.typesOnly f))).images
end

/-- 総称の型に、通常値型の注釈を代入して形成を保つ。 -/
theorem Ty.Annotation.subst_types_closed {P C n a Γ xs}
    (h : Ty.Annotation P (List.replicate n ({} : TParam)) [] a) (hk : a.HasKind P (List.replicate n .value) .value)
    (valid : P.VarianceValid) (hl : xs.length = n) (ht : TypeAnnotations P C Γ xs)
    (ho : ∀ t ∈ xs, Ordinary t) : Ty.Annotation P C Γ (a.subst xs []) := by
  let f := fun i => if i < xs.length then xs[i]?.getD (.tvar i) else .tvar (i-xs.length)
  have hfo : ∀ i, Ordinary (f i) := by
    simpa only [typeEnvAt_zero_eq_typesOnly, SubstEnv.typesOnly] using typeEnvAt_ordinary 0 xs [] ho
  have hm : TypeFormationMap [] Γ f := ⟨by intro i a hi; simp at hi, hfo⟩
  have hin : ∀ i, i < n → ∃ t, xs[i]? = some t ∧ t ∈ xs ∧ f i = t := by
    intro i hi
    have hix : i < xs.length := by omega
    exact ⟨xs[i], List.getElem?_eq_getElem hix, List.getElem_mem hix, by simp [f, hix]⟩
  have hfs : ∀ i, (f i).Sorted Γ := by
    intro i
    by_cases hi : i < xs.length
    · obtain ⟨t, _, ht', he⟩ := hin i (by omega)
      rw [he]; exact (ht t ht').sorted
    · simp [f, hi, Ty.Sorted]
  have hfd : ∀ i, Ty.Declared P C Γ (f i) := by
    intro i
    by_cases hi : i < xs.length
    · obtain ⟨t, _, ht', he⟩ := hin i (by omega)
      rw [he]; exact (ht t ht').declared
    · simp [f, hi, Ty.Declared]
  change Ty.Annotation P C Γ (a.bind (typeEnvAt 0 xs []))
  rw [typeEnvAt_zero_eq_typesOnly]
  refine ⟨Ty.wf_typesOnly (by simpa using h.wf) hk.noTapp f (by simp) ?_ hfo,
    Ty.sorted_norm (Ty.Sorted.typesOnly h.sorted hk.noTapp hm hfs), (h.declared.typesOnly hk.noTapp valid hm hfd).norm⟩
  intro i hi
  obtain ⟨t, _, ht', he⟩ := hin i hi
  rw [he]; exact (ht t ht').wf

/-- 検証済みの構成子の欄は、欄ごとの形成を呼出し側に要求せず具体化できる。 -/
theorem Program.VarianceValid.field_annotation {P C Γ c cd a xs} (valid : P.VarianceValid)
    (hc : P.cons c = some cd) (ha : a ∈ cd.args) (hl : xs.length = cd.ntys)
    (ht : TypeAnnotations P C Γ xs) (ho : ∀ t ∈ xs, Ordinary t) : Ty.Annotation P C Γ (a.subst xs []) := by
  have hs := (valid.2 c cd hc).2 a ha
  exact hs.1.subst_types_closed hs.2.1 valid hl ht ho

end Benitoite.Release.Refinement
